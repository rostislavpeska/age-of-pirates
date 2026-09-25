---
name: blender-architecture
description: Builds and repairs architectural Blender models with approved blockouts, realistic construction profiles, editable topology and monitored geometry budgets. Use for architectural blockout, modeling, topology repair and geometry review in Blender.
---
# Architecture modeling
Read [construction and review](references/construction.md) for geometry work. Before removing hidden faces or classifying low-detail backs, read [surface visibility and destruction](references/surface-visibility.md). Use the sibling `blender-architecture-texturing` skill for UV/material planning.

## Local prerequisites

Follow the [local-tool readiness guidance](../skill-library-audit/references/local-tools.md).

Use locally installed Blender with a verified operator or automation route. The
bundled mesh audit imports `bpy` and runs inside Blender, not ordinary Python.
Before live edits, inspect the connected application's version, file, scene and
objects without changing them. A configured path or an available MCP tool name
alone does not prove that the intended session is connected. Preserve unsaved work;
do not open a replacement session, install a bridge or upgrade Blender as part of
this check. If live control is unavailable, continue planning or agreed saved-copy
inspection and state that live edits remain blocked.

1. Verify the actual Blender process, file, scene and target objects before editing. A bridge returning a default cube while the building is open elsewhere is the wrong session. Do not edit it or silently open more instances. Saved-file inspection is a fallback, not evidence of live unsaved state.
2. Research the real building/style from photographs and architectural sources. Record URLs, viewpoints, dimensions/estimates and which decisions the evidence supports. Decorative geometry must be research-based.
3. Make a deliberately simple placeholder blockout: footprint, major volumes, floors, roofs and openings. Use proxies for columns and ornament. Present proportions and budget, then obtain explicit approval before detailed modeling. Adjusting a placeholder is not approval to detail it.
4. Plan seams, semantic material regions, module projection depths, density and AO before detailing. Keep a quad-based editable source; do not triangulate at the start. Use planar n-gons only where reliable. Triangulation belongs on an export duplicate, followed by inspection.
5. Unless the project specifies another budget, target 10,000–20,000 evaluated vertices for the whole building. Monitor base/evaluated totals and per-object counts after meaningful operations and before/after replication, modifiers, joins and splits. Warn near 20k. Treat 25k as a review threshold, not a new target; forecasted work beyond it requires explicit approval. Splitting does not reset the total allowance. Record any approved project-specific budget and tolerance. Simpler assets below 10k are fine.
6. Run `scripts/audit_mesh.py` after meaningful geometry changes. Preserve and compare original corner normals when extracting or deleting parts of an imported model, as described in [construction and review](references/construction.md). Count/UV/degenerate checks do not prove preserved shading, clean intersections, plausible profiles or runtime compatibility.
7. Save checkpoints. Inspect front/back/left/right, four corners, high/low and interior views after modeling and texturing stages. Reinspect each user-marked location and its mirrored/repeated counterparts. Do this proactively during autonomous work. An unviewed render is not verification.

Maintain a defect register: exact location/object/face, suspected cause, evidence, change, same-view comparison and test state. Completion reports distinguish geometry, textures, export and destination-runtime checks. Never claim a repeated defect is fixed everywhere after checking only one instance.
