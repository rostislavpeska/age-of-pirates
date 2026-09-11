"""Copy the zpHarbourPathBlock3 units from the donor grouping into the four
IS_Shore_Trade groupings, rigidly transformed into each one's own frame.

Method (no eyeballing anywhere):
  * The 8 zpHarbourPlatform units carry a unique `variation` id that appears in
    all five files, giving exact point correspondences donor -> target.
  * A 2D rigid fit (rotation + translation, Kabsch) is solved from those 8
    pairs. The rotation is snapped to an exact multiple of 90 deg when it is
    within tolerance, so no floating drift enters the written coordinates.
  * Every pathblock position AND its orientation vector go through that same
    transform, so each block keeps its exact offset from the harbour platforms
    and faces landward in whatever direction that grouping is rotated.
  * Verification: a rigid transform preserves distances, so the distance from
    each pathblock to each platform must be identical in donor and target.
    That invariant is asserted per file, per block.

New units are appended AFTER the last existing unit. The trailing unit in every
target is the baked Nugget the map targets via
rmGetGroupingInstanceUnitByType(...) + instanceIdShift, so appending leaves
every existing index untouched.

    python scripts/tools/place_pathblocks.py            # dry run
    python scripts/tools/place_pathblocks.py --apply    # write both copies
"""
from __future__ import annotations

import math
import re
import sys
from pathlib import Path

PROFILE = Path(r"C:/Users/rosti/Games/Age of Empires 3 DE/76561199512878537"
               r"/RandMaps/groupings")
REPO = Path(__file__).resolve().parents[2] / "game" / "randmaps" / "groupings"

DONOR = "Trade Grouping PathBlocks"
TARGETS = ["IS_Shore_Trade_01", "IS_Shore_Trade_02",
           "IS_Shore_Trade_03", "IS_Shore_Trade_04"]
BLOCK = "zpHarbourPathBlock3"
ANCHOR = "zpHarbourPlatform"

UNIT_RE = re.compile(
    r'<unit\s+variation="(?P<var>[^"]*)"\s+posx="(?P<px>[^"]*)"\s+posz="(?P<pz>[^"]*)"'
    r'\s+orientx="(?P<ox>[^"]*)"\s+orienty="(?P<oy>[^"]*)"\s+orientz="(?P<oz>[^"]*)"\s*>'
    r'(?P<name>[^<]*)</unit>')


def parse(path: Path):
    text = path.read_bytes().decode("utf-8")
    units = []
    for m in UNIT_RE.finditer(text):
        units.append(dict(var=m.group("var"),
                          x=float(m.group("px")), z=float(m.group("pz")),
                          ox=float(m.group("ox")), oy=float(m.group("oy")),
                          oz=float(m.group("oz")),
                          name=m.group("name")))
    return text, units


def rigid_fit(src, dst):
    """2D rotation+translation taking src points onto dst points (Kabsch)."""
    n = len(src)
    cs = (sum(p[0] for p in src) / n, sum(p[1] for p in src) / n)
    cd = (sum(p[0] for p in dst) / n, sum(p[1] for p in dst) / n)
    num = sum((s[0] - cs[0]) * (d[1] - cd[1]) - (s[1] - cs[1]) * (d[0] - cd[0])
              for s, d in zip(src, dst))
    den = sum((s[0] - cs[0]) * (d[0] - cd[0]) + (s[1] - cs[1]) * (d[1] - cd[1])
              for s, d in zip(src, dst))
    theta = math.atan2(num, den)
    # snap to an exact quarter turn when we are clearly at one
    deg = math.degrees(theta)
    snapped = round(deg / 90.0) * 90.0
    if abs(deg - snapped) < 0.01:
        theta = math.radians(snapped)
        deg = snapped
    c, s = math.cos(theta), math.sin(theta)
    # rotation applied as (x,z) -> (x*c - z*s, x*s + z*c); note the fit above
    # solves for the angle that maps src onto dst under exactly this form
    tx = cd[0] - (cs[0] * c - cs[1] * s)
    tz = cd[1] - (cs[0] * s + cs[1] * c)
    return theta, deg, tx, tz


def apply_xf(theta, tx, tz, x, z):
    c, s = math.cos(theta), math.sin(theta)
    return x * c - z * s + tx, x * s + z * c + tz


