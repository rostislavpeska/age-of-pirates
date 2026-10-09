---
name: masonry-texturing
description: Geometry-locked stone, brick and stair masonry for game building atlases. Covers world-height courses, quoins and dressed opening surrounds, and seamless junctions across faceted or rounded corners (unrolled corner sheets, quarter-perimeter bond rings), plus stair slab bonds and weathering placed by the geometry. Also covers smooth-normal bakes and AI painting (Gemini edits with a vanilla style reference) behind a joint-registration gate. Use when stone, brick or steps look boxy, tiled, too clean or too light, when corners and edges show "creepy junctions", or when a UV-frozen model needs premium hand-painted masonry.
---

# Masonry texturing

Built on the Korean castle premium rounds of 2026-10-09 (M1-M5), where the owner moved the foundation from "creepy"
and "boxy" to "almost there". The core rule: **the geometry owns the structure (layout, joints, relief, weathering
placement); the image model only paints the surface.** Everything else follows from it.

## 1. Lay out in world space, sample per face

- Courses sit at **fixed world heights**, the same rows on every face. Give the plinth its own course up to the ledge.
- Sample the layout into one **sheet per plane** in that plane's own frame (u horizontal in-face, v = n x u, metres).
  Pack the sheets into an atlas. The bake maps every owner face onto it through the same frame, colour, normal and
  alpha alike.
- One **per-stone ID** drives tone, height, roughness and wear, so each stone keeps one identity across all maps.
- Scale: stones 0.55-1.25 m in courses of 0.44-0.60 m for castle foundations; bricks about 0.25 x 0.125 m. Each course
  holds a whole number of bricks (see 3).

## 2. Not boxy (owner: "too boxy, even the brick")

Rectangles with a bevel read as CG tiles. Break them at three scales:

- **Silhouette:** warp the joints with noise (stone about 3 cm at 0.45 m plus 8 mm at 8 cm; brick about 3.5 mm).
- **Shape:** round each unit's corners with its own radius (rounded-box distance: stone 5-15 cm, brick 0.8-2.2 cm).
- **Edges:** chip the arrises, let the joint width vary along the joint, and pillow the faces.

Joints are **thin, irregular and dark grey, never thick black outlines.** Arrises are worn and slightly lighter. Each
stone gets its own tone, plus mottling inside it.

## 3. Junctions that are continuous by construction

Painting or laying out each face separately produces doubled quoins and stepping joints, and flat facets show bands.
Never fix a junction by painting it. Make it continuous by construction:

- **Corner zone sheet:** the wall-end quoins, all facets of a rounded or chamfered corner and the next wall's start
  quoins sample ONE sheet. Its coordinate is unrolled: `s` runs round the corner and `z` is world height.
  - Per facet: `s = cumulative facet widths at that height + (u - u_left(v))`.
  - On wall A's end, `s` is negative; on wall B's start, `s = total width + t`.
  - Straight dressed beds in the zone, and 3-4 staggered stones per course.
  - Fade the walls' joint warp to zero towards the zone, so courses meet on clean lines.
  - Openings and their surrounds take precedence over the zone.
  - Details: [continuity](references/continuity.md).
- **Running bond round a tower: quarter-perimeter rings.** One sheet per ring (the wall and its corner facets).
  - Columns are normalised `x / Q(z)`, where `Q(z)` = wall width + facet widths at that height.
  - Each course holds `N = round(Q / L)` bricks; jitter their lengths and renormalise.
  - Use wrap-around noise.
  - One painting per ring, plus a 0.6 m wrap strip that is cross-faded into the start.
