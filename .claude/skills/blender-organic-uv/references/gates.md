# The organic UV gate

`scripts/uv_gates.py` checks evaluator runs against a **gate profile measured on the consuming game's shipped units**.
The numbers belong to the game layer, never to this package: this page says what each gate protects, how to read it
and how to derive the limits. [`profiles/template_unit_body.json`](../profiles/template_unit_body.json) lists the
checks with their metric paths and runs; a game layer copies it and fills the limits. A hard FAIL or a missing metric
(status MISSING) fails the gate; a missed target is reported. Numbers compare at full precision: no tolerance.

## What each gate protects

| Check (run) | Metric | Protects against | How the reference sets it |
| --- | --- | --- | --- |
| Flipped faces, folds, unintended overlap, mirrored islands, stacked mirror texels (page) | `flips.*`, `overlaps.*` | paint landing on two places, broken tangents, AO doubled | 0, always |
| Min island gap, page border (page) | `packing.min_island_gap_px`, `min_page_border_px` | colour bleeding across islands at the mips the game samples | the reference gutters; the mip at which gaps vanish (`gutter_vanish_mip`) is the readable form |
| L2 / Linf stretch (page) | `distortion.L2_stretch`, `Linf_stretch` | blurred or smeared texels | at or just past the reference body; read each island's own stretch when priorities are on |
| Angle stretch mean / p90 (page) | `distortion.angular_aniso_*` | shear: a painted circle turning into an ellipse | the reference range |
| Density p50 / visible-weighted p10 (page) | `texel_density.all.p50`, `visible_weighted.p10` | wasted page, soft visible areas | the reference body on the same page size |
| Coverage (page) | `packing.coverage_texels` | an empty page | the reference range |
| GPU vertices over every UV layer (page) | `counts.gpu_vertices_all_uv_layers` | a vertex budget broken by UV splits or a forgotten placeholder layer | the model contract's ceiling |
| Upright share (page) | `orientation.upright_share_15deg` | sideways islands that slow painting by hand or by an image model | the reference share as the floor; the recipe reaches 100 % |
| Left/right density asymmetry (page) | `symmetry.density_log2_asym_mean` | mirror-copy painting going wrong | the reference body (near 0) |
| Seam per sqrt(area), visible seam per sqrt(area) (body) | `seams.seam_per_sqrt_area`, `visible_mean_per_sqrt_area` | seams where the camera sees them | the reference body's own page, posed and seen like ours |
| UV split ratio (body) | `counts.uv_split_ratio` | vertex cost of the seams | the reference body |
| Body islands, tiny islands (body) | `islands.count`, `tiny_count` | scattered pages | the reference range |
| Head/torso, bone regions (body) | `bone_regions.head_torso` (+ `head_torso_visible`) | a head painted at body resolution | the project's decision, read on the same estimator as the reference ratios |

The body run is the fair comparison for seams, splits, islands and the head ratio: a reference body usually owns its
page, while our page also carries a skinned weapon.

## Why the building gates do not apply

Measured on an organic rider on 2026-10-11 with the hard-surface tools unchanged:

- A universal density floor set for buildings (tens of texels per unit) passes trivially at unit densities (hundreds).
- Islands per 100 square units misfires on a 4 square-unit body (285 for 12 islands, against a building ceiling of
  200).
- The smooth-patch coherence check (one smooth patch = one island) flags most planned garment seams, because on a
  smooth body every seam crosses a smooth patch (45 of 189 patches). The declared seam-rule table is the organic
  coherence unit instead.
- Per-object overlap checks miss meshes that share a page: run the gate on every mesh of the page together.

## Deriving a profile for a game, page size or unit class

1. Extract the reference units into a scratch folder (never into a repository) and import each body into a scratch
   `.blend` with the game layer's importer, keeping its UVs and weights.
2. Run `uv_eval.py` on each reference body alone, posed and seen like your own units (same pose clip, pitch, headings,
   culling); at least the static numbers for bodies without a pose.
3. Set each hard limit at the worst value among the reference bodies that represent the class, or just past the
   best-known body where the class is wide; set targets from a measured candidate, not from wishes. Keep the
   zero-defect checks at 0.
4. Record the date, the models, the estimator rules, the pose and the build in `derived_from`, and an evidence string
   on every check. A number changes only with new measurements, never to let a model pass.

## The evidence rider against its game's profile (2026-10-11)

The H1 recipe on a 1124-triangle body + 146-triangle skinned weapon (one 1024 page) passed every hard limit of its
game's unit-body profile. Missed targets: the visible-weighted density p10 (345 against 350 t/m) and the head ratio
on the bone-region estimator (1.119; 1.271 on visible faces only). Its numbers are in [method](method.md), section 8.
