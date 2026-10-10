"""Regression tests for plan_batches, aggregate_findings and run_inspector prompt filling (no models are called).

    python -m pytest test_visual_inspector.py -q
"""
import json, shutil, subprocess, sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent))
from plan_batches import plan
from aggregate_findings import aggregate, label_ok, cell
import run_inspector

HERE = Path(__file__).resolve().parent; REPO = Path(__file__).resolve().parents[4]   # <repo>/.claude/skills/visual-inspector/scripts
SPEC = {'asset': 'test house', 'camera': '40 deg', 'legend': ['MAGENTA = hidden'], 'classes': {'H1': 'magenta visible?'},
        'not_defects': ['grey']}


def ann(n=10):
    a = [{'file': f'd/v{i}__ann.png', 'label': f'v{i} (camera az{i * 10:03d})', 'control': None, 'grid': [8, 6]} for i in range(n)]
    a.append({'file': 'd/CONTROL_c0__ann.png', 'label': 'c0 (camera az022)', 'control': 'planted', 'grid': [8, 6]})
    a.append({'file': 'd/CLEAN_c5__ann.png', 'label': 'c5 (camera az072)', 'control': 'clean', 'grid': [8, 6]})
    return a


def answer(job, iid, findings=None, label_fn=None, skip_planted=False, dirty_clean=False):
    b = next(x for x in job['batches'] if x['inspector_id'] == iid); out = []
    for f in b['images']:
        m = job['images'][f]; fs = list((findings or {}).get(Path(f).name, []))
        if m['control'] == 'planted' and not skip_planted:
            fs.append({'class': 'H1', 'grid_cells': ['D3'], 'what': 'magenta block', 'confidence': 'high', 'severity': 'major'})
        if m['control'] == 'clean' and dirty_clean:
            fs.append({'class': 'H1', 'grid_cells': ['A1'], 'what': 'invented', 'confidence': 'low', 'severity': 'minor'})
        out.append({'image_file': Path(f).name, 'view_label_read': (label_fn or (lambda x: x))(m['label']), 'clean': not fs, 'findings': fs})
    return {'inspector_id': iid, 'images': out}


def test_plan_covers_every_image_votes_times_with_controls():
    job = plan(SPEC, ann(), per=5, votes=2, engines=('claude', 'codex'))
    targets = [f for f, m in job['images'].items() if not m['control']]
    for f in targets:
        assert sum(f in b['images'] for b in job['batches']) == 2
    for b in job['batches']:
        assert 4 <= len(b['images']) <= 6 or b is job['batches'][-1]
        assert any(job['images'][f]['control'] == 'planted' for f in b['images'])
    assert {b['engine'] for b in job['batches'] if b['round'] == 0} == {'claude'}
    assert {b['engine'] for b in job['batches'] if b['round'] == 1} == {'codex'}


def test_plan_refuses_without_planted_control():
    try:
        plan(SPEC, [x for x in ann() if x['control'] != 'planted'])
    except SystemExit as e:
        assert 'planted control' in str(e)
    else:
        raise AssertionError('no planted control must refuse')


def test_consensus_needs_two_inspectors_on_touching_cells():
    job = plan(SPEC, ann(), per=5, votes=2); res = {}
    for b in job['batches']:
        f = {'v3__ann.png': [{'class': 'H1', 'grid_cells': ['E5'] if b['round'] == 0 else ['F4'], 'what': 'stripe', 'confidence': 'med', 'severity': 'minor'}]}
        res[b['inspector_id']] = answer(job, b['inspector_id'], f)
    agg = aggregate(job, res, 2)
    assert agg['valid_inspectors'] == agg['all_inspectors']
    c = [x for x in agg['findings'] if x['image'] == 'v3__ann.png']
    assert len(c) == 1 and c[0]['status'] == 'consensus' and c[0]['votes'] == 2 and c[0]['verify']
    assert 'v4__ann.png' in agg['clean_images'] and not agg['under_covered']


def test_far_cells_stay_separate_singles():
    job = plan(SPEC, ann(), per=5, votes=2); res = {}
    for b in job['batches']:
        f = {'v3__ann.png': [{'class': 'H1', 'grid_cells': ['A1'] if b['round'] == 0 else ['H6'], 'what': 'x', 'confidence': 'low', 'severity': 'minor'}]}
        res[b['inspector_id']] = answer(job, b['inspector_id'], f)
    c = [x for x in aggregate(job, res, 2)['findings'] if x['image'] == 'v3__ann.png']
    assert sorted(x['status'] for x in c) == ['single', 'single'] and not any(x['verify'] for x in c)


def test_missed_planted_control_invalidates_inspector_and_its_clean_votes():
    job = plan(SPEC, ann(), per=5, votes=2); res = {}
    bad = job['batches'][0]['inspector_id']
    for b in job['batches']:
        res[b['inspector_id']] = answer(job, b['inspector_id'], skip_planted=(b['inspector_id'] == bad))
    agg = aggregate(job, res, 2)
    assert not agg['inspectors'][bad]['valid'] and 'missed planted control' in agg['inspectors'][bad]['problems'][0]
    under = {Path(f).name for f in job['batches'][0]['images'] if not job['images'][f]['control']}
    assert under <= set(agg['under_covered'])


