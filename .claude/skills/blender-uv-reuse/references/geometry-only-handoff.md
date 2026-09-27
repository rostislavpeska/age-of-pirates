# Geometry-only sharing checkpoint

Use when the user explicitly requests stacking before AO and atlas optimization.
Copy the approved geometry into a new scene and preserve the unique source UVs.
Shared addresses are provisional candidates; AO, opacity, tangent-space normals,
grain, signs and unique decoration may split them later. Do not bake this scene.

## Matching contract

Recover persistent whole-chart ancestry from the authoring manifest. If a later
geometry repair subdivides a face, keep the inherited chart rather than declaring
each resulting polygon a new chart. Current visible/hidden classification can
separate their allocation, but geometry matching must not fragment a coherent
visible chart merely to improve match counts. Recover missing ancestry by measured
source polygon correspondence, with unresolved or ambiguous mappings recorded.

The helper `geometry_share.py` expects each chart to contain faces with stable IDs,
world `points`, pixel-space `uv`, unit geometric `normal` and a physical `material`
label. A chart can contain multiple materials; their spatial pattern must match.

1. Try eight 2D orientation transforms (axis swap and sign combinations), remove
   translation, and form a coarse UV/material/boundary signature. This only
   shortlists shapes with compatible existing parameterization and pixel size.
2. Match face/corner correspondence including polygon edge connectivity. Equal
   vertex sets with different boundaries are not equal patches. Ambiguous identical
   coincident UV faces are rejected rather than arbitrarily paired.
3. Solve the orthogonal 3D fit by SVD for proper and reflected transforms. Require
   `max ||R*p+t-q|| <= absolute + relative*characteristic_length`, with no scale
   factor, and a bounded transformed-normal angle. Measure UV error separately.
4. Test every member against its chosen owner, not transitive similarity chains.
   Log 3D reflection and UV reflection separately. They remain normal/alpha risks
   for the later channel gate.
5. Assign corresponding owner coordinates in the new UV layer. Existing detailed
   owner positions and chart pixel size stay fixed; freed addresses remain empty.
   Re-read Blender's stored floats to measure actual error, density and collisions.

Example tolerances from the Korean TC: 0.01-pixel shortlist quantization,
0.025-pixel UV fit allowance, position limit `2e-5 + 2e-5*L` in scene units,
normal allowance 0.5 degrees. These are explicit case parameters, not universal
precision guarantees. Different topology or UV parameterization may produce a
false negative despite congruent surfaces; keep unique and record this limitation.

## Hidden atlas and stale allocation correction

When explicitly allowed, hidden/down/interior faces may overlap regardless of
geometry **within their physical-material cell**. Do not put stone in wood's cell
or use the exception on a restored visible face. Keep black as the review override
and provide a second hidden-family color view. Use explicit mesh UV coordinates,
not a Generated/Object mapping shader masquerading as an editable atlas.

After classification changes, the old object/page may no longer agree with its
face visibility. Route by current face attributes, not old object names. A visible
face inherited from a formerly generic hidden chart may have invalid pre-existing
sharing. Give it a separate legal detailed-page address, preserving pixel density
and documenting the migration. A simple empty-slot placement for these restored
owners is an allocation correction; disclose it even though existing detailed
owners are not repacked. Never claim literally no placement occurred.

The source `Before_Sharing` layer needs accompanying source-page metadata when
faces have migrated to a different-resolution page. Raw normalized UV area is not
comparable across pages; measure in destination pixels. Repartitioning by atlas
may duplicate vertices at object seams without changing polygon geometry. Report
that vertex increase and keep the original component model.

## Remote-review packet

- Shared/unique/hidden status view: three unmistakable colors and a legend.
- Group colors: same group gets the same color on model and UV sheet; exact stable
  group IDs are also face attributes because hundreds of colors are not distinct.
- Focused opposite roof and whole-facade examples showing both instances plus
  their single UV footprint. Include owner/member counts and reflection flags.
  If adjacent geometry blocks either view, add clearly labelled isolated-chart
  renders alongside the whole-model context. Do not call adjacent facade faces
  opposite sides, or mistake an occluded photograph for proof of a missing match.
- Semantic material view, density checker using the actual UV layer, and a
  hidden-material view while the main review retains black backing.
- Actual opaque, alpha-bearing and hidden UV sheets; before/after comparison;
  original chart edges rather than tessellation lines; full-size downloadable
  images and close-up crops. Label diagnostic resolution separately from budget.
- Matched photos from every side, underside, interiors, roof and wall junctions.
  A browsable local HTML gallery plus a group table reduces forced Blender visits.
- Append and activate the candidate in live Blender, retain selection/overlays and
  useful UV Editing. Keep the source intact. Verify actual mesh UVs, group membership,
  image bindings and controls. State any failed native screenshot capture.

## Measured candidate, acceptance pending

On the S7 Korean TC source, 1,714 visible inherited charts produced 344 geometry
sharing groups, 1,453 shared instances, and 261 remaining unique charts. This frees
1,109 former addresses without repacking existing detailed owners. The candidate
includes complete opposite roof patches and one whole multimaterial facade pair.
There are 1,478 hidden faces in six material cells. A further 352 restored-visible
faces migrated from old generic H allocation; 126 remaining owners needed distinct
addresses. The working A8192/B4096 sheets are still oversized; no runtime capacity
or final-density approval follows from these numbers.

Eight regression tests cover rigid and mirrored correspondence, wrong geometry,
wrong material, changed UV scale, relief differences, boundary-connectivity mismatch,
and input/topology preservation. The applied model preserves all 5,234 polygon
shapes and has zero authored triangles or new flipped normals. This is evidence
for the bounded geometry checkpoint, not AO-compatible production texturing.
The live UV Editing screenshot was inspected with actual selected UV loops,
group colors, visible controls and opaque perspective navigation. A native image
capture can fail intermittently; retry after redraw and verify its content before
claiming the editor handoff was visually confirmed.
