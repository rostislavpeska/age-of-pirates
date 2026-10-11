"""grid.py on a synthetic transparent image (source-pixel labels, crop and zoom, refusals) and --help of every
command without Blender. Host Python with Pillow.

    python -B -m pytest .claude/skills/image-to-3d-reference/tests -q -p no:cacheprovider
"""
import subprocess
import sys
from pathlib import Path

import pytest

TESTS = Path(__file__).resolve().parent
SCRIPTS = TESTS.parent / 'scripts'
sys.path[:0] = [str(SCRIPTS), str(TESTS.parents[1] / 'blender-organic-modeling' / 'scripts')]
import grid as G  # noqa: E402

RED, BLUE, GREY = (255, 0, 0), (0, 140, 255), (205, 205, 205)


@pytest.fixture
def src(tmp_path):
    from PIL import Image, ImageDraw
    im = Image.new('RGBA', (300, 200), (0, 0, 0, 0))
    ImageDraw.Draw(im).rectangle([210, 120, 280, 190], fill=(10, 200, 10, 255))
    p = tmp_path / 'render.png'
    im.save(p)
    return p


def test_first_line_is_the_next_multiple():
    assert [G.first_line(v, 50) for v in (0, 1, 49, 50, 51)] == [0, 50, 50, 50, 100]


def test_lines_sit_on_source_pixels_and_transparency_is_grey(src, tmp_path):
    from PIL import Image
    out = tmp_path / 'grid.png'
    assert G.main([str(src), str(out), '--step', '50']) == 0
    im = Image.open(out).convert('RGB')
    assert im.size == (300, 200)
    assert im.getpixel((100, 140)) == RED and im.getpixel((50, 140)) == BLUE
    assert im.getpixel((75, 130)) == GREY and im.getpixel((240, 160)) == (10, 200, 10)


def test_crop_and_zoom_keep_source_coordinates(src, tmp_path):
    from PIL import Image
    out = tmp_path / 'crop.png'
    assert G.main([str(src), str(out), '--step', '50', '--crop', '60,40,260,190', '--zoom', '2']) == 0
    im = Image.open(out).convert('RGB')
    assert im.size == (400, 300)
    assert im.getpixel((80, 150)) == RED          # source x = 100 -> (100 - 60) * 2
    assert im.getpixel((180, 150)) == BLUE        # source x = 150


@pytest.mark.parametrize('args,why', [(['--crop', '0,0,400,100'], 'outside'), (['--crop', '1,2,3'], '4 integers'),
                                      (['--step', '1'], '--step')])
def test_bad_arguments_are_setup_errors(src, tmp_path, capsys, args, why):
    assert G.main([str(src), str(tmp_path / 'x.png')] + args) == 2
    assert why in capsys.readouterr().err and not (tmp_path / 'x.png').exists()


def test_output_inside_a_git_work_tree_is_refused(src, capsys):
    target = TESTS / '_refused_grid.png'
    assert G.main([str(src), str(target)]) == 2
    assert 'git work tree' in capsys.readouterr().err and not target.exists()


@pytest.mark.parametrize('script', ['render_ortho.py', 'mesh_stats.py', 'preview_glb.py', 'grid.py',
                                    'pose_angles.py'])
def test_help_works_without_blender(script):
    r = subprocess.run([sys.executable, '-B', str(SCRIPTS / script), '--help'], capture_output=True, text=True,
                       timeout=60)
    assert r.returncode == 0 and 'usage:' in r.stdout, r.stderr
