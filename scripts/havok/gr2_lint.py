"""Export lint for AoE3DE building models (.gr2 + damaged .gr2 + .hkt + .material + animfile), against a VANILLA
reference profile. Every check prints PASS / FAIL / SKIP with its numbers. Exit 1 on any FAIL; exit 2 when nothing
FAILs but a check was SKIPPED (e.g. --no-dll, or the DLL tools are missing: the file is NOT proven to load in the game).
Only exit 0 clears a model for the owner's game test (AGENTS.md rule 13); --allow-skip turns exit 2 into 0 for local
iteration and is never used for that gate.

    python scripts/havok/gr2_lint.py --profile korean_tc art/buildings/korean_tc/
    python scripts/havok/gr2_lint.py --profile korean_tc --intact X.gr2 --damaged Y.gr2 [--hkt Z.hkt] [--json OUT]
    python scripts/havok/gr2_lint.py --profile market art/buildings/market/ --intact art/buildings/market/M.gr2
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
  winding                 (every model) the face area whose winding agrees with the stored normal: >= 90 % per model,
                          >= 50 % per mesh
                          (vanilla 97-100 %; a mirrored export without corner reversal is ~0 %: inside out)
  hkt_pairing             every GR2 piece bone has its Havok body at the profile's axis map / scale, and every
                          piece's render vertices lie inside its own convex hull.
  materials               mesh material bindings == the .material submaterials; referenced mod textures exist.
  crc / dll_read          header CRC valid; the game's Granny DLL reads the file (headless gr2_to_raw.py route:
                          rc 0 and a non-empty output). The DLL route also decodes Oodle-compressed files. Route from
                          the local env (AOP_GR2_DLL_ROUTE wsl|native|both, AOP_WSL_DISTRO, AOP_GR2_DLL): the TIGO PC
                          never ran it (distro 'Ubuntu' hard-coded, Wine half installed: INC-149/168, 2026-10-09).
                          The native route converts in three memory layouts and needs identical bytes.
  fixups                  no pointer fixup outside the objects reachable from the root (gr2_fixups.py). The append-only
                          writer left re-pointed root arrays with their fixups: the DLL then converted every Korean
                          writer output out of bounds (layout-dependent bytes, crashes) while single runs passed;
                          vanilla files have none (INC-187, 2026-10-09).
  bounds                  (every rigid / index-only mesh; weighted meshes are reported, not checked) every referenced
                          vertex lies inside the stored bone-binding box (bone-local AABB, gr2_bounds.py; exact on
                          vanilla rigid and destruction models): the Korean HC pier, collision mesh and a junk boat were
                          moved in place 83-87 units outside their unchanged boxes, none visible in game (2026-10-17).
  root_identity           (opt-in profile key "root_identity"; no profile sets it) the root bone rests at identity. Added
                          on 2026-10-17 for the Korean HC docks01, then not used: the fix the owner chose keeps the
                          vanilla skeleton and vanilla Idle, and a non-identity root was never shown to cause the error.
  animfile_crlf           the animfile the engine parses has CRLF endings (AGENTS.md rule 1).
  tangents                every used vertex has a non-zero tangent: materialdefault normalises it, a zero tangent is
                          NaN lighting (legacy DE conversions ship all zeros; west_townhall rendered 'very dark' with
                          any texture, 2026-09-30). The byte's low 7 bits (VS fade, vanilla 127) are reported only.
  uv_lineage              (profiles with a "uv_gate", the Korean TC) the UV lineage gate (Claude_CP2 gates/uv_gate.py,
                          run()) must be ok: the approved roof UV was dropped and S18k shipped (INC-002); a gate that
                          cannot be found is SKIP (not proven), one that cannot read its registry is FAIL.
  texture_budget          (every model; owner 2026-09-30, KTC-165) the AoP texture CEILING of the model's class:
                          small 1x2048 / medium 2048 + 1024 complement / large 2x2048. Counted (INC-033): every
                          DISTINCT own texture file of the model - every map of every submaterial and parameter
                          variant, the Normals / Masks / Details under a vanilla BaseColor included, the animfile's
                          <replacetexture> targets - over ALL its stages (intact, damaged, construction: the sibling
                          .material files and the models its animfile loads). Pages = per map channel, the n-th
                          largest file of each channel shares slot n. The class is agreed per model with the owner:
                          confirmed_by must resolve to his message in the store that names the class and the model
                          (profile "names"); a confirmed folder class covers only its "models". An unconfirmed or
                          unverifiable class does not clear the model. The shipped Korean TC carried a third set (matc
                          512, the hidden faces).
  texel_density           (every model) the UNIVERSAL UV density floor (blender-architecture-texturing
                          references/uv-density-floor.md): configured median/face floors per model and page
                          (currently 90/54 t/u), plus area-share/collapse limits. Below-floor exceptions require
                          the exact candidate's recorded owner GO; malformed/collapsed UV failures remain blocking.

Unit profiles ("unit_profiles", kind unit; 2026-10-11, PROPOSED for the owner): a skinned unit model runs crc, fixups,
dll_read, vertex_limit, wrap16, tangents, winding and materials, then unit_skeleton (one reference skeleton byte for
byte), unit_fit (the meshes sit on that skeleton: skeleton_fit.py, the scale gate of INC-251), unit_weights (8-bit sums
255, descending, cap, slot-0 convention, allowed bones), unit_vertex (the vanilla 40-byte skinned layout and fill),
unit_budget (measured vanilla maxima), texture_budget with the unit classes ("unit_texture_budget"; a listed vanilla
reference with no own texture file is not applicable), texel_density (the UNIVERSAL floor, as for every model: no unit
exemption, INC-253) and unit_density (the organic UV gate profile's higher density minima on top of it; --pose-npz for
the visible-weighted part, a numpy port of blender-organic-uv's visibility). References: "unit_references", measured
with --measure-unit-reference.

    python scripts/havok/gr2_lint.py --profile unit_rider_1024 --intact X.gr2 [--pose-npz SEATED_IDLE.npz] [FOLDER]

Profiles: scripts/havok/gr2_lint_profiles.json ("references" = numbers measured on vanilla files; "profiles" = the
building's own design facts and tolerances; every art/buildings folder has one, at least its texture class - a profile
without orientation / attach / damaged facts runs the generic checks only). External tools (the DLL route) are found
through the profile file's "tools" entry or the GR2_LINT_TOOLS environment variable; when they are missing the DLL
check is SKIP, never PASS. Reads only; writes nothing next to the model (DLL outputs go to a temp folder); vanilla
texture sizes are read from the archive headers in memory, nothing is extracted. A separate mod keeps its own building
profiles in its own repository (--profiles <file>): {"extends": "gr2_lint_profiles.json"} inherits this file's tools
(key by key) and the owner's texture_budget classes, which an extending file can never redefine; relative paths in a
profile file (uv_contract, owner_messages, authorization evidence) resolve from that file's repository.
"""
import argparse
import hashlib
import importlib.util
import json
import os
import re
import shutil
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


def _mesh(name, loc, nv, comps, tris, groups, mats, bone_names, iw, layout, obbs=None):
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
                tan=comps.get('Tangent'), tanw=comps.get('BasicStaticPackedData1'),
                tris=np.asarray(tris, np.int64).reshape(-1, 3), groups=[tuple(int(x) for x in gr) for gr in groups],
                mats=list(mats), index_width=iw, layout=layout, comps=comps, obbs=obbs)


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
            out['bones'].append(dict(name=b['Name'], parent=b['ParentIndex'][0], world=np.linalg.inv(iw),
                                     rest=tuple(b['Transform'])))
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
        elif top['Indices16'][1]:
            (s, o), n, iw = top['Indices16'][2], top['Indices16'][1], 2
        else:                                             # every triangle dropped (gr2_droptris): empty, not a crash
            s, o, n, iw = 0, 0, 0, 4
        tris = np.frombuffer(bytes(g.payload[s][o:o + n * iw]), '<i4' if iw == 4 else '<u2')
        groups = [(x['MaterialIndex'][0], x['TriFirst'][0], x['TriCount'][0]) for x in g.array(top['Groups'])]
        mats = []
        for x in g.array(rec['MaterialBindings']):
            ref = x['Material']
            mats.append(g.read(*ref[2], *ref[1])['Name'] if ref[1] else None)
        bba = g.array(rec['BoneBindings'])
        bbs = [x['BoneName'] for x in bba]
        obbs = [(np.array(x['OBBMin'], float), np.array(x['OBBMax'], float)) for x in bba]
        out['meshes'].append(_mesh(rec['Name'], tuple(loc), nv, comps, tris, groups, mats, bbs, iw, layout, obbs))
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
            out['bones'].append(dict(name=S(bo), parent=struct.unpack_from('<i', d, bo + 4)[0], world=np.linalg.inv(iw),
                                     rest=struct.unpack_from('<I3f4f9f', d, bo + 8)))      # flags, pos, quat, scale/shear
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
        obbs = [(np.array(struct.unpack_from('<3f', d, P(mo + 32) + 36 * k + 4), float),       # name ptr, OBBMin, OBBMax
                 np.array(struct.unpack_from('<3f', d, P(mo + 32) + 36 * k + 16), float)) for k in range(P(mo + 28))]
        out['meshes'].append(_mesh(S(mo), (0, mo), nv, comps, tris, groups, mats, bbs, iw, layout, obbs))
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
DLL_ROUTES = ('wsl', 'native', 'both')


def _local_value(name):
    """this device's local environment value (scripts/tools/local_env.py: the environment, else config/aop.local.env)"""
    tools = str(HERE.parent / 'tools')
    if tools not in sys.path:
        sys.path.append(tools)
    import local_env
    return local_env.value(name)


def smart_app_control_on():
    """True/False on Windows (registry CI\\Policy VerifiedAndReputablePolicyState: 0 off, 1 on, 2 evaluation); None when
    it cannot be read. The native route never runs unless this is False: SAC caches a block verdict per exe."""
    if os.name != 'nt':
        return None
    try:
        import winreg
        with winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, r'SYSTEM\CurrentControlSet\Control\CI\Policy') as k:
            return winreg.QueryValueEx(k, 'VerifiedAndReputablePolicyState')[0] != 0
    except OSError:
        return None


def _dll_wsl(g2r, src, dst, exe, distro):
    work = f'$HOME/gr2lint_{os.getpid()}_{uuid.uuid4().hex[:8]}'
    cmd = (f'set -e; unset DISPLAY WAYLAND_DISPLAY; export WINEDLLOVERRIDES=winedbg.exe=d WINEARCH=win32 '
           f'WINEPREFIX=$HOME/.wine_gxo WINEDEBUG=-all; mkdir -p {work}; cd {work}; '
           f'cp "{g2r.wsl_path(src)}" in.gr2; cp "{g2r.wsl_path(exe)}" gr2raw.exe; cp {g2r.DLL_LINUX} .; '
           f'set +e; timeout 300 wine ./gr2raw.exe >/dev/null 2>&1; rc=$?; set -e; echo "RC=$rc"; '
           f'if [ -f out.gr2 ]; then cp out.gr2 "{g2r.wsl_path(dst)}"; fi; cd /; rm -rf {work}')
    try:
        r = subprocess.run(['wsl.exe', '-d', distro, '--exec', 'bash', '-c', cmd], capture_output=True, text=True,
                           timeout=400)
        rc = next((int(l[3:]) for l in r.stdout.splitlines() if l.startswith('RC=')), None)
        tail = (r.stdout[-300:] + r.stderr[-300:]).strip()
    except (OSError, subprocess.SubprocessError) as e:
        rc, tail = None, repr(e)
    if rc is None:
        tail = f'WSL distro {distro!r} did not run the tool (set AOP_WSL_DISTRO: wsl -l -v). ' + tail
    return rc, tail


NATIVE_LAYOUTS = (8, 72, 136)   # extra work-folder name lengths: the process memory layout differs per run


