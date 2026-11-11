"""rig_table.py: the GXO-form writer for Blender scenes (sail mode unchanged, skinned mode for pose tests).

    python -m pytest scripts/havok/tests/test_rig_table.py -q

The helper tests need only Python and numpy (Linux CI). The scene tests build a small armature + skinned mesh in a
background Blender (`blender -b`, never a window) and skip where no Blender is found (BLENDER, then
config/tool-paths.local.json tools.blender.path, then PATH). Every file goes to pytest's temp folder.
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

import numpy as np
import pytest

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
sys.path.insert(0, str(HERE.parent))
sys.path.insert(0, str(REPO / '.claude' / 'skills' / 'aoe3de-unit-animation' / 'scripts'))
import rig_table as RT  # noqa: E402
import pose_sim  # noqa: E402


# ---------------------------------------------------------------- helpers, no Blender

def test_module_imports_without_blender():
    assert 'bpy' not in sys.modules or not hasattr(RT, 'bpy')


def test_limit_weights_keeps_the_four_largest_and_renormalizes():
    out = RT.limit_weights([(1, 0.4), (2, 0.3), (3, 0.2), (4, 0.06), (5, 0.04)], 4)
    assert [s for s, _ in out] == [1, 2, 3, 4]
    assert abs(sum(w for _, w in out) - 1) < 1e-12
    assert all(out[i][1] >= out[i + 1][1] for i in range(3))


def test_limit_weights_merges_a_bone_listed_twice_and_drops_dust():
    out = RT.limit_weights([(2, 0.3), (2, 0.3), (1, 0.4), (3, 0.0005)], 4)
    assert [s for s, _ in out] == [2, 1] and np.allclose([w for _, w in out], [0.6, 0.4])


def test_quantized_weights_sum_to_255_and_no_kept_influence_is_zero():
    rng = np.random.default_rng(7)
    for _ in range(500):
        k = int(rng.integers(1, 5))
        w = rng.random(k) ** 3 + 0.003
        out = RT.limit_weights(list(enumerate(w, 1)), 4, quantize=True)
        q = [round(x * 255) for _, x in out]
        assert sum(q) == 255 and min(q) >= 1, (w, q)
        assert all(abs(x * 255 - round(x * 255)) < 1e-9 for _, x in out)
        assert q == sorted(q, reverse=True)


def test_quantize_gives_a_unit_to_a_kept_influence_that_largest_remainder_would_zero():
    # four remainders 0.9/0.8/0.7/0.6 over floors that sum to 252: the 0.6 one (floor 0) would end at 0
    w = np.array([100.9, 100.8, 53.7, 0.6]) / 256.0
    out = RT.limit_weights(list(enumerate(w, 1)), 4, min_weight=0.001, quantize=True)
    q = sorted(round(x * 255) for _, x in out)
    assert sum(q) == 255 and q[0] >= 1


def test_vw_line_fills_unused_slots_with_slot_zeros_index():
    assert RT.vw_line([(3, 1.0)]) == 'vw 1 0 0 0 3 3 3 3'
    assert RT.vw_line([(2, 0.75), (5, 0.25)]) == 'vw 0.75 0.25 0 0 2 5 2 2'


def test_split_corners_splits_at_uv_seams_and_hard_normals_only():
    n = (0.0, 0.0, 1.0)
    corners = [(0, (0.1, 0.2), n), (0, (0.1, 0.2), n), (0, (0.6, 0.2), n), (0, (0.1, 0.2), (1.0, 0.0, 0.0)),
               (1, (0.1, 0.2), n)]
    keys, per = RT.split_corners(corners)
    assert len(keys) == 4 and per == [0, 0, 1, 2, 3]


def test_mesh_lines_parse_in_pose_sim(tmp_path):
    verts = [((0, 0, 0), (0, 0, 1), (0, 0), [(1, 1.0)]), ((1, 0, 0), (0, 0, 1), (1, 0), [(1, 0.5), (2, 0.5)]),
             ((0, 1, 0), (0, 0, 1), (0, 1), [(2, 1.0)])]
    lines = [RT.bone_line('Root', 0, np.eye(3), (0, 0, 0)), RT.bone_line('Arm', 1, np.eye(3), (0, 0, 1))]
    lines += RT.mesh_lines('m', ['Root', 'Arm'], [1], verts, [(1, 0, 1, 2)])
    p = tmp_path / 't.gxo'
    p.write_text('\n'.join(lines) + '\n')
    bones, meshes = pose_sim.parse_model(p)
    assert [b['name'] for b in bones] == ['Root', 'Arm'] and bones[1]['parent'] == 0
    m = meshes[0]
    assert m['mb'] == ['Root', 'Arm'] and m['f'] == [[1, 2, 3]] and len(m['v']) == len(m['vt']) == len(m['vw']) == 3
    assert m['vw'][1] == [0.5, 0.5, 0, 0, 1, 2, 1, 1]
    out = pose_sim.skin(bones, pose_sim.pose(bones, {}), m)
    assert np.allclose(out, m['v'])                                   # rest keys reproduce the written mesh


def test_sail_mode_arguments_stay_a_single_path():
    a = RT.parse_args(['out.gxo'])
    assert a.out == 'out.gxo' and not a.skinned and a.scale == 1.0


@pytest.mark.parametrize('extra', [['--scale', '0.393700787'], ['--objects', 'body'], ['--quantize'], ['--triangulate'],
                                   ['--max-influences', '2']])
def test_skinned_only_options_are_refused_in_sail_mode(extra, capsys):
    # sail_lines() never scaled: --scale without --skinned would write scaled bones over unscaled sail vertices
    with pytest.raises(SystemExit):
        RT.parse_args(['out.gxo'] + extra)
    assert 'only apply with --skinned' in capsys.readouterr().err
    assert RT.parse_args(['out.gxo', '--skinned'] + extra).skinned


# ---------------------------------------------------------------- Blender scenes

def blender_exe():
    cands = [os.environ.get('BLENDER')]
    cfg = REPO / 'config' / 'tool-paths.local.json'
    if cfg.is_file():
        try:
            cands.append(json.loads(cfg.read_text(encoding='utf-8'))['tools']['blender']['path'])
        except (KeyError, ValueError, TypeError):
            pass
    cands.append(shutil.which('blender'))
    for c in cands:
        if c and Path(c).is_file():
            return c
    return None


SCENE = r'''
import bpy, sys
from mathutils import Matrix, Vector
out = sys.argv[sys.argv.index('--') + 1]
bpy.ops.wm.read_factory_settings(use_empty=True)
ad = bpy.data.armatures.new('RigData'); arm = bpy.data.objects.new('Rig', ad); bpy.context.scene.collection.objects.link(arm)
bpy.context.view_layer.objects.active = arm; bpy.ops.object.mode_set(mode='EDIT')
def bone(name, head, tail, parent=None):
    b = ad.edit_bones.new(name); b.head = head; b.tail = tail
    if parent: b.parent = ad.edit_bones[parent]
    return b
bone('Root', (0, 0, 0), (0, 0, 0.2)); bone('Arm', (0, 0, 1), (0.5, 0, 1.5), 'Root')
bone('B1', (0, 0, 0.3), (0, 0, 0.4), 'Root'); bone('B2', (0, 0, 0.5), (0, 0, 0.6), 'Root')
bone('B3', (0, 0, 0.7), (0, 0, 0.8), 'Root'); bone('Ghost', (1, 1, 1), (1, 1, 1.2), 'Root')
bpy.ops.object.mode_set(mode='OBJECT')
def mesh(name, verts, faces, groups, uvs=None):
    me = bpy.data.meshes.new(name); me.from_pydata(verts, [], faces); me.update()
    o = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(o)
    o.parent = arm; md = o.modifiers.new('Armature', 'ARMATURE'); md.object = arm
    for vi, gw in enumerate(groups):
        for g, w in gw:
            vg = o.vertex_groups.get(g) or o.vertex_groups.new(name=g); vg.add([vi], w, 'REPLACE')
    uv = me.uv_layers.new(name='UVMap')
    for li, l in enumerate(me.loops):
        uv.uv[li].vector = uvs[li] if uvs else (me.vertices[l.vertex_index].co.x, me.vertices[l.vertex_index].co.y)
    return o
# a quad and a triangle sharing the edge 1-2, which is a UV seam (vertices 1 and 2 have another UV in each face)
V = [(0, 0, 1), (1, 0, 1), (1, 1, 1), (0, 1, 1), (2, 0.5, 1)]
F = [(0, 1, 2, 3), (1, 4, 2)]
G = [[('Root', 1.0)], [('Root', 0.5), ('Arm', 0.5)], [('Arm', 0.3), ('B1', 0.3), ('B2', 0.2), ('B3', 0.15), ('Root', 0.05)],
     [('Arm', 1.0)], [('Arm', 0.999), ('B1', 0.0005), ('B2', 0.0005)]]
UV = [(0, 0), (0.5, 0), (0.5, 0.5), (0, 0.5), (0.9, 0.1), (1.0, 0.5), (0.6, 0.5)]
mat = bpy.data.materials.new('mata'); body = mesh('Body', V, F, G, UV); body.data.materials.append(mat)
mesh('REF_vanilla', V, F, G)
o = mesh('Unweighted', [(0, 0, 0), (1, 0, 0), (0, 1, 0)], [(0, 1, 2)], [[('Root', 1.0)], [('Root', 1.0)], []])
o.modifiers['Armature'].object = None
o = mesh('NotABone', [(0, 0, 0), (1, 0, 0), (0, 1, 0)], [(0, 1, 2)], [[('Root', 1.0)], [('Nope', 1.0)], [('Root', 1.0)]])
o.modifiers['Armature'].object = None
s = bpy.data.meshes.new('sail'); s.from_pydata([(0, 0, 2), (1, 0, 2), (0, 1, 2)], [], [(0, 1, 2)])
so = bpy.data.objects.new('sail_01_cloth', s); bpy.context.scene.collection.objects.link(so); so.parent = arm
so.vertex_groups.new(name='Arm')
bpy.ops.wm.save_as_mainfile(filepath=out)
print('SCENE OK')
'''


@pytest.fixture(scope='module')
def scene(tmp_path_factory):
    exe = blender_exe()
    if not exe:
        pytest.skip('no Blender (BLENDER, config/tool-paths.local.json or PATH)')
    d = tmp_path_factory.mktemp('rig_table')
    (d / 'scene.py').write_text(SCENE)
    blend = d / 'scene.blend'
    r = subprocess.run([exe, '-b', '--factory-startup', '--python-exit-code', '1', '--python', str(d / 'scene.py'),
                        '--', str(blend)], capture_output=True, text=True, errors='replace', timeout=300)
    assert r.returncode == 0 and blend.is_file(), r.stdout[-2000:] + r.stderr[-2000:]
    return exe, blend, d


def run_rt(scene, out, *args):
    exe, blend, _ = scene
    r = subprocess.run([exe, '-b', str(blend), '--factory-startup', '--python-exit-code', '1', '--python',
                        str(HERE.parent / 'rig_table.py'), '--', str(out)] + list(args),
                       capture_output=True, text=True, errors='replace', timeout=300)
    return r


def test_sail_mode_writes_only_the_legacy_lines(scene):
    out = scene[2] / 'sail.gxo'
    r = run_rt(scene, out)
    assert r.returncode == 0, r.stderr[-2000:]
    lines = out.read_text().splitlines()
    kinds = [ln.split()[0] for ln in lines]
    assert set(kinds) == {'b', 'm', 'mb', 'mm', 'v'} and kinds.count('b') == 6
    assert lines[kinds.index('m'):] == ['m "sail_01_cloth"', 'mb "Arm"', 'mm 1', 'v 0 0 2', 'v 1 0 2', 'v 0 1 2']
    assert 'WROTE' in r.stdout and 'sail meshes 1' in r.stdout


def test_skinned_mode_refuses_ngons_without_triangulate(scene):
    r = run_rt(scene, scene[2] / 'x.gxo', '--skinned', '--objects', 'Body')
    assert r.returncode != 0 and 'not triangles' in (r.stdout + r.stderr)


def test_skinned_mode_refuses_unweighted_vertices_and_foreign_groups(scene):
    r = run_rt(scene, scene[2] / 'x.gxo', '--skinned', '--objects', 'Unweighted', '--triangulate')
    assert r.returncode != 0 and 'without weight' in (r.stdout + r.stderr)
    r = run_rt(scene, scene[2] / 'x.gxo', '--skinned', '--objects', 'NotABone', '--triangulate')
    assert r.returncode != 0 and "not bones of Rig: ['Nope']" in (r.stdout + r.stderr)


def test_skinned_mode_writes_a_model_pose_sim_reads(scene):
    out = scene[2] / 'body.gxo'
    r = run_rt(scene, out, '--skinned', '--triangulate', '--quantize')
    assert r.returncode == 0, r.stdout[-2000:] + r.stderr[-2000:]
    text = out.read_text()
    assert text.splitlines()[0] == 'mt "mata"' and 'm "REF_vanilla"' not in text
    bones, meshes = pose_sim.parse_model(out)
    assert [b['name'] for b in bones] == ['Root', 'Arm', 'B1', 'B2', 'B3', 'Ghost']
    assert np.allclose(bones[1]['W0'][3, :3], [0, 0, 1])
    y = bones[1]['W0'][1, :3]                                          # Blender bone Y axis = head -> tail
    assert np.allclose(y, np.array([0.5, 0, 0.5]) / np.linalg.norm([0.5, 0, 0.5]), atol=1e-6)
    (m,) = meshes
    assert m['name'] == 'Body' and m['mb'] == ['Root', 'Arm', 'B1', 'B2', 'B3']   # Ghost carries no weight
    assert len(m['f']) == 3 and len(m['v']) == 7                       # 5 vertices + 2 split on the UV seam (1, 2)
    for w in m['vw']:
        k = [x for x in w[:4] if x > 0]
        assert 1 <= len(k) <= 4 and abs(sum(w[:4]) - 1) < 1e-6
        assert all(abs(x * 255 - round(x * 255)) < 1e-6 for x in w[:4])
    five = [w for v, w in zip(m['v'], m['vw']) if np.allclose(v, [1, 1, 1])]
    assert five and all(sum(1 for x in w[:4] if x > 0) == 4 for w in five)   # 5 influences limited to 4
    dust = [w for v, w in zip(m['v'], m['vw']) if np.allclose(v, [2, 0.5, 1])][0]
    assert dust[:4] == [1, 0, 0, 0]                                    # 0.0005 weights dropped
    V = np.array(m['v'])
    vn = np.array([[float(x) for x in ln.split()[1:]] for ln in text.splitlines() if ln.startswith('vn ')])
    for f in m['f']:
        a, b, c = (V[i - 1] for i in f)
        assert np.cross(b - a, c - a) @ vn[f[0] - 1] > 0               # CCW winding along the stored normal
    assert 'max influences 4 (1 vertices limited to 4)' in r.stdout
    out_rest = pose_sim.skin(bones, pose_sim.pose(bones, {}), m)
    assert np.allclose(out_rest, m['v'], atol=1e-6)


ORDER = r'''
import bpy, sys
a = sys.argv[sys.argv.index('--') + 1:]
bpy.data.objects['Rig']['gxo_bone_order'] = a[1].split(',')
bpy.ops.wm.save_as_mainfile(filepath=a[0])
'''


def test_gxo_bone_order_sets_the_written_order_and_refuses_a_child_first(scene):
    exe, _, d = scene
    (d / 'order.py').write_text(ORDER)
    for name, order in (('ok', 'Root,Ghost,B3,B2,B1,Arm'), ('bad', 'Arm,Root,Ghost,B3,B2,B1')):
        r = subprocess.run([exe, '-b', str(scene[1]), '--factory-startup', '--python-exit-code', '1', '--python',
                            str(d / 'order.py'), '--', str(d / ('order_%s.blend' % name)), order],
                           capture_output=True, text=True, errors='replace', timeout=300)
        assert r.returncode == 0, r.stderr[-2000:]
    ok = (exe, d / 'order_ok.blend', d)
    out = d / 'order.gxo'
    r = run_rt(ok, out, '--skinned', '--triangulate', '--objects', 'Body')
    assert r.returncode == 0, r.stderr[-2000:]
    bones, (m,) = pose_sim.parse_model(out)
    assert [b['name'] for b in bones] == ['Root', 'Ghost', 'B3', 'B2', 'B1', 'Arm']
    assert [b['parent'] for b in bones] == [-1, 0, 0, 0, 0, 0]
    assert m['mb'] == ['Root', 'B3', 'B2', 'B1', 'Arm']                 # weighted bones follow the same order
    r = run_rt((exe, d / 'order_bad.blend', d), d / 'bad.gxo', '--skinned', '--triangulate', '--objects', 'Body')
    assert r.returncode != 0 and 'before their parent' in (r.stdout + r.stderr)


def test_skinned_scale_multiplies_positions_and_bone_translations(scene):
    out = scene[2] / 'half.gxo'
    r = run_rt(scene, out, '--skinned', '--triangulate', '--objects', 'Body', '--scale', '0.5')
    assert r.returncode == 0, r.stderr[-2000:]
    bones, (m,) = pose_sim.parse_model(out)
    assert np.allclose(bones[1]['W0'][3, :3], [0, 0, 0.5])
    assert np.allclose(np.array(m['v']).max(0), [1.0, 0.5, 0.5])
