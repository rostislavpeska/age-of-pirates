"""Blender-side texture-set coherence check (rule 1 of scripts/havok/texture_sets.py) for review / preview scenes.

Every material: the images feeding Principled Base Color (directly or through mix nodes), Normal (through a Normal
Map node) and the masks (an image whose channels feed Roughness / AO) are identified against config/texture_sets.json
by file hash (on disk or packed), a 12-hex hash prefix in the image name, or a registered alias. One material must take
its channels from ONE registered set and never from a retired one. Unregistered images are listed, never guessed.

Background (saved file, read-only):
    blender -b <file.blend> --python blender_texture_sets.py -- <out.json> [<aop repo root> [<registry json>]]
The registry defaults to AoP's config/texture_sets.json; pass the project's own (e.g. the Koreans add-on
tools/texture_sets.json) for its scenes.
Live (owner's Blender through the MCP, read-only): exec this file with OUT=None, it returns the report dict.
Exit / result: errors == [] means coherent. Writes nothing into the .blend.
"""
import hashlib
import json
import sys
from pathlib import Path

import bpy


def _repo(argv_root=None):
    if argv_root:
        return Path(argv_root)
    here = Path(__file__).resolve()
    return here.parents[4]          # .claude/skills/<skill>/scripts/<this>


def _image_hash(img):
    try:
        if img.packed_file is not None:
            return hashlib.sha256(bytes(img.packed_file.data)).hexdigest()
        p = Path(bpy.path.abspath(img.filepath)) if img.filepath else None
        if p and p.is_file():
            return hashlib.sha256(p.read_bytes()).hexdigest()
    except Exception:
        return None
    return None


def _upstream_images(sock, seen=None):
    """image nodes feeding a socket, through any chain of nodes (mix, separate, normal map...)."""
    seen = seen or set()
    out = []
    for link in getattr(sock, 'links', []):
        n = link.from_node
        if n.as_pointer() in seen:
            continue
        seen.add(n.as_pointer())
        if n.type == 'TEX_IMAGE' and n.image is not None:
            out.append(n.image)
        for s in n.inputs:
            out += _upstream_images(s, seen)
    return out


def scan(repo_root=None, registry=None):
    root = _repo(repo_root)
    sys.path.insert(0, str(root / 'scripts' / 'havok'))
    import texture_sets as TS
    reg = TS.load_registry(registry or root / 'config' / 'texture_sets.json')
    report = dict(file=bpy.data.filepath, registry_sets=len(reg['_sets']) if reg else 0, materials=[], errors=[], unregistered=[])
    for mat in bpy.data.materials:
        if not mat.use_nodes or mat.node_tree is None:
            continue
        bsdf = next((n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED'), None)
        if bsdf is None:
            continue
        roles = {'basecolor': _upstream_images(bsdf.inputs['Base Color'])}
        roles['normals'] = _upstream_images(bsdf.inputs['Normal'])
        masks = []
        for name in ('Roughness', 'Metallic', 'Specular IOR Level', 'Alpha'):
            if name in bsdf.inputs:
                masks += _upstream_images(bsdf.inputs[name])
        roles['masks'] = [m for m in masks if m not in roles['basecolor']]
        bound, rows = {}, []
        for role, imgs in roles.items():
            for img in imgs:
                hit = TS.set_of_image(reg, img.name, _image_hash(img)) or TS.set_of_image(reg, Path(img.filepath or '').name)
                rows.append(dict(role=role, image=img.name, set=hit[0] if hit else None, channel=hit[1] if hit else None))
                if hit:
                    bound.setdefault(f'{role}:{img.name}', hit[0])
                else:
                    report['unregistered'].append(f'{mat.name}: {role} <- {img.name}')
        users = [s.name for s in bpy.data.scenes if any(o.type == 'MESH' and any(sl.material == mat for sl in o.material_slots) for o in s.objects)]
        errs = TS.binding_findings(bound, reg, f'material "{mat.name}" (scenes {users})') if reg else []
        report['materials'].append(dict(material=mat.name, scenes=users, images=rows, errors=errs))
        report['errors'] += errs
    return report


if __name__ == '__main__':
    argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
    rep = scan(argv[1] if len(argv) > 1 else None, argv[2] if len(argv) > 2 else None)
    if argv:
        Path(argv[0]).write_text(json.dumps(rep, indent=1), encoding='utf-8')
    print('TEXTURE_SETS', 'errors', len(rep['errors']), 'materials', len(rep['materials']), 'unregistered', len(rep['unregistered']), flush=True)
    for e in rep['errors'][:20]:
        print('  ERROR', e, flush=True)
