# Age of Pirates evidence: Korean Town Center (2026-09-29)

This is a worked example, not a portable prerequisite. The paths are in the AoP owner's Korean repo clone.
Workspace: `$AOP_KOREAN_REPO/research/Texturing_11/Claude_CP2` (CP2; `AOP_KOREAN_REPO` = that clone on the device,
`config/aop.local.env`).

## Owner decisions, in order

1. The player colour goes on the plaster panels below the mid rail, as the "4th layer". Candidate `details_r1` had
   19 faces (0.79 % of the 2048 page), and 5 texel groups, all painted, needed no unshare. Its BaseColor under the
   mask was neutral grey (sRGB 211), following the vanilla rule.
2. Gables were added: the player colour goes in the gold lattice cells, procedurally, and the image is not
   regenerated ("I love the texture, just want the player color on it").
3. About 11:30: "the player color is nice, so this can be applied but WITHOUT TOUCHING the basecolor map". The
   Details map alone went on HEAD (`head_player_colour`), with the cream walls and gold cells kept. Journal
   `2026-09-29-claude-116`.
4. About 12:00, looking at the blue-tinted gables: "player color also on Gables but the baseColor on Gables with
   player color background should be lighter then". The candidates were `head_gables_light_partial` and
   `head_gables_light_neutral`, with only the gable-cell BaseColor texels changed.
5. The rule that followed: **"Only light objects like sails / white walls don't need basecolor transform beneath
   player color override"**, and "this should also be part of the skill used for player color application".

## Calibration of the keep/lighten rule (HEAD `uplift_out/state/head_1150_player_colour`, Details.R >= 250)

| field | texels | mean sRGB | luma | Lab chroma | verdict | in-game P1 blue / P2 red |
| --- | --- | --- | --- | --- | --- | --- |
| cream walls (kept) | 39,212 | 220, 210, 190 | 210.8 | 11.4 | KEEP | (37, 35, 182) / (181, 31, 27) |
| gold gable cells | 9,208 | 166, 123, 60 | 127.3 | 41.2 | LIGHTEN | (25, 16, 57) dark navy / (136, 13, 3) |
| gable cells after `partial` | 9,208 | 223, 206, 182 | 207.8 | 14.5 | KEEP | (38, 34, 174) / (183, 30, 25) |
| gable cells after `neutral` | 8,914 | 210 grey | 210.2 | 0.0 | KEEP | n/a |

The thresholds (luma >= 200, chroma <= 20) separate the two owner cases with margin on both axes. The `partial`
output passes the rule, and the in-game blue on it matches the cream walls' blue.

## Real-data self-check of the skill scripts (2026-09-29)

- Procedural parity: `details_mask.field_cells` compared with CP2 `details_sources.gable_cells` on the HEAD BaseColor
  and the same 4 gable regions. 11,923 against 11,922 masked texels; 184 differ (soft edge only; full texels 8,917
  against 8,914). The Otsu split moved about 0.3 deg because the skill places it in the histogram gap instead of on
  a bin centre.
- `lighten_under_mask.py --mode partial --region gables` compared with CP2 `head_gables_light_partial`: at most 1
  count of difference (rounding) on 2,558 texels. 11,922 texels changed, 0 outside the mask.
- `check_state.py` HEAD against that candidate: PASS. Every other map is byte-identical, and the BaseColor changed
  only under Details.R > 0.

## Source tools (CP2, generalised into this skill)

- `details_player.py`: geometry selection of the lower panels, texel groups, 4x4 coverage and 10-step dilation.
  It became the faces source of `details_mask.py`.
- `details_gables/details_sources.py`: gable cells by Lab hue and hue Otsu, and the `gable_base`
  keep/partial/neutral function. They became the procedural source and `lighten_under_mask.py`.
- `details_gables/lighten_gable_cells.py`: the scoped HEAD edit. It became `lighten_under_mask.py --region`.
- `details_review.py`: the Blender tint group. It became `scripts/details_review.py` (same node names, so it re-wires
  an AoP review scene idempotently).
- `Export_CP1/dryrun.py --textures-only`: the Details DDT (2048, fmt 4, 10 mips, validator PASS) and the one-line
  material diff.

## Lessons recorded in `.claude/skills/JOURNAL.jsonl`

- `claude-89`: the shader formula, R-only, linear, UV0, DXT1, same size.
- `claude-92`: select by wall structure, not by height.
- `claude-94`: preview node group; a missing image is magenta, and (1 - B) ignores it.
- `claude-113`: every picture and candidate must build on HEAD. Renders built on final v2 dropped the owner's green
  band and red door, and he saw a "heavy regression".
- `claude-116`: the Details-only decision, later refined by the lighter-gable rule.
- The workflow `wf_cd9acdd0-f70` verify pass also recorded: a flat extraction of `default.materialdef` picked up
  the granny_legacy copy; the promote step drops `*_Details.png` until `publish.py` learns the optional map; the
  1-texel soft edge reaches the rail and sill strips on the tower-east chart (mean R 15.7 and 4.9, disclosed).
