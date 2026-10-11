---
name: blender-organic-modeling
description: Model deforming organic game assets in Blender - people, riders, clothing and armour worn on a body, later animals - from reference research and a blockout on the target skeleton through optional sculpt, deformation topology, retopology, skin binding, pose tests and LODs. Use for character or creature modeling, retopology, weight transfer and deformation review. Not for buildings or static props (blender-architecture) and not for organic UVs (blender-organic-uv).
---

# Organic modeling (meshes that deform with a skeleton)

Generic Blender method for bodies, riders, clothing and armour worn on a body, and later animals, built for a
real-time game. It holds no game-specific numbers: the consuming project's game layer supplies the target skeleton,
the budgets, the reference assets it measured and the export route. This skill says how to build, bind and prove
the mesh. Rules are marked **must**, **should** or **may**; each reference gives every rule's check and its source
keys, listed in [sources](references/sources.md). A rule without an external source says it is a process rule or
names the reference measurement it compares against.

## Scope and routing

| Need | Where |
| --- | --- |
| Buildings, static props, lathed pots and profile bands | the separate `blender-architecture` skill (hard-surface); its rules (blockout of volumes, joint ownership, building budgets, atlas chain) are not organic rules |
| Organic UVs | the separate `blender-organic-uv` skill (declared garment seams, SLIM, mirror-exact unique layout, head priority, evaluator and gates); it starts after G2, G3 and the final silhouette. Never apply the architectural chart, conjoin or atlas rules to a character |
| Organic baking and texturing | not covered yet (candidate name `blender-organic-texturing`); the architectural baking skill's rules are not organic rules |
| Generated 3D references (TRELLIS image or text to 3D, re-posing a design into the bind pose, landmark fit) | the separate `image-to-3d-reference` skill; the generated mesh is a reference and bake source, never the deliverable |
| Scene, object and file naming, units and axes, export copy, counts, evidence levels | [asset conventions](../blender-asset-conventions/SKILL.md) |
| Driving the owner's live Blender | [live-session safety](../blender-mcp-safety/SKILL.md): log before risky calls; heavy work runs in `blender -b` |
| Game facts: skeleton donor, budgets, reference measurements, LOD logic, export route, bench test | the consuming project's game layer, never this package |

## Local prerequisites and bundled tools

Follow the [local-tool readiness guidance](../skill-library-audit/references/local-tools.md). Blender with `bpy`,
`bmesh` and `mathutils` does all checks; prefer background runs (`blender -b --factory-startup --python-exit-code 2
--python ...`: without the exit-code flag an uncaught exception exits 0 and reads as a pass, see
[scripts/README.md](scripts/README.md), "Direct form") and write renders and reports to the session scratchpad. Before live edits, confirm the connected Blender's version,
file, scene and objects without changing them; a live GUI session counts as screen control under most project
rules, so announce it first. The project supplies the target skeleton (armature or bone table) and the test
animations; without them, stop at the blockout.

The bundled background tools - the export-copy audit (triangles and n-gons, influence cap, weight sums and clean
limit, allowed bones and deform flags, `REF_` objects, Preserve Volume, donor bone heads and armature matrix, the
`flip_name` test, 8-bit weight sums) and the synthetic probes behind the `L` source keys - are described, with
their command lines, in [scripts/README.md](scripts/README.md). Run the audit at every gate from G2 on; its JSON
report goes in the handoff `qa` block.

## Session-start contract (G0)

Before modelling, agree and record in the phase handoff: the target skeleton (donor file, allowed weighted bones,
bind pose, origin), the frame and scale route, the reference asset and who measured it, the triangle budget and
influence cap per LOD, the skinning model, every animation the asset plays (and the mount for a rider), the
on-screen size at the game camera, the texture budget for the UV skill, the pinned references, design deviations,
the LOD decision and the weapon rig. A missing term is asked, never guessed. When the export route has never carried
new skinned geometry into the game, G0 also runs the falsifiable round trip on a small skinned specimen and the game
layer's bench test, before the blockout ([skinning and pose tests](references/skinning-pose-tests.md), section 12).
Details: [contract and blockout](references/contract-and-blockout.md).

## Workflow and gates

