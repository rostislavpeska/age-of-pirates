"""Small, separately queued Painter 9.1.2 adapter steps.

Internal Qt adapter, not Adobe's public layer API. Exact PID and saved project are
required. Never use an arbitrary current window, coordinate or unguarded retry.
"""
import json
import os
from pathlib import Path
import sp_remote as sp
import painter_audit as audit


STEPS = r'''
def refresh():
    ALL_WIDGETS.extend(APP.allWidgets())

def select_mask(name):
    icon=one(widgets(layer_view(name),cls='QToolButton',name='maskIcon'),'mask icon')
    if icon.isHidden():
        return menu_action('addMask','Add black mask')
    activate_widget(icon)
    return {'selected_mask':name}

def effects(name):
    return [w for w in widgets(layer_view(name),cls='Alg::ActionView')]

def effect_labels(w):
    return [c.property('text') for c in widgets(w,cls='Alg::EditLabel') if c.objectName() in ('name','label')]

def select_generator(name,display):
    found=[w for w in effects(name) if display in effect_labels(w)]
    activate_widget(one(found,'generator '+display))
    return {'selected_generator':display}

def generator_value(name,value):
    root=one((w for w in widgets(cls='Alg::GeneratorView') if w.isVisible()),'generator properties')
    slider=one(widgets(root,cls='Alg::Slider',name=name),'generator parameter '+name)
    before=slider.property('value')
    minimum,maximum=slider.property('min'),slider.property('max')
    if not minimum<=float(value)<=maximum:
        raise ValueError('Parameter outside declared control range')
    audit_step('parameter.native_property.'+name,'before')
    if not slider.setProperty('value',float(value)):
        raise RuntimeError('Native value property is not writable')
    audit_step('parameter.native_property.'+name,'after')
    refresh()
    slider=one(widgets(root,cls='Alg::Slider',name=name),'refreshed generator parameter')
    actual=slider.property('value')
    if abs(actual-float(value))>1e-5:
        raise RuntimeError('Parameter readback mismatch')
    return {'parameter':name,'before':before,'after':actual}

def layer_opacity(name,value):
    root=layer(name).parentWidget()
    menu=one(widgets(root,cls='QMenu',name='opacityMenu'),'layer opacity menu')
    slider=one(widgets(menu,cls='Alg::Slider'),'opacity slider')
    if not 0<=float(value)<=100:
        raise ValueError('Opacity must be 0..100')
    before=slider.property('value')
    if not slider.setProperty('value',float(value)):
        raise RuntimeError('Opacity value property is not writable')
    return {'before':before,'after':slider.property('value')}

def session_dispatch(r):
    refresh()
    op=r['op']
    if op=='inspect':return inspect()
    if op=='inspect_generator':
        root=one((w for w in widgets(cls='Alg::GeneratorView') if w.isVisible()),'generator properties')
        return {w.objectName():w.property('value') for w in widgets(root,cls='Alg::Slider') if w.isVisible()}
    if op=='ensure_fill':return add_fill(r['name'])
    if op=='select_layer':return select_layer(r['name'])
    if op=='set_channels':return set_channels(r['enabled'])
    if op=='bind_texture':return bind_texture(r['channel'],r['url'])
    if op=='select_mask':return select_mask(r['name'])
    if op=='ensure_generator_effect':
        found=effects(r['name'])
        named=[w for w in found if r['display'] in effect_labels(w)]
        if len(named)==1:return {'created':False}
        if found:raise RuntimeError('Unexpected existing effects; inspect before another insertion')
        return menu_action('addEffect','Add generator')
    if op=='select_generator':return select_generator(r['name'],r['display'])
    if op=='bind_generator':
        root=one((w for w in widgets(cls='Alg::GeneratorView') if w.isVisible()),'generator properties')
        return bind_resource(one(widgets(root,cls='Alg::DropZoneWidget',name='generator'),'generator source'),r['url'])
    if op=='set_generator_value':return generator_value(r['name'],r['value'])
    if op=='set_layer_opacity':raise RuntimeError('Opacity mutation is unverified; not part of the bounded tested adapter')
    raise ValueError('Unsupported bounded adapter step: '+op)
'''


class LegacySession:
    def __init__(self, project, pid):
        self.project=Path(project).resolve()
        self.pid=int(pid)
        if os.environ.get('PAINTER_EXPECT_PID') != str(self.pid):
            raise RuntimeError('Set PAINTER_EXPECT_PID explicitly to this session PID')
        audit.configure(project=str(self.project),log_path=self.project.parent/'painter_connector_events.jsonl')
        if sp.check()!='9.1.2':
            raise RuntimeError('This internal adapter is verified only for9.1.2; probe capabilities and use the public layer API on newer releases')
        self.guard()
        self.source=Path(__file__).with_name('legacy_runtime.py').read_text(encoding='utf-8')+'\n'+STEPS

    def guard(self):
        identity=sp.py('import os\nimport substance_painter.project as p\nRESULT={"pid":os.getpid(),"path":p.file_path() if p.is_open() else None}',
                       timeout=5,operation='session.identity',mutating=False)
        if identity['pid']!=self.pid or not identity['path'] or Path(identity['path']).resolve()!=self.project:
            raise RuntimeError('Painter PID or active project changed; no mutation allowed')

    def step(self, request):
        self.guard()
        # Keep wrappers alive across event-loop turns, and reacquire controls after
        # a stack mutation. Do not pass stale widget objects to a later job.
        key=str(self.project)
        inputs='\n'.join(name+'='+repr(value) for name,value in {
            'wanted_pid':self.pid,'wanted_project':self.project.as_posix(),
            'session_key':key,'adapter_source':self.source,'session_steps':STEPS,'request':request}.items())+'\n'
        code=inputs+'''import builtins, os
import substance_painter.project as p
assert os.getpid()==wanted_pid and p.file_path().replace(chr(92),'/')==wanted_project
if not hasattr(builtins,'_sp_legacy_sessions'):builtins._sp_legacy_sessions={}
cache=builtins._sp_legacy_sessions
if session_key not in cache:
    cache[session_key]={'__name__':'guarded_legacy_session','_sp_audit_step':_sp_audit_step}
    exec(adapter_source,cache[session_key])
g=cache[session_key];g['_sp_audit_step']=_sp_audit_step
exec(session_steps,g)
RESULT=g['session_dispatch'](request)
'''
        return sp.later(code,poll=.25,timeout=30,operation='bounded_adapter.'+request['op'],
                        mutating=request['op'] not in ('inspect','inspect_generator'),script_name='legacy_session.py')

    def select_texture_set(self,name):
        self.guard()
        sp.js('alg.texturesets.setActiveTextureSet('+json.dumps(name)+')',timeout=10,
              operation='texture_set.select',mutating=True)
        actual=sp.js('alg.texturesets.getActiveTextureSet()',timeout=5,operation='texture_set.read',mutating=False)
        if actual!=[name]:raise RuntimeError('Texture set readback mismatch')
