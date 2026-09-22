---
name: rm-trigger-testing
description: Test a random map's trigger system offline first, then read the game's compiled trigger script after ONE user-requested generation. Covers the workflow ladder (S6, pytest pins, the trigger simulator, trigtemp.xs, census), the compiled rule shape, the unit INDEX law, the engine's trigger dynamics (Fire Event, ping-pong, Socket Build on water, process-stale data) and the trigtemp_check.py checker. Triggers on "trigger does not fire", "only the last one works", "persistent flare", "socket build places nothing", "read trigtemp", "test triggers offline", "ping-pong", "trigger loops". The in-game generation is done ONLY when the user asks for it.
---

# rm-trigger-testing: triggers are proven offline and by one read of trigtemp.xs

The game is generated ONLY when the user asks for it. Everything else here is offline.

Never launch, kill, click into or automate the game or the Scenario Editor on your own initiative
(`game-startup`, `rm-census`). Never play a match to find out whether a trigger works.

## 1. The ladder (stop at the first rung that fails)

| Rung | Command | Proves |
|---|---|---|
| 1. S6 scope check | `python scripts/mapcheck/xs_scope_check.py randmaps/<map>.xs` | no use-before-declaration, double declaration, call-before-definition, reserved word (`label`, `rule`, ...): a failure here = "Random Map: X failed to load" with no log |
| 2. Shape pins | `python -m pytest scripts/mapcheck/tests/test_london_roles.py scripts/mapcheck/tests/test_london_revolt.py scripts/mapcheck/tests/test_parliament_natives.py -q` (London; each map pins its own) | the trigger blocks still have the agreed shape (names, four `rmSetTrigger*` lines, event wiring) |
| 3. Simulator | `python -m pytest scripts/mapcheck/tests/test_gunsocket_lock.py scripts/mapcheck/tests/test_gunsocket_lock_harness.py -q` | engine rule model on the families it parses today (section 7) |
| 4. ONE generation | the user generates (or asks for a driver run, `rm-census` section 3) | the map compiles and the game writes `trigtemp.xs` |
| 5. Read trigtemp | `python .claude/skills/rm-trigger-testing/scripts/trigtemp_check.py` then `--rule <Name>` for the rules in question | every unit parameter resolved, every event wired, no every-frame cycle |
| 6. Census | `python sandbox/census/census.py "<profile>\Scenario\<save>.age3Yscn" --full` | the indices the triggers name hold the units you meant (section 4) |

One falsifiable hypothesis per generation. After rung 5 STOP and report; do not reach for a match.

## 2. The artifacts (what each one proves)

| Artifact | Where | Proves | Never proves |
|---|---|---|---|
| `trigtemp.xs` | `<profile>\Trigger\trigtemp.xs`, rewritten on every generation, editor and skirmish | the trigger script the game compiled from the map's `rm*Trigger*` calls, one XS rule per trigger: the whole trigger diagnosis after ONE generation and BEFORE any play | render, spawn |
| RM dump | `<profile>\RandMaps\Age3DERM<mapfile>.dmp.txt` | the map script compiled (XS symbol table; values are 0, written before the run) | anything about triggers or placement |
| Saved scenario | `<profile>\Scenario\<name>.age3Yscn`, read by `sandbox/census/census.py <save> --full` | every placed unit with proto and position in INDEX order: ground truth for indices and spawns | render; mod proto NAMES are unreliable (match by position and count) |
| Screenshot | `sandbox/census/samples/...` | RENDER only (a unit can be placed and never render: LF-only animfile) | spawn, triggers |

`<profile>` = `C:\Users\TIGO\Games\Age of Empires 3 DE\76561198347905238`; the repo sits at
`<profile>\mods\local\age-of-pirates`.

## 3. The compiled rule shape (read it, do not guess it)

```
rule _Name
highFrequency                    (or minInterval N)
active | inactive
runImmediately                   (absent on some rules)
{
   bool bVar0 = (true);
   trUnitSelectByID(1012);       // a unit condition reads the selection made just before it
   bool bVar1 = (trUnitIsOwnedBy(1));
   bool tempExp = (bVar0 && bVar1);
   if (tempExp)
   {
      trSetUnitIdleProcessing(true);
      <effects in order>
      trEventFire(2377);         // one "Fire Event" -> a numeric event id, mapped by eventHandler
      xsDisableRule("_Name");    // present when the trigger does NOT loop
      trEcho("Trigger disabling rule Name");
   }
}
```

