"""Physics settle for arranged props (Blender rigid bodies, background, deterministic for one Blender build).
Research hybrid: upright props rest analytically (arrange_props.py) and stay PASSIVE; only the poses in --simulate
(lean, tipped, stack) fall under gravity. A member flagged "physics" in the spec settles whatever its pose. Heroes (--fixed) and props smaller than --small are passive too (Blender rigid
bodies are unstable below ~20 cm).
Per prop a temporary PROXY rigid body = convex hull of all its parts (world space, mass = hull volume x density); the
LOW parts near the props become PASSIVE mesh colliders (copies) plus a passive ground slab (top at z = 0). The catalog
meshes and the LOW are never touched. Active proxies start --lift above their pose with a seeded +-jitter tilt; frames run
in order; a prop is at rest when its last --rest frames move < 0.5 mm and turn < 0.05 deg. Accepted: write the delta
(proxy final @ proxy initial^-1) onto the prop root. Rejected (moving, tilt > --max-tilt, travelled > 0.5 m): the placed
(analytic) pose is kept and reported. Then a MARGIN SNAP drops every simulated prop straight down to 1 mm above the
surface under it (Bullet keeps hull-on-hull contacts ~2 x margin apart: 8 mm at margin 0.004). Proxies, the rigid-body
scene and its world are deleted: the output holds plain transforms on linked duplicates.
  blender -b <arranged.blend> --factory-startup --python settle_props.py -- --model <M> --out <blend> --report <json>
          --arrange-report ARRANGE_REPORT.json [--props-collection "{model} | PROPS"] [--fixed CannonOnChocks]
Defaults follow the research brief: substeps 20, iterations 30, margin 0.004, friction 0.6 props / 0.8 ground,
restitution 0, damping 0.3 / 0.6, 240 frames, rest window 12 frames."""
import argparse, json, math, random, sys
from pathlib import Path
import bmesh
import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

ap = argparse.ArgumentParser()
for k in ('model', 'out', 'report'):
    ap.add_argument('--' + k, required=True)
ap.add_argument('--frames', type=int, default=240); ap.add_argument('--rest', type=int, default=12)
ap.add_argument('--fixed', default='CannonOnChocks', help='catalog props that stay where placed (passive colliders): heroes')
ap.add_argument('--small', type=float, default=.25, help='props whose largest size is below this stay analytic (Blender: < ~20 cm is unstable)')
ap.add_argument('--lift', type=float, default=.03); ap.add_argument('--jitter', type=float, default=2.0)
ap.add_argument('--friction', type=float, default=.6); ap.add_argument('--ground-friction', type=float, default=.8); ap.add_argument('--restitution', type=float, default=0.0)
ap.add_argument('--lin-damp', type=float, default=.3); ap.add_argument('--ang-damp', type=float, default=.6)
ap.add_argument('--substeps', type=int, default=20); ap.add_argument('--iterations', type=int, default=30)
ap.add_argument('--margin', type=float, default=.004); ap.add_argument('--density', type=float, default=600.)
ap.add_argument('--radius', type=float, default=2.5); ap.add_argument('--max-tilt', type=float, default=12.)
ap.add_argument('--seed', type=int, default=5)
ap.add_argument('--props-collection', default='{model} | PROPS'); ap.add_argument('--low-collection', default='{model} | LOW geometry')
ap.add_argument('--scene', default='{model} | NATIVE MODEL', help='scene made active again before saving')
ap.add_argument('--arrange-report', help='arrange_props report: only the poses in --simulate get gravity, the rest stay analytic (passive)')
ap.add_argument('--simulate', default='lean,tipped,stack', help='poses that settle under gravity (research hybrid: upright props rest analytically)')
a = ap.parse_args(sys.argv[sys.argv.index('--') + 1:]); RNG = random.Random(a.seed)
for sc in bpy.data.scenes:
    for vl in sc.view_layers:
        vl.update()
props_col = bpy.data.collections[a.props_collection.format(model=a.model)]
roots = [o for o in props_col.objects if o.parent is None]
parts_of = {r: [c for c in props_col.objects if c.parent == r and c.type == 'MESH'] for r in roots}
low = [o for o in bpy.data.collections[a.low_collection.format(model=a.model)].all_objects if o.type == 'MESH']
dg = bpy.context.evaluated_depsgraph_get()


def world_verts(objs):
    P = []
    for o in objs:
        oe = o.evaluated_get(dg); me = oe.to_mesh(); P += [o.matrix_world @ v.co for v in me.vertices]; oe.to_mesh_clear()
    return P


sim = bpy.data.scenes.new(f'settle {a.model}'); bpy.context.window.scene = sim
sim.frame_start, sim.frame_end = 1, a.frames
bpy.ops.rigidbody.world_add(); W = sim.rigidbody_world
W.substeps_per_frame = a.substeps; W.solver_iterations = a.iterations
W.point_cache.frame_start, W.point_cache.frame_end = 1, a.frames
coll = bpy.data.collections.new('settle proxies'); sim.collection.children.link(coll)


