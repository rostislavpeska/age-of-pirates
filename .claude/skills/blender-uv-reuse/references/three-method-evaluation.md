# Three-method geometry-sharing comparison (experimental)

Compare alternatives from one immutable chart manifest and the same accepted
geometry. Cache an unchanged baseline rather than repeating an expensive solver.
Preserve all source sharing groups, whole charts, material identities, hidden
family cells, world geometry and authored quads/ngons. No AO or packing belongs
in this checkpoint. Report candidates and rejected examples, not only a winner.

## A / strict correspondence

Use `geometry_share.py`: compatible polygon boundaries, material patterns and
rigid/reflected 3D fit, with no fitted scale. This recovers complete mirrored roof
slopes. Different internal subdivisions can still prevent a valid planar match.

## B / equivalent planar material regions

Use `planar_share.prepare()` and `match()` on whole charts. The helper:

1. Fits a plane and rejects excessive nonplanarity, inconsistent normals,
   overlapping source faces, invalid polygons or a non-affine existing UV field.
2. Unions the projected faces **by material**, retaining holes and disconnected
   regions. Internal edges need not agree, but the visible surface and material
   regions must agree within the strict surface tolerance.
3. Proposes rigid/reflected boundary-edge alignment without a scale factor;
   tests symmetric difference and a symmetric Hausdorff estimate for the regions.
4. Transfers the owner's affine UV field to every member corner. With member
   plane coordinates `x`, alignment `(R,t)` and owner UV field `(A,b)`, use
   `u_member = (x R^T + t) A + b`. No face splitting or retriangulation occurs.
5. Fits the UV-to-UV linear map and bounds **both singular values** around 1.
   Equal UV area alone can hide 2x stretch on one axis and 0.5x on the other.
6. Compares aligned silhouette and material-ID images at 256 and 1024 pixels,
   each at two subpixel phases. Geometry/material/density gates and the image
   gate must all pass. Every member is checked directly against the final owner.

Korean TC experiment parameters: planarity 2e-5 scene units; affine UV residual
0.025 pixels; surface tolerance `2e-5 + 2e-5 * L`; density axes within 0.1% plus
1e-5 numerical allowance. L is the planar bounding-box diagonal. These are case
parameters, not a universal recommended precision.

## C / bounded approximate regions

Keep B's whole-chart and material constraints, but experimentally increase the
relative surface tolerance to 0.0025. Keep a second screen-space discrepancy
limit of 0.5 pixels at a declared 120 pixels per scene unit; it is a review-camera
contract, not a guarantee at arbitrary zoom. Existing density is still preserved.

Require raster silhouette IoU at least 0.995 at 256 and 0.997 at 1024, with at
most 0.001 differing material coverage on common pixels, at both phases. Log
all thresholds and errors. Alpha borders, normals/tangent handedness, grain,
decoration and contact AO remain separate later gates, even if these images pass.
Record UV reflection separately from the arbitrary planar basis reflection and
the lifted world-transform determinant.

C is deliberately approximate. Recommend B by default when C offers only small
additional savings: first require the numerical and image gates, then prefer
strict geometric equivalence and maximize saved area within that tier. Report
C's extra savings separately so a human can choose the controlled compromise.
Do not describe the conservative choice as a measured perceptual preference.

## Image evaluation is useful, but not complete

Rasterize unified material regions at pixel centers. A polygon scan converter
can change edge pixels merely because an identical boundary has more vertices.
The first experimental rasterizer falsely rejected an identical wall strip;
direct region sampling removed that artifact. Keep a regression for this case.

Finite image samples can miss subpixel differences. Conversely, a one-pixel
boundary difference can dominate a thin strip's IoU. Retain independent surface
distance and both-axis density tests; save the difference image, affected pixel
counts and surface error. Do not infer absence of defects from an empty-looking
thumbnail. Shapely's Hausdorff calculation here is an estimate over the polygonal
representation, not CGAL's bounded-error mesh distance algorithm.

Useful primary references:

- [CGAL distance functions](https://doc.cgal.org/latest/Polygon_mesh_processing/group__PMP__distance__grp.html):
  distinguishes sampled approximate distance from bounded-error Hausdorff tools.
- [Open3D ICP registration](https://www.open3d.org/docs/release/tutorial/pipelines/icp_registration.html):
  local registration is an alignment tool; fitness and residual alone do not
  establish material, UV or complete surface correspondence. ICP was researched
  but not implemented in this bounded experiment.

## Korean TC S10 evidence and limits

| Method | Freed addresses | Unique charts | Extra freed vs A |
|---|---:|---:|---:|
| A strict | 1,133 | 223 | 0 |
| B equivalent planar regions | 1,136 | 219 | 3 |
| C bounded approximation | 1,138 | 217 | 5 |

1,714 original visible charts; B joins subdivided stone-cap patches and a wall
strip. C gains two further addresses; seven attempted near-matches fail its
image gate. All old families remain intact. B's new planar image comparisons
have exact sampled silhouette and material agreement. This does not approve AO
or texture-channel reuse. Manual acceptance of S10 is still pending.

Readback preserves 5,234 polygons and zero authored triangles, with no geometry
or custom-normal change and no different-owner UV collisions. Twenty inherited
intra-chart seam intersections, each below 0.073 working pixel squared, remain
unchanged. Report baseline defects separately from new regressions rather than
silently claiming a globally perfect UV map.

Deliver all three live Blender versions, actual UV sheets, group colors, delta
highlights, a checker with hidden faces black, opposite views and accepted/rejected
patch images. Read back actual loops, not only the plan. Workbench Texture mode
uses the active image even when its shader link is absent: give hidden checker
materials an explicit black image, or they can incorrectly show a checker.

Run `python -m unittest discover -s scripts -p 'test_*.py'` from this package.
The new tests cover subdivision independence, holes, material regions, 3D rigid
and reflected transforms, both-axis density, nonplanar/non-affine rejection,
duplicate faces, input preservation, near matches and image roundoff.
