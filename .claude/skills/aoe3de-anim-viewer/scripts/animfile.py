#!/usr/bin/env python
"""Animfile resolver: an animfile and everything it pulls in, as the bundle's `animfiles`, `logic` and `composition`.

    python animfile.py units/asians/chinese/iron_flail/iron_flail.xml [--bones] [--json]
    python animfile.py --proto ypIronFlail --bones          # the proto's animfile (proto_resolve)

    import vfs as V, animfile as A
    fs = V.VFS()
    s = A.AnimfileSet(fs, 'units/asians/chinese/iron_flail/iron_flail.xml', bones=A.Gr2Bones(fs))
    s.animfiles            # id -> animfile record (bundle-schema.md section 9)
    s.logic                # logic types and states (section 6)
    s.composition(durations={clip id: seconds})              # section 10; durations optional
    s.references           # {'models', 'clips', 'animfiles'}: what the gr2/material stages load next

Grammar covered (census of the 3910 vanilla animfiles, 2026-10-11): `definebone`; `attachment` with `<include>` and/or
an inline body (components, anims, definebones, nested attachments - stored as a synthetic animfile `<id>#<name>`);
`submodel` (same shape); `component` with `assetreference` (GrannyModel + materialvariant, popcornFx, ParticleSystem,
ClothFlag...), `logic` trees of any type (Tech, LowPoly, Variation, Destruction, Culture, SubCiv...; a repeated branch
tag such as Variation's `<data>` becomes the state `data#0`, `data#1`...), `submodelref`, `decal`, `attach` at component
or branch level; `anim` with the `animlengthoverride` attribute (copied to every variant), `component` names, `attach`,
GrannyAnim variants (file, weight, every `<tag>` with all its attributes). Anything else is kept in an `other` list as
read, never dropped. Element and attribute names are matched case-insensitively and kept as written.

Resolution and audit (every finding is also a VFS warning, bundle-schema.md section 13):
- files: a variant clip or model that no layer holds -> `file-missing` (variant clip null, asset `missing: true`).
- attach records: the named attachment (this animfile, then its parents for inline bodies) -> `resolved.animfile`;
  `tobone` is looked up in the declaring side's models (the component's, or the anim's components'), `frombone` in the
  attachment's models. Bone names match as the engine does, a space equals an underscore, case-insensitive
  (unit_gr2.nm), then by an inferred engine alias that drops a leading `Bip01 ` / `bone ` (`R HAND` = `Bip01_R_Hand`,
  `ATTACHPOINT` = `bone_attachpoint`; note `bone-alias-assumed`). A frombone the attachment's model lacks (`hotspot`)
  is engine-defined: the model origin is assumed (`engine-bone-assumed`). A tobone, definebone or tag bone
  (footprintbone, effectbone) found in no model -> `bone-unresolved`. `resolved.frombone` / `tobone` index the default
  state's model (the first resolved state); `resolved.checks` lists every model checked.
- `attachment-declared-not-attached` (declared, no attach uses it), `attach-target-undeclared`,
  `attachment-effect-not-rendered` (popcornFx / ParticleSystem / ClothFlag assets), `tag-overflow` (fraction > 1),
  `component-undeclared`, `anim-duplicate-name`, `include-cycle`.
- composition: the main animfile, every attach as a child, and the pairing of a synced component-level child (the
  rider): same anim name, main variant i -> child variant i mod n - a labelled HYPOTHESIS (critic P1-6), with duration
  mismatches, one-sided anims (`anim-one-sided`) and short death clips (`ragdoll-not-simulated`) when durations are given.

Bone names come from a provider: `Gr2Bones(fs)` reads each model through the VFS with aoe3de-unit-model's unit_gr2
(an Oodle-compressed gr2 reports `model-unreadable`, never dropped), or any callable model id -> [names] | None.
"""
from __future__ import annotations

import argparse
import sys
from collections import Counter
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import av_common as C  # noqa: E402
import vfs as V  # noqa: E402

MAX_DEPTH = 8
MAX_STATES = 4096
EFFECT_TYPES = ('popcornfx', 'particlesystem', 'clothflag')
BONE_PREFIXES = ('bip01 ', 'bone ')
ATTACH_KNOWN = ('a', 'frombone', 'tobone', 'syncanims', 'allowrotation')
PAIRING_RULE = 'same anim name; main variant i -> child variant i mod n'
RAGDOLL_RATIO = 0.75


# ------------------------------------------------------------------------------------------------ bone names
def nm(name) -> str:
    """bone name for matching: a space equals an underscore, case-insensitive (the engine's rule, unit_gr2.nm)."""
    return str(name).replace('_', ' ').lower().strip()


def alias(name) -> str:
    """the inferred engine short name: nm() without a leading 'bip01 ' / 'bone ' (R HAND, ATTACHPOINT)."""
    k = nm(name)
    for p in BONE_PREFIXES:
        if k.startswith(p):
            return k[len(p):]
    return k


