"""Inside-out shells: a closed shell must enclose positive signed volume (2026-10-10 Dock gable boards)."""
import unittest
from shell_orientation import check_mesh, self_intersecting

CUBE_V = [(0, 0, 0), (1, 0, 0), (1, 1, 0), (0, 1, 0), (0, 0, 1), (1, 0, 1), (1, 1, 1), (0, 1, 1)]
CUBE_F = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]   # outward


class ShellTests(unittest.TestCase):
    def test_outward_cube_ok(self):
        r = check_mesh(CUBE_V, CUBE_F)
        self.assertEqual([x['status'] for x in r], ['OK'])
        self.assertAlmostEqual(r[0]['volume'], 1.0)

    def test_reversed_cube_inside_out(self):
        r = check_mesh(CUBE_V, [tuple(reversed(f)) for f in CUBE_F])
        self.assertEqual([x['status'] for x in r], ['INSIDE_OUT'])

    def test_translation_does_not_change_the_sign(self):
        moved = [(x + 700, y - 40, z + 3) for x, y, z in CUBE_V]
        self.assertEqual(check_mesh(moved, [tuple(reversed(f)) for f in CUBE_F])[0]['status'], 'INSIDE_OUT')
        self.assertEqual(check_mesh(moved, CUBE_F)[0]['status'], 'OK')

    def test_thin_board_slab(self):
        # the actual failure: a 0.1 m triangular gable board whose outer plane faced inward
        v = [(0, 0, 0), (2, 0, 0), (1, 0, 1), (0, .1, 0), (2, .1, 0), (1, .1, 1)]
        out = [(0, 1, 2), (3, 5, 4), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)]
        self.assertEqual(check_mesh(v, out)[0]['status'], 'OK')
        self.assertEqual(check_mesh(v, [tuple(reversed(f)) for f in out])[0]['status'], 'INSIDE_OUT')

    def test_open_shell_is_not_judged(self):
        r = check_mesh(CUBE_V, CUBE_F[:5])
        self.assertEqual([x['status'] for x in r], ['OPEN'])

    def test_two_shells_one_object(self):
        v = CUBE_V + [(x + 3, y, z) for x, y, z in CUBE_V]
        f = CUBE_F + [tuple(reversed(tuple(i + 8 for i in q))) for q in CUBE_F]
        self.assertEqual(sorted(x['status'] for x in check_mesh(v, f)), ['INSIDE_OUT', 'OK'])

    def test_gable_bowtie_outline(self):
        # the actual 2026-10-10 board plane (x, z): the sloped edge ends 8 cm below the curved bottom's ends
        bottom = [(1.695, 4.9803), (1.8675, 4.9617), (2.04, 4.9482), (2.73, 4.931), (3.42, 4.9482), (3.5925, 4.9617), (3.765, 4.9803)]
        top = [(3.765, 4.8977), (3.5925, 4.9661), (2.73, 5.565), (1.8675, 4.9661), (1.695, 4.8977)]
        self.assertTrue(self_intersecting(bottom + top))
        fixed = [(1.695, 4.8877)] + bottom[1:-1] + [(3.765, 4.8877)] + top
        self.assertFalse(self_intersecting(fixed))


if __name__ == '__main__':
    unittest.main()
