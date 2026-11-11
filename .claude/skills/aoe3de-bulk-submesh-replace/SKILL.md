---
name: aoe3de-bulk-submesh-replace
description: "AoE3 DE adapter for replacing repeated props (lanterns, crates, barrels, posts) baked into composite scene meshes: which meshes, the connector material, the rope and post UV stripes, material slots and textures. Use with Blendify blender-complex-scene (repeated props section) and aoe3de-complex-scene-export."
---

# AoE3 DE repeated props in composite meshes

The method - find each prop as a connected face island inside its material slot, merge multi-part props, normalize the
template to an anchor, swap in place with bmesh, verify the unit count - is generic: Blendify
[blender-complex-scene](../blender-complex-scene/SKILL.md), section "Repeated props baked into one mesh", with
`scripts/mesh_islands.py` and `scripts/path_tube.py` (moved there 2026-10-17; outputs checked identical). The scripts here
are shims that keep the old import names and the AoE3 defaults: `cluster_submesh.py` (`find_submesh_components`,
`deduplicate_multi_part_clusters`) and `catenary_rope.py` (`generate_rope_mesh`). Export the result with
[aoe3de-complex-scene-export](../aoe3de-complex-scene-export/SKILL.md) (rule 6, conjoined props: in-place GR2 buffers,
never whole-model conversion).

## AoE3 rules

1. **Composite geometry is not separate objects.** Home City and environment assets (`props.gr2`,
   `lantern_upgrade.gr2`, `bridgesandstuff.gr2`, `*_GEOShape` meshes) bake dozens or hundreds of props into single
   meshes. Never replace the whole object or split it away from its `Armature` parent: that breaks the scene graph and
   the Havok bindings.
2. **Connectors stay.** Ropes and wires use material `mate`; filter the island search to the prop slot so connectors are
   never deleted with the prop bodies. Where vanilla lacks a connector along a span (missing eave ropes), rebuild a
   continuous 4-sided tube through the prop top anchors (`generate_rope_mesh`), normals outward.
3. **UV stripes on the shared atlas** (Blender V = 1 - GR2 V):
   - Rope fiber stripe: Blender V 0.018..0.066 (GR2 V 0.934..0.982).
   - Vertical wooden posts: Blender V 0.514..0.974.
   - Prop templates authored in Blender space (Japanese lanterns, V 0.003..0.864) keep their V: inverting it makes the
     top dome sample the dark thatch/rope stripe.
   - **Open:** `generate_rope_mesh`'s default V 0.957..0.967 lies in the GR2 stripe range, not the Blender one above,
     yet the tube is injected into a Blender mesh. Check the default against the atlas before relying on it
     (2026-10-17: not verified in game or render).
4. **Material slots and textures.** Keep connectors and replacement props in separate slots (e.g. slot 0 ropes, slot 1
   props) with full graphs: `*_BaseColor.png`, `*_Normals.png` (Non-Color, `ShaderNodeNormalMap`), `*_Masks.png`
   (Non-Color, roughness/metal), and `*_Emissive.png` for lit lanterns and torches. Pack the images (`img.pack()`).

## Checks

- Scene object count unchanged; the edited object keeps its `Armature` parent and transform.
- Replaced units = inventory count; `mate` connector triangles unchanged unless a rebuilt span was intended.
- No floating props: each hangs from a continuous rope or sits on a surface, checked at game camera distance.
- Materials in Material Preview; textures packed.
