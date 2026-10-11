"""Pure tests (no Blender) for organic_weights.py and blender_env.py; run on any Python 3 with pytest.

    python -B -m pytest .claude/skills/blender-organic-modeling/scripts/test_organic_weights.py -q -p no:cacheprovider
"""
import json
import random
import sys
from pathlib import Path

import pytest

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import blender_env as E  # noqa: E402
import organic_weights as W  # noqa: E402


@pytest.mark.parametrize('weights', [
    [('a', 0.7), ('b', 0.1), ('c', 0.1), ('d', 0.1)],
    [('a', 1 / 3), ('b', 1 / 3), ('c', 1 / 3)],
    [('a', 0.5), ('b', 0.5)],
    [('a', 0.94), ('b', 0.02), ('c', 0.02), ('d', 0.02)],
    [('a', 0.6), ('b', 0.3)],            # unnormalized input is renormalized first
    [('a', 1.0)],
])
def test_quantize_sums_to_255_within_one_unit(weights):
    entries, dropped = W.quantize(weights)
    assert dropped == []
    assert W.check_quantized(entries) == []
    assert W.quantization_error(weights, entries) <= 1 / 255 + 1e-12


def test_quantize_drops_influences_below_half_a_unit():
    entries, dropped = W.quantize([('a', 0.999), ('b', 0.001)])
    assert entries == [('a', 255)] and dropped == ['b']


def test_quantize_never_leaves_a_kept_influence_at_zero():
    # d = 0.6/255 is kept (>= 0.5/255); the three 0.8 remainders win the 3 spare units, so d would end at 0
    weights = [('a', 84.8 / 255), ('b', 84.8 / 255), ('c', 84.8 / 255), ('d', 0.6 / 255)]
    entries, dropped = W.quantize(weights)
    assert dropped == [] and W.check_quantized(entries) == []
    assert dict(entries)['d'] == 1 and sorted(q for _, q in entries) == [1, 84, 85, 85]
    assert W.quantization_error(weights, entries) <= 1 / 255 + 1e-12


def test_quantize_error_stays_within_one_unit_when_every_influence_is_at_least_one_unit():
    # step 3 never acts when every kept influence is >= 1/255 (always true after a 0.02 clean limit)
    rng = random.Random(255)
    for _ in range(5000):
        n = rng.randint(1, 4)
        raw = [1 / 255 + rng.random() ** rng.choice((1, 3, 8)) for _ in range(n)]
        weights = [(chr(97 + i), w / sum(raw)) for i, w in enumerate(raw)]
        if min(w for _, w in weights) < 1 / 255:
            continue
        entries, dropped = W.quantize(weights)
        assert dropped == [] and W.check_quantized(entries) == []
        assert W.quantization_error(weights, entries) < 1 / 255


def test_quantize_step_3_can_cost_the_donor_more_than_one_unit():
    # 255 w = 117.555, 0.536, 136.384, 0.525: the 2 spare units go to a and b, d ends at 0 and takes 1 unit from c
    weights = [('a', 117.555 / 255), ('b', 0.536 / 255), ('c', 136.384 / 255), ('d', 0.525 / 255)]
    entries, dropped = W.quantize(weights)
    assert dropped == [] and W.check_quantized(entries) == []
    assert dict(entries) == {'c': 135, 'a': 118, 'b': 1, 'd': 1}
    assert 1 / 255 < W.quantization_error(weights, entries) < 2 / 255


def test_quantize_is_descending_and_deterministic():
    entries, _ = W.quantize([('b', 0.25), ('a', 0.25), ('c', 0.5)])
    assert entries[0][0] == 'c' and [b for b, _ in entries[1:]] == ['a', 'b']


@pytest.mark.parametrize('entries, problem', [
    ([('a', 200), ('b', 54)], 'sum 254 != 255'),
    ([('a', 255), ('b', 0)], 'influence at 0'),
    ([('a', 55), ('b', 200)], 'not descending'),
    ([('a', 155), ('a', 100)], 'bone twice'),
    ([], 'no influence'),
])
def test_check_quantized_names_each_problem(entries, problem):
    assert problem in W.check_quantized(entries)


@pytest.mark.parametrize('name, partner, side', [
    ('Bip01_L_Thigh', 'Bip01_R_Thigh', True),
    ('Bip01 R Calf', 'Bip01 L Calf', True),
    ('Thigh.L', 'Thigh.R', True),
    ('l_hand', 'r_hand', True),
    ('mixamorig:LeftArm', 'mixamorig:RightArm', True),
    ('Arm_Left', 'Arm_Right', True),
    ('Bip01_Spine1', 'Bip01_Spine1', False),
    ('Leftover', 'Leftover', False),
    ('Bip01_Pelvis', 'Bip01_Pelvis', False),
])
def test_mirror_name_swaps_side_tokens_anywhere(name, partner, side):
    assert W.mirror_name(name) == (partner, side)