def _dll_native(g2r, src, dst, exe, dll):
    """the same tool and DLL run directly on Windows (only where Smart App Control is off), once per work-folder length
    in NATIVE_LAYOUTS. A file the DLL reads out of bounds (orphan pointer fixups, INC-187) converts differently or crashes
    depending on the memory layout, so every run must pass with byte-identical output. Use system temp, not the evidence
    folder: a long cwd can be rejected by Windows CreateProcess even when Python can copy the files (INC-601)."""
    outs, tails, rc_all = [], [], 0
    for n in NATIVE_LAYOUTS:
        with tempfile.TemporaryDirectory(prefix='gr2native_' + 'n' * n + '_') as folder:
            work = Path(folder)
            shutil.copyfile(src, work / 'in.gr2')
            shutil.copyfile(dll, work / 'granny2_age3de.dll')
            shutil.copyfile(exe, work / 'gr2raw.exe')
            try:
                r = subprocess.run([str(work / 'gr2raw.exe')], cwd=str(work), capture_output=True, timeout=300)
                rc, tail = r.returncode, (r.stdout[-300:] + r.stderr[-300:]).decode('utf-8', 'replace').strip()
            except (OSError, subprocess.SubprocessError) as e:
                rc, tail = None, repr(e)
            if rc is not None and rc & 0xffffffff == 0xC0000005:
                tail = f'access violation 0xC0000005 inside granny2_age3de.dll (layout +{n}). ' + tail
            out = work / 'out.gr2'
            outs.append(out.read_bytes() if out.exists() and out.stat().st_size else None)
        if rc != 0 or outs[-1] is None:
            if rc_all == 0:
                rc_all = rc if rc not in (0, None) else (None if rc is None else -2)
            tails.append(tail or f'layout +{n}: rc={rc}, no output')
    if rc_all == 0 and len({o for o in outs}) > 1:
        rc_all, tails = -1, [f'outputs differ between memory layouts {NATIVE_LAYOUTS}: the DLL reads data out of bounds '
                             '(orphan pointer fixups? python scripts/havok/gr2_fixups.py)']
    if rc_all == 0:
        Path(dst).write_bytes(outs[0])
    return rc_all, '; '.join(tails)


def dll_read(path, tdir, workdir):
    """run granny2_age3de.dll (the converter's copy of the game's Granny runtime) on PATH: GrannyConvertFileToRaw via
    gr2_to_raw.py's hand-built exe. Route = local env AOP_GR2_DLL_ROUTE:
      wsl (default)  under Wine in the WSL distro AOP_WSL_DISTRO (default gr2_to_raw.DISTRO), in a UNIQUE Linux work
                     folder, so parallel users of gr2_to_raw never share in.gr2/out.gr2;
      native         the same exe and DLL (AOP_GR2_DLL) directly on Windows - refused while Smart App Control is on;
      both           both routes; PASS only when both pass with byte-identical outputs.
    -> dict(status PASS/FAIL/SKIP, rc, out_bytes, flat path, route)"""
    if tdir is None or not (Path(tdir) / 'gr2_to_raw.py').exists():
        return dict(status='SKIP', why=f'gr2_to_raw.py not found (tools dir {tdir}); set GR2_LINT_TOOLS')
    sys.path.insert(0, str(tdir))
    try:
        import gr2_to_raw as g2r
    finally:
        sys.path.pop(0)
    route = (_local_value('AOP_GR2_DLL_ROUTE') or 'wsl').strip().lower()
    if route not in DLL_ROUTES:
        return dict(status='FAIL', rc=None, out_bytes=0, flat=None, route=route,
                    tail=f'AOP_GR2_DLL_ROUTE={route!r} is not one of {DLL_ROUTES}')
    dll = _local_value('AOP_GR2_DLL')
    if route in ('native', 'both'):
        why = None
        if not dll or not Path(dll).is_file():
            why = f'AOP_GR2_DLL not set or not found ({dll}): the native route needs the converter granny2_age3de.dll'
        elif smart_app_control_on() is not False:
            why = 'Smart App Control is on or unreadable: the native route is refused (use the wsl route)'
        if why:
            return dict(status='SKIP', why=why, route=route)
    src = Path(path).resolve()
    exe = Path(workdir) / '_gr2lint_tool.exe'
    exe.write_bytes(g2r.build_exe())
    runs = {}
    for r_ in (('wsl', 'native') if route == 'both' else (route,)):
        dst = Path(workdir) / f'{src.stem}_{r_}_flat.gr2'
        if r_ == 'wsl':
            rc, tail = _dll_wsl(g2r, src, dst, exe, _local_value('AOP_WSL_DISTRO') or g2r.DISTRO)
        else:
            rc, tail = _dll_native(g2r, src, dst, exe, dll)
        n = dst.stat().st_size if dst.exists() else 0
        runs[r_] = dict(rc=rc, out_bytes=n, flat=str(dst) if n else None, ok=rc == 0 and n > 0, tail=tail)
    ok = all(x['ok'] for x in runs.values())
    tail = '; '.join(f"{k}: {v['tail']}" for k, v in runs.items() if not v['ok'])
    if ok and len(runs) == 2 and Path(runs['wsl']['flat']).read_bytes() != Path(runs['native']['flat']).read_bytes():
        ok, tail = False, 'wsl and native outputs differ: the routes disagree'
    first = runs['wsl' if 'wsl' in runs else 'native']
    return dict(status='PASS' if ok else 'FAIL', rc=first['rc'], out_bytes=first['out_bytes'], flat=first['flat'],
                route=route, **({'runs': {k: {'rc': v['rc'], 'out_bytes': v['out_bytes']} for k, v in runs.items()}}
                                if len(runs) == 2 else {}), **({} if ok else {'tail': tail}))


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


def check_fixups(stage, path, h):
    """no pointer fixup outside the objects reachable from the root (INC-187): an orphaned array's fixups make the
    Granny DLL convert the file out of bounds - nondeterministic output or a crash, which one DLL run can miss"""
    if h.get('compressed'):
        return R(stage, 'fixups', None, 'Oodle-compressed: relocation tables not readable here (the DLL route converts it)')
    try:
        from gr2_fixups import orphan_fixups
        rep = orphan_fixups(path)
    except Exception as e:
        return R(stage, 'fixups', False, f'cannot walk the type tree ({type(e).__name__}: {e})')
    n = len(rep['orphans'])
    return R(stage, 'fixups', n == 0, f"{n} orphan pointer fixup(s) of {rep['fixups']}"
             + (f" - first {rep['orphans'][:3]}; repair: python scripts/havok/gr2_fixups.py --scrub IN OUT" if n else ''),
             orphans=n)


def check_dll(stage, dll):
    if dll['status'] == 'SKIP':
        return R(stage, 'dll_read', None, dll['why'])
    runs = dll.get('runs')
    how = (' (' + ', '.join(f"{k} rc={v['rc']} {v['out_bytes']} B" for k, v in runs.items()) + ', identical)'
           if runs and dll['status'] == 'PASS' else '')
    return R(stage, 'dll_read', dll['status'] == 'PASS',
             f"granny2_age3de.dll [{dll.get('route', 'wsl')}] rc={dll['rc']} output {dll['out_bytes']} B{how}",
             **{k: v for k, v in dll.items() if k in ('tail', 'route', 'runs')})


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


def check_bounds(stage, info):
    """every referenced vertex lies inside the stored box of its bone binding (gr2_bounds.py: bone-local AABB, exact on
    vanilla). In-place edits that moved vertices without refreshing the boxes left the Korean HC pier, its collision
    mesh and a junk boat 83-87 units outside them (2026-10-17, neither visible in game)."""
    from gr2_bounds import extents, tolerance
    iw = {b['name']: np.linalg.inv(b['world']) for b in info['bones']}
    bad, checked, missing, skinned = [], 0, [], 0
    for m in info['render']:
        if not m.get('obbs'):
            continue
        c = m['comps']
        if c.get('BoneWeights') is not None:          # weighted: vanilla boxes are no rest AABB (gr2_bounds.py)
            skinned += 1; continue
        if any(n not in iw for n in m['bone_names']):
            missing.append(m['name']); continue
        for k, box in enumerate(extents(m['pos'], m['tris'], [iw[n] for n in m['bone_names']], c.get('BoneIndices'))):
            if box is None:
                continue
            lo, hi = m['obbs'][k]; checked += 1
            ex = float(max((lo - box[0]).max(), (box[1] - hi).max(), 0.0))
            if ex > tolerance(lo, hi):
                bad.append(dict(mesh=m['name'], bone=m['bone_names'][k], excess=round(ex, 4), verts=box[2],
                                stored=[_r(lo, 3), _r(hi, 3)], actual=[_r(box[0], 3), _r(box[1], 3)]))
    return R(stage, 'bounds', not bad and not missing,
             f"{checked} binding box(es) checked, {len(bad)} with referenced vertices outside"
             + (f": {[(b['mesh'], b['bone'], b['excess']) for b in bad[:4]]}; repair: python scripts/havok/gr2_bounds.py --fix IN OUT" if bad else '')
             + (f"; bones missing from the skeleton for {missing}" if missing else '')
             + (f"; {skinned} weighted mesh(es) not checked (info)" if skinned else ''), outside=bad)


def check_root_identity(stage, info):
    """(opt-in profile key "root_identity") the model's root bone rests at identity. docks01 is the one homecity model
    with a non-identity root (BONE_MAIN (2.98, 0.52, -6.28), 10.8 deg); whether that matters in game is unproven."""
    roots = [b for b in info['bones'] if b['parent'] < 0]
    if not roots:
        return R(stage, 'root_identity', False, 'no skeleton root')

    def identity(t):                                   # the REST transform (what the anim drives), Granny flags applied
        f = int(t[0])
        return ((not f & 1 or np.abs(t[1:4]).max() < 1e-5) and (not f & 2 or abs(abs(t[7]) - 1) < 1e-7)
                and (not f & 4 or np.abs(np.array(t[8:17]) - np.eye(3).reshape(-1)).max() < 1e-5))
    bad = [(b['name'], _r(b['rest'][1:4], 3)) for b in roots if not identity(b['rest'])]
    return R(stage, 'root_identity', not bad, f"root bone(s) {[b['name'] for b in roots]} "
             + ('at identity' if not bad else f'NOT at identity {bad}; canonize: python scripts/havok/gr2_bones.py IN '
                '{"canonize_root": true} OUT (children keep their world)'))


WINDING_MIN = 0.90      # model area share; 444 vanilla building GR2s: min 0.947, median 1.00 (2026-10-09)
WINDING_MESH_MIN = 0.50  # per mesh: a mostly inside-out mesh; vanilla worst mesh 0.556 (west_stables_age2_deathmodel)


def check_winding(stage, info):
    """the front side of every face: the engine culls by winding and lights by the stored normal, so the two must agree.
    A writer fed positions through a MIRRORED frame (det -1, e.g. Blender -> raw (-x, z, -y)) without reversing each
    face's corner order ships every face inside out: the outside is culled, the inside drawn - two-sided cut-out roofs
    render black, walls dark (Korean House r14, 2026-10-09: 0-2 % agreement; vanilla and the Korean TC 97-100 %).
    Area share of faces whose winding normal agrees with the mean stored normal of their corners, per mesh and model."""
    rows, tot, agree_area = [], 0.0, 0.0
    for m in info['render']:
        if not len(m['tris']) or m.get('nrm') is None:
            continue
        P, N = m['pos'][m['tris']], m['nrm'][m['tris']][..., :3]     # skinned Normal is x4 (w = 127): xyz only
        fn = np.cross(P[:, 1] - P[:, 0], P[:, 2] - P[:, 0])
        area = 0.5 * np.linalg.norm(fn, axis=1)
        agree = (fn * N.mean(1)).sum(1) > 0
        a, s = float(area.sum()), float(area[agree].sum())
        tot += a; agree_area += s
        rows.append(dict(mesh=m['name'], mats=m['mats'], faces=int(len(area)), agree_area_share=round(s / a, 4) if a else None))
    if not rows or tot <= 0:
        return R(stage, 'winding', None, 'no render faces with normals')
    share = agree_area / tot
    bad = [r for r in rows if r['agree_area_share'] is not None and r['agree_area_share'] < WINDING_MESH_MIN]
    return R(stage, 'winding', share >= WINDING_MIN and not bad,
             f"{share * 100:.1f}% of the face area has its winding along the stored normal (min {WINDING_MIN * 100:.0f}%, "
             f"per mesh {WINDING_MESH_MIN * 100:.0f}%)"
             + (f"; INSIDE OUT: {[(r['mesh'], r['agree_area_share']) for r in bad]} (reverse each face's corner order "
                "after a mirrored frame change)" if bad else ''), share=round(share, 4), meshes=rows)


