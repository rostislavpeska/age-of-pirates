"""Run on an isolated Blender worker; measures arrays without changing any scene."""
import json,math,time
from pathlib import Path
import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from sampling import camera_directions,triangle_samples

def measure(directory,name,cfg):
    if not bpy.app.background:
        raise RuntimeError('Use an isolated background worker; do not block the interactive Blender UI.')
    if cfg.get('ray_samples_per_triangle',7)!=7:
        raise ValueError('This tested implementation uses seven samples; other counts are not implemented.')
    OUT=Path(directory)
    start=time.time();g=np.load(OUT/(name+'_geometry.npz'));ts=g['triangles'];fids=g['face_ids'];opaque=g['opaque']
    fs=json.loads((OUT/(name+'_faces.json')).read_text());xyz=ts[opaque]
    bvh=BVHTree.FromPolygons(xyz.reshape(-1,3).tolist(),np.arange(len(xyz)*3).reshape(-1,3).tolist(),all_triangles=True)
    diag=np.linalg.norm(ts.max((0,1))-ts.min((0,1)));eps=diag*2e-7
    dirs=camera_directions(cfg['primary_camera_elevations'],cfg['primary_azimuths'])
    stress=camera_directions(cfg['stress_elevations'],24,math.pi/24)
    records=[];rays=0
    for f in fs:
        n=np.array(f['normal']);tris=ts[f['triangles']]
        sam=triangle_samples(tris,edge_fraction=.015);weights=np.repeat(np.linalg.norm(np.cross(tris[:,1]-tris[:,0],tris[:,2]-tris[:,0]),axis=1),7);weights/=weights.sum()
        maxvis=0.;meanvis=0.;stressvis=0.;hits={}
        for di,d in enumerate(np.concatenate([dirs,stress])):
            exposure=0.;direction=Vector(d)
            for j,p in enumerate(sam):
                rays+=1;hit,hn,idx,distance=bvh.ray_cast(Vector(p+d*eps),direction,diag*4)
                if hit is None:exposure+=weights[j]
                elif di<len(dirs):
                    target=int(fids[opaque[idx]])
                    if target!=f['id']:hits[target]=hits.get(target,0)+1
            if di<len(dirs):maxvis=max(maxvis,exposure);meanvis+=exposure/len(dirs)
            else:stressvis=max(stressvis,exposure)
        pairs=[];dists=[];samepart=[]
        if n[2]<-.05:
            direction=Vector((0,0,1))
            for p in sam:
                rays+=1;hit,hn,idx,distance=bvh.ray_cast(Vector(p+np.array([0,0,eps])),direction,cfg['pair_max_distance_world'])
                good=hit is not None and hn.z>.15 and distance>eps*2
                pairs.append(good);dists.append(float(distance) if good else -1)
                samepart.append(bool(good and fs[int(fids[opaque[idx]])]['part']==f['part']))
        records.append({'id':f['id'],'max_exposure':maxvis,'mean_exposure':meanvis,'stress_max_exposure':stressvis,
                        'pair_coverage':float(np.mean(pairs)) if pairs else 0,'pair_same_part':float(np.mean(samepart)) if pairs else 0,
                        'pair_distances':dists,'hit_neighbors':hits})
        if f['id']%500==0:(OUT/'ray_progress.json').write_text(json.dumps({'dataset':name,'face':f['id'],'rays':rays,'seconds':time.time()-start}))
    summary={'seconds':time.time()-start,'rays':rays,'directions':len(dirs),'stress_directions':len(stress),'epsilon':eps}
    (OUT/(name+'_rays.json')).write_text(json.dumps({'summary':summary,'faces':records}))
    return summary
