---
name: blender-uv-observability
description: Build and verify an operator-facing Blender UV workspace with real editable mapping, measured density, concrete material allocation and actual sharing families. Use when publishing or repairing live UV review views; delegates unwrap, conjoin and AO to their specialist skills.
---

# Observable UV workspace

**DRAFT — owner workspace review first, then deep audit and standardization.**
The current owner requires simultaneous copies, not mode-switched scenes:
standard Blender density checker, four resource isolations with everything else
black (walls, roofs, generic, pottery), and conjoined-family colors. For three
Houses this means 18 visible models. This overrides the earlier three-mode UI.
The project/subproject supplies allowed square page sizes and texture policy.
Painting subtypes (planks, beams, red wood, stone blocks/solid stone, roof field,
ends and ridges) are distinct from runtime resource ownership.

This is the operator interface of the multi-skill
[UV workflow](../blender-uv-workflow/SKILL.md), not an unwrap algorithm.
Read [the contract and research](references/contract.md) before publishing it.
Use the project's existing job, version, handoff and incident systems.

Provide three reachable views of the **same revision and model census**:

1. Density: actual UV image and checker, measured two-axis texels/unit and target,
   with below-target faces identifiable. A generic checker is not a measurement.
2. Materials: named physical finishes, actual intended texture owner/cell and
   backing versus unique allocation. State unresolved bindings. Compare the
   project's accepted references; a material-ID rainbow is insufficient.
3. Sharing: colors identify actual owner/member texel families; unique charts are
   gray. Preserve chart, face, family and owner IDs. Before sharing exists, label
   this view pending, expose only already verified shared resources, and never
   portray arbitrary chart colors as completed conjoinment.

In every mode the UV Editor shows the active editable UV layer and the image
actually used by the displayed mesh. Image dimensions, shader UV node, editor
image and selected page scope must agree. Select one texture page at a time;
different page coordinates must not be overlaid on one unrelated image.
For an unpacked worksheet use a matching canvas or explicit tiled image. A
rectangular-canvas conversion must preserve pixel coordinates and measured
density; it is not permission to repack, rescale detail or enlarge runtime pages.

Show phase, revision, model/page selector, current operation, last result, failed
attempts, pending work and a compact legend in Blender. Keep before/candidate
recoverable. Existing screen-control authorization and MCP safety rules apply.
The operator must be able to select a part and see its actual islands without
asking the agent to synthesize a new picture.

After publishing, independently read back all three modes and a representative
selection on each page/model. Run `scripts/contract.py` on the extracted evidence,
retain failure fixtures, and inspect an actual live screenshot after redraw.
Saved files and status prose do not establish live correctness. Integrate the
result into the workflow checkpoint's `operator_view` check. Missing evidence
blocks promotion; authorized WIP repair continues with its failures visible.
No prose contract makes an unrestricted tool environment literally unbreakable.
These checks detect specified failures; project callers must run them and visual
quality remains an operator decision.
