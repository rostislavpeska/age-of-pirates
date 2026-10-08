# Evidence and packing decisions

Researched 2026-10-08. These are original summaries of primary documentation, not
copied manuals. Tools were inspected, not purchased or installed. Local experiment
results are consumer evidence and must travel in its handoff, not private paths here.

## 1. Optimize ownership before placement

[Epic's texture/lightmap comparison](https://dev.epicgames.com/documentation/en-us/unreal-engine/unwrapping-uvs-for-lightmaps?application_version=4.27)
explicitly distinguishes reusable texture UVs from unique lightmap UVs. Repeated
surfaces can reuse texture coordinates. Its Lightmass-specific page-border advice
must not be generalized to another engine's albedo/normal atlas. For architecture,
reuse requires surface/material/direction correspondence; contact AO may require
later variants. A surface being dark does not establish that it is invisible.

## 2. Why shape-aware packing matters

[Blender's packing manual](https://docs.blender.org/manual/uk/5.2/modeling/meshes/uv/editing.html)
distinguishes rectangle bounds, convex outlines and complete concave shapes. Only
the last can use interior gaps. Rotation and scale are independent packing choices;
exact-shape and exact fractional margins can cost considerably more computation.
The cited manual is 5.2; inspect the installed operator RNA before using an option
in a different build. Our 5.1.2 experiment had valid roof transforms but fragmented
18 composite wall owners and was rejected. An API success is not a family-preservation
test. Geometry-connected UV islands and semantic sharing groups are different units.

[Jylanki's MaxRects reference](https://github.com/juj/RectangleBinPack/blob/master/MaxRectsBinPack.h)
provides multiple placement heuristics and optional quarter-turns. This is a useful
rectangular baseline; it cannot reclaim a hole enclosed by one rectangle. A solver's
occupied rectangles are not equivalent to painted surface area. Keep these metrics
separate, especially for hollow frames and curved roof-edge ribbons.

[xatlas's maintained interface](https://github.com/jpcy/xatlas/blob/master/source/xatlas/xatlas.h)
separates chart generation from packing and exposes density, resolution, padding,
bilinear support, block alignment and search choices. A requested resolution alone
does not establish the final page count or UV density; read the actual output.
Do not invoke a full atlas generator when only relocation of approved charts is
authorized. Always protect semantic owner/member correspondence outside the packer.

## 3. A pixel is a measurement unit, not permission to remove gutters

[UVPackmaster's pixel margin documentation](https://uvpackmaster.com/doc3/blender/latest/20-packing-functionalities/30-pixel-margin/)
ties pixel alignment to destination texture size. Fixed-scale alignment can preserve
only a chart's origin if its dimensions are fractional. Scaling to align every corner
can introduce nonuniform distortion; snapping many vertices can collapse UV faces.
Therefore prefer integer translations and validated rectangular alignment. Do not
round every curved vertex or change chart aspect ratios merely for prettier grids.

[Adobe's padding explanation](https://experienceleague.adobe.com/en/docs/substance-3d-painter/using/technical-support/workflow-issues/export-issues/texture-dilation-or-padding)
explains dilation and why lower mip levels need it. Infinite dilation fills unused
background but cannot make arbitrarily close unrelated surfaces immune to bleeding.
Measure inter-chart gap and page border independently, at the final resolution.
A mip level m has 2^m fewer samples per axis; base-level margins shrink accordingly.
That arithmetic is an estimate, not a guarantee for anisotropic filtering or a
specific engine's mip-generation kernel. Validate exported channels at relevant mips.

[Microsoft's block compression specification](https://learn.microsoft.com/en-us/windows/win32/direct3d11/texture-block-compression-in-direct3d-11)
defines 4x4 blocks, with 8 bytes for BC1 and 16 for BC3/BC5/BC7. Shared block
endpoints can mix nearby colours; block alignment may help but costs space and is
not a universal requirement to pad every edge by four texels. For format accounting,
sum ceil(width/4) * ceil(height/4) * bytes_per_block across actual mip levels and
unique channels/pages. Blank pixels still allocate blocks. Better occupancy at fixed
size improves resolution/headroom; it does not reduce the allocated texture bytes.

## 4. Search with a stopping rule

[UVPackmaster's heuristic search](https://uvpackmaster.com/doc3/blender/latest/20-packing-functionalities/40-heuristic-search/)
retains the best of multiple attempts within a chosen duration. This supports bounded
experiments instead of trusting a single arrangement. Declare the candidate list,
runtime limit, allowed rotations and metric. Do not purchase a plugin or invoke its
AI/external services merely because its documentation is useful.

Our mask experiment uses conservative pixel-grid silhouettes, proper quarter-turns,
whole owner groups and exact post-checks. Its greedy ordering can miss better layouts;
coarse pixels can reserve more padding than necessary. Report those costs and retain
a better rectangle result. Neither algorithm establishes a mathematical optimum.

## Practical diagnosis

| Symptom | Evidence to collect | First action |
| --- | --- | --- |
| Large blanks between subtype rows | content vs row-envelope pixels | pack across subtypes, retain chart ID masks |
| Huge boxes around thin curves | owner filled area vs envelope | nest around outlines; then evaluate strip straightening |
| Repeated houses consume new texels | geometry/material/role correspondence | share across the full set, retain AO lineage |
| Many tiny islands waste gutters | perimeter/padding to content ratio | stitch physically continuous compatible regions |
| Atlas looks full but details blur | real two-axis texels/unit | inspect stretch and below-floor surface area |
| Dependency renamed as new texture | runtime paths/hashes and cell mapping | restore existing resource; do not allocate another page |
| Packer moved or split owner parts | per-owner affine residual | reject candidate before touching Blender source |

These diagnoses guide experiments; they do not waive chart, density, budget or
operator requirements. Space accounting should state exact raster counts plus
geometric/pixel-boundary limitations, rather than claiming fictitious single-pixel
optimality for a heuristic search.
