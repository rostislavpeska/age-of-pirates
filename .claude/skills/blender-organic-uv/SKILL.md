---
name: blender-organic-uv
description: Unwrap deforming organic game assets in Blender - people, riders, clothing and armour on a body, their skinned weapons and attached hats or helmets - with declared mirror-exact garment seams, SLIM flattening, a unique mirrored upright layout, island-scale head priority read on the bone-region estimator, a pair-aware packer with a texel gutter, and an evaluator gated against shipped reference units. Use for character or creature UV unwraps, seam planning, UV evaluation, head-density priority and packing a unit texture page. Not for buildings or static props (the blender-clean-uv family) and not for baking or texturing.
---

# Organic UV (unwrapping meshes that deform with a skeleton)

Generic Blender method for the UVs of an organic asset after `blender-organic-modeling` has proven its deformation.
It holds no game numbers of its own: a gate profile measured on the consuming game's shipped units supplies them (the
game layer fills a copy of [`profiles/template_unit_body.json`](profiles/template_unit_body.json)). Rules are marked
**must**, **should** or **may**; each reference gives the measurement behind a rule.

## Scope and routing

| Need | Where |
| --- | --- |
| Modeling, skinning, pose tests, the export copy | `blender-organic-modeling` (its G2, G3 and final silhouette must pass first) |
| Buildings, props, architectural charts, conjoin, AO separation, atlases | the `blender-clean-uv` / `blender-uv-*` family; their chart, coherence, density-floor and fragmentation rules are not organic rules ([gates](references/gates.md), notes) |
| Scene and file conventions, handoff, journal, live-session safety | `blender-asset-conventions`, `blender-mcp-safety`, `workflow-journal` |
| Game facts: reference units and their gate profile, page budget, pose clips and the pose NPZ writer, camera pitch, export route | the consuming project's game layer, never this package |
| Baking and texturing an organic asset | not covered yet |

## Local prerequisites

Follow the [local-tool readiness guidance](../skill-library-audit/references/local-tools.md). Background Blender with
`bpy`, `bmesh` and `mathutils` runs the dump, unwrap, apply and evaluator stages; host Python with numpy, scipy and
Pillow runs the planner, layout, priority, drawing and gate tools. Blender is found through the companion skill's
`blender_env.py` (`--blender-exe`, `--local-config` tools.blender.path, `BLENDER`, PATH, the standard folder). Every
output goes to a scratch folder: the tools refuse paths inside a git work tree. No live Blender, no screen control:
the whole chain is background work. Command lines and file formats: [scripts/README.md](scripts/README.md).

## The method

| Step | Work | Passes when |
| --- | --- | --- |
| 0 | Preconditions: export copy triangulated and final, **mirror-exact with a centre edge loop**, part labels per polygon, weights bound, the page budget agreed ([method](references/method.md), section 1) | `mesh_dump.py`: 0 unmatched mirror vertices, parts present |
| 1 | **Seam plan** as a declared rule table (`seam_plan.py`): part borders (neck, armholes, waist, boot tops, wrists, scalp), the back centre of torso and head, trousers centre back and front, one hidden cut per tube (inner leg, arm underside, palm to the fingertip, back of the heel then along the sole to the toe tip), **one island per arm**, no ring across an elbow or knee; `apex` and `tube` rules for small parts, `cone_deg` for attachments | every island a disk or a declared disk with holes; the set mirror-invariant |
| 2 | **Flatten with SLIM** (`organic_unwrap.py`): MINIMUM_STRETCH, `no_flip`, `fill_holes`, 50 iterations, method passed explicitly; ABF++ only as a per-object fallback; never pure LSCM | 0 flipped faces |
| 3 | **Layout** (`organic_layout.py`): centre islands made exactly symmetric, every -X island the reflection of its +X twin as its own island (**unique texels, never stacked**), islands upright (3D up = +V, packer never rotates), normalised, scaled by their priority multiplier, head islands calibrated on the bone-region estimator, packed with a **16 px gutter at 1024** (gaps hold through mip 4, vanish at mip 5); attachments on their own page | layout written, no problem reported |
| 4 | **Apply** to a copy (`organic_apply.py`): new layer active and active-render, placeholder layers removed, seams marked from the islands | geometry unchanged; marked seams = planned seams |
| 5 | **Evaluate** (`uv_eval.py`): a page run and a body-only run with the game camera's posed visibility, then `uv_gates.py` with the profile and `compare_runs.py` against the reference unit | every hard gate passes; missed targets named in the report |
| 6 | **Deliver** the pictures of each batch to the owner (`uv_layout.png`, `summary_card.png`, `model_checker.png`, the comparison sheet) before the next dependent step; handoff and journal | the owner has seen them; acceptance recorded separately |

