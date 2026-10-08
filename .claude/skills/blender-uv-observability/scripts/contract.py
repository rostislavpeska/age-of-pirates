"""Validate extracted operator-view evidence; does not trust a PASS label."""
import argparse,json,math
from pathlib import Path

MODES=('density','materials','families')
def audit(d):
    errors=[]
    def require(ok,msg):
        if not ok:errors.append(msg)
    require(d.get('schema')==1,'schema missing/unsupported')
    require(bool(d.get('revision')),'revision missing')
    models=d.get('models',[]);require(bool(models) and len(models)==len(set(models)),'model census missing/duplicated')
    require(d.get('level')=='LIVE_VERIFIED','live readback required')
    require(bool(d.get('session')) and bool(d.get('operation')),'live session/operation missing')
    views=d.get('views',{})
    for mode in MODES:
        v=views.get(mode,{})
        require(v.get('revision')==d.get('revision'),mode+': stale revision')
        require(set(v.get('models',[]))==set(models),mode+': incomplete model coverage')
        require(v.get('reachable') is True,mode+': not reachable')
        require(bool(v.get('scene')) and bool(v.get('legend')),mode+': missing scene/legend')
        if mode=='density':
            values=v.get('density_axes',[])
            require(len(values)==2 and all(isinstance(x,(int,float)) and math.isfinite(x) and x>0 for x in values),mode+': missing measured two-axis density')
        if mode=='materials':
            require(bool(v.get('material_plan')) and isinstance(v.get('unresolved_faces'),int),mode+': missing material allocation evidence')
        if mode=='families':
            ready=v.get('state')=='verified'
            require(v.get('state') in ('pending','verified'),mode+': unknown readiness')
            require(isinstance(v.get('owner_count'),int) and isinstance(v.get('member_count'),int),mode+': missing actual sharing census')
            require(v.get('colors_from_actual_families') is True,mode+': arbitrary chart colors')
            if d.get('stage') in ('share','ao','freeze'):require(ready,'sharing checkpoint cannot consume pending families')
    probes=d.get('probes',[])
    expected={(m,p,v) for m in models for p in d.get('pages',{}) for v in MODES}
    actual={(p.get('model'),p.get('page'),p.get('mode')) for p in probes}
    require(bool(expected) and actual==expected,'missing or extraneous model/page/mode probes')
    require(len(actual)==len(probes),'duplicate probes')
    for p in probes:
        label='/'.join(str(p.get(k,'')) for k in ('model','page','mode'))
        uv=p.get('active_uv')
        require(bool(uv) and uv==p.get('shader_uv')==p.get('editor_uv'),label+': UV-layer mismatch')
        require(bool(p.get('editor_image')) and p.get('editor_image')==p.get('shader_image'),label+': image mismatch')
        require(p.get('size')==d.get('pages',{}).get(p.get('page')),label+': image dimensions mismatch')
        require(p.get('out_of_canvas')==0,label+': UVs outside shown image')
        require(p.get('foreign_page_faces')==0,label+': multiple pages over one image')
        require(p.get('selected_face_count',0)>0,label+': no editable selected faces')
        err=p.get('pixel_coordinate_error')
        require(isinstance(err,(int,float)) and math.isfinite(err) and 0<=err<=.002,label+': changed/unmeasured pixel mapping')
    return {'status':'FAIL' if errors else 'PASS','errors':errors,'metrics':{'probe_count':len(probes),'defects':len(errors),'models':len(models),'views':len(views)}}

def metric_errors(metrics):
    e=[]
    for k in ('probe_count','defects','models','views'):
        v=metrics.get(k)
        if not isinstance(v,int) or isinstance(v,bool) or v<0:e.append('missing/invalid '+k)
    if metrics.get('defects')!=0:e.append('operator view defects remain')
    if metrics.get('views')!=3 or metrics.get('models',0)<1 or metrics.get('probe_count',0)<3:e.append('operator evidence incomplete')
    return e

if __name__=='__main__':
    ap=argparse.ArgumentParser();ap.add_argument('evidence');ap.add_argument('--out');a=ap.parse_args();r=audit(json.loads(Path(a.evidence).read_text()))
    if a.out:Path(a.out).write_text(json.dumps(r,indent=2))
    print(json.dumps(r,indent=2));raise SystemExit(0 if r['status']=='PASS' else 1)
