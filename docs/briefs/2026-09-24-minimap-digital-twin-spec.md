# Specification: the minimap digital twin (`mapview`)

This specification was written on 2026-09-24 for the agent that builds and tests it on another device. The owner
asked for exploration and specification only; nothing here is built yet. Every fact below comes from a read-only
survey of this repository, with file:line references; re-check line numbers before relying on them.

## 1. Goal

**One coordinate system shared by every tool.** Every random-map object is known in world metres (x, z). The tool
can then convert, in both directions, between:
- the map script and its simulation (`scripts/mapsim`);
- the saved generation (census of a `.age3Yscn`);
- the minimap in the Scenario Editor and in a running match (screen pixels);
- the camera in the running game (move it to a world point and photograph it).

**What this enables:**
- **Automatic spawn checks, in the editor:** every expected object is compared with what spawned, and each
  problem is photographed zoomed on the object.
- **Focused in-game documentation:** "photograph the London dock quay of player 3", "record 60 s at the enemy
  construction block". This replaces colour-cluster guessing: `scripts/aitest/snapshots.py` today clicks
  player-colour pixels and produced mostly irrelevant pictures.
- **A world-coordinate layer on the AI's echoes:** positions the AI logs (`LONDONPLACE ... at x/z`) can be drawn
  on the twin and photographed.

## 2. What exists (reuse it; code is LEGO)

| Piece | Where | What it gives | Limits |
|---|---|---|---|
| **mapsim** | `scripts/mapsim/` (CLI `sim.py`, about 152 tests) | a mini XS interpreter (`xs_extract.py`) that folds `rmSetMapSize` per scenario; placements solved to map fractions (`gsolve.py`); a terrain grid of land / shallow / deep / cliff (`render.py:92-116`); a minimap-style render (`render.py:173-186`, rotate +45 degrees, circle crop = the longer side) | approximate: random calls are "tainted", both arms of a tainted `if` run, player positions are nominal (`xs_extract.py:603-701`); no pixel coordinates |
| **census** | `sandbox/census/census.py` (decoder), `scripts/scenview.py` | a saved generation into units: proto, position; `scenview.py` also gets the player (u16 at tag+68) and position at tag-48 | `census.py` CLI resolves protos with an old lookup (`:121-125`; use `census()`, `:104`); no player; map size and terrain planes not decoded (`scenview.py:17-19`); `scenview` assumes 600 m |
| **editor driver** | `sandbox/census/editor_regen.py`, `gamewin.py` (skill **rm-census**) | File > New > map > seed > Generate > save, a load-bar poll, any monitor | 2560x1080 sheet only; the editor minimap crop box is not in the repo (it lives in an off-repo `load_map.py`, skill **map-minimap**) |
| **in-game driver** | `scripts/aitest/driver.py`, `probe.py`, coords sheets | clicks, pixels, screenshots; `minimap_center` (2880x1800: 2641,1562; 2560x1080: 2320,900) | centre only: no radius, scale or orientation; primary monitor only |
| **coordinate rules** | skill **rm-coordinates** | the minimap rotation: visual top = code (1,1), left = low x / high z; `u = (x - z)/sqrt2, v = (x + z - 1)/sqrt2` | never measured against pixels; the world-circle radius is 0.455 in the skill but 0.5 in `geometry.py:21-24` (unresolved) |
| **map size** | e.g. `zplondon.xs:397-408`: 360 x 645 / 685 / 765 m by player count | rectangular maps | the census does not record the size |

## 3. What to build

### 3.1 `scripts/mapview/transform.py`: the core, pure functions with no game needed

- `world_to_frac(x_m, z_m, size_x, size_z)` and back. 1 tile = 2 m (`scripts/mapsim/units.py`).
- `frac_to_minimap(fx, fz, cal)` and `minimap_to_frac(px, py, cal)`, where `cal` is a calibration record (3.2):
  - the rotation;
  - the aspect of rectangular maps;
  - the circle crop;
  - the centre, scale and sign per screen.
- Round-trip exact to 1 px. Unit-tested against the rm-coordinates rule and against mapsim's render transform
  (`render.py:181-186`); both must agree.

### 3.2 Calibration: measured, never assumed (per screen kind and resolution)

A record `scripts/mapview/cal/<screen>_<WxH>.json` for each of `ingame` and `editor`, holding:
- the minimap centre in pixels and the pixels per map fraction on u and v;
- how a rectangular map fills the disc: the longer side or the diagonal;
- the sign of each axis.

**Method:** generate a known map in the editor (the **rm-unit-bench** / **map-minimap** flow). Place 3+ distinctive
units at known world coordinates (map corners, map centre, one off-axis point). Screenshot the minimap, find their
pixels, and solve the affine transform from the least squares of the 3+ pairs.

**Acceptance:** each calibration point within 2 px, and a 4th independent point within 3 px.

Resolve the world-circle radius (0.455 vs 0.5) as a side result, and write the answer into the rm-coordinates skill.