def match_bone(name, bones):
    """(index, 'exact' | 'alias' | 'alias-ambiguous') of `name` in a bone-name list, or (None, None)."""
    key = nm(name)
    for i, b in enumerate(bones):
        if nm(b) == key:
            return i, 'exact'
    short = alias(name)
    hits = [i for i, b in enumerate(bones) if alias(b) == short]
    if hits:
        return hits[0], ('alias' if len(hits) == 1 else 'alias-ambiguous')
    return None, None


class Gr2Bones:
    """model id -> bone names, read through the VFS with aoe3de-unit-model's unit_gr2 (lazy import). None for a model
    no layer holds or the reader refuses (Oodle-compressed sections); `reasons[model]` says why."""

    def __init__(self, fs):
        self.fs = fs
        self.cache = {}
        self.reasons = {}

    def __call__(self, model_id):
        if model_id in self.cache:
            return self.cache[model_id]
        names = None
        path = self.fs.materialize(model_id) if self.fs.exists(model_id) else None
        if path is None:
            self.reasons[model_id] = 'file-missing'
        else:
            unit_dir = HERE.parents[1] / 'aoe3de-unit-model' / 'scripts'
            if str(unit_dir) not in sys.path:
                sys.path.insert(0, str(unit_dir))
            import unit_gr2
            try:
                names = [b['name'] for b in unit_gr2.Model(path).skeleton]
            except unit_gr2.Unreadable as e:
                self.reasons[model_id] = 'gr2-unreadable: %s' % e
            except Exception as e:                               # noqa: BLE001 - a broken model is reported
                self.reasons[model_id] = 'gr2-read-failed: %s' % e
        self.cache[model_id] = names
        return names


# ------------------------------------------------------------------------------------------------ element parsers
def _attrs(el, skip=()):
    skip = tuple(s.lower() for s in skip)
    return {k: v for k, v in el.attrib.items() if k.lower() not in skip}


def parse_tag(el) -> dict:
    """{type, fraction, attrs, overflow} (+ text when the value is not a number)."""
    raw = (el.text or '').strip()
    frac = V.fnum(raw)
    t = {'type': V.attr(el, 'type'), 'fraction': frac, 'attrs': _attrs(el, ('type',)),
         'overflow': bool(frac is not None and frac > 1.0)}
    if frac is None:
        t['text'] = raw
    return t


def parse_attach(el) -> dict:
    """{a, frombone, tobone, syncanims, allowrotation, attrs, resolved} (resolved filled by AnimfileSet)."""
    sync = V.flag(V.attr(el, 'syncanims'))
    rec = {'a': V.attr(el, 'a'), 'frombone': V.attr(el, 'frombone'), 'tobone': V.attr(el, 'tobone'),
           'syncanims': sync, 'allowrotation': V.flag(V.attr(el, 'allowrotation')), 'attrs': _attrs(el, ATTACH_KNOWN),
           'resolved': {'attachment': V.attr(el, 'a'), 'animfile': None, 'frombone': None, 'tobone': None,
                        'notes': []}}
    if sync is None:
        rec['resolved']['notes'].append('syncanims-missing')
    if V.kids(el):
        rec['other'] = V.fields(el)
    return rec


def parse_asset(el) -> dict:
    """{type, file, model (GrannyModel id), materialvariant, attrs[, other]}."""
    typ = V.attr(el, 'type') or ''
    f = V.kid_text(el, 'file')
    a = {'type': typ, 'file': f}
    if typ.lower() == 'grannymodel' and f:
        a['model'] = V.ref_id(f, '.gr2')
    mv = V.kid(el, 'materialvariant')
    a['materialvariant'] = V.number(V.attr(mv, 'index')) if mv is not None else None
    a['attrs'] = _attrs(el, ('type',))
    other = [V.record(c) for c in V.kids(el) if V.tag(c) not in ('file', 'materialvariant')]
    if other:
        a['other'] = other
    return a


def parse_decal(el) -> dict:
    tex = V.kid(el, 'texture')
    return {'effecttype': V.kid_text(el, 'effecttype'), 'texture': V.text(tex) if tex is not None else None,
            'selectedtexture': V.kid_text(el, 'selectedtexture'), 'width': V.fnum(V.kid_text(el, 'width')),
            'height': V.fnum(V.kid_text(el, 'height')),
            'isfakeshadow': V.flag(V.attr(tex, 'isfakeshadow')) if tex is not None else None,
            'fields': V.fields(el)}


NODE_TAGS = ('assetreference', 'submodelref', 'logic', 'attach', 'decal')


