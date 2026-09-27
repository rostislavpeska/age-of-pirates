"""Offline image and voxel evidence; no live Blender control."""
import argparse
import json
from pathlib import Path
import time

import numpy as np
from evidence_kernels import sweep, voxel_run


def measure(directory, dataset, config):
    out = Path(directory)
    g = np.load(out / (dataset + '_geometry.npz'), allow_pickle=False)
    tri = g['triangles'][g['opaque']]
    fi = g['face_ids'][g['opaque']]
    fs = json.loads((out / (dataset + '_faces.json')).read_text(encoding='utf-8'))
    if not len(tri) or len(fs) == 0:
        raise ValueError('Empty opaque snapshot.')
    start = time.time()
    train = sweep(tri, fi, fs, config['primary_camera_elevations'], config['primary_azimuths'], config['image_resolution'], 0)
    held = sweep(tri, fi, fs, config['holdout_elevations'], config['holdout_azimuths'], config['holdout_image_resolution'], .123)
    stress = sweep(tri, fi, fs, config['stress_elevations'], 12, config['image_resolution'], .071)
    images = {'train': train, 'heldout': held, 'stress': stress, 'summary': {'seconds': time.time() - start}, 'measurement_config': config}
    (out / (dataset + '_images.json')).write_text(json.dumps(images), encoding='utf-8')
    start = time.time()
    vals, runs = [], []
    coarse, fine = config['voxel_pitches_world']
    for h, shift in ((coarse, 0), (fine, 0), (fine, config.get('voxel_shift', .37))):
        if h <= 0:
            raise ValueError('Voxel pitch must be positive.')
        val, run = voxel_run(tri, fs, h, shift, config.get('voxel_max_cells', 8000000))
        vals.append(val); runs.append(run)
    arr = np.array(vals)
    voxels = {'minimum_enclosure': arr.min(0).tolist(), 'maximum_enclosure': arr.max(0).tolist(),
              'unstable': ((arr.max(0) - arr.min(0)) > config.get('voxel_unstable_tolerance', .2)).tolist(),
              'runs': runs, 'seconds': time.time() - start, 'measurement_config': config}
    (out / (dataset + '_voxels.json')).write_text(json.dumps(voxels), encoding='utf-8')
    return {'image_seconds': images['summary']['seconds'], 'voxel_seconds': voxels['seconds']}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--data-dir', type=Path, required=True)
    parser.add_argument('--dataset', required=True)
    parser.add_argument('--config', type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(measure(args.data_dir, args.dataset, json.loads(args.config.read_text(encoding='utf-8')))))
