"""gr2_props.py: the props page is found by its texture (never the slot letter), every placed prop is matched per
placement, a props-free stage must draw nothing on the page, and a missing manifest or gate is SKIP, never a pass.

    python -m pytest scripts/havok/tests/test_gr2_props.py -q
"""
import json
import os
import sys
from pathlib import Path

import numpy as np
import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import gr2_lint  # noqa: E402
import gr2_props as GP  # noqa: E402

HOUSE = '''<material>
  <submaterial name="matc"><parameters><texture name="BaseColor" override="buildings\\korean_shared\\textures\\korean_shared_matc_r65_BaseColor" /></parameters></submaterial>
  <submaterial name="matd"><parameters><texture name="BaseColor" override="buildings\\korean_tc\\textures\\korean_tc_mata_BaseColor" /></parameters></submaterial>
  <submaterial name="mate"><parameters><texture name="BaseColor" override="buildings\\korean_shared\\textures\\korean_shared_props_r6_BaseColor" /></parameters></submaterial>
</material>'''


def cube(c, h=0.1):
    v = np.array([[x, y, z] for z in (-1, 1) for y in (-1, 1) for x in (-1, 1)], float) * h + c
    q = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
    return v, np.array([(a, b, c_) for a, b, c_, d in q] + [(a, c_, d) for a, b, c_, d in q])


class StubGate:
    """stands in for Blendify composition_gate: one group per placement, matched by triangle count only"""
    @staticmethod
    def match_groups(groups, pos, tris):
        ok = len(tris) == sum(g['tris'] for g in groups.values())
        return dict(ok=ok, summary=('PASS' if ok else 'FAIL') + f' {len(tris)} tris', missing=[], partial={}, extra=0)


def house(tmp_path, props_on='mate'):
    mat = tmp_path / 'korean_house_a.material'; mat.write_text(HOUSE)
    pottery, props = cube((0, 0, 0)), cube((1, 0, 0))
    mesh = lambda name, slot, m: dict(name=name, mats=[slot], groups=[(0, 0, len(m[1]))], pos=m[0], tris=m[1])
    info = dict(render=[mesh('r58_pottery_3', 'matd', pottery), mesh('r58_props_4', props_on, props)])
    man = dict(page='korean_shared_props_r6', stages=dict(intact=dict(props='all'), construction=dict(props='none')),
               placements=[dict(id='House.Prop.Onggi.0', prop='Onggi', tris=12, area=0.0, points_mm=[])])
    return info, str(mat), man


def test_slot_pages_by_texture_not_letter(tmp_path):
    info, mat, _ = house(tmp_path)
    assert GP.slot_pages(mat) == dict(matc='korean_shared_matc_r65', matd='korean_tc_mata', mate='korean_shared_props_r6')
    rows = GP.composition(info, GP.slot_pages(mat))
    assert [(r['slot'], r['page'], r['tris']) for r in rows] == [('matd', 'korean_tc_mata', 12),
                                                                  ('mate', 'korean_shared_props_r6', 12)]


def test_props_stage_reads_only_the_props_page(tmp_path):
    info, mat, man = house(tmp_path)
    ok, msg, _ = GP.check_stage(man, 'intact', info, mat, StubGate)
    assert ok and "['mate']" in msg                       # the TC pottery on matd is not counted as props


def test_props_free_stage_must_draw_nothing_on_the_page(tmp_path):
    info, mat, man = house(tmp_path)
    ok, msg, _ = GP.check_stage(man, 'construction', info, mat, StubGate)
    assert ok is False and '12 triangles on korean_shared_props_r6' in msg


def test_wrong_page_version_fails(tmp_path):
    info, mat, man = house(tmp_path)
    man['page'] = 'korean_shared_props_r6_2'
    ok, msg, _ = GP.check_stage(man, 'intact', info, mat, StubGate)
    assert ok is False and 'no slot binds the props page korean_shared_props_r6_2' in msg


def test_dropped_props_mesh_fails(tmp_path):
    info, mat, man = house(tmp_path)
    info['render'].pop()                                   # the props mesh is not bound any more
    ok, msg, _ = GP.check_stage(man, 'intact', info, mat, StubGate)
    assert ok is False


def test_lint_check_without_manifest_is_skip(tmp_path):
    info, mat, _ = house(tmp_path)
    prof = dict(props_manifest=dict(path='missing.json'), _root=str(tmp_path))
    r = GP.lint_check('intact', info, mat, prof, gr2_lint.R)
    assert r['check'] == 'props' and r['status'] == 'SKIP' and 'not proven' in r['summary']


def test_lint_check_maps_the_lint_stage(tmp_path):
    info, mat, man = house(tmp_path)
    (tmp_path / 'm.json').write_text(json.dumps(man))
    prof = dict(props_manifest=dict(path='m.json', stages=dict(intact='construction')), _root=str(tmp_path))
    r = GP.lint_check('intact', info, mat, prof, gr2_lint.R)   # a _con profile lints its model as 'intact'
    assert r['status'] == 'FAIL' and 'the manifest says no props' in r['summary']


GATE = GP.find_gate()


def signed(pos, tris):
    s = GATE.signature(pos, tris)
    return dict(id='all', prop='all', tris=s['tris'], area=s['area'],
                points_mm=np.round(np.asarray(s['points']) * 1000).astype(int).tolist())
ADDON = Path(os.environ.get('KOREAN_ADDON_REPO') or Path(__file__).resolve().parents[3] / 'age-of-pirates-koreans')
CONSULATE = ADDON / 'art' / 'buildings' / 'korean_consulate'


@pytest.mark.skipif(GATE is None or not CONSULATE.is_dir(),
                    reason='needs Blendify composition_gate ($BLENDIFY_REPO) and the Koreans add-on ($KOREAN_ADDON_REPO)')
def test_real_consulate_props_survive_retriangulation_and_a_cut_fails():
    """the installed Korean Consulate: the damaged GR2 re-triangulated its props (2724 of 7472 triangle centroids moved
    up to 13 cm), so the page signature of the intact model must still match it; a cut of 100 triangles must not"""
    pages = GP.slot_pages(CONSULATE / 'korean_consulate.material')
    intact = gr2_lint.read_raw(str(CONSULATE / 'korean_consulate.gr2'))
    pos, tris, slots = GP.page_mesh(intact, pages, 'korean_shared_props_r6')
    assert slots == ['matd'] and len(tris) == 7472
    man = dict(page='korean_shared_props_r6', stages=dict(damaged=dict(props='all'), construction=dict(props='none')),
               placements=[signed(pos, tris)])
    damaged = gr2_lint.read_raw(str(CONSULATE / 'korean_consulate_damaged.gr2'))
    assert GP.check_stage(man, 'damaged', damaged, str(CONSULATE / 'korean_consulate_damaged.material'), GATE)[0]
    con = gr2_lint.read_raw(str(CONSULATE / 'korean_consulate_con.gr2'))
    assert GP.check_stage(man, 'construction', con, str(CONSULATE / 'korean_consulate_con.material'), GATE)[0]
    cut = dict(render=[dict(m, tris=m['tris'][:-100], groups=[(0, 0, len(m['tris']) - 100)]) if m['mats'] == ['matd']
                       else m for m in damaged['render']])
    ok, msg, res = GP.check_stage(man, 'damaged', cut, str(CONSULATE / 'korean_consulate_damaged.material'), GATE)
    assert ok is False and res['partial']['all']['tris'] == [7372, 7472], msg
