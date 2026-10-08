import sys,copy,json,tempfile,unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'scripts'))
from contract import audit
from profile import load

def fixture():
    d={'schema':2,'revision':'r1','scene':'review','models':['A','B','C'],'profile':{'resource_groups':['WALLS','ROOFS','GENERIC','POTTERY'],'page_sizes':[512,1024,2048],'square_only':True},'copies':[],'pages':{'walls':[2048,2048]},'density_status':'failed','selection':{'faces':6,'foreign_page_faces':0,'active_uv':'UV','shader_uv':'UV','editor_uv':'UV','editor_image':'grid','shader_image':'grid'}}
    d['profile'].update(agreement={'status':'owner_confirmed','source':'fixture operator message'},owned_pages={'WALLS':{'count':1,'size':[2048,2048]}},shared_dependencies={'generic':{'resource_group':'GENERIC','identity':'shared-r1','size':[1024,1024]}})
    d['pages']['generic']=[1024,1024]
    d['page_bindings']={'walls':{'resource':'WALLS','ownership':'owned'},'generic':{'resource':'GENERIC','ownership':'reused','source':{'identity':'shared-r1','channels':{'BaseColor':{'runtime':'art/shared.ddt','sha256':'a'*64}}}}}
    for model in d['models']:
        for mode in ['DENSITY',*d['profile']['resource_groups'],'FAMILIES']:
            d['copies'].append({'model':model,'mode':mode,'scene':'review','visible':True,'faces':10,'binding_errors':0,'out_of_canvas':0,'correspondence_errors':0,'checker':'COLOR_GRID','isolation_errors':0,'family_state':'verified','family_errors':0})
    return d
class Smoke(unittest.TestCase):
    def test_ao_checkpoint_rejects_missing_fake_and_exported_reference(self):
        d=fixture();d['stage']='ao'
        self.assertEqual(audit(d)['status'],'FAIL')
        for model in d['models']:
            d['copies'].append(dict(model=model,mode='AO',scene='review',visible=True,faces=20,binding_errors=0,out_of_canvas=0,correspondence_errors=0,ao_kind='unique_reference',texture_baked=True,baker='Substance Painter',source_coverage_errors=0,runtime_export=False,bake_sha256='f'*64,bake_size=[2048,2048]))
        self.assertEqual(audit(d)['status'],'PASS')
        for change in [lambda c:c.update(texture_baked=False),lambda c:c.update(runtime_export=True),lambda c:c.update(source_coverage_errors=1),lambda c:c.update(bake_size=[2048,1024]),lambda c:c.update(bake_sha256='missing')]:
            bad=copy.deepcopy(d);change(bad['copies'][-1]);self.assertEqual(audit(bad)['status'],'FAIL')
        d['stage']='freeze';self.assertEqual(audit(d)['status'],'FAIL')
    def test_accepted_layout_with_honest_quality_failure(self): self.assertEqual(audit(fixture())['status'],'PASS')
    def test_rejected_regressions(self):
        mutations=[lambda d:d['copies'].pop(),lambda d:d['copies'][0].update(scene='other'),lambda d:d['copies'][0].update(visible=False),lambda d:d['copies'][0].update(checker='CUSTOM'),lambda d:d['copies'][1].update(isolation_errors=1),lambda d:d['copies'][5].update(family_errors=1),lambda d:d['pages'].update(walls=[2048,1024]),lambda d:d['selection'].update(shader_uv='wrong'),lambda d:d['copies'][0].update(correspondence_errors=1),lambda d:d['selection'].update(foreign_page_faces=1)]
        for i,change in enumerate(mutations):
            with self.subTest(regression=i):
                d=fixture();change(d);self.assertEqual(audit(d)['status'],'FAIL')
    def test_subproject_override(self):
        with tempfile.TemporaryDirectory() as td:
            p=Path(td)/'p.json';p.write_text(json.dumps({'page_sizes':[4096],'square_only':False,'resource_groups':['A'],'subprojects':{'small':{'page_sizes':[512],'square_only':True}}}))
            resolved=load(p,'small');self.assertEqual(resolved['page_sizes'],[512]);self.assertTrue(resolved['square_only']);self.assertEqual(resolved['resource_groups'],['A'])
    def test_budget_regressions(self):
        mutations=[lambda d:d['profile'].pop('agreement'),lambda d:d['pages'].update(extra=[2048,2048]),lambda d:d['page_bindings']['generic'].update(ownership='owned'),lambda d:d['page_bindings']['generic']['source'].update(identity='other-atlas'),lambda d:d['profile']['owned_pages']['WALLS'].update(count=2)]
        for i,change in enumerate(mutations):
            with self.subTest(regression=i):
                d=fixture();change(d);self.assertEqual(audit(d)['status'],'FAIL')
    def test_inherited_all_ages_dependency_and_cycle(self):
        with tempfile.TemporaryDirectory() as td:
            p=Path(td)/'p.json';raw={'page_sizes':[512,1024,2048],'square_only':True,'subprojects':{'korean':{'shared_dependencies':{'atlas':'all-ages'}},'houses':{'extends':'korean','owned_pages':{'walls':1,'roofs':1}}}};p.write_text(json.dumps(raw));r=load(p,'houses');self.assertEqual(r['shared_dependencies']['atlas'],'all-ages');self.assertEqual(r['owned_pages']['walls'],1)
            raw['subprojects']['korean']['extends']='houses';p.write_text(json.dumps(raw))
            with self.assertRaises(ValueError):load(p,'houses')
if __name__=='__main__':unittest.main()
