---
name: rm-groupings-deploy
description: Groupings on random maps - the three copies (repo game/randmaps/groupings is canonical, only the profile folder is a deploy target; Steam Game\RandMaps\groupings is vanilla-only), the one-way deploy flow, the process-start indexing rule, the grouping XML anatomy (units, tilegroup base terrain, flattener line, variation index, socket-last), and how to prove a grouping spawned. Use when a grouping does not spawn, when editing or cloning a grouping, when two copies differ, or when repainting a grouping's ground. Triggers on "grouping", "rmCreateGrouping", "village does not spawn", "deploy the grouping", "tilegroup", "ground flattener", "variation", "socket last".
---

# rm-groupings-deploy

## Three copies, one direction

| Copy | Role |
|---|---|
| `game/randmaps/groupings/<Name>.xml` (repo) | CANONICAL. Edit here only. Shipped by the mod. |
| `<profile>\RandMaps\groupings\` | the ONLY deploy target - what the game indexes for Skirmish and the editor |
| Steam `Game\RandMaps\groupings\` | VANILLA ONLY. Never write, copy, edit or delete there (user rule 2026-09-22). |

Deploy = copy repo -> the profile folder only, then restart the game: the grouping index is built at process
start (File > New does not re-read it). A grouping the map names that is missing from the index
spawns NOTHING, silently (IS_Shore harbours, 2026-08-14). Before any transform, diff unit counts
across the two copies (repo, profile); if they differ, say so and use the repo copy - deployed copies go stale
and editor re-saves land under new names (`native inuit village 1.xml` vs `Native Inuit Village 01.xml`).

## The Steam root is off limits (user rule, 2026-09-22)

`Game\RandMaps\groupings\` belongs to Steam: 680 stock groupings in two install clusters (2024-06-26
and the 2026-09-10 DLC update, incl. `european\` and the Stuart/Sami/Inuit villages). Mod copies that had
accumulated there (85 files; 46 stale against the repo, the whole Istanbul set a month behind) were stripped
on 2026-09-22 after verifying a repo copy existed for each. A stale root copy shadows the repo silently, so:

- never deploy, edit or re-save a mod grouping into the Steam root; the profile folder is the deploy target;
- never delete anything there either - the two mod files WITHOUT a repo copy (`IS_SPC_Construction`,
  `IS_SPC_Fisherman_Float`, the latter used by the root-only 000_istanbul test copy) stay until the user decides;
- audit recipe: any top-level file whose mtime is outside the Steam clusters, or whose name exists in the
  repo, is a mod copy - report it, and delete only on the user's word after confirming the repo copy exists;
- the vanilla stem index `scripts/source/groupings_index.txt` was listed from that folder while it was
  contaminated (Aug 2026); refresh it only from a clean root and never from the profile folder.

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
