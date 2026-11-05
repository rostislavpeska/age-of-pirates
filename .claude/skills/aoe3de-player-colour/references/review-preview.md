# Preview in Blender and verification

`scripts/details_review.py` tints the review scene with the game's base-pass formula:
`BaseColor x mix(white, PlayerColour, Details.R x Strength)`. One shared node group holds the
player colour and the strength. `set_player(1..8)` uses the vanilla `playercolors.xml` colours, `set_color_srgb()`
sets any colour, and `set_strength(0)` switches the tint off. `controls()` returns the two sockets for a sidebar panel.

## Install

- **Owner's live scene**: one MCP call, **logged first** per `blender-mcp-safety`. The call only adds nodes and at
  most one image; it never reloads other images and never saves:

  ```python
  import importlib.util as u; s = u.spec_from_file_location('details_review', r'<skill>/scripts/details_review.py')
  m = u.module_from_spec(s); s.loader.exec_module(m)
  print(m.install(r'<maps>/P2048_Details.png', basecolor_match='P2048_BaseColor', player=1)); print(m.selftest())
  ```

  `basecolor_match` selects the materials whose Principled Base Color comes from an image with that text in its
  name, path or `aop_final_path`. The Details node reuses the BaseColor node's UV input (UV0). Pass `final_path` when
  a review watcher swaps candidate maps by that property.
- **Required map and role:** supply the exact Details path from the source material/role manifest, with its
  hash and BaseColor association. A filename alone does not establish shader packing. The file must exist;
  an undeclared role, undecoded DDT or unsupported shader requires an explicit unsupported state at the caller.
  `install()` raises for a missing declared map or an empty material selection before changing the scene.
- Details is loaded as **Non-Color** by resolved path. A same-name image at another path, or an sRGB image
  already in use, is preserved. The binder reads **R only**, including when G/B are nonzero, per
  [the disassembled base-pass contract](engine-and-vanilla.md). The earlier `R*(1-B)` was a preview workaround
  for magenta missing-file placeholders, not engine behavior; those legacy groups now fail explicitly and
  remain unchanged for a deliberate migration on a saved copy.
- Re-running `install` is idempotent: it swaps the image and does not stack a second tint.
  Existing groups must have the supported formula and connected BaseColor/Details/output/coordinates;
  conflicting or partial named graphs fail without replacing them. The material must contain one Principled shader.
  Selection follows upstream BaseColor links through AO mixes and the supported tint group. Already-tinted
  materials outside `basecolor_match` are excluded. Use a narrow source identity filter, not the broad default,
  when binding different Details pages. Explicit texture coordinates are retained through AO chains;
  conflicting coordinates fail. For implicit coordinates the caller must name the source mesh's UV0 layer
  with `uv_map` (the historical default `UVMap` is not source identity evidence).
  Omitted `player`/`strength` preserve existing shared controls; a new group starts at player 1, strength 1.
  Passing those arguments changes the shared scene control explicitly.
  `uninstall()` restores the direct BaseColor links.
- Anything that drives the owner's screen (a GUI Blender, viewport screenshots) needs the owner warned first (AoP
  AGENTS.md rule 11). Background runs (`blender -b`) on a copy do not.

## Verify (background, on a COPY of the owner's HEAD scene; never save the original)

1. Preserve the original source and failed graph, the declared map hashes/roles and a valid control. On a copy,
   attempt a missing declared path: require an explicit error and unchanged graph. Do not render a placeholder
   and call it a valid import.
2. Install with the candidate Details. `selftest()` passes. The masked faces render as the expected tint (e.g. player
   1 on a light base comes out near (0.22, 0.22, 0.91) linear), and unmasked faces are identical to before.
3. `set_player(2)` gives red, and `set_strength(0)` restores the untinted base.
4. `uninstall()` restores the original graph on a disposable copy; it is a scene-wide operation.
5. Render the owner's sheet with **2-3 player colours** (blue, red, green) on the fields in question: close views at
   eye level plus one overall view, before and after, both **from HEAD**. A "before" from an older final or a
   different merge hides or adds unrelated elements, and the owner reads that as a regression.

Texture-space sanity check without Blender: `pc_common.ingame_albedo(bc8, R, player)` gives the same albedo per texel.

## Tested boundary (INC-580 / Blendify #62)

`test_details_review.py` runs the actual adapter against an offline bpy graph double: R-only formula, strict
missing-file failure, image identity, valid-repeat preservation, target scope, AO/UV links and malformed graphs.
Run it with `test_player_colour.py`. This does not decode texture pixels, execute Blender or certify an importer.
No automatic importer hook is provided by this module. A consumer which creates or replaces materials must call
the adapter with declared role paths and verify its saved output. In particular, the historical Industrial castle
4UP recipe built only BaseColor/Normals/Masks and did not call this adapter. Authoring, runtime-model imports and
reference copies each require their own pinned saved-model replay and blue/red response before claiming coverage.

`scripts/extraction_adapter.py` provides the explicit read-only descriptor for
Blendify `allocation_delivery.extract_saved_blender(group_adapter={path,sha256})`.
It pins the exact binder source bytes and supports its finite R-only group, one
sRGB BaseColor image, one Non-Color Details image and named explicit UV0 input.
Unknown groups, legacy blue suppression, extra nodes, missing/ambiguous images,
muted nodes and changed clamps fail. Further AO/multi-image BaseColor graphs
require a separately verified role adapter; this module does not guess roles.
`test_extraction_adapter.py` covers this boundary. Fixture proof is not saved-model
proof. The retained Korean TC R3 native readback (INC580, 2026-10-21) contains
the legacy ten-node/eleven-link `R*(1-B)*Strength` group plus an AO multiply;
it correctly refuses this adapter. A modeller must supply a separately preserved
and explicitly migrated supported source before a new authorized native replay.
The rejected R3 ornament remains rejected; this diagnostic creates no art approval.

After changing player colour, verify the rendered target actually changes. A scene
can retain unused legacy colour nodes while the visible material uses a constant
blue input. Follow links from the material assigned to the rendered object, then
compare matched blue/red images in independently declared target rectangles:
`scripts/check_render_response.py BLUE.png RED.png --regions regions.json --out result.json`.
Regions are `{ "gable": [x0,y0,x1,y1] }` in image pixels. Check each requested
target separately: a changing lower band cannot prove that the gable responds.
The check measures responsiveness only; material linkage, source identity and
engine validation remain required. Regression fixtures are in
`scripts/test_render_response.py` (INC-277, Korean castle decoration r13).
