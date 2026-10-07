"""Shared mod dependencies remain distinct from newly owned atlas pages."""
import copy
import hashlib
import json
import struct
import os
import subprocess
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import gr2_lint as L


def fixture(tmp_path, monkeypatch):
    art = tmp_path / 'art'
    art.mkdir()
    maps = [('own', 'BaseColor', 2048), ('tc', 'BaseColor', 512), ('tc', 'Normals', 512)]
    files = []
    subs = []
    for name, channel, size in maps:
        path = art / f'{name}_{channel}.ddt'
        path.write_bytes(b'RTS3' + bytes([0, 0, 1, 12]) + struct.pack('<II', size, size) + bytes(16))
        subs.append(f'<submaterial name="{name}_{channel}"><materialdef name="default"/><parameters>'
                    f'<texture name="{channel}" override="{name}_{channel}"/></parameters></submaterial>')
        if name == 'tc':
            files.append(dict(path=path.name, sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
                              width=size, height=size))
    mat = art / 'fake.material'
    mat.write_bytes(('<material>\r\n' + '\r\n'.join(subs) + '\r\n</material>\r\n').encode())
    store = tmp_path / 'owner.json'
    store.write_text(json.dumps({'messages': {'d': {'items': [
        {'id': 'class', 'text': 'The fake building is small.'},
        {'id': 'share', 'text': 'The fake building can reuse shared TC textures.'}]}}}))
    monkeypatch.setattr(L, 'owner_message_store', lambda prof: store)
    prof = dict(names=['fake'], texture_budget=dict(class_='small'),
                _texture_budget={'classes': {'small': {'ceiling': [2048]}}})
    prof['texture_budget'] = {'class': 'small', 'confirmed_by': 'class', 'models': ['fake'],
                             'shared_mod_dependencies': [dict(source_names=['TC'], confirmed_by='share', files=files)]}
    return art, mat, prof


def check(art, mat, prof):
    return L.check_texture_budget('intact', mat, art, prof, 'fake')


def test_exact_dependency_excludes_all_channels_and_unlisted_copy_counts(tmp_path, monkeypatch):
    art, mat, prof = fixture(tmp_path, monkeypatch)
    r = check(art, mat, prof)
    assert r['status'] == 'PASS', r
    assert r['data']['counted'] == 1 and r['data']['own_files'] == 1
    assert len(r['data']['shared_mod_dependencies']) == 2
    (art / 'copy_BaseColor.ddt').write_bytes((art / 'tc_BaseColor.ddt').read_bytes())
    mat.write_bytes(mat.read_bytes().replace(b'tc_BaseColor"', b'copy_BaseColor"'))
    r = check(art, mat, prof)
    assert r['status'] == 'FAIL' and r['data']['counted'] == 2


@pytest.mark.parametrize('mutation', ['hash', 'dimensions', 'authorization', 'source', 'target', 'traversal', 'empty'])
def test_invalid_dependency_fails_closed(tmp_path, monkeypatch, mutation):
    art, mat, prof = fixture(tmp_path, monkeypatch)
    dep = prof['texture_budget']['shared_mod_dependencies'][0]
    if mutation == 'hash':
        (art / 'tc_BaseColor.ddt').write_bytes((art / 'tc_BaseColor.ddt').read_bytes() + b'changed')
    elif mutation == 'dimensions': dep['files'][0]['width'] = 1024
    elif mutation == 'authorization': dep['confirmed_by'] = 'class'
    elif mutation == 'source': dep['source_names'] = ['unrelated']
    elif mutation == 'target': prof['names'] = ['unrelated']; prof['texture_budget']['models'] = ['unrelated']
    elif mutation == 'traversal': dep['files'][0]['path'] = '../elsewhere.ddt'
    elif mutation == 'empty': dep['files'] = []
    assert check(art, mat, prof)['status'] == 'FAIL'


def test_dependency_scope_does_not_hide_other_stage_or_channel(tmp_path, monkeypatch):
    art, mat, prof = fixture(tmp_path, monkeypatch)
    damaged = art / 'fake_damaged.material'
    (art / 'extra_Normals.ddt').write_bytes((art / 'own_BaseColor.ddt').read_bytes())
    (art / 'extra2_Normals.ddt').write_bytes((art / 'own_BaseColor.ddt').read_bytes())
    damaged.write_bytes(b'<material>\r\n<submaterial name="a"><parameters>'
                       b'<texture name="Normals" override="extra_Normals"/></parameters></submaterial>'
                       b'<submaterial name="b"><parameters><texture name="Normals" override="extra2_Normals"/>'
                       b'</parameters></submaterial>\r\n</material>\r\n')
    r = L.check_texture_budget('intact', mat, art, prof, 'fake', materials=[damaged])
    assert r['status'] == 'FAIL' and r['data']['counted'] == 2


