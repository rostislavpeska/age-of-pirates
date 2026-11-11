# Volcano lava trails: how they work and why they are invisible

Reverse-engineered 2026-11-11 from the repo, the compiled trigger scripts and two of the owner's files: the match save
`Savegame\Lava Bug.age3Ysav` (Polynesia, 4 players) and the editor test scenario `Scenario\~testing.age3Yscn` with its
`Trigger\trigtemp.xs` (`zp_z_hawaii3`, generated 2026-11-11 08:27). Evidence levels follow `docs/trade_routes_guide.md`:
**[PROVEN]** = read from data, a census or the compiled `trigtemp.xs`; **[LIKELY]** = derived, not observed in game;
**[OPEN]** = not known.

## 0. Summary

- **Root cause [PROVEN on Polynesia].** Every lava stage waits for "at least 20 wagons of type N within 12 m of the
  volcano" (20 m on Hawaii and Iceland), measured around a unit index written into the map as a literal (`volcanoID`). On Polynesia 4p that literal is
  `"273"`. In the generated map, 273 is no volcano unit: it is car 18 of lava train 4, and those train units are destroyed
  at the end of every eruption. The save has no unit 273 at all. The condition can never become true, gaia's art culture
  never advances, and the lava wagons keep drawing their invisible branch.
- **Why it once worked [LIKELY].** When the literals were written, they pointed into the crater grouping's block of ten
  `zpTrainStopper` units at the volcano centre. Ten units side by side tolerate a drift of up to 9 indices. The v7.2 pirate
  village re-exports (`0f8639db`, 2026-09-11, then `1894913f`, 2026-09-25) added 17 units to `pirate_village05` and
  `pirate_village06`, which every lava map places before its crater. That pushed the crater past the literal.
- **Same bug on Hawaii [PROVEN].** In the owner's `zp_z_hawaii3` generation of 2026-11-11, the literal `"181"` is a
  `zpLavaSpawnerTradeWagon4`, car 16 of lava train 4. The crater starts at 191 and the avoider is 235. Melanesia volcano
  A (`"361"`) has the same bug [LIKELY, by index count].
- **Iceland is built differently.** It takes its reference at generation (`rmGetUnitPlaced` of a controller unit at the
  crater centre). Every unit near that index is a fixed crater unit that survives eruptions, so it should work
  [LIKELY]. It has not been observed in game. Unknown builds lava routes with no trigger chain at all.
- **The eruption's area damage is dead too [PROVEN].** `Volcano_Damage` compiles to `trUnitSelect("273")` (Polynesia)
  and `trUnitSelect("181")` (Hawaii). The quoted form means the compiler could not resolve the unit, so the selection is
  empty and nothing is damaged (skill `nugget-targeting`, Rule 0).
- **Fix (applied 2026-11-11 to Polynesia, Hawaii and Melanesia; Polynesia confirmed in game by the owner the same day;
  Hawaii and Melanesia not yet seen in game).** Take the reference at generation from the "ai avoider" unit each map already places at
  the crater centre: `string volcanoID = ""+rmGetUnitPlaced(volcanoAvoider, 0);` (section 7). One editor generation
  proves it: in `trigtemp.xs`, `Volcano_Damage` must read `trUnitSelectByID(n)`.

## 1. The parts

| Part | Where | Role |
|---|---|---|
| 4 lava routes | `game/randmaps/zppolynesia.xs` 744-770 | `rmCreateTradeRoute` + `rmBuildTradeRoute(id, "lava_flow")`, each from the map centre (0.5, 0.5) 15 tiles out: east, north, west, south |
| Route type `lava_flow` | `data/traderoutedefs.xml` 32 | `river="true"`, `blocksize="8.0"`, black minimap colour; its "train" is 26 units: `zpLavaSpawnerTrade` + 5 x `zpLavaSpawnerTradeWagon` + 5 x `Wagon2` + 5 x `Wagon3` + 5 x `Wagon4` + 5 x `Wagon5`, 1 m apart |
| Train protos | `data/protomods.xml` 27714 (engine), 27758 / 27802 / 27846 / 27890 / 27934 (Wagon..Wagon5) | speed 0.3, invulnerable, non-collideable, no HP bar, no minimap icon; differ only in their animfile |
| Train animfiles | `art/terrain/lavabig.xml` (engine), `lava.xml`, `lava2.xml` ... `lava5.xml` | the engine always shows a fire; each wagon's `ball` component has `<logic type="Culture">` (section 2) |
| Cold lava | `zpLavaDeath` (`protomods.xml` 28248), `art/terrain/lavacold.xml` | cold-lava decal, `lifespan` 4 s, `FadeOutDecalOnDeath` |
| Crater | grouping `Volcano_Crater_NoGround.xml`, placed at `zppolynesia.xs` 1173-1175 | 45 units: offsets 0-9 `zpTrainStopper` at the centre, then obstructions, fire spawners, `zpVolcanoSpawner` (30), `zpVolcanoInvisibleTarget` (32), `zpVolcanoBurn` (35) ... |
| AI avoider | `zppolynesia.xs` 1177-1186 | one `zpVolcanoAvoiderS/M/L/XL` at (0.5, 0.5), placed right after the crater |
| Triggers | `zppolynesia.xs` 1677-2545 | eruption timers, phases, lava toggles, culture stages (section 3) |
| Techs | `data/techtreemods.xml` 14893-15204 | `zpVolcanoActive`, `zpVolcanoPassive`, `zpVolcanoRange*`, `zpVolcanoLavaBack` (section 3) |
| Trigger effects | `data/trigger/triggerdata.xml` 1618-1622, 1638-1642 | "Trade Route Toggle State" = `trTradeRouteToggleState(route, show)`; "Player : Override Culture for Art" = `trPlayerOverrideArtCulture(player, culture)` |

