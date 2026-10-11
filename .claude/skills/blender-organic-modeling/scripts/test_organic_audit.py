"""organic_audit.py on synthetic bodies built by fixture_bodies.py in background Blender; skips without Blender.

    python -B -m pytest .claude/skills/blender-organic-modeling/scripts -q -p no:cacheprovider

Blender comes from BLENDER, PATH or the standard install folder (blender_env.find_blender; set BLENDER when Blender
is named only in a local tool-path file). Every file goes to pytest's temp folder. Each seeded defect must fail
exactly its own check(s); the clean body must fail none; a missing or malformed input file exits 2 with SETUP ERROR
and no report, in the host form and in the direct Blender form.
"""
import json
import os
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import pytest

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import blender_env as E  # noqa: E402

BLENDER = E.find_blender()
pytestmark = pytest.mark.skipif(not BLENDER, reason='Blender not found (set BLENDER or put blender on PATH)')


def run_blender(script, args, timeout=600):
    return subprocess.run(E.blender_command(BLENDER, HERE / script, args), capture_output=True, text=True,
                          errors='replace', timeout=timeout)


def common(fx, ref):
    return ['--max-tris', '400', '--allowed-bones', '@' + str(fx / 'allowed.txt'), '--reference', str(ref)]


# name -> (fixture name or '{path key}', extra arguments, failed checks expected (None = see test), exit code)
CASES = {
    'clean': ('clean', ['--symmetry', 'body'], set(), 0),
    'clean_working': ('clean', ['--stage', 'working', '--symmetry', '*'], set(), 0),
    'over_budget': ('clean', ['--max-tris', '300'], {'triangle_budget'}, 1),
    'target_warn': ('clean', ['--target-tris', '300'], set(), 0),
    'vertex_budget': ('clean', ['--max-verts', '100'], {'vertex_budget'}, 1),
    'mean_influences': ('clean', ['--max-mean-influences', '1.45'], {'influence_mean'}, 1),
    'ngon': ('ngon', [], {'ngons'}, 1),
    'quads': ('quads', [], {'triangulated'}, 1),
    'quads_working': ('quads', ['--stage', 'working'], set(), 0),
    'five_influences': ('five_influences', [], {'influence_cap'}, 1),
    'unnormalized': ('unnormalized', [], {'weight_sums'}, 1),
    'tiny_weight': ('tiny_weight', [], {'clean_limit'}, 1),
    'neck_weight': ('neck_weight', [], {'allowed_bones', 'nondeform_weights'}, 1),
    'deform_flag': ('deform_flag', [], {'deform_flags'}, 1),
    'ref_object': ('ref_object', [], {'ref_objects'}, 1),
    'ref_object_working': ('ref_object', ['--stage', 'working'], set(), 0),
    'preserve_volume': ('preserve_volume', [], {'preserve_volume'}, 1),
    'bone_moved': ('bone_moved', [], {'donor_match'}, 1),
    'armature_moved': ('armature_moved', [], {'donor_match'}, 1),
    'asymmetric': ('asymmetric', ['--symmetry', 'body'], {'weight_symmetry'}, 1),
    'asymmetric_unchecked': ('asymmetric', [], set(), 0),
    'unpaired': ('unpaired', ['--symmetry', 'body'], {'weight_symmetry'}, 1),
    'unpaired_warn': ('unpaired', ['--symmetry', 'body', '--symmetry-unpaired', 'warn'], set(), 0),
    'unpaired_unchecked': ('unpaired', [], set(), 0),
    'side_suffix': ('side_suffix', [], None, 1),
    'empty_group': ('empty_group', [], {'group_hygiene'}, 1),
    'helper_group': ('helper_group', [], {'group_hygiene'}, 1),
    'unweighted': ('unweighted', [], {'unweighted'}, 1),
    'unbound': ('unbound', ['--mesh', 'body'], {'armature_binding'}, 1),
    'unbound_no_mesh': ('unbound', [], None, 2),
    'mesh_bones_full': ('clean', ['--mesh-bones', 'body=@{allowed}'], set(), 0),
    'mesh_bones_narrow': ('clean', ['--mesh-bones', 'body=Bip01_Pelvis,Bip01_Spine'], {'allowed_bones'}, 1),
    'quantized_good': ('clean', ['--quantized-json', '{good}'], set(), 0),
    'quantized_bad': ('clean', ['--quantized-json', '{bad}'], {'quantized_255'}, 1),
    # input files that are missing or malformed: exit 2, SETUP ERROR, no report
    'missing_reference': ('clean', ['--reference', '{missing}'], None, 2),
    'not_a_reference': ('clean', ['--reference', '{good}'], None, 2),
    'missing_allowed': ('clean', ['--allowed-bones', '@{missing}'], None, 2),
    'broken_allowed_json': ('clean', ['--allowed-bones', '@{broken}'], None, 2),
    'broken_quantized': ('clean', ['--quantized-json', '{broken}'], None, 2),
    'malformed_quantized': ('clean', ['--quantized-json', '{malformed}'], None, 2),
    'not_a_blend': ('{fake_blend}', [], None, 2),
    'mesh_bones_outside_union': ('clean', ['--mesh-bones', 'body=Bip01_Neck'], None, 2),
    'mesh_bones_unknown_mesh': ('clean', ['--mesh-bones', 'robe=Bip01_Pelvis'], None, 2),
}
# setup-error case -> the text its SETUP ERROR line must name
SETUP_TEXT = {'missing_reference': '--reference', 'not_a_reference': '--reference',
              'missing_allowed': '--allowed-bones', 'broken_allowed_json': '--allowed-bones',
              'broken_quantized': '--quantized-json', 'malformed_quantized': '--quantized-json',
              'not_a_blend': 'cannot open', 'unbound_no_mesh': 'no mesh bound',
              'mesh_bones_outside_union': '--mesh-bones', 'mesh_bones_unknown_mesh': '--mesh-bones'}


