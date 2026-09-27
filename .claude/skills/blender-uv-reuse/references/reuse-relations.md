# Reuse relations and semantic matching units (experimental)

Do not reduce every reuse decision to a boolean whole-chart equality test.
Record independent fields: coverage (`full`/`partial`), transform (`rigid`/
`scaled`), geometric reflection, UV reflection, X/Y density change and material
family. Rotation is ordinary rigid reuse, not automatically mirroring. Partial
and scaled relations may also be mirrored.

| User-facing type | Required evidence | Main risk deferred to later gates |
|---|---|---|
| Exact / normal | Whole matching geometry and material; no fitted scale | AO or unique art differs |
| Mirrored | Explicit correspondence and reflection flags | Tangent handedness, lettering, asymmetrical ornament |
| Partial | Entire member lies on a corresponding subset of the owner | Incorrect module phase, border/trim or owner-only AO |
| Scaled | Named generic material, size ceiling, separate X/Y limits | Unequal density and stretched recognizable detail |

Every relation is provisional until AO and all participating texture channels
are validated. Do not bake all stacked members into one texel region.

## Semantic walls: a facade is not always the right matching unit

The S10 matcher kept whole facades unique because they combined plaster, posts,
beams and window fronts. Small differences in the timber frame vetoed identical
large panels. Merely raising geometry tolerance did not solve this problem.

`semantic_regions.refine(chart, panel_materials)` separates only explicitly
allowed physical panel materials. Adjacent coplanar faces of a panel stay one
region; a point contact is not a shared edge. The remaining frame retains its
original chart and UV coordinates. Preserve parent ancestry and record the change
in matching-unit count; comparing raw chart counts before/after refinement alone
is misleading. Measure filled pixel area and reclaimed chart envelopes separately.

Korean TC S11 refines 13 unique composite facades into 45 complete plaster/window
regions plus their inherited frames. Exact correspondence shares 35 panels in
9 families, including all eight 1.2 by 2.4 upper-tower window fronts. This frees
26 repeated panel allocations, approximately 3.113 million working UV pixels,
without changing density, the frame layout, vertices or polygons. The remaining
panels really have differing dimensions or geometry; do not force them into an
exact-match group. These are geometry candidates, not approved final window art.

## Hollow frames and actual allocation economics

S11 reduced filled UV area by about 19% relative to S10 B, but the user correctly
identified that large frame outlines still retained the old facade rectangles.
That percentage did not establish a smaller packed atlas. Panel reuse alone is
not a complete facade optimization. Apply the same whole-surface/subset matcher
to the remaining timber frames; do not silently stop after matching panel fills.

S12 stacks three complete frames with 60.21%, 88.10% and 74.54% coverage of their
larger compatible owners, without geometric scaling or chart fragmentation.
One old approximately 740 x 737 working-pixel rectangle becomes completely empty.
Two others still contain independent panel owners. Their frame outlines are freed,
but their entire bounding rectangles are not empty. These are measured examples,
not a guarantee that the helper discovers every possible frame correspondence.

For an old chart envelope E and the remaining owner surfaces U, report both
`area(E intersect U)` and the owners whose envelopes still intersect E. An empty
surface region is not necessarily an empty packing rectangle. Report separately:

1. Filled owner UV union area, including shared families only once.
2. Released chart addresses and completely empty former envelopes.
3. Partially freed envelopes and the panel/trim owners still inside them.
4. Actual packed page dimensions and gutters, only after a packing experiment.
5. Texture memory at the chosen format/mip count, only after page sizes change.

Show actual before/after UV crops, including retained panels. Keep source density
and owner placement fixed at the geometry-only checkpoint. Do not move independent
panels or shrink islands merely to make a space-saving picture look better.
The current subset helper requires a matching whole-polygon anchor and checks
trimmed polygons within individual owner polygons; compound coplanar unions and
different subdivision patterns can still produce false negatives. A rejection
therefore means unresolved by this method, not proof that a frame cannot share.

## Partial roofs: different boundaries need not prevent surface reuse

`partial_surface_share.match_subset()` searches rigid/reflected anchor fits and
checks every member polygon against the same transformed owner surface. Use
exact corner correspondence for unchanged polygons. For a trimmed polygon,
require containment in a sufficiently planar owner polygon, bounded geometric
error, material agreement and both-axis density preservation.

An affine UV field is not always adequate even on a nearly planar quad. If its
residual exceeds the declared UV limit, read Blender's **derived render corner
interpolation**, then use that interpolation for the trimmed corners. Reading
`mesh.calc_loop_triangles()` fills an analytical render cache; it must never
replace authoring polygons or create triangle UV islands. Assert the authored
polygon vertex lists and zero-triangle count before/after. Keep the interpolation
manifest beside the test. Do not guess the export diagonal.

The reported West Hall roof pair has 18 full polygons versus 20 polygons after
two bottom-row cells were trimmed during physical-overlap repair. Both trimmed
pieces of each cell retain the same original face ID. A bijective topology
matcher therefore rejected the pair. Surface-subset matching reuses 93.8327% of
the complete end with a 180-degree rotation, **no reflection or geometric scale
on the accepted correspondence**. Maximum surface error is about 3.1e-6 scene
units. The cut-outs remain real geometry; the entire surviving roof chart shares
one coherent owner footprint. Do not label every opposite pair mirrored merely
because it looks symmetric.

For partial reuse, full-silhouette IoU is the wrong pass criterion: the missing
owner region is intentional. Test member containment, coverage of every member
surface, material agreement and differences only on the common region. Show an
isolated owner/member checker pair plus a UV overlay with the unused region.
Check UV union coverage, outside-owner area and self-overlap after assignment.
Subpixel seam intersections have an explicit numerical budget (0.1 working
pixel squared in S11); report them rather than claiming literally zero overlap.

## Half/third modules and bounded scaling

`scaled_rectangle_share.partial_rectangle()` covers an affine rectangular member
using 1/2, 1/3 or a product of such integer subdivisions of the owner rectangle,
with no scale fit. It retains material/page identity and both-axis density.
Corner anchoring establishes a geometric candidate only: a two-window texture
does not guarantee that its half has the right trim or decoration. Pattern phase
and contact AO must still be checked. The half/third cases currently have unit
specimen tests; they are not bulk-applied to the Korean TC.

`scaled_rectangle_share.proposal()` is intentionally proposal-only. S11's case
policy allows small generic wood patches at most 0.16 square scene units and
0.8 units maximum extent, with at most 2% change on each axis and 2% density change.
Large walls, roofs, windows, signs and ornate surfaces are outside this allowlist.
These values are editable experiment parameters, not a global asset standard.

Two small-wood candidates were found. The isolated Blender specimen demonstrates
one with approximately 1.95% change on its long axis and no short-axis change;
only the specimen receives these UVs. Main-model coordinates are unaffected by
the scaled experiment. Keep this distinction visible in the scene and report.

## Upfront factory rule

During modeling, tag facade parents, complete reusable panel/trim modules,
material families and intended texture grain direction. Preserve those IDs
through geometry repair. Search in this order: whole identical charts; exact
semantic modules; mirrored counterparts; strict partial containment; explicitly
bounded scaled proposals. A coarse geometric signature must not veto a valid
relation in a later category. Never increase tolerance to compensate for an
incorrect semantic unit or a missing relation type.

The helpers and S11 examples remain experimental pending the user's visual
acceptance. They extend the geometry-only checkpoint; they do not certify AO,
final packing, texture art or in-game shading.
