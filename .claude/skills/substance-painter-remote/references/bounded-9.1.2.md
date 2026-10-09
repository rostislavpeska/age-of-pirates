# Bounded Painter9.1.2 layer adapter

Verified2026-10-07 against Painter9.1.2 / Python API0.2.11 on a disposable
two-material256 project. This is an internal Qt adapter, not a public layer API.
Adobe's public layer stack editing arrived in10.0; probe the installed capabilities
instead of assuming this older adapter is appropriate everywhere. See
[Adobe's layer editing documentation](https://experienceleague.adobe.com/en/docs/substance-3d-dev/painter-python/api/substancepainter-package/layerstack-module/edition)
and [the product team's version clarification](https://community.adobe.com/questions-59/adjust-fill-layer-color-via-script-629489).

## What changed and what was proved

The original generator lookup searched for an `Alg::EditLabel` named `name`;
the actual effect control is named `label`. It could fail to recognize an existing
generator. The repaired lookup handles both names, scoped to the requested layer.
Each structural edit yields back to Painter's event loop before a dependent action.
Widgets are reacquired after changes and retained in a process-local context.
Numeric changes use the native `Alg::Slider.value` property rather than emitting
`editingFinished` on a text field. Persistent parameters, not field text, are checked.

Both test pages completed: named fill, color/roughness channels, exact texture URL,
black mask, built-in Dirt generator, dirt amount and grunge parameter changes,
idempotent repeat, save, close, reopen and export. No native crash occurred.
Saved dirt amount0.85 and grunge0.60 survived reopening. Reopened RGB exports
differed by at most1/255, mean0.00212/255, after the procedural graph rebuilt.
This is not a promise of byte-identical procedural exports. The earlier native
`ucrtbase` crash's exact C++ cause remains unproven; do not claim that it was
conclusively isolated to a numeric control.

Private evidence: Korean military r60 `painter_trial/ROUNDTRIP_PROOF.json`,
`BATCH_STEPS.json`, `BATCH_REOPENED.json`, `batch.spp`, exported PNGs and durable logs.
The original `painter_connector.py` quarantine remains; do not remove it to run
the older monolithic generator recipe.

## Execution contract

1. Probe the device-local installation and capture the API PID/project/window status.
   An API reachable in a hidden process is **not** the owner's visible instance.
2. Set `PAINTER_EXPECT_PID` to that observed, intended PID. Open a versioned saved
   project copy via public API; protect any existing user document.
3. Construct `LegacySession(project_path, pid)`. Every step verifies PID and exact
   project again. Use current-session resource URLs resolved by public resource API.
4. Per texture set, run these separately queued `step` operations in order:
   `ensure_fill`, `set_channels`, `bind_texture` per channel, `select_mask`,
   `ensure_generator_effect`, `bind_generator`, `set_generator_value` per parameter.
   For an existing generator use `select_mask`, `select_generator`, then values.
   `inspect_generator` reads back the actual native values.
   Channel toggle keys are the observed button texts (`color`, `rough`, `metal`,
   `height`, `nrm` on the tested instance), whereas resource labels include
   `Base color`, `Roughness` and `Normal`. Export uses still other identifiers such
   as `basecolor`; inspect before substituting one naming scheme for another.
5. Save, reopen and export by public API. Verify generator resource, parameters,
   non-flat output and the intended pixel changes. Repeated setup must reuse a
   single named effect, not accumulate layers.
6. Apply the model's scoped preservation, color/normal/alpha and matched-view gates.
   Connector success proves control, not artistic quality or target-game readiness.

No global input, focus raising or window activation is part of this workflow.
An ambiguous selection, unexpected existing effect, missing parameter, PID change,
project switch, timeout or lost connection stops the dependent step. Inspect its
saved state and audit log; do not blindly repeat a possibly completed mutation.
