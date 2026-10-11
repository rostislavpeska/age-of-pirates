"""Known-answer tests of the core metrics (definitions.md D1-D10, D16) on synthetic meshes."""
import numpy as np

import synth
import toplib as TL


def topo_of(V, F, **kw):
    WV, WF, rep, _ = TL.weld_and_clean(V, F, **kw)
    return WV, WF, TL.Topology(len(WV), WF), rep


# ---------------------------------------------------------------------------------------------------------------- D2 weld
def test_weld_recovers_split_export():
    V, F = synth.split_grid(3, 2)
    WV, WF, t, rep = topo_of(V, F)
    assert len(V) == 24 and rep['verts_final'] == 12
    assert t.n_boundary == 10 and t.n_nonmanifold == 0
    assert rep['fused_by_tolerance'] is False


def test_weld_never_fuses_stacked_cards():
    V, F = synth.stacked_cards(gap=1e-3)
    _, WF, _, rep = topo_of(V, F)
    assert rep['verts_final'] == 8 and len(WF) == 2
    assert rep['fused_by_tolerance'] is False


def test_weld_reports_tolerance_fusion():
    V, F = synth.stacked_cards(gap=1e-7)          # inside 1e-6 x diagonal: fused, and reported as such
    _, WF, _, rep = topo_of(V, F)
    assert rep['verts_final'] == 4 and len(WF) == 1 and rep['duplicate'] == 1
    assert rep['fused_by_tolerance'] is True
    assert rep['fusion_check']['duplicate_faces'] == {'exact': 0, 'rule': 1}


def test_weld_diagonal_ignores_unreferenced_vertices():
    V, F = synth.grid(2, 2)
    far = np.vstack([V, [[1000.0, 1000.0, 1000.0]]])  # an unreferenced helper vertex far away
    _, _, _, rep = topo_of(far, F)
    assert abs(rep['diag'] - np.linalg.norm([1.0, 0.0, 1.0])) < 1e-6
    assert rep['verts_referenced'] == 9 and rep['verts_file'] == 10


# ---------------------------------------------------------------------------------------------------------------- D1, D3
def test_canonical_order_is_input_order_free():
    V, F = synth.quad_sphere(3)
    A = TL.weld_and_clean(V, F)
    P, Q = synth.permute(V, F, seed=3)
    B = TL.weld_and_clean(P, Q)
    assert np.allclose(A[0], B[0]) and A[1] == B[1]


def test_clean_faces_counts():
    kept, cnt = TL.clean_faces([(0, 1, 2, 3), (0, 1, 1, 2), (0, 1, 0), (3, 2, 1, 0), (1, 2, 3, 0), (4, 5, 4, 6)])
    assert kept == [(0, 1, 2, 3), (0, 1, 2)]           # the repeated corner collapses to a triangle
    assert cnt == dict(degenerate=1, invalid=1, duplicate=2, duplicate_reversed=1)


# ---------------------------------------------------------------------------------------------------------------- D5, D7
def test_grid_counts():
    _, _, t, _ = topo_of(*synth.grid(4, 3))
    fk = TL.face_kinds(t)
    assert fk['quads'] == 12 and fk['tris'] == 0 and fk['ngons'] == 0 and fk['tri_equivalent'] == 24
    pc, poles, inner = TL.pole_census(t)
    assert pc['inner'] == 6 and pc['total'] == 0 and pc['valence_hist'] == {4: 6}
    bl = t.boundary_loops()
    assert len(bl) == 1 and bl[0]['nverts'] == 14 and bl[0]['closed']


def test_cube_poles_and_rings():
    _, _, t, _ = topo_of(*synth.cube())
    pc, _, _ = TL.pole_census(t)
    assert pc['v3'] == 8 and pc['v5'] == 0 and pc['v6plus'] == 0
    assert t.n_boundary == 0 and t.n_nonmanifold == 0 and not t.bowtie_vertices()
    strips = t.face_strips()
    assert sorted(len(s['faces']) for s in strips if s['closed']) == [4, 4, 4] and len(strips) == 3


def test_quad_sphere_eight_poles():
    _, _, t, _ = topo_of(*synth.quad_sphere(3))
    pc, _, _ = TL.pole_census(t)
    assert t.nF == 54 and pc['verts'] == 56 and pc['v3'] == 8 and pc['total'] == 8


def test_uv_sphere_six_plus_poles():
    _, _, t, _ = topo_of(*synth.uv_sphere(12, 8))
    pc, _, _ = TL.pole_census(t)
    assert pc['v6plus'] == 2 and pc['valence_hist'][12] == 2
    assert pc['p6_share_of_verts'] == round(2 / pc['verts'], 5)


# ---------------------------------------------------------------------------------------------------------------- D6
def test_bowtie_definition():
    _, _, t, _ = topo_of(*synth.bowtie())
    assert len(t.bowtie_vertices()) == 1
    assert t.n_nonmanifold == 0
    inner = t.inner_mask()
    assert not inner[t.bowtie_vertices()[0]]


def test_nonmanifold_fin():
    _, _, t, _ = topo_of(*synth.fin())
    assert t.n_nonmanifold == 1


