"""Negative and positive controls for logic_qa.py (run: blender -b --factory-startup --python blender_test_logic_qa.py).

Named blender_test_* so plain-Python unittest discovery (test_*.py) skips it: it needs bpy.

Every defect class gets a minimal scene that MUST be reported, and one clean scene with designed joints that MUST
pass. Exit code 1 on any failure. Deterministic: fixed geometry, no randomness.
"""
import sys
import traceback
from pathlib import Path

import bpy
import bmesh
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import logic_qa  # noqa: E402

FAILS = []


def box(coll, name, lo, hi):
    me = bpy.data.meshes.new(name); bm = bmesh.new()
    v = [bm.verts.new((x, y, z)) for z in (lo[2], hi[2]) for y in (lo[1], hi[1]) for x in (lo[0], hi[0])]
    for f in ((0, 2, 3, 1), (4, 5, 7, 6), (0, 1, 5, 4), (2, 6, 7, 3), (0, 4, 6, 2), (1, 3, 7, 5)):
        bm.faces.new([v[i] for i in f])
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces)); bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new(name, me); coll.objects.link(o); return o


def plane(coll, name, lo, hi, z):
    me = bpy.data.meshes.new(name)
    me.from_pydata([(lo[0], lo[1], z), (hi[0], lo[1], z), (hi[0], hi[1], z), (lo[0], hi[1], z)], [], [(0, 1, 2, 3)])
    o = bpy.data.objects.new(name, me); coll.objects.link(o); return o


def scene(tag):
    c = bpy.data.collections.new('case ' + tag); bpy.context.scene.collection.children.link(c)
    root = bpy.data.objects.new('T.NativeOrigin', None) if 'T.NativeOrigin' not in bpy.data.objects else bpy.data.objects['T.NativeOrigin']
    if root.name not in bpy.context.scene.objects:
        bpy.context.scene.collection.objects.link(root)
    return c, root


def check(tag, cond, detail):
    print(('PASS ' if cond else 'FAIL ') + tag + ('' if cond else ' :: ' + detail))
    if not cond:
        FAILS.append(tag)


def run(c, root, openings=()):
    bpy.context.view_layer.update()
    return logic_qa.run({'T': c}, list(openings), {'T': root}, land_roles=('T',))['roles']['T']


