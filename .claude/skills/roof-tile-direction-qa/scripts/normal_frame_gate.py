"""Reject an invalid diagnostic tangent frame before judging a normal map.

Inputs are per-triangle/per-corner world-space vectors and triangle UVs. This
validates the supplied frame, not a renderer's undocumented tangent convention.
NumPy is required on the inspection host, not inside the game.
"""
import numpy as np


def assess(positions, uv, normals, tangents, bitangents, *,
           orthogonal_tolerance=0.01, length_tolerance=0.01,
           minimum_uv_cosine=0.5):
    P, U, N, T, B = [np.asarray(x, dtype=float) for x in
                     (positions, uv, normals, tangents, bitangents)]
    if P.ndim != 3 or P.shape[1:] != (3, 3) or not len(P):
        raise ValueError('Expected nonempty triangle positions [triangle,corner,xyz]')
    if U.shape != P.shape[:2] + (2,) or any(x.shape != P.shape for x in (N, T, B)):
        raise ValueError('UVs and frame vectors must correspond to the same corners')
    if not all(np.isfinite(x).all() for x in (P, U, N, T, B)):
        raise ValueError('Finite input required')
    e1, e2 = P[:, 1] - P[:, 0], P[:, 2] - P[:, 0]
    u1, u2 = U[:, 1] - U[:, 0], U[:, 2] - U[:, 0]
    det = u1[:, 0] * u2[:, 1] - u1[:, 1] * u2[:, 0]
    valid = (abs(det) > 1e-12) & (np.linalg.norm(np.cross(e1, e2), axis=1) > 1e-12)
    if not valid.all():
        return {'status': 'FAIL', 'reason': 'degenerate geometry or UV triangle',
                'invalid_triangles': np.where(~valid)[0].tolist()}
    lengths = np.stack([np.linalg.norm(x, axis=2) for x in (N, T, B)])
    if (lengths < 1e-12).any():
        return {'status': 'FAIL', 'reason': 'zero frame vector'}
    n, t, b = [x / np.linalg.norm(x, axis=2, keepdims=True) for x in (N, T, B)]
    dot = lambda a, c: np.sum(a * c, axis=2)
    orth = np.maximum.reduce([abs(dot(n, t)), abs(dot(n, b)), abs(dot(t, b))])
    du = ((e1 * u2[:, 1, None] - e2 * u1[:, 1, None]) / det[:, None])[:, None, :]
    dv = ((e2 * u1[:, 0, None] - e1 * u2[:, 0, None]) / det[:, None])[:, None, :]
    du = du - n * np.sum(du * n, axis=2, keepdims=True)
    du /= np.maximum(np.linalg.norm(du, axis=2, keepdims=True), 1e-12)
    expected_b = np.cross(n, du)
    expected_b *= np.where(np.sum(expected_b * dv, axis=2, keepdims=True) >= 0, 1, -1)
    cos_t, cos_b = dot(t, du), dot(b, expected_b)
    bad = ((orth > orthogonal_tolerance) |
           (np.max(abs(lengths - 1), axis=0) > length_tolerance) |
           (cos_t < minimum_uv_cosine) | (cos_b < minimum_uv_cosine))
    return {'status': 'FAIL' if bad.any() else 'PASS',
            'failed_triangles': np.where(bad.any(axis=1))[0].tolist(),
            'maximum_orthogonality_error': float(orth.max()),
            'maximum_length_error': float(abs(lengths - 1).max()),
            'minimum_positive_u_cosine': float(cos_t.min()),
            'minimum_bitangent_cosine': float(cos_b.min()),
            'scope': 'diagnostic frame coherence only; not roof or engine acceptance'}


if __name__ == '__main__':
    import argparse, json
    from pathlib import Path
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('input', help='NPZ with P, UV, N, T and B arrays')
    parser.add_argument('--out', help='Write the JSON report here, outside runtime assets')
    args = parser.parse_args()
    with np.load(args.input, allow_pickle=False) as arrays:
        result = assess(*[arrays[k] for k in ['P', 'UV', 'N', 'T', 'B']])
    body = json.dumps(result, indent=2)
    if args.out: Path(args.out).write_text(body + '\n', encoding='utf-8')
    print(body)
    raise SystemExit(0 if result['status'] == 'PASS' else 1)
