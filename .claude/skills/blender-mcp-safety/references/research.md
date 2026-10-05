# Why the Blender MCP connection keeps dropping - investigation 2026-09-28

Scope: read-only on the running Blender processes and add-on source. Nothing was sent to
the owner's live Blender, nothing was killed or restarted, no live socket was opened by
this investigation. All commands run were: reading files, `tasklist`, `netstat`, and
offline unit tests of a new helper script.

## Verdict up front

- **Verified**: at the time of Incident B, Blender PID 47304 (window title "GPT Astra -
  Korean TC Materials WIP") was alive with its file saved, and `netstat -ano` showed
  **nothing** listening on 9876 - the add-on's socket was gone, the process was not.
- **Verified in code**: the installed add-on already contains a real, documented fix for
  one earlier WinError 10054 cause (stale client threads surviving a toggle-restart -
  `blender_mcp_addon.py` lines 586-601). It also matches, near verbatim, the diagnosis in
  upstream issue ahujasid/blender-mcp#314 about per-command timer registration silently
  dropping callbacks on Windows - already fixed here with a single persistent drain timer
  (lines 452-457, 654-682).
- **Suspected, high confidence** (not independently reproduced - reproducing it would mean
  deliberately racing two Blender instances for a port, which risks the same crash class
  this task forbids triggering): Incident B was a **second live Blender process stealing
  port 9876 from the first via Windows' SO_REUSEADDR semantics**. This session's own
  artifacts show two concurrent Blender GUI processes in the ~10 minutes around the
  incident (see Timeline below), the add-on explicitly sets `SO_REUSEADDR` before `bind()`
  (line 542), and that flag is documented by Microsoft as exactly the mechanism that lets a
  second process's `bind()` take over a port a first process is still listening on. The
  project's own community troubleshooting pages independently warn against running more
  than one MCP-enabled Blender at a time for this exact reason.
- **Verified in code, distinct and additional fragility**: `execute_code` runs arbitrary
  `exec()` on Blender's main thread (line 1377) and every layer around it only catches
  `except Exception` (lines 672, 743, 1370) - never `BaseException`. A `SystemExit` (e.g.
  from a script that calls `sys.exit()`) raised inside executed code would propagate out of
  the `_drain_command_queue` timer callback itself, which Blender's timer subsystem then
  simply stops rescheduling - the queue-draining timer dies silently, forever, while the
  listening socket (a separate thread) keeps accepting connections that never get answered.
  This produces a **hang**, not the **closed port** actually observed in Incident B, so it
  is not the cause of Incident B, but it is a real, unaddressed gap worth fixing alongside it.

## 1. Reading the add-on's server code

File: `%APPDATA%\Blender Foundation\Blender\5.0\scripts\addons\blender_mcp_addon.py` (175 KB,
modified fork, mtime 2026-09-14).

**Startup / singleton** (lines 3956-4123, `register()`): the server object is stored as
`bpy.types.blendermcp_server`, a bare Python attribute on the `bpy.types` module object -
not tied to `bpy.data`, so it survives a File > New / File > Open in the *same* process.
`blendermcp_auto_start_server` defaults to `True` (line 3970-3974) with no environment-variable
override (unlike the API-key settings, which do fall back to env vars via
`_get_config_value`, lines 462-478). Every Blender process that loads this add-on - including
one started headless-GUI via `--python bootstrap.py` for a background-job worker that has no
intention of using MCP at all - will therefore try to auto-bind port 9876 at `register()` time.

**Socket setup** (`start()`, lines 527-564):
```
541  self.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
542  self.socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
543  self.socket.bind((self.host, self.port))
544  # Backlog of 1 meant a reconnecting client could complete the TCP
545  # handshake and then never be accept()ed - a connection that looks
546  # established but is never serviced.
547  self.socket.listen(5)
```
`SO_REUSEADDR` is set on the *first* socket to bind. Per Microsoft's own Winsock
documentation (cited below), that is precisely the condition under which Windows allows a
**different, unrelated process** to later bind the same address:port while the first
socket is still alive and listening - "port hijacking" in older Windows terms, only
prevented by the first binder instead using `SO_EXCLUSIVEADDRUSE`. This add-on uses neither
an exclusive bind nor a distinct port per process; two Blender instances both running this
add-on will contend for the exact same 9876.

**Accept loop** (`_server_loop`, lines 621-652): `self.socket.settimeout(1.0)`, loops on
`accept()`, spawns one daemon thread per client via `_handle_client`. A generic exception in
`accept()` (line 643) is logged and the loop just sleeps 0.5s and retries - it does not
exit unless `self.running` is already `False`. This part is robust to transient
errors; it will not itself explain a socket that goes fully absent from `netstat` while
`self.running` was never toggled off, which is why the multi-instance bind-steal theory
(an *external* process taking the same port, not this loop dying) fits the observed
"closed port, no exception on record" symptom better than an internal crash of this loop
would.

**Command draining, single persistent timer** (`_drain_command_queue`, lines 452-457 and
654-682): this fork deliberately does **not** register a `bpy.app.timers` callback per
incoming command. The comment at 452-457 states why: *"registering a timer per command
(the previous approach) could silently drop the callback - on Windows especially - leaving
the client blocked in recv() until its socket timeout."* That is, nearly word for word, the
diagnosis in upstream issue **ahujasid/blender-mcp#314** (see Section 2) - this fork already
carries that fix. Per-command exceptions are caught (`except Exception as e:` at line 672)
and turned into an `{"status": "error", ...}` JSON reply rather than being allowed to kill
the timer - **except** that this only catches `Exception`, not `BaseException`, so a
`SystemExit`/`GeneratorExit` raised inside `execute_command` -> `execute_code`'s `exec()`
(line 1377) is not caught here either, and would kill this specific timer for good (see
verdict above).

**Client handling and disconnect** (`_handle_client`, lines 684-735): `client.settimeout(1.0)`
so the per-client thread stays responsive to `self.running`; a `recv()` returning `b''`
(line 699) is treated as a clean disconnect and breaks the loop; any other exception also
breaks the loop (line 723-725); the `finally` block (728-735) always removes the client from
`self._clients` and closes the socket. Malformed (not just incomplete) input is treated
identically to a partial frame (`except (json.JSONDecodeError, UnicodeDecodeError): pass`,
lines 714-719) and simply appended to indefinitely; there is no cap on `buffer` size. Genuinely
garbage bytes on the wire (as opposed to a slow trickle of a valid frame) would grow this
buffer forever and never resolve - this is the same failure shape as upstream issue #219
("Incomplete JSON response") describes from the client's side.

**Stop / restart, and the WinError 10054 this fork already fixed once** (`stop()`, lines
566-619): stopping is thorough - unregisters the timer, closes the listening socket,
and, per the comment at 586-589, explicitly shuts down every live client socket:
```
586  # Shut down live client sockets. Without this, handler threads stay
587  # parked in a blocking recv() forever; being daemon threads they then
588  # outlive the restart and close connections the new server owns
589  # (the WinError 10054 seen after toggling the addon).
```
This confirms WinError 10054 has hit this exact add-on before, from a **different**
mechanism than Incident B (an in-process toggle-off/toggle-on leaving orphaned handler
threads from the *old* server instance interfering with the *new* one in the *same*
process). That bug is already fixed. Incident B's signature - port fully absent from
`netstat`, Blender never toggled the add-on, no crash - does not match this already-fixed
path; it matches an external actor (a second process) taking the port instead.

**`execute_code`** (lines 1367-1380): runs `exec(code, namespace)` directly, unsandboxed, on
the main thread, wrapped only in `except Exception`. Nothing here is Incident-B-specific,
but it is the mechanism by which *any* future risky call (including one that calls
`bpy.types.blendermcp_server.stop()`, disables the add-on, or calls `sys.exit()`/
`os._exit()`) could kill the server or the process outright - worth keeping in mind for
"safe call shapes" below.

### `bootstrap.py` (Astra_CP1's own script, not part of the add-on)

`$AOP_KOREAN_REPO/research/Texturing_11/Astra_CP1/bootstrap.py`
does **not** touch the MCP add-on, the port, or `bpy.types.blendermcp_server` at all. It:
- clears the default scene and appends a fixed object set from a source .blend (lines 12-20),
- verifies a UV fingerprint against a frozen `uv_freeze.json` (line 21-22),
- saves a working copy (line 38),
- and registers its **own** independent persistent timer, `poll()` (line 63), which watches
  a `live_jobs/*.request.json` directory and `exec()`s whatever script each request names
  (lines 48-61) - a second, file-drop-based automation channel that never goes through
  port 9876 at all. Jobs 001-007 in `live_jobs/` (12:38-13:28) all completed with `ok: true`
  and never touch the MCP server; they are not implicated in Incident B.

This is actually the shape of the fix requested in task 3(c): the job-queue pattern already
proves that most of what an agent needs from a live Blender (append, bake, measure, save,
report back as JSON) does not require the MCP socket at all.

## 2. External research (web, with URLs)

- **ahujasid/blender-mcp #314** - "blender MCP":
  <https://github.com/ahujasid/blender-mcp/issues/314> (aka
  <https://github.com/ahujasid/mcp-for-blender/issues/314>). Reports exactly this add-on's
  failure family on Windows: connections accepted on `localhost:9876` but never answered
  (multi-minute hangs), an occasional `WinError 10054` when an established connection is
  dropped mid-exchange, and identifies the cause as **"the handler is scheduled with
  `bpy.app.timers.register()`, which only fires when Blender's main event loop is
  processing"**, with per-command timer registration able to silently fail on Windows.
  Proposed fixes: an immediate accept-ack, a `ping` command that never touches `bpy` data,
  and logging every accept/dispatch to the system console. The installed add-on's
  single-persistent-timer/queue design (Section 1) is exactly this fix, already applied.
- **ahujasid/blender-mcp #219** - "Incomplete JSON response, MCP timeout":
  <https://github.com/ahujasid/blender-mcp/issues/219>. A response is received but
  truncated (51 of however many bytes) and never becomes valid JSON; the client times out
  after ~40s and reconnects. Same family as the unbounded `buffer` accumulation in
  `_handle_client` noted above - large or malformed payloads are the recurring theme behind
  "response never completes."
- **Community troubleshooting pages for this exact project** independently document the
  multi-instance hazard this investigation suspects caused Incident B: "Only run one MCP
  server instance at a time... a second Blender add-on trying to bind the same port... will
  confuse or block the connection" and recommend a distinct `--port 9877` for any second
  instance (mcp-for-blender.com/reference/troubleshooting; blendermcp.org/server - fetched
  2026-09-28 via web search, exact URLs returned by the search were the community docs
  sites, not GitHub issue numbers).
- **Microsoft Learn, "Using SO_REUSEADDR and SO_EXCLUSIVEADDRUSE"**:
  <https://learn.microsoft.com/en-us/windows/win32/winsock/using-so-reuseaddr-and-so-exclusiveaddruse>.
  States plainly that when the *first* socket to bind a port sets `SO_REUSEADDR`, a second,
  unrelated process can then bind the same address:port while the first is still alive and
  listening; `SO_EXCLUSIVEADDRUSE` on the first socket is the documented way to prevent it.
  This is the exact call the add-on makes (line 542) without ever setting the exclusive
  option, and is the mechanistic basis for the "two live Blenders steal each other's port"
  theory above.
- The fork's own public repo, <https://github.com/rostislavpeska/blender-mcp-modded>,
  describes itself (per its README) as a small, additive extension (camera tools, model
  import, text-to-3D webhook) that does not touch "core infrastructure." That does not match
  what is actually installed: the persistent-timer fix, the `_clients` shutdown-on-stop fix,
  and the `listen(5)` backlog fix are all core-infrastructure changes present in the local
  175 KB file but not described in the public README. Either the public repo is stale or the
  installed copy carries additional local-only patches; worth reconciling later so the next
  reinstall/update doesn't silently lose these fixes, but out of scope for this
  investigation (no repo push was made).

## 3. Timeline this session found (all read-only)

| Time (2026-09-28) | Event | Source |
| --- | --- | --- |
| ~12:38 | `bootstrap.py` runs inside Blender PID 47304, `--factory-startup`-style GUI launch, builds "Astra_CP1" scene, registers its own `poll()` job-queue timer | `bootstrap.py`, `live_status.json` |
| 12:38-13:28 | Jobs 001-007 run through the file-queue mechanism (not MCP); all `ok: true` | `live_jobs/*.result.json` |
| 13:53:58 | A **different** live Blender session ("Review_Pilot", file `Korean_TC_T01_Texturing.blend`) is driven via `execute_blender_code` through one call that rebuilds the scene, appends a 1.3M-face object, and calls `bpy.ops.render.opengl` - it crashes (Incident A, already understood/logged) | `CRASH_LOG.jsonl` |
| 14:03:19 | A **read-only** `execute_blender_code` call, intended for the Astra_CP1 file, fails: `WinError 10054`; a follow-up check finds PID 47304 alive with its file saved and port 9876 fully closed (Incident B) | `CRASH_LOG.jsonl`; confirmed again independently in this investigation via `tasklist` (PID 47304 present, window title "GPT Astra - Korean TC Materials WIP") and `netstat -ano` (no 9876 entry at all) |

The 13:53:58 crash and the 14:03:19 disconnect are ~9 minutes apart on what the evidence
shows were two *different* Blender processes/files. That a second live GUI Blender (Review
Pilot's) was up and manipulating a socket-bound MCP add-on at the same time the surviving
process's own MCP binding went dark is the concrete basis for the port-collision theory -
it is offered as the most likely explanation, not a certainty, since nothing here re-created
the race under controlled conditions (doing so was out of scope and risky by the same logic
that makes it a hazard for the owner).

## 4. Proposed fix

### (a) Detect a dead server and restart it without restarting Blender

Two independent things can go wrong and they need different handling:

1. **The drain timer dies** (e.g. a `BaseException` escapes `execute_code`, or any future
   code path raises something `except Exception` does not catch). Fix: widen every boundary
   around user-supplied code from `except Exception` to `except BaseException` (lines 672,
   743, and inside `execute_code` at 1370), so nothing but an actual interpreter-fatal error
   can silently kill the timer. This is a one-line change per site, in the add-on file
   (`%APPDATA%\...\blender_mcp_addon.py`) - **proposed only, not applied**, since editing the
   owner's live add-on file was out of scope for this task. Sketch (illustrative, not
   applied):
   ```python
   except BaseException as e:          # was: except Exception as e:
       print(f"Error executing command: {e}")
       traceback.print_exc()
       response_json = json.dumps({"status": "error", "message": str(e)})
   ```
2. **The listening socket disappears while `self.running` is still True and nobody called
   `.stop()`** - the actual Incident B shape. A second, independent watchdog timer
   (registered persistent, alongside `_drain_command_queue`, polling every ~3s) that checks
   `self.running and (self.socket is None or self.socket.fileno() == -1)` and, if true, calls
   `self.stop(); self.start()` **inside the same process** would recover from *this
   process's own* socket dying without ever touching the Blender process itself. It would
   **not** fully fix Incident B if the true cause is a second process still holding/re-taking
   the port - the two would just keep trading it - so this is necessary but not sufficient
   on its own; it must be paired with the procedural fix below. It can be triggered
   externally today with what already exists: `mcp_log.py restart` launches a **new**
   Blender process (last resort, requires the owner's go-ahead per the "never restart the
   game/Blender" house rule); there is currently no way to ask a *surviving* Blender to
   re-run only `self.stop(); self.start()` without also exposing that as a new MCP command
   or a Blender-side keyboard/timer trigger, which would itself need to go through the
   already-dead channel. In practice, once the socket is gone, only the watchdog timer
   above (running inside the same process, not dependent on the socket) can self-heal it.
3. **Procedural fix for the actual suspected cause** (this is the one that matters most):
   never let a second live Blender GUI process auto-bind port 9876 while one is already
   listening. Concretely:
   - `mcp_log.py restart` and any future "open another Blender" helper should check
     `port_open()` **before** launching and refuse (or pick a different port) if something
     already answers - `open_review.py` (below) does exactly this.
   - A worker-only process like Astra's `bootstrap.py` never needed MCP in the first place
     (it uses its own file-drop job queue). The cleanest fix is to make such workers launch
     with the add-on's auto-start explicitly disabled, so they never attempt the bind at
     all. There is currently no environment-variable gate for
     `blendermcp_auto_start_server` (unlike the API-key settings, which do check env vars -
     `_get_config_value`, lines 462-478). Proposed addition (illustrative, not applied):
     ```python
     auto_start = scene.blendermcp_auto_start_server and not os.environ.get("BLENDERMCP_NO_AUTOSTART")
     ```
     A worker script would then set `BLENDERMCP_NO_AUTOSTART=1` in its own process
     environment before Blender loads the add-on, guaranteeing it never contends for 9876.

### (b) Safe call shapes

- One `bpy`-mutating operation per `execute_code` call; never combine a scene
  rebuild/append with a render in the same call (register row R1 already captures the
  crash this caused).
- Save (`bpy.ops.wm.save_mainfile()`) in its own small call immediately before any call that
  touches geometry, materials, or rendering, so a crash or a dropped connection loses at
  most one step.
- Prefer the structured read-only handlers (`get_scene_info`, `get_object_info`) over
  `execute_code` for inspection - they're plain Python dict-builders, not raw `exec()`, and
  cannot accidentally reach `sys.exit()`/add-on internals.
- Treat any response over a few tens of KB (a big screenshot, a full scene dump) as a
  candidate for the same truncation class documented in upstream #219; prefer writing large
  results to a file on disk and returning the path, not the payload, over the socket.
- Before a risky call, confirm the server is actually alive with something that doesn't
  touch `bpy` at all - the existing `mcp_log.port_open()` (a plain TCP connect) already
  serves as that "ping"; call it and abort the call plan if it's False rather than let the
  MCP client's own multi-minute timeout be the first signal.

### (c) Background-Python connector + `open_review.py`

For anything that does not need the live UI: `blender -b file --python script.py` (already
recommended in `SKILL.md`) never opens a socket, never competes for a port, and cannot be
affected by any of the above - Astra's `bootstrap.py` file-queue pattern is the live-UI
equivalent of the same idea (it also avoids MCP, by design or by accident).

For the live-review case, `scripts/open_review.py` (new, this investigation) builds on that:
it assumes the review `.blend` was already produced by a background run, then opens it in a
**new** Blender instance that is meant to become the sole owner of port 9876. It refuses to
launch (exit code 2) if `mcp_log.port_open()` already reports something listening, unless
`--force` is passed - directly encoding the procedural fix from (a)(3) so this tool cannot
recreate Incident B by accident. It logs a `before`/result pair to `CRASH_LOG.jsonl` via
`mcp_log.write()`, exactly like the existing `mcp_log.py restart` command. Its argument
parsing and its port-wait polling loop (`wait_for_port`, with `check_fn`/`sleep_fn`/`clock_fn`
all injectable) are covered by `scripts/test_open_review.py`, run offline (11 tests, no real
socket, no real Blender, no `time.sleep`) - see that file for the guard test that asserts
`time.sleep` and `socket.create_connection` are never called by the polling logic itself.
`launch_blender()` was **not** exercised even under mocks against a real path in this
investigation beyond confirming it is a thin, patchable wrapper around `subprocess.Popen`.
