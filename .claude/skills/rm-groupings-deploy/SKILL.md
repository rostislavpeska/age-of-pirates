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
- The flattener line above is the mod's exact idiom: the first unit, at 0 / 0 (the Stuart houses are the exception,
  off-centre and not first).
- Size, measured (2026-10-07): `obstructionradiusx/z` is a half-width in METRES, and FlattenGround levels the whole
  box. The flattener's radius 20 levels a 40 x 40 m square: 21 x 21 height vertices, 20 x 20 tiles of 2 m. Positions
  (`posx`/`posz`) are metres; `<width>`/`<height>` are tiles. Evidence from 16 flatteners in 14 Danube editor saves:
  the share of vertices at the flattener's exact height is 95-97 % on the perimeters 16-18 m out, 81 % at 20 m, 11 %
  at 22 m and 1 % at 24 m. The square can sit one vertex (2 m) off-centre, and later units with their own flattening
  re-level patches inside it. The heights are `(tx+1)*(tz+1)` float32, x-major, right after the save's `WT` block
  (`scripts/mapsim/field.py` 537); a unit's saved `y` is the level height.
- Which groupings carry the flattener and which have copies without it: "Flatten / unflatten standard" below.
- `subtype` is the terrain subtype string from `Art/terrain/terraintypes*.xml` (uiname "Rockies
  Ground Snow 3" -> `rockies\groundsnow3_roc`); read it with bartool, never guess.
- `variation="N"` shows Variation entry N mod K of the proto's animfile (grouping-variation memory).
- Editor re-exports shift units by (-1,-1) m against their own terrain; measure with fixed anchors.
- Sockets in groupings (owner 2026-10-07): a STANDARD socket (`SocketTradeRoute`, `zpSPCPortSocket`) works inside a
  grouping; a CAPTURABLE socket inside a grouping does not (engine bug) - place it by object def.
- Trigger code that targets a grouping's unit by engine id needs the socket LAST in the XML and the
  per-map id shift verified in game (nugget-targeting skill).

## Flatten / unflatten standard (owner 2026-10-07)

The owner kept the 40 m flattener ("the settlements are big") and with it the copies: "keep the debt and define some
standards for flatten / unflatten groupings". `scripts/mapcheck/tests/test_area_flattener.py` pins every rule.

1. **Who carries it:** settlement groupings. `Hussite_Camp_01-05`, `Orthodox_Monastery01-06`, `Orthodox_South_01-03`
   and `Jesuit_Cathedral_EU_Flat_01-03` carry the exact flattener line above: the first unit, at 0 / 0.
2. **Who never does:** a grouping that holds a Town Center (forts, player starts). With the flattener in the Malta
   forts the owner saw the Explorer spawn fail. Level a start with a flat area beneath it instead. The Danube's fort
   site is 650 tiles, smooth 5, elevation variation 0, at the land height and 2 m off the water.
3. **The copy without it:** `<Name>_noflatten.xml` is `<Name>.xml` minus the flattener line, nothing else. It is
   derived, never edited. Edit the base, then run `python scripts/tools/noflatten_copies.py --write`; `--check`
   reports drift, and `--add <Name>` creates a copy. Make a copy only for a map that uses it.
4. **Naming:** the flattened grouping keeps the plain name and the copy appends `_noflatten`. The script appends it
   after the drawn type: `"Hussite_Camp_0"+type+"_noflatten"`. The Jesuit names are the legacy opposite (`_Flat_` =
   with the flattener). Do not extend that pattern.
5. **When a map uses the copies:** when its real editor generations, made without the flattener, show a steep step
   (>= 1.5 m between neighbouring vertices, 2 m apart) or water inside a settlement's 40 x 40 m square. Gentle slopes
   are what the flattener is for. Measure saves, not mapsim: its cliff areas both over-call (Elbe) and under-call
   (Black Sea). Read the heights as described above. Today: King of Bohemia, Dead Sea, Black Sea.
6. **The map edge:** a flattened settlement's centre never comes closer than 22 m to the map edge (the 20 m
   half-width plus one vertex). Owner: "obstruction can touch the map edge". The guarantee is its requested point
   minus its max distance, or an edge box / world circle among its constraints. The Danube adds its 30 m
   `playerEdgeConstraint` to its settlements. Balearic Islands and The Unknown are beyond mapsim and are checked in
   real saves (88 m and 38 m).
7. **A new map or a new settlement family** follows 1-6. A family that should flatten gets the line; copies come only
   with a map that needs them.

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
