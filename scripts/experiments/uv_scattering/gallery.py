"""Make a local comparison gallery and exact-coordinate SVG UV sheets."""
import json,sys,html
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw,ImageFont
p=Path(sys.argv[1]);results=json.loads((p/'results.json').read_text());faces=json.loads((p/'faces.json').read_text())
audit=json.loads((p/'saved_file_audit.json').read_text())
names=['Baseline','Planar','Protected','Strip65','Strip100','Sewn100','Xatlas','ABF','Smart']
try:font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',24)
except OSError:font=ImageFont.load_default()
for view in ['Overview','Rear','Under','Joinery','Checker','Eaves']:
    im=Image.new('RGB',(1500,1260),'#151c26');d=ImageDraw.Draw(im)
    for i,n in enumerate(names):
        x=(i%3)*500;y=(i//3)*420
        pic=Image.open(p/(n+'_'+view+'.png'));pic.thumbnail((500,375));im.paste(pic,(x,y+40))
        count=audit['LAB_'+n]['native_visible_charts'];d.text((x+10,y+4),f'{n} | {count} islands',font=font,fill='white')
    im.save(p/('Montage_'+view+'.jpg'),quality=92)
for n in names:
    plan=json.loads((p/(n+'.json')).read_text())
    for page in ['A','B','H']:
        selected=[f for f in faces if f['page']==page]
        pts=np.vstack([plan[str(f['id'])]['uv'] for f in selected]);lo=pts.min(0);hi=pts.max(0);size=hi-lo
        pad=max(size)*.005
        body=[]
        for f in selected:
            r=plan[str(f['id'])];q=np.array(r['uv']);color='#'+''.join(f'{int(max(0,min(1,c))*255):02x}' for c in r['color'])
            points=' '.join(f'{x:.9g},{-y:.9g}' for x,y in q)
            label=html.escape(f"Face {f['id']} | chart {r['chart']} | {f['part']}")
            body.append(f'<polygon points="{points}" fill="{color}" stroke="#14202a" stroke-width="{max(size)*.00013}"><title>{label}</title></polygon>')
        svg=f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{lo[0]-pad} {-hi[1]-pad} {size[0]+2*pad} {size[1]+2*pad}" style="background:#eee">'+''.join(body)+'</svg>'
        (p/f'{n}_UV_{page}.svg').write_text(svg)
rows=[]
for n in names:
    m=results[n]['metrics'];a=audit['LAB_'+n]
    rows.append(f"<tr><td>{n}</td><td>{a['native_visible_charts']}</td><td>{a['native_singletons']}</td><td>{m['visible_charts']}</td><td>{m['intra_chart_overlap_pairs']}</td><td>{100*m['anisotropy_area_above_1_1']:.2f}%</td></tr>")
table=''.join(rows)
doc='''<!doctype html><html lang="en"><meta charset="utf-8"><title>S12 scattering laboratory</title>
<style>body{font:16px system-ui;background:#101720;color:#e9eef5;margin:0;padding:28px}main{max-width:1500px;margin:auto}h1{font-size:36px;margin-bottom:8px}p{max-width:1050px;line-height:1.55;color:#bac7d8}a{color:#80cfef}select,button{background:#263648;color:white;border:1px solid #52657d;padding:10px;font:inherit;border-radius:6px}label{display:inline-block;margin:10px 15px 10px 0}.pair{display:grid;grid-template-columns:1fr 1fr;gap:16px}.pair img{width:100%;display:block}figure{margin:0}figcaption{padding:10px;background:#1f2a37;font-weight:600}table{border-collapse:collapse;width:100%;margin:25px 0}td,th{text-align:left;border-bottom:1px solid #354151;padding:10px}th{color:#8fb7d3}.note{background:#273445;padding:16px;border-left:4px solid #edba64}.links{margin:18px 0}.legend{font-size:14px}@media(max-width:800px){.pair{grid-template-columns:1fr}body{padding:12px}}</style>
<main><h1>Where the islands break</h1><p>S12 Korean Town Center · isolated chart-construction experiments · 27 September 2026</p>
<div class="note">This is a comparison laboratory, not a production unwrap. Original S12 remains in the Blender file. Colors follow actual native UV connectivity; the sewn variant changes only a derived review mesh. A larger solid color region is not proof of safe normal-map baking.</div>
<label>Left <select id="left"></select></label><label>Right <select id="right"></select></label><label>View <select id="view"><option>Overview</option><option>Rear</option><option>Under</option><option>Joinery</option><option>Checker</option></select></label>
<div class="pair"><figure><figcaption id="lt"></figcaption><a id="la"><img id="li"></a></figure><figure><figcaption id="rt"></figcaption><a id="ra"><img id="ri"></a></figure></div>
<p class="legend">Click an image for full resolution. Native island colors are deterministic and contrast with graph neighbors; the finite palette repeats elsewhere. Black is the inherited hidden-surface class. Checker images use the actual CandidateUV layer with an orientation-marked bitmap. They are diagnostic, not a physical texel-density certificate.</p>
<h2>Read back from the saved Blender file</h2><table><thead><tr><th>Method</th><th>Native islands</th><th>Single-face islands</th><th>Virtual continuous charts</th><th>UV overlap pairs*</th><th>Area stretched &gt;1.1×**</th></tr></thead><tbody>TABLE</tbody></table>
<p>* Within coordinate-continuous charts, including inherited baseline defects; not 3D mesh intersections. **Anisotropy ratio of Jacobian singular values, area weighted. Tiny degenerate source triangles are listed separately in the raw results; a raw maximum is misleading.</p>
<h2>Interpretation</h2><p>Planar-only repair barely changes the result. Normal-protected joining is the conservative candidate. Strip100 recovers much more continuity but crosses hard-normal boundaries. Sewn100 demonstrates the additional difference between equal UV coordinates and actual mesh connectivity. None clears every gate: the rigid candidates retain baseline UV overlap defects, while solver candidates have distortion or foldover costs.</p>
<h2>Exact UV sheets</h2><p>These SVGs plot actual coordinates, including intentional reuse in the baseline. Experimental sheets use a translated diagnostic layout outside the production tile, with no claim of final atlas capacity. Hover faces for IDs. Open in a browser and zoom for detail.</p><div id="uvlinks" class="links"></div>
<h2>Workflow and evidence</h2><p>Freeze input → classify native/virtual/contact adjacency → propose charts → test folds/stretch/density → read saved file back → inspect opposing views and boundary closeups → review tangent/material constraints → human choice → later reuse/AO/packing.</p>
<div class="links"><a href="RESEARCH.md">Research, repositories and validation gates</a> · <a href="Scattering_Comparison.blend">Editable Blender comparison</a> · <a href="results.json">Full metrics and rejection witnesses</a> · <a href="saved_file_audit.json">Independent file readback</a> · <a href="sewing_validation.json">Sewing displacement/normal measurements</a></div>
<p>The computer-use tool denied Blender UI capture, so rendered views and saved-file readback were checked; the live UV-editor screenshot gate is still open.</p></main>
<script>const names=NAMES;const stats=STATS;const $=id=>document.getElementById(id);for(const id of ['left','right'])for(const n of names)$(id).add(new Option(n,n));$('left').value='Baseline';$('right').value='Sewn100';function update(){for(const [id,prefix] of [['left','l'],['right','r']]){const n=$(id).value;const src=n+'_'+$('view').value+'.png';$(prefix+'i').src=src;$(prefix+'a').href=src;$(prefix+'t').textContent=n+' — '+stats['LAB_'+n].native_visible_charts+' native islands';}const n=$('right').value;$('uvlinks').innerHTML=['A','B','H'].map(p=>'<a href="'+n+'_UV_'+p+'.svg">'+n+' — UV '+p+'</a>').join(' · ');}for(const id of ['left','right','view'])$(id).onchange=update;update();</script></html>'''
doc=doc.replace('TABLE',table).replace('NAMES',json.dumps(names)).replace('STATS',json.dumps(audit)).replace('<option>Checker</option>','<option>Checker</option><option>Eaves</option>')
(p/'index.html').write_text(doc,encoding='utf-8')
