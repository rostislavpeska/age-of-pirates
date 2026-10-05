"""The universal UV density floor (density_floor.py) and the 03_uv handoff that records it (handoff.py).

Owner 2026-09-30: "Plus we need hard DPI floor!!!!!!!!!! Scattered UV map is a nightmare!!!!!! ... But UV map DPI floor
should be universal". Synthetic models of unit quads: a coherent map passes; the SAME pages scattered into many small,
shrunken islands fail the per-face floor although the median still passes; every rule fails without tolerance; a missing
measurement is INCOMPLETE; only the owner's whole message waives. Real models: scripts/havok/tests/test_gr2_lint.py.

    python -m pytest .claude/skills/blender-architecture-texturing/scripts/test_density_floor.py -q
"""
import json
import subprocess
import sys
from pathlib import Path

import numpy as np
import pytest

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.dont_write_bytecode = True
import density_floor as DF  # noqa: E402
import handoff as HO  # noqa: E402
sys.path.insert(0, str(HERE.parents[1] / 'blender-uv-workflow' / 'tests'))
from uv_checkpoint_fixture import freeze_fixture

FLOOR = DF.load_floor('aoe3de')
OWNER = [{'id': 'm7', 'text': 'Keep the hidden ktc page as it is below the density floor, nobody sees it.'}]


