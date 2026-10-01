# Danube map (PLAN, not built)

Status: **plan only, 2026-10-01.** The owner asked for a plan, not the map. Nothing is implemented. Every name and
line number below was read from the repo on 2026-10-01; re-check them before building, because other agents edit
these files.

## The map in one paragraph

The Danube makes one big U-bend (the Danube Bend). The layout reference is the owner's minimap of 2026-10-01: the
river enters at the north-east edge, runs south-west past the centre, turns in a U and leaves at the east edge.
**The players sit around the bend**, on the outer shore that wraps the U. **The shore inside the bend is locked**:
the river closes it on three sides and the east map edge on the fourth. It is reachable only over the bridges, and it
holds the **Prince Elector castles (max 4, on cliffs)** and **rich resources**. The river itself is a water trade
route. The **north** outer shore belongs to the **Hussites**, the **south** outer shore to the **Orthodox
monasteries** (the Balkan variant from the Adriatic Sea map). Land, water, cliffs and forests look like King of
Bohemia. The southern half also gets a few dry-grass patches.

(Revised the same day: the first draft had one team per bank and the Electors in the middle. The owner moved the
players around the bend and the Electors onto the locked inner shore.)

## Layout

```
            N  (outer shore: team 1, Hussites)
        ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~  <- river, north arm (enters at the NE edge)
  outer |  INNER SHORE (locked)       |
  shore |  Electors on cliffs,        |  east
  apex  |  rich mines, herds, treasure|  map
 (west) |                             |  edge
        ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~  <- river, south arm (leaves at the E edge)
            S  (outer shore: team 2, Orthodox, dry patches)
```

- The outer shore is one landmass wrapping the U (north arm, west apex, south arm). The teams can reach each other
  by walking around the apex, or through the inner shore over the bridges.
- The inner shore must stay locked. Both river arms must run all the way to the east edge, and no land strip may
  bypass them along that edge. The playability grid (`mapcheck`) must show the inner shore connected **only** through
  bridge tiles.
- Fairness: the map is mirror-symmetric north to south (the U, the bridges, the sockets, the start positions). Only
  the natives differ (Hussites north, Orthodox south), as the owner specified.

## Players around the bend

- Ring placement around the map centre (`rm-players` skill). Circle fraction 0 is north and grows clockwise, so the
  outer arc (south, west, north) is fraction 0.5-1.0. Two teams: team 1 on the north part of the arc (about
  0.80-0.97), team 2 on the south part (about 0.53-0.70). The west apex (about 0.72-0.78) stays free as the land
  meeting point. FFA or uneven teams: spread evenly over 0.53-0.97.
- The ring radius must put every start on the outer shore, clear of the river. `mapcheck` SIM `RING_LOW_LAND` warns
  when the ring runs over water; tune the radius and the waypoints together.
- Place the fake-grouping lock (20 gaia `zpSPCWaterSpawnPoint`) right before the first Town Center (owner's rule,
  `rm-players`).

## The locked inner shore: Electors and rich resources

- **Prince Electors (max 4)**, all on the inner shore, each on its own cliff plateau (the Elbe recipe with
  `Italian Cliff Grassy`, see Natives). 2 at ≤4 players, 4 at 5+. Spread them so that each team's bridge has
  Electors at equal distance.
- **Rich resources** (proposal, numbers for the owner to set). Per 2 players: 3 gold mines + 2 silver mines,
  3 large herds, 2 hardwood forest patches, and 2-3 higher-tier treasures (a higher `rmSetNuggetDifficulty`
  band). The outer shores keep a normal amount (King of Bohemia densities). All of it goes through
  `rm-resource-balance` so both teams' bridges reach the same value.
- Optional high-value trade sockets on the inner banks of the river route (contested), in addition to the per-team
  sockets on the outer shores.
- No ford into the inner shore: a shallow crossing would unlock it.

## Reference maps and what each one supplies

