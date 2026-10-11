# Deformation topology (G2)

How a low-poly body is laid out so it bends cleanly with a fixed skeleton under linear-blend skinning. Source keys
refer to [sources](sources.md). Joint-zone checks assume the pose set from the contract
([contract and blockout](contract-and-blockout.md)). Calibrate every count, share or ratio against the reference
asset the game layer measured; numbers given here without a source are labelled heuristics. Practitioner layouts
(PC1, PC10) describe what keeps volume; shipped low-poly game characters often spend less, so the reference asset,
measured with the same method, sets the floor and the pose tests decide.

At small budgets the deforming surface is the clothed form, not a bare body under clothes
([clothing and armour](clothing-armour.md), section 0): every rule below applies to that surface.

## 1. Quads to author, triangles to ship (must)

- Author the body in quads with clean loops; deliberate triangles only where a ring merges or ends. Quads deform
  well and keep loop selection usable (B10, PC4).
- Report the budget in triangles, never faces.
- Triangulate the export copy explicitly (Triangulate modifier with a fixed quad method, applied, or by hand) before
  any bake and before the pose gates, so Blender, the bake and the game share one triangulation (B9, PC4, PC6).
  Mirrored halves get mirrored triangulation; triangulate before mirroring normals or UVs (PC5, PC6).
- In the primary and extreme poses, rotate any joint-zone diagonal that makes the bent side cave in or spike out
  (`bmesh.ops.rotate_edges`), then rerun the pose checks.

Check: the export copy has 0 faces with more than 3 vertices; the exported triangle count equals
`len(mesh.loop_triangles)` after `mesh.calc_loop_triangles()`; the triangle-list hash at bake time equals the one at
export.

## 2. Rings at each hinge, matched to the reference asset (should)

- Aim for two full edge rings straddling the pivot at each elbow and knee of the full-detail LOD: the practitioner
  layout that keeps volume (PC1). When budget allows, add a half-ring on the stretch side between them: 3 rings on
  the stretch side, 2 on the crease side, the layout PC1 calls the best low-poly solution.
- Shipped low-poly characters often use fewer: one blended ring at an elbow that the clips bend little or a sleeve
  hides, sometimes none. Match the reference asset joint by joint and record the ring count chosen for each joint in
  the ring budget (section 4).
- A single row weighted about 50/50 at the pivot loses volume when the joint bends far (PC1). Use it only where the
  reference asset does the same at that joint and the pose test (skinning, section 8) is no worse than the
  reference's.
- Alternative (may): a diamond (rotated quad) on the crease side - back of the knee, inner elbow - with plain parallel
  loops on the kneecap and elbow point (PC10). Keep loop spacing fairly even, without tiny faces next to large ones
  (R12). Choose one pattern per joint and record it for the pole census.

Check (bmesh, on the quad mesh before triangulation): for each joint, take the plane through the pivot with the
bone axis as normal; count the closed edge loops whose centroid lies within +/-15 % of the upper segment length of
that plane and whose vertices are all dominated by the joint's two bones. Run the same count on the reference asset.
Pass when every joint has at least the reference's count; a joint with fewer passes only when its pose metrics at
the clip extremes are no worse than the reference's. Record both counts per joint in the handoff.

## 3. Hinge weights graded like the reference asset (should)

Knee and elbow:

- rows away from the joint are rigid, 100 % to their own bone;
- the blend stays in the rows nearest the pivot, and the lower bone's weight rises monotonically across them;
- the practitioner layout blends one pivot row at about 50/50 between rigid rows (100 / 50 / 100, PC1); shipped
  low-poly characters may spread the blend over 2-4 rows. Match the reference asset's blended-row count and weights
  at that joint.

Wrist, ankle and the head-to-chest band have no fixed recipe here: measure them on the reference asset. The wrist
follows section 11 (forearm roll), the neck band section 8 and the ankle section 9.

Keep the rest of the body mostly single-influence and match the reference asset's single-influence share.

