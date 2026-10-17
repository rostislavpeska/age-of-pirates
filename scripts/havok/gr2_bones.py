"""In-place skeleton edits of an uncompressed .gr2 - pivot canonization: rest transforms and inverse-world matrices of
bones are rewritten in their 164-byte records, nothing else moves (vertices, meshes, relocations, file size); CRC
recomputed. Meshes keep their model-space vertices, so a bone moved WITHOUT its vertices changes what its meshes look
like at rest - move the vertices with gr2_rotate_verts by the same transform (and refresh the boxes: gr2_bounds.py).

Why (Korean HC docks01, 2026-10-17, owner: "dock has broken pivot", "for complex scenes pivot canonization should be the
first step"): the owner moved the pier and a junk boat in Blender at OBJECT level; the export moved their vertices
~25 m but left their pivot bones at the vanilla spot, and docks01 is the one homecity model whose root bone is not
identity (BONE_MAIN at (2.98, 0.52, -6.28), turned 10.8 degrees; 23 other homecity/building models: identity). In game
the pier and that boat came out displaced while the boat edited at mesh level was right.

    python gr2_bones.py in.gr2 plan.json out.gr2
    plan.json: {"canonize_root": true,                                   # root rest -> identity, every child keeps its world
                "move": [{"bones": ["bone_hc_wokou_junk"], "matrix": [[3x3]], "translate": [x, y, z]}, ...]}
    "move": each listed bone's rest WORLD transform W becomes T . W (T = matrix (proper rotation, default identity) then
    translate, model space); its descendants follow (their local transforms are kept). Listed bones must not be each
    other's descendants. Applied after canonize_root.

Convention (self-checked before writing: the stored InverseWorldTransform of every bone must equal the one recomputed
from the rest locals to 1e-4, else the edit is refused): local = translate(position) . R(quaternion) . ScaleShear as
column-vector matrices (vanilla docks01: 1.3e-5; the ScaleShear . R order is 2.55 off - that order belongs to the
converter's GXO TEXT keys, gr2_rest_anim.py, not to the file); InverseWorld stored = inverse of the column-vector world,
transposed (gr2-granny-edit). A rewritten bone keeps its own ScaleShear; a local that is not rotation . ScaleShear (a
non-uniformly scaled parent) is refused. fencewalls01 and china_hc_water fit neither order (IW not the rest bind): refused.
"""
import json, struct, sys, zlib
from pathlib import Path
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gr2_read import Gr2   # noqa: E402
from gr2_dump import refs  # noqa: E402

BONE = 164


def qmat(x, y, z, w):
    return np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                     [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                     [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])


def mquat(R):
    """proper rotation matrix -> unit quaternion (x, y, z, w), w >= 0"""
    t = np.trace(R)
    if t > 0:
        s = 2 * np.sqrt(t + 1); w = s / 4; x = (R[2, 1] - R[1, 2]) / s; y = (R[0, 2] - R[2, 0]) / s; z = (R[1, 0] - R[0, 1]) / s
    else:
        i = int(np.argmax(np.diag(R))); j, k = (i + 1) % 3, (i + 2) % 3
        s = 2 * np.sqrt(1 + R[i, i] - R[j, j] - R[k, k]); q = np.zeros(4)
        q[i] = s / 4; q[j] = (R[j, i] + R[i, j]) / s; q[k] = (R[k, i] + R[i, k]) / s; q[3] = (R[k, j] - R[j, k]) / s
        x, y, z, w = q
    q = np.array([x, y, z, w]); q /= np.linalg.norm(q)
    return q if q[3] >= 0 else -q


def local4(t):
    """column-vector local matrix of a Transform tuple (flags, pos3, quat4, scaleshear9), Granny's flags applied"""
    f = int(t[0]); M = np.eye(4)
    R = qmat(*t[4:8]) if f & 2 else np.eye(3); S = np.array(t[8:17]).reshape(3, 3) if f & 4 else np.eye(3)
    M[:3, :3] = R @ S; M[:3, 3] = t[1:4] if f & 1 else 0
    return M


def worlds(bones, locals_):
    W = []
    for b, L in zip(bones, locals_):
        p = b['ParentIndex'][0] if isinstance(b['ParentIndex'], tuple) else b['ParentIndex']
        W.append(W[p] @ L if p >= 0 else L)
    return W


