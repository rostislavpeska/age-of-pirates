"""Detect and fix out-centred city block groupings (game/randmaps/groupings/*.xml). Standard library only.

An out-centred block has every unit displaced against its own painted ground; the cause is the Scenario Editor
re-export, which moves units by whole metres in the NEGATIVE direction (-1 m, sometimes on one axis only).
Rules established in game on 2026-09-22 (user-verified, see ../SKILL.md):

  area      the grouping's real rectangle, <width> x <height> tiles at 2 m, centred on the origin (0, 0)
  evidence  1. a TWIN - the EU_/IT_/IS_ version of the same lot - is the same design moved by a whole-metre
               vector; the twin further in -x/-z is the displaced one
            2. the EDGE POLES (PropsPoles within 3 m of a side; middle poles ignored): centre = midpoint of the
               mean pole on the low side and the mean pole on the high side
            3. city lots without poles on both sides: EVERY unit in the 3 m edge band, same midpoint
  fix       whole metres, +1 or +2 only (offset rounded half up); a positive offset (uneven poles), an offset
            under 0.5 m, or one beyond 2 m (a different layout) gets no fix
  apply     every unit's posx / posz moves; ground, heights, unit order and CRLF stay byte-identical

    python centering.py scan [--dir DIR]          # every grouping that needs a fix, with its evidence
"""
from __future__ import annotations

import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

SKILL = Path(__file__).resolve().parents[1]
REPO = SKILL.parents[2]                     # <repo>/.claude/skills/grouping-centering
GROUPINGS = REPO / "game" / "randmaps" / "groupings"

UNIT = re.compile(r'(<unit [^>]*?posx=")([-\d.]+)(" posz=")([-\d.]+)("[^>]*>)(\w+)(</unit>)')
POLE = "PropsPoles"
BAND = 3.0                                  # a unit within 3 m of a side belongs to that side
MIN_SHIFT, MAX_SHIFT = 1, 2                 # whole metres
TWIN_SHARE = 0.6                            # a twin shift counts when it explains >= 60 % of the units
FAMILIES = ("EU_", "IT_", "IS_")
CITY = ("Block", "SPC_Player")              # name parts of city lots: the edge-unit fallback applies to these
EXCLUDE = {"EU_SPC_Player_London"}          # user 2026-09-22: its -1 m "fix" was worse; never touched


def read(path: Path) -> str:
    return path.read_bytes().decode("utf-8", errors="replace")


def units(text: str):
    """[(x, z, proto)] in metres, file order."""
    return [(float(m.group(2)), float(m.group(4)), m.group(6)) for m in UNIT.finditer(text)]


def area(text: str):
    """(half_x, half_z) of the real rectangle in metres. Measured over every repo grouping: the painted tiles
    start at -size//2 (15 -> -7..7, 30 -> -15..14) and centred blocks have their edge poles centred on the
    origin (odd sizes -0.02 m over 168 axes, even -0.13 m over 25), so the rectangle is centred on (0, 0)."""
    w = re.search(r"<width>(\d+)</width>", text)
    h = re.search(r"<height>(\d+)</height>", text)
    return (float(w.group(1)) if w else 0.0), (float(h.group(1)) if h else 0.0)


def is_city(stem: str) -> bool:
    return stem.startswith(FAMILIES) and any(k in stem for k in CITY)


def edge_centre(text: str, axis: int, poles_only: bool):
    """Midpoint of the mean low-side and mean high-side edge unit on one axis (0 = x, 1 = z), relative to the
    area centre; None unless both sides have edge units."""
    half = area(text)[axis]
    vals = [u[axis] for u in units(text) if not poles_only or u[2] == POLE]
    low = [v for v in vals if v <= -half + BAND]
    high = [v for v in vals if v >= half - BAND]
    if not low or not high:
        return None
    return (sum(low) / len(low) + sum(high) / len(high)) / 2


