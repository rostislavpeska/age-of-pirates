# Local tools and readiness

Application binaries, licenses, game archives, plugins and live connections stay
on the user's machine. Skills ship instructions, wrapper source and declarations.
Installation, executable discovery, connection and tested capability are separate.

| Tool or capability | Evidence needed before dependent work |
| --- | --- |
| Blender | Installed version, intended file/scene/objects, unsaved state, working operator or automation route; `bpy` helpers run inside Blender |
| Photoshop | Installed/licensed product when required by the workflow; active layered document, unsaved state and required layer/export capabilities |
| Substance Painter | Installed version and verified integration for the requested project/texture-set operations |
| Resource Manager | Exact product/version and required format operation; do not guess an executable from this generic name |
| GR2 converter | Explicit local executable, known command interface and tested export profile; a successful exit/header is only a sanity check |
| GR2 inspector | Ability to read actual meshes, bones, bindings and bounds for the output; a viewer screenshot alone is insufficient |
| Game | Readable local archives for lookup; an authorized game session for runtime testing |
| Python dependencies | Distribution available in the chosen interpreter; packages installed elsewhere or inside Blender do not satisfy a standalone Python helper |

Use explicit task paths, existing local configuration or environment discovery.
Keep credentials and actual device paths out of public package files. The example
configuration maps tool ids to paths; it does not contain commands to execute.
Do not create a duplicate configuration source when the project already has one.

The audit only checks presence and labels it `present-unverified`. After the audit,
use a documented read-only session/capability check appropriate to the selected
tool. Verify that the connection reaches the intended document before mutation.
Never load a document with embedded code or run arbitrary probe commands as part
of the resource audit. A timeout or unexpected dialog requires inspection, not
automatic retries against the source.

When capability testing is needed, preserve unsaved work, use scratch copies and
record input/output identity and tool version. Do not install, upgrade, connect a
new account or add plugins as a preflight repair. Such changes need their own task
scope; an authorized task does not need a second confirmation for routine checks.

Missing optional software should not block unrelated operations. Missing required
software blocks its dependent step. Continue planning, document work and other
independent checks. A manual export can be an appropriate handoff; changing the
requested editor or flattening a layered source requires agreement. Never claim
live edits or runtime validation from a background copy or a structural audit.
