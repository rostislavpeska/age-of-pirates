---
name: blender-uv-conjoin
description: Apply explicit per-region UV sharing policies to coherent charts, preserving source scale and reporting distortion, compatibility and space diagnostics. Use after clean-chart and material review for shared-family proposals; final packing and AO are separate checkpoints.
---

# UV conjoinment (merge similar charts, then repack)

All operator delivery follows the required portable
[UV operator contract](../blender-uv-observability/SKILL.md). Family colours must
come from actual owner/member UV correspondence, not arbitrary island colours.

Goal: the smallest atlas at a fixed texel density that still reads like an AoE
texture set. Two levers, in this order of payoff on the Korean TC (page A):

| Step | Page side at 256 texels/unit | Area vs original page |
| --- | --- | --- |
| original layout | 8192 | 100% |
| repack only, no sharing (1711 charts) | 7296 | 79% |
| repack S12's existing sharing (569 owners) | 5494 | 45% |
| exact containment sharing (science route) + repack | 5370 | 43% |
| **T1** merge +/-10%, IoU 0.85 + repack | 4458 | 30% |
| **T2** merge +/-25%, IoU 0.75 + repack | 3870 | 22% |
| **T3** merge +/-40%, IoU 0.60 + repack | 3116 | 14% |

Empty atlas space was the largest waste, then near-similar charts that exact
matching refuses to merge. T3 was chosen for that historical TC experiment. It is not an automatic rule for
new buildings. Read [lessons](references/lessons.md) for its measured trade-offs.

## Stage and region policy

Use [the shared UV workflow](../blender-uv-workflow/SKILL.md). Clean charts and
material classification precede sharing. Choose T1/T2/T3 or exact correspondence
per region, recording distortion and channel restrictions. T3 allows about 67%
axis stretch and is an explicit approximation, never an architecture-wide default.
Signs, unique ornament and grain/normal/alpha/player-color regions remain protected
unless their correspondence is proven. Assembly/contact AO is deliberately pending
in the first sharing phase; it must not veto geometry/material/role conjoinment.
Follow [the two-phase contract](../blender-uv-workflow/references/sharing-and-capacity.md).
The CLI requires a preset;
the library's conservative default is T1. Reflection is not enabled by this helper.

## Workflow

1. Consume the reviewed unique-chart baseline and material classes. List affected
   layout-bound bakes; use existing authorization for the change, preserving the
   previous version. A valid bake master may be re-derived under its contract.
2. Export real UV charts with `scripts/blender_export_faces.py`. Its default
   `normalize=False` preserves source coordinates and density. IDs are namespaced
   by object; maintain persistent part/face IDs if topology or names will change.
3. For a sharing checkpoint use `conjoin.families(...)`, which does not pack.
   It preserves chart boundaries by default. Hollow-frame refinement is explicit
   (`split_hollow_charts=True`) and needs parent-child lineage plus continuity
   review before applying; do not split accepted frames merely to meet a quota.
4. `scripts/conjoin.py` is a merge-plus-pack experiment. Use it only when that
   packing is intended, e.g. `python scripts/conjoin.py faces.json plan.json --preset T1 --page 8192`.
   `--page` is the emitted UV denominator; measured packing footprint is separate.
   Gutter is in working texels. Final compression/mip padding must be tested.
5. Inspect space diagnostics: hollow and unique share, packing efficiency and
   largest owner are ADVISORY. Explain legitimate unique surfaces. Do not repeatedly
   rerun or distort charts to force those percentages green. An explicit minimum
   runtime density still fails when violated. Numeric inputs must be finite.
6. Apply to a candidate copy through `scripts/blender_apply_conjoin.py`; keep the
   unique layer and source unchanged. Show family-colored full models, readable UV
   sheets and owner/member close-ups, before AO separation. Use a legend: gray is
   unique, family colors mean shared texels, material colors are a different view.
7. Report before/after packed footprint at identical scale/gutter, actual emitted
   UV scale, owners/members, distortion, channel compatibility and unresolved AO.
   Geometry-only candidates are provisional, not bake-ready.

## Rules that hold regardless of preset

- **Never change owner chart size.** Output UVs at the ORIGINAL page scale
  (`--page 8192`): owners keep their exact original UV size, the freed space stays
  empty, and the owner decides later whether to shrink the page. Do not rescale the
  result to fill 0-1 and keep exporter `normalize=False` (the current default).
  Both were an owner-reported drift (2026-09-28): they silently raised texel density.
  An explicitly authorized density revision is a separate, measured operation;
  it does not change this helper's scale-preserving contract.

- Same material only; never merge across material IDs (wood onto plaster, window onto wall).
- Whole charts are the unit; do not cut charts into scraps to raise the merge count.
- Rect-to-rect mapping changes member texel density by the axis scale factors;
  report it. T3 allows up to about 67% stretch on one axis by construction.
- Owners are packed tightly; the packer (`pack_rects.py`, MaxRects best-short-side)
  hits known optima on its controls. Blender's pack_islands failed those controls
  (10% worse on 16 squares; exact-shape mode hung) - do not use it for measurement.
- Geometry-only: no AO veto in this first phase. Subsequent AO variants need one
  owner bake each; unique contact shading is a reason for a measured local split,
  not to un-merge everything.
- This helper uses proper rotations only. A separate reflected-sharing method must
  prove normal/tangent and directional-channel compatibility before use.
