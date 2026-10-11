# The organic UV method in detail

The recipe is the hybrid that won a seven-method comparison on a 1.1k-triangle rider on 2026-10-11 (measured trade-offs
in [rejected methods](rejected-methods.md)): rule-based mirror-exact garment seams, SLIM, a mirror-exact layout with
unique texels, upright islands, island-scale head priority, a pair-aware raster packer with a 16 px gutter. Every
number below is measured on that rider unless a source key says otherwise ([sources](sources.md)).

## 1. Preconditions

| Input | Must hold | Check |
| --- | --- | --- |
| Deforming mesh | passed G2, G3 and the final silhouette of `blender-organic-modeling` | its handoff |
| Export copy | triangulated, final vertex order; UVs are planned on the mesh that ships | `organic_audit.py` triangulated check |
| Quad authoring mesh (optional) | same vertex order and positions as the export copy | `seam_plan.py` refuses a mismatch |
| Mirror | mirror-exact across local x = 0 **with a centre edge loop** (vertices on x = 0); left/right faces mirror one to one | `mesh_dump.py` `mirror_unmatched` = 0; the layout reports faces that straddle x = 0 |
| Part labels | one label per polygon: a face attribute (INT with a names map, or STRING) or a part map `{object: [label per polygon]}` | `mesh_dump.py` `part_source` |
| Ring/slot ids (optional) | INT vertex attributes of a ring-built body, slot ids consistent along a limb | used by `slot_line` / `ring_loop` rules |
| Weights | the bound vertex groups (bone regions read them) | `mesh_dump.py` `weights` |
| Texture budget | which meshes share which page and its size (G0 contract) | the layout config |

A mesh that is not mirror-exact can still be unwrapped (rules with `"mirror": false`, layout without
`mirror_objects`), but the left/right symmetry gate and mirror-copy painting are then lost.

## 2. Seam plan: declared rules, not search

