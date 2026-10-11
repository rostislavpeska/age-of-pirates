"""Measure the board / plank direction a texture actually shows on a mesh and judge it (host Python: numpy, scipy, PIL).

Owner 2026-10-11, after a Discovery house deck and porch steps came out with boards running in different directions on
neighbouring treads: "the planky problem with planks of different direction persists. This needs harness hardening!".
check_material_direction.py only compares directions it is GIVEN; this front end MEASURES them:

  1. every audited triangle's UV footprint on the texture -> structure tensor of the luminance (seams and grain): the
     strongest gradients run ACROSS the boards, so the board direction in UV is perpendicular to the dominant gradient;
     a footprint whose tensor is not anisotropic enough (coherence < --min-coherence) is UNASSESSED, never a pass;
  2. that UV direction -> 3D through the triangle's UV Jacobian (T = dP/du, B = dP/dv), so rotated or mirrored islands are
     judged in the world;
  3. triangles are grouped into planar regions (edge-connected, normals within 5 deg, same plane);
  rules: COHERENCE - every triangle within --coherence-deg of its region's median direction; LONG AXIS - a horizontal
  region (|n.z| > .7: deck, tread, landing) runs its boards along its own long plan axis (principal axis of its
  vertices) unless the region is square-ish (axis ratio < 1.3, reported only); a vertical region with --vertical
  horizontal expects level boards.
Writes the observations in check_material_direction.py's format (face, expected, observed) plus the coherence findings.

    python plank_direction_audit.py MESH.npz TEXTURE.png --out REPORT.json [--faces FACES.npy] [--uv-flip-v]
        [--coherence-deg 30] [--long-axis-deg 25] [--min-coherence .25] [--vertical horizontal|skip]
MESH.npz: pos (n, 3) world, z up; uv (n, 2) with v up (--uv-flip-v when v runs down the image); tris (m, 3);
optional FACES.npy: bool (m,) = the triangles to audit. Exit 0 PASS, 1 FAIL, 2 INCOMPLETE.
"""
import argparse, json, math, sys
from pathlib import Path
import numpy as np
from PIL import Image
from scipy import ndimage as ndi


def structure_tensor(L):
    gy, gx = np.gradient(ndi.gaussian_filter(L, .8))
    return gx * gx, gy * gy, gx * gy


def footprint(uv_px, H, W):
    xs, ys = uv_px[:, 0], uv_px[:, 1]
    x0, x1 = max(int(np.floor(xs.min())), 0), min(int(np.ceil(xs.max())), W - 1)
    y0, y1 = max(int(np.floor(ys.min())), 0), min(int(np.ceil(ys.max())), H - 1)
    if x1 <= x0 or y1 <= y0:
        return None
    yy, xx = np.mgrid[y0:y1 + 1, x0:x1 + 1] + .5
    den = (ys[1] - ys[2]) * (xs[0] - xs[2]) + (xs[2] - xs[1]) * (ys[0] - ys[2])
    if abs(den) < 1e-9:
        return None
    l1 = ((ys[1] - ys[2]) * (xx - xs[2]) + (xs[2] - xs[1]) * (yy - ys[2])) / den
    l2 = ((ys[2] - ys[0]) * (xx - xs[2]) + (xs[0] - xs[2]) * (yy - ys[2])) / den
    ins = (l1 >= .05) & (l2 >= .05) & (1 - l1 - l2 >= .05)                  # keep off the triangle edges (island borders)
    return (yy[ins] - .5).astype(int), (xx[ins] - .5).astype(int)


def regions(P, T, N, ang=5.):
    """edge-connected, near-coplanar triangle groups"""
    m = len(T); parent = list(range(m))
    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]; i = parent[i]
        return i
    edges = {}
    key = lambda a, b: (min(a, b), max(a, b))
    Pq = np.round(P, 4); vid = {}; canon = np.array([vid.setdefault(tuple(p), len(vid)) for p in Pq])   # weld by position
    for t, tri in enumerate(T):
        c = canon[tri]
        for a_, b_ in ((c[0], c[1]), (c[1], c[2]), (c[2], c[0])):
            edges.setdefault(key(a_, b_), []).append(t)
    cosang = math.cos(math.radians(ang))
    for ts in edges.values():
        for t2 in ts[1:]:
            t1 = ts[0]
            if N[t1] @ N[t2] > cosang and abs((P[T[t2][0]] - P[T[t1][0]]) @ N[t1]) < .01:
                parent[find(t2)] = find(t1)
    return np.array([find(i) for i in range(m)])