`void main(void)` comes first (one `trEventSetHandler(id, "eventHandler")` per event), then
`void eventHandler(int eventID=-1)`: `case <id>: xsEnableRule("_Target");`. A looping trigger either
lacks `xsDisableRule(self)` or re-arms itself with `trDelayedRuleActivation("_Self")` right after it
(London's `_Activate_Consulate_*`).

Measured on the London generation of 2026-09-22 20:54: 239 rules, 200 handler events,
294 `trEventFire`, 24 `trDelayedRuleActivation`, 361 `trUnitSelectByID`, 285 `trConvertUnitsInArea`,
129 `trTechSetStatus`, 52 `trSocketBuild`, 40 `trUnitConvert`, 32 `trDisableTrigger`,
20 `trUnitSuspendAction`, 16 `trMinimapFlare`, 2 `trTeamVictory`, 0 `trUnitSelect("...")`.
(The 20:07 file the brief quotes had 243 rules; the counts move with every map edit.)

How to read a unit parameter:

- `trUnitSelectClear(); trUnitSelectByID(223);` - the index resolved to a live unit at generation.
- `trUnitSelect("262148");` - a select by NAME: the value was not an index. DEAD, silent no-op.
- String-typed params are passed VERBATIM and resolved by the engine at run time from the same
  index: `trCountUnitsInArea("226",1,"TradingPost",8)` (Units in Area `DstObject`),
  `trSocketBuild(1, "281", "zpSPCCityTowerFlat")` (Socket Build `Socket`),
  `trNuggetCollectable("363")` (Nugget Is Collectable `NuggetObject`). A wrong index here is NOT
  visible in trigtemp: confirm it against the census.

## 4. The index law (checklist)

The most expensive fact of the project (`nugget-targeting` Rule 0, memory
`rm-getunitplaced-stale-handles`):

- [ ] Every trigger parameter that names a unit takes the unit's scenario INDEX (placement order =
      census order), never an engine id.
- [ ] Grouping unit: `rmGetGroupingInstanceUnitByType(placement, proto) + instanceIdShift`; the
      constant is per map (London 3, Istanbul 2, Paris 1), measured with root copies differing only
      in the constant.
- [ ] Plain object-def unit: `rmGetUnitPlaced(def, 0) + instanceIdShift` (Istanbul's `fortMark`
      markers, `randmaps/zpistanbulb.xs` 4200-4205, shift `instanceIdShiftIndividual`).
- [ ] A socket docked on a trade route (`rmSetObjectDefTradeRouteID`): `rmGetUnitPlaced` returns an
      engine id in the 0x40000 pool (262146...). No constant fixes it: literal indices from a census,
      re-census after any change to what is placed before it.
- [ ] Several sockets of ONE proto in one grouping: `rmGetGroupingInstanceUnitByType` returns one of
      them. Put the sockets LAST in the export and place a `zpSPCWaterSpawnPoint` marker right after
      the grouping; sockets = marker index - 1 .. - n (`randmaps/zpazteccity.xs` 624-631 defines the
      markers, 1348-1351 derives the ids; London section 13).
- [ ] Adding N units to any grouping placed EARLIER shifts every later literal index by N
      (2026-09-22: the bridge gained two gate sockets and a marker, the guards moved +3).
- [ ] Trigger names: create them with the exact string you look up. A space in an `rmTriggerID`
      lookup works in the editor and fails in skirmish (`nugget-targeting`); London uses underscores.

## 5. Engine laws of trigger dynamics

1. `Fire Event` ENABLES the target rule; the target then waits for its own condition (next tick). A
   fired non-looping rule disables itself. `Timer` / `Timer ms` count from the rule's activation
   (`cActivationTime`). Source: `scripts/mapcheck/triggerdsl.py` docstring and trigtemp.xs.
