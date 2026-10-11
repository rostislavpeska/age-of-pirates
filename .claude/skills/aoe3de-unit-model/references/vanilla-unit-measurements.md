# Vanilla unit measurements (riders, horses, attachments)

Measured 2026-10-10 on the retail AoE3 DE archives (Steam app 933110), read-only; re-measured and extended
2026-10-11 with this package's scripts. Level: **measured**. The scripts read vanilla files straight from the archive
(`--archive Art/units/...`, extracted in memory with [aoe3de-bar-archives](../../aoe3de-bar-archives/SKILL.md) into a
temp folder, never a repository) through the consumer's GR2 reader (`<consumer-root>/scripts/havok/gr2_read.py`);
texture sizes come from the DDT headers inside the archive. Archive paths below are relative to `Art/units/`.

| Section | Script (in `scripts/`, `python <script> --help`) |
| --- | --- |
| Full table, mesh-level detail, budgets | `measure_units.py --material --mesh --summary` |
| Shipped buffers, influences and weights, vertex format | `vertex_fill.py` |
| Hinge blends, joint rings and blend rows, density, mesh segment axes | `joint_metrics.py --what blends,rings,density,sides,axes` |
| Regions, shape and symmetry, faces the mount covers, tiers, hands, UV | `shape_metrics.py` (`--what seat` for the mount-covered faces, `--compare A B` for tiers and hands) |
| Texture pages and Details | `texture_pages.py material|ddt|details|gr2` |

`tests/test_unit_model_scripts.py` pins the iron_rider_0 and yabusamerider_0 numbers below and skips where no game
install is found.

| Rule of the generic method (blender-organic-modeling) | Reference data here |
| --- | --- |
| Rings at each hinge, hinge weights (deformation topology, sections 2-3) | "Joint rings and blend rows" |
| Clothed form as the deforming body, shells only where they leave the silhouette (clothing and armour, section 0) | "Shape and symmetry" |
| Faces the mount covers (clothing and armour, section 5) | "Faces the mount covers" |
| Influence distribution and single-influence share (skinning and pose tests, section 3) | "Influences and weights" |

## Which file is which (read from the animfiles)

The unit-to-animfile link comes from the vanilla `Data/protoy.xml`.

| Unit | Animfile(s) | Rider models by tech | LowPoly logic | Horse | Weapons / headgear |
| --- | --- | --- | --- | --- | --- |
| Iron Flail (Chinese) | `asians/chinese/iron_flail/iron_flail.xml`, `iron_flail_rider.xml`, `iron_flail_whip.xml` | `<none>` iron_rider_0 / `yphonoredironflail` iron_rider_2 | rider: yes (`iron_rider_0_lp`, `iron_rider_2_lp`); horse: the full model in both slots | iron_flail_horse_0 / _1 | flail is a **skinned mesh inside the rider gr2**; `attachment_whip` (oprichnik_2age/3age_whip) declared but never attached; torch on `R HAND` |
| Keshik (Chinese) | `asians/chinese/keshik/keshik_horse.xml`, `keshik_rider.xml` | rank01 / `ypdisciplinedkeshik` rank02 (+hat_rank02 on `HEAD`) / `yphonoredkeshik` rank03 (+hat_rank03) | rider: **no** (`lp_keshik_rider_*` ship unreferenced); horse: yes (`lp_keshik_horse_rank0X`) | keshik_horse_rank01/02/03 | bow `cav_archer_1age_bow` on `Bip01 L Hand`; sword `steppe_rider_sword` on `Bip01 Prop1`; hats on `HEAD` |
| Steppe Rider (Chinese) | `asians/chinese/steppe_rider/steppe_rider_horse.xml`, `steppe_rider.xml` | steppe_rider_0 / `ypdisciplinedstepperider` _1 / `yphonoredstepperider` _2 | rider: yes (`_0_lp`, `_1_lp`, `_2_lp`); horse: full model in both slots | steppe_rider_horse (all ranks) | sword `steppe_rider_sword` on `Bip01 Prop1`; oprichnik whip declared, never attached |
| Naginata Rider (Japanese) | `asians/japanese/naginata_rider/naginata_rider_horse.xml`, `naginata_rider.xml` | naginata_rider_0 / `ypdisciplinednaginatarider` _1 / `yphonorednaginatarider` _2 | rider: yes (`_0_lp` .. `_2_lp`); horse: full model in both slots | naginata_horse / _1 / _2 | `naginata_lance` on `bip01 prop1` |
| Yabusame (Japanese) | `asians/japanese/yabusame/yabusamehorse.xml`, `yabusamerider.xml` | yabusameRider_0 / `yphonoredyabusame` _2 | rider: yes (`_0_lp`, `_2_lp`); horse: yes (`yabusameHorse_0_lp`, `_2_lp`) | yabusameHorse_0 / _2 | `yabusameRider_bow` on `Bip01 L Hand` (Idle: `bip01 prop2`); sword `steppe_rider_sword` on `Bip01 Prop1` |
| Hussar (European) | `cavalry/light_cavalry/light_cavalry_horse.xml`, `light_cavalry_rider.xml`, `light_cavalry_sword.xml` | light_cavalry_age2_rider / `veteranhussars` age3 / `guardhussars` age4; variants lifeguard, danish_lifeguard, merchussar, georgian_hussar | **none** (`lp_light_cavalry_*`, `light_cavalry_age1_*` unreferenced) | light_cavalry_age2/3/4_horse | sword `light_cavalry_sword_age02` (age04 for Guard and variants) on `Bip01 Prop1` |
| Dragoon (European) | `cavalry/dragoon/dragoon_horse.xml`, `dragoon_rider.xml`, `dragoon_gun.xml`, `dragoon_sword.xml` | dragoon_age3 / `guarddragoons`, `imperialdragoons` age4; variants legion_dragoon, mercdragoon, krakus, danish_dragoon | **none** (`lp_dragoon_*` unreferenced) | dragoon_horse_age3 / age4 (+ variants) | gun `dragoon_gun1` (gun2 Guard) on `Bip01 Prop1`; hats on `Bip01 head` for two variants |

