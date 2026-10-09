"""Fixture test for bake_owner_maps.py and uv_fingerprint.py (runs Blender in the background).

python test_bake_owner_maps.py "C:/Program Files/Blender Foundation/Blender 5.0/blender.exe"
Low: 2x2 grid, faces 0/1 are owners, faces 2/3 are members stacked on the owners' texels.
High: a tent over face 0 (tilted normals) and a flat strip over the left half of face 1 only.
Checks: normals tilt on face 0's texels, stay flat on face 1's; opacity is white under the
strip and black where face 1 has no high; freeze -> check PASS; a moved UV -> check FAIL.
"""
import json
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
FIXTURE = r'''
import bpy, json, sys
out = sys.argv[sys.argv.index('--') + 1]
for o in list(bpy.data.objects): bpy.data.objects.remove(o)
v = [(x, y, 0) for y in (0, 1, 2) for x in (0, 1, 2)]
f = [(0, 1, 4, 3), (1, 2, 5, 4), (3, 4, 7, 6), (4, 5, 8, 7)]
me = bpy.data.meshes.new('Low'); me.from_pydata(v, [], f); low = bpy.data.objects.new('Low', me)
bpy.context.scene.collection.objects.link(low)
me.uv_layers.new(name='UVMap'); me.uv_layers.new(name='UV_Old')  # extra layers: the bake must drop them safely
uv = me.uv_layers.new(name='UV_Final')
isl = {0: (.05, .45), 1: (.55, .95), 2: (.05, .45), 3: (.55, .95)}   # u range; v .05-.45
for p in me.polygons:
    u0, u1 = isl[p.index]
    for li, c in zip(p.loop_indices, [(u0, .05), (u1, .05), (u1, .45), (u0, .45)]):
        uv.data[li].uv = c
hv = [(0, 0, .02), (1, 0, .02), (1, 1, .02), (0, 1, .02), (.5, .5, .25), (1, 0, .02), (1.5, 0, .02), (1.5, 1, .02), (1, 1, .02)]
hf = [(0, 1, 4), (1, 2, 4), (2, 3, 4), (3, 0, 4), (5, 6, 7, 8)]
hm = bpy.data.meshes.new('High'); hm.from_pydata(hv, [], hf); hi = bpy.data.objects.new('High', hm)
bpy.context.scene.collection.objects.link(hi)
# Closer unrelated HIGH: normal bake must exclude it through the declared pair.
im = bpy.data.meshes.new('Interferer'); im.from_pydata([(0,0,.29),(2,0,.29),(2,1,.29),(0,1,.29)], [], [(0,1,2,3)])
io = bpy.data.objects.new('Interferer', im); bpy.context.scene.collection.objects.link(io)
bpy.ops.wm.save_as_mainfile(filepath=out + '/fixture.blend')
json.dump({'faces': {'L:0': {'owner': True, 'page': 'P', 'material': 'ROOF_TILE'},
                     'L:1': {'owner': True, 'page': 'P', 'material': 'ROOF_TILE'},
                     'L:2': {'owner': False, 'page': 'P', 'material': 'ROOF_TILE'},
                     'L:3': {'owner': False, 'page': 'P', 'material': 'ROOF_TILE'}}},
          open(out + '/plan.json', 'w'))
'''
MOVE_UV = r'''
import bpy
bpy.data.objects['Low'].data.uv_layers['UV_Final'].data[0].uv.x += .01
'''


def blender(exe, *args, script=None, tmp=None):
    cmd = [exe, '-b', *args]
    if script:
        p = Path(tmp) / 'snippet.py'; p.write_text(script); cmd += ['--python', str(p)]
    return subprocess.run(cmd, capture_output=True, text=True)


