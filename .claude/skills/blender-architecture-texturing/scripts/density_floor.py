"""Universal UV texel-density floor: a HARD gate for every model of every project (owner, 2026-09-30).

Rule (../references/uv-density-floor.md); the numbers per game are in ../references/uv-density-floor.json:
  a model_median  the model's area-weighted median density >= model_median_min
  b face_floor    at most face_max_share_below of the textured 3D area lies below face_floor, for the whole model AND
                  for every page on its own (a scattered map of small, shrunken islands fails here)
  c collapsed     faces parked on no texels (zero UV area, or below 1 t/u) hold at most collapsed_max_share of the area
  b+c untextured  the area below face_floor and the collapsed area TOGETHER hold at most untextured_max_share (INC-035:
                  1.9 % below plus 2.9 % collapsed passed b and c one by one)
density(face) = sqrt(UV area in texels^2 / 3D area in model units^2); W x H = the page the face samples (the KTC-021 /
INC-002 forensic unit). Percentiles are 3D-area weighted. Faces with zero 3D area are counted, never measured.
Dilution-proof (INC-035): the shares of b and b+c count each texel region once. A face whose UVs sit on texels a larger
face already covers (a stack) adds no texture, so its area does not enter the denominator; faces below the floor and
collapsed faces always count in full. Hidden faces stacked on used texels therefore cannot turn a FAIL into a PASS.
Fragmentation (islands per 100 u2) is measured against a PROPOSED ceiling (uv-density-floor.json
"fragmentation_proposed"): a note, never a FAIL until the owner confirms it.

Hard: no tolerance below a number. A missing or stale measurement (another unit, an older schema) is INCOMPLETE, a FAIL
that nothing waives. An exception requires owner GO for the exact measured candidate and named runtime pages.
make_proposal() binds geometry/UV content, metrics, page dimensions and numeric policy. The owner's complete verified
message must match proposal_go(), or an authenticated owner decision must bind proposal_question() to its captured GO.
Omitted/empty/unknown page scope and keyword-only legacy waivers fail closed (INC-089). See uv-density-floor.md.


    python density_floor.py faces FACES.npz [--model NAME]    arrays P (n,3,3), UV (n,3,2), page (n,); names, W, H
                                                              (the block records source {file, sha256} of the input)
    python density_floor.py block FILE.json [--key density]   a recorded metrics block (the 03_uv HANDOFF "density")
    python density_floor.py gr2 MODEL.gr2 [--material M]      AoE3DE: through Age of Pirates scripts/havok/gr2_lint.py
    common: [--game G] [--config JSON] [--waivers JSON --owner-messages JSON] [--json]
Exit 0 PASS or WAIVED, 1 FAIL, 2 the input or the config cannot be read. numpy only; writes nothing.
"""
import argparse
import hashlib
import json
import math
import re
import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from uv_metrics import weighted_quantile  # noqa: E402

CONFIG = HERE.parent / 'references' / 'uv-density-floor.json'
NUMBERS = ('model_median_min', 'face_floor', 'face_max_share_below', 'collapsed_max_share', 'face_max_share_below_owned',
           'untextured_max_share', 'untextured_max_share_owned')
SCHEMA = 3                # 2 = dilution-proof shares; 3 = unrounded gate metrics (INC-089)
OWN_GRID = 256            # cells per page side at most for the texel-ownership raster (8 texels on a 2048 page)
FLOOR_WORDS = re.compile(r'(?<![\w-])(?:density|dpi|texels?|t/u)(?![\w-])', re.I)
CHECK = 'density_floor'
ZERO_3D = 1e-8            # model units^2: a degenerate triangle, not a surface
COLLAPSED_T = 1.0         # t/u: one texel stretched over more than a unit = a face parked on a texel or a line


class FloorError(ValueError):
    """the config or the input cannot be read: exit 2, never a pass"""


def _num(x):
    return isinstance(x, (int, float)) and not isinstance(x, bool) and math.isfinite(x)


def load_floor(game=None, path=None):
    """the floor numbers of one game -> dict(game, config, unit, model_median_min, face_floor, ...)"""
    p = Path(path or CONFIG)
    try:
        doc = json.loads(p.read_text(encoding='utf-8'))
    except (OSError, ValueError) as e:
        raise FloorError(f'density floor config {p}: {type(e).__name__}: {e}') from e
    g = game or doc.get('default_game')
    f = (doc.get('games') or {}).get(g) if isinstance(doc, dict) else None
    if not isinstance(f, dict):
        raise FloorError(f'{p}: no floor numbers for game {g!r}')
    bad = [k for k in NUMBERS if not _num(f.get(k)) or f[k] < 0 or (k.endswith('share') or 'share_' in k) and f[k] > 1]
    if bad:
        raise FloorError(f'{p}: game {g}: {", ".join(bad)} missing or out of range')
    return dict(game=g, config=str(p), unit=f.get('unit'), **{k: float(f[k]) for k in NUMBERS})


def load_fragmentation(game=None, path=None):
    """the PROPOSED fragmentation ceiling of one game (INC-035) -> {islands_per_100u2_max, status, basis} or {}: a
    note until the owner confirms it (status 'confirmed' + confirmed_by), never a rule of its own here"""
    p = Path(path or CONFIG)
    try:
        doc = json.loads(p.read_text(encoding='utf-8'))
        f = (doc.get('games') or {}).get(game or doc.get('default_game')) or {}
        fr = f.get('fragmentation_proposed') or {}
        return fr if _num(fr.get('islands_per_100u2_max')) else {}
    except (OSError, ValueError, AttributeError):
        return {}


