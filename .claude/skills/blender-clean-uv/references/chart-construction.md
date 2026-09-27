# Chart construction and editable delivery

## Joining, layout grouping and stacking

A chart maps a surface patch to UV coordinates. Unique visible shading requires
distinct surface interiors to occupy distinct texels; shared boundaries are valid.
AO may vary from dark to light inside one chart. That variation does not require
seams. Reusing the same texels for different required values is a separate problem
handled by the overlap skill.

Build adjacency from shared geometric edges. Imported seam duplicates may use a
scale-aware virtual edge match without welding or changing normals. Crossing
faces, point contacts and nearby boxes are not adjacency. Name the architectural
group before joining: gable, roof slope, facade bay, ridge strip or foundation.

For planar patches use one measured planar frame; for curved strips use a coherent
unfolding constrained by measured distortion. A hard normal generally needs a UV
split for tangent-normal baking. Do not smooth a construction fold to avoid a seam.
A closed tube needs a longitudinal seam; do not split every quad into a chart.
Different material IDs may share a chart if the baked semantic mask retains them.

Disconnected front patches can share a coordinated upright facade layout while
keeping posts, recesses and hardware in 3D. Label this **layout grouping**, not
topological stitching. Preserve whole gable outlines and real openings. Do not
replace a deep facade with a flat receiver just to simplify packing: compare the
high source, low receiver and baked result under opposing light and grazing views.
Shallow closed lattice may bake well; open rails, major posts, deep reveals and
silhouette projections need their geometry. A normal map cannot restore parallax.

## Quantitative checks

Evaluate the piecewise surface map on read-only analytical tessellation. Preserve
the editable quads/ngons. With world coordinates in a local orthonormal surface
basis and UV coordinates multiplied by image width/height:

    J = texel_edge_matrix * inverse(world_edge_matrix)
    density_axes = singular_values(J)
    anisotropy = max(density_axes) / min(density_axes)

Include object transforms and verified scene units. Report both axes, area-weighted
coverage outside limits and worst visible defects. Area-average density alone can
hide one compressed axis. Declare tolerances and detail/hidden exceptions before
packing; do not silently shrink charts to pass capacity.

Check exact positive-area intersections **inside each chart** and between charts.
Adjacent face interiors must occupy opposite sides of their common UV edge.
Equal edge endpoints do not establish this. A demonstrated reverse-eave defect
put opposing back/bevel faces onto the same strip area even though endpoints
matched. Split at those actual hard folds, keeping the remaining strip continuous.
Do not solve it by making separate islands for every polygon.

Audit finite coordinates, nonzero UV area, intended page/region containment, full
face coverage, gutters, source-image binding and unintended reflections. Holes
and openings must correspond to geometry. Preserve unrelated charts and map
channels when repairing a local fault. A page-bounds check is insufficient.

## Camera and hidden allocation

Record the camera envelope and intact/damaged state. For normal n and direction v
toward an orthographic camera, dot(n,v) <= 0 is back-facing under single-sided
rendering; front-facing samples still require occlusion checks. Finite ray samples
can miss edges, and an opaque BVH can incorrectly hide faces behind cutouts.
Uncertain faces retain their allocation until inspected.

Separate camera-invisible backs, visible soffits and fracture interiors. Retained
hidden backs can share neutral wood/stone/clay regions; one-eighth linear density
uses one-sixty-fourth of the content area before padding. Do not allocate a unique
tiny padded island for every hidden cap. Bottom-facing alone proves nothing.

A partial hidden-face repair may partition quads without removing visible detail.
Containment evidence requires actual opaque covering geometry, not just matching
bounding boxes. It applies only while that assembly remains intact. Keep the
closed authoring/bake/fracture source; deletion or low-density allocation must not
silently remove interiors exposed when destruction separates the pieces.

## Live editor check

1. Read the active file, scene, object, mode, UV layer and image through the live
   Blender connection. A repaired background file is staging until that revision
   is present in the user's intended session. Preserve unsaved authoring scenes.
2. In UV Editing, enter Edit Mode on an intended review mesh and select its faces.
   Verify editable loops appear over the corresponding actual bitmap. Keep the
   scene selectable: mesh/component visibility, overlays, selected outlines and
   normal editing controls must work. Do not reuse presentation settings that
   disable operator inspection.
3. Confirm the UV layer shown is the one feeding the material's image textures.
   Name and explain any extra supported map layer. Source-bank coordinates,
   Generated/Object coordinates or hidden mapping transforms are not proof of an
   authored atlas. Shared low-density hidden materials remain an explicit exception.
4. Verify switching review meshes can display their corresponding UV sheets;
   clear an inappropriate image pin and select the intended image texture node.
   Opacity must follow the delivered UV mapping too. Check bake target nodes before
   a rebake; a stale target can cause missing-image or circular-input problems.
5. Capture the actual editor using the authorized integration and inspect it.
   Readback should identify active mesh/layer/image, face counts, selection state,
   page sizes and validation failures. A rendered wire diagram alone is not this
   evidence. Save a separate recovery copy when the original has unsaved work.

The review may use derived atlas meshes, but retain component-based authoring and
bindings. Do not merge the only editable source merely to display all sheets.
Report diagnostic and runtime dimensions separately. Passing this editor check
does not certify economical packing, mip behavior, final textures or export.
