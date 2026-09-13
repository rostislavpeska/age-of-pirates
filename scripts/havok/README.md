# Havok destruction experiment (2026-09-13) - NOT production

Tools written while decoding AoE3DE's `*_damaged.hkt` destruction files and trying to author one
for a test cube. State and findings: see the memory notes `hkt-destruction-format-decoded`,
`destruction-authoring-pipeline`, `gxo-converter-runs-under-wsl-wine`.

- `hkt_read.py`   - Havok 2018 TAG0 tagfile reader (type tables, items, records)
- `hkt_patch.py`  - in-place patcher (properties, motion, velocity, mass) - the sheriff experiments
- `hkt_write.py`  - writer: bodies -> tagfile (convex hulls via hull3d.py, boxes for proxies)
- `hull3d.py`     - small 3D convex hull
- `rig_cube.py`   - Blender background script: one bone per piece, FBX export in metres/Y-up
- `install_cube.py` - installs art + animfile + proto for zpTestCube
- `ddt_write.py`  - plain-colour DXT5 .ddt textures + .material
- `verify_freeze.py`, `exe_destruction_strings.py` - checks used during the investigation
- `pw.py`, `run_gen.py` - PrintWindow capture + editor automation attempts (harness, unfinished)

Verified in game: the engine reads the mod's .hkt and honours the 4 hkSimpleProperty values /
motion type; initial velocities are ignored. Open: the generated cube's corner piece vanishes at
death (suspected axis-sign of the GXO->engine mapping; untested flip is the installed file).
