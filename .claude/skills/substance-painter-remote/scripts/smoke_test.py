"""Smoke test of the Painter capabilities the skill relies on (needs Painter with remote scripting).

python smoke_test.py [mesh.fbx] [map.png]
Refuses to run when a project is open. Creates a throwaway project from the mesh (default:
Painter's own automated-test FBX), lists texture sets, imports the image as a project resource,
assigns it as the AO mesh map of the first texture set, reads it back, closes WITHOUT saving.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import sp_remote  # noqa: E402

PAINTER = Path(r'C:\Program Files\Adobe\Adobe Substance 3D Painter')
mesh = sys.argv[1] if len(sys.argv) > 1 else str(PAINTER / 'resources/python/modules/automated_tests/resources/4cubes3udims.fbx')
image = sys.argv[2] if len(sys.argv) > 2 else None
IMPORTS = 'import substance_painter.project as p, substance_painter.textureset as ts, substance_painter.resource as r\n'

print('painter', sp_remote.check() or sys.exit('not reachable'))
assert sp_remote.py(IMPORTS + 'RESULT = p.is_open()') is False, 'a project is open - close it first'
sp_remote.later(IMPORTS + f'p.create({mesh!r})',
                until=IMPORTS + 'RESULT = p.is_open() and not p.is_busy() and bool(ts.all_texture_sets())')
result = sp_remote.py(IMPORTS + 'sets = ts.all_texture_sets()\n'
                      'RESULT = dict(sets=[s.name() for s in sets], resolution=[s.get_resolution().width for s in sets])')
if image:
    result['ao_map'] = sp_remote.py(IMPORTS + f'res = r.import_project_resource({image!r}, r.Usage.TEXTURE)\n'
                                    's = ts.all_texture_sets()[0]\n'
                                    's.set_mesh_map_resource(ts.MeshMapUsage.AO, res.identifier())\n'
                                    'RESULT = s.get_mesh_map_resource(ts.MeshMapUsage.AO).url()')
sp_remote.later(IMPORTS + 'p.close()', until=IMPORTS + 'RESULT = not p.is_open()')
result['closed'] = True
print(result)
