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

## World-space bake intent (no HIGH model)

`scripts/bake_intent_check.py` reads the final normal map through the low mesh's own UVs and tangent frames and judges
each face against its own downhill direction. Use it when there is no HIGH to compare against, e.g. an analytic or
transferred tile page, or as the first screen before the full chain above. The four measures:

| measure | what it catches | does not depend on |
| --- | --- | --- |
| lap asymmetry | reversed laps (green flipped) | UV orientation (frame resolved) |
| roll axis ratio | rolls turned 90 deg (R/G swapped) | UV orientation |
| lap axis p50 | sagging / skewed courses | UV convention (content-derived) |
| texel anisotropy | a stretched or squeezed course coordinate | the map |

Calibration (2026-10-11), all on decoded final maps:

| roof | lap | roll | lap axis p50 | anisotropy p05 / p95 | verdict |
| --- | --- | --- | --- | --- | --- |
| Korean TC, own HIGH bake (tile-texel mask) | 5.46 | 2.16 | 16.1 deg | .91 / 1.10 | PASS |
| TC, flipG control | .55 | 2.24 | - | - | inverts |
| TC, swapRG control | 1.01 | .45 | - | - | inverts |
| rice paddy r4, analytic page on a pyramid; course coordinate measured along leaning grid columns | 3.43 | 1.87 | 23.8 deg | .45 / 1.00 | FAIL |
| rice paddy r6, course coordinate = arc length up the fall line | 13798* | 2.37 | 12.0 deg | 1.00 / 1.00 | PASS |

*The pan of an analytic page has almost no steep texels that face uphill, so the ratio is large; only "well above 1"
matters.

The r4 failure is the one the owner saw in game ("the bake incorrect"). Lap and roll still passed there, so on their
own they would have missed it. The lap axis and anisotropy measures catch it. Starting thresholds
(`bake_intent_core.THRESHOLDS`):
- lap asymmetry >= 2;
- roll ratio >= 1.5;
- lap axis p50 <= 20 deg;
- anisotropy p05 >= .8 and p95 <= 1.25;
- at least 2000 texels.

Recalibrate on the set's own known-correct roof before tightening them.

Deliberately odd faces (a corner sweep, a flared eave) are declared with a FACE attribute, `intent_free` = 1, by the
builder, not afterwards by the checker. They are measured apart (`declared`) and never gate. On the r6 pyramid, 272
sweep faces show lap axis p50 21 deg there and are reported, not failed. Declaring a face is a design statement:
record why in the builder.
