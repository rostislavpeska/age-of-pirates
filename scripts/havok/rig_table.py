"""Write the rig table straight from the Blender rig scene - no converter needed.
Output is the small text form the Granny tools already read (the converter's GXO lines).

Sail mode (default, unchanged since the sail pipeline):
  b "name" parent m00..m22 tx ty tz   absolute rest transform in armature space (row-major 3x3 = R transposed)
  m "sail_01_cloth" / mb "bone" / v x y z   every object whose name starts with sail_ -> its bone + vertex positions
Armature space of the rig scenes = engine units, x across, y along the ship, z up (engine = (-x, z, -y)), i.e. the
same frame and units as a converter GXO of a converter-made model, so gr2_addbones.py (--map mirror), gr2_splitmesh.py,
dmg_extract.py and dmg_bonetable.py take this file exactly like a converter dump.

    blender -b rig.blend --python scripts/havok/rig_table.py -- out.gxo

Skinned mode (a working mesh for pose tests; aoe3de-unit-model, 2026-10-11):
  mt "material" per material used, then b lines, then per mesh m / mb (bones carrying weight, armature order) /
  mm k (1-based material index, one per material the mesh uses) / per GXO vertex v, vn, vt, vw (4 weights, 4 1-based
  mb indices; unused slots weight 0 and slot 0's index) / fg k / f a b c (1-based, Blender winding = CCW).
  Bones are written in Blender's order (depth-first), or in the order of the armature object's custom property
  `gxo_bone_order` when it lists every bone (donor_to_blend.py stores the donor gr2's order there).
  A GXO vertex is one (vertex, UV, corner normal) combination, like the converter's dump of a gr2; UVs are written as
  Blender holds them (the converter's dump of a vanilla gr2 has V already flipped the same way), normals are unit
  corner normals in armature space. The mesh is taken with every Armature modifier switched off (rest shape, other
  modifiers applied). Positions and bone translations are multiplied by --scale.

    blender -b unit.blend --python scripts/havok/rig_table.py -- out.gxo --skinned [--armature NAME]
            [--objects NAME ...] [--scale 0.393700787] [--max-influences 4] [--quantize] [--triangulate]

  --scale 0.393700787 (1/2.54) turns a working scene in engine units into the units of a converter GXO dumped from a
  vanilla gr2, which is what pose_sim.py needs next to vanilla clips decoded by aoe3de-unit-model's clip_decode.py
  (export-routes.md).
  --quantize stores weights as k/255 (sum 255, every kept influence at least 1/255), as the game's uint8 slots hold
  them. --triangulate takes Blender's own triangulation of n-gons (pose tests of a quad working mesh); an export copy
  is triangulated explicitly first and written without it. The skinned writer refuses: a vertex without weight, a
  weighted vertex group that is not a bone of the armature, more than --max-influences after cleaning (it limits,
  then reports), a missing UV layer, n-gons without --triangulate. Without --skinned those options (--scale, --objects,
  --quantize, --triangulate, --max-influences) are refused: sail mode writes the scene as it is.
"""
import argparse
import sys

FMT = '%.9g'


# ---------------------------------------------------------------- pure helpers (tested without Blender)

def bone_line(name, parent, rows, t):
    """GXO bone line: parent is 1-based (0 = root); rows = the 3x3 as GXO rows (R transposed); t = translation."""
    return 'b "%s" %d %s' % (name, parent, ' '.join(FMT % x for x in list(rows[0]) + list(rows[1]) + list(rows[2])
                                                    + list(t)))


def limit_weights(pairs, max_influences=4, min_weight=0.5 / 255, quantize=False):
    """[(bone slot, weight)] -> cleaned [(slot, weight)], descending, at most max_influences, summing to 1.
    Drops weights under min_weight (after each renormalization), merges a bone listed twice. quantize: weights k/255
    with sum 255 (floor + largest remainder; a kept influence that would end at 0 takes 1 from the largest)."""
    acc = {}
    for slot, w in pairs:
        if w > 0:
            acc[slot] = acc.get(slot, 0.0) + float(w)
    items = sorted(acc.items(), key=lambda kv: (-kv[1], kv[0]))[:max_influences]
    while items:
        tot = sum(w for _, w in items)
        if tot <= 0:
            return []
        items = [(s, w / tot) for s, w in items]
        keep = [(s, w) for s, w in items if w >= min_weight]
        if len(keep) == len(items):
            break
        items = keep
    if not items:
        return []
    if not quantize:
        return items
    raw = [w * 255.0 for _, w in items]
    q = [int(x) for x in raw]
    order = sorted(range(len(raw)), key=lambda i: (-(raw[i] - q[i]), i))
    for i in order[:255 - sum(q)]:
        q[i] += 1
    for i in range(len(q)):
        if q[i] == 0:
            big = max(range(len(q)), key=lambda k: q[k])
            q[big] -= 1
            q[i] = 1
    out = sorted(((items[i][0], q[i] / 255.0) for i in range(len(q))), key=lambda kv: (-kv[1], kv[0]))
    return out


