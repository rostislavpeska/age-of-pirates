"""The blueprint (definitions.md section B): fields, no coordinates, deterministic hash, independent of vertex and face
order where the input order carries no meaning."""
import json

import numpy as np

import synth
import toplib as TL
import blueprint as BP


def loaded(V, F):
    return dict(V=np.asarray(V, float), faces=[tuple(f) for f in F], source=dict(path='synthetic', format='npz'),
                rig=None, vgroup_dom=None, wire_edges=0)


def bp_of(V, F, kind='head', **kw):
    return BP.build(TL.analyse(loaded(V, F), kind=kind, **kw))


def test_fields_low_poly_head():
    bp = bp_of(*synth.quad_sphere(3))
    for k in ('schema', 'meta', 'budget', 'regions', 'head_share', 'poles', 'loops', 'pole_links', 'face_rings',
              'plane_map', 'symmetry', 'hash'):
        assert k in bp, k
    assert bp['budget']['quads'] == 54 and bp['budget']['tri_equivalent'] == 108
    assert bp['poles']['counts'] == {'3': 8, '5': 0, '6+': 0} and len(bp['poles']['list']) == 8
    assert bp['plane_map']['planes'] >= 6
    assert bp['loops']['open'] == len(bp['loops']['open_list'])
    for lp in bp['loops']['open_list']:
        assert lp['start']['type'] == 'pole3' and lp['end']['type'] == 'pole3'


def test_hash_is_deterministic():
    V, F = synth.quad_sphere(4)
    a, b = bp_of(V, F), bp_of(V, F)
    assert a['hash'] == b['hash'] and len(a['hash']) == 64


def test_hash_free_of_vertex_and_face_order():
    V, F = synth.quad_sphere(4)
    a = bp_of(V, F)
    for seed in (1, 2):
        P, Q = synth.permute(V, F, seed=seed)
        assert bp_of(P, Q)['hash'] == a['hash']


def test_hash_sees_topology_change():
    V, F = synth.quad_sphere(3)
    W, G = synth.quad_sphere(4)
    assert bp_of(V, F)['hash'] != bp_of(W, G)['hash']


def test_no_coordinates_in_blueprint():
    bp = bp_of(*synth.quad_sphere(3))
    txt = json.dumps(bp, default=TL._json_default)
    for p in bp['poles']['list']:
        assert set(p) <= {'valence', 'region', 'zone', 'segment', 't', 'angle_deg', 'radius_over_H', 'pos_over_H', 'id'}
    assert '"V"' not in txt and '"faces": [[' not in txt


def test_limb_blueprint_rings(tmp_path):
    V, F, J = synth.two_segment_limb()
    sk = tmp_path / 'sk.json'
    sk.write_text(json.dumps({'l_shoulder': J['a'], 'l_elbow': J['b'], 'l_wrist': J['c']}))
    bp = bp_of(V, F, kind='body', skeleton=str(sk))
    assert bp['rings']['upperarm_l']['count'] == 5 and bp['rings']['forearm_l']['sides'] == [8, 8, 8, 8]
    assert bp['joints']['elbow_l']['rings_in_band'] == 1
    assert bp['loops']['closed_roles'].get('ring') == 9
