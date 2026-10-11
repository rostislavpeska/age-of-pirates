"""Organic prop arrangement (Blender, background, deterministic per seed): story CLUSTERS of catalog props placed by seeded
rejection sampling with hard gates, in poses beyond "upright and square" - yaw off the building axes, TIPPED (on a side),
LEANING on a wall plane, STACKED on a flat-top prop, NESTLED against a wall or a placed prop. Physical rest is refined
afterwards by settle_props.py and gated by prop_metrics.py (see ../SKILL.md for the whole workflow).

Props are linked duplicates of a catalog (root empty '<root_prefix><Prop>' + parented mesh parts, appended once from
"library"; meshes, UVs and attributes are never touched; uniform scale 1).
Hard gates per try: 0 BVH intersections with the LOW and with other props (1 mm lift), support = highest building surface
under 3 x 3 inner probes (rays from 1.6 m - below eaves), outside every clearance box, footprint inside the cluster zone
(stack / lean / wall-nestled exempt), no prop nested inside another (ray parity of part centres), a stack's
centre >= 2 cm inside its base's top, access corridors empty, hero clearance (plan hull gap 0.15 m for members that
"serves" the hero, 0.35 m for the rest - nothing on, over or against the hero), no accidental axis row (3+ centres within
0.10 m on one x or y line, unless "row_ok"). Supports are the building only: a prop rests on another prop only as a
declared "stack" on a "flat_top" base. Yaws: "wall_yaw" +-3..12 deg (never exactly parallel), stacks +-5..25 deg against
the base, "yaw_toward" aims a prop (+-"yaw_jitter", default 25), free yaws never within 8 deg of square.

spec = {"library": <catalog .blend>, "catalog_collection": ..., "root_prefix": "Props.", "seed": 13,
        "flat_top": ["AmmoCrate", ...], "collections": {"props": "{model} | PROPS", "scene": ..., "low": ...},
        "models": {"<Model>": {
          "clear": {name: [[x0, y0, z0], [x1, y1, z1]]}, "zones": {name: [[x, y], ...]},
          "corridors": {name: [[x0, y0], [x1, y1], width]},
          "clusters": [{"id", "story", "zone", "anchor": [x, y], "spread": m, "members": [
              {"id", "prop", "pose": "upright|tipped|lean|stack", "at": [x, y], "spread": m, "hero": true,
               "serves": "<hero id>", "wall_yaw": deg, "yaw_toward": [x, y], "yaw_jitter": deg, "on": "<base id>",
               "wall": {"point": [x, y], "normal": [nx, ny]}, "tilt": deg,
               "against": {"wall": {...} | "prop": "<placed id>", "gap": [g0, g1]}, "row_ok": true,
               "physics": true (settle this member under gravity whatever its pose, e.g. a carrier resting on a stick)}]}]}}}
  blender -b <file> --factory-startup --python refresh_view_layers.py --python arrange_props.py -- --spec SPEC.json
          --out <blend> --report <json> [--replace] [--tries 400]
Report: per prop pose, yaw, support, bbox, tries; failures with rejection reasons counted (never dropped silently)."""
import argparse, hashlib, json, math, random, sys
from pathlib import Path
import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

ap = argparse.ArgumentParser(); [ap.add_argument('--' + k, required=True) for k in ('spec', 'out', 'report')]
ap.add_argument('--replace', action='store_true'); ap.add_argument('--tries', type=int, default=400)
a = ap.parse_args(sys.argv[sys.argv.index('--') + 1:])
for sc in bpy.data.scenes:
    for vl in sc.view_layers:
        vl.update()
