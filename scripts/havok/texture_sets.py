"""Texture-set coherence: the maps bound together must describe ONE UV layout (INC: Korean TC, 2026-10-08).

The defect it exists for: a material (runtime .material or a Blender review shader) took BaseColor from one atlas
revision and Normals/Masks from another (r65 colour on v2 UVs with v2 normal + masks), and a texture path swap without
a UV remap / tangent rewrite. Names alone cannot tell legal reuse from a mix-up (vanilla reuses a base model's
Normals/Masks under a new BaseColor in 412 of AoP's 1,720 submaterials), so the checks are layered:

  1 registry      config/texture_sets.json lists the project's OWN texture sets by revision (channel -> art path +
                  sha256, retired flag, preview-image hashes and aliases, atlas regions, tangent convention). A binding
                  may take channels from ONE registered set only (or that set's declared variants); a retired set is
                  never bound.
  2 variants      <parameters variant="N"> blocks: a RECOLOUR changes BaseColor / Details only (the other channels equal
                  the default block's or are omitted - the Corvette pattern); a RE-SKIN changes Normals / Masks too and
                  then every changed channel comes from ONE source stem. A recoloured BaseColor of a mod-own DDT keeps
                  the default's size, and (content check) its structure correlates with the default BaseColor.
  3 regions       a model bound to a registered ATLAS: every triangle's UVs inside one region box (a path swap without a
                  UV remap puts triangles across region borders).
  4 tangents      a model bound to a registered set with a tangent convention: T . dP/du has the declared sign on the
                  faces (a page move without new tangents inverts the relief).

`binding_findings` is pure Python (shared by the .material check and the Blender checker); the gr2 checks take the
gr2_lint model dict. The registry is optional: without it only rule 2 applies.
"""
import hashlib
import json
import re
from pathlib import Path

import numpy as np

REPO = Path(__file__).resolve().parents[2]
REGISTRY = REPO / 'config' / 'texture_sets.json'
CHANNELS = ('basecolor', 'normals', 'masks', 'details')
RECOLOUR = ('basecolor', 'details')
CH_SUFFIX = re.compile(r'_(basecolor|normals?|masks|details|opacity|emissive)$', re.I)


def norm_ref(ref):
    """art-relative texture reference, case-folded, backslashes, no extension."""
    r = str(ref).replace('/', '\\').strip().lower()
    return re.sub(r'\.(ddt|tga|png|dds)$', '', r)


def stem(ref):
    return CH_SUFFIX.sub('', norm_ref(ref))


def channel(name):
    n = str(name).strip().lower()
    return 'normals' if n in ('normal', 'normals') else n


def load_registry(path=REGISTRY):
    p = Path(path)
    if not p.exists():
        return None
    reg = json.loads(p.read_text(encoding='utf-8'))
    reg['_by_ref'] = {}
    reg['_by_hash'] = {}
    for s in reg.get('sets', []):
        for ch, row in s.get('channels', {}).items():
            reg['_by_ref'][norm_ref(row['path'])] = (s['id'], channel(ch))
            if row.get('sha256'):
                reg['_by_hash'][row['sha256']] = (s['id'], channel(ch))
        for ch, hashes in s.get('preview_sha256', {}).items():
            for h in hashes:
                reg['_by_hash'][h] = (s['id'], channel(ch))
        for var, chans in s.get('variants', {}).items():
            for ch, ref in chans.items():
                reg['_by_ref'][norm_ref(ref)] = (s['id'] + ':' + var, channel(ch))
    reg['_sets'] = {s['id']: s for s in reg.get('sets', [])}
    return reg


def set_of_ref(reg, ref):
    return (reg or {}).get('_by_ref', {}).get(norm_ref(ref))


def set_of_image(reg, name='', sha256=None):
    """Blender/preview image -> (set id, channel) by file hash, a 12-hex hash prefix in the name, or a registered alias."""
    if not reg:
        return None
    if sha256 and sha256 in reg['_by_hash']:
        return reg['_by_hash'][sha256]
    low = Path(str(name)).name.lower()
    for h, hit in reg['_by_hash'].items():
        if re.search(r'(^|[^0-9a-f])' + h[:12] + r'([^0-9a-f]|$)', low):
            return hit
    for s in reg.get('sets', []):
        for ch, pats in s.get('aliases', {}).items():
            for pat in pats:
                if re.search(pat, low, re.I):
                    return (s['id'], channel(ch))
    return None


