"""Export lint for AoE3DE building models (.gr2 + damaged .gr2 + .hkt + .material + animfile), against a VANILLA
reference profile. Every check prints PASS / FAIL / SKIP with its numbers. Exit 1 on any FAIL; exit 2 when nothing
FAILs but a check was SKIPPED (e.g. --no-dll, or the DLL tools are missing: the file is NOT proven to load in the game).
Only exit 0 clears a model for the owner's game test (AGENTS.md rule 13); --allow-skip turns exit 2 into 0 for local
iteration and is never used for that gate.

    python scripts/havok/gr2_lint.py --profile korean_tc art/buildings/korean_tc/
    python scripts/havok/gr2_lint.py --profile korean_tc --intact X.gr2 --damaged Y.gr2 [--hkt Z.hkt] [--json OUT]
    python scripts/havok/gr2_lint.py --measure-reference china_towncenter_age2.gr2   # numbers for a new profile

Why each check exists (every one is a defect that reached the game first):
  vertex_limit / wrap16   a damaged mesh is drawn with 16-bit indices: the 102,527-vertex single mesh of 2026-09-29
                          wrapped into building-high stretched sheets. Every bound mesh <= 65,535 vertices, max index
                          < 65,536, and a 16-bit wrap simulation changes 0 triangles.
  orientation             a 90-degree turn / mirror was found only in game. The display-frame quadrant of the flag
                          mast and of the open courtyard must equal the reference building's (China TC age 2: tower
                          back-right, courtyard front-left). Display frame = (-x_raw, -z_raw, y_raw), +X right,
                          +Y back, as rotate_gr2.py documents.
  handedness              a mirror that keeps the mast quadrant (a diagonal mirror) flips every UV chart: the
                          area-weighted majority of UV-chart handedness must have the profile's sign; optional
                          name-board faces (profile) must each read the right way.
  attach_bones / flag     bone_flag_civ, BONE_GARRISONFLAG, BONE_HITPOINTBAR present; the flag bone ON the model's
                          own mast axis (<= 2 cm) at the vanilla height below the tip (the pilot's flag hung 0.155 m
                          beside its pole).
  damaged_frame           the damaged model sits in the intact's frame: bbox, tip, attach bones.
  base_binding            every damaged render triangle is bound to a piece bone; the base (fixed) bone may carry
                          only the platform (below profile height) and declared props. Unallowed triangles are
                          grouped into connected elements and counted per kind (e.g. window panels).
  hkt_pairing             every GR2 piece bone has its Havok body at the profile's axis map / scale, and every
                          piece's render vertices lie inside its own convex hull.
  materials               mesh material bindings == the .material submaterials; referenced mod textures exist.
  crc / dll_read          header CRC valid; the game's Granny DLL reads the file (headless gr2_to_raw.py route:
                          rc 0 and a non-empty output). The DLL route also decodes Oodle-compressed files.
  animfile_crlf           the animfile the engine parses has CRLF endings (AGENTS.md rule 1).

Profiles: scripts/havok/gr2_lint_profiles.json ("references" = numbers measured on vanilla files; "profiles" = the
building's own design facts and tolerances). External tools (the DLL route) are found through the profile file's
"tools" entry or the GR2_LINT_TOOLS environment variable; when they are missing the DLL check is SKIP, never PASS.
Reads only; writes nothing next to the model (DLL outputs go to a temp folder).
"""
import argparse
import json
import os
import re
import struct
import subprocess
import sys
import tempfile
import uuid
import zlib
from collections import Counter, defaultdict
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from gr2_read import Gr2, MAGIC64, MAGIC32  # noqa: E402
from gr2_dump import refs  # noqa: E402

PROFILES = HERE / 'gr2_lint_profiles.json'
ATTACH = ('bone_flag_civ', 'BONE_GARRISONFLAG', 'BONE_HITPOINTBAR')
TYPE_NP = {10: '<f4', 11: 'i1', 12: 'u1', 13: 'i1', 14: 'u1', 15: '<i2', 16: '<u2', 17: '<i2', 18: '<u2', 19: '<i4',
           20: '<u4', 21: '<f2'}
TYPE_SCALE = {13: 127.0, 14: 255.0, 17: 32767.0, 18: 65535.0}
QUAD_NAMES = {'+X+Y': 'back-right', '-X+Y': 'back-left', '-X-Y': 'front-left', '+X-Y': 'front-right'}


# ---------------------------------------------------------------------------------------------------------- reading
def header(path):
    """magic / compression / CRC straight from the bytes (works on Oodle-compressed files too)."""
    d = Path(path).read_bytes()
    magic = d[:16]
    if magic not in (MAGIC64, MAGIC32):
        return dict(gr2=False, size=len(d))
    crc, sec_off, sec_count = struct.unpack_from('<I', d, 40)[0], *struct.unpack_from('<II', d, 44)
    table = 32 + sec_off
    comp = [struct.unpack_from('<I', d, table + 44 * i)[0] for i in range(sec_count)]
    sizes = [struct.unpack_from('<I', d, table + 44 * i + 8)[0] for i in range(sec_count)]
    return dict(gr2=True, size=len(d), bits=64 if magic == MAGIC64 else 32,
                compressed=any(c != 0 and s for c, s in zip(comp, sizes)),
                crc_stored=crc, crc_ok=(zlib.crc32(d[table:]) & 0xffffffff) == crc)


def _decode(buf, base, stride, nv, layout):
    out = {}
    for name, off, t, c in layout:
        if t not in TYPE_NP or nv == 0:
            continue
        dt = np.dtype(TYPE_NP[t]); c = max(c, 1)
        a = np.ndarray((nv, c), dt, buf, base + off, (stride, dt.itemsize)).astype(np.float64)
        out[name] = a / TYPE_SCALE[t] if t in TYPE_SCALE else a
    return out


