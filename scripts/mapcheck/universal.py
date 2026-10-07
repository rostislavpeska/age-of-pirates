"""The universal zero-config suite (plan Part F Tier S + Tier G, built in G2).

Every check cites its evidence (guide chapter or Part F failure class).
Static checks (S1-S5) consume the extraction and the filesystem only —
milliseconds, no matplotlib. Grid checks (G1-G5) consume the Layer-2
classified grid through TerrainGrid.class_code()/digest() plus the existing
mapsim verdict engine (scripts.mapsim.checks) — those carry basis="model".
"""

from __future__ import annotations

import json
import re
from collections import deque
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

from scripts.mapcheck.finding import Finding

REPO_ROOT = Path(__file__).resolve().parents[2]
IMAGES_ROOT = REPO_ROOT / "data" / "wpfg" / "resources" / "images"
GOLDENS_DIRS = (
    REPO_ROOT / "scripts" / "maps" / "goldens",
    REPO_ROOT / "scripts" / "mapsim" / "tests" / "goldens",
)

# G5 naval gate (v1 heuristic, basis=model): a map whose DEEP class covers
# more than this fraction is treated as a naval map — separated players are
# INFO (ships/transports assumed), not FAIL. A land map cut by a river band
# (a few percent DEEP) stays below it and separation is a real FAIL.
NAVAL_DEEP_FRACTION = 0.10


@dataclass
class RunResult:
    findings: List[Finding] = field(default_factory=list)
    ex: Any = None      # xs_extract.Extraction
    rs: Any = None      # scene.ResolvedScene
    tg: Any = None      # field.TerrainGrid
    ring: Any = None    # [(x_frac, z_frac)] nominal player anchors


# --------------------------------------------------------------------------
# source stripping: comments and string literals become spaces (newlines
# kept) so regex positions and line numbers stay true. The Arsenal lesson
# from G1: grep sees commented-out code, a checker must not.
# --------------------------------------------------------------------------

def _strip(src: str, keep_strings: bool = False) -> str:
    """Comments (and, unless keep_strings, string contents) blanked to spaces; offsets and line numbers kept."""
    out: List[str] = []
    i, n = 0, len(src)
    mode = ""  # "" | line | block | str
    while i < n:
        c = src[i]
        if mode == "":
            if c == "/" and i + 1 < n and src[i + 1] == "/":
                mode = "line"; out.append("  "); i += 2; continue
            if c == "/" and i + 1 < n and src[i + 1] == "*":
                mode = "block"; out.append("  "); i += 2; continue
            if c == '"':
                mode = "str"; out.append('"' if keep_strings else " "); i += 1; continue
            out.append(c); i += 1
        elif mode == "line":
            if c == "\n":
                mode = ""
            out.append("\n" if c == "\n" else " "); i += 1
        elif mode == "block":
            if c == "*" and i + 1 < n and src[i + 1] == "/":
                mode = ""; out.append("  "); i += 2; continue
            out.append("\n" if c == "\n" else " "); i += 1
        else:  # str
            if c == '"':
                mode = ""
            out.append(c if keep_strings else " "); i += 1
    return "".join(out)


def _line_of(src: str, offset: int) -> int:
    return src.count("\n", 0, offset) + 1


# --------------------------------------------------------------------------
# S2: duplicate declaration in the SAME block (guide 21.1:10469, crash
# class). Precise block identity via a brace-id stack; declarations inside
# parentheses (for-headers, parameter defaults) are excluded, and sibling
# blocks may legally redeclare — only a true same-block duplicate fires.
# Define-before-use is NOT attempted (deferred, plan G7): without a full
# scope/param model it false-positives, and the extractor's own warnings
# already surface unknown identifiers.
# --------------------------------------------------------------------------

_DECL_RE = re.compile(r"\b(int|float|bool|string|vector)\s+([A-Za-z_]\w*)\s*=")


