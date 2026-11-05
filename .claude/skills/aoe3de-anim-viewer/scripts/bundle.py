#!/usr/bin/env python
"""Unit bundle writer: one proto (or a bare animfile) -> manifest.json + binary buffers in the viewer cache.

    python bundle.py --proto ypIronFlail [--lgt "Tantalus Viewer"] [--out-root DIR] [--json]
    python bundle.py --animfile units/asians/chinese/iron_flail/iron_flail.xml

    import bundle as B
    res = B.build_bundle(proto='ypIronFlail')       # BuildResult: bundle_id, folder, manifest, summary()
    res.folder / 'manifest.json'                    # references/bundle-schema.md, v0

The writer only wires the M1 modules together, in this order, all read-only:
    vfs (layers from mods/age3-mod-status.json, then the game archives)
    -> proto_resolve (protoy + every enabled mod's protomods; ROF from the protoactions)
    -> animfile (includes, attachments, logic, attach records, audit)
    -> gr2_model for every model the animfiles reference, in every logic state (the viewer switches states)
    -> gr2_curves for every clip, whose durations feed the horse/rider pairing and the timing view
    -> tactics (actions, tactics, transitions, speedmodifier) and the merged `timing`
    -> material (the `.material` beside each gr2, merged with its materialdef) -> ddt (raw BC mips for S3TC)
    -> lighting (lgt, reflection cube, tonemap LUT, playercolors)
Nothing the subject references is dropped: an undecodable model, clip or texture keeps its id with
`decodable: false` and `unavailable_reason`, and raises a warning (bundle-schema section 5).

Where it writes: `<out root>/<bundle_id>/` (default out root = av_common.cache_root(), the system temp; a git work tree,
an AoE3 profile or mods folder and the install are refused - AGENTS.md rules 3 and 8). The binary buffers are written
first and the manifest last, each atomically, so a reader never sees a manifest that names missing bytes.

bundle_id = av_common.cache_key(inputs): the subject, the logic states ('all': every state is in the bundle), the
VFS layer list with its fingerprints, the lighting choice and the tool version. Mod file CONTENTS are not in the key
(a mod edit keeps the id, so the owner's viewer URL stays valid); every build re-reads the sources and rewrites the
folder, and `content_sha256` (over every provenance hash) changes with any source byte.

`fidelity` holds an M (measured) / A (approximated) / U (unknown) / H (labelled hypothesis) flag per stage of what the
viewer shows and exports - the pose and skinning, the M3 game shader (lighting.SHADING_FIDELITY), the M4 timeline
(TIMELINE_STAGES) and the M5 exports (EXPORT_STAGES) - and `build` the per-module result of this run (counts,
unavailable items).
"""
from __future__ import annotations

import argparse
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))
import av_common as C  # noqa: E402
import vfs as V  # noqa: E402
import proto_resolve as P  # noqa: E402
import animfile as A  # noqa: E402
import tactics as T  # noqa: E402

DEFAULT_LGT = 'Tantalus Viewer'
DEFAULT_REFL_MAX = 128          # px: the reflection cube is not drawn before M3; keep the bundle small
VIEWER_STAGE = 'm3'             # the game shader (viewer/shading): its stage flags come from lighting.SHADING_FIDELITY

CONVENTIONS = {'frame': 'gr2', 'up': '+y', 'vectors': 'row', 'matrix_order': 'row-major', 'quaternion': 'xyzw',
               'local': 'R@S', 'time': 'seconds', 'curve_eval': 'bspline-clip_decode', 'quat_normalize': 'newton1',
               'display': 'engine frame drawn with x negated (the gr2 frame is left-handed: Right -X, Up +Y, Back +Z; '
                          'unit_gr2 frame A, det -1, maps it to the converter/Blender frame)'}

