"""Preserve the old conflicting allocation and verify actual consumer emission."""
import unittest
import numpy as np
from pages import assign_pages, emit
from conjoin import prepare
from test_pages import rect
from page_allocation import compatible


def pages():
    return [dict(name='alpha1024',size=1024,binding='matB',capabilities=dict(
        opacity=['opaque','cutout'],channels=['color','normal','alpha'],source_bindings=['wall','cut'])),
        dict(name='opaque2048',size=2048,binding='matA',capabilities=dict(
        opacity=['opaque'],channels=['color','normal'],source_bindings=['wall']))]


class MixedPagesTests(unittest.TestCase):
    def charts(self):
        charts=prepare(rect('cut',400,400,'EAVE_CUTOUT')+rect('wall',400,400,'PLASTER')+
                       rect('large',1700,1700,'PLASTER'))
        for c in charts:
            cut=c['mat']=='EAVE_CUTOUT'
            c['requirements']=dict(opacity='cutout' if cut else 'opaque',
                channels=['color','alpha'] if cut else ['color','normal'],binding='cut' if cut else 'wall')
        return charts

    def test_preserved_old_negative_and_valid_mixed_emission(self):
        charts=self.charts()
        old=[dict(name='opaque2048',size=2048),dict(name='alpha1024',size=1024,
             prefer=['EAVE_CUTOUT','ROOF_TRIM','ROOF_TILE'],must=['EAVE_CUTOUT'])]
        self.assertIsNone(assign_pages(charts,[0,1,2],old,1.,8.))
        split=assign_pages(charts,[0,1,2],pages(),1.,8.)
        plan=emit(charts,[0,1,2],{},pages(),1.,split,8.)
        self.assertEqual(plan['wall:0']['page'],'alpha1024')
        self.assertEqual(plan['cut:0']['page'],'alpha1024')
        self.assertEqual(plan['wall:0']['binding'],'matB')
        for c in charts:
            row=plan[c['id']+':0']; p=next(p for p in pages() if p['name']==row['page'])
            q=np.array(row['uv'])*p['size']
            self.assertAlmostEqual(np.linalg.norm(q[1]-q[0]), np.linalg.norm(
                np.array(c['faces'][0]['uv'])[1]-np.array(c['faces'][0]['uv'])[0]))

    def test_explicit_split_cannot_bypass_cutout_requirement(self):
        with self.assertRaisesRegex(ValueError,'incompatible'):
            emit(self.charts(),[0,1,2],{},pages(),1.,{'alpha1024':[1], 'opaque2048':[0,2]},8.)

    def test_member_requirement_is_checked_too(self):
        charts=self.charts();charts[1]['requirements']['channels']=['height']
        with self.assertRaisesRegex(ValueError,'incompatible'):
            emit(charts,[0,2],{1:(1.,0,np.eye(3),1.,1.)},pages(),1.,
                 {'alpha1024':[0], 'opaque2048':[2]},8.)

    def test_empty_explicit_contract_cannot_downgrade_to_legacy(self):
        with self.assertRaisesRegex(ValueError,'capability'):
            assign_pages(self.charts(),[0,1,2],[dict(name='broken',size=2048,binding='x',capabilities={})],1.)

    def test_legacy_must_rule_cannot_be_silently_ignored(self):
        p=pages();p[0].update(prefer=['OTHER'],must=['OTHER'])
        with self.assertRaisesRegex(ValueError,'legacy material'):
            assign_pages(self.charts(),[0,1,2],p,1.)


if __name__ == '__main__': unittest.main()
