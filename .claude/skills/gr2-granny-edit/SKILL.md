---
name: gr2-granny-edit
description: Read, inspect and edit Age of Empires III DE Granny .gr2 models at byte level with the repo's own tools (scripts/havok/gr2_*.py) - dump skeletons/meshes/animations, append bones (with parent chains, from a GXO bone table), cut triangles out of a mesh into new rigid meshes bound to other bones, and verify a built file before it ever reaches the game (reader CRC -> converter loads it -> Blender finds the geometry identical to vanilla). Use whenever a vanilla model needs extra bones or a mesh split and its vertex data must stay byte-identical (the converter re-encodes meshes and they shade dark in game). Triggers on "add bones to the model", "split the mesh", "edit the gr2", "inspect the gr2", "why is the model dark", "does the game load this gr2".
---

# Granny-level .gr2 editing

**Core rule (measured on the Treasure Ship, 2026-09-15):** every model the game must render exactly like
vanilla is built from the **raw vanilla gr2 with in-place edits**. The converter (GXO or FBX route) rewrites
the vertex data in its own format and the result shades dark in game (no tangents; even with tangents it was
never right). The converter is used only for **animations** and as a **loader test**.

All tools live in `scripts/havok/`; run them from the repo root with `python scripts/havok/<tool>.py`.
Vanilla files come raw (uncompressed) from the .bar (**bar-extract** skill); converter output is
Oodle1-compressed and the reader cannot open it - that is expected.

## Tools

| tool | what it does |
|---|---|
| `gr2_read.py FILE` | `Gr2` class: sections, relocations, type tree, CRC check (`crc_check()`), generic `read()/array()`; prints the skeleton |
| `gr2_dump.py FILE [--bones] [--tracks]` | skeletons (parents, positions), meshes (vertex layout, rigid / indexed / skinned, bbox, bone bindings), models, animations (track groups, curve formats per track) |
| `gr2_pieces.py DMG.gr2 [substring] [rig.gxo]` | per-piece vertex clouds of a destruction model (BoneIndices), optional position match against a GXO's sail meshes with an auto-detected frame |
| `gr2_pose.py MODEL.gr2 ANIM.gr2 [substring]` | a static-pose anim vs the model's rest: per bone delta rotation (axis/angle) and scale/shear matrix |
| `gr2_addbones.py VANILLA.gr2 TABLE.gxo OUT.gr2 --inplace --map mirror [--only ...]` | append bones from a GXO `b` table into the vanilla skeleton, in place (see below) |
| `gr2_splitmesh.py BONES.gr2 RIG.gxo OUT.gr2` | cut triangles whose vertices coincide with the GXO's `sail_*` meshes into new rigid meshes bound to those meshes' bones; vertex bytes copied verbatim |
| `fbx_check.py NEW.fbx VANILLA.fbx OUT_DIR` | Blender headless: loop-by-loop comparison (positions, normals, UVs) + renders |
| `converter.py --format gxo FILE.gr2` / `--format gr2 --bang` / `--modify-gr2 calculatetangents` | the converter under Wine with any option (see **gxo-convert**) |
| `anim_tracks.py IN.gxo OUT.gxo --keep bone_sail` / `--drop Object02` | filter animation tracks in GXO form |

## Facts that were each wrong once (do not re-derive)

- 64-bit v7 file: magic 16 B, section table at 32 + SectionArrayOffset (=104), 44-byte section entries
  (compression, data offset, size, expanded, align, first16, first8, reloc offset/count, marshalling
  offset/count). **CRC32 = zlib.crc32(file[104:])**. Pointers are 8 bytes at **4-byte** alignment; array =
  int32 count + pointer; variant array = type ptr + count + data ptr. Member type enum has a removed slot 6.
- Bone record 164 B: Name@0, ParentIndex@8, Transform@12 (flags 3, pos, quat xyzw, 3x3 scale/shear),
  InverseWorld4x4@80 = inverse(column-vector world).T, LODError@144 (1304.65 for added bones), ExtendedData@148.
- Mesh record 76 B: Name, PrimaryVertexData, MorphTargets, PrimaryTopology, MaterialBindings, BoneBindings,
  ExtendedData. TriTopology 132 B (Groups, Indices int32 or Indices16, rest empty). VertexData 44 B
  (Vertices variant array + VertexComponentNames + annotation sets). Vanilla vertex stride 24 (Position f32x3,
  Normal int8x3, pad, Tangent int8x3, pad, UV f16x2; destruction models replace the first pad by BoneIndices).
- **Section roles matter to the game's Granny DLL**: rigid models keep vertex/index data in sections 1/2,
  destruction models in 3/4. New data must be appended to the SAME section as the source mesh's data; writing
  a destruction model's new meshes into 1/2 crashed `granny2_age3de.dll` (the loader test caught it).
- Never move an existing array to another section (crashes the loader). Grow section 0 in place: insert after
  the array, shift every later offset (relocation sources/targets, first16/first8), or append new records at the
  end and only update counts/pointers (what `gr2_splitmesh.py` does).
- Vanilla damaged roots (`bone_main`) carry a **90-degree Y rest rotation**; intact roots (`Object02`) are
  identity. Any transform expressed relative to the root differs between the two models.

## Bone tables for the appender (`gr2_addbones.py`)

The table is a GXO text file with `b "name" parent m00..m22 tx ty tz` lines, as the converter writes them:
- **transforms are ABSOLUTE (model space)**, not parent-relative - chain bones repeat their parent's translation;
  the 3x3 is row-major (transpose to a column-vector rotation);
- parent = 1-based index into the table, 0 = root; existing bone names in the table are skipped but usable as
  parents (e.g. a damaged model's `mast_wood_solid_3`); parents may also be other new bones (scale chains);
- `--map mirror` = engine (x, y up, z) = (-gx, gz, -gy): the converter's frame for converter-made GXOs
  (engine units). A GXO dumped from a VANILLA gr2 is the same frame at engine/2.54 (Maya units) - scale it or use
  `--scale 2.54`. Verified: muzzle bones transplanted this way fire outward in game.
- Ready-made tables: the converter's GXO of any model that already has the bones (`converter.py --format gxo`),
  `scripts/havok/dmg_bonetable.py` (animtrans chains for a damaged model).

## Verification ladder (every step before a game restart)

1. `gr2_dump.py OUT.gr2` - CRC ok, bones/meshes/bindings as intended.
2. `converter.py --format gxo OUT.gr2` - the game's Granny DLL loads it (a Wine backtrace = the game would crash;
   the GXO also shows what the converter thinks the bones/bindings are).
3. `converter.py --format fbx OUT.gr2` then `fbx_check.py OUT.fbx VANILLA.fbx DIR` - every loop must match
   vanilla by position with normals < 0.1 deg and UV distance 0; renders in DIR.
4. Game test (**game-startup** skill; art changes need a full restart, the user closes the game).

## Frames, units, converters

- Blender rig scenes (`sails_*.py`): armature object scale 0.01, data in engine units, Z up, y along the ship,
  x across; **blender = M.T . engine** with the mirror map above.
- Converter FBX of a vanilla gr2 imports at engine/254 in Blender (units /2.54, then /100); converter-made
  gr2s import at engine/100. `fbx_check.py` reports the ratio (1.0 or 2.54 are the two sane values).

Related skills: **ship-sails** (the full sail pipeline that uses these tools), **unit-bones**,
**havok-destruction**, **gxo-convert** (converter under Wine; GXO grammar), **bar-extract**.
