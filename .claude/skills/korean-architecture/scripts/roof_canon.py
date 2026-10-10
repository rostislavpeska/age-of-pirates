"""Canonical Korean roof appearance: sample the accepted Town Center, never re-implement it.

Owner 2026-10-10: "Harden the roof process. Each roof now looks worse than previous. The Town center last version must
be canonical reference ... each copy is worse and worse." Every building had re-derived the TC look (photo clay,
painted light, chips, soot, moss) as new code - copy of a copy. This module makes the canonical TC roof PIXELS the
source: a new roof's tile field, caps and eave-end clay are sampled from the TC by tile-local coordinates, so the TC
look arrives unchanged (star topology: every building derives from the canon pack, never from another building).

Tile-local features (identical definition on the TC and on any target page, so no orientation or UV assumption):
  roll  roll mask of the tile ID bake (B channel), f  position in tile (G: 0 top .. 1 lower lip),
  a     across-roll position inside the tile cell, 0..1: the cell's down-slope axis is the mean gradient of f inside it,
        a = the texel's projection on the perpendicular, normalised over the cell (left/right symmetric by design).
        (v1 used the distance to the cell boundary: it mixes along and across and printed concentric rectangles.)
A component = connected texels with one tile ID value (R channel), i.e. one roll segment or one pan of one course.

  python roof_canon.py build  --pack DIR            # TC exemplar from DIR/tc (decoded runtime maps + tile inputs)
  python roof_canon.py profile --pack DIR           # canonical appearance profile (metrics.json) of the TC field
Library use (dock_roof_canon.py etc.): load_exemplar, components, transfer_field, match_slopes, profile, gate.
"""
import json, hashlib, sys, argparse
import numpy as np
from pathlib import Path
from PIL import Image
from scipy import ndimage
from scipy.spatial import cKDTree

lin = lambda c: np.where(c <= .04045, c / 12.92, ((c + .055) / 1.055) ** 2.4)
srgb = lambda c: np.where(c <= .0031308, c * 12.92, 1.055 * np.power(np.clip(c, 0, None), 1 / 2.4) - .055)
TC_CLASS = {'ROOF_TILE': (77, 151, 229), 'ROOF_TRIM': (97, 200, 231), 'EAVE_CUTOUT': (137, 231, 248)}   # Material_Split_S1


def components(tile_r, mask, tol=1e-5):
    """label connected texels sharing one tile ID value inside mask; returns labels (0 = none) and d (0 edge .. 1 middle)."""
    edge = np.zeros(mask.shape, bool)
    for ax in (0, 1):
        for sh in (1, -1):
            nb = np.roll(tile_r, sh, ax); nm = np.roll(mask, sh, ax)
            edge |= mask & (~nm | (np.abs(nb - tile_r) > tol))
    inner = mask & ~edge
    lab, n = ndimage.label(inner)
    dist = ndimage.distance_transform_edt(inner)
    mx = ndimage.maximum(dist, lab, np.arange(1, n + 1)) if n else np.zeros(0)
    d = np.where(lab > 0, dist / np.maximum(np.concatenate([[1.], mx])[lab], 1e-6), 0.)
    # edge texels: attach to the neighbouring component with d = 0 (they are real tile texels)
    if n:
        idx = ndimage.distance_transform_edt(lab == 0, return_distances=False, return_indices=True)
        lab = np.where(mask & (lab == 0), lab[idx[0], idx[1]], lab)
    return lab, np.where(mask, d, 0.).astype(np.float32), n


def across(lab, f, n):
    """across-roll coordinate a (0..1) per texel of each tile component: perpendicular to the mean gradient of f."""
    gy, gx = np.gradient(f.astype(np.float64)); ok = lab > 0
    lim = .25                                                        # ignore the course-boundary jumps of f
    w = ok & (np.abs(gx) < lim) & (np.abs(gy) < lim)
    sx = np.bincount(lab[w], gx[w], minlength=n + 1); sy = np.bincount(lab[w], gy[w], minlength=n + 1)
    nrm = np.hypot(sx, sy) + 1e-12; dx, dy = sx / nrm, sy / nrm                # down-slope axis (pixel space) per component
    yy, xx = np.nonzero(ok); c = lab[ok]
    proj = xx * (-dy[c]) + yy * dx[c]                                       # perpendicular projection
    lo = np.full(n + 1, np.inf); hi = np.full(n + 1, -np.inf); np.minimum.at(lo, c, proj); np.maximum.at(hi, c, proj)
    out = np.zeros(lab.shape, np.float32); out[ok] = (proj - lo[c]) / np.maximum(hi[c] - lo[c], 1e-6)
    return out


