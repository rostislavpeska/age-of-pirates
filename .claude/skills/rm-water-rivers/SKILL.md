---
name: rm-water-rivers
description: Water on random maps - sea level and sea type, the water-body definition chain (data/waterbodies*.xml over the vanilla snapshots), the beach formula (bank/outerbank), why a body without banks cannot drive a river, river width and waypoints on rectangular maps, lakes and ice water types, and which water names the catalog accepts. Use when choosing or cloning a water body, when a river builds nothing, when beaches appear or fail to appear, or when a shore terraces. Triggers on "sea type", "water body", "river", "rmRiverCreate", "beach", "shoreline", "lake", "ice water", "waterbodies".
---

# rm-water-rivers

## Base water and bodies

```cpp
rmSetSeaLevel(2.0);  rmSetSeaType("ZP Bering Strait");   // a <waterbody> name, catalog-checked (S4)
rmTerrainInitialize("water");                             // everything starts under water
```
Water bodies are defined in `data/waterbodies.xml` / `data/waterbodies2.xml` (mod overrides) over
`scripts/source/waterbodies*.xml` (vanilla snapshots); per-body DEPTH comes from that chain, so the
seabed height = sea level minus the body's depth (mapsim-engine-rules). List names with
`mapcheck --live` or `bartool cat data/waterbodies2.xml`; never invent a name.

## The beach formula (pinned 2026-08-12)

A stretch of coast grows a sand beach IF AND ONLY IF the touching body has non-empty `bank` /
`outerbank` attributes: `bank` paints the first ring of land tiles at the water's edge, `outerbank`
the next. Width of the water is irrelevant. `bank=""` = no beach (ZP Black Sea Lagoon).

## Rivers

- `rmRiverCreate` with a body that has NO bank definition builds NOTHING, silently (the counter-rule).
  Rivers require banks, and banks paint sand and terrace the rim via minriverbankheight /
  maxriverbankheight. The clean river = a cloned body whose bank textures match the seabed and
  whose bank heights are 0/0; XMB regen after the edit.
- River width = 2R uncapped at low R, saturating at half-width 32 m.
- Rectangular maps: the engine reads river waypoints in size_x units on both axes;
  `z_authored = z_wanted * sizeZ / sizeX`.
- Build ALL rivers before any land feature a river would drown (Istanbul: a river built after a gun
  island drowns it); paint the city last.

## Lakes and ice

Lakes are water AREAS (`rmSetAreaWaterType(id, "<body>")`, base height below sea level); Kamchatka's
"ice holes" are small water areas of type `great lakes ice`. `deFishingHole` is a unit placed on land
or ice, not a water area (rm-objects-herds).

## Verify

mapcheck S4 for names; the mapsim water grid (`mapcheck --live`, DEEP/shallow coverage in G5); a
minimap screenshot for shape; census of fish / whales for spawn (`fishLand`, `whaleLand` constraints
keep them off the shore in metres).