FIDELITY_STAGES = {
    'skinning': ('M', 'linear blend, 4 influences, skin = inverse_world @ world (game vertex shader)'),
    'pose': ('M', 'tracks bound by name (space = underscore), untracked bones keep their rest local, R@S with full '
                  'scale-shear; pose_sim parity'),
    'curve_sampling': ('A', 'B-spline (clip_decode.bspline) in continuous time with one Newton-step quaternion '
                            'normalisation; Granny index alignment inferred (critic P0-3), not measured on AoE3 data'),
    'vertex_input': ('M', 'vertex streams uploaded byte for byte (f32 position, snorm normal, f16 UV, u8 weights)'),
    'texture_decode': ('M', 'raw S3TC upload: the GPU decodes BC blocks as the game does (M0: NVIDIA rounding on '
                            'ANGLE D3D11, exact on SwiftShader)'),
    'material': ('A', 'M2 placeholder: BaseColor (sRGB), player colour through Details.R, cutout 0.5; Masks, '
                      'Normals and the materialdef parameters are not shaded until the game shader (M3)'),
    'brdf': ('A', 'M2 placeholder: Lambert sun + flat ambient, not the game GGX/IBL lighting pass'),
    'lgt_mapping': ('U', 'lgt fields -> shader constants are name matches or guesses (lighting.py derived)'),
    'player_colour': ('U', 'playercolors color1 read as sRGB/255 (guess)'),
    'sun_direction': ('U', 'lighting.sun_direction convention is a guess'),
    'tonemap': ('U', 'no tonemap in M2 (the LUT is in the bundle; which game path runs is unknown)'),
    'shadows': ('A', 'no shadows in M2'),
    'camera': ('U', 'game camera FOV and distance unknown; pitch 47 from game.cfg limitPitch (meaning unverified)'),
    'rider_sync': ('H', 'rider root = the horse ATTACHPOINT world matrix; same anim name, variant i -> i mod n; '
                        'absolute time or normalised phase (labelled hypothesis, critic P1-6)'),
    'timing': ('H', 'ROF from the protoactions, tactics rate rules H1..H4 (labelled hypotheses)'),
}

# M4 timeline stages (the same flags and notes as viewer/panels/data.js TIMELINE_FIDELITY, adopted here so every
# consumer - job reports, export sidecars, the badge - sees them; a stage the bundle carries wins in the page)
TIMELINE_STAGES = {
    'key_grid': ('M', 'key ticks at k / round(1 / timestep) s, the clip_decode grid; a non-integer declared rate is '
                      'flagged on the ruler'),
    'tag_timing': ('H', "tags at fraction x clip duration on the clip's own clock (H2); whether animlengthoverride "
                        'stretches them is unknown (ghost markers)'),
    'tag_overflow': ('U', 'fraction > 1 drawn past the clip end in the overflow lane: meaning unknown'),
    'variant_choice': ('H', 'the roll is one draw over the normalised weights; anims without <weight> are uniform '
                            '(hypothesis); when and how the engine draws is not measured'),
    'tactics_rate': ('H', 'tactics-rate preset = AnimationRate (H3) x clip / ROF (H1 ROF fit), labelled until the '
                          'timing run (design section 8 item 9)'),
    'footprint': ('A', "dot at the footprintbone's world position at the tag time (viewer pose); a bone only declared "
                       'by <definebone> sits at the model origin (verified for attaches, assumed for footprints)'),
}

# M5 export stages (anim_viewer.py render / video / compare; scripts/sheets.py, video.py, metrics.py)
EXPORT_STAGES = {
    'export_frame_times': ('M', 'every exported frame is posed at an exact main-clock time from the bundle clips '
                                '(deterministic sampling in the headless page, never a real-time capture); video frame i '
                                'shows t = i / fps modulo the main clip duration'),
    'video_encode': ('A', 'MP4 = H.264 yuv420p (BT.709 matrix, limited range, 4:2:0 chroma) of the sRGB PNG frames; '
                          'animated WebP stores frame durations in whole milliseconds (round(1000 / fps))'),
    'compare_clock': ('H', 'compare and side-by-side: both units start their anim at t = 0 on one main clock and each '
                           'loops its own main clip past its end; how two units align in game is not measured'),
    'metric_penetration': ('A', 'rider-horse penetration: rider vertices inside the horse meshes by the generalised '
                                'winding number (|w| > 0.5; the meshes are open triangle soups), depth = distance to the '
                                'nearest horse triangle; CPU-skinned viewer pose, gr2 units (metres assumed)'),
    'metric_hoof_height': ('A', "hoof height: lowest vertex of the footstep's leg above y = 0; legs = the lowest 12 % "
                                'of the bind pose, split front/back and left/right by the skeleton (head bone side, '
                                '_l bones side); the footprintbone name (FRNT/BACK, LT/RT) picks the leg'),
}


class BuildResult:
    def __init__(self, bundle_id, folder, manifest):
        self.bundle_id, self.folder, self.manifest = bundle_id, Path(folder), manifest

    def summary(self) -> dict:
        m = self.manifest

        def unavailable(section):
            return sorted(k for k, v in (m.get(section) or {}).items() if v and v.get('decodable') is False)
        return {
            'bundle_id': self.bundle_id, 'folder': str(self.folder), 'subject': m['subject'],
            'animfiles': len(m['animfiles']), 'models': len(m['models']), 'clips': len(m['clips']),
            'materials': len(m['materials']), 'textures': len(m['textures']),
            'unavailable': {s: unavailable(s) for s in ('models', 'clips', 'textures') if unavailable(s)},
            'warnings': len(m['warnings']),
            'warning_codes': sorted({w['code'] for w in m['warnings']}),
            'bytes': sum(b['byteLength'] for b in m['buffers']),
            'elapsed_s': m['build']['elapsed_s'],
        }


