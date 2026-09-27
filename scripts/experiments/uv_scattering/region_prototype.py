"""Policy-driven roof candidates, preserving unrelated previous candidate UVs."""
import json,sys,math,copy
from pathlib import Path
from collections import Counter,defaultdict
import numpy as np
from shapely.geometry import Polygon
from shapely.strtree import STRtree
from experiment import islands,local_projection,uv_joined,contact_layout,colors,metrics

def solve(faces,edges,previous,policies,broad=False):
    f=copy.deepcopy(faces);uv=[np.array(previous[str(x['id'])]['uv']) for x in f]
    regions=policies['regions'];reports={}
    for part,policy in regions.items():
        selected=[i for i,x in enumerate(f) if x['part']==part];ss=set(selected)
        # One candidate chart cannot span multiple atlas pages. Allocate a new
        # diagnostic page for this whole region without changing original flags.
        for i in selected:f[i]['page']='REGION_'+part;f[i]['hidden']=False
        # Preserve coherent existing visible charts; initialize hidden faces
        # independently because their shared backing coordinates are not unwraps.
        visible_edges=[e for e in edges if e['a'] in ss and e['b'] in ss and not faces[e['a']]['hidden'] and not faces[e['b']]['hidden']]
        old=[np.array(x['uv']) for x in faces]
        seeds=[g for g in islands(f,visible_edges,old) if g[0] in ss]
        lengths=[]
        for i in selected:
            if faces[i]['hidden']:continue
            p=np.array(faces[i]['points']);q=old[i]
            for j in range(len(p)):
                den=np.linalg.norm(p[(j+1)%len(p)]-p[j])
                if den>1e-6:lengths.append(np.linalg.norm(q[(j+1)%len(q)]-q[j])/den)
        density=float(np.median(lengths));members={};owner={};seed_id=0;repaired=[]
        for g in seeds:
            polys=[Polygon(old[i]) for i in g]
            valid=not any(faces[i]['hidden'] for i in g) and all(p.is_valid and p.area>1e-13 for p in polys)
            if valid:
                tree=STRtree(polys)
                valid=not any(p.intersection(polys[int(j)]).area>1e-11 for k,p in enumerate(polys) for j in tree.query(p) if j>k)
            split=[g] if valid else [[i] for i in g]
            if not valid and len(g)>1:repaired.extend(faces[i]['id'] for i in g)
            for group in split:
                members[seed_id]=group
                for i in group:
                    owner[i]=seed_id
                    uv[i]=old[i].copy() if valid else local_projection(faces[i])*density
                seed_id+=1
        counts=Counter();witnesses=[];reflections=0
        ordered=[e for e in edges if e['a'] in ss and e['b'] in ss]
        # Reasoning prefers attaching the underside to a broad roof region.
        # Smooth internal construction edges remain earlier than sharp folds.
        ordered.sort(key=lambda e:(1-round(float(np.dot(f[e['a']]['normal'],f[e['b']]['normal'])),3),-e['length'],e['a'],e['b']))
        angle=175 if broad else policy['max_fold_degrees'];limit=360 if broad else policy['max_faces']
        for e in ordered:
            e=dict(e)
            a,b=e['a'],e['b'];ga,gb=owner[a],owner[b]
            if ga==gb:continue
            # Let an all-hidden provisional chart adopt the adjoining visible
            # chart's density. Never rescale an existing visible chart.
            if all(faces[i]['hidden'] for i in members[ga]) and not all(faces[i]['hidden'] for i in members[gb]):
                a,b=b,a;ga,gb=gb,ga
                e.update(a=a,b=b,ai=e['bi'],aj=e['bj'],bi=e['ai'],bj=e['aj'])
            if len(members[ga])+len(members[gb])>limit:counts['region_chart_size_limit']+=1;continue
            if np.dot(f[a]['normal'],f[b]['normal'])<math.cos(math.radians(angle)):counts['regional_fold_limit']+=1;continue
            va=uv[a][e['aj']]-uv[a][e['ai']];vb=uv[b][e['bj']]-uv[b][e['bi']]
            la,lb=np.linalg.norm(va),np.linalg.norm(vb)
            if min(la,lb)<1e-10:counts['degenerate_edge']+=1;continue
            scale=1.
            if abs(la-lb)>2e-6:
                if all(faces[i]['hidden'] for i in members[gb]) and .25<=la/lb<=4:
                    scale=la/lb
                else:counts['edge_scale_mismatch']+=1;continue
            alpha=math.atan2(va[1],va[0]);beta=math.atan2(vb[1],vb[0])
            def rot(t):return np.array([[math.cos(t),-math.sin(t)],[math.sin(t),math.cos(t)]])
            ra=rot(alpha);rb=rot(beta)
            pa=[Polygon(uv[i]) for i in members[ga]];tree=STRtree(pa)
            accepted=None
            for reflect in ([False,True] if policy['allow_uv_reflection'] else [False]):
                transform=scale*ra@np.diag([1,-1 if reflect else 1])@rb.T
                offset=uv[a][e['ai']]-uv[b][e['bi']]@transform.T
                proposed={i:uv[i]@transform.T+offset for i in members[gb]}
                pb=[Polygon(proposed[i]) for i in members[gb]]
                if any(not p.is_valid or p.area<=1e-13 for p in pa+pb):continue
                if any(p.intersection(pa[int(j)]).area>1e-11 for p in pb for j in tree.query(p)):continue
                accepted=proposed;reflections+=int(reflect);break
            if accepted is None:counts['overlap_or_invalid_polygon']+=1;continue
            uv_ids=[faces[a]['id'],faces[b]['id']]
            witnesses.append({'faces':uv_ids,'original_hidden_boundary':faces[a]['hidden']!=faces[b]['hidden'],'original_material_boundary':faces[a]['physical_family']!=faces[b]['physical_family'],'reflected':reflect,'hidden_chart_scale':scale})
            for i,q in accepted.items():uv[i]=q;owner[i]=ga
            members[ga].extend(members.pop(gb))
        # Translate only this region; outside regions remain exactly unchanged.
        laid=contact_layout(f,edges,uv)
        for i in selected:uv[i]=laid[i]
        g=[g for g in islands(f,edges,uv) if g[0] in ss]
        reports[part]={'faces':len(selected),'charts':len(g),'singletons':sum(len(x)==1 for x in g),'joined_hidden_boundaries':sum(x['original_hidden_boundary'] for x in witnesses),'joined_material_boundaries':sum(x['original_material_boundary'] for x in witnesses),'reflected_joins':reflections,'rejections':dict(counts),'witnesses':witnesses,'reinitialized_invalid_chart_faces':repaired,'density_for_new_underside_charts':density,'originally_hidden_diagnostic_faces':sum(faces[i]['hidden'] for i in selected)}
    # Color actual sewn coordinate charts, while unrelated parts retain their old colors.
    col=colors(f,edges,uv)
    plan={}
    for i,x in enumerate(f):
        item=dict(uv=uv[i].tolist(),diagnostic_page=x['page'],original_hidden=faces[i]['hidden'],policy_region=x['part'] if x['part'] in regions else '',**(col[str(x['id'])] if x['part'] in regions else {k:previous[str(x['id'])][k] for k in ['chart','color']}))
        plan[str(x['id'])]=item
    return plan,{'regions':reports,'metrics':metrics(f,edges,uv),'note':'Hidden roof faces are included for diagnostic chart construction, not visibility-approved allocation.'},f

if __name__=='__main__':
    source=Path(sys.argv[1]);out=Path(sys.argv[2]);out.mkdir(parents=True,exist_ok=True)
    faces=json.loads((source/'faces.json').read_text());edges=json.loads((source/'adjacency.json').read_text())['edges'];previous=json.loads((source/'Sewn100.json').read_text());policies=json.loads(Path(__file__).with_name('roof_policies.json').read_text())
    for name,broad in [('Regional',False),('RegionalBroad',True)]:
        plan,report,review=solve(faces,edges,previous,policies,broad)
        (out/(name+'.json')).write_text(json.dumps(plan));(out/(name+'_report.json')).write_text(json.dumps(report,indent=2))
        print(name,{k:{a:v[a] for a in ['charts','joined_hidden_boundaries','joined_material_boundaries']} for k,v in report['regions'].items()},flush=True)
    (out/'policy.json').write_text(json.dumps(policies,indent=2))