Check: walk each limb ring by ring from the upper to the lower bone; the lower-bone weight never decreases along
the walk and runs from 0 to 1; the number of blended rows (0 < w < 1) at each knee and elbow lies within +/-1 of the
reference asset's count measured the same way; the single-influence share of the whole body lies within the
reference range. Sources: PC1 (100 / 50 / 100 rings; two full rings at 100 / 100) and the game layer's reference
measurement.

## 4. Write the ring budget first (should)

- Adding one full edge ring to an N-sided limb tube costs 2N triangles (N more quads; a 6-sided ring costs 12).
  Partial rings and wedges cost less: PC9 compares a wedge joint with an extra-ring joint on a 6-sided limb, 56
  against 64 triangles.
- Before modelling, write a table in the handoff: joints x rings x sides x 2. Choose limb side counts deliberately.
- Get triangles back by dissolving mid-limb loops that change neither silhouette nor deformation. Do not drop below
  the reference asset's ring count at a hinge of the full-detail LOD unless that joint meets section 2's pose
  exception, recorded in the ring budget.
- Heuristic, unsourced: joint rings rarely need more than about 15 % of the body budget.

Check: compare the table with the triangle count and with a per-zone triangle count by dominant bone; flag any
mid-segment loop whose dissolve (on a copy) changes neither the silhouette masks nor the pose metrics.

## 5. Density where the joint bends most (may)

- Spend extra density at the joints that bend furthest in the asset's clips (for a seated rider: knees and hip;
  elbows that are modelled pre-bent need less).
- Measure the reference asset: vertices per 10 % of segment length near each joint against mid-segment, and stay in
  its range.
- Extra rings do not cure collapse under bad weights: 3 rings instead of 1 under automatic weights gave the same elbow
  compression and more knee self-intersections (L11). Fix weights first, loops second.

Check: the same density ratio computed on the new body (garment shells that leave the body excluded) lies within
the reference range.

## 6. Shoulder: a bent straw, not muscle loops (should)

- Rings around the upper-arm root, aligned to the arm axis and tilted down into the armpit. 2-3 rings is a budget
  choice; PC2 shows about 5.
- Grade chest/clavicle to upper-arm weights across those rings, with the clavicle on the top ring only.
- At game budgets do not route deltoid or pectoral loops: the lower the polycount, the more a shoulder behaves as a
  deformed cylinder, and strict muscle loops pay off only with more influences (PC2).

Check: pose each arm at the bind angle, at about 120 deg elevation and at the weapon-swing extremes; fail on BVH
overlap between upper-arm-dominated and chest-dominated faces, or on any shoulder-top face whose posed normal points
against its rigidly transformed bind normal (dot < 0).

## 7. Hip, groin and buttocks (may)

- Give each thigh root a ring running in a V from the hip crest to the crotch, plus one ring 10-15 % down the thigh.
  Keep buttock loops horizontal and compact near the bottom of the cheeks.
- Blend the top-rear thigh rows with the pelvis at a minor weight inside the reference range; if the reference pelvis
  owns no rigid vertex, neither does yours.
- Faces a mount always covers (inner thigh, crotch, seat) stay unless the reference asset removes them
  ([clothing and armour](clothing-armour.md), section 5).
- Source: R13 (old, 795-polygon character; the thread never says which fix worked) plus the reference measurement.

Check: in the primary pose and at the hip extreme of the attack clips, no inner-thigh BVH overlap, and crotch and
buttock ring cross-sections keep at least about 70 % of their bind area (heuristic, unsourced).

## 8. Torso, neck and head (may)

- Torso: continuous horizontal loops, one blended loop at each spine pivot height and a rigid loop between them.
  Put a hard material break (belt, armour-skirt edge) on the waist loop. Avoid long vertical faces that cross both
  pivots.
- Neck: if the reference does not weight the neck bone, the head binds straight to the chest bone; put a collar,
  aventail or helmet-skirt edge on that band and keep the head rigid. Measure the band's blended rows and weights on
  the reference asset and match them; there is no fixed recipe.
- Source: process rule of this skill, PC1's hinge reasoning applied to the spine and neck, calibrated against the
  reference measurement.

