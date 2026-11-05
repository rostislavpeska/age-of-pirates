"""gr2_reskeleton.py (2026-10-09): the Shaolin Disciple mesh on the yabusame rider skeleton, so cavalry animations drive
a bald monk (Koreans add-on, tools/korean_monk_model.py).

    python -m pytest scripts/havok/tests/test_gr2_reskeleton.py -q

Vanilla bytes are read from the game archives into the test's temp folder (never the repo, AGENTS.md rule 3); without a
game install the tests skip.
"""
from __future__ import annotations

import sys
from pathlib import Path

import pytest

HAVOK = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(HAVOK))
import gr2_lint as L  # noqa: E402
from gr2_fixups import orphan_fixups  # noqa: E402
from gr2_read import Gr2  # noqa: E402
from gr2_reskeleton import build, model, skeleton  # noqa: E402

RIDER = 'art/units/asians/japanese/yabusame/yabusamerider_0.gr2'
DISCIPLE = 'art/units/asians/chinese/shaolin_disciple/shaolin_disciple_01.gr2'
HORSE = 'art/units/asians/japanese/yabusame/yabusamehorse_0.gr2'


def vanilla(tmp_path, rel):
    bt, index = L._bartool()
    entry = index.get(rel.lower()) if bt else None
    if entry is None:
        pytest.skip(f'game archives not readable here ({rel})')
    p = tmp_path / Path(rel).name
    p.write_bytes(bt.read_entry(entry))
    return p


def test_disciple_takes_the_rider_skeleton_and_keeps_every_mesh_byte(tmp_path):
    donor, target = vanilla(tmp_path, RIDER), vanilla(tmp_path, DISCIPLE)
    out = tmp_path / 'korean_monk_rider.gr2'
    build(str(donor), str(target), str(out), 0.005)
    gd, gt, go = Gr2(str(donor)), Gr2(str(target)), Gr2(str(out))
    assert go.crc_check() and not orphan_fixups(out)['orphans']
    skd, sko = skeleton(gd), skeleton(go)
    assert [b['Name'] for b in sko['bones']] == [b['Name'] for b in skd['bones']]
    assert [b['ParentIndex'] for b in sko['bones']] == [b['ParentIndex'] for b in skd['bones']]
    assert sko['rec']['Name'] == model(go)['rec']['Name'] == 'Bip01_Root'
    for i in range(gt.sec_count):                       # vertex, index and every other target section unchanged
        if gt.sections[i]['data_size']:
            changed = sum(1 for x, y in zip(gt.payload[i], go.payload[i]) if x != y)
            assert len(gt.payload[i]) == len(go.payload[i]) and changed <= (1 if i == 0 else 0), (i, changed)


def test_refuses_a_donor_without_the_bound_bones(tmp_path):
    donor, target = vanilla(tmp_path, HORSE), vanilla(tmp_path, DISCIPLE)
    with pytest.raises(SystemExit, match='missing from the donor'):
        build(str(donor), str(target), str(tmp_path / 'x.gr2'), 0.005)