def parse_node(el, top=False) -> dict:
    """a logic node {logic, branches} when the content is exactly one <logic>, else a leaf
    {assets[, attach, decals, children (nested logic nodes), other]}. At component level (top) attach and decal
    belong to the component."""
    assets = [parse_asset(c) for c in V.kids(el, 'assetreference')]
    assets += [{'type': 'submodelref', 'file': None, 'ref': V.attr(c, 'ref'), 'attrs': _attrs(c, ('ref',))}
               for c in V.kids(el, 'submodelref')]
    logics = [parse_logic(c) for c in V.kids(el, 'logic')]
    attach = [] if top else [parse_attach(c) for c in V.kids(el, 'attach')]
    decals = [] if top else [parse_decal(c) for c in V.kids(el, 'decal')]
    if len(logics) == 1 and not assets and not attach and not decals and (top or not _others(el)):
        return logics[0]
    node = {'assets': assets}
    if attach:
        node['attach'] = attach
    if decals:
        node['decals'] = decals
    if logics:
        node['children'] = logics
    if not top and _others(el):
        node['other'] = _others(el)
    return node


def _others(el):
    return [V.record(c) for c in V.kids(el) if V.tag(c) not in NODE_TAGS]


def parse_logic(el) -> dict:
    """{logic: type, branches: [{state, attrs, node}]}; a repeated branch tag gets '#<n>' (Variation's <data>)."""
    brs = V.kids(el)
    counts = Counter(c.tag for c in brs)
    seen = Counter()
    branches = []
    for c in brs:
        state = c.tag if counts[c.tag] == 1 else '%s#%d' % (c.tag, seen[c.tag])
        seen[c.tag] += 1
        branches.append({'state': state, 'attrs': dict(c.attrib), 'node': parse_node(c)})
    return {'logic': V.attr(el, 'type') or '', 'branches': branches}


def flatten(node, state=None):
    """every state combination of a tree: [(state dict, [model ids], [attach records])], in file order."""
    state = dict(state or {})
    if 'logic' in node:
        if not node['branches']:
            return [(state, [], [])]
        out = []
        for br in node['branches']:
            out += flatten(br['node'], {**state, node['logic']: br['state']})
            if len(out) > MAX_STATES:
                return out[:MAX_STATES]
        return out
    models = [a['model'] for a in node.get('assets', []) if a.get('model')]
    res = [(state, models, list(node.get('attach', [])))]
    for ch in node.get('children', []):
        res = [(s2, m + m2, a + a2) for (s, m, a) in res for (s2, m2, a2) in flatten(ch, s)][:MAX_STATES]
    return res


def iter_nodes(node):
    yield node
    if 'logic' in node:
        for br in node['branches']:
            yield from iter_nodes(br['node'])
    else:
        for ch in node.get('children', []):
            yield from iter_nodes(ch)


def parse_component(el) -> dict:
    """{name, tree, resolved: [{state, models, attach}], decals, attach[, includes, other]}."""
    tree = parse_node(el, top=True)
    comp = {'name': V.text(el), 'tree': tree,
            'resolved': [{'state': s, 'models': m, 'attach': a} for s, m, a in flatten(tree)],
            'decals': [parse_decal(c) for c in V.kids(el, 'decal')],
            'attach': [parse_attach(c) for c in V.kids(el, 'attach')]}
    inc = [C.logical_path(V.text(c)) for c in V.kids(el, 'include') if V.text(c)]
    if inc:
        comp['includes'] = inc
    other = [V.record(c) for c in V.kids(el) if V.tag(c) not in NODE_TAGS + ('include',)]
    if other:
        comp['other'] = other
    return comp


def parse_variant(el, index, animlengthoverride=None) -> dict:
    """{index, clip, file, weight, animlengthoverride, tags[, other]}; clip is the id, nulled by the set when missing."""
    f = V.kid_text(el, 'file')
    v = {'index': index, 'clip': V.ref_id(f, '.gr2') if f else None, 'file': f,
         'weight': V.number(V.kid_text(el, 'weight')), 'animlengthoverride': animlengthoverride,
         'tags': [parse_tag(t) for t in V.kids(el, 'tag')]}
    other = [V.record(c) for c in V.kids(el) if V.tag(c) not in ('file', 'weight', 'tag')]
    if other:
        v['other'] = other
    return v


def weights_of(variants) -> dict:
    """{rule, normalized}: declared | uniform-hypothesis | mixed (a variant without <weight> counts 1, a hypothesis)
    | none (no variant)."""
    if not variants:
        return {'rule': 'none', 'normalized': []}
    ws = [v['weight'] for v in variants]
    have = [w is not None for w in ws]
    if all(have):
        rule, vals = 'declared', [float(w) for w in ws]
    elif not any(have):
        rule, vals = 'uniform-hypothesis', [1.0] * len(ws)
    else:
        rule, vals = 'mixed', [float(w) if w is not None else 1.0 for w in ws]
    tot = sum(vals)
    if tot <= 0:
        vals, tot = [1.0] * len(vals), float(len(vals))
    return {'rule': rule, 'normalized': [x / tot for x in vals]}


