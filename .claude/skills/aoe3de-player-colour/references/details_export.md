# Details export: DDT and material lines

## The map

`<page>_Details.png` from `details_mask.py`: 8-bit, linear RGB = (R, 0, 0), the same size as the page's BaseColor.
It is dilated into the gutter like the BaseColor, so no uncoloured seam appears at lower mips.

## DDT (Age of Pirates tool; any equivalent DXT1 writer works)

The Age of Pirates repository's `<repo>/scripts/havok/ddt_dxt1.py` (not part of this package) writes the vanilla profile (RTS3, usage 0, alpha 0, fmt 4 DXT1, full mip chain):

    python scripts/havok/ddt_dxt1.py <maps>/P2048_Details.png <stage>/textures/<model>_mata_Details.ddt

This plain form keeps the (R, 0, 0) channels as they are. For `--pack`, the channels must be **greyscale** images:
`--pack` converts each input to luminance (`convert('L')`), so feeding it the red (R, 0, 0) PNG would store
0.299 x R. Write the mask as grey first:

    python scripts/havok/ddt_dxt1.py --pack MASK_grey.png BLACK.png BLACK.png OUT_Details.ddt

The inputs are scratch PNGs, never repo files. The Details resolution equals its BaseColor's. DXT1 is fine even when
that submaterial's BaseColor is DXT5.

Verify by decoding the DDT: the header is `0,0,4,<mips>`, G and B max 0, and the R error is small (Korean TC 2048:
mean 0.003, max 42 on one soft-edge block).

## Material

Add one line under the submaterial's unchanged materialdef (the 4th texture; no define, no float):

```xml
<submaterial name="mata">
  <materialdef name="default" />
  <parameters>
    <texture name="BaseColor" override="buildings\<model>\textures\<model>_mata_BaseColor" />
    <texture name="Normals" override="buildings\<model>\textures\<model>_mata_Normals" />
    <texture name="Masks" override="buildings\<model>\textures\<model>_mata_Masks" />
    <texture name="Details" override="buildings\<model>\textures\<model>_mata_Details" />
  </parameters>
</submaterial>
```

- Only submaterials that carry player colour get the line; the others stay as they are.
- **Damaged material**: add the same Details line to the matching destructible submaterial (vanilla
  `china_towncenter_age2_damaged.material` repeats the intact mata Details).
- In Age of Pirates, `.material` is runtime XML: it must be CRLF (`<repo>/scripts/tools/check_art_eol.py`) and
  follows the `aoe-xml` skill. The override path is the archive-relative path without the extension.
- If the Blender export scene carries material nodes, a Details image node may be added unconnected (the GR2 carries
  only material names); the texture binding lives in the `.material`.

## Pipeline hook points (AoP Korean TC finding)

A publish or promote step that moves unknown maps to a sidecar will drop the Details before it reaches the export.
Register `*_Details.png` as an optional output of that step. The Korean TC `publish.py` needed an
`OPTIONAL_MAPS` patch, proposed and unapplied as of 2026-09-29.
