"""World-space bake intent of a lapped tile roof: does the FINAL normal map, read through the mesh's actual UVs and
tangent frames, do what a tile roof must do - on THIS geometry? Pure NumPy (host Python); the Blender front end is
bake_intent_check.py. No HIGH model is needed: the downhill direction comes from each low face itself.

Per triangle: downhill g = steepest descent in the face plane (swept, curved, pyramid roofs are judged on their own
slopes - no fixed axis, so an intended odd shape is no false positive); tangent frame T = dP/du, B = dP/dv from the
UV derivatives (handedness kept, mirrored UVs handled); every covered texel's decoded tangent normal -> world
n = nx T + ny B + nz N.

  lap_asymmetry    steep texels facing DOWNhill (n.g > sin 20 deg) over those facing UPhill: a lap step drops
                   downhill, so a correct field is well above 1; reversed laps (green flipped) fall below 1
  roll_axis_ratio  mean |n.s| / mean |n.g|, s = N x g: rolls running down the fall line tilt the normal sideways, so
                   the ratio is well above 1; rolls turned 90 deg (R/G swapped) invert it
  lap_axis_deg     lap texels only: angle between the in-plane direction of their tilt and the fall line (p50/p95).
                   Content-derived and UV-convention free: level straight courses ~0; sagging or skewed courses
                   (a course coordinate measured along leaning grid columns) raise it
  anisotropy       |dP/dv| / |dP/du| per face, area-weighted p05/p50/p95: 1 = square texels; a stretched course
                   coordinate deviates
  frame_misalign   angle between the declared up-slope axis B and world uphill: CONVENTION-BOUND (an atlas may store
                   courses along u), so reported, never gated
Declared intent: faces flagged `free` (a builder-declared deviation, e.g. a corner sweep zone) are measured apart
(`*_declared`) and never gate. Calibrate with controls: flipG must drop lap_asymmetry below 1 and swapRG must drop
roll_axis_ratio below 1 on the SAME mesh, or the measure is not reading the map.
"""
import math
import numpy as np

TH = math.sin(math.radians(20))
# Starting thresholds (2026-10-11 calibration, roof-tile-direction-qa references/measurement-protocol.md): Korean TC
# own-HIGH roof lap 5.46 / roll 2.16 / lap axis p50 16.1 deg / anisotropy p05 .91; its flipG 0.55, swapRG roll 0.45;
# a known-bad bake (sagging courses) lap axis p50 23.8 deg / anisotropy p05 .45; its fix 12 deg / .99.
THRESHOLDS = dict(lap_asymmetry_min=2.0, roll_axis_ratio_min=1.5, lap_axis_p50_max=20.0, anisotropy_p05_min=.8,
                  anisotropy_p95_max=1.25, min_texels=2000)


def control(NT, kind):
    """a negative control of a decoded tangent-normal image (H, W, 3) in [-1, 1]"""
    if kind == 'none':
        return NT
    if kind == 'flipG':
        out = NT.copy(); out[..., 1] *= -1; return out
    if kind == 'swapRG':
        return NT[..., [1, 0, 2]]
    raise ValueError(kind)


def _wq(rows, q):
    if not rows:
        return None
    v = np.array(rows, float); o = np.argsort(v[:, 0]); c = np.cumsum(v[o, 1]) / v[:, 1].sum()
    return round(float(v[o, 0][min(int(np.searchsorted(c, q)), len(v) - 1)]), 3)


def _pct(vals, q):
    return round(float(np.percentile(vals, q)), 2) if len(vals) else None


