# Korean r70d texture candidate, 8 October 2026 (night run)

Owner brief: the Korean Barracks, Stable and Town Center textures were "too perfect, too geometric";
make them illustrative, slightly exaggerated AoE3 style with imperfections - walls with damage, mould
and ripped plaster, much less Barracks player colour (courtyard wall should read as stone), dirtier
hanji (darker than the walls), the roof bake kept but with moss/mould, doors more illustrated.
Texture-only; no UV, geometry, alpha, material or GR2 change.

## Where it is

- **AoP branch `korean-textures-r70`** (owner: "Install in mod. It's fine. Rather separate branch.").
  `Pirate-rework` is untouched apart from two skill commits and keeps the r62 textures.
  Switch back: `git checkout Pirate-rework`. Restore the seven textures on this branch only:
  `python <work>/install/install_r70.py --rollback` (git restore from bcfd0236).
- Installed files (7): Barracks/Stable/TC `mata` BaseColor and Normals, Barracks Details.
  Masks, materials, GR2, HKT, shared `matc` and TC props are unchanged.
- Restart the game (art needs a process restart) and place **Korean Barracks**, **Korean Stable** and
  **ZP TEST Korean Town Center - Destruction Test** in the Scenario Editor.
- Installed revision: **r70d** (commit history on the branch keeps r70b and r70c for comparison).
- Library packages (candidate, with the saved Painter project, maps, change masks, views, sources,
  QA and HANDOFF.json): AoE Buildings > Korean > Colonial > 2d-assets > barracks / stable /
  town-center > versions > `r70d-texture-candidate` (Korean repo commit 1f37551, report
  `research/Colonial_Textures_15/README.md`, KTC-176 notes 113-115).
- Blender: the game-light review rig (Korea_Skirmish lightset, game shader formula with player colour,
  six cameras) is open on the owner's PC with r70d (`handoff/Korean_GameLight_r70d_FINAL.blend` in the
  session work folder; the same rig and scripts are archived in each package under `sources/`).

## What changed

| Feature | r60 | Candidate |
| --- | --- | --- |
| Plaster | flat grey-white, L 183, stain 0.005 | owner's Elector two-coat recipe: cream top-coat islands (Painter white-coat Dirt run) over a warm under-coat, relief in the normal map, calm field with dirty edges, rising damp and algae at the foot, soot under the eaves, rips at feet/corners exposing darker rubble; stack guard on shared cells |
| Barracks player colour | 9.9 % of texels, mid-grey base, courtyard caps/bands blue | ~1 % of the visible surface: courtyard caps and bands are stone, skirt boards and headers lost player colour, the hall band is dark lacquered board with two worn pinstripes, gable emblems kept |
| Hanji | blue-grey, clean | warm tea-stained paper, clearly darker than the plaster, grime halo along the lattice, tears/patches, a replaced pane |
| Doors | plain planks | Korean iron fittings (cloud-end hinge straps, studs, ring pulls), deeper seams, lit bevels, scuffed lower boards; gate chips show raw wood |
| Red lacquer timber | flat fill | grain under lacquer, worn arrises, grimy feet |
| Stone | warm, flat | neutral granite with grain, soft joints, pillow shading, sparse moss on tops |
| Roofs | bake | bake untouched; overlay moss pads darker than the tile, water streaks, eave mould |

## Evidence (agent checks, not owner acceptance)

- Measured against 18 vanilla JP/CN atlases (Painter-free metrics: luma, chroma, warmth, stain,
  detail, moss, player-colour share).
- Independent QA each round: alpha byte-identical, untouched roof texels byte-identical, protected
  regions unchanged, every changed texel inside a recipe claim, mip halos (Lanczos mip 4) clean after a
  48 px gutter refresh, normal sign checked against an independent gradient per atlas, DDT dry run
  (headers/sizes identical to the installed files).
- Senior-artist judge (strict, AoE3 DE standard): r70b 6/10, r70c 7/10, r70d 7/10 (criteria average 7.3).
- Encoder proven byte-identical on the untouched r60 BaseColor and Normals before encoding.

## Known limits

- Not seen in game by the agent: access to the game window was not granted overnight.
- Barracks courtyard plaster strip shares the stacked hall cell (40 faces); it can only become stone
  with a minimal UV move of 12 faces plus a GR2 re-export (owner decision).
- Stable and TC player-colour skirts were out of scope (unchanged); the Barracks now uses a pinstripe
  style - owner decision whether the set should match.
- The Barracks lattice shares 1,057 texels with props (RackPost/RackCross); kept darkened.
- Judge's remaining notes on r70d: roof moss reads dark olive at game zoom (the TC gains no visible green),
  a soft damp line repeats on the stacked Barracks bays, Stable window-frame specks.
