"""Host stage of the UV cleanness evaluator: UV pictures, model sheets and the one-page summary card (PIL + numpy).

    python uv_draw.py OUTDIR

Reads OUTDIR/metrics.json, OUTDIR/data.npz and OUTDIR/renders/*.png (written by uv_eval_blender.py) and writes
OUTDIR/uv_layout.png, uv_stretch.png, model_checker.png, model_stretch.png and summary_card.png (absolute paths
printed). Normally started by uv_eval.py. OUTDIR must lie outside every git work tree.
"""
import colorsys
import json
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

BG = (30, 30, 34)
PAGE_BG = (52, 52, 58)
GRID = (78, 78, 86)
TXT = (230, 230, 230)
DIM = (160, 160, 168)


def font(size, bold=False):
    for name in (('arialbd.ttf' if bold else 'arial.ttf'), 'DejaVuSans.ttf'):
        for d in (os.path.join(os.environ.get('WINDIR', 'C:/Windows'), 'Fonts'), '/usr/share/fonts/truetype/dejavu', ''):
            try:
                return ImageFont.truetype(os.path.join(d, name) if d else name, size)
            except OSError:
                continue
    return ImageFont.load_default()


def isl_color(i, sat=0.55, val=0.85):
    h = (i * 0.61803398875) % 1.0
    r, g, b = colorsys.hsv_to_rgb(h, sat, val)
    return int(r * 255), int(g * 255), int(b * 255)


def div_color(x, lo=-1.0, hi=1.0):
    t = min(1.0, max(0.0, (x - lo) / (hi - lo)))
    c0, c1, c2 = np.array([41, 82, 191]), np.array([247, 247, 247]), np.array([204, 26, 26])
    c = c0 + (c1 - c0) * (t / 0.5) if t < 0.5 else c1 + (c2 - c1) * ((t - 0.5) / 0.5)
    return tuple(int(v) for v in c)


def seq_color(x, lo, hi):
    t = min(1.0, max(0.0, (x - lo) / (hi - lo)))
    stops = np.array([[247, 247, 242], [252, 204, 77], [230, 77, 38], [115, 13, 89]], float)
    pos = t * (len(stops) - 1)
    i = min(int(pos), len(stops) - 2)
    f = pos - i
    return tuple(int(v) for v in stops[i] * (1 - f) + stops[i + 1] * f)


class Canvas:
    def __init__(self, page, size, margin=40):
        self.page, self.size, self.m = page, size, margin
        self.s = size / page

    def xy(self, uv):
        """UV (V up) -> canvas pixel (y down)."""
        return (self.m + uv[0] * self.size, self.m + (1 - uv[1]) * self.size)


