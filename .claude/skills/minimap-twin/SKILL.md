---
name: minimap-twin
description: One world coordinate for the map script, the saved generation, the minimap and the in-game camera (scripts/mapview). Use to calibrate a screen's minimap, build the twin of a map (expected objects from mapsim joined with the census of a save, problems circled), aim the camera at a world point and photograph or record it, or convert metres / fractions / minimap pixels either way. Triggers on "minimap pixel", "where on the minimap", "photograph the enemy base", "record at the bridge", "spawn check", "twin", "calibrate the minimap", "world coordinate".
---

# The minimap digital twin (`scripts/mapview`)

Specification: `docs/briefs/2026-09-24-minimap-digital-twin-spec.md`. Everything below is offline except the
camera; the camera moves nothing but the camera.

## Coordinates in one line each

- Metres (x, z) <-> fractions (fx, fz): divide by the map size; London is 360 x 645 / 685 / 765 m by player count
  (`zplondon.xs` around line 400); 1 tile = 2 m.
- Fractions -> minimap plane: `u = (dx - a dz) / sqrt2`, `v = (dx + a dz) / sqrt2`, dx = fx - 0.5, dz = fz - 0.5,
  a = size_z / size_x. Visual top = code (1,1), right = (1,0), left = (0,1). Agrees with mapsim's render and the
  rm-coordinates skill (tested).
- The disc: its diameter is the map's longer side (mapsim's world circle 0.5 times max(1, a)); the 0.455 in
  rm-coordinates is the safe placement margin, not the disc.
- Pixels: `px = cx + s u`, `py = cy - s v`, s = disc radius in px / disc radius in display units. cx, cy and the
  radius come only from a **measured** calibration; an unmeasured record is refused.

`scripts/mapview/transform.py` holds these as pure functions (`world_to_minimap`, `minimap_to_world`, ...).

## Calibrate a screen (once per screen kind and resolution; needs the editor or a match)

1. Generate a known map in the editor (rm-census / map-minimap flow). Place three or more distinctive units at
   known world coordinates: map corners, the centre, one off-axis point. Full-resolution screenshot.
2. Find their pixels: `python scripts/mapview/calibrate.py blobs <png> --box x0,y0,x1,y1 [--colour R,G,B]`.
3. Write `pairs.json` (`what`, `x_m`, `z_m`, `px`, `py`, plus `size_x_m`, `size_z_m`) and fit:
   `python scripts/mapview/calibrate.py fit pairs.json --screen ingame --size 2560x1080`. The record is written
   only if every pair is within 2 px; a fourth independent pair must pass `check` within 3 px.
4. Records live in `scripts/mapview/cal/<screen>_<WxH>.json`; `calibrate.py show` lists them. The free-affine
   diagnostic printed by `fit` should show angle and skew near 0; if not, the screen is not a pure 45 degree
   rotation and the model needs the owner's decision.

Traps: compute on full-resolution pixels (a downscaled copy is not 1:1); button edges are gradients, measure where
a probe sits; the in-game minimap is black where unexplored, the transform does not care but colour detection does.

## Build a twin

    python scripts/mapview/twin.py randmaps/zplondon.xs --players 2 --teams 2 [--census <save.age3Yscn>]

Expected = mapsim's placements for that setup (approximate by design: tainted branches run both arms, player
positions are nominal, per-player loops are not expanded). Actual = the census of the save. Output
`scripts/mapview/out/<map>_<N>p/twin.json` and `twin.png` (minimap orientation; red circle = expected but not
spawned within `--tol-m`, orange x = spawned but not expected). The census owner field is **not decoded yet**
(`census_reader.py` docstring); `--find-owner` locates it from a save whose owners are known.

## Aim the camera (in a match, on the owner's word)

    python scripts/mapview/camera.py shot 210 480 --size 360x645 --name enemy_block
    python scripts/mapview/camera.py record 180 322 --size 360x645 --seconds 60 --name bridge

`goto` clicks the minimap pixel, parks the mouse off the minimap (its tooltip covers it), and verifies that the
white camera trapezoid's centroid is within 3 px of the target; one retry covers the eaten first click after a
focus change. It refuses without a measured calibration and refuses a target outside the disc. It never selects
or orders units and never touches the game process.

`scripts/aitest/snapshots.py <out> --world targets.json --size 360x645` photographs a list of world targets the
same way (the AI's echoed positions, town centres from a census, construction blocks).
