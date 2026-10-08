# Vanilla attachment evidence, 8 October 2026

Census of all 551 decompiled building animfiles (`Art/buildings/**/*.xml.XMB`) with every referenced GR2 read
from the game's BAR archives (**aoe3de-bar-archives**). 1,360 attaches name a bone other than `ATTACHPOINT`.

| Finding | Count |
| --- | ---: |
| Attaches whose anim has a readable `<simskeleton>` model | 599 |
| Horse attaches under a simskeleton with the bone in the simskeleton model | 34 of 34 |
| Flag attaches under a simskeleton with the bone in the simskeleton model | 2 of 2 |
| Smoke/chimney/fire attaches whose bone is in the intact model but not in the simskeleton | 22 (in-game effect not verified) |
| Attaches whose bone exists in no model (dead vanilla attaches, tolerated silently) | 66 under a simskeleton, more elsewhere |
| Attaches naming a bone no `<definebone>` declares | 231 |
| Scaffold/frame attaches | 66, all `ATTACHPOINT` -> `ATTACHPOINT` |
| Horse attaches inside a LowPoly `<normal>` branch whose `lp_*` model has no horse bone | every vanilla stable and corral |

Horse bone transform in vanilla stables (east/west/med, intact and damaged identical): quaternion
(0, 0.7071, 0, 0.7071), scale 0.8, y = 0. Top views with the horse model (`axe_rider_1_horse`) placed at the
bones (`scripts/attach_plot.py`) show the heads pointing out through the open stall fronts.

## Scaffold base at the last construction stage

Every Japanese p66 stage (TC, Bansho, Stable, Dojo, Consulate, Market) is the building's own `*_con_stage3`
plus `asi_4x4_stage2` attached at `ATTACHPOINT`. `asi_4x4_stage2` = 120 triangles of scaffold (mata,
`default_doublesided_cutout`) and 387 triangles of material piles (matb). Part of it always ends up inside the
building: share of scaffold samples enclosed by the building on all four sides -

| Model | Scaffold (mata) | Piles (matb) |
| --- | ---: | ---: |
| Japan TC age 2 (vanilla) | 11 % | 18 % |
| Japan Stable age 2 (vanilla) | 23 % | 39 % |
| Japan Bansho age 2 (vanilla) | 5 % | 32 % |
| Korean TC r72 | 10 % | 40 % |
| Korean Barracks r68e | 3 % | 33 % |
| Korean Stable r68e | 16 % | 29 % |

No quarter turn of the scaffold reduces the overlap meaningfully, so the Korean stages attach it unrotated at
`ATTACHPOINT` like vanilla (AoP, 8 Oct 2026). Whether the piles read well inside the Korean courtyards is the
owner's game check.
