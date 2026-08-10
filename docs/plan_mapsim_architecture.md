# Plan: mapsim 3-layer architecture & the Terrain Standard

User directive 2026-08-09. Status: PLANNING ONLY — no code in this pass.
Supersedes the testing-refactor sketch where they overlap
(plan_mapsim_testing_refactor.md remains the Layer-1/Layer-3 checklist donor).

---

## Part A — the three layers

### Layer 1 · Script validity & automated testing (no simulator needed)
Plain unit tests over the .xs source and reference catalogs. No terrain
model, no rendering, no growth — therefore zero model risk.
- parse/crash class: syntax, undefined/duplicate variables, missing
  `rmTerrainInitialize` (guide 21.1)
- name validation against the mod→vanilla catalog chain (guide 21.2):
  water types, terrain mixes/types, cliff types, protos, groupings, civs
  (`data/*` overrides, `scripts/source/*` vanilla snapshots via bar-extract)
- pure-arithmetic conflicts: players-circular radius vs trade-route polyline
  (guide 21.6 case study), route-docked socket distances
- delivery: a `pytest` suite + a thin CLI (`mapcheck <map>.xs`) with exit
  codes; findings all `basis: deterministic`, each citing its guide section.
Independent from Layers 2/3; can gate CI today.

### Layer 2 · Terrain (THE current focus — Part B below)
One canonical, cited standard for ground height, water, cliffs and paint —
what the engine computes, what we derive from it, and what every color means.
No invented colors, no ad-hoc class rules. Everything either
**FACT** (documented/measured, cited) or **CALIBRATED** (registered constant
with its measurement recipe) — and the rendering is a pure function of the
classified grid, never the other way around.

### Layer 3 · Entity spawn visualization (documented, OUT OF SCOPE for now)
Backlog, in the user's own terms:
- groupings drawn as their REAL rectangles (footprint from the grouping
  definition files), 50% dark overlay — overlap with terrain/route instantly
  visible
- deterministic minimap icons from protoy/protomods for: trade-route sockets
  (incl. grouping sockets), native sockets, town centers, KotH hill
- players as colored markers in player colors
- resource classes: forests, herds, mines with distinct glyphs
- prerequisite: Layer-1 catalogs (protoy/groupings) provide footprints and
  icon identities deterministically
- checks that need these footprints (grouping-vs-route, grouping-vs-cliff)
  land here too.

---

## Part B — the Layer-2 Terrain Standard (normative)

### B1. Canonical cell state (what the model stores; all meters)
Per grid cell (2 m sampling):

| Field | Meaning | Source |
|---|---|---|
| `ground_h` | floor/ground elevation | init height; area base heights; stamps; carves |
| `water_surface` | height of the covering water plane, or None | sea level; area water surface (base height of a water-typed area); river surface |
| `water_body` | governing water body name, or None | rmSetSeaType / rmSetAreaWaterType / rmRiverCreate |
| `cliff` | cliff type name + component (`interior` / `edge`), or None | rmSetAreaCliffType (+ edge geometry) |
| `owner` | the build step that last wrote ground_h here | build order |

This replaces today's tangle of `water/wdepth/wshallow/painted/cliff/land`
booleans with orthogonal physical quantities. Classes are DERIVED, never
stored. `paint` is intentionally ABSENT (Layer-3 concern; the extractor's
has_paint flag remains only as the invisible-vs-paint-only discriminator in
the layering algebra).

