import sys,copy,unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'scripts'))
from contract import audit,metric_errors
def fixture():
    d={'schema':1,'revision':'r1','stage':'clean','models':['A'],'pages':{'roof':[2048,1024]},'level':'LIVE_VERIFIED','session':'s','operation':'op','views':{},'probes':[]}
    for m in ('density','materials','families'):
        d['views'][m]={'revision':'r1','models':['A'],'reachable':True,'scene':m,'legend':'meaning','density_axes':[159,161],'material_plan':'plan','unresolved_faces':0,'state':'pending','owner_count':0,'member_count':0,'colors_from_actual_families':True}
        d['probes'].append({'model':'A','page':'roof','mode':m,'active_uv':'UV','shader_uv':'UV','editor_uv':'UV','editor_image':'img','shader_image':'img','size':[2048,1024],'out_of_canvas':0,'foreign_page_faces':0,'selected_face_count':6,'pixel_coordinate_error':0})
    return d
class ContractTests(unittest.TestCase):
    def test_early_pending_is_honest(self):self.assertEqual(audit(fixture())['status'],'PASS')
    def test_sharing_requires_actual_completion(self):
        d=fixture();d['stage']='share';self.assertEqual(audit(d)['status'],'FAIL')
    def test_wrong_uv(self):
        d=fixture();d['probes'][0]['shader_uv']='legacy';self.assertEqual(audit(d)['status'],'FAIL')
    def test_repeated_tile_mismatch(self):
        d=fixture();d['probes'][0]['out_of_canvas']=100;self.assertEqual(audit(d)['status'],'FAIL')
    def test_wrong_image(self):
        d=fixture();d['probes'][1]['shader_image']='other';self.assertEqual(audit(d)['status'],'FAIL')
    def test_missing_model(self):
        d=fixture();d['models'].append('B');self.assertEqual(audit(d)['status'],'FAIL')
    def test_file_not_live(self):
        d=fixture();d['level']='FILE_VERIFIED';self.assertEqual(audit(d)['status'],'FAIL')
    def test_chart_colors_not_sharing(self):
        d=fixture();d['views']['families']['colors_from_actual_families']=False;self.assertEqual(audit(d)['status'],'FAIL')
    def test_wrong_canvas_size(self):
        d=fixture();d['probes'][0]['size']=[2048,2048];self.assertEqual(audit(d)['status'],'FAIL')
    def test_silent_rescale(self):
        d=fixture();d['probes'][0]['pixel_coordinate_error']=5;self.assertEqual(audit(d)['status'],'FAIL')
    def test_empty_metrics_cannot_pass(self):self.assertTrue(metric_errors({}))
    def test_pass_wrapper_cannot_hide_defects(self):self.assertTrue(metric_errors({'probe_count':18,'defects':1,'models':3,'views':3}))
if __name__=='__main__':unittest.main()
