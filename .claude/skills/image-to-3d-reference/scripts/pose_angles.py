#!/usr/bin/env python
"""Pose angles of a figure from joint picks in a JSON file: 2D on a front view, 3D with a side ortho view.

    python pose_angles.py PICKS.json --out SCRATCH/pose.json [--centre-limbs] [--overlay-dir SCRATCH/overlays]

Use it to check a re-posed design image before the paid 3D job, and the generated model's pose after it
(render_ortho.py front + side). Picks are image pixels [x, y] (y down), read off grid.py overlays. Host Python with
numpy; Pillow only for --centre-limbs, --overlay-dir and a hip rule without ground_y. No Blender.

PICKS.json (paths relative to the JSON file; every block except "cases" and one arm or leg is optional):
  {"target": {"upper_arm_from_down": 26.2, "elbow": 26.5, "leg_spread": 16.4},
   "cases": {"E3": {
      "front": {"image": "E3_front.png",
                "arms": {"R": [S, E, W], "L": [S, E, W]},          shoulder, elbow, wrist centres
                "legs": {"R": [H, A], "L": [H, K, A]},             hip, (knee,) ankle
                "hip_rule": {"height": 0.646, "half_width": 0.0615, "ground_y": 1099}},
      "side": {"arm": "L", "points": [S, E, W]},                   the same arm's joints in the side ortho view
      "ortho": "E3_ortho.json"}}}                                  or {"res": 1200, "px_per_m": 500, "centre_z": 1.0}
"R" is the image-left limb = the figure's RIGHT side in a front view. A hip_rule places hidden hip joints from both
shoulder picks and the ground line (lowest silhouette row when ground_y is absent): hip height = height x the
shoulder height above the ground, hips half_width x that height either side of the shoulder centre; the leg lists
then hold only (knee,) ankle. Take the two fractions from the target skeleton (hip joint height / shoulder joint
height, half the hip separation / shoulder joint height).

Reported per case: per arm upper_arm_from_down, forearm_from_down, chord_from_down (signed, positive = away from the
body) and elbow_projected (bend in the image plane, 0 = straight); per leg leg_from_down (hip to ankle, signed) and
knee_projected; leg_spread = the two leg angles summed (negative when the legs cross); with "side" + "ortho" the arm
in 3D (front gives X and Z, side gives Y and Z): upper_arm_from_down_3d, elbow_3d (bend), chord_from_down_3d,
wrist_forward_of_shoulder_m (a figure facing -Y) and front_side_z_mismatch_m (pick consistency; > 0.02 m: re-pick);
errors = measured - target. --centre-limbs moves the elbow and wrist picks across the limb to the middle of the
silhouette (transparent render, or a plain background read from the border). Outputs must lie outside every git
work tree. Exit 0 = measured, 2 = setup error (bad or missing picks, image or ortho mapping, refused path).
"""
import argparse
import hashlib
import json
import math
import os
import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
sys.path[:0] = [str(HERE), str(HERE.parents[1] / 'blender-organic-modeling' / 'scripts')]
try:
    import blender_env as E  # noqa: E402
except ImportError:
    sys.exit('SETUP ERROR: companion skill blender-organic-modeling (scripts/blender_env.py) not found')

SIDES = ('R', 'L')
OUT = {'R': -1, 'L': 1}          # outward image x direction per side in a front view


class SetupError(Exception):
    pass


# ----------------------------------------------------------------------------------------------- geometry
def angle_between(u, v):
    u, v = np.asarray(u, float), np.asarray(v, float)
    nu, nv = np.linalg.norm(u), np.linalg.norm(v)
    if nu == 0 or nv == 0:
        raise SetupError('two picks of one limb coincide')
    return math.degrees(math.acos(float(np.clip(u @ v / nu / nv, -1, 1))))


def from_down(v, side):
    """Angle of image vector v from straight down (+y), positive when it points away from the body."""
    a = math.degrees(math.atan2(abs(v[0]), v[1]))
    return a if (v[0] * OUT[side] > 0 or abs(v[0]) < 1e-9) else -a


