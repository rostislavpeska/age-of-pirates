"""numpy reference of the M3 game shader (references/shader-model.md): the same maths as viewer/shading/glsl.js,
written independently from the formulas, for the pixel-parity tests (test_shading_gpu.py) and the hand checks.

Every function works on arrays whose last axis is the vector axis (rgb, xyz), any leading shape, float64.
Stages, in the game's order:
    material()        materialdefault BasePass: samples + vertex data -> surface (albedo, metal, rough, ao, n, horizon)
    gbuffer()         the deferred storage round trip (albedo pow(1/2.2) 8 bit, normal 10 bit, data 8 bit), optional
    lighting()        lightingpass PSDirectIndirectLighting: sun (GGX, disc), IBL (cube lookups through env(dir, lod)),
                      hemisphere, shadow-colour tint, specular occlusion, EnvBRDF table, exposure
    pcf25()           the 25-tap bilinear soft-compare shadow filter on a depth array
    post_lut() / post_legacy()   fxaacolorgradetonemap PSMain (tonemap LUT, grade LUT, dither) / tonemap.hlsl (Hable)
The cube lookup is a callable env(dir, lod) -> rgba so the tests can use exact synthetic cubes.
"""
from __future__ import annotations

import math
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / 'scripts'))
import lighting as L  # noqa: E402

PI_INV = 0.318310
SUN_COS = 0.999550
SUN_SIN = 0.029995
FRESNEL = (-5.554730, -6.983160)
ROUGH_FLOOR = 0.08
MIP_POW = 0.769231
HORIZON = 1.5


def dot(a, b):
    return np.sum(a * b, axis=-1, keepdims=True)


def normalize(v):
    return v / np.sqrt(dot(v, v))


def sat(x):
    return np.clip(x, 0.0, 1.0)


def lerp(a, b, t):
    return a + (b - a) * t


def cross(a, b):
    return np.cross(a, b)


def safe_pow(x, e):
    """x^e as exp2(log2(x) e) with x <= 0 -> 0 (the shaders' log/exp pair)."""
    x = np.asarray(x, np.float64)
    with np.errstate(divide='ignore'):
        return np.where(x > 0, np.exp2(np.log2(np.maximum(x, 1e-38)) * e), 0.0)


def srgb_decode(c):
    return L.srgb_to_linear(c)


# ------------------------------------------------------------------------------------------------ material
def material(base, lift, nrm, masks, details, n_vert, t_vert, t_w, pc, params, *, front=None, double_sided=False,
             pos=None, eye=None):
    """the materialdefault BasePass. base/lift: linear rgb of the BaseColor sample and of its 2-mips-finer sample;
    nrm: Normals rgb (0..1); masks: Masks rgb; details: Details red (shape (..., 1)); n_vert/t_vert: interpolated
    vertex normal and tangent xyz (not normalised); t_w: tangent w (..., 1); pc: player colour (linear rgb);
    params: dict aoIntensity, aoGamma, liftMetallic, liftNonMetallic, roughnessMin/Max, roughnessMetallicMin/Max,
    metallicMin/Max; front: bool array (..., 1) for double-sided; pos/eye: world position and camera position.
    Returns dict albedo, metal, rough, ao, n, horizon (horizon not saturated)."""
    p = params
    s = np.where(front, 1.0, -1.0) if double_sided else 1.0
    nv, tv = n_vert * s, t_vert * s
    albedo = lerp(base, base * pc, details)
    nts = nrm * 2.0 - 1.0
    N, T = normalize(nv), normalize(tv)
    B = np.sign(t_w) * cross(N, T)
    n = normalize(nts[..., 0:1] * T + nts[..., 1:2] * B + nts[..., 2:3] * N)
    ao = safe_pow(np.maximum(1.0 - (1.0 - masks[..., 0:1]) * p['aoIntensity'], 0.0), max(1.0 + p['aoGamma'], 0.0))
    maxc = np.max(lift, axis=-1, keepdims=True)
    my, mz = masks[..., 1:2], masks[..., 2:3]
    r1 = lerp(p['roughnessMin'], p['roughnessMax'], my)
    r1 = lerp(r1, my, mz)
    rough = lerp(r1, lerp(p['roughnessMetallicMin'], p['roughnessMetallicMax'], r1), mz)
    metal = sat(lerp(p['metallicMin'], p['metallicMax'], mz))
    k = 1.0 + p['liftNonMetallic'] * (maxc - 1.0)
    albedo = albedo / lerp(k, 1.0, metal)
    albedo = sat(albedo / (1.0 + metal * p['liftMetallic'] * (maxc - 1.0)))
    V = normalize(pos - eye)
    R = V - 2.0 * dot(V, n) * n
    horizon = dot(nv, R) * HORIZON + 1.0
    return {'albedo': albedo, 'metal': metal, 'rough': rough, 'ao': ao, 'n': n, 'horizon': horizon}


