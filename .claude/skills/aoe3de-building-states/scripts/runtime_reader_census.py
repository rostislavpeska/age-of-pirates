"""Read-only, complete serialized triangle/material/UV census.

Audit: 2026-10-13-codex-roof-pattern-80; INC-334. Reuses gr2_lint's decoder.
Raw positions stay in the serialized model frame; no inferred rest transform.
Use --allow-native for a configured, headless DLL decode of compressed files.
No fallback to a different model. Not an animfile routing or visibility proof.
Submaterial names match case-insensitively, as in the game (audit
2026-10-17-claude-opus-5.5 harness-fixes-02): vanilla japan_consulate_age2.material
declares matA/matB/matC while its GR2 binds mata/matb/matc.
"""
import argparse
import hashlib
import json
import sys
import time
import xml.etree.ElementTree as ET
from pathlib import Path
import numpy as np

REPO = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(REPO / 'scripts/havok'))
import gr2_lint as L


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def collect(info, bindings):
    positions, uvs, materials, mesh_ids, tri_ids, bones = [], [], [], [], [], []
    mesh_rows = []
    for mesh_id, mesh in enumerate(info['render']):
        tris = np.asarray(mesh['tris'], dtype=np.int64)
        if mesh['uv'] is None or not np.isfinite(mesh['uv']).all():
            raise ValueError(f'Missing/nonfinite UV: {mesh["name"]}')
        coverage = np.zeros(len(tris), np.int64)
        names = np.full(len(tris), '', dtype='U128')
        for material_index, first, count in mesh['groups']:
            if not (0 <= material_index < len(mesh['mats']) and first >= 0 and count >= 0 and first + count <= len(tris)):
                raise ValueError('Invalid material group bounds')
            name = mesh['mats'][material_index]
            if name not in bindings:
                raise ValueError(f'Missing material binding: {name}')
            names[first:first+count] = name
            coverage[first:first+count] += 1
        if np.any(coverage != 1):
            raise ValueError(f'Uncovered or multiply assigned triangles: {mesh["name"]}')
        positions.append(mesh['pos'][tris])
        uvs.append(mesh['uv'][tris])
        materials.append(names)
        mesh_ids.append(np.full(len(tris), mesh_id, dtype=np.int64))
        tri_ids.append(np.arange(len(tris), dtype=np.int64))
        # Corner indices are retained; a dominant-bone choice is not fragment proof.
        bones.append(mesh['bone'][tris])
        mesh_rows.append(dict(id=mesh_id, name=mesh['name'], triangles=len(tris),
                              bone_names=mesh['bone_names'], groups=mesh['groups'],
                              material_bindings=mesh['mats'], layout=mesh.get('layout', [])))
    if not positions:
        raise ValueError('No bound render triangles')
    return dict(position=np.concatenate(positions), uv_raw=np.concatenate(uvs),
                material=np.concatenate(materials), mesh=np.concatenate(mesh_ids),
                triangle=np.concatenate(tri_ids), bone=np.concatenate(bones)), mesh_rows


def match_bindings(info, bindings):
    """Key the material file's submaterials by the spelling the GR2 meshes bind.

    The game resolves a mesh's material name case-insensitively, so a declared
    'matA' serves a bound 'mata'; the entry then records declared_name='matA'.
    Declared submaterials that no mesh binds keep their own spelling.
    """
    bound = {}
    for mesh in info['render']:
        for name in mesh['mats']:
            bound.setdefault(name.casefold(), set()).add(name)
    result = {}
    for declared, entry in bindings.items():
        for name in sorted(bound.get(declared.casefold(), ())) or [declared]:
            result[name] = entry if name == declared else dict(entry, declared_name=declared)
    return result


def material_bindings(path, art_root):
    result, folded = {}, {}
    for sub in ET.parse(path).getroot().findall('submaterial'):
        name = sub.attrib['name']
        if name.casefold() in folded:
            raise ValueError(f'Duplicate material name (the game matches case-insensitively): '
                             f'{folded[name.casefold()]}, {name}')
        folded[name.casefold()] = name
        textures = {}
        for tex in sub.findall('./parameters/texture'):
            ref = tex.attrib.get('override')
            if not ref:
                raise ValueError('Texture without explicit reference')
            local = art_root / (ref.replace('\\', '/') + '.ddt')
            textures[tex.attrib['name']] = dict(reference=ref,
                source='local' if local.is_file() else 'archive_or_unresolved',
                sha256=sha(local) if local.is_file() else None)
        definition = sub.find('materialdef')
        result[name] = dict(shader=definition.attrib.get('name') if definition is not None else None,
                            textures=textures)
    return result


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('--model', type=Path, required=True)
    ap.add_argument('--material', type=Path, required=True)
    ap.add_argument('--art-root', type=Path, required=True)
    ap.add_argument('--out', type=Path, required=True)
    ap.add_argument('--allow-native', action='store_true')
    args = ap.parse_args()
    if args.out.exists():
        raise ValueError('Output already exists; retain prior census')
    args.out.mkdir(parents=True)
    started = time.monotonic()
    source_hash, material_hash = sha(args.model), sha(args.material)
    dll = None
    if L.header(args.model).get('compressed'):
        if not args.allow_native:
            raise ValueError('Compressed model requires explicit --allow-native')
        cfg = json.loads((REPO / 'config/gr2_lint_military.json').read_text())
        dll = L.dll_read(args.model, L.find_tools(cfg), args.out)
        if dll['status'] != 'PASS':
            raise ValueError('Native decode failed: ' + repr(dll))
    info = L.load(args.model, dll)
    if not info['header']['crc_ok']:
        raise ValueError('Source CRC failure')
    bindings = match_bindings(info, material_bindings(args.material, args.art_root))
    arrays, meshes = collect(info, bindings)
    np.savez_compressed(args.out / 'READERS.npz', **arrays)
    values, counts = np.unique(arrays['material'], return_counts=True)
    report = dict(schema=1, status='PASS', source_file=args.model.name, source_sha256=source_hash,
        material_file=args.material.name, material_sha256=material_hash, decoder=info['source'],
        decoder_sha256=sha(REPO / 'scripts/havok/gr2_lint.py'),
        script_sha256=sha(__file__), dll=dll, meshes=meshes, bindings=bindings,
        triangles_by_material=dict(zip(values.tolist(), counts.tolist())),
        triangle_count=len(arrays['material']), arrays_sha256=sha(args.out/'READERS.npz'),
        conventions=dict(positions='raw serialized model coordinates',uv='raw GR2; Blender V is 1-raw V',
            bones='dominant per corner as decoded by gr2_lint; not complete blended skin weights'),
        limitations=['No asset/state routing, visibility, frame correspondence or release proof.',
                    'All bound render triangles counted; unbound meshes excluded explicitly.',
                    'Unresolved archive textures require external archive evidence.'],
        audit='2026-10-13-codex-roof-pattern-80; INC-334', seconds=time.monotonic()-started)
    assert source_hash == sha(args.model) and material_hash == sha(args.material)
    (args.out/'CENSUS.json').write_text(json.dumps(report, indent=2)+'\n')
    print(json.dumps({k:report[k] for k in ('status','source_file','source_sha256','triangle_count','triangles_by_material','seconds')}))


if __name__ == '__main__':
    main()
