---
name: aoe3de-player-colour
description: Apply player colour to Age of Empires III DE buildings through the material's 4th texture (Details, R = player-colour weight). Covers the engine formula, building the mask from face selections or by segmenting painted fields in the existing BaseColor, the rule for the BaseColor under the mask (light objects keep it; saturated or dark fields are lightened, or gold x blue turns dark navy), the Blender preview, the DDT and material lines, and the checks. Use when a building, ship or prop needs player colour, a Details map, a "player color band", or when the player colour looks dark, muddy or wrongly tinted.
---
# AoE3 DE player colour (Details map)

## How the engine does it

Every building materialdef (default, cutout, doublesided, destructible, parallax) samples an optional 4th texture,
`Details`, and does, per texel (a multiply, not a replace):

    albedo_lin = BaseColor_lin * lerp(1, PlayerColour_lin, Details.R)

- Only **R** is read. G is the emissive mask in `default_emissive` only; B and A are unread. Write R-only, G = B = 0.
- Details is **linear** (no srgb flag, default black = no player colour). It uses **UV0**, the same as BaseColor, so
  every texel shared through stacked or conjoined UVs is coloured on every face that uses it.
- File: RTS3 DDT, DXT1 (fmt 4), full mip chain, **same resolution as its BaseColor**. Material: one extra
  `<texture name="Details" override="...">` line in the submaterial, and the same line in the damaged material.
  Recipe in [details_export.md](references/details_export.md); shader and vanilla evidence in
  [engine-and-vanilla.md](references/engine-and-vanilla.md).

## The BaseColor under the mask: the decision rule

The multiply means the base under the mask sets the player colour's brightness and hue. A saturated or dark base
tints and darkens it: gold x blue is dark navy. Vanilla keeps the base under the mask neutral and light (231-255 grey;
castle_regicide 158 grey for whole wall panels).

**Only light objects (sails, white or cream walls, light cloth) keep their BaseColor under the mask. Everything else
(gold, wood, painted colours, dark fields) gets a lighter base.**

Measure it: `scripts/lighten_under_mask.py` (default mode `report`) takes the texels under the full mask
(Details.R >= 250) and gives the verdict:

| verdict | condition (8-bit sRGB base) | action |
| --- | --- | --- |
| KEEP | mean Rec.709 luma >= 200 **and** mean Lab chroma <= 20 | leave the BaseColor as it is |
| LIGHTEN | anything else | mode `partial` (keeps some hue at the target luma) or `neutral` (grey) |

Calibrated on two measured cases (see the AoP evidence): cream walls had luma 211 and chroma 11 (KEEP); gold gable
cells had luma 127 and chroma 41 (LIGHTEN). The tool reports the predicted in-game colour for 2-3 players before and
after. Always show the owner the in-game look with 2-3 player colours before deciding. The verdict is advice, and the
owner can overrule it. The tool warns when the chosen mode contradicts the verdict.

The lighten modes touch only texels with Details.R > 0 (optionally inside `--region`, e.g. one field under a shared
Details map). They blend by R, so a soft edge moves by its fraction. They keep grain, soot and AO as relative
brightness (`grey = target x (Y / mean Y)^0.6`, capped) and lift the field's mean to `--target-srgb` (default 211).

## Budget: measure what the player sees

Vanilla Asian buildings (18 JP/CN atlases, measured 2026-10-08) put player colour on **0.6-4 % of
used texels (median 2.1 %)**, on thin stripes, base trims, eave bands or one panel; never on tile
fields, posts or door leaves; the mask is hard (61-96 % of non-zero texels >= 250) and worn like
flaking paint. A texel share hides stacking: on the Korean Barracks a 0.8 % texel share was still
3.8 % on screen, because the one kept band cell was stacked ~7x and its light base made it louder.
Report the **stack-weighted share** (texels x visible faces sharing them) or the pixel share of a
blue-vs-red render pair, before and after; narrowing a stacked band to one 10-12 texel stripe is the
effective lever. Evidence: AoP workflow journal 2026-10-08-claude-05 and -16.

## Workflow

1. **Scope.** Agree which surfaces carry player colour (owner's screenshot or words). Freeze the UVs first: Details
   follows UV0, so a later repack invalidates the mask.
2. **Mask** with `scripts/details_mask.py`. Sources are max-combined. See [mask-sources.md](references/mask-sources.md).
   - *Faces*: select faces by geometry or class, then export `faces.json` (UV0 polygons plus the visible pixel counts).
     Texel groups come from centre-rasterised sharing (>= 3 texels). **A group that also holds a seen unselected face
     is refused** (exit 2, with an unshare proposal); never widen the colour through collateral sharing. The coverage
     is supersampled for a soft edge on shared chart borders, then dilated into the gutter (10 steps).
   - *Procedural*: segment a painted field in the existing BaseColor inside a region. Use CIE Lab hue and chroma,
     then an **Otsu split on the hue, not the luma**: soot and fading darken lines and cells alike. Then take the
     4-connected cells, drop specks, fill small holes and add a 1-texel soft edge. The images are not regenerated.
3. **Base.** Run `lighten_under_mask.py` in report mode on each field, then apply `keep`, `partial` or `neutral`
   as decided. Write the result to a new file; never write over the input.
4. **Preview** in Blender with `scripts/details_review.py` (the game formula, one shared player-colour node,
   `set_player(1..8)`). See [review-preview.md](references/review-preview.md) for how to install it and verify it.
5. **Check** with `scripts/check_state.py --base <HEAD maps> --cand <candidate>` (add `--faces/--select` for the
   leak check). It passes only if every other map is byte-identical, BaseColor changed only under Details.R > 0, and
   no unselected face carries mean R > 0.5. Render the before/after from the **owner's current (HEAD) scene or
   state**, never from an older final or a copy that lacks his latest elements.
   Check **completeness separately from leakage**. For a repeated architectural role
   (for example a band around all walls), enumerate required components from the
   brief and whole model before selecting painted faces. Sample the intended
   world-space role through each component's actual UV0 into Details.R, including
   mirrored ends, short returns, courtyards and elevated walls. Record nonempty
   samples and all-reader compatibility per component; a whole-model average can
   hide a completely unpainted end. Validate the source-bound report with
   `scripts/check_role_coverage.py report.json` and show matched front/back/corner
   views. The validator checks report completeness, not the sampling implementation
   or visual quality. Local cuts/reuse need a UV review packet; retain other charts.
6. **Export**: build the DDT and add the material lines ([details_export.md](references/details_export.md)). Then run
   the consuming mod's own line-ending and deployment checks.

## Scripts

Plain Python, NumPy and Pillow (details_review.py runs inside Blender). Images are handled in file order (row 0 =
top), and UV (u, v) maps to (u*size, (1-v)*size).

- `pc_common.py`: colour math, `ingame_albedo`, `base_stats`/`classify` (the rule), Otsu, components, dilation.
- `details_mask.py`: the faces and procedural sources to `<page>_Details.png` (R, 0, 0), plus a JSON report.
- `lighten_under_mask.py`: verdict and the keep/partial/neutral base under the mask.
- `check_state.py`: scope check (maps, BaseColor under the mask, texel-sharing leak).
- `check_role_coverage.py`: per-component role coverage and source-identity evidence;
  `test_role_coverage.py` tests missing, empty, stale and conflicting evidence.
- `details_review.py`: the Blender preview node group, install/uninstall/set_player/selftest.
- `test_player_colour.py`: `python -m pytest <skill>/scripts/test_player_colour.py -q`

Project evidence and worked examples: [Age of Pirates Korean TC](references/aop-korean-tc-evidence.md).
