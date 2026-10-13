---
name: armorpaint-remote
description: Run ArmorPaint native scripts headlessly to create editable layers, procedural masks and material effects from existing mesh maps, save/reopen projects and verify texture exports. Includes a bounded Windows CLI and stdio MCP adapter; does not require GUI driving or rebaking.
---

# ArmorPaint native automation

Use the configured local runtime, not an assumed installation. The tested route
is upstream native C scripting, with a small batch adapter. Read
[the tested API and limitations](references/native-workflow.md) before authoring
scripts. This is a GPU renderer with a hidden window, not a CPU-only server.

Set `tools.armorpaint.path` in the consumer's ignored local tool configuration,
or set `ARMORPAINT_EXE`. Do not put a device path in this package. The command
requires Windows; other platforms remain untested.

```powershell
python scripts/armorpaint_batch.py --local-config LOCAL.json run --input MODEL.obj --script AUTHOR.c --out-dir FRESH_LOGS --expect NEW_PROJECT.arm --marker PROJECT_COMPLETE
python scripts/armorpaint_batch.py --local-config LOCAL.json export --input NEW_PROJECT.arm --out-dir FRESH_EXPORT
```

Paths in examples are placeholders. Output directories must be new or empty.
Every run writes command/runtime identity, input hashes, timestamps, stdout,
stderr, expected-output hashes, elapsed time and hidden-window observations.
An exit code alone never establishes success. Exports verify all five PNG maps,
dimensions and decoding. The adapter rejects timeout, visible windows, native
script errors, missing markers, absent/stale outputs and changed source files.
It terminates only the process it owns. Inspect failed evidence before retrying.

## Material workflow

1. Preserve the original mesh, UVs, maps and masks. Work on an authoring copy with
   correct material/face ownership. Reuse current curvature, AO, position and
   normal maps when available; do not rebake without the task's authorization.
2. Create an editable baseline and separate effect layers: exposed wear,
   cavity dirt and protected moss/roughness. Use native material nodes/fill
   masks. Save, reopen and export a baseline plus isolated effects and combined
   specimen. The supplied [smoke test](scripts/smoke_test.py) exercises native
   layers, masks, deletion, save/reopen and exported pixel changes.
3. Compare native export against the original. Resampling and normal-map
   roundtrips can change untouched pixels. For a frozen atlas, apply the
   candidate-minus-native-baseline delta only within the owned effect mask;
   retain original alpha and protected channels exactly. Do not silently
   replace the normal map when only colour/roughness were authorized.
4. Inspect fixed close, grazing and RTS-scale shots against the project's
   canonical reference. Verify top AND vertical/underside surfaces, alpha,
   mips and shared-UV ownership. Numeric change counts prove coverage, not art
   quality. Preserve failed variants and keep owner approval distinct from QA.

No generic roof palette or effect strength is prescribed here; recipes and
reference hashes belong in the consuming project. The current adapter supports
native script execution and five-map PNG export, not every application feature.

## MCP and checks

The optional [stdio server](scripts/armorpaint_mcp.py) exposes the same verified
batch operations. Configure its command as `python <absolute path to server>`
and `ARMORPAINT_EXE` in the client's local environment. No automatic edits to
agent configuration, socket listener, persistent GUI or global installation.

```powershell
python -m unittest discover -s scripts -p test_armorpaint_batch.py -v
python scripts/smoke_test.py --exe EXE --out-dir FRESH_SMOKE
```

For smaller project pages, read the explicit-resolution extension in the linked
workflow. Export resolution is an assertion; the separate `resize` command saves
a new project and verifies it without changing the source.

The native smoke launches owned hidden processes. It is not a bake or a game
validation. Public MCP projects targeting older ArmorPaint revisions may need
native patches; do not assume tool-name compatibility with this build.
