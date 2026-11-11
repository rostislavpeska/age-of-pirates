# Findings of the London AI campaign, 2026-09-23/24 (runs 15-27)

This file condenses the campaign. Its sources are `docs/briefs/2026-09-23-london-ai-plan.md` (the plan),
`docs/briefs/2026-09-23-london-ai-test-report.md` (every run) and `docs/briefs/2026-09-23-ai-issues-log.md` (I1-I13).

## What works on London (kept, owner-approved)

| Piece | Evidence |
|---|---|
| detection by the player's own marker, and the setup (socket, bridge gates, near / far Keep) | L0 / L1 in every run from 15 to 26 |
| the war plan holds the stock attack while a bridge gate stands and releases it once both are down or ours | L4; released about 13:00 |
| the gate killer: the near Keep's gates, then the bridge gates, then the far Keep's gates | L5; the near gate down by 7-9 minutes |
| the Keep capture (the killer reserve standing at the gate takes the flag) and the garrison at 101 | L7 / L8; run 17: the AI took both Keeps and won |
| economic buildings in the countryside behind the team's wall gates, spread over all gates | run 19 (fields placed), run 23 (countryside failures 27+27 down to 0-4, Mills appear) |
| base growth over the river, the hills and the countryside KB group, 120 m cap | run 20: bases 40-70 m grew to 100-120 m |
| the forward base at the enemy bridgehead once the crossing is open | owner 2026-09-24; not yet measured |

## What was reverted, and why

| Change | Runs | Why it was wrong |
|---|---|---|
| the stock Trading Post rule skips the bridge post and far-bank sockets | 22-26 | **gameplay**: the bridge and every post must be contested; the failure count fell because the AI stopped trying (I13, heavy violation) |
| towers at the wall gates | 24-26 | **gameplay**: London's walls are decorative, the battle is inside the city |
| no forward base on London | 26 | **gameplay**: the forward base is situational; the owner wants it next to the bridge |
| military buildings to the base's back | 25 | no gain, and new "can't path" failures: the base's back reaches behind the wall hills |

Runs 22-26 are contaminated for any TOTAL failure figure: the socket filter was active. Per-building-type figures
of the kept pieces (fields, base growth) stay valid.

## Engine and knowledge-base facts (measured)

1. **`kbCanPath2` ignores gates.** It returned 1 across two standing gaia bridge gates (run 15).
2. **Area groups do not follow gates.** The knowledge base joins both London banks through the bridge deck (group
   2), and the countryside behind the city wall is its own land group (5/6/7).
3. **`kbAreaCalculate()` changed nothing** on London.
4. **Main base growth** happens only in `buildingPlacementFailedHandler`:
   - the base starts at 40 m (`aisetup.xs` 2664) and grows 20 m, at most every 40 s;
   - it freezes forever once any area of another group is in range;
   - `xsArraySetInt(basesToAvoid, baseID)` misses its index argument, so the memory of a frozen base never works.
5. **Stock behaviour on vanilla Amazonia** (run 18): the base stays at 40 m, with about 48 placement failures per
   10 minutes, mostly Town Centers. The freeze is stock behaviour, not a London defect.
6. **The Town Center search** covers 50 m around the base or a mine, avoiding 40 m around any TC, and retries
   endlessly.
7. **Towers use a fixed ring** about 31 m around the base centre with a ~15 m search.
8. **Forward buildings** are placed at `selectForwardBaseLocation()`, halfway along the line from our base to the
   enemy TC. Both `forwardTowerBaseManager` and the forward military plans use it.
9. **An AI resignation offer** is a modal dialog that pauses the game (run 24).
10. **Per-player logs** are UTF-16 and flush only on a menu quit. The engine's BuildPlan echoes have no newline.
11. **Game speed Fast:** 30 minutes of cap is about 45-55 minutes of game time.

## Harness facts (the driver, the screen at 2880x1800)

- **The map picker** keeps its search text and filters only on open. Clearing the box shows the category grid,
  whose first tile is "All Maps" (random).
- **The home menu** gained a Continue button, which shifted every button. Home is now two pixels (Skirmish and Exit).
- **The in-game cog menus differ:**
  - live: Photo Mode, Tech Tree, Save, Load, Restart, Options, Resign, Quit (Quit at y 615);
  - post-match: View Postgame, Restart, Photo Mode, Options, Quit (Quit at y 414, where the live menu has Restart).
- **Button left edges are a gradient:** x 2460 = (48,19,9), 2500 = (68,29,14), plateau (81,34,17) from 2560. Measure
  a probe where it will sit; never shift it unmeasured.
- **A dialog's OK button moves with its text length.** The Yes/No dialogs share Yes (1139,1008) and No (1740,1008);
  the left-edge signature is (960,1008) = (70,29,14) and (1540,1008) = (63,26,13).
- **The first click after a focus change is eaten.**

## Process lessons

- **The owner's intent beats the metric.** A metric that improves because the AI does less is a regression (I13).
- **Name every change in the report before running it,** with the approval it rests on.
- **One hypothesis per run** made the bad "back" change cleanly revertible. Mixing would have hidden it.
- **Stop when the requirement is met;** propose the rest.
- **Anything that can pause, stop or confuse the harness is logged** as an I-entry with a guard. Twelve of the
  thirteen issues were harness or process, not AI.
