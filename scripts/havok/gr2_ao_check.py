"""gr2_lint check `ao_shared_uv`: baked AO (Masks.R) that belongs to ANOTHER instance of a shared UV island.

Owner 2026-10-12 (Korean Rice Paddy): "plus there is ambient oclussion bug - not catched by the harness!!!!". The four
corner posts share one UV island; the AO bake wrote the contact shadow of the OCCLUDED instance (a post face pressed
against the rack panel) into the texels every instance samples, so the OPEN instances showed a black patch in the game.
No check looked at the AO against the geometry.

Rule (measured, not guessed): every render triangle of a page whose .material binds a mod Masks texture gets 16
barycentric samples; each sample has its texel (instances of one island land on the same texels: the samples are the same barycentrics), its baked AO (Masks.R) and - when the AO is dark (< 0.5) -
its exposure: the share of 16 hemisphere rays (0.04-1.8 m, around the STORED outward normal) that hit no surface of the
model or the terrain (y < 0) (dense surface sample, KD tree); faces turned to the ground (normal y < -0.7) are skipped. A texel cell whose dark instances disagree - exposure range
>= 0.4 with the most exposed >= 0.55 - is a CONFLICT: one baked value cannot be right for both. The check sums the area
of the exposed instances' samples in conflict texels, PER PAGE. FAIL when a page exceeds the profile's
`ao_shared_uv_max_m2` (default 0.5 m2).
Repair recipe: korean-buildings-blender research/Junction_TestBed_21/all_models/recipes/ao_shared_fix.py (re-predicts
the AO of conflict texels from the exposed instance, only brightening).

Calibration 2026-10-12 (installed Korean intact models, m2 per page): Rice Paddy own page 0.97 before the repair (the
owner's finding) -> 0.18 after; Castle own page 0.75 (flagged: spread over the walls, needs a visual check); every other
page <= 0.38 (TC 0.26 + props r6.2 0.38, Dock 0.30, Market 0.16 + props 0.26, Monastery 0.16 + props 0.33, Houses <= 0.20,
Barracks 0.03, Stable 0.02). The gate 0.5 m2 per page separates the reported bug from the rest.
"""
import importlib.util
import hashlib
import math
from pathlib import Path
import numpy as np

HERE = Path(__file__).resolve().parent
DDT2PNG = HERE.parents[1] / '.claude' / 'skills' / 'aoe3-texture-weathering' / 'scripts' / 'ddt2png.py'
NS, CELL, DARK, RANGE, OPEN = 16, 1, .5, .4, .55     # CELL 1: identical-UV instances hit the SAME texels (same samples); neighbours in UV space are not shared
_rng = np.random.default_rng(0)
_B = _rng.random((NS, 2)); _f = _B.sum(1) > 1; _B[_f] = 1 - _B[_f]; BARY = np.c_[1 - _B.sum(1), _B]
DIRS = _rng.normal(size=(16, 3)); DIRS /= np.linalg.norm(DIRS, axis=1)[:, None]
STEPS = np.r_[.04, .08, .15, .25, .4, .6, .9, 1.3, 1.8]
_DDT = {}


def _read_ao(path):
    if path not in _DDT:
        spec = importlib.util.spec_from_file_location('ddt2png', str(DDT2PNG)); mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        _DDT[path] = np.asarray(mod.read_ddt(str(path))[0].convert('RGBA'))[..., 0].astype(float) / 255
    return _DDT[path]


