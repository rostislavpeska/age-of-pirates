"""Phase handoff manifests (see ../references/handoff-contract.md).

python handoff.py write SPEC.json [--out DIR/HANDOFF.json] [--owner-messages TRACKER.json] [--profiles JSON]
                                                             hash canonical paths, validate inputs, write
python handoff.py check HANDOFF.json                         re-hash canonical paths, report drift (exit 3)
python handoff.py chain DIR                                  list every HANDOFF.json below DIR by phase
Paths inside a handoff are relative to its own folder (absolute paths are allowed and kept).
A 03_uv handoff in review / accepted records `density` (the metrics block of density_floor.py) and `page_budget`
({pages: [{name, size}]}); the universal UV density floor and the page ceiling must pass before the UV freeze (owner
2026-09-30, KTC-164/165). Nothing in them is self-declared (INC-034): the class, its confirmation and the ceiling come
from the project's model profiles (--profiles, default Age of Pirates scripts/havok/gr2_lint_profiles.json) and the
confirmation is verified against the owner's message store (--owner-messages, else the profiles' tools.owner_messages);
the density block names the canonical file it was measured on (source.sha256) in the game's unit; the budget pages are
the measured density pages. An owner waiver of the floor (`density_waivers`) counts only with his message store and when
it is about this floor and this model (INC-036).
"""
import argparse
import datetime
import hashlib
import importlib.util
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
PROFILES = HERE.parents[3] / 'scripts' / 'havok' / 'gr2_lint_profiles.json'   # the consuming project's ceilings
PHASES = ['01_geometry', '02_material_split', '03_uv', '04_bake', '05_sources', '06_surface', '07_compose',
          '08_review', '09_painter', '10_export']
STATUS = ['wip', 'review', 'accepted', 'superseded']


def sha(p):
    h = hashlib.sha256()
    with open(p, 'rb') as f:
        for b in iter(lambda: f.read(1 << 20), b''):
            h.update(b)
    return h.hexdigest()


def resolve(base, p):
    q = Path(p); return q if q.is_absolute() else (base / q)


def project_lint(profiles_path):
    """the project's model lint next to its profiles (gr2_lint.py): model_class, class_confirmation, owner store"""
    lint = Path(profiles_path).parent / 'gr2_lint.py'
    spec = importlib.util.spec_from_file_location('gr2_lint_for_handoff', str(lint))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def model_profile(GL, profiles, model, name=None):
    """the profile that holds the model: named in the spec, the model's own, or the one listing it"""
    ps = profiles.get('profiles') or {}
    for n in [name, model, GL.model_of(model)]:
        if n and n in ps:
            return GL.resolve_profile(profiles, n)
    for n, v in ps.items():
        tb = v.get('texture_budget') or {}
        if model in (tb.get('per_model') or {}) or model in (tb.get('models') or []):
            return GL.resolve_profile(profiles, n)
    return None


