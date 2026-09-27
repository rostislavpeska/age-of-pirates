"""Distinguish native editable connectivity from coordinate-continuous proxies."""
import sys,json,math
from pathlib import Path
import numpy as np
from experiment import native_edges,islands,colors,uv_joined
out=Path(sys.argv[1]);faces=json.loads((out/'faces.json').read_text())
edges=json.loads((out/'adjacency.json').read_text())['edges'];native=native_edges(faces,edges)
results=json.loads((out/'results.json').read_text())
for name,r in results.items():
    plan=json.loads((out/(name+'.json')).read_text());uv=[np.array(plan[str(f['id'])]['uv']) for f in faces]
    actual=islands(faces,native,uv);visible=[g for g in actual if not faces[g[0]]['hidden']]
    r['metrics']['native_visible_charts']=len(visible)
    r['metrics']['native_singleton_charts']=sum(len(g)==1 for g in visible)
    # Actual corner normal discontinuity, separate from geometric dihedral.
    joined_hard=[]
    for e in edges:
        a,b=faces[e['a']],faces[e['b']]
        if a['hidden'] or b['hidden'] or not uv_joined(e,uv):continue
        dots=[np.dot(a['corner_normals'][e[ka]],b['corner_normals'][e[kb]]) for ka,kb in [('ai','bi'),('aj','bj')]]
        if min(dots)<math.cos(math.radians(5)):joined_hard.append([a['id'],b['id']])
    r['metrics']['joined_hard_normal_edges']=len(joined_hard)
    r['hard_normal_witnesses']=joined_hard
    # Native UV connectivity drives the primary colors.
    color=colors(faces,native,uv)
    for f in faces:
        row=plan[str(f['id'])];row['virtual_chart']=row['chart'];row.update(color[str(f['id'])])
    (out/(name+'.json')).write_text(json.dumps(plan))
    print(name,len(visible),r['metrics']['native_singleton_charts'],len(joined_hard))
(out/'results.json').write_text(json.dumps(results,indent=2))
