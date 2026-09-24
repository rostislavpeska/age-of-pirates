# Connection, troubleshooting and provenance

## What actually worked here

The cathedral/Ostinder session called `New-Object -ComObject Photoshop.Application`
and then `DoJavaScriptFile(absoluteJsxPath)` from a local shell. JSX ran inside the
desktop application, accessing live documents, layers and unsaved pixels. The
export scripts saved the source, duplicated it, flattened the duplicate and wrote
TGA maps. This did not require a Photoshop MCP server or a Photoshop Python module.

The bundled runner improves the historical connection: `GetActiveObject` attaches
only to a running instance, avoiding the possible application launch from
`New-Object`. Windows PowerShell 5.1 supplies that .NET Framework method. Always
invoke `powershell.exe` explicitly; a shell named PowerShell may actually be `pwsh`
(PowerShell 7). The attached instance must be verified by its document inventory.

Recovered evidence on 2026-09-24:

- Original tool calls executed the COM/JSX route, including Ostinder live-document
  exports on 2026-09-20. The historical constructor is evidence, not the preferred
  attach-only preflight for a new session.
- Scratch workspace scripts `tools/export_active_ostinder_details.jsx` and
  `tools/export_current_ostinder_details_and_masks.jsx` demonstrate the source ->
  duplicate -> TGA sequence. Their old file paths/channel settings are examples,
  not portable defaults or a reason to execute them on current assets.
- The operator's incident record describes incorrect lion orientation, repeated
  regeneration over manual edits and editable PSD/export divergence. Successful
  application access did not make those artwork decisions correct.
- A new read-only COM call connected to Photoshop 19.0.0 (CC 2018), with two open
  documents. This proves local access for that session, not all other agents.
- The bundled helper and scratch smoke test subsequently passed on that session:
  the PSD reopened with three layers and its guide hidden; the TGA was 32 x 32 RGB.
  An independent pixel check found the expected gray background and red painted
  center, with the hidden green guide excluded. The test preserved the existing
  document IDs, saved states, selected layers and active document. This verifies
  layered RGB/24-bit export only; alpha export, other Photoshop versions and
  engine-specific conversion were not tested in this skill-creation task.

The previous texturing skill required a working editor connection but omitted
these concrete invocation steps. We have not inspected every failing agent's
environment; their individual failure causes must be established by the probe.

## Diagnose the actual boundary

| Observation | Action |
| --- | --- |
| No Photoshop MCP tools | Try the local COM probe. MCP availability is a separate issue. |
| Shell is Linux/cloud with no Windows desktop execution | This route is unavailable there. Use an authorized Windows agent/connector. |
| WSL can execute Windows programs | Use Windows `powershell.exe` and Windows paths, then probe; interoperability alone does not prove app access. |
| `GetActiveObject` missing | Use Windows PowerShell 5.1, not PowerShell 7. Do not install Python packages to solve this. |
| Cannot attach / `0x800401E3` | Confirm Photoshop is running, the user/session and elevation match, and COM registration exists. Do not launch or repair registration implicitly; on the operator's word use `scripts/start_photoshop.ps1`. |
| `Photoshop.exe` running, no main window, still `0x800401E3` | Seen 2026-09-24: a windowless instance with two PSDs open did not attach, and a new launch became a **second** instance beside it. List PIDs and command lines (`Win32_Process`), leave that process alone and ask before starting another copy. |
| Class not registered | Inspect the installed version/registration. Skill discovery does not install Photoshop or its license. |
| Wrong documents | Stop before writes; reconnect to the intended session. A process name alone does not identify the document. |
| Call rejected / `0x80010001` / server busy | A modal dialog or ongoing operation may block COM. Resolve the actual blocker; retry read-only once when ready. Do not loop a mutating script. |
| JSX syntax error or `require`, `batchPlay`, `executeAsModal` unavailable | This is ExtendScript/ES3, not UXP, Node or browser JavaScript. Use the installed version's API. |
| Tool timed out | Photoshop may still be executing. Inspect live documents and outputs before retrying; never kill Photoshop to clear a timeout. |

An execution-policy/permission block remains a real boundary. Do not change machine
policy, auto-elevate, install plugins or bypass an agent's restrictions to hide it.
The manual fallback is **File > Scripts > Browse**, using the same reviewed JSX;
do not claim automated execution if the operator ran it.

## Authoritative references

- [Adobe: scripting in Photoshop](https://helpx.adobe.com/photoshop/using/scripting.html)
  documents Windows COM automation and Photoshop scripting.
- [Adobe Photoshop developer entry point](https://developer.adobe.com/photoshop/)
  distinguishes ExtendScript and newer extension options.
- [Adobe: UXP scripting](https://developer.adobe.com/photoshop/uxp/ps_reference/media/uxpscripting/)
  documents the separate `.psjs` runtime. Do not copy UXP examples into CC 2018 JSX.

Read only the relevant reference if an API/version question remains; broad new MCP
research is unnecessary when the local probe and required operation already work.
