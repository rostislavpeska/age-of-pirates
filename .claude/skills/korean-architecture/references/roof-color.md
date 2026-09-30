# Roof color bound to real tile structure

The owner likes the roof bake and normal relief, but rejected a perfectly clean,
uniform roof. The requested finish takes cues from vanilla: neighboring tiles
have slightly different tones, restrained moss in sheltered areas, and limited
worn clay at exposed lips. Keep the existing tile courses and silhouette.

## Inputs and controls

Use the frozen roof UV plan, baked coverage, **geometry-derived tile IDs**, course
position and roll/pan mask. Measure every slope separately. A curved or tapered
slope cannot inherit another slope's spacing/frame just because both are roofs.
The Town Center has four source banks R0–R3; these labels are not a universal
four-roof assumption for other Korean buildings.

Separate controls: deterministic tile-tone seed/range, warm/cool bias, moss
strength, exposed-clay strength and material palette. Keep layout/normal/AO
structure fixed for a color-only finish. If relief is changed, route it through
the high/low baking workflow and regenerate the matching IDs.

## Demonstrated color-only recipe

`window_wanja/r2_roof_finish.py` consumes `roof_v2` baked fields:
R = per-tile variation, G = position within a course, B = roll mask. Its inputs
include existing projected grime as a breakup source, not a second structural
tile pattern. The recipe:

- Applies restrained shade variation (exemplar multiplier 0.85–1.15) and small
  warm/cool bias per existing tile.
- Places broken moss preferentially in sheltered pan/lap regions. Avoid green
  outlines on every tile or equal weathering over exposed ridges.
- Adds pale warm worn clay to a minority of exposed existing lips. It does not
  invent another set of cracks or seams over the baked normals.
- Expands only into unowned gutters, protecting other sampled material regions.

In the r2 exemplar, all **537 ROOF_TILE faces** were compared to the baked ID plan
before reuse. Page and UV coordinates matched. Only P2048/P1024 BaseColor changed;
normal, Masks, Opacity and Details were byte-identical. Protected nonroof pixels
changed: **zero**. This establishes a scoped color pass, not whole-model approval.

Review close and medium views with fixed lighting, all slopes, eave corners and
their undersides. Compare normal-disabled/unlit color when apparent tile damage
could be an atlas/material assignment error. A pleasing render of a background
copy does not prove the live or exported model uses that material mapping.

## Methods that failed here

An analytic grid projected independently into each face/segment disagreed with
the baked geometry: doubled tile rhythm, jumps at joints and pinstripes on round
ridge tubes. Long ridge decoration now follows modeled arc-length-continuous HIGH
geometry; coloring uses its baked IDs. Do not resurrect a second formula grid to
make the color more detailed. Corners require measured coverage/cage inspection,
not random stain painting to hide projection errors.

Implementation: `research/Texturing_11/Claude_CP2/roof_v2.py`, `roof_tile_ids.py`,
`ridge_eave_v2.py` and `window_wanja/r2_roof_finish.py` in the Korean repo. The
registry and exemplar handoffs locate exact source fields and reports.