# ------------------------------------------------------------------------------------------------------ measuring
def face_density(P, UV, W, H):
    """per triangle: 3D area, UV area in texels^2, density t/u (the forensic block, vectorised)"""
    P, UV = np.asarray(P, float), np.asarray(UV, float)
    a3 = 0.5 * np.linalg.norm(np.cross(P[:, 1] - P[:, 0], P[:, 2] - P[:, 0]), axis=1)
    u1, u2 = UV[:, 1] - UV[:, 0], UV[:, 2] - UV[:, 0]
    tex2 = 0.5 * np.abs(u1[:, 0] * u2[:, 1] - u1[:, 1] * u2[:, 0]) * float(W) * float(H)
    with np.errstate(invalid='ignore', divide='ignore'):
        dens = np.sqrt(tex2 / np.maximum(a3, 1e-30))
    return a3, tex2, dens


class _UF:
    def __init__(self, n):
        self.p = np.arange(n)

    def f(self, a):
        p, r = self.p, a
        while p[r] != r:
            r = p[r]
        while p[a] != r:
            p[a], a = r, p[a]
        return r

    def u(self, a, b):
        a, b = self.f(a), self.f(b)
        if a != b:
            self.p[a] = b


def islands(P, UV):
    """island label per triangle: triangles sharing an edge with identical position AND UV at both ends (KTC-021)"""
    n = len(P)
    if not n:
        return np.zeros(0, np.int64)
    uf = _UF(n)
    key = np.concatenate([np.round(np.asarray(P, float) / 1e-4), np.round(np.nan_to_num(UV) / 1e-5)], axis=2)
    vid = np.unique(key.reshape(-1, 5).astype(np.int64), axis=0, return_inverse=True)[1].reshape(n, 3)
    edges = {}
    for t in range(n):
        a, b, c = vid[t]
        for e in ((a, b), (b, c), (c, a)):
            k = (e[0], e[1]) if e[0] < e[1] else (e[1], e[0])
            j = edges.setdefault(k, t)
            if j != t:
                uf.u(t, j)
    return np.array([uf.f(t) for t in range(n)])


def owned_fraction(UV, a3, W, H, grid=OWN_GRID, chunk=4_000_000):
    """per triangle: the share of the page cells it covers that it OWNS (INC-035). The page is rasterised at most
    `grid` cells per side; the largest 3D face covering a cell owns it, so a face stacked on texels another face
    already uses owns nothing (it adds no texture). UVs wrap (the texture repeats); a face whose UV box spans more cells
    than the page holds owns at most one page's worth. A face that covers no cell centre (smaller than a cell) owns
    itself: it cannot add measurable area, and faces that only touch along an edge never conflict."""
    UV = np.nan_to_num(np.asarray(UV, float))
    a3 = np.asarray(a3, float)
    n = len(UV)
    if not n:
        return np.zeros(0)
    gx, gy = max(1, int(min(W, grid))), max(1, int(min(H, grid)))
    q = UV * [gx, gy]
    lo = np.floor(q.min(1)).astype(np.int64)
    hi = np.floor(q.max(1)).astype(np.int64)
    w, h = hi[:, 0] - lo[:, 0] + 1, hi[:, 1] - lo[:, 1] + 1
    cells = w * h
    big = cells > gx * gy
    faces, keys = [np.zeros(0, np.int64)], [np.zeros(0, np.int64)]
    small = np.flatnonzero(~big)
    ends = np.cumsum(cells[small])
    start = 0
    while start < len(small):                                      # bounded memory: chunks of candidate cells
        stop = int(np.searchsorted(ends, (ends[start - 1] if start else 0) + chunk, side='right'))
        idx = small[start:max(stop, start + 1)]
        start = max(stop, start + 1)
        k = cells[idx]
        f = np.repeat(idx, k)
        off = np.arange(int(k.sum())) - np.repeat(np.cumsum(k) - k, k)
        cx = lo[f, 0] + off % w[f]
        cy = lo[f, 1] + off // w[f]
        px, py = cx + 0.5, cy + 0.5
        t = q[f]
        d1 = (px - t[:, 1, 0]) * (t[:, 0, 1] - t[:, 1, 1]) - (t[:, 0, 0] - t[:, 1, 0]) * (py - t[:, 1, 1])
        d2 = (px - t[:, 2, 0]) * (t[:, 1, 1] - t[:, 2, 1]) - (t[:, 1, 0] - t[:, 2, 0]) * (py - t[:, 2, 1])
        d3 = (px - t[:, 0, 0]) * (t[:, 2, 1] - t[:, 0, 1]) - (t[:, 2, 0] - t[:, 0, 0]) * (py - t[:, 0, 1])
        inside = ~(((d1 < 0) | (d2 < 0) | (d3 < 0)) & ((d1 > 0) | (d2 > 0) | (d3 > 0)))
        faces.append(f[inside])
        keys.append((cy[inside] % gy) * gx + (cx[inside] % gx))
    face, key = np.concatenate(faces), np.concatenate(keys)
    pair = np.unique(face * (gx * gy) + key)                       # one entry per (face, cell)
    face, key = pair // (gx * gy), pair % (gx * gy)
    rank = np.empty(n, np.int64)
    rank[np.argsort(-a3, kind='stable')] = np.arange(n)           # the largest face owns a shared cell
    order = np.lexsort((rank[face], key))
    k_s, f_s = key[order], face[order]
    first = np.ones(len(k_s), bool)
    first[1:] = k_s[1:] != k_s[:-1]
    owner = f_s[np.maximum.accumulate(np.where(first, np.arange(len(k_s)), 0))]
    covered = np.bincount(f_s, minlength=n).astype(float)
    owned = np.bincount(f_s[f_s == owner], minlength=n).astype(float)
    frac = np.where(covered > 0, owned / np.maximum(covered, 1), 1.0)
    frac[big] = (gx * gy) / cells[big]
    return frac


