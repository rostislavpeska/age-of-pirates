# Brief: extract the trigger-testing skills (2026-09-22)

Written for: a fresh Claude Code agent started in this repository with no memory of the London session.
Read this whole document before touching a file. Everything below was measured on 2026-09-21/22 on the
London map; where a fact has a source, the source is named so you can verify it instead of trusting me.

## 0. What you are building, in one paragraph

Two skills. (1) A new skill `rm-trigger-testing` that tells an agent how to test random-map trigger
systems OFFLINE first, how to read the artifacts the game writes after ONE generation, which engine
laws the triggers obey, and a checker script over the game's compiled trigger script. (2) An extension of
the existing `rm-census` skill into the universal observation skill: every artifact, plus the exact,
measured sequence by which a game test is controlled from the Scenario Editor (generate, start the
playtest, end it, save), plus a monitor-independent window-coordinate helper so the existing screen
drivers work on any monitor. The in-game generation step is done ONLY when the user requests it.

## 1. Hard rules (each one has cost real money)

1. Never launch, kill, click into, or automate the game or the Scenario Editor. Never take the screen.
   Never run `sandbox/census/london_gen_safe.py`, `sandbox/census/editor_regen.py`,
   `sandbox/census/bench_run.py`. A `--dry-run` you add yourself may be run only if the script
   provably performs no input event when the game is not running; if unsure, do not run it and say so.
2. The repository IS the live mod (the game loads it). Never write vanilla extractions into it.
   `bartool extract` only into a scratch directory outside the repo (skill `bar-extract`).
3. Never write under `randmaps/`, `data/`, `game/`, `sound/`, `art/`. Your paths are:
   `.claude/skills/rm-trigger-testing/**`, `.claude/skills/rm-census/SKILL.md`,
   `sandbox/census/gamewin.py`, `sandbox/census/tests/**`, and edits to the three drivers named in
   section 6 (only the coordinate refactor described there), plus `docs/agent-skills.md` if it indexes
   skills (check first).
4. Git: commit only your own paths with explicit `git add <path>`. Never `git add -A`, `git commit -a`,
   `git stash`, `git reset`, `git checkout -- <other file>`. Another session may edit map/data files in
   this tree concurrently. Commit message style: one long descriptive first line, a blank line, then
   exactly the line `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`.
5. Backslashes: the Bash tool collapses `\\` even in quoted heredocs. Write every file that contains a
   Windows path or a regex backslash with the Write tool; build a literal backslash in Python from
   `chr(92)` when you must patch through Bash.
6. Runtime XML (`art/**/*.xml`, `*.material`, `sound/**/*_snds.xml`) must be CRLF; you are not writing
   any, but do not "fix" line endings of files you touch either. Preserve each file's existing endings.
7. Skill conventions: read `.claude/skills/README.md`, `docs/agent-skills.md`,
   `.claude/skills/skill-library-audit/SKILL.md` and `docs/skill-system-architecture.md` before writing.
   One `SKILL.md` per skill with frontmatter `name:` and `description:`; scripts under the skill's
   `scripts/`, tests under `tests/`. The new skill is AoP-only: do NOT add it to
   `scripts/skill-sync-manifest.json`.
8. No in-game verification is expected from you and none is allowed. Everything you deliver must be
   verified offline (pytest, a dry run of a parser over a real artifact copy).
9. Say what you could not verify. A guess presented as a fact is the failure mode this project pays for.

## 2. Orientation: the files you will read

Repository root: `C:\Users\TIGO\Games\Age of Empires 3 DE\76561198347905238\mods\local\age-of-pirates`.
Profile folder (the game writes here): `C:\Users\TIGO\Games\Age of Empires 3 DE\76561198347905238`.

