"""A synthetic mounted unit for the bundle and parity tests (no game bytes, CI-safe): a horse, its rider seated on the
horse's attach point with syncanims=1, a rigid torch attached to the rider's hand in one anim with syncanims=0, their
clips, a .material with a materialdef and BC1 textures - all written into one mod folder of a fake AoE3 profile.

    u = av_unit_fixture.write_unit(tmp_path)          # {'profile', 'mod', 'horse', 'rider', 'torch', ...}
    fs = av_unit_fixture.vfs(u)                       # vfs.VFS over that mod only (no game layer)
    res = bundle.build_bundle(animfile=u['horse'], fs=fs, out_root=tmp_path / 'bundles', lighting=False)

Names exercise the engine rules: the rider clip names 'Bip01 Pelvis' with a space (bone Bip01_Pelvis), the horse clip
names 'bone attachpoint' (bone bone_attachpoint), the animfile seats the rider on tobone="ATTACHPOINT" (the engine
alias) from frombone="hotspot" (in no model: engine-defined, model origin assumed), the torch on tobone="R HAND".
The horse spine carries a keyed scale-shear stretch (as vanilla horse tracks do) and one horse bone has transform
flags 3 with stored scale-shear numbers off the identity (flags applied: identity).
"""
from __future__ import annotations

import struct
import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE.parent / 'scripts'))
import av_fixtures as F  # noqa: E402
import gr2_synth as S  # noqa: E402

BS = chr(92)
UNIT = 'units/test/rider_unit/'
HORSE_ANIMFILE = UNIT + 'horse.xml'
RIDER_ANIMFILE = UNIT + 'rider.xml'
TORCH_ANIMFILE = 'effects/test/torch.xml'
HORSE_MODEL = UNIT + 'horse_0.gr2'
RIDER_MODEL = UNIT + 'rider_0.gr2'
TORCH_MODEL = 'effects/test/torch.gr2'
CLIPS = {'horse_idle': 'animation_library/test/horse_idle.gr2', 'horse_attack': 'animation_library/test/horse_attack.gr2',
         'rider_idle': 'animation_library/test/rider_idle.gr2', 'rider_attack': 'animation_library/test/rider_attack.gr2',
         'rider_idle_b': 'animation_library/test/rider_idle_b.gr2'}

SKINNED = [('Position', 'real32', 3), ('Normal', 'binormal_int8', 4), ('TextureCoordinates0', 'real32', 2),
           ('BoneWeights', 'normal_uint8', 4), ('BoneIndices', 'uint8', 4)]
STATIC = [('Position', 'real32', 3), ('Normal', 'binormal_int8', 3), ('TextureCoordinates0', 'real16', 2)]


def bslash(p):
    return p.replace('/', BS)


def horse_bones():
    return [
        {'name': 'horse_root', 'parent': -1, 'transform': S.transform((0, 0, 0), S.axis_quat((0, 1, 0), 10))},
        {'name': 'horse_spine', 'parent': 0,
         'transform': S.transform((0.0, 1.2, 0.1), S.axis_quat((1, 0, 0), -12), (1.0004, 0, 0, 0, 1, 0, 0, 0, 0.9996),
                                  flags=3)},
        {'name': 'horse_neck', 'parent': 1, 'transform': S.transform((0.0, 0.3, 0.9), S.axis_quat((1, 0, 0), 25))},
        {'name': 'bone_attachpoint', 'parent': 1,
         'transform': S.transform((0.0, 0.45, -0.05), S.axis_quat((0, 0, 1), 4))},
    ]


def rider_bones():
    return [
        {'name': 'Bip01_Root', 'parent': -1, 'transform': S.transform((0, 0, 0), S.axis_quat((0, 1, 0), 90), flags=2)},
        {'name': 'Bip01_Pelvis', 'parent': 0, 'transform': S.transform((0.0, 0.05, 0.0), S.axis_quat((1, 0, 0), -90))},
        {'name': 'Bip01_Spine', 'parent': 1,
         'transform': S.transform((0.1, 0, 0.01), S.axis_quat((0, 0, 1), 20), (1.05, 0.02, 0, 0, 0.97, 0, 0, 0.01, 1.0))},
        {'name': 'Bip01_R_Hand', 'parent': 2, 'transform': S.transform((0.35, -0.2, 0.15), S.axis_quat((0, 1, 0), -30))},
    ]


