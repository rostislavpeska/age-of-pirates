"""Tests for the geometry primitives, per plan section 3 (test_geometry.py)."""

from __future__ import annotations

import math
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[3]))

from scripts.mapsim.geometry import (  # noqa: E402
    WORLD_CIRCLE_R,
    angle_frac_in_arc,
    annulus_intersects_annulus,
    annulus_intersects_box,
    annulus_intersects_disc,
    discs_overlap,
    dist,
    dist_point_to_polyline,
    dist_point_to_segment,
    dist_range_to_box,
    in_guide_octagon,
    in_safe_box,
    in_world_circle,
    intervals_overlap,
    point_in_circle,
    reachable_dist_interval,
)


class TestCircle:
    def test_boundary_inclusive(self):
        # Exactly on the circle counts as inside (engine tolerates exact-edge).
        assert point_in_circle((1.0, 0.5), (0.5, 0.5), 0.5)
        assert not point_in_circle((1.0000001, 0.5), (0.5, 0.5), 0.5)

    def test_world_circle(self):
        assert WORLD_CIRCLE_R == 0.5
        assert in_world_circle((0.5, 0.5))
        assert in_world_circle((0.5, 1.0))          # cardinal midpoint, r = 0.5
        assert not in_world_circle((0.9, 0.9))      # r ~ 0.566
        assert not in_world_circle((0.99, 0.99))    # corner props live outside

    def test_pirate_headlands_inside_circle(self):
        # (0.17, 0.30): r = hypot(0.33, 0.20) ~ 0.386 — inside, matching the
        # boundary-model correction in plan section 1.2.
        assert in_world_circle((0.17, 0.30))
        assert in_world_circle((0.83, 0.30))


class TestDiscs:
    def test_overlap_tangent_inclusive(self):
        assert discs_overlap((0.0, 0.0), 1.0, (2.0, 0.0), 1.0)
        assert not discs_overlap((0.0, 0.0), 1.0, (2.0001, 0.0), 1.0)
        assert discs_overlap((0.0, 0.0), 3.0, (1.0, 0.0), 0.5)  # containment


class TestPolyline:
    def test_segment_distance(self):
        assert dist_point_to_segment((0.0, 1.0), (0.0, 0.0), (2.0, 0.0)) == pytest.approx(1.0)
        assert dist_point_to_segment((-1.0, 0.0), (0.0, 0.0), (2.0, 0.0)) == pytest.approx(1.0)
        assert dist_point_to_segment((3.0, 4.0), (0.0, 0.0), (0.0, 0.0)) == pytest.approx(5.0)

    def test_polyline_distance_takes_minimum(self):
        route = [(0.0, 0.0), (2.0, 0.0), (2.0, 2.0)]
        assert dist_point_to_polyline((1.0, 0.5), route) == pytest.approx(0.5)
        assert dist_point_to_polyline((2.5, 1.0), route) == pytest.approx(0.5)

    def test_polyline_needs_points(self):
        with pytest.raises(ValueError):
            dist_point_to_polyline((0.0, 0.0), [])


class TestAnnuli:
    def test_reachable_interval_point_inside_band(self):
        assert reachable_dist_interval(5.0, 4.0, 6.0) == (0.0, 11.0)

    def test_reachable_interval_point_in_hole(self):
        lo, hi = reachable_dist_interval(1.0, 4.0, 6.0)
        assert lo == pytest.approx(3.0)
        assert hi == pytest.approx(7.0)

    def test_reachable_interval_point_outside(self):
        lo, hi = reachable_dist_interval(10.0, 4.0, 6.0)
        assert lo == pytest.approx(4.0)
        assert hi == pytest.approx(16.0)

    def test_annulus_annulus(self):
        assert annulus_intersects_annulus(0.0, 5.0, 6.0, 5.5, 7.0)
        # ring around a hole: inner disc entirely inside the other's hole
        assert not annulus_intersects_annulus(0.0, 5.0, 6.0, 0.0, 1.0)
        assert annulus_intersects_annulus(10.0, 0.0, 5.0, 0.0, 5.0)   # tangent
        assert not annulus_intersects_annulus(10.1, 0.0, 5.0, 0.0, 5.0)

    def test_annulus_disc(self):
        # The old pirate-village shape: anchor with MaxDistance 30 m vs a land
        # disc 50 m away with radius 15 m — unreachable.
        assert not annulus_intersects_disc(50.0, 0.0, 30.0, 15.0)
        assert annulus_intersects_disc(40.0, 0.0, 30.0, 15.0)

    def test_invalid_annulus_raises(self):
        with pytest.raises(ValueError):
            reachable_dist_interval(1.0, 6.0, 4.0)
        with pytest.raises(ValueError):
            reachable_dist_interval(1.0, -1.0, 4.0)