def _duplicate_declarations(stripped: str) -> List[Tuple[str, int, int]]:
    decls = [(m.start(2), m.group(2)) for m in _DECL_RE.finditer(stripped)]
    if not decls:
        return []
    out: List[Tuple[str, int, int]] = []
    # (block_id, name) -> line. Names are case-sensitive: zplondon.xs declares rampSteps and rampStepS side by side
    # (since 9c11b233, 2026-09-24) and compiles in game; a lower-cased key made that a false FAIL (2026-10-06)
    seen: Dict[Tuple[int, str], int] = {}
    block_stack = [0]
    next_id = 1
    paren = 0
    di = 0
    for off, ch in enumerate(stripped):
        while di < len(decls) and decls[di][0] == off:
            name = decls[di][1]
            if paren == 0:
                key = (block_stack[-1], name)
                line = _line_of(stripped, off)
                if key in seen:
                    out.append((name, line, seen[key]))
                else:
                    seen[key] = line
            di += 1
        if ch == "(":
            paren += 1
        elif ch == ")":
            paren = max(0, paren - 1)
        elif ch == "{":
            block_stack.append(next_id)
            next_id += 1
        elif ch == "}" and len(block_stack) > 1:
            block_stack.pop()
    return out


# --------------------------------------------------------------------------
# static tier
# --------------------------------------------------------------------------

def _is_tainted(v: Any) -> bool:
    from scripts.mapsim.xs_extract import Tainted
    return isinstance(v, Tainted)


