# Plan: mapsim as a TESTING tool (refactor proposal)

Purpose correction (user directive 2026-08-09): the tool exists for **automatic
map testing** — deterministic verdicts like *"map has spawn issues: objects
spawn over cliffs / in water"*. Rendering is a debug byproduct, never the
product. This plan inventories the real spawn issues from the repo's RM
guidelines, audits where the current tool still guesses, and proposes the
refactor.

---

## 1. The spawn-issue taxonomy (from the guide, ranked by severity)

Source: `docs/random_map_generation_guide_v2.md` ch. 21 (lines cited).

### 21.1 Critical — map crashes on load
| Issue | Guide | Deterministically checkable? |
|---|---|---|
| Undefined variable | :10450 | YES — the extractor already parses the script; unknown identifiers surface as warnings today, should be findings |
| Variable defined twice | :10469 | YES — same |
| Missing `rmTerrainInitialize()` | :10508 | YES — already extracted, not yet reported |
| Invalid syntax / array syntax | :10520/:10543 | YES — parse errors, should map to a CRASH_RISK finding instead of an exception |

### 21.2 Very serious — content silently doesn't spawn
| Issue | Guide | Root cause | Checkable? |
|---|---|---|---|
| **Invalid water type name** | :10738 | name not in waterbodies(2).xml | YES — catalog exists (waterdata.py) |
| **Invalid terrain mix / terrain type** | :10767/:10789 | name not in mix/terrain catalogs | YES — needs catalog loader |
| **Invalid native civ ID** | :10818 | not in civs.xml | YES — scripts/source/civs.xml |
| **Invalid object (proto) name** | :10843 | not in protoy.xml/protomods.xml | YES — catalogs in repo |
| **Invalid grouping name** | :10867 | grouping file missing | YES — needs grouping catalog |
| **Land object/grouping over water** | :10901 | anchor+annulus reach no land, or constraints unsatisfiable | PARTIALLY — see §2 blind spot: `--xs` placements have no terrain affinity today |
| **Objects on cliff EDGES** (tops are fine) | :10960 | anchor on the steep rim band | YES — the grid now has cliff cells + rim; not yet consumed by checks |
| **Groupings on trade route path** | :11003 | fixed-footprint grouping intersects the route band | YES — pure geometry; groupings "can't adjust to constraints" per guide |
| **Players circular vs route conflict** | :11058 | ring radius ≈ route radius + area route-constraints ⇒ fallback bunching | YES — pure arithmetic (the guide's own 0.30-vs-route case) |
| Search annulus too small / wrong anchor (deer case) | :10924 | max distance can't reach valid ground | PARTIALLY — CONSTRAINT_UNSAT exists but rests on the approximate disc model |

### 21.3 Wrong locations
| Issue | Guide | Checkable? |
|---|---|---|
| 45° coordinate confusion (visual W = code NW) | :11118 | Lint-only (advice, not error) |

## 2. Honest audit — where the tool still guesses

Facts (fully deterministic, safe to gate on):
- script parsing/interpretation, every authored coordinate, constraint
  arithmetic, build order, name strings, waterbodies depths, sea level,
  base terrain, rmSetAreaCliffHeight, per-team ring sections.

Model estimates (calibrated, fine for pictures, NOT for verdicts):
- priority-flood growth shapes; SHORE_STANDOFF_M = 13 (Elbe calibration);
  ROUTE_HALF_WIDTH_M = 8; RIVER_HALF_WIDTH_CAP_M = 27 (pixel calibration);
  cliff-side dilation; nominal ring anchors (`approx`); seed relocation;
  the analytic disc model in checks.py (`_area_band_m` coherence slack).

**Blind spots (worst first):**
1. `--xs` placements all get `terrain_affinity="either"` (bridge.py) — so the
   guide's #1 runtime issue class (land object over water) is effectively
   UNCHECKED for extracted maps. Affinity must come from proto data
   (protoy.xml movement/placement type), not curation.
2. No name validation at all beyond water types.
3. Cliff cells exist in the grid but no check consumes them (objects on rim).
4. Grouping-vs-route overlap unchecked (except route-docked drift).
5. Several current *error* verdicts rest on model estimates (AREA_SHORTFALL,
   WRONG_TERRAIN via disc bands) — they belong in a separate "model estimate"
   severity so CI can gate on hard facts only.

## 3. Refactor proposal

### 3.1 Verdict classes: FACT vs ESTIMATE (core change)
Every `Finding` gains `basis: "deterministic" | "model"`. Exit code 1 only for
deterministic errors; model findings are advisory (`--strict` includes them).
This is the anti-guesswork contract: a red test is always a provable script
defect with a guide citation in the message.

### 3.2 Name-validation layer (new module `refdata.py`, all deterministic)
Mirror the engine lookup chain **mod → vanilla snapshot** (the waterdata.py
pattern, user-approved): protoy/protomods, clifftypes/clifftypes2, civs,
forest(2), terrain mixes + terrain types (extract vanilla catalogs via
bar-extract into scripts/source/ as needed), groupings. Validate every string
argument: rmSetSeaType, rmSetAreaWaterType/CliffType/Mix/TerrainType/ForestType,
rmAddObjectDefItem protos, rmCreateGrouping groupings, rmSetSubCiv civs.
New verdict: `UNDEFINED_NAME` (error, deterministic, cites the files searched).

### 3.3 Proto-derived terrain affinity
From protoy movement type (land/water/naval/building): auto-assign
terrain_affinity per object def. Then land-over-water / water-over-land checks
finally fire on `--xs` maps. Verdict split:
- deterministic error when the whole search annulus is *provably* wrong
  terrain from authored facts alone (e.g. annulus entirely in base sea beyond
  every land-creating area's authored reach);
- model warning when it depends on grown shapes.

### 3.4 New deterministic checks (direct from guide 21.2)
- `OBJECT_ON_CLIFF_EDGE`: anchor (min_dist 0) on a cliff rim cell; groupings
  stricter (error) than objects (warning), per guide.
- `GROUPING_BLOCKS_ROUTE`: grouping anchor within route half-width (+ footprint).
- `PLAYER_RING_ON_ROUTE`: |ring radius − route distance| < the player areas'
  route-constraint margin ⇒ the guide's fallback-bunching case.
- `CRASH_RISK`: parse errors / missing TerrainInitialize / duplicate vars as
  findings instead of stack traces.

### 3.5 Golden findings harness (determinism lock)
`--matrix` already emits findings JSON. Add golden files per map+scenario under
tests/goldens/; a test asserts byte-stable findings. Any model change then
shows an exact verdict diff in review — "maps looking different" becomes an
explicit, reviewed event instead of drift. (Renders are already deterministic
run-to-run; differences between sessions were model changes. This makes them
auditable.)

### 3.6 Output contract
`report_*.json` keeps schema; add `basis`, `guide_ref` per finding and a
summary block `{deterministic_errors, model_warnings}`. Exit codes: 0 clean /
1 deterministic errors / 2 usage. CI-ready.

### 3.7 Demote visuals
Render/`--layers` stay for debugging; no check may read the render. The
model-estimate constants stay ONLY on the render/growth side and in
model-basis findings.

## 4. Suggested order of work
1. Finding.basis + exit-code contract + reclassify existing verdicts (small,
   unlocks CI use immediately).
2. refdata.py name validation (biggest silent-failure class, purely mechanical).
3. Proto affinity + land/water placement checks on `--xs`.
4. Cliff-edge / grouping-route / ring-route checks.
5. Golden findings harness over the 13-map suite.
