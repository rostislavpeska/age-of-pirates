# Plan: Map Spawn Simulator (`mapsim`)

Coordinate-only static simulator for AoE3 DE random map scripts. Renders a round
minimap-style preview of where areas and objects will land, and reports which
placements are off the map, off the world circle, off authored land, or
unknowable before generation — with correct fraction / meter / tile arithmetic.

**Scope locked by assignment:** no blob shapes, no area variants, no coherence
simulation. Only locations, area sizes, and unit conversion done right.

This plan is evidence-driven: every engine fact below was established by an
8-agent research pass over the guide, stock maps, and grouping XMLs, and the two
riskiest verdicts (meters-per-tile, boundary model) survived / were corrected by
independent adversarial verifiers. Citations are `file:line`.

---

## 1. Established ground truth (verified, cite-checked)

### 1.1 Units — the conversion calculator's contract

| Fact | Value | Key evidence |
|---|---|---|
| Tile size | **2.0 m × 2.0 m** | guide `random_map_generation_guide_v2.md:650` "Tile Size: 2x2 meters"; grouping tile grids (below) |
| `rmSetMapSize(x, z)` | **meters**, not tiles | guide:1814 "dimensions of the map in meters"; `amazonia.xs:25-27` echoes the value as `"m x m"` |
| Terrain grid | `(x/2) × (z/2)` tiles | follows from the two facts above |
| This map's ladder | 400 / 500 / 600 / 660 m ⇒ 200 / 250 / 300 / 330 tiles per side | `000_independence_war.xs:50-57` |
| World coordinates (vectors) | meters | `000_Elbe.xs:695-696` round-trips `xsVectorGetX` through `rmXMetersToFraction` |
| Grouping `posx`/`posz` | meters; `<width>`/`<height>` | tiles | `Bridge_universal_long.xml`: tile `<block>` startx spans exactly −20..19 = the declared `<width>40</width>`; deck heights at ±36/34 m align with bridge-face units at posx −29.31..+27.08 only at 2 m/tile |

**Formulas** (X shown; Z is the analog with `mapSizeZ`):

```
rmXTilesToFraction(t)   = (t * 2.0) / mapSizeX_m
rmXMetersToFraction(m)  = m / mapSizeX_m
rmXFractionToMeters(f)  = f * mapSizeX_m
rmAreaTilesToFraction(t)= t / totalTiles,  totalTiles = (mapSizeX_m/2) * (mapSizeZ_m/2)
```

`rmSetAreaSize` takes a fraction of total map **area**. An ideal (coherence 1.0)
area is a disc with (general, non-square-safe form):

```
radius_m      = sqrt(area_frac * mapSizeX_m * mapSizeZ_m / pi)
radius_frac_x = radius_m / mapSizeX_m     # == sqrt(area_frac/pi) only when square
radius_tiles  = radius_m / 2.0
```

**Known guide erratum** (do not "correct" the calculator to match it):
guide:6620 claims 400 area tiles ≈ 20×20 m — that takes sqrt(400)=20 and drops
the 2 m/tile factor; 400 tiles = 1600 m² = 40×40 m. Pinned by a known-value test.

**Verified invariant** (becomes a property test): an area sized in *tiles* has a
constant physical radius across map sizes — 700 tiles ≈ 29.9 m radius at 400 m
*and* at 660 m — while an area sized as a *literal fraction* (0.33 player
islands) scales with the map (radius 129.6 m at 400 m → 213.9 m at 660 m).

**Observed in-game (user, 2026-07-30, first-class evidence):** areas grow
AROUND obstacles to reach their tile budget, and the map edge acts as an
obstacle — an area centered on the edge grows to a visibly larger radius than
the same-size area mid-map. Consequences for the shape model: `rmSetAreaSize`
is a target, not a footprint clip; blocked space redistributes area instead of
deleting it; the analytic acceptance test is that an edge-seeded area's radius
approaches √2 × its free-field radius (half-disc of equal area).

