---
name: aoe3de-bulk-submesh-replace
description: "Detect, isolate, and bulk-replace repeated prop submeshes in complex composite AoE3DE scenes while preserving connectors, materials, and transforms."
---

# AoE3 DE Bulk Submesh and Composite Prop Replacement

This skill provides an automated, non-destructive workflow for identifying and bulk-replacing repeated props (such as lanterns, barrels, crates, lamps, posts) that are merged into complex composite scene meshes (`*_GEOShape`, environment props, Home City assets).

It preserves rest-pose coordinate systems, armature parenting, bone bindings, and structural connectors (such as ropes, wires, and mounting brackets).

---

## Forensic Core Rules

1. **Composite Geometry is Not Separate Objects:**
   In AoE3 DE Home Cities and environment assets (`props.gr2`, `lantern_upgrade.gr2`, `bridgesandstuff.gr2`), dozens or hundreds of repeated props share single unified meshes. Never attempt whole-object replacement or split objects away from `Armature` parents, as this invalidates scene graphs and Havok bindings.

2. **Always Isolate by Component Topology, Not Vertex Range:**
   Repeated props are connected components of triangles within a material group. Use union-find disjoint sets over polygon edge adjacency to identify each separate prop unit. Verify component triangle count or bounding box dimensions before selecting for deletion.

3. **Multi-Part Prop Clustering:**
   Many props consist of separate disjoint elements (e.g., a lantern body, a hanging ring, and a tassel). Group components whose centroids fall within a proximity threshold ($\le 0.15\text{ m}$) into a single logical entity before calculating placement centroids and anchor points.

4. **1:1 Isotropic Scaling and Template Normalization:**
   Replacement templates must be clean, manifold, and scaled $1:1$ isotropically ($\Delta X = \Delta Y$). Normalize the template so that its local origin $(0, 0, 0)$ corresponds to a defined functional anchor (e.g. top hanging ring for lanterns, base for grounded props).

5. **Connector / Cable Continuity Preservation:**
   When replacing props suspended from or connected by ropes/cables:
   - Identify connector submeshes (e.g. material `mate`) and never delete them with the prop bodies.
   - If vanilla assets lacked connectors along certain spans (e.g. missing roof eave ropes), reconstruct continuous 4-sided tube geometry passing through prop anchor loops.
   - Ensure tube normals face strictly outwards and UV coordinates sample the authentic fiber stripe: in Blender authoring space (origin bottom-left), the rope stripe is $V \in [0.018 \dots 0.066]$ (corresponding to raw GR2 $V_{gr2} \in [0.934 \dots 0.982]$ via $V_{blender} = 1.0 - V_{gr2}$). Vertical wooden posts sample $V \in [0.514 \dots 0.974]$.
   - Prop templates authored in Blender space (e.g. Japanese lanterns with $V \in [0.003 \dots 0.864]$) must NOT have $V$ inverted during placement, otherwise the top dome erroneously samples the dark thatch/rope stripe.

6. **Multi-Material Separation:**
   Keep connectors and replaced props in distinct material slots (e.g. Slot 0 for ropes, Slot 1 for replacement props). Configure complete PBR graphs (BaseColor, Normals, Masks/Roughness, Emissive) and pack textures into the `.blend` file.

---

## Step-by-Step Workflow

### Step 1: Submesh Cluster Detection & Extraction
Use `scripts/cluster_submesh.py` to scan the target mesh:
```python
from cluster_submesh import find_submesh_components, deduplicate_multi_part_clusters

# Find components within the target material slot (e.g. mata / slot 1)
raw_comps = find_submesh_components(mesh, material_index=1, min_face_count=20)
props = deduplicate_multi_part_clusters(raw_comps, proximity_threshold=0.15)
print(f"Detected {len(props)} distinct prop units to replace.")
```

Each detected prop provides:
- `centroid`: 3D center point $(X, Y, Z)$
- `top_anchor`: Highest vertex (e.g. hanging loop apex)
- `bottom_anchor`: Lowest vertex (e.g. base contact)
- `face_indices`: Exact polygons to delete

### Step 2: Prepare Clean Manifold Replacement Template
Load or author a clean replacement template (e.g. JSON format containing `verts`, `faces`, `face_loop_uvs`):
- Verify manifoldness (zero non-manifold edges).
- Check that loop normals and face winding point outward.
- Define anchor offset relative to origin (e.g. $Z_{top} = 0.0\text{ m}$).

### Step 3: In-Place Geometric Substitution
In Blender using `bmesh`:
```python
import bmesh

bm = bmesh.new()
bm.from_mesh(mesh)
bm.faces.ensure_lookup_table()

# 1. Delete original prop faces
faces_to_del = [bm.faces[i] for prop in props for i in prop['face_indices']]
bmesh.ops.delete(bm, geom=faces_to_del, context='FACES')

# 2. Instantiate replacement templates at anchor points
for prop in props:
    target_pos = prop['top_anchor'] # or centroid
    for v_co in template_verts:
        bm.verts.new(v_co + target_pos)
    # Add template faces with material_index = replacement_slot
    # Transfer loop UVs to active UV layer

bm.to_mesh(mesh)
bm.free()
mesh.update()
```

### Step 4: Catenary Rope / Connector Reconstruction
If connecting cables or ropes are broken or missing:
Use `scripts/catenary_rope.py`:
```python
from catenary_rope import generate_rope_mesh

# Trace waypoints through prop top anchors and structural posts
waypoints = [post_start] + [prop['top_anchor'] for prop in prop_run] + [post_end]
r_verts, r_quads, r_uvs = generate_rope_mesh(waypoints, radius=0.018)

# Inject into mesh with connector material slot (e.g. mate)
```

### Step 5: PBR Material Configuration
Ensure both connector and replacement materials have active PBR node setups:
- **Connectors (`mate`)**:
  - Base Color: `*_BaseColor.png`
  - Normal Map: `*_Normals.png` (`Non-Color` space via `ShaderNodeNormalMap`)
  - Roughness: `*_Masks.png` (`Non-Color` space)
- **Props (`*_Mat`)**:
  - Base Color: `*_BaseColor.png`
  - Normal Map: `*_Normals.png`
  - Roughness / Metallic: `*_Masks.png`
  - Emission Color & Strength: `*_Emissive.png` (for luminous lanterns/torches)
- Pack textures: `img.pack()` for all referenced images.

---

## Verification & QA Checklist

- [ ] **Object Count & Armature Parent:** Scene object count unchanged; target object retains its `Armature` parent and transform matrix.
- [ ] **Prop Unit Count:** Total replaced units match the inventory count exactly ($N_{polys} = N_{units} \times N_{template\_faces}$).
- [ ] **No Floating Elements:** Props are visibly suspended from continuous ropes or anchored to surfaces; zero floating gaps.
- [ ] **Normals & Winding:** Quad tube normals and template normals point strictly outward ($+Z$ outward for quad tubes).
- [ ] **Packed Textures:** All BaseColor, Normal, Mask, and Emissive images are packed directly into the blend file.
- [ ] **Viewports Redrawn:** 3D viewports tagged and verified in Material Preview shading.
