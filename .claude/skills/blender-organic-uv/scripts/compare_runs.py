"""Side-by-side comparison of several uv_eval runs (host, PIL): one table image + one JSON.

    python compare_runs.py OUT.png RUNDIR [RUNDIR ...] [--json OUT.json] [--title TEXT]

OUT.png and OUT.json must lie outside every git work tree (scratch output only).

Each RUNDIR is a uv_eval.py output folder (metrics.json, uv_layout.png, renders/). Rows = the headline metrics,
columns = runs, then the UV layout and a game-camera checker tile of each run. No ranking or score: the numbers
only (lower is better for stretch, seams, islands, overlaps, splits; higher for gaps, coverage, uprightness).
"""
import argparse
import json
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import uv_draw as UD  # noqa: E402
import uvenv  # noqa: E402

ROWS = [
    ('page', lambda M: M['page']),
    ('pose', lambda M: M['pose']['mode']),
    ('triangles / vertices', lambda M: '%d / %d' % (M['counts']['triangles'], M['counts']['vertices'])),
    ('UV split vertices (ratio)', lambda M: '%d (x%.2f)' % (M['counts']['uv_split_vertices'], M['counts']['uv_split_ratio'])),
    ('L2 stretch / Linf', lambda M: '%s / %s' % (M['distortion']['L2_stretch'], M['distortion']['Linf_stretch'])),
    ('angular s1/s2 mean / p90', lambda M: '%s / %s' % (M['distortion']['angular_aniso_mean'], M['distortion']['angular_aniso_p90'])),
    ('angle dev mean deg', lambda M: M['distortion']['angle_dev_mean_deg']),
    ('area |log2| mean', lambda M: M['distortion']['area_log2_mean_abs']),
    ('texel t/m p10/p50/p90', lambda M: '%s / %s / %s' % tuple(M['texel_density']['all'][k] for k in ('p10', 'p50', 'p90'))),
    ('texel global equivalent', lambda M: M['texel_density']['global_equivalent']),
    ('head / torso (bone regions)', lambda M: M.get('bone_regions', {}).get('head_torso')),
    ('density CV', lambda M: M['texel_density']['all']['cv']),
    ('islands (tiny)', lambda M: '%d (%d)' % (M['islands']['count'], M['islands']['tiny_count'])),
    ('seam length m', lambda M: M['seams']['seam_length_m']),
    ('visible seam m mean / any', lambda M: '%s / %s' % (M['seams']['visible_mean_m'], M['seams']['visible_any_m'])),
    ('visible seam on screen m', lambda M: M['seams'].get('visible_projected_mean_m')),
    ('seam / visible per sqrt(area)', lambda M: '%s / %s' % (M['seams'].get('seam_per_sqrt_area'), M['seams'].get('visible_mean_per_sqrt_area'))),
    ('GPU vertices, all UV layers', lambda M: M['counts'].get('gpu_vertices_all_uv_layers')),
    ('texel coverage', lambda M: UD.pct(M['packing']['coverage_texels'])),
    ('min island gap px', lambda M: M['packing']['min_island_gap_px']),
    ('pairs < gutter', lambda M: '%d (< %g px)' % (M['packing']['island_pairs_below_gutter'], M['packing']['gutter_px_required'])),
    ('gutters vanish at mip', lambda M: '%s (%s px)' % (M['packing']['gutter_vanish_mip'], M['packing']['gutter_vanish_page_px'])),
    ('page border gap px', lambda M: M['packing']['min_page_border_px']),
    ('overlap unint./mirror/fold px2', lambda M: '%s / %s / %s' % (M['overlaps']['unintended_px2'], M['overlaps']['declared_mirror_px2'], M['overlaps']['self_fold_px2'])),
    ('flipped faces', lambda M: M['flips']['flipped_faces']),
    ('upright / axis-aligned islands', lambda M: '%s / %s' % (UD.pct(M['orientation']['upright_share_15deg']), UD.pct(M['orientation']['axis_aligned_share_15deg']))),
    ('UV area never visible', lambda M: UD.pct(M['visibility']['uv_area_on_never_visible_share'])),
    ('L/R density asym |log2| (pairs)', lambda M: '%s (%s)' % (M['symmetry'].get('density_log2_asym_mean'), M['symmetry'].get('pairs'))),
]


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('out')
    ap.add_argument('runs', nargs='+')
    ap.add_argument('--json')
    ap.add_argument('--title', default='UV runs compared')
    a = ap.parse_args()
    a.out = str(uvenv.out_path(a.out, 'comparison picture'))
    if a.json:
        a.json = str(uvenv.out_path(a.json, 'comparison JSON'))
    Ms = [json.load(open(os.path.join(r, 'metrics.json'))) for r in a.runs]
    colw, labw, rowh = 520, 380, 30
    thumb_w = colw - 20
    W = labw + colw * len(Ms) + 20
    H = 120 + rowh * (len(ROWS) + 1) + thumb_w + 40 + thumb_w + 60
    im = Image.new('RGB', (W, H), UD.BG)
    d = ImageDraw.Draw(im)
    fT, fH, fB = UD.font(30, True), UD.font(19, True), UD.font(18)
    d.text((20, 16), a.title, fill=UD.TXT, font=fT)
    y = 70
    for j, M in enumerate(Ms):
        d.text((labw + j * colw, y), M['label'][:48], fill=(255, 200, 90), font=fH)
    y += rowh + 6
    table = {}
    for k, f in ROWS:
        d.text((20, y), k, fill=UD.DIM, font=fB)
        for j, M in enumerate(Ms):
            try:
                v = f(M)
            except Exception:  # noqa: BLE001
                v = '-'
            table.setdefault(M['label'], {})[k] = v
            d.text((labw + j * colw, y), str(v), fill=UD.TXT, font=fB)
        y += rowh
    y += 20
    for j, (r, M) in enumerate(zip(a.runs, Ms)):
        p = os.path.join(r, 'uv_layout.png')
        if os.path.exists(p):
            S, m = min(2048, int(M['page']) * 2), 50          # uv_draw.draw_layout canvas size and margin
            t = Image.open(p).convert('RGB').crop((m - 4, m - 4, m + S + 4, m + S + 4)).resize((thumb_w, thumb_w), Image.LANCZOS)
            im.paste(t, (labw + j * colw, y))
    d.text((20, y), '\n'.join(['UV layout', '(seams: red = visible', 'in game, white = hidden;', 'red circles = gaps',
                               'below the gutter)']), fill=UD.DIM, font=fB)
    y += thumb_w + 20
    for j, (r, M) in enumerate(zip(a.runs, Ms)):
        t = UD.thumb(M.get('renders', {}).get('checker_game_h045'), thumb_w)
        if t:
            im.paste(t, (labw + j * colw, y))
    d.text((20, y), 'game camera h045,\nchecker', fill=UD.DIM, font=fB)
    im.save(a.out)
    if a.json:
        json.dump({'runs': a.runs, 'table': table}, open(a.json, 'w'), indent=1)
    print('PICTURE', os.path.abspath(a.out))


if __name__ == '__main__':
    main()
