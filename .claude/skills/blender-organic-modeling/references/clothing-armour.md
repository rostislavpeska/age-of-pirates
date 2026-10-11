# Clothing, armour and props on a body (G3)

Layers worn on a deforming body: robes, skirts, sashes, armour plates, helmets, straps, weapons. Source keys refer
to [sources](sources.md).

## 0. At small budgets the clothed form is the deforming body (should)

- When the budget is close to what the reference asset spends (game characters of a few hundred to a few thousand
  triangles), model one continuous deforming surface in the clothed shape: skin where skin shows, the garment
  surface where clothing covers the body. Its rings, poles and weights follow
  [deformation topology](deformation-topology.md), and G2 tests this mesh.
- Do not model a bare body and then dress it: every body face under a garment is budget the silhouette never shows,
  and stacked layers need offsets, extra pose proofs and a deletion pass afterwards.
- Separate shells only for parts that leave the body's silhouette or move apart from it: hanging flaps and skirt
  panels, brims, plumes, plates that stand off, loose sleeves, straps across open space, the weapon. Sections 1-10
  apply to them.
- A bare body under layers fits larger budgets, or a project whose tiers swap garments over one shared body; record
  that choice in the handoff.

Check: the hidden-face scan of section 5, run on the clothed body with its shells, finds no body face fully covered
by a shell outside one overlap ring; every separate shell changes the silhouette mask at one heading or more of the
silhouette sheet when hidden ([contract and blockout](contract-and-blockout.md), section 7), or is declared a moving
part. Sources: PC3 (no hidden geometry; spend triangles on the silhouette), E2 (remove hidden faces) and the game
layer's reference measurement (how the reference splits body and shells).

## 1. Layer weights come from the final body (must)

Weight every separate shell only from the finished body, in this order:

1. Data Transfer modifier on the layer: vertex data, `VGROUP_WEIGHTS`, mapping Nearest Face Interpolated
   (`POLYINTERP_NEAREST`), source = body.
2. Generate the missing groups first (`object.datalayout_transfer`), or the transfer may not work (B3).
3. Apply the modifier.
4. Bind the layer to the body's armature (an Armature modifier on it).
5. Run the hygiene chain of [skinning and pose tests](skinning-pose-tests.md) section 2: Clean (the interpolated
   transfer leaves weights under the clean limit), Limit Total to the **same** influence cap as the body, then
   Normalize All, always in that order.

```python
import bpy
layer, body = bpy.data.objects["<ASSET>_LOW_Robe"], bpy.data.objects["<ASSET>_LOW_Body"]
arm = next(m.object for m in body.modifiers if m.type == 'ARMATURE')   # the body's armature
mod = layer.modifiers.new("WeightsFromBody", 'DATA_TRANSFER')
mod.object, mod.use_vert_data = body, True
mod.data_types_verts, mod.vert_mapping = {'VGROUP_WEIGHTS'}, 'POLYINTERP_NEAREST'
for ob in bpy.context.view_layer.objects:
    ob.select_set(ob in (layer, body))
bpy.context.view_layer.objects.active = layer
bpy.ops.object.datalayout_transfer(modifier=mod.name)
bpy.ops.object.modifier_apply(modifier=mod.name)
layer.modifiers.new("Armature", 'ARMATURE').object = arm   # bind first: BONE_DEFORM exists only on a bound mesh
bpy.ops.object.vertex_group_clean(group_select_mode='BONE_DEFORM', limit=0.02, keep_single=True)
bpy.ops.object.vertex_group_limit_total(group_select_mode='BONE_DEFORM', limit=4)   # the body's cap
bpy.ops.object.vertex_group_normalize_all(group_select_mode='BONE_DEFORM', lock_active=False)
```

