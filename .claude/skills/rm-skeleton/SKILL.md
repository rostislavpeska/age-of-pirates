---
name: rm-skeleton
description: Start or repair a random map script from the mandatory spine - the includes, chooseMercs(), map size, sea level, terrain init, map types, player placement and Town Centers that every generating map has - plus the .xml metadata, where the files live (repo vs Steam Game\RandMaps editor twin vs profile), the sync-by-copy rule and CRLF. Use when creating a new map, when a map crashes at generation, when a test map is needed, or when two copies of a map exist. Triggers on "new map", "map skeleton", "minimal map", "map crashes on generate", "which copy does the game load", "sync the map", "template map".
---

# rm-skeleton: the spine every map must keep

## The spine (order matters, all mandatory)

```cpp
include "mercenaries.xs";          // the three includes: every working map has them
include "ypAsianInclude.xs";
include "ypKOTHInclude.xs";
void main(void) {
   rmSetStatusText("", 0.01);
   rmSetMapSize(<metres>, <metres>);                 // missing -> 0xC0000005 +0x7E9D2D
   rmSetSeaLevel(<h>);  rmSetSeaType("<water body>");
   rmSetBaseTerrainMix("<mix>");  rmTerrainInitialize("<terrain>", <h>);   // missing -> crash
   rmSetMapType("<type>"); ...                       // at least one; drives AI, shipments, politicians
   chooseMercs();                                    // missing -> generation aborts (+0xA7508D)
   rmPlacePlayersCircular(...) or rmPlacePlayersLine(...);   // missing -> crash
   /* one TownCenter per player at rmPlayerLocXFraction/ZFraction */
   rmSetStatusText("", 1.0);
}
```

Reference texts, copy them rather than retype: `scripts/tools/unitbench.py` (XS_TEMPLATE, the 200 m
land bench), the Steam folder's `000zpTestMap.xs` (islands + player areas), and any shipped map's first
60 lines. `scripts/maps/000_hkt_test.xs` (git 7130e597) records why each spine line exists.

## Files and where they live

| File | Purpose | Location |
|---|---|---|
| `<stem>.xs` | the script | repo `game/randmaps/` (shipped, Skirmish) |
| `<stem>.xml` | lobby identity: `displayNameID` or `displayName`, images, `loadss` | beside the .xs |
| `<stem>.mods.xml` | optional per-map proto overrides | beside the .xs; it takes its own row in the editor list |
| editor twin | the Scenario Editor reads ONLY the Steam `Game\RandMaps` folder | keep it byte-identical by copy after every edit; different stem is fine (zpcoldwar vs zp_coldwar) |
| test maps `000_*`, `0000_*` | editor-only benches | Steam `Game\RandMaps`, never the mod folder |

Two files with the same display name = the picker silently uses the stale one (the 2026-08-15
Istanbul incident). Before trusting any in-game observation, checksum every same-name copy.

## Rules

- Files are CRLF; edit with Python on bytes (`scripts/tools/patchfile.py`), never `sed -i` (strips CR).
- XS has no block scope: a variable declared inside an `if` or loop lives in main's namespace; never
  reuse a name across blocks (xs-main-scope-collisions memory).
- `intVar * floatVar` truncates to 0 in XS; accumulate floats.
- New helpers go above `main` as `void name(int a = -1, string s = "")`: every parameter needs a
  default (vanilla ypKOTHInclude.xs is the reference).
- Mercenary/consulate content that a map enables needs the includes; a map without natives still
  needs `chooseMercs()`.
- Gate: `python -m scripts.mapcheck <stem> --static-only --live` = 0 FAIL before any generation.
  Then one editor generation with the crash oracle (rm-unit-bench's runner or map-minimap).

Related: rm-workflow (the phases), rm-coordinates, rm-players, rm-unit-bench (a frozen instance of
this spine).
