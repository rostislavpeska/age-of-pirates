"""aoe-xml material_source.py: a retexture keeps its source's materialdef (what the BaseColor alpha does).

Owner's game tests 2026-10-09: the Gakgung Archer's cards drew solid - right alpha, but one default_doublesided for the
whole unit where vanilla changdao_1/2 are default_doublesided_cutout. The check must catch that by both routes (a vanilla
map the material names, the alpha fingerprint of a mod BaseColor) and stay quiet on correct materials."""
import importlib.util
import os
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[3]
BS = chr(92)


def _ms():
    spec = importlib.util.spec_from_file_location('material_source', REPO / '.claude/skills/aoe-xml/scripts/material_source.py')
    ms = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(ms)
    return ms


def test_alpha_use_kinds():
    ms = _ms()
    assert [ms.alpha_use(d) for d in ('default_doublesided_cutout', 'default_cutout', 'destructible_doublesided_cutout',
                                      'speedtree' + BS + 'tree_subsurface')] == ['cut'] * 4
    assert [ms.alpha_use(d) for d in ('default', 'default_doublesided', 'destructible', 'destructible_doublesided')] == ['ignore'] * 4
    assert ms.alpha_use('alphablend_scroll_v2') == 'blend'
    assert ms.alpha_use('default_emissive_advanced') == 'other'      # unproven: never an ERROR


@pytest.fixture(scope='module')
def facts():
    ms = _ms()
    return ms, ms.load_index()


def _material(root, name, md, base):
    p = Path(root) / 'art' / 'units' / 'x' / (name + '.material')
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_bytes(('<material>\r\n  <submaterial name="mata">\r\n    <materialdef name="%s" />\r\n    <parameters>\r\n'
                   '      <texture name="BaseColor" override="%s" />\r\n    </parameters>\r\n  </submaterial>\r\n'
                   '</material>\r\n' % (md, base)).encode())
    return str(p)


@pytest.mark.local('steam')
def test_vanilla_changdao_defs_differ_per_age(facts):
    ms, data = facts
    defs = {m.rsplit('/', 1)[1]: d for m, sub, d, tex in data['subs'] if m.startswith('units/asians/chinese/changdao/changdao_')}
    assert (defs['changdao_0'], defs['changdao_1'], defs['changdao_2']) == (
        'default_doublesided', 'default_doublesided_cutout', 'default_doublesided_cutout')
    cut = data['base']['units/asians/chinese/changdao/textures/changdao_0_mata_basecolor']['cut']
    assert cut > 0.05                                    # age 0 cuts out texels, yet its def ignores the alpha


@pytest.mark.local('steam')
def test_a_vanilla_basecolor_under_the_wrong_def_fails(facts, tmp_path):
    ms, data = facts
    base = BS.join(['units', 'asians', 'chinese', 'changdao', 'textures', 'changdao_1_mata_BaseColor'])
    errors, _ = ms.check_file(_material(tmp_path, 'wrong', 'default_doublesided', base), str(tmp_path), data)
    assert len(errors) == 1 and 'changdao_1' in errors[0] and 'default_doublesided_cutout' in errors[0]
    assert ms.check_file(_material(tmp_path, 'right', 'default_doublesided_cutout', base), str(tmp_path), data) == ([], [])


@pytest.mark.local('steam')
def test_a_retextured_basecolor_is_traced_by_its_alpha(facts, tmp_path):
    """The Gakgung age 2 case: every map the mod's own, the source found by the BaseColor's cut-out mask."""
    ms, data = facts
    import bartool
    idx = bartool.build_index(bartool.find_game_dir())
    ddt = tmp_path / 'art' / 'units' / 'x' / 'textures' / 'x_mata_BaseColor.ddt'
    ddt.parent.mkdir(parents=True)
    ddt.write_bytes(bartool.read_entry(idx['art/units/asians/chinese/changdao/textures/changdao_2_mata_basecolor.ddt']))
    own = BS.join(['units', 'x', 'textures', 'x_mata_BaseColor'])
    errors, _ = ms.check_file(_material(tmp_path, 'wrong', 'default_doublesided', own), str(tmp_path), data)
    assert len(errors) == 1 and 'changdao_2' in errors[0] and 'alpha matches' in errors[0]
    assert ms.check_file(_material(tmp_path, 'right', 'default_doublesided_cutout', own), str(tmp_path), data) == ([], [])


@pytest.mark.local('steam')
def test_aop_materials_have_no_new_finding(facts):
    """Every AoP material passes; the first sweep's findings (KNOWN, reported 2026-10-10) only warn."""
    ms, data = facts
    errors, known = [], 0
    for d, _, fs in os.walk(REPO / 'art'):
        for f in fs:
            if f.lower().endswith('.material'):
                e, w = ms.check_file(os.path.join(d, f), str(REPO), data)
                errors += e
                known += sum(m.startswith('KNOWN') for m in w)
    assert errors == []
    assert known == len(ms.KNOWN)                        # a fixed KNOWN entry leaves the list
