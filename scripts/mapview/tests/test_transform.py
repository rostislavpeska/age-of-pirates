"""mapview.transform: round trips, the rm-coordinates rule, agreement with mapsim's render transform, and the
calibration fit on synthetic pixels with noise (spec section 4, offline), the record gates, and the real Paris
editor numbers (fixtures/paris_editor_minimap.json)."""
import json
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

    def test_load_calibration_gates(self, tmp_path, monkeypatch):
        """review F6: a record is usable only when accepted, and checked unless the caller opts out."""
        monkeypatch.setattr(T, "CAL_DIR", tmp_path)
        monkeypatch.delenv("MAPVIEW_CAL_DIR", raising=False)
        with pytest.raises(FileNotFoundError):
            T.load_calibration("editor", 2560, 1080)
        cal = T.Calibration("ingame", 2560, 1080, 1, 1, 100, measured=True)       # a legacy record: no 'accepted'
        cal.save()
        with pytest.raises(ValueError, match="not an accepted"):
            T.load_calibration("ingame", 2560, 1080, require_checked=False)
        cal.accepted = True
        cal.save()
        with pytest.raises(ValueError, match="never passed"):
            T.load_calibration("ingame", 2560, 1080)
        assert T.load_calibration("ingame", 2560, 1080, require_checked=False).radius_px == 100
        cal.checked = True
        cal.save()
        got = T.load_calibration("ingame", 2560, 1080)
        assert got.accepted and got.checked and got.look_offset_px == [0.0, 0.0]

    def test_cal_dir_env_override(self, tmp_path, monkeypatch):
        monkeypatch.setenv("MAPVIEW_CAL_DIR", str(tmp_path / "scratch_cal"))
        p = T.Calibration("editor", 2560, 1080, 1, 1, 100, accepted=True, checked=True).save()
        assert p.parent == tmp_path / "scratch_cal" and T.list_calibrations() == [p]

    def test_record_round_trip_keeps_new_fields(self):
        cal = T.Calibration("editor", 2560, 1080, 2269.33, 920.33, 130.5, measured=True, method="disc", accepted=True,
                            r_line_px=136.18, probes=[{"x": 1, "y": 2, "rgb": [3, 4, 5]}],
                            check_pairs=[{"what": "a", "x_m": 1.0, "z_m": 2.0, "size_x_m": 3.0, "size_z_m": 4.0,
                                          "px": 5.0, "py": 6.0, "err_px": 0.5}], check_residual_px=0.5,
                            look_offset_px=[0.25, -0.5])
        back = T.Calibration.from_json(cal.to_json())
        assert back == cal


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
            assert cal.sign_u == 1 and cal.sign_v == -1 and cal.residual_px < 2.0
            assert cal.accepted and cal.measured and cal.method == "icons" and not cal.checked
            # a fourth independent point within 3 px
            check = self._synthetic(truth, aspect, 4, 0.4, 99)
            assert T.max_residual(cal, check, aspect) < 3.0

    def test_fit_gate_sets_accepted(self):
        truth = _cal()
        pairs = self._synthetic(truth, 1.0, 4, 0.0, 11)
        pairs[0] = (pairs[0][0], pairs[0][1], pairs[0][2] + 9.0, pairs[0][3])          # one bad pixel
        cal = T.fit_calibration(pairs, 1.0, "ingame", 2560, 1080)
        assert cal.residual_px > T.ACCEPT_FIT_PX and not cal.accepted and not cal.measured

    def test_joint_least_squares_is_optimal(self):
        """review F2: s, cx, cy solved jointly minimise the squared error for the model; nudging any of them
        makes it worse (the old per-axis slopes averaged into one s kept non-optimal intercepts)."""
        truth = _cal(2269.5, 920.5, 130.0)
        a = 360 / 653
        pairs = self._synthetic(truth, a, 5, 1.2, 21)
        cal = T.fit_calibration(pairs, a, "editor", 2560, 1080)

        def sse(cx, cy, r):
            c = T.Calibration("editor", 2560, 1080, cx, cy, r, sign_u=cal.sign_u, sign_v=cal.sign_v)
            total = 0.0
            for fx, fz, px, py in pairs:
                qx, qy = T.frac_to_minimap(fx, fz, c, a)
                total += (qx - px) ** 2 + (qy - py) ** 2
            return total
        base = sse(cal.cx, cal.cy, cal.radius_px)
        for d in ((0.05, 0, 0), (-0.05, 0, 0), (0, 0.05, 0), (0, -0.05, 0), (0, 0, 0.05), (0, 0, -0.05)):
            assert sse(cal.cx + d[0], cal.cy + d[1], cal.radius_px + d[2]) > base

    def test_fit_detects_flipped_axes(self):
        truth = _cal(sign_u=-1, sign_v=1)
        pairs = self._synthetic(truth, 1.0, 5, 0.2, 8)
        cal = T.fit_calibration(pairs, 1.0, "editor", 2560, 1080)
        assert cal.sign_u == -1 and cal.sign_v == 1

    def test_affine_diagnostic_sees_a_pure_rotation(self):
        truth = _cal()
        pairs = self._synthetic(truth, 645 / 360, 8, 0.0, 9)
        d = T.fit_affine_diagnostic(pairs, 645 / 360)
        assert abs(d["angle_deg"]) < 1e-6 and abs(d["skew_deg"]) < 1e-6 and d["residual_px"] < 1e-6
        assert abs(d["scale_u"] - truth.pixels_per_unit(645 / 360)) < 1e-6

    def test_affine_diagnostic_after_the_fitted_signs(self):
        """review F8: a mirrored u axis the model handles reads angle 0 once the fitted signs are applied; three
        pairs determine the affine exactly, so there is no residual to report."""
        truth = _cal(sign_u=-1, sign_v=-1)
        pairs = self._synthetic(truth, 1.0, 6, 0.0, 12)
        cal = T.fit_calibration(pairs, 1.0, "editor", 2560, 1080)
        d = T.fit_affine_diagnostic(pairs, 1.0, cal.sign_u, cal.sign_v)
        assert abs(d["angle_deg"]) < 1e-6 and abs(d["skew_deg"]) < 1e-6
        assert T.fit_affine_diagnostic(pairs[:3], 1.0, cal.sign_u, cal.sign_v)["residual_px"] is None

    def test_affine_diagnostic_sees_a_rotation(self):
        truth = _cal()
        a = 645 / 360
        pairs = []
        th = math.radians(2.0)
        for fx, fz, px, py in self._synthetic(truth, a, 6, 0.0, 13):
            dx, dy = px - truth.cx, py - truth.cy
            pairs.append((fx, fz, truth.cx + dx * math.cos(th) - dy * math.sin(th),
                          truth.cy + dx * math.sin(th) + dy * math.cos(th)))
        d = T.fit_affine_diagnostic(pairs, a)
        assert abs(abs(d["angle_deg"]) - 2.0) < 1e-6 and abs(d["skew_deg"]) < 1e-6

    def test_three_points_minimum(self):
        """review F7: two pairs fit any aspect with a 0 px residual, so a fit needs three."""
        truth = _cal()
        pairs = self._synthetic(truth, 1.0, 3, 0.0, 14)
        with pytest.raises(ValueError):
            T.fit_calibration(pairs[:2], 1.0, "ingame", 2560, 1080)
        assert T.fit_calibration(pairs, 1.0, "ingame", 2560, 1080).residual_px < 1e-6


