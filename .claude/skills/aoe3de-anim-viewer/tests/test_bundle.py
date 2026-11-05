"""aoe3de-anim-viewer bundle writer (scripts/bundle.py): the M1 modules wired into manifest.json + binary buffers.

    python -m pytest .claude/skills/aoe3de-anim-viewer/tests/test_bundle.py -q        # CI: add -m "not local"

CI-safe: the synthetic mounted unit of av_unit_fixture (one mod folder of a fake profile, no game layer); every
buffer view is read back and checked against the sources. Owner's machine (local marker): the vanilla Iron Flail
(ypIronFlail) end to end. Bundles go to pytest's temp folder; a repository target is refused.
"""
import sys
from pathlib import Path

import numpy as np
import pytest

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / 'scripts'))
sys.path.insert(0, str(HERE))
import av_common as C  # noqa: E402
try:
    import gr2_model as GM  # noqa: E402
except ImportError as e:                       # no consumer GR2 reader (a public export)
    pytest.skip(str(e), allow_module_level=True)
import bundle as B  # noqa: E402
import av_unit_fixture as UF  # noqa: E402


@pytest.fixture
def unit(tmp_path, monkeypatch):
    monkeypatch.setenv(C.CACHE_ENV, str(tmp_path / 'cache'))
    u = UF.write_unit(tmp_path)
    res = B.build_bundle(animfile=u['horse'], fs=UF.vfs(u), out_root=tmp_path / 'bundles', lighting=False,
                         log=lambda m: None)
    return u, res


def buffers(res):
    return {b['id']: (res.folder / b['uri']).read_bytes() for b in res.manifest['buffers']}


def test_manifest_top_level_and_buffers(unit):
    u, res = unit
    m = res.manifest
    assert m['schema'] == C.SCHEMA_NAME and m['schema_version'] == C.SCHEMA_VERSION
    assert m['bundle_id'] == res.bundle_id == res.folder.name and len(res.bundle_id) == 16
    assert m['bundle_id'] == C.cache_key(*m['inputs'])
    assert m['subject'] == {'kind': 'animfile', 'proto': None, 'animfile': u['horse']}
    for key in ('conventions', 'layers', 'provenance', 'warnings', 'logic', 'composition', 'animfiles', 'models',
                'materials', 'textures', 'clips', 'proto', 'tactics', 'timing', 'lighting', 'fidelity', 'oracles'):
        assert key in m, key
    assert m['oracles'] == {'precomp': None} and m['proto'] is None and m['tactics'] is None
    assert [lay['id'] for lay in m['layers']] == ['mod:synthetic-mod']
    data = buffers(res)
    for b in m['buffers']:
        assert len(data[b['id']]) == b['byteLength'] and C.sha256_bytes(data[b['id']]) == b['sha256']
    assert set(data) == {'geo', 'anim', 'tex'}                    # no lighting asked: no 'light' buffer
    assert sorted(p.name for p in res.folder.iterdir()) == sorted(['manifest.json'] + [b['uri'] for b in m['buffers']])
    assert set(m['fidelity']['stages']) >= {'skinning', 'pose', 'curve_sampling', 'material', 'rider_sync', 'timing'}
    assert m['fidelity']['stages']['rider_sync'] == 'H' and m['fidelity']['stages']['material'] == 'M'   # M3 shader
    assert m['fidelity']['shader_model'] == 'v1' and m['fidelity']['viewer'] == 'm3' and m['tool']['shader_model'] == 'v1'
    assert len(m['content_sha256']) == 64


