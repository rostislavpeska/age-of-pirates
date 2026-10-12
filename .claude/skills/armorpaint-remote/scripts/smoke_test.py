"""Native integration smoke: editable layers/mask/delete/save/reopen and verified pixels."""
import argparse
import json
from pathlib import Path
from PIL import Image
from armorpaint_batch import prepare_directory, runtime, run_script, export

def cpath(path):
    return json.dumps(str(Path(path).resolve()))

def run(exe, root):
    mesh=root/'plane.obj'
    mesh.write_text('o Smoke\nv -1 -1 0\nv 1 -1 0\nv 1 1 0\nv -1 1 0\nvt 0 0\nvt 1 0\nvt 1 1\nvt 0 1\nvn 0 0 1\nf 1/1/1 2/2/1 3/3/1\nf 1/1/1 3/3/1 4/4/1\n')
    black=root/'black.arm';white=root/'white.arm';create=root/'create.c';reopen=root/'reopen.c'
    create.write_text('''int frame=0;
void tick(){frame=frame+1;
if(frame==2){
slot_layer_t*b=script_layer_new_color(0xff204080,0.8,0.7,0.0);script_layer_set_name(b,"Smoke Base");
slot_layer_t*w=script_layer_new_color(0xffe0c080,1.0,0.3,0.0);script_layer_set_name(w,"Smoke Wear");
slot_layer_t*m=script_layer_new_mask(w,0);script_layer_set_name(m,"Smoke Black Mask");
slot_layer_t*d=script_layer_new_color(0xff00ff00,1.0,0.5,0.0);script_layer_delete(d);
console_info(string("LAYER_COUNT=%d",script_layer_count()));}
if(frame==4){project_filepath_set('''+cpath(black)+''');project_save(0);}
if(frame<7)script_notify_on_next_frame(tick);else console_info("CREATE_COMPLETE");}
void main(){script_notify_on_next_frame(tick);}
''')
    reopen.write_text('''int frame=0;
void tick(){frame=frame+1;
if(frame==2){slot_layer_t*m=script_layer_get("Smoke Black Mask");m->visible=false;script_layer_update(m);console_info(string("REOPEN_LAYER_COUNT=%d",script_layer_count()));}
if(frame==4){project_filepath_set('''+cpath(white)+''');project_save(0);}
if(frame<7)script_notify_on_next_frame(tick);else console_info("REOPEN_COMPLETE");}
void main(){script_notify_on_next_frame(tick);}
''')
    reports={}
    reports['create']=run_script(exe,mesh,create,root/'create-log',[black],'CREATE_COMPLETE')
    if not reports['create']['ok']: raise RuntimeError(reports['create']['errors'])
    reports['black_export']=export(exe,black,root/'black-export')
    if not reports['black_export']['ok']: raise RuntimeError(reports['black_export']['errors'])
    reports['reopen']=run_script(exe,black,reopen,root/'reopen-log',[white],'REOPEN_COMPLETE')
    if not reports['reopen']['ok']: raise RuntimeError(reports['reopen']['errors'])
    reports['white_export']=export(exe,white,root/'white-export')
    if not reports['white_export']['ok']: raise RuntimeError(reports['white_export']['errors'])
    expected={'base':[(32,64,128),(224,192,128)],'rough':[178,76],'occ':[204,255],'metal':[0,0]}
    pixels={}
    for channel, values in expected.items():
        got=[]
        for name in ['black','white']:
            with Image.open(root/f'{name}-export/{name}_{channel}.png') as im:
                got.append(im.getpixel((1024,1024)))
        if got!=values: raise AssertionError((channel,got,values))
        pixels[channel]=got
    for name, marker in [('create-log','LAYER_COUNT=4'),('reopen-log','REOPEN_LAYER_COUNT=4')]:
        if marker not in (root/name/'stdout.txt').read_text():
            raise AssertionError(f'Layer graph readback missing: {marker}')
    result={'ok':True,'pixels':pixels,'runs':reports,'normal_roundtrip':'Reported separately; not asserted byte-exact','new_bakes':0}
    (root/'SMOKE.json').write_text(json.dumps(result,indent=2));return result

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--exe');p.add_argument('--local-config');p.add_argument('--out-dir',required=True);a=p.parse_args()
    folder=prepare_directory(a.out_dir)
    try:
        report=run(runtime(a.exe,a.local_config),folder)
    except Exception as exc:
        report={'ok':False,'error':f'{type(exc).__name__}: {exc}'}
        (folder/'SMOKE.json').write_text(json.dumps(report,indent=2))
    print(json.dumps({'ok':report['ok'],'evidence':str(folder/'SMOKE.json'),'error':report.get('error')}))
    raise SystemExit(0 if report['ok'] else 1)