def _stats(d, w, floor):
    q = [weighted_quantile(d, w, x) for x in (.02, .1, .5, .9)]
    # Store full precision: rounding before comparison silently tolerates a failing boundary.
    return dict(p2=float(q[0]), p10=float(q[1]), p50=float(q[2]), p90=float(q[3]),
                min_face=float(d.min()),
                share_below_face_floor=float(w[d < floor['face_floor']].sum() / w.sum()))


def measure(groups, floor, exempt=()):
    """groups: [{page, W, H, P (n,3,3), UV (n,3,2)}]; W or H None = the page size is unknown (not measured: INCOMPLETE).
    exempt: page names left out by the owner's waiver. -> the metrics block (the 03_uv HANDOFF "density" shape)"""
    rows = {}
    candidate = hashlib.sha256()
    unmeasured, ex, zero3 = {}, {}, 0
    for gr in groups:
        name, P = str(gr['page']), np.asarray(gr['P'], float)
        if not len(P):
            continue
        candidate.update(json.dumps([name, gr.get('W'), gr.get('H')], sort_keys=True).encode())
        for values in (P, gr.get('UV')):
            values = np.asarray(values, dtype='<f8')
            candidate.update(str(values.shape).encode())
            candidate.update(values.tobytes())
        if name in exempt:
            e = ex.setdefault(name, dict(faces=0, area3d=0.0))
            e['faces'] += len(P)
            e['area3d'] += float(face_density(P, np.zeros((len(P), 3, 2)), 1, 1)[0].sum())
            continue
        if not (_num(gr.get('W')) and _num(gr.get('H')) and gr['W'] > 0 and gr['H'] > 0):
            e = unmeasured.setdefault(name, dict(faces=0, area3d=0.0, why=gr.get('why') or 'page size unknown'))
            e['faces'] += len(P)
            e['area3d'] += float(face_density(P, np.zeros((len(P), 3, 2)), 1, 1)[0].sum())
            continue
        UV = np.asarray(gr['UV'], float) if gr.get('UV') is not None else np.full((len(P), 3, 2), np.nan)
        a3, tex2, dens = face_density(P, UV, gr['W'], gr['H'])
        r = rows.setdefault(name, dict(W=int(gr['W']), H=int(gr['H']), P=[], UV=[], a3=[], d=[]))
        r['P'].append(P), r['UV'].append(UV), r['a3'].append(a3), r['d'].append(dens)
    out = dict(schema=SCHEMA, game=floor['game'], unit=floor.get('unit'), face_floor=floor['face_floor'], pages={},
               unmeasured={k: dict(v, area3d=round(v['area3d'], 4)) for k, v in unmeasured.items()},
               exempt={k: dict(v, area3d=round(v['area3d'], 4)) for k, v in ex.items()})
    D, A, COL, NI = [], [], 0.0, 0
    col_faces, inc_area = 0, 0.0
    LOW, OWN_OK, OK = 0.0, 0.0, 0.0
    ff = floor['face_floor']
    for name, r in rows.items():
        P, UV = np.concatenate(r['P']), np.concatenate(r['UV'])
        a3, d = np.concatenate(r['a3']), np.concatenate(r['d'])
        z = a3 < ZERO_3D
        zero3 += int(z.sum())
        col = ~z & (~np.isfinite(d) | (d < COLLAPSED_T))
        inc = ~z & ~col
        low, ok = inc & (d < ff), inc & ~(d < ff)
        own = owned_fraction(UV, a3, r['W'], r['H'])
        p_low, p_ok, p_own = float(a3[low].sum()), float(a3[ok].sum()), float((a3 * own)[ok].sum())
        LOW, OK, OWN_OK = LOW + p_low, OK + p_ok, OWN_OK + p_own
        col_faces += int(col.sum())
        COL += float(a3[col].sum())
        inc_area += float(a3[inc].sum())
        pg = dict(W=r['W'], H=r['H'], faces=int(len(a3)), area3d=round(float(a3[~z].sum()), 4),
                  measured_faces=int(inc.sum()), collapsed_faces=int(col.sum()), zero_area_faces=int(z.sum()))
        if inc.any():
            pg.update(_stats(d[inc], a3[inc], floor))
            pg['share_below_face_floor_owned'] = p_low / max(p_low + p_own, 1e-30)   # dilution-proof
            pg['stacked_share'] = round(1 - p_own / p_ok, 6) if p_ok else 0.0
            n_isl = len(np.unique(islands(P[inc], UV[inc])))
            NI += n_isl
            pg.update(islands=n_isl, islands_per_100u2=round(100 * n_isl / max(float(a3[inc].sum()), 1e-12), 1))
            D.append(d[inc]), A.append(a3[inc])
        out['pages'][name] = pg
    total = inc_area + COL
    for pg in out['pages'].values():
        pg['area_share'] = round(pg['area3d'] / total, 4) if total else None
    out['faces'] = int(sum(p['faces'] for p in out['pages'].values()))
    out['zero_area_faces'] = zero3
    out['collapsed'] = dict(faces=col_faces, area3d=round(COL, 4), share=COL / total if total else None)
    den = LOW + COL + OWN_OK
    out['untextured'] = dict(area3d=round(LOW + COL, 4), share=(LOW + COL) / total if total else None,
                             share_owned=(LOW + COL) / den if den else None)
    if D:
        d, a = np.concatenate(D), np.concatenate(A)
        out['model'] = dict(faces=int(len(d)), area3d=round(float(a.sum()), 4), **_stats(d, a, floor), islands=NI,
                            islands_per_100u2=round(100 * NI / float(a.sum()), 1))
        out['model']['share_below_face_floor_owned'] = LOW / max(LOW + OWN_OK, 1e-30)
        out['model']['stacked_share'] = round(1 - OWN_OK / OK, 6) if OK else 0.0
    else:
        out['model'] = dict(faces=0, area3d=0.0)
    out['candidate_sha256'] = candidate.hexdigest()
    return out


