"""Check every UV reader before painting and against decoded runtime alpha.

The geometry adapter supplies independent samples, including reused faces. NPZ:
pixel[N,2] (top-left y,x), expected[N], interior[N], reader[N], inventory[K],
size[2]. Boundary samples are counted but cannot create an interior failure.
Never build expected/interior/inventory from candidate alpha or owner masks.
"""
import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image


def measure(data, alpha=None):
    pixel = np.asarray(data['pixel'])
    expected = np.asarray(data['expected'], bool)
    interior = np.asarray(data['interior'], bool)
    reader = np.asarray(data['reader']).astype(str)
    inventory = np.asarray(data['inventory']).astype(str)
    size = tuple(int(x) for x in data['size'])
    n = len(pixel)
    if len(size) != 2 or min(size) < 1 or pixel.shape != (n, 2):
        raise ValueError('Invalid page or pixel shape')
    if not np.issubdtype(pixel.dtype, np.integer):
        raise ValueError('Pixel indices must be integers')
    if any(a.shape != (n,) for a in [expected, interior, reader]) or n == 0:
        raise ValueError('Missing or unequal independent samples')
    if not len(inventory) or set(reader) != set(inventory):
        raise ValueError('Reader inventory is incomplete or contains unaccounted faces')
    if np.any(pixel < 0) or np.any(pixel >= np.array(size)):
        raise ValueError('Sample outside page')
    if not interior.any():
        raise ValueError('No interior evidence')
    index = pixel[:, 0] * size[1] + pixel[:, 1]
    opaque = np.zeros(size[0] * size[1], bool)
    transparent = opaque.copy()
    opaque[index[interior & expected]] = True
    transparent[index[interior & ~expected]] = True
    conflicts = opaque & transparent
    result = {'status': 'PASS', 'samples': n, 'interior_samples': int(interior.sum()),
              'readers': len(inventory), 'conflicting_texels': int(conflicts.sum()),
              'conflict_samples': int((interior & conflicts[index]).sum()),
              'mode': 'preflight' if alpha is None else 'decoded-alpha', 'per_reader': []}
    if alpha is not None:
        alpha = np.asarray(alpha)
        if alpha.shape != size:
            raise ValueError('Decoded alpha dimensions differ')
        actual = alpha[pixel[:, 0], pixel[:, 1]] >= 128
        bad = (actual != expected) & interior
        result['interior_mismatch'] = int(bad.sum())
    for name in inventory:
        select = reader == name
        row = {'reader': str(name), 'samples': int(select.sum()),
               'interior_samples': int((select & interior).sum()),
               'conflicts': int((select & interior & conflicts[index]).sum())}
        if alpha is not None:
            row['interior_mismatch'] = int((select & bad).sum())
        result['per_reader'].append(row)
    if result['conflicting_texels'] or result.get('interior_mismatch', 0):
        result['status'] = 'FAIL'
    return result


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('samples')
    p.add_argument('--alpha', help='Decoded L or RGBA image; omit for pre-bake compatibility')
    p.add_argument('--out', required=True)
    args = p.parse_args()
    try:
        alpha = None
        if args.alpha:
            image = Image.open(args.alpha)
            if image.mode not in ('L', 'RGBA'):
                raise ValueError('Expected L alpha or RGBA decoded image')
            alpha = np.array(image if image.mode == 'L' else image.getchannel('A'))
        with np.load(args.samples, allow_pickle=False) as data:
            result = measure(data, alpha)
    except (ValueError, KeyError, OSError) as error:
        result = {'status': 'INVALID', 'error': str(error)}
    Path(args.out).write_text(json.dumps(result, indent=2), encoding='utf-8')
    print(json.dumps({k: v for k, v in result.items() if k != 'per_reader'}))
    return {'PASS': 0, 'FAIL': 1, 'INVALID': 2}[result['status']]


if __name__ == '__main__':
    raise SystemExit(main())
