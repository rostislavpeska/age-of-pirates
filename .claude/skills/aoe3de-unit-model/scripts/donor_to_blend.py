"""Build the working Blender scene of a unit from its donor gr2: the donor skeleton as an armature at working scale,
optionally the donor's own meshes as REF_ overlays with their weights (background Blender, no converter needed).

    blender -b --factory-startup --python donor_to_blend.py -- DONOR.gr2 OUT.blend [--scale 1.0] [--no-ref]
            [--deform weighted|all|NAME,NAME,...] [--name RIG]

Frame and scale (verified 2026-10-11 against the converter's GXO dump of iron_rider_0: bones 1.6e-7, see
references/export-routes.md): armature space is the GXO frame (x across, y along, z up; engine (x, y up, z) =
(-x, z, -y)) in engine units x --scale. --scale 1 (default) is the working scale: engine units, a rider about 2.1
units tall, so Merge by Distance, bevel widths and transfer distances behave. No object carries a scale, nothing
needs applying. rig_table.py --skinned --scale 0.393700787 (1 / 2.54, printed below) writes a model GXO in the
units of clip_decode.py's vanilla clips and of the converter's model dumps, for pose_sim.py.

The armature keeps the donor's bone names, parents and rest matrices (each bone's Blender matrix is the donor rest
transform; Blender stores it to float precision); Blender lists bones depth-first, so the donor's order is stored in
the armature's `gxo_bone_order` property, which rig_table.py follows. --deform weighted (default) leaves the deform flag on only for
the bones the donor's own meshes weight, so automatic weights and Data Transfer cannot land on Root, Neck, Prop,
Toe, Ponytail or attach bones; --deform all keeps every bone deforming; a comma list names them. REF_ meshes carry
the donor's vertex groups, UVs (V flipped to Blender's convention) and stored normals as custom normals: overlays for
the blockout, sources for a weight transfer (a policy question for vanilla data), and the round-trip specimen
(rig_table.py on a REF_ mesh must give back the donor's data). OUT.blend holds vanilla-derived data: it is refused
inside any git working tree and inside the consumer repository.
"""
import argparse
import hashlib
import sys
from pathlib import Path

import bpy
from mathutils import Matrix

sys.path.insert(0, str(Path(__file__).resolve().parent))
import unit_gr2 as U  # noqa: E402


def parse(argv):
    ap = argparse.ArgumentParser(prog='donor_to_blend.py')
    ap.add_argument('donor')
    ap.add_argument('out')
    ap.add_argument('--scale', type=float, default=1.0, help='armature units per engine unit (1 = working scale)')
    ap.add_argument('--no-ref', action='store_true', help='skip the REF_ meshes')
    ap.add_argument('--deform', default='weighted', help='weighted | all | comma list of bone names')
    ap.add_argument('--name', help='armature object name (default <donor stem>_rig)')
    return ap.parse_args(argv)


def blender_matrix(Wg):
    """GXO-frame row-vector 4x4 -> Blender column-vector Matrix (bone axes as columns)."""
    R, t = Wg[:3, :3].T, Wg[3, :3]
    return Matrix(((R[0][0], R[0][1], R[0][2], t[0]), (R[1][0], R[1][1], R[1][2], t[1]),
                   (R[2][0], R[2][1], R[2][2], t[2]), (0.0, 0.0, 0.0, 1.0)))


def build_armature(m, name, scale, deform):
    ad = bpy.data.armatures.new(name + '_data')
    arm = bpy.data.objects.new(name, ad)
    bpy.context.scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode='EDIT')
    sk = m.skeleton
    W = [U.to_gxo_matrix(b['world'], units=scale) for b in sk]
    kids = {}
    for i, b in enumerate(sk):
        if b['parent'] >= 0:
            kids.setdefault(b['parent'], []).append(i)
    ebs = []
    for i, b in enumerate(sk):
        eb = ad.edit_bones.new(b['name'])
        d = [float(((W[k][3, :3] - W[i][3, :3]) ** 2).sum() ** 0.5) for k in kids.get(i, [])]
        d = [x for x in d if x > 1e-4 * scale]
        length = min(d) if d else 0.05 * scale
        eb.head = (0.0, 0.0, 0.0)
        eb.tail = (0.0, length, 0.0)
        eb.matrix = blender_matrix(W[i])
        eb.use_connect = False
        ebs.append(eb)
    for i, b in enumerate(sk):
        if b['parent'] >= 0:
            ebs[i].parent = ebs[b['parent']]
    bpy.ops.object.mode_set(mode='OBJECT')
    for b in ad.bones:
        b.use_deform = deform is None or b.name in deform
    return arm


