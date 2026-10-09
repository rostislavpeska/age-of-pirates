"""Automated texture-map QA detectors for baked low-poly page maps (plain Python + numpy; PIL for rasters).

python qa_detectors.py config.json        -> writes the report, exit 3 on any FAIL (like qa_textures.py)
Specimen proof: test_qa_detectors.py (pytest). Real-data proof (Korean TC): Texturing_11/Claude_CP2/qa_detectors.

One function per detector; each returns {"verdict": "PASS"|"FAIL"|"SKIP", ...numbers, "reasons": [...]}
(SKIP = not assessable, e.g. fewer than 4 analysis windows fit inside the mask; never counted as a pass).
  rhythm_check          two unrelated periodicities along one axis in a normal map (unlocked procedural bump
                        over modelled rows = "extra stripes"), and any repeated feature shorter than min_period.
  stacked_normal_check  a second normal printed over a baked structure: final vs bake slopes, after removing
                        the part the bake explains (k * bake), must leave (almost) nothing.
  uv_registration_check members that read the WRONG part of their owner's texels (straddle an owner fold, or
                        their own fold is not on an owner fold), members on unbaked texels, mirrored members on
                        directional materials, member/owner texel-density stretch.
  mask_offset_check     a mask (edge wear, dirt) not registered to its reference (normal edges, AO): best
                        cross-correlation offset > max_offset texels, or no correlation (another layout).
  mask_layout_check     mask energy outside the UV islands (a mask from another UV layout).
  channel_packing_check packed Masks channels hold what the spec says (AO / roughness / metallic).
  class_pattern_check   per class: repeated features shorter than min_period texels, and flat fills.
  eave_alpha_check      eave cutout regression gate: FRONT cut 15-35 %, UNDER hanging part >= 90 %, BACK/UNDER
                        match the FRONT in front (members included), alpha edge on the baked tile outline.
                        config {"type": "eave_alpha", "plan", "geometry", "sources", "alpha", "normal", "page"}
  class_mismatch_check  a face that samples texels of another class through the plan: its class (plan material, or
                        an independent per-face truth: "expected" = authored material) vs the ClassID texels its UV
                        polygon covers (e.g. a wooden frame reading plaster = white). config {"type": "class_mismatch",
                        "plan", "classmap": {"path", "palette": {CLASS: [r,g,b] sRGB 0-1}} | {"path", "scale": 16},
                        "classes", "pages", "expected": {key: CLASS} | path, "equivalent": [[CLASS, ..]]}
  relief_missing_check  relief regression gate (owner 2026-09-29: "planks not on the model ... should NOT pass the next
                        time"): albedo LINES (seams, member edges, sheet outlines) with no oriented relief within 2
                        texels, per 16x16 tile, named per face; owner waivers pass. config {"type": "relief_missing",
                        "basecolor", "normal", "valid"?}. Korean TC CLI with faces/elements: Claude_CP2/relief_gate.py
  relief_drop_check     tiles whose relief RMS falls by > half vs a base must lie in the job's DECLARED relief-removal
                        scope, else FAIL. config {"type": "relief_drop", "normal", "base", "declared"? (mask spec)}
  masks_missing_check   D9, the Masks twin of relief_missing (owner 2026-10-09: "the doors have no normals and masks
                        maps"): albedo LINES with no line in any Masks channel (AO, roughness, metallic) within 2 texels,
                        per 16x16 tile, named per face. config {"type": "masks_missing", "basecolor", "masks", "valid"?}

Images: .png/.jpg/.tif (8/16 bit, read as 0..1), .npy, .exr (converted once by background Blender into a
cache .npy - set QA_BLENDER to the executable, QA_CACHE to the cache dir). Arrays are top-down (row 0 = the
top of the image, v = 1), float32, HxWxC. UV (u, v) -> texel (x = u * size, y = (1 - v) * size).

config = {"out": "report.json",
          "checks": [{"id": "roof_R0", "type": "rhythm", "normal": "N.png",
                      "mask": {"path": "COV.exr", "channel": 0, "threshold": 0.5}, "window": 96},
                     {"type": "stacked_normal", "final": "F.png", "bake": "B.exr", "mask": {...},
                      "classmap": {...}, "classes": [...], "bake_only": ["WINDOW_ASSEMBLY", "ROOF_TILE"]},
                     {"type": "uv_registration", "plan": "plan.json", "geometry": "faces.json",
                      "sources": {"Obj_A": "S12_Groups_A"}, "pages": {"P1024": 1024}, "directional": ["SIGN_DECOR"]},
                     {"type": "mask_offset", "mask": "EdgeWear.png", "reference": "Normal.png",
                      "reference_kind": "normal_edges", "valid": {...}},
                     {"type": "mask_layout", "mask": "Dirt.png", "valid": {...}},
                     {"type": "channel_packing", "masks": "Masks.png", "classmap": {"path": "CLS.exr", "scale": 16},
                      "classes": [...], "channels": {"R": "ao", "G": "roughness", "B": "metallic"},
                      "metal_classes": ["METAL"], "valid": {...}},
                     {"type": "class_pattern", "image": "BaseColor.png", "classmap": {...}, "classes": [...]}]}
A mask spec is {"path", "channel": 0, "threshold": 0.5} or {"path", "mode": "length"} (vector length > 0.5,
e.g. a baked world-normal = the valid texels); a bare string means channel 0 > 0.5.
Thresholds and their measured justification: references/texturing-qa.md "Automated detectors".
"""
import hashlib
import json
import os
import subprocess
import sys
import tempfile
from collections import Counter, defaultdict
from pathlib import Path

import numpy as np

BLENDER = os.environ.get('QA_BLENDER', r'C:\Program Files\Blender Foundation\Blender 5.0\blender.exe')


# ----------------------------------------------------------------------------------------------- image IO
def _cache_path(path):
    p = Path(path).resolve(); st = p.stat()
    key = hashlib.sha1(f'{p}|{st.st_mtime_ns}|{st.st_size}'.encode()).hexdigest()[:20]
    root = Path(os.environ.get('QA_CACHE', Path(tempfile.gettempdir()) / 'qa_detectors_cache'))
    root.mkdir(parents=True, exist_ok=True)
    return root / f'{p.stem}_{key}.npy'


def prefetch_exr(paths):
    """Convert every not-yet-cached EXR with ONE background Blender run."""
    todo = [(str(Path(p).resolve()), str(_cache_path(p))) for p in paths
            if str(p).lower().endswith('.exr') and not _cache_path(p).exists()]
    if not todo:
        return
    with tempfile.NamedTemporaryFile('w', suffix='.json', delete=False) as f:
        json.dump(todo, f); jobs = f.name
    r = subprocess.run([BLENDER, '-b', '--factory-startup', '--python', str(Path(__file__).resolve()),
                        '--', '--convert-exr', jobs], capture_output=True, text=True)
    os.unlink(jobs)
    missing = [s for s, d in todo if not Path(d).exists()]
    if missing:
        raise RuntimeError(f'EXR conversion failed for {missing[:3]}: {r.stdout[-800:]} {r.stderr[-800:]}')


def _blender_convert(jobs_json):  # runs INSIDE background Blender
    import bpy
    for src, dst in json.load(open(jobs_json)):
        im = bpy.data.images.load(src, check_existing=False); im.colorspace_settings.name = 'Non-Color'
        w, h = im.size; ch = im.channels
        a = np.empty(w * h * ch, np.float32); im.pixels.foreach_get(a)
        a = a.reshape(h, w, ch)[::-1, :, :min(ch, 3)]            # Blender rows are bottom-up
        np.save(dst, a.astype(np.float16)); bpy.data.images.remove(im)
        print('CONVERTED', src)


def read_map(path):
    """float32 HxWxC, top-down. PNG/TIF integer data scaled to 0..1."""
    path = str(path); low = path.lower()
    if low.endswith('.npy'):
        a = np.load(path)
    elif low.endswith('.exr'):
        prefetch_exr([path]); a = np.load(_cache_path(path))
    else:
        try:
            import cv2
            a = cv2.imread(path, cv2.IMREAD_UNCHANGED)
            if a is None:
                raise OSError(path)
            if a.ndim == 3:
                a = a[..., [2, 1, 0, 3][:a.shape[2]]] if a.shape[2] >= 3 else a
        except ImportError:
            from PIL import Image
            a = np.asarray(Image.open(path))
        a = a.astype(np.float32) / (65535.0 if a.dtype == np.uint16 else 255.0) if a.dtype.kind in 'ui' else a
    a = np.asarray(a, np.float32)
    return a[..., None] if a.ndim == 2 else a


def read_mask(spec, shape=None):
    if spec is None:
        return None if shape is None else np.ones(shape[:2], bool)
    if isinstance(spec, str):
        spec = {'path': spec}
    a = read_map(spec['path'])
    if spec.get('mode') == 'length':
        m = np.linalg.norm(a[..., :3], axis=-1) > spec.get('threshold', 0.5)
    else:
        m = a[..., spec.get('channel', 0)] > spec.get('threshold', 0.5)
    return ~m if spec.get('invert') else m


def read_classmap(spec):
    a = read_map(spec['path'])[..., spec.get('channel', 0)]
    return np.rint(a * spec.get('scale', 16)).astype(int)


# ----------------------------------------------------------------------------------------------- helpers
def slopes(normal_rgb):
    """tangent-space slope components (nx, ny) of an encoded normal map (0..1 -> -1..1)."""
    return normal_rgb[..., :2] * 2.0 - 1.0


def luma(rgb):
    if rgb.shape[-1] == 1:
        return rgb[..., 0]
    return rgb[..., 0] * .2126 + rgb[..., 1] * .7152 + rgb[..., 2] * .0722


def box_blur(x, r):
    """mean over a (2r+1)^2 box, edge-clamped (integral image)."""
    if r <= 0:
        return x.copy()
    p = np.pad(x.astype(np.float64), r + 1, mode='edge'); c = p.cumsum(0).cumsum(1)
    k = 2 * r + 1; h, w = x.shape
    s = c[k:k + h, k:k + w] - c[0:h, k:k + w] - c[k:k + h, 0:w] + c[0:h, 0:w]
    return (s / (k * k)).astype(np.float32)


