# Skinning, weights and pose tests (G2, G3, G4)

Source keys refer to [sources](sources.md).

## 1. Automatic weights are a starting point (should)

- Before any automatic weighting, set the deform flag on exactly the bones the mesh being weighted may use, and turn
  it off on every other bone (`bone.use_deform = False`): root, helper, prop and attach bones, toes, a neck the
  contract keeps unweighted, and the chain bones of a separately weighted prop (for the prop mesh, the reverse).
  Automatic weights and every `group_select_mode='BONE_DEFORM'` operator follow this flag, so a bone left deforming
  collects weight; a bone with the flag off is left out of automatic weights and deforms nothing, whatever its
  weights (B20, A1). So for pose tests the flag is on for every bone any mesh of the asset is weighted to (body and
  prop lists together), and off for the rest. The flag changes no transform, name or parent; whether it stays off in
  the export file is the export route's decision, and the exported bone list must equal the donor's either way (some
  exporters drop non-deform bones).
- Parent with automatic weights (`parent_set(type='ARMATURE_AUTO')`) only to start, or start from a reference body's
  weights (section 13). The manual warns that parts may not deform as expected and that same-named groups are
  overwritten (B5).
- Assert 0 unweighted deform vertices right away. Bone heat is not guaranteed to reach every vertex (B5), and small
  scenes and loose parts are commonly blamed; the bundled probe left none unweighted at scale 0.008, after a x100
  scale-up, or with a loose part (L2, experiment `autoweight_pitfalls`), so the assert decides, not the scale. When
  it does leave vertices unweighted, weight those parts separately (or scale the scene by 100, weight and scale back,
  an unmeasured remedy).
- The viewport hides bad sums: the Armature modifier normalizes at evaluation (L2). Never take a correct-looking
  deformation as proof of normalized weights.

Check: while weighting, `{b.name for b in arm.data.bones if b.use_deform}` equals the allowed list for that mesh,
and during pose tests the union of all meshes' lists; vertices with no deform-group weight = 0; then run the hygiene
chain below.

## 2. Weight hygiene chain (must)

In this order, with every argument explicit (the defaults are `group_select_mode=''`, `lock_active=True`,
`limit=0.0`, `keep_single=False`; A1, L8). The mesh must already be bound to the target armature (an Armature
modifier on it, or parenting with empty groups): `BONE_DEFORM` exists only on a bound mesh, and an unbound one raises
`TypeError` (L16).

```python
import bpy
bpy.ops.object.vertex_group_clean(group_select_mode='BONE_DEFORM', limit=0.02, keep_single=True)
bpy.ops.object.vertex_group_limit_total(group_select_mode='BONE_DEFORM', limit=CAP)
bpy.ops.object.vertex_group_normalize_all(group_select_mode='BONE_DEFORM', lock_active=False)
```

- Clean removes weights below the limit; Keep Single keeps at least one group per vertex (B2). Use 0.02-0.04 so no
  weight is lost to export rounding; a shipped reference may legitimately hold smaller ones, compare instead of
  copying.
- Limit Total drops the lowest weights; it must be followed by Normalize All (sums were off by 0.42 without it, L3).
- `BONE_DEFORM` acts on the bones whose deform flag is on (section 1): with the flags set to the allowed list, the
  chain never moves weight onto a bone outside it.
- Rerun the chain after every later weight edit. Normalize only deform-bone groups, never helper groups.

Check over `mesh.vertices`: max nonzero deform groups <= CAP; max |sum - 1| <= 1e-6; no deform weight in
(0, clean limit).

## 3. Influence cap and allowed bones (must)

- CAP is the target engine's influence limit. Real-time engines use a small fixed cap: Unity defaults to 4 (E1, E3),
  Unreal 4 or 8 with an "unlimited" path capped at 12 (E4), Source 3 (E5), Granny readers 4 slots (E6). The game
  layer gives the number, per LOD.
- Aim for the reference asset's distribution: mostly 1-2 influences, 3 at joints, 4 rare.
- Weighted groups are a subset of the bones the contract allows, with exact names. Delete empty groups and groups
  that are not bones before export.

Check: the set of groups with any nonzero weight is a subset of the allowed bone names (exact strings); no empty or
non-bone group; the influence histogram stays within CAP and near the reference shares; after export, the file's
bone list (names, order, parents) equals the donor's, with no bone dropped because its deform flag was off.

## 4. Quantized weights (should, for 8-bit weight formats)

Many game formats store 4 weights as 8-bit values that sum to 255; in some, a weight of 0 marks an empty slot (E6),
and the exporter normalizes (E7). To keep every influence and the exact sum:

1. drop influences below 0.5/255 and renormalize;
2. q_i = floor(255 x w_i), then give the units still missing from 255 one at a time to the largest fractional parts
   of 255 x w_i (largest remainder);
