# Roof geometry, junctions and disconnected UVs

This is the generic implementation contract, not a claim that every operation
already exists. Units/tolerances come from the asset scale and destination texel
size; culture, ridge shape and finish do not belong in classification.

## Detect in geometry, independent of UV layout

Use the frozen evaluated triangles in one frame with a declared up vector.
Distinguish geometric face normals from shading normals. Build edge adjacency
from topology; separately find spatially matching boundary segments on split
objects/duplicated vertices using bounded tolerances and projected overlap.
Do not weld the source or assume coincident segments necessarily belong together.
Reject ambiguous pairings, overlapping shells and inconsistent orientation.
Retain face/part IDs, segment intervals, both sides and evidence/confidence.

For a shared edge with consistently oriented face normals nA/nB and consistently
directed edge t, atan2(dot(t, cross(nA,nB)), dot(nA,nB)) gives a signed turn.
Its sign depends on the winding convention; prove it on convex and concave
controls, including mirrored transforms, rather than hardcoding an untested
sign as "valley". Cross-sections on both incident surfaces establish whether
the crease is locally convex or concave. Ridge versus sloping hip also depends
on its course, surrounding slopes and runoff, not merely its dihedral angle.

Smooth or tessellated roofs can encode the same junction through a narrow band
of faces instead of a single crease. Trace the physical intersection/transition
of the declared slope surfaces and test nearby sections. Do not classify by
"distance to the other slope family": that also selects convex verges. Use
surface-gradient drainage as supporting evidence, not as a universal answer for
flat, overhanging or upturned surfaces. Mark unresolved candidates for review.

Chain compatible segments into junction paths with stable IDs, tangent, side
labels, endpoints, branches and local widths. An inventory includes absent and
ambiguous cases explicitly. A supplied answer key cannot prove no junction was
missed. Compare discovered candidates against the declared architectural scope.

## Construct from parameters

The project selects the profile, terminal form, tiling and overlap conventions.
Generic construction samples its section along the measured path with a stable
frame (transport through bends; avoid sudden Frenet-frame flips). Fit or trim
sections against BOTH receiving surfaces. Handle mitres, branches, seated ends,
eave outlets, thickness and cap winding explicitly; do not leave floating tips.
Check gap, penetration, self-intersection and silhouette against the unmodified
receivers. Author LOW changes only inside the task's geometry authorization.

When detail is baked, use a temporary local HIGH and existing bake contracts.
Require expected treatment coverage on both faces of a two-sided junction.
If a shared texel also serves a distant surface where that treatment is wrong,
record the exact conflicting readers. Do not hide the missing half, paint the
distant surface, or unshare UVs without authorization. A local bake cannot solve
an incompatible shared-texel contract by itself.

## Verify continuity across UV breaks

### Body-to-end mapping implementation contract

Keep authoring coordinates separate from stored UVs. For every destination texel,
resolve its actual triangle and barycentric weights, reconstruct the physical
point, and evaluate the SAME fitted pattern used by the neighbouring surface.
Never fit the body and end independently to their island bounding boxes.

1. Declare the shared rim and its two receiving sides. Register the sides through
   `paired_surface.register_boundary` where its supported conditions hold. Match
   endpoints, direction and partial edge subdivisions; refuse ambiguous attachment.
2. Attach the existing pattern's coordinates/IDs to that rim. Arclength identifies
   the physical seam; it does not automatically replace the existing pattern's
   lateral coordinate or change its pitch. Interpolate the approved pattern's
   coordinate along the rim, then continue it onto both receiving surfaces.
3. Evaluate body and cap from the same piece identity, centreline, course phase,
   cross-section and deterministic material seed. Use surface-local depth/radial
   coordinates for cap relief. The cap need not carry the body's longitudinal
   grain in the same direction, but rim colour/moss/material must agree.
4. Derive the alpha silhouette from that same physical profile. Project through
   all front/back/underlip/cap readers. Do not generate a separate circle grid or
   paste a resized 2D body row into the end island. A too-thin receiver or a shared
   texel needing opposite alpha is a measured compatibility failure, not something
   that greater mapping precision can solve.
5. Evaluate effects in physical/piece coordinates and rasterize them separately
   into the existing islands. Distinguish true exposed rim wear from UV boundaries.
   Keep structural normal, semantic IDs, curvature, AO, moss protection and alpha
   as named inputs; roughness is not a replacement for a moss mask.
6. Convert each sampled physical normal into the destination's own tangent frame
   with the exporter/runtime convention. Preserve the intended turn between body
   and cap; do not force equal tangent RGB or physical normals at a hard corner.
   The existing triangle-frame diagnostic is not an exact engine tangent baker.

Validate rim position and piece/phase coverage, then per-channel continuity and
compressed filtering at actual resolution. Geometry correspondence can be exact
while rasterized colour still differs through quantization, filtering or shared
readers. Never promise perfect pixels from a registration-only test. Reuse valid
structural bakes for effects-only work; if a structural map is demonstrably wrong,
mark only its dependent stage invalid and retain the original source.

For a continuous surface, pair samples by 3D location on both sides, then map
them independently into their actual UV triangles/pages. Compare:

- semantic piece ID, material class and pattern phase in a common physical frame;
- BaseColor in a declared colour space, roughness/masks and alpha;
- decoded normals transformed from each UV tangent frame into the same object
  or world frame. Tangent-space RGB need not match across rotated/mirrored charts;
- equivalent interior samples, to distinguish a seam from intentional texture
  variation. Include endpoint/corner probes and all shared readers.

An intentional hard corner may have different normals: compare to the expected
paired surface/relief, not a forced equality. A tube body turning into its end
needs continuous rim, identity and material response, not identical normals.
Never exempt a seam solely because the material/UV ID differs. Exclusions need
a declared physical boundary and coverage evidence. Test actual decoded mips
at destination resolution, then inspect matched close and target-size views.

Required controls before claiming a complete checker: continuous plane split
in UVs; duplicated/split-object boundary; mirrored chart; intended material
boundary; wrong tile phase; flipped normal; one-sided valley; shared-reader
conflict; corner termination; compression-induced seam. Name unsupported cases.
The existing colour-seam monitor covers only part of this contract; extend its
implementation after logged reuse/gap inspection instead of inventing another
standalone checker for each building.