# ------------------------------------------------------------------------------------------------------ the rule
def rules(m, floor):
    """-> list of findings {rule, page, text, incomplete}; empty = PASS"""
    bad = []

    def inc(text):
        bad.append(dict(rule='incomplete', page=None, text='INCOMPLETE: ' + text, incomplete=True))
    if not isinstance(m, dict):
        inc('no density block recorded')
        return bad
    ff = m.get('face_floor')
    if not _num(ff) or abs(ff - floor['face_floor']) > 1e-9:
        inc(f"measured against a face floor of {ff}, the {floor['game']} floor is {floor['face_floor']}: measure again")
    if not _num(m.get('schema')) or m['schema'] < SCHEMA:
        inc(f"measured with schema {m.get('schema')} (needs dilution-proof shares and unrounded gate metrics; now {SCHEMA}): "
            'measure again')
    if m.get('unit') != floor.get('unit') or m.get('game') != floor['game']:
        inc(f"measured in unit {m.get('unit')!r} for game {m.get('game')!r}, the {floor['game']} floor is in "
            f"{floor.get('unit')!r}: measure again")
    mod = m.get('model') if isinstance(m.get('model'), dict) else {}
    missing = [k for k in ('p50', 'share_below_face_floor', 'share_below_face_floor_owned') if not _num(mod.get(k))]
    if missing:
        inc(f"no measured model {' / '.join(missing)} (no textured face measured, or not recorded)")
    col = (m.get('collapsed') or {}).get('share') if isinstance(m.get('collapsed'), dict) else None
    if not _num(col):
        inc('no measured collapsed-face share')
    unt = m.get('untextured') if isinstance(m.get('untextured'), dict) else {}
    if not (_num(unt.get('share')) and _num(unt.get('share_owned'))):
        inc('no measured untextured (b + c) share')
    if m.get('unmeasured'):
        inc('page size unknown, faces not measured: ' + ', '.join(
            f"{k} ({v.get('faces')} faces, {v.get('why')})" for k, v in sorted(m['unmeasured'].items())))
    pages = m.get('pages') if isinstance(m.get('pages'), dict) else {}
    if not pages:
        inc('no measured page inventory')
    for name, pg in sorted(pages.items()):
        if not isinstance(pg, dict):
            inc(f'page {name}: no measured page record')
            continue
        if any(not _num(pg.get(k)) or pg[k] <= 0 or int(pg[k]) != pg[k] for k in ('W', 'H')):
            inc(f'page {name}: page size unknown or invalid')
        count_keys = ('faces', 'measured_faces', 'collapsed_faces')
        zero_count = pg.get('zero_area_faces', 0)
        if not isinstance(zero_count, int) or isinstance(zero_count, bool) or zero_count < 0:
            inc(f'page {name}: invalid zero-area face count')
            zero_count = 0
        if any(not isinstance(pg.get(k), int) or isinstance(pg[k], bool) or pg[k] < 0 for k in count_keys):
            inc(f'page {name}: missing or invalid face counts')
        elif pg['faces'] <= 0 or pg['measured_faces'] + pg['collapsed_faces'] + zero_count != pg['faces']:
            inc(f'page {name}: inconsistent face counts')
        if not isinstance(pg, dict) or (pg.get('measured_faces', 1) and not (
                _num(pg.get('share_below_face_floor')) and _num(pg.get('share_below_face_floor_owned')))):
            inc(f'page {name}: no measured share below the face floor')
        for key in ('share_below_face_floor', 'share_below_face_floor_owned'):
            if pg.get('measured_faces') and _num(pg.get(key)) and not 0 <= pg[key] <= 1:
                inc(f'page {name}: invalid {key}')
    for label, value in [('collapsed', col), ('untextured', unt.get('share')),
                         ('untextured owned', unt.get('share_owned')),
                         *[(key, mod.get(key)) for key in ('share_below_face_floor', 'share_below_face_floor_owned')]]:
        if _num(value) and not 0 <= value <= 1:
            inc(f'{label}: share must be between zero and one')
    if any(b['incomplete'] for b in bad):
        return bad
    lim, fl, mx = floor['model_median_min'], floor['face_floor'], floor['face_max_share_below']
    if mod['p50'] < lim:
        bad.append(dict(rule='model_median', page=None, incomplete=False,
                        text=f"a model median {mod['p50']:.1f} t/u is below {lim:g}"))
    mo = floor['face_max_share_below_owned']
    own = ' of the texel-owning area (each stack of faces on the same texels counted once, INC-035)'
    if mod['share_below_face_floor'] > mx:
        bad.append(dict(rule='face_floor', page=None, incomplete=False,
                        text=f"b {mod['share_below_face_floor'] * 100:.2f} % of the model area is below {fl:g} t/u "
                             f"(max {mx * 100:g} %, p2 {mod.get('p2')})"))
    elif mod['share_below_face_floor_owned'] > mo:
        bad.append(dict(rule='face_floor', page=None, incomplete=False,
                        text=f"b {mod['share_below_face_floor_owned'] * 100:.2f} %{own} is below {fl:g} t/u (max "
                             f"{mo * 100:g} %)"))
    for name, pg in sorted(pages.items()):
        s = pg.get('share_below_face_floor') if isinstance(pg, dict) else None
        so = pg.get('share_below_face_floor_owned') if isinstance(pg, dict) else None
        if _num(s) and s > mx:
            bad.append(dict(rule='face_floor', page=name, incomplete=False,
                            text=f"b page {name}: {s * 100:.2f} % of its area below {fl:g} t/u (max {mx * 100:g} %, "
                                 f"p50 {pg.get('p50')})"))
        elif _num(so) and so > mo:
            bad.append(dict(rule='face_floor', page=name, incomplete=False,
                            text=f"b page {name}: {so * 100:.2f} %{own} below {fl:g} t/u (max {mo * 100:g} %)"))
    if col > floor['collapsed_max_share']:
        bad.append(dict(rule='collapsed', page=None, incomplete=False,
                        text=f"c {col * 100:.2f} % of the area on collapsed UVs (max {floor['collapsed_max_share'] * 100:g} %)"))
    if unt['share'] > floor['untextured_max_share']:
        bad.append(dict(rule='untextured', page=None, incomplete=False,
                        text=f"b+c {unt['share'] * 100:.2f} % of the area below {fl:g} t/u or on collapsed UVs together "
                             f"(max {floor['untextured_max_share'] * 100:g} %)"))
    elif unt['share_owned'] > floor['untextured_max_share_owned']:
        bad.append(dict(rule='untextured', page=None, incomplete=False,
                        text=f"b+c {unt['share_owned'] * 100:.2f} %{own} below {fl:g} t/u or on collapsed UVs "
                             f"(max {floor['untextured_max_share_owned'] * 100:g} %)"))
    return bad


