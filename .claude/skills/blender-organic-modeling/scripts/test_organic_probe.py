"""organic_probe.py reproduces the measured claims L1-L15 of references/sources.md; skips without Blender.

    python -B -m pytest .claude/skills/blender-organic-modeling/scripts -q -p no:cacheprovider

The full probe runs once (about 10 s) into pytest's temp folder. Qualitative claims are asserted on every Blender;
the exact numbers are asserted only on Blender 5.1, where they were first measured (2026-10-10).
"""
import json
import subprocess
import sys
from pathlib import Path

import pytest

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import blender_env as E  # noqa: E402
import organic_probe as P  # noqa: E402  (host import: bpy stays None)

BLENDER = E.find_blender()
needs_blender = pytest.mark.skipif(not BLENDER, reason='Blender not found (set BLENDER or put blender on PATH)')


def test_plan_pulls_in_the_experiments_whose_files_are_opened():
    assert P.plan(['shrinkwrap']) == ['rings', 'shrinkwrap']
    assert P.plan(['silhouette', 'flip_name']) == ['flip_name', 'skin', 'silhouette']
    assert P.plan(None) == list(P.EXPERIMENTS)
    with pytest.raises(ValueError):
        P.plan(['no_such_probe'])


def test_every_l_key_has_an_experiment():
    keys = {k for _, lk, _ in P.EXPERIMENTS.values() for k in lk}
    assert keys == {'L%d' % i for i in range(1, 17)}


@pytest.fixture(scope='module')
def probe(tmp_path_factory):
    out = tmp_path_factory.mktemp('organic_probe')
    r = subprocess.run(E.blender_command(BLENDER, HERE / 'organic_probe.py', ['--out', out]), capture_output=True,
                       text=True, errors='replace', timeout=900)
    assert r.returncode == 0, r.stdout[-3000:] + r.stderr[-3000:]
    data = json.loads((out / 'probe.json').read_text(encoding='utf-8'))
    data['_exact'] = data['blender'].startswith('5.1')
    return data


@needs_blender
def test_probe_ran_every_experiment_without_error(probe):
    assert probe['errors'] == {} and probe['experiments'] == list(P.EXPERIMENTS)
    assert set(probe['_lkeys']) == {'L%d' % i for i in range(1, 17)}


@needs_blender
def test_l1_flip_name_misses_mid_name_markers(probe):
    r = probe['L1_flip_name']
    for n in ('Bip01_L_Thigh', 'Bip01 L Thigh', 'Bip01_R_Calf', 'Bip01_L_UpperArm'):
        assert r[n]['unchanged']
    for n, flipped in (('L_Thigh', 'R_Thigh'), ('Thigh_L', 'Thigh_R'), ('Thigh.L', 'Thigh.R')):
        assert r[n]['flip_name'] == flipped


@needs_blender
def test_l2_automatic_weights_exceed_the_cap_and_sum_off(probe):
    for v in ('plain', 'joint_loops'):
        c = probe['C_autoweights_%s' % v]
        assert c['max_influences'] > 4 and c['sum_dev_max'] > 0.05
    assert probe['L_unnormalized_weight_preview']['follows_fully'] is True
    if probe['_exact']:
        assert probe['C_autoweights_plain']['over_4'] == 38 and probe['C_autoweights_plain']['sum_dev_max'] == 0.089
        assert probe['C_autoweights_joint_loops']['over_4'] == 47
        assert probe['C_autoweights_joint_loops']['sum_dev_max'] == 0.0888


@needs_blender
def test_l3_limit_total_needs_normalize_all(probe):
    e = probe['E_shell_transfer']
    assert e['after_limit2_no_normalize']['sum_dev_max'] > 0.1 and e['after_limit2_normalize']['sum_dev_max'] == 0.0
    if probe['_exact']:
        assert e['after_limit2_no_normalize']['sum_dev_max'] == 0.4203


@needs_blender
def test_l4_shell_transfer_and_gap(probe):
    e, s = probe['E_shell_transfer'], probe['E2_shell_poke']
    assert e['weights_after_transfer']['max_influences'] > 4
    assert e['shell_body_intersections']['bend_35'] > e['shell_body_intersections']['bend_0']
    assert s['same_limit4_gap0.010']['bend_0'] == 0 and s['same_limit4_gap0.000']['bend_0'] > 0
    if probe['_exact']:
        assert e['weights_after_transfer']['max_influences'] == 6
        assert e['shell_body_intersections'] == {'bend_0': 20, 'bend_35': 77}
        assert s['same_limit4_gap0.010'] == {'bend_0': 0, 'bend_30': 0, 'bend_60': 14}
        assert s['shell_limit2_gap0.010'] == {'bend_0': 0, 'bend_30': 21, 'bend_60': 31}
        assert s['shell_rigid1_gap0.010'] == {'bend_0': 0, 'bend_30': 16, 'bend_60': 87}


@needs_blender
def test_l5_uv_seams_and_flat_shading_split_vertices(probe):
    h = probe['H_vertex_split']
    assert h['smooth_no_uv'] == h['verts'] < h['smooth_smartuv66'] < h['flat_smartuv66']
    if probe['_exact']:
        assert (h['verts'], h['triangles'], h['smooth_smartuv66'], h['flat_smartuv66']) == (182, 360, 393, 598)