def test_absent_declaration_preserves_counting(tmp_path, monkeypatch):
    art, mat, prof = fixture(tmp_path, monkeypatch)
    prof['texture_budget'].pop('shared_mod_dependencies')
    r = check(art, mat, prof)
    assert r['status'] == 'FAIL' and r['data']['counted'] == 2


def test_pinned_chat_evidence_without_fabricated_message_id(tmp_path, monkeypatch):
    art, mat, prof = fixture(tmp_path, monkeypatch)
    dep = prof['texture_budget']['shared_mod_dependencies'][0]
    dep.pop('confirmed_by')
    evidence = {'authority': 'owner', 'kind': 'recorded_owner_chat', 'purpose': 'shared_mod_dependencies',
                'source_citation': 'Owner chat, exact quoted instruction', 'owner_quote': 'Reuse TC textures.',
                'models': ['fake'], 'source_names': ['TC']}
    path = tmp_path / 'approval.json'
    path.write_text(json.dumps(evidence))
    dep['authorization'] = dict(kind='recorded_owner_chat', path=str(path),
                               sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
                               owner_quote=evidence['owner_quote'])
    assert check(art, mat, prof)['status'] == 'PASS'
    wrong = copy.deepcopy(prof)
    wrong['texture_budget']['shared_mod_dependencies'][0]['authorization']['owner_quote'] = 'yes'
    assert check(art, mat, wrong)['status'] == 'FAIL'
    evidence['models'] = ['other']
    path.write_text(json.dumps(evidence))
    dep['authorization']['sha256'] = hashlib.sha256(path.read_bytes()).hexdigest()
    assert check(art, mat, prof)['status'] == 'FAIL'


def test_budget_exclusion_does_not_exclude_density_groups(tmp_path, monkeypatch):
    import numpy as np
    art, mat, prof = fixture(tmp_path, monkeypatch)
    assert check(art, mat, prof)['status'] == 'PASS'
    mesh = dict(groups=[(0, 0, 1)], mats=['tc_BaseColor'], tris=np.array([[0, 1, 2]]),
                pos=np.array([[0., 0, 0], [1, 0, 0], [0, 1, 0]]), uv=np.zeros((3, 2)))
    groups = L.density_groups({'render': [mesh]}, mat, art)
    assert len(groups) == 1 and groups[0]['page'] == 'tc_BaseColor'
    assert np.count_nonzero(groups[0]['UV']) == 0


def directory_link(link, target):
    if os.name == 'nt':
        subprocess.run(['cmd', '/c', 'mklink', '/J', str(link), str(target)], check=True, capture_output=True)
    else:
        link.symlink_to(target, target_is_directory=True)


def test_staging_junction_requires_exact_canonical_root_and_relative_resource(tmp_path, monkeypatch):
    art, mat, prof = fixture(tmp_path, monkeypatch)
    canonical = tmp_path/'canonical_art'; target=canonical/'tc'; target.mkdir(parents=True)
    for path in art.glob('tc_*.ddt'):
        (target/path.name).write_bytes(path.read_bytes())
    directory_link(art/'borrowed',target)
    mat.write_bytes(mat.read_bytes().replace(b'override="tc_',b'override="borrowed/tc_'))
    dep=prof['texture_budget']['shared_mod_dependencies'][0]
    for item in dep['files']:item['path']='borrowed/'+item['path']
    # Outside stage is rejected with no canonical root, and with a different relative name.
    assert check(art,mat,prof)['status']=='FAIL'
    prof['texture_budget']['shared_mod_canonical_art_root']=str(canonical)
    assert check(art,mat,prof)['status']=='FAIL'
    directory_link(canonical/'borrowed',target)
    assert check(art,mat,prof)['status']=='PASS'
    prof['texture_budget']['shared_mod_canonical_art_root']=str(tmp_path/'unrelated')
    assert check(art,mat,prof)['status']=='FAIL'
