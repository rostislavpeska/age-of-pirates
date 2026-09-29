"""Specimen proof for the bake master (master_unwrap.py, master_bake.py, derive_maps.py, compare_maps.py).

python -m pytest .claude/skills/blender-high-low-baking/scripts/test_master_derive.py -q
Pure numpy (always runs; specimens built in memory / tmp_path, never images in the repo): Blender texel centres,
barycentrics, UV-skip, isometric unfolding, analytic POS master -> derived positions through rotated / mirrored /
scaled / cross-page charts, tangent round trip against an independent Blender formula (sign +1 and -1; a wrong
sign must fail), chart / hit / ID partitions, the margin (extend_fill against a line-by-line transcription of
Blender's IMB_filter_extend incl. page borders, L1 diamond growth, per-receiver overwrite replay and its crop, the
L1-opening check that tells an L1 fill from a square one), footprint vs point under strong minification and the
auto filter switch, the host EXR reader, the packer, compare metrics on known offsets.
Blender integration (skipped unless QA_BLENDER names blender.exe; BLENDER_GATE = a gate command run before every
launch): a fixture LOW (owner/member grid, bent strip, ngon, flat faces) + a bumped HIGH with a cutout hole and
tile-ID emission; master_unwrap -> master_bake -> derive onto layout A (sharing) and layout B (a member unshared,
a chart rotated 90 deg and mirrored), each compared with a direct bake_owner_maps bake of that layout; guards
refuse a moved LOW vertex, a changed HIGH file, an owner without master data and a freeze mismatch; a derive
with a flipped bitangent sign fails the comparison.
"""
import importlib.util
import json
import math
import os
import shlex
import subprocess
import sys
from pathlib import Path

import numpy as np
import pytest

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))


def _load(name):
    spec = importlib.util.spec_from_file_location(name, HERE / f'{name}.py')
    mod = importlib.util.module_from_spec(spec); spec.loader.exec_module(mod)
    return mod


D = _load('derive_maps'); U = _load('master_unwrap'); C = _load('compare_maps')


# ------------------------------------------------------------------------------------------ rasterizer
def _inside(tri, px, py):
    s = []
    for i in range(3):
        (x0, y0), (x1, y1) = tri[i], tri[(i + 1) % 3]
        s.append((x1 - x0) * (py - y0) - (y1 - y0) * (px - x0))
    s = np.array(s)
    return (s >= 0).all(0) | (s <= 0).all(0)


@pytest.mark.parametrize('seed', range(5))
def test_rasterize_blender_centres_and_barycentrics(seed):
    rng = np.random.default_rng(seed); W = H = 64
    tri = rng.uniform(2, 60, (3, 2))
    t, x, y, b = D.rasterize(tri[None], W, H)
    yy, xx = np.mgrid[0:H, 0:W]
    want = _inside(tri, xx + .501, yy + .502)
    got = np.zeros((H, W), bool); got[y, x] = True
    assert (got == want).all()
    P = b @ tri                                              # barycentrics reproduce the texel centre
    assert np.allclose(P, np.stack([x + .501, y + .502], 1), atol=1e-9)
    assert np.allclose(b.sum(1), 1) and (b >= -1e-12).all()


def test_shared_edges_claimed_once_and_uv_skip():
    W = H = 32
    sq = np.array([[3.3, 4.1], [27.7, 5.2], [26.4, 28.8], [4.9, 27.3]])
    tris = np.array([sq[[0, 1, 2]], sq[[0, 2, 3]], sq[[0, 2, 3]] + 100])   # the third lies outside: UV-skip
    t, x, y, b = D.rasterize(tris, W, H)
    lin = y * W + x
    assert len(np.unique(lin)) == len(lin), 'a texel centre was claimed by two triangles'
    assert not (t == 2).any(), 'a triangle outside 0..1 must produce no texels'
    yy, xx = np.mgrid[0:H, 0:W]
    want = _inside(sq[[0, 1, 2]], xx + .501, yy + .502) | _inside(sq[[0, 2, 3]], xx + .501, yy + .502)
    assert want.sum() == len(lin)


# ------------------------------------------------------------------------------------------ unfolding + packing
def _grid_faces(nx=3, ny=2, bend=0.0, size=1.0, dens=20.0, ngon=False):
    """planar (or bent about x = nx/2) quad grid as face records; optional 6-gon at the end"""
    def z(xv):
        return max(0.0, xv - nx / 2) * math.tan(math.radians(bend))
    verts = {}
    def vid(i, j):
        return verts.setdefault((i, j), len(verts))
    faces = []
    for j in range(ny):
        for i in range(nx):
            corners = [(i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1)]
            pos = np.array([[a * size, b * size, z(a * size)] for a, b in corners])
            faces.append(dict(key=f'F:{len(faces)}', obj='F', poly=len(faces), verts=[vid(*c) for c in corners], pos=pos,
                              tris=np.array([[0, 1, 2], [0, 2, 3]]), area=0.0, dens=dens))
    if ngon:
        c = np.array([nx * size + 1.5, 0.5, 0]); ang = np.radians(np.arange(6) * 60)
        pos = c + 0.6 * np.stack([np.cos(ang), np.sin(ang), np.zeros(6)], 1)
        faces.append(dict(key=f'F:{len(faces)}', obj='F', poly=len(faces), verts=list(range(1000, 1006)), pos=pos,
                          tris=np.array([[0, 1, 2], [0, 2, 3], [0, 3, 4], [0, 4, 5]]), area=0.0, dens=dens))
    for f in faces:
        f['area'] = sum(U.tri_area3(f['pos'], t) for t in f['tris'])
        n = np.cross(f['pos'][1] - f['pos'][0], f['pos'][2] - f['pos'][0]); f['normal'] = n / np.linalg.norm(n)
        f['cn'] = np.repeat(f['normal'][None], len(f['pos']), 0)
    return faces


def test_unfold_is_an_exact_isometry_and_splits_at_the_angle():
    faces = _grid_faces(4, 2, bend=20.0, ngon=True)
    adj = U.face_adjacency(faces, 1e-4, 30.0)
    charts = U.build_charts(faces, adj, max_extent=1e9)
    for ch in charts:
        for fi in ch['faces']:
            f = faces[fi]; uv = ch['uv'][fi]
            for t in f['tris']:
                for a, b in ((0, 1), (1, 2), (2, 0)):
                    l3 = np.linalg.norm(f['pos'][t[a]] - f['pos'][t[b]]) * f['dens']
                    assert abs(np.linalg.norm(uv[t[a]] - uv[t[b]]) - l3) < 1e-9 * max(l3, 1)
    # normals differ at the bend -> not smooth -> split; corner normals equal on each side -> 2 charts + ngon
    assert len(charts) == 3
    faces2 = _grid_faces(4, 2, bend=20.0)
    for f in faces2:                                          # smooth across the bend -> one chart (20 < 30 deg)
        f['cn'] = np.repeat(np.array([[0, 0, 1.0]]), 4, 0)
    assert len(U.build_charts(faces2, U.face_adjacency(faces2, 1e-4, 30.0), 1e9)) == 1
    assert len(U.build_charts(faces2, U.face_adjacency(faces2, 1e-4, 15.0), 1e9)) == 2


