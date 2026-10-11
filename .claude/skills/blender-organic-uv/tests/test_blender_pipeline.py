"""Background-Blender tests (skipped when no Blender is found): the evaluator against analytic answers on synthetic
meshes, its pictures, the three pose modes, and the whole organic pipeline (dump -> seam plan -> SLIM unwrap ->
layout -> apply to a copy -> evaluate -> gates) on the synthetic tube body.

    python -B -m pytest .claude/skills/blender-organic-uv/tests -q -p no:cacheprovider

Blender comes from BLENDER, PATH or the standard install folder (blender_env.find_blender of the companion skill
blender-organic-modeling). Every file goes to pytest's temp folder; output inside the repository must be refused.
"""
import json
import math
import subprocess
import sys
from pathlib import Path

import numpy as np
import pytest

TESTS = Path(__file__).resolve().parent
SCRIPTS = TESTS.parent / 'scripts'
sys.path[:0] = [str(SCRIPTS), str(TESTS)]
import synthetic as S  # noqa: E402
import uvenv  # noqa: E402

BLENDER = uvenv.find_blender()
pytestmark = pytest.mark.skipif(not BLENDER, reason='Blender not found (set BLENDER or put blender on PATH)')
PX = 1024 * 1024


def blender(script, args, blend=None, timeout=900):
    return subprocess.run(uvenv.blender_command(BLENDER, script, [str(a) for a in args], blend=blend),
                          capture_output=True, text=True, errors='replace', timeout=timeout)


def host(script, args, timeout=900):
    return subprocess.run([sys.executable, '-B', str(SCRIPTS / script)] + [str(a) for a in args],
                          capture_output=True, text=True, errors='replace', timeout=timeout)


def tail(r):
    return (r.stdout or '')[-3000:] + (r.stderr or '')[-3000:]


@pytest.fixture(scope='module')
def fx(tmp_path_factory):
    d = tmp_path_factory.mktemp('fixture')
    r = blender(TESTS / 'make_fixture_blend.py', [d])
    assert r.returncode == 0, tail(r)
    return d


def evaluate(fx, out, objects, extra=(), render=False):
    args = ['--blend', fx / 'fixture.blend', '--uv-layer', 'UVMap', '--page', 1024, '--out', out,
            '--objects', objects, '--label', out.name] + list(extra) + ([] if render else ['--no-render'])
    r = host('uv_eval.py', args)
    assert r.returncode == 0, tail(r)
    return json.loads((out / 'metrics.json').read_text())


def get(d, path):
    for k in path.split('.'):
        d = d[k]
    return d


CASES = [
    ('V1_iso', 'S_iso', [], {
        'distortion.L2_stretch': 1.0, 'distortion.Linf_stretch': 1.0, 'distortion.angular_aniso_mean': 1.0,
        'distortion.angle_dev_mean_deg': 0.0, 'distortion.area_log2_mean_abs': 0.0,
        'texel_density.all.p50': 512.0, 'texel_density.global_equivalent': 512.0, 'islands.count': 1,
        'seams.seam_length_m': 0.0, 'packing.coverage_texels': 0.25, 'orientation.upright_share_15deg': 1.0,
        'orientation.circular_mean_deg': 0.0, 'flips.flipped_faces': 0, 'overlaps.pairs': 0,
        'counts.gpu_vertices_all_uv_layers': 25}),
    ('V2_aniso', 'S_aniso', [], {
        'distortion.L2_stretch': math.sqrt(5 / 4), 'distortion.Linf_stretch': math.sqrt(2),
        'distortion.angular_aniso_mean': 2.0, 'distortion.angle_dev_mean_deg': (math.degrees(math.atan(2)) - 45) * 2 / 3,
        'distortion.area_log2_mean_abs': 0.0, 'texel_density.all.p50': 1024 * math.sqrt(0.125)}),
    ('V3_two_scales_gap', 'S_two', [], {
        'islands.count': 2, 'seams.seam_length_m': 1.0, 'distortion.L2_stretch': 1.25,
        'distortion.Linf_stretch': math.sqrt(2.5), 'distortion.area_ratio_p10': 0.4, 'distortion.area_ratio_p90': 1.6,
        'distortion.area_log2_mean_abs': 1.0, 'texel_density.all.p10': 256.0, 'texel_density.all.p90': 512.0,
        'packing.min_island_gap_px': 3.0, 'packing.gutter_vanish_mip': 2, 'packing.island_pairs_below_gutter': 1,
        'seams.visible_mean_m': 0.375, 'seams.visible_any_m': 1.0, 'seams.seam_per_sqrt_area': 1.0 / math.sqrt(2)}),
    ('V4_cylinder', 'S_cyl', [], {
        'distortion.L2_stretch': 1.0, 'distortion.Linf_stretch': 1.0, 'islands.count': 1, 'seams.seam_length_m': 1.0,
        'seams.visible_mean_m': 0.375, 'seams.visible_any_m': 1.0, 'overlaps.pairs': 0}),
    ('V5_cylinder_wall', 'S_cyl', ['--occluders', 'S_wall'], {
        'seams.visible_mean_m': 0.25, 'seams.visible_any_m': 1.0}),
    ('V6_mirror_declared', 'S_mirror', ['--mirror-overlap', 'x'], {
        'overlaps.declared_mirror_px2': 0.04 * PX, 'overlaps.unintended_px2': 0.0, 'flips.flipped_faces': 2,
        'flips.mirrored_islands': 1, 'flips.minority_flipped_faces_in_mixed_islands': 0, 'islands.count': 2,
        'packing.min_island_gap_px': 0.0, 'packing.gutter_vanish_mip': 0}),
    ('V6b_mirror_undeclared', 'S_mirror', [], {
        'overlaps.unintended_px2': 0.04 * PX, 'overlaps.declared_mirror_px2': 0.0}),
    ('V7_partial_overlap', 'S_partial', ['--mirror-overlap', 'x'], {
        'overlaps.unintended_px2': 0.01 * PX, 'overlaps.declared_mirror_px2': 0.0, 'islands.count': 2}),
    ('V8_fold', 'S_fold', [], {
        'overlaps.self_fold_px2': 0.06 * PX, 'flips.flipped_faces': 2,
        'flips.minority_flipped_faces_in_mixed_islands': 2, 'islands.count': 1, 'flips.mirrored_islands': 0}),
    ('V9_rot90', 'S_rot90', [], {
        'orientation.circular_mean_deg': 90.0, 'orientation.upright_share_15deg': 0.0,
        'orientation.axis_aligned_share_15deg': 1.0, 'distortion.L2_stretch': 1.0}),
]


