# Parked ideas

Ideas the owner wants kept but not built yet. One file per idea that needs a plan; one line here for everything
else. An idea moves to `docs/plans/` (approved) or `docs/briefs/` (work in progress) when the owner says go, and its
line here says where it went. Newest first.

| Date | Idea | Status | Where |
|---|---|---|---|
| 2026-10-01 | Danube map: players around the Danube Bend; the locked shore inside the bend (bridges only) holds max 4 Prince Electors on cliffs and rich resources; river = water trade route (Riverina method), Florence-docked bridges; Hussites north, Balkan Orthodox monasteries south; King of Bohemia land and water, dry-grass patches in the south | v8b (normal map, `game/randmaps/zpdanube.xs`) failed in game 2026-10-06 (15% of the map water); v9 regeneration plan (17 requirements, land route over the bridges, roads) awaiting the go | [2026-10-01-danube-map.md](2026-10-01-danube-map.md) |
| 2026-09-28 | Whalers from a new map type `inuitwhaling` on every map with Inuits, and the Inuit tech `zpInuitUmiaks` shipping a hero (Tuglavina) who trains merc Harpooners | parked, owner watching | [2026-09-28-inuit-whaling-and-hero.md](2026-09-28-inuit-whaling-and-hero.md) |
| 2026-09-28 | Wokou junks: Kurils and Melanesia give every player a starting `ypWokouJunk` (`zpkurils.xs` 861, `zpmelanesia.xs` 1822). It shares the Wokou settlement's build limit (3), so it takes one slot from the start. The Wokou have no junk HP/damage upgrade, while the pirates get `zpUpdatePrivateersI/II`. Proposal: `zpWokouCheapShipyard` (already +1 limit, -25 % cost/time) also gives +15 % HP and damage to `ypWokouJunk`, price 150 wood + 150 gold. Clean alternative: a starting-junk clone outside the pool, like vanilla's `deStartingUnitPrivateer` | proposed, numbers are the owner's | this line |
| 2026-09-28 | Automatic image judgement of the destruction bench: send the run video to a Gemini video model through a new n8n workflow (the current one only generates images) | later, only if the owner's keyframe review is not enough | `docs/briefs/2026-09-28-destruction-bench-plan.md` |

## Side findings noticed on the way (not ideas, just not fixed)

- `game/randmaps/zpmalta.xs` line 55: `rmSetMapType("euroLaclasssocketndNavalTradeRoute")` is a garbled name that
  forces nothing (harmless: line 60 sets `euroNavalTradeRoute`).
- `data/mapspecifictechmods.xml` has the `caribbeanwater` block twice (also noted in `docs/trade_routes_guide.md`).
- `scripts/tools/unitbench.py` pre-flight P3 exempts only `.pkfx` particles, so a vanilla `.particle` reference
  (the Mortar's `smoke_puff.particle`) fails as a missing `.gr2`.
- `scripts/source/techtreey.xml` and `protoy.xml` are older than the current patch (no `deMapArctic`,
  `DENativeInuit`, whaler on the Dock); refresh them with `bartool extract ... --in-repo`.