| Need | Copy from | Where |
|---|---|---|
| Land, water, cliff, forest, light | King of Bohemia | `randmaps/zpkingofbohemia.xs` 51-83 (size, light, sea, base terrain, map types), 288 (river), 315 / 348 (continent mix), 633-720 (cliffs), 967 (forest) |
| River built around a water trade route | Riverina ("Downer River") | `game/randmaps/zpriverina.xs` 674-755: `rmRiverCreate` and a river trade route on the **same waypoints**, then bank areas that avoid the route, then sockets on the route |
| Bridges docked on the river | Florence | `randmaps/zpflorence.xs` 452-560: a stopper object on the trade route gives the river centre; the bridge grouping sits exactly there (min/max distance 0); both banks are flat shore areas with an `Italian Cliff River` edge |
| Bridge sites raised to the deck | Riverina | `game/randmaps/zpriverina.xs` 516-580: `mississippi_bridge_01` plus "bridge site" areas at the deck height on both ends |
| Hussites | King of Bohemia | groupings `Hussite_Camp_01`..`05` (also `HussiteCamp_Hidden_N/W`), placed at 505-525; triggers "Activate Hussites" (1731) and "ZP Pick Hussite Leader" (2895); merc `zpMercHussiteWagon` (1151) |
| Orthodox monasteries, Balkan variant | Adriatic Sea | `game/randmaps/zpvenice.xs`: subciv `zporthodox` (19), variant `Orthodox_Monastery0` + `rmRandInt(4, 6)` (636-638), plateau recipe (647-692), triggers "Activate Orthodox" (1798) and "ZP Pick Orthodox Captain" (2277) |
| Prince Electors on cliffs | Elbe | `randmaps/zpelbe.xs`: subciv `zpprinceelector` (45-48), controller + cliff plateau + grouping (715-777), triggers "Activate Electors", "Elector Increase/Decrease", "Elector on/off Player" (~1730-1780) |

Rule for all of them: copy the **whole proven block** of the one map that already has the system (trigger
families above all). Never mix a family from two maps (the Istanbul/Paris fort-trigger lesson), and keep each
system exactly as its source map runs it (the Istanbul verdict: hacks do not stack).

## Look (names verified in the mod data)

| What | Name | Source |
|---|---|---|
| Base land mix | `italy_grass_lush` | King of Bohemia continents |
| South dry patches | `italy_grass_dry`, `italy_grass_medium_dry`, `italy_grass_dirt` | same Italy mix family, so they blend with the base (all in `art/terrain/mix`) |
| River water | `ZP Bohemian River` | King of Bohemia river (`data/waterbodies*`); it builds on KoB, so it has the banks `rmRiverCreate` needs |
| Sea type | `ZP Venice Lagoon` | King of Bohemia |
| Cliffs (castles, monasteries) | `Italian Cliff Grassy` | King of Bohemia castle cliffs |
| River banks at the bridges | `Italian Cliff River` | Florence |
| Forest | `z69 North New England` | King of Bohemia |
| Lighting | `honshu_Skirmish` | King of Bohemia |
| Map size | 400 / 460 / 520 by player count | King of Bohemia 51-58 |

Dry patches: 4-8 small areas painted with the dry mixes, confined to the southern half by a box constraint. Build
them before the forests, and keep them away from the river banks and the monastery plateaus.

## The river: the water trade route is the skeleton

The route is the master shape and the water follows it. The route cannot be bent to follow the water: it snaps to a
16 m block grid (see the investigation below).

1. **One list of waypoints** is the only source of the path (the "one owner per coordinate" rule). The Danube Bend
   is 6-8 waypoints, chosen **on the route's 16 m grid, with every leg at 0, 45 or 90 degrees** (pending the probe
   below). Then the built route equals the authored polyline. The legs that carry bridges are axis-aligned.