def test_flipped_winding():
    _, _, t, _ = topo_of(*synth.flipped_pair())
    assert len(t.flipped_edges()) == 1


# ---------------------------------------------------------------------------------------------------------------- D8, D10
def test_grid_edge_loops_and_strips():
    _, _, t, _ = topo_of(*synth.grid(4, 3))
    loops = t.edge_loops()
    assert len(loops) == 19 and sum(len(L['edges']) for L in loops) == t.nE == 31
    assert not any(L['closed'] for L in loops)
    strips = t.face_strips()
    assert len(strips) == 7 and sorted(len(s['faces']) for s in strips) == [3, 3, 3, 3, 4, 4, 4]


def test_tube_rings():
    _, _, t, _ = topo_of(*synth.tube(n=8, rows=6))
    loops = t.edge_loops()
    closed = [L for L in loops if L['closed']]
    assert len(closed) == 5 and all(len(L['verts']) == 8 for L in closed)
    assert len(t.boundary_loops()) == 2
    strips = t.face_strips()
    assert sorted(len(s['faces']) for s in strips if s['closed']) == [8] * 6


# ---------------------------------------------------------------------------------------------------------------- D4
def test_caps_only_when_declared():
    V, F = synth.tube(n=8, rows=4, caps='ngon')
    WV, WF, _, _ = topo_of(V, F)
    kept, rep = TL.judged_unit(WV, WF)
    assert len(kept) == len(WF) and len(rep['cap_candidates']) == 2 and not rep['caps']
    kept, rep = TL.judged_unit(WV, WF, declared_caps=2)
    assert len(kept) == len(WF) - 2 and len(rep['caps']) == 2
    kept, rep = TL.judged_unit(WV, WF, declared_caps=1)
    assert len(kept) == len(WF) and rep['caps_mismatch'] == dict(declared=1, found=2)


def test_fan_caps():
    V, F = synth.tube(n=8, rows=4, caps='fan')
    WV, WF, _, _ = topo_of(V, F)
    kept, rep = TL.judged_unit(WV, WF, declared_caps=2)
    assert len(kept) == 32 and all(c['kind'] == 'fan' for c in rep['caps'])


def test_eyeballs_always_excluded():
    head = synth.quad_sphere(4, radius=1.0)
    eye_l = synth.quad_sphere(2, radius=0.06, centre=(0.3, -0.9, 0.2))
    eye_r = synth.quad_sphere(2, radius=0.06, centre=(-0.3, -0.9, 0.2))
    V = np.vstack([head[0], eye_l[0], eye_r[0]])
    n1, n2 = len(head[0]), len(head[0]) + len(eye_l[0])
    F = head[1] + [[v + n1 for v in f] for f in eye_l[1]] + [[v + n2 for v in f] for f in eye_r[1]]
    WV, WF, _, _ = topo_of(V, F)
    kept, rep = TL.judged_unit(WV, WF)
    assert len(rep['eyeballs']) == 2 and len(kept) == len(head[1])
    kept, rep = TL.judged_unit(WV, WF, keep_eyeballs=True)
    assert len(kept) == len(WF)


# ---------------------------------------------------------------------------------------------------------------- D9
def test_concave_quad():
    WV, WF, t, _ = topo_of(*synth.concave_quad())
    q = TL.quad_quality(WV, t)
    assert q['concave_quads'] == 1 and q['concave_worst_deg'] > 180


def test_flat_square_quality():
    WV, WF, t, _ = topo_of(*synth.grid(1, 1))
    q = TL.quad_quality(WV, t)
    assert q['concave_quads'] == 0 and abs(q['aspect']['max'] - 1.0) < 1e-9
    assert abs(q['min_corner_deg']['p0'] - 90.0) < 1e-6 and q['planarity_deg']['max'] == 0.0


# ---------------------------------------------------------------------------------------------------------------- D16
def test_symmetry_exact_and_broken():
    V, F = synth.mirrored_grid(4, 3)
    WV, WF, t, _ = topo_of(V, F)
    H = float(np.ptp(WV[:, 2]))
    s, _ = TL.symmetry(WV, t, H)
    assert s['partner_share'] == 1.0 and s['face_mirror_share'] == 1.0 and s['centre_inexact'] == 0
    V2 = V.copy()
    V2[1, 2] += 0.01
    WV, WF, t, _ = topo_of(V2, F)
    s, _ = TL.symmetry(WV, t, float(np.ptp(WV[:, 2])))
    assert s['partner_share'] < 1.0


# ---------------------------------------------------------------------------------------------------------------- D11 winding
def test_winding_number():
    th = np.linspace(0, 2 * np.pi, 12, endpoint=False)
    P = np.c_[np.cos(th), np.sin(th), np.zeros_like(th)]
    wn, _ = TL.winding_number(P, np.zeros(3), np.array([0, 0, 1.0]))
    assert abs(abs(wn) - 1.0) < 1e-9
    wn, _ = TL.winding_number(P + [5, 0, 0], np.zeros(3), np.array([0, 0, 1.0]))
    assert abs(wn) < 1e-9
