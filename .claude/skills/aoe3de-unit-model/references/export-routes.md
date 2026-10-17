# Export routes for skinned unit models

How a unit model gets from Blender into a `.gr2` the game draws like vanilla, what is proven, and the falsifiable
round trip that runs at G0, before any blockout. Facts are measured on vanilla files (2026-10-10/11, with this
package's scripts, listed in [the skill](../SKILL.md)) or documented in the cited skills.

## 1. What the file must contain

- **Skeleton**: the donor's, byte for byte (names, parents, order, Transform, InverseWorld, LOD error). The skin
  checker must report 0 bones added, removed, renamed or re-parented.
- **Vertex**: the vanilla 40-byte skinned layout - Position real32x3 @0, Normal binormal_int8x4 @12, Tangent
  binormal_int8x4 @16, DiffuseColor0 normal_uint8x4 @20, TextureCoordinates0 real32x2 @24, BoneWeights
  normal_uint8x4 @32, BoneIndices uint8x4 @36 - with one UV set and the vertex-colour channel present. Fill like DE
  full-LOD files: colour (255,255,255,255), Normal.w = 127, Tangent.w = +/-127 carrying the handedness; tangents from
  MikkTSpace on the final data ([materials and textures](materials-textures.md), section 6). A clean export splits
  vertices only at UV seams and hard normals (the "welded" count, `scripts/measure_units.py`); vanilla buffers carry
  extra tangent-only splits that are not a target.
- **Weights**: at most 4 influences; every vertex sums to exactly 255 by the generic recipe
  ([blender-organic-modeling](../../blender-organic-modeling/references/skinning-pose-tests.md), section 4: drop
  influences under 0.5/255, renormalize, floor plus largest remainder; no used influence may end at 0, because a 0
  weight marks an empty slot; `rig_table.py --quantize` applies the same steps); descending order; no bone twice in a
  vertex; unused index slots repeat slot 0's index (`scripts/vertex_fill.py` reports all
  of these on any gr2).
- **Bindings**: BoneIndices index the mesh's own BoneBindings palette, which binds to the skeleton by name. The body
  binds the 18 body bones; a skinned weapon mesh binds only its chain bones.
- **Meshes and materials**: one body mesh with one material, plus a second mesh or submaterial only for a vanilla
  reason (a skinned weapon chain, cutout cards on the same page, a small cover mesh); see
  [vanilla unit measurements](vanilla-unit-measurements.md).

## 2. Frames, units and the working scale

- gr2 data is the engine frame (y up) in engine units: a rider is about 2.1 units tall
  ([vanilla unit measurements](vanilla-unit-measurements.md), "Shape and symmetry").
- A converter GXO dumped from a vanilla gr2 is the **GXO frame** - x across, y along, z up, engine (x, y up, z) =
  (-x, z, -y) - at engine/2.54, with every triangle's corner order reversed (the frame map mirrors) and V flipped to
  Blender's convention. Verified on iron_rider_0 against the converter's own dump: bones 1.6e-7 (rotation conjugated by
  the frame map, translation mapped and divided by 2.54); positions, UVs and weights equal at 1e-4 and every
  triangle in the same orientation (`scripts/unit_gr2.py` `to_gxo_point` / `to_gxo_matrix`). Its `vn`
  lines are **not** the stored normals (lengths 0.32-1.38, no fixed relation): never read normals from a converter
  dump. A converter GXO of a converter-made gr2 is in engine units ([gr2-granny-edit](../../gr2-granny-edit/SKILL.md),
  "Frames, units").
- A converter FBX of a vanilla gr2 imports into Blender at engine/2.54/100 (a 2 m rider at 0.008 units, the armature
  carrying that scale; `fbx_check.py` reports the ratio). Use it for inspection only: modelling at that size breaks
  every absolute distance (blender-asset-conventions, section 1), and applying the armature scale changes the bones.

### Working-scale recipe (settled 2026-10-11)

