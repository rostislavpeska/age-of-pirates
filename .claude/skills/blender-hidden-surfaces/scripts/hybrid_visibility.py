"""Reusable M5 material-allocation classifier. No Blender or asset mutation."""
import argparse
from collections import defaultdict
import json
from pathlib import Path

import numpy as np
from scipy.sparse import coo_matrix
from scipy.sparse.csgraph import breadth_first_order, maximum_flow


DEFAULTS = {
    'graph_unary_weights': {'images': 1.5, 'rays': 1.5, 'paired_backing': 1.0, 'voxel': .4},
    'graph_lambda': .35, 'image_score_pixels': 4., 'image_score_fraction': .08,
    'ray_score_fraction': .10, 'pair_normal_offset': .05, 'pair_normal_span': .30,
    'protect_pixels': 4, 'protect_fraction': .1, 'normal_dot_min': .82,
    'edge_weight_max': 4., 'normal_power': 8, 'capacity_scale': 100000,
}


def cut(prob, edges, lam, scale=100000):
    n = len(prob)
    s, t = n, n + 1
    p = np.clip(prob, .0001, .9999)
    row, col, val = [], [], []

    def add(i, j, w):
        row.append(i); col.append(j); val.append(max(1, int(w * scale)))

    for i in range(n):
        add(s, i, -np.log(p[i])); add(i, t, -np.log(1 - p[i]))
    for i, j, w in edges:
        add(i, j, lam * w); add(j, i, lam * w)
    cap = coo_matrix((np.array(val, np.int64), (row, col)), shape=(n + 2, n + 2)).tocsr()
    flow = maximum_flow(cap, s, t)
    residual = (cap - flow.flow).tocsr()
    residual.data = (residual.data > 0).astype(np.int64)
    residual.eliminate_zeros()
    reachable = breadth_first_order(residual, s, directed=True, return_predecessors=False)
    keep = np.zeros(n + 2, bool)
    keep[reachable] = True
    return ~keep[:n]


def adjacency(faces, config):
    incident = defaultdict(list)
    for f in faces:
        points = np.asarray(f['points'], float)
        for a, b in zip(points, np.roll(points, -1, axis=0)):
            key = tuple(sorted((tuple(a), tuple(b))))
            incident[key].append(f['id'])
    edges = []
    for key, ids in incident.items():
        for ai, i in enumerate(ids):
            for j in ids[ai + 1:]:
                if i == j:
                    continue
                a, b = faces[i], faces[j]
                dot = float(np.dot(a['normal'], b['normal']))
                if dot < config['normal_dot_min'] or a['alpha'] != b['alpha']:
                    continue
                ma = a.get('physical_material', a.get('old_material', '').replace('HIDDEN_', ''))
                mb = b.get('physical_material', b.get('old_material', '').replace('HIDDEN_', ''))
                if ma != mb:
                    continue
                length = np.linalg.norm(np.array(key[0]) - key[1])
                weight = length / np.sqrt(max((a['area'] + b['area']) / 2, 1e-8)) * dot ** config['normal_power']
                edges.append((i, j, float(min(weight, config['edge_weight_max']))))
    return edges


