"""AoP adapter for the canonical Blendify synchronizer. Audit codex-16/18.
The implementation executes in this module namespace so caller configuration and
fixture overrides affect the same globals. No copied implementation or asset work.
"""
from pathlib import Path
import runpy

_bootstrap_root = Path(__file__).resolve().parents[2]
_env = runpy.run_path(str(_bootstrap_root / 'scripts/tools/local_env.py'))
_value = _env['value']('BLENDIFY_REPO', str(_bootstrap_root))
if not _value:
    raise SystemExit('Set BLENDIFY_REPO before using public skill synchronization.')
_path = Path(_value) / '.claude/skills/public-skill-export/scripts/public_skill_sync.py'
__file__ = str(_path)
exec(compile(_path.read_text(encoding='utf-8-sig'), str(_path), 'exec'), globals())
