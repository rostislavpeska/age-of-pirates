---
name: rm-trade-routes
description: Trade routes on random maps - route type = the traderoutedefs record name (land vs nautical, the DLC's arctic chains), upgrade chains in traderoutes.xml, the ONE-LINE record rule for the compiled twin, sockets at waypoints, build order versus cliffs, and the "falls back to the base route" diagnosis. Use when adding or changing a trade route, switching a route type, when trade units are wrong or missing, when a route renders as dirt, or when the Trading Post upgrades look wrong. Triggers on "trade route", "rmBuildTradeRoute", "route type", "arctic route", "trade units", "falls back to dirt", "traderoutedefs".
---

# rm-trade-routes

## The API is small and the name is everything

```cpp
int r = rmCreateTradeRoute();                       // no arguments, no type here
rmAddTradeRouteWaypoint(r, x, z);  ...              // or rmAddRandomTradeRouteWaypoints
bool ok = rmBuildTradeRoute(r, "<route-def name>");  // THE type: textures + trade units + upgrade chain
vector p = rmGetTradeRouteWayPoint(r, 0.3);  rmPlaceObjectDefAtPoint(socketDef, 0, p);   // sockets
```

`"<route-def name>"` is a `<route ...>NAME` record in `data/traderoutedefs.xml` (the mod overrides the
whole vanilla file). Unknown name = the engine silently builds the base route. `mapcheck` now checks
it (S4 "unknown trade route type"). Upgrade levels come from `data/traderoutes.xml`
`<level><upgrade><from>A</from><to>B</to>`; a level-2/3 record carries `hideoneditor=""` so it stays
out of the editor list - that attribute is vanilla, not a lock.

| Land chains | Nautical chains |
|---|---|
| dirt -> stone -> train; snow -> stone -> train; dirt_trail -> stone_trail | water -> water2 -> water3; water_trail -> water2_trail (Trading Galleon) -> water3_trail (Fluyt) |
| arctic1 (Arctic Trader) -> arctic2 (Sled) -> arctic3 (dogs + dog sled) [DLC, ice road] | arctic_water_trail (Umiak) -> arctic_water2_trail (Galleon) -> arctic_water3_trail (Icebreaker) [DLC] |
| mod: xmassnow -> xmasstagecoach -> xmastrain; armored_train; lava_flow | mod: hansa_water_trail -> water2_trail; native_water_trail chain; asian_water_trail chain |

Vanilla precedent for the ice road: `Arctic Territories.xs` builds `"arctic1"` with `SocketTradeRoute`
and `rmCreateTradeRoute()` - the same three calls as any land route.

## The compiled-twin rule (cost hours on 2026-09-10)

Every record in traderoutedefs.xml is ONE line. A record pasted multi-line (the DLC merge did this
for the six arctic routes) compiles its name as `'arctic1\r\n    '` - the lookup never matches and
every generation shows the base route while "all other routes work". Verify with
`python scripts/tools/xmb_idcheck.py data/traderoutedefs.xml data/traderoutes.xml` (STALE / WSTEXT),
regenerate the .xmb, restart the game (data loads at process start).

## Build order and geometry

- Build routes BEFORE any cliff area they must cross so the cliff edge can leave gaps; Cold War
  builds its routes after the cliff-ringed islands (the old engine tolerated it).
- `rmCreateTradeRouteDistanceConstraint(name, m)` only acts on routes that already exist when the
  constrained area is built; an "islands avoid the route" constraint declared before the route is
  inert (Cold War: the islands cover the corridor, which is the design).
- Sockets: `rmGetTradeRouteWayPoint(r, fraction)` returns engine metres; place with
  `rmPlaceObjectDefAtPoint`. Count sockets in the census (`SocketTradeRoute`) to prove the route built.
  Always use a ROUTE POSITION, never a free map coordinate. `rmPlaceObjectDefAtLoc(socket, 0, x, z)` at a point
  on the road's line spawned nothing (London countryside sockets, 2026-09-27). The block that works is King of
  Bohemia's (`zpkingofbohemia.xs` 267-272, 745): one def with `rmSetObjectDefTradeRouteID`, `SocketTradeRoute`,
  `rmSetObjectDefAllowOverlap(true)`, min 2 / max 8 m, then `rmPlaceObjectDefAtPoint(def, 0,
  rmGetTradeRouteWayPoint(route, fraction))`. On a straight route the fraction runs along the waypoints, so a
  map position converts to a fraction directly.
- Nautical routes need water waypoints; a land chain over water is a causeway design, not an error.

## Harbour port sites: the tracked pattern (18 maps)

A harbour on a coast or a river is a PORT SITE: a big round area of land under the harbour, set back from the route
point, with the harbour grouping between it and the water. Owner 2026-10-08: "It's a known pattern from other maps -
needs to be tracked"; the Danube re-derived it three times in one night (a pad joined to the bank 30 m off the route,
then a tiny island, then this). Copy it, never derive.