def arm_2d(S, E_, W, side):
    S, E_, W = (np.asarray(p, float) for p in (S, E_, W))
    return dict(S=S.round(1).tolist(), E=E_.round(1).tolist(), W=W.round(1).tolist(),
                upper_arm_from_down=round(from_down(E_ - S, side), 1),
                forearm_from_down=round(from_down(W - E_, side), 1),
                chord_from_down=round(from_down(W - S, side), 1),
                elbow_projected=round(angle_between(E_ - S, W - E_), 1))


def leg_2d(points, side):
    P = [np.asarray(p, float) for p in points]
    rec = dict(points=[p.round(1).tolist() for p in P], leg_from_down=round(from_down(P[-1] - P[0], side), 1))
    if len(P) == 3:
        rec['knee_projected'] = round(angle_between(P[1] - P[0], P[2] - P[1]), 1)
    return rec


def to_world(front_px, side_px, ortho):
    """3D point from a front pick (x -> X, y -> Z) and a side pick (x -> Y, y -> Z) of normalised ortho renders."""
    res, ppm, cz = ortho['res'], ortho['px_per_m'], ortho['centre_z']
    X = (front_px[0] - res / 2) / ppm
    Y = (side_px[0] - res / 2) / ppm
    Z = cz - ((front_px[1] + side_px[1]) / 2 - res / 2) / ppm
    return np.array([X, Y, Z]), abs(front_px[1] - side_px[1]) / ppm


def arm_3d(front, side_pts, ortho):
    P, dz = zip(*(to_world(f, s, ortho) for f, s in zip(front, side_pts)))
    S, E_, W = P
    down = np.array([0.0, 0.0, -1.0])
    return dict(S=S.round(4).tolist(), E=E_.round(4).tolist(), W=W.round(4).tolist(),
                upper_arm_from_down_3d=round(angle_between(E_ - S, down), 1),
                elbow_3d=round(angle_between(E_ - S, W - E_), 1),
                chord_from_down_3d=round(angle_between(W - S, down), 1),
                wrist_forward_of_shoulder_m=round(float(S[1] - W[1]), 4),
                front_side_z_mismatch_m=round(float(max(dz)), 4))