def static_checks(path: Path, scenario) -> RunResult:
    from scripts.mapsim.xs_extract import extract
    from scripts.refdata import catalog

    res = RunResult()
    stem = path.stem
    F = res.findings.append

    src = path.read_text(encoding="utf-8", errors="replace")
    stripped = _strip(src)

    # S1 — the script extracts (crash class 1, guide 21.1)
    try:
        ex = extract(path, scenario)
    except Exception as e:  # noqa: BLE001 — any parse/eval failure IS the finding
        F(Finding("S1", "FAIL", "deterministic",
                  f"script fails to parse/extract: {e}", map=stem,
                  guide_ref="guide 21.1"))
        return res
    res.ex = ex
    for w in ex.warnings:
        F(Finding("S1", "INFO", "deterministic", f"extractor warning: {w}",
                  map=stem, guide_ref="guide 21.1"))

    # S2 — duplicate declaration, same block (crash class, guide 21.1:10469)
    for name, line, first in _duplicate_declarations(stripped):
        F(Finding("S2", "FAIL", "deterministic",
                  f"variable {name!r} declared twice in the same block "
                  f"(first at line {first}) — XS compile error",
                  map=stem, line=line, guide_ref="guide 21.1:10469"))

    # S3 — terrain initialization (crash class, guide 21.1:10508) and
    # water-base call order (community: AOE_Fan tutorial)
    from scripts.mapsim.waterdata import is_water_type_name
    if ex.terrain_init is None:
        F(Finding("S3", "FAIL", "deterministic",
                  "no rmTerrainInitialize call — documented crash cause",
                  map=stem, guide_ref="guide 21.1:10508"))
    elif is_water_type_name(str(ex.terrain_init)):
        m_init = re.search(r"\brmTerrainInitialize\s*\(", stripped)
        m_sea = re.search(r"\brmSetSeaType\s*\(", stripped)
        if m_sea is None:
            F(Finding("S3", "WARN", "deterministic",
                      "water base without rmSetSeaType — engine default sea "
                      "type applies", map=stem,
                      guide_ref="AOE_Fan tutorial"))
        elif m_init and m_sea.start() > m_init.start():
            F(Finding("S3", "WARN", "deterministic",
                      "rmSetSeaType called AFTER the flooded "
                      "rmTerrainInitialize — community guidance orders it "
                      "before", map=stem,
                      line=_line_of(stripped, m_sea.start()),
                      guide_ref="AOE_Fan tutorial"))
    if ex.map_size_x is None:
        F(Finding("S3", "FAIL", "deterministic",
                  "no rmSetMapSize call — map has no dimensions", map=stem,
                  guide_ref="guide ch.7"))

    # S4 — every name resolves in the layered catalogs (silent no-spawn
    # class 3, guide 21.2). One finding per distinct name.
    water_cat = catalog("water")
    proto_cat = catalog("proto")
    group_cat = catalog("grouping")

    water_refs: Dict[str, int] = {}
    if ex.sea_type and not _is_tainted(ex.sea_type):
        water_refs.setdefault(str(ex.sea_type), 0)
    for a in ex.areas.values():
        if a.water_type and not _is_tainted(a.water_type):
            water_refs.setdefault(str(a.water_type), a.line)
    for r in ex.rivers.values():
        if r.water_type and not _is_tainted(r.water_type):
            water_refs.setdefault(str(r.water_type), r.line)
    for name, line in sorted(water_refs.items()):
        if not water_cat.has(name):
            sug = water_cat.suggest(name)
            F(Finding("S4", "FAIL", "deterministic",
                      f"unknown water type {name!r}"
                      + (f" — did you mean {sug[0]!r}?" if sug else ""),
                      map=stem, line=line or None,
                      guide_ref="guide 21.2:10738"))

    proto_refs: Dict[str, int] = {}
    grouping_refs: Dict[str, int] = {}
    for d in ex.defs.values():
        if d.is_grouping:
            if isinstance(d.proto, str) and d.proto:
                grouping_refs.setdefault(d.proto, d.line)
            else:
                # runtime concat with a literal prefix ("maori_hawaii_0"+
                # rand): the prefix must still resolve to >=1 variant file
                pref = getattr(d.proto, "str_prefix", None)
                if pref:
                    grouping_refs.setdefault(pref, d.line)
            continue
        for proto, _cnt in d.items:
            if isinstance(proto, str) and proto:
                proto_refs.setdefault(proto, d.line)
    for name, line in sorted(proto_refs.items()):
        if not proto_cat.has(name):
            sug = proto_cat.suggest(name)
            F(Finding("S4", "FAIL", "deterministic",
                      f"unknown proto {name!r}"
                      + (f" — did you mean {sug[0]!r}?" if sug else "")
                      + " — object will not spawn",
                      map=stem, line=line, guide_ref="guide 21.2:10843"))
    # Trade route types: rmBuildTradeRoute's second argument must be a <route> record in the mod's
    # data/traderoutedefs.xml (the mod overrides the whole file). An unknown name is NOT an error in
    # the engine: it silently builds the base route (Cold War "arctic1" hunt, 2026-09-10).
    route_names = _traderoute_names()
    if route_names:
        for _h, rtype in sorted(getattr(ex, "route_types", {}).items(), key=lambda kv: str(kv[0])):
            if isinstance(rtype, str) and rtype and rtype not in route_names:
                close = [n for n in route_names if rtype.lower() in n.lower() or n.lower() in rtype.lower()]
                F(Finding("S4", "FAIL", "deterministic",
                          f"unknown trade route type {rtype!r} — engine silently falls back to the base route"
                          + (f" — did you mean {close[0]!r}?" if close else ""),
                          map=stem))
    for ref, line in sorted(grouping_refs.items()):
        if any(c in ref for c in ("/", "\\", ":")):
            F(Finding("S4", "FAIL", "deterministic",
                      f"grouping reference is a machine-local path "
                      f"({ref!r}) — resolves on the author's disk only",
                      map=stem, line=line, guide_ref="guide 21.2:10867"))
        elif not group_cat.resolve(ref):
            sug = group_cat.suggest(ref)
            F(Finding("S4", "FAIL", "deterministic",
                      f"grouping {ref!r} matches no file (exact or "
                      f"prefix-variant)"
                      + (f" — did you mean {sug[0]!r}?" if sug else ""),
                      map=stem, line=line, guide_ref="guide 21.2:10867"))

    # S5 — companion files (guide ch.10 / 21.6; Steam RMS intro: custom maps
    # need .xml + .xs)
    xml_path = path.with_suffix(".xml")
    if not xml_path.is_file():
        F(Finding("S5", "FAIL", "deterministic",
                  f"no companion {xml_path.name} next to the script — the "
                  "map cannot appear in the lobby", map=stem,
                  guide_ref="guide ch.10"))
    else:
        try:
            import xml.etree.ElementTree as ET
            root = ET.parse(xml_path).getroot()
        except ET.ParseError as e:
            F(Finding("S5", "FAIL", "deterministic",
                      f"{xml_path.name} is not valid XML: {e}", map=stem,
                      guide_ref="guide ch.10"))
            root = None
        if root is not None:
            refs = []
            for attr in ("imagepath", "loadBackground"):
                v = root.get(attr)
                if v:
                    refs.append((attr, v))
            refs += [("loadss", el.text.strip())
                     for el in root.findall("loadss") if el.text]
            for what, ref in refs:
                if not _image_exists(ref):
                    F(Finding("S5", "WARN", "deterministic",
                              f"{what} {ref!r}: no matching .png under the "
                              "mod images tree (vanilla asset, or a broken "
                              "reference)", map=stem,
                              guide_ref="guide ch.10"))

    # S7 — map-edge constraints on scattered objects (rm-objects-herds "Map-edge constraints"; owner 2026-10-06:
    # treasures and mines landed outside the playable circle on the Danube, whose objects carried King of Bohemia's
    # BOX edge on a square map). A constraint tests the object's centre only, and rmSetWorldCircleConstraint does not
    # keep a searched object inside the circle. Square map: a full circle (pie centred 0.5/0.5, radius at least a few
    # metres inside the rim). Rectangular map: that circle AND a box. The maps that already lacked them on 2026-10-06
    # are baselined (s7_edge_baseline.json): up to their count the findings are WARN, so the legacy roster stays
    # readable; a new map, or a baselined map whose count grows, FAILs.
    edge = _edge_constraint_findings(ex, stem)
    allowed = _edge_baseline().get(stem.lower(), 0)
    for f in edge:
        if len(edge) <= allowed:
            f = Finding("S7", "WARN", f.basis, f"[legacy, baselined 2026-10-06: fix when the map is next touched] "
                        f"{f.message}", map=f.map, line=f.line, guide_ref=f.guide_ref)
        F(f)

    # S8 / S9 — build order and route read-backs (Danube v9, 2026-10-07: "you build trade route after the bridges";
    # its river drawn through rmGetTradeRouteWayPoint reads ran to the map corner and 15% of the map stayed water)
    for f in _build_order_findings(src, ex, stem):
        F(f)
    # S10 — a placement section of no length places nobody (Danube v12 1v1 / 2v1, 2026-10-07)
    for f in _placement_findings(ex, stem):
        F(f)
    return res