def check_tangents(stage, info):
    """materialdefault normalises the vertex tangent (PS: rsq(dot(T, T))): a zero tangent is NaN lighting, the model
    renders nearly unlit. Legacy DE conversions ship ALL tangents zero (west_towncenter_3age, 2026-09-30: 'very dark'
    in game with any texture). The tangent byte's low 7 bits are the VS fade value (vanilla 127); converter models
    carry other values and render fine, so they are reported, not failed."""
    rows, bad = [], []
    for m in info['render']:
        if m.get('tan') is None or not len(m['tris']):
            continue
        used = np.unique(m['tris'])
        zero = int((np.linalg.norm(m['tan'][used][:, :3], axis=1) < 0.5).sum())   # x4 tangents: w is the sign
        fade = int(((m['tanw'][used, 0].astype(np.int64) & 127) != 127).sum()) if m.get('tanw') is not None else None
        row = dict(mesh=m['name'], vertices=int(len(used)), zero_tangent=zero, fade_not_127=fade)
        rows.append(row)
        if zero:
            bad.append(row)
    if not rows:
        return R(stage, 'tangents', None, 'no packed tangent data in the bound meshes')
    return R(stage, 'tangents', not bad,
             f"{sum(r['zero_tangent'] for r in rows)} zero-length tangent(s) in {sum(r['vertices'] for r in rows)} used vertices"
             + (f"; ZERO in {[(r['mesh'], r['zero_tangent']) for r in bad]} (unlit in game: compute tangents from UV0)" if bad else '')
             + f" | fade bits != 127 on {sum(r['fade_not_127'] or 0 for r in rows)} (info)", meshes=rows)


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


def check_rest_bounds(stage, info, intact, prof):
    """INC-071: reject pre-displaced fracture geometry, before Havok runs."""
    p, q = render_positions(info), render_positions(intact)
    if not len(p) or not len(q):
        return R(stage, 'assembled_rest_bounds', False, 'missing render geometry')
    delta = float(np.abs(np.array([p.min(0), p.max(0)]) - np.array([q.min(0), q.max(0)])).max())
    tol = prof['rest_contract'].get('bounds_tolerance_m', 0.02)
    return R(stage, 'assembled_rest_bounds', delta <= tol,
             f'intact/damaged maximum bound difference {delta:.6f} m; limit {tol}', delta_m=delta)


def check_ground_supports(stage, info, prof):
    """Probe declared structural feet; a fence touching zero cannot prove grounding."""
    p = render_positions(info)
    rows = []
    for support in prof['rest_contract'].get('ground_supports', []):
        lo, hi = np.array(support['xz_min']), np.array(support['xz_max'])
        within = np.all((p[:, [0, 2]] >= lo - 1e-5) & (p[:, [0, 2]] <= hi + 1e-5), axis=1)
        cloud = p[within]
        y = float(cloud[:, 1].min()) if len(cloud) else None
        target = support.get('ground_y', 0.0)
        ok = y is not None and abs(y - target) <= support.get('tolerance_m', 0.01)
        rows.append(dict(name=support['name'], min_y=y, target_y=target, ok=ok))
    return [R(stage, 'structural_ground_contact', all(x['ok'] for x in rows),
              f"{sum(x['ok'] for x in rows)}/{len(rows)} structural feet grounded", supports=rows)] if rows else []


def check_physical_mounts(stage, info, prof):
    """Explicit donor-specific supports; no universal TC mast/garrison assumption."""
    wp = world_pos(info)
    results = []
    for mount in prof['physical_mounts']:
        name = mount['bone']
        point = np.asarray(mount['position'], float)
        clouds = []
        for mesh in info['render']:
            pos = mesh['pos']
            if stage == 'damaged':
                ids = [i for i, n in enumerate(mesh['bone_names']) if n == mount['body']]
                pos = pos[np.isin(mesh['bone'], ids)]
            clouds.extend(pos)
        points = np.asarray(clouds, float).reshape(-1, 3)
        axis = np.linalg.norm(points[:, [0, 2]] - point[[0, 2]], axis=1)
        # Require actual mesh rings at BOTH ends of a continuous-height mast scope.
        near = points[axis <= mount.get('radius_m', .09)]
        bottom, top = mount['bottom_y'], mount['top_y']
        rings = bool(len(near) and np.any(abs(near[:, 1] - bottom) < .02)
                     and np.any(abs(near[:, 1] - top) < .02))
        bone_ok = name in wp and np.max(abs(wp[name] - point)) < .01
        body_ok = stage != 'damaged' or bool(len(points) and axis.max() < mount.get('assembly_radius_m', .65))
        ok = bone_ok and rings and body_ok and bottom < point[1] < top
        results.append(R(stage, 'physical_mount', ok,
                         f'{name}: bone={bone_ok}, support-end-rings={rings}, reserved-body={body_ok}',
                         bone=name, mounting_position=point.tolist(), points=len(points)))
    return results


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


def check_texture_sets(stage, mat_path, art_root):
    """texture_sets.py rules 1 + 2: one texture set per binding, no retired set (config/texture_sets.json)."""
    import texture_sets as TS
    if not mat_path or not Path(mat_path).exists():
        return R(stage, 'texture_sets', None, 'no .material given')
    reg = TS.load_registry(TS.registry_for(mat_path))
    res = TS.material_findings(mat_path, reg, art_root)
    summary = ('; '.join(res['errors']) if res['errors'] else
               f"one texture set per binding ({len(reg['_sets'])} registered sets)" if reg else 'one texture set per binding (no registry)')
    if res['warnings']:
        summary += f" | WARN {len(res['warnings'])}: " + '; '.join(res['warnings'])
    return R(stage, 'texture_sets', not res['errors'], summary, errors=res['errors'], warnings=res['warnings'])


def check_atlas_regions(stage, info, mat_path):
    """texture_sets.py rule 3: faces bound to a registered atlas lie inside its region boxes (a texture path swap
    without a UV remap puts them across region borders)."""
    import texture_sets as TS
    checked, outside, sets = TS.region_findings(info, mat_path, TS.load_registry(TS.registry_for(mat_path)) if mat_path else None)
    if not checked:
        return R(stage, 'atlas_regions', True, 'no face bound to a registered atlas')
    return R(stage, 'atlas_regions', outside == 0, f"{checked - outside}/{checked} triangle(s) inside one region box of {sets}"
             + (f"; {outside} OUTSIDE every region (UVs not remapped to this atlas?)" if outside else ''), outside=outside, sets=sets)


def check_tangent_convention(stage, info, mat_path, min_share=0.9, min_tris=50):
    """texture_sets.py rule 4: the GR2 tangents of faces on a registered set follow its convention (T = +dP/du for
    uv_derivative, -dP/du for negate_t_and_b); a page move without new tangents inverts the relief."""
    import texture_sets as TS
    rows = [r for r in TS.tangent_findings(info, mat_path, TS.load_registry(TS.registry_for(mat_path)) if mat_path else None) if r[3] >= min_tris]
    if not rows:
        return R(stage, 'tangent_convention', True, 'no face bound to a registered set with a tangent convention')
    bad = [r for r in rows if r[2] < min_share]
    txt = ', '.join(f'{s} {c}: {share:.1%} of {n}' for s, c, share, n in rows)
    return R(stage, 'tangent_convention', not bad, txt + (f' | FAIL below {min_share:.0%}: {[r[0] for r in bad]}' if bad else ''),
             rows=[dict(set=s, convention=c, share=share, triangles=n) for s, c, share, n in rows])


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


def twin_pieces(info, cm=100.):
    """same-facing triangles at the same place (1 cm) bound to DIFFERENT bones -> {(bone_a, bone_b): count}"""
    owners = {}
    for m in info['render']:
        P = np.round(np.asarray(m['pos'], float) * cm).astype(np.int64); Pf = np.asarray(m['pos'], float)
        T = m['tris']; vb = m['bone']; bn = m['bone_names']
        n = np.cross(Pf[T[:, 1]] - Pf[T[:, 0]], Pf[T[:, 2]] - Pf[T[:, 0]]); a = np.linalg.norm(n, axis=1)
        for t, nn, aa in zip(T, n, a):
            if aa < 1e-10:
                continue
            key = (tuple(sorted(map(tuple, P[t]))), tuple(np.round(nn / aa, 1)))
            owners.setdefault(key, set()).add(bn[vb[t[0]]] if len(bn) else '?')
    pairs = {}
    for v in owners.values():
        if len(v) > 1:
            k = tuple(sorted(v))[:2]; pairs[k] = pairs.get(k, 0) + 1
    return pairs


def check_twin_pieces(stage, info, hkt_path=None, max_visible=2, body_props=None):
    """A destruction piece's surface must have ONE owner when its bodies break at different times. The same surface on a
    stage piece and an on-death piece (or on two stage pieces of different proxies, or on a piece and the static base)
    flies off with one and stays with the other (owner 2026-10-10, Korean castle in game: "pieces get chipped but
    underneath the original part stays on place (like cloning debris)" - coincident donor bodies both received the region
    in the Voronoi fracture). Twins of two pieces that fall together (both on-death, or one stage proxy) are invisible:
    vanilla has them (japanese_castle_age2_damag: 188 such triangles, 1 visible)."""
    pairs = twin_pieces(info)
    if not hkt_path and body_props is None:
        n = sum(pairs.values())
        return R(stage, 'twin_pieces', None if n else True, f'{n} triangle(s) duplicated on two bodies (no .hkt: timing unknown)')
    if body_props is None:
        from hkt_read import Tagfile
        from hkt_props import bodies, props
        tf = Tagfile(str(hkt_path)); body_props = {rb['name']: props(tf, rb) for _, rb in bodies(tf)}
    P = body_props
    def visible(a, b):
        pa, pb = P.get(a), P.get(b)
        if pa is None or pb is None:                         # a static bone (no body): the piece leaves, the twin stays
            return True
        if pa.get('type') != pb.get('type'):
            return True
        return pa.get('type') == 0 and pa.get('parent') != pb.get('parent')
    vis = {k: v for k, v in pairs.items() if visible(*k)}; n_vis = sum(vis.values()); n_all = sum(pairs.values())
    worst = sorted(vis.items(), key=lambda kv: -kv[1])[:6]
    return R(stage, 'twin_pieces', n_vis <= max_visible,
             f'{n_vis} triangle(s) on two bodies that break at different times (of {n_all} twins)' + (f' - {worst}' if worst else ''),
             visible_twins=n_vis, twins=n_all, pairs=[[list(k), v] for k, v in worst])


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


# ------------------------------------------------------------------------ texture budget + UV density floor (KTC-165)
REPO = HERE.parents[1]
DENSITY_FLOOR = REPO / '.claude' / 'skills' / 'blender-architecture-texturing' / 'scripts' / 'density_floor.py'
BARTOOL_DIR = REPO / '.claude' / 'skills' / 'aoe3de-bar-archives' / 'scripts'
TEX_EXT = ('.ddt', '.tga', '.png', '.dds')
_VANILLA = {}


def image_size(path):
    """(W, H) from the file header: DDT (RTS3), TGA, PNG, DDS; None when unknown"""
    b = Path(path).read_bytes()[:32]
    if b[:4] == b'RTS3':
        return struct.unpack_from('<II', b, 8)
    if b[:8] == b'\x89PNG\r\n\x1a\n':
        return struct.unpack_from('>II', b, 16)
    if b[:4] == b'DDS ':
        h, w = struct.unpack_from('<II', b, 12)
        return w, h
    if Path(path).suffix.lower() == '.tga' and len(b) >= 16:
        return struct.unpack_from('<HH', b, 12)
    return None


def _lz4_head(src, want):
    """bartool's pure-python LZ4 block decoder, stopping after `want` output bytes (budget_inventory.py, KTC-165)"""
    out = bytearray()
    i, n = 0, len(src)
    while i < n and len(out) < want:
        token = src[i]; i += 1
        lit = token >> 4
        if lit == 15:
            while True:
                b = src[i]; i += 1; lit += b
                if b != 255:
                    break
        out += src[i:i + lit]; i += lit
        if i >= n or len(out) >= want:
            break
        offset = src[i] | (src[i + 1] << 8); i += 2
        mlen = token & 0x0F
        if mlen == 15:
            while True:
                b = src[i]; i += 1; mlen += b
                if b != 255:
                    break
        mlen += 4
        start = len(out) - offset
        for j in range(mlen):
            out.append(out[start + j])
    return bytes(out[:want])


def _bartool():
    if 'bartool' not in _VANILLA:
        try:
            sys.path.insert(0, str(BARTOOL_DIR))
            import bartool
            _VANILLA['bartool'] = bartool
            _VANILLA['index'] = bartool.build_index(bartool.find_game_dir())
        except Exception as e:                                # no game install / no bartool: vanilla sizes unknown
            _VANILLA['bartool'], _VANILLA['index'], _VANILLA['why'] = None, {}, f'{type(e).__name__}: {e}'
        finally:
            if str(BARTOOL_DIR) in sys.path:
                sys.path.remove(str(BARTOOL_DIR))
    return _VANILLA['bartool'], _VANILLA['index']