def page_frame(d, cv, grid_tex=64):
    m, S = cv.m, cv.size
    d.rectangle([m, m, m + S, m + S], fill=PAGE_BG)
    step = grid_tex * cv.s
    k = 0
    while k * step <= S + 0.5:
        w = 2 if (k * grid_tex) % (cv.page // 4) == 0 else 1
        col = (110, 110, 120) if w == 2 else GRID
        d.line([m + k * step, m, m + k * step, m + S], fill=col, width=w)
        d.line([m, m + k * step, m + S, m + k * step], fill=col, width=w)
        k += 1
    d.rectangle([m, m, m + S, m + S], outline=(200, 200, 210), width=2)


def legend(d, x, y, items, f):
    for col, txt in items:
        d.rectangle([x, y + 3, x + 22, y + 17], fill=col)
        d.text((x + 30, y), txt, fill=TXT, font=f)
        y += 24
    return y


def draw_layout(D, M, out_png):
    page = int(M['page'])
    S = min(2048, page * 2)
    cv = Canvas(page, S, 50)
    W = S + 2 * cv.m + 620
    H = S + 2 * cv.m + 60
    im = Image.new('RGB', (W, H), BG)
    d = ImageDraw.Draw(im, 'RGBA')
    page_frame(d, cv, grid_tex=max(16, page // 16))
    UV, lab, fl = D['UV'], D['lab'], D['flipped']
    ovl = D['overlaps']
    bad = set()
    decl = set()
    for row in ovl:
        (bad if int(row[3]) in (0, 2) else decl).update([int(row[0]), int(row[1])])
    for t in range(len(UV)):
        pts = [cv.xy(p) for p in UV[t]]
        c = isl_color(int(lab[t]))
        if fl[t]:
            c = tuple(int(v * 0.55) for v in c)
        d.polygon(pts, fill=c + (235,))
    for t in range(len(UV)):
        pts = [cv.xy(p) for p in UV[t]]
        d.line(pts + [pts[0]], fill=(0, 0, 0, 110), width=1)
    # outlines: seams coloured by in-game visibility, borders grey
    for k, e in enumerate(D['seam_uv']):
        f = float(D['seam_vis_frac'][k])
        col = (255, 40, 40, 255) if f >= 0.25 else ((255, 165, 0, 255) if f > 0 else (245, 245, 245, 220))
        for side in e:
            d.line([cv.xy(side[0]), cv.xy(side[1])], fill=col, width=3 if f > 0 else 2)
    for t in bad:
        pts = [cv.xy(p) for p in UV[t]]
        d.line(pts + [pts[0]], fill=(255, 0, 255, 255), width=3)
    for t in decl:
        pts = [cv.xy(p) for p in UV[t]]
        d.line(pts + [pts[0]], fill=(0, 230, 255, 255), width=2)
    g = D['gaps']
    need = float(M['packing']['gutter_px_required'])
    for row in g:
        if row[2] >= need:
            break
        if np.isnan(row[3]):
            continue
        pa = (row[3] / page, row[4] / page)
        pb = (row[5] / page, row[6] / page)
        A, B = cv.xy(pa), cv.xy(pb)
        rad = max(6, need * cv.s)
        d.ellipse([A[0] - rad, A[1] - rad, A[0] + rad, A[1] + rad], outline=(255, 30, 30, 255), width=2)
        d.line([A, B], fill=(255, 30, 30, 255), width=3)
    f1, f2, f3 = font(30, True), font(20), font(17)
    P = M['packing']
    d.text((cv.m, 10), '%s  |  UV layout  |  %d x %d page, grid %d texels' % (
        M['label'], page, page, max(16, page // 16)), fill=TXT, font=font(24, True))
    x0 = S + 2 * cv.m
    y = cv.m
    d.text((x0, y), 'Legend', fill=TXT, font=f1)
    y += 44
    y = legend(d, x0, y, [((200, 160, 120), 'island fill (one colour per island)'),
                          ((110, 88, 66), 'darker fill = flipped UV face'),
                          ((245, 245, 245), 'seam / outline never visible in game'),
                          ((255, 165, 0), 'seam visible in < 25 % of headings'),
                          ((255, 40, 40), 'seam visible in >= 25 % of headings'),
                          ((255, 0, 255), 'unintended overlap / fold'),
                          ((0, 230, 255), 'declared mirror overlap'),
                          ((255, 30, 30), 'island gap < %g texels (circle = gutter)' % need)], f3)
    y += 16
    I = M['islands']
    lines = ['islands %d (tiny %d)' % (I['count'], I['tiny_count']),
             'coverage %.1f %% of texels' % (100 * P['coverage_texels']),
             'pack efficiency (bbox) %s' % P['pack_efficiency_bbox'],
             'min island gap %s texels' % P['min_island_gap_px'],
             'pairs below %g texels: %d' % (need, P['island_pairs_below_gutter']),
             'gutters vanish at mip %s (%s px page)' % (P['gutter_vanish_mip'], P['gutter_vanish_page_px']),
             'bleeding pairs per mip: %s' % P['pairs_bleeding_per_mip'][:8],
             'min page-border gap %s texels' % P['min_page_border_px'],
             'overlaps: unintended %s px2, mirror %s px2, folds %s px2' % (
                 M['overlaps']['unintended_px2'], M['overlaps']['declared_mirror_px2'], M['overlaps']['self_fold_px2']),
             'flipped faces %d (mirrored islands %d)' % (M['flips']['flipped_faces'], M['flips']['mirrored_islands'])]
    for ln in lines:
        d.text((x0, y), ln, fill=TXT, font=f3)
        y += 23
    # zoom inset on the tightest pair
    y += 20
    cover = D['cover']
    if len(g) and not np.isnan(g[0][3]):
        cxp = (g[0][3] + g[0][5]) / 2
        cyp = (g[0][4] + g[0][6]) / 2
        half = 12
        z = 22
        x_a = int(math.floor(cxp)) - half
        y_a = int(math.floor(cyp)) - half
        d.text((x0, y), 'tightest pair, islands %d / %d: %.2f texels (1 cell = 1 texel)' % (
            g[0][0], g[0][1], g[0][2]), fill=TXT, font=f3)
        y += 26
        cov_lab = D['_first']
        for iy in range(2 * half):
            for ix in range(2 * half):
                tx, ty = x_a + ix, y_a + iy
                if 0 <= tx < page and 0 <= ty < page:
                    row_ = page - 1 - ty
                    li = cov_lab[row_, tx]
                    if D['multi'][row_, tx]:
                        col = (255, 0, 255)
                    elif li >= 0:
                        col = isl_color(int(li))
                    else:
                        col = PAGE_BG
                else:
                    col = (0, 0, 0)
                X = x0 + ix * z
                Y = y + (2 * half - 1 - iy) * z
                d.rectangle([X, Y, X + z - 1, Y + z - 1], fill=col, outline=(20, 20, 24))
        for (px, py) in ((g[0][3], g[0][4]), (g[0][5], g[0][6])):
            X = x0 + (px - x_a) * z
            Y = y + (2 * half - (py - y_a)) * z
            d.ellipse([X - 5, Y - 5, X + 5, Y + 5], outline=(255, 30, 30), width=3)
        y += 2 * half * z + 10
        d.text((x0, y), 'texel centres sampled at mip 0; magenta = texel shared by 2 islands', fill=DIM, font=f3)
    im.save(out_png)
    return out_png


def draw_stretch(D, M, out_png):
    page = int(M['page'])
    S = 1000
    W = 2 * S + 3 * 50
    H = S + 2 * 50 + 150
    im = Image.new('RGB', (W, H), BG)
    d = ImageDraw.Draw(im, 'RGBA')
    UV = D['UV']
    L2 = D['L2_n']
    an = D['aniso']
    f2, f3 = font(24, True), font(18)
    for k, (title, vals, cf) in enumerate((
            ('L2 stretch (Sander), log2 scale: blue = more texels than average, red = stretched', L2,
             lambda v: div_color(math.log2(v), -1, 1)),
            ('angular distortion sigma1/sigma2 (1 = conformal)', an, lambda v: seq_color(v, 1.0, 3.0)))):
        cv = Canvas(page, S, 0)
        ox = 50 + k * (S + 50)
        oy = 60
        d.rectangle([ox, oy, ox + S, oy + S], fill=PAGE_BG, outline=(200, 200, 210), width=2)
        for t in range(len(UV)):
            v = vals[t]
            col = (10, 10, 10) if not np.isfinite(v) else cf(float(v))
            pts = [(ox + p[0] * S, oy + (1 - p[1]) * S) for p in UV[t]]
            d.polygon(pts, fill=col + (255,))
            d.line(pts + [pts[0]], fill=(0, 0, 0, 60), width=1)
        d.text((ox, 20), title, fill=TXT, font=f3)
        # colour bar
        by = oy + S + 30
        for i in range(400):
            x = i / 399
            col = div_color(-1 + 2 * x) if k == 0 else seq_color(1 + 2 * x, 1, 3)
            d.line([ox + i, by, ox + i, by + 22], fill=col)
        labs = ('x0.5', 'x1', 'x2') if k == 0 else ('1.0', '2.0', '>=3.0')
        for j, lb in enumerate(labs):
            d.text((ox + j * 200 - (0 if j == 0 else 20), by + 28), lb, fill=TXT, font=f3)
    Dm = M['distortion']
    d.text((50, H - 50), '%s | L2 %s  Linf %s  aniso mean %s p90 %s  angle dev mean %s deg  |log2 area| %s  collapsed %s' % (
        M['label'], Dm['L2_stretch'], Dm['Linf_stretch'], Dm['angular_aniso_mean'], Dm['angular_aniso_p90'],
        Dm['angle_dev_mean_deg'], Dm['area_log2_mean_abs'], Dm['collapsed_faces']), fill=TXT, font=f3)
    im.save(out_png)
    return out_png


def sheet(rows, out_png, title, f_title=None):
    """rows: [(row label, [(img path, caption)])]"""
    f1 = f_title or font(26, True)
    f3 = font(18)
    ims = [[(Image.open(p).convert('RGB') if p and os.path.exists(p) else None, c) for p, c in r] for _, r in rows]
    cell_w = max((im.width for r in ims for im, _ in r if im), default=200)
    cell_h = max((im.height for r in ims for im, _ in r if im), default=200)
    ncol = max(len(r) for r in ims)
    lab_w = 0
    row_h = [max((im.height for im, _ in r if im), default=0) for r in ims]
    W = lab_w + ncol * (cell_w + 10) + 20
    H = 60 + sum(h + 40 for h in row_h)
    out = Image.new('RGB', (W, H), BG)
    d = ImageDraw.Draw(out)
    d.text((20, 14), title, fill=TXT, font=f1)
    y = 60
    for (rl, _), r, rh in zip(rows, ims, row_h):
        d.text((20, y), rl, fill=DIM, font=f3)
        x = 20
        for im, cap in r:
            if im:
                out.paste(im, (x, y + 26))
                d.text((x + 4, y + 26 + im.height - 24), cap, fill=(20, 20, 20), font=f3)
            x += (im.width if im else cell_w) + 10
        y += rh + 40
    out.save(out_png)
    return out_png


def composite_heatmaps(M):
    """<kind>_<view>_flat.png (exact colours, alpha) x shade_<view>.png (studio white) -> <kind>_<view>.png"""
    R = M.get('renders', {})
    for key, path in R.items():
        if os.path.exists(path) or not path.endswith('.png'):
            continue
        flat = path[:-4] + '_flat.png'
        view = os.path.basename(path)[:-4].split('_', 1)[1]
        shade = os.path.join(os.path.dirname(path), 'shade_%s.png' % view)
        if not (os.path.exists(flat) and os.path.exists(shade)):
            continue
        F = np.asarray(Image.open(flat).convert('RGBA')).astype(float) / 255
        S = np.asarray(Image.open(shade).convert('RGBA')).astype(float) / 255
        lum = S[..., :3].mean(-1)
        m = F[..., 3] > 0.5
        ref = np.percentile(lum[m], 95) if m.any() else 1.0
        f = 0.55 + 0.45 * np.clip(lum / max(ref, 1e-6), 0, 1)
        rgb = F[..., :3] * f[..., None]
        bg = np.array([0.80, 0.80, 0.81])
        al = F[..., 3:4]
        out = rgb * al + bg * (1 - al)
        Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8)).save(path)


def model_sheets(M, outdir):
    R = M.get('renders', {})
    if not R:
        return []
    composite_heatmaps(M)
    views = ['front', 'back', 'side_left', 'three_quarter']
    games = sorted(k[len('checker_game_'):] for k in R if k.startswith('checker_game_'))
    pose = M['pose']['mode']
    res = []
    rows = [('Checker (COLOR_GRID) on the model, bind pose, back faces culled', [(R.get('checker_' + v), v) for v in views]),
            ('Game camera, pitch %g deg, %s pose, headings 0..315 (0 = front)' % (M['camera']['pitch_deg'], pose),
             [(R.get('checker_game_' + h), h) for h in games[:4]]),
            ('', [(R.get('checker_game_' + h), h) for h in games[4:]])]
    res.append(sheet(rows, os.path.join(outdir, 'model_checker.png'), '%s | checker on the model' % M['label']))
    rows = [('L2 stretch per face (blue = more texels, white = page average, red = stretched x2), bind pose',
             [(R.get('stretch_' + v), v) for v in views]),
            ('angular distortion sigma1/sigma2 (white 1.0 -> purple >= 3)', [(R.get('angle_' + v), v) for v in views]),
            ('L2 stretch at the game camera, %s pose' % pose, [(R.get('stretch_game_' + h), h) for h in games[:4]]),
            ('', [(R.get('stretch_game_' + h), h) for h in games[4:]])]
    res.append(sheet(rows, os.path.join(outdir, 'model_stretch.png'), '%s | stretch on the model' % M['label']))
    return res


def thumb(path, w):
    if not path or not os.path.exists(path):
        return None
    im = Image.open(path).convert('RGB')
    h = int(im.height * w / im.width)
    return im.resize((w, h), Image.LANCZOS)


def summary_card(M, outdir, layout_png, stretch_png):
    W, H = 2200, 1400
    im = Image.new('RGB', (W, H), BG)
    d = ImageDraw.Draw(im)
    fT, fH, fB, fS = font(34, True), font(22, True), font(19), font(16)
    d.text((30, 20), 'UV cleanness card: %s' % M['label'], fill=TXT, font=fT)
    d.text((30, 66), '%s | objects %s | UV %s | page %d | pose %s | occluders %s' % (
        os.path.basename(M['blend']), ','.join(M['objects']), M['uv_layer'], M['page'], M['pose']['mode'],
        ','.join(M['occluders']) or '-'), fill=DIM, font=fS)
    Dm, Td, I, Sm, P, O, Fl, Or, V = (M['distortion'], M['texel_density'], M['islands'], M['seams'], M['packing'],
                                      M['overlaps'], M['flips'], M['orientation'], M['visibility'])
    a = Td['all']
    vw = Td['visible_weighted']
    rows = [
        ('DISTORTION', None),
        ('L2 stretch (1 = ideal)', Dm['L2_stretch']), ('Linf stretch', Dm['Linf_stretch']),
        ('area with L2 > 1.5', pct(Dm['faces_L2_gt_1_5_share'])),
        ('angular sigma1/sigma2 mean / p90', '%s / %s' % (Dm['angular_aniso_mean'], Dm['angular_aniso_p90'])),
        ('angle deviation mean / p90', '%s / %s deg' % (Dm['angle_dev_mean_deg'], Dm['angle_dev_p90_deg'])),
        ('area distortion mean |log2|', Dm['area_log2_mean_abs']),
        ('area ratio p10 / p90', '%s / %s' % (Dm['area_ratio_p10'], Dm['area_ratio_p90'])),
        ('collapsed faces', Dm['collapsed_faces']),
        ('TEXEL DENSITY (t/m @ page)', None),
        ('p10 / p50 / p90', '%s / %s / %s' % (a['p10'], a['p50'], a['p90'])),
        ('visible-weighted p10 / p50 / p90', '%s / %s / %s' % (vw['p10'], vw['p50'], vw['p90'])),
        ('global equivalent', Td['global_equivalent']), ('spread CV', a['cv']),
        ('head / torso, hands / torso (bone regions)', '%s / %s' % (M.get('bone_regions', {}).get('head_torso'),
                                                                   M.get('bone_regions', {}).get('hands_torso'))),
        ('ISLANDS AND SEAMS', None),
        ('islands / tiny / per m2', '%s / %s / %s' % (I['count'], I['tiny_count'], I['per_m2'])),
        ('island size px2 p10 / p50 / max', '%s / %s / %s' % (I['size_px2_p10'], I['size_px2_p50'], I['size_px2_max'])),
        ('seam length', '%s m (%d edges)' % (Sm['seam_length_m'], Sm['seam_edges'])),
        ('VISIBLE seam (mean of headings / any)', '%s / %s m' % (Sm['visible_mean_m'], Sm['visible_any_m'])),
        ('visible seam projected on screen', '%s m (mean of headings)' % Sm.get('visible_projected_mean_m')),
        ('seam / visible per sqrt(area)', '%s / %s' % (Sm.get('seam_per_sqrt_area'), Sm.get('visible_mean_per_sqrt_area'))),
        ('UV split vertices', '%s (x%s)' % (M['counts']['uv_split_vertices'], M['counts']['uv_split_ratio'])),
        ('GPU vertices, every UV layer in file', M['counts'].get('gpu_vertices_all_uv_layers')),
        ('PACKING', None),
        ('texel coverage of page', pct(P['coverage_texels'])),
        ('pack efficiency (bbox)', P['pack_efficiency_bbox']),
        ('min island gap', '%s texels (%d pairs < %g)' % (P['min_island_gap_px'], P['island_pairs_below_gutter'],
                                                          P['gutter_px_required'])),
        ('gutters vanish at', 'mip %s (%s px)' % (P['gutter_vanish_mip'], P['gutter_vanish_page_px'])),
        ('overlap unintended / mirror / fold px2', '%s / %s / %s' % (O['unintended_px2'], O['declared_mirror_px2'],
                                                                      O['self_fold_px2'])),
        ('flipped faces / mirrored islands', '%s / %s' % (Fl['flipped_faces'], Fl['mirrored_islands'])),
        ('ORIENTATION AND VISIBILITY', None),
        ('island up: mean |dev| / circ std', '%s / %s deg' % (Or['mean_abs_deg'], Or['circular_std_deg'])),
        ('upright / axis-aligned share', '%s / %s' % (pct(Or['upright_share_15deg']), pct(Or['axis_aligned_share_15deg']))),
        ('UV area on never-visible faces', pct(V['uv_area_on_never_visible_share'])),
        ('L/R density asymmetry |log2| mean', '%s (%s pairs > 25 %%)' % (M.get('symmetry', {}).get('density_log2_asym_mean'),
                                                                       M.get('symmetry', {}).get('pairs_over_25pct'))),
    ]
    y = 110
    for k, v in rows:
        if v is None:
            y += 8
            d.text((30, y), k, fill=(255, 200, 90), font=fH)
            y += 30
            continue
        d.text((40, y), k, fill=DIM, font=fB)
        d.text((430, y), str(v), fill=TXT, font=fB)
        y += 26
    # per-part table (texel density t/m, L2 stretch, islands)
    pp = Td.get('per_part', {})
    if pp and not (len(pp) == 1 and list(pp)[0].startswith('(')):
        y += 14
        d.text((30, y), 'PER PART   p10 / p50 / p90 t/m   L2   islands', fill=(255, 200, 90), font=fH)
        y += 30
        items = sorted(pp.items(), key=lambda kv: -(kv[1].get('area_m2') or 0))
        half = (len(items) + 1) // 2
        for i, (k, v) in enumerate(items):
            col = 30 if i < half else 360
            yy_ = y + (i % half) * 21
            d.text((col, yy_), '%-14s %s/%s/%s  %s  %s' % (k[:14], int(v['p10'] or 0), int(v['p50'] or 0),
                                                         int(v['p90'] or 0), v.get('L2_stretch'), v.get('islands')),
                   fill=TXT, font=font(15))
        y += half * 21
    if y + 34 > H:                                   # long part lists: grow the card instead of overprinting
        grown = Image.new('RGB', (W, y + 44), BG)
        grown.paste(im, (0, 0))
        im, H = grown, y + 44
        d = ImageDraw.Draw(im)
    d.text((30, H - 34), 'pose: %s' % M['pose']['note'][:170], fill=DIM, font=fS)
    lay = thumb(layout_png, 760)
    if lay:
        im.paste(lay, (720, 110))
    st = thumb(stretch_png, 700)
    R = M.get('renders', {})
    x = 720
    y2 = 110 + (lay.height if lay else 0) + 12
    if st:
        im.paste(st, (x, y2))
    col = 1500
    yy = 110
    for key in ('checker_three_quarter', 'checker_front', 'stretch_three_quarter'):
        t = thumb(R.get(key), 330)
        if t:
            im.paste(t, (col + (0 if key != 'checker_front' else 340), yy if key != 'checker_front' else 110))
            if key == 'checker_three_quarter':
                pass
        if key == 'checker_front':
            yy = 110 + (t.height if t else 0) + 10
    t = thumb(R.get('stretch_three_quarter'), 330)
    if t:
        im.paste(t, (col, yy))
    g0 = thumb(R.get('checker_game_h000'), 330)
    g1 = thumb(R.get('checker_game_h045'), 330)
    yy2 = yy + (t.height if t else 0) + 10
    if g0:
        im.paste(g0, (col, yy2))
    if g1:
        im.paste(g1, (col + 340, yy2))
    sw = thumb(R.get('checker_side_left'), 330)
    if sw:
        im.paste(sw, (col + 340, yy))
    d.text((col, yy2 + (g0.height if g0 else 0) + 6), 'game camera h000 / h045 (%s pose)' % M['pose']['mode'],
           fill=DIM, font=fS)
    d.text((col, 88), 'checker: three-quarter / front;  then L2 stretch three-quarter / checker side', fill=DIM, font=fS)
    out = os.path.join(outdir, 'summary_card.png')
    im.save(out)
    return out


def pct(x):
    return '-' if x is None else '%.1f %%' % (100 * float(x))


def main():
    import uvenv
    if len(sys.argv) != 2:
        print(__doc__)
        return 2
    outdir = str(uvenv.out_path(sys.argv[1], 'output folder'))
    M = json.load(open(os.path.join(outdir, 'metrics.json')))
    Z = np.load(os.path.join(outdir, 'data.npz'))
    D = {k: Z[k] for k in Z.files}
    # rebuild the island-id raster (first island per texel) for the zoom inset
    import uvlib as L
    _, first, _ = L.raster_cover(D['UV'], D['lab'], int(M['page']))
    D['_first'] = first
    outs = [draw_layout(D, M, os.path.join(outdir, 'uv_layout.png')),
            draw_stretch(D, M, os.path.join(outdir, 'uv_stretch.png'))]
    outs += model_sheets(M, outdir)
    outs.append(summary_card(M, outdir, outs[0], outs[1]))
    for p in outs:
        print('PICTURE', os.path.abspath(p))
    return 0


if __name__ == '__main__':
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    sys.exit(main())
