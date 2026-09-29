"""Focused scope, extraction and identity controls in one small background Blender.

python test_bake_contract.py /path/to/blender
No HIGH production assets, live sessions, images or manual review are needed.
"""
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
FIXTURE = r'''
import bpy, json, sys, time, tempfile, copy
from pathlib import Path
sys.path.insert(0, SCRIPTS)
import bake_contract as gate
from uv_fingerprint import fingerprint as uv_fingerprint
t0=time.perf_counter()
me=bpy.data.meshes.new('Bent');me.from_pydata([(0,0,0),(1,0,0),(2,0,1),(0,1,0),(1,1,0),(2,1,1)],[],[(0,1,4,3),(1,2,5,4)])
ob=bpy.data.objects.new('Bent',me);bpy.context.scene.collection.objects.link(ob)
for p in me.polygons:p.use_smooth=True
uv=me.uv_layers.new(name='UV_Final')
for p in me.polygons:
    for l in p.loop_indices:uv.data[l].uv=me.vertices[me.loops[l].vertex_index].co.xy/2
me.update()
plan={'L:0':{'owner':True,'page':'P'},'L:1':{'owner':True,'page':'P'}}
cfg={'sources':{'L':'Bent'},'pages':{'P':64},'highs':[{'objects':['High']}], 'only':['L:0'],
     'scope':{'mode':'pilot','regions':[{'id':'left','faces':['L:0'],'highs':['High']}]}}
def reject(c, phrase):
    try:gate.validate_scope(c,plan,{'L':2})
    except ValueError as e:assert phrase in str(e),str(e)
    else:raise AssertionError('Expected rejection: '+phrase)
gate.validate_scope(cfg,plan,{'L':2})
c=copy.deepcopy(cfg);c['scope']['regions'][0]['faces'].append('L:1');reject(c,'missing')
c=copy.deepcopy(cfg);c['only'].append('L:1');reject(c,'unexpected')
c=copy.deepcopy(cfg);c['scope']['regions'][0]['highs']=['Wrong'];reject(c,'existing recipe HIGHs')
c=copy.deepcopy(cfg);c['only']=['L:99'];reject(c,'unknown/member')
c=copy.deepcopy(cfg);del c['scope'];reject(c,'migrate')
c=copy.deepcopy(cfg);c['scope']['mode']='production';reject(c,'both freeze')
c['freeze']='declared-uv-freeze.json';c['input_contract']='declared-low-contract.json'
assert gate.validate_scope(c,plan,{'L':2})['mode']=='production'
base=gate.fingerprint(['Bent']);u0=uv_fingerprint(['Bent'],'UV_Final')['combined']
old=me.vertices[2].co.z;me.vertices[2].co.z+=.1;me.update()
assert gate.fingerprint(['Bent'])['combined']!=base['combined']
assert uv_fingerprint(['Bent'],'UV_Final')['combined']==u0
me.vertices[2].co.z=old;me.update()
me.polygons[0].use_smooth=False;me.update()
assert gate.fingerprint(['Bent'])['combined']!=base['combined']
assert uv_fingerprint(['Bent'],'UV_Final')['combined']==u0
me.polygons[0].use_smooth=True;me.update()
assert gate.fingerprint(['Bent'])['combined']==base['combined']
# Reversing face winding changes the triangle/loop contract even at identical positions.
flip=bpy.data.objects.new('WindingControl',me.copy());bpy.context.scene.collection.objects.link(flip)
f0=gate.fingerprint(['WindingControl'])['combined'];flip.data.flip_normals();flip.data.update()
assert gate.fingerprint(['WindingControl'])['combined']!=f0
with tempfile.TemporaryDirectory() as tmp:
    p=Path(tmp)/'contract.json';p.write_text(json.dumps(base))
    gate.check_contract({'input_contract':str(p)},base)
    bad=dict(base,combined='changed')
    try:gate.check_contract({'input_contract':str(p)},bad)
    except ValueError:pass
    else:raise AssertionError('Changed LOW signature accepted')
copyob=bpy.data.objects.new('Receiver',me.copy());bpy.context.scene.collection.objects.link(copyob)
result=gate.keep_faces(copyob,{0})
assert result['face_ids']==[0] and result['triangles_equal']
assert result['normal_error_before']>.1,result
assert result['normal_error_after']<=result['normal_tolerance'],result
assert gate.fingerprint(['Bent'])['combined']==base['combined'],'Authoring mesh was changed'
# A valid explicit partial pilot is allowed; its shading frame is preserved despite deletion.
whole=bpy.data.objects.new('Whole',me.copy());bpy.context.scene.collection.objects.link(whole)
whole_result=gate.keep_faces(whole,{0,1});assert whole_result['normal_error_after']<=1e-4
print('CONTRACT_TEST_PASS',json.dumps({'partial_receiver':result,'full_receiver':whole_result,'seconds':time.perf_counter()-t0}))
'''


def main(exe):
    with tempfile.TemporaryDirectory(prefix='bake-contract-') as tmp:
        path = Path(tmp) / 'fixture.py'
        path.write_text(FIXTURE.replace('SCRIPTS', repr(str(HERE))))
        r = subprocess.run([exe, '-b', '--factory-startup', '--python', str(path)], capture_output=True, text=True)
        assert r.returncode == 0 and 'CONTRACT_TEST_PASS' in r.stdout, r.stdout[-4000:] + r.stderr[-4000:]
        print(r.stdout)


if __name__ == '__main__':
    main(sys.argv[1])