| Step | Work | Gate (passes when) |
| --- | --- | --- |
| 1 | References pinned; skeleton imported exactly through the export route; bind pose identified; for an unproven route, the specimen round trip | **G0**: contract complete; for an unproven route, the specimen round trip and bench result recorded before the blockout starts |
| 2 | Blockout on the skeleton, half-side with Mirror; silhouettes at the game camera beside a reference asset | **G1**: owner approves proportions, silhouette and budget before any detail (adjusting a placeholder is not approval); the handoff carries the delivery fields |
| 3 | Optional sculpt, only as a bake source ([sculpt and retopology](references/sculpt-retopo.md)) | - |
| 4 | The deforming mesh with deformation topology. At small budgets it is the clothed form itself - skin where it shows, garment where it covers ([clothing and armour](references/clothing-armour.md), section 0). Hinge rings and weights matched to the reference asset, shoulder straw, rigid mitt hands ([deformation topology](references/deformation-topology.md)) | **G2**: quick bind (deform flags on the allowed bones only) and pose test of that mesh in the primary pose and the clip extremes, linear-blend preview, before any UV work |
| 5 | Separate shells only for parts that leave the silhouette (flaps, brims, plates, plume, weapon), weighted from the final body ([clothing and armour](references/clothing-armour.md)) | **G3**: every shell passes the same poses; hidden body faces removed only after this proof; faces the mount covers kept unless the reference removes them |
| 6 | Final weights: clean, limit, normalize; mirrored correctly; all clips tested ([skinning and pose tests](references/skinning-pose-tests.md)) | metrics no worse than the reference asset; **final silhouette**: the G1 sheet rerendered on the finished mesh with every layer and the weapon ([contract and blockout](references/contract-and-blockout.md), section 10) |
| - | UVs, bake, textures: other skills, which start only after G2, G3 and the final silhouette | - |
| 7 | Export copy: triangulated, layers trimmed, names exact, hashes recorded; the round trip through the converter repeated on the finished asset | **G4**: Blender and game file agree on meshes, triangles, bones and influence maximum; bundled audit passes |
| 8 | Low LOD if decided: by hand, own skeleton file, silhouette kept ([LOD](references/lod.md)) | **G5**: LOD bind, weights and silhouette checks pass |

Each gate's evidence (numbers, renders) goes to the owner as it lands; a file on disk is not a result.

## UVs

Organic UV unwrapping belongs to the separate `blender-organic-uv` skill. What this skill hands over to it:

- the texture budget from G0 (which meshes share which page, its size; a skinned weapon on the body page, attached
  models on their own pages) and the reference units the gates are measured on;
- an export copy that is triangulated, final in vertex order and **mirror-exact across x = 0 with a centre edge loop**
  (the organic layout writes the -X islands as exact reflections and needs mirror partners for every vertex);
- one part label per polygon (a face attribute or a part map) and, for ring-built bodies, the ring and slot vertex
  attributes: the declared seam rules are written against them;
- the seam-relevant decisions: hard edges on seams, material breaks, player-colour regions.

Start no UV work before G2, G3 and the final silhouette pass, and do not borrow the architectural chart, conjoin,
AO-separation or atlas rules for a deforming body.

## Handoff and journal

- Write a `HANDOFF.json` at the end of every phase by the project's phase-handoff contract. In this library it is
  hosted by the hard-surface texturing package: `blender-architecture-texturing/references/handoff-contract.md` and
  `blender-architecture-texturing/scripts/handoff.py`. Blockout, sculpt (HIGH) and the skinned LOW belong to phase
  `01_geometry`; pose, weight and silhouette evidence goes in `qa`; references, deviations and contract terms go
  under `conventions`. A handoff that asks for the owner's review needs `primary_blend`, `active_scene` and
  `delivery.live_readback` ([contract and blockout](references/contract-and-blockout.md), section 9). The
  conventions package explains the mapping.
- Record lessons the moment they happen in the [workflow journal](../workflow-journal/SKILL.md); use stage
  `modeling` until a skinning stage exists.
- Keep machine checks, delivery to the owner and owner acceptance as separate facts.

## The mistakes that cost the most

- Rebuilding or "cleaning" the target armature, or modelling in another pose than its bind pose: every reused clip
  then shifts the mesh.
- Modelling first and proving the export route last: an unproven route is tested at G0 on a specimen.
- Spending a small budget on hidden anatomy: a bare body under full clothing, deleted afterwards.
- Approving joints with Preserve Volume on, or after testing only frame 0 of an idle.
- Trusting automatic weights or the viewport: up to 5 influences and sums off by 0.09 were measured; leaving the
  deform flag on root, prop or chain bones, which then collect body weight. Run the hygiene chain with explicit
  arguments, on a mesh already bound to the armature.
- Mirroring weights on Biped-style names (`Bip01 L Thigh`): Blender pairs nothing and says nothing.
- A closed skirt tube between the legs, or a layer limited to fewer influences than the body under it.
- Remeshing or decimating the deliverable: vertex groups and UVs are lost, slivers appear.
- Starting UVs before the deforming body passed its pose test.
