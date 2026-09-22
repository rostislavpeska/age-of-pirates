"""Read-only Blender audit. blender file.blend -b --python audit_mesh.py -- --out report.json
No save/export. Evaluated mesh counts exclude unrealized Geometry Nodes instances.
Corner-split estimate is not a serialized FBX/GR2 count. Density is px/scene-meter.
"""
import argparse
import json
import math
import sys
from pathlib import Path
import bpy


def audit(args):
    scene = bpy.context.scene
    scale = scene.unit_settings.scale_length
    if not math.isfinite(scale) or scale <= 0:
        raise ValueError('Invalid scene unit scale')
    objects = [o for o in scene.objects if o.type == 'MESH'
               and (not args.objects or o.name in args.objects)]
    missing = set(args.objects or []) - {o.name for o in objects}
    if missing or not objects:
        raise ValueError(f'Missing mesh targets or empty scope: {sorted(missing)}')
    rows = []
    graph = bpy.context.evaluated_depsgraph_get()
    for obj in objects:
        evaluated = obj.evaluated_get(graph)
        mesh = evaluated.to_mesh()
        try:
            mesh.calc_loop_triangles()
            used_edges = {tuple(sorted(k)) for p in mesh.polygons for k in p.edge_keys}
            linked = {v for e in mesh.edges for v in e.vertices}
            uv = mesh.uv_layers.active
            densities = []
            split = set()
            degenerate = 0
            for tri in mesh.loop_triangles:
                points = [evaluated.matrix_world @ mesh.vertices[i].co for i in tri.vertices]
                area = (points[1] - points[0]).cross(points[2] - points[0]).length * .5 * scale**2
                if area <= 1e-14:
                    degenerate += 1
                if uv and area > 1e-14:
                    a, b, c = [uv.data[i].uv for i in tri.loops]
                    ua = abs((b.x-a.x)*(c.y-a.y)-(b.y-a.y)*(c.x-a.x)) * .5
                    densities.append(args.resolution * math.sqrt(ua/area))
                for li in tri.loops:
                    split.add((mesh.loops[li].vertex_index, tri.material_index,
                               tuple(round(x, 6) for x in uv.data[li].uv) if uv else (),
                               tuple(round(x, 6) for x in mesh.corner_normals[li].vector)))
            densities.sort()
            rows.append(dict(object=obj.name, source_vertices=len(obj.data.vertices),
                             evaluated_vertices=len(mesh.vertices), polygons=len(mesh.polygons),
                             triangles=len(mesh.loop_triangles), estimated_split_vertices=len(split),
                             loose_vertices=sum(v.index not in linked for v in mesh.vertices),
                             loose_edges=sum(tuple(sorted(e.vertices)) not in used_edges for e in mesh.edges),
                             degenerate_triangles=degenerate,
                             uv_layers=[u.name for u in mesh.uv_layers],
                             density_min=min(densities) if densities else None,
                             density_p10=densities[int((len(densities)-1)*.1)] if densities else None,
                             density_median=densities[len(densities)//2] if densities else None))
        finally:
            evaluated.to_mesh_clear()
    total = sum(r['evaluated_vertices'] for r in rows)
    limit = args.budget + args.tolerance
    return dict(file=bpy.data.filepath, scene=scene.name, unit_scale=scale,
                scope=[o.name for o in objects], objects=rows, total_evaluated_vertices=total,
                budget=args.budget, tolerance=args.tolerance,
                budget_status='approval_required' if total > limit else 'tolerance' if total > args.budget else 'within_target',
                limitations=['No intersection or semantic-region validation',
                             'No count of unrealized Geometry Nodes instances',
                             'Density assumes scene units represent meters; calibrate actual project scale',
                             'Export split counts are estimates, not engine limits'])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', required=True)
    parser.add_argument('--objects', nargs='+')
    parser.add_argument('--budget', type=int, default=20000)
    parser.add_argument('--tolerance', type=int, default=5000)
    parser.add_argument('--resolution', type=int, default=2048)
    args = parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    if min(args.budget, args.tolerance) < 0 or args.resolution <= 0:
        parser.error('Budget/tolerance must be nonnegative; resolution must be positive')
    result = audit(args)
    Path(args.out).parent.mkdir(parents=True, exist_ok=True)
    Path(args.out).write_text(json.dumps(result, indent=2), encoding='utf-8')
    print(json.dumps({k: result[k] for k in ['total_evaluated_vertices', 'budget_status']}))
    if result['budget_status'] == 'approval_required':
        raise SystemExit(2)


if __name__ == '__main__':
    main()