def _placement_findings(ex, stem: str) -> List[Finding]:
    """S10: rmPlacePlayersCircular on a placement section of no length (start == end, as the extractor evaluated it
    for this scenario). The engine places nobody there: Danube v12 gave a lone player the section (c, c) and the
    editor saves of 1v1 and 2v1 had no Town Center for the lone players. A lone player stands at his section's START,
    so the section still needs a length."""
    out: List[Finding] = []
    for ev in ex.player_events:
        sec = ev.get("section")
        if ev.get("call") != "rmPlacePlayersCircular" or not sec:
            continue
        if not all(isinstance(v, (int, float)) and not isinstance(v, bool) for v in sec[:2]):
            continue
        s0, s1 = float(sec[0]), float(sec[1])
        if abs(s1 - s0) < 1e-9:
            out.append(Finding("S10", "FAIL", "deterministic",
                               f"rmPlacePlayersCircular on the placement section ({s0:.3f}, {s1:.3f}) of no length "
                               f"(placement team {ev.get('team')}): the engine places nobody there - give a lone "
                               f"player's section a length, he stands at its start", map=stem))
    return out


WATER_ROUTE_MARKERS = ("river_trail", "water_trail")   # route types boats use; every other type is a land route


def _build_order_findings(src: str, ex, stem: str) -> List[Finding]:
    """S8: a LAND trade route built after a bridge grouping is placed (every repo map but Danube v9 builds its land
    routes first - Florence 477 / 522, London 743 / 810, Paris 350 / 413; a bridge goes onto a finished road). S9: an
    rmGetTradeRouteWayPoint read at a route end (fraction <= 0 or >= 1, as the extractor evaluated it): the engine
    returned the map origin there. Pure function of the RAW source (grouping files and route types are strings, which
    _strip blanks), so tests can call it on fixtures."""
    out: List[Finding] = []
    stripped = _strip(src, keep_strings=True)
    bridge_vars = set(re.findall(r'(\w+)\s*=\s*rmCreateGrouping\(\s*[^,]+,\s*"[^"]*bridge[^"]*"', stripped,
                                 flags=re.IGNORECASE))
    first_bridge = None
    for v in bridge_vars:
        m = re.search(r'rmPlaceGrouping\w*\(\s*%s\b' % re.escape(v), stripped)
        if m and (first_bridge is None or m.start() < first_bridge):
            first_bridge = m.start()
    if first_bridge is not None:
        for m in re.finditer(r'rmBuildTradeRoute\(\s*(\w+)\s*,\s*"([^"]+)"\s*\)', stripped):
            kind = m.group(2).lower()
            if any(w in kind for w in WATER_ROUTE_MARKERS):
                continue
            if m.start() > first_bridge:
                out.append(Finding(
                    "S8", "FAIL", "deterministic",
                    f"land trade route {m.group(1)!r} ({m.group(2)}) is built after the first bridge grouping is placed "
                    f"(line {_line_of(stripped, first_bridge)}): build the land route first, then put the bridges on it",
                    map=stem, line=_line_of(stripped, m.start()), guide_ref="rm-trade-routes: build order"))
    lines = stripped.split("\n")
    for line, handle, frac in getattr(ex, "route_end_reads", []) or []:
        # an initializer overwritten before anything reads it is harmless (zpkingofbohemia.xs 738:
        # `vector socketLoc2 = rmGetTradeRouteWayPoint(tradeRouteID, 0.0);`, reassigned at 0.12 before its first use)
        text = lines[line - 1] if 0 < line <= len(lines) else ""
        dm = re.search(r'\bvector\s+(\w+)\s*=\s*rmGetTradeRouteWayPoint', text)
        if dm:
            after = "\n".join(lines[line:])
            nxt = re.search(r'\b%s\b(\s*=(?!=))?' % re.escape(dm.group(1)), after)
            if nxt and nxt.group(1):
                continue
        out.append(Finding(
            "S9", "FAIL", "deterministic",
            f"rmGetTradeRouteWayPoint at a route end (fraction {frac:g}): the engine returned the map origin there "
            f"(Danube 2026-10-07); read interior fractions only, and draw geometry from the authored waypoints",
            map=stem, line=line, guide_ref="rm-trade-routes: route read-backs"))
    return out


