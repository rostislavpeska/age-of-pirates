# scripts/havok - Granny (.gr2), Havok (.hkt) and sail-rig tools

Skills that document the workflows: `.claude/skills/gr2-granny-edit`, `ship-sails`, `unit-bones`,
`havok-destruction`. Run everything from the repo root: `python scripts/havok/<tool>.py`. Blender tools:
`blender -b --python scripts/havok/<tool>.py -- args`.

No converter is part of the repo. The pipelines need a few gr2 <-> FBX / GXO conversions; do them with whatever
converter you have (`converter.py` wraps a configured one or, in its default manual mode, prints what to produce
and waits for the file). The owner's converter-specific skill (`gxo-convert`, gitignored) lives in OneDrive
`DE Converter\claude-skills\`.

## Granny .gr2 (raw vanilla files; converter output is usually Oodle-compressed and unreadable here)
- `gr2_read.py`      reader (sections, relocations, types, CRC) - imported by every other gr2 tool
- `gr2_dump.py`      structural dump: skeleton, meshes (layout, bindings, bbox), models, animations/curves
- `gr2_pieces.py`    destruction models: per-piece vertex clouds; optional match against a GXO's sail meshes
- `gr2_pose.py`      static-pose anim vs rest skeleton (delta rotations, scale/shear) - how the Fuchuan furls
- `gr2_addbones.py`  append bones in place from a GXO `b` table (absolute transforms; chains; existing parents)
- `gr2_splitmesh.py` cut labelled triangles into new rigid meshes on other bones, vertex bytes verbatim
- `fbx_check.py`     Blender: compare a model's FBX with the vanilla FBX (positions/normals/UVs) + renders
- `fbx_preview.py`   Blender: render an FBX with one colour per mesh
- `rig_table.py`     Blender: bone table + sail_* mesh vertices of a rig scene in GXO form (no converter needed)
- `converter.py`     conversion wrapper: backend from the gitignored converter.local.json (wine-wsl / native /
  command) or manual mode (prints the request, waits for the output file); --format gr2|gxo|fbx
- `anim_tracks.py`   keep/drop tracks in an anim GXO, pin the track-group name (Blender bakes every bone; poses
  must key only the sail bones)

## Sail rig (Treasure Ship worked example; see ship-sails)
- `sails_analyze.py`  split the welded intact mesh into loose parts, stats, renders -> split.blend
- `sails_rig.py`      separation + scale chains + bars + idle/walk poses + FBX exports (the rig build)
- `sails_reexport.py` re-export a rig with flag bones dropped and custom normals cleared
- `sails_separate.py` separation only (cloth + bars as objects, vanilla armature), for inspection
- `sails_clean.py`    tidy a rig scene for a human (collections, packed placeholder textures)
- `dmg_extract.py`    damaged gr2 -> JSON (bones, pieces, sail labels, sail->mast)
- `dmg_blender.py`    Blender verification scene of the damaged rig (pieces, sails under masts, demo actions)
- `dmg_bonetable.py`  animtrans + sail chains as a GXO bone table for gr2_addbones.py
- `gxo_sails.py`, `gxo_sails_dmg.py`  converter-route builds (vertex data re-encoded -> dark in game; kept as
  GXO grammar references and label/frame logic; superseded by gr2_splitmesh.py)
- `sails_cluster.py`, `sails_groups*.py`, `sails_uv.py`, `sails_roundtrip.py`, `sails_build.py`  earlier
  analysis stages (superseded, kept for the record)

## Havok .hkt
- `hkt_read.py`   Havok 2018 TAG0 tagfile reader (summary of bodies)
- `hkt_props.py`  destruction properties per body (type / sim / material / parent)
- `hkt_patch.py`  in-place patcher (properties, motion, velocity, mass)
- `hkt_write.py` + `hull3d.py`  tagfile writer from a body list (test-cube experiment; unproven in game)

## Experiment leftovers (test cube / harness, 2026-09-13, not production)
`rig_cube.py`, `install_cube.py`, `ddt_write.py`, `verify_freeze.py`, `exe_destruction_strings.py`,
`pw.py`, `run_gen.py`.
