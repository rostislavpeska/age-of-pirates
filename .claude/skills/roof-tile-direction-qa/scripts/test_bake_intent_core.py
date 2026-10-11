"""Synthetic checks of bake_intent_core (host Python + NumPy): a lapped slope reads PASS, reversed laps, turned rolls,
a stretched course coordinate and sagging courses FAIL, a declared-intent face never gates, mirrored UVs keep the
verdict, and the controls must invert. These test the checker, not any asset."""
import math
import unittest
from pathlib import Path
import sys

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bake_intent_core as C  # noqa: E402

S = 256


def lap_map(courses=8, rolls=8, skew=0.):
    """tangent normals of a lapped tile field: v = up-slope, a sharp lap step facing DOWNhill (-v) at the foot of each
    course, rolls along v (sideways tilt over u, strong on the pan, weak on the step); skew > 0 makes the courses sag
    (the step line bends with u, so the step also faces sideways)"""
    y, x = np.mgrid[0:S, 0:S] + .5
    u = x / S; v = 1 - y / S
    ph = (v * courses + skew * np.sin(math.pi * u) * courses) % 1
    step = ph < .22; roll = np.sin(2 * math.pi * u * rolls)
    n = np.zeros((S, S, 3))
    n[..., 0] = np.where(step, .15 * roll - skew * courses * math.pi * np.cos(math.pi * u) * .7, .7 * roll)
    n[..., 1] = np.where(step, -.7, .05)
    n[..., 2] = 1
    return n / np.linalg.norm(n, axis=-1, keepdims=True)


def slope(pitch=30., stretch=1., mirror=False, cells=6):
    """a 4 x 4 m roof plane falling toward -y, split into cells x cells quads; UV u along x, v up the slope"""
    t = math.radians(pitch); P, UV = [], []
    for i in range(cells):
        for j in range(cells):
            a, b = i / cells, (i + 1) / cells; c, d = j / cells, (j + 1) / cells
            def pt(uu, vv):
                return [4 * uu, 4 * vv * math.cos(t), 4 * vv * math.sin(t)]
            def tx(uu, vv):
                return [1 - uu if mirror else uu, vv * stretch]
            for tri in (((a, c), (b, c), (b, d)), ((a, c), (b, d), (a, d))):
                q = [pt(*k) for k in tri]
                if mirror:
                    q = [q[0], q[2], q[1]]; tri = (tri[0], tri[2], tri[1])
                P.append(q); UV.append([tx(*k) for k in tri])
    return np.array(P), np.array(UV)


class BakeIntent(unittest.TestCase):
    def ctl(self, P, UV, NT, free=None):
        return {k: C.measure(P, UV, C.control(NT, k), free) for k in ('flipG', 'swapRG')}

    def test_correct_field_passes_with_inverting_controls(self):
        P, UV = slope(); NT = lap_map(); r = C.measure(P, UV, NT)
        self.assertGreater(r['lap_asymmetry'], 2); self.assertGreater(r['roll_axis_ratio'], 1.5)
        self.assertEqual(C.verdict(r, controls=self.ctl(P, UV, NT))[0], 'PASS', C.verdict(r, controls=self.ctl(P, UV, NT)))

    def test_without_controls_inconclusive(self):
        P, UV = slope(); r = C.measure(P, UV, lap_map())
        self.assertEqual(C.verdict(r)[0], 'INCONCLUSIVE')

    def test_reversed_laps_fail(self):
        P, UV = slope(); r = C.measure(P, UV, C.control(lap_map(), 'flipG'))
        self.assertLess(r['lap_asymmetry'], 1); self.assertEqual(C.verdict(r)[0], 'FAIL')

    def test_turned_rolls_fail(self):
        P, UV = slope(); r = C.measure(P, UV, C.control(lap_map(), 'swapRG'))
        self.assertLess(r['roll_axis_ratio'], 1); self.assertEqual(C.verdict(r)[0], 'FAIL')

    def test_stretched_course_coordinate_fails(self):
        for stretch in (.5, 2.):                           # course coordinate squeezed / stretched against u
            P, UV = slope(stretch=stretch); r = C.measure(P, UV, lap_map())
            self.assertAlmostEqual(r['anisotropy']['p50'], 1 / stretch, places=2)
            self.assertEqual(C.verdict(r)[0], 'FAIL', stretch)

    def test_sagging_courses_fail_on_lap_axis(self):
        P, UV = slope(); r = C.measure(P, UV, lap_map(skew=.12))
        self.assertGreater(r['lap_axis_deg']['p50'], 20); self.assertEqual(C.verdict(r)[0], 'FAIL')

    def test_declared_intent_never_gates(self):
        P, UV = slope(); good = lap_map(); bad = lap_map(skew=.12)
        NT = np.where((np.arange(S) < S * 4 // 6)[None, :, None], bad, good)    # u < 4/6: sagging courses on purpose
        free = np.zeros(len(P), bool); free[:48] = True                         # the faces there (cells i < 4) declared
        r_undeclared = C.measure(P, UV, NT)
        self.assertEqual(C.verdict(r_undeclared)[0], 'FAIL')                    # undeclared, the gate catches it
        r = C.measure(P, UV, NT, free)
        self.assertEqual(r['declared']['faces'], 48); self.assertGreater(r['declared']['lap_axis_p50'], 20)
        self.assertEqual(C.verdict(r, controls=self.ctl(P, UV, NT, free))[0], 'PASS')

    def test_mirrored_uvs_keep_the_verdict(self):
        P, UV = slope(mirror=True); NT = lap_map(); r = C.measure(P, UV, NT)
        self.assertGreater(r['lap_asymmetry'], 2)

    def test_too_little_roof_is_inconclusive(self):
        P, UV = slope(cells=1); r = C.measure(P[:1], UV[:1] * .05, lap_map())
        self.assertEqual(C.verdict(r)[0], 'INCONCLUSIVE')


if __name__ == '__main__':
    unittest.main()
