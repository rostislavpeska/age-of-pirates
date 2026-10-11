---
name: texture-corner-seams
description: Monitor and repair texture seams at a model's corners - every geometric edge where two faces meet on different UV islands or pages. Inventories the seams in background Blender, measures the colour step across each one against the same step inside the faces, classes it ok / tone / pattern / boundary, renders the worst as unfolded strips, and blends tone seams on texels that one face (or one UV family) owns. Use after any texture compose or paint chain on an atlas building, when corners show a crack, a tone jump or unrelated patterns meeting, or as a release gate for seam quality.
---

# Texture corner seams

Owner 2026-10-11 (Korean Market): "add texture corners separately and corner texture seams monitoring and edit". A UV
seam on a geometric corner is where the two faces' texels stop being neighbours. Every per-face paint step can open a
visible step there:
- a tone shift from per-face tone variation, a facing-dependent bake or a per-face grade;
- a pattern break, where each face is painted in its own frame.

Treat corners as their own deliverable: monitor them all, fix what a blend can fix, and send pattern breaks back to the
layout.

## 1. Inventory (background Blender, read-only)

[`scripts/seam_inventory.py`](scripts/seam_inventory.py) lists every manifold edge whose two faces meet on different UV
positions or pages. For each edge it records:
- both sides' page px and the 3D edge;
- the dihedral angle;
- each face's role, paint subtype and material slot;
- every face's page polygon, used for texel ownership.

Pages come from a face attribute (Market: `uv_resource_r2`, `0=2048,5=1024`); unlisted pages (shared hidden backing) are
ignored.

## 2. Monitor (host Python)

[`scripts/seam_monitor.py`](scripts/seam_monitor.py) `monitor` samples both sides of every seam, bilinear, 1 and 3 texels
inside their own face, opaque texels only, endpoints skipped:
- **across**: the colour step over the seam;
- **within**: the same 2-texel step inside the faces;
- **ratio** = across / within;
- **tone**: the step of the along-edge means.

| Class | Rule | Action |
| --- | --- | --- |
| ok | ratio ≤ 1.5, or step < .03 | none |
| tone | mostly a mean shift (tone ≥ .5 × across) | blend (`edit`) |
| pattern | unrelated structure | fix the layout: one frame across the corner (unrolled corner sheet, [masonry-texturing](../masonry-texturing/SKILL.md); folded slab, [alpha-cutout-texturing](../alpha-cutout-texturing/SKILL.md)) |
| boundary | the sides differ in paint subtype, material, or texel class (`--classes`, e.g. a baked ROLE map) | intended (ridge against tile field); not scored |

Score = metres × (ratio − 1), × 1.5 on near-coplanar seams (dihedral < 30°), where a step reads as a crack.
`SEAM_STRIPS.png` unfolds the worst seams: side A's last 8 texels above side B's first 8, as a viewer crosses the corner.
Read the strips before deciding anything. On the Market, the worst-scored list was first led by hip bands and plinth tops
that belong to other recipes.

## 3. Edit (tone seams only)

`edit` pulls each side towards the pair's along-edge mean:
- smoothed along the edge, |Δ| ≤ .15;
- in a band of 6 texels with linear falloff, plus 2 gutter texels;
- tapered at the edge ends.

Rules:
- **Ownership:** a texel is edited only when it is covered by one face, or by one UV family whose members all repeat the
  same texture seam (identical page px). That seam is edited once for every member. A texel covered by more faces than
  that is never touched (asserted).
- **Subtypes:** `--edit-subtypes` limits the edit to surfaces whose continuity belongs to this step. Report-only
  surfaces keep their own recipes: masonry rings, the shared roof canon, folded thatch, gated sheets.
- **No regressions:** a seam the blend makes worse (overlapping bands on narrow faces) is rejected and the pass redone.
  The run fails if any edited seam still ends worse.
- **Idempotent chains:** snapshot the pre-edit pages and restore them at the start of every step that runs before the
  edit when the final still holds the last edit. A downstream sha guard otherwise sees edited input (Market: the panel
  compose guard).

A blend fixes tone, not structure. After the edit, some tone seams correctly re-class as pattern. Send those to the
layout.

## 4. Market result (2026-10-11, UV r7c, 685 objects)

- **Inventory:** 2,830 seam edges, 650 m judged.
- **Before:** ok 380 m, tone 218 m, pattern 48 m.
- **Edit:** subtypes plaster, timber, boards, player, hanji, lattice, iron, wet wood, rope, cloth, onggi, brass, silk,
  paper, fresh wood; 347 seams blended, 347 improved, 6 rejected, 0 worse.
- **After:** tone 145 m; score 801 → 667.
- **Reported to their recipes:**
  - Post plinths (family island): grey top against beige chamfer, ratio 11.8. Masonry recipe.
  - One-sided dark hip bands on hip fields. Roof canon.

## Run

```bash
blender -b MODEL.blend --python scripts/seam_inventory.py -- --out SEAMS_INV.json --pages 0=2048,5=1024 --collection "<LOW>"
python scripts/seam_monitor.py monitor --inventory SEAMS_INV.json --pages 0=P0_BaseColor.png,5=P5_BaseColor.png --out DIR [--classes 0=ROLE0.npy,5=ROLE5.npy]
python scripts/seam_monitor.py edit --inventory SEAMS_INV.json --pages ... --classes ... --edit-subtypes 0,2,3 --out-pages OUT
```

Run the fixtures from `scripts/`: `python -m unittest test_seam_monitor -v`. They cover matching (ok), darker face
(tone, fixed inside the bands only), unrelated stripes (pattern, untouched), a texel shared beyond its group (untouched),
the subtype filter and boundary.