def offset(stem: str, text: str, axis: int):
    """(offset, source) of one axis: edge poles on both sides, else (city lots only) any edge units."""
    c = edge_centre(text, axis, poles_only=True)
    if c is not None:
        return c, "poles"
    if is_city(stem):
        c = edge_centre(text, axis, poles_only=False)
        if c is not None:
            return c, "edge units"
    return None, "-"


def whole_metres(c) -> int:
    """The fix for offset c: +1 or +2 m (half up); 0 for None, a positive offset, < 0.5 m or > 2.5 m."""
    if c is None or c >= 0:
        return 0
    n = int(abs(c) + 0.5)
    return n if MIN_SHIFT <= n <= MAX_SHIFT else 0


def twin_shift(a, b):
    """Most common (dx, dz) mapping units of a onto units of b (same proto, order-independent) and its share."""
    by = defaultdict(list)
    for x, z, p in b:
        by[p].append((x, z))
    votes = Counter()
    for x, z, p in a:
        for bx, bz in by[p]:
            votes[(round(bx - x, 1), round(bz - z, 1))] += 1
    if not votes:
        return None, 0.0
    d, n = votes.most_common(1)[0]
    return d, n / max(len(a), len(b))


def twin_evidence(stem: str, text: str, groupings: Path = GROUPINGS):
    """(fix_dx, fix_dz, twin, share) when an EU_/IT_/IS_ twin is this block moved by a whole-metre vector and
    THIS block is the one further in -x/-z; else None."""
    if not stem.startswith(FAMILIES):
        return None
    me, best = units(text), None
    for fam in FAMILIES:
        other = fam + stem[3:]
        path = groupings / f"{other}.xml"
        if other == stem or not path.is_file():
            continue
        d, share = twin_shift(units(read(path)), me)
        if not d or share < TWIN_SHARE or d == (0.0, 0.0) or d[0] > 0 or d[1] > 0:
            continue
        fx, fz = whole_metres(d[0]), whole_metres(d[1])
        if (fx or fz) and (best is None or share > best[3]):
            best = (fx, fz, other, share)
    return best


def decide(stem: str, text: str, groupings: Path = GROUPINGS):
    """(dx, dz, evidence) for one grouping; (0, 0, why) when it needs no fix."""
    if stem in EXCLUDE:
        return 0, 0, "excluded (user)"
    tw = twin_evidence(stem, text, groupings)
    if tw:
        return tw[0], tw[1], f"twin {tw[2]} = this + ({tw[0]:+d}, {tw[1]:+d}) m, {tw[3]:.0%} of units"
    fix, why = [], []
    for axis in (0, 1):
        o, src = offset(stem, text, axis)
        fix.append(whole_metres(o))
        why.append(f"{'xz'[axis]} {src} {'-' if o is None else f'{o:+.2f}'}")
    return fix[0], fix[1], "; ".join(why)


def shift_text(text: str, dx: float, dz: float) -> str:
    """Every unit's posx / posz moved by (dx, dz); every other byte unchanged."""
    def rep(m):
        return (f"{m.group(1)}{float(m.group(2)) + dx:.4f}{m.group(3)}{float(m.group(4)) + dz:.4f}"
                f"{m.group(5)}{m.group(6)}{m.group(7)}")
    return UNIT.sub(rep, text)


def groupings_to_fix(groupings: Path = GROUPINGS):
    """[(stem, text, dx, dz, evidence)] for every grouping that needs a fix."""
    out = []
    for p in sorted(groupings.glob("*.xml")):
        if "_Centered" in p.stem or "backup" in p.stem.lower():
            continue
        t = read(p)
        dx, dz, why = decide(p.stem, t, groupings)
        if dx or dz:
            out.append((p.stem, t, dx, dz, why))
    return out


def main(argv=None) -> int:
    argv = sys.argv[1:] if argv is None else argv
    d = Path(argv[argv.index("--dir") + 1]) if "--dir" in argv else GROUPINGS
    rows = groupings_to_fix(d)
    print(f"{len(rows)} groupings to fix (whole metres, +1/+2 only):")
    for stem, _, dx, dz, why in rows:
        print(f"  {stem:38} {dx:+d} m x, {dz:+d} m z   {why}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