def vw_line(weights):
    """GXO vw line from cleaned [(1-based mb index, weight)]: 4 weights then 4 indices; unused slots weight 0 and the
    index of slot 0 (the DE full-LOD convention)."""
    w = [x for _, x in weights] + [0.0] * (4 - len(weights))
    i = [s for s, _ in weights] + [weights[0][0]] * (4 - len(weights))
    return 'vw ' + ' '.join(FMT % x for x in w) + ' ' + ' '.join('%d' % x for x in i)


def split_corners(corners, uv_decimals=6, normal_decimals=4):
    """corners [(vertex index, (u, v), (nx, ny, nz))] -> (unique keys in first-seen order, per-corner GXO index).
    One GXO vertex per distinct (vertex, UV, normal) - what an export of the mesh ships."""
    keys, index, per_corner = [], {}, []
    for vi, uv, n in corners:
        k = (vi, round(uv[0], uv_decimals), round(uv[1], uv_decimals),
             round(n[0], normal_decimals), round(n[1], normal_decimals), round(n[2], normal_decimals))
        if k not in index:
            index[k] = len(keys)
            keys.append((vi, uv, n))
        per_corner.append(index[k])
    return keys, per_corner


def mesh_lines(name, mb, mats, verts, tris):
    """lines of one skinned mesh. mb: bone names; mats: 1-based material indices used, in fg order;
    verts: [(pos, normal, uv, weights[(1-based mb, w)])]; tris: [(fg 1-based, a, b, c)] with 0-based GXO indices."""
    out = ['m "%s"' % name] + ['mb "%s"' % b for b in mb] + ['mm %d' % k for k in mats]
    for p, n, uv, w in verts:
        out.append('v ' + ' '.join(FMT % x for x in p))
        out.append('vn ' + ' '.join(FMT % x for x in n))
        out.append('vt ' + ' '.join(FMT % x for x in uv))
        out.append(vw_line(w))
    for g in sorted({t[0] for t in tris}):
        out.append('fg %d' % g)
        out += ['f %d %d %d' % (a + 1, b + 1, c + 1) for gg, a, b, c in tris if gg == g]
    return out


# ---------------------------------------------------------------- Blender side

def ordered_bones(arm):
    """the armature's bones in Blender's order, or in the order listed by the custom property `gxo_bone_order` on the
    armature object (donor_to_blend.py sets the donor gr2's order; Blender itself lists bones depth-first)."""
    bones = list(arm.data.bones)
    order = [str(n) for n in arm.get('gxo_bone_order', [])]
    if order:
        by = {b.name: b for b in bones}
        if sorted(order) != sorted(by):
            raise SystemExit('gxo_bone_order on %s does not list exactly its %d bones' % (arm.name, len(by)))
        bones = [by[n] for n in order]
        pos = {b.name: i for i, b in enumerate(bones)}
        late = [b.name for b in bones if b.parent and pos[b.parent.name] > pos[b.name]]
        if late:
            raise SystemExit('gxo_bone_order lists bones before their parent: %s' % late)
    return bones


def bone_table(arm, scale=1.0):
    bones = ordered_bones(arm)
    index = {b.name: i + 1 for i, b in enumerate(bones)}
    lines = []
    for b in bones:
        M = b.matrix_local; R = M.to_3x3(); t = M.translation
        rows = [[R[c][r] for c in range(3)] for r in range(3)]       # row-major of R transposed (GXO convention)
        tt = [t.x, t.y, t.z] if scale == 1.0 else [t.x * scale, t.y * scale, t.z * scale]
        lines.append(bone_line(b.name, index[b.parent.name] if b.parent else 0, rows, tt))
    return lines, bones


