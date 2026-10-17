"""Shared reader for the aoe3de-unit-model measurement scripts (read-only).

Opens AoE3 DE .gr2 files with the consuming project's GR2 reader (`<consumer-root>/scripts/havok/gr2_read.py`,
found by walking up from this file or from AOE3_UNIT_CONSUMER_ROOT) and returns numpy arrays per mesh: every vertex
component, the triangle list, bone bindings, material bindings and groups, plus the skeleton with world rest matrices.
Vanilla inputs can be read straight from the game archive (`--archive Art/units/...gr2`): the file is extracted in
memory with aoe3de-bar-archives' bartool and written to a temporary folder outside every repository (`fetch` refuses
a target inside a git working tree, as bartool's extract command does).

Frames: gr2 data is the engine frame and engine units (y up). A converter GXO of a vanilla gr2 is the GXO frame at
engine/2.54: g = e @ A.T / 2.54 for points, W_g = A @ W_e @ A.T for rotations, faces reversed, V flipped (verified on
iron_rider_0 against the converter's dump, 2026-10-11: 1.6e-7). `to_gxo_*` implement it.
"""
from __future__ import annotations

import os
import sys
import tempfile
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
BARTOOL_DIR = HERE.parents[1] / 'aoe3de-bar-archives' / 'scripts'


def find_consumer_root():
    env = os.environ.get('AOE3_UNIT_CONSUMER_ROOT')
    if env and (Path(env) / 'scripts' / 'havok' / 'gr2_read.py').is_file():
        return Path(env)
    for p in [HERE] + list(HERE.parents):
        if (p / 'scripts' / 'havok' / 'gr2_read.py').is_file():
            return p
    raise SystemExit('consumer GR2 reader not found: set AOE3_UNIT_CONSUMER_ROOT to the folder holding '
                     'scripts/havok/gr2_read.py')


ROOT = find_consumer_root()
HAVOK = ROOT / 'scripts' / 'havok'
for _p in (str(HAVOK), str(ROOT / 'scripts' / 'tools')):
    if _p not in sys.path:
        sys.path.insert(0, _p)
from gr2_read import Gr2  # noqa: E402
from gr2_dump import refs  # noqa: E402

TYPE_NP = {10: '<f4', 11: 'i1', 12: 'u1', 13: 'i1', 14: 'u1', 15: '<i2', 16: '<u2', 17: '<i2', 18: '<u2',
           19: '<i4', 20: '<u4', 21: '<f2'}
TYPE_NAME = {10: 'real32', 11: 'int8', 12: 'uint8', 13: 'binormal_int8', 14: 'normal_uint8', 15: 'int16',
             16: 'uint16', 17: 'binormal_int16', 18: 'normal_uint16', 19: 'int32', 20: 'uint32', 21: 'real16'}
A = np.array([[-1.0, 0, 0], [0, 0, -1.0], [0, 1.0, 0]])     # engine row vector e = g @ A (GXO frame -> engine)
GXO_PER_ENGINE = 1 / 2.54                                    # a converter GXO of a vanilla gr2


class Unreadable(Exception):
    pass


def nm(name):
    """bone name for matching: a space equals an underscore, case-insensitive (the engine's rule)."""
    return name.replace('_', ' ').lower()


def region(bone):
    n = bone.lower()
    if n.startswith('bone_') or 'attach' in n or 'prop' in n:
        return 'weapon'                              # flail chain (bone_handle is not a hand), attach and prop bones
    if 'head' in n or 'neck' in n or 'ponytail' in n:
        return 'head'
    if 'hand' in n or 'finger' in n:
        return 'hands'
    if 'arm' in n or 'clavicle' in n:
        return 'arms'
    if 'spine' in n or 'pelvis' in n:
        return 'torso'
    if 'foot' in n or 'toe' in n:
        return 'feet'
    if 'thigh' in n or 'calf' in n:
        return 'legs'
    return 'other'


def legs_region(r):
    """the coarse grouping of the triangle-share tables: feet count as legs."""
    return 'legs' if r == 'feet' else r


