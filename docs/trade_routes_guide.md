# Age of Pirates: Trade Route Guide

Research compilation, 2026-09-24. This file is documentation only. It is written so that it can later become a skill
(an extension of `.claude/skills/rm-trade-routes/`).

**What has been applied since the research.** The research read HEAD `cae26f9b`. The guide was first saved at 22:59; from 23:00
on, four commits changed the trade setup of London and Istanbul (section 9 and 10.1):

- `fa44aea2` (23:00): London moved from `euroTradeRouteUpgradeAll` to `euroTradeRouteCapture`; the new shadow tech
  `zpDisableAllTradeRouteUpgrades` removes every upgrade button (London and Istanbul); London got two route techs
  (`zpLondonDeptfordStation` at St Paul's, `zpLondonEastIndiaCompany` at the Minster) that raise a route to level 2 by
  trigger; Istanbul's two naval routes start at level 1.
- `750af968` (23:23): the disable tech also covers the mod's six zp upgrade techs and runs for players 1..N only; London's
  players get `DETradeRouteAllResourcesShadow` (the `deTradeCrateAll` toggle); the two route techs are UNOBTAINABLE in data
  and made obtainable by London's start trigger.
- `c72fa3b8` (23:29): the route-tech buttons moved to page 11, column 0 on St Paul's and the Minster.
- `e4f89c3c` (23:37): London's trade plan (the lock, the resource shadow, the two route techs made obtainable) moved out of
  the start trigger into the shared setup tech `zpLondonSetup`, which `zpLondonAttackerSetup` and `zpLondonDefenderSetup`
  activate; the start trigger now grants each player only its side's setup tech.

The recipes in section 8 remain documentation; section 9 compares London before and after these commits.

It was compiled from six research lenses:

1. the data chain;
2. upgrade techs and map types;
3. sockets, posts and capture;
4. the script, trigger and AI API;
5. a survey of every map;
6. history and lessons.

## How to read this guide

**Status tags.** Every claim carries one:

- **[PROVEN]**: read in data or code.
- **[LIKELY]**: inferred from several sources.
- **[OPEN]**: needs an in-game test. The cheapest test is listed in the OPEN index (section 10.3) and referenced here as `O<n>`.

When a table has no status column, every row in it is PROVEN (read in data) unless a cell says otherwise.

**Evidence shorthand.**

| Prefix | Means |
|---|---|
| V-defs, V-routes | vanilla `traderoutedefs.xml` / `traderoutes.xml`, decompiled from the current build into the session scratchpad (`vdata/`) |
| V-tech, V-proto | vanilla `techtreey.xml` / `protoy.xml` (the scratchpad `techtreey_live.xml` / `protoy_live.xml` are md5-identical) |
| V-mst, V-trig | vanilla `mapspecifictechs.xml` / `trigger/triggerData.xml` (decompiled) |
| M-defs, M-routes, M-proto, M-tech, M-mst | repo `data/traderoutedefs.xml`, `data/traderoutes.xml`, `data/protomods.xml`, `data/techtreemods.xml`, `data/mapspecifictechmods.xml` |
| M-trig | repo `data/trigger/triggerdata.xml` |
| `zpxxx.xs:n` | repo `randmaps/zpxxx.xs` line n |
| `game/zpxxx.xs:n` | repo `game/randmaps/zpxxx.xs` line n |
| `Steam/xxx.xs:n` | `C:/Program Files (x86)/Steam/steamapps/common/AoE3DE/Game/RandMaps/xxx.xs` |
| `ai/core/x.xs:n` | repo `game/ai/core/x.xs` (read only; `coreDLC/` is byte-identical for the trade logic) |
| exe | string scan of `AoE3DE_s.exe` (engine help text) |
| dump | profile `RandMaps/Age3DERM<map>.dmp.txt` (RM symbol dump: string constants, no line numbers) |
| census | unit census of saved scenarios `Scenario/mapview_london4p_live.age3Yscn` (2026-09-24 12:07) and `LondonIndivUnitIDs.age3Yscn` (2026-09-22) |
| DXG | `.claude/skills/aoe3de-reference/references/data_xml_guide.md` (2146 lines). Not `docs/data_xml_guide.md`, which has 245 lines and does not contain the cited text |

**Line numbers.** Repo line numbers are as of HEAD `e4f89c3c` (2026-09-24 23:37). The research itself read `cae26f9b` (22:25). Every citation of `zplondon.xs` from line 2818 on, `zpistanbulb.xs` from 4297 on, `techtreemods.xml` from 38655 on and `protomods.xml` from 74373 on was re-read at `e4f89c3c`; lines that describe the older state say so (for example "at `cae26f9b`"). Other files had no trade-relevant change between the two commits. `zpparis.xs` and `zpverseilles.xs` changed while the research ran; their lines were read again afterwards. The working tree is edited live by other sessions, so re-check a line before relying on it. Vanilla line numbers are those of the 2026-09-24 decompile. A fresh decompile with the `bar-extract` skill, made into a scratchpad and never into the repo, reproduces them. The research scripts named in some places lived in the session scratchpad and are temporary.

**Where to start.**

| I want to... | Go to |
|---|---|
| pick a route def for a map | 2.4, 2.5 |
| know which buttons a post will show | 3.1, 3.7, 4.1 |
| start a route already upgraded | 8a |
| give a land route and a naval route separate upgrades | 8b |
| mix capturable posts and normal Trading Posts | 8c |
| address a route from a trigger | 5.4 |
| know what the AI does with routes | 6 |
| see London's trade design, before and after `fa44aea2` | 9 |

## Contents

1. [Summary](#1-summary)
2. [The data chain](#2-the-data-chain)
3. [Map types and upgrade techs](#3-map-types-and-upgrade-techs)
4. [Posts and sockets](#4-posts-and-sockets)
5. [The script and trigger API](#5-the-script-and-trigger-api)
6. [The AI and trade routes](#6-the-ai-and-trade-routes)
7. [Survey of maps](#7-survey-of-maps)
8. [Recipes](#8-recipes)
9. [Case study: London](#9-case-study-london)
10. [Pitfalls, lessons and the OPEN index](#10-pitfalls-lessons-and-the-open-index)

---

## 1. Summary

A trade route is built from these layers:

```
RM script       rmCreateTradeRoute() -> waypoints -> rmBuildTradeRoute(id, "<def name>")        (5.1)
                rmSetObjectDefTradeRouteID(objectDef, id)  links sockets and capturable posts     (4, 5.1)
                rmSetMapType("<type>")  -> forced techs from mapspecifictechs.xml                  (3.6)
route def       traderoutedefs.xml <route>: kind (land / nautical / river), textures, units       (2.2-2.4)
level chain     traderoutes.xml <level> 0 / 1 / 2: <upgrade><from>def</from><to>def</to>          (2.5)
trade units     a gaia-owned convoy of RailroadUnit protos named by the current level's def       (2.6)
posts           TradingPost built on a socket, or a pre-placed capturable post                     (4)
buttons         upgrade techs in the post proto's <tech> list, shown only when OBTAINABLE,
                prereqs met and the tech's TP-kind flag matches the route kind                     (3.1)
income          <unitmultiples> toggles (crates or units), gated on techs, not on levels          (2.7)
level change    tech effects UpgradeTradeRoute / UpgradeAllTradeRoutes, or the triggers
                "Trade Route Set Level" / "Trade Route Apply Tech"                                 (3.3, 5.2)
```

The facts that decide most questions:

1. **The RM script only chooses the def.** The second argument of `rmBuildTradeRoute` must equal the text of one `<route>` record in `traderoutedefs.xml`. No RM call takes a level, tech or owner. Levels move only at run time, through triggers or techs. [PROVEN] (5.1)
2. **The def's kind decides which upgrade family a post shows.** Upgrade techs carry `YPLandTPOnly`, `YPNauticalTPOnly` or `DERiverTPOnly`, and a post shows only the techs whose flag matches its route: `nautical="false"`, `nautical="true"` or `river="true"`. [LIKELY] (3.1)
   - `nautical="true"` does not mean water. The Asian land roads `water`, `water2` and `water3` are nautical. [PROVEN] (2.3)
3. **The map type decides which family is OBTAINABLE.** `rmSetMapType` forces "enable" techs. With no enable tech, only `TradeRouteUpgrade1/2` exists, and only on land posts. [PROVEN] (3.5, 3.6)
4. **Upgrades are per post.** Upgrade techs carry `UniqueProtoUnitInstance`, `TradingPost` carries `CreateUniqueInstance`, and the AI reads the status per building. [PROVEN] (4.2)
5. **The `*All` techs upgrade every route on the map.** `EuropeAll`, `WaterAll`, `RiverAll` and the Colorado/Dakota `All` pair do. The European three also link to their sibling techs of the other kinds. [PROVEN] (3.3)
6. **"Trade Route Set Level" moves only the route.** It compiles to `trTradeRouteSetLevel(route, level)` and sets no tech.
   - The post keeps offering the level-1 upgrade: [PROVEN] in data and seen by the owner on London, 2026-09-24 (build `67f294f1`..`cae26f9b`, before the lock).
   - The food/wood/coin toggles stay locked, because they need the tech: [LIKELY].
   (5.2, 9.3)
7. **"Trade Route Apply Tech" is vanilla's way to pre-upgrade a route** (The Unknown, and five encrypted European maps). Whether it also removes the button is [OPEN] (O3). (5.2, 8a)
8. **Vanilla capturable posts can never upgrade.** They list only `ypTradeRouteUpgradeIndia1/2`, which stay UNOBTAINABLE on every shipped map type. [PROVEN]
9. **The mod's four capturable post protos can.** They list 22 normal upgrade techs, so they upgrade with whatever the map type unlocks for their route kind. [PROVEN] (4.1, 4.4) Exception: where a map activates `zpDisableAllTradeRouteUpgrades` (London and Istanbul since `fa44aea2`), `zpOrientalFerry` and `zpTradingPostCaptureNaval` lose those rows for the players who have it (3.5).
10. **Triggers number routes from 1.** The TradeRoute parameter is `rmCreateTradeRoute()` id + 1: creation order, starting at 1. [PROVEN]. Whether build order could differ is [OPEN] (O1). (5.4)
11. **London is the only map that mixes the two kinds.** Among all 52 mod maps and every readable vanilla map, it alone places a route-linked normal socket and route-linked capturable posts in the same generation. [PROVEN] (7.3)
12. **The mod AI has no European route branch.** It decides each route's type once, at setup. The retail vanilla AI has the branch; the mod's copy lost it. [PROVEN in code] On European maps the AI therefore probably never upgrades a land route. [LIKELY] (6)
13. **London and Istanbul now move their routes by trigger only** (`fa44aea2`, `750af968`, `e4f89c3c`). Both routes start at level 1, `zpDisableAllTradeRouteUpgrades` removes every upgrade button for players 1..N, and on London a player-researched route tech (Deptford Station, East India Company) raises one route to level 2 for everyone. [PROVEN in code; in-game behaviour OPEN] (9)

---

## 2. The data chain

### 2.1 Files and the override model

- **The mod replaces both route files whole** [PROVEN]. `data/traderoutedefs.xml` and `data/traderoutes.xml` have the same names as vanilla `Data/*.xml.XMB`, and no `*mods` merge variant exists. `bartool list traderoute` returns 6 archive files: `traderoutedefs.xml.XMB`, `traderoutes.xml.XMB`, `uitraderoutedlg.xml.XMB`, `uitraderoutepanel.xml.XMB`, `uitraderoutepanel2.xml.XMB` and `uitraderoutepanel2min.xml.XMB`.
  - `traderoutedefs.xml` has 39 records, each on one line (M-defs 2-40): all 26 vanilla names plus 13 mod-only names. defsdiff: "vanilla missing in mod: []".
  - A stale copy has lost vanilla records before (section 10).
- **Both have `.xml.xmb` twins that must be rebuilt after an edit** (AGENTS.md rule 4: `python .claude/skills/aoe3de-bar-archives/scripts/xmbc.py check|build data/<file>.xml`). On 2026-09-24 both twins MATCH, `scripts/tools/xmb_idcheck.py` reports 0 findings, and the decoded twins contain no element text with leading or trailing whitespace. [PROVEN]
- **The one-line rule** [PROVEN]. Every `<route>` record stays on one line. The Resource Manager XMB compiler keeps element text verbatim. A multi-line record therefore compiles its name with trailing whitespace (`'arctic1\r\n    '`), the lookup fails, and the engine silently builds the base route.
  - The repo compiler `xmbc.py` strips text (`Compiler.node: body = wstr((e.text or '').strip())`), so it cannot reproduce the failure. Any other compiler can.
  - Incident 2026-09-10, fixed in `ca2b2f7b`; memory `xmb-text-whitespace-trap.md`.
- **Unknown or misspelled route names fall back silently** to the base route (the first record, `dirt` with Travois), with no error. [LIKELY] mapcheck S4 FAILs on unknown route names (`scripts/mapcheck/universal.py` 244-254: `Finding("S4", "FAIL", ...)`, "unknown trade route type ... engine silently falls back to the base route"). The exact fallback target is [OPEN] (O20).
- **Per-map `.mods.xml` files carry only protomods** [PROVEN]. All 18 contain only `<protomods>` (zpgrinch and zpwinterwonderlandii spell it `ProtoMods`). Whether other sections (techtreemods, traderoutes) would be honoured there is untested. Protomods can still change a post per map (for example `zpblacksea.mods.xml` 160-168 on `zpTradingPostCaptureNavalOriental` / `NavalLone`, `zplondon.mods.xml` 74-76 on `zpOrientalFerry`), including, in principle, adding or removing its `<tech>` rows; tech-row removal has no precedent (O15).
- **The editor dialog is overridden** [PROVEN]. `data/uitraderoutedlg.xml` replaces the vanilla dialog. Its buttons call `editorSetAllTradeRoutesToDef` with 10 defs, two lines each (L20-86): `water`, `dirt`, `snow`, `dirt_trail`, `dirt_trail_african`, `water_trail`, `river_trail`, `asian_water_trail`, `native_water_trail` and `hansa_water_trail` (83 / 86). That button is the only consumer of `hansa_water_trail`; no `.xs` builds it.

### 2.2 Anatomy of a route record [PROVEN]

`<route blocksize="16.0" minimapcolor="230 230 230" nautical="false">dirt<straight>...</straight> ... <units><unit>Travois</unit></units></route>` (V-defs 2-23)

- **Attributes.**
  - `blocksize`: 16.0 everywhere; 8.0 on `lava_flow`.
  - `minimapcolor`: `230 230 230`; `0 0 0` on `lava_flow`.
  - Exactly one kind attribute: `nautical="false"`, `nautical="true"` or `river="true"`.
  - Optionally `hideoneditor=""`.
- **Name.** The element text.
- **Nine texture pieces.** `straight`, `straight45`, `fillcorner`, `corner90`, `corner45a`, `corner45b`, `end`, `end45`, `corner90diagonal`. Each holds a base texture path and an optional `<decal [bump=...]>`.
- **`<units>`.** The first `<unit>` leads the convoy. Each following unit carries `distance="m"`, which is probably its spacing behind the leader in metres [LIKELY]. Examples: train cars 3.2 / 6.3, porters 3.2, arctic dogs 2.4 / 2.5 / 3.0, lava wagons 1, and the armored-train sound car and gun 0.0 (the gun sits on its car).
- **`hideoneditor`.** It most likely hides a def from the scenario editor's Trade Route Type dropdown (`TradeRoute_TypeFld`). Vanilla puts it only on level-1/2 targets. The mod dropped it from 11 of them, so those appear in the dropdown in the mod. [LIKELY]

### 2.3 Route kinds

- **The kind attribute decides which upgrade family a post on the route shows** [LIKELY]. The upgrade techs carry `YPLandTPOnly`, `YPNauticalTPOnly` or `DERiverTPOnly`, and the data shows no other link between kind and button.
  - V-tech 129506 `DETradeRouteUpgradeEurope1` carries `YPLandTPOnly`; 97042 `DETradeRouteUpgradeWater1` carries `YPNauticalTPOnly`; 129456 `DETradeRouteUpgradeRiver1` carries `DERiverTPOnly`.
  - DXG 1395-1396 and 1468: "only displayed in Trading Posts linked to Trade Routes of the Nautical/Land/River type".
  - The owner relied on this in 2024: `57ea1b9d` changed `native_water_trail/2/3` from `nautical="true"` to `river="true"` to match their `DERiverTPOnly` techs.
- **Nautical is not water** [PROVEN]. Vanilla `water`, `water2` and `water3` are `nautical="true"` but use land road textures and land units (Travois, Stagecoach, Train). They are the Asian land-route family.
  - Evidence: V-defs 120-193. `Steam/silkRoad.xs` 83 `tradeRouteType = "water"`; `himalayas.xs` 42 and `borneo.xs` 44 do the same. V-routes 6 / 50 `nauticallevelname` 62403 'Rickshaw' and 64989 'Trade Cart'. DXG 1395: "Trading Routes in Asian maps are, internally, classified as Nautical".
  - That is why `ypTradeRouteCaptureable` and `TradeRouteUpgradeCapturable1/2` carry `YPNauticalTPOnly`.
- **Where mod water chains sit.** The mod's native river chain uses a `DERiverTPOnly` tech (M-tech 7378 `zpTradeRouteUpgradeWaterNative`). The asian nautical chain uses a `YPNauticalTPOnly` tech (M-tech 6738).
- **Which defs are nautical** [PROVEN]. Only `water*`, `water_trail*`, `asian_water_trail*`, `hansa_water_trail` and `arctic_water_trail*` are `nautical="true"`. `river_trail*`, `native_water_trail*`, `australia_river_trail` and `lava_flow` are `river="true"`. `dirt`, `train`, `armored_train` and `xmassnow` are `nautical="false"`.

### 2.4 Table T1: all 39 route definitions

Vanilla has 26 defs and the mod adds 13. Columns:

- **kind**: land, nautical or river.
- **V-defs / M-defs**: the line in each file.
- **decal V/M**: the decal in vanilla and in the mod.
- **hide V/M**: `hideoneditor` in vanilla and in the mod.
- **units**: the trade units, as in the mod file.
- **repo maps**: the line of `rmBuildTradeRoute`. `game/` means `game/randmaps`, and `(target)` means the def is reached only by an upgrade.

| def | kind | V-defs | M-defs | texture (straight) | decal V/M | hide V/M | units (mod file) | repo maps |
|---|---|---|---|---|---|---|---|---|
| dirt | land | 2 | 2 | dirt | bump/bump | n/n | Travois | London 724, Paris 350, Versailles 379, KingOfBohemia 613, Crownlands 369, Florence 477, AztecCity 313, performance_test 299; game/ BlueMountains, EyreBasin, Mississippi, Riverina, Tasmania, WildWest, WWCanyon; zpunknown (var) |
| stone | land | 24 | 3 | road | bump/bump | Y/n | Stagecoach | (target) |
| snow | land | 46 | 4 | snow | yes/yes | n/n | Travois | game/LabradorCoast 309; zpunknown (var) |
| train | land | 68 | 5 | train | bump/bump | Y/n | TrainEngine + TrainCoalcar + TrainCarCoin + 2x TrainCar + TrainCarWood + 2x TrainCarFood + TrainCaboose | CivilWar 286 (built directly) |
| temp | land | 98 | 6 | temp | yes/yes | n/n | Caravel | none |
| water | nautical (Asian land road) | 120 | 7 | dirt | bump/bump | n/n | Travois | zpunknown (var); vanilla silkRoad, himalayas, borneo |
| water2 | nautical | 142 | 8 | road | bump/bump | Y/n | Stagecoach | (target) |
| water3 | nautical | 164 | 9 | train | bump/bump | Y/n | same 9-car train | (target) |
| dirt_trail | land | 194 | 10 | dirt | bump/bump | n/n | Travois | zpunknown (var); vanilla S-American maps |
| stone_trail | land | 216 | 11 | road | bump/bump | Y/n | deStagecoach + 2x deTradePorter | (target) |
| dirt_trail_african | land | 240 | 12 | dirt | bump/bump | n/n | Travois | zpunknown (var) |
| stone_trail_african | land | 262 | 13 | road | bump/bump | Y/n | Stagecoach + deTradePorter | (target) |
| caravan_trail_african | land | 285 | 14 | road | bump/bump | Y/n | deCaravanGuide + 7x deCaravanPorter | (target) |
| water_trail | nautical | 314 | 15 | dirt | bump/none | n/n | deTradingShip | London 604, Elbe 338, IstanbulB 1032/1043, BlackSea 426, CaribbeanWars 187/200, VeniceCity 285, venicecit_test 285, Iceland (var); game/ BalearicIslands, cookislands (x2), atols, australia, barrierreef, hawaii, kurils, malta, malta_castles, mediterranean, melanesia, newguinea, philippines, polynesia, tasmania, torresstrait, tortuga, treasureisland, venice, zealand |
| water2_trail | nautical | 336 | 16 | road -> dirt | bump/none | Y/n | deTradingGalleon | (target; also from hansa) |
| water3_trail | nautical | 358 | 17 | road -> dirt | bump/none | Y/n | deTradingFluyt | (target) |
| river_trail | river | 380 | 18 | dirt | bump/none | n/n | deRiverTrader | Elbe 305, Florence 457/463, Crownlands 355, game/DeadSea 433 |
| river2_trail | river | 402 | 19 | road -> dirt | bump/none | Y/n | deCargoBoat | (target) |
| river3_trail | river | 424 | 20 | road -> dirt | bump/none | Y/n | deTradingBarge | (target) |
| eu_stone_trail | land | 446 | 21 | road | bump/bump | n/n | deStagecoach | none in repo (Steam-root test copy `zp_z_verseilles2.xs` only); vanilla euFrance (dump) |
| asian_water_trail | nautical | - | 22 | dirt | -/none | -/n | zpAsianRiverTrader | game/Burma_b 330 |
| asian_water2_trail | nautical | - | 23 | dirt | -/none | -/n | zpAsianRiverTradeJunk | (target) |
| asian_water3_trail | nautical | - | 24 | dirt | -/none | -/n | zpChinaTreasureShip | (target) |
| native_water_trail | river | - | 25 | dirt | -/none | -/n | zpNativeRiverTrader | AztecCity 307/318, CivilWar 443, IndependenceWar 357, game/ElDorado 255, game/Mississippi 834 |
| native_water2_trail | river | - | 26 | dirt | -/none | -/n | zpCargoBoat | (target; also from australia) |
| native_water3_trail | river | - | 27 | dirt | -/none | -/n | zpTradeSteamer | (target) |
| xmassnow | land | - | 28 | snow | -/yes | -/n | Travois | Grinch 362/363, WinterWonderlandII (var, 492) |
| xmasstagecoach | land | - | 29 | snow | -/yes | -/n | zpTradeSledge | (target) |
| xmastrain | land | - | 30 | train | -/bump | -/n | TrainEngine + TrainCoalcar + 6x TrainCar + TrainCaboose | (target) |
| armored_train | land | - | 31 | dirt | -/none | -/n | zpArmoredTrainEngineMove, 2x SoundMove, CoalcarMove (sic), KitchenWagon, Gunpowder, GuncarFront, GunCar, Gun, GuncarBack, Hospital, Barracks (all ...Move) | CivilWar 298/310; game/ BlueMountains, EyreBasin, LabradorCoast, Mississippi, WildWest, WWCanyon |
| lava_flow | river (blocksize 8.0, minimap 0 0 0) | - | 32 | dirt | -/none | -/n | zpLavaSpawnerTrade + 5x each of Wagon, Wagon2..Wagon5 (distance 1) | Iceland 1170-1191; game/ Hawaii, Melanesia, Polynesia, zpunknown |
| australia_river_trail | river | - | 33 | dirt | -/none | -/n | zpAboriginalRiverTrader | game/Riverina 696 |
| hansa_water_trail | nautical | - | 34 | dirt | -/none | -/n | zpHansaTradeRouteShip | no map; editor button only (uitraderoutedlg.xml 83 / 86) |
| arctic1 | land | 468 | 35 | ice | yes/yes | n/n | deArcticTrader | game/ColdWar 641/670 |
| arctic2 | land | 490 | 36 | ice | yes/yes | n/n | deArcticTraderSled | (target) |
| arctic3 | land | 512 | 37 | ice_road | yes/yes | n/n | 3x deArcticTraderDogs + deArcticTraderDogSled | (target) |
| arctic_water_trail | nautical | 537 | 38 | dirt | bump/none | n/n | deUmiak | none |
| arctic_water2_trail | nautical | 559 | 39 | road | bump/none | Y/Y | deTradingGalleon | (target) |
| arctic_water3_trail | nautical | 581 | 40 | road | bump/none | Y/Y | deIcebreaker | (target) |

### 2.5 Level chains

**The level file** [PROVEN]. `traderoutes.xml` has exactly three `<level>` records: 0 (no upgrades), 1 and 2. Each lists `<upgrade><from>def</from><to>def</to></upgrade>` pairs. A route at level N uses the def reached by following the pairs from its base def.

- **Top-level knobs.** `<unittypeowner>TradingPost</unittypeowner>`, `<buildresourceaward/>`, `<traderoutelengthscale>360</traderoutelengthscale>`.
- **Per-level knobs.** `awardsound`, `levelname`, `nauticallevelname`, `icontexture`, `nauticalicontexture`. `<grantsvisibility/>` is on levels 1 and 2; `<transport/>` on level 2 only.
- **Pair counts.** Vanilla level 1 has 9 upgrades (V-routes 11-46) and level 2 has 8 (55-86). The top-level and per-level metadata are identical in the mod.
- **What `<transport/>` and `<buildresourceaward/>` do** is [OPEN] (O21).

Table T2: every entry def, followed through levels 0-2 (V-routes 10-94, M-routes 10-129).

| entry def | kind | level 0 | level 1 (def: units) | level 2 (def: units) | source |
|---|---|---|---|---|---|
| dirt | land | Travois | stone: Stagecoach | train: 9-car train | V+M |
| snow | land | Travois | stone: Stagecoach | train | V+M (merges into the dirt chain) |
| water | nautical (Asian) | Travois | water2: Stagecoach | water3: train | V+M |
| dirt_trail | land | Travois | stone_trail: deStagecoach + 2 deTradePorter | train | V+M |
| dirt_trail_african | land | Travois | stone_trail_african: Stagecoach + deTradePorter | caravan_trail_african: deCaravanGuide + 7 deCaravanPorter | V+M |
| water_trail | nautical | deTradingShip | water2_trail: deTradingGalleon | water3_trail: deTradingFluyt | V+M |
| river_trail | river | deRiverTrader | river2_trail: deCargoBoat | river3_trail: deTradingBarge | V+M |
| arctic1 | land | deArcticTrader | arctic2: deArcticTraderSled | arctic3: 3 deArcticTraderDogs + deArcticTraderDogSled | V+M |
| arctic_water_trail | nautical | deUmiak | arctic_water2_trail: deTradingGalleon | arctic_water3_trail: deIcebreaker | V+M |
| asian_water_trail | nautical | zpAsianRiverTrader | asian_water2_trail: zpAsianRiverTradeJunk | asian_water3_trail: zpChinaTreasureShip | M 39-42, 100-103 |
| native_water_trail | river | zpNativeRiverTrader | native_water2_trail: zpCargoBoat | native_water3_trail: zpTradeSteamer | M 43-46, 104-107 |
| australia_river_trail | river | zpAboriginalRiverTrader | native_water2_trail: zpCargoBoat | native_water3_trail: zpTradeSteamer | M 51-54 |
| hansa_water_trail | nautical | zpHansaTradeRouteShip | water2_trail: deTradingGalleon | water3_trail: deTradingFluyt | M 55-58 |
| xmassnow | land | Travois | xmasstagecoach: zpTradeSledge | xmastrain: TrainEngine + TrainCoalcar + 6 TrainCar + TrainCaboose | M 47-50, 108-111 |
| temp / eu_stone_trail / armored_train / lava_flow | land / land / land / river | Caravel / deStagecoach / armored train / lava | no pair (behaviour [OPEN], O18) | no pair | chains.py |

- **Merging chains** [PROVEN]. Some chains merge on the first upgrade: `snow` into `stone` and `stone_trail` into `train` (vanilla); `australia_river_trail` into `native_water2_trail` and `hansa_water_trail` into `water2_trail` (mod). After that upgrade the special route takes the textures and units of the standard target def (V-routes 15-18, 59-62; M-routes 51-58).
- **Defs without a pair** [OPEN] (O18). No upgrade pair touches `temp`, `eu_stone_trail`, `armored_train` or `lava_flow`, and `eu_stone_trail` (deStagecoach) is never the source or target of a pair. What the engine does with such a route at level 1 or 2 is untested. The mod already sets its `armored_train` routes to Level 1 (`game/zpwildwest.xs` 413 builds armored_train as route 2; 1766-1768 run Set Level on TradeRoute 2, Level 1).
- **Where the arctic pairs sit.** In the mod file they come after each level's metadata (M-routes 66-73, 121-128).

### 2.6 Trade units

- **The RailroadUnit family** [PROVEN]. Trade units belong to the unittype `RailroadUnit`: 28 vanilla protos plus 28 mod protos. Every unit named in a route def is a RailroadUnit except two:
  - `Caravel` (def `temp`), a real warship;
  - the misspelled `zpArmoredTrainCoalcarMove` (the proto is `zpArmoredTrainCoalCarMove`, M-proto 21575).
  - Traits they share: Unattackable; Invulnerable, InvulnerableIfGaia, NonCollideable, NoHPBar and Tracked; only the Delete command; no tactics file. Vanilla techs address the whole family by `RailroadUnit` (V-tech 109821 `DEMapFasterTradeUnit`: MaximumVelocity x1.25).
- **Owner** [PROVEN]. Trade units belong to gaia (player 0): in the census, deTradingShip (index 0) and Travois (index 166) are both player 0. Two mod mechanisms rely on this:
  - `game/zpmississippi.xs` 2211-2218 and 2246-2250 count gaia's Stagecoach and TrainEngine;
  - the trigger effect "ZP Trade Harbour AutoSetup" (M-trig about 3787-3830) activates `zpUpdatePort1/2` when gaia owns a deTradingGalleon or deTradingFluyt.
- **Index at generation** [PROVEN for London]. Each `rmBuildTradeRoute` creates one trade unit at generation, and that unit takes a unit index. On London that is deTradingShip at index 0 (the lane is built first) and Travois at 166.
- **Speed by level** [PROVEN]. Level-0 units run at 4.0, level-1 units at 7.0, and level-2 units at 8.5, on land, sea, river and arctic chains alike. Mod exceptions: `zpChinaTreasureShip` (Asian level 2) runs 5.0, slower than its 7.0 level-1 junk, and the lava units run 0.3.
- **Look and name come from the map** [PROVEN]. The animfile picks a model with `<logic type="Tech">`. Map techs rename units with `SetName` and swap portraits with `CopyUnitPortraitAndIcon`.
  - The `trade_stagecoach` animfile has no `demapeuropean` branch, so European maps show the default stagecoach at level 1.
  - `Travois` becomes 'Scholar' (122538) under `DEEnableTradeRouteEuropean` or `EuropeanAll`.
- **Unused RailroadUnits** [PROVEN]. Six ride on no route. `ypTradeCart`, `ypRickshaw` and `ypRickshawIndian` (vanilla) only donate portraits (V-tech 7888-7891). `zpTradeCaravel` (M-proto 10382), `zpTradeShipwreck` (M-proto 9194) and `zpArmoredTrainCoalCarMove` are unused as route units.
- **deUmiak's animfile is missing** [OPEN] (O22). The level-0 unit of `arctic_water_trail` points to `units/trade/naval/trade_ship_A_01/trade_ship_A_01.xml`, which no archive contains. Only the `.gr2`, `.material` and textures exist, plus `trade_ship_A_03.xml`. No repo map uses `arctic_water_trail`; arctic maps re-skin deTradingShip through its `demaparctic` branch instead.
- **Triggers and techs acting on the units** [PROVEN].
  - "Trade Route Toggle State" hides route units: armored-train and lava maps, e.g. `game/zpwildwest.xs` 1617-1623 and 1776-1782.
  - `zpTransformArmoredTrain` / `zpTransformArmoredTrainBack` (M-tech 12676 / 12708) swap Move and Static protos.
  - Map-forced speed techs: `DEMapFasterTradeUnit` (RailroadUnit x1.25; nigerdelta, savanna) and `DEMapFasterWaterTradeUnit` (ship x1.5, galleon x1.25, fluyt x1.294; Finland).

Table T3: trade-unit protos.

| proto | source (id, line) | move, speed | route def (level) | display name (string) | per-map look / name |
|---|---|---|---|---|---|
| Travois | V 479, V-proto 27398 | land 4.0 | dirt, snow, water, dirt_trail, dirt_trail_african, xmassnow (L0) | Trade Travois 29375 | renamed 122538 Scholar (DEEnableTradeRouteEuropean/All), 64990 Rickshaw (Asian, Maghreb), 90900 Barter Merchant (NativeAmerican), 102123 Trader (African), 501380 Aboriginal Trader (zpEnableTradeRouteAustralian); models none/ypmapfareast/ypmapindian/demapmaghreb/demapamerican/demapafrican/demapeuropean/zpmapaustralian (mod art/units/trade/travois.xml) |
| Stagecoach | V 480, 27441 | land 7.0 | stone, water2, stone_trail_african (L1) | Stagecoach 29379 | 64989 Trade Cart (Asian, Maghreb), 102124 Caravan Trader (African), 90901 (zpAztecCityGeneralSetup); models none/ypmapfareast/ypmapindian/demapmaghreb/demapamerican/demapafrican, NO European branch |
| deStagecoach | V 1676, 118622 | land 7.0 | stone_trail (L1), eu_stone_trail (L0) | 29379 | 90901 Traveling Merchant, 64989, 102124; same animfile as Stagecoach |
| deTradePorter | V 1612, 113398 | land 7.0 | stone_trail x2, stone_trail_african (L1 followers) | Pack Llama 80633 | 102126 Pack Camel (African) |
| TrainEngine, TrainCoalcar, TrainCarCoin, TrainCar, TrainCarWood, TrainCarFood, TrainCaboose | V 316 14010, 321 14507, 643 38564, 629 37750, 641 38480, 642 38522, 322 14549 | land 8.5 | train, water3 (L2); xmastrain | Steam Train 22968, Coal Car, Coin Car, Passenger Car, Wood Car, Food Car, Caboose | engine/coal: none/demapeuropean/zpmapaustralian (mod overrides art/units/trains/engine.xml, coal_car.xml, coin_car.xml) |
| Caravel | V 289, 9645 (mod partial M-proto 1840) | water 8.5 | temp (a land def) | Caravel 22826 | warship, not a RailroadUnit |
| deCaravanGuide + deCaravanPorter | V 1920 136271, 1921 136313 | land 8.5 | caravan_trail_african (L2) | Caravan Guide 102125, Caravan Pack Camel 102127 | - |
| deTradingShip | V 1925, 136509 | water 4.0 | water_trail (L0) | Oceanic Carrack 102135 | 106424 Trade Umiak + demaparctic model; x1.5 DEMapFasterWaterTradeUnit |
| deTradingGalleon | V 1926, 136548 (M-proto 3945 adds civflagoverride) | water 7.0 | water2_trail, arctic_water2_trail (L1) | Trade Galleon 102136 | 106427 Arctic Brig; x1.25 |
| deTradingFluyt | V 1927, 136587 | water 8.5 | water3_trail (L2) | East Indiaman 102130 | 106430 Icebreaker; x1.294 |
| deRiverTrader / deCargoBoat / deTradingBarge | V 2547 174369 / 2548 174414 / 2549 174459 | water 4.0 / 7.0 / 8.5 | river_trail / 2 / 3 | River Trader / Cargo Boat / Trading Barge | - |
| deArcticTrader / deArcticTraderSled / deArcticTraderDogs + deArcticTraderDogSled | V 2915 197044 / 2916 197088 / 2918 197172 + 2917 197130 | land 4.0 / 7.0 / 8.5 | arctic1 / 2 / 3 | Arctic Trapper / Sledger / Dog Team + Dog Driver | - |
| deUmiak | V 2992, 201157 | water 4.0 | arctic_water_trail (L0) | Trade Umiak 106424 | animfile absent from the archives |
| deIcebreaker | V 2993, 201196 | water 8.5 | arctic_water3_trail (L2) | Icebreaker 106430 | - |
| zpAsianRiverTrader / zpAsianRiverTradeJunk / zpChinaTreasureShip | M 20065 8741 / 20066 8789 / 20043 5696 | water 4.0 / 7.0 / 5.0 | asian_water_trail / 2 / 3 | Trading Barque 500308 / Trade Junk 500310 / Treasure Ship 33715 | L0 animfile: Civ indian + Tech yphcarmedfishermenindians |
| zpNativeRiverTrader / zpCargoBoat / zpTradeSteamer | M 20399 10334 / 20245 24622 / 20401 10430 | water 4.0 / 7.0 / 8.5 | native_water_trail / 2 / 3 (also australia L1/L2) | Trade Canoe 500383 / Cargo Boat 122530 / Trade Steamer 500387 | zpCargoBoat renamed 502478 Large Trade Canoe + zpaztectrade model (zpAztecTrade) |
| zpAboriginalRiverTrader | M 20378, 34106 | water 4.0 | australia_river_trail | Aboriginal River Trader 501637 | - |
| zpHansaTradeRouteShip | M 20851, 62485 | water 4.0 | hansa_water_trail | Trade Cog 502934 | - |
| zpTradeSledge | M 20188, 21210 | land 7.0 | xmasstagecoach | Reindeer Sled 500960 | - |
| zpArmoredTrain*Move | M Engine 20193 21527, CoalCar 20194 21575 (def spells Coalcar), KitchenWagon 23457, Gunpowder 22719, GuncarFront 23276, GunCar 21670, Gun 21713, GuncarBack 23319, Hospital 22609, Barracks 21623, Sound 23923 | land 8.5 | armored_train | Armored Train (Engine) 501017 ... | Move <-> Static via zpTransformArmoredTrain / Back |
| zpLavaSpawnerTrade + Wagon..Wagon5 | M 20308-20313, 27705-27925 | land 0.3 | lava_flow | Lava Flow 501342 | Culture logic on the wagons |
| orphans | V ypTradeCart, ypRickshaw, ypRickshawIndian; M zpTradeCaravel 10382, zpTradeShipwreck 9194, zpArmoredTrainCoalCarMove | - | none | - | portrait donors / unused |

### 2.7 Income: the `<unitmultiples>` toggles

- **What a toggle is** [PROVEN]. Each `<unit>` in `<unitmultiples>` is a toggle on the Trading Post, with an `activeicon`, a `disabledicon` and a `tooltip`. It names either a crate proto or a unit to deliver.
  - Crates are `AbstractTradeCrate` with `initialresource` 85; `deTradeCrateAll` gives 3 x 28.3333 (V-proto 168727 `deCrateofFoodEuropean`: `<initialresource resourcetype="Food">85.0000`).
  - Tooltips: 34053-34056 'This Trading Post is delivering Wood / Food / Coin / generating Experience'.
- **Gating** [PROVEN]. A toggle appears when its `<techprereq>` and `<playertechprereq>` are Active. `<orprereqs/>` means any one of the listed techs will do. `<restricttocapturabletp/>` limits the toggle to capturable posts.
- **Toggles need the tech, not the level** [LIKELY]. Every Food, Wood and Coin crate needs an upgrade tech. Only three toggles depend on no route-upgrade tech:
  - `CrateofXP`: needs only the player tech `DETradeRouteXPShadow`, which `XPTrickle` activates, and every `Age0<civ>` tech activates `XPTrickle` (V-tech 3329-3345, e.g. line 92). So XP is available from the start.
  - `deTradeCrateAll`: needs `DETradeRouteAllResourcesShadow`. `DEIndependence` swaps the XP toggle for this one (V-tech 168531).
  - `deTradeCrateofInfluence` (mod change, see 2.8).

  A route raised by trigger without its tech therefore offers no food, wood or coin toggle until someone researches that tech. The button state after Set Level has not been observed (O5). Where the upgrade techs are locked for good, granting `DETradeRouteAllResourcesShadow` is the way to keep resource income: London does so since `750af968` (9.2).
- **Delivery happens in the engine** [LIKELY]. The TradingPost tactics (`Data/tactics/tradingpost.tactics.XMB`) contain no delivery action. How the delivered amount scales with route length (`traderoutelengthscale` 360) is [OPEN] (O21).
- **Income-tuning techs** [PROVEN]. Techs tune income with `InventoryAmount BasePercent` on the crates: 43 such effects in vanilla (e.g. `DEHCFedOhioSupplyShadow` x2.00 on abstracttradecrate) and 30 in the mod (e.g. `zpWokouHandsOff` x1.25).
- **Capture-only crates** [PROVEN]. Crates marked `<restricttocapturabletp/>` exist only for capturable posts: `ypTradeCrateof*`, `deCrateof*African1`, `deTradeCrateofInfluenceCapture` and `deTradeCrateofExportCapture`. Each needs one of the three capture techs (3.4).
  - No proto lists those capture techs, so only a map type (or a trigger) can switch them on.
  - Mod triggers do so on two maps: `zpcivilwar.xs` 1477 (`cTechdeTradeRouteCaptureableEuropean`) and `zpindependencewar.xs` 1661 (`cTechypTradeRouteCaptureable`).
- **Unit deliveries** [PROVEN]. The vanilla `ypNatGurkha` entry (gated on `ypTradeRouteUpgradeIndia1`) is dead: no proto of that name exists in the current build (only `ypNatMercGurkha` / `ypNatMercGurkhaJemadar`). The mod delivers `ypConsulatePrussianNeedleGun` behind `zpTradeRouteUpgradeHansaShadow` (M-routes 721), which `zpSPCHansaNeedleGunTradeRoute` (M-tech 31750) switches on.

Table T4: every `<unitmultiples>` entry. Food, Wood and Coin triplets are grouped.

| crate family | V-routes | M-routes | techprereq (OR where several) | playertechprereq | capturable TP only |
|---|---|---|---|---|---|
| ypTradeCrateofFood/Wood/Coin | 99 | 135 | ypTradeRouteCaptureable | - | yes |
| ypCrateofFood1/Wood1/Coin1 | 138 | 177 | ypTradeRouteUpgrade1 | - | no |
| TradeCrateofFood/Wood/Coin | 174 | 213 | TradeRouteUpgrade1 | - | no |
| deCrateofFood/Wood/Coin | 210 | 249 | deTradeRouteUpgradeAll1 | - | no |
| deCrateof*American | 246 | 285 | deTradeRouteUpgradeAmerica1 | - | no |
| deCrateof*Maghreb | 282 | 321 | DETradeRouteUpgradeMaghreb1 | - | no |
| deCrateof*African | 318 | 357 | DETradeRouteUpgradeAfrica1 | - | no |
| deCrateof*Water | 354 | 393 | DETradeRouteUpgradeWater1 OR DETradeRouteUpgradeWaterAll1 | - | no |
| deCrateof*African1 | 396 | 438 | deTradeRouteCaptureableAfrican OR deTradeRouteCaptureableEuropean | - | yes |
| deCrateof*River | 441 | 489 | DETradeRouteUpgradeRiver1 OR DETradeRouteUpgradeRiverAll1 | - | no |
| deCrateof*European | 483 | 534 | DETradeRouteUpgradeEurope1 OR DETradeRouteUpgradeEuropeAll1 OR DETradeRouteUpgradeArctic1 | - | no |
| CrateofXP | 528 | 582 | - | DETradeRouteXPShadow | no |
| deTradeCrateAll | 540 | 733 | - | DETradeRouteAllResourcesShadow | no |
| deTradeCrateofInfluence | 552 | 594 | V: any of the 13 level-1 upgrade techs; M adds DEAfricanTradeRouteInfluenceShadow to the OR list (601) | DEAfricanTradeRouteInfluenceShadow | no |
| deTradeCrateofInfluenceCapture | 578 | 745 | ypTradeRouteCaptureable OR deTradeRouteCaptureableAfrican OR deTradeRouteCaptureableEuropean | DEAfricanTradeRouteInfluenceShadow | yes |
| deTradeCrateofExport | 595 | 762 | any of the 13 level-1 upgrade techs | deConsulateSpanishMercantilismIndependence | no |
| deTradeCrateofExportCapture | 621 | 788 | the 3 capture techs (OR) | deConsulateSpanishMercantilismIndependence | yes |
| ypNatGurkha (dead: no such proto) | 638 | 621 | ypTradeRouteUpgradeIndia1 | - | no |
| zpCrateof*Treasure (mod) | - | 633 | zpTradeRouteUpgradeTreasure OR zpTradeRouteUpgradeWaterNative | - | no |
| zpCrateof*Australian (mod) | - | 679 | zpTradeRouteUpgradeAustralia1 | - | no |
| ypConsulatePrussianNeedleGun (mod, unit delivery) | - | 721 | zpTradeRouteUpgradeHansaShadow | - | no |

### 2.8 How the mod's route files differ from vanilla [PROVEN]

**`traderoutes.xml`.**

- Unchanged: the top level and the metadata of all 3 levels.
- New upgrade pairs:
  - level 1 gains 5: asian, native, xmas, `australia -> native_water2_trail` and `hansa -> water2_trail`;
  - level 2 gains 3.
- `<unitmultiples>` gains 7 entries: `zpCrateof*Treasure`, `zpCrateof*Australian` and `ypConsulatePrussianNeedleGun`.
- `deTradeCrateofInfluence` carries one extra techprereq, `DEAfricanTradeRouteInfluenceShadow`, inside its OR list (M-routes 601, from `570bf024` "Version 5.4"). This probably gives the Influence toggle to African civs already at level 0 [LIKELY].
- `deTradeCrateAll` and the capture/export crates moved to the end of the list.
- Nothing from vanilla is missing ("vanilla crates missing in mod: []"). `7bca3463` restored the vanilla crate prereqs and `deTradeCrateAll`.

**`traderoutedefs.xml`.**

- **`hideoneditor`** is gone from 11 level-1/2 defs: `stone`, `train`, `water2`, `water3`, `stone_trail`, `stone_trail_african`, `caravan_trail_african`, `water2_trail`, `water3_trail`, `river2_trail` and `river3_trail`. Only `arctic_water2/3_trail` keep it, because their records came in with `e9800ad9`.
- **Decals.** Decals are removed from `water_trail/2/3`, `river_trail/2/3` and `arctic_water_trail/2/3`, and `water2/3_trail` and `river2/3_trail` switch their base texture from road to dirt. None of the 9 mod water/river defs, `armored_train` or `lava_flow` carries a decal. The removal is deliberate. `d6d22541`: "The mod strips `<decal>` from naval and river routes on purpose; a decal there paints a dirt strip across open sea."
- **13 new defs.**

### 2.9 Data gaps and oddities

| item | detail | evidence | status |
|---|---|---|---|
| Arctic water crates | no food/wood/coin crate lists DETradeRouteUpgradeArcticWater1; an arctic water route upgraded with its own tech unlocks no F/W/C toggle | V-routes 354-393 (Water crates need Water1 OR WaterAll1); V-tech 173206 | PROVEN (data) |
| ypNatGurkha | dead unit delivery | 2.7 | PROVEN |
| deUmiak animfile | missing from every archive | 2.6 | OPEN (O22) |
| Case in tech names | vanilla traderoutes.xml references `deTradeRouteUpgradeAll1`, the tech is `DETradeRouteUpgradeAll1`, so tech lookup there appears case-insensitive | V-routes 217 vs V-tech 76773 | LIKELY |
| Case in proto names | armored_train names `zpArmoredTrainCoalcarMove`, the proto is `zpArmoredTrainCoalCarMove` | M-defs 31 vs M-proto 21575 | OPEN (O19) |
| Duplicate map record | mapspecifictechmods has two identical `caribbeanwater` blocks | M-mst 39-43 and 58-62 | PROVEN |
| Influence / Export crates ignore the zp level-1 techs | neither OR list names `zpTradeRouteUpgradeTreasure`, `zpTradeRouteUpgradeWaterNative` or `zpTradeRouteUpgradeAustralia1`. On Treasure, native-water and Australian routes the Export crate never appears, and Influence unlocks only through `DEAfricanTradeRouteInfluenceShadow` (African civs). The same holds on London and Istanbul since `fa44aea2`, where no level-1 tech can become Active | M-routes 593-619 `deTradeCrateofInfluence` (OR: the Shadow + the 13 vanilla level-1 techs); M-routes 761-786 `deTradeCrateofExport` (OR: the 13 vanilla level-1 techs) | PROVEN (data) |

---

## 3. Map types and upgrade techs

### 3.1 When a post shows an upgrade button

All four conditions must hold.

1. **The tech is in the post proto's `<tech>` list** [PROVEN]. On `TradingPost` every vanilla upgrade tech shares one grid slot, row 0, page 1, column 0 (V-proto 10140-10287). The mod adds its zp pairs at column 1 (M-proto 2432-2435, 2552-2553).
2. **The tech is OBTAINABLE for that player** [PROVEN]. Map-forced enable techs flip this (3.5, 3.6).
3. **Its prereqs are Active** [PROVEN].
   - Level 1 needs its enable tech plus the gate `DETradeRouteUpgrade1Enable`.
   - Level 2 needs the level-1 tech plus `DETradeRouteUpgrade2Enable` (3.2).
   - Example: V-tech 129506-129528 `DETradeRouteUpgradeEurope1`, `<status>OBTAINABLE`, prereqs `DEEnableTradeRouteEuropean` + `DETradeRouteUpgrade1Enable`.
4. **The tech's TP-kind flag matches the route kind of the post** [LIKELY]. `YPLandTPOnly` matches `nautical="false"`, `YPNauticalTPOnly` matches `nautical="true"`, `DERiverTPOnly` matches `river="true"`.
   - Sources: DXG 1395-1396 and 1468.
   - It fits London's screenshot (taken on the `euroTradeRouteUpgradeAll` build, before `fa44aea2`): `zpOrientalFerry` lists both EuropeAll1 and WaterAll1, yet showed one ship-icon upgrade.
   - It becomes PROVEN if a captured nautical post never shows a land-flagged tech it lists (O8; since `fa44aea2` test on Venice City or Elbe, not on London or Istanbul, whose lock removes the rows).

Because all upgrades share one slot, at most one upgrade button shows at a time. The engine does **not** hide an upgrade because the route has already reached that level (5.2, 9.3).

### 3.2 Gate techs and cost cards [PROVEN]

**The gates.** Both are OBTAINABLE Shadow techs with 0 research points, so they activate by themselves once a prereq is met.

- **`DETradeRouteUpgrade1Enable`** (V-tech 124861-124873, OrPrereqs, `DEDisplayAsAge1Prereq`): activates with `DEAge0Italians` OR `Colonialize`.
- **`DETradeRouteUpgrade2Enable`** (V-tech 82221-82236, `DEDisplayAsAge3Prereq`): activates with `DEAge0Italians` OR `HCXPHouseofBraganca` OR `DEHCFedSteamEngine` OR `DETrickleEconomicsShadow` OR `Industrialize`. The mod adds `zpPolarExpress` (M-tech 39650-39654; a list element without mergeMode appends).
- **Who opens them early.**
  - Italians (`DEAge0Italians`, V civs.xml 11555-11570) get both tiers from Age 1.
  - `HCXPHouseofBraganca` is 'TEAM House of Bragança' (Portuguese deck).
  - `DEHCFedSteamEngine` is 'Corliss Steam Engine' (US federal, Rhode Island).
  - No vanilla XML activates `DETrickleEconomicsShadow` ([OPEN], O37).

**Cost cards.** Cost rules target the flag `DETradeRouteUpgrade`, not tech names.

- These make every tech with that flag free: `HCXPHouseofBraganca`, `DEHCFedSteamEngine`, `DEHCREVSuezCanal` (which also sets research points to 0), and the mod's `zpPolarExpress` (which also sets AllowedAge -1).
- Evidence: V-tech 45148-45154, 88601-88607, 84157-84166; M-tech 39636-39647.
- The India and Capturable techs lack the flag, so these cards never touch them.

**Standard costs.** Level 1 costs 200 food + 200 wood; level 2 costs 300 wood + 400 gold.

**The effect subtypes.**

- **`UpgradeTradeRoute`** (amount = level) acts on the post's own route: string 33293 "Upgrades this Trade Route to use Stagecoaches".
- **`UpgradeAllTradeRoutes`** acts on every route: string 91726 "Upgrades all Trade Routes...". Two forms exist:
  - **Data** form: `DETradeRouteUpgradeAll1/2`, Colorado/Dakota, with no links.
  - **Data2** form: the European `*All` pairs. They carry links to their sibling techs:
    - `EuropeAll` links `watertech=WaterAll` and `rivertech=RiverAll` (V-tech 135233);
    - `WaterAll` links `landtech=EuropeAll` and `rivertech=RiverAll` (138988);
    - `RiverAll` links `landtech=EuropeAll` and `watertech=WaterAll` (135185).
  - Rollover text: 124562 "...Any River or Naval trade routes in the map will also be upgraded to match the same level"; 124697 and 124560 are the same for the other kinds.
  - What the links do exactly (probably mark the siblings as done) is [OPEN] (O13).
- **Counts.** Vanilla has exactly 25 techs with `UpgradeTradeRoute` and 8 with `UpgradeAllTradeRoutes`. All 33 are in T5.

### 3.3 Table T5: vanilla route techs (complete)

All rows are from V-tech. The DE/TAD per-route techs all carry `UniqueProtoUnitInstance` and the group flag `DETradeRouteUpgrade`.

| tech | line | status | cost | prereqs (all Active; OR where marked) | TP-kind flag | group flag | effect |
|---|---|---|---|---|---|---|---|
| TradeRouteUpgrade1 | 18895 | OBTAINABLE | 200F/200W | DETradeRouteUpgrade1Enable | YPLandTPOnly | DETradeRouteUpgrade | Data UpgradeTradeRoute 1 |
| TradeRouteUpgrade2 | 18917 | OBTAINABLE | 300W/400G | TradeRouteUpgrade1, 2Enable | YPLandTPOnly | DETradeRouteUpgrade | UpgradeTradeRoute 2 |
| ypTradeRouteUpgradeIndia1 | 50944 | UNOBTAINABLE | 200F/200W | Colonialize | - | YPCapturableTradeRouteUpgradeTech | UpgradeTradeRoute 1 ('Troop Transport' 61768) |
| ypTradeRouteUpgradeIndia2 | 51298 | UNOBTAINABLE | 300W/400G | India1, 2Enable | - | YPCapturableTradeRouteUpgradeTech | UpgradeTradeRoute 2 |
| TradeRouteUpgradeCapturable1 | 62198 | OBTAINABLE | 200F/200W | Colonialize | YPNauticalTPOnly | YPCapturableTradeRouteUpgradeTech | UpgradeTradeRoute 1 ('Trade Cart' 67684); no proto lists it |
| TradeRouteUpgradeCapturable2 | 62176 | OBTAINABLE | 300W/400G | Capturable1, Industrialize | YPNauticalTPOnly | YPCapturableTradeRouteUpgradeTech | UpgradeTradeRoute 2; no proto lists it |
| ypTradeRouteUpgrade1 | 65974 | OBTAINABLE | 200F/200W | YPEnableAsianNativeOutpost, 1Enable | YPNauticalTPOnly | DETradeRouteUpgrade | UpgradeTradeRoute 1 |
| ypTradeRouteUpgrade2 | 65997 | OBTAINABLE | 300W/400G | yp1, 2Enable | YPNauticalTPOnly | DETradeRouteUpgrade | UpgradeTradeRoute 2 |
| ypTradeRouteCaptureable | 66172 | OBTAINABLE | - | Colonialize | YPNauticalTPOnly | YPCapturableTradeRouteUpgradeTech | XPRate 0.50 BasePercent (crate unlock) |
| DETradeRouteUpgradeAll1 | 76773 | OBTAINABLE | 200F/200W | DEEnableTradeRouteUpgradeAll, 1Enable | YPLandTPOnly | DETradeRouteUpgrade | Data UpgradeAllTradeRoutes 1 |
| DETradeRouteUpgradeAll2 | 76796 | OBTAINABLE | 300W/400G | All1, 2Enable | YPLandTPOnly | DETradeRouteUpgrade | UpgradeAllTradeRoutes 2 |
| deTradeRouteUpgradeAmerica1 | 81182 | OBTAINABLE | 200F/200W | DEEnableTradeRouteNativeAmerican, 1Enable | YPLandTPOnly | DETradeRouteUpgrade | UpgradeTradeRoute 1 |
| deTradeRouteUpgradeAmerica2 | 81205 | OBTAINABLE | 300W/400G | 2Enable, America1 | YPLandTPOnly | DETradeRouteUpgrade | UpgradeTradeRoute 2 |
| DETradeRouteUpgradeMaghreb1 | 81980 | OBTAINABLE | 200F/200W | DEEnableTradeRouteMaghrebi, 1Enable | YPLandTPOnly | DETradeRouteUpgrade | UpgradeTradeRoute 1 |
| DETradeRouteUpgradeMaghreb2 | 82003 | OBTAINABLE | 300W/400G | 2Enable, Maghreb1 | YPLandTPOnly | DETradeRouteUpgrade | UpgradeTradeRoute 2 |
| DETradeRouteUpgradeAfrica1 | 96966 | OBTAINABLE | 200F/200W | DEEnableTradeRouteAfrican, 1Enable | YPLandTPOnly | DETradeRouteUpgrade | UpgradeTradeRoute 1 |
| DETradeRouteUpgradeAfrica2 | 96989 | OBTAINABLE | 300W/400G | Africa1, 2Enable | YPLandTPOnly | DETradeRouteUpgrade | UpgradeTradeRoute 2 |
| DETradeRouteUpgradeAfricaRailroad2 | 97269 | UNOBTAINABLE | 300W/400G | Africa1, 2Enable | YPLandTPOnly | DETradeRouteUpgrade | UpgradeTradeRoute 2 (scenario) |
| DETradeRouteUpgradeWater1 | 97042 | OBTAINABLE | 200F/200W | DEEnableTradeRouteWater, 1Enable | YPNauticalTPOnly | DETradeRouteUpgrade | UpgradeTradeRoute 1 |
| DETradeRouteUpgradeWater2 | 97065 | OBTAINABLE | 300W/400G | Water1, 2Enable | YPNauticalTPOnly | DETradeRouteUpgrade | UpgradeTradeRoute 2 |
| deTradeRouteCaptureableAfrican | 97099 | OBTAINABLE | - | Colonialize | YPLandTPOnly | YPCapturableTradeRouteUpgradeTech | XPRate 0.50 BasePercent (crate unlock) |
| DETradeRouteUpgradeRiver1 | 129456 | OBTAINABLE | 200F/200W | DEEnableTradeRouteEuropeanRiver, 1Enable | DERiverTPOnly | DETradeRouteUpgrade | UpgradeTradeRoute 1 |
| DETradeRouteUpgradeRiver2 | 129479 | OBTAINABLE | 300W/400G | River1, 2Enable | DERiverTPOnly | DETradeRouteUpgrade | UpgradeTradeRoute 2 |
| DETradeRouteUpgradeEurope1 | 129506 | OBTAINABLE | 200F/200W | DEEnableTradeRouteEuropean, 1Enable | YPLandTPOnly | DETradeRouteUpgrade | UpgradeTradeRoute 1 |
| DETradeRouteUpgradeEurope2 | 129529 | OBTAINABLE | 300W/400G | Europe1, 2Enable | YPLandTPOnly | DETradeRouteUpgrade | UpgradeTradeRoute 2 |
| DETradeRouteUpgradeRiverAll1 | 135168 | OBTAINABLE | 200F/200W | DEEnableTradeRouteEuropeanRiverAll, 1Enable | DERiverTPOnly | DETradeRouteUpgrade | Data2 UpgradeAllTradeRoutes 1, landtech=EuropeAll1, watertech=WaterAll1 |
| DETradeRouteUpgradeRiverAll2 | 135191 | OBTAINABLE | 300W/400G | RiverAll1, 2Enable | DERiverTPOnly | DETradeRouteUpgrade | Data2 ... 2, landtech=EuropeAll2, watertech=WaterAll2 |
| DETradeRouteUpgradeEuropeAll1 | 135214 | OBTAINABLE | 200F/200W | DEEnableTradeRouteEuropeanAll, 1Enable | YPLandTPOnly | DETradeRouteUpgrade | Data2 ... 1, watertech=WaterAll1, rivertech=RiverAll1 |
| DETradeRouteUpgradeEuropeAll2 | 135237 | OBTAINABLE | 300W/400G | EuropeAll1, 2Enable | YPLandTPOnly | DETradeRouteUpgrade | Data2 ... 2, watertech=WaterAll2, rivertech=RiverAll2 |
| deTradeRouteCaptureableEuropean | 138159 | OBTAINABLE | - | Colonialize | YPLandTPOnly | YPCapturableTradeRouteUpgradeTech | XPRate 0.50 BasePercent (crate unlock) |
| DETradeRouteUpgradeWaterAll1 | 138969 | OBTAINABLE | 200F/200W | DEEnableTradeRouteEuropeanWaterAll, 1Enable | YPNauticalTPOnly | DETradeRouteUpgrade | Data2 ... 1, landtech=EuropeAll1, rivertech=RiverAll1; icon trade_galleon_icon (138976) |
| DETradeRouteUpgradeWaterAll2 | 138992 | OBTAINABLE | 300W/400G | WaterAll1, 2Enable | YPNauticalTPOnly | DETradeRouteUpgrade | Data2 ... 2, landtech=EuropeAll2, rivertech=RiverAll2 |
| DETradeRouteUpgradeArctic1 | 173131 | OBTAINABLE | 200F/200W | DEEnableTradeRouteArctic, 1Enable | YPLandTPOnly | DETradeRouteUpgrade | UpgradeTradeRoute 1 |
| DETradeRouteUpgradeArctic2 | 173154 | OBTAINABLE | 300W/400G | Arctic1, 2Enable | YPLandTPOnly | DETradeRouteUpgrade | UpgradeTradeRoute 2 |
| DETradeRouteUpgradeArcticWater1 | 173206 | OBTAINABLE | 200F/200W | DEEnableTradeRouteArcticWater, 1Enable | YPNauticalTPOnly | DETradeRouteUpgrade | UpgradeTradeRoute 1 |
| DETradeRouteUpgradeArcticWater2 | 173229 | OBTAINABLE | 300W/400G | ArcticWater1, 2Enable | YPNauticalTPOnly | DETradeRouteUpgrade | UpgradeTradeRoute 2 |
| gate DETradeRouteUpgrade1Enable | 124861 | OBTAINABLE Shadow, 0 rp | - | OR: DEAge0Italians, Colonialize | - | - | none (prereq holder) |
| gate DETradeRouteUpgrade2Enable | 82221 | OBTAINABLE Shadow, 0 rp | - | OR: DEAge0Italians, HCXPHouseofBraganca, DEHCFedSteamEngine, DETrickleEconomicsShadow, Industrialize (+ mod zpPolarExpress) | - | - | none |

- **Obtainable by default** [PROVEN]. `TradeRouteUpgrade1/2` (the North-American Stagecoach and Iron Horse) are OBTAINABLE by default. Every regional enable tech sets them UNOBTAINABLE and makes its own pair obtainable, except `EuropeanWater`, `ArcticWater`, `AfricanScenario` and `YPEnableTradeRouteIndian` (V-tech 7868-7879: India1/2 obtainable, `TradeRouteUpgradeCapturable1/2` unobtainable, `TradeRouteUpgrade1/2` untouched). A map with no enable tech therefore offers `TradeRouteUpgrade1/2` at land posts.
- **The dormant capturable pair** [LIKELY]. `TradeRouteUpgradeCapturable1/2` are meant for capturable posts, but no proto lists them (0 hits in `protoy.xml` and `protomods.xml`), and vanilla capture posts list their techs explicitly (India1/2, V-proto 94313 / 94360). So most likely no player can research them. Against it: both carry `YPCapturableTradeRouteUpgradeTech`, which DXG 1409 describes as "Denotes a technology to be made available in Capturable Trading Posts", so an engine path that needs no proto row is not ruled out. Their only other uses are `YPEnableTradeRouteIndian`, which makes them unobtainable, and `zpDisableAllTradeRouteUpgrades` (3.5), which does the same. Cheapest test: on silkRoad (nautical 'water' route, where `TradeRouteUpgradeCapturable1` is OBTAINABLE), capture a post in Colonial and look for a 'Trade Cart' button (O40). This bears directly on 8c T3.
- **What the mod overrides** [PROVEN]. Of all vanilla trade techs, `techtreemods` overrides only `DETradeRouteUpgrade2Enable`, to add `zpPolarExpress`. The mod redefines no vanilla upgrade or enable tech. Its own techs that switch vanilla upgrades off (for example `zpDisableAllTradeRouteUpgrades`) are new records (3.5).

### 3.4 The capture techs are not upgrades [PROVEN]

`ypTradeRouteCaptureable` (66172, `YPNauticalTPOnly`), `deTradeRouteCaptureableAfrican` (97099, `YPLandTPOnly`) and `deTradeRouteCaptureableEuropean` (138159, `YPLandTPOnly`) share these traits:

- all three are OBTAINABLE, with prereq `Colonialize`;
- all carry `YPCapturableTradeRouteUpgradeTech`, the flag that means "made available in Capturable Trading Posts" (DXG 1409);
- their only own effect is `XPRate 0.50 BasePercent` on the player.

**How they arrive.** No proto lists them. They arrive through map-type `<forcetech>`:

| map types | forced capture tech | V-mst lines |
|---|---|---|
| silkRoad1-3 | ypTradeRouteCaptureable | 997 / 1039 / 1080 |
| sahara, transsaharanroute1-3, lostsahara1-3 | deTradeRouteCaptureableAfrican | 2410 / 2754 / 2797 / 2840 / 2926 / 2970 / 3014 |
| euroTradeRouteCapture | deTradeRouteCaptureableEuropean | 3343 |

Two mod maps grant them by trigger instead (2.7).

**What they unlock.** The `restricttocapturabletp` crates (T4).

**Unresolved.**

- **Colonialize prereq under forcetech** [OPEN] (O11). Of the 48 distinct map-forced techs, only the three capture techs carry an age prereq (Colonialize; V-tech 66172, 97099, 138159). `deCatamaranAfrican`'s only prereq is `deMapAfricanCoast` (V-tech 108776-108789), which is forced alongside it (V-mst horn 2064 / 2065, swahilicoast 2672 / 2673). `<forcetech>` may therefore mean "research as soon as the prereqs allow", which would put the capture crates at Colonial.
- **XPRate scope** [OPEN] (O12). DXG 1771 describes XPRate as "Multiplier to be applied over Trade Route granted resources ... Player", which would also hit a normal TP on the same map.
- **Land-flagged tech on a nautical post** [OPEN] (O9). `deTradeRouteCaptureableEuropean` is `YPLandTPOnly`. Whether it unlocks the capture crates on a NAUTICAL capture post is untested.
  - A mod comment in `zpindependencewar.xs` (above 1658, commit `06709709`) says naval harbours need `ypTradeRouteCaptureable` and "Elbe rides it too". The data contradicts this: Elbe's map type forces the European, land-flagged tech.

### 3.5 Table: enable and disable techs

What each one flips. Sources: V-tech and M-tech.

| enable tech | file:line | -> unobtainable | -> obtainable | -> active | other effects |
|---|---|---|---|---|---|
| YPEnableTradeRouteIndian | V 7868 | TradeRouteUpgradeCapturable1/2 | ypTradeRouteUpgradeIndia1/2 | - | SetName ypTradingPostCapture -> 66616 'East India Company Site'; forced by no map type |
| YPEnableAsianNativeOutpost | V 7880 | TradeRouteUpgrade1/2 | ypTradeRouteUpgrade1/2 | - | Stagecoach -> Trade Cart, Travois -> Rickshaw names and icons; TradingPost icon from ypTradingPostAsian |
| DEEnableTradeRouteUpgradeAll | V 76819 | TradeRouteUpgrade1/2 | DETradeRouteUpgradeAll1/2 | - | - |
| DEEnableTradeRouteNativeAmerican | V 81163 | TradeRouteUpgrade1/2 | deTradeRouteUpgradeAmerica1/2 | - | deStagecoach -> 'Traveling Merchant', Travois renamed, icons |
| DEEnableTradeRouteMaghrebi | V 81236 | TradeRouteUpgrade1/2 | DETradeRouteUpgradeMaghreb1/2 | - | Trade Cart / Rickshaw names, Asian icons |
| DEEnableTradeRouteAfrican | V 97012 | TradeRouteUpgrade1/2 | DETradeRouteUpgradeAfrica1/2 | - | African names and icons |
| DEEnableTradeRouteAfricanScenario | V 97292 | DETradeRouteUpgradeAfrica2 | DETradeRouteUpgradeAfricaRailroad2 | DEEnableTradeRouteAfrican | - |
| DEEnableTradeRouteWater | V 97088 | TradeRouteUpgrade1/2 | DETradeRouteUpgradeWater1/2 | - | - |
| DEEnableTradeRouteEuropeanRiver | V 129442 | TradeRouteUpgrade1/2 | DETradeRouteUpgradeRiver1/2 | - | TP icon from deIconEuropeanTradingPost |
| DEEnableTradeRouteEuropean | V 129552 | TradeRouteUpgrade1/2 | DETradeRouteUpgradeEurope1/2 | - | Travois -> 122538 'Scholar'; European TP, trader and train icons |
| DEEnableTradeRouteEuropeanRiverAll | V 135260 | TradeRouteUpgrade1/2 | DETradeRouteUpgradeRiverAll1/2 | - | TP icon |
| DEEnableTradeRouteEuropeanAll | V 135274 | TradeRouteUpgrade1/2 | DETradeRouteUpgradeEuropeAll1/2 | - | Travois -> Scholar, icons |
| DEEnableTradeRouteEuropeanWaterAll | V 139015 | TradeRouteUpgrade1/2, DETradeRouteUpgradeArcticWater1/2 | DETradeRouteUpgradeWaterAll1/2 | - | TP icon |
| DEEnableTradeRouteEuropeanWater | V 139031 | - | - | DEEnableTradeRouteWater | TP icon (unlocks nothing itself) |
| DEEnableTradeRouteArctic | V 173177 | TradeRouteUpgrade1/2 | DETradeRouteUpgradeArctic1/2 | - | - |
| DEEnableTradeRouteArcticWater | V 173188 | - | DETradeRouteUpgradeArcticWater1/2 | - | trading-ship Arctic names + UpdateVisual |
| DENavalTradeRouteEuropeanRename | V 138153 | - | - | - | empty Shadow |
| ypMapIndian | V 9775 | - | - | - | CopyTechIcon India1 -> ypTradeRouteUpgrade1 |
| deMapArctic | V 172531 | - | - | - | SetName / icons of WaterAll1/2 -> Arctic names (172575-172582) |
| DEIndependence | V 168531 | DETradeRouteXPShadow | - | DETradeRouteAllResourcesShadow | swaps the XP crate for deTradeCrateAll |
| XPTrickle | V 3329 | - | - | DETradeRouteXPShadow | XP crate from the start (activated by every Age0 tech) |
| zpEnableTradeRouteAfricanRiver | M 8343 | TradeRouteUpgrade1/2 | River1/2 | - | African icons; referenced by no map |
| zpNativeWaterTradeRoute | M 11506 | Europe1/2, yp1/2, Water1/2, WaterAll1/2 | zpTradeRouteUpgradeWaterNative | - | CommandRemove Water1/2 from TradingPost (zpriverina.xs 1305) |
| zpEnableTradeRouteAustralian | M 15192 | TradeRouteUpgrade1/2 | zpTradeRouteUpgradeAustralia1/2 | - | CommandRemove TradeRouteUpgrade1/2 from TradingPost; Australian icons |
| zpIsBurmaMap | M 6681 | Europe1/2, yp1/2, Water1/2, WaterAll1/2 | zpTradeRouteUpgradeTreasure | - | CommandRemove Water1/2 (mapspecifictechmods burma) |
| zpIsAztecMap | M 6931 | Europe1/2, yp1/2, Water1/2, WaterAll1/2 | WaterNative1/2 | - | CommandRemove Water1/2 |
| zpAztecCityGeneralSetup | M 25138 | Europe, yp, Water, WaterAll, WaterNative, America pairs | - | zpSPCAztecAltarBasicShadow, zpAztecTrade | CommandRemove Water1/2 |
| zpCivilWarGeneralStup | M 26622 | WaterNative1/2 | - | zpForbidRevolutions | CommandRemove WaterNative1/2 |
| zpMapOceania | M 18063-18068 | - | - | YPEnableAsianNativeOutpost | Asian names / icons; zpMapOceaniab then removes yp1/2; set by 3 map scripts (game/ zpmelanesia, zpnewguinea, zptorresstrait: `cTechzpMapOceania`) |
| zpMapOceaniab | M 18070 | ypTradeRouteUpgrade1/2 | - | - | auto-activates on YPEnableAsianNativeOutpost + zpMapOceania |
| zpDisableTradeRouteUpgrade | M 21349-21379 | TradeRouteUpgrade1/2, Europe1/2, EuropeAll1/2 | - | - | CommandRemove all six from TradingPost (Versailles; does not touch Water/WaterAll/River/RiverAll or any capture proto) |
| zpDisableAllTradeRouteUpgrades (dbid 50073, Shadow, UNOBTAINABLE; `fa44aea2`, widened in `750af968`) | M 39072-39364 | 39 techs: all 33 vanilla UpgradeTradeRoute / UpgradeAllTradeRoutes techs of T5 (TradeRouteUpgradeCapturable1/2 and India1/2 included) + the mod's six (zpTradeRouteUpgradeTreasure/2, WaterNative/2, Australia1/2) | - | - | CommandRemove 37 techs from TradingPost (the 39 minus Capturable1/2, which no proto lists), 22 from zpOrientalFerry and 22 from zpTradingPostCaptureNaval (the 22 rows each lists). Does NOT touch zpTradingPostCaptureNavalLone or NavalOriental (Black Sea, Elbe, Independence War), and leaves the capture techs alone. Activated for players 1..N by London (since `e4f89c3c` through `zpLondonSetup`, M-tech 38683, which the side setup techs granted at `zplondon.xs` 2829-2845 activate) and Istanbul (`zpistanbulb.xs` 4300-4304); never for gaia since `750af968` |
| zpArmoredTrainTech | M 12760-12793 | DETradeRouteUpgrade1Enable, 2Enable, Australia1/2 | - | - | kills every DE upgrade for that player; SpawnArmoredTrain on TradingPost / zpTrainStationA/B |

### 3.6 Table: map types that force trade-route techs

V-mst has 87 `<map>` entries, and 72 of them force trade-route techs. `rmSetMapType` can be called several times per script, and each call adds that type's forced techs [PROVEN]. The `euro*` names occur only in `mapspecifictechs.xml` and `maptypes.xml`, so a trade map type changes nothing but the forced techs: not nuggets, placement or AI data [LIKELY].

| forced trade techs | map types (V-mst line) | resulting upgrade pair per post kind |
|---|---|---|
| (none) | the other 15 entries (bayou 128, california 210, caribbean 250, carolina 288, greatLakes 413, greatPlains 453, newEngland 659, northwestTerritory 698, paintedDesert 737, rockies 861, saguenay 901, sonora 1121, texas 1247, yukon 1371, default 3548), plus any map type absent from the file | land: TradeRouteUpgrade1/2; nautical and river: nothing |
| DEEnableTradeRouteNativeAmerican | amazonia 2, andes 44, araucania 86, pampas 777, patagonia 819, yucatan 1329, mexico 1591, orinoco 1632 | land: America1/2 |
| ypEnableAsianNativeOutpost | borneo 167, ceylon 327, deccan 370, himalayas 493, kamchatka 535 (repeated at 3424), japan 575, mongolia 617, scenarioypack 940, siberia 954, Steppe2 1161, Steppe3 1204, yellowRiver 1287, fertilecrescent 1410, punjab 1453 | nautical: yp1/2; land: none |
| ypTradeRouteCaptureable + ypEnableAsianNativeOutpost | silkRoad1 995, silkRoad2 1037, silkRoad3 1079 | capture crates ypTradeCrateof*; vanilla capture posts have no upgrade |
| DEEnableTradeRouteUpgradeAll | colorado 1496, dakota 1536 | land: All1/2 (every route) |
| DEEnableTradeRouteMaghrebi | scenariomaghreb 1577 | land: Maghreb1/2 |
| DEEnableTradeRouteArctic | arcticterritories 1675 | land: Arctic1/2 |
| DEEnableTradeRouteArctic + ArcticWater | arcticterritorieswater 3507 | land Arctic1/2; nautical ArcticWater1/2 (per route) |
| DEEnableTradeRouteAfrican | arabia 1716, atlas 1758, congobasin 1800, darfur 1842, dunes 1885, greatrift 1970, highlands 2013, lakechad 2147, lakevictoria 2189, nigerriver 2278, nileriver 2321, sahel 2452, savanna 2494, siwaoasis 2579, sudd 2622, tassili 2711, tripolitania 2882 | land: Africa1/2 |
| DEEnableTradeRouteWater | goldcoast 1927 | nautical: Water1/2 |
| DEEnableTradeRouteAfrican + Water | horn 2057, ivorycoast 2103, nigerdelta 2233, peppercoast 2365, swahilicoast 2665 | land Africa1/2; nautical Water1/2 (per route) |
| deTradeRouteCaptureableAfrican + African | transsaharanroute1 2753, 2 2796, 3 2839, lostsahara1 2925, 2 2969, 3 3013 | capture crates African1; land Africa1/2 |
| deTradeRouteCaptureableAfrican + African + Water | sahara 2409 | capture crates African1; land Africa1/2; nautical Water1/2 |
| DEEnableTradeRouteAfricanScenario | scenarioafricaeast 2537 | land: Africa1 + AfricaRailroad2 |
| DEEnableTradeRouteEuropean | euroLandTradeRoute 3057, euroNoTrade 3301 | land: Europe1/2 |
| DEEnableTradeRouteEuropeanRiver | euroRiverTradeRoute 3097 | river: River1/2 |
| DEEnableTradeRouteEuropeanWater (-> DEEnableTradeRouteWater) | euroNavalTradeRoute 3137 | nautical: Water1/2 |
| European + EuropeanRiver | euroLandRiverTradeRoute 3177 | land Europe1/2; river River1/2 |
| European + EuropeanWater | euroLandNavalTradeRoute 3218 | land Europe1/2; nautical Water1/2 (per route) |
| European + EuropeanWater + EuropeanRiver | euroNavalRiverTradeRoute 3382 | all three per route |
| EuropeanAll + EuropeanRiverAll + EuropeanWaterAll | euroTradeRouteUpgradeAll 3259, Finland 3464 (+ DEMapFasterWaterTradeUnit 3469) | land EuropeAll, nautical WaterAll, river RiverAll: each upgrades every route |
| deTradeRouteCaptureableEuropean + DEEnableTradeRouteEuropean | euroTradeRouteCapture 3341 | land Europe1/2 (per route); nautical and river nothing; capture crates African1 |
| mod overrides (M-mst) | malta 2 (deEUMapUpdateVisuals + DEEnableTradeRouteEuropeanWater); caribbeanwater 39 and a duplicate at 58 (DEEnableTradeRouteWater + deMapAmerican); burma 44 (ypMapIndian + ypEnableAsianNativeOutpost + zpIsBurmaMap); eldorado 51 (zpIsAztecMap, M-tech 6931; registered in maptypemods.xml 5; `game/zpeldorado.xs` 72) | as in the rows above; eldorado: river posts WaterNative1/2 (Europe / yp / Water / WaterAll unobtainable, Water1/2 CommandRemoved from TradingPost) |

Every `euro*` type also forces `deMapEuropean` and `bpRegicideEuropeanMap` [PROVEN]. All of them are registered in `V maptypes.xml` 112-120. A new map-type name must be registered as a `<type>` in `data/maptypemods.xml`, as `malta`, `caribbeanwater`, `burma` and `piratehistoricalmap` are, and needs a `<map>` block in `mapspecifictechmods.xml`. Both files have XMB twins [PROVEN].

### 3.7 Table: European map types, and what each post can show

| map type (V-mst line) | forced trade techs (+ deMapEuropean, bpRegicideEuropeanMap) | post on a land route | post on a nautical route (incl. mod capture posts) | post on a river route | capture crates |
|---|---|---|---|---|---|
| euroLandTradeRoute (3057) | DEEnableTradeRouteEuropean | Europe1/2 | nothing obtainable | nothing | no |
| euroRiverTradeRoute (3097) | DEEnableTradeRouteEuropeanRiver | nothing | nothing | River1/2 | no |
| euroNavalTradeRoute (3137) | DEEnableTradeRouteEuropeanWater -> DEEnableTradeRouteWater | nothing | Water1/2 (own route) | nothing | no |
| euroLandRiverTradeRoute (3177) | European + EuropeanRiver | Europe1/2 | nothing | River1/2 | no |
| euroLandNavalTradeRoute (3218) | European + EuropeanWater | Europe1/2 | Water1/2 | nothing | no |
| euroTradeRouteUpgradeAll (3259) - Paris (`zpparis.xs` 148), performance_test (103); London until `fa44aea2` | EuropeanAll + EuropeanRiverAll + EuropeanWaterAll | EuropeAll1/2: upgrades ALL routes | WaterAll1/2: upgrades ALL routes | RiverAll1/2: upgrades ALL routes | no |
| euroNoTrade (3301) | DEEnableTradeRouteEuropean | Europe1/2 | nothing | nothing | no |
| euroTradeRouteCapture (3341) - Versailles 164, Elbe 89, Venice City 70 (+ zpvenicecit_test 70), Iceland (var at 46, set at 104), Black Sea 108, Istanbul 741, London 426 (since `fa44aea2`) | deTradeRouteCaptureableEuropean + DEEnableTradeRouteEuropean | Europe1/2 | nothing [LIKELY, O8] | nothing | yes, on capturable posts: deCrateof{Food,Wood,Coin}African1 + Influence/Export Capture [nautical posts: OPEN, O9] |
| euroNavalRiverTradeRoute (3382) | European + EuropeanWater + EuropeanRiver | Europe1/2 | Water1/2 | River1/2 | no |
| Finland (3464) | as UpgradeAll + DEMapFasterWaterTradeUnit | EuropeAll | WaterAll | RiverAll | no |

- Vanilla capture posts list only India1/2, so they show no upgrade under any of these types [PROVEN].
- Mod capture posts list 22 DE upgrades, so they show whatever the type enables for their route kind [PROVEN data, LIKELY display]. On London and Istanbul `zpDisableAllTradeRouteUpgrades` removes every upgrade from TradingPost, zpOrientalFerry and zpTradingPostCaptureNaval for players 1..N, whatever the map type (3.5).
- `euroNavalRiverTradeRoute` also forces the European LAND tech [PROVEN].

### 3.8 Table: the mod's own route techs (M-tech)

| tech | line | status | cost | prereqs | TP flag | effect | listed on / unlocked by |
|---|---|---|---|---|---|---|---|
| zpTradeRouteUpgradeTreasure | 6738 | UNOBTAINABLE | 200F/200W | zpIsBurmaMap, 1Enable | YPNauticalTPOnly | UpgradeTradeRoute 1 | TradingPost (M-proto 2226); zpIsBurmaMap 6681 makes it obtainable |
| zpTradeRouteUpgradeTreasure2 | 6784 | OBTAINABLE | 300W/400G | Treasure, 2Enable | YPNauticalTPOnly | UpgradeTradeRoute 2 | TradingPost |
| zpTradeRouteUpgradeWaterNative | 7378 | UNOBTAINABLE | 200F/200W | none | DERiverTPOnly | UpgradeTradeRoute 1 | TradingPost; zpNativeWaterTradeRoute 11506 / zpIsAztecMap 6931 |
| zpTradeRouteUpgradeWaterNative2 | 7398 | OBTAINABLE | 300W/400G | WaterNative, Industrialize (no 2Enable) | DERiverTPOnly | UpgradeTradeRoute 2 | TradingPost |
| zpTradeRouteUpgradeAustralia1 | 15144 | OBTAINABLE | 200F/200W | zpEnableTradeRouteAustralian, 1Enable | YPLandTPOnly | UpgradeTradeRoute 1 | TradingPost; zpEnableTradeRouteAustralian 15192 |
| zpTradeRouteUpgradeAustralia2 | 15168 | OBTAINABLE | 300W/400G | Australia1, 2Enable | YPLandTPOnly | UpgradeTradeRoute 2 | TradingPost |
| zpHansaTradeRouteUpgrade | 31770-31781 | UNOBTAINABLE Shadow, OrPrereqs, 0 rp | - | zpConsulateHansaWestern / Central / East | - | none; triggers read it | obtainable via zpBonuHansa 31789 (zpElbeSetup 31700, zpIcelandSetup 33592); Elbe 1706-1717 routes 1 and 2 -> 2; Iceland 2782-2790 route 1 -> 2 |
| zpVeniceTradeRouteUpgrade | 22127-22138 | same | - | zpConsulateVeniceDolphin / Cornaro / Contarini | - | none | zpBonusVenetians 22100 (zpvenicecity.xs 1062); 1320-1332 route 1 -> 2 |
| zpSultanateTradeRouteUpgrade | 35909-35920 | same | - | zpConsulateSultanatePhanar / Sufi / Corsairs | - | none | obtainable only on Black Sea: the only TechStatus obtainable for it is M-tech 35174 inside zpEnableIstanbulCityTechs (35161), which only `zpblacksea.xs` 1453 activates, despite its name; zpblacksea 2033-2044 route 1 -> 2. Istanbul neither enables nor reads it (`zpistanbulb.xs` never names it; its setup tech zpBosporusMapSetup, M-tech 37359-37408, does not either) |
| zpTradeRouteUpgradeHansaShadow | 30818 | UNOBTAINABLE Shadow | - | - | - | gates the unit delivery ypConsulatePrussianNeedleGun (M-routes 721) | activated by zpSPCHansaNeedleGunTradeRoute 31750 (TeamTech at zpHanseaticChurch, prereq Fortressize; obtainable via zpElbeSetup 31699) |
| zpSPCTradeRouteStop / GoEast / GoWest | 22255-22302 | UNOBTAINABLE, YPInfiniteTech | 100G / 20G | - | - | none; triggers read it | zpPirateTavern(B) (M-proto 47195 / 47545); zpEnableSPCPirateCityTechs 22519; zpcaribbeanwars.xs 1655-1776 |
| zpDisableAllTradeRouteUpgrades | 39072-39364 | UNOBTAINABLE Shadow (dbid 50073) | - | - | - | 39 upgrade techs unobtainable + CommandRemove on TradingPost / zpOrientalFerry / zpTradingPostCaptureNaval (full lists in 3.5) | London players 1..N (zpLondonSetup 38683, via the side setup techs, `zplondon.xs` 2829-2845), Istanbul players 1..N (`zpistanbulb.xs` 4300-4304) |
| zpLondonDeptfordStation | 39369-39382 | UNOBTAINABLE (OBTAINABLE at `fa44aea2`, UNOBTAINABLE since `750af968`) | 300W/400G, 60 rp | Industrialize | - | none of its own (dbid 50074, icon train_europe_icon, strings 503594 / 503595) | button on zpSPCLondonBasilica (St Paul's; M-proto 74373, page 11 column 0 at 74431 since `c72fa3b8`); zpLondonSetup makes it obtainable for London's players 1..N (M-tech 38685; before `e4f89c3c` the start trigger set status 1); trigger London_Deptford_Plr k (`zplondon.xs` 2897-2920): on Active -> Set Level TradeRoute 2 (road) Level 2, then status 0 + Disable Trigger for every other player. St Paul's also stands on Versailles (EU_Resource_Block_Cathedral), hence UNOBTAINABLE in data |
| zpLondonEastIndiaCompany | 39383-39396 | same | 300W/400G, 60 rp | Industrialize | - | none of its own (dbid 50075, icon trade_fluyt_icon, strings 503596 / 503597) | button on zpSPCMinster (M-proto 74495, page 11 column 0 at 74553); obtainable through zpLondonSetup (38686); trigger London_EastIndia_Plr k (2921-2944): Set Level TradeRoute 1 (lane) Level 2, then status 0 + Disable Trigger for the others |
| zpPolarExpress | 39621 | UNOBTAINABLE | 200W/200G | Colonialize | - | every techWithFlag DETradeRouteUpgrade: cost 0, AllowedAge -1; OR-prereq of 2Enable | Xmas maps |
| zpXmassTradeRoute | 39913 | Shadow | - | - | - | renames and re-icons TradeRouteUpgrade1/2 | zpgrinch.xs 1122, zpwinterwonderlandii.xs 1547 |
| zpUpdatePort1 / zpUpdatePort2 | 1767 / 1789 | - | - | - | - | UpdateVisual on the harbour centres | "ZP Trade Harbour AutoSetup" (gaia galleon / fluyt count) |
| zpTollstation | 20497-20507 | - | - | - | - | SetName zpSPCPortSocket -> 501979 'Toll Station' + CopyUnitPortraitAndIcon from zpTollStationIcon | London, Paris, Versailles (for players 0..N) |

### 3.9 How mod maps switch families on without a map type [PROVEN]

**Start triggers.** Many mod maps set an enable tech in a start trigger instead: "ZP Set Tech Status (XS)" compiles to `trTechSetStatus(player, cTechX, status)` (M-trig 2150-2155), where status 2 = active, 1 = obtainable and 0 = unobtainable.

- `DEEnableTradeRouteWater`: 19 `game/randmaps` maps (e.g. `game/zpmalta.xs` 1465, `game/zpvenice.xs` 1531).
- `zpEnableTradeRouteAustralian`: zpaustralia 1270 and others.
- Others: `zpMapOceania`, `zpIsAztecMap`, `zpNativeWaterTradeRoute` (zpriverina 1305), `DEEnableTradeRouteEuropeanRiver` (zpdeadsea 1033) and `DEEnableTradeRouteNativeAmerican` (`zpazteccity.xs` 1469).
- Capture techs: `deTradeRouteCaptureableEuropean` (`zpcivilwar.xs` 1474-1477) and `ypTradeRouteCaptureable` (`zpindependencewar.xs` 1658-1661).
- `game/zpmississippi.xs` 1846-1857 uses status 1 on `TradeRouteUpgrade1/2`; 2190-2197 then sets `zpTradeRouteUpgradeWaterNative/2` to status 0 once its trigger has levelled the routes.

**Engine checks.** The engine has its own "Set Tech Status" effect (M-trig 827-832, TechID of vartype tech, i.e. `rmGetTechID`). The encrypted vanilla `bpGreenland` uses it to set `DEEnableTradeRouteEuropeanWaterAll` (dump strings 15-20).

**Mis-spelled map type** [PROVEN]. `game/zpmalta.xs` 55 carries a garbled type, `euroLaclasssocketndNavalTradeRoute`, an unregistered name that probably has no effect; line 60 then sets `euroNavalTradeRoute`. No repo map uses `euroLandNavalTradeRoute`.

---

## 4. Posts and sockets

### 4.1 Table: every trade-post and socket proto

| proto | defined | what it is (from its data) | key unittypes / flags | route-upgrade techs in its `<tech>` list | tactics | used on |
|---|---|---|---|---|---|---|
| SocketTradeRoute | V-proto 28057; mod merge M-proto 22145 (+AbstractTradeRouteBuilding) | empty trade socket; a TradingPost builds on it | Socket, TradePostSocket, Unattackable; ForceToGaia, AlwaysShowAsSocket, Invulnerable | none | none | route-linked: London 731, Paris 345, Florence 1535/1542, Crownlands 851, KoB 268, Aztec City 332; baked in groupings: EU_SPC_Block_Trade_02 (London 1126-1127), IT_SPC_Block_Trade, EU_island_Bastille, Harbour_Universal_* |
| ypSocketTradeRoute | V-proto 94103 | Asian copy of the socket | same | none | none | no mod map |
| zpSPCPortSocket ('Toll Station') | M-proto 2957-2998 (id 20001) | socket with no subciv; a TradingPost builds on it | TradePostSocket, NativeSocket, Socket, NativeBuilding; ForceToGaia, Invulnerable | none | none | London bridge grouping (EU_SPC_London_Bridge.xml 63), Paris wall gates (zpparis.xs 1942), Harbour_Center_* groupings; renamed by zpTollstation |
| TradingPost | V-proto 9969-10562; mod merge M-proto 2226 | the buildable TP | AbstractTradingPost, ConvertsHerds; CreateUniqueInstance (10434); socketunittype TradePostSocket | all 31 vanilla at r0 p1 c0 (every T5 row except the Capturable pair); mod adds zpTreasure1/2, zpWaterNative1/2, zpAustralia1/2 at column 1 | tradingpost.tactics | every map |
| ypTradingPostAsian | V-proto 108091 | Asian-civ TP | CreateUniqueInstance, NotPlayerPlaceable | TradeRouteUpgrade1/2, yp1/2, India1/2 | tradingpost.tactics | no mod map |
| ypTradingPostCapture | V-proto 94139-94381 | pre-placed capturable post | CapturableTradingPost, AbstractTradingPost, TradePostSocket, Socket; InitialGarrisonOnly, Invulnerable, NotDeleteable; no CreateUniqueInstance | India1/2 only (94313, 94360) | yptradingpostcapture.tactics (AutoConvert 12 m) | silkRoad.xs 335; zpunknown variant |
| deTradingPostCaptureAfrican | V-proto 136779-137020 | same, African | same | India1/2 only | same | Sahara maps (encrypted), zpunknown variant |
| deTradingPostCaptureEuropean | V-proto 174595-174837 | same, European look | same (flags 174828-174830) | India1/2 only (174769, 174813) | same (174836) | zpverseilles.xs 565-587 (4 posts); vanilla euFrance |
| zpTradingPostCaptureNaval | M-proto 44876 (id 20579) | mod capturable harbour on water | CapturableTradingPost, AbstractTradingPost, AbstractFort; movement air, TieToWaterSurface, ApplyFlagOverrideIfGaia | 22: India2, All1/2, America1/2, Maghreb1/2, Africa1/2, AfricaRailroad2, Water1/2, River1/2, Europe1/2, RiverAll1/2, EuropeAll1/2, WaterAll1/2 (44934-44955) | yptradingpostcapture.tactics | Elbe, Venice City, Civil War, Iceland |
| zpTradingPostCaptureNavalLone | M-proto 62790 (20855) | same, FlattenGround | same | same 22 (62848-62869) | same | Elbe, Black Sea, Independence War |
| zpTradingPostCaptureNavalOriental | M-proto 67148 (20913) | same, oriental market look | same | same 22 (67206-67227) | same | Black Sea |
| zpOrientalFerry ('Ferry Harbour' 503362) | M-proto 72212-72332 (20968) | capturable harbour with a garrison and zpFerryDeploy | Socket (72263), TradePostSocket, CapturableTradingPost (72268), AbstractTradingPost, AbstractOutpost, MilitaryBuilding; air; maxcontained 40 | same 22 (72269-72290) | yptradingpostcapture.tactics (72331) | London (4; look swapped in zplondon.mods.xml 74-76), Istanbul (4) |
| TradingPostTravois 56303, ypTradingPostWagon 101887, deTradingPostWagon 122564, deStateCapitolTrainTradingPostWagon 123221, deTradingPostBuilder 141875 | V-proto | wagons that build a TradingPost | AbstractWagon | - | - | - |
| SocketIconTradeRoute 2137, deIconEuropeanTradingPost 168712, deIconAfricanTradingPost 142729, zpTollStationIcon (M-proto 42063) | V / M | icon sources for CopyUnitPortraitAndIcon | - | - | - | DEEnableTradeRouteEuropean*, zpTollstation |
| ypNuggetTradingPost | V-proto 8481 | guard nugget of capturable posts (nuggets.xml 99 / 101) | AbstractNugget | - | - | silkRoad, Sahara, euNuggetCapturable/2 (London uses 101) |
| props, not TPs: zpTradepostAztecCapturable 53144, zpSPCHarbour/B, zpSPCPortCenter*, zpHarbourCenterVenice, zpTrainStationA (22849; socketunittype TowerSocket) | M-proto | NativeBuilding props with 0 techs; zpTrainStationA is made a CapturableTradingPost only by zpcivilwar.mods.xml 4-14 | - | - | - | - |

### 4.2 Upgrades are tracked per post [PROVEN]

- `TradingPost` and `ypTradingPostAsian` are the only protos, vanilla or mod, with the flag `CreateUniqueInstance`.
- Every DE/TAD route-upgrade tech carries `UniqueProtoUnitInstance`, and the gate techs carry `DEForceUniqueInstancePrereqUpdate`.
- DXG 476 and 1379 define both flags as per-instance.
- The AI reads status per building: `ai/core/aitechs.xs` 2231 `kbBuildingTechGetStatus(<upgrade>, ownedTradingPostID) == cTechStatusObtainable`; `aieconomy.xs` 3622 does the same for crates.

Consequences:

- **A route can be at level 1 while a post on it still offers the level-1 tech** (section 9.3).
- **Capturable protos lack `CreateUniqueInstance`.** No capturable proto has it. What a per-instance tech does when researched on such a post (one post, or every post of that proto the player owns) is [OPEN] (O14).

### 4.3 How capture works end to end

**Vanilla** [PROVEN]:

1. **The post.** A pre-placed gaia post of a capturable proto, linked to the route with `rmSetObjectDefTradeRouteID`. It is a building and a socket at once (CapturableTradingPost, TradePostSocket, Socket), and it is Invulnerable and NotDeleteable.
2. **The guard.** A `ypNuggetTradingPost` nugget sits in the same object def: `Steam/silkRoad.xs` 332-337 add items `ypTradingPostCapture` + `Nugget` and call `rmSetNuggetDifficulty(99, 99)`. The vanilla guard nuggets are:
   - `euNuggetCapturable` (99);
   - `euNuggetCapturable2` (101: ypNuggetTradingPost + 4 deGuardianMusketeer, maptypes incl. westEurope; V nuggets.xml 8915-8942);
   - `deNuggetTradingPost1-3` (99, Sahara);
   - `ypNuggetTradingPost1-3` (99, silkRoad).
3. **Conversion.** `yptradingpostcapture.tactics` gives an `AutoConvert` action with `maxrange` 12.0 (string 69161). Vanilla keeps it suspended until the guard falls. afTransSahara (dump strings) has the trigger pair `DisableAutoconvert` ("Always" -> Unit Action Suspend AutoConvert True) and `GuardianDeath` ("Nugget Is Collectable" -> Suspend False). euFrance (dump strings) has four such pairs, `DisableAutoconvert` / `GuardianDeath` A-D (the plain pair plus B, C, D, each name twice), next to 7 `deTradingPostCaptureEuropean` strings (`Age3DERMeuFrance.dmp.txt` 2494-2634). `silkRoad.xs` 430-460 has the same pattern.
4. **Income.** Only the capture crates, and only when the map type forces a capture tech (3.4, T4).
5. **Upgrades.** None: India1/2 stay UNOBTAINABLE.
6. **AI.** A route whose first post is gaia-owned is "capturable, can't be upgraded" (6.1).

**Mod** [PROVEN unless marked]:

- **Tech rows.** The four mod capture protos carry the 22 upgrade rows. The original `zpTradingPostCaptureNaval` (`6049d700`, 2024-12-10) had none; the rows arrived in `0db2b2af` (2024-12-13, "Venice Map big update"). `zpOrientalFerry` inherited them when it was created (`e611db64`, 2026-08-19). This is history, not design.
- **Suspend and release by trigger with literal unit indices.** London:
  - 2013-2059 "London NoAutoConvert";
  - 2063-2107 "Harbour N1..S2 Convert ON", where "Nugget Is Collectable" on each guard index releases the post;
  - the indices come from a census (5.6).
- **Setup-tech lock.** A second, permanent lock is a setup tech applying `Data action="Autoconvert" subtype="ActionEnable" amount=0` to the capture proto for players 0..N. It is used by `zpElbeSetup` (M-tech 31667ff), `zpCivilWarGeneralStup` (26642-26643), `zpIcelandSetup` (33587) and `zpEnableIstanbulCityTechs` (35180-35181). The same maps also run a trigger-suspend release. Which lock governs capture is [OPEN] (O27).
- **Venice City's mods file.** `zpvenicecity.mods.xml` 191-194 removes the capture tactics from `zpTradingPostCaptureNaval` on that map. That commit (`44e482a5`) moved the change out of global protomods.
- **Mod guard nuggets** (`data/nuggetmods.xml`): 510 zpNuggetCapturableTradeEU1, 511 EUEst1-3 (Pirate / Cossack / Crabat), 514 AM / AM2, 517 Anatolia / Anatolia2, 603 zpNuggetLondonHarbour (the old water guard, now unused), plus 306 (Hansa cities, Elbe) and 298 (Venice).

### 4.4 Removing upgrade buttons from a post type [PROVEN pattern]

**The proven pattern** is a shadow setup tech that sets the upgrade techs UNOBTAINABLE and applies `<effect type="CommandRemove" tech="..."><target type="ProtoUnit">X</target>` to the proto. Vanilla uses the same double lock (`DESPCDelugeSetup` V-tech 127696-127703).

- The setup tech must fire for every player who could build or own such a post, because tech status and the command list are per player. Versailles applies the lock to players 1..N only and works: `zpverseilles.xs` 1817 `rmCreateTrigger("Starting Techs")`, 1819 `for(i=1; <= cNumberNonGaiaPlayers)` applies `zpVerseillesAttackerSetup` / `DefenderSetup` (1839 / 1853), which activate `zpDisableTradeRouteUpgrade` (M-tech 21298 / 21342); only the later `zpTollstation` loop (1865) starts at i=0. London applies `zpDisableAllTradeRouteUpgrades` to players 1..N (0..N at `fa44aea2`; 1..N since `750af968`; since `e4f89c3c` through `zpLondonSetup`, which the side setup techs granted at `zplondon.xs` 2829-2845 activate) and Istanbul to 1..N (`zpistanbulb.xs` 4294-4304). Elbe applies `zpElbeSetup` for `i=0; <= cNumberNonGaiaPlayers` (`zpelbe.xs` 1291-1296). Whether gaia needs the lock (for posts captured from gaia) is untested [OPEN] (O15).
- Precedents: `zpDisableTradeRouteUpgrade`, `zpNativeWaterTradeRoute`, `zpEnableTradeRouteAustralian`, `zpIsBurmaMap`, `zpIsAztecMap`, `zpAztecCityGeneralSetup`, `DESPCDelugeSetup` and `zpDisableAllTradeRouteUpgrades`. All target `TradingPost`. `zpDisableAllTradeRouteUpgrades` (`fa44aea2`, M-tech 39072-39364) is the first to target the capture protos too (`<effect type="CommandRemove" tech=...><target type="ProtoUnit">zpOrientalFerry</target>`, 22 of them, and 22 on `zpTradingPostCaptureNaval`). Whether such a lock still holds after capture is still [OPEN] (O15); the test is to capture a London ferry and check for any upgrade button.
- **Status versus command list** [LIKELY]. A TechStatus change hits every post of that player. CommandRemove hits one proto. To separate normal TPs from capture posts on the same route kind, only proto-level means work: CommandRemove on the capture proto, or the proto's own `<tech>` rows.

**Blunter instruments.**

- `zpArmoredTrainTech` makes both gates unobtainable, which kills every DE upgrade for the player, the land TP included.
- Per-player "ZP Set Tech Status (XS)" status 0 (Mississippi) switches a tech off without removing its button definition.

**Per-map proto override** [OPEN] (O15). `<tech mergeMode="remove">` in a per-map `.mods.xml` has no precedent. `mergeMode="remove"` is used there only on command (6), flag (19), minimapicon (6), tactics (2), unitregen (2), contain and unittype. No per-map `.mods.xml` carries techtreemods.

### 4.5 Sockets baked into groupings

- **Grouping units are never route-linked** [PROVEN]. `rmSetObjectDefTradeRouteID` works on object defs, and the harbour groupings are placed separately.
- **Harbour groupings** [PROVEN]. RM guide 6952-6957: `Harbour_Center_*` (a baked `zpSPCPortSocket`) "should only be used when there is exactly one trade route". `Harbour_Universal_*` (a baked `SocketTradeRoute`) works with any number of routes.
- **Capturable posts** [PROVEN]. A capturable socket never works inside a grouping (Istanbul `zpistanbulb.xs` 12-16, 1443-1447). It is placed on its own, route-linked with max distance 0.5 so that it docks on the lane, and the harbour grouping is then hung off the post's real position.
- **London's Toll Station** [LIKELY]. It is the bridge grouping's `zpSPCPortSocket` (census index 226 at 269.13, 345.58), renamed by `zpTollstation`. The owner's land TP showed a `YPLandTPOnly` tech, which implies it counts as linked to the road. How a TP on a baked socket picks its route on a two-route map is [OPEN] (O6).
- **The pirate-map AI** [PROVEN]. Its `CaribTPMonitor` rule builds TPs on `zpSPCPortSocket` (6.2).

### 4.6 Placement rules: what ties a Trading Post to a socket

- **The link** [PROVEN]. `TradingPost` names `<placementfile>tradepost.xml</placementfile>` (V-proto 9982). Vanilla `tradepost.xml` and the mod copy `data/placementrules/tradepost.xml` (identical content, with an `.xmb` twin) say:
  - `<distanceatmostfromsocket linkunit="true" distance="2">TradePostSocket</distanceatmostfromsocket>`: the post must stand within 2 m of a unit of type `TradePostSocket`, and `linkunit` links it to that socket;
  - `<distanceatleastfromtype player="enemy" foundation="any" distance="65">FirstTC</distanceatleastfromtype>`: at least 65 m from an enemy's first Town Center;
  - `<distanceatmostfromtype player="team" ... distance="75" norushonly="true">FirstTC</distanceatmostfromtype>`: in no-rush games, at most 75 m from a team first TC.
- **The city variant** [PROVEN]. `data/placementrules/tradepost_city.xml` is the same with the enemy-TC distance cut to 45 m. Four maps assign it in their `.mods.xml` (`<unit name="TradingPost"><placementfile>tradepost_city.xml</placementfile>`): `zpcivilwar.mods.xml` 46, `zpcrownlands.mods.xml` 307, `zpindependencewar.mods.xml` 16, `zpvenicecity.mods.xml` 242. Like every `*_city.xml` placement file in the repo, it has no `.xmb` twin. London does not override the TradingPost's placement file.
- **`TradePostSocket` is broader than trade sockets** [PROVEN]. 56 vanilla protos and 57 mod protos carry it: `SocketTradeRoute`, `ypSocketTradeRoute`, `zpSPCPortSocket`, the capture posts (`ypTradingPostCapture`, `deTradingPostCaptureAfrican`, `zpTradingPostCaptureNaval`, `zpOrientalFerry` ...) and every native socket (`SocketCree`, `deSocketStuart`, `zpSocketJewish` ...). Which subciv, if any, the post then serves comes from the socket, not from this rule.
- **Consequence for O6** [OPEN, a candidate explanation]. A London socket that "offers nothing" may simply fail the 65 m enemy-first-TC rule for that player; the rule, not the route link, would then explain the difference between sockets.

---

## 5. The script and trigger API

### 5.1 Table: RM calls

There are 13 trade calls in total: 10 route calls, plus `rmSetMapType`, `rmIsMapType` and `rmForbidTradeMonopoly`. Signatures come from the RM dump `Age3DERM00000_zplondon.dmp.txt` ("397 Syscalls"), and help text from the exe. No other `rm*TradeRoute*` or `*Monopoly*` name exists [PROVEN]. None of the calls takes a level, upgrade, owner or tech argument [PROVEN].

| ID | signature | engine help | uses (Steam .xs / mod maps) | pitfalls |
|---|---|---|---|---|
| 346 | int rmCreateTradeRoute() | Creates a trade route. | all | no type, owner or level; returned id + 1 = the trigger's TradeRoute |
| 347 | bool rmAddTradeRouteWaypoint(int id, float xFrac, float zFrac) | Adds the given waypoint to the specified trade route. | all | snaps to the def's 16 m blocksize grid (about 4 tiles off the asked point on Istanbul); a route needs at least 2 waypoints ('Trade route #%d needs at least two waypoints.') |
| 348 | bool rmAddTradeRouteWaypointVector(int id, vector v) | same | 0 / 0 | never used; units of v unknown (O38) |
| 349 | bool rmAddRandomTradeRouteWaypoints(int id, float endX, float endZ, int count, float maxVariation) | Adds random waypoints ... | 44 files (some commented) / zpgrinch 354-360 | needs one existing waypoint first ('A trade route must have at least one waypoint before you add additional random points.') |
| 350 | bool rmAddRandomTradeRouteWaypointsVector(int id, vector v, int count, float maxVariation) | same | 0 / 0 | never used |
| 351 | bool rmCreateTradeRouteWaypointsInArea(int id, int areaID, float length) | Creates a trade route in the specified area. | 0 / 0 | never used |
| 352 | vector rmGetTradeRouteWayPoint(int id, float fraction) | Retrieves a waypoint along the trade route based on the fraction. | all | only after the build; returns a point on the built, snapped line; the fraction runs along that line (which can extend past the map edge), not along an axis [LIKELY]; London reads real positions back through docked zpSPCWaterSpawnPoint controllers (zplondon.xs 164-176) |
| 353 | bool rmBuildTradeRoute(int id, string defName) | Builds the trade route with the given terrain type. | all | defName = a traderoutedefs record; returns bool (silkRoad.xs 365-367, unknown.xs 3110 check it); 'Bad trade route def name passed in!' |
| 276 | int rmSetObjectDefTradeRouteID(int defID, int routeID) | Set the trade route for all objects in this object definition. | all | registers sockets, stoppers and capturable posts; they get engine ids in the 0x40000 range (5.6); whether it docks or only links is [OPEN] (O34) |
| 248 | int rmCreateTradeRouteDistanceConstraint(string name, float minDist) | Make a constraint to avoid trade routes. | all | no route id: avoids every route that exists when the constraint is checked [LIKELY] |
| 362 | void rmSetMapType(string) | - | all | may be called several times; each name adds its forced techs; the only RM control over which upgrade techs exist |
| 363 | bool rmIsMapType(string) | - | 1 (commented, mercenaries.xs 8) | - |
| 391 | void rmForbidTradeMonopoly(bool=1) | Sets whether or not Trade Monopoly victory will be forbidden from being used in the current map. | 0 readable vanilla / 13 mod maps (Caribbean Wars has it commented out at 939) | AI: aiIsMonopolyAllowed() -> monopolyManager |
| (385) | int rmGetTechID(string) | - | unknown.xs 8005 | supplies the tech-type TechID for 'Trade Route Apply Tech' and 'Set Tech Status' |

Invalid route ids raise '%d is not a valid trade route ID.' [PROVEN]

### 5.2 Table: the trigger layer

Sources: M-trig, which is byte-identical to vanilla for the four route effects (V-trig 1535-1549 and 1796-1800). The engine exports exactly four `tr*TradeRoute*` functions [PROVEN].

| name | kind, M-trig line | params (vartype, default) | compiles to | mod users |
|---|---|---|---|---|
| Trade Route Set Level | effect 1623-1627 | TradeRoute (traderoute, 1), Level (long, 1) | `trTradeRouteSetLevel(%TradeRoute%, %Level%);` | zplondon 2860-2865 (start, both routes level 1) + 2902-2904 / 2926-2928 (route techs, level 2), zpistanbulb 4331-4336, zpelbe 1297-1302 + 1706-1717, zpverseilles 1875, zpvenicecity 1071 / 1325, zpvenicecit_test 1013 / 1117-1128, zpIceland 1981 / 2787, zpazteccity 1505-1518, zpindependencewar 1670 / 1689, zpcivilwar 2168, zpblacksea 1456 / 2033-2044; game/ bluemountains, eyrebasin, labradorcoast, mississippi, wildwest, wwcanyon |
| Trade Route Apply Tech | effect 1873-1877 | TradeRoute, TechID (tech, 0) | `trTradeRouteApplyTech(%TradeRoute%, %TechID%);` | vanilla unknown*.xs; mod game/zpunknown.xs 12408-12416 only |
| Trade Route Toggle State | effect 1618-1622 | TradeRoute, ShowUnit (bool, true) | `trTradeRouteToggleState(%TradeRoute%, %ShowUnit%);` | armored-train and lava maps (civilwar, Iceland, melanesia, hawaii, polynesia, labrador, bluemountains, wildwest, wwcanyon, eyrebasin, mississippi); caribbeanwars blockade 1550-1631 |
| Trade Route Set Position | effect 1613-1617 | TradeRoute, Position (float 0-1, 'Normalized Distance From Start') | `trTradeRouteSetPosition(%TradeRoute%, %Position%);` | none |
| Player Controls Socket | condition 152-156 | PlayerID, Socket (unit) | `trPlayerControlsSocket(p, "socket")` | - |
| Team Player Controls Socket | condition 399-403 | PlayerID, Socket | `trTeamPlayerControlsSocket(p, "socket")` | - |
| Socket Empty | condition 382-385 | Socket | `trSocketEmpty("socket")` ('no fully-built building occupying the socket') | - |
| Team SubCiv Trading Post Count | condition 386-392 | SubCiv, TeamID, Op, Count | `trTeamSubCivTradingPostCount(...)` | - |
| Player Unit Count | condition 132-138 | PlayerID, ProtoUnit, Op, Count | `trPlayerUnitCountSpecific(p, "proto") op n` | game/zpatols 1424-1452 (gaia galleon/fluyt -> zpUpdatePort1/2); game/zpmississippi 2211-2250 |
| Units Owned | condition 219-225 | unit, Player | `trUnitIsOwnedBy(%Player%)` | zpistanbulb 5109-5169 (Fort_N_Plr fc) |
| Nugget Is Collectable | condition | NuggetObject | - | London 2063-2107, afTransSahara (dump) |
| Unit Action Suspend | effect 962 | SrcObject, ActionName, Suspend | `trUnitSuspendAction("AutoConvert", b)` | the capture pattern: London 2013-2107, silkRoad 430-460 |
| Socket Build | effect 2098-2103 | PlayerID, Socket, ProtoUnit (TradingPost) | `trSocketBuild(p, "socket", "proto");` | London bridge towers |
| AIComms Claim TradePost | effect 1587 | SendToPlayerID, Area | `trAICommsClaim(p, x, y, z);` | - |
| Set Tech Status | effect 827-832 | PlayerID, TechID (tech), Status (2) | `trTechSetStatus(p, tech, s);` | - |
| ZP Set Tech Status (XS) | effect 2150-2155 | PlayerID, TechID (string 'cTechX'), Status | `trTechSetStatus(p, cTechX, s);` | every mod map's start trigger |
| ZP Set Tech Status Conditional (XS) | effect 2156-2168 | - | - | - |
| ZP Tech Status Equals (XS) | condition 482-487 | PlayerID, TechID (string), Status | `trTechStatusCheck(p, cTechX, s)` | zpelbe 1703-1720, zpIceland 2780, zpvenicecity 1320, zpblacksea 2033, zpindependencewar 1684, zplondon 2898-2901 / 2922-2925 |
| ZP Trade Harbour AutoSetup | effect about 3787-3830 | TechID (cTechDEEnableTradeRouteWater), Proto1 (deTradingGalleon), Proto2 (deTradingFluyt) | injects rules UpdatePortStartingTech / UpdatePortsI / UpdatePortsII through '}}'; activates DEEnableTradeRouteWater for players 1-8 and zpUpdatePort1/2 for gaia | no map calls the effect; 13 maps carry equivalent hand-written rules (zpcaribbeanwars, zpcivilwar, zpvenicecit_test; game/ zpatols, zpbarrierreef, zpdeadsea, zpmalta_castles, zpmediterranean, zpmississippi, zppolynesia, zptasmania, zptortuga, zpvenice); not London |

**Engine help (exe)** [PROVEN]:

- `trTradeRouteSetLevel(traderouteindex, level)`: "Sets the specified trade route to the specified level from a trigger."
- `trTradeRouteApplyTech(traderouteindex, techid)`: "Applies the specified tech to the specified trade route, assuming that this tech refers to the next tr level for this tr type."
- `trTradeRouteToggleState`: "Enable or disables the unit from showing."
- `trTradeRouteSetPosition`: "Places train on a specified position on the route."

**Set Level versus Apply Tech.**

- **Set Level** has no player parameter and no tech parameter. It moves the route map-wide: its units and look, for everyone. [PROVEN]
  - It does **not** retire the upgrade tech: the owner saw it on London, 2026-09-24 (build `67f294f1`..`cae26f9b`). Versailles and Mississippi both remove the techs separately after levelling, which neither would need if Set Level retired them; London and Istanbul do the same since `fa44aea2` (`zpDisableAllTradeRouteUpgrades`). [PROVEN in data plus in-game observation]
  - Researching the level-1 tech later only re-sets level 1. For `EuropeAll1` that is Data2 amount 1 Absolute.
- **Apply Tech** is the vanilla form: `Steam/unknown.xs` 7995-8013. On European regions only, and with 20 % chance (7995 `if (rmRandFloat(0,1) <= 0.20 && euMap == 1 && tpORnot != 5)`), it creates trigger `setupRailroad` (runImmediately, priority 4), which applies `DETradeRouteUpgradeEurope1` to `tradeRouteID+1` (8003-8005), and then `Europe2` with a further 25 % chance (8007-8012), on a `euroLandTradeRoute` map (1524) with the `dirt` def (1547).
  - Encrypted vanilla maps use it too (dump strings): euEngland applies Europe1/2, River1/2 and Water1/2; euDeluge applies Europe1; euEightyYearsWar applies Water1; euGreatNorthernWar applies Water1 twice; euRussoTurkWar applies Europe1/2 and also uses Set Level with 'TradeRouteRailway'.
  - **euDeluge pairs Apply Tech with a lock in the same trigger** (the one vanilla A1 + A2 recipe, 8a). Its dump string sequence (`Age3DERMeuDeluge.dmp.txt` 3322-3332) reads 'DelugeSetup; DelugeSetup; Trade Route Apply Tech; TradeRoute; TechID; DETradeRouteUpgradeEurope1; Set Tech Status; PlayerID; TechID; DESPCDelugeSetup; Status'. `DESPCDelugeSetup` (V-tech 127691-127706 for its trade part) CommandRemoves Europe1/2 from TradingPost, sets Europe1/2 unobtainable and removes the FourOfAKind command. The map is encrypted, so this is strings only. It hints that Apply Tech alone does not remove the next upgrade (Europe2) [LIKELY, not proof].
  - Whether Apply Tech marks the tech as researched on the route's posts (button gone, crates unlocked), including posts built later, is [OPEN] (O3). What it does with an `*All` tech is also [OPEN] (O4).
- **No condition reads a route's level directly** [PROVEN]. Maps read the level indirectly by counting gaia's trade units ("Player Unit Count" with PlayerID 0).

### 5.3 Table: engine trade functions for AI and trigger scripts

Every exported name containing TradeRoute, TradingPost, TradePost, Monopoly or Socket (exe).

| function | help string | used by the mod AI |
|---|---|---|
| kbGetNumberTradeRoutes() | gets number trade routes. | aisetup 507 |
| kbTradeRouteGetNumberTradingPosts(int index) | gets number trading posts on the route. | aitechs, aieconomy, aipiraterules |
| kbTradeRouteGetTradingPostID(int index, int postIndex) | gets trading post id from route. (AI comment: built and foundation posts only, no LOS needed) | aisetup 523, aitechs, aieconomy |
| kbTradeRouteGetNumberUnits(int index) | gets number units from route. | no |
| kbTradeRouteGetUnit(int index, int unitIndex) | gets unit from route. | aisetup 548, aitechs 2164 |
| kbUnitGetTradeRoute(int unitID) | Returns trade route of the unit. | no |
| aiSetTradingPostUnitType(int tpID, int puid) | Sets the trading post unit type. | aieconomy 3645-3650 |
| aiIsMonopolyAllowed() / aiReadyForTradeMonopoly() / aiDoTradeMonopoly() | monopoly possible / ready / execute | aisetup 2699, aimilitary 4316 |
| aiGetNumberTradePostsControlled(teamID) / aiGetNumberTradePostsNeededForMonopoly() | monopoly victory | no |
| aiBuildHMSocket(int socketID) | Builds the available building on the socket in historical maps. | aibuildings buildHistoricalMapSocket |
| trTradeRouteSetLevel / trTradeRouteApplyTech / trTradeRouteToggleState / trTradeRouteSetPosition | see 5.2 | - |
| trPlayerControlsSocket / trTeamPlayerControlsSocket / trSocketEmpty / trSocketBuild / trTeamSubCivTradingPostCount / trAICommsClaim | see 5.2 | - |
| upgradeTradeRoute(int unitID), tradeRouteTrain, tradeRouteCommand, uiFindTradeRouteSite, uiSocketBuild | UI and console ('UI use - upgrade the trade route associated with this unit') | - |

### 5.4 The TradeRoute index convention

**Rule** [PROVEN]. In a trigger, TradeRoute = the id `rmCreateTradeRoute()` returned, plus 1. Routes are numbered 1, 2, 3... in the order the script creates them. The AI numbers the same routes from 0 (`for (i = 0; < gNumberTradeRoutes)`, `ai/core/aisetup.xs` 520). AI index i is therefore trigger route i+1 [LIKELY].

Proof table:

| map | routes, in creation order | highest TradeRoute used | reading |
|---|---|---|---|
| Steam/unknown.xs (+ Large, LOST, LOSTLarge) | 2559 tradeRouteID (the second rmCreateTradeRoute at 2897 sits inside a /* */ block) | tradeRouteID+1 (8004, 8010) | RM id + 1 = trigger index |
| game/zpmelanesia | 242, 243 water_trail; 784, 797, 1158, 1166 lava_flow = 6 | 6 (2684, 2708) | 0-based numbering would make 6 invalid |
| zpIceland | 333 main + 1165-1186 lava = 5 | 5 (2429, 2453) | same |
| game/zphawaii, game/zppolynesia | 1 + 4 lava = 5 | 5 | same |
| zpcivilwar | 274 train, 288 / 300 armored, 372 native_water = 4 | 4 (2168 Set Level 4 = native_water_trail) | same |
| game/zpbluemountains, zpwildwest, zpwwcanyon | 4 | 4 | same |
| zpazteccity | 303, 309, 315 = 3 | 3 | same |
| zpelbe | 277 river_trail, 313 water_trail = 2 | 2 | consistent |
| zplondon | 598 waterRouteID water_trail, 625 tradeRouteID dirt = 2 | 2 (2863; also 2903 in London_Deptford_Plr k) | 1 = lane, 2 = road; the comments at 2857-2859 and 2886-2887 say so; scripts/mapcheck/tests/test_london_revolt.py pins it (TestTradeRouteLevels) and test_trade_route_plan.py pins the route triggers. The compiled London trigtemp passes the values through literally (5.5) |
| zpistanbulb | 1022 tradeRouteN, 1034 tradeRouteS (both water_trail) = 2 | 2 (4334) | 1 = tradeRouteN, 2 = tradeRouteS; the comment at 4330 says so |

- **Creation order or build order?** [OPEN] (O1). No catalogued map builds its routes in a different order from the one it creates them in. The vanilla `+1` idiom ties the number to the create id, so creation order is [LIKELY].
- **The London sighting does not prove the convention.** Stagecoaches on the road would also appear under 0-based numbering, because 'TradeRoute 1' would then be the road. The lane settles it at no cost: a Trade Galleon means 1-based numbering and both effects hit; a plain Trading Ship means otherwise (O2).

### 5.5 Compiled forms: where to see them

- **`Trigger/trigtemp.xs`** is the compiled trigger script of the LAST map generation [PROVEN]. Every generation overwrites it, so line numbers in it are not stable and are not cited here. A Versailles generation (2026-09-24, about 22:15) showed, inside `rule _Starting_Techs` (highFrequency / active / runImmediately): `trTradeRouteSetLevel(1, 1);`. London generations made after `fa44aea2` (for example the trigtemp of 23:23, a 2-player London at the `750af968` script) show `rule _LondonStartingTechs` with `trTradeRouteSetLevel(1, 1);` and `trTradeRouteSetLevel(2, 1);`, `rule _London_Deptford_Plr1` with `trTradeRouteSetLevel(2, 2);` and `rule _London_EastIndia_Plr1` with `trTradeRouteSetLevel(1, 2);`. The TradeRoute value is passed through literally, with no translation: 1 = the lane, 2 = the road, as the script numbers them.
- **The RM dump** (`RandMaps/Age3DERM<map>.dmp.txt`) lists compiled string constants. It is overwritten by every generation of that map; the 22:08 `zplondon` and 22:13 `00000_zplondon` dumps the research read are gone. The current ones: `Age3DERM00000_zplondon.dmp.txt` (23:11, the `fa44aea2` script) and `Age3DERMzplondon.dmp.txt` (23:23, the `750af968` script) each hold 4 'Trade Route Set Level' constants (start x2, Deptford, East India) and the map-type string `euroTradeRouteCapture`; only the 23:23 dump names `cTechDETradeRouteAllResourcesShadow`. Dump values are 0, because the dump is compile-only.
- **Encrypted vanilla maps** (all `eu*`, `af*`, `bp*`; 199 of the 447 `.xs` files in Steam RandMaps) can only be read through these dumps [PROVEN].

### 5.6 Unit indices versus engine ids [PROVEN]

A trigger parameter is a unit INDEX (the compiler emits `trUnitSelectByID`). `rmGetUnitPlaced` returns an ENGINE id, and units linked to a route with `rmSetObjectDefTradeRouteID` get engine ids in the 0x40000 range. Those ids are useless as trigger parameters: `trUnitSelect("262148")` is a no-op, and no fixed offset corrects them.

- **Use literal census indices.** London addresses its four ferries as 169-172 and their guards as 365 / 370 / 375 / 380 (`zplondon.xs` 1945-1968).
  - The 2026-09-24 census puts the ferries at 169-172 and the `ypNuggetTradingPost` guards at 366 / 371 / 376 / 381. The code has predicted the pole-less layout since the pole removal, which that census does not yet show.
  - Memory `rm-getunitplaced-stale-handles.md`; skill `rm-trigger-testing` 94-96; brief `docs/briefs/2026-09-22-trigger-testing-skills.md` 131-141.
- **Each built route consumes one index for its trade unit.** That is behind London's `instanceIdShift` and most likely behind King of Bohemia's "Fixed TradeRoute Issue" (`e52c6f6a`: every grouping-unit shift +0 -> +1) [LIKELY].

### 5.7 Build-order rules the maps rely on

- **Stopper first** [PROVEN as the owner's empirical rule]. The trade route is placed first, and a `zpSPCWaterSpawnPoint` stopper at waypoint 0.5 is needed: "without it the islands don't spawn". That comment appears in 11 map scripts, first in `zpparis.xs` (`180b1578`, 2024-11-07).
- **London law 1** (`zplondon.xs` 33-34): "a route built after water poisons every later water placement". London builds the lane first (598-604), defines the road (625), builds the gates, builds the road (724), then the river (735-738), posts, bridge and piers. The owner enforced this order after an inversion cost a day (memory `london-map-status` 2026-09-18).
- **Memory `rm-water-placement-rules.md`** (2026-09-17, nine editor tests):
  - land route + docked WSP before water;
  - nautical route after islands;
  - islands via `rmPlaceGroupingInstanceAtLoc` with max distance 0.00;
  - route-linked sockets do not snap (place with max 0.5, before their grouping);
  - read waypoints through controllers.

  The "nautical after islands" rule conflicts with London's lane-first order. Which rule is current is [OPEN] (O35).
- **Nothing may be placed on a built route** [PROVEN]. A park flush with the route failed silently (`096ded9b`). A gate placed on a built road fails, so the gates go before the road (`ed80e037`, `zplondon.xs` 619-622). An area in the river under an island stopped London Bridge (`12166f70`).
- **Rivers can remove units** [LIKELY]. London's lane stopper and two lane controllers (indices 1-3) were created and later removed; the likeliest cause is the river built over them in section 4 (O36).

---

## 6. The AI and trade routes

The AI is read-only for this guide. **AGENTS.md rule 7:** AI changes never change what the AI contests without the owner's approval (sockets, Trading Posts ...). Map-specific AI code lives only where `scripts/aitest/tests` (`APPROVED_LONDON_CODE`) lists the approval. Start with the `ai-edit` skill; `docs/ai_scripting_guidelines.md` rule 13. On 2026-09-24 a London change that filtered the bridge socket and far-bank TPs out of the stock Trading Post rule (`5c3e7233`, `londonSocketExcluded`) was reverted as a "heavy violation" (`9e3d7c45`). The owner's rule since then: the bridge and all TPs are taken normally. The gate test is `e097de05`. Brief: `docs/briefs/2026-09-23-ai-issues-log.md` row I13.

### 6.1 How routes are classified: mod AI versus retail AI

The mod AI decides each route's type once, at setup [PROVEN]. `ai/core/aisetup.xs` 507-615; `coreDLC/aisetup.xs` is byte-identical for this logic, and so are aitechs, aieconomy, aicore, aimilitary, aibuildings and aiglobals.

**The mod AI has lost the European branches** [PROVEN]. The mod's `game/ai/core/aicore.xs` replaces the vanilla core, and the vanilla `aiMain.xs` 2 includes `core/aiCore.xs`. The retail AI (`Steam Game/AI/core/aiSetup.xs` 511-607, `aiGlobals.xs` 75 `extern const int cTradeRouteEurope = 8;`) has European branches; the mod's route-type constants 0-7 (`aiglobals.xs` 248-256) have no Europe.

| check, in order | mod AI (ai/core/aisetup.xs) | retail AI (Steam AI/core/aiSetup.xs) | London under the mod AI |
|---|---|---|---|
| first Trading Post owned by gaia at setup (`xsSetContextPlayer(0)`; `kbUnitGetPlayerID(kbTradeRouteGetTradingPostID(i, 0)) == 0`) | 523: 'capturable Trading Route which can't be upgraded', max-upgraded true (526); Asian crates ypTradeCrateofCoin/Wood/Food (539-543) unless deMapAfrican is active | 511: same | lane (AI route 0; four gaia ferries): capturable Asia [LIKELY, O30] |
| naval | 548-556: first moving unit deTradingShip / Galleon / Fluyt -> Water1/2 | 535: DEEnableTradeRouteWater active -> Water1/2 | - |
| EuropeanWaterAll / RiverAll / River / European / Arctic / EuropeanAll | missing | 547-607: WaterAll1/2, RiverAll1/2, River1/2, Europe1/2, Arctic1/2, EuropeAll1/2 | - |
| NativeAmerican / Asian outpost / African | 562 / 573 / 584 | present | no |
| DEEnableTradeRouteUpgradeAll (the Colorado/Dakota 'All') | 595 -> All1/2 | 646 | not forced on London |
| default | 607-611: TradeRouteUpgrade1/2 ('North American Trading Route') | same | road (AI route 1) -> TradeRouteUpgrade1/2, both UNOBTAINABLE under DEEnableTradeRouteEuropean (the Capture map type since `fa44aea2`; under `DEEnableTradeRouteEuropeanAll` before) and again under `zpDisableAllTradeRouteUpgrades` |
| route already raised by Set Level | fully upgraded only if the first unit is deTradingFluyt / TrainEngine / deCaravanGuide (aitechs 2166-2168; aipiraterules 5657-5663) | same | no reaction |

### 6.2 The AI's trade rules [PROVEN]

| rule | where | what it does |
|---|---|---|
| tradeRouteUpgradeMonitor | aicore 2635; aitechs 2154 | researches a route's next upgrade only when `kbBuildingTechGetStatus(..., ownedTradingPostID) == cTechStatusObtainable` (2231); the second upgrade waits for Age 4 and a lead of 2 posts (2243-2244) |
| tradeRouteTacticMonitor | aicore 2638; aieconomy 3604 | picks a post's crate (difficulty Easy and up); requires the route's first upgrade Active or a capturable type (3620-3627); `aiSetTradingPostUnitType(tradingPostID, <gTradeRouteCrates entry>)` (3645-3650); line 3653 `break; // This route doesn't have the first upgrade active yet` |
| polarExpressUpgradeMonitor | aipiraterules 519 (enable) / 5668 (rule) | Christmas maps only (gaia zpPropChristmassTree): turns off the normal upgrade rule and buys level 2 without waiting for Age 4 |
| CaribTPMonitor | aipiraterules 392 / 3233 / 3254 | pirate maps (gIsPirateMap): builds TPs on zpSPCPortSocket with a Hero |
| tradingPostMonitor | aibuildings 3788 | queries every Socket-type unit (3857 `createSimpleUnitQuery(cUnitTypeSocket, cPlayerRelationAny, cUnitStateAny)`); a socket counts as claimed only if a TradingPost stands within 10 m (3866-3867) |
| monopolyManager | aisetup 2699-2708; aimilitary 4316 | enabled only if `aiIsMonopolyAllowed()`; `rmForbidTradeMonopoly(true)` keeps it off |

### 6.3 Consequences

- **European maps** [LIKELY]. The mod AI never upgrades a land route and never picks that post's crate. The land route falls to the North-American default, whose techs every European enable tech makes unobtainable, and the crate rule stops at 3653. This hits London, Paris and every other European map.
- **London** [LIKELY]:
  - the lane is capturable and never upgraded; a captured ferry gets Asian crate types, which need `ypTradeRouteCaptureable`, which London does not activate (O30, O31);
  - the road is a North-American route, so nothing is researched there (and since `fa44aea2` no upgrade is obtainable there anyway);
  - Set Level changes nothing for the AI;
  - `tradingPostMonitor` probably sees the ferries as empty sockets: they have the Socket unittype and no TradingPost within 10 m. This may account for part of the 19-27 failed Trading Post placements per player in AI test run 21 (`docs/briefs/2026-09-23-london-ai-test-report.md`) (O32).
- **A capture tech could line up with the AI** [LIKELY]. Granting `ypTradeRouteCaptureable` on a capture map would make the Asian crates the AI assigns to capturable routes valid. This is a data change, not an AI change; whether it is wanted is the owner's call.
- **Untested at time 0** [OPEN] (O33). It is not known whether `kbTradeRouteGetUnit(i, 0)` returns a unit at setup. If it returns -1, the mod AI's ship-based naval test would treat a pure water route as land.

---

## 7. Survey of maps

The survey covers all 19 scripts in `randmaps/`, all 33 in `game/randmaps/`, the readable vanilla maps, and the encrypted vanilla `eu*` / `bp*` / `af*` maps through their dumps.

### 7.1 Table: `randmaps/` (19 scripts)

| map | rmSetMapType (line) | routes, creation order: var @create, def @build (N = nautical) | posts linked to a route (proto x count, lines) | sockets baked in groupings (never route-linked) | route triggers | guards / notes |
|---|---|---|---|---|---|---|
| zplondon | grass, land, default, westEurope, piratehistoricalmap, euroTradeRouteCapture (421-426; euroTradeRouteUpgradeAll until `fa44aea2`) | #1 waterRouteID @598 water_trail @604 (N); #2 tradeRouteID @625 dirt @724 | #1: zpOrientalFerry x4 (747-778); #2: SocketTradeRoute x1 (731, helper 181-191); controllers zpSPCWaterSpawnPoint (612-615, 725-728); lane stopper unlinked (605-611) | EU_SPC_London_Bridge: zpSPCPortSocket = Toll Station (790, 1997); EU_SPC_Block_Trade_02: SocketTradeRoute (1126-1127) | players 1..N: zpLondonAttackerSetup / DefenderSetup (2829-2845), both activating zpLondonSetup (zpDisableAllTradeRouteUpgrades + DETradeRouteAllResourcesShadow active, Deptford / East India obtainable; M-tech 38683-38686); zpTollstation 0..N (2846-2856); Set Level r1=1, r2=1 (2860 / 2863); London_Deptford_Plr k -> r2=2, London_EastIndia_Plr k -> r1=2 (2886-2945); NoAutoConvert (2013); Convert ON x4 (2063-2107); Bridge_ON/OFF (2575+) | 4 land nuggets diff 101 (814-826); monopoly forbidden 2499 |
| zpparis | grass, land, default, westEurope, piratehistoricalmap, euroTradeRouteUpgradeAll (143-148) | #1 tradeRouteID @343 dirt @350 | SocketTradeRoute x2 at 0.05 / 0.95 (2p, 5+p) or 0.10 / 0.90 (3-4p) (355-371); stopper linked (344) | eu_wall_sw/ne_socketable[2]: zpSPCPortSocket x2 (308-325, 1942-1943); EU_island_Bastille: SocketTradeRoute (392) | none on routes; zpTollstation (2060); Gate1_ON_Plr k (3047) | Bastille nugget 297; forbid 1904; zpParisSetup touches no upgrade tech |
| zpverseilles | grass, land, default, westEurope, piratehistoricalmap, euroTradeRouteCapture (159-164) | #1 @372 dirt @379 | deTradingPostCaptureEuropean x4 (565-587, placed 810-819); SocketTradeRoute def linked but NEVER placed (366-374) | EU_SPC_Block_Trade_NoSocket (610) | Set Level r1=1 (1875); zpVerseilles*Setup -> zpDisableTradeRouteUpgrade (1839 / 1853); zpTollstation (1868; no port socket on the map) | nugget 510 zpNuggetCapturableTradeEU1 (808); forbid 1704 |
| zpelbe | grass, water, default, centralEurope, euroTradeRouteCapture, piratehistoricalmap (85-90) | #1 @277 river_trail @305; #2 @313 water_trail @338 (N) | #1: zpTradingPostCaptureNaval x2 (381-399) + NavalLone x2 (791-818; 797 relinked to #1 at 798); #2: CaptureNaval x2 (375-391, placed 423 / 427); Nugget x2 linked to #1 (803-820) | none | Set Level r1=1, r2=1 (1297 / 1300); zpHansaTradeRouteUpgrade -> r1=2, r2=2 (1706-1717) | nuggets 306 (Hansa cities, 419), 101 (lone, 815); no forbid |
| zpvenicecity | water, piratehistoricalmap, mediEurope, euroTradeRouteCapture (67-70) | #1 @280 water_trail @285 | zpTradingPostCaptureNaval x4 (331-383) | none | Set Level r1=1 (1071); zpVeniceTradeRouteUpgrade -> r1=2 (1320-1332) | fake stopper unlinked (288-296); nugget 298 (389); forbid 893; mods.xml removes the capture tactics |
| zpvenicecit_test | as zpvenicecity (67-70) | #1 @280 water_trail @285 | zpTradingPostCaptureNaval x4 (332-354) | none | Set Level r1=1 (1013); r1=2 on zpVeniceTradeRouteUpgrade (1117-1128) | forbid 868 |
| zpblacksea | grass, water, eastEurope, default, piratehistoricalmap, eurotradeRouteCapture [lower-case e] (103-108) | #1 @402 water_trail @426 | zpTradingPostCaptureNavalOriental x2 when blockadeSpawn==0, otherwise unlinked zpSPCWaterSpawnPoint (460-500); NavalLone x3 (734-747) + Nugget x3 linked (752-765), placed 771-776 | none | Set Level r1=1 (1456); zpSultanateTradeRouteUpgrade -> r1=2 (2033-2044) | nugget 511 (769); no forbid |
| zpistanbulb | grass, water, eastEurope, default, piratehistoricalmap, eurotradeRouteCapture [lower-case e], mediEurope (736-743) | #1 tradeRouteN @1022 water_trail @1032; #2 tradeRouteS @1034 water_trail @1043 | zpOrientalFerry x4, 2 per lane (1368-1375, 1388-1395, 1448-1455, 1468-1475) | trade harbour groupings with ypNuggetTradingPost baked (4266-4269) | Set Level r1=1, r2=1 (4331 / 4334) and zpDisableAllTradeRouteUpgrades for players 1..N (loop 4294, effect 4300-4304), both since `fa44aea2`; no custom upgrade trigger | nugget 517; forbid 748 |
| zpcivilwar | bayou, grass, water, piratehistoricalmap (76-79) | #1 @274 train @286; #2 @288 armored_train @298; #3 @300 armored_train @310; #4 @372 native_water_trail @443 | #1: zpTrainStationA x3 (731-760; capturable only through zpcivilwar.mods.xml 4-14); #4: zpTradingPostCaptureNaval x2 (406-420, placed BEFORE the build) | City_State_Western_* (zpTrainStationProps) | deTradeRouteCaptureableEuropean (1477); AT_Initialize r4=2 + toggles (2168-2180) | Autoconvert disabled in setup; forbid 1344 |
| zpindependencewar | grass, water, default, newEngland, piratehistoricalmap, caribbeanwater (105-110) | #1 @328 native_water_trail @357 | zpTradingPostCaptureNavalLone x4 + Nugget x4 linked (283-337, placed 989-999) | none | ypTradeRouteCaptureable (1661); Set Level r1=1 (1670); zpRevolutionAmerica -> r1=2 (1684-1696; comment 1678-1682 'no upgrade tech is researchable at the harbours on this map, so the Revolution is the only path') | nugget 514 (983); forbid 2060 |
| zpIceland | treasureSet, treasureSet2, tradeRouteMapType='euroTradeRouteCapture', 'piratehistoricalmap', grass, water (102-107; vars 43-46) | #1 @333 toiletPaper='water_trail' @358; #2-#5 lava_flow (1165-1191) | zpTradingPostCaptureNaval x1 (370-377) | none | Set Level r1=1 (1981); lava toggles r2-5 (2420-2453); zpHansaTradeRouteUpgrade -> r1=2 (2782-2790) | Autoconvert disabled in setup; no forbid |
| zpazteccity | grass, land, water, mexico, default, piratehistoricalmap (93-98) | #1 @303 native_water_trail @307; #2 @309 dirt @313; #3 @315 native_water_trail @318 | #2: SocketTradeRoute (331-336, placed 698-700) | AZ_Big_PlayerDistrict / Euro: SocketTradeRoute x4 (559 / 564) | zpAztecCityGeneralSetup, then DEEnableTradeRouteNativeAmerican (1462-1470); Set Level r1-3=1 (1505-1518) | forbid 1321; America1/2 re-enabled? (O24) |
| zpcrownlands | grass, land, default, centralEurope, euroLandRiverTradeRoute, piratehistoricalmap (164-169) | #1 @345: river_trail @355 (weirdMap 0) or dirt @369 (weirdMap 1) | SocketTradeRoute x4 (850-885) | none | none | forbid 1150 |
| zpflorence | grass, land, default, mediEurope, piratehistoricalmap, euroLandRiverTradeRoute (200-205) | #1 @452 river_trail @457; #2 @459 river_trail @463; #3 @465 dirt @477 | #1: SocketTradeRoute x2; #2: x2 (1530-1547) | IT_SPC_Block_Trade: SocketTradeRoute (897, placed 1035-1036, 1082-1083) | none | stopperID3 relinked 460 / 466; forbid 1674 |
| zpkingofbohemia | grass, land, default, centralEurope, euroLandTradeRoute, piratehistoricalmap (78-83) | #1 @249 dirt @613 (ring, built late) | SocketTradeRoute x5-8 (268-273, placed 745-807); zpTrainStopper linked (244-250) | none | none | forbid 1153 |
| zpcaribbeanwars | caribbean, piratehistoricalmap, grass, water, caribbeanwater (58-62) | #1 @176 water_trail @187; #2 @189 water_trail @200 | none (177 / 190 are one-argument link calls) | harbour_center_*: zpSPCPortSocket (477-499) | blockade Toggle State (1550-1631); zpSPCTradeRouteGo/Stop East/West | no forbid |
| zpgrinch | yukon, snow, land (43-45) | #1 @337 xmassnow @362; #2 @338 xmassnow @363 | SocketTradeRoute x1 per route (340-357, placed 370-377) | none | zpXmassTradeRoute (1122) | no forbid |
| zpwinterwonderlandii | treasureSet, ScenarioFreezing, snow, land (120-123) | #1 @396 toiletPaper='xmassnow' @492 | SocketTradeRoute (400-405, placed 511-646) | none | zpXmassTradeRoute (1547) | no forbid |
| performance_test | grass, land, default, westEurope, piratehistoricalmap, euroTradeRouteUpgradeAll (98-103) | #1 @292 dirt @299 | SocketTradeRoute x2 (287-294, placed 306-314) | eu_wall_*_socketable: zpSPCPortSocket (263 / 268); EU_island_Bastille (335) | zpTollstation | Paris clone; forbid 1604 |

### 7.2 Table: `game/randmaps/` (33 scripts, compact)

| map | trade map types | routes (defs) | route-linked posts | grouping sockets (unlinked) | route triggers |
|---|---|---|---|---|---|
| zpBalearicIslands | mapType5='euroNavalTradeRoute' (43, via 109-114) | 2x water_trail (315 / 324; #1 rebuilt 337) | SocketTradeRoute on useTradeRouteID (817-819) | Harbour_Universal_E/N/S/W | - |
| zp_z_cookislands, zpcookislands | water | water_trail | SocketTradeRoute | - | DEEnableTradeRouteWater |
| zpatols | water | 2x water_trail | SocketTradeRoute x2 defs | - | I/II Update Ports (1424-1452) |
| zpaustralia | australia, grass, water | 3x water_trail | zpSPCWaterSpawnPoint only | Harbour_Universal_NE/NW/S | - |
| zpbarrierreef | water, tropical, barrierreef | water_trail | none | - | - |
| zpbluemountains | australia, grass, land | dirt, armored_train, dirt, armored_train | SocketTradeRoute on #1 | Railway_Station_Big_* | AT_TR_Upgrade (zpArmoredTrainTech, 1868-1877) + toggles |
| zpburma_b | water, burma | asian_water_trail | none | treasure_ship_harbour1-3 (SocketTradeRoute) | - |
| zpcoldwar | arcticterritories, arcticterritorieswater, snow, water | 2x arctic1 | SocketTradeRoute x2 | - | - |
| zpdeadsea | arabia, desert, water | river_trail | none | Harbour_DeadSea* (zpSPCPortSocket) | DEEnableTradeRouteEuropeanRiver |
| zpeldorado | mexico, desert, water, eldorado | native_water_trail | SocketTradeRoute | - | - |
| zpeyrebasin | australia, desert, water | dirt, 2x armored_train | stoppers only (zpTradingPostCaptureInvisible def at 232 is dead; the proto is commented out at M-proto 78342) | Railway_Station_Big_* | AT_TR_Upgrade (1830-1836) + toggles |
| zphawaii | water | water_trail + 4 lava_flow | SocketTradeRoute | - | lava toggles |
| zpkurils | water, kurils, kamchatka | 2x water_trail | none | harbour_universal_* | - |
| zplabradorcoast | water, snow, yukon | snow, 2x armored_train | stoppers | Railway_Station_Big_SW* | AT_TR_Upgrade (1339-1345) |
| zpmalta | 'euroLaclasssocketndNavalTradeRoute' [garbled, 55], grass, water, mediEurope, medisea, euroNavalTradeRoute (60) | 2x water_trail | none | harbour_Universal_* | DEEnableTradeRouteWater (1465) |
| zpmalta_castles, zpmediterranean | water, mediEurope, euroNavalTradeRoute, anno | water_trail | none | Harbour_Center_* / harbour_arabia_* (zpSPCPortSocket) | - |
| zpmelanesia | water | 2x water_trail + lava | stoppers on lava | harbour_universal_* | lava toggles (2684, 2708) |
| zpmississippi | bayou, grass, water | dirt / armored_train variants + native_water_trail | SocketTradeRoute + stoppers | Railway_Station_Big_*, Harbour_Center_River_* | TradeRouteUpgrade1/2 status 1 (1846-1857); AT_TR_Upgrade (2148-2180); zpTradeRouteUpgradeWaterNative/2 status 0 (2190-2197) |
| zpnewguinea, zpphilippines, zptreasureisland | water (+ newguinea / caribbeanwater) | water_trail | SocketTradeRoute | Harbour_Universal_NW/SE (newguinea) | - |
| zppolynesia | water | water_trail + lava | lava stoppers (zpTreeCaribbean) | Harbour_Center_* | lava toggles |
| zpriverina | australia, grass, water | dirt, australia_river_trail | SocketTradeRoute on both | - | zpNativeWaterTradeRoute (1305) |
| zptasmania | tasmania, grass, water | water_trail, dirt | zpSPCWaterSpawnPoint; SocketTradeRoute on #2 | Harbour_Center_S/SE/SW | - |
| zptorresstrait, zpzealand | water / australia / newzealand | 2x water_trail | none | Harbour_Universal_* | - |
| zptortuga | caribbean, grass, water, caribbeanwater | water_trail | none | harbour_01-04 (zpSPCPortSocket) | - |
| zpunknown | per region, incl. Sahara, silkRoad3, euroLandTradeRoute, sahara | 1 route, toiletPaper per region | EITHER deTradingPostCaptureAfrican + Nugget OR ypTradingPostCapture + Nugget OR SocketTradeRoute (4271-4289) | - | Apply Tech Europe1(/2) (12408-12416) |
| zpvenice | water, mediEurope, euroNavalTradeRoute, adralicsea | water_trail | none | Venice_Harbour_01-03 (zpSPCPortSocket) | DEEnableTradeRouteWater (1531) |
| zpwildwest | texas, grass, land | dirt / armored_train pairs | stoppers (zpTradingPostCaptureInvisible def dead: 224-225, links commented 405 / 470) | Railway_Station_Big_* | AT_TR_Upgrade (1763-1773) |
| zpwwcanyon | sonora, desert, land | dirt, armored_train, dirt, armored_train | SocketTradeRoute + stoppers | Railway_Station_Big_* | AT_TR_Upgrade (1869-1878) |

### 7.3 Table: does any map combine capturable posts with normal Trading Post sockets?

The owner's statement "no map actually combines the convertible TPs and normal ones" holds for every readable script, mod and vanilla alike [PROVEN]. London is the first, and only, mixed map.

| map | normal route-linked SocketTradeRoute | port socket (Toll Station) | capturable post on a route | combined? |
|---|---|---|---|---|
| zplondon (mod) | 1 on the road (731; absent in both saved censuses, O6) | zpSPCPortSocket in the bridge (790) | 4x zpOrientalFerry on the lane | YES, the only mod map |
| zpparis / performance_test | 2 | 2 (wall gates) | none | no |
| zpverseilles | def only, never placed | none | 4x deTradingPostCaptureEuropean | no (capture-only) |
| zpelbe, zpvenicecity (+test), zpIceland, zpblacksea, zpindependencewar, zpistanbulb | none | none | zp capture protos / zpOrientalFerry | no (capture-only) |
| zpcivilwar | none | none | 2x CaptureNaval (#4) + 3x zpTrainStationA made capturable (#1) | no (two capturable kinds) |
| zpazteccity, zpcrownlands, zpflorence, zpkingofbohemia, zpgrinch, zpwinterwonderlandii | yes | no | none | no (normal only) |
| zpunknown | one kind per generation (4271-4289) | - | one kind per generation | no |
| vanilla afTransSahara (encrypted) | 'sockets to dock Trade Posts1/2' SocketTradeRoute | - | deTradingPostCaptureAfrican + Nugget, 2 defs, GuardianDeath / DisableAutoconvert triggers | [LIKELY] yes, from dump strings only; needs a census (O28) |
| vanilla euFrance, silkRoad | no | - | yes | no |
| vanilla unknown | yes | - | no (only the capturable map types Sahara / silkRoad3) | no |

### 7.4 Table: "upgrade offered again" exposure

Maps whose triggers set a route level while upgrade techs may still be obtainable.

| map | level set by trigger | family the map enables | who would still show it | suppression present | verdict |
|---|---|---|---|---|---|
| zplondon at `cae26f9b` (before `fa44aea2`) | r1=1, r2=1 at start (2884 / 2887 then) | EuropeAll1/2 (land), WaterAll1/2 (nautical), RiverAll1/2 | the road TP: EuropeAll1; a captured zpOrientalFerry: WaterAll1 (UpgradeAllTradeRoutes) | none | PROVEN for the land TP (owner-observed + data); LIKELY for the ferries (O7) |
| zplondon now (`e4f89c3c`) | r1=1, r2=1 at start (2860 / 2863); r2=2 on zpLondonDeptfordStation, r1=2 on zpLondonEastIndiaCompany (2897-2944) | Europe1/2 (land, Capture type) | none expected: TradingPost and zpOrientalFerry lose every upgrade command and every upgrade tech is unobtainable for players 1..N | zpDisableAllTradeRouteUpgrades (players 1..N, via zpLondonSetup) | LIKELY safe; whether the ferry lock holds after capture is O15 |
| zpistanbulb (`fa44aea2`) | r1=1, r2=1 at start (4331 / 4334) | Europe1/2 (land-only; both routes are nautical) | none expected | zpDisableAllTradeRouteUpgrades (players 1..N, 4300-4304) | LIKELY safe (O15) |
| zpverseilles | r1=1 (1875) | Europe1/2 (+ capture) | TradingPost: commands removed; deTradingPostCaptureEuropean lists only India1/2 | zpDisableTradeRouteUpgrade | LIKELY safe |
| zpazteccity | r1-3=1 (1505-1518) | America1/2 (mexico + trigger) | TradingPost on the dirt road | zpAztecCityGeneralSetup, then DEEnableTradeRouteNativeAmerican re-activated in the same trigger | OPEN (O24) |
| zpelbe | r1, r2=1; later =2 on the Hansa consulate | Europe1/2 (YPLandTPOnly) | captured CaptureNaval / NavalLone on route 1 (river_trail) might show Europe1 | none | OPEN (O25) |
| zpvenicecity (+test), zpIceland, zpblacksea | r1=1; later =2 on the consulate tech | Europe1/2 only | water_trail posts: Europe1 is land-only, so hidden; Water1 not enabled | custom zp*TradeRouteUpgrade path | LIKELY safe (Black Sea also hinges on O23) |
| zpindependencewar | r1=1; =2 on zpRevolutionAmerica | Water1/2 (caribbeanwater) | Lone posts on the river-kind native_water_trail | author's comment | LIKELY safe |
| zpcivilwar | r4=2 at start | none forced; capture tech set | - | zpArmoredTrainTech kills the enable gates | LIKELY safe |
| armored-train maps (6 in game/randmaps) | after zpArmoredTrainTech | - | - | gates DETradeRouteUpgrade1Enable/2Enable unobtainable | LIKELY safe |
| zpparis / performance_test | no Set Level | EuropeAll | TradingPost (normal upgrading) | - | not affected |
| vanilla euEngland, euDeluge, euEightyYearsWar, euGreatNorthernWar, euRussoTurkWar | Apply Tech (+ Set Level on RussoTurk) | Europe / River / Water | TradingPost | unknown | OPEN (O3) |

### 7.5 Table: vanilla European reference maps

All `eu*`, `af*` and `bp*` scripts are encrypted. This table is built from the string constants in the 30 eu/bp dumps plus the readable `.xs` files [PROVEN, as far as "this string is in the script"]. Vanilla `eu` maps without a dump are unsurveyed.

| map | source | trade map type | route defs seen | post protos | route trigger strings |
|---|---|---|---|---|---|
| euFrance | dump | euroTradeRouteCapture | eu_stone_trail (up to 4 routes) | deTradingPostCaptureEuropean ONLY (7 strings) | capture triggers DisableAutoconvert / GuardianDeath, plain + B, C, D (2 strings each; dump 2563-2634) |
| euBaltic | dump | euroTradeRouteUpgradeAll (+ 'Finland') | dirt?, water_trail (both strings present, dump 2232 / 2234) [LIKELY a land + naval route, strings only] | SocketTradeRoute | - |
| euWallachia | dump | euroTradeRouteUpgradeAll | river_trail | SocketTradeRoute | - |
| euFinland | dump | Finland | water_trail | SocketTradeRoute | - |
| euEngland | dump | euroNavalRiverTradeRoute | river_trail, water_trail | SocketTradeRoute | Apply Tech Europe1/2, River1/2, Water1/2 |
| euGreatNorthernWar | dump | euroLandNavalTradeRoute | water_trail | SocketTradeRoute | Apply Tech Water1 x2 |
| euDeluge | dump | euroLandTradeRoute | - | SocketTradeRoute (+ deTradingPostWagon) | Apply Tech Europe1 + Set Tech Status DESPCDelugeSetup in the same trigger (the lock, 5.2; dump 3322-3332) |
| euRussoTurkWar | dump | euroLandTradeRoute | - | SocketTradeRoute | TradeRouteRailway, Apply Tech Europe1/2, Set Level |
| euEightyYearsWar | dump | euroNavalTradeRoute | water_trail | SocketTradeRoute (+ deSPCCapturableSocketTower) | Apply Tech Water1 |
| euSaxony, euScotland | dump | euroLandRiverTradeRoute | river_trail | SocketTradeRoute | - |
| euBohemia, euDnieperBasin, euItaly, euLithuania, euPortugal | dump | euroRiverTradeRoute | river_trail | SocketTradeRoute | - |
| euArchipelago, euIberia (+Large), euSardiniaCorsica; bpBlackSea, bpGotland, bpHeligoland, bpIceland, bpNorthSea, bpShetlands | dump | euroNavalTradeRoute | water_trail | SocketTradeRoute | - |
| bpGreenland | dump | euroNavalTradeRoute | water_trail | SocketTradeRoute | 'Set Tech Status' DEEnableTradeRouteEuropeanWaterAll |
| euAlps, euAnatolia, euBalkans, euBudapest, euPomeraniaLarge, euPyrenees; bpBeringStrait, bpSouthNorway, bpHM* | dump | euroLandTradeRoute | (no literal) | SocketTradeRoute | bpHM*: TradeMonopolyLost |
| euArena, euGreatTurkishWar, euItalianWars, euNapoleonicWars, euThirtyYearsWar | dump | euroNoTrade | - | none / SPC district and city-state sockets | TradeMonopolyLost |
| afTransSahara | dump | TransSaharanRoute1-3 | dirt_trail_african x2 | SocketTradeRoute (Posts1/2) AND deTradingPostCaptureAfrican + Nugget | GuardianDeath / DisableAutoconvert |
| other af* dumps (13) | dump | - | dirt_trail_african / water_trail | SocketTradeRoute | - |
| silkRoad | Steam/silkRoad.xs 45-184, 330-372 | silkRoad1/2/3 | 'water' (nautical) | ypTradingPostCapture + Nugget in ONE def (difficulty 99) | - |
| Colorado, Dakota | .xs | colorado / dakota (DEEnableTradeRouteUpgradeAll) | 2x dirt | SocketTradeRoute | - |
| unknown | Steam/unknown.xs 452, 1082, 1749-2137, 2553, 2907 | Sahara / silkRoad3 / euroLandTradeRoute / sahara per region | toiletPaper | SocketTradeRoute only | Apply Tech Europe1(/2) |
| HMSevenYearsWar | .xs | euroNavalTradeRoute | - | - | - |

No readable vanilla map uses `euroTradeRouteUpgradeAll` or `euroTradeRouteCapture` [PROVEN]. The only readable vanilla European trade choices are `unknown.xs` and `HMSevenYearsWar.xs`.

### 7.6 Trade Monopoly [PROVEN]

**Where it is forbidden.** `rmForbidTradeMonopoly(true)` is set on:

| map | line |
|---|---|
| London | 2499 (`e2fb4795`; pinned by `scripts/mapcheck/tests/test_london_roles.py` 615-617) |
| Paris | 1904 (since `5478b1e2`) |
| Versailles | 1704 |
| Venice City (+ test) | 893 / 868 |
| Aztec City | 1321 |
| Civil War | 1344 |
| Crown Lands | 1150 |
| Florence | 1674 |
| King of Bohemia | 1153 |
| Istanbul | 748 |
| Independence War | 2060 |
| performance_test | 1604 |

It is absent on Elbe, Black Sea, Iceland, Caribbean Wars, Grinch and Winter Wonderland.

**The command stays.** TradingPost and every capture proto still list the `FourOfAKind` command (page 1, column 2; `zpOrientalFerry` 72328). Its associated tech `TradeMonopoly` is UNOBTAINABLE, with prereqs Industrialize OR DERevolutionLivonia (V protounitcommands.xml 1077-1082; V-tech 20631-20647).

**Open.** Whether captured posts count toward a monopoly on the maps without the forbid is [OPEN] (O39).

### 7.7 Code smells found in route calls [PROVEN]

- **Elbe route links.**
  - 314 links the stopper to route 1 again instead of route 2.
  - 797-798 and 809-810 link socketID6 and nuggetID6 to route 2 and then to route 1. Which call wins is [OPEN] (O26); probably the last, which would put both lone harbours and nuggets on the river route.
- **Florence.** 460 links stopperID3 to route 1, then 466 to route 3.
- **Caribbean Wars.** 177 / 190 call `rmSetObjectDefTradeRouteID` with ONE argument.
- **Civil War.** It places its route-4 harbours (406-420) BEFORE `rmBuildTradeRoute(tradeRouteID4)` (443).
- **Malta.** `game/zpmalta.xs` 55 has the garbled map type `euroLaclasssocketndNavalTradeRoute`.
- **mapspecifictechmods.** It has two identical `caribbeanwater` records.
- **Map-type spelling.** Black Sea and Istanbul spell the type `eurotradeRouteCapture`. Matching is [LIKELY] case-insensitive, because vanilla mixes case too: Arctic Territories calls `rmSetMapType("ArcticTerritories")` for record `arcticterritories`; Hokkaido uses 'Japan' for 'japan'; nuggets.xml uses 'Sahara' / 'TransSaharanRoute1'. Still untested (O23).
- **London `if` without braces** (outside trade, found in passing). 2046 and 2051 use `if (towerSFlagUnit >= 0)` / `if (towerNFlagUnit >= 0)` without braces. The condition guards only `rmAddTriggerEffect("Unit Action Suspend")`; the three `rmSetTriggerEffectParam` lines always run. (2169 and 2330 have braces.)

---

## 8. Recipes

Each recipe lists every viable design, its trade-offs, and what must be tested in game. The recipes are documentation; London and Istanbul have since applied a variant of 8a A2 and 8c L2 + T6 on their own (`fa44aea2`, `750af968`; section 9). House rules apply to every data change:

- new tech records go at the end of real content, directly above the file's first long TEST/commented section, ids continuing the real sequence (AGENTS.md rule 5);
- every `data/*.xml` edit needs its `.xml.xmb` twin rebuilt (rule 4);
- route records stay on one line (2.1);
- AI changes need the owner's approval (rule 7).

### 8a. Start a route at level N without its posts offering the same upgrade again

Facts to design around:

- Set Level moves the route but sets no tech [PROVEN].
- The post's button is the tech, tracked per post [PROVEN].
- The food/wood/coin crates need the level-1 tech Active [LIKELY].

| design | how | button afterwards | F/W/C crates | reaching level 2 later | evidence | status |
|---|---|---|---|---|---|---|
| A1 Apply Tech | 'Trade Route Apply Tech' with TradeRoute = id+1 and TechID = rmGetTechID(the level-1 tech of the family the map type enables for that route kind). For level 2, apply L1, then L2, in order (the engine help assumes 'the next tr level') | gone? | unlocked? | the L2 tech at the post, if L1 now counts as researched | Steam/unknown.xs 7995-8013; five encrypted eu maps; exe help | OPEN (O3, O4) |
| A1 + A2 Apply Tech + lock | Apply Tech L1 and, in the same trigger, a setup tech that CommandRemoves and locks L1/L2 | gone | unlocked if Apply Tech counts as research (O3) | by trigger only | vanilla euDeluge: Apply Tech Europe1 + Set Tech Status DESPCDelugeSetup (dump strings only, 5.2) | pattern PROVEN (strings), effect OPEN |
| A2 Set Level + remove the techs | Set Level, plus a setup tech for the players (Versailles, London and Istanbul use 1..N; see 4.4 on gaia): TechStatus unobtainable + CommandRemove on the proto (zpDisableTradeRouteUpgrade / zpDisableAllTradeRouteUpgrades idiom); or per-player 'ZP Set Tech Status (XS)' status 0 (Mississippi) | gone | locked for good (the tech never becomes Active): only XP / All / Influence remain, unless DETradeRouteAllResourcesShadow is granted (London `750af968`) | by trigger only: the Venice / Elbe shadow-tech -> Set Level 2 pattern, or London's route techs (9) | Versailles 14ad8066; game/zpmississippi 2190-2197; London / Istanbul `fa44aea2` | pattern PROVEN; crate effect LIKELY |
| A3 Set Level only | London at `67f294f1`..`cae26f9b` | stays | locked until bought | buy L1 (again), then L2 | owner, 2026-09-24 | PROVEN, not recommended |
| A4 No trigger | let players buy the upgrades | normal | normal | normal | Paris | PROVEN |

- **When A2 is fine.** A2 suits capture-only maps. Their income comes from capture crates, which key on the capture tech, not on an upgrade tech. That is why Versailles works.
- **When A2 hurts.** On a map with a normal TP, A2 leaves that TP with XP only: the per-resource crates (for example `deCrateof*European`, M-routes 533-580) need Europe1 OR EuropeAll1 OR Arctic1 Active, which a lock prevents for good, and Set Level sets no tech (5.2). Under `fa44aea2` alone London's land TP would therefore have offered XP (+ Influence for African civs) only [LIKELY, O5]. `750af968` grants `DETradeRouteAllResourcesShadow` to London's players 1..N (since `e4f89c3c` inside `zpLondonSetup`, M-tech 38684), which unlocks the `deTradeCrateAll` toggle (M-routes 732-743, playertechprereq only, 3 x 28.33 F/W/C). `deTradeCrateAll` has no `restricttocapturabletp`, so it may also appear on captured ferries (O10).

Which tech A1 needs:

| map type or enabler | land route | nautical route | river route |
|---|---|---|---|
| none | TradeRouteUpgrade1/2 | - | - |
| euroLandTradeRoute, euroTradeRouteCapture, euroNoTrade | DETradeRouteUpgradeEurope1/2 | - | - |
| euroNavalTradeRoute (or DEEnableTradeRouteWater by trigger) | - | DETradeRouteUpgradeWater1/2 | - |
| euroRiverTradeRoute | - | - | DETradeRouteUpgradeRiver1/2 |
| euroLandNavalTradeRoute (V-mst 3218-3222: European + EuropeanWater) | Europe1/2 | Water1/2 | - |
| euroLandRiverTradeRoute (3177-3181: European + EuropeanRiver) | Europe1/2 | - | River1/2 |
| euroNavalRiverTradeRoute (3382-3387: European + EuropeanWater + EuropeanRiver) | Europe1/2 | Water1/2 | River1/2 |
| euroTradeRouteUpgradeAll, Finland | EuropeAll1/2 (may raise every route, O4) | WaterAll1/2 | RiverAll1/2 |
| arcticterritories(water) | Arctic1/2 | ArcticWater1/2 (no crates, 2.9) | - |
| mod enablers | zpTradeRouteUpgradeAustralia1/2 | zpTradeRouteUpgradeTreasure/2 | zpTradeRouteUpgradeWaterNative/2 |

To test A1: in a Steam-root test copy (a bare `.xs` + `.xml`; a `.mods.xml` beside a Steam-root test map crashes the game, memory `mods-xml-never-in-game-root`), replace one Set Level with Apply Tech. Generate once, build a TP on that route, and read page 1 plus the crate toggles.

### 8b. Separate upgrades for a land route and a naval route

| design | how | land post offers | naval post offers | status |
|---|---|---|---|---|
| B1 | `rmSetMapType("euroLandNavalTradeRoute")` (V-mst 3218: European + EuropeanWater -> DEEnableTradeRouteWater) | Europe1/2, own route only (UpgradeTradeRoute) | Water1/2, own route only | PROVEN in data; used by no repo map; vanilla euGreatNorthernWar (dump) |
| B2 | `euroLandTradeRoute` + per-player "ZP Set Tech Status (XS)" `cTechDEEnableTradeRouteWater` status 2 at start (the 19-map game/randmaps precedent for the water half) | Europe1/2 | Water1/2 | LIKELY equivalent to B1 |
| B3 | `euroNavalRiverTradeRoute` when a river route is also present | Europe1/2 | Water1/2 (river: River1/2) | PROVEN in data |
| avoid | euroTradeRouteUpgradeAll, Finland, colorado / dakota | every upgrade raises every route | - | PROVEN |

- **Crates** [PROVEN in data]. The land post gets the European Food/Wood/Coin toggles after Europe1; the naval post gets the Water toggles after Water1.
- **Starting levels.** Use Apply Tech with Europe1 on the road and Water1 on the lane (euGreatNorthernWar applies Water1 twice) [OPEN, O3], or leave level 0.
- **Capture posts on the naval route.** The mod's capture protos list Water1/2, so under B1 or B2 they can upgrade their lane too. If they must not, add a lock from 8c.
- **AI** [LIKELY]. The mod AI books a naval route with a player-built first post as naval (Water1/2), which works. The land route falls to the North-American default, so the AI never upgrades it (6.3). Report only.

### 8c. Capturable posts that cannot upgrade and activate a capture-specific tech, next to a normal upgradeable TP

This is the owner's request of 2026-09-24. Three pieces are needed: (1) a normal TP that upgrades only its own route; (2) capture posts with no upgrade button; (3) a tech that capturing activates, which gives the capture posts their own behaviour.

**Why it is possible.** Nothing in `traderoutes.xml` forbids mixing the two [PROVEN]. Crates are split by `restricttocapturabletp`; techs are split by each proto's own `<tech>` list and the TP-kind flag. The silkRoad map types do half of this already, forcing a capture tech alongside a normal enable tech, although `silkRoad.xs` places only capture posts.

**Piece (1): the normal TP upgrades only its route.** Use a map type without "All", for example `euroTradeRouteCapture` or `euroLandTradeRoute` (T 3.7). [PROVEN in data]

**Piece (2): lock the capture posts.** Options, cheapest first:

| lock | how | pros | cons / risks | status |
|---|---|---|---|---|
| L1 map type unlocks nothing for their kind | under euroTradeRouteCapture or euroLandTradeRoute, a nautical post has no obtainable tech in its list (Water1 needs DEEnableTradeRouteWater, WaterAll1 needs ...EuropeanWaterAll, India1/2 unobtainable, the rest are land-only) | zero new data; seven mod maps already use euroTradeRouteCapture (Versailles, Elbe, Venice City, Iceland, Black Sea, Istanbul, London), plus the Venice City test copy | rests on the TP-kind filter (O8); breaks as soon as a naval family is enabled | LIKELY |
| L2 setup tech with TechStatus unobtainable + CommandRemove on the capture proto, for the players (see 4.4 on gaia) | the Deluge / Versailles idiom, aimed at Water1/2 and WaterAll1/2 (+ EuropeAll1/2 if All stays), target `zpOrientalFerry` | explicit, and robust to map-type changes | new tech record + XMB twin; TechStatus also hits any normal TP of that kind for the player (fine on London, where no normal naval post exists); zpDisableTradeRouteUpgrade itself is unusable (it strips the land TP and never touches Water) | pattern PROVEN. Applied on London and Istanbul as `zpDisableAllTradeRouteUpgrades` (`fa44aea2`), the first tech to target the capture protos (zpOrientalFerry, zpTradingPostCaptureNaval); it strips the land TP too, as the owner ordered ('all buttons removed'). Whether it still holds after capture is still O15 (test: capture a London ferry, check for any upgrade button) |
| L3 per-map `.mods.xml` `<tech mergeMode="remove">` on the proto | London-only override (zplondon.mods.xml already overrides the ferry's animfile) | map-local; zpOrientalFerry stays intact for Istanbul | no precedent for tech rows | OPEN (O15) |
| not suitable | zpArmoredTrainTech-style gate kill | - | removes every DE upgrade for the player, the normal TP included | PROVEN |

`zpOrientalFerry` is shared with Istanbul (`zpistanbulb.xs`, 5 references). Any lock must be map-local: a tech that only London activates, or London's `.mods.xml` [PROVEN].

**Piece (3): a capture-specific tech.** Options:

| hook | how | notes | status |
|---|---|---|---|
| T1 vanilla deTradeRouteCaptureableEuropean | forced by euroTradeRouteCapture, or by start trigger (zpcivilwar 1474-1477) | unlocks deCrateof*African1 plus Influence/Export Capture on capture posts; caveats: YPLandTPOnly on a nautical post (O9), XPRate 0.5 player-wide (O12), Colonialize timing (O11) | PROVEN data, OPEN in game |
| T2 vanilla ypTradeRouteCaptureable | start trigger per player (zpindependencewar 1658-1661), or a new map type | unlocks ypTradeCrateof* (nautical flag); also the crates the mod AI already assigns to capturable routes | PROVEN data, OPEN in game |
| T3 new zp capture tech on the proto | new tech flagged YPCapturableTradeRouteUpgradeTech (+ YPNauticalTPOnly), listed on the capture proto via the proto list or `CommandAdd tech=... <target type="ProtoUnit">` (precedent zpBourbonExpansionSPC, M-tech 21278ff); model: the dormant TradeRouteUpgradeCapturable1/2. For a capture-only upgrade, use the effect UpgradeTradeRoute (own route) | pros: full control of cost, age, effect; cons: new data + twin; per-instance behaviour on a proto without CreateUniqueInstance (O14) | building blocks PROVEN, combination OPEN |
| T4 per-player "on capture" trigger | condition 'Units Owned' on the literal post indices (London 169-172; Istanbul Fort_N_Plr 5109-5169 idiom) or 'Player Unit Count' of the capture proto >= 1, then effect 'ZP Set Tech Status (XS)' on the capture tech for that player | the literal-index rule applies (5.6) | PROVEN building blocks |
| T5 new capture-only income | a `<unitmultiples>` entry with `<restricttocapturabletp/>` + the new techprereq (a crate, or a unit delivery like the Hansa needle gun, M-routes 721) in traderoutes.xml | one-line names, XMB twin; traderoutes.xml replaces vanilla whole | PROVEN building blocks |
| T6 tech drives the level | shadow tech -> per-player 'ZP Tech Status Equals (XS)' -> Set Level 2 (Venice / Elbe / Black Sea / Iceland) | Set Level has no player parameter, so one player's tech upgrades the route for everyone | PROVEN in code |
| T7 new map type | register a name in maptypemods.xml plus a `<map>` block in mapspecifictechmods.xml forcing e.g. DEEnableTradeRouteEuropean + ypTradeRouteCaptureable (+ deTradeRouteCaptureableEuropean) (the malta / caribbeanwater / burma precedent) | data-driven, no trigger; if it replaces a euro* type, it must also force deMapEuropean and bpRegicideEuropeanMap | PROVEN pattern |

**Combined designs.**

| design | contents | effort | must be tested |
|---|---|---|---|
| D1 minimal | map type euroTradeRouteCapture; lane Set Level 1; normal route Apply Tech or level 0 | script only | O3, O8, O9, O11, O12 |
| D2 D1 + lock | D1 + an L2 setup tech on the capture proto | + 1 tech, twin | as D1 + O15 |
| D3 trigger-granted capture tech | euroLandTradeRoute (or euroTradeRouteCapture) + per-player start trigger for ypTradeRouteCaptureable and/or deTradeRouteCaptureableEuropean (T1 / T2) | script only | O9, O11, O12 |
| D4 own map type | T7 | + 2 data twins | O9, O11 |
| D5 fully custom | T3 + T4 + T5 (+ T6): capture posts get their own tech, income and optional level driver | most work, most control | O14, O15, plus balance |

**What London implemented** (`fa44aea2`, `750af968`, `e4f89c3c`; details in 9). Close to D2, with the lock widened to the land TP: map type `euroTradeRouteCapture` (piece 1 and hook T1: `deTradeRouteCaptureableEuropean` forced), both routes Set Level 1, `zpDisableAllTradeRouteUpgrades` for players 1..N (lock L2 on TradingPost, zpOrientalFerry and zpTradingPostCaptureNaval), `DETradeRouteAllResourcesShadow` so the road posts keep resource income, and a T6-style level driver keyed to two building techs (Deptford Station -> road level 2, East India Company -> lane level 2). No London-specific capture tech (T3-T5) exists; the owner's "specific tech for convertible TPs" is served only by the vanilla `deTradeRouteCaptureableEuropean`, whose effect on a nautical post is O9. `750af968` reports granting `ypTradeRouteCaptureable` as the owner's call if captured ferries show no resource toggles.

---

## 9. Case study: London

The research analysed London at `cae26f9b`: map type `euroTradeRouteUpgradeAll`, both routes raised by Set Level, no lock. Three commits then changed its trade design (`fa44aea2`, `750af968`, `e4f89c3c`; the owner's words in the `fa44aea2` message: "both trade routes lvl1 by default / all buttons removed / ... use same maptype for London"). 9.1 and 9.2 describe London now (HEAD `e4f89c3c`). 9.3 and 9.4 explain the earlier state that the owner reported. 9.5 compares the two, and 9.6 maps the research's proposed steps to what was applied.

### 9.1 What London does now (`randmaps/zplondon.xs`, 3786 lines at `e4f89c3c`)

| element | lines | detail |
|---|---|---|
| header: build order and laws | 10-43 | 1 = lane FIRST, 2 = road defined, 3.9 = road built, 4 = river, 5 = posts, 7 = harbours, 8 = guards; law 1 route-before-water; law 7 no hull floats on rmRiverCreate |
| routePoint / routeSocket helpers | 164-176 / 181-191 | routePoint: zpSPCWaterSpawnPoint linked and placed at a waypoint (read back); routeSocket: SocketTradeRoute linked, max 4 m |
| map types | 421-426 | grass, land, default, westEurope, piratehistoricalmap, euroTradeRouteCapture (426, since `fa44aea2`; euroTradeRouteUpgradeAll before). Capture forces deTradeRouteCaptureableEuropean + DEEnableTradeRouteEuropean (+ deMapEuropean, bpRegicideEuropeanMap), V-mst 3341-3345; none of the other types forces a trade tech |
| constraints | 450 / 452 / 465 | trade route: min 5 / wall 4 / resources 8 m |
| guard tunables | 509-511, 513 | difficulty 101, 2.5 m in, 3 m search; harbour 1 shift 17 m |
| route 1 = nautical U | 598-604 | waterRouteID, 4 waypoints (legs +/-16 m, turn 80 m west of the road), 'water_trail' |
| lane stopper | 605-611 | 'TradeShipStopperFake' zpSPCWaterSpawnPoint at waypoint 0.5, NOT route-linked |
| lane controllers | 612-615 | routePoint 0.2 / 0.8 -> zLaneS / zLaneN; the river centre is their mean |
| route 2 = land road (defined) | 625-628 | tradeRouteID, x = roadAsk 0.7756, z 0 -> 0.5 -> 1 |
| wall gates before the road | 646-718 | EU_SPC_London_Wall_SE/NW_01, x3 per bank on the road line |
| road built | 724 | 'dirt'; controllers 0.25 / 0.75 (725-728) |
| road socket | 731 | routeSocket(tradeRouteID, xRoad, zRiver): the only route-linked SocketTradeRoute; absent in both saved censuses (O6) |
| river | 735-738 | 'ZP London River', after both routes |
| ferry posts | 745-778 | harbourN1/N2/S1/S2PostDef: zpOrientalFerry, linked to waterRouteID (747 / 757 / 767 / 777), max 0.5 (they dock on the lane) |
| London Bridge | 790-797 | EU_SPC_London_Bridge (zpSPCPortSocket = Toll Station; gate sockets E/F) + marker |
| harbour groupings | 800-807 | EU_SPC_London_Harbour_NW_01 / SE_01 hung off the real post positions |
| harbour guards | 809-826 | landNuggetDef, difficulty 101 = vanilla euNuggetCapturable2 (ypNuggetTradingPost + 4 deGuardianMusketeer), 2.5 m inside the quay wall line |
| literal indices | 1945-1968 | posts 169-172, guards 365 / 370 / 375 / 380 |
| bridge socket id | 1997 | rmGetGroupingInstanceUnitByType(bridgeInst, 'zpSPCPortSocket') |
| AutoConvert suspended | 2013-2059 | posts, menageries, factories, tower flags |
| releases | 2063-2107 | 'Nugget Is Collectable' on each guard -> unsuspend AutoConvert on the post |
| monopoly | 2499 | rmForbidTradeMonopoly(true) |
| bridge follows its TP | 2562-2735 | Bridge_ON/OFF_Plr k: 'Units in Area' TradingPost within 8 m (bridgePostM, 2569) of the port socket |
| start trigger | 2828-2884 | LondonStartingTechs. Players 1..N (2829-2845): team 0 gets zpLondonAttackerSetup (2833-2836), the others zpLondonDefenderSetup (2840-2843); both activate zpLondonSetup (below). Players 0..N (2846-2856): zpTollstation + deEUMapUpdateVisuals. Set Level TradeRoute 1 Level 1 (2860) and TradeRoute 2 Level 1 (2863). zpConverGate for gaia (2866-2872) |
| route techs | 2886-2945 | per player k = 1..N, created at 2890-2894. London_Deptford_Plr k (2897-2920): condition 'ZP Tech Status Equals (XS)' zpLondonDeptfordStation = 2 (2898-2901) -> Set Level TradeRoute 2 Level 2 (2902-2904), then for every other player status 0 on the tech and 'Disable Trigger' on their copy (2905-2916). London_EastIndia_Plr k (2921-2944): the same for zpLondonEastIndiaCompany -> TradeRoute 1 Level 2 (2926-2928). Priority 4, active, runImmediately, no loop |
| per-map mods | zplondon.mods.xml 74-76 | zpOrientalFerry animfile -> buildings\market\city_market.xml (cd863e71); 59 / 71 command removes (Transform) |

The data side [PROVEN]:

| record | where | what it does for London |
|---|---|---|
| zpLondonSetup (Shadow, dbid 41543) | M-tech 38655-38688; trade part 38683-38686 | activates zpDisableAllTradeRouteUpgrades and DETradeRouteAllResourcesShadow, makes zpLondonDeptfordStation and zpLondonEastIndiaCompany obtainable (plus the non-trade shared setup: Military Camp, PopulationCap 250, no houses, cathedral / bank / tower techs, zpForbidRevolutions, zpExtendedStuartLondon) |
| zpLondonAttackerSetup / zpLondonDefenderSetup | M-tech 38934 / 38946 | each activates zpLondonSetup (38941 / 38953) plus its side's big-button pair |
| zpDisableAllTradeRouteUpgrades | M-tech 39072-39364 | the lock: 39 upgrade techs unobtainable, CommandRemove on TradingPost (37), zpOrientalFerry (22), zpTradingPostCaptureNaval (22) (3.5) |
| zpLondonDeptfordStation / zpLondonEastIndiaCompany | M-tech 39369-39382 / 39383-39396 | UNOBTAINABLE in data; 300W/400G, 60 rp, Industrialize; no effects of their own (3.8) |
| route-tech buttons | M-proto 74431 (zpSPCLondonBasilica, St Paul's, 74373) / 74553 (zpSPCMinster, 74495) | page 11, column 0 since `c72fa3b8` (column 5 at `fa44aea2`) |
| tests | `scripts/mapcheck/tests/test_trade_route_plan.py` (new in `fa44aea2`); `test_london_revolt.py` 162 | pin the lock, the route techs, the triggers and Istanbul's levels; TestTradeRouteLevels counts four 'Trade Route Set Level' effects |

What the census of the two saved 4-player generations shows [PROVEN] (both generations predate `fa44aea2`; the changes since are trigger and data only, so they create no units and shift no index):

| index (09-24 / 09-22) | proto | x, z (m) | owner | meaning |
|---|---|---|---|---|
| 0 / 0 | deTradingShip | 28.7, 328.0 / 107.4, 360.0 | 0 | the lane's trade unit, created by rmBuildTradeRoute (route 1) |
| 1-3 / 1-3 | (missing) | - | - | lane stopper + 2 lane controllers: created, later removed (O36) |
| 166 / 166 | Travois | 280.0, 456.1 / 280.0, 314.1 | 0 | the road's trade unit (route 2, level 0) |
| 167, 168 | zpSPCWaterSpawnPoint | 279, 177 / 279, 511 | 0 | road controllers 0.25 / 0.75 |
| (none) | SocketTradeRoute at the crossing | - | - | routeSocket (731) created no unit: no index gap between 168 and 169 |
| 169-172 | zpOrientalFerry | x 41-143, z 313-375 | 0 | the four Ferry Harbours (literal trigger indices) |
| 226 / 227 | zpSPCPortSocket | 269.13, 345.58 | 0 | bridge socket = 'Toll Station' |
| 366 / 371 / 376 / 381 (09-22: 363 / 368 / 373 / 378) | ypNuggetTradingPost | quay, by each harbour | 0 | difficulty-101 guards |
| 1960, 2014 / 1951, 2005 | SocketTradeRoute | 270.1, 217.7; 268.1, 475.7 | 0 | EU_SPC_Block_Trade_02 sockets, 9 m off the road |
| 7719 / 7697 | deNatEUPropStagecoach | 247.7, 528.3 | 0 | a prop, not a trade unit |

### 9.2 What each post offers now

- **The land TP on the road** (the "Toll Station"; which socket it stands on is O6):
  - Upgrades: none [PROVEN in data, LIKELY in game]. Every upgrade tech is unobtainable for players 1..N and removed from TradingPost's command list. Without the lock the Capture type would offer Europe1/2, own route only.
  - Crates [LIKELY, O5]: `CrateofXP` (every civ), `deTradeCrateAll` (from `DETradeRouteAllResourcesShadow`, since `750af968`), Influence for African civs. Never the European Food/Wood/Coin toggles and never Export: both need a level-1 upgrade tech Active (2.9, 8a). Under `fa44aea2` alone the land TP would have offered XP (+ Influence) only.
  - Route: the road runs Stagecoaches from the start (Set Level 1) and trains once any player researches Deptford Station at St Paul's [code PROVEN; in game OPEN, O41].
- **A captured Ferry Harbour** (`zpOrientalFerry` on the nautical lane):
  - Upgrades: none expected. Its 22 rows are CommandRemoved for players 1..N. Whether that holds for a post captured from gaia is O15. Even without the lock, nothing in its list would be obtainable for a nautical post under the Capture type (O8).
  - Crates: `CrateofXP`; the capture crates `deCrateof{Food,Wood,Coin}African1` (+ Influence / Export Capture) through the map-forced `deTradeRouteCaptureableEuropean`, if the land-flagged tech serves a nautical post (O9) and from Colonial (O11); possibly also `deTradeCrateAll`, which carries no `restricttocapturabletp` (O10). `750af968` names granting `ypTradeRouteCaptureable` as the owner's call if the ferries show no resource toggles.
  - Route: the lane starts at level 1 (a Trade Galleon if the 1-based numbering holds, O2) and reaches level 2 once any player researches the East India Company at the Minster (O41).
- **XPRate.** `deTradeRouteCaptureableEuropean` carries `XPRate 0.50 BasePercent` for each player once it is active. `750af968` reports it as halving the XP rate; the data alone does not say whether it halves or adds 50 % (O12).
- **The owner's screenshot** (captured Danish ferry, three buttons; taken on the `euroTradeRouteUpgradeAll` build, before `fa44aea2`):

  | button | most likely | evidence | status |
  |---|---|---|---|
  | "98" with a green check | the active crate toggle, most likely CrateofXP, the only toggle available there then. 98 against a base of 85 is unexplained; one lens suggests +15 % | 2.7; V-proto CrateofXP 29819 initialresource 85 | LIKELY / OPEN (O17) |
  | ship icon | DETradeRouteUpgradeWaterAll1 (removed by the lock since `fa44aea2`) | icon trade_galleon_icon | LIKELY |
  | two crossed arrows over a building | zpFerryDeploy (page 2, column 0) | M-proto 72329; protounitcommandmods 549-557, icon ability_ferry_eject.png ('four arrows over a pier') | LIKELY |

### 9.3 Why the Stagecoach was offered again (London at `67f294f1`..`cae26f9b`)

1. **The start trigger levelled the routes without any tech** [PROVEN]. `LondonStartingTechs` ran Set Level on TradeRoute 1 and TradeRoute 2, Level 1 (2884-2889 at `cae26f9b`, commit `67f294f1`). Both compile to `trTradeRouteSetLevel(route, 1)`: no tech, no player.
2. **The route changed** [PROVEN, by observation and data]. Road `dirt` became `stone` (Stagecoach). Whether the lane became `water2_trail` (Trade Galleon) is O2.
3. **The button did not** [PROVEN]. The buttons are techs, one copy per post instance. `DETradeRouteUpgradeEuropeAll1` stayed OBTAINABLE (prereqs `DEEnableTradeRouteEuropeanAll` + `DETradeRouteUpgrade1Enable`), so the "II" button stayed.
4. **It still had to be bought** [PROVEN / LIKELY]. Buying it cost 200F/200W and re-set every route to level 1: no visible change. But it was the only way to reach `EuropeAll2` (its prereq is `EuropeAll1` Active, V-tech 135237) and, most likely, to unlock the European food/wood/coin toggles.
5. **London had copied only half of the Versailles fix** [PROVEN]. Versailles solved this in 2024 (`14ad8066`) by pairing Set Level 1 with `zpDisableTradeRouteUpgrade`, which its setup techs activate. At `cae26f9b`, `zpLondonAttackerSetup` and `zpLondonDefenderSetup` (then M-tech 38913 / 38937) had no such effect.
6. **Closed since `fa44aea2`** [PROVEN in code]. The other half is now in place, widened to every family and to the capture protos: `zpDisableAllTradeRouteUpgrades`, activated through `zpLondonSetup` since `e4f89c3c`.

### 9.4 Why UpgradeAll was wrong for London (replaced in `fa44aea2`)

1. **Every upgrade was map-wide** [PROVEN]. `euroTradeRouteUpgradeAll` (426 at `cae26f9b`) forces the three `*All` enablers, and all their techs are `UpgradeAllTradeRoutes`. The player who bought at the land TP lifted the ferry lane; a player who captured a ferry could lift the road [LIKELY, O7]. That was the owner's complaint.
2. **It was the only reason the ferries could upgrade at all** [PROVEN]. They list the `WaterAll` rows (inherited from the 2024 capture proto), and UpgradeAll unlocked them. Vanilla capture posts would show nothing.
3. **No capture tech was forced** [PROVEN]. Captured ferries got no capture-specific income: only XP.
4. **It was never chosen** [PROVEN]. London took it over with the Paris frame on 2026-09-18 (`27039313`). Versailles started with the same type and switched to `euroTradeRouteCapture` the next day (`394e7272` -> `07817529`, 2024-11-19/20). Venice City went from `euroLandTradeRoute` to Capture within four days (`7d2e6146` -> `0db2b2af`).
5. **The AI gained nothing from it** [LIKELY]. The mod AI has no European branch and upgrades neither route (6.3).

### 9.5 Table: London before `fa44aea2`, versus now

| item | before (`cae26f9b`, euroTradeRouteUpgradeAll) | now (`e4f89c3c`, euroTradeRouteCapture + lock + route techs) | status |
|---|---|---|---|
| forced techs | DEEnableTradeRouteEuropeanAll, RiverAll, WaterAll (+ deMapEuropean, bpRegicideEuropeanMap), V-mst 3260-3264 | DEEnableTradeRouteEuropean + deTradeRouteCaptureableEuropean (+ the same two), V-mst 3342-3345 | PROVEN |
| setup techs, players 1..N | zpLondonAttackerSetup / DefenderSetup with no trade effect | the same two, now activating zpLondonSetup: zpDisableAllTradeRouteUpgrades, DETradeRouteAllResourcesShadow, the two route techs obtainable | PROVEN (code) |
| land TP upgrade (route 2, dirt) | EuropeAll1 'Stagecoach', then EuropeAll2; each upgrades EVERY route, the lane included | none (the Capture type alone would give Europe1/2, own route only) | PROVEN (data); display LIKELY |
| ferries' upgrade (route 1, water_trail, nautical) | WaterAll1 'Trade Galleons', then WaterAll2; each upgrades every route, the road included | none: removed for players 1..N; and nothing in the list is obtainable for a nautical post under Capture | LIKELY (O8, O15) |
| land TP income | XP until EuropeAll1, then European F/W/C | XP + deTradeCrateAll from the start; never European F/W/C or Export | LIKELY (O5) |
| ferry income | CrateofXP only; Water crates after WaterAll1 | CrateofXP + deCrateofFood/Wood/CoinAfrican1 (+ Influence/Export Capture); maybe deTradeCrateAll | LIKELY; OPEN whether the land-flagged capture tech serves a nautical post (O9), from which age (O11), and O10 |
| road level | 1 at start (Set Level); later moved by any post's *All tech | 1 at start (2863); 2 when a player researches zpLondonDeptfordStation (St Paul's, Industrial, 300W/400G) | PROVEN (code); OPEN in game (O41) |
| lane level | 1 at start; later any post's *All tech | 1 at start (2860); 2 on zpLondonEastIndiaCompany (Minster) | same |
| who raises a route | anyone who bought an *All tech at any post | the first player to research the route tech; the tech then goes to status 0 for everyone else and their triggers are disabled | PROVEN (code) |
| XPRate | - | +0.50 BasePercent XPRate from deTradeRouteCaptureableEuropean, once active; direction and scope unclear | OPEN (O12) |

London now uses the map type that Versailles, Elbe, Venice City, Iceland, Black Sea and Istanbul use. Istanbul uses the very same `zpOrientalFerry` proto and, since `fa44aea2`, the same lock. London is still the only map that also places a normal socket (7.3).

### 9.6 The research's change set, and what was applied

The research proposed the steps below (in this order) before `fa44aea2`. Their status at `e4f89c3c`:

0. **Run the free tests first** (9.7). Not done before the change. The tests that need the old build now need a test copy of `zplondon.xs` at `cae26f9b` (9.7).
1. **Map type** `euroTradeRouteUpgradeAll` -> `euroTradeRouteCapture` at 426. **Done** in `fa44aea2`. The capture tech arrives with it (piece T1 of 8c).
2. **Lane: keep Set Level 1.** **Kept** (2860). The optional raise to level 2 keyed to a tech is **done by other means**: London_EastIndia_Plr k (2921-2944), keyed to `zpLondonEastIndiaCompany` at the Minster.
3. **Road: Apply Tech instead of Set Level, or drop the Set Level.** **Not taken.** Instead Set Level 1 stays (2863), every upgrade button is removed (the owner: "all buttons removed"), level 2 comes from `zpLondonDeptfordStation` (2897-2920), and resource income comes from `DETradeRouteAllResourcesShadow` (`750af968`). O3 remains open but no longer decides London.
4. **Capture tech for nautical posts.** **Partly.** `deTradeRouteCaptureableEuropean` arrives with the map type; `ypTradeRouteCaptureable` is not granted (`750af968` leaves it to the owner). O9 decides. No London-specific capture tech exists (8c T3-T5).
5. **Optional lock on the ferries.** **Done by other means**, wider than proposed: `zpDisableAllTradeRouteUpgrades` also strips the land TP, as the owner ordered. It is a new tech, activated through `zpLondonSetup` since `e4f89c3c`.
6. **Script hygiene.** **Open.** The header (22-23) and the guard comment (811-813) still say a post is released by 'Units in Area'; the code has used 'Nugget Is Collectable' since `f4363cf5`. The 13.5 comment (2567) still says 'the land route's own SocketTradeRoute stands 10.3 m from the port socket', which the census contradicts. Whether `routeSocket(tradeRouteID, ...)` at 731 is needed is still O6.
7. **Tests.** **Done.** `test_london_revolt.py` 162 counts four Set Level effects; `test_trade_route_plan.py` pins the lock, the route techs and Istanbul; `test_london_roles.py` 615-617 still pins the monopoly forbid.
8. **AI: report only** (rule 7). Unchanged. Under the mod AI the lane stays "capturable, never upgraded" and the road stays unupgraded. `tradingPostMonitor` may try to build on the ferries (6.3). Any change needs the owner's approval and the `ai-edit` skill.

### 9.7 In-game tests, in order

On the current build (`e4f89c3c`):

| # | build | action | settles |
|---|---|---|---|
| T1 | current | at the start, look at the lane's trade unit: Trade Galleon or Trading Ship | O2 (index convention; both Set Levels hit) |
| T2 | current | in one game, build a TP on each spot (route socket if present, Toll Station zpSPCPortSocket, trade-block SocketTradeRoute); note whether placement is refused (the 65 m enemy-first-TC rule, 4.6), whether the route's trade units deliver to it, and which toggles (XP, All) appear. Upgrade buttons no longer tell the sockets apart | O6 |
| T3 | current | capture a ferry in Age 1 and again in Age 2; look for any upgrade button (none expected), capture crates and deTradeCrateAll; hover its buttons | O9, O10, O11, O15, O17 |
| T4 | current | on the land TP, note the toggles (XP, deTradeCrateAll, any F/W/C) | O5 |
| T5 | current | reach Industrial; research Deptford Station at St Paul's: the road's units turn to trains and the button disappears for the other players; then the East India Company at the Minster: the lane turns to level 2 | O41 |
| T6 | current | compare the XP counter and the land TP's delivered amount here with Paris | O12 |

Tests of the earlier design need a test copy of `zplondon.xs` at `cae26f9b` in Steam `Game/RandMaps` (bare `.xs`), with its two setup-tech grants (`cTechzpLondonAttackerSetup` / `cTechzpLondonDefenderSetup`) removed: since `e4f89c3c` those techs activate `zpLondonSetup` and with it the lock, so an unedited old script would still get it:

| # | build | action | settles |
|---|---|---|---|
| T7 | `cae26f9b` copy | capture one ferry; check for WaterAll1; research it and watch whether the road's units change and whether the land TP still offers EuropeAll1 | O7, O13 |
| T8 | `cae26f9b` copy | buy EuropeAll1 at the land TP before any ferry is captured; watch the lane | O16 |
| T9 | `cae26f9b` copy, edited | route 2: Apply Tech EuropeAll1 instead of Set Level; build the TP; read page 1 and the toggles; watch the lane | O3, O4 |
| T10 | `cae26f9b` copy | capture two ferries, research WaterAll1 on one, compare both | O14 |

Paris (`zpparis.xs` 148) and performance_test (103) still use UpgradeAll, but each has one land route only, so they cannot show a cross-route effect (O13, O16).

Test copies of London go into Steam `Game/RandMaps` as a bare `.xs` (+ `.xml`), never with a `.mods.xml` (memory `mods-xml-never-in-game-root`). Starting the game is the owner's call (skill `game-startup`).

---

## 10. Pitfalls, lessons and the OPEN index

### 10.1 Table: timeline of trade-route lessons

| date | commit | map / file | lesson |
|---|---|---|---|
| 2023-12-05 | 36270dd6 | traderoutes.xml | first mod chain: xmassnow -> xmasstagecoach -> xmastrain |
| 2024-01-04..02-05 | e1886c5b, 673c7d01, cd6150fd | armored_train | layered routes switched by Set Level and Toggle State (RM guide 15.3) |
| 2024-03-07 | 57ea1b9d | traderoutedefs | native_water chain nautical -> river: the kind attribute decides which TP-only techs show |
| 2024-07-11 | 2d95b432 | lava_flow | route + art crash fix (lava_flow is a river route with blocksize 8) |
| 2024-11-07 | 180b1578 | zpparis | euroTradeRouteUpgradeAll; first 'without it the islands don't spawn' stopper |
| 2024-11-11 | 5478b1e2 | zpparis | rmForbidTradeMonopoly(true) |
| 2024-11-19/20 | 394e7272 / 07817529 | zpverseilles | map type UpgradeAll -> Capture after one day |
| 2024-11-21 | 14ad8066 | zpverseilles + techtreemods | eu_stone_trail -> dirt; Set Level 1; zpDisableTradeRouteUpgrade via the setup techs |
| 2024-12-10/13 | 6049d700 / 0db2b2af | zpTradingPostCaptureNaval | proto created without tech rows, then given the 22 upgrade rows; Venice City switched to Capture |
| 2024-12-13 | 44e482a5 | zpvenicecity.mods.xml | map-specific proto edits moved into the map's .mods.xml |
| 2024-12-21 | 6091140e | zpvenicecity | DEEnableTradeRouteWater activation removed, Set Level 1 added: route levelling taken away from the posts on purpose |
| 2024-12-23 | a3d8ecbc | zpVeniceTradeRouteUpgrade | consulate -> shadow tech -> Set Level 2 |
| 2025-01-06 | 2d857dda | zpcaribbeanwars | harbour groupings offset per player count (lanes displace) |
| 2025-03-16 | e52c6f6a | zpkingofbohemia | 'Fixed TradeRoute Issue' = every id shift +0 -> +1 (the route's trade unit takes an index) |
| 2025-07-27 | 1d4043da | zpelbe | two capture routes, Set Level 1 on both, zpHansaTradeRouteUpgrade -> level 2 on both |
| 2025-10-05 | 27fb8c99 | zpverseilles | 4 x deTradingPostCaptureEuropean, EU_SPC_Block_Trade_NoSocket |
| 2025-10-26/27 | d0d5fc97 / 1ac83d6f | zpblacksea | zpSultanateTradeRouteUpgrade, Set Level |
| 2025-11-06 | a5527de4 | RM guide ch. 15 | 'capturable socket always needs to be assigned to a trade route' |
| 2026-07-25 | 7bca3463 / 1d6c862f | traderoutes / defs | arctic chains restored (a stale copy had lost them; `<level>` records are positional, pair them by index); 60 decals restored (wrong for water) |
| 2026-07-27 | d6d22541 | traderoutedefs | naval/river decals stripped again, on purpose |
| 2026-08-07 | e9800ad9 | traderoutedefs | DLC arctic records pasted multi-line (the later bug) |
| 2026-08-19 | e611db64 | zpOrientalFerry | ferry post created (inherits the 22 rows) |
| 2026-09-10/11 | ca2b2f7b | traderoutedefs | a multi-line name falls back to the base route; records collapsed to one line |
| 2026-09-17 | 3c23d3c9 | skills / tools | rm-trade-routes skill, xmb_idcheck, mapcheck unknown-route check; 9 editor tests on water order |
| 2026-09-18 | 27039313 / cdb121da | zplondon | Paris frame (UpgradeAll inherited); guards = euNuggetCapturable2 (101); the water privateer guard was dropped because rmRiverCreate rivers float no collideable hull |
| 2026-09-21 | ed80e037 / 096ded9b | zplondon | gates before the road; a park on the route fails silently |
| 2026-09-22 | b8274dc1 | zplondon | docked ferries addressed by literal census indices |
| 2026-09-23 | e2fb4795 / 12166f70 | zplondon | monopoly forbidden; the eyot in the river reverted (it stopped the bridge) |
| 2026-09-24 | 5c3e7233 -> 9e3d7c45, e097de05 | game/ai | TP socket filter = heavy violation, reverted; gate test added |
| 2026-09-24 | 67f294f1 | zplondon | Set Level 1 on routes 1 + 2 WITHOUT Versailles' zpDisableTradeRouteUpgrade: the Stagecoach button stays |
| 2026-09-24 23:00 | fa44aea2 | zplondon, zpistanbulb, techtreemods, protomods, tests | 'Trade routes: no post upgrades anything; London's St Paul's / Minster route techs; Istanbul's naval routes at level 1'. zpDisableAllTradeRouteUpgrades (the lock, London + Istanbul), zpLondonDeptfordStation / zpLondonEastIndiaCompany with per-player Set Level 2 triggers, London on euroTradeRouteCapture, Istanbul Set Level 1 on both routes; new `scripts/mapcheck/tests/test_trade_route_plan.py`; `test_london_revolt.py` TestTradeRouteLevels now asserts four 'Trade Route Set Level' effects (line 162 at `e4f89c3c`) |
| 2026-09-24 23:23 | 750af968 | zplondon, techtreemods | review fixes: a lock also kills the per-resource crates, so London grants DETradeRouteAllResourcesShadow; the lock covers the six zp upgrade techs; the route techs UNOBTAINABLE in data (St Paul's also stands on Versailles); the lock for players 1..N only |
| 2026-09-24 23:29 / 23:37 | c72fa3b8 / e4f89c3c | protomods / techtreemods, zplondon | route-tech buttons to page 11 column 0; London's trade plan moved into the shared setup tech zpLondonSetup |

### 10.2 Pitfalls

1. **Set Level is not a tech** (2026-09-24). A route raised by trigger keeps its posts' upgrade button and most likely keeps the resource toggles locked. Pair it with a lock (8a A2) or test Apply Tech (8a A1).
2. **A frame copies its map type** (2026-09-18). London inherited `euroTradeRouteUpgradeAll` from Paris. Choose the trade map type deliberately for every new map (3.7).
3. **Mod capture posts are not vanilla capture posts.** They list 22 normal upgrades, so they upgrade whenever the map type unlocks their kind's family (4.1), unless the map activates a lock such as `zpDisableAllTradeRouteUpgrades` (London, Istanbul; it does not cover NavalLone / NavalOriental).
4. **One line per route record** (2026-09-10). Multi-line records compile a bad name and fall back silently. The repo compiler hides the bug; run `scripts/tools/xmb_idcheck.py`.
5. **Whole-file replacement** (2026-07-25). `traderoutes.xml` and `traderoutedefs.xml` replace vanilla. A stale copy silently loses vanilla records after a game update; compare against a fresh decompile (the `vanilla-merge` skill).
6. **Decals on water routes are wrong** (2026-07-27). A decal paints a dirt strip across open water. Automated "restore vanilla" passes must skip them.
7. **Unknown def names fall back silently.** mapcheck S4 FAILs on unknown route names (`scripts/mapcheck/universal.py` 244-254).
8. **Triggers take unit indices, not engine ids** (2026-09-22). Route-linked units have 0x40000 engine ids; use census indices (5.6).
9. **Every built route consumes one unit index for its trade unit** (2025-03-16, 2026-09-18). Id shifts in trigger code must count it.
10. **Nothing may be placed on a built route; gates go before the road** (2026-09-21). An area under an island stopped London Bridge (2026-09-23).
11. **`zpOrientalFerry` is shared with Istanbul.** Proto changes must be map-local (8c).
12. **Grouping-baked `zpSPCPortSocket` harbours are for single-route maps** (RM guide 6952-6957). London has two routes (O6).
13. **The AI is out of scope without approval** (2026-09-24 revert). Report AI consequences; never change what the AI contests (AGENTS.md rule 7).
14. **Some vanilla evidence is only indirect.** Encrypted vanilla maps can be read only through RM dumps. Claims from dumps prove "this string is in the script", not placement; census the generated scenario for ground truth.
15. **A lock on the upgrade techs also locks the per-resource crates** (2026-09-24, `750af968`). The Food/Wood/Coin toggles need a level-1 upgrade tech Active. A map that removes every upgrade must grant `DETradeRouteAllResourcesShadow` (the `deTradeCrateAll` toggle) or accept XP-only posts (8a).

### 10.3 OPEN index

Each question with its cheapest test. "Current London" means the build of `e4f89c3c` (lock + route techs). "`cae26f9b` copy" means a Steam-root test copy of `zplondon.xs` at `cae26f9b` with its two setup-tech grants removed (9.7). Tests are for the owner to run; agents never start the game.

| # | question | cheapest test | section |
|---|---|---|---|
| O1 | Is TradeRoute numbered by creation order or by build order? | Steam-root test copy: create A, create B, build B before A, Set Level TradeRoute 1 = 2; see which route changes units | 5.4 |
| O2 | After London's Set Levels, is the lane's unit a Trade Galleon (1-based numbering, both effects hit) or a Trading Ship? | current London: look at the lane at the start | 5.4, 9.7 T1 |
| O3 | Does 'Trade Route Apply Tech' mark the tech researched on the route's posts (button gone, crates unlocked, L2 offered), also for posts built after the trigger ran? | `cae26f9b` copy: route-2 Set Level -> Apply Tech EuropeAll1; build a TP. Vanilla euDeluge shows only the crate half, because it also locks the buttons (5.2) | 5.2, 8a |
| O4 | Does Apply Tech with an *All tech also raise the other route? | the O3 game: watch the lane | 5.2 |
| O5 | Does London's land TP offer XP + deTradeCrateAll (+ Influence for African civs) and no Food/Wood/Coin or Export? (Under the `fa44aea2` script alone it would have been XP only.) | current London: read the land TP's toggles | 2.7, 9.2 |
| O6 | Which London socket carried the TP that showed the Stagecoach (route socket 731, Toll Station zpSPCPortSocket, trade-block SocketTradeRoute)? Do TPs on unlinked sockets earn? Why did routeSocket 731 create no unit in both saved generations? Candidate for a socket that refuses a TP: the 65 m enemy-first-TC placement rule (4.6) | current London: build a TP on each; since `fa44aea2` no post shows an upgrade, so compare placement, whether the trade units deliver and which toggles appear; re-census a fresh generation | 4.5, 4.6, 9.1 |
| O7 | Does a captured London ferry offer WaterAll1, and does researching it raise the road? | moot for current London (the lock removes WaterAll1); `cae26f9b` copy: capture one ferry, read and research | 9.4 |
| O8 | Does the engine hide a listed tech whose TP-kind flag does not match the route (e.g. Europe1 on a nautical capture post)? | Venice City or Elbe: capture a post in Colonial, look for a Stagecoach button. Not London or Istanbul since `fa44aea2`: the lock removes the rows there | 3.1 |
| O9 | Do capture crates (deCrateof*African1) appear on NAUTICAL capture posts under the land-flagged deTradeRouteCaptureableEuropean, or is ypTradeRouteCaptureable needed? | ask the owner whether captured Istanbul / Venice / Elbe harbours show Food/Wood/Coin; else capture one in a skirmish | 3.4, 8c |
| O10 | Do unrestricted normal crates (e.g. deCrateof*Water, deTradeCrateAll) also appear on a capture post once their tech is active? | current London: a captured ferry, look for deTradeCrateAll (granted since `750af968`); or a `cae26f9b` copy after WaterAll1 | 2.7, 9.2 |
| O11 | Is a map-forced tech with an unmet prereq (the capture techs need Colonialize) active from the start or only in Age 2? | Versailles: capture a post in Age 1, look for crate buttons | 3.4 |
| O12 | What does XPRate 0.5 BasePercent on the capture techs do, and does it hit normal TPs of the same player? | compare a normal TP's delivery on euroLandTradeRoute vs euroTradeRouteCapture (e.g. Paris vs Versailles setup), or the XP counter over 60 s | 3.4, 9.5 |
| O13 | What do the Data2 landtech / watertech / rivertech links do (mark siblings Active for one player or all; unlock the sibling's crates)? | `cae26f9b` copy: buy EuropeAll1 at the land TP, then see whether a captured ferry still offers WaterAll1 and shows water crates; or vanilla euBaltic (land + naval under UpgradeAll, LIKELY). Paris and performance_test have one route only | 3.2 |
| O14 | A per-instance tech researched on a capture post without CreateUniqueInstance: does it apply to that post only or to every post of that proto the player owns? | needs a capture post that offers an upgrade (none on current London or Istanbul): `cae26f9b` copy, capture two ferries, research WaterAll1 on one, compare both | 4.2 |
| O15 | Does a per-player CommandRemove on zpOrientalFerry (zpDisableAllTradeRouteUpgrades, applied to players 1..N at start since `750af968`, not to gaia) hold on a post captured from gaia? Does gaia need the lock? Does `<tech mergeMode="remove">` work in a per-map .mods.xml? | current London or Istanbul: capture a ferry, look for any upgrade button (none expected); the per-map removal has no precedent | 4.4, 8c |
| O16 | Does UpgradeAllTradeRoutes also raise a route whose posts are all gaia-owned? | moot for London since `fa44aea2`; `cae26f9b` copy: buy EuropeAll1 before any ferry is captured, watch the lane | 3.2 |
| O17 | What were the three buttons on the captured ferry ('98' with a check, ship, crossed arrows; screenshot from the pre-`fa44aea2` build)? | current London: capture a ferry and hover its buttons (the ship icon should be gone) | 9.2 |
| O18 | Does a def without an upgrade pair (armored_train, lava_flow, eu_stone_trail, temp) keep its units at level 1 or 2? | zpwildwest already sets its armored_train to Level 1: census the route units | 2.5 |
| O19 | Is proto lookup in `<units>` case-insensitive (zpArmoredTrainCoalcarMove vs CoalCar)? | zpwildwest census: does a coal car follow the armored engine? | 2.9 |
| O20 | Does an unknown def name fall back to the first record (dirt / Travois) or elsewhere? | unitbench map: build a route named 'bogus', census | 2.1 |
| O21 | What formula sets the delivered amount (crate 85 x traderoutelengthscale 360)? What do `<transport/>` and `<buildresourceaward/>` do? | one long and one short route: read the counter per trade-unit pass | 2.5, 2.7 |
| O22 | Is deUmiak (level 0 of arctic_water_trail) invisible because its animfile is missing? | editor: editorSetAllTradeRoutesToDef("arctic_water_trail") and look | 2.6 |
| O23 | Does rmSetMapType match 'eurotradeRouteCapture' case-insensitively (Black Sea 108, Istanbul 741)? | Black Sea: tech-tree or trigger-echo check of DEEnableTradeRouteEuropean / deTradeRouteCaptureableEuropean for player 1 | 7.7 |
| O24 | Aztec City: does re-activating DEEnableTradeRouteNativeAmerican after zpAztecCityGeneralSetup make America1/2 obtainable again? | build a TP on the Aztec road | 7.4 |
| O25 | Elbe: do captured posts on the river_trail route show Europe1 (or nothing)? | capture one Elbe river harbour | 7.4 |
| O26 | Elbe socketID6 / nuggetID6 are linked to route 2, then route 1: which link wins? | census the Elbe lone harbours' route, or capture and read the offered family | 7.7 |
| O27 | Which capture lock governs: the setup-tech Autoconvert ActionEnable 0 or the trigger suspend/release? Do captured posts ever flip back? | Elbe: clear a Hansa settlement's guards and watch | 4.3 |
| O28 | afTransSahara: are the SocketTradeRoute defs placed next to the capture posts in every lobby size (a vanilla mixing precedent)? | generate a 2p game, save, census | 7.3 |
| O29 | Which vanilla eu*/af*/bp* maps use which route calls, beyond their string constants? | not testable offline (encrypted); census generated scenarios if needed | 7.5 |
| O30 | AI: does kbTradeRouteGetTradingPostID(0, 0) return a gaia ferry at setup on London (lane booked as capturable)? | one AI log with debugSetup: look for 'Route: 0 is an Asian capturable Trading Route' | 6.1 |
| O31 | AI: does aiSetTradingPostUnitType with ypTradeCrateof* work on a captured zpOrientalFerry on water_trail? | one echo of its bool return (owner approval, rule 7) | 6.3 |
| O32 | AI: does tradingPostMonitor create TP build plans on the ferries (Socket unittype)? | echo-only AIDIAG line with the proto of bestTradeSocketID on London (owner approval, rule 7) | 6.3 |
| O33 | AI: does kbTradeRouteGetUnit(i, 0) return a unit at setup, or -1 (which would book a pure water route as land)? | one AI echo at setup | 6.3 |
| O34 | Does rmSetObjectDefTradeRouteID dock a unit onto the route or only link it? (Istanbul comment 'it docks itself onto the lane' vs memory rule 9 'does NOT snap', ferry 14 m off the lane) | census a linked object placed with max 0 vs max 0.5 | 5.1 |
| O35 | Build order: memory rm-water-placement-rules rule 1 (2026-09-17: nautical route after islands) vs London (lane first, before the river, owner-enforced 2026-09-18): which is the current rule? | owner decision; one editor generation of a lane-first copy with islands | 5.7 |
| O36 | Were London's lane stopper and controllers (indices 1-3) removed by rmRiverBuild? | move one controller after the river in a test copy, re-census | 5.7, 9.1 |
| O37 | Is DETrickleEconomicsShadow (an OR-prereq of DETradeRouteUpgrade2Enable) activated anywhere outside the XML (engine, encrypted script)? | not decidable offline; watch for an early level-2 button without Industrialize | 3.2 |
| O38 | Units and behaviour of the never-used rmAddTradeRouteWaypointVector, rmAddRandomTradeRouteWaypointsVector, rmCreateTradeRouteWaypointsInArea | one editor generation per call | 5.1 |
| O39 | Do captured posts count toward a Trade Monopoly on maps without rmForbidTradeMonopoly (Elbe, Black Sea, Iceland, Caribbean Wars, Grinch, Winter Wonderland)? | relevant only if London ever drops its forbid | 7.6 |
| O40 | Can a player research the dormant TradeRouteUpgradeCapturable1/2 at a capture post although no proto lists them (the YPCapturableTradeRouteUpgradeTech flag)? | silkRoad (nautical 'water' route, Capturable1 OBTAINABLE there): capture a post in Colonial, look for a 'Trade Cart' button | 3.3, 8c T3 |
| O41 | Do London's route techs work: Deptford Station raises the road to trains, the East India Company raises the lane to level 2, and each disappears for the other players? | current London: reach Industrial, research each at St Paul's / the Minster, watch the route units and the other players' buttons | 9.1, 9.7 T5 |

### 10.4 How conflicting research findings were resolved

- **`eu_stone_trail` exists** in both the vanilla and the mod `traderoutedefs.xml` (V-defs 446; `data/traderoutedefs.xml` 21, which the writer re-checked on 2026-09-24). One lens reported it absent. So the 2024 Versailles switch to `dirt` was not a missing-name fix, and `zp_z_verseilles2.xs` builds a real def.
- **RM trade calls: 13.** There are 10 route calls plus `rmSetMapType`, `rmIsMapType` and `rmForbidTradeMonopoly`. One lens counted 12 and included `rmSetNuggetDifficulty`, which is used to guard capture posts but is not a trade call.
- **The compiled `trTradeRouteSetLevel(1, 1)`** the research saw in `trigtemp.xs` (line 417 of that generation) came from a Versailles generation, not a London or Florence one. Florence sets no route level. London trigtemps now exist (5.5).
- **London's crossing socket.** The script places it (731), but both saved censuses lack it. Both facts stand, and the gap is O6.
- **The owner of trade units** is gaia. One lens listed this as open; the census proves it (2.6).
- **`zpOrientalFerry` tech rows** sit at M-proto 72269-72290 (WaterAll1 at 72289, WaterAll2 at 72290), as four lenses reported. One lens quoted 72267-72289.