def sail_lines(bpy, arm):
    lines, nsail = [], 0
    for o in sorted(bpy.data.objects, key=lambda o: o.name):
        if o.type != 'MESH' or not o.name.startswith('sail_'): continue
        bone = o.vertex_groups[0].name if o.vertex_groups else (o.parent_bone or '')
        lines.append('m "%s"' % o.name); lines.append('mb "%s"' % bone); lines.append('mm 1')
        for v in o.data.vertices:
            p = o.matrix_local @ v.co if o.parent == arm else arm.matrix_world.inverted() @ (o.matrix_world @ v.co)
            lines.append('v %.9g %.9g %.9g' % (p.x, p.y, p.z))
        nsail += 1
    return lines, nsail


def skinned_objects(bpy, arm, names):
    if names:
        missing = [n for n in names if n not in bpy.data.objects]
        if missing:
            raise SystemExit('objects not in the scene: %s' % missing)
        return [bpy.data.objects[n] for n in names]
    out = []
    for o in sorted(bpy.data.objects, key=lambda o: o.name):
        if o.type != 'MESH' or o.name.startswith('REF_'):
            continue
        if any(m.type == 'ARMATURE' and m.object == arm for m in o.modifiers):
            out.append(o)
    return out


def evaluated_rest_mesh(bpy, o):
    """the object's mesh with every Armature modifier off (rest shape, other modifiers applied); caller clears it."""
    mods = [m for m in o.modifiers if m.type == 'ARMATURE']
    state = [(m, m.show_viewport) for m in mods]
    for m in mods:
        m.show_viewport = False
    try:
        dg = bpy.context.evaluated_depsgraph_get()
        dg.update()
        oe = o.evaluated_get(dg)
        me = oe.to_mesh(preserve_all_data_layers=True, depsgraph=dg)   # keeps vertex groups and every UV layer
    finally:
        for m, s in state:
            m.show_viewport = s
    return oe, me


def skinned_lines(bpy, arm, objects, a):
    bone_order = [b.name for b in ordered_bones(arm)]
    bone_set = set(bone_order)
    materials, mesh_out, stats = [], [], []
    inv_arm = arm.matrix_world.inverted()
    for o in objects:
        oe, me = evaluated_rest_mesh(bpy, o)
        try:
            if not me.uv_layers:
                raise SystemExit('%s: no UV layer' % o.name)
            uvl = me.uv_layers.active or me.uv_layers[0]
            M = inv_arm @ o.matrix_world
            N3 = M.to_3x3().inverted().transposed()
            names = {g.index: g.name for g in o.vertex_groups}
            bad = sorted({names[g.group] for v in me.vertices for g in v.groups
                          if g.weight > 0 and names.get(g.group) not in bone_set})
            if bad:
                raise SystemExit('%s: weighted vertex groups that are not bones of %s: %s' % (o.name, arm.name, bad))
            vweights, unweighted, over = [], [], 0
            for v in me.vertices:
                pairs = [(names[g.group], g.weight) for g in v.groups if g.weight > 0]
                if not pairs:
                    unweighted.append(v.index)
                over += len(pairs) > a.max_influences
                vweights.append(pairs)
            if unweighted:
                raise SystemExit('%s: %d vertices without weight (first %s)' % (o.name, len(unweighted), unweighted[:8]))
            used = {b for pairs in vweights for b, _ in pairs}
            mb = [b for b in bone_order if b in used]
            slot = {b: i + 1 for i, b in enumerate(mb)}
            cleaned = [limit_weights([(slot[b], w) for b, w in pairs], a.max_influences, 0.5 / 255, a.quantize)
                       for pairs in vweights]
            if any(not c for c in cleaned):
                raise SystemExit('%s: a vertex lost every weight in cleaning' % o.name)
            cn = me.corner_normals
            polys = []
            if all(len(p.loop_indices) == 3 for p in me.polygons):
                polys = [(p.material_index, list(p.loop_indices)) for p in me.polygons]
            elif a.triangulate:
                me.calc_loop_triangles()
                polys = [(t.material_index, list(t.loops)) for t in me.loop_triangles]
            else:
                ng = sum(1 for p in me.polygons if len(p.loop_indices) != 3)
                raise SystemExit('%s: %d faces are not triangles - triangulate the export copy or pass --triangulate'
                                 % (o.name, ng))
            corners, tri_corners, mat_of_tri = [], [], []
            for mi, loops in polys:
                tri_corners.append([])
                for li in loops:
                    vi = me.loops[li].vertex_index
                    n = (N3 @ cn[li].vector).normalized()
                    uv = uvl.uv[li].vector
                    corners.append((vi, (uv.x, uv.y), (n.x, n.y, n.z)))
                    tri_corners[-1].append(len(corners) - 1)
                mat_of_tri.append(mi)
            keys, per_corner = split_corners(corners)
            slot_names = []
            for mi in sorted(set(mat_of_tri)):
                ms = o.material_slots[mi].material if mi < len(o.material_slots) else None
                slot_names.append((mi, ms.name if ms else '%s_mat%d' % (o.name, mi)))
            mats = []
            for mi, nm in slot_names:
                if nm not in materials:
                    materials.append(nm)
                mats.append(materials.index(nm) + 1)
            fg_of = {mi: k + 1 for k, (mi, _) in enumerate(slot_names)}
            verts = []
            for vi, uv, n in keys:
                p = M @ me.vertices[vi].co
                pos = (p.x * a.scale, p.y * a.scale, p.z * a.scale) if a.scale != 1.0 else (p.x, p.y, p.z)
                verts.append((pos, n, uv, cleaned[vi]))
            tris = [(fg_of[mi], per_corner[c[0]], per_corner[c[1]], per_corner[c[2]])
                    for mi, c in zip(mat_of_tri, tri_corners)]
            mesh_out += mesh_lines(o.name, mb, mats, verts, tris)
            stats.append((o.name, len(me.vertices), len(verts), len(tris), max(len(c) for c in cleaned), over, mb))
        finally:
            oe.to_mesh_clear()
    return ['mt "%s"' % m for m in materials], mesh_out, stats