def measure(info, masks_of):
    """masks_of(material name) -> a Masks texture file or None. -> dict(conflict_m2, area_m2, pages, top)"""
    from scipy.spatial import cKDTree
    tris = np.concatenate([np.asarray(m['pos'], float)[np.asarray(m['tris'])] for m in info['render'] if len(m['tris'])])
    TA = np.linalg.norm(np.cross(tris[:, 1] - tris[:, 0], tris[:, 2] - tris[:, 0]), axis=1) / 2
    rng = np.random.default_rng(1); n_s = int(min(4e6, max(TA.sum(), 1e-6) / .015 ** 2))
    idx = rng.choice(len(tris), n_s, p=TA / TA.sum()); u, v = rng.random(n_s), rng.random(n_s); f = u + v > 1; u[f], v[f] = 1 - u[f], 1 - v[f]
    tree = cKDTree(tris[idx, 0] + u[:, None] * (tris[idx, 1] - tris[idx, 0]) + v[:, None] * (tris[idx, 2] - tris[idx, 0]))
    keys, expo, area, where = [], [], [], []; pages = set(); total = 0.
    for m in info['render']:
        for mi, first, count in m['groups']:
            name = m['mats'][mi] if 0 <= mi < len(m['mats']) else None; tex = masks_of(name)
            T = np.asarray(m['tris'])[first:first + count]
            if tex is None or not len(T) or m.get('nrm') is None:
                continue
            A = _read_ao(tex); h, w = A.shape; pages.add(Path(tex).name)
            P = np.asarray(m['pos'], float)[T]; UV = np.asarray(m['uv'], float)[:, :2][T]; N = np.asarray(m['nrm'], float)[T].mean(1)
            ar = np.linalg.norm(np.cross(P[:, 1] - P[:, 0], P[:, 2] - P[:, 0]), axis=1) / 2; ln = np.linalg.norm(N, axis=1)
            ok = (ar > 1e-7) & (ln > 1e-6); P, UV, N, ar = P[ok], UV[ok], N[ok] / ln[ok][:, None], ar[ok]; total += ar.sum()
            sp = np.einsum('sk,tkc->tsc', BARY, P); su = np.einsum('sk,tkc->tsc', BARY, UV)
            px = np.clip((su[..., 0] * w).astype(int) % w, 0, w - 1); py = np.clip((su[..., 1] * h).astype(int) % h, 0, h - 1)
            ti, si = np.where((A[py, px] < DARK) & (N[:, 1] > -.7)[:, None])           # faces turned to the ground: hidden
            if not len(ti):
                continue
            c = sp[ti, si] + N[ti] * .03; n = N[ti]
            d = np.where((n @ DIRS.T)[..., None] < 0, -DIRS[None], DIRS[None])
            Q = c[:, None, None, :] + d[:, :, None, :] * STEPS[None, None, :, None]
            hit = (tree.query(Q.reshape(-1, 3), distance_upper_bound=.015)[0].reshape(len(ti), 16, len(STEPS)) < .015) | (Q[..., 1] < 0)
            e = 1 - hit.any(2).mean(1)                        # the terrain blocks too
            keys += [f'{tex}|{x // CELL}|{y // CELL}' for x, y in zip(px[ti, si], py[ti, si])]
            expo += e.tolist(); area += (ar[ti] / NS).tolist(); where += np.round(c, 1).tolist()
    grp = {}
    for i, k in enumerate(keys):
        grp.setdefault(k, []).append(i)
    bad, spots = 0., {}
    for ii in grp.values():
        e = [expo[i] for i in ii]
        if max(e) - min(e) >= RANGE and max(e) >= OPEN:
            for i in ii:
                if expo[i] >= min(e) + RANGE:
                    bad += area[i]; k = tuple(np.round(np.array(where[i]) * 2) / 2); spots[k] = spots.get(k, 0) + area[i]
    top = sorted(spots.items(), key=lambda x: -x[1])[:5]
    return dict(conflict_m2=round(bad, 4), area_m2=round(total, 1), pages=sorted(pages),
                top=[dict(at=list(k), m2=round(v, 4)) for k, v in top])


