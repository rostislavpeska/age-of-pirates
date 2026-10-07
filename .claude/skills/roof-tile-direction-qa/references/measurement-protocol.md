# Roof lap direction: measurement protocol

A correct analytic tile-profile formula is not proof that the final roof reads
correctly. Source relief, bake projection, shared readers, tangent frames, image
channels, AO and baked color can disagree. Keep the result
unaccepted until the stages below agree; ordinary file/native lint does not cover
this appearance requirement.

## Required evidence per roof field

1. **Physical frame.** Identify actual ridge and eave points in world coordinates.
   A section's sampled direction must descend along its roof surface; labels such
   as U, V, front, mirrored or uphill are not sufficient. Include every reader,
   including repeated/mirrored fields, not just the bake owner. Near-flat/upturned
   eave regions require a declared drainage path rather than an ambiguous gravity
   projection. Preserve roof-end alpha and accepted ridge geometry.
2. **Actual HIGH cross-section.** Intersect the generated HIGH mesh along that
   path, subtract the smooth backing and measure the exposed lap. It must fall
   sharply towards the eave. An analytic helper can catch a sign typo, but cannot
   replace measuring the generated source. Include a deliberately reversed
   profile as a negative control. Report unresolved or subpixel laps separately.
3. **Baked and final normals.** Sample the actual maps at the current reader UVs
   and reconstruct world normals with that reader's tangent frame. Validate finite
   unit vectors, orthogonality, handedness, coordinate transform and corner-normal
   identity first. A diagnostic using a mismatched frame cannot return PASS.
   Gram-Schmidt interpolation must follow the renderer's basis convention; do not
   invent orthogonality by silently modifying unknown input data. Compare with
   measured HIGH normals at corresponding hit points and physical lap sides.
4. **Serialized runtime.** Decode the actual installed DDT and all relevant mips;
   use the actual GR2 UVs, normals, tangents and handedness. Pin material bindings
   and hashes. Account for image row order and V/channel conversion exactly once.
   Do not reconstruct with author UVs and call it a runtime test. Check both intact
   and damaged readers. An unverified engine bitangent/shader contract is an open
   limitation, never an assumed OpenGL/DirectX label.
5. **Separate visual channels.** From fixed cameras, show grey normal-only material
   under opposite light directions; AO-only with neutral material; unlit BaseColor;
   and the final material. The HIGH and baked LOW specimen need the same views.
   If normal-only relief is correct but the lap still looks inverted in unlit
   color/AO, repair those registered shadow cues; do not invert good normals.
   Confirm the relevant game-zoom mip and compare the set's accepted reference.

## What to record

For each field: source/reader identity, ridge/eave direction, triangle and sample
coverage, signed lip change, reference-to-final normal angular errors, UV/normal
convention, used mip, image and mesh hashes, failed/ambiguous samples, and links to
the channel-isolation images. Thresholds must be calibrated on a known-correct
specimen and known-reversed controls, then fixed before evaluating candidates.
Distinguish physically verified roof fields from supplied chart or owner labels;
metadata alone cannot establish a drainage direction or physical coverage.
When earlier evidence is missing, a bounded prerequisite check is still useful,
but its result cannot establish roof acceptance.

The local slope relation for a unit normal `n`, smooth backing normal `N`, and
unit downhill tangent `d` is approximately `dh/ds = -dot(n,d)/dot(n,N)` when the
detail is a height field in that local frame. Use it only after frame validation;
large curvature, grazing normals, projection offsets and rolled tile sides require
explicit sample exclusions or a better geometric comparison. A course-phase
median alone is not a reliable gate: filtering/interpolation can mix phase wraps.

`scripts/normal_frame_gate.py` is the diagnostic prerequisite. Its tests cover
non-orthogonal frames, an orthogonal frame pointing against +U, wrong handedness,
correct mirrored UVs and degenerate input. Do not report its output as a roof
acceptance result.

**Acceptance is conjunctive:** source geometry, final normal reconstruction,
AO/color direction, current runtime identity and visible result must agree.
Global averages cannot excuse one reversed roof field. Inconclusive is not PASS.
