"""Background-Blender adapter tests (skipped without Blender): Tris to Quads with computed normals (D15), the append
loader that never loads an excluded object of a mixed .blend (D0), and the negative-control generator."""
import os
import subprocess

import numpy as np
import pytest

import synth
import toplib as TL
import tl_io

HERE = os.path.dirname(os.path.abspath(__file__))


def test_t2q_recovers_quads_with_normals(blender):
    V, F = synth.quad_sphere(4)
    T = synth.triangulate_fan(F).tolist()
    d = dict(V=V, faces=[tuple(t) for t in T], source=dict(path='synthetic', format='npz'), rig=None, vgroup_dom=None,
             wire_edges=0)
    tl_io.add_t2q(d, exe=blender)
    assert d['t2q']['zero_normals_after_update'] == 0 and d['t2q']['rejected_faces'] == 0
    fk = TL.face_kinds(TL.Topology(len(d['t2q_V']), d['t2q_faces']))
    assert fk['quads'] == len(F) and fk['tris'] == 0


def test_t2q_free_of_input_order(blender):
    V, F = synth.quad_sphere(3)
    T = synth.triangulate_fan(F)
    out = []
    for seed in (None, 5):
        if seed is None:
            P, Q = V, T.tolist()
        else:
            P, Q = synth.permute(V, T.tolist(), seed=seed, faces_too=True)
        d = dict(V=P, faces=[tuple(t) for t in Q], source={}, rig=None, vgroup_dom=None, wire_edges=0)
        tl_io.add_t2q(d, exe=blender)
        out.append(sorted(tuple(sorted(map(tuple, np.round(d['t2q_V'][list(f)], 6)))) for f in d['t2q_faces']))
    assert out[0] == out[1]


def test_append_never_loads_excluded(blender, tmp_path):
    blend = tmp_path / 'fixture.blend'
    subprocess.run([blender, '-b', '--factory-startup', '--disable-autoexec', '--python-exit-code', '2', '--python',
                    os.path.join(HERE, 'make_fixture_blend.py'), '--', str(blend)], check=True, capture_output=True)
    names = tl_io.blend_names(str(blend), exclude='EXCLUDED', exe=blender)        # case-insensitive
    assert 'Cube - Keep' in names['objects'] and not any('Excluded' in n for n in names['objects'])
    d = tl_io.load(str(blend), select='^Cube', exclude='EXCLUDED', blender=blender)
    assert [o['name'] for o in d['source']['objects']] == ['Cube - Keep'] and len(d['faces']) == 6
    with pytest.raises(ValueError):
        tl_io.load(str(blend), blender=blender)            # a .blend is never loaded whole


def test_control_generator(blender, tmp_path):
    V, F = synth.quad_sphere(6)
    src = tmp_path / 'src.npz'
    tl_io.save_npz(str(src), V, F)
    out = tmp_path / 'dec.npz'
    tl_io.run_blender(['control', str(src), str(out), '--method', 'decimate', '--ratio', '0.2'], exe=blender)
    d = tl_io.load_npz(str(out))
    fk = TL.face_kinds(TL.Topology(len(d['V']), d['faces']))
    assert fk['tris'] > 0 and fk['faces'] < len(F)