def parse_anim(el) -> dict:
    """{name, components, attach, variants, weights, animlengthoverride, attrs[, weight, other]}."""
    alo = V.fnum(V.attr(el, 'animlengthoverride'))
    variants, other = [], []
    for c in V.kids(el):
        t = V.tag(c)
        if t == 'assetreference' and (V.attr(c, 'type') or '').lower() == 'grannyanim':
            variants.append(parse_variant(c, len(variants), alo))
        elif t not in ('component', 'attach', 'weight'):
            other.append(V.record(c))
    a = {'name': V.text(el), 'components': [V.text(c) for c in V.kids(el, 'component')],
         'attach': [parse_attach(c) for c in V.kids(el, 'attach')], 'variants': variants,
         'weights': weights_of(variants), 'animlengthoverride': alo, 'attrs': _attrs(el, ('animlengthoverride',))}
    w = V.kid(el, 'weight')
    if w is not None:
        a['weight'] = V.number(V.text(w))
    if other:
        a['other'] = other
    return a


def _new_record(afid):
    return {'id': afid, 'path': afid.split('#', 1)[0], 'provenance': None, 'eol': None, 'source_form': None,
            'includes': [], 'definebones': [], 'attachments': [], 'components': [], 'anims': {}, 'submodels': [],
            'other': [], 'audit': []}


def parse_animfile(root, afid) -> dict:
    """{id: record} for an <animfile> element: the record of `afid` plus one synthetic record per inline attachment or
    submodel body (`<afid>#<name>`, with `parent` and `inline: true`). Pure: no file access."""
    out = {}
    _parse_body(root, C.logical_path(afid), out)
    return out


def _parse_body(el, afid, out):
    rec = _new_record(afid)
    out[afid] = rec
    for c in V.kids(el):
        t = V.tag(c)
        if t == 'definebone':
            rec['definebones'].append(V.text(c))
        elif t in ('attachment', 'submodel'):
            name = V.text(c)
            incs = [C.logical_path(V.text(i)) for i in V.kids(c, 'include') if V.text(i)]
            body = None
            if any(V.tag(x) != 'include' for x in V.kids(c)):
                body = '%s#%s' % (afid, name)
                n = 2
                while body in out:
                    body, n = '%s#%s~%d' % (afid, name, n), n + 1
                _parse_body(c, body, out)
                out[body].update(parent=afid, inline=True)
            entry = {'name': name, 'include': incs[0] if incs else None, 'body': body, 'used_by': [], 'audit': []}
            if len(incs) > 1:
                entry['includes_extra'] = incs[1:]
            for i in incs:
                if i not in rec['includes']:
                    rec['includes'].append(i)
            rec['attachments' if t == 'attachment' else 'submodels'].append(entry)
        elif t == 'component':
            comp = parse_component(c)
            for i in comp.get('includes', []):
                if i not in rec['includes']:
                    rec['includes'].append(i)
            rec['components'].append(comp)
        elif t == 'anim':
            a = parse_anim(c)
            key, n = a['name'], 2
            while key in rec['anims']:
                key, n = '%s#%d' % (a['name'], n), n + 1
            if key != a['name']:
                rec['audit'].append({'code': 'anim-duplicate-name', 'anim': a['name'], 'key': key})
            rec['anims'][key] = a
        else:
            rec['other'].append(V.record(c))
    return rec


