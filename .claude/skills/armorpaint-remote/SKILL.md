---
name: armorpaint-remote
description: Run ArmorPaint native scripts through the tested Windows batch adapter to create layers, save/reopen projects and verify exports. Reuse existing mesh maps; no GUI driving or rebake is required.
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

ArmorPaint and custom scripts can consume externally derived, named masks through
this workflow. A historical Painter-generated map is reusable evidence, not a
requirement to start Painter for each asset. Keep the provider/tool identity and
source masks in the recipe; a change of provider requires a bounded comparison
against the accepted output, not a software-name quality claim. For disconnected
roof body/end islands, consume the shared physical mapping in
[roof baking](../blender-roof-baking/references/geometry-contract.md#body-to-end-mapping-implementation-contract).
Independent per-island planar effects and UV-edge wear do not prove continuity.

The consuming recipe owns layer order, explicit resolution, parameters with
units, seeds, map conventions and each input mask's identity and meaning. Retain
native baseline, isolated effects and combined exports so the composition can be
replayed independently. Record whether a mask is measured, retained or a proxy;
never substitute roughness for semantic moss without a reviewed recipe change.
Equal strengths with different inputs are not a replay of the same finish.

Report native script execution, reopen/export, cached delta composition and
visual acceptance as separate evidence. None proves automatic region selection,
upstream map creation or runtime quality. Provider failures remain scoped to
that operation; they do not silently switch the task to another application.

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

### Replay the frozen-atlas composition

`python scripts/composite_delta.py --recipe RECIPE.json --root INPUT_ROOT --out NEW_OUTPUT`
replays an already exported native effect without starting ArmorPaint. The recipe
names a binary grayscale scope and map rows with source, native before/after,
selected destination channels and reference PNG paths relative to INPUT_ROOT.
Rows without channel changes copy the source. Optional `--source-dir` chains
the preceding replay output. Outputs must be new. The receipt records input,
tool and recipe hashes, protected-pixel counts and exact reference comparisons.

Supported: uint8 maps, explicit channel mapping, clipped signed deltas and exact
preservation outside the binary scope. This proves composition only; cached
native exports do not prove replay of native layers, masks or upstream baking.
The consuming project owns its recipe and accepted reference identities.
`python -m pytest scripts/test_composite_delta.py -q` checks channel/scope
preservation, clipping and dimensional refusals.

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
