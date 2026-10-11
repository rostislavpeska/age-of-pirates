"""One folded parameterisation for an extruded alpha slab (thatch, straw or reed eaves, fringed awnings), plus the seam QA.

A slab is one 2D profile (top, back, underside, optional rounded nose) extruded along the eave, with two end caps; its
PROFILE_MAP comes from slab_profile_map.py (background Blender). Every face reads ONE coordinate pair:
- v = the slope coordinate s of the nearest outline point. Top and underside both read v = s; a rounded nose takes its
  inner vertices by arc length between its end vertices, so v is continuous and monotone round the whole outline.
- us = u + depth below the top x (1 - 2u/W). The end caps carry the top's material straight down over the end, and the
  shift reaches the underside, back and nose so they meet the caps on the same columns.
Shared edges therefore sample the same painting from both sides, and a cut defined as one function of (us, v) runs
through every face of the slab (no leftover rim).

    python slab_fold.py qa --profile PROFILE_MAP.json --basecolor PAGE_BaseColor.png [--out SEAM_QA.json]
exits 1 when the seam QA fails.
"""
import argparse, json, sys
import numpy as np


class Slab:
    def __init__(self, pm):
        self.pm = pm; self.N = pm['size']
        self.OL = np.array(pm['outline_st'], float); self.CUM = np.array(pm['outline_cum'], float); self.PER = self.CUM[-1]
        self.THICK = float(-self.OL[:, 1].min()); self.W = float(pm['u_len']); self.u0 = float(pm['u0'])
        self.c0, self.U, self.Vv, self.nt = (np.array(pm[k], float) for k in ('c0', 'U', 'Vv', 'nt'))
        self.F = {f['face']: f for f in pm['faces']}
        self.seg_kind = [self._segment_kind(i) for i in range(len(self.OL))]
        self.VK = self._vertex_v()

    def _segment_kind(self, i):
        """kind of the side face holding outline segment i (matched on the faces' slab (s, t) points)"""
        A_, B_ = self.OL[i], self.OL[(i + 1) % len(self.OL)]
        for f in self.pm['faces']:
            if f['kind'] == 'end':
                continue
            st = np.array([[q[1], q[2]] for q in f['slab']])
            if np.linalg.norm(st - A_, axis=1).min() < 1e-4 and np.linalg.norm(st - B_, axis=1).min() < 1e-4:
                return f['kind']
        return 'unknown'

    def _vertex_v(self):
        VK = self.OL[:, 0].copy(); n = len(self.OL)
        inner = [k for k in range(n) if self.seg_kind[k] == 'nose' and self.seg_kind[k - 1] == 'nose']
        if inner:                                                                         # one rounded run: arc-length fill
            first = min(k for k in range(n) if self.seg_kind[k] == 'nose')
            last = (max(k for k in range(n) if self.seg_kind[k] == 'nose') + 1) % n
            c_first = self.CUM[first]; c_last = self.CUM[last] if last != 0 else self.PER
            for k in inner:
                w = (self.CUM[k] - c_first) / max(c_last - c_first, 1e-9); VK[k] = VK[first] + w * (VK[last] - VK[first])
        return VK

    def nearest_outline(self, st):
        """(p, distance, v) of the nearest point on the closed outline for points st (n, 2)"""
        OL, CUM, VK = self.OL, self.CUM, self.VK
        bp = np.zeros(len(st)); bd = np.full(len(st), 9e9); bv = np.zeros(len(st))
        for i in range(len(OL)):
            j = (i + 1) % len(OL); A_, B_ = OL[i], OL[j]; ab = B_ - A_; L2 = max(ab @ ab, 1e-12)
            t = np.clip(((st - A_) @ ab) / L2, 0, 1); d = np.linalg.norm(st - (A_ + t[:, None] * ab), axis=1)
            up = d < bd; bd[up] = d[up]; bp[up] = CUM[i] + t[up] * np.sqrt(L2); bv[up] = VK[i] + t[up] * (VK[j] - VK[i])
        return bp, bd, bv

    def coords_3d(self, X3):
        """3D points (n, 3) -> dict(u, s, t, us, v)"""
        d = X3 - self.c0; u = d @ self.U - self.u0; s = d @ self.Vv; t = d @ self.nt
        _, _, v = self.nearest_outline(np.c_[s, t])
        us = u + np.clip(-t, 0, self.THICK) * (1 - 2 * np.clip(u, 0, self.W) / self.W)
        return {'u': u, 's': s, 't': t, 'us': us, 'v': v}

    def texels(self, f, grow=1):
        from PIL import Image, ImageDraw, ImageFilter
        msk = Image.new('L', (self.N, self.N), 0); ImageDraw.Draw(msk).polygon([tuple(q) for q in f['uv_px']], fill=255)
        if grow > 1:
            msk = msk.filter(ImageFilter.MaxFilter(grow))
        return np.nonzero(np.asarray(msk) > 0)

    def face_coords(self, f, yy, xx):
        """page texels (row, col) of face f -> 3D and the folded coordinates"""
        X3 = np.c_[xx + .5, yy + .5, np.ones(len(xx))] @ np.array(f['px_to_3d']); c = self.coords_3d(X3); c['X3'] = X3
        return c

    def px_of(self, fid, P3):
        T = np.array(self.F[fid]['px_to_3d']); sol, *_ = np.linalg.lstsq(T[:2].T, (P3 - T[2]).T, rcond=None); return sol.T

    def inward(self, fid, A3, B3):
        f = self.F[fid]; n = np.array(f['normal']); e = (B3 - A3) / np.linalg.norm(B3 - A3); w = np.cross(n, e)
        C3 = np.array([[q[0] + self.u0, q[1], q[2]] for q in f['slab']]).mean(0) @ np.array([self.U, self.Vv, self.nt]) + self.c0
        return w if (C3 - (A3 + B3) / 2) @ w > 0 else -w


