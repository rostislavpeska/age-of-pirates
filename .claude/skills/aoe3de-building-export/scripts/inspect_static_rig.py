"""Read-only Blender static-building audit; never rigs or exports.
blender model.blend -b --python inspect_static_rig.py -- --out report.json --objects MeshA MeshB
Without --objects inspect all scene meshes; restrict scope when reference meshes exist.
"""
import argparse
import json
import math
import sys
from pathlib import Path
import bpy


def inspect(objects, expected_materials):
    rows = []
    for obj in objects:
        issues = []
        mesh = obj.data
        modifiers = [m for m in obj.modifiers if m.type == 'ARMATURE' and m.show_viewport]
        arm = modifiers[0].object if len(modifiers) == 1 else None
        if not arm or arm.type != 'ARMATURE':
            issues.append('Exactly one enabled Armature modifier targeting an ARMATURE is required')
        bones = {b.name for b in arm.data.bones if b.use_deform} if arm and arm.type == 'ARMATURE' else set()
        names = {g.index: g.name for g in obj.vertex_groups}
        bad_vertices = []
        for v in mesh.vertices:
            valid = [g.weight for g in v.groups if names.get(g.group) in bones]
            other = [g for g in v.groups if g.weight > 0 and names.get(g.group) not in bones]
            if other or not valid or any(not math.isfinite(w) or w < 0 for w in valid) or abs(sum(valid)-1) > 1e-5:
                bad_vertices.append(v.index)
        if bad_vertices:
            issues.append(f'{len(bad_vertices)} vertices have missing/invalid deform weights')
        if len(mesh.uv_layers) != 1:
            issues.append('Export copy must have one intended UV layer')
        if len(mesh.color_attributes):
            issues.append('Color layers need explicit compatibility review before export')
        mats = [s.material.name if s.material else None for s in obj.material_slots]
        if any(n not in expected_materials for n in mats):
            issues.append(
                'Unexpected/empty material slot; expected only '
                + ', '.join(sorted(expected_materials))
            )
        if any(p.material_index >= len(mats) for p in mesh.polygons):
            issues.append('Invalid polygon material index')
        rows.append(dict(object=obj.name, vertices=len(mesh.vertices),
                         triangles=sum(len(p.vertices)-2 for p in mesh.polygons),
                         armature=arm.name if arm else None,
                         bones=sorted(bones), material_slots=mats,
                         world_matrix=[list(r) for r in obj.matrix_world],
                         invalid_weight_vertices=bad_vertices, issues=issues))
    return rows


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--out', required=True)
    p.add_argument('--objects', nargs='+')
    p.add_argument('--materials', nargs='+', default=['mata', 'matb', 'matc'],
                   help='accepted material slot names for the target export profile')
    args = p.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    objects = [o for o in bpy.context.scene.objects if o.type == 'MESH' and (not args.objects or o.name in args.objects)]
    if not objects or set(args.objects or []) - {o.name for o in objects}:
        raise ValueError('Empty or incomplete object scope')
    rows = inspect(objects, set(args.materials))
    report = dict(file=bpy.data.filepath, scene=bpy.context.scene.name, objects=rows,
                  passed=not any(r['issues'] for r in rows),
                  limitations='Source mesh audit only; verify evaluated mesh, bind matrices and serialized FBX/GR2 separately')
    Path(args.out).write_text(json.dumps(report, indent=2), encoding='utf-8')
    print(json.dumps({'passed': report['passed'], 'objects': len(rows)}))
    if not report['passed']:
        raise SystemExit(2)
