"""Shared host/Blender helpers for the organic UV tools (standard library only, no bpy).

Finding Blender, building the background command line and the scratch-only output rule come from the companion skill
`blender-organic-modeling/scripts/blender_env.py` (one source; never copied here). This module adds:

- `out_path(path, what)`: an absolute output path outside every git work tree, else SystemExit(2) with a SETUP ERROR;
- `read_json(path)` / `write_json(path, data)`: UTF-8 JSON with a computed-before-written body (a failing dump never
  truncates an existing file);
- `run_blender(script, args, blend=None, ...)`: background Blender with --factory-startup and --python-exit-code 2.

Blender is found in this order: --blender-exe, --local-config FILE (tools.blender.path), BLENDER, `blender` on PATH,
the standard install folder (newest first). A path named by the first three that is not a file stops the tool.
"""
import json
import os
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
_COMPANION = HERE.parents[1] / 'blender-organic-modeling' / 'scripts'
if str(_COMPANION) not in sys.path:
    sys.path.append(str(_COMPANION))
try:
    import blender_env as E  # noqa: E402
except ImportError:  # pragma: no cover - only when the companion package is missing
    sys.exit('SETUP ERROR: companion skill blender-organic-modeling (scripts/blender_env.py) not found')

find_blender = E.find_blender
add_blender_args = E.add_blender_args
split_blender_args = E.split_blender_args
blender_command = E.blender_command
refuse_in_worktree = E.refuse_in_worktree
git_worktree = E.git_worktree


class SetupError(SystemExit):
    """Exit 2 with a SETUP ERROR line."""

    def __init__(self, msg):
        print('SETUP ERROR: %s' % msg, file=sys.stderr)
        super().__init__(2)


def out_path(path, what='output'):
    """Absolute path for an output file or folder; refuses paths inside a git work tree."""
    if not path:
        raise SetupError('%s path missing' % what)
    p = Path(path).expanduser()
    if not p.is_absolute():
        p = Path.cwd() / p
    p = p.resolve()
    why = refuse_in_worktree(p, what)
    if why:
        raise SetupError(why)
    return p


def read_json(path):
    try:
        return json.loads(Path(path).read_text(encoding='utf-8-sig'))
    except (OSError, ValueError) as exc:
        raise SetupError('cannot read JSON %s: %s' % (path, exc))


def write_json(path, data, indent=1):
    text = json.dumps(data, indent=indent)          # computed first: a failing dump leaves the old file intact
    p = Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(text, encoding='utf-8')
    return p


def resolve_blender(blender_exe=None, local_config=None):
    try:
        exe = find_blender(blender_exe, local_config)
    except ValueError as exc:
        raise SetupError(str(exc))
    if not exe:
        named = blender_exe or (local_config and 'tools.blender.path in ' + str(local_config)) or os.environ.get('BLENDER')
        raise SetupError('MISSING Blender%s: pass --blender-exe EXE or --local-config FILE, set BLENDER, or put blender '
                         'on PATH' % (' (%s is not a file)' % named if named else ''))
    return exe


def run_blender(exe, script, args, blend=None, log=None, timeout=3600):
    """Run `script` in background Blender; returns (returncode, text). The text is also written to `log`."""
    cmd = blender_command(exe, script, args, blend=blend)
    r = subprocess.run(cmd, capture_output=True, text=True, errors='replace', timeout=timeout)
    text = (r.stdout or '') + (r.stderr or '')
    if log:
        Path(log).write_text(text, encoding='utf-8')
    return r.returncode, text


def blender_argv():
    """Arguments after `--` inside Blender (empty outside)."""
    return sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
