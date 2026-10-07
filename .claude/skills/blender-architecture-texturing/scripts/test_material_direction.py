import unittest
from check_material_direction import check

class DirectionTests(unittest.TestCase):
    def test_rotated_masonry_is_rejected(self):
        r=check([dict(face='foundation',expected=[1,0,0],observed=[0,0,1])]);self.assertEqual(r['status'],'FAIL')
    def test_mirrored_unoriented_grain_is_compatible(self):
        self.assertEqual(check([dict(face='beam',expected=[1,0,0],observed=[-1,0,0])])['status'],'PASS')
    def test_signed_direction_rejects_reversal(self):
        self.assertEqual(check([dict(face='run',expected=[1,0,0],observed=[-1,0,0],signed=True)])['status'],'FAIL')
    def test_missing_observation_not_a_pass(self):
        self.assertEqual(check([dict(face='gable',expected=[0,0,1])])['status'],'FAIL')
    def test_unassessed_reported(self):
        self.assertEqual(check([dict(face='good',expected=[0,0,1],observed=[0,0,1]),dict(face='tiny',unassessed='subpixel')])['status'],'INCOMPLETE')
    def test_nonfinite_rejected(self):
        self.assertEqual(check([dict(face='bad',expected=[1,0,0],observed=[float('nan'),0,0])])['status'],'FAIL')
    def test_one_wrong_reader_cannot_average_away(self):
        r=check([dict(face='owner',expected=[1,0,0],observed=[1,0,0]),dict(face='reader',expected=[0,0,1],observed=[1,0,0])]);self.assertEqual(len(r['problems']),1)

if __name__=='__main__':unittest.main()