def summary(m, floor):
    m = m if isinstance(m, dict) else {}
    mod = m.get('model') if isinstance(m.get('model'), dict) else {}
    col = m.get('collapsed') if isinstance(m.get('collapsed'), dict) else {}
    unt = m.get('untextured') if isinstance(m.get('untextured'), dict) else {}
    parts = [f"a median {mod.get('p50')} t/u (min {floor['model_median_min']:g})",
             f"b {_pct(mod.get('share_below_face_floor'))} below {floor['face_floor']:g} t/u (max "
             f"{floor['face_max_share_below'] * 100:g} %, p2 {mod.get('p2')})",
             f"c collapsed {_pct(col.get('share'))} (max {floor['collapsed_max_share'] * 100:g} %)",
             f"b+c {_pct(unt.get('share'))} (max {floor['untextured_max_share'] * 100:g} %)"]
    if _num(mod.get('share_below_face_floor_owned')):
        parts.append(f"texel-owning area: b {_pct(mod['share_below_face_floor_owned'])} (max "
                     f"{floor['face_max_share_below_owned'] * 100:g} %), b+c {_pct(unt.get('share_owned'))} (max "
                     f"{floor['untextured_max_share_owned'] * 100:g} %), stacked {_pct(mod.get('stacked_share'))}")
    pages = m.get('pages') if isinstance(m.get('pages'), dict) else {}
    if pages:
        parts.append('pages ' + ', '.join(f"{k} {v.get('W')}: p50 {v.get('p50')} / {_pct(v.get('share_below_face_floor'))}"
                                          f" below" for k, v in sorted(pages.items()) if isinstance(v, dict)))
    if _num(mod.get('islands_per_100u2')):
        frag = load_fragmentation(floor['game'], floor.get('config'))
        parts.append(f"{mod['islands_per_100u2']} islands per 100 u2 (" + (
            f"proposed ceiling {frag['islands_per_100u2_max']:g}, {frag.get('status')}: info)" if frag else 'info)'))
    return '; '.join(parts)


def fragmentation_note(m, floor):
    """a note when the model is above the PROPOSED fragmentation ceiling (INC-035); never a finding"""
    mod = (m or {}).get('model') if isinstance((m or {}).get('model'), dict) else {}
    frag = load_fragmentation(floor['game'], floor.get('config'))
    x = mod.get('islands_per_100u2')
    if frag and _num(x) and x > frag['islands_per_100u2_max']:
        return (f"fragmentation: {x:g} islands per 100 u2 is above the proposed fragmentation ceiling "
                f"{frag['islands_per_100u2_max']:g} ({frag.get('status')}; not a FAIL)")
    return None