2. Ping-pong: two triggers that fire each other and whose conditions can hold at the same time
   re-fire every frame. Measured 2026-09-22: London's `Towers_ON1` <-> `Towers_ON2`, both
   `Team Unit Count zpSPCTowerOfLondon >= 1` for their team; with one Tower per team the minimap flare
   never stopped (fixed in commit 8ac63e04). Paris's `RoyalCourt_ON` (`randmaps/zpparis.xs`
   2303-2350) is safe only because one proto is one building with one owner. Rule: one-shot effects
   (flares, sounds, tech grants) belong in the per-player `Units Owned` conversion trigger, one event
   per capture (Bohemia's `CastleOn_Player`, `randmaps/zpkingofbohemia.xs` 1799-2005, its flare at 1975).
3. A team-count condition can never tell WHICH of two same-proto units a team holds.
4. `Socket Build` at run time is a placement: a LAND building on a bridge deck or over water places
   nothing, for gaia and for player 1 alike (three restarts, 2026-09-22; memory
   `socket-build-needs-air-on-deck`). Built protos there are `<movementtype>air</movementtype>`
   (`randmaps/zpvenicecity.mods.xml` 196-199 overrides `deSPCCityTower`; `zpAztecCityOutpost`,
   `zpSPCFixedGun`). AztecCity's proven order: `Defender_Setup0` converts the sockets to the builder,
   `Defender_Setup1` builds 10 ms later (`randmaps/zpazteccity.xs` 1565-1690). No map in the mod builds
   for gaia; London builds for player 1 and converts to gaia afterwards.
5. The Bohemia gate rebuild: a unique invisible gate socket proto per gate under the gate, one
   transform tech per socket (`cTechzpConverGate1..8`, `randmaps/zpkingofbohemia.xs` 2263-2382), fired
   once on capture when no gate of the owner stands within 15 m, then a 500 ms deactivator
   (`Gate_Rebuilt_Deactivator`, line 2389); the transform consumes the socket (one rebuild per gate).
6. Process-stale law: protomods, techtreemods, strings, commands, powers and abilities load ONCE at
   process start. Before blaming a trigger compare `(Get-Process AoE3DE_s).StartTime` with the
   `data/*.xml.xmb` mtimes. A `TechID` the running process cannot resolve drops that trigger at
   serialization and can derail the triggers after it: blocks that name new techs go LAST in the map
   (London section 16).
7. `debugRandomMaps` in `Startup\user.cfg` freezes every generation after the next restart (memory
   `debugrandommaps-hangs-generation`). Never set it.
8. XS main scope has no block scope: a variable declared in a loop body, or a bare loop variable,
   shares `main`'s namespace (memory `xs-main-scope-collisions`); S6 catches it.

Map scripts are written LITERALLY (Istanbul's shape): no helper functions around placements or
triggers, every trigger with its four `rmSetTrigger*` lines, ids derived in one block (memory
`map-scripts-literal-not-abstracted`). Working files are frozen until the user names them.

## 6. `scripts/trigtemp_check.py`

```bash
python .claude/skills/rm-trigger-testing/scripts/trigtemp_check.py                 # <profile>\Trigger\trigtemp.xs
python .claude/skills/rm-trigger-testing/scripts/trigtemp_check.py <copy.xs>       # a saved copy
python .claude/skills/rm-trigger-testing/scripts/trigtemp_check.py --list          # every rule: state, loop, conditions, targets
python .claude/skills/rm-trigger-testing/scripts/trigtemp_check.py --rule Bridge_ON_Plr1
python -m pytest .claude/skills/rm-trigger-testing/tests -q
```

Read-only, standard library. One line per finding, `KIND rule detail`, then a `#` summary line.
Exit 1 on DEAD or CYCLE, 2 when the file is missing, else 0.

| Kind | Meaning | Do |
|---|---|---|
| `DEAD` | `trUnitSelect("...")`: a unit param that was not an index | fix the index (section 4), census |
| `GAIABUILD` | `trSocketBuild(0, ...)` | build for a player, convert afterwards (law 4) |
| `CYCLE` | a Fire-Event cycle (through `trEventFire` + handler, `xsEnableRule`, `trDelayedRuleActivation`) with no timer and no provably exclusive pair of conditions: can re-fire every frame | move the one-shot effect into the per-capture trigger (law 2) |
| `POLL` | info: the same cycle throttled by a timer or `minInterval` - a periodic re-check | intended? London's 48 `BuildTower*_ON/_OFF` pairs are (1200 ms) |
| `ALWAYS` | an active looping rule whose only condition is `(true)` | runs every frame forever; almost never meant |
| `UNDEFINED` | a fired event id with no handler case, or an enable target that is not a rule | a missing trigger or a name typo |
| `DISABLED-TARGET` | `trDisableTrigger(n)` maps to no rule | same |

Provably exclusive (the cycle is a designed toggle, not reported): `trUnitIsOwnedBy(p)` on the same
`trUnitSelectByID(x)` with different `p`; the same expression compared to disjoint ranges (`>= 1`
against `== 0`, `>= 2` against `< 2`); the same expression `==` two different literals. Never
exclusive: timers (`cActivationTime` is per rule), team counts of different teams, tech status,
`(true)`, anything under `||`. A self re-arm by `trDelayedRuleActivation` is the loop flag, not an edge.

Deviation from the 2026-09-22 brief, on purpose: a timer-throttled cycle is `POLL` (exit 0), not
`CYCLE`, because it cannot re-fire every frame; otherwise every London socket-build pair would fail.
Effects are not modelled: a cycle whose own effects falsify a condition is still reported.

Result on the London generation of 2026-09-22 20:54: 239 rules, 200 handler events, 0 failing,
48 `POLL` (the twelve wooden-tower sockets x four players).

## 7. The simulator today, and the agreed extension (NOT built)

`scripts/mapcheck/triggerdsl.py` parses the RM trigger DSL (plain calls, `+` concatenation, the
`for (v = 1; <= cNumberNonGaiaPlayers)` idiom unrolled) and simulates the engine rule model (ANDed
conditions, self-disable unless loop, Fire Event enables). Its parser reads only the gun-socket
subset; the tests are `test_gunsocket_lock.py` and `test_gunsocket_lock_harness.py`.

Agreed next step, not built: a runaway detector (after each scenario step the simulation must reach
quiescence within a few ticks; any rule firing repeatedly while the world is unchanged fails), golden
snapshots of the parsed, unrolled trigger list for the verified families, a static Fire-Event cycle
check on the DSL side, and London's vocabulary in the parser.

## 8. Not evidence

- The RM dump, for anything about triggers.
- A screenshot, for a spawn (and the minimap, for units).
- A shift constant, for a trade-route-docked socket.
- A generation run in a process older than the `.xml.xmb` files it depends on.
- A trigtemp.xs that is older than the map edit (check its mtime against the generation).