@pytest.fixture(scope='module')
def results(tmp_path_factory):
    fx = tmp_path_factory.mktemp('organic_fixtures')
    r = run_blender('fixture_bodies.py', [fx])
    assert r.returncode == 0, r.stdout[-3000:] + r.stderr[-3000:]
    manifest = json.loads((fx / 'fixtures.json').read_text(encoding='utf-8'))
    ref = fx / 'donor_ref.json'
    r = run_blender('organic_audit.py', ['--blend', manifest['clean']['file'], '--write-reference', ref])
    assert r.returncode == 0 and ref.is_file(), r.stdout[-3000:] + r.stderr[-3000:]
    (fx / 'good.json').write_text(json.dumps({'vertices': [[['A', 200], ['B', 55]], [['A', 255]]]}), encoding='utf-8')
    (fx / 'bad.json').write_text(json.dumps({'meshes': {'body': [[['A', 200], ['B', 54]], [['A', 0], ['B', 255]],
                                                                  [['A', 100], ['A', 155]]]}}), encoding='utf-8')
    (fx / 'broken.json').write_text('{"bones": ["Bip01_Pelvis", ', encoding='utf-8')
    (fx / 'malformed.json').write_text(json.dumps({'vertices': [[['A', 255]], [['A']]]}), encoding='utf-8')
    (fx / 'fake.blend').write_text('not a blend file', encoding='utf-8')
    paths = {'good': fx / 'good.json', 'bad': fx / 'bad.json', 'broken': fx / 'broken.json',
             'malformed': fx / 'malformed.json', 'missing': fx / 'no_such_file.json', 'fake_blend': fx / 'fake.blend',
             'allowed': fx / 'allowed.txt'}

    def one(name):
        file, extra, _, _ = CASES[name]
        extra = [x.format(**paths) for x in extra]
        blend = file.format(**paths) if file.startswith('{') else manifest[file]['file']
        report = fx / ('report_%s.json' % name)
        args = ['--blend', blend] + common(fx, ref) + extra + ['--report', report]
        r = run_blender('organic_audit.py', args)
        data = json.loads(report.read_text(encoding='utf-8')) if report.is_file() else None
        return name, (r.returncode, data, r.stdout + r.stderr)

    with ThreadPoolExecutor(max_workers=min(6, os.cpu_count() or 2)) as pool:
        out = dict(pool.map(one, CASES))
    out['_fx'], out['_manifest'], out['_ref'], out['_paths'] = fx, manifest, ref, paths
    return out