def test_every_view_reads_back_its_source(unit):
    u, res = unit
    m, data = res.manifest, buffers(res)
    views = []

    def walk(x):
        if isinstance(x, dict):
            if {'buffer', 'byteOffset', 'byteLength', 'dtype'} <= set(x):
                views.append(x)
            for v in x.values():
                walk(v)
        elif isinstance(x, list):
            for v in x:
                walk(v)
    walk({k: m[k] for k in ('models', 'clips', 'textures')})
    assert views
    for v in views:
        assert v['byteOffset'] % C.BUFFER_ALIGN == 0
        assert C.read_view(data[v['buffer']], v).size == v['count'] * v['components']
    horse = GM.read_model(Path(u['mod']) / 'art' / u['horse_model'])
    rec = m['models'][u['horse_model']]
    pos = C.read_view(data['geo'], rec['meshes'][0]['streams']['Position']['view'])
    assert np.array_equal(pos, horse.meshes[0].streams['Position'])
    assert [b['name'] for b in rec['skeleton']['bones']] == [b['name'] for b in horse.bones]
    assert rec['meshes'][0]['bone_bindings'][1] == {'name': 'horse spine', 'bone': 1}     # engine name rule
    tex = m['textures'][u['textures'][0]]
    assert tex['decodable'] and tex['bc'] == 'BC1' and [x['width'] for x in tex['mips']] == [16, 8, 4]
    assert tex['uses'] == [{'material': u['rider_model'][:-4] + '.material#mata', 'slot': 'BaseColor', 'srgb': True}]


def test_composition_timing_and_warnings(unit):
    u, res = unit
    m = res.manifest
    comp = m['composition']
    assert comp['main'] == u['horse'] and comp['pairing']['child'] == u['rider']
    assert comp['pairing']['status'] == 'hypothesis' and comp['pairing']['durations_known']
    assert {(c['animfile'], c['scope'], c['attach']['syncanims']) for c in comp['children']} == \
        {(u['rider'], 'component', True), (u['torch'], 'anim', False)}
    assert [o['anim'] for o in comp['pairing']['one_sided']] == ['Highstep']
    clips = m['clips']
    assert clips[u['clips']['horse_attack']]['duration'] == pytest.approx(1.0)
    assert round(clips[u['clips']['horse_attack']]['fps_declared']) == 192
    codes = {w['code'] for w in m['warnings']}
    assert {'engine-bone-assumed', 'anim-one-sided', 'tag-overflow', 'material-file-missing'} <= codes
    assert all(w['layer'] in (None, 'mod:synthetic-mod') for w in m['warnings'])
    assert m['timing']['status'] == 'hypothesis'
    s = res.summary()
    assert s['models'] == 3 and s['clips'] == 5 and s['textures'] == 2 and not s['unavailable']


def test_rebuild_keeps_the_id_and_replaces_the_folder(unit, tmp_path):
    u, res = unit
    (res.folder / 'stale.bin').write_bytes(b'old')
    again = B.build_bundle(animfile=u['horse'], fs=UF.vfs(u), out_root=tmp_path / 'bundles', lighting=False,
                           log=lambda m: None)
    assert again.bundle_id == res.bundle_id and not (res.folder / 'stale.bin').exists()
    assert again.manifest['content_sha256'] == res.manifest['content_sha256']
    listed = B.list_bundles(tmp_path / 'bundles')
    assert [x['bundle_id'] for x in listed] == [res.bundle_id]


def test_an_undecodable_model_is_kept_and_reported(tmp_path, monkeypatch):
    monkeypatch.setenv(C.CACHE_ENV, str(tmp_path / 'cache'))
    u = UF.write_unit(tmp_path)
    import gr2_synth as S
    (Path(u['mod']) / 'art' / u['torch_model']).write_bytes(
        S.build_model(UF.torch_bones(), [UF.rigid('torch_root')], compression=2))
    res = B.build_bundle(animfile=u['horse'], fs=UF.vfs(u), out_root=tmp_path / 'bundles', lighting=False,
                         log=lambda m: None)
    rec = res.manifest['models'][u['torch_model']]
    assert rec['decodable'] is False and rec['unavailable_reason'] == 'gr2-compressed-oodle1'
    assert any(w['code'] == 'gr2-compressed' and w['path'] == u['torch_model'] for w in res.manifest['warnings'])
    assert res.summary()['unavailable'] == {'models': [u['torch_model']]}