def rot_only(theta, x, z):
    c, s = math.cos(theta), math.sin(theta)
    return x * c - z * s, x * s + z * c


def fmt(v):
    out = "%.4f" % v
    return "0.0000" if out == "-0.0000" else out


def main(apply_changes: bool):
    dtext, dunits = parse(PROFILE / (DONOR + ".xml"))
    danchors = {u["var"]: u for u in dunits if u["name"] == ANCHOR}
    dblocks = [u for u in dunits if u["name"] == BLOCK]
    print("donor: %s  -> %d anchors, %d %s\n" % (DONOR, len(danchors), len(dblocks), BLOCK))

    for stem in TARGETS:
        tpath = PROFILE / (stem + ".xml")
        ttext, tunits = parse(tpath)
        tanchors = {u["var"]: u for u in tunits if u["name"] == ANCHOR}
        shared = sorted(set(danchors) & set(tanchors))
        assert len(shared) >= 3, "%s: only %d shared anchors" % (stem, len(shared))

        src = [(danchors[v]["x"], danchors[v]["z"]) for v in shared]
        dst = [(tanchors[v]["x"], tanchors[v]["z"]) for v in shared]
        theta, deg, tx, tz = rigid_fit(src, dst)

        resid = []
        for (sx, sz), (dx, dz) in zip(src, dst):
            px, pz = apply_xf(theta, tx, tz, sx, sz)
            resid.append(math.hypot(px - dx, pz - dz))
        rms = math.sqrt(sum(r * r for r in resid) / len(resid))

        print("%s   rotation %+7.2f deg   translation (%+8.4f, %+8.4f)"
              % (stem, deg, tx, tz))
        print("    anchors matched: %d   fit residual max %.6f m, rms %.6f m"
              % (len(shared), max(resid), rms))
        assert max(resid) < 1e-3, "%s: fit residual too large" % stem

        existing = [u for u in tunits if u["name"] == BLOCK]
        if existing:
            print("    SKIP - %d %s already present\n" % (len(existing), BLOCK))
            continue

        lines = []
        worst = 0.0
        for b in dblocks:
            nx, nz = apply_xf(theta, tx, tz, b["x"], b["z"])
            ox, oz = rot_only(theta, b["ox"], b["oz"])
            # distance-invariance proof against every anchor
            for v in shared:
                d0 = math.hypot(b["x"] - danchors[v]["x"], b["z"] - danchors[v]["z"])
                d1 = math.hypot(nx - tanchors[v]["x"], nz - tanchors[v]["z"])
                worst = max(worst, abs(d0 - d1))
                # 0.5 mm bound: the files store 4 decimals (0.1 mm), so an exact
                # quarter-turn cannot reproduce authored values any tighter
                assert abs(d0 - d1) < 5e-4, \
                    "%s: distance to anchor %s changed %.6f -> %.6f" % (stem, v, d0, d1)
            lines.append(
                '\t\t<unit variation="%s" posx="%s" posz="%s" orientx="%s" '
                'orienty="%s" orientz="%s">%s</unit>'
                % (b["var"], fmt(nx), fmt(nz), fmt(ox), fmt(b["oy"]), fmt(oz), BLOCK))
            print("      (%9.4f,%9.4f) o(%7.4f,%7.4f)  ->  (%9.4f,%9.4f) o(%7.4f,%7.4f)"
                  % (b["x"], b["z"], b["ox"], b["oz"], nx, nz, ox, oz))
        print("    distance-to-anchor invariance: OK for %d blocks x %d anchors, "
              "worst deviation %.6f m (%.3f mm)" % (len(dblocks), len(shared), worst, worst * 1000))

        if apply_changes:
            last = list(UNIT_RE.finditer(ttext))[-1]
            ins = "\r\n" + "\r\n".join(lines)
            new = ttext[:last.end()] + ins + ttext[last.end():]
            for base in (PROFILE, REPO):
                p = base / (stem + ".xml")
                p.write_bytes(new.encode("utf-8"))
            print("    WROTE %d units to profile + repo copies" % len(lines))
        print()


if __name__ == "__main__":
    main("--apply" in sys.argv)
