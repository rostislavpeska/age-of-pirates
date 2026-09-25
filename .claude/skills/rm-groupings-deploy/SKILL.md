---
name: rm-groupings-deploy
description: Groupings on random maps - the three copies (the repo's game/randmaps/groupings is the source of truth AND what the game reads; the profile folder is an optional mirror, synced only on request; Steam Game\RandMaps\groupings is vanilla-only), the one-way flow, the process-start indexing rule, the grouping XML anatomy (units, tilegroup base terrain, flattener line, variation index, socket-last), and how to prove a grouping spawned. Use when a grouping does not spawn, when editing or cloning a grouping, when two copies differ, or when repainting a grouping's ground. Triggers on "grouping", "rmCreateGrouping", "village does not spawn", "deploy the grouping", "tilegroup", "ground flattener", "variation", "socket last".
---

# rm-groupings-deploy

## Three copies, one direction

| Copy | Role |
|---|---|
| `game/randmaps/groupings/<Name>.xml` (repo) | THE SOURCE OF TRUTH, and what the game reads (the mod folder is the live mod). Edit here only; the remote repo is the truth across devices. |
| `<profile>\RandMaps\groupings\` | NOT needed for spawning. An optional mirror (e.g. for editor re-saves); sync it from the repo only when the user asks. What is there does not matter. |
| Steam `Game\RandMaps\groupings\` | VANILLA ONLY. Never write, copy, edit or delete there (user rule 2026-09-22). |

Proof (2026-09-24, the 2880x1800 test device): the profile folder held none of the London groupings, yet all 67
London groupings spawned in the editor, and `EU_SPC_London_Bridge` spawned with 111 members - the repo file of that
morning (one pole removed, 112 -> 111), so the game read the repo copy (twin report
docs/briefs/2026-09-24-minimap-twin-test-report.md). The older rule here ("the profile folder is the ONLY deploy
target") was wrong; do not copy groupings to the profile folder to make them spawn. After editing a grouping, restart
the game before testing (the index is believed to be built at process start; File > New does not re-read it). A
grouping the map names that exists in no copy spawns NOTHING, silently (IS_Shore harbours, 2026-08-14). If a profile
copy differs from the repo, the repo copy wins; editor re-saves land there under new names
(`native inuit village 1.xml` vs `Native Inuit Village 01.xml`) and must be brought back into the repo by hand.

## The Steam root is off limits (user rule, 2026-09-22)

`Game\RandMaps\groupings\` belongs to Steam: 680 stock groupings in two install clusters (2024-06-26
and the 2026-09-10 DLC update, incl. `european\` and the Stuart/Sami/Inuit villages). Mod copies that had
accumulated there (85 files; 46 stale against the repo, the whole Istanbul set a month behind) were stripped
on 2026-09-22 after verifying a repo copy existed for each. A stale root copy shadows the repo silently, so:

- never deploy, edit or re-save a mod grouping into the Steam root; the repo is where groupings live;
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

### Known placement issues (proven in game, 2026-09-25, `0000_zzplondon_pirates`)

- **The instance API skips single-unit groupings.** `rmPlaceGroupingInstanceAtLoc` places nothing, silently, for a
  grouping exported with `<selectassingleunit>1</selectassingleunit>` / `<workonassingleunit>1</workonassingleunit>`
  (native-village exports such as `EU_Natives_Pirates_01`). London's instance-placed groupings (bridge, harbours) are
  0 / 0. Read the header first; a single-unit grouping takes `rmSetGroupingMinDistance(g, 0.0)`,
  `rmSetGroupingMaxDistance(g, 0.0)` and `rmPlaceGroupingAtLoc(g, 0, x, z)` (Elbe's pirate villages do the same).
- **No water units in a grouping on a baked quay or pier.** Land and air units are fine where the grouping's baked heights
  raise the ground (London Bridge carries land houses and sockets over the river); a water-movement unit
  (`zpHarbourPlatform`) standing on a raised cell blocks the whole grouping. Owner rule: land + air only - strip the
  water units. Check before placing: each unit's `movementtype` (the map's .mods.xml, then protomods, then the live
  protoy) against the height of the tile under it, tile i centred on 2i m (`round(pos / 2)`); the working London bridge
  and harbour exports show no mismatch under that convention.

## Verify

`census_judge.py` fingerprints every grouping by its socket/flag unit and reports rolled / absent /
flaky across seeds. Related: grouping-terrain, grouping-model-swap, extended-native.