@pytest.mark.parametrize('name,objects,extra,expected', CASES, ids=[c[0] for c in CASES])
def test_evaluator_matches_analytic_values(fx, tmp_path, name, objects, extra, expected):
    M = evaluate(fx, tmp_path / name, objects, extra)
    for path, want in expected.items():
        got = get(M, path)
        assert got is not None and abs(float(got) - want) <= max(1e-3, 1e-3 * abs(want)), (path, got, want)


def test_evaluator_pictures_and_repo_refusal(fx, tmp_path):
    out = tmp_path / 'pictures'
    evaluate(fx, out, 'S_cyl', ['--occluders', 'S_wall', '--res', 160, '--game-res', 120], render=True)
    for name in ('uv_layout.png', 'uv_stretch.png', 'model_checker.png', 'model_stretch.png', 'summary_card.png'):
        assert (out / name).stat().st_size > 10000, name
    assert (out / 'renders' / 'stretch_front.png').is_file()            # flat x shade composite written by uv_draw
    inside = TESTS / '_refused_eval'
    r = host('uv_eval.py', ['--blend', fx / 'fixture.blend', '--objects', 'S_iso', '--uv-layer', 'UVMap', '--page',
                            1024, '--out', inside, '--no-render'])
    assert r.returncode == 2 and not inside.exists()


def test_pose_modes_move_the_visible_seam(fx, tmp_path):
    bind = evaluate(fx, tmp_path / 'bind', 'S_cylpose')
    turned = evaluate(fx, tmp_path / 'frame', 'S_cylpose', ['--pose-frame', 10])
    quarter = evaluate(fx, tmp_path / 'action', 'S_cylpose', ['--pose-frame', 10, '--pose-action', 'Turn90'])
    vb, vt, vq = (np.array(M['seams']['visible_per_heading_m']) for M in (bind, turned, quarter))
    assert bind['pose']['mode'] == 'bind' and turned['pose']['mode'] == 'frame'
    assert list(np.nonzero(vb)[0]) == [0, 1, 7]                          # seam faces -Y: headings -45, 0, 45
    assert list(np.nonzero(vt)[0]) == [3, 4, 5]                          # turned 180 deg: headings 135-225
    assert list(np.nonzero(vq)[0]) == [1, 2, 3]                          # Turn90: headings 45-135
    # the same pose from an NPZ written by another tool
    co = np.array([v for v in S_cyl_vertices()], float)
    npz = tmp_path / 'pose.npz'
    np.savez(npz, pose__S_cylpose=co * np.array([-1.0, -1.0, 1.0]))
    viaz = evaluate(fx, tmp_path / 'npz', 'S_cylpose', ['--pose-npz', npz])
    assert viaz['pose']['mode'] == 'npz'
    assert viaz['seams']['visible_per_heading_m'] == turned['seams']['visible_per_heading_m']


def S_cyl_vertices():
    n, r, h, rows = 16, 0.3, 1.0, 4
    for j in range(rows + 1):
        for i in range(n):
            th = math.radians(-90 + i * 360.0 / n)
            yield (r * math.cos(th), r * math.sin(th), h * j / rows)


def test_unwrap_refuses_conformal(fx, tmp_path):
    seams = tmp_path / 'seams.json'
    seams.write_text(json.dumps({'objects': {'S_iso': {'seams': []}}}), encoding='utf-8')
    r = blender(SCRIPTS / 'organic_unwrap.py', ['--seams', seams, '--out', tmp_path / 'raw.json', '--method',
                                                 'CONFORMAL'], blend=fx / 'fixture.blend')
    assert r.returncode != 0 and 'CONFORMAL' in tail(r) and not (tmp_path / 'raw.json').exists()