def page_budget_errors(spec, owner_messages=None, profiles_path=None):
    """(errors, profile) of a 03_uv page budget (INC-034): the class, its owner confirmation and the ceiling are the
    project's (never the spec's), the confirmation resolves to the owner's message about this class and model, the pages
    fit the ceiling and are the pages the density block measured"""
    pb, model, block = spec.get('page_budget'), spec.get('model'), spec.get('density')
    if not isinstance(pb, dict):
        return ['03_uv: no page_budget {pages: [{name, size}]} recorded'], None
    path = Path(profiles_path or PROFILES)
    try:
        profiles = json.loads(path.read_text(encoding='utf-8'))
        GL = project_lint(path)
    except Exception as e:                                           # no project ceilings: never a pass
        return [f'page_budget: the project ceilings {path} cannot be read ({type(e).__name__}: {e})'], None
    prof = model_profile(GL, profiles, model, spec.get('profile'))
    if prof is None:
        return [f'page_budget: {model} has no profile in {path.name}: the owner sets its class per model'], None
    e = []
    entry = GL.model_class(prof, model)
    classes = (profiles.get('texture_budget') or {}).get('classes') or {}
    cls, who = entry.get('class'), entry.get('confirmed_by')
    if not cls or cls not in classes:
        return [f"page_budget: no texture class recorded for {model} ({entry.get('why') or 'the owner sets it'})"], prof
    if not who:
        e.append(f"page_budget: class {cls} of {model} not confirmed by the owner "
                 f"({entry.get('why') or entry.get('status') or 'proposed'})")
    else:
        store = Path(owner_messages) if owner_messages else GL.owner_message_store(prof)
        ok, why = GL.class_confirmation(entry, cls, prof, model, store=store)
        if ok is not True:
            e.append(f'page_budget: class {cls} of {model} not confirmed by the owner: {why}')
    cap = sorted(classes[cls].get('ceiling') or [], reverse=True)
    for k, want in (('class', cls), ('confirmed_by', who), ('ceiling', cap)):
        got = pb.get(k)
        if got is not None and (sorted(got, reverse=True) if k == 'ceiling' and isinstance(got, list) else got) != want:
            e.append(f"page_budget: the spec's {k} {got} is not the project's {want} for {model} ({path.name})")
    pages = pb.get('pages')
    if not (isinstance(pages, list) and pages and all(isinstance(x, dict) and isinstance(x.get('size'), int)
                                                      and x.get('name') for x in pages)):
        return e + ['page_budget: pages must list {name, size} for every runtime page'], prof
    sizes = sorted((x['size'] for x in pages), reverse=True)
    if len(sizes) > len(cap):
        e.append(f'page_budget: {len(sizes)} pages over the {cls} ceiling of {len(cap)} ({cap})')
    e += [f'page_budget: a {sz} page over the ceiling slot {c}' for sz, c in zip(sizes, cap) if sz > c]
    if isinstance(block, dict):
        measured = {str(k): max(int(v.get('W') or 0), int(v.get('H') or 0)) for k, v in (block.get('pages') or {}).items()
                    if isinstance(v, dict)}
        measured.update({str(k): None for k in list(block.get('unmeasured') or {}) + list(block.get('exempt') or {})})
        listed = {str(x['name']): x['size'] for x in pages}
        if set(listed) != set(measured) or any(measured[k] not in (None, listed[k]) for k in listed if k in measured):
            e.append(f'page_budget: the pages {sorted(listed.items())} are not the pages the density block measured '
                     f'{sorted(measured.items(), key=str)}')
    return e, prof


def density_errors(spec, owner_messages=None, prof=None):
    """the universal UV density floor on the recorded density block (density_floor.py); a waiver must name the floor
    and the model (the profile's names are its aliases)"""
    sys.path.insert(0, str(HERE))
    import density_floor as DF
    block = spec.get('density')
    try:
        floor = DF.load_floor((block or {}).get('game') if isinstance(block, dict) else None)
    except DF.FloorError as e:
        return [f'density: {e}']
    verify = DF.verifier(owner_messages) if owner_messages else None
    res = DF.evaluate(block, floor, spec.get('density_waivers') or [], verify, spec.get('model'),
                      aliases=(prof or {}).get('names') or ())
    if res['status'] == 'FAIL':
        return [f"density floor FAIL ({floor['game']}): {f['text']}" for f in res['findings']] + \
            [f'density: {n}' for n in res['notes']]
    return []


def density_source_errors(spec):
    """the density block is bound to this handoff's canonical UV (INC-034): its source.sha256 is the hash of one of the
    canonical files, so a block measured on another model or an older UV cannot be recorded"""
    block = spec.get('density')
    if not isinstance(block, dict):
        return []
    src = block.get('source') if isinstance(block.get('source'), dict) else {}
    shas = {c.get('sha256'): role for role, c in (spec.get('canonical') or {}).items() if c.get('sha256')}
    if not src.get('sha256'):
        return ['density: the block names no source {file, sha256}: measure the canonical UV with density_floor.py']
    if src['sha256'] not in shas:
        return [f"density: measured on {src.get('file')} ({str(src['sha256'])[:12]}), which is none of this handoff's "
                'canonical files: measure the canonical UV again']
    return []