SPEC = json.loads(Path(a.spec).read_text(encoding='utf-8')); lib = str(Path(SPEC['library']).resolve())
RNG = random.Random(SPEC.get('seed', 7))
need = sorted({m['prop'] for md in SPEC['models'].values() for c in md['clusters'] for m in c['members']})
CATN = SPEC.get('catalog_collection', 'Props | CATALOG (appended, do not edit)'); PFX = SPEC.get('root_prefix', 'Props.')
COLS = {'props': '{model} | PROPS', 'scene': '{model} | NATIVE MODEL', 'low': '{model} | LOW geometry', **SPEC.get('collections', {})}
cat = bpy.data.collections.get(CATN)
have = {o.name for o in cat.objects} if cat else set()
missing = [p for p in need if f'{PFX}{p}' not in have]
if missing:
    with bpy.data.libraries.load(lib, link=False) as (src, dst):
        dst.objects = [n for n in src.objects if any(n == f'{PFX}{p}' or n.startswith(f'{PFX}{p}.') for p in missing)]
    if not cat:
        cat = bpy.data.collections.new(CATN)
    for o in dst.objects:
        cat.objects.link(o)
roots = {p: bpy.data.objects[f'{PFX}{p}'] for p in need}
kids = {p: [o for o in cat.objects if o.parent == roots[p]] for p in need}
ROW_TOL = .10                                                      # research: axis rows = 3+ centres within 0.10 m
FLAT_TOP = set(SPEC.get('flat_top', []))                         # stack bases (flat tops); never round kegs / jars / barrels


def bvh(objs, lift=0.0):
    V, T = [], []
    dg = bpy.context.evaluated_depsgraph_get()
    for o in objs:
        oe = o.evaluated_get(dg); me = oe.to_mesh(); mw = o.matrix_world; base = len(V); me.calc_loop_triangles()
        V += [mw @ v.co + Vector((0, 0, lift)) for v in me.vertices]; T += [[base + i for i in t.vertices] for t in me.loop_triangles]
        oe.to_mesh_clear()
    return BVHTree.FromPolygons(V, T, all_triangles=True) if T else None


def verts(objs):
    dg = bpy.context.evaluated_depsgraph_get(); P = []
    for o in objs:
        oe = o.evaluated_get(dg); me = oe.to_mesh(); P += [o.matrix_world @ v.co for v in me.vertices]; oe.to_mesh_clear()
    return P


def inside(poly, x, y):
    c = False; n = len(poly)
    for i in range(n):
        (x1, y1), (x2, y2) = poly[i], poly[(i + 1) % n]
        if (y1 > y) != (y2 > y) and x < (x2 - x1) * (y - y1) / (y2 - y1 + 1e-12) + x1:
            c = not c
    return c


def hull2(P):
    """plan convex hull (monotone chain) of world points"""
    pts = sorted({(round(p.x, 4), round(p.y, 4)) for p in P})
    if len(pts) < 3:
        return pts
    def cr(o, a_, b_): return (a_[0] - o[0]) * (b_[1] - o[1]) - (a_[1] - o[1]) * (b_[0] - o[0])
    lo_, up_ = [], []
    for q in pts:
        while len(lo_) >= 2 and cr(lo_[-2], lo_[-1], q) <= 0: lo_.pop()
        lo_.append(q)
    for q in reversed(pts):
        while len(up_) >= 2 and cr(up_[-2], up_[-1], q) <= 0: up_.pop()
        up_.append(q)
    return lo_[:-1] + up_[:-1]


def seg_dist(p, a_, b_):
    ax_, ay_ = b_[0] - a_[0], b_[1] - a_[1]; L2 = ax_ * ax_ + ay_ * ay_ or 1e-12
    t = max(0., min(1., ((p[0] - a_[0]) * ax_ + (p[1] - a_[1]) * ay_) / L2))
    return math.hypot(p[0] - a_[0] - t * ax_, p[1] - a_[1] - t * ay_)


def hull_gap(A, B):
    """plan distance between two convex hulls (0 if they overlap)"""
    if any(inside(B, x, y) for x, y in A) or any(inside(A, x, y) for x, y in B):
        return 0.0
    return min(min(seg_dist(p, B[i], B[(i + 1) % len(B)]) for i in range(len(B))) for p in A)