def erode(mask, r):
    return box_blur(mask.astype(np.float32), r) > 0.999 if r > 0 else mask


# ----------------------------------------------------------------------------------------------- D1 rhythms
# Measured (2026-09-28, Korean TC roof banks): 2-D window spectra mis-assigned the slope harmonics (a thin tile
# lip puts as much power in its 2nd/3rd harmonic as in the fundamental) and a single eave band read as a period.
# What works: per window and per UV axis, the power spectrum of every line averaged over the lines (phase-free,
# so rows staggered per tile column keep their peak), sharp peaks only, then a harmonic-sum grouping.
def line_spectrum(sig, mask, axis, pad=4):
    """sig HxWxK (square window), axis 0 = along y (each column is a line), 1 = along x. Mean power over lines
    of the Hann-windowed, per-line mean-removed signal (texels outside the mask count as the line mean)."""
    if axis == 1:
        sig = sig.transpose(1, 0, 2); mask = mask.T
    L = sig.shape[0]; n = L * pad; hw = np.hanning(L)[:, None]; P = np.zeros(n // 2 + 1)
    cnt = np.maximum(mask.sum(0, keepdims=True), 1)
    for c in range(sig.shape[2]):
        s = sig[..., c]; mu = np.where(mask, s, 0).sum(0, keepdims=True) / cnt
        P += (np.abs(np.fft.rfft(np.where(mask, s - mu, 0.0) * hw, n, axis=0)) ** 2).mean(1)
    return np.arange(len(P)) / n, P


def line_peaks(f, P, L, min_rel=0.12, min_prom=4.0, fmin_bins=1.5, max_width=3.0, min_texels=3.0):
    """sharp periodic peaks: local max >= min_rel x the strongest power above fmin, >= min_prom x the higher of
    the two valleys within 3 bins, half-power width <= max_width bins (>= ~3 repetitions inside the window;
    a single band or blob gives a broad hump). Periods under min_texels are ignored (aliased harmonics of sharp
    lips fold back there at non-harmonic positions)."""
    ok = (f >= fmin_bins / L) & (f <= 1.0 / min_texels); df = f[1] - f[0]; nb = max(int(round(1.0 / (L * df))), 1)
    idx = [i for i in range(1, len(P) - 1) if ok[i] and P[i] >= P[i - 1] and P[i] > P[i + 1]]
    if not idx:
        return []
    top = P[ok].max(); out = []
    for i in idx:
        if P[i] < min_rel * top:
            continue
        lo = P[max(i - 3 * nb, 0):i].min(); hi = P[i + 1:i + 1 + 3 * nb].min()
        prom = P[i] / max(lo, hi, 1e-30)
        l, r = i, i
        while l > 0 and P[l] > 0.5 * P[i]:
            l -= 1
        while r < len(P) - 1 and P[r] > 0.5 * P[i]:
            r += 1
        width = (r - l) * df * L
        if prom < min_prom or width > max_width:
            continue
        a, b, c = np.log(P[i - 1:i + 2] + 1e-30); d = a - 2 * b + c
        fi = (i + (0.5 * (a - c) / d if d < 0 else 0.0)) * df
        out.append(dict(f=float(fi), period=round(float(1 / fi), 2), rel=round(float(P[i] / top), 3),
                        prom=round(float(prom), 1), width=round(float(width), 2)))
    return out


def rhythms(peaks, L, tol_rel=0.04, tol_bins=0.3, kmax=16, max_period=48.0, mmax=3, implied_penalty=0.85):
    """Greedy harmonic-sum grouping. Candidates: every peak frequency / m (m = 1..mmax, period <= max_period:
    the missing fundamental of 2nd/3rd harmonics). Pick the candidate whose integer multiples explain the most
    peak power (ties -> the shorter period, a real peak preferred), remove what it explains, repeat. Returns
    [{period, strength (sum of rel), explains [periods], implied}], one entry per rhythm. Tolerance 0.3 bin +
    4 % of f (row drift on curved slopes grows with the harmonic): at window 96 a 13-texel course sits only
    0.75 bin from the 2nd harmonic of 31-texel rows (0.5 bin + 4 % merged them), while the fixed roof puts
    its 3rd row harmonic 6.5 % off (3 % flagged it)."""
    left = list(peaks); out = []

    def tol(f):
        return tol_bins / L + tol_rel * f
    while left:
        best = None
        for p in left:
            for m in range(1, mmax + 1):
                F = p['f'] / m
                if m > 1 and 1 / F > max_period:
                    break
                ex = [q for q in left if 1 <= round(q['f'] / F) <= kmax and abs(q['f'] - round(q['f'] / F) * F) <= tol(q['f'])]
                key = (round(sum(q['rel'] for q in ex) * (1.0 if m == 1 else implied_penalty), 3), F)
                if best is None or key > best[0]:
                    best = (key, F, ex, m > 1)
        _, F, ex, implied = best
        out.append(dict(period=round(1 / F, 2), f=F, strength=round(sum(q['rel'] for q in ex), 3),
                        explains=[q['period'] for q in ex], implied=implied))
        left = [q for q in left if q not in ex]
    return out


def merge_drift(rh, drift=1.2):
    """rhythms whose periods differ by less than `drift` x are one rhythm drifting (a curved roof: rows even along
    the curve drift 27 -> 31 texels along a straight UV axis), not two structures. Only rhythms with a real
    fundamental peak merge: an IMPLIED 26-texel 'fundamental' of a 13-texel course must not hide in 31-texel rows."""
    out = []
    for r in sorted(rh, key=lambda q: -q['strength']):
        for o in out:
            if not (r['implied'] or o['implied']) and max(r['period'], o['period']) / min(r['period'], o['period']) <= drift:
                o['strength'] = round(o['strength'] + r['strength'], 3); o['explains'] = o['explains'] + r['explains']; break
        else:
            out.append(dict(r))
    return out


def analyse_window(sig, mask, min_period=16.0, pair_rel=0.15, **kw):
    """both UV axes of one window -> {'y'|'x': {peaks, rhythms, two, short}}"""
    L = sig.shape[0]; res = {}
    for ax, name in ((0, 'y'), (1, 'x')):
        f, P = line_spectrum(sig, mask, ax)
        pk = line_peaks(f, P, L, **kw); rh = merge_drift(rhythms(pk, L))
        strong = [r for r in rh if r['strength'] >= pair_rel]
        res[name] = dict(peaks=pk, rhythms=rh, two=len(strong) >= 2,
                         short=[r['period'] for r in strong if r['period'] < min_period])
    return res


def scan_windows(sig, mask, window=128, step=None, min_cover=0.9):
    step = step or window // 2; h, w = mask.shape
    for y in range(0, max(h - window, 0) + 1, step):
        for x in range(0, max(w - window, 0) + 1, step):
            m = mask[y:y + window, x:x + window]
            if m.shape == (window, window) and m.mean() >= min_cover:
                yield y, x, sig[y:y + window, x:x + window], m


def rhythm_check(image, mask=None, window=96, step=None, min_cover=0.9, min_period=16.0, max_flag_frac=0.3,
                 min_flag_windows=2, signal='slopes', fail_short=True, pair_rel=0.15, min_windows=4):
    """Two unrelated rhythms along one UV axis (same texels), or a rhythm shorter than min_period texels.
    image: encoded normal (signal='slopes') or colour (signal='luma'). window >= 3 x the longest modelled period
    (96 at 107 texels/unit: the roof rows are ~31 texels; 64 cannot resolve them and reads their 2nd harmonic
    as a short rhythm). A window is flagged when one axis
    carries >= 2 rhythms of strength >= pair_rel (or a short one); FAIL when flagged windows exceed
    max_flag_frac of the windows scanned inside the mask (and >= min_flag_windows). Two DIFFERENT structures
    that merely sit side by side in one window stay well below max_flag_frac on real maps."""
    sig = slopes(image) if signal == 'slopes' else luma(image)[..., None]
    mask = np.ones(image.shape[:2], bool) if mask is None else mask
    rows = []; periods = Counter()
    for y, x, s, m in scan_windows(sig, mask, window, step, min_cover):
        a = analyse_window(s, m, min_period=min_period, pair_rel=pair_rel)
        for ax in a:
            for r in a[ax]['rhythms']:
                if r['strength'] >= pair_rel:
                    periods[(ax, int(round(r['period'])))] += 1
        rows.append(dict(y=y, x=x, two=[ax for ax in a if a[ax]['two']], short=[p for ax in a for p in a[ax]['short']],
                         rhythms={ax: [(r['period'], r['strength']) for r in a[ax]['rhythms'] if r['strength'] >= pair_rel] for ax in a}))
    n = len(rows); n_two = sum(bool(r['two']) for r in rows); n_short = sum(bool(r['short']) for r in rows)
    reasons = []
    checks = [('two rhythms on one axis', n_two)] + ([(f'rhythm shorter than {min_period} texels', n_short)] if fail_short else [])
    for name, cnt in checks:
        if n and cnt >= min_flag_windows and cnt / n > max_flag_frac:
            reasons.append(f'{name}: {cnt}/{n} windows')
    verdict = 'FAIL' if reasons else 'PASS'
    if n < min_windows:                     # 2-3 windows decide nothing (a small bank: 1 drifting window = 50 %)
        verdict, reasons = 'SKIP', [f'only {n} {window}x{window} windows fit inside the mask (< {min_windows})']
    return dict(verdict=verdict, reasons=reasons, windows=n, two_rhythm_windows=n_two,
                short_period_windows=n_short, flag_frac=round(max(n_two, n_short if fail_short else 0) / max(n, 1), 3),
                common_rhythms=[(f'{ax}:{p}', c) for (ax, p), c in periods.most_common(8)],
                examples=[r for r in rows if r['two'] or r['short']][:5])


# ----------------------------------------------------------------------------------------------- D2 stacking
def stacked_normal_check(final, bake, mask=None, max_added=0.35, min_bake_rms=0.01):
    """A detail normal printed over a baked structure. Least-squares fit final_slopes = k * bake_slopes + r
    inside the mask (k absorbs a global strength change); added = rms(r) / rms(bake). FAIL when
    added > max_added. A bake-only class (window lattice, roof tiles) should read ~0."""
    mask = np.ones(final.shape[:2], bool) if mask is None else mask
    f = slopes(final)[mask].astype(np.float64); b = slopes(bake)[mask].astype(np.float64)
    if len(b) == 0:
        return dict(verdict='FAIL', reasons=['empty mask'])
    rb = float(np.sqrt((b ** 2).sum(1).mean()))
    if rb < min_bake_rms:
        return dict(verdict='PASS', reasons=[], note='bake is flat here - nothing to protect', bake_rms=rb)
    k = float((f * b).sum() / (b * b).sum()); r = f - k * b
    added = float(np.sqrt((r ** 2).sum(1).mean())) / rb
    reasons = [f'added structure {added:.2f} x the bake (> {max_added})'] if added > max_added else []
    return dict(verdict='FAIL' if reasons else 'PASS', reasons=reasons, added=round(added, 3), k=round(k, 3),
                bake_rms=round(rb, 4), texels=int(mask.sum()))


# ----------------------------------------------------------------------------------------------- D3 UV members
def _vkey(p):
    return tuple(np.round(np.asarray(p, float), 4))


def _shoelace(pts):
    x, y = pts[:, 0], pts[:, 1]
    return 0.5 * float(np.dot(x, np.roll(y, -1)) - np.dot(y, np.roll(x, -1)))


def _jacobian(tex, verts):
    """world units per texel along the texel x and y axes (3x2), least squares over the polygon."""
    A = tex - tex.mean(0); P = verts - verts.mean(0)
    J, *_ = np.linalg.lstsq(A, P, rcond=None)
    return J.T


def load_geometry(path, sources):
    """ridge_faces.json style dump {object: {"faces": [{"i", "n", "v", ...}]}} -> {plan_key: face}."""
    F = json.load(open(path, encoding='utf-8-sig')); geo = {}
    for ob, prefix in sources.items():
        for f in F[ob]['faces']:
            geo[f'{prefix}:{f["i"]}'] = f
    return geo


def uv_registration_check(plan, geo, page, size, directional=(), min_share=0.9, fold_deg=15.0, max_stretch=1.4,
                          ss=4, min_member_texels=6.0, offset=1.5, texels_per_unit=None, materials=None,
                          dihedral_tol=10.0):
    """plan: {key: {page, uv, family, owner, material}}; geo: {key: {v, n}} (loop order = plan uv order).
    Per member face: share = fraction of its texels on its dominant owner REGION (owner faces joined across
    edges folding less than fold_deg); fold = fraction of samples along each member fold (dihedral > fold_deg)
    whose two sides read DIFFERENT owner regions meeting at the same dihedral (+- dihedral_tol; a chart shifted
    by exactly one row lands every fold on the NEXT owner fold, which differs in angle). score = min(share, fold) < min_share -> MISREGISTERED.
    fold_deg 15: the eave FRONT/UNDER fold is 20-23 deg (a 25 deg threshold merged both rows into one region
    and caught only 28 of the 52 known members); face-to-face roof curvature is <= 25 deg but a correctly
    registered member sits inside its owner face, so a low threshold costs nothing there.
    Also: NO_OWNER (> 50 % on texels no owner bakes), MIRRORED (UV winding opposite to the dominant owner face,
    only for `directional` materials), STRETCHED (member/owner world size per texel along u or v > max_stretch)."""
    from PIL import Image, ImageDraw, ImageFilter
    fams = defaultdict(list)
    for k, e in plan.items():
        if e['page'] == page and k in geo and (materials is None or e['material'] in materials):
            fams[e['family']].append(k)
    res = {}; cos_fold = np.cos(np.radians(fold_deg))
    for fam, keys in fams.items():
        owners = [k for k in keys if plan[k]['owner']]; members = [k for k in keys if not plan[k]['owner']]
        if not members:
            continue
        tex = {k: np.array([[u * size, (1 - v) * size] for u, v in plan[k]['uv']]) for k in keys}
        ver = {k: np.array(geo[k]['v'], float) for k in keys}; nrm = {k: np.array(geo[k]['n'], float) for k in keys}
        allp = np.vstack([tex[k] for k in keys]); x0, y0 = np.floor(allp.min(0)) - 4; x1, y1 = np.ceil(allp.max(0)) + 4
        W, H = int((x1 - x0) * ss), int((y1 - y0) * ss)
        to_px = lambda p: [((a - x0) * ss, (b - y0) * ss) for a, b in p]
        # owner regions: union-find across shared 3D edges that fold less than fold_deg
        par = {k: k for k in owners}

        def root(a):
            while par[a] != a:
                par[a] = par[par[a]]; a = par[a]
            return a
        edges = defaultdict(list)
        for k in keys:
            vk = [_vkey(p) for p in ver[k]]
            for i in range(len(vk)):
                edges[frozenset((vk[i], vk[(i + 1) % len(vk)]))].append((k, i))
        for e, lst in edges.items():
            ol = [k for k, _ in lst if plan[k]['owner']]
            for a in ol:
                for b in ol:
                    if a < b and np.dot(nrm[a], nrm[b]) > cos_fold:
                        par[root(a)] = root(b)
        rid = {k: i + 1 for i, k in enumerate(sorted({root(k) for k in owners}))}
        region = {k: rid[root(k)] for k in owners}
        lab_im = Image.new('I', (W, H), 0); face_im = Image.new('I', (W, H), 0)
        dl, df = ImageDraw.Draw(lab_im), ImageDraw.Draw(face_im)
        for i, k in enumerate(owners):
            dl.polygon(to_px(tex[k]), fill=region[k]); df.polygon(to_px(tex[k]), fill=i + 1)
        lab = np.asarray(lab_im, np.int32); fid = np.asarray(face_im, np.int32)

        def label_at(pts):
            q = np.clip(np.rint((np.asarray(pts) - [x0, y0]) * ss - 0.5).astype(int), 0, [W - 1, H - 1])
            return lab[q[:, 1], q[:, 0]], fid[q[:, 1], q[:, 0]]
        mset = set(members)
        for k in members:
            area = abs(_shoelace(tex[k]))
            if area < min_member_texels:
                res[k] = dict(verdict='TINY', texels=round(area, 1), material=plan[k]['material']); continue
            mi = Image.new('L', (W, H), 0); ImageDraw.Draw(mi).polygon(to_px(tex[k]), fill=1)
            m = np.asarray(mi, bool)
            # texel-centre style: drop the rasteriser's outline ring when the polygon is thick enough
            me = np.asarray(Image.fromarray(m.astype(np.uint8) * 255).filter(ImageFilter.MinFilter(3))) > 0
            m = me if me.sum() > 0.5 * m.sum() else m
            labs = lab[m]; tot = len(labs)
            cnt = Counter(labs.tolist()); none = cnt.pop(0, 0) / tot
            dom, dn = (cnt.most_common(1)[0] if cnt else (0, 0)); share = dn / tot
            # fold registration
            fold_scores = []
            vk = [_vkey(p) for p in ver[k]]; cf = tex[k].mean(0)
            for i in range(len(vk)):
                e = frozenset((vk[i], vk[(i + 1) % len(vk)]))
                for g, j in edges[e]:
                    if g == k or g not in mset or np.dot(nrm[k], nrm[g]) > cos_fold:
                        continue
                    a, b = tex[k][i], tex[k][(i + 1) % len(vk)]
                    gv = [_vkey(p) for p in ver[g]]; ga, gb = tex[g][j], tex[g][(j + 1) % len(gv)]
                    if gv[j] != vk[i]:
                        ga, gb = gb, ga
                    if max(np.linalg.norm(ga - a), np.linalg.norm(gb - b)) > 0.75:
                        continue                                 # UV seam between the two members: no shared edge
                    d = b - a; L = np.linalg.norm(d)
                    if L < 2:
                        continue
                    nn = np.array([-d[1], d[0]]) / L; cg = tex[g].mean(0)
                    sf = nn if np.dot(cf - a, nn) > 0 else -nn; sg = nn if np.dot(cg - a, nn) > 0 else -nn
                    if np.dot(sf, sg) > 0:
                        continue                                 # both faces on one side in UV: overlapped, skip
                    t = np.linspace(0.15, 0.85, 9)[:, None]; pts = a + t * d
                    (la, fa), (lb, fb) = label_at(pts + offset * sf), label_at(pts + offset * sg)
                    th_m = np.degrees(np.arccos(np.clip(np.dot(nrm[k], nrm[g]), -1, 1)))
                    th_o = np.array([np.degrees(np.arccos(np.clip(np.dot(nrm[owners[x - 1]], nrm[owners[y - 1]]), -1, 1)))
                                     if x > 0 and y > 0 else 999.0 for x, y in zip(fa, fb)])
                    ok = (la != lb) & (la > 0) & (lb > 0) & (np.abs(th_o - th_m) <= dihedral_tol)
                    fold_scores.append(float(np.mean(ok)))
            fold = min(fold_scores) if fold_scores else 1.0
            score = min(share, fold)
            # dominant owner face -> mirror + stretch
            fids = fid[m]; fids = fids[fids > 0]
            flags = []
            info = dict(material=plan[k]['material'], share=round(share, 3), fold=round(fold, 3),
                        none=round(none, 3), folds=len(fold_scores), family=fam)
            if none > 0.5:
                flags.append('NO_OWNER')
            elif score < min_share:
                flags.append('MISREGISTERED')
            if len(fids):
                o = owners[Counter(fids.tolist()).most_common(1)[0][0] - 1]; info['owner'] = o
                mirrored = np.sign(_shoelace(tex[k])) != np.sign(_shoelace(tex[o]))
                info['mirrored'] = bool(mirrored)
                if mirrored and plan[k]['material'] in directional:
                    flags.append('MIRRORED')
                Jm, Jo = _jacobian(tex[k], ver[k]), _jacobian(tex[o], ver[o])
                st = [float(np.linalg.norm(Jm[:, c]) / max(np.linalg.norm(Jo[:, c]), 1e-9)) for c in (0, 1)]
                s = max(max(x, 1 / x) for x in st if x > 0); info['stretch'] = round(s, 3)
                if texels_per_unit:
                    info['density'] = [round(1 / max(np.linalg.norm(Jm[:, c]), 1e-9), 1) for c in (0, 1)]
                if s > max_stretch:
                    flags.append('STRETCHED')
            info['flags'] = flags; info['verdict'] = 'FAIL' if flags else 'OK'
            res[k] = info
    bad = {k: v for k, v in res.items() if v['verdict'] == 'FAIL'}
    by = Counter(f for v in bad.values() for f in v['flags'])
    reasons = [f'{n} members {f}' for f, n in by.items()]
    return dict(verdict='FAIL' if bad else 'PASS', reasons=reasons, members=len(res), flagged=len(bad),
                by_flag=dict(by), flagged_faces=sorted(bad), faces=res)


# ----------------------------------------------------------------------------------------------- D4 masks
def normal_edges(normal):
    """edge strength of an encoded normal: gradient magnitude of the slope components."""
    s = slopes(normal); e = np.zeros(s.shape[:2], np.float32)
    for c in range(2):
        gy, gx = np.gradient(s[..., c]); e += gx * gx + gy * gy
    return np.sqrt(e)


def ncc_offsets(a, b, valid, search=6, hp=8):
    """normalised cross-correlation of b shifted by (dy, dx) against a, high-passed, over joint valid texels.
    Returns ({(dy, dx): corr}, best (dy, dx), best corr, corr at (0, 0))."""
    a = np.where(valid, a - box_blur(a, hp), 0).astype(np.float32)
    b = np.where(valid, b - box_blur(b, hp), 0).astype(np.float32)
    s = search; A = a[s:-s, s:-s]; V = valid[s:-s, s:-s]; out = {}
    for dy in range(-s, s + 1):
        for dx in range(-s, s + 1):
            B = b[s + dy:b.shape[0] - s + dy, s + dx:b.shape[1] - s + dx]
            VB = valid[s + dy:b.shape[0] - s + dy, s + dx:b.shape[1] - s + dx] & V
            x, y = A[VB], B[VB]
            out[(dy, dx)] = float((x * y).sum() / np.sqrt((x * x).sum() * (y * y).sum() + 1e-12))
    best = max(out, key=out.get)
    return out, best, out[best], out[(0, 0)]


def mask_offset_check(mask, reference, valid, reference_kind='normal_edges', search=6, max_offset=2,
                      min_corr=0.1, hp=8):
    """mask: HxW (edge wear, dirt); reference: encoded normal (reference_kind='normal_edges': edges of the
    normal), or a scalar map ('scalar': e.g. AO, 'inverse': 1 - map, e.g. dirt vs AO). FAIL when the best
    correlation sits more than max_offset texels away from (0, 0), or the best correlation < min_corr."""
    if reference_kind == 'normal_edges':
        ref = normal_edges(reference)
    else:
        ref = luma(reference) if reference.ndim == 3 else reference
        ref = 1 - ref if reference_kind == 'inverse' else ref
    m = luma(mask) if mask.ndim == 3 else mask
    _, best, cbest, c0 = ncc_offsets(ref, m, valid, search, hp)
    off = float(np.hypot(*best)); reasons = []
    if off > max_offset:
        reasons.append(f'mask best aligned at offset {best} ({off:.1f} texels > {max_offset})')
    if cbest < min_corr:
        reasons.append(f'mask does not follow its reference (best corr {cbest:.3f} < {min_corr})')
    return dict(verdict='FAIL' if reasons else 'PASS', reasons=reasons, best_offset=list(best),
                best_corr=round(cbest, 4), corr_at_zero=round(c0, 4))


def mask_layout_check(mask, valid, max_outside=0.02, max_empty_island_frac=0.5, island_min_px=64):
    """A mask from another UV layout: energy outside the islands (valid) and islands it leaves empty."""
    m = luma(mask) if mask.ndim == 3 else mask
    tot = float(m.sum()) + 1e-9; outside = float(m[~valid].sum()) / tot
    reasons = []
    if outside > max_outside:
        reasons.append(f'{outside:.1%} of the mask energy lies outside the UV islands')
    return dict(verdict='FAIL' if reasons else 'PASS', reasons=reasons, outside_frac=round(outside, 4))


def channel_packing_check(masks, classmap, classes, valid, channels=None, metal_classes=('METAL',),
                          reference_ao=None):
    """Packed Masks (default R=AO, G=roughness, B=metallic). metallic: ~0 off the metal classes (p99 <= 0.1);
    roughness: a real spread of mid values (p05 >= 0.05, >= 50 % of texels in 0.15..0.98);
    ao: mean >= 0.35 and, with reference_ao, correlation >= 0.5."""
    channels = channels or {'R': 'ao', 'G': 'roughness', 'B': 'metallic'}
    reasons = []; out = {}
    metal_ids = [classes.index(c) for c in metal_classes if c in classes]
    is_metal = np.isin(classmap, metal_ids) & valid
    for ch, role in channels.items():
        x = masks[..., 'RGBA'.index(ch)]; v = x[valid]; st = dict(role=role, mean=round(float(v.mean()), 3))
        if role == 'metallic':
            off = x[valid & ~is_metal]; st['p99_off_metal'] = round(float(np.quantile(off, .99)), 3) if len(off) else 0
            if st['p99_off_metal'] > 0.1:
                reasons.append(f'{ch} (metallic) is non-zero off the metal classes (p99 {st["p99_off_metal"]})')
            if is_metal.sum() > 64:
                st['mean_on_metal'] = round(float(x[is_metal].mean()), 3)
        elif role == 'roughness':
            st['p05'] = round(float(np.quantile(v, .05)), 3); st['mid_frac'] = round(float(((v > .15) & (v < .98)).mean()), 3)
            if st['p05'] < 0.05 or st['mid_frac'] < 0.5:
                reasons.append(f'{ch} (roughness) is not a roughness map (p05 {st["p05"]}, mid {st["mid_frac"]})')
        elif role == 'ao':
            if st['mean'] < 0.35:
                reasons.append(f'{ch} (ao) mean {st["mean"]} < 0.35')
            if reference_ao is not None:
                r = reference_ao[valid]; c = float(np.corrcoef(v, r)[0, 1]); st['corr_ref'] = round(c, 3)
                if c < 0.5:
                    reasons.append(f'{ch} (ao) does not match the reference AO (corr {c:.2f})')
        out[ch] = st
    return dict(verdict='FAIL' if reasons else 'PASS', reasons=reasons, channels=out)


# ----------------------------------------------------------------------------------------------- D5 classes
def components(mask):
    try:
        import cv2
        n, lab = cv2.connectedComponents(mask.astype(np.uint8), connectivity=4)
        return lab
    except ImportError:                                           # pure numpy fallback (slow on big islands)
        lab = np.where(mask, np.arange(mask.size).reshape(mask.shape) + 1, 0); big = mask.size + 1
        while True:
            cur = np.where(mask, lab, big); new = cur.copy()
            for ax, sh in ((0, 1), (0, -1), (1, 1), (1, -1)):
                new = np.minimum(new, np.where(mask, np.roll(cur, sh, ax), big))
            new = np.where(mask, new, 0)
            if np.array_equal(new, lab):
                return lab
            lab = new


def class_pattern_check(image, classmap, classes, valid=None, min_period=16.0, window=64, min_cover=0.9,
                        max_flag_frac=0.15, flat_min_std=0.02, min_island_px=400, class_floor=None, skip=(),
                        signal='luma'):
    """Per class (texturing-qa.md 'Pattern period vs density' + 'Structure'): rhythm_check on the class texels
    (luma of a colour map; signal='slopes' for an encoded normal) -> FAIL when more than max_flag_frac of the
    windows carry a rhythm shorter than min_period texels; and FLAT islands: connected components of the class
    whose relative luma spread std/mean is below the class floor (a plain fill where structure is expected)."""
    valid = np.ones(classmap.shape, bool) if valid is None else valid
    lum = luma(image); out = {}; reasons = []
    for ci, name in enumerate(classes):
        if name in skip:
            continue
        mk = valid & (classmap == ci)
        if mk.sum() < min_island_px:
            continue
        r = rhythm_check(image, erode(mk, 1), window=window, min_cover=min_cover, min_period=min_period,
                         max_flag_frac=max_flag_frac, signal=signal)
        e = dict(px=int(mk.sum()), windows=r['windows'], short_period_windows=r['short_period_windows'],
                 two_rhythm_windows=r['two_rhythm_windows'], common_rhythms=r['common_rhythms'][:4])
        if any('shorter' in x for x in r['reasons']):
            reasons.append(f'{name}: rhythm < {min_period} texels in {r["short_period_windows"]}/{r["windows"]} windows')
            e['short_examples'] = [(x['y'], x['x'], x['short']) for x in r['examples'] if x['short']][:3]
        lab = components(mk).ravel(); sel = mk.ravel() & (lab > 0); l = lab[sel]; v = lum.ravel()[sel].astype(np.float64)
        cnt = np.bincount(l); s1 = np.bincount(l, v); s2 = np.bincount(l, v * v)
        floor = (class_floor or {}).get(name, flat_min_std); flat = []
        for i in np.nonzero(cnt >= min_island_px)[0]:
            mu = s1[i] / cnt[i]; sd = np.sqrt(max(s2[i] / cnt[i] - mu * mu, 0.0)); rs = sd / max(mu, 0.05)
            if rs < floor:
                ys, xs = np.divmod(np.nonzero(lab == i)[0], mk.shape[1])
                flat.append(dict(px=int(cnt[i]), rel_std=round(float(rs), 4),
                                 bbox=[int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())]))
        if flat:
            reasons.append(f'{name}: {len(flat)} flat islands, largest {max(flat, key=lambda f: f["px"])}')
            e['flat'] = sorted(flat, key=lambda f: -f['px'])[:5]
        out[name] = e
    return dict(verdict='FAIL' if reasons else 'PASS', reasons=reasons, classes=out)