@needs_blender
def test_l6_quadriflow_drops_groups_and_uvs(probe):
    f = probe['F_quadriflow_manifold']
    assert f['before']['vgroups'] > 0 and f['after']['vgroups'] == 0 and f['after']['uv_layers'] == 0
    if probe['_exact']:
        assert f['before']['vgroups'] == 16 and f['after']['quads'] == 470


@needs_blender
def test_l7_decimate_slivers_and_unsubdivide(probe):
    g = probe['G_decimate']
    assert g['collapse_0.5']['min_angle'] < g['subdiv1']['min_angle']
    assert g['collapse_0.5']['vgroups'] > 0 and g['collapse_0.5']['weighted_verts'] == g['collapse_0.5']['verts']
    if probe['_exact']:
        assert (g['subdiv1']['min_angle'], g['collapse_0.5']['min_angle']) == (16.2, 6.62)
        assert g['collapse_0.5']['vgroups'] == 16
        assert (g['unsubdiv_2']['verts'], g['unsubdiv_2']['faces']) == (186, 191)


@needs_blender
def test_l8_operator_defaults(probe):
    d = probe['L8_operator_defaults']
    assert d['uv.unwrap']['method'] == 'CONFORMAL'
    assert d['object.vertex_group_clean'] == {'group_select_mode': '', 'limit': 0.0, 'keep_single': False}
    assert d['object.vertex_group_normalize_all']['lock_active'] is True


@needs_blender
def test_bone_deform_choice_needs_a_bound_mesh(probe):
    r = probe['bone_deform_enum']
    assert r['unbound'].startswith('TypeError') and r['bound'] == ['FINISHED']
    assert r['unbound_limit_total'].startswith('TypeError')                    # L16: Limit Total as well
    done = {'clean': ['FINISHED'], 'limit_total': ['FINISHED'], 'normalize_all': ['FINISHED']}
    assert r['bound_chain'] == done                                             # after an Armature modifier
    assert r['parent_empty_groups_modifiers'] == ['ARMATURE'] and r['parent_empty_groups_chain'] == done


@needs_blender
def test_l9_mirror_skin_body(probe):
    a = probe['A_skin_plain']
    assert a['non_manifold_edges'] == 0 and a['uv_layers'] == 0 and a['self_intersections'] == 0
    if probe['_exact']:
        assert (a['verts'], a['triangles']) == (166, 328)
        assert (probe['A_skin_joint_loops']['verts'], probe['A_skin_joint_loops']['triangles']) == (182, 360)


@needs_blender
def test_l10_headless_silhouette_render(probe):
    j = probe['J_silhouette']
    for view in ('front', 'rts45'):
        assert 0 < j[view]['coverage'] < 1 and Path(j[view]['file']).is_file()


@needs_blender
def test_l11_l15_linear_blend_joints(probe):
    d = probe['D2_fixed_skeleton_rings']
    for rings in ('rings_1', 'rings_3'):
        assert 0.7 < d[rings]['elbow_100']['radius_ratio_min'] < 0.8
        assert d[rings]['elbow_130']['new_self_intersections'] > 0
    if probe['_exact']:
        assert d['rings_1']['elbow_100']['radius_ratio_min'] == 0.764
        assert d['rings_1']['knee_100']['radius_ratio_min'] == 0.751
        assert (d['rings_3']['knee_100']['new_self_intersections'], d['rings_1']['knee_100']['new_self_intersections']) \
            == (21, 0)


@needs_blender
def test_l12_inverted_shell_flips_the_signed_volume(probe):
    v = probe['P4_shrinkwrap']['inverted_shell_signed_volume']
    assert v['original'] > 0 and v['all_flipped'] == -v['original'] and v['after_recalc_normals'] == v['original']


@needs_blender
def test_l13_headless_proportional_edit(probe):
    k = probe['K_proportional_translate']
    assert k['op'] == ['FINISHED'] and k['moved_verts'] > 1
    if probe['_exact']:
        assert k['moved_verts'] == 25


@needs_blender
def test_l14_shrinkwrap_methods_do_not_discriminate(probe):
    s = probe['P4_shrinkwrap']
    fits = {m: s[m]['target_to_cage_p95_m'] for m in ('NEAREST_SURFACEPOINT', 'TARGET_PROJECT', 'PROJECT')}
    assert len(set(fits.values())) == 1


@needs_blender
def test_probe_folder_inside_a_git_work_tree_is_refused():
    target = HERE / 'refused_probe_out'
    r = subprocess.run(E.blender_command(BLENDER, HERE / 'organic_probe.py', ['--out', target, '--only', 'flip_name']),
                       capture_output=True, text=True, errors='replace', timeout=300)
    assert r.returncode == 2 and 'git work tree' in r.stderr
    assert not target.exists()


@needs_blender
def test_a_crash_outside_the_experiments_exits_2(tmp_path):
    nl = chr(10)
    code = nl.join(['import sys', 'sys.path.insert(0, %r)' % str(HERE), 'import organic_probe as P',
                    'def boom(a):', '    raise ZeroDivisionError("seeded crash")', 'P.run = boom',
                    'sys.exit(P.main_blender(["--out", %r]))' % str(tmp_path / 'out')])
    r = subprocess.run([BLENDER, '-b', '--factory-startup', '--python-expr', code], capture_output=True, text=True,
                       errors='replace', timeout=300)
    assert r.returncode == 2, r.stdout[-1500:] + r.stderr[-1500:]
    assert 'Traceback' in r.stderr and 'seeded crash' in r.stderr and 'SETUP ERROR' in r.stderr

