#!/usr/bin/env python
"""Host-side entry point: convert .gr2 inputs to FBX through the GR2 converter under Wine in WSL (never the exe on
the Windows host - Smart App Control blocks it), then run skin_check.py in background Blender.

    python run_skin_check.py MODEL.gr2|.fbx [--baseline VANILLA.gr2|.fbx] --out DIR [--expect-dropped MESH ...]
                             [--max-influences 4]

Copies each .gr2 into DIR/work first (the converter writes next to its input). DIR belongs in the session
scratchpad, never in the repo. Device paths come from the environment or the gitignored local config:
  BLENDER            Blender executable, else config/tool-paths.local.json tools.blender.path
  GXO_CONVERTER_DIR  the converter folder (with wine/gxo_wine.sh), else %OneDrive%/DE Converter
  GXO_WSL_DISTRO     WSL distro running Wine, else an exact 'Ubuntu', else the first registered 'Ubuntu*'
Exit code: skin_check's (1 on FAIL), 2 when a tool is missing.
"""
import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[3]                   # .claude/skills/<skill>/scripts -> repo root


def blender_exe():
    if os.environ.get('BLENDER'):
        return os.environ['BLENDER']
    cfg = REPO / 'config' / 'tool-paths.local.json'
    if cfg.is_file():
        path = json.loads(cfg.read_text(encoding='utf-8')).get('tools', {}).get('blender', {}).get('path')
        if path:
            return path
    return shutil.which('blender')


def wsl_distros():
    out = subprocess.run(['wsl.exe', '-l', '-q'], capture_output=True).stdout
    text = out.decode('utf-16-le', 'replace') if b'\x00' in out else out.decode('utf-8', 'replace')
    return [d.strip() for d in text.replace('\x00', '').splitlines() if d.strip()]


def pick_distro(registered, wanted=None):
    """The env choice, else an exact 'Ubuntu', else the first 'Ubuntu*' (e.g. 'Ubuntu-24.04')."""
    if wanted:
        return wanted if wanted in registered else None
    if 'Ubuntu' in registered:
        return 'Ubuntu'
    return next((d for d in registered if d.lower().startswith('ubuntu')), None)


def to_fbx(gr2, work):
    conv = Path(os.environ.get('GXO_CONVERTER_DIR') or Path(os.environ.get('OneDrive', Path.home())) / 'DE Converter')
    script = conv / 'wine' / 'gxo_wine.sh'
    distro = pick_distro(wsl_distros(), os.environ.get('GXO_WSL_DISTRO'))
    if not script.is_file() or not distro:
        print('MISSING converter: %s, WSL distro: %s' % (script if not script.is_file() else 'ok', distro))
        sys.exit(2)
    work.mkdir(parents=True, exist_ok=True)
    src = work / gr2.name
    shutil.copy2(gr2, src)
    lin = subprocess.run(['wsl.exe', '-d', distro, '--exec', 'wslpath', '-u', str(script).replace('\\', '/')],
                         capture_output=True, text=True).stdout.strip()
    r = subprocess.run(['wsl.exe', '-d', distro, '--exec', 'bash', lin, 'fbx', str(src).replace('\\', '/')],
                       capture_output=True)
    text = (r.stdout + r.stderr).decode('utf-8', 'replace').replace('\x00', '')
    ok = [l for l in text.splitlines() if l.startswith('OK')]
    fbx = src.with_suffix('.fbx')
    if not ok or not fbx.is_file():
        print('CONVERSION FAILED for %s (distro %s):\n%s' % (gr2, distro, text[-1500:]))
        sys.exit(2)
    print(ok[0])
    return fbx


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('model')
    ap.add_argument('--baseline')
    ap.add_argument('--out', required=True)
    ap.add_argument('--expect-dropped', nargs='*', default=[])
    ap.add_argument('--max-influences', type=int, default=4)
    a = ap.parse_args()
    out = Path(a.out).resolve()
    if REPO in out.parents or out == REPO:
        sys.exit('--out must be outside the repository (session scratchpad)')
    work = out / 'work'
    model = Path(a.model).resolve()
    model = to_fbx(model, work / 'model') if model.suffix.lower() == '.gr2' else model
    base = None
    if a.baseline:
        base = Path(a.baseline).resolve()
        base = to_fbx(base, work / 'baseline') if base.suffix.lower() == '.gr2' else base
    exe = blender_exe()
    if not exe or not Path(exe).is_file():
        print('MISSING Blender (set BLENDER or tools.blender.path in config/tool-paths.local.json)')
        sys.exit(2)
    cmd = [exe, '-b', '--factory-startup', '--python', str(HERE / 'skin_check.py'), '--',
           '--model', str(model), '--out', str(out), '--max-influences', str(a.max_influences)]
    if base:
        cmd += ['--baseline', str(base)]
    if a.expect_dropped:
        cmd += ['--expect-dropped'] + a.expect_dropped
    r = subprocess.run(cmd, capture_output=True, text=True, errors='replace')
    keep = ('DIFF', 'WARN', 'FAIL', '   ', 'report', 'Traceback', 'Error')
    for line in r.stdout.splitlines() + r.stderr.splitlines():
        if line.startswith(keep) or ' MESH ' in line or ' ARMATURE ' in line:
            print(line)
    sys.exit(r.returncode)


if __name__ == '__main__':
    main()
