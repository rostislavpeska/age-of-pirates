# Texturing QA after the UV freeze: pictures, pass criteria, constraints

Owner rule (2026-09-28): during the whole texturing phase take pictures, inspect the model and pass
clear visual criteria at every iteration, so defects like untextured ridges are caught by the agent,
not by the owner. Every iteration = the two scripts below + a look at the sheet, BEFORE telling the owner.

## Every iteration

1. `blender -b --factory-startup --python-exit-code 1 --python scripts/qa_textures.py -- config.json` - numeric: per class and per UV island of the final maps. This helper imports `bpy` even for PNG inputs; host Python is insufficient. The separate `scripts/qa_detectors.py config.json` runs in host Python for ordinary raster inputs.
   Fails on: empty texels inside owner islands; a FLAT island (luma std below the class floor - a plain
   fill where a material should show structure); class mean colour off its target by more than the
   tolerance; normal vectors not unit; opacity holes on classes that must be solid.
2. `scripts/qa_shots.py config.json` - pictures: the same fixed cameras every time (Cycles, background,
   the review file) -> one contact sheet. Look at every tile of the sheet.
   For a partial rerender, resolve the requested shot IDs before loading/rendering
   and require the selected list to equal them. Missing filter keys or zero-match
   script substitutions must fail, never default to the complete shot list.
   Keep the completed manifest and verify retained frame hashes. Korean r49's
   revision-specific filter mismatch repeated three views before intervention;
   explicit selector/shot assertions prevented recurrence in the corrected run.
3. For an unexplained defect, in this order:
   a. **Texel level first:** crop the final maps where the defect is (same window of BaseColor, Normal and a
      normal shaded with one light), upscale nearest x4, and overlay the low-poly UV edges from the plan.
      Count the rhythms: every repeated line must belong to a named feature.
   b. **HIGH alone vs HIGH + shader:** render the high geometry in plain grey and again with its bake shader,
      same camera, grazing light. What the shader adds must sit ON the modelled features.
   c. The four-way fixed-camera diagnosis - Final / BaseColor only / Normal only / UV checker - tells colour,
      relief, binding and UV apart at viewing distance, but it did NOT find the roof's second rhythm in two
      rounds (2026-09-28); steps a and b did in minutes.

4. **Vanilla bar gate (numbers, not taste):** measure the final maps against vanilla buildings of the same kind
   (Korean TC: `Claude_CP2/benchmark` - `measure.py ours` with `OURS_DIR`/`MEASURE_OUT`, then `bench_gate.py`).
   Every class metric (detail energy, mid-scale variation, value range, speck fractions, foot darkening, hue life,
   grain coherence; roofs: finer tile period >= 23.6 texels, roll/course contrast, tile variation, regularity) must
   sit at or above the vanilla median. A deviation passes only as WAIVED, listed in `bench_exceptions.json` with
   the owner's words and date; agents never add waivers. Vanilla is the floor, not the ceiling.
5. **Parallel variants:** the compositor takes `COMPOSE_OUT` (isolated output) and `COMPOSE_HOOKS` (hook modules);
   `qa_shots.py` takes `image_remap` to render a variant's maps in the same review file. Variants never touch
   `final/`; the accepted hooks are listed in `compose_hooks.json`.
6. **Publishing (Korean TC: `Claude_CP2/PUBLISHING.md`):** `publish.py` is the only writer of `final/` and
   `compose_hooks.json`. An agent finishes an item with `publish.py candidate --key K --dir <its COMPOSE_OUT> --hooks
   ...` and never writes `final/`. Only the coordinator runs `publish.py promote --hooks <full accepted set> --note ..`
   after verification. promote freezes the hooks (`hooks_accepted/<stem>__<sha8>.py`), composes into staging, gates
   (qa_textures PASS, qa_detectors no new failure vs the current final, bench reported), then swaps with history and
   `final/PUBLISHED.json`. The owner's Blender reloads the changed maps by itself (`aop_review_live.py`, installed
   once through the MCP; that call never reloads - its timer does, 4 images per step, blender-mcp-safety R9). Never
   preview by re-pointing the owner's images through the MCP: register a candidate, the owner presses Preview.
