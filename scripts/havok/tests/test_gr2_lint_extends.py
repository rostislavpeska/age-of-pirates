"""A separate mod's lint profile file: inherits the owner's texture classes, never redefines them, and resolves its
relative evidence paths from its own repository (the Koreans add-on keeps its building profiles there)."""
import json
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import gr2_lint as L


def mod_repo(tmp_path, doc):
    repo = tmp_path / 'mod'
    (repo / '.git').mkdir(parents=True)
    (repo / 'tools' / 'lint').mkdir(parents=True)
    path = repo / 'tools' / 'lint' / 'profiles.json'
    path.write_text(json.dumps(doc), encoding='utf-8')
    return repo, path


def test_extends_inherits_the_owner_classes_and_tools(tmp_path):
    base = L.load_profiles()
    repo, path = mod_repo(tmp_path, {'extends': 'gr2_lint_profiles.json',
                                     'tools': {'owner_messages': 'tools/lint/owner.json'},
                                     'profiles': {'house': {'texture_budget': {'class': 'large'}}}})
    doc = L.load_profiles(path)
    assert doc['texture_budget'] == base['texture_budget']
    assert doc['tools']['gr2_to_raw_dir'] == base['tools']['gr2_to_raw_dir']
    assert doc['tools']['owner_messages'] == 'tools/lint/owner.json'
    assert Path(doc['_root']) == repo.resolve()
    prof = L.resolve_profile(doc, 'house')
    assert prof['_texture_budget']['classes'] == base['texture_budget']['classes']
    assert L.owner_message_store(prof) == repo.resolve() / 'tools/lint/owner.json'


def test_an_extending_file_cannot_redefine_the_classes(tmp_path):
    _, path = mod_repo(tmp_path, {'extends': 'gr2_lint_profiles.json',
                                  'texture_budget': {'classes': {'small': {'ceiling': [4096]}}}, 'profiles': {}})
    with pytest.raises(ValueError, match='texture_budget'):
        L.load_profiles(path)


@pytest.mark.parametrize('name', ['../havok/gr2_lint_profiles.json', 'missing.json'])
def test_extends_names_a_profile_file_next_to_the_lint(tmp_path, name):
    _, path = mod_repo(tmp_path, {'extends': name, 'profiles': {}})
    with pytest.raises(ValueError, match='extends'):
        L.load_profiles(path)


def test_aop_profiles_keep_their_root(tmp_path):
    doc = L.load_profiles()
    assert Path(doc['_root']) == L.HERE.parents[1]
    prof = dict(_root=doc['_root'])
    assert L.profile_path(prof, 'config/x.json')[0] == L.HERE.parents[1] / 'config/x.json'
    assert L.profile_path({}, 'config/x.json')[0] == Path('config/x.json')        # a profile from no file: as before