def build_ref(me, arm, scale):
    vw = me.vertex_weights()
    P = U.to_gxo_point(me.pos, units=scale)
    key, verts, weights, gpu_to_v = {}, [], [], []
    for i in range(me.n):
        k = (tuple(round(float(c), 6) for c in P[i]), tuple(sorted((b, round(w, 6)) for b, w in vw[i].items())))
        if k not in key:
            key[k] = len(verts)
            verts.append(tuple(float(c) for c in P[i]))
            weights.append(vw[i])
        gpu_to_v.append(key[k])
    tris, corners = [], []
    for t in me.tris:
        r = [int(t[2]), int(t[1]), int(t[0])]                     # the GXO frame mirrors: winding reverses
        f = [gpu_to_v[x] for x in r]
        if len(set(f)) == 3:
            tris.append(f)
            corners.append(r)
    mesh = bpy.data.meshes.new('REF_' + me.name)
    mesh.from_pydata(verts, [], tris)
    mesh.update()
    uv = mesh.uv_layers.new(name='UVMap')
    UVs = me.comps['TextureCoordinates0'].astype(float)
    N = me.comps['Normal'][:, :3].astype(float)
    Ng = N @ U.A.T
    Ng /= (Ng ** 2).sum(1, keepdims=True) ** 0.5
    loop_normals = []
    for poly, gpu in zip(mesh.polygons, corners):
        for li, g in zip(poly.loop_indices, gpu):
            uv.uv[li].vector = (UVs[g][0], 1.0 - UVs[g][1])
            loop_normals.append(tuple(Ng[g]))
    mesh.shade_smooth()
    mesh.normals_split_custom_set(loop_normals)
    o = bpy.data.objects.new('REF_' + me.name, mesh)
    bpy.context.scene.collection.objects.link(o)
    o.parent = arm
    md = o.modifiers.new('Armature', 'ARMATURE')
    md.object = arm
    groups = {}
    for vi, w in enumerate(weights):
        for b, x in w.items():
            g = groups.get(b) or o.vertex_groups.new(name=b)
            groups[b] = g
            g.add([vi], x, 'REPLACE')
    for name in me.materials or ['mat']:
        mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
        mesh.materials.append(mat)
    return o, len(verts), len(tris)


def main():
    a = parse(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else [])
    out = Path(a.out).resolve()
    U.refuse_repo_target(out.parent, 'OUT holds vanilla-derived data')
    m = U.Model(a.donor)
    weighted = sorted({b for me in m.meshes for b in me.weighted_bones()})
    deform = None if a.deform == 'all' else (set(weighted) if a.deform == 'weighted' else set(a.deform.split(',')))
    bpy.ops.wm.read_factory_settings(use_empty=True)
    name = a.name or m.name + '_rig'
    arm = build_armature(m, name, a.scale, deform)
    arm['aoe3_donor'] = Path(a.donor).name
    arm['aoe3_donor_sha256'] = hashlib.sha256(Path(a.donor).read_bytes()).hexdigest()
    arm['aoe3_scale'] = a.scale
    arm['aoe3_frame'] = 'GXO frame: x across, y along, z up; engine (x, y up, z) = (-x, z, -y) / scale'
    arm['aoe3_pose_sim_scale'] = 1.0 / (2.54 * a.scale)
    arm['aoe3_weighted_bones'] = weighted
    arm['gxo_bone_order'] = [b['name'] for b in m.skeleton]        # rig_table.py writes bones in the donor's order
    refs = []
    if not a.no_ref:
        for me in m.meshes:
            if 'TextureCoordinates0' in me.comps and me.n:
                refs.append(build_ref(me, arm, a.scale))
    out.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(out))
    print('DONOR %s: %d bones (%d deforming: %s), scale %g' % (
        m.name, len(m.skeleton), sum(b.use_deform for b in arm.data.bones), a.deform, a.scale))
    for o, nv, nt in refs:
        print('  REF %s: %d vertices, %d triangles, groups %d' % (o.name, nv, nt, len(o.vertex_groups)))
    print('SAVED %s' % out)
    print('pose-test export: blender -b %s --python <consumer-root>/scripts/havok/rig_table.py -- MODEL.gxo --skinned '
          '--armature %s --scale %.9g' % (out.name, name, 1.0 / (2.54 * a.scale)))


if __name__ == '__main__':
    main()