**Adversarial finding worth keeping:** the `2.0` in the classic
`size = 2.0*sqrt(players*playerTiles)` formula is a *designer scale knob*, not
the unit ratio — shipping maps use 1.4 (`araucania.xs:49`), 2.1 (`andes.xs:89`),
2.5. m/tile = 2.0 is pinned by the guide and grouping internals, **never** by
that coefficient. The calculator must not infer tile size from map-size formulas.

### 1.2 Boundary — the round map model

The map is always a **square** grid. The round look is a generation-time clip:
`rmSetWorldCircleConstraint(true)` (`000_independence_war.xs:81`, guide:3243)
constrains RM activities to the inscribed circle; corners still physically exist
as terrain. Individual areas opt out via
`rmSetAreaObeyWorldCircleConstraint(id, false)` — this map uses the opt-out on
13 areas (lines 377–606), so **the flag must be tracked per area**.

Out-of-bounds semantics (empirical, from a sweep of the whole stock RandMaps
folder):

- No shipped script ever passes a spatial coordinate outside `[0,1]`. Engine
  behavior there is **undocumented** → the simulator treats it as invalid input
  and fails loudly (never clamps, never guesses).
- Exactly-edge values are legal: fish at `(1.00, 0.70)` (`Cascade Range.xs:1327`),
  props at `(0.99, 0.99)`.
- The engine's failure mode near the boundary is **silent fallback**, not an
  error (guide:8137: players "spawn in fallback location, usually bunched
  together") — which is exactly why this tool needs to exist.
- Values > 1.0 appear only as `rmSetPlacementSection` *angle* fractions, which
  wrap (`0000_crownlands.xs:660`, guide:11729-11736). Angular wrap ≠ spatial wrap.

**Verdict regions** (three nested checks):

1. **Hard domain** `[0,1]²` — outside ⇒ `OFF_MAP` (input error).
2. **World circle** — center (0.5, 0.5), radius 0.5 in fraction units. Inside
   square but outside circle, when the constraint applies to that placement ⇒
   `OUTSIDE_CIRCLE` (silent fail / fallback likely). Type-specific safe radii
   observed across stock maps: players/TC ≤ 0.45, generic objects ≤ 0.47,
   nuggets/flags ≤ 0.48 — between safe radius and 0.5 ⇒ `EDGE_RISK` warning.
   Only 0.45 is documented (guide:8135); 0.47/0.48 are inferred from stock-map
   convention and carry the same epistemic status as `WORLD_CIRCLE_R` — named
   config constants with docstring caveats, measured by markers in E3.
3. **Authored-land union** (water-base maps: `rmTerrainInitialize("water")` +
   `rmSetSeaLevel(1.0)`, so land = union of areas with base height > sea level,
   each modeled as a disc at its computed radius). Land placements outside the
   union ⇒ `WRONG_TERRAIN`; water placements inside it likewise.

**Correction forced by the adversarial verifier (design-critical):** an earlier
draft used "land = the z ≥ 0.45 half" as the land test. That misclassifies the
pirate headlands — 1100-tile land discs at (0.17, 0.30) and (0.83, 0.30) with
the world-circle opt-out (`000_independence_war.xs:571-607`) that the game
renders fine. The land region **must** be derived from the authored areas
themselves, never from a map-level heuristic. This exact case is a mandatory
regression test.

**Placements are discs, not points.** `rmSetObjectDefMinDistance/MaxDistance`
give every placement a search annulus in meters around its anchor (TC max 20 m /
60 m at `000_independence_war.xs:896-916`); the engine slides within it. A check
passes if the annulus intersects the valid region — testing only the center
point produces false alarms.

Because blob shape is out of scope, each area is an ideal disc plus an
**uncertainty band**: `smoothDistance` + 20% of radius for coherence-1.0 areas,
wider (50%) when coherence is unset/low. Verdicts inside the band are reported
as `NEAR_EDGE_OF_AREA` (uncertain) rather than pass/fail.

**Runtime-dependent values are flagged, never guessed.** Anything derived from
`rmGetUnitPosition`, `rmFindClosestPointVector`, `rmGetTradeRouteWayPoint`,
`rmPlayerLoc*Fraction`, `rmRand*` etc. gets verdict `UNKNOWN_RUNTIME` with its
symbolic expression. One codified exception — **literal-anchored taint
resolution**: when the tainted value is a pure readback of a placement whose own
anchor is literal (the probe idiom: place at literal → `rmGetUnitPosition` →
convert back), the checker resolves it to that literal anchor and marks the
verdict *approximate* instead of unknown. Regression test 1 (§3) exercises the
hand-built untainted scene in WP2; the end-to-end WP4 path must reach the same
OK-approximate verdict through this rule, not regress to `UNKNOWN_RUNTIME`.

**Guide octagon, pinned** (the guide never says "octagon"; two shapes are
derivable from its prose, so the tool fixes one): inside iff
`0.2 ≤ X+Z ≤ 1.8` and `|X−Z| < 0.8` within `[0,1]²` — the guide's literal
red-zone rules (guide:279), i.e. corner cuts of 0.2 along each edge. The softer
`0.1–0.9` box is a separate helper. Both are **advisory-only** overlays: at
(0.9, 0.9) the octagon admits a point the world circle rejects (r ≈ 0.566).

### 1.3 The golden fixture

The complete geometry inventory of the deployed map (22 areas, 42 object defs,
10 trade-route waypoint entries with player-count branches, player placement
tree) was extracted and spot-verified against
`000_independence_war.xs` — stored at
[docs/mapsim_fixture_independence_war.json](mapsim_fixture_independence_war.json).

Be precise about what it is: an **inventory** — line-cited entries with
verbatim expression strings — not a runnable scene. In WP1 it serves as the
curation checklist from which the scene JSON (§2.2, the single golden format)
is authored; the extractor's WP4 diff target is those curated scenes, not this
file. WP1 also vendors a **hashed snapshot** of the exact `.xs` revision into
`scripts/mapsim/tests/fixtures/` — the deployed file lives in the Steam-managed
game folder and is under active development, so goldens refer to the snapshot,
never the live file, with a documented re-baseline step for map edits.

---

## 2. Architecture

Follows the repo's existing tooling conventions exactly (verified against
`scripts/tech_generator/`, `scripts/unit_generator/`, root `_*.py` CI
validators, and skills scripts):

