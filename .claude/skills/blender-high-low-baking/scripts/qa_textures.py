"""Numeric texture QA on finished page maps (background Blender for EXR IO: blender -b --factory-startup --python qa_textures.py -- config.json).

config = {
  "pages": {"P2048": {"size": 2048, "basecolor": ".../P2048_BaseColor.png", "normal": ".../P2048_Normal.png",
                      "cls": ".../CLS_P2048.exr", "ws_normal": ".../WN_P2048.exr",
                      "opacity": null}, ...},
  "classes": ["WOOD", ...],                 # index = round(CLS.R * 16)
  "targets": {"ROOF_TRIM": {"hex": "41464A", "tol": 0.35, "min_std": 0.03}, ...},   # tol: relative luma distance
  "default_min_std": 0.02, "min_island_px": 64, "out": ".../qa_report.json"
}
Checks per page: empty texels inside owner islands (valid but basecolor ~0), FLAT islands (connected
components of one class whose RELATIVE luma spread std/mean < min_std - a plain fill where structure is
expected; relative, so dark materials like a glaze are not flagged for being dark),
class luma mean vs target, normal length. Exit code 3 when any check fails; the report lists the worst islands
with their pixel bounding boxes so they can be found on the UV sheet.
"""
import json
import sys

import bpy
import numpy as np


def load(path, size):
    im = bpy.data.images.load(str(path), check_existing=False); im.colorspace_settings.name = 'Non-Color'
    a = np.empty(size * size * 4, np.float32); im.pixels.foreach_get(a); bpy.data.images.remove(im)
    return a.reshape(size, size, 4)


def islands(mask):
    """4-connected components (pure numpy union by iterative label propagation)."""
    lab = np.where(mask, np.arange(mask.size, dtype=np.int64).reshape(mask.shape), -1)
    big = np.iinfo(np.int64).max
    for _ in range(4096):
        cur = np.where(mask, lab, big); new = cur.copy()
        for ax, sh in ((0, 1), (0, -1), (1, 1), (1, -1)):
            nb = np.roll(cur, sh, ax)
            new = np.minimum(new, np.where(mask, nb, big))
        new = np.where(mask, new, -1)
        if np.array_equal(new, lab):
            break
        lab = new
    return lab


cfg = json.load(open(sys.argv[sys.argv.index('--') + 1], encoding='utf-8-sig'))   # tolerate a BOM (PowerShell 5.1)
classes = cfg['classes']; report = {'pages': {}, 'fail': []}
for page, pc in cfg['pages'].items():
    n = pc['size']; base = load(pc['basecolor'], n)[..., :3]
    cls = np.clip(np.rint(load(pc['cls'], n)[..., 0] * 16), 0, len(classes) - 1).astype(int)
    valid = np.linalg.norm(load(pc['ws_normal'], n)[..., :3], axis=-1) > 0.5
    luma = base[..., 0] * .2126 + base[..., 1] * .7152 + base[..., 2] * .0722
    pr = {'empty_texels': int((valid & (base.max(-1) < 0.004)).sum()), 'classes': {}, 'flat_islands': []}
    if pr['empty_texels'] > 0:
        report['fail'].append(f'{page}: {pr["empty_texels"]} empty texels inside islands')
    if pc.get('normal'):
        nv = load(pc['normal'], n)[..., :3] * 2 - 1; ln = np.linalg.norm(nv, axis=-1)[valid]
        pr['normal_len_p01_p99'] = [round(float(np.quantile(ln, .01)), 3), round(float(np.quantile(ln, .99)), 3)]
    for ci, name in enumerate(classes):
        mk = valid & (cls == ci)
        if mk.sum() < cfg.get('min_island_px', 64):
            continue
        t = cfg.get('targets', {}).get(name, {})
        entry = dict(px=int(mk.sum()), luma_mean=round(float(luma[mk].mean()), 4), luma_std=round(float(luma[mk].std()), 4))
        if t.get('hex'):
            c = np.array([int(t['hex'][i:i + 2], 16) / 255 for i in (0, 2, 4)])
            tl = float(c[0] * .2126 + c[1] * .7152 + c[2] * .0722)
            entry['target_luma'] = round(tl, 4); dev = abs(entry['luma_mean'] - tl) / max(tl, 1e-3)
            entry['rel_dev'] = round(dev, 3)
            if dev > t.get('tol', 0.35):
                report['fail'].append(f'{page} {name}: mean luma {entry["luma_mean"]} vs target {tl:.3f} ({dev:.0%})')
        pr['classes'][name] = entry
        # islands at quarter resolution (enough to find flat fills; propagation cost ~ island length)
        small = islands(mk[::4, ::4]); lab = np.repeat(np.repeat(small, 4, 0), 4, 1)[:n, :n]; lab = np.where(mk, lab, -1)
        ids, counts = np.unique(lab[mk & (lab >= 0)], return_counts=True)
        floor = t.get('min_std', cfg.get('default_min_std', 0.02))
        for iid, cnt in zip(ids, counts):
            if cnt < cfg.get('min_island_px', 64):
                continue
            sel = lab == iid; s = float(luma[sel].std()) / max(float(luma[sel].mean()), 0.05)   # relative spread
            if s < floor:
                ys, xs = np.nonzero(sel)
                pr['flat_islands'].append(dict(cls=name, px=int(cnt), luma_std=round(s, 4),
                                               bbox_px=[int(xs.min()), int(n - 1 - ys.max()), int(xs.max()), int(n - 1 - ys.min())]))
    pr['flat_islands'].sort(key=lambda x: -x['px'])
    if pr['flat_islands']:
        report['fail'].append(f'{page}: {len(pr["flat_islands"])} flat islands, largest {pr["flat_islands"][0]}')
    report['pages'][page] = pr
open(cfg['out'], 'w').write(json.dumps(report, indent=2))
print('QA', 'FAIL' if report['fail'] else 'PASS', json.dumps(report['fail'][:12]))
sys.exit(3 if report['fail'] else 0)