1. Build the scene from the donor gr2, no converter involved:
   `blender -b --factory-startup --python scripts/donor_to_blend.py -- DONOR.gr2 <scratch>/donor.blend`.
   Armature space is the GXO frame **in engine units** (`--scale 1`): every object transform is identity, nothing is
   ever applied, and the bones are the donor's rest transforms. Only the bones the donor's meshes weight keep the
   deform flag (iron_rider_0: 23 of 32), so automatic weights and Data Transfer cannot land on Root, Neck, Prop, Toe,
   Ponytail or `bip01_attach_rt`. The 23 are the union the pose tests and the audit use; while weighting one mesh,
   narrow the flags to that mesh's own list (body: the 18, the five chain bones off - `bone_handle` sits exactly at
   the right-hand pivot; flail: the chain bones only), as
   [blender-organic-modeling](../../blender-organic-modeling/references/skinning-pose-tests.md) section 1 says. The donor's bone order is stored in the armature's `gxo_bone_order` property
   (Blender lists bones depth-first). The donor's meshes come in as `REF_*` overlays with their weights. The .blend
   holds vanilla-derived data, so the script refuses an output path inside the consumer repository.
2. Model on that armature at that scale; the working mesh is a child of the armature with an Armature modifier and
   vertex groups named exactly as the bones.
3. For pose tests, write the mesh with `<consumer-root>/scripts/havok/rig_table.py ... --skinned --scale 0.393700787`
   (1/2.54): the model GXO then has the units and frame of the converter's dumps of vanilla clips, which is what
   `pose_sim.py` binds against (section 4).
4. The scale a GXO needs for the converter's GXO -> gr2 direction: **engine units, `--scale 1`** (measured
   2026-10-11 on the Pyeongon specimen: the converter takes GXO numbers as engine units without rescaling; at 1 the
   skeleton lands within 7.8e-6 of the donor and positions within 5e-9, at 0.3937 everything is 0.3937x). The
   donor-preserving writer (section 6) reads the same `--scale 1` GXO.

Proof of steps 1 and 3 (2026-10-11, iron_rider_0): donor_to_blend then rig_table `--skinned --scale 0.393700787
--quantize` on the two `REF_` meshes gives back the converter's dump - 32 bones in the same order with the same
parents, matrices within 7.8e-6 (Blender stores bones in float32); 829 + 147 GXO vertices (exactly the welded counts);
identical (position, UV, quantized weight) sets at 1e-4 and identically oriented triangles; `pose_sim.py` posed vertices
within 2.5e-6 of the dump's at keys 0 and 144 of `oprichnik_attack_a`. The skill test
`tests/test_unit_model_scripts.py` repeats the round trip against the gr2 itself.

## 3. G0: the falsifiable export round trip, before the blockout

Route B (new skinned geometry) is unproven, so the export risk is tested first, on a specimen, before any modelling
deliverable depends on it. Run at G0, in this order:

1. **Donor**: choose and record it ([rider skeleton](rider-skeleton.md), section 8): readable (not
   Oodle-compressed: `scripts/measure_units.py`), every clip the unit plays keys only bones it has
   (`scripts/track_coverage.py --animfile ...`).
2. **Scene**: `scripts/donor_to_blend.py` (section 2). Rerun the Blender-side round trip on the `REF_` meshes: the
   output must equal the donor's data (the skill test does exactly this; a failure stops G0).
3. **Specimen**: a small skinned mesh on the donor armature at working scale - for example a sleeve over one forearm
   and a short strip on a weapon chain, 100-300 triangles, 2-3 influences where joints bend, one material with its own
   small page, one UV set, weights quantized (`rig_table.py --quantize`).
4. **Writer**: produce the specimen gr2 with the candidate route (section 6): the converter from the rig_table GXO
   (through `gxo-convert` and its Wine route where the host blocks the exe; check which backend
   `converter.py --check` reports before calling it), or a donor-preserving writer when one exists for 40-byte data.
5. **Ladder**: steps 1-6 of section 7 on the specimen gr2, each result recorded.
6. **Bench**: exactly one game test ([aoe3de-model-test-unit](../../aoe3de-model-test-unit/SKILL.md)) of the specimen
   on the donor's animfile, on the device the project allows: it draws, it is lit like the vanilla rider beside it
   (no dark shading), and it bends with the clips where `pose_sim.py` said it would.
7. **Lint**: ask the owner for the consumer's unit lint profile and unit texture class now (section 9); the
   specimen is the first file that profile is tried on.

Only after the bench passes does the blockout (G1) start. A failing step is reported with its evidence and the owner
decides (another writer, route A when the shape can stay vanilla, or a stop); the blockout never starts on hope.

