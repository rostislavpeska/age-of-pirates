# Regions and density
## Semantic regions
Use named regions for walls, floors, domes, gold, roof panels, ridges/valleys, columns, feet, capitals, surrounds, doors and relief. Source materials can be numerous. Consolidate into runtime atlases after approval, retaining a per-face region manifest.

## Proposed starting profile
DPI metadata does not describe 3D sharpness. Measure pixels per verified world unit,
then calibrate visible-surface density against shipped assets, the actual camera and
the material memory budget. Do not assume a universal 512 px/m minimum or convert
raw imported coordinates to metres without checking scale. Name detail exceptions
and hidden-surface classes explicitly. Do not silently lower density to squeeze
packing; first fix chart composition and intentional reuse.
Bottom-facing does not automatically mean invisible: visible soffits/reveals need visible-surface density. A 2x linear density costs about 4x pixel area; 0.5x costs one quarter. Use labeled square checkers and test both directions; area-average density hides one-axis stretching.
Use the geometry audit's per-face exposure manifest, including its camera/state
contract and proof status. A face missed by point samples gets no automatic density
discount. Retained camera-invisible opaque backs can share a small backing region;
destruction-exposed interiors need their own allocation. Do not multiply unique
charts for each hidden box cap, or infer UV-sharing compatibility from orientation
alone. Preserve shared AO constraints and alpha silhouette resolution.
For a square map, density = resolution * sqrt(UV triangle area / surface area in square meters). Include object/root transforms and scene unit scale. Record intended density, material, region polygon/bounds, orientation, exposure class, padding and shared-AO policy. Export consolidation must retain these semantics.

For two-axis distortion, use the Jacobian singular values in
[chart joining](chart-joining.md); equal area does not establish equal sharpness in
both directions. Chart coherence, density, allowed overlap and AO feasibility are
separate gates. A late unique repack is not a substitute for facade/trim design.

Retain architectural meaning in the layout: facade panels preserve opening cutouts; distinct domes use separate fan-shaped islands; roof sheets use coherent rectangular regions; ridges, rails and fences use long strips; and metallic finials use protected regions. Preserve the separation of purpose rather than copying coordinates from another asset.