def _pct(x):
    return f'{x * 100:.2f} %' if _num(x) else 'not measured'


# ------------------------------------------------------------------------------------------------------ waivers
def norm(s):
    return ' '.join(str(s or '').lower().split())


def owner_messages(doc):
    """(id, text) of every stored owner message: a tracker {messages: {day: {items: [...]}}}, {items: [...]} or [...]"""
    if isinstance(doc, dict) and isinstance(doc.get('messages'), dict):
        items = [it for d in doc['messages'].values() for it in ((d.get('items') if isinstance(d, dict) else None) or [])]
    elif isinstance(doc, dict):
        items = doc.get('messages') if isinstance(doc.get('messages'), list) else doc.get('items') or []
    else:
        items = doc if isinstance(doc, list) else []
    for it in items:
        if isinstance(it, dict):
            yield it.get('id'), it.get('text')


def find_quote(doc, quote, msg=None):
    """the owner message whose WHOLE text is `quote` (whitespace and case ignored), or None (uv_gate.find_quote)"""
    q = norm(quote)
    if not q:
        return None
    for mid, text in owner_messages(doc):
        if (not msg or mid == msg) and q == norm(text):
            return mid
    return None


class OwnerStore:
    """the owner's message store (e.g. the task tracker's tasks.json): called as verify(quote, msg) -> the id of the
    message whose WHOLE text is the quote, or None; .text(id) and .decision(id) for the relevance checks (INC-036)"""

    def __init__(self, doc):
        self.doc = doc

    def __call__(self, quote, msg=None):
        return find_quote(self.doc, quote, msg)

    def text(self, mid):
        return next((t for i, t in owner_messages(self.doc) if mid and i == mid), None)

    def decision(self, did):
        """Authenticate a GO against the stored owner message and the answered question snapshot.

        A coordinator's option alone is not an owner answer. The question hash is recorded when the owner answers;
        changing a question/proposal later invalidates that answer. Short GO is usable through this explicit link.
        """
        d = (self.doc.get('decisions') or {}).get(did) if isinstance(self.doc, dict) else None
        if not isinstance(d, dict):
            return None
        rec, own = d.get('record') or {}, d.get('owner') or {}
        if not isinstance(rec, dict) or not isinstance(own, dict):
            return None
        question = d.get('question')
        text = self.text(rec.get('msg'))
        option = next((o for o in d.get('options') or [] if isinstance(o, dict) and o.get('key') == 'GO'), {})
        authentic = (isinstance(question, str) and rec.get('option') == 'GO' and norm(option.get('label')) == 'go'
                     and rec.get('at') and rec.get('source') == 'chat ' + str(rec.get('msg'))
                     and norm(text) in ('go', norm('GO ' + str(did))) and norm(rec.get('answer')) == norm(text)
                     and (not own.get('answer') or norm(own['answer']) == norm(text))
                     and rec.get('question_sha256') == hashlib.sha256(question.encode('utf-8')).hexdigest())
        return dict(answer=rec.get('option'), text=question, authenticated=bool(authentic),
                    proposal=d.get('density_proposal'), msg=rec.get('msg'), owner_quote=text)


def verifier(path):
    """a quote check against the owner's message store (e.g. the task tracker's tasks.json)"""
    return OwnerStore(json.loads(Path(path).read_text(encoding='utf-8')))


def names_model(text, model, aliases=()):
    """the text names the model: its name (underscores as spaces too) or one of its aliases, as whole words"""
    t = norm(text)
    names = [model, str(model or '').replace('_', ' '), *(aliases or ())]
    return any(n and re.search(r'(?<![\w-])' + re.escape(norm(n)) + r'(?![\w-])', t) for n in names)


def about_floor(text, model, aliases=()):
    """an owner text that decides THIS check for THIS model: it names the density floor and the model (INC-036)"""
    return bool(FLOOR_WORDS.search(str(text or ''))) and names_model(text, model, aliases)


def fingerprint(value):
    """Stable content binding, independent of JSON indentation or filesystem paths."""
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(',', ':'), allow_nan=False).encode()).hexdigest()


def make_proposal(metrics, floor, model, pages):
    """A reviewable exception proposal for exactly this measured candidate and these runtime pages.

    It is evidence, never approval. Regenerate after any candidate, measurement, dimensions or policy change.
    A consumer with old metrics lacking candidate_sha256 must remeasure before requesting an exception.
    """
    if any(f['incomplete'] for f in rules(metrics, floor)):
        raise FloorError('an incomplete measurement cannot support a density proposal')
    if not isinstance(model, str) or not model.strip():
        raise FloorError('a density proposal needs one model')
    if not (isinstance(pages, list) and pages and all(isinstance(p, str) and p for p in pages)
            and len(set(pages)) == len(pages) and set(pages) <= set(metrics['pages'])):
        raise FloorError('pages must be a nonempty unique list of actual measured pages; unknown pages never waive')
    candidate = metrics.get('candidate_sha256')
    if not isinstance(candidate, str) or not re.fullmatch('[0-9a-f]{64}', candidate):
        raise FloorError('the measurement lacks candidate_sha256: remeasure the geometry and UVs')
    return dict(schema=1, check=CHECK, model=model, candidate_sha256=candidate,
                metrics_sha256=fingerprint(metrics), floor_sha256=fingerprint({k: floor[k] for k in (*NUMBERS, 'game', 'unit')}),
                pages={p: {k: metrics['pages'][p].get(k) for k in ('W', 'H', 'p50', 'share_below_face_floor',
                                                                'share_below_face_floor_owned')} for p in sorted(pages)},
                model_median=metrics['model']['p50'], model_median_min=floor['model_median_min'], face_floor=floor['face_floor'])