Why the order: the transfer produced up to 6 influences per vertex; a layer limited below the body's cap pokes
through on bending (limit 2: 21 / 31 overlaps at 30 / 60 deg against 0 / 14 at the body's limit of 4; rigid: 16 / 87);
Limit Total without Normalize left sums off by 0.42 (L3, L4). Operator defaults are `group_select_mode=''` and
`lock_active=True`, so pass both (A1, L8). The `BONE_DEFORM` choice exists only once the mesh is bound to an
armature: on a freshly modelled, unbound layer the operator raises `TypeError: enum "BONE_DEFORM" not found` (L16),
so the binding comes before the cleanup. Adding the Armature modifier after the transfer is applied keeps the Data
Transfer modifier first in the stack when it is applied. `BONE_DEFORM` follows each bone's deform flag, so set the
flags as [skinning and pose tests](skinning-pose-tests.md) section 1 says before the transfer.

Check per layer: exactly one Armature modifier, on the body's armature; 0 unweighted vertices; maximum influences no
higher than the body's cap; max |sum - 1| <= 1e-6; no weight in (0, clean limit);
weighted groups a subset of the body's allowed bones; layer-against-body intersecting triangle pairs
(`BVHTree.overlap` on evaluated meshes, ignoring pairs that share a vertex, A4) = 0 at rest and at every test pose.

## 2. Offset first, then prove it in poses (must)

- A layer sits off the body: a shell at gap 0 intersected the body at rest (7-11 pairs); a 1 cm gap (scaled to
  model units) gave 0 at rest, and the intersections then rose only with bending (L4).
- Test every layer in the primary pose and at the extreme frames of the asset's clips before any body face under it
  is deleted (section 5).

Check: as in section 1, at rest and per tested frame, logged in the pose-test JSON.

## 3. Below the belt: open flaps, never a tube between the legs (should)

- Build hanging cloth below the belt as open flaps (front, back, sides) or as a separate open skirt or apron weighted
  to the pelvis, thighs and calves. A closed tube that bridges both legs is stretched across the full leg spread of a
  seated or striding pose.
- Riding garments: real riding coats are slit to fall either side of the saddle (R17). Treat a split-panel layout as
  a hypothesis and compare it with the reference asset in the primary pose before adopting it.
- Each panel follows its own leg: weight it mainly to its thigh, with a falloff to the pelvis at the waist.

Check: a component that holds vertices dominated by both left-leg and right-leg bones and has 2 or more boundary loops
(a tube) fails; one open boundary (an apron) passes. In the primary pose, no flap penetrates the opposite thigh or the
mount (BVH overlap).

## 4. Rigid accessories (should)

A separate shell (helmet, plate, plume, brim, ornament) is either:

- weighted 100 % to one bone, where it sits on a rigid zone; or
- given the same weights as the body surface under it, so it never separates from or sinks into the body.

Check: for each non-body shell, either its influence histogram is {1: all vertices} on one bone, or every vertex's
weights match the nearest body-surface point (BVH `find_nearest` plus barycentric weights, A4) within the target
format's weight step (1/255 for 8-bit weights). In the extreme poses the shell-to-body distance changes by no more
than about 1 cm (heuristic). Source: L4 (a rigid shell over a bending zone intersected the body 16 / 87 times at
30 / 60 deg; one weighted like the body, 0 / 14).

## 5. Remove hidden faces only after the pose proof; keep what the mount covers (should)

- Delete body faces fully covered by a shell only after G3 passes, keeping one ring of overlap under every hem, cuff
  and collar so bending never opens a gap.
- Removing hidden faces also helps automatic skinning (E2), and it saves triangles that a tight budget needs.
- Faces that a mount or another fixed partner covers in the bind pose (a rider's inner thighs, crotch and seat) are a
  separate case. Check the reference asset first and keep them unless it removes them: clips lift the body off the
  mount (rising to strike, leaning out), so a face covered in the bind pose is not covered in every frame. Delete
  them only when the reference does and the paired-clip test ([skinning and pose tests](skinning-pose-tests.md),
  section 9) shows them covered in every tested frame.

Check: a hidden-face scan casts rays from each face centre in 26 directions against all parts (`BVHTree.ray_cast`,
A4); a face is hidden only when every ray is blocked within the asset's size; each hidden face kept is inside an
overlap ring. For the mount-covered zone, count on the candidate and on the reference the faces dominated by the
pelvis or thigh bones whose normals face down or towards the mid-plane; the candidate's count is 0 only when the
reference's is, and each deleted face is covered (ray test against the posed mount) in every tested frame. Sources:
E2, PC3, and the game layer's reference measurement.

## 6. Single-sided cloth and cards (should)

- Model robes, hems and sashes as single-sided surfaces on a double-sided material where their back shows.
- Use alpha-cutout cards for plumes, fringes and tassels.
- Open boundaries exist only on parts declared open; everything else follows the hygiene rules in
  [sculpt and retopology](sculpt-retopo.md).

Check: every boundary loop belongs to a face set with a double-sided material, or is invisible in the silhouette
renders; the open-boundary edge share is no higher than the reference asset's. Source: process rule of this skill,
calibrated against the reference (shipped characters are rarely watertight, [sculpt and retopology](sculpt-retopo.md)
section 5).

## 7. Thickness where it must show (may)

Where a layer must show thickness (a heavy hem, a collar): copy the visible faces, push them out along the normals,
apply scale, then Solidify with offset +1 (Simple mode unless edges have more than two faces). Thickness is in local
coordinates, so apply scale first (B15). Count the added triangles in the budget.

Check: layer-against-body overlap 0 at rest before weighting; triangle budget table updated.

## 8. Detail goes into the texture (should)

- Paint stitching, quilting, studs, plates, pleats and cords into the textures and the normal map. Spend geometry only
  on shapes that change the outline from the game camera: skirt flare, shoulder plates, brim, crest, plume, weapon
  (PC3, R5, R9, R11).
- A stacked-plate look is at most one flared shell with a stepped hem, never geometry per plate.

Check: every shell with a bounding-box diagonal under 5 cm is on the handoff's identifier list or is removed and
painted; more than 4 islands with near-identical vertex counts and bounding boxes (repeated plates) fails.

## 9. Cords, straps and reins from curves (should)

- Cord: a Bezier spline with a round bevel, `bevel_resolution` 0 (4-sided) or 1, `resolution_u` 1-2; on POLY splines
  `resolution_u` does nothing. Cross-section vertices = 4 + 2 x `bevel_resolution`; rings = (points - 1) x
  `resolution_u` + 1 on Bezier splines (B16).
- Strap or belt: an extruded ribbon, single-sided on a double-sided material, or Solidify for visible thickness. Use
  Tilt for twist and Fill Caps where an end shows. A bevel object must be flat in its local XY (B16).
- Convert to mesh, merge by distance in working units, then weight from the body (section 1).

Check: converted vertex counts match the formulas; boundary edges only on parts declared single-sided; each strap
passes the section 1 checks.

## 10. Weapons and props: decide the rig first (should)

Decide before modelling and record in the handoff, because the choice fixes the material split and the budget:

- **rigid attachment**: a separate model on one prop or hand bone, 1 influence per vertex, attached by the engine;
- **skinned chain**: a separate mesh inside the body file, weighted 1 influence per vertex to chain bones - only when
  every clip the asset plays has tracks for those bones; a rigid pole cannot ride clips that animate each link
  separately. Weight the chain mesh with only its chain bones deforming, and the body with the chain bones' deform
  flag off ([skinning and pose tests](skinning-pose-tests.md), section 1);
- never weld a weapon into the body shell.

Check: the bone dump of every clip the asset plays lists the chain bones (skinned route); the weapon's influence
histogram is {1: all vertices}; the body carries no weight on a chain bone; at key frames of every clip, no weapon
vertex lies more than a small tolerance inside the body or the mount (BVH test, A4). Source: process rule of this
skill; it follows from [contract and blockout](contract-and-blockout.md) section 3 (a bone without a track keeps
its rest pose).

## 11. Variants and ranks reuse the body (should)

Build tier 1 completely (mesh, weights, UVs, LOD if any). Derive further tiers by duplicating it and swapping or adding
shells (headgear, plates, skirt length) or changing only the texture, without retopologizing the body, so weights
carry over one to one. Record per tier which shells differ.

Check: tier N shares at least the project's threshold of body positions with tier 1 (for example 90 %), and the
shared vertices carry identical weights within the weight step. Source: process rule of this skill (weights carry
over unchanged only while the body's vertices do).
