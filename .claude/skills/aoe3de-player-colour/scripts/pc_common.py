"""Shared helpers of the aoe3de-player-colour skill: colour math, the game's player-colour formula, image IO, the
keep/lighten decision under a Details mask, and the small image operators (Otsu, components, dilation).

Plain Python + NumPy + Pillow. Images are handled in FILE order (row 0 = top of the PNG); UV v is up, so a UV point
maps to (x, y) = (u * size, (1 - v) * size).

Engine formula (AoE3 DE materialdefault.hlsl base pass, disassembled 2026-09-29):
    albedo_lin = BaseColor_lin * lerp(1, PlayerColour_lin, Details.R)
BaseColor is sRGB, Details is linear (no srgb flag) and only its R channel is read.
"""
import hashlib
from collections import deque
from pathlib import Path

import numpy as np

# Data/playercolors.xml (vanilla), color1, sRGB 0-255
PLAYER_COLORS = {1: (45, 45, 245), 2: (210, 40, 40), 3: (224, 224, 30), 4: (145, 15, 243), 5: (42, 212, 58),
                 6: (234, 135, 0), 7: (28, 194, 219), 8: (235, 97, 235)}
PLAYER_NAMES = {'blue': 1, 'red': 2, 'yellow': 3, 'purple': 4, 'green': 5, 'orange': 6, 'cyan': 7, 'pink': 8}

# Decision rule (owner 2026-09-29: "Only light objects like sails / white walls don't need basecolor transform beneath
# player color override"). Calibrated on the Korean TC: cream walls = KEEP, gold gable cells = LIGHTEN
# (references/aop-korean-tc-evidence.md). Both must hold for KEEP:
LIGHT_LUMA_MIN = 200.0    # mean Rec.709 luma of the 8-bit sRGB BaseColor under the full mask
LIGHT_CHROMA_MAX = 20.0   # mean CIE Lab chroma C* of the same texels
FULL_R = 250              # Details.R (8 bit) counted as "under the full mask" for the statistics

LUMA709 = np.array([0.2126, 0.7152, 0.0722])
N4 = ((1, 0), (-1, 0), (0, 1), (0, -1))


# ------------------------------------------------------------------------------------------------------ colour math
def s2l(a):
    """sRGB (0-255, any shape) -> linear 0-1 float64"""
    a = np.asarray(a, np.float64) / 255.0
    return np.where(a <= 0.04045, a / 12.92, ((a + 0.055) / 1.055) ** 2.4)


def l2s(x):
    """linear 0-1 -> sRGB uint8"""
    x = np.clip(np.asarray(x, np.float64), 0, 1)
    return np.rint(255 * np.where(x <= 0.0031308, x * 12.92, 1.055 * x ** (1 / 2.4) - 0.055)).astype(np.uint8)


def lab(lin):
    """CIE Lab (D65) of linear sRGB [..., 3]"""
    M = np.array([[0.4124, 0.3576, 0.1805], [0.2126, 0.7152, 0.0722], [0.0193, 0.1192, 0.9505]])
    xyz = np.maximum(lin, 0) @ M.T / np.array([0.95047, 1.0, 1.08883])
    f = np.where(xyz > 216 / 24389, np.cbrt(xyz), (24389 / 27 * xyz + 16) / 116)
    return np.stack([116 * f[..., 1] - 16, 500 * (f[..., 0] - f[..., 1]), 200 * (f[..., 1] - f[..., 2])], -1)


def hue_chroma(lin):
    """(Lab hue in degrees -180..180, Lab chroma C*) of linear sRGB"""
    L = lab(lin)
    return np.degrees(np.arctan2(L[..., 2], L[..., 1])), np.hypot(L[..., 1], L[..., 2])


def player_lin(pc):
    """player colour given as 1..8, a name ('blue') or an sRGB triple -> linear RGB"""
    if isinstance(pc, str):
        pc = PLAYER_NAMES[pc.lower()] if not pc.isdigit() else int(pc)
    if isinstance(pc, (int, np.integer)):
        pc = PLAYER_COLORS[int(pc)]
    return s2l(np.asarray(pc, np.float64))


def ingame_albedo(bc8, r, pc):
    """the game's base-pass albedo as sRGB uint8: BaseColor_lin * lerp(1, PC_lin, R); r = Details.R in 0..1"""
    w = np.asarray(r, np.float64)[..., None]
    return l2s(s2l(bc8) * (1 - w + w * player_lin(pc)))


# --------------------------------------------------------------------------------------------------------- image io
def read_rgb8(p):
    from PIL import Image
    return np.asarray(Image.open(p).convert('RGB')).copy()


def write_rgb8(p, a):
    from PIL import Image
    Image.fromarray(np.ascontiguousarray(a.astype(np.uint8)), 'RGB').save(p)


def read_details_r(p):
    """Details.R as float 0..1 (G, B ignored, as the default shaders do)"""
    return read_rgb8(p)[..., 0].astype(np.float64) / 255.0


def write_details(p, r):
    """(R, 0, 0) 8-bit linear PNG = the vanilla R-only Details layout"""
    a = np.zeros(r.shape + (3,), np.uint8)
    a[..., 0] = np.rint(np.clip(r, 0, 1) * 255).astype(np.uint8)
    write_rgb8(p, a)
    return a[..., 0]