- **Congruent texel sharing** (member faces reading an owner's texels) needs every corner identical (C4). Both
  constructions give exactly that.
- **Ledges:** a horizontal ledge top gets its own grain, with the joints of the face below carried across it.
- **Trim bands** (cap courses, string courses, coping edges) are rings too: one course of 0.7 m dressed blocks with
  straight beds and dark joints.
- **Tops, undersides and walkways:** map every pixel onto the band face beneath (the nearest vertical ring plane, by
  depth and u-extent; try the four 90-degree rotations for congruent members). That gives `xn` along the ring and the
  depth `r`.
  - Narrow tops carry the band's head joints over the edge.
  - A walkway is paved in rows along the edge (rows about 0.5 m deep, whole slabs per quarter, half-slab offset on
    alternate rows), with dirt and moss against the inner wall.

## 4. Openings

Openings get a ring of lighter dressed stone (about 0.19 m), cut as follows:
- jamb blocks on the course lines;
- 9 voussoirs over an arch;
- a framed surround for gun slits.

Weathering runs from the openings: streaks below them and soot above (decay about 0.75 m down, 0.22 m up). Draw
openings black in AI inputs. A painted black must never reach a face: replace near-black paint with layout colour.

## 5. Steps

- One slab per step running over the nosing (the "heavy tread"). Riser and tread share the slab joints.
- **Zig-zag** (owner): a running bond up the stair. Even steps take 3 slabs, odd steps take half slabs at the ends, so
  every joint sits mid-slab on the steps above and below.
- A worn, lighter path down the centre, rounded worn nosings, dirt in the back corners and at the cheeks.
- Give hidden backs and undersides varied stone. A uniform fill fails QA as a flat island, and a step's bed-joint line
  at z = 0 paints a whole underside as joint.

## 6. Weathering placed by the geometry

Measure the vanilla targets first ([aoe3-texture-weathering](../aoe3-texture-weathering/SKILL.md): castle stone
L 106, low chroma, stain fraction about 0.13). Then place by world position:
- rising damp and soil at the foot;
- grime under cap courses;
- rain streaks from the top edges;
- pits on the low courses and at stone edges;
- moss on stone tops near the ground.

Calibrate the mean luma globally after layout.

**Sun-facing tops render far lighter than walls at the same albedo.** Paint ledges and treads at about 0.5-0.6 of the
wall value, with soil and a grainy relief normal. Judge horizontal surfaces in the render, not in the atlas numbers.

## 7. AI painting behind a gate

Read [AI paint and registration](references/ai-paint-gate.md).
- **Input:** a lit layout elevation, with openings black and margins flat grey, plus a vanilla wall crop as a second
  "style reference only" image. Gemini edits work; OpenAI masked edits through the n8n harness are disabled (INC-203).
- **Frames:** unrolled elevations only. A wall with its corner facets in u order and the plinth below it works. Packed
  fragments do not: Gemini invents windows, doors and whole walls in them.
- **Gate:** the painting's dark lines against the layout joint mask must reach F1 >= 0.5 within +-4 px. On a FAIL,
  keep the layout colours or retry once (`--allow-repeat`).
- **Compose:**
  - painted units at about 40-55 % chroma, so the set hue stays;
  - luminance normalised per frame to the calibrated layout;
  - joints and relief from the layout;
  - on every painted sheet, near-black paint falls back to layout colour; a painted black line once left 48 empty
    texels;
  - clamp soot so paint luma >= 0.45 x layout luma: 0.6 flattened the brick, none left black blotches.
- **A generated painting pasted as its own sheet (a door, a medallion) needs its own Normal and Masks.** Measure the
  painting's features (bands, studs, seams, frames), build a height model from them and derive the normal, the metallic
  mask, roughness per material and a cavity AO (`ATLAS_SURF.png` R rough, G metal, B weight; `ATLAS_AO.png`). Never
  derive relief from the painting's RGB. The QA's D8/D9 structure gates fail a painting over a flat Normal or Masks
  (owner 2026-10-09: "the doors have no normals and masks maps").
- **Paint thin rings stacked:** paint levels of a tower that are thin strips stacked in one frame, as they stand on the
  tower. That keeps them consistent; a lone thin strip came back almost unpainted.

## 8. Bake and shading

- **Smooth shading across facets:** compute smooth-by-angle (30 degree) normals on the FULL mesh and set them as
  custom normals on the owner-only bake copies. Normal maps are baked against them, and **the game mesh must carry the
  same normals**.
- **Cut-outs** (railing lattice): carry an alpha atlas, bake it as its own channel and take
  `min(eave opacity, alpha)` into BaseColor A. Cut the outer AND inner faces at the same world positions, so the hole
  is see-through; keep the pattern symmetric about the panel centre so mirrored inner frames agree.

## 9. QA traps

- Flat islands: hidden faces and dressed fills need variation (std >= 0.03).
- Pure black texels next to openings.
- Pin the stone target to the measured value. Re-check the frames byte for byte before reusing paid paintings
  (keep calibration scoped to the painted object).

## Reference implementation

The Korean castle recipes, outside AoP: `$AOP_KOREAN_REPO/research/Colonial_Expansion_17/castle_geometry_r1/recipes/`.
- `premium_m3_layout.py`: unrolled corner sheet.
- `premium_m4_layout.py`: rings, stairs, ledge.
- `premium_m5_layout.py`: railing, stair bond.
- `premium_m*_paint.py`: gate and compose.
- `texture_bake.py --sheets --smooth`.

[`scripts/masonry_lib.py`](scripts/masonry_lib.py) holds the reusable pieces (outline extents, periodic noise, ring
bond positions, rounded-box distance, registration gate) with tests. Sources from the research: [sources](references/sources.md).