| Map | Site (tiles) | Smooth | Harbour grouping | Trade socket |
|---|---|---|---|---|
| zpaustralia, zpnewguinea | 400 | 15 | Harbour_Universal_<dir> | inside the grouping + a route-linked `zpSPCWaterSpawnPoint` at the route point |
| zptorresstrait | 500-600 (+ class portSite) | 15 | Harbour_Universal_<dir> | as above |
| zpkurils, zpzealand, zpmelanesia, zpmalta | 600 | 15-20 | harbour_universal_<dir> | as above |
| zpatols, zpvenice, zptasmania | 400-650 | 15 | Platform_Universal / Harbour_Center_* | per map |
| zpmississippi (river) | 450, base 0.5 | 20 | Harbour_Center_River_NE / _SW, 7 tiles toward the water | `zpSPCPortSocket` (an SPC port, not a trade post) |
| zpmalta_castles, zppolynesia, zpmediterranean, zpcaribbeanwars | 600-630 | 15-20 | Harbour_Center_* | `zpSPCPortSocket` |
| zpburma_b, zptortuga, zpblacksea | 350-600 | 15-20 | pirateport / harbour_0x | per map |
| zpdanube (river) | 400, base = land | 4 | Harbour_River_NE / NW / SE / SW (the owner's socket + 3 platforms) | `SocketTradeRoute` inside the grouping |

The recipe: `rmCreateArea` 400-600 tiles, coherence 1, base height of the land (a beach: lower), the site's mix,
smoothing 15-20 at sea but about 4 in a river (wide smoothing raises the bed toward the route), centred about one
site-radius behind the harbour so it joins the land; the harbour grouping 14-16 m in front of the site's centre,
facing the water, its socket INSIDE it. Position everything from the route's authored line, never read-backs at
route ends (mapcheck S9).

**One tile back from the route, always, the land with it** (owner 2026-10-07, Danube: "harbours - 1 tile back from
trade route always - including the land beneath them"): the Danube's sockets went from 16 to 18 m off the route
line, the port site with them (its centre 17.6 m behind the socket) and its route margin from 10 to 12 m off the line.
Move the site together with the harbour, never the grouping alone.

**Sockets inside groupings (owner 2026-10-07, track this):** a STANDARD socket works inside a grouping -
`SocketTradeRoute` (Australia's Harbour_Universal_*, the Danube's Harbour_River_*), the SPC port socket
`zpSPCPortSocket` (Caribbean Wars' Harbour_Center_*). A CAPTURABLE socket inside a grouping does NOT work - an engine
bug: place those by object def. One grouping with its socket is the simple way; a separate route-linked socket next
to platforms is not needed.

**Harbour grouping names are SCREEN directions** (the camera is turned 45 deg), the suffix the side the harbour faces the
water on (measured on Harbour_Universal_*, Harbour_Center_*): NE = world east, NW = world north, SE = world south,
SW = world west; N / E / S / W are the diagonals between. The four main (world-axis) directions are therefore the set
NE / NW / SE / SW. Harbour_River_NE / NW / SE / SW (2026-10-07): the owner's "Harbour center - platform unit" (profile
RandMaps/groupings) - the socket as the origin, three platforms 9.4-10.1 m out (variants 130 / 247 / 247), no
painted terrain.

Pitfalls (Danube, 2026-10-08):
- route-distance constraints count from the 16 m road's EDGE, 8 m beyond the line: "7 m" keeps land 15 m off;
- measure the water at each harbour first (mapsim terrain grid): the Danube's point bars bring the bank to 28-31 m
  off the route, the far bank is 46-51 m;
- a NEW grouping file is found only after a game restart (rm-groupings-deploy);
- an island (separate from the bank) is not reachable on foot - say so, never decide it silently either way.

## Diagnosis order

1. `xmb_idcheck` on the two files (rung 2 of rm-diagnose)  2. the name exists in the mod file
3. process restarted after the regen  4. `rmBuildTradeRoute` returned true (echo it)  5. geometry.
