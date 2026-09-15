---
name: havok-destruction
description: Understand, inspect and adapt Age of Empires III DE destruction assets - the *_damaged.gr2 piece model, its Havok 2018 *_damaged.hkt rigid-body tagfile (piece types, keyframed vs dynamic, parent links), the .dmg damage templates and the animfile Destruction logic - and make a damaged model carry animation bones (animtrans pattern) so a unit keeps animating and its attachments through the damage stages. Uses scripts/havok/hkt_*.py, gr2_pieces.py, dmg_*.py; no converter needed. Triggers on "damaged model", "hkt", "destruction", "pieces fall", "mast falls", "simskeleton", "animtrans", "the damaged model doesn't animate", "progressive damage stopped working".
---

# Destruction models (.hkt / _damaged.gr2) and animated damage stages

## How the pieces work (decoded 2026-09-13/15, verified in game)

- `*_damaged.gr2`: one skeleton whose bones are the pieces (`wall_wood_solid_0006`, `mast_wood_solid_3`,
  `sailrigging_cloth_solidhide_112`, proxies `hulla_proxy`, `chunkb_proxy`, `on_death`, `bone_debris_*`),
  flat hierarchy under the root; 3-4 "Combined" meshes whose vertices carry a per-vertex bone index
  (`BoneIndices`, one bone per vertex) - `gr2_pieces.py` lists every piece's vertex cloud and bbox.
- `*_damaged.hkt`: Havok 2018 TAG0 tagfile, `hkpPhysicsData` with one rigid body per piece, **named like the
  bone**. Behaviour lives in four `hkSimpleProperty` keys: `0x12A001` type (0 stage piece, 1 on-death,
  6 base proxy, 7 group proxy), `0x12A002` sim (3 dynamic, 4 keyframed, 0 base), `0x12A003` material
  (1 stone, 2 wood, 3 metal, 4 cloth), `0x12A004` parent body index. The engine honours these and the motion
  type; initial velocities in the file are ignored. `hkt_props.py FILE.hkt [substring]` prints them.
- Keyframed pieces with a parent follow that parent body (rigging strips follow their mast); dynamic pieces
  (masts, hull halves) fall under physics when their group breaks.
- Treasure Ship: sails (cloth + bars) are welded INTO the mast pieces; Fuchuan: sails are separate pieces.
- Animfile: `<logic type="Destruction"><p1>damaged</p1><p99>intact</p99>`, Death component = damaged model,
  `.dmg` templates = projectile impact system (`boneimpact*`), `simskeleton` = the skeleton the anims are
  sampled on (battleship: the damaged model; frigate: none).

Tools: `hkt_read.py` (summary), `hkt_props.py` (properties), `hkt_patch.py` (in-place property/motion edits),
`hkt_write.py` + `hull3d.py` (write a tagfile from a body list - used for the test cube; the generated cube never
destructed progressively, so authoring a new hkt from scratch is unproven - cloning a vanilla pair is).

## Animated bones in a damaged model (the vanilla `animtrans` pattern)

Battleship/Frigate damaged models repeat every animated bone of the intact model:
```
mast_wood_solid_N (physics piece, no anim track)
 └─ animtransNN   (no track; rest = the piece's world transform inverted -> world identity)
     └─ bone_sail.. / bone_flag_civ / bone_banner..   (same LOCAL transform as in the intact model)
```
so one anim pair drives both stages and a falling mast takes its sails and flags. Requirements found by test:
1. intact root name == damaged root name == anim track group name (else the anim does not bind to the
   damaged/sim skeleton: destruction works, nothing animates) - rename the damaged root in place if needed;
2. the damaged root keeps its vanilla 90-degree Y rest, so the anims must carry **no track for the root** and
   **no track for bones hung directly under the root** (flags, muzzles, impact points) - only for bones under
   animtrans (else the model turns 90 degrees / the flag and cannons sit off);
3. `<simskeleton>` = damaged model on the unit's anims (this also brought progressive destruction back);
4. the .hkt stays untouched: bodies are matched by bone name and the new bones have no bodies (like muzzles).

Build (all Granny-level, no converter): `scripts/havok/dmg_extract.py` (bones, pieces, labels, sail->mast from
the gr2 + the rig table from `rig_table.py`), `dmg_blender.py` (verification scene: pieces as vertex groups, sail
bones under their masts, actions incl. a mast-fall demo), `dmg_bonetable.py` (animtrans + chains as a GXO bone
table), then `gr2_addbones.py --inplace --map mirror` and `gr2_splitmesh.py` (new mesh data goes into the
damaged file's own sections 3/4 - other sections crash the loader). Full sequence in **ship-sails**.

## What did not work (do not retry blindly)
- A converter-built damaged model (GXO route) crashed nothing but animated nothing: its bone `b` lines were
  written parent-relative while the GXO form is absolute, and its root was still `bone_main`. Converters also
  drop the per-vertex bone bindings of destruction models and crash on the big ones - never round-trip a
  `_damaged` model through one; edit the vanilla file in place.
- The test cube (own hkt from `hkt_write.py`): pieces existed, no progressive damage, chipped piece vanished;
  the map-based test harness crashed the editor three times. Cloning vanilla pairs is the proven route.

Related: **gr2-granny-edit** (formats, GXO grammar, verification ladder, converter note), **unit-bones**,
**ship-sails**; memory notes `hkt-destruction-format-decoded`, `animtrans-pattern-damaged-models`.
