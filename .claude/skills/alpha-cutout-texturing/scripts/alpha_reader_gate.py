"""Check every UV reader before painting and against decoded runtime alpha.

The geometry adapter supplies independent samples, including reused faces. NPZ:
pixel[N,2] (top-left y,x), expected[N], interior[N], reader[N], inventory[K],
size[2]. Boundary samples are counted but cannot create an interior failure.
Never build expected/interior/inventory from candidate alpha or owner masks.
Python callers may pass certificates and certificate_inputs for zero-centre
readers; see verify_certificates. This narrow route is not exposed by the CLI.
Certificate cell constraints are reported separately, never as centre samples.
Use fixed_alpha for an immutable protected page: its values are input constraints,
not a proposed texture. A FAIL is a proof for the supplied contour and samples,
not a proof that every possible contour is impossible. Witnesses identify the
contradictory reader requirements without silently choosing minimum/maximum alpha.

Audit: 2026-10-13-codex-roof-civic-readers-01 (KTC-377, INC-308).
Certificate integration: 2026-10-13-codex-market-certificate-01.
"""
import argparse
import hashlib
import inspect
import json
from pathlib import Path

import numpy as np
from PIL import Image


def triangle_cells(uv, size):
    """Positive-area cell intersections, without manufacturing centre samples."""
    triangle = np.asarray(uv, float) * [size[1], size[0]]
    if triangle.shape != (3, 2) or not np.isfinite(triangle).all():
        raise ValueError('Invalid certificate UV triangle')
    if np.any(triangle < 0) or np.any(triangle > [size[1], size[0]]):
        raise ValueError('Certificate UV outside page')
    a, b = triangle[1:] - triangle[0]
    if abs(a[0] * b[1] - a[1] * b[0]) == 0:
        raise ValueError('Degenerate certificate UV triangle')
    cells = []
    lo = np.floor(triangle.min(0)).astype(int)
    hi = np.ceil(triangle.max(0)).astype(int)
    if np.prod(hi - lo) > 4096:
        raise ValueError('Certificate exceeds bounded subtexel verification scope')
    for y in range(lo[1], hi[1]):
        for x in range(lo[0], hi[0]):
            # Any centre in the closed triangle invalidates this narrow route.
            bary = np.linalg.solve(np.column_stack([a, b]), [x + .5, y + .5] - triangle[0])
            if min(bary) >= 0 and sum(bary) <= 1:
                raise ValueError('Certificate triangle has a texel centre')
            polygon = list(triangle)
            for axis, boundary, sign in [(0, x, 1), (0, x + 1, -1),
                                         (1, y, 1), (1, y + 1, -1)]:
                clipped = []
                for start, end in zip(polygon, polygon[1:] + polygon[:1]):
                    d0, d1 = sign * (start[axis] - boundary), sign * (end[axis] - boundary)
                    if d0 >= 0:
                        clipped.append(start)
                    if (d0 >= 0) != (d1 >= 0):
                        clipped.append(start + (end - start) * d0 / (d0 - d1))
                polygon = clipped
            if len(polygon) >= 3:
                # Local coordinates avoid cancellation for small atlas triangles.
                p = np.asarray(polygon) - [x, y]
                area = abs(np.sum(p[:, 0] * np.roll(p[:, 1], -1)
                                  - p[:, 1] * np.roll(p[:, 0], -1))) / 2
                if area > 0:
                    cells.append([size[0] - 1 - y, x])
    if not cells:
        raise ValueError('Certificate triangle has no positive cell coverage')
    return sorted(cells)


