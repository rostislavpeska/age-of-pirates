---
name: blender-prop-arrangement
description: Arrange catalog props around a building in Blender so they look lived-in yet physically plausible - story clusters, a protected hero prop, yaw off the building axes, leaning / tipped / stacked / nestled poses, rigid-body gravity settle, static-stability and "not too organised" gates. Use when placing or reviewing set-dressing props (crates, kegs, jars, carts, cannons) on AoE3 DE building models.
---

# Organic, physical prop arrangement

Props are **linked duplicates of an accepted catalog** (root empty + parented parts). Never edit catalog meshes, UVs or
attributes, never scale, never invent props: ask the owner for a missing one. Keep props out of the building's UV
split, visibility, sharing, packing and density work. Read [research](references/research.md) before changing a gate.

## Owner rules (2026-10-11, Korean Consulate review)

- "Too organized (boxy arrangement) - more real world mess": no props square to the building, no rows, real contacts.
- "The chests on the barrel look weird" (crates had landed on the cannon barrel because every placed prop counted as a
  support): supports are the building and a declared stack base only. Stack bases are flat-top props; round props
  (kegs, jars, barrels, the gun barrel) are never a base.
- "Barrel is great asset and we're hiding it ... something you need access to any time during an attack": the hero
  (cannon) stays fully visible and reachable - nothing on, over or against it; crew items within reach of it, never on it.
- "Arrangement should respect real physical constraints ... how to use gravity": gravity settle + static checks.
- Use the gallery / balcony decks as well as the ground.

## Workflow

1. **Spec** (`ARRANGE_SPEC.json`, format in `scripts/arrange_props.py`): zones (plan polygons on ground / decks),
   clearance boxes (doors, stairs, landings, gate paths, flag sockets), corridors (paths that lead *to* a hero),
   story clusters with an anchor and members. Write walls / deck edges / rails from the LOW (query bounding boxes)
   before writing anchors: a zone that stops short of a wall blocks every wall-nestled prop.
2. **Arrange**: `blender -b <file> --factory-startup --python refresh_view_layers.py --python arrange_props.py --
   --spec SPEC.json --out ARRANGED.blend --report ARRANGE_REPORT.json --replace`. A failure prints its rejection
   reasons (`hits LOW`, `hero ... clearance`, `footprint leaves zone`, `axis row`, ...); fix the spec, never the gate.
3. **Settle**: `settle_props.py -- --model <M> --arrange-report ARRANGE_REPORT.json --out SETTLED.blend ...`.
   Upright props stay analytic (passive); lean / tipped / stack fall under gravity; then the margin snap.
4. **Gate**: `prop_metrics.py -- --model <M> --spec SPEC.json --arrange-report ARRANGE_REPORT.json --out METRICS.json`
   must print `PASS`.
5. **Prove nothing else moved**: `diff_blend_nonprops.py` against the source file - `identical_nonprops: true`.
   Never overwrite a frozen / fingerprinted file: save a sibling file and a receipt (sha256, parent sha256, diff,
   reports, metrics).
6. **Review** at the game pitch (35-60 deg) from inside the courts, plus a top view; send the sheet to the owner.

## Cluster recipes

- **Hero + crew** ("gun crew work area"): hero `"hero": true`, aimed with `yaw_toward` (e.g. at the gate) and a small
  `yaw_jitter`; serving members `"serves": "<hero>"` (plan gap >= 0.15 m to the hero's hull, everything else 0.35 m);
  ready-use items at the hero's flank (shot by the loader, powder near the breech), a spare wheel leaning on a wall.
  Plan the hero's real footprint first: a 2 m diagonal cannon leaves little room in a 2 x 3.5 m court.
- **Supply heap**: crate + keg nestled (`"against": {"prop": ...}`), a keg on the crate (`stack`), one keg rolled
  into a gap (`tipped`, against a wall).
- **Office goods on a deck**: chest with a paper bundle on top, a second bundle stack, a basin nestled against the
  chest, a crate against the bundles - against the back wall, walkway clear.
- Wall-huggers stand 2-5 cm off the wall (`"against": {"wall": ..., "gap": [.02, .05]}`) with `wall_yaw` +-3-12 deg.
- Small props (< 0.20 m) only on a host. A prop modelled leaning (e.g. the Korean jige, 14 deg on its stick) is placed
  upright - do not lean it again.

## Gates (prop_metrics.py; thresholds in `prop_layout_metrics.THRESHOLDS`, never loosened per run)

| Gate | Rule |
| --- | --- |
| stability | upright / stack: centre of mass inside the support polygon by max(2 cm, 10 % of its smallest width); stack on its declared base; lean: mu_req = d(ground contact -> COM) / h(upper contact) <= 0.4; small props on a host |
| aligned share | non-round props (and every tipped / leaning one) within 5 deg of a building axis <= 35 % |
| axis rows | 0 groups of 3+ centres on one x / y line within 0.10 m (declared rows exempt) |
| contact share | >= 30 % of props touch a prop or wall (side contact <= 1 cm, or resting on / carrying a prop) |
| isolated share | <= 20 % with nothing within 0.6 m |

Advisory only: Clark-Evans R per zone (Donnelly edge correction, verified against Monte Carlo), nearest-neighbour CV,
orientation entropy, parallel-neighbour share. sd(R) is 0.17-0.27 at 5-12 props per zone - read it, do not gate on it.
A tipped barrel on level ground is in neutral equilibrium: its roll stops are reported, not gated.

## Pitfalls (each one happened)

- **A prelude that moves data before a save** (a bake-alignment script that shifts HIGH sources) writes the moved
  transforms into the arranged file. Use `refresh_view_layers.py` before any script that saves.
- **Stale matrices**: some pipelines save stale `matrix_world`; refresh every view layer before reading transforms.
- **Parent offsets**: a catalog root keeps its catalog parent -> props land metres away while the gates pass on the
  wrong place. Clear the root's parent; check the footprint is inside the zone.
- **Support rays from high up hit roofs**: start them 1.6 m above the probe (below the eaves).
- **Hero clearance on an axis-aligned box** of a diagonal 2 m cannon blocks half the court: use the plan convex hull.
- **Plan hulls touch long before surfaces do**: a keg's bulge and a tray's rim sit at different heights. Nestling
  refines on the 3D surface distance (measured 10-27 mm off before the fix, 4-8 mm after).
- **No ground mesh**: the building files have an implicit ground; without the passive slab every prop falls away.
- **Bullet margins**: hull-on-hull rest ~2 x margin apart (8 mm at 0.004). The margin snap removes the float.
- **Bullet rolls convex discs**: a wheel leaning on a wall creeps; keep the analytic lean (mu_req checked).
- **Vertex-only contact tests** miss lid / band contacts of low-poly props: support uses a 1-2 cm ray grid.
- **A stack whose base failed** must fail too (reported), not crash the run.
- **Nested props pass a BVH overlap test**: it sees only crossing surfaces, so a jar accepted fully inside another jar
  passed (Monastery m1). The arranger rejects part centres inside another prop (ray parity) and the gate fails any
  interpenetrating or nested pair.
- **Several items on one base** (jars on a terrace, bowls on a table): stacks honour `at` / `spread`; the stacked
  centre must sit >= 2 cm inside the base's top.
- **A prop modelled to rest on a third point** (the jige's stick tip 10.7 mm above its feet) cannot pass the upright
  analytic rest: flag it `"physics": true` so gravity settles it onto the stick.
- **Bounding-box contact counts** overstate contact (0.79 bbox vs 0.26 real on the same layout).
