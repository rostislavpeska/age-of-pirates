# Unit materials and texture sets

Measured 2026-10-10 on vanilla rider, horse and attachment files (method in
[vanilla unit measurements](vanilla-unit-measurements.md)) unless a line says otherwise. Scripts: `.material` pages
and DDT headers `scripts/texture_pages.py material|ddt`, Details coverage `texture_pages.py details`, UV area, texel
density and mirrored UVs `scripts/shape_metrics.py --what uv`, tangents `scripts/tangent_compare.py`. Lines marked
*script not kept* come from a 2026-10-10 measurement whose script was not recovered: re-measure before relying on them.
Runtime `.material` files are art XML: CRLF on disk, checked with the consumer's XML tools (`aoe-xml`).

## 1. The .material file

One per model, next to the gr2 with the same stem. `asians/chinese/iron_flail/iron_rider_0.material`:

```xml
<material>
  <submaterial name="mata">
    <materialdef name="default" />
    <parameters>
      <texture name="BaseColor" override="units\asians\chinese\iron_flail\textures\iron_rider_0_mata_BaseColor" />
      <texture name="Normals" override="units\asians\chinese\iron_flail\textures\iron_rider_0_mata_Normals" />
      <texture name="Masks" override="units\asians\chinese\iron_flail\textures\iron_rider_0_mata_Masks" />
      <texture name="Details" override="units\asians\chinese\iron_flail\textures\iron_rider_0_mata_Details" />
    </parameters>
  </submaterial>
  <submaterial name="matb">
    <materialdef name="default" />
    <parameters>
      <texture name="BaseColor" override="units\cavalry\oprichnik\textures\oprichnik_whip_matA_BaseColor" />
      <texture name="Normals" override="units\cavalry\oprichnik\textures\oprichnik_whip_matA_Normals" />
      <texture name="Masks" override="units\cavalry\oprichnik\textures\oprichnik_whip_matA_Masks" />
    </parameters>
  </submaterial>
</material>
```

The second submaterial borrows another unit's page by archive path: vanilla textures are referenced, never copied.

## 2. Texture sets

| Asset | Set |
| --- | --- |
| Rider body (every DE full-LOD rider) | one 1024 x 1024 set: BaseColor, Normals, Masks, plus Details on all except the yabusame riders |
| Second submaterial on a rider | only for alpha-cut cards on the same page (hussar age2: 20 triangles, `default_doublesided_cutout`) or a skinned weapon borrowing a vanilla page (iron flail) |
| Horse | one 1024 set of 3-4 maps; hussar horses add a 512 second set |
| Rigid attachment | 512 set (swords, naginata, gun, keshik hats), 256 for bows; BaseColor, Normals, Masks, no Details |

- Shaders (`materialdef`) seen on units: `default`, `default_cutout`, `default_doublesided`,
  `default_doublesided_cutout`. In the extracted rider and horse set, 39 of 77 submaterials are
  `default_doublesided_cutout`, 7 `default_cutout`, 28 `default`. Use a double-sided shader wherever single-sided
  cloth or open shells show their back; cutout variants for alpha cards. Cutout riders ship BaseColor in an alpha
  format; that the cutout reads that alpha is inferred.
- DDT formats: the BaseColor of every DE horse and of some riders (steppe_rider_2, naginata_rider_1,
  yabusamerider_0/2, dragoon_age3/4, light_cavalry_age3_rider) is format 9, 1,398,184 bytes at 1024 (about 1 byte per
  texel with mips); the other BaseColors and every Normals, Masks and Details page are formats 4/5, 699,136 bytes at
  1024 (about 0.5 byte per texel). Pages carry full mip chains (9 levels at 1024).
