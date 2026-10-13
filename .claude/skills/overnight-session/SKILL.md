---
name: overnight-session
description: Rules for an owner-authorized overnight (unattended) run - invoke when the owner says "start overnight session" (or /overnight-session). Pre-flight checklist (screen saver, power, budget, scope), the run rules (deadline, caps, no GUI, quiet heartbeat, notes, no repeats), and the morning handoff. Overnight runs are allowed ONLY through this skill.
---

# Overnight session

The owner leaves the machine running unattended. Collected from the practice that already worked in this project
(korean-buildings-blender `research/*/OVERNIGHT.md` and `MORNING_REVIEW.md`, Construction_13, Colonial_Military_12,
Colonial_Roof_Rollout_22), the screen-saver facts in `lobby-minimap` and `aoe3-cheats`, and the 2026-10-12 token audit.
Overnight work is allowed ONLY when the owner says "start overnight session"; otherwise the standing rule holds: never
launch overnight or long-running agents on your own.

## 1. Pre-flight (before the owner leaves; ask, do not assume)

- **Screen saver / display:** the owner's OLED laptop starts a pixel-refresh screen saver after about 30 min idle. It
  swallows every click and key (PrintWindow captures still work); the Windows keep-awake API cannot stop it, and ending
  it by script needs the owner's explicit yes. So: the owner turns the screen saver off for the night, or the run does
  no GUI driving at all. With the display off, desktop captures come back blank (memory: remote owner = no game screen).
- **Power:** on mains power; the system must not sleep (the desktop app's keep-awake setting prevents system sleep, not
  the screen saver).
- **Scope in writing:** the brief names the goal, what is FROZEN (e.g. geometry, UVs, budgets), what is allowed, the work
  mode (production / exploration with its question and stop rule / harness maintenance) and the deadline (default 07:00
  Europe/Prague).
- **Budget:** a hard token or agent budget for the night, stated by the owner; the coordinator restarts from a written
  handoff at its context threshold: 250 k tokens (owner 2026-10-12: "250k", night runs only).
- **Other sessions:** list the sessions that stay active; one owner per task and file area (no shared checkout writes).

## 2. The task list is the contract (owner 2026-10-12: "the night agent must very precisly follow the task list")

- Before leaving, the owner marks the night's tasks in the project's task list (STATE.md / backlog) - each row with its
  id, his words, the acceptance evidence and the order. Nothing unmarked is worked on.
- Work the marked tasks in his order, one at a time; a task is done only with the evidence its row asks for.
- Write every status change to the list at once (started, checkpoint, done, blocked + what unblocks it), so the
  morning view is the list itself.
- No new tasks, no scope growth, no "while I am here" fixes: anything discovered goes to the list as a new row marked
  `found overnight - for the owner`, untouched.
- A blocked task is marked blocked with its reason and the run moves to the next marked task; if none is left, stop
  early and write the morning report. Finishing early is fine; inventing work is not.

### Dependency-scoped blockers and pause check

Owner correction, 13 October 2026: a failed stage blocks only its named consumers.
Record the artifact/stage, reason, evidence and exact unblock condition. Inspect
the rest of the authorized queue; continue independent useful work. Avoiding
empty polling is not a reason to stop useful work. Keep this review in the
existing task STATUS.json as `pause_review`, not a separate task database.

Before pausing for lack of useful work, run
`python scripts/pause_gate.py --status <existing-STATUS.json>` from this skill.
The review contains `reviewed_at` (UTC ISO), `expected_task_ids` copied from the
current authorized queue, and `tasks` rows with `id`, `state` and `evidence`.
Allowed states: `done`, `blocked`, `ready`, `running`. A blocked row also names
`blocked_stage`, `reason`, `unblocks`. Unknown/missing/duplicate rows or a review
older than 15 minutes refuse the pause. Exit 0 means every listed task is done
or explicitly blocked; exit 2 identifies runnable work or invalid accounting.

This is a precondition the coordinator runs, not an interceptor of the app API.
It cannot independently discover omitted tasks: reconcile `expected_task_ids`
against the authoritative queue first. Explicit owner stop and a real deadline
remain separate reasons to pause; never relabel useful work blocked to pass.

## 3. During the run

- One overnight job per project (one root + one worker at most; the two-job launch cap counts every session).
  Resume the same run after an interruption; never a duplicate launch.
- Background Blender only (`-b --factory-startup`); no game launch, no GUI, no screen control; live Blender only if
  the owner left it running for this run, with one bounded watch.
- Read unread owner notes at every step start and say which were applied.
- Do not repeat completed work; consume earlier evidence. Stop a failed hypothesis promptly; a new experiment needs a
  measured upside, one specimen and one revision.
- Agents capped (about 100 calls, 60 when exploring) with file handoffs; builders self-check before a verifier runs.
- No paid external calls (image harness, generators, downloads) unless the brief authorizes them; count every one.
- Write status to the project's `OVERNIGHT.md` at each checkpoint (time, what changed, pictures, next). A heartbeat
  wakes only to do work: no wake-ups that restate an unchanged status.

## 4. At the deadline or on completion

- Save a truthful WIP handoff: exact files, hashes, pictures, what passed, every unmet requirement, paid calls (count).
- Write the morning report (`MORNING_REVIEW.md` style): outcome, choices for the owner, bottleneck, next step.
- Never report "fully tested": the owner runs the first game test in the morning.
- Pause the heartbeat / automation, release claims, update the task list, commit only your own work.
