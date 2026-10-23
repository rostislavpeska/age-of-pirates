---
name: aoe3de-unit-model
description: "Apply AoE3 DE unit-model budgets, skeleton, material and export requirements. Use alongside generic character authoring; animation timing belongs to aoe3de-unit-animation."
---

# AoE3 DE unit models: the game facts

What a new or changed Age of Empires III DE unit model must respect, measured read-only on the retail archives on
2026-10-10/11. The method - contract, blockout, deformation topology, weights, pose tests, LOD - is in
[blender-organic-modeling](../blender-organic-modeling/SKILL.md); this package fills its contract (G0) with AoE3
numbers, names the AoE3 tool for each gate and ships the scripts that reproduce every number. Riders are measured;
infantry and horses only in part.

| Need | Skill |
| --- | --- |
| How clips bind to bones, putting a body on a rider skeleton, pose preview, horse and rider pairs, attack-tag timing | [aoe3de-unit-animation](../aoe3de-unit-animation/SKILL.md) |
| Skeleton and weight proof against a donor, clay renders | [skinned-model-check](../skinned-model-check/SKILL.md) |
| Byte-level GR2 reading and edits, frames and units | [gr2-granny-edit](../gr2-granny-edit/SKILL.md); appending bones in place: `unit-bones` |
| Attachments, `<definebone>`, attachment check | [aoe3de-model-attachments](../aoe3de-model-attachments/SKILL.md) |
| Bench proto for the game test | [aoe3de-model-test-unit](../aoe3de-model-test-unit/SKILL.md) |
| UVs: the generic method, evaluator and gate tool | [blender-organic-uv](../blender-organic-uv/SKILL.md); the AoE3 benchmark, gate profile (`profiles/organic_uv_unit_body_1024.json`), camera, pose and page facts in [organic UV reference](references/organic-uv-reference.md) |
| Extracting vanilla files (scratch only, never into a repository) | [aoe3de-bar-archives](../aoe3de-bar-archives/SKILL.md) |
| Animfile and `.material` grammar, CRLF | the consumer's XML skill (`aoe-xml` in AoP) |

## Contract values for an AoE3 rider (G0)

| Term | AoE3 value | Detail |
| --- | --- | --- |
| Skeleton | a vanilla `Bip01` rider rig chosen by the clips the unit plays (`scripts/track_coverage.py`): **iron_rider_0** (32 bones, flail chain) for a new rider on the oprichnik clips; the yabusame rider (30 bones, standing rest) for transplanting an existing body with `gr2_reskeleton.py` | [rider skeleton](references/rider-skeleton.md), section 8 |
| Weighted bones | exactly the 18 body bones (Pelvis, Spine, Spine1, Head, L/R Clavicle, UpperArm, ForeArm, Hand, Thigh, Calf, Foot); never Neck, Root, Prop, Toe, Ponytail, Nub; a skinned weapon only on its chain bones | rider skeleton |
| Bind pose | standing: arms 26.2 deg from down, elbows 26.5, knees 0.1-8.1, thigh spread 7.2-17.9; the seated pose comes only from the clips (idle: hip about 58, knee 49, spread 67) | rider skeleton |
| Segment lengths | thigh and calf 0.506, upper arm and forearm 0.304, Spine1 -> Head 0.328 (engine units), fixed by the clips | rider skeleton |
| Frame and scale | working scene from `scripts/donor_to_blend.py`: GXO frame in engine units (a rider about 2.1 tall), identity object transforms, nothing applied; pose-test GXO written with `rig_table.py --skinned --scale 0.393700787`; a converter FBX imports at 0.008 (inspection only) | [export routes](references/export-routes.md), section 2 |
| Budget, full LOD | body with any skinned weapon 962-1504 triangles (median 1240), 628-1061 welded vertices, one 1024 set; rigid weapons 67-127, hats 80-96 | [vanilla unit measurements](references/vanilla-unit-measurements.md) |
| Budget, LP | optional; 200-262 triangles, 0.17-0.21 of the full model, max 2 influences | [LowPoly LOD](references/lod-lowpoly.md) |
| Influences | cap 4 (format slots); vanilla mean 1.20-1.42, 0-7 vertices with 4; attachments 1; weights sum to 255 in 8 bits (the generic quantization recipe, `blender-organic-modeling` skinning section 4) | vanilla unit measurements |
| Skinning model | linear blend, **inferred**: it is what `pose_sim.py` implements; the game's own skinning is undocumented and unmeasured. Judge joints in linear blend (Preserve Volume off); the G0 bench is the first game evidence | export routes, section 4 |
| Starting weights | the donor's `REF_` meshes from `donor_to_blend.py` are already in the working frame and scale with their weights, so the generic transfer from a reference body (skinning section 13) needs no alignment step; using vanilla weight data is the consumer's asset-policy decision, like the stock hand (rider skeleton, section 9), recorded before use | export routes, section 2 |
| Joint blends | knees blend 2-7 rows (median 3), elbows usually one 0.5 ring, wrists bimodal: reference data, not a recipe | vanilla unit measurements, "Joint rings and blend rows" |
| Mount-covered faces | kept: every measured rider keeps its seat and inner-thigh faces (1.1-4.9 % of the body's triangles) | vanilla unit measurements, "Faces the mount covers" |
| Materials | `default` family, BaseColor + Normals + Masks (R AO, G roughness, B metallic) + Details (R = player colour); double-sided shaders for open cloth | [materials and textures](references/materials-textures.md) |
| Horse | never modelled, copied or reskinned: a vanilla horse animfile referenced by archive path | rider skeleton |
| Camera | `game.cfg` `limitPitch=47`; meaning and field of view undocumented: calibrate renders on an existing screenshot | materials and textures |

## Gates in AoE3 terms

- **G0** contract, then the **falsifiable export round trip on a specimen, before any blockout**
  ([export routes](references/export-routes.md), section 3): donor with full clip coverage, the donor scene, the
  Blender round trip on the donor's `REF_` meshes, a small skinned specimen through the candidate writer, the ladder,
  one bench test, and the owner asked for a unit lint profile and texture class. No blockout while any of it fails.
- **G1** blockout: on the donor armature from `donor_to_blend.py`, at working scale, in the bind pose, with the
  donor's `REF_` meshes as overlay (another vanilla rider such as keshik_rider_rank01: build its own scene with the
  script and append its `REF_` meshes);
  silhouettes calibrated on a vanilla rider's pixel height.
