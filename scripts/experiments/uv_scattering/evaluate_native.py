import json
from pathlib import Path
import sys
import numpy as np
from experiment import islands, metrics, colors, signed_area, contact_layout

folder=Path(sys.argv[1]);faces=json.loads((folder/'faces.json').read_text())
edges=json.loads((folder/'adjacency.json').read_text())['edges']
results=json.loads((folder/'results.json').read_text())
for name in ['ABF','Smart']:
    raw=json.loads((folder/(name+'_raw.json')).read_text())
    uv=[np.array(raw[str(f['id'])]) for f in faces]
    # Restore each chart's area scale to the baseline, without hiding anisotropy.
    for g in islands(faces,edges,uv):
        if faces[g[0]]['hidden']:continue
        before=sum(abs(signed_area(np.array(faces[i]['uv']))) for i in g)
        after=sum(abs(signed_area(uv[i])) for i in g)
        if after>1e-15:
            scale=np.sqrt(before/after)
            for i in g:uv[i]*=scale
    uv=contact_layout(faces,edges,uv)
    c=colors(faces,edges,uv)
    (folder/(name+'.json')).write_text(json.dumps({str(f['id']):dict(uv=q.tolist(),**c[str(f['id'])]) for f,q in zip(faces,uv)}))
    m=metrics(faces,edges,uv)
    part={}
    for g in islands(faces,edges,uv):
        if faces[g[0]]['hidden']:continue
        x=part.setdefault(faces[g[0]]['part'],dict(charts=0,singletons=0,faces=0))
        x['charts']+=1;x['singletons']+=len(g)==1;x['faces']+=len(g)
    results[name]={'metrics':m,'by_part':part,'details':{'solver':'Blender 5.0.1 '+name,'scale':'chart area restored, per-face density not guaranteed'}}
    print(name,json.dumps({k:v for k,v in m.items() if not isinstance(v,list)}))
(folder/'results.json').write_text(json.dumps(results,indent=2))
