"""Direction controls; synthetic fixtures do not certify an asset."""
import unittest
from roof_lap_gate import assess


class RoofLapTests(unittest.TestCase):
    def sample(self,uphill_bug=False):
        down=[i*.288/999 for i in range(1000)];out=[]
        for d in down:
            s=-.002-d;phase=((s if uphill_bug else -s)/.292)%1
            t=max(0.,min(1.,(phase-.94)/.06));out.append(.015*phase*(1-t*t*(3-2*t)))
        return down,out

    def test_corrected_physical_downhill_lip_passes(self):
        self.assertEqual(assess(*self.sample(),[0,1,-.5])['status'],'PASS')

    def test_incident_uphill_lip_fails(self):
        self.assertEqual(assess(*self.sample(True),[0,1,-.5])['status'],'FAIL')

    def test_flat_relief_cannot_pass(self):
        self.assertEqual(assess([0,1,2,3,4],[0]*5,[0,1,-.5])['status'],'FAIL')

    def test_mislabeled_uphill_frame_rejected(self):
        with self.assertRaises(ValueError):assess(*self.sample(),[0,1,.5])

    def test_backward_sample_order_rejected(self):
        with self.assertRaises(ValueError):assess([4,3,2,1,0],[0]*5,[0,1,-.5])


if __name__=='__main__':unittest.main()
