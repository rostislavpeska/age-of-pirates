---
name: roof-tile-direction-qa
description: Diagnose and verify overlapping roof-tile direction across source geometry, baked normals, UV sharing, AO/color and exported maps. Use when tile laps or shadows appear reversed, or when validating a tiled roof bake before repetition or export.
---

# Roof tile direction QA

Determine which stage makes the tiles read incorrectly before changing a map or
rebaking. This skill measures direction and separates visual cues; it does not
authorize geometry edits, application restarts, screen control or deployment.
Use the project's existing authoring/export tools for those operations.

## Establish the observed artifact

Record whether the complaint concerns Blender, a saved render or the running
game. Pin mesh, UV, material and map identities, including the actual installed
files and reload/cache state where relevant. Do not assume a running game uses
the latest file just because its disk hash changed. Preserve the current model.

Read [the measurement protocol](references/measurement-protocol.md), then follow
the chain without skipping ahead:

1. Declare world-space ridge-to-eave direction for each roof field. Include shared
   and mirrored readers. Check actual HIGH cross-sections after subtracting the
   smooth backing: the exposed lap drops sharply downhill. A formula-only check
   cannot certify generated geometry.
2. Validate the diagnostic tangent frame before reading normal direction. Vectors
   must be finite, normalized, orthogonal and coherent with the triangle's UV
   derivatives and handedness. Wrong frames can invent a reversed bake.
3. Compare measured HIGH normals with raw bake and final map samples on the same
   surface points. Resolve each sampled texel to its actual bake owner; zeros
   outside an owner's coverage are missing evidence, not a flat normal.
4. Isolate grey normal-only shading under opposite lights, AO-only, unlit
   BaseColor and full material. Good relief with misleading painted shadows is a
   color/AO problem. Do not invert correct normals to compensate for it.
5. Repeat on decoded exported maps and relevant mips, using the serialized mesh's
   UVs and tangent data. Check the actual engine convention and relevant intact/
   damaged states. Neither an author preview nor a load/CRC test proves this step.

Use a known-correct section and deliberately reversed controls to calibrate the
test before judging the candidate. Inspect field-level results; an average cannot
hide a reversed section. Mark missing/ambiguous evidence **INCONCLUSIVE**, not PASS.
Once the failing boundary is isolated, change only that boundary and retest the
affected fields plus their shared readers. Do not launch another full bake merely
because the previous check is inconclusive.

## Executable prerequisites

These are deliberately bounded helpers, **not an automatic full-roof certificate**:

- `scripts/roof_lap_gate.py`: `assess(distances, relief, downhill)` checks a sampled
  displacement profile. Supply actual measured HIGH sections for asset evidence;
  its synthetic unit tests only test the checker. Default steep-drop dominance 3
  is a starting threshold, not an empirically universal roof-quality floor.
- `scripts/normal_frame_gate.py`: checks supplied per-triangle/per-corner frames
  against geometry and UV derivatives. Requires host NumPy. NPZ arrays: P/N/T/B
  shaped `(triangles,3,3)`, UV shaped `(triangles,3,2)`, all in one world frame.
  Exit 0 means frame coherence only; exit 1 is a failed frame, not proof of a bad
  roof. It does not extract Blender frames or implement an engine shader.

```sh
python scripts/normal_frame_gate.py <scratch>/frames.npz --out <scratch>/frame-report.json
python -m unittest discover -s scripts -p "test_*.py"
```

Run these relative to this skill folder. No application, network or asset mutation
is performed by the helpers. Choose a Python environment with NumPy; do not install
or launch software just to turn a missing capability into a green check.

## Observable handoff

Deliver a per-field table containing source/reader and map hashes, physical
direction, tested sample coverage, signed lip change, normal angular error, mip,
and PASS/FAIL/INCONCLUSIVE at each boundary. Include the channel-isolation views,
the known-reversed negative control, and explicit missing views/states.

Separate **machine evidence**, **pictures delivered**, **owner acceptance** and
**engine verification**. Approval of this method does not accept an unresolved
roof. A false diagnostic is itself recorded, invalidated and tested; do not leave
its earlier PASS/FAIL labels looking authoritative.
