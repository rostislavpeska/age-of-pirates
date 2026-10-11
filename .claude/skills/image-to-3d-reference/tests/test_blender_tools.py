"""render_ortho.py, mesh_stats.py and preview_glb.py on a synthetic figure GLB built in background Blender
(make_fixture_model.py); skips without Blender.

    python -B -m pytest .claude/skills/image-to-3d-reference/tests -q -p no:cacheprovider

Blender comes from BLENDER, PATH or the standard install folder (blender_env.find_blender of the companion skill
blender-organic-modeling). Every file goes to pytest's temp folder. Checks: welded part and fragment census, the
ortho mapping against the rendered silhouette (and an end-to-end angle through pose_angles.py), the bounding-box
pair scale, the host-form relaunch with a relative output folder (Blender resolves relative render paths against
the drive root), the explicit reference name, and the refusal of output inside a git work tree.
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
sys.path[:0] = [str(SCRIPTS), str(TESTS.parents[1] / 'blender-organic-modeling' / 'scripts')]
import blender_env as E  # noqa: E402
import pose_angles as P  # noqa: E402

BLENDER = E.find_blender()
pytestmark = pytest.mark.skipif(not BLENDER, reason='Blender not found (set BLENDER or put blender on PATH)')
REFUSED = TESTS / '_refused_output'          # inside the repository: every tool must refuse it


def run_blender(script, args, cwd=None, timeout=600):
    return subprocess.run(E.blender_command(BLENDER, script, args), capture_output=True, text=True,
                          errors='replace', timeout=timeout, cwd=cwd)


def tail(r):
    return (r.stdout or '')[-3000:] + (r.stderr or '')[-3000:]


@pytest.fixture(scope='module')
def fx(tmp_path_factory):
    d = tmp_path_factory.mktemp('figure')
    r = run_blender(TESTS / 'make_fixture_model.py', [d])
    assert r.returncode == 0, tail(r)
    return json.loads((d / 'fixture.json').read_text(encoding='utf-8'))


def test_mesh_stats_welds_seam_splits_and_bands_the_fragments(fx, tmp_path):
    out = tmp_path / 'stats.json'
    r = run_blender(SCRIPTS / 'mesh_stats.py', ['--model', fx['glb'], '--out', out])
    assert r.returncode == 0, tail(r)
    rep = json.loads(out.read_text(encoding='utf-8'))
    m = rep['meshes'][0]
    assert m['raw_vertices'] > m['welded_vertices']            # the GLB split every flat face
    assert m['triangles'] == fx['triangles']
    assert m['loose_parts'] == fx['loose_parts'] and m['fragments'] == fx['fragments']
    assert m['fragments_under_50_verts'] == fx['fragments']
    assert m['open_edges'] == 0 and m['nonmanifold_edges'] == 0 and m['components_converged']
    bands = m['fragment_count_by_height_band']
    assert bands[fx['arm_band']] == 2 and bands[fx['plume_band']] == 3 and sum(bands) == fx['fragments']
    assert any(i[1] == fx['texture'] for i in rep['images']), rep['images']
    assert len(rep['model_sha256']) == 64


def test_render_ortho_mapping_matches_the_silhouette(fx, tmp_path):
    from PIL import Image
    res = 400
    r = run_blender(SCRIPTS / 'render_ortho.py', ['--model', fx['glb'], '--out-dir', tmp_path, '--prefix', 'fig',
                                                  '--res', res, '--engine', 'WORKBENCH'])
    assert r.returncode == 0, tail(r)
    info = json.loads((tmp_path / 'fig_ortho.json').read_text(encoding='utf-8'))
    s, ppm, cz = info['scale'], info['px_per_m'], info['centre_z']
    assert s == pytest.approx(2.0 / fx['raw_height'], rel=1e-4)
    assert info['norm_bbox'][0][2] == pytest.approx(0.0, abs=1e-4)
    assert info['norm_bbox'][1][2] == pytest.approx(2.0, abs=1e-4)
    alpha = np.asarray(Image.open(tmp_path / 'fig_front.png').convert('RGBA'))[:, :, 3] > 128
    assert alpha.shape == (res, res) and Image.open(tmp_path / 'fig_side.png').size == (res, res)
    rows = np.where(alpha.any(1))[0]
    assert abs(rows.min() - (res / 2 - (2.0 - cz) * ppm)) <= 2       # top of the plume
    assert abs(rows.max() - (res / 2 + cz * ppm)) <= 2               # soles

    t = math.radians(fx['arm_deg'])

    def px(side, frac):
        """Front-view pixel of a point at `frac` along the arm axis (side +1 = world +X = the figure's left)."""
        X = (fx['shoulder'][0] + math.sin(t) * fx['arm_len'] * frac) * side * s
        Z = (fx['shoulder'][2] - math.cos(t) * fx['arm_len'] * frac) * s
        return [X * ppm + res / 2, res / 2 - (Z - cz) * ppm]

    x, y = px(1, 0.8)
    assert alpha[int(round(y)), int(round(x))]
    nx, ny = math.cos(t), -math.sin(t)                               # image-plane normal, away from the torso
    assert not alpha[int(round(y + 30 * ny)), int(round(x + 30 * nx))]
    # end to end: picks off the mapping, elbow and wrist pushed off the axis, centred again on the silhouette
    picks = {'target': {'upper_arm_from_down': fx['arm_deg']}, 'cases': {'fig': {'front': {
        'image': 'fig_front.png', 'arms': {
            'L': [px(1, 0.08), [a + 4 * b for a, b in zip(px(1, 0.5), (nx, ny))], px(1, 0.9)],
            'R': [px(-1, 0.08), [a - 4 * b for a, b in zip(px(-1, 0.5), (-nx, ny))], px(-1, 0.9)]}}}}}
    pf = tmp_path / 'picks.json'
    pf.write_text(json.dumps(picks), encoding='utf-8')
    assert P.main([str(pf), '--out', str(tmp_path / 'pose.json'), '--centre-limbs']) == 0
    arms = json.loads((tmp_path / 'pose.json').read_text(encoding='utf-8'))['cases']['fig']['arms']
    for side in ('L', 'R'):
        assert arms[side]['upper_arm_from_down'] == pytest.approx(fx['arm_deg'], abs=1.0), arms[side]
        assert arms[side]['elbow_projected'] < 3.0


def test_host_form_relaunches_blender_and_keeps_relative_output_under_the_cwd(fx, tmp_path):
    r = subprocess.run([sys.executable, str(SCRIPTS / 'render_ortho.py'), '--blender-exe', BLENDER,
                        '--model', fx['glb'], '--out-dir', 'rel_out', '--prefix', 'fig', '--res', '64',
                        '--engine', 'WORKBENCH'], capture_output=True, text=True, errors='replace', timeout=600,
                       cwd=tmp_path)
    assert r.returncode == 0, tail(r)
    for name in ('fig_front.png', 'fig_side.png', 'fig_ortho.json'):
        assert (tmp_path / 'rel_out' / name).is_file(), name


def test_preview_pair_uses_the_named_reference_and_its_height(fx, tmp_path):
    r = run_blender(SCRIPTS / 'preview_glb.py', ['--model', fx['glb'], '--out-dir', tmp_path, '--prefix', 'p',
                                                 '--reference-blend', fx['ref_blend'],
                                                 '--reference-object', fx['ref_object'], '--views', 'front,side',
                                                 '--res', '160x180', '--engine', 'WORKBENCH'])
    assert r.returncode == 0, tail(r)
    stats = json.loads((tmp_path / 'p_stats.json').read_text(encoding='utf-8'))
    assert stats['scale_to_reference'] == pytest.approx(fx['ref_height'] / fx['raw_height'], rel=1e-4)
    assert stats['reference_object'] == 'REF_body' and stats['triangles'] == fx['triangles']
    for name in ('p_pair_front.png', 'p_pair_side.png', 'p_solo_front.png', 'p_solo_side.png'):
        assert (tmp_path / name).is_file(), name
    assert not list(tmp_path.glob('p_*_back.png'))


def test_preview_with_a_missing_reference_object_is_a_setup_error(fx, tmp_path):
    r = run_blender(SCRIPTS / 'preview_glb.py', ['--model', fx['glb'], '--out-dir', tmp_path,
                                                 '--reference-blend', fx['ref_blend'], '--reference-object', 'Body',
                                                 '--engine', 'WORKBENCH'])
    assert r.returncode == 2 and 'SETUP ERROR' in r.stderr and 'REF_body' in r.stderr
    assert not list(tmp_path.iterdir())


@pytest.mark.parametrize('script,args', [
    ('render_ortho.py', ['--out-dir', REFUSED, '--engine', 'WORKBENCH', '--res', '32']),
    ('preview_glb.py', ['--out-dir', REFUSED, '--engine', 'WORKBENCH', '--res', '32x32']),
    ('mesh_stats.py', ['--out', REFUSED / 'stats.json']),
])
def test_output_inside_a_git_work_tree_is_refused(fx, script, args):
    r = run_blender(SCRIPTS / script, ['--model', fx['glb']] + args)
    assert r.returncode == 2 and 'git work tree' in r.stderr, tail(r)
    assert not REFUSED.exists()


def test_a_missing_model_is_a_setup_error(tmp_path):
    r = run_blender(SCRIPTS / 'mesh_stats.py', ['--model', tmp_path / 'absent.glb'])
    assert r.returncode == 2 and 'model not found' in r.stderr