# ----------------------------------------------------------------------------------------------- D6 eave alpha
def _eave_faces(plan, geo, page, classes):
    """eave faces of `classes` on `page` with role FRONT (vertical, facing out), UNDER (tilted down-out) or BACK
    (vertical, facing in); `out` = horizontal part of the nearest UNDER face's normal."""
    fs = {}
    for k, x in plan.items():
        if x.get('page') != page or x.get('material') not in classes or k not in geo:
            continue
        v = np.asarray(geo[k]['v'], float)
        fs[k] = dict(key=k, family=x['family'].split(':', 1)[-1], owner=bool(x.get('owner', True)),
                     uv=np.asarray(x['uv'], float), v=v, n=np.asarray(geo[k]['n'], float), c=v.mean(0))
    unders = [f for f in fs.values() if f['n'][2] < -0.2]
    for f in fs.values():
        if f['n'][2] > 0.2 or not unders:
            f['role'] = 'TOP'; continue
        u = f if f['n'][2] < -0.2 else min(unders, key=lambda u: np.linalg.norm(u['c'] - f['c']))
        h = u['n'].copy(); h[2] = 0; f['out'] = h / np.linalg.norm(h)
        f['role'] = 'UNDER' if f is u else ('FRONT' if f['n'] @ f['out'] > 0 else 'BACK')
    return fs


