---
name: substance-painter-remote
description: Control Substance 3D Painter through device-local discovery and its remote scripting API. Probe the actual installation, API process and project before editing; use public project/resource/export APIs and the separately validated bounded 9.1.2 layer adapter. Use for Painter materials, mesh maps, saves and exports, including when no MCP is installed.
---

# Substance Painter by remote scripting

## Connector first (owner instruction, 2026-09-28)

Use the connector before desktop control. If an action needs desktop fallback, implement and
verify an equivalent connector command before repeating that action across assets. Do not
turn repeated clicking into the production workflow. Read
[the tested 9.1.2 adapter and its limits](references/connector-9.1.2.md) before layer work.
Read [connector logging and recovery](references/connector-logging.md) before a new adapter
trial or after connection loss. The log identifies the actual Painter process; a running
window is not proof that it is the process listening on the scripting endpoint.
Connector development is a separate trial on a saved copy; a successful button invocation
is not proof that a parameter change, saved project or exported texture is correct.

Dependent operations must stop at the first failure. Before **save-as and export**,
verify the expected project and imported mesh identity as strictly as before baking.
An earlier failed create/close must never let a later save label an unrelated open
document as a completed diagnostic. Close an owned project before renaming its
saved file. Put multi-line client code in a script; nested shell quoting is not
a reliable orchestration layer. Korean House AO refresh, 2026-10-09, INC-180
(original local ID INC-177, remapped during cross-device reconciliation).

Do not infer the installation or capabilities from another computer. Run
`python scripts/painter_environment.py --local-config <this-device-tool-paths.json> --report <scratch-report.json>`.
The ignored local file uses `tools.substance-painter.path`, `host` and `port`.
An explicit executable is validated; otherwise an unambiguous running process or
Windows installation registry entry can identify it. Environment overrides:
`PAINTER_LOCAL_CONFIG`, `PAINTER_EXECUTABLE`, `PAINTER_HOST`, `PAINTER_PORT`.
Never put a discovered device path into this skill or tracked recipes.

Report **API reachable**, **backend PID**, **window visibility**, **project path** and
**operation verified** separately. A hidden API process is not the owner's visible window.
With multiple instances, mutations require `PAINTER_EXPECT_PID` matching the API process;
never select an instance merely because its executable path matches. The probe does not
prove which window is foreground. Do not bring a window forward or relaunch the owner's
instance without the applicable screen-control authorization.

## Start

On an authorized start, the portable launcher checks for existing processes before
launching; it never silently restarts or creates a second instance:

```powershell
python scripts/painter_environment.py --local-config <this-device-tool-paths.json> --start --report <scratch-report.json>
```

This starts a background instance and reports it as such. `python scripts/sp_remote.py --check`
prints the observed version or exits2. A manually started visible instance may lack
`--enable-remote-scripting`; do not confuse it with another listening process.

