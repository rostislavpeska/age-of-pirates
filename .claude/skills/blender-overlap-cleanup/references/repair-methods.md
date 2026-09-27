# Overlap methods and evidence

## Detection layers

**Coplanar surfaces:** transform vertices to world space; broad-phase AABB tests;
parallel/antiparallel geometric normals; plane-distance test; project into the
best-conditioned 2D coordinate plane; measure positive polygon-intersection area.
Check within and across objects, independent of vertex indices, UVs and materials.
Shared edges alone are not overlapping area. Match original ancestry when comparing
stages with different face subdivisions. Curved/nonplanar polygons are exclusions,
not silent passes.

**Crossing surfaces:** use read-only triangulation with original polygon IDs and
BVH candidate pairs, then intersect the two triangle/plane segments. Require a
positive-length common segment through the interior of both original polygons;
exclude shared boundaries. Keep points and part IDs for review. Curved surfaces,
thin layers and alpha need explicit treatment. A crossing count describes face
pairs, not distinct physical joints.

**Solid overlap/containment:** positive intersection of two verified axis-aligned
boxes is `product(min(maxA,maxB)-max(minA,minB))` when all three extents exceed the
tolerance. An AABB of an arbitrary shape is only broad phase. General solids need
verified closed orientation plus appropriate point/volume intersection methods.
Completely contained duplicate solids can have zero transverse surface crossings.

The supplied planner consumes records with `id`, world `points`, unit geometric
`normal`, `area`, `hidden` and `alpha`. `overlap_pairs(records)` and
`positive_box_overlaps(boxes)` are read-only. Each box has stable `id`, `lo`, `hi`.
`transverse_pairs(triangles, face_indices, candidate_pairs, records)` consumes
read-only triangle arrays and BVH candidates, returning original polygon-pair
witnesses. Its dominant-plane test on nonplanar polygons is a review heuristic;
do not mistake it for a complete curved-solid or alpha-mask certificate.
`repair_plan(records, certified_boxes)` returns replacement polygon coordinates
with original indices and removal reasons; it does not modify meshes or certify
the supplied boxes.

## Verify a usable solid before trimming against it

For an axis-aligned construction box, all six outward boundary rectangles must
be covered by current opaque render polygons, within declared numeric tolerance.
An old closed source is useful for locating components, but does not establish
current closure. Previous hidden-face cleanup may have removed caps.

A missing cap may be covered by the **interior** of an already verified retained
solid. Iteratively establish such union dependencies, with a directed record of
which solids cover which missing patches. Reject an unanchored cycle of mutually
assumed coverage. This licenses intact union-boundary cleanup only while those
solids stay together and opaque. A bounding proxy alone never licenses deletion.

## Repair selection

For fused construction, subtract parts of a surface that lie inside verified
retained solids. Then assign remaining coincident patches to one owner. A detailed
visible family can win over an obsolete black backing; preserve semantic intent,
alpha and texture/bone compatibility rather than choosing by object order alone.
The helper uses detailed-before-hidden, larger-area, stable-ID priority as an
explicit starter policy, not universal artistic ownership.

Opposing contacts default to `opposing_policy='report'`. The optional
`single_owner_intact` policy is only for confirmed same-assembly intact rendering
with compatible sidedness and a separately preserved capped/destruction source.
Do not apply it to independently separating debris or arbitrary thin double-sided
surfaces. Report these decisions per contact.

Plane subtraction may create holes. Divide those into coherent polygons with
straight cuts; avoid per-pixel boundaries. Planar ngons are permitted. A residual
triangular region can become three quads using edge midpoints and its center;
propagate boundary splits to neighbors when a conforming closed mesh is required.
Read-only triangle arrays must never replace the authored quad mesh.

The helper drops extremely small numeric remnants (area <= 1e-8 projected units,
or minimum rotated-rectangle width < 5e-7 units); these are example engineering
tolerances for the measured consumer scale. They are not real-world millimeters.
Review total dropped area and narrow legitimate features on other scales.
Its default plane tolerance is 1e-5 scene units. Normalize unit normals.

The consumer applicator must preserve vertex-group names/indices, interpolate
weights and every UV layer at cut vertices, carry per-face semantic/ancestry
attributes, preserve smooth/hard normals, and remove genuinely unused vertices.
Replacing a Blender mesh may require recreating its vertex groups. Reapplying all
custom normals may quantize even untouched vectors; measure the actual retained
vectors and prefer unchanged data for untouched objects.

Blender's Exact Boolean solver is an alternative for verified suitable solids.
Its output still needs the topology, UV, normal and budget gates. A whole-building
Boolean on open/material-split meshes is not a shortcut to a certified result.
Different props should generally be repositioned or resized into clean spacing
instead of unioned into one object (e.g. two jars intersecting).

## Evidence: Korean Town Center, September 2026

The facade generator appended separate closed boxes for posts, rails and panels,
then repeated full facades at corners. A pre-UV/source snapshot already contained
penetrations; later UV and hidden-material operations carried them forward.
Material changes made dark/light competition more obvious. Comparing original
face IDs found no new coplanar pairs introduced by the later classification cuts.
The counts alone had increased because those cuts subdivided existing contacts.

The repair experiment found 588 coplanar pairs (350 co-directed partial pairs,
238 opposing pairs), plus thousands of transverse polygon-pair crossings. A
coplanar-only audit missed vertical penetrating corners. Verified box/retained-
union clipping repaired the wall/frame construction and box props; one intersecting
yard jar was repositioned. The applied Blender mesh, not just the plan, passed the
coplanar audit and retained zero triangular authoring polygons. This does NOT
certify arbitrary curved roof/ridge contacts: those remained separately recorded
for architectural review. The user subsequently accepted the exterior and interior
as good enough to continue, explicitly not perfect. This accepts the local repaired
candidate for UV work; it does not certify the residual curved contacts or establish
general automatic accuracy. Do not describe the entire asset as intersection-free.

Another failure was handing over an inactive diagnostic scene. The corrected
contract requires the repaired material-colored model active and framed in the
live session, followed by a fresh native screenshot inspected by the agent.

## Primary sources consulted

- [Blender 2.91 modeling release notes](https://developer.blender.org/docs/release_notes/2.91/modeling/): Exact Boolean treatment of coplanar/overlapping geometry. This supports solver choice, not automatic clean authoring topology.
- [Blender Intersect Boolean manual](https://docs.blender.org/manual/en/latest/modeling/meshes/editing/face/intersect_boolean.html): exact/self-intersection options and their cost.
- [Shapely difference](https://shapely.readthedocs.io/en/stable/reference/shapely.difference.html): polygon subtraction and explicit precision-grid behavior. Tested with Shapely 2.1.2.
- [CGAL self-intersection repair and snap rounding](https://www.cgal.org/2025/06/13/autorefine-and-snap/), Loriot and Valque, 13 June 2025: exact construction can gain intersections again after conversion to floating coordinates. This supports rerunning the detector on the applied/serialized Blender result.

These are research sources; the helper is an independently written limited planar/
box method. It does not implement or claim CGAL's general triangle-soup guarantees.
