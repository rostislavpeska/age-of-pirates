"""Out-centred city block workflow: detect -> build the verification set -> the user checks in game -> apply.

    python .claude/skills/grouping-centering/scripts/workflow.py scan     # the decision table; writes nothing
    python .claude/skills/grouping-centering/scripts/workflow.py build    # the verification set (below)
    python .claude/skills/grouping-centering/scripts/workflow.py status   # does the game need a restart?
    python .claude/skills/grouping-centering/scripts/workflow.py apply    # ONLY after the user approved in game

build writes
  <stem>_Centered.xml      every fixed grouping, in the repo AND the profile RandMaps/groupings (stale ones removed)
  000_zpblockfix.xs/.xml   PAIRS map (Steam Game/RandMaps): original LEFT, _Centered RIGHT, per fixed grouping
  000_zpblockset.xs/.xml   SET map: every city block as it will be after the change (fixed ones as _Centered)
  <review>/pairs_legend.png, set_legend.png, sheet.png, decisions.txt   (default sandbox/grouping-centering/review)
Both maps: flat Great Plains ground (great_plains\\ground1_gp, GreatPlains_Skirmish light, as vanilla
"great plains.xs") and at least GAP m between any two groupings - never side by side.

apply writes every fix INTO the original (repo + profile), deletes the _Centered copies and the pairs map, rebuilds
the set map from the fixed originals and rescans (must find nothing). Groupings load at game START only: every
build / apply ends with the restart check.
"""
from __future__ import annotations

import math
import re
import subprocess
import sys
from datetime import datetime
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, str(Path(__file__).resolve().parent))
import centering as cg  # noqa: E402

PROFILE = cg.REPO.parents[2]                                   # <profile>/mods/local/<mod>
PROFILE_G = PROFILE / "RandMaps" / "groupings"
STEAM_RM = Path(r"C:\Program Files (x86)\Steam\steamapps\common\AoE3DE\Game\RandMaps")
REVIEW = cg.REPO / "sandbox" / "grouping-centering" / "review"
PAIRS, SET = "000_zpblockfix", "000_zpblockset"
GAP = 20.0                  # minimum metres between ANY two groupings on both maps (user 2026-09-22)
COLUMN_GAP = 60.0
ROW_WIDTH = 520.0           # metres of blocks per row of the set map before wrapping
TERRAIN = "great_plains\\ground1_gp"
LIGHT = "GreatPlains_Skirmish"


# ------------------------------------------------------------------ geometry
def even(m):
    return 2.0 * math.ceil(m / 2.0 - 1e-9)


def size_m(text):
    hx, hz = cg.area(text)
    return 2.0 * hx, 2.0 * hz


def frac(axis, m):
    f = "rmXMetersToFraction" if axis == "x" else "rmZMetersToFraction"
    return f"0.5 + {f}({m:.1f})" if m >= 0 else f"0.5 - {f}({-m:.1f})"


def min_gap(boxes):
    """Smallest edge-to-edge distance between any two boxes (grouping, x, z, w, h, ...), metres."""
    best = float("inf")
    for i in range(len(boxes)):
        for j in range(i + 1, len(boxes)):
            a, b = boxes[i], boxes[j]
            gx = abs(a[1] - b[1]) - (a[3] + b[3]) / 2
            gz = abs(a[2] - b[2]) - (a[4] + b[4]) / 2
            best = min(best, max(gx, gz))
    return best


