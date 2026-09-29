# Bake master: bake once per geometry, derive every UV layout

A HIGH-to-LOW bake is the most expensive step of the texturing pipeline. A direct bake
is bound to one UV layout, so every repack, conjoinment or resolution change used to cost
a rebake. A **bake master** stores the baked quantities once, on a private unique-texel
layout, in a form that does not depend on any UV layout. Any runtime layout is then
**derived** from it in seconds to minutes, without loading a HIGH.

Rebake only when the LOW geometry or a HIGH changes. A UV edit is a derive.

## When to use it

- The geometry is frozen (a recorded LOW `input_contract`), but the UV layout is still
  expected to change: conjoinment, AO separation, page or resolution changes.
- The HIGHs are expensive (millions of faces, long ray bakes).
- Several candidate layouts must be compared with real bakes.

Do not use it for LOW-only quantities such as position, world normal or class masks.
Those can be computed directly on any layout.

## What the master stores

A **master** is stored for each LOW geometry version: `<out>/<geo12>/`, where `geo12`
is the first 12 hex digits of `bake_contract.fingerprint(sources)['combined']`.

| Quantity | Stored as | Why it is UV-independent |
| --- | --- | --- |
| NORMAL | object-space normal, `normalize(M3^-1 n_world)`, encoded `n/2 + 0.5 + 1e-5` | no tangent frame is involved |
| AO | local AO from the HIGHs (`only_local`, finite distance) | a surface quantity |
| OPACITY | the run's ray-hit mask (every face ray-based, no classes) | a surface quantity |
| EMIT | the HIGH's own emission, such as tile IDs | a surface quantity |

Tangent-space normals and anything shared between faces are never stored.
Each run also bakes OPACITY as its own hit mask. EMIT alone cannot mark misses.

**Unique texels.** Every face gets its own chart texels, including faces that are members
in a runtime layout. The master density is at least 2x the runtime density: 2 x the p99
owner density of every plan that will be derived, rounded up. A face has master data only
where a run baked it with a HIGH that covers it. Classes with steep, discontinuous relief
(eave cutouts: disc and pan edges) take `class_factor` 1.5, i.e. 3x runtime, for headroom:
with the correct margin their raw p95 is 5.8 deg at 2x (limit 6) and 4.7 deg at 3x. (The
first measurement, 6.6-6.9 at 2x against 5.7-5.8 at 3x, was made with the faulty square
margin.) Pass every path
absolute: Blender silently skips an EXR save to a relative path while the PNG next to it
is written.

**Margin 0 in the master.** Blender's EXTEND margin also fills missed-ray texels inside
a receiver. A miss unmasks the texel, so a direct bake shrinks its holes by `margin`
texels. Measured on 2026-09-28: a 15.4-texel hole kept 256 texels at margin 0 and 64 at
margin 4. The master therefore bakes with margin 0 and keeps an exact hit mask.
The derive applies the target recipe's margin afterwards, as the baker does (see
"The margin" below).

## The margin, as Blender does it

Read from the Blender 5.0.1 source, not assumed:

- `RE_bake_pixels_populate_from_objects` (`render/intern/bake.cc`): a ray miss sets the
  receiver texel's `primitive_id` to -1, and `RE_bake_mask_fill` masks only texels with a
  primitive. The bake mask of a receiver is therefore its **hit** texels; misses are
  written as the START colour and stay unassigned.
- `IMB_filter_extend` (`imbuf/intern/filter.cc`), called by `RE_bake_margin` for
  `margin_type='EXTEND'`: per pass, an unassigned texel is filled only when one of its
  **4 edge neighbours** is assigned. Its value is the weighted mean of its assigned
  8 neighbours (edge 2, diagonal 1). Texels outside the page are unassigned (no clamping,
  no wrap). Filled texels count as assigned in the next pass. The front therefore grows an
  **L1 diamond**, one texel per pass. An 8-neighbour gate grows a square: that was the
  first derive's bug (see the evidence section).