- DXT1 stores each 4x4 block as two endpoint colours plus two interpolated ones
  ([Microsoft block compression](https://learn.microsoft.com/en-us/windows/win32/direct3d10/d3d10-graphics-programming-guide-resources-block-compression)):
  give painted motifs (studs, lamellae, pleats) a period of at least 8 texels at mip 0 and a tone of their own, or they
  blur away.

## 3. Masks

Masks = R ambient occlusion, G roughness, B metallic (shader disassembly of the building materialdefs,
`aoe3de-player-colour/references/engine-and-vanilla.md`; units use the same materialdef names). Vanilla rider values
(*script not kept*): AO mean 0.909-1.000 (very light: vanilla relies on painted value structure, not baked AO);
roughness of metal texels 0.430-0.505, of cloth 0.726-0.805; metallic is binary, covering 0.1-23 % of a page.

## 4. Details and player colour

- Details.R is the player-colour weight: `lerp(base, base * PC, Details.R)`, linear, UV0, measured on the building
  materialdefs (`aoe3de-player-colour`). Riders use the same materialdef names, so the same behaviour is inferred,
  not proven on units.
- Vanilla rider Details: R only (G = B = 0), hard-edged (R > 200 within 0.2-3 points of R > 25), covering 8.9-50.4 %
  of the page: keshik 31.6-34.6 %, steppe 34.2-39.8 %, naginata 28.0-29.7 %, iron flail 8.9-33.3 %, dragoon
  17.4-28.8 %, hussar 18.4-50.4 %. Horses 1.2-15.5 %.
- Under the mask the BaseColor is neutral (saturation 0.009-0.028) with folds kept, median luma 137-210 (sRGB): not the
  near-white that building player colour uses (*script not kept*).
- Player colour normally sits on non-metal; the naginata riders put it on armour (12-19 % of the mask on metal), a
  style choice, not an engine rule (*script not kept*).
- The yabusame riders have no Details map and so no rider player colour: never use their `.material` as a template.

## 5. UV facts for the organic UV step

For `blender-organic-uv`; the full vanilla UV benchmark, the gate profile and the camera and pose inputs are in
[organic UV reference](organic-uv-reference.md). The short version:

- Every DE full-LOD rider body has 0 % mirrored (negative-winding) UV area (`shape_metrics.py --what uv`, the 20
  riders) and 0.0-0.3 % stacked texels (*script not kept*); legacy LPs mirror 22-57 % (iron_rider_0_lp 48-51 %).
- UV fill of the 0-1 page 0.48-0.71 (median about 0.65; the script's UV area counts overlaps twice, so it equals the
  fill only without stacking); texel density 351-476 px per engine unit at 1024 on the largest mesh of each of the 20
  riders (2026-10-11; the 2026-10-10 sample said 350-430), measured as sqrt(UV area x 1024^2 / 3D area); the
  two-material samurai reach 508.
- A consumer may add a universal density floor (AoP: `blender-architecture-texturing/references/uv-density-floor.md`);
  vanilla riders sit far above it.

## 6. Tangents and normal maps

- Measured: Blender 5.1 `calc_tangents` (MikkTSpace) rebuilt on raw GR2 data of 6 vanilla models (8 meshes:
  iron_rider_0 with its flail, yabusamerider_0 with its leg cover, steppe_rider_2, wandering_horseman, sowar_0,
  yabusamehorse_0) matches the stored int8 tangents: median dot 0.9999-1.0, 98.4-100 % of corners above 0.95,
  handedness sign agreeing on 97.9-100 % of corners. With V flipped, the sign agrees on only 0-2.1 %.
- So compute tangents with MikkTSpace on the final serialized data (exported triangles, stored normals, raw stored
  UVs) and bake tangent-space maps from exactly that triangulated mesh. If UVs are flipped for storage, recompute the
  tangents afterwards; never carry them over.
- The green-channel convention of unit Normals maps is unmeasured. Buildings in one mod showed different transforms
  per atlas (`aoe3de-building-export/references/textures-xml.md`). Before shipping a baked map, compare it with a
  vanilla rider Normals page on a feature of known relief under all four red/green sign combinations, and confirm
  with one bench test using an asymmetric emboss.

## 7. Camera (for readability reviews)

`<game install>/Startup/game.cfg` sets `limitPitch=47`, `normalZoom=50`, `minZoom=29`, `maxZoom=60`. Nothing documents
whether these are the live pitch or distances, and no field of view was found, so the unit's on-screen size cannot be
computed from the config. Calibrate review renders against an existing in-game screenshot (a vanilla rider's pixel
height) instead.
