# Normal maps: source, combine, test (owner rule, 2026-09-29)

Every agent that writes, edits or reviews a Normal page follows this file. Stacking limits
(what may sit on a bake at all) stay in [texturing-qa.md](texturing-qa.md#normal-layer-stacking-rules-owner-2026-09-28);
this file says WHERE each relief comes from, HOW it is combined and HOW it is tested.

**Why it exists (Korean TC, 2026-09-29):** the plank walls on the 14 window-assembly quads carried a flat
Normal since the first final (only the BaseColor showed planks), the red window frames and the notice-board
paper were flat too. Every check passed, because none compared the albedo's structure with the relief.

## 1. Source decision table

Pick the FIRST row whose criterion holds. One detail has one source; never two sources for the same feature.

| # | Source | Use when (criterion) | Never for | Example on this building |
|---|---|---|---|---|
| a | **Bake from the high poly** (`bake_owner_maps.py` / `master_bake.py` + `derive_maps.py`) | the feature is modelled geometry, or should be (depth >= ~1 texel = 9.3 mm at 107 t/m, or a silhouette/AO role) | anything the high does not model (the bake of a flat high is flat, not "done") | members, mouldings, roof tiles, eave tiles, window lattice bars and frame, ridge rolls |
| b | **From the job's own masks / geometry** (height from the exact mask or polygon set that painted the colour, height -> normal, RNM onto the bake) | a decor job PAINTS a structural line (seam, groove, grid, frame, muntin, board edge, paper edge) that is not in the high | organic noise; features already in the bake | plank grooves on the window-assembly board walls, red frame bevels, notice-board paper edge, the `inner_grid` muntins (WINDOWS.json `relief`, 2 mm round) |
| c | **From the texture** (albedo luma -> high-pass (sigma ~ 4-8 texels) -> height -> normal) | organic micro-surface of the SAME material, no structure: wood grain, paper fibre, plaster/stone pores | structural lines (seams, joints, frames): albedo edges are shading + colour, they misplace and double lines; any class with a baked structure of another kind | grain inside one board, hanji fibre, plaster pores |
| d | **Procedural / tiled material normal** (Poly Haven maps as used for matc; Blender noise height) | a generic surface with no painted structure and no photo of its own, tiled at the measured real-world scale | anything with a readable period that the geometry or colour defines (it adds a second rhythm) | plain plaster walls, stone plinth faces, generic timber (matc) |
| e | **Photoshop** (tested COM/JSX route: `.claude/skills/photoshop-live-edit`) | a hand correction the owner asks for, or a layered artist edit on an existing page (paint out a bump, fix a seam) | batch generation, anything a script must reproduce | owner-requested fix on one element's Normal |
| f | **Substance Painter** (remote scripting, `localhost:60041`, skill `substance-painter-remote`) | many painted height details on one texture set, where SP's height channel + "Combine" mixing onto the baked normal beats scripting masks (stencils, brush height, smart masks) | single generated lines a mask job already knows; re-baking what Blender baked | a heavily carved sign board or dense ornament, if ever |

Rule of thumb: **geometry -> bake; painted structure -> its own mask; organic noise -> texture high-pass;
generic -> tiled material; hands -> Photoshop; heavy painted height -> Substance.** A mask (b) always beats an
image-derived guess (c) for the same line: it is aligned texel for texel by construction.

**Photoshop on this machine (checked 2026-09-29 from install files, not launched):** Photoshop CC 2018,
version 19.0 (`C:\Program Files\Adobe\Adobe Photoshop CC 2018`). It still ships the 3D engine
(`Required/Plug-ins/3D Engines/Photoshop3DEngine.8bi`) and the locale strings for *Filter > 3D > Generate
Normal Map...* and *Generate Bump Map...* (cs_CZ UI: "Generovat normalni mapu"). Adobe discontinued 3D in
22.5 (2021) and removed the legacy features entirely in 2024, so the menu exists here only because the install
is old; it needs OpenGL GPU drawing enabled and is untested on this PC. Its result is a luma-derived guess
(= row c with less control) and not scriptable reproducibly: do not use it for generation.

## 2. Combine rules

1. **The bake is the base, always.** Every added relief goes on with **Reoriented Normal Mapping** (RNM,
   Barre-Brisebois & Hill) onto the baked normal. Never overwrite, average, overlay or linear-add baked
   relief; SP "Replace" mixing is forbidden on baked classes (use "Combine").
2. **Convention:** tangent space = the page Normal: **OpenGL +Y, +x = +U, +y = +V** (rows bottom-up),
   measured on the lattice bake (WINDOWS.json `relief.note`). Any imported map (Poly Haven "_gl" vs "_dx",
   SP export preset, Photoshop) is sign-checked against the bake before use (test 4). Store 16-bit PNG, unit
   vectors, renormalise after every blend.
3. **Scope masks per element:** each relief layer carries the mask of the element/class it belongs to
   (ClassID or the decor layer's own `within` region). Height is generated INSIDE the mask and the
   height->normal gradient is taken with the mask edge clamped, so no slope is created at a boundary.
4. **No relief across a material or element boundary:** grooves stop at the window block, window relief
   stays in the window cells, a frame bevel does not print onto the wall. A boundary gets relief only from
   the bake.
5. **Amplitude (107 texels/m, 1 texel = 9.3 mm; slope = height / run):**

   | Class | Height | Profile | Note |
   |---|---|---|---|
   | plank grooves / board seams | 2-4 mm | V or round, 1-2 texels wide | reads at RTS distance; > 5 mm competes with the members |
   | window/door frame bevels | 2-4 mm | 1 texel chamfer | inside the frame only |
   | muntins (painted) | 1.5-2 mm | round, flat crest + 1 shoulder | measured: 2 mm reads, 1.5 mm faint (WINDOWS.json) |
   | paper / board edges | 0.5-1.5 mm | step | notice board, hanji edges |
   | wood grain, paper fibre, pores (row c/d) | 0.2-0.6 mm | noise | max ~ 1/3 of the class's structural relief |
   | tiled generic material (row d) | 0.3-1 mm | as shipped, scaled | strength set by measured slope, not by eye |

## 3. Test spec: whole-model normal audit

Runs on the final Normal page(s) with ClassID, the decor layer masks, the bake-only Normal and the BaseColor.
Complements the other agent's `relief_missing_check` / `relief_drop_check` in `qa_detectors.py` (use them as
building blocks, do not duplicate). Report per class and per element; any FAIL blocks the owner handover.

| # | Test | Measure | Criterion | Would have caught today |
|---|---|---|---|---|
| 1 | **Coverage** | per visible class: rms slope of the final Normal (tilt from the class's mean normal), and the albedo's high-pass structure energy on the same texels | FAIL when a class has rms slope < 0.01 (flat) unless the recipe waives it by owner name; FAIL when albedo structure energy is high (lines/edges above its class median x 2) and the normal gradient at those texels is < 20 % of the class's relief elsewhere ("painted but not relieved") | the 14 flat plank walls, flat red frames, flat notice paper |
| 2 | **No overlap** | for each relief layer, slope energy outside its own element mask (dilated 1 texel) vs inside; and per class, count distinct relief sources present | FAIL when > 2 % of a layer's slope energy lies outside its mask, or a class shows two structural sources (e.g. plank grooves inside window cells, muntin relief on the board wall) | planks + windows printed over each other; grooves running into the window block |
| 3 | **Alignment** | high-passed normalised cross-correlation between the albedo's structural edges (seams, frames) and the relief's gradient magnitude, +-6 texels | FAIL when the best offset > 1 texel or best corr < 0.3 on classes with structural relief | a groove shifted off the painted seam; a line from a different layout |
| 4 | **Convention sign** | per imported/added layer: correlation of its X and Y components with the bake's X and Y over a shared feature (bevel, bar edge) | FAIL when either axis correlates negatively (green or red flipped) or |corr| < 0.3 | a DirectX Poly Haven map or SP export reading as inverted relief |
| 5 | **Amplitude range** | per class: 95th percentile slope converted to mm over the profile width | FAIL outside the section 2 table (+-30 %); FAIL when organic noise > 1/3 of structural relief | grain louder than the grooves; a 10 mm groove out-shouting members |
| 6 | **UV seam continuity** | along every 3D edge between charts on a relief class, sample the Normal transformed to object space from both sides | FAIL when the mean angular jump > 10 deg or a groove/line ends at the seam on one side only | grooves that stop at a chart seam mid-wall |
| 7 | **DDT / mip survival** | encode the page exactly as shipped (DDT format and mips of the export pipeline), decode, and repeat tests 1 and 5 at mip 0 and at the mip the RTS camera samples (texel-to-pixel ratio from the fixed RTS shot, typically mip 1-2) | FAIL when a class's structural slope energy drops below 50 % of mip 0 pre-compression, or the class becomes flat by test 1 | 1.5 mm muntins or 0.5 mm paper edges that vanish in game |

Every test writes numbers per class to the QA report and a Normal-only crop (nearest x4, UV edges overlaid)
for each FAIL; visual review then happens on the live review scene, never on the table alone.

## 4. Checklist for every job that touches Normal

1. Name the source row (a-f) for each detail you add and why the earlier rows do not apply.
2. Build relief from the SAME masks/geometry that painted the colour; scope each layer to its element mask.
3. RNM onto the bake only; OpenGL +Y, +U/+V; 16-bit; sign-check every imported map against the bake.
4. Amplitude from the table in mm, measured after the blend, not set by eye.
5. Run the normal audit (coverage, no overlap, alignment, sign, amplitude, seams, DDT/mip) and hand over only
   on PASS or an owner waiver.

## Sources

- Barre-Brisebois & Hill, *Blending in Detail* (RNM): https://blog.selfshadow.com/publications/blending-in-detail/
- Polycount wiki, *Normal Map Technical Details* (channels, tangent basis, flips): http://wiki.polycount.com/wiki/Normal_Map_Technical_Details
- Polycount wiki, *Normal Map Compression* (block compression artefacts, swizzles): http://wiki.polycount.com/wiki/Normal_Map_Compression
- Adobe, *Substance 3D Painter - Texture Set settings* (Normal mixing Combine/Replace, height-to-normal): https://experienceleague.adobe.com/en/docs/substance-3d-painter/using/interface/texture-set/texture-set-settings
- Adobe, *Substance 3D Painter - Height Map Painting*: https://experienceleague.adobe.com/en/docs/substance-3d-painter/using/painting/advanced-channel-painting/height-map-painting
- Adobe Community, *Photoshop 3D features are being removed* (22.5 discontinuation, Generate Normal Map): https://community.adobe.com/t5/photoshop-ecosystem-discussions/generating-normal-maps-and-bump-maps-are-being-discontinued/td-p/12429364