def test_full_pipeline_on_the_tube_body(fx, tmp_path):
    dump, seams, raw = tmp_path / 'dump.json', tmp_path / 'seams.json', tmp_path / 'raw.json'
    r = blender(SCRIPTS / 'mesh_dump.py', ['--out', dump, '--objects', 'Body', '--part-names',
                                            fx / 'part_names.json'], blend=fx / 'fixture.blend')
    assert r.returncode == 0, tail(r)
    d = json.loads(dump.read_text())['objects']['Body']
    assert d['mirror_unmatched'] == 0 and set(d['vattrs']) == {'ring', 'slot'} and d['part_source'].startswith('face')
    rules = tmp_path / 'rules.json'
    rules.write_text(json.dumps(S.BODY_RULES), encoding='utf-8')
    r = host('seam_plan.py', [dump, rules, '--out', seams])
    assert r.returncode == 0, tail(r)
    r = blender(SCRIPTS / 'organic_unwrap.py', ['--seams', seams, '--out', raw], blend=fx / 'fixture.blend')
    assert r.returncode == 0, tail(r)
    rawd = json.loads(raw.read_text())
    assert rawd['objects']['Body']['method'] == 'MINIMUM_STRETCH' and rawd['defaults']['iterations'] == 50
    cfg = tmp_path / 'layout_cfg.json'
    cfg.write_text(json.dumps({'schema': 'blender-organic-uv/layout/1',
                               'pages': [{'name': 'body', 'size': 512, 'gutter_px': 8, 'objects': ['Body']}],
                               'mirror_objects': ['Body'], 'priority': {'factors': {'hand': 1.15}},
                               'head_target': {'ratio': 1.3, 'objects': ['Body']}, 'search': {'iters': 12}}),
                   encoding='utf-8')
    layout = tmp_path / 'layout.json'
    r = host('organic_layout.py', [dump, raw, cfg, '--out', layout, '--quiet'])
    assert r.returncode == 0, tail(r)
    rep = json.loads((tmp_path / 'layout_report.json').read_text())
    assert rep['head_calibration']['applied'] and not rep['problems']
    copy_blend, apply_rep = tmp_path / 'applied.blend', tmp_path / 'apply.json'
    r = blender(SCRIPTS / 'organic_apply.py', ['--layout', layout, '--out', copy_blend, '--report', apply_rep,
                                                '--remove-uv-layer', 'UVMap', '--seams', seams],
                blend=fx / 'fixture.blend')
    assert r.returncode == 0, tail(r)
    ar = json.loads(apply_rep.read_text())
    assert ar['geometry_unchanged'] and ar['removed_layers']['Body'] == ['UVMap']
    s = ar['seams']['Body']
    assert s['planned_not_uv_border'] == 0 and s['uv_border_not_planned'] == 0
    out = tmp_path / 'eval'
    r = host('uv_eval.py', ['--blend', copy_blend, '--objects', 'Body', '--uv-layer', 'UV_ORGANIC', '--page', 512,
                            '--gutter-px', 8, '--part-attr', 'part', '--part-names', fx / 'part_names.json',
                            '--out', out, '--no-render'])
    assert r.returncode == 0, tail(r)
    M = json.loads((out / 'metrics.json').read_text())
    assert M['flips']['flipped_faces'] == 0 and M['overlaps']['pairs'] == 0
    assert M['packing']['min_island_gap_px'] >= 8 and M['orientation']['upright_share_15deg'] > 0.99
    assert M['symmetry']['density_log2_asym_mean'] < 1e-4 and M['flips']['mirrored_islands'] == 0
    assert M['counts']['gpu_vertices_all_uv_layers'] == M['counts']['uv_split_vertices']   # placeholder gone
    assert M['bone_regions']['head_torso'] == pytest.approx(1.3, abs=0.01)
    profile = tmp_path / 'profile.json'
    profile.write_text(json.dumps({'schema': 'blender-organic-uv/gates/1', 'name': 'synthetic', 'checks': [
        {'id': 'flips', 'run': 'page', 'metric': 'flips.flipped_faces', 'hard': {'max': 0}},
        {'id': 'gap', 'run': 'page', 'metric': 'packing.min_island_gap_px', 'hard': {'min': 8}},
        {'id': 'head', 'run': 'page', 'metric': 'bone_regions.head_torso', 'hard': {'min': 1.29, 'max': 1.31}}]}),
        encoding='utf-8')
    r = host('uv_gates.py', ['--profile', profile, '--run', 'page=%s' % out])
    assert r.returncode == 0, tail(r)
    # every metric path of the template profile exists in a real evaluator run
    tmpl = json.loads((TESTS.parent / 'profiles' / 'template_unit_body.json').read_text(encoding='utf-8'))
    sys.path.insert(0, str(SCRIPTS))
    import uv_gates as G
    res = G.evaluate(tmpl, {'page': M, 'body': M})
    assert [row['id'] for row in res['rows'] if row['value'] is None] == []