def _face_texels(f, size):
    """texel centres inside the face's UV polygon -> (rows, cols) top-down + world positions (barycentric)"""
    uv = f['uv'] * size
    x0, y0 = np.floor(uv.min(0)).astype(int); x1, y1 = np.ceil(uv.max(0)).astype(int) + 1
    xs, ys = np.meshgrid(np.arange(max(x0, 0), min(x1, size)) + 0.5, np.arange(max(y0, 0), min(y1, size)) + 0.5)
    pts = np.stack([xs.ravel(), ys.ravel()], -1); P = np.full((len(pts), 3), np.nan)
    for i in range(1, len(uv) - 1):
        a, b, c = uv[0], uv[i], uv[i + 1]; T = np.array([b - a, c - a]).T
        if abs(np.linalg.det(T)) < 1e-12:
            continue
        l1, l2 = np.linalg.solve(T, (pts - a).T); l0 = 1 - l1 - l2
        ins = (l0 >= 0) & (l1 >= 0) & (l2 >= 0) & np.isnan(P[:, 0])
        P[ins] = l0[ins, None] * f['v'][0] + l1[ins, None] * f['v'][i] + l2[ins, None] * f['v'][i + 1]
    ok = ~np.isnan(P[:, 0])
    return (size - 1 - np.floor(pts[ok, 1]).astype(int)), np.floor(pts[ok, 0]).astype(int), P[ok]


