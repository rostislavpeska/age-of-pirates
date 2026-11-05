#!/usr/bin/env python
"""Tactics file -> actions and tactics, merged with the proto's protoactions into the bundle's `timing` view.

    python tactics.py --proto ypIronFlail          # tactics record + timing (ROF from the protoactions) as JSON
    python tactics.py data/tactics/handcavalrysplash.tactics

    import vfs as V, proto_resolve as P, tactics as T
    fs = V.VFS(); proto = P.resolve_proto(fs, 'ypIronFlail')
    tac = T.load_tactics(fs, proto['tactics_file'])          # bundle-schema.md section 12 `tactics`
    tim = T.timing(proto, tac, animfile=main_animfile_record, durations={clip id: seconds})   # `timing`

Grammar (census of the 472 vanilla tactics files, critic P1-5): top-level `<action>` (name with stringid, type, anim,
idleanim, reloadanim, animationrate, rof, `<rate type>` lines, typedanim, ...), `<tactic>` (name as its text, `<action
priority>` references, idle/bored/death/walk/jog/run/move anims, `<speedmodifier>`, `<transition>` with tactic, length,
exit and optional anim, action, automatic, commandautomatic) and `<dbaction>`. Every child is also kept as read
(`fields`); unknown top-level elements go to `other`.

Timing (every rule labelled; status 'hypothesis' until the test-device timing run, design section 8 item 9):
- ROF comes from the proto's protoaction of the same name (`rof_source: protoaction`); the tactics value is kept as
  `rof_tactics` (H1: the protoaction ROF overrides the tactics ROF). Without a protoaction the tactics ROF is used.
- Clip durations of the action's anim come from the main animfile's variants when `durations` is given.
- A clip shorter than its ROF is flagged (Raze_attack 1.0 s against ROF 3.0: the decisive in-game timing case).
- `anims_unreferenced`: anims of the animfile that no tactics action or tactic names (Attack_trample, Highstep: played
  by engine logic the data does not show); `anims_missing`: names the tactics use that the animfile lacks.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import av_common as C  # noqa: E402
import vfs as V  # noqa: E402

ANIM_SUFFIX = 'anim'
RULES = {
    'H1': 'H1: the protoaction ROF overrides the tactics ROF',
    'H2': 'H2: tags scale with the clip, not with ROF',
    'H3': 'H3: AnimationRate multiplies the clip playback rate',
    'H4': 'H4: a tactic speedmodifier multiplies maxvelocity / maxrunvelocity',
}


def parse_action(el) -> dict:
    """{name, stringid, type, anim, idleanim, reloadanim, animationrate, rof, rate, fields}."""
    name = V.kid(el, 'name')
    return {'name': V.text(name) if name is not None else None,
            'stringid': V.attr(name, 'stringid') if name is not None else None,
            'type': V.kid_text(el, 'type'), 'anim': V.kid_text(el, 'anim'), 'idleanim': V.kid_text(el, 'idleanim'),
            'reloadanim': V.kid_text(el, 'reloadanim'), 'animationrate': V.fnum(V.kid_text(el, 'animationrate')),
            'rof': V.fnum(V.kid_text(el, 'rof')),
            'rate': [{'type': V.attr(r, 'type'), 'value': V.fnum(V.text(r))} for r in V.kids(el, 'rate')],
            'fields': V.fields(el)}


def parse_transition(el) -> dict:
    """{tactic, length, exit, anim, action, automatic, commandautomatic, fields}."""
    return {'tactic': V.kid_text(el, 'tactic'), 'length': V.fnum(V.kid_text(el, 'length')),
            'exit': V.flag(V.kid_text(el, 'exit')), 'anim': V.kid_text(el, 'anim'),
            'action': V.kid_text(el, 'action'), 'automatic': V.flag(V.kid_text(el, 'automatic')),
            'commandautomatic': V.flag(V.kid_text(el, 'commandautomatic')), 'fields': V.fields(el)}


def parse_tactic(el) -> dict:
    """{name, speedmodifier, actions: [{name, priority}], anims: {idle, bored, death, walk, jog, run, move...},
    transitions, fields}."""
    anims = {}
    for c in V.kids(el):
        t = V.tag(c)
        if t.endswith(ANIM_SUFFIX) and len(t) > len(ANIM_SUFFIX):
            anims.setdefault(t[:-len(ANIM_SUFFIX)], V.text(c))
    return {'name': V.text(el), 'stringid': V.attr(el, 'stringid'),
            'speedmodifier': V.fnum(V.kid_text(el, 'speedmodifier')),
            'actions': [{'name': V.text(a), 'priority': V.number(V.attr(a, 'priority'))} for a in V.kids(el, 'action')],
            'anims': anims, 'transitions': [parse_transition(t) for t in V.kids(el, 'transition')],
            'fields': V.fields(el)}


def parse_tactics(root) -> dict:
    """{actions, tactics, other} of a <tactics> element (pure)."""
    out = {'actions': [], 'tactics': [], 'other': []}
    for c in V.kids(root):
        t = V.tag(c)
        if t == 'action':
            out['actions'].append(parse_action(c))
        elif t == 'tactic':
            out['tactics'].append(parse_tactic(c))
        else:
            out['other'].append(V.record(c))
    return out


def load_tactics(fs, tactics_id):
    """the manifest's `tactics` record {id, provenance, layer, source_form, eol, actions, tactics, other}, or None
    (with the VFS's `file-missing` warning)."""
    tid = C.logical_path(tactics_id)
    vf = fs.read_xml(tid)
    if vf is None:
        return None
    rec = {'id': tid, 'provenance': vf.provenance, 'layer': vf.layer, 'source_form': vf.source_form, 'eol': vf.eol}
    if vf.root is None:
        rec.update(actions=[], tactics=[], other=[], unavailable_reason=vf.unavailable_reason)
        return rec
    if V.tag(vf.root) != 'tactics':
        fs.warn('not-a-tactics-file', tid, vf.layer, 'root element is <%s>, not <tactics>' % vf.root.tag)
    rec.update(parse_tactics(vf.root))
    if vf.engine_ignored:
        rec['engine_ignored'] = True
    return rec


def _clip_durations(animfile, anim, durations):
    if not animfile or not anim:
        return []
    by = {k.lower(): v for k, v in animfile.get('anims', {}).items()}
    a = by.get(anim.lower())
    if a is None:
        return []
    d = durations or {}
    return [d.get(v['clip']) if v.get('clip') else None for v in a['variants']]


def timing(proto, tactics, animfile=None, durations=None) -> dict:
    """the merged timing view (bundle-schema.md section 12): one entry per tactics action (and per protoaction the
    tactics file lacks), ROF from the protoactions, durations per variant of the action's anim."""
    pas = {(p['name'] or '').lower(): p for p in (proto or {}).get('protoactions', [])}
    acts = (tactics or {}).get('actions', [])
    tacs = (tactics or {}).get('tactics', [])
    used_by = {}
    for t in tacs:
        for a in t['actions']:
            used_by.setdefault((a['name'] or '').lower(), []).append({'tactic': t['name'], 'priority': a['priority']})
    rows, seen = [], set()
    for a in acts:
        key = (a['name'] or '').lower()
        seen.add(key)
        pa = pas.get(key)
        rows.append(_row(a['name'], a, pa, used_by.get(key, []), animfile, durations))
    for key, pa in pas.items():
        if key not in seen:
            rows.append(_row(pa['name'], None, pa, used_by.get(key, []), animfile, durations))
    out = {'actions': rows, 'status': 'hypothesis', 'rules': [RULES['H1'], RULES['H2']]}
    mv, mr = (proto or {}).get('maxvelocity'), (proto or {}).get('maxrunvelocity')
    out['movement'] = {'maxvelocity': mv, 'maxrunvelocity': mr, 'tactics': [
        {'tactic': t['name'], 'speedmodifier': t['speedmodifier'], 'anims': t['anims'],
         'maxvelocity_effective': (mv * t['speedmodifier']) if mv is not None and t['speedmodifier'] is not None else mv,
         'maxrunvelocity_effective': (mr * t['speedmodifier']) if mr is not None and t['speedmodifier'] is not None
         else mr,
         'transitions': t['transitions'], 'rule': RULES['H4'] if t['speedmodifier'] is not None else None}
        for t in tacs]}
    if any(r['animationrate'] is not None for r in rows):
        out['rules'].append(RULES['H3'])
    if animfile:
        named = set()
        for a in acts:
            for k in ('anim', 'idleanim', 'reloadanim'):
                if a.get(k):
                    named.add(a[k].lower())
            for f in a['fields']:
                if f['tag'].lower().endswith(ANIM_SUFFIX) and f['text']:
                    named.add(f['text'].lower())
        for t in tacs:
            named.update(v.lower() for v in t['anims'].values() if v)
            named.update(tr['anim'].lower() for tr in t['transitions'] if tr['anim'])
        have = {k.lower(): k for k in animfile.get('anims', {})}
        out['anims_unreferenced'] = [have[k] for k in have if k not in named]
        out['anims_missing'] = sorted({n for n in named if n not in have})
    return out


def _row(name, act, pa, used_by, animfile, durations):
    rof_p = pa['rof'] if pa else None
    rof_t = act['rof'] if act else None
    if rof_p is not None:
        rof, src = rof_p, 'protoaction'
    elif rof_t is not None:
        rof, src = rof_t, 'tactics'
    else:
        rof, src = None, 'none'
    anim = act['anim'] if act else None
    durs = _clip_durations(animfile, anim, durations)
    row = {'action': name, 'anim': anim, 'idleanim': act['idleanim'] if act else None,
           'reloadanim': act['reloadanim'] if act else None, 'rof_effective': rof, 'rof_source': src,
           'rof_tactics': rof_t, 'rof_protoaction': rof_p, 'animationrate': act['animationrate'] if act else None,
           'clip_durations': durs, 'tactics': used_by, 'rules': [RULES['H1'], RULES['H2']], 'notes': []}
    if act is None:
        row['notes'].append('protoaction without a tactics action: no anim is known')
    if rof_p is not None and rof_t is not None and abs(rof_p - rof_t) > 1e-9:
        row['notes'].append('protoaction ROF %g differs from the tactics ROF %g' % (rof_p, rof_t))
    known = [d for d in durs if d is not None]
    if rof is not None and known and min(known) < rof - 1e-3:
        row['notes'].append('clip shorter than ROF (%.3f s < %g s): what the unit shows between attacks is the '
                            'decisive in-game timing case' % (min(known), rof))
    if row['animationrate'] is not None:
        row['rules'].append(RULES['H3'])
    return row


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('tactics', nargs='?', help='tactics id (data/tactics/x.tactics) or file name')
    ap.add_argument('--proto', help='take the tactics file and the protoactions of this proto')
    ap.add_argument('--profile')
    ap.add_argument('--game')
    a = ap.parse_args(argv)
    fs = V.VFS(profile=a.profile, game_dir=a.game)
    proto = None
    tid = a.tactics
    animrec = None
    if a.proto:
        import animfile
        import proto_resolve
        proto = proto_resolve.resolve_proto(fs, a.proto)
        tid = tid or (proto or {}).get('tactics_file')
        if proto and proto.get('animfile'):
            animrec = animfile.AnimfileSet(fs, proto['animfile']).animfiles.get(proto['animfile'])
    if not tid:
        ap.error('a tactics id or --proto is needed')
    import proto_resolve
    tac = load_tactics(fs, proto_resolve.tactics_id(tid))
    out = {'tactics': tac, 'timing': timing(proto, tac, animrec), 'warnings': fs.warnings}
    sys.stdout.write(C.json_text(out))
    return 0 if tac else 1


if __name__ == '__main__':
    sys.exit(main())
