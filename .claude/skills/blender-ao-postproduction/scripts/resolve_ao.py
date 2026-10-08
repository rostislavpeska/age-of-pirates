"""Reproject unique reference AO onto explicit production owners, then mask conflicts.

Input triangles carry production pixel coordinates (bottom-left origin) and
reference UVs; every chart declares its owner. No mesh or UV edits occur.
Run: python resolve_ao.py INPUT.json --out DIR [--padding 4]
"""
import argparse
from collections import defaultdict
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image
from scipy.ndimage import binary_dilation, distance_transform_edt, map_coordinates


def neutralize(ao, mask):
    a, m = np.asarray(ao), np.asarray(mask)
    if a.shape != m.shape or not np.isfinite(a).all() or not np.isfinite(m).all():
        raise ValueError('AO and mask must have equal finite shapes')
    if a.min() < 0 or a.max() > 1 or m.min() < 0 or m.max() > 1:
        raise ValueError('AO and mask must be normalized linear scalar data')
    return a * (1 - m) + m


def raster_triangle(xy, width, height):
    """Pixel centres with barycentric weights; input xy has top-left origin."""
    xy = np.asarray(xy, dtype=np.float64)
    lo = np.maximum(np.floor(xy.min(axis=0)).astype(int), 0)
    hi = np.minimum(np.ceil(xy.max(axis=0)).astype(int), [width, height])
    if np.any(hi <= lo):
        return np.array([], int), np.array([], int), np.empty((0, 3))
    a, b = xy[1] - xy[0], xy[2] - xy[0]
    den = a[0]*b[1] - a[1]*b[0]
    if abs(den) < 1e-12:
        return np.array([], int), np.array([], int), np.empty((0, 3))
    yy, xx = np.mgrid[lo[1]:hi[1], lo[0]:hi[0]]
    qx, qy = xx + .5 - xy[0, 0], yy + .5 - xy[0, 1]
    u = (qx*b[1]-qy*b[0])/den
    v = (a[0]*qy-a[1]*qx)/den
    take = (u >= -1e-7) & (v >= -1e-7) & (u+v <= 1+1e-7)
    return yy[take], xx[take], np.stack((1-u[take]-v[take], u[take], v[take]), axis=1)


def chart_samples(triangles, references, size):
    w, h = size
    indices, values = [], []
    for t in triangles:
        xy = np.array(t['production_pixels'], dtype=float)
        xy[:, 1] = h - xy[:, 1]
        yy, xx, bary = raster_triangle(xy, w, h)
        if not len(xx):
            continue
        uv = bary @ np.asarray(t['reference_uv'])
        im = references[t['house']]
        # PNG scalar values are consumed directly: no sRGB conversion.
        vals = map_coordinates(im, [(1-uv[:, 1])*im.shape[0]-.5,
                                    uv[:, 0]*im.shape[1]-.5], order=1, mode='nearest')
        indices.append(yy*w+xx)
        values.append(vals)
    if not indices:
        return np.array([], int), np.array([], float)
    idx, val = np.concatenate(indices), np.concatenate(values)
    # Shared triangle boundaries within ONE chart are not separate AO writers.
    unique, reverse = np.unique(idx, return_inverse=True)
    mean = np.bincount(reverse, weights=val)/np.bincount(reverse)
    return unique, mean


def family_conflicts(owner, members, threshold=.08, maximum=.20):
    """Return union mask and pointwise evidence, never an average across readers."""
    union = np.zeros_like(owner, dtype=bool)
    evidence = []
    for member in members:
        delta = np.abs(member - owner)
        p95, peak = float(np.percentile(delta, 95)), float(delta.max())
        failed = p95 > threshold or peak > maximum
        if failed:
            union |= delta > threshold
        evidence.append(dict(p95=p95, maximum=peak, failed=failed))
    return union, evidence