class TestRealEditorNumbers:
    """The Paris editor frame as plain numbers (fixtures/paris_editor_minimap.json): the drawn disc, the four
    explorers' world positions from the save headers and their stars' pixels. Runs without PIL."""
    FIX = json.loads((Path(__file__).resolve().parent / "fixtures" / "paris_editor_minimap.json").read_text(encoding="utf-8"))

    def _disc_cal(self):
        d = self.FIX["disc"]
        return T.Calibration("editor", 2560, 1080, d["cx"], d["cy"], d["r_disc"], method="disc", accepted=True)

    def _pairs(self, which="explorer"):
        out = []
        for s in self.FIX["stars"]:
            src = s if which == "explorer" else s["post"]
            out.append({"what": src["what"], "x_m": src["x_m"], "z_m": src["z_m"], "size_x_m": self.FIX["size_x_m"],
                        "size_z_m": self.FIX["size_z_m"], "px": s["star_px"], "py": s["star_py"]})
        return out

    def test_disc_predicts_the_explorer_stars_within_2px(self):
        worst, rows = T.evaluate_pairs(self._disc_cal(), self._pairs())
        assert worst < 2.0, rows
        assert all(abs(r["err_px"] - s["explorer_err_px"]) <= 0.006 for r, s in zip(rows, self.FIX["stars"]))

    def test_the_star_is_not_the_command_post(self):
        """The star marks the Explorer: the command posts (the glyph behind the star) miss it by 4-7 px."""
        worst, rows = T.evaluate_pairs(self._disc_cal(), self._pairs("post"))
        assert min(r["err_px"] for r in rows) > 3.0, rows

    def test_icon_fit_agrees_with_the_disc(self):
        sx, sz = self.FIX["size_x_m"], self.FIX["size_z_m"]
        pairs = [(p["x_m"] / sx, p["z_m"] / sz, p["px"], p["py"]) for p in self._pairs()]
        cal = T.fit_calibration(pairs, sz / sx, "editor", 2560, 1080)
        d = self.FIX["disc"]
        assert (cal.sign_u, cal.sign_v) == (1, -1) and cal.residual_px < 1.0 and cal.accepted
        assert abs(cal.radius_px - d["r_disc"]) < 1.0
        assert math.hypot(cal.cx - d["cx"], cal.cy - d["cy"]) < 1.5
        diag = T.fit_affine_diagnostic(pairs, sz / sx, cal.sign_u, cal.sign_v)
        assert abs(diag["angle_deg"]) < 0.5 and abs(diag["skew_deg"]) < 0.5

    def test_engine_size(self):
        """The minimap draws the engine's terrain: 654 m (327 tiles), not rmSetMapSize's 653."""
        assert (self.FIX["size_x_m"], self.FIX["size_z_m"]) == (654.0, 360.0)
        assert self.FIX["size_script_m"] == [653.0, 360.0] and self.FIX["terrain_tiles"] == [327, 180]