EDGE_SEARCH_MIN_M = 40.0      # a placement searching further than this from its anchor is a scatter
EDGE_RIM_MARGIN_M = 4.0       # the circle's radius must sit at least this far inside the half map size
EDGE_BASELINE = Path(__file__).resolve().parent / "s7_edge_baseline.json"


def _edge_baseline() -> Dict[str, int]:
    """S7 findings per map stem (lower case) on 2026-10-06; tests/test_edge_constraints.py ratchets them down."""
    try:
        counts = json.loads(EDGE_BASELINE.read_text(encoding="utf-8"))["counts"]
    except (OSError, ValueError, KeyError):
        return {}
    out: Dict[str, int] = {}
    for k, v in counts.items():
        stem = Path(k).stem.lower()
        out[stem] = max(out.get(stem, 0), int(v))
    return out


def _edge_constraint_findings(ex, stem: str) -> List[Finding]:
    """S7: every scattered object def (placed in an area, or searched more than EDGE_SEARCH_MIN_M from its anchor;
    route-docked sockets and groupings excluded) carries a circle edge constraint, and a box as well on a rectangular
    map. Pure function of the extraction, so tests can call it on fixtures."""
    out: List[Finding] = []
    sx, sz = ex.map_size_x, ex.map_size_z
    if not isinstance(sx, (int, float)) or not isinstance(sz, (int, float)):
        return out
    square = abs(float(sx) - float(sz)) < 1.0
    half_min = min(float(sx), float(sz)) / 2.0
    half_diag = (float(sx) ** 2 + float(sz) ** 2) ** 0.5 / 2.0

    def is_circle(spec) -> bool:
        if spec.get("kind") != "pie":
            return False
        c = spec.get("center") or [None, None]
        r = spec.get("r_max_m")
        if not all(isinstance(v, (int, float)) for v in (c[0], c[1], r)):
            return False
        if abs(float(c[0]) - 0.5) > 0.01 or abs(float(c[1]) - 0.5) > 0.01:
            return False
        rim = half_min if square else half_diag
        return float(r) <= rim - EDGE_RIM_MARGIN_M

    def is_box(spec) -> bool:
        if spec.get("kind") != "box":
            return False
        b = spec.get("box") or []
        if len(b) < 4 or not all(isinstance(v, (int, float)) for v in b[:4]):
            return False
        x0, z0, x1, z1 = (float(v) for v in b[:4])
        return min(x0, z0) > 0.0 and max(x1, z1) < 1.0

    scattered: Dict[int, Tuple[Any, int]] = {}
    for p in ex.placements:
        if p.def_handle is None or not p.nominal:
            continue
        d = ex.defs.get(p.def_handle)
        if d is None or d.is_grouping or d.route_docked:
            continue
        search = d.max_dist if isinstance(d.max_dist, (int, float)) else 0.0
        if p.kind == "in_area" or float(search) >= EDGE_SEARCH_MIN_M:
            scattered.setdefault(p.def_handle, (d, p.def_line))
    for handle, (d, line) in sorted(scattered.items(), key=lambda kv: kv[1][1]):
        specs = [ex.constraints.get(c, {}) for c in d.constraints]
        has_circle = any(is_circle(s) for s in specs)
        has_box = any(is_box(s) for s in specs)
        if square and not has_circle:
            why = ("a box alone leaves the corners open" if has_box else "no edge constraint")
            out.append(Finding("S7", "FAIL", "deterministic",
                               f"object {d.name!r} is scattered on a square map without a circle edge constraint "
                               f"({why}): it can land outside the playable circle", map=stem, line=d.line,
                               guide_ref="rm-objects-herds: Map-edge constraints"))
        elif not square and not (has_circle and has_box):
            missing = " and ".join(w for w, ok in (("a corner circle", has_circle), ("an edge box", has_box)) if not ok)
            out.append(Finding("S7", "FAIL", "deterministic",
                               f"object {d.name!r} is scattered on a rectangular map without {missing}",
                               map=stem, line=d.line, guide_ref="rm-objects-herds: Map-edge constraints"))
    return out