7. **Regression gate (`scripts/state_regression.py`, owner 2026-09-29: "Tests should catch regressions from previous
   model states" - the v15 eave scallops were lost silently):** runs on every compose, UV version switch and export.
   `fingerprint` the new state (maps + active plan + geometry; `--export` for an export) and `compare` it with every
   accepted baseline (Korean TC: `Claude_CP2/regression`, `make_baselines.py gate NEW.fp.json`). A FAIL blocks
   promotion unless that exact property is listed in the owner's `waivers.json`; agents never add waivers. Per
   element class across UV layouts, per chart only where the chart is unchanged; the eave part calls
   `qa_detectors.eave_alpha_check`. A newly accepted state becomes a baseline. A baseline from an older tool schema
   FAILs `fingerprint.schema`: re-fingerprint it, never compare around it.
8. **Relief gate (`qa_detectors.relief_missing_check` / `relief_drop_check`; Korean TC CLI `Claude_CP2/relief_gate.py
   <state dir> --base HEAD --base <owner-seen baselines> --declared <job's relief-removal scope>`, owner 2026-09-29:
   "planks not on the model ... This regression should NOT pass the next time!"):** every delivery runs it; exit 3
   blocks. Albedo LINES (seams, joints, member edges, sheet outlines) with no oriented relief within 2 texels FAIL
   per face (the plank walls, window frames and notice-board paper on HEAD 10a73d32 all did), and any tile whose
   relief falls by more than half against HEAD or an owner-seen baseline FAILs unless the job declared it. Only
   owner decisions (his words) go into `relief_gate_waivers.json`. The planks were never in the Normal; the
   PLAIN_WALLS removal job only exposed them - no earlier gate compared albedo structure with relief.

## Automated detectors (`scripts/qa_detectors.py`)

Run them with the numeric QA, before the pictures: `python scripts/qa_detectors.py config.json` (the config format
is in the script header; exit 3 on FAIL; EXR is read through background Blender). Each detector is proven by
`scripts/test_qa_detectors.py` (a small synthetic specimen with the defect FAILS, its clean twin PASSES) and on
the Korean TC maps (`Texturing_11/Claude_CP2/qa_detectors/real_check.py`, 2026-09-28). SKIP = not assessable
(too few windows), never a pass.

| Detector | Catches | Threshold | Real-map proof |
| --- | --- | --- | --- |
| `rhythm_check` | two unrelated rhythms along one UV axis in a normal (an unlocked course bump over modelled rows); any rhythm < 16 texels | window 96 (>= 3 x the longest modelled period); per axis the line-averaged spectrum, sharp peaks, harmonic grouping (0.3 bin + 4 %); a window flags when one axis has 2 rhythms >= 0.15; FAIL when > 30 % of the windows flag | Astra roof relief FAILS in every assessable bank (55-70 % of windows, the 13-texel course over the 30-32-texel rows); roof_v2 PASSES (1-20 %) |
| `stacked_normal_check` | a detail normal printed over a baked structure (planks over the lattice, a tile photo over baked tiles) | final slopes = k * bake + r in the bake-only class; FAIL when rms(r) > 0.35 x rms(bake) | final lattice / roof tiles 0.004-0.07 PASS; the real plank normal whiteout over the real lattice 0.71 (x0.8) and 0.36 (x0.4) FAIL |
| `uv_registration_check` | members reading the wrong part of the owner's strip; members on unbaked texels; mirrored members (listed `directional` materials); member/owner stretch | owner faces grouped into regions across folds < 15 deg; per member min(share on one region, fold registration: the member's fold must sit on an owner fold of the same dihedral +- 10 deg) < 0.9; > 50 % on no owner texels; stretch > 1.4 per UV axis | S17 plan: all 52 tower-eave members + 8 already known partial ones (4 row siblings 79 %, 4 Chart_001 slivers 87-89 %); S18e: the 52 clear; current UV_Final: only the 4 slivers left |
| `mask_offset_check` | edge wear not on the normal's edges, dirt not following AO, a mask from another layout | high-passed normalised cross-correlation over +-6 texels; FAIL when the best offset > 2 texels or the best corr < 0.1 | final EdgeWear / Dirt best at (0, 0); shifted 4 / 3 texels found exactly; the other page's dirt corr 0.016 |
| `mask_layout_check` | a mask from another UV layout | > 2 % of the mask energy outside the islands | final 0 %; the other page's dirt 8.5 % |
| `channel_packing_check` | roughness / metallic / AO in the wrong channel | metallic p99 <= 0.1 off the metal classes; roughness p05 >= 0.05 and >= 50 % mid values; AO mean >= 0.35 | final Masks PASS; G<->B swap FAILS on both rules |
| `class_pattern_check` | colour rhythms < 16 texels per class; flat islands | window 64, > 15 % of the class windows; relative luma std < class floor | flags the 13-texel window lattice painted into the P2048 colour and the 6-texel ridge courses on P1024 (owner decision per "Pattern period vs density") |