def verify_certificates(certificates, current, size, missing):
    """Verify a narrow constant-station opaque proof against independent inputs.

    Audit: 2026-10-13-codex-market-certificate-01. `current` is supplied by the
    trusted geometry adapter, NEVER decoded from the certificate: page identity,
    source_paths (mesh/frame/contour/page and other dependencies), every triangle
    of every missing reader, and the actual source-backed contour callable
    (lateral, first, pitch, thickness). Each triangle supplies reader, triangle_id,
    co, uv, frame(axis/top/bottom/first/pitch). Certificate duplicates those exact
    identities plus source_hashes, size and cells_yx. The gate rehashes sources,
    evaluates the constant contour independently, and recomputes the affine bound.
    Adapter ownership includes proving triangle/source/material correspondence;
    a matching hash alone does not establish that correspondence.
    """
    if not certificates:
        if missing:
            raise ValueError('Reader inventory is incomplete or contains unaccounted faces')
        return []
    if not current or not missing:
        raise ValueError('Certificates need independent current inputs and missing readers')
    paths = current['source_paths']
    if not {'mesh', 'frame', 'contour', 'page'} <= set(paths):
        raise ValueError('Certificate source identities are incomplete')
    hashes = {name: hashlib.sha256(Path(path).read_bytes()).hexdigest()
              for name, path in paths.items()}
    contour = current['contour']
    if Path(inspect.getsourcefile(contour)).resolve() != Path(paths['contour']).resolve():
        raise ValueError('Contour callable differs from identified source')
    triangles = current['triangles']
    by_id = {row['triangle_id']: row for row in triangles}
    if len(by_id) != len(triangles) or {row['reader'] for row in triangles} != missing:
        raise ValueError('Independent missing-reader triangle inventory differs')
    seen, verified = set(), []
    for certificate in certificates:
        key = certificate['triangle_id']
        if key in seen or key not in by_id:
            raise ValueError('Duplicate or unknown certificate triangle')
        seen.add(key)
        row = by_id[key]
        if (certificate['schema'] != 'constant-station-opaque-v1'
                or certificate['page'] != current['page']
                or certificate['size'] != list(size)
                or certificate['reader'] != row['reader']
                or certificate['source_hashes'] != hashes
                or not np.array_equal(certificate['co'], row['co'])
                or not np.array_equal(certificate['uv'], row['uv'])):
            raise ValueError('Wrong or stale certificate source/reader/triangle/UV/page identity')
        co = np.asarray(row['co'], float)
        fr = row['frame']
        axis = fr['axis']
        top, bottom = np.asarray(fr['top'], float), np.asarray(fr['bottom'], float)
        if (co.shape != (3, 3) or not np.isfinite(co).all() or axis not in (0, 1, 2)
                or top.ndim != 2 or top.shape[1] != 3 or bottom.shape != top.shape
                or len(top) < 2 or not np.isfinite(top).all() or not np.isfinite(bottom).all()
                or not np.all(np.diff(top[:, axis]) > 0)
                or np.ptp(co[:, axis]) != 0):
            raise ValueError('Certificate requires finite constant-station affine frame')
        station = co[0, axis]
        if not top[0, axis] <= station <= top[-1, axis]:
            raise ValueError('Certificate station outside frame')
        tp = np.array([np.interp(station, top[:, axis], top[:, j]) for j in range(3)])
        bt = np.array([np.interp(station, top[:, axis], bottom[:, j]) for j in range(3)])
        down = bt - tp
        thickness = np.linalg.norm(down)
        if not np.isfinite(thickness) or thickness <= 0:
            raise ValueError('Invalid certificate frame thickness')
        depth = (co - tp) @ (down / thickness)
        limit = np.asarray(contour(station, fr['first'], fr['pitch'], float(thickness)))
        if limit.shape != () or not np.isfinite(limit) or not depth.max() < float(limit):
            raise ValueError('Continuous opaque bound failed')
        cells = triangle_cells(row['uv'], size)
        if certificate['cells_yx'] != cells:
            raise ValueError('Incomplete or wrong certificate cell coverage')
        verified.append(dict(reader=row['reader'], triangle_id=key, cells_yx=cells,
                             minimum_depth=float(depth.min()), maximum_depth=float(depth.max()),
                             contour_limit=float(limit), source_hashes=hashes,
                             scope='constant-station whole-triangle opaque; base cells only'))
    if seen != set(by_id):
        raise ValueError('Missing certificate for independent triangle inventory')
    return verified