@pytest.mark.parametrize('name', sorted(CASES))
def test_each_defect_fails_its_own_check(results, name):
    code, report, log = results[name]
    _, _, expected, exit_code = CASES[name]
    assert code == exit_code, log[-3000:]
    if exit_code == 2:
        assert report is None, name
        line = next((x for x in log.splitlines() if x.startswith('SETUP ERROR')), '')
        assert SETUP_TEXT[name] in line and 'Traceback' not in log, log[-3000:]
        return
    if expected is not None:
        assert set(report['failed']) == expected, report['failed']


def test_unpaired_vertices_fail_symmetry_and_are_listed(results):
    _, report, _ = results['unpaired']
    row = next(c for c in report['checks'] if c['id'] == 'weight_symmetry')
    body = row['detail']['body']
    assert row['status'] == 'fail' and row['unpaired_vertices'] == 6 and row['unpaired_rule'] == 'fail'
    assert body['unpaired_vertices'] == 6 and len(body['first_unpaired']) == 6 and body['pairs_over_tol'] == 0
    _, report, _ = results['unpaired_warn']
    row = next(c for c in report['checks'] if c['id'] == 'weight_symmetry')
    assert row['status'] == 'warn' and row['unpaired_rule'] == 'warn'


def test_missing_reference_exits_2_in_every_form(results):
    clean, missing = results['_manifest']['clean']['file'], results['_paths']['missing']
    report = results['_fx'] / 'report_forms.json'
    args = ['--blend', str(clean), '--reference', str(missing), '--report', str(report)]
    forms = {
        'host': [sys.executable, str(HERE / 'organic_audit.py')] + args,
        'direct': E.blender_command(BLENDER, HERE / 'organic_audit.py', args),
        # the documented direct form minus --python-exit-code: the audit's own handler still exits 2
        'direct_bare': [BLENDER, '-b', '--factory-startup', '--python', str(HERE / 'organic_audit.py'), '--'] + args,
    }
    for form, cmd in forms.items():
        r = subprocess.run(cmd, capture_output=True, text=True, errors='replace', timeout=600,
                           env=dict(os.environ, BLENDER=BLENDER))
        assert r.returncode == 2 and 'SETUP ERROR' in r.stderr, (form, r.stdout[-1500:] + r.stderr[-1500:])
        assert '--reference' in r.stderr and not report.exists(), form


def test_unexpected_exception_exits_2_with_traceback(results):
    report = results['_fx'] / 'report_crash.json'
    nl = chr(10)
    code = nl.join(['import sys', 'sys.path.insert(0, %r)' % str(HERE), 'import organic_audit as A',
                    'def boom(a):', '    raise ZeroDivisionError("seeded crash")', 'A.audit = boom',
                    'sys.exit(A.main_blender(["--report", %r]))' % str(report)])
    r = subprocess.run([BLENDER, '-b', '--factory-startup', '--python-expr', code], capture_output=True, text=True,
                       errors='replace', timeout=600)
    assert r.returncode == 2, r.stdout[-1500:] + r.stderr[-1500:]
    assert 'Traceback' in r.stderr and 'seeded crash' in r.stderr and 'SETUP ERROR' in r.stderr
    assert not report.exists()


def test_host_form_finds_blender_from_its_options(results, tmp_path):
    clean = results['_manifest']['clean']['file']
    cfg = tmp_path / 'tool-paths.local.json'
    cfg.write_text(json.dumps({'tools': {'blender': {'path': BLENDER}}}), encoding='utf-8')
    wrong_env = dict(os.environ, BLENDER=str(tmp_path / 'no_blender.exe'))   # the options must win over BLENDER
    base = [sys.executable, str(HERE / 'organic_audit.py'), '--blend', clean]
    for option, value, name in (('--local-config', cfg, 'a.json'), ('--blender-exe', BLENDER, 'b.json')):
        r = subprocess.run(base + [option, str(value), '--report', str(tmp_path / name)], capture_output=True,
                           text=True, errors='replace', env=wrong_env, timeout=600)
        assert r.returncode == 0, (option, r.stdout[-1500:] + r.stderr[-1500:])
    r = subprocess.run(base + ['--blender-exe', str(tmp_path / 'missing.exe'), '--report', str(tmp_path / 'c.json')],
                       capture_output=True, text=True, errors='replace', env=dict(os.environ, BLENDER=BLENDER),
                       timeout=600)
    assert r.returncode == 2 and 'MISSING Blender' in r.stderr and not (tmp_path / 'c.json').exists()