def vanilla_texture(rel):
    """a texture the game ships: its size from the archive header, read in memory (nothing is extracted, AGENTS.md
    rule 3) -> dict(src='vanilla', file, W, H) or None"""
    _, index = _bartool()
    for e in TEX_EXT[:3]:
        entry = index.get('art/' + rel.lower() + e)
        if entry is None:
            continue
        size = None
        if e == '.ddt':
            with open(entry.bar, 'rb') as f:
                f.seek(entry.offset)
                data = f.read(min(entry.size_stored, 8192))
            if data[:4] == b'alz4':
                data = _lz4_head(data[16:], 32)
            if data[:4] == b'RTS3':
                size = struct.unpack_from('<II', data, 8)
        return dict(src='vanilla', file=entry.name, W=size[0] if size else None, H=size[1] if size else None)
    return None


def resolve_texture(tex, art_root):
    """a .material texture path -> dict(src mod | vanilla | missing, file, W, H): the mod's own file under art/ first
    (its header), else the game's archive (header in memory)"""
    rel = str(tex).replace(chr(92), '/').strip('/')
    if art_root is not None:
        base = Path(art_root) / rel
        for e in TEX_EXT:
            p = base.with_name(base.name + e)
            if p.is_file():
                s = image_size(p)
                return dict(src='mod', file=str(p), W=s[0] if s else None, H=s[1] if s else None)
    return vanilla_texture(rel) or dict(src='missing', file=rel, W=None, H=None)


def read_material(path):
    """the submaterials of a .material (plain XML, or XMB through bartool) -> [{name, shader, textures {map: path},
    all_textures [(map, path, variant)]}]: `textures` is the default variant (the page a face samples), `all_textures`
    every parameter block, variants included (the engine loads them for that variant: INC-033)"""
    import xml.etree.ElementTree as ET
    raw = Path(path).read_bytes()
    if raw[:4] == b'alz4' or raw[:2] == b'X1':               # compiled: .material.XMB
        bt = _bartool()[0]
        if bt is None:
            raise ValueError(f"{Path(path).name} is XMB and bartool is unavailable ({_VANILLA.get('why')})")
        raw = bt.unwrap_alz4(raw)
        txt = bt.xmb_to_xml(raw) if bt.is_xmb(raw) else raw.decode('utf-8-sig', 'replace')
    else:
        txt = raw.decode('utf-8-sig', 'replace')
    subs = []
    for sm in ET.fromstring(txt).iter('submaterial'):
        md = sm.find('materialdef')
        tex, every = {}, []
        for params in sm.findall('parameters'):
            var = params.get('variant') or '0'
            pairs = [(t.get('name'), t.get('override') or t.get('value') or '') for t in params.findall('texture')]
            every += [(k, v, var) for k, v in pairs if v]
            if var == '0':
                tex.update(dict(pairs))
        subs.append(dict(name=sm.get('name'), shader=(md.get('name') if md is not None else '') or '',
                         textures={k: v for k, v in tex.items() if v}, all_textures=every))
    return subs


def texture_sets(subs, art_root):
    """one texture SET per BaseColor (a submaterial's group of maps; two submaterials on one BaseColor are one set):
    [{key, basecolor, src, size (max side over its resolved maps), maps, subs, shaders, missing}]"""
    sets = {}
    for s in subs:
        if not s['textures']:
            continue
        bc = s['textures'].get('BaseColor') or sorted(s['textures'].values())[0]
        key = bc.replace(chr(92), '/').lower()
        st = sets.setdefault(key, dict(key=key, basecolor=bc, subs=[], shaders=[], maps={}, missing=[]))
        st['subs'].append(s['name'])
        if s['shader'] not in st['shaders']:
            st['shaders'].append(s['shader'])
        for m, t in s['textures'].items():
            r = resolve_texture(t, art_root)
            st['maps'][m] = r
            if r['src'] == 'missing':
                st['missing'].append(t)
    for st in sets.values():
        bc = st['maps'].get('BaseColor') or next(iter(st['maps'].values()))
        st['src'] = bc['src']
        sides = [max(r['W'], r['H']) for r in st['maps'].values() if r['src'] == st['src'] and r.get('W')]
        st['size'] = max(sides) if sides else None
    return list(sets.values())


STAGE_RX = re.compile(r'_(?:damaged|con|construction)$', re.I)
STAGE_SUFFIXES = ('', '_damaged', '_con', '_construction')
_GRANNY = re.compile(r'<assetreference[^>]*type\s*=\s*"GrannyModel"[^>]*>(.*?)</assetreference>', re.S | re.I)
_FILE = re.compile(r'<file>\s*([^<]+?)\s*</file>', re.I)
_REPLACE = re.compile(r'<replacetexture>\s*<from>\s*([^<]*?)\s*</from>\s*<to>\s*([^<]*?)\s*</to>\s*</replacetexture>',
                      re.I)
_MAP_OF = re.compile(r'_(basecolor|normals?|masks|details|opacity|emissive)$', re.I)


def model_of(stem):
    """the model a stage file belongs to: korean_tc_damaged -> korean_tc, castle_zen_construction -> castle_zen"""
    return STAGE_RX.sub('', str(stem))


def model_class(prof, model):
    """the texture class the owner agreed for this model: its per_model entry, else the profile's class when that
    covers the model. A CONFIRMED folder class covers only the models it names ("models"): the market's medium (m335)
    covered oriental_house, a house (INC-033); any other model needs its own per_model class"""
    tb = prof.get('texture_budget') or {}
    pm = tb.get('per_model') or {}
    if model in pm:
        return pm[model]
    if tb.get('confirmed_by'):
        covers = tb.get('models')
        if not covers:
            return dict(tb, confirmed_by=None, why=f"the folder class {tb.get('class')} (owner {tb['confirmed_by']}) "
                                                    'names no models it covers: record "models" or a per_model class')
        if model not in covers:
            return {'class': None, 'why': f"the folder class {tb.get('class')} (owner {tb['confirmed_by']}) covers "
                                          f"{', '.join(covers)} only: record a per_model class for {model}"}
    return tb


def _ci_files(folder, names):
    """the files of `folder` whose name matches one of `names`, ignoring case (a Windows folder)"""
    want = {n.lower() for n in names}
    try:
        return [f for f in Path(folder).iterdir() if f.is_file() and f.name.lower() in want]
    except OSError:
        return []


def model_sources(mat_path, model, art_root, materials=(), animfiles=()):
    """(materials, animfiles, replacements) that make up one model's textures over ALL its stages (INC-033): the given
    materials, the sibling <model>[_damaged|_con|_construction].material next to them, the animfiles given or found
    next to them that load the model, the mod .material of every model those animfiles load, and their
    <replacetexture> (from, to) pairs"""
    mats = [Path(m) for m in [mat_path, *materials] if m]
    folders = list(dict.fromkeys(m.parent for m in mats))
    for f in folders:
        mats += _ci_files(f, [f'{model}{sfx}.material' for sfx in STAGE_SUFFIXES])
    anims = [Path(a) for a in animfiles or () if a]
    for f in folders:
        for x in sorted(f.glob('*.xml')):
            try:
                txt = x.read_text(encoding='utf-8-sig', errors='replace')
            except OSError:
                continue
            refs = [model_of(Path(r.replace(chr(92), '/')).name).lower() for blk in _GRANNY.findall(txt)
                    for r in _FILE.findall(blk)]
            if model.lower() in refs:
                anims.append(x)
    anims = list(dict.fromkeys(anims))
    repl = []
    for a in anims:
        try:
            txt = a.read_text(encoding='utf-8-sig', errors='replace')
        except OSError:
            continue
        repl += [(fr, to, a.name) for fr, to in _REPLACE.findall(txt) if to]
        if art_root is not None:
            for blk in _GRANNY.findall(txt):
                for r in _FILE.findall(blk):
                    m = Path(art_root) / (r.replace(chr(92), '/') + '.material')
                    if m.is_file():
                        mats.append(m)
    seen, out = set(), []
    for m in mats:
        k = str(m.resolve()).lower() if m.exists() else str(m).lower()
        if k not in seen:
            seen.add(k)
            out.append(m)
    return out, anims, repl


def _channel(name):
    """a map name as one channel: Normals / Normal -> normal, BaseColor -> basecolor"""
    c = str(name or '').lower()
    return 'normal' if c in ('normal', 'normals') else c


def own_pages(subs, repl, art_root, shared=False, excluded_files=()):
    """every DISTINCT own texture file (INC-033) -> (pages [(size, label)], files {channel: {key: (size, name)}},
    unknown [names]): a channel is the map name (BaseColor, Normals ...); page slot n holds the n-th largest file of
    each channel, labelled by its BaseColor file when that is the largest. Shared vanilla files count only when
    `shared`"""
    files, unknown = defaultdict(dict), []
    items = [(ch, t) for sub in subs for ch, t, _v in sub.get('all_textures') or ()]
    for _fr, to, _src in repl:
        m = _MAP_OF.search(Path(to.replace(chr(92), '/')).name)
        items.append(((m.group(1) if m else 'BaseColor'), to))
    for ch, t in items:
        r = resolve_texture(t, art_root)
        if r['src'] != 'mod' and not (shared and r['src'] == 'vanilla'):
            continue
        if r['src'] == 'mod' and str(Path(r['file']).resolve()).lower() in excluded_files:
            continue
        name = Path(str(t).replace(chr(92), '/')).name
        size = max(r['W'], r['H']) if r.get('W') and r.get('H') else None
        if size is None and name not in unknown:
            unknown.append(name)
        files[_channel(ch)][str(r['file']).lower()] = (size, name)
    ranked = {ch: sorted(v.values(), key=lambda x: (-(x[0] or 10 ** 9), x[1].lower())) for ch, v in files.items()}
    pages = []
    for i in range(max((len(v) for v in ranked.values()), default=0)):
        slot = {ch: v[i] for ch, v in ranked.items() if i < len(v)}
        size = None if any(x[0] is None for x in slot.values()) else max(x[0] for x in slot.values())
        bc = slot.get('basecolor')
        label = bc[1] if bc and bc[0] == size else max(slot.values(), key=lambda x: (x[0] or 10 ** 9, x[1]))[1]
        pages.append((size, label))
    return pages, files, unknown


