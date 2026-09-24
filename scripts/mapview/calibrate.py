"""Calibrate a screen's minimap: measure the drawn disc, then check it against icons at known world positions, or
against the map rectangle's long edges where no save exists.

    python scripts/mapview/calibrate.py disc  <screenshot.png> --screen editor|ingame [--box x0,y0,x1,y1]
    python scripts/mapview/calibrate.py check <pairs.json> --screen editor|ingame --screen-size 2560x1080
                                              [--map randmaps/zplondon.xs --players 4 [--teams 2]]
    python scripts/mapview/calibrate.py edges <screenshot.png> --screen editor|ingame --map zplondon --players 4
                                              [--teams 2]
    python scripts/mapview/calibrate.py stars <screenshot.png> --colour 0,0,255 [--colour 255,0,0 ...] [--box ...]
    python scripts/mapview/calibrate.py blobs <screenshot.png> --colour R,G,B [--box x0,y0,x1,y1] [--tol 0.08]
    python scripts/mapview/calibrate.py fit   <pairs.json> --screen editor|ingame --screen-size 2560x1080 [--force]
    python scripts/mapview/calibrate.py show
(--size is kept as an alias of --screen-size: the SCREEN's pixels, not the map's metres.)

The method (2026-09-24, replaces the icon fit as the primary route):
1. `disc` on a FULL-RESOLUTION screenshot with no dialog open: minimap_detect.measure_disc fits a circle to the
   ring's bright-gold line and reads the drawn rim (radius_px; the map's longer side touches it). The record is
   written with method 'disc', accepted true, checked false, the ring probes, signs +1/-1 (fitted on the Paris
   editor frame's explorer stars). Refused (exit 1, nothing written) when the ring is not found, its line / rim
   ratio is off, fewer than 4 probes are found or they cover fewer than 3 quadrants. Measured 2026-09-24: editor
   2560x1080 centre (2269.33, 920.33) rim 130.5 px on every editor frame on disk (2026-09-11..24: Paris, Florence,
   Versailles, Istanbul, London samples and the live London 4p frame; a partly covered one 130.47); in-match HUD
   (sandbox/census/tt_state0.png, 2026-08-15) centre (2399.32, 899.31) rim 147.0 px.
2. `check` with independent pairs IN METRES and their map size (in the file, per pair, or --map/--players, which
   reads the ENGINE size through mapinfo: rmSetMapSize rounded to whole 2 m tiles, London 4p 360 x 686): PASS when
   every pair is within 3 px; then the record stores checked true, the pairs and the worst error. FAIL prints every
   error and leaves checked false. A size that disagrees with the engine size by 0.5 m or more is refused (review F1:
   a wrong length shifts every pixel by a constant that a fit absorbs silently; the script's 685 is refused with a
   hint to 686). --map/--players/--teams that contradict the file's own map/players/teams are refused (review F6).
   Pairs that are the fitted points of an icon record are refused: not independent (review F8). A FAIL on a record
   that had passed before revokes it (checked false, the failing pairs stored).
3. Pairs for a check: `stars` finds each player's star, which marks the player's EXPLORER (not the start building:
   2026-09-24, see minimap_detect.player_star); read the explorers' world positions from the same save. Live London
   4p editor frame (2026-09-24 12:06) with its save: stars 0.75 / 1.22 / 0.80 / 0.81 px from the Explorers at
   360 x 686 m.
4. `edges`, the icon-free check for a NON-SQUARE map (a match has no save to census): the record and the engine map
   size predict the two long edges of the map rectangle; minimap_detect.first_black_along measures, on every sample
   2 px apart along the long axis, the first black pixel along the normal from the centre line. PASS when each
   side's median inset (model minus measured) is within 0.5-2.5 px and the two sides agree within 1.0 px (at the
   2560x1080 editor's rim, 130.5 px; edge_band scales all three with a larger rim, 2026-09-24): the drawn
   map ends 1-2 px inside the model edge (a darkening vignette), symmetrically, so a centre or scale error shows as
   a disagreement or an inset outside the band. The record then stores checked true with check_pairs entries of
   kind 'edge' (inset, samples, spread) and check_residual_px = half the side disagreement. Square maps (their
   edges touch the disc only at the midpoints) and maps whose long edges reach the rim everywhere are refused.
   Measured 2026-09-24 on the editor: London 4p live frame 1.31 / 1.31 px (101 samples a side, spread 0), Paris
   (gen_paris.png) 1.59 / 2.07 px (99 samples, spread 0.71) at the engine sizes; the 2-player size 646 m on the
   London frame reads 5.55 / 5.55 px and fails. (The main session's nearest-pixel scan with the script sizes read
   66.83 / 66.83 of 68.59 px on London and 70.19 / 70.69 of 71.94 px on Paris.) Whether the in-match minimap
   draws the outside black is NOT measured.
   ALONG the long axis (fix-round verify V1, 2026-09-24): the longer side spans the disc, so at both ends of the long axis
   the map must run up to the rim. The record's centre IS the ring's centre (disc), so what can go wrong is the map
   drawn off-centre inside the ring: then one end is cut by the rim and the other leaves a black cap before it.
   `edges` therefore also scans 6 rays near the long axis at each end for a black run inside the rim, and FAILS when
   one is found on half the rays or more. Resolution: a cap shorter than the black run (EDGE_BLACK_RUN px) is not
   seen, so along the axis the check bounds the offset only to about that. Measured 2026-09-24: no cap at either end
   on the London live frame (1 stray black icon on 1 of 6 rays) or on Paris.

pairs.json (metres; a size is required, per file or per pair):
    {"map": "zpparis", "players": 4, "teams": 2, "size_x_m": 654, "size_z_m": 360,
     "pairs": [{"what": "P1 Explorer", "x_m": 57, "z_m": 87, "px": 2220.5, "py": 1023.5}, ...]}
`fit` also takes fractions ({"fx", "fz", "px", "py"}) but then needs the size or an explicit "aspect" in the file.

`fit` (icons only, the fallback when the ring cannot be read): joint common-scale least squares, at least 3 pairs,
accepted when every pair is within 2 px; --force writes a failed fit with accepted false, which load_calibration
refuses. An icon record has no ring probes and no r_line_px, so camera.py refuses it (it needs both to verify an aim
and to park the mouse): icon records serve twin.py and diagnostics only (review F8). Records live in
scripts/mapview/cal/<screen>_<WxH>.json ($MAPVIEW_CAL_DIR overrides, for scratch runs).
"""
from __future__ import annotations