- **G2/G3** pose tests, offline: write the working mesh with `<consumer-root>/scripts/havok/rig_table.py --skinned
  --triangulate --scale 0.393700787`, decode every clip the animfile plays (rider and horse) with
  `scripts/clip_decode.py`, then run `aoe3de-unit-animation/scripts/pose_sim.py` with `--mount` on the vanilla horse
  at key 0 and at the extreme keys `clip_angles.py` names. Decoded oprichnik_attack_a on iron_rider_0 reaches hip
  flexion 105, knee 87 / 85, spine bend 58, upper arm 115 (right; left 81) and elbow 111 deg near keys 125-209
  ([rider skeleton](references/rider-skeleton.md), section 6); the new body must deform cleanly there. A converter
  GXO dump of a clip is a pose at key 0 only (pose_sim refuses its later keys). Renders with `render_obj.py` in
  background Blender.
- **G4** export: the route and ladder in [export routes](references/export-routes.md), sections 5-7. Route A
  (in-place edit) is proven; route B (new skinned geometry) only once the G0 round trip passed.
- **G5** LOD: the owner decides between no LowPoly logic, the full model in both slots, or a hand-built LP.

## Before a bench test (offline, in this order)

1. In Blender, on the export copy: `blender-organic-modeling/scripts/organic_audit.py` with `--cap 4`,
   `--allowed-bones` the donor's weighted bones (18 body bones plus any chain bones), `--mesh-bones` per mesh (body:
   the 18; a skinned weapon: its chain bones only), `--reference` a snapshot of the donor scene written with
   `--write-reference` before any edit, `--symmetry` on the body, and the contract's triangle and mean-influence
   ceilings: exit 0, report in the handoff `qa` block. A vertex ceiling taken from the vanilla table is a welded
   count: compare it with the report's `gpu_vertices_estimate` (`--max-verts` checks Blender vertices, which are
   fewer), and with `vertex_fill.py`'s welded count on the gr2 (step 4).
2. `gr2_dump.py` (CRC ok) and `gr2_fixups.py` (0 orphans) on the output.
3. `run_skin_check.py OUT --baseline DONOR --out <scratch>/skin_check --max-influences 4`: no FAIL; send the clay
   views (`--out` is required, outside the repository).