## 2. How a lava trail is drawn

A lava trail is a trade-route "train" owned by gaia, crawling out of the crater along a short route. What it looks like
depends on gaia's **art culture**, which the triggers switch with "Player : Override Culture for Art" (player 0). One
override changes the art of every gaia unit at once, on all four routes.

Each wagon's animfile draws either the bare `terrain\lava\lavawalker` model (no lava decal: the owner sees nothing) or
six variations of `lavawalker` + the glowing `lavadecal_basecolor` decal (1.5 x 1.5 m) + the `rock` / `rock2` fire
attachments [PROVEN, animfiles read]:

| Gaia art culture | Wagon | Wagon2 | Wagon3 | Wagon4 | Wagon5 |
|---|---|---|---|---|---|
| none (game start) / WesternEurope | - | - | - | - | - |
| Chinese | lava | - | - | - | - |
| Japanese | lava | lava | - | - | - |
| Indian | lava | lava | lava | - | - |
| Mediterranean | lava | lava | lava | lava | - |
| EasternEurope | lava | lava | lava | lava | lava |

So "lava visible" is never a matter of the units existing: the trains exist from generation on [PROVEN: the save holds
4 x 26 train units]. Visibility is only gaia's culture. Stepping the culture lights the train up group by group, front
first, so the flow seems to grow out of the crater.

The train runs as a conveyor: a car reaching the route end continues from the start. In the save, train 1's engine is
12.7 m out while its Wagon4/5 cars are 30-36 m out [PROVEN: census positions].

Side effect [LIKELY]: every other gaia unit whose animfile has culture logic also changes its look during an eruption.

## 3. One eruption, step by step (Polynesia)

Trigger names are the map's. "Fire" = the effect "Fire Event", which activates the named trigger; its conditions are then
checked. Times are from the trigger's own activation.

1. **Countdown** (`Volcano_Counter_Hard/Easy/Moderate`, 1861-1919, active at start): by difficulty, a visible counter
   "Volcano erupts in" of 720 s (hard), 960 s (moderate) or 1200 s (easy). At 0 it fires `Volcano_StartInitial`.
2. **Eruption start** (`Volcano_StartInitial` 1921-1958, later `Volcano_Start1..5` 1960-2183):
   - tech `zpVolcanoActive` for gaia: spawns the firing `zpSPCVolcano` from `zpVolcanoSpawner` and lights the crater
     fires;
   - lighting `carribean`, camera shake, earthquake sound, chat "The Volcano is waking up!";
   - counter "Volcano eruption" = `eruptionLenght` (80 s at 1-2 players, 100 s at 3-4, 120 s at 5-6, 140 s at 7-8). At 0
     it fires `Volcano_Stop`;
   - quest var `Eruption` = 0;
   - fires the next `Volcano_StartN`, which waits for `Eruption == 1` and its own random break (700-1200 s, rolled at
     generation). `Start5` fires `Start1` again, so eruptions repeat forever;
   - fires `Volcano_Music1`, `Volcano_Short` and `Volcano_Lava`.
3. **Lava on** (`Volcano_Lava` 2187-2206): "Trade Route Toggle State" routes 2, 3, 4, 5 = show. Routes count from 1
   in creation order: route 1 is the water lane (244), 2-5 are the lava routes [PROVEN rule, `trade_routes_guide.md` 5.4].
   Then it fires `Volcano_Lava_Delay1`.