def sha_file(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()


# ----------------------------------------------------------------------------------------------- keep / lighten rule
def base_stats(bc8, mask):
    """statistics of the 8-bit sRGB BaseColor under a bool mask (the texels the player colour will multiply)"""
    m = np.asarray(mask, bool)
    n = int(m.sum())
    if n == 0:
        return dict(texels=0)
    v = bc8[m].astype(np.float64)
    hue, chroma = hue_chroma(s2l(v))
    luma = v @ LUMA709
    mx, mn = v.max(-1), v.min(-1)
    return dict(texels=n, mean_srgb=[round(float(x), 1) for x in v.mean(0)], luma_mean=round(float(luma.mean()), 1),
                luma_p5_p50_p95=[round(float(x), 1) for x in np.percentile(luma, [5, 50, 95])],
                chroma_mean=round(float(chroma.mean()), 1), chroma_p95=round(float(np.percentile(chroma, 95)), 1),
                hue_median_deg=round(float(np.median(hue)), 1),
                hsv_sat_mean=round(float(np.mean((mx - mn) / np.maximum(mx, 1))), 3))


def classify(stats, luma_min=LIGHT_LUMA_MIN, chroma_max=LIGHT_CHROMA_MAX):
    """(verdict, reason): 'keep' for a light, low-chroma base (sails, white / cream walls, light cloth); 'lighten' for
    anything saturated or darker (gold, wood, painted colours), which would darken or tint the player colour"""
    if not stats.get('texels'):
        return 'none', 'no texels under the mask'
    light = stats['luma_mean'] >= luma_min
    neutral = stats['chroma_mean'] <= chroma_max
    if light and neutral:
        return 'keep', (f'light object: luma {stats["luma_mean"]} >= {luma_min} and chroma {stats["chroma_mean"]} <= '
                        f'{chroma_max}; the BaseColor stays under the mask')
    why = []
    if not light:
        why.append(f'luma {stats["luma_mean"]} < {luma_min} (darkens the player colour)')
    if not neutral:
        why.append(f'chroma {stats["chroma_mean"]} > {chroma_max} (tints the player colour)')
    return 'lighten', 'lighten under the mask (partial or neutral): ' + '; '.join(why)


def predicted_colours(bc8, r, full=None, players=(1, 2, 5)):
    """mean in-game sRGB colour under the full mask for a few player colours"""
    full = (r >= FULL_R / 255.0) if full is None else full
    if not full.any():
        return {}
    return {str(p): [round(float(x), 1) for x in ingame_albedo(bc8[full], np.ones(int(full.sum())), p)
                     .astype(np.float64).mean(0)] for p in players}


# -------------------------------------------------------------------------------------------------- image operators
def otsu(v, bins=128):
    """Otsu threshold of a 1-D sample; class 0 = v < threshold. The threshold sits in the middle of the empty gap after
    the last class-0 bin (a bin centre would cut that bin in half - CP2's version did, harmless on dense real data)"""
    h, e = np.histogram(v, bins=bins)
    c = (e[:-1] + e[1:]) / 2
    w0 = np.cumsum(h); w1 = w0[-1] - w0; s = np.cumsum(h * c)
    m0 = s / np.maximum(w0, 1); m1 = (s[-1] - s) / np.maximum(w1, 1)
    i = int(np.argmax(w0 * w1 * (m0 - m1) ** 2))
    nxt = np.nonzero(h[i + 1:])[0]
    return float((e[i + 1] + e[i + 1 + nxt[0]]) / 2) if len(nxt) else float(e[i + 1])


def components(m):
    """4-connected component labels of a bool array (0 = background), BFS over the set texels"""
    H, W = m.shape
    lab = np.zeros((H, W), np.int32)
    n = 0
    for r0, c0 in zip(*np.nonzero(m)):
        if lab[r0, c0]:
            continue
        n += 1
        lab[r0, c0] = n
        q = deque([(r0, c0)])
        while q:
            r, c = q.popleft()
            for dy, dx in N4:
                y, x = r + dy, c + dx
                if 0 <= y < H and 0 <= x < W and m[y, x] and not lab[y, x]:
                    lab[y, x] = n
                    q.append((y, x))
    return lab


def shift(a, dy, dx, fill):
    o = np.full_like(a, fill)
    H, W = a.shape
    o[max(dy, 0):H + min(dy, 0), max(dx, 0):W + min(dx, 0)] = a[max(-dy, 0):H + min(-dy, 0), max(-dx, 0):W + min(-dx, 0)]
    return o


def dilate(img, valid, steps=10):
    """gutter fill (single channel): unfilled texels take the mean of their filled 4-neighbours, `steps` rings"""
    img = img.astype(np.float32).copy()
    v = valid.copy()
    for _ in range(steps):
        acc = np.zeros_like(img); cnt = np.zeros(v.shape, np.float32)
        for dy, dx in N4:
            vv = shift(v, dy, dx, False); acc += shift(img, dy, dx, 0) * vv; cnt += vv
        new = (~v) & (cnt > 0)
        img[new] = acc[new] / cnt[new]
        v = v | new
    return img
