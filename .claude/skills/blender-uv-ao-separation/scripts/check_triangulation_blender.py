"""Run with background Blender. Regression specimen for INC-091.

Checks actual rays against a warped roof quad; increasing offsets or deleting
occluders is not needed. Does not save a mesh or image.
"""
import bpy,json
from mathutils import Vector
from mathutils.bvhtree import BVHTree
P=[(1.100000023841858,.6800000071525574,3.9390087127685547),
   (1.100000023841858,.0982000082731247,3.8988590240478516),
   (1.350000023841858,.0982000082731247,4.1393351554870605),
   (1.350000023841858,.6800000071525574,4.194141864776611)]
m=bpy.data.meshes.new('INC091 nonplanar roof');m.from_pydata(P,[],[(0,1,2,3)]);m.update();m.calc_loop_triangles()
triangles=[list(t.vertices) for t in m.loop_triangles]
old=BVHTree.FromPolygons(P,[(0,1,2,3)])
fixed=BVHTree.FromPolygons(P,triangles,all_triangles=True)
old_hits=0;fixed_hits=0
for tri in triangles:
 a,b,c=[Vector(P[i]) for i in tri];n=(b-a).cross(c-a).normalized()
 for w in [(1/3,1/3,1/3),(.23,.31,.46),(.6,.2,.2),(.2,.6,.2)]:
  origin=a*w[0]+b*w[1]+c*w[2]+n*.0003
  old_hits+=old.ray_cast(origin,n,.5)[0] is not None
  fixed_hits+=fixed.ray_cast(origin,n,.5)[0] is not None
assert old_hits>0,'Specimen no longer reproduces divergent implicit tessellation'
assert fixed_hits==0,'Outward rays self-hit: receiver and occluder triangulation differ'
print(json.dumps(dict(test='INC091_warped_quad',implicit_self_hits=old_hits,explicit_self_hits=fixed_hits,offset=.0003,status='PASS')))
