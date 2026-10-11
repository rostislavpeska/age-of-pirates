"""organic_layout.py and island_priority.py on the synthetic flat body (host Python: numpy, scipy, Pillow; no Blender,
CI-safe). Checks: exact mirror twins with unique texels, a symmetric centre island, upright islands, the gutter
measured by uvlib (not trusted from the packer halo), no overlap or flip, island multipliers and the head calibration
on the bone-region estimator."""
import copy
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
import island_priority as IP  # noqa: E402
import organic_layout as OL  # noqa: E402
import synthetic as S  # noqa: E402
import uvlib as L  # noqa: E402

PAGE = 256
GUTTER = 8.0


def config(**extra):
    cfg = {'schema': OL.SCHEMA_CONFIG, 'pages': [{'name': 'body', 'size': PAGE, 'gutter_px': GUTTER,
                                                   'objects': ['Body']}], 'mirror_objects': ['Body'],
           'search': {'iters': 12}}
    cfg.update(extra)
    return cfg


@pytest.fixture(scope='module')
def flat():
    return S.flat_body()


@pytest.fixture(scope='module')
def plain(flat):
    d, raw = flat
    out, ok = OL.run(d, raw, config(), log=lambda s: None)
    assert ok, out['report']['problems']
    return d, out


def triangles(d, out):
    o = d['objects']['Body']
    P = np.array(o['co'], float)
    F, UV, parts = [], [], []
    for poly, uvs, part in zip(o['polys'], out['objects']['Body']['polys'], o['parts']):
        for k in range(1, len(poly) - 1):
            F.append([poly[0], poly[k], poly[k + 1]])
            UV.append([uvs[0], uvs[k], uvs[k + 1]])
            parts.append(part)
    return P, np.array(F), np.array(UV, float), parts


def test_groups_and_kinds(plain):
    d, out = plain
    kinds = sorted(g['kind'] for g in out['report']['pages'][0]['groups'])
    assert kinds == ['centre_symmetric', 'centre_symmetric', 'lateral_pair_unique']
    assert not out['report']['problems']


def test_unique_texels_gutter_and_no_flips(plain):
    d, out = plain
    P, F, UV, _ = triangles(d, out)
    fm = L.face_metrics(P, F, UV, PAGE)
    assert not fm['flipped'].any()
    assert UV.min() >= 0 and UV.max() <= 1
    assert L.tri_overlaps(UV, 1e-12) == []
    edges = L.edge_table(F, UV)
    lab = L.islands(len(F), edges)
    assert len(set(lab)) == 4                                     # torso, head, two arms: nothing stacked
    seg, sid = L.outline_segments(edges, lab)
    gaps = L.island_gaps(seg, sid)
    assert min(v[0] for v in gaps.values()) * PAGE >= GUTTER
    # one shared density: every face at the page density (no priority given)
    assert np.allclose(fm['density'], out['report']['pages'][0]['density_t_per_m'], rtol=1e-6)


def test_mirror_twins_are_exact_reflections(plain):
    d, out = plain
    o = d['objects']['Body']
    mm = o['mirror_map']
    uv = out['objects']['Body']['polys']
    polys = o['polys']
    idx = {frozenset(f): i for i, f in enumerate(polys)}
    arm_plus = [i for i, p in enumerate(o['parts']) if p == 'sleeve' and np.mean([o['co'][v][0] for v in polys[i]]) > 0]
    for f in arm_plus:
        g = idx[frozenset(mm[v] for v in polys[f])]
        for k, v in enumerate(polys[f]):
            a = np.array(uv[f][k])
            b = np.array(uv[g][polys[g].index(mm[v])])
            assert b[1] == pytest.approx(a[1], abs=1e-12)          # same height, reflected across one vertical line
        us = [uv[f][k][0] + uv[g][polys[g].index(mm[v])][0] for k, v in enumerate(polys[f])]
        assert max(us) - min(us) < 1e-9


def test_centre_island_is_symmetric_and_upright(plain):
    d, out = plain
    P, F, UV, parts = triangles(d, out)
    o = d['objects']['Body']
    mm = o['mirror_map']
    cvert = {}
    for poly, uvs, part in zip(o['polys'], out['objects']['Body']['polys'], o['parts']):
        if part == 'coat':
            for v, u in zip(poly, uvs):
                cvert[v] = np.array(u)
    axis = np.mean([u[0] for v, u in cvert.items() if abs(o['co'][v][0]) < 1e-9])
    for v, u in cvert.items():
        w = cvert[mm[v]]
        assert u[0] + w[0] == pytest.approx(2 * axis, abs=1e-9) and u[1] == pytest.approx(w[1], abs=1e-9)
    unit, w = L.up_in_uv(P, F, UV)
    lab = L.islands(len(F), L.edge_table(F, UV))
    for ang, coh, wt in L.island_orientation(unit, w, lab, int(lab.max()) + 1):
        assert abs(ang) < 1e-6                                     # 3D up = +V on every island


