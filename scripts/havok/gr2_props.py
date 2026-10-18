"""AoE3 DE adapter of the composition gate: what a building GR2 really draws on each texture page, and whether every
placed prop of a props manifest is in it (nothing missing, nothing extra, on the right page version).

    python scripts/havok/gr2_props.py composition MODEL.gr2 [MODEL.material]        # per bound mesh: slot, page, tris
    python scripts/havok/gr2_props.py check MANIFEST.json --art-root <mod>/art [--json OUT]   # exit 1 FAIL, 2 SKIP

The page of a slot is the stem of its BaseColor override (korean_shared_props_r6_BaseColor -> korean_shared_props_r6):
the slot LETTER is not an identity (the Korean props page is matd on the civic buildings, mate on the Houses, matf on
the age-0 Houses; matd is the TC pottery page on the Houses). Only meshes the model binds are read (gr2_lint 'render'):
an unbound mesh never draws.

Props manifest (written by the project, e.g. korean-buildings-blender patterns/korean/props_manifests/<building>.json):
  page        the props page stem every props stage must bind
  stages      {stage: {gr2, material (paths relative to the mod's art/ root), props: "all" | "none"}}
  placements  [{id, prop, tris, area, points_mm: [[x, y, z] ...]}] in the GR2 raw frame, from the export payload
A stage with props "all" must hold exactly the placements (Blendify blender-complex-scene composition_gate
match_groups: corners within 2 mm, triangle count and area); "none" must draw no triangle on the page.

gr2_lint runs it as the check 'props' when a profile has "props_manifest": {"path": "$AOP_KOREAN_REPO/...",
"stages": {"intact": "construction"}} (lint stage -> manifest stage; default the same name). A manifest or the
generic gate that cannot be found is SKIP (exit 2: not cleared), never a pass.

Why (2026-10-17, Korean Consulate, owner: "Where are the props?"): prop meshes were dropped silently by a review
builder; nothing in the chain checked props per placement. gr2_lint 'materials' only compares slot sets and the UV
contract pins counts written from the same payload. Audit: workflow journal 2026-10-17-claude-opus-5.5
props-forensics-04.
"""
import argparse
import importlib.util
import json
import os
import re
import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import gr2_lint  # noqa: E402

GATE = 'blender-complex-scene/scripts/composition_gate.py'


def slot_pages(material_path):
    """{slot: BaseColor page stem (lower case)} of a .material; a slot without a BaseColor override maps to None"""
    t = Path(material_path).read_text(encoding='utf-8', errors='replace')
    out = {}
    for m in re.finditer(r'<submaterial\s+name="([^"]+)"\s*>(.*?)</submaterial>', t, re.S):
        b = re.search(r'name="BaseColor"\s+override="([^"]+)"', m.group(2))
        out[m.group(1)] = re.sub(r'_basecolor$', '', b.group(1).replace('/', '\\').split('\\')[-1].lower()) if b else None
    return out


def composition(info, pages=None):
    """[{mesh, slot, page, tris}] per material group of every bound mesh (info = gr2_lint.read_raw / load)"""
    rows = []
    for m in info['render']:
        groups = m['groups'] or [(0, 0, len(m['tris']))]
        for g in groups:
            slot = m['mats'][g[0]] if 0 <= g[0] < len(m['mats']) else None
            n = g[2] if len(g) > 2 else len(m['tris'])
            rows.append(dict(mesh=m['name'], slot=slot, page=(pages or {}).get(slot), tris=int(n)))
    return rows


def expected_parts(info, name='mesh_{i}_{g}'):
    """what a review scene of this GR2 must hold: one part per bound mesh group, {id, material (slot), tris}; name =
    the scene's object name template ({i} bound mesh, {g} group: the runtime-preview extract's mesh_<i>_<g>.npz).
    Compare with Blendify composition_gate.diff_parts against scene_inventory.composition()."""
    out = []
    for i, m in enumerate(info['render']):
        for g, gr in enumerate(m['groups'] or [(0, 0, len(m['tris']))]):
            slot = m['mats'][gr[0]] if 0 <= gr[0] < len(m['mats']) else None
            out.append(dict(id=name.format(i=i, g=g, mesh=m['name']), material=slot,
                            tris=int(gr[2] if len(gr) > 2 else len(m['tris']))))
    return out


def page_mesh(info, pages, page):
    """every bound triangle on the slots that bind `page` -> (pos, tris, slots)"""
    slots = sorted(s for s, p in pages.items() if p == page)
    P, T, base = [], [], 0
    for m in info['render']:
        groups = m['groups'] or [(0, 0, len(m['tris']))]
        for g in groups:
            if not (0 <= g[0] < len(m['mats'])) or m['mats'][g[0]] not in slots:
                continue
            first, n = (g[1], g[2]) if len(g) > 2 else (0, len(m['tris']))
            t = np.asarray(m['tris'], np.int64)[first:first + n]
            P.append(np.asarray(m['pos'], float)); T.append(t + base); base += len(m['pos'])
    if not P:
        return np.zeros((0, 3)), np.zeros((0, 3), np.int64), slots
    return np.concatenate(P), np.concatenate(T), slots