def measure(data, alpha=None, fixed_alpha=None, *, certificates=None, certificate_inputs=None):
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
    if any(a.shape != (n,) for a in [expected, interior, reader]):
        raise ValueError('Missing or unequal independent samples')
    if not len(inventory) or len(set(inventory)) != len(inventory) or not set(reader) <= set(inventory):
        raise ValueError('Reader inventory is incomplete or contains unaccounted faces')
    verified = verify_certificates(certificates, certificate_inputs, size,
                                   set(inventory) - set(reader))
    if np.any(pixel < 0) or np.any(pixel >= np.array(size)):
        raise ValueError('Sample outside page')
    if not interior.any() and not verified:
        raise ValueError('No interior evidence')
    index = pixel[:, 0] * size[1] + pixel[:, 1]
    opaque = np.zeros(size[0] * size[1], bool)
    transparent = opaque.copy()
    opaque[index[interior & expected]] = True
    transparent[index[interior & ~expected]] = True
    for proof in verified:
        for y, x in proof['cells_yx']:
            opaque[y * size[1] + x] = True
    conflicts = opaque & transparent
    opaque_count = np.bincount(index[interior & expected], minlength=opaque.size)
    cut_count = np.bincount(index[interior & ~expected], minlength=opaque.size)
    result = {'status': 'PASS', 'samples': n, 'interior_samples': int(interior.sum()),
              'readers': len(inventory), 'conflicting_texels': int(conflicts.sum()),
              'conflict_samples': int((interior & conflicts[index]).sum()),
              'mode': 'preflight' if alpha is None else 'decoded-alpha', 'per_reader': [],
              'minimum_unavoidable_sample_errors': int(np.minimum(opaque_count, cut_count).sum()),
              'conflict_witnesses': [], 'fixed_alpha_witnesses': []}
    result['certificates'] = verified
    result['certified_readers'] = len({proof['reader'] for proof in verified})
    result['certificate_cell_constraints'] = sum(len(proof['cells_yx']) for proof in verified)
    result['certificate_witnesses'] = []
    # Bound report size, retaining exact totals above. The two sample indices
    # let adapters recover their independent geometry/UV evidence from the NPZ.
    for texel in np.flatnonzero(conflicts)[:16]:
        owners = np.flatnonzero(interior & expected & (index == texel))
        if not len(owners):
            continue  # Distinct certificate witness below, never a fake sample.
        a = int(owners[0])
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
    certificate_fail = False
    for proof in verified:
        for y, x in proof['cells_yx']:
            failures = []
            if transparent[y * size[1] + x]:
                failures.append('shared-cut-reader')
            if alpha is not None and alpha[y, x] < 128:
                failures.append('decoded-alpha')
            if fixed_alpha is not None and fixed_alpha[y, x] < 128:
                failures.append('fixed-alpha')
            if failures:
                certificate_fail = True
                result['certificate_witnesses'].append(dict(reader=proof['reader'],
                    triangle_id=proof['triangle_id'], pixel=[y, x], failures=failures,
                    cut_samples=np.flatnonzero(interior & ~expected &
                                               (index == y * size[1] + x)).tolist()))
    for name in inventory:
        select = reader == name
        row = {'reader': str(name), 'samples': int(select.sum()),
               'interior_samples': int((select & interior).sum()),
               'conflicts': int((select & interior & conflicts[index]).sum())}
        row['certified_triangles'] = sum(proof['reader'] == name for proof in verified)
        if alpha is not None:
            row['interior_mismatch'] = int((select & bad).sum())
        if fixed_alpha is not None:
            row['fixed_alpha_mismatch'] = int((select & fixed_bad).sum())
        result['per_reader'].append(row)
    if (certificate_fail or result['conflicting_texels'] or result.get('interior_mismatch', 0)
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