def measure(P, UV, NT, free=None, mask=None, groups=None):
    """P (n, 3, 3) world triangle corners (z up); UV (n, 3, 2) with v up (image row 0 = v 1); NT (H, W, 3) decoded
    tangent normals in [-1, 1] (x along +u, y along +v); free (n,) bool = declared intent; mask (H, W) bool = only these
    texels count; groups (n,) labels for per-group lap/roll numbers. Returns the report dict."""
    P = np.asarray(P, float); UV = np.asarray(UV, float); H, W = NT.shape[:2]
    free = np.zeros(len(P), bool) if free is None else np.asarray(free, bool)
    down = up = 0; sum_s = sum_g = 0.; n_tex = 0; MIS, MISF, ANI, LAP, LAPF = [], [], [], [], []; per = {}
    for i in range(len(P)):
        p0, p1, p2 = P[i]; u0, u1, u2 = UV[i]
        N = np.cross(p1 - p0, p2 - p0); area = np.linalg.norm(N) / 2
        if area < 1e-10:
            continue
        N /= 2 * area
        g = np.array([0., 0., -1.]) + N * N[2]                  # steepest descent in the face plane
        if np.linalg.norm(g) < .2:                              # near-flat face: no downhill to judge
            continue
        g /= np.linalg.norm(g); s = np.cross(N, g)
        e1, e2, d1, d2 = p1 - p0, p2 - p0, u1 - u0, u2 - u0
        det = d1[0] * d2[1] - d2[0] * d1[1]
        if abs(det) < 1e-12:
            continue
        T = (e1 * d2[1] - e2 * d1[1]) / det; B = (e2 * d1[0] - e1 * d2[0]) / det
        Bu = B - N * N.dot(B)
        if np.linalg.norm(Bu) > 1e-12 and np.linalg.norm(T) > 1e-12:
            ang = math.degrees(math.acos(max(-1., min(1., Bu.dot(-g) / np.linalg.norm(Bu)))))
            (MISF if free[i] else MIS).append((ang, area))
            if not free[i]:
                ANI.append((np.linalg.norm(B) / np.linalg.norm(T), area))
        T = T - N * N.dot(T); T /= np.linalg.norm(T); hand = 1. if np.cross(N, T).dot(B) > 0 else -1.
        Bn = np.cross(N, T) * hand
        xs = UV[i, :, 0] * W; ys = (1 - UV[i, :, 1]) * H
        x0, x1 = max(int(xs.min()), 0), min(int(xs.max()) + 1, W - 1); y0, y1 = max(int(ys.min()), 0), min(int(ys.max()) + 1, H - 1)
        if x1 < x0 or y1 < y0:
            continue
        yy, xx = np.mgrid[y0:y1 + 1, x0:x1 + 1] + .5
        den = (ys[1] - ys[2]) * (xs[0] - xs[2]) + (xs[2] - xs[1]) * (ys[0] - ys[2])
        if abs(den) < 1e-9:
            continue
        l1 = ((ys[1] - ys[2]) * (xx - xs[2]) + (xs[2] - xs[1]) * (yy - ys[2])) / den
        l2 = ((ys[2] - ys[0]) * (xx - xs[2]) + (xs[0] - xs[2]) * (yy - ys[2])) / den
        ins = (l1 >= 0) & (l2 >= 0) & (1 - l1 - l2 >= 0)
        if mask is not None:
            ins &= mask[np.clip((yy - .5).astype(int), 0, H - 1), np.clip((xx - .5).astype(int), 0, W - 1)]
        if not ins.any():
            continue
        nt = NT[(yy[ins] - .5).astype(int), (xx[ins] - .5).astype(int)]
        nw = nt[:, :1] * T + nt[:, 1:2] * Bn + nt[:, 2:3] * N; nw /= np.linalg.norm(nw, axis=1, keepdims=True)
        dg = nw @ g; ds = nw @ s
        lapm = dg > TH
        if lapm.any():
            (LAPF if free[i] else LAP).extend(np.degrees(np.arctan2(np.abs(ds[lapm]), dg[lapm])).tolist())
        if free[i]:
            continue
        od, ou = int((dg > TH).sum()), int((dg < -TH).sum())
        down += od; up += ou; sum_s += float(np.abs(ds).sum()); sum_g += float(np.abs(dg).sum()); n_tex += int(ins.sum())
        if groups is not None:
            k = str(groups[i]); q = per.setdefault(k, [0, 0, 0., 0., 0])
            q[0] += od; q[1] += ou; q[2] += float(np.abs(ds).sum()); q[3] += float(np.abs(dg).sum()); q[4] += int(ins.sum())
    return dict(texels=n_tex, lap_asymmetry=round(down / max(up, 1), 3), roll_axis_ratio=round(sum_s / max(sum_g, 1e-9), 3),
                lap_axis_deg=dict(p50=_pct(LAP, 50), p95=_pct(LAP, 95)),
                anisotropy=dict(p05=_wq(ANI, .05), p50=_wq(ANI, .5), p95=_wq(ANI, .95)),
                frame_misalign_deg=dict(p50=_wq(MIS, .5), p95=_wq(MIS, .95), max=_wq(MIS, 1.), gated=False),
                declared=dict(faces=int(free.sum()), lap_texels=len(LAPF), lap_axis_p50=_pct(LAPF, 50),
                              frame_misalign_p50=_wq(MISF, .5)),
                steep_down=down, steep_up=up,
                per_group={k: dict(texels=v[4], lap_asymmetry=round(v[0] / max(v[1], 1), 3),
                                   roll_axis_ratio=round(v[2] / max(v[3], 1e-9), 3)) for k, v in per.items()})


def verdict(rep, th=None, controls=None):
    """PASS / FAIL / INCONCLUSIVE with reasons. controls = {'flipG': report, 'swapRG': report} of the same mesh: without
    both, the verdict is INCONCLUSIVE (the measure is not proven to read this map)."""
    th = dict(THRESHOLDS, **(th or {})); why = []
    if rep['texels'] < th['min_texels']:
        return 'INCONCLUSIVE', [f"{rep['texels']} texels < {th['min_texels']}: too little roof to judge"]
    if rep['lap_asymmetry'] < th['lap_asymmetry_min']:
        why.append(f"lap_asymmetry {rep['lap_asymmetry']} < {th['lap_asymmetry_min']} (laps reversed or flat)")
    if rep['roll_axis_ratio'] < th['roll_axis_ratio_min']:
        why.append(f"roll_axis_ratio {rep['roll_axis_ratio']} < {th['roll_axis_ratio_min']} (rolls not along the fall line)")
    la = rep['lap_axis_deg']['p50']
    if la is not None and la > th['lap_axis_p50_max']:
        why.append(f"lap_axis p50 {la} deg > {th['lap_axis_p50_max']} (courses sag or skew)")
    an = rep['anisotropy']
    if an['p05'] is not None and (an['p05'] < th['anisotropy_p05_min'] or an['p95'] > th['anisotropy_p95_max']):
        why.append(f"anisotropy p05/p95 {an['p05']}/{an['p95']} outside {th['anisotropy_p05_min']}..{th['anisotropy_p95_max']} "
                   '(stretched course coordinate)')
    if why:
        return 'FAIL', why
    if not controls or set(controls) < {'flipG', 'swapRG'}:
        return 'INCONCLUSIVE', ['controls flipG and swapRG not run on this mesh']
    if not controls['flipG']['lap_asymmetry'] < 1 or not controls['swapRG']['roll_axis_ratio'] < 1:
        return 'INCONCLUSIVE', [f"controls did not invert (flipG lap {controls['flipG']['lap_asymmetry']}, swapRG roll "
                                f"{controls['swapRG']['roll_axis_ratio']}): the measure is not reading this map"]
    return 'PASS', []