| What | Path |
|---|---|
| The map whose systems were measured | `randmaps/zplondon.xs` (sections `// ---- 13.` triggers, `13.3` Tower conversions, `13.4` victory, `13.5` bridge, `13.6` bridge towers, `14.` starting techs + AI chain, `16.` AI socket build) |
| Its tests (the shape pins) | `scripts/mapcheck/tests/test_london_roles.py`, `test_london_revolt.py`, `test_parliament_natives.py` |
| The XS scope checker | `scripts/mapcheck/xs_scope_check.py` (S6: use-before-declaration, double declaration, call-before-definition, reserved words) |
| The existing trigger simulator | `scripts/mapcheck/triggerdsl.py` (engine rule model; parser reads only the gun-socket subset), used by `scripts/mapcheck/tests/test_gunsocket_lock.py` and `test_gunsocket_lock_harness.py` |
| The saved-scenario census | `sandbox/census/census.py <file.age3Yscn> [--full]` |
| Screen drivers (read, do not run) | `sandbox/census/bench_run.py`, `sandbox/census/london_gen_safe.py`, `sandbox/census/editor_regen.py`, `sandbox/census/capture.py`, `sandbox/census/ai_view.py`, `sandbox/census/census_judge.py` |
| Skills to read | `.claude/skills/nugget-targeting/SKILL.md` (Rule 0 = the index law), `rm-census`, `rm-unit-bench`, `rm-diagnose`, `game-startup`, `mapcheck`, `map-politician-triggers` |
| Reference maps | `randmaps/zpparis.xs`, `zpistanbulb.xs`, `zpcaribbeanwars.xs`, `zpkingofbohemia.xs`, `zpazteccity.xs`, `zpvenicecity.xs` |
| Session memory (read-only, outside the repo) | `C:\Users\TIGO\.claude\projects\c--Users-TIGO-Games-Age-of-Empires-3-DE-76561198347905238-mods-local-age-of-pirates\memory\` : `rm-getunitplaced-stale-handles.md`, `socket-build-needs-air-on-deck.md`, `london-map-status.md`, `map-scripts-literal-not-abstracted.md`, `debugrandommaps-hangs-generation.md`, `xs-main-scope-collisions.md`, `xs-reserved-words.md`, `grouping-deploy-gap.md`, `steam-root-groupings-off-limits.md`, `mods-xml-never-in-game-root.md` |
| The game's compiled trigger script (a copy is your parser fixture) | `<profile>\Trigger\trigtemp.xs` (rewritten on every generation, editor and skirmish) |
| The RM dump | `<profile>\RandMaps\Age3DERM<mapfile>.dmp.txt` |

## 3. The measured facts the skill must encode

Every item: what, then where it was measured.

### 3.1 The artifacts and what each proves

- `trigtemp.xs`: the trigger script the game compiled from the map's `rm*Trigger*` calls, one XS rule
  per trigger. It is the whole diagnosis of a trigger system after ONE generation and BEFORE any play.
  Source: nugget-targeting SKILL.md Rule 0; London 2026-09-22 18:29-20:07 (six generations read).
- The RM dump `Age3DERM<map>.dmp.txt`: the compiled XS symbol table of the map script; proves the script
  compiled, values are 0 (written before the run). Never evidence about triggers.
- The saved scenario `.age3Yscn`: zlib stream after the 8-byte `l33t` header, UTF-16 trigger params;
  `sandbox/census/census.py <save> --full` lists every unit with proto and position in INDEX order.
  Vanilla proto names come out right; mod protos come out unreliable (match by position and by "the only
  proto index that appears exactly N times"). Ground truth for indices and spawns.
- A screenshot: ground truth for RENDER only (a unit can be placed and never render: LF-only animfile).

### 3.2 The compiled rule shape (read it, do not guess it)

```
rule _Name
highFrequency
active | inactive
runImmediately
{
   bool bVar0 = (true);
   bool bVar1 = (<condition>);
   bool tempExp = (bVar0 && bVar1);
   if (tempExp)
   {
      trSetUnitIdleProcessing(true);
      <effects in order>
      trEventFire(4440);            // one "Fire Event" -> a numeric event, or
      xsEnableRule("_Target");      // the same effect compiled directly for some targets
      xsDisableRule("_Name");       // present when the trigger does NOT loop
      trEcho("Trigger disabling rule Name");
   }
}
```
plus `void eventHandler(int eventID=-1)` near the top that maps event ids to `xsEnableRule` calls, and
`void main(void)` first. Measured: `<profile>\Trigger\trigtemp.xs` of 2026-09-22 20:07 (243 rules,
292 `trEventFire`, 24 `trDelayedRuleActivation`). Function census of that file:
`trConvertUnitsInArea` 285, `trUnitSelectByID` 349, `trTechSetStatus` 113, `trSocketBuild` 52,
`trUnitConvert` 40, `trDisableTrigger` 32, `trUnitSuspendAction` 20, `trMinimapFlare` 8,
`trCounterAddTime` 2, `trCounterAbort` 2, `trTeamVictory` 2.

### 3.3 The index law (the most expensive fact of the project)

- A trigger parameter that names a unit takes the unit's scenario INDEX (placement order, the census
  order). Two compile shapes exist:
  - unit-typed params (`SrcObject` of Convert / Units Owned / Unit Action Suspend /
    Convert Units in Area, `NuggetObject` is NOT one of these): the trigger compiler resolves index to
    engine id at generation: `trUnitSelectClear(); trUnitSelectByID(223);` = resolved and alive;
    `trUnitSelect("262148");` = a select-by-NAME = dead, the value was not an index.
  - string-typed params, passed VERBATIM and resolved by the engine at run time from the same index:
    `trCountUnitsInArea("226",1,"TradingPost",8)` (Units in Area `DstObject`),
    `trSocketBuild(1, "281", "zpSPCCityTowerFlat")` (Socket Build `Socket`),
    `trNuggetCollectable("363")` (Nugget Is Collectable `NuggetObject`). Proven: fix B's guard indices
    363/368/373/378 locked all four harbours in game with exactly this shape.
- Where the index comes from:
  - `rmGetGroupingInstanceUnitByType(placement, proto) + instanceIdShift` (London 3, Istanbul 2,
    Paris 1, measured per map with four root copies of the map differing only in the constant).
  - a plain object-def unit: `rmGetUnitPlaced(def, 0) + instanceIdShift` (Istanbul's fortMark markers,
    `zpistanbulb.xs` around line 4205; Istanbul's individual shift equals its instance shift).
  - a socket docked on a trade route (`rmSetObjectDefTradeRouteID`): `rmGetUnitPlaced` returns an
    engine id in the 0x40000 pool (262146...) - unusable, no constant fixes it; use literal indices
    from a census and re-census after any change to what is placed before it.
  - several sockets of ONE proto in one grouping: `rmGetGroupingInstanceUnitByType` returns one unit;
    place the sockets LAST in the export and a `zpSPCWaterSpawnPoint` marker right after the grouping;
    sockets = marker index - 1 .. - n (`zpazteccity.xs` 624-631 and 1348-1351; London 13 block).
- Adding N units to any grouping placed EARLIER in the script shifts every later literal index by N
  (London 2026-09-22: the bridge gained two gate sockets and a marker, the guards moved +3).

### 3.4 Engine laws of trigger dynamics

1. `Fire Event` ENABLES the target rule; the target then waits for its own condition (next tick). A
   fired non-looping rule disables itself. `Timer ms` / `Timer` count from the rule's activation.
   Source: triggerdsl.py docstring and trigtemp.xs.
2. Ping-pong: two triggers that fire each other and whose conditions can hold at the same time re-fire
   every frame. Measured 2026-09-22: London's `Towers_ON1` <-> `Towers_ON2`, both `Team Unit Count
   zpSPCTowerOfLondon >= 1` for their team, with one Tower per team = a persistent minimap flare. Paris's
   `RoyalCourt_ON` (`zpparis.xs` 2322-2350) is safe only because one proto is one building with one
   owner. Rule: one-shot effects (flares, sounds, tech grants) belong in the per-player `Units Owned`
   conversion trigger, one event per capture (Bohemia's `CastleOn_Player` flares there too).
3. A team-count condition can never tell WHICH of two same-proto units a team holds.
4. `Socket Build` at run time is a placement: a LAND building on a bridge deck / over water places
   nothing, for gaia and for player 1 alike (three restarts, 2026-09-22). Built protos there are
   `<movementtype>air</movementtype>` (Venice's `deSPCCityTower` override in `zpvenicecity.mods.xml`,
   `zpAztecCityOutpost`, `zpSPCFixedGun`). AztecCity's proven order: convert the sockets to the builder
   first, build in the next trigger 10 ms later (`zpazteccity.xs` 1565-1690). No map in the mod builds
   for gaia; London builds for player 1 and converts to gaia in the same trigger.
5. The Bohemia gate rebuild: a unique invisible gate socket proto per gate under the gate, a transform
   tech per socket (`zpConverGate1..8`), fired once on capture when no gate of the owner stands within
   15 m, then a 500 ms deactivator; the transform consumes the socket (one rebuild per gate).
   `zpkingofbohemia.xs` 1906-2000, 2251-2269, 2388-2408.
6. Process-stale law: protomods, techtreemods, strings, commands, powers, abilities load ONCE at process
   start. Before blaming a trigger, compare `(Get-Process AoE3DE_s).StartTime` with the `.xml.xmb`
   mtimes. A `TechID` the running process cannot resolve drops that trigger at serialization and can
   derail the triggers after it: blocks that name new techs go LAST in the map.
7. `debugRandomMaps` in `Startup\user.cfg` freezes every generation after the next restart
   (memory `debugrandommaps-hangs-generation.md`). Never.
8. Trigger names: create with the string you look up (London uses underscores in both); a space in an
   `rmTriggerID` lookup works in the editor and fails in skirmish (nugget-targeting SKILL.md).
9. XS main scope has no block scope: a variable declared in a loop body or a bare loop variable shares
   `main`'s namespace; S6 catches double declarations, use-before-declaration and reserved words.

### 3.5 The user's testing doctrine

- Offline first, always: S6, the pytest pins, the simulator where it applies.
- ONE generation, requested from the user (or run by the driver only on the user's explicit word), then
  read `trigtemp.xs` and stop. Never play to find out. One falsifiable hypothesis per restart.
- A saved scenario + census when indices matter; the census is the only truth for mod protos.
- Map scripts are written LITERALLY (Istanbul's shape): no helper functions around placements or
  triggers, every trigger with its four `rmSetTrigger*` lines, ids derived in one block.
- Working files are frozen until the user names them.

## 4. Deliverable 1: skill `rm-trigger-testing`

Create `.claude/skills/rm-trigger-testing/SKILL.md`, `scripts/trigtemp_check.py`, `tests/`.

### 4.1 SKILL.md contents (in this order)

1. Frontmatter: `name: rm-trigger-testing`; `description:` one paragraph that starts with the trigger
   phrases ("trigger does not fire", "only the last one works", "persistent flare", "socket build
   places nothing", "read trigtemp", "test triggers offline") and states that the in-game step is
   user-requested only.
2. The first body line: "The game is generated ONLY when the user asks for it. Everything else here is
   offline."
3. The workflow ladder (offline S6 -> pins -> simulator -> one generation by the user -> trigtemp
   read -> census when indices matter), with the exact commands.
4. The artifacts table (3.1).
5. The compiled rule shape (3.2) and how to read it: ByID = alive, `trUnitSelect("...")` = dead, the
   string-typed params, the event handler.
6. The index law (3.3) as a checklist.
7. The dynamics laws (3.4), each with its measured source.
8. `trigtemp_check.py` usage and what each finding means.
9. What the existing simulator covers today and the agreed extension (runaway detector: after each
   scenario step the sim must reach quiescence within a few ticks, any rule firing repeatedly while the
   world is unchanged fails; golden snapshots of the parsed, unrolled trigger list for the verified
   families; a static Fire-Event cycle check). Mark the extension as NOT built.
10. "Not evidence": the RM dump for triggers, a screenshot for spawns, a shift constant for docked
    sockets, a generation in a process older than the XMBs.

### 4.2 `scripts/trigtemp_check.py` specification

- Python 3, standard library only. `python .claude/skills/rm-trigger-testing/scripts/trigtemp_check.py
  [path]`; default path = `<profile>\Trigger\trigtemp.xs` (build the profile path from the repo path:
  the repo sits under `<profile>\mods\local\<mod>`).
- Parse every `rule _Name ... {` block: name, `active`/`inactive`, whether the body contains
  `xsDisableRule("_Name")` (loop = false) or not (loop = true), the `bVar` condition expressions, the
  effect lines in order, the `trEventFire(n)` ids and `xsEnableRule` targets; parse `eventHandler` to
  map event ids to rule names.
- Findings (print one line each, `KIND rule detail`), exit 1 when any DEAD or CYCLE exists:
  - `DEAD`: `trUnitSelect("...")` inside a rule (an unresolved unit param).
  - `GAIABUILD`: `trSocketBuild(0, ...)` (never places).
  - `CYCLE`: a cycle in the Fire-Event graph (through `trEventFire` via the handler and `xsEnableRule`)
    whose rules' conditions are not provably exclusive. Exclusive: `trUnitIsOwnedBy(p)` after a
    `trUnitSelectByID(x)` with the same x and different p; a `trCountUnitsInArea` with the same
    arguments compared `>=` vs `==0`. Non-exclusive (report): `trPlayerUnitCountSpecific`/team counts,
    `trTechStatus*`, timers, `(true)`.
  - `ALWAYS`: a rule that is `active`, loops, and whose only condition is `(true)`.
  - `UNDEFINED`: an event id or `xsEnableRule` target with no rule.
  - `DISABLED-TARGET`: `trDisableTrigger(n)` whose event id maps to no rule.
- `--list` prints every rule with its state and its condition summary; `--rule NAME` prints one rule.
- Tests: `tests/fixtures/trigtemp_sample.xs` = a trimmed copy of the real file with (at least) the rules
  `_TowerSUnlock`, `_TowerConvS_Plr1`, `_TowerConvS_Plr2`, `_Bridge_ON_Plr1`, `_Bridge_OFF_Plr1`,
  `_BuildTowerS1_ON_Plr1`, `_BuildTowerS1_OFF_Plr1`, `_BridgeTowers_Setup0`, `_BridgeTowers_Setup1`,
  the matching `eventHandler` entries, plus a synthetic ping-pong pair (two active rules with
  `trPlayerUnitCountSpecific`-style conditions firing each other) and one rule with a dead
  `trUnitSelect("262148")`. `tests/test_trigtemp_check.py` asserts: the sample yields exactly the
  synthetic CYCLE and DEAD, no finding on the London rules, the loop detection, the handler mapping.
  Run: `python -m pytest .claude/skills/rm-trigger-testing/tests -q`.

## 5. Deliverable 2: `rm-census` becomes the universal observation skill

Edit `.claude/skills/rm-census/SKILL.md` (keep everything that is there and correct; restructure if
needed). Add:

1. The artifacts table (3.1) with one line per artifact: what it proves, where it lands, which script
   reads it.
2. The editor-controlled test sequence, MEASURED from the drivers (cite file and line numbers for every
   step): how the drivers recognise the main menu and the editor (pixel checks), open the Scenario
   Editor, pick the map in the Type dropdown (`--peek` and `--nav down,row` in `bench_run.py`), set the
   seed, generate, watch the load bar, save the scenario (Save As name and where the copy lands), where
   screenshots and the trigtemp copy land (`sandbox/census/samples/...`), how a playtest is started from
   the editor and how it is ended and the editor or main menu regained, and every guard: the foreground
   check (`london_gen_safe.py` exits 3 without a click when the editor is not in front), the "kill only
   on the user's word" rule of `editor_regen.py` and the `game-startup` skill, "do not touch the mouse
   for ~60 s" of `bench_run.py`. If a step (for example ending a playtest) is not in any driver, write
   "not measured, no driver does it" - do not invent it.
3. The rule that these drivers run ONLY on the user's explicit request in that session, never as a
   default step.
4. The census reading rules (3.1, mod protos, the five-apart guardian pattern, index = placement order).

### 5.1 Monitor independence: `sandbox/census/gamewin.py`

The drivers use absolute screen pixels. Add a helper module (Write tool) and refactor the drivers to
use it, behaviour otherwise identical:

- Find the game window: read the exact title / class string the drivers already use (grep them for
  `FindWindow`, `pygetwindow`, `pyautogui`, `win32gui`, `title`); reuse the same dependency, add none.
- `window_rect() -> (left, top, right, bottom)` via `ctypes.windll.user32` (`FindWindowW`,
  `GetWindowRect`, `GetForegroundWindow`) if no wrapper library is already imported.
- `monitor_of(rect)`: which monitor the window sits on (`MonitorFromRect` + `GetMonitorInfoW`), with
  the monitor's rect, so a log line can say "window on monitor 2 at (x, y, w, h)".
- `to_screen(nx, ny, rect) -> (x, y)`: normalised 0..1 window coordinates to screen pixels; pure
  function, unit-tested. `from_screen` the inverse.
- `is_foreground()`.
- Every driver gets `--dry-run`: print the window rect, the monitor, and every click/key it WOULD
  perform with both normalised and pixel coordinates; perform no input event. When the window is not
  found, print that and exit 2 without any input event.
- Convert each hard-coded pixel position in the drivers into a normalised pair derived from the
  resolution the driver was written for (state that resolution and the derivation in a comment per
  position; if a driver's resolution cannot be established from its code or samples, say so and leave
  that driver's numbers untouched).
- Tests: `sandbox/census/tests/test_gamewin.py` for the pure functions (no window needed).

## 6. Out of scope (do not start them)

- The simulator extension in `scripts/mapcheck/triggerdsl.py` (runaway detector, goldens, London's
  vocabulary). Describe it in the skill as the agreed next step.
- Any map or data change. Any in-game run. Any change to `nugget-targeting` beyond a one-line pointer
  to the new skill (allowed, optional).

## 7. Verification before you report

- `python -m pytest .claude/skills/rm-trigger-testing/tests sandbox/census/tests
  scripts/mapcheck/tests/test_xs_scope.py -q` green.
- `python .claude/skills/rm-trigger-testing/scripts/trigtemp_check.py` against the real
  `<profile>\Trigger\trigtemp.xs` runs and reports (read-only). Include its findings in the report.
- Every path and line number you cite exists (re-read before citing).
- Two commits, one per deliverable, explicit paths only.

## 8. Report format (the last message of your session)

1. Files written or changed, one line each.
2. Test counts per suite.
3. The editor-controlled sequence, step by step, each with `file:line`.
4. The findings of `trigtemp_check.py` on the real file.
5. What you could not verify, and anything in the drivers that contradicts section 3.
6. Nothing else. No praise, no summary of this brief.
