"""Corner / texture-seam monitor and tone editor (host Python). Owner 2026-10-11: "add texture corners separately and corner
texture seams monitoring and edit".

    python seam_monitor.py monitor --inventory SEAMS_INV.json --pages 0=P0_BaseColor.png,5=P5_BaseColor.png --out DIR [--top 40]
        [--classes 0=ROLE_P0.npy,5=ROLE_P5.npy]
    python seam_monitor.py edit    --inventory SEAMS_INV.json --pages ... --out-pages OUTDIR [--band 6] [--report DIR]

MONITOR: for every seam edge (seam_inventory.py) sample both sides 1 and 3 texels inside their own face (bilinear, opaque
texels only, endpoints skipped), along the edge. across = colour step over the seam; within = the same 2-texel step inside
the faces; ratio = across / within. tone = the step of the along-edge MEANS (a low-frequency shift). Classes:
- ok: ratio <= 1.5, or the step is below .03 (invisible);
- tone: mostly a tone shift (tone >= .5 x across). The edit can blend it away;
- pattern: the two sides show unrelated structure. This needs a layout fix (unrolled corner sheet, folded slab, shared
  frame); no blend hides it;
- boundary: the two faces carry different paint subtypes or materials (ridge against tile field). Intended: not
  scored, never edited.
Score = metres x (ratio - 1), x1.5 on near-coplanar seams (dihedral < 30 deg, where a step reads as a crack). Writes
SEAM_MONITOR.json (every seam) and SEAM_STRIPS.png: the worst seams unfolded, side A above side B, as a viewer crosses
the corner.
EDIT: tone seams only (optionally only some paint subtypes), on texels owned by one face - or by one UV family whose
members all repeat the same texture seam (edited once for all; a texel covered by more faces than that is never touched).
Each side is pulled towards the pair's along-edge mean in a band (default 6 texels, linear falloff, plus 2 gutter
texels), smoothed along the edge, |delta| <= .15. Then re-monitors: the edited seams must improve and no texel outside the
bands may change.
"""
import argparse, json, sys
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFont


def load_pages(spec):
    out = {}
    for k, v in (x.split('=', 1) for x in spec.split(',')):
        out[int(k)] = np.asarray(Image.open(v).convert('RGBA')).astype(np.float32) / 255
    return out


def bilinear(img, x, y):
    x = np.clip(x - .5, 0, img.shape[1] - 1.001); y = np.clip(y - .5, 0, img.shape[0] - 1.001); x0 = x.astype(int); y0 = y.astype(int)
    fx = (x - x0)[:, None]; fy = (y - y0)[:, None]
    return (img[y0, x0] * (1 - fx) * (1 - fy) + img[y0, x0 + 1] * fx * (1 - fy) + img[y0 + 1, x0] * (1 - fx) * fy + img[y0 + 1, x0 + 1] * fx * fy)


def inside(poly, x, y):
    """even-odd point in polygon (vectorised over points)"""
    P = np.asarray(poly, float); res = np.zeros(len(x), bool); n = len(P)
    for i in range(n):
        x1, y1 = P[i]; x2, y2 = P[(i + 1) % n]
        c = ((y1 > y) != (y2 > y)) & (x < (x2 - x1) * (y - y1) / ((y2 - y1) + 1e-12) + x1)
        res ^= c
    return res


def load_classes(spec, scale):
    """per-page texel class maps (.npy float or int, channel 0; class = rint(value x scale)), e.g. a baked ROLE map"""
    out = {}
    for k, v in (x.split('=', 1) for x in spec.split(',')):
        A = np.load(v); A = A[..., 0] if A.ndim == 3 else A; out[int(k)] = np.rint(A * scale).astype(np.int32)
    return out


