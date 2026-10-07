"""Exact protected-pixel gate. Config: checks[{before,after,allowed,protected_channels?}], out.

Allowed is an explicit binary mask in image coordinates, including approved gutters.
Channels use file RGB(A) order. PNG precision is preserved with OpenCV, including 16 bit.
Percentile comparison is unsuitable for this gate: even one changed protected sample fails.
"""
import argparse
import hashlib
import json
from pathlib import Path
import numpy as np


def compare(before, after, allowed, protected_channels=()):
    if before.shape != after.shape or before.dtype != after.dtype:
        raise ValueError('Image shape or precision mismatch')
    if before.ndim == 2:
        before, after = before[..., None], after[..., None]
    if before.ndim != 3 or allowed.shape != before.shape[:2] or allowed.dtype != bool:
        raise ValueError('Expected matching binary mask and image')
    if not np.isfinite(before).all() or not np.isfinite(after).all():
        raise ValueError('Nonfinite pixel')
    if allowed.all():
        raise ValueError('No protected pixels: scoped preservation is unassessable')
    channels = list(protected_channels)
    if any(not isinstance(c, int) or c < 0 or c >= before.shape[2] for c in channels):
        raise ValueError('Invalid protected channel')
    delta = np.abs(after.astype(np.float64) - before.astype(np.float64))
    outside = delta[~allowed]
    whole = delta[..., channels] if channels else np.zeros(1)
    maximum = max(float(outside.max()), float(whole.max()))
    return {'status': 'PASS' if maximum == 0 else 'FAIL',
            'protected_max': maximum,
            'outside_changed_pixels': int(np.any(delta > 0, axis=2)[~allowed].sum()),
            'protected_pixels': int((~allowed).sum()),
            'allowed_pixels': int(allowed.sum()),
            'protected_channels': channels}


def read(path):
    import cv2
    a = cv2.imread(str(path), cv2.IMREAD_UNCHANGED)
    if a is None:
        raise ValueError('Cannot read ' + str(path))
    if a.ndim == 3:
        a = a[..., [2, 1, 0, 3] if a.shape[2] == 4 else [2, 1, 0]]
    return a


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('config', type=Path)
    args = ap.parse_args()
    cfg = json.loads(args.config.read_text(encoding='utf-8'))
    rows = []
    for c in cfg['checks']:
        paths = {k: Path(c[k]) for k in ('before', 'after', 'allowed')}
        paths = {k: p if p.is_absolute() else args.config.parent / p for k, p in paths.items()}
        m = read(paths['allowed'])
        if m.ndim == 3:
            if not np.all(m == m[..., :1]):
                raise ValueError('Mask channels disagree')
            m = m[..., 0]
        if not np.isin(m, [0, np.iinfo(m.dtype).max]).all():
            raise ValueError('Allowed mask must be binary')
        result = compare(read(paths['before']), read(paths['after']), m > 0,
                         c.get('protected_channels', []))
        result.update(id=c.get('id', str(paths['after'])),
                      hashes={k: hashlib.sha256(p.read_bytes()).hexdigest() for k, p in paths.items()})
        rows.append(result)
    report = {'status': 'PASS' if rows and all(x['status'] == 'PASS' for x in rows) else 'FAIL', 'checks': rows}
    if cfg.get('out'):
        Path(cfg['out']).write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
    print(json.dumps(report, indent=2))
    return 0 if report['status'] == 'PASS' else 1


if __name__ == '__main__':
    raise SystemExit(main())