def add_rb(o, kind, shape, mass=1.0, friction=None):
    bpy.context.view_layer.objects.active = o; o.select_set(True)
    bpy.ops.rigidbody.object_add(type=kind); rb = o.rigid_body
    rb.collision_shape = shape; rb.friction = a.friction if friction is None else friction; rb.restitution = a.restitution
    rb.use_margin = True; rb.collision_margin = a.margin
    if kind == 'ACTIVE':
        rb.mass = mass; rb.linear_damping = a.lin_damp; rb.angular_damping = a.ang_damp
    else:
        rb.mesh_source = 'BASE'
    o.select_set(False)


# passive building colliders near the props (mesh shapes, world-space copies)
centres = [sum(world_verts(parts_of[r]), Vector()) / max(len(world_verts(parts_of[r])), 1) for r in roots]
passive = 0
for o in low:
    P = world_verts([o]); c = sum(P, Vector()) / len(P); ext = max((p - c).length for p in P)
    if any((c - q).length < a.radius + ext for q in centres):
        me = o.evaluated_get(dg).to_mesh().copy(); me.transform(o.matrix_world); o.evaluated_get(dg).to_mesh_clear()
        p = bpy.data.objects.new(f'P|{o.name}', me); coll.objects.link(p); add_rb(p, 'PASSIVE', 'MESH', friction=a.ground_friction); passive += 1
# the ground is implicit in the building files (z = 0, no mesh): a thick passive slab under the whole site
gm = bpy.data.meshes.new('settle ground'); gbm = bmesh.new(); bmesh.ops.create_cube(gbm, size=1.0); gbm.to_mesh(gm); gbm.free()
allc = [p for r in roots for p in world_verts(parts_of[r])]; gx = sum(p.x for p in allc) / len(allc); gy = sum(p.y for p in allc) / len(allc)
ground = bpy.data.objects.new('P|ground z=0', gm); coll.objects.link(ground)
ground.matrix_world = Matrix.Translation((gx, gy, -.25)) @ Matrix.Diagonal((60, 60, .5, 1)); bpy.context.view_layer.update()
bpy.context.view_layer.objects.active = ground; ground.select_set(True); bpy.ops.object.transform_apply(location=False, rotation=False, scale=True); ground.select_set(False)
add_rb(ground, 'PASSIVE', 'BOX', friction=a.ground_friction); passive += 1
# active proxies: convex hull of each prop's parts, origin at its centre, lifted + tiny seeded tilt
state = {}
FIXED = set(a.fixed.split(',')); SIM = set(a.simulate.split(','))
POSE = {}; PHYS = set()
if a.arrange_report:
    for row in json.load(open(a.arrange_report))['models'][a.model]['rows']:
        if 'FAILED' not in row:
            POSE[row['id']] = row['pose']
            if row.get('physics'):
                PHYS.add(row['id'])
for r in roots:
    P = world_verts(parts_of[r]); c = sum(P, Vector()) / len(P)
    size = max(max(p[j] for p in P) - min(p[j] for p in P) for j in range(3)); kind = r.name.split('.')[2]
    bm = bmesh.new()
    for p in P:
        bm.verts.new(p - c)
    bmesh.ops.convex_hull(bm, input=bm.verts[:]); me = bpy.data.meshes.new(f'hull {r.name}'); bm.to_mesh(me); bm.free()
    vol = abs(sum(f.normal.dot(me.vertices[f.vertices[0]].co) * f.area for f in me.polygons) / 3)
    o = bpy.data.objects.new(f'A|{r.name}', me); coll.objects.link(o)
    tilt = Matrix.Rotation(math.radians(RNG.uniform(-a.jitter, a.jitter)), 4, 'X') @ Matrix.Rotation(math.radians(RNG.uniform(-a.jitter, a.jitter)), 4, 'Y')
    o.matrix_world = Matrix.Translation(c + Vector((0, 0, a.lift))) @ tilt
    pose = POSE.get(r.name.split('.', 3)[3]) if POSE else None
    if kind in FIXED or size < a.small or (POSE and pose not in SIM and r.name.split('.', 3)[3] not in PHYS):   # heroes, tiny and analytic props: passive, placed pose kept
        o.matrix_world = Matrix.Translation(c); bpy.context.view_layer.update(); add_rb(o, 'PASSIVE', 'CONVEX_HULL')
        state[r.name] = {'proxy': o, 'M0': Matrix.Translation(c), 'fixed': True, 'pose': pose, 'mass_kg': None}; continue
    bpy.context.view_layer.update(); add_rb(o, 'ACTIVE', 'CONVEX_HULL', mass=max(.5, vol * a.density))
    state[r.name] = {'proxy': o, 'M0': Matrix.Translation(c), 'start': o.matrix_world.copy(), 'mass_kg': round(max(.5, vol * a.density), 2)}
# run the simulation frame by frame (the cache needs sequential frames) and track the last frames' motion
track = {k: [] for k in state}
for f in range(1, a.frames + 1):
    sim.frame_set(f)
    if f > a.frames - a.rest:
        for k, s in state.items():
            track[k].append(s['proxy'].matrix_world.copy())