def main(exe):
    with tempfile.TemporaryDirectory() as tmp:
        t = Path(tmp).as_posix()
        r = blender(exe, '--python-expr', FIXTURE.replace("sys.argv[sys.argv.index('--') + 1]", repr(t)))
        assert (Path(tmp) / 'fixture.blend').exists(), r.stdout[-2000:] + r.stderr[-2000:]
        freeze = {'objects': ['Low'], 'uv_name': 'UV_Final', 'freeze': f'{t}/freeze.json', 'bakes': [f'{t}/bake/bake_report.json']}
        (Path(tmp) / 'freeze_cfg.json').write_text(json.dumps(freeze))
        r = blender(exe, f'{t}/fixture.blend', '--python', str(HERE / 'uv_fingerprint.py'), '--', 'record', f'{t}/freeze_cfg.json')
        assert 'RECORDED' in r.stdout, r.stdout[-2000:] + r.stderr[-2000:]
        recipe = {'plan': f'{t}/plan.json', 'sources': {'L': 'Low'}, 'highs': [{'objects': ['High', 'Interferer']}],
                  'pages': {'P': 64}, 'maps': ['NORMAL', 'AO', 'OPACITY'], 'extrusion': .3, 'max_ray_distance': .6,
                  'scope': {'mode': 'pilot', 'regions': [{'id': 'pair', 'faces': ['L:0','L:1'], 'highs': ['High']}]},
                  'assembly': {'name': 'machinery fixture: one tile plane, no eave or caps', 'parts': {'field': {'materials': ['ROOF_TILE'], 'bake': 'high'}}},
                  'margin': 2, 'samples': 4, 'freeze': f'{t}/freeze.json', 'out_dir': f'{t}/bake'}
        (Path(tmp) / 'recipe.json').write_text(json.dumps(recipe))
        r = blender(exe, f'{t}/fixture.blend', '--python', str(HERE / 'bake_owner_maps.py'), '--', f'{t}/recipe.json')
        assert 'REPORT' in r.stdout, r.stdout[-3000:] + r.stderr[-3000:]

        def px(name, u, v):  # normalised 0..1; Pillow reads 16-bit RGB as 8-bit, 16-bit grey as I;16
            im = Image.open(Path(tmp) / 'bake' / f'{name}.png'); w, h = im.size
            c = im.getpixel((int(u * w), int((1 - v) * h))); full = 65535 if im.mode.startswith('I') else 255
            return [x / full for x in c] if isinstance(c, tuple) else c / full
        n_tent, n_flat = px('NORMAL_P', .15, .25), px('NORMAL_P', .65, .25)
        tilt = lambda c: abs(c[0] - .5) + abs(c[1] - .5)
        assert tilt(n_tent) > .1, f'face 0 should carry the tent normals: {n_tent}'
        assert tilt(n_flat) < .03, f'face 1 under the flat strip should be flat: {n_flat}'
        o_hit, o_miss = px('OPACITY_P', .65, .25), px('OPACITY_P', .88, .25)
        assert o_hit > .9 and o_miss < .1, f'opacity hit/miss: {o_hit} / {o_miss}'
        solid = dict(recipe, maps=['OPACITY'], opacity_classes=['EAVE_CUTOUT'], out_dir=f'{t}/bake_solid')
        (Path(tmp) / 'recipe_solid.json').write_text(json.dumps(solid))
        r = blender(exe, f'{t}/fixture.blend', '--python', str(HERE / 'bake_owner_maps.py'), '--', f'{t}/recipe_solid.json')
        assert 'REPORT' in r.stdout, r.stdout[-3000:] + r.stderr[-3000:]
        im = Image.open(Path(tmp) / 'bake_solid' / 'OPACITY_P.png'); full = 65535 if im.mode.startswith('I') else 255
        assert im.getpixel((int(.88 * im.size[0]), int(.75 * im.size[1]))) > .9 * full, 'a solid-class face must stay opaque where rays miss'
        rep = json.loads((Path(tmp) / 'bake' / 'bake_report.json').read_text())
        assert rep['targets']['P']['T_L_P_pair']['faces'] == 2, 'members must not be bake targets'
        assert rep['preflight']['scope']['allowed_highs'] == {'pair':['High']}
        # Invalid scope must fail before a HIGH load, image allocation or bake result.
        invalid = dict(recipe, only=['L:0'], highs=[{'file':'does-not-exist.blend','objects':['High','Interferer']}], out_dir=f'{t}/invalid')
        (Path(tmp) / 'invalid.json').write_text(json.dumps(invalid))
        r = blender(exe, f'{t}/fixture.blend', '--python', str(HERE / 'bake_owner_maps.py'), '--', f'{t}/invalid.json')
        assert 'Scope mismatch' in r.stderr and 'BAKED' not in r.stdout, r.stdout[-2000:] + r.stderr[-2000:]
        assert not (Path(tmp)/'invalid').exists()
        r = blender(exe, f'{t}/fixture.blend', '--python', str(HERE / 'uv_fingerprint.py'), '--', 'check', f'{t}/freeze_cfg.json')
        assert r.returncode == 0 and 'CHECK PASS' in r.stdout, r.stdout[-2000:]
        r = blender(exe, f'{t}/fixture.blend', '--python-expr', MOVE_UV, '--python', str(HERE / 'uv_fingerprint.py'), '--', 'check', f'{t}/freeze_cfg.json')
        assert r.returncode == 3 and 'CHECK FAIL' in r.stdout, r.stdout[-2000:]
    print('OK bake_owner_maps + uv_fingerprint: owners only, tilt/flat normals, opacity hit/miss, freeze pass/fail')


if __name__ == '__main__':
    main(sys.argv[1])