def _texels_per_unit(f, size):
    v = f['v']; area = sum(np.linalg.norm(np.cross(v[i] - v[0], v[i + 1] - v[0])) / 2 for i in range(1, len(v) - 1))
    return float(np.sqrt(abs(_shoelace(f['uv'] * size)) / max(area, 1e-12)))


def _bottom_edge(v, sv):
    """vertex indices of the lowest edge running ALONG the eave (s extent >= half the face's): not the two lowest
    vertices and not the lowest edge - on an upturned corner quad both pick its short vertical end edge"""
    n = len(v); ds = [abs(sv[(k + 1) % n] - sv[k]) for k in range(n)]
    i = min((k for k in range(n) if ds[k] >= 0.5 * max(ds)), key=lambda k: v[k, 2] + v[(k + 1) % n, 2])
    return [i, (i + 1) % n]


def _front_alpha(P, e, fronts, alpha, size):
    """alpha of the FRONT (owner or member) directly in front of each point P of BACK/UNDER face e, read through
    that FRONT's own UVs; 0 below the FRONT's bottom edge - beyond a FRONT's end (upturned corners) below that edge
    EXTRAPOLATED along the eave (nearest FRONT within 0.35 m); nan where nothing decides"""
    out = e['out']; ax = np.cross([0, 0, 1.0], out); ax /= np.linalg.norm(ax); ps = P @ ax
    res = np.full(len(P), np.nan); below = np.zeros(len(P), bool)
    ext_d = np.full(len(P), np.inf); ext_below = np.zeros(len(P), bool)
    for f in fronts:
        if f['out'] @ out < 0.9 or abs(f['c'][2] - e['c'][2]) > 0.45 or not -0.02 < (f['c'] - e['c']) @ out < 0.25:
            continue
        t = (f['n'] @ f['c'] - P @ f['n']) / (f['n'] @ out); Q = P + t[:, None] * out
        for i in range(1, len(f['v']) - 1):
            A, B, C = f['v'][0], f['v'][i], f['v'][i + 1]; e1, e2, w = B - A, C - A, Q - A
            d00, d01, d11 = e1 @ e1, e1 @ e2, e2 @ e2; dd = d00 * d11 - d01 * d01
            l1 = (d11 * (w @ e1) - d01 * (w @ e2)) / dd; l2 = (d00 * (w @ e2) - d01 * (w @ e1)) / dd
            ins = np.isnan(res) & (l1 >= -1e-4) & (l2 >= -1e-4) & (l1 + l2 <= 1 + 1e-4)
            if ins.any():
                uv = (f['uv'][0] + l1[ins, None] * (f['uv'][i] - f['uv'][0]) + l2[ins, None] * (f['uv'][i + 1] - f['uv'][0])) * size
                res[ins] = alpha[np.clip(size - 1 - np.floor(uv[:, 1]).astype(int), 0, size - 1), np.clip(np.floor(uv[:, 0]).astype(int), 0, size - 1)]
        sv = f['v'] @ ax; lo = _bottom_edge(f['v'], sv); (s0, s1), (z0, z1) = sv[lo], f['v'][lo, 2]
        zb = z0 + np.clip((ps - s0) / (s1 - s0 + 1e-12), 0, 1) * (z1 - z0)
        below |= (ps >= sv.min() - 1e-3) & (ps <= sv.max() + 1e-3) & (Q[:, 2] < zb + 1e-4)
        ds = np.maximum(sv.min() - ps, 0) + np.maximum(ps - sv.max(), 0); nearer = ds < ext_d
        ext_d[nearer] = ds[nearer]; ext_below[nearer] = (P[:, 2] < z0 + (ps - s0) / (s1 - s0 + 1e-12) * (z1 - z0) + 1e-4)[nearer]
    corner = np.isnan(res) & ~below & (ext_d > 0) & (ext_d < 0.35) & ext_below
    below |= corner
    res[np.isnan(res) & below] = 0.0
    return res, below


def _first_crossing(z, val, thr):
    """lowest z where val reaches thr scanning upward (linear between the two texels); nan if never"""
    o = np.argsort(z); z, val = z[o], val[o]; hit = np.nonzero(val >= thr)[0]
    if not len(hit):
        return np.nan
    i = hit[0]
    if i == 0:
        return z[0]
    return z[i - 1] + (thr - val[i - 1]) / max(val[i] - val[i - 1], 1e-9) * (z[i] - z[i - 1])


