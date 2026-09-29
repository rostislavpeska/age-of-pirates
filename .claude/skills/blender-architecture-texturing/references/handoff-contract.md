# Phase handoff contract (every 3D asset, every agent)

Owner rule (2026-09-28): outputs are standardized per phase so any agent can take over at any phase and
**consume** the previous phase instead of reinventing it. All work is agent-agnostic (Claude, GPT/Codex,
Gemini, a human). A phase is not finished until its `HANDOFF.json` exists and validates.

## Phases (fixed ids)

| id | Canonical outputs (what downstream MUST consume) |
| --- | --- |
| `01_geometry` | LOW file + object names; HIGH files + object names (in place, same transforms) |
| `02_material_split` | per-face class (attribute name on the LOW + manifest), class palette (ID colours), change log |
| `03_uv` | `UV_Final` layer, per-face plan (page, owner, family, class), freeze fingerprint |
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
6. Pictures and QA per [texturing QA](../../blender-high-low-baking/references/texturing-qa.md) belong in
   the handoff of every texturing phase.