def _mesh(name, loc, nv, comps, tris, groups, mats, bone_names, iw, layout):
    if 'BoneIndices' in comps:
        bi = comps['BoneIndices'].astype(np.int64)
        if bi.shape[1] > 1 and 'BoneWeights' in comps:
            bone = bi[np.arange(nv), comps['BoneWeights'].argmax(1)]
        else:
            bone = bi[:, 0]
    else:
        bone = np.zeros(nv, np.int64)                     # rigid mesh: every vertex on binding 0
    return dict(name=name, loc=loc, nv=int(nv), pos=comps.get('Position', np.zeros((nv, 3))),
                nrm=comps.get('Normal'), uv=comps.get('TextureCoordinates0'), bone=bone, bone_names=list(bone_names),
                tris=np.asarray(tris, np.int64).reshape(-1, 3), groups=[tuple(int(x) for x in gr) for gr in groups],
                mats=list(mats), index_width=iw, layout=layout)


def read_raw(path):
    """sectioned, uncompressed .gr2 (vanilla files, byte-level tool outputs) through the repo reader."""
    g = Gr2(str(path))
    r = g.root()
    out = dict(path=str(path), source='raw', materials=[rec['Name'] for rec, _ in refs(g, r['Materials'])],
               bones=[], meshes=[], models=[])
    sks = refs(g, r['Skeletons'])
    if sks:
        for b in g.array(sks[0][0]['Bones']):
            iw = np.array(b['InverseWorldTransform'], float).reshape(4, 4)
            out['bones'].append(dict(name=b['Name'], parent=b['ParentIndex'][0], world=np.linalg.inv(iw)))
    for rec, loc in refs(g, r['Models']):
        mb = rec['MeshBindings']
        locs = []
        if mb[0] == 'array':
            locs = [x['Mesh'][1] for x in g.array(mb)]
        elif mb[0] == 'refarray':
            locs = [x['Mesh'][1] if 'Mesh' in x else l for x, l in refs(g, mb)]
        out['models'].append(dict(name=rec['Name'], mesh_locs=[tuple(x) for x in locs if x]))
    for rec, loc in refs(g, r['Meshes']):
        vd = rec['PrimaryVertexData']
        vr = g.read(*vd[2], *vd[1])
        _, tp, nv, dp = vr['Vertices']
        lay_m, stride = g.layout(*tp)
        layout = [(m['name'], o, m['type'], m['count']) for m, o in lay_m]
        comps = _decode(g.payload[dp[0]], dp[1], stride, nv, layout) if nv else {}
        top = g.read(*rec['PrimaryTopology'][2], *rec['PrimaryTopology'][1])
        if top['Indices'][1]:
            (s, o), n, iw = top['Indices'][2], top['Indices'][1], 4
        else:
            (s, o), n, iw = top['Indices16'][2], top['Indices16'][1], 2
        tris = np.frombuffer(bytes(g.payload[s][o:o + n * iw]), '<i4' if iw == 4 else '<u2')
        groups = [(x['MaterialIndex'][0], x['TriFirst'][0], x['TriCount'][0]) for x in g.array(top['Groups'])]
        mats = []
        for x in g.array(rec['MaterialBindings']):
            ref = x['Material']
            mats.append(g.read(*ref[2], *ref[1])['Name'] if ref[1] else None)
        bbs = [x['BoneName'] for x in g.array(rec['BoneBindings'])]
        out['meshes'].append(_mesh(rec['Name'], tuple(loc), nv, comps, tris, groups, mats, bbs, iw, layout))
    _mark_bound(out)
    return out


def read_flat(path):
    """the flat 32-bit image the game's Granny DLL writes (gr2_to_raw.py): pointers are file offsets."""
    d = Path(path).read_bytes()
    g = Gr2.__new__(Gr2)                                  # gr2_read's typedef/layout machinery on one flat block
    g.data, g.ptr, g.payload, g.reloc = d, 4, [bytearray(d)], {}
    g.deref = lambda sec, off: ((0, struct.unpack_from('<I', d, off)[0]) if struct.unpack_from('<I', d, off)[0] else None)
    P = lambda off: struct.unpack_from('<I', d, off)[0]  # noqa: E731
    S = lambda off: g.cstr(0, P(off)) if P(off) else None  # noqa: E731
    out = dict(path=str(path), source='dll-flat', materials=[S(P(P(24) + 4 * i)) for i in range(P(20))],
               bones=[], meshes=[], models=[])
    for i in range(P(28)):
        so = P(P(32) + 4 * i)
        for k in range(P(so + 4)):
            bo = P(so + 8) + 152 * k
            iw = np.array(struct.unpack_from('<16f', d, bo + 76), float).reshape(4, 4)
            out['bones'].append(dict(name=S(bo), parent=struct.unpack_from('<i', d, bo + 4)[0], world=np.linalg.inv(iw)))
        break                                             # first skeleton, like read_raw
    for i in range(P(52)):
        mo = P(P(56) + 4 * i)
        vdo, tto = P(mo + 4), P(mo + 16)
        tp, nv, dp = P(vdo), P(vdo + 4), P(vdo + 8)
        lay_m, stride = g.layout(0, tp)
        layout = [(m['name'], o, m['type'], m['count']) for m, o in lay_m]
        comps = _decode(g.payload[0], dp, stride, nv, layout) if nv else {}
        groups = [struct.unpack_from('<3i', d, P(tto + 4) + 12 * k) for k in range(P(tto))]
        if P(tto + 8):
            tris, iw = np.frombuffer(d, '<i4', P(tto + 8), P(tto + 12)), 4
        else:
            tris, iw = np.frombuffer(d, '<u2', P(tto + 16), P(tto + 20)), 2
        mats = [S(P(P(mo + 24) + 4 * k)) for k in range(P(mo + 20))]
        bbs = [S(P(mo + 32) + 36 * k) for k in range(P(mo + 28))]
        out['meshes'].append(_mesh(S(mo), (0, mo), nv, comps, tris, groups, mats, bbs, iw, layout))
    for i in range(P(60)):
        mo = P(P(64) + 4 * i)
        out['models'].append(dict(name=S(mo), mesh_locs=[(0, P(P(mo + 80) + 4 * k)) for k in range(P(mo + 76))]))
    _mark_bound(out)
    return out