3. a kept influence that ended at 0 takes one unit from the largest entry, so none is stored at 0 (only a weight
   under 1/255 can end there);
4. store weights in descending order, no bone twice in one vertex; unused index slots repeat the first bone index
   (E6).

Each influence stays within 1/255 of its weight except where step 3 acts. Giving every kept influence 1 unit before
the share instead costs the largest weight up to about (k - 1)/255 for k influences (3/255 measured on a
4-influence test body). The bundled `organic_weights.quantize` implements exactly these steps and the audit's
`quantized_255` check uses it ([scripts/README.md](../scripts/README.md), "Quantization recipe"). The game layer
confirms the format.

Check: after export, every skinned vertex sums to exactly 255; every stored influence is at least 1; no nonzero
weight under the clean limit; descending order; no duplicate bone per vertex.

## 5. Mirroring weights with names Blender cannot pair (must)

- Blender pairs left and right only when the L/R marker sits at the start or end of the name, or after the last
  separator (B6, A8). Biped-style names carry it mid-name (`Bip01 L Thigh`, `Bip01_L_Thigh`), and
  `bpy.utils.flip_name` returns them unchanged (L1).
- Then the Mirror modifier's vertex-group mirroring, X-mirror weight painting, Mirror Vertex Group and Flip Group
  Names all silently do nothing.
- Either rename the groups temporarily (`Bip01_L_Thigh` -> `Thigh.L`), mirror, and restore the exact target names,
  or mirror with a script that maps the left names to the right ones explicitly.
- Weight mirroring needs a perfectly X-symmetric rest pose (B2); otherwise use topology mirror (B19). Mirror before
  any asymmetric edit.

Check: run `bpy.utils.flip_name` on one target name first (unchanged = this rule applies); after mirroring, for every
vertex v with a partner v' at (-x, y, z) within 1e-4, |w(v, left bone) - w(v', right bone)| <= 1/255, centre bones
equal; before export, every group name equals a target bone name and none ends in `.L` or `.R`.

## 6. Judge joints in linear blend (must)

- Keep the Armature modifier's Preserve Volume off in previews (`use_deform_preserve_volume = False`) unless the
  target engine is confirmed to use dual-quaternion skinning. Preserve Volume uses quaternions (B4) and hides the
  linear-blend collapse a game skin shows (R1); Unity, for one, documents linear blend skinning (E1).
- The game layer states the engine's skinning model with its evidence level (documented, measured or inferred,
  [conventions](../../blender-asset-conventions/references/scene-and-export.md) section 5). Until a dual-quaternion
  engine is documented or measured, judge in linear blend.
- Never approve a joint that looks right only with Preserve Volume on.

Check: assert `all(not m.use_deform_preserve_volume for m in ob.modifiers if m.type == 'ARMATURE')` before every
test render and record the value and the skinning model's evidence level in the test JSON.

## 7. Test the clips the asset really plays (must)

- G2 (the deforming body, before any UV work): bind quickly (automatic weights are enough) and pose the primary pose
  and the extremes. A topology fault found after UVs, bake and paint throws all of that away (R8, E2).
- Test every clip the asset plays (idle, move, attack, work, death) at the frames of maximum joint angle, not only
  frame 0 of an idle: attacks raise arms above the shoulder and fold hips far past any idle (R15).
- A clip that was not run counts as untested. If the posing tool gives clean poses only at some keys, say so and pose
  the rig by hand to the measured extremes.
- Log every clip and frame tested in a JSON file in the session scratchpad.

Check: the log lists every clip from the contract with the frames tested and the metrics of section 8.

## 8. Deformation metrics, relative to a reference (should)

Per tested pose, on evaluated meshes:

- self-overlap between regions that must not touch (left leg against right leg, upper arm against chest), with
  `BVHTree.overlap`, ignoring pairs that share a vertex (A4);
- folds: faces in a joint zone whose posed normal points against their rigidly transformed bind normal (dot < 0);
- ring cross-section area against bind (heuristic floor about 70 %, unsourced);
- layer-to-body distance change for every shell.

Gate relative to the reference asset posed the same way: every candidate metric no worse than the reference plus
10 %, intersections no more than the reference count. Absolute thresholds are uncalibrated: synthetic linear-blend
joints already shrink to 0.75 of their radius at 100 deg (L15). Fix a failure first by smoothing weights across
neighbouring rings, then by adding loops.

Check: a table per clip, candidate against reference, with the pose renders sent to the owner.

## 9. Riders: test on the real mount (should)