## Column meanings

| Column | Meaning |
| --- | --- |
| GPU verts | vertices in the gr2 vertex buffers as shipped (what the engine uploads) |
| welded verts | distinct (position, normal, UV, vertex colour, bone weights, bone indices), tangent ignored: what a clean export of the same mesh ships (UV seams and hard edges still split) |
| unique pos | distinct positions (rounded to 1e-5): roughly what Blender shows |
| tris | index count / 3, all meshes of the file |
| skel / weighted bones | bones in the skeleton / bones with a nonzero weight on at least one vertex (a rigid mesh counts its one bone) |
| infl max / mean; 1/2/3/4 | nonzero weights per vertex over all GPU vertices, and how many vertices have 1, 2, 3, 4 |
| textures | per submaterial of the `.material`: map count (BaseColor, Normals, Masks [, Details]), page size, `materialdef` |

## Full table

| Unit | Model | Role | GPU verts | welded | unique pos | tris | meshes | mat slots | skel | weighted | infl max / mean | 1/2/3/4 | textures |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- | --- |
| Iron Flail | iron_rider_0 | rider, default, normal LOD (flail skinned in) | 985 | 976 | 694 | 1328 | 2 | 2 | 32 | 23 | 4 / 1.419 | 633/295/53/4 | mata 4 maps @1024 (default); matb 3 maps @1024 (default) |
| Iron Flail | iron_rider_0_lp | rider, default, lowpoly | 371 | 274 | 148 | 245 | 2 | 4 | 32 | 22 | 2 / 1.143 | 318/53/0/0 | no .material (legacy maps) |
| Iron Flail | iron_rider_2 | rider, Honored, normal (flail skinned in) | 975 | 966 | 684 | 1312 | 2 | 2 | 31 | 23 | 4 / 1.422 | 624/295/52/4 | mata 4 @1024; matb 3 @1024 |
| Iron Flail | iron_rider_2_lp | rider, Honored, lowpoly | 359 | 259 | 143 | 235 | 2 | 4 | 32 | 23 | 2 / 1.326 | 242/117/0/0 | no .material |
| Iron Flail | iron_rider_1 | UNREFERENCED legacy mesh | 406 | 294 | 168 | 285 | 2 | 5 | 32 | 23 | 2 / 1.36 | 260/146/0/0 | no .material |
| Iron Flail | iron_rider_1_lp | UNREFERENCED legacy mesh | 361 | 266 | 143 | 235 | 2 | 4 | 32 | 23 | 2 / 1.324 | 244/117/0/0 | no .material |
| Iron Flail | iron_flail_horse_0 | horse, default (both slots) | 3810 | 921 | 704 | 1346 | 2 | 2 | 32 | 27 | 4 / 1.508 | 2376/1025/317/92 | mata 4 @1024 (default_doublesided_cutout) |
| Iron Flail | iron_flail_horse_1 | horse, Honored (both slots) | 3810 | 921 | 704 | 1346 | 2 | 2 | 32 | 27 | 4 / 1.508 | 2376/1025/317/92 | mata 4 @1024 (default_doublesided_cutout) |
| Iron Flail | oprichnik_2age_whip | whip attachment, never attached | 147 | 147 | 77 | 146 | 1 | 1 | 6 | 5 | 1 / 1.0 | 147/0/0/0 | mata 3 @1024 (default) |
| Keshik | keshik_rider_rank01 | rider, default (no lowpoly slot) | 987 | 981 | 719 | 1278 | 1 | 1 | 28 | 18 | 3 / 1.301 | 725/227/35/0 | mata 4 @1024 (default_doublesided_cutout) |
| Keshik | keshik_rider_rank02 | rider, Disciplined (+hat_rank02) | 956 | 950 | 688 | 1242 | 1 | 1 | 26 | 18 | 4 / 1.313 | 694/227/33/2 | mata 4 @1024 (default_doublesided_cutout) |
| Keshik | keshik_rider_rank03 | rider, Honored (+hat_rank03) | 956 | 950 | 688 | 1242 | 1 | 1 | 26 | 18 | 4 / 1.313 | 694/227/33/2 | mata 4 @1024 (default_doublesided_cutout) |
| Keshik | lp_keshik_rider_rank01 | rider lp, UNREFERENCED | 344 | 261 | 132 | 224 | 1 | 3 | 24 | 18 | 2 / 1.32 | 234/110/0/0 | no .material |
| Keshik | lp_keshik_rider_rank02 | rider lp, UNREFERENCED | 213 | 211 | 125 | 212 | 1 | 3 | 24 | 16 | 2 / 1.352 | 138/75/0/0 | no .material |
| Keshik | keshik_horse_rank01 | horse, default, normal | 3804 | 883 | 700 | 1330 | 1 | 1 | 32 | 27 | 4 / 1.531 | 2347/989/373/95 | mata 3 @1024 (default_doublesided_cutout) |
| Keshik | lp_keshik_horse_rank01 | horse, default, lowpoly | 132 | 132 | 77 | 140 | 1 | 2 | 45 | 22 | 2 / 1.583 | 55/77/0/0 | no .material |
| Keshik | keshik_horse_rank03 | horse, Honored, normal | 3921 | 934 | 742 | 1377 | 2 | 2 | 32 | 27 | 4 / 1.518 | 2453/1000/373/95 | mata 3 @1024 (default_doublesided_cutout) |
| Keshik | lp_keshik_horse_rank03 | horse, Honored, lowpoly | 154 | 154 | 99 | 171 | 1 | 1 | 45 | 25 | 2 / 1.571 | 66/88/0/0 | no .material |
| Keshik | keshik_hat_rank02 | hat attachment (HEAD) | 288 | 71 | 50 | 96 | 1 | 1 | 2 | 1 | 1 / 1.0 | 288/0/0/0 | matA 3 @512 (default) |
| Keshik | keshik_hat_rank03 | hat attachment (HEAD) | 163 | 79 | 42 | 80 | 1 | 1 | 3 | 1 | 1 / 1.0 | 163/0/0/0 | matA 3 @512 (default) |
| Keshik | cav_archer_1age_bow | bow attachment (Bip01 L Hand) | 162 | 105 | 44 | 84 | 1 | 1 | 3 | 1 | 1 / 1.0 | 162/0/0/0 | mata 3 @256 (default) |
| Keshik | steppe_rider_sword | sword attachment (Bip01 Prop1) | 200 | 118 | 64 | 105 | 1 | 1 | 3 | 1 | 1 / 1.0 | 200/0/0/0 | mata 3 @512 (default_doublesided_cutout) |
| Steppe Rider | steppe_rider_0 | rider, default, normal | 884 | 875 | 658 | 1284 | 1 | 1 | 22 | 18 | 3 / 1.258 | 672/196/16/0 | mata 4 @1024 (default) |
| Steppe Rider | steppe_rider_0_lp | rider, default, lowpoly | 352 | 256 | 124 | 212 | 1 | 2 | 22 | 16 | 2 / 1.406 | 209/143/0/0 | no .material |
| Steppe Rider | steppe_rider_1 | rider, Disciplined, normal | 931 | 922 | 670 | 1286 | 1 | 1 | 22 | 18 | 3 / 1.242 | 717/203/11/0 | mata 4 @1024 (default) |
| Steppe Rider | steppe_rider_1_lp | rider, Disciplined, lowpoly | 423 | 317 | 136 | 226 | 1 | 2 | 22 | 16 | 2 / 1.392 | 257/166/0/0 | no .material |
| Steppe Rider | steppe_rider_2 | rider, Honored, normal | 1093 | 1061 | 801 | 1504 | 1 | 1 | 22 | 18 | 4 / 1.357 | 764/275/47/7 | mata 4 @1024 (default_doublesided_cutout) |
| Steppe Rider | steppe_rider_2_lp | rider, Honored, lowpoly | 561 | 419 | 165 | 262 | 1 | 2 | 22 | 16 | 2 / 1.319 | 382/179/0/0 | no .material |
| Steppe Rider | steppe_rider_horse | horse, every rank, both slots | 3804 | 881 | 700 | 1330 | 1 | 1 | 32 | 27 | 4 / 1.503 | 2399/988/326/91 | mata 4 @1024 (default_doublesided_cutout) |
| Naginata Rider | naginata_rider_0 | rider, default, normal | 628 | 628 | 505 | 962 | 1 | 1 | 22 | 18 | 3 / 1.282 | 468/143/17/0 | mata 4 @1024 (default_doublesided) |
| Naginata Rider | naginata_rider_0_lp | rider, default, lowpoly | 433 | 274 | 145 | 200 | 1 | 2 | 22 | 18 | 2 / 1.427 | 248/185/0/0 | no .material |
| Naginata Rider | naginata_rider_1 | rider, Disciplined, normal | 780 | 780 | 567 | 1054 | 1 | 1 | 22 | 18 | 3 / 1.286 | 574/189/17/0 | mata 4 @1024 (default_doublesided_cutout) |
| Naginata Rider | naginata_rider_1_lp | rider, Disciplined, lowpoly | 387 | 303 | 166 | 220 | 1 | 2 | 22 | 18 | 2 / 1.382 | 239/148/0/0 | no .material |
| Naginata Rider | naginata_rider_2 | rider, Honored, normal | 877 | 876 | 631 | 1188 | 1 | 1 | 22 | 18 | 3 / 1.254 | 671/189/17/0 | mata 4 @1024 (default_doublesided) |
| Naginata Rider | naginata_rider_2_lp | rider, Honored, lowpoly | 389 | 302 | 173 | 219 | 1 | 3 | 22 | 18 | 2 / 1.38 | 241/148/0/0 | no .material |
| Naginata Rider | naginata_horse_2 | horse, Honored (both slots) | 3850 | 909 | 724 | 1350 | 2 | 2 | 32 | 27 | 4 / 1.555 | 2334/1008/397/111 | mata 4 @1024 (default_doublesided_cutout) |
| Naginata Rider | naginata_lance | naginata attachment (bip01 prop1) | 111 | 89 | 38 | 67 | 1 | 1 | 3 | 1 | 1 / 1.0 | 111/0/0/0 | matA 3 @512 (default) |
| Yabusame | yabusamerider_0 | rider, default, normal | 779 | 765 | 590 | 1110 | 2 | 2 | 30 | 18 | 3 / 1.363 | 545/185/49/0 | mata 3 @1024 (default_cutout) |
| Yabusame | yabusamerider_0_lp | rider, default, lowpoly | 592 | 338 | 139 | 231 | 1 | 2 | 30 | 16 | 2 / 1.13 | 515/77/0/0 | no .material |
| Yabusame | yabusamerider_2 | rider, Honored, normal | 819 | 806 | 626 | 1180 | 1 | 1 | 30 | 18 | 4 / 1.283 | 610/188/19/2 | mata 3 @1024 (default_doublesided_cutout) |
| Yabusame | yabusamerider_2_lp | rider, Honored, lowpoly | 454 | 343 | 157 | 248 | 1 | 2 | 30 | 17 | 2 / 1.119 | 400/54/0/0 | no .material |
| Yabusame | yabusamehorse_0 | horse, default, normal | 3872 | 921 | 727 | 1358 | 1 | 1 | 32 | 27 | 4 / 1.543 | 2381/989/391/111 | mata 4 @1024 (default_doublesided_cutout) |
| Yabusame | yabusamehorse_0_lp | horse, default, lowpoly | 393 | 276 | 144 | 242 | 1 | 2 | 45 | 26 | 2 / 1.405 | 234/159/0/0 | no .material |
| Yabusame | yabusamehorse_2 | horse, Honored, normal | 4067 | 978 | 776 | 1430 | 1 | 1 | 32 | 27 | 4 / 1.549 | 2488/1038/430/111 | mata 4 @1024 (default_doublesided_cutout) |
| Yabusame | yabusamehorse_2_lp | horse, Honored, lowpoly | 425 | 291 | 153 | 246 | 1 | 2 | 45 | 26 | 2 / 1.579 | 179/246/0/0 | no .material |
| Yabusame | yabusamerider_bow | bow attachment (L Hand / prop2) | 268 | 94 | 48 | 92 | 1 | 1 | 2 | 1 | 1 / 1.0 | 268/0/0/0 | mata 3 @256 (default) |
| Hussar | light_cavalry_age2_rider | rider, default (no lowpoly slot) | 771 | 763 | 561 | 1110 | 1 | 2 | 22 | 18 | 3 / 1.27 | 579/176/16/0 | mata 4 @1024 (default); matb 4 @1024 (default_doublesided_cutout) |
| Hussar | light_cavalry_age3_rider | rider, Veteran | 886 | 878 | 636 | 1226 | 1 | 1 | 22 | 18 | 3 / 1.33 | 614/252/20/0 | mata 4 @1024 (default_doublesided_cutout) |
| Hussar | light_cavalry_age4_rider | rider, Guard | 890 | 884 | 642 | 1238 | 1 | 1 | 21 | 18 | 3 / 1.297 | 646/224/20/0 | mata 4 @1024 (default_doublesided_cutout) |
| Hussar | lp_light_cavalry_age2_rider | rider lp, UNREFERENCED | 189 | 187 | 107 | 161 | 1 | 2 | 21 | 16 | 3 / 1.37 | 122/64/3/0 | no .material |
| Hussar | merchussar | rider, merc variant | 3538 | 989 | 669 | 1262 | 3 | 3 | 22 | 18 | 3 / 1.245 | 2732/744/62/0 | mata 4 @1024 (default); matb 4 @1024 (default) |
| Hussar | light_cavalry_age2_horse | horse, default | 3978 | 954 | 739 | 1404 | 1 | 2 | 32 | 27 | 4 / 1.501 | 2525/1007/351/95 | mata 4 @1024 (default_cutout); matb 4 @512 (default) |
| Hussar | light_cavalry_age4_horse | horse, Guard | 3978 | 954 | 739 | 1404 | 1 | 2 | 32 | 27 | 4 / 1.51 | 2515/993/375/95 | mata 4 @1024 (default_cutout); matb 4 @512 (default_cutout) |
| Hussar | lp_light_cavalry_age2_horse | horse lp, UNREFERENCED | 142 | 142 | 83 | 146 | 1 | 2 | 29 | 25 | 4 / 1.88 | 54/55/29/4 | no .material |
| Hussar | light_cavalry_sword_age02 | sword attachment (Bip01 Prop1) | 243 | 186 | 76 | 127 | 1 | 1 | 3 | 1 | 1 / 1.0 | 243/0/0/0 | mata 3 @512 (default) |
| Hussar | light_cavalry_sword_age04 | sword attachment, Guard | 243 | 186 | 76 | 127 | 1 | 1 | 3 | 1 | 1 / 1.0 | 243/0/0/0 | mata 3 @512 (default) |
| Dragoon | dragoon_age3 | rider, default (no lowpoly slot) | 768 | 759 | 558 | 1068 | 3 | 3 | 22 | 18 | 3 / 1.262 | 578/179/11/0 | three submaterials, 4 maps @1024 each (default_doublesided_cutout, default, default) |
| Dragoon | dragoon_age4 | rider, Guard/Imperial | 902 | 875 | 630 | 1204 | 4 | 4 | 22 | 16 | 3 / 1.2 | 741/142/19/0 | mata 4 @1024 (default_cutout) |
| Dragoon | lp_dragoon_age3 | rider lp, UNREFERENCED | 173 | 173 | 102 | 163 | 1 | 2 | 22 | 17 | 2 / 1.514 | 84/89/0/0 | no .material |
| Dragoon | mercdragoon | rider, merc variant | 3568 | 1026 | 689 | 1282 | 3 | 3 | 22 | 18 | 3 / 1.270 | 2638/898/32/0 | mata 4 @1024 (default); matb 4 @1024 (default_doublesided_cutout) |
| Dragoon | dragoon_horse_age3 | horse, default | 897 | 892 | 701 | 1332 | 1 | 1 | 34 | 25 | 4 / 1.496 | 585/198/95/19 | mata 4 @1024 (default_cutout) |
| Dragoon | dragoon_horse_age4 | horse, Guard | 846 | 841 | 701 | 1332 | 1 | 1 | 34 | 25 | 4 / 1.526 | 534/198/95/19 | mata 4 @1024 (default_doublesided_cutout) |
| Dragoon | lp_dragoon_horse_age3 | horse lp, UNREFERENCED | 165 | 165 | 79 | 148 | 1 | 2 | 35 | 24 | 2 / 1.691 | 51/114/0/0 | no .material |
| Dragoon | dragoon_gun1 | gun attachment (Bip01 Prop1) | 134 | 76 | 40 | 68 | 1 | 1 | 3 | 1 | 1 / 1.0 | 134/0/0/0 | mata 3 @512 (default_doublesided_cutout) |
| Dragoon | dragoon_gun2 | gun attachment, Guard | 134 | 76 | 40 | 68 | 1 | 1 | 3 | 1 | 1 / 1.0 | 134/0/0/0 | mata 3 @512 (default_doublesided_cutout) |