def shared_mod_dependencies(prof, model, art_root):
    """Validate explicit shared-mod dependencies; never infer sharing from a name or folder.

    Profile texture_budget.shared_mod_dependencies entries contain source_names, confirmed_by,
    and files [{path (art-relative, WITH extension), sha256, width, height}]. The owner's message
    must name this model, the source and sharing/reuse. Exact paths prevent renamed duplicates
    from borrowing an exclusion; hashes pin the reviewed version. This affects the ceiling only,
    never density, missing-texture, material or geometry checks. A pinned recorded_owner_chat evidence
    artifact is also supported when the real owner instruction has no app message id. A staging junction
    may point to the same resource under explicit shared_mod_canonical_art_root. No entries preserves old behavior.
    """
    entries = (prof.get('texture_budget') or {}).get('shared_mod_dependencies') or []
    if not entries:
        return set(), [], []
    excluded, accepted, errors = set(), [], []
    names = list(prof.get('names') or []) + [model, str(model).replace('_', ' ')]
    root = Path(art_root).resolve() if art_root is not None else None
    canonical = None
    canonical_setting = (prof.get('texture_budget') or {}).get('shared_mod_canonical_art_root')
    if canonical_setting:
        candidate, missing_vars = local_path(canonical_setting)
        if candidate and not missing_vars and candidate.is_absolute() and candidate.is_dir():
            canonical = candidate.resolve()
        else:
            errors.append('shared mod canonical art root must resolve to an existing absolute directory')
    for dep in entries:
        if not isinstance(dep, dict):
            errors.append('shared mod dependency must be an object')
            continue
        who, sources = dep.get('confirmed_by'), dep.get('source_names') or []
        auth = dep.get('authorization')
        authorized = False
        if isinstance(auth, dict) and auth.get('kind') == 'recorded_owner_chat':
            # Owner chat is also an authority when no app message id exists. The agent records
            # the REAL quote and citation once; a pinned artifact is the trusted approval store,
            # not a claim of cryptographic identity verification or a generated owner message id.
            try:
                evidence_path, missing_vars = profile_path(prof, auth.get('path') or '')
                raw = evidence_path.read_bytes() if evidence_path and not missing_vars else b''
                evidence = json.loads(raw)
                authorized = (hashlib.sha256(raw).hexdigest() == auth.get('sha256')
                              and evidence.get('authority') == 'owner'
                              and evidence.get('kind') == 'recorded_owner_chat'
                              and evidence.get('purpose') == 'shared_mod_dependencies'
                              and bool(evidence.get('source_citation'))
                              and bool(evidence.get('owner_quote'))
                              and evidence['owner_quote'] == auth.get('owner_quote')
                              and model in (evidence.get('models') or [])
                              and bool(sources)
                              and set(sources) <= set(evidence.get('source_names') or []))
            except (OSError, ValueError, TypeError, AttributeError):
                authorized = False
            who = 'recorded owner chat'
        else:
            try:
                store = _density_module().verifier(owner_message_store(prof))
                text = store.text(who)
                authorized = (bool(text) and _names_in(text, names) and _names_in(text, sources)
                              and bool(re.search(r'\b(?:shared?|sharing|reuse|reusing|existing)\b', text, re.I)))
            except (OSError, ValueError, TypeError):
                authorized = False
        if not authorized:
            errors.append(f'shared mod dependency {sources}: owner {who} does not authorize model/source sharing')
            continue
        if not dep.get('files'):
            errors.append(f'shared mod dependency {sources}: no exact files declared')
            continue
        for item in dep['files']:
            if not isinstance(item, dict):
                errors.append('shared mod file must be an object')
                continue
            rel = str(item.get('path') or '').replace(chr(92), '/')
            path = (root / rel).resolve() if root else None
            if (not rel or Path(rel).is_absolute() or ':' in rel or '..' in Path(rel).parts or root is None
                    or path == root):
                errors.append(f'shared mod path must stay under art/: {rel}')
                continue
            if not path.is_relative_to(root):
                # An isolated stage may expose EXACT existing runtime resources via a junction.
                # Require its resolved target to equal the same relative resource beneath the
                # profile's explicit canonical art root; arbitrary external targets remain invalid.
                expected = (canonical / rel).resolve() if canonical else None
                if canonical is None or not path.is_relative_to(canonical) or path != expected:
                    errors.append(f'shared mod junction {rel} is outside its declared canonical art root/resource')
                    continue
            sha = str(item.get('sha256') or '').lower()
            dims = (item.get('width'), item.get('height'))
            if (not re.fullmatch('[0-9a-f]{64}', sha)
                    or any(type(v) is not int or v <= 0 for v in dims)):
                errors.append(f'shared mod file {rel}: SHA256 and positive dimensions required')
                continue
            if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != sha:
                errors.append(f'shared mod file {rel}: missing or changed from its pinned SHA256')
                continue
            if image_size(path) != dims:
                errors.append(f'shared mod file {rel}: dimensions differ from {dims}')
                continue
            key = str(path).lower()
            if key not in excluded:
                excluded.add(key)
                accepted.append(dict(path=rel, sha256=sha, width=dims[0], height=dims[1],
                                     source_names=sources, confirmed_by=who,
                                     authorization=auth if isinstance(auth, dict) else None))
    return excluded, accepted, errors


def _names_in(text, names):
    t = ' '.join(str(text or '').lower().split())
    return any(n and re.search(r'(?<![\w-])' + re.escape(' '.join(str(n).lower().split())) + r'(?![\w-])', t)
               for n in names)


def class_confirmation(entry, cls, prof, model, store=None):
    """(True, None) when confirmed_by resolves to the owner's message in his store and that message names the class
    and the model (the entry's or profile's "names", or the model name); (False, why) when it does not; (None, why)
    when there is no store to check it against (not proven: SKIP) - INC-033"""
    who = entry.get('confirmed_by')
    store = owner_message_store(prof) if store is None else store
    if store is None or not Path(store).is_file():
        return None, f"owner message store {store} missing: confirmed_by {who} cannot be verified"
    try:
        st = _density_module().verifier(store)
    except (OSError, ValueError) as e:
        return None, f'owner message store {store} unreadable ({type(e).__name__}): confirmed_by {who} not verified'
    text = st.text(who)
    if text is None:
        return False, f'confirmed_by {who} is not an owner message in {Path(store).name}'
    # INC-066: the owner can specify the exact single-page ceiling instead of
    # the class label. Keep this equivalence narrow; model relevance below and
    # the measured texture ceiling/density checks still apply independently.
    single_2048 = (cls == 'small' and
                   re.search(r'\beach (?:one|model|building)\s+(?:1\s*[xX]\s*)?2048\b', str(text), re.I) and
                   not re.search(r'\b(?:4096|8192)\b|2048\s*\+|\b(?:two|2)\s+(?:maps|pages|atlases)\b|\?', str(text), re.I))
    if not _names_in(text, [cls]) and not single_2048:
        return False, f'owner message {who} does not name the class {cls}: "{str(text)[:80]}"'
    names = list(entry.get('names') or prof.get('names') or []) + [model, str(model).replace('_', ' ')]
    if not _names_in(text, names):
        return False, f'owner message {who} does not name {model} ({", ".join(map(str, names[:-2])) or "no names"})'
    return True, None


def recorded_model_ceiling(entry, prof, model):
    """Pinned owner-chat ceiling for this model only; never edits global classes.

    Like shared_mod_dependencies, this is an auditable approval record, not an
    automatic authentication of an owner quote. Invalid declarations fail closed.
    """
    auth = entry.get('ceiling_authorization')
    try:
        path, missing = profile_path(prof, auth['path'])
        raw = path.read_bytes() if path and not missing else b''
        evidence = json.loads(raw)
        ceiling = entry['ceiling']
        scopes = (evidence.get('models'), entry.get('models'))
        exact_scope = all(isinstance(s, list) and s
                          and all(isinstance(n, str) and n.strip() for n in s)
                          and model in s for s in scopes)
        valid = (auth.get('kind') == 'recorded_owner_chat'
                 and hashlib.sha256(raw).hexdigest() == auth.get('sha256')
                 and evidence.get('authority') == 'owner'
                 and evidence.get('kind') == 'recorded_owner_chat'
                 and evidence.get('purpose') == 'texture_budget_ceiling'
                 and bool(evidence.get('source_citation'))
                 and bool(evidence.get('owner_quote'))
                 and evidence['owner_quote'] == auth.get('owner_quote')
                 and exact_scope
                 and isinstance(ceiling, list) and bool(ceiling)
                 and all(type(n) is int and n > 0 and n & (n - 1) == 0 for n in ceiling)
                 and evidence.get('ceiling') == ceiling)
        if valid:
            return sorted(ceiling, reverse=True), None
    except (OSError, ValueError, TypeError, KeyError, AttributeError):
        pass
    return [], 'invalid recorded owner ceiling: pin exact quote, model, dimensions and evidence SHA256'


def check_texture_budget(stage, mat_path, art_root, prof, model, materials=(), animfiles=()):
    """AoP texture-budget CEILING (owner 2026-09-30, m334-m336): the model's own texture files over all its stages
    (INC-033) against its class (small 1x2048, medium 2048 + a 1024 complement, large 2x2048). The class is set per
    model with the owner and verified against his message store; shared vanilla atlases are reported, counted only
    when texture_budget.count_shared_vanilla says so. Pinned shared-mod dependencies can be excluded via
    texture_budget.shared_mod_dependencies; density/material checks still apply to those resources."""
    cfg = prof.get('_texture_budget') or {}
    classes = cfg.get('classes') or {}
    entry = model_class(prof, model)
    if not mat_path or not Path(mat_path).exists():
        return R(stage, 'texture_budget', False, f"material {mat_path} missing: the texture sets cannot be counted")
    mats, anims, repl = model_sources(mat_path, model, art_root, materials, animfiles)
    subs = []
    for m in mats:
        if not Path(m).exists():
            continue
        try:
            subs += read_material(m)
        except Exception as e:                                # an unreadable material is never a pass
            return R(stage, 'texture_budget', False, f'{Path(m).name} cannot be read ({type(e).__name__}: {e})')
    sets = texture_sets(subs, art_root)
    shared = bool(cfg.get('count_shared_vanilla'))
    excluded, shared_mod, shared_errors = shared_mod_dependencies(prof, model, art_root)
    pages, files, unknown = own_pages(subs, repl, art_root, shared, excluded)
    other = [s for s in sets if s['src'] == 'vanilla' and not shared]
    missing = [t for s in sets for t in s['missing']]
    cls, who = entry.get('class'), entry.get('confirmed_by')
    ceiling = sorted((classes.get(cls) or {}).get('ceiling') or [], reverse=True)
    explicit = 'ceiling' in entry or 'ceiling_authorization' in entry
    ceiling_error = None
    if explicit:
        ceiling, ceiling_error = recorded_model_ceiling(entry, prof, model)
        cls, who = 'recorded model ceiling', 'recorded owner chat'
    over = []
    if len(pages) > len(ceiling):
        over.append(f'{len(pages)} sets > {len(ceiling)}')
    over += [f"{label} {size} > {c}" for (size, label), c in zip(pages, ceiling) if size is None or size > c]
    txt = lambda s: f"{Path(s['basecolor'].replace(chr(92), '/')).name} {s['size']} ({'/'.join(s['shaders'])})"  # noqa: E731
    own_sets = sorted((s for s in sets if (s['src'] == 'mod'
                      and str(Path(resolve_texture(s['basecolor'], art_root)['file']).resolve()).lower() not in excluded)
                      or (shared and s['src'] == 'vanilla')),
                      key=lambda s: -(s['size'] or 10 ** 9))
    n_files = sum(len(v) for v in files.values())
    head = (f"{model}: class {cls or '-'} ({f'owner {who}' if who else entry.get('status') or 'no class'}), ceiling "
            f"{' + '.join(map(str, ceiling)) or '-'}; {len(pages)} page(s) {[p[0] for p in pages]} from {n_files} own "
            f"file(s) in {', '.join(Path(m).name for m in mats if Path(m).exists())}"
            + (f" + {', '.join(a.name for a in anims)}" if anims else '')
            + f"; own set(s): {', '.join(map(txt, own_sets)) or 'none'}")
    if other:
        head += '; shared vanilla, not counted: ' + ', '.join(map(txt, other))
    if shared_mod:
        head += '; pinned shared mod files, not counted: ' + ', '.join(s['path'] for s in shared_mod)
    why, verified = list(shared_errors), True
    if explicit:
        if ceiling_error:
            why.append(ceiling_error)
            verified = False
    elif not cls or cls not in classes:
        why.append(entry.get('why') or f"no texture class recorded for {model} (the owner sets it per model)")
    elif not who:
        why.append(entry.get('why') or f"class {cls} not confirmed by the owner "
                                        f"({entry.get('status') or 'proposed, owner to confirm'})")
    else:
        verified, reason = class_confirmation(entry, cls, prof, model)
        if verified is False:
            why.append(f'class {cls} not confirmed: {reason}')
        elif verified is None:
            head += f' | {reason} (not proven: SKIP)'
    if over:
        why.append('over the ceiling: ' + ', '.join(over))
    if missing:
        why.append('textures that resolve nowhere: ' + ', '.join(missing))
    if unknown:
        why.append('own textures of unknown size: ' + ', '.join(unknown))
    status = False if why else (None if verified is None else True)
    return R(stage, 'texture_budget', status, head + (' | ' + '; '.join(why) if why else ''), model=model, cls=cls,
             confirmed_by=who, confirmed=verified, ceiling=ceiling,
             sets=[dict(basecolor=s['basecolor'], src=s['src'], size=s['size'], shaders=s['shaders'], subs=s['subs'])
                   for s in sets], counted=len(pages), pages=[p[0] for p in pages], own_files=n_files,
             sources=[str(m) for m in mats] + [str(a) for a in anims], shared_mod_dependencies=shared_mod)


def density_groups(info, mat_path, art_root):
    """the render triangles grouped by the page they sample (the BaseColor of their submaterial) for density_floor.py:
    [{page, W, H, P, UV, why}]; W/H None when the page size cannot be read (a FAIL: INCOMPLETE)"""
    try:                                                      # names match case-insensitively (vanilla med_tc_age2:
        subs = ({str(s['name']).lower(): s for s in read_material(mat_path)}   # GR2 'mata', .material 'matA')
                if mat_path and Path(mat_path).exists() else {})
    except Exception:
        subs = {}
    cache, groups = {}, []
    for m in info['render']:
        for mi, first, count in m['groups']:
            name = m['mats'][mi] if 0 <= mi < len(m['mats']) else None
            t = m['tris'][first:first + count]
            if not len(t):
                continue
            bc = ((subs.get(str(name).lower()) or {}).get('textures') or {}).get('BaseColor')
            if bc is None:
                page, W, H, why = f'{name} (no BaseColor)', None, None, f'no BaseColor for material {name}'
            else:
                if bc not in cache:
                    cache[bc] = resolve_texture(bc, art_root)
                r = cache[bc]
                page, W, H = Path(bc.replace(chr(92), '/')).name, r.get('W'), r.get('H')
                why = None if W else f"{r['src']} texture, size unknown"
            uv = m['uv'][t][:, :, :2] if m['uv'] is not None else None
            groups.append(dict(page=page, W=W, H=H, P=m['pos'][t], UV=uv, why=why))
    return groups


