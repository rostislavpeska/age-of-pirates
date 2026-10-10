"""Planted-defect controls for junction_check.py (run: blender -b --factory-startup --python blender_test_junction_check.py).

Named blender_test_* so plain-Python unittest discovery (test_*.py) skips it: it needs bpy.
Every defect class gets a minimal scene that MUST fail; every designed joint MUST pass. Exit code 1 on any miss.
Deterministic: fixed geometry, no randomness.
"""
import math
import sys
import traceback
from pathlib import Path

import bpy
import bmesh
from mathutils import Matrix

sys.path.insert(0, str(Path(__file__).resolve().parent))
import junction_check as jc  # noqa: E402

FAILS = []


def coll(tag):
    """A fresh collection; the previous case's objects are removed so part names stay exact ('Beam', not 'Beam.001')."""
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o)
    for me in list(bpy.data.meshes):
        bpy.data.meshes.remove(me)
    c = bpy.data.collections.new('case ' + tag); bpy.context.scene.collection.children.link(c); return c


def box(c, name, lo, hi, inside_out=False, mw=None):
    me = bpy.data.meshes.new(name); bm = bmesh.new()
    v = [bm.verts.new((x, y, z)) for z in (lo[2], hi[2]) for y in (lo[1], hi[1]) for x in (lo[0], hi[0])]
    for f in ((0, 2, 3, 1), (4, 5, 7, 6), (0, 1, 5, 4), (2, 6, 7, 3), (0, 4, 6, 2), (1, 3, 7, 5)):
        bm.faces.new([v[i] for i in f])
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    if inside_out:
        bmesh.ops.reverse_faces(bm, faces=list(bm.faces))
    bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new(name, me); c.objects.link(o)
    if mw is not None:
        o.matrix_world = mw
    return o


def sheet(c, name, pts, solidify=None):
    me = bpy.data.meshes.new(name); me.from_pydata(pts, [], [tuple(range(len(pts)))]); me.update()
    o = bpy.data.objects.new(name, me); c.objects.link(o)
    if solidify:
        m = o.modifiers.new('solid', 'SOLIDIFY'); m.thickness = solidify; m.offset = -1
    return o


def run(c, junctions, **extra):
    bpy.context.view_layer.update()
    return jc.evaluate(dict({'name': c.name, 'scope': {'collection': c.name}, 'junctions': junctions}, **extra))


def check(tag, cond, rep):
    print(('PASS ' if cond else 'FAIL ') + tag)
    if not cond:
        print(jc.table(rep)); FAILS.append(tag)


def J(rep, i=0):
    return rep['junctions'][i]


