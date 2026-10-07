# Material direction after UV freeze

A clean UV checker does not prove that photographed boards, grain or masonry
courses face the right way. The source image, material projection and every UV
reader are three separate coordinate systems. Check their composition.

## Declare the material frame

Record the source image/hash, the direction of its grain or courses in **image
U/V**, physical repeat size, and the architectural direction it should follow.
Inspect the actual image; do not infer its axes from its filename. Use the same
transform for color, roughness, masks and detail normals. After rotating or
mirroring a source normal, re-express its vectors in the destination UV tangent
frame; rotating the bitmap alone is insufficient.

Choose direction by construction role:

- Boarded panels and gables use one deliberate frame across the entire panel.
  A triangle's longest edge often points along its slope, not its boards.
- Beams/posts follow the member length. A short segment of a curved beam can
  be wider than it is long; its longest polygon edge is not a reliable axis.
- Curved ridges use a continuous coordinate along the actual cross-section
  chain. Keep phase across segment boundaries; do not restart a world-dot
  projection in a different tangent frame on every segment.
- Masonry side courses follow the horizontal run, with vertical joints rising
  upward. Tops and narrow end sections need their own reviewed interpretation.
- Single timbers use an interior crop of one photographed plank; do not place
  the source photograph's board joints across one solid timber.

## Check owners and readers

For each directional surface, carry the applied source-U direction into atlas
UVs, then through the **reader's** UV-to-surface Jacobian. Compare that vector
with the reader's role direction. Reflected/rotated sharing can pass density and
overlap checks while producing a sideways pattern. Report failures by face and
role; do not average them into a passing model median. List subpixel/unassessed
surfaces separately. A normal sign error is a separate check from grain angle.

`scripts/check_material_direction.py` validates supplied geometric observations
(dependency: Python standard library). Its input vectors must come from the
applied mapping, not be copied from the desired direction. It checks mapping
evidence, **not visual realism or the correctness of the role labels**.

Inspect the actual final material in fixed front/back and side close-ups: gables
on both ends, all wooden ridge runs and tips, platform corners, and opposite
mirrored readers. Check normal-only alongside color for direction changes.
Recheck after Painter export and live image binding. Publish the same revision
that was inspected; a staged scene that was never activated is not a handoff.

Check **source scale on both axes**, separately from atlas density. Cropping a
photo to one plank and stretching that crop over a beam can turn correctly
oriented grain into crosswise-looking streaks. Preserve physical source pixel
pitch when cropping/wrapping; record deliberate anisotropy and inspect a close-up.
Direction-vector tests alone cannot detect this appearance failure (r47 ridge
close-up caught it before publication).

Repair projection before considering UV changes. If two readers require
incompatible directions on the same texels, identify that conflict explicitly;
a global texture rotation cannot repair both. Keep the prior version and list
any affected bake/atlas work before a scoped sharing change.

## Evidence

Korean military r46/r47, 2026-10-07, INC-106: granite source U was projected onto
world Z, producing vertical courses. Longest-edge frames turned the grain across
short wooden ridge segments. The Town Center already had a connected-panel
world-up frame for decorative boards (`source_maps.py:decor_frames`); that role
rule was missed when its material recipe was reused on military meshes.
Numeric color, coverage and normal-length checks did not test these directions.
The r47 audit records geometric observations and separate visual review; neither
claims production acceptance or verifies an unobserved live revision.