def test_side_suffix_flags_temporary_blender_names():
    assert W.side_suffix('Thigh.L') and W.side_suffix('hand.r')
    assert not W.side_suffix('Bip01_L_Thigh') and not W.side_suffix('Bip01_Pelvis')


def test_parse_name_list_forms(tmp_path):
    assert W.parse_name_list('A, B ,C') == ['A', 'B', 'C']
    txt = tmp_path / 'bones.txt'
    txt.write_text('# allowed\nBip01_Pelvis\n\nBip01 L Thigh  # mid-name marker\n', encoding='utf-8')
    assert W.parse_name_list('@' + str(txt)) == ['Bip01_Pelvis', 'Bip01 L Thigh']
    js = tmp_path / 'bones.json'
    js.write_text(json.dumps({'bones': ['A', 'B']}), encoding='utf-8')
    assert W.parse_name_list('@' + str(js)) == ['A', 'B']
    assert W.parse_name_list(None) is None


def test_histogram_counts_vertices_per_influence_count():
    assert W.histogram([1, 2, 2, 4, 1, 1]) == {1: 3, 2: 2, 4: 1}


def test_output_inside_a_git_work_tree_is_refused(tmp_path):
    assert E.refuse_in_worktree(HERE / 'x.json') is not None or E.git_worktree(HERE) is None
    (tmp_path / 'repo' / '.git').mkdir(parents=True)
    assert 'git work tree' in E.refuse_in_worktree(tmp_path / 'repo' / 'out' / 'report.json')
    assert E.refuse_in_worktree(tmp_path / 'scratch' / 'report.json') is None


def test_blender_env_variable_must_name_a_file(monkeypatch, tmp_path):
    monkeypatch.setenv('BLENDER', str(tmp_path / 'missing_blender.exe'))
    assert E.find_blender() is None
    exe = tmp_path / 'blender.exe'
    exe.write_bytes(b'')
    monkeypatch.setenv('BLENDER', str(exe))
    assert E.find_blender() == str(exe)


def test_find_blender_order_explicit_then_local_config_then_environment(monkeypatch, tmp_path):
    env_exe, cfg_exe, cli_exe = (tmp_path / n for n in ('env_blender.exe', 'cfg_blender.exe', 'cli_blender.exe'))
    for exe in (env_exe, cfg_exe, cli_exe):
        exe.write_bytes(b'')
    cfg = tmp_path / 'tool-paths.local.json'
    cfg.write_text(json.dumps({'tools': {'blender': {'path': str(cfg_exe)}}}), encoding='utf-8')
    monkeypatch.setenv('BLENDER', str(env_exe))
    assert E.find_blender(str(cli_exe), str(cfg)) == str(cli_exe)
    assert E.find_blender(None, str(cfg)) == str(cfg_exe)
    assert E.find_blender() == str(env_exe)
    # a named path that is missing is "missing", never a silent fallback to the next source
    assert E.find_blender(str(tmp_path / 'nope.exe'), str(cfg)) is None
    cfg.write_text(json.dumps({'tools': {'blender': {'path': str(tmp_path / 'nope.exe')}}}), encoding='utf-8')
    assert E.find_blender(None, str(cfg)) is None
    # a config without a blender entry falls through to BLENDER
    cfg.write_text(json.dumps({'tools': {'photoshop': {'path': 'x'}}}), encoding='utf-8')
    assert E.find_blender(None, str(cfg)) == str(env_exe)


@pytest.mark.parametrize('content', ['{"tools": ', '[1, 2]', '{"tools": {"blender": {"path": 5}}}'])
def test_unreadable_local_config_is_an_error(tmp_path, content):
    cfg = tmp_path / 'tool-paths.local.json'
    cfg.write_text(content, encoding='utf-8')
    with pytest.raises(ValueError):
        E.find_blender(None, str(cfg))
    with pytest.raises(ValueError):
        E.find_blender(None, str(tmp_path / 'missing.json'))


def test_split_blender_args_takes_out_only_the_location_options():
    exe, cfg, rest = E.split_blender_args(['--blend', 'a.blend', '--blender-exe', 'B.exe', '--mesh', 'body',
                                           '--local-config=c.json', '--report', 'r.json'])
    assert (exe, cfg) == ('B.exe', 'c.json')
    assert rest == ['--blend', 'a.blend', '--mesh', 'body', '--report', 'r.json']
    assert E.split_blender_args(['--blend', 'x.blend']) == (None, None, ['--blend', 'x.blend'])


def test_blender_command_is_background_factory_startup():
    cmd = E.blender_command('blender', 'tool.py', ['--a', 1], blend='f.blend')
    assert cmd[:4] == ['blender', '-b', '--factory-startup', 'f.blend']
    assert cmd[cmd.index('--python-exit-code') + 1] == '2' and cmd[-3:] == ['--', '--a', '1']
