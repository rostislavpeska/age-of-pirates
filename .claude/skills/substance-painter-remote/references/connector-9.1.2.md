# Painter 9.1.2 connector

`scripts/painter_connector.py` checks the exact active `.spp` path and Painter version before
mutations. `legacy_runtime.py` runs inside Painter through `sp_remote.py`; it selects named Qt
controls and resource model entries. It does not use desktop coordinates or global mouse input.
It still depends on Painter's internal UI structure and the English control labels.

## Proven scope and boundaries

On 2026-09-28 the Korean TC checkpoint exercised:

- Selecting `mata` and `matb` via the public texture-set API.
- Creating/renaming a fill, selecting it, enabling only color and roughness, assigning four
  imported textures by name **and exact resource URL**.
- Saving, reopening, and exporting both pages through Painter's public API. A two-page
  reassignment/save pass took 7.45 seconds; repeating it reused the two named layers and maps.
- Creating a black mask and generator, then binding the built-in Dirt resource. This is
  narrower evidence than a finished weathering recipe.

Evidence belongs in the external asset workspace: `Texturing_11/Astra_CP1/connector_base_report.json`,
`connector_repeat_stdout.json`, `painter_base_export_report.json`. The roof, window and visual
quality gates are separate from connector success.

**Quarantined:** `set_generator_parameter` was active when Painter exited during a weathering trial.
The instrumented follow-up exited during `ensure_generator` with numeric controls excluded.
Therefore generator creation/binding (`ensure_generator`, `bind_generator`, `Add generator`)
are also quarantined. Individual success did not establish batch safety; the exact native cause
requires crash evidence and must not be attributed to a numeric field alone.
Numeric controls, including `set_opacity`, are blocked rather than exposed as working commands.
Recipes containing generator parameters or opacity are rejected before any mutation.
Do not remove the block or retry it on the working project without a separate validated fix.
Standalone open-picker commands are also blocked: a modal picker without a queued completion
can stall the request. Do not treat the command list as a claim of full Painter automation.

## Second native crash: bind_texture (2026-09-28, Claude)

Painter 9.1.2 died again with the SAME signature as the generator crash (`ucrtbase.dll`, `0xc0000409`,
offset `0xa527e`) while `adapter.bind_texture` was running in a two-texture-set recipe
(`Texturing_11/Claude_CP2/painter/painter_connector_events.jsonl`, sequence 175-184; the project had been
saved before the recipe). The fill/bind path is therefore NOT batch-safe either: treat every Qt-adapter
mutation as quarantined until an isolated reproduction explains the fault. Public-API work (create/open,
mesh maps, resource import, save, export) remained stable. Owner workflow until then: the agent prepares the
project by public API; layers are one manual drag per texture set.

## Invocation

Run from the skill directory, with absolute project/recipe paths:

```powershell
python scripts/painter_connector.py --project C:/assets/Working.spp --recipe C:/assets/base_recipe.json --report C:/assets/base_report.json
```

The recipe schema for verified base materials is:

```json
{
  "texture_sets": [{
    "name": "mata",
    "layers": [{
      "name": "Base Materials",
      "enabled_channels": ["color", "rough"],
      "textures": {
        "Base color": {"file": "C:/assets/BaseColor.png"},
        "Roughness": {"name": "Roughness"}
      }
    }]
  }],
  "save": true
}
```

Resource specifications accept an import `file`, an existing project `name`, or an exact `url`.
All names must resolve uniquely. An optional `export` object uses Adobe's documented export
configuration and the public export API. Inspect returned files; export success is not proof
that every requested optional map existed in the document.

For a single operation use `--request operation.json`. Supported actions include `inspect`,
`select_texture_set`, `ensure_fill`, `rename`, `select_layer`, `set_channels`, `bind_texture`,
`ensure_mask`, and `show_window`. Generator commands remain quarantined and are not part
of this supported list. Low-level `menu_action` is not idempotent and must not be blindly
retried; its `Add generator` entry is blocked. Prefer the verified `ensure_*` commands.

## Adapter implementation constraints established by the probes

- Retain Qt wrappers for a job and deduplicate them by C++ pointer. Temporary parent wrappers
  caused invalidation errors; retaining duplicated wrappers caused false ambiguous matches.
- Synthetic resource MIME drops were rejected. The tested route opens the named source
  selector, then a prequeued callback chooses the exact resource-model entry and verifies URL.
- Check the source label and public `list_layer_stack_resources()` after assignment. A label
  alone is not enough to establish persistence; finish the trial with save/reopen/export.
- The public resource context (`project0`, `project4`, etc.) changes on reopen. Resolve current
  project resources each run; do not reuse a URL from an earlier session blindly.
- Capture failures and uncertain outcomes. A lost connection does not prove that an action
  had no effect. Inspect the project before any retry.