def parse_args(argv):
    ap = argparse.ArgumentParser(prog='rig_table.py', description='GXO-form table from a Blender scene')
    ap.add_argument('out')
    ap.add_argument('--skinned', action='store_true', help='write skinned meshes (UV, normal, weight, face lines)')
    ap.add_argument('--armature', help='armature object name (default: the only one / the first in sail mode)')
    ap.add_argument('--objects', nargs='*', default=[], help='skinned: these mesh objects (default: every mesh '
                    'with an Armature modifier on the armature, REF_* excluded)')
    ap.add_argument('--scale', type=float, default=1.0, help='multiply positions and bone translations')
    ap.add_argument('--max-influences', type=int, default=4)
    ap.add_argument('--quantize', action='store_true', help='weights as k/255 summing to 255')
    ap.add_argument('--triangulate', action='store_true', help='accept n-gons through Blender\'s triangulation')
    a = ap.parse_args(argv)
    if not a.skinned:
        used = [n for n, v in (('--scale', a.scale != 1.0), ('--objects', bool(a.objects)), ('--quantize', a.quantize),
                               ('--triangulate', a.triangulate), ('--max-influences', a.max_influences != 4)) if v]
        if used:
            ap.error('%s only apply with --skinned: sail mode writes its bones and sail_* vertices as the scene holds '
                     'them' % ', '.join(used))
    return a


def main():
    import bpy
    a = parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else [])
    arms = [o for o in bpy.data.objects if o.type == 'ARMATURE']
    if a.armature:
        arm = bpy.data.objects[a.armature]
    elif a.skinned and len(arms) != 1:
        raise SystemExit('%d armatures in the scene: pass --armature' % len(arms))
    else:
        arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
    lines, bones = bone_table(arm, a.scale)
    if not a.skinned:
        sail, nsail = sail_lines(bpy, arm)
        open(a.out, 'w', encoding='utf-8', newline='\n').write('\n'.join(lines + sail) + '\n')
        print('WROTE', a.out, 'bones', len(bones), 'sail meshes', nsail)
        return
    objects = skinned_objects(bpy, arm, a.objects)
    if not objects:
        raise SystemExit('no skinned mesh found (Armature modifier on %s) and no --objects given' % arm.name)
    mt, meshes, stats = skinned_lines(bpy, arm, objects, a)
    open(a.out, 'w', encoding='utf-8', newline='\n').write('\n'.join(mt + lines + meshes) + '\n')
    print('WROTE', a.out, 'bones', len(bones), 'skinned meshes', len(stats), 'scale', a.scale)
    for name, nv, ng, nt, mx, over, mb in stats:
        print('  MESH %s: %d Blender vertices -> %d GXO vertices, %d triangles, max influences %d%s, weighted bones %d: %s'
              % (name, nv, ng, nt, mx, (' (%d vertices limited to %d)' % (over, a.max_influences)) if over else '',
                 len(mb), ' '.join(mb)))


if __name__ == '__main__':
    main()
