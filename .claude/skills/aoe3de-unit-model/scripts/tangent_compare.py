#!/usr/bin/env python
"""Compare the int8 tangents stored in unit gr2 meshes with Blender's MikkTSpace on the same data (read-only).

    python tangent_compare.py --archive Art/units/asians/chinese/iron_flail/iron_rider_0.gr2 [...] [--blender EXE]

The AoE3 half only: dumps positions, stored normals, stored tangents, raw UVs and triangles of every mesh to a temp
JSON (the input format of the generic comparison), then runs blender-organic-modeling's scripts/tangent_compare.py,
which relaunches itself in background Blender (`-b`, never a window): the mesh is rebuilt from the raw data, the
stored normals become custom corner normals, `calc_tangents` runs for UVs (u, v) and (u, 1 - v), and each corner's
tangent and handedness are compared with the stored ones. Prints per mesh: median and 5th-percentile dot, share
above 0.95, share of agreeing handedness signs. Backs materials-textures.md section 6 (2026-10-10: median
0.9999-1.0, 98.4-100 % above 0.95, signs 97.9-100 %; with V flipped only 0-2.1 %). Blender: --blender, BLENDER, the
consumer's config/tool-paths.local.json (tools.blender.path) or PATH, else the generic tool's own search.
"""
import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import unit_gr2 as U  # noqa: E402

# the generic Blender half (companion skill blender-organic-modeling)
GENERIC = Path(__file__).resolve().parents[2] / 'blender-organic-modeling' / 'scripts' / 'tangent_compare.py'


def dump(m):
    meshes = []
    for me in m.meshes:
        if not {'Normal', 'Tangent', 'TextureCoordinates0'} <= set(me.comps):
            continue
        meshes.append(dict(name=me.name, P=me.pos.tolist(), N=me.comps['Normal'].astype(int).tolist(),
                           T=me.comps['Tangent'].astype(int).tolist(),
                           UV=me.comps['TextureCoordinates0'].astype(float).tolist(), I=me.tris.ravel().tolist()))
    return dict(file=m.path.name, meshes=meshes)


def blender_exe(explicit=None):
    cands = [explicit, os.environ.get('BLENDER')]
    cfg = U.ROOT / 'config' / 'tool-paths.local.json'
    if cfg.is_file():
        try:
            cands.append(json.loads(cfg.read_text(encoding='utf-8'))['tools']['blender']['path'])
        except (KeyError, ValueError, TypeError):
            pass
    cands.append(shutil.which('blender'))
    return next((c for c in cands if c and Path(c).is_file()), None)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    U.add_input_args(ap)
    ap.add_argument('--blender')
    ap.add_argument('--work', help='folder for the JSON files (default: a temp folder)')
    a = ap.parse_args(argv)
    data = []
    for p, m, why in U.models(U.resolve_inputs(a)):
        if m is None:
            print('%s: UNREADABLE %s' % (Path(p).stem, why))
            continue
        data.append(dump(m))
    work = Path(a.work) if a.work else U.temp_dir('tangents')
    work.mkdir(parents=True, exist_ok=True)
    src, out = work / 'tangent_data.json', work / 'mikk_compare.json'
    src.write_text(json.dumps(data))
    exe = blender_exe(a.blender)
    cmd = [sys.executable, str(GENERIC), '--input', str(src), '--out', str(out)] + (['--blender-exe', exe] if exe else [])
    r = subprocess.run(cmd, capture_output=True, text=True, errors='replace')
    if r.returncode or not out.is_file():
        raise SystemExit('tangent comparison failed (exit %d): %s' % (r.returncode, (r.stdout + r.stderr)[-3000:]))
    res = json.loads(out.read_text(encoding='utf-8'))['results']
    for rec in res:
        print('%s / %s (%d tris): ' % (rec['file'], rec['mesh'], rec['tris']) + '; '.join(
            'uv %s: median dot %.4f p05 %.4f >0.95 %.1f%% sign agree %.1f%%' % (
                v, rec[v]['tangent_dot_median'], rec[v]['tangent_dot_p05'], 100 * rec[v]['share_dot_gt_0.95'],
                100 * rec[v]['sign_agree']) for v in ('v', '1-v')))
    print('JSON', out)
    return res


if __name__ == '__main__':
    main()