def torch_bones():
    return [{'name': 'torch_root', 'parent': -1, 'transform': S.transform((0, 0, 0))}]


def skinned(n, bone_names, seed, material='mata'):
    rng = np.random.default_rng(seed)
    nb = len(bone_names)
    cols = {'Position': rng.uniform(-0.5, 0.5, (n, 3)).astype(np.float32),
            'Normal': rng.integers(-127, 128, (n, 4)).astype(np.int8),
            'TextureCoordinates0': rng.uniform(0, 1, (n, 2)).astype(np.float32),
            'BoneWeights': np.tile(np.array([170, 85, 0, 0], np.uint8), (n, 1)),
            'BoneIndices': np.column_stack([np.arange(n) % nb, (np.arange(n) + 1) % nb, np.zeros(n), np.zeros(n)]
                                           ).astype(np.uint8)}
    tris = [(i, i + 1, i + 2) for i in range(n - 2)]
    return {'name': 'bodyShape', 'members': SKINNED, 'columns': cols, 'indices': [x for t in tris for x in t],
            'groups': [(0, 0, len(tris))], 'materials': [material], 'bone_names': list(bone_names)}


def rigid(bone_name):
    cols = {'Position': np.array([[0, 0, 0], [0, 0.6, 0], [0.05, 0.6, 0], [0.05, 0, 0]], np.float32),
            'Normal': np.tile(np.array([0, 0, 127], np.int8), (4, 1)),
            'TextureCoordinates0': np.array([[0, 0], [0, 1], [1, 1], [1, 0]], np.float16)}
    return {'name': 'torchShape', 'members': STATIC, 'columns': cols, 'indices': [0, 1, 2, 0, 2, 3], 'indices16': True,
            'groups': [(0, 0, 2)], 'materials': ['mata'], 'bone_names': [bone_name]}


def quats(axis, degrees):
    return [c for d in degrees for c in S.axis_quat(axis, d)]


def clip(tracks, duration, timestep=1 / 60):
    return S.build_clip([('root', S.transform(flags=0), tracks)], duration=duration, timestep=timestep)


def horse_idle():
    return clip([
        ('horse_root', {'OrientationCurve': ('K32fC32f', 2, [0, 0.4, 1.0, 1.6, 2.0], quats((0, 1, 0), [0, 8, 15, 9, 0])),
                        'PositionCurve': ('D3Constant32f', [0.0, 0.02, 0.0]), 'ScaleShearCurve': ('Identity', 9)}),
        ('horse_spine', {'OrientationCurve': ('D4Constant32f', list(S.axis_quat((1, 0, 0), -12))),
                         'PositionCurve': ('K32fC32f', 1, [0, 1.0, 2.0], [0, 1.2, 0.1, 0, 1.25, 0.12, 0, 1.2, 0.1]),
                         'ScaleShearCurve': ('K32fC32f', 2, [0, 0.7, 1.3, 2.0],
                                             [1, 0, 0, 0, 1, 0, 0, 0, 1, 1.08, 0.03, 0, 0, 0.96, 0, 0, 0.02, 1.02,
                                              0.94, 0, 0.01, 0, 1.04, 0, 0, 0, 0.99, 1, 0, 0, 0, 1, 0, 0, 0, 1])}),
        ('bone attachpoint', {'OrientationCurve': ('K32fC32f', 3, [0, 0.5, 1.0, 1.5, 2.0],
                                                   quats((0, 0, 1), [4, 9, -3, 6, 4])),
                              'PositionCurve': ('Constant32f', [0.0, 0.45, -0.05]), 'ScaleShearCurve': None}),
    ], 2.0)


def horse_attack():
    return clip([
        ('horse_neck', {'OrientationCurve': ('K32fC32f', 2, [0, 0.25, 0.5, 0.75, 1.0], quats((1, 0, 0), [25, 40, 10, 30, 25])),
                        'PositionCurve': ('D3Constant32f', [0.0, 0.3, 0.9]), 'ScaleShearCurve': ('Identity', 9)}),
        ('horse_spine', {'OrientationCurve': ('K32fC32f', 1, [0, 0.5, 1.0], quats((1, 0, 0), [-12, -20, -12])),
                         'PositionCurve': ('D3Constant32f', [0.0, 1.2, 0.1]), 'ScaleShearCurve': ('Identity', 9)}),
    ], 1.0, timestep=1 / 192)


