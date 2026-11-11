#!/usr/bin/env python
"""Clip reader of the aoe3de-anim-viewer backend: an animation .gr2 -> the bundle's clip record (references/bundle-schema.md
section 11) with every curve normalised to {degree, knots f32, controls f32 x dim}, knots and controls in a binary buffer.

    import av_common as C, gr2_curves as GC
    anim = C.BufferWriter('anim')
    rec, warnings = GC.clip_record(path_or_bytes, anim, clip_id='animation_library/cavalry/oprichnik_attack_a.gr2')
    clip = GC.read_clip(path_or_bytes)                  # the Python form (curves as numpy arrays)
    pos, quat, ss = GC.sample_track(clip.tracks[0].curves, t)   # reference evaluator (tests, parity fixtures)

    python gr2_curves.py CLIP.gr2 [...]                 # summary per file (nothing is written)

Python only normalises; the viewer evaluates (bundle-schema section 11). The evaluator here is the Python reference of
that contract, for parity tests: `bspline` is aoe3de-unit-model's clip_decode.bspline (imported, not copied); `t` is
clamped to the knot range; orientations take one Newton step, q *= (3 - |q|^2) / 2 (the adopted default,
`normalize='newton1'`; `'exact'` divides by the norm as clip_decode does).

Curves decoded - the formats clip_decode reads, through its read_curve:
- K32fC32f (real32 knots and controls, any degree) -> `bspline`; an empty one -> `identity`, `inferred: true`
  (clip_decode's reading; the stored format stays in `format`);
- Constant32f, D3Constant32f, D4Constant32f -> `constant`;
- Identity -> `identity`, `inferred: false`; a curve without data -> `identity`, format `none`, `inferred: true`.
Every other format (the quantized D4nK16uC15u, D4nK8uC7u, D3K16uC16u, D3K8uC8u, D3I1K*, Keyframes32f, ...) -> an
`unavailable` curve with reason `curve-format-<name lower case>`; the clip then has `decodable: false` and its first
such reason, while every decodable curve is still written. A malformed curve (control count against dimension, knots
not ascending) -> `curve-malformed`. Files that cannot be opened (Oodle, 32-bit, ...) give the unavailable clip record,
as gr2_model does; a gr2 without an animation -> `clip-no-animation`. Only the first animation and its first track group
are read (clip_decode's rule; the schema's clip has one `track_group`); every other group is named, with its track
count and curve formats, in the warning `clip-extra-track-groups`. Vanilla has such clips: petard01/attack.gr2 holds
the prop's 6 tracks first and the soldier's 24 tracks (quantized curves) second, so its record shows only the prop.

Measured 2026-10-11 on vanilla oprichnik_attack_a.gr2 (192 fps, 289 keys, 32 tracks, all K32fC32f degree 2): the
normalised curves reproduce clip_decode.decode at every key exactly (0.0, exact normalisation; key 0 with the Newton
step 4.8e-14), and iron_rider_0 posed at key 0 equals pose_sim in frame A within 5.1e-14. Off key 0 the Newton step
differs from exact normalisation by up to 7.9e-6 in quaternion components, 1.6e-5 in matrix entries (the B-spline blend
of unit quaternions shrinks |q|^2 by up to 0.005), so a parity check must use the same rule on both sides.
"""
from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np

import gr2_model as GM  # noqa: E402  (sets sys.path for av_common, unit_gr2, clip_decode and the consumer reader)
import av_common as C  # noqa: E402
import clip_decode as CD  # noqa: E402
from gr2_dump import CURVE_FMT, refs  # noqa: E402

DECODED = ('K32fC32f', 'Identity', 'Constant32f', 'D3Constant32f', 'D4Constant32f')
CONSTANT_FORMATS = ('Constant32f', 'D3Constant32f', 'D4Constant32f')
TRACK_CURVES = (('position', 'PositionCurve', 3), ('orientation', 'OrientationCurve', 4),
                ('scale_shear', 'ScaleShearCurve', 9))
IDENTITY = {3: [0.0, 0.0, 0.0], 4: [0.0, 0.0, 0.0, 1.0], 9: list(GM.IDENTITY_SS)}