- `write_internal_bake_pixels` (`editors/object/object_bake_api.cc`), with the
  `use_clear=False` that `bake_owner_maps.py` passes: every receiver bake copies only its
  own masked texels into the page, then runs EXTEND with its own mask. A later receiver's
  margin therefore **overwrites** texels an earlier receiver wrote, within `margin` of the
  later receiver's hits. `bake_owner_maps.py` bakes the receivers of a page in a fixed
  order (source x region), and for OPACITY with cutout classes a solid self-bake pass
  before each receiver's cutout pass.

The derive replays exactly that (`derive.margin_mode: "baker"`, the default): per
receiver in the baker's order, write its hit texels, then run EXTEND with that pass's mask.
`"owners"` runs one pass over every hit instead, so no hit is ever overwritten; use it
when the baker's seam overwrite is not wanted, and expect differences to a direct bake
there.

## The layout (`master_unwrap.py`)

`blender -b LOW.blend --factory-startup --python master_unwrap.py -- unwrap.json`
runs read-only and never saves the file.

1. **Guards.** The unwrap checks the LOW contract, face keys (prefix and index range),
   duplicates and modifiers.
2. **Charts.** Loop triangles join across edges that are inside the group, smooth
   (the corner normals on both sides are equal), below `split_angle_deg` and in the same
   density class. Hard edges are always chart borders.
3. **Parametrisation.** Each triangle is unfolded, rotated about the shared edge into the
   plane. This is an exact isometry, so every master texel has exactly the master density.
   Growth stops before any positive-area overlap, so doubly curved corners split into
   more charts. The `seed` option copies shapes from an existing unique layer instead,
   and falls back to unfolding when distortion exceeds 1.25.
4. **Rotation and packing.** Each chart is rotated to its minimum-area rectangle; the
   stored quantities do not depend on UV orientation. Packing is deterministic
   skyline bottom-left. Each box includes a gutter of `margin + 1` texels per side.
   The last page shrinks to the smallest power of two that holds its charts.
5. **Validation at Blender's texel centres** `((x + 0.501)/W, (y + 0.502)/H)`.
   The result must have 0 texels claimed by two faces, and every face at least 3x3 texels
   and 3 texels wide. How closely this raster matches the baker's own coverage is measured
   per run (`layout_check`, below).
6. **Immutable result.** An existing geo directory is refused unless `extend` is set.
   Extending is append-only: new groups go into free space or onto new pages, and old
   charts never move.

The unwrap writes these outputs:

- `master.json` (the manifest)
- `master_uv.npz` (page-local loop UVs, a page and a chart per polygon)
- `master_plan.json` (every face is an owner)
- `master_freeze.json` (the in-session `UV_Master`, in `uv_fingerprint.py` format)
- `low_contract.json`
- `charts_M<k>.npz` (face and chart rasters, plus the ambiguous-border mask)
- `unwrap_report.json`

## The runs (`master_bake.py`)

```
python master_bake.py recipes --master M/master.json --from bank_a.json [...] \
       --maps NORMAL,AO,OPACITY --run R2_D --out R2_D.json
blender -b LOW.blend --factory-startup --python master_bake.py -- bake R2_D.json
```

The `recipes` step merges the bank recipes' regions by identical HIGH set (one receiver
per source and HIGH set; see Limits, receiver partition). It refuses
differing ray parameters and writes an ordinary `bake_owner_maps.py` recipe on
`UV_Master`, with production scope, the master freeze and the LOW contract.

The `bake` step creates `UV_Master` in session. Faces outside the master sit at
(-2, -2), so they are never baked. It then runs the **unchanged** `bake_owner_maps.py`
source with one asserted override, `normal_space='TANGENT'` -> `'OBJECT'`, plus the
optional `keep_faces` tolerance. There is still one bake entry point and no copied guard
code.

The post-step records the following:

- **Hit fraction per face**, from the run's own OPACITY. A solid-class face below 0.98
  is a FAIL and never enters the manifest as data.
