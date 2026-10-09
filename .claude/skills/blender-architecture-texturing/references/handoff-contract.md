# Phase handoff contract (every 3D asset, every agent)

Owner rule (2026-09-28): outputs are standardized per phase so any agent can take over at any phase and
**consume** the previous phase instead of reinventing it. All work is agent-agnostic (Claude, GPT/Codex,
Gemini, a human). A phase is not finished until its `HANDOFF.json` exists and validates.

## Primary final deliverable: the finished Blender scene

Owner clarification, 2026-10-09: the final handoff is a **Blender scene containing
the finalized models**. `HANDOFF.json` identifies and verifies that artifact; it
does not replace it. Name the entry `.blend` and its active scene explicitly.

For a completed textured-model handoff, that scene opens directly to every named
finished model in the agreed batch, with final geometry, actual UVs, assigned
materials, normal/alpha/processed-AO bindings and required props/attachments within
the agreed scope. Use a readable framing and lighting setup. Diagnostic duplicates,
old candidates and HIGH bake sources must not obscure or masquerade as the final
models. Keep the full required UV operator workspace and authoring sources as
clearly separate supporting deliverables; a clean final scene does not remove them.

Save and reopen the actual delivered file. Verify model/part identities, materials,
packed images or portable dependencies, and the default visible scene; personally
inspect images rendered from that reopened scene. Link the `.blend` as the primary
handoff. Unresolved required geometry/material/texture defects prevent a final
completion claim. A candidate remains a candidate until the agreed acceptance gate;
calling its file "final" does not establish acceptance or engine compatibility.

When the owner requests that result in their open Blender, publish it there and
read back the **live window's** active file, scene, visible model identities,
material preview mode and bound images. A correct disk package or a documentation
update cannot establish live publication. Preserve dirty work before switching;
save the review state and verify the saved active scene. Record disk delivery and
live delivery separately. Evidence: Korean Houses INC-183, 2026-10-09: texture r13
was on disk while the owner still saw the older AO/UV r5 scene.

## Delivered means visible in the owner's Blender (enforced)

Owner, 2026-10-09: "this handoff contract should be unbreakable". A checkpoint was reported as delivered while the
owner's viewer still showed an older file. Files on disk, a published package or a pointer write are not delivery.

- **Enforced by `handoff.py` (schema 2).** A handoff that asks for the owner's review or acceptance must carry three
  things, or `write` refuses it and `check` reports drift. This means `owner_review: pending`, status `review` or
  status `accepted`.
  - `primary_blend`, a canonical `.blend` entry;
  - `active_scene`;
  - `delivery.live_readback = {version, file_sha256, scene, viewer, at}`. The file hash must equal the primary
    `.blend` and the scene must equal `active_scene`.
- **Accepted also records his words:** `owner_acceptance = {quote, at}`.
- **The readback comes only from the live viewer pair** in
  [blender-uv-observability](../../blender-uv-observability/SKILL.md):
  - `live_viewer.py` runs in his Blender. It loads every newer version at once and stashes unsaved edits to a
    recovery copy rather than waiting. It writes a heartbeat.
  - `live_publish.py` publishes and waits for a fresh heartbeat with the same bytes and scene. Exit 0 writes
    `LIVE_READBACK.json`. Exit 4 means NOT VISIBLE: say "published, not delivered" and why. Never say done.
- **Library packages are re-checked.** The publisher refuses a staged HANDOFF that asks for review without a
  matching readback, or that was hand-written outside `handoff.py`.
- **Order:** stage → `live_publish.py` (readback) → `handoff.py write` with the readback → publish the package →
  report.
- **Schema-1 handoffs** written before this rule stay historical records.

## Phases (fixed ids)

| id | Canonical outputs (what downstream MUST consume) |
| --- | --- |
| `01_geometry` | LOW file + object names; HIGH files + object names (in place, same transforms) |
| `02_material_split` | per-face class (attribute name on the LOW + manifest), class palette (ID colours), change log |
| `03_uv` | `UV_Final` layer, per-face plan (page, owner, family, class), freeze fingerprint, `density` (measured block) and `page_budget` (rule 7) |
| `04_bake` | bake recipes, NORMAL / AO / OPACITY / EMIT (IDs) per page, coverage, bake reports |
| `05_sources` | texture sources with licence and provenance (CC0 / Substance / GPT-generated + seamless edit) |
| `06_surface` | per-page surface masks and projected sources on the frozen UVs |
| `07_compose` | final page maps (`<page>_BaseColor/Normal/Masks/Opacity.png`) + board maps |
| `08_review` | review `.blend` (one scene, board), QA report, shot sheet |
| `09_painter` | `.spp`, layer list, exported maps |
| `10_export` | GR2, `.material`, DDT, XML - see the engine export skill |