def pairs_layout(fixed):
    """Two columns of pairs, original LEFT / _Centered RIGHT; GAP within a pair and between rows."""
    half = (len(fixed) + 1) // 2
    cols = [fixed[:half], fixed[half:]]
    col_w = [max((2 * size_m(r[1])[0] + GAP for r in c), default=0.0) for c in cols]
    col_x = [-even(col_w[0] / 2 + COLUMN_GAP / 2), even(col_w[1] / 2 + COLUMN_GAP / 2)]
    total_h = max(sum(even(size_m(r[1])[1] + GAP) for r in c) for c in cols)
    boxes = []                                  # (grouping, x, z, w, h, label, fixed)
    for ci, c in enumerate(cols):
        z = even(total_h / 2)
        for stem, t, dx, dz, _ in c:
            w, h = size_m(t)
            rh = even(h + GAP); zc = even(z - rh / 2); z -= rh
            xo = even(w / 2 + GAP / 2)
            boxes.append((stem, col_x[ci] - xo, zc, w, h, f"{stem} ORIGINAL", False))
            boxes.append((f"{stem}_Centered", col_x[ci] + xo, zc, w, h, f"{stem} FIXED {dx:+d},{dz:+d}", True))
    return boxes, col_w[0] + col_w[1] + COLUMN_GAP, total_h


def city_blocks(groupings, fixed_stems):
    """Every city block: a family grouping with edge markers on two opposite sides, or one being fixed."""
    out = []
    for p in sorted(groupings.glob("*.xml")):
        s = p.stem
        if "_Centered" in s or "backup" in s.lower() or not s.startswith(cg.FAMILIES):
            continue
        t = cg.read(p)
        if s in fixed_stems or any(cg.offset(s, t, a)[0] is not None for a in (0, 1)):
            w, h = size_m(t)
            out.append((s, w, h, s in fixed_stems))
    return out


def set_layout(blocks):
    """Rows per family (EU, IT, IS), GAP between all blocks; centres on even metres."""
    placed, y = [], 0.0
    for fam in cg.FAMILIES:
        items = sorted([b for b in blocks if b[0].startswith(fam)], key=lambda b: (-b[2], -b[1], b[0]))
        x, row_h = 0.0, 0.0
        for stem, w, h, fixed in items:
            if x and x + w > ROW_WIDTH:
                y += row_h + GAP + 2; x, row_h = 0.0, 0.0
            placed.append([stem, x + w / 2, y + h / 2, w, h, fixed])
            x += w + GAP + 2; row_h = max(row_h, h)     # +2: snapping centres to even metres may take 1 m per side
        y += row_h + 2 * GAP
    tw = max(p[1] + p[3] / 2 for p in placed); th = y - 2 * GAP
    boxes = [(f"{s}_Centered" if f else s, even(x - tw / 2), even(th / 2 - z), w, h, s, f) for s, x, z, w, h, f in placed]
    return boxes, tw, th