2. **Route first**, with a `zpSPCWaterSpawnPoint` stopper at fraction 0.5. That's London law 1, "a route built
   after water poisons every later water placement", owner-enforced 2026-09-18, plus the guide's
   "stopper first" rule. `rmBuildTradeRoute(id, "river_trail")`: a river route (`river="true"`, so the trading
   posts show the river upgrades) that upgrades to `river2_trail` and `river3_trail`, as on Florence and the Elbe.
3. **Water from the route** (method A, recommended). Start the map as water (`rmTerrainInitialize("water")`, as
   the Elbe does), then build the north shore, the south shore and the inner shore as land areas in
   `italy_grass_lush` with `rmCreateTradeRouteDistanceConstraint(R)`. The river is then exactly the route's corridor,
   2R wide, whatever shape the route takes. `R` is set from the bridge span (see Bridges). This is the owner's
   "trade route as base, terrain around it", and it cannot drift from the route by construction.
   - Method B (Riverina): `rmRiverCreate` on the same waypoints plus banks that avoid the route. River bodies
     are most likely splines (`riverline` with `minSplineDistance` in the exe), while routes are block lattices. At
     every bend the river can leave the route, so boats sail over grass, or the route's sockets land in the water.
     Use B only if the probe shows the two coincide.
4. Trade sockets only at route positions: `rmGetTradeRouteWayPoint(route, fraction)` with
   `rmPlaceObjectDefAtPoint`, using King of Bohemia's socket block (`rm-trade-routes` skill). A free map coordinate
   on the route line spawns nothing (London, 2026-09-27). Pick naval capture sockets
   (`zpTradingPostCaptureNaval`, as on the Elbe) or `SocketTradeRoute`. Choose fractions on straight legs, and away
   from both ends: the built line can run past the map edge.

## Bridges ("few crossings", docked the Florence way)

