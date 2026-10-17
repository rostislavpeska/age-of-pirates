"""Shared colour statistics (sRGB 8-bit inputs)."""
import numpy as np
from PIL import Image, ImageFilter


def luma(rgb):
    rgb = rgb.astype(np.float64)
    return 0.2126 * rgb[..., 0] + 0.7152 * rgb[..., 1] + 0.0722 * rgb[..., 2]


def hsv_s(rgb):
    rgb = rgb.astype(np.float64)
    mx = rgb.max(-1)
    mn = rgb.min(-1)
    return np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0.0)


def srgb_to_lin(c):
    c = c / 255.0
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def lab(rgb):
    l = srgb_to_lin(rgb.astype(np.float64))
    M = np.array([[0.4124, 0.3576, 0.1805], [0.2126, 0.7152, 0.0722], [0.0193, 0.1192, 0.9505]])
    xyz = l @ M.T
    xyz = xyz / np.array([0.95047, 1.0, 1.08883])
    f = np.where(xyz > 0.008856, np.cbrt(xyz), 7.787 * xyz + 16 / 116)
    L = 116 * f[..., 1] - 16
    a = 500 * (f[..., 0] - f[..., 1])
    b = 200 * (f[..., 1] - f[..., 2])
    return L, a, b


def highpass_std(rgb, mask, sigma=4):
    """std of luma minus its Gaussian blur: density of painted micro detail (grunge, grain, cracks)."""
    y = luma(rgb)
    im = Image.fromarray(np.clip(y, 0, 255).astype(np.uint8))
    bl = np.asarray(im.filter(ImageFilter.GaussianBlur(sigma))).astype(np.float64)
    hp = y - bl
    return float(hp[mask].std()) if mask.any() else float('nan')


def lowpass_std(rgb, mask, sigma=16):
    """std of a strongly blurred luma: macro value variation (big stains, streaks, AO gradients)."""
    y = luma(rgb)
    im = Image.fromarray(np.clip(y, 0, 255).astype(np.uint8))
    bl = np.asarray(im.filter(ImageFilter.GaussianBlur(sigma))).astype(np.float64)
    return float(bl[mask].std()) if mask.any() else float('nan')


def stain_frac(rgb, mask, sigma=12, k=0.75):
    """fraction of texels darker than k x their local (blurred) luma: chips, stains, cracks, pits."""
    y = luma(rgb)
    im = Image.fromarray(np.clip(y, 0, 255).astype(np.uint8))
    bl = np.asarray(im.filter(ImageFilter.GaussianBlur(sigma))).astype(np.float64)
    return float((y[mask] < k * bl[mask]).mean()) if mask.any() else float('nan')


def green_frac(px):
    """fraction of texels that read as moss/lichen/algae green (Lab hue 100-170 deg, chroma > 10)."""
    L, a, b = lab(px)
    C = np.hypot(a, b)
    h = (np.degrees(np.arctan2(b, a)) + 360) % 360
    return float(((h > 100) & (h < 170) & (C > 10)).mean())


def stats(rgb, mask):
    """rgb HxWx3 uint8, mask HxW bool."""
    if not mask.any():
        return None
    px = rgb[mask]
    y = luma(px)
    s = hsv_s(px)
    L, a, b = lab(px)
    C = np.hypot(a, b)
    hue = (np.degrees(np.arctan2(b, a)) + 360) % 360
    m = px.astype(np.float64).mean(0)
    return dict(
        n=int(mask.sum()),
        luma_mean=round(float(y.mean()), 1),
        luma_std=round(float(y.std()), 1),
        luma_p5=round(float(np.percentile(y, 5)), 1),
        luma_p50=round(float(np.percentile(y, 50)), 1),
        luma_p95=round(float(np.percentile(y, 95)), 1),
        sat_mean=round(float(s.mean()), 3),
        chroma_mean=round(float(C.mean()), 1),
        hue_mean_deg=round(float((np.degrees(np.arctan2(b.mean(), a.mean())) + 360) % 360), 0),
        warmth_RminusB=round(float(m[0] - m[2]), 1),
        rgb_mean=[round(float(v), 1) for v in m],
        hp_std=round(highpass_std(rgb, mask), 2),
        lp_std=round(lowpass_std(rgb, mask), 2),
        stain_frac=round(stain_frac(rgb, mask), 3),
        green_frac=round(green_frac(px), 3),
    )