def _mark_bound(info):
    bound = {l for mo in info['models'] for l in mo['mesh_locs']}
    for m in info['meshes']:
        m['bound'] = m['loc'] in bound
    info['render'] = [m for m in info['meshes'] if m['bound']]


# ----------------------------------------------------------------------------------------------- DLL route (headless)
def dll_read(path, tdir, workdir):
    """run the game's granny2_age3de.dll on PATH (GrannyConvertFileToRaw, gr2_to_raw.py's hand-built exe under
    Wine/WSL) in a UNIQUE Linux work folder, so parallel users of gr2_to_raw never share in.gr2/out.gr2.
    -> dict(status PASS/FAIL/SKIP, rc, out_bytes, flat path)"""
    if tdir is None or not (Path(tdir) / 'gr2_to_raw.py').exists():
        return dict(status='SKIP', why=f'gr2_to_raw.py not found (tools dir {tdir}); set GR2_LINT_TOOLS')
    sys.path.insert(0, str(tdir))
    try:
        import gr2_to_raw as g2r
    finally:
        sys.path.pop(0)
    src = Path(path).resolve()
    dst = Path(workdir) / (src.stem + '_flat.gr2')
    exe = Path(workdir) / '_gr2lint_tool.exe'
    exe.write_bytes(g2r.build_exe())
    work = f'$HOME/gr2lint_{os.getpid()}_{uuid.uuid4().hex[:8]}'
    cmd = (f'set -e; unset DISPLAY WAYLAND_DISPLAY; export WINEDLLOVERRIDES=winedbg.exe=d WINEARCH=win32 '
           f'WINEPREFIX=$HOME/.wine_gxo WINEDEBUG=-all; mkdir -p {work}; cd {work}; '
           f'cp "{g2r.wsl_path(src)}" in.gr2; cp "{g2r.wsl_path(exe)}" gr2raw.exe; cp {g2r.DLL_LINUX} .; '
           f'set +e; timeout 300 wine ./gr2raw.exe >/dev/null 2>&1; rc=$?; set -e; echo "RC=$rc"; '
           f'if [ -f out.gr2 ]; then cp out.gr2 "{g2r.wsl_path(dst)}"; fi; cd /; rm -rf {work}')
    try:
        r = subprocess.run(['wsl.exe', '-d', g2r.DISTRO, '--exec', 'bash', '-c', cmd], capture_output=True, text=True,
                           timeout=400)
        rc = next((int(l[3:]) for l in r.stdout.splitlines() if l.startswith('RC=')), None)
        tail = (r.stdout[-300:] + r.stderr[-300:]).strip()
    except (OSError, subprocess.SubprocessError) as e:
        rc, tail = None, repr(e)
    n = dst.stat().st_size if dst.exists() else 0
    ok = rc == 0 and n > 0
    return dict(status='PASS' if ok else 'FAIL', rc=rc, out_bytes=n, flat=str(dst) if n else None,
                **({} if ok else {'tail': tail}))


def load(path, dll=None):
    """normalized model: raw files through the repo reader; compressed ones through the DLL flat image."""
    h = header(path)
    if not h.get('gr2'):
        raise ValueError(f'{path}: not a gr2')
    if not h['compressed']:
        info = read_raw(path)
    elif dll and dll.get('flat'):
        info = read_flat(dll['flat'])
    else:
        raise ValueError(f'{path}: Oodle-compressed and the DLL route is unavailable ({(dll or {}).get("why")})')
    info['header'] = h
    return info


# ------------------------------------------------------------------------------------------------------- measuring
def display(P):
    P = np.asarray(P, float)
    return np.stack([-P[..., 0], -P[..., 2], P[..., 1]], -1)


def world_pos(info):
    return {b['name']: b['world'][3, :3].copy() for b in info['bones']}


def render_positions(info):
    return np.concatenate([m['pos'] for m in info['render']]) if info['render'] else np.zeros((0, 3))


def mast(P):
    """the flag mast = the thin (< 0.2 m) column under the highest vertex (gr2_attach.py's measure, raw frame)."""
    tip = float(P[:, 1].max())
    c0 = P[P[:, 1] > tip - 0.3][:, [0, 2]].mean(0)
    thin = []
    for h0 in np.arange(tip - 4.0, tip, 0.05):
        s = P[(P[:, 1] >= h0) & (P[:, 1] < h0 + 0.05)]
        s = s[np.linalg.norm(s[:, [0, 2]] - c0, axis=1) < 0.35]
        if len(s) >= 3:
            ext = s[:, [0, 2]].max(0) - s[:, [0, 2]].min(0)
            if ext.max() < 0.2:
                thin.append((s[:, [0, 2]].max(0) + s[:, [0, 2]].min(0)) / 2)
    if not thin:
        return dict(tip=tip, axis_xz=None, slices=0)
    axis = np.mean(thin, 0)
    return dict(tip=tip, axis_xz=axis, slices=len(thin), spread=float(np.max(np.linalg.norm(np.array(thin) - axis, axis=1))))


def triangles(info, meshes=None):
    """-> (T (n,3,3) raw positions, UV (n,3,2) or None, mesh index, bone name) over the render meshes."""
    T, U, MI, BN = [], [], [], []
    for k, m in enumerate(meshes if meshes is not None else info['render']):
        t = m['tris']
        if not len(t):
            continue
        T.append(m['pos'][t])
        U.append(m['uv'][t] if m['uv'] is not None else np.full((len(t), 3, 2), np.nan))
        MI.append(np.full(len(t), k))
        names = np.array(m['bone_names'] + ['<none>'], dtype=object)
        b = m['bone'][t[:, 0]]
        BN.append(names[np.where((b >= 0) & (b < len(m['bone_names'])), b, len(m['bone_names']))])
    if not T:
        return np.zeros((0, 3, 3)), np.zeros((0, 3, 2)), np.zeros(0, int), np.zeros(0, object)
    return np.concatenate(T), np.concatenate(U), np.concatenate(MI), np.concatenate(BN)


def quadrant(x, y):
    return ('+X' if x >= 0 else '-X') + ('+Y' if y >= 0 else '-Y')


