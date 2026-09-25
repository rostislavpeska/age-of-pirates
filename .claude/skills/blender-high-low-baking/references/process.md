# High/low architectural baking process

Research and Blender specimen work: 25 September 2026. Professional references are
evidence for workflow mechanics, not proof of any game's original authoring method.
The initial helpers were exercised in Blender 5.1.2. Engine acceptance is separate.

## Professional sources and the decisions they support

- [Joe Wilson, Marmoset baking tutorial](https://marmoset.co/posts/toolbag-baking-tutorial/):
  retain silhouette geometry, freeze triangulation/tangents, use deliberate UV
  seams at hard normals, and resolve projection instead of painting over errors.
- [Steph Everett, Senior Artist, baking handbook](https://marmoset.co/posts/the-toolbag-baking-texturing-and-rendering-handbook/):
  inspect the cage, isolate bake groups, test normals first, and separate local AO
  from occlusion between groups. Toolbag-specific buttons are not Blender settings.
- [Thiago Klafke, modular environments](https://www.thiagoklafke.com/tutorials/modular-environments/)
  and [xNormal walkthrough](https://www.thiagoklafke.com/tutorials/xnormal/):
  bake reusable surface/trim sources where appropriate, then test them on actual
  architecture early. A unique full-building bake is not always the efficient end state.
- [Adobe matching by name](https://experienceleague.adobe.com/en/docs/substance-3d/bakers/features/matching-by-name):
  explicit pairing prevents nearby geometry bleeding into a bake. In the included
  Blender helper this is implemented by object selection, not implicit suffix magic.
- [Blender baking manual, 4.5](https://docs.blender.org/manual/sv/4.5/render/cycles/baking.html)
  and [UV operators, 5.0](https://docs.blender.org/manual/en/5.0/modeling/meshes/editing/uv.html):
  active image targets, cages, image margins and seam-based flattening. Check live
  RNA for version-sensitive parameters; older manuals do not establish new behavior.

## 1. Contract and source organization

Keep AUTHOR editable; HIGH contains modeled relief; LOW is the destination mesh;
CAGE is a topology-identical projection envelope; REFERENCE contains donor meshes,
decals and photography. Use explicit allowlists for each bake and export. Record
unit scale, high/low/cage hashes, output resolution and normal convention. Keep
generated texture previews and scene files in the user's external asset workspace.

Classify each feature: silhouette/open space -> geometry; broad shallow relief ->
candidate bake; subpixel grain -> material detail or omission. For example, keep
roof curvature and edge tiles but bake interior tile rolls. Keep an open railing;
paper-backed shallow lattice may be baked after testing depth/parallax at game zoom.

For a paper-backed window, bake the assembled panel rather than separately packing
every lattice-bar face. Keep outer frames/posts and deep structural projections.
Bake a semantic mask alongside normal and AO so the later bitmap texture can
distinguish paper/infill from wood. Before changing high-source material slots,
save every polygon's material index and restore it after rebuilding the slots:
clearing Blender material slots can reset the indices. Check mapped interior
histograms and require each expected semantic class to occur; a successful all-zero
ID bake is not a usable mask. Preserve source-face correspondence, remaining corner
normals, root weights and UVs when removing the baked fine geometry on a duplicate.

## 2. Geometry before UVs

Fix unintended coplanar overlaps, exposed assembly gaps, inward normals and loose
faces. An intentionally closed low solid may contain concealed construction joints;
that does not make all those surfaces useful bake receivers. Subdivision cannot
repair an incorrect roof profile. Establish high tile/course dimensions and bevel
widths in model units; include sufficiently broad slopes to survive the chosen pixels.

Inspect low shading with no maps first. Do not smooth structural corners to reduce
the vertex count. Track source/evaluated vertices, triangles and split estimates.
Hard normals, UVs and material boundaries may duplicate serialized vertices.

## 3. Semantic UV charts

Separate roof slopes at hips/ridges, gable wood from tiles, tops from soffits, and
ridge/end-cap trims from broad tile fields. Align tile courses/grain intentionally.
Use arc distance along a curved slope as the initial row coordinate. Do not force
a compound-curved or tapering patch into a perfect rectangle if this stretches it;
use trapezoidal/fan charts, additional seams or a small constrained unwrap instead.

Run labeled square checkers and measure both UV axes; an area-only density number
can hide strong directional stretching. Use the companion texturing skill's UV/AO
rules. Choose density from camera coverage and destination memory, not assumed meters.
For a first test, use unique non-mirrored charts; enable reuse only after each
chart's geometry, tangent orientation and AO context are compatible.

### Roof-transition specimens

A generic repeating roll texture does not establish the value of a custom bake.
Before extending it across a building, inspect a proven reference as geometry,
UVs and decoded normal data together. Trace the actual atlas band to triangle IDs;
keep source positions and corner normals. Compare plain clay, wireframe,
normal-only and basecolor-only views with the same camera and light. Pixel color
alone cannot establish the height of a detail or the reference's original baking
software. A shaded atlas image is not evidence of individual tile meshes.

A cheap continuous eave strip can carry many round tile ends through its normal
map. Its turn relative to the main roof and the band's UV placement are part of
the illusion. Record the physical strip cross-section, UV band width in pixels
and roof-to-trim boundary. Preserve profile and exposed silhouette in LOW; model
tile rolls, course overlaps and end rims in HIGH as one coordinated construction.
Do not apply a roof-field map to a vertical fascia and expect circular ends.

Build the next specimen around a real roof-to-eave transition rather than another
isolated tile plane. Align each round end with its cover-tile row; tile pitch and
structural rafter pitch are separate design choices. Use the actual curved LOW
profile, approved corner normals and topology-matched cage. Determine whether a
continuous strip or individual cap solids is necessary at the intended distance;
compare both silhouette and grazing view, not only the top-facing render.

Raw GR2-style UVs may have integer tile offsets and an inverted V convention.
Cast half-precision coordinates to float64 before numerical analysis. Fold an
entire triangle's integer offset for display only; per-vertex modulo can split
seams or manufacture overlaps. Preserve real UVs on the imported model. Test both
green signs when the source tangent convention is unresolved, and label the
preview; do not declare the destination convention from the nicer-looking image.
Limit vector statistics to actual mapped texels, excluding atlas padding. A
compressed normal atlas need not have exact unit-length RGB vectors everywhere.

The project roof-transition experiment was exercised in Blender 5.1.2 after the
generic specimen. Its building-specific generator remains with the external
authoring project; no reusable roof kit is bundled. The following fitting lessons
were demonstrated on the vertical-eave pilot:

- Give a vertical front band identical plan coordinates at its top and bottom.
  Split its corner normals from the curved field, separate the UV charts, and
  rebake. Moving geometry under the old normal map is not a valid update.
- Do not create thickness by translating that entire shell down in Z alone:
  vertical outer and inner faces then overlap. Inset the underside in plan or
  construct a proper thickness profile. Inspect the section; a closed-manifold
  count does not detect coincident faces or prove correct shading.
- Fit an integer number of cover-tile rows to each span. With usable span S,
  end inset m and N centers, pitch is (S - 2m)/(N - 1). Keep the same phase on the
  slope and front band; choose N near the intended pitch, and keep enough inset
  for a complete end disc plus filtering clearance. Do not cut half a disc at a hip.
- Size the disc and rim from the actual front-band height. Give modeled relief
  compact support: blend to the receiver at the outer edge, hard crease, hip and
  crest. An unbounded ring or scallop can intersect its neighbor or suggest detail
  continuing beyond the low silhouette. A normal map cannot repair that outline.
- Phase alignment alone is insufficient: a round badge below a separate tile nose
  is still wrong. Inspect the joint in HIGH and baked LOW. The cover row must
  terminate at the round face, without a second neck/highlight between them.
  Match the reference's disc depth and edge treatment; a raised torus is not
  equivalent to a flat tile end with a shallow rim.
- Inspect opacity on the exact mapped source band, alongside color and normals.
  An alpha channel or transparent pixels elsewhere in an atlas do not establish
  that its eaves use cutout transparency. Decoder output is not proof of shader
  alpha interpretation. When deliberately using a cutout, derive its silhouette
  from the same row centers, discs and scallops as the normal source. An opaque
  backing/closure can fill the holes; inspect front, back, underside and shadows.
  Keep color/normal padding beyond alpha boundaries to prevent dark fringes, and
  validate coverage through destination mips separately.
- Keep raised hip caps, gable verges and central ridges as low geometry when their
  profile is visible. Follow the actual roof edge, cover the join and inspect where
  several caps meet. Detail under a cap may be concealed intentionally; exposed
  coplanar overlaps remain defects.

In this pilot the front/field charts had a 32.8-pixel gap at 1024 resolution,
with 12 pixels of dilation on each side. That leaves about 8.8 pixels before
filtering, not a guarantee for distant mips. Opposing-light high/flat/baked views
verified the vertical profile. Operator review then exposed a detached end-disc
design that those structural checks had missed. The next pilot moved the flat end
faces into the tile termination, removed the extra neck and used matching cutout
coverage on the outer and backing lip. Its baked LOW was inspected under both
light directions. Engine tangents, compression and in-game mips remain untested.

Padding is a pixel budget. A candidate 16-pixel bake margin at 2K leaves only one
pixel at mip4. Keep enough island separation for BOTH charts' padding and filtering,
then inspect actual downsampled/compressed outputs. This is a trial setting, not a
guarantee for all mips. Raster background is not evidence of chart coverage.

## 4. Frozen LOW and surface receivers

Finalize the export duplicate's evaluated modifiers, triangulation and corner
normals, then copy the cage. Keep AUTHOR untriangulated where useful. Any later
change to topology, UVs or normals invalidates the corresponding bake fingerprint.

For a solid slab/roof, copy only intended exterior faces to a receiver. Transfer
the original triangle winding, positions, corner normals and UV coordinates; when
splitting vertices, include normal and UV in the key. Verify equality against the
destination, not just approximate bounds. The receiver can be open; the runtime
solid keeps its thickness. Exclude underside, trim and adjacent walls from the pair.

## 5. Cage and pair selection

Use identical topology and face/vertex order. Move cage vertices only. Inspect for
crossing rays, self-intersections, missed tile crests and wrong neighboring hits.
The necessary offset follows actual maximum relief, not a universal 0.1 setting.
With an explicit Blender cage, `max_ray_distance` is not a substitute for cage design.
Start close; locally adjust or split a group rather than expanding a global cage.

The helper selects the declared HIGH objects and one active LOW receiver, explicitly
sets Selected to Active and the cage, and requires unique UVs. It needs a task-owned
scratch scene. Name filtering alone does not prevent wrong ray hits.

## 6. Bake order and outputs

First bake NORMAL only at low diagnostic resolution. Blender pilot settings are
Cycles, tangent space, +X/+Y/+Z, Non-Color, strength 1, explicit cage, EXTEND margin.
This establishes a Blender preview convention only. Use float EXR for editable
normal data and a 16-bit Raw/data PNG preview; verify reloaded pixels. Keep normals
out of display transforms, sRGB decoding and ordinary RGB-overlay blending.

Bake AO separately with declared occluders and distance. The helper emits a local
AO shader from HIGH, so reference meshes and broad scene shadows are not included.
Never multiply dark AO into albedo and then apply it again through a mask. Shared
texture pixels cannot contain different contact AO for different building positions.
Curvature/ID masks are optional authoring aids, not interchangeable with roughness.

## 7. Specimen acceptance and application

Render HIGH, LOW flat and LOW baked with neutral color/roughness, AO disconnected,
identical camera and two opposite light vectors. Test a curve, a shallow bevel and
an asymmetric feature. Observe the expected silhouette/parallax difference rather
than trying to cure it by boosting normal strength. Promote such details back to
geometry if the mismatch matters at the intended view.

The included specimens retain a closed slab with 286 vertices/568 triangles and
use an exact 143-vertex/240-triangle top receiver. Their 104,594-vertex high sources
are bake-only geometry. Initial tests demonstrated normal/AO generation and the
need to mark the top/side boundary sharp explicitly. No numerical engine-quality
claim follows from these counts.

Check finite vectors, approximate unit length away from filtering transitions,
zero positive-area UV overlaps, cage ordering and saved-data round trips. These do
not prove semantic coverage or visual quality. Record which images were inspected.
Apply only after the representative bake is visually sound. Recheck every repeated
candidate and record low/high counts separately.

When rebuilding a mesh on an already rigged object, verify both vertex-group names
and actual weights afterward. An unchanged armature modifier or parent does not
prove the replacement mesh is skinned. Restore the intended static-root weights
on new vertices and verify attachment bones independently.

## 8. Destination handoff and failure response

Test the final triangulated mesh, UVs and tangents in the actual destination shader
with an asymmetric raised/recessed coupon. Verify green-channel convention, mask
packing, mips and material bindings from a working target profile. Compare normal
disabled/enabled before altering color. Destruction may need different contact AO
and new interior UVs; a baked intact model does not certify fractured shading.

| Symptom | First falsifiable check |
| --- | --- |
| Black wedges or stamped neighboring details | Selected HIGH list, cage intersection and ray direction |
| Faceted/diagonal shading | LOW triangulation and corner-normal identity before bake versus runtime |
| Rounded slab rim without bevel | Explicit hard boundary; flat side-face flags alone are insufficient |
| Seams at islands | Hard-normal/UV correspondence, padding, tangent convention and reloaded data space |
| Inflated/inverted relief | Normal axis convention, texture decoding and incorrect image transforms |
| Dark shared patches | Overlapping bake writes, wrong occluders or duplicate AO multiplication |
| Nice close-up, unreadable game view | Feature width, texel allocation and compressed mip evidence |

Stop repeating the same bake after two unsuccessful visual attempts; inspect the
mesh/UV/cage data and change one demonstrated cause. Keep failed evidence separate
from the accepted version rather than silently replacing history.