def base_set(sid):
    return sid.split(':', 1)[0]


def binding_findings(bound, reg, where=''):
    """bound: {channel: set id or None} of ONE binding. -> findings (rule 1)."""
    out = []
    ids = {c: s for c, s in bound.items() if s}
    bases = {base_set(s) for s in ids.values()}
    if len(bases) > 1:
        out.append(f'{where}: channels from {len(bases)} different texture sets {dict(sorted(ids.items()))} - one binding '
                   f'must use ONE set (or its declared variants)')
    for c, s in ids.items():
        row = (reg or {}).get('_sets', {}).get(base_set(s), {})
        if row.get('status') == 'retired':
            out.append(f'{where}: {c} is from the RETIRED set {base_set(s)} ({row.get("retired_note", "")})'.rstrip(' ()'))
    return out


_BLOCK = re.compile(r'<parameters(?:\s+variant="(\d+)")?\s*>(.*?)</parameters>', re.S)
_SUB = re.compile(r'<submaterial\s+name="([^"]+)"\s*>(.*?)</submaterial>', re.S)
_TEX = re.compile(r'<texture\s+name="([^"]+)"\s+override="([^"]+)"')


def parse_material(text):
    """-> [(submaterial, variant or None, {channel: ref})]"""
    rows = []
    for sname, body in _SUB.findall(text):
        for v, bb in _BLOCK.findall(body):
            rows.append((sname, v or None, {channel(a): b for a, b in _TEX.findall(bb)}))
    return rows


def ddt_size(art_root, ref):
    if art_root is None:
        return None
    p = Path(art_root) / (norm_ref(ref).replace('\\', '/') + '.ddt')
    cands = [p] if p.exists() else ([q for q in p.parent.glob('*') if q.name.lower() == p.name.lower()] if p.parent.exists() else [])
    if not cands:
        return None
    b = cands[0].read_bytes()[:16]
    return tuple(int.from_bytes(b[8 + 4 * i:12 + 4 * i], 'little') for i in (0, 1)) if b[:4] == b'RTS3' else None


def material_findings(material_path, reg=None, art_root=None, content=None):
    """rules 1 + 2 on one .material file -> dict(errors=[...], warnings=[...], content=[...]).
    errors   (deterministic, gate): a block mixes registered sets / binds a retired set.
    warnings (heuristic, report): a variant re-skin whose changed channels come from more than one source stem.
    content  (report): optional callable(ref_default, ref_variant) -> same-channel structure correlation; calibrated
             2026-10-08 on 265 AoP variant pairs (median 0.96, but re-painted sails / player-colour Details / repainted
             facades fall to 0.07-0.44), so it never gates."""
    text = Path(material_path).read_text(encoding='utf-8', errors='replace')
    name = Path(material_path).name
    res = dict(errors=[], warnings=[], content=[])
    rows = parse_material(text)
    defaults = {s: b for s, v, b in rows if v is None}
    for sname, v, b in rows:
        where = f'{name} [{sname}]' + (f' variant {v}' if v else '')
        if reg:
            res['errors'] += binding_findings({c: (set_of_ref(reg, r) or (None,))[0] for c, r in b.items()}, reg, where)
        if v is None or sname not in defaults:
            continue
        d = defaults[sname]
        changed = {c: r for c, r in b.items() if norm_ref(r) != norm_ref(d.get(c, ''))}
        reskin = {c: r for c, r in changed.items() if c not in RECOLOUR}
        if reskin and len({stem(r) for r in changed.values()}) > 1:
            res['warnings'].append(f'{where}: re-skin changes {sorted(reskin)} but its changed channels come from '
                                   f'{len({stem(r) for r in changed.values()})} sources {sorted({stem(r) for r in changed.values()})}')
        if content is not None:
            for c, r in changed.items():
                if c in d:
                    x = content(d[c], r)
                    if x is not None:
                        res['content'].append(dict(where=where, channel=c, r=round(x, 3)))
    return res


