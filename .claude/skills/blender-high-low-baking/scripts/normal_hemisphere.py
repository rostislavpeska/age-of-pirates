"""Bounded tangent-normal check; input NPZ: normal(H,W,3), used(H,W), opacity(H,W)."""
import argparse
import json
import numpy as np


def assess(normal, used, opacity, tolerance=0.02):
    n = np.asarray(normal, dtype=float)
    used = np.asarray(used, dtype=bool)
    opacity = np.asarray(opacity, dtype=float)
    if n.shape != used.shape + (3,) or opacity.shape != used.shape:
        raise ValueError('Normal, coverage and opacity dimensions differ')
    core = used & (opacity >= 0.999)
    finite = np.isfinite(n).all(axis=-1)
    negative = core & finite & (n[..., 2] < -tolerance)
    length = np.linalg.norm(n, axis=-1)
    invalid = core & (~finite | (np.abs(length - 1) > 0.05))
    return {'status': 'FAIL' if negative.any() or invalid.any() or not core.any() else 'PASS',
            'opaque_pixels': int(core.sum()), 'negative_z_pixels': int(negative.sum()),
            'invalid_vector_pixels': int(invalid.sum()), 'z_tolerance': tolerance,
            'scope': 'opaque tangent hemisphere and vector validity; not visual or engine approval'}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('input'); parser.add_argument('--out', required=True)
    args = parser.parse_args()
    with np.load(args.input) as data:
        report = assess(data['normal'], data['used'], data['opacity'])
    with open(args.out, 'w', encoding='utf-8') as out:
        json.dump(report, out, indent=2)
    print(json.dumps(report))
    raise SystemExit(0 if report['status'] == 'PASS' else 1)