def q(x, bits, bias=0.0):
    """UNORM store of `bits` bits: round to nearest; `bias` (in units of the value, e.g. +-3e-4) moves the rounding
    boundaries - the parity test accepts either side for values that close to a boundary."""
    m = float((1 << bits) - 1)
    return np.floor(sat(x) * m + 0.5 + bias * m) / m


def gbuffer(surf, quantise=True, bias=0.0):
    """the deferred storage round trip: what the lighting pass reads back. The data channels are UNORM (saturated)
    in both modes; quantise adds the 8/10-bit steps (bias: see q)."""
    enc = safe_pow(sat(surf['albedo']), 1.0 / 2.2)
    nenc = surf['n'] * 0.5 + 0.5
    metal, rough, ao, hor = surf['metal'], sat(surf['rough']), sat(surf['ao']), sat(surf['horizon'])
    if quantise:
        enc, metal, rough, ao, hor = (q(v, 8, bias) for v in (enc, metal, rough, ao, hor))
        nenc = q(nenc, 10, bias)
    return {'albedo': safe_pow(sat(enc), 2.2), 'metal': metal, 'rough': rough, 'ao': ao,
            'n': normalize(nenc * 2.0 - 1.0), 'horizon': hor}


# ------------------------------------------------------------------------------------------------ lighting
def rotate_y(d, sin, cos):
    return np.concatenate([d[..., 0:1] * cos + d[..., 2:3] * sin, d[..., 1:2],
                           -d[..., 0:1] * sin + d[..., 2:3] * cos], axis=-1)


def envbrdf(f0, rough, ndotv):
    scale = np.array(L.ENVBRDF_SCALE, np.float64)
    bias = np.array(L.ENVBRDF_BIAS, np.float64)
    ix = np.minimum(np.floor(sat(rough) * 8.0), 7.0).astype(int)[..., 0]
    iy = np.minimum(np.floor(sat(ndotv) * 8.0), 7.0).astype(int)[..., 0]
    return f0 * scale[iy, ix][..., None] + bias[iy, ix][..., None]


