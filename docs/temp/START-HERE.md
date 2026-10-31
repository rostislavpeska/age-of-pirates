# Handoff to a fresh Claude agent: AoE3 DE legacy unloading capture

## Your assignment

Work on this Windows device to collect a **working legacy Age of Empires III: Definitive Edition installation**, its matching data, and a reproducible ship-unloading example. Another agent will compare these files with the current game. Do the work and produce the capture package; do not merely propose a plan.

The user reports that ships could unload units onto land above coastal cliffs in an older build, but cannot in the current build. Both automatic and manual unloading are affected according to the user. This has not yet been verified in a controlled old/new scenario.

The button's XML is:

```xml
<protounitcommand>
  <name>Eject</name>
  <icon>resources\images\icons\command\garrison_out.png</icon>
  <command>uiEjectGarrisonedUnits autoScout(false)</command>
  <rollovertextid>36839</rollovertextid>
</protounitcommand>
```

Those are two commands. `autoScout(false)` is not an argument of `uiEjectGarrisonedUnits`. A separate callback, `uiEjectAtPointer`, handles a clicked destination. Investigate gameplay behavior without assuming the XML is the cause.

## What has already been learned on the other device

- Historical EXE supplied: version **100.19.17293.0**, size **57,840,440 bytes**, SHA-256 `e7681a5738bbb2dc76dea26a034381cc6b0010f3d22a9434ae489e736712e0d9`.
- Current EXE: version **100.19.18309.0**, size **59,943,224 bytes**, SHA-256 `a3fcaa23f57ffcfe5fb799e2b19f89560793784c73aded74747d955c95a4c625`.
- On-disk code was not directly useful for disassembly. Reading the loaded main module produced readable native code.
- Both old and current loaded-code snapshots were captured. The historical EXE subsequently crashed during startup in the current installation. The cause of that crash was not established. **Do not repeat the executable swap.** The current installation on the other device was restored and its SHA-256 verified.
- The missing evidence is a working legacy runtime with **matching legacy data**, active mods, and a controlled successful cliff-unloading case. A fresh runtime snapshot from that working installation will also verify the earlier capture.
- The eject callback, command execution, action, cargo ejection, and position-search routines have been linked. Their major branch structures largely match between builds, with many structure-offset changes. A deeper path/obstruction helper changed, but no change has yet been proven to cause the regression.
- The mod involved on the other device is `age-of-pirates`, under the user's AoE3 profile `mods\local` directory. Do not assume it is present here or that this device uses the same drive or profile ID.

## Non-negotiable operating constraints

1. **The legacy game must be started with the device disconnected from the internet.** The user's chosen workflow is: prepare with Claude, disconnect, start the game offline, reconnect, and continue in this same Claude thread while the game remains running. Keep Steam in Offline Mode and do not restart or update the game on reconnection. Record this accurately as offline startup followed by reconnected capture; Steam Offline Mode alone does not establish that the game has no network access after reconnection.
2. Keep the legacy EXE and its installed data together. Do not update the game, verify files through Steam, reinstall it, replace its EXE, or modify Steam manifests.
3. Do not patch game binaries, inject code, write process memory, change ACLs, disable protection software, or install kernel drivers. The supplied collector uses query/read-only process access.
4. Do not force-kill the game. Close through its menu if necessary. Preserve existing saves and settings. Save any test as a new named scenario/save.
5. Do not transmit captures or crash reports automatically. Save locally, then return the package through the user's chosen transfer method after testing.
6. If Steam requires going online or updating before it can launch, stop that attempt and report it. Do not sacrifice the preserved legacy installation to complete the capture.

## Included tool

`capture_legacy.py` requires **64-bit Python 3 on Windows**, with no third-party packages. It does not launch anything and does not use the network. It:

- Locates a running `AoE3DE_s.exe`, or waits for it; rejects ambiguity unless `--pid` is supplied.
- Reads only the main EXE's headers, executable sections, `.rdata`, `.pdata`, and `_RDATA`.
- Saves an RVA-indexed image of `SizeOfImage` bytes. Uncaptured sections are zero-filled. **This is an analysis image, not a runnable EXE or a full process dump.**
- Records actual module base, process path, hashes, section ranges, and unreadable pages.
- Copies the actual running EXE from disk, inventories installed `.bar` archives, optionally copies `Data.bar` and `ArtTerrain.bar`, and copies the Steam app manifest when found.
- Creates only a new output folder; refuses to overwrite an existing capture directory.

## Step 1: establish the local paths and readiness

Read this handoff and inspect the collector. Locate 64-bit Python and the preserved legacy installation. The usual game location is `C:\Program Files (x86)\Steam\steamapps\common\AoE3DE`, but do not assume it.

Run from the extracted kit directory in PowerShell:

```powershell
py -3 -c "import sys,struct; print(sys.executable); print(struct.calcsize('P')*8)"
py -3 .\capture_legacy.py --help
```

The first command must print `64`. If `py` is missing, locate an existing 64-bit `python.exe` and substitute its full path using PowerShell's `&` call operator. If Python is not installed, arrange it before disconnecting; do not begin an offline procedure with missing dependencies.

Record the executable's file version and SHA-256 before launch using the actual path:

```powershell
$legacyExe = 'REPLACE_WITH_ACTUAL_FULL_PATH_TO_AoE3DE_s.exe'
(Get-Item -LiteralPath $legacyExe).VersionInfo | Select-Object FileVersion, ProductVersion
Get-FileHash -LiteralPath $legacyExe -Algorithm SHA256 | Format-List
```

If this is a different historical build, record it exactly and continue if the user identifies it as a working legacy version. Do not label it 17293 merely because this handoff mentions that version.

## Step 2: choose one capture timing

### A. The game is already running offline

Leave it running. Reach its main menu or pause the relevant test. Use the actual displayed/file version in place of the example version below:

```powershell
py -3 .\capture_legacy.py --out .\capture\menu --version 100.19.17293.0 --copy-data
```

If multiple games are found, identify the intended process and add `--pid 12345` with its actual PID. Do not close an unrelated process.

### B. Required pause-and-resume workflow when the game is not started

**Give the user control of the timing.** Prepare and validate the script and paths first. Then end your response with: "Ready. Disconnect from the internet, start the legacy game through Steam Offline Mode, and wait for its main menu. Then reconnect without closing the game or taking Steam online, and reply 'game started, continue' here. I will resume in this same thread."

Do not start the game yourself, set a countdown, assume readiness after a delay, or keep issuing tool calls while waiting for that reply. Do not create a new thread. After the user replies, locate the already-running process, recheck its executable version/hash, and use procedure A. Never relaunch it just because your agent connection was interrupted.

The user may optionally prefer to collect while fully disconnected. Only in that case prepare the following waiting command; it runs independently of Claude:

Before disconnecting, prepare this command and leave the terminal available. It can be started before the game; it waits up to 15 minutes:

```powershell
py -3 .\capture_legacy.py --out .\capture\menu --version 100.19.17293.0 --wait 900 --prompt --copy-data
```

Then:

1. The user disconnects the device from the internet and keeps it disconnected throughout game startup.
2. Start Steam in Offline Mode and launch the preserved game through Steam. Decline any update requirement by abandoning that attempt, not by updating.
3. Wait for the game's main menu. Switch to the collector terminal and press Enter when prompted.
4. Let the collector finish. Claude does not need to remain connected or running for this. The user can then reconnect and reply in this same thread; inspect the existing capture and continue without restarting the game.

If the game exits before capture, the collector should report a failure. Do not silently substitute files from another installation.

## Step 3: verify the capture locally

`capture\menu\legacy.json` must have:

- The correct game path and actual PID/module base.
- The expected historical disk SHA-256, or a clearly documented different legacy version.
- `read_failures: []`. A partial capture is useful, but must be labeled partial; do not call it complete.
- `legacy.mapped.bin` length equal to its `size` field. For the known 17293 EXE this is **60,825,600 bytes**.

Run:

```powershell
$captureMeta = Get-Content -LiteralPath .\capture\menu\legacy.json -Raw | ConvertFrom-Json
$captureMeta | Select-Object reported_version, path, base_hex, size, disk_sha256
@($captureMeta.read_failures).Count
(Get-Item -LiteralPath .\capture\menu\legacy.mapped.bin).Length
Get-FileHash -LiteralPath .\capture\menu\legacy.disk.exe -Algorithm SHA256 | Format-List
```

Record the result. `--copy-data` copies `Data.bar` and `ArtTerrain.bar` when present; check `matching-data` and inventory rather than assuming they were found. If access to the running process is denied, preserve the error. A collector at the same or higher privilege level may be needed; do not change system security settings.

## Step 4: capture the actual legacy data and mod context

Required:

- The collector's matching `Game\Data\Data.bar`, including any additional matching Data.bar found under other game directories.
- `Game\Art\ArtTerrain.bar` when present, since terrain definitions may matter.
- Any loose files that override those archives: unit prototypes, `protounitcommands`, tactics, terrain/obstruction definitions, and relevant map scripts. Preserve original relative paths and raw `.xmb` as well as any decoded XML. Do not rename binary XMB to XML and call it decoded.
- Active mod names, order, versions, and whether enabled. Prefer screenshots of the mod menu. Determine the actual AoE3 profile location; do not assume a fixed Steam ID.
- A copy of the relevant mod's data/tactics/map scripts, and its metadata. If it is a Git repository, record `git rev-parse HEAD` and `git status --short`; include relevant uncommitted files. Do not include `.git`, account credentials, unrelated personal documents, or unrelated mods.

