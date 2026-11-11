# Engine formula and vanilla evidence

Measured 2026-09-29 on the installed AoE3 DE build (Age of Pirates research workflow; journal record
`2026-09-29-claude-89`). Status: **measured** by shader disassembly and decoding the vanilla textures; in-game
confirmation of a new Details map is still owed.

## Shader

- All building materialdefs use `material/materialdefault.hlsl`. The Details slot is
  `<texture default="black" name="Details" />`: optional, no srgb flag (linear data), black when absent.
- Base pass (default, cutout, doublesided, doublesided_cutout, destructible*, alphatocoverage, parallax, forward):
  `sample r0.w, v7.xy, t3.yzwx` (Details.R) -> `mad r2.xyz, r0.xyz, cb5[idx].xyz, -r0.xyz` ->
  `mad r0.xyz, r0.wwww, r2.xyz, r0.xyz`, which is `lerp(base, base * PC, Details.R)`.
  BaseColor is sampled sRGB-to-linear (`srgb="true"`); the result is gamma-encoded into the G-buffer.
- Player colour = `cPlayerColors[instance.playerColorIndex * 3 + int(pixelxformColor)]`. `pixelxformColor` defaults
  to 0 and none of the 7650 vanilla .material files overrides it, so 0 = the main player colour.
- `default_emissive` reads Details.RG: emissive = albedo * Details.G * EmissiveIntensity (signal fire, campfire).
  The weathered DETAIL_MAP variant uses RGB for weathering; TERRAIN_MASK reads A. Neither concerns building paint.
- All four textures sample `v7.xy`: Details has no UV set of its own (UV0).
- For comparison, Masks = R AO, G roughness, B metallic.

Reproduce: extract `Render/materialdefs/default.materialdef` (use `bartool cat`: a flat extraction overwrote it with
`granny_legacy/default.materialdef`, which has no Details slot) and disassemble
`RenderCachematerialdefault_PSMain_ps_*.hlslc` with `D3DDisassemble` from d3dcompiler_47.

## Vanilla Details files (census of all 529 `art/buildings/**/*_Details.ddt`)

| property | count |
| --- | --- |
| fmt 4 DXT1, alpha 0 | 455 |
| fmt 5 DXT1 with 1-bit alpha | 73 |
| same resolution as its BaseColor | 526 of 526 pairs |
| R-only (G = B = 0) | 464; 13 older grey R=G=B, 4 G-only emissive, 4 empty, 43 mixed |

Mipmaps: the full chain (10 at 2048, 9 at 1024), with the same header as the BaseColor (`'RTS3',0,0,4,10`).
Mask shape: 85-90 % of the covered texels are 255 (hard); the rest is an anti-aliased edge.
Material usage: Details appears in 2039 default, 1621 default_doublesided_cutout, 392 destructible, 232
default_doublesided, 146 default_cutout and 35 default_emissive submaterials. Damaged materials repeat the intact
Details on their destructible submaterial (`china_towncenter_age2_damaged.material`, mata).

## BaseColor under the mask in vanilla

BaseColor inside Details.R > 200:

| texture | coverage | mean sRGB under the mask | saturation |
| --- | --- | --- | --- |
| china_towncenter_age2 mata | 2.6 % trims and rails | 254.7 grey | 0.00 |
| japan_towncenter_age2 matA | 2.8 % stripes on plaster | 232.6, 231.0, 231.7 | 0.01 |
| east_tc_age2 mata | 7.5 % roof edges and gable boards | 252.7 grey | 0.00 |
| west_barracks_age2 matA | 2.5 % | 253.6, 253.3, 253.0 | 0.00 |
| castle_regicide matA | 11.2 % whole wall and lattice panels | 158.4, 158.1, 151.3, dirt kept | 0.10 |

Outside the mask the same BaseColors are saturated (0.29-0.58). Vanilla therefore desaturates and lightens the paint
before masking it. castle_regicide is the one mid-grey precedent: its hue is true, but the player colour is darker.
The skill's rule flags such a base as LIGHTEN (luma < 200); keeping it is a deliberate owner choice.
