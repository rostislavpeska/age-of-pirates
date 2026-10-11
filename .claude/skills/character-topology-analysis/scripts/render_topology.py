"""Topology pictures for character-topology-analysis (host Python, numpy + Pillow; no Blender).

Orthographic, flat-shaded faces drawn back to front with their edges, poles as dots (valence 3 blue, 5 red, 6+ magenta,
unexplained poles ringed black), limb rings as coloured polylines, eye rings light blue, mouth rings pink, mask loops
green, landmarks as crosses; faces coloured by region, by plane-map patch (--color plane) or plain. Pictures of
third-party reference models stay in the caller's work folder: this tool refuses to write inside a git work tree.

    python -I render_topology.py <mesh> [load and analysis options as toplib measure] --out PNG
        [--view front|back|left|right|34|top] [--zoom head|torso|arm_l|leg_l|hand_l|foot_l|shoulder_l|hip_l]
        [--color region|plain|plane] [--no-rings] [--skeleton-overlay] [--width 1400] [--title TEXT]
"""
import argparse
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import toplib as TL  # noqa: E402
import tl_features as FT  # noqa: E402

REGION_RGB = dict(head=(232, 196, 160), neck=(214, 170, 150), torso=(176, 198, 222), arms=(178, 214, 170),
                  hands=(236, 214, 120), legs=(196, 176, 220), feet=(230, 160, 140), part=(205, 205, 205),
                  other=(200, 200, 200))
POLE_RGB = {3: (30, 80, 230), 5: (220, 40, 30), 6: (200, 30, 200)}
RING_RGB = [(255, 140, 0), (0, 160, 140), (150, 60, 200), (20, 120, 230), (210, 40, 120), (90, 160, 20)]
PLANE_RGB = [(231, 138, 120), (120, 170, 222), (150, 204, 130), (240, 196, 110), (190, 150, 220), (110, 200, 200),
             (230, 160, 190), (180, 180, 120), (140, 150, 230), (220, 120, 160), (120, 190, 150), (200, 170, 140)]
VIEWS = dict(front=(0, -1, 0), back=(0, 1, 0), left=(1, 0, 0), right=(-1, 0, 0), top=(0, 0, 1))


def view_basis(view):
    if view == '34':
        d = np.array([0.6, -1.0, 0.15])
    else:
        d = np.array(VIEWS[view], float)
    d = d / np.linalg.norm(d)            # from the model toward the camera
    up = np.array([0, 0, 1.0]) if abs(d[2]) < 0.9 else np.array([0, 1.0, 0])
    x = np.cross(up, d)
    x /= np.linalg.norm(x)
    y = np.cross(d, x)
    return d, x, y


def font(sz):
    for n in ('segoeui.ttf', 'arial.ttf', 'DejaVuSans.ttf'):
        try:
            return ImageFont.truetype(n, sz)
        except OSError:
            pass
    return ImageFont.load_default()


