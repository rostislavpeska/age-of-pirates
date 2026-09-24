---
name: ai-edit
description: The entry point for ANY change under game/ai (the XS AI scripts) - the owner's approval gate for gameplay-scope changes (what the AI contests - sockets, Trading Posts, natives, bridges, objectives, forward bases, targets, defences), the done-rule (stop when the requirement is met), how the AI's rules fit together, the compile order and declare-before-use, the map-specific guard pattern (gIsLondon) and its validation tests, the XS constructs the engine rejected, the automated in-game test process (driver, criteria, one hypothesis per run, report) and the findings of the London campaign, with the AOE3 AI Scripting Guide as the reference. Use before editing aipiraterules.xs, aibuildings.xs, aiglobals.xs or any core AI file, before an AI test run, and when reading AI per-player logs. Triggers on "AI", "aipiraterules", "the AI does not", "AI builds", "AI attacks", "AI test", "night run", "placement failed", "xs error", "compile error dialog".
---

# ai-edit: change the AI without changing the game

| Read | When |
|---|---|
| this page | always, first |
| [references/rules-puzzle.md](references/rules-puzzle.md) | before adding a rule or touching a stock rule's switch: the families, handlers, plan priorities and the London chain |
| [references/test-environment.md](references/test-environment.md) | setting up a device / session: user.cfg, crash dumps, screen, coordinate sheet, lobby (with the **game-startup** and **ui-calibrate** skills) |
| [references/testing-process.md](references/testing-process.md) | before and during any in-game test: the phases, the driver, the rules of the cycle |
| [references/criteria.md](references/criteria.md) | every success criterion, the echo line it reads, its bound; judging a run from the logs; adding a criterion |
| [references/validation-tests.md](references/validation-tests.md) | before every commit, and when adding a test or lint |
| [references/findings-2026-09.md](references/findings-2026-09.md) | before any London work: what works, what was reverted and why, engine and harness facts |
| `docs/ai_scripting_guidelines.md` | the 13 hard-won rules (shared query object, plan priorities, silent engine failures, echo discipline ...) |

## 0. The gate, before anything else (AGENTS.md hard rule 7, guidelines rule 13)

**What the AI contests is the owner's decision, not yours.** That covers:
- sockets and Trading Posts (a bridge post, every native, the far bank included);
- objectives, bridges and forward bases;
- targets, and where defences stand.

A change to any of them is a **proposal in the report, never a commit**. On the night of 2026-09-23/24 an agent made
the stock Trading Post rule skip London's bridge post and far-bank sockets, put towers at the decorative wall gates,
and switched the forward base off. The failure metric improved because the AI did less. The owner called it a heavy
violation; everything was reverted, and 5 runs were lost.

- **Ask one question of every change:** does it change what the AI fights over, or only how it executes what it
  already wants? Only the second kind is yours to ship.
- **A metric that improves because the AI does less is a regression.** Read a failure as the AI trying.
- **Enforced by tests:**
  - `APPROVED_LONDON_CODE` lists the only functions where London code may live, each with the owner's quote. Adding
    one is the approval step: ask first.
  - `test_contested_decisions_carry_no_london_branch` keeps the deciding rules free of map branches.
- **Map design facts:** read the map's memory and brief first. London: the city is the battlefield, the walls are
  decorative, and the bridge and every Trading Post are claimed normally.

## 1. The done-rule

When the owner's requirement is met and its criteria pass on two consecutive runs: **stop**.
- Report, and list the further ideas as proposals.
- Add nothing else: no "while we're here", no chasing a lower number on a metric nobody asked to minimise.

Every unrequested change risks a working state. The night's toxic changes were made after the requirement was met.

## 2. Where the code compiles

- **`game/ai/core/`** is what the game compiles. The map build echo (`LONDON p<N> build r<k>`) proves it at every
  match start. `coreDLC/` is not in lockstep; that is an open owner decision.
- **The include order is `aicore.xs` 90-104:** globals, utilities, buildorders, waterrules, assertivewall,
  buildings, techs, exploration, economy, military, hccards, chats, **pirate rules**, archipelago, setup.
- **XS resolves names in file order.** A global that an earlier file needs goes into `aiglobals.xs`, declared once
  (tested).
- **A `mutable` stub in `aicore.xs`** plus the real body later is the core's forward declaration. Any other double
  definition is an error.
- **AI files are CRLF.** Write them through a script that converts, and check with `file`.

## 3. The map-specific pattern

- **Detection by object, never by name.** The player's own marker (`zpAILondonBridge`) sets `gIsLondon` in
  `initializePirateRules`.
- **Guards:** every helper starts with `if (gIsLondon == false) { return (...); }`, and every hook in a stock
  function sits inside `if (gIsLondon == true) { ... }`. Both are tested.
- **Hooks change HOW, not WHAT:** a place, a search radius, a growth limit.
- **Every rule echoes its refusals** (throttled) and its phase changes with counts. Use one vocabulary per map
  (`LONDONWAR`, `LONDONGATE`, `LONDONKEEP`, `LONDONHOLD`, `LONDONPLACE`).
- **Test knobs** go behind `gLondonTestMode`. The echo-only `aiTestDiag` goes behind `gAITestDiag`. Both must be
  `false` for release.

## 4. XS: what the engine rejected, and the reference

**Rejected in game (every AI dies, a modal dialog appears):**
- `if ((xsVectorGetZ(a) - xsVectorGetZ(b)) * side < (...) * side + 20.0)` gave Error 0308 / 0135. The exact trigger
  is not isolated; write plain steps into locals. It is linted.

**Guide rules, linted:**
- no local variable named like a function or rule;
- no `scalar * vector` (write `vector * scalar`);
- no double definition without a `mutable` stub;
- no ternary.

**Avoided out of caution:** concatenating a `bool` or `long` into a string. Assign to an `int` first.

**Queries:** `createSimpleUnitQuery` is ONE shared object, so read or cache its results before the next query.

**Reference, in lookup order:**
1. The engine's own dump: `generateAIConstants` in `user.cfg` writes `Logs\Age3DEAIConstantsPlayer<N>.txt` (every
   syscall and constant of THIS build; authoritative). Remove the line again afterwards.
2. The **AOE3 AI Scripting Guide** (alistairJah / aoe3mc), cloned at `references/ai-guide/`:
   - site: https://aoe3mc.github.io/ai-guide/ (XS language: https://aoe3mc.github.io/ai-guide/xs/);
   - repo: https://github.com/aoe3mc/ai-guide;
   - one page per syscall under `docs/ai/**/functions/`.
3. **Enhanced AI** (EsteGringo), `../../subscribed/209052_enhanced ai/game/ai/`: clean, working usage.
4. The in-repo AssertiveWall fork: how OUR AI actually behaves.

## 5. Before a commit, before a match

    python -m pytest scripts/aitest/tests -q        # 68 tests, about 2 s; red = no commit, no match

Then follow the automated test process ([references/testing-process.md](references/testing-process.md)):
- the floor on a standard map;
- the map's rounds, 30 minutes each, one hypothesis per run, two consecutive passes;
- a regression run on a standard map;
- the report and the issues log.

The game belongs to the owner: never kill it, and launch it only on the owner's word. Never edit `game/ai` while a
match loads.