Influence means are exact (nonzero slots / vertices); the 2026-10-10 table rounded twice and showed 1.364 and 1.269
for yabusamerider_0 and mercdragoon. Every other cell of the 65 rows was reproduced by `measure_units.py` on
2026-10-11.

**Unreadable** (section 0 Oodle-compressed; the reader raises `NotImplementedError`): `asians/japanese/naginata_rider/`
`naginata_horse.gr2`, `naginata_horse_1.gr2`; `cavalry/dragoon/` `danish_dragoon.gr2`, `jutland_dragoon_horse.gr2`,
`krakus.gr2`, `legion_dragoon.gr2`; `cavalry/light_cavalry/` `danish_lifeguard.gr2`, `georgian_hussar.gr2`,
`lifeguard.gr2`; also about half of the DE explorer skins. Their `.material` files are readable. Never pick an
unreadable file as donor or reference.

## Mesh-level detail

| Model | Mesh | GPU verts / tris | Skinning | Bones bound -> weighted | Material |
| --- | --- | --- | --- | --- | --- |
| iron_rider_0 | iron_rider_0Shape (body) | 838 / 1182 | max 4, mean 1.49 (486/295/53/4) | 18 -> 18 | mata (own 1024 set, 4 maps) |
| iron_rider_0 | iron_rider_0_whipShape (flail) | 147 / 146 | 1 influence per vertex | bone_handle, bone_link1, bone_link2, bone_link3, bone_tip | matb (borrowed oprichnik whip 1024 set, 3 maps) |
| iron_rider_2 | body / flail | 828 / 1166 + 147 / 146 | body max 4; flail 140 x1, 7 x2 | 18 + 5 | mata + matb |
| yabusamerider_0 | body + separate leg-cover mesh | 715 / 1026 + 64 / 84 | max 3 | 18 (leg cover: 5 of them) | one material |
| dragoon_age4 | body + hair, hat, bag | 738 / 1010 + 32/36, 92/102, 40/56 | body skinned; hair, hat, bag rigid on one bone each | 16 | one material |
| light_cavalry_age2_rider | one mesh, 2 groups | 771 / 1090 + 20 | max 3 | 18 | mata `default` + matb `default_doublesided_cutout` on the same BaseColor page (20 cut-out triangles) |
| iron_flail_horse_0 | body + rigid bits | 3771 / 1326 + 39 / 20 | max 4, mean 1.51 | 27 + 1 | mata |