def rider_idle(offset=0):
    return clip([
        ('Bip01 Pelvis', {'OrientationCurve': ('K32fC32f', 2, [0, 0.6, 1.2, 1.8, 2.4],
                                               quats((1, 0, 0), [-90 + offset, -84, -95, -88, -90 + offset])),
                          'PositionCurve': ('K32fC32f', 2, [0, 1.2, 2.4], [0, 0.05, 0, 0.02, 0.07, 0, 0, 0.05, 0]),
                          'ScaleShearCurve': ('Identity', 9)}),
        ('Bip01_Spine', {'OrientationCurve': ('K32fC32f', 0, [0.0], list(S.axis_quat((0, 0, 1), 20))),
                         'PositionCurve': ('D3Constant32f', [0.1, 0, 0.01]), 'ScaleShearCurve': ('K32fC32f', 2, [], [])}),
    ], 2.4)


def rider_attack():
    return clip([
        ('Bip01_Spine', {'OrientationCurve': ('K32fC32f', 2, [0, 0.3, 0.6, 1.0], quats((0, 1, 0), [0, 30, -25, 0])),
                         'PositionCurve': ('D3Constant32f', [0.1, 0, 0.01]), 'ScaleShearCurve': ('Identity', 9)}),
        ('bip01 r hand', {'OrientationCurve': ('K32fC32f', 2, [0, 0.5, 1.0], quats((0, 0, 1), [0, 70, 0])),
                          'PositionCurve': ('D3Constant32f', [0.35, -0.2, 0.15]), 'ScaleShearCurve': ('Identity', 9)}),
    ], 1.0, timestep=1 / 192)


HORSE_XML = '''<animfile>
  <attachment>RiderAttachment<include>%(rider)s</include>
  </attachment>
  <component>ModelComp<logic type="Tech">
      <none><assetreference type="GrannyModel"><file>%(horse_model)s</file></assetreference></none>
    </logic>
    <attach a="RiderAttachment" frombone="hotspot" tobone="ATTACHPOINT" syncanims="1" />
  </component>
  <anim>Idle<assetreference type="GrannyAnim"><file>%(horse_idle)s</file>
      <tag type="FootstepLeft" footprintbone="horse_neck">0.25</tag></assetreference>
    <component>ModelComp</component>
  </anim>
  <anim>Attack<assetreference type="GrannyAnim"><file>%(horse_attack)s</file>
      <tag type="Attack">0.54</tag><tag type="SpecificSoundSet" set="Swoosh" checkvisible="1">1.20</tag></assetreference>
    <component>ModelComp</component>
  </anim>
  <anim>Highstep<assetreference type="GrannyAnim"><file>%(horse_attack)s</file></assetreference>
    <component>ModelComp</component>
  </anim>
</animfile>
'''

RIDER_XML = '''<animfile>
  <attachment>torch<include>%(torch)s</include>
  </attachment>
  <component>ModelComp<logic type="Tech">
      <none><assetreference type="GrannyModel"><file>%(rider_model)s</file></assetreference></none>
    </logic>
  </component>
  <anim>Idle<assetreference type="GrannyAnim"><file>%(rider_idle)s</file><weight>3</weight></assetreference>
    <assetreference type="GrannyAnim"><file>%(rider_idle_b)s</file><weight>1</weight></assetreference>
    <component>ModelComp</component>
  </anim>
  <anim>Attack<assetreference type="GrannyAnim"><file>%(rider_attack)s</file></assetreference>
    <component>ModelComp</component>
    <attach a="torch" frombone="ATTACHPOINT" tobone="R HAND" syncanims="0" />
  </anim>
</animfile>
'''

TORCH_XML = '''<animfile>
  <component>ModelComp<assetreference type="GrannyModel"><file>%(torch_model)s</file></assetreference></component>
  <anim>Idle<component>ModelComp</component></anim>
</animfile>
'''