def layout_facts(info, roof_height):
    """display-frame layout: mast quadrant and the open-courtyard quadrant (least roof area above roof_height),
    both relative to the footprint centre (bbox centre in display X/Y)."""
    P = render_positions(info)
    D = display(P)
    lo, hi = D.min(0), D.max(0)
    c = (lo[:2] + hi[:2]) / 2
    ms = mast(P)
    res = dict(bbox_display=[lo.round(4).tolist(), hi.round(4).tolist()], centre_xy=c.round(4).tolist(),
               tip=round(ms['tip'], 4))
    if ms['axis_xz'] is not None:
        md = display(np.array([ms['axis_xz'][0], 0, ms['axis_xz'][1]]))[:2] - c
        res['mast_display_xy'] = md.round(4).tolist()
        res['mast_quadrant'] = quadrant(*md)
    T = display(triangles(info)[0])
    n = np.cross(T[:, 1] - T[:, 0], T[:, 2] - T[:, 0])
    area = np.linalg.norm(n, axis=1) / 2
    cen = T.mean(1)
    roof = (cen[:, 2] > roof_height) & (np.abs(n[:, 2]) > 0.3 * np.linalg.norm(n, axis=1))
    share = {}
    for q in QUAD_NAMES:
        sx, sy = (1 if q[0] == '+' else -1), (1 if q[2] == '+' else -1)
        sel = roof & (np.sign(cen[:, 0] - c[0]) == sx) & (np.sign(cen[:, 1] - c[1]) == sy)
        share[q] = float(area[sel].sum())
    tot = sum(share.values()) or 1.0
    res['roof_area_share'] = {q: round(v / tot, 4) for q, v in share.items()}
    res['courtyard_quadrant'] = min(share, key=share.get)
    return res


def uv_handedness(T, U, weights=None):
    """per-triangle UV chart handedness: +1 when the UV basis (dP/du, dP/dv) turns the same way as the triangle's
    own geometric normal (winding), -1 when the chart is mirrored. -> signs, areas"""
    e1, e2 = T[:, 1] - T[:, 0], T[:, 2] - T[:, 0]
    d1, d2 = U[:, 1] - U[:, 0], U[:, 2] - U[:, 0]
    det = d1[:, 0] * d2[:, 1] - d1[:, 1] * d2[:, 0]
    area = np.linalg.norm(np.cross(e1, e2), axis=1) / 2
    ok = np.isfinite(det) & (np.abs(det) > 1e-12) & (area > 1e-10)
    return np.where(ok, np.sign(det), 0), np.where(ok, area, 0)


def elements(T, key_round=3):
    """connected components of a triangle set (shared rounded vertex positions) -> list of index lists."""
    n = len(T)
    par = np.arange(n)

    def f(x):
        while par[x] != x:
            par[x] = par[par[x]]
            x = par[x]
        return x
    seen = {}
    for i in range(n):
        for v in np.round(T[i], key_round):
            k = tuple(v)
            j = seen.setdefault(k, i)
            if j != i:
                a, b = f(i), f(j)
                if a != b:
                    par[a] = b
    groups = defaultdict(list)
    for i in range(n):
        groups[f(i)].append(i)
    return list(groups.values())


def element_kind(T):
    """a flat vertical panel of <= 4 triangles and 0.3-8 m2 = a window/door panel (the S18k LOW models windows as
    single quads); otherwise 'geometry'."""
    n = np.cross(T[:, 1] - T[:, 0], T[:, 2] - T[:, 0])
    a = np.linalg.norm(n, axis=1)
    area = a.sum() / 2
    un = n / np.maximum(a[:, None], 1e-12)
    vertical = np.all(np.abs(un[:, 1]) < 0.1)
    planar = np.all(np.abs(un @ un[0]) > 0.99)
    if len(T) <= 4 and vertical and planar and 0.3 <= area <= 8.0:
        return 'window_panel'
    return 'geometry'


# ----------------------------------------------------------------------------------------------------------- checks
def R(stage, cid, ok, summary, **data):
    """one check result; ok None = SKIP"""
    return dict(stage=stage, check=cid, status='SKIP' if ok is None else ('PASS' if ok else 'FAIL'), summary=summary,
                data=data)


def _r(x, n=4):
    return np.round(np.asarray(x, float), n).tolist()


def check_crc(stage, info):
    h = info['header']
    return R(stage, 'crc', h['crc_ok'], f"stored {h['crc_stored']:#010x} {'matches' if h['crc_ok'] else 'DOES NOT match'}"
             f" ({h['bits']}-bit, {'Oodle-compressed' if h['compressed'] else 'raw'})")


def check_dll(stage, dll):
    if dll['status'] == 'SKIP':
        return R(stage, 'dll_read', None, dll['why'])
    return R(stage, 'dll_read', dll['status'] == 'PASS', f"granny2_age3de.dll rc={dll['rc']} output {dll['out_bytes']} B",
             **{k: v for k, v in dll.items() if k in ('tail',)})


def check_limits(stage, info, prof):
    lim = prof.get('limits', {})
    maxv, maxi = lim.get('max_vertices', 65535), lim.get('max_index', 65535)
    rows, bad, changed = [], [], 0
    for m in info['render']:
        t = m['tris']
        mi = int(t.max()) if len(t) else -1
        wrap = int(((t & 0xFFFF) != t).any(axis=1).sum()) if len(t) else 0
        oob = int((t >= m['nv']).any(axis=1).sum()) if len(t) else 0
        changed += wrap
        row = dict(mesh=m['name'], mats=m['mats'], vertices=m['nv'], tris=len(t), max_index=mi, index_bytes=m['index_width'],
                   wrap16_changed_tris=wrap, index_out_of_range_tris=oob)
        rows.append(row)
        if m['nv'] > maxv or mi > maxi or oob:
            bad.append(row)
    worst = max(rows, key=lambda r: r['vertices']) if rows else {}
    a = R(stage, 'vertex_limit', not bad and bool(rows),
          f"{len(rows)} bound mesh(es), largest {worst.get('vertices')} v / max index {worst.get('max_index')} "
          f"(limit {maxv} / {maxi})" + (f"; OVER: {[(r['mesh'], r['mats'], r['vertices']) for r in bad]}" if bad else ''),
          meshes=rows)
    b = R(stage, 'wrap16', changed == 0 and bool(rows), f"16-bit index wrap changes {changed} triangle(s)",
          changed_tris=changed)
    return [a, b]


