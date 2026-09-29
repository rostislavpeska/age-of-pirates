"""Guarded Painter connector: official API plus version-specific semantic Qt adapter.

python painter_connector.py --project FILE.spp --request operation.json
Import Connector for a multi-step recipe; all writes use the same project guard.
"""
import argparse
from contextlib import contextmanager
import json
import time
from pathlib import Path
from urllib.parse import unquote, urlsplit
import sp_remote as sp
import painter_audit as audit


class QuarantinedCommand(RuntimeError):
    audit_outcome = 'blocked'


class Connector:
    def __init__(self, project):
        self.project=Path(project).resolve()
        self.audit_path=self.project.parent/'painter_connector_events.jsonl'
        audit.configure(log_path=self.audit_path, project=str(self.project))
        with self.operation('connect', mutating=False):
            self.version=sp.check()
            if self.version != '9.1.2':
                raise RuntimeError('Legacy Qt adapter is verified only on Painter 9.1.2; got '+str(self.version))
            pid=sp.py('import os\nRESULT=os.getpid()', operation='painter.identity', mutating=False)
            audit.configure(remote_pid=pid, painter_version=self.version)
            self.guard()

    @contextmanager
    def operation(self, name, request=None, mutating=True):
        with audit.Operation('connector.'+name, mutating=mutating, arguments=audit.summary(request)) as trace:
            with audit.endpoint_lock(sp.HOST, sp.PORT):
                yield trace

    def guard(self):
        url=sp.js('alg.project.url()', operation='project.guard', mutating=False)
        path=unquote(urlsplit(url).path).lstrip('/')
        if Path(path).resolve() != self.project:
            raise RuntimeError('Active Painter project differs from requested project: '+str(url))

    def log(self,phase,operation,**fields):
        audit.event(phase, 'connector.note', arguments=audit.summary(operation), **fields)

    def run(self, request):
        with self.operation(request.get('op','invalid'), request, mutating=request.get('op')!='inspect') as trace:
            result=self._run(request)
            trace.finish(result=audit.summary(result))
            return result

    def _run(self, request):
        if request['op'] in ('set_generator_parameter','set_opacity','open_resource_picker','choose_picker',
                             'ensure_generator','bind_generator') or (
                request['op']=='menu_action' and request.get('text')=='Add generator'):
            raise QuarantinedCommand('Command quarantined after failed adapter validation')
        self.guard()
        if request['op']=='select_texture_set':
            name=request['name']
            sp.js('alg.texturesets.setActiveTextureSet('+json.dumps(name)+')', operation='texture_set.select', mutating=True)
            actual=sp.js('alg.texturesets.getActiveTextureSet()', operation='texture_set.read', mutating=False)
            if actual!=[name]:raise RuntimeError('Texture set selection mismatch: '+str(actual))
            return {'texture_set':name}
        source=Path(__file__).with_name('legacy_runtime.py').read_text(encoding='utf-8')
        code=source+'\nRESULT=dispatch('+repr(request)+')\n'
        return sp.later(code, poll=0.25, timeout=30, operation='adapter.'+request['op'],
                        mutating=request['op']!='inspect', script_name='legacy_runtime.py')

    def resource(self, spec):
        with self.operation('resource', spec, mutating='file' in spec) as trace:
            result=self._resource(spec)
            trace.finish(resource_url=result)
            return result

    def _resource(self, spec):
        self.guard()
        if 'url' in spec:return spec['url']
        code='import substance_painter.resource as r\n'
        if 'file' in spec:
            path=Path(spec['file']).resolve()
            if not path.is_file():raise FileNotFoundError(path)
            code+=f'obj=r.import_project_resource({str(path)!r},r.Usage.TEXTURE)\nRESULT=obj.identifier().url()'
        else:
            code+=f'objects=r.Resource.retrieve(r.ResourceID.from_project({spec["name"]!r}))\n'
            code+='assert len(objects)==1, "Resource must be unique"\nRESULT=objects[0].identifier().url()'
        return sp.later(code,poll=.25,timeout=30, operation='resource.import' if 'file' in spec else 'resource.lookup',
                        mutating='file' in spec)

    def save(self):
        with self.operation('save'):
            self.guard()
            return sp.later('import substance_painter.project as p\np.save()\nRESULT={"saved":True}',
                            poll=.5,timeout=90,operation='project.save')

    def export(self,config):
        with self.operation('export',config):
            return self._export(config)

    def _export(self,config):
        self.guard()
        result=sp.later('import substance_painter.export as e\n'
                        +f'r=e.export_project_textures({config!r})\n'
                        +'RESULT={"status":str(r.status),"message":r.message,"files":[f for fs in r.textures.values() for f in fs]}',
                        poll=.5,timeout=300,operation='project.export')
        if result['status']!='ExportStatus.Success':raise RuntimeError('Export not successful: '+str(result))
        for filename in result['files']:
            if not Path(filename).is_file():raise RuntimeError('Export file missing: '+filename)
        return result

    def apply_recipe(self, recipe):
        with self.operation('recipe',recipe):
            return self._apply_recipe(recipe)

    def _apply_recipe(self, recipe):
        for entry in recipe['texture_sets']:
            for layer in entry['layers']:
                if 'generator' in layer or 'opacity' in layer:
                    raise QuarantinedCommand('Generator paths and numeric opacity are quarantined. Recipe rejected before mutations.')
        start=time.monotonic(); results=[]
        for entry in recipe['texture_sets']:
            results.append(self.run({'op':'select_texture_set','name':entry['name']}))
            for layer in entry['layers']:
                name=layer['name']
                results.append(self.run({'op':'ensure_fill','name':name}))
                results.append(self.run({'op':'set_channels','enabled':layer['enabled_channels']}))
                for channel,spec in layer.get('textures',{}).items():
                    results.append(self.run({'op':'bind_texture','channel':channel,'url':self.resource(spec)}))
                if 'generator' in layer:
                    generator=layer['generator']
                    results.append(self.run({'op':'ensure_generator','name':name,'url':generator['url']}))
                    for key,value in generator.get('parameters',{}).items():
                        results.append(self.run({'op':'set_generator_parameter','name':key,'value':value}))
                if 'opacity' in layer:
                    results.append(self.run({'op':'set_opacity','name':name,'value':layer['opacity']}))
            results.append(self.run({'op':'inspect'}))
        if recipe.get('save',True):results.append(self.save())
        if recipe.get('export'):results.append(self.export(recipe['export']))
        return {'seconds':time.monotonic()-start,'operations':results}


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project',required=True)
    group=parser.add_mutually_exclusive_group(required=True)
    group.add_argument('--request',type=Path)
    group.add_argument('--recipe',type=Path)
    parser.add_argument('--report',type=Path)
    args=parser.parse_args()
    connector=Connector(args.project)
    result=connector.apply_recipe(json.loads(args.recipe.read_text(encoding='utf-8'))) if args.recipe else connector.run(json.loads(args.request.read_text(encoding='utf-8')))
    output=json.dumps(result,indent=2)
    if args.report:args.report.write_text(output,encoding='utf-8')
    print(output)