MATERIALDEF = '''<materialdef pass="opaque" showinviewer="true">
  <shader file="material/materialdefault.hlsl">
    <vertexformat name="SkinnedPackedVertex" />
  </shader>
  <parameters>
    <texture default="missingbasecolor" name="BaseColor" requiresoverride="true" srgb="true" />
    <texture default="black" name="Details" />
    <float default="1.0f" name="AO Intensity" />
  </parameters>
</materialdef>
'''

MATERIAL = '''<material>
  <submaterial name="mata">
    <materialdef name="default" />
    <parameters>
      <texture name="BaseColor" override="%s" />
      <texture name="Details" override="%s" />
    </parameters>
  </submaterial>
</material>
'''


def ddt_bc1(w=16, h=16, seed=3):
    """an RTS3 DXT1 texture with a full mip chain down to 4x4 (format 4), deterministic blocks."""
    rng = np.random.default_rng(seed)
    imgs, level = [], 0
    while True:
        lw, lh = max(1, w >> level), max(1, h >> level)
        imgs.append(rng.integers(0, 256, max(1, (lw + 3) // 4) * max(1, (lh + 3) // 4) * 8, dtype=np.uint8).tobytes())
        if lw <= 4 and lh <= 4:
            break
        level += 1
    off = 16 + 8 * len(imgs)
    table = b''
    for im in imgs:
        table += struct.pack('<II', off, len(im))
        off += len(im)
    return b'RTS3' + bytes([0, 0, 4, len(imgs)]) + struct.pack('<II', w, h) + table + b''.join(imgs)


def write_unit(folder):
    """the profile, its single mod and every file of the synthetic unit; returns the ids."""
    p = F.Profile(Path(folder) / 'profile')
    m = p.mod('synthetic-mod', priority=1)
    names = {'rider': bslash(RIDER_ANIMFILE), 'torch': bslash(TORCH_ANIMFILE),
             'horse_model': bslash(HORSE_MODEL[:-4]), 'rider_model': bslash(RIDER_MODEL[:-4]),
             'torch_model': bslash(TORCH_MODEL[:-4]), **{k: bslash(v[:-4]) for k, v in CLIPS.items()}}
    m.write('art/' + HORSE_ANIMFILE, HORSE_XML % names)
    m.write('art/' + RIDER_ANIMFILE, RIDER_XML % names)
    m.write('art/' + TORCH_ANIMFILE, TORCH_XML % names)
    m.write('art/' + HORSE_MODEL, S.build_model(horse_bones(), [skinned(8, ['horse_root', 'horse spine', 'horse_neck',
                                                                            'bone_attachpoint'], 1)]))
    m.write('art/' + RIDER_MODEL, S.build_model(rider_bones(), [skinned(9, ['Bip01_Root', 'Bip01_Pelvis', 'Bip01_Spine',
                                                                            'Bip01_R_Hand'], 2)]))
    m.write('art/' + TORCH_MODEL, S.build_model(torch_bones(), [rigid('torch_root')], skeleton='torch_root'))
    for key, builder in (('horse_idle', horse_idle), ('horse_attack', horse_attack), ('rider_idle', rider_idle),
                         ('rider_attack', rider_attack)):
        m.write('art/' + CLIPS[key], builder())
    m.write('art/' + CLIPS['rider_idle_b'], rider_idle(offset=5))
    tex = UNIT + 'textures/rider_0_mata_'
    m.write('art/' + RIDER_MODEL[:-4] + '.material', MATERIAL % (bslash(tex + 'basecolor'), bslash(tex + 'details')))
    m.write('art/' + tex + 'basecolor.ddt', ddt_bc1(16, 16, 3))
    m.write('art/' + tex + 'details.ddt', ddt_bc1(16, 16, 4))
    m.write('render/materialdefs/default.materialdef', MATERIALDEF)
    p.write()
    return {'profile': p.folder, 'mod': m.folder, 'horse': HORSE_ANIMFILE, 'rider': RIDER_ANIMFILE,
            'torch': TORCH_ANIMFILE, 'horse_model': HORSE_MODEL, 'rider_model': RIDER_MODEL, 'torch_model': TORCH_MODEL,
            'clips': dict(CLIPS), 'textures': [tex + 'basecolor.ddt', tex + 'details.ddt']}


def vfs(unit, **kw):
    """a vfs.VFS over the unit's profile, mods only (no game layer)."""
    import vfs as V
    return V.VFS(profile=unit['profile'], include_game=False, **kw)