def test_side_suffix_names_the_leftover_rename(results):
    _, report, _ = results['side_suffix']
    assert {'side_suffix', 'group_hygiene'} <= set(report['failed'])
    row = next(c for c in report['checks'] if c['id'] == 'side_suffix')
    assert row['value'] == ['Thigh.L']


def test_clean_body_reports_flip_name_blind_names(results):
    _, report, _ = results['clean']
    row = next(c for c in report['checks'] if c['id'] == 'mirror_names')
    assert row['status'] == 'info'
    assert 'Bip01_L_Thigh' in row['detail']['flip_name_blind']
    assert row['detail']['flip_name_mismatch'] == [] and row['detail']['partner_missing'] == []


def test_clean_body_symmetry_pairs_every_vertex(results):
    _, report, _ = results['clean']
    row = next(c for c in report['checks'] if c['id'] == 'weight_symmetry')
    sym = row['detail']['body']
    assert row['status'] == 'pass'
    assert sym['pairs'] > 0 and sym['unpaired_vertices'] == 0 and sym['max_weight_diff'] == 0.0


def test_target_overrun_is_a_warning(results):
    _, report, _ = results['target_warn']
    row = next(c for c in report['checks'] if c['id'] == 'triangle_budget')
    assert row['status'] == 'warn'


def test_counts_and_inputs_are_recorded(results):
    _, report, _ = results['clean']
    body = results['_manifest']['_body']
    assert report['counts']['total']['vertices'] == body['vertices']
    assert report['counts']['total']['triangles'] == body['triangles']
    assert report['counts']['total']['gpu_vertices_estimate'] >= body['vertices']
    assert len(report['file_sha256']) == 64 and report['units']['distances'] == 'armature-space units'


def test_quantized_file_issues_are_named(results):
    _, report, _ = results['quantized_bad']
    detail = next(c for c in report['checks'] if c['id'] == 'quantized_255')['detail']
    problems = [p for issue in detail['file_first_issues'] for p in issue['problems']]
    assert detail['file_vertices_with_issues'] == 3
    assert 'sum 254 != 255' in problems and 'influence at 0' in problems and 'bone twice' in problems


def test_mesh_bones_names_the_bones_outside_the_meshs_own_list(results):
    _, report, _ = results['mesh_bones_narrow']
    row = next(c for c in report['checks'] if c['id'] == 'allowed_bones')
    outside = row['value']['body']
    assert 'Bip01_Head' in outside and 'Bip01_Pelvis' not in outside and 'Bip01_Spine' not in outside
    assert report['mesh_bones'] == {'body': ['Bip01_Pelvis', 'Bip01_Spine']}
    deform = next(c for c in report['checks'] if c['id'] == 'deform_flags')
    assert deform['status'] == 'pass'                  # the deform flags are still checked against the union


def test_donor_reference_holds_every_bone(results):
    ref = json.loads(results['_ref'].read_text(encoding='utf-8'))
    assert ref['kind'] == 'armature-reference' and len(ref['bones']) == 16
    assert {'head_local', 'tail_local', 'matrix_local', 'parent'} <= set(ref['bones'][0])


def test_report_inside_a_git_work_tree_is_refused(results):
    target = HERE / 'refused_report.json'
    r = run_blender('organic_audit.py', ['--blend', results['_manifest']['clean']['file'], '--report', target])
    assert r.returncode == 2 and 'git work tree' in r.stderr
    assert not target.exists()


def test_host_python_relaunches_in_blender(results):
    env = dict(os.environ, BLENDER=BLENDER)
    report = results['_fx'] / 'report_host.json'
    r = subprocess.run([sys.executable, str(HERE / 'organic_audit.py'), '--blend',
                        results['_manifest']['clean']['file'], '--report', str(report)],
                       capture_output=True, text=True, errors='replace', env=env, timeout=600)
    assert r.returncode == 0, r.stdout[-2000:] + r.stderr[-2000:]
    assert json.loads(report.read_text(encoding='utf-8'))['result'] == 'pass'


def test_fixture_builder_without_a_folder_exits_2():
    r = subprocess.run([BLENDER, '-b', '--factory-startup', '--python', str(HERE / 'fixture_bodies.py')],
                       capture_output=True, text=True, errors='replace', timeout=300)
    assert r.returncode == 2 and 'usage' in r.stderr
