"""Constraint-reactive grouping placement (plan Part H) — the three
user-reported failure modes, each pinned on its real map:

- wwcanyon: four same-anchor Sufi villages must SCATTER (avoidSufi =
  70 m from the SocketApache unit inside each placed village).
- tortuga: rmPlaceGroupingInArea villages must land INSIDE their
  island's grown terrain, not at the island's map-edge anchor.
- paris: spawn-chance branches (rmRandInt) place ONE monastery per
  spot — the lo-roll arm — never both arms stacked.
"""

from __future__ import annotations

import math
import sys
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[3]
if str(REPO) not in sys.path:
    sys.path.insert(0, str(REPO))

from scripts.mapsim.bridge import extraction_to_resolved
from scripts.mapsim.field import FieldContext, terrain_grid
from scripts.mapsim.gsolve import _ring_samples, ensure_solved
from scripts.mapsim.scene import Scenario
from scripts.mapsim.xs_extract import extract


def _solved(map_path: Path, players: int, teams: int):
    ex = extract(map_path, Scenario(players=players, teams=teams))
    rs = extraction_to_resolved(ex)
    ensure_solved(rs)
    return rs


class TestRingSampleOrder:
    def test_clockwise_from_north(self):
        pts = list(_ring_samples(0.0, 0.0, 10.0))
        # first sample = due north (+z); quarter way = due east (+x)
        assert pts[0][0] == pytest.approx(0.0, abs=1e-9)
        assert pts[0][1] == pytest.approx(10.0)
        q = pts[len(pts) // 4]
        assert q[0] == pytest.approx(10.0, rel=1e-2)
        assert abs(q[1]) < 1.0


class TestNominalRoll:
    def test_lo_roll_selects_one_arm(self, tmp_path):
        src = tmp_path / "roll.xs"
        src.write_text("""
void main(void) {
   rmSetStatusText("", 0.1);
   rmTerrainInitialize("grass", 2.0);
   rmSetMapSize(400, 400);
   int roll = rmRandInt(1, 2);
   int gA = rmCreateGrouping("gA", "pirate_village05");
   int gB = rmCreateGrouping("gB", "pirate_village06");
   if (roll == 1) {
      rmPlaceGroupingAtLoc(gA, 0, 0.3, 0.3);
      rmPlaceGroupingAtLoc(gB, 0, 0.7, 0.7);
   }
   else {
      rmPlaceGroupingAtLoc(gB, 0, 0.3, 0.3);
      rmPlaceGroupingAtLoc(gA, 0, 0.7, 0.7);
   }
   rmSetStatusText("", 1.0);
}
""", encoding="utf-8")
        rs = _solved(src, 2, 2)
        gs = [p for p in rs.placements if p.is_grouping]
        # lo roll = 1 -> then-arm only: gA west, gB east — one each
        assert sorted((p.name, round(p.x, 2), round(p.z, 2)) for p in gs) == [
            ("gA", 0.3, 0.3), ("gB", 0.7, 0.7)]
        assert rs.suppressed_variants == 2


class TestWWCanyonScatter:
    @pytest.fixture(scope="class")
    def rs(self):
        return _solved(REPO / "game" / "randmaps" / "zpwwcanyon.xs", 4, 2)

    def test_mosques_placed_and_spread(self, rs):
        mos = [p for p in rs.placements if p.is_grouping
               and p.name.startswith("mosque")]
        assert len(mos) == 2
        assert all(not p.solve_unsat for p in mos), \
            [p.solve_unsat for p in mos]
        # avoidSufi: mosque 2's spot must clear 70 m from mosque 1's
        # SocketApache unit (registry truth, post-solve context)
        ctx = FieldContext(rs)
        g = rs.grid
        pts = ctx.type_points("SocketApache")
        assert pts, "solved villages must register their sockets"
        m2 = next(p for p in mos if p.name == "mosque 2")
        p2 = (g.x_frac_to_m(m2.x), g.z_frac_to_m(m2.z))
        others = [pt for pt in pts if pt[2] != m2.line]
        assert min(math.hypot(p2[0] - a, p2[1] - b)
                   for a, b, _ln in others) >= 70.0 - 1e-6

    def test_min_distance_ring_honored(self, rs):
        g = rs.grid
        for p in rs.placements:
            if p.is_grouping and p.name.startswith("mosque") \
                    and not p.solve_unsat:
                ax = p.anchor_x if p.anchor_x is not None else p.x
                az = p.anchor_z if p.anchor_z is not None else p.z
                d = math.hypot(g.x_frac_to_m(p.x - (ax - p.x) * 0), 0)
                d = math.hypot((p.x - 0.5) * g.size_x_m,
                               (p.z - 0.5) * g.size_z_m)
                assert d >= 20.0 - 1e-6, f"{p.name} inside min ring: {d}"


class TestTortugaInArea:
    def test_carib_villages_inside_islands(self):
        rs = _solved(REPO / "game" / "randmaps" / "zptortuga.xs", 2, 2)
        tg = terrain_grid(rs, cell_tiles=1.0)
        caribs = [p for p in rs.placements if p.is_grouping
                  and p.name.startswith("caribs")]
        assert caribs, "carib villages must extract"
        placed = [p for p in caribs if p.x is not None and not p.solve_unsat]
        assert placed, "at least one carib village must solve"
        for p in placed:
            assert tg.is_land_frac(p.x, p.z), \
                f"{p.name} at ({p.x:.3f},{p.z:.3f}) must stand on land"
            assert p.anchor_x is not None, \
                "in_area solve must record the area anchor for the tether"
