# Korean roof textures: copy the Town Center, do not re-derive it

Owner, 2026-10-10: "Forensic inspection why each roof costs 300 USD operator time!!! And how to cut the cost so you know
what to do!!! What you are presenting me still looks CHEAP AND BORING AND THE QUALITY IS MANY LEVELS BELOW THE FINAL TOWN
CENTER". Earlier the same day: "It's only shading. Nothing else... Simple. Study the Town Center", "check the last TC
version", "check TC roof ridges".

## Why roofs cost ~$300 each (forensic, 2026-10-10)

| Roof | Rounds | Note |
| --- | --- | --- |
| TC (the bar) | Painter r46-r58 (12 projects), r60 roof Painter, recipes r70d/e/f | TC session audit: $2,366 for ~6 accepted items = ~$390 per item (`Claude_CP2/PROCESS_HARDENING_PLAN.md`) |
| House | r14, r15, r15b-h (8 roof rounds in one day) | most rounds chased "look like the TC" |
| Castle | pilot, assembly, HIGH r1/r2/r2b, premium M1-M7, then C9 / C12 / C13-C15 on 2026-10-10 | C9 plaid (wrong axis), C12 "boring" |

Causes, largest first:
1. **Re-deriving the TC look per building** (procedural shading, moss and grain, Painter rounds) instead of reusing the
   TC's finished texels.
2. **Misreading the reference.**
   - The wrong axis: rolls taken for courses.
   - Half the reference: the TC keeps its second tile fields, every cap strip and the eave disc rows on **matb**, not mata.
   - Grey stand-in materials in reference renders; unequal light.
3. **Statistics accepted as appearance.** Matched tile std, fine std and moss % still looked flat.
4. **The full pipeline before a mock** (bake, compose, DDT, install), so every rejection cost a whole cycle.
5. **Process overhead.** Relaunched workflows, default-reject reviews, long contexts ($811 + $777 + $947 in the TC audit).

## What to do (the cheap path, ~$20-40 a roof)

1. **The reference is the INSTALLED TC: its gr2 and all of its DDTs.**
   - Sha-check the DDTs against the version folder.
   - Load the gr2 with AoP `scripts/havok/gr2_lint.py` (`load`, `display`).
   - Render it under the same light and camera as the candidate, with mata, matb and the shared matc all bound.
2. **Find a feature's TC texels with a UV-readout render.** Emission = (u, v, material id) from the same camera; read the
   pixels on the feature. This is how the TC caps were found on matb.
3. **Read the axes from the normal map, never from a luminance period.** The rhythm whose period matches the cross-roll
   normal component is the roll (TC: 28.65 px; courses 31.6 px).
4. **Copy the TC texels by tile coordinates.**
   - Field: course phase along the slope, plus crown / edge / pan position across the roll, from the target bake's EMIT
     (tone, phase, roll). A cover cell or a pan cell of the TC is chosen by a hash of the tile tone.
   - Caps: position along the cap, plus 0..1 across it, from the TC's cap strip (four whole segments, wrapped).
   - Scale by the texel-density ratio, so every feature keeps the TC's physical size.
   - Then run the TC overlay recipe (r70 `recipe_roof.py`, moss / streaks / chips) with its moss target tuned to the
     TC's ~5 % share.
   - Castle implementation (Korean repo, `castle_geometry_r1/recipes/roof_tc/`): `castle_roof_tc_transfer.py`,
     `castle_roof_caps_tc.py`, `castle_roof_compose.py`, `castle_roof_kit.py --feat`.
5. **One mock before anything is installed.** Pictures TC | current | candidate, plus the live Blender scene, then the
   owner's yes. One rejected round means stop and ask; no third blind round.
6. **Numbers gate defects only** (alpha speckle D10, relief D8, masks D9, density, budget). The look is judged side by
   side against the TC.
