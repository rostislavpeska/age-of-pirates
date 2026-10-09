"""Assembly gate: a roof (or any declared assembly) is baked as ONE scope, never one part at a time.

Owner, 2026-10-09: "the roof bottom should always be baked together - possibly also the ridges". Two prose rules
already said so (this skill, step 6; korean-architecture roof-ends.md "a field-only normal bake is not a finished
eave") and a field-only roof pilot was still baked. This gate makes it mechanical; bake_owner_maps.py runs it before
any preflight or HIGH load.

A recipe whose scoped faces include a roof material (plan `material` containing "roof", any case) must declare
`assembly`: a spec path (JSON) or an inline spec:
  {"name": "...",
   "parts": {"field":  {"materials": ["roof_field", "ROOF_TILE"], "bake": "high"},
             "front":  {"materials": ["roof_end_receiver"], "bake": "high", "opacity": "derived from the front HIGH"},
             "soffit": {"materials": ["soffit_rafters"], "bake": "none", "reason": "no relief; assembly AO"}, ...},
   "absent": {"caps": "this building has no caps (owner-approved design)"}}     # absent may also sit in the recipe
Rules (all must hold):
  1. every scoped face's material belongs to a declared part (no unknown roof roles);
  2. every `high` part has owner faces in the plan, unless declared absent with a reason;
  3. EVERY owner face of a `high` part (all sources, all pages) is in the scope - a page left out of `pages` or a
     part left out of the regions fails;
  4. every `none` part carries a reason; absent parts carry a reason.
`python assembly_scope.py <recipe.json>` prints the verdict (exit 1 on FAIL). Scope = which faces bake together; it
does not judge relief quality, opacity values or appearance - those stay with their own checks and the owner.
"""
import json
import sys
from pathlib import Path


def _spec(cfg, base):
    a = cfg.get('assembly')
    if isinstance(a, str):
        p = Path(a)
        if not p.is_absolute():
            p = Path(base) / p
        return json.loads(p.read_text()), str(p)
    return a, 'inline'


def is_roof(material):
    return 'roof' in str(material or '').lower()


def check(cfg, plan, base='.'):
    """cfg: bake recipe; plan: {face_key: {owner, page, material}}. Returns {verdict, errors, parts, spec}."""
    regions = (cfg.get('scope') or {}).get('regions') or []
    scoped = {f for r in regions for f in r.get('faces', [])}
    if not any(is_roof((plan.get(f) or {}).get('material')) for f in scoped):
        return {'verdict': 'PASS', 'errors': [], 'parts': {}, 'spec': None, 'note': 'no roof material in scope'}
    errors = []
    spec, where = _spec(cfg, base)
    if not isinstance(spec, dict) or not isinstance(spec.get('parts'), dict) or not spec['parts']:
        return {'verdict': 'FAIL', 'spec': where, 'parts': {},
                'errors': ['roof scope without a declared assembly: declare the whole roof (field, eave fronts, undersides, '
                           'caps/ridges, soffit) as one recipe - owner 2026-10-09 "the roof bottom should always be baked together"']}
    absent = dict(spec.get('absent') or {}); absent.update(cfg.get('assembly_absent') or {})
    mat_part = {}
    for name, part in spec['parts'].items():
        mats = part.get('materials') or []
        if not mats:
            errors.append(f'{name}: no materials declared')
        if part.get('bake') not in ('high', 'none'):
            errors.append(f'{name}: bake must be "high" or "none"')
        if part.get('bake') == 'none' and not str(part.get('reason') or '').strip():
            errors.append(f'{name}: a "none" part needs a reason')
        for m in mats:
            mat_part[str(m).lower()] = name
    for name, why in absent.items():
        if not str(why or '').strip():
            errors.append(f'{name}: absent without a reason')
    sources = set((cfg.get('sources') or {}).keys())
    in_sources = lambda k: not sources or k.rsplit(':', 1)[0] in sources
    report = {}
    for f in sorted(scoped):
        m = str((plan.get(f) or {}).get('material') or '').lower()
        if m not in mat_part and (is_roof(m) or m):
            errors.append(f'scoped face {f}: material {m!r} is not a declared assembly part')
            break
    for name, part in spec['parts'].items():
        mats = {str(m).lower() for m in part.get('materials') or []}
        owners = [k for k, e in plan.items() if in_sources(k) and e.get('owner') and str(e.get('material') or '').lower() in mats]
        got = [k for k in owners if k in scoped]
        report[name] = {'bake': part.get('bake'), 'owner_faces': len(owners), 'in_scope': len(got),
                        'pages': sorted({str(plan[k].get('page')) for k in owners})}
        if part.get('bake') != 'high':
            continue
        if not owners:
            if name not in absent:
                errors.append(f'{name}: no owner faces in this plan - add its source object or declare it absent with a reason')
            continue
        missing = [k for k in owners if k not in scoped]
        if missing:
            pages = sorted({str(plan[k].get('page')) for k in missing})
            errors.append(f'{name}: {len(missing)} of {len(owners)} owner faces are not in the scope (pages {pages}) - '
                          f'the part is baked with the rest of the roof or not at all')
    return {'verdict': 'FAIL' if errors else 'PASS', 'errors': errors, 'parts': report, 'spec': where,
            'scope': 'which faces bake together; relief/opacity/appearance are separate checks'}


if __name__ == '__main__':
    rp = Path(sys.argv[1]); cfg = json.loads(rp.read_text())
    plan = json.loads(Path(cfg['plan']).read_text())['faces']
    r = check(cfg, plan, rp.parent)
    print(json.dumps(r, indent=2)); raise SystemExit(r['verdict'] != 'PASS')
