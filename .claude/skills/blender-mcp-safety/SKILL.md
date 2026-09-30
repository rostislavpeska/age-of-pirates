---
name: blender-mcp-safety
description: Crash log and risky-action register for driving the owner's LIVE Blender through the Blender MCP (execute_blender_code, viewport screenshots, Poly Haven imports). Log every risky call before it runs, record crashes with the last call, restart Blender after a crash (owner-authorized 2026-09-28) and consult the register to bypass known crash triggers. Use before any live Blender MCP work, after "Blender crashed", or when choosing between a live call and a background (blender -b) run.
---

# Blender MCP safety: log, avoid, recover

The owner's Blender is a live, unsaved-work session. A crash costs their work and trust. Every
agent that drives it through the MCP keeps one shared log: `CRASH_LOG.jsonl` in this folder.

## Before a live call

1. Prefer a **background** run (`blender -b file --python script.py`) for anything heavy: bakes,
   appends of million-face objects, batch material rebuilds, renders. Live calls are for building a
   review scene, small inspections and view changes.
2. If the call matches a row of the register below, follow its bypass.
3. Log it first: `python scripts/mcp_log.py before --action "<what>" --risk "<register id or new>" --file <blend>`.
   The log line is written and flushed before the call, so a crash leaves the last intent on record.
4. After it returns: `python scripts/mcp_log.py after --ok` (or `--error "<message>"`).
5. Save the live file (`bpy.ops.wm.save_mainfile()`) in its own small call before a risky call.

## After a crash

1. `python scripts/mcp_log.py crash --note "<what the owner saw>"`: marks the last `before` entry as the
   suspected trigger. The script prints it.
2. Restart Blender with the same file (owner-authorized):
   `python scripts/mcp_log.py restart --file "<blend>"`. It launches Blender, waits for the MCP port
   (9876) and logs the result. Recovery: Blender's `File > Recover` / the `.blend1`.
3. Add or update a register row below. Do not repeat the same call shape without its bypass.

## Risky-action register

| id | Risky action | Evidence | Bypass |
| --- | --- | --- | --- |
| R1 | Several heavy operations in ONE MCP call: rebuild a scene (remove + recreate objects), append a HIGH, then `render.opengl` | Crash 2026-09-28 (Claude, Review_Pilot third rebuild + OpenGL render) | One operation per call; save between; render only in its own call or in a background copy |
| R2 | Removing a scene while its objects/materials are in use by the viewport, then rebuilding under the same names | Leftover `.001` objects, preceded the crash above | Delete the scene's own objects and data first (review_scene.py `_clear`), in its own call |
| R3 | `bpy.ops.render.opengl` / `get_viewport_screenshot` while Blender is not focused | Screenshot returned stale frames 3x | Set `region_3d` directly; verify with a background render of a camera, not the live viewport |
| R4 | `read_factory_settings` inside a GUI startup script before screen areas exist | Astra journal 2026-09-28-astra-03 | Start on the disposable startup scene; guard a missing screen |
| R5 | Library-loading into a list that is reused afterwards | Astra journal 2026-09-28-astra-02 (list replaced by datablocks) | Copy name lists before `libraries.load` |
| R6 | Appending million-face HIGH objects (roof banks 1.1-1.3 M faces) into the live session repeatedly | Memory growth; heavy viewport | Link once, or build review HP in a background file and link that |
| R7 | Two live Blender GUI processes running this add-on at once (e.g. opening a second review Blender while an agent's background-worker Blender, such as a `bootstrap.py` job-queue instance, is still open) | Incident B, 2026-09-28: PID 47304 stayed alive with its file saved, but port 9876 went fully absent from `netstat` after a second Blender ("Review_Pilot") was live and then crashed ~9 min earlier; the add-on sets `SO_REUSEADDR` before `bind()` (line 542), which on Windows lets a second process silently take over a port the first is still listening on - see `references/research.md` | Never open a second live Blender while one already answers on 9876 (`python scripts/mcp_log.py tail` or a plain `port_open()` check first); use `scripts/open_review.py` for a live-review instance - it refuses to launch unless the port is free (`--force` to override); a headless job-queue worker (Astra's `bootstrap.py` pattern) never needs MCP at all - keep it off the file-drop channel, not the socket |
| R9 | One call that reloads many large images (19 maps at 1-2k, a machine with ~2.5 GB free RAM and background Blender jobs running) | Incident C, 2026-09-28 23:24 (Korean TC preview): "Communication error: No data received", then port 9876 absent and flapping; the owner had to Save As and restart Blender (the add-on auto-starts the server on launch). The owner went blind for 30 min: "No observability = 99% chance of failure" | Reload at most 4 images per call and only the files that changed; better, let an in-Blender watcher reload on a publish signal instead of pushing through the MCP. During any session that drives the live Blender, keep a port watchdog running (Monitor: poll `netstat -ano` for `:9876 ... LISTENING` every 20 s, print only up/down changes) and tell the owner at once when it drops |
| R10 | Repointing `bpy.data.images[...].filepath` by hand in a scene that has a review watcher | Incident D, 2026-09-29 13:05 (Korean TC relief fix + darker panes): the viewport kept the old GPU copy, the watcher's panel and Back button did not know the change, and the owner could not see what he was asked to approve ("approve -> means I wanna see in Blender!!!!", "The process is STILL flawed!") | The watcher is the only writer: register the maps as a candidate (the project's publish step), then call the watcher's preview through the MCP; it queues the reloads, redraws and keeps Back. Ask for approval only after the owner can see it. A hand repoint is an emergency only, followed at once by the candidate + preview |
| R11 | Clearing mesh material slots to make an image-free transfer, then restoring only the slot list | Korean TC Wanja r2, 2026-09-30: `mesh.materials.clear()` reset 713 polygon indices to slot 0; all eight linked review models showed the wrong roof atlas, despite correct UVs and a correct background render | Preserve the per-polygon material-index vector before clearing. Transfer lightweight placeholder slots and restore the vector; after attaching to LIVE objects, compare every polygon's expected slot AND the slot's material/image bindings. Gate the live result, not only the background source |
| R8 | `execute_code` running a script that can raise something other than `Exception` (e.g. `sys.exit()`) | Verified in code only (not observed live): every catch around `exec()` in `execute_code` is `except Exception`, never `BaseException` (lines 672, 743, 1370) - such a script would silently kill the response-draining timer forever while the socket stays open, i.e. every future call hangs until the client's own multi-minute timeout | Never call `sys.exit()`/`os._exit()`/`quit()` from injected code; if a call ever hangs instead of erroring, suspect this before assuming a crash |

## Tools

- `scripts/mcp_log.py before|after|crash|restart|tail`: the log and the restart.
- `scripts/open_review.py BLEND [--exe] [--port] [--timeout] [--poll-interval] [--force]`:
  opens a background-built review `.blend` in a new Blender instance meant to be the sole
  owner of the MCP port; refuses to start if something already answers on that port (R7).
  Logs to `CRASH_LOG.jsonl` via `mcp_log.write`. `scripts/test_open_review.py` covers its
  argument parsing and port-wait loop offline - no socket, no Blender, no real sleep.
- See `references/research.md` for the full investigation behind R7/R8: the add-on's
  server code read line-by-line, the upstream GitHub issues it matches, and the proposed
  (not applied) watchdog-timer and env-var-gated-autostart fixes.
