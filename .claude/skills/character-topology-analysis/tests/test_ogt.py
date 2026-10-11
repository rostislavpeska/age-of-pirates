"""OGT read-back of source polygons from the glTF triangle order (definitions.md D14), on synthetic index streams."""
import numpy as np

import synth
import tl_io


def prim(T, base=0):
    T = np.asarray(T, np.int64)
    return dict(node='n', prim=0, T=T, base=base, n=int(T.max()) + 1, neg_det=False)


def as_sets(faces):
    return sorted(tuple(sorted(f)) for f in faces)


def test_fan_runs_rebuild_quads():
    V, F = synth.grid(3, 2)
    T = synth.triangulate_fan(F)
    runs = tl_io.fan_runs(T)
    assert len(runs) == len(F)
    assert as_sets([p for p, _ in runs]) == as_sets(F)


def test_read_back_quads():
    V, F = synth.grid(3, 2)
    polys, rep = tl_io.ogt_read_back(V, [prim(synth.triangulate_fan(F))])
    assert rep['used'] and rep['strict_pair_share'] == 1.0
    assert as_sets(polys) == as_sets(F) and rep['ambiguous_six_runs'] == 0


def test_six_run_read_as_two_quads():
    # two quads fanned from the same first corner: (a b c d) + (a d e f) = one six-triangle-corner run
    V = np.array([[0, 0, 0], [1, 0, 0], [2, 0, 0], [2, 0, 1], [1, 0, 1], [0, 0, 1], [3, 0, 0], [3, 0, 1]], float)
    T = [[0, 1, 2], [0, 2, 3], [0, 3, 4], [0, 4, 5]]
    # in a pure quad stream (every strict pair shares an edge) the run is split into its pairs
    polys, rep = tl_io.ogt_read_back(V, [prim(T)])
    assert rep['split_pure_quad_stream'] == 1 and rep['ambiguous_six_runs'] == 0
    assert as_sets(polys) == as_sets([[0, 1, 2, 3], [0, 3, 4, 5]])
    # with a lone triangle in the stream it is not pure: the six-run is ambiguous, read as two quads and counted
    polys, rep = tl_io.ogt_read_back(V, [prim(T + [[2, 6, 7]])])
    assert rep['ambiguous_six_runs'] == 1
    assert as_sets([p for p in polys if len(p) == 4]) == as_sets([[0, 1, 2, 3], [0, 3, 4, 5]])
    assert as_sets(tl_io.six_runs_as_pairs([(0, 1, 2, 3, 4, 5)])) == as_sets([[0, 1, 2, 3], [0, 3, 4, 5]])


def test_triangle_kept():
    V = np.array([[0, 0, 0], [1, 0, 0], [0, 0, 1], [1, 0, 1]], float)
    T = [[0, 1, 2], [0, 2, 3], [3, 2, 1]]            # a quad, then a lone triangle
    polys, rep = tl_io.ogt_read_back(V, [prim(T + [[1, 3, 0], [1, 0, 2]])])
    assert any(len(p) == 3 for p in polys)


def test_broken_order_is_not_read():
    V, F = synth.grid(4, 4)
    T = synth.triangulate_fan(F)
    rng = np.random.default_rng(1)
    polys, rep = tl_io.ogt_read_back(V, [prim(T[rng.permutation(len(T))])])
    assert polys is None and rep['used'] is False and 'skipped' in rep


def test_repeated_welded_vertex_splits_run():
    # a seam: vertex 4 duplicates vertex 1 (same position, own raw id) - the run (0 1 2 3 4 5) repeats a welded vertex
    V = np.array([[0, 0, 0], [1, 0, 0], [1, 0, 1], [0, 0, 1], [1, 0, 0], [0.5, 0, -1]], float)
    T = [[0, 1, 2], [0, 2, 3], [0, 3, 4], [0, 4, 5]]
    polys, rep = tl_io.ogt_read_back(V, [prim(T)])
    assert rep['split_repeat_vertex'] == 1 and all(len(p) == 4 for p in polys) and len(polys) == 2


def test_read_back_is_vertex_numbering_free():
    V, F = synth.grid(3, 3)
    T = synth.triangulate_fan(F)
    polys, _ = tl_io.ogt_read_back(V, [prim(T)])
    perm = np.random.default_rng(2).permutation(len(V))
    inv = np.empty_like(perm)
    inv[perm] = np.arange(len(V))
    polys2, _ = tl_io.ogt_read_back(V[perm], [prim(inv[T])])
    assert as_sets([[int(perm[v]) for v in p] for p in polys2]) == as_sets(polys)
