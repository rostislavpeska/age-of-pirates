"""Bake master runs: UV-independent maps from the HIGHs onto the unique UV_Master layout (one run per HIGH set).

1. host      python master_bake.py recipes --master M/master.json --from bank_a.json [bank_b.json ...]
                 --maps NORMAL,AO,OPACITY --run R2_D --out R2_D.json [--samples N]
                 [--receiver-normal-tolerance 5e-4] [--replace]
   Merges the scope regions of the given bank recipes by identical HIGH set, refuses differing extrusion /
   max_ray_distance / ao_distance / samples, restricts the faces to the master and writes an ordinary
   bake_owner_maps recipe: plan = master_plan.json, uv_name UV_Master, the manifest's pages the run touches,
   freeze = master_freeze.json, input_contract = the master's LOW contract, scope production, NO
   opacity_classes (every face ray-based: the target recipe applies its classes at derive time), margin 0
   (the EXTEND margin would fill missed-ray texels and blur the hit mask; derive applies the target margin),
   out_dir = M/runs/<run>. OPACITY is always baked: it is the run's own hit mask.
2. Blender   blender -b LOW.blend --factory-startup --python master_bake.py -- bake R2_D.json
   Creates UV_Master in session from master_uv.npz (faces outside the master at (-2,-2): never baked; the file
   is never saved) and runs the UNCHANGED bake_owner_maps.py source with ONE asserted override,
   normal_space 'TANGENT' -> 'OBJECT' (+ the optional keep_faces corner-normal tolerance). Post-step:
   per-face hit fraction from the run's OPACITY (a solid-class face below 0.98 is a FAIL: the HIGH does not
   cover it; it is never recorded as data), HIGH provenance (name, file sha256, mesh faces), params, Blender,
   seconds, image sha256, and face -> map -> run entries in master.json (atomic). A face x map another run
   already produced needs --replace.
Rebake triggers: a LOW contract change (new geo directory) or a HIGH file / ray parameter change. A UV edit
never is: that is derive_maps.py. Method: references/bake-master.md.
"""
import argparse
import importlib.util
import json
import sys
import time
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent


def _load(name):
    spec = importlib.util.spec_from_file_location(name, HERE / f'{name}.py')
    mod = importlib.util.module_from_spec(spec); spec.loader.exec_module(mod)
    return mod


D = _load('derive_maps')
DEFAULTS = {'extrusion': .05, 'max_ray_distance': .25, 'samples': 16, 'ao_distance': .15}
BAKE_ORDER = ('NORMAL', 'EMIT', 'AO', 'OPACITY')