def test_a_repository_target_is_refused(tmp_path, monkeypatch):
    monkeypatch.setenv(C.CACHE_ENV, str(tmp_path / 'cache'))
    u = UF.write_unit(tmp_path)
    (tmp_path / 'repo' / '.git').mkdir(parents=True)
    with pytest.raises(C.RepoPathError):
        B.build_bundle(animfile=u['horse'], fs=UF.vfs(u), out_root=tmp_path / 'repo' / 'bundles', lighting=False,
                       log=lambda m: None)
    assert not (tmp_path / 'repo' / 'bundles').exists()
    with pytest.raises(ValueError):
        B.build_bundle(fs=UF.vfs(u), out_root=tmp_path / 'b', log=lambda m: None)


# ---------------------------------------------------------------- the vanilla Iron Flail (owner's machine)
@pytest.mark.local
def test_iron_flail_bundle_end_to_end(tmp_path, monkeypatch):
    monkeypatch.setenv(C.CACHE_ENV, str(tmp_path / 'cache'))
    import vfs as V
    fs = V.VFS()
    if not any(lay.kind == 'game' for lay in fs.layers):
        pytest.skip('no AoE3 DE install found')
    res = B.build_bundle(proto='ypIronFlail', fs=fs, out_root=tmp_path / 'bundles', log=lambda m: None)
    m = res.manifest
    horse, rider = 'units/asians/chinese/iron_flail/iron_flail.xml', 'units/asians/chinese/iron_flail/iron_flail_rider.xml'
    assert m['subject'] == {'kind': 'proto', 'proto': 'ypIronFlail', 'animfile': horse}
    assert m['layers'][-1]['id'] == 'game' and m['proto']['tactics_file'] == 'data/tactics/handcavalrysplash.tactics'
    clips = m['clips']
    horse_clips = {v['clip'] for a in m['animfiles'][horse]['anims'].values() for v in a['variants']}
    rider_clips = {v['clip'] for a in m['animfiles'][rider]['anims'].values() for v in a['variants']}
    assert len(horse_clips) == 32 and len(rider_clips) == 30
    assert all(clips[c]['decodable'] and 'K32fC32f' in clips[c]['formats'] for c in horse_clips | rider_clips)
    # the whip clips are quantized: kept, unavailable, reported (the whip is declared but never attached)
    assert res.summary()['unavailable'] == {'clips': ['units/cavalry/oprichnik/oprichnik_whip_attack_a.gr2',
                                                      'units/cavalry/oprichnik/oprichnik_whip_idle_a.gr2']}
    assert all(v['decodable'] for v in m['models'].values()) and len(m['models']) == 9
    assert all(v['decodable'] for v in m['textures'].values()) and len(m['textures']) >= 19
    pairs = m['composition']['pairing']['pairs']
    assert len(pairs) == 45 and 'Death_by_havoc' in m['composition']['pairing']['ragdoll']
    rows = {r['action']: r for r in m['timing']['actions']}
    assert rows['MeleeHandAttack']['rof_effective'] == 1.5 and rows['MeleeHandAttack']['rof_source'] == 'protoaction'
    assert m['lighting']['lgt']['name'] == 'Tantalus Viewer' and m['lighting']['tonemap_lut'] is not None
    assert m['lighting']['player_colors']
    assert m['lighting']['shader']['version'] == 'v1' and m['lighting']['envbrdf']['status'] == 'measured'
    presets = {p['name']: p for p in m['lighting']['presets']}                      # M3 lighting packs
    assert set(presets) == {'Tantalus Viewer', 'NewEngland_Skirmish'} and all(p['status'] == 'ok' for p in presets.values())
    codes = {w['code'] for w in m['warnings']}
    assert {'attachment-declared-not-attached', 'engine-bone-assumed', 'ragdoll-not-simulated',
            'curve-format-unsupported', 'anim-one-sided'} <= codes