- **HIGH provenance**: name, file sha256 and face count.
- **Run data**: ray parameters, Blender version, seconds and image hashes.
- **`layout_check`**: texels the baker hit outside the master raster. The fixture gives 0.
  A real mesh can give a few isolated texels where a texel centre falls exactly on an
  outer chart edge (a rasteriser tie). Such a texel lies in the ambiguous-border band, so
  it is never sampled. More than a handful, or any such texel off the border band,
  means the layout and the baker disagree: stop and find out why.

A face x map that another run already produced needs `--replace`.

## The derive (`derive_maps.py`)

`blender -b LOW.blend --factory-startup --python derive_maps.py -- recipe.json`

The recipe is the ordinary bake recipe plus `"master"`. One recipe works with two
executors.

1. **Reused guards.** `bake_owner_maps.py` runs with `preflight_only`. That covers scope,
   the input contract, the UV freeze of the target layer, modifiers and the exact owner
   receivers through `keep_faces`.
2. **Master guards.** The derive refuses with "rebake master run X" when any of these
   hold:
   - the LOW contract differs;
   - the npz hash differs;
   - a scope face x map has no master data;
   - the producing HIGH names or file hashes differ;
   - the ray parameters differ;
   - the Blender version differs.

   It also checks the density ratio: below 0.75 it refuses, below 1.5 it warns.
3. **Per target texel.** The derive rasterises the target triangle at Blender's texel
   centres; faces outside 0..1 produce no texels. It takes the barycentrics, finds the
   same point in the master, and samples it.
4. **Sampling.** Sampling is constrained by partitions. A master texel is usable only
   in the sample's chart, off the ambiguous border band, with the nearest texel's hit
   status, and optionally with the same tile ID. Weights of unusable texels are zeroed
   and the rest renormalised. Filters:

   | Map | Filter |
   | --- | --- |
   | NORMAL, AO | `auto`: bilinear point up to 4 master texels per target texel, `footprint` above |
   | OPACITY | nearest status (binary like the baker) |
   | EMIT | nearest; IDs are never averaged |

   `footprint` takes S x S samples over the target texel (S = ceil of the density ratio),
   mirror-clamped into the target triangle like Cycles. `auto` decides per face by its
   density ratio. The reason for the split: a direct bake casts one ray per texel centre,
   and its 16 samples jitter only inside the one HIGH triangle that ray hit. On a dense HIGH
   that is a point sample, and a bilinear point sample of the master matches it best. A
   bilinear sample reads the master's 2 x 2 texels, which is at least a quarter of the
   target footprint up to ratio 4. Beyond that it aliases wherever the HIGH varies inside
   one triangle (textured or coarse HIGHs), so `auto` switches to `footprint` there and
   the report lists every face point-sampled above 4. `soft` is an option.
   `id_partition` (split NORMAL/AO by EMIT tile ID) exists but measured worse on roof
   normals (eave p95 8.0 vs 6.6 deg): a 16-sample EMIT blends IDs at tile edges.
5. **NORMAL to tangent space.** This replicates `RE_bake_normal_world_to_tangent` on the
   baker's own frame. MikkTSpace runs on the preflight receiver itself, because tangents
   weld only inside the extracted receiver. It runs on a scratch copy: quads stay quads,
   ngons become their loop triangles (`Mesh.calc_tangents` refuses ngons), and the
   receiver's corner normals are exact float custom normals. Per texel:
   - `T = sum w_i T_i`
   - `N = sum w_i N_i`; flat faces use the whole polygon's face normal (`triangle->normal`
     = `face_normal_calc`, as in the Blender 5.0.1 source), which the report compares with
     the flat faces' corner normals
   - `sign = (sum w_i s_i) < 0 ? -1 : 1`
   - `B = sign * cross(N, T)`
   - `x = solve([T|B|N], G n)` with `G = M3^T M3`, then normalise.
6. **Owners only.** Members are never written. Misses stay unassigned (START). Classes
   outside the target `opacity_classes` are written solid 1.0. The target `margin` is then
   replayed as the baker runs it (see "The margin, as Blender does it"): IMB_filter_extend
   with its 4-neighbour gate, one pass per receiver in the baker's order.