try:
    # 1. clean scene with designed joints: post on a stone base, beam on the post, rafter notched into an attic
    c, root = scene('clean')
    box(c, 'T.Hall.Post.A.StoneBase', (-.17, -.17, 0), (.17, .17, .12))
    box(c, 'T.Hall.Post.A', (-.1, -.1, .12), (.1, .1, 2.5))
    box(c, 'T.Hall.Plate', (-.3, -.1, 2.5), (2.0, .1, 2.62))
    box(c, 'T.Hall.Bracket.A', (-.05, -.05, 2.3), (.4, .05, 2.48))           # bracket arm tenoned .15 into the post, under the plate
    r = run(c, root)
    s = r['summary']
    check('clean scene has no findings', not any(v for k, v in s.items()), str(s))
    check('clean scene counts its designed joint', r['penetration']['joints_within_limit'].get('family default', 0) >= 1, str(r['penetration']))

    # 2. roof poke: a band beam passing up through a roof shell (r1b 'subsurface beams on market tower')
    c, root = scene('poke')
    box(c, 'T.Ground', (-2, -2, -.2), (2, 2, 0))
    box(c, 'T.Wall', (-1, -.1, 0), (1, .1, 3.0))
    box(c, 'T.Roof.Tower.HipField.LOW', (-1.5, -1.5, 3.0), (1.5, 1.5, 3.1))
    box(c, 'T.Tower.FloorBand.South', (-.5, -.12, 2.9), (.5, .12, 3.3))
    r = run(c, root)
    check('roof_poke detects a beam through the roof', any(x['part'] == 'T.Tower.FloorBand.South' for x in r['roof_poke']), str(r['roof_poke']))

    # 3. roof embed: a board fully inside the roof shell (no triangle crosses: overlap() alone misses it)
    c, root = scene('embed')
    box(c, 'T.Ground', (-2, -2, -.2), (2, 2, 0))
    box(c, 'T.Wall', (-1, -.1, 0), (1, .1, 3.0))
    box(c, 'T.Roof.Hall.HipField.LOW', (-1.5, -1.5, 3.0), (1.5, 1.5, 3.12))
    box(c, 'T.Hall.Signboard', (-.2, -.2, 3.03), (.2, .2, 3.09))
    r = run(c, root)
    check('roof_embed or penetration detects a fully contained board', any(x['part'] == 'T.Hall.Signboard' for x in r['roof_embed']) or r['penetration']['pairs'] >= 1,
          str(r['roof_embed']) + str(r['penetration']))

    # 4. penetration beyond any joint, and a joint over its limit
    c, root = scene('penetration')
    box(c, 'T.Ground', (-2, -2, -.2), (2, 2, 0))
    box(c, 'T.Crate', (0, 0, 0), (.5, .5, .5))
    box(c, 'T.Barrel', (.4, .4, 0), (.9, .9, .5))                        # 10 cm into the crate, no joint
    box(c, 'T.Hall.Post.B.StoneBase', (2.0, -.17, 0), (2.34, .17, .12))
    box(c, 'T.Hall.Post.B', (2.07, -.1, .02), (2.27, .1, 2.0))            # 10 cm into its base, joint max .02
    r = run(c, root)
    pairs = {(a, b) for a, b, *_ in r['penetration']['worst']} | {(b, a) for a, b, *_ in r['penetration']['worst']}
    check('penetration detects an unjointed overlap', ('T.Crate', 'T.Barrel') in pairs, str(r['penetration']))
    check('penetration detects a joint deeper than its limit', ('T.Hall.Post.B', 'T.Hall.Post.B.StoneBase') in pairs, str(r['penetration']))

    # 5. pierce: a baluster through a thin mid rail (protrusion stays under the rail joint limit)
    c, root = scene('pierce')
    box(c, 'T.Ground', (-2, -2, -.2), (2, 2, 0))
    box(c, 'T.Stair.Gallery.Baluster.01', (-.0225, -.0225, 0), (.0225, .0225, .55))
    box(c, 'T.Gallery.Nangan.MidRail.0', (-.5, -.0275, .40), (.5, .0275, .45))
    r = run(c, root)
    check('pierce detects a baluster through a rail', any(x['part'] == 'T.Stair.Gallery.Baluster.01' for x in r['pierce']), str(r['pierce']))

    # 6. floating part
    c, root = scene('floating')
    box(c, 'T.Ground', (-2, -2, -.2), (2, 2, 0))
    box(c, 'T.Lantern', (0, 0, 1.0), (.2, .2, 1.3))
    r = run(c, root)
    check('floating detects a part touching nothing', 'T.Lantern' in r['floating'], str(r['floating']))

    # 7. z-fighting: a board flush inside a sign (coincident front and back faces)
    c, root = scene('zfight')
    box(c, 'T.Ground', (-2, -2, -.2), (2, 2, 0))
    box(c, 'T.Sign', (0, 0, 0), (1, .02, 1))
    box(c, 'T.Board', (.2, 0, .2), (.8, .02, .8))
    r = run(c, root)
    check('zfight detects coincident same-facing faces', len(r['zfight']) >= 1, str(r['zfight']))

    # 8. doors and windows: blocked free area, door into nowhere, blocked window (+ the clean counterparts)
    c, root = scene('openings')
    box(c, 'T.Ground', (-3, -3, -.2), (3, 3, 0))
    box(c, 'T.Wall', (-2, 0, 0), (2, .14, 3.5))
    box(c, 'T.Obstacle.Column', (-1.1, -.6, 0), (-.9, -.4, 2.5))           # .4 m in front of door A
    ops = [dict(id='T.DoorA', role='T', kind='door', origin=[-1, 0, 0], u=[1, 0, 0], n=[0, -1, 0], width=1.0, z0=.0, z1=2.2),
           dict(id='T.DoorHigh', role='T', kind='door', origin=[1, 0, 0], u=[1, 0, 0], n=[0, -1, 0], width=.8, z0=1.5, z1=3.3),
           dict(id='T.WinA', role='T', kind='window', origin=[1.6, 0, 0], u=[1, 0, 0], n=[0, -1, 0], width=.5, z0=1.0, z1=1.6)]
    box(c, 'T.Shutter.Prop', (1.45, -.3, .9), (1.75, -.2, 1.7))            # .2 m in front of the window
    r = run(c, root, ops)
    check('door_free_area detects a column in front of a door', any(x['opening'] == 'T.DoorA' for x in r['door_free_area']), str(r['door_free_area']))
    check('door_support detects a raised door into nowhere', any(x['opening'] == 'T.DoorHigh' for x in r['door_support']), str(r['door_support']))
    check('window_clearance detects a blocked window', any(x['opening'] == 'T.WinA' for x in r['window_clearance']), str(r['window_clearance']))

    # 9. stair headroom
    c, root = scene('headroom')
    box(c, 'T.Ground', (-2, -2, -.2), (2, 2, 0))
    box(c, 'T.Stair.Main.Step.00', (0, 0, 0), (1, .3, 1.0))
    box(c, 'T.Hall.Plate', (-.5, -.5, 2.2), (1.5, .8, 2.3))                # 1.2 m over the tread
    box(c, 'T.Hall.Post.C', (-.5, -.5, 0), (-.3, -.3, 2.2))
    r = run(c, root)
    check('stair_headroom detects a beam 1.2 m over a tread', any(x['tread'] == 'T.Stair.Main.Step.00' for x in r['stair_headroom']), str(r['stair_headroom']))

    # 10. open shell is listed (containment undefined), not silently treated as solid
    c, root = scene('open')
    box(c, 'T.Ground', (-2, -2, -.2), (2, 2, 0))
    plane(c, 'T.Awning', (0, 0), (1, 1), 0.0)
    r = run(c, root)
    check('open_shells lists a single plane', 'T.Awning' in r['open_shells'], str(r['open_shells']))
    # 11. advisory inspection topics: each must be raised on its specimen; the clean scene raises none
    c, root = scene('inspect')
    box(c, 'T.Ground', (-3, -3, -.2), (3, 3, 0))
    box(c, 'T.Hall.Wall.A', (1.0, -1.0, 0), (1.14, 1.0, 4.0))
    box(c, 'T.Gallery.Deck', (0.0, -.5, 3.0), (.95, .5, 3.16))              # 5 cm short of the wall: a balcony not attached
    box(c, 'T.Gallery.Post.0.StoneBase', (-.1, -.1, 0), (.1, .1, .1))
    box(c, 'T.Gallery.Post.0', (-.06, -.06, .1), (.06, .06, 3.0))
    box(c, 'T.Frame.Post.A', (2.0, -.1, 0), (2.2, .1, 3.0))
    box(c, 'T.Frame.Bay.Lintel.0', (2.2, -.05, 2.0), (2.9, .16, 2.18))      # 6 cm proud of the post it butts into
    box(c, 'T.Front.Wall.B', (-2.5, -1.0, 0), (-1.0, -.86, 3.0))
    for nm_, lo_, hi_ in (('Jamb.Left', (-2.0, -1.12, 1.0), (-1.93, -.98, 2.0)), ('Jamb.Right', (-1.57, -1.12, 1.0), (-1.5, -.98, 2.0)),
                          ('Sill', (-1.93, -1.12, 1.0), (-1.57, -.98, 1.07)), ('Lintel', (-1.93, -1.12, 1.93), (-1.57, -.98, 2.0))):
        box(c, 'T.Front.Win.' + nm_, lo_, hi_)                               # frame 12 cm proud of the wall face (y -1.0)
    band = box(c, 'T.Front.Wall.Band', (-2.5, -1.0, .95), (-2.05, -.86, 1.10)); band['pc_region'] = 'wall_bottom'   # sill falls inside it
    box(c, 'T.Crate.A', (-2.8, 1.5, 0), (-2.3, 2.0, .5)); box(c, 'T.Crate.B', (-2.27, 1.5, 0), (-1.8, 2.0, .5))   # 3 cm slot
    ops = [dict(id='T.Front.Win', role='T', kind='window', origin=[-1.75, -1.0, 0], u=[1, 0, 0], n=[0, -1, 0], width=.5, z0=1.0, z1=2.0)]
    r = run(c, root, ops)
    I = r['inspect']
    check('inspect: attachment flags a balcony 5 cm off the wall', any(x['part'] == 'T.Gallery.Deck' for x in I['attachment']), str(I['attachment']))
    check('inspect: junction_proud flags a lintel proud of its post', any(x['member'] == 'T.Frame.Bay.Lintel.0' for x in I['junction_proud']), str(I['junction_proud']))
    check('inspect: frame_proud flags a 12 cm window frame', any(x['opening'] == 'T.Front.Win' for x in I['frame_proud']), str(I['frame_proud']))
    check('inspect: opening_band flags a sill inside a band', any(x['opening'] == 'T.Front.Win' and x['kind'] == 'inside' for x in I['opening_band']), str(I['opening_band']))
    check('inspect: near_gap flags a 3 cm slot', any({x['a'], x['b']} == {'T.Crate.A', 'T.Crate.B'} for x in I['near_gap']), str(I['near_gap']))
    c, root = scene('inspect-clean')
    box(c, 'T.Ground', (-3, -3, -.2), (3, 3, 0))
    box(c, 'T.Hall.Wall.A', (1.0, -1.0, 0), (1.14, 1.0, 4.0))
    box(c, 'T.Gallery.Deck', (0.0, -.5, 3.0), (1.0, .5, 3.16))              # touches the wall over its whole end face
    box(c, 'T.Gallery.Post.0', (-.06, -.06, 0), (.06, .06, 3.0))
    box(c, 'T.Frame.Post.A', (2.0, -.1, 0), (2.2, .1, 3.0))
    box(c, 'T.Frame.Bay.Lintel.0', (2.2, -.07, 2.0), (2.9, .09, 2.18))      # within the post's faces
    r = run(c, root)
    check('inspect: the clean specimen raises no topic', not any(r['inspect_summary'].values()), str(r['inspect_summary']))
except Exception:
    traceback.print_exc(); FAILS.append('exception')

print('LOGIC_QA_TESTS', 'FAILED ' + ', '.join(FAILS) if FAILS else 'ALL PASSED')
sys.exit(1 if FAILS else 0)
