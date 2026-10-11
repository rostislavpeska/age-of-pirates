"""Known-answer tests of the skeleton-based features (definitions.md D11-D13, D17-D26) on a synthetic two-segment limb
with a given skeleton, plus sections, label clean-up and the plane map."""
import json

import numpy as np
import pytest

import synth
import toplib as TL
import tl_features as FT
import tl_skeleton as SK


def loaded(V, F):
    return dict(V=np.asarray(V, float), faces=[tuple(f) for f in F], source=dict(path='synthetic', format='npz'),
                rig=None, vgroup_dom=None, wire_edges=0)


@pytest.fixture()
def limb(tmp_path):
    V, F, J = synth.two_segment_limb(n=8, rows=10, radius=0.08, length=1.0)
    sk = tmp_path / 'skeleton.json'
    sk.write_text(json.dumps({'l_shoulder': J['a'], 'l_elbow': J['b'], 'l_wrist': J['c']}))
    return TL.analyse(loaded(V, F), kind='body', skeleton=str(sk))


def test_limb_segments_from_given_skeleton(limb):
    names = [s['name'] for s in limb['_ctx']['skel']['segs']]
    assert names == ['upperarm_l', 'forearm_l']
    assert limb['skeleton']['source'].startswith('given')


def test_limb_rings(limb):
    rg = limb['rings']
    assert rg['upperarm_l']['rings'] == 5 and rg['forearm_l']['rings'] == 4
    assert set(rg['upperarm_l']['sides'] + rg['forearm_l']['sides']) == {8}
    assert all(t < 1 for t in rg['upperarm_l']['tilt_deg'])


def test_limb_ring_cover(limb):
    rg = limb['rings']
    assert rg['upperarm_l']['ring_face_share'] == 1.0 and rg['forearm_l']['ring_face_share'] == 1.0
    assert rg['upperarm_l']['ring_face_share_aligned'] == 1.0


def test_joint_band(limb):
    jr = limb['joint_rings']['elbow_l']
    assert jr['rings_in_band'] == 1 and abs(jr['band_length_over_H'] - 0.5) < 1e-9
    assert limb['band_poles']['elbow_l']['poles_band'] == 0


def test_band_pole_crease_side(limb):
    ctx = limb['_ctx']
    V = ctx['V']
    front = int(np.where((np.abs(V[:, 2] - 0.5) < 1e-9) & (V[:, 1] < -0.07))[0][0])    # elbow ring, front (-Y)
    back = int(np.where((np.abs(V[:, 2] - 0.5) < 1e-9) & (V[:, 1] > 0.07))[0][0])
    ctx['poles'] = ctx['poles'].copy()
    ctx['poles'][[front, back]] = True
    bp = FT.band_poles(ctx)['elbow_l']
    assert bp['poles_band'] == 2 and bp['poles_band_crease'] == 1 and bp['poles_band_extension'] == 1
    assert bp['poles_ring_band'] == 2


def test_band_faces_between_rings(limb):
    ctx = limb['_ctx']
    V = ctx['V']
    loops = [L for L in ctx['loops'] if L['closed']]
    z = {round(float(V[L['verts'], 2].mean()), 3): L for L in loops}
    band = FT.band_faces(ctx['topo'], z[0.2]['edges'], z[0.4]['edges'])
    assert len(band) == 16
    assert FT.band_faces(ctx['topo'], z[0.2]['edges'], z[0.2]['edges']) is None


def test_no_parity_transitions_on_constant_rings(limb):
    assert limb['ring_parity']['transitions'] == 0


def test_section_components():
    V, F = synth.tube(n=8, rows=4)
    W, G = synth.tube(n=8, rows=4, origin=(1, 0, 0))
    V2 = np.vstack([V, W])
    F2 = F + [[v + len(V) for v in f] for f in G]
    WV, WF, _, _ = TL.weld_and_clean(V2, F2)
    topo = TL.Topology(len(WV), WF)
    FE = [topo.face_edges(f) for f in range(topo.nF)]
    comps = SK.section_components(WV, topo.E, FE, np.array([0, 0, 0.55]), np.array([0, 0, 1.0]))
    assert len(comps) == 2 and all(len(c) == 8 for c in comps)
    P = SK.section_points(WV, topo.E, np.array([0, 0, 0.55]), np.array([0, 0, 1.0]))
    assert len(P) == 16 and np.allclose(P[:, 2], 0.55)


def test_label_island_cleanup():
    V, F = synth.grid(6, 6)
    WV, WF, _, _ = TL.weld_and_clean(V, F)
    topo = TL.Topology(len(WV), WF)
    lab = np.zeros(len(WV), np.int64)
    x, z = WV[:, 0], WV[:, 2]
    lab[x > 0.8] = 1                                           # the main piece of label 1
    island = (np.abs(x - 0.5) < 1e-9) & (np.abs(z - 0.5) < 1e-9)
    lab[island] = 1                                            # a one-vertex island of label 1 inside label 0
    new, moved = SK.clean_labels(lab, topo)
    assert moved == 1 and new[island][0] == 0 and (new[x > 0.8] == 1).all() and (new[~island & (x < 0.8)] == 0).all()


def test_plane_map_cube_head():
    V, F = synth.cube()
    rep = TL.analyse(loaded(V, F), kind='head')
    pm = rep['plane_map']
    assert pm['applied'] and pm['planes'] == 6 and pm['planes_over_2pct'] == 6
    assert abs(sum(p['area_share'] for p in pm['patches']) - 1.0) < 1e-3
    assert {p['facing'] for p in pm['patches']} == {'front', 'back', 'left', 'right', 'top', 'under'}


def test_single_region_part():
    V, F = synth.quad_sphere(3)
    rep = TL.analyse(loaded(V, F), kind='head')
    assert rep['regions']['per_region']['head']['tri_share'] == 1.0 and rep['regions']['head_share'] == 1.0


def test_estimator_on_section_fallback():
    # the vertex-slab fallback and the section estimator both return every canonical key on a crude stick figure
    V, F = synth.tube(n=6, rows=8, radius=0.05, length=1.7)
    J = SK.estimate_joints(V)
    for k in ('l_shoulder', 'l_elbow', 'l_wrist', 'l_hip', 'l_knee', 'l_ankle', 'neck', 'head', 'pelvis'):
        assert k in J and np.all(np.isfinite(J[k]))
