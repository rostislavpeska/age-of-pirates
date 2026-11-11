#!/usr/bin/env python
"""Proto -> animfile + tactics, from the live protoy in the archives plus every enabled mod's protomods.

    python proto_resolve.py ypIronFlail            # the merged proto record as JSON (bundle-schema.md section 12)

    import vfs as V, proto_resolve as P
    fs = V.VFS()
    rec = P.resolve_proto(fs, 'ypIronFlail')      # {name, dbid, animfile, tactics_file, maxvelocity, protoactions...}
    subj = P.subject(fs, proto='ypIronFlail')     # {kind, proto, animfile} (bundle-schema.md section 4)

Sources, read through the VFS (never a stale snapshot): `data/protoy.xml` from the first layer holding it (the game's
Data.bar today), then `data/protomods.xml` of EVERY enabled mod that has one (its `.xmb` twin when present, as the
engine reads it), applied from the lowest-priority mod to the highest, so AoP (priority 1) applies last and wins.

Merge rules (bundle-schema `proto.sources` names the rule each layer applied):
- documented (aoe-xml data-xml.md): a mod `<unit mergeMode='replace'>` replaces the record whole; a unit name protoy
  lacks is a new record.
- observed in AoP, engine behaviour inferred: a re-declared unit WITHOUT mergeMode merges child by child - a child with
  mergeMode='remove' removes the same tag with the same text (`<contain mergeMode='remove'>AbstractArtillery</contain>`),
  mergeMode='add' appends, a `<protoaction>` replaces the one with the same `<name>`, a repeatable tag (unittype, flag,
  command, cost, armor, contain, train, tech, ...) appends unless the same element exists, any other tag replaces the
  first child of that tag. These child rules are labelled 'hypothesis' in the record's notes.
Protoactions are the source of ROF (critic P1-5: the tactics file rarely carries one; techs change it later -
`techs_applied` stays empty in v0).
"""
from __future__ import annotations

import argparse
import copy
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import av_common as C  # noqa: E402
import vfs as V  # noqa: E402

PROTOY = 'data/protoy.xml'
PROTOMODS = 'data/protomods.xml'
REPEATABLE = {'unittype', 'flag', 'command', 'cost', 'armor', 'contain', 'train', 'tech', 'protoaction',
              'carrycapacity', 'damagebonus', 'logicalmovementtype', 'autoattacktype', 'unitaction', 'aura'}
MERGE_HYPOTHESIS = ('protomods child merge (no mergeMode on the unit): remove/add/replace-by-tag rules inferred from '
                    'AoP usage, not measured in the engine')


def tactics_id(name) -> str:
    """the logical id of a proto's <tactics> value (`handCavalrySplash.tactics` -> data/tactics/handcavalrysplash.tactics)."""
    p = C.logical_path(name)
    return p if p.startswith('data/') else 'data/tactics/' + p.split('/')[-1]


def _name(unit):
    return (V.attr(unit, 'name') or '').strip()


def _mode(el):
    return (V.attr(el, 'mergemode') or '').strip().lower()


def _same(a, b):
    return V.tag(a) == V.tag(b) and V.text(a).lower() == V.text(b).lower()


def merge_unit(base, mod):
    """the record after one mod's <unit> (module docstring). Returns (element, rule) where rule is 'replace', 'merge',
    'add' (a new unit) or 'remove' (element None)."""
    mode = _mode(mod)
    if mode == 'remove':
        return None, 'remove'
    if base is None or mode == 'replace':
        out = copy.deepcopy(mod)
        return out, ('add' if base is None else 'replace')
    out = copy.deepcopy(base)
    for k, v in mod.attrib.items():
        if k.lower() != 'mergemode':
            out.set(k, v)
    for ch in V.kids(mod):
        cmode, t = _mode(ch), V.tag(ch)
        new = copy.deepcopy(ch)
        for k in [k for k in new.attrib if k.lower() == 'mergemode']:
            del new.attrib[k]
        if cmode == 'remove':
            for old in [o for o in V.kids(out) if _same(o, ch)]:
                out.remove(old)
            continue
        if cmode == 'add':
            out.append(new)
            continue
        if t == 'protoaction':
            nm = (V.kid_text(ch, 'name') or '').lower()
            old = next((o for o in V.kids(out, 'protoaction') if (V.kid_text(o, 'name') or '').lower() == nm), None)
            if old is not None:
                out.insert(list(out).index(old), new)
                out.remove(old)
            else:
                out.append(new)
        elif t in REPEATABLE:
            if not any(_same(o, ch) and o.attrib == new.attrib for o in V.kids(out, t)):
                out.append(new)
        else:
            old = V.kid(out, t)
            if old is not None:
                out.insert(list(out).index(old), new)
                out.remove(old)
            else:
                out.append(new)
    return out, 'merge'