try:
    # 1. clean butt joints: a beam ending flush on a wall face, a 2 cm rail into a 4 cm post
    c = coll('clean')
    box(c, 'Wall', (0, 0, 0), (.3, 4, 3)); box(c, 'Beam', (.3, 1.9, 2.5), (2.3, 2.1, 2.7))
    box(c, 'Post', (3, 1.98, 0), (3.04, 2.02, 1)); box(c, 'Rail', (3.04, 1.99, .8), (4.5, 2.01, .85))
    r = run(c, [{'id': 'beam-wall', 'a': 'Beam', 'b': 'Wall', 'strategy': 'butt'},
                {'id': 'rail-post', 'a': 'Rail', 'b': 'Post', 'strategy': 'butt'}])
    check('clean butt joints pass', r['status'] == 'PASS', r)

    # 2. gap: the beam stops 3 cm short of the wall
    c = coll('gap')
    box(c, 'Wall', (0, 0, 0), (.3, 4, 3)); box(c, 'Beam', (.33, 1.9, 2.5), (2.3, 2.1, 2.7))
    r = run(c, [{'id': 'beam-wall', 'a': 'Beam', 'b': 'Wall', 'strategy': 'butt'}])
    check('3 cm gap fails', J(r)['status'] == 'FAIL' and abs(J(r)['worst_gap'] - .03) < .002, r)

    # 3. penetration: the beam runs 6 cm into the wall
    c = coll('pen')
    box(c, 'Wall', (0, 0, 0), (.3, 4, 3)); box(c, 'Beam', (.24, 1.9, 2.5), (2.3, 2.1, 2.7))
    r = run(c, [{'id': 'beam-wall', 'a': 'Beam', 'b': 'Wall', 'strategy': 'constructed'}])
    check('6 cm penetration fails (constructed)', J(r)['status'] == 'FAIL' and abs(J(r)['worst_pen'] - .06) < .005, r)
    r = run(c, [{'id': 'beam-wall', 'a': 'Beam', 'b': 'Wall', 'strategy': 'seated', 'max_pen': .08}])
    check('6 cm seat passes when declared seated .08', r['status'] == 'PASS', r)
    r = run(c, [{'id': 'beam-wall', 'a': 'Beam', 'b': 'Wall', 'strategy': 'seated'}])
    check('seated without a seat depth is inconclusive', J(r)['status'] == 'INCONCLUSIVE' and r['status'] == 'FAIL', r)

    # 4. proud: a 9 cm rail butting into a 3 cm post (r1h: rails 7.5 cm proud of 3 cm posts)
    c = coll('proud')
    box(c, 'Post', (0, -.015, 0), (.03, .015, 1)); box(c, 'Rail', (.03, -.045, .8), (1.5, .045, .85))
    r = run(c, [{'id': 'rail-post', 'a': 'Rail', 'b': 'Post', 'strategy': 'butt'}])
    check('rail proud of its post fails', J(r)['status'] == 'FAIL' and abs(J(r)['worst_proud'] - .03) < .002, r)

    # 4b. attachment: a deck 9.5 cm off its wall that touches only a sill block at one corner has contact (gap 0) but
    # no seat (cover 0 %) and fails; the same deck seated flush on the wall passes (Market r1h -> r1i)
    c = coll('deck corner')
    box(c, 'W.Wall', (0, 0, 0), (.3, 4, 3)); box(c, 'W.Sill', (.3, 1, 2.12), (.395, 1.2, 2.3))
    box(c, 'Deck', (.395, 1, 2), (2.3, 3, 2.16))
    att = {'id': 'deck-wall', 'a': 'Deck', 'b': 'W.*', 'strategy': 'seated', 'max_gap': .006, 'max_pen': .05, 'min_cover': .6}
    r = run(c, [att])
    check('deck touching at one corner fails on cover', J(r)['status'] == 'FAIL' and J(r)['worst_gap'] == 0 and J(r)['worst_cover'] < .2, r)
    c = coll('deck seated')
    box(c, 'W.Wall', (0, 0, 0), (.3, 4, 3)); box(c, 'Deck', (.3, 1, 2), (2.3, 3, 2.16))
    r = run(c, [att])
    check('deck seated on its wall passes', r['status'] == 'PASS' and J(r)['worst_cover'] > .9, r)

    # 4c. a rail that meets its west post but stops 3 cm short of its east post: all_b catches the second end
    c = coll('rail ends')
    box(c, 'Post.A', (0, -.045, 0), (.09, .045, 1)); box(c, 'Post.B', (2, -.045, 0), (2.09, .045, 1))
    box(c, 'Rail', (.09, -.03, .8), (1.97, .03, .88))
    rail = {'id': 'rail', 'a': 'Rail', 'b': 'Post.*', 'strategy': 'butt'}
    r = run(c, [dict(rail, all_b=True)])
    check('rail short of its second post fails with all_b', J(r)['status'] == 'FAIL' and abs(J(r)['worst_gap'] - .03) < .002, r)
    r = run(c, [rail])
    check('without all_b the nearest post is enough', J(r)['status'] == 'PASS', r)

    # 5. roof slabs: a wing slab butting a main slab passes, one running 20 cm into it fails
    c = coll('slab ok')
    box(c, 'Roof.Main', (0, 0, 2), (4, 3, 2.2)); box(c, 'Roof.Wing', (4, 1, 2), (6, 2, 2.2))
    r = run(c, [{'id': 'valley', 'a': 'Roof.Wing', 'b': 'Roof.Main', 'strategy': 'constructed'}])
    check('roof slabs sharing a seam pass', r['status'] == 'PASS', r)
    c = coll('slab overlap')
    box(c, 'Roof.Main', (0, 0, 2), (4, 3, 2.2)); box(c, 'Roof.Wing', (3.8, 1, 2), (6, 2, 2.2))
    r = run(c, [{'id': 'valley', 'a': 'Roof.Wing', 'b': 'Roof.Main', 'strategy': 'constructed'}])
    check('overlapping roof slabs fail', J(r)['status'] == 'FAIL' and J(r)['worst_pen'] > .05, r)

    # 6. world space: the same two pairs rotated (object transforms, not mesh data)
    R = Matrix.Rotation(math.radians(30), 4, 'Z') @ Matrix.Rotation(math.radians(20), 4, 'X')
    c = coll('rotated ok')
    box(c, 'Roof.Main', (0, 0, 2), (4, 3, 2.2), mw=R); box(c, 'Roof.Wing', (4, 1, 2), (6, 2, 2.2), mw=R)
    r = run(c, [{'id': 'valley', 'a': 'Roof.Wing', 'b': 'Roof.Main', 'strategy': 'constructed'}])
    check('rotated seam passes', r['status'] == 'PASS', r)
    c = coll('rotated overlap')
    box(c, 'Roof.Main', (0, 0, 2), (4, 3, 2.2), mw=R); box(c, 'Roof.Wing', (3.8, 1, 2), (6, 2, 2.2), mw=R)
    r = run(c, [{'id': 'valley', 'a': 'Roof.Wing', 'b': 'Roof.Main', 'strategy': 'constructed'}])
    check('rotated overlap fails', J(r)['status'] == 'FAIL' and J(r)['worst_pen'] > .05, r)

    # 7. modifiers are evaluated: a solidified sheet is a closed slab (measurable), not an open shell
    c = coll('solidify')
    box(c, 'Roof.Main', (0, 0, 2), (4, 3, 2.2))
    sheet(c, 'Roof.Wing', [(3.8, 1, 2.2), (6, 1, 2.2), (6, 2, 2.2), (3.8, 2, 2.2)], solidify=.2)
    r = run(c, [{'id': 'valley', 'a': 'Roof.Wing', 'b': 'Roof.Main', 'strategy': 'constructed'}])
    check('solidified sheet is measured, overlap fails', J(r)['status'] == 'FAIL' and J(r).get('worst_pen', 0) > .05, r)

    # 8. an open sheet inside a closed slab is measured against the slab (10 cm deep) and fails
    c = coll('open in closed')
    box(c, 'Roof.Main', (0, 0, 2), (4, 3, 2.2))
    sheet(c, 'Roof.Wing', [(3.5, 1, 2.1), (6, 1, 2.1), (6, 2, 2.1), (3.5, 2, 2.1)])
    r = run(c, [{'id': 'valley', 'a': 'Roof.Wing', 'b': 'Roof.Main', 'strategy': 'constructed'}])
    check('open sheet inside a slab fails', J(r)['status'] == 'FAIL' and abs(J(r)['worst_pen'] - .1) < .005, r)
    # 8b. single-sided roof sheets (game roof fields) over one square: main z = 2 + .5y, wing z = 2 + .5x. Untrimmed,
    # each runs behind the other (up to ~.9 m) and fails; trimmed at the valley line y = x they meet and pass.
    c = coll('sheets crossed')
    sheet(c, 'Roof.Main', [(0, 0, 2), (2, 0, 2), (2, 2, 3), (0, 2, 3)])
    sheet(c, 'Roof.Wing', [(0, 0, 2), (2, 0, 3), (2, 2, 3), (0, 2, 2)])
    r = run(c, [{'id': 'valley', 'a': 'Roof.Wing', 'b': 'Roof.Main', 'strategy': 'constructed'}])
    check('untrimmed roof sheets fail', J(r)['status'] == 'FAIL' and J(r)['worst_pen'] > .5, r)
    c = coll('sheets valley')
    sheet(c, 'Roof.Main', [(0, 0, 2), (2, 2, 3), (0, 2, 3)])
    sheet(c, 'Roof.Wing', [(0, 0, 2), (2, 0, 3), (2, 2, 3)])
    r = run(c, [{'id': 'valley', 'a': 'Roof.Wing', 'b': 'Roof.Main', 'strategy': 'constructed'}])
    check('roof sheets trimmed at the valley pass', r['status'] == 'PASS', r)
    # 8c. the same valley with the wing running 15 cm past the valley line, under the main sheet: fails on depth
    c = coll('sheets overshoot')
    sheet(c, 'Roof.Main', [(0, 0, 2), (2, 2, 3), (0, 2, 3)])
    sheet(c, 'Roof.Wing', [(0, .15, 2), (0, 0, 2), (2, 0, 3), (2, 2, 3), (1.85, 2, 2.925)])
    r = run(c, [{'id': 'valley', 'a': 'Roof.Wing', 'b': 'Roof.Main', 'strategy': 'constructed'}])
    check('wing sheet overshooting the valley fails', J(r)['status'] == 'FAIL' and .03 < J(r)['worst_pen'] < .2, r)

    # 8d. a rafter resting under a roof sheet (top 2 mm below it: an exactly coincident top would flicker, see 8f) is a
    # contact, not a clash (declared seat, and in the undeclared scan)
    c = coll('rafter under sheet')
    sheet(c, 'Roof.Field', [(0, 0, 2), (4, 0, 2), (4, 3, 2), (0, 3, 2)])
    box(c, 'Rafter', (1, -.3, 1.848), (1.1, 3.3, 1.998))
    r = run(c, [{'id': 'rafter', 'a': 'Rafter', 'b': 'Roof.Field', 'strategy': 'seated', 'max_pen': .02}], undeclared={'scan': True})
    check('rafter resting under a roof sheet passes', r['status'] == 'PASS', r)
    r = run(c, [], undeclared={'scan': True})
    check('rafter under a roof sheet is no undeclared clash', r['status'] == 'PASS', r)

    # 8e. a roof sheet ending exactly on a tower face is a clean seat; the same roof running 40 cm into the tower fails
    c = coll('roof on tower')
    box(c, 'Tower', (-2, -2, 0), (2, 2, 10))
    sheet(c, 'Roof.Hall', [(2, -1.9, 3.27), (8.4, -1.9, 3.27), (8.4, 0, 4.37), (2, 0, 4.37)])
    seat = {'id': 'roof-tower', 'a': 'Roof.Hall', 'b': 'Tower', 'strategy': 'seated', 'max_pen': .02, 'reach': .5}
    r = run(c, [seat], undeclared={'scan': True})
    check('roof sheet ending on a tower face passes', r['status'] == 'PASS', r)
    c = coll('roof into tower')
    box(c, 'Tower', (-2, -2, 0), (2, 2, 10))
    sheet(c, 'Roof.Hall', [(1.6, -1.9, 3.27), (8.4, -1.9, 3.27), (8.4, 0, 4.37), (1.6, 0, 4.37)])
    r = run(c, [seat])
    check('roof sheet running into the tower fails', J(r)['status'] == 'FAIL' and abs(J(r)['worst_pen'] - .4) < .01, r)

    # 8f. coincident faces: a board whose top lies exactly on the roof sheet flickers (fails); 2 mm lower it passes;
    # a panel laid on a wall face, not declared, fails the undeclared scan
    seat = {'id': 'board-roof', 'a': 'Board', 'b': 'Roof.Field', 'strategy': 'seated', 'max_pen': .005, 'max_gap': .01, 'min_cover': .8}
    c = coll('board on roof')
    sheet(c, 'Roof.Field', [(0, 0, 2), (4, 0, 2), (4, 3, 2), (0, 3, 2)])
    box(c, 'Board', (1, .5, 1.5), (1.05, 2.5, 2))
    r = run(c, [seat])
    check('board top lying on the roof fails on coincident faces', J(r)['status'] == 'FAIL' and 'coincident' in J(r)['members'][0]['reason'], r)
    c = coll('board under roof')
    sheet(c, 'Roof.Field', [(0, 0, 2), (4, 0, 2), (4, 3, 2), (0, 3, 2)])
    box(c, 'Board', (1, .5, 1.5), (1.05, 2.5, 1.998))
    r = run(c, [seat])
    check('board top 2 mm under the roof passes', r['status'] == 'PASS', r)
    c = coll('panel on wall')
    box(c, 'Wall', (0, 0, 0), (.3, 4, 3))
    sheet(c, 'Panel', [(.3, 1, 1), (.3, 2, 1), (.3, 2, 2), (.3, 1, 2)])
    r = run(c, [], undeclared={'scan': True})
    check('undeclared coincident panel fails the scan', r['undeclared']['status'] == 'FAIL', r)

    # 8g. cover is sampled finely: a 0.20 m beam on a 0.25 m post covers 80 % of the post top (a 4 x 4 grid read 100 %)
    c = coll('beam on post')
    box(c, 'Post', (3.875, -.125, 0), (4.125, .125, 2.8)); box(c, 'Beam', (0, -.1, 2.8), (4.325, .1, 3.05))
    pb = {'id': 'post-beam', 'a': 'Post', 'b': 'Beam', 'strategy': 'seated', 'max_pen': .005}
    r = run(c, [dict(pb, min_cover=.9)])
    check('beam narrower than its post fails full cover', J(r)['status'] == 'FAIL' and .7 < J(r)['worst_cover'] < .9, r)
    r = run(c, [dict(pb, min_cover=.75)])
    check('... and passes the 75 % cover it really has', r['status'] == 'PASS', r)

    # 9. orientation: an inside-out board fails, a correct one passes
    c = coll('orient')
    box(c, 'Gable.N', (0, 0, 0), (2, .1, 1), inside_out=True); box(c, 'Gable.S', (0, 3, 0), (2, 3.1, 1))
    r = run(c, [], orientation=['Gable.*'])
    check('inside-out board fails', r['orientation']['status'] == 'FAIL' and
          [d['part'] for d in r['orientation']['defects']] == ['Gable.N'], r)

    # 10. a self-intersecting gable outline (sloped edge ending below the bottom edge) triangulates flipped
    c = coll('bowtie')
    sheet(c, 'Gable.Board', [(0, 0, 0), (4, 0, 0), (4, 0, 2), (2, 0, 3), (1, 0, -.6)])   # last edge crosses the bottom edge
    r = run(c, [], orientation=['Gable.*'])
    check('bow-tie board fails', r['orientation']['status'] == 'FAIL', r)

    # 10b. extents, probes and facing: a roof built too small, an unfilled corner, a sheet facing down all fail
    c = coll('scene checks')
    sheet(c, 'Roof.Main', [(0, 0, 2), (4, 0, 2), (4, 3, 2.5), (0, 3, 2.5)])
    box(c, 'Ring.N', (-.3, 2, 6), (2, 2.3, 6.25)); box(c, 'Ring.E', (2, -2, 6), (2.3, 2, 6.25))
    r = run(c, [], extents=[{'part': 'Roof.Main', 'min': [0, 0, None], 'max': [4, 3, None]}],
            probes=[{'part': 'Ring.*', 'inside': [[1, 2.15, 6.1]]}, {'part': 'Roof.Main', 'on': [[2, 1.5, 2.25]]}], up=['Roof.*'])
    check('right extents, filled probe, upward sheet pass', r['status'] == 'PASS', r)
    r = run(c, [], extents=[{'part': 'Roof.Main', 'max': [4.5, None, None]}])
    check('roof short of its extent fails', r['extents']['status'] == 'FAIL', r)
    r = run(c, [], probes=[{'part': 'Ring.*', 'inside': [[2.15, 2.15, 6.1]]}, {'part': 'Roof.Main', 'on': [[2, 1.5, 2.4]]}])
    check('unfilled corner and off-surface point fail', len(r['probes']['defects']) == 2, r)
    c = coll('sheet down')
    sheet(c, 'Roof.Main', [(0, 0, 2), (0, 3, 2.5), (4, 3, 2.5), (4, 0, 2)])
    r = run(c, [], up=['Roof.*'])
    check('downward roof sheet fails', r['up']['status'] == 'FAIL', r)

    # 11. a pattern that matches nothing is inconclusive, never a silent pass
    c = coll('missing')
    box(c, 'Wall', (0, 0, 0), (.3, 4, 3))
    r = run(c, [{'id': 'beam-wall', 'a': 'Beam*', 'b': 'Wall', 'strategy': 'butt'}])
    check('missing part is inconclusive', J(r)['status'] == 'INCONCLUSIVE' and r['status'] == 'FAIL', r)

    # 12. undeclared overlaps fail the scan; the same pair declared as a seat passes
    c = coll('undeclared')
    box(c, 'Chimney', (1, 1, 1.8), (1.5, 1.5, 3)); box(c, 'Roof.Main', (0, 0, 2), (4, 3, 2.2))
    r = run(c, [], undeclared={'scan': True})
    check('undeclared overlap fails', r['undeclared']['status'] == 'FAIL', r)
    r = run(c, [{'id': 'chimney', 'a': 'Chimney', 'b': 'Roof.Main', 'strategy': 'seated', 'max_pen': .3}], undeclared={'scan': True})
    check('declared seat passes the scan', r['status'] == 'PASS', r)

    # 13. every matched part is judged: one good rail and one proud rail -> exactly one failing member
    c = coll('set')
    box(c, 'Post.A', (0, -.015, 0), (.03, .015, 1)); box(c, 'Rail.A', (.03, -.01, .8), (1.5, .01, .85))
    box(c, 'Post.B', (0, 1.985, 0), (.03, 2.015, 1)); box(c, 'Rail.B', (.03, 1.955, .8), (1.5, 2.045, .85))
    r = run(c, [{'id': 'rails', 'a': 'Rail.*', 'b': 'Post.*', 'strategy': 'butt'}])
    bad = [m['a'] for m in J(r)['members'] if m['status'] != 'PASS']
    check('each member judged on its own', J(r)['status'] == 'FAIL' and bad == ['Rail.B'], r)
except Exception:
    traceback.print_exc(); FAILS.append('exception')

print('JUNCTION_CHECK_TESTS', 'FAIL' if FAILS else 'PASS', FAILS)
sys.exit(1 if FAILS else 0)