def _log_default(msg):
    print(msg, flush=True)


def material_file_of(model_id) -> str:
    """the `.material` beside a gr2, same base name (aoe-xml art-xml.md)."""
    return model_id[:-4] + '.material' if model_id.lower().endswith('.gr2') else model_id + '.material'


def _dedupe(warnings):
    seen, out = set(), []
    for w in warnings:
        key = (w.get('code'), w.get('path'), w.get('layer'), w.get('message'))
        if key not in seen:
            seen.add(key)
            out.append(w)
    return out


def fidelity_block() -> dict:
    """FIDELITY_STAGES with the M3 game-shader stages of lighting.SHADING_FIDELITY merged over them (the shared keys -
    material, brdf, tonemap, shadows, lgt mapping, player colour, sun direction - describe the game shader now)."""
    import lighting as L
    stages = dict(FIDELITY_STAGES)
    stages.update(L.SHADING_FIDELITY)
    stages.update(TIMELINE_STAGES)
    stages.update(EXPORT_STAGES)
    return {'calibration': 'none', 'shader_model': L.SHADER_MODEL, 'viewer': VIEWER_STAGE,
            'stages': {k: v[0] for k, v in stages.items()},
            'notes': {k: v[1] for k, v in stages.items()}}


def build_bundle(proto=None, animfile=None, *, fs=None, lgt=DEFAULT_LGT, out_root=None, refl_max_size=DEFAULT_REFL_MAX,
                 textures=True, lighting=True, presets=True, log=_log_default) -> BuildResult:
    """read every source of the subject and write its bundle (module docstring). proto: a proto name; animfile: an
    animfile id or path instead. fs: a vfs.VFS (default: this profile's layers and the game). Returns BuildResult."""
    import gr2_model as GM                      # numpy and the consumer's gr2 reader: imported here, not at load
    import gr2_curves as GC
    import material as MAT
    import ddt as D
    import lighting as L

    t0 = time.monotonic()
    root = C.refuse_repo_path(out_root or C.cache_root(), 'a viewer bundle')
    fs = fs or V.VFS()
    log('layers: %s' % ', '.join(lay.id for lay in fs.layers))
    proto_rec = None
    if proto:
        proto_rec = P.resolve_proto(fs, proto)
        if proto_rec is None:
            raise LookupError('proto %r not found in protoy or the enabled mods\' protomods' % proto)
        animfile = proto_rec['animfile']
        subject = {'kind': 'proto', 'proto': proto_rec['name'], 'animfile': animfile}
    elif animfile:
        subject = {'kind': 'animfile', 'proto': None, 'animfile': C.logical_path(animfile)}
        animfile = subject['animfile']
    else:
        raise ValueError('build_bundle needs a proto name or an animfile')
    if not animfile:
        raise LookupError('proto %s names no animfile' % proto)
    log('subject: %s -> %s' % (subject['proto'] or '-', animfile))

    s = A.AnimfileSet(fs, animfile, bones=A.Gr2Bones(fs))
    log('animfiles: %d (%s)' % (len(s.animfiles), ', '.join(s.animfiles)))
    build = {'modules': {}}
    warnings = []
    geo, anim, tex, light = (C.BufferWriter(x) for x in ('geo', 'anim', 'tex', 'light'))

    def layer_fill(ws, layer=None):
        for w in ws:
            if w.get('layer') is None and layer is not None:
                w['layer'] = layer
            warnings.append(w)

    # ---------------------------------------------------------------- models
    models = {}
    material_files = []
    for mid in s.references['models']:
        vf = fs.read(mid, quiet=True)
        if vf is None:
            models[mid] = GM.unavailable_model_record(mid, 'file-missing')
            warnings.append(GM.warning('file-missing', mid, 'model in no layer'))
            continue
        mfile = material_file_of(mid)
        has_mat = fs.exists(mfile)
        rec, ws = GM.model_record(vf.data, geo, model_id=mid, provenance=vf.provenance,
                                  material_file=mfile if has_mat else None, layer=vf.layer)
        rec['layer'] = vf.layer
        rec['material_file'] = mfile if has_mat else None
        models[mid] = rec
        layer_fill(ws, vf.layer)
        if has_mat and mfile not in material_files:
            material_files.append(mfile)
        if rec['decodable'] and not has_mat:
            warnings.append(GM.warning('material-file-missing', mfile, 'no .material beside %s (the art-xml.md '
                                       'convention; how the engine finds this model\'s material is unknown): its '
                                       'meshes draw untextured' % mid, vf.layer))
    build['modules']['gr2_model'] = {'models': len(models),
                                     'unavailable': sorted(k for k, v in models.items() if not v['decodable'])}
    log('models: %d (%d unavailable)' % (len(models), len(build['modules']['gr2_model']['unavailable'])))

    # ---------------------------------------------------------------- clips
    clips, durations = {}, {}
    for cid in s.references['clips']:
        vf = fs.read(cid, quiet=True)
        if vf is None:
            clips[cid] = GC.unavailable_clip_record(cid, 'file-missing')
            continue
        rec, ws = GC.clip_record(vf.data, anim, clip_id=cid, provenance=vf.provenance, layer=vf.layer)
        rec['layer'] = vf.layer
        clips[cid] = rec
        layer_fill(ws, vf.layer)
        if rec.get('duration') is not None:
            durations[cid] = rec['duration']
    build['modules']['gr2_curves'] = {'clips': len(clips),
                                      'unavailable': sorted(k for k, v in clips.items() if not v['decodable']),
                                      'formats': sorted({f for v in clips.values() for f in v.get('formats') or []})}
    log('clips: %d (%d unavailable), formats %s' % (len(clips), len(build['modules']['gr2_curves']['unavailable']),
                                                   build['modules']['gr2_curves']['formats']))

    composition = s.composition(durations)

    # ---------------------------------------------------------------- tactics and timing
    tac = None
    if proto_rec and proto_rec.get('tactics_file'):
        tac = T.load_tactics(fs, proto_rec['tactics_file'])
    timing = T.timing(proto_rec, tac, s.animfiles.get(s.root), durations) if (proto_rec or tac) else \
        {'actions': [], 'status': 'hypothesis', 'rules': []}
    build['modules']['tactics'] = {'file': tac['id'] if tac else None, 'actions': len(timing['actions'])}

    # ---------------------------------------------------------------- materials and textures
    fetch = MAT.vfs_fetch(fs)
    materials, texture_uses = {}, {}
    cache = MAT.MaterialdefCache(fetch)
    for mfile in material_files:
        got = fetch(mfile)
        if got is None:
            continue
        out = MAT.build_materials(mfile, got[0], fetch, provenance=got[1], cache=cache)
        materials.update(out['records'])
        for tid, uses in out['texture_uses'].items():
            texture_uses.setdefault(tid, []).extend(uses)
        layer_fill(out['warnings'], fs.provenance.records[got[1]]['layer'])
        if out['empty']:
            warnings.append({'code': 'material-empty', 'path': mfile, 'layer': None,
                             'message': '%s has no submaterial' % mfile})
    textures_out = {}
    if textures:
        for tid in texture_uses:
            got = fetch(tid)
            rec = D.texture_record(tid, got[0] if got else None, tex, provenance=got[1] if got else None)
            rec['uses'] = texture_uses[tid]
            textures_out[tid] = rec
            if not rec['decodable']:
                warnings.append({'code': rec['unavailable_reason'] if rec['unavailable_reason'] == 'file-missing'
                                 else 'texture-unavailable', 'path': tid, 'layer': None,
                                 'message': 'texture not drawn: %s' % rec['unavailable_reason']})
    build['modules']['material'] = {'files': material_files, 'materials': len(materials)}
    build['modules']['ddt'] = {'textures': len(textures_out),
                               'unavailable': sorted(k for k, v in textures_out.items() if not v['decodable'])}
    log('materials: %d from %d files; textures: %d (%d unavailable)'
        % (len(materials), len(material_files), len(textures_out), len(build['modules']['ddt']['unavailable'])))

    # ---------------------------------------------------------------- lighting
    if lighting and lgt:
        lres = L.build_lighting(lgt, fetch, light, refl_max_size=refl_max_size)
        lighting_section = lres['section']
        if presets:          # M3: the lgt presets as lighting packs (full reflection cube) beside the bundle
            lighting_section['presets'] = L.build_presets(out_root=root, log=log)
            log('lighting presets: %s' % ', '.join('%s %s' % (p['name'], p['bundle_id'] or p['status'])
                                                   for p in lighting_section['presets']))
        layer_fill(lres['warnings'])
    else:
        lighting_section = L.lighting_section()
    build['modules']['lighting'] = {'lgt': lgt if lighting else None,
                                    'refl_max_size': refl_max_size,
                                    'refl': (lighting_section.get('refl') or {}).get('id')}

    # ---------------------------------------------------------------- manifest
    inputs = [{'subject': subject}, {'logic': 'all'}, {'layers': fs.inputs()},
              {'lighting': {'lgt': lgt if lighting else None, 'refl_max_size': refl_max_size}},
              {'tool': C.TOOL_VERSION, 'schema': C.SCHEMA_VERSION}]
    bundle_id = C.cache_key(*inputs)
    warnings = _dedupe(fs.warnings + warnings)
    prov = fs.provenance.to_json()
    content = C.sha256_bytes(C.canonical_json([[p['layer'], p['path'], p['sha256']] for p in prov]).encode('utf-8'))
    writers = [w for w in (geo, anim, tex, light) if w.data()]
    build['elapsed_s'] = round(time.monotonic() - t0, 2)
    manifest = {
        'schema': C.SCHEMA_NAME, 'schema_version': C.SCHEMA_VERSION, 'bundle_id': bundle_id,
        'created': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
        'tool': {'name': C.TOOL_NAME, 'version': C.TOOL_VERSION, 'shader_model': L.SHADER_MODEL, 'calibration': 'none'},
        'inputs': inputs, 'subject': subject, 'conventions': dict(CONVENTIONS),
        'buffers': [w.record() for w in writers],
        'layers': fs.layer_records(), 'provenance': prov, 'content_sha256': content,
        'warnings': warnings,
        'logic': s.logic, 'composition': composition, 'animfiles': s.animfiles,
        'models': models, 'materials': materials, 'textures': textures_out, 'clips': clips,
        'proto': proto_rec, 'tactics': tac, 'timing': timing, 'lighting': lighting_section,
        'fidelity': fidelity_block(), 'oracles': {'precomp': None}, 'build': build,
    }
    folder = root / bundle_id
    for w in writers:
        C.write_bytes(folder / (w.id + '.bin'), w.data(), 'a viewer bundle')
    for stale in folder.glob('*.bin'):                       # buffers of an earlier build that this one lacks
        if stale.stem not in {w.id for w in writers}:
            stale.unlink()
    C.write_json(folder / 'manifest.json', manifest, why='a viewer bundle')
    log('bundle %s: %s (%.1f MB, %d warnings) in %.1f s'
        % (bundle_id, folder, sum(b['byteLength'] for b in manifest['buffers']) / 1e6, len(warnings),
           build['elapsed_s']))
    return BuildResult(bundle_id, folder, manifest)