def inside_mesh(b, p, eps=1e-4):
    """ray-parity point-in-mesh test on a BVH: odd hit counts along +x, +y, +z (2 of 3 votes)"""
    votes = 0
    for d in (Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))):
        o, n = p.copy(), 0
        for _ in range(64):
            h = b.ray_cast(o, d, 50.)
            if h[0] is None:
                break
            n += 1; o = h[0] + d * eps
        votes += n % 2
    return votes >= 2


def part_centres(parts):
    out = []
    for o in parts:
        V = verts([o])
        if V:
            out.append(sum(V, Vector()) / len(V))
    return out


def seg_box_hit(p0, p1, half, lo, hi, n=24):
    """does the plan segment p0-p1 widened by `half` touch the box lo-hi (sampled)"""
    for i in range(n + 1):
        t = i / n; x = p0[0] + t * (p1[0] - p0[0]); y = p0[1] + t * (p1[1] - p0[1])
        if lo.x - half < x < hi.x + half and lo.y - half < y < hi.y + half:
            return True
    return False


def pose_matrix(m, yaw):
    R = Matrix.Rotation(math.radians(yaw), 4, 'Z')
    if m['pose'] == 'tipped':                                   # lying on its side: roll 90 deg about the local X axis
        R = R @ Matrix.Rotation(math.radians(90 + RNG.uniform(-4, 4)), 4, 'X')
    elif m['pose'] == 'lean':                                   # tilt toward the wall about the horizontal axis along the wall
        nx, ny = m['wall']['normal']; axis = Vector((-ny, nx, 0)).normalized()
        R = Matrix.Rotation(math.radians(-m.get('tilt', 12)), 4, axis) @ R
    return R