class Mesh:
    def __init__(self, g, rec):
        self.name = rec['Name']
        vd = rec['PrimaryVertexData']
        vrec = g.read(*vd[2], *vd[1])
        _, tp, n, dp = vrec['Vertices']
        lay, stride = g.layout(*tp)
        self.n, self.stride = int(n), stride
        self.layout = [(m['name'], TYPE_NAME.get(m['type'], m['type']), max(m['count'], 1), off) for m, off in lay]
        self.comps = {}
        for m, off in lay:
            t, c = m['type'], max(m['count'], 1)
            if t in TYPE_NP and n:
                dt = np.dtype(TYPE_NP[t])
                self.comps[m['name']] = np.ndarray((n, c), dt, g.payload[dp[0]], dp[1] + off,
                                                   (stride, dt.itemsize)).copy()
        top = g.read(*rec['PrimaryTopology'][2], *rec['PrimaryTopology'][1])
        if top['Indices'][1]:
            (s, o), k, dt = top['Indices'][2], top['Indices'][1], '<i4'
        else:
            (s, o), k, dt = top['Indices16'][2], top['Indices16'][1], '<u2'
        self.tris = np.frombuffer(bytes(g.payload[s][o:o + k * np.dtype(dt).itemsize]), dt).astype(np.int64)
        self.tris = self.tris[:len(self.tris) // 3 * 3].reshape(-1, 3)
        self.groups = [(x['MaterialIndex'][0], x['TriFirst'][0], x['TriCount'][0]) for x in g.array(top['Groups'])] \
            if top.get('Groups') and top['Groups'][0] == 'array' else []
        self.materials = []
        if rec.get('MaterialBindings') and rec['MaterialBindings'][0] == 'array':
            for x in g.array(rec['MaterialBindings']):
                ref = x['Material']
                self.materials.append(g.read(*ref[2], *ref[1])['Name'] if ref and ref[1] else None)
        self.bones = [x['BoneName'] for x in g.array(rec['BoneBindings'])] \
            if rec.get('BoneBindings') and rec['BoneBindings'][0] == 'array' else []

    @property
    def pos(self):
        return self.comps['Position'].astype(np.float64)

    @property
    def skinned(self):
        return 'BoneWeights' in self.comps and 'BoneIndices' in self.comps

    def influences(self):
        """nonzero weights per vertex (1 for a rigid or index-only mesh)."""
        if self.skinned:
            return (self.comps['BoneWeights'] > 0).sum(1)
        return np.ones(self.n, int)

    def weighted_bones(self):
        if self.skinned:
            w, bi = self.comps['BoneWeights'], self.comps['BoneIndices'].astype(np.int64)
            used = sorted({int(x) for x in bi[w > 0]})
        elif 'BoneIndices' in self.comps:
            used = sorted({int(x) for x in self.comps['BoneIndices'][:, 0]})
        else:
            used = [0] if self.bones else []
        return [self.bones[i] for i in used if i < len(self.bones)]

    def vertex_weights(self):
        """per GPU vertex {bone name: weight}, weights normalized to sum 1."""
        out = []
        if self.skinned:
            W = self.comps['BoneWeights'].astype(np.float64)
            B = self.comps['BoneIndices'].astype(np.int64)
            for w, b in zip(W, B):
                tot = w.sum() or 1.0
                d = {}
                for x, i in zip(w, b):
                    if x > 0:
                        d[self.bones[i]] = d.get(self.bones[i], 0.0) + x / tot
                out.append(d)
        else:
            bone = self.bones[int(self.comps['BoneIndices'][0, 0])] if 'BoneIndices' in self.comps and self.n \
                else (self.bones[0] if self.bones else None)
            out = [{bone: 1.0} if bone else {} for _ in range(self.n)]
        return out

    def welded_count(self, decimals=5):
        """distinct (position rounded, every other component except Tangent): what a clean export ships."""
        if not self.n:
            return 0
        cols = [np.round(self.pos, decimals)]
        cols += [v.astype(np.float64) for k, v in self.comps.items() if k not in ('Position', 'Tangent')]
        return int(len(np.unique(np.hstack(cols), axis=0)))

    def unique_positions(self, decimals=5):
        return int(len(np.unique(np.round(self.pos, decimals), axis=0))) if self.n else 0


class Model:
    def __init__(self, path):
        self.path = Path(path)
        self.name = self.path.stem
        try:
            self.g = g = Gr2(str(path))
        except NotImplementedError as e:
            raise Unreadable('%s: %s' % (self.path.name, e))
        self.crc_ok = g.crc_check()
        r = g.root()
        self.root_materials = [m['Name'] for m, _ in refs(g, r.get('Materials'))]
        self.textures = [t for t, _ in refs(g, r.get('Textures'))]
        self.meshes = [Mesh(g, m) for m, _ in refs(g, r.get('Meshes'))]
        self.skeletons = []
        for sk, _ in refs(g, r.get('Skeletons')):
            bones = []
            for b in g.array(sk['Bones']):
                iw = np.array(b['InverseWorldTransform'][:16], float).reshape(4, 4)
                lod = b.get('LODError')
                bones.append(dict(name=b['Name'], parent=b['ParentIndex'][0], world=np.linalg.inv(iw),
                                  lod=lod[0] if isinstance(lod, tuple) else lod))
            self.skeletons.append(dict(name=sk['Name'], bones=bones))

    @property
    def skeleton(self):
        return self.skeletons[0]['bones'] if self.skeletons else []

    def joints(self):
        """{nm(bone): world rest position (engine)}"""
        return {nm(b['name']): b['world'][3, :3] for b in self.skeleton}


def to_gxo_point(p, units=GXO_PER_ENGINE):
    return np.asarray(p, float) @ A.T * units


def to_gxo_matrix(W, units=GXO_PER_ENGINE):
    """engine row-vector rest/world 4x4 -> GXO frame 4x4 (rotation conjugated, translation mapped and scaled)."""
    out = np.eye(4)
    out[:3, :3] = A @ W[:3, :3] @ A.T
    out[3, :3] = W[3, :3] @ A.T * units
    return out


def load(path):
    return Model(path)


# ---------------------------------------------------------------- archive input

def _bartool():
    sys.path.insert(0, str(BARTOOL_DIR))
    try:
        import bartool
    finally:
        sys.path.remove(str(BARTOOL_DIR))
    return bartool


def refuse_repo_target(path, why='vanilla archive copies'):
    """SystemExit when `path` lies inside a git working tree (bartool's own check, which its extract command enforces
    unless --in-repo) or inside the consumer root: these scripts never write vanilla-derived files into a repository."""
    p = Path(path).resolve()
    root = _bartool().git_root(str(p))
    consumer = ROOT.resolve()
    if root or p == consumer or consumer in p.parents:
        raise SystemExit('refusing to write into a git working tree (%s): %s (%s); use a temp or scratch folder'
                         % (root or consumer, p, why))


def game_index():
    bartool = _bartool()
    try:
        game = bartool.find_game_dir()
    except SystemExit as e:
        raise FileNotFoundError(str(e))
    return bartool, bartool.build_index(game)


def game_available():
    try:
        game_index()
        return True
    except (FileNotFoundError, ImportError):
        return False


def temp_dir(name='inputs'):
    d = Path(tempfile.gettempdir()) / 'aoe3de-unit-model' / name
    d.mkdir(parents=True, exist_ok=True)
    return d


def fetch(rel_paths, out_dir=None, index=None):
    """archive paths (relative to the game folder, `Art/units/...`) -> local copies under out_dir (default: a temp
    folder). Read-only on the archive; a folder inside a git working tree is refused before anything is read."""
    out_dir = Path(out_dir) if out_dir else temp_dir()
    refuse_repo_target(out_dir)
    bartool, idx = index or game_index()
    out = []
    for rel in rel_paths:
        key = rel.replace(chr(92), '/').lower().lstrip('/')
        e = idx.get(key) or idx.get('art/' + key)
        if e is None:
            raise FileNotFoundError('not in the game archives: %s' % rel)
        p = out_dir / e.name.replace(chr(92), '/')
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_bytes(bartool.read_entry(e))
        out.append(p)
    return out


def add_input_args(ap):
    ap.add_argument('files', nargs='*', help='gr2 files on disk')
    ap.add_argument('--archive', nargs='*', default=[], metavar='REL',
                    help='archive paths read from the game install, e.g. Art/units/cavalry/dragoon/dragoon_age3.gr2')
    ap.add_argument('--extract-to', help='folder for archive copies (default: a temp folder; a repository is refused)')


def resolve_inputs(a):
    paths = [Path(p) for p in a.files]
    if a.archive:
        paths += fetch(a.archive, a.extract_to)
    if not paths:
        raise SystemExit('no input: pass gr2 files or --archive paths')
    return paths


def models(paths):
    """yield (path, Model or None, reason) without stopping on an unreadable (Oodle-compressed) file."""
    for p in paths:
        try:
            yield p, Model(p), None
        except Unreadable as e:
            yield p, None, str(e)