7. **Drop-in output.** The derive writes `<MAP>_<page>.exr/.png`, `owners_<page>.npz` and
   `derive_report.json` with the bake_report keys. `uv_fingerprint.py check`, compose and
   the QA tools read it unchanged.

`derive.uv_from_plan: true` builds the target layer in session from the plan's `uv`
lists. A candidate layout can then be derived before any `.blend` carries it.

## Acceptance (`compare_maps.py`)

The texel set is the derive's owner raster, eroded 2 texels. Direct roof bakes are near
point samples with steep, discontinuous content, so a quarter-texel sampling phase alone
can cost as much as a raw threshold. Raw per-texel thresholds therefore come with a smooth
subset and a per-face median:

| Map | Criterion |
| --- | --- |
| NORMAL | all texels: mean < 2 deg, p95 < 6 deg; smooth subset: mean < 1, p95 < 3; per-face median < 1 deg |
| AO | mean abs difference < 0.03; after 3x3 box < 0.015; per-face mean < 0.05 |
| OPACITY | > 99 % agreement away from edges, > 97 % overall, solid classes 100 % |
| EMIT | R > 99 % on ID-interior texels, G < 0.02, B > 99 % |
| Coverage | 0 texels without master data |
| Margin (NORMAL, EMIT; whole page) | the written set (texels that differ from START) is an L1 opening of radius `margin`, in the derived map and, as a check of the rule, in the direct one; on a page where the direct bake wrote every owner texel, replaying the derive's margin on the direct bake's own owner values reproduces the direct margin (max abs < 1e-5) |

The eroded interior never sees the margin, which is why the margin has its own check.
Gutter values are also reported, next to the owners' outermost ring they are filled from:
written-set agreement, the angle (NORMAL) and R agreement (EMIT). They are not pass/fail.
A gutter copies the ring, and the ring lies outside the interior on purpose (sampling
phase at chart edges). A gutter difference that tracks the ring's is not a margin error.

A frame error is face-wide and a sampling error is local, which is why the per-face
median is the frame check. Report a failure with its diagnosis; never loosen a threshold.
Remedies, in order:

1. An ID partition for roof normals (a derive only). It failed on Korean TC R2.
2. A class density factor (rebake that run only). It passed on Korean TC R2.

`compare_maps.py render` renders each variant alone with the same RTS 3/4 camera and two
opposing grazing suns. It also writes luminance differences and a contact sheet.

## Tests

`python -m pytest scripts/test_master_derive.py -q`

- **Always (pure numpy):** texel centres, UV-skip, isometric unfolding, analytic
  positions through rotated, mirrored, scaled and cross-page charts, the tangent round
  trip against an independent transcription of the Blender formula (a flipped sign must
  fail), partitions, the packer and the metrics. The margin: `extend_fill` against a
  line-by-line transcription of `IMB_filter_extend` (including page borders), L1 diamond
  growth, the per-receiver overwrite and its exact crop, and the L1-opening check telling
  an L1 fill from a square one. Minification: at ratio 6 and 8 the footprint filter tracks
  the box mean of the master texels (rms 0.05 and 0.03 on +-1 noise) while a point sample
  aliases (0.67 and 0.68); `auto` switches above 4. The host EXR reader is checked on a
  hand-written EXR.
- **With `QA_BLENDER`, optionally `BLENDER_GATE`:** a fixture LOW (sheet, bent strip,
  flat ngon, flat ridge, members) and a relief HIGH with holes and tile-ID emission,
  derived onto two layouts and compared with direct bakes, margin check included. It also
  checks that the four guards refuse and that a flipped sign fails the comparison. Claim
  it only from one complete pytest run.

## A layout or resolution change, step by step

