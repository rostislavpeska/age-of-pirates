"""Small semantic evidence gate. Input metrics must come from the saved candidate.

This detects omitted scope, not artistic quality. No inferred owner acceptance.
"""
import argparse,json,math
from pathlib import Path
from check_alpha_chain import assess as assess_alpha_chain

def assess(data):
 errors=[]
 required={'field','front_relief','front_opacity','underlip','corners'}
 expected=set(data.get('expected_roofs',[]));roofs=data.get('roofs',{})
 if not expected or set(roofs)!=expected:errors.append('roof inventory incomplete or unexpected')
 for name,r in roofs.items():
  if set(r.get('verified_roles',[]))!=required:errors.append(name+': missing semantic feature')
  gap=r.get('projection_min')
  target=r.get('required_projection')
  if not isinstance(target,(float,int)) or not math.isfinite(target) or target<=0:errors.append(name+': no declared projection target')
  elif not isinstance(gap,(float,int)) or not math.isfinite(gap) or gap<target-1e-5:errors.append(name+': insufficient geometry projection')
  if r.get('interior_bake_misses')!=0:errors.append(name+': missing bake coverage')
  cut=r.get('front_cut_fraction',0)
  if not isinstance(cut,(float,int)) or not .005<cut<.70:errors.append(name+': missing or excessive alpha cut')
  if r.get('reader_mismatch_fraction',1)>.05:errors.append(name+': mismatched repeated/underlip reader')
  if r.get('material_placeholder',True):errors.append(name+': placeholder material remains on required feature')
  if r.get('geometry_and_uv_identity_checked') is not True:errors.append(name+': unbound geometry/UV evidence')
 if data.get('own_pages')!=[2048,2048]:errors.append('military own-page budget drift')
 if data.get('additional_runtime_materials')!=0:errors.append('runtime material proliferation')
 chain=data.get('alpha_chain')
 if not isinstance(chain,dict):errors.append('missing measured backing and rendered alpha-chain evidence')
 else:
  alpha=assess_alpha_chain(chain.get('projection',{}),chain.get('renders',{}),chain.get('expected_faces',{}))
  errors.extend(alpha['errors'])
 return {'verdict':'FAIL' if errors else 'PASS','errors':errors,'scope':'declared eave feature evidence; visual/engine acceptance remains separate'}

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('report',type=Path);a=p.parse_args();r=assess(json.loads(a.report.read_text()));print(json.dumps(r,indent=2));raise SystemExit(r['verdict']!='PASS')