class Seams:
    def __init__(self, inv, classes=None):
        self.inv = inv; self.size = {int(k): v for k, v in inv['pages'].items()}; self.classes = classes or {}
        self.poly = {(f['obj'], f['face']): f['px'] for f in inv['faces']}

    def frame(self, s, side):
        """edge endpoints (px), unit along, unit inward normal (px) for one side of a seam"""
        P = np.array(s['uv_a' if side == 0 else 'uv_b'], float); cen = np.array(s['cen_a' if side == 0 else 'cen_b'], float)
        e = P[1] - P[0]; L = float(np.linalg.norm(e)); e = e / max(L, 1e-9); n = np.array([-e[1], e[0]])
        if (cen - (P[0] + P[1]) / 2) @ n < 0:
            n = -n
        return P, e, n, L

    def sample(self, pages, s, ts, depth):
        """colours (k, 4) per side at `depth` texels inside each face, plus 'inside its own face' flags"""
        out = []
        for side in (0, 1):
            P, e, n, L = self.frame(s, side); pts = P[0] + ts[:, None] * (P[1] - P[0]) + depth * n
            pg = s['pages'][side]; c = bilinear(pages[pg], pts[:, 0], pts[:, 1])
            ok = inside(self.poly[(s['obj'], s['faces'][side])], pts[:, 0], pts[:, 1])
            out.append((c, ok))
        return out

    def measure(self, pages, s):
        L = max(self.frame(s, 0)[3], self.frame(s, 1)[3]); n = int(np.clip(L / 1.5, 4, 48)); ts = np.linspace(.08, .92, n)
        (a1, ia1), (b1, ib1) = self.sample(pages, s, ts, 1.)
        (a3, ia3), (b3, ib3) = self.sample(pages, s, ts, 3.)
        v = ia1 & ib1 & (a1[:, 3] >= .5) & (b1[:, 3] >= .5)
        if v.sum() < 3:
            return {'judged': False}
        across = float(np.abs(a1[v, :3] - b1[v, :3]).mean())
        wa = v & ia3 & (a3[:, 3] >= .5); wb = v & ib3 & (b3[:, 3] >= .5); parts = []
        if wa.sum() >= 2:
            parts.append(np.abs(a1[wa, :3] - a3[wa, :3]).mean())
        if wb.sum() >= 2:
            parts.append(np.abs(b1[wb, :3] - b3[wb, :3]).mean())
        within = float(np.mean(parts)) if parts else None
        tone = float(np.abs(a1[v, :3].mean(0) - b1[v, :3].mean(0)).mean())
        ratio = across / max(within if within is not None else across, .01)
        boundary = s.get('subtypes', [0, 0])[0] != s.get('subtypes', [0, 0])[1] or s.get('materials', [0, 0])[0] != s.get('materials', [0, 0])[1]
        if not boundary and self.classes:                                                   # texel classes (ROLE) differ across the edge
            cl = []
            for side in (0, 1):
                C = self.classes.get(s['pages'][side])
                if C is None:
                    break
                P, e, n, L_ = self.frame(s, side); pts = P[0] + ts[v][:, None] * (P[1] - P[0]) + 1. * n
                ix = np.clip(pts[:, 0].astype(int), 0, C.shape[1] - 1); iy = np.clip(pts[:, 1].astype(int), 0, C.shape[0] - 1)
                vals, cnt = np.unique(C[iy, ix], return_counts=True); cl.append(int(vals[cnt.argmax()]))
            boundary = len(cl) == 2 and cl[0] != cl[1]
        cls = 'ok' if (ratio <= 1.5 or across < .03) else 'boundary' if boundary else ('tone' if tone >= .5 * across else 'pattern')
        w = 0. if cls == 'boundary' else 1.5 if s['dihedral_deg'] < 30 else 1.
        return {'judged': True, 'samples': int(v.sum()), 'across': round(across, 4), 'within': None if within is None else round(within, 4),
                'tone': round(tone, 4), 'ratio': round(ratio, 2), 'class': cls, 'score': round(s['len_m'] * max(ratio - 1, 0) * w, 4)}

    def monitor(self, pages):
        rows = []
        for i, s in enumerate(self.inv['seams']):
            m = self.measure(pages, s); m.update({'i': i, 'obj': s['obj'], 'faces': s['faces'], 'pages': s['pages'], 'len_m': round(s['len_m'], 3),
                                                  'dihedral_deg': round(s['dihedral_deg'], 1)}); rows.append(m)
        J = [r for r in rows if r['judged']]; L = sum(r['len_m'] for r in J)
        summ = {'seams': len(rows), 'judged': len(J), 'metres_judged': round(L, 1)}
        for c in ('ok', 'tone', 'pattern', 'boundary'):
            summ[c] = sum(1 for r in J if r['class'] == c); summ[c + '_m'] = round(sum(r['len_m'] for r in J if r['class'] == c), 1)
        summ['score'] = round(sum(r['score'] for r in J), 2)
        summ['len_weighted_ratio'] = round(sum(r['ratio'] * r['len_m'] for r in J) / max(L, 1e-9), 3)
        return summ, rows

    def strips(self, pages, rows, top, path, half=8, W=120):
        worst = sorted([r for r in rows if r['judged'] and r['class'] in ('tone', 'pattern')], key=lambda r: -r['score'])[:top]
        if not worst:
            return 0
        try:
            F = ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf', 13)
        except OSError:
            F = ImageFont.load_default()
        tiles = []
        for r in worst:
            s = self.inv['seams'][r['i']]; ts = np.linspace(.02, .98, W); img = []
            for side, depths in ((0, range(half, 0, -1)), (1, range(1, half + 1))):
                for d in depths:
                    P, e, n, L = self.frame(s, side); pts = P[0] + ts[:, None] * (P[1] - P[0]) + (d - .5) * n
                    c = bilinear(pages[s['pages'][side]], pts[:, 0], pts[:, 1]); img.append(c[:, :3] * c[:, 3:] + .5 * (1 - c[:, 3:]))
            im = Image.fromarray((np.clip(np.array(img), 0, 1) * 255).astype(np.uint8)).resize((W * 3, 2 * half * 3), Image.NEAREST)
            tile = Image.new('RGB', (W * 3 + 330, 2 * half * 3 + 6), (24, 24, 24)); tile.paste(im, (0, 3))
            ImageDraw.Draw(tile).text((W * 3 + 8, 6), f"{r['obj'][-34:]}  f{r['faces']}\n{r['class']}  ratio {r['ratio']}  {r['len_m']} m  {r['dihedral_deg']} deg",
                                      fill=(230, 230, 230), font=F)
            tiles.append(tile)
        out = Image.new('RGB', (tiles[0].width, sum(t.height for t in tiles)), (0, 0, 0)); y = 0
        for t in tiles:
            out.paste(t, (0, y)); y += t.height
        out.save(path); return len(tiles)

    def coverage(self):
        """per page: how many faces cover each texel (fan triangles; a texel with count > 1 is shared)"""
        cov = {p: np.zeros((N, N), np.int16) for p, N in self.size.items()}
        for f in self.inv['faces']:
            P = np.array(f['px'], float); C = cov[f['page']]; N = C.shape[0]
            x0, y0 = np.floor(P.min(0)).astype(int); x1, y1 = np.ceil(P.max(0)).astype(int)
            x0, y0 = max(x0, 0), max(y0, 0); x1, y1 = min(x1, N), min(y1, N)
            if x1 <= x0 or y1 <= y0:
                continue
            yy, xx = np.mgrid[y0:y1, x0:x1]; px = xx.ravel() + .5; py = yy.ravel() + .5
            hit = inside(P, px, py); C[yy.ravel()[hit], xx.ravel()[hit]] += 1
        return cov

    def edit(self, pages, rows, band=6., gutter=2., max_delta=.15, subtypes=None, exclude=()):
        """tone seams only. A UV family repeats one texture seam on every member: identical (pages, uv_a, uv_b) seams form a
        group, edited once, and their texels may be covered by as many faces as the group has instances (never more)."""
        cov = self.coverage(); acc = {p: np.zeros(im.shape[:2] + (3,), np.float32) for p, im in pages.items()}
        wsum = {p: np.zeros(im.shape[:2], np.float32) for p, im in pages.items()}; touched = []
        allowed = {p: np.ones(im.shape[:2], np.int16) for p, im in pages.items()}
        key = lambda s: (tuple(s['pages']), tuple(np.round(np.ravel(s['uv_a']) * 2).astype(int)), tuple(np.round(np.ravel(s['uv_b']) * 2).astype(int)))
        groups = {}
        for i, s in enumerate(self.inv['seams']):
            groups.setdefault(key(s), []).append(i)
        done = set()
        for r in rows:
            if not (r['judged'] and r['class'] == 'tone'):
                continue
            s = self.inv['seams'][r['i']]; kk = key(s)
            if kk in done or r['i'] in exclude:
                continue
            done.add(kk); n_inst = len(groups[kk])
            if subtypes is not None and not (s.get('subtypes', [None, None])[0] in subtypes and s.get('subtypes', [None, None])[1] in subtypes):
                continue
            L = max(self.frame(s, 0)[3], self.frame(s, 1)[3])
            if L < 4:
                continue
            n = int(np.clip(L / 1.5, 6, 64)); ts = np.linspace(.04, .96, n)
            (a1, ia), (b1, ib) = self.sample(pages, s, ts, 1.5)
            v = ia & ib & (a1[:, 3] >= .5) & (b1[:, 3] >= .5)
            if v.sum() < 3:
                continue
            k = max(3, n // 6)                                                                    # smooth along the edge
            def smooth(c):
                cc = np.where(v[:, None], c[:, :3], np.nan); out = np.zeros_like(cc)
                for i in range(n):
                    w_ = cc[max(0, i - k):i + k + 1]; out[i] = np.nanmean(w_, 0) if np.isfinite(w_).any() else np.nan
                ok = np.isfinite(out).all(1)
                for ch in range(3):
                    out[:, ch] = np.interp(ts, ts[ok], out[ok, ch])
                return out
            mA, mB = smooth(a1), smooth(b1); tgt = (mA + mB) / 2
            for side, m in ((0, mA), (1, mB)):
                D = np.clip(tgt - m, -max_delta, max_delta); P, e, nn, Ls = self.frame(s, side); pg = s['pages'][side]; Np = pages[pg].shape[0]
                lo = np.floor(np.minimum(P[0], P[1]) - band - 2).astype(int); hi = np.ceil(np.maximum(P[0], P[1]) + band + 2).astype(int)
                lo = np.clip(lo, 0, Np); hi = np.clip(hi, 0, Np)
                yy, xx = np.mgrid[lo[1]:hi[1], lo[0]:hi[0]]; q = np.c_[xx.ravel() + .5, yy.ravel() + .5]
                t = ((q - P[0]) @ e) / max(Ls, 1e-9); d = (q - P[0]) @ nn
                sel = (t >= 0) & (t <= 1) & (d >= -gutter) & (d <= band)
                yv, xv = yy.ravel()[sel], xx.ravel()[sel]; t, d = t[sel], d[sel]
                own = cov[pg][yv, xv] <= n_inst
                inface = inside(self.poly[(s['obj'], s['faces'][side])], xv + .5, yv + .5)
                keep = own & (inface | (cov[pg][yv, xv] == 0))
                yv, xv, t, d = yv[keep], xv[keep], t[keep], d[keep]
                taper = np.clip(np.minimum(t, 1 - t) / .1, 0, 1)
                w = np.where(d < 0, 1., 1 - d / band) * taper
                Dt = np.stack([np.interp(t, ts, D[:, ch]) for ch in range(3)], -1)
                np.add.at(acc[pg], (yv, xv), Dt * w[:, None]); np.add.at(wsum[pg], (yv, xv), w)
                allowed[pg][yv, xv] = np.maximum(allowed[pg][yv, xv], n_inst)
            touched += groups[kk]
        new = {}; changed = {}
        for p, im in pages.items():
            dl = acc[p] / np.maximum(wsum[p], 1.)[..., None]; out = im.copy(); out[..., :3] = np.clip(im[..., :3] + dl, 0, 1)
            new[p] = out; changed[p] = int((np.abs(np.rint(out * 255) - np.rint(im * 255)).max(-1) > 0).sum())
            assert not (np.abs(dl).max(-1)[cov[p] > allowed[p]] > 0).any(), 'a texel shared beyond its seam group would change'
        return new, touched, changed


def main():
    ap = argparse.ArgumentParser(); ap.add_argument('mode', choices=('monitor', 'edit')); ap.add_argument('--inventory', required=True)
    ap.add_argument('--pages', required=True); ap.add_argument('--out', help='monitor: report dir'); ap.add_argument('--top', type=int, default=40)
    ap.add_argument('--out-pages', help='edit: dir for the edited BaseColor pages (same file names)'); ap.add_argument('--band', type=float, default=6.)
    ap.add_argument('--classes', help='per-page texel class maps (.npy), e.g. 0=ROLE_P0.npy,5=ROLE_P5.npy: a class change across a seam is a boundary')
    ap.add_argument('--class-scale', type=float, default=64.)
    ap.add_argument('--edit-subtypes', help='edit only seams whose two faces carry these paint subtypes (comma ids); others are reported')
    a = ap.parse_args()
    S = Seams(json.load(open(a.inventory)), load_classes(a.classes, a.class_scale) if a.classes else None); pages = load_pages(a.pages)
    names = {int(k): Path(v).name for k, v in (x.split('=', 1) for x in a.pages.split(','))}
    summ, rows = S.monitor(pages)
    if a.mode == 'monitor':
        O = Path(a.out); O.mkdir(parents=True, exist_ok=True)
        n = S.strips(pages, rows, a.top, O / 'SEAM_STRIPS.png')
        json.dump({'summary': summ, 'rows': rows}, open(O / 'SEAM_MONITOR.json', 'w'), indent=0)
        print('SEAM_MONITOR', json.dumps(summ), 'strips', n); return
    subs = {int(x) for x in a.edit_subtypes.split(',')} if a.edit_subtypes else None
    before = {r['i']: r for r in rows}; rejected = set()
    for _ in range(4):                                     # a seam the blend makes worse (overlapping bands on narrow faces) is
        new, touched, changed = S.edit(pages, rows, a.band, subtypes=subs, exclude=rejected)   # rejected and the pass redone
        s2, rows2 = S.monitor(new); after = {r['i']: r for r in rows2}
        worse_i = [i for i in touched if after[i]['judged'] and after[i]['ratio'] > before[i]['ratio'] + .05]
        if not worse_i:
            break
        rejected |= set(worse_i)
    imp = [(before[i]['ratio'], after[i].get('ratio')) for i in touched if after[i]['judged']]
    better = sum(1 for b, c in imp if c is not None and c < b); worse = [(b, c) for b, c in imp if c is not None and c > b + .05]
    O = Path(a.out_pages); O.mkdir(parents=True, exist_ok=True)
    for p, im in new.items():
        Image.fromarray(np.clip(np.rint(im * 255), 0, 255).astype(np.uint8), 'RGBA').save(O / names[p])
    rep = {'before': summ, 'after': s2, 'edited_seams': len(touched), 'improved': better, 'worse': worse[:20], 'changed_texels': changed,
           'rejected': sorted(rejected), 'edit_subtypes': sorted(subs) if subs else 'all'}
    json.dump(rep, open(O / 'SEAM_EDIT.json', 'w'), indent=1)
    print('SEAM_EDIT seams', len(touched), 'improved', better, 'worse', len(worse), 'rejected', len(rejected), 'changed', changed,
          '| tone m %.1f -> %.1f' % (summ['tone_m'], s2['tone_m']), '| score %.1f -> %.1f' % (summ['score'], s2['score']))
    if worse:
        sys.exit(1)


if __name__ == '__main__':
    main()
