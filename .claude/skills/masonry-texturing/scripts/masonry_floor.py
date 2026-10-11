"""Masonry quality floor: fail a page whose masonry is a tiled stone source with a drawn joint grid (dependency: numpy,
Pillow, scipy).

    python masonry_floor.py PAGE_BaseColor.png FACES.json [--size 2048] [--json OUT.json]

FACES.json: {"faces": [{"group": name, "page": int, "uv_px": [[x, y], ...]}, ...]} - page px, y down (the masonry map of
the consuming project; faces of other pages are ignored when --page is given). Per group, over its texels:
- tile_repeat: the highest secondary peak of the normalised autocorrelation of the high-passed luminance INSIDE the stones
  (joints masked: courses repeat by design), beyond 12 px. A repeated source tile peaks at its period; painted stone does not. FAIL above --max-repeat (.45).
- stone_identity: spread (std) of the low-passed luminance - each stone carries its own tone. FAIL below --min-identity (.03).
- joint_share: share of texels darker than their 9 px neighbourhood by .05 - joints exist but do not swamp the stone.
  FAIL outside [--min-joint .02, --max-joint .35].
Groups with fewer than --min-texels (1500) are reported, not judged. Exit 1 on any FAIL. This is a floor, not acceptance:
it does not judge colour, style or junctions.
"""
import argparse, json, sys
import numpy as np
from PIL import Image, ImageDraw


def group_metrics(lum, mask):
    from scipy.ndimage import gaussian_filter, median_filter
    ys, xs = np.nonzero(mask)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    L, m = lum[y0:y1, x0:x1], mask[y0:y1, x0:x1].astype(float)
    mu = (L * m).sum() / m.sum()
    from scipy.ndimage import binary_dilation
    jmask = binary_dilation((L < median_filter(L, size=9) - .05) & (m > 0), iterations=4)
    m_in = m * ~jmask                                     # stone interiors without their rims: a regular bond repeats its BLOCKS by
                                                          # design (sagoseok, courses); a tiled source repeats its fine TEXTURE
    hp = (L - gaussian_filter(L * m_in, 1.5) / np.maximum(gaussian_filter(m_in, 1.5), 1e-3)) * m_in   # fine texture only
    H, W = hp.shape; P = np.zeros((2 * H, 2 * W)); P[:H, :W] = hp; Q = np.zeros_like(P); Q[:H, :W] = m_in
    F = np.fft.rfft2(P); ac = np.fft.irfft2(F * np.conj(F), P.shape)
    FM = np.fft.rfft2(Q); cnt = np.fft.irfft2(FM * np.conj(FM), P.shape)                       # overlap counts per lag
    acn = ac / np.maximum(cnt, 1) / max(ac[0, 0] / max(cnt[0, 0], 1), 1e-12)
    acn[cnt < .25 * m_in.sum()] = 0                                                             # lags with little overlap are noise
    yy, xx = np.meshgrid(np.fft.fftfreq(2 * H) * 2 * H, np.fft.fftfreq(2 * W) * 2 * W, indexing='ij')
    acn[np.hypot(yy, xx) < 12] = 0
    repeat = float(acn.max()) if acn.size else 0.
    lp = gaussian_filter(L * m, 3) / np.maximum(gaussian_filter(m, 3), 1e-3)
    identity = float(np.std(lp[m > 0]))
    joint = (L < median_filter(L, size=9) - .05) & (m > 0)
    return {'texels': int(m.sum()), 'mean_lum': round(float(mu), 3), 'tile_repeat': round(repeat, 3),
            'stone_identity': round(identity, 4), 'joint_share': round(float(joint.sum() / m.sum()), 4)}


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0]); ap.add_argument('page'); ap.add_argument('faces')
    ap.add_argument('--size', type=int, default=2048); ap.add_argument('--page-index', type=int); ap.add_argument('--json')
    ap.add_argument('--max-repeat', type=float, default=.45); ap.add_argument('--min-identity', type=float, default=.03)
    ap.add_argument('--min-joint', type=float, default=.02); ap.add_argument('--max-joint', type=float, default=.35)
    ap.add_argument('--min-texels', type=int, default=1500)
    a = ap.parse_args(argv)
    lum = np.asarray(Image.open(a.page).convert('RGB')).astype(np.float32).mean(-1) / 255; N = lum.shape[0]
    faces = json.load(open(a.faces))['faces']
    groups = {}
    for f in faces:
        if a.page_index is not None and f.get('page') != a.page_index:
            continue
        groups.setdefault(f['group'], []).append(f['uv_px'])
    rep, ok = {}, True
    for g, polys in sorted(groups.items()):
        im = Image.new('L', (N, N), 0); d = ImageDraw.Draw(im)
        for p in polys:
            d.polygon([tuple(q) for q in p], fill=255)
        mask = np.asarray(im) > 0
        if mask.sum() < a.min_texels:
            rep[g] = {'texels': int(mask.sum()), 'judged': False}; continue
        r = group_metrics(lum, mask); fails = []
        if r['tile_repeat'] > a.max_repeat:
            fails.append('tile_repeat')
        if r['stone_identity'] < a.min_identity:
            fails.append('stone_identity')
        if not a.min_joint <= r['joint_share'] <= a.max_joint:
            fails.append('joint_share')
        r['fails'] = fails; r['judged'] = True; ok &= not fails; rep[g] = r
    out = {'page': a.page, 'thresholds': {'max_repeat': a.max_repeat, 'min_identity': a.min_identity, 'joint': [a.min_joint, a.max_joint]},
           'groups': rep, 'status': 'PASS' if ok else 'FAIL'}
    if a.json:
        json.dump(out, open(a.json, 'w'), indent=1)
    print('MASONRY_FLOOR', out['status'], {g: r.get('fails', 'not judged') for g, r in rep.items() if r.get('fails') or not r.get('judged')})
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
