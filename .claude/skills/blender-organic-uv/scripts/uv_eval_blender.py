"""Blender stage of the UV cleanness evaluator (background Blender only; the .blend is read, never saved).

    blender -b FILE.blend --factory-startup --python-exit-code 2 --python uv_eval_blender.py -- --objects A,B
            --uv-layer UVMap --page 1024 --out ABS_OUTDIR [options]

Normally started by uv_eval.py (host), which also draws the UV pictures and the summary card. Run with -- --help for
the options. Writes OUT/metrics.json, OUT/data.npz and OUT/renders/*.png. OUT must be absolute and outside every git
work tree.

Pose for visibility (default: the bind pose of the file, nothing else occludes):
  --pose-frame N [--pose-action NAME]   evaluate the meshes with their Armature modifiers at frame N (optionally with
                                        the named action assigned to those armatures first): Blender's own skinning
  --pose-npz FILE                       posed positions written by another tool (a game layer's pose simulator):
                                        arrays pose__<object> (V,3, world, the mesh's vertex order), optional
                                        occluder_P (N,3) + occluder_F (M,3) (e.g. a mount) and forward (3,)
"""
import argparse
import hashlib
import json
import math
import os
import sys
import time

import bpy
import numpy as np
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import uvlib as L  # noqa: E402
import uvenv  # noqa: E402

TOOL_VERSION = 'uv_eval 1.1 (blender-organic-uv, 2026-10-11)'