Measured limits: 2-D window spectra mis-assign the slope harmonics of sharp tile lips and read one eave band as a
period - use the per-axis line spectra. The reference-free rhythm check does NOT see planks over a lattice (the
40-texel seam harmonics interleave with the 24-texel lattice); a stack needs the bake reference. A 25 deg fold
threshold merged the eave FRONT/UNDER rows (20-23 deg) and found 28 of the 52. The rhythm check reads UV-axis
aligned charts only; narrow strips (P1024 eave banks) SKIP.

### Required upfront checks added after owner escalations (2026-09-28)

Both escalations passed every detector above: each check was per face or per member, and none followed a
pattern ACROSS faces. Two checks are therefore required before the owner sees a roof (implementation tracked
as P1-20 in the Korean TC backlog; until they exist, do them by hand with the owner-camera render below):

| Check | Root cause it would have caught | How |
| --- | --- | --- |
| `run_continuity_check` (per linear element) | side ridges: the MAIN-ridge recipe on round tubes, pattern keyed to per-straight-segment frames -> laps/lines jump at 55 of 59 joints, pale gutters | build runs (chains of faces of one element, e.g. `ridge_parts.classify`); sample the final BaseColor/Normal along the run's arc length across every segment joint; FAIL when the pattern phase or luminance jumps at joints, when a thin element's gutter ring is paler/darker than its inside, or when a class is split by a normal threshold instead of by facets |
| `eave_alpha_check` (qa_detectors.py, type `eave_alpha`) - runs on EVERY compose and EVERY export, exit 3 blocks | eave cutout lost (2026-09-29 regression): ray-miss OPACITY left the end-tile face opaque, the compose dropped the S18f tower cut, a member-fronted back lip stayed opaque | active plan, members through their own UVs: FRONT cut 15-35 %, UNDER hanging part >= 90 %, BACK/UNDER opaque behind a cut FRONT <= 5 %, alpha 0.5 contour <= 1 texel (median) from the baked disc/pan outline; FAIL names the charts |
| `seam_phase_check` (per 3D edge between charts) | west hall south eave: the end-tile strip was a member of ANOTHER roof's eave family (83-89 % registered, so the registration gate passed) -> end tiles at that roof's pitch under this slope's rolls | for every 3D edge shared by two faces in different charts on a patterned class, sample the texture along the edge from both sides; FAIL on a colour/normal discontinuity or a periodic phase drift (tile/roll positions on one side vs the other) |

### Diagnosis pitfalls that cost time (read before diagnosing)