- **Role registration gate (2026-09-28, Korean TC tower eaves).** A member must land on the owner texels of
  its OWN role, not just inside the owner chart: an eave strip has an end-tile FRONT row and a cut-out UNDER
  band; a T3 merge put 4 tower-eave charts onto the rear-hall strip upside down and 1.5x wide, so the tower's
  end-tile faces read the cut-out band (22-82 % on the wrong role). Every checker, density and overlap test
  passed; only the renders showed it, after texturing. Before accepting a conjoin, rasterise every member's
  quad into the owner's texels and require >= 90 % on the same role (FRONT / UNDER / TOP / SIDE by the face
  normal relative to the family frame) and the same handedness for directional content (tiles, grain,
  lettering). Fix a failing member by unsharing it (own chart from its own unwrap, baked from its own high),
  not by stretching it onto the owner strip. Evidence: `ridge_member_audit.py`, S18f fix (56 faces).
- **Never share a patterned strip across elements with a different rhythm.** An eave end-tile strip shared between
  two roofs gives the member the owner roof's tile pitch and phase: its end tiles drift against its own rolls even at
  83-89 % registration (Korean TC west hall south eave, owner escalation 2026-09-28). Fixed in S18i by re-conjoining
  the 12 faces corner for corner onto a strip with the same pitch and phase (the Tower upper eave): the unshare did not
  fit the page. Conjoin patterned strips (eaves, ridges, tile rows) only between runs with the same measured pitch and phase.

## Quick reposition (a texture does not sit)

When a face shows the wrong texture - a wooden frame renders white like plaster, a sill turns band green, an eave
strip reads another roof's rhythm - the quickest fix is often to move only its UV island onto texels that ALREADY
hold the right content: it becomes a MEMBER of a congruent owner of the right class and role (corner for corner, or an
exact 1:1 window inside a larger owner), or moves onto free texels of that class. No new texels, no bake, no recompose.

1. **Find every such face, not just the one in the screenshot.** `qa_detectors.py` `class_mismatch_check` measures,
   through the active plan, each face's class against the ClassID texels it samples. The plan material agrees with
   the texels it baked, so pass an independent per-face truth as `expected` (e.g. the authored material); the Korean TC
   S18k frames were plan PLASTER, authored wood: 12 faces of one facade, while the screenshot showed one.
2. **Reposition** with `scripts/reposition_island.py` (one command, config JSON; `--help` and its docstring):
   `python reposition_island.py run --config cfg.json --faces KEY,KEY --version S18k --out DIR [--target-class WOOD]
   [--target-family F | --target-owner K] [--accept-ao] [--allow-free]`
   (stages `plan`, `apply`, `low`, `verify`, `handoff`; `plan` alone is a dry run that lists the candidates).
3. **Guards it enforces**: proper rotations only (normal onto normal, up onto up, never mirrored), density per axis
   1 +- 3 %, same UV handedness, owner texels of the class (ClassID) and **plain** in every decorated map the owner can
   see (a member inherits all its owner's paint: the sharing collateral), the S14 AO point test (a miss only with
   `--accept-ao`, reported for the owner's decision), role registration (`uv_registration_check`: no new or changed
   flag anywhere, every moved face >= 90 % on its owner), `class_mismatch` clean for the moved faces and nothing new,
   no new cross-family overlap, UVs changed on the moved faces only (byte identity of both saved blends). A moved owner
   whose texels other members still read hands the ownership to the member covering its footprint.
4. **One batched UV switch per checkpoint.** Build the next version on the last unswitched one (S18k on S18j), never
   next to it; chain its live patch (`live_patch_chain`) so `from` is what the owner's scene still has.
5. **Deliver** by live patch: `live_patch_<ver>.json` `{object_hint, uv_layer, faces {i: {from, to}}}` for the
   coordinator to apply to the owner's scene; the tool never touches the active UV version, final maps or the live
   Blender. Render before/after from the owner's current scene state with the patch applied in memory.

## Next step: AO separation

Before baking AO onto shared texels, run [blender-uv-ao-separation](../blender-uv-ao-separation/SKILL.md):
it consumes these parent families and splits incompatible AO members within each
parent using corresponding-point tests. If using `families()` with a `compat`
hook, partition by the saved parent first and preserve the exact correspondence;
do not silently replace this sharing proposal with a global re-conjoin.
Then split families onto runtime pages with [aoe-uv-atlas-export](../aoe-uv-atlas-export/SKILL.md).
Curved charts (pot bands, rings) are never split as frames: a chart whose pieces use more
than four directions is treated as curved.

## Tools

- `scripts/conjoin.py` - merge + repack library/CLI, presets T1/T2/T3.
- `scripts/audit.py` - explicit hollow-chart refinement, space advisories and runtime density check.
- `scripts/pack_rects.py` - validated packer and page-side measurement (self-test: run it).
- `scripts/reposition_island.py` - quick reposition of a few faces onto the right texels (above);
  specimen proof `test_reposition_island.py` (pytest).
- `scripts/labeled_fit.py` - exact directed-Hausdorff containment (fallback #2): certified
  rigid fits, labels for material, grain/up direction and semantic tags.
- `scripts/blender_export_faces.py`, `scripts/blender_apply_conjoin.py`,
  `scripts/render_review.py`, `scripts/draw_uv_sheet.py` - Blender round trip and review.
- `python -m unittest test_conjoin` from `scripts/` (includes the frame-incident regression tests).
