"""Run with background Blender. Regression specimen for stale stored matrix_world.

A command-line load evaluates only the window's scene. An object in another scene keeps
the matrix_world stored at save time; a part whose parent a script moved without a
depsgraph update reads its old place (c4r9 civic pair: 74 Monastery lantern parts read
(0,0,0), stacked inside each other and baked AO 0.0). The specimen: a cube parented to an
empty in a second scene, the empty moved without an update, saved, reloaded by a fresh
Blender. ao_sample.py and bake_owner_ao.py must see the cube where its parent put it: the
face against a plate dark, the opposite face open. Writes only to a temporary folder.

blender -b --factory-startup --python-exit-code 1 --python check_world_matrix_blender.py
"""
import bpy, json, subprocess, tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
H, CELL = .1, [(c, r) for r in range(2) for c in range(3)]


def cell_uv(i, m=.03):
    c, r = CELL[i]; u0, u1, v0, v1 = c / 3 + m, (c + 1) / 3 - m, r / 2 + m, (r + 1) / 2 - m
    return [[u0, v0], [u1, v0], [u1, v1], [u0, v1]]


def blender(blend, *args):
    p = subprocess.run([bpy.app.binary_path, '-b', '--factory-startup', str(blend), '--python-exit-code', '1', *args],
                       capture_output=True, encoding='utf-8', errors='replace', timeout=600)
    assert p.returncode == 0, p.stdout[-2000:] + p.stderr[-2000:]
    return p.stdout


bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.data.scenes.new('Assembly')        # not the window's scene, like the civic LOW scenes
post = bpy.data.objects.new('Post', None); sc.collection.objects.link(post)
v = [(x, y, z) for z in (-H, H) for y in (-H, H) for x in (-H, H)]
me = bpy.data.meshes.new('Lantern')
me.from_pydata(v, [], [(0, 2, 3, 1), (4, 5, 7, 6), (0, 1, 5, 4), (2, 6, 7, 3), (0, 4, 6, 2), (1, 3, 7, 5)]); me.update()
uv = me.uv_layers.new(name='UV')
for p in me.polygons:
    for j, li in enumerate(p.loop_indices):
        uv.data[li].uv = cell_uv(p.index)[j]
PX = max(range(6), key=lambda i: me.polygons[i].normal.x); MX = min(range(6), key=lambda i: me.polygons[i].normal.x)
lantern = bpy.data.objects.new('Lantern', me); sc.collection.objects.link(lantern); lantern.parent = post
pm = bpy.data.meshes.new('Plate'); pm.from_pydata([(0, -.5, -.5), (0, .5, -.5), (0, .5, .5), (0, -.5, .5)], [], [(0, 1, 2, 3)])
plate = bpy.data.objects.new('Plate', pm); plate.location = (5 + H + .05, 0, 0); sc.collection.objects.link(plate)
sc.view_layers[0].update()
post.location = (5, 0, 0)                   # moved by script, no depsgraph update before the save

with tempfile.TemporaryDirectory(prefix='ao_world_matrix_', ignore_cleanup_errors=True) as tmp:
    tmp = Path(tmp); blend = tmp / 'stale.blend'
    bpy.ops.wm.save_as_mainfile(filepath=str(blend))
    probe = ("import bpy,json;o=bpy.data.objects['Lantern'];s=o.matrix_world.translation.x;"
             "[vl.update() for sc in bpy.data.scenes for vl in sc.view_layers];"
             "print('MW',json.dumps([s,o.matrix_world.translation.x]))")
    stale, fresh = json.loads(blender(blend, '--python-expr', probe).split('MW ')[1].splitlines()[0])
    assert abs(stale) < 1e-6 and abs(fresh - 5) < 1e-6, f'Specimen no longer reproduces a stale stored matrix: {stale} -> {fresh}'

    cfg = dict(targets=[dict(object='Lantern', key='Lantern', uv='UV', page=64)], occluders=['Plate', 'Lantern'],
               radius=.5, rays=64, grid=12, lattice=2, out=str(tmp / 'ao.json'))
    (tmp / 'sample.json').write_text(json.dumps(cfg))
    assert 'AO_DONE' in blender(blend, '--python', str(HERE / 'ao_sample.py'), '--', str(tmp / 'sample.json'))
    faces = {f['face']: [s[3] for s in f['samples']] for f in json.loads((tmp / 'ao.json').read_text())['faces']}
    sample_px, sample_mx = sum(faces[f'Lantern:{PX}']) / len(faces[f'Lantern:{PX}']), min(faces[f'Lantern:{MX}'])

    plan = {f'Lantern:{i}': dict(uv=cell_uv(i), owner=True) for i in range(6)}
    (tmp / 'plan.json').write_text(json.dumps(dict(faces=plan)))
    cfg = dict(plan=str(tmp / 'plan.json'), sources=dict(Lantern='Lantern'), extra_occluders=['Plate'], pages=dict(P=64),
               uv_name='UV_Final', radius=.5, samples=16, margin=2, out_dir=str(tmp))
    (tmp / 'bake.json').write_text(json.dumps(cfg))
    assert 'BAKED' in blender(blend, '--python', str(HERE / 'bake_owner_ao.py'), '--', str(tmp / 'bake.json'))
    img = bpy.data.images.load(str(tmp / 'AO_P.png')); n = img.size[0]; px = list(img.pixels); bpy.data.images.remove(img)

    def bake_mean(i):
        (u0, v0), _, (u1, v1), _ = cell_uv(i, .06)
        vals = [px[4 * (y * n + x)] for y in range(n) for x in range(n) if u0 < (x + .5) / n < u1 and v0 < (y + .5) / n < v1]
        return sum(vals) / len(vals)
    bake_px, bake_mx = bake_mean(PX), bake_mean(MX)

result = dict(test='stale_world_matrix', sample_plate_face=round(sample_px, 3), sample_open_face=round(sample_mx, 3),
              bake_plate_face=round(bake_px, 3), bake_open_face=round(bake_mx, 3))
assert sample_px < .5 and bake_px < .5, f'Face against the plate is open: AO scripts read the stored matrix_world {result}'
assert sample_mx > .99 and bake_mx > .9, f'Open face is occluded {result}'
print(json.dumps(dict(result, status='PASS')))
