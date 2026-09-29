---
name: substance-painter-remote
description: Control Substance 3D Painter through its built-in remote scripting for projects, mesh maps, resources, saves and exports. Includes a version-specific Painter 9.1.2 connector for named fill layers and texture assignment, with generator commands quarantined after native crashes. Use for Painter material assembly, bake import and export, including when no compatible MCP is installed.
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

Painter 9.1.2 (`C:\Program Files\Adobe\Adobe Substance 3D Painter`) is too old for the published
Painter MCPs, and none is needed: Painter itself runs scripts sent to a local port.

## Start

Launch only on the owner's word (as with the game, never on your own initiative), with no
project open in another Painter instance:

```powershell
Start-Process "C:\Program Files\Adobe\Adobe Substance 3D Painter\Adobe Substance 3D Painter.exe" -ArgumentList "--enable-remote-scripting"
```

The port opens about one second later. `python scripts/sp_remote.py --check` prints the version
or exits 2. A Painter started without the flag does not listen: ask the owner to restart it.

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
- `resource.import_project_resource(path, Usage.TEXTURE)` and
  `TextureSet.set_mesh_map_resource(MeshMapUsage.X, id)` - slots: AO, BentNormals, Curvature,
  Height, ID, Normal, Opacity, Position, Thickness, WorldSpaceNormal.
- Also present, not yet exercised: `baking` (parameters, `bake_async`), `export.export_project_textures(config)`,
  `project.save_as`.

**No public layer API in this version:** Python API 0.2.11 has no `layerstack` module and
JS `alg` has no layer namespace. This does **not** mean all layer work requires desktop input.
`scripts/painter_connector.py` uses the public APIs where available and a version-gated Qt
adapter for named layer controls. Fill creation/rename, channel toggles, texture resource
selection and saved two-page base materials were exercised on 9.1.2. Black-mask creation,
generator creation and Dirt resource binding succeeded individually, but later batch use
exited during `ensure_generator` even without numeric controls. The generator path and
numeric controls are quarantined. See the reference for exact evidence
and commands. Do not describe this internal UI adapter as Adobe's public layer API.

## Shared UVs: load owners only

On conjoined UVs members sit on their owner's texels. Painter bakes and paints every face it
has, so a member would overwrite its owner. Export to Painter **only the owner faces** of the
frozen layer (the targets of `bake_owner_maps.py`), one material per page (`mata`, `matb` ->
one texture set each, resolution = page size). The model shows gaps in Painter; the textures
are complete on the full model in Blender and in game. Bake in Blender
([blender-high-low-baking](../blender-high-low-baking/SKILL.md) `bake_owner_maps.py`, after the
[UV freeze](../blender-architecture-texturing/references/pipeline-order.md)) and import the
maps as mesh maps, rather than baking in Painter.

## Rules

- Never close, save over or reload a project you did not create in this session; check
  `last_imported_mesh_path()` first. A throwaway project is closed without saving.
- `scripts/smoke_test.py [mesh] [map.png]` proves create -> texture sets -> mesh map ->
  close on Painter's own test FBX (passed 2026-09-28). Run it after a Painter update.