def write(spec_path, out, owner_messages=None, profiles=None):
    spec = json.loads(Path(spec_path).read_text()); out = Path(out) if out else Path(spec_path).with_name('HANDOFF.json')
    base = out.parent; errors = []
    if spec.get('phase') not in PHASES:
        errors.append(f'phase must be one of {PHASES}')
    if spec.get('status') not in STATUS:
        errors.append(f'status must be one of {STATUS}')
    for k in ('model', 'producer', 'canonical', 'next'):
        if not spec.get(k):
            errors.append(f'missing {k}')
    for role, c in spec.get('canonical', {}).items():
        p = resolve(base, c['path'])
        if not p.exists():
            errors.append(f'canonical {role}: missing {p}')
        elif p.is_file():
            c['sha256'] = sha(p); c['bytes'] = p.stat().st_size
    if spec.get('phase') == '03_uv' and spec.get('status') in ('review', 'accepted'):     # before the UV freeze
        budget, prof = page_budget_errors(spec, owner_messages, profiles)
        errors += budget + density_source_errors(spec) + density_errors(spec, owner_messages, prof)
    for inp in spec.get('inputs', []):
        h = resolve(base, inp['handoff'])
        if not h.exists():
            errors.append(f'input handoff missing: {h}')
        else:
            up = json.loads(h.read_text()); inp['status'] = up.get('status'); inp['sha256'] = sha(h)
            if up.get('status') not in ('review', 'accepted'):
                errors.append(f'input {h} has status {up.get("status")}')
    if errors:
        print('HANDOFF INVALID', *errors, sep='\n  '); return 3
    spec['schema'] = 1; spec.setdefault('date', datetime.date.today().isoformat())
    out.write_text(json.dumps(spec, indent=2)); print('HANDOFF WRITTEN', out); return 0


def check(path):
    path = Path(path); h = json.loads(path.read_text()); drift = []
    for role, c in h.get('canonical', {}).items():
        p = resolve(path.parent, c['path'])
        if not p.exists():
            drift.append(f'{role}: missing')
        elif c.get('sha256') and p.is_file() and sha(p) != c['sha256']:
            drift.append(f'{role}: changed since the handoff')
    print('HANDOFF', h.get('phase'), h.get('status'), 'OK' if not drift else 'DRIFT', *drift, sep='\n  ' if drift else ' ')
    return 3 if drift else 0


def chain(root):
    rows = []
    for p in Path(root).rglob('HANDOFF.json'):
        h = json.loads(p.read_text()); rows.append((PHASES.index(h['phase']) if h.get('phase') in PHASES else 99, h.get('phase'), h.get('status'), h.get('producer'), str(p)))
    for r in sorted(rows):
        print(f'{r[1]:18} {r[2]:10} {r[3]:10} {r[4]}')
    return 0


if __name__ == '__main__':
    ap = argparse.ArgumentParser(); sub = ap.add_subparsers(dest='cmd', required=True)
    w = sub.add_parser('write'); w.add_argument('spec'); w.add_argument('--out'); w.add_argument('--owner-messages')
    w.add_argument('--profiles', help='the project model profiles with the owner-confirmed texture classes')
    c = sub.add_parser('check'); c.add_argument('handoff')
    ch = sub.add_parser('chain'); ch.add_argument('root')
    a = ap.parse_args()
    sys.exit(write(a.spec, a.out, a.owner_messages, a.profiles) if a.cmd == 'write' else check(a.handoff)
             if a.cmd == 'check' else chain(a.root))
