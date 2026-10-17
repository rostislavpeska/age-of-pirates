"""Check that declared target regions visibly respond to a player-colour change.

Matched camera, lighting and geometry are required. This detects an inert preview
control; it is not proof of runtime shader parity or absence of mask leakage.
"""
import argparse
import hashlib
import json
from pathlib import Path
import numpy as np
from PIL import Image


def check(a, b, regions, threshold=12, minimum=100):
    if a.shape != b.shape or a.ndim != 3 or a.shape[2] != 3:
        raise ValueError('matched RGB image dimensions required')
    changed = np.max(np.abs(a.astype(float) - b.astype(float)), axis=2) > threshold
    rows = []
    for name, rect in regions.items():
        x, y, x1, y1 = rect
        if not (0 <= x < x1 <= a.shape[1] and 0 <= y < y1 <= a.shape[0]):
            raise ValueError('invalid target rectangle: ' + name)
        n = int(changed[y:y1, x:x1].sum())
        rows.append({'target': name, 'rectangle': rect, 'changed_pixels': n, 'pass': n >= minimum})
    if not rows:
        raise ValueError('at least one independently declared target region required')
    return {'pass': all(r['pass'] for r in rows), 'regions': rows,
            'threshold_byte_values': threshold, 'minimum_pixels': minimum,
            'limitation': 'Responsiveness only; geometry/material binding and runtime proof are separate.'}


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('first'); ap.add_argument('second'); ap.add_argument('--regions', required=True)
    ap.add_argument('--out', required=True); ap.add_argument('--threshold', type=float, default=12)
    ap.add_argument('--minimum', type=int, default=100); args = ap.parse_args()
    paths = [Path(args.first), Path(args.second)]
    arrays = [np.asarray(Image.open(p).convert('RGB')) for p in paths]
    report = check(*arrays, json.loads(Path(args.regions).read_text()), args.threshold, args.minimum)
    report['inputs'] = [{'path': str(p), 'sha256': hashlib.sha256(p.read_bytes()).hexdigest()} for p in paths]
    Path(args.out).write_text(json.dumps(report, indent=2))
    print('PLAYER_RENDER_RESPONSE', 'PASS' if report['pass'] else 'FAIL')
    return 0 if report['pass'] else 3


if __name__ == '__main__':
    raise SystemExit(main())
