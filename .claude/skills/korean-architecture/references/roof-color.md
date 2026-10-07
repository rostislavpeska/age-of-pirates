# Roof color bound to real tile structure

The owner likes the roof bake and normal relief, but rejected a perfectly clean,
uniform roof. The requested finish takes cues from vanilla: neighboring tiles
have slightly different tones, restrained moss in sheltered areas, and limited
worn clay at exposed lips. Keep the existing tile courses and silhouette.

**Set tint lock (owner, 2026-10-07):** Korean buildings of this set must use the
accepted TC roof's same tints. Consume its finished material revision and inherited
palette controls through the generic [building-set procedure](../../blender-architecture-texturing/references/building-set-consistency.md).
The variation recipe below cannot substitute for comparing the actual TC output.
Match roof fields, caps and alpha eave ends as separate roles; wooden main ridges
inherit the TC timber role. Keep relief, rounded silhouettes and alpha protected
in a tint repair. New per-building normalization or a similar raw clay source does
not establish a match. Japanese/Chinese references inform set readability; the
accepted Korean TC remains the palette authority for this set.

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

## Set-match correction: inherit the whole shading recipe

Military r50 retained the TC clay colors and local tile relief but omitted the
TC's assembly-contact color stage. Like-for-like exposed roll samples were
already within about one encoded RGB level; channels/contact were lighter.
Do not globally darken the atlas to force its whole-roof mean to match.

The accepted TC compositor applies assembly contact in linear color using
`0.45 + 0.55 * assembly_AO ** 0.8`, in addition to the separate tile-local relief.
In a new member, measure assembly contact from its own unchanged geometry; do not
copy the TC's spatial shadow map. On shared texels evaluate all readers, keeping
the least-dark value where the approved policy suppresses conflicting contact.
Apply this stage once and keep its source separate from already-baked tile AO.

Military r51 is a review candidate demonstrating this correction: 512 contact
sampling, 48 rays, one-unit radius, unchanged 2048 outputs and no new islands.
Those values are evidence, not universal defaults. Exclude inventoried alpha
fronts from opaque AO blockers; a nonexistent semantic field silently excludes
nothing. The authoritative per-face inventory identifies these fronts.

Protect every nonroof occupied pixel, normal, alpha, player mask and roughness.
An unchanged roughness resource stays byte-identical rather than being rewritten
in another PNG channel format. Painter public-resource replacement/export was
verified with exact roof-core pixels; source borders and padding remain authoritative.
See military `uv_r51` and its external `ROOF_CONTACT_QA`, `COMPOSITE_QA`, Painter
roundtrip and fixed-view review receipts. Owner and engine acceptance are separate.

## Tile lap direction: military r60 / INC-135

The tile-lap repair is separate from ridge overlap and eave projection. The TC
source's course coordinate grows downhill. Military fields measured arc length
`s` from eave to ridge, but reused the same signed phase: lips dropped uphill on
all 16 owner regions. The source correction is `phase = (-s / course_pitch) % 1`, retaining
tile IDs and course boundaries. Rebuild HIGH normals/local AO/TileData together,
then reapply the established TC colour recipe using the corrected phase. Preserve
ridge wood, rounded ends, alpha, LOW geometry and UVs.

The owner still reported reversed-looking shadows after this correction. It is
not an accepted appearance fix. Use [roof tile direction QA](../../roof-tile-direction-qa/SKILL.md)
to isolate the remaining boundary before changing channels or rebaking. Independent
sampled author normals and one actual HIGH cross-section preserve the intended
direction; these bounded results do not settle color/AO cues or the engine shader.
Audit every shared reader's downhill frame. A mirrored chart alone proves no
direction, and the initial coordinate audit did not validate final tangent frames.
Keep roof-end alpha and accepted timber ridge geometry outside this correction.