## Decision rules

- **Solver.** SLIM **must** be the default: it keeps density even inside islands where the conformal solvers squeeze
  closed ends (ABF++ left a shoulder triangle at 0.48x; LSCM collapsed mitts to L2 15.9 with 22 flips). ABF++ **may**
  be used for one object when cuts cannot fix SLIM there; CONFORMAL is refused by the tool.
- **Mirror.** Left and right **must** own separate texels (the shipped reference riders mirror 0 %): the -X island is a reflected
  copy beside its twin, so one side can be painted, copied and then made asymmetric. Stacked halves fail the gates.
  An island that is not mirror-exact is left as solved, never averaged into symmetry.
- **Orientation.** Islands **must** be upright and the packer **must not** rotate: CARDINAL left 37 % upright,
  AXIS_ALIGNED 64 %, upright packing cost nothing.
- **Gutter.** 16 px at 1024 (8 px floor), 8 px on a 512 attachment page, verified by the evaluator, never by the
  packer's halo. 16 px costs 3 % density against 8 px; keep it until a texture test proves 8 px enough.
- **Head priority.** An island scale, not SLIM weights (weights only move texels inside an island). Factors average
  over the island's **visible** faces; read and calibrate the ratio on the **bone-region estimator** (the one the
  reference ratios were measured with), never on part labels: the same layout read 1.29 by labels and 1.12 by bone
  regions. The target is the project's decision (the game layer records it); whether hidden faces count is open
  ([open questions](references/open-questions.md)), so report both readings.
- **Pages.** The page budget comes from the G0 contract: typically the body and any weapon skinned into it share the
  unit page, and a separately attached model (a hat or helmet on an attach point, a bow) owns a smaller page. Gate
  overlaps over every mesh of a page together.
- **Optional steps stay off** unless measured better at page level: straightening strips into rectangles (cost two
  targets on the evidence rider for no packing gain), stacking identical small parts (0 gain, gates failed), coat side
  seams (+0.77 m of flank seam seen from the side headings, +0.13 m mean visible seam, -3.5 % density).
- **Comparisons.** Seam length per sqrt(surface area); seams, splits, islands and the head ratio on the body-only run;
  each island's own stretch next to the page L2 (a priority raises the page L2 by design).

## The mistakes that cost the most

- Gating an organic UV with the building gates: the density floor passes trivially, islands-per-area misfires and the
  smooth-patch coherence check flags every garment seam. Use the declared seam plan and a profile measured on units.
- Cutting arms into pieces with an elbow ring, or stopping a cut before the apex of a closed end (hand, toe, stud).
- Trusting the hidden-side heuristic on a bent tube: it chose a near-worst plume cut (L2 1.52 against 1.02 possible).
- Leaving the operator default (CONFORMAL in Blender 5.1), or assuming `no_flip` prevents folds (a strip folded anyway).
- Averaging priority over all faces (44 % of a head island was never visible: head/torso diluted to 1.01-1.10), and
  quoting a part-label ratio as matching a reference measured on bone regions.
- Trusting a packer halo of gutter/2 + 0.75 (gave 7.76 px against 8): use + 1.25 and measure.
- Checking overlaps per object while several meshes share one page (a helmet sat on 74 % body texels unseen).
- Leaving the placeholder UV layer first in the file: the exporter may ship it and the GPU count rose 1001 -> 1065.
- Comparing seams in metres between models of different size, or straightening on island cost alone.

## Handoff and journal

- Each phase ends with the project's handoff (in this library `blender-architecture-texturing/references/handoff-contract.md`
  and its `handoff.py`): UV layer, pages, seam-rule table, layout config, evaluator runs and the gate report under
  `qa`; a handoff that asks for the owner's review carries the live readback the contract requires.
- Record lessons at the moment they happen in the [workflow journal](../workflow-journal/SKILL.md), stage `unwrap`
  (`tooling` for tool defects).
- Keep machine checks, delivery to the owner and owner acceptance as separate facts.

## References

- [method](references/method.md): preconditions, the rule table with a worked garment example, solver settings,
  layout steps, apply, evaluation runs and traps, delivery, and the evidence run (port fidelity, head calibration).
- [gates](references/gates.md): what each gate protects, why the building gates do not apply, how to derive a
  profile from reference units; [`profiles/template_unit_body.json`](profiles/template_unit_body.json) to copy.
- [rejected methods](references/rejected-methods.md): measured trade-offs of Smart UV, ABF++, LSCM, SLIM-only, the
  automatic seam search, rectangles, stacked mirroring, stacking and pack rotation.
- [open questions](references/open-questions.md): what only the owner, a texture test or the game can answer.
- [sources](references/sources.md): literature, Blender documentation and the journal records behind the numbers.