def test_packer_deterministic_no_overlap_gutter_and_extend():
    rng = np.random.default_rng(3)
    boxes = [(int(w), int(h)) for w, h in rng.integers(8, 90, (40, 2))]
    a1, s1 = U.pack(boxes, 256, True); a2, s2 = U.pack(boxes, 256, True)
    assert a1 == a2 and s1 == s2

    def rects(where, bxs):
        return [(p, x, y, w, h) for (p, x, y), (w, h) in zip(where, bxs)]
    R = rects(a1, boxes)
    for i, (p, x, y, w, h) in enumerate(R):
        assert 0 <= x and x + w <= s1[p] and 0 <= y and y + h <= s1[p]
        for q, x2, y2, w2, h2 in R[i + 1:]:
            assert p != q or x + w <= x2 or x2 + w2 <= x or y + h <= y2 or y2 + h2 <= y, 'boxes overlap'
    # boxes carry gutter = margin + 1 on every side -> chart contents stay >= 2 * margin + 2 apart
    existing = {}
    for p, x, y, w, h in R:
        existing.setdefault(p, (s1[p], []))[1].append((x, y, w, h))
    more = [(int(w), int(h)) for w, h in rng.integers(8, 60, (15, 2))]
    a3, s3 = U.pack(more, 256, True, existing)
    for (p, x, y), (w, h) in zip(a3, more):
        for q, x2, y2, w2, h2 in R:
            assert p != q or x + w <= x2 or x2 + w2 <= x or y + h <= y2 or y2 + h2 <= y, 'extend moved into an old chart'
    assert all(s3[p] == s1[p] for p in s1), 'extend changed an existing page size'


def test_min_area_rect_is_a_rotation_with_width_ge_height():
    rng = np.random.default_rng(1)
    P = rng.normal(size=(50, 2)) * [10, 2]
    th = 0.7; Rot = np.array([[math.cos(th), -math.sin(th)], [math.sin(th), math.cos(th)]])
    R, ang, (w, h), off = U.min_area_rect(P @ Rot.T)
    assert abs(np.linalg.det(R) - 1) < 1e-12 and w >= h
    q = (P @ Rot.T) @ R.T - off
    assert q.min() > -1e-9 and abs(q[:, 0].max() - w) < 1e-9


# ------------------------------------------------------------------------------------------ analytic POS master
def _master_from_charts(faces, charts, page, gutter=5):
    """lay charts out like master_unwrap (rect, pack), rasterise, return per-face master uv and page rasters"""
    boxes, geo = [], []
    for ch in charts:
        pts = np.concatenate([ch['uv'][fi] for fi in ch['faces']])
        R, ang, (w, h), off = U.min_area_rect(pts)
        boxes.append((int(math.ceil(w + 2 * gutter)), int(math.ceil(h + 2 * gutter)))); geo.append((R, off))
    where, sizes = U.pack(boxes, page, True)
    muv, mpage, mchart = {}, {}, {}
    for ci, ((p, x, y), (R, off), ch) in enumerate(zip(where, geo, charts)):
        for fi in ch['faces']:
            muv[fi] = (ch['uv'][fi] @ R.T - off + [x + gutter, y + gutter]) / sizes[p]; mpage[fi] = p; mchart[fi] = ci
    pages = {}
    for p, S in sizes.items():
        tris, fo, co, p3 = [], [], [], []
        for fi, f in enumerate(faces):
            if mpage[fi] == p:
                for t in f['tris']:
                    tris.append(muv[fi][t] * S); fo.append(fi); co.append(mchart[fi]); p3.append(f['pos'][t])
        v = U.validate_page(np.array(tris), np.array(fo), np.array(co), S, S)
        assert v['double'] == 0
        pos = np.zeros((S, S, 3)); tri, x, y, b = D.rasterize(np.array(tris), S, S)
        pos[y, x] = np.einsum('ki,kij->kj', b, np.array(p3)[tri])
        pages[p] = dict(size=S, pos=pos, chart=v['chart'], usable=(v['chart'] >= 0) & ~v['border'], status=v['chart'] >= 0)
    return muv, mpage, mchart, pages


def _target(faces, transforms, W):
    """per-face target uv: each face its own chart, unfolded at target density then transformed"""
    tuv = {}
    for fi, f in enumerate(faces):
        base = U.unfold_face(f['pos'], f['tris'], 10.0)
        rot, mirror, scale, shift = transforms[fi % len(transforms)]
        c = base - base.mean(0)
        if mirror:
            c[:, 0] *= -1
        th = math.radians(rot); Rm = np.array([[math.cos(th), -math.sin(th)], [math.sin(th), math.cos(th)]])
        tuv[fi] = (c @ Rm.T * scale + shift) / W
    return tuv


