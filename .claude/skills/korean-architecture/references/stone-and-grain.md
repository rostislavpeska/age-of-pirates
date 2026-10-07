# Korean foundations and timber direction

Reuse the accepted Town Center's **source photograph and appearance recipe**,
not its historical atlas coordinates or a generic longest-edge projection.
See the project's `KR-MAT-DIRECTION-01` / `patterns/korean/material_orientation.md`.

## Stone foundation

The accepted TC uses the granite-wall source tinted around `9E998E`, with
moderate block variation, irregular photo-driven moss and soil from ground
level, recess dirt, and cleaner/chipped upper edges. Its source implementation is
`research/Texturing_11/Claude_CP2/compose_textures.py`, `STONE` branch.

Preserve horizontal masonry courses on vertical foundation sides. TC's original
source mapping pairs horizontal U with vertical V. The military r47 error put
world-up on U, turning the courses 90 degrees. A small stone plinth is not a brick
wall: inspect scale against the TC in the same scene and camera, and keep stone
blocks large enough to read. Ground-relative weathering uses actual world height;
do not cover elevated post bases with a ground moss band. Break the moss line
with source detail and keep it localized, rather than tinting the entire base green.

Do not claim assembly AO when using only the existing local AO or geometry-height
masks. Source photos, generated surface masks, bake normals and final export maps
have separate provenance and checks.

## Gables, main ridges and other timber

- Gable infill boards run vertically, including both mirrored ends. The TC's
  `source_maps.py:decor_frames` establishes one world-up panel frame.
- Main ridges remain wooden and grain follows their curved length. Recover the
  cross-section chain for a continuous material coordinate; short segment width
  must not select a transverse grain axis. Crop inside one source plank to avoid
  painting plank joints across a solid timber.
- Clay hip/verge caps keep their geometry-aligned tile bake. Do not rotate these
  because the separate wooden main ridge needs a grain correction.
- Posts, rails, panel boards and narrow returns are different roles. Check both
  their intended construction direction and the source's actual grain axis.

Generic projection, normal-vector transforms and shared-reader direction checks
belong to [material orientation](../../blender-architecture-texturing/references/material-orientation.md).
Inspect stone corners, gables and every wooden ridge before publishing, with the
accepted TC alongside the new model. An appended but inactive revision is not
visible delivery.

Evidence: owner correction 2026-10-07; INC-106 (orientation) and INC-107 (lost live
append reply). The military r47 repair is a review candidate, not game acceptance.
