"""area_probe.instrument: a probe block right after the named area's rmBuildArea, one marker proto per area."""
from __future__ import annotations

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[3]))

from scripts.mapsim.area_probe import PROTOS, instrument  # noqa: E402

SRC = """void main(void) {
	int northID = rmCreateArea("north shore");
	rmSetAreaSize(northID, 0.5, 0.5);
	rmBuildArea(northID);
	int innerID = rmCreateArea("inner shore");
	rmBuildArea(innerID);
}
"""


def test_block_follows_each_build_with_its_own_marker():
    out, mapping = instrument(SRC, ["north shore", "inner shore"], 8)
    assert mapping == {"north shore": PROTOS[0], "inner shore": PROTOS[1]}
    i_build = out.index("rmBuildArea(northID);")
    i_probe = out.index('rmCreateAreaConstraint("area probe in 0", northID)')
    assert i_build < i_probe < out.index('int innerID = rmCreateArea("inner shore");')
    assert 'rmAddObjectDefItem(probeDef1, "%s", 1, 0.0);' % PROTOS[1] in out
    assert "for (pgx0=0; < 8)" in out and "(1.0*pgx0 + 0.5) / 8.0" in out   # float first: no int * float truncation


def test_unknown_area_is_refused():
    with pytest.raises(SystemExit):
        instrument(SRC, ["west shore"], 8)
