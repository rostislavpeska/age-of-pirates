---
name: aoe3de-complex-scene-export
description: "Safely patch, reposition, drop geometry from, and export complex multi-model AoE3DE scenes (such as Home Cities and composite environments) without whole-model re-export mesh loss or coordinate frame misalignment."
---

# AoE3 DE Complex Scene Export and In-Place Patching

This skill governs the inspection, modification, selective triangle dropping, bone repositioning, and prop export for complex composite Age of Empires III DE scenes (particularly Home Cities).

## Forensic Core Rules

0. **Inventory first, then the smallest edit that keeps the vanilla animation (Korean docks01, 2026-10-17).** Before
   any per-object export, list every edited object's transform sources (object matrix = a moved "pivot", parent,
   delta transforms, constraints, armature pose, mesh-level edits) and every attachment drawing in the edited area
   (vanilla `china_boats` still drew four fishing boats absent from the Blender scene, one inside the new pier).
   Animated parts: keep the vanilla skeleton and the vanilla Idle; move vertices (measured, rule 7); a moved part whose
   pivot stays behind swings around it in game ("exaggerated, jumping") - freeze it by renaming its track in the vanilla
   anim (`gr2_rename.py IN OUT track OLD NEW`: same length, same sort slot, a name no bone has). Parts the vanilla Idle
   already places stay byte-vanilla. Owner: "I think we drift to overengineering!" - three game tests with converter-made
   Idles, root canonization and pivot moves (`gr2_bones.py`, `gr2_rest_anim.py`) misplaced the junks although model and
   anim each checked exact; those tools stay available but are not game-proven for this.
1. **Never recompile vanilla ground or composite building GR2s via whole-model FBX conversion.**
   Running `converter.py --format gr2` on full vanilla assets (such as `china_hc_ground` or `fillerbuildings_ijk`) drops large polygons, strips vertex buffers, alters UV precision, and destroys Havok/destruction bindings (shrinking 430 KB ground models to 145 KB).
2. **Use in-place triangle dropping (`gr2_droptris.py`) for removing buildings/clusters.**
   When user edits in Blender remove buildings from a filler set (e.g., removing houses from `fillerbuildings_ab` or `fillerbuildings_ijk`), identify the dropped triangle indices via 3D KDTree centroid matching against vanilla GR2 and run `gr2_droptris.py`. The resulting GR2 stays byte-for-byte identical in size, preserves all vertex structures, updates material group counts, and recomputes the header CRC32.
3. **Use in-place bone patching for repositioning attachment sockets.**
   Moving Town Center, Merchant Guild, or street tree attachment bones must be done by patching the bone's local transform and `InverseWorldTransform` inside the ground GR2 binary directly.
4. **Isolate added props (e.g. Market Stalls) into dedicated modular models.**
   Never join user-added props into vanilla bridge, wall, or ground meshes. Separate them into their own mesh, compile them cleanly via GXO/GR2, give them their own `.material`, and attach them to `ATTACHPOINT` in the animfile XML.
5. **Runtime XML and materials must have CRLF line endings.**
   Always convert runtime XML and `.material` files to CRLF (`check_art_eol.py --fix`) and validate with `xmlcheck.py`.

7. **Moved meshes: measure each one against the vanilla REST vertices, then refresh the boxes (2026-10-17).**
   The Blender HC scene shows every prop at its skeleton rest pose, not at the Idle anim's key 0. Map each edited
   object's world vertices with the contract below and compare them to the vanilla mesh: a same-count mesh is one
   rigid fit (Procrustes residual < 1e-4), a trimmed one is its object translation plus dropped triangles plus, if any,
   translated copies of vanilla triangles (`gr2_droptris.py` `"dup"`). Never reuse one object's fit for another: the
   Korean docks01 build moved boat 0 with boat 1's 73.33-degree fit and the pier by hand-picked shifts, ~20 m off, with
   vanilla bone boxes - neither was visible in game. Every in-place writer now refreshes the boxes (`gr2_bounds.py`);
   `gr2_lint` check `bounds` fails stale ones. Keep the vanilla Idle (rule 0); never freeze, edit or re-convert the
   converter's dump of the vanilla anim (garbage past ~15 frames).
   Worked recipe with its proof step: `age-of-pirates-koreans/tools/homecity_docks01.py`.
---

## 1. Coordinate Transformation Contract

The exact transformation between Blender metric world coordinates and Granny GR2 binary coordinates is:

$$\begin{aligned}
X_{gr2} &= -2.54 \cdot X_{blender} \\
Y_{gr2} &= 2.54 \cdot Z_{blender} \\
Z_{gr2} &= -2.54 \cdot Y_{blender}
\end{aligned}$$

