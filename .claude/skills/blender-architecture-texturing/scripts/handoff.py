"""Phase handoff manifests (see ../references/handoff-contract.md).

python handoff.py write SPEC.json [--out DIR/HANDOFF.json]   hash canonical paths, validate inputs, write
python handoff.py check HANDOFF.json                         re-hash canonical paths, report drift (exit 3)
python handoff.py chain DIR                                  list every HANDOFF.json below DIR by phase
Paths inside a handoff are relative to its own folder (absolute paths are allowed and kept).
"""
import argparse
import datetime
import hashlib
import json
import sys
from pathlib import Path

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


def write(spec_path, out):
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
    w = sub.add_parser('write'); w.add_argument('spec'); w.add_argument('--out')
    c = sub.add_parser('check'); c.add_argument('handoff')
    ch = sub.add_parser('chain'); ch.add_argument('root')
    a = ap.parse_args()
    sys.exit(write(a.spec, a.out) if a.cmd == 'write' else check(a.handoff) if a.cmd == 'check' else chain(a.root))
