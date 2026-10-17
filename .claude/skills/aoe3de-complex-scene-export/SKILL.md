---
name: aoe3de-complex-scene-export
description: "AoE3 DE adapter for complex Blender scenes (Home Cities, composite environments): the GR2 frame, in-place GR2 writers, ground attach bones and the vanilla-animation rule. Use with Blendify blender-complex-scene when moving, trimming, splitting or adding parts of a vanilla scene model."
---

# AoE3 DE complex scenes: the GR2 adapter

The method - live vs saved state, inventory of transform sources, measuring every edit against its source mesh, one
placement handle per independently moved part, the 1:1 proof and the stop rule - is generic: Blendify
[blender-complex-scene](../blender-complex-scene/SKILL.md) with its `scene_inventory.py` and `edit_match.py`. This
skill holds only what AoE3 DE adds. Worked recipe: Korean repo `tools/homecity_docks01.py` (docks01, game-tested
2026-10-17).

## Rules

1. **Never recompile vanilla ground or composite GR2s through whole-model FBX/GXO conversion.** It drops polygons,
   strips vertex buffers, alters UV precision and destroys Havok/destruction bindings (a 430 KB ground became 145 KB).
2. **Edit in place.** Drop triangles (`gr2_droptris.py`), add translated copies of existing triangles into the freed
   slots (its `"dup"`), move/turn vertices (`gr2_rotate_verts.py` `"translate"` / `"matrix"`). Every writer refreshes
   the bone-binding boxes (`gr2_bounds.py`); `gr2_lint` check `bounds` fails stale ones (a pier and a junk moved ~20 m
   with vanilla boxes were invisible in game).
3. **Keep the vanilla skeleton and the vanilla Idle.** A part moved away from the pivot that animates it swings around
   that far pivot ("exaggerated, jumping"): freeze it by renaming its track in the vanilla anim (`gr2_rename.py IN OUT
   track OLD NEW`: same length, same ASCII sort slot, a name no bone has; refused when the string is shared - the root
   track's name is also the track group's name) or give it its own ground bone (rule 4). Converter-made Idles
   (`gr2_rest_anim.py`) and root canonization / pivot moves (`gr2_bones.py`) misplaced the junks in three game tests
   although model and anim each checked exact: tested tools, not game-proven for this.
4. **An independently placed part = its own model on its own ground bone** (game-tested: the docks01 harbour junk).
   - Model: the vanilla model with every other mesh emptied (`gr2_droptris.py`); the part's mesh, skeleton and pivot
     stay byte-vanilla; its Idle is the vanilla anim referenced by archive path (`homecity\china\docks01\docks01_anim`).
   - Ground bone: the measured rigid move (vanilla part -> Blender part) appended to the ground model with
     `gr2_addbones.py GROUND.gr2 TABLE.gxo OUT.gr2 --inplace --map mirror --scale 2.54 --only bone_<name>`; the GXO
     b-table is in Blender coordinates (`b "root" 0 <identity> 0 0 0` then `b "bone_<name>" 1 <R^T row-major> x y z`).
     A re-run moves an existing bone with `gr2_bones.py` only when it changed (untouched records stay byte-identical).
   - Animfile: `<definebone>bone_<name></definebone>`, an `<attachment>` with the part model and the vanilla anim, and
     `<attach a="<part>" frombone="ATTACHPOINT" tobone="bone_<name>" syncanims="0" />` on the ground component (the
     street-tree `bone_pathnode_XX` pattern).
5. **Attachments that draw in the edited area but are absent from the scene still draw in game** (vanilla `china_boats`
   put a fishing boat inside the new pier; `rocks01`): remove them from the animfile with the owner's yes.
6. **Added props:** *modular* - its own GR2 (GXO + converter, section 4) on an attach bone; *conjoined* - joined into an
   existing environment mesh (market stalls into `bridgesandstuff_M0Shape`): Blender world vertices through the frame
   map, corner order reversed, material groups split, new vertex/index buffers packed.
7. **Runtime XML and `.material` files are CRLF** (`check_art_eol.py --fix`) and pass `xmlcheck.py`.

## 1. GR2 frame contract

$X_{gr2} = -2.54\,X_b,\; Y_{gr2} = 2.54\,Z_b,\; Z_{gr2} = -2.54\,Y_b$ (inverse: $X_b = -X_{gr2}/2.54,\; Y_b =
-Z_{gr2}/2.54,\; Z_b = Y_{gr2}/2.54$); for `edit_match.to_frame` the matrix is `[[-1,0,0],[0,0,1],[0,-1,0]]`, scale
2.54. Measured on docks01 (826 unchanged pier triangles): the map is a reflection (det -1), so a GR2 triangle is the
Blender loop triangle with its corner order REVERSED, and GR2 UV = (u, 1 - v). Blender's imported corner normals are not
the vanilla normals (median dot 0.65): normals/tangents come from vanilla vertex bytes.

- **GXO frame:** `v <x> <y> <z>` lines are Blender metric world coordinates; the converter applies the -2.54 mapping.
- **FBX importer bone trap:** imported bones get ~20.55 m display vectors along +Y; `bone.tail` is the engine
  attachment position, `bone.head` is shifted by -20.55 m in Y.
- The Blender homecity scene shows props at their skeleton REST pose, not at the Idle anim's key 0; a converter dump of
  a vanilla anim is valid only for its first frames (docks01_anim: scale 11.2 by frame 1264).

## 2. Removing buildings or clusters (`gr2_droptris.py`)

Triangle indices to drop = vanilla triangles with no edited counterpart: `edit_match.classify` (Blendify) on the
vanilla mesh and the Blender object mapped into the GR2 frame (kept / dropped / copies), then
`python scripts/havok/gr2_droptris.py <src.gr2> <plan.json> <out.gr2> --check`. Write a `.material` for the edited
clone referencing vanilla textures by archive path and point the animfile `<attachment>` at it.

## 3. Moving an attachment bone

Use `gr2_bones.py` `"move"` (rigid world transform, descendants follow, inverse-worlds recomputed, refuses a skeleton
whose stored inverse-worlds are not its rest). The older hand patch - Position at bone offset +16 and the inverse-world
translation at +128 set to the negated position, CRC recomputed - is valid only for a translation-only bone under an
identity parent.

## 4. Exporting new props (modular route)

Separate the prop from conjoined environment meshes; write a GXO (`mt "mata"`, `b "BONE_MAIN" 0 1 0 0 0 1 0 0 0 1 0 0
0`, `m`, `mb "BONE_MAIN"`, `mm 1`, interleaved `v`/`vn`/`vt` per vertex, `f` 1-based); `python
scripts/havok/converter.py --format gr2 --bang <model.gxo>`; a CRLF `.material`; declare the attachment and attach it to
a bone in the animfile.

## 5. Live scene tracking (WIP)

`scripts/tools/blender_scene_tracker.py` (uncommitted work in progress): `snapshot` / `diff baseline.json` (added,
deleted, moved with deltas, modified meshes), `timeline` (the `save_post` journal `blender_scene_journal.jsonl`),
`audit-repo` (live meshes vs repository `.gr2` face counts) and `install-handler --persist`. It drives the live session
on port 9876 (`blender-mcp-safety` R14: one session per port). Its snapshot/diff part is generic and proposed for
Blendify `blender-complex-scene`; `audit-repo` stays here.