def check_orientation(stage, info, prof):
    o = prof['orientation']
    lf = layout_facts(info, o.get('roof_height_m', 2.5))
    md = lf.get('mast_display_xy')
    off = float(np.hypot(*md)) if md else 0.0
    ok = (md is not None and off >= o.get('min_mast_offset_m', 1.0) and lf['mast_quadrant'] == o['mast_quadrant']
          and lf['courtyard_quadrant'] == o['courtyard_quadrant'])
    s = (f"mast {lf.get('mast_quadrant')} ({QUAD_NAMES.get(lf.get('mast_quadrant'), '?')}, {off:.2f} m off centre), "
         f"courtyard {lf['courtyard_quadrant']} ({QUAD_NAMES[lf['courtyard_quadrant']]}); want mast {o['mast_quadrant']} "
         f"/ courtyard {o['courtyard_quadrant']} like {prof.get('reference')}")
    return R(stage, 'orientation', ok, s, **lf)


def check_handedness(stage, info, prof):
    hp = prof['handedness']
    T, U, _, _ = triangles(info)
    s, a = uv_handedness(T, U)
    frac = float(a[s == hp.get('expect_sign', 1)].sum() / max(a.sum(), 1e-12))
    ok = frac >= hp.get('min_fraction', 0.6)
    res = dict(fraction_expected_sign=round(frac, 4), triangles=int(len(T)))
    nb = hp.get('name_board')
    msg = f"{frac:.3f} of the UV area has handedness {hp.get('expect_sign', 1):+d} (min {hp.get('min_fraction', 0.6)})"
    if nb and nb.get('stage', 'intact') == stage:
        m = next((x for x in info['render'] if x['name'] == nb['mesh']), None)
        if m is None:
            ok = False
            msg += f"; name board mesh {nb['mesh']} MISSING"
        else:
            ids = np.asarray(nb['triangles'], int)
            ids = ids[ids < len(m['tris'])]
            bs, _ = uv_handedness(m['pos'][m['tris'][ids]], m['uv'][m['tris'][ids]])
            good = int((bs == nb.get('expect_sign', 1)).sum())
            res['name_board'] = dict(mesh=nb['mesh'], checked=int(len(ids)), reading_right=good)
            ok = ok and len(ids) == len(nb['triangles']) and good == len(ids)
            msg += f"; name board {good}/{len(nb['triangles'])} faces read the right way"
    return R(stage, 'handedness', ok, msg, **res)


def check_attach(stage, info, prof):
    at = prof['attach']
    wp = world_pos(info)
    missing = [n for n in at['bones'] if n not in wp]
    out = [R(stage, 'attach_bones', not missing, f"{len(at['bones']) - len(missing)}/{len(at['bones'])} present"
             + (f"; MISSING {missing}" if missing else ''), missing=missing)]
    hp = at.get('hitpointbar')
    if hp is not None and 'BONE_HITPOINTBAR' in wp:
        d = float(np.abs(wp['BONE_HITPOINTBAR'] - hp).max())
        out.append(R(stage, 'hitpointbar', d <= at.get('hitpointbar_tol_m', 0.01),
                     f"BONE_HITPOINTBAR {_r(wp['BONE_HITPOINTBAR'])} vs vanilla {hp}: {d:.4f} m", diff=d))
    return out


def check_flag(stage, info, prof):
    at = prof['attach']
    wp = world_pos(info)
    ms = mast(render_positions(info))
    if 'bone_flag_civ' not in wp or ms['axis_xz'] is None:
        return R(stage, 'flag_on_mast', False, 'no bone_flag_civ' if ms['axis_xz'] is not None else 'no mast found')
    fc = wp['bone_flag_civ']
    off = float(np.hypot(fc[0] - ms['axis_xz'][0], fc[2] - ms['axis_xz'][1]))
    below = ms['tip'] - fc[1]
    gw = wp.get('BONE_GARRISONFLAG')
    gar = float(fc[1] - gw[1]) if gw is not None else None
    gar_off = float(np.hypot(*(gw[[0, 2]] - ms['axis_xz']))) if gw is not None else None
    tol = at.get('height_tol_m', 0.02)
    ok = (off <= at['flag_axis_tol_m'] and abs(below - at['flag_below_tip_m']) <= tol
          and gar is not None and abs(gar - at['garrison_below_flag_m']) <= tol and gar_off <= at['flag_axis_tol_m'])
    return R(stage, 'flag_on_mast', ok,
             f"flag {off * 100:.1f} cm off the mast axis (max {at['flag_axis_tol_m'] * 100:.0f}), {below:.4f} m below the "
             f"tip (vanilla {at['flag_below_tip_m']}), garrison {None if gar is None else round(gar, 4)} m below it "
             f"(vanilla {at['garrison_below_flag_m']}) and {None if gar_off is None else round(gar_off * 100, 1)} cm off axis",
             off_axis_m=round(off, 4), below_tip_m=round(below, 4), garrison_below_m=gar, mast_axis_xz=_r(ms['axis_xz']),
             tip=round(ms['tip'], 4))


def check_bone_set(stage, info, allowed):
    names = [b['name'] for b in info['bones']]
    extra = [n for n in names if n not in allowed]
    missing = [n for n in allowed if n not in names]
    return R(stage, 'bone_set', not extra and not missing, f"{len(names)} bones {names if len(names) <= 8 else ''}" +
             (f"; UNDECLARED {extra}" if extra else '') + (f"; MISSING {missing}" if missing else ''),
             extra=extra, missing=missing)


def material_names(path):
    t = Path(path).read_text(encoding='utf-8', errors='replace')
    return re.findall(r'<submaterial\s+name="([^"]+)"', t), re.findall(r'override="([^"]+)"', t)