def lighting(g, pos, eye, shadow, lc, env, max_mip, ssao=1.0):
    """the lighting pass on the G-buffer read-back `g` (gbuffer() output, or a material() output for the forward
    reading). lc: dict sun_direction (light travel), sun_color, shadow_color, hemi_top, hemi_bottom, rot_sin, rot_cos,
    intensity, normalize, exposure. env(dir, lod) -> rgba. Returns the HDR rgb (before the post pass)."""
    albedo, metal, rough, n = g['albedo'], g['metal'], g['rough'], g['n']
    ao = g['ao'] * ssao
    S = np.asarray(lc['sun_direction'], np.float64)
    Lsun = -S
    Vd = normalize(pos - eye)
    ndotv = np.maximum(dot(n, -Vd), 1e-5)
    diffuse = albedo * (1.0 - metal)
    f0 = lerp(0.04, albedo, metal)
    alpha = np.maximum(rough, ROUGH_FLOOR) ** 2
    a2m1 = alpha * alpha - 1.0
    k = alpha * 0.5
    gv = 1.0 / (ndotv * (1.0 - k) + k)
    R = Vd - 2.0 * dot(Vd, n) * n
    cos_lr = dot(Lsun * np.ones_like(R), R)
    perp = R - cos_lr * Lsun
    with np.errstate(invalid='ignore', divide='ignore'):        # perp = 0 where R points at the sun: R is used there
        disc = normalize(normalize(perp) * SUN_SIN + Lsun * SUN_COS)
    Ld = np.where(cos_lr < SUN_COS, disc, R)
    ndotl = np.maximum(dot(n, Ld), 1e-5)
    H = normalize(Ld - Vd)
    vdoth = dot(-Vd, H)
    ndoth = dot(n, H)
    d = np.maximum(ndoth * ndoth * a2m1 + 1.0, 0.0)
    D = (alpha / d) ** 2 * PI_INV
    F = f0 + (1.0 - f0) * np.exp2(vdoth * (FRESNEL[0] * vdoth + FRESNEL[1]))
    vis = gv / (ndotl * (1.0 - k) + k) * 0.25
    sun = np.asarray(lc['sun_color'], np.float64)
    spec = F * vis * D * ndotl * sun
    diff = ndotl * diffuse * PI_INV * sun
    sh_ao = shadow * ao
    direct = diff * sh_ao + spec * sh_ao
    top, bottom = np.asarray(lc['hemi_top'], np.float64), np.asarray(lc['hemi_bottom'], np.float64)

    def env_lit(d, lod):
        e = env(rotate_y(d, lc['rot_sin'], lc['rot_cos']), lod)
        rgb, a = e[..., :3], e[..., 3:4]
        return (rgb * a + shadow * (rgb - rgb * a)) * lc['normalize']

    irr = env_lit(n, np.full(n.shape[:-1] + (1,), float(max_mip)))
    irr = irr * lerp(bottom, top, 0.5 + 0.5 * n[..., 1:2]) * lc['intensity'] * ao
    rs = sat(rough)
    lod = max_mip * safe_pow(rs, MIP_POW)
    senv = env_lit(R, lod) * lerp(bottom, top, 0.5 + 0.5 * R[..., 1:2]) * lc['intensity']
    occ = sat(safe_pow(sat(ao + ndotv), rough) + ao - 1.0) * g['horizon']
    spec_ibl = occ * senv * envbrdf(f0, rough, sat(ndotv))
    diff_ibl = diffuse * irr
    shadowed = np.maximum(np.maximum(dot(S * np.ones_like(n), n), 0.0), 1.0 - shadow)
    tint = lerp(1.0, np.asarray(lc['shadow_color'], np.float64), shadowed)
    colour = tint * diff_ibl + tint * spec_ibl + direct
    return colour * lc['exposure']


# ------------------------------------------------------------------------------------------------ shadows
def pcf25(depth, uv, z, bias, softness):
    """the 25-tap bilinear soft-compare filter: depth (S, S) row 0 = texture row 0 (t = 0), uv (..., 2), z (..., 1)
    receiver depth (0 near the light). lit = 1 - saturate((z - bias - d) * softness) per texel, texels floor(p) - 3 ..
    floor(p) + 2 (p = uv * S), weights [1 - f, 1, 1, 1, 1, f] per axis, / 25. Outside the map: 1."""
    S = depth.shape[0]
    p = uv * S
    i = np.floor(p)
    f = sat(p - i)
    out = np.zeros(uv.shape[:-1], np.float64)
    for a in range(6):
        wx = np.where(a == 0, 1.0 - f[..., 0], np.where(a == 5, f[..., 0], 1.0))
        xi = np.clip(i[..., 0].astype(int) - 3 + a, 0, S - 1)
        for b in range(6):
            wy = np.where(b == 0, 1.0 - f[..., 1], np.where(b == 5, f[..., 1], 1.0))
            yi = np.clip(i[..., 1].astype(int) - 3 + b, 0, S - 1)
            d = depth[yi, xi]
            lit = 1.0 - sat((z[..., 0] - bias - d) * softness)
            out += wx * wy * lit
    out = out / 25.0
    inside = (uv[..., 0] >= 0) & (uv[..., 0] <= 1) & (uv[..., 1] >= 0) & (uv[..., 1] <= 1) & (z[..., 0] <= 1)
    return np.where(inside, out, 1.0)[..., None]


