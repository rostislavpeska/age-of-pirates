# Vanilla Asian open surfaces: measured 2026-09-25

Scope: Chinese/Japanese Town Center age2, Chinese village age2 variant01, Japanese
shrine age2 variant01; each intact and damaged. Read original bound GR2 meshes,
not converter output. Combined material meshes were measured together; damaged
topology was separated by bone binding so touching independent pieces cannot
artificially close one another. Positions use Blender (X,-Z,Y) from raw GR2 XYZ.
Raw units are not assumed to be metres.

## Observations

| Asset | Intact triangles | Damaged triangles | Intact boundary edges | Damaged boundary edges |
| --- | ---: | ---: | ---: | ---: |
| China TC age2 | 3,126 | 24,020 | 918 | 447 |
| Japan TC age2 | 2,915 | 34,628 | 803 | 4 |
| China village age2_01 | 3,338 | 10,272 | 652 | 798* |
| Japan shrine age2_01 | 968 | 10,130 | 290 | 50 |

Boundary counts use positional weld rounding 1e-5, ignore UV/normal seams, exclude
zero-area triangles. They are not counts of holes. The study also reports exact
and 1e-4 welds. Intact TC counts were unchanged across these tolerances. Damage
meshes contain nonmanifold intersections as well as closed components: never
describe every vanilla debris component as watertight.

*Village damage has 226 triangles with differing vertex bone indices, excluded
from rigid-piece topology measurements. The resulting open edges include those
exclusions; do not interpret 798 as a directly comparable whole-mesh hole count.

Solid, backface-culled views from below show deliberately absent intact floor
undersides and thin exterior shells. The damaged versions add backing/thickness
and extensive interior geometry. The destruction materials `matz` (and Japan's
`maty`) reference shared destruction sheets. A separate damaged render model is
therefore the relevant precedent, not globally closing the intact source export.
These previews intentionally do not simulate texture alpha or actual damage motion.

## Density is not a blanket backside discount

For an illustrative all-azimuth 30–60 degree camera envelope, classify triangles
using the geometric-normal formula in the architecture skill. Area-weighted
median densities below use actual BaseColor dimensions and raw coordinate units,
main building `mata` only, excluding zero-area geometry. Orientation-eligible
does not mean proven unoccluded.

| Intact main map | Camera-back density | Orientation-eligible density | Ratio |
| --- | ---: | ---: | ---: |
| China TC age2, 2048 | 98.6 | 119.1 | 0.83 |
| Japan TC age2, 2048 | 136.8 | 136.9 | 1.00 |
| Village age2_01, 1024 | 139.8 | 143.7 | 0.97 |
| Shrine age2_01, 1024 | 88.4 | 137.1 | 0.64 |

This sample does NOT justify assigning every underside 1/4 or 1/8 density.
Retained backs often share coherent existing texture regions. Omission and atlas
reuse are stronger observed mechanisms; reduced resolution remains an explicit
case-by-case optimization. Shared accessory and destruction sheets have different
density ranges and are not mixed into this facade comparison.

## Korean v19 audit, no source geometry changed

39 meshes, 6,424 vertices, 10,820 triangles; the window-panel revision. Live Blender
5.1.2 was accessed through the MCP stdio bridge. The audit found 508 exact-weld
components and 444 verified closed convex render components, characteristic of
the construction-solid approach that needs optimization.

| Classification | Triangles | Meaning |
| --- | ---: | --- |
| Strictly buried inside retained opaque components | 412 | Intact-only certificate; 66 certifying shells frozen |
| Camera-back across the example envelope | 1,654 | 18.63% of total area; retain pending shadow/state decision |
| No hit in sampled views | 3,109 | Review candidates only; narrow visible strips were observed |
| Roof/alpha protected | 1,768 | No automatic removal or density change |
| Visible in samples or otherwise unresolved | 3,877 | Retain |

The 412 certified triangles cover 0.97% of total surface area. Whole-polygon
filtering gives **230 complete polygons / 388 triangles**; 12 additional polygons
are only partially certified (24 certified triangles) and cannot be deleted whole.
The current intact clay materials are assumed opaque where used as occluders;
alpha-bearing roof regions were excluded. Clearance is 1e-4 raw units versus
1e-8 shell validation tolerance. This scope is not a damage-state certificate.

A temporary in-memory removal of the 412 triangles produced zero changed hits
in 12,288 camera rays and 8,192 shadow rays, and zero changed AO occlusions in
8,192 rays (AO radius2 raw units). Alpha roof geometry was excluded on both sides.
These finite checks exercise the implementation; the supporting-plane containment
test supplies the conditional geometric argument. No edited GR2, HKT or game
test was performed. The accepted Blender asset remained unchanged.

The obvious base bottoms lie at z=0. That alone does not prove terrain coverage
on all placements. Preserve them or flag for a terrain-contract check; do not
silently count them as certified removal. Likewise, the current v19 damage-piece
partition is pending, so none of its intact certificates transfers automatically
to the previous, successful closed-blockout destruction prototype.

## Reproduction artifacts (external, never shipped)

Session folder: `Documents/Blender/Korean_Civilization_Research/Visibility_04`.
Contains original source hashes, per-triangle arrays, bound-mesh extraction script,
material/density reports, exact/welded topology, Korean face-to-occluder records,
visibility/ray-regression scripts and eight inspected geometric renders. Vanilla
inputs remain in the external session extraction folder. No vanilla files or
generated previews were added to the repository.

Reusable procedure and formulas:
[Surface visibility and removal](../../blender-architecture/references/surface-visibility.md).
Existing atlas interpretation:
[Asian UV atlas evidence](asian-uv-atlas-evidence.md).
