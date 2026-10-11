"""Build the Blender test scene for the organic UV tools (background Blender, writes one .blend and a names file).

    blender -b --factory-startup --python-exit-code 2 --python make_fixture_blend.py -- ABS_OUT_DIR

Evaluator validation objects (planes face -Y = the default camera front; units = metres; UV layer 'UVMap'), with the
analytic answers checked in test_blender_pipeline.py:
  S_iso      1 x 1 grid, UV = 0.5 x the plane: L2 = Linf = 1, density 512 t/m @1024, orientation 0
  S_aniso    same plane, UV scaled 0.5 in x and 0.25 in z: sigma ratio 2, L2 = sqrt(5/4), Linf = sqrt(2)
  S_two      two 1 x 1 planes sharing one edge (seam 1 m), UV scales 0.25 and 0.5, islands 3 texels apart @1024
  S_cyl      open 16-gon cylinder r 0.3 h 1, chord-exact unwrap, seam column facing -Y: visible in headings -45/0/45
  S_wall     box in front of the cylinder seam: blocks heading 0 only
  S_mirror   plane at +x and its exact mirror at -x stacked on the same UV square (0.2 x 0.2)
  S_partial  two unrelated planes whose UV squares overlap by 0.1 x 0.1
  S_fold     three quads in a row, the middle one folded back in UV
  S_rot90    plane whose UV is turned so that 3D up maps to +U
  S_cylpose  S_cyl driven by armature PoseRig (one bone along +Z): action Turn180 (assigned) turns it 180 deg about Z
             at frame 10, action Turn90 (not assigned) 90 deg
Organic pipeline object:
  Body       tests/synthetic.tube_body(): face INT attribute 'part' (names in part_names.json), vertex INT attributes
             ring and slot, one vertex group per bone, a placeholder UV layer 'UVMap' that the apply step removes
"""
import json
import math
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import synthetic as S  # noqa: E402


def mesh(name, verts, faces, uvs=None):
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in verts], [], [tuple(f) for f in faces])
    me.update()
    uvl = me.uv_layers.new(name='UVMap')
    if uvs is not None:
        for poly, fuv in zip(me.polygons, uvs):
            for li, uv in zip(poly.loop_indices, fuv):
                uvl.data[li].uv = uv
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    return o


def grid(x0, x1, z0, z1, n, uvf, y=0.0, tri=False):
    V, Fc, U = [], [], []
    idx = {}
    for i in range(n + 1):
        for j in range(n + 1):
            idx[(i, j)] = len(V)
            V.append((x0 + (x1 - x0) * i / n, y, z0 + (z1 - z0) * j / n))
    for i in range(n):
        for j in range(n):
            q = [idx[(i, j)], idx[(i + 1, j)], idx[(i + 1, j + 1)], idx[(i, j + 1)]]
            fs = [q] if not tri else [[q[0], q[1], q[2]], [q[0], q[2], q[3]]]
            for f in fs:
                Fc.append(f)
                U.append([uvf(V[k][0], V[k][2]) for k in f])
    return V, Fc, U


def cylinder():
    n, r, h, rows = 16, 0.3, 1.0, 4
    chord = 2 * r * math.sin(math.pi / n)
    V, Fc, U = [], [], []
    for j in range(rows + 1):
        for i in range(n):
            th = math.radians(-90 + i * 360.0 / n)
            V.append((r * math.cos(th), r * math.sin(th), h * j / rows))
    for j in range(rows):
        for i in range(n):
            i2 = (i + 1) % n
            Fc.append([j * n + i, j * n + i2, (j + 1) * n + i2, (j + 1) * n + i])
            u0, u1 = 0.03 + 0.5 * chord * i, 0.03 + 0.5 * chord * (i + 1)
            v0, v1 = 0.03 + 0.5 * h * j / rows, 0.03 + 0.5 * h * (j + 1) / rows
            U.append([(u0, v0), (u1, v0), (u1, v1), (u0, v1)])
    return V, Fc, U