4. **Culture stages** (`Volcano_Lava_Delay1..5` 2233-2324, checked every 5 s): DelayN waits for
   `trCountUnitsInArea(volcanoID, 0, "zpLavaSpawnerTradeWagonN", 12) >= 20`, i.e. all 20 type-N wagons (5 per route x 4)
   within 12 m of the volcano reference. It then sets gaia's culture one step further (Chinese, Japanese, Indian,
   Mediterranean, EasternEurope) and fires Delay N+1. **This is the step that breaks** (section 4).
5. **Bombardment** (`Volcano_Short` 2340, `Medium`, `Long`, `UltraLong`, `XXLong`, every 20 s, as many as the player
   count allows): techs `zpVolcanoRangeShort/Medium/Long/UltraLong/XXLong` switch which `CannonAttack*` range the
   `zpSPCVolcano` uses. Each phase shakes the camera and fires `Volcano_Damage`.
6. **Area damage** (`Volcano_Damage` 1839-1857): for every player, "Damage Units in Area" around `volcanoID`: units
   `eqAreaDamage` (25-57), buildings 20 x that, within `islandSize` (90-170 m). It uses the same reference as step 4.
7. **Lava cools** (`Volcano_Short2` 2469-2486, then `Volcano_Lava_Transform` 2327-2336, 15 s later): tech
   `zpVolcanoLavaBack` transforms the engine and every wagon of all four trains into `zpLavaDeath`. That is a cold-lava
   decal living 4 s, so **the trains die at the end of every eruption**. LavaBack lands 5 s before the eruption counter
   ends: at 75 / 95 / 115 / 135 s.
8. **Eruption end** (`Volcano_Stop` 2490-2517): tech `zpVolcanoPassive` (volcano back to passive, fires back to
   spawners), lighting `age304_caribbean`, `Eruption` = 1, music fades, fires `Volcano_Lava_Death`.
9. **Lava off** (`Volcano_Lava_Death` 2208-2231, armed from the start, waits for `Eruption == 1`): routes 2-5 = hide,
   gaia's culture = WesternEurope (the invisible branch). The next eruption's step 3 shows the routes again, with **new**
   train units under new ids [PROVEN: generation ids 177-280 are gone in the save; the live trains are 2549-2652].
10. **Trade-route upgrade guard** (`I Update Sockets` / `II Update Sockets` 2521-2545): when gaia first owns a
    `deTradingGalleon` or a `deTradingFluyt` (the water lane upgraded), fire `Volcano_Lava_Death`. Purpose [OPEN]: most
    likely the lane upgrade re-shows the lava routes, and this hides them again.

## 4. Why the lava is invisible

### 4.1 The reference unit does not exist [PROVEN]

`zppolynesia.xs` 1695-1731 sets `volcanoID` per player count: `"270"` (1 player) to `"277"` (8 players). The compiled
script of the owner's game (`Trigger\trigtemp.xs`, 4 players) has

```
bool bVar1 = (trCountUnitsInArea("273",0,"zpLavaSpawnerTradeWagon",12) >= 20);   // Delay1 .. Delay5
trUnitSelect("273"); trDamageUnitsInArea(1,"Unit",130,40);                        // Volcano_Damage
```

A quoted id in `trigtemp.xs` is the census index (skill `rm-census`). The census of `Lava Bug.age3Ysav`:

| Census index | Units |
|---|---|
| 0 | the water lane's trade unit |
| 1-8 | player starts and the four village controllers |
| 9-176 | two pirate villages, two Wokou villages, their flags and harbour platforms |
| **177-280** | **no record**: the four lava trains as generated (4 x 26), destroyed since |
| 281-324 | the crater: 281-290 `zpTrainStopper`, 311 `zpVolcanoSpawner`, 313 `zpVolcanoInvisibleTarget` at (374.2, 373.2) ... |
| 325 | `zpVolcanoAvoiderM` at (375.0, 375.0) |
| 2548 | `zpSPCVolcano` (spawned by `zpVolcanoActive`) |
| 2549-2652 | the live lava trains: 4 x (`zpLavaSpawnerTrade` + 25 wagons), all owned by gaia |

So `"273"` counts around a unit that is gone. `Delay1` never fires, gaia stays on none/WesternEurope, and every wagon
draws its invisible branch. At generation, 273 was car 18 of train 4 (a `zpLavaSpawnerTradeWagon4`), a moving unit that
dies at the first `zpVolcanoLavaBack`. The reference was therefore wrong from the first second of the game.

