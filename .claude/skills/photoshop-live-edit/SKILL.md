---
name: photoshop-live-edit
description: Control an open desktop Photoshop document through Windows COM and ExtendScript, preserve manual layered edits, and export verified texture maps. Use for live PSD editing, masks, source synchronization, or exports when Photoshop MCP is absent or insufficient.
---

# Live Photoshop editing and export

Use the user's live Photoshop document as the source. This workflow is agent-neutral:
it needs local Windows command execution in the user's desktop session, not a
particular model, agent extension or Photoshop MCP server. It was recovered from
successful Photoshop CC 2018 operations in this project; other installations need
the probe below. A skill teaches the route; it does not grant tools or permissions.

## Connect before declaring Photoshop unavailable

If an available Photoshop connector already provides the required live operations,
use it. Otherwise use this verified Windows route:

**Windows PowerShell 5.1 -> Photoshop COM -> ExtendScript `.jsx`.**

From the repository root, run this read-only inventory:

```powershell
powershell.exe -NoProfile -NonInteractive -STA -File .claude/skills/photoshop-live-edit/scripts/photoshop.ps1
```

Outside this repository, substitute the absolute installed skill path. The helper
attaches to an existing application; it never launches Photoshop, saves documents,
changes layers or installs anything during the inventory. It reports Photoshop
version, open document IDs/paths, unsaved state, selected layers and layer structure.

Read [connection diagnosis and evidence](references/connection.md) if it fails.
Do not equate a missing MCP entry with an unavailable application. Do not install
a new server, use screen clicks, or repeatedly retry failing calls when a working
script route is available. A cloud agent without Windows desktop access cannot use
this route merely by reading this skill.

## Identify and protect the source

- Select the intended document by **session ID plus expected name/path**, not by
  whichever tab is active. IDs change after reopening. Unsaved documents may have
  no path. If the target is ambiguous, ask one precise question before changing it.
- The live state wins over an older PSD/TGA or generated intermediate when the
  operator has edited it. Inspect layer visibility and the active layer/channel;
  do not activate a presumed alternative when asked to export the current version.
- Before an edit, save a layered checkpoint of the live state outside runtime
  asset folders. A disk copy of an old PSD does not protect unsaved edits. Preserve
  the previous disk version before overwriting it, when applicable.
- For export-only requests, change no artwork, UVs, transforms, masks or visibility.
  Capture/save the live source and export that exact composition. Hidden checking
  overlays stay hidden; if a guide is visibly enabled, resolve intent before
  hiding it. Never rerun a layer-construction script over manual corrections.

## Execute small, reviewable operations

Read [editing and export recipes](references/edit-export.md) for the scripting
pattern, data-map precautions and safe PSD/TGA handling. Write a task-specific JSX
file to scratch, inspect it, then run:

```powershell
powershell.exe -NoProfile -NonInteractive -STA -File .claude/skills/photoshop-live-edit/scripts/photoshop.ps1 -ScriptPath "C:/scratch/task-edit.jsx"
```

This executes code with Photoshop's authority; `-ScriptPath` is **not** a read-only
mode. Keep operations within the user's task. Batch related edits in one short JSX
call, execute Photoshop operations sequentially, and return a compact result.
Preserve the original active document and restore global preferences in `finally`.
Do not close user documents or quit the application unless requested.

Keep requested changes editable: named layers, masks and adjustments in the PSD.
Use current approved pixels as the base if the user requests simplification, with
only the checking overlays they want. Flat exports alone do not update the PSD.
For technical texture work, preserve dimensions, UV orientation, channel packing
and data values outside the requested mask. Never guess a flip from an oblique
model view; verify the specific UV island and relevant sail/face before transforming.

## Finish where the operator works

Save the layered source, export from a disposable duplicate, verify exported
dimensions/channels and requested pixel changes, then use the destination pipeline
if conversion/installation was requested. For AoE3DE, consult the relevant project
texture/conversion workflow for DDT flags and packed channels; do not invent them.
Verify installed files against the validated outputs. Refresh the intended live
Blender images if requested and report which application actually received changes.
Use matching view/lighting comparisons and yield for manual feedback when needed.

Do not say “updated in Photoshop” for an external PNG edit, “in Blender” for a
background-only scene, or “in game” before the installed files are verified.
One uncertain visual correction should lead to a focused check, not repeated
unverified rotations, regeneration or an expanding layer stack.

## Verification

The default probe is read-only. The optional [scratch smoke test](scripts/smoke_test.jsx)
creates and exports a tiny temporary layered document, verifies reopened outputs,
and closes only its own documents. It writes under the Windows temporary folder;
do not run it under a strict no-write instruction. Run it once when establishing
compatibility, not before every export. Connection success does not prove visual
correctness or target-engine compatibility.