def tc_page(pack, page):
    """decoded TC runtime maps + merged tile banks of one TC page (P2048 = mata, P1024 = matb)."""
    T = Path(pack) / 'tc'; I = T / 'inputs'; stem = 'korean_tc_mata' if page == 'P2048' else 'korean_tc_matb'
    bc = np.asarray(Image.open(T / f'{stem}_BaseColor.png').convert('RGBA')).astype(np.float32) / 255.
    ms = np.asarray(Image.open(T / f'{stem}_Masks.png').convert('RGB')).astype(np.float32) / 255.
    nm = np.asarray(Image.open(T / f'{stem}_Normals.png').convert('RGB')).astype(np.float32) / 255.
    cid = np.asarray(Image.open(I / f'{page}_ClassID.png').convert('RGB')).astype(int)
    n = bc.shape[0]; tile = np.zeros((n, n, 3), np.float32); has = np.zeros((n, n), bool)
    for b in range(4):
        cov = np.load(I / f'cov_R{b}_{page}.npy')[..., 0] > .5; t = np.load(I / f'tile_R{b}_{page}.npy')
        tile[cov] = t[cov]; has |= cov
    cls = {k: np.abs(cid - np.array(v)).sum(-1) < 6 for k, v in TC_CLASS.items()}
    return dict(bc=bc, ms=ms, nm=nm, tile=tile, has=has, cls=cls)


def slope_deg(nm01):
    v = nm01[..., :3] * 2 - 1; v /= np.maximum(np.linalg.norm(v, axis=-1, keepdims=True), 1e-6)
    return np.degrees(np.arcsin(np.clip(np.hypot(v[..., 0], v[..., 1]), 0, 1)))