## Budgets

Rider bodies: the 20 referenced normal-LOD rider files with readable data (iron 0/2, keshik r1-r3, steppe 0-2,
naginata 0-2, yabusame 0/2, hussar age2-4, merchussar, dragoon age3/4, mercdragoon); skinned-in parts included,
attachments excluded.

| Quantity | min | median | mean | max |
| --- | ---: | ---: | ---: | ---: |
| triangles | 962 (naginata_rider_0) | 1240 | 1218 | 1504 (steppe_rider_2) |
| welded vertices | 628 | 881 | 886 | 1061 |
| unique positions | 505 | 650 | 645 | 801 |

LP riders (the 10 referenced `_lp` riders: iron 0/2, steppe 0-2, naginata 0-2, yabusame 0/2):

| Quantity | min | median | mean | max |
| --- | ---: | ---: | ---: | ---: |
| triangles | 200 | 228.5 | 230 | 262 |
| GPU vertices (shipped) | 352 | 406 | 432 | 592 |
| welded vertices | 256 | 302.5 | 308 | 419 |
| unique positions | 124 | 146.5 | 150 | 173 |

LP / full triangle ratio per pair: 0.17-0.21 (mean 0.19).

- **Horses**: every DE horse is the same base mesh: 700-776 unique positions, 1326-1430 triangles, 841-978 welded
  vertices; shipped GPU vertices 3804-4067 for the Asian and hussar horses but 846-897 for the dragoon horses.