def quads(n, density, W, page='P2048', scatter=False, origin=(0.0, 0.0)):
    """n x n unit quads in the XY plane at `density` t/u on a W page: one coherent island, or (scatter) one island
    per quad, each placed apart on the page"""
    P, UV = [], []
    s = density / W                                         # UV units per model unit
    for i in range(n):
        for j in range(n):
            x0, y0 = origin[0] + i, origin[1] + j
            corners = np.array([[x0, y0, 0], [x0 + 1, y0, 0], [x0 + 1, y0 + 1, 0], [x0, y0 + 1, 0]], float)
            if scatter:
                uv0 = np.array([(i * n + j) * 3 * s % 0.9, 0.05 + ((i * n + j) * 3 * s // 0.9) * 3 * s])
                uv = uv0 + (corners[:, :2] - [x0, y0]) * s
            else:
                uv = (corners[:, :2] - origin) * s + 0.01
            for t in ((0, 1, 2), (0, 2, 3)):
                P.append(corners[list(t)])
                UV.append(uv[list(t)])
    return dict(page=page, W=W, H=W, P=np.array(P), UV=np.array(UV))


def verdict(groups, **kw):
    m = DF.measure(groups, FLOOR)
    return DF.evaluate(m, FLOOR, remeasure=lambda pages: DF.measure(groups, FLOOR, exempt=pages), **kw)


def rules_of(res):
    return {(f['rule'], f['page']) for f in res['findings']}


# ------------------------------------------------------------------------------------------------------ the rule
def test_the_aoe3de_numbers_are_the_measured_vanilla_floor():
    assert (FLOOR['model_median_min'], FLOOR['face_floor'], FLOOR['face_max_share_below'],
            FLOOR['collapsed_max_share']) == (100.0, 60.0, 0.02, 0.03)
    doc = json.loads(DF.CONFIG.read_text(encoding='utf-8'))
    assert set(doc['games']['aoe3de']['basis']) == set(DF.NUMBERS)          # every number carries its evidence


def test_a_coherent_map_at_107_passes():
    res = verdict([quads(10, 107, 2048)])
    m = res['metrics']
    assert res['status'] == 'PASS', res['summary']
    assert abs(m['model']['p50'] - 107) < 0.01 and m['model']['share_below_face_floor'] == 0
    assert m['model']['islands'] == 1 and m['collapsed']['share'] == 0


def test_the_same_pages_scattered_fail_the_per_face_floor():
    """KTC-164: the owner's "scattered UV map" - the same page, the same area, but 12 % of it cut into separate
    shrunken islands at 45 t/u. The median still passes (107); the per-face rule catches it."""
    coherent = [quads(10, 107, 2048), quads(3, 107, 2048, origin=(20, 0))]
    scattered = [quads(10, 107, 2048), quads(3, 45, 2048, scatter=True, origin=(20, 0))]
    ok, bad = verdict(coherent), verdict(scattered)
    assert ok['status'] == 'PASS'
    assert bad['status'] == 'FAIL' and bad['metrics']['model']['p50'] >= 100
    assert ('face_floor', None) in rules_of(bad) and ('face_floor', 'P2048') in rules_of(bad)
    assert bad['metrics']['model']['islands_per_100u2'] > ok['metrics']['model']['islands_per_100u2']
    assert abs(bad['metrics']['model']['share_below_face_floor'] - 9 / 109) < 1e-6


def test_a_low_median_fails():
    res = verdict([quads(10, 95, 2048)])
    assert res['status'] == 'FAIL' and rules_of(res) == {('model_median', None)}


def test_a_page_below_the_floor_fails_even_when_the_model_share_passes():
    """1 % of the model on a 512 page at 40 t/u: the model share 0.99 % passes, the page fails (per page)"""
    res = verdict([quads(10, 107, 2048), quads(1, 40, 512, page='P512')])
    assert res['metrics']['model']['share_below_face_floor'] < FLOOR['face_max_share_below']
    assert res['status'] == 'FAIL' and rules_of(res) == {('face_floor', 'P512')}


def test_collapsed_uvs_cannot_hide_a_scattered_map():
    """faces parked on one texel escape the percentiles, so their share has its own cap (vanilla max 2.7 %)"""
    g = quads(10, 107, 2048)
    col = quads(3, 107, 2048, origin=(20, 0))
    col['UV'][:] = 0.5                                                   # every UV on one point
    res = verdict([g, col])
    assert res['status'] == 'FAIL' and rules_of(res) == {('collapsed', None), ('untextured', None)}   # b+c: INC-035
    assert abs(res['metrics']['collapsed']['share'] - 9 / 109) < 1e-6


def test_just_at_the_floor_passes_and_just_below_fails():
    assert verdict([quads(10, 100.01, 2048)])['status'] == 'PASS'
    assert verdict([quads(10, 99.99, 2048)])['status'] == 'FAIL'


def test_an_unknown_page_size_is_incomplete_and_never_waived():
    g = quads(4, 107, 2048, page='shared_atlas')
    g.update(W=None, why='vanilla texture, size unknown')
    res = verdict([quads(10, 107, 2048), g], waivers=[dict(id='W-1', check='density_floor', owner_quote=OWNER[0]['text'],
                                                           msg='m7', at='2026-09-30')],
                  verify=lambda q, m=None: DF.find_quote(OWNER, q, m))
    assert res['status'] == 'FAIL' and res['findings'][0]['incomplete']
    assert 'page size unknown' in res['findings'][0]['text']


# ------------------------------------------------------------------------------------------------------ waivers
def waiver(**kw):
    w = dict(id='W-1', check='density_floor', model='ktc', owner_quote=OWNER[0]['text'], msg='m7', at='2026-09-30',
             recorded_by='test')
    w.update(kw)
    return [w]


def verify(q, m=None):
    return DF.find_quote(OWNER, q, m)


def test_a_page_waiver_exempts_that_page_and_the_rest_must_still_pass():
    low = [quads(10, 107, 2048), quads(6, 50, 512, page='matc')]          # the Korean TC shape: a low hidden page
    assert verdict(low, model='ktc')['status'] == 'FAIL'
    res = verdict(low, waivers=waiver(pages=['matc']), verify=verify, model='ktc')
    assert res['status'] == 'WAIVED' and res['waived_by'][0]['id'] == 'W-1'
    assert 'matc' in res['metrics_with_exempt_pages']['exempt']
    worse = [quads(10, 107, 2048), quads(6, 50, 512, page='matc'), quads(4, 30, 1024, page='P1024')]
    assert verdict(worse, waivers=waiver(pages=['matc']), verify=verify, model='ktc')['status'] == 'FAIL'


def test_only_the_whole_owner_message_waives():
    low = [quads(10, 95, 2048)]
    assert verdict(low, waivers=waiver(), verify=verify, model='ktc')['status'] == 'WAIVED'
    frag = verdict(low, waivers=waiver(owner_quote='nobody sees it'), verify=verify, model='ktc')
    assert frag['status'] == 'FAIL' and 'a fragment never waives' in frag['notes'][0]
    unverified = verdict(low, waivers=waiver(), verify=None, model='ktc')
    assert unverified['status'] == 'FAIL' and 'no owner message store' in unverified['notes'][0]
    assert verdict(low, waivers=waiver(model='other'), verify=verify, model='ktc')['status'] == 'FAIL'
    assert verdict(low, waivers=waiver(check='no_regression'), verify=verify, model='ktc')['status'] == 'FAIL'
    assert verdict(low, waivers=waiver(at=None), verify=verify, model='ktc')['status'] == 'FAIL'


def test_find_quote_reads_a_tracker_store():
    tracker = {'messages': {'2026-09-30': {'items': [{'id': 'm334', 'text': 'Plus we need  hard DPI floor!'}]}}}
    assert DF.find_quote(tracker, 'plus we need hard dpi floor!') == 'm334'
    assert DF.find_quote(tracker, 'hard DPI floor') is None
    assert DF.find_quote(tracker, 'plus we need hard dpi floor!', 'm1') is None


# ------------------------------------------------------------------------------------------------ recorded blocks
def test_a_recorded_block_gives_the_same_verdict():
    """the 03_uv HANDOFF "density" block is the measure() output, stored as JSON"""
    for groups in ([quads(10, 107, 2048)], [quads(10, 107, 2048), quads(3, 45, 2048, scatter=True, origin=(20, 0))]):
        m = DF.measure(groups, FLOOR)
        block = json.loads(json.dumps(m))
        assert DF.evaluate(block, FLOOR)['status'] == DF.evaluate(m, FLOOR)['status']


@pytest.mark.parametrize('edit,words', [
    (lambda b: b.pop('model'), 'no measured model'),
    (lambda b: b['model'].pop('share_below_face_floor'), 'share_below_face_floor'),
    (lambda b: b.update(face_floor=50), 'face floor of 50'),
    (lambda b: b.pop('collapsed'), 'collapsed-face share'),
    (lambda b: b['pages']['P2048'].update(share_below_face_floor='0'), 'page P2048'),
])
def test_a_missing_or_stale_block_is_incomplete(edit, words):
    b = json.loads(json.dumps(DF.measure([quads(10, 107, 2048)], FLOOR)))
    edit(b)
    res = DF.evaluate(b, FLOOR)
    assert res['status'] == 'FAIL' and all(f['incomplete'] for f in res['findings'])
    assert any(words in f['text'] for f in res['findings']), res['findings']
    assert DF.evaluate(None, FLOOR)['status'] == 'FAIL'


def test_another_game_overrides_the_numbers_never_the_rule(tmp_path):
    cfg = json.loads(DF.CONFIG.read_text(encoding='utf-8'))
    cfg['games']['othergame'] = dict(cfg['games']['aoe3de'], model_median_min=300.0, face_floor=200.0)
    p = tmp_path / 'floor.json'
    p.write_text(json.dumps(cfg), encoding='utf-8')
    other = DF.load_floor('othergame', p)
    m = DF.measure([quads(10, 250, 2048)], other)
    assert rules_of(DF.evaluate(m, other)) == {('model_median', None)}
    assert DF.evaluate(DF.measure([quads(10, 250, 2048)], FLOOR), FLOOR)['status'] == 'PASS'
    cfg['games']['bad'] = {'face_floor': 60}
    p.write_text(json.dumps(cfg), encoding='utf-8')
    with pytest.raises(DF.FloorError):
        DF.load_floor('bad', p)
    with pytest.raises(DF.FloorError):
        DF.load_floor('nosuchgame')


# ------------------------------------------------------------------------------------------------------ CLI
def npz(tmp_path, groups, name='faces.npz'):
    P = np.concatenate([g['P'] for g in groups])
    UV = np.concatenate([g['UV'] for g in groups])
    page = np.concatenate([[g['page']] * len(g['P']) for g in groups])
    names = list(dict.fromkeys(g['page'] for g in groups))
    size = {g['page']: g['W'] for g in groups}
    p = tmp_path / name
    np.savez(p, P=P, UV=UV, page=page, names=np.array(names), W=np.array([size[n] for n in names]),
             H=np.array([size[n] for n in names]))
    return p


def cli(*args):
    r = subprocess.run([sys.executable, str(HERE / 'density_floor.py'), *map(str, args)], capture_output=True, text=True)
    return r.returncode, r.stdout + r.stderr


def test_cli_exit_codes(tmp_path):
    good = npz(tmp_path, [quads(10, 107, 2048)], 'good.npz')
    bad = npz(tmp_path, [quads(10, 107, 2048), quads(3, 45, 2048, scatter=True, origin=(20, 0))], 'bad.npz')
    assert cli('faces', good)[0] == 0
    rc, out = cli('faces', bad)
    assert rc == 1 and 'FAIL' in out and 'below 60 t/u' in out
    rc, out = cli('faces', good, '--json')
    block = tmp_path / 'handoff.json'
    block.write_text(json.dumps({'density': json.loads(out)['metrics']}), encoding='utf-8')
    assert cli('block', block)[0] == 0
    assert cli('faces', tmp_path / 'missing.npz')[0] == 2
    assert cli('faces', good, '--game', 'nosuchgame')[0] == 2
    (tmp_path / 'w.json').write_text(json.dumps(waiver()), encoding='utf-8')
    (tmp_path / 'msgs.json').write_text(json.dumps(OWNER), encoding='utf-8')
    w = ('--model', 'ktc', '--waivers', tmp_path / 'w.json')
    assert cli('faces', bad, *w, '--owner-messages', tmp_path / 'msgs.json')[0] == 0
    assert cli('faces', bad, *w)[0] == 1                                       # no store: the waiver cannot count


# ------------------------------------------------------------------------------------------ the 03_uv handoff
M335 = ("yes, and 1024+2048 - not only TC. Let's say Medium size buildings (TC + Market + possibly some others.... "
        "building class can be discussed individually per model")


def store(tmp_path, extra=()):
    """the owner's message store: m335 (the Korean TC is medium) and m7 (a waiver about the ktc density floor)"""
    p = tmp_path / 'msgs.json'
    p.write_text(json.dumps([{'id': 'm335', 'text': M335}, *OWNER, *extra]), encoding='utf-8')
    return p


def block(tmp_path, groups=None, faces='faces.npz'):
    """a density block measured on the canonical UV file `faces` (its sha256 is the block's source)"""
    f = tmp_path / faces
    if not f.exists():
        f.write_bytes(f'the UV faces of {faces}'.encode())
    m = json.loads(json.dumps(DF.measure(groups or [quads(10, 107, 2048)], FLOOR)))
    m['source'] = {'file': faces, 'sha256': HO.sha(f)}
    return m


def uv_spec(tmp_path, **kw):
    (tmp_path / 'plan.json').write_text('{}', encoding='utf-8')
    spec = {'model': 'korean_tc', 'phase': '03_uv', 'status': 'review', 'producer': 'test', 'next': '04_bake',
            'canonical': {'plan': {'path': 'plan.json'}, 'uv_faces': {'path': 'faces.npz'}},
            'density': block(tmp_path), 'page_budget': {'pages': [{'name': 'P2048', 'size': 2048}]}}
    spec.update(kw)
    spec['workflow_checkpoint'] = freeze_fixture(tmp_path / 'workflow', spec['model'],
        {role: tmp_path / entry['path'] for role, entry in spec['canonical'].items()})
    p = tmp_path / 'HANDOFF.spec.json'
    p.write_text(json.dumps(spec), encoding='utf-8')
    return p


def write(tmp_path, capsys, owner=True, profiles=None, **kw):
    rc = HO.write(uv_spec(tmp_path, **kw), None, store(tmp_path) if owner else None, profiles)
    return rc, capsys.readouterr().out


def test_a_uv_handoff_records_density_and_budget_and_passes(tmp_path, capsys):
    rc, out = write(tmp_path, capsys)
    assert rc == 0 and 'HANDOFF WRITTEN' in out, out


def test_final_handoff_requires_freeze_not_clean_acceptance(tmp_path, capsys):
    p = uv_spec(tmp_path)
    spec = json.loads(p.read_text()); spec.pop('workflow_checkpoint')
    p.write_text(json.dumps(spec))
    assert HO.write(p, None, store(tmp_path)) == 3
    assert 'workflow_checkpoint' in capsys.readouterr().out
    spec['workflow_checkpoint'] = freeze_fixture(tmp_path / 'early', spec['model'],
        {role: tmp_path / entry['path'] for role, entry in spec['canonical'].items()}, through='clean')
    spec['status'] = 'wip'; p.write_text(json.dumps(spec))
    assert HO.write(p, None, store(tmp_path)) == 0
    spec['status'] = 'accepted'; p.write_text(json.dumps(spec))
    assert HO.write(p, None, store(tmp_path)) == 3
    assert 'requires freeze' in capsys.readouterr().out


@pytest.mark.parametrize('kw,words', [
    ({'density': None}, 'no density block recorded'),
    ({'page_budget': None}, 'no page_budget'),
])
def test_a_uv_handoff_without_the_records_is_invalid(tmp_path, capsys, kw, words):
    rc, out = write(tmp_path, capsys, **kw)
    assert rc == 3 and 'HANDOFF INVALID' in out and words in out, out


def test_a_uv_handoff_over_the_projects_ceiling_is_invalid(tmp_path, capsys):
    three = [quads(10, 107, 2048, page='a'), quads(4, 107, 1024, page='b'), quads(2, 107, 512, page='c')]
    rc, out = write(tmp_path, capsys, density=block(tmp_path, three),
                    page_budget={'pages': [{'name': 'a', 'size': 2048}, {'name': 'b', 'size': 1024},
                                           {'name': 'c', 'size': 512}]})
    assert rc == 3 and '3 pages over the medium ceiling of 2' in out, out
    rc, out = write(tmp_path, capsys, density=block(tmp_path, [quads(10, 107, 4096, page='a')]),
                    page_budget={'pages': [{'name': 'a', 'size': 4096}]})
    assert rc == 3 and 'a 4096 page over the ceiling slot 2048' in out, out


def test_a_uv_handoff_below_the_floor_is_invalid_unless_the_owner_waived_it(tmp_path, capsys):
    low = block(tmp_path, [quads(10, 95, 2048)])
    rc, out = write(tmp_path, capsys, density=low)
    assert rc == 3 and 'density floor FAIL' in out and 'median 95.0' in out
    rc, out = write(tmp_path, capsys, density=low, density_waivers=waiver(model='korean_tc'))
    assert rc == 0, out                                    # m7 names the ktc (a profile name) and the density floor


def test_a_wip_uv_handoff_may_stop_before_the_measurement(tmp_path, capsys):
    rc, out = write(tmp_path, capsys, status='wip', density=None, page_budget=None)
    assert rc == 0, out


# ---------------------------------------------------------- INC-034: nothing in a 03_uv handoff is self-declared
@pytest.mark.parametrize('pb,words', [
    # H1: small / m1 / [4096 x 3] declared in the spec: the Korean TC is medium (m335), ceiling [2048, 1024]
    ({'class': 'small', 'confirmed_by': 'm1', 'ceiling': [4096, 4096, 4096],
      'pages': [{'name': 'P2048', 'size': 2048}]}, "the spec's class small is not the project's medium"),
    ({'confirmed_by': 'm1', 'pages': [{'name': 'P2048', 'size': 2048}]}, "the spec's confirmed_by m1 is not"),
    ({'ceiling': [4096, 4096, 4096], 'pages': [{'name': 'P2048', 'size': 2048}]}, "the spec's ceiling"),
    # H4: an unknown class name
    ({'class': 'huge', 'ceiling': [8192], 'pages': [{'name': 'P2048', 'size': 2048}]}, "the spec's class huge"),
])
def test_inc034_the_class_and_ceiling_come_from_the_project(tmp_path, capsys, pb, words):
    """INC-034"""
    rc, out = write(tmp_path, capsys, page_budget=pb)
    assert rc == 3 and words in out, out


def test_inc034_the_class_confirmation_is_verified(tmp_path, capsys, monkeypatch):
    """INC-034: the owner's confirmation of the class resolves to his message: no store = not proven; a profile whose
    confirmed_by is not his message about the class fails"""
    prof = json.loads(HO.PROFILES.read_text(encoding='utf-8'))
    prof['tools']['owner_messages'] = str(tmp_path / 'no_store.json')
    alt = tmp_path / 'lint' / 'gr2_lint_profiles.json'
    alt.parent.mkdir()
    alt.write_text(json.dumps(prof), encoding='utf-8')
    lint = HO.project_lint(HO.PROFILES)                         # the project's lint, reading the altered profiles
    monkeypatch.setattr(HO, 'project_lint', lambda path: lint)
    rc, out = write(tmp_path, capsys, owner=False, profiles=alt)
    assert rc == 3 and 'cannot be verified' in out, out
    prof['profiles']['korean_tc']['texture_budget']['confirmed_by'] = 'm264'
    alt.write_text(json.dumps(prof), encoding='utf-8')
    rc, out = write(tmp_path, capsys, profiles=alt)
    assert rc == 3 and 'confirmed_by m264 is not an owner message' in out, out
    del prof['profiles']['korean_tc']['texture_budget']['confirmed_by']
    alt.write_text(json.dumps(prof), encoding='utf-8')
    rc, out = write(tmp_path, capsys, profiles=alt)
    assert rc == 3 and 'not confirmed by the owner' in out, out
    rc, out = write(tmp_path, capsys, model='no_such_model')
    assert rc == 3 and 'no_such_model has no profile' in out, out


def test_inc034_the_density_block_is_bound_to_the_canonical_uv(tmp_path, capsys):
    """INC-034: H2: a block measured on another model (another file) passed; so did a block without any source"""
    foreign = block(tmp_path, faces='other_model.npz')
    rc, out = write(tmp_path, capsys, density=foreign)
    assert rc == 3 and "which is none of this handoff's canonical files" in out, out
    unbound = block(tmp_path)
    del unbound['source']
    rc, out = write(tmp_path, capsys, density=unbound)
    assert rc == 3 and 'the block names no source' in out, out


def test_inc034_the_budget_pages_are_the_measured_pages(tmp_path, capsys):
    """INC-034: H3: the budget listed one 2048 page while the density block also measured a 512 page"""
    two = block(tmp_path, [quads(10, 107, 2048), quads(3, 107, 512, page='q512')])
    rc, out = write(tmp_path, capsys, density=two)
    assert rc == 3 and 'are not the pages the density block measured' in out, out
    rc, out = write(tmp_path, capsys, density=two, page_budget={'pages': [{'name': 'P2048', 'size': 2048},
                                                                          {'name': 'q512', 'size': 512}]})
    assert rc == 0, out


def test_inc034_a_block_in_another_unit_is_incomplete(tmp_path, capsys):
    """INC-034: D7: a block in texels per centimetre (numbers x100) passed the rule"""
    cm = block(tmp_path, [quads(10, 50, 2048)])
    cm['unit'] = 'texels per centimetre'
    cm['model'].update(p50=5000.0, p2=5000.0, share_below_face_floor=0.0)
    rc, out = write(tmp_path, capsys, density=cm)
    assert rc == 3 and 'INCOMPLETE' in out and 'unit' in out, out


def test_inc034_the_cli_measures_the_source_into_the_block(tmp_path):
    """INC-034"""
    good = npz(tmp_path, [quads(10, 107, 2048)], 'good.npz')
    rc, out = cli('faces', good, '--json')
    assert rc == 0 and json.loads(out)['metrics']['source'] == {'file': 'good.npz', 'sha256': HO.sha(good)}


# ------------------------------------------------------------------------ INC-035: dilution, b + c, scatter
def stack(n, density, W, page, origin=(-500.0, -500.0), shift=0.0):
    """n hidden unit quads far from the model whose UVs all sit on the texels of the model's first quad (a stack),
    each one shifted by `shift` UV units (a partial overlap, the verifier's evasion)"""
    one = quads(1, density, W, page=page)
    P = np.concatenate([one['P'] + [origin[0] + 2.0 * i, origin[1], -10.0] for i in range(n)])
    UV = np.concatenate([one['UV'] + [shift * (i % 3) / 3, 0.0] for i in range(n)])
    return dict(page=page, W=W, H=W, P=P, UV=UV)


def test_inc035_stacked_hidden_faces_do_not_dilute_rule_b():
    """INC-035: the verifier turned the shipped KTC from FAIL to PASS with hidden quads whose UVs are stacked on texels
    the model already uses. A stacked face adds no texture: rule b counts each texel region once (its largest face)"""
    base = [quads(10, 107, 2048), quads(3, 40, 512, page='P512')]            # 9 of 109 u2 at 40 t/u
    assert ('face_floor', None) in rules_of(verdict(base))
    for shift in (0.0, 0.5 * 107 / 2048):                                    # exact and partial stacks
        diluted = base + [stack(400, 107, 2048, 'P2048', shift=shift), stack(400, 107, 512, 'P512', shift=shift)]
        res = verdict(diluted)
        m = res['metrics']['model']
        assert m['share_below_face_floor'] < FLOOR['face_max_share_below']         # the raw share is fooled
        assert res['status'] == 'FAIL' and {('face_floor', None), ('face_floor', 'P512')} <= rules_of(res), shift
        assert m['share_below_face_floor_owned'] > 0.05 and m['stacked_share'] > 0.5
        assert 'texel-owning area' in ' '.join(f['text'] for f in res['findings'])


def test_inc035_b_and_c_are_capped_together():
    """INC-035: 1.9 % of the area at 2 t/u (under b's 2 %) plus 2.9 % collapsed (under c's 3 %) = 4.8 % untextured: FAIL"""
    good = quads(20, 120, 2048)
    tot = 400 / (1 - 0.019 - 0.029)
    k = np.sqrt(tot * 0.019)
    low = quads(1, 2.0 * k, 2048, origin=(100, 0))                          # 2 t/u once scaled by k
    low['P'] = (low['P'] - [100, 0, 0]) * k + [100, 0, 0]
    col = quads(1, 120, 2048, origin=(200, 0))
    col['P'] = (col['P'] - [200, 0, 0]) * np.sqrt(tot * 0.029) + [200, 0, 0]
    col['UV'][:] = 0.9
    res = verdict([good, low, col])
    assert res['status'] == 'FAIL' and rules_of(res) == {('untextured', None)}, rules_of(res)
    assert abs(res['metrics']['untextured']['share'] - 0.048) < 1e-3
    assert (FLOOR['untextured_max_share'], FLOOR['untextured_max_share_owned'],
            FLOOR['face_max_share_below_owned']) == (0.035, 0.08, 0.03)


def test_inc035_fragmentation_is_measured_against_a_proposed_ceiling_only():
    """INC-035: the owner's "scattered UV map": 4444 islands per 100 u2 at a uniform 101 t/u. The fragmentation ceiling is a
    PROPOSAL (vanilla max 178, the KTC 278): reported, never a FAIL until the owner confirms it"""
    frag = DF.load_fragmentation('aoe3de')
    assert frag['status'] == 'proposed, owner to confirm' and frag['islands_per_100u2_max'] == 200
    g = quads(12, 101 * 0.2, 2048, scatter=True)                # 0.2 u islands once scaled: 2500 per 100 u2
    g['P'] = g['P'] * 0.2
    res = verdict([g])
    assert res['status'] == 'PASS' and res['metrics']['model']['islands_per_100u2'] > 2000
    assert abs(res['metrics']['model']['p50'] - 101) < 0.5
    note = ' '.join(res['notes'])
    assert 'above the proposed fragmentation ceiling 200' in note and 'owner to confirm' in note
    assert 'proposed ceiling 200' in res['summary']


def test_inc035_an_old_block_is_incomplete():
    """a block measured before INC-035 (schema 1: its b could be diluted) or in another unit (texels per cm) is
    INCOMPLETE: measure again"""
    b = json.loads(json.dumps(DF.measure([quads(10, 107, 2048)], FLOOR)))
    assert DF.evaluate(b, FLOOR)['status'] == 'PASS'
    old = dict(b, schema=1)
    assert any('schema 1' in f['text'] for f in DF.evaluate(old, FLOOR)['findings'])
    cm = dict(b, unit='texels per centimetre')
    res = DF.evaluate(cm, FLOOR)
    assert res['status'] == 'FAIL' and any('unit' in f['text'] and f['incomplete'] for f in res['findings'])


# ------------------------------------------------------------------------ INC-036: generic messages never waive
GENERIC = [{'id': 'm278', 'text': 'approve'}, {'id': 'm264', 'text': 'yes'},
           {'id': 'm8', 'text': 'Waive the density floor for the ktc hidden matc page, nobody sees it.'}]
DECISIONS = {'decisions': {'D-9': {'question': 'ktc: leave the matc page out of the density floor?',
                                   'options': [{'key': 'A', 'label': 'measure it'}, {'key': 'B', 'label': 'waive it'}],
                                   'record': {'option': 'B', 'at': '2026-09-30T12:00:00Z'}}},
             'messages': {'d': {'items': GENERIC}}}


def test_inc036_a_generic_whole_message_never_waives():
    """INC-036"""
    low = [quads(10, 107, 2048), quads(6, 50, 512, page='matc')]
    store = DF.OwnerStore(DECISIONS)
    for mid, text in (('m278', 'approve'), ('m264', 'yes')):
        for pages in (None, ['matc']):
            res = verdict(low, waivers=waiver(owner_quote=text, msg=mid, **({'pages': pages} if pages else {})),
                          verify=store, model='ktc')
            assert res['status'] == 'FAIL' and 'does not name the density floor and the model' in ' '.join(res['notes'])
    ok = verdict(low, waivers=waiver(owner_quote=GENERIC[2]['text'], msg='m8', pages=['matc']), verify=store, model='ktc')
    assert ok['status'] == 'WAIVED'
    other = verdict(low, waivers=waiver(owner_quote=GENERIC[2]['text'], msg='m8', model='mkt', pages=['matc']),
                    verify=store, model='mkt')
    assert other['status'] == 'FAIL'                                       # names another model
    nomodel = [dict(w, model=None) for w in waiver(owner_quote=GENERIC[2]['text'], msg='m8', pages=['matc'])]
    assert verdict(low, waivers=nomodel, verify=store, model='ktc')['status'] == 'FAIL'   # the waiver names its model


def test_inc036_an_answered_decision_about_this_floor_waives():
    """INC-036"""
    low = [quads(10, 107, 2048), quads(6, 50, 512, page='matc')]
    store = DF.OwnerStore(DECISIONS)
    w = [dict(id='W-2', check='density_floor', model='ktc', pages=['matc'], decision='D-9', option='B',
              at='2026-09-30T12:00:00Z', recorded_by='test')]
    assert verdict(low, waivers=w, verify=store, model='ktc')['status'] == 'WAIVED'
    assert verdict(low, waivers=[dict(w[0], option='A')], verify=store, model='ktc')['status'] == 'FAIL'
    assert verdict(low, waivers=[dict(w[0], decision='D-404')], verify=store, model='ktc')['status'] == 'FAIL'
