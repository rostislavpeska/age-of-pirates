"""Check every UV reader before painting and against decoded runtime alpha.

The geometry adapter supplies independent samples, including reused faces. NPZ:
pixel[N,2] (top-left y,x), expected[N], interior[N], reader[N], inventory[K],
size[2]. Boundary samples are counted but cannot create an interior failure.
Never build expected/interior/inventory from candidate alpha or owner masks.
Use fixed_alpha for an immutable protected page: its values are input constraints,
not a proposed texture. A FAIL is a proof for the supplied contour and samples,
not a proof that every possible contour is impossible. Witnesses identify the
contradictory reader requirements without silently choosing minimum/maximum alpha.

Audit: 2026-10-13-codex-roof-civic-readers-01 (KTC-377, INC-308).
"""
import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image


def measure(data, alpha=None, fixed_alpha=None):
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
    opaque_count = np.bincount(index[interior & expected], minlength=opaque.size)
    cut_count = np.bincount(index[interior & ~expected], minlength=opaque.size)
    result = {'status': 'PASS', 'samples': n, 'interior_samples': int(interior.sum()),
              'readers': len(inventory), 'conflicting_texels': int(conflicts.sum()),
              'conflict_samples': int((interior & conflicts[index]).sum()),
              'mode': 'preflight' if alpha is None else 'decoded-alpha', 'per_reader': [],
              'minimum_unavoidable_sample_errors': int(np.minimum(opaque_count, cut_count).sum()),
              'conflict_witnesses': [], 'fixed_alpha_witnesses': []}
    # Bound report size, retaining exact totals above. The two sample indices
    # let adapters recover their independent geometry/UV evidence from the NPZ.
    for texel in np.flatnonzero(conflicts)[:16]:
        a = int(np.flatnonzero(interior & expected & (index == texel))[0])
        b = int(np.flatnonzero(interior & ~expected & (index == texel))[0])
        result['conflict_witnesses'].append({
            'pixel': pixel[a].tolist(), 'opaque_sample': a, 'cut_sample': b,
            'opaque_reader': str(reader[a]), 'cut_reader': str(reader[b])})
    fixed_bad = np.zeros(n, bool)
    if fixed_alpha is not None:
        fixed_alpha = np.asarray(fixed_alpha)
        if fixed_alpha.shape != size:
            raise ValueError('Fixed alpha dimensions differ')
        fixed_actual = fixed_alpha[pixel[:, 0], pixel[:, 1]] >= 128
        fixed_bad = (fixed_actual != expected) & interior
        result['fixed_alpha_mismatch'] = int(fixed_bad.sum())
        result['fixed_alpha_mismatch_texels'] = int(np.unique(index[fixed_bad]).size)
        result['minimum_unavoidable_sample_errors'] = int(fixed_bad.sum())
        result['mode'] += '+fixed-alpha'
        for sample in np.flatnonzero(fixed_bad)[:16]:
            result['fixed_alpha_witnesses'].append({
                'sample': int(sample), 'pixel': pixel[sample].tolist(),
                'reader': str(reader[sample]), 'expected_opaque': bool(expected[sample]),
                'fixed_opaque': bool(fixed_actual[sample])})
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
        if fixed_alpha is not None:
            row['fixed_alpha_mismatch'] = int((select & fixed_bad).sum())
        result['per_reader'].append(row)
    if (result['conflicting_texels'] or result.get('interior_mismatch', 0)
            or result.get('fixed_alpha_mismatch', 0)):
        result['status'] = 'FAIL'
    return result


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('samples')
    p.add_argument('--alpha', help='Decoded L or RGBA image; omit for pre-bake compatibility')
    p.add_argument('--fixed-alpha', help='Immutable protected-page L/RGBA alpha constraint')
    p.add_argument('--out', required=True)
    args = p.parse_args()
    try:
        images = []
        for path in (args.alpha, args.fixed_alpha):
            if not path:
                images.append(None)
                continue
            image = Image.open(path)
            if image.mode not in ('L', 'RGBA'):
                raise ValueError('Expected L alpha or RGBA decoded image')
            images.append(np.array(image if image.mode == 'L' else image.getchannel('A')))
        with np.load(args.samples, allow_pickle=False) as data:
            result = measure(data, *images)
    except (ValueError, KeyError, OSError) as error:
        result = {'status': 'INVALID', 'error': str(error)}
    Path(args.out).write_text(json.dumps(result, indent=2), encoding='utf-8')
    print(json.dumps({k: v for k, v in result.items() if k != 'per_reader'}))
    return {'PASS': 0, 'FAIL': 1, 'INVALID': 2}[result['status']]


if __name__ == '__main__':
    raise SystemExit(main())
