"""The UV integrity gate must FIRE on every defect class it names (positive controls), and pass a clean layout."""
import copy
import sys
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
from uv_integrity import audit, snapshot  # noqa: E402

SQ = [[.1, .1], [.3, .1], [.3, .3], [.1, .3]]          # counter-clockwise: positive area
TRI = [[.4, .1], [.5, .1], [.45, .2]]


def clean():
    return [dict(id='own#0', page='0', family=7, role=1, uv=copy.deepcopy(SQ)),
            dict(id='own#1', page='0', family=7, role=1, uv=copy.deepcopy(TRI)),
            dict(id='mem#0', page='0', family=7, role=2, uv=[SQ[2], SQ[3], SQ[0], SQ[1]]),   # same polygon, other start
            dict(id='mem#1', page='0', family=7, role=2, uv=copy.deepcopy(TRI)),
            dict(id='uni#0', page='0', family=-1, role=0, uv=[[.6, .6], [.8, .6], [.8, .8]]),
            dict(id='hid#0', page='3', family=-1, role=0, uv=[[30 / 1024, 1 - 60 / 1024], [60 / 1024, 1 - 60 / 1024],
                                                             [60 / 1024, 1 - 30 / 1024]])]   # counter-clockwise


ATLAS = {'3': {'size': 1024, 'regions': [[20, 20, 236, 748]]}}


class UVIntegrity(unittest.TestCase):
    def run_audit(self, faces, **kw):
        return audit(faces, ATLAS, **kw)

    def test_clean_layout_passes(self):
        r = self.run_audit(clean())
        self.assertEqual(r['status'], 'PASS', r['failures']); self.assertEqual(r['families'], 1)

    def test_mirrored_member_copy_fails_winding_and_stacking(self):
        f = clean(); f[2]['uv'] = list(reversed(SQ))               # the reflection that matched the same vertex SET
        r = self.run_audit(f)
        self.assertEqual(r['failures'].get('W_negative_winding'), 1)
        self.assertEqual(r['failures'].get('S_member_not_stacked_on_owner'), 1)
        self.assertIn('mem#0', r['examples']['W_negative_winding'])

    def test_member_off_its_owner_or_on_another_page_fails(self):
        f = clean(); f[3]['uv'] = [[u + .001, v] for u, v in TRI]
        self.assertEqual(self.run_audit(f)['failures'].get('S_member_not_stacked_on_owner'), 1)
        f = clean(); f[3]['page'] = '2'
        self.assertEqual(self.run_audit(f)['failures'].get('S_member_on_other_page'), 1)
        f = clean(); f[0]['role'] = f[1]['role'] = 0
        self.assertEqual(self.run_audit(f)['failures'].get('S_member_without_owner'), 2)

    def test_atlas_face_dragged_out_of_its_region_fails(self):
        f = clean(); f[5]['uv'] = [[u + .5, v] for u, v in f[5]['uv']]   # a pack moved a hidden atlas face
        self.assertEqual(self.run_audit(f)['failures'].get('R_outside_atlas_region'), 1)

    def test_bounds_collapse_and_nonfinite_fail(self):
        for uv, code in (([[1.2, .1], [1.3, .1], [1.25, .2]], 'B_outside_unit'), ([[.1, .1], [.2, .2], [.3, .3]], 'B_collapsed'),
                         ([[float('nan'), .1], [.2, .1], [.2, .2]], 'B_nonfinite_or_degenerate')):
            f = clean(); f[4]['uv'] = uv
            self.assertEqual(self.run_audit(f)['failures'].get(code), 1, code)

    def test_non_target_face_moved_by_a_step_fails(self):
        before = snapshot(clean()); f = clean(); f[5]['uv'][0] = [31 / 1024, 1 - 60 / 1024]   # inside its region still
        r = self.run_audit(f, frozen={'before': before, 'targets': ['own#0', 'own#1', 'mem#0', 'mem#1', 'uni#0']})
        self.assertEqual(r['failures'].get('F_non_target_moved'), 1)
        f = clean(); f[0]['uv'] = [[u + .01, v] for u, v in SQ]; f[2]['uv'] = copy.deepcopy(f[0]['uv'])
        r = self.run_audit(f, frozen={'before': before, 'targets': ['own#0', 'mem#0']})
        self.assertNotIn('F_non_target_moved', r['failures'])     # the step's own targets may move

    def test_owner_split_over_pages_and_duplicate_ids(self):
        f = clean(); f[1]['page'] = '1'
        self.assertEqual(self.run_audit(f)['failures'].get('S_owner_split_over_pages'), 1)
        with self.assertRaises(ValueError):
            audit(clean() + [clean()[0]])


if __name__ == '__main__':
    unittest.main()
