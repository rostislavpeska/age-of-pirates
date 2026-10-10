---
name: prop-atlas
description: Put many small objects (props - barrels, crates, carts, baskets, jars, ropes, tools) of a building set on ONE shared UV page and texture them consistently - props-only page with every prop face on it, architecture texel-density rules (universal floor + one uniform density), charts planned from the generating primitives (grain, boards), one repack, AI-painted sheets at one metric scale, material-aware gates and a coverage gate. Use when props or other small objects share an atlas, when props look low-res, smeared, blotchy or inconsistent next to each other, when a props page has wasted space or foreign charts, or when asked "how do we handle props on UV maps".
---

# Props on one UV page

Built on the Korean Market/Dock props page, 2026-10-10. The owner's rounds, in order: "ours are too low res", "more
custom GPT or Gemini generated textures", "some objects like ropes have very bad quality ... use the 2048 prop texture
map CONSISTENTLY", "I want single map and all props on it", "Lot of wasted space ... Can you use the whole map?",
"check prop texel density and define minimum", "the density varies a lot - props are objects like architecture - treat
them like that".

## 1. One page, props only, every prop face on it

- **Props only.** Building parts that crept onto the props page (a stall roof and bins: 41 % of the used area, never
  baked by the props chain) move to their building's own page, each island rescaled to that page's density and
  contact-packed into its free space (split an island into faces before lowering
  density, and report every reduction).
- **Every face of a prop on the page** (one material per prop). Faces no camera reaches are **stacked on the prop's own
  largest chart** at >= 100 t/u: no page space, and the universal floor counts a stack once. A separate grey patch failed:
  the hidden faces of a flat prop are half its area, so at 60 t/u its median fell below 90 (crate, straw mat), and no
  free square was left for a 100 t/u patch.
- **Placed copies are instances** of the catalog meshes (shared mesh data): every UV change on the catalog reaches every
  placement. Find a representative object per MESH, and exclude every mesh any catalog object or instance uses when moving
  "non-prop" pieces (a lookup by object name once moved 266 prop islands to the building page).

## 2. Density: props are architecture

- The **universal floor** of [blender-architecture-texturing](../blender-architecture-texturing/references/uv-density-floor.md)
  applies to every prop as a model and to the page (`density_floor.py faces FACES.npz --model PROP`): median >= 90 t/u,
  <= 2 % of the area below 54 t/u, collapsed <= 3 %. Hidden faces count.
- **One uniform density** for every visible chart of the page (one uniform pack scale; check p05/p95 within ~10 %).
  Korean props page: 299 t/u median at 2048, p05 299, p95 331, every prop PASS. Small objects get more density than the
  buildings (101 t/u) because the camera sees them up close in the same pixels; the rule is uniformity, not equality.
- **Painted detail has a density too.** Sheets fitted one per prop came out at 288-2200 px/m, so grain, nails and weave
  were painted at a different metric size on every prop. Paint every prop at ONE sheet scale (Korean: 560 px/m, about
  2x the page) and spread big props over several sheets (a cart: 5 sheets; 34 sheets for 28 props).
- Upscaling the final page never raises density (texel floor rule). Raise the page, repack, or move foreign charts out.

## 3. Charts planned from the primitives

Props are built from a few generators (lathe, torus, box, beam, prism, slab). Record the primitive per part at build
time, or rebuild the catalog in a scratch kit and match each part vertex for vertex (124/124 matched), then unwrap
analytically - never generic LSCM, never the building's role-switch bake:

| Primitive | Chart | Grain (u) | Boards / joints |
| --- | --- | --- | --- |
| torus (hoop, tyre, rim, rope coil) | one strip; seams underneath/behind and on the tube's inner side | around the ring | - |
| lathe (keg, jar, hub, barrel, shot) | side bands unrolled, v centred; faces square to the axis planar | along the profile | staves = segments (grain v at a reference radius so staves are straight) |
| box / beam / prism / slab | four sides wrapped, the long axis (beam run, prism extrusion) = u; ends planar | along the run | ~11 cm boards per face; ends ~10 cm |

Write the grain coordinates (metres) as their own UV layer and the board lines per chart: the bake's source frame and
every painter read them, so direction is planned, not measured (a PCA "member axis" is meaningless on rings and turned
parts: a rope coil smeared into blotches). Identical parts of a prop (same primitive, topology and face sizes by index)
share one owner chart.

## 4. Pack once, fill the page

- Pack every owner chart of the page at one uniform scale (Blender `pack_islands`, CONCAVE, cardinal rotations only so
  the grain stays on u or v), gap = the runtime gutter **at the page size** (4 texels at 2048, not 4 at 1024).
- Members follow their owner by **family id + exact UV polygon** (copied UVs, maybe loop-shifted), then containment.
- Adding charts into an existing layout's gaps fails when the free space is fragmented (largest free square ~70 texels:
  65 splits, 13 density cuts, 8 failures): repack the page once.

## 5. Texture: AI-painted sheets, gated

Method and gates: [image-harness](../image-harness/SKILL.md) "Paint a model's textures from its UV layout" and
[masonry-texturing](../masonry-texturing/SKILL.md) section 7. For props:

- **Layout sheet per prop** in grain space, laid out like a vanilla prop atlas (staves side by side, heads as discs, long
  strips as rows split on their LONGER axis), with lit vanilla-measured colours per material and the details the paint
  must carry (rivets, nail heads, bung hole, rope twist, straw weave, end-grain rings).
- **Style reference: a small material crop**, not a whole vanilla atlas - Gemini copied a native-crates atlas's stake
  layout into a firewood sheet (IoU 0.33). Add "paint over the FIRST image in place, never move, add or remove a shape".
- **Gate per material:** silhouette IoU >= 0.90 for every sheet; joint recall >= 0.70 over BOARD joints only (chart
  outlines of cloth, silk or cords are frayed or light, recall 0.03-0.67 on correct paintings); masonry keeps the joint F1.
- **Compose** toward the measured vanilla luma per material (wood .23, straw .37, cloth .58, paper .70, brass .50, onggi
  .24, iron .20 sRGB), chroma ~0.85.
- **Generators** from the bake's EDGE (bevel convexity) and CAV (short AO): wood/clay/stone chipped edges, iron bright
  edges + rust in crevices, brass burnished edges, soft materials (rope, straw, cloth, paper) dirt only. Dry stores (powder,
  shot) get no moss.
- **Coverage gate:** every chart of the page received a gated painting; the report lists any that did not.

## 6. Pitfalls (measured)

| Symptom | Cause | Fix |
| --- | --- | --- |
| hanji bundle with brown stripes | building bake source = a 25x44 px window-paper crop with a lattice bar | painted sheet per prop |
| rope coil blotchy | 260x35 px timber crop + PCA grain on a ring | torus chart + grain layer + painting |
| black half of the page | building parts on the props page, unbaked by the props chain | move them to their own page |
| grey washed painting | compose normalised to a dark layout mean, chroma 0.6 | vanilla luma target, chroma 0.85 |
| correct paintings rejected | joint F1 on grain-rich wood; outlines counted as joints | IoU + board-joint recall |

## Reference implementation (outside AoP)

Korean props: `korean-market-dock/recipes/` - `props_consulate_uv.py` (primitives, charts, grain, families),
`props_page_cleanup.py` (props-only page, stacked hidden faces), `props_r3_repack.py`, `props_density_export.py` (floor
input), `props_ai_sheet.py` (layout, gates, compose), `props_ai_paint.py` (driver), `props_sheet_apply.py` (map back,
relief, generators, coverage).