def _image_exists(ref: str) -> bool:
    """A map-XML image reference resolves if the literal path or its
    basename exists under the mod images root (evidence: zptortuga's
    'ui\\random_map\\tortuga\\tortuga_mini' ships as
    icons/random_map/tortuga/tortuga_mini.png)."""
    rel = ref.replace("\\", "/")
    if (IMAGES_ROOT / f"{rel}.png").is_file() or (IMAGES_ROOT / rel).is_file():
        return True
    base = rel.rsplit("/", 1)[-1]
    base = base if base.endswith(".png") else f"{base}.png"
    icons = IMAGES_ROOT / "icons" / "random_map"
    return any(icons.rglob(base)) if icons.is_dir() else False


# --------------------------------------------------------------------------
# grid tier
# --------------------------------------------------------------------------

def _scenario_tag(sc) -> str:
    return f"P{sc.players}T{sc.teams}"


def grid_checks(res: RunResult, scenario, stem: str) -> RunResult:
    """G1-G5 on top of a successful static pass. Appends to res.findings."""
    from scripts.mapsim import checks as simchecks
    from scripts.mapsim.bridge import _ring_positions, extraction_to_resolved
    from scripts.mapsim.field import FieldContext, terrain_grid

    ex = res.ex
    if ex is None or ex.map_size_x is None:
        return res
    stem_tag = _scenario_tag(scenario)
    F = res.findings.append

    rs = extraction_to_resolved(ex)
    ctx = FieldContext(rs)
    tg = terrain_grid(rs, ctx)          # cell_tiles=1.0 — the golden resolution
    ring = _ring_positions(ex)
    res.rs, res.tg, res.ring = rs, tg, ring

    classes = {"names": ("LAND", "SHALLOW", "DEEP", "CLIFF")}

    # G2 — every player places on buildable ground (class 6, guide 21.3)
    if ring:
        for k, (x, z) in enumerate(ring, start=1):
            i, j = tg.cell_of_frac(x, z)
            code = tg.class_code(i, j)
            if code not in (0, 1):
                F(Finding("G2", "FAIL", "model",
                          f"player {k} nominal anchor ({x:.3f}, {z:.3f}) "
                          f"lands on {classes['names'][code]} — spawn will "
                          "fall back or fail", map=stem,
                          scenario=stem_tag,
                          guide_ref="guide 21.3:11058",
                          details={"player": k, "class": code}))
    else:
        F(Finding("G2", "INFO", "model",
                  "no circular player placement extracted — player anchors "
                  "not statically checkable", map=stem, scenario=stem_tag))

    # G3/G4 — the mapsim verdict engine: placement legality, constraint
    # satisfiability, area shortfalls, ring coverage, route docking.
    sev_map = {"error": "FAIL", "warning": "WARN", "info": "INFO"}
    for sf in simchecks.run_checks(rs):
        if sf.verdict in ("OK", "INACTIVE", "FEASIBLE_OK", "RING_OK"):
            continue
        F(Finding(f"SIM:{sf.verdict}", sev_map.get(sf.severity, "INFO"),
                  "model", f"{sf.name}: {sf.message}", map=stem,
                  scenario=stem_tag, details=dict(sf.details)))

    # G5 — reachability (lite): flood over walkable classes from each
    # player anchor; land-dominant maps must connect every pair.
    if ring and len(ring) >= 2:
        comp = _components(tg)
        cells = [tg.cell_of_frac(x, z) for x, z in ring]
        labels = [comp[j][i] for i, j in cells]
        deep = sum(tg.class_code(i, j) == 2
                   for j in range(tg.nz) for i in range(tg.nx))
        deep_frac = deep / float(tg.nx * tg.nz)
        split = {k + 1: lab for k, lab in enumerate(labels)}
        if len(set(labels)) > 1:
            naval = deep_frac >= NAVAL_DEEP_FRACTION
            F(Finding("G5", "INFO" if naval else "FAIL", "model",
                      ("players start in separate walkable regions "
                       f"{split} — "
                       + ("naval map assumed (DEEP covers "
                          f"{deep_frac:.0%})" if naval else
                          f"land map (DEEP only {deep_frac:.0%}) with no "
                          "walkable route between players")),
                      map=stem, scenario=stem_tag,
                      details={"components": split,
                               "deep_fraction": round(deep_frac, 3)}))

    # G1 — golden digest (determinism lock, plan B6)
    golden = _find_golden(stem, stem_tag)
    if golden is not None:
        got = tg.digest()
        want = json.loads(golden.read_text(encoding="utf-8"))
        if got != want:
            F(Finding("G1", "FAIL", "deterministic",
                      f"classified grid differs from golden {golden.name} — "
                      "either the map changed (regenerate the golden "
                      "deliberately) or the model regressed", map=stem,
                      scenario=stem_tag,
                      details={"hist": got["hist"],
                               "golden_hist": want["hist"]}))
    else:
        F(Finding("G1", "INFO", "deterministic",
                  f"no golden for {stem}_{stem_tag} — digest hist "
                  f"{tg.digest()['hist']}", map=stem, scenario=stem_tag))
    return res