Seat the posed rider on the posed mount with their paired clips. Check legs against the barrel, buttocks against the
saddle, feet against the stirrup area, skirt panels against the flank, and render the pair from 4 views into the
scratchpad. The same frames prove which mount-covered faces stay covered
([clothing and armour](clothing-armour.md), section 5).

Check: per tested frame, the count of rider vertices inside the mount (BVH ray parity, A4) and their depth; none
beyond a small tolerance (heuristic: 1 cm in game units); the 4-view renders exist and were sent to the owner.
Source: process rule of this skill; R15 (test through the real animations).

## 10. Context-explicit Blender scripts (must)

- Set `view_layer.objects.active` and `select_set()` before each operator; operators act on active and selected
  objects.
- Leave Edit Mode before reading mesh data, or use `bmesh.from_edit_mesh`: Edit-Mode changes reach the mesh only on
  leaving Edit Mode (A2).
- Never keep an `EditBone` reference across a mode switch; edit bones exist only in Edit Mode and stale references can
  crash Blender (A3).
- Measure modifier and armature results only on `obj.evaluated_get(depsgraph)` or `Mesh.new_from_object`.
- Pass enum and option arguments explicitly (see section 2). `Mesh.use_auto_smooth` no longer exists since Blender 4.1
  (A7); use the Smooth by Angle modifier or sharp-edge attributes.

Check: run each script twice in fresh `blender -b --factory-startup` sessions on the same saved file and diff the
JSON output; identical output means no hidden context dependence.

## 11. Further gates (may)

- Weight-bleed detector: flag a vertex farther than 3x the median distance from its dominant bone's segment. It is
  unvalidated until it is proven on a seeded bleed.
- Report deform bones that own no vertex as information only; shared game rigs carry many.
- When Data Transfer and bone heat both fail on loose, layered garments, use a robust method as a reference: weight
  inpainting (R3) or geodesic voxel binding (R4). The result still passes sections 2-3 and the layer checks.

Check: the bleed detector flags exactly the 10 seeded vertices when 0.6 of an upper-arm weight is added to 10 chest
vertices, before it is used as a gate; unowned deform bones appear in the report as information, never as a FAIL;
a robust-method result passes the checks of sections 2-3 and [clothing and armour](clothing-armour.md) section 1.

## 12. G4: the export copy and the round trip (must)

- Prepare the export duplicate as the [conventions](../../blender-asset-conventions/references/scene-and-export.md)
  say: modifiers applied except the armature binding, explicit triangulation, only the layers the target uses, vertex
  groups named exactly as the target bones, hygiene chain rerun, triangle-list and UV hashes recorded.
- The first export of new skinned geometry is one falsifiable round trip through the project's converter: the game
  file must report the same mesh count, triangle count, bone list and influence maximum as the Blender candidate,
  before anything depends on that route. A passing structural check does not prove the game loads the file; the
  game layer names the bench test.
- When the route has not yet carried new skinned geometry into the game, run that round trip at G0, before the
  blockout, on a small skinned specimen on the donor skeleton (a few hundred triangles over the allowed bones, plus
  a chain if the asset has one) and the game layer's bench test. It settles the working-scale and frame recipe and
  the converter's limits before any modelling depends on them; the finished asset repeats it at G4.

Check: Blender candidate and game file agree on those four numbers; the project's skin checker reports no FAIL; for
an unproven route, the G0 specimen's round trip and bench result are in the handoff before the blockout starts.
Sources: PC6 and B9 (the exported triangulation is the one tested), conventions sections 1 and 3; the early round
trip is a process rule of this skill (one falsifiable test before dependent work).

## 13. Starting weights from a reference body (may)

- When a shipped body of the target game is bound to the same skeleton, its weights may replace automatic weights as
  the starting point: import it through the same route as a `REF_` object, align it to the candidate in the same
  frame and working scale, transfer its vertex groups with Data Transfer (Nearest Face Interpolated, missing groups
  generated first, as in [clothing and armour](clothing-armour.md) section 1), apply it, bind the candidate to the
  armature (Armature modifier) if it is not bound yet, then run the hygiene chain (section 2, which needs the
  binding) and correct by hand.
- It starts the hinge grading near the reference's ([deformation topology](deformation-topology.md), sections 2-3)
  and avoids the bleed of automatic weights; the pose tests still decide.
- Using a shipped asset's weight data is the project's policy decision: record the owner's answer before using it.

Check: before the transfer, the reference body evaluates to its raw positions at rest (rest equals bind) and its
weighted groups are filtered to the candidate's allowed bones; before the hygiene chain, the candidate carries exactly
one Armature modifier, on the target armature; after the chain, the checks of sections 2-3 pass, the
candidate's weighted groups are a subset of the allowed bones, and no `REF_` object is exported. Sources: B3 (Data
Transfer of vertex groups) and a process rule of this skill.
