"""Small schema-2 operator smoke check; consumes measured live evidence, not assets."""
import argparse
import json
import re
from pathlib import Path
from profile import validate_page

def audit(d):
    errors=[]
    def need(ok, why):
        if not ok: errors.append(why)
    need(d.get('schema')==2, 'unsupported evidence schema')
    need(bool(d.get('revision')) and bool(d.get('scene')), 'missing revision/scene')
    models=d.get('models',[]); resources=d.get('profile',{}).get('resource_groups',[])
    need(bool(models) and len(set(models))==len(models), 'invalid model census')
    need(bool(resources) and len(set(resources))==len(resources), 'invalid resource census')
    ao_required=d.get('profile',{}).get('ao_review_required',False) or d.get('stage') in ('ao','freeze')
    modes=['DENSITY',*resources,'FAMILIES']+(['AO'] if ao_required else [])
    expected={(m,v) for m in models for v in modes}
    copies=d.get('copies',[])
    need({(c.get('model'),c.get('mode')) for c in copies}==expected and len(copies)==len(expected), 'missing/duplicate copies')
    for c in copies:
        label=f"{c.get('model')}/{c.get('mode')}"
        need(c.get('scene')==d.get('scene') and c.get('visible') is True, label+': not simultaneously visible')
        need(c.get('faces',0)>0, label+': no geometry')
        for key in ('binding_errors','out_of_canvas','correspondence_errors'):
            need(c.get(key)==0, label+': '+key)
        if c.get('mode')=='DENSITY': need(c.get('checker')=='COLOR_GRID', label+': nonstandard checker')
        if c.get('mode') in resources: need(c.get('isolation_errors')==0, label+': rest is not black or target is missing')
        if c.get('mode')=='FAMILIES':
            need(c.get('family_state') in ('verified','pending'), label+': undeclared family state')
            need(c.get('family_state')=='pending' or c.get('family_errors')==0, label+': false sharing')
        if c.get('mode')=='AO':
            need(c.get('ao_kind') in ('unique_reference','resolved_shared'),label+': missing AO purpose')
            need(c.get('texture_baked') is True and c.get('baker') in ('Substance Painter','Blender'),label+': not a texture bake')
            need(c.get('source_coverage_errors')==0,label+': incomplete source geometry')
            need(c.get('runtime_export') is False if c.get('ao_kind')=='unique_reference' else True,label+': diagnostic export leak')
            need(bool(re.fullmatch('[0-9a-f]{64}',c.get('bake_sha256',''))),label+': missing bake identity')
            try:ok=len(c['bake_size'])==2 and validate_page(d['profile'],*c['bake_size'])
            except (KeyError,TypeError):ok=False
            need(ok,label+': diagnostic size violates project policy')
            if d.get('stage')=='freeze':need(c.get('ao_kind')=='resolved_shared',label+': reference cannot stand in for final shared AO')
    for model in models:
        need(len({c.get('faces') for c in copies if c.get('model')==model and c.get('mode')!='AO'})==1, model+': inconsistent geometry coverage')
    pages=d.get('pages',{})
    need(bool(pages),'no pages')
    for page,size in pages.items():
        try: ok=len(size)==2 and validate_page(d['profile'],*size)
        except (KeyError,TypeError): ok=False
        need(ok, page+': violates consumer page policy')
    profile=d.get('profile',{});agreement=profile.get('agreement',{})
    need(agreement.get('status')=='owner_confirmed' and bool(agreement.get('source')),
         'missing explicit session texture-budget agreement')
    budget=profile.get('owned_pages',{})
    need(bool(budget),'missing owned page budget')
    bindings=d.get('page_bindings',{})
    need(set(bindings)==set(pages),'page ownership census mismatch')
    for resource,rule in budget.items():
        owned=[name for name,b in bindings.items() if b.get('resource')==resource and b.get('ownership')=='owned']
        need(len(owned)==rule.get('count'),resource+': owned page count violates agreement')
        for name in owned:need(pages.get(name)==rule.get('size'),name+': owned dimensions violate agreement')
    for name,binding in bindings.items():
        resource=binding.get('resource');kind=binding.get('ownership')
        need(resource in resources,name+': unknown resource')
        if kind=='owned':need(resource in budget,name+': unauthorized owned resource')
        elif kind=='reused':
            source=binding.get('source',{})
            need(bool(source.get('identity')) and bool(source.get('channels')),name+': missing existing source')
            for channel,record in source.get('channels',{}).items():
                need(bool(record.get('runtime')) and bool(re.fullmatch('[0-9a-f]{64}',record.get('sha256',''))),name+': missing source identity for '+channel)
        else:need(False,name+': unknown ownership')
    for key,dependency in profile.get('shared_dependencies',{}).items():
        resource=dependency.get('resource_group')
        need(bool(resource),key+': shared dependency lacks resource group')
        matches=[(name,b) for name,b in bindings.items() if b.get('resource')==resource]
        need(bool(matches),key+': missing shared dependency')
        for name,b in matches:
            need(b.get('ownership')=='reused' and b.get('source',{}).get('identity')==dependency.get('identity'),name+': substituted shared atlas')
            need(pages.get(name)==dependency.get('size'),name+': shared source dimensions mismatch')
    p=d.get('selection',{})
    need(p.get('faces',0)>0 and p.get('foreign_page_faces')==0,'selection missing or mixes pages')
    need(bool(p.get('active_uv')) and p.get('active_uv')==p.get('shader_uv')==p.get('editor_uv'),'selection UV mismatch')
    need(bool(p.get('editor_image')) and p.get('editor_image')==p.get('shader_image'),'selection image mismatch')
    need(d.get('density_status') in ('pending','failed','verified'),'density status not disclosed')
    return {'status':'FAIL' if errors else 'PASS','errors':errors,'copies':len(copies),'models':len(models),'scope':'operator data and declared budget smoke; not visual delivery, source-authority verification, UV quality, AO or independent agent compliance'}

if __name__=='__main__':
    ap=argparse.ArgumentParser();ap.add_argument('evidence');ap.add_argument('--out');a=ap.parse_args()
    r=audit(json.loads(Path(a.evidence).read_text(encoding='utf-8-sig')))
    if a.out:Path(a.out).write_text(json.dumps(r,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(r,indent=2));raise SystemExit(r['status']!='PASS')