def _density_module():
    if 'density' not in _VANILLA:
        spec = importlib.util.spec_from_file_location('density_floor', str(DENSITY_FLOOR))
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        _VANILLA['density'] = mod
    return _VANILLA['density']


def local_path(text):
    """a profile path whose $VARIABLES come from this device's local environment (scripts/tools/local_env.py: the
    environment, else config/aop.local.env) -> (Path, []) or (None, [the variables not set on this device])"""
    if not text:
        return None, []
    tools = str(HERE.parent / 'tools')
    if tools not in sys.path:
        sys.path.append(tools)
    import local_env
    s, missing = local_env.expand(text)
    return (None, missing) if missing else (Path(s), [])


def owner_message_store(prof):
    """the owner's message store the waiver quotes are checked against: the profile file's tools.owner_messages
    ($AOP_TASKS_DIR/tasks.json); None = waivers cannot count"""
    return profile_path(prof, (prof.get('_tools') or {}).get('owner_messages'))[0]


def check_density(stage, info, mat_path, art_root, prof, model):
    """the UNIVERSAL UV density floor (blender-architecture-texturing/references/uv-density-floor.md): hard, no
    tolerance; the only exception is the owner's waiver in the profile's "waivers" (his whole message)."""
    try:
        DF = _density_module()
        floor = DF.load_floor('aoe3de')
    except Exception as e:                                    # the floor cannot be proven: never a pass
        return R(stage, 'texel_density', False, f'density floor unavailable ({type(e).__name__}: {e})')
    groups = density_groups(info, mat_path, art_root)
    store = owner_message_store(prof)
    verify = DF.verifier(store) if store is not None and store.is_file() else None
    m = DF.measure(groups, floor)
    res = DF.evaluate(m, floor, prof.get('waivers') or [], verify, model,
                      lambda pages: DF.measure(groups, floor, exempt=pages), aliases=prof.get('names') or ())
    fails = '' if res['status'] != 'FAIL' else ' | FAIL ' + ' | '.join(f['text'] for f in res['findings'])
    return R(stage, 'texel_density', res['status'] != 'FAIL', f"{res['status']} {res['summary']}{fails}"
             + (f" ({'; '.join(res['notes'])})" if res['notes'] else ''), verdict=res['status'], metrics=res['metrics'],
             findings=res['findings'], waived_by=res['waived_by'],
             **({'metrics_with_exempt_pages': res['metrics_with_exempt_pages']}
                if 'metrics_with_exempt_pages' in res else {}))


# ------------------------------------------------------------------------------------------------------ unit profiles
# A unit profile ("unit_profiles" in the profile file, "kind": "unit") lints a skinned unit model (a rider today) with
# the generic checks above (crc, fixups, dll_read, vertex_limit, wrap16, tangents, winding, materials, texture_budget,
# the universal texel_density floor) plus the unit checks below; the building facts (orientation, flags, damaged frame,
# Havok pairing, atlas registries) do not apply. References are MEASURED on vanilla units (--measure-unit-reference).
UVLIB = REPO / '.claude' / 'skills' / 'blender-organic-uv' / 'scripts' / 'uvlib.py'
UNIT_SKINNED_LAYOUT = [('Position', 0, 10, 3), ('Normal', 12, 13, 4), ('Tangent', 16, 13, 4), ('DiffuseColor0', 20, 14, 4),
                       ('TextureCoordinates0', 24, 10, 2), ('BoneWeights', 32, 14, 4), ('BoneIndices', 36, 12, 4)]
VIS_BARY = np.array([[1 / 3, 1 / 3, 1 / 3], [2 / 3, 1 / 6, 1 / 6], [1 / 6, 2 / 3, 1 / 6], [1 / 6, 1 / 6, 2 / 3]])


def _uvlib():
    """blender-organic-uv's pure-numpy metrics (the evaluator's own density and quantile definitions)"""
    if 'uvlib' not in _VANILLA:
        spec = importlib.util.spec_from_file_location('organic_uvlib', str(UVLIB))
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        _VANILLA['uvlib'] = mod
    return _VANILLA['uvlib']


def unit_raw(m):
    """the stored integers of a decoded skinned mesh: weights /255, indices, normal and tangent x127, colour /255"""
    c = m.get('comps') or {}
    out = {}
    for k, s in (('BoneWeights', 255.0), ('Normal', 127.0), ('Tangent', 127.0), ('DiffuseColor0', 255.0)):
        if k in c:
            out[k] = np.rint(c[k] * s).astype(np.int64)
    if 'BoneIndices' in c:
        out['BoneIndices'] = c['BoneIndices'].astype(np.int64)
    return out


def skeleton_signature(info):
    """names, parents and a hash of the world rest matrices (5 decimals) of the first skeleton"""
    names = [b['name'] for b in info['bones']]
    parents = [int(b['parent']) for b in info['bones']]
    W = np.round(np.array([b['world'] for b in info['bones']], float), 5) + 0.0
    return dict(bones=len(names), names=names, parents=parents,
                world_sha256=hashlib.sha256(W.astype('<f8').tobytes()).hexdigest()[:16])


def skinned_meshes(info):
    return [m for m in info['render'] if 'BoneWeights' in (m.get('comps') or {})]


def check_unit_skeleton(stage, info, prof):
    """the model carries one of the profile's reference skeletons byte for byte (names, order, parents, rest)"""
    sig = skeleton_signature(info)
    refs_ = prof.get('_unit_refs') or {}
    allowed = (prof.get('unit') or {}).get('skeletons') or []
    hit = [r for r in allowed if (refs_.get(r) or {}).get('skeleton', {}).get('world_sha256') == sig['world_sha256']
           and refs_[r]['skeleton']['names'] == sig['names'] and refs_[r]['skeleton']['parents'] == sig['parents']]
    near = {}
    for r in allowed:
        s = (refs_.get(r) or {}).get('skeleton') or {}
        near[r] = dict(bones=s.get('bones'), same_names=s.get('names') == sig['names'],
                       same_parents=s.get('parents') == sig['parents'])
    bound = sorted({n for m in info['render'] for n in m['bone_names']} - set(sig['names']))
    ok = bool(hit) and not bound
    return R(stage, 'unit_skeleton', ok, f"{sig['bones']} bones, world {sig['world_sha256']}: "
             + (f"= the reference skeleton of {hit[0]}" if hit else f"matches none of {allowed} {near}")
             + (f"; bindings name bones not in the skeleton {bound}" if bound else ''), signature=sig, matches=hit)


def check_unit_fit(stage, info, prof):
    """the skinned meshes sit on their skeleton (skeleton_fit.py, INC-251): the vertex-to-dominant-bone distance (p50,
    p95) and the mesh / weighted-joint height ratio within the limits measured on the 20 DE riders - a model exported at
    the wrong scale (0.3937x) or offset passes every byte check and fails here"""
    import skeleton_fit as F
    lim = dict(F.LIMITS, **((prof.get('unit') or {}).get('fit_limits') or {}))
    rep = F.fit(*F.from_info(info))
    bad = F.judge(rep, lim)
    return R(stage, 'unit_fit', not bad, (f"dist to the dominant bone p50 {rep.get('dist_p50')} (max {lim['dist_p50_max']}), "
                                          f"p95 {rep.get('dist_p95')} (max {lim['dist_p95_max']}), height ratio "
                                          f"{rep.get('height_ratio')} ({lim['height_ratio_min']}-{lim['height_ratio_max']})")
             + (' | ' + ' | '.join(bad) if bad else ''), fit=rep, limits=lim)


def check_unit_weights(stage, info, prof):
    """8-bit weights as vanilla stores them: every vertex sums to 255, descending, no bone twice, at most the cap,
    unused slots repeat slot 0's index (share >= the measured minimum), weighted bones inside the allowed set"""
    u = prof.get('unit') or {}
    cap, allowed = u.get('max_influences', 4), set(u.get('allowed_weighted_bones') or [])
    slot0_min = u.get('zero_slot_slot0_min', 1.0)
    rows, bad = [], []
    for m in skinned_meshes(info):
        r = unit_raw(m)
        W, I = r['BoneWeights'], r['BoneIndices']
        sums = W.sum(1)
        infl = (W > 0).sum(1)
        desc = bool((W[:, :-1] >= W[:, 1:]).all())
        dup = int(sum(len(set(i[w > 0])) != int((w > 0).sum()) for w, i in zip(W, I)))
        zero = W == 0
        slot0 = float((I[zero] == np.broadcast_to(I[:, :1], I.shape)[zero]).mean()) if zero.any() else 1.0
        used = sorted({m['bone_names'][int(i)] for i in np.unique(I[W > 0]) if int(i) < len(m['bone_names'])})
        outside = sorted(set(used) - allowed) if allowed else []
        row = dict(mesh=m['name'], vertices=m['nv'], sums_not_255=int((sums != 255).sum()), max_influences=int(infl.max()),
                   descending=desc, bone_twice=dup, zero_slot_slot0_share=round(slot0, 4), weighted_bones=used,
                   outside_allowed=outside, index_past_palette=int((I[W > 0] >= len(m['bone_names'])).sum()))
        rows.append(row)
        if (row['sums_not_255'] or row['max_influences'] > cap or not desc or dup or slot0 < slot0_min or outside
                or row['index_past_palette']):
            bad.append(row)
    if not rows:
        return R(stage, 'unit_weights', False, 'no skinned (BoneWeights) mesh bound: not a skinned unit')
    return R(stage, 'unit_weights', not bad, '; '.join(
        f"{r['mesh']}: {r['vertices']} v, sums!=255 {r['sums_not_255']}, max infl {r['max_influences']} (cap {cap}), "
        f"descending {r['descending']}, twice {r['bone_twice']}, slot0 {r['zero_slot_slot0_share']} "
        f"(min {slot0_min}), {len(r['weighted_bones'])} weighted bones"
        + (f", OUTSIDE {r['outside_allowed']}" if r['outside_allowed'] else '') for r in rows), meshes=rows)


def check_unit_vertex(stage, info, prof):
    """the vanilla 40-byte skinned vertex and the DE full-LOD fill: colour 255, Normal.w 127, Tangent.w +-127"""
    rows, bad = [], []
    for m in info['render']:
        lay = [tuple(x) for x in m['layout']]
        r = unit_raw(m)
        row = dict(mesh=m['name'], layout_vanilla=lay == UNIT_SKINNED_LAYOUT)
        if row['layout_vanilla']:
            row.update(colour_not_255=int((r['DiffuseColor0'] != 255).any(1).sum()),
                       normal_w_not_127=int((r['Normal'][:, 3] != 127).sum()),
                       tangent_w_not_pm127=int((np.abs(r['Tangent'][:, 3]) != 127).sum()))
            if row['colour_not_255'] or row['normal_w_not_127'] or row['tangent_w_not_pm127']:
                bad.append(row)
        else:
            row['layout'] = lay
            bad.append(row)
        rows.append(row)
    return R(stage, 'unit_vertex', bool(rows) and not bad,
             '; '.join(f"{r['mesh']}: " + ('vanilla 40-byte skinned layout, fill: colour!=255 %d, normal.w!=127 %d, '
                                           'tangent.w!=+-127 %d' % (r['colour_not_255'], r['normal_w_not_127'],
                                                                    r['tangent_w_not_pm127'])
                                           if r['layout_vanilla'] else f"layout {r['layout']} is NOT the vanilla one")
                       for r in rows), meshes=rows)


def welded_count(m):
    """distinct (position rounded 1e-5, every other stored component except Tangent): what a clean export ships"""
    c = m.get('comps') or {}
    if not m['nv']:
        return 0
    cols = [np.round(c['Position'], 5)] + [v for k, v in sorted(c.items()) if k not in ('Position', 'Tangent')]
    return int(len(np.unique(np.hstack(cols), axis=0)))


