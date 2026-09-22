# Regions and density
## Semantic regions
Use named regions for walls, floors, domes, gold, roof panels, ridges/valleys, columns, feet, capitals, surrounds, doors and relief. Source materials can be numerous. Consolidate into runtime atlases after approval, retaining a per-face region manifest.

## Proposed starting profile
DPI metadata does not describe 3D sharpness. Measure pixels per meter after checking real model scale. Proposed minimum 1x = **512 px/m** for visible walls/roofs; ornament/details 2x = **1024 px/m**; genuinely hidden/underside faces 0.5x = **256 px/m**. These are production defaults, not measured engine limits. Calibrate at the intended camera distance/resolution and memory budget. Do not silently lower density to squeeze packing.
Bottom-facing does not automatically mean invisible: visible soffits/reveals need visible-surface density. A 2x linear density costs about 4x pixel area; 0.5x costs one quarter. Use labeled square checkers and test both directions; area-average density hides one-axis stretching.
For a square map, density = resolution * sqrt(UV triangle area / surface area in square meters). Include object/root transforms and scene unit scale. Record intended density, material, region polygon/bounds, orientation, exposure class, padding and shared-AO policy. Export consolidation must retain these semantics.

Retain architectural meaning in the layout: facade panels preserve opening cutouts; distinct domes use separate fan-shaped islands; roof sheets use coherent rectangular regions; ridges, rails and fences use long strips; and metallic finials use protected regions. Preserve the separation of purpose rather than copying coordinates from another asset.