def _find_golden(stem: str, tag: str) -> Optional[Path]:
    for d in GOLDENS_DIRS:
        p = d / f"{stem}_{tag}.json"
        if p.is_file():
            return p
    return None


def _components(tg) -> List[List[int]]:
    """4-connected component label per cell over walkable classes
    (LAND=0, SHALLOW=1); -1 for non-walkable."""
    comp = [[-1] * tg.nx for _ in range(tg.nz)]
    label = 0
    for j0 in range(tg.nz):
        for i0 in range(tg.nx):
            if comp[j0][i0] != -1 or tg.class_code(i0, j0) not in (0, 1):
                continue
            q = deque([(i0, j0)])
            comp[j0][i0] = label
            while q:
                i, j = q.popleft()
                for di, dj in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    ni, nj = i + di, j + dj
                    if (0 <= ni < tg.nx and 0 <= nj < tg.nz
                            and comp[nj][ni] == -1
                            and tg.class_code(ni, nj) in (0, 1)):
                        comp[nj][ni] = label
                        q.append((ni, nj))
            label += 1
    return comp


# --------------------------------------------------------------------------
# entry point
# --------------------------------------------------------------------------

def _profile_template_checks(res: RunResult, prof, scenario,
                             stem: str) -> None:
    """Profile-driven template instances (plan G4). `expectations` are
    sugar for one area_class_probe instance; `tests` run as declared."""
    from scripts.mapcheck.templates import TemplateContext, run_template
    ctx = TemplateContext(
        stem=stem, scenario=scenario, scenario_tag=_scenario_tag(scenario),
        ex=res.ex, rs=res.rs, tg=res.tg, ring=res.ring, profile=prof)
    if prof.expectations:
        res.findings += run_template(
            "area_class_probe", {"probes": prof.expectations}, ctx)
    for t in prof.tests:
        res.findings += run_template(t["template"], t.get("params"), ctx)


