import json,sys
from pathlib import Path
import numpy as np
from experiment import merge_experiment,metrics,colors,native_edges,islands
p=Path(sys.argv[1]);f=json.loads((p/'faces.json').read_text());e=json.loads((p/'adjacency.json').read_text())['edges']
uv,details=merge_experiment(f,e,100,'strip',protect_normals=True)
m=metrics(f,e,uv);native=native_edges(f,e);c=colors(f,native,uv);nc=[g for g in islands(f,native,uv) if not f[g[0]]['hidden']]
m['native_visible_charts']=len(nc);m['native_singleton_charts']=sum(len(g)==1 for g in nc)
(p/'Protected.json').write_text(json.dumps({str(x['id']):dict(uv=u.tolist(),**c[str(x['id'])]) for x,u in zip(f,uv)}))
r=json.loads((p/'results.json').read_text());r['Protected']={'metrics':m,'details':details,'by_part':{}}
(p/'results.json').write_text(json.dumps(r,indent=2));print(m['native_visible_charts'],m['native_singleton_charts'],details['accepted_merges'])