def validation_objects():
    mesh('S_iso', *grid(-0.5, 0.5, 0, 1, 4, lambda x, z: (0.25 + 0.5 * (x + 0.5), 0.25 + 0.5 * z)))
    mesh('S_aniso', *grid(-0.5, 0.5, 0, 1, 4, lambda x, z: (0.1 + 0.5 * (x + 0.5), 0.1 + 0.25 * z)))
    g = 3.0 / 1024
    V = [(x, 0.0, z) for (x, z) in [(-1, 0), (0, 0), (0, 1), (-1, 1), (1, 0), (1, 1)]]
    Fc = [[0, 1, 2, 3], [1, 4, 5, 2]]
    Lf = lambda x, z: (0.05 + 0.25 * (x + 1), 0.05 + 0.25 * z)  # noqa: E731
    Rf = lambda x, z: (0.30 + g + 0.5 * x, 0.05 + 0.5 * z)  # noqa: E731
    mesh('S_two', V, Fc, [[Lf(V[k][0], V[k][2]) for k in Fc[0]], [Rf(V[k][0], V[k][2]) for k in Fc[1]]])
    mesh('S_cyl', *cylinder())
    x0, x1, y0, y1, z0, z1 = -0.15, 0.15, -0.75, -0.65, 0.0, 2.0
    V = [(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0), (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)]
    Fc = [[0, 3, 2, 1], [4, 5, 6, 7], [0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7]]
    mesh('S_wall', V, Fc, [[(0, 0)] * 4 for _ in Fc])
    VA, FA, UA = grid(0.5, 1.0, 0, 0.5, 1, lambda x, z: (0.6 + 0.4 * (x - 0.5), 0.6 + 0.4 * z), tri=True)
    VB = [(-x, y, z) for x, y, z in VA]
    FB = [[f[0], f[2], f[1]] for f in FA]
    UB = [[u[0], u[2], u[1]] for u in UA]
    nA = len(VA)
    mesh('S_mirror', VA + VB, FA + [[k + nA for k in f] for f in FB], UA + UB)
    V1, F1, U1 = grid(0.0, 0.5, 0, 0.5, 1, lambda x, z: (0.1 + 0.4 * x, 0.1 + 0.4 * z))
    V2, F2, U2 = grid(2.0, 2.5, 0, 0.5, 1, lambda x, z: (0.2 + 0.4 * (x - 2.0), 0.2 + 0.4 * z))
    mesh('S_partial', V1 + V2, F1 + [[k + len(V1) for k in f] for f in F2], U1 + U2)
    ux = {0: 0.1, 1: 0.3, 2: 0.2, 3: 0.4}
    V = [(float(i), 0.0, float(j)) for i in range(4) for j in range(2)]
    Fc = [[i * 2, (i + 1) * 2, (i + 1) * 2 + 1, i * 2 + 1] for i in range(3)]
    mesh('S_fold', V, Fc, [[(ux[int(V[k][0])], 0.1 + 0.2 * V[k][2]) for k in f] for f in Fc])
    mesh('S_rot90', *grid(-0.5, 0.5, 0, 1, 2, lambda x, z: (0.1 + 0.5 * z, 0.6 - 0.5 * (x + 0.5))))


def posed_cylinder():
    ob = mesh('S_cylpose', *cylinder())
    arm_data = bpy.data.armatures.new('PoseRig')
    rig = bpy.data.objects.new('PoseRig', arm_data)
    bpy.context.scene.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode='EDIT')
    b = arm_data.edit_bones.new('Bip01_Spine')
    b.head, b.tail = (0, 0, 0), (0, 0, 1)
    bpy.ops.object.mode_set(mode='OBJECT')
    vg = ob.vertex_groups.new(name='Bip01_Spine')
    vg.add(list(range(len(ob.data.vertices))), 1.0, 'REPLACE')
    md = ob.modifiers.new('Armature', 'ARMATURE')
    md.object = rig
    pb = rig.pose.bones['Bip01_Spine']
    pb.rotation_mode = 'XYZ'
    for name, ang in (('Turn90', 90.0), ('Turn180', 180.0)):
        rig.animation_data_create()
        act = bpy.data.actions.new(name)
        rig.animation_data.action = act
        for frame, a in ((1, 0.0), (10, math.radians(ang))):
            pb.rotation_euler = (0.0, a, 0.0)               # bone Y = world +Z: a turn about the vertical axis
            pb.keyframe_insert('rotation_euler', frame=frame)
        act.use_fake_user = True
    rig.animation_data.action = bpy.data.actions['Turn180']
    try:
        act = bpy.data.actions['Turn180']
        if getattr(rig.animation_data, 'action_slot', None) is None and len(act.slots):
            rig.animation_data.action_slot = act.slots[0]
    except (AttributeError, TypeError):
        pass
    pb.rotation_euler = (0.0, 0.0, 0.0)
    bpy.context.scene.frame_set(1)


def body(out_dir):
    b = S.tube_body()
    ob = mesh('Body', b.co, b.polys)
    me = ob.data
    names = sorted(set(b.parts))
    at = me.attributes.new('part', 'INT', 'FACE')
    at.data.foreach_set('value', [names.index(p) for p in b.parts])
    for an, vals in (('ring', b.ring), ('slot', b.slot)):
        a = me.attributes.new(an, 'INT', 'POINT')
        a.data.foreach_set('value', vals)
    groups = {}
    for v, w in enumerate(b.w):
        for bone, x in w:
            if bone not in groups:
                groups[bone] = ob.vertex_groups.new(name=bone)
            groups[bone].add([v], x, 'REPLACE')
    with open(os.path.join(out_dir, 'part_names.json'), 'w') as f:
        json.dump({str(i): n for i, n in enumerate(names)}, f)


def main():
    out_dir = sys.argv[sys.argv.index('--') + 1]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    validation_objects()
    posed_cylinder()
    body(out_dir)
    path = os.path.join(out_dir, 'fixture.blend')
    bpy.ops.wm.save_as_mainfile(filepath=path)
    print('FIXTURE_OK', path, sorted(o.name for o in bpy.data.objects))


main()