def _traderoute_names() -> set:
    """Route-def names the engine can look up: every <route ...>NAME record in the mod's
    data/traderoutedefs.xml (a full override of the vanilla file). Empty set if the file is absent."""
    p = Path(__file__).resolve().parents[2] / "data" / "traderoutedefs.xml"
    if not p.is_file():
        return set()
    text = p.read_text(encoding="utf-8", errors="ignore")
    return set(re.findall(r"<route [^>]*>([A-Za-z0-9_]+)", text))


def run(path: Path, scenario, static_only: bool = False,
        profiles_dir: Optional[Path] = None) -> RunResult:
    from scripts.mapcheck import profile as profmod
    from scripts.mapsim.waterdata import depth_overrides

    prof, perrs = profmod.load(
        path.stem, profiles_dir or profmod.PROFILES_DIR)
    res = static_checks(path, scenario)
    for e in perrs:
        res.findings.append(Finding(
            "P0", "FAIL", "deterministic",
            f"profile invalid: {e}", map=path.stem,
            guide_ref="scripts/maps/schema.md"))

    fatal_static = any(f.severity == "FAIL" and f.check in ("S1", "S3")
                       for f in res.findings)
    if not static_only and not fatal_static and res.ex is not None:
        with depth_overrides(prof.water_depth_m if prof else None):
            grid_checks(res, scenario, path.stem)
        if prof:
            _profile_template_checks(res, prof, scenario, path.stem)

    for f in res.findings:
        if not f.map:
            f.map = path.stem
        if not f.scenario and f.check.startswith(("G", "SIM", "T:")):
            f.scenario = _scenario_tag(scenario)
    profmod.apply_known_issues(res.findings, prof)
    return res