Check: torso and neck blends exist only on the pivot loops and the neck band; posed head turns and a +/-45 deg spine
twist (a guess, not a sourced range) show no flipped faces at the waist or neck and no collar-helmet overlap.

## 9. Hands and feet (should)

- With no finger bones in the skeleton, model each hand as one closed rigid mitt in the grip pose: a thumb plus one
  finger block, fingers painted (R14). Shape the grip around the prop bone so the weapon sits inside the fist.
- Feet: rigid blocks, toes unbound when the reference leaves them unbound, the ankle blend measured on the reference
  asset and matched.
- Shipped characters of one game often share a stock hand or foot. Copying a shipped asset's geometry into a new
  model is the project's policy decision, not a modelling choice: ask the owner before reusing it, and record the
  answer.

Check: no bone named like a finger; the prop bone's head lies inside the hand hull at the test frames (convex-hull
or ray-parity test, A4); the hand and foot rigid shares match the reference; any reused shipped geometry has the
owner's recorded decision.

## 10. Pole census (may)

- List every non-boundary vertex whose edge count is not 4 on the quad mesh.
- Allowed: poles of a declared joint pattern (3-into-2 merge, crease diamond, convergence vertex).
- Preferred homes for other poles: armpit, side of the chest, flat of the back, top of the head (PC3, R12).
- Fail: a stray pole on the stretch side of a joint, on the pivot ring itself, in the groin or inner thigh. A blanket
  ban near joints would reject the sanctioned patterns; loops stop at poles (B10).

Check: `[v for v in bm.verts if not v.is_boundary and len(v.link_edges) != 4]`, classified by zone (+/-15 % of
segment length around a pivot; crease or stretch side by the bend direction) and by declared pattern.

## 11. No helper bones the clips do not animate; the wrist (must)

- Do not add twist, roll, helper or corrective bones unless a clip the asset plays has a track for them: a bone
  without a track keeps its rest transform and corrects nothing.
- Solve deformation with ring placement and weights.
- Forearm roll then lands on the wrist joint: hide it behind a cuff, bracer or sleeve edge. If the linear-blend test
  still shows a candy-wrapper at the wrist (R1, R2), spreading the hand influence over 2-3 forearm rings is an
  alternative (may); compare it with the reference asset under the same 90 deg hand roll. This section is the only
  wrist rule; section 3's knee and elbow grading does not apply here.
- Shape keys only when the engine plays them and the project confirms it.

Check: every vertex group on the body names an allowed bone; the export's bone list equals the donor's; the wrist
under a 90 deg hand roll is no worse than the reference asset's (ring cross-section and fold metrics, skinning
section 8). Source: R1, R2 (candy-wrapper); the no-helper-bone rule follows from
[contract and blockout](contract-and-blockout.md) section 3 (a fixed skeleton; untracked bones keep their rest pose).

## 12. Hard edges on UV seams, and the cost of splits (should)

- When the material uses a tangent-space normal map, every hard edge must also be a UV seam (PC5). Put both on breaks
  you need anyway: a belt, an armour rim, a cuff.
- Shade organic parts smooth. Every hard edge and seam duplicates vertices in the game mesh; count GPU vertices, not
  Blender vertices (PC4, E1). Smart UV seams and flat shading inflate the count (L5).

Check: the list of sharp edges (or split custom normals) that are not UV seams is empty, or each entry has a reason in
the handoff; the GPU-vertex estimate ([conventions](../../blender-asset-conventions/references/scene-and-export.md),
"Counts") divided by unique positions stays inside the reference range.

## 13. Symmetric by construction, asymmetric on purpose (should)

- Build the body with a Mirror modifier on X (Clipping and Merge) and apply it before weighting (B7). Repair drift
  with Symmetrize (B8).
- Add asymmetric parts (weapon-arm details, one-sided flaps, quiver) only after the symmetric weights are final.
  Weight mirroring itself is in [skinning and pose tests](skinning-pose-tests.md).

Check: seam vertices on the mirror plane have |x| < 1e-5; the share of vertices with a mirror partner within 1 mm
matches the reference asset's share.