def make_recipe(master, banks, maps, run, samples=None, tolerance=None, replace=False, device='CPU'):
    """-> (recipe dict, notes). Pure host-side JSON work."""
    # absolute paths only: bake_owner_maps saves the EXR through Blender, which does not write a relative
    # filepath_raw next to the relative PNG (2026-09-29: a relative --master left the runs without EXRs)
    mpath = Path(master).resolve(); mdir = mpath.parent; man = json.loads(mpath.read_text())
    banks = [Path(b).resolve() for b in banks]
    cfgs = [json.loads(Path(b).read_text()) for b in banks]
    params = {}
    for k in D.RAY_PARAMS:
        vals = {float(c.get(k, DEFAULTS[k])) for c in cfgs}
        if len(vals) != 1:
            raise ValueError(f'bank recipes differ in {k}: {sorted(vals)} - one master run needs one set of ray parameters')
        params[k] = vals.pop()
    if samples is not None:
        params['samples'] = int(samples)
    files, merged, dropped, cut = {}, {}, [], set()
    for c in cfgs:
        cut |= set(c.get('opacity_classes') or [])
        for h in c['highs']:
            if not h.get('file'):
                raise ValueError('master runs need their HIGHs in files (sha256 provenance for the derive guard)')
            for n in h['objects']:
                if files.setdefault(n, h['file']) != h['file']:
                    raise ValueError(f'HIGH {n} comes from two files')
        for r in c['scope']['regions']:
            hs = tuple(sorted(r['highs']))
            for f in r['faces']:
                if f not in man['faces']:
                    dropped.append(f); continue
                merged.setdefault(hs, [])
                if f not in merged[hs]:
                    merged[hs].append(f)
    seen = {}
    for hs, fs in merged.items():
        for f in fs:
            if seen.setdefault(f, hs) != hs:
                raise ValueError(f'{f}: bank regions pair it with two HIGH sets {seen[f]} / {hs}')
    if not merged:
        raise ValueError('no bank face is in the master layout')
    regions = [dict(id=f'{run}_{i:02d}', faces=sorted(fs), highs=list(hs)) for i, (hs, fs) in enumerate(sorted(merged.items()))]
    faces = sorted(f for r in regions for f in r['faces'])
    pages = sorted({man['faces'][f]['page'] for f in faces})
    eligible = sorted(f for f, e in man['faces'].items() if e['page'] in pages)
    by_file = {}
    for n in sorted({n for r in regions for n in r['highs']}):
        by_file.setdefault(files[n], []).append(n)
    claims = [m for m in BAKE_ORDER if m in maps]
    rec = dict(plan=str(mdir / 'master_plan.json'), sources=man['sources'],
               pages={p: man['pages'][p] for p in pages}, maps=[m for m in BAKE_ORDER if m in set(claims) | {'OPACITY'}],
               uv_name=man['uv_name'], extrusion=params['extrusion'], max_ray_distance=params['max_ray_distance'],
               samples=int(params['samples']), ao_distance=params['ao_distance'], margin=0, device=device,
               scope=dict(mode='production', regions=regions), freeze=str(mdir / 'master_freeze.json'),
               input_contract=str(mdir / 'low_contract.json'),
               highs=[dict(file=f, objects=ns) for f, ns in sorted(by_file.items())],
               out_dir=str(mdir / 'runs' / run),
               master=dict(manifest=str(mpath), run=run, claims=claims, replace=bool(replace), bank_recipes=[str(b) for b in banks],
                           dropped_faces=sorted(set(dropped)), opacity_classes=sorted(cut), normal_space='OBJECT',
                           receiver_normal_tolerance=tolerance, samples_override=samples))
    if faces != eligible:
        rec['only'] = faces
    return rec, dict(faces=len(faces), regions=len(regions), dropped=len(set(dropped)), pages=pages)