import argparse
import datetime
import json
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from scripts.mapview.transform import (ACCEPT_CHECK_PX, ACCEPT_FIT_PX, Calibration, aspect_of,  # noqa: E402
                                        cal_path, evaluate_pairs, fit_affine_diagnostic, fit_calibration,
                                        frac_to_minimap, list_calibrations, load_calibration)

SCREENS = ("ingame", "editor")
DISC_MAX_RMS_PX = 1.0          # the bright line's rms about its circle: 0.54-0.61 px on every frame measured 2026-09-24
DISC_MAX_SPREAD_PX = 3.0       # interquartile range of the per-ray rim: 0-1 px measured
DISC_MIN_PROBES = 4            # probes found on the bright line: 5-8 measured
DISC_MIN_QUADRANTS = 3         # quadrants (about the centre) the probes cover: 4 on the full frames, 3+ partly covered
SIZE_TOL_M = 0.5               # a pairs file's map size vs the engine size (whole 2 m tiles): under 1 m
EDGE_INSET_MIN_PX = 0.5        # edges: each side's median inset (model edge minus the first black pixel)...
EDGE_INSET_MAX_PX = 2.5        # ... within this band (measured 1.31 / 1.31 London 4p, 1.59 / 2.07 Paris, 2026-09-24)
EDGE_AGREE_PX = 1.0            # ... and the two sides within this of each other
EDGE_REF_RIM_PX = 130.5        # the rim those three were measured at (2560x1080 editor); edge_band scales above it
EDGE_MIN_SAMPLES = 10          # ... on at least this many samples per side, and half of the side's rays
EDGE_STEP_PX = 2.0             # samples along the long axis, every this many pixels
EDGE_SQUARE_MAX = 1.05         # longer / shorter side below this: square, the long edges touch the rim only
EDGE_BEFORE_PX, EDGE_AFTER_PX = 12.0, 8.0     # the search window along the normal about the model edge
END_OFFSETS_PX = (-8.0, -5.0, -2.0, 2.0, 5.0, 8.0)   # ends: rays this far across the long axis
END_BEFORE_PX, END_AFTER_PX = 12.0, -1.5     # ... searched from the rim - 12 px to the rim - 1.5 px


class PairsError(ValueError):
    pass


# ----------------------------------------------------------------------------- pairs files
def _num(d, key, where):
    try:
        v = float(d[key])
    except (KeyError, TypeError, ValueError):
        raise PairsError("%s: %r must be a number, got %r" % (where, key, d.get(key) if isinstance(d, dict) else d))
    if not math.isfinite(v):
        raise PairsError("%s: %r must be finite, got %r" % (where, key, v))
    return v


def _map_stem(ref) -> str:
    return Path(str(ref).replace(chr(92), "/")).stem.lower()


def _cli_agrees_with_file(d, map_arg=None, players_arg=None, teams_arg=None):
    """Review F6: a --map/--players/--teams that contradicts what the pairs file states is refused - a typo would
    otherwise re-size every pair and a failed check would revoke a good record."""
    if map_arg and d.get("map") and _map_stem(map_arg) != _map_stem(d["map"]):
        raise PairsError("--map %s contradicts the file's map %r - refuse" % (map_arg, d["map"]))
    for arg, key in ((players_arg, "players"), (teams_arg, "teams")):
        if arg is not None and d.get(key) is not None and int(arg) != int(d[key]):
            raise PairsError("--%s %d contradicts the file's %s %r - refuse" % (key, int(arg), key, d[key]))


def _map_size_or_none(d, map_arg=None, players_arg=None, teams_arg=None):
    """The ENGINE size (mapinfo.map_size: rmSetMapSize rounded to whole 2 m tiles) of the map named by --map (or the
    file's "map"), or None when no map is named. --map that cannot be read is an error; a file's map name that does
    not resolve to a script is only noted."""
    from scripts.mapview import mapinfo
    _cli_agrees_with_file(d, map_arg, players_arg, teams_arg)
    ref = map_arg or d.get("map")
    if not ref:
        return None, ""
    players = players_arg if players_arg is not None else d.get("players")
    teams = teams_arg if teams_arg is not None else d.get("teams", 2)
    if players is None:
        if map_arg:
            raise PairsError("--map needs --players (the size depends on the player count)")
        return None, "map %r named without players - size not cross-checked" % ref
    try:
        path = mapinfo.resolve_map(ref)
    except FileNotFoundError as e:
        if map_arg:
            raise PairsError(str(e))
        return None, "map %r not found as a script - size not cross-checked" % ref
    try:
        script = mapinfo.script_map_size(path, int(players), int(teams))
    except Exception as e:           # mapsim's ExtractError, a bad Scenario - never a silent default size
        raise PairsError("mapsim could not read the size of %s for %s players / %s teams: %s" % (path.name, players, teams, e))
    size = (mapinfo.engine_size_m(script[0]), mapinfo.engine_size_m(script[1]))
    note = "%s, %d players, %d teams: %gx%g m (engine, whole 2 m tiles; rmSetMapSize %gx%g)" % (
        path.name, int(players), int(teams), size[0], size[1], script[0], script[1])
    return size, note


