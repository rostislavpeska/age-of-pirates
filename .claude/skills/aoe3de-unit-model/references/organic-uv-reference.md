# AoE3 DE unit UVs: the reference for the organic UV step (2026-10-11)

The AoE3 facts that `blender-organic-uv` (the generic method: declared seams, SLIM, mirror-exact unique layout, head
priority, evaluator, gates) needs and must not hold itself: the vanilla UV benchmark, the gate profile derived from it
([`profiles/organic_uv_unit_body_1024.json`](../profiles/organic_uv_unit_body_1024.json)), the camera and pose inputs
of the evaluator, and the AoP owner's decisions for unit pages. Numbers were measured read-only on the retail archives.

## 0. How to run the organic UV step on an AoE3 unit

- Run the generic chain of [blender-organic-uv](../../blender-organic-uv/SKILL.md) on the export copy.
- Gates: `uv_gates.py --profile .claude/skills/aoe3de-unit-model/profiles/organic_uv_unit_body_1024.json --run
  page=PAGE_RUN --run body=BODY_RUN` (section 6).
- Camera: `--pitch 47` (`game.cfg limitPitch=47`; its meaning and the field of view are unverified), `--headings 8`,
  single-sided.
- Posed visibility: seated on the vanilla horse with the unit's idle clip, `--pose-npz` written from
  `aoe3de-unit-animation/scripts/pose_sim.py` (rider clip key 0 on the horse clip key 0, the rider origin at the
  horse's attach point, the horse as an extra occluder, forward = the horse's head direction, GXO scale 0.393700787).
  The 2026-10-11 runs used exactly this; a maintained writer script is still open (section 7).
- Pages: one 1024 page per human unit for the body and any weapon skinned into it (AoP owner 2026-10-11: "human
  units should have 1x 1024 texture"); a hat or helmet attachment on its own 512 page, a bow on 256, as vanilla does
  (section 4).
- Head priority: the AoP owner agreed about 1.3x the torso, like vanilla (2026-10-11), read on the bone-region
  estimator; whether hidden faces count is still his call (`blender-organic-uv` open questions).

## 1. What was measured, and how

- **Models**: 16 vanilla models extracted from the retail game archives on 2026-10-11 (game build not recorded): 6
  rider/infantry bodies on 1024 pages (iron_rider_0, keshik_rider_rank01, yabusamerider_0, musketeer_2age,
  changdao_0, ashigaru_0age), one horse (iron_flail_horse_0), the legacy low-poly iron_rider_0_lp, and their
  attachments (hats, swords, guns, bows, the iron flail).
- **Reader**: this package's GR2 reader (`scripts/unit_gr2.py`, `scripts/shape_metrics.py`); the benchmark driver was
  a scratch script (*script not kept*), and its densities reproduce `shape_metrics.py --what uv` exactly. Pages and
  sizes from the `.material` files and the DDT headers (`scripts/texture_pages.py`).
- **UV convention**: GR2 unit UVs are DirectX (row = v x H, no V flip) when drawn over a decoded page; one unit
  (ashigaru_0age) is stored Z-up while the others are Y-up, so the up axis comes from the skeleton per model.
- **Bone-region estimator**: each triangle belongs to the region of its dominant bone (largest weight summed over its
  corners; a tie goes to the bone met first, as `collections.Counter.most_common`), regions by bone name (head/neck,
  hands, arms/clavicle, spine/pelvis = torso, feet, thigh/calf = legs, prop/attach/bone_ = weapon); region density =
  page x sqrt(sum UV area / sum 3D area). `blender-organic-uv`'s `uvlib.bone_region` and its evaluator's
  `bone_regions` block use the same rules.
- **Evaluator run on the vanilla body**: iron_rider_0's body was also run through `uv_eval` (imported as a reference
  object, seated idle pose oprichnik_idle1 key 0 on horse_idle_a key 0, pitch 47, 8 headings, single-sided), which is
  where the visibility numbers come from. Only this one body has evaluator visibility numbers.
- t/u = texels per engine unit at the page size; the evaluator's t/m equals t/u when 1 unit is taken as 1 m.

## 2. Bodies (one 1024 page each)