def bilinear(img, x, y):
    x = np.clip(x - .5, 0, img.shape[1] - 1.001); y = np.clip(y - .5, 0, img.shape[0] - 1.001); x0 = x.astype(int); y0 = y.astype(int)
    fx = (x - x0)[:, None]; fy = (y - y0)[:, None]
    return (img[y0, x0] * (1 - fx) * (1 - fy) + img[y0, x0 + 1] * fx * (1 - fy) + img[y0 + 1, x0] * (1 - fx) * fy + img[y0 + 1, x0 + 1] * fx * fy)


def seam_qa(slab, bc, tag='', D=.006, worst_max=2.0, mean_max=1.3):
    """Colour step across every shared edge against the same-distance step inside the two faces.
    bc: float RGBA page (N, N, 4) in 0..1. Samples D and 3D metres inside each face (bilinear) where all four are opaque.
    A matching seam looks like any other 2D step in the material (ratio ~1 or below); an unrelated frame does not."""
    rows = []
    for e in slab.pm['shared_edges']:
        A3, B3 = np.array(e['a']), np.array(e['b']); ts = np.linspace(.05, .95, 24); P3 = A3 + ts[:, None] * (B3 - A3)
        fa, fb = e['faces']; wa, wb = slab.inward(fa, A3, B3), slab.inward(fb, A3, B3)
        ca = bilinear(bc, *slab.px_of(fa, P3 + D * wa).T); cb = bilinear(bc, *slab.px_of(fb, P3 + D * wb).T)
        ca2 = bilinear(bc, *slab.px_of(fa, P3 + 3 * D * wa).T); cb2 = bilinear(bc, *slab.px_of(fb, P3 + 3 * D * wb).T)
        ok = (ca[:, 3] > .9) & (cb[:, 3] > .9) & (ca2[:, 3] > .9) & (cb2[:, 3] > .9)
        kinds = [slab.F[fa]['kind'], slab.F[fb]['kind']]
        if ok.sum() < 6:
            rows.append({'faces': e['faces'], 'kinds': kinds, 'judged': False}); continue
        across = float(np.abs(ca[ok, :3] - cb[ok, :3]).mean())
        within = float((np.abs(ca[ok, :3] - ca2[ok, :3]).mean() + np.abs(cb[ok, :3] - cb2[ok, :3]).mean()) / 2)
        rows.append({'faces': e['faces'], 'kinds': kinds, 'judged': True, 'samples': int(ok.sum()), 'across': round(across, 4),
                     'within': round(within, 4), 'ratio': round(across / max(within, .01), 2)})
    J = [r for r in rows if r['judged']]
    worst = max((r['ratio'] for r in J), default=None); mean_r = float(np.mean([r['ratio'] for r in J])) if J else None
    ok = bool(J) and worst <= worst_max and mean_r <= mean_max
    return {'tag': tag, 'judged': len(J), 'mean_ratio': None if mean_r is None else round(mean_r, 2), 'worst_ratio': worst, 'pass': ok,
            'rule': f'across-edge colour step <= {worst_max}x (each edge) and <= {mean_max}x (mean) the same-distance step inside the faces',
            'edges': rows}


if __name__ == '__main__':
    ap = argparse.ArgumentParser(); ap.add_argument('mode', choices=('qa',)); ap.add_argument('--profile', required=True)
    ap.add_argument('--basecolor', required=True); ap.add_argument('--out')
    a = ap.parse_args()
    from PIL import Image
    S = Slab(json.load(open(a.profile))); bc = np.asarray(Image.open(a.basecolor).convert('RGBA')).astype(np.float32) / 255
    R = seam_qa(S, bc, a.basecolor)
    if a.out:
        json.dump(R, open(a.out, 'w'), indent=1)
    print('SEAM_QA', 'judged', R['judged'], 'mean ratio', R['mean_ratio'], 'worst', R['worst_ratio'], 'PASS' if R['pass'] else 'FAIL',
          sorted(((r['ratio'], '-'.join(r['kinds'])) for r in R['edges'] if r['judged']), reverse=True)[:4])
    sys.exit(0 if R['pass'] else 1)
