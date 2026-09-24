"""mapview.transform: round trips, the rm-coordinates rule, agreement with mapsim's render transform, and the
calibration fit on synthetic pixels with noise (spec section 4, offline)."""
import math
import random
import sys
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO))
from scripts.mapview import transform as T  # noqa: E402

SQRT2 = math.sqrt(2.0)


def _cal(cx=2320.0, cy=900.0, r=190.0, fill="longer_side", sign_u=1, sign_v=-1):
    return T.Calibration("ingame", 2560, 1080, cx, cy, r, fill, sign_u, sign_v, measured=True)


class TestMetresFractions:
    def test_round_trip_rectangular(self):
        rnd = random.Random(1)
        for _ in range(500):
            x, z = rnd.uniform(0, 360), rnd.uniform(0, 645)
            fx, fz = T.world_to_frac(x, z, 360, 645)
            assert 0 <= fx <= 1 and 0 <= fz <= 1
            bx, bz = T.frac_to_world(fx, fz, 360, 645)
            assert abs(bx - x) < 1e-9 and abs(bz - z) < 1e-9

    def test_axes_never_conflated(self):
        fx, fz = T.world_to_frac(180, 645, 360, 645)
        assert (fx, fz) == (0.5, 1.0)

    def test_tiles(self):
        assert T.world_to_tiles(10, 4) == (5, 2) and T.tiles_to_world(5, 2) == (10, 4)

    def test_bad_size_rejected(self):
        with pytest.raises(ValueError):
            T.world_to_frac(1, 1, 0, 600)


class TestMinimapPlane:
    def test_rm_coordinates_rule_square(self):
        # u = (x - z) / sqrt2, v = (x + z - 1) / sqrt2 (rm-coordinates skill)
        rnd = random.Random(2)
        for _ in range(200):
            x, z = rnd.random(), rnd.random()
            u, v = T.frac_to_uv(x, z, 1.0)
            assert abs(u - (x - z) / SQRT2) < 1e-12 and abs(v - (x + z - 1) / SQRT2) < 1e-12

    def test_orientation(self):
        top = T.frac_to_uv(1, 1); bottom = T.frac_to_uv(0, 0); left = T.frac_to_uv(0, 1); right = T.frac_to_uv(1, 0)
        assert abs(top[0]) < 1e-12 and top[1] > 0 and bottom[1] < 0
        assert left[0] < 0 and right[0] > 0 and abs(left[1]) < 1e-12 and abs(right[1]) < 1e-12

    def test_round_trip_with_aspect(self):
        rnd = random.Random(3)
        for a in (1.0, 645 / 360, 360 / 645, 2.5):
            for _ in range(200):
                x, z = rnd.random(), rnd.random()
                u, v = T.frac_to_uv(x, z, a)
                bx, bz = T.uv_to_frac(u, v, a)
                assert abs(bx - x) < 1e-12 and abs(bz - z) < 1e-12

    def test_agrees_with_mapsim_render_transform(self):
        """mapsim render.py: scale(1, aspect) then rotate +45 about (0.5, 0.5 aspect); the plane's origin is that centre."""
        mpl = pytest.importorskip("matplotlib")
        from matplotlib.transforms import Affine2D
        rnd = random.Random(4)
        for a in (1.0, 645 / 360, 0.55):
            disp = Affine2D().scale(1.0, a) + Affine2D().rotate_deg_around(0.5, 0.5 * a, 45)
            for _ in range(100):
                x, z = rnd.random(), rnd.random()
                X, Y = disp.transform((x, z))
                u, v = T.frac_to_uv(x, z, a)
                assert abs((X - 0.5) - u) < 1e-9 and abs((Y - 0.5 * a) - v) < 1e-9

    def test_disc_is_the_longer_side(self):
        from scripts.mapsim.geometry import WORLD_CIRCLE_R
        assert T.WORLD_CIRCLE_R == WORLD_CIRCLE_R == 0.5
        assert T.disc_radius_display(1.0) == 0.5 and abs(T.disc_radius_display(645 / 360) - 0.5 * 645 / 360) < 1e-12
        assert abs(T.disc_radius_display(1.0, "diagonal") - 0.5 * SQRT2) < 1e-12
        # a square map's corners are outside the disc (cut), its edge midpoints are on it
        assert not T.in_minimap_disc(1, 1) and T.in_minimap_disc(0.5, 1.0) and T.in_minimap_disc(0.5, 0.5)