def render(rep, out, view='front', zoom=None, color='region', rings=True, face_rings=False, width=1400, title=None,
           mark_unexplained=True, highlight=None, skeleton=False):
    ctx = rep['_ctx']
    V, topo = ctx['V'], ctx['topo']
    sk = ctx['skel']
    d, ax, ay = view_basis(view)
    used = topo.used_vertices()
    sel_v = np.zeros(len(V), bool)
    sel_v[used] = True
    if zoom:
        sel_v = zoom_mask(ctx, zoom) & sel_v
    P = V[sel_v] if sel_v.any() else V[used]
    X, Y = V @ ax, V @ ay
    xs, ys = P @ ax, P @ ay
    pad = 0.06 * max(np.ptp(xs), np.ptp(ys), 1e-9)
    x0, x1, y0, y1 = xs.min() - pad, xs.max() + pad, ys.min() - pad, ys.max() + pad
    sc = (width - 40) / max(x1 - x0, 1e-12)
    hgt = int((y1 - y0) * sc) + 40
    hgt = max(200, min(hgt, 3 * width))
    img = Image.new('RGB', (width, hgt + 60), (250, 250, 247))
    dr = ImageDraw.Draw(img)

    def px(i):
        return (20 + (X[i] - x0) * sc, 60 + hgt - 20 - (Y[i] - y0) * sc)
    N, _ = TL.face_normals_areas(V, topo.faces)
    C = TL.face_centroids(V, topo.faces)
    depth = C @ d
    light = np.array([0.3, -0.8, 0.6])
    light /= np.linalg.norm(light)
    freg = sk['freg']
    fsel = [f for f in range(topo.nF) if all(sel_v[v] for v in topo.faces[f])] if zoom else list(range(topo.nF))
    fsel = [f for f in fsel if N[f] @ d > 0]
    fsel.sort(key=lambda f: depth[f])
    ids = Image.new('I', img.size, 0)
    di = ImageDraw.Draw(ids)
    patch = ctx.get('plane_patch') or {}
    for f in fsel:
        if color == 'plane' and f in patch:
            base = PLANE_RGB[patch[f] % len(PLANE_RGB)]
        elif color in ('region', 'plane'):
            base = REGION_RGB.get(freg[f], (205, 205, 205))
        else:
            base = (210, 210, 205)
        sh = 0.55 + 0.45 * max(0.0, float(N[f] @ light))
        col = tuple(int(c * sh) for c in base)
        poly = [px(v) for v in topo.faces[f]]
        dr.polygon(poly, fill=col, outline=(70, 70, 75))
        di.polygon(poly, fill=int(f) + 1)
    # a vertex is visible when the id buffer around its pixel shows one of its own faces (occlusion test)
    idb = np.array(ids, dtype=np.int64)
    vis = np.zeros(len(V), bool)
    cand = set()
    for f in fsel:
        cand.update(topo.faces[f])
    for v in cand:
        x, y = px(v)
        xi, yi = int(round(x)), int(round(y))
        win = idb[max(yi - 2, 0):yi + 3, max(xi - 2, 0):xi + 3].ravel() - 1
        own = set(int(f) for f in topo.vertex_faces(v))
        if own & set(win.tolist()):
            vis[v] = True
    if rings:
        rl = ctx.get('rings', [])
        for k, g in enumerate(rl):
            vs = ctx['loops'][g['loop']]['verts']
            if not vis[vs].mean() > 0.3:
                continue
            col = RING_RGB[k % len(RING_RGB)]
            cyc = list(vs) + [vs[0]]
            for a_, b_ in zip(cyc[:-1], cyc[1:]):
                if vis[a_] and vis[b_]:
                    dr.line([px(a_), px(b_)], fill=col, width=3)
        fc = ctx.get('face')
        if fc and fc.get('_face_loops'):
            fcol = dict(eye_l=(0, 170, 255), eye_r=(0, 170, 255), mouth=(255, 60, 160), mask=(120, 200, 0))
            for key, lst in fc['_face_loops'].items():
                for vs in lst:
                    cyc = list(vs) + [vs[0]]
                    for a_, b_ in zip(cyc[:-1], cyc[1:]):
                        if vis[a_] and vis[b_]:
                            dr.line([px(a_), px(b_)], fill=fcol[key], width=2)
        if fc and fc.get('_landmarks'):
            lm = fc['_landmarks']
            for c in [lm['eyes'][0], lm['eyes'][1], lm['mouth'], lm['nose']]:
                if c is None:
                    continue
                p = (20 + (c @ ax - x0) * sc, 60 + hgt - 20 - (c @ ay - y0) * sc)
                dr.line([(p[0] - 7, p[1]), (p[0] + 7, p[1])], fill=(0, 0, 0), width=2)
                dr.line([(p[0], p[1] - 7), (p[0], p[1] + 7)], fill=(0, 0, 0), width=2)
    if highlight:
        for vs, col in highlight:
            pts = [px(v) for v in vs]
            if len(pts) > 1:
                dr.line(pts, fill=col, width=4)
    if skeleton and sk.get('segs'):
        def pp(c):
            return (20 + (c @ ax - x0) * sc, 60 + hgt - 20 - (c @ ay - y0) * sc)
        for s in sk['segs']:
            dr.line([pp(s['A']), pp(s['B'])], fill=(40, 40, 40), width=2)
        for k, c in sk['J'].items():
            q = pp(np.asarray(c))
            dr.rectangle((q[0] - 3, q[1] - 3, q[0] + 3, q[1] + 3), fill=(255, 255, 255), outline=(0, 0, 0))
    rad = max(3, int(width / 300))
    zones = ctx.get('pole_zone', {})
    bad = set(FT.BAD_ZONES)
    for v in np.where(ctx['poles'] & vis)[0]:
        k = min(int(topo.valence[v]), 6)
        col = POLE_RGB.get(k, (200, 30, 200))
        x, y = px(v)
        rr = rad + (2 if k >= 6 else 0)
        dr.ellipse((x - rr, y - rr, x + rr, y + rr), fill=col)
        if mark_unexplained and zones.get(int(v)) in bad:
            dr.ellipse((x - rr - 3, y - rr - 3, x + rr + 3, y + rr + 3), outline=(0, 0, 0), width=2)
    f1, f2 = font(22), font(15)
    dr.text((20, 8), title or str(rep.get('source', {}).get('path', '')), fill=(20, 20, 20), font=f1)
    fk, pc = rep['face_kinds'], rep['poles']
    dr.text((20, 36), '%s view%s | %d faces (%d quads, %d tris, %d n-gons) | poles 3:%d 5:%d 6+:%d | rings %d' % (
        view, (' / ' + zoom) if zoom else '', fk['faces'], fk['quads'], fk['tris'], fk['ngons'], pc['v3'], pc['v5'],
        pc['v6plus'], len(ctx.get('rings', []))), fill=(60, 60, 60), font=f2)
    refusal = None
    try:
        import blender_env as BE  # noqa: F401
        refusal = BE.refuse_in_worktree(out, 'picture')
    except Exception:
        refusal = None
    if refusal:
        raise SystemExit(refusal)
    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
    img.save(out)
    return out


