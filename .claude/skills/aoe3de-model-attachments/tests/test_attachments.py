"""aoe3de-model-attachments: attachment resolution, construction flag policy and the explicit-transform bone appender.
Synthetic cases need nothing but Python; the regression cases read this repo's git history (no game, no DLL)."""
import json, subprocess, sys
from pathlib import Path
import pytest

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / 'scripts'))
import attachment_check as AC  # noqa: E402

REPO = AC.REPO
ANIM = """<animfile>
  <definebone>bone_horse1</definebone>
  <submodel>built<component>LIVE<logic type="Destruction">
      <p1><assetreference type="GrannyModel"><file>x\\damaged</file></assetreference></p1>
      <p99><assetreference type="GrannyModel"><file>x\\intact</file></assetreference></p99></logic>
    <attach a="horse1" frombone="bone_master" tobone="bone_horse1" syncanims="1" /></component>
    <anim>Idle<component>LIVE</component><simskeleton><model>x\\damaged</model></simskeleton></anim>
  </submodel>
  <submodel>stage3<component>con<assetreference type="GrannyModel"><file>x\\con</file></assetreference></component></submodel>
  <component>b<logic type="BuildingCompletion"><p66><submodelref ref="stage3" /></p66><p100><submodelref ref="built" /></p100></logic></component>
</animfile>"""


def run(tmp_path, skeletons):
    art = tmp_path / 'art' / 'x'; art.mkdir(parents=True)
    for n in skeletons:
        (art / f'{n}.gr2').write_bytes(b'')
    f = tmp_path / 'a.xml'; f.write_text(ANIM)
    return AC.check(f, tmp_path / 'art', bones_of=lambda p: skeletons[p.stem])


def test_bone_only_in_the_intact_model_fails_through_the_simskeleton(tmp_path):
    rep = run(tmp_path, {'intact': ['BONE_MAIN', 'bone_horse1'], 'damaged': ['bone_master'], 'con': ['BONE_MAIN']})
    assert rep['status'] == 'FAIL'
    assert any('simskeleton' in f for f in rep['findings']) and any('model x\\damaged' in f for f in rep['findings'])


def test_bone_in_every_model_and_simskeleton_passes(tmp_path):
    rep = run(tmp_path, {'intact': ['BONE_MAIN', 'bone_horse1'], 'damaged': ['bone_master', 'bone_horse1'], 'con': ['BONE_MAIN']})
    assert rep['status'] == 'PASS'


def test_flag_bone_in_a_construction_stage_fails(tmp_path):
    rep = run(tmp_path, {'intact': ['bone_horse1'], 'damaged': ['bone_horse1'], 'con': ['BONE_MAIN', 'bone_flag_civ']})
    assert rep['status'] == 'FAIL' and any('construction stage stage3 (p66)' in f for f in rep['findings'])


def test_archive_models_are_reported_not_passed(tmp_path):
    f = tmp_path / 'a.xml'; f.write_text(ANIM)
    rep = AC.check(f, tmp_path / 'empty-art', bones_of=lambda p: [])
    assert all(r['status'].startswith('NOT CHECKED') for r in rep['rows'] if r.get('role') != 'definebone')


def git_blob(rev, path, out):
    r = subprocess.run(['git', '-C', str(REPO), 'show', f'{rev}:{path}'], capture_output=True)
    if r.returncode:
        pytest.skip(f'{rev}:{path} not in this clone')
    out.parent.mkdir(parents=True, exist_ok=True); out.write_bytes(r.stdout)


def test_installed_korean_stable_resolves_both_horses():
    rep = AC.check(REPO / 'art/zbench_korean_military/stable/korean_stable_physics.xml')
    assert rep['status'] == 'PASS'
    assert {r['tobone'] for r in rep['rows'] if r.get('role') == 'simskeleton'} == {'bone_horse1', 'bone_horse2'}


def test_regression_2026_10_08_stable_as_pushed_before_the_fix_fails(tmp_path):
    """b6e4344f: horse bones in the intact GR2 only -> both horses at the origin in game."""
    art = tmp_path / 'art'; d = 'zbench_korean_military/stable/'
    git_blob('b6e4344f', 'art/' + d + 'korean_stable_physics.gr2', art / d / 'korean_stable_physics.gr2')
    git_blob('b6e4344f', 'art/' + d + 'korean_stable_physics_damaged.gr2', art / d / 'korean_stable_physics_damaged.gr2')
    git_blob('b6e4344f', 'art/' + d + 'korean_stable_physics_con.gr2', art / d / 'korean_stable_physics_con.gr2')
    git_blob('b6e4344f', 'art/' + d + 'korean_stable_physics.xml', tmp_path / 'stable.xml')
    rep = AC.check(tmp_path / 'stable.xml', art)
    assert rep['status'] == 'FAIL' and sum('missing in' in f for f in rep['findings']) == 4
    assert sum('<definebone>' in f for f in rep['findings']) == 2


def test_regression_2026_10_08_construction_flag_bone_fails(tmp_path):
    """513928bd: the TC construction model still carried the donor's bone_flag_civ."""
    art = tmp_path / 'art'
    git_blob('513928bd', 'art/buildings/korean_tc/korean_tc_con.gr2', art / 'buildings/korean_tc/korean_tc_con.gr2')
    git_blob('513928bd', 'art/buildings/korean_tc/korean_tc.xml', tmp_path / 'tc.xml')
    rep = AC.check(tmp_path / 'tc.xml', art)
    assert rep['status'] == 'FAIL' and any('bone_flag_civ' in f for f in rep['findings'])