4. `scripts/vertex_fill.py OUT.gr2`: vertex layout, fill and weight sums identical in kind to vanilla.
5. `pose_sim.py` seated on the vanilla horse with decoded clips, every clip at key 0 and the extreme keys: z range
   within a few cm of the donor posed by the same keys on the same horse; renders sent.
6. `attachment_check.py` on the animfile; animfile and `.material` CRLF and valid XML.
7. Bench proto ([aoe3de-model-test-unit](../aoe3de-model-test-unit/SKILL.md)); the game test runs only on the
   device the project allows, after the consumer's own export gate.

## Scripts

All read-only on game data; vanilla inputs come straight from the archive with `--archive Art/units/...` into a temp
folder (never a repository); reports print and JSON goes to a temp folder unless `--json` names one.

| Script | Measures or does | Backs |
| --- | --- | --- |
| `scripts/measure_units.py` | GPU, welded and unique vertices, triangles, meshes, slots, bones, influences, `.material` pages, budget summary | vanilla unit measurements: full table, budgets |
| `scripts/vertex_fill.py` | vertex layout and fill, weight sums, order, zero slots, smallest weights, split causes | shipped buffers, weights, vertex format |
| `scripts/joint_metrics.py` | bind angles, segment lengths, joint rings and blend rows, hinge blends, density, limb sides | joint rings, rider skeleton sections 3-4 |
| `scripts/shape_metrics.py` | shells and open edges, symmetry, region shares, heads, hands, UV area and texel density; `--compare` for tiers and stock hands | regions, shape, UV facts |
| `scripts/clip_decode.py` | a clip gr2 decoded straight into GXO clip text, every key a pose (no converter) | rider skeleton section 6, export routes section 4 |
| `scripts/clip_angles.py` | joint angles per key of a decoded clip through pose_sim, extremes and their keys | rider skeleton section 6 |
| `scripts/track_coverage.py` | clip tracks against donor skeletons, root keying | the donor choice |
| `scripts/texture_pages.py` | DDT headers, `.material` pages with archive sizes, Details coverage, legacy texture names | materials and textures, LowPoly LOD |
| `scripts/tangent_compare.py` | stored tangents dumped from the gr2, compared with Blender's MikkTSpace by the generic `blender-organic-modeling/scripts/tangent_compare.py` | materials and textures section 6 |
| `scripts/donor_to_blend.py` | the working scene: donor armature at working scale, deform flags, bone order, `REF_` meshes (background Blender) | export routes sections 2-3 |
| `scripts/unit_gr2.py` | the shared reader and archive access the others import | - |

`tests/test_unit_model_scripts.py` runs synthetic cases everywhere and pins the vanilla numbers and the Blender round
trip where the game install and a Blender are found.

## Open measurements

- What selects the `<lowpoly>` child at run time.
- The green-channel convention of unit Normals maps (measure against a vanilla rider page first).
- Whether units read Details.R exactly as buildings do (same materialdefs; inferred, not proven).
- The camera's real pitch and field of view, and a unit's pixel height at default zoom.
- Pose extremes of death clips, and whether `rider_death_havoc_a/b` needs physics data in the model.
- Granny's exact B-spline index alignment (`clip_decode.py` infers it; the LSLib reading moves the attack_a extremes
  by up to 2 deg and the strike timing by about one key).
- Route B: proven offline 2026-10-11 through the donor-preserving `skinned_gr2.py` (the converter route fails the
  ladder: no tangents, not the vanilla layout; [export routes](references/export-routes.md), section 6); the writer
  refuses a wrong-scale GXO and donor geometry handed back through a re-export (repair round, same section); one game
  bench of the specimen is still open.
- The rigid attachment route through the donor-preserving writer (layout match inferred, one bench test needed).
- The owner's confirmation of the PROPOSED unit lint profile `unit_rider_1024` and its texture class
  `unit_human_1024` in AoP's `gr2_lint` (2026-10-11).
- Masks values, BaseColor saturation under the player-colour mask and UV stacking: their 2026-10-10 scripts were not
  kept; re-measure before relying on them.

Related by name: `unit-bones` (bones appended in place), `gxo-convert` (the converter under Wine), `aoe-xml`
(animfile grammar), `aoe3de-player-colour` (Details and player colour), `blender-asset-conventions` (export copy and
evidence levels).