def proposal_go(proposal):
    """Exact full-message approval form. Display the proposal and measured findings before asking for this GO."""
    pages = ', '.join(f'{p} {v["W"]}x{v["H"]}' for p, v in sorted(proposal['pages'].items()))
    return f'GO density_floor {proposal["model"]} pages {pages} proposal {fingerprint(proposal)}'


def proposal_question(proposal):
    """Canonical decision question; a stored short GO answers this exact question, never a later revision."""
    return (f'Allow this measured candidate below the density floor? {proposal_go(proposal)[3:]}. '
            f'Model median {proposal["model_median"]} t/u; minimum {proposal["model_median_min"]}; '
            f'face floor {proposal["face_floor"]} t/u. Answer GO or HOLD.')


def valid_waivers(waivers, verify, model=None, aliases=(), metrics=None, floor=None):
    """Validate scoped, candidate-bound GO evidence. Legacy callers remain fail-closed without metrics/floor.

    ``aliases`` is retained for API compatibility; the generated proposal uses canonical model/page identifiers.
    """
    ok, notes = [], []
    for w in waivers or []:
        if not isinstance(w, dict):
            continue
        checks = w.get('checks') if w.get('checks') is not None else [w.get('check')]
        if CHECK not in (checks if isinstance(checks, list) else [checks]):
            continue
        wid = w.get('id')
        reason = None
        if any(not isinstance(w.get(k), str) or not w[k].strip() for k in ('id', 'at', 'recorded_by', 'model')):
            reason = 'it needs id, at, recorded_by and one model'
        elif not model or w['model'] != model:
            reason = 'it does not name the current model'
        elif metrics is None or floor is None:
            reason = 'current measurement and floor are required'
        else:
            try:
                expected = make_proposal(metrics, floor, model, w.get('pages'))
                if w.get('proposal') != expected:
                    reason = 'proposal is missing or stale: candidate, measurement, page dimensions or policy changed'
            except (FloorError, ValueError, TypeError) as e:
                reason = str(e)
        if reason:
            notes.append(f'waiver {wid} ignored: {reason}')
            continue
        if w.get('decision'):
            dec = getattr(verify, 'decision', None)
            d = dec(w['decision']) if dec else None
            if not d or not d.get('authenticated') or d.get('answer') != 'GO' or w.get('option') != 'GO':
                notes.append(f'waiver {wid} ignored: no authenticated owner GO decision')
            elif d.get('proposal') != expected or d.get('text') != proposal_question(expected):
                notes.append(f'waiver {wid} ignored: the answered question does not bind this proposal')
            else:
                ok.append(dict(w, owner_quote=d['owner_quote'], msg=d['msg']))
            continue
        if not (w.get('owner_quote') and w.get('msg')):
            notes.append(f'waiver {wid} ignored: it needs owner_quote and msg')
        elif verify is None:
            notes.append(f"waiver {wid} ignored: no owner message store to verify its quote")
        elif not verify(w['owner_quote'], w.get('msg')):
            notes.append(f"waiver {wid} ignored: its quote is not the whole owner message {w.get('msg') or '(any)'} "
                         '(a fragment never waives)')
        elif norm(w['owner_quote']) != norm(proposal_go(expected)):
            notes.append(f'waiver {wid} ignored: owner message is not the explicit GO for this model and texture proposal')
        else:
            ok.append(w)
    return ok, notes


def evaluate(m, floor, waivers=(), verify=None, model=None, remeasure=None, aliases=()):
    """the hard gate on one model -> {status PASS | FAIL | WAIVED, summary, findings, metrics, waived_by, notes}.
    remeasure(pages) -> the metrics without those pages (raw faces only; a recorded block cannot leave pages out, so
    there a partial-page waiver clears only that page's own finding). aliases is kept for caller compatibility;
    new proposals always name the canonical model and pages."""
    found = rules(m, floor)
    frag = fragmentation_note(m, floor) if isinstance(m, dict) else None
    res = dict(status='FAIL' if found else 'PASS', summary=summary(m, floor), findings=found, metrics=m, waived_by=[],
               notes=[frag] if frag else [])
    if not found or any(f['incomplete'] for f in found):
        return res
    good, notes = valid_waivers(waivers, verify, model, aliases, metrics=m, floor=floor)
    res['notes'] += notes
    pages = sorted({str(p) for w in good for p in w.get('pages') or []})
    if not pages:
        return res
    used = [{k: w.get(k) for k in ('id', 'msg', 'at', 'pages')} for w in good if w.get('pages')]
    if set(pages) == set(m['pages']):
        # An explicit list of every measured page is scoped approval, unlike a missing/empty blanket waiver.
        left = []
    elif remeasure is not None:
        m2 = remeasure(pages)
        left = rules(m2, floor)
        res.update(metrics_with_exempt_pages=m2, findings_with_exempt_pages=left)
        res['summary'] += f" | owner-exempt pages {', '.join(pages)} left out: {summary(m2, floor)}"
    else:
        left = [f for f in found if not (f['page'] and f['page'] in pages)]
    # A resolution exception never authorizes broken UV coverage. Preserve the original
    # model-wide collapse result even if exempting its page makes the remeasurement pass.
    left += [f for f in found if f['rule'] == 'collapsed' and f not in left]
    if left:
        res['findings'] = left
        return res
    res.update(status='WAIVED', waived_by=used)
    res['summary'] += ' [WAIVED ' + ', '.join(f"{u['id']} {u.get('msg') or ''}".strip() for u in used) + ']'
    return res