```
scripts/mapsim/
  __init__.py          # empty, matches existing packages
  main.py              # zero-arg entrypoint, "# ==== USER SETTINGS ====" block,
                       #   sys.path bootstrap (parents[2]), delegates to sim.py
  sim.py               # argparse worker CLI: main(argv) -> int (0/1/2),
                       #   from __future__ import annotations, pathlib
  units.py             # MapGrid: the conversion calculator (stdlib only)
  geometry.py          # discs, circle, annuli, polyline distance, octagon (stdlib only)
  scene.py             # dataclasses + JSON scene loader, per-player-count resolution
  checks.py            # verdict engine over a resolved scene
  render.py            # matplotlib isolated here; lazy import w/ graceful skip
  xs_extract.py        # WP4: mini-interpreter .xs -> scene JSON
  tests/
    fixtures/independence_war.inventory.json
    test_units.py  test_geometry.py  test_scene.py
    test_checks.py test_render.py    test_extract.py
```

- **Interpreters (verified on this machine):** PATH `python` = 3.12.10 **with
  matplotlib 3.10.7** and pytest 9.0.3; `py` = 3.13.7, pytest 8.4.2, no
  matplotlib. Core stays stdlib-only; `render.py` lazy-imports matplotlib
  (`matplotlib.use("Agg")`) following the repo's `bartool`/lz4 optional-dep
  precedent, and prints a clear skip message under `py`. No requirements.txt —
  matches house style.
- **Invocation:** `python scripts/mapsim/main.py` from repo root; flags on
  `sim.py` for agent use. Tests: `python -m pytest scripts/mapsim/tests`.