def check_materials(stage, info, mat_path, art_root):
    used = sorted({m['mats'][g[0]] for m in info['render'] for g in m['groups'] if 0 <= g[0] < len(m['mats'])})
    if not mat_path:
        return R(stage, 'materials', None, f"no .material given; model uses {used}", used=used)
    if not Path(mat_path).exists():
        return R(stage, 'materials', False, f"material file {mat_path} MISSING; model uses {used}", used=used)
    subs, tex = material_names(mat_path)
    own = None
    if art_root is not None:
        try:
            own = str(Path(mat_path).resolve().parent.relative_to(Path(art_root).resolve())).replace('/', chr(92)).lower()
        except ValueError:
            own = None
    missing_tex = []
    for t in tex:
        if own and t.lower().startswith(own + chr(92)):
            base = Path(art_root) / t.replace(chr(92), '/')
            if not any(base.with_suffix(e).exists() for e in ('.ddt', '.tga', '.png', '.dds')):
                missing_tex.append(t)
    ok = sorted(subs) == used and not missing_tex
    return R(stage, 'materials', ok, f"bound {used} vs {Path(mat_path).name} {sorted(subs)}" +
             (f"; MISSING mod textures {missing_tex}" if missing_tex else
              f"; {len(tex)} texture refs, the mod's own ones exist" if own else '; textures not checked (no art root)'),
             used=used, submaterials=subs, missing_textures=missing_tex)


def check_bindings(stage, info):
    skel = {b['name'] for b in info['bones']}
    missing = sorted({n for m in info['render'] for n in m['bone_names'] if n not in skel})
    mixed = 0
    for m in info['render']:
        tb = m['bone'][m['tris']]
        mixed += int((~((tb[:, 0] == tb[:, 1]) & (tb[:, 1] == tb[:, 2]))).sum())
    return R(stage, 'bindings', not missing and mixed == 0,
             f"{len(missing)} bone binding(s) not in the skeleton, {mixed} triangle(s) spanning two bones",
             missing=missing, mixed_tris=mixed)


def check_frame(stage, dmg, intact, prof):
    d = prof['damaged']
    Pd, Pi = render_positions(dmg), render_positions(intact)
    bb = float(np.abs(np.r_[Pd.min(0) - Pi.min(0), Pd.max(0) - Pi.max(0)]).max())
    md, mi = mast(Pd), mast(Pi)
    ax = (float(np.hypot(*(md['axis_xz'] - mi['axis_xz']))) if md['axis_xz'] is not None and mi['axis_xz'] is not None
          else float('inf'))
    wd, wi = world_pos(dmg), world_pos(intact)
    att = {n: (float(np.abs(wd[n] - wi[n]).max()) if n in wd and n in wi else None) for n in prof['attach']['bones']}
    attmax = max((v for v in att.values() if v is not None), default=float('inf'))
    ok = (bb <= d['bbox_tol_m'] and abs(md['tip'] - mi['tip']) <= d['tip_tol_m'] and ax <= d['mast_axis_tol_m']
          and None not in att.values() and attmax <= d['attach_tol_m'])
    return R(stage, 'damaged_frame', ok,
             f"vs intact: bbox diff {bb:.4f} m (max {d['bbox_tol_m']}), tip diff {abs(md['tip'] - mi['tip']):.4f}, mast "
             f"axis diff {ax:.4f} m (max {d['mast_axis_tol_m']}), attach bones diff {attmax:.5f} m (max {d['attach_tol_m']})",
             bbox_damaged=[_r(Pd.min(0)), _r(Pd.max(0))], bbox_intact=[_r(Pi.min(0)), _r(Pi.max(0))],
             mast_axis_diff_m=ax, attach_diff_m=att)


def check_base(stage, info, prof):
    d = prof['damaged']
    T, _, MI, BN = triangles(info)
    base = BN == d['base_bone']
    unbound = int((BN == '<none>').sum())
    Tb = T[base]
    mats = np.array([info['render'][k]['mats'][0] if info['render'][k]['mats'] else '?' for k in MI[base]], dtype=object)
    boxes = {k: np.array(v, float) for k, v in d.get('base_allowed_boxes', {}).items() if not k.startswith('_')}
    allowed, bad_rows = Counter(), []
    for ids in elements(Tb):
        P = Tb[ids].reshape(-1, 3)
        lo, hi = P.min(0), P.max(0)
        where = 'platform' if hi[1] <= d['base_max_height_m'] else next(
            (k for k, b in boxes.items() if np.all(lo >= b[0]) and np.all(hi <= b[1])), None)
        if where:
            allowed[where] += len(ids)
        else:
            bad_rows.append(dict(kind=element_kind(Tb[ids]), tris=len(ids), mats=dict(Counter(mats[ids])),
                                 bbox=[_r(lo, 2), _r(hi, 2)]))
    per = {}
    for r in bad_rows:
        e = per.setdefault(r['kind'], dict(elements=0, tris=0))
        e['elements'] += 1
        e['tris'] += r['tris']
    txt = ', '.join(f"{k} {v['elements']} element(s) / {v['tris']} tris" for k, v in per.items()) or 'none'
    return R(stage, 'base_binding', not bad_rows and unbound == 0,
             f"{int(base.sum())} tris on '{d['base_bone']}': allowed {dict(allowed)}; NOT allowed {txt}"
             + (f"; {unbound} tris on no binding" if unbound else ''),
             base_tris=int(base.sum()), allowed=dict(allowed), not_allowed=per,
             not_allowed_tris=sum(r['tris'] for r in bad_rows), elements=bad_rows[:50],
             piece_tris=int((~base).sum()) - unbound)


def hkt_bodies(path):
    from hkt_patch import Patcher
    p = Patcher(str(path))
    tf = p.tf
    out = []
    for _, name, _, _, rb in p.bodies():
        T = np.array(rb['motion']['motionState']['transform'], float).reshape(4, 4)
        sidx = rb['collidable']['shape'][1]
        planes = None
        if tf.tname(tf.items[sidx][0]) == 'hkpConvexVerticesShape':
            pl = tf.read_item(tf.read_item(sidx)[0]['planeEquations'][1])
            planes = np.array([list(v) if isinstance(v, list) else [v[q] for q in range(4)] for v in pl], float)
        out.append(dict(name=name, R=T[:3, :3], t=T[3, :3], planes=planes))
    return out