### 3.3 Twin assembly: `scripts/mapview/twin.py <map.xs> [--players N --teams T] [--census file.age3Yscn]`

- **Expected:** mapsim's scene for that player setup: objects with proto, player, fraction position and the
  authored anchor (the object def or grouping name), plus the terrain grid.
- **Actual** (optional): census units with proto, player and world position. First fix `census.py`: use
  `census()` for names, add the player from `scenview`'s layout, and read the map size from the save or pass it in.
- **Join** expected to actual per proto and anchor: nearest-within-tolerance matching per proto, and report the
  unmatched on both sides.
- **Output:** `twin.json` (every object in world metres, fractions, minimap pixels for every calibrated screen,
  plus its match status) and a render `twin.png` in minimap orientation with problems circled.

### 3.4 Camera and capture: `scripts/mapview/camera.py`

- `goto(world_x, world_z, screen)`: click the minimap pixel from the transform. Verify: the minimap's white camera
  trapezoid centre (visible in the HUD minimap) lands within 3 px of the target.
- `shot(world_x, world_z, name)`: goto, park the mouse off the minimap (its tooltip covers it: measured in
  `snapshots.py`), wait 2.5 s, full screenshot plus a crop around the screen centre.
- `record(world_x, world_z, seconds)`: goto, then an ffmpeg capture of that window (the driver has `--record`).
- **Owner's rules:** it moves the camera only. It never selects or orders units and never clicks outside the
  minimap. It never kills or launches the game. The first click after a focus change is eaten.

### 3.5 Uses to wire in once the core passes

1. `snapshots.py` becomes a list of world targets: the AI's echoed positions (`LONDONPLACE`, `LONDONSETUP`), each
   base's Town Center from the census, the construction blocks, the dock quay stretches.
2. **Editor spawn check:** generate, save, census, twin, and a picture of every unmatched expected object (a
   **mapcheck**-style finding list).

## 4. Tests (the builder's own gate)

- **Offline, pytest:** transform round-trips; agreement with mapsim's render; calibration fitting on synthetic points
  with noise; twin join on a fixture (the independence_war scene plus a small saved census).
- **In the editor** (only on the owner's word, per the rm-census rules): calibrate both screens at the builder's
  resolution. Generate London 3v2, census it, and check the London bridge, both construction blocks and the four
  Keeps against the twin within 4 m.
- **In a match:** `goto` the enemy construction block and verify the camera trapezoid. Photograph it; the picture
  must show the block (a human check once, then the recorded pixel acceptance).

## 5. Known traps

- Screenshots downscaled for review do not map 1:1 back to screen pixels (a 1000 px copy is 2.88x on 2880). Always
  compute on full-resolution pixels.
- Minimap button edges and frames are gradients. Measure where a probe sits; never shift one unmeasured.
- Map size depends on the player count (London: 645 / 685 / 765 m long).
- Fog: unexplored areas are black on the in-game minimap. The transform does not depend on what is visible;
  colour-based detection does.
- The AI's `kbUnitGetPosition` and the census positions are world metres; the map script's `rmEchoInfo` values are
  metres too, but no file carries them after generation (only the census does).

## 6. Hand-off

- **Branch:** `Pirate-rework`. **Owner rules:** AGENTS.md, the skills rm-census, rm-coordinates, map-minimap,
  ui-calibrate and game-startup.
- **Deliverables:**
  - `scripts/mapview/` with tests;
  - calibration JSONs for the builder's resolution;
  - a short skill `.claude/skills/minimap-twin/SKILL.md` (how to calibrate, build a twin, aim a shot);
  - `snapshots.py` migrated to world targets.

## 7. Corrections found while building (2026-09-24, the main session on the owner's device)

- **Census positions:** a unit's own position is the fixed header BEFORE its `UN` tag (x/y/z at tag-49 on the current build,
  tag-48 on older saves, followed by an orthonormal 3x3). `sandbox/census/census.py` used to read the NEXT record's header
  (section 2's "position at tag-48" was one byte off on today's build). Fixed in `scripts/mapview/census_reader.py`.
- **Owner:** not at tag+68 (that is the proto / post-id area). It is the u16 20 bytes before the header start: 1..N on every
  per-player object, 0 elsewhere (London, Elbe, bench saves).
- **Map size:** the engine rounds `rmSetMapSize` to whole 2 m tiles (London 4p asks 685 m, the save and the minimap use 686 m);
  the save's terrain header holds the exact tile counts.
- **World circle / disc:** measured, the minimap disc's diameter is the map's longer side (editor rim 130.5 px at 2560x1080,
  centre (2269.33, 920.33)); the drawn map is centred on the ring within 0.2 px. The 0.455 in rm-coordinates is a placement
  margin, not the disc.
- **Player stars on the minimap are the EXPLORERS**, not the town centres or command posts.
- **Camera trapezoid:** its aim point is the intersection of the outline's diagonals, not the outline's centroid (7-10 px apart).