def list_bundles(root=None) -> list:
    """[{bundle_id, subject, created, bytes}] of the bundles under the cache root (newest first)."""
    root = Path(root) if root else C.cache_root()
    out = []
    for m in root.glob('*/manifest.json'):
        if not P_BUNDLE_ID(m.parent.name):
            continue
        try:
            d = C.read_json(m)
        except (OSError, ValueError):
            continue
        out.append({'bundle_id': d.get('bundle_id'), 'subject': d.get('subject'), 'created': d.get('created'),
                    'bytes': sum(b.get('byteLength', 0) for b in d.get('buffers', [])),
                    'warnings': len(d.get('warnings', []))})
    return sorted(out, key=lambda x: x['created'] or '', reverse=True)


def P_BUNDLE_ID(name) -> bool:
    return len(name) == 16 and all(c in '0123456789abcdef' for c in name)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument('--proto', help='proto name, e.g. ypIronFlail')
    g.add_argument('--animfile', help='animfile id or path instead of a proto')
    ap.add_argument('--lgt', default=DEFAULT_LGT, help='lighting set (default %(default)s)')
    ap.add_argument('--refl-max', type=int, default=DEFAULT_REFL_MAX, help='largest reflection-cube mip kept (px)')
    ap.add_argument('--out-root', help='bundle root (default: the viewer cache; a repository is refused)')
    ap.add_argument('--json', action='store_true', help='print the summary as JSON')
    a = ap.parse_args(argv)
    try:
        res = build_bundle(a.proto, a.animfile, lgt=a.lgt, refl_max_size=a.refl_max, out_root=a.out_root)
    except (C.RepoPathError, LookupError, ValueError) as e:
        print('error: %s' % e, file=sys.stderr)
        return 2
    s = res.summary()
    if a.json:
        sys.stdout.write(C.json_text(s))
    else:
        for k, v in s.items():
            print('%-14s %s' % (k, v))
    return 0


if __name__ == '__main__':
    sys.exit(main())