| Unit | Tris | Islands | Coverage | Stacked | Density p50 / CV | Stretch mean | Gutter min / median px | Border px | Upright | Seam per sqrt(area) | Head/torso | Hands/torso |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| iron_rider_0 | 1182 | 11 | 58.2 % | 0 % | 343 / 0.16 | 1.149 | 21.0 / 27.0 | 15 | 71 % | 5.35 | 1.30 | 0.86 |
| keshik_rider_rank01 | 1278 | 37 | 62.5 % | 0.3 % | 358 / 0.14 | 1.121 | 4.8 / 23.0 | 7 | 73 % | 8.01 | 1.47 | 0.87 |
| yabusamerider_0 | 1110 | 15 | 60.9 % | 0 % | 376 / 0.10 | 1.186 | 7.1 / 13.0 | 5 | 46 % | 6.97 | 0.97 | 0.87 |
| musketeer_2age | 1118 | 12 | 72.2 % | 0 % | 477 / 0.11 | 1.222 | 4.4 / 8.7 | 0 | 64 % | 5.63 | 1.02 | 0.91 |
| changdao_0 | 1174 | 9 | 58.2 % | 0 % | 361 / 0.15 | 1.251 | 15.0 / 19.4 | 13 | 71 % | 5.27 | 1.22 | 0.93 |
| ashigaru_0age | 1124 | 10 | 66.7 % | 2.8 % | 430 / 0.12 | 1.217 | 11.2 / 20.1 | 8 | 46 % | 5.58 | 1.37 | 0.87 |
| iron_flail_horse_0 | 1346 | 16 | 48.1 % | 0.02 % | 219 / 0.18 | 1.342 | 7.0 / 16.0 | 3 | 40 % | 8.28 | - | - |
| iron_rider_0_lp (legacy) | 222 | 17 | 73.9 % on 64 x 64 | 96.2 % | 37 / 0.20 | 1.64 | 0 / 1.0 | 0 | 99 % | 5.64 | 1.01 | 0.95 |

"Stretch mean" is the benchmark's area-weighted anisotropy; "stacked" counts texels used twice (ashigaru's 2.8 % is
one folded strap). No DE body mirrors or shares left/right texels; every side owns its texels (asymmetric paint and
player colour). The legacy low-poly model stacks 96 % on a 64 x 64 page: it is not a convention for new work.

iron_rider_0 body through `uv_eval` (seated idle): L2 1.052 / Linf 3.75, anisotropy 1.149 / p90 1.40, density p10 /
p50 / p90 314 / 343 / 372 t/m, visible-weighted p10 313, 11 islands, seams 11.61 m (visible mean 2.25 m, any heading
5.88 m), surface 4.81 m2, coverage 58.2 %, min island gap 21.3 px (gutters vanish at mip 5), page border 15.0 px, 72 %
upright, left/right density asymmetry 0.0022, UV split vertices 755 (ratio 1.22), 30.8 % of the UV area on faces
never visible.

## 3. Seam anatomy

- Torso one island, cut down the back centre (iron rider, changdao, ashigaru, keshik) or down a coat's front opening
  (musketeer, yabusame kimono); the armholes stay as holes inside the torso island (iron rider).
- Head cut at the back centre.
- Arms one island each, cut along the underside; hands a separate stock island (seam length 0.37 u, identical on six
  units).
- Legs and robes cut on the inner side; open hems left as natural borders.
- The Asian bodies share one torso UV template: iron_rider_0, changdao_0 and ashigaru_0age torso islands have 168
  triangles each, intersection-over-union 0.71-0.79 (keshik derived, 0.49-0.64).
- Face density 1.3-1.6x the page on iron rider, keshik, changdao, ashigaru; 1.0x on musketeer and yabusame. Hands get
  0.86-0.93x the torso on every unit.

## 4. Attachments

| Attachment | Parent | Page | Density vs body | Notes |
| --- | --- | --- | --- | --- |
| iron flail (skinned in iron_rider_0) | iron_rider_0 | second submaterial on the borrowed 1024 oprichnik whip page | 4.55x (1622 t/u) | 64 % coverage |
| keshik_hat_rank02 | keshik | own 512 | 1.82x | |
| musketeer_2age_hat | musketeer | own 512 | 0.94x | 1 px gutters |
| ashigaru_0age_hat | ashigaru | own 512 | 2.03x | one island |
| steppe_rider_sword | keshik | own 512 | 2.02x | |
| musketeer_2age_gun | musketeer | own 512 | 1.10x | |
| changdao_wpn | changdao | own 512 | 1.34x | |
| cav_archer_1age_bow | keshik | own 256 | 1.65x | limbs stacked as rotated copies (64 % of texels) |
| yabusamerider_bow | yabusame | own 256 | 0.98x | limbs stacked (41 %) |