- **Attachments** (rigid, one bone, attached by `<attach>`): steppe_rider_sword 105 tris, light-cavalry sword 127,
  naginata 67, dragoon gun 68, cavalry-archer bow 84 (2age 72), yabusame bow 92, keshik hats 80-96; 71-186 welded
  vertices. Exception: the iron flail, skinned in, 146 tris / 147 vertices on a 5-bone chain.
- **Regions** (`shape_metrics.py --what regions`, the 20 riders above): triangle shares by the bone with the largest
  summed weight - head plus integrated headgear 16.7-32.5 %, hands 6.9-10.8 % (the stock hand is 52-58 triangles and
  24-30 unique positions per hand), arms 13.4-24.2 %, torso 12.3-31.4 %, legs with feet and skirts 23.7-42.4 %; the
  iron flail's chain is 11 % (weapon). By unique positions: head 15.7-33.4 %, torso 11.7-36.6 %, arms 12.1-23.5 %,
  hands 6.9-10.4 %, legs 13.2-37.1 %, feet 6.7-11.2 %. A robe counts as legs or torso by its weights and a hat as head.
  The 2026-10-10 six-rider samples (head 16-27 %, torso 13-16 %, legs 27-41 %) fall inside these ranges. LPs: head
  10-19 % of positions.

