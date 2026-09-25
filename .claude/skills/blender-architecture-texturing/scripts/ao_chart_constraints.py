"""Pixelwise feasibility of intentionally overlapping scalar AO charts.

No Blender dependency. Inputs must already correspond in UV, resolution, linear
AO convention, bake distance, and occluder policy. This is NOT an unwrap solver.
Spatial AO variation within an injective chart is valid and is never rejected.
"""
import numpy as np


def assess_stack(values, coverage, error=.05, uncertainty=0.):
    a=np.asarray(values,dtype=float);mask=np.asarray(coverage,dtype=bool)
    if a.shape!=mask.shape or a.ndim<2 or a.shape[0]<2:
        raise ValueError('Expected matching [instances, ...pixels] arrays')
    if error<0 or uncertainty<0 or not np.isfinite(a[mask]).all():
        raise ValueError('Invalid tolerances or covered values')
    if np.any((a[mask]<0)|(a[mask]>1)):
        raise ValueError('AO must be linear ambient visibility in [0,1]')
    count=mask.sum(axis=0);shared=count>=2
    lower=np.min(np.where(mask,a,np.inf),axis=0)
    upper=np.max(np.where(mask,a,-np.inf),axis=0)
    spread=np.where(shared,upper-lower,0.)
    # True range lies within +/-2u of measured range if every input error <=u.
    lower_error=np.maximum(0,spread*.5-uncertainty)
    upper_error=spread*.5+uncertainty
    conflict=shared&(lower_error>error)
    uncertain=shared&~conflict&(upper_error>error)
    compromise=np.zeros_like(lower);covered=count>0
    compromise[covered]=(lower[covered]+upper[covered])*.5
    return dict(shared_pixels=int(shared.sum()),conflict_pixels=int(conflict.sum()),
                uncertain_pixels=int(uncertain.sum()),
                max_required_error=float((spread*.5).max(initial=0)),
                conflict_fraction=float(conflict.sum()/max(1,shared.sum())),
                compatible=not conflict.any() and not uncertain.any(),
                conflict_mask=conflict,uncertain_mask=uncertain,
                minimax_value=compromise,required_error=spread*.5)


if __name__=='__main__':
    import unittest
    class Cases(unittest.TestCase):
        def test_gradient_is_not_a_conflict(self):
            a=np.array([[.1,.5,.9],[.1,.5,.9]])
            self.assertTrue(assess_stack(a,np.ones_like(a,bool))['compatible'])
        def test_different_context_cannot_share(self):
            r=assess_stack([[.25],[.9]],[[1],[1]],.1)
            self.assertFalse(r['compatible']);self.assertAlmostEqual(r['max_required_error'],.325)
        def test_no_shared_texel_no_conflict(self):
            r=assess_stack([[.1,.9],[.9,.1]],[[1,0],[0,1]])
            self.assertTrue(r['compatible']);self.assertEqual(r['shared_pixels'],0)
        def test_small_noise_is_inconclusive(self):
            r=assess_stack([[.4],[.5]],[[1],[1]],.05,.02)
            self.assertFalse(r['compatible']);self.assertEqual(r['uncertain_pixels'],1)
        def test_extremes_not_transitive_pair_chain(self):
            r=assess_stack([[.4],[.48],[.56]],[[1],[1],[1]],.05)
            self.assertFalse(r['compatible']);self.assertAlmostEqual(r['max_required_error'],.08)
    unittest.main()