def check_unit_budget(stage, info, prof):
    """triangles and welded vertices of every bound mesh together within the measured vanilla rider maxima"""
    u = prof.get('unit') or {}
    tris = int(sum(len(m['tris']) for m in info['render']))
    welded = int(sum(welded_count(m) for m in info['render']))
    mt, mw = u.get('max_triangles'), u.get('max_welded_vertices')
    ok = (mt is None or tris <= mt) and (mw is None or welded <= mw)
    return R(stage, 'unit_budget', ok, f"{tris} triangles (max {mt}), {welded} welded vertices (max {mw}) over "
             f"{len(info['render'])} mesh(es)", triangles=tris, welded=welded)


def cam_dirs(forward, headings=8, pitch=47.0):
    """the evaluator's camera directions (blender-organic-uv uv_eval_blender.cam_dirs): z up, heading 0 = forward"""
    f = np.array(forward, float)
    f[2] = 0.0
    f /= max(np.linalg.norm(f), 1e-9)
    cp, sp = np.cos(np.radians(pitch)), np.sin(np.radians(pitch))
    out = []
    for h in range(headings):
        a = 2 * np.pi * h / headings
        d = np.array([np.cos(a) * f[0] - np.sin(a) * f[1], np.sin(a) * f[0] + np.cos(a) * f[1], 0.0])
        out.append(np.array([d[0] * cp, d[1] * cp, sp]))
    return out


def face_visibility(P, F, occP, occF, dirs, chunk=512):
    """per heading and face, the share of 4 barycentric samples (offset 2e-4 x the occluder diagonal along the face
    normal) that see the camera direction past every occluder face that FACES the camera (single-sided, back faces
    do not occlude): a numpy port of blender-organic-uv uv_eval_blender.face_visibility (BVH ray casts there)."""
    def normals(V, T):
        n = np.cross(V[T[:, 1]] - V[T[:, 0]], V[T[:, 2]] - V[T[:, 0]])
        return n / np.maximum(np.linalg.norm(n, axis=1), 1e-30)[:, None]
    N, NO = normals(P, F), normals(occP, occF)
    diag = float(np.linalg.norm(occP.max(0) - occP.min(0)))
    off = 2e-4 * diag
    A0, E1, E2 = occP[occF[:, 0]], occP[occF[:, 1]] - occP[occF[:, 0]], occP[occF[:, 2]] - occP[occF[:, 0]]
    vis = np.zeros((len(dirs), len(F)))
    for h, d in enumerate(dirs):
        dots = N @ d
        front = np.nonzero(dots > 1e-6)[0]
        blockers = NO @ d > 0
        a0, e1, e2 = A0[blockers], E1[blockers], E2[blockers]
        pv = np.cross(np.broadcast_to(d, e2.shape), e2)
        det = (e1 * pv).sum(1)
        okd = np.abs(det) > 1e-20
        a0, e1, e2, pv, det = a0[okd], e1[okd], e2[okd], pv[okd], det[okd]
        inv = 1.0 / det
        Q = P[F[front]]
        nn = N[front] * np.sign(dots[front])[:, None]
        origins = (VIS_BARY @ Q).reshape(-1, 3) + np.repeat(nn, 4, axis=0) * off if len(front) else np.zeros((0, 3))
        hit = np.zeros(len(origins), bool)
        for s in range(0, len(origins), chunk):
            o = origins[s:s + chunk, None, :]
            tv = o - a0[None]
            u = (tv * pv[None]).sum(2) * inv[None]
            qv = np.cross(tv, e1[None])
            v = (qv * d).sum(2) * inv[None]
            t = (qv * e2[None]).sum(2) * inv[None]
            hit[s:s + chunk] = ((u >= 0) & (v >= 0) & (u + v <= 1) & (t > 1e-9 * diag)).any(1)
        vis[h, front] = (~hit).reshape(-1, 4).mean(1) if len(front) else 0.0
    return vis


def unit_page(info, mat_path):
    """the faces on the unit's page: render faces grouped by the BaseColor of their submaterial (the material name
    when the .material is missing); the page = the group with the most 3D area. -> (page name, [(mesh, face rows)])"""
    try:
        subs = {str(s['name']).lower(): s for s in read_material(mat_path)} if mat_path and Path(mat_path).exists() else {}
    except Exception:
        subs = {}
    groups = defaultdict(list)
    for m in info['render']:
        for mi, first, count in m['groups']:
            name = m['mats'][mi] if 0 <= mi < len(m['mats']) else None
            bc = ((subs.get(str(name).lower()) or {}).get('textures') or {}).get('BaseColor') or f'({name})'
            groups[bc].append((m, np.arange(first, first + count)))
    if not groups:
        return None, []

    def area(items):
        tot = 0.0
        for m, rows in items:
            T = m['pos'][m['tris'][rows]]
            tot += 0.5 * np.linalg.norm(np.cross(T[:, 1] - T[:, 0], T[:, 2] - T[:, 0]), axis=1).sum()
        return tot
    page = max(groups, key=lambda k: area(groups[k]))
    return page, groups[page]


def unit_density(info, mat_path, page_size, pose=None, headings=8, pitch=47.0):
    """texel density of the unit page as blender-organic-uv's evaluator reports it: per face page x sqrt(A_uv / A_3d)
    (t/u = t/m with 1 unit = 1 m), area-weighted p10/p50/p90 over every face, and - with a pose NPZ - weighted by
    area x the mean visibility over the camera headings (texel_density.visible_weighted)"""
    U = _uvlib()
    page, items = unit_page(info, mat_path)
    if not items:
        return dict(page=None)
    P = [m['pos'][m['tris'][rows]] for m, rows in items]
    UV = [m['uv'][m['tris'][rows]][:, :, :2] for m, rows in items]
    Pt, UVt = np.concatenate(P), np.concatenate(UV)
    F = np.arange(3 * len(Pt)).reshape(-1, 3)
    fm = U.face_metrics(Pt.reshape(-1, 3), F, UVt, page_size)
    dens, A3 = fm['density'], fm['area3d']
    q = U.wquantile(dens, A3, [0.1, 0.5, 0.9])
    out = dict(page=page, faces=int(len(F)), meshes=sorted({m['name'] for m, _ in items}),
               all={'p10': round(q[0], 1), 'p50': round(q[1], 1), 'p90': round(q[2], 1)})
    if pose is not None:
        Z = pose
        missing = [m['name'] for m in info['render'] if 'pose__' + m['name'] not in Z]
        if missing:
            out['visible_error'] = f'pose NPZ lacks pose__ arrays for {missing}'
            return out
        posed = {m['name']: np.asarray(Z['pose__' + m['name']], float) for m in info['render']}
        bad = [n for n, m in ((m['name'], m) for m in info['render']) if posed[n].shape != (m['nv'], 3)]
        if bad:
            out['visible_error'] = f'pose arrays of {bad} do not match the vertex counts'
            return out
        Pe = np.concatenate([posed[m['name']][m['tris'][rows]] for m, rows in items]).reshape(-1, 3)
        occP, occF, base = [], [], 0
        for m in info['render']:                               # every mesh of the model occludes, the page ones too
            occP.append(posed[m['name']])
            occF.append(m['tris'] + base)
            base += m['nv']
        if 'occluder_P' in Z and 'occluder_F' in Z:
            occP.append(np.asarray(Z['occluder_P'], float))
            occF.append(np.asarray(Z['occluder_F'], np.int64) + base)
        fwd = np.asarray(Z['forward'], float) if 'forward' in Z else np.array([0.0, -1.0, 0.0])
        vis = face_visibility(Pe, F, np.vstack(occP), np.vstack(occF), cam_dirs(fwd, headings, pitch))
        w = vis.mean(0)
        qv = U.wquantile(dens, A3 * w, [0.1, 0.5, 0.9])
        out['visible_weighted'] = {'p10': round(qv[0], 1), 'p50': round(qv[1], 1), 'p90': round(qv[2], 1),
                                   'never_visible_area_share': round(float(A3[vis.max(0) == 0].sum() / A3.sum()), 4)}
        out['camera'] = dict(headings=headings, pitch=pitch, forward=np.round(fwd, 4).tolist())
    return out


def load_pose(path):
    if not path:
        return None
    with np.load(path) as z:
        return {k: z[k].copy() for k in z.files}


def uv_density_limits(prof):
    """the hard minima of the unit profile's density checks, read from the organic UV gate profile it names"""
    cfg = prof.get('uv_density') or {}
    p, _ = profile_path(prof, cfg.get('profile'))
    if p is None or not Path(p).is_file():
        raise FileNotFoundError(f"uv_density.profile {cfg.get('profile')} not found")
    doc = json.loads(Path(p).read_text(encoding='utf-8'))
    checks = {c['id']: c for c in doc['checks']}
    return {cid: checks[cid] for cid in cfg.get('checks') or []}, doc.get('name'), str(p)


def check_unit_density(stage, info, mat_path, prof, pose):
    """the unit page's texel density against the organic UV gate profile's hard minima - a higher, unit-specific target
    ON TOP of the universal floor (check texel_density runs for units too: INC-253): texel_density.all.p50 always,
    texel_density.visible_weighted.p10 with a seated pose NPZ (--pose-npz); without one that part is SKIP (not proven)"""
    try:
        lim, pname, ppath = uv_density_limits(prof)
    except Exception as e:                                    # a limit that cannot be read is never a pass
        return R(stage, 'unit_density', False, f'uv density limits unavailable ({type(e).__name__}: {e})')
    u = prof.get('unit') or {}
    d = unit_density(info, mat_path, u.get('page', 1024), pose, u.get('headings', 8), u.get('pitch', 47.0))
    if not d.get('page'):
        return R(stage, 'unit_density', False, 'no bound faces')
    parts, ok, skip = [], True, False
    for cid, c in lim.items():
        metric = c['metric']
        if metric == 'texel_density.all.p50':
            val = d['all']['p50']
        elif metric == 'texel_density.visible_weighted.p10':
            val = (d.get('visible_weighted') or {}).get('p10')
        else:
            val = None
        hard = (c.get('hard') or {}).get('min')
        if val is None:
            skip = True
            parts.append(f"{cid} not measured ({d.get('visible_error') or 'no --pose-npz: the seated pose is needed'})")
            continue
        good = hard is None or val >= hard
        ok &= good
        parts.append(f"{cid} {val} (hard min {hard}){'' if good else ' BELOW'}")
    status = False if not ok else (None if skip else True)
    return R(stage, 'unit_density', status, f"page {d['page']} ({d['faces']} faces of {', '.join(d['meshes'])}) at "
             f"{u.get('page', 1024)}: " + '; '.join(parts) + f" [limits: {pname}]", density=d, profile=ppath)


def check_unit_texture_budget(stage, mat_path, art_root, prof, model, **union):
    """texture_budget with the unit classes; a model the profile lists as a vanilla REFERENCE with no own texture file
    has nothing to count (PASS, not applicable) - every other model runs the full check (an unconfirmed class FAILs)"""
    if model in (prof.get('references') or []) and mat_path and Path(mat_path).exists():
        try:
            subs = read_material(mat_path)
            pages, files, unknown = own_pages(subs, [], art_root)
        except Exception as e:
            return R(stage, 'texture_budget', False, f'{Path(mat_path).name} cannot be read ({type(e).__name__}: {e})')
        if not pages and not unknown:
            return R(stage, 'texture_budget', True, f"{model}: vanilla reference of this profile, 0 own texture files "
                     '(its pages are the game\'s): the unit class does not apply', model=model, counted=0)
    return check_texture_budget(stage, mat_path, art_root, prof, model, **union)


def measure_unit_reference(path, mat_path=None, pose_npz=None, page_size=1024):
    """the numbers a unit profile's references entry holds, measured on a vanilla file (read-only, raw files)"""
    info = read_raw(path)
    sk = [m for m in skinned_meshes(info)]
    weighted, slot0, infl = set(), [], 0
    for m in sk:
        r = unit_raw(m)
        W, I = r['BoneWeights'], r['BoneIndices']
        weighted |= {m['bone_names'][int(i)] for i in np.unique(I[W > 0])}
        zero = W == 0
        if zero.any():
            slot0.append(float((I[zero] == np.broadcast_to(I[:, :1], I.shape)[zero]).mean()))
        infl = max(infl, int((W > 0).sum(1).max()))
    d = unit_density(info, mat_path, page_size, load_pose(pose_npz))
    return dict(file=Path(path).name, skeleton=skeleton_signature(info), weighted_bones=sorted(weighted),
                max_influences=infl, zero_slot_slot0_share_min=round(min(slot0), 4) if slot0 else None,
                triangles=int(sum(len(m['tris']) for m in info['render'])),
                welded=int(sum(welded_count(m) for m in info['render'])),
                layouts_vanilla=[[tuple(x) for x in m['layout']] == UNIT_SKINNED_LAYOUT for m in info['render']],
                density=d)