## HANDOFF.json (one per phase folder)

```json
{"schema": 1, "model": "Korean_TC", "phase": "07_compose", "status": "review",
 "producer": "claude", "date": "2026-09-28",
 "inputs":    [{"phase": "06_surface", "handoff": "../06_surface/HANDOFF.json"}],
 "canonical": {"P2048_BaseColor": {"path": "final/P2048_BaseColor.png", "convention": "sRGB 8-bit"}},
 "conventions": {"normal": "tangent space OpenGL +Y, UV_Final", "masks": "R=AO G=roughness B=metallic"},
 "qa": {"result": "pass", "report": "qa_report.json", "pictures": ["qa_sheet.png"]},
 "open_issues": ["..."], "next": "08_review: build the review scene from these maps",
 "reproduce": ["blender -b --factory-startup --python compose_textures.py"]}
```

`scripts/handoff.py write spec.json` hashes every canonical path and checks each input handoff exists;
`check HANDOFF.json` re-hashes and reports drift; `chain DIR` lists the phase chain and its status.

## Rules

1. **Start from the latest accepted (or review) upstream handoff.** Read its `canonical`, `conventions`
   and `open_issues` first. Consume those files; do not rebuild an upstream artifact from older sources.
2. **Change an upstream artifact only by a new version of that phase** (new folder / version, reason,
   owner approval where the pipeline requires it, e.g. a UV change after the freeze), never silently
   inside a downstream step. Downstream phases then re-run from their recipes.
3. **Carry identity, not appearance:** IDs (per-face class, family, owner) and palettes come from the
   upstream manifest; a downstream view (e.g. a ClassID board) uses the upstream palette, not a new one.
4. **Keep the other agent's work:** new files in your own versioned folder; never overwrite another
   producer's files; name the producer in the handoff.
5. **Handoff anywhere:** if you stop mid-phase, write the handoff with `status: wip`, what is done, what
   is not, and the exact command to continue.
   A WIP may consume the latest WIP handoff with its real source hash. It remains
   WIP: review/accepted output cannot consume a WIP parent. Never substitute an
   older accepted parent to satisfy the tool while working from a newer candidate.
6. Pictures and QA per [texturing QA](../../blender-high-low-baking/references/texturing-qa.md) belong in
   the handoff of every texturing phase.
7. **A UV phase passes the density floor and the page budget before the UV freeze.**
   - **`density`:** a 03_uv handoff in `review` or `accepted` records the metrics block of
     `scripts/density_floor.py`, measured on the final runtime pages. It must pass the universal
     [UV density floor](uv-density-floor.md).
   - **`page_budget`:** the same handoff records `pages: [{name, size}]`, exactly the pages the density block measured.
     Nothing else is self-declared (INC-034): the class, the owner's confirmation and the ceiling come from the
     project's model profiles (Age of Pirates: `<consumer-root>/scripts/havok/gr2_lint_profiles.json`, `--profiles`), and the
     confirmation must resolve to his message about this class and model in his store (`--owner-messages`).
   - **The density block is bound to the UV:** its `source.sha256` is the hash of one of this handoff's canonical
     files (`density_floor.py faces|gr2` records it), and it is in the game's unit (else INCOMPLETE).
   - **`handoff.py write` refuses** the handoff when either record is missing or fails.
   - **The owner's waiver** of the floor (`density_waivers`) requires verified
     explicit GO for the exact model, texture pages and measured candidate. Use
     the [density proposal contract](uv-density-floor.md) and
     `--owner-messages <his message store>`; a blanket model waiver is insufficient.
   - **A `wip` handoff** may stop before the measurement.
   - **The project's export gate re-checks both** against its own ceilings. Age of Pirates:
     `<consumer-root>/scripts/havok/gr2_lint.py`.

## Observable subcheckpoints (2026-10-06)

The [shared UV workflow](../../blender-uv-workflow/SKILL.md) owns the staged sequence.
Use `workflow_checkpoint: {path, sha256}` to attach its validated receipt to a
handoff. The receipt's asset must match `model`, and its input hashes must include
all canonical file hashes. Final `03_uv` review/accepted writes require a `freeze`
receipt, in addition to the existing measured density and project-budget checks.
A WIP handoff may carry accepted `clean`, `materials`, `share` or `ao` evidence;
this does not promote final UV status. Do not rename clean-chart acceptance to
freeze or invent missing historical reports. Existing assets remain recoverable.

`handoff.py check` now revalidates checkpoint ancestry and evidence, input handoff
hashes, and final UV density/budget. Pass the same `--profiles` and
`--owner-messages` used at write when these are not the project defaults.
Legacy final handoffs without the new evidence remain historical records; they
do not acquire a new workflow verification claim automatically.