class TestPixels:
    def test_round_trip_pixels(self):
        cal = _cal()
        rnd = random.Random(5)
        for a in (1.0, 645 / 360):
            for _ in range(300):
                x, z = rnd.random(), rnd.random()
                px, py = T.frac_to_minimap(x, z, cal, a)
                bx, bz = T.minimap_to_frac(px, py, cal, a)
                assert abs(bx - x) < 1e-9 and abs(bz - z) < 1e-9
        # metres both ways, exact to 1 px after rounding
        for _ in range(100):
            x, z = rnd.uniform(0, 360), rnd.uniform(0, 645)
            px, py = T.world_to_minimap(x, z, 360, 645, cal)
            bx, bz = T.minimap_to_world(round(px), round(py), 360, 645, cal)
            s = cal.pixels_per_unit(645 / 360)
            assert math.hypot(bx - x, bz - z) <= (0.5 * SQRT2 / s) * 360 + 1e-6   # half a pixel in metres

    def test_screen_orientation(self):
        cal = _cal()
        top = T.frac_to_minimap(1, 1, cal); bottom = T.frac_to_minimap(0, 0, cal)
        left = T.frac_to_minimap(0, 1, cal); right = T.frac_to_minimap(1, 0, cal)
        assert top[1] < cal.cy < bottom[1] and left[0] < cal.cx < right[0]      # y grows downward on screen
        assert abs(T.frac_to_minimap(0.5, 0.5, cal)[0] - cal.cx) < 1e-9

    def test_rectangular_map_fills_the_disc_with_its_longer_side(self):
        cal = _cal(r=190.0)
        a = 645 / 360
        # the far ends of the long axis (z) sit on the disc; the short axis ends are inside
        for fx, fz in ((0.5, 0.0), (0.5, 1.0)):
            px, py = T.frac_to_minimap(fx, fz, cal, a)
            assert abs(math.hypot(px - cal.cx, py - cal.cy) - cal.radius_px) < 1e-6
        px, py = T.frac_to_minimap(0.0, 0.5, cal, a)
        assert math.hypot(px - cal.cx, py - cal.cy) < cal.radius_px * 0.6

    def test_unmeasured_record_refused(self, tmp_path, monkeypatch):
        monkeypatch.setattr(T, "CAL_DIR", tmp_path)
        cal = T.Calibration("ingame", 2560, 1080, 1, 1, 100, measured=False)
        cal.save()
        with pytest.raises(ValueError):
            T.load_calibration("ingame", 2560, 1080)
        assert T.load_calibration("ingame", 2560, 1080, require_measured=False).radius_px == 100
        with pytest.raises(FileNotFoundError):
            T.load_calibration("editor", 2560, 1080)


class TestFit:
    def _synthetic(self, truth, aspect, n, noise, seed):
        rnd = random.Random(seed)
        pairs = []
        while len(pairs) < n:
            fx, fz = rnd.random(), rnd.random()
            if not T.in_minimap_disc(fx, fz, aspect):
                continue
            px, py = T.frac_to_minimap(fx, fz, truth, aspect)
            pairs.append((fx, fz, px + rnd.gauss(0, noise), py + rnd.gauss(0, noise)))
        return pairs

    def test_fit_recovers_the_disc_within_a_pixel(self):
        truth = _cal(2320.0, 900.0, 190.0)
        for aspect in (1.0, 645 / 360):
            pairs = self._synthetic(truth, aspect, 6, 0.4, 7)
            cal = T.fit_calibration(pairs, aspect, "ingame", 2560, 1080)
            assert abs(cal.cx - truth.cx) < 1.0 and abs(cal.cy - truth.cy) < 1.0 and abs(cal.radius_px - truth.radius_px) < 1.5
            assert cal.sign_u == 1 and cal.sign_v == -1 and cal.measured and cal.residual_px < 2.0
            # a fourth independent point within 3 px
            check = self._synthetic(truth, aspect, 4, 0.4, 99)
            assert T.max_residual(cal, check, aspect) < 3.0

    def test_fit_detects_flipped_axes(self):
        truth = _cal(sign_u=-1, sign_v=1)
        pairs = self._synthetic(truth, 1.0, 5, 0.2, 8)
        cal = T.fit_calibration(pairs, 1.0, "editor", 2560, 1080)
        assert cal.sign_u == -1 and cal.sign_v == 1

    def test_affine_diagnostic_sees_a_pure_rotation(self):
        pytest.importorskip("numpy")
        truth = _cal()
        pairs = self._synthetic(truth, 645 / 360, 8, 0.0, 9)
        d = T.fit_affine_diagnostic(pairs, 645 / 360)
        assert abs(d["angle_deg"]) < 1e-6 and abs(d["skew_deg"]) < 1e-6 and d["residual_px"] < 1e-6
        assert abs(d["scale_u"] - truth.pixels_per_unit(645 / 360)) < 1e-6

    def test_two_points_minimum(self):
        with pytest.raises(ValueError):
            T.fit_calibration([(0.5, 0.5, 100, 100)], 1.0, "ingame", 1, 1)