class Curve:
    """one normalised curve: kind 'bspline' | 'constant' | 'identity' | 'unavailable'; bspline: degree, knots
    (K,) float32, controls (K, dim) float32; constant: value (dim,); identity: inferred; unavailable: reason."""

    def __init__(self, kind, dim, fmt, degree=None, knots=None, controls=None, value=None, inferred=False,
                 reason=None, detail=None):
        self.kind, self.dim, self.format = kind, int(dim), fmt
        self.degree, self.knots, self.controls = degree, knots, controls
        self.value, self.inferred, self.reason, self.detail = value, inferred, reason, detail

    def __repr__(self):
        extra = {'bspline': lambda: 'degree %s, %d knots' % (self.degree, len(self.knots)),
                 'constant': lambda: str(list(self.value)), 'identity': lambda: 'inferred %s' % self.inferred,
                 'unavailable': lambda: self.reason}[self.kind]()
        return 'Curve(%s %s dim %d, %s)' % (self.kind, self.format, self.dim, extra)


def curve_format(g, cv):
    """(format code, format name) of an inline granny curve2, or (None, 'none') when it holds no data."""
    v = cv.get('CurveData') if cv else None
    if not v or v[0] != 'variant' or not v[1] or not v[2]:
        return None, 'none'
    op = v[2]
    code = g.payload[op[0]][op[1]]                 # CurveDataHeader.Format: the first byte of every curve struct
    return code, CURVE_FMT.get(code, str(code))


def read_curve(g, cv, dim) -> Curve:
    code, name = curve_format(g, cv)
    if code is None:
        return Curve('identity', dim, 'none', inferred=True)
    if name not in DECODED:
        return Curve('unavailable', dim, name, reason='curve-format-' + name.lower())
    try:
        c = CD.read_curve(g, cv, dim)
    except CD.Undecodable as e:
        return Curve('unavailable', dim, name, reason='curve-malformed', detail=str(e))
    if c is None:                                   # Identity, or an empty K32fC32f (identity, inferred)
        return Curve('identity', dim, name, inferred=(name != 'Identity'))
    _, degree, K, Cn = c
    if name in CONSTANT_FORMATS:
        return Curve('constant', dim, name, value=np.asarray(Cn[0], np.float32))
    K32, C32 = np.asarray(K, np.float32), np.asarray(Cn, np.float32).reshape(len(K), dim)
    if len(K32) > 1 and np.any(np.diff(K32) < 0):
        return Curve('unavailable', dim, name, reason='curve-malformed', detail='knots not ascending')
    return Curve('bspline', dim, name, degree=int(degree), knots=K32, controls=C32)


def _transform_tracks(g, tg):
    tt = tg.get('TransformTracks')
    return g.array(tt) if isinstance(tt, tuple) and tt and tt[0] == 'array' else []


class Track:
    def __init__(self, bone, flags, curves):
        self.bone, self.flags, self.curves = bone, flags, curves     # curves: {'position'|'orientation'|...: Curve}


class Gr2Clip:
    """the Python form of an animation gr2 (read_clip)."""

    def __init__(self, g, info, path=None):
        self.path, self.info, self.crc_ok = path, info, bool(g.crc_check())
        anims = [a for a, _ in refs(g, g.root().get('Animations'))]
        groups = [t for t, _ in refs(g, anims[0].get('TrackGroups'))] if anims else []
        if not anims or not groups:
            raise GM.Gr2Unavailable('clip-no-animation', info, 'no animation' if not anims else 'no track group')
        an, tg = anims[0], groups[0]
        self.animation_count, self.group_count = len(anims), len(groups)
        self.name = an.get('Name')
        self.duration = float(an['Duration'][0])
        self.timestep = float(an['TimeStep'][0])
        self.oversampling = float(an['Oversampling'][0]) if isinstance(an.get('Oversampling'), tuple) else None
        self.fps_declared = 1.0 / self.timestep if self.timestep > 0 else None
        self.key_count = int(round(self.duration * round(self.fps_declared))) + 1 if self.fps_declared else None
        self.group_name = tg.get('Name')
        ip = tg.get('InitialPlacement')
        self.initial_placement = GM.transform(ip) if isinstance(ip, tuple) and len(ip) == 17 else None
        self.tracks = []
        for tr in _transform_tracks(g, tg):
            fl = tr.get('Flags')
            self.tracks.append(Track(tr['Name'], int(fl[0]) if isinstance(fl, tuple) else None,
                                     {key: read_curve(g, tr.get(field), dim) for key, field, dim in TRACK_CURVES}))
        # groups this reader leaves out (vanilla petard01/attack.gr2: the prop group first, the soldier's 24 tracks
        # with quantized curves second): name, track count and formats, for the warning
        self.extra_groups = []
        for ai, a in enumerate(anims):
            for gi, t in enumerate(refs(g, a.get('TrackGroups'))):
                if ai == 0 and gi == 0:
                    continue
                tt = _transform_tracks(g, t[0])
                self.extra_groups.append({'animation': ai, 'name': t[0].get('Name'), 'tracks': len(tt),
                                          'formats': sorted({curve_format(g, x.get(f))[1] for x in tt
                                                             for _, f, _ in TRACK_CURVES})})

    def curves(self):
        for tr in self.tracks:
            for key, _, _ in TRACK_CURVES:
                yield tr, key, tr.curves[key]

    @property
    def formats(self):
        return sorted({c.format for _, _, c in self.curves()})

    @property
    def decodable(self):
        return all(c.kind != 'unavailable' for _, _, c in self.curves())

    @property
    def unavailable_reason(self):
        reasons = sorted({c.reason for _, _, c in self.curves() if c.kind == 'unavailable'})
        return reasons[0] if reasons else None

    def key_times(self):
        """the clip_decode key grid: every 1/round(fps) s from 0 to the duration."""
        if not self.key_count:
            return [0.0]
        fps = round(self.fps_declared)
        return [min(f / fps, self.duration) for f in range(self.key_count)]


