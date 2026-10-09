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

## Reject collapsed source projections

Test the mapping actually supplied to the image sampler, before modulo/repeat,
separately from destination UV area and density. `scripts/surface_projection.py`
measures the two singular axes in source pixels per model unit. A zero or nearly
zero axis is a failure for a two-dimensional material, even if the other axis and
the atlas island are large. Do not validate a proposed frame while the compositor
still samples the old one. Nonfinite evidence fails; degenerate geometry remains
unassessed and requires a separate geometry/tessellation check.

For shared texels, compose the owner's applied source mapping with each reader's
UV-to-surface mapping. Account for every reader; unmeasured faces are not passes.
Use the mesh's real tessellation, not a triangle fan across a concave n-gon. Tiny
near-collinear triangles can make numerical derivatives unstable: report them
separately. A whole-planar-face fit may establish the material frame when its
residual is below a stated pixel tolerance, but it does not certify those export
triangles or erase their geometry/UV diagnostic.

Choose a face-tangent frame when an object's length axis is perpendicular to an
end cap. Identify caps by the member's own run direction; rotated assets and
their shared owners need not use the same world axis. Use end-grain on exposed
timber sections, longitudinal grain along curved trim's continuous arc length,
horizontal stone courses on vertical sides, and unjointed stone on stair treads.
Do not use a global wood rotation or a fixed world-normal label as the repair.

Repair only the affected owner texels and their declared gutter. Verify exact
protected-pixel and alpha preservation, and inspect all affected shared readers
with final material plus normal-disabled controls. Do not repack valid UVs or
rebake unrelated AO merely to fix the source coordinate generator.

## Evidence

Korean Houses r13, 2026-10-09: all six opposite foundation sides had valid
23,617-pixel atlas islands, but object-long-axis Y was constant on their faces.
The compositor stretched one source image column across each side. Stair faces
and timber caps exposed the same class of defect. UV density and material colour
statistics had passed. A later background trim trial also mistook a rotated
ridge's side for its cap; per-member frames and owner/reader checks caught it
before live publication. `scripts/test_surface_projection.py` retains the
nonzero-atlas/zero-source regression and rotated/opposite-face controls.

Korean military r46/r47, 2026-10-07, INC-106: granite source U was projected onto
world Z, producing vertical courses. Longest-edge frames turned the grain across
short wooden ridge segments. The Town Center already had a connected-panel
world-up frame for decorative boards (`source_maps.py:decor_frames`); that role
rule was missed when its material recipe was reused on military meshes.
Numeric color, coverage and normal-length checks did not test these directions.
The r47 audit records geometric observations and separate visual review; neither
claims production acceptance or verifies an unobserved live revision.