def build(pack):
    """TC field exemplar: per texel (comp, roll, f, d, linear RGB, roughness) + per-component stats."""
    P = tc_page(pack, 'P2048'); m = P['cls']['ROOF_TILE'] & P['has'] & (P['bc'][..., 3] > .5)
    lab, d, n = components(P['tile'][..., 0], m); d = across(lab, P['tile'][..., 1], n)
    sel = m & (lab > 0); ys, xs = np.nonzero(sel)
    rgb = lin(P['bc'][ys, xs, :3]); lum = rgb @ [.2126, .7152, .0722]
    comp = lab[ys, xs]; roll = P['tile'][ys, xs, 2]; f = P['tile'][ys, xs, 1]
    # per component: size, type (roll if mean mask > .5), f coverage, weathering score (moss = greenish + darker)
    cnt = np.bincount(comp, minlength=n + 1); rmean = np.bincount(comp, roll, minlength=n + 1) / np.maximum(cnt, 1)
    fmin = np.full(n + 1, 9.); fmax = np.full(n + 1, -9.)
    np.minimum.at(fmin, comp, f); np.maximum.at(fmax, comp, f)
    green = np.clip(rgb[:, 1] - np.maximum(rgb[:, 0], rgb[:, 2]), 0, None)
    gscore = np.bincount(comp, green, minlength=n + 1) / np.maximum(cnt, 1)
    lmean = np.bincount(comp, lum, minlength=n + 1) / np.maximum(cnt, 1)
    full = (cnt >= np.percentile(cnt[cnt > 0], 25)) & (fmin < .12) & (fmax > .88)            # complete tiles only
    ex = dict(comp=comp.astype(np.int32), roll=roll.astype(np.float32), f=f.astype(np.float32), d=d[ys, xs].astype(np.float32),
              rgb=rgb.astype(np.float32), rough=P['ms'][ys, xs, 1].astype(np.float32),
              comp_n=cnt.astype(np.int32), comp_roll=rmean.astype(np.float32), comp_full=full, comp_green=gscore.astype(np.float32),
              comp_lum=lmean.astype(np.float32))
    out = Path(pack) / 'exemplar_field.npz'; np.savez_compressed(out, **ex)
    # caps (ROOF_TRIM on matb) and eave-end clay (EAVE_CUTOUT discs B>.5 / rest) - value pools for the edge parts
    Q = tc_page(pack, 'P1024')
    pools = {}
    bcl = lin(Q['bc'][..., :3]); clay = (bcl[..., 0] - bcl[..., 2]) < .03                        # caps are grey clay: drop the wooden ridges
    for name, msk in (('cap', Q['cls']['ROOF_TRIM'] & (Q['bc'][..., 3] > .5) & clay),
                      ('end_disc', Q['cls']['EAVE_CUTOUT'] & Q['has'] & (Q['tile'][..., 2] > .5) & (Q['bc'][..., 3] > .5)),
                      ('end_rest', Q['cls']['EAVE_CUTOUT'] & Q['has'] & (Q['tile'][..., 2] <= .5) & (Q['bc'][..., 3] > .5))):
        yy, xx = np.nonzero(msk); pools[name] = dict(rgb=lin(Q['bc'][yy, xx, :3]).astype(np.float32), rough=Q['ms'][yy, xx, 1].astype(np.float32),
                                                       slope=slope_deg(Q['nm'][yy, xx]).astype(np.float32))
    np.savez_compressed(Path(pack) / 'exemplar_edges.npz', **{f'{k}_{kk}': v for k, d_ in pools.items() for kk, v in d_.items()})
    em = Q['cls']['EAVE_CUTOUT'] & Q['has'] & (Q['bc'][..., 3] > .5)
    labe, de, ne = components(Q['tile'][..., 0], em); sele = em & (labe > 0); ye, xe = np.nonzero(sele)
    ce = labe[ye, xe]; disc = (Q['tile'][ye, xe, 2] > .5).astype(np.float32); cnte = np.bincount(ce, minlength=ne + 1)
    dmean = np.bincount(ce, disc, minlength=ne + 1) / np.maximum(cnte, 1)
    rgbe = lin(Q['bc'][ye, xe, :3]); lume = rgbe @ [.2126, .7152, .0722]
    exe = dict(comp=ce.astype(np.int32), roll=disc, f=np.full(len(ce), .5, np.float32), d=de[ye, xe].astype(np.float32), rgb=rgbe.astype(np.float32),
               rough=Q['ms'][ye, xe, 1].astype(np.float32), comp_n=cnte.astype(np.int32), comp_roll=dmean.astype(np.float32),
               comp_full=cnte >= max(12, np.percentile(cnte[cnte > 0], 25)),
               comp_green=(np.bincount(ce, np.clip(rgbe[:, 1] - np.maximum(rgbe[:, 0], rgbe[:, 2]), 0, None), minlength=ne + 1) / np.maximum(cnte, 1)).astype(np.float32),
               comp_lum=(np.bincount(ce, lume, minlength=ne + 1) / np.maximum(cnte, 1)).astype(np.float32))
    np.savez_compressed(Path(pack) / 'exemplar_ends.npz', **exe)
    rep = {'field_texels': int(sel.sum()), 'components': int(n), 'complete_components': int(full.sum()),
           'roll_frac': round(float((roll > .5).mean()), 3), 'pools': {k: int(len(v['rgb'])) for k, v in pools.items()},
           'field_slope_deg_quantiles': np.round(np.percentile(slope_deg(P['nm'][ys, xs]), np.arange(0, 101, 5)), 2).tolist(),
           'cap_slope_deg_quantiles': np.round(np.percentile(pools['cap']['slope'], np.arange(0, 101, 5)), 2).tolist(),
           'end_slope_deg_quantiles': np.round(np.percentile(np.concatenate([pools['end_disc']['slope'], pools['end_rest']['slope']]), np.arange(0, 101, 5)), 2).tolist()}
    rep['end_components'] = int(ne); rep['end_disc_frac'] = round(float(disc.mean()), 3)
    rep['sha256'] = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in (out, Path(pack) / 'exemplar_edges.npz', Path(pack) / 'exemplar_ends.npz')}
    json.dump(rep, open(Path(pack) / 'EXEMPLAR.json', 'w'), indent=1)
    print('EXEMPLAR', json.dumps({k: v for k, v in rep.items() if 'quantiles' not in k}))
    return rep


def load_exemplar(pack):
    return dict(np.load(Path(pack) / 'exemplar_field.npz')), dict(np.load(Path(pack) / 'exemplar_edges.npz')), json.load(open(Path(pack) / 'EXEMPLAR.json'))


def load_ends(pack):
    return dict(np.load(Path(pack) / 'exemplar_ends.npz'))