The compiler gives a second sign. A valid unit index in an effect compiles to `trUnitSelectByID(<engine id>)`. Here
`Volcano_Damage` compiled to the quoted `trUnitSelect("273")`, i.e. "no such unit, select by name". That selects nothing.
A train car is not resolved even while it exists: Hawaii's `"181"` was a live train car in the generated scenario and
still compiled to `trUnitSelect("181")` [PROVEN, section 5].

### 4.2 Hawaii, from the owner's editor test [PROVEN]

`zp_z_hawaii3`, generated 2026-11-11 08:27. Census of `Scenario\~testing.age3Yscn` and the compiled `trigtemp.xs`:

| Index | Unit at generation |
|---|---|
| 87-190 | the four lava trains (engines 87, 113, 139, 165) |
| 179-180 | `zpLavaSpawnerTradeWagon3` (train 4) |
| **181** | **`zpLavaSpawnerTradeWagon4`, train 4 car 16**: the map's `volcanoID` |
| 191-234 | the crater: 191-200 `zpTrainStopper`, then obstructions, fire spawners, `zpVolcanoSpawner`, `zpVolcanoInvisibleTarget` |
| 235 | `zpVolcanoAvoiderM` |

`trigtemp.xs`: `trCountUnitsInArea("181",0,"zpLavaSpawnerTradeWagon",20) >= 20` (Delay1-5, radius 20 m here) and
`trUnitSelect("181")` (Volcano_Damage). The index count from the repo had predicted exactly this: 10 before the crater,
train 4 car 16.

### 4.3 How the literal drifted [LIKELY: index arithmetic, crater start confirmed by both censuses]

The literal was written in the map's first commit (`1edbe162`, 2024-08-15) and never changed. The placement order before
the crater has stayed the same since. Only the village groupings grew:

| Commit | Date | `pirate_village05` / `06` | 4p crater starts at | Index 273 |
|---|---|---|---|---|
| `1edbe162` Polynesia added | 2024-08-15 | 29 / 26 | 264 | crater offset 9: the 10th `zpTrainStopper`, at the centre |
| `14749e8d` pirate settlements | 2026-08-03 | 33 / 26 | 268 | offset 5, still a stopper |
| `0f8639db` harbour + Tortuga props, v7.2 prep | 2026-09-11 | 44 / 33 | 286 | a lava train car: **broken** |
| `1894913f` five villages re-exported | 2026-09-25 | 41 / 31 | 281 | a lava train car: broken (the save) |

The ten stoppers at the centre made the system tolerate up to 9 extra units placed earlier in the script. Any edit to a
grouping placed before the crater moves the index again. A literal unit index here is a time bomb.

## 5. The other lava maps

| Map | Reference | Status |
|---|---|---|
| Polynesia (`zppolynesia.xs`) | literals `"270"`-`"277"` (1695-1731) | **broken** since `0f8639db` [PROVEN, save] |
| Hawaii (`zphawaii.xs`, twin `zp_z_hawaii3.xs` in the game root) | literal `"181"` (1597), all player counts | **broken** since `0f8639db` [PROVEN, section 4.2; owner saw it in game 2026-11-11]. Was stopper offset 7, now 10 before the crater |
| Melanesia (`zpmelanesia.xs`) | `"361"` volcano A, `"408"` volcano B (2220-2221); Delay1/3/5 use A, Delay2/4 use B | **broken** [LIKELY]: 361 was a fire spawner at A's centre (offset 10), now 7 before crater A = a train car; 408 still lands on crater B's stoppers (offset 3). Delay1 needs A, so the chain stops at once and both volcanoes stay dark. The root twin `zp_z_melanesia.xs` is from 2025-06-18 and differs from the repo |
| Iceland (`randmaps/zpIceland.xs`, root copy `0zpIceland.xs` differs) | computed: `""+(rmGetUnitPlaced(volcanoControllerID, 0))` (1434-1436, 1907), radius 20 m | **should work** [LIKELY], not observed in game. See below |
| Unknown (`zpunknown.xs` 4954-4981) | builds four `lava_flow` routes, has no eruption or culture triggers | its lava never shows [LIKELY]; separate question whether that is intended |

**Iceland in detail.** Its four lava routes start at `volcPlaceX/Y` (0.42, or 0.45 with more than two teams). Two helper
units on the first tenth of routes 1 and 2 give `volcLocX/Y`, which is the same point. The crater and the controller
(`zpSPCWaterSpawnPoint`) are placed there, and the avoider right after them. Route indices 2-5 are right: route 1 is the
land trade route (333-358).