def check_hkt(stage, info, hkt_path, prof):
    h = prof['damaged']['hkt']
    if not hkt_path or not Path(hkt_path).exists():
        return R(stage, 'hkt_pairing', False, f"hkt {hkt_path} missing")
    H = hkt_bodies(hkt_path)
    wp = world_pos(info)
    amap = h['axis_map']
    pairs = [(b, wp[b['name']]) for b in H if b['name'] in wp]
    unpaired = [b['name'] for b in H if b['name'] not in wp]
    if pairs:
        X = np.array([w[amap] for _, w in pairs]); Y = np.array([b['t'] for b, _ in pairs])
        ks = float((X * Y).sum() / max((X * X).sum(), 1e-12))
        err = np.linalg.norm(Y - ks * X, axis=1)
    else:
        ks, err = 0.0, np.array([np.inf])
    byname = {b['name']: b for b in H}
    base = prof['damaged']['base_bone']
    no_body, out_d, worst, hull_pieces = set(), [], None, 0
    for m in info['render']:
        for bi, bn in enumerate(m['bone_names']):
            P = m['pos'][m['bone'] == bi]
            if not len(P) or bn == base:
                continue
            b = byname.get(bn)
            if b is None:
                no_body.add(bn)
                continue
            if b['planes'] is None:                          # cylinders / list shapes: pairing only
                continue
            loc = (ks * P[:, amap] - b['t']) @ b['R'].T
            dd = (loc @ b['planes'][:, :3].T + b['planes'][:, 3]).max(1)     # > 0 = outside the hull by dd metres
            out_d.append(dd)
            hull_pieces += 1
            if worst is None or dd.max() > worst[1]:
                worst = (bn, float(dd.max()))
    D = np.concatenate(out_d) if out_d else np.array([np.inf])
    dmax = float(D.max())
    share = float((D > h['containment_tol_m']).mean())
    med = float(np.median(err))
    ok = (not unpaired and not no_body and abs(ks - h['scale']) <= h['scale_tol'] and med <= h['median_err_max_m']
          and dmax <= h['containment_max_out_m'] and share <= h['containment_max_share'])
    return R(stage, 'hkt_pairing', ok,
             f"{len(pairs)}/{len(H)} bodies paired, scale {ks:.4f} (vanilla {h['scale']}), median err {med:.4f} m "
             f"(max {h['median_err_max_m']}), {len(no_body)} render piece(s) without body; hull containment: farthest "
             f"vertex {dmax:.3f} m outside its own hull (max {h['containment_max_out_m']}, {worst[0] if worst else '-'}), "
             f"{share * 100:.3f}% of {len(D)} vertices beyond {h['containment_tol_m']} m (max {h['containment_max_share'] * 100:.2f}%)",
             bodies=len(H), paired=len(pairs), unpaired=unpaired[:20], scale=round(ks, 4), median_err_m=round(med, 4),
             p95_err_m=round(float(np.percentile(err, 95)), 4), pieces_without_body=sorted(no_body)[:20],
             hull_max_out_m=round(dmax, 4), hull_share_beyond_tol=round(share, 5), hull_pieces=hull_pieces,
             worst_piece=worst[0] if worst else None)


def check_crlf(path):
    if not path or not Path(path).exists():
        return R('folder', 'animfile_crlf', False, f"animfile {path} missing")
    b = Path(path).read_bytes()
    lone = b.count(b'\n') - b.count(b'\r\n')
    return R('folder', 'animfile_crlf', lone == 0, f"{Path(path).name}: {lone} LF-only line(s)", lf_only=lone)


# -------------------------------------------------------------------------------------------------------- driving
def load_profiles(path=PROFILES):
    return json.loads(Path(path).read_text(encoding='utf-8'))


def resolve_profile(profiles, name):
    p = dict(profiles['profiles'][name])
    p['name'] = name
    return p


def find_tools(profiles):
    """gr2_to_raw.py's folder: GR2_LINT_TOOLS, else config/tool-paths.local.json tools.gr2_to_raw_dir (this device,
    ignored), else the profile file's home-relative default."""
    env = os.environ.get('GR2_LINT_TOOLS')
    if env:
        return Path(env)
    local = HERE.parents[1] / 'config' / 'tool-paths.local.json'
    try:
        t = json.loads(local.read_text(encoding='utf-8')).get('tools', {}).get('gr2_to_raw_dir')
        if t:
            return Path(os.path.expanduser(t))
    except (OSError, ValueError, AttributeError):
        pass
    t = profiles.get('tools', {}).get('gr2_to_raw_dir')
    return Path(os.path.expanduser(t)) if t else None


def art_root_of(folder):
    for p in [Path(folder).resolve(), *Path(folder).resolve().parents]:
        if p.name.lower() == 'art':
            return p
    return None


def lint(prof, intact=None, damaged=None, hkt=None, intact_material=None, damaged_material=None, animfile=None,
         tools=None, use_dll=True, art_root=None, workdir=None):
    """-> list of check results. Files left None are not checked."""
    results = []
    own_tmp = None
    if workdir is None:
        own_tmp = tempfile.TemporaryDirectory(prefix='gr2lint_')
        workdir = own_tmp.name
    try:
        infos = {}
        for stage, path in (('intact', intact), ('damaged', damaged)):
            if not path:
                continue
            h = header(path)
            if not h.get('gr2'):
                results.append(R(stage, 'read', False, f'{path}: not a gr2 file'))
                continue
            dll = dll_read(path, tools, workdir) if use_dll else dict(status='SKIP', why='--no-dll')
            try:
                info = load(path, dll)
            except Exception as e:                            # unreadable: report it, never crash the lint
                results += [R(stage, 'crc', h['crc_ok'], f"crc {'ok' if h['crc_ok'] else 'BAD'}"), check_dll(stage, dll),
                            R(stage, 'read', False, f'{type(e).__name__}: {e}')]
                continue
            infos[stage] = info
            results += [check_crc(stage, info), check_dll(stage, dll)]
            results += check_limits(stage, info, prof)
            results.append(check_orientation(stage, info, prof))
            results.append(check_handedness(stage, info, prof))
            results += check_attach(stage, info, prof)
            if stage == 'intact':
                results.append(check_flag(stage, info, prof))
                if prof.get('intact_bones'):
                    results.append(check_bone_set(stage, info, prof['intact_bones']))
                results.append(check_materials(stage, info, intact_material, art_root))
            else:
                results.append(check_bindings(stage, info))
                results.append(check_frame(stage, info, infos['intact'], prof) if 'intact' in infos
                               else R(stage, 'damaged_frame', None, 'no intact model given'))
                results.append(check_base(stage, info, prof))
                results.append(check_hkt(stage, info, hkt, prof) if hkt else R(stage, 'hkt_pairing', None, 'no .hkt given'))
                results.append(check_materials(stage, info, damaged_material, art_root))
        if animfile is not None:
            results.append(check_crlf(animfile))
    finally:
        if own_tmp is not None:
            own_tmp.cleanup()
    return results