def structure_correlation(path_a, path_b, n=256):
    """same-channel layout check of two DDTs: gradient structure, 256 px, blurred, Pearson r."""
    from PIL import Image
    import sys
    sys.path.insert(0, str(REPO / '.claude' / 'skills' / 'aoe3-texture-weathering' / 'scripts'))
    from ddt2png import read_ddt
    from scipy.ndimage import gaussian_filter, sobel

    def struct(p):
        im, _ = read_ddt(p)
        a = np.asarray(im.convert('RGB').resize((n, n), Image.BILINEAR), np.float32) / 255.
        s = a @ np.array([.299, .587, .114], np.float32)
        g = gaussian_filter(np.hypot(sobel(s, 0), sobel(s, 1)), 1.5)
        return (g - g.mean()) / (g.std() + 1e-9)
    return float((struct(path_a) * struct(path_b)).mean())


def content_checker(art_root):
    def f(ref_a, ref_b):
        pa = Path(art_root) / (norm_ref(ref_a).replace('\\', '/') + '.ddt')
        pb = Path(art_root) / (norm_ref(ref_b).replace('\\', '/') + '.ddt')
        return structure_correlation(pa, pb) if pa.exists() and pb.exists() else None
    return f


# ------------------------------------------------------------------------------------------------ rules 3 + 4 (gr2)
def bound_sets(info, material_path, reg):
    """render mesh index -> registered set id of its material (default block BaseColor/Normals)."""
    if not reg or not material_path or not Path(material_path).exists():
        return {}
    rows = parse_material(Path(material_path).read_text(encoding='utf-8', errors='replace'))
    sub = {s.lower(): b for s, v, b in rows if v is None}
    out = {}
    for k, m in enumerate(info['render']):
        for g in m['groups']:
            mat = (m['mats'][g[0]] if 0 <= g[0] < len(m['mats']) else '').lower()
            b = sub.get(mat, {})
            hit = next((set_of_ref(reg, b[c]) for c in ('basecolor', 'normals') if c in b and set_of_ref(reg, b[c])), None)
            if hit:
                out.setdefault(k, []).append((g, base_set(hit[0])))
    return out


def region_findings(info, material_path, reg, tol_px=0.5):
    """rule 3: -> (checked triangles, outside count, sets)"""
    checked = outside = 0
    sets = set()
    for k, groups in bound_sets(info, material_path, reg).items():
        m = info['render'][k]
        for (mi, first, cnt), sid in groups:
            s = reg['_sets'][sid]
            if not s.get('regions'):
                continue
            sets.add(sid)
            w, h = s.get('page', [1024, 1024])
            px = m['uv'][m['tris'][first:first + cnt]] * [w, h]           # raw GR2 UV: v down = image y
            inside = np.zeros(len(px), bool)
            for r in s['regions']:
                x0, y0, x1, y1 = r['box_px']
                inside |= ((px[..., 0] >= x0 - tol_px) & (px[..., 0] <= x1 + tol_px)
                           & (px[..., 1] >= y0 - tol_px) & (px[..., 1] <= y1 + tol_px)).all(1)
            checked += len(px)
            outside += int((~inside).sum())
    return checked, outside, sorted(sets)


def tangent_findings(info, material_path, reg, min_share=0.9):
    """rule 4: -> [(set id, declared, share of triangles with the declared T.dP/du sign, triangles)]"""
    rows = []
    for k, groups in bound_sets(info, material_path, reg).items():
        m = info['render'][k]
        if m.get('tan') is None:
            continue
        for (mi, first, cnt), sid in groups:
            conv = reg['_sets'][sid].get('tangent')
            if conv not in ('uv_derivative', 'negate_t_and_b'):
                continue
            t = m['tris'][first:first + cnt]
            P, U = m['pos'][t], m['uv'][t]
            e1, e2 = P[:, 1] - P[:, 0], P[:, 2] - P[:, 0]
            d1, d2 = U[:, 1] - U[:, 0], U[:, 2] - U[:, 0]
            r = d1[:, 0] * d2[:, 1] - d2[:, 0] * d1[:, 1]
            T = m['tan'][t[:, 0]][:, :3].astype(float)
            ok = (np.abs(r) > 1e-12) & (np.linalg.norm(T, axis=1) > 1e-6)
            if not ok.any():
                continue
            dpdu = (e1 * d2[:, 1:2] - e2 * d1[:, 1:2]) / np.where(ok, r, 1)[:, None]
            sgn = np.sign(np.einsum('ij,ij->i', dpdu[ok], T[ok]))
            want = 1 if conv == 'uv_derivative' else -1
            rows.append((sid, conv, float((sgn == want).mean()), int(ok.sum())))
    return rows


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()