And inversely:

$$\begin{aligned}
X_{blender} &= -\frac{X_{gr2}}{2.54} \\
Y_{blender} &= -\frac{Z_{gr2}}{2.54} \\
Z_{blender} &= \frac{Y_{gr2}}{2.54}
\end{aligned}$$

Measured on the Korean HC docks01 (2026-10-17, 826 unchanged pier triangles): this map is a reflection (det -1), so a
GR2 triangle is the Blender loop triangle with its corner order REVERSED, and GR2 UV = (u, 1 - v) exactly. Blender's
imported corner normals are NOT the vanilla normals (median dot 0.65): take normals/tangents from vanilla vertex bytes.

### GXO Coordinate Frame
In GXO text files (`v <x> <y> <z>`), coordinates are in **Blender metric world coordinates** $(X_{b}, Y_{b}, Z_{b})$. When `GXOConverterAge3DE.exe` compiles `.gxo` to `.gr2`, the converter itself performs the $-2.54\times$ axis transformation.

### Blender FBX Importer Bone Head/Tail Trap
When an FBX is imported into Blender, Blender creates dummy bone display vectors with ~20.55m length along $+Y$:
- `bone.tail` represents the actual GXO/engine attachment position.
- `bone.head` is shifted by $-20.55\text{ m}$ in $Y$.
Always instantiate props or calculate transforms using the actual attachment coordinate or `bone.tail`.

---

## 2. In-Place Triangle Dropping (`gr2_droptris.py`)

When buildings or structures are deleted from a complex filler building mesh in Blender:

1. **Calculate Triangle Centroids in Blender:**
   ```python
   mesh.calc_loop_triangles()
   verts = np.array([v.co for v in mesh.vertices])
   tris = np.array([[v for v in tri.vertices] for tri in mesh.loop_triangles])
   b_centroids = verts[tris].mean(axis=1)
   ```
2. **Transform Vanilla GR2 Triangles to Blender Space and Match:**
   ```python
   info = gr2_lint.read_raw(vanilla_gr2_path)
   pos_gr2 = info['meshes'][0]['pos']
   tris_gr2 = info['meshes'][0]['tris']
   pos_b = np.column_stack([-pos_gr2[:, 0]/2.54, -pos_gr2[:, 2]/2.54, pos_gr2[:, 1]/2.54])
   c_gr2 = pos_b[tris_gr2].mean(axis=1)
   
   tree_b = cKDTree(b_centroids)
   dists, _ = tree_b.query(c_gr2)
   dropped_indices = np.where(dists > 1e-3)[0]
   ```
3. **Execute In-Place Drop:**
   ```bash
   python scripts/havok/gr2_droptris.py <src.gr2> <plan.json> <out.gr2> --check
   ```
4. **Deploy & Wire:**
   - Write `.material` for the cloned model referencing vanilla textures.
   - Update `<attachment>` in the mod's animfile XML to reference the new model.

---

## 3. In-Place Bone Transform Patching

To move an attachment bone in `korean_hc_ground.gr2`:

1. Locate bone index $i$ in `skel['Bones']`.
2. Compute file offset:
   $$\text{pos\_off} = \text{sec0\_off} + \text{base} + i \cdot \text{stride} + 16$$
   $$\text{iwt\_trans\_off} = \text{sec0\_off} + \text{base} + i \cdot \text{stride} + 80 + 48$$
3. Pack new coordinates:
   $$\text{Position} = (X_{gr2}, Y_{gr2}, Z_{gr2})$$
   $$\text{InverseWorldTranslation} = (-X_{gr2}, -Y_{gr2}, -Z_{gr2})$$
4. Recalculate header CRC32:
   ```python
   crc = zlib.crc32(bytes(data[g.sec_table:])) & 0xffffffff
   struct.pack_into('<I', data, 40, crc)
   ```

---

## 4. Exporting Props (Market Stalls, Props, Benches)

1. Separate prop geometry from any accidentally conjoined environment meshes.
2. Build clean GXO file:
   ```
   mt "mata"
   b "BONE_MAIN" 0 1 0 0 0 1 0 0 0 1 0 0 0
   m "<mesh_name>"
   mb "BONE_MAIN"
   mm 1
   v <x_blender> <y_blender> <z_blender>
   vn <nx> <ny> <nz>
   vt <u> <v>
   ...
   f <v0> <v1> <v2>
   ```
3. Compile with:
   ```bash
   python scripts/havok/converter.py --format gr2 --bang <model.gxo>
   ```
4. Create matching CRLF `.material` referencing appropriate texture sets.
5. In `<animfile>`, declare attachment and attach to `ATTACHPOINT`.