class TestBoxes:
    BOX = (0.1, 0.1, 0.9, 0.9)

    def test_dist_range_inside(self):
        lo, hi = dist_range_to_box((0.5, 0.5), self.BOX)
        assert lo == 0.0
        assert hi == pytest.approx(math.hypot(0.4, 0.4))

    def test_dist_range_outside(self):
        lo, hi = dist_range_to_box((1.0, 0.5), self.BOX)
        assert lo == pytest.approx(0.1)
        assert hi == pytest.approx(math.hypot(0.9, 0.4))

    def test_annulus_box(self):
        assert annulus_intersects_box((0.5, 0.5), 0.0, 0.1, self.BOX)
        assert not annulus_intersects_box((0.5, 0.5), 0.6, 0.7, self.BOX)  # box max reach ~0.566
        assert annulus_intersects_box((1.5, 0.5), 0.6, 0.7, self.BOX)

    def test_malformed_box_raises(self):
        with pytest.raises(ValueError):
            dist_range_to_box((0.0, 0.0), (0.9, 0.1, 0.1, 0.9))


class TestIntervals:
    def test_overlap(self):
        assert intervals_overlap(0.0, 1.0, 1.0, 2.0)   # touching counts
        assert not intervals_overlap(0.0, 1.0, 1.1, 2.0)


class TestPlacementArcs:
    def test_plain_arc(self):
        assert angle_frac_in_arc(0.3, 0.23, 0.40)
        assert not angle_frac_in_arc(0.5, 0.23, 0.40)

    def test_wrapped_arc_independence_war(self):
        # rmSetPlacementSection(0.73, 0.27) at >2 teams wraps through 0.
        assert angle_frac_in_arc(0.0, 0.73, 0.27)
        assert angle_frac_in_arc(0.9, 0.73, 0.27)
        assert angle_frac_in_arc(0.27, 0.73, 0.27)
        assert angle_frac_in_arc(0.73, 0.73, 0.27)
        assert not angle_frac_in_arc(0.5, 0.73, 0.27)

    def test_arc_end_over_one_normalizes(self):
        # crownlands passes end 1.0615 -> normalizes to 0.0615 and wraps.
        assert angle_frac_in_arc(0.19, 0.1875, 1.0615)
        assert angle_frac_in_arc(0.05, 0.1875, 1.0615)
        assert not angle_frac_in_arc(0.1, 0.1875, 1.0615)


class TestGuideOverlays:
    def test_octagon_literal_rules(self):
        assert in_guide_octagon((0.5, 0.5))
        assert not in_guide_octagon((0.05, 0.05))    # X+Z < 0.2
        assert not in_guide_octagon((0.95, 0.1))     # |X-Z| >= 0.8
        assert in_guide_octagon((0.9, 0.9))          # X+Z = 1.8, boundary in
        assert not in_guide_octagon((1.2, 0.5))      # outside the [0,1] square

    def test_octagon_vs_circle_documented_disagreement(self):
        # Advisory overlay admits (0.9, 0.9); the world circle rejects it.
        assert in_guide_octagon((0.9, 0.9))
        assert not in_world_circle((0.9, 0.9))

    def test_safe_box(self):
        assert in_safe_box((0.5, 0.5))
        assert in_safe_box((0.1, 0.9))               # boundary-inclusive
        assert not in_safe_box((0.95, 0.5))


class TestBasics:
    def test_dist(self):
        assert dist((0.0, 0.0), (3.0, 4.0)) == pytest.approx(5.0)

    def test_non_finite_raises(self):
        with pytest.raises(ValueError):
            dist((float("nan"), 0.0), (0.0, 0.0))
        with pytest.raises(ValueError):
            angle_frac_in_arc(float("inf"), 0.0, 1.0)