def read_clip(src) -> Gr2Clip:
    """the Python form of an animation gr2 (path or bytes); GM.Gr2Unavailable when it cannot be opened."""
    path = None if isinstance(src, (bytes, bytearray, memoryview)) else Path(src)
    g, info = GM.open_gr2(src)
    try:
        return Gr2Clip(g, info, path)
    except GM.PARSE_ERRORS as e:
        raise GM.Gr2Unavailable('gr2-parse-failed', info, '%s: %s' % (type(e).__name__, e))


# ------------------------------------------------------------------------------------------------ records
def curve_record(curve, writer) -> dict:
    """the bundle form of one curve; a bspline's knots and controls are appended to `writer`."""
    if curve.kind == 'bspline':
        return {'kind': 'bspline', 'degree': curve.degree, 'dim': curve.dim, 'format': curve.format,
                'knots': writer.add(curve.knots, 'f32', 1),
                'controls': writer.add(curve.controls, 'f32', curve.dim)}
    if curve.kind == 'constant':
        return {'kind': 'constant', 'dim': curve.dim, 'format': curve.format,
                'value': [float(x) for x in curve.value]}
    if curve.kind == 'identity':
        return {'kind': 'identity', 'dim': curve.dim, 'format': curve.format, 'inferred': bool(curve.inferred)}
    return {'kind': 'unavailable', 'dim': curve.dim, 'format': curve.format, 'reason': curve.reason}


def curve_from_record(rec, buffers) -> Curve:
    """a Curve back from its bundle form; `buffers` maps buffer id -> bytes (the .bin contents)."""
    kind, dim = rec['kind'], rec['dim']
    if kind == 'bspline':
        K = np.array(C.read_view(buffers[rec['knots']['buffer']], rec['knots']), np.float32).reshape(-1)
        Cn = np.array(C.read_view(buffers[rec['controls']['buffer']], rec['controls']), np.float32).reshape(-1, dim)
        return Curve('bspline', dim, rec['format'], degree=rec['degree'], knots=K, controls=Cn)
    if kind == 'constant':
        return Curve('constant', dim, rec['format'], value=np.asarray(rec['value'], np.float32))
    if kind == 'identity':
        return Curve('identity', dim, rec['format'], inferred=rec.get('inferred', False))
    return Curve('unavailable', dim, rec['format'], reason=rec.get('reason'))


def unavailable_clip_record(clip_id, reason, provenance=None) -> dict:
    return {'id': clip_id, 'path': clip_id, 'provenance': provenance, 'decodable': False,
            'unavailable_reason': reason, 'duration': None, 'timestep': None, 'oversampling': None,
            'fps_declared': None, 'key_count': None, 'formats': [], 'track_group': None, 'tracks': [],
            'precomp': None}