def load_metre_pairs(path, map_arg=None, players_arg=None, teams_arg=None):
    """(document, pairs [{'what','x_m','z_m','size_x_m','size_z_m','px','py'}], note). Every pair needs a size:
    per pair, from the file, or from mapsim (--map/--players or the file's map + players). Sizes SIZE_TOL_M or more
    away from the engine size are refused."""
    d = json.loads(Path(path).read_text(encoding="utf-8"))
    if not isinstance(d, dict) or not isinstance(d.get("pairs"), list) or not d["pairs"]:
        raise PairsError("%s: needs a non-empty \"pairs\" list" % Path(path).name)
    mapsize, note = _map_size_or_none(d, map_arg, players_arg, teams_arg)
    file_size = None
    if d.get("size_x_m") is not None or d.get("size_z_m") is not None:
        file_size = (_num(d, "size_x_m", "file"), _num(d, "size_z_m", "file"))
    out = []
    for i, p in enumerate(d["pairs"]):
        where = "pair %d (%s)" % (i + 1, p.get("what", "") if isinstance(p, dict) else "")
        if not isinstance(p, dict) or "x_m" not in p or "z_m" not in p:
            raise PairsError("%s: check pairs must be in metres (x_m, z_m)" % where)
        if p.get("size_x_m") is not None or p.get("size_z_m") is not None:
            size = (_num(p, "size_x_m", where), _num(p, "size_z_m", where))
        elif file_size is not None:
            size = file_size
        elif mapsize is not None:
            size = mapsize
        else:
            raise PairsError("%s: no map size - give size_x_m/size_z_m in the file or --map/--players" % where)
        if size[0] <= 0 or size[1] <= 0:
            raise PairsError("%s: map size must be positive, got %r" % (where, size))
        if mapsize is not None and (abs(size[0] - mapsize[0]) >= SIZE_TOL_M or abs(size[1] - mapsize[1]) >= SIZE_TOL_M):
            from scripts.mapview import mapinfo
            hint = ""
            if (mapinfo.engine_size_m(size[0]), mapinfo.engine_size_m(size[1])) == tuple(mapsize):
                hint = " - that is rmSetMapSize's value; the engine builds whole 2 m tiles: use %gx%g" % mapsize
            raise PairsError("%s: size %gx%g disagrees with %s - refuse (a wrong size shifts every pixel)%s"
                             % (where, size[0], size[1], note, hint))
        out.append({"what": str(p.get("what", "")), "x_m": _num(p, "x_m", where), "z_m": _num(p, "z_m", where),
                    "size_x_m": size[0], "size_z_m": size[1], "px": _num(p, "px", where), "py": _num(p, "py", where)})
    return d, out, note


def load_pairs(path, map_arg=None, players_arg=None, teams_arg=None):
    """For `fit`: (document, [(fx, fz, px, py)], labels, aspect, points). Metre pairs go through load_metre_pairs
    (one size for all: a fit is one map); fraction pairs need the file's size or an explicit "aspect" (review F7:
    no silent aspect 1.0)."""
    d = json.loads(Path(path).read_text(encoding="utf-8"))
    raw = d.get("pairs") if isinstance(d, dict) else None
    if not isinstance(raw, list) or not raw:
        raise PairsError("%s: needs a non-empty \"pairs\" list" % Path(path).name)
    if all(isinstance(p, dict) and "x_m" in p for p in raw):
        d, rows, _ = load_metre_pairs(path, map_arg, players_arg, teams_arg)
        sizes = {(r["size_x_m"], r["size_z_m"]) for r in rows}
        if len(sizes) != 1:
            raise PairsError("fit pairs must come from one map size, got %s" % sorted(sizes))
        sx, sz = sizes.pop()
        pairs = [(r["x_m"] / sx, r["z_m"] / sz, r["px"], r["py"]) for r in rows]
        points = [dict(r, fx=f[0], fz=f[1]) for r, f in zip(rows, pairs)]
        return d, pairs, [r["what"] for r in rows], aspect_of(sx, sz), points
    if d.get("size_x_m") is not None and d.get("size_z_m") is not None:
        aspect = aspect_of(_num(d, "size_x_m", "file"), _num(d, "size_z_m", "file"))
    elif d.get("aspect") is not None:
        aspect = _num(d, "aspect", "file")
        if aspect <= 0:
            raise PairsError("aspect must be positive")
    else:
        raise PairsError("fraction pairs need size_x_m/size_z_m or an explicit \"aspect\" in the file")
    pairs, labels = [], []
    for i, p in enumerate(raw):
        where = "pair %d" % (i + 1)
        if not isinstance(p, dict) or "fx" not in p:
            raise PairsError("%s: mix of metre and fraction pairs" % where)
        pairs.append((_num(p, "fx", where), _num(p, "fz", where), _num(p, "px", where), _num(p, "py", where)))
        labels.append(str(p.get("what", "")))
    points = [{"what": lab, "fx": f[0], "fz": f[1], "px": f[2], "py": f[3]} for lab, f in zip(labels, pairs)]
    return d, pairs, labels, aspect, points


def _size(text):
    """--screen-size (alias --size): the SCREEN's pixels, WxH."""
    try:
        w, h = (int(x) for x in text.lower().split("x"))
    except ValueError:
        raise PairsError("--screen-size must be WxH pixels, e.g. 2560x1080, got %r" % text)
    return w, h


