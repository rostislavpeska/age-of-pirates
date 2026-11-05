# Korean Town Center v20: scope of the demonstrated result

Measured and user-confirmed 2026-09-26. The owner directly answered the explicit
v20 test question: **"Destruction worked"**. This confirms overall destruction
for the files below, independently of the earlier v07 blockout. Individual HP
thresholds, collision precision, final textures and attachment behavior were not
separately reported. The later Town Center skill test was accepted by the owner;
see the approval record below.

Test proto: `zpKoreanTownCenterTest` (21207); unchanged Chinese age-2 control:
`zpChineseTownCenterControl` (21208). Runtime folder:
`art/buildings/korean_tc_experiment/`.

| File | SHA-256 |
| --- | --- |
| korean_tc_pilot.gr2 | c39713935f62b63031a00ec1ca5b2aef3b3c15adb07b362dfd762f0fca275975 |
| korean_tc_pilot_damaged.gr2 | 0e20dca03069123b9bf0c0a92da1777cf6182bbda28b4c7c085298020210ba2e |
| korean_tc_pilot_damaged.hkt | 33859911db779fcc86eba843a2e8c142a8b5dbc9b8477ddeb9cd45f0768d5446 |

| Export measurement | Intact | Damaged |
| --- | ---: | ---: |
| Packed vertices, including UV/normal splits | 18,799 | 54,308 |
| Triangles in exported runtime files | 10,432 | 32,868 |
| Rigid geometry groups | 1 | 156 |
| Skeleton bones | 7 | 272 |

The 156 damage groups include fixed `base`; 13 moving groups are progressive
stage pieces. The 221-body donor graph is retained and 155 convex hulls refitted.
These counts are evidence for this asset, not recommended budgets. The historical
source's topology is not the template for current quad-based authoring.

The external `Korean_Civilization_Research/Game_Test_v20/` folder contains
`RUNTIME_ACCEPTANCE.md`, `runtime_feedback.json`, source/export audits,
`build_pilot_gr2.py`, `adapt_korean_hkt.py`, `verify_export.py` and the deployment
manifest. `Shell_05/Korean_TC_Shell_and_Interiors_v20.blend` is the historical
input. New UV work is separate. Those scripts contain local paths and are not
bundled portable dependencies of this skill; do not run their deployment blindly.

Use the shared [Chinese donor frame and serialization evidence](../../havok-destruction/references/chinese-tc-experiment.md)
for the runtime implementation. The measured transform is donor-specific:
`HKT world = 1.024 * (GR2.z, GR2.y, GR2.x)`. Preserve the shared format guidance
in one place instead of duplicating it into each architectural recipe.

Remaining limits: donor-shaped group/base proxies, unused invisible bodies,
donor masses and conservative box inertia; a convex hull can bridge disconnected
fragments assigned to one body. v20 uses provisional stock materials and omits
final roof alpha and roof/window bakes. None of these are silently approved by
the overall destruction pass.

## Skill acceptance and promotion

The owner subsequently confirmed:

> Towncenter destruction proved and works in editor, the skill test passed, no further testing necessary for now, So the destruction skill is now correct

This direct user report approves the Town Center destruction skill and its
manual editor test. The reviewed workflow is saved in the canonical library.
No further tests were run for promotion, as requested. The prepared naval
regression was not reported as performed and remains untested. This approval
does not add unreported per-stage observations, collision measurements, final
material acceptance or proof of arbitrary new Havok graph creation.
