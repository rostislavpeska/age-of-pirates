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
- Nautical routes need water waypoints; a land chain over water is a causeway design, not an error.

## Diagnosis order

1. `xmb_idcheck` on the two files (rung 2 of rm-diagnose)  2. the name exists in the mod file
3. process restarted after the regen  4. `rmBuildTradeRoute` returned true (echo it)  5. geometry.