def edit(src, plan, out):
    g = Gr2(str(src)); assert g.crc_check() and all(s['compression'] == 0 for s in g.sections if s['data_size'])
    d = bytearray(g.data); fo = lambda sec, off: g.sections[sec]['data_off'] + off     # noqa: E731
    sk = refs(g, g.root()['Skeletons'])[0][0]; arr = sk['Bones']; assert g.struct_size(*arr[3]) == BONE
    bones = g.array(arr); base = fo(*arr[2]); n = len(bones)
    parent = [b['ParentIndex'][0] for b in bones]; names = [b['Name'] for b in bones]
    T = [list(b['Transform']) for b in bones]
    W = worlds(bones, [local4(t) for t in T])
    iw_stored = [np.array(b['InverseWorldTransform'], float).reshape(4, 4) for b in bones]
    err = max(float(np.abs(np.linalg.inv(Wb).T - iw).max()) for Wb, iw in zip(W, iw_stored))
    assert err < 1e-4, f'stored inverse-world matrices do not follow the convention (max error {err:.2e}): refused'
    newW = [w.copy() for w in W]
    rep = dict(convention_error=err)
    root = None
    if plan.get('canonize_root'):
        roots = [i for i in range(n) if parent[i] < 0]; assert len(roots) == 1, f'{len(roots)} roots'
        root = roots[0]; rep['root'] = names[root]; newW[root] = np.eye(4)            # every other world unchanged
    for op in plan.get('move', []):
        Rm = np.asarray(op.get('matrix', np.eye(3)), float)
        assert np.abs(Rm @ Rm.T - np.eye(3)).max() < 1e-5 and np.linalg.det(Rm) > 0, 'matrix: a rotation'
        M = np.eye(4); M[:3, :3] = Rm; M[:3, 3] = op.get('translate', [0, 0, 0])
        for b in op['bones']:
            i = names.index(b)
            for j in [i] + [j for j in range(n) if _descends(j, i, parent)]:
                newW[j] = M @ newW[j]
        rep.setdefault('moved', []).extend(op['bones'])
    # every bone: local = inv(new parent world) . new world; rewritten only where it changed
    touched = set()
    for i in range(n):
        if i == root:
            T[i] = [0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 1, 0, 0, 0, 1]; touched.add(i); continue
        L = newW[i] if parent[i] < 0 else np.linalg.inv(newW[parent[i]]) @ newW[i]
        if np.abs(L - local4(T[i])).max() > 1e-7:
            T[i] = _transform(L, T[i]); touched.add(i)
    touched |= {i for i in range(n) if np.abs(newW[i] - W[i]).max() > 1e-9}      # their inverse-world changes
    Wf = worlds(bones, [local4(t) for t in T])
    for i in sorted(touched):                                                # untouched records stay byte-identical
        assert np.abs(Wf[i] - newW[i]).max() < 1e-4, f'{names[i]}: rebuilt world off by {np.abs(Wf[i] - newW[i]).max():.2e}'
        o = base + i * BONE
        struct.pack_into('<i3f4f9f', d, o + 12, *[int(T[i][0])] + [float(x) for x in T[i][1:]])
        struct.pack_into('<16f', d, o + 80, *np.linalg.inv(Wf[i]).T.reshape(-1))
    rep['rewritten'] = [names[i] for i in sorted(touched)]
    struct.pack_into('<I', d, 32 + 8, zlib.crc32(bytes(d[g.sec_table:])) & 0xffffffff)
    Path(out).write_bytes(d)
    rep['worlds'] = {names[i]: np.round(Wf[i][:3, 3], 4).tolist() for i in sorted(touched)}
    return rep


def _descends(j, i, parent):
    p = parent[j]
    while p >= 0:
        if p == i:
            return True
        p = parent[p]
    return False


def _transform(L, old):
    """column local matrix -> Transform tuple; the bone's ScaleShear is kept (L3 = R . ScaleShear)"""
    S = np.array(old[8:17]).reshape(3, 3) if int(old[0]) & 4 else np.eye(3)
    R = L[:3, :3] @ np.linalg.inv(S)
    assert np.abs(R @ R.T - np.eye(3)).max() < 1e-4, 'the new local is not rotation . ScaleShear'
    q = mquat(R); p = L[:3, 3]
    flags = (1 if np.abs(p).max() > 1e-9 else 0) | (2 if abs(q[3]) < 1 - 1e-12 else 0) | (int(old[0]) & 4)
    return [flags, *p.tolist(), *q.tolist(), *S.reshape(-1).tolist()]


if __name__ == '__main__':
    src, planp, out = sys.argv[1:4]
    print('BONES', json.dumps(edit(src, json.loads(Path(planp).read_text()), out), indent=1))
