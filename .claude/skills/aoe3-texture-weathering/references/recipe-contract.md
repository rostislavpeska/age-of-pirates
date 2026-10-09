# Mask kit, recipe contract, compose and review (Korean r70 implementation)

The full working implementation (kit builder, seven recipes in three rounds, compose, game-light rig,
QA scripts) is archived in the Korean `r70*` 2d-asset packages of the AoE Buildings library under
`sources/`. Reuse it rather than rewriting; adapt the feature table per building.

## Mask kit (per atlas, 2048, float16 npz, row 0 = top, x = u*W, y = (1-v)*H)

| array | meaning |
| --- | --- |
| feature, feature_bits, cell | resolved feature id (priority on overlaps), all overlaps, chart island id |
| h_local / h_dom | height inside the face's own vertical extent (0 bottom, 1 top; roofs eave->ridge); h_dom uses only the most-seen orientation so opposite faces do not cancel |
| up_x, up_y / up_dom_*, up_coh | world-up in pixel space; agreement of stacked faces |
| dist_down, dist_up, face_h_tx | texels to the panel edge down/up-slope; panel height in texels |
| edge_dist, edge_norm | distance to the island border; divided by the island inradius |
| nz, orient | world normal z; orientation class |
| curv_bake, curv_nrm | Painter curvature bake (owner mesh) and curvature from the normal map (they measure different things) |
| ao, ao_bake | game AO (Masks.R) and a raw Painter AO |
| stack, stack_vis, visible, used | faces per texel, visible faces per texel, visibility, used texels |

Weighting: where visible faces cover a texel, only visible faces count, weighted by visibility.
Provide `directional_trust` (0 where stacked orientations conflict) and fade direction-dependent
effects (damp, streaks) by it.

## Recipe contract

- Inputs read-only; outputs only in the recipe folder: `<atlas>__BaseColor.png` (RGB 8-bit, byte-
  identical outside the claim), `<atlas>__claim.png` (L, 255 = owned; at most 4 px dilation into empty
  gutter, never into another feature), optional `<atlas>__Height.png` (16-bit, 32768 = 0, 1 unit =
  1/1024 texel), optional `__Details.png` (R only), deterministic script + params, previews.
- One recipe owns Details for an atlas. Protected texels (roof base colour, alpha, props, eave backing,
  shared atlases) are never claimed except by overlay recipes that keep untouched texels identical.
- Each recipe LOOKS at 1:1 and at game zoom and reports measured stats against its targets.

## Compose

Priority order (low to high) used on the Korean set: stone, timber, plaster, hanji, doors, player
colour/courtyard, roof overlays. Refresh only the declared empty gutter territory nearest to each
owner; a fixed 48 px dilation can overwrite neighbors on a four-pixel-margin atlas. Preserve other
owners, measure the actual mip/filter result and report insufficient padding without silently
changing UVs. Use exact pixel-centre containment for coverage statistics: rounded polygon drawing
can include outside pixels along every edge. Merge heights -> OpenGL detail normal normalize(-dh/dx, +dh/drow, 1)
-> RNM into the OpenGL source -> the installed per-atlas transform. Keep player-colour base texels of
buildings whose player colour was out of scope byte-identical.

## QA checks (independent scripts, numbers + evidence images)

1. alpha identical; 2. untouched roof texels identical, overlays only; 3. protected regions; 4. every
changed texel inside a claim, composite reproducible; 5. Details R-only and coverage; 6. mip halos
(box and the encoder's Lanczos, mips 1-4); 7. stacked-cell repetition (centred marks on stacked faces);
8. DDT dry run (headers, sizes, round-trip error, cutout mismatch); 9. normals change only where relief
exists, sign against an independent gradient (height for new relief, AO gradient for installed tiles);
10. out-of-scope player-colour bases unchanged; 11. stack-weighted player-colour share.

## Review loop that worked

Round 1: seven recipes + compose + art critic + QA (3 h). Round 2: four fix agents on the ranked
critique + compose + critic + senior-artist judge + QA (1.3 h). Round 3: three fix agents on the judge's
notes. Time-box rounds; pass critiques as files; keep every round's outputs for comparison sheets.