def find_gate():
    """the generic composition gate: $BLENDIFY_REPO/.claude/skills/..., else this repo's skill link; None = not found"""
    sys.path.append(str(HERE.parent / 'tools'))
    import local_env
    roots = [Path(v) / '.claude' / 'skills' for v in [local_env.value('BLENDIFY_REPO')] if v]
    roots.append(HERE.parents[1] / '.claude' / 'skills')
    for r in roots:
        p = r / GATE
        if p.is_file():
            spec = importlib.util.spec_from_file_location('composition_gate', str(p))
            mod = importlib.util.module_from_spec(spec); spec.loader.exec_module(mod)
            return mod
    return None


def groups_of(manifest):
    return {p['id']: dict(points=(np.asarray(p['points_mm'], float) / 1000.0).tolist(), tris=p['tris'], area=p['area'])
            for p in manifest['placements']}


def check_stage(manifest, stage, info, material_path, gate=None):
    """-> (ok True/False/None, message, data) for one manifest stage of an already read GR2"""
    spec = manifest['stages'][stage]; page = manifest['page'].lower()
    pages = slot_pages(material_path) if material_path and Path(material_path).is_file() else {}
    if not pages:
        return False, f"{stage}: material {material_path} missing or without submaterials", {}
    pos, tris, slots = page_mesh(info, pages, page)
    bound = sorted({p for p in pages.values() if p})
    if spec['props'] == 'none':
        ok = not len(tris)
        return ok, (f"{stage}: no triangle on {page} (props none)" if ok else
                    f"{stage}: {len(tris)} triangles on {page} {slots}, the manifest says no props"), dict(tris=len(tris))
    if not slots:
        return False, (f"{stage}: no slot binds the props page {page}; the material binds {bound} (wrong page version "
                       f"or the props were dropped)"), dict(pages=pages)
    gate = gate or find_gate()
    if gate is None:
        return None, f"{stage}: Blendify {GATE} not found ($BLENDIFY_REPO unset?): props not proven", {}
    res = gate.match_groups(groups_of(manifest), pos, tris)
    res['slots'] = slots; res['page'] = page
    return res['ok'], f"{stage}: {page} on {slots}: {res['summary']}", res


def manifest_path(prof):
    """the profile's props_manifest.path: $VARIABLES from this device's local env, else relative to the profile repo"""
    text = (prof.get('props_manifest') or {}).get('path')
    if not text:
        return None, '(no props_manifest.path in the profile)'
    if text.startswith('$'):
        p, missing = gr2_lint.local_path(text)
        return (p, None) if p else (None, f"{', '.join(missing)} not set on this device: python scripts/tools/local_env.py")
    return Path(prof.get('_root') or HERE.parents[1]) / text, None


def lint_check(stage, info, material_path, prof, R):
    """gr2_lint check 'props' for one lint stage (profile key props_manifest)"""
    path, why = manifest_path(prof)
    if path is None or not path.is_file():
        return R(stage, 'props', None, f"props manifest {path or why} not found: the props are not proven (a SKIP is not a "
                                       f"pass)")
    manifest = json.loads(path.read_text(encoding='utf-8'))
    mstage = ((prof.get('props_manifest') or {}).get('stages') or {}).get(stage, stage)
    if mstage not in manifest['stages']:
        return R(stage, 'props', False, f"{path.name} has no stage {mstage}")
    ok, msg, data = check_stage(manifest, mstage, info, material_path)
    return R(stage, 'props', ok, f"{path.name} {msg}", manifest=str(path), **{k: v for k, v in data.items()
                                                                               if k in ('missing', 'partial', 'extra')})


def check(manifest_path_, art_root, stages=None):
    """every (or the named) manifest stage against the files under art_root -> list of (stage, ok, message, data)"""
    manifest = json.loads(Path(manifest_path_).read_text(encoding='utf-8'))
    gate = find_gate(); out = []
    for stage, spec in manifest['stages'].items():
        if stages and stage not in stages:
            continue
        gr2 = Path(art_root) / spec['gr2']; mat = Path(art_root) / spec['material']
        if not gr2.is_file():
            out.append((stage, False, f"{stage}: {gr2} missing", {})); continue
        ok, msg, data = check_stage(manifest, stage, gr2_lint.read_raw(str(gr2)), str(mat), gate)
        out.append((stage, ok, msg, data))
    return out


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    sub = ap.add_subparsers(dest='cmd', required=True)
    c = sub.add_parser('composition'); c.add_argument('gr2'); c.add_argument('material', nargs='?')
    k = sub.add_parser('check'); k.add_argument('manifest'); k.add_argument('--art-root', required=True)
    k.add_argument('--stage', action='append'); k.add_argument('--json')
    a = ap.parse_args(argv)
    if a.cmd == 'composition':
        mat = a.material or str(Path(a.gr2).with_suffix('.material'))
        pages = slot_pages(mat) if Path(mat).is_file() else {}
        for r in composition(gr2_lint.read_raw(a.gr2), pages):
            print(f"{r['mesh']:40s} {str(r['slot']):6s} {str(r['page']):40s} {r['tris']}")
        return 0
    res = check(a.manifest, a.art_root, a.stage)
    for stage, ok, msg, _ in res:
        print({True: 'PASS', False: 'FAIL', None: 'SKIP'}[ok], msg)
    if a.json:
        Path(a.json).write_text(json.dumps([dict(stage=s, ok=o, message=m, **d) for s, o, m, d in res], indent=1,
                                           default=str), encoding='utf-8')
    return 1 if any(o is False for _, o, _, _ in res) else 2 if any(o is None for _, o, _, _ in res) else 0


if __name__ == '__main__':
    sys.exit(main())