def record_from_clip(clip, writer, *, clip_id, provenance=None, layer=None):
    """(clip record, warnings) of a read Gr2Clip; knots and controls are appended to `writer`."""
    warnings = []
    if not clip.crc_ok:
        warnings.append(GM.warning('gr2-crc-mismatch', clip_id, 'the header CRC does not match the file (the '
                                   'engine\'s reaction is unknown)', layer))
    if clip.extra_groups:
        warnings.append(GM.warning('clip-extra-track-groups', clip_id, 'only the first track group (%s) of the first '
                                   'animation is read; NOT read: %s' % (clip.group_name, '; '.join(
                                       'animation %d group %s: %d tracks, %s' % (x['animation'], x['name'],
                                                                                 x['tracks'], ', '.join(x['formats']))
                                       for x in clip.extra_groups)), layer))
    bad = {}
    for tr, key, c in clip.curves():
        if c.kind == 'unavailable':
            bad.setdefault((c.reason, c.format), []).append('%s.%s' % (tr.bone, key))
    for (reason, fmt), where in sorted(bad.items()):
        code = 'curve-malformed' if reason == 'curve-malformed' else 'curve-format-unsupported'
        warnings.append(GM.warning(code, clip_id, '%s (%s): %d curve(s), e.g. %s'
                                   % (fmt, reason, len(where), ', '.join(where[:4])), layer))
    tracks = [{'bone': tr.bone, **{key: curve_record(tr.curves[key], writer) for key, _, _ in TRACK_CURVES}}
              for tr in clip.tracks]
    rec = {'id': clip_id, 'path': clip_id, 'provenance': provenance, 'decodable': clip.decodable,
           'unavailable_reason': clip.unavailable_reason, 'duration': clip.duration, 'timestep': clip.timestep,
           'oversampling': clip.oversampling, 'fps_declared': clip.fps_declared, 'key_count': clip.key_count,
           'formats': clip.formats,
           'track_group': {'name': clip.group_name, 'initial_placement': clip.initial_placement},
           'tracks': tracks, 'precomp': None}
    return rec, warnings


def clip_record(src, writer, *, clip_id=None, provenance=None, layer=None):
    """(clip record, warnings) for an animation gr2 given as a path or bytes. A file that cannot be opened gives the
    unavailable record and one warning; `writer` is then left untouched."""
    is_bytes = isinstance(src, (bytes, bytearray, memoryview))
    cid = clip_id or ('synthetic.gr2' if is_bytes else C.logical_path(src))
    try:
        clip = read_clip(src)
    except GM.Gr2Unavailable as e:
        return unavailable_clip_record(cid, e.reason, provenance), [GM.unavailable_warning(e.reason, cid, e.detail,
                                                                                           layer)]
    return record_from_clip(clip, writer, clip_id=cid, provenance=provenance, layer=layer)


# ------------------------------------------------------------------------------------------------ reference evaluator
def normalize_quaternion(q, rule='newton1'):
    """'newton1': q * (3 - |q|^2) / 2 (one Newton step, the bundle default); 'exact': q / |q|; 'none'."""
    q = np.asarray(q, np.float64)
    if rule == 'newton1':
        return q * ((3.0 - float(q @ q)) / 2.0)
    if rule == 'exact':
        return q / (np.linalg.norm(q) or 1.0)
    return q


def evaluate(curve, t, method='bspline'):
    """value (dim,) of a curve at time t (seconds). method 'bspline' (the contract) or 'knots' (debug: every control
    a linear key at its knot), both clip_decode.sample. ValueError for an unavailable curve."""
    if curve.kind == 'bspline':
        return np.asarray(CD.sample(('', curve.degree, curve.knots.astype(np.float64),
                                     curve.controls.astype(np.float64)), float(t), method), np.float64)
    if curve.kind == 'constant':
        return np.asarray(curve.value, np.float64)
    if curve.kind == 'identity':
        return np.asarray(IDENTITY[curve.dim], np.float64)
    raise ValueError('curve %s is unavailable (%s)' % (curve.format, curve.reason))


def sample_track(curves, t, method='bspline', normalize='newton1'):
    """(position (3,), orientation (4,) normalised, scale_shear (9,)) of one track at time t."""
    return (evaluate(curves['position'], t, method),
            normalize_quaternion(evaluate(curves['orientation'], t, method), normalize),
            evaluate(curves['scale_shear'], t, method))


def track_matrix(curves, t, method='bspline', normalize='newton1'):
    """the track's local row-vector 4x4 at time t (L = R @ S, translation row), gr2 frame."""
    p, q, s = sample_track(curves, t, method, normalize)
    return GM.local_matrix({'position': p, 'orientation': q, 'scale_shear': s})


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('files', nargs='+', help='animation gr2 files on disk (read only)')
    a = ap.parse_args(argv)
    for f in a.files:
        try:
            clip = read_clip(f)
        except GM.Gr2Unavailable as e:
            print('%s: unavailable (%s)' % (f, e))
            continue
        kinds = {}
        for _, _, c in clip.curves():
            label = '%s %s' % (c.kind, c.format) + (' deg %d' % c.degree if c.kind == 'bspline' else '')
            kinds[label] = kinds.get(label, 0) + 1
        print('%s: %.4f s, %.3f fps declared, %s keys, %d tracks, decodable %s%s, curves %s'
              % (Path(f).name, clip.duration, clip.fps_declared or 0, clip.key_count, len(clip.tracks),
                 clip.decodable, ' (%s)' % clip.unavailable_reason if not clip.decodable else '',
                 dict(sorted(kinds.items()))))


if __name__ == '__main__':
    main()