def eave_alpha_check(plan, geo, alpha, normal, page='P1024', size=None, classes=('EAVE_CUTOUT',), front_cut=(0.15, 0.35),
                     under_cut=0.90, max_mismatch=0.05, max_edge_dist=1.0, relief_tau=0.35, min_column_texels=6):
    """Eave cutout regression gate (owner 2026-09-29: 'losing that alpha was BASICALLY A REGRESSION'). Every eave
    chart through the ACTIVE plan, members included (each face samples the maps through its own UVs, so a member
    reads its owner's texels):
      FRONT (end-tile face) cut = alpha < 0.5 within front_cut (the tiles' scalloped silhouette, not 0 and not all);
      UNDER cut >= under_cut over the part that hangs below its FRONT's bottom edge;
      every BACK/UNDER texel directly behind a FRONT (owner or member) matches that FRONT's alpha - an opaque lip
      behind a cut FRONT texel is a mismatch (> max_mismatch of the face -> FAIL);
      the alpha 0.5 contour follows the baked tile outline: per 1-texel column of a FRONT face, the lowest point where
      the baked normal's slope |n_xy| reaches relief_tau (disc bottoms, pan-tile arcs) vs the lowest point where
      alpha reaches 0.5; median distance per chart <= max_edge_dist texels.
    FAIL names the charts."""
    size = size or alpha.shape[0]
    A = alpha[..., 0] if alpha.ndim == 3 else alpha
    dev = np.hypot(*(slopes(normal)[..., k] for k in (0, 1)))
    fs = _eave_faces(plan, geo, page, set(classes)); fronts = [f for f in fs.values() if f['role'] == 'FRONT']
    ch = defaultdict(lambda: dict(texels=0, cut=0, hang=0, hang_cut=0, checked=0, mismatch=0, dist=[]))
    bad_faces = []
    for f in fs.values():
        if f['role'] == 'TOP':
            continue
        r, c, P = _face_texels(f, size)
        if not len(P):
            continue
        a = A[r, c]; e = ch[(f['family'], f['role'])]; e['texels'] += len(a); e['cut'] += int((a < 0.5).sum())
        if f['role'] == 'FRONT':
            ax = np.cross([0, 0, 1.0], f['out']); ax /= np.linalg.norm(ax); tpu = _texels_per_unit(f, size)
            s = P @ ax; b = np.floor((s - s.min()) * tpu).astype(int); d = dev[r, c]
            for k in np.unique(b):
                m = b == k
                if m.sum() < min_column_texels:
                    continue
                zt = _first_crossing(P[m, 2], d[m], relief_tau)
                if np.isnan(zt):
                    continue
                za = _first_crossing(P[m, 2], a[m], 0.5)
                za = P[m, 2].max() if np.isnan(za) else za
                e['dist'].append(abs(za - zt) * tpu)
        else:
            fa, below = _front_alpha(P, f, fronts, A, size)
            ok = ~np.isnan(fa); mm = ok & (a >= 0.5) & (fa < 0.5)
            e['checked'] += int(ok.sum()); e['mismatch'] += int(mm.sum())
            if f['role'] == 'UNDER':
                e['hang'] += int(below.sum()); e['hang_cut'] += int((below & (a < 0.5)).sum())
            if ok.sum() and mm.sum() / ok.sum() > max_mismatch:
                bad_faces.append((f['key'], f['family'], f['role'], round(float(mm.sum() / ok.sum()), 3)))
    charts, reasons = {}, []
    for (fam, role), e in sorted(ch.items()):
        cut = e['cut'] / max(e['texels'], 1); row = dict(texels=e['texels'], cut=round(cut, 3)); why = []
        if role == 'FRONT':
            med = float(np.median(e['dist'])) if e['dist'] else float('nan')
            row.update(edge_columns=len(e['dist']), edge_median_texels=round(med, 2))
            if not front_cut[0] <= cut <= front_cut[1]:
                why.append(f'FRONT cut {cut:.2f} outside {front_cut[0]:.2f}-{front_cut[1]:.2f}')
            if not e['dist'] or med > max_edge_dist:
                why.append(f'alpha edge {med:.2f} texels from the baked tile outline (max {max_edge_dist})')
        else:
            mis = e['mismatch'] / max(e['checked'], 1); row.update(checked=e['checked'], mismatch=round(mis, 3))
            if mis > max_mismatch:
                why.append(f'{role} opaque behind a cut FRONT on {mis:.1%} of {e["checked"]} texels')
            if role == 'UNDER':
                hc = e['hang_cut'] / max(e['hang'], 1); row.update(hanging=e['hang'], hanging_cut=round(hc, 3))
                if e['hang'] and hc < under_cut:
                    why.append(f'UNDER hanging part cut {hc:.2f} < {under_cut:.2f}')
        row['verdict'] = 'FAIL' if why else 'PASS'; charts[f'{fam} | {role}'] = row
        reasons += [f'{fam} | {role}: {w}' for w in why]
    return dict(verdict='FAIL' if reasons else 'PASS', reasons=reasons, charts=charts,
                mismatched_faces=sorted(bad_faces)[:40], faces=len(fs))


# ----------------------------------------------------------------------------------------------- D7 class mismatch
def read_palette_classmap(spec, classes, tol=0.05):
    """ClassID image drawn in a palette ({CLASS: [r, g, b] sRGB 0..1 or '#rrggbb'}) -> class index per texel, top-down;
    -1 = black (no class baked), -2 = no palette colour within tol (rms)."""
    a = read_map(spec['path'])[..., :3]; pal = spec['palette']
    hexrgb = lambda h: [int(h.lstrip('#')[i:i + 2], 16) / 255 for i in (0, 2, 4)]  # noqa: E731
    cols = np.array([hexrgb(pal[c]) if isinstance(pal[c], str) else pal[c] for c in classes], np.float32)
    d = np.full(a.shape[:2], np.inf, np.float32); idx = np.full(a.shape[:2], -2, int)
    for i, c in enumerate(cols):
        di = ((a - c) ** 2).mean(-1); idx[di < d] = i; d = np.minimum(d, di)
    idx[d > tol * tol] = -2; idx[a.max(-1) < 0.02] = -1
    return idx


def _poly_texels(uv, size):
    """(rows top-down, cols) of the texel centres inside a UV polygon (even-odd rule)"""
    t = np.array([[u * size, (1 - v) * size] for u, v in uv], float)
    x0, y0 = np.maximum(np.floor(t.min(0)).astype(int), 0); x1, y1 = np.minimum(np.ceil(t.max(0)).astype(int) + 1, size)
    ys, xs = np.mgrid[y0:max(y1, y0), x0:max(x1, x0)]; px, py = xs.ravel() + 0.5, ys.ravel() + 0.5
    ins = np.zeros(len(px), bool)
    for i in range(len(t)):
        (ax, ay), (bx, by) = t[i], t[(i + 1) % len(t)]
        cr = (ay > py) != (by > py)
        ins ^= cr & (px < ax + (py - ay) * (bx - ax) / np.where(by == ay, 1e-30, by - ay))
    return ys.ravel()[ins], xs.ravel()[ins]


def class_mismatch_check(plan, classmap, classes, page, size, expected=None, equivalent=(), min_texels=8,
                         max_mismatch=0.5, skip=('HIDDEN',)):
    """Every face on `page` (owners AND members: each samples the maps through its own UVs): its class = expected[key]
    (an independent per-face truth, e.g. the authored material) or else the plan material; mismatch = share of its
    baked texels (classmap >= 0) whose class is not that class (or an `equivalent` one, e.g. WOOD ~ GABLE_DECOR).
    CLASS_MISMATCH when mismatch > max_mismatch; NO_CLASS when more than half its texels carry no class. Faces under
    min_texels texel centres are counted as tiny, never flagged. FAIL names the faces (key, class, read class)."""
    eq = {c: {c} for c in classes}
    for grp in equivalent:
        for c in grp:
            eq.setdefault(c, {c}).update(grp)
    expected = expected or {}; out, tiny, checked = {}, [], 0
    for k, e in plan.items():
        if e.get('page') != page:
            continue
        cls = expected.get(k) or e.get('material')
        if cls in skip or cls not in classes:
            continue
        r, c = _poly_texels(e['uv'], size)
        if len(r) < min_texels:
            tiny.append(k); continue
        checked += 1; read = classmap[r, c]; ok = read >= 0; n = int(ok.sum())
        if n < 0.5 * len(read):
            out[k] = dict(cls=cls, flags=['NO_CLASS'], texels=len(read), baked=n); continue
        want = [classes.index(x) for x in eq[cls] if x in classes]
        mis = float(1 - np.isin(read[ok], want).mean())
        if mis > max_mismatch:
            cnt = Counter(read[ok].tolist()); dom = classes[cnt.most_common(1)[0][0]]
            out[k] = dict(cls=cls, source='expected' if k in expected else 'plan', plan_material=e.get('material'),
                          reads=dom, mismatch=round(mis, 3), texels=len(read), owner=bool(e.get('owner', True)),
                          family=e.get('family'), shares={classes[i]: round(v / n, 3) for i, v in cnt.most_common(3)},
                          flags=['CLASS_MISMATCH'])
    pairs = Counter(f'{v["cls"]}->{v.get("reads", "none")}' for v in out.values())
    reasons = [f'{n} faces {p}' for p, n in pairs.most_common()]
    return dict(verdict='FAIL' if out else 'PASS', reasons=reasons, checked=checked, flagged=len(out), tiny=len(tiny),
                by_pair=dict(pairs), flagged_faces=sorted(out), faces=out)


# ----------------------------------------------------------------------------------------------- D8 relief gate
# Owner 2026-09-29 ~12:30: "the wooden wall material normals (planks not on the model!!! ... This regression should NOT
# pass the next time!" + "window frames around windows have NO normal map" + "the sign ... the paper should also have
# normal map". Measured on HEAD 10a73d321b1f7a13 (S18i, P2048): the plank seams of the 14 WINDOW_ASSEMBLY quads read
# line response 0.07-0.13 (grain between them 0.02-0.03) over a Normal that is exactly (0, 0, 1); plaster walls read
# 0.006 (p50) / 0.028 (p95); the baked lattice slope gradient 0.1-0.3, plaster noise 0.02. No earlier gate compared
# albedo structure to relief: the planks were never in the Normal, and a relief-removal job (PLAIN_WALLS) exposed it.
def _box1(x, r, axis):
    """mean over 2r+1 texels along one axis, edge-clamped"""
    if r <= 0:
        return x
    pad = [(0, 0)] * x.ndim; pad[axis] = (r + 1, r)
    c = np.cumsum(np.pad(x.astype(np.float64), pad, mode='edge'), axis=axis)
    n = x.shape[axis]; k = 2 * r + 1
    hi = np.take(c, np.arange(k, k + n), axis=axis); lo = np.take(c, np.arange(0, n), axis=axis)
    return ((hi - lo) / k).astype(np.float32)


def line_response_axes(L, half=4, step=2):
    """oriented structure of a luma image per UV axis: [lines running along x, lines running along y]; per texel
    max(|edge| (central difference), |line| (texel minus the mean of its neighbours `step` away: a seam, groove or
    member line)) across the line, averaged over 2*half+1 texels ALONG it - a coherent seam survives, grain does not."""
    L = np.asarray(L, np.float32); out = []
    for ax in (0, 1):
        sh = lambda d: np.roll(L, d, ax)  # noqa: E731
        e = (sh(-1) - sh(1)) / 2; v = L - (sh(step) + sh(-step)) / 2
        along = 1 - ax
        out.append(np.maximum(np.abs(_box1(e, half, along)), np.abs(_box1(v, half, along))))
    return out


def line_response(L, half=4, step=2):
    a, b = line_response_axes(L, half, step)
    return np.maximum(a, b)


def run_length(mask, axis):
    """per True texel: the length of its run of consecutive True texels along `axis`"""
    m = np.moveaxis(np.asarray(mask, bool), axis, -1); n = m.shape[-1]
    idx = np.arange(n)
    start = np.where(m & ~np.concatenate([np.zeros(m.shape[:-1] + (1,), bool), m[..., :-1]], -1), idx, -1)
    start = np.maximum.accumulate(start, axis=-1)
    end = np.where(m & ~np.concatenate([m[..., 1:], np.zeros(m.shape[:-1] + (1,), bool)], -1), idx, n)
    end = np.flip(np.minimum.accumulate(np.flip(end, -1), axis=-1), -1)
    return np.moveaxis(np.where(m, end - start + 1, 0), -1, axis)


