"""Local roundtrip/protection tests; never calls a generator or game exporter."""
import json,subprocess,sys
from pathlib import Path
import numpy as np
from PIL import Image

TOOL=Path(__file__).with_name('uv_island_paint.py')

def test_blender_uv_json_roundtrip_and_protection(tmp_path):
    y,x=np.mgrid[:128,:128]
    src=np.stack([(x*7)%256,(y*5)%256,((x+y)*3)%256,(x*2)%256],-1).astype('uint8')
    page=tmp_path/'page.png';Image.fromarray(src).save(page)
    uv=tmp_path/'uv.json';uv.write_text(json.dumps({'origin':'top-left','source_id':'fixture.blend:Roof','uv_layer':'UV_Provisional','triangles':[[[.2,.2],[.8,.2],[.8,.8]],[[.2,.2],[.8,.8],[.2,.8]]]}))
    edit=tmp_path/'edit';r=subprocess.run([sys.executable,str(TOOL),'extract','--page',str(page),'--uv-json',str(uv),'--all','--out',str(edit)],capture_output=True,text=True);assert r.returncode==0,r.stderr
    out=tmp_path/'out.png';r=subprocess.run([sys.executable,str(TOOL),'apply','--dir',str(edit),'--painted',str(edit/'EDIT_INPUT.png'),'--route','manual','--calls','0','--out-page',str(out)],capture_output=True,text=True);assert r.returncode==0,r.stderr
    rec=json.loads((edit/'APPLY.json').read_text());assert rec['gate']=='PASS' and rec['structure']>.99
    assert rec['outside_changed_texels']==0 and rec['alpha_changed_texels']==0
    changed=np.asarray(Image.open(out));assert np.array_equal(changed[...,3],src[...,3]);assert np.array_equal(changed[:20],src[:20])
    Image.new('RGB',(512,128)).save(tmp_path/'wrong_aspect.png')
    r=subprocess.run([sys.executable,str(TOOL),'apply','--dir',str(edit),'--painted',str(tmp_path/'wrong_aspect.png'),'--route','manual','--out-page',str(tmp_path/'bad.png')],capture_output=True,text=True)
    assert r.returncode!=0 and not (tmp_path/'bad.png').exists()
