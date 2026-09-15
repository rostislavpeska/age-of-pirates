Treasure Ship furling sails - backup v2 (2026-09-15), state before the damaged-model root rename.
Mod files: as installed (intact 8-sail Granny build, damaged Granny build with animtrans, 8-sail poses, animfile with simskeleton).
sources/: Blender scenes (zptreasureship_rig8_clean.blend = intact rig with poses; zptreasureship_dmg_rig.blend = damaged rig for
verification), FBX exports used for the poses, cm8.gxo (converter dump of the rig = bone table + sail labels), dmg.json (damaged model
extraction), dmg_bones.gxo (bone table for the damaged model), intact_bones.gr2 / dmg_bones.gr2 (vanilla files with bones appended,
before the sail split), vanilla_intact.gxo, and the pristine vanilla gr2 files from the .bar.
Rebuild: scripts/havok/gr2_addbones.py (--inplace --map mirror) then gr2_splitmesh.py, see scripts/havok/README.md.
