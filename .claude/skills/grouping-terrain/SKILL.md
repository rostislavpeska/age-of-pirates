---
name: grouping-terrain
description: Map and edit the terrain baked into a random-map grouping XML (game/randmaps/groupings) - cliff groups (ZP City / ZP Bridge ...), shoreline tilegroups, plateau heights, unit positions. Use when a cliff piece under a bridge, quay or wall shows the wrong cliff type, when a grouping's island/plateau must be raised or lowered, when units must be nudged by metres or a socket must become the last unit, or whenever the user asks "which tile is this", "map the grouping", "show me the cliffs". Triggers on cliffgroup, ZP Bridge, ZP City, grouping heights, bridge faces, move units in grouping, socket last.
---

# Grouping terrain: map it, then edit by tile coordinates

A grouping (`game/randmaps/groupings/*.xml`) carries its own terrain, not just units:

| section | what | coordinates |
|---|---|---|
| `<units><unit variation posx posz orientx orienty orientz>proto</unit>` | placed objects | **metres**, origin = grouping centre, 2 m per tile |
| `<tiles><tilegroup type="Shoreline" subtype=...><block ...>` | painted terrain tiles | **tiles** (startx/startz/endx/endz, inclusive) |
| `<tiles><cliffgroup type="ZP City">` / `"ZP Bridge"` / ... | cliff type per tile, drawn with the types from `data/clifftypes2.xml` | tiles |
| `<heights><tiles x z>v v v ...</tiles>` | vertex heights, one row per tile row; a plateau top is one repeated value (e.g. 5.250) | tiles |

Cliff types are per tile here, not per area: "this concrete piece is city type, I want bridge type" is
a `cliffgroup` block move, not a map-script change. `ZP Bridge` is the flat (zero-displacement)
variant of the city cliff meant to sit under `zpBridgeFace` props; the façade pieces are ~9 m wide
(2 per bridge side, spaced 9 m) and often overhang city tiles - that is the usual cause.

## 1. Map first (the user reads tile labels off the picture)

```bash
python .claude/skills/grouping-terrain/scripts/grouping_map.py game/randmaps/groupings/EU_Island_Bastille.xml <scratchpad>/bastille.png
python ... --flat            # +x right, +z up instead of the in-game 45-degree view
python ... --heights         # tint plateau heights, print the distinct values
python ... --units zpBridgeFace,PropsPoles
```

Default view matches the game camera: **+x = up-right (screen NE), +z = up-left (NW), bottom edge
= SE, left = SW**. Every cliff tile is labelled `x,z`; unit markers show metres with a facing arrow.
Put the PNG where the user can open it (Desktop; the IDE file card may not render) - they circle
tiles on it and give you labels back. Regenerate after every edit so they can confirm.

## 2. Edit by tile / metre, byte-preserving

```bash
S=.claude/skills/grouping-terrain/scripts; U="C:/Users/TIGO/Games/Age of Empires 3 DE/76561198347905238/RandMaps/groupings"
python $S/grouping_edit.py <file> list
python $S/grouping_edit.py <file> cliff --from "ZP City" --to "ZP Bridge" --row z=-4 --x -13..-9 --also "$U"
python $S/grouping_edit.py <file> cliff --from "ZP City" --to "ZP Bridge" --tiles "-11,-4 12,-4" --also "$U"
python $S/grouping_edit.py <file> height --from 5.250 --to 5.050 --also "$U"       # whole plateau -0.2 m
python $S/grouping_edit.py <file> shift --dz -0.5 --protos zpBridgeFace,PropsPoles --also "$U"
python $S/grouping_edit.py <file> shift --dx 1 --dz 1 --all --also "$U"
python $S/grouping_edit.py <file> socket-last --proto zpSocketPirates --also "$U"
```

Rules the scripts enforce and you must respect:
- Only the touched attributes change; formatting, ordering and CRLF survive (diff must show just the moved lines).
- `--also` writes the identical bytes to the user's `RandMaps/groupings/` copy - the game loads THAT folder
  locally; the repo copy is what ships. Keep them identical, always say which copies you wrote.
- `shift` moves **units only**. Tiles, cliffs and heights sit on the 2 m grid and cannot move by
  fractions - tell the user the terrain stayed put when they ask for a whole-island move.
- Moving a `height` value moves every vertex carrying it (the whole plateau, so everything standing on it).
  Keep a copy of the file before a height change so "revert" is byte-exact.
- Groupings load at game start; the map script may depend on unit ORDER (Paris resolves island
  sockets as "last unit before the water flag") - never reorder units except with `socket-last`.

## 3. Map-side placement is separate

Where the whole grouping lands is the map script (`rmPlaceGroupingAtLoc` / `rmPlaceGroupingInstanceAtLoc`
in `randmaps/zpXXX.xs` and its game-root twin under
`C:\Program Files (x86)\Steam\steamapps\common\AoE3DE\Game\RandMaps\`). Moving the grouping by metres:
`0.5 + rmXTilesToFraction(4) - rmZMetersToFraction(1.0)`. Edit both twins; their only legitimate
difference is the user's local test-trigger block.
