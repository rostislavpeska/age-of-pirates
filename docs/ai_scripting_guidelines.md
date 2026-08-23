# AI scripting guidelines (basic)

Working rules for editing `game/ai/` in this mod, distilled from the Istanbul
landing campaign (2026-08) where each one was proven the expensive way, plus
the two reference sources below. Every claim here was verified in game or in
the engine's own dumps — extend this file only with verified material.

## The reference sources — where to look things up

1. **AOE3 AI Scripting Guide** (alistairJah / aoe3mc) — cloned locally at
   `references/ai-guide/` (site: https://aoe3mc.github.io/ai-guide/).
   Per-function reference pages under `docs/ai/**/functions/*.md` — one file
   per syscall (e.g. `kbCanPath2.md`), plus XS-language chapters. First stop
   for "what does this engine call actually do".
2. **Enhanced AI by EsteGringo** — subscribed mod on disk at
   `../../subscribed/209052_enhanced ai/game/ai/` (path relative to this
   mod's root; author confirmed in its readme). Written by a professional
   programmer: cleaner structure than AssertiveWall, which grew by trial and
   error. Slightly weaker naval combat, much better reading. Especially:
   `core/ainavalinvasion.xs` (a complete landing module),
   `core/ainavalutilities.xs`, `core/ainavalnew.xs`, and the `*new.xs`
   rewrites of economy/military.
3. **The engine's own API dump** — `generateAIConstants` in `user.cfg` writes
   `Logs/Age3DEAIConstantsPlayer<N>.txt` (~648 KB): every syscall signature
   and doc string, every generated constant, for THIS build. Authoritative
   over any guide when they disagree.

Lookup order when stuck: engine dump (does the call exist, exact signature)
→ ai-guide (semantics, examples) → Enhanced AI (a clean working usage)
→ AssertiveWall in-repo (how OUR fork actually behaves).

## Hard-won rules (each cost a debugging session)

1. **`createSimpleUnitQuery` returns ONE SHARED query object**
   (`aiutilities.xs:777`, `static int`). Never interleave two simple queries:
   read or CACHE the first query's results before creating the second.
   Violating this made every lighthouse marker filter itself out (distance 0
   to "a fort" that was actually itself).
2. **Units obey their plan, not your task.** A bare `aiTaskUnit*` on a unit
   owned by a stock plan is overwritten within seconds (managers re-task on a
   0.3–10 s cadence). To *use* units: put them in a `cPlanReserve` with
   `aiPlanSetDesiredPriority` ≥ the thieves (army 99, transport 100 — stock's
   own numbers), and **re-issue orders every pass** from a minInterval-3 rule.
   Boarding went 0/12 → 6/8 on exactly this change.
3. **Destroy plans on every exit path.** A leaked priority-100 reserve starves
   every other naval rule forever. One reset helper, called from every
   return.
4. **The engine fails silently.** No error strings exist for failed
   enter/garrison/landing tasks (verified against the binary). If a mechanism
   can fail, it must echo its own failure — nothing else will.
5. **RM constants are not AI constants.** `cNumberNonGaiaPlayers` is
   RM-script-only; the AI uses `cNumberPlayers` (index 0 = gaia). A wrong
   symbol is a compile error dialog naming the line — the game tells you.
6. **`cUnitType<ProtoName>` constants are generated per proto** — any proto in
   protomods works, no registration needed.
7. **The KB is not the world.** `kbArea*`/`kbAreaGroup*` are the AI's belief,
   computed at load, with measured holes on Istanbul. `kbCanPath2(pointA,
   pointB, protoUnitTypeID, range)` asks the real pathfinder. For anything
   load-bearing, prefer ground truth or test both and echo disagreements.
8. **Detect maps by OBJECT, not name** (`getGaiaUnitCount(cUnitType...)` in
   the setup rule) — maps ship under multiple filenames.
9. **Echo discipline**: every rule that can refuse must say why (throttled
   heartbeat), every phase transition must log a counted line
   (`sailing, 6/8 aboard`). `Age3Log.txt` streams echoes LIVE with `P#N`
   prefixes when `showAiEchoes` is set — that is the debugging channel.
   Per-player `Age3DEAIOutputPlayer<N>.txt` flushes on match exit.
10. **Test-mode knob**: gate thresholds behind one `bool g...TestMode` so a
    test game exercises the target mechanism in minutes. Flip to `false` for
    release. (`gIstanbulLandTestMode` is the template.)
11. **Both AI trees must move in lockstep**: `game/ai/core/` and
    `game/ai/coreDLC/` — every edit lands in both; they are CRLF.
12. **House loop idioms**: `for (i = 0; < n)` implicit loop vars; `break` and
    `continue` exist; no ternary; declare-before-use within the file (helpers
    above the rules that call them).

## The development loop

Run game → test → quit → analyze → look up (sources above) → edit → repeat.
The automated harness (`scripts/aitest/`) runs the first four steps
unattended: `driver.py --runs N` navigates the lobby, watches the live log to
a verdict, archives per-run logs to `runs/run_NNN/` + `results.csv`, and
quits gracefully (which flushes the per-player AI logs). See
`scripts/aitest/NAVIGATION.md`.