# ------------------------------------------------------------------------------------------------ the set
class AnimfileSet:
    """an animfile, its includes and inline bodies, resolved and audited (module docstring)."""

    def __init__(self, fs, animfile_id, bones=None, max_depth=MAX_DEPTH):
        self.fs = fs
        self.root = C.logical_path(animfile_id)
        self.bones = bones
        self.max_depth = max_depth
        self.animfiles = {}
        self.layers = {}
        self.references = {'models': [], 'clips': [], 'animfiles': []}
        self._referenced = set()
        self._unresolved = {}
        self._done = set()
        self._load(self.root, 0, ())
        for rec in list(self.animfiles.values()):
            self._resolve_attaches(rec)
        for rec in list(self.animfiles.values()):
            self._audit(rec)
        self._emit_bone_warnings()

    # ---------------------------------------------------------------- loading
    def _warn(self, code, afid, message):
        self.fs.warn(code, afid.split('#', 1)[0], self.layers.get(afid), message)

    def _load(self, afid, depth, chain):
        if afid in chain:
            self.fs.warn('include-cycle', afid, self.layers.get(afid), 'include cycle: %s' % ' -> '.join(chain + (afid,)))
            rec = self.animfiles.get(chain[-1])
            if rec is not None:
                rec['audit'].append({'code': 'include-cycle', 'include': afid})
            return
        if afid in self.animfiles:
            return
        if depth > self.max_depth:
            self.fs.warn('include-cycle', afid, None, 'include depth above %d: %s' % (self.max_depth, afid))
            return
        vf = self.fs.read_xml(afid)
        if vf is None or vf.root is None:
            rec = _new_record(afid)
            rec['unavailable_reason'] = 'file-missing' if vf is None else vf.unavailable_reason
            if vf is not None:
                rec.update(provenance=vf.provenance, eol=vf.eol, source_form=vf.source_form)
            self.animfiles[afid] = rec
            return
        if V.tag(vf.root) != 'animfile':
            self.fs.warn('not-an-animfile', afid, vf.layer, 'root element is <%s>, not <animfile>' % vf.root.tag)
        recs = parse_animfile(vf.root, afid)
        for rid, rec in recs.items():
            rec.update(provenance=vf.provenance, eol=vf.eol, source_form=vf.source_form, layer=vf.layer)
            if vf.engine_ignored:
                rec['engine_ignored'] = True
            self.layers[rid] = vf.layer
            self.animfiles[rid] = rec
            self._check_files(rec)
        self.references['animfiles'].append(afid)
        for rec in recs.values():
            for inc in rec['includes']:
                self._load(inc, depth + 1, chain + (afid,))

    def _add_ref(self, kind, rid):
        if rid not in self.references[kind]:
            self.references[kind].append(rid)

    def _check_files(self, rec):
        for comp in rec['components']:
            for node in iter_nodes(comp['tree']):
                for a in node.get('assets', []):
                    if a.get('model'):
                        self._add_ref('models', a['model'])
                        if not self.fs.exists(a['model']):
                            a['missing'] = True
                            rec['audit'].append({'code': 'file-missing', 'model': a['model'], 'component': comp['name']})
                            self._warn('file-missing', rec['id'], 'GrannyModel %s (component %s) is in no layer'
                                       % (a['file'], comp['name']))
                    elif a['type'].lower() in EFFECT_TYPES:
                        rec['audit'].append({'code': 'effect-not-rendered', 'type': a['type'], 'file': a['file'],
                                             'component': comp['name']})
                        self._warn('attachment-effect-not-rendered', rec['id'],
                                   '%s asset %s (component %s) is not rendered by the viewer'
                                   % (a['type'], a['file'], comp['name']))
        for name, an in rec['anims'].items():
            for v in an['variants']:
                if v['clip'] is None:
                    continue
                if self.fs.exists(v['clip']):
                    self._add_ref('clips', v['clip'])
                else:
                    rec['audit'].append({'code': 'file-missing', 'clip': v['clip'], 'anim': name, 'variant': v['index']})
                    self._warn('file-missing', rec['id'], 'GrannyAnim %s (anim %s variant %d) is in no layer'
                               % (v['file'], name, v['index']))
                    v['clip'] = None

    # ---------------------------------------------------------------- models of a side
    def _component(self, rec, name):
        for comp in rec['components']:
            if comp['name'].lower() == (name or '').lower():
                return comp
        return None

    def _models(self, rec, comp_names=None):
        """(ordered unique model ids, default model) of the named components (all when None), all states."""
        comps = rec['components'] if comp_names is None else \
            [c for c in (self._component(rec, n) for n in comp_names) if c is not None]
        models, default = [], None
        for comp in comps:
            for r in comp['resolved']:
                for m in r['models']:
                    if default is None:
                        default = m
                    if m not in models:
                        models.append(m)
        return models, default

    def _target_models(self, att):
        models, default = [], None
        for rid in (att.get('include'), att.get('body')):
            rec = self.animfiles.get(rid) if rid else None
            if rec is None:
                continue
            ms, d = self._models(rec)
            models += [m for m in ms if m not in models]
            default = default or d
        return models, default

    def _check_bone(self, side, bone, models, default):
        checks = []
        if not bone:
            return None, checks
        for m in models:
            names = self.bones(m) if self.bones is not None else None
            if self.bones is None:
                checks.append({'side': side, 'model': m, 'bone': bone, 'index': None, 'name': None,
                               'match': 'not-checked'})
                continue
            if names is None:
                why = getattr(self.bones, 'reasons', {}).get(m)
                checks.append({'side': side, 'model': m, 'bone': bone, 'index': None, 'name': None,
                               'match': 'model-unreadable', 'reason': why})
                continue
            idx, how = match_bone(bone, names)
            checks.append({'side': side, 'model': m, 'bone': bone, 'index': idx,
                           'name': names[idx] if idx is not None else None, 'match': how or 'unresolved'})
        index = next((c['index'] for c in checks if c['model'] == default), None)
        return index, checks

    # ---------------------------------------------------------------- attaches
    def sites(self, rec):
        """every attach record of an animfile: (scope, owner, attach) with scope component | branch | anim."""
        for comp in rec['components']:
            for at in comp['attach']:
                yield 'component', comp['name'], at
            for node in iter_nodes(comp['tree']):
                for at in node.get('attach', []):
                    yield 'branch', comp['name'], at
        for name, an in rec['anims'].items():
            for at in an['attach']:
                yield 'anim', name, at

    def _find_attachment(self, rec, name):
        cur = rec
        while cur is not None:
            for att in cur['attachments']:
                if att['name'].lower() == (name or '').lower():
                    return cur, att
            cur = self.animfiles.get(cur.get('parent'))
        return None, None

    def _resolve_attaches(self, rec):
        for scope, owner, at in self.sites(rec):
            res = at['resolved']
            if id(res) in self._done:
                continue
            self._done.add(id(res))
            holder, att = self._find_attachment(rec, at['a'])
            if att is None:
                res['notes'].append('attachment-undeclared')
                rec['audit'].append({'code': 'attach-target-undeclared', 'a': at['a'], scope: owner})
                self._warn('attach-target-undeclared', rec['id'],
                           '<attach a="%s"> (%s %s) names no declared attachment' % (at['a'], scope, owner))
                continue
            self._referenced.add((holder['id'], att['name'].lower()))
            res['animfile'] = att['include'] or att['body']
            if att['include'] and att['body']:
                res['body'] = att['body']
            # tobone: the declaring side; frombone: the attachment's models
            if scope == 'anim':
                comps = rec['anims'][owner]['components']
                pmodels, pdefault = self._models(rec, comps)
            else:
                pmodels, pdefault = self._models(rec, [owner])
            cmodels, cdefault = self._target_models(att)
            res['tobone'], tchecks = self._check_bone('to', at['tobone'], pmodels, pdefault)
            res['frombone'], fchecks = self._check_bone('from', at['frombone'], cmodels, cdefault)
            res['checks'] = tchecks + fchecks
            if self.bones is None:
                res['notes'].append('bones-not-checked')
                continue
            if any(c['match'].startswith('alias') for c in res['checks']):
                res['notes'].append('bone-alias-assumed')
            if any(c['match'] == 'alias-ambiguous' for c in res['checks']):
                res['notes'].append('bone-alias-ambiguous')
            readable_from = [c for c in fchecks if c['match'] not in ('model-unreadable', 'not-checked')]
            if readable_from and all(c['index'] is None for c in readable_from):
                res['notes'].append('engine-bone-assumed')
                rec['audit'].append({'code': 'engine-bone-assumed', 'a': at['a'], 'bone': at['frombone'],
                                     scope: owner})
                self._warn('engine-bone-assumed', rec['id'],
                           'frombone "%s" of attachment %s is in none of its models (%s): the engine defines it; '
                           'the model origin is assumed' % (at['frombone'], at['a'], ', '.join(cmodels) or 'none'))
            for c in tchecks:
                if c['match'] == 'unresolved':
                    self._unresolved_bone(rec, at['tobone'], 'attach %s tobone' % at['a'], c['model'])

    # ---------------------------------------------------------------- audits
    def _unresolved_bone(self, rec, bone, use, model):
        key = (rec['id'], nm(bone))
        item = self._unresolved.setdefault(key, {'bone': bone, 'uses': [], 'models': []})
        if use not in item['uses']:
            item['uses'].append(use)
        if model not in item['models']:
            item['models'].append(model)

    def _bone_found_anywhere(self, bone, models):
        """True / False when at least one model was readable; None when no model could be checked."""
        checked = False
        for m in models:
            names = self.bones(m)
            if names is None:
                continue
            checked = True
            if match_bone(bone, names)[0] is not None:
                return True
        return False if checked else None

    def _audit(self, rec):
        # attachments: used_by and declared-not-attached
        comp_att = {}
        for scope, owner, at in self.sites(rec):
            if scope in ('component', 'branch'):
                comp_att.setdefault(owner.lower(), []).append((at['a'] or '').lower())
        for name, an in rec['anims'].items():
            names = [(at['a'] or '').lower() for at in an['attach']]
            for cname in an['components']:
                names += comp_att.get(cname.lower(), [])
                if self._component(rec, cname) is None and rec['components']:
                    rec['audit'].append({'code': 'component-undeclared', 'anim': name, 'component': cname})
                    self._warn('component-undeclared', rec['id'],
                               'anim %s names component %s, which is not declared' % (name, cname))
            for att in rec['attachments']:
                if att['name'].lower() in names and name not in att['used_by']:
                    att['used_by'].append(name)
        for att in rec['attachments']:
            if (rec['id'], att['name'].lower()) not in self._referenced:
                att['audit'].append('declared-not-attached')
                rec['audit'].append({'code': 'declared-not-attached', 'attachment': att['name'],
                                     'include': att['include']})
                self._warn('attachment-declared-not-attached', rec['id'],
                           'attachment %s%s is declared but no <attach> uses it'
                           % (att['name'], ' (include %s)' % att['include'] if att['include'] else ''))
        # tags
        overflow = []
        for name, an in rec['anims'].items():
            for v in an['variants']:
                for t in v['tags']:
                    if t['overflow']:
                        overflow.append('%s[%d] %s %.3f' % (name, v['index'], t['type'], t['fraction']))
        if overflow:
            rec['audit'].append({'code': 'tag-overflow', 'tags': overflow})
            self._warn('tag-overflow', rec['id'], '%d tag(s) past the clip end (fraction > 1, meaning unknown): %s'
                       % (len(overflow), '; '.join(overflow[:6]) + (' ...' if len(overflow) > 6 else '')))
        if self.bones is None:
            return
        # definebones and tag bones, against this animfile's own models
        all_models, _ = self._models(rec)
        if all_models:
            for b in rec['definebones']:
                if self._bone_found_anywhere(b, all_models) is False:
                    self._unresolved_bone(rec, b, 'definebone', None)
        for name, an in rec['anims'].items():
            models, _ = self._models(rec, an['components']) if an['components'] else (all_models, None)
            if not models:
                continue
            for v in an['variants']:
                for t in v['tags']:
                    for k, val in t['attrs'].items():
                        if k.lower().endswith('bone') and val and self._bone_found_anywhere(val, models) is False:
                            self._unresolved_bone(rec, val, 'tag %s@%s' % (t['type'], k), None)

    def _emit_bone_warnings(self):
        for (rid, _key), item in self._unresolved.items():
            rec = self.animfiles[rid]
            models = [m for m in item['models'] if m] or self._models(rec)[0]
            rec['audit'].append({'code': 'bone-unresolved', 'bone': item['bone'], 'uses': item['uses'],
                                 'models': models})
            self._warn('bone-unresolved', rid, 'bone "%s" (%s) is in none of the models %s'
                       % (item['bone'], ', '.join(item['uses']), ', '.join(models)))

    # ---------------------------------------------------------------- views
    @property
    def logic(self) -> dict:
        """{types: {type: [states]}, default: {type: first state}, default_rule} over every animfile of the set."""
        types = {}
        for rec in self.animfiles.values():
            for comp in rec['components']:
                for node in iter_nodes(comp['tree']):
                    if 'logic' in node:
                        states = types.setdefault(node['logic'], [])
                        for br in node['branches']:
                            if br['state'] not in states:
                                states.append(br['state'])
        return {'types': types, 'default': {k: v[0] for k, v in types.items() if v},
                'default_rule': 'first branch of each logic type (a UI default, not an engine claim)'}

    def clips_of(self, afid=None):
        """distinct clip ids of one animfile (default the main one), in file order."""
        rec = self.animfiles[afid or self.root]
        out = []
        for an in rec['anims'].values():
            for v in an['variants']:
                if v['clip'] and v['clip'] not in out:
                    out.append(v['clip'])
        return out

    def composition(self, durations=None) -> dict:
        """bundle-schema.md section 10. durations: {clip id: seconds} (optional) for mismatches and ragdoll checks."""
        children, index = [], {}
        for afid, rec in self.animfiles.items():
            for scope, owner, at in self.sites(rec):
                r = at['resolved']
                key = (afid, scope if scope != 'anim' else 'anim', owner if scope != 'anim' else None, at['a'],
                       at['frombone'], at['tobone'], at['syncanims'])
                if key in index:
                    if scope == 'anim':
                        index[key]['declared_in']['anims'].append(owner)
                    continue
                declared = {'animfile': afid}
                declared.update({'anims': [owner]} if scope == 'anim' else {'component': owner})
                child = {'animfile': r.get('animfile'), 'attachment': at['a'], 'scope': scope,
                         'attach': {'a': at['a'], 'frombone': at['frombone'], 'tobone': at['tobone'],
                                    'syncanims': at['syncanims']},
                         'declared_in': declared}
                index[key] = child
                children.append(child)
        main = self.animfiles.get(self.root)
        pairings = []
        for ch in children:
            if ch['declared_in']['animfile'] == self.root and ch['scope'] == 'component' and ch['attach']['syncanims'] \
                    and ch['animfile'] in self.animfiles:
                pairings.append(self._pairing(main, self.animfiles[ch['animfile']], durations))
        out = {'main': self.root, 'children': children, 'pairing': pairings[0] if pairings else None}
        if len(pairings) > 1:
            out['pairings'] = pairings
        return out

    def _pairing(self, main, child, durations):
        mn = {k.lower(): k for k in main['anims']}
        cn = {k.lower(): k for k in child['anims']}
        one_sided = [{'anim': mn[k], 'side': 'main'} for k in mn if k not in cn] + \
                    [{'anim': cn[k], 'side': 'child'} for k in cn if k not in mn]
        for o in one_sided:
            self._warn('anim-one-sided', main['id'] if o['side'] == 'main' else child['id'],
                       'anim %s exists only in the %s animfile (%s); the other side\'s fallback is an assumption'
                       % (o['anim'], o['side'], main['id'] if o['side'] == 'main' else child['id']))
        pairs, mismatches, ragdoll = [], [], []
        d = durations or {}
        for lk, mk in mn.items():
            if lk not in cn:
                continue
            mv, cv = main['anims'][mk]['variants'], child['anims'][cn[lk]]['variants']
            if not cv or not mv:
                continue
            for i, v in enumerate(mv):
                j = i % len(cv)
                pairs.append({'anim': mk, 'main_variant': i, 'child_variant': j,
                              'rule': 'index' if len(mv) == len(cv) else 'index-mod-%d' % len(cv)})
                dm, dc = d.get(v['clip']), d.get(cv[j]['clip'])
                if dm is not None and dc is not None and abs(dm - dc) > 1e-3:
                    mismatches.append({'anim': mk, 'variant': i, 'child_variant': j, 'main_duration': round(dm, 4),
                                       'child_duration': round(dc, 4)})
            if lk.startswith('death') and durations:
                md = [d[x['clip']] for x in mv if d.get(x['clip']) is not None]
                cd = [d[x['clip']] for x in cv if d.get(x['clip']) is not None]
                if md and cd:
                    a, b = sum(md) / len(md), sum(cd) / len(cd)
                    if min(a, b) <= RAGDOLL_RATIO * max(a, b):
                        ragdoll.append(mk)
                        self._warn('ragdoll-not-simulated', main['id'],
                                   'anim %s: mean clip %.3f s (main) vs %.3f s (child) - the shorter side probably '
                                   'hands over to a Havok ragdoll, which the viewer does not simulate' % (mk, a, b))
        return {'child': child['id'], 'rule': PAIRING_RULE, 'status': 'hypothesis',
                'sync_modes': ['absolute-time', 'normalised-phase'], 'durations_known': bool(durations),
                'mismatches': mismatches, 'one_sided': one_sided, 'pairs': pairs, 'ragdoll': ragdoll}

    def to_json(self) -> dict:
        """{'animfiles': ..., 'logic': ...}: the bundle's sections 9 and 6."""
        return {'animfiles': self.animfiles, 'logic': self.logic}


