"""Assess measured front/backing projection AND controlled rendered silhouettes.

Producer-independent fixtures use wrong backing UVs and forced opaque rendering.
Counts alone never certify appearance; retain hashes, views and owner review.
"""
import math


def assess_clearance(measured, expected_fronts, views, max_fraction=.05):
 """INC-103: all declared roof perimeters/views, with actual alpha-aware rays.

 Call with the authoritative expected inventory, not only measured roof names.
 This validates measurements, not their producer; retain hashed source scenes,
 a known failed specimen and shaded views alongside the report.
 """
 errors=[]
 if not expected_fronts or not views or len(set(views))!=len(views):
  return {'verdict':'FAIL','errors':['empty or duplicate expected inventory']}
 required={roof+'|'+view for roof in expected_fronts for view in views}
 if set(measured)!=required:errors.append('missing or extra roof/view evidence')
 for roof,fronts in expected_fronts.items():
  if not fronts or len(set(fronts))!=len(fronts):errors.append(roof+': invalid front inventory')
  for view in views:
   key=roof+'|'+view;r=measured.get(key,{})
   ids=r.get('fronts',[])
   if len(ids)!=len(set(ids)) or set(ids)!=set(fronts):errors.append(key+': omitted/duplicate perimeter faces')
   count=r.get('samples');blocked=r.get('blocked')
   perface=r.get('face_samples',{})
   if set(perface)!=set(fronts) or not all(isinstance(v,int) and not isinstance(v,bool) and v>=3 for v in perface.values()) or sum(perface.values())!=count:
    errors.append(key+': missing transparent samples on a perimeter face')
   if not all(isinstance(v,int) and not isinstance(v,bool) for v in [count,blocked]) or count<100 or not 0<=blocked<=count:
    errors.append(key+': invalid/insufficient measured samples');continue
   fraction=r.get('blocked_fraction')
   if not isinstance(fraction,(int,float)) or not math.isfinite(fraction) or abs(fraction-blocked/count)>1e-8:
    errors.append(key+': inconsistent blocked fraction');continue
   if fraction>max_fraction:errors.append(key+': cutout clearance obstructed')
 return {'verdict':'FAIL' if errors else 'PASS','errors':errors,
         'scope':'local gap clearance over declared roofs/views; visual and engine acceptance separate'}

def assess(projection, renders, expected_faces):
 errors=[]
 if not expected_faces or set(projection)!=set(expected_faces) or set(renders)!=set(expected_faces):
  errors.append('incomplete building evidence')
 for kind,count in expected_faces.items():
  p=projection.get(kind,{})
  if len(p.get('faces',[]))!=count:errors.append(kind+': omitted underlip faces')
  if p.get('cut_front_samples',0)<=0:errors.append(kind+': no projected cut samples')
  if not 0<=p.get('mismatch_fraction',1)<=.05:errors.append(kind+': opaque backing behind cut front')
  r=renders.get(kind,{})
  if r.get('reference_cut_pixels',0)<100:errors.append(kind+': render is not a useful silhouette view')
  if not 0<=r.get('blocked_fraction',1)<=.05:errors.append(kind+': rendered cutout is obstructed')
 return {'verdict':'FAIL' if errors else 'PASS','errors':errors,'scope':'measured backing readers and declared controlled views; owner/engine acceptance separate'}
