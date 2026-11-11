"""Synthetic tests for mod_overlap.py (no game install needed).

    python -m pytest .claude/skills/aoe3de-multi-mod/scripts -q
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mod_overlap  # noqa: E402


def make(profile, title, prio, files, enabled=True):
    base = profile / 'local' / title
    for rel in files:
        p = base / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text('x')
    return {'Title': title, 'Path': 'local\\' + title, 'WorkshopID': 0, 'Priority': prio, 'Enabled': enabled}


def profile_with(tmp_path, mods):
    (tmp_path / 'age3-mod-status.json').write_text(json.dumps({'Actions': [], 'Mods': mods}))
    return str(tmp_path)


def test_lower_priority_number_wins_and_mods_files_merge(tmp_path):
    mods = [make(tmp_path, 'addon', 2, ['art/b/Consulate.xml', 'data/protomods.xml', 'data/protomods.xml.xmb']),
            make(tmp_path, 'base', 1, ['art/b/consulate.xml', 'data/protomods.xml', 'data/protomods.xml.xmb']),
            make(tmp_path, 'off', 3, ['art/b/consulate.xml'], enabled=False)]
    p = profile_with(tmp_path, mods)
    rows = mod_overlap.overlaps(p, mod_overlap.load_mods(p))
    shadow = [r for r in rows if not r['additive']]
    assert [(r['winner'], r['loser']) for r in shadow] == [('base', 'addon')]     # case-insensitive match, disabled ignored
    assert sum(r['additive'] for r in rows) == 2
    assert mod_overlap.main(['--profile', p, '--fail']) == 1
    assert mod_overlap.main(['--profile', p, '--fail', '--allow', 'art/b/consulate.xml']) == 0
    assert mod_overlap.main(['--profile', p]) == 0


def test_named_mods_and_unknown_title(tmp_path):
    mods = [make(tmp_path, 'a', 1, ['sound/x_snds.xml']), make(tmp_path, 'b', 2, ['sound/x_snds.xml'])]
    p = profile_with(tmp_path, mods)
    assert mod_overlap.main(['--profile', p, '--mods', 'a', 'b', '--fail']) == 1
    try:
        mod_overlap.main(['--profile', p, '--mods', 'a', 'nope'])
    except SystemExit as e:
        assert 'nope' in str(e)
    else:
        raise AssertionError('unknown title accepted')
