"""Blender front end of bake_intent_core.py (background Blender, read-only): extracts the world triangles, UVs and the
declared-intent face flag of the roof objects, decodes the final normal map and reports the world-space bake intent
measures with their negative controls and a verdict.

    blender -b FILE.blend --python-exit-code 1 --python bake_intent_check.py -- --objects NAME [NAME ...] --normal PNG
        [--uv UV_Final] [--slot N] [--flip-r] [--flip-g] [--texel-mask MASK.npy] [--free-attr intent_free]
        [--out REPORT.json] [--label TEXT]

--normal: the map as the mesh reads it (OpenGL / +Y up). An engine map with green flipped: --flip-g; an exporter that
stores red flipped: --flip-r. --slot: only faces of this material slot. --texel-mask: NPY image (row 0 = top), only
texels > 0 count (e.g. the tile texels of a shared page). --free-attr: an INT/BOOL FACE attribute the builder sets on
faces whose deviation is intended (a corner sweep zone); they are measured apart and never gate.
The report holds the run and both controls (flipG, swapRG); exit 0 PASS, 1 FAIL, 2 INCONCLUSIVE.
"""
import argparse, json, sys
from pathlib import Path
import bpy
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bake_intent_core as C  # noqa: E402

ap = argparse.ArgumentParser(); ap.add_argument('--objects', nargs='+', required=True); ap.add_argument('--normal', required=True)
ap.add_argument('--uv', default='UV_Final'); ap.add_argument('--slot', type=int); ap.add_argument('--flip-r', action='store_true')
ap.add_argument('--flip-g', action='store_true'); ap.add_argument('--texel-mask'); ap.add_argument('--free-attr', default='intent_free')
ap.add_argument('--out'); ap.add_argument('--label', default='')
a = ap.parse_args(sys.argv[sys.argv.index('--') + 1:])
img = bpy.data.images.load(str(Path(a.normal).resolve())); img.colorspace_settings.name = 'Non-Color'; W, H = img.size
NT = np.array(img.pixels[:], dtype=np.float32).reshape(H, W, img.channels)[::-1, :, :3] * 2 - 1    # row 0 = top
if a.flip_r:
    NT[..., 0] *= -1
if a.flip_g:
    NT[..., 1] *= -1
MASK = (np.load(a.texel_mask) > 0) if a.texel_mask else None
P, UV, FREE, GRP = [], [], [], []
for name in a.objects:
    ob = bpy.data.objects[name]; me = ob.data; me.calc_loop_triangles(); uvl = me.uv_layers[a.uv].data
    mw = np.array(ob.matrix_world); co = np.array([v.co for v in me.vertices]); co = co @ mw[:3, :3].T + mw[:3, 3]
    fa = me.attributes.get(a.free_attr)
    free = [bool(d.value) for d in fa.data] if fa is not None and fa.domain == 'FACE' else None
    for t in me.loop_triangles:
        if a.slot is not None and t.material_index != a.slot:
            continue
        P.append(co[list(t.vertices)]); UV.append([uvl[l].uv[:] for l in t.loops])
        FREE.append(bool(free and free[t.polygon_index])); GRP.append(name)
rep = C.measure(np.array(P), np.array(UV), NT, np.array(FREE), MASK, GRP)
ctl = {k: C.measure(np.array(P), np.array(UV), C.control(NT, k), np.array(FREE), MASK) for k in ('flipG', 'swapRG')}
status, why = C.verdict(rep, controls=ctl)
out = dict(label=a.label, normal=a.normal, objects=a.objects, status=status, why=why, thresholds=C.THRESHOLDS, run=rep,
           controls={k: {x: v[x] for x in ('lap_asymmetry', 'roll_axis_ratio')} for k, v in ctl.items()})
if a.out:
    Path(a.out).write_text(json.dumps(out, indent=1))
print('BAKE_INTENT', status, json.dumps(dict(why=why, **{k: rep[k] for k in ('texels', 'lap_asymmetry', 'roll_axis_ratio', 'lap_axis_deg', 'anisotropy', 'declared')},
                                           controls=out['controls'])))
sys.exit({'PASS': 0, 'FAIL': 1}.get(status, 2))