def classify(faces, images, rays, voxels, settings=None, keep_ids=()):
    config = dict(DEFAULTS)
    config.update(settings or {})
    n = len(faces)
    if not n or [f['id'] for f in faces] != list(range(n)):
        raise ValueError('Faces must have contiguous IDs in original snapshot order.')
    if [f['id'] for f in rays['faces']] != list(range(n)):
        raise ValueError('Ray evidence IDs do not match face order.')

    def vector(values, name, unit=False):
        v = np.asarray(values, float)
        if v.shape != (n,) or not np.all(np.isfinite(v)):
            raise ValueError(f'{name}: expected {n} finite values')
        if np.any(v < 0) or (unit and np.any(v > 1 + 1e-9)):
            raise ValueError(f'{name}: invalid range')
        return np.clip(v, 0, 1) if unit else v

    weights = config['graph_unary_weights']
    w = np.array([weights[k] for k in ('images', 'rays', 'paired_backing', 'voxel')], float)
    if not np.all(np.isfinite(w)) or np.any(w < 0) or w.sum() <= 0:
        raise ValueError('Weights must be finite, nonnegative and have positive sum.')
    if not np.isfinite(config['graph_lambda']) or config['graph_lambda'] < 0:
        raise ValueError('Invalid smoothing lambda.')
    for key in ('image_score_pixels', 'image_score_fraction', 'ray_score_fraction', 'pair_normal_span', 'capacity_scale'):
        if not np.isfinite(config[key]) or config[key] <= 0:
            raise ValueError(f'{key} must be finite and positive.')
    for i in keep_ids:
        if not isinstance(i, int) or not 0 <= i < n:
            raise ValueError('Keep override does not identify an original face.')
    px = vector(images['train']['max_pixels'], 'pixels')
    frac = vector(images['train']['max_fraction'], 'fraction', True)
    ray = vector([f['max_exposure'] for f in rays['faces']], 'rays', True)
    pair = vector([f['pair_coverage'] for f in rays['faces']], 'pairing', True)
    vox = vector(voxels['minimum_enclosure'], 'voxels', True)
    unstable = vector(voxels['unstable'], 'unstable', True).astype(bool)
    normal = np.asarray([f['normal'] for f in faces], float)
    area = vector([f['area'] for f in faces], 'areas')
    if normal.shape != (n, 3) or not np.isfinite(normal).all() or np.any(area <= 0):
        raise ValueError('Nonfinite normal or degenerate face; repair analysis input first.')
    if not np.allclose(np.linalg.norm(normal, axis=1), 1, atol=1e-4):
        raise ValueError('World-space geometric normals must be unit length.')
    alpha = np.array([bool(f['alpha']) for f in faces])
    scores = np.array([
        np.clip(1 - np.maximum(px / config['image_score_pixels'], frac / config['image_score_fraction']), 0, 1),
        np.clip(1 - ray / config['ray_score_fraction'], 0, 1),
        pair * np.clip((-normal[:, 2] - config['pair_normal_offset']) / config['pair_normal_span'], 0, 1),
        np.where(unstable, 0, vox),
    ])
    probability = np.sum(w[:, None] * scores, axis=0) / w.sum()
    protected = alpha | ((px >= config['protect_pixels']) & (frac >= config['protect_fraction']))
    protected[list(keep_ids)] = True
    probability[protected] = .0001
    edges = adjacency(faces, config)
    mask = cut(probability, edges, config['graph_lambda'], config['capacity_scale'])
    mask[protected] = False
    report = {
        'method': 'M5_HybridGraph', 'status': 'review_candidate', 'config': config,
        'candidate_ids': np.flatnonzero(mask).tolist(), 'candidate_count': int(mask.sum()),
        'protected_ids': np.flatnonzero(protected).tolist(), 'graph_edges': len(edges),
        'probability_hidden': probability.tolist(), 'geometry_modified': False,
        'uv_modified': False, 'automatic_formula_approved': False,
        'unstable_voxel_ids': np.flatnonzero(unstable).tolist(),
    }
    if 'heldout' in images:
        held = images['heldout']
        risk = mask & (vector(held['max_pixels'], 'heldout pixels') >= config['protect_pixels']) & (vector(held['max_fraction'], 'heldout fraction', True) >= config['protect_fraction'])
        report['heldout_exposed_ids'] = np.flatnonzero(risk).tolist()
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--data-dir', type=Path, required=True)
    parser.add_argument('--dataset', required=True)
    parser.add_argument('--config', type=Path, required=True)
    parser.add_argument('--keep', type=Path, help='JSON object mapping original face IDs to protection reasons')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    load = lambda suffix: json.loads((args.data_dir / (args.dataset + suffix)).read_text(encoding='utf-8'))
    keep = json.loads(args.keep.read_text(encoding='utf-8')) if args.keep else {}
    if not isinstance(keep, dict) or any(not str(v).strip() for v in keep.values()):
        raise ValueError('Protection overrides must carry reasons.')
    report = classify(load('_faces.json'), load('_images.json'), load('_rays.json'), load('_voxels.json'), json.loads(args.config.read_text(encoding='utf-8')), [int(k) for k in keep])
    report['keep_override_reasons'] = keep
    args.output.write_text(json.dumps(report, indent=2), encoding='utf-8')
    print(json.dumps({k: report[k] for k in ('method', 'candidate_count', 'graph_edges', 'status')}))


if __name__ == '__main__':
    main()
