"""UV cleanness evaluator (driver): background Blender measures, the host draws.

    python uv_eval.py --blend FILE.blend --objects A,B --uv-layer UVMap --page 1024 --out ABS_OUTDIR
                      [--label NAME] [--occluders C,D] [--pose-frame N [--pose-action NAME] | --pose-npz FILE]
                      [--forward 0,-1,0] [--part-map PARTS.json | --part-attr part [--part-names NAMES.json]]
                      [--bone-regions RULES.json] [--mirror-overlap none|x] [--mirror-tol 0.01] [--gutter-px 4]
                      [--tiny-px 16] [--metres-per-unit 1.0] [--floor-tu N] [--headings 8] [--pitch 47] [--double-sided]
                      [--res 560] [--game-res 360] [--no-render]
                      [--blender-exe EXE | --local-config tool-paths.local.json]

Inputs: a .blend (opened read only, never saved), the mesh objects that share ONE texture page, the UV layer name
(the same on every object), the page size. Output folder (absolute, outside every git work tree):
  metrics.json      every metric below, plus run metadata (blend sha256, Blender version, pose used, camera)
  data.npz          per-triangle arrays for the drawings (UV, island, object, polygon, visibility, region, ...)
  renders/*.png     checker / stretch / angle on the model (front, back, side_left, three_quarter, bind pose) and
                    checker / stretch at the game camera (--headings headings at --pitch, posed when a pose is given)
  uv_layout.png     islands coloured, wire, page grid, seams coloured by in-game visibility, gutter violations,
                    overlaps, zoom on the tightest island pair at texel level
  uv_stretch.png    L2 stretch and angular distortion per face on the UV
  model_checker.png, model_stretch.png, summary_card.png

Metrics (definitions in uvlib.py): Sander et al. 2001 L2 / Linf stretch (page-normalised, 1 = ideal; per island in
islands.list), angular distortion (sigma1/sigma2, angle deviation), area distortion (log2 area ratio), texel density
per face in texels per metre (p10/p50/p90, per part, visible-weighted), bone-region densities and the head/torso
ratio (the reference unit benchmark's estimator), islands (count, sizes, tiny), seams (total and VISIBLE length, both also
per sqrt(surface area)), packing (texel coverage, island gaps in texels, pairs below --gutter-px, the mip where
gutters vanish, page border gap), overlaps (unintended, declared mirror with --mirror-overlap x, folds), flipped faces,
island orientation (3D up in UV), UV split vertices for this layer and GPU vertices over EVERY UV layer in the file.

Exit codes: 0 ok, 2 setup error or Blender stage failed, 3 drawing failed.
"""
import argparse
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import uvenv  # noqa: E402


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter,
                                 add_help=False)
    ap.add_argument('--blend')
    ap.add_argument('--log', help='Blender log file (default OUT/blender.log)')
    ap.add_argument('-h', '--help', action='store_true')
    uvenv.add_blender_args(ap)
    a, rest = ap.parse_known_args()
    if a.help:
        print(__doc__)
        return 0
    if not a.blend:
        raise uvenv.SetupError('--blend is required')
    if '--out' not in rest:
        raise uvenv.SetupError('--out is required (absolute folder outside any git work tree)')
    i = rest.index('--out')
    out = uvenv.out_path(rest[i + 1], 'output folder')
    rest[i + 1] = str(out)
    blend = os.path.abspath(a.blend)
    if not os.path.isfile(blend):
        raise uvenv.SetupError('blend not found: %s' % blend)
    exe = uvenv.resolve_blender(a.blender_exe, a.local_config)
    os.makedirs(out, exist_ok=True)
    log = a.log or os.path.join(out, 'blender.log')
    code, txt = uvenv.run_blender(exe, os.path.join(HERE, 'uv_eval_blender.py'), rest, blend=blend, log=log)
    ok_line = [ln for ln in txt.splitlines() if ln.startswith('UVEVAL_OK')]
    if code != 0 or not ok_line:
        print(txt[-4000:])
        print('BLENDER STAGE FAILED (exit %d), log %s' % (code, log))
        return 2
    print(ok_line[0])
    q = subprocess.run([sys.executable, os.path.join(HERE, 'uv_draw.py'), str(out)], capture_output=True, text=True)
    print(q.stdout.strip())
    if q.returncode != 0:
        print(q.stderr[-3000:])
        return 3
    print('METRICS', os.path.join(str(out), 'metrics.json'))
    return 0


if __name__ == '__main__':
    sys.exit(main())
