# r62 deterministic re-export, 7 October 2026

The owner requested re-export of both buildings and their destruction variants.
The active author candidate remains r60; roof appearance is still unresolved.

- Fresh current-Blender extraction: 263 Barracks and 209 Stable objects, including
  protected pots. All exterior positions, corner normals, UVs, material/body
  assignments and ordering exactly match the accepted fracture inputs.
- Four intact/damaged GR2s were serialized again; six DDTs encoded again from
  canonical r60 maps. All ten outputs are byte-identical to the installed r60/r59
  files. This confirms reproducibility; it is not a new visual correction.
- Strict native checks: Barracks 23 PASS, Stable 25 PASS, zero FAIL/SKIP. This
  includes density, source UV correspondence, materials and destruction checks.
- All ten freshly generated files were reinstalled, then hash checked against the
  tested stage. HKT, material/XML, Details and protected shared assets are unchanged.
- Four front/back mapping previews were rendered from actual GR2 and decoded DDT
  data and inspected. These use geometric normals; they exclude animated props.
  They do not certify mapped-normal shading or in-game physics.
- Scoped XML: six files, zero errors, one donor-metadata warning. Stable damaged
  Default_Material is not used by rendered meshes; those bind defined materials
  mata, matb, matc and matz. No speculative material change was made.

The snapshot contains actual outputs, extraction payloads, scripts, before files,
hashes, QA, handoff and images. The author/Painter/Photoshop sources remain in the
r60 snapshot selected by CURRENT.json. Cloud propagation is not verified.
The export adds no runtime bytes or texture pages and no source file to the mod.

## Manual testing

Reload/restart the game and place **Korean Barracks** (`zzKoreanBarracksPhysics`)
and **Korean Stable** (`zzKoreanStablePhysics`). Both include damaged variants.
No agent game test occurred. Re-export permission is not roof appearance acceptance.
Paid image calls: zero. KTC-176 unread notes: none. Missing public skill-mirror
paths are tracked separately as INC-139; they did not affect export capability.

Source/recovery: `$AOP_KOREAN_REPO/CURRENT.json.military_current.runtime_export`.