def test_priority_multiplier_and_hidden_cap(flat):
    d, raw = flat
    nv = {'Body': [p == 'face' for p in d['objects']['Body']['parts']]}
    prio = {'factors': {'face': 1.5, 'sleeve': 1.2}, 'never_visible': nv, 'hidden_cap': 0.75}
    out, ok = OL.run(d, raw, config(priority=prio), log=lambda s: None)
    m = {tuple(g['parts']): g['multiplier'] for g in out['report']['pages'][0]['groups']}
    assert m[('sleeve',)] == pytest.approx(1.2) and m[('coat',)] == pytest.approx(1.0)
    assert m[('face',)] == pytest.approx(0.75)                     # all faces hidden: the capped factor


def test_head_calibration_hits_the_bone_region_target(flat):
    d, raw = flat
    cfg = config(priority={'factors': {'face': 1.5}}, head_target={'ratio': 1.3, 'objects': ['Body']})
    out, ok = OL.run(d, raw, cfg, log=lambda s: None)
    cal = out['report']['head_calibration']
    assert ok and cal['applied'] and cal['ratio_before'] == pytest.approx(1.5, rel=1e-6)
    assert cal['head_groups'] == ['Body:c1']
    r = IP.layout_ratio(d, out)['Body']
    assert r['ratio'] == pytest.approx(1.3, abs=1e-3)
    cfg['head_target']['ratio'] = 9.0
    out, ok = OL.run(d, raw, cfg, log=lambda s: None)
    assert not out['report']['head_calibration']['applied']
    assert any('head calibration' in p for p in out['report']['problems'])


def test_calibrate_and_region_density_units():
    ent = lambda s: IP.region_density([('head', 1.0, 1.0, 1.0 * s), ('torso', 2.0, 2.0, 1.0)])  # noqa: E731
    dens, ratio = ent(1.0)
    assert dens == {'head': 1.0, 'torso': 1.0} and ratio == 1.0
    s, r = IP.calibrate(ent, 1.3)
    assert s == pytest.approx(1.3, abs=1e-4) and r == pytest.approx(1.3, abs=1e-4)
    assert IP.calibrate(ent, 10.0)[0] is None
    assert IP.island_multiplier([0, 1], [2.0, 1.0], np.array([False, True]), [1.0, 3.0]) == 2.0
    assert IP.island_multiplier([0, 1], [2.0, 1.0], np.array([True, True]), [1.0, 3.0]) == 1.25
    assert IP.poly_area_uv([[0, 0], [1, 0], [1, 1], [0, 1]]) == 1.0
    assert IP.poly_area3d(np.eye(3), [0, 1, 2]) == pytest.approx(math.sqrt(3) / 2)


def test_setup_errors(flat):
    d, raw = flat
    with pytest.raises(SystemExit):
        OL.run(d, raw, dict(config(), schema='wrong'), log=lambda s: None)
    two = config()
    two['pages'].append({'name': 'b', 'size': 128, 'objects': ['Body']})
    with pytest.raises(SystemExit):
        OL.run(d, raw, two, log=lambda s: None)                   # one object on two pages
    bad = copy.deepcopy(raw)
    bad['objects']['Body']['polys'][0]['v'] = [0, 1, 2, 99]
    with pytest.raises(SystemExit):
        OL.run(d, bad, config(), log=lambda s: None)


def test_cli_and_repo_refusal(flat, tmp_path):
    d, raw = flat
    files = {}
    for k, v in (('dump', d), ('raw', raw), ('cfg', config())):
        files[k] = tmp_path / ('%s.json' % k)
        files[k].write_text(json.dumps(v), encoding='utf-8')
    out = tmp_path / 'layout.json'
    cmd = [sys.executable, '-B', str(SCRIPTS / 'organic_layout.py'), str(files['dump']), str(files['raw']),
           str(files['cfg']), '--quiet', '--out']
    p = subprocess.run(cmd + [str(out)], capture_output=True, text=True)
    assert p.returncode == 0, p.stdout + p.stderr
    assert json.loads(out.read_text())['schema'] == OL.SCHEMA_OUT
    assert (tmp_path / 'layout_report.json').is_file()
    inside = TESTS / '_refused_layout.json'
    p = subprocess.run(cmd + [str(inside)], capture_output=True, text=True)
    assert p.returncode == 2 and not inside.exists()
