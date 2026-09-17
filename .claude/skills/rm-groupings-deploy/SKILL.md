---
name: rm-groupings-deploy
description: Groupings on random maps - the three copies (repo game/randmaps/groupings is canonical, Steam Game\RandMaps\groupings and the profile folder are deploy targets), the one-way deploy flow, the process-start indexing rule, the grouping XML anatomy (units, tilegroup base terrain, flattener line, variation index, socket-last), and how to prove a grouping spawned. Use when a grouping does not spawn, when editing or cloning a grouping, when two copies differ, or when repainting a grouping's ground. Triggers on "grouping", "rmCreateGrouping", "village does not spawn", "deploy the grouping", "tilegroup", "ground flattener", "variation", "socket last".
---

# rm-groupings-deploy

## Three copies, one direction

| Copy | Role |
|---|---|
| `game/randmaps/groupings/<Name>.xml` (repo) | CANONICAL. Edit here only. Shipped by the mod. |
| Steam `Game\RandMaps\groupings\` | what the Scenario Editor indexes |
| `<profile>\RandMaps\groupings\` | what the game indexes for Skirmish/editor too |

Deploy = copy repo -> both targets, then restart the game: the grouping index is built at process
start (File > New does not re-read it). A grouping the map names that is missing from the index
spawns NOTHING, silently (IS_Shore harbours, 2026-08-14). Before any transform, diff unit counts
across the three copies; if they differ, say so and use the repo copy - deployed copies go stale
and editor re-saves land under new names (`native inuit village 1.xml` vs `Native Inuit Village 01.xml`).

## Anatomy of a grouping XML

```xml
<grouping>
  <width>15</width><height>12</height>
  <ignoreplacementrules>1</ignoreplacementrules> ...
  <units>
    <unit variation="97" posx="0" posz="0" orientx="0.0000" orienty="0.0000" orientz="-1.0000">zpInvisibleGroundFlattener</unit>
    <unit variation="218" posx="8.26" posz="-6.13" ...>deSocketInuit</unit>   <!-- socket = the fingerprint -->
  </units>
  <tiles>
    <tilegroup type="PassableLand" subtype="rockies\groundsnow3_roc">   <!-- base terrain, painted per block -->
      <block startx="-7" startz="-4" endx="0" endz="3"></block>
    </tilegroup>
  </tiles>
</grouping>
```
- The flattener line above is the mod's exact idiom (ten groupings carry it as the first unit).
- `subtype` is the terrain subtype string from `Art/terrain/terraintypes*.xml` (uiname "Rockies
  Ground Snow 3" -> `rockies\groundsnow3_roc`); read it with bartool, never guess.
- `variation="N"` shows Variation entry N mod K of the proto's animfile (grouping-variation memory).
- Editor re-exports shift units by (-1,-1) m against their own terrain; measure with fixed anchors.
- Trigger code that targets a grouping's unit by engine id needs the socket LAST in the XML and the
  per-map id shift verified in game (nugget-targeting skill).

## Placing

`rmCreateGrouping("label", "<file stem>")` + constraints, then `rmPlaceGroupingAtLoc(id, player, x, z)`
(city-state maps use `rmPlaceGroupingInstanceAtLoc`; it places nothing elsewhere). Groupings are
constraint-reactive: the engine searches for a feasible point; a native grouping is also gated on
its subciv roll, so absence at one player count is normal (rm-census's judge tells the two apart).

## Verify

`census_judge.py` fingerprints every grouping by its socket/flag unit and reports rolled / absent /
flaky across seeds. Related: grouping-terrain, grouping-model-swap, extended-native.