Seams follow garments and the hidden side, as the shipped reference units do: torso cut down the back centre (or
down a coat's front opening), head cut at the back centre, arms cut along the underside, hands a separate island, legs
on the inner side, open hems left as natural borders (the game layer records its own units' seam anatomy). Write them
as a rule table
(`seam_plan.py`, schema in its docstring) so the plan is repeatable, reviewable and mirror-invariant by construction:
side rules run on +X and are mirrored.

Worked example for a coated rider (labels are the asset's own):

| Rule id | Kind | Declaration | Why |
| --- | --- | --- | --- |
| neck | border | coat / hood+collar | part border, hidden by the collar |
| armholes | border | coat / shoulder flap | part border; the arm becomes its own island |
| waist | border | belt / trousers | under the coat skirt |
| boot_tops | border | trousers / boot | part border |
| wrists | border | bracer / hand | hands are a separate island (the reference units share one stock hand island) |
| scalp_ring | border | scalp / hood+face | hidden under the helmet |
| torso_hood_back | centre | coat, belt, hood: back | the back centre; the torso unrolls into ONE island with the armholes as holes |
| trousers_back / trousers_front | centre | trousers: back / front | the front cut sits under the skirt |
| inseam | path | trousers, centre_lowest -> boot border, hide (-1, 0.15, 0) | inner leg (on +X the inside faces -X) |
| arm_underside | path | flap+sleeve+bracer, armhole -> wrist, hide (-0.6, 0.35, -0.7) | ONE island per arm, no elbow or cuff ring |
| palm | path | hand, wrist -> farthest_from, hide (-1, 0.2, -0.2) | a closed mitt needs a cut to its apex |
| heel, sole | path | boot top -> lowest-back vertex (hide +Y), then -> toe tip (hide -Z) | a cut that stops at the heel leaves the toe cone closed |

Rules of thumb, each from a measurement:

- **No cuts across deforming joints.** Elbow and knee rings put a seam where the skin stretches; one island per arm
  (flap + sleeve + bracer) reproduced the reference rider's arm anatomy with 1.78 m visible body seam against its
  2.25 m, while four-piece arms with an elbow ring reached 2.0-2.3 m.
- **Closed ends need a cut to their apex** before any solver: an inner-hand cut to the fingertip pole took hand
  anisotropy 2.48 -> 1.41; a back-of-boot cut continued along the sole to the toe tip took boot 2.24 -> 1.21; open
  pyramids (studs, a spike) unfold exactly with one base-to-apex edge (`apex` rule, L2 1.383 -> 1.000).
- **Cone points**: for attachments that are not garments (helmets, hats), `cone_deg: 300` joins every interior vertex
  whose angle sum is below 300 deg to the island border; it took a helmet page from L2 1.066 / aniso p90 2.57 to
  1.003 / 1.15.
- **A bent or twisted tube** (a plume) is the exception to the hidden-side rule: of 24 candidate cut lines one gave L2
  1.022 and another 1.805, and the hidden-side heuristic picked a near-worst one (1.52). Cut along the outer crest of
  the bend, or try the candidate lines and measure.
- **Plan on quads, ship triangles**: with `"graph": "<quad object>"` paths stay on the authoring mesh's edges, so a
  triangulation diagonal never becomes a seam; seam pairs apply unchanged when the vertex order is identical.
- **Holes are allowed only where declared** (`allow_holes`): the torso island with two armhole holes matches the
  reference rider;
  SLIM's `fill_holes` handles them. Any other non-disk island is a FAIL, or gets an automatic hidden cut with
  `"complete": "cut"` (reported, so it can become a declared rule). A cup (a closed cap) counts as a disk: the census
  cannot see cap distortion, the palm/apex/cone rules do.
- **Coat side seams** (armhole -> waist) relieve the armhole corners (Linf 1.70 -> 1.47) but add 0.77 m of seam that
  shows from the side headings (+0.13 m mean visible seam) and cost 3.5 % density: not by default.

## 3. Flattening: SLIM

`organic_unwrap.py` defaults: `method=MINIMUM_STRETCH` (SLIM), `no_flip=True`, `fill_holes=True`, `iterations=50`,
`correct_aspect=True`, margin 0. Always pass the method: the operator's RNA default in Blender 5.1 is CONFORMAL.

| Solver | On a garment seam set | Use |
| --- | --- | --- |
| SLIM (MINIMUM_STRETCH) | even density inside islands (cap 1.01x, spread p95/p05 1.17 on a synthetic fist), page L2 1.010-1.011, 0 flips; 50 iterations beat 10 (angle p90 1.31 vs 1.36) for < 0.1 s | default |
| ABF++ (ANGLE_BASED) | conformal: closed ends and strips undersampled inside their island (a shoulder triangle at 0.48x, mitt density spread 1.75x, face 0.93x torso) | per-object fallback (`--object-method NAME=ANGLE_BASED`) when SLIM cannot be fixed with cuts |
| LSCM (CONFORMAL) | collapses closed ends (22 flipped faces, 935 px2 of folds, mitt L2 15.9) and drifts in scale along bands | refused unless `--allow-conformal` |

SLIM importance weights only move texels inside an island (Blender rescales every island to its own 3D area), so a
cross-island priority is an island scale (section 4), not weights. `no_flip` prevents flipped triangles, not boundary
self-overlap: a 12-face strip kept a 4.5 px2 fold once; the evaluator's `overlaps.self_fold_px2` catches it, and one
bridge cut across the strip removed it. On a mirror-exact mesh with a mirror-invariant seam set SLIM returns
mirror-exact islands (asymmetry about 1e-7 of the island size).

## 4. Layout

`organic_layout.py`, one config for all pages:

1. **Islands** from the raw unwrap.
2. **Mirror, unique texels** (`mirror_objects`): a centre island whose faces mirror inside it is made exactly symmetric
   about a vertical axis (average of +X and the reflection of -X, centre-plane corners joined); every -X island is
   rewritten as the reflection of its +X twin, placed beside it as its own island. Left/right density asymmetry 0.000:
   one side can be painted, mirror-copied, then made asymmetric. Never stacked (section "decision rules" of SKILL.md).
   An island whose mirror does not close, or whose faces straddle x = 0, is left as solved and reported: forcing a
   non-exact island symmetric by averaging moved a helmet dome by 2.2 % and raised its angle stretch to 1.33.
3. **Upright**: the projected 3D up of each island points to +V; a weak up (a horizontal top) puts the front at the
   bottom, else the long axis goes vertical. The packer never rotates. Upright cost nothing (coverage 60.9 -> 61.2 %);
   CARDINAL packing left 37 % upright, AXIS_ALIGNED 64 %.
4. **Normalise** every island to 1 UV unit = 1 m of surface, then **scale it by its priority multiplier**
   (`island_priority.py`): the 3D-area-weighted mean factor over the island's visible faces (all when none is
   visible; a mirrored pair uses both twins). Factors come from a per-part table or a per-polygon list; never-visible
   faces are capped (`hidden_cap`, 0.75 in the evidence run). Averaging over all faces instead diluted head/torso from
   1.28 to 1.01-1.10, because 44 % of the head island was never visible.
5. **Head calibration** (`head_target`): the head islands (dominant bone region `head`, not entirely hidden) get one
   common factor s, solved by bisection so that the bone-region estimator reads the target ratio. The estimator is a
   ratio of area sums, independent of the page density, so it is solved before packing.
6. **Pack**: raster bottom-left packer (FFT collision test; mirrored pairs as one unit), one texel density D found by
   bisection, five orders x three fill modes, the best D kept. Gutter = dilation halo of `gutter/2 + halo_extra_px`
   texels: 0.75 gave a 7.76 px gap against an 8 px contract, 1.25 held 8.5 px. The raster packer covered 65.9 % at an
   8.5 px gap where Blender's `pack_islands` (CONCAVE, rotation off) covered 61-62 %, about +4 % density. Verify the
   gutter with the evaluator, never trust the halo.

Gutter sizes: 16 px at 1024 keeps islands apart through mip 4, the gaps vanishing at mip 5 like the reference
rider's 21.3 px (the evaluator's `gutter_vanish_mip` = the first mip where the closest pair is under 1 texel), for
-3 % density against 8 px; 8 px at 512 for an attachment page holds through mip 3 and vanishes at mip 4. If Blender's packer is used instead (for a quick
attachment page), `margin_method='FRACTION'` pads EACH island: island gap = 2 x margin, page border = 1 x margin
(margin 4.25/1024 -> 8.5 px gaps, 4.25 px border).