def zoom_mask(ctx, zoom):
    V, sk = ctx['V'], ctx['skel']
    vreg, vseg = sk['vreg'], sk['vseg']
    names = [s['name'] for s in sk['segs']]
    if zoom == 'head':
        m = (vreg == 'head') | (vreg == 'neck')
        if not m.any():
            m = np.ones(len(V), bool)
        return m
    if zoom == 'torso':
        return np.isin(vreg, ['torso', 'neck'])
    side = zoom[-1]
    base = zoom[:-2]
    groups = dict(arm=['upperarm', 'forearm'], leg=['thigh', 'calf'], hand=['hand'], foot=['foot'],
                  shoulder=['clavicle', 'upperarm'], hip=['pelvis', 'thigh'])
    ks = [i for i, n in enumerate(names) if n.rsplit('_', 1)[0] in groups.get(base, []) and n.endswith('_' + side)]
    m = np.isin(vseg, ks)
    if base in ('shoulder', 'hip'):
        j = sk['jf'].get(('shoulder_' if base == 'shoulder' else 'hip_') + side)
        if j is not None:
            L = max(j['L_parent'], j['L_child'])
            m = np.linalg.norm(V - j['pivot'], axis=1) <= 0.75 * L
    return m


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    TL.add_analysis_args(ap)
    ap.add_argument('--out', required=True)
    ap.add_argument('--view', default='front', choices=['front', 'back', 'left', 'right', '34', 'top'])
    ap.add_argument('--zoom')
    ap.add_argument('--color', default='region', choices=['region', 'plain', 'plane'])
    ap.add_argument('--no-rings', action='store_true')
    ap.add_argument('--skeleton-overlay', action='store_true', help='draw the joints and segments used')
    ap.add_argument('--width', type=int, default=1400)
    ap.add_argument('--title')
    a = ap.parse_args(argv)
    _, rep = TL.analyse_from_args(a)
    print('RENDER', render(rep, a.out, a.view, a.zoom, a.color, not a.no_rings, width=a.width, title=a.title,
                           skeleton=a.skeleton_overlay))
    return 0


if __name__ == '__main__':
    sys.exit(main())
