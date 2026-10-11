# Open questions only a texture test, the game or the owner can answer

Recorded 2026-10-11 after the evidence rider. Each answer, once known, goes into the profile or the decision rules
with its evidence, and the line here is closed. None of them can be settled by more offline UV measurement.

## Owner decisions

1. **Which reading carries the head target**: the bone-region estimator over all faces (comparable with reference
   ratios measured on shipped units; on the evidence rider a 1.3 target then forces the head island to 1.61x and the
   page L2 past its target, because the deliberately shrunk hidden scalp is counted) or over visible faces only (1.38x,
   page L2 1.027)? [Method](method.md) section 8 has both runs.
2. **Hands**: the evidence run gave hands a 1.15x multiplier (its brief asked for sharper hands), which reads
   1.10x the torso by part labels and 1.05x on the bone-region estimator; the reference units the game
   layer measured give hands less than the torso. Keep, drop to 1.0, or follow the references?
3. **A skinned weapon on the body page** runs at body density; reference units may give weapons several times more
   (the game layer records it). Visibly blurry in game? A separate page changes the page budget.
4. **Hidden UV area**: about 26 % of the page sits on faces never visible at one idle key. Down-weight more (the hidden
   cap applies only to fully hidden islands today) once more clips confirm the visibility?

## Texture test (paint, encode, look)

5. With painted DXT textures at RTS zoom, is an 8 px gutter enough, or are 16 px needed (16 px costs 3 % density)?
6. Do part-border seams disappear under paint as expected; does the torso's back-centre seam show from behind?
7. Is painting (by hand or with an image model) faster from SLIM islands or from straightened rectangles?
8. Does the engine sample unit textures with wrap or clamp (decides whether a 4 px page border is safe)?
9. Where do the player-colour areas (the Details map's red channel) fall relative to the seams?

## In game (on the test device, never the main machine)

10. The game camera's real pitch (47 deg is assumed in every visibility number).
11. Do seams show in walk, attack, death and weapon swings; how much do elbows, knees and hips stretch under skinning
    (only the bind pose is measured)?
12. Does a 1.3x head read better at game distance?
13. Do tangents and normal maps survive the new seams through the converter, which drops tangents today?
14. The real GPU vertex count after normal and material splits, and whether the converter exports only the active UV
    layer or all of them.