# -------------------------------------------------------------------------------------------------------- driving
def load_profiles(path=PROFILES):
    """a profile file. "extends" names a profile file next to this script: its tools come in key by key (the file's
    own keys win) and its texture_budget and references are taken as they are; the owner's classes are never
    redefined by a separate mod. "_root" = the file's repository (nearest folder with .git, else the file's folder):
    the base of the file's relative paths."""
    path = Path(path).resolve()
    doc = json.loads(path.read_text(encoding='utf-8'))
    base_name = doc.get('extends')
    if base_name is not None:
        base_path = HERE / str(base_name)
        if Path(str(base_name)).name != base_name or not base_path.is_file() or base_path == path:
            raise ValueError(f'{path.name}: extends {base_name!r} is not another profile file next to gr2_lint.py')
        if 'texture_budget' in doc or 'unit_texture_budget' in doc:
            raise ValueError(f'{path.name}: an extending profile file cannot redefine the owner\'s texture_budget')
        base = json.loads(base_path.read_text(encoding='utf-8'))
        doc['tools'] = {**(base.get('tools') or {}), **(doc.get('tools') or {})}
        doc['texture_budget'] = base.get('texture_budget') or {}
        doc['unit_texture_budget'] = base.get('unit_texture_budget') or {}
        doc.setdefault('references', base.get('references') or {})
        doc.setdefault('unit_references', base.get('unit_references') or {})
        doc['unit_profiles'] = {**(base.get('unit_profiles') or {}), **(doc.get('unit_profiles') or {})}
    doc['_root'] = str(next((d for d in path.parents if (d / '.git').exists()), path.parent))
    return doc


def profile_path(prof, text):
    """a path named in a profile: $VARIABLES from this device's local environment (local_path), a relative path from
    the profile file's repository ("_root"; the working folder for a profile that came from no file)"""
    p, missing = local_path(text)
    if p is not None and not p.is_absolute() and prof.get('_root'):
        p = Path(prof['_root']) / p
    return p, missing


def resolve_profile(profiles, name):
    if name not in profiles.get('profiles', {}) and name in (profiles.get('unit_profiles') or {}):
        p = dict(profiles['unit_profiles'][name])              # a unit profile: unit classes and unit references
        p['name'], p['kind'] = name, 'unit'
        p['_texture_budget'] = profiles.get('unit_texture_budget') or {}
        p['_unit_refs'] = profiles.get('unit_references') or {}
        p['_tools'] = profiles.get('tools') or {}
        if profiles.get('_root'):
            p['_root'] = profiles['_root']
        return p
    if name not in profiles.get('profiles', {}):
        raise KeyError(f"no lint profile {name!r} in gr2_lint_profiles.json (every building folder has one; a model "
                       "without a profile is not cleared)")
    p = dict(profiles['profiles'][name])
    if p.get('resource_only'):
        raise KeyError(f'{name!r} is a shared texture dependency, not an exportable building profile')
    p['name'] = name
    p['_texture_budget'] = profiles.get('texture_budget') or {}       # the owner's classes and counting rule
    p['_tools'] = profiles.get('tools') or {}
    if profiles.get('_root'):
        p['_root'] = profiles['_root']
    return p


def find_tools(profiles):
    """gr2_to_raw.py's folder: GR2_LINT_TOOLS, else the profile file's tools.gr2_to_raw_dir ($AOP_KOREAN_REPO/...);
    None = not on this device (the dll_read check is SKIP)."""
    env = os.environ.get('GR2_LINT_TOOLS')
    if env:
        return Path(env)
    return local_path(profiles.get('tools', {}).get('gr2_to_raw_dir'))[0]


def uv_gate_path(profiles, prof):
    """the profile's UV lineage gate (INC-002, AGENTS.md rule 13): its uv_gate.path ($AOP_KOREAN_REPO/...). A variable
    not set on this device gives a path that names it (check_uv_gate: SKIP). None = the profile has no UV gate."""
    g = prof.get('uv_gate')
    if not g:
        return None
    if not g.get('path'):
        return Path('(no uv_gate.path in the profile)')
    p, missing = local_path(g['path'])
    return p or Path('(%s not set on this device: python scripts/tools/local_env.py)' % ', '.join(missing))


def check_uv_gate(path):
    """the UV lineage gate as one lint check: its run() on its own default registry (never $KTC_UV_LINEAGE). Missing =
    SKIP (exit 2: not cleared); unreadable registry / tracker = FAIL; not ok = FAIL with the gate's FAIL lines"""
    if path is None or not Path(path).is_file():
        return R('folder', 'uv_lineage', None, f'UV lineage gate {path} not found: the UV is not proven (a SKIP is not a '
                                               'pass)', gate=str(path))
    try:
        spec = importlib.util.spec_from_file_location('ktc_uv_gate', str(path))
        ug = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(ug)
        rep = ug.run(ug.DEFAULT_LINEAGE)
    except Exception as e:                                    # uv_gate.py exit 2: never a pass
        return R('folder', 'uv_lineage', False, f'{path}: cannot read the registry or the tracker ({type(e).__name__}: '
                                                f'{str(e)[:300]})', gate=str(path))
    fails = [c['text'] for c in rep['checks'] if c['status'] == 'FAIL']
    head = f"in_use {rep['in_use']}, approved target {rep['approved_target']} ({rep['head_status']})"
    return R('folder', 'uv_lineage', bool(rep['ok']),
             head + (': every check PASS or WAIVED' if rep['ok'] else ' | ' + ' | '.join(f[:400] for f in fails)),
             gate=str(path), checks={c['id']: c['status'] for c in rep['checks']})


def art_root_of(folder):
    for p in [Path(folder).resolve(), *Path(folder).resolve().parents]:
        if p.name.lower() == 'art':
            return p
    return None


def lint(prof, intact=None, damaged=None, hkt=None, intact_material=None, damaged_material=None, animfile=None,
         tools=None, use_dll=True, art_root=None, workdir=None, pose=None):
    """-> list of check results. Files left None are not checked. pose: a loaded pose NPZ (unit profiles only: the
    seated pose of the visible-weighted density)."""
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
            # every model, every profile (KTC-165): the AoP texture ceiling of its class and the universal UV floor
            mat = intact_material if stage == 'intact' else damaged_material
            model = prof.get('model') or model_of(Path(intact or path).stem)
            union = dict(materials=[x for x in (intact_material, damaged_material) if x],
                         animfiles=[animfile] if animfile else ())             # one budget over all stages (INC-033)
            h = header(path)
            if not h.get('gr2'):
                results += [R(stage, 'read', False, f'{path}: not a gr2 file'),
                            check_texture_budget(stage, mat, art_root, prof, model, **union)]   # the .material alone
                continue
            dll = dll_read(path, tools, workdir) if use_dll else dict(status='SKIP', why='--no-dll')
            try:
                info = load(path, dll)
            except Exception as e:                            # unreadable: report it, never crash the lint
                results += [R(stage, 'crc', h['crc_ok'], f"crc {'ok' if h['crc_ok'] else 'BAD'}"), check_dll(stage, dll),
                            R(stage, 'read', False, f'{type(e).__name__}: {e}'),
                            check_texture_budget(stage, mat, art_root, prof, model, **union)]
                continue
            infos[stage] = info
            results += [check_crc(stage, info), check_fixups(stage, path, h), check_dll(stage, dll)]
            results += check_limits(stage, info, prof)
            results.append(check_tangents(stage, info))
            results.append(check_winding(stage, info))
            results.append(check_bounds(stage, info))
            if prof.get('root_identity'):
                results.append(check_root_identity(stage, info))
            if prof.get('kind') == 'unit':                    # a skinned unit: the unit checks, no building facts
                results += [check_unit_skeleton(stage, info, prof), check_unit_fit(stage, info, prof),
                            check_unit_weights(stage, info, prof),
                            check_unit_vertex(stage, info, prof), check_unit_budget(stage, info, prof),
                            check_materials(stage, info, mat, art_root),
                            check_unit_texture_budget(stage, mat, art_root, prof, model, **union),
                            check_density(stage, info, mat, art_root, prof, model),    # the universal floor (INC-253)
                            check_unit_density(stage, info, mat, prof, pose)]
                continue
            if prof.get('rest_contract'):
                results += check_ground_supports(stage, info, prof)
                if stage == 'damaged':
                    results.append(check_rest_bounds(stage, info, infos['intact'], prof) if 'intact' in infos
                                   else R(stage, 'assembled_rest_bounds', None, 'no intact model given'))
            if prof.get('physical_mounts'):
                results += check_physical_mounts(stage, info, prof)
            if 'orientation' in prof:                         # building-specific facts: a generic profile has none
                results.append(check_orientation(stage, info, prof))
            if 'handedness' in prof:
                results.append(check_handedness(stage, info, prof))
            if 'attach' in prof:
                results += check_attach(stage, info, prof)
            if stage == 'intact':
                from gr2_ao_check import check as check_ao_shared_uv          # INC: shared-UV AO (owner 2026-10-12)
                results.append(check_ao_shared_uv(stage, info, intact_material, art_root, prof, read_material, resolve_texture, R))
                if 'attach' in prof:
                    results.append(check_flag(stage, info, prof))
                if prof.get('intact_bones'):
                    results.append(check_bone_set(stage, info, prof['intact_bones']))
                results.append(check_materials(stage, info, intact_material, art_root))
                results += [check_texture_sets(stage, intact_material, art_root), check_atlas_regions(stage, info, intact_material),
                            check_tangent_convention(stage, info, intact_material)]
            else:
                results.append(check_bindings(stage, info))
                results.append(check_twin_pieces(stage, info, hkt))
                if 'damaged' in prof:
                    results.append(check_frame(stage, info, infos['intact'], prof) if 'intact' in infos
                                   else R(stage, 'damaged_frame', None, 'no intact model given'))
                    results.append(check_base(stage, info, prof))
                    results.append(check_hkt(stage, info, hkt, prof) if hkt
                                   else R(stage, 'hkt_pairing', None, 'no .hkt given'))
                results.append(check_materials(stage, info, damaged_material, art_root))
                results += [check_texture_sets(stage, damaged_material, art_root), check_atlas_regions(stage, info, damaged_material),
                            check_tangent_convention(stage, info, damaged_material)]
            results.append(check_texture_budget(stage, mat, art_root, prof, model, **union))
            results.append(check_density(stage, info, mat, art_root, prof, model))
            if prof.get('uv_contract'):
                from gr2_uv_contract import check as check_uv_contract
                ok, message = check_uv_contract(stage, info, prof['uv_contract'],
                                                prof.get('_root') or Path(__file__).resolve().parents[2])
                results.append(R(stage, 'source_uv_contract', ok, message))
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
    ap.add_argument('--measure-unit-reference', metavar='GR2',
                    help='print unit profile numbers of a vanilla unit (with --material and --pose-npz) and exit')
    ap.add_argument('--material', help='--measure-unit-reference: the model\'s .material (the page of its density)')
    ap.add_argument('--pose-npz', help='unit profiles: the seated pose NPZ of the visible-weighted density (posed '
                    'positions pose__<mesh> in the gr2 vertex order, gr2-handed z-up frame, occluder_P/F = the horse, '
                    'forward); without it that part of unit_density is SKIP')
    a = ap.parse_args(argv)
    if a.measure_reference:
        print(json.dumps(measure_reference(a.measure_reference), indent=1))
        return 0
    if a.measure_unit_reference:
        print(json.dumps(measure_unit_reference(a.measure_unit_reference, a.material, a.pose_npz), indent=1))
        return 0
    if not a.profile:
        ap.error('--profile is required')
    profiles = load_profiles(a.profiles)
    try:
        prof = resolve_profile(profiles, a.profile)
    except KeyError as e:
        ap.error(str(e))
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
    for key, stage in (('intact_material', 'intact'), ('damaged_material', 'damaged')):
        if not files[key] and files[stage]:                       # a generic profile: the .material next to the model
            files[key] = str(Path(files[stage]).with_suffix('.material'))
    if a.pose_npz and prof.get('kind') != 'unit':
        ap.error('--pose-npz applies to unit profiles only')
    res = lint(prof, **files, tools=find_tools(profiles), use_dll=not a.no_dll,
               art_root=art_root_of(folder) if folder else None, pose=load_pose(a.pose_npz))
    if prof.get('uv_gate'):                                  # the Korean TC: the UV lineage gate clears it too (INC-002)
        res.append(check_uv_gate(uv_gate_path(profiles, prof)))
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