## 4. The writer for pose tests (proven offline)

`<consumer-root>/scripts/havok/rig_table.py` writes a Blender scene in the GXO form. Sail mode (default) is unchanged.
`--skinned` adds what `pose_sim.py` and the converter read: `mt` per material, `b` lines (in `gxo_bone_order` when
set), and per mesh `m`, `mb` (bones carrying weight), `mm`, per GXO vertex `v`/`vn`/`vt`/`vw`, `fg`, `f` (Blender's
CCW winding, which matches the converter's dumps). The mesh is read with its Armature modifiers off (rest shape, other
modifiers applied). It refuses unweighted vertices, weighted groups that are not bones, a missing UV layer, and n-gons
unless `--triangulate` (a quad working mesh in a pose test; an export copy is triangulated explicitly first).

```bash
blender -b <scratch>/work.blend --python <consumer-root>/scripts/havok/rig_table.py -- <scratch>/work.gxo \
        --skinned --armature <donor>_rig --scale 0.393700787 --triangulate --quantize
python .claude/skills/aoe3de-unit-model/scripts/clip_decode.py --archive Art/animation_library/cavalry/CLIP.gr2 \
       Art/animation_library/cavalry/HORSE_CLIP.gr2 --out-dir <scratch>/clips
python .claude/skills/aoe3de-unit-animation/scripts/pose_sim.py --model <scratch>/work.gxo --anim <scratch>/clips/CLIP.gxo \
       --frame N --out <scratch>/posed.obj [--mount HORSE.gxo --mount-anim <scratch>/clips/HORSE_CLIP.gxo]
```

The clip GXOs come from `clip_decode.py`, which reads the clip's curves straight from its gr2 (no converter; every
key a pose; key 0 equals the converter's key 0 within 6e-7). A converter `--format gxo` dump of a clip is a pose at
key 0 only: its later keys leave the curves ([rider skeleton](rider-skeleton.md), section 6), and pose_sim refuses
any key whose bone-driving 3x3 has |det - 1| > 0.001. Model GXOs of vanilla files (the horse) still come from the
converter (`gxo-convert`): its model dumps match the gr2 within 1.6e-7. Decoded, key 144 of oprichnik_attack_a seats
iron_rider_0 on yabusamehorse_0 (horse_1-5_attack_A) at z 0.457..1.175.

## 5. Route A: in-place edit of a vanilla gr2 (proven)

For a unit whose shape stays vanilla: a retexture clone, a dropped part, moved existing vertices.

- Work on the raw vanilla file with the byte-level tools ([gr2-granny-edit](../../gr2-granny-edit/SKILL.md)):
  internal renames (`gr2_rename.py`), another vanilla skeleton whose joints match (`gr2_reskeleton.py`), dropped
  triangles or moved vertices (`gr2_editmesh.py`). No new vertices, so weights never need a transfer.
- Prove it with the skinned-model-check baseline workflow
  ([skinned-model-check](../../skinned-model-check/SKILL.md)): the vanilla file against itself first, then the edit
  against vanilla with 0 re-weighted vertices.
- Consumer policy may limit this route (AoP allows a cloned vanilla gr2 only for a distinct unit made as a retexture,
  geometry unchanged).

## 6. Route B: new skinned geometry (proven offline 2026-10-11; the bench test is open)

A body that changes shape is a mod-made model, not a clone. Facts that make this route risky:

- Converter output (GXO or FBX route) rewrites vertex data in its own format; on a rigid ship it shaded dark in game,
  "even with tangents it was never right" (gr2-granny-edit core rule). The converter route also lost faces on
  buildings (`skinned-model-check`).
- Converter output is usually Oodle-compressed, which the repository reader cannot open.
- A converter-built gr2 with a second root bone is not drawn at all; an attach bone must be a child of the one root
  (`unit-bones`).
- The GXO lines rig_table writes for the converter beyond what pose_sim reads (`mt`, `mm`, `fg`, unit `vn`) follow the
  converter's own dumps; that the converter accepts them is unverified until G0 step 4.

Candidate writers, each to be proven by the G0 round trip (2026-10-11 run on the Pyeongon G1 r2 body + flail with
the H1 UVs, 1270 triangles, every ladder step recorded in C:/work/unit-process/export (HANDOFF.json)):

