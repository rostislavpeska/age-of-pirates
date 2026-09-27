---
name: blender-uv-conjoin
description: Aggressive UV conjoinment for game assets - merge charts of the same material with similar dimensions and outline onto shared texels, then repack the atlas tightly at fixed density. Route by asset class (architecture heavy, hard-surface light, organic none). T3 is the default for buildings, T2 the fallback, exact containment the fallback for sensitive areas. Use when a texture atlas wastes space, when asked to "conjoin", stack, merge or reuse UV islands, or to shrink an atlas budget.
---

# UV conjoinment (merge similar charts, then repack)

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
matching refuses to merge. The owner chose T3 because the result resembles vanilla
AoE texturing (shared generic strips, stretched to fit). Read
[lessons](references/lessons.md) before changing the rule.

## Route by asset class first

| Asset class | Conjoinment | Method |
| --- | --- | --- |
| Architecture (buildings, walls, gates) | Heavy: roofs, walls, beams, trims repeat | **T3** default; **T2** fallback when stretch shows; exact containment (`labeled_fit.py`) for sensitive areas |
| Hard surface (tanks, warships, cannons, carts) | Light: only true repeats (wheels, barrels, planks, rivet strips) | **T1**, or exact containment; most charts stay unique - these objects are smaller and less boxy |
| Organic (humans, animals, trees, cloth) | None | Do not conjoin. Blender auto-unwrap (Smart UV Project / Minimum Stretch) plus a plain pack works best |

Sensitive areas inside architecture - signs, lettering, asymmetric ornament, faces
that must carry unique baked contact shading (AO), mirrored normal-map detail - are
marked `protect: true` so they stay unique, or are shared only by exact containment.

## Workflow

1. **Clean charts first.** Run [blender-clean-uv](../blender-clean-uv/SKILL.md):
   coherent charts, no scattered single faces on visible surfaces. Conjoinment
   merges whole charts; it cannot repair fragmentation.
2. **Export** (inside Blender): `scripts/blender_export_faces.py` - charts are real UV
   islands (or an INT chart attribute), each rescaled to one target density.
   Exclude hidden-material pages (they already share low-density cells).
3. **Conjoin** (host Python, numpy + shapely):
   `python scripts/conjoin.py faces.json plan.json --preset T3 --gutter 16`.
   Gutter is in working texels (16 at 8192 = 4 at 2048, DXT block safe).
   Hollow charts (frames, rings, ladders) are split into straight members first -
   this is the default; never pass `--no-split-hollow` for architecture.
   `--trim WOOD` shares all wood strips on a few width-class trim strips (optional;
   on the Korean TC it cut families 82 -> 60 but not the page).
4. **Space gate - mandatory.** conjoin.py prints `AUDIT PASS/FAIL` and exits 2 on FAIL.
   Never show the owner a FAIL result. Read the top consumers, fix the cause, rerun.
   Then look at the UV sheet image yourself: large grey (unshared) or hollow blocks
   mean the rule did not apply - that is a failure even if numbers look acceptable.

   | Gate (default) | Catches |
   | --- | --- |
   | hollow charts <= 10% of owner rectangles | whole timber frames kept as one chart (incident: 68%) |
   | unshared charts <= 45% | conjoinment silently not applying |
   | packing efficiency >= 45% | empty page / oversized rectangles |
   | one chart <= 25% of page | a giant composite chart |
   | `--min-runtime-density N` | blurry texture: reports texels/unit on the runtime page |
5. **Apply** (inside Blender): `scripts/blender_apply_conjoin.py` copies the objects
   into a new review scene (sources untouched), writes a real UV layer and flat family
   colours: same colour = same texels, grey = unique, black = hidden pages.
6. **Show** the owner two things, nothing else first:
   `scripts/draw_uv_sheet.py` (before/after UV map at the same texel scale) and
   `scripts/render_review.py` (colour-by-family model, 4 sides, background Blender).
   Live viewport captures can be stale; render in the background instead.
7. **Report numbers that mean space:** page side at fixed density with the same
   packer and gutter before/after, owners, member density change (mean/max). Never
   report freed member area as savings.

## Rules that hold regardless of preset

- **Never change owner chart size.** Output UVs at the ORIGINAL page scale
  (`--page 8192`): owners keep their exact original UV size, the freed space stays
  empty, and the owner decides later whether to shrink the page. Do not rescale the
  result to fill 0-1 and do not normalise chart density (the exporter's default).
  Both were an owner-reported drift (2026-09-28): they silently raised texel density.

- Same material only; never merge across material IDs (wood onto plaster, window onto wall).
- Whole charts are the unit; do not cut charts into scraps to raise the merge count.
- Rect-to-rect mapping changes member texel density by the axis scale factors;
  report it. T3 allows up to about 67% stretch on one axis by construction.
- Owners are packed tightly; the packer (`pack_rects.py`, MaxRects best-short-side)
  hits known optima on its controls. Blender's pack_islands failed those controls
  (10% worse on 16 squares; exact-shape mode hung) - do not use it for measurement.
- Geometry-only: AO bakes need one owner bake per family; unique contact shading is
  a reason to protect, not to un-merge everything.
- Mirrored merges (flips) assume the engine handles mirrored tangent space; for
  normal-mapped detail verify before relying on it.

## Tools

- `scripts/conjoin.py` - merge + repack library/CLI, presets T1/T2/T3.
- `scripts/audit.py` - hollow-chart split and the space gate (PASS/FAIL, runtime texels/unit).
- `scripts/pack_rects.py` - validated packer and page-side measurement (self-test: run it).
- `scripts/labeled_fit.py` - exact directed-Hausdorff containment (fallback #2): certified
  rigid fits, labels for material, grain/up direction and semantic tags.
- `scripts/blender_export_faces.py`, `scripts/blender_apply_conjoin.py`,
  `scripts/render_review.py`, `scripts/draw_uv_sheet.py` - Blender round trip and review.
- `python -m unittest test_conjoin` from `scripts/` (includes the frame-incident regression tests).