### B2. Derivation rules (each one cited — the whole standard)
1. `depth = water_surface - ground_h` where a water plane exists.
2. **Water is visible** iff `depth > 0` (guide:3068 "terrain below this
   height = underwater").
3. **Depth classes — documented engine scale, NOT the invented per-body
   alpha midpoint** (guide:5610, :5628, :5683-5698):
   - `WADE`  : 0 < depth ≤ 0.5 — walkable, no ships
   - `WATER` : 0.5 < depth < 2.0 — transition (Danube 1.1 lives here)
   - `DEEP`  : depth ≥ 2.0 — ship access
   River fords via rmRiverAddShallow force `WADE` in their radius.
   (This resolves the Crownlands complaint properly: 1.1 m is *water*, its
   three fords are *wade* — and retires the alpha-midpoint invention.)
4. **Land** iff no water plane or `depth ≤ 0`.
5. **Cliff components**: `interior` = spawnable flat top (objects CAN spawn,
   guide:10960); `edge` = the impassable rim band. Raised cliffs
   (cliffHeight > 0 or default 4.0, ref:291) get an edge band whose width is
   the height run; height-0 cliffs are ground with a carved rim only.
6. **Layering algebra** (build order; forensically pinned 2026-08-08/09):
   a. base: rmTerrainInitialize sets ground_h (default 0, guide:3145) and
      paint; "water"/water-body name ⇒ ground_h = sea_level − sea body depth.
   b. area with base height ⇒ writes ground_h (rm ref:285).
   c. area with water type ⇒ writes water_surface (= its base height if set,
      else sea level; Riverina cascade, guide:7772) + water_body; carves
      ground_h to surface − body depth.
   d. river ⇒ same as (c) along its band.
   e. connection ⇒ raises ground_h to its base height where lower; never
      lowers (IW "carves nothing" + Tortuga causeways).
   f. invisible area (no height/paint/water/cliff) with any
      rmSetAreaElevation* call and heightBlend < 2 ⇒ CARVES ground down to
      the sea type's floor (sea − depth(sea_type)) where higher, never
      raising water floors. Forensic 2026-08-09: Civil War's arms BLOCK
      land units (fords/bridges exist ⇒ deep, great lakes2 6 m) and Elbe's
      gulf carries the ship trade route (⇒ ≥2 m, Hansa 3 m) — a height-0
      stamp would make both walkable, contradicting the maps. WW Canyon dry
      templates (no elevation call) and Paris blend-3 masks stay dry.
   g. paint-only area ⇒ writes `paint` only (Australia mountains).
   h. any ground_h/water write REPLACES the cell's cliff (one-shape rule).
7. **Sea level default 0.0** when the call is absent (vanilla behavioral
   evidence; no data-file constant exists).

### B3. Class standard (REVISED per user verification 2026-08-09)
FOUR classes — the spawn-testing vocabulary and the whole display:

| Class | Swatch | Meaning (spawn semantics) | Rule |
|---|---|---|---|
| LAND | green | buildable/walkable ground — INCLUDES cliff interiors (spawnable, guide:10960) | depth ≤ 0 or no water plane |
| SHALLOW | light blue | walkable AND buildable/spawnable (USER-OBSERVED in-game; overrides guide:5351's 0.5 m wade prose) | 0 < depth ≤ 1.0 |
| DEEP | navy | not walkable (ships need depth ≥ 2.0, guide:5610 — checks query the raw depth) | depth > 1.0 |
| CLIFF border | dark brown | the impassable rim band — spawn killer (guide:10960) | cliff edge band only |

Refinements locked in:
- the raw `depth` NUMBER stays in the state (free) so checks can distinguish
  walkable/buildable (≤1.0) and navigable (≥2.0) exactly; the 1.0–2.0 band
  DISPLAYS as DEEP but is not navigable — no check may treat display class as
  depth.
- `paint` is REMOVED from Layer 2 entirely (zero spawn relevance; texture-only
  areas render as LAND). Terrain-color palettes, rock fills, painted tints all
  move to the Layer-3 "for show" backlog.
- cliff interiors are LAND; only the edge band is a class. Underwater cliffs
  are just water cells (border optionally drawn as information, never a class).

### B4. Constants register (every non-documented number, with its recipe)
| Constant | Value | Basis | Re-measurement recipe |
|---|---|---|---|
| SHALLOW threshold 1.0 | USER-OBSERVED | in-game authoring experience (user 2026-08-09); guide's 0.5 wade prose overridden | E9 pins the exact value |
| ship-depth threshold 2.0 | FACT | guide:5610 | — |
| sea default 0.0 | FACT (behavioral) | crownlands/greatbarrierreef vanilla | — |
| SHORE_STANDOFF_M | 13 | CALIBRATED (Elbe probes 2026-07-30) | 3-probe corridor measurement |
| ROUTE_HALF_WIDTH_M | 8 | CALIBRATED (blocksize 16/2) | route pixel width on 3 minimaps |
| RIVER_HALF_WIDTH_CAP_M | 32 | RECALIBRATED 2026-08-09 second pass (lake-calibrated overlay method): low R exact 2R uncapped (crownlands 14->28, riverina 15->30, pixel-hugging); civilwar R=180 band 60-66 m -> cap half 32. Original 27 leaned on elbe, whose river runs inside its estuary — void. | E6 probe map for the knee between 32 and 180 |
| ROUTE_HALF_WIDTH_M | 8 | DATA (traderoutedefs.xml route blocksize=16.0, verified 2026-08-09 — no longer inferred) | — |
| cliff edge run = height | ESTIMATE (45° talus) | needs in-game measurement (E5) |
| growth shapes (flood) | MODEL | research decision 2026-07-30 | golden-grid diffs |
Anything not in this table and not cited in B2 is a bug.

### B5. Open questions → numbered experiments (in-game, not guesses)
- **E5** cliff side run: measure a 6 m cliff's painted footprint in-editor.
- **E6** river width law — PARTIALLY RESOLVED 2026-08-09: width = 2R exact
  and uncapped through R=15 (crownlands/riverina minimap-verified);
  saturation confirmed at R=180 (civilwar ~60-66 m band -> cap half 32).
  REMAINING: the knee between R=32 and R=180 has no measurable corpus
  river (elbe = estuary, kingofbohemia = city-covered, venice = lagoon) —
  probe map with args 40/60/90 still wanted, and whether the cap is an
  engine constant or per-water-body.
- **E7** influence-segment mass distribution — **RESOLVED 2026-08-09 by
  minimap forensics** (no probe map needed): the engine grows an area only
  along segments whose skeleton CHAINS to the disc anchor; a disconnected
  segment cluster gets NO budget mass. Proof: zpaustralia's Uluru mesa
  (anchor 0.5,0.65; stale 4-segment cage at ~0.5,0.41 = 5.6x radius away)
  — the in-game massif sits at the ANCHOR, verified through the rotate-45
  view transform pixel-calibrated on Lake Eyre (0.55,0.45); the old
  "Uluru forms at its segment ring" calibration was a y-flip misread.
  Model: field.connected_influence_segments (tolerance = area radius,
  chain-transitive); corpus survey shows every legitimate skeleton
  (big lone island 25-seg ring, IW/civilwar rivers) is anchor-connected
  (dmin<=0.014), only the mesa cage is not. Dead segments render red in
  the debug overlay. Locked by scripts/maps/goldens/zpaustralia_P{2T2,8T8}
  + byte-identical IW goldens. Bonus finding: the australia minimap is an
  8-PLAYER capture (massif core = 0.33% of map square = the P8 mesa
  interior; star icons do NOT equal player count).
- **E9** exact walkable/buildable depth: probe map with strips at depths
  0.6 / 0.8 / 1.0 / 1.2 — test unit walking + building placement on each
  (user estimates 1.0, possibly 1.2).
- **E8** invisible-stamp scope: does the stamp lower already-water floors?
  (currently: no, per IW author comment) — verify with a probe map.

### B6. Layer-2 test strategy (determinism lock)
Golden CLASSIFIED GRIDS, not pixels: per map+scenario store a compact digest
(class histogram + a fixed 32×32 downsample of class codes). Tests assert
byte-equality; any model change = explicit golden diff in review. Renders are
derived, so they can never drift silently again.

### B7. Migration from today's code (when implementation is approved)
- field.py arrays → the B1 state (ground_h/water_surface/water_body/paint/
  cliff component); wshallow/alpha-midpoint deleted in favor of B2.3.
- render.py palette → B3 table + optional terrain_palette.json.
- checks that consume terrain read ONLY derived classes (never raw arrays).
- the layering debugger (--layers) stays — it renders B1 state per step and
  becomes the standard's living documentation.

---

## Part C — Layer-2 forensics (user request 2026-08-09)

### C1. AUDIT: how the CURRENT system decides minimap colors

Palette constants: render.py:24-32 (WATER navy, SHALLOW blue, LAND green,
CLIFF_EDGE dark brown, CLIFF_FILL rock tan, PAINTED olive). Cell coloring:
render.terrain_rgba (render.py:70-113): `water ? (wshallow ? SHALLOW : WATER)
: painted ? PAINTED : LAND`, then cliff codes overpaint (edge → CLIFF_EDGE
:110; raised interior above water → CLIFF_FILL :112).

Primitive-by-primitive (VERDICT: FACT = documented/measured & cited,
CAL = registered calibration, INV = invented — must die):

| # | Primitive | Current state writes | Current color logic | Verdict |
|---|---|---|---|---|
| 1 | Base water (`rmTerrainInitialize("water")`) | water=True, wdepth=XML depth of sea type (field.py:427) | deep/shallow via per-body alpha-fade **midpoint** (waterdata.shallow_boundary_of, field.py:428) | depth FACT · midpoint **INV** |
| 2 | Base land (texture init) | water=False | LAND green | FACT |
| 3 | Rivers | band = 2·min(avg(args), 27) (xs_extract CAL); wdepth=XML (field.py:547); fords force wshallow in radius | midpoint rule (:548) | width CAL · depth FACT · midpoint **INV** |
| 4 | Water areas (incl. elevated cascade) | water=True, wdepth=XML of area body (field.py:700-705); surface height only via creates_land=False | midpoint rule | FACT + **INV** midpoint; elevated surface not stored (ground_h/water_surface missing) |
| 5 | Land area with height (bh > sea) | land code, water=False (field.py:713-718) | LAND green | FACT |
| 6 | Land patch, no height, WITH paint | painted=True (field.py has_paint branch) | PAINTED **olive — invented color** | **INV** |
| 7 | Land patch, no height, no paint, WITH rmSetAreaElevation* | stamp ground to 0 ⇒ water, wdepth=sea_level (field.py:772) | midpoint vs sea body | rule FACT (forensic) · midpoint **INV** |
| 8 | Land patch, nothing at all (dry template) | marker only | no fill; grey dotted outline | FACT |
| 9 | Cliff, cliffHeight>0 (raised) | cliff code + dilation by height run (ESTIMATE, E5) | interior CLIFF_FILL, boundary CLIFF_EDGE | classification FACT · dilation EST |
| 10 | Cliff height 0 + base height | land/submerged by bh vs sea; rim only | rim CLIFF_EDGE, fill = ground class | FACT |
| 11 | Underwater cliff (bh < sea) | water fill, wdepth = sea−bh; rim | midpoint on sea body | FACT + **INV** midpoint |
| 12 | Connections | ≥sea → land strip; <sea → floor raised, depth sea−bh (field.py:630-637) | midpoint | FACT + **INV** midpoint |
| 13 | Trade routes | no terrain effect; growth keep-out d+8 (CAL) | gold dashed overlay | FACT (overlay) |
| 14 | Constraints | no terrain effect; masks = grey dotted outlines | overlay only | FACT |

Summary of the disease: **one invented rule (alpha-fade midpoint) decides
every water color**, and **one invented color (PAINTED olive)** decides every
texture-only area. Everything else is already fact- or calibration-based.

### C2. PROPOSED deterministic color coding (state-transition table)

Every primitive writes ONLY canonical state (B1); color is a pure lookup of
the derived class (B3). The complete transition table:

| Primitive | ground_h | water_surface / body | paint | cliff |
|---|---|---|---|---|
| base init (land tex, h) | h (default 0) | — | init name | — |
| base init (water) | sea − depth(sea body) | sea level / sea body | — | — |
| river | surface − depth(body) | sea level / river body | — | cleared |
| river ford | unchanged | unchanged | — | — | *(class forced WADE)* |
| water area | surf − depth(body) | bh if set else sea / area body | area mix if any | cleared |
| land area (bh) | bh | — (dry if bh ≥ surface) | area mix | cleared |
| paint-only patch | unchanged | unchanged | mix name | unchanged |
| flat mask (Elevation*, blend<2) | min(ground_h, 0) | unchanged | — | cleared where stamped |
| dry template | unchanged | unchanged | — | unchanged |
| cliff raised | bh if set | per bh vs surface | mix if any | type + edge band (run per E5) |
| cliff h=0 | bh if set | per bh | mix if any | type, rim only |
| connection | max(ground_h, bh) | unchanged | replacement tex | cleared |
| trade route / constraints | no terrain writes — overlay layer only |

Derived class (B2): LAND / WADE (0<d≤0.5) / WATER (0.5<d<2) / DEEP (d≥2) /
CLIFF-interior / CLIFF-edge — thresholds are the guide's documented scale
(guide:5610/:5683), replacing the alpha midpoint everywhere. Paint tints only
via declared terrain_palette.json (unmapped ⇒ LAND + report listing).

### C3. PROPOSED data-source architecture (reusable beyond mapsim)

**Contract — one loader pattern for every catalog** (generalizing
waterdata.py): a catalog is an ordered list of layered sources, first hit
wins, provenance recorded:

```
catalog("waterbodies") = [data/waterbodies.xml (mod), data/waterbodies2.xml (mod),
                          scripts/source/waterbodies.xml (vanilla),
                          scripts/source/waterbodies2.xml (vanilla)]
lookup(name) -> (record, source_layer)   # provenance for reports/debugging
```

**Two override styles — must be explicit per catalog:**
- *record-replacement* files: waterbodies2, clifftypes2, forest2 — a mod
  record with the same name fully replaces the vanilla record.
- *delta-mod* files: protomods, techtreemods, nuggetmods — patches applied ON
  TOP of the vanilla record (protoy + protomods = effective proto). The
  loader for these needs a merge step, not a lookup chain.

**Catalog inventory (present ✓ / to extract ✗ via bar-extract into
scripts/source/, refreshed after every game patch via vanilla-merge):**

| Catalog | Mod layer | Vanilla snapshot | Status |
|---|---|---|---|
| waterbodies | data/waterbodies2.xml (+ data/waterbodies.xml slot) | scripts/source/waterbodies.xml, waterbodies2.xml | ✓ complete |
| terrain types | (data/art/terrain if ever) | scripts/source/art/terrain/terraintypes{,2,3,cherry}.xml | ✓ present |
| terrain mixes | — | scripts/source/art/terrain/mix/*.xml (258 files) | ✓ present |
| cliff types | data/clifftypes2.xml | scripts/source/clifftypes.xml | ✓ (add vanilla clifftypes2 ✗) |
| protos | data/protomods.xml (DELTA) | scripts/source/protoy.xml | ✓ (needs delta merge) |
| groupings | data/art groupings if any | ✗ extract art/groupings | ✗ |
| forests | data/forest?* | scripts/source/forest.xml, forest2.xml | ✓ |
| civs / natives | data/civmods.xml (DELTA) | scripts/source/civs.xml | ✓ |
| nuggets | data/nuggetmods.xml (DELTA) | scripts/source/nuggets.xml | ✓ |
| trade routes | data/traderoutes.xml, traderoutedefs.xml | ✗ extract vanilla | partial |

**Placement**: a standalone `scripts/refdata/` package (no mapsim imports) so
bar-extract/vanilla-merge tooling, Layer-1 name validation, Layer-3 icons and
any future tool consume the same layered catalogs. mapsim's waterdata.py
becomes its first client.

---

## Part D — Map Profiles: per-map single source of truth (user request 2026-08-09, PLANNING ONLY)

### D1. Purpose
One file per map holding everything that is TRUE OF THIS MAP ONLY:
map-specific weirdnesses (odd shallow depths, special spawns, water
groupings, elevation quirks, later terrain-color replacements), plus the
map's own test expectations. Rationale: chasing a global root cause for a
one-map oddity is wasted effort and pollutes the global standard; the
profile quarantines it, documents it, and TESTS it.

### D2. Where
`scripts/mapsim/maps/<stem>.json` — e.g. `scripts/mapsim/maps/zpcivilwar.json`.
- auto-loaded by sim/checks when `--xs` stem matches; absence = pure global rules
- NOT inside randmaps/ (deploy-by-copy ships that folder to the game; profiles
  are tooling, not mod content)
- goldens can sit next to them: `scripts/mapsim/maps/goldens/<stem>_PxTy.json`

### D3. What language
Plain JSON (stdlib, diffable, no code execution — a profile is DATA and must
never contain logic). Free-text `notes`/`evidence` fields substitute for
comments (same convention as the curated scene fixture). Schema versioned via
a top-level `"profile": 1`.

### D4. Schema draft (sections; all optional)
```jsonc
{
  "profile": 1,
  "map": "zpcivilwar",
  "notes": "Star-river map; armies cross the E/W arms at authored fords.",

  "overrides": {              // applied AFTER the global standard
    "areas": {
      "shallow1": {"walkable": true,
        "evidence": "user in-game 2026-08-09: units ford the west arm"},
      "shallow2": {"walkable": true, "evidence": "same, east arm"}
    },
    "rivers":   {},           // width/walkability/extra fords per river line
    "sea":      {},           // sea-level / plane corrections if ever needed
    "palette":  {}            // Layer-3: terrain color replacements
  },

  "expectations": {           // the profile IS the map's test
    "probes": [               // classified-grid assertions at fixed points
      {"at": [0.10, 0.60], "class": "SHALLOW", "why": "west ford"},
      {"at": [0.50, 0.50], "class": "DEEP",    "why": "central pool"},
      {"at": [0.85, 0.25], "class": "LAND",    "why": "player island"}
    ],
    "counts": {"connections": 0, "rivers": 1, "players_spawned": "all"},
    "golden": "goldens/zpcivilwar_P4T2.json"
  },

  "known_issues": [           // accepted findings — CI separates known vs NEW
    {"finding": "OUTSIDE_CIRCLE", "name": "Armored Train*",
     "why": "route corners exit the circle by design"}
  ]
}
```

### D5. Guard rails (so profiles don't rot into a hack pile)
1. **Every override carries `evidence`** (who observed what, when). An
   override without evidence is a lint ERROR — the no-guessing rule extends
   to profiles.
2. **Applied overrides are reported**: every report/render lists
   "profile: N overrides applied" — never silent.
3. **Promotion workflow**: the same override appearing in ≥3 profiles is a
   candidate GLOBAL rule — reviewed, promoted into the standard, deleted
   from profiles. (The current SHALLOW_BUILD_DEPTH_M=1.5 is the worked
   example: today it is global on one map's evidence; under this
   architecture it would have started life in zpcivilwar.json and been
   promoted only after E9 or a second map corroborates.)
4. Profiles never change EXTRACTION (what the script says) — only model
   interpretation and expectations. If a profile needs to lie about the
   script, that is an extractor bug.

### D6. Test integration
pytest parametrizes over `scripts/mapsim/maps/*.json`: run the sim for each
profile's scenarios, evaluate `expectations` (probes, counts, golden digest),
diff findings against `known_issues` — new findings fail, known ones pass.
This is the per-map regression harness the whole effort has been building
toward: one file = one map's contract.

---

## Part E — Layer-1 test architecture: universal suite + template library (PLANNING ONLY, 2026-08-09)

### E1. The split (user directive)
1. **Universal suite** — runs for EVERY map with zero configuration.
   The "is it playable" contract:
   - code validity: parse/crash class (syntax, undefined/duplicate vars,
     missing rmTerrainInitialize) — guide 21.1
   - name validation vs refdata catalogs (water, terrain mix/type, cliff,
     proto, grouping, native civ) — guide 21.2
   - completeness: required files exist (map .xml metadata, minimap images —
     guide ch10), map size/ladder sane, world-circle flag read
   - playability: all players place (ring resolves, spawn ground exists),
     starting units/TC defs present, per-player starting resources within
     reach (mines, huntables/berries), trade route builds if declared,
     natives resolve if declared
   - triggers: DSL parses; every unit/proto/effect a trigger references
     exists (docs/map_trigger_guide.md is the reference)
2. **Template library** — parameterized, REUSABLE checks. A map-specific
   concern is always expressed as template + params, never as per-map code:
   - `player_spawn_complete(count, spawn_class, min_spacing)` — the
     zpflorence player-spawn case
   - `grouping_spawn_complete(pattern, expected, allowed_classes)` — the
     zpparis "did all random blocks/buildings spawn" case
   - `area_class_probe(points[])` — Part D expectations reuse this
   - `ford_crossings_walkable(points[])`, `socket_count_on_route(route, n)`,
     `resource_fairness(kind, per_player_min, radius)`,
     `triggers_present(names[])`, `koth_hill_reachable()` ...
   Discipline: a unique need with no matching template ⇒ FIRST generalize it
   into a new parameterized template, THEN instantiate. That is what makes
   "map specific" reusable for the next map.

### E2. Where things live
```
scripts/mapcheck/                Layer-1 package (no rendering imports)
  runner.py                      CLI: mapcheck <map.xs> [--strict]
  universal.py                   the zero-config suite
  templates/                     one module per family
    spawn.py resources.py groupings.py triggers.py terrain.py
scripts/refdata/                 layered mod->vanilla catalogs (Part C3)
scripts/maps/<stem>.json         THE map profile (amends Part D location:
                                 one neutral home serving mapcheck AND mapsim)
scripts/maps/goldens/...         per-map classified-grid goldens
```
Each template declares `requires: []` or `["grid"]` — static templates run
without the simulator (fast, no matplotlib); terrain-aware ones consume the
Layer-2 classified grid through one narrow interface (class_code/probes).

### E3. Per-map instantiation (profile `tests` section)
```jsonc
"tests": [
  {"template": "player_spawn_complete",
   "params": {"count": "all", "spawn_class": "LAND", "min_spacing_m": 80},
   "why": "zpflorence regression: P5 spawn used to fall back"},
  {"template": "grouping_spawn_complete",
   "params": {"pattern": "EU_block_*", "expected": 12,
              "allowed_classes": ["LAND"]},
   "why": "zpparis random city blocks must all place"}
]
```
Universal thresholds (e.g. mines-per-player) have ONE global default table in
`universal.py`; a profile may override them under `overrides.checks` with the
same evidence-required rule as Part D.

### E4. Runner + CI contract
`mapcheck` = universal suite + profile templates, merged into the same
findings JSON as mapsim (`basis: deterministic|model`, `guide_ref`), diffed
against `known_issues`. pytest parametrizes over `scripts/maps/*.json` so the
whole mod's map roster is one test matrix; exit codes gate CI on
deterministic findings only.

---

## Part F — Basic test set v1 (PROPOSAL, 2026-08-09; forensic + web research)

The concrete first slice of Part E to actually implement. Rule: every check
traces to a documented failure mode (in-repo guide ch.21 or a community
source) or to a bug this project already hit. Nothing speculative.

### F1. What actually breaks maps (research digest)

Failure classes, ranked by how often the sources report them:

| # | Failure class | Evidence |
|---|---------------|----------|
| 1 | **Crash on load: undefined / doubly-defined variable, invalid syntax** (XS is case-sensitive; C-style arrays are invalid) | guide 21.1 (:10450, :10469, :10520, :10543); AOE_Fan tutorial: "map crashes typically indicate undefined variables or syntax errors"; Steam RMS intro: case-sensitivity + redefinition rules |
| 2 | **Crash on load: missing `rmTerrainInitialize()`** | guide 21.1:10508; AOE_Fan: "mandatory for every map"; water base needs `rmSetSeaType` BEFORE the flooded init |
| 3 | **Silent no-spawn: invalid name string** (water type, terrain mix/type, proto, grouping, native civ) — game substitutes a fallback or drops the object, no error surfaced | guide 21.2 (:10738-:10894); AOE_Fan: "verify grouping string matches actual native unit names" |
| 4 | **Silent no-spawn: over-constraint** — constraints leave zero legal cells | guide 21.2:10895 "Spawn on Impossible Location"; AOE_Fan: "over-constrained objects have nowhere legal to place" |
| 5 | **Spawn on impossible terrain** — land objects on water/cliffs, groupings on trade routes | guide 21.2:10895 (the section was ADDED to the guide from real incidents) |
| 6 | **Player placement fallback** — circular placement conflicts ⇒ players bunch at a fallback point | guide 21.3:11058 "Players Circular Issues"; our own find: IW player-6 zero-cell area (layering debugger) |
| 7 | **Randomization branch defines nothing** — e.g. "if whichNative is 4-6, define nothing" ⇒ that roll spawns nothing | AOE_Fan tutorial |
| 8 | **Build-order mistakes** — natives/trade sockets must build before forests/mines/herds so the avoid-constraints can see them | AOE_Fan tutorial; guide "Typical Constraint Workflow" (:2838) |

Community testing practice worth adopting mechanically: **generate the map
several times and at several player counts** (guide 21.6 "2, 4, 6, 8"; Steam
RMS intro: "load the map a few times, or with different player numbers").
`rmEchoInfo` output is developer-only and not player-visible (AOE_Fan) — a
reason to do static analysis instead of relying on in-game echo.

### F2. The basic set — three tiers, ~12 checks

**Tier S — static (extractor only, no simulator, milliseconds).**

| ID | Check | FAIL when | Evidence |
|----|-------|-----------|----------|
| S1 | script parses | xs_extract raises / stops early — report first offending line | class 1 |
| S2 | globals defined-before-use, no same-scope redefinition (globals only — no full scope checker) | undefined use or duplicate `int x =` | class 1 |
| S3 | `rmTerrainInitialize` present; if base is water, `rmSetSeaType` precedes it | missing / misordered | class 2 |
| S4 | every name string resolves in the layered refdata catalogs: water type, terrain mix, proto, grouping, native civ | any unknown name (print it + nearest match) | class 3 |
| S5 | file completeness: matching map `.xml`, `imagepath` minimap PNG exists, loadscreen exists | referenced file missing | guide ch.10 / 21.6 |

**Tier G — grid-backed (Layer-2 classified grid via the narrow
class_code/probe interface).**

| ID | Check | FAIL when | Evidence |
|----|-------|-----------|----------|
| G1 | determinism lock: classified-grid digest == golden | any byte differs | B6 (already built) |
| G2 | players place: each ring anchor resolves, inside world circle, on LAND/SHALLOW; player area claims > 0 cells | any player fails the ladder (reuse checks.py RING_*) | class 6 |
| G3 | spawn legality: every concrete/nominal placement lands on an allowed class (land objects not on DEEP or CLIFF band; ships/docks touch water) | class violation | class 5 |
| G4 | over-constraint: a placement whose constraints exclude every cell of its target area | zero legal cells | class 4 |
| G5 | reachability (lite): flood-fill walkable classes from each player spawn; on a map with NO navigable water, every player pair must connect | unreachable pair on a land-only map; water maps: INFO-level matrix only | "is playable" core; IW causeways / Hawaii connections are the regression cases |

**Tier M — the matrix.** Run S+G at P2T2, P4T2, P8T8 (goldens per scenario —
IW already has P2T2+P8T8). This IS the community's "test at 2/4/6/8" advice,
automated. No random reseeding in v1 — the sim is nominal-deterministic, so
"load it a few times" is covered by the scenario axis, not a seed axis.

**Ordering note (class 8):** v1 does NOT verify build order — it falls out of
G4 (a mine over-constrained because the socket built too late shows up as
zero legal cells). A dedicated order lint is v2 if G4 proves too blunt.

### F3. Starter templates (three, each with a named real-map case)

Only templates with a concrete customer now; the rest of E1's list is backlog.
1. `player_spawn_complete` — zpflorence P5-fallback case (params: count,
   spawn_class, min_spacing_m).
2. `grouping_spawn_complete` — zpparis "all random city blocks placed"
   (params: pattern, expected, allowed_classes).
3. `area_class_probe` — Part D expectation probes (Civil War ford = SHALLOW,
   Crownlands Danube = DEEP); this is how profile evidence becomes a test.

### F4. Non-goals for v1 (the no-overengineering line)

- NO balance/fairness scoring (resource distance symmetry etc.) — needs a
  standard we don't have; matrix + G2 covers the crash-level version.
- NO trigger DSL validation — separate catalog work (map_trigger_guide.md);
  S4's name checking is the hook to extend later.
- NO full XS type/scope checker — S2 is globals-only on purpose.
- NO branch-completeness lint (class 7) yet — detection needs value-set
  tracking through rmRandInt; revisit after S4 shows how often it fires.
- NO per-map goldens for the whole roster — start with the 13 simulated maps.

### F5. Sources

In-repo: random_map_generation_guide_v2.md ch.21 (:10394-:11248, checklist
21.6 :11212), plan_mapsim_testing_refactor.md (taxonomy inventory),
map_trigger_guide.md (trigger hook, deferred).
Web (2026-08-09): AOE_Fan's RMS Command Tutorial
(therassaskjasd.catsboard.com/t339); "An Introduction to Random Map
Scripting" (steamcommunity.com/sharedfiles/filedetails/?id=155256742);
ESOCommunity RMS resource thread (eso-community.net/viewtopic.php?t=4749,
index of the above); official support articles 8478836252564 +
8478444858388 (fetch-blocked 403 — titles/scope only); aoe3-rms-dump
(github.com/peschmae/aoe3-rms-dump, vanilla script corpus for S4 spot
checks). forums.ageofempires.com t/104902 checked and EXCLUDED — it is the
AoE2 guide, not AoE3.

---

## Part G — BUILD PLAN (user request 2026-08-09): mapcheck v1, profiles, skills

Execution order G0→G6. Each work package has a done-when gate; no package
starts before the previous gate is green. Layer 3 (grouping rectangles +
object icons on the simmap) begins only after G6.

### G0. DECISION — profile = one JSON per map, tests read it, never own it

The question: JSON overrides vs folding overrides into the map test suite.
**Answer: JSON profile, one file per map (`scripts/maps/<stem>.json`), and
the test suite contains ZERO per-map data.** Reasons:
1. The same override must steer BOTH mapsim generation (e.g. a verified
   walkable depth) and mapcheck expectations. Two homes = guaranteed drift.
2. Part D's guard rails (evidence-required, promotion workflow) are
   mechanically enforceable on data; on Python test code they are a code
   review hope.
3. Claude skills can author/patch JSON against a schema far more safely
   than they can write test code.
4. Map-specific LOGIC still lives in Python — but only as parameterized
   templates (E1); the profile instantiates them. "Specific test" =
   template + params + why, always.

### G1. `scripts/refdata/` — layered catalogs (prereq for S4)

- `refdata/__init__.py` — one public surface: `catalog(kind)` with kinds
  `water | proto | grouping` (v1; `terrain_mix`, `native_civ` = v1.1 if
  trivial). Mod-first layering per C3: record-replacement for water,
  delta-merge for protomods over protoy.
- `waterdata.py` stays where it is (mapsim imports it); refdata re-exports
  it — no churn in working code.
- Sources already on disk: `data/protomods.xml`, `scripts/source/protoy.xml`,
  grouping files, water XMLs. NO new extraction needed for v1.
- Tests: `refdata/tests/` — layering order (mod name shadows vanilla),
  unknown-name miss, nearest-match suggester (difflib, for S4 messages).
- **Done when:** pytest green + `catalog("proto")` resolves 5 spot-check
  names from a vanilla map and 5 mod names from an Age of Pirates map.

### G2. `scripts/mapcheck/` — universal suite (Part F Tier S+G)

```
scripts/mapcheck/
  __init__.py
  finding.py      Finding dataclass: id, severity(FAIL|WARN|INFO),
                  basis(deterministic|model), message, map, scenario,
                  line, guide_ref
  universal.py    S1-S5 (static) + G2-G5 (grid) as pure functions
                  Extraction/TerrainGrid -> [Finding]
  runner.py       CLI: python -m scripts.mapcheck <map.xs>
                  [--scenario P2T2] [--matrix] [--json out] [--strict]
```
- S-checks consume `xs_extract.Extraction` only (fast path, no matplotlib
  import). S2 = globals-only pass over the token stream (define-before-use,
  same-scope duplicate) — extractor already tokenizes; no new parser.
- G-checks consume the Layer-2 grid through TWO entry points only:
  `TerrainGrid.class_code(i,j)` and `TerrainGrid.digest()`. No reaching
  into wdepth/wwalk internals — that keeps Layer 1 honest when Layer 2
  evolves.
- G5 reachability = one scipy-free flood fill over class∈{LAND,SHALLOW};
  navigable-water presence check gates FAIL vs INFO (F2 rule).
- Exit codes: 0 clean / 1 FAIL present / 2 crash. `--strict` promotes WARN.
- **Done when:** unit tests on synthetic fixtures (one per check: a script
  missing terrainInit, a bogus proto name, an over-constrained placement,
  a two-island no-water map...) + runner produces findings JSON on
  Independence War with zero FAILs.

### G3. Map profiles — schema, loader, two pilots

- `scripts/maps/schema.md` — the D4 schema frozen to v1 fields ONLY:
  `map, version, evidence[], overrides{water_depth_m{}, walkable{}},
  expectations[probes], tests[{template,params,why}], known_issues[]`.
  Everything else in D4 stays "reserved".
- `scripts/mapcheck/profile.py` — hand-rolled validator (no jsonschema
  dep): unknown key = FAIL, override without matching `evidence` entry =
  FAIL (the D5 guard rail, now mechanical).
- Consumers: mapsim reads `overrides` (waterdata lookup consults profile
  before catalogs); mapcheck reads `expectations`+`tests`+`known_issues`
  (findings diffed against known_issues → suppressed but listed as INFO).
- Pilots: **civilwar** (the 1.5 m ford evidence — promotes the
  SHALLOW_BUILD_DEPTH_M story into data) and **zptortuga** (island spawn +
  underwater-cliff constraints).
- **Done when:** both pilots validate, mapsim renders civilwar identically
  (digest unchanged — override matches the constant), mapcheck consumes
  both without special-casing.

### G4. Template library — the three starters (F3)

- `scripts/mapcheck/templates/__init__.py` — registry:
  `TEMPLATES: dict[str, callable(params, ctx) -> [Finding]]`; ctx bundles
  extraction, grid, profile, scenario.
- `templates/spawn.py` → `player_spawn_complete`;
  `templates/groupings.py` → `grouping_spawn_complete`;
  `templates/terrain.py` → `area_class_probe`.
- Registry rule (E1 discipline, enforced): runner FAILs on a profile
  referencing an unregistered template — the error message says "generalize
  into a template first".
- **Done when:** civilwar profile runs `area_class_probe` on the ford
  (expects SHALLOW) and Crownlands on the Danube (expects DEEP) — both
  green; one deliberately-wrong probe goes red.

### G5. Claude skills — two skills, thin, pointing at real commands

```
.claude/skills/mapcheck/SKILL.md       "run + read the map checker"
.claude/skills/map-profile/SKILL.md    "author/patch a map profile"
```
- **mapcheck skill:** canonical invocations (single map, --matrix, roster
  via pytest), how to read findings JSON (severity/basis semantics, the
  known_issues diff), the triage ladder: real map bug → fix the .xs;
  engine weirdness verified in-game → profile entry; simulator gap →
  mapsim issue, NEVER a profile hack. Links Part F IDs to guide ch.21
  sections so the agent cites evidence in reports.
- **map-profile skill:** schema v1 field-by-field, the evidence-required
  rule with a worked example (the civilwar ford entry), the promotion
  workflow (observe → in-game verify → record evidence → override), and
  the hard DON'Ts (no override without evidence; no new schema keys; no
  per-map Python).
- Both skills carry a "verify before trusting" preamble: run the command,
  read the output — never assert results from memory.
- **Done when:** invoking each skill cold in a fresh session produces a
  correct run/edit on a pilot map (manual spot check).

### G6. Pilot gate — prove it on three maps, then stop

- Roster: **Civil War** (profile-heavy), **Independence War** (golden
  fixture, causeways), **Hawaii** (team sections + connections — the
  historical trouble spot). Run full matrix (P2T2/P4T2/P8T8).
- Triage every finding to one of: real map bug (fix in .xs, rerun),
  known_issue (record with evidence), checker bug (fix mapcheck).
  Target: three maps, zero unexplained findings.
- Add the roster pytest (`test_roster.py` parametrized over
  `scripts/maps/*.json` + S-tier over all 13 simulated maps) to the
  standard test run.
- **Exit criteria for Part G = entry ticket for Layer 3** (grouping
  rectangles, protoy-derived icons, player colors on the simmap — Part A
  Layer 3 scope). The findings JSON already carries placements with
  positions/classes, so Layer 3 is a renderer over existing data — no
  checker rework expected.

### G7. Explicitly deferred (recorded so they don't sneak back in)

Branch-completeness lint (F4), trigger validation, terrain_mix/native_civ
catalogs (unless trivial during G1), fairness metrics, seed-variance
testing, goldens beyond the 13 simulated maps, any new mapsim rendering
work before G6 exits.

### G8. Build log (2026-08-09) — ALL GATES PASSED

- G1 DONE: scripts/refdata (water/proto/grouping, mod-first). Vanilla
  groupings ship as LOOSE files under <install>/Game/RandMaps/groupings
  (not in .bar) — snapshotted 466 stems to scripts/source/
  groupings_index.txt. Grouping resolution implements the prefix-variant
  mechanic incl. significant trailing spaces. Lesson locked in tests:
  grep sees commented-out XML, parsers must not (Arsenal / Florence
  MAPMODS block).
- G2 DONE: scripts/mapcheck (finding/locate/universal/runner + 7
  synthetic fixtures). Deviation: S2 is duplicate-declaration only
  (same-block, brace-id precise); define-before-use deferred to G7 —
  a naive version false-positives, extractor warnings already surface
  unknown identifiers. Extraction-path goldens live in
  scripts/maps/goldens/ (the curated-scene goldens in mapsim/tests/
  goldens/ are a DIFFERENT pipeline and stay).
- G3 DONE: schema.md + profile.py (unknown-key + evidence guard rails
  mechanical), waterdata.depth_overrides context (all depth paths flow
  through depth_of). Override-identity digest gate proven on fixture.
- G4 DONE: registry + player_spawn_complete / grouping_spawn_complete /
  area_class_probe; profile expectations are area_class_probe sugar;
  unregistered template -> FAIL "generalize first".
- G5 DONE: .claude/skills/mapcheck + map-profile.
- G6 DONE: pilot matrix 0 FAIL on zp_z_z_zcivilwar2 /
  000_independence_war / zp_z_hawaii; roster S-tier green over all 33
  mod maps (test_roster.py, OPEN_STATIC backlog with stale-entry guard).
  279 tests green total.
- Extractor fixes en route (falsified-by-corpus): `%` operator
  (tokenizer+parser+eval, zpBalearicIslands:945), `>`/`>=` for-loop
  shorthand (zpunknown:7986), rmPlacePlayer literal-coordinate ring
  fallback (civilwar 2-player branch).
- OPEN map bugs found by the tool (content decisions, user's call):
  zpBalearicIslands TreeMediterranean (proto nonexistent — starting
  trees never spawn), zpeyrebasin+zpwildwest zpTradingPostCaptureInvisible
  (proto only in commented-out protomods block), zpunknown
  Rogue_Factory_Japan grouping (only _North/_South exist),
  zptortuga/zptorresstrait/zpzealand machine-local grouping paths
  (branch-gated, invisible to fixed-scenario extraction),
  zp_z_cookislands missing lobby .xml.
- Layer 3 (grouping rectangles + object icons over the simmap) is now
  UNBLOCKED per the G6 exit criteria.
- Post-gate (2026-08-09): CLIFF RULE, FINAL FORM (after three iterations
  with the user): the cliff border is the area's BUILD-TIME GROWN CLAIM
  (TerrainGrid.cliff_claims) - the growth model's shape under the area's
  own constraints and influence segments - captured when the area builds
  and NEVER eroded by later builds. User diagnosis that settled it: "the
  code was not that bad, the problem was overriding cliffs with other
  land areas on top." The forensic numbers that exposed the problem:
  one-shape erasure left 8-20% crescent leftovers (elbe shoreLines
  109/~1300 cells, IW docks 32/300, riverina upper west 464/5080) which
  rendered as unauthored half-moons. Authored-circle and raised-only
  display variants were tried and rejected (circles ignored constraints/
  segments; raised-only was interpretive). ENGINE RULE (user-verified
  in-game): placement blocking persists on a cliff's footprint even
  after ramps/later terrain replace it - an RM generation bug the model
  reproduces: cliff_band persists under land-area overrides (water still
  clears it; flooded ground blocks as water). IW goldens regenerated
  (+91 CLIFF cells). Honest limitation: engine-placed cliff areas draw
  nothing; partial authored rims (cliffEdge fractions) draw full.
- Post-gate (2026-08-09): RECT-MAP COORDINATE RULE pinned — the engine
  reads RIVER waypoints as fractions of SIZE_X on both axes, while trade
  routes/areas/objects use true per-axis fractions. Evidence: wwcanyon
  (400x560) authors its river to z=1.4 = exactly 560 m, minimap confirms
  full span with the t=0.5 ford at map center; routes reach the far edge
  with plain 1.0; vanilla rect maps (Baja/Pampas/Colorado/Araucania)
  keep routes 0..1. The lost Discord author formula, reconstructed:
  z_authored = z_wanted_frac * sizeZ / sizeX (rivers only). bridge.py
  converts river waypoints to per-axis fractions; overshoot past the
  edge clips like in-game (paris Seine). Measurement toolbox note: rect
  minimaps crop with longer side = disc diameter (ratio 1.0), square
  minimaps at 0.833.
- Post-gate (2026-08-09): E7 resolved and fixed (see B5) —
  field.connected_influence_segments drops anchor-disconnected segment
  clusters at all four consumption sites (shapes, seeds, water features,
  render overlay); Australia's Uluru now builds as ONE massif at its
  anchor matching the minimap; zpaustralia goldens locked; 279 tests
  green with IW goldens byte-identical.
- Post-gate (2026-08-10): PLAYER RING CONVENTION pinned (the "Civil War
  forts" bug; user diagnosis "X is z and vice versa"). Circle fraction s
  sits at position angle 90° − s·360° — s=0 at authored NORTH (+z),
  increasing CLOCKWISE toward +x: pos(s) = (0.5 + r·sin 2πs,
  0.5 + r·cos 2πs), the x/z swap of the naive math convention. Full
  rings (section 0..1) produce the same uniform point set either way,
  so only SECTIONED team maps exposed the transpose — why the bug read
  as "mostly Civil War". Evidence: (1) zpunknown's bay ladder pairs 8
  bay compass locations with the player section placed opposite — the
  formula fits all 8 exactly and no other convention does; (2)
  zpcivilwar's P2 branch places both players literally at z=0.25
  (south, mirrored about x=0.5, minimap forts confirm) and its P4+
  sections (0.28-0.4 / 0.6-0.72) reproduce that design only under this
  formula; (3) the official RMS doc's clock reading agrees in rotation
  direction. Same commit models rmPlacePlayersLine: per-team lines,
  players evenly spaced ENDPOINTS INCLUDED in lobby order
  (zpbarrierreef widens its line span with player count to hold
  spacing — interior-only slots would collapse its 2-player lines);
  unlocks bluemountains/paris player anchors. Implementation:
  xs_extract.ring_positions (single shared site). Grouping-side
  verification the same day: Civil War's 11 grouping anchors proved
  correct end-to-end by magenta-cross debug overlay
  (MAPSIM_DEBUG_ANCHORS=1) + sub-pixel affine fit + 50% minimap blend —
  the Inventors socket landed within 2 m of its authored posx/posz.
  Open question (nominal): slot phase within a section arc (slot-start
  vs slot-center) — needs an in-game probe.

## Part H — Constraint-reactive grouping placement (BUILT 2026-08-10)

Build outcome (same day; 287 tests green): gsolve.py implements the
deterministic solver exactly as planned, with two evidence-driven
adjustments discovered during the build:
- Class/area/terrain distances evaluate against the GROWN grid's
  chamfer fields (TerrainGrid.class_cells newly exposed), not authored
  discs — a mesa's authored disc covers the valley corridors its grown
  claim leaves open (wwcanyon's whole annulus read as blocked until
  this switch; growth-side class distance already worked this way).
- PINNED groupings (max_dist 0) register their units in the placed-type
  registry BEFORE terrain growth — IW's water avoids the bridge's 14
  zpBridgeFace units in build order. This replaced the curated scene's
  "zpBridgeFace" class shim (the real map only adds classPlateau); the
  IW goldens were regenerated after visual verification (dock cliff
  rings intact; ~100 cells shifted where point-based clearance differs
  from the old 80x28 rect approximation, and dock-site land ownership
  legitimately passes to the later-built playerHills).
Type matching consults protoy UnitTypes (proto_counts_as); exact-name
matches cover literal sockets (SocketApache, SocketTradeRoute).
rmCreateTypeDistanceConstraint's old class_distance placeholder is
gone. Verified live: wwcanyon mosques scatter >= 70 m apart from each
other's sockets (both placed), tortuga carib villages solve INSIDE
their islands' grown land, paris rolls ONE monastery per spot
(suppressed alt-arm counter in the render title).

User reports driving this (all verified forensically the same day):
- WW Canyon: multiple groupings stacked at one spot, ignoring
  constraints. Root cause: its four Sufi villages are ALL anchored at
  (0.5,0.5) with a 20 m..half-map search annulus and mutual avoidance
  (avoidSufi = 70 m from "SocketApache" — a unit INSIDE each placed
  village); the maltese labs / jewish villages use 70 m annuli with
  mountain/route/water constraints. The engine scatters them through
  the feasible region; the sim stamps them all at the anchor.
- Tortuga: Carib villages "missing". Root cause: rmPlaceGroupingInArea
  boxes draw at the target AREA'S RAW ANCHOR — tortuga's islands
  anchor at map edges ((1.0,0.7), (0.3,0.0), (0.1,0.9)) so the boxes
  pin half-off the edge instead of inside the island's grown cells.
  (Extraction itself is fine: refs resolve, footprints exist, install
  groupings dir found.)
- Paris: spawn chance not considered — jesuitMaltese = rmRandInt(1,2)
  is Tainted, the both-arms policy places maltese AND jesuit at BOTH
  mirror spots (4 boxes where the game rolls 2).

Repo-wide constraint-kind inventory for grouping constraints (script
scan 2026-08-10): type_distance 240, terrain 201, class_distance 89,
pie 50, terrain_max 41, route_distance 16, area_avoid 8, area_max 1.
29 maps place groupings with a non-zero max-distance annulus.

H1. Constraint spec completeness (xs_extract).
    Extract specs for the kinds groupings actually use and that the
    solver must evaluate but the constraint dict does not yet carry:
    rmCreateTypeDistanceConstraint -> {kind: type_distance, type,
    distance_m}; rmCreateAreaConstraint -> {kind: area_avoid, area
    name} (verify avoid-vs-inside semantics against the guide before
    coding); rmCreateTerrainMaxDistanceConstraint -> {kind:
    terrain_max, ...}; rmCreateAreaMaxDistanceConstraint. Groupings
    keep their constraint name lists (already carried end-to-end).

H2. Placed-type registry (new, small module).
    {unit_type_lower: [(x_m, z_m), ...]} accumulated in BUILD ORDER:
    trade-route socket defs, per-player starting defs at ring nominals
    (TCs), object defs with concrete anchors, and every SOLVED
    grouping's units (type = element text in the grouping XML, position
    = solved anchor + unit offset). Type matching must consult protoy
    UnitTypes so abstract names ("townCenter", "sockettraderoute")
    match concrete protos; unresolvable types mark the constraint
    UNEVALUATED (honest), never silently satisfied.

H3. Deterministic annulus solver (field/new solver module).
    Placements processed in SCRIPT ORDER. For each grouping placement:
    max_dist == 0 -> anchor as today (Civil War unchanged). Else
    search the annulus [min_dist, max_dist] around the anchor for the
    NEAREST cell satisfying ALL evaluable constraints (terrain, class,
    route, pie, box, area_avoid, type_distance vs the registry);
    tie-break clockwise from north (the pinned ring convention).
    in_area placements search INSIDE the area's claimed cell set
    (nearest to the area centroid) under the same constraints — fixes
    tortuga. Point feasibility only — grouping XMLs carry
    ignoreplacementrules=1, so no invented footprint clearance. On
    success: solved (x,z), approx flag when moved, deposit unit types
    into the registry AND footprint cells into rmAddGroupingToClass
    classes (so avoidMountains-style class constraints react to
    earlier groupings). On failure: stay at anchor, CONSTRAINT_UNSAT
    (existing finding), red-edged box. Deterministic throughout; the
    engine's random scatter inside the feasible region is the honest
    limitation (tether display, H5).
    NOMINAL RULE DECISION: nearest-feasible-to-anchor (mathematical
    precision doctrine; alternative considered and rejected: fake
    low-discrepancy scatter).
    NOTE ordering: solver runs AFTER terrain build (needs the class
    grid) but replays placement calls in authored order.

H4. Spawn-chance variants (bridge selection rule).
    Placements already carry the tainted-if variant path
    (XPlacement.variant). New nominal rule: for each tainted if, KEEP
    placements only from the NOMINAL arm — rand conditions resolve by
    rolling lo (rmRandInt(1,2) -> 1), matching the "first variant =
    deterministic nominal" precedent from prefix resolution; state
    stays last-write-wins (unchanged). Paris then shows exactly one
    monastery per spot (maltese west / jesuit east, the lo-roll).
    Alternative arms are dropped from display but counted in reports
    ("N alternative-variant placements suppressed").

H5. Render.
    Box at the SOLVED spot (colors unchanged). When solved != anchor:
    thin dotted tether anchor->box + tiny hollow anchor dot, so
    engine-side scatter uncertainty stays visible. UNSAT = red edge at
    anchor. Legend entries for tether and unsat.

H6. Verification gate.
    Unit tests: annulus (min ring honored, nearest chosen, clockwise
    tie-break), type-registry chains (4 same-anchor mosques end >=70 m
    apart), in_area interior solve, variant lo-roll selection,
    max_dist=0 maps byte-identical (civilwar goldens). Integration:
    wwcanyon (no overlapping mosque/lab boxes, labs off the
    mountains), tortuga (villages inside their islands), paris (one
    monastery per spot). Full suite + 13-map re-render + minimap
    compare + artifact republish.