1. **Scope the master once per geometry.** Groups = the faces each bank HIGH was built for
   (its recipes' regions, over every layout that will be derived). A new bank on the same
   geometry is `extend: true`; old charts never move.
2. **Density covers the future layout.** `reference_plans` include the planned layout (or
   `density` is set by hand) so its owners stay >= 1.5x below the master; a denser layout
   than master/1.5 warns, master/0.75 refuses. The layout is immutable, so raising the
   density later means a new master directory (`out`).
3. **Bake every bank in one gated Blender session**: `master_bake.py recipes` per bank and
   map set on the host, then one `bake` step per run (the gate wait dominates the cost).
4. **After the new UV freeze, derive**: copy each direct recipe, point `plan`, `freeze`,
   `pages` and `uv_name` at the new version, add `"master"` and a new `out_dir`, and pass
   all recipes to one `derive_maps.py` call. A refusal names the run to rebake.
5. **Check** with `uv_fingerprint.py check` on the derive reports, the texturing QA and a
   render review. Where a direct bake of the new layout exists, `compare_maps.py compare`.

## Cost

A master of every face at 2x density holds about 6.5x the owner texels of one direct
bake. It pays off after a few UV iterations. Load one master page per map at a time.
Keep EMIT in float32, because half precision collides tile IDs, and never store normals
lossy.

## Limits

- **HIGH coverage:** faces no HIGH covers have no master data. Unsharing them needs a
  HIGH first.
- **Version-sensitive:** Blender equality is not an in-game result. The contract,
  fingerprint and MikkTSpace are all Blender-version-sensitive.
- **Receiver partition:** a selected-to-active ray starts along the receiver's
  barycentric-interpolated vertex normals (`calc_point_from_barycentric_extrusion`). Those
  are the normals of the extracted receiver mesh, so they bend at vertices the receiver
  shares with faces that were cut away. The master bakes one receiver per source and HIGH
  set; a direct bake cuts per page and region. Smooth faces next to such a cut therefore
  differ locally, and no derive can remove that without rebaking with the target's cut.
- **Margin mode:** `baker` reproduces the direct bake's margin, including a later receiver
  overwriting an earlier one's texels in reach; `owners` never overwrites a hit, and then
  differs from a direct bake where charts of two receivers lie within `margin`.
- **The exec of `bake_owner_maps.py` is anchored:** any edit to that script needs the
  fixture test again.

## AoP evidence (Korean TC R2)

Specimen: bank R2 (tower lower eave), 119 faces (95 S18c owners + 24 S18f eavefix faces),
Blender 5.0.1. Outputs: `Texturing_11/Claude_CP2/bake_master/5c92518b7651/` (final master,
`proof/compare_R2.json`, renders) and `5c92518b7651_d220/` (first master at 2x everywhere).

- **Layout.** 220 px/m (2 x p99 109.5 of S18c + S18f), EAVE_CUTOUT 330 px/m; 30 charts on
  one 2048 page, 0 shared texels, density error 4e-15, narrowest face 18 texels. At 2x
  everywhere it fitted one 1024 page. `covered_outside_layout` was 1 texel per run, the
  same texel both times: (764, 131) on the outer edge of face 55, inside the border band.
- **Master runs.** NORMAL+AO+OPACITY 19 s and EMIT+OPACITY 11 s of bake time (16 samples,
  one 1.09 M-face HIGH each). 70 ROOF_TILE faces are 100 % hit. 29 of 49 EAVE_CUTOUT faces
  are below 35 % hit: the bank HIGH does not cover the under/back band. The direct bakes miss
  there too, so both carry filler (journal claude-02: eave alpha is analytic).
- **Derives.** 2-12 s per recipe, with guards at about 0.3 s and no HIGH loaded; all 12
  recipes of the fix round ran in one 72 s Blender launch.
- **Acceptance** after the margin fix (`derived_fix/`, `proof/compare_fix_main.json`, PASS;
  every pair against its own direct bake):

  | Pair | NORMAL mean / p95 | Per-face median | AO | OPACITY | EMIT R | Margin | Verdict |
  | --- | --- | --- | --- | --- | --- | --- | --- |
  | S18c roof P2048 (70 faces, vs `bake/`, `tile/`) | 0.83 / 2.78 deg | <= 0.64 deg | - | - | 100 % | replay exact | PASS |
  | S18c eave P1024 (25 faces, vs `bake/`, `tile/`) | 1.51 / 4.74 deg | <= 0.66 deg | - | - | 99.94 % | L1 | PASS |
  | S18f eavefix P1024 (24 faces) | 1.05 / 4.66 deg | <= 0.59 deg | 0.0067 | 99.98 % | 100 % | L1 | PASS |
  | TEST layout (90 deg + mirror, 1.5x) | 0.75 / 2.68 deg | <= 0.53 deg | 0.0070 | 99.94 % | 100 % | L1 | PASS |

  "Replay exact": replaying the derive's margin (2 receivers in bake order) on the direct
  bake's own owner values reproduces its margin to 1.8e-7 (NORMAL) and 1.5e-7 (EMIT), 0
  texels off. One pass over all hits misses 390 texels, the old square fill 3088
  (`proof/margin_replay_check.json`). "L1": the written sets of both maps are L1 openings
  of radius 4. Every first-round derive fails that check (74-710 texels unexplained,
  `proof/compare_old_round_margin.json`). The TEST layout existed only in session
  (`uv_from_plan`) and is compared with a direct rebake of that layout. The S18f
  "all 119 faces" pair is informational only (`proof/compare_fix_composite_info.json`):
  its reference is a composite of two direct bakes with other receivers, so its margin
  cannot match.
- **What failed first, and why.** The first derive grew the margin with an 8-neighbour
  gate (a square) in one pass over all hits. On the S18c eave pair that gave 2.66 / 6.06
  deg, a FAIL. It was first misread as back-facing hits and a growing hit region. The
  hit-set diagnosis took the derived OPACITY after its fill as the hit mask, so fill texels
  counted as hits. The fix (4-neighbour gate, per-receiver replay) needed no rebake.
- **What remains.** Every texel above 20 deg on the S18c eave pair (68 of 16115) lies on
  the 19 faces whose receiver vertex normals differ between the direct bake's cut and the
  master's; the 6 faces without such a change have none (`proof/seam_vnormal_check.json`;
  see Limits). Face S12_Groups_B:137 is back-facing on 57 % of its texels in the direct
  bake and 58 % in the derive: the HIGH/ray setup of that face, not the derive. Fixing it
  needs its cage or rays fixed and its master run rebaked.