Vanilla never puts a hat or a weapon model on the body page; the one skinned weapon (the iron flail) borrows another
unit's page at 4.5x the body density. A weapon skinned into a new unit's body and sharing its 1024 page (the AoP
owner's rule) therefore runs at body density, about 4x below that vanilla flail: an open question for the texture
test.

## 5. Limits of this reference

- One evaluator run on one vanilla body (iron_rider_0) carries the visibility and seam-visibility numbers; the other
  bodies have geometry and UV numbers only.
- Visibility comes from one seated idle key at pitch 47; the game camera's real pitch is unverified.
- The head/torso ratios are bone-region numbers; the hidden-face question (a helmeted head) has no vanilla
  counterpart because vanilla hats are separate attachment models.
- t/u assumes engine units for distances; the density floor of buildings (90 / 54 t/u) is passed trivially by unit
  bodies (350-480 t/u) and is not a useful organic gate.

## 6. The gate profile (unit body on a 1024 page)

The profile file is the source; this table mirrors it. Hard limits sit at or just past the vanilla value; targets are
what the H1 recipe reached on a 1.1k-triangle rider (body + skinned flail on one 1024 page, 2026-10-11).

| Metric (run) | Hard | Target | Vanilla evidence | H1 rider |
| --- | --- | --- | --- | --- |
| Flipped faces, folds, unintended overlap (page) | 0 | 0 | 0 on DE bodies (one folded strap on ashigaru) | 0 |
| Mirrored islands, stacked mirror texels (page) | 0 | 0 | DE riders mirror 0 % | 0 |
| Min island gap px (page) | >= 8 | >= 16 (mip 5) | iron_rider_0 21.3; DE 4.4-21 | 16.5 |
| Page border px (page) | >= 4 | >= 8 | iron_rider_0 15 | 11.25 |
| L2 / Linf stretch (page) | <= 1.06 / 3.75 | <= 1.03 / 2.0 | iron_rider_0 1.052 / 3.75 | 1.026 / 1.81 |
| Angle stretch mean / p90 (page) | <= 1.20 / 1.45 | <= 1.15 / 1.35 | iron_rider_0 1.149 / 1.40; DE 1.12-1.25 | 1.123 / 1.298 |
| Density p50 / visible-weighted p10 t/m (page) | >= 343 / 313 | >= 360 / 350 | iron_rider_0 343.4 / 313.4, keshik_rider_rank01 358.4 / 332.2; DE p50 343-477 | 372 / 345 |
| Texel coverage (page) | >= 55 % | >= 60 % | DE 58-72 % | 60.3 % |
| GPU vertices, every UV layer (page) | <= 1,050 | <= 950 | vanilla welded 628-1061 | 899 |
| Upright islands (page) | >= 70 % | >= 95 % | iron_rider_0 72 %; DE 46-73 % | 100 % |
| Left/right density asymmetry (page) | <= 0.01 | <= 0.003 | iron_rider_0 0.0022 | 0.000 |
| Seam per sqrt(area) (body) | <= 6.6 | <= 5.6 | iron_rider_0 5.30; DE 5.27-8.01 | 5.55 |
| Visible seam per sqrt(area) (body) | <= 1.03 | <= 0.90 | iron_rider_0 1.03 | 0.87 |
| UV split ratio (body) | <= 1.32 | <= 1.25 | iron_rider_0 1.22 | 1.24 |
| Body islands / tiny (body) | <= 20 / <= 2 | 10-16 / 0 | DE 9-37 | 15 / 0 |
| Head/torso, bone regions (body) | owner decision | 1.25-1.35 | iron_rider_0 1.30; changdao 1.22; ashigaru 1.37; keshik 1.47; yabusame 0.97; musketeer 1.02 | 1.119 (1.271 visible faces) |

The visible-weighted p10 hard minimum is the floor of the lowest vanilla reference (iron_rider_0 313.4, reproduced exactly by `gr2_lint`'s numpy port of the evaluator's visibility, 2026-10-11); it was 314 until the export review found that value failed iron_rider_0 itself. AoP's export lint applies these two density minima (profile `unit_rider_1024` in `scripts/havok/gr2_lint_profiles.json`, PROPOSED) on top of the universal density floor, which runs for every model, units included.

The 1,050 vertex ceiling is the unit contract's (vanilla welded maximum 1061). The universal density floor (90 / 54
t/u, blender-architecture-texturing uv-density-floor.md) is not one of the organic gate's own checks, but it applies to
every model at export (AoP `gr2_lint` check `texel_density`): unit bodies sit at 350-480 t/u and pass it by far
(iron_rider_0, keshik_rider_rank01 and the Pyeongon specimen: 0 % below 54 t/u, 0 % collapsed).

## 7. Open AoE3 items for the UV step

- A maintained pose-NPZ writer in `aoe3de-unit-animation` (the evaluator's `--pose-npz` format is in
  `blender-organic-uv/scripts/README.md`; the 2026-10-11 runs used a scratch adapter around `pose_sim.py`).
- The game camera's real pitch; seams and skinning stretch in walk, attack and death; DXT bleeding at 8 vs 16 px
  gutters; whether the converter exports only the active UV layer; tangents through the converter.
