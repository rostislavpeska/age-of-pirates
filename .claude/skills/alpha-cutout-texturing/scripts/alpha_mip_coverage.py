"""Read-only regional alpha QA for *decoded, encoded* mip images.

The engine adapter supplies the decoded mip PNGs; this portable helper never
encodes, repacks, changes alpha, or claims camera/engine validation. Source and
region masks use the same image orientation. NumPy and Pillow are required.

    python alpha_mip_coverage.py config.json --out report.json

Config: source (RGBA or L PNG), threshold (0..1), regions [{name, mask}],
mips [{level, image, min_retention?, max_retention?, max_empty_coverage?}].
Every nonzero mask pixel is one equally weighted source texel-centre sample.
Bounds are explicit per mip. Ungated mips remain diagnostic, never PASS.
Exit 0: all declared gates pass; 1: gate failure; 2: invalid/diagnostic-only.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image


def alpha_image(path):
    with Image.open(path) as image:
        if image.mode == 'L':
            array = np.asarray(image).copy()
        elif 'A' in image.getbands():
            array = np.asarray(image.getchannel('A')).copy()
        else:
            raise ValueError(f'Expected alpha-bearing or L image: {path}')
    return array.astype(np.float64) / 255.0


def bilinear_at_source_centres(alpha, source_shape, y, x):
    """Clamp-to-edge image-space bilinear samples at identical normalized UVs."""
    h, w = alpha.shape
    sy = (y + .5) * h / source_shape[0] - .5
    sx = (x + .5) * w / source_shape[1] - .5
    sy = np.clip(sy, 0, h - 1)
    sx = np.clip(sx, 0, w - 1)
    y0, x0 = np.floor(sy).astype(int), np.floor(sx).astype(int)
    y1, x1 = np.minimum(y0 + 1, h - 1), np.minimum(x0 + 1, w - 1)
    fy, fx = sy - y0, sx - x0
    return ((alpha[y0, x0] * (1 - fx) + alpha[y0, x1] * fx) * (1 - fy)
            + (alpha[y1, x0] * (1 - fx) + alpha[y1, x1] * fx) * fy)


def measure(source, mask, mip, level, threshold=.5):
    if not isinstance(level, int) or level < 0:
        raise ValueError('Mip level must be a nonnegative integer')
    if source.ndim != 2 or mask.shape != source.shape or mip.ndim != 2:
        raise ValueError('Source/mask must have matching 2D dimensions')
    expected = tuple(max(1, axis // (2 ** level)) for axis in source.shape)
    if mip.shape != expected:
        raise ValueError(f'Mip {level}: expected {expected}, got {mip.shape}')
    if not 0 < threshold < 1:
        raise ValueError('Threshold must lie strictly between 0 and 1')
    if not np.isfinite(source).all() or not np.isfinite(mip).all():
        raise ValueError('Nonfinite alpha')
    y, x = np.where(mask)
    if not len(x):
        raise ValueError('Empty region mask')
    original = source[y, x] >= threshold
    sampled = bilinear_at_source_centres(mip, source.shape, y, x) >= threshold
    baseline, coverage = float(original.mean()), float(sampled.mean())
    union = np.count_nonzero(original | sampled)
    return {
        'source_samples': len(x), 'source_coverage': baseline,
        'mip_coverage': coverage, 'retention': coverage / baseline if baseline else None,
        'delta_percentage_points': 100 * (coverage - baseline),
        'silhouette_iou': float(np.count_nonzero(original & sampled) / union) if union else 1.0,
        'lost_opaque_samples': int(np.count_nonzero(original & ~sampled)),
        'filled_cutout_samples': int(np.count_nonzero(~original & sampled)),
        'bbox_min_axis_at_mip': min((x.max()-x.min()+1) * mip.shape[1] / source.shape[1],
                                   (y.max()-y.min()+1) * mip.shape[0] / source.shape[0]),
    }


def gate(result, spec):
    failures = []
    if result['retention'] is None:
        if 'max_empty_coverage' in spec and result['mip_coverage'] > spec['max_empty_coverage']:
            failures.append('transparent region gained opaque coverage')
        gated = 'max_empty_coverage' in spec
    else:
        gated = 'min_retention' in spec or 'max_retention' in spec
        if 'min_retention' in spec and result['retention'] < spec['min_retention']:
            failures.append('opaque coverage shrank below bound')
        if 'max_retention' in spec and result['retention'] > spec['max_retention']:
            failures.append('cutout gaps filled above bound')
    return ('FAIL' if failures else 'PASS' if gated else 'DIAGNOSTIC'), failures


def audit(config, base):
    if not config.get('regions') or not config.get('mips'):
        raise ValueError('At least one named region and one decoded mip required')
    levels = [m['level'] for m in config['mips']]
    if len(set(levels)) != len(levels):
        raise ValueError('Duplicate mip levels')
    for spec in config['mips']:
        for key in ('min_retention', 'max_retention', 'max_empty_coverage'):
            if key in spec and (not np.isfinite(spec[key]) or spec[key] < 0):
                raise ValueError(f'Invalid {key} bound')
        if spec.get('min_retention', 0) > spec.get('max_retention', float('inf')):
            raise ValueError('Inverted retention bounds')
        if spec.get('max_empty_coverage', 0) > 1:
            raise ValueError('Empty coverage bound exceeds 1')
    names = [r['name'] for r in config['regions']]
    if len(set(names)) != len(names):
        raise ValueError('Duplicate region names')
    sources = {}
    def resolve(relative):
        path = (base / relative).resolve()
        sources[str(path)] = hashlib.sha256(path.read_bytes()).hexdigest()
        return path
    original = alpha_image(resolve(config['source']))
    rows = []
    for region in config['regions']:
        with Image.open(resolve(region['mask'])) as image:
            mask = np.asarray(image.convert('L')) > 0
        for spec in config['mips']:
            result = measure(original, mask, alpha_image(resolve(spec['image'])),
                             spec['level'], config.get('threshold', .5))
            status, failures = gate(result, spec)
            rows.append(dict(region=region['name'], level=spec['level'], status=status,
                             failures=failures, bounds={k:v for k,v in spec.items()
                               if k in ('min_retention','max_retention','max_empty_coverage')}, **result))
    failed = any(r['status'] == 'FAIL' for r in rows)
    gated = any(r['status'] == 'PASS' for r in rows)
    return {'status': 'FAIL' if failed else 'PASS_DECLARED_GATES' if gated else 'DIAGNOSTIC',
            'method': 'Fixed source texel-centre UV samples, bilinear, clamp-to-edge, decoded compressed mip alpha. No trilinear/anisotropic/projected-camera certification.',
            'threshold': config.get('threshold', .5), 'sources_sha256': sources,
            'ungated_rows': sum(r['status']=='DIAGNOSTIC' for r in rows), 'rows': rows}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('config', type=Path)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    try:
        result = audit(json.loads(args.config.read_text(encoding='utf-8')), args.config.parent)
    except (ValueError, KeyError, OSError, TypeError) as error:
        result = {'status':'INVALID', 'error':str(error)}
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(result, indent=2), encoding='utf-8')
    print(result['status'], args.out)
    return {'PASS_DECLARED_GATES':0, 'FAIL':1}.get(result['status'], 2)


if __name__ == '__main__':
    raise SystemExit(main())