# ----------------------------------------------------------------------------------------------- silhouette
def silhouette(path):
    """(RGB image, boolean mask): alpha when the image has transparency, else distance from the border colour."""
    from PIL import Image, ImageFilter
    im = Image.open(path)
    if im.mode in ('RGBA', 'LA') or (im.mode == 'P' and 'transparency' in im.info):
        rgba = im.convert('RGBA')
        alpha = np.asarray(rgba)[:, :, 3]
        if alpha.min() < 255:
            return rgba, alpha > 128
    rgb = im.convert('RGB')
    a = np.asarray(rgb).astype(float)
    border = np.concatenate([a[:8].reshape(-1, 3), a[-8:].reshape(-1, 3), a[:, :8].reshape(-1, 3),
                             a[:, -8:].reshape(-1, 3)])
    m = np.sqrt(((a - np.median(border, 0)) ** 2).sum(2)) > 30
    mi = Image.fromarray((m * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(3)).filter(ImageFilter.MaxFilter(3))
    return rgb, np.asarray(mi) > 128


def _inside(m, p):
    x, y = int(round(p[0])), int(round(p[1]))
    return 0 <= y < m.shape[0] and 0 <= x < m.shape[1] and bool(m[y, x])


def centre_across(m, p, d, cap=60, search=20):
    """Move p perpendicular to direction d to the middle of the silhouette run through it.
    Returns (point, run width in px, capped). Capped means no limb edge was found within `cap` px on one side (the
    limb touches the body, a coat or a skirt) or the pick is off the silhouette: the pick is then returned UNCHANGED,
    because the middle of such a run depends on the cap, not on the limb (2026-10-11: a fused elbow moved 4-7 px
    with the cap, the upper-arm angle 2-3 deg)."""
    d = np.asarray(d, float)
    d = d / np.linalg.norm(d)
    n = np.array([-d[1], d[0]])
    p0 = p = np.asarray(p, float)
    if not _inside(m, p):
        for k in range(1, search + 1):
            hit = next((p + s * k * n for s in (1, -1) if _inside(m, p + s * k * n)), None)
            if hit is not None:
                p = hit
                break
        else:
            return p0, 0, True
    ext = []
    for s in (1, -1):
        k = 0
        while k < cap and _inside(m, p + s * (k + 1) * n):
            k += 1
        ext.append(k)
    if max(ext) >= cap:
        return p0, int(ext[0] + ext[1] + 1), True
    return p + n * (ext[0] - ext[1]) / 2.0, int(ext[0] + ext[1] + 1), False


# ----------------------------------------------------------------------------------------------- input
def _pt(v, where):
    if (not isinstance(v, (list, tuple)) or len(v) != 2
            or not all(isinstance(c, (int, float)) and not isinstance(c, bool) for c in v)):
        raise SetupError('%s: expected a pixel pick [x, y], got %r' % (where, v))
    return [float(v[0]), float(v[1])]


def _pts(v, n, where):
    if not isinstance(v, list) or len(v) not in n:
        raise SetupError('%s: expected %s picks' % (where, ' or '.join(map(str, n))))
    return [_pt(p, '%s[%d]' % (where, i)) for i, p in enumerate(v)]


def load_ortho(spec, base, where):
    if isinstance(spec, str):
        p = (base / spec) if not os.path.isabs(spec) else Path(spec)
        try:
            spec = json.loads(Path(p).read_text(encoding='utf-8-sig'))
        except (OSError, ValueError) as exc:
            raise SetupError('%s: ortho mapping %s: %s' % (where, p, exc))
    if not isinstance(spec, dict):
        raise SetupError('%s: "ortho" must be a file name or {"res", "px_per_m", "centre_z"}' % where)
    try:
        return dict(res=float(spec['res']), px_per_m=float(spec['px_per_m']), centre_z=float(spec['centre_z']))
    except (KeyError, TypeError, ValueError):
        raise SetupError('%s: ortho mapping needs numeric res, px_per_m and centre_z' % where)


def load_picks(path):
    try:
        data = json.loads(Path(path).read_text(encoding='utf-8-sig'))
    except (OSError, ValueError) as exc:
        raise SetupError('picks %s: %s' % (path, exc))
    if not isinstance(data, dict) or not isinstance(data.get('cases'), dict) or not data['cases']:
        raise SetupError('picks %s: expected {"cases": {"<tag>": {...}}}' % path)
    target = data.get('target') or {}
    if not isinstance(target, dict) or not all(isinstance(v, (int, float)) for v in target.values()):
        raise SetupError('picks %s: "target" must map names to numbers' % path)
    return data, target


# ----------------------------------------------------------------------------------------------- measure
def measure_case(tag, case, base, target, centre):
    if not isinstance(case, dict) or not isinstance(case.get('front'), dict):
        raise SetupError('%s: every case needs a "front" block' % tag)
    front = case['front']
    img = front.get('image')
    img_path = None
    if img:
        img_path = (base / img) if not os.path.isabs(img) else Path(img)
        if not img_path.is_file():
            raise SetupError('%s: image not found: %s' % (tag, img_path))
    arms_in = front.get('arms') or {}
    legs_in = front.get('legs') or {}
    if not isinstance(arms_in, dict) or not isinstance(legs_in, dict) or not (arms_in or legs_in):
        raise SetupError('%s: front needs "arms" and/or "legs" keyed R / L' % tag)
    for k in list(arms_in) + list(legs_in):
        if k not in SIDES:
            raise SetupError('%s: limb key %r is not R or L' % (tag, k))
    mask = None
    if centre or (front.get('hip_rule') and 'ground_y' not in front['hip_rule']):
        if img_path is None:
            raise SetupError('%s: --centre-limbs and a hip_rule without ground_y need front.image' % tag)
        mask = silhouette(img_path)[1]
    res = dict(image=str(img_path) if img_path else None, arms={}, legs={})
    arms = {}
    for side, v in arms_in.items():
        S, E_, W = _pts(v, (3,), '%s.front.arms.%s' % (tag, side))
        if centre:
            E_, wE, cE = centre_across(mask, E_, np.subtract(W, S))
            W, wW, cW = centre_across(mask, W, np.subtract(W, E_))
            res.setdefault('centring', {})[side] = dict(elbow_width_px=wE, elbow_kept_as_picked=bool(cE),
                                                        wrist_width_px=wW, wrist_kept_as_picked=bool(cW))
        arms[side] = (S, list(E_), list(W))
        res['arms'][side] = arm_2d(S, E_, W, side)
    legs = {side: _pts(v, (1, 2, 3), '%s.front.legs.%s' % (tag, side)) for side, v in legs_in.items()}
    rule = front.get('hip_rule')
    if rule:
        if set(arms) != set(SIDES):
            raise SetupError('%s: a hip_rule needs both shoulder picks' % tag)
        try:
            fh, fw = float(rule['height']), float(rule['half_width'])
        except (KeyError, TypeError, ValueError):
            raise SetupError('%s: hip_rule needs numeric height and half_width' % tag)
        ground = float(rule['ground_y']) if 'ground_y' in rule else float(np.where(mask.any(1))[0].max())
        sh_y = (arms['R'][0][1] + arms['L'][0][1]) / 2
        cx = (arms['R'][0][0] + arms['L'][0][0]) / 2
        h = ground - sh_y
        hip_y = ground - fh * h
        hips = {'R': [cx - fw * h, hip_y], 'L': [cx + fw * h, hip_y]}
        legs = {side: [hips[side]] + pts for side, pts in legs.items()}
        res['hip_rule'] = dict(ground_y=ground, shoulder_height_px=round(h, 1), hips={k: [round(c, 1) for c in v]
                                                                                    for k, v in hips.items()})
    for side, pts in legs.items():
        if len(pts) < 2 or len(pts) > 3:
            raise SetupError('%s: leg %s needs hip and ankle (and optionally the knee)' % (tag, side))
        res['legs'][side] = leg_2d(pts, side)
    if set(res['legs']) == set(SIDES):
        res['leg_spread'] = round(res['legs']['R']['leg_from_down'] + res['legs']['L']['leg_from_down'], 1)
    if 'side' in case:
        sd = case['side']
        if not isinstance(sd, dict) or sd.get('arm') not in arms:
            raise SetupError('%s: "side" needs "arm" (R or L, with front picks) and "points"' % tag)
        if 'ortho' not in case:
            raise SetupError('%s: "side" needs an "ortho" mapping (render_ortho.py *_ortho.json)' % tag)
        side_pts = _pts(sd.get('points'), (3,), '%s.side.points' % tag)
        res['arm_3d'] = dict(arm=sd['arm'], **arm_3d(arms[sd['arm']], side_pts, load_ortho(case['ortho'], base, tag)))
    errors = {}
    if 'upper_arm_from_down' in target:
        for side, rec in res['arms'].items():
            errors['upper_arm_%s' % side] = round(rec['upper_arm_from_down'] - target['upper_arm_from_down'], 1)
        if 'arm_3d' in res:
            errors['upper_arm_3d'] = round(res['arm_3d']['upper_arm_from_down_3d'] - target['upper_arm_from_down'], 1)
    if 'elbow' in target and 'arm_3d' in res:
        errors['elbow_3d'] = round(res['arm_3d']['elbow_3d'] - target['elbow'], 1)
    if 'leg_spread' in target and 'leg_spread' in res:
        errors['leg_spread'] = round(res['leg_spread'] - target['leg_spread'], 1)
    res['errors'] = errors
    res['_draw'] = dict(arms=arms, legs=legs)
    return res


def draw_overlay(tag, res, target, path):
    """Front image with the measured limbs (green) and the target directions (yellow)."""
    from PIL import Image, ImageDraw
    src = Image.open(res['image'])
    im = Image.new('RGB', src.size, (205, 205, 205))
    if src.mode in ('RGBA', 'LA'):
        im.paste(src.convert('RGBA'), (0, 0), src.convert('RGBA'))
    else:
        im = src.convert('RGB')
    d = ImageDraw.Draw(im)
    for side, (S, E_, W) in res['_draw']['arms'].items():
        S, E_, W = (np.asarray(p, float) for p in (S, E_, W))
        if 'upper_arm_from_down' in target:
            t = math.radians(target['upper_arm_from_down'])
            L = (np.linalg.norm(E_ - S) + np.linalg.norm(W - E_)) * 1.15
            G = S + np.array([OUT[side] * math.sin(t), math.cos(t)]) * L
            d.line([tuple(S), tuple(G)], fill=(255, 220, 0), width=3)
        d.line([tuple(S), tuple(E_), tuple(W)], fill=(0, 230, 60), width=3)
        for P in (S, E_, W):
            d.ellipse([P[0] - 5, P[1] - 5, P[0] + 5, P[1] + 5], outline=(0, 120, 0), fill=(0, 230, 60))
    for side, pts in res['_draw']['legs'].items():
        P = [np.asarray(p, float) for p in pts]
        if 'leg_spread' in target:
            t = math.radians(target['leg_spread'] / 2)
            G = P[0] + np.array([OUT[side] * math.tan(t), 1.0]) * (P[-1][1] - P[0][1])
            d.line([tuple(P[0]), tuple(G)], fill=(255, 220, 0), width=3)
        d.line([tuple(p) for p in P], fill=(0, 230, 60), width=3)
        for p in P:
            d.ellipse([p[0] - 5, p[1] - 5, p[0] + 5, p[1] + 5], outline=(0, 120, 0), fill=(0, 230, 60))
    d.text((8, 8), '%s  green = measured, yellow = target' % tag, fill=(0, 0, 0))
    im.save(path)
    return path


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def build_parser():
    ap = argparse.ArgumentParser(prog='pose_angles.py', description=__doc__.splitlines()[0],
                                 epilog='The module docstring describes the picks file.',
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('picks', help='picks JSON (see the module docstring)')
    ap.add_argument('--out', required=True, help='result JSON, outside any git work tree')
    ap.add_argument('--centre-limbs', action='store_true', help='centre elbow and wrist picks across the silhouette')
    ap.add_argument('--overlay-dir', help='write <case>_pose.png overlays here (cases with a front image)')
    return ap


def run(a):
    out = os.path.abspath(a.out)
    for p, what in ((out, '--out'), (os.path.abspath(a.overlay_dir) if a.overlay_dir else None, '--overlay-dir')):
        if p:
            err = E.refuse_in_worktree(p, what)
            if err:
                raise SetupError(err)
    data, target = load_picks(a.picks)
    base = Path(a.picks).resolve().parent
    result = dict(tool='pose_angles', picks=str(Path(a.picks).resolve()), picks_sha256=sha256(a.picks),
                  target=target, centre_limbs=bool(a.centre_limbs), cases={})
    overlays = []
    for tag, case in data['cases'].items():
        rec = measure_case(tag, case, base, target, a.centre_limbs)
        if a.overlay_dir and rec['image']:
            os.makedirs(os.path.abspath(a.overlay_dir), exist_ok=True)
            overlays.append(draw_overlay(tag, rec, target, os.path.join(os.path.abspath(a.overlay_dir),
                                                                          '%s_pose.png' % tag)))
            rec['overlay'] = overlays[-1]
        rec.pop('_draw')
        result['cases'][tag] = rec
        arms = ' '.join('%s %.1f' % (s, r['upper_arm_from_down']) for s, r in rec['arms'].items())
        extra = ''
        if 'arm_3d' in rec:
            extra += ', 3D %.1f, elbow 3D %.1f' % (rec['arm_3d']['upper_arm_from_down_3d'], rec['arm_3d']['elbow_3d'])
        if 'leg_spread' in rec:
            extra += ', legs %.1f' % rec['leg_spread']
        print('%s: upper arm %s%s; errors %s' % (tag, arms or '-', extra, json.dumps(rec['errors'])))
    os.makedirs(os.path.dirname(out), exist_ok=True)
    Path(out).write_text(json.dumps(result, indent=1), encoding='utf-8')
    print('POSE %s' % out)
    return 0


def main(argv=None):
    try:
        a = build_parser().parse_args(argv)
    except SystemExit as exc:
        return 2 if exc.code else 0
    try:
        return run(a)
    except SetupError as exc:
        print('SETUP ERROR: %s' % exc, file=sys.stderr)
        return 2


if __name__ == '__main__':
    sys.exit(main())