`rmGetUnitPlaced` returns the engine id, and the triggers want the index. The two are equal unless a unit was docked
on a trade route earlier (London 2026-09-22, skill `nugget-targeting` Rule 0). Iceland docks one Hansa socket at 370-377,
and its own Hansa triggers use a +1 shift. So the reference may land one unit early: on the crater's last unit, a
`zpGrassFire` about 4 m from the centre. In the Polynesia save, that same grass fire survived the eruptions. Either way
the condition counts around a fixed unit at the crater, within 20 m. The controller unit itself also survives in a match:
the Polynesia save holds 27 `zpSPCWaterSpawnPoint` despite their `OnlyInEditor` flag [PROVEN].

Check, if the lava is still invisible on Iceland: one generation, then `trigtemp.xs`. `Volcano_Damage` must read
`trUnitSelectByID(n)`. A quoted id would point to a different cause.

## 6. Side findings

- `Volcano_Stop` fires `rmTriggerID("Volcano_Start")`, a trigger that does not exist. It compiles to `trEventFire(-1)`
  [PROVEN] and does nothing. The Start1..5 chain is armed elsewhere, so nothing is lost.
- The wagon animfiles attach `rock3`, which none of them defines (only `rock`, `rock2`) [PROVEN]. In-game effect [OPEN].
- The crater grouping has 45 units in the repo, but the save shows 44 at the crater: `zpVolcanoBurn` (offset 35) has no
  record [OPEN: not placed, or not readable by the census].
- If an eruption ends before stage 5, the waiting `DelayN` stays armed into the next eruption, and the culture can then
  jump [LIKELY, harmless once the reference is right].
- Melanesia 1179 docks `stopperID` on route 2 again where `stopperID2` was meant [PROVEN, code]. `stopperID2` is only used
  for its position, so this is harmless.
- The radius differs per map: 12 m on Polynesia, 20 m on Hawaii and Iceland [PROVEN, compiled scripts].

## 7. Fix (applied 2026-11-11; Polynesia confirmed in game, Hawaii and Melanesia not yet seen)

Changelog: `docs/changelog_v7.4.md`, Bugfixes.

Take the reference at generation from a unit the maps already place at the crater centre, the "ai avoider":

| Map | Change |
|---|---|
| Polynesia | 1695-1731: `string volcanoID = ""+rmGetUnitPlaced(volcanoAvoider, 0);` instead of the per-player literals |
| Hawaii | 1597: the same line |
| Melanesia | 2220-2221: `volcanoID` from `volcanoAvoider` (1525-1535), `volcanoID2` from `volcanoAvoider2` (1543-) |

- **Why this one.** It adds no unit, so no other index moves. It follows the maps' own working idiom: the pirate sockets
  already come from `rmGetUnitPlaced(piratewaterflagID1, 0) - 1`, and in this generation they compiled to the correct
  census ids `"124"` and `"170"` [PROVEN]. Iceland uses the same pattern for its volcano.
- **Engine id = index here.** `rmGetUnitPlaced` returns the engine id (`trade_routes_guide.md` 5.6). It equals the
  index unless a unit was docked on a trade route earlier:
  - Polynesia docks nothing (its lava stoppers 796-799 are commented out). In the save, the crater's ids equal the index
    count [PROVEN].
  - Hawaii docks its water sockets at 973, after the avoider (963).
  - Melanesia docks one `stopperID` on lava route 1 (817-819) before both avoiders. A shift of a few units would still
    land on crater units (the last ones are fire spawners, kept through the eruptions). The check below decides it.
- **Geometry [LIKELY fine].** The avoider sits about 4 m off the routes' origin (375, 375 vs 372, 372); the old stopper
  sat about 2.7 m off. With a 12 m radius, a 5-wagon group still has about a 15 s window while it passes the crater,
  checked every 5 s.
- **Verification.**
  1. One editor generation per map, then `Trigger\trigtemp.xs`. `Volcano_Damage` must read `trUnitSelectByID(n)`, not a
     quoted id, and the Delay conditions must quote the avoider's index (Polynesia 4p: 325, Hawaii 4p: 235).
  2. One eruption in game: the lava shows and grows, and the eruption damages units around the crater.
- Game-root twins, all registered in `scripts/tools/sync_local_maps.py` and equal to the repo since 2026-11-11:
  `zp_z_polynesia`, `zp_z_hawaii3`, `zp_z_melanesia`, `0zpIceland` (`0zpunknown` already was). The replaced copies were
  older repo states with no local edits; backups are in the session scratchpad. Not touched: `zp_z_hawaii`,
  `zp_z_hawaii2` (2024 relics), the `0zpunknown` rigged test copies, `bpIceland` (another map, binary).
- Checks run: `scripts/mapcheck/xs_scope_check.py` OK on all three maps; no test pins the old literals.
- The 7.3 production zip (built 2026-11-07, not uploaded) contains the bug.