- The bridges are the only gates into the locked inner shore. One on the north arm (team 1's gate) and one on the
  south arm (team 2's gate), mirrored so that each is the same distance from its team's starts. At 5+ players a
  third bridge crosses at the west apex; it is shared and contested. Each bridge goes on a straight river segment,
  away from the sockets and from each
  other (Elbe's `avoidBridge` on `zpBridgeFace`).
- **Groupings cannot be rotated** (the never-rotate-a-cliffgroup rule). Choose the bridge by the direction of the
  segment it crosses:

  | Grouping | Size (tiles) | Precedent |
  |---|---|---|
  | `Bridge_Universal_03` | 16 x 26 | Florence (crosses an east-west river) |
  | `Bridge_universal_long` | 40 x 14 | Elbe, Independence War |
  | `Bridge_Universal_E` / `_N` | 32 x 31 / 34 x 34 | not used on any map yet; map them with `grouping-terrain` first |
  | `mississippi_bridge_01/02` | - | Riverina, Mississippi |

- In this layout, the north and south arms run east-west, so their bridges are Florence's `Bridge_Universal_03`
  (26 tiles north-south, proven across an east-west river). The west apex runs north-south, so its bridge is most
  likely `Bridge_universal_long` (40 tiles east-west, by its footprint). Confirm its span direction with
  `grouping-terrain` before use. Keep each bridge site's river segment straight for the bridge's whole length.
- Docking: take the river centre at the bridge from the route (`rmGetTradeRouteWayPoint`, then a stopper object,
  then `rmGetUnitPosition`, as on Florence), and place the grouping exactly there with min/max distance 0.
- **Heights must meet the deck.** Read the deck height from the grouping XML (`grouping-terrain`) and set the bank
  or bridge-site areas to it. King of Bohemia's height ladder (comment at line 306): land 2.983, standard bridges
  3.088-3.150, EU bridges 5.136. Riverina raises the bridge sites to 8.0.
- The river width at a crossing must match the bridge's span. Florence uses radius 15 for a 26-tile bridge.
- **Open risk: trade boats under bridges.** Florence splits its river route at the bridge (0.0-0.4 and 0.6-1.0), so
  no boat passes under it. Either copy that split (the route becomes 2-3 separate stretches) or prove in one test
  that route boats pass the bridge groupings. Decide before building.

## Natives (`rmAllocateSubCivs(3)`: 0 Hussites, 1 Orthodox, 2 Prince Electors)

| Native | Where | Count | Grouping | Placement |
|---|---|---|---|---|
| Hussites (`zphussites`) | north outer shore (team 1's side), not on the locked inner shore | 2 (3 at 6+ players) | `Hussite_Camp_0` + 1..5 (the Elbe pairs types 4 and 5) | King of Bohemia castle cliffs: 600 tiles, base height 7.136, `Italian Cliff Grassy`, `shortAvoidTradeRoute`; or flat, like the Elbe camps |
| Orthodox (`zporthodox`) | south outer shore (team 2's side), not on the locked inner shore | 2 (3 at 6+ players) | `Orthodox_Monastery0` + `rmRandInt(4, 6)` (Balkan) | Adriatic plateau recipe (ramp area plus an 800-tile plateau with a painted top), cliff type switched to `Italian Cliff Grassy` for the King of Bohemia look |
| Prince Electors (`zpprinceelector`) | **the locked inner shore only**, equal distance from each team's bridge | max **4**: 2 at ≤4 players, 4 at 5+ | `Elector_Bavaria_0x`, `Elector_Austria_0x` (Danube states), then `Elector_Bohemia_0x`, `Elector_Saxony_0x` (`Brandenburg` has only `_02`) | Elbe recipe (controller object, then a 650-tile plateau at base height 5 with a 2-segment cliff edge, then the grouping at the centre), using `Italian Cliff Grassy` |

Triggers: copy each family whole from its source map, as listed in the reference table. The politician switchers
follow the `map-politician-triggers` skill. With three native systems on one map, every trigger family keeps its
own name prefix.

## Build order (the script spine)

1. Players, subcivs, size, light, sea, base terrain (water, method A), map types.
2. Classes and constraints.
3. The route waypoints (on the grid), then the river trade route, then its stopper at 0.5 (river steps 1-2). Read
   the built line back immediately (`rmGetTradeRouteWayPoint`) and keep it in variables for everything that
   follows.
4. The three shores as land areas avoiding the route by R (method A). Then the bridge sites (bank heights at the
   deck), then the bridges, read from the route on straight axis-aligned legs.
5. Cliff plateaus for the Electors, Hussites and monasteries. Build them after the route, so they avoid it, and
   before anything placed on top of them.
6. Native groupings, then trade sockets.
7. Inner-shore resources (the rich set), then dry-grass patches (south), then forests. Forests go **before** objects: a forest area built later deletes what
   it covers (London's tin mines).
8. Player placement around the bend (sections, fake-grouping lock), Town Centres and starting units, then the
   outer-shore mines, herds, fish in the river (if any) and nuggets.
9. Triggers (the three native families, the AI leader picks).

Keep the script spine valid at every stage of the build, and never strip it (the RM-spine rule).

## Registration and text

- A historical map like King of Bohemia: `randmaps/zpdanube.xs`, `zpdanube.xml` with `<filter>Historical</filter>`,
  `zpdanube.mods.xml`.
- New strings (name, details, load details) in the NEW STRINGS block, using the `aoe-game-text` skill.
- Minimap and load-screen images (`ui\random_map\...`) are new art the owner provides. Reuse King of Bohemia's
  until then.
- Map types, King of Bohemia style: `grass`, `land`, `default`, `centralEurope`, `euroLandTradeRoute`,
  `piratehistoricalmap`. The Elbe uses `water` and `euroTradeRouteCapture` instead. Choose these together with
  the dock question below, because map types gate ships (map-type memory).

## Verification (in this order)

1. `mapcheck` (names, route types, water, playability) and a map profile at `scripts/maps/zpdanube.json`.
2. `minimap-twin` / `mapsim` offline pictures, then the census of one generation: bridges (`zpBridgeFace`), sockets,
   natives, electors ≤ 4. No screen control is needed for this step.
3. Editor minimap (`map-minimap`): this takes the screen, so it needs the owner's go first.
4. Automated AI games only when the owner asks. The AI contests sockets, natives and bridges, so any map-specific AI
   code needs the owner's approval first (AGENTS.md rule 7).

## Risk analysis

Impact: **critical** = the map is broken (the inner shore unreachable, a crash); **high** = a core feature fails
silently; **medium** = visible defect or balance; **low** = cosmetic. Evidence tags: PROVEN = seen in this mod;
LIKELY = strong indication; OPEN = untested.

### Bridges (the riskiest spawns: they are the only way into the inner shore)

| # | Risk | Evidence | Impact | Mitigation and check |
|---|---|---|---|---|
| B1 | A bridge fails to spawn, so the inner shore is unreachable | groupings at an exact spot (min/max 0) fail silently when the spot is invalid (PROVEN, many maps) | **critical** | Build the bridge sites first and place each bridge on a route point of a straight axis-aligned leg. Check the placement result in the script; if a bridge is missing, build a fallback land causeway (a narrow land area across the corridor) at that point. Census the bridge count, and require `mapcheck` connectivity: inner shore reachable |
| B2 | A bridge placed **over the built route** is refused | "nothing may be placed on a built route": a park and a gate on a land road failed (PROVEN, `096ded9b`, `ed80e037`); London Bridge over its water lane works (PROVEN) | high | Probe P4 settles it for a river route. If refused, split the route at the bridges (Florence) |
| B3 | Wrong orientation | groupings cannot be rotated (PROVEN, never-rotate-a-cliffgroup); `Bridge_Universal_E/_N` never used | high | Bridges only on axis-aligned legs; map `_E/_N` with `grouping-terrain` before using them |
| B4 | Deck ends float or are buried, ramps unpathable | bridge groupings carry baked heights; King of Bohemia's height ladder (line 306); Riverina raises the sites to 8.0 (PROVEN) | high | Read the deck height from the grouping XML, set the site areas to it, and walk a unit across in the unit bench |
| B5 | River width at the crossing does not match the bridge span | Florence: radius 15 for a 26-tile bridge (PROVEN) | high | Set R (method A) from the span; no bridges on 45-degree legs |
| B6 | Bridge facade pieces overhang city cliff tiles (seams) | `grouping-terrain` skill: `zpBridgeFace` pieces ~9 m, the ZP Bridge vs ZP City cliff mix-up (PROVEN) | low | `grouping-terrain` review of the chosen groupings |
| B7 | Trade boats pass through the bridge decks | trade units ride the route curve (`BUnitRailroadAction ... mCurveParam` in the exe) and ignore obstruction (LIKELY); Florence keeps its river routes off its bridge, whose land route crosses on top | medium | Probe P4: watch a river trader pass. If it looks wrong, split the route |
| B8 | The AI does not path through the bridges or contest the inner shore | the AI contests sockets, natives and bridges; AGENTS.md rule 7 | medium | Owner decision before any AI work; an AI test only on request |
| B9 | Unit indices shift | every built route takes one unit index; King of Bohemia's "Fixed TradeRoute Issue" shifted every grouping unit +1 (LIKELY) | high | Freeze the build order before writing any trigger that addresses units by index; re-census after every order change |

### Trade route (shape and spawns)

| # | Risk | Evidence | Impact | Mitigation and check |
|---|---|---|---|---|
| T1 | Waypoints snap to the 16 m block grid, so the built route is not the authored line | trade routes guide, API row 347: "about 4 tiles off the asked point on Istanbul" (PROVEN); every water/river def has `blocksize="16.0"` | high | Method A (water follows the built route). Read every later position back from the built route; author the waypoints on the grid (probe P1) |
| T2 | Unknown path between snapped waypoints: the 9 piece types (`straight`, `straight45`, `corner90`, `corner45a/b`, `fillcorner`, `end`, `end45`, `corner90diagonal`) point to an 8-direction block lattice. A leg at another angle becomes a staircase or a dog-leg | piece names in `data/traderoutedefs.xml` (PROVEN); the algorithm itself is not in the exe strings (OPEN) | high | Legs at 0 / 45 / 90 degrees only; probe P2 measures the rule |
| T3 | River and route diverge at bends (method B) | river defs are most likely splines: `riverline` with `minSplineDistance` / `maxSplineDistance` in the exe (LIKELY) | high | Method A; B only if the probe shows they coincide |
| T4 | Route-versus-water build order | London law 1 "a route built after water poisons every later water placement" (owner-enforced 2026-09-18) versus the 2026-09-17 memory "nautical route after islands": guide O35 (OPEN) | high | Route first (London). Probe P3 checks fish and sockets placed after it |
| T5 | A river built over stoppers or controllers deletes them | London's lane stopper and controllers vanished (LIKELY, guide O36) | medium | Method A has no `rmRiverCreate`; with B, place them after the river |
| T6 | Anything placed on the route fails silently | PROVEN (London) | high | Every area and grouping avoids the route by constraint and is built after it |
| T7 | Sockets do not spawn or land in the water | route-linked sockets do not snap; a free coordinate on a route line spawned nothing (PROVEN, London 2026-09-27) | high | Only `rmGetTradeRouteWayPoint` points, a small max distance onto the bank; census the socket count |
| T8 | A fraction near a route end lands off the map | the built line can run past the map edge (LIKELY, guide API row 352) | medium | Sockets and bridges only on interior legs |
| T9 | The chosen socket shows no upgrades on a river route | the route kind decides the upgrade family (`DERiverTPOnly`); the guide's post-versus-route table (3.x) | medium | Check the chosen socket proto against the guide's table before choosing |

### Other spawns

| # | Risk | Evidence | Impact | Mitigation and check |
|---|---|---|---|---|
| S1 | The inner shore is too small at size 400 for 4 plateaus (650 tiles each), rich resources and forests | arithmetic: the inner shore is about a quarter of 200 x 200 tiles | high | Scale the counts with the map size; census every count |
| S2 | Elector sockets on fully cliff-ringed plateaus are unreachable | the Elbe leaves gaps (2 edge segments at 40 %); King of Bohemia's castle cliffs use a full edge | high | The Elbe edge pattern with the gaps facing the bridges; walk a unit up in the unit bench |
| S3 | Forests delete earlier objects | London tin mines (PROVEN) | medium | Forests before objects (build order 7) |
| S4 | Player starts fall on water or too close to the river or natives | `RING_LOW_LAND` (`rm-players`) | high | `mapcheck` SIM; tune the radius with the waypoints |
| S5 | Three native systems + triggers + routes on one map crash | Istanbul verdict: hacks do not stack (PROVEN) | **critical** | Copy proven blocks whole; one change, one test; MAP CODE for any crash |
| S6 | The three politician families clash on the consulate | the Elbe already runs Hussites + Electors (PROVEN precedent); Orthodox adds a third | medium | `map-politician-triggers`; check every consulate page in a test game |
| S7 | Leak around the lock: a land strip along the east edge lets players walk into the inner shore | world-circle handling at the edge (OPEN for this layout) | **critical** | Run both arms past the edge (King of Bohemia runs its river to 1.5); `mapcheck` connectivity |

## Upfront investigation: how a trade route takes its shape (before any Danube code)

**Static, done 2026-10-01 (no game needed):**
- `data/traderoutedefs.xml`: `blocksize="16.0"` on every river and water def (8.0 on `lava_flow`), and 9 piece
  textures that imply an 8-direction lattice (see T2).
- `AoE3DE_s.exe` strings: `traderoute.cpp`; trade units move by a curve parameter (`BUnitRailroadAction ...
  mCurveParam`); `rmAddRandomTradeRouteWaypoints(id, endX, endZ, count, maxVariation)` adds random wiggles (avoid
  it: not deterministic); `rmCreateTradeRouteWaypointsInArea(id, area, length)`;
  `DistanceAtMostFromTradeRoute` / `DistanceAtLeastFromTradeRoute` placement rules; `terrainCleanUpIllegalTOBs()`
  clears terrain objects near routes. **The path algorithm itself is not in the strings.** There is no "show route
  lines" command, only `clearTradeRouteLines()` and a `tradeRouteHackDebug` switch.
- `docs/trade_routes_guide.md` already holds the proven rules: snapping (API row 347), build order (5.7), sockets,
  upgrade families, and the open questions O34-O36 that bear on this map.

**Empirical probe** (a throwaway map `000000_trprobe`, never shipped). One generation per test, using the census
method (`rm-census`: save the generation, decode the `.age3Yscn`, read positions):

| Test | Question | Set-up | Result used for |
|---|---|---|---|
| P1 | Where is the grid, and how do waypoints snap? | 8 short straight routes with waypoints offset 0, 2, 4 ... 14 m; a marker unit at `rmGetTradeRouteWayPoint` every 1 % | the grid origin and spacing, the snap rule: Danube waypoints placed exactly on nodes |
| P2 | What does a leg at an arbitrary angle become? | legs at 0, 15, 30, 45, 60 and 90 degrees, 160 m long, same markers | whether non-45 legs are staircases or one bend: confirms the 0/45/90 rule |
| P3 | Does the Danube Bend corridor work? | the planned waypoints, method A with 2-3 values of R | a continuous corridor, a locked inner shore (`mapcheck` connectivity), fish and sockets after the route (T4) |
| P4 | Bridges | the planned bridge groupings at the planned fractions on P3 | placed or refused (B1/B2); deck heights (B4); a unit walks across (unit bench); a river trader passes under (play test, owner) |
| P5 | Sockets | river sockets at the planned fractions | count, position on the bank, river upgrade buttons (T7/T9) |

- **Order:** offline first (`mapcheck`, `mapsim`, `minimap-twin`). The editor generations of P1-P5 take the screen,
  so they need the owner's go (AGENTS.md rule 11), as do the `rm-census` drivers.
- **Exe disassembly** only if P1/P2 stay ambiguous: there are no symbols, and the strings carry no algorithm.
- **Deliverables:** a "route geometry" section in `docs/trade_routes_guide.md` (grid origin, snap and lattice rules,
  closing T1/T2 and O35/O36 where the probe answers them); `mapsim` / `mapcheck` updated to model the true lattice,
  so later maps are checked offline; then the Danube waypoints.

## Decisions for the owner before building

1. **Team arcs:** team 1 north and team 2 south of the bend, with the west apex left free as the land meeting point.
   Or do the teams share the whole arc?
2. **Bridges:** 2 at ≤4 players (one per arm) plus the shared apex bridge at 5+? No ford, to keep the inner
   shore locked.
3. **Trade route and bridges:** split the river route at the bridges (Florence), or keep it continuous and test
   that boats pass under the bridges?
4. **Electors:** which states? Proposed: Bavaria and Austria, then Bohemia and Saxony at 5+ players.
5. **Navy:** docks and warships on the Danube (the Elbe's `water` map type), or a land map with a trade river
   (King of Bohemia's `land`)?
6. **Location:** historical map (King of Bohemia, Elbe), or a random map in `game/randmaps` and a `.set`?
7. **Inner-shore richness:** the resource numbers (proposal: per 2 players 3 gold + 2 silver mines, 3 herds, 2
   hardwood patches, 2-3 higher-tier treasures), and whether the inner banks get contested trade sockets.
8. **The probe first:** approve the trade-route probe (P1-P5) before any Danube code. Its editor generations
   take the screen, so each run needs your go. Also: method A (water from the route, recommended) or B (Riverina:
   river object plus route)?