def _size_hint(w, h):
    """Review F7: camera.py's --size is the MAP size (360x686); here it is the screen's. Both numbers under 1200
    look like metres - said when no record is found for them."""
    if w < 1200 and h < 1200:
        return (" (%dx%d looks like a map size in metres: --screen-size is the screenshot's pixel size, e.g. "
                "2560x1080; the map size comes from the pairs file or --map/--players)" % (w, h))
    return ""


def _box(text):
    try:
        b = tuple(int(float(x)) for x in text.split(","))
    except ValueError:
        b = ()
    if len(b) != 4 or b[2] <= b[0] or b[3] <= b[1]:
        raise PairsError("--box must be x0,y0,x1,y1 with x1 > x0 and y1 > y0, got %r" % text)
    return b


def _colour(text):
    try:
        c = tuple(int(x) for x in text.split(","))
    except ValueError:
        c = ()
    if len(c) != 3 or not all(0 <= v <= 255 for v in c):
        raise PairsError("--colour must be R,G,B (0-255), got %r" % text)
    return c


# ----------------------------------------------------------------------------- disc
def record_from_disc(m, screen, width, height, offset=(0, 0), source=""):
    """A Calibration from a minimap_detect.DiscMeasurement; offset = the measured image's top-left in screen pixels
    (a crop), (0, 0) for a full screenshot."""
    ox, oy = offset
    return Calibration(
        screen=screen, width=int(width), height=int(height), cx=round(m.cx + ox, 2), cy=round(m.cy + oy, 2),
        radius_px=m.r_disc, fill="longer_side", sign_u=1, sign_v=-1, measured=True, method="disc",
        accepted=True, checked=False, r_line_px=m.r_line,
        probes=[{"x": p["x"] + ox, "y": p["y"] + oy, "rgb": list(p["rgb"])} for p in m.probes],
        note=("disc measured %s from %s (box %s): bright line %d px, rms %.3f px, %d rays, rim spread %.1f px, "
              "line / rim %.4f; signs +1/-1 as fitted on the Paris editor explorer stars 2026-09-24"
              % (datetime.date.today().isoformat(), source or "an image", list(m.box), m.n_line_px, m.rms_line_px,
                 m.n_rays, m.ray_spread_px, m.r_line / m.r_disc)))


def probe_quadrants(m) -> int:
    """How many quadrants about the disc centre the probes cover."""
    return len({(p["x"] >= m.cx, p["y"] >= m.cy) for p in m.probes})


def disc_gate(m, img=None):
    """Reasons to refuse a disc measurement (empty = accept): too few probes, probes bunched in fewer than
    DISC_MIN_QUADRANTS quadrants (a partly covered ring), a noisy line, a ragged rim, or a line / rim ratio off the
    ring's measured geometry (review F1; measure_disc already raises on it). The earlier 'probes fail on the same
    image' test could never fire - each probe stores the pixel it was read from (review F4) - and is gone; img is
    kept for callers."""
    from scripts.mapview import minimap_detect as MD
    why = []
    if len(m.probes) < DISC_MIN_PROBES:
        why.append("only %d probes on the bright line (need %d)" % (len(m.probes), DISC_MIN_PROBES))
    q = probe_quadrants(m)
    if q < DISC_MIN_QUADRANTS:
        why.append("the probes cover %d quadrant(s) of the ring (need %d)" % (q, DISC_MIN_QUADRANTS))
    ratio = m.r_line / m.r_disc if m.r_disc else float("inf")
    if abs(ratio - MD.RING_RATIO) > MD.RING_RATIO_TOL:
        why.append("bright line / rim %.4f, measured %.4f +- %.3f" % (ratio, MD.RING_RATIO, MD.RING_RATIO_TOL))
    if m.rms_line_px > DISC_MAX_RMS_PX:
        why.append("bright line rms %.2f px > %.1f" % (m.rms_line_px, DISC_MAX_RMS_PX))
    if m.ray_spread_px > DISC_MAX_SPREAD_PX:
        why.append("rim spread %.1f px > %.1f" % (m.ray_spread_px, DISC_MAX_SPREAD_PX))
    return why


def cmd_disc(a):
    from PIL import Image
    from scripts.mapview import minimap_detect as MD
    img = Image.open(a.image).convert("RGB")
    W, H = img.size
    box = _box(a.box) if a.box else None
    try:
        m = MD.measure_disc(img, box)
    except ValueError as e:
        print("REFUSED: %s - nothing written" % e)
        return 1
    why = disc_gate(m, img)
    print("disc: centre (%.2f, %.2f) rim %.2f px, bright line %.2f px (%d px, rms %.3f), %d rays spread %.1f, %d probes "
          "in %d quadrants" % (m.cx, m.cy, m.r_disc, m.r_line, m.n_line_px, m.rms_line_px, m.n_rays, m.ray_spread_px,
                               len(m.probes), probe_quadrants(m)))
    if why:
        print("REFUSED: %s - nothing written" % "; ".join(why))
        return 1
    cal = record_from_disc(m, a.screen, W, H, source=Path(a.image).name)
    old = cal.path()
    if old.is_file():
        prev = Calibration.from_json(old.read_text(encoding="utf-8"))
        print("replacing %s (method %r, checked %s): the new record is checked false until `check` passes"
              % (old.name, prev.method, prev.checked))
    p = cal.save()
    print("written %s (accepted, NOT checked: run `calibrate.py check` with pairs in metres, or `calibrate.py edges` "
          "on a non-square map)" % p)
    return 0


# ----------------------------------------------------------------------------- check
def _load_for_check(screen, w, h):
    try:
        return load_calibration(screen, w, h, require_checked=False)
    except FileNotFoundError as e:
        print("REFUSED: %s%s" % (e, _size_hint(w, h)))
    except ValueError as e:
        print("REFUSED: %s" % e)
    return None


