"""Synthetic stand-in for a generated figure, built in background Blender for the tool tests.

    blender -b --factory-startup --python-exit-code 2 --python make_fixture_model.py -- OUTDIR

Writes OUTDIR/figure.glb, OUTDIR/ref.blend and OUTDIR/fixture.json (the expected numbers). The figure, in raw model
units like a generated GLB (about 1 unit tall): a subdivided torso box (the largest part), two straight arm boxes
from shoulders at z 0.75 pointing down and outward at ARM_DEG from vertical, and three small cubes on top (a
"plume" of fragments), all flat shaded with one packed 64 x 64 texture, so the GLB splits vertices at every face
edge exactly as generated models split them at UV seams. ref.blend holds the reference body REF_body (1.8 tall) and
a decoy mesh. OUTDIR must be outside every git work tree.
"""
import json
import math
import sys
from pathlib import Path

import bmesh
import bpy

ARM_DEG, ARM_LEN, ARM_T = 26.2, 0.30, 0.04
SHOULDER = (0.12, 0.0, 0.75)
PLUME = [(0.0, 0.0, 0.97), (0.03, 0.0, 0.96), (-0.03, 0.0, 0.955)]
CUBE_HALF = 0.01


def box(bm, centre, half, axes=None):
    """An 8-vertex box; axes = three unit vectors (default world axes)."""
    axes = axes or ((1, 0, 0), (0, 1, 0), (0, 0, 1))
    vs = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            for sz in (-1, 1):
                p = [centre[i] + sx * half[0] * axes[0][i] + sy * half[1] * axes[1][i] + sz * half[2] * axes[2][i]
                     for i in range(3)]
                vs.append(bm.verts.new(p))
    idx = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
    faces = [bm.faces.new([vs[i] for i in f]) for f in idx]
    return vs, faces


def main(out):
    out = Path(out).resolve()
    out.mkdir(parents=True, exist_ok=True)
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob)
    bm = bmesh.new()
    _, torso_faces = box(bm, (0, 0, 0.45), (0.1, 0.06, 0.45))
    bmesh.ops.subdivide_edges(bm, edges=list({e for f in torso_faces for e in f.edges}), cuts=2,
                              use_grid_fill=True)
    t = math.radians(ARM_DEG)
    for s in (-1, 1):
        d = (s * math.sin(t), 0.0, -math.cos(t))
        n = (math.cos(t), 0.0, s * math.sin(t))                  # perpendicular in the XZ plane
        c = [SHOULDER[0] * s + d[0] * ARM_LEN / 2, SHOULDER[1], SHOULDER[2] + d[2] * ARM_LEN / 2]
        box(bm, c, (ARM_T / 2, ARM_T / 2, ARM_LEN / 2), axes=(n, (0, 1, 0), d))
    for c in PLUME:
        box(bm, c, (CUBE_HALF,) * 3)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    uv = bm.loops.layers.uv.new('UVMap')
    for f in bm.faces:
        for k, loop in enumerate(f.loops):
            loop[uv].uv = ((k in (1, 2)) * 1.0, (k in (2, 3)) * 1.0)
    for f in bm.faces:
        f.smooth = False
    me = bpy.data.meshes.new('figure')
    bm.to_mesh(me)
    tris = sum(len(f.verts) - 2 for f in bm.faces)
    bm.free()
    ob = bpy.data.objects.new('figure', me)
    bpy.context.scene.collection.objects.link(ob)
    img = bpy.data.images.new('fixture_tex', 64, 64)
    img.pixels = [v for i in range(64 * 64) for v in ((i % 8) / 8.0, ((i // 64) % 8) / 8.0, 0.5, 1.0)]
    img.pack()
    mat = bpy.data.materials.new('fixture_mat')
    mat.use_nodes = True
    tex = mat.node_tree.nodes.new('ShaderNodeTexImage')
    tex.image = img
    bsdf = mat.node_tree.nodes['Principled BSDF']
    mat.node_tree.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
    me.materials.append(mat)
    for o in bpy.context.scene.objects:
        o.select_set(False)
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    glb = out / 'figure.glb'
    bpy.ops.export_scene.gltf(filepath=str(glb), export_format='GLB', use_selection=True)
    # reference body and a decoy, saved beside the figure
    rbm = bmesh.new()
    box(rbm, (0, 0, 0.9), (0.2, 0.1, 0.9))
    rme = bpy.data.meshes.new('REF_body')
    rbm.to_mesh(rme)
    rbm.free()
    bpy.context.scene.collection.objects.link(bpy.data.objects.new('REF_body', rme))
    dbm = bmesh.new()
    box(dbm, (1.0, 0, 0.25), (0.1, 0.1, 0.25))
    dme = bpy.data.meshes.new('Decoy')
    dbm.to_mesh(dme)
    dbm.free()
    bpy.context.scene.collection.objects.link(bpy.data.objects.new('Decoy', dme))
    bpy.ops.wm.save_as_mainfile(filepath=str(out / 'ref.blend'))
    top = max(c[2] for c in PLUME) + CUBE_HALF
    fixture = dict(glb=str(glb), ref_blend=str(out / 'ref.blend'), ref_object='REF_body', ref_height=1.8,
                   raw_height=top, triangles=tris, loose_parts=1 + 2 + len(PLUME), fragments=2 + len(PLUME),
                   arm_band=int((SHOULDER[2] - math.cos(t) * ARM_LEN / 2) / top * 10), plume_band=9,
                   arm_deg=ARM_DEG, arm_len=ARM_LEN, arm_thickness=ARM_T, shoulder=SHOULDER, texture=[64, 64])
    (out / 'fixture.json').write_text(json.dumps(fixture, indent=1), encoding='utf-8')
    print('FIXTURE %s' % out)


if __name__ == '__main__':
    args = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
    if not args:
        print('usage: blender -b --factory-startup --python-exit-code 2 --python make_fixture_model.py -- OUTDIR')
        sys.exit(2)
    main(args[0])
