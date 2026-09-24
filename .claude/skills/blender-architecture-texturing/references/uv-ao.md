# UV repair and AO
Zombie atlas defects are residual/misassigned islands, corners or faces sampling obsolete/neighboring patches. Being inside 0..1 is insufficient. Validate intended material, region, orientation and triangulated interior, including slanted patches and short returns. A column motif on a floor is wrong even with valid coordinates.
Snapshot before edits. Match ledge sides to the approved FRONT motif and scale. Fix insufficient density with proper UV area, not sharpening. Use a narrow padded inset for demonstrated neighboring-patch bleed; do not blindly shrink/repack all islands. Check every map using the changed UVs.
For curved ledges include the short returns: geometric bounds alone can miss those faces. Compare the repaired ends/corners and a neighboring untouched surface in the existing shader environment. Inspect the renders before claiming visual verification. Keep runtime visibility diagnosis separate from cosmetic UV repairs and preserve the operator's manual export workflow.
`scripts/validate_uv.py` checks rectangular assignments and exact unchanged geometry/unrelated UVs/materials using its JSON schema. It does not prove nonrectangular containment, appropriate motif, density, shading or full coverage. Report unassigned coverage. Geometry changes require separate validation and a fresh baseline.

## AO planning
Standardize projections and contacts. Choose bake distance at the recorded physical scale. Remove duplicates/backing overlaps before baking; explicitly select intended occluders and exclude reference meshes. Do not globally increase AO to disguise inconsistent depths.
Inspect AO-only views for black wedges, corner halos, boundary stripes and exposure differences between repeated modules. Compare with neutral AO under fixed lights to distinguish baked shading from shadows/diffuse dirt. Use small masked test bakes to identify bad occluders/cage distances.
Prefer correcting bake inputs and rebaking affected regions. Otherwise lighten/remove AO through a feathered mask or use a small masked blur on a copy. Preserve good AO elsewhere. Blur inside the intended region only and rebuild padding; global atlas blur spreads neighboring motifs. If AO is multiplied into basecolor already, another AO multiplication double-darkens it; preserve or reconstruct clean basecolor rather than indiscriminate gamma changes.
[Blender baking reference](https://docs.blender.org/manual/en/4.2/render/cycles/baking.html): verify passes, targets and margins against the installed version. An initial 8–16 px gutter at 2048 is a test convention, not a guarantee down to the smallest shared mip. Inspect downsampled maps at intended viewing distances.

## Shared atlas UVs
Shared material UVs cannot hold different location-specific AO values at the same pixel. Never bake unrelated overlaps sequentially into one image and accept whichever was written last.
Choose explicitly: identical repeated modules with identical AO context; unique AO variants/islands for different contacts; an extra unique AO UV/map only if the destination supports it; or shared micro-occlusion without location-specific AO. For constrained destinations, prefer supported atlas variants instead of adding an unsupported UV layer. Use a non-overlapping temporary bake layout and transfer validated variants/maps with padding. Record every shared region's AO policy.

## Postproduction

Unexpected dark/light regions are not automatically texture defects. Compare
per-corner mesh normals with the unmodified original model before changing color
or AO, especially after roofs, stairs or adjacent faces were removed. Inspect
unlit basecolor, normal-map-disabled shading and the full material under the same
lights. If unlit color is intact but lighting changes, investigate geometry
normals, tangents and material interpretation first. Preserve texture pixels when
the demonstrated fault is in exported vertex data.

Unify walls with walls and roof metals with roof metals under fixed lighting; do not force different materials to identical tones. Inspect roughness, metallic and AO before repeatedly darkening diffuse. Basecolor is sRGB; normals/masks are data. Use semantic masks for stone warmth/darkness and decorative contrast, preserving roofs, glass, gold and other maps unless requested. Normal strength/vector changes are separate from diffuse edits. Capture unsaved Photoshop sources safely before using them.
Save layered sources and versioned outputs. Verify unchanged pixels outside masks, channels, dimensions, mip behavior and packed/external image paths. Texture-only edits normally do not require model reconversion; geometry, UV, rig and material bindings do.

## Validator input
Before/after JSON: `objects` maps each object name to `vertices` (coordinate arrays) and `faces` (ordered records with `vertices` indices, `material` index, and ordered `uv` pairs). Manifest: `objects` maps each name to `faces`, mapping string face indices to region names. `regions` maps region names to `material`, `bounds` = [u_min,v_min,u_max,v_max], optional `padding_px` and `size` = [width,height]. Only assigned faces may change UV/material; all geometry and unassigned faces must remain identical. Invoke `python scripts/validate_uv.py before.json after.json manifest.json`. Rectangles contain all interpolated triangle interiors when their corners are inside, but nonrectangular atlas shapes require polygon-aware containment.
