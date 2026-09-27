"""Run in the frozen input copy: --python blender_export.py -- S9_faces.json out.

Read-only export; input scene and its geometry are not changed.
"""
import bpy,json,sys
from pathlib import Path
args=sys.argv[sys.argv.index('--')+1:];metadata=Path(args[0]);out=Path(args[1]);out.mkdir(parents=True,exist_ok=True)
meta={f['id']:f for f in json.loads(metadata.read_text())};result=[]
for ob in bpy.data.scenes['S12_Groups'].objects:
    if ob.type!='MESH':continue
    me=ob.data;ids=json.loads(ob['source_face_ids']);uv=me.uv_layers['UVMap'];me.calc_loop_triangles();tris={p.index:[] for p in me.polygons}
    for t in me.loop_triangles:tris[t.polygon_index].append([list(me.polygons[t.polygon_index].loop_indices).index(l) for l in t.loops])
    for p,fid in zip(me.polygons,ids):
        x=meta[fid].copy();x.update(points=[list(ob.matrix_world@me.vertices[v].co) for v in p.vertices],uv=[list(uv.data[l].uv) for l in p.loop_indices],normal=list(p.normal),triangles=tris[p.index],corner_normals=[list(me.corner_normals[l].vector) for l in p.loop_indices],mesh_vertices=list(p.vertices),mesh=ob.name)
        result.append(x)
(out/'faces.json').write_text(json.dumps(result))