- **Reproduce the owner's exact view first.** Read the live viewport with ONE read-only MCP call
  (`region_3d.view_matrix.inverted()`, `space.lens`, area size) and render it in background. The viewport lens is
  doubled internally: viewport 50 mm = camera 25 mm on a 36 mm sensor. On a review file with board copies hide every
  other board collection, or the camera ends up inside a neighbouring copy. ("The critical part is not visible on
  your images" = wrong camera.)
  For an automatically framed face, calculate its normal from the whole polygon,
  not the first three vertices: valid n-gons can begin with collinear points.
  Reject zero directions, verify the intended side and target visibility, then
  inspect the first crop before launching the full close-up batch (r48 windows,
  2026-10-07). An invalid camera is failed evidence, not a failed material.
- **UV checker vs texture.** If the checker looks continuous but the texture does not, the fault is how the
  material is mapped onto the UVs (recipe, frames, sharing), not the layout - fix the texture, do not re-lay UVs
  (owner, 2026-09-28: "don't do unintentional UV changes"). A UV change is only for faces that read the wrong
  texels (members of another element's family).
- **Renderer.** Prefer EEVEE; in background with a busy GPU it can crash (EXCEPTION_ACCESS_VIOLATION) - fall back to
  Cycles CPU automatically.
- **Memory.** With other Blender jobs running the machine can drop to 2-4 GB free: one heavy Blender job per agent,
  retry once after MemoryError, and pause lower-priority workflows for a critical fix.
- **Report as you go.** Send before/after images the moment a stage has them; a long silent agent reads as stuck.
  For a critical fix, merge a QA-passing result into the live scene at once and let the reviewers finish after.
- **Sessions.** Workflows cannot be resumed from a new Claude session: agents keep partial reports on disk, and a
  relaunch points each agent at its previous journal entries and out dir.

## Delivery pictures: the standard camera set

Owner, 2026-09-29: "the current view might be corrupted because I may change during inspection. So I propose
standardized camera positions around model as fallback if view gives ambiguous data". Delivery pictures come from ONE
standard camera set, defined once in data from the LOW's bounding box (8 RTS views every 45 deg at 52 deg down, a top
view, fixed close-ups of what the owner reviews most; Korean TC: `Claude_CP2/std_cameras.json`, rendered by
`render_std_views.py` through `qa_shots.py` `camera_set`). Every picture is stamped with the state id of its maps and
the view name. Before/after always use the same standard cameras. The owner's live camera is only an extra, used
when the ambiguity check passes: fresh (captured after his last Preview), camera outside the bbox, building in the
frame centre and not a speck, no wall filling the frame from under 1 m. Otherwise the output says
`owner view ambiguous: <reason> -> standard views`.

## Shot list (minimum)

| Group | Views | Must show |
| --- | --- | --- |
| RTS | 4 sides at the game camera angle (about 50 deg down), whole building | silhouette, material read, no black/pink/flat blocks |
| Roofs | one close-up per roof slope family | one tile rhythm, courses, clay variation, no mosaic |
| Ridges and hips | one per ridge line | cap tiles + mortar layers, not a flat band |
| Roof bottoms | each eave from below and the side | tile underside / rafters as designed, no foreign material |
| Eave corners | each upturned corner | continuity of tiles and end tiles, no pale or smeared patch |
| Walls | each wall type | plaster, timber, windows readable, wear at edges, dirt at the foot |
| Base | platform corners and steps | stone, chips, moss/dirt at the foot |
| Board | BaseColor / Normal / Masks / EdgeWear / Dirt / ClassID / UV checker copies | every map present on every face |

## Pass criteria (all must hold)

### Declared AO storage and application

Keep an effect ledger distinguishing measured AO, its packed runtime channel,
BaseColor composition and shader application. Storing AO is not applying it twice.
Shared-island reader count does not darken the stored value. Verify one bake writer
per texel and track actual composition applications; never brighten AO by reader
count. Follow the portable [AO postproduction contract](../../blender-uv-workflow/references/ao-handoff.md#ao-accumulation-count-applications-not-shared-islands).
Preserve the accepted reference/engine contract even when BaseColor already has
contact shading. `scripts/check_ao_storage.py` compares an explicitly scoped,
aligned measured field to the final packed channel; it rejects a cleared channel
and even one lost contact witness (INC-120). Its synthetic regression tests are
`scripts/test_ao_storage.py`. A passing channel check is not a visual AO pass:
show AO-only geometry, BaseColor-only contact and final material against the
reference. Shared-reader suppression and unbaked material roles remain explicit
limitations. Open surfaces can correctly be white; avoid a global darkness quota.

### Material-readability feedback loop

A bound image and nonzero color variance do not prove the intended material reads.
For each owner-priority material, provide a dedicated physical-scale close-up and
an RTS view, with revision/shot stamps and map/mesh hashes. Use the same lighting
and player tint for reference comparisons. Inspect paper fibers and lattice contact,
paint substrate/weathering, masonry courses, timber grain and eave silhouettes
separately. Record observed, inferred and unassessed findings distinctly.

When the owner requests independent agent feedback, use one bounded read-only
review after each candidate, following the project's job cap. The reviewer returns
region-specific finding IDs and re-review conditions. Next loops inspect the
changed regions plus fixed full views and report fixed/new/open IDs; do not repeat
unbounded aesthetic exploration or treat the agent's opinion as owner acceptance.

Korean military r47 (2026-10-07): paper luma std 0.0098 passed a 0.006 floor but
looked nearly uniform. Player-color substrate averaged about 209/255 versus 118/255
on the actual TC reference. Measure the substrate before changing mask weights or
the global palette. Material-specific thresholds supplement this visual check;
arbitrary extra noise is not proof of better paper. Local contact shading shared
by multiple faces must be assessed on every reader; suppress incompatible AO
under an authorized common-AO policy rather than silently adding unique islands.

- **Coverage:** every visible face carries its class material; no empty, black or default-colour texel.
- **Structure:** no flat fills - every class shows its source detail (grain, tiles, plaster, stone).
  Classes WITHOUT a high-poly source (e.g. ridges/caps excluded from the roof bake) need an explicit
  texture plan in the recipe; a generic class fallback is a fail, not a default.
- **One rhythm:** colour patterns derived from a bake source follow the relief's rhythm. Never overlay
  two independent random grids (e.g. random per pan course AND random per roll segment).
- **Pattern period vs density:** a repeated feature spans at least 16 runtime texels (period x texels
  per unit). Below that, keep it in the normal map at low contrast; do not paint it into the colour.
- **Continuity:** tiles/courses continue across a slope and its corners; breaks only at ridges and hips.
- **No stamped repeats:** shared owner texels repeat every distinctive photo mark (stain, scratch, blotch) at
  the same spot on every member; on shared panels keep a photo's contrast low (about half) or choose a
  source without distinctive marks.
- **UV sanity:** the UV checker shows square cells without visible stretch on visible faces; members that
  stretch more than about 1.4x on a patterned material are listed for the owner (UV decision).
- **Material direction:** grain and courses follow the architectural role on every shared reader, including
  mirrored gables, short curved ridge segments and foundation corners. Follow the
  [orientation checks](../../blender-architecture-texturing/references/material-orientation.md).
  Check color and normal direction together; passing color variance is not an orientation test.
- **Materials read at RTS distance:** roof, plaster, timber, stone and windows are distinguishable in
  the RTS shots; wear and dirt stay moderate and concentrated (foot, thresholds, roofline, edges).

## Normal layer stacking rules (owner, 2026-09-28)

A detail normal from a texture source may be added on top of the baked relief ONLY when all hold:
1. the source depicts the surface's real physical structure (wood grain on a wooden member, plaster on
   plaster, stone on stone);
2. the surface carries no baked high-poly structure of a DIFFERENT kind (window lattice, roof tiles,
   eave tiles keep their bake alone);
3. the source's macro features match the object: plank seams only on real boarding (doors, board walls),
   never on a post or beam (one piece of timber); block joints only on blocky masonry.
Examples: base wood + plank tiles on a board wall - YES; planks + window lattice - NO; tile photo + baked
roof tiles - NO. Violations read as "two normals printed over each other". qa check: view the Normal board
copy on every class; a second pattern inside a baked structure fails.

## Material consistency rules (owner, 2026-09-28)

- **Across a building set:** use the accepted reference building's versioned palette
  and recipe controls, then test finished material equivalence with the
  [set-consistency procedure](../../blender-architecture-texturing/references/building-set-consistency.md).
  Passing this document's generic class-color tolerance is not evidence that a new
  building matches the set. Compare the actual reference outputs and common scene.

- **One tint family per material:** every wooden element shares ONE hue family (members, boards, lattice,
  gables, sign board); variation per member at most about +-3 %. Distinct roles differ by a deliberate
  value step (e.g. lattice darker), written in the palette, not by random picks. "Random wood in random
  colours" is a fail.
- **A tint request never swaps the source.** "Align the tint" = keep the photo the owner has seen and change
  only its colour with a tool: Photoshop adjustment layers (Solid Color in Color mode + Levels, editable PSD,
  e.g. `ps_tint.py`) or a documented colour transform. A different photo is a separate proposal shown side by
  side (2026-09-28: a swap to a "better tinted" timber photo was rejected as "2-3 levels below the original").
- The palette lives in one place (compose config / manifest / the tint script's job table); board views use
  the upstream split palette.

## Constraints learned (roof, 2026-09-28)

- Bake colour IDs from the SAME high-poly shader math as the relief (EMIT map kind of
  `bake_owner_maps.py`); an ID baked from a different frame, pitch or phase does not line up.
- **A procedural bump on a high must be locked to what the high already models.** Measure the modelled
  features first (ray profiles along the slope: crest drops, channel kinks), then drive the shader through
  the MEASURED positions. On a curved roof the rows are even along the curve, so their spacing along a
  straight axis drifts (0.284 -> 0.298 over 7 rows): map piecewise-linearly through the measured rows, never
  one period + phase. An unlocked course shader bakes a second rhythm = "extra stripes" (2026-09-28, three
  owner rounds; fix `roof_v2.py`: matched filter, per-row refine, piecewise course coordinate, gate on every
  row gap = one tile).
- Per-tile variation only on the dominant, readable element (the roll segments), gentle (about +-6 %);
  the channels stay uniform, slightly darker; lip line subtle.
- Photo sources on patterned materials keep at most half of their contrast, so the geometry rhythm reads.
- Surface masks (edges, short AO) need the whole model around the owners: keep member faces in the
  bake object with their bake UVs moved to u+2 - the bake skips them (tested), neighbours stay real.