rep = {'spec': a.spec, 'library_sha256': hashlib.sha256(Path(lib).read_bytes()).hexdigest(), 'models': {}}
for role, md in SPEC['models'].items():
    PCOL = COLS['props'].format(model=role)
    if a.replace and bpy.data.collections.get(PCOL):
        old = bpy.data.collections[PCOL]
        for o in list(old.objects):
            bpy.data.objects.remove(o, do_unlink=True)
        bpy.data.collections.remove(old)
    scn = bpy.data.scenes[COLS['scene'].format(model=role)]; VL = scn.view_layers[0]
    if cat.name not in [c.name for c in scn.collection.children]:
        scn.collection.children.link(cat)
        next(c for c in VL.layer_collection.children if c.collection == cat).exclude = True
    col = bpy.data.collections.new(PCOL); scn.collection.children.link(col)
    low = [o for o in bpy.data.collections[COLS['low'].format(model=role)].all_objects if o.type == 'MESH']
    low_bvh = bvh(low); placed = {}; rows = []; YAW = {}; HERO = {}; CEN = {}; BOX = {}; PC_ = {}
    for cl in md['clusters']:
        zone = md['zones'][cl['zone']]
        for i, m in enumerate(cl['members']):
            mid = m.get('id', f"{cl['id']}.{i}"); name = m['prop']; ok = False; why = {}
            for t in range(a.tries):
                if m['pose'] == 'stack' and m['on'] not in placed:
                    break                                         # base failed: this stack fails too (reported below)
                if m['pose'] == 'stack':
                    assert placed[m['on']][2] in FLAT_TOP, (mid, 'stack base must have a flat top', placed[m['on']][2])
                    base = placed[m['on']]; bp = verts(base[1]); bx = sum(p.x for p in bp) / len(bp); by = sum(p.y for p in bp) / len(bp)
                    sx, sy = m.get('at', (bx, by)); sp = m.get('spread', .06)              # several items can share one base
                    x, y = sx + RNG.uniform(-sp, sp), sy + RNG.uniform(-sp, sp)
                else:
                    ax, ay = m.get('at', cl['anchor']); s = m.get('spread', cl['spread'])
                    x, y = ax + RNG.gauss(0, s), ay + RNG.gauss(0, s)
                if not inside(zone, x, y):
                    why['anchor outside zone'] = why.get('anchor outside zone', 0) + 1; continue
                if 'wall_yaw' in m:
                    yaw = m['wall_yaw'] + RNG.choice((-1, 1)) * RNG.uniform(3, 12)
                elif m['pose'] == 'stack':
                    yaw = YAW[m['on']] + RNG.choice((-1, 1)) * RNG.uniform(5, 25)
                elif 'yaw_toward' in m:                        # e.g. the cannon aimed at the gate, +-25 deg
                    tx, ty = m['yaw_toward']; yaw = math.degrees(math.atan2(ty - y, tx - x)) + m.get('yaw_offset', 0) + RNG.uniform(-m.get('yaw_jitter', 25), m.get('yaw_jitter', 25))
                else:
                    yaw = RNG.uniform(0, 360)
                if 'wall_yaw' not in m and m['pose'] not in ('tipped', 'stack') and 'yaw_toward' not in m:
                    while min(abs(((yaw % 90) + 90) % 90), 90 - abs(((yaw % 90) + 90) % 90)) < 8:      # never square to the building
                        yaw = RNG.uniform(0, 360)
                r0 = roots[name]; R = pose_matrix(m, yaw)
                root = r0.copy(); col.objects.link(root); root.parent = None; root.name = f'{role}.Prop.{name}.{mid}'
                parts = []
                for k in kids[name]:
                    c = k.copy(); col.objects.link(c); c.parent = root; c.matrix_parent_inverse = k.matrix_parent_inverse.copy(); parts.append(c)
                root.matrix_world = Matrix.Translation((x, y, 0)) @ R @ Matrix.Translation(-r0.matrix_world.translation) @ r0.matrix_world
                VL.update(); P = verts(parts)
                lo = Vector([min(p[j] for p in P) for j in range(3)]); hi = Vector([max(p[j] for p in P) for j in range(3)])
                if m['pose'] == 'lean':                          # slide toward the wall until the nearest vertex touches it
                    nx, ny = m['wall']['normal']; wx, wy = m['wall']['point']
                    dmin = min((p.x - wx) * nx + (p.y - wy) * ny for p in P)
                    root.matrix_world = Matrix.Translation((-nx * (dmin - .004), -ny * (dmin - .004), 0)) @ root.matrix_world; VL.update(); P = verts(parts)
                if 'against' in m:                               # nestle: slide until the plan gap to a wall / placed prop is in range
                    ag = m['against']; g0, g1 = ag.get('gap', [.003, .008]); gap_ = RNG.uniform(g0, g1)
                    if 'wall' in ag:
                        nx, ny = ag['wall']['normal']; wx, wy = ag['wall']['point']
                        dmin = min((p.x - wx) * nx + (p.y - wy) * ny for p in P)
                        root.matrix_world = Matrix.Translation((-nx * (dmin - gap_), -ny * (dmin - gap_), 0)) @ root.matrix_world
                    elif ag.get('prop') in placed:
                        Ht = hull2(verts(placed[ag['prop']][1]))
                        for _ in range(12):
                            Hm = hull2(P); G = hull_gap(Hm, Ht)
                            if abs(G - gap_) < .002 or G == 0.0:
                                break
                            mx = sum(x_ for x_, _y in Hm) / len(Hm); my = sum(y_ for _x, y_ in Hm) / len(Hm)
                            tx = sum(x_ for x_, _y in Ht) / len(Ht); ty = sum(y_ for _x, y_ in Ht) / len(Ht)
                            L = math.hypot(tx - mx, ty - my) or 1e-9; st = (G - gap_) * .9
                            root.matrix_world = Matrix.Translation(((tx - mx) / L * st, (ty - my) / L * st, 0)) @ root.matrix_world
                            VL.update(); P = verts(parts)
                    VL.update(); P = verts(parts)
                # support: highest surface under the inner footprint (rays from 1.6 m above the ground, below eaves)
                lo = Vector([min(p[j] for p in P) for j in range(3)]); hi = Vector([max(p[j] for p in P) for j in range(3)])
                # supports: the building only; a declared stack rests on its named base only (owner 2026-10-11: "the chests on
                # the barrel look weird" - an upright crate had landed on a keg because every placed prop counted as support)
                sup = 0.0; others = [low_bvh] + ([bvh(placed[m['on']][1])] if m['pose'] == 'stack' else [])
                for fu in (.3, .5, .7):
                    for fv in (.3, .5, .7):
                        px, py = lo.x + fu * (hi.x - lo.x), lo.y + fv * (hi.y - lo.y)
                        for b in others:
                            h = b.ray_cast(Vector((px, py, max(1.6, lo.z + 1.6))), Vector((0, 0, -1)), 3.5)
                            if h[0] is not None and h[0].z < hi.z + 1.0:
                                sup = max(sup, h[0].z)
                root.matrix_world = Matrix.Translation((0, 0, sup - lo.z + .001)) @ root.matrix_world; VL.update()
                if m.get('against', {}).get('prop') in placed:   # 3D refine: plan hulls touch long before the surfaces do
                    tp = placed[m['against']['prop']][1]; tb = bvh(tp); TV = verts(tp)
                    for _ in range(15):
                        P = verts(parts); mb = bvh(parts)
                        d3 = min(min(tb.find_nearest(v)[3] for v in P), min(mb.find_nearest(v)[3] for v in TV))
                        if d3 - gap_ < .0015:
                            break
                        mx = sum(p.x for p in P) / len(P); my = sum(p.y for p in P) / len(P)
                        tx = sum(p.x for p in TV) / len(TV); ty = sum(p.y for p in TV) / len(TV); L = math.hypot(tx - mx, ty - my) or 1e-9
                        st = (d3 - gap_) * .9
                        root.matrix_world = Matrix.Translation(((tx - mx) / L * st, (ty - my) / L * st, 0)) @ root.matrix_world; VL.update()
                P = verts(parts); lo = Vector([min(p[j] for p in P) for j in range(3)]); hi = Vector([max(p[j] for p in P) for j in range(3)])
                pb = bvh(parts, lift=.001)
                hit_low = len(pb.overlap(low_bvh)) if pb else 0
                hit_props = sum(len(pb.overlap(bvh(pp[1]))) for k_, pp in placed.items() if not (m['pose'] == 'stack' and k_ == m['on'])) if pb else 0
                if m['pose'] == 'stack':                         # resting ON the base prop is contact, everything else must be clear
                    base_hit = len(pb.overlap(bvh(placed[m['on']][1], lift=-.002)))
                    hit_props += base_hit
                clr = [k for k, (b0, b1) in md['clear'].items() if all(lo[j] < b1[j] and hi[j] > b0[j] for j in range(3))]
                # NESTED: BVH overlap only sees crossing surfaces - a prop fully inside another passes it (Monastery m1:
                # a hangari accepted inside a dok). Part centres of either prop inside the other = rejected.
                for k_, pp in placed.items():
                    plo, phi = BOX[k_]
                    if all(lo[j] < phi[j] - .01 and hi[j] > plo[j] + .01 for j in range(3)):
                        qb = bvh(pp[1])
                        if (qb and any(inside_mesh(qb, c) for c in part_centres(parts))) or (pb and any(inside_mesh(pb, c) for c in PC_[k_])):
                            clr.append(f'inside {k_}')
                if m['pose'] == 'stack':                         # the stacked prop's centre sits >= 2 cm inside its base's top
                    Hb = hull2(verts(placed[m['on']][1])); cx0, cy0 = (lo.x + hi.x) / 2, (lo.y + hi.y) / 2
                    if not inside(Hb, cx0, cy0) or min(seg_dist((cx0, cy0), Hb[i], Hb[(i + 1) % len(Hb)]) for i in range(len(Hb))) < .02:
                        clr.append('stack off its base top')
                # HERO: nothing on, over or against it (owner 2026-10-11: the barrel is the great asset, crews need it free)
                for hid, hh in HERO.items():
                    g = .15 if m.get('serves') == hid else .35
                    if hull_gap(hull2(P), hh) < g:
                        clr.append(f'hero {hid} clearance {g} m')
                for cname, (p0, p1, wdt) in md.get('corridors', {}).items():   # access corridors (segment, width); they lead TO the hero
                    if not m.get('hero') and seg_box_hit(p0, p1, wdt / 2, lo, hi):
                        clr.append(f'corridor {cname}')
                cx_, cy_ = (lo.x + hi.x) / 2, (lo.y + hi.y) / 2       # no accidental axis rows (>= 3 centres on one x / y line)
                if m['pose'] != 'stack' and not m.get('row_ok'):
                    if sum(abs(c[0] - cx_) <= ROW_TOL for c in CEN.values()) >= 2:
                        clr.append('axis row x')
                    if sum(abs(c[1] - cy_) <= ROW_TOL for c in CEN.values()) >= 2:
                        clr.append('axis row y')
                inz = all(inside(zone, xx, yy) for xx, yy in ((lo.x, lo.y), (lo.x, hi.y), (hi.x, lo.y), (hi.x, hi.y))) or m['pose'] in ('stack', 'lean') or 'wall' in m.get('against', {})
                if hit_low == 0 and hit_props == 0 and not clr and inz:
                    placed[mid] = (root, parts, name); ok = True; YAW[mid] = yaw; BOX[mid] = (lo.copy(), hi.copy()); PC_[mid] = part_centres(parts)
                    if m['pose'] != 'stack':
                        CEN[mid] = (cx_, cy_)
                    if m.get('hero'):
                        HERO[mid] = hull2(P)
                    rows.append({'id': mid, 'cluster': cl['id'], 'story': cl.get('story'), 'prop': name, 'pose': m['pose'], 'yaw': round(yaw % 360, 1),
                                 'xy': [round(x, 3), round(y, 3)], 'support_z': round(sup, 3), 'bbox': [[round(v, 3) for v in lo], [round(v, 3) for v in hi]],
                                 'tries': t + 1, 'intersections_low': 0, 'intersections_props': 0, 'clearance_hits': [], 'physics': bool(m.get('physics')),
                                 'shares_catalog_meshes': all(p.data == k.data for p, k in zip(parts, kids[name]))})
                    break
                for r_ in (['hits LOW'] if hit_low else []) + (['hits props'] if hit_props else []) + clr + ([] if inz else ['footprint leaves zone']):
                    why[r_] = why.get(r_, 0) + 1
                for o in parts + [root]:
                    bpy.data.objects.remove(o, do_unlink=True)
                VL.update()
            if not ok:
                rows.append({'id': mid, 'cluster': cl['id'], 'prop': name, 'pose': m['pose'], 'FAILED': f'no valid pose in {a.tries} tries', 'rejections': dict(sorted(why.items(), key=lambda kv: -kv[1]))})
            print('ARRANGE', role, mid, name, m['pose'], 'OK' if ok else 'FAILED ' + json.dumps(why), flush=True)
    good = [r for r in rows if 'FAILED' not in r]                 # layout metrics + stability: prop_metrics.py (the gate)
    rep['models'][role] = {'placed': len(good), 'failed': [r['id'] for r in rows if 'FAILED' in r],
                           'gate3': 'PASS' if len(good) == len(rows) else 'FAIL',
                           'poses': {p_: sum(r['pose'] == p_ for r in good) for p_ in ('upright', 'tipped', 'lean', 'stack')},
                           'rows': rows}
    print('ARRANGE_DONE', role, json.dumps({k: v for k, v in rep['models'][role].items() if k != 'rows'}), flush=True)
bpy.ops.wm.save_as_mainfile(filepath=str(Path(a.out).resolve()), copy=True, relative_remap=False)
Path(a.report).write_text(json.dumps(rep, indent=1))
