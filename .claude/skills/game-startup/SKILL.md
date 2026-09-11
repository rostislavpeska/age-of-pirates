---
name: game-startup
description: Start Age of Empires III DE for automated testing - Steam launch, intro-video skip, home-menu recognition, and the crash-relaunch policy. Triggers on "start the game", "game crashed, restart", "renew the game", "launch AoE3", "is the game up".
---

# Starting the game for automated testing

## The policy first

Killing `AoE3DE_s.exe` is FORBIDDEN, always. LAUNCHING is allowed in exactly
two cases (user amendment 2026-08-25): a direct user instruction, or the
driver's explicit `--allow-restart` flag. Default automation without the
flag stops and waits for a human.

## Manual / agent-driven startup sequence

1. **Launch**: `powershell -NoProfile -Command "Start-Process 'steam://rungameid/933110'"`
   (never the exe directly - Steam owns the session). The process appears in
   ~10-30 s; full boot to the main menu takes ~60-100 s.
2. **Skip the intro videos**: 2-3 Esc taps a couple of seconds apart while
   booting - `python scripts/aitest/probe.py key esc`. Harmless if the menu
   is already up.
3. **Recognize "up"** - two layers:
   - process: `tasklist /FI "IMAGENAME eq AoE3DE_s.exe"`
   - home menu: probe the active coordinate sheet's `home_skirmish` point
     (`python scripts/aitest/probe.py pixel <x> <y>` vs its `rgb`, tolerance
     +-30/channel). The sheet comes from `scripts/aitest/coords/` selected by
     the gitignored `whichsheet.json` - see the **ui-calibrate** skill.
   Wait pattern: background `until tasklist | grep -qi aoe3; do sleep 5; done`
   then a settle sleep, then the pixel probe.
4. **Wrong screen after boot** (Tools submenu after a mod reload, etc.):
   screenshot first (`probe.py shot`), identify, then one targeted click
   (e.g. the Back button) - never blind clicking.
5. The mod loads automatically with the profile. A mod reload in the Mods
   panel re-reads compiled data (fresh .xmb needed - Resource Manager);
   art/xml changes need this full process restart, AI .xs never does.

## In the driver

`python scripts/aitest/driver.py --runs N --cap-min M [--record] [--allow-restart]`
- with `--allow-restart`: a dead game (before a run, or the GAME-CRASHED
  verdict mid-batch) is relaunched via the Steam URL, the driver waits up to
  240 s for the home probe, and the batch continues. Crash dumps (BugSplat's
  are in `%LOCALAPPDATA%\Temp\AoE3DE_s*.dmp`, LocalDumps' - if armed - in
  `Games\Age of Empires 3 DE\CrashDumps`) are read with
  `python scripts/aitest/crashdump_triage.py`.
- without it: the driver stops and reports; the human restarts.
