---
name: map-minimap
description: Generate a random map in the live Scenario Editor and photograph its minimap, for visual validation before a play test is spent on it. Use when asked to "show me the map", "send the minimap", "load it and screenshot", "does the terrain look right", or to confirm a map edit actually changed the terrain. Triggers on "minimap", "load the map", "generate it in the editor", "visual check".
---

# map-minimap: see the terrain before testing it

`mapcheck` proves a map is statically valid. This proves it *looks* right —
the one check a simulator cannot do. Run it before spending an hour of play
test on a map edit.

```bash
cd C:/Users/rosti/aop_harness/aitest
python -u load_map.py --row 8 --seed 4242
```

Three images land in `aitest/editor_shots/`:

| file | what it settles |
|---|---|
| `10_dropdown_crop.png` | the map list, before picking — confirms the row index |
| `04_picked_crop.png` | which map is actually selected, plus players/teams |
| `minimap_row<N>.png` | the generated minimap, cropped |

**Always read `04_picked_crop.png` before believing the minimap.** It shows the
`Type:` field. A minimap of the wrong map looks exactly as convincing as the
right one.

## Deploying the map first

The editor only scans the **Steam install**, never the profile folder:

```
C:\Program Files (x86)\Steam\steamapps\common\AoE3DE\Game\RandMaps\
```

A map needs its `.xs`; `.xml` and `.mods.xml` come too if the version under
test has them. Name them all after the same stem (`000_is_crashtest.*`).

## Two traps

**A `.mods.xml` occupies its own selector row.** Deploying one shifts every row
below it, so `--row 8` can silently select a different map. That is what the
dropdown screenshot is for — check it whenever the deployed file set changes.

**Never restart a healthy game to reload a map.** The editor re-reads the `.xs`
from disk on every File > New > Generate. Edit, generate again, done. A
relaunch costs ~2 minutes of Steam launch plus menu walk, per shot, and buys
nothing. `load_map.py` branches on state and reuses a running editor; only a
crash justifies a relaunch. (Data and art XML are the separate case that does
need a restart — and an `.xmb` rebuild.)

## Reading the result

The oracle for "did it work" is process death plus a new minidump in
`%LOCALAPPDATA%\Temp\AoE3DE_s*.dmp` — a filesystem fact. Every pixel heuristic
tried on this game has misread at least once. `load_map.py` reports
`GENERATED` / `CRASHED` on that basis and prints any new dump path.

A generation crash at `0xC0000005 +0x7E9D2D` means the script is not a valid
map — usually a truncation or strip that dropped `rmSetMapSize`,
`rmTerrainInitialize` or `rmPlacePlayer`. It is not a terrain bug.

## Related

- `mapcheck` — static validity, name catalogs, terrain-grid playability
- `map-profile` — record a verified weirdness so mapcheck stops flagging it