class TestLiveLondonNumbers:
    """The live London 4p editor frame of 2026-09-24 as plain numbers (fixtures/london4p_editor_minimap.json): the
    disc record (2269.33, 920.33) rim 130.5, the four Explorers from the save mapview_london4p_live.age3Yscn and their
    stars' pixels. Runs without PIL."""
    FIX = json.loads((Path(__file__).resolve().parent / "fixtures" / "london4p_editor_minimap.json").read_text(encoding="utf-8"))
    EXPLORERS = {"P1": (43.0, 545.0), "P2": (189.0, 537.0), "P3": (55.0, 153.0), "P4": (175.0, 153.0)}

    def _cal(self):
        return T.Calibration("editor", 2560, 1080, 2269.33, 920.33, 130.5, method="disc", accepted=True)

    def _pairs(self, size_z):
        return [{"what": s["what"], "x_m": s["x_m"], "z_m": s["z_m"], "size_x_m": 360.0, "size_z_m": size_z,
                 "px": s["star_px"], "py": s["star_py"]} for s in self.FIX["stars"]]

    def test_the_fixture_holds_the_save_numbers(self):
        got = {s["what"][:2]: (s["x_m"], s["z_m"]) for s in self.FIX["stars"]}
        assert got == self.EXPLORERS
        assert (self.FIX["size_x_m"], self.FIX["size_z_m"]) == (360.0, 686.0) and self.FIX["terrain_tiles"] == [180, 343]

    def test_explorer_stars_within_1_5_px_at_the_engine_size(self):
        worst, rows = T.evaluate_pairs(self._cal(), self._pairs(686.0))
        assert worst < 1.5, rows
        assert [r["err_px"] for r in rows] == pytest.approx([0.75, 1.22, 0.80, 0.81], abs=0.006)
        assert all(abs(r["err_px"] - s["explorer_err_px"]) <= 0.006 for r, s in zip(rows, self.FIX["stars"]))

    def test_the_script_size_fits_worse(self):
        """rmSetMapSize's 685 m: every star further off, the worst 1.52 px."""
        w686, r686 = T.evaluate_pairs(self._cal(), self._pairs(686.0))
        w685, r685 = T.evaluate_pairs(self._cal(), self._pairs(685.0))
        assert abs(w685 - 1.52) <= 0.01 and w685 > w686
        assert all(a["err_px"] > b["err_px"] for a, b in zip(r685, r686))
