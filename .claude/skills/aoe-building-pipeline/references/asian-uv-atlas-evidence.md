# Asian building UV composition: installed-asset evidence

Measured 25 September 2026 from the installed DE assets. Work products, decoded
textures, overlays, raw mesh arrays, hashes and Blender projects remain outside
the live mod in `Korean_Civilization_Research/Vanilla_UV_ReverseEngineering` and
`Hybrid_UV_03`. Do not copy the vanilla maps into runtime art or public skills.

Use the reusable [chart-joining and AO procedure](../../blender-architecture-texturing/references/chart-joining.md)
for authoring. This document records AoP evidence and the Korean trial decisions.

## Observed composition

The sampled assets combine building-specific facade/roof regions with repeated
strips/details and a cross-building texture library. Their main sheets are neither
all-unique lightmap layouts nor generic tiled materials applied to every face.

- China TC age 2 has large facade panels, coherent roof shapes/eave bands, narrow
  beam/trim regions and separate landmark details. Actual UV triangle pairs reuse
  facade patches. Small window/structural motifs appear in the mapped images on
  broad low-poly surfaces; individual construction boxes are not required for
  every visible line.
- All three sampled Japan shrine age 2 variants use the same
  `japan_shrine_age2_03_mata_basecolor` sheet.
- China TC age 2 uses its own main sheet and `Asians_accessories_mata`. China TC
  age 4 also references `china_waracademy_age4_matc`.
- Japan TC age 4 adds `japanese_caslte_age4_mata` (the shipped spelling) to the
  common accessories sheet and its own main map.
- China war academy age 2 uses its own sheets, common accessories, an age 4 academy
  sheet and Chinese market age 2 material. Age 4 continues reusing age 2 maps.
- Chinese village `mata` and `matd` reference the same 1024 map but use different
  shader profiles: `default` and `default_doublesided_cutout`. Image identity does
  not make the two material slots interchangeable.

The inspected China TC2, Japan TC4 and Chinese village mesh vertex layouts expose
`TextureCoordinates0` only, plus Position, Normal, Tangent and packed static data.
The packed fields were not decoded. This does **not** prove absence of vertex AO,
nor establish a second runtime AO UV set. Default main materials reference
BaseColor/Normals/Masks/Details; some shared prop materials omit Details. No new
channel interpretation is inferred from those names alone.

## Measurements

Density is area-weighted median pixels per **raw model coordinate unit**, after
the common axis conversion, not assumed metres. Invalid/degenerate triangles are
reported and excluded. Exact reuse is a lower bound based on matching UV triangle
coordinates within 1/16 source texel, grouped by the actual image. Different
triangulations and partial strip overlaps are not counted as exact matches.

| Main building map | Size | Median density | Exact stacked surface | Exact-triangle reuse factor |
| --- | ---: | ---: | ---: | ---: |
| China TC age 2 | 2048 | 119 | 18.7% | 1.17 |
| China TC age 4 | 2048 | 139 | 25.7% | 1.23 |
| Japan TC age 2 | 2048 | 137 | 16.8% | 1.13 |
| Japan TC age 4 | 2048 | 116 | 20.3% | 1.15 |
| Japan stable age 2 | 2048 | 147 | 32.0% | 1.36 |
| China war academy age 2 | 2048 | 128 | 38.6% | 1.37 |
| China war academy age 4 | 2048 | 143 | 72.6% | 2.11 |
| Chinese village age 2, variant 1 | 1024 | 144 | 89.7% | 3.67 |
| Japan shrine age 2, variant 1 | 1024 | 137 | 65.3% | 1.73 |
| Japan shrine age 2, variant 2 | 1024 | 137 | 47.8% | 1.43 |
| Japan shrine age 2, variant 3 | 1024 | 137 | 11.9% | 1.08 |

Some shipped stacks distort their geometry; imitate the architectural economy,
not every defect. For example, the Chinese village mesh 3 door-panel triangles
1526..1541 form eight congruent repeats, while some other repeated patches have
significant size variation. China TC2 mesh 0 faces 32..39 contain congruent reused
facade triangles. These are useful reproducible traces, not a guarantee for all
faces in the asset library.

Raw UVs include integer tile offsets and an inverted V convention relative to the
Blender preview. The measured triangles did not cross integer tile boundaries.
Only whole-triangle integer translation was used for visualization; per-vertex
modulo would manufacture overlaps. Green overlay edges indicate exact repeats;
orange means no exact-triangle match, not proven global uniqueness.

## What can be inferred, and what cannot

The observed data supports authoring a modular texture vocabulary, low-poly facade
receivers, measured roof/trim mappings, intentional repeats, and building-specific
patches. It does not reveal the original artists' software, order of operations,
high-poly source or whether each normal detail was baked or painted. A reconstructed
workflow must be proved by our own specimens instead of claiming recovered history.

## Korean trial and corrected process

The v16 repeating material trial had inconsistent density. The v17 unique layout
and v18 density/context-reuse layout then over-fragmented the construction geometry.
They passed density/intersection checks but were rejected by the user as final UV
composition. Keep them as diagnostics only. Packing and per-face projection cannot
replace architectural chart construction. The Korean direction is authored bitmap
atlases plus unique/variant patches; procedural pattern shaders are not the target.

Three small tests now distinguish the relevant constraints:

1. A continuous two-panel wall accepts one chart while one side is shaded by a
   corner. Its measured mean ambient visibility is 0.884 on one half and 1.000 on
   the other. This variation is representable because the halves use different
   texels. Stacking the halves instead produced required minimax errors up to
   0.235 in that experiment.
2. An actual Korean bay repeated in the same local context shares one bake owner.
   Adding a corner gives a different AO field. On the sampled front faces, 5.14%
   of covered pixels conflicted with a 0.05 scalar error budget plus 0.01 allowance;
   maximum minimax error was 0.230. The allowance is not a measured sampling
   confidence bound. This demonstrates why the corner needs a variant, not why
   every face needs an island.
3. A shallow full-bay pilot demonstrated geometry-derived normal/AO relief on a
   two-triangle receiver. Grazing inspection also exposes its lost edge/parallax.
   Therefore the actual TC application targets only paper-backed inner window
   lattice; main frames, posts, open rails and silhouette edges remain geometry.

The window application bakes 14 actual panels from six wall assemblies. Its 98
fine lattice bars become normal/AO detail. Five coherent 128 px/unit patches fit
one 512-square atlas: three west-hall windows share one patch, eight tower windows
share another, and the three rear-hall windows keep separate map variants. Reuse
requires <=0.02 texel dimension difference, <=0.04 owner AO/semantic-mask difference,
and <=5 degrees tangent-normal difference on corresponding covered interiors.
Each channel is checked separately. Padding/boundary/mip and game checks remain
necessary; these thresholds are a measured project trial, not universal defaults.

The camera allocation experiment sampled 16 azimuths at elevations 30/45/60 degrees,
using face centers and inset corners. It identified 599 non-cutout downward faces
(177.67 square raw units) for 16 px/unit and 3589 camera-occluded candidates for
32 px/unit, versus 128 for visible/protected surfaces. Geometry was retained.
This is finite, opaque-BVH evidence; cutouts and low-angle views require inspection.
The rejected full-building packing is not the source of the accepted chart design.

Next propagation follows the same order: coherent facade patches and reusable
trim regions first; unique contact/landmark variants second; then density, AO
compatibility, packing and artistic bitmap work. Preserve geometry and approved
roof UVs while deciding those patches. Do not run another full unique repack to
claim that chart fragmentation has been fixed.
