"""Prepare the diagnostic proposal; Blender performs sewing and audits it later."""
import sys,json
from pathlib import Path
import numpy as np
from experiment import colors
p=Path(sys.argv[1]);f=json.loads((p/'faces.json').read_text());e=json.loads((p/'adjacency.json').read_text())['edges']
d=json.loads((p/'Strip100.json').read_text());c=colors(f,e,[np.array(d[str(x['id'])]['uv']) for x in f])
for x in f:d[str(x['id'])].update(c[str(x['id'])])
(p/'Sewn100.json').write_text(json.dumps(d))
r=json.loads((p/'results.json').read_text());r['Sewn100']=json.loads(json.dumps(r['Strip100']))
r['Sewn100']['details']['sewing']='Derived review mesh only; independent Blender readback required'
r['Sewn100']['metrics']['native_visible_charts']=r['Sewn100']['metrics']['visible_charts']
r['Sewn100']['metrics']['native_singleton_charts']=r['Sewn100']['metrics']['singleton_charts']
(p/'results.json').write_text(json.dumps(r,indent=2))
