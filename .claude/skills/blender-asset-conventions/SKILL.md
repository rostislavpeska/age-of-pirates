---
name: blender-asset-conventions
description: Conventions every Blender asset pipeline in this library shares - scene, object and file naming, units and axes, authoring source versus export copy, evidence levels, and where the shared phase-handoff, live-delivery, journal and live-session safety contracts live. Load with any Blender modeling skill; holds no modeling method.
---

# Blender asset conventions (shared by hard-surface and organic work)

This package is neutral ground. It holds the conventions that both the hard-surface skills (buildings, props)
and the organic skills (characters, riders, clothing on a body, animals) follow, so neither side links into the
other. It contains no modeling method. Rules are marked **must**, **should** or **may**.

| Concern | Where it lives |
| --- | --- |
| Units and axes, object and file naming, authoring source versus export copy, counts, evidence levels | [scene and export conventions](references/scene-and-export.md) |
| Live Blender session safety: log before risky calls, crash register, recovery | [live-session safety](../blender-mcp-safety/SKILL.md) |
| Shared lessons recorded at the moment they happen | [workflow journal](../workflow-journal/SKILL.md) |
| Local application readiness (Blender version, session, background route) | [local-tool readiness](../skill-library-audit/references/local-tools.md) |
| Phase handoff contract and its writer | `blender-architecture-texturing/references/handoff-contract.md` and `blender-architecture-texturing/scripts/handoff.py` (hosted by the hard-surface texturing package for now) |
| Live delivery readback (what "delivered" means) | `blender-uv-observability/scripts/live_publish.py` with `blender-uv-observability/scripts/live_viewer.py` (standard library plus `bpy`; generic code in a UV-centred package) |
| Organic UVs: seam rules, unwrap, layout, evaluator, gates, delivery pictures | `blender-organic-uv` (its own; the hard-surface UV packets do not apply to a deforming body) |
| Texturing QA, vision inspectors | hard-surface packages only, until an organic texturing skill exists |

The pointers above are written as package-prefixed paths, not links, on purpose: a link would make every
consumer of this package depend on the whole hard-surface UV and texturing suite. Open the file by path when the
step needs it.

## Using the phase handoff from organic work

The fixed phase ids of the handoff contract already fit a character:

- blockout, optional sculpt (HIGH) and the retopologized, skinned LOW all belong to `01_geometry`, whose canonical
  outputs are the LOW file with its object names and the HIGH files with theirs;
- pose tests, weight checks and silhouette renders go in the handoff's `qa` block with their pictures;
- skeleton donor, scale route, budgets and the LOD decision go in `conventions` and `open_issues` until the
  owner settles them.

No new phase id is needed yet. A skinning-specific id or journal stage is a planned change (below), not a
convention to invent per task.

## Planned moves (each needs the owner's approval; none is in force)

1. Move the live viewer pair and its tests from `blender-uv-observability` into this package and update every
   caller.
2. Split the handoff contract: its generic part moves here, the UV density and page-budget rules stay with UV.
3. Add a `skinning` stage to the workflow journal (today: use `modeling`).
4. Extract a generic core of the project's skinned-model checker if organic assets are exported outside one game.
5. Forward the rules that [scene and export conventions](references/scene-and-export.md) sections 3 and 4 restate
   (authoring source versus export copy, counts): the hard-surface skills still hold their own copies
   (`blender-architecture/SKILL.md` step 4, `blender-architecture/references/construction.md` "Counts",
   `blender-clean-uv/SKILL.md`, `blender-overlap-cleanup/SKILL.md` step 4,
   `blender-high-low-baking/references/process.md` section 4). Replace each copy with a plain-name pointer to this
   package; for a skill on a public export allowlist, also add this package to that allowlist first, so its closure
   stays complete.

Until a move happens, the current host path above is the only source; never copy it here.