Page assignment comes from the G0 contract: typically the body and any weapon skinned into the body mesh share the
unit page, while separately attached models (a hat or helmet on a head attach point, a bow) own a smaller page; the
game layer records what its shipped units do and the project's rule. Run the overlap gate on every mesh bound to one
page together: per-object checks found 0 folds while a placeholder helmet sat on 74 % body
texels of the same page.

## 5. Apply

`organic_apply.py` writes the layout as a new layer into a copy, makes it active and active-render, removes named
placeholder layers (`--remove-uv-layer UVMap`), marks the island borders as seams and compares them with the plan,
and refuses to save when anything but UV layers and seam flags changed. Remove the placeholder before the audit and
the export: an exporter that writes the first or every layer would ship it, and it pushed a rider from 1001 to 1065
GPU vertices, over a 1,050 ceiling. The evaluator's `counts.gpu_vertices_all_uv_layers` counts every layer in the file.

## 6. Evaluate

Two `uv_eval.py` runs per unit page:

| Run | Objects | Occluders | Read for |
| --- | --- | --- | --- |
| page | every mesh on the page (body + skinned weapon) | attachments | distortion, density, packing, overlaps, flips, orientation, symmetry, GPU vertices |
| body | the body alone | weapon + attachments | seams per sqrt(area), visible seams, UV split ratio, islands, head/torso: the fair comparison with a reference body that owns its page |
| attachment | the attachment alone | body + weapon | its own page's gaps, stretch, flips |

Flags: `--gutter-px 8` (the hard limit; the 16 px target is read from `min_island_gap_px`), the posed visibility from
the game layer (`--pose-npz`, or `--pose-frame` on an imported clip) with `--pitch` and `--headings` matching the
game camera, and the part labels (`--part-map` or `--part-attr`). Then `uv_gates.py` with the profile, and
`compare_runs.py` against the reference unit and the previous candidate.

Read the numbers with these traps in mind:

- **Page L2 counts intended priority as stretch**: a 1.3x head raised the page L2 from 1.010 to 1.026. Judge each
  island's own stretch (`islands.list[].L2_stretch_island`) when priorities are on.
- **Compare seam length per sqrt(surface area)**, never in metres: 11.37 m against the reference rider's 11.61 m
  looked shorter but was +5 % per unit surface (5.55 vs 5.30), because the reference body is larger.
- **Head/torso only on the same estimator**: part labels read 1.29 where the bone-region estimator read 1.12 on the
  same layout (section 8). Reference ratios measured on shipped units are bone-region numbers.
- **About 26-31 % of a rider's UV area sits on faces never visible** at the seated game camera (the reference rider
  30.8 %). This is one idle key, so it is a candidate for down-weighting, not proof.
- **Look at the pictures** before trusting an orientation or visibility number (a wrapped tube was once labelled
  "flat" by a mean-normal rule).

## 7. Delivery, handoff and journal

- Every bounded UV batch (seam plan, unwrap, layout, each optional step) is saved and checked, and its actual UV
  pictures go to the owner before the next dependent step: `uv_layout.png`, `summary_card.png`, `model_checker.png`
  and the `compare_runs.py` sheet. Machine verification, delivery and owner acceptance are separate facts.
- The phase handoff uses the project's contract (in this library hosted by
  `blender-architecture-texturing/references/handoff-contract.md` and its `handoff.py`): the UV layer name, the
  pages, the seam-rule table, the layout config, the evaluator runs and the gate report go under `qa`.
- Lessons go to the [workflow journal](../../workflow-journal/SKILL.md) at the moment they happen, stage `unwrap`.

## 8. Evidence run (2026-10-11, Blender 5.1.2)

The evidence rider: a 1124-triangle body + 146-triangle skinned flail on one 1024 page, a 96-triangle helmet on its
own 512 page; seated idle pose from the game layer's pose simulator, pitch 47, 8 headings.

**Port fidelity.** The skill's chain, run on the same file, reproduced the hand-built hybrid exactly: the rule table
of section 2 gave the same 138 body + 51 weapon seam edges as the hand-written planner; `organic_unwrap.py` gave a
bit-identical raw unwrap; `organic_layout.py` (search range 150-1200 t/m, as the original) matched the original
layout within 1e-15 UV units at the same page density 358.22 t/m; the evaluator found 0 differences in the 503
numeric metrics both versions report (page run 279, body run 224; the port adds the bone regions, the GPU count over
every layer and the per-sqrt(area) seams, and reports a density floor only on request).

**Result (H1 recipe).** Page: L2 1.026 / Linf 1.81, angle stretch 1.123 / p90 1.298, density p50 372 / visible p10
345 t/m, coverage 60.3 %, min gap 16.5 px (vanishes at mip 5), border 11.25 px, 0 flips / folds / overlap, 100 %
upright, left/right asymmetry 0.000, 899 GPU vertices. Body: 15 islands (0 tiny), seam per sqrt(area) 5.55, visible
0.87, UV split ratio 1.24. Every hard gate of the profile passed; targets missed: visible p10 (345 < 350) and the head
ratio on the bone-region estimator, 1.119 (1.271 on visible faces only). The helmet page: 0 flips / overlap, 8.58
px gaps (mip 4), L2 1.003, angle stretch 1.073.

**Head calibration on the bone-region estimator** (same seams and unwrap):

| Variant | Head-island factor | Head island t/m | Page D t/m | Page L2 | Head/torso all faces | Visible faces |
| --- | --- | --- | --- | --- | --- | --- |
| H1, part-label priority (hood x1.34) | 1.342 | 481 | 358.2 | 1.026 | 1.119 | 1.271 |
| calibrated, all faces, target 1.3 | 1.613 | 568 | 351.9 | 1.038 (target 1.03 missed) | 1.300 | - |
| calibrated, visible faces, target 1.3 | 1.376 | 490 | 356.0 | 1.027 | 1.142 | 1.300 |

Two causes keep the all-face reading low: the hidden scalp, shrunk to x0.6 on purpose, falls into the head region,
and hood faces weighted to the upper spine lift the torso. Which variant the 1.3 target applies to is an open owner
decision ([open questions](open-questions.md)).