def parse(argv):
    ap = argparse.ArgumentParser(prog='uv_eval_blender.py', description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--objects', required=True, help='comma list of mesh objects sharing ONE texture page')
    ap.add_argument('--uv-layer', required=True, help='UV layer name evaluated on every object')
    ap.add_argument('--page', type=int, required=True, help='page size in texels (square), e.g. 1024')
    ap.add_argument('--out', required=True, help='absolute output folder outside any git work tree')
    ap.add_argument('--label', default='', help='run label printed on the pictures')
    ap.add_argument('--occluders', default='', help='comma list of extra objects that hide faces (e.g. the helmet '
                                                     'when evaluating the body); the evaluated objects always occlude')
    ap.add_argument('--pose-frame', type=int, help='evaluate Armature modifiers at this frame (posed visibility)')
    ap.add_argument('--pose-action', help='action assigned to the driving armatures before --pose-frame')
    ap.add_argument('--pose-npz', help='posed positions from another tool (see the module help)')
    ap.add_argument('--forward', default='0,-1,0', help='unit forward x,y,z: heading 0 looks at this side (default '
                                                        'the -Y front of Blender\'s front view)')
    ap.add_argument('--part-attr', default='part', help="face attribute with part labels (default 'part')")
    ap.add_argument('--part-names', help='JSON {int: name} for an INT part attribute')
    ap.add_argument('--part-map', help='JSON {object: [part per loop triangle or per polygon]} (when the attribute '
                                       'is absent)')
    ap.add_argument('--bone-regions', help='JSON [[region, regex], ...] for the bone-region estimator (default: '
                                           'Biped-style names, uvlib.DEFAULT_REGION_RULES)')
    ap.add_argument('--mirror-overlap', choices=['none', 'x'], default='none',
                    help='declared mirror stacking: overlaps between faces that are mirror images across x=0 count '
                         'as declared, every other overlap is unintended (default none = all unintended)')
    ap.add_argument('--mirror-tol', type=float, default=0.01, help='centroid tolerance for mirror pairs (model units)')
    ap.add_argument('--gutter-px', type=float, default=4.0, help='minimum island gap in texels at the page size')
    ap.add_argument('--tiny-px', type=float, default=16.0, help='an island smaller than tiny^2 texels is tiny')
    ap.add_argument('--metres-per-unit', type=float, default=1.0, help='model units -> metres (texel density t/m)')
    ap.add_argument('--floor-tu', type=float, help='report the area share below this texel density (texels per model '
                                                   'unit), e.g. a project-wide density floor; off by default')
    ap.add_argument('--headings', type=int, default=8)
    ap.add_argument('--pitch', type=float, default=47.0, help='game camera pitch below horizontal, degrees (set the '
                                                           'camera of the consuming game)')
    ap.add_argument('--double-sided', action='store_true', help='back faces are drawn (default: culled, single-sided)')
    ap.add_argument('--res', type=int, default=560, help='render size of the model views')
    ap.add_argument('--game-res', type=int, default=360, help='render size of each game-camera tile')
    ap.add_argument('--no-render', action='store_true')
    return ap.parse_args(argv)


# ---------------------------------------------------------------- extraction
def sha256(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for b in iter(lambda: f.read(1 << 20), b''):
            h.update(b)
    return h.hexdigest()


def extract(ob, uv_name, a, part_map, part_names):
    me = ob.data
    mw = np.array(ob.matrix_world)
    V = np.array([tuple(v.co) for v in me.vertices], float).reshape(-1, 3)
    V = (np.c_[V, np.ones(len(V))] @ mw.T)[:, :3]
    me.calc_loop_triangles()
    lt = me.loop_triangles
    F = np.array([tuple(t.vertices) for t in lt], int).reshape(-1, 3)
    LP = np.array([tuple(t.loops) for t in lt], int).reshape(-1, 3)
    poly = np.array([t.polygon_index for t in lt], int)
    # corner order for the dominant-bone tie rule: a triangle polygon keeps its own corner order (loop triangles may
    # start at another corner), so this estimator agrees with island_priority.py on the same mesh
    Fdom = np.array([tuple(me.polygons[p].vertices) if len(me.polygons[p].vertices) == 3 else tuple(f)
                     for p, f in zip(poly, F)], int).reshape(-1, 3)
    if uv_name not in me.uv_layers:
        raise SystemExit('%s has no UV layer %r (has %s)' % (ob.name, uv_name, [u.name for u in me.uv_layers]))
    layers = {}
    for u in me.uv_layers:
        buf = np.zeros(len(me.loops) * 2)
        u.data.foreach_get('uv', buf)
        layers[u.name] = buf.reshape(-1, 2)
    UV = layers[uv_name][LP]
    real = {tuple(sorted(e.vertices)) for e in me.edges}
    parts = None
    src = None
    at = me.attributes.get(a.part_attr)
    if at is not None and at.domain == 'FACE':
        vals = [d.value for d in at.data]
        names = part_names or {}
        parts = [str(names.get(str(vals[p]), vals[p])) for p in poly]
        src = 'face attribute %s' % a.part_attr
    elif part_map and ob.name in part_map and isinstance(part_map[ob.name], list):
        pm = part_map[ob.name]
        if len(pm) == len(F):
            parts = [str(x) for x in pm]
            src = 'part map (per loop triangle)'
        elif len(pm) == len(me.polygons):
            parts = [str(pm[p]) for p in poly]
            src = 'part map (per polygon)'
    gn = {g.index: g.name for g in ob.vertex_groups}
    vw = []
    for v in me.vertices:
        w = sorted(((gn[g.group], g.weight) for g in v.groups if g.weight > 0 and g.group in gn), key=lambda t: -t[1])
        vw.append(w[:4])
    # GPU vertex estimate over EVERY UV layer the file carries (an exporter may write them all)
    loop_v = np.zeros(len(me.loops), int)
    me.loops.foreach_get('vertex_index', loop_v)
    keys = set()
    rounded = [np.round(layers[n], 6) for n in sorted(layers)]
    for li in range(len(me.loops)):
        keys.add((int(loop_v[li]),) + tuple(float(x) for r in rounded for x in r[li]))
    return dict(name=ob.name, V=V, F=F, Fdom=Fdom, UV=UV, poly=poly, real=real, parts=parts, part_src=src, vw=vw,
                n_polys=len(me.polygons), uv_layers=list(layers), gpu_all_layers=len(keys))


# ---------------------------------------------------------------- pose
def assign_action(names, action):
    act = bpy.data.actions.get(action)
    if act is None:
        raise SystemExit('action not found: %s' % action)
    arms = []
    for n in names:
        for m in bpy.data.objects[n].modifiers:
            if m.type == 'ARMATURE' and m.object is not None and m.object not in arms:
                arms.append(m.object)
    if not arms:
        raise SystemExit('--pose-action: no Armature modifier with an object on %s' % names)
    for arm in arms:
        ad = arm.animation_data or arm.animation_data_create()
        ad.action = act
        try:                                   # Blender 4.4+ layered actions: pick the first slot when none is set
            if getattr(ad, 'action_slot', None) is None and len(act.slots):
                ad.action_slot = act.slots[0]
        except (AttributeError, TypeError):
            pass
    return [o.name for o in arms]


def evaluated_positions(names, frame):
    sc = bpy.context.scene
    sc.frame_set(int(frame))
    dg = bpy.context.evaluated_depsgraph_get()
    out = {}
    for n in names:
        ob = bpy.data.objects[n]
        oe = ob.evaluated_get(dg)
        me = oe.to_mesh()
        try:
            if len(me.vertices) != len(ob.data.vertices):
                raise SystemExit('%s: evaluated vertex count %d != %d (a modifier other than the armature changes '
                                 'topology)' % (n, len(me.vertices), len(ob.data.vertices)))
            V = np.array([tuple(v.co) for v in me.vertices], float).reshape(-1, 3)
            mw = np.array(oe.matrix_world)
            out[n] = (np.c_[V, np.ones(len(V))] @ mw.T)[:, :3]
        finally:
            oe.to_mesh_clear()
    return out


# ---------------------------------------------------------------- visibility
def cam_dirs(fwd, headings, pitch):
    out = []
    cp, sp = math.cos(math.radians(pitch)), math.sin(math.radians(pitch))
    for h in range(headings):
        a = 2 * math.pi * h / headings
        c, s = math.cos(a), math.sin(a)
        d = np.array([c * fwd[0] - s * fwd[1], s * fwd[0] + c * fwd[1], 0.0])
        out.append(np.array([d[0] * cp, d[1] * cp, sp]))
    return out


def tri_normals(P, F):
    n = np.cross(P[F[:, 1]] - P[F[:, 0]], P[F[:, 2]] - P[F[:, 0]])
    return n / np.maximum(np.linalg.norm(n, axis=1), 1e-30)[:, None]


class Occluder:
    def __init__(self, P, F, double_sided):
        self.P, self.F = P, F
        self.N = tri_normals(P, F)
        self.bvh = BVHTree.FromPolygons([Vector(v) for v in P], [tuple(int(x) for x in f) for f in F],
                                        all_triangles=True)
        self.ds = double_sided
        self.diag = float(np.linalg.norm(P.max(0) - P.min(0)))

    def blocked(self, origin, to_cam):
        o = Vector(origin)
        d = Vector(to_cam)
        eps = 1e-5 * self.diag
        for _ in range(16):
            loc, nrm, idx, dist = self.bvh.ray_cast(o, d)
            if loc is None:
                return False
            if self.ds or float(np.dot(self.N[idx], to_cam)) > 0:
                return True
            o = loc + d * eps
        return False


BARY = np.array([[1 / 3, 1 / 3, 1 / 3], [2 / 3, 1 / 6, 1 / 6], [1 / 6, 2 / 3, 1 / 6], [1 / 6, 1 / 6, 2 / 3]])


def face_visibility(Pe, Fe, occ, dirs, double_sided):
    N = tri_normals(Pe, Fe)
    off = 2e-4 * occ.diag
    vis = np.zeros((len(dirs), len(Fe)))
    front = np.zeros((len(dirs), len(Fe)), bool)
    for h, d in enumerate(dirs):
        dots = N @ d
        fr = dots > 1e-6 if not double_sided else np.abs(dots) > 1e-6
        front[h] = fr
        for t in np.nonzero(fr)[0]:
            Q = Pe[Fe[t]]
            nn = N[t] if dots[t] > 0 else -N[t]
            hit = 0
            for b in BARY:
                p = b @ Q + nn * off
                if not occ.blocked(p, d):
                    hit += 1
            vis[h, t] = hit / len(BARY)
    return vis, front


def edge_visibility(Pe, Fe, edges_sel, occ, dirs, front):
    N = tri_normals(Pe, Fe)
    off = 2e-4 * occ.diag
    out = np.zeros((len(dirs), len(edges_sel)), bool)
    for j, e in enumerate(edges_sel):
        a, b = e['v']
        fs = e['faces']
        for h, d in enumerate(dirs):
            if not all(front[h, t] for t in fs):
                continue
            nn = sum(N[t] for t in fs)
            nn = nn / max(np.linalg.norm(nn), 1e-30)
            if np.dot(nn, d) < 0:
                nn = -nn
            for s in (0.25, 0.5, 0.75):
                p = Pe[a] * (1 - s) + Pe[b] * s + nn * off
                if not occ.blocked(p, d):
                    out[h, j] = True
                    break
    return out


# ---------------------------------------------------------------- renders
def colormap_div(x, lo=-1.0, hi=1.0):
    """diverging blue-white-red for x in [lo, hi] (0 = white)."""
    t = np.clip((np.asarray(x, float) - lo) / (hi - lo), 0, 1)
    c0 = np.array([0.16, 0.32, 0.75])
    c1 = np.array([0.97, 0.97, 0.97])
    c2 = np.array([0.80, 0.10, 0.10])
    out = np.where((t < 0.5)[:, None], c0 + (c1 - c0) * (t / 0.5)[:, None], c1 + (c2 - c1) * ((t - 0.5) / 0.5)[:, None])
    return out


def colormap_seq(x, lo, hi):
    """sequential white -> yellow -> red -> dark purple."""
    t = np.clip((np.asarray(x, float) - lo) / (hi - lo), 0, 1)
    stops = np.array([[0.97, 0.97, 0.95], [0.99, 0.80, 0.30], [0.90, 0.30, 0.15], [0.45, 0.05, 0.35]])
    pos = t * (len(stops) - 1)
    i = np.minimum(pos.astype(int), len(stops) - 2)
    f = (pos - i)[:, None]
    return stops[i] * (1 - f) + stops[i + 1] * f


def srgb_to_lin(c):
    c = np.asarray(c, float)
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


class Renderer:
    """Workbench renders. Heatmaps are a FLAT colour pass with alpha plus a STUDIO white SINGLE-colour pass, multiplied
    on the host (uv_draw.composite_heatmaps): STUDIO light alone turns white faces mid-grey and hides the scale."""

    def __init__(self, a, outdir):
        self.a = a
        self.dir = os.path.join(outdir, 'renders')
        os.makedirs(self.dir, exist_ok=True)
        sc = bpy.context.scene
        self.sc = sc
        for o in sc.objects:
            o.hide_render = True
        sc.render.engine = 'BLENDER_WORKBENCH'
        sh = sc.display.shading
        sh.light = 'STUDIO'
        sh.show_backface_culling = not a.double_sided
        try:
            sh.show_cavity = False
        except Exception:  # noqa: BLE001
            pass
        sc.display.render_aa = '8'
        sc.render.film_transparent = False
        if sc.world is None:
            sc.world = bpy.data.worlds.new('uveval_world')
        sc.world.color = (0.62, 0.62, 0.64)
        try:
            sc.view_settings.view_transform = 'Standard'
            sc.view_settings.look = 'None'
        except Exception:  # noqa: BLE001
            pass
        sc.render.image_settings.file_format = 'PNG'
        sc.render.resolution_percentage = 100
        cd = bpy.data.cameras.new('UVEVAL_CAM')
        cd.type = 'ORTHO'
        cd.clip_start = 0.001
        cd.clip_end = 1000.0
        self.cam = bpy.data.objects.new('UVEVAL_CAM', cd)
        sc.collection.objects.link(self.cam)
        sc.camera = self.cam
        self.checker = bpy.data.images.new('uveval_checker', a.page, a.page, alpha=False)
        self.checker.generated_type = 'COLOR_GRID'
        self.grey = bpy.data.images.new('uveval_grey', 4, 4, alpha=False)
        self.grey.generated_type = 'BLANK'
        self.grey.generated_color = (0.55, 0.55, 0.57, 1.0)
        self.objs = []

    def mat(self, name, image):
        m = bpy.data.materials.new(name)
        try:
            m.use_nodes = True
        except Exception:  # noqa: BLE001
            pass
        nt = m.node_tree
        bsdf = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
        tex = nt.nodes.new('ShaderNodeTexImage')
        tex.image = image
        tex.interpolation = 'Linear'
        nt.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
        nt.nodes.active = tex
        m.diffuse_color = (0.55, 0.55, 0.57, 1.0)
        return m

    def add(self, name, P, F, UV=None, face_col=None, evaluated=True):
        me = bpy.data.meshes.new('UVEVAL_' + name)
        me.from_pydata([tuple(v) for v in P], [], [tuple(int(x) for x in f) for f in F])
        me.update()
        uvl = me.uv_layers.new(name='uveval')
        if UV is not None:
            uvl.data.foreach_set('uv', UV.reshape(-1).astype(np.float32))
        me.uv_layers.active = uvl
        uvl.active_render = True
        col = me.color_attributes.new('uveval_col', 'FLOAT_COLOR', 'CORNER')
        if face_col is None:
            face_col = np.tile([0.55, 0.55, 0.57], (len(F), 1))
        self.set_cols(me, face_col)
        me.color_attributes.active_color = col
        try:
            me.attributes.active_color = col
        except Exception:  # noqa: BLE001
            pass
        me.shade_flat()
        o = bpy.data.objects.new('UVEVAL_' + name, me)
        self.sc.collection.objects.link(o)
        o.data.materials.append(self.mat('uveval_m_' + name, self.checker if evaluated else self.grey))
        o['uveval_eval'] = evaluated
        self.objs.append(o)
        return o

    def set_cols(self, me, face_col):
        lin = srgb_to_lin(face_col)
        c = np.repeat(np.c_[lin, np.ones(len(lin))], 3, axis=0)
        me.color_attributes['uveval_col'].data.foreach_set('color', c.reshape(-1).astype(np.float32))

    def frame(self, objs, to_cam, up_hint=(0, 0, 1), margin=1.06, fixed_scale=None):
        z = np.asarray(to_cam, float)
        z = z / np.linalg.norm(z)
        x = np.cross(np.asarray(up_hint, float), z)
        if np.linalg.norm(x) < 1e-6:
            x = np.cross((0, 1, 0), z)
        x = x / np.linalg.norm(x)
        y = np.cross(z, x)
        V = np.vstack([np.array([tuple(o.matrix_world @ v.co) for v in o.data.vertices]) for o in objs])
        px, py, pz = V @ x, V @ y, V @ z
        cx, cy = (px.min() + px.max()) / 2, (py.min() + py.max()) / 2
        ext = max(px.max() - px.min(), py.max() - py.min()) * margin
        pos = x * cx + y * cy + z * (pz.max() + 5.0)
        M = Matrix(((x[0], y[0], z[0], pos[0]), (x[1], y[1], z[1], pos[1]), (x[2], y[2], z[2], pos[2]),
                    (0, 0, 0, 1)))
        self.cam.matrix_world = M
        self.cam.data.ortho_scale = fixed_scale if fixed_scale else ext
        return ext

    def shot(self, path, res, visible, color_type, light='STUDIO', transparent=False):
        for o in self.objs:
            o.hide_render = o not in visible
        sh = self.sc.display.shading
        sh.color_type = color_type
        sh.light = light
        if color_type == 'SINGLE':
            sh.single_color = (1.0, 1.0, 1.0)
        self.sc.render.film_transparent = transparent
        self.sc.render.resolution_x = res
        self.sc.render.resolution_y = res
        self.sc.render.filepath = path
        bpy.ops.render.render(write_still=True)
        return path


VIEWS = {'front': (0.0, -1.0, 0.0), 'back': (0.0, 1.0, 0.0), 'side_left': (1.0, 0.0, 0.0),
         'three_quarter': (0.64, -0.70, 0.32)}


# ---------------------------------------------------------------- main
def main():
    a = parse(uvenv.blender_argv())
    t0 = time.time()
    out = a.out
    if not os.path.isabs(out):
        raise SystemExit('--out must be absolute (Blender resolves relative paths to the drive root)')
    why = uvenv.refuse_in_worktree(out, 'output folder')
    if why:
        raise SystemExit(why)
    os.makedirs(out, exist_ok=True)
    names = [n for n in a.objects.split(',') if n]
    occ_names = [n for n in a.occluders.split(',') if n and n not in names]
    part_map = json.load(open(a.part_map)) if a.part_map else None
    part_names = json.load(open(a.part_names)) if a.part_names else None
    region_rules = json.load(open(a.bone_regions)) if a.bone_regions else None
    O = bpy.data.objects
    for n in names + occ_names:
        if n not in O or O[n].type != 'MESH':
            raise SystemExit('mesh object not found: %s' % n)
    ex = {n: extract(O[n], a.uv_layer, a, part_map, part_names) for n in names}
    occ_ex = {}
    for n in occ_names:
        ob = O[n]
        uvn = a.uv_layer if a.uv_layer in ob.data.uv_layers else ob.data.uv_layers[0].name if ob.data.uv_layers else None
        if uvn is None:
            ob.data.uv_layers.new(name='tmp')
            uvn = 'tmp'
        occ_ex[n] = extract(ob, uvn, a, None, None)

    # ---- concatenate the evaluation set (one page)
    Vs, Fs, UVs, objid, parts, real, polys, Fdoms = [], [], [], [], [], set(), [], []
    off = 0
    for i, n in enumerate(names):
        d = ex[n]
        Vs.append(d['V'])
        Fs.append(d['F'] + off)
        Fdoms.append(d['Fdom'] + off)
        UVs.append(d['UV'])
        polys.append(d['poly'])
        objid += [i] * len(d['F'])
        parts += d['parts'] if d['parts'] else ['(%s)' % n] * len(d['F'])
        real |= {(x + off, y + off) for x, y in d['real']}
        off += len(d['V'])
    P = np.vstack(Vs)
    F = np.vstack(Fs)
    UV = np.vstack(UVs)
    poly_idx = np.concatenate(polys)
    objid = np.array(objid)
    T = len(F)
    page = a.page
    vw_all = [w for n in names for w in ex[n]['vw']]

    # ---- pose and visibility
    fwd = np.array([float(x) for x in a.forward.split(',')])
    fwd[2] = 0.0
    fwd = fwd / max(np.linalg.norm(fwd), 1e-9)
    pose_info = {'mode': 'bind', 'note': 'bind (rest) pose of the .blend; nothing else occludes'}
    posed = {n: ex[n]['V'] for n in names}
    posed_occ = {n: occ_ex[n]['V'] for n in occ_names}
    extra_occ = None
    if a.pose_npz and a.pose_frame is not None:
        raise SystemExit('--pose-npz and --pose-frame are exclusive')
    if a.pose_frame is not None:
        arms = assign_action(names + occ_names, a.pose_action) if a.pose_action else None
        pp = evaluated_positions(names + occ_names, a.pose_frame)
        posed = {n: pp[n] for n in names}
        posed_occ = {n: pp[n] for n in occ_names}
        pose_info = {'mode': 'frame', 'frame': a.pose_frame, 'action': a.pose_action, 'armatures': arms,
                     'note': 'Blender-evaluated Armature modifiers at frame %d%s' % (
                         a.pose_frame, (' with action %s' % a.pose_action) if a.pose_action else '')}
    elif a.pose_npz:
        Z = np.load(a.pose_npz)
        for n in names + occ_names:
            k = 'pose__' + n
            if k in Z.files:
                Pz = np.asarray(Z[k], float)
                if Pz.shape != (len(ex.get(n, occ_ex.get(n))['V']), 3):
                    raise SystemExit('%s: pose array shape %s, mesh has %d vertices' % (k, Pz.shape,
                                                                                      len(ex.get(n, occ_ex.get(n))['V'])))
                (posed if n in names else posed_occ)[n] = Pz
        if 'occluder_P' in Z.files and 'occluder_F' in Z.files:
            extra_occ = (np.asarray(Z['occluder_P'], float), np.asarray(Z['occluder_F'], int))
        if 'forward' in Z.files:
            fwd = np.asarray(Z['forward'], float).copy()
            fwd[2] = 0.0
            fwd = fwd / max(np.linalg.norm(fwd), 1e-9)
        pose_info = {'mode': 'npz', 'file': a.pose_npz, 'posed_objects': sorted(k[6:] for k in Z.files if k.startswith('pose__')),
                     'extra_occluder_tris': int(len(extra_occ[1])) if extra_occ else 0,
                     'note': 'posed positions from %s%s' % (os.path.basename(a.pose_npz),
                                                            ' (+ an extra occluder)' if extra_occ else '')}
    Pe = np.vstack([posed[n] for n in names])
    occP, occF = [Pe], [F]
    base = len(Pe)
    for n in occ_names:
        occP.append(posed_occ[n])
        occF.append(occ_ex[n]['F'] + base)
        base += len(posed_occ[n])
    if extra_occ is not None:
        occP.append(extra_occ[0])
        occF.append(extra_occ[1] + base)
    occ = Occluder(np.vstack(occP), np.vstack(occF), a.double_sided)
    dirs = cam_dirs(fwd, a.headings, a.pitch)
    vis, front = face_visibility(Pe, F, occ, dirs, a.double_sided)

    # ---- topology
    edges = L.edge_table(F, UV, real_edges=real)
    lab = L.islands(T, edges)
    n_isl = int(lab.max() + 1) if T else 0
    seams = [e for e in edges if e['kind'] == 'seam']
    borders = [e for e in edges if e['kind'] == 'border']
    nonman = [e for e in edges if e['kind'] == 'nonmanifold']
    seam_vis = edge_visibility(Pe, F, seams, occ, dirs, front)
    elen = lambda e: float(np.linalg.norm(P[e['v'][0]] - P[e['v'][1]]))  # noqa: E731
    seam_len = np.array([elen(e) for e in seams])
    border_len = np.array([elen(e) for e in borders])
    mpu = a.metres_per_unit

    # ---- distortion
    fm = L.face_metrics(P, F, UV, page)
    ok = fm['ok']
    A3 = fm['area3d']
    Auv = fm['area_uv']
    tot3 = float(A3.sum())
    totuv = float(Auv.sum())
    Lg = math.sqrt(float((fm['L2'][ok] ** 2 * A3[ok]).sum() / A3[ok].sum())) * fm['k'] if ok.any() else None
    Linf = float(fm['Gamma'][ok].max() * fm['k']) if ok.any() else None
    dens = fm['density'] / mpu                              # texels per metre
    dens_u = fm['density']

    # ---- islands
    isl = []
    unit, upw = L.up_in_uv(P, F, UV)
    orient = L.island_orientation(unit, upw, lab, n_isl)
    for i in range(n_isl):
        m = lab == i
        uvpts = UV[m].reshape(-1, 2)
        fl = fm['flipped'][m]
        isl.append(dict(id=i, faces=int(m.sum()), obj=names[int(objid[m][0])],
                        area_uv_px=float(Auv[m].sum() * page * page), area3d_m2=float(A3[m].sum() * mpu * mpu),
                        bbox_px=[float(uvpts[:, 0].min() * page), float(uvpts[:, 1].min() * page),
                                 float(uvpts[:, 0].max() * page), float(uvpts[:, 1].max() * page)],
                        flipped_faces=int(fl.sum()), mirrored=bool(fl.all() and m.sum() > 0),
                        orient_deg=None if orient[i][0] is None else round(orient[i][0], 2),
                        orient_coherence=round(orient[i][1], 4), orient_weight=orient[i][2],
                        visible_share=float((vis.max(0)[m] > 0).astype(float) @ A3[m] / max(A3[m].sum(), 1e-30)),
                        L2_stretch_island=L.r(math.sqrt(float((fm['L2'][m & ok] ** 2 * A3[m & ok]).sum()
                                                              / max(A3[m & ok].sum(), 1e-30)))
                                              * math.sqrt(float(Auv[m].sum()) / max(float(A3[m].sum()), 1e-30)), 4)
                        if (m & ok).any() else None,
                        density_t_per_m=L.r(page * math.sqrt(float(Auv[m].sum()) / max(float(A3[m].sum()), 1e-30)) / mpu, 1),
                        parts=sorted(set(parts[t] for t in np.nonzero(m)[0]))))
    sizes = np.array([x['area_uv_px'] for x in isl]) if isl else np.zeros(0)
    tiny = a.tiny_px ** 2

    # ---- gutters
    seg, sid = L.outline_segments(edges, lab)
    gaps = L.island_gaps(seg, sid, chunk=256)
    ov = L.tri_overlaps(UV, min_area=0.01 / (page * page))
    cent = P[F].mean(1)
    ov_rows = []
    ov_area = {'self_fold': 0.0, 'declared_mirror': 0.0, 'unintended': 0.0}
    overlapping_isl = set()
    for t1, t2, ar in ov:
        if lab[t1] == lab[t2]:
            kind = 'self_fold'
        else:
            kind = 'unintended'
            if a.mirror_overlap == 'x':
                mc = cent[t1] * np.array([-1.0, 1.0, 1.0])
                if np.linalg.norm(mc - cent[t2]) < a.mirror_tol:
                    kind = 'declared_mirror'
            overlapping_isl.add((min(lab[t1], lab[t2]), max(lab[t1], lab[t2])))
        ov_area[kind] += ar
        ov_rows.append((int(t1), int(t2), float(ar * page * page), kind))
    gap_rows = []
    for (i, j), (dv, pa, pb) in gaps.items():
        dpx = 0.0 if (i, j) in overlapping_isl else dv * page
        gap_rows.append((int(i), int(j), float(dpx), (pa * page).tolist(), (pb * page).tolist()))
    for (i, j) in overlapping_isl:
        if (i, j) not in gaps:
            gap_rows.append((int(i), int(j), 0.0, None, None))
    gap_rows.sort(key=lambda r_: r_[2])
    min_gap = gap_rows[0][2] if gap_rows else None
    nmips = int(math.log2(page)) + 1
    bleed = []
    for mlev in range(nmips):
        bleed.append(sum(1 for g in gap_rows if g[2] / (2 ** mlev) < 1.0))
    if min_gap is None:
        vanish = None
    elif min_gap < 1.0:
        vanish = 0
    else:
        vanish = int(math.floor(math.log2(min_gap))) + 1
    below = [g for g in gap_rows if g[2] < a.gutter_px]
    if len(seg):
        pts = seg.reshape(-1, 2)
        border_gap = float(np.min(np.minimum.reduce([pts[:, 0], 1 - pts[:, 0], pts[:, 1], 1 - pts[:, 1]])) * page) + 0.0
    else:
        border_gap = None

    # ---- coverage
    cnt, first, multi = L.raster_cover(UV, lab, page)
    covered = int((cnt > 0).sum())
    sq = np.array([[0, 0], [1, 0], [1, 1], [0, 1]], float)
    inside = 0.0
    for t in range(T):
        inside += L.poly_area(L.clip_poly(list(L.tri_ccw(UV[t])), sq))
    allp = UV.reshape(-1, 2)
    bb = [float(allp[:, 0].min()), float(allp[:, 1].min()), float(allp[:, 0].max()), float(allp[:, 1].max())]
    bb_c = [max(0, bb[0]), max(0, bb[1]), min(1, bb[2]), min(1, bb[3])]
    bb_area = max(0.0, bb_c[2] - bb_c[0]) * max(0.0, bb_c[3] - bb_c[1])

    # ---- texel density stats
    def dstats(mask, weights=None):
        w = A3 * (weights if weights is not None else 1.0)
        w = np.where(mask, w, 0.0)
        q = L.wquantile(dens, w, [0.1, 0.5, 0.9])
        mean = L.wmean(dens, w)
        sd = math.sqrt(L.wmean((dens - mean) ** 2, w)) if mean is not None else None
        return {'p10': L.r(q[0], 1), 'p50': L.r(q[1], 1), 'p90': L.r(q[2], 1), 'mean': L.r(mean, 1),
                'cv': L.r(sd / mean if mean else None, 4), 'area_m2': L.r(float(w.sum()) * mpu * mpu, 5)}
    all_m = np.ones(T, bool)
    vis_any = vis.max(0) > 0
    vis_mean = vis.mean(0)
    per_part = {}
    for pn in sorted(set(parts)):
        m = np.array([p == pn for p in parts])
        st = dstats(m)
        st['faces'] = int(m.sum())
        st['L2_stretch'] = L.r(math.sqrt(float((fm['L2'][m & ok] ** 2 * A3[m & ok]).sum() / max(A3[m & ok].sum(), 1e-30))) * fm['k'], 4) if (m & ok).any() else None
        st['islands'] = int(len(set(lab[m])))
        per_part[pn] = st
    rel = np.log2(np.where(ok, fm['area_ratio'], np.nan))
    floor = {'median_tu': L.r(L.wquantile(dens_u, np.where(ok | fm['collapsed'], A3, 0), [0.5])[0], 1),
             'collapsed_share': L.r(float(A3[(dens_u < 1)].sum() / tot3), 5)}
    if a.floor_tu:
        floor.update(floor_tu=a.floor_tu, share_below_floor=L.r(float(A3[(dens_u < a.floor_tu)].sum() / tot3), 5))

    # ---- bone regions (the reference unit benchmark's head-priority estimator)
    doms = L.tri_dominant_bones(np.vstack(Fdoms), vw_all)
    regions = [L.bone_region(b, region_rules) for b in doms]
    rd = L.region_densities(P, F, UV, page, regions, mpu)
    vmask = vis.max(0) > 0
    rd_vis = L.region_densities(P, F[vmask], UV[vmask], page, np.array(regions)[vmask], mpu) if vmask.any() else {}
    bone_regions = {'rule': 'region of the dominant bone per triangle (sum of corner weights), first matching name '
                            'rule; density = page * sqrt(sum UV area / sum 3D area) over the region',
                    'rules': region_rules or L.DEFAULT_REGION_RULES,
                    'regions': {k: {kk: L.r(vv, 4) for kk, vv in v.items()} for k, v in rd.items()},
                    'head_torso': L.r(L.region_ratio(rd, 'head', 'torso'), 4),
                    'hands_torso': L.r(L.region_ratio(rd, 'hands', 'torso'), 4),
                    'head_torso_visible': L.r(L.region_ratio(rd_vis, 'head', 'torso'), 4),
                    'visible_note': 'the same estimator over faces visible in at least one heading (hidden faces that '
                                    'were shrunk on purpose, e.g. a scalp under a helmet, left out)',
                    'weighted_triangles': int(sum(1 for b in doms if b is not None))}

    # ---- seams
    proj = np.zeros((len(dirs), len(seams)))
    for j, e in enumerate(seams):
        ev = Pe[e['v'][1]] - Pe[e['v'][0]]
        for h, d in enumerate(dirs):
            proj[h, j] = np.linalg.norm(ev - np.dot(ev, d) * d)
    seam_proj_mean = float((proj * seam_vis).sum(1).mean()) * mpu if len(seams) else 0.0
    seam_any = seam_vis.any(0) if len(seams) else np.zeros(0, bool)
    seam_frac = seam_vis.mean(0) if len(seams) else np.zeros(0)
    seam_parts = {}
    for j, e in enumerate(seams):
        k_ = '|'.join(sorted(set(parts[t] for t in e['faces'])))
        s = seam_parts.setdefault(k_, [0.0, 0.0])
        s[0] += seam_len[j] * mpu
        s[1] += seam_len[j] * seam_frac[j] * mpu
    sqrt_area = math.sqrt(tot3 * mpu * mpu) if tot3 > 0 else None

    # ---- orientation stats
    ow = np.array([x['orient_weight'] for x in isl]) if isl else np.zeros(0)
    oa = np.array([x['orient_deg'] if x['orient_deg'] is not None else 0.0 for x in isl]) if isl else np.zeros(0)
    defined = ow > 0
    cmean, cstd = L.circ_stats(oa[defined], ow[defined]) if defined.any() else (None, None)
    wsum = ow[defined].sum() if defined.any() else 0.0
    upright = float(ow[defined & (np.abs(oa) <= 15)].sum() / wsum) if wsum else None
    axis = float(ow[defined & (np.abs(((oa + 45) % 90) - 45) <= 15)].sum() / wsum) if wsum else None
    mean_abs = float((np.abs(oa[defined]) * ow[defined]).sum() / wsum) if wsum else None

    # ---- uv vertex splits (GPU vertex estimate, this layer)
    keyset = set()
    for t in range(T):
        for k in range(3):
            keyset.add((int(F[t, k]), round(float(UV[t, k, 0]), 6), round(float(UV[t, k, 1]), 6)))

    # ---- left/right symmetry of the texel density (mirror pairs across x = 0, rest pose)
    mc = cent * np.array([-1.0, 1.0, 1.0])
    sym = {'rule': 'faces whose rest centroid mirrored across x=0 lands within --mirror-tol of another face; '
                   '|log2| of their texel-density ratio, area-weighted', 'pairs': 0}
    if T <= 6000:
        D2 = ((mc[:, None, :] - cent[None, :, :]) ** 2).sum(-1)
        nn = D2.argmin(1)
        dn = np.sqrt(D2[np.arange(T), nn])
        mt = (dn < a.mirror_tol) & (nn != np.arange(T)) & ok & ok[nn]
        if mt.any():
            lr = np.abs(np.log2(dens_u[mt] / dens_u[nn[mt]]))
            sym.update(pairs=int(mt.sum()), matched_area_share=L.r(float(A3[mt].sum() / tot3), 4),
                       density_log2_asym_mean=L.r(L.wmean(lr, A3[mt]), 4),
                       density_log2_asym_p90=L.r(L.wquantile(lr, A3[mt], [0.9])[0], 4),
                       pairs_over_25pct=int((lr > math.log2(1.25)).sum()))
    else:
        sym['note'] = 'skipped above 6000 triangles'

    fl = fm['flipped']
    mixed = 0
    for i in range(n_isl):
        m = lab == i
        nf = int(fl[m].sum())
        if 0 < nf < m.sum():
            mixed += min(nf, int(m.sum()) - nf)

    metrics = {
        'tool': TOOL_VERSION,
        'label': a.label,
        'blender': bpy.app.version_string,
        'blend': bpy.data.filepath, 'blend_sha256': sha256(bpy.data.filepath),
        'objects': names, 'occluders': occ_names, 'uv_layer': a.uv_layer, 'page': page,
        'metres_per_unit': mpu,
        'units_note': 'model units -> metres by --metres-per-unit (t/m numbers assume 1 model unit = 1 m unless set)',
        'counts': {'triangles': T, 'polygons': int(sum(ex[n]['n_polys'] for n in names)), 'vertices': int(len(P)),
                   'uv_split_vertices': len(keyset),
                   'uv_split_ratio': L.r(len(keyset) / max(len(P), 1), 4),
                   'gpu_vertices_all_uv_layers': int(sum(ex[n]['gpu_all_layers'] for n in names)),
                   'gpu_note': 'distinct (vertex, UV of every layer in the file) keys: an exporter that writes every '
                               'layer ships this many; normal and material splits not counted',
                   'uv_layers': {n: ex[n]['uv_layers'] for n in names},
                   'per_object': {n: {'tris': int(len(ex[n]['F'])), 'part_source': ex[n]['part_src'],
                                      'gpu_vertices_all_uv_layers': ex[n]['gpu_all_layers']} for n in names}},
        'pose': pose_info,
        'camera': {'pitch_deg': a.pitch, 'headings': a.headings, 'projection': 'orthographic direction',
                   'forward': [round(float(x), 4) for x in fwd],
                   'culling': 'double-sided' if a.double_sided else 'single-sided (back faces culled, do not occlude)',
                   'heading0': 'camera on the forward side of the model'},
        'distortion': {
            'L2_stretch': L.r(Lg, 4), 'Linf_stretch': L.r(Linf, 4),
            'L2_note': 'Sander et al. 2001, page-normalised: 1.0 = uniformly scaled isometry; intended density '
                       'priorities count as stretch here (see islands.list[].L2_stretch_island)',
            'faces_L2_gt_1_5_share': L.r(float(A3[ok & (fm['L2_n'] > 1.5)].sum() / tot3), 4),
            'angular_aniso_mean': L.r(L.wmean(fm['aniso'], np.where(ok, A3, 0)), 4),
            'angular_aniso_p90': L.r(L.wquantile(fm['aniso'], np.where(ok, A3, 0), [0.9])[0], 4),
            'angular_aniso_max': L.r(float(fm['aniso'][ok].max()) if ok.any() else None, 4),
            'angle_dev_mean_deg': L.r(L.wmean(fm['angdev'], np.where(ok, A3, 0)), 3),
            'angle_dev_p90_deg': L.r(L.wquantile(fm['angdev'], np.where(ok, A3, 0), [0.9])[0], 3),
            'area_log2_mean_abs': L.r(L.wmean(np.abs(rel), np.where(ok, A3, 0)), 4),
            'area_ratio_p10': L.r(L.wquantile(fm['area_ratio'], np.where(ok, A3, 0), [0.1])[0], 4),
            'area_ratio_p90': L.r(L.wquantile(fm['area_ratio'], np.where(ok, A3, 0), [0.9])[0], 4),
            'collapsed_faces': int(fm['collapsed'].sum()), 'degenerate_3d_faces': int(fm['degenerate3d'].sum()),
        },
        'texel_density': {
            'unit': 'texels per metre at the page size (= per model unit x 1/metres_per_unit)',
            'global_equivalent': L.r(page * math.sqrt(totuv / tot3) / mpu, 1) if tot3 else None,
            'global_note': 'page * sqrt(sum UV area / sum 3D area), overlaps counted twice',
            'all': dstats(all_m), 'visible_weighted': dstats(all_m, vis_mean),
            'per_part': per_part, 'density_floor_check': floor,
        },
        'bone_regions': bone_regions,
        'islands': {
            'count': n_isl, 'tiny_threshold_px2': tiny,
            'tiny_count': int((sizes < tiny).sum()),
            'size_px2_min': L.r(float(sizes.min()) if len(sizes) else None, 1),
            'size_px2_p10': L.r(float(np.percentile(sizes, 10)) if len(sizes) else None, 1),
            'size_px2_p50': L.r(float(np.percentile(sizes, 50)) if len(sizes) else None, 1),
            'size_px2_p90': L.r(float(np.percentile(sizes, 90)) if len(sizes) else None, 1),
            'size_px2_max': L.r(float(sizes.max()) if len(sizes) else None, 1),
            'per_m2': L.r(n_isl / (tot3 * mpu * mpu), 2) if tot3 else None,
            'list': isl,
        },
        'seams': {
            'seam_edges': len(seams), 'seam_length_m': L.r(float(seam_len.sum()) * mpu, 4),
            'visible_any_m': L.r(float(seam_len[seam_any].sum()) * mpu, 4),
            'visible_mean_m': L.r(float((seam_len * seam_frac).sum()) * mpu, 4),
            'surface_area_m2': L.r(tot3 * mpu * mpu, 5),
            'seam_per_sqrt_area': L.r(float(seam_len.sum()) * mpu / sqrt_area, 4) if sqrt_area else None,
            'visible_mean_per_sqrt_area': L.r(float((seam_len * seam_frac).sum()) * mpu / sqrt_area, 4)
            if sqrt_area else None,
            'per_sqrt_area_note': 'compare seam length between models per sqrt(surface area), never in metres',
            'visible_projected_mean_m': L.r(seam_proj_mean, 4),
            'visible_projected_note': 'visible seam length projected on the image plane of each heading (posed '
                                      'geometry, orthographic), mean over headings: what the eye can see',
            'visible_per_heading_m': [L.r(float(seam_len[seam_vis[h]].sum()) * mpu, 4) for h in range(len(dirs))],
            'visible_rule': 'a seam edge counts in a heading when both adjacent faces face the camera and a point on '
                            'the edge is unoccluded; visible_mean = length x share of headings',
            'by_part_pair_m': {k: [L.r(v[0], 4), L.r(v[1], 4)] for k, v in sorted(seam_parts.items(), key=lambda kv: -kv[1][1])},
            'mesh_border_edges': len(borders), 'mesh_border_length_m': L.r(float(border_len.sum()) * mpu, 4),
            'nonmanifold_edges': len(nonman),
        },
        'packing': {
            'coverage_texels': L.r(covered / (page * page), 4),
            'fill_sum_uv_area': L.r(totuv, 4),
            'uv_area_outside_page': L.r(totuv - inside, 6),
            'bbox': [L.r(x, 4) for x in bb],
            'pack_efficiency_bbox': L.r(covered / (page * page) / bb_area, 4) if bb_area else None,
            'gutter_px_required': a.gutter_px,
            'min_island_gap_px': L.r(min_gap, 3),
            'island_pairs_below_gutter': len(below),
            'pairs_below_gutter': [dict(a=g[0], b=g[1], gap_px=L.r(g[2], 3), at_px=g[3]) for g in below[:200]],
            'gutter_vanish_mip': vanish,
            'gutter_vanish_page_px': (page >> vanish) if vanish is not None else None,
            'pairs_bleeding_per_mip': bleed,
            'mip_rule': 'a pair bleeds at mip m when its mip-0 gap / 2^m < 1 texel; vanish mip = first mip where the '
                        'closest pair bleeds',
            'min_page_border_px': L.r(border_gap, 3),
        },
        'overlaps': {
            'mode': a.mirror_overlap,
            'pairs': len(ov_rows),
            'unintended_px2': L.r(ov_area['unintended'] * page * page, 2),
            'declared_mirror_px2': L.r(ov_area['declared_mirror'] * page * page, 2),
            'self_fold_px2': L.r(ov_area['self_fold'] * page * page, 2),
            'unintended_share_of_uv': L.r(ov_area['unintended'] / totuv, 5) if totuv else None,
            'texels_multi_island': int(multi.sum()), 'texels_multi_face': int((cnt > 1).sum()),
        },
        'flips': {'flipped_faces': int(fl.sum()), 'flipped_area_share': L.r(float(A3[fl].sum() / tot3), 5),
                  'mirrored_islands': int(sum(1 for x in isl if x['mirrored'])),
                  'minority_flipped_faces_in_mixed_islands': mixed},
        'orientation': {'rule': 'angle of 3D up (+Z, bind pose) in UV, degrees from +V, positive towards +U; island '
                                'weight = 3D area x in-plane share of up',
                        'mean_abs_deg': L.r(mean_abs, 2), 'circular_mean_deg': L.r(cmean, 2),
                        'circular_std_deg': L.r(cstd, 2), 'upright_share_15deg': L.r(upright, 4),
                        'axis_aligned_share_15deg': L.r(axis, 4),
                        'undefined_islands': int((~defined).sum())},
        'symmetry': sym,
        'visibility': {'faces_never_visible': int((~vis_any).sum()),
                       'area_never_visible_share': L.r(float(A3[~vis_any].sum() / tot3), 4),
                       'uv_area_on_never_visible_share': L.r(float(Auv[~vis_any].sum() / totuv), 4) if totuv else None,
                       'mean_visible_area_share': L.r(float((vis_mean * A3).sum() / tot3), 4)},
        'seconds': None,
    }

    # ---- renders
    renders = {}
    if not a.no_render:
        R = Renderer(a, out)
        Ux = np.vstack([ex[n]['UV'] for n in names])
        l2c = colormap_div(np.log2(np.clip(np.where(ok, fm['L2_n'], 4.0), 1e-6, None)), -1, 1)
        l2c[~ok] = (0.1, 0.1, 0.1)
        anc = colormap_seq(np.where(ok, fm['aniso'], 4.0), 1.0, 3.0)
        anc[~ok] = (0.1, 0.1, 0.1)
        rest_objs, posed_objs = [], []
        o0 = 0
        for n in names:
            nt = len(ex[n]['F'])
            sl = slice(o0, o0 + nt)
            rest_objs.append(R.add(n + '_rest', ex[n]['V'], ex[n]['F'], Ux[sl], l2c[sl]))
            posed_objs.append(R.add(n + '_posed', posed[n], ex[n]['F'], Ux[sl], l2c[sl]))
            rest_objs[-1]['sl'] = (o0, o0 + nt)
            posed_objs[-1]['sl'] = (o0, o0 + nt)
            o0 += nt
        extra = [R.add(n + '_occ', posed_occ[n], occ_ex[n]['F'], None, None, evaluated=False) for n in occ_names]
        frame_objs = posed_objs + list(extra)          # the game tiles frame the model, an extra occluder may crop
        if extra_occ is not None:
            extra.append(R.add('extra_occluder', extra_occ[0], extra_occ[1], None, None, evaluated=False))

        def recolor(objs, C):
            for o in objs:
                s0, s1 = o['sl']
                R.set_cols(o.data, C[s0:s1])
        for vn, d in VIEWS.items():
            R.frame(rest_objs, d)
            p = os.path.join(R.dir, 'checker_%s.png' % vn)
            R.shot(p, a.res, rest_objs, 'TEXTURE')
            renders['checker_%s' % vn] = p
            R.shot(os.path.join(R.dir, 'shade_%s.png' % vn), a.res, rest_objs, 'SINGLE', 'STUDIO', True)
            for kind, C in (('stretch', l2c), ('angle', anc)):
                recolor(rest_objs, C)
                R.shot(os.path.join(R.dir, '%s_%s_flat.png' % (kind, vn)), a.res, rest_objs, 'VERTEX', 'FLAT', True)
                renders['%s_%s' % (kind, vn)] = os.path.join(R.dir, '%s_%s.png' % (kind, vn))
        allg = posed_objs + extra
        recolor(posed_objs, l2c)
        for h, d in enumerate(dirs):
            hn = 'game_h%03d' % round(360 * h / len(dirs))
            R.frame(frame_objs, d, margin=1.15)
            p = os.path.join(R.dir, 'checker_%s.png' % hn)
            R.shot(p, a.game_res, allg, 'TEXTURE')
            renders['checker_%s' % hn] = p
            R.shot(os.path.join(R.dir, 'shade_%s.png' % hn), a.game_res, allg, 'SINGLE', 'STUDIO', True)
            R.shot(os.path.join(R.dir, 'stretch_%s_flat.png' % hn), a.game_res, allg, 'VERTEX', 'FLAT', True)
            renders['stretch_%s' % hn] = os.path.join(R.dir, 'stretch_%s.png' % hn)
    metrics['renders'] = renders
    metrics['seconds'] = round(time.time() - t0, 1)

    # ---- data for the host drawings
    np.savez_compressed(
        os.path.join(out, 'data.npz'), UV=UV, lab=lab, objid=objid, poly=poly_idx, objects=np.array(names),
        L2_n=np.where(ok, fm['L2_n'], np.nan),
        aniso=np.where(ok, fm['aniso'], np.nan), angdev=fm['angdev'], density=dens, area_ratio=fm['area_ratio'],
        flipped=fl, collapsed=fm['collapsed'], vis=vis, area3d=A3, regions=np.array(regions),
        seam_uv=np.array([[e['uvs'][0], e['uvs'][1]] for e in seams]).reshape(-1, 2, 2, 2) if seams else np.zeros((0, 2, 2, 2)),
        seam_vis_frac=seam_frac, seam_len=seam_len,
        outline=seg, outline_isl=sid, cover=cnt, multi=multi,
        gaps=np.array([[g[0], g[1], g[2]] + (g[3] or [np.nan, np.nan]) + (g[4] or [np.nan, np.nan]) for g in gap_rows])
        if gap_rows else np.zeros((0, 7)),
        overlaps=np.array([[o_[0], o_[1], o_[2], {'self_fold': 0, 'declared_mirror': 1, 'unintended': 2}[o_[3]]]
                           for o_ in ov_rows]) if ov_rows else np.zeros((0, 4)),
        parts=np.array(parts))
    with open(os.path.join(out, 'metrics.json'), 'w') as f:
        json.dump(metrics, f, indent=1)
    print('UVEVAL_OK %s islands=%d L2=%s Linf=%s seams=%.3f m (visible mean %.3f m) cover=%.3f min_gap=%s px %.1fs' % (
        a.label, n_isl, metrics['distortion']['L2_stretch'], metrics['distortion']['Linf_stretch'],
        float(seam_len.sum()) * mpu, float((seam_len * seam_frac).sum()) * mpu, covered / page / page,
        metrics['packing']['min_island_gap_px'], time.time() - t0))


if __name__ == '__main__':
    main()
