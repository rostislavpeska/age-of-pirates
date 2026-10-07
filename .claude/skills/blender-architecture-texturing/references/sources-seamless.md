# Sources and seamless textures
Research photographs of the actual period/style before generating capitals, relief, cornices, window surrounds or roof details. Record provenance and which features the source supports. Do not replace rich ornament with generic smooth filler to save work. Favor bitmap/normal relief within the geometry budget when silhouettes permit.

Use the available GPT image tool for generated sources. Request orthographic, front-facing material samples with specified physical scale, neutral diffuse illumination, no perspective, cast shadows, baked AO, lettering or watermark. For researched relief request crisp detail at the 2x allocation. Preserve prompts, reference URLs and generated originals. A normal-looking generated RGB image is not a validated tangent normal map: derive/bake and inspect normals separately.

A seamless prompt is not proof of tiling. Inspect a 3x3 repeat at final scale. Offset/wrap half the image width/height so borders meet centrally; repair central seams on a copy with wrap-aware painting or image editing, protecting outer-edge continuity. Repeat and inspect both axes/corners, tonal gradients and distinctive repeating marks. Retest derived normals/roughness after finalizing the tile. Do not accept mirrored brickwork merely because its border difference is small.
`scripts/check_tile.py image.png --out report.json` compares boundary discontinuity to ordinary neighbor variation. It is diagnostic, not an artistic pass. Deterministic tiling previews/numeric edits are appropriate when agreed; do not substitute script-painted approximations for requested image generation.

## Texture source catalogue

| Source | Best use | Licence and provenance |
| --- | --- | --- |
| [Poly Haven](https://polyhaven.com/textures) | Photographic PBR materials | [CC0](https://polyhaven.com/license); checked 2026-09-14. |
| [ambientCG](https://ambientcg.com/) | Photographic PBR materials | [CC0](https://docs.ambientcg.com/license/); checked 2026-09-14. |
| [FreeStylized](https://freestylized.com/all-textures/) | Additional candidate for stylized PBR textures, alphas and Painter materials; compare its visual style with the established building set before adoption | [Site licence](https://freestylized.com/disclaimer/) checked 2026-10-07. Free website content permits commercial and non-commercial projects; attribution is optional. The site calls its terms "custom CC0" but adds redistribution restrictions, so **do not record this as unrestricted CC0**. Raw republication on other platforms is restricted; the terms allow redistribution after key modifications and repurposing, including use in a kit or asset pack. Patreon products have separate, non-CC0 terms. Record the particular asset, licence evidence and modifications. |

FreeStylized is an owner-requested possible source alongside Poly Haven, not a mandatory replacement for existing approved materials. Check each asset's actual download tier, supplied channels, resolution, normal convention and physical scale; do not assume a source/Designer file or a paid download is included. No subscription or purchase is implied by this catalogue.

Verify individual asset/current terms and record source URL, author if given, licence, scale and modifications in the source handoff. Keep original downloads outside runtime folders; ship only the permitted, integrated output. Reference photographs are not automatically reusable textures. Keep basecolor/normal/roughness physically consistent.
