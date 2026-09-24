"""Calibrate a screen: fit the minimap disc (centre, radius, signs) from measured pixel pairs.

    python scripts/mapview/calibrate.py fit <pairs.json> --screen ingame --size 2560x1080 [--fill longer_side]
    python scripts/mapview/calibrate.py blobs <screenshot.png> --box x0,y0,x1,y1 [--colour R,G,B --tol 40]
    python scripts/mapview/calibrate.py check <pairs.json> --screen ingame --size 2560x1080
    python scripts/mapview/calibrate.py show

pairs.json (fractions or metres; metres need the map size):
    {"map": "zplondon", "players": 2, "size_x_m": 360, "size_z_m": 645,
     "pairs": [{"x_m": 13.1, "z_m": 493.5, "px": 2301, "py": 887, "what": "TC p1"}, ...]}
    or  "pairs": [{"fx": 0.5, "fz": 0.5, "px": ..., "py": ...}, ...]

Method (spec 3.2): generate a known map in the editor, place three or more distinctive units at known world
coordinates (map corners, the centre, one off-axis point), screenshot the minimap at FULL resolution, find their
pixels (the `blobs` command finds coloured blobs inside a box) and `fit`. Acceptance: every pair within 2 px, a
fourth independent pair within 3 px (`check`). The record is written only when it passes; a failed fit prints
its residuals and writes nothing. Records live in scripts/mapview/cal/<screen>_<WxH>.json.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from scripts.mapview.transform import (Calibration, aspect_of, fit_affine_diagnostic, fit_calibration,  # noqa: E402
                                        frac_to_minimap, list_calibrations, load_calibration, max_residual,
                                        world_to_frac)

ACCEPT_FIT_PX = 2.0
ACCEPT_CHECK_PX = 3.0


def load_pairs(path: Path):
    d = json.loads(Path(path).read_text(encoding="utf-8"))
    sx, sz = d.get("size_x_m"), d.get("size_z_m")
    pairs, labels = [], []
    for p in d["pairs"]:
        if "fx" in p:
            fx, fz = float(p["fx"]), float(p["fz"])
        else:
            if not (sx and sz):
                raise SystemExit("pairs in metres need size_x_m and size_z_m in the file")
            fx, fz = world_to_frac(float(p["x_m"]), float(p["z_m"]), sx, sz)
        pairs.append((fx, fz, float(p["px"]), float(p["py"])))
        labels.append(p.get("what", ""))
    aspect = aspect_of(sx, sz) if (sx and sz) else float(d.get("aspect", 1.0))
    return d, pairs, labels, aspect


def blobs(image_path: Path, box, colour=None, tol=40, min_px=4):
    """Coloured blobs inside box=(x0,y0,x1,y1) of a full-resolution screenshot: [(cx, cy, n_px, rgb)] sorted by
    size. With no colour: every saturated blob (max channel - min channel > 90). Pure PIL, no numpy."""
    from PIL import Image
    im = Image.open(image_path).convert("RGB")
    x0, y0, x1, y1 = box
    px = im.load()
    hits = []
    for y in range(y0, y1):
        for x in range(x0, x1):
            r, g, b = px[x, y]
            if colour is None:
                ok = (max(r, g, b) - min(r, g, b)) > 90
            else:
                ok = abs(r - colour[0]) <= tol and abs(g - colour[1]) <= tol and abs(b - colour[2]) <= tol
            if ok:
                hits.append((x, y, (r, g, b)))
    # 8-connected components by grid buckets of 3 px
    groups = []
    seen = set()
    index = {}
    for x, y, rgb in hits:
        index.setdefault((x // 3, y // 3), []).append((x, y, rgb))
    for key in index:
        if key in seen:
            continue
        stack = [key]; comp = []
        seen.add(key)
        while stack:
            k = stack.pop()
            comp.extend(index[k])
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    nk = (k[0] + dx, k[1] + dy)
                    if nk in index and nk not in seen:
                        seen.add(nk); stack.append(nk)
        if len(comp) >= min_px:
            cx = sum(p[0] for p in comp) / len(comp)
            cy = sum(p[1] for p in comp) / len(comp)
            rgb = tuple(sum(p[2][i] for p in comp) // len(comp) for i in range(3))
            groups.append((round(cx, 1), round(cy, 1), len(comp), rgb))
    return sorted(groups, key=lambda g: -g[2])


def cmd_fit(a):
    d, pairs, labels, aspect = load_pairs(a.pairs)
    w, h = (int(x) for x in a.size.lower().split("x"))
    cal = fit_calibration(pairs, aspect, a.screen, w, h, fill=a.fill,
                          note="fitted from %s (%s, aspect %.3f)" % (Path(a.pairs).name, d.get("map", "?"), aspect))
    print("fit: centre (%.1f, %.1f) radius %.1f px sign_u %d sign_v %d fill %s" % (cal.cx, cal.cy, cal.radius_px, cal.sign_u, cal.sign_v, cal.fill))
    worst = 0.0
    for (fx, fz, px, py), lab in zip(pairs, labels):
        qx, qy = frac_to_minimap(fx, fz, cal, aspect)
        e = ((qx - px) ** 2 + (qy - py) ** 2) ** 0.5
        worst = max(worst, e)
        print("  %-22s measured (%7.1f, %7.1f) predicted (%7.1f, %7.1f) err %.2f px" % (lab, px, py, qx, qy, e))
    try:
        diag = fit_affine_diagnostic(pairs, aspect)
        print("free affine: scale u %.2f v %.2f px/unit, angle %.2f deg, skew %.2f deg, residual %.2f px"
              % (diag["scale_u"], diag["scale_v"], diag["angle_deg"], diag["skew_deg"], diag["residual_px"]))
    except Exception as e:  # numpy missing
        print("free affine diagnostic skipped: %s" % e)
    if worst > ACCEPT_FIT_PX and not a.force:
        print("REJECTED: worst residual %.2f px > %.1f - nothing written (measure again, or --force to keep)" % (worst, ACCEPT_FIT_PX))
        return 1
    p = cal.save()
    print("written %s (residual %.2f px)" % (p, cal.residual_px))
    return 0


def cmd_check(a):
    d, pairs, labels, aspect = load_pairs(a.pairs)
    w, h = (int(x) for x in a.size.lower().split("x"))
    cal = load_calibration(a.screen, w, h)
    worst = max_residual(cal, pairs, aspect)
    for (fx, fz, px, py), lab in zip(pairs, labels):
        qx, qy = frac_to_minimap(fx, fz, cal, aspect)
        print("  %-22s measured (%7.1f, %7.1f) predicted (%7.1f, %7.1f) err %.2f px" % (lab, px, py, qx, qy, ((qx - px) ** 2 + (qy - py) ** 2) ** 0.5))
    print("check: worst %.2f px -> %s" % (worst, "PASS" if worst <= ACCEPT_CHECK_PX else "FAIL"))
    return 0 if worst <= ACCEPT_CHECK_PX else 1


def cmd_blobs(a):
    box = tuple(int(x) for x in a.box.split(","))
    colour = tuple(int(x) for x in a.colour.split(",")) if a.colour else None
    for cx, cy, n, rgb in blobs(Path(a.image), box, colour, a.tol)[:a.top]:
        print("blob at (%.1f, %.1f)  %4d px  rgb %s" % (cx, cy, n, rgb))
    return 0


def cmd_show(a):
    cals = list_calibrations()
    if not cals:
        print("no calibrations in scripts/mapview/cal - nothing is measured yet")
    for p in cals:
        c = Calibration.from_json(p.read_text(encoding="utf-8"))
        print("%-28s centre (%.1f, %.1f) radius %.1f px fill %s measured %s residual %s" % (p.name, c.cx, c.cy, c.radius_px, c.fill, c.measured, c.residual_px))
    return 0


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    f = sub.add_parser("fit"); f.add_argument("pairs"); f.add_argument("--screen", required=True, choices=("ingame", "editor"))
    f.add_argument("--size", required=True, help="WxH of the screen the pixels were measured on")
    f.add_argument("--fill", default="longer_side", choices=("longer_side", "diagonal")); f.add_argument("--force", action="store_true")
    c = sub.add_parser("check"); c.add_argument("pairs"); c.add_argument("--screen", required=True); c.add_argument("--size", required=True)
    b = sub.add_parser("blobs"); b.add_argument("image"); b.add_argument("--box", required=True); b.add_argument("--colour", default=None)
    b.add_argument("--tol", type=int, default=40); b.add_argument("--top", type=int, default=12)
    sub.add_parser("show")
    a = ap.parse_args(argv)
    return {"fit": cmd_fit, "check": cmd_check, "blobs": cmd_blobs, "show": cmd_show}[a.cmd](a)


if __name__ == "__main__":
    sys.exit(main())