Put these under `capture\context` and `capture\mod` with a written source-path map. Do not zip the entire 50 GB game installation. Do not modify or extract into the live game/mod folders. Raw Data.bar is sufficient for the other agent to decode; the capture agent need not implement an archive decoder.

## Step 5: controlled unloading test

Record whether the device remained disconnected or was reconnected after offline startup. Do not describe a reconnected test as fully offline. Follow the user's pause-and-resume workflow above.

If a known working example is available, use it. Otherwise ask the user which ship/map illustrates the behavior. Do not fabricate a successful test.

Create a separate test save/scenario, such as `legacy-cliff-unload-test`, with:

- One identified transport and identified cargo, owned by the local player.
- A low beach control and a coastal cliff with room for units on top.
- The same transport/cargo type in both tests.

Record each case separately:

| Terrain | Action | Cargo before/after | Outcome |
|---|---|---|---|
| Low beach | Eject button | actual counts | observed result |
| Low beach | Eject destination/click | actual counts | observed result |
| Cliff | Eject button | actual counts | observed result |
| Cliff | Eject destination/click | actual counts | observed result |

For each test record the map/scenario name, civilization, ship display/internal name if known, cargo display/internal name, coordinates if available, cliff height if available, click location, whether the ship moved, delay until result, and whether every or only some units unloaded. Mark unavailable fields unknown. Take before/after screenshots or a short video. Distinguish the selected ship actually ejecting from a scenario trigger spawning units.

Keep a **before-unloading** save/scenario and an **after-success** save if supported. Copy only those test files into `capture\repro`.

If successful cliff unloading is reproduced, pause and take a second code capture into a fresh folder, without duplicating archives:

```powershell
py -3 .\capture_legacy.py --out .\capture\after-cliff-test --version 100.19.17293.0
```

This second capture checks for code that becomes readable only after gameplay. If the legacy game cannot reach the menu or cannot reproduce unloading, return the available files and exact failure; do not hide it.

## Step 6: write the final handoff and package

Create `capture\RESULTS.md` with:

1. Actual version, EXE hash, how offline operation was ensured, and launch method.
2. Whether main-menu capture and second capture succeeded; unreadable ranges if any.
3. Active mods and their versions/commit plus uncommitted state.
4. Test table, exact reproduction steps, and paths to test saves/screenshots.
5. Archive/loose-file sources and any missing requested files.
6. Any crash or error, with concise relevant log excerpts. Do not send crash reports automatically.

Close the game normally when finished only if the user wants it closed. The user controls when to reconnect, including reconnecting after offline startup to continue in this same thread. Package locally:

```powershell
py -3 -c "import shutil; print(shutil.make_archive('AoE3DE-legacy-capture', 'zip', 'capture'))"
Get-FileHash -LiteralPath .\AoE3DE-legacy-capture.zip -Algorithm SHA256 | Format-List
```

Return `AoE3DE-legacy-capture.zip`, its SHA-256, and a short honest summary. Do not omit the matching legacy data: another copy of the EXE alone will not resolve the remaining uncertainty.

## Optional landmarks for the receiving reverse-engineering agent

These are RVAs for the known exact builds, not universal addresses. Add the actual module base for live addresses. Do not use them to patch anything.

| Component | 17293 RVA | 18309 RVA |
|---|---:|---:|
| uiEjectGarrisonedUnits | 0xC934C0 | 0xF52700 |
| uiEjectAtPointer | 0xC93100 | 0xF52340 |
| autoScout | 0xC74F70 | 0xF33170 |
| aiTaskUnitEject | 0x111B1E0 | 0x1446240 |
| BEjectCommand slot 21 / execution | 0xAB3770 | 0xD63C80 |
| Eject request/action scheduling | 0xBBABD0 | 0xE77590 |
| BUnitEjectAction update | 0xE88290 | 0x119D1D0 |
| Cargo-ejection routine | 0xA36F70 | 0xCE09E0 |
| BUnit::createFromSourceUnit | 0xA2EC10 | 0xCD8560 |
| Single-position wrapper | 0xA38170 | 0xCE1BE0 |
| Candidate-position search | 0xA38370 | 0xCE1DE0 |
| Changed deeper path/obstruction helper (purpose provisional) | 0xE61420 | 0x1175E60 |

MSVC unwind entries can split one function into chained ranges. Aggregate UNW_FLAG_CHAININFO records before comparing full functions. Equal first-range sizes do not imply equal functions. Normalized instruction similarity that ignores call/global addresses is not proof of semantic equivalence; compare target routines and data too.
