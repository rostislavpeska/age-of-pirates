"""Read-only base-mesh snapshot. Call snapshot() through the verified Blender API."""
import hashlib
import json
from pathlib import Path

import numpy as np


def snapshot(objects, output_dir, dataset, material_map):
    """material_map: every material name -> {physical_material: str, alpha: bool}."""
    if not objects or any(o.type != 'MESH' for o in objects):
        raise ValueError('Pass an explicit nonempty list of mesh objects.')
    out = Path(output_dir)
    out.mkdir(parents=True, exist_ok=True)
    paths = [out / (dataset + s) for s in ('_faces.json', '_geometry.npz', '_snapshot.json')]
    if any(p.exists() for p in paths):
        raise FileExistsError('Choose a new dataset name; immutable snapshot already exists.')
    faces, triangles, face_ids, hashes = [], [], [], {}
    for obj in objects:
        if obj.mode != 'OBJECT' or any(m.show_viewport for m in obj.modifiers):
            raise ValueError(f'{obj.name}: use base Object-mode mesh or prepare an explicit analysis copy with source mapping.')
        mesh = obj.data
        coordinates = [[*v.co] for v in mesh.vertices]
        polygon_vertices = [list(p.vertices) for p in mesh.polygons]
        uv = {layer.name: [[*v.uv] for v in layer.data] for layer in mesh.uv_layers}
        payload = {'coordinates': coordinates, 'polygons': polygon_vertices, 'uv': uv, 'matrix_world': [list(r) for r in obj.matrix_world]}
        hashes[obj.name] = hashlib.sha256(json.dumps(payload, sort_keys=True).encode()).hexdigest()
        mesh.calc_loop_triangles()  # Cache only; does not change authoring polygons.
        by_polygon = [[] for _ in mesh.polygons]
        for tri in mesh.loop_triangles:
            by_polygon[tri.polygon_index].append(tri)
        for p in mesh.polygons:
            mat = obj.material_slots[p.material_index].material if p.material_index < len(obj.material_slots) else None
            key = mat.name if mat else ''
            if key not in material_map:
                raise ValueError(f'Unclassified material {key!r} on {obj.name}; no alpha/material inference allowed.')
            spec = material_map[key]
            if not isinstance(spec.get('alpha'), bool) or not spec.get('physical_material'):
                raise ValueError(f'Material {key!r} needs explicit alpha boolean and physical family.')
            fid = len(faces)
            tris = np.array([[tuple(obj.matrix_world @ mesh.vertices[v].co) for v in t.vertices] for t in by_polygon[p.index]], float)
            cross = np.cross(tris[:, 1] - tris[:, 0], tris[:, 2] - tris[:, 0])
            norm = cross.sum(0)
            if np.linalg.norm(norm) < 1e-12 or np.any(np.linalg.norm(cross, axis=1) < 1e-12):
                raise ValueError(f'Degenerate analysis polygon {obj.name}:{p.index}.')
            inds = list(range(len(triangles), len(triangles) + len(tris)))
            triangles.extend(tris.tolist()); face_ids.extend([fid] * len(tris))
            faces.append({'id': fid, 'object': obj.name, 'polygon': p.index, 'part': obj.name,
                          'points': [tuple(obj.matrix_world @ mesh.vertices[v].co) for v in p.vertices],
                          'normal': (norm / np.linalg.norm(norm)).tolist(), 'area': float(np.linalg.norm(cross, axis=1).sum() / 2),
                          'triangles': inds, 'alpha': spec['alpha'], 'physical_material': spec['physical_material'],
                          'old_material': key, 'label': -1})
    opaque = np.array([i for i, fid in enumerate(face_ids) if not faces[fid]['alpha']], np.int64)
    if not len(opaque):
        raise ValueError('This method needs nonempty opaque geometry.')
    fingerprint = hashlib.sha256(json.dumps({'hashes': hashes, 'materials': material_map}, sort_keys=True).encode()).hexdigest()
    paths[0].write_text(json.dumps(faces), encoding='utf-8')
    np.savez_compressed(paths[1], triangles=np.asarray(triangles), face_ids=np.asarray(face_ids), opaque=opaque)
    manifest = {'fingerprint': fingerprint, 'object_geometry_uv_hashes': hashes, 'material_contract': material_map,
                'face_count': len(faces), 'analysis_triangle_count': len(triangles), 'source_modified': False,
                'world_up': 'Z', 'evaluated_modifiers': False}
    paths[2].write_text(json.dumps(manifest, indent=2), encoding='utf-8')
    return manifest