| Writer | Data | Status |
| --- | --- | --- |
| Converter, GXO -> gr2 from `rig_table.py --skinned` | not the vanilla layout | **rejected on evidence**: accepts the GXO at `--scale 1`; writes a 32-bit Oodle1 file (repo reader, `gr2_fixups`, `vertex_fill`, the anim viewer all refuse it; the game DLL reads it); vertex layout Position, BoneWeights, BoneIndices, Normal real32x3, UV0 - **no Tangent, no DiffuseColor0**; rebuilds the skeleton (7.8e-6 off, not byte for byte); unused weight slots do not repeat slot 0; re-quantizes weights (26 of 753 body vertices off by 1/255). The same on the 2026-10-11 G0 specimen. |
| `<consumer-root>/scripts/havok/skinned_gr2.py` (donor-preserving, a NEW file around the donor) | skinned 40-byte | **proven offline**: donor skeleton byte for byte, the donor's own vertex type, MikkTSpace tangents on the final data (recomputed on the written file: median dot 1.0, sign 100 %; the Tangent.w -127 path of mirrored UVs and hard edges proven on a synthetic mesh through Blender's MikkTSpace, and real hard edges on the helmet specimen: 21 split-normal positions), 0 orphan fixups, no donor mesh/vertex/index/UV/texture data left (bytes AND geometry, see below); game DLL read on both routes identical to the repo reader; vertex fill identical in kind to iron_rider_0; skin check 0 FAIL; seated pose test on 445 keys of 42 clip pairs within 0.0002 cm of the Blender export; inside the horse at alive keys 2.3-17.1 cm per key (5.4-17.1 cm as the worst key of each pair) against the donor's 22.2-31.1 cm (24.4-31.1), at death keys up to 32.0 cm (donor 30.9); lit like vanilla in the anim viewer's game-shader port. The game bench (section 7, step 7) is still open. |
| `<consumer-root>/scripts/havok/multimaterial_gr2.py` (donor-preserving, append-only) | rigid 24-byte only; refuses non-rigid weights | proven on building data |
| Same writer for a **rigid attachment** (hat, rigid weapon) on a vanilla attachment donor | rigid 24-byte | **inferred**: its accepted layout (Position real32x3 @0, Normal binormal_int8x3 @12, BasicStaticPackedData0 uint8 @15, Tangent binormal_int8x3 @16, BasicStaticPackedData1 uint8 @19, TextureCoordinates0 real16x2 @20) is exactly the layout of every vanilla rigid unit attachment measured (steppe_rider_sword, light_cavalry_sword_age02, naginata_lance, dragoon_gun1, yabusamerider_bow, keshik_hat_rank02; `scripts/vertex_fill.py`, 2026-10-11). Needs one bench test before anything relies on it. |

The rigid route bears on the weapon-rig choice ([rider skeleton](rider-skeleton.md), section 7): a rigid prop on
`Bip01 Prop1` could reuse it, a skinned chain cannot.

What `skinned_gr2.py` refuses (repair round 2026-10-11, after an independent verification broke the first version):

- **Scale (INC-251).** A 0.3937x GXO (the pose-test scale) written at `--scale 1` passed every byte check of the
  first version and the unit lint. The writer now needs a GXO bone table that lists every palette bone, every GXO
  joint within 1e-3 units of the donor joint at `--scale` (the specimen: 2e-7; the 0.3937 GXO: 0.85), and the meshes
  sitting on the donor skeleton (`skeleton_fit.py`: vertex-to-dominant-bone distance p50 <= 0.20 and p95 <= 0.45
  units, mesh / weighted-joint height ratio 1.0-2.2; the 20 DE riders measure 0.107-0.156, 0.196-0.371 and
  1.19-1.90; the 0.3937x model 0.266, 0.786 and 0.47). The fit check is coarse (unit-system errors, gross offsets);
  the joint check is the fine one. The same fit runs in the lint (`unit_fit`).