## Shipped buffers are inflated: budget from welded counts

`vertex_fill.py` prints the extra splits per attribute and the split positions by cause. Most DE horses ship about
4x the vertices they need. iron_flail_horse_0: 3771 GPU vertices for 1326 triangles
(3978 corners); 2843 of the splits come from the Tangent attribute alone, 69 from normals, 170 from UVs; without the
tangent it welds to 921. The dragoon horses, the identical 701-position / 1332-triangle mesh, ship at 846 / 897.
Same artifact on the keshik, steppe, naginata_2, yabusame and hussar horses, the merc riders (2856 GPU for 1002
triangles) and small props (keshik hat 288 GPU for 96 triangles). Rider bodies weld at 0.65-0.77 vertices per
triangle; the welded-to-unique ratio is 1.24-1.41 (iron_rider_0 splits 182 positions: 94 by UV only, 58 by normal
only, 30 by both).

## Influences and weights

- Rider bodies: max 3 or 4, mean 1.20-1.42; 4-influence vertices are rare (0-7 per rider, iron_rider_0: 4 of 838).
  Single-influence share of unique positions 56-77 % (iron_rider_0 56 %, yabusamerider_0 74 %).
- Horses: max 4, mean 1.50-1.56 (91-111 four-influence vertices; dragoon horses 19). Asian LPs max 2; legacy
  European LPs max 2-4. Attachments 1.