# ------------------------------------------------------------------------------------------------ CLI
def summary(s) -> list:
    lines = []
    for afid, rec in s.animfiles.items():
        nv = sum(len(a['variants']) for a in rec['anims'].values())
        lines.append('%s  [%s %s]  anims %d, variants %d, clips %d, attachments %s'
                     % (afid, rec.get('layer'), rec.get('source_form'), len(rec['anims']), nv, len(s.clips_of(afid)),
                        ', '.join('%s%s' % (a['name'], '!' + ','.join(a['audit']) if a['audit'] else '')
                                  for a in rec['attachments']) or '-'))
        for _scope, owner, at in s.sites(rec):
            r = at['resolved']
            lines.append('    attach %-18s %s -> %s  from=%s to=%s sync=%s notes=%s'
                         % (at['a'], at['frombone'], at['tobone'], r['frombone'], r['tobone'], at['syncanims'],
                            ','.join(r['notes']) or '-'))
    return lines


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('animfile', nargs='?', help='animfile id or path (units\\...\\x.xml)')
    ap.add_argument('--proto', help='resolve this proto\'s animfile instead')
    ap.add_argument('--bones', action='store_true', help='check bones against the gr2 models (unit_gr2)')
    ap.add_argument('--json', action='store_true', help='print the records as JSON')
    ap.add_argument('--profile')
    ap.add_argument('--game')
    a = ap.parse_args(argv)
    fs = V.VFS(profile=a.profile, game_dir=a.game)
    target = a.animfile
    if a.proto:
        import proto_resolve
        target = proto_resolve.subject(fs, proto=a.proto)['animfile']
    if not target:
        ap.error('an animfile or --proto is needed')
    s = AnimfileSet(fs, target, bones=Gr2Bones(fs) if a.bones else None)
    if a.json:
        out = s.to_json()
        out.update(composition=s.composition(), warnings=fs.warnings, provenance=fs.provenance.records)
        sys.stdout.write(C.json_text(out))
    else:
        print('\n'.join(summary(s)))
        print('logic: %s' % s.logic['types'])
        for w in fs.warnings:
            print('warning %-34s %s: %s' % (w['code'], w['path'], w['message']))
    return 0


if __name__ == '__main__':
    sys.exit(main())