# ------------------------------------------------------------------ outputs
def map_script(stem, head, size_x, size_z, boxes):
    """The RM script placing every box's grouping; spine as 000_unitbench.xs (without it generation crashes)."""
    groups = sorted({b[0] for b in boxes})
    var = {g: "g" + re.sub(r"\W", "", g) for g in groups}
    L = [f"// {stem} - GENERATED by .claude/skills/grouping-centering/scripts/workflow.py - do not edit."]
    L += [f"// {h}" for h in head]
    L += ["", 'include "mercenaries.xs";', 'include "ypAsianInclude.xs";', 'include "ypKOTHInclude.xs";', "",
          "void main(void)", "{", '   rmSetStatusText("", 0.01);', f"   rmSetMapSize({size_x}, {size_z});",
          "   rmSetSeaLevel(0.0);", f'   rmSetLightingSet("{LIGHT}");',
          f'   rmTerrainInitialize("{TERRAIN}", 1.0);',                 # one backslash, as vanilla "great plains.xs"
          '   rmSetMapType("greatPlains");', '   rmSetMapType("land");', '   rmSetMapType("grass");',
          "   chooseMercs();", '   rmDefineClass("player");', '   rmDefineClass("classBlock");', "",
          "   // players along the bottom edge, clear of the blocks",
          "   for(i=1; <= cNumberNonGaiaPlayers)", "   {", "      rmPlacePlayer(i, 0.1 + 0.1 * i, 0.03);", "   }",
          '   int tcID = rmCreateObjectDef("player TC");', '   rmAddObjectDefItem(tcID, "TownCenter", 1, 0.0);',
          "   rmSetObjectDefMinDistance(tcID, 0.0);", "   rmSetObjectDefMaxDistance(tcID, 0.0);",
          "   for(i=1; <= cNumberNonGaiaPlayers)", "   {",
          "      rmPlaceObjectDefAtLoc(tcID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));", "   }",
          '   rmSetStatusText("", 0.40);', ""]
    for g in groups:
        v = var[g]
        L += [f'   int {v} = rmCreateGrouping("{g}", "{g}");', f"   rmSetGroupingMinDistance({v}, 0.00);",
              f"   rmSetGroupingMaxDistance({v}, 0.50);", f'   rmAddGroupingToClass({v}, rmClassID("classBlock"));']
    L.append("")
    L += [f"   rmPlaceGroupingAtLoc({var[b[0]]}, 0, {frac('x', b[1])}, {frac('z', b[2])});" for b in boxes]
    L += ["", '   rmSetStatusText("", 1.0);', "}", ""]
    xml = ('<?xml version = "1.0" encoding = "UTF-8"?>\r\n'
           f'<mapinfo displayName = "{stem}" detailsText = "{head[0]}"\r\n'
           '    imagepath = "ui\\random_map\\great_plains\\great_plains_mini" cannotReplace = "" '
           'loadBackground = "ui\\random_map\\great_plains\\great_plains_map">\r\n'
           "   <loadss>ui\\random_map\\great_plains\\great_plains_ss_01</loadss>\r\n</mapinfo>\r\n")   # vanilla "great plains.xml"
    return "\r\n".join(L), xml


def write_map(stem, head, boxes, tw, th):
    size_x, size_z = int(even(tw + 120)), int(even(th + 160))
    xs, xml = map_script(stem, head, size_x, size_z, boxes)
    (STEAM_RM / f"{stem}.xs").write_bytes(xs.encode("utf-8"))
    (STEAM_RM / f"{stem}.xml").write_bytes(xml.encode("utf-8"))
    return size_x, size_z


def legend(boxes, tw, th, title, out, scale):
    W, H = int(tw * scale + 80), int(th * scale + 110)
    im = Image.new("RGB", (W, H), "white"); d = ImageDraw.Draw(im)
    try:
        font = ImageFont.truetype("arial.ttf", 10); big = ImageFont.truetype("arial.ttf", 14)
    except OSError:
        font = big = ImageFont.load_default()
    d.text((10, 8), title, fill="black", font=big)
    d.text((10, 28), "Top view: +x right, +z up. In game the camera looks from the SE corner (this picture turned 45 deg).",
           fill=(90, 90, 90), font=font)
    ox, oz = W / 2, 60 + th * scale / 2
    for g, x, z, w, h, label, fixed in boxes:
        x0, y0 = ox + (x - w / 2) * scale, oz - (z + h / 2) * scale
        x1, y1 = ox + (x + w / 2) * scale, oz - (z - h / 2) * scale
        d.rectangle([x0, y0, x1, y1], fill=(170, 225, 170) if fixed else (232, 232, 232), outline=(110, 110, 110))
        words, lines, cur = label.replace("_", " ").split(), [], ""
        maxc = max(6, int((x1 - x0) / 6))
        for wd in words:
            if cur and len(cur) + 1 + len(wd) > maxc:
                lines.append(cur); cur = wd
            else:
                cur = f"{cur} {wd}".strip()
        lines.append(cur)
        for i, ln in enumerate(lines[: max(1, int((y1 - y0 - 4) / 11))]):
            d.text((x0 + 3, y0 + 2 + 11 * i), ln, fill="black", font=font)
    im.save(out)


