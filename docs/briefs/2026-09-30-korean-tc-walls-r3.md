# Korean Town Center: Walls R3 delivery and handoff

The owner approved the wall update and requested texture installation on 2026-09-30.
`art/buildings/korean_tc/textures/korean_tc_mata_BaseColor.ddt` now has greyer, mottled plaster with edge
dirt; it is shared by intact and `_damaged`. All 16 package files were verified after installation.
This wall-only revision did not change geometry, UVs, normal/mask/Details maps, roof finish or Hangul sign.

Source/receipt/evidence live in the Korean repository:
[Walls R3](https://github.com/rostislavpeska/korean-buildings-blender/tree/main/research/Texturing_11/Export_Walls_r3).
Large editable assets remain in the external `Korean Buildings Blender/snapshots/2026-09-30-live-walls-r3`
library; its manifest is in that directory in Git. Original live Blender and PSD sources were preserved.

Quality status remains **25 PASS / 5 FAIL / 0 SKIP**: hidden-atlas budget, hidden-surface density in both
models, and stale UV lineage. The owner explicitly approved installation after these failures were disclosed.
This is a revision-specific exception, not a generic bypass. Game-window blur is unresolved. The actual live
source and previous export source matched in geometry, every UV layer, material assignments and corner normals;
there is no evidence that this inspected pair used different source versions. No new game test was run.

Korean feature recipes: [korean-architecture](../../.claude/skills/korean-architecture/SKILL.md).

The owner requested **feedback only**, with harness implementation left to the separate Claude builder:
[asset-versioning and Blender/GitHub feedback](https://github.com/rostislavpeska/korean-buildings-blender/blob/main/docs/feedback/2026-09-30-claude-asset-versioning.md).
The brief names reproduced faults, confidence limits, complete-bundle version semantics and proposed acceptance
tests. It does not claim the safeguards are implemented.

Next-art-direction discussion (no choice made and no new modeling started):
[TC lifecycle, Fortress buildings, Industrial/Imperial TC trade-offs and ChatGPT prompt](https://github.com/rostislavpeska/korean-buildings-blender/blob/main/docs/decisions/2026-09-30-next-korean-buildings.md).