- **Gutters** (reported): S18c roof gutter 2.03 / 7.22 deg against 2.38 / 8.34 on the
  owners' outermost ring it is filled from (one-pass fill: 5.69 / 18.6); on the eave pages
  the ring itself differs by 5-7 deg mean at the hit/miss borders, and the gutter follows it.
- **Density.** The first master at 2x everywhere (`5c92518b7651_d220`, one 1024 page, no
  class factor) also passes with the fixed margin (`d220/proof/compare_d220_fix.json`):
  S18c roof 0.83 / 2.79, S18c eave 1.81 / 5.83, eavefix 1.25 / 5.80, TEST 0.86 / 3.31 deg.
  The eave p95 sits just under 6 there, against 4.7 at 3x, so the class factor stays for
  headroom.
- **Filters.** Against these direct bakes (ratios 1.37-3.21) the footprint filter is worse
  than the point sample on every pair (S18c roof 1.10 / 3.70 with a 1.05 deg face median,
  S18c eave 2.32 / 8.03, eavefix 1.87 / 8.30, TEST 0.96 / 3.69;
  `proof/compare_fix_variants.json`). Hence `auto` = point up to ratio 4.
- **Fixture, one pytest run** (2026-09-29, 25 passed in 38 min, the time mostly spent
  waiting at the machine gate): both layouts pass (NORMAL 0.20 / 0.40 and 0.19 / 0.39 deg,
  per-face median 0.21), the margin check passes and the gutter written sets agree 100 %.
  A flipped bitangent sign raises the per-face median to 7.7 deg and fails, all four guards
  refuse, and `covered_outside_layout` is 0.
