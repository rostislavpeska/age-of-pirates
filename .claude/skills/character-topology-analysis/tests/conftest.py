"""Shared fixtures. The package holds no device paths: the reference and Blender tests read their inputs from the
environment and skip with the reason when one is missing.

    CTA_LIBRARY_ROOT   the reference library root (folders <id>/..., read only)
    CTA_MPFB_DATA      the MPFB2 data folder (3dobjs/base.obj = the CC0 hm08 base mesh, read directly)
    CTA_VERIFIER_DATA  the step-2 verifier's data folder (S01/S14/S15 *_glb.json, compare_t2q.json, my_t2q_measures.json)
    CTA_GAME_PROFILE   a game profile JSON made by profile_from_survey.py (the G1 squat-head control)
    CTA_OWN_G1         our Pyeongon G1 r2 .blend (object Pyeongon_G1_LOW_Body)
    BLENDER            the Blender executable (else PATH / the standard install folder via blender_env)
"""
import json
import os
import sys

import pytest

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPTS = os.path.join(os.path.dirname(HERE), 'scripts')
REFS = os.path.join(os.path.dirname(HERE), 'references')
for p in (SCRIPTS, HERE):
    if p not in sys.path:
        sys.path.insert(0, p)


def _env_dir(name):
    v = os.environ.get(name)
    if not v or not os.path.exists(v):
        pytest.skip('%s not set or missing (reference test)' % name)
    return v


@pytest.fixture(scope='session')
def library_root():
    return _env_dir('CTA_LIBRARY_ROOT')


@pytest.fixture(scope='session')
def mpfb_data():
    d = _env_dir('CTA_MPFB_DATA')
    if not os.path.isfile(os.path.join(d, '3dobjs', 'base.obj')):
        pytest.skip('CTA_MPFB_DATA has no 3dobjs/base.obj')
    return d


@pytest.fixture(scope='session')
def verifier_data():
    return _env_dir('CTA_VERIFIER_DATA')


@pytest.fixture(scope='session')
def blender():
    import tl_io
    exe = tl_io.blender_exe(os.environ.get('BLENDER'))
    if not exe:
        pytest.skip('no Blender found (set BLENDER)')
    return exe


@pytest.fixture(scope='session')
def calibration_items():
    return json.load(open(os.path.join(REFS, 'calibration_items.json'), encoding='utf-8'))


def item_path(it, roots):
    p = it['path']
    for k, v in roots.items():
        p = p.replace('<%s>' % k, v)
    return p


def load_item(it, roots, exclude=None, need_t2q=False, blender=None):
    import tl_io
    return tl_io.load(item_path(it, roots), select=it.get('select'), group=it.get('group'), up=it.get('up'),
                      rot=it.get('rot'), joints_from_groups=it.get('joints_from_groups'), collection=it.get('collection'),
                      exclude=exclude, need_t2q=need_t2q, blender=blender)