def line_structure(L, thr, half=4, min_run=10):
    """texels on an albedo LINE: oriented response >= thr on a run of >= min_run texels along that line (seams, member
    edges, sheet outlines); mottled stone and grain blotches are shorter (HEAD: granite speckle 3-8 texels)"""
    out = np.zeros(np.shape(L), bool)
    for ax, r in enumerate(line_response_axes(L, half)):
        m = r >= thr
        out |= m & (run_length(m, 1 - ax) >= min_run)
    return out


def relief_energy(normal):
    """per texel: gradient magnitude of the tangent slopes (nx, ny) = the relief a normal map draws (0 on a bake of a
    flat face; grooves, lips and bevels light it up; a constant tilt does not)"""
    s = slopes(normal); out = np.zeros(s.shape[:2], np.float32)
    for k in (0, 1):
        gy, gx = np.gradient(s[..., k].astype(np.float32)); out += np.hypot(gx, gy)
    return out


def _interior(labels, r):
    """texels whose (2r+1)^2 neighbourhood lies in one face (chart borders and gutters never read as structure)"""
    ok = labels >= 0
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            if dy or dx:
                ok &= np.roll(np.roll(labels, dy, 0), dx, 1) == labels
    return ok


def _dilate(mask, r):
    return box_blur(mask.astype(np.float32), r) > 1e-6 if r > 0 else mask


def _tile_faces(lab, keys, sel):
    ids, cnt = np.unique(lab[sel & (lab >= 0)], return_counts=True)
    return {keys[i]: int(c) for i, c in zip(ids, cnt)} if keys is not None else {int(i): int(c) for i, c in zip(ids, cnt)}


def relief_lines(normal, half=4):
    """oriented relief of a normal map: line_response of each tangent slope component (grooves, lips, member edges);
    grain noise averages out along the line (measured: plank-board noise 0.005-0.02, board grooves 0.05-0.4, window
    lattice 0.1-0.9)"""
    s = slopes(normal)
    return np.maximum(line_response(s[..., 0], half), line_response(s[..., 1], half))


def relief_missing_check(basecolor, normal, labels=None, keys=None, valid=None, tile=16, line_half=4, struct_thr=0.07,
                         min_run=10, relief_thr=0.03, support_r=2, interior_r=2, min_struct=12, min_unsupported=0.6,
                         min_face_texels=150, waive_faces=(), max_list=200):
    """relief_missing: albedo structure (seams, member edges, sheet outlines: line_response >= struct_thr) with no
    oriented relief within support_r texels (relief_lines < relief_thr there) = a drawn seam over a flat normal. Only
    LINES of the normal support: the grain noise of a plank board runs under a pasted paper sheet and must not count
    as the sheet's relief (the notice board, HEAD 2026-09-29).
    Per tile x tile block: FLAG when >= min_struct unsupported structure texels AND they are >= min_unsupported of the
    block's structure texels. labels (HxW int, owner face index per texel, -1 = none) + keys (index -> face key) name
    the faces; only face-interior texels are read (interior_r). A face is FLAGGED when its unsupported texels in flagged
    tiles reach min_face_texels; waive_faces (owner decisions) are reported, never failed.
    Flat-by-design areas pass by construction: no structure (plain plaster, paper cells) or relief present."""
    L = luma(basecolor[..., :3]) if basecolor.ndim == 3 else basecolor
    H, W = L.shape
    lab = np.zeros((H, W), int) if labels is None else np.asarray(labels)
    ok = _interior(lab, interior_r) & (lab >= 0)
    if valid is not None:
        ok &= valid
    S = line_structure(L, struct_thr, line_half, min_run) & ok
    rel = relief_lines(normal, line_half) >= relief_thr
    rel &= lab >= 0                                          # gutters carry no relief of the face
    U = S & ~_dilate(rel, support_r)
    out = _structure_gate(S, U, lab, keys, tile, min_struct, min_unsupported, min_face_texels, waive_faces, max_list,
                          'carry albedo structure over a flat normal')
    out['params'] = dict(tile=tile, struct_thr=struct_thr, min_run=min_run, relief_thr=relief_thr, support_r=support_r,
                         min_struct=min_struct, min_unsupported=min_unsupported, min_face_texels=min_face_texels)
    return out


