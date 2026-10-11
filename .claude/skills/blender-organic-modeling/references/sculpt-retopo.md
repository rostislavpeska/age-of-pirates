# Sculpt, retopology and reduction

Source keys refer to [sources](sources.md).

## 1. The sculpt is optional and only a bake source (should)

- A low-poly game character is often box-modelled directly; a sculpt is worth making only when its detail will be
  baked into normal maps (PC7, R8).
- The game mesh is built by hand over the blockout or the sculpt. Blender's manual is explicit: no perfect automatic
  tool exists for topology that deforms, and the automatic remeshers do not give topology that lends itself to
  deformation (B1).
- Keep the sculpt in the same transforms as the low mesh and name it as the bake source
  ([conventions](../../blender-asset-conventions/references/scene-and-export.md)). Baking and texturing are not part
  of this skill.

Check: the HIGH object shares the LOW's transforms; the LOW was not produced by a remesher (its history and the
handoff say how it was made).

## 2. Retopology over a sculpt (should)

- Snap to the sculpt with Face Project or Face Nearest, Backface Culling on, a Mirror modifier with Clipping on the
  retopo object (B12, B7, PC8).
- Lay the rings from [deformation topology](deformation-topology.md) first (hinges, shoulders, hip V), then fill
  the spans between them.
- Shrinkwrap is a limb-tube helper only (forearm, shin, mid upper arm): wrap against a limb-only target, or use
  Project with a limit so vertices that miss stay put (B14). Shoulders, armpits, hips, crotch and neck are laid by
  hand. A probe could not tell the Shrinkwrap methods apart (L14), so no method is preferred.
- For organic nudging use connected-only proportional editing instead of moving single vertices (B17, L13).

Check: on limb tubes the target-to-mesh 95th-percentile distance stays under 10 % of the limb radius (heuristic);
no Shrinkwrap modifier remains on the deliverable near the shoulder, hip or neck.

## 3. Remeshers only on disposable references (must)

- QuadriFlow and Voxel remesh discard every data layer: "All data layers will be lost" (A1); measured, 16 vertex
  groups and a UV map became none (L6). `preserve_attributes` does not keep vertex groups.
- QuadriFlow returns FINISHED even when it rejects the input; the rejection is only a WARNING report, and its checks
  count boundary edges as manifold (A10).
- Run them only on a copy prefixed `REF_` (a proxy, a Shrinkwrap or bake target), never on a deliverable that has
  UVs or weights.

Check: before the call, record face count and layer counts; after it, the face count changed (otherwise the call
silently did nothing) and the deliverable's `uv_layers` and `vertex_groups` counts are unchanged.

## 4. Reduction (may)

- Never reach low poly by Subdivide then Collapse: the hand-built cage is the deliverable.
- Decimate is not meant for meshes modelled carefully and economically (B13); its Collapse ratio counts triangles,
  it triangulates quads and makes slivers (minimum angle 16.2 -> 6.6 deg, L7). Use it for drafts only.
- To undo a subdivision use Decimate Un-Subdivide with even iterations (L7).
- After any reduction, gate the share of sliver triangles (minimum angle below 10 deg) against the reference
  asset's share; report the minimum angle as information only, since shipped game meshes carry a few slivers.

Check: sliver share no higher than the reference asset's; the minimum angle is printed but never a FAIL on its own.

## 5. Mesh hygiene before skinning (should)

- Zero loose vertices, zero zero-area faces, zero duplicate faces, outward normals on every closed shell (PC3, E2).
- Open boundaries are allowed by design on open parts (hems, sleeves, cloth panels) that use a double-sided
  material; shipped game characters are rarely watertight, so never apply a 3D-printing gate.
- Edges with more than two faces: no more than the reference asset has.
- Inversion: a fully flipped closed shell keeps contiguous winding, so detect it by signed volume (closed shells only,
  L12) or by comparing normals before and after `recalc_face_normals` on a copy.

Check: `Mesh.validate(verbose=True)` returns False (nothing to fix); wire, loose and zero-area counts 0
(`bmesh` flags `is_wire`, `is_manifold`, `is_boundary`, A5, A6); the share of faces flipped by a recalculation on a
copy is 0 outside declared open parts.
