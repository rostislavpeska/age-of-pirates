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

def _strip(src: str) -> str:
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
                mode = "str"; out.append(" "); i += 1; continue
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
            out.append(" "); i += 1
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
    seen: Dict[Tuple[int, str], int] = {}   # (block_id, name_lower) -> line
    block_stack = [0]
    next_id = 1
    paren = 0
    di = 0
    for off, ch in enumerate(stripped):
        while di < len(decls) and decls[di][0] == off:
            name = decls[di][1]
            if paren == 0:
                key = (block_stack[-1], name.lower())
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
    return res


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
