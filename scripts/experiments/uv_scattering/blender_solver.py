"""Run only in the isolated laboratory. Analytical proxy, no source mesh edits."""
import bpy
import json
import math
import os
from collections import defaultdict
from pathlib import Path
import numpy as np

out = Path(os.environ['TEMP']) / 'codex-uv-scattering-20260927'
faces = json.loads((out / 'faces.json').read_text())
edges = json.loads((out / 'adjacency.json').read_text())['edges']

def eligible(a,b):
    return (not a['hidden'] and not b['hidden'] and a['part']==b['part']
            and a['page']==b['page'] and a['physical_family']==b['physical_family'])

corners=[(i,j) for i,f in enumerate(faces) if not f['hidden'] for j in range(len(f['points']))]
idx={k:i for i,k in enumerate(corners)}
parent=list(range(len(corners)))
def root(i):
    while parent[i]!=i:
        parent[i]=parent[parent[i]];i=parent[i]
    return i
def join(a,b):parent[root(b)]=root(a)
for e in edges:
    if eligible(faces[e['a']],faces[e['b']]):
        for a,b in [('ai','bi'),('aj','bj')]:join(idx[(e['a'],e[a])],idx[(e['b'],e[b])])
verts=[];roots={};polys=[];face_ids=[]
for k,(i,j) in enumerate(corners):
    r=root(k)
    if r not in roots:roots[r]=len(verts);verts.append(faces[i]['points'][j])
for i,f in enumerate(faces):
    if not f['hidden']:
        polys.append([roots[root(idx[(i,j)])] for j in range(len(f['points']))]);face_ids.append(i)
sc=bpy.data.scenes.new('Solver_Proxy_Only');bpy.context.window.scene=sc
me=bpy.data.meshes.new('Verified_Edge_Proxy');me.from_pydata(verts,[],polys);me.update()
ob=bpy.data.objects.new('Disposable_Solver_Proxy',me);sc.collection.objects.link(ob)
bpy.context.view_layer.objects.active=ob;ob.select_set(True)
print('PROXY',len(verts),len(polys),flush=True)
uv=me.uv_layers.new(name='SolverUV')
links=defaultdict(list)
for p in me.polygons:
    for key in p.edge_keys:links[tuple(sorted(key))].append(p.index)
for edge in me.edges:
    incident=links[tuple(sorted(edge.vertices))]
    # Conservative starting seams; the comparison exposes what this heuristic misses.
    edge.use_seam=len(incident)!=2 or me.polygons[incident[0]].normal.dot(me.polygons[incident[1]].normal)<math.cos(math.radians(65))
bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT')
print('UNWRAP_BEGIN',flush=True)
bpy.ops.uv.unwrap(method='ANGLE_BASED',margin=.001)
bpy.ops.object.mode_set(mode='OBJECT')
uv=me.uv_layers['SolverUV']  # Edit-mode rebuild invalidates the earlier RNA handle.
result={str(f['id']):f['uv'] for f in faces}
for p,i in zip(me.polygons,face_ids):result[str(faces[i]['id'])]=[list(uv.data[l].uv) for l in p.loop_indices]
(out/'ABF_raw.json').write_text(json.dumps(result))
# Smart Project is a second native comparison on exactly the same proxy.
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.uv.smart_project(angle_limit=math.radians(66),island_margin=.001)
bpy.ops.object.mode_set(mode='OBJECT')
uv=me.uv_layers['SolverUV']
for p,i in zip(me.polygons,face_ids):result[str(faces[i]['id'])]=[list(uv.data[l].uv) for l in p.loop_indices]
(out/'Smart_raw.json').write_text(json.dumps(result))
bpy.context.window.scene=bpy.data.scenes['S12_Groups']
bpy.data.scenes.remove(sc)
bpy.data.objects.remove(ob,do_unlink=True);bpy.data.meshes.remove(me)
(out/'solver_done.json').write_text(json.dumps({'ABF':'ANGLE_BASED, virtual-edge proxy, 65 degree seams','Smart':'66 degree smart projection, same proxy','source_edited':False}))