# ------------------------------------------------------------------------------------------------------ inputs
def groups_from_npz(path):
    z = np.load(path, allow_pickle=False)
    names, W, H = [str(x) for x in z['names']], z['W'], z['H']
    page = np.asarray(z['page']).astype(str)
    return [dict(page=n, W=float(W[i]), H=float(H[i]), P=z['P'][page == n], UV=z['UV'][page == n])
            for i, n in enumerate(names)]


def file_sha256(path):
    import hashlib
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for b in iter(lambda: f.read(1 << 20), b''):
            h.update(b)
    return h.hexdigest()


def block_from_file(path, key='density'):
    doc = json.loads(Path(path).read_text(encoding='utf-8'))
    return doc.get(key) if isinstance(doc, dict) and key in doc else doc


def groups_from_gr2(path, material=None, art_root=None):
    """AoE3DE adapter: the Age of Pirates model lint reads the GR2 and the page sizes (.material + DDT headers)"""
    repo = HERE.parents[3]
    sys.path.insert(0, str(repo / 'scripts' / 'havok'))
    try:
        import gr2_lint
    except ImportError as e:
        raise FloorError(f'a GR2 needs the AoE3DE reader (Age of Pirates scripts/havok/gr2_lint.py): {e}; other engines '
                         'pass their faces (subcommand faces)') from e
    info = gr2_lint.read_raw(path)
    mat = Path(material) if material else Path(path).with_suffix('.material')
    return gr2_lint.density_groups(info, mat, art_root or gr2_lint.art_root_of(Path(path).parent))


def main(argv=None):
    ap = argparse.ArgumentParser(prog='density_floor.py', description=__doc__.splitlines()[0])
    ap.add_argument('kind', choices=('faces', 'block', 'gr2'))
    ap.add_argument('path')
    ap.add_argument('--game')
    ap.add_argument('--config', help='floor numbers (default ../references/uv-density-floor.json)')
    ap.add_argument('--key', default='density', help='block: the key holding the metrics block')
    ap.add_argument('--material', help='gr2: the .material (default: next to the model)')
    ap.add_argument('--model', help='the model name the waivers name')
    ap.add_argument('--waivers', help='JSON list of the recorded owner waivers')
    ap.add_argument('--owner-messages', help="the owner's message store the waiver quotes are checked against")
    ap.add_argument('--propose-pages', nargs='+', help='prepare candidate-bound exception evidence for these pages; never grants GO')
    ap.add_argument('--json', action='store_true')
    a = ap.parse_args(argv)
    try:
        floor = load_floor(a.game, a.config)
        remeasure = None
        if a.kind == 'block':
            m = block_from_file(a.path, a.key)
        else:
            groups = groups_from_npz(a.path) if a.kind == 'faces' else groups_from_gr2(a.path, a.material)
            m = measure(groups, floor)
            m['source'] = {'file': Path(a.path).name, 'sha256': file_sha256(a.path)}   # the handoff binds to it
            remeasure = lambda pages: measure(groups, floor, exempt=pages)  # noqa: E731
        waivers = json.loads(Path(a.waivers).read_text(encoding='utf-8')) if a.waivers else []
        verify = verifier(a.owner_messages) if a.owner_messages else None
    except (OSError, ValueError, KeyError) as e:
        print(f'density_floor: cannot read the input or the config ({type(e).__name__}): {e}', file=sys.stderr)
        return 2
    res = evaluate(m, floor, waivers, verify, a.model or Path(a.path).stem, remeasure)
    if a.propose_pages:
        try:
            proposal = make_proposal(m, floor, a.model or Path(a.path).stem, a.propose_pages)
            res.update(proposal=proposal, owner_go_text=proposal_go(proposal), decision_question=proposal_question(proposal))
        except FloorError as e:
            print(f'density_floor: cannot prepare proposal: {e}', file=sys.stderr)
            return 2
    if a.json:
        print(json.dumps(res, indent=1, default=str))
    else:
        print(f"UV density floor {res['status']} ({floor['game']}): {res['summary']}")
        for f in res['findings'] if res['status'] == 'FAIL' else []:
            print('  FAIL ' + f['text'])
        for n in res['notes']:
            print('  note ' + n)
        if res.get('proposal'):
            print('  PROPOSAL (not approval): ' + json.dumps(res['proposal'], sort_keys=True))
            print('  Owner GO text: ' + res['owner_go_text'])
    return 1 if res['status'] == 'FAIL' else 0


if __name__ == '__main__':
    if hasattr(sys.stdout, 'reconfigure'):
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    sys.exit(main())
