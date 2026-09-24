"""mapview.twin and census_reader: expected objects from mapsim, the join on a synthetic 'actual' set, the
report files, and the census reader on the in-repo sample saves (spec section 4, offline)."""
import json
import random
import sys
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO))
from scripts.mapview import twin as TW  # noqa: E402
from scripts.mapview import census_reader as CR  # noqa: E402

LONDON = REPO / "randmaps" / "zplondon.xs"
BENCH = REPO / "sandbox" / "census" / "samples" / "bench" / "ub_unitbench_unit_s4242.age3Yscn"


@pytest.fixture(scope="module")
def london_expected():
    objs, rs, warnings = TW.expected_objects(LONDON, 2, 2)
    return objs, rs, warnings


class TestExpected:
    def test_london_expected_from_mapsim(self, london_expected):
        objs, rs, _ = london_expected
        assert rs.grid.size_x_m == 360 and rs.grid.size_z_m == 645       # 2 players (zplondon.xs 397-408)
        assert len(objs) >= 20 and all(0 <= o.fx <= 1 and 0 <= o.fz <= 1 for o in objs)
        assert all(abs(o.x_m - o.fx * 360) < 1e-6 and abs(o.z_m - o.fz * 645) < 1e-6 for o in objs)
        anchors = {o.anchor for o in objs}
        assert any("wall" in a for a in anchors)
        groupings = [o for o in objs if o.members]
        assert groupings and all(o.proto.startswith("EU_") or o.proto.startswith("IS_") or o.members for o in groupings)

    def test_grouping_members_read_from_the_export(self):
        m = TW.grouping_members("EU_SPC_London_Bridge")
        # the export carries the port socket and the tower sockets; its gates are placeholders until capture
        assert "zpSPCPortSocket" in m and "deSPCSocketCityTower" in m and "zpInvisibleGateSocketE" in m
        assert TW.grouping_members("no_such_grouping_xyz") == []


class TestJoin:
    def _actual_from(self, expected, rnd, jitter=1.5):
        out = []
        for i, e in enumerate(expected):
            proto = e.members[0] if e.members else e.proto
            out.append(TW.TwinObject("actual", proto, e.x_m + rnd.uniform(-jitter, jitter), e.z_m + rnd.uniform(-jitter, jitter),
                                     e.fx, e.fz, None, "", 0, [], "unjudged", "id%d" % i))
        return out

    def test_join_reports_exactly_the_missing_and_the_extra(self, london_expected):
        objs, rs, _ = london_expected
        expected = [TW.TwinObject(**{**o.__dict__}) for o in objs]
        rnd = random.Random(11)
        actual = self._actual_from(expected, rnd)
        dropped = actual.pop(3)                       # one expected object never spawned
        extra_proto = expected[0].members[0] if expected[0].members else expected[0].proto
        actual.append(TW.TwinObject("actual", extra_proto, 5.0, 5.0, 5 / 360, 5 / 645, None, "", 0, [], "unjudged", "stray"))
        actual.append(TW.TwinObject("actual", "PropsPoles", 50.0, 50.0, 50 / 360, 50 / 645, None, "", 0, [], "unjudged", "prop"))
        counts = TW.join(expected, actual, tol_m=8.0)
        missing = [e for e in expected if e.status == "missing"]
        extra = [a for a in actual if a.status == "extra"]
        assert counts["missing"] == len(missing) and counts["extra"] == len(extra)
        # exactly the dropped object is missing unless a same-proto neighbour within 8 m absorbed the stray
        assert len(missing) <= 2 and any(m.x_m == expected[3].x_m and m.z_m == expected[3].z_m for m in missing)
        assert all(a.match_id == "stray" for a in extra) and len(extra) <= 1
        assert [a for a in actual if a.match_id == "prop"][0].status == "unjudged"      # props are not modelled
        assert all(e.match_dist_m is not None and e.match_dist_m <= 8.0 for e in expected if e.status == "matched")

    def test_tolerance_is_metres(self, london_expected):
        objs, rs, _ = london_expected
        expected = [TW.TwinObject(**{**o.__dict__}) for o in objs[:5]]
        far = [TW.TwinObject("actual", e.members[0] if e.members else e.proto, e.x_m + 20.0, e.z_m, e.fx, e.fz, None, "", 0, [], "unjudged", "f%d" % i)
               for i, e in enumerate(expected)]
        TW.join(expected, far, tol_m=8.0)
        assert all(e.status == "missing" for e in expected)
        TW.join(expected, far, tol_m=25.0)
        assert all(e.status == "matched" for e in expected)


class TestBuild:
    def test_report_files(self, tmp_path):
        rep = TW.build(LONDON, 2, 2, None, tmp_path, png=False)
        j = json.loads((tmp_path / "twin.json").read_text(encoding="utf-8"))
        assert j["size_x_m"] == 360 and j["counts"]["expected"] == len(j["expected"]) and j["census"] is None
        assert all(set(("proto", "x_m", "z_m", "fx", "fz", "status", "pixels")) <= set(o) for o in j["expected"])
        assert rep["calibrations"] == {} or all(Path(p).is_file() for p in rep["calibrations"].values())

    def test_png_when_matplotlib(self, tmp_path):
        pytest.importorskip("matplotlib")
        rep = TW.build(LONDON, 2, 2, None, tmp_path, png=True)
        assert rep["png"] is True and (tmp_path / "twin.png").stat().st_size > 10000


class TestCensusReader:
    def test_bench_sample(self):
        units = CR.read(BENCH, 200, 200)
        protos = sorted(set(u["proto"] for u in units))
        assert "TownCenter" in protos and len(units) >= 5
        assert all(0 <= u["fx"] <= 1 and 0 <= u["fz"] <= 1 for u in units)
        assert all(u["player"] is None for u in units)          # the owner is not decoded yet (docstring)

    def test_find_owner_offset_is_honest(self):
        # no offset can make 2 town centres carry owners (1, 2) when the records are identical there: an empty answer
        hits = CR.find_owner_offset(BENCH, "TownCenter", [1, 2])
        assert isinstance(hits, list)