class ProtoDB:
    """protoy + the mods' protomods of one VFS (parsed once, cached on the VFS as `_protodb`)."""

    def __init__(self, fs):
        self.fs = fs
        self.base = fs.read_xml(PROTOY)
        self.units = {}
        if self.base is not None and self.base.root is not None:
            for u in V.kids(self.base.root, 'unit'):
                self.units.setdefault(_name(u).lower(), u)
        self.mods = [vf for vf in fs.read_each(PROTOMODS) if vf.root is not None]
        self._mod_units = []
        for vf in self.mods:
            idx = {}
            for u in V.kids(vf.root, 'unit'):
                idx.setdefault(_name(u).lower(), []).append(u)
            self._mod_units.append((vf, idx))

    def names(self):
        out = set(self.units)
        for _, idx in self._mod_units:
            out.update(idx)
        return out

    def merged(self, name):
        """(element or None, sources, notes) for a proto name (case-insensitive)."""
        key = name.lower()
        el = self.units.get(key)
        sources, notes = [], []
        if el is not None:
            sources.append({'layer': self.base.layer, 'provenance': self.base.provenance, 'rule': 'base'})
            if _name(el) != name:
                notes.append('name matched case-insensitively: %s' % _name(el))
        # lowest priority first: read_each returns the lookup order (highest priority first)
        for vf, idx in reversed(self._mod_units):
            for u in idx.get(key, []):
                el, rule = merge_unit(el, u)
                sources.append({'layer': vf.layer, 'provenance': vf.provenance, 'rule': rule})
                if rule == 'merge' and MERGE_HYPOTHESIS not in notes:
                    notes.append(MERGE_HYPOTHESIS)
        return el, sources, notes


def protodb(fs) -> ProtoDB:
    db = getattr(fs, '_protodb', None)
    if db is None:
        db = ProtoDB(fs)
        fs._protodb = db
    return db


def protoaction_record(el) -> dict:
    """{name, rof, damage, maxrange, fields} of one <protoaction> (fields = every child as read)."""
    return {'name': V.kid_text(el, 'name'), 'rof': V.fnum(V.kid_text(el, 'rof')),
            'damage': V.fnum(V.kid_text(el, 'damage')), 'maxrange': V.fnum(V.kid_text(el, 'maxrange')),
            'fields': V.fields(el)}


def proto_record(el, sources, notes) -> dict:
    """the manifest's `proto` (bundle-schema.md section 12) from a merged <unit> element."""
    anim = V.kid_text(el, 'animfile')
    tac = V.kid_text(el, 'tactics')
    return {
        'name': _name(el),
        'provenance': sources[-1]['provenance'] if sources else None,
        'dbid': V.number(V.kid_text(el, 'dbid')),
        'animfile': C.logical_path(anim) if anim else None,
        'tactics_file': tactics_id(tac) if tac else None,
        'maxvelocity': V.fnum(V.kid_text(el, 'maxvelocity')),
        'maxrunvelocity': V.fnum(V.kid_text(el, 'maxrunvelocity')),
        'movementtype': V.kid_text(el, 'movementtype'),
        'protoactions': [protoaction_record(p) for p in V.kids(el, 'protoaction')],
        'techs_applied': [],
        'sources': sources,
        'notes': notes,
    }


def resolve_proto(fs, name):
    """the merged proto record, or None with a `proto-missing` warning."""
    db = protodb(fs)
    el, sources, notes = db.merged(name)
    if el is None:
        fs.warn('proto-missing', PROTOY, None,
                'no proto named %r in protoy or any enabled mod\'s protomods' % name if not sources else
                'proto %r was removed by a mod (mergeMode=remove)' % name)
        return None
    rec = proto_record(el, sources, notes)
    if rec['animfile'] is None:
        fs.warn('file-missing', PROTOY, sources[-1]['layer'], 'proto %s names no <animfile>' % rec['name'])
    return rec


def subject(fs, proto=None, animfile=None) -> dict:
    """{kind, proto, animfile} (bundle-schema.md section 4): a proto name, or an animfile path given directly."""
    if proto:
        rec = resolve_proto(fs, proto)
        return {'kind': 'proto', 'proto': rec['name'] if rec else proto, 'animfile': rec['animfile'] if rec else None}
    if animfile:
        return {'kind': 'animfile', 'proto': None, 'animfile': C.logical_path(animfile)}
    raise ValueError('subject needs a proto name or an animfile path')


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('proto')
    ap.add_argument('--profile')
    ap.add_argument('--game')
    a = ap.parse_args(argv)
    fs = V.VFS(profile=a.profile, game_dir=a.game)
    rec = resolve_proto(fs, a.proto)
    out = {'proto': rec, 'layers': fs.layer_records(), 'provenance': fs.provenance.records, 'warnings': fs.warnings}
    sys.stdout.write(C.json_text(out))
    return 0 if rec else 1


if __name__ == '__main__':
    sys.exit(main())