def test_clean_control_findings_and_label_mismatch_and_missing_result():
    job = plan(SPEC, ann(), per=5, votes=2); res = {}
    ids = [b['inspector_id'] for b in job['batches']]
    res[ids[0]] = answer(job, ids[0], dirty_clean=True)
    res[ids[1]] = answer(job, ids[1], label_fn=lambda x: 'something else entirely')
    agg = aggregate(job, res, 2)
    assert any('clean control' in p for p in agg['inspectors'][ids[0]]['problems'])
    assert any('label mismatch' in p for p in agg['inspectors'][ids[1]]['problems'])
    assert agg['inspectors'][ids[2]]['problems'] == ['no result (failed run)']


def test_plan_refuses_control_twin_of_an_inspected_view():
    a = ann(); a[-2]['label'] = 'v3 (camera az030)'
    try:
        plan(SPEC, a)
    except SystemExit as e:
        assert 'share a view' in str(e)
    else:
        raise AssertionError('a control twin must refuse')


def test_label_and_cell_parsing():
    assert label_ok('market_az045_el+40  (camera az045_el+40)', 'Market_az045_el+40 (camera az045_el+40)')
    assert not label_ok('market_az045_el+40', 'market_az200_el+15')
    assert cell('H6', [8, 6]) == (7, 5) and cell('I1', [8, 6]) is None and cell('A7', [8, 6]) is None and cell('east', [8, 6]) is None


def test_prompt_fill_per_engine():
    job = plan(SPEC, ann(), per=5, votes=1); b = job['batches'][0]
    pc = run_inspector.fill(job, b, 'claude'); px = run_inspector.fill(job, b, 'codex')
    for p in (pc, px):
        assert '{' + 'asset}' not in p and 'test house' in p and 'H1: magenta visible?' in p and b['inspector_id'] in p
    assert 'Read tool' in pc and 'attached' in px


def test_schema_is_strict_for_codex():
    s = json.load(open(run_inspector.SCHEMA))

    def walk(x):
        if isinstance(x, dict):
            if x.get('type') == 'object':
                assert x.get('additionalProperties') is False and sorted(x['required']) == sorted(x['properties'])
            for v in x.values():
                walk(v)
    walk(s)


def blender_exe():
    """This PC's Blender (config/tool-paths.local.json, else blender on PATH), or None."""
    cfg = REPO / 'config' / 'tool-paths.local.json'
    try:
        p = Path(json.loads(cfg.read_text(encoding='utf-8'))['tools']['blender']['path'])
    except (OSError, KeyError, ValueError):
        p = None
    if p and p.is_file():
        return p
    w = shutil.which('blender')
    return Path(w) if w else None


def run_blender(cmd):
    r = subprocess.run([str(c) for c in cmd], capture_output=True, timeout=300)
    err, out = (x.decode('utf-8', 'replace')[-3000:] for x in (r.stderr, r.stdout))
    assert r.returncode == 0, f'blender exit {r.returncode}: {cmd}\nSTDERR:\n{err}\nSTDOUT:\n{out}'
    return out


PROBE = (                                                 # one single-sided sheet, normal -Z, face attribute cls = 4
    "import bpy, sys\n"
    "from pathlib import Path\n"
    "d = Path(sys.argv[sys.argv.index('--') + 1])\n"
    "bpy.ops.wm.read_factory_settings(use_empty=True)\n"
    "sc = bpy.context.scene; sc.name = 'S'; sc.render.dither_intensity = 0\n"   # dither 1 (default) varies the grey by 1 level
    "col = bpy.data.collections.new('M'); sc.collection.children.link(col)\n"
    "me = bpy.data.meshes.new('sheet'); me.from_pydata([(-1, -1, 0), (1, -1, 0), (1, 1, 0), (-1, 1, 0)], [], [(0, 3, 2, 1)])\n"
    "me.attributes.new('cls', 'INT', 'FACE').data[0].value = 4\n"
    "col.objects.link(bpy.data.objects.new('sheet', me))\n"
    "bpy.ops.wm.save_as_mainfile(filepath=str(d / 'probe.blend'))\n")


def test_overlay_culls_back_faces_by_default(tmp_path):
    """A single-sided sheet seen from behind (normal -Z, camera 40 deg up): the game draws nothing there, so neither may the overlay."""
    exe = blender_exe()
    if not exe:
        pytest.skip('no Blender on this machine (config/tool-paths.local.json)')
    Image = pytest.importorskip('PIL.Image')
    (tmp_path / 'probe.py').write_text(PROBE, encoding='utf-8')
    run_blender([exe, '-b', '--factory-startup', '--python-exit-code', '1', '--python', tmp_path / 'probe.py', '--', tmp_path])
    seen = {}
    for tag, extra in (('cull', []), ('nocull', ['--no-cull-backfaces'])):
        out = run_blender([exe, '-b', tmp_path / 'probe.blend', '--factory-startup', '--python-exit-code', '1',
                           '--python', HERE / 'render_overlay_views.py', '--', '--scene', 'S', '--collections', 'M', '--attr', 'cls',
                           '--colors', '{"4": [1, 0, 1]}', '--views', '0:40', '--res', '64x48', '--out', tmp_path / tag, '--tag', tag, *extra])
        assert 'OVERLAY_DONE' in out, out
        rec = json.loads((tmp_path / tag / f'VIEWS_{tag}.json').read_text(encoding='utf-8'))
        with Image.open(tmp_path / tag / rec['views'][0]['file']) as im:
            im = im.convert('RGB')
        seen[tag] = (rec['cull_backfaces'], im.getpixel((32, 24)), im.getpixel((1, 1)))   # centre, background corner
    assert seen['cull'][0] is True and seen['cull'][1] == seen['cull'][2], f'culled: the background must show through the back: {seen}'
    assert seen['nocull'][0] is False and seen['nocull'][1] == (255, 0, 255), f'not culled: the back face draws magenta: {seen}'