def sheet(fixed, out):
    """Top view of every pair: frame = real size, inner frame = edge band, red = poles, grey = other units."""
    S, PAD = 6.0, 34
    try:
        font = ImageFont.truetype("arial.ttf", 12)
    except OSError:
        font = ImageFont.load_default()

    def panel(text, title):
        hx, hz = cg.area(text)
        w, h = int(2 * hx * S + 2 * PAD), int(2 * hz * S + 2 * PAD + 20)
        im = Image.new("RGB", (w, h), "white"); d = ImageDraw.Draw(im)
        ox, oz = w / 2, 20 + PAD + hz * S
        P = lambda x, z: (ox + x * S, oz - z * S)
        d.text((6, 4), title, fill="black", font=font)
        d.rectangle([P(-hx, hz), P(hx, -hz)], outline=(120, 120, 120), width=2)
        d.rectangle([P(-hx + cg.BAND, hz - cg.BAND), P(hx - cg.BAND, -hz + cg.BAND)], outline=(215, 215, 215))
        cx, cz = P(0, 0)
        d.line([(cx - 6, cz), (cx + 6, cz)], fill="black"); d.line([(cx, cz - 6), (cx, cz + 6)], fill="black")
        for x, z, proto in cg.units(text):
            px, pz = P(x, z)
            r, col = (5, (220, 30, 30)) if proto == cg.POLE else (2, (150, 150, 150))
            d.ellipse([px - r, pz - r, px + r, pz + r], fill=col)
        return im
    rows = []
    for stem, t, dx, dz, why in fixed:
        a = panel(t, f"{stem}  ORIGINAL")
        b = panel(cg.shift_text(t, dx, dz), f"FIXED  {dx:+d} m x, {dz:+d} m z")
        row = Image.new("RGB", (a.width + b.width + 20, max(a.height, b.height) + 16), "white")
        row.paste(a, (0, 0)); row.paste(b, (a.width + 20, 0))
        ImageDraw.Draw(row).text((6, row.height - 15), why, fill=(90, 90, 90), font=font)
        rows.append(row)
    W = max(r.width for r in rows); H = sum(r.height + 10 for r in rows)
    im = Image.new("RGB", (W, H), "white"); y = 0
    for r in rows:
        im.paste(r, (0, y)); y += r.height + 10
    im.save(out)


def table(fixed):
    lines = [f"{len(fixed)} groupings to fix (whole metres, +1/+2 only):"]
    lines += [f"  {s:38} {dx:+d} m x, {dz:+d} m z   {why}" for s, _, dx, dz, why in fixed]
    return lines


# ------------------------------------------------------------------ status
def game_start():
    r = subprocess.run(["powershell", "-NoProfile", "-Command",
                        "(Get-Process AoE3DE_s -ErrorAction SilentlyContinue).StartTime.ToString('o')"],
                       capture_output=True, text=True)
    s = r.stdout.strip()
    return datetime.fromisoformat(s[:26]) if s else None


def status():
    newest = max((f.stat().st_mtime for f in PROFILE_G.glob("*.xml")), default=0)
    started = game_start()
    if not started:
        print("RESTART: the game is not running - the next start loads the current groupings.")
    elif started.timestamp() < newest:
        print(f"RESTART REQUIRED: the game started {started:%H:%M}, a grouping was deployed "
              f"{datetime.fromtimestamp(newest):%H:%M}. Generating now shows the OLD groupings.")
    else:
        print(f"OK: the game started {started:%H:%M}, after the last deploy - generate the maps.")


