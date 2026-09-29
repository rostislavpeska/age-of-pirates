# Preview in Blender and verification

`scripts/details_review.py` tints the review scene with the game's base-pass formula:
`BaseColor x mix(white, PlayerColour, Details.R x (1 - Details.B) x Strength)`. One shared node group holds the
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
- **Missing file is safe**: Blender samples a missing image as magenta (1, 0, 1), and the (1 - B) factor turns that
  into no tint. The scene may point at a Details file that does not exist yet and still look unchanged.
- Re-running `install` is idempotent: it swaps the image and does not stack a second tint.
  `uninstall()` restores the direct BaseColor links.
- Anything that drives the owner's screen (a GUI Blender, viewport screenshots) needs the owner warned first (AoP
  AGENTS.md rule 11). Background runs (`blender -b`) on a copy do not.

## Verify (background, on a COPY of the owner's HEAD scene; never save the original)

1. Render before install. Then install with a Details path that does not exist and render again: the two renders
   are **byte-identical**.
2. Install with the candidate Details. `selftest()` passes. The masked faces render as the expected tint (e.g. player
   1 on a light base comes out near (0.22, 0.22, 0.91) linear), and unmasked faces are identical to before.
3. `set_player(2)` gives red, and `set_strength(0)` restores the untinted base.
4. `uninstall()` restores the renders from step 1.
5. Render the owner's sheet with **2-3 player colours** (blue, red, green) on the fields in question: close views at
   eye level plus one overall view, before and after, both **from HEAD**. A "before" from an older final or a
   different merge hides or adds unrelated elements, and the owner reads that as a regression.

Texture-space sanity check without Blender: `pc_common.ingame_albedo(bc8, R, player)` gives the same albedo per texel.