def audit(P, UV, T, img, faces=None, coherence_deg=30., long_deg=25., min_coh=.25, vertical='horizontal'):
    H, W = img.shape[:2]; L = img[..., :3].astype(np.float32) @ np.array([.299, .587, .114], np.float32) if img.ndim == 3 else img.astype(np.float32)
    Jxx, Jyy, Jxy = structure_tensor(L)
    faces = np.ones(len(T), bool) if faces is None else faces
    e1 = P[T[:, 1]] - P[T[:, 0]]; e2 = P[T[:, 2]] - P[T[:, 0]]; N = np.cross(e1, e2)
    N /= np.linalg.norm(N, axis=1, keepdims=True) + 1e-12
    reg = regions(P, T, N)
    obs, D3, ok = [], np.zeros((len(T), 3)), np.zeros(len(T), bool)
    unassessed = []
    for t in np.nonzero(faces)[0]:
        uvp = np.c_[UV[T[t], 0] * W, (1 - UV[T[t], 1]) * H]
        fp = footprint(uvp, H, W)
        if fp is None or len(fp[0]) < 24:
            unassessed.append(dict(face=int(t), reason='footprint too small')); continue
        jxx, jyy, jxy = Jxx[fp].mean(), Jyy[fp].mean(), Jxy[fp].mean()
        tr = jxx + jyy; det = jxx * jyy - jxy * jxy; disc = math.sqrt(max(tr * tr / 4 - det, 0))
        l1, l2 = tr / 2 + disc, tr / 2 - disc; coh = (l1 - l2) / (l1 + l2 + 1e-12)
        if coh < min_coh:
            unassessed.append(dict(face=int(t), reason=f'texture not directional (coherence {coh:.2f})')); continue
        g = np.array([jxy, l1 - jxx]) if abs(jxy) > 1e-12 else (np.array([1., 0.]) if jxx >= jyy else np.array([0., 1.]))
        g /= np.linalg.norm(g) + 1e-12                                       # dominant gradient (image x right, y down)
        b_img = np.array([-g[1], g[0]])                                      # boards run across it
        b_uv = np.array([b_img[0], -b_img[1]]) / np.array([W, H])            # image -> UV (v up), per unit
        d1, d2 = UV[T[t], :][1] - UV[T[t], :][0], UV[T[t], :][2] - UV[T[t], :][0]
        det_uv = d1[0] * d2[1] - d2[0] * d1[1]
        if abs(det_uv) < 1e-14:
            unassessed.append(dict(face=int(t), reason='degenerate UV')); continue
        Tg = (e1[t] * d2[1] - e2[t] * d1[1]) / det_uv; Bg = (e2[t] * d1[0] - e1[t] * d2[0]) / det_uv
        d = Tg * b_uv[0] + Bg * b_uv[1]; d /= np.linalg.norm(d) + 1e-12
        D3[t] = d; ok[t] = True
    problems = []
    for r in np.unique(reg[faces & ok]):
        ts = np.nonzero((reg == r) & ok)[0]
        if not len(ts):
            continue
        n = N[ts[0]]; ds = D3[ts]
        # axial median: align signs to the first, then the mean direction
        ds = ds * np.sign(ds @ ds[0])[:, None]; med = ds.mean(0); med /= np.linalg.norm(med) + 1e-12
        for t in ts:
            a = math.degrees(math.acos(min(1, abs(D3[t] @ med))))
            if a > coherence_deg:
                problems.append(dict(face=int(t), region=int(r), error='coherence', angle=round(a, 1)))
        vs = P[np.unique(T[reg == r])]
        expected = None
        if abs(n[2]) > .7:                                                   # floor: along the region's long plan axis
            xy = vs[:, :2] - vs[:, :2].mean(0); w_, v_ = np.linalg.eigh(xy.T @ xy)
            if w_[1] > 1.3 ** 2 * max(w_[0], 1e-9):
                expected = np.r_[v_[:, 1], 0.]; role = 'floor_long_axis'
        elif vertical == 'horizontal':
            h = np.cross([0, 0, 1.], n); h /= np.linalg.norm(h) + 1e-12; expected = h; role = 'wall_level'
        if expected is not None:
            for t in ts:
                obs.append(dict(face=f'tri{int(t)}', expected=expected.round(4).tolist(), observed=D3[t].round(4).tolist(), role=role, region=int(r)))
                a = math.degrees(math.acos(min(1, abs(D3[t] @ expected))))
                if a > long_deg:
                    problems.append(dict(face=int(t), region=int(r), error=role, angle=round(a, 1)))
    status = 'FAIL' if problems else ('INCOMPLETE' if not ok[faces].any() else 'PASS')
    return dict(status=status, audited=int(faces.sum()), measured=int(ok[faces].sum()), unassessed=len(unassessed),
                regions=int(len(np.unique(reg[faces & ok]))), problems=problems, observations=obs,
                unassessed_detail=unassessed[:40], rules=dict(coherence_deg=coherence_deg, long_axis_deg=long_deg, min_coherence=min_coh))


if __name__ == '__main__':
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0]); ap.add_argument('mesh'); ap.add_argument('texture')
    ap.add_argument('--out'); ap.add_argument('--faces'); ap.add_argument('--uv-flip-v', action='store_true')
    ap.add_argument('--coherence-deg', type=float, default=30.); ap.add_argument('--long-axis-deg', type=float, default=25.)
    ap.add_argument('--min-coherence', type=float, default=.25); ap.add_argument('--vertical', default='horizontal', choices=['horizontal', 'skip'])
    a = ap.parse_args()
    z = np.load(a.mesh); UV = z['uv'].astype(float)
    if a.uv_flip_v:
        UV = np.c_[UV[:, 0], 1 - UV[:, 1]]
    img = np.asarray(Image.open(a.texture).convert('RGB'))
    rep = audit(z['pos'].astype(float), UV, z['tris'], img, np.load(a.faces) if a.faces else None, a.coherence_deg, a.long_axis_deg,
                a.min_coherence, a.vertical)
    if a.out:
        Path(a.out).write_text(json.dumps(rep, indent=1))
    print('PLANK_AUDIT', rep['status'], json.dumps({k: rep[k] for k in ('audited', 'measured', 'unassessed', 'regions')}),
          'problems', len(rep['problems']), [p for p in rep['problems'][:6]])
    sys.exit({'PASS': 0, 'FAIL': 1}.get(rep['status'], 2))
