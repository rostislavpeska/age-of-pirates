---
name: rm-triggers
description: The HUB for random-map triggers in Age of Pirates - where a trigger task goes, the reference files, the anatomy of a trigger, the general laws that apply to every trigger (cost, tech execution, names, unit indices, order, gaia, what proves an effect), and the setup-tech convention for historical maps. Routes to the specialised skills (nugget-targeting, map-politician-triggers, rm-trigger-testing) instead of repeating them. Use before writing or changing ANY trigger or starting-tech code in a map. Triggers on "trigger", "starting techs", "setup tech", "ZP Set Tech Status", "rmCreateTrigger", "fire the tech", "tech does not activate", "gaia tech", "trigger guidelines".
---

# rm-triggers: the hub for map triggers

Read this first for any trigger work, then the specialised skill the task belongs to.

| The task | Skill |
|---|---|
| A trigger names a unit: capture, conversion, sockets, nuggets, Units in Area | `nugget-targeting` |
| Consulate / Trading Post politician switchers | `map-politician-triggers` |
| Testing: pytest pins, the trigger simulator, `trigtemp.xs`, the compiled rule shape, ping-pong, the unit INDEX law in full | `rm-trigger-testing` |
| AI scripts reacting to the map | `ai-edit` |
| Native extensions and their big buttons | `extended-native`, `native-politician` |

## Reference files

- `data/trigger/triggerdata.xml`: every trigger effect, condition and parameter name (`ZP Set Tech Status (XS)`,
  `Fire Event`, ...). Look a name up there; never guess one.
- `data/techtreemods.xml`: every `TechID` a trigger fires (`cTech` + the tech name).
- `docs/map_trigger_guide.md`: patterns and full examples (starting techs, politicians, pirate ship training).
  Where it disagrees with a law below, the law wins: the laws are measured and newer.

## Anatomy

`rmCreateTrigger` -> `rmSwitchToTrigger(rmTriggerID(...))` -> conditions -> effects -> properties. Starting
techs and setup: priority 4, active, run immediately, no loop. Monitors (a tech researched, a building owned):
loop. A trigger created inactive runs only when another fires it (`Fire Event`). Player loops: `1..N` for player
triggers, `0..N` only where gaia must get the effect too. Declare loop variables in `main()`.

## The laws (each one cost a session)

1. **Triggers are expensive; tech effect lists are cheap.** A map effect goes into a setup tech; the trigger only
   fires the setups (next section).
2. **Tech-execution law** (`nugget-targeting`, 2026-08-15): `TechStatus active` inside a tech only flips the
   target's flag and never runs its effects. A tech whose effects must run is fired by the trigger:
   `ZP Set Tech Status (XS)`, `Status 2`.
3. **Trigger-name law** (`nugget-targeting`, 2026-08-15): create with spaces, look up with underscores:
   `rmCreateTrigger("Starting Techs")` then `rmTriggerID("Starting_Techs")`. A space in a lookup works in the
   editor and silently fails in skirmish. The guide's older example and its case note are superseded.
4. **Unit parameters are INDICES.** Compute them (`rmGetUnitPlaced` + the map's shift, grouping-instance lookups);
   never type a literal id (`rm-trigger-testing` section 4, `nugget-targeting` Rules 0 and 2). A new unit goes AFTER
   every unit a trigger references, so no index moves (London's construction markers and countryside sockets are
   placed last, 2026-09-27).
5. **Effects run in the order written.** Keep dependencies in order within one trigger: London fires the generic
   setup (which adds the Stuart extension's big buttons) BEFORE the side setups that strip the other side's button.
6. **What proves an effect:** the RM dump proves compilation only; `trigtemp.xs` after a generation shows the
   compiled triggers; an effect is proven only in a running game. A changed `data/*.xml` needs its `.xmb` rebuilt
   and a game restart first (`rm-trigger-testing`, "Not evidence").
7. **Deleting from a production trigger or tech needs the owner's approval** (AGENTS.md rule 9). Read the tests
   that pin it first: they encode its dependencies.

## Setup techs: the map's effects live in techs, the trigger only fires them

Historical maps, and any setup-heavy map, keep their map-specific effects in SETUP techs in
`data/techtreemods.xml`. A new map effect (a `SetName`, an enable, a command, a cap) goes INTO a setup tech. Never
a trigger per effect, never another map's tech (`zpUnknownRogueAmerican`), never another map's setup (the London
rename put into `zpIndependenceWarSetup`, 2026-09-27). The reference layout is Paris / Civil War:

- `zp<Map>Setup`, the GENERIC setup: every player's effects, fired DIRECTLY by the trigger (`zpparis.xs` 2034,
  `zpcivilwar.xs` 1474). Civil War fires it for players 0..N, gaia included (`zpcivilwar.xs` 1471); London does the
  same since 2026-09-27 so gaia-owned buildings take the map's names. Istanbul warns that unit-changing effects at
  start can reset AutoConvert suspensions (`zpistanbulb.xs` 4347-4349): test the captures after.
- side setups (`...AttackerSetup` / `...DefenderSetup`, `zpCivilUnionSetup`): ONLY what differs per side, fired
  AFTER the generic one (law 5).
- `zp<Map>GaiaSetup` (Paris 2073, Civil War 1505): gaia-only effects such as hitpoints, fired for player 0.

A setup that switches another tech on from inside (`TechStatus active`) only sets a flag (law 2). That suits
shadow techs read as flags (a `...DisableShadow` used as a prerequisite). A tech whose effects must run is fired by
the trigger, or its effects sit in the setup's own list. London 2026-09-27: the side setups switched the generic
`zpLondonSetup` on from inside, so none of its effects ran (the city Distillery read Cognac). A tech near the end of
the file has also compiled, been granted and done nothing (index 1262 of 1312, 2026-08-19): check its index when
law 2 does not explain a failure.

## The Prince Elector site ladder (reverse engineered 2026-10-07)

Owning several elector settlements raises the elector units' build limits: one step of `zpElectorSiteIncrease`
(+9 Landsknecht, +15 Line Infantry, ...) per settlement beyond the first, taken back by `zpElectorSiteDecrease`.
Per player a ladder of triggers counts the owned `zpElectorCenter` (Crownlands: its workshops' team flags). Use the
Danube's `zpElectorSiteLadder(numSettlements)` (above `main`): one independent toggle per threshold n -
"Elector Increase<n>" (count >= n, active at start) wakes only "Elector Decrease<n-1>" (count <= n-1), which wakes only
Increase<n>. The hand-written chains of Crownlands / Unknown (4 castles) and Independence War's estates (6 houses)
also wake the next rung of the same direction and count a loss of two settlements in one tick twice (4 -> 0 at once:
-3 steps); fixing them deletes Fire Events from production triggers (AGENTS.md rule 9, waiting for the owner).
mapsim records every trigger a script executes (`Extraction.triggers`); `scripts/mapcheck/elector_ladder.py`
replays each ladder on walks of the owned count, and `scripts/mapcheck/tests/test_elector_ladder.py` runs it for every
map with electors at 2, 4, 6 and 8 players (the three maps above as strict xfails).

## Before a trigger change ships

- Every `TechID` exists in techtreemods; every effect name in triggerdata.xml.
- Lookups use underscores; loop ranges are deliberate (gaia in or out).
- New units placed after every referenced unit; no literal ids.
- The map's trigger tests pass (`python -m pytest scripts/mapcheck/tests -q -k <map>`); the data twins are rebuilt.
- One running game proves the effect; the editor generation proves only compilation.
