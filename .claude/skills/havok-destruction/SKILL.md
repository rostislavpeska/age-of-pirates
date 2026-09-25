---
name: havok-destruction
description: Inspect and adapt Age of Empires III DE destruction assets - fractured building geometry, donor Havok body graphs and collision hulls, per-piece GR2 bindings, damage templates and animation XML. Includes the in-game-confirmed Korean Town Center donor adaptation and the animated ship animtrans pattern. Use for damaged models, HKT files, progressive damage, falling pieces, simskeleton and destruction export failures.
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
destructed progressively). Creating a new body graph from scratch remains unproven here.
Preserving a donor graph while replacing building geometry and refitting its collision hulls
worked for the Korean Town Center: user-confirmed in game on 2026-09-25.

## Building architecture donors

For building architecture swaps, a similar footprint is only a donor-selection
hint. Compare named bodies/bones, piece vertex bindings, rest transforms, parent
properties and collision envelopes. Bone count, body count and geometry-piece
count need not agree: donors can contain proxies, attachment bones and unpaired
base geometry. Preserve those distinctions instead of forcing a one-to-one
count. For a new donor, first verify an unchanged clone, then one bounded piece
change in both intact and damaged states; inspect progressive damage and death
in game before replicating the technique. Reuse a confirmed baseline when one
exists. An offline match does not prove physics behavior.

For Chinese Town Center donors, read [the confirmed Korean adaptation and measured
building frames](references/chinese-tc-experiment.md). It records the successful
artifact hashes, fracture/binding recipe, collision-hull changes and export checks.
The observed HKT/GR2 axis and unit conversion differs from simply reading both
as world coordinates. Start with simple materials when the task is a physics proof;
final UVs and custom texture production need not delay that test.

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
2. in these ship donors, the damaged root keeps its vanilla 90-degree Y rest, so the anims must carry **no track for the root** and
   **no track for bones hung directly under the root** (flags, muzzles, impact points) - only for bones under
   animtrans (else the model turns 90 degrees / the flag and cannons sit off);
3. `<simskeleton>` = damaged model on the unit's anims (this also brought progressive destruction back);
4. the .hkt stays untouched: bodies are matched by bone name and the new bones have no bodies (like muzzles).

That 90-degree rest is donor-specific. The early Chinese Town Center has an
essentially identity `BONE_MAIN` in both intact and damaged models. Inspect the
actual skeleton and inverse-world matrices; do not impose the ship rotation on buildings.

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
  the map-based test harness crashed the editor three times. This failed graph-generation recipe is distinct
  from the later successful Korean building adaptation, which preserved the donor graph and refitted hulls.

Related: **gr2-granny-edit** (formats, GXO grammar, verification ladder, converter note), **unit-bones**,
**ship-sails**; memory notes `hkt-destruction-format-decoded`, `animtrans-pattern-damaged-models`.

## Reference: the Havok 2018.1 Content Tools manual (not in the repo)

Havok's own 2470-page manual (filter manager, rigid-body / destruction export, preview, hkt tagfiles) is
proprietary documentation, so it is NOT committed to this public repo. The owner keeps it in OneDrive, shared by
all the owner's devices: `DE Converter\docs\Havok_2018-1-0_Content_Tools_Manual.pdf`, with a full text extract
`...Manual.txt` beside it (2.1 M characters; grep it: `grep -n -i "keyframed" ".../docs/Havok_2018-1-0_Content_Tools_Manual.txt"`,
each page starts with `=== page N ===`). Use it for the meaning of hkt fields and filters before guessing; the
engine-specific facts (the four hkSimpleProperty keys, ignored velocities) are the mod's own measurements above.