def padded(image, coverage, owner_ids, distance):
    if distance < 0:
        raise ValueError('padding must be nonnegative')
    if not coverage.any():
        return image.copy(), owner_ids.copy(), coverage.copy()
    dist, near = distance_transform_edt(~coverage, return_indices=True)
    band = (dist <= distance) & ~coverage
    out, ids = image.copy(), owner_ids.copy()
    out[band] = image[near[0][band], near[1][band]]
    ids[band] = owner_ids[near[0][band], near[1][band]]
    return out, ids, band


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def run(config, output, padding=4):
    out = Path(output)
    out.mkdir(parents=True, exist_ok=True)
    size = config['size']; w, h = size
    if len(size) != 2 or min(size) <= 0:
        raise ValueError('size must have two positive dimensions')
    references = {k: np.asarray(Image.open(v).convert('L'), dtype=np.float32)/255
                  for k, v in config['references'].items()}
    grouped = defaultdict(lambda: defaultdict(list))
    for t in config['triangles']:
        grouped[t['resource']][t['chart']].append(t)
    report = {'schema': 1, 'method': 'explicit owner reprojection + common neutral conflict mask',
              'production_uv_changes': 0, 'readers_are_not_multiplications': True,
              'candidate_requires_visual_acceptance': True, 'size': size,
              'thresholds': {'p95': .08, 'maximum': .20}, 'padding_pixels': padding,
              'source_hashes': {k: sha(v) for k, v in config['references'].items()},
              'exclusions': config.get('excluded_nearzero_triangles', []), 'resources': {}}
    for resource, charts in grouped.items():
        owners = defaultdict(list)
        for cid, ts in charts.items():
            owners[ts[0]['owner']].append(cid)
        raw = np.ones(w*h, dtype=np.float32)
        resolved = raw.copy(); conflict = np.zeros(w*h, bool)
        coverage = np.zeros(w*h, bool); owner_ids = np.zeros(w*h, np.int32)
        readers = np.zeros(w*h, np.uint16); writer_count = np.zeros(w*h, np.uint8)
        rows, missing, subpixel = [], [], []
        for oid, cids in owners.items():
            if oid not in charts:
                raise ValueError(f'Owner {oid} absent')
            oi, ov = chart_samples(charts[oid], references, size)
            if not len(oi):
                subpixel.append({'owner': oid, 'charts': cids}); continue
            writer_count[oi] += 1
            raw[oi] = ov; coverage[oi] = True; owner_ids[oi] = oid; readers[oi] += 1
            cmask = np.zeros(len(oi), bool); members = []
            for cid in cids:
                if cid == oid: continue
                mi, mv = chart_samples(charts[cid], references, size)
                common, op, mp = np.intersect1d(oi, mi, return_indices=True)
                lost = len(oi)+len(mi)-2*len(common)
                if lost:
                    missing.append({'owner': oid, 'member': cid, 'pixel_difference': lost})
                if not len(common): continue
                union, ev = family_conflicts(ov[op], [mv[mp]])
                cmask[op] |= union
                members.append(dict(chart=cid, pixels=len(common), **ev[0]))
                readers[common] += 1
            # One-pixel dilation, constrained to the SAME owner's covered pixels.
            if cmask.any():
                x, y = oi % w, oi // w
                x0, y0, x1, y1 = x.min(), y.min(), x.max()+1, y.max()+1
                local = np.zeros((y1-y0, x1-x0), bool)
                local[y[cmask]-y0, x[cmask]-x0] = True
                local = binary_dilation(local, iterations=1)
                cmask = local[y-y0, x-x0]
            resolved[oi] = neutralize(ov, cmask.astype(float))
            conflict[oi] = cmask
            rows.append({'owner': oid, 'charts': len(cids), 'pixels': len(oi),
                         'neutral_pixels': int(cmask.sum()), 'members': members})
        if np.max(writer_count) > 1:
            raise ValueError(f'{resource}: independent owners overlap at pixel centres')
        shape = (h, w)
        cov = coverage.reshape(shape); ids = owner_ids.reshape(shape)
        for name, data in [('OWNER_RAW', raw), ('RESOLVED', resolved)]:
            a, _, _ = padded(data.reshape(shape), cov, ids, padding)
            Image.fromarray(np.rint(a*255).astype(np.uint8)).save(out/f'{resource}_AO_{name}.png')
        Image.fromarray(conflict.reshape(shape).astype(np.uint8)*255).save(out/f'{resource}_AO_NEUTRAL_MASK.png')
        Image.fromarray(cov.astype(np.uint8)*255).save(out/f'{resource}_AO_COVERAGE.png')
        Image.fromarray(readers.reshape(shape)).save(out/f'{resource}_AO_READER_COUNT.png')
        Image.fromarray(writer_count.reshape(shape)*255).save(out/f'{resource}_AO_WRITER_COUNT.png')
        np.savez_compressed(out/f'{resource}_AO_EVIDENCE.npz', raw=raw.reshape(shape),
                            resolved=resolved.reshape(shape), coverage=cov,
                            mask=conflict.reshape(shape), owner_ids=ids,
                            readers=readers.reshape(shape), writer_count=writer_count.reshape(shape))
        count = int(coverage.sum())
        report['resources'][resource] = dict(owners=len(owners), charts=len(charts),
            content_pixels=count, neutral_pixels=int(conflict.sum()),
            neutral_content_percent=float(100*conflict.sum()/max(1,count)),
            missing_correspondence=missing, subpixel_owners=subpixel,
            failed_families=sum(any(m['failed'] for m in r['members']) for r in rows),
            maximum_writer_count=int(writer_count.max()), families=rows)
    (out/'AO_POSTPROCESS_REPORT.json').write_text(json.dumps(report, indent=2))
    return report


if __name__ == '__main__':
    ap = argparse.ArgumentParser(); ap.add_argument('config'); ap.add_argument('--out', required=True)
    ap.add_argument('--padding', type=int, default=4); args = ap.parse_args()
    result = run(json.loads(Path(args.config).read_text()), args.out, args.padding)
    print(json.dumps({r: {k:v for k,v in row.items() if k!='families'}
                      for r,row in result['resources'].items()}, indent=2))