def _fitted_on(cal, pairs):
    """The check pairs that are the record's own fitted points (same what and pixel): not independent (F8)."""
    same = []
    for p in pairs:
        for q in cal.points or []:
            if (str(q.get("what", "")) == p["what"] and abs(float(q.get("px", 1e9)) - p["px"]) < 0.01
                    and abs(float(q.get("py", 1e9)) - p["py"]) < 0.01):
                same.append(p["what"] or "(%g, %g)" % (p["px"], p["py"]))
                break
    return same


def _store_check(cal, ok, stored, residual, what):
    """PASS: checked true with these entries. FAIL: a record that had passed is revoked (checked false, the failing
    entries stored); a fresh one is left unwritten. Returns the exit code."""
    if not ok:
        if cal.checked:              # a failed check revokes an earlier pass: the record is not trusted any more
            cal.checked = False
            cal.check_pairs = stored
            cal.check_residual_px = round(residual, 3)
            print("REVOKED: %s was checked earlier; written with checked=false and these failing %s" % (cal.save(), what))
        else:
            print("nothing written: %s stays checked=false" % cal.path().name)
        return 1
    cal.checked = True
    cal.check_pairs = stored
    cal.check_residual_px = round(residual, 3)
    p = cal.save()
    print("written %s (checked, residual %.2f px)" % (p, residual))
    return 0


def cmd_check(a):
    w, h = _size(a.size)
    cal = _load_for_check(a.screen, w, h)
    if cal is None:
        return 1
    d, pairs, note = load_metre_pairs(a.pairs, a.map, a.players, a.teams)
    if note:
        print("map size: %s" % note)
    same = _fitted_on(cal, pairs)
    if same:
        print("REFUSED: %d pair(s) are the points this %r record was fitted on (%s) - a check needs independent pairs"
              % (len(same), cal.method, ", ".join(same[:4])))
        return 1
    worst, rows = evaluate_pairs(cal, pairs)
    for r in rows:
        print("  %-34s (%7.1f, %7.1f) m of %gx%g  measured (%7.1f, %7.1f) predicted (%7.1f, %7.1f) err %.2f px"
              % (r["what"][:34], r["x_m"], r["z_m"], r["size_x_m"], r["size_z_m"], r["px"], r["py"], r["qx"], r["qy"],
                 r["err_px"]))
    ok = worst <= ACCEPT_CHECK_PX
    print("check: %d pairs, worst %.2f px -> %s (limit %.1f px)" % (len(rows), worst, "PASS" if ok else "FAIL",
                                                                    ACCEPT_CHECK_PX))
    stored = [dict({k: r[k] for k in ("what", "x_m", "z_m", "size_x_m", "size_z_m", "px", "py", "err_px")},
                   kind="icon") for r in rows]
    return _store_check(cal, ok, stored, worst, "pairs")


# ----------------------------------------------------------------------------- edges (no save needed)
def long_edge_rays(cal, size_x_m, size_z_m, step_px=EDGE_STEP_PX, before=EDGE_BEFORE_PX, after=EDGE_AFTER_PX):
    """The two long edges of a non-square map as rays for minimap_detect.first_black_along:
    {side: {'what', 'model_px', 'rays': [(x0, y0, nx, ny, model_px)]}} with side 'a' (x = 0 or z = 0 m) and 'b'
    (x = size_x or z = size_z). Each ray starts on the map's long centre line, points along the normal to that
    side's edge, and is kept only when its whole search window (to model + after + the black run) stays 1.5 px
    inside the drawn rim. ValueError for a square map."""
    from scripts.mapview import minimap_detect as MD
    a = aspect_of(size_x_m, size_z_m)
    if max(a, 1.0 / a) < EDGE_SQUARE_MAX:
        raise ValueError("a square map (%gx%g m): its edges touch the disc only at their midpoints - no long edge to "
                         "measure; check it with icon pairs instead" % (size_x_m, size_z_m))
    long_px = 2.0 * cal.radius_px                      # the longer side spans the disc
    n = max(2, int(long_px / step_px))
    if a > 1:                                          # z is long: the long edges are x = 0 and x = size_x
        names = {"a": "long edge x=0 m", "b": "long edge x=%g m" % size_x_m}
        at = lambda t, s: frac_to_minimap(s, t, cal, a)                     # noqa: E731
    else:                                              # x is long: z = 0 and z = size_z
        names = {"a": "long edge z=0 m", "b": "long edge z=%g m" % size_z_m}
        at = lambda t, s: frac_to_minimap(t, s, cal, a)                     # noqa: E731
    out = {k: {"what": names[k], "model_px": None, "rays": []} for k in ("a", "b")}
    reach = after + MD.EDGE_BLACK_RUN + 1.5
    for i in range(n + 1):
        t = i / float(n)
        c = at(t, 0.5)
        for k, s in (("a", 0.0), ("b", 1.0)):
            e = at(t, s)
            half = math.hypot(e[0] - c[0], e[1] - c[1])
            nx, ny = (e[0] - c[0]) / half, (e[1] - c[1]) / half
            out[k]["model_px"] = half
            if math.hypot(e[0] + reach * nx - cal.cx, e[1] + reach * ny - cal.cy) > cal.radius_px:
                continue
            out[k]["rays"].append((c[0], c[1], nx, ny, half))
    return out


