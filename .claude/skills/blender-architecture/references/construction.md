# Construction and diagnosis
Inspect wall profiles in plan and cross-section at every floor, setback, transept, apse and tower. Columns sit on plinths/floors; capitals contact the supported entablature. Ledges meet with plausible returns. Resolve floating supports, missing caps, disconnected cornices and roof ribs intersecting the wrong surfaces. Real construction references determine profiles, not whichever extrusion is quickest.

Align course heights and the FULL ledge profile around corners, including short returns. Derive repeated windows/columns from shared dimensions and projection depths; do not guess each extrusion independently. Consistent depth also makes reusable UVs and AO practical.

## Overlap
Small concealed intersections at construction joints can be reasonable; document which part covers which. Do not leave two visible faces on the same plane or use backing panels to fake an opening. Audit across objects and within objects, including slanted faces. Classify duplicates, intentional covers, open edges, reveals, detached caps, shading and UV faults before editing.
Delete genuinely redundant geometry, then check loose vertices/edges. Do not delete all nonmanifold/interior surfaces indiscriminately. For intentional layers, offset the documented geometry layer along the correct direction and verify the junction remains closed. UV movement does not separate surfaces. Convert through root/object transforms and scene units: 0.001 coordinate units is not automatically 1 mm. Check every overlapping pair ends on different planes. Never blanket-offset individual triangles without checking continuity.

## Triangles
Keep the source editable in quads. Do not blindly dissolve an imported triangulated mesh. Inspect export triangulation for nonplanar quads, skinny triangles and arch junctions.
A visible triangle may be protruding geometry, z-fighting, bad corner normals/tangents, distorted UVs or baked shading. Compare wireframe/face orientation, unlit basecolor, normal-disabled and final views. Correct normals only on demonstrated bad surfaces; globally flattening ornament is a regression. Double-sided rendering is an engine choice, not a universal repair.

## Imported shading data

Before extracting a body, removing roofs/stairs, merging vertices or splitting an
imported mesh, snapshot the original per-corner normal vectors with geometry and
UVs. Topology edits can change the normal fans on retained faces even when their
positions and UVs remain identical. Keeping a custom-normal attribute is not proof
that those vectors remain correct. Compare the retained corners after each such
operation; do not trust a later export round-trip as an independent baseline.

If damage is demonstrated, recover normals from the unmodified original using
unambiguous face geometry and UV correspondence, accounting for transforms and
deliberate translations. Preserve hard wall corners and smooth curved surfaces.
Do not reset every face to flat or average all normals to hide a local defect.

## Inspection
Locate the exact face with selection or a ray query; inspect coordinates, material and UVs against neighbors. Do not limit searches to axis-aligned planes: persistent stripes and wedges often originate on slanted triangles. Check each repeated module separately. Verify the preview mode in which the issue appears, not merely another renderer.
Compare geometry, UVs, materials, weights and normals with the checkpoint, allowing only intended differences. Save before edits, preserve unrelated data and inspect same-view before/after images. Do not claim a targeted check covers the whole model.

## Counts
Track source/evaluated vertices, triangle counts and a corner-split estimate. UV seams, hard normals, materials and skinning can enlarge exported buffers. Counts after serialization are separate evidence. Geometry Nodes instances may need realization on an evaluation/export copy to be counted. A successful split in one destination does not prove a universal per-mesh limit.