- **Donor data beyond bytes (INC-252).** The vanilla body and whip handed back through Blender at scale 1.0001 held
  no donor byte run but 100 % of their positions and UVs. The clean proof now also measures, per output mesh, the
  share of its vertices on donor positions (as stored, and after normalising each mesh pair by bounding box or by
  centroid and RMS radius), on donor UV pairs (as stored or V-flipped) and whether its welded topology equals a donor
  mesh's; more than 1 % or an equal topology refuses. A re-export that drops one vertex changes the topology
  signature (the iron body did), so positions and UVs carry that case.
- **No output from a failed build.** The file is written as `OUT.partial` and renamed only after verify, the clean
  proof and the tangent recheck (median dot >= 0.999, sign >= 0.99) pass; an existing `OUT` survives a failed
  overwrite.
- Also refused, each with a test: the donor as output, a compressed, 32-bit, non-gr2 or bad-CRC donor, a donor
  whose skinned layout is not the vanilla one, a donor with two skeletons or models, two materials in one mesh,
  v/vn/vt/vw count mismatch, a face past the vertices, unreferenced vertices, zero tangents, Blender missing (no
  other tangent rule is substituted).

## 7. The ladder (every export)

1. `<consumer-root>/scripts/havok/gr2_dump.py OUT.gr2`: CRC ok, meshes, bindings and counts as expected.
2. `<consumer-root>/scripts/havok/gr2_fixups.py OUT.gr2`: 0 orphan fixups.
3. A native-loader read where the consumer has one (AoP: `gr2_lint` `dll_read`), identical across work-folder lengths.
4. Vertex layout and fill identical to vanilla; every weight sum 255 (`scripts/vertex_fill.py OUT.gr2`).
5. `skinned-model-check/scripts/run_skin_check.py OUT.gr2 --baseline DONOR.gr2 --out <scratch>/skin_check
   --max-influences 4`: no FAIL; the vertex-count WARN is expected for new geometry (`--out` is required and must be
   outside the repository).
6. `aoe3de-unit-animation/scripts/pose_sim.py` with decoded clips (section 4), seated on the vanilla horse at key 0
   of the unit's clips and at the extreme keys: rider z range within a few cm of the donor posed by the same keys on
   the same horse, no rider vertex inside the horse beyond a small tolerance. The vanilla calibration (yabusame on its
   horse, cavalry idle, z 0.406..1.179) is a key-0 number: it proves the seat, not an extreme key.
7. Exactly one bench test ([aoe3de-model-test-unit](../../aoe3de-model-test-unit/SKILL.md)) on the device the project
   allows for game tests.

Blender and the game file must agree on mesh count, triangle count, bone list and influence maximum.

## 8. Animfile and attachments

- A rider's horse animfile includes the rider animfile and seats it with
  `<attach a="Rider" frombone="hotspot" tobone="ATTACHPOINT" syncanims="1" />`; every anim name the unit plays exists
  in both files, and the attack blocks of horse and rider come from one vanilla unit
  ([aoe3de-unit-animation](../../aoe3de-unit-animation/SKILL.md)).
- The horse is a vanilla horse referenced by archive path; no horse gr2, material or texture is added.
- Every custom attach bone has a `<definebone>` in the animfile and exists in every model the component can show;
  engine tags (`Bip01 Prop1`, `R HAND`, `HEAD`, `ATTACHPOINT`) need no declaration. Run `attachment_check.py`
  ([aoe3de-model-attachments](../../aoe3de-model-attachments/SKILL.md)).
- Animfiles and `.material` files are runtime art XML: CRLF on disk, or the engine ignores them silently.

## 9. Consumer export gates

A consuming mod may gate game tests on its own lint. AoP (2026-10-11): `gr2_lint --profile unit_rider_1024`
(`unit_profiles` in the consumer's scripts/havok/gr2_lint_profiles.json), **PROPOSED for the owner**: skeleton,
skeleton fit (`unit_fit`, the scale gate), weights, vertex layout and budget against references measured on
iron_rider_0 and keshik_rider_rank01 (both pass 16/16), the UNIVERSAL UV density floor (`texel_density`, as for every
model: no unit exemption) with the organic UV gate profile's higher density minima on top (`unit_density`,
`--pose-npz` for the visible-weighted part), and the unit texture class `unit_human_1024` (1x1024, PROPOSED from the
owner's 2026-10-11 words): texture_budget FAILS until his confirmation is recorded in the owner message store. Never
skip the lint or invent a profile.
