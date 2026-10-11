"""Host-side helpers for the organic tools: find Blender, keep output out of git work trees, run a bpy script.

No bpy. Blender is found in this order (the first source that names a path decides):
  1. --blender-exe EXE on the tool's command line;
  2. --local-config FILE: a JSON {"tools": {"blender": {"path": "..."}}} (the library's local tool-path file);
  3. the BLENDER environment variable;
  4. `blender` on PATH;
  5. the standard install folders (Windows `Program Files/Blender Foundation/Blender <version>/blender.exe`, newest
     version first; macOS `/Applications/Blender.app`).
A path named by 1-3 that is not a file gives "missing"; there is no silent fallback to a later source.
Every tool writes only to a scratch folder: a path inside any git work tree is refused, and the default is a fresh
folder in the system temp directory.

    python blender_env.py [--blender-exe EXE] [--local-config FILE]   # prints the executable, exit 1 when none
"""
import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

BLENDER_ARGS = ('--blender-exe', '--local-config')


def _version_key(path):
    m = re.search(r'(\d+)\.(\d+)', str(path.parent.name))
    return (int(m.group(1)), int(m.group(2))) if m else (0, 0)


def configured_blender(local_config):
    """tools.blender.path from a local tool-path JSON, '' when the file names none; ValueError when unreadable."""
    try:
        data = json.loads(Path(local_config).read_text(encoding='utf-8-sig'))
    except (OSError, ValueError) as exc:
        raise ValueError('local config %s: %s' % (local_config, exc))
    tools = data.get('tools') if isinstance(data, dict) else None
    if not isinstance(tools, dict):
        raise ValueError('local config %s: expected {"tools": {...}}' % local_config)
    entry = tools.get('blender') or {}
    path = entry.get('path', '') if isinstance(entry, dict) else ''
    if not isinstance(path, str):
        raise ValueError('local config %s: tools.blender.path must be a string' % local_config)
    return path


def find_blender(explicit=None, local_config=None):
    """Path of a Blender executable, or None (order in the module docstring)."""
    for named in (explicit, configured_blender(local_config) if local_config else '', os.environ.get('BLENDER')):
        if named:
            return str(Path(named).expanduser()) if Path(named).expanduser().is_file() else None
    found = shutil.which('blender')
    if found:
        return found
    candidates = []
    for base in (os.environ.get('ProgramFiles'), os.environ.get('ProgramW6432'), 'C:/Program Files'):
        if base:
            candidates += list(Path(base, 'Blender Foundation').glob('Blender */blender.exe'))
    candidates.sort(key=_version_key, reverse=True)
    mac = Path('/Applications/Blender.app/Contents/MacOS/Blender')
    if mac.is_file():
        candidates.append(mac)
    return str(candidates[0]) if candidates else None


def add_blender_args(ap):
    """The Blender-location options on a tool's parser (used by the host form; ignored inside Blender)."""
    ap.add_argument('--blender-exe', metavar='EXE', help='Blender executable for the host form (first choice)')
    ap.add_argument('--local-config', metavar='FILE', help='local tool-path JSON whose tools.blender.path names '
                    'Blender for the host form (before BLENDER, PATH and the standard folders)')


def split_blender_args(argv):
    """(blender_exe, local_config, remaining argv): the Blender-location options taken out of a host command line."""
    p = argparse.ArgumentParser(add_help=False, allow_abbrev=False)
    add_blender_args(p)
    known, rest = p.parse_known_args([str(a) for a in argv])
    return known.blender_exe, known.local_config, rest


def git_worktree(path):
    """The git work tree containing `path` (or its nearest existing parent), else None."""
    p = Path(path).resolve()
    while not p.exists() and p != p.parent:
        p = p.parent
    for q in (p, *p.parents):
        if (q / '.git').exists():
            return q
    return None


def refuse_in_worktree(path, what='output'):
    """Error text when `path` lies inside a git work tree (scratch-only rule), else None."""
    tree = git_worktree(path)
    if tree is not None:
        return '%s %s is inside the git work tree %s; write to a scratch folder instead' % (what, path, tree)
    return None


def scratch_dir(prefix):
    """A fresh folder in the system temp directory."""
    return tempfile.mkdtemp(prefix=prefix)


def blender_command(exe, script, args, blend=None):
    """Background, factory-startup command line; a Python exception exits with code 2."""
    cmd = [exe, '-b', '--factory-startup']
    if blend:
        cmd.append(str(blend))
    cmd += ['--python-exit-code', '2', '--python', str(script), '--'] + [str(a) for a in args]
    return cmd


def relaunch_in_blender(script, argv):
    """Run `script` with `argv` in background Blender, stream its output and return its exit code (2 = no Blender)."""
    try:
        exe_arg, config, rest = split_blender_args(argv)
        exe = find_blender(exe_arg, config)
    except ValueError as exc:
        print('SETUP ERROR: %s' % exc, file=sys.stderr)
        return 2
    if not exe:
        named = exe_arg or (config and 'tools.blender.path in ' + config) or os.environ.get('BLENDER')
        print('MISSING Blender%s: pass --blender-exe EXE or --local-config FILE, set BLENDER, or put blender on PATH'
              % (' (%s is not a file)' % named if named else ''), file=sys.stderr)
        return 2
    r = subprocess.run(blender_command(exe, script, rest))
    return r.returncode


if __name__ == '__main__':
    ap = argparse.ArgumentParser(prog='blender_env.py', description='Print the Blender executable the tools use.')
    add_blender_args(ap)
    a = ap.parse_args()
    try:
        exe = find_blender(a.blender_exe, a.local_config)
    except ValueError as exc:
        print('SETUP ERROR: %s' % exc, file=sys.stderr)
        sys.exit(2)
    print(exe or 'MISSING Blender')
    sys.exit(0 if exe else 1)