**Someone else's instance holds the endpoint (its project must not be touched)?** Start an own hidden second
instance with its own port: `python scripts/launch_second_instance.py --report <scratch.json>` (startup plugin
`scripts/second_instance/startup/rpc_endpoint.py`, 127.0.0.1:60042), then set `PAINTER_HOST=127.0.0.1`,
`PAINTER_PORT=60042`, `PAINTER_EXPECT_PID=<endpoint_pid>` and work on a copy of their `.spp`. Proven 2026-10-09 with
300+ bounded steps; read [the second instance and generator-mask rounds](references/second-instance-9.1.2.md)
(also: the Dirt generator's non-linear `dirt_level`, probe-channel export rounds, compositor NaN guard).

For an independent pre-sharing AO diagnostic, unique UVs on a complete copied
assembly are appropriate. Label its `.spp` as a reference, not the final shared-UV
paint master. `alg.mapexport.saveMeshMap` defaults to texture-set resolution, which
can differ from bake resolution: pass explicit `resolution:[width,height]` and
verify actual output dimensions. In `later(..., until=...)`, the Python condition
must assign `RESULT`; a bare expression leaves the client waiting after success.

## Client (`scripts/sp_remote.py`)

| Call | Use |
| --- | --- |
| `js(code)` | JavaScript `alg.*` API; returns the last expression |
| `py(code)` | Python `substance_painter.*`; set `RESULT` (JSON-serialisable) to get a value back |
| `later(code, until=...)` | **every long operation** - create, open, close, bake, export, save |

`later` queues the code on Painter's main loop and polls. Called directly inside a request, a
long operation re-enters the request handler while Painter processes events and the request
runs **twice** (a successful `create` answered "Cannot create a new project because one is
already opened"). The operation also returns before Painter finishes (texture sets are empty
right after `create`), so `until` polls a condition, by default "not busy".

## What is scriptable in 9.1.2 (verified 2026-09-28)

- `project.create(mesh)`, `close()`, state (`is_open`, `is_busy`, `last_imported_mesh_path`).
- Texture sets: one per material of the FBX; names, resolution (`set_resolution`).
  On9.1.2 resolve a named set from `all_texture_sets()` (or the observed
  `TextureSet.from_name`); there is no module-level `get_texture_set`.
- `resource.import_project_resource(path, Usage.TEXTURE)` and
  `TextureSet.set_mesh_map_resource(MeshMapUsage.X, id)` - slots: AO, BentNormals, Curvature,
  Height, ID, Normal, Opacity, Position, Thickness, WorldSpaceNormal.
- `export.export_project_textures(config)` and `project.save_as`: exercised with
  saved/reopened military r60 sources and scoped texture comparisons.
- `baking` (exercised 2026-10-08): `bake_async` of normal/WSN/AO/curvature/position/thickness in
  8-14 s at 2048. Connect the completion callback strongly (`connect_strong`); a plain connection is
  dropped and the wait never returns. Afterwards call `ui.switch_to_mode(UIMode.Edition)` before any
  layer step.

**No public layer API in9.1.2:** Python API0.2.11 has no `layerstack` module and
JS `alg` has no layer namespace. This does **not** mean all layer work requires desktop input.
`scripts/painter_connector.py` uses the public APIs where available and a version-gated Qt
adapter for named layer controls. Fill creation/rename, channel toggles, texture resource
selection and saved two-page base materials were exercised on 9.1.2. Black-mask creation,
generator creation and Dirt resource binding succeeded individually, but later batch use
exited during `ensure_generator` even without numeric controls. The generator path and
numeric controls in the original all-in-one adapter remain quarantined. The separately
validated `scripts/legacy_session.py` uses small queued steps, persistent control context,
correct effect labels and native slider properties. Read
[the bounded repair and save/reopen proof](references/bounded-9.1.2.md) before using it.
Do not describe this internal Qt adapter as Adobe's public layer API. On another version,
probe for public `layerstack` capabilities first; do not blindly force the9.1.2 adapter.

The owner's plaster recipe (white fill + height, black mask, Dirt generator) runs end to end on
9.1.2 with this bounded adapter: two runs, 540 steps, no crash, exact readback after reopen. Read
[white-coat Dirt relief](references/whitedirt-relief-9.1.2.md) for the step order, measured
settings, the 16-bit Height export and its pitfalls (select_mask before ensure_generator_effect,
integer Grunge_Scale, true-case save paths, AO binding, saturated dark-AO blocks).
The owner does not want Painter upgraded (2026-10-08); keep 9.1.2 workflows working.

## Shared UVs: load owners only

On conjoined UVs members sit on their owner's texels. Painter bakes and paints every face it
has, so a member would overwrite its owner. Export to Painter **only the owner faces** of the
frozen layer (the targets of `bake_owner_maps.py`), one material per page (`mata`, `matb` ->
one texture set each, resolution = page size). The model shows gaps in Painter; the textures
are complete on the full model in Blender and in game. Bake in Blender
([blender-high-low-baking](../blender-high-low-baking/SKILL.md) `bake_owner_maps.py`, after the
[UV freeze](../blender-architecture-texturing/references/pipeline-order.md)) and import the
maps as mesh maps, rather than baking in Painter.

**Prove coverage from the current mesh, not historical owner labels.** Rasterize
all currently bound own-atlas UV triangles and compare them with the exported
Painter triangles. Every used pixel must have a representative. Chart equality
can omit independently packed AO banks, larger members and newly remapped faces.
Keep valid owners; add only uncovered UV polygon portions from current readers,
interpolating their positions and corner normals. Recheck coverage and overlaps.
Do not export every shared member to conceal the gap. Korean military r60 found
39,252 Barracks and11,107 Stable missing texels this way (INC-137).
Compare a baseline export with the canonical maps before accepting new paint;
successful resource binding does not prove a complete exported atlas.
`scripts/owner_coverage.py` checks current versus authoring UV triangles on each
page (NumPy on the client/Blender host). Its negative tests include a missing AO
bank and an underrepresented larger member. This raster gate complements, rather
than replaces, geometric overlap and material/normal-channel checks.

## Rules

- Never close, save over or reload a project you did not create in this session; check
  `last_imported_mesh_path()` first. A throwaway project is closed without saving.
- `scripts/smoke_test.py [mesh] [map.png]` proves create -> texture sets -> mesh map ->
  close on Painter's own test FBX (passed 2026-09-28). Run it after a Painter update.