def bake(recipe_path):
    import bpy
    t0 = time.time()
    cfg = json.loads(Path(recipe_path).read_text()); mb = cfg['master']
    mpath = Path(mb['manifest']); mdir = mpath.parent; man = json.loads(mpath.read_text())
    run, claims, replace = mb['run'], list(mb['claims']), bool(mb.get('replace'))
    out = Path(cfg['out_dir'])
    if not (out.is_absolute() and mpath.is_absolute()):
        raise SystemExit('MASTER_BAKE_REFUSED relative out_dir/manifest: rewrite the recipe with master_bake.py recipes')
    if (out / 'bake_report.json').exists() and not replace:
        raise SystemExit(f'MASTER_BAKE_REFUSED run {run} already exists ({out}); pass --replace to rebake it')
    faces = sorted(f for r in cfg['scope']['regions'] for f in r['faces'])
    taken = sorted({(f, m, man['faces'][f]['maps'][m]) for f in faces for m in claims
                    if man['faces'][f]['maps'].get(m) not in (None, run)})
    if taken and not replace:
        raise SystemExit(f'MASTER_BAKE_REFUSED {len(taken)} face x map already produced by another run, e.g. {taken[:3]}; '
                         'pass --replace')
    if D.sha256_file(mdir / 'master_uv.npz') != man['npz_sha256']:
        raise SystemExit('MASTER_BAKE_REFUSED master_uv.npz differs from master.json')
    unwrap = _load('master_unwrap')
    unwrap.apply_master_uv(cfg['sources'], np.load(mdir / 'master_uv.npz'), man['uv_name'])
    t_bake = time.time()
    g = D.exec_bake_owner_maps(recipe_path, overrides=[("normal_space='TANGENT'", "normal_space='OBJECT'")],
                               receiver_normal_tolerance=mb.get('receiver_normal_tolerance'))
    t_bake = time.time() - t_bake
    if 'report' not in g:
        raise SystemExit('MASTER_BAKE_FAILED bake_owner_maps did not finish')
    lost = [f'{m}_{pg}.exr' for m in cfg['maps'] for pg in cfg['pages'] if not (out / f'{m}_{pg}.exr').is_file()]
    if lost:
        raise SystemExit(f'MASTER_BAKE_FAILED EXR masters missing in {out}: {lost} - nothing recorded in the manifest')
    # --- post-step: hit fractions on the master's own chart raster
    cut = set(mb.get('opacity_classes') or [])
    fidx = {k: i for i, k in enumerate(man['face_index'])}
    hit_fraction, fails, mismatch = {}, [], {}
    for pg in cfg['pages']:
        cz = np.load(mdir / f'charts_{pg}.npz'); face_r = cz['face']; usable = (face_r >= 0) & ~cz['border']
        op = D.load_page(out / f'OPACITY_{pg}.exr', {})[..., 0] >= 0.5
        mismatch[pg] = dict(covered_outside_layout=int((op & (face_r < 0)).sum()))
        tot = np.bincount(face_r[usable], minlength=len(fidx)); hit = np.bincount(face_r[usable & op], minlength=len(fidx))
        for f in faces:
            if man['faces'][f]['page'] != pg:
                continue
            i = fidx[f]; hf = float(hit[i] / tot[i]) if tot[i] else 0.0
            hit_fraction[f] = hf
            if man['faces'][f].get('cls') not in cut and hf < 0.98:
                fails.append(f)
    highs = []
    files = {n: h['file'] for h in cfg['highs'] for n in h['objects']}
    sha = {f: D.sha256_file(f) for f in set(files.values())}
    for n, f in sorted(files.items()):
        ob = g['highs_by_name'][n]
        highs.append(dict(name=n, file=f, sha256=sha[f], mesh_faces=len(ob.data.polygons)))
    images = {p.stem: D.sha256_file(p) for p in sorted(out.glob('*.exr'))}
    entry = dict(recipe=str(recipe_path), dir=str(out), maps=claims, baked=list(cfg['maps']), normal_space='OBJECT',
                 highs=highs, params={k: cfg.get(k, DEFAULTS[k]) for k in D.RAY_PARAMS} | {'margin': cfg.get('margin', 0)},
                 regions={r['id']: dict(faces=r['faces'], highs=r['highs']) for r in cfg['scope']['regions']},
                 blender=bpy.app.version_string, seconds=round(time.time() - t0, 1), seconds_bake=round(t_bake, 1),
                 images=images, fails=fails, layout_check=mismatch, bank_recipes=mb.get('bank_recipes'),
                 dropped_faces=mb.get('dropped_faces'), samples_override=mb.get('samples_override'))
    man = json.loads(mpath.read_text())                   # re-read: merge onto the newest manifest
    man['runs'][run] = entry
    for f in faces:
        e = man['faces'][f]; e['hit_fraction'][run] = round(hit_fraction.get(f, 0.0), 5)
        for m in claims:
            if f in fails:
                if e['maps'].get(m) == run:
                    del e['maps'][m]
            else:
                e['maps'][m] = run
    man['history'].append(dict(action='bake', run=run, time=time.strftime('%Y-%m-%d %H:%M:%S'), faces=len(faces),
                               fails=len(fails), replace=replace))
    D.write_json_atomic(mpath, man)
    print('MASTER_BAKE', run, 'faces', len(faces), 'fails', len(fails), 'seconds', entry['seconds'],
          'layout_check', mismatch)
    if fails:
        print('MASTER_BAKE_FAIL solid faces the HIGH does not cover (hit fraction < 0.98):', fails[:20])
        sys.exit(3)


def main(argv):
    if argv and argv[0] == 'bake':
        return bake(argv[1])
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('mode', choices=['recipes'])
    ap.add_argument('--master', required=True); ap.add_argument('--from', dest='banks', nargs='+', required=True)
    ap.add_argument('--maps', required=True); ap.add_argument('--run', required=True); ap.add_argument('--out', required=True)
    ap.add_argument('--samples', type=int); ap.add_argument('--receiver-normal-tolerance', type=float)
    ap.add_argument('--replace', action='store_true'); ap.add_argument('--device', default='CPU')
    a = ap.parse_args(argv)
    maps = [m.strip().upper() for m in a.maps.split(',') if m.strip()]
    rec, notes = make_recipe(a.master, a.banks, maps, a.run, a.samples, a.receiver_normal_tolerance, a.replace, a.device)
    Path(a.out).write_text(json.dumps(rec, indent=1))
    print('MASTER_RECIPE', a.out, notes)


if __name__ == '__main__':
    main(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else sys.argv[1:])