def end_stats(exe):
    """TC eave-end statistics per class (disc = roll mask > .5, rest): mean linear colour, between-tile tone spread
    (std of tile mean luma / mean), within-tile grain (mean of per-tile luma std / mean), mean roughness."""
    lum = exe['rgb'] @ [.2126, .7152, .0722]; out = {}
    for name, sel in (('disc', exe['roll'] > .5), ('rest', exe['roll'] <= .5)):
        c = exe['comp'][sel]; l = lum[sel]; n_ = np.bincount(c); ok = n_ >= 8
        mu = np.bincount(c, l) / np.maximum(n_, 1); var = np.bincount(c, l * l) / np.maximum(n_, 1) - mu ** 2
        out[name] = {'mean': exe['rgb'][sel].mean(0).astype(np.float32), 'tone_sd': float(np.std(mu[ok]) / max(np.mean(mu[ok]), 1e-6)),
                     'grain_sd': float(np.mean(np.sqrt(np.clip(var[ok], 0, None)) / np.maximum(mu[ok], 1e-6))), 'rough': float(exe['rough'][sel].mean())}
    return out


def transfer_field(ex, lab, d, roll, f, score, seed=7, k_pool=24, knn=4):
    """colour + roughness for target field texels (flat arrays) by tile-local features from the canon exemplar.
    lab: target component ids (>0), score: per-texel coherent weathering target 0..1 (smooth world noise) - each target
    component takes a TC component of its type (roll/pan) whose weathering rank matches the score (random among k_pool),
    then every texel takes the TC texel of that component nearest in (f, d)."""
    rng = np.random.default_rng(seed)
    full = np.nonzero(ex['comp_full'])[0]; ctype = ex['comp_roll'][full] > .5
    order_by_type = {}
    for t in (False, True):
        cids = full[ctype == t]; w = ex['comp_green'][cids] * 3 + (ex['comp_lum'][cids].mean() - ex['comp_lum'][cids])   # moss + darkness
        order_by_type[t] = cids[np.argsort(w)]
    # texel index per TC component
    srt = np.argsort(ex['comp'], kind='stable'); starts = np.searchsorted(ex['comp'][srt], np.arange(len(ex['comp_n']) + 1))
    trees = {}
    out_rgb = np.zeros((len(lab), 3), np.float32); out_r = np.zeros(len(lab), np.float32)
    tl = np.unique(lab)
    for c in tl:
        m = lab == c; typ = bool(roll[m].mean() > .5); pool = order_by_type[typ]
        s = float(np.clip(np.median(score[m]), 0, 1)); i0 = int(s * (len(pool) - 1))
        lo, hi = max(0, i0 - k_pool // 2), min(len(pool), i0 + k_pool // 2 + 1)
        src = int(pool[rng.integers(lo, hi)])
        if src not in trees:
            ii = srt[starts[src]:starts[src + 1]]; trees[src] = (cKDTree(np.c_[ex['f'][ii], ex['d'][ii]]), ii)
        tr, ii = trees[src]; dist, j = tr.query(np.c_[f[m], d[m]], k=min(knn, len(ii)))
        if j.ndim == 1:
            dist, j = dist[:, None], j[:, None]
        w = 1. / np.maximum(dist, 1e-3); w /= w.sum(1, keepdims=True)                   # k-NN blend: no nearest-texel blocks
        out_rgb[m] = (ex['rgb'][ii[j]] * w[..., None]).sum(1); out_r[m] = (ex['rough'][ii[j]] * w).sum(1)
    return out_rgb, out_r


def canon_grain(ex):
    """within-tile relative luma std of the canon field (photo grain): re-injected where a target is denser than the canon."""
    lum = ex['rgb'] @ [.2126, .7152, .0722]; c = ex['comp']; n_ = np.bincount(c)
    mu = np.bincount(c, lum) / np.maximum(n_, 1); var = np.bincount(c, lum * lum) / np.maximum(n_, 1) - mu ** 2
    ok = n_ > 50; return float(np.median(np.sqrt(np.clip(var[ok], 0, None)) / np.maximum(mu[ok], 1e-6)))


def match_slopes(nm01, mask, target_q):
    """monotone remap of the tangent-normal slope angle inside mask to the canonical quantiles (azimuth kept)."""
    v = nm01[..., :3] * 2 - 1; v /= np.maximum(np.linalg.norm(v, axis=-1, keepdims=True), 1e-6)
    s = np.hypot(v[..., 0], v[..., 1]); th = np.degrees(np.arcsin(np.clip(s, 0, 1)))
    qs = np.linspace(0, 100, len(target_q)); src_q = np.percentile(th[mask], qs)
    th2 = np.interp(th, src_q, np.asarray(target_q, float)); k = np.where(s > 1e-6, np.sin(np.radians(th2)) / np.maximum(s, 1e-6), 1.)
    out = v.copy(); out[..., 0] *= k; out[..., 1] *= k; out[..., 2] = np.cos(np.radians(th2))
    out = np.where(mask[..., None], out, v)
    return (out * .5 + .5).astype(np.float32)


def profile(rgb_lin, roll, f, d, slope=None):
    """appearance profile of a roof field (flat arrays): colour mean/std per (roll, f-bin, d-bin) + global stats."""
    lum = rgb_lin @ [.2126, .7152, .0722]; Y = (srgb(np.clip(lum, 0, 1)) * 255)
    prof = {}
    for r_ in (0, 1):
        for fb in range(5):
            for db in range(3):
                m = ((roll > .5) == bool(r_)) & (f >= fb / 5) & (f < (fb + 1) / 5 + (fb == 4)) & (d >= db / 3) & (d < (db + 1) / 3 + (db == 2))
                if m.sum() > 50:
                    prof[f'{"roll" if r_ else "pan"}_f{fb}_d{db}'] = [round(float(Y[m].mean()), 2), round(float(Y[m].std()), 2)]
    hp = Y - ndimage.uniform_filter1d(Y, 9)
    g = {'Y_mean': round(float(Y.mean()), 2), 'Y_std': round(float(Y.std()), 2), 'bright_spec': round(float((hp > 18).mean()), 4),
         'dark_spec': round(float((hp < -18).mean()), 4),
         # equal-weight bin means: independent of how much area a building's tile section gives rolls vs pans
         'roll_pan_ratio': round(float(np.mean([v[0] for k, v in prof.items() if k.startswith('roll')]) /
                                       max(np.mean([v[0] for k, v in prof.items() if k.startswith('pan')]), 1e-3)), 3),
         'green_frac': round(float(((rgb_lin[:, 1] - np.maximum(rgb_lin[:, 0], rgb_lin[:, 2])) > .004).mean()), 4)}
    if slope is not None:
        g['slope_p50_p75_p90'] = [round(float(np.percentile(slope, q)), 1) for q in (50, 75, 90)]
    return {'bins': prof, 'global': g}


def gate(target, canon, tol_bin=6., tol_ratio=.06, tol_spec=.5):
    """compare two profiles: per-bin mean luma within tol_bin (8-bit), roll/pan contrast within tol_ratio, speck and green
    fractions within +-tol_spec relative, slope quantiles within 4 deg. Returns (ok, failures)."""
    fails = []
    for k, (mu, sd) in canon['bins'].items():
        if k in target['bins'] and abs(target['bins'][k][0] - mu) > tol_bin:
            fails.append(f'bin {k}: {target["bins"][k][0]} vs canon {mu}')
    tg, cg = target['global'], canon['global']
    if abs(tg['roll_pan_ratio'] - cg['roll_pan_ratio']) > tol_ratio:
        fails.append(f'roll/pan {tg["roll_pan_ratio"]} vs {cg["roll_pan_ratio"]}')
    for k in ('bright_spec', 'dark_spec', 'green_frac'):
        if cg[k] > 0 and abs(tg[k] - cg[k]) / cg[k] > tol_spec:
            fails.append(f'{k} {tg[k]} vs {cg[k]}')
    if 'slope_p50_p75_p90' in tg and 'slope_p50_p75_p90' in cg:
        for a_, b_ in zip(tg['slope_p50_p75_p90'], cg['slope_p50_p75_p90']):
            if abs(a_ - b_) > 4:
                fails.append(f'slope {tg["slope_p50_p75_p90"]} vs {cg["slope_p50_p75_p90"]}'); break
    return not fails, fails


if __name__ == '__main__':
    ap = argparse.ArgumentParser(); ap.add_argument('cmd', choices=['build', 'profile']); ap.add_argument('--pack', required=True)
    a = ap.parse_args()
    if a.cmd == 'build':
        build(a.pack)
    else:
        ex, _, rep = load_exemplar(a.pack)
        P = tc_page(a.pack, 'P2048'); m = P['cls']['ROOF_TILE'] & P['has'] & (P['bc'][..., 3] > .5)
        prof = profile(ex['rgb'], ex['roll'], ex['f'], ex['d'], slope_deg(P['nm'][m]))
        json.dump(prof, open(Path(a.pack) / 'CANON_PROFILE.json', 'w'), indent=1); print('PROFILE', json.dumps(prof['global']))
