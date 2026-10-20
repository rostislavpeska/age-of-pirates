"""Read-only cached allocation replay. Audit codex-mixed-atlas-02 / INC-564.

Consumer declarations are mandatory: cached face/resource names do not establish
opacity or shader support. This emits a proposal, never edits a blend or maps.
"""
import argparse
import hashlib
import json
import math
import sys
from pathlib import Path
import numpy as np
from pages import assign_pages, emit
from conjoin import prepare
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'blender-architecture-texturing'/'scripts'))
from uv_metrics import triangle_metrics


def sha(path):
    h=hashlib.sha256()
    with Path(path).open('rb') as f:
        for chunk in iter(lambda:f.read(1024*1024), b''): h.update(chunk)
    return h.hexdigest()


def replay(actual, source, declarations, density, gutter):
    if not math.isfinite(density) or density<=0:
        raise ValueError('explicit positive common density required')
    cache_hash=sha(actual);source_hash=sha(source)
    if cache_hash!=declarations['actual_sha256'] or source_hash!=declarations['source_sha256']:
        raise ValueError('source/cache differs from declared identity')
    data=json.loads(Path(actual).read_text(encoding='utf-8'))
    if data['source_inputs']['source_sha256']!=source_hash:
        raise ValueError('cached extraction belongs to another saved source')
    wanted=set(declarations['faces'])
    rows=[r for r in data['faces'] if r['face'] in wanted]
    if {r['face'] for r in rows}!=wanted:
        raise ValueError('declared face scope missing from saved cache')
    def chart_key(r):
        return r['face'].rsplit('#',1)[0]+':'+str(r['uv_chart'])+':'+str(r['resource'])
    selected_charts={chart_key(r) for r in rows}
    if any(chart_key(r) in selected_charts and r['face'] not in wanted for r in data['faces']):
        raise ValueError('scope fragments a saved source chart')
    records=[];requirements={};area3d={}
    for r in rows:
        key=chart_key(r)
        req=declarations['materials'][r['material_sha256']]
        if key in requirements and requirements[key]!=req:
            raise ValueError('mixed requirements in one source chart')
        requirements[key]=req
        q=np.asarray(r['uv'],float)*declarations['source_sizes'][str(r['resource'])]
        records.append(dict(id=r['face'],chart=key,material=r['material_sha256'],uv=q.tolist()))
        p=np.asarray(r['points'],float)
        area=sum(float(np.linalg.norm(np.cross(p[i]-p[0],p[i+1]-p[0])))/2
                 for i in range(1,len(p)-1))
        area3d[key]=area3d.get(key,0)+area
    # Normalize whole coherent charts by measured area density, not per-page scale.
    charts=prepare(records)
    factors={c['id']:density/math.sqrt(c['area']/area3d[c['id']]) for c in charts}
    for f in records: f['uv']=(np.asarray(f['uv'])*factors[f['chart']]).tolist()
    charts=prepare(records)
    for c in charts: c['requirements']=requirements[c['id']]
    owners=list(range(len(charts)));pages=declarations['pages']
    split=assign_pages(charts,owners,pages,1.,gutter)
    result=dict(status='CAPACITY_REFUSED' if split is None else 'PROPOSAL_ONLY',
        source_sha256=source_hash,actual_sha256=cache_hash,source_inputs=data['source_inputs'],
        source_faces=len(data['faces']),scope_faces=len(rows),scope_charts=len(charts),
        target_equivalent_density=density,common_scale=1.,gutter_rt=gutter,
        dependencies_present=bool(data.get('material_dependencies')),
        declaration_authority=declarations['authority'],split=split,
        limits='Scoped cached geometry/UV proposal; opacity/channel/binding declarations are not pixel evidence; '
               'equivalent chart density normalization does not certify both density axes, tangent normals, '
               'alpha continuity, occupied space outside this scope, saved edits or asset delivery.')
    if split is not None:
        result['faces']=emit(charts,owners,{},pages,1.,split,gutter)
        normalized={f['id']:f for f in records}
        page_sizes={p['name']:p['size'] for p in pages}
        axis_error=0.;low=[];high=[]
        for r in rows:
            row=result['faces'][r['face']]
            for i in range(1,len(r['points'])-1):
                indices=[0,i,i+1];xyz=np.asarray(r['points'])[indices]
                if np.linalg.norm(np.cross(xyz[1]-xyz[0],xyz[2]-xyz[0]))<1e-12:continue
                before=triangle_metrics(xyz,np.asarray(normalized[r['face']]['uv'])[indices],[1,1])
                after=triangle_metrics(xyz,np.asarray(row['uv'])[indices],[page_sizes[row['page']]]*2)
                axis_error=max(axis_error,abs(after['low']/before['low']-1),abs(after['high']/before['high']-1))
                low.append(after['low']);high.append(after['high'])
        if axis_error>1e-6:raise ValueError('page emission changed measured density axes')
        result['density_axes']=dict(max_relative_change_during_emission=axis_error,
            min_low=min(low),max_high=max(high),
            certification='Common page scale verified; measured axis range retained, not an art-density approval')
    return result


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('actual');p.add_argument('source');p.add_argument('declarations');p.add_argument('output')
    p.add_argument('--density',type=float,required=True);p.add_argument('--gutter',type=float,required=True)
    a=p.parse_args();d=json.loads(Path(a.declarations).read_text(encoding='utf-8'))
    result=replay(a.actual,a.source,d,a.density,a.gutter)
    Path(a.output).write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({k:result[k] for k in ('status','scope_faces','scope_charts','dependencies_present')}))
    return 0 if result['status']=='PROPOSAL_ONLY' else 2


if __name__=='__main__':raise SystemExit(main())