def measure_ends(img, cal, size_x_m, size_z_m):
    """The along-axis half of the edges check: at each end of the long axis, a black cap before the rim means the map is
    drawn off-centre inside the ring. Two check_pairs entries of kind 'end' (rays, black_rays, gap_px = the median
    cap length where one was found, resolution_px), each with ok; see the module docstring for the resolution."""
    from scripts.mapview import minimap_detect as MD
    a = aspect_of(size_x_m, size_z_m)
    at = (lambda t: frac_to_minimap(0.5, t, cal, a)) if a > 1 else (lambda t: frac_to_minimap(t, 0.5, cal, a))   # noqa: E731
    out = []
    for label, t in (("long-axis end %s=0" % ("z" if a > 1 else "x"), 0.0), ("long-axis end %s=max" % ("z" if a > 1 else "x"), 1.0)):
        e = at(t)
        L = math.hypot(e[0] - cal.cx, e[1] - cal.cy)
        ux, uy = (e[0] - cal.cx) / L, (e[1] - cal.cy) / L
        rays = []
        for o in END_OFFSETS_PX:
            dm = math.sqrt(max(cal.radius_px ** 2 - o * o, 1.0))
            rays.append((cal.cx - o * uy, cal.cy + o * ux, ux, uy, dm))
        hits = MD.first_black_along(img, rays, END_BEFORE_PX, END_AFTER_PX)
        gaps = sorted(r[4] - h for h, r in zip(hits, rays) if h is not None)
        black = len(gaps)
        entry = {"kind": "end", "what": label, "size_x_m": float(size_x_m), "size_z_m": float(size_z_m),
                 "rays": len(rays), "black_rays": black, "gap_px": round(gaps[len(gaps) // 2], 3) if gaps else 0.0,
                 "resolution_px": float(MD.EDGE_BLACK_RUN), "ok": black < 0.5 * len(rays)}
        out.append(entry)
    return out


def edge_band(rim_px):
    """(inset min, inset max, side agreement) in px for a disc of rim rim_px: the 2560x1080 editor band scaled by
    rim_px / EDGE_REF_RIM_PX, never tighter. The inset is drawn art (a darkening vignette) and grows with the UI:
    2026-09-24 on the 2880x1800 device, editor 2.32 / 2.38 px at rim 218.72 and match 3.45 / 3.52 px at rim 220.89
    (the fixed band failed the match, whose scale agreed with the explorer-checked editor record)."""
    k = max(1.0, float(rim_px) / EDGE_REF_RIM_PX)
    if k == 1.0:
        return EDGE_INSET_MIN_PX, EDGE_INSET_MAX_PX, EDGE_AGREE_PX
    return EDGE_INSET_MIN_PX * k, EDGE_INSET_MAX_PX * k, EDGE_AGREE_PX * k


def measure_edges(img, cal, size_x_m, size_z_m):
    """The edges check on one screenshot: {'sides': [entry a, entry b], 'agree_px', 'ok', 'why'}; each entry is a
    check_pairs record of kind 'edge' (inset_px = model minus the median measured distance, samples, spread_px =
    the interquartile range, model_px, measured_px, rays). ValueError when there is nothing to measure."""
    from scripts.mapview import minimap_detect as MD
    geo = long_edge_rays(cal, size_x_m, size_z_m)
    band_lo, band_hi, agree_max = edge_band(cal.radius_px)
    sides, why = [], []
    for k in ("a", "b"):
        g = geo[k]
        if len(g["rays"]) < EDGE_MIN_SAMPLES:
            raise ValueError("%s: only %d samples stay inside the rim (need %d) - the map's long edges reach the "
                             "rim; check it with icon pairs instead" % (g["what"], len(g["rays"]), EDGE_MIN_SAMPLES))
        hits = sorted(v for v in MD.first_black_along(img, g["rays"], EDGE_BEFORE_PX, EDGE_AFTER_PX) if v is not None)
        entry = {"kind": "edge", "what": g["what"], "size_x_m": float(size_x_m), "size_z_m": float(size_z_m),
                 "model_px": round(g["model_px"], 3), "rays": len(g["rays"]), "samples": len(hits),
                 "measured_px": None, "inset_px": None, "spread_px": None}
        if len(hits) < max(EDGE_MIN_SAMPLES, 0.5 * len(g["rays"])):
            why.append("%s: the map/black boundary was found on %d of %d samples - is the outside of the map drawn "
                       "black on this screen?" % (g["what"], len(hits), len(g["rays"])))
        if hits:
            med = hits[len(hits) // 2] if len(hits) % 2 else 0.5 * (hits[len(hits) // 2 - 1] + hits[len(hits) // 2])
            entry.update(measured_px=round(med, 3), inset_px=round(g["model_px"] - med, 3),
                         spread_px=round(hits[(3 * len(hits)) // 4] - hits[len(hits) // 4], 3))
            if not (band_lo <= entry["inset_px"] <= band_hi):
                why.append("%s: inset %.2f px outside %.2f-%.2f" % (g["what"], entry["inset_px"], band_lo, band_hi))
        sides.append(entry)
    agree = None
    if sides[0]["inset_px"] is not None and sides[1]["inset_px"] is not None:
        agree = abs(sides[0]["inset_px"] - sides[1]["inset_px"])
        if agree > agree_max:
            why.append("the two sides disagree by %.2f px (limit %.2f): the centre is off across the map" % (agree, agree_max))
    ends = measure_ends(img, cal, size_x_m, size_z_m)
    for e in ends:
        if not e["ok"]:
            why.append("%s: the map ends %.1f px short of the rim on %d of %d rays - drawn off-centre inside the ring "
                       "along its long axis" % (e["what"], e["gap_px"], e["black_rays"], e["rays"]))
    return {"sides": sides, "ends": ends, "agree_px": None if agree is None else round(agree, 3), "ok": not why,
            "why": why}


def cmd_edges(a):
    from PIL import Image
    from scripts.mapview import mapinfo
    from scripts.mapview import minimap_detect as MD
    img = Image.open(a.image).convert("RGB")
    W, H = img.size
    cal = _load_for_check(a.screen, W, H)
    if cal is None:
        return 1
    if cal.probes:
        ok, good, n = MD.probes_ok(img, cal.probes)
        if not ok:
            print("REFUSED: %d of %d ring probes match on %s - the minimap is not on screen or a dialog dims it"
                  % (good, n, Path(a.image).name))
            return 1
    try:
        path = mapinfo.resolve_map(a.map)
        script = mapinfo.script_map_size(path, int(a.players), int(a.teams))
    except Exception as e:           # a missing script, mapsim's ExtractError - never a silent default size
        raise PairsError("the map size of %s for %s players / %s teams: %s" % (a.map, a.players, a.teams, e))
    sx, sz = mapinfo.engine_size_m(script[0]), mapinfo.engine_size_m(script[1])
    print("map size: %s, %d players, %d teams: %gx%g m (engine; rmSetMapSize %gx%g)"
          % (path.name, a.players, a.teams, sx, sz, script[0], script[1]))
    res = measure_edges(img, cal, sx, sz)
    for s in res["sides"]:
        print("  %-24s model %6.2f px  measured %s  inset %s px  %d/%d samples  spread %s px"
              % (s["what"], s["model_px"], s["measured_px"], s["inset_px"], s["samples"], s["rays"], s["spread_px"]))
    for e in res["ends"]:
        print("  %-24s black cap before the rim on %d/%d rays%s" % (e["what"], e["black_rays"], e["rays"],
              " (median %.1f px)" % e["gap_px"] if e["black_rays"] else " (none: the map reaches the rim)"))
    for w in res["why"]:
        print("  - %s" % w)
    lo, hi, agree_max = edge_band(cal.radius_px)
    print("edges: agree %s px -> %s (insets %.2f-%.2f px, sides within %.2f px, rim %.2f px)"
          % (res["agree_px"], "PASS" if res["ok"] else "FAIL", lo, hi, agree_max, cal.radius_px))
    residual = (res["agree_px"] or 0.0) / 2.0          # the centre's offset across the map, the vignette cancelled
    return _store_check(cal, res["ok"], res["sides"] + res["ends"], residual, "edges")


# ----------------------------------------------------------------------------- fit (icons)
def cmd_fit(a):
    w, h = _size(a.size)
    d, pairs, labels, aspect, points = load_pairs(a.pairs, a.map, a.players, a.teams)
    if len(pairs) < 3:
        print("REFUSED: %d pairs - a fit needs at least 3 (4 for the affine diagnostic)" % len(pairs))
        return 1
    cal = fit_calibration(pairs, aspect, a.screen, w, h, fill=a.fill, points=points,
                          note="icon fit %s from %s (%s, aspect %.4f)" % (datetime.date.today().isoformat(),
                                                                          Path(a.pairs).name, d.get("map", "?"), aspect))
    print("fit: centre (%.2f, %.2f) radius %.2f px sign_u %d sign_v %d fill %s"
          % (cal.cx, cal.cy, cal.radius_px, cal.sign_u, cal.sign_v, cal.fill))
    for (fx, fz, px, py), lab in zip(pairs, labels):
        qx, qy = frac_to_minimap(fx, fz, cal, aspect)
        print("  %-34s measured (%7.1f, %7.1f) predicted (%7.1f, %7.1f) err %.2f px"
              % (lab[:34], px, py, qx, qy, math.hypot(qx - px, qy - py)))
    diag = fit_affine_diagnostic(pairs, aspect, cal.sign_u, cal.sign_v)
    print("free affine (after the fitted signs): scale u %.2f v %.2f px/unit, angle %.2f deg, skew %.2f deg, residual %s"
          % (diag["scale_u"], diag["scale_v"], diag["angle_deg"], diag["skew_deg"],
             "n/a (needs >= 4 pairs)" if diag["residual_px"] is None else "%.2f px" % diag["residual_px"]))
    if not cal.accepted and not a.force:
        print("REJECTED: worst residual %.2f px > %.1f - nothing written (measure again, or --force to keep an "
              "UNACCEPTED record)" % (cal.residual_px, ACCEPT_FIT_PX))
        return 1
    old = cal.path()
    if old.is_file() and not a.overwrite:
        prev = Calibration.from_json(old.read_text(encoding="utf-8"))
        if prev.accepted and (prev.method != "icons" or not cal.accepted):
            print("REFUSED: %s holds an accepted %r record - pass --overwrite to replace it with this %s icon fit"
                  % (old.name, prev.method, "accepted" if cal.accepted else "UNACCEPTED"))
            return 1
    if not cal.accepted:
        p = cal.save()
        print("written %s with accepted=false (residual %.2f px): load_calibration refuses it" % (p, cal.residual_px))
        return 1
    p = cal.save()
    print("written %s (accepted, residual %.2f px; NOT checked: run `check` with independent pairs)"
          % (p, cal.residual_px))
    return 0


# ----------------------------------------------------------------------------- image helpers
def _disc_for(img, box=None, quiet=False):
    from scripts.mapview import minimap_detect as MD
    try:
        return MD.measure_disc(img, box)
    except ValueError as e:
        if not quiet:
            print("warning: no minimap ring measured (%s)" % e, file=sys.stderr)
        return None


def cmd_stars(a):
    from PIL import Image
    from scripts.mapview import minimap_detect as MD
    img = Image.open(a.image).convert("RGB")
    m = _disc_for(img, _box(a.box) if a.box else None)
    if m is None:
        print("REFUSED: the stars are searched inside the measured disc")
        return 1
    print("disc: centre (%.2f, %.2f) rim %.2f px" % (m.cx, m.cy, m.r_disc))
    missing = 0
    for text in a.colour:
        col = _colour(text)
        cands = MD.star_candidates(img, col, m)
        star = MD.player_star(img, col, m)
        if star is None:
            missing += 1
            print("colour %-13s no star (best core %s)" % (text, cands[0] if cands else "none"))
        else:
            print("colour %-13s star at (%.2f, %.2f) score %.2f" % (text, star[0], star[1], cands[0]["score"]))
    return 1 if missing else 0


def cmd_blobs(a):
    from PIL import Image
    from scripts.mapview import minimap_detect as MD
    img = Image.open(a.image).convert("RGB")
    colour = _colour(a.colour)
    disc = None if a.no_disc else _disc_for(img)
    if a.box:
        box = _box(a.box)
    elif disc is not None:
        box = (int(disc.cx - disc.r_disc) - 1, int(disc.cy - disc.r_disc) - 1,
               int(disc.cx + disc.r_disc) + 2, int(disc.cy + disc.r_disc) + 2)
    else:
        print("REFUSED: no --box and no measured disc")
        return 1
    W, H = img.size
    clamped = (max(0, box[0]), max(0, box[1]), min(W, box[2]), min(H, box[3]))
    if clamped != tuple(box):
        print("warning: box %s clamped to the image: %s" % (list(box), list(clamped)), file=sys.stderr)
    found = MD.blobs(img, clamped, colour, a.tol, disc=disc)
    if not found:
        print("warning: zero blobs of colour %s (chroma tol %.2f) in box %s%s - a dialog, the wrong colour, or no "
              "such icon" % (colour, a.tol, list(clamped), " inside the disc" if disc else ""), file=sys.stderr)
    for cx, cy, n, rgb in found[:a.top]:
        print("blob at (%.2f, %.2f)  %4d px  rgb %s" % (cx, cy, n, rgb))
    return 0


def cmd_show(a):
    cals = list_calibrations()
    if not cals:
        print("no calibrations in %s - nothing is measured yet" % cal_path("x", 0, 0).parent)
    for p in cals:
        c = Calibration.from_json(p.read_text(encoding="utf-8"))
        print("%-28s %-5s centre (%.2f, %.2f) radius %.2f px accepted %s checked %s (worst %s px) fit residual %s"
              % (p.name, c.method or "?", c.cx, c.cy, c.radius_px, c.accepted, c.checked, c.check_residual_px,
                 c.residual_px))
    return 0


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("disc", help="measure the drawn disc on a full-resolution screenshot")
    s.add_argument("image"); s.add_argument("--screen", required=True, choices=SCREENS)
    s.add_argument("--box", default=None, help="x0,y0,x1,y1 to search for the ring (default: the bottom-right 700x500)")
    screen_help = "WxH pixels of the screen the pixels were measured on, e.g. 2560x1080 (not the map size)"
    c = sub.add_parser("check", help="independent pairs in metres against the stored record")
    c.add_argument("pairs"); c.add_argument("--screen", required=True, choices=SCREENS)
    c.add_argument("--screen-size", "--size", dest="size", required=True, help=screen_help)
    c.add_argument("--map", default=None, help="map script (path or name under randmaps/) for the size")
    c.add_argument("--players", type=int, default=None); c.add_argument("--teams", type=int, default=None)
    e = sub.add_parser("edges", help="icon-free check: the non-square map's long edges against the stored record")
    e.add_argument("image"); e.add_argument("--screen", required=True, choices=SCREENS)
    e.add_argument("--map", required=True, help="map script (path or name under randmaps/)")
    e.add_argument("--players", type=int, required=True); e.add_argument("--teams", type=int, default=2)
    f = sub.add_parser("fit", help="icon fit (fallback): joint least squares on >= 3 pairs")
    f.add_argument("pairs"); f.add_argument("--screen", required=True, choices=SCREENS)
    f.add_argument("--screen-size", "--size", dest="size", required=True, help=screen_help)
    f.add_argument("--fill", default="longer_side", choices=("longer_side", "diagonal"))
    f.add_argument("--map", default=None); f.add_argument("--players", type=int, default=None)
    f.add_argument("--teams", type=int, default=None)
    f.add_argument("--force", action="store_true", help="write a failed fit, with accepted=false")
    f.add_argument("--overwrite", action="store_true", help="replace an accepted disc record")
    t = sub.add_parser("stars", help="each player's star (= its Explorer) inside the measured disc")
    t.add_argument("image"); t.add_argument("--colour", action="append", required=True, help="R,G,B; repeat per player")
    t.add_argument("--box", default=None)
    b = sub.add_parser("blobs", help="8-connected chroma blobs of one colour inside the disc")
    b.add_argument("image"); b.add_argument("--colour", required=True, help="R,G,B of the player colour")
    b.add_argument("--box", default=None, help="x0,y0,x1,y1 (default: the measured disc's square)")
    b.add_argument("--tol", type=float, default=0.08, help="chroma tolerance per channel (r,g,b over their sum)")
    b.add_argument("--top", type=int, default=12); b.add_argument("--no-disc", action="store_true")
    sub.add_parser("show")
    a = ap.parse_args(argv)
    try:
        return {"disc": cmd_disc, "check": cmd_check, "edges": cmd_edges, "fit": cmd_fit, "stars": cmd_stars,
                "blobs": cmd_blobs, "show": cmd_show}[a.cmd](a)
    except ValueError as e:          # PairsError, a bad size or a degenerate fit: a message, never a traceback
        print("REFUSED: %s" % e)
        return 2
    except OSError as e:             # a missing / unreadable pairs file or screenshot (review F7)
        print("REFUSED: %s" % e)
        return 2


if __name__ == "__main__":
    sys.exit(main())