def _structure_gate(S, U, lab, keys, tile, min_struct, min_unsupported, min_face_texels, waive_faces, max_list, what):
    """shared by D8/D9: S = albedo structure texels, U = the unsupported ones. Per tile x tile block FLAG when >=
    min_struct unsupported AND >= min_unsupported of the block's structure; a face fails at >= min_face_texels."""
    H, W = S.shape
    ny, nx = -(-H // tile), -(-W // tile)
    tiles, per_face = [], defaultdict(lambda: dict(unsupported=0, tiles=0, boxes=[]))
    for ty in range(ny):
        for tx in range(nx):
            sl = np.s_[ty * tile:(ty + 1) * tile, tx * tile:(tx + 1) * tile]
            ns, nu = int(S[sl].sum()), int(U[sl].sum())
            if nu < min_struct or nu < min_unsupported * ns:
                continue
            box = [tx * tile, ty * tile, min((tx + 1) * tile, W), min((ty + 1) * tile, H)]
            fc = _tile_faces(lab[sl], keys, U[sl])
            tiles.append(dict(box=box, structure=ns, unsupported=nu, faces=fc))
            for k, c in fc.items():
                e = per_face[k]; e['unsupported'] += c; e['tiles'] += 1
                if len(e['boxes']) < 12:
                    e['boxes'].append(box)
    waive = set(waive_faces)
    flagged = {k: v for k, v in per_face.items() if v['unsupported'] >= min_face_texels}
    failing = sorted(k for k in flagged if k not in waive)
    waived = sorted(k for k in flagged if k in waive)
    reasons = [f'{len(failing)} faces {what} ({sum(flagged[k]["unsupported"] for k in failing)}'
               f' unsupported structure texels in {len({tuple(b) for k in failing for b in flagged[k]["boxes"]})}+ tiles)'] if failing else []
    return dict(verdict='FAIL' if failing else 'PASS', reasons=reasons, structure_texels=int(S.sum()),
                unsupported_texels=int(U.sum()), flagged_tiles=len(tiles), tiles=tiles[:max_list],
                flagged_faces=failing, waived_faces=waived, faces={k: flagged[k] for k in sorted(flagged)},
                _unsupported_mask=U)


# ----------------------------------------------------------------------------------------------- D9 masks gate
# Owner 2026-10-09: "the doors have no normals and masks maps. Can you add it and also add test to catch such failures".
# Measured on the Korean castle C7 R0 page (line response of the albedo lines' Masks, max over R/G/B, p50): the GPT door
# pasted over a role-constant roughness, no metallic and no cavity AO 0.016 (3 % of its lines >= 0.04); every other sheet
# (stone, brick, trims, the TC gable) 0.08-0.19 (98-100 % >= 0.04): their roughness follows the joints.
# Face floor: plank boards whose Masks carry grain but no seam lines were flagged per tile; the door's whole-face Masks
# line p90 is 0.012, every textured face >= 0.065 - a face FAILS only when its Masks are flat (p90 < face_p90 = 0.04).
def masks_lines(masks, half=4):
    """oriented structure of a packed Masks map: line_response of each of R, G, B (AO, roughness, metallic), max."""
    m = np.asarray(masks, np.float32)
    return np.maximum.reduce([line_response(m[..., k], half) for k in range(min(3, m.shape[-1]))])


def masks_missing_check(basecolor, masks, labels=None, keys=None, valid=None, tile=16, line_half=4, struct_thr=0.07,
                        min_run=10, masks_thr=0.04, support_r=2, interior_r=2, min_struct=12, min_unsupported=0.6,
                        min_face_texels=150, face_p90=0.04, waive_faces=(), max_list=200):
    """masks_missing: albedo structure (seams, bands, member edges) with no line in ANY Masks channel within support_r
    texels = a painting pasted over flat masks (no cavity AO, roughness or metallic follows what the colour shows).
    Same blocks, face naming and waivers as relief_missing_check."""
    L = luma(basecolor[..., :3]) if basecolor.ndim == 3 else basecolor
    H, W = L.shape
    lab = np.zeros((H, W), int) if labels is None else np.asarray(labels)
    ok = _interior(lab, interior_r) & (lab >= 0)
    if valid is not None:
        ok &= valid
    S = line_structure(L, struct_thr, line_half, min_run) & ok
    ml = masks_lines(masks, line_half); sup = (ml >= masks_thr) & (lab >= 0)
    U = S & ~_dilate(sup, support_r)
    out = _structure_gate(S, U, lab, keys, tile, min_struct, min_unsupported, min_face_texels, waive_faces, max_list,
                          'carry albedo structure over flat Masks (no AO, roughness or metallic lines)')
    name = (lambda i: keys[i]) if keys is not None else int
    p90 = {name(i): float(np.quantile(ml[ok & (lab == i)], .9)) for i in np.unique(lab[ok & (lab >= 0)])}
    textured = sorted(k for k in out['flagged_faces'] if p90.get(k, 0.) >= face_p90)    # Masks present, only off the seams
    out['flagged_faces'] = [k for k in out['flagged_faces'] if k not in textured]; out['textured_faces'] = textured
    out['face_masks_p90'] = {k: round(p90.get(k, 0.), 3) for k in out['faces']}
    if not out['flagged_faces']:
        out['verdict'], out['reasons'] = 'PASS', []
    else:
        out['reasons'] = [f'{len(out["flagged_faces"])} faces carry albedo structure over flat Masks (whole-face Masks line p90 < '
                          f'{face_p90}: no AO, roughness or metallic structure) - {out["flagged_faces"][:6]}']
    out['params'] = dict(tile=tile, struct_thr=struct_thr, min_run=min_run, masks_thr=masks_thr, support_r=support_r,
                         min_struct=min_struct, min_unsupported=min_unsupported, min_face_texels=min_face_texels, face_p90=face_p90)
    return out


def relief_drop_check(candidate_normal, base_normal, labels=None, keys=None, declared=None, valid=None, tile=16,
                      min_base=0.03, max_drop=0.5, texel_drop=0.02, min_declared=0.9, min_face_texels=24, max_list=200):
    """relief_drop: tiles whose relief energy (RMS of relief_energy over the block's face texels) falls from >= min_base
    in the base to <= (1 - max_drop) x base in the candidate are relief REMOVALS; each must lie inside `declared` (HxW
    bool, the job's declared relief-removal scope): >= min_declared of the block's dropped texels (per-texel energy
    fall > texel_drop) in scope, else UNDECLARED -> FAIL, naming faces and blocks."""
    lab = np.zeros(candidate_normal.shape[:2], int) if labels is None else np.asarray(labels)
    ok = lab >= 0
    if valid is not None:
        ok &= valid
    eb, ec = relief_energy(base_normal), relief_energy(candidate_normal)
    drop = ((box_blur(eb, 1) - box_blur(ec, 1)) > texel_drop) & ok
    dec = np.zeros_like(ok) if declared is None else np.asarray(declared, bool)
    H, W = ok.shape; ny, nx = -(-H // tile), -(-W // tile)
    und, decl = [], []; per_face = defaultdict(lambda: dict(dropped=0, tiles=0, boxes=[]))
    for ty in range(ny):
        for tx in range(nx):
            sl = np.s_[ty * tile:(ty + 1) * tile, tx * tile:(tx + 1) * tile]
            m = ok[sl]
            if m.sum() < 16:
                continue
            b = float(np.sqrt((eb[sl][m] ** 2).mean())); c = float(np.sqrt((ec[sl][m] ** 2).mean()))
            if b < min_base or c > (1 - max_drop) * b:
                continue
            d = drop[sl]; nd = int(d.sum()); inside = int((d & dec[sl]).sum())
            box = [tx * tile, ty * tile, min((tx + 1) * tile, W), min((ty + 1) * tile, H)]
            row = dict(box=box, base=round(b, 4), candidate=round(c, 4), dropped=nd, declared=inside)
            if nd and inside >= min_declared * nd:
                decl.append(row); continue
            row['faces'] = _tile_faces(lab[sl], keys, d & ~dec[sl]); und.append(row)
            for k, n in row['faces'].items():
                e = per_face[k]; e['dropped'] += n; e['tiles'] += 1
                if len(e['boxes']) < 12:
                    e['boxes'].append(box)
    faces = {k: v for k, v in per_face.items() if v['dropped'] >= min_face_texels}
    reasons = [f'undeclared relief removal on {len(faces)} faces ({len(und)} tiles; relief RMS fell > {max_drop:.0%})'] if faces else []
    return dict(verdict='FAIL' if faces else 'PASS', reasons=reasons, undeclared_tiles=und[:max_list],
                declared_tiles=len(decl), flagged_faces=sorted(faces), faces={k: faces[k] for k in sorted(faces)},
                params=dict(tile=tile, min_base=min_base, max_drop=max_drop, min_declared=min_declared))


# ----------------------------------------------------------------------------------------------- CLI
def run_check(c):
    t = c['type']
    if t == 'rhythm':
        img = read_map(c['normal']); m = read_mask(c.get('mask'), img.shape)
        kw = {k: c[k] for k in ('window', 'step', 'min_cover', 'min_period', 'max_flag_frac', 'signal', 'fail_short',
                                'min_windows') if k in c}
        return rhythm_check(img, m, **kw)
    if t == 'stacked_normal':
        f = read_map(c['final']); m = read_mask(c.get('mask'), f.shape)
        if c.get('classmap'):
            cm = read_classmap(c['classmap']); m = m & np.isin(cm, [c['classes'].index(x) for x in c['bake_only']])
        return stacked_normal_check(f, read_map(c['bake']), m, c.get('max_added', 0.35))
    if t == 'uv_registration':
        plan = json.load(open(c['plan'], encoding='utf-8-sig'))['faces']; geo = load_geometry(c['geometry'], c['sources'])
        out = {}
        for page, size in c['pages'].items():
            r = uv_registration_check(plan, geo, page, size, directional=c.get('directional', ()),
                                      min_share=c.get('min_share', 0.9), max_stretch=c.get('max_stretch', 1.4),
                                      fold_deg=c.get('fold_deg', 15.0))
            r.pop('faces'); out[page] = r
        bad = [f'{p}: {x}' for p, r in out.items() for x in r['reasons']]
        return dict(verdict='FAIL' if bad else 'PASS', reasons=bad, pages=out)
    if t == 'mask_offset':
        mk = read_map(c['mask']); ref = read_map(c['reference']); v = read_mask(c.get('valid'), mk.shape)
        return mask_offset_check(mk[..., 0] if mk.shape[-1] == 1 else luma(mk), ref, v, c.get('reference_kind', 'normal_edges'),
                                 c.get('search', 6), c.get('max_offset', 2), c.get('min_corr', 0.1))
    if t == 'mask_layout':
        mk = read_map(c['mask']); v = read_mask(c['valid'], mk.shape)
        return mask_layout_check(mk, v, c.get('max_outside', 0.02))
    if t == 'channel_packing':
        mk = read_map(c['masks']); cm = read_classmap(c['classmap']); v = read_mask(c.get('valid'), mk.shape)
        return channel_packing_check(mk, cm, c['classes'], v, c.get('channels'), c.get('metal_classes', ('METAL',)))
    if t == 'class_pattern':
        img = read_map(c['image']); cm = read_classmap(c['classmap']); v = read_mask(c.get('valid'), img.shape)
        kw = {k: c[k] for k in ('min_period', 'window', 'max_flag_frac', 'flat_min_std', 'min_island_px', 'class_floor',
                                'skip', 'signal') if k in c}
        return class_pattern_check(img, cm, c['classes'], v, **kw)
    if t == 'eave_alpha':
        plan = json.load(open(c['plan'], encoding='utf-8-sig'))['faces']; geo = load_geometry(c['geometry'], c['sources'])
        kw = {k: c[k] for k in ('classes', 'front_cut', 'under_cut', 'max_mismatch', 'max_edge_dist', 'relief_tau') if k in c}
        return eave_alpha_check(plan, geo, read_map(c['alpha']), read_map(c['normal']), c.get('page', 'P1024'), c.get('size'), **kw)
    if t == 'class_mismatch':
        plan = json.load(open(c['plan'], encoding='utf-8-sig'))['faces']; exp = c.get('expected') or {}
        exp = json.load(open(exp, encoding='utf-8-sig')) if isinstance(exp, str) else exp
        kw = {k: c[k] for k in ('equivalent', 'min_texels', 'max_mismatch', 'skip') if k in c}; out = {}
        for page, size in c['pages'].items():
            spec = dict(c['classmap'], path=c['classmap']['path'].format(page=page))
            cm = read_palette_classmap(spec, c['classes']) if 'palette' in spec else read_classmap(spec)
            out[page] = class_mismatch_check(plan, cm, c['classes'], page, size, exp, **kw)
        bad = [f'{p}: {x}' for p, r in out.items() for x in r['reasons']]
        return dict(verdict='FAIL' if bad else 'PASS', reasons=bad, pages=out)
    if t == 'relief_missing':
        bc = read_map(c['basecolor']); v = read_mask(c.get('valid'), bc.shape)
        kw = {k: c[k] for k in ('tile', 'struct_thr', 'min_run', 'relief_thr', 'support_r', 'min_struct', 'min_unsupported',
                                'min_face_texels') if k in c}
        r = relief_missing_check(bc, read_map(c['normal']), valid=v, **kw); r.pop('_unsupported_mask'); return r
    if t == 'masks_missing':
        bc = read_map(c['basecolor']); v = read_mask(c.get('valid'), bc.shape)
        kw = {k: c[k] for k in ('tile', 'struct_thr', 'min_run', 'masks_thr', 'support_r', 'min_struct', 'min_unsupported',
                                'min_face_texels', 'face_p90') if k in c}
        r = masks_missing_check(bc, read_map(c['masks']), valid=v, **kw); r.pop('_unsupported_mask'); return r
    if t == 'relief_drop':
        n = read_map(c['normal']); v = read_mask(c.get('valid'), n.shape)
        dec = read_mask(c['declared'], n.shape) if c.get('declared') else None
        kw = {k: c[k] for k in ('tile', 'min_base', 'max_drop', 'min_declared', 'min_face_texels') if k in c}
        return relief_drop_check(n, read_map(c['base']), declared=dec, valid=v, **kw)
    raise ValueError(f'unknown check type {t}')


def main(cfg_path):
    cfg = json.load(open(cfg_path, encoding='utf-8-sig'))
    exrs = [v for c in cfg['checks'] for v in c.values() if isinstance(v, str) and v.lower().endswith('.exr')]
    exrs += [v['path'] for c in cfg['checks'] for v in c.values() if isinstance(v, dict) and str(v.get('path', '')).lower().endswith('.exr')]
    prefetch_exr(exrs)
    report = {'checks': {}, 'fail': []}
    for i, c in enumerate(cfg['checks']):
        cid = c.get('id', f'{c["type"]}_{i}'); r = run_check(c); report['checks'][cid] = r
        print(f'{r["verdict"]:4} {cid}: {"; ".join(r.get("reasons", [])) or "ok"}', flush=True)
        if r['verdict'] == 'FAIL':
            report['fail'].append(cid)
    if cfg.get('out'):
        Path(cfg['out']).write_text(json.dumps(report, indent=1, default=str))
    print('QA_DETECTORS', 'FAIL' if report['fail'] else 'PASS', report['fail'])
    return 3 if report['fail'] else 0


if __name__ == '__main__':
    argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else sys.argv[1:]
    if argv and argv[0] == '--convert-exr':
        _blender_convert(argv[1])
    elif argv:
        sys.exit(main(argv[0]))
    else:
        print(__doc__)