# ------------------------------------------------------------------ steps
def build():
    fixed = cg.groupings_to_fix()
    REVIEW.mkdir(parents=True, exist_ok=True)
    keep = {f"{r[0]}_Centered.xml" for r in fixed}
    for d in (cg.GROUPINGS, PROFILE_G):
        for f in d.glob("*_Centered.xml"):
            if f.name not in keep:
                f.unlink(); print(f"removed stale {f}")
    for stem, t, dx, dz, _ in fixed:
        data = cg.shift_text(t, dx, dz).encode("utf-8")
        for d in (cg.GROUPINGS, PROFILE_G):
            (d / f"{stem}_Centered.xml").write_bytes(data)
    (REVIEW / "decisions.txt").write_text("\n".join(table(fixed)) + "\n", encoding="utf-8")
    print("\n".join(table(fixed)))
    if fixed:
        pb, pw, ph = pairs_layout(fixed)
        sx, sz = write_map(PAIRS, [f"{len(fixed)} fixed groupings: original LEFT, _Centered RIGHT, {GAP:.0f} m apart.",
                                   "Which is where: sandbox/grouping-centering/review/pairs_legend.png"], pb, pw, ph)
        legend(pb, pw, ph, f"{PAIRS}: original (grey) LEFT, fixed (green) RIGHT", REVIEW / "pairs_legend.png", 2.2)
        sheet(fixed, REVIEW / "sheet.png")
        print(f"pairs map {PAIRS}: {len(pb)} placements, {sx} x {sz} m, min gap {min_gap(pb):.0f} m")
    sb, sw, sh = set_layout(city_blocks(cg.GROUPINGS, {r[0] for r in fixed}))
    sx, sz = write_map(SET, [f"All {len(sb)} city blocks as after the change ({len(fixed)} as _Centered), {GAP:.0f} m apart.",
                             "Which is where: sandbox/grouping-centering/review/set_legend.png"], sb, sw, sh)
    legend(sb, sw, sh, f"{SET}: every city block, green = placed as the fixed version", REVIEW / "set_legend.png", 1.6)
    print(f"set map {SET}: {len(sb)} blocks, {sx} x {sz} m, min gap {min_gap(sb):.0f} m | review files in {REVIEW}")
    status()


def apply():
    fixed = cg.groupings_to_fix()
    for stem, t, dx, dz, why in fixed:
        data = cg.shift_text(t, dx, dz).encode("utf-8")
        (cg.GROUPINGS / f"{stem}.xml").write_bytes(data)
        (PROFILE_G / f"{stem}.xml").write_bytes(data)
        print(f"applied {stem}: {dx:+d} m x, {dz:+d} m z (repo + profile)   [{why}]")
    for d in (cg.GROUPINGS, PROFILE_G):
        for f in d.glob("*_Centered.xml"):
            f.unlink(); print(f"removed {f}")
    for ext in (".xs", ".xml"):
        f = STEAM_RM / f"{PAIRS}{ext}"
        if f.is_file():
            f.unlink(); print(f"removed {f}")
    left = cg.groupings_to_fix()
    print("rescan: nothing left to fix" if not left else "STILL FLAGGED: " + ", ".join(r[0] for r in left))
    applied = {r[0] for r in fixed}
    sb, sw, sh = set_layout(city_blocks(cg.GROUPINGS, set()))
    write_map(SET, [f"All {len(sb)} city blocks after the change (fixes applied in place), {GAP:.0f} m apart.",
                    "Which is where: sandbox/grouping-centering/review/set_legend.png"], sb, sw, sh)
    REVIEW.mkdir(parents=True, exist_ok=True)
    sb = [(g, x, z, w, h, label, label in applied) for g, x, z, w, h, label, _ in sb]
    legend(sb, sw, sh, f"{SET}: every city block after the change (green = fixed in place)", REVIEW / "set_legend.png", 1.6)
    status()


def main(argv=None):
    cmd = (sys.argv[1:] if argv is None else argv or ["scan"])
    cmd = cmd[0] if cmd else "scan"
    if cmd == "scan":
        print("\n".join(table(cg.groupings_to_fix())))
    elif cmd == "build":
        build()
    elif cmd == "apply":
        apply()
    elif cmd == "status":
        status()
    else:
        print(__doc__); return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