- Every skinned vertex in every vanilla mesh measured sums to exactly 255 over 4 uint8 slots; weights are stored in
  descending order with no bone twice in one vertex; in DE full-LOD meshes 97.5-100 % of zero-weight slots repeat the
  index of slot 0.
- Smallest nonzero weight: 10-14/255 on most DE riders (range 6-26/255 over 25 of 26 files);
  yabusamerider_0 is the exception, minimum 1/255 with 14 weights under 5/255. Compare vanilla data with a baseline;
  never "fix" it.
- Hinge blends (`joint_metrics.py --what blends`, the 20 riders: unique positions whose two largest weights are the
  joint's two bones, and the median of the smaller weight): knee 4-34 per knee (0.24-0.50), elbow 7-19 (0.31-0.50),
  ankle 8-13 (0.46-0.50), wrist 6-15 (bimodal: about 0.1 on the iron riders, 0.24-0.5 elsewhere), head-to-chest band
  6-38 (0.10-0.50), pelvis-to-thigh 2-35 per side (0.10-0.50), clavicle-to-upper-arm 2-12 per side. Torso blends are
  sparse: pelvis-spine 1-12 in 12 of the 20 files, spine-spine1 1-12 in 8. The pelvis is the dominant bone of 8-14
  positions and rigid on none (2026-10-10 sample).
- Vertex density (`joint_metrics.py --what density`: positions per 10 % of segment within 15 % of the joint against
  mid upper segment): knee 0.4-4.7x mid-thigh, elbow 0.6-3.0x mid-arm over the 20 riders (the five-rider sample of
  2026-10-10: 1.4-4.7 and 0.8-1.6); elbows are modelled pre-bent 26.5 deg.

## Joint rings and blend rows

Reference data for the deformation-topology rules of [blender-organic-modeling](../../blender-organic-modeling/SKILL.md)
(ring counts and blend rows are checked against a reference asset, not a fixed recipe). `joint_metrics.py --what
rings` clusters the unique positions around the knee (Calf joint) and elbow (ForeArm joint) into rings along the bent
limb axis; a ring is blended when some of its positions carry two bones; the numbers are the mean weight of the lower
bone on each blended ring, upper to lower. Approximate: an oblique loop splits or merges.

| Rider | Knee L blended rows | Knee R | Elbow L | Elbow R |
| --- | --- | --- | --- | --- |
| iron_rider_0 | 3: 0.34 / 0.43 / 0.71 | 4: 0.0 / 0.36 / 0.43 / 0.75 | none found | none found |
| iron_rider_2 | 3: 0.32 / 0.43 / 0.69 | 4: 0.0 / 0.33 / 0.43 / 0.73 | none found | none found |
| yabusamerider_0 and _2 | 4: 0.40 / 0.45 / 0.75 / 0.80 | 4: 0.40 / 0.45 / 0.75 / 0.87 | 1: 0.5 | _0 3: 0.34 / 0.58 / 0.89; _2 1: 0.5 |
| keshik_rider_rank01-03 | 5: 0.01 / 0.39 / 0.49 / 0.50 / 0.57 | 4: 0.40 / 0.49 / 0.75-0.80 / 0.80 | 1: 0.5 | 1: 0.5 |
| steppe_rider_0 / _1 / _2 | 3 / 3 / 5 rows, 0.12-0.95 | 6 / 2 / 6 rows, 0.12-0.99 | 2: 0.5 / 0.83 (_2: 0.40 / 0.84) | 2: 0.5 / 0.83 (_2 1: 0.84) |
| naginata_rider_0 / _1 / _2 | 2 / 3 / 3: 0.17 / 0.50 (/ 0.93) | the same | 1: 0.5 | 1: 0.5 |
| light_cavalry_age2-4, merchussar | 3: 0.24 / 0.50 / 0.75 | 3 (age3 and age4: 7, with 0.13-0.26 rows above) | 1: 0.5 | 1: 0.5 |
| dragoon_age3, age4, mercdragoon | 2: 0.50 / 0.81 | 2: 0.50 / 0.81 | 1: 0.5 | 1: 0.5 |

- Knees blend 2-7 rows (median 3), not one 50/50 pivot row: the rows typically step about 0.25-0.4, 0.45-0.5 and
  0.7-0.8 down the joint, and some riders add a light 0.1-0.2 row above. The dragoons and naginata_rider_0 use only
  two blended rows.
- Elbows: one blended ring at 0.5 at both elbows on 14 of the 20 riders (keshik x3, naginata x3, light cavalry
  age2-4 and merchussar, dragoon x3, yabusamerider_2); two or three rings on the steppe riders and yabusamerider_0's
  right elbow (its left has one). On
  the iron riders the ring method finds none, yet each elbow has 10 two-weight positions at a median 0.43
  (`--what blends`): the blend exists on an oblique loop the clustering does not see.
- Wrists are bimodal (above) and the head-to-chest band runs 0.10-0.50: neither fits a fixed 0.35-0.5 bin.
- LPs: 0-5 blended positions per knee, the iron LP knee none ([LowPoly LOD](lod-lowpoly.md)).
- These are game-ready assets of about 1240 triangles; they show what the engine and these clips tolerate, not a
  minimum.

## Shape and symmetry

- DE rider bodies are 80-98 % bilaterally symmetric in rest pose (`shape_metrics.py --what symmetry`: welded
  positions with a mirror partner across x within 1 mm, 79.6-98.4 % on the 20 riders); one-sided props are separate
  meshes.
- Bodies are not watertight (`--what shells`, the largest mesh of each of the 20 riders): 0-134 welded boundary edges,
  0-6 edges with more than two faces. Shells: one
  continuous upper body plus floating shells (helmet, plume, plates); legs welded into the body (iron flail,
  yabusame) or separate leg/skirt shells under the hem (steppe 2, dragoon, naginata, keshik). The keshik robe is 13+
  small shells all dominated by L_Thigh; the steppe_rider_2 shoulder plate blends 4 bones.
- Tiers share 91-100 % of welded positions (`shape_metrics.py --compare A B`: keshik rank02 and rank03 100 %,
  identical geometry differing by texture and hat; naginata 0 in 2 95.2 %, yabusame 0 in 2 91.2 %, iron flail 0 in 2
  97.1 %); steppe rider tiers only 53-79 % (0 in 2: 78.9 %).
- Bounding boxes in rest pose (`--what heads`): yabusame riders 0..2.11 (rank 2 helmet 2.18) high, 1.10-1.14 wide,
  0.42-0.48 deep; iron_rider_0 -1.13..1.95 (the lowered frame, section 5 of [rider skeleton](rider-skeleton.md)).

## Faces the mount covers

Reference data for the mount-covered-faces rule of [blender-organic-modeling](../../blender-organic-modeling/SKILL.md)
(clothing and armour, section 5). `shape_metrics.py --what seat` counts, on each body mesh, the triangles dominated
by a pelvis or thigh bone whose normal faces down (seat) or, on a thigh, towards the mid-plane (inner thigh); normals
come from the winding, oriented outward. Measured 2026-10-11:

| Rider body | Triangles | Pelvis + thigh | Seat | Inner thigh | Share of the mesh |
| --- | ---: | ---: | ---: | ---: | ---: |
| iron_rider_0 | 1182 | 172 | 12 | 30 | 3.6 % |
| yabusamerider_0 | 1026 | 106 | 6 | 30 | 3.5 % |
| keshik_rider_rank01 | 1278 | 310 | 11 | 52 | 4.9 % |
| steppe_rider_0 | 1284 | 133 | 0 | 14 | 1.1 % |
| light_cavalry_age2_rider | 1110 | 88 | 0 | 26 | 2.3 % |
| naginata_rider_0 | 962 | 122 | 12 | 16 | 2.9 % |

Every measured rider keeps faces the saddle and the horse's barrel cover in the bind pose; none removes the inner
thighs. A new rider keeps them too (the clips lift the body off the saddle when striking).

## Vertex format

All 59 rider, horse and LP files measured (30 full, 29 LP) use one 40-byte skinned vertex: Position real32x3 @0,
Normal binormal_int8x4 @12, Tangent binormal_int8x4 @16, DiffuseColor0 normal_uint8x4 @20, TextureCoordinates0
real32x2 @24, BoneWeights normal_uint8x4 @32, BoneIndices uint8x4 @36. One UV set only (`vertex_fill.py`). Rigid
attachments use a 24-byte vertex: Position real32x3 @0, Normal binormal_int8x3 @12, BasicStaticPackedData0 uint8 @15,
Tangent binormal_int8x3 @16, BasicStaticPackedData1 uint8 @19, TextureCoordinates0 real16x2 @20 (swords, lance, gun,
bow, keshik hat, the horse's rigid bits). Fill in DE full-LOD files: DiffuseColor0 = (255,255,255,255) on every vertex,
Normal.w = 127, Tangent.w = +127 or -127 (the handedness; 95.7-100 % at +127). Legacy LP fill differs (w = -70,
colour 127/129) and is never a convention to copy. Details on writing it: [export routes](export-routes.md).
