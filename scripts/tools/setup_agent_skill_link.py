"""AoP bootstrap for canonical Blendify discovery. Audit 2026-10-13-codex-16/18."""
from pathlib import Path
import importlib.util
import json
import runpy

ROOT = Path(__file__).resolve().parents[2]
_env = runpy.run_path(str(ROOT / 'scripts/tools/local_env.py'))
_configured = _env['value']('BLENDIFY_REPO', str(ROOT))
if not _configured:
    raise SystemExit('Set BLENDIFY_REPO in config/aop.local.env, then retry skill setup.')
_library = Path(_configured).resolve(strict=True)
_marker = json.loads((_library / 'config/skill-library.json').read_text(encoding='utf-8'))
if _marker.get('id') != 'blendify' or _marker.get('schemaVersion') != 1:
    raise SystemExit('BLENDIFY_REPO is not a compatible canonical Blendify checkout.')
_spec = importlib.util.spec_from_file_location('blendify_skill_setup', _library / 'scripts/skill_setup.py')
_module = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_module)
def setup(root=ROOT, **kwargs):
    return _module.setup(root, **kwargs)
catalog = _module.catalog
is_link = _module.is_link

if __name__ == '__main__':
    _module.main(default_root=ROOT)