def test_add_bones_reproduces_the_stable_horse_fix_byte_for_byte(tmp_path):
    git_blob('b6e4344f', 'art/zbench_korean_military/stable/korean_stable_physics_damaged.gr2', tmp_path / 'old.gr2')
    table = [{'name': 'bone_horse1', 'parent': None, 'pos': [1.085, -3.42, 0.0], 'rot_blender': [[0, 1, 0], [-1, 0, 0], [0, 0, 1]], 'scale': 0.8},
             {'name': 'bone_horse2', 'parent': None, 'pos': [1.085, 0.02, 0.0], 'rot_blender': [[0, 1, 0], [-1, 0, 0], [0, 0, 1]], 'scale': 0.8}]
    (tmp_path / 't.json').write_text(json.dumps(table))
    subprocess.run([sys.executable, str(HERE.parent / 'scripts/add_bones.py'), str(tmp_path / 'old.gr2'), str(tmp_path / 't.json'),
                    str(tmp_path / 'new.gr2'), '--from-blender'], check=True, capture_output=True)
    fixed = REPO / 'art/zbench_korean_military/stable/korean_stable_physics_damaged.gr2'
    assert (tmp_path / 'new.gr2').read_bytes() == fixed.read_bytes()


ANIM_LOWPOLY = r"""<animfile>
  <definebone>bone_horse1</definebone>
  <component>LIVE<logic type="LowPoly">
      <normal>
        <logic type="Destruction">
          <p1><assetreference type="GrannyModel"><file>x\damaged</file></assetreference></p1>
          <p99><assetreference type="GrannyModel"><file>x\intact</file></assetreference></p99></logic>
        <attach a="horse1" frombone="bone_master" tobone="BONE_HORSE1" syncanims="1" />
      </normal>
      <lowpoly><assetreference type="GrannyModel"><file>x\lp</file></assetreference></lowpoly></logic>
    <attach a="scaffold" frombone="ATTACHPOINT" tobone="ATTACHPOINT" syncanims="0" />
  </component>
  <anim>Idle<component>LIVE</component><simskeleton><model>x\damaged</model></simskeleton></anim>
</animfile>"""


def run_lowpoly(tmp_path, skeletons):
    art = tmp_path / 'art' / 'x'; art.mkdir(parents=True)
    for n in skeletons:
        (art / f'{n}.gr2').write_bytes(b'')
    f = tmp_path / 'lp.xml'; f.write_text(ANIM_LOWPOLY)
    return AC.check(f, tmp_path / 'art', bones_of=lambda p: skeletons[p.stem])


def test_an_attach_in_the_lowpoly_normal_branch_does_not_need_the_bone_in_the_lowpoly_model(tmp_path):
    """vanilla stables.xml: horse attaches sit in <normal>; lp_*_stables models carry no horse bones."""
    rep = run_lowpoly(tmp_path, {'intact': ['bone_horse1'], 'damaged': ['bone_horse1'], 'lp': ['root']})
    assert rep['status'] == 'PASS' and not any(r.get('ref') == r'x\lp' for r in rep['rows'])


def test_bone_names_compare_case_insensitively_and_attachpoint_is_engine_provided(tmp_path):
    rep = run_lowpoly(tmp_path, {'intact': ['bone_horse1'], 'damaged': ['Bone_Horse1'], 'lp': []})
    assert rep['status'] == 'PASS'
    assert not any((r.get('tobone') or '').upper() == 'ATTACHPOINT' for r in rep['rows'])


def test_the_normal_branch_still_needs_the_bone_in_its_damaged_simskeleton(tmp_path):
    rep = run_lowpoly(tmp_path, {'intact': ['bone_horse1'], 'damaged': ['root'], 'lp': []})
    assert rep['status'] == 'FAIL' and any('simskeleton' in f for f in rep['findings'])


def test_an_undeclared_custom_bone_fails_even_when_every_model_has_it(tmp_path):
    art = tmp_path / 'art' / 'x'; art.mkdir(parents=True)
    for n in ('intact', 'damaged', 'con'):
        (art / f'{n}.gr2').write_bytes(b'')
    f = tmp_path / 'a.xml'; f.write_text(ANIM.replace('<definebone>bone_horse1</definebone>', ''))
    rep = AC.check(f, tmp_path / 'art', bones_of=lambda p: {'intact': ['bone_horse1'], 'damaged': ['bone_horse1'], 'con': []}[p.stem])
    assert rep['status'] == 'FAIL' and len(rep['findings']) == 1 and '<definebone>' in rep['findings'][0]


def test_engine_tags_need_no_declaration():
    assert not any(AC.needs_definebone(b) for b in ('ATTACHPOINT', 'ROOT', 'MASTER', 'HEAD', 'PROP1', 'R HAND', 'Bip01 L ForeArm'))
    assert AC.needs_definebone('bone_horse1') and AC.needs_definebone('bone_prop')


def test_regression_2026_10_08_stable_with_damaged_bones_but_no_definebone_fails(tmp_path):
    """cc76b0ac: bones in the intact AND damaged GR2, horses still at the origin in game - no <definebone>."""
    art = tmp_path / 'art'; d = 'zbench_korean_military/stable/'
    for n in ('korean_stable_physics.gr2', 'korean_stable_physics_damaged.gr2', 'korean_stable_physics_con.gr2'):
        git_blob('cc76b0ac', 'art/' + d + n, art / d / n)
    git_blob('cc76b0ac', 'art/' + d + 'korean_stable_physics.xml', tmp_path / 'stable.xml')
    rep = AC.check(tmp_path / 'stable.xml', art)
    assert rep['status'] == 'FAIL' and len(rep['findings']) == 2 and all('<definebone>' in f for f in rep['findings'])