def table(results, files):
    lines = [f"{k:16} {v}" for k, v in files.items() if v]
    w = max([len(r['check']) for r in results] + [5])
    for r in results:
        lines.append(f"{r['stage']:8} {r['check']:{w}}  {r['status']:4}  {r['summary']}")
    n = Counter(r['status'] for r in results)
    verdict = '  -> FAIL' if n['FAIL'] else ('  -> INCOMPLETE (a SKIP is not a pass: not cleared for a game test)'
                                             if n['SKIP'] else '  -> ok')
    lines.append(f"{n['PASS']} PASS, {n['FAIL']} FAIL, {n['SKIP']} SKIP" + verdict)
    return '\n'.join(lines)


def measure_reference(path, roof_height=2.5):
    """numbers of a vanilla model for a profile's 'references' entry (read-only, raw files)."""
    info = read_raw(path)
    lf = layout_facts(info, roof_height)
    T, U, _, BN = triangles(info)
    s, a = uv_handedness(T, U)
    wp = world_pos(info)
    ms = mast(render_positions(info))
    out = dict(file=Path(path).name, layout=lf, uv_handedness_positive=round(float(a[s > 0].sum() / a.sum()), 4),
               bones=len(info['bones']), attach={n: _r(wp[n]) for n in ATTACH if n in wp},
               mast_axis_xz=None if ms['axis_xz'] is None else _r(ms['axis_xz']))
    if 'bone_flag_civ' in wp and ms['axis_xz'] is not None:
        fc = wp['bone_flag_civ']
        out['flag_off_axis_m'] = round(float(np.hypot(fc[0] - ms['axis_xz'][0], fc[2] - ms['axis_xz'][1])), 4)
        out['flag_below_tip_m'] = round(ms['tip'] - fc[1], 4)
        if 'BONE_GARRISONFLAG' in wp:
            out['garrison_below_flag_m'] = round(float(fc[1] - wp['BONE_GARRISONFLAG'][1]), 4)
    if 'base' in set(BN):
        yb = T[BN == 'base'][:, :, 1].max(1)
        out['base_tris'] = int(len(yb))
        out['base_max_height_m'] = round(float(yb.max()), 3)
    return out


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('folder', nargs='?', help='model folder (art/buildings/<name>/); files named by the profile')
    ap.add_argument('--profile', help='profile name in gr2_lint_profiles.json')
    ap.add_argument('--profiles', default=str(PROFILES))
    ap.add_argument('--intact', help='intact .gr2 (overrides the folder one)')
    ap.add_argument('--damaged', help='damaged .gr2 (overrides the folder one)')
    ap.add_argument('--hkt', help='damaged .hkt (overrides the folder one)')
    ap.add_argument('--only', choices=('intact', 'damaged'), help='report one stage (the intact is still read for the frame)')
    ap.add_argument('--no-dll', action='store_true', help='skip the Granny DLL read (reported SKIP -> exit 2)')
    ap.add_argument('--allow-skip', action='store_true',
                    help='exit 0 despite SKIPs (local iteration only; never for the game-test gate)')
    ap.add_argument('--json', help='write the full report here')
    ap.add_argument('--measure-reference', metavar='GR2', help='print profile numbers of a vanilla model and exit')
    a = ap.parse_args(argv)
    if a.measure_reference:
        print(json.dumps(measure_reference(a.measure_reference), indent=1))
        return 0
    if not a.profile:
        ap.error('--profile is required')
    profiles = load_profiles(a.profiles)
    prof = resolve_profile(profiles, a.profile)
    f = prof.get('files', {})
    folder = Path(a.folder) if a.folder else None

    def pick(key, given=None):
        if given:
            return given
        return str(folder / f[key]) if folder and f.get(key) and (folder / f[key]).exists() else None
    files = dict(intact=pick('intact', a.intact), damaged=pick('damaged', a.damaged), hkt=pick('hkt', a.hkt),
                 intact_material=pick('intact_material'), damaged_material=pick('damaged_material'),
                 animfile=pick('animfile'))
    for key in ('intact_material', 'damaged_material', 'animfile'):
        if folder and f.get(key) and not files[key]:
            files[key] = str(folder / f[key])                    # named by the profile: its check reports it MISSING
    res = lint(prof, **files, tools=find_tools(profiles), use_dll=not a.no_dll,
               art_root=art_root_of(folder) if folder else None)
    if a.only:
        res = [r for r in res if r['stage'] in (a.only, 'folder')]
    print(table(res, files))
    if a.json:
        Path(a.json).write_text(json.dumps(dict(profile=a.profile, files=files, results=res), indent=1, default=str),
                                encoding='utf-8')
    return exit_code(res, a.allow_skip)


def exit_code(res, allow_skip=False):
    """1 any FAIL; 2 no FAIL but a SKIP (not proven, e.g. the game DLL never read the file); 0 all PASS"""
    if any(r['status'] == 'FAIL' for r in res):
        return 1
    if any(r['status'] == 'SKIP' for r in res) and not allow_skip:
        return 2
    return 0


if __name__ == '__main__':
    sys.exit(main())