def page_limit(path, prof):
    """Apply an existing owner acceptance only to its exact named texture bytes.

    An accepted shared dependency must not raise the ceiling for new own pages.
    Missing provenance or a changed hash is an error, not a fallback acceptance.
    """
    base = float(prof.get('ao_shared_uv_max_m2', .5))
    entries = prof.get('ao_shared_uv_accepted_pages', [])
    matches = [e for e in entries if e.get('file') == Path(path).name]
    if not matches:
        return base, None
    if len(matches) != 1:
        raise ValueError('duplicate AO page acceptance: ' + Path(path).name)
    e = matches[0]
    required = ('sha256', 'max_m2', 'owner_quote', 'date', 'source_acceptance')
    if any(not e.get(k) for k in required):
        raise ValueError('incomplete owner AO acceptance: ' + Path(path).name)
    if hashlib.sha256(Path(path).read_bytes()).hexdigest() != e['sha256']:
        raise ValueError('accepted AO page hash changed: ' + Path(path).name)
    limit = float(e['max_m2'])
    if not math.isfinite(limit) or limit < 0:
        raise ValueError('invalid accepted AO limit')
    return limit, {k: e[k] for k in ('owner_quote', 'date', 'source_acceptance', 'sha256')}


def check(stage, info, mat_path, art_root, prof, read_material, resolve_texture, R):
    """gr2_lint entry: R(stage, 'ao_shared_uv', ok, summary, **data)"""
    try:
        subs = {str(s['name']).lower(): s for s in read_material(mat_path)} if mat_path and Path(mat_path).exists() else {}
    except Exception as e:
        return R(stage, 'ao_shared_uv', None, f'material unreadable ({type(e).__name__})')

    def masks_of(name):
        t = ((subs.get(str(name).lower()) or {}).get('textures') or {}).get('Masks')
        if not t:
            return None
        r = resolve_texture(t, art_root)
        return r['file'] if r.get('src') == 'mod' and str(r['file']).lower().endswith('.ddt') else None
    names = sorted({str(m['mats'][mi]) for m in info['render'] for mi, _, _ in m['groups'] if 0 <= mi < len(m['mats'])})
    pages = {}
    for nm in names:
        f = masks_of(nm)
        if f:
            pages.setdefault(f, []).append(nm)
    if not pages:
        return R(stage, 'ao_shared_uv', None, 'no mod Masks page bound')
    lim = float(prof.get('ao_shared_uv_max_m2', .5)); per = {}; limits = {}; acceptances = {}
    try:
        for f, mats in pages.items():                     # per page: one bake, one verdict
            limit, acceptance = page_limit(f, prof)
            limits[Path(f).stem] = limit
            if acceptance:
                acceptances[Path(f).stem] = acceptance
            per[Path(f).stem] = measure(info, lambda n, f=f, mats=mats: f if n in mats else None)
    except ValueError as e:
        return R(stage, 'ao_shared_uv', False, f'invalid AO page acceptance ({e})')
    except Exception as e:                                # never crash the lint; an unmeasured AO is not a pass
        return R(stage, 'ao_shared_uv', None, f'not measured ({type(e).__name__}: {e})')
    bad = {k: v for k, v in per.items() if v['conflict_m2'] > limits[k]}
    worst = max(per.items(), key=lambda kv: kv[1]['conflict_m2'])
    where = '; '.join(f"{t_['m2']} m2 at {t_['at']}" for t_ in worst[1]['top'][:3])
    return R(stage, 'ao_shared_uv', not bad, f"open faces carrying another instance's baked AO (shared UV islands, Masks.R), max {lim} m2 per "
             f"page: " + ', '.join(f"{k} {v['conflict_m2']}" for k, v in sorted(per.items(), key=lambda kv: -kv[1]['conflict_m2']))
             + (f" | worst at {where}" if where and worst[1]['conflict_m2'] > 0 else '')
             + (f" | hash-pinned owner acceptances: " + ', '.join(f'{k} <= {limits[k]}' for k in acceptances) if acceptances else ''),
             pages={k: dict(conflict_m2=v['conflict_m2'], max_m2=limits[k], top=v['top'], acceptance=acceptances.get(k)) for k, v in per.items()})