def test_pos_master_derives_exact_positions_through_rotated_mirrored_scaled_crosspage_charts():
    faces = _grid_faces(3, 2, dens=20.0)
    charts = U.build_charts(faces, U.face_adjacency(faces, 1e-4, 30.0), 30.0)   # one face per chart
    muv, mpage, mchart, pages = _master_from_charts(faces, charts, 64)   # small pages -> several master pages
    assert len(charts) >= 3 and len(pages) >= 2
    W = 64
    tr = [(90, False, 1.0, (18, 18)), (0, True, 1.0, (46, 18)), (37, False, 0.5, (18, 46)),
          (180, True, 1.5, (46, 46)), (270, False, 1.0, (18, 18)), (15, True, 0.8, (46, 18))]
    tuv = _target(faces, tr, W)
    tpage = {fi: fi // 4 for fi in range(len(faces))}          # faces 4, 5 on a second target page
    exact_err, other_err, n_exact = 0.0, 0.0, 0
    for tp in (0, 1):
        for fi, f in enumerate(faces):
            if tpage[fi] != tp:
                continue
            tris = tuv[fi][f['tris']] * W
            tri, x, y, b = D.rasterize(tris, W, W)
            truth = np.einsum('ki,kij->kj', b, f['pos'][f['tris']][tri])
            m_uv = np.einsum('ki,kij->kj', b, muv[fi][f['tris']][tri])
            pg = pages[mpage[fi]]; S = pg['size']
            px, py = D.master_px(m_uv, S, S)
            vals, hit, found = D.sample_master(px, py, np.full(len(px), mchart[fi]), pg['chart'], pg['usable'], pg['status'],
                                               pg['pos'], mode='bilinear')
            assert found.all() and hit.all()
            x0 = np.floor(px).astype(int); y0 = np.floor(py).astype(int)
            full = np.ones(len(px), bool)
            for dx in (0, 1):
                for dy in (0, 1):
                    xx = np.clip(x0 + dx, 0, S - 1); yy = np.clip(y0 + dy, 0, S - 1)
                    full &= pg['usable'][yy, xx] & (pg['chart'][yy, xx] == mchart[fi])
            err = np.linalg.norm(vals - truth, axis=1)
            if full.any():
                exact_err = max(exact_err, float(err[full].max())); n_exact += int(full.sum())
            if (~full).any():
                other_err = max(other_err, float(err[~full].max()))
    assert n_exact > 200
    assert exact_err < 1e-5, f'interior positions must be exact: {exact_err}'
    assert other_err < 1.5 / 20.0, f'border samples farther than 1.5 master texels: {other_err}'


# ------------------------------------------------------------------------------------------ tangent conversion
def _blender_world_to_tangent(n_world, T, B, N, M3):
    """independent transcription of RE_bake_normal_world_to_tangent (bake.cc): tsm[0..2] = T, B, N are the
    COLUMNS (Blender matrices are column-major), nor = M3^T n (mul_transposed_mat3_m4_v3), nor = inv(tsm) nor."""
    out = []
    for n, t, b, nn in zip(n_world, T, B, N):
        tsm = [list(t), list(b), list(nn)]                    # tsm[col][row]
        Mm = np.array(tsm).T                                  # math matrix with those columns
        v = np.array([sum(M3[r][c] * n[r] for r in range(3)) for c in range(3)])   # transposed multiply
        x = np.linalg.inv(Mm) @ v
        out.append(x / np.linalg.norm(x))
    return np.array(out)


@pytest.mark.parametrize('sign', [1.0, -1.0])
def test_tangent_round_trip_matches_blender_formula(sign):
    rng = np.random.default_rng(int(sign > 0))
    k = 400
    T = rng.normal(size=(k, 3)); N = rng.normal(size=(k, 3)) + [0, 0, 2]
    N *= rng.uniform(.7, 1.0, (k, 1)); T *= rng.uniform(.7, 1.0, (k, 1))        # interpolated: not unit
    B = sign * np.cross(N, T)
    M3 = np.array([[1.3, .2, 0], [-.1, .9, .3], [.05, 0, 1.1]])                  # scaled, sheared object
    nw = rng.normal(size=(k, 3)) + [0, 0, 1.5]; nw /= np.linalg.norm(nw, axis=1, keepdims=True)
    expect = _blender_world_to_tangent(nw, T, B, N, M3)
    m = nw @ np.linalg.inv(M3).T; m /= np.linalg.norm(m, axis=1, keepdims=True)      # OBJECT bake
    stored = m * 0.5 + 0.5 + 1e-5
    x, ok = D.to_tangent(D.decode_normal(stored), T, N, np.full(k, sign), M3.T @ M3)
    ang = np.degrees(np.arccos(np.clip((x * expect).sum(1), -1, 1)))
    assert ok.all() and ang.max() < 0.01, ang.max()
    xw, _ = D.to_tangent(D.decode_normal(stored), T, N, np.full(k, -sign), M3.T @ M3)
    wrong = np.degrees(np.arccos(np.clip((xw * expect).sum(1), -1, 1)))
    assert np.median(wrong) > 10, 'a flipped bitangent sign must be detected'


# ------------------------------------------------------------------------------------------ partitions
def _two_charts(S=32):
    chart = np.full((S, S), -1); chart[4:28, 4:16] = 0; chart[4:28, 16:28] = 1     # touching charts
    usable = chart >= 0
    return chart, usable


def test_chart_partition_never_bleeds_across_charts():
    chart, usable = _two_charts(); status = usable.copy()
    val = np.zeros((32, 32, 1)); val[chart == 1] = 1.0
    rng = np.random.default_rng(0)
    px = rng.uniform(14.0, 15.99, 500); py = rng.uniform(5, 26, 500)            # chart 0 right next to chart 1
    v, h, f = D.sample_master(px, py, np.zeros(500, int), chart, usable, status, val)
    assert f.all() and np.abs(v).max() == 0.0


def test_hit_partition_keeps_misses_out_and_ids_stay_pure():
    chart, usable = _two_charts(); status = np.zeros_like(usable); status[:, :10] = True; status &= usable
    val = np.where(status[..., None], 1.0, 0.5)
    px = np.linspace(9.1, 9.49, 50); py = np.full(50, 10.3)                       # nearest texel 9 = hit
    v, h, f = D.sample_master(px, py, np.zeros(50, int), chart, usable, status, val)
    assert h.all() and np.allclose(v, 1.0)
    ids = np.zeros((32, 32)); ids[:, :] = (np.arange(32)[None, :] // 4) * 0.1 + (np.arange(32)[:, None] // 4) * 0.01
    emit = np.stack([ids, np.random.default_rng(1).uniform(0, 1, (32, 32)), np.zeros((32, 32))], -1)
    rng = np.random.default_rng(2); px = rng.uniform(4, 27, 800); py = rng.uniform(4, 27, 800)
    cid = chart[np.clip(np.rint(py).astype(int), 0, 31), np.clip(np.rint(px).astype(int), 0, 31)]
    keep = cid >= 0
    st = usable.copy()
    v, h, f = D.sample_master(px[keep], py[keep], cid[keep], chart, usable, st, emit, mode='nearest')
    assert set(np.round(v[:, 0], 6)) <= set(np.round(ids[usable], 6)), 'nearest must never invent an ID'
    vb, _, _ = D.sample_master(px[keep], py[keep], cid[keep], chart, usable, st, emit, mode='bilinear', ids=ids)
    assert set(np.round(vb[:, 0], 6)) <= set(np.round(ids[usable], 6)), 'bilinear inside one ID keeps IDs pure'


# ------------------------------------------------------------------------------------------ EXTEND margin
def _imb_filter_extend(buf, mask, width, height, depth, filt):
    """line-by-line transcription of IMB_filter_extend (Blender 5.0.1 source/blender/imbuf/intern/filter.cc) on
    flat lists: buf[depth * index + c], mask[index] (0 = unassigned), filter_make_index -> -1 off the image,
    the 4-edge-neighbour gate, weight[k] over i (x offset, outer) and j (y offset, inner)."""
    def make_index(x, y):
        return -1 if (x < 0 or x >= width or y < 0 or y >= height) else y * width + x

    def assigned(m, index):
        return index >= 0 and m[index] != 0
    weight = [1, 2, 1, 2, 0, 2, 1, 2, 1]
    src, srcmask = list(buf), list(mask)
    r, cannot_early_out = 0, True
    while cannot_early_out and r < filt:
        cannot_early_out = False
        dst, dstmask = list(src), list(srcmask)
        for y in range(height):
            for x in range(width):
                index = make_index(x, y)
                if assigned(srcmask, index):
                    continue
                if not (assigned(srcmask, make_index(x - 1, y)) or assigned(srcmask, make_index(x + 1, y)) or
                        assigned(srcmask, make_index(x, y - 1)) or assigned(srcmask, make_index(x, y + 1))):
                    continue
                wsum, acc, k = 0.0, [0.0] * depth, 0
                for i in (-1, 0, 1):
                    for j in (-1, 0, 1):
                        if i != 0 or j != 0:
                            t = make_index(x + i, y + j)
                            if assigned(srcmask, t):
                                wsum += weight[k]
                                for c in range(depth):
                                    acc[c] += weight[k] * src[depth * t + c]
                        k += 1
                if wsum != 0:
                    for c in range(depth):
                        dst[depth * index + c] = acc[c] / wsum
                    dstmask[index] = 2
                    cannot_early_out = True
        src, srcmask = dst, dstmask
        r += 1
    return src, srcmask


def _via_reference(img, a, passes):
    H, W, C_ = img.shape
    buf, m = _imb_filter_extend(img.reshape(-1).tolist(), a.reshape(-1).astype(int).tolist(), W, H, C_, passes)
    return np.array(buf).reshape(H, W, C_), np.array(m).reshape(H, W) != 0


def test_extend_fill_matches_imb_filter_extend_incl_page_borders():
    rng = np.random.default_rng(4)
    for trial in range(3):
        img = rng.uniform(0, 1, (17, 23, 3)); a = rng.uniform(0, 1, (17, 23)) < (0.08, 0.15, 0.3)[trial]
        a[0, :5] = True; a[:4, -1] = True                   # assigned texels on the page border
        ref, ra = _via_reference(img, a, 4)
        got, ga = D.extend_fill(img, a, 4)
        assert (ga == ra).all() and np.allclose(got, ref, atol=1e-12)
        assert np.array_equal(got[a], img[a]), 'assigned (owner) texels must never change'


def test_extend_grows_an_l1_diamond_and_never_wraps():
    img = np.zeros((15, 15, 1)); a = np.zeros((15, 15), bool); a[7, 7] = True; img[7, 7] = 1.0
    _, ga = D.extend_fill(img, a, 3)
    yy, xx = np.mgrid[0:15, 0:15]
    assert (ga == (np.abs(yy - 7) + np.abs(xx - 7) <= 3)).all(), 'EXTEND grows 4-neighbour (L1), not 8 (square)'
    a2 = np.zeros((15, 15), bool); a2[0, 0] = True
    _, g2 = D.extend_fill(img, a2, 2)
    assert (g2 == (yy + xx <= 2)).all(), 'no clamping or wrapping at the page border'
    corner = np.zeros((6, 6, 1)); m = np.zeros((6, 6), bool); m[0, 1] = m[1, 0] = True; corner[0, 1] = 1.0; corner[1, 0] = 3.0
    got, _ = D.extend_fill(corner, m, 1)
    assert got[0, 0, 0] == 2.0 and got[1, 1, 0] == 2.0, 'off-page neighbours carry no weight'


def test_replay_margin_overwrites_earlier_receivers_like_the_baker():
    start = np.zeros((12, 20, 1))
    ys1, xs1 = np.nonzero(np.pad(np.ones((8, 6), bool), ((2, 2), (2, 12))))      # receiver 1: x 2..7
    ys2, xs2 = np.nonzero(np.pad(np.ones((8, 6), bool), ((2, 2), (9, 5))))       # receiver 2: x 9..14
    p1 = (ys1, xs1, np.full((len(ys1), 1), 1.0)); p2 = (ys2, xs2, np.full((len(ys2), 1), 2.0))
    img = D.replay_margin(start, [p1, p2], 2)
    assert img[4, 7, 0] == 2.0 and img[4, 8, 0] == 2.0, 'the later receiver overwrites the earlier one within reach'
    assert img[4, 6, 0] == 1.0, 'beyond margin (L1 3 from its hits) the earlier receiver keeps its texels'
    own = D.replay_margin(start, [(np.concatenate([ys1, ys2]), np.concatenate([xs1, xs2]),
                                   np.concatenate([p1[2], p2[2]]))], 2)
    assert (own[ys1, xs1, 0] == 1.0).all() and (own[ys2, xs2, 0] == 2.0).all(), 'owners mode never overwrites a hit'
    for passes in ([p1, p2], [p2, p1]):
        H, W = start.shape[:2]; ref = start.copy()
        for ys, xs, v in passes:                            # uncropped reference
            ref[ys, xs] = v; m = np.zeros((H, W), bool); m[ys, xs] = True; ref, _ = D.extend_fill(ref, m, 2)
        assert np.allclose(D.replay_margin(start, passes, 2), ref), 'the crop must not change the result'


# ------------------------------------------------------------------------------------------ minification
def test_auto_filter_resolves_by_ratio():
    f = D.choose_filter('auto', [1.0, 2.0, D.AUTO_POINT_MAX, D.AUTO_POINT_MAX + 0.01, 8.0])
    assert f.tolist() == ['point', 'point', 'point', 'footprint', 'footprint']
    assert D.choose_filter('point', [8.0]).tolist() == ['point']


@pytest.mark.parametrize('ratio', [6.0, 8.0])
def test_footprint_area_filters_strong_minification(ratio):
    """a noise master minified `ratio` x: the footprint filter tracks the box mean of the master texels under each
    target texel (what the baker's 16 jittered samples average when the HIGH does not limit them); a bilinear
    point sample aliases"""
    rng = np.random.default_rng(int(ratio)); S = 256
    vals = rng.choice([-1.0, 1.0], (S, S))[..., None]
    chart = np.zeros((S, S), int); usable = np.ones((S, S), bool); status = np.ones((S, S), bool)
    n = int(200 // ratio); o = 20.3                          # target texels per side; master origin (off-grid)
    tt = np.array([[[0, 0], [n, 0], [n, n]], [[0, 0], [n, n], [0, n]]], np.float64)
    tm = tt * ratio + o - D.PIX_OFF                          # master pixel coords (texel (i, j) at (i, j))
    tri, x, y, bary = D.rasterize(tt, n, n)
    cat = dict(x=x, y=y, chart=np.zeros(len(x), int), tri=tri, tri_tt=tt, tri_tm=tm)
    sel = np.arange(len(x))
    fp, h, f = D.footprint_sample(cat, sel, vals, (chart, usable, status), None, np.full(len(x), int(math.ceil(ratio))))
    mxy = np.einsum('ki,kij->kj', bary, tm[tri])
    pt, _, _ = D.sample_master(mxy[:, 0], mxy[:, 1], np.zeros(len(x), int), chart, usable, status, vals)
    cx = (x + D.PIX_OFF[0]) * ratio + o - D.PIX_OFF[0]; cy = (y + D.PIX_OFF[1]) * ratio + o - D.PIX_OFF[1]
    box = np.array([vals[int(np.ceil(b - ratio / 2)):int(np.floor(b + ratio / 2)) + 1,
                         int(np.ceil(a - ratio / 2)):int(np.floor(a + ratio / 2)) + 1, 0].mean() for a, b in zip(cx, cy)])
    e_fp = np.sqrt(((fp[:, 0] - box) ** 2).mean()); e_pt = np.sqrt(((pt[:, 0] - box) ** 2).mean())
    assert f.all() and h.all()
    assert e_fp < 0.12 and e_pt > 3 * e_fp, (e_fp, e_pt)


# ------------------------------------------------------------------------------------------ compare metrics
def test_compare_metrics_on_known_offsets():
    rng = np.random.default_rng(5); H = W = 48
    n = rng.normal(size=(H, W, 3)) * [0, .2, 0] + [0, 0, 1]   # in the rotation plane
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    th = math.radians(3.0); R = np.array([[1, 0, 0], [0, math.cos(th), -math.sin(th)], [0, math.sin(th), math.cos(th)]])
    A = n * .5 + .5; B = (n @ R.T) * .5 + .5
    face = np.full((H, W), -1); face[4:44, 4:24] = 0; face[4:44, 24:44] = 1
    interior = C.Q.erode(face >= 0, 2)
    res, ang = C.normal_metrics(A, B, interior, face, ['a', 'b'])
    assert abs(res['all']['mean'] - 3.0) < 1e-6 and abs(res['face_median_max'] - 3.0) < 1e-6
    assert not res['pass']['face_median'] and not res['pass']['all_mean'] and res['pass']['all_p95']
    th = math.radians(0.5); R = np.array([[1, 0, 0], [0, math.cos(th), -math.sin(th)], [0, math.sin(th), math.cos(th)]])
    res, _ = C.normal_metrics(A, (n @ R.T) * .5 + .5, interior, face, ['a', 'b'])
    assert all(res['pass'].values()) and abs(res['smooth']['mean'] - 0.5) < 1e-6
    ao = np.full((H, W, 1), .7); r = C.ao_metrics(ao, ao + .02, interior, face, ['a', 'b'])
    assert abs(r['mean'] - .02) < 1e-9 and r['pass']['mean'] and not r['pass']['box3']
    op = np.zeros((H, W, 1)); op[:, :24] = 1; op2 = np.roll(op, 1, axis=1)
    r = C.opacity_metrics(op, op2, interior)
    assert r['agree_interior'] == 1.0 and r['agree_all'] < 1.0
    ids = np.floor(np.arange(W) / 6)[None, :].repeat(H, 0) / 100
    e1 = np.stack([ids, np.zeros_like(ids), np.zeros_like(ids)], -1); e2 = e1.copy(); e2[..., 0] = np.roll(ids, 1, 1)
    r = C.emit_metrics(e1, e2, interior)
    assert r['r_agree_id_interior'] == 1.0 and r['r_agree_all'] < 1.0 and r['pass']['r']


def test_margin_rule_check_separates_l1_from_square_fill_and_host_exr_reader(tmp_path):
    H = W = 40
    hits = np.zeros((H, W), bool); hits[10:20, 12:25] = True; hits[30, 5] = True; hits[0:3, 30:36] = True  # page edge
    img = np.where(hits[..., None], 0.7, 0.0) * np.ones((1, 1, 3))
    l1, _ = D.extend_fill(img, hits, 3)
    sq = hits.copy()
    for _ in range(3):                                        # the old 8-neighbour (square) growth
        p = np.pad(sq, 1); sq = sq | np.any([p[1 + dy:1 + dy + H, 1 + dx:1 + dx + W] for dy in (-1, 0, 1)
                                              for dx in (-1, 0, 1)], 0)
    assert C.l1_open(C.written(l1, 'EMIT'), 3)[0], 'an L1 fill is an L1 opening (also cut at the page edge)'
    assert not C.l1_open(sq, 3)[0], 'a square fill is not'
    # host reader: an uncompressed scanline EXR written by hand (FLOAT channels B, G, R), rows bottom-up out
    import struct
    Wd, Hd = 5, 3; data = np.arange(Wd * Hd * 3, dtype=np.float32).reshape(Hd, Wd, 3)   # top-down R, G, B
    def attr(name, typ, val):
        return name.encode() + b'\0' + typ.encode() + b'\0' + struct.pack('<i', len(val)) + val
    ch = b''.join(c.encode() + b'\0' + struct.pack('<i', 2) + b'\0\0\0\0' + struct.pack('<ii', 1, 1) for c in 'BGR') + b'\0'
    box = struct.pack('<iiii', 0, 0, Wd - 1, Hd - 1)
    hdr = (b'\x76\x2f\x31\x01' + struct.pack('<i', 2) + attr('channels', 'chlist', ch) + attr('compression', 'compression', b'\0')
           + attr('dataWindow', 'box2i', box) + attr('displayWindow', 'box2i', box) + attr('lineOrder', 'lineOrder', b'\0')
           + attr('pixelAspectRatio', 'float', struct.pack('<f', 1)) + attr('screenWindowCenter', 'v2f', struct.pack('<ff', 0, 0))
           + attr('screenWindowWidth', 'float', struct.pack('<f', 1)) + b'\0')
    rows = [struct.pack('<ii', y, Wd * 3 * 4) + b''.join(data[y, :, c].tobytes() for c in (2, 1, 0)) for y in range(Hd)]
    start = len(hdr) + 8 * Hd; offs, o = [], start
    for r_ in rows:
        offs.append(o); o += len(r_)
    (tmp_path / 't.exr').write_bytes(hdr + struct.pack(f'<{Hd}Q', *offs) + b''.join(rows))
    got = C.read_exr_host(tmp_path / 't.exr')
    assert got.shape == (Hd, Wd, 3) and np.array_equal(got, data[::-1])


# ============================================================================================ Blender integration
BLENDER = os.environ.get('QA_BLENDER')
GATE = os.environ.get('BLENDER_GATE')
needs_blender = pytest.mark.skipif(not BLENDER or not Path(BLENDER).exists(), reason='set QA_BLENDER to blender.exe')

FIXTURE = r'''
import bpy, bmesh, json, math, sys, importlib.util
import numpy as np
from pathlib import Path
out, here = Path(sys.argv[sys.argv.index('--') + 1]), Path(sys.argv[sys.argv.index('--') + 2])
for o in list(bpy.data.objects): bpy.data.objects.remove(o)
V, F, SM = [], [], []
def v(p): V.append(tuple(float(c) for c in p)); return len(V) - 1
grid = {(i, j): v((i, j, 0.15 * math.sin(0.9 * i))) for i in range(4) for j in range(3)}
for j in range(2):
    for i in range(3):
        F.append([grid[i, j], grid[i + 1, j], grid[i + 1, j + 1], grid[i, j + 1]]); SM.append(True)        # 0..5
zs = lambda x: max(0.0, x - 5) * math.tan(math.radians(20))
strip = {(i, j): v((4 + i, 0.8 * j, zs(4 + i))) for i in range(4) for j in range(2)}
for i in range(3):
    F.append([strip[i, 0], strip[i + 1, 0], strip[i + 1, 1], strip[i, 1]]); SM.append(True)            # 6..8
F.append([v((8.6 + 0.6 * math.cos(a), 0.5 + 0.6 * math.sin(a), 0.1)) for a in np.radians(np.arange(6) * 60)]); SM.append(False)  # 9 ngon
r = [v(p) for p in [(10, 0, 0), (11, 0, .4), (11, 1, .4), (10, 1, 0), (12, 0, 0), (12, 1, 0)]]
F.append([r[0], r[1], r[2], r[3]]); SM.append(False); F.append([r[1], r[4], r[5], r[2]]); SM.append(False)  # 10, 11 flat
F.append([v(p) for p in [(13, 0, 0), (13.5, 0, 0), (13.5, .5, 0), (13, .5, 0)]]); SM.append(True)     # 12 (outside the master)
me = bpy.data.meshes.new('Low'); me.from_pydata(V, [], F); me.polygons.foreach_set('use_smooth', SM); me.update()
low = bpy.data.objects.new('Low', me); bpy.context.scene.collection.objects.link(low)
P = 128.0; DENS = 20.0

def island(f, origin, rot=0.0, mirror=False, scale=1.0):
    pts = np.array([V[i] for i in F[f]]); x = pts[1] - pts[0]; x /= np.linalg.norm(x)
    n = np.cross(pts[1] - pts[0], pts[-1] - pts[0]); n /= np.linalg.norm(n); y = np.cross(n, x)
    q = np.stack([(pts - pts[0]) @ x, (pts - pts[0]) @ y], 1) * DENS * scale
    if mirror: q[:, 0] *= -1
    th = math.radians(rot); q = q @ np.array([[math.cos(th), -math.sin(th)], [math.sin(th), math.cos(th)]]).T
    q -= q.min(0); return (q + origin) / P

A = {0: island(0, (6, 6)), 1: island(1, (36, 6)), 2: island(2, (66, 6)), 6: island(6, (6, 40)), 7: island(7, (36, 40)),
     8: island(8, (66, 40)), 9: island(9, (96, 6)), 10: island(10, (6, 70)), 11: island(11, (36, 70)), 12: island(12, (96, 70))}
A[3], A[4], A[5] = A[0], A[1], A[2]                                   # members stacked on their owners
B = dict(A); B[1] = island(1, (96, 40), rot=90, mirror=True); B[4] = B[1]; B[2] = island(2, (66, 6), scale=1.3); B[5] = B[2]
B[3] = island(3, (66, 95)); B[12] = island(12, (96, 100))
for name, L in (('UV_Final', A), ('UV_B', B)):
    uv = me.uv_layers.new(name=name)
    for p in me.polygons:
        for k, li in enumerate(p.loop_indices):
            uv.data[li].uv = L[p.index][k]
cls = {**{i: 'ROOF_TILE' for i in range(9)}, 9: 'WOOD', 10: 'EAVE_CUTOUT', 11: 'EAVE_CUTOUT', 12: 'WOOD'}
def plan(L, owners, extra=()):
    return {'faces': {f'L:{i}': dict(owner=i in owners, page='P', material=cls[i], uv=L[i].tolist(), family=f'f{i}')
                      for i in list(range(12)) + list(extra)}}
json.dump(plan(A, {0, 1, 2, 6, 7, 8, 9, 10, 11}), open(out / 'plan_A.json', 'w'))
json.dump(plan(B, {0, 1, 2, 3, 6, 7, 8, 9, 10, 11}), open(out / 'plan_B.json', 'w'))
json.dump(plan(B, {0, 1, 2, 3, 6, 7, 8, 9, 10, 11, 12}, extra=[12]), open(out / 'plan_C.json', 'w'))
# HIGH: the 12 faces, subdivided, relief along the normal, two holes, per-tile emission IDs
def make_high(name, amp):
    hm = me.copy(); bm = bmesh.new(); bm.from_mesh(hm)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.index == 12], context='FACES')
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=24, use_grid_fill=True)
    bm.normal_update()
    for vv in bm.verts:
        x, y, _ = vv.co; vv.co = vv.co + vv.normal * (0.01 + amp * math.sin(9 * x) * math.cos(7 * y))
    dead = []
    for f in list(bm.faces):
        c = f.calc_center_median()
        if (c.x - 11.5) ** 2 + (c.y - 0.5) ** 2 < 0.18 ** 2 or (c.x - 10.5) ** 2 + (c.y - 0.5) ** 2 < 0.15 ** 2:   # cutout faces
            dead.append(f)
    bmesh.ops.delete(bm, geom=list(set(dead)), context='FACES')
    bm.to_mesh(hm); bm.free()
    for p in hm.polygons: p.use_smooth = True
    # tiles of 1 m = 20 target texels: G (ramp in the tile) and B (half-tile stripes) must be resolvable at the
    # fixture density; 0.125 m tiles (2.5 texels, B edges every 1.25) failed G/B on sampling noise, not on the method
    TILE = 1.0
    att = hm.attributes.new('tile', 'FLOAT_COLOR', 'FACE'); rng = {}
    for p in hm.polygons:
        c = p.center; tx, ty = math.floor(c.x / TILE), math.floor(c.y / TILE)
        rid = (math.sin(tx * 12.9898 + ty * 78.233) * 43758.5453) % 1.0
        att.data[p.index].color = (0.05 + 0.9 * rid, (c.y / TILE) % 1.0, 1.0 if (c.x / TILE) % 1.0 > .5 else 0.0, 1.0)
    m = bpy.data.materials.new('TileID'); m.use_nodes = True; nt = m.node_tree; nt.nodes.clear()
    a = nt.nodes.new('ShaderNodeAttribute'); a.attribute_name = 'tile'; a.attribute_type = 'GEOMETRY'
    em = nt.nodes.new('ShaderNodeEmission'); o = nt.nodes.new('ShaderNodeOutputMaterial')
    nt.links.new(a.outputs['Color'], em.inputs['Color']); nt.links.new(em.outputs[0], o.inputs[0])
    hm.materials.clear(); hm.materials.append(m)
    return bpy.data.objects.new(name, hm)
hi = make_high('High', 0.02); bpy.data.libraries.write(str(out / 'high.blend'), {hi}, fake_user=True)
hi2 = make_high('High', 0.021); bpy.data.libraries.write(str(out / 'high_changed.blend'), {hi2}, fake_user=True)
bpy.data.objects.remove(hi); bpy.data.objects.remove(hi2)
bpy.ops.wm.save_as_mainfile(filepath=str(out / 'fixture.blend'))
bpy.ops.wm.open_mainfile(filepath=str(out / 'fixture.blend'))
def load(n):
    s = importlib.util.spec_from_file_location(n, here / f'{n}.py'); m = importlib.util.module_from_spec(s); s.loader.exec_module(m); return m
fpm, con = load('uv_fingerprint'), load('bake_contract')
json.dump(con.fingerprint(['Low']), open(out / 'low_contract.json', 'w'))
for n, lay in (('A', 'UV_Final'), ('B', 'UV_B')):
    json.dump(fpm.fingerprint(['Low'], lay), open(out / f'freeze_{n}.json', 'w'))
print('FIXTURE_OK')
'''



# several skill scripts in ONE Blender session (the machine gate makes every launch expensive): each step is
# exec'd like `blender --python script -- args`, SystemExit / exceptions are recorded per step.
RUNNER = r'''
import json, sys, traceback
steps_path = sys.argv[sys.argv.index('--') + 1]
steps = json.load(open(steps_path)); res = []; argv0 = sys.argv[0]
for st in steps:
    print('STEP_BEGIN', st['id'], flush=True); code, err = 0, ''
    try:
        if st.get('pre'):
            exec(st['pre'], {})
        sys.argv = [argv0, '--', *st['args']]
        exec(compile(open(st['script'], encoding='utf-8').read(), st['script'], 'exec'),
             {'__name__': '__main__', '__file__': st['script']})
    except SystemExit as e:
        code = e.code if isinstance(e.code, int) else (0 if e.code is None else 1)
    except BaseException:
        code, err = 1, traceback.format_exc()
    print('STEP_END', st['id'], code, err[-1500:], flush=True)
    res.append(dict(id=st['id'], code=code, err=err[-3000:]))
json.dump(res, open(steps_path + '.result.json', 'w'), indent=1)
'''


def _gate():
    if GATE:
        while subprocess.run(shlex.split(GATE)).returncode != 0:
            pass


def _blender(*args):
    _gate()
    return subprocess.run([BLENDER, '-b', '--factory-startup', *args], capture_output=True, text=True, timeout=3600)


def _session(t, name, blend, steps):
    """run steps [(id, script, [args], pre)] in one background Blender on blend -> ({id: result}, log)"""
    (t / 'runner.py').write_text(RUNNER)
    sp = t / f'{name}.steps.json'
    sp.write_text(json.dumps([dict(id=i, script=str(sc), args=[str(a) for a in ar], pre=pre) for i, sc, ar, pre in steps]))
    r = _blender(str(blend), '--python', str(t / 'runner.py'), '--', str(sp))
    res = Path(str(sp) + '.result.json')
    assert res.exists(), r.stdout[-3000:] + r.stderr[-3000:]
    return {x['id']: x for x in json.loads(res.read_text())}, r.stdout + r.stderr


def _pairs(t):
    both = [dict(id=L, derived=str(t / f'derived_{L}'), direct=str(t / f'direct_{L}'), maps=['NORMAL', 'EMIT', 'AO', 'OPACITY'],
                 pages=['P']) for L in 'AB']
    flip = [dict(id='flip', derived=str(t / 'derived_flip'), direct=str(t / 'direct_B'), maps=['NORMAL'], pages=['P'])]
    return both, flip


@pytest.fixture(scope='module')
def pipeline(tmp_path_factory):
    t = tmp_path_factory.mktemp('master_fixture')
    (t / 'build.py').write_text(FIXTURE)
    r = _blender('--python', str(t / 'build.py'), '--', str(t), str(HERE))
    assert 'FIXTURE_OK' in r.stdout, r.stdout[-3000:] + r.stderr[-3000:]
    owners = {'A': [0, 1, 2, 6, 7, 8, 9, 10, 11], 'B': [0, 1, 2, 3, 6, 7, 8, 9, 10, 11]}
    uvn = {'A': 'UV_Final', 'B': 'UV_B'}
    rec = {}
    for L in 'AB':
        rec[L] = dict(plan=str(t / f'plan_{L}.json'), sources={'L': 'Low'}, highs=[dict(file=str(t / 'high.blend'), objects=['High'])],
                      pages={'P': 128}, maps=['NORMAL', 'EMIT', 'AO', 'OPACITY'], uv_name=uvn[L], extrusion=.05,
                      max_ray_distance=.1, margin=2, samples=16, ao_distance=.15, opacity_classes=['EAVE_CUTOUT'],
                      scope=dict(mode='production', regions=[dict(id='all', faces=[f'L:{i}' for i in owners[L]], highs=['High'])]),
                      freeze=str(t / f'freeze_{L}.json'), input_contract=str(t / 'low_contract.json'), out_dir=str(t / f'direct_{L}'))
        (t / f'direct_{L}.json').write_text(json.dumps(rec[L]))
    unwrap = dict(sources={'L': 'Low'}, input_contract=str(t / 'low_contract.json'),
                  groups=[dict(id='G', faces=[f'L:{i}' for i in range(12)])],
                  reference_plans=[str(t / 'plan_A.json'), str(t / 'plan_B.json')], reference_page_sizes={'P': 128},
                  density=None, factor=2.0, round_to=10, page_size=512, margin=2, out=str(t / 'bake_master'))
    (t / 'unwrap.json').write_text(json.dumps(unwrap))
    res, log = _session(t, 's1', t / 'fixture.blend', [
        ('direct_A', HERE / 'bake_owner_maps.py', [t / 'direct_A.json'], None),
        ('direct_B', HERE / 'bake_owner_maps.py', [t / 'direct_B.json'], None),
        ('unwrap', HERE / 'master_unwrap.py', [t / 'unwrap.json'], None)])
    assert all(v['code'] == 0 for v in res.values()) and 'UNWRAP_PASS' in log, log[-4000:]
    geo = json.loads((t / 'low_contract.json').read_text())['combined'][:12]
    M = t / 'bake_master' / geo / 'master.json'
    r = subprocess.run([sys.executable, str(HERE / 'master_bake.py'), 'recipes', '--master', str(M), '--from',
                        str(t / 'direct_A.json'), str(t / 'direct_B.json'), '--maps', 'NORMAL,EMIT,AO,OPACITY',
                        '--run', 'FX', '--out', str(t / 'master_FX.json')], capture_output=True, text=True)
    assert 'MASTER_RECIPE' in r.stdout, r.stdout + r.stderr
    steps = [('master', HERE / 'master_bake.py', ['bake', t / 'master_FX.json'], None)]
    for L in 'AB':
        (t / f'derive_{L}.json').write_text(json.dumps(dict(rec[L], master=str(M), out_dir=str(t / f'derived_{L}'))))
    (t / 'derive_flip.json').write_text(json.dumps(dict(rec['B'], master=str(M), out_dir=str(t / 'derived_flip'),
                                                        maps=['NORMAL'], derive=dict(debug_flip_sign=True))))
    steps.append(('derive', HERE / 'derive_maps.py', [t / 'derive_A.json', t / 'derive_B.json', t / 'derive_flip.json'], None))
    res, log = _session(t, 's2', t / 'fixture.blend', steps)
    assert res['master']['code'] == 0 and 'MASTER_BAKE FX' in log, log[-4000:]
    assert res['derive']['code'] == 0 and log.count('DERIVE_REPORT') == 3, log[-4000:]
    both, flip = _pairs(t)
    C.Q.BLENDER = BLENDER
    os.environ.setdefault('QA_CACHE', str(t / 'qa_cache'))
    _gate()
    C.Q.prefetch_exr([Path(p[k]) / f'{m}_P.exr' for p in both + flip for k in ('derived', 'direct') for m in p['maps']])
    return dict(t=t, M=M, rec=rec, master_log=log)


def _compare(t, name, pairs):
    code = C.compare(dict(pairs=pairs, erode=2, out=str(t / f'{name}.json')))
    return code, json.loads((t / f'{name}.json').read_text())


@needs_blender
def test_fixture_derive_matches_direct_bakes_on_both_layouts(pipeline):
    t = pipeline['t']; man = json.loads(pipeline['M'].read_text())
    run = man['runs']['FX']
    assert run['layout_check']['M0']['covered_outside_layout'] == 0, 'baker and master raster disagree'
    assert not run['fails']
    assert 'L:12' not in man['faces'], 'faces outside the master stay UV-skipped'
    for L in 'AB':
        rep = json.loads((t / f'derived_{L}' / 'derive_report.json').read_text())
        members = {'A': ['L:3', 'L:4', 'L:5'], 'B': ['L:4', 'L:5']}[L]
        assert not set(members) & set(rep['faces']), 'members must never be derive targets'
        assert rep['summary']['missing_texels'] == 0
    code, res = _compare(t, 'compare', _pairs(t)[0])
    summary = {k: {pg: {m: v[m].get('pass') for m in ('NORMAL', 'EMIT', 'AO', 'OPACITY')} for pg, v in r['pages'].items()}
               for k, r in res['pairs'].items()}
    assert code == 0, json.dumps(summary, indent=1) + json.dumps(res, indent=1)[:6000]


@needs_blender
def test_fixture_wrong_bitangent_sign_fails(pipeline):
    t = pipeline['t']
    code, res = _compare(t, 'compare_flip', _pairs(t)[1])
    n = res['pairs']['flip']['pages']['P']['NORMAL']
    assert code == 3 and not n['pass']['face_median'], n


@needs_blender
def test_fixture_guards_refuse(pipeline):
    t = pipeline['t']; M = pipeline['M']; cases = {}
    base = dict(pipeline['rec']['B'], master=str(M))
    c = dict(base, highs=[dict(file=str(t / 'high_changed.blend'), objects=['High'])])
    cases['changed_high'] = (c, 'changed since run', None)
    c = dict(base, plan=str(t / 'plan_C.json'), uv_name='UV_C', derive=dict(uv_from_plan=True),
             scope=dict(mode='pilot', regions=[dict(id='all', faces=[f'L:{i}' for i in (0, 1, 2, 3, 6, 7, 8, 9, 10, 11, 12)], highs=['High'])]))
    c.pop('freeze'); cases['no_master_data'] = (c, 'not in the master layout', None)
    cases['freeze_mismatch'] = (dict(base, freeze=str(t / 'freeze_A.json')), 'differs from the freeze', None)
    cases['moved_vertex'] = (base, 'input_contract', "import bpy; bpy.data.objects['Low'].data.vertices[0].co.z += 0.01")
    steps = []
    for name, (c, _, pre) in cases.items():                   # order matters: the moved vertex stays moved
        c = dict(c, out_dir=str(t / f'refused_{name}')); (t / f'refuse_{name}.json').write_text(json.dumps(c))
        steps.append((name, HERE / 'derive_maps.py', [t / f'refuse_{name}.json'], pre))
    res, log = _session(t, 's3', t / 'fixture.blend', steps)
    for name, (_, expect, _) in cases.items():
        seg = log.split(f'STEP_BEGIN {name}')[1].split('STEP_BEGIN')[0]
        assert res[name]['code'] != 0 and expect in seg + res[name]['err'], (name, seg[-2000:], res[name])
        assert not (t / f'refused_{name}' / 'derive_report.json').exists(), name