# ------------------------------------------------------------------------------------------------ post
def trilinear(lut, uvw):
    """GL LINEAR sampling of a 3D texture lut[b, g, r, c] (r fastest = x) at uvw (..., 3), clamp to edge."""
    n = lut.shape[0]
    x = uvw * n - 0.5
    i0 = np.floor(x)
    f = x - i0
    i0 = i0.astype(int)
    out = 0.0
    for dz in (0, 1):
        for dy in (0, 1):
            for dx in (0, 1):
                ix = np.clip(i0[..., 0] + dx, 0, n - 1)
                iy = np.clip(i0[..., 1] + dy, 0, n - 1)
                iz = np.clip(i0[..., 2] + dz, 0, n - 1)
                w = (f[..., 0] if dx else 1 - f[..., 0]) * (f[..., 1] if dy else 1 - f[..., 1]) * \
                    (f[..., 2] if dz else 1 - f[..., 2])
                out = out + w[..., None] * lut[iz, iy, ix]
    return out


def post_lut(hdr, tonemap_lut, noise, grade_lut=None, grade_enabled=0.0, dither_scale=1.0 / 256.0):
    """fxaacolorgradetonemap PSMain: tonemap LUT at sqrt(min(c/2, 1)) * 31/32 + 1/64, grade LUT at t (N-1)/N + 0.5/N
    lerped by grade_enabled, + (2n - 1) * dither_scale. hdr (..., 3); noise (..., 3) in 0..1. Returns float rgb
    (before the 8-bit store)."""
    uvw = np.sqrt(np.minimum(hdr * 0.5, 1.0)) * (31.0 / 32.0) + 1.0 / 64.0
    t = trilinear(tonemap_lut, uvw)[..., :3]
    if grade_lut is not None:
        n = grade_lut.shape[0]
        g = trilinear(grade_lut, t * (n - 1) / n + 0.5 / n)[..., :3]
        t = lerp(t, g, grade_enabled)
    return t + (noise * 2.0 - 1.0) * dither_scale


def hable(x):
    return (x * (0.15 * x + 0.05) + 0.004) / (x * (0.15 * x + 0.5) + 0.06) - 0.066667


def post_legacy(hdr, noise, *, exposure=0.5, luminance_based=0.0, influence=1.0, white_point=11.2, noise_scale=0.0):
    """tonemap.hlsl PSMain (Uncharted 2 / Hable): c' = 2 exposure c; per channel hable(c') blended with the
    luminance-scaled version by luminance_based; / hable(white); + 0.1 noise_scale (2n - 1); lerp(c, t, influence),
    saturate; gamma 1/2.2."""
    e2 = 2.0 * exposure
    lum = dot(hdr, np.array(L.REC709_LUMA))
    with np.errstate(divide='ignore', invalid='ignore'):
        ratio = np.where(lum > 0, hable(e2 * lum) / np.maximum(lum, 1e-30), 0.0)
    per = hable(hdr * e2)
    t = sat(per + luminance_based * (hdr * ratio - per))
    t = t / hable(white_point)
    t = t + (noise * 2.0 - 1.0) * noise_scale * 0.1
    t = sat(lerp(hdr, t, influence))
    return safe_pow(t, 1.0 / 2.2)


def to_unorm8(x):
    return np.floor(sat(x) * 255.0 + 0.5).astype(np.int64)


def composite(rgb, alpha, background):
    """the viewer's background composite after the post pass (no game counterpart)."""
    bg = np.asarray(background[:3], np.float64)
    return lerp(bg, rgb, alpha)


__all__ = ['material', 'gbuffer', 'lighting', 'pcf25', 'post_lut', 'post_legacy', 'trilinear', 'envbrdf', 'hable',
           'to_unorm8', 'composite', 'rotate_y', 'q', 'math']