rows = []
bpy.context.window.scene = bpy.data.scenes[a.scene.format(model=a.model)]
for r in roots:
    s = state[r.name]
    if s.get('fixed'):
        rows.append({'prop': r.name, 'settled': True, 'fixed': True, 'pose': s.get('pose'), 'note': 'passive (hero / small / analytic upright): placed pose kept'}); continue
    Mf = track[r.name][-1]
    move = max((Mf.translation - M.translation).length for M in track[r.name])
    rot = max(math.degrees(Mf.to_quaternion().rotation_difference(M.to_quaternion()).angle) for M in track[r.name])
    delta = Mf @ s['M0'].inverted()                          # proxy final pose relative to the placed (unlifted) pose
    up0 = (r.matrix_world.to_3x3() @ Vector((0, 0, 1))).normalized(); up1 = ((delta @ r.matrix_world).to_3x3() @ Vector((0, 0, 1))).normalized()
    tilt = math.degrees(up0.angle(up1)); drop = (s['M0'].translation - Mf.translation).length
    ok = move < .0005 and rot < .05 and tilt <= a.max_tilt and drop < .5
    s['ok'] = ok
    if ok:
        r.matrix_world = delta @ r.matrix_world
    rows.append({'prop': r.name, 'mass_kg': s['mass_kg'], 'settled': ok, 'tilt_change_deg': round(tilt, 2), 'travel_m': round(drop, 3),
                 'rest_motion_mm': round(move * 1000, 3), 'rest_rotation_deg': round(rot, 3)})
    print('SETTLE', r.name, 'OK' if ok else 'KEPT PLACED POSE', rows[-1], flush=True)
bpy.data.scenes.remove(sim)
# margin snap: Bullet keeps hull-on-hull contacts ~2 x margin apart (8 mm at margin .004), so a settled prop hovers over
# its support. Drop every simulated prop straight down to 1 mm above the nearest surface below (orientation kept).
for sc_ in bpy.data.scenes:
    for vl in sc_.view_layers:
        vl.update()
lowV, lowT = [], []
for o in low:
    P = world_verts([o]); c = sum(P, Vector()) / len(P)
    if any((c - q).length < a.radius + max((p - c).length for p in P) for q in centres):
        me = o.evaluated_get(dg).to_mesh(); me.calc_loop_triangles(); b = len(lowV)
        lowV += [o.matrix_world @ v.co for v in me.vertices]; lowT += [[b + i for i in tr.vertices] for tr in me.loop_triangles]; o.evaluated_get(dg).to_mesh_clear()
LOWB = BVHTree.FromPolygons(lowV, lowT, all_triangles=True) if lowT else None


def prop_bvh(r):
    V, T = [], []
    for o in parts_of[r]:
        me = o.evaluated_get(dg).to_mesh(); me.calc_loop_triangles(); b = len(V)
        V += [o.matrix_world @ v.co for v in me.vertices]; T += [[b + i for i in tr.vertices] for tr in me.loop_triangles]; o.evaluated_get(dg).to_mesh_clear()
    return V, (BVHTree.FromPolygons(V, T, all_triangles=True) if T else None)


snapped = {}
moved = [r for r in roots if state[r.name].get('ok')]
for r in sorted(moved, key=lambda r_: min(p.z for p in world_verts(parts_of[r_]))):      # bottom-up: bases before tops
    V, _ = prop_bvh(r); zmin = min(p.z for p in V); band = [p for p in V if p.z < zmin + .05]
    others = [prop_bvh(q)[1] for q in roots if q is not r]
    gapz = min(p.z for p in band)                                                # ground plane z = 0
    for p in band:
        for b in [LOWB] + others:
            if b is None:
                continue
            h = b.ray_cast(p + Vector((0, 0, 1e-4)), Vector((0, 0, -1)), .05)
            if h[0] is not None:
                gapz = min(gapz, p.z - h[0].z)
    if gapz > .0015:
        r.matrix_world = Matrix.Translation((0, 0, -(gapz - .001))) @ r.matrix_world; bpy.context.view_layer.update()
    snapped[r.name] = round(gapz * 1000, 2)
for row in rows:
    if row['prop'] in snapped:
        row['margin_snap_gap_mm'] = snapped[row['prop']]
print('SETTLE_SNAP', json.dumps(snapped), flush=True)
for o in list(coll.objects):
    bpy.data.objects.remove(o, do_unlink=True)
bpy.data.collections.remove(coll); bpy.data.orphans_purge(do_recursive=True)
for sc in bpy.data.scenes:
    for vl in sc.view_layers:
        vl.update()
bpy.ops.wm.save_as_mainfile(filepath=str(Path(a.out).resolve()), copy=True, relative_remap=False)
rep = {'model': a.model, 'params': vars(a), 'passive_colliders': passive, 'props': len(rows),
       'settled': sum(r_['settled'] for r_ in rows), 'rows': rows}
Path(a.report).write_text(json.dumps(rep, indent=1)); print('SETTLE_DONE', json.dumps({k: v for k, v in rep.items() if k not in ('rows', 'params')}))