- **Outputs** (PNGs, reports) default to `playground/mapsim/` — already
  gitignored (the repo's committed `.pyc` files show what happens otherwise).

### 2.1 `units.py` — the conversion calculator

The part you called tricky, so it gets the strictest design: one class, all
conversions as pure methods, no module-level state, every formula from §1.1.

```python
@dataclass(frozen=True)
class MapGrid:
    size_x_m: float          # rmSetMapSize x — METERS (verified §1.1)
    size_z_m: float
    TILE_M: ClassVar[float] = 2.0

    tiles_x / tiles_z / total_tiles          # derived
    x_tiles_to_frac(t) / z_tiles_to_frac(t)  # (t*2)/size_m
    x_m_to_frac(m) / x_frac_to_m(f)          # and Z twins
    area_tiles_to_frac(t)                    # t / total_tiles
    area_frac_to_radius_frac(f)              # sqrt(f/pi)
    area_tiles_to_radius_m(t)                # sqrt(t/pi)*2  — map-size invariant
    frac_dist_m(x1,z1,x2,z2)                 # anisotropy-safe distance in meters

@classmethod
MapGrid.for_players(n, ladder=INDEPENDENCE_WAR_LADDER)  # 400/500/600/660
```

Design rules: reject non-finite and negative inputs with exceptions (fail loud,
§1.2); document in each method's docstring which rm* function it mirrors and
its evidence line; support non-square maps (x ≠ z) even though this map is
square — `rmZTilesToFraction` divides by `size_z_m`, and conflating the axes is
precisely the class of silent bug the tool exists to catch.

### 2.2 `scene.py` — the model

Dataclasses (a richer schema than the raw inventory — WP1 curation fills the
fields the inventory only records as prose):

- `MapConfig`: size ladder, sea level, world-circle flag, **team count and mode
  flags (KOTH, nomad)** — map geometry branches on `cNumberTeams` (TC
  MaxDistance is 20 m at 2 teams, else 60 m; `000_independence_war.xs:896-916`)
  and on mode, so the resolution key is **`(P, teams, mode)`**, never P alone
- `Area`: name, location (authored coords **or `engine_placed`** — the
  `westforest+i`/`eastForest+i` loops have no `rmSetAreaLocation`; such areas
  get `UNKNOWN_RUNTIME` placement and are excluded-with-note from the land
  union), size as a **(min, max) range** in tiles or fraction (keep which!),
  base height, coherence, smooth distance, `obey_world_circle`, derived
  `creates_land`
- `Placement`: name, kind (`at_loc` / `in_area` / `at_point` / `route_docked` /
  `grouping`), anchor or symbolic expression + taint flag, min/max distance
  (m, branch-resolvable like everything else), **`terrain_affinity`**
  (land / water / either — drives `WRONG_TERRAIN`), **`category`**
  (player_tc / generic / nugget_flag — selects the `EDGE_RISK` tier),
  explicit `area_ref` / `route_ref`, constraint refs, grouping footprint
  (tiles, from grouping XML `<width>/<height>`)
- `TradeRoute`: waypoint polyline (branch-resolvable)
- `PlayerPlacement`: circular(min, max) + placement sections per team branch,
  or fixed coordinates
- `Constraint`: pie (center, r0, r1, arc) | box (x0, z0, x1, z1, buffer)

Scene JSON is **one file with branch-keyed values** (by size rung, team count,
mode); the loader resolves it for any requested `(P, teams, mode)`. Checks and
reports run at least P ∈ {2, 3, 5, 7, 8} — the ladder's boundary counts 3/5/7
included, because `>=` vs `>` misauthorings bite exactly there — at both
2-team and FFA team layouts where the map branches on teams.

### 2.3 `checks.py` — verdict engine

Ordered per placement: `OFF_MAP` → `OUTSIDE_CIRCLE` / `EDGE_RISK` →
`WRONG_TERRAIN` / `NEAR_EDGE_OF_AREA` → `CONSTRAINT_UNSAT` → `OK`;
`UNKNOWN_RUNTIME` short-circuits (subject to the literal-anchor rule, §1.2).
Scene-level checks emit their own finding record type (area pair / route /
ring findings are not per-placement verdicts and get their own shape in the
report JSON):

- area–area overlap (estate valleys vs harbour cliffs — a real bug we hit)
- trade-route waypoints on water / inside domain; route-docked sockets within
  perpendicular MinDistance..MaxDistance of the polyline, snap tolerance = half
  the route's `blocksize` read from the map's `traderoutedefs.xml` entry
  (guide:6122 documents the attribute); E3 only confirms the value in-game
- player ring: radius vs 0.45 cap (guide:8135), ring ∩ land union per section
  arc (**wrapped arcs supported** — the map uses `rmSetPlacementSection(0.73,
  0.27)` at >2 teams, which wraps through 0), TC annulus on land
- constraint satisfiability ⇒ `CONSTRAINT_UNSAT`: anchor's annulus ∩ every
  attached pie/box constraint non-empty (this is the verdict that would have
  caught the original pirate-village MaxDistance-30 silent failure)

Report: table to stdout (name, kind, scenario key, verdict, distance-to-valid),
JSON to `playground/mapsim/report_P{n}_T{teams}.json`, exit 1 on any hard
fail — CI-compatible like the root `_*.py` validators.

### 2.4 `render.py`

One PNG per scenario key: square domain, world-circle outline, octagon guide
(dashed, per its pinned definition), water base, land-area discs (fill = terrain class, hatch = uncertainty
band), trade-route polyline + sockets, placement markers colored by verdict,
player ring arcs, legend, meter scale bar. Verdict colors: green OK / yellow
EDGE_RISK & NEAR_EDGE / red fails / gray UNKNOWN_RUNTIME.

### 2.5 `xs_extract.py` (WP4) — scope fixed by the construct survey

The survey of all four relevant maps produced the full construct catalog and 13
extraction hazards (reassignment between uses, four spellings of the
player-count constant, `rmSetAreaSize` called up to 4× on one handle,
comment-stripping before everything, shorthand `for(i=1; <n)` with loop-variable
leakage, taint propagation through `xsVectorGetX`, etc.). Conclusion: **a regex
extractor is provably wrong on this codebase; the extractor must be a small
sequential interpreter**, run once per player count:

1. strip comments (incl. `//` glued to code and 100-line `/* */` dead blocks)
2. symbol table with function-level scoping, last-write-wins
3. constant folding: arithmetic, string concat (area names like `"westforest"+i`
   are identity-bearing), the **eight** foldable builtins —
   `rmX/ZTilesToFraction`, `rmX/ZMetersToFraction`, `rmX/ZFractionToMeters`,
   `rmAreaTilesToFraction` (needs both folded sizes), `rmDegreesToRadians`
   (needs neither) — evaluated against the **already-folded** map size
   (program order matters)
4. if/else-if/else with braced, unbraced and empty bodies; all three for-loop
   forms + `break`, unrolled per scenario key
5. opaque handles: `rmCreate*` returns fresh ids; property setters accumulate,
   sequential overwrite
6. taint lattice: the runtime-only reads (§1.2 list) poison derived values;
   tainted geometry args are emitted symbolic
7. **tainted-condition branches fork**: a conditional on a tainted expression
   (the map's own `if (teamStartLoc > 0.5)` — `teamStartLoc = rmRandFloat`)
   emits *both* arms as labeled variants ("runtime branch: teamStartLoc");
   the golden scenes store the variant set, so the WP4 diff is well-defined
   for mirror-symmetric cases
8. trigger DSL blocks parse-and-discard (they share loop variables with
   geometry code, so they can't be blind-skipped)

The **normative hazard list** is the 13-entry catalog in
[docs/mapsim_xs_extraction_evidence.json](mapsim_xs_extraction_evidence.json)
(vendored from the research pass — the plan text names only the headline ones);
`test_extract.py`'s one-micro-case-per-hazard requirement counts against that
file, not against this section.

Not supported (declared, warned on sight): includes' internals, `switch`/`while`
(unused anywhere), xsArray beyond int get/set.

---

## 3. Test plan (pytest — first tests in this repo, so self-contained)

**test_units.py** — the calculator gets known-value + property tests:

| Test | Expectation |
|---|---|
| `x_tiles_to_frac(22)` @ 400 m | `0.11` exactly (matches Elbe's dock offset math, `000_Elbe.xs:527`) |
| `x_tiles_to_frac(22)` @ 660 m | `0.0667` |
| `area_tiles_to_frac(700)` @ 2p | `700/40000 = 0.0175`; radius ≈ 0.07463 frac ≈ 29.85 m |
| tiles-area radius invariance | radius_m(700 tiles) equal at 400 m and 660 m (±ε) |
| round trip | `x_m_to_frac(x_frac_to_m(f)) ≈ f` (`pytest.approx`, rel 1e-12) — **not** `==`: `(f*S)/S != f` in IEEE doubles for up to ~15% of values at S = 400/660 |
| totals | `area_tiles_to_frac(total_tiles) == 1.0`; `x_tiles_to_frac(tiles_x) == 1.0` |
| ladder | five explicit pairs: 2→400, 3→500, 5→600, 7→660, 8→660 |
| guide erratum | 400 area tiles ⇒ 1600 m² (40×40 m), pinning the guide:6620 error out |
| anisotropy | non-square grid: X and Z linear conversions differ correctly, **and** `area_frac_to_radius_m` uses `sqrt(f·Sx·Sz/π)`, not an X-only formula |
| signed offsets | linear conversions accept negatives (`x_tiles_to_frac(-22) == -0.11` @400) — the `0.5 - rmXTilesToFraction(22)` idiom; dimensions/areas reject them |
| loud failure | NaN/inf anywhere raises; negative sizes/areas raise |

**test_geometry.py** — circle membership at boundary values (0.5 exactly on
circle, boundary-inclusive), annulus–annulus / annulus–disc / annulus–box
intersection (tangent, containment, ring-around-hole cases),
point-to-polyline distance, **wrapped placement-section arcs** (arc
(0.73, 0.27) contains angle-fraction 0.0 and 0.9, excludes 0.5; crownlands'
(0.1875, 1.0615) normalizes and wraps), octagon per its pinned definition
(§1.2) plus the documented octagon-vs-circle disagreement at (0.9, 0.9).

**test_checks.py** — verdict taxonomy on hand-built scenes, including three
regression cases from this project's real history:

1. **Pirate headlands** (the case that refuted the draft model): land grouping at
   (0.17, 0.30) on a 1100-tile authored disc with circle opt-out ⇒ must be `OK`
   (hand-built untainted scene here; the WP4 end-to-end path must reach
   OK-approximate via the literal-anchor rule, asserted in `test_extract.py`).
2. **Old pirate-village config**: MaxDistance 30 m + no authored land beneath ⇒
   asserts verdict `CONSTRAINT_UNSAT` specifically.
3. **Harbour sockets before shore cliffs existed** ⇒ `WRONG_TERRAIN`;
   with the four 700-tile cliff areas ⇒ `OK`.

Plus: fish at (1.00, 0.70) ⇒ warning not error; TC at r = 0.46 ⇒ `EDGE_RISK`;
coordinate 1.01 ⇒ raises.

**test_scene.py** — golden fixture loads; counts match (22 areas / 42 object
defs); per-P resolution picks the right `rmSetAreaSize` overwrite (riverArea1:
2700 → 3500 → 4500 → 6000 tiles).

**test_render.py** — `pytest.importorskip("matplotlib")`; smoke: files created,
non-trivial size, one per P.

**test_extract.py** (WP4) — one micro-case per hazard from the normative list
(§2.5), then the golden gate: `extract(snapshot.xs, key) == curated scene
JSON` for every scenario key the goldens cover. The bias guard runs on a
**genuinely stock** map already cited in the evidence (`amazonia.xs` or
`Cascade Range.xs`) — *not* `000_Elbe.xs`, which is this mod's own map and
shares authoring idioms with the fixture; Elbe can serve as a second in-house
target, gated only on "extraction completes with zero unsupported-construct
warnings".

---

## 4. Work packages — gated, in order

Every gate has a **mechanical part** (suite green, artifact exists, diff empty)
and, where judgment is unavoidable, an explicitly labeled **manual part** —
named as such so nobody mistakes a review for a proof. No time estimates — the
gates are the plan.

**WP0 — scaffold + `units.py` + `geometry.py` + CI hook**
Mechanical gate: full `test_units.py` + `test_geometry.py` suite green on
**both** interpreters (`python` 3.12 and `py` 3.13); a path-filtered GitHub
Actions workflow (`mapsim.yml`) runs the suite on push, joining the repo's four
existing validator checks.

**WP1 — `scene.py` + scene curation + snapshot vendoring**
Curate the inventory into the branch-keyed scene JSON (the golden format);
vendor the hashed `.xs` snapshot into `tests/fixtures/`. Mechanical gate:
`test_scene.py` green, counts match the inventory, snapshot hash recorded.
Manual gate: 3 fresh inventory entries re-verified line-by-line against the
snapshot.

**WP2 — `checks.py`**
Mechanical gate: `test_checks.py` green including all three historical
regressions; report generated for every scenario key in
{2,3,5,7,8} × {2-team, FFA}. Manual gate: I triage every finding against the
`.xs` — each becomes "real issue", or "documented false-positive with tracked
cause"; the triage table goes in the report directory.

**WP3 — `render.py` + CLI wiring**
Mechanical gate: PNGs for all scenario keys land in `playground/mapsim/`.
**User gate:** you eyeball them against your knowledge of the map. Cheap to
iterate — this is where wrong constants become visible instantly.

**WP3b — evaluable constraints + feasibility field** *(added after the WP3
review: terrain constraints and constraint-derived "dynamic" areas — still no
blobs, only constraint geometry)*
1. Upgrade catalog kinds from `opaque` where the referenced geometry is
   statically known: `terrain` (distance to/from the authored-land union),
   `marker_class` (great-lake/deep-lake marker discs — formalize area classes
   into a scene field), `route_distance` (polyline), `footprint` (bridge,
   docks), `anchor_set` (sockets, estates). Truly runtime-relative constraints
   (TC/nugget/all-object avoidance) stay opaque with a documented list.
2. Deterministic feasibility field: sample the grid at tile resolution (no
   randomness — resumable and test-stable); per entity, intersect its
   constraint set into an allowed region. Metrics: allowed fraction of each
   located area's authored disc; feasible-region tiles vs requested tiles for
   engine-placed loops (predicts forest underfill).
3. New findings: `AREA_SQUEEZED` (allowed fraction of a located disc below a
   threshold), `FEASIBLE_TOO_SMALL` (engine-placed loop demand exceeds the
   feasible region), plus terrain-constraint coverage folded into
   `CONSTRAINT_UNSAT`.
4. Renderer overlay: `--field <entity>` stipples the allowed region on the
   preview; squeezed discs shade their forbidden part.
Mechanical gate: analytic unit tests (e.g. a disc half-covered by water ⇒
allowed 50% ± sampling error); field run on the real scene at 2p and 8p.
Manual gate: triage of new findings. **User gate:** overlay previews.
Caveat recorded: terrain constraints reference *generated* terrain; the field
approximates it with the authored-disc union, so uncertainty bands apply.

**WP4 — `xs_extract.py`**
The mini-interpreter, test-driven off the normative hazard list. Mechanical
gate: golden diff empty vs the curated scenes for every covered scenario key;
bias-guard extraction on a genuinely stock map (`amazonia.xs` / `Cascade
Range.xs`) plus warning-free extraction of in-house Elbe; every construct in
the survey either handled or explicitly warned-on.

**WP5 — sweep + hardening**
Run against 2–3 genuinely stock maps; stock maps are presumed correct — every
flag on them is a simulator bug until proven otherwise. Mechanical gate: sweep
completes, findings enumerated. Manual gate: zero findings left *unexplained*
(each is closed as simulator-bug-fixed or documented engine-behavior note).

**Rollback/pause points:** each WP is independently useful. Stopping after WP2
already yields a working checker driven by hand-written scenes; WP4 is the
largest package and can be deferred indefinitely.

---

## 5. Experiments

**Done (static, adversarially verified):**
- E1 — meters-per-tile adjudication: **2.0 m/tile**, two skeptics failed to
  refute (one strengthened it: found the 1.4 coefficient in `araucania.xs` and
  showed it's a scale knob, not a unit).
- E2 — boundary model: draft refuted on the pirate-headland case and corrected
  to the authored-land-union model (§1.2).

**Queued (need the game, one launch each — user runs, I prepare):**
- E3 — in-game cross-check, behind `int mapDebug = 1;` in the map: place a
  visible marker column at `rmXTilesToFraction(50)`, at `rmXMetersToFraction(100)`
  (should coincide at 2 m/tile), at (0.5, 0.999), at the world-circle edge
  r = 0.5 along an axis, **and at r = 0.45 / 0.47 / 0.48** (the inferred
  safe-radius tiers — same epistemic status as the circle radius). Confirms:
  unit ratio in the live engine, edge behavior, the exact world-circle radius,
  the tier radii, and the trade-route socket snap grid (vs the `blocksize`
  read from `traderoutedefs.xml`).
- E4 — prediction vs reality: run the simulator on the current map, generate
  in-game with a seed from `Age3Log.txt`, compare screenshot to the WP3 PNG.

Neither experiment blocks WP0–WP2; E3 slots in before WP5 to close the last
constants.

---

## 6. Risks

| Risk | Mitigation |
|---|---|
| Fixture errors (its agent had no verifier) | 3 entries spot-verified already; WP1 re-verifies 3 more; WP4's independent extractor diffs the whole thing |
| Disc model vs real blob shapes | uncertainty bands (§1.2); verdicts in the band are "uncertain", never hard fails; out-of-scope by assignment |
| World-circle radius exactly 0.5 is inferred, not documented | E3 measures it; until then it's a named constant `WORLD_CIRCLE_R = 0.5` with the caveat in its docstring |
| Probe-and-bind placements are statically unknowable | `UNKNOWN_RUNTIME` verdict class — honest by design; the more the map moves to probe-and-bind, the more the tool's value shifts to areas/anchors, which is where the real bugs were |
| Two-interpreter drift (3.12 with matplotlib vs 3.13 without) | core stdlib-only; WP0 gate runs tests on both; render degrades gracefully |
| XS interpreter divergence from engine | golden-diff against two real maps; unsupported constructs warn loudly instead of guessing |
| Golden-input drift: both target `.xs` files live in the Steam-managed game folder, outside the repo, under active development — fixture line numbers rot on any edit or game update | WP1 vendors a hashed snapshot into `tests/fixtures/`; goldens reference the snapshot, never the live file; documented re-baseline step |

---

## 7. Decisions taken (flag if you disagree)

1. Package at `scripts/mapsim/`, mirroring `tech_generator` (two-layer
   main.py/worker, USER SETTINGS block).
2. Outputs to `playground/mapsim/` (already gitignored).
3. matplotlib optional at runtime (repo's lz4 precedent), no requirements.txt.
4. Scene JSON is a single branch-keyed file resolved at load for any
   `(P, teams, mode)`; standard check matrix {2,3,5,7,8} × {2-team, FFA}.
5. Constraint checking limited to distance-type constraints (pies, boxes,
   min/max annuli); class-avoidance constraints recorded but not evaluated.
6. Coherence is read **only** to size the uncertainty band (§1.2), never to
   model shape — the one place the "no coherence" scope line is touched; flag
   if even that is out of scope.
7. The pytest suite joins CI as a path-filtered workflow (`mapsim.yml`) so the
   WP0 gate keeps protecting after merge.
8. Linear conversions accept signed values (offset idiom
   `0.5 - rmXTilesToFraction(22)`); dimensions and areas reject negatives.
