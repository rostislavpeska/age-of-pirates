"""GR2 <-> GXO/FBX conversion behind ONE tracked entry point, with the machine-specific part in a gitignored config.

The pipeline needs four things from "a converter" (GXOConverterAge3DE.exe by Kevsoft, or anything equivalent):
    gr2 -> gxo     text dump: bones (absolute transforms), meshes, anim keys  - also the LOADER TEST (uses the game's granny2 DLL)
    gr2 -> fbx     geometry for Blender
    gxo/fbx -> gr2 animations (and label tables); --bang = engine mesh format, --modify-gr2=calculatetangents
The output always lands next to the input with the target extension.

Backend = scripts/havok/converter.local.json (gitignored; copy converter.example.json) or the env var AOE3_CONVERTER
(same JSON). Backends:
    wine-wsl  : the exe under Wine inside a WSL distro (this PC: Smart App Control blocks the exe on the host;
                setup guide = the gitignored .claude/skills/gxo-convert skill / OneDrive "DE Converter")
    native    : run the exe directly (a PC where it is allowed to run)
    command   : any shell template with {exe} {opts} {file} {dir} placeholders (other tool, wrapper, remote)
    manual    : print what to convert and wait for the output file (GUI drag-and-drop, 3ds Max / Blender plugin, web tool)

    python scripts/havok/converter.py --format gxo model.gr2
    python scripts/havok/converter.py --format gr2 --bang model.gxo
    python scripts/havok/converter.py --modify-gr2 calculatetangents model.gr2
    python scripts/havok/converter.py --check                      # which backend, does it answer
Exit code 0 = every output exists; a Wine/Granny backtrace is printed when the exe crashed (= the game would crash too).
"""
import argparse, json, os, shlex, subprocess, sys, time

HERE = os.path.dirname(os.path.abspath(__file__))
LOCAL = os.path.join(HERE, 'converter.local.json')
EXAMPLE = os.path.join(HERE, 'converter.example.json')


def load_config():
    if os.environ.get('AOE3_CONVERTER'):
        return json.loads(os.environ['AOE3_CONVERTER'])
    if os.path.exists(LOCAL):
        return json.load(open(LOCAL, encoding='utf-8'))
    return {'backend': 'manual'}


def wsl_path(p):
    p = os.path.abspath(p).replace('\\', '/')
    return '/mnt/' + p[0].lower() + p[2:]


def run_wine_wsl(cfg, opts, f):
    d = wsl_path(os.path.dirname(f)); name = os.path.basename(f)
    distro = cfg.get('distro', 'Ubuntu'); prefix = cfg.get('wineprefix', '$HOME/.wine_gxo'); exe = cfg.get('exe', '$HOME/gxo/GXOConverterAge3DE.exe')
    cmd = ("export WINEARCH=win32 WINEPREFIX=%s WINEDEBUG=-all; cd %s && timeout %d wine %s %s %s >/tmp/conv_$$.log 2>&1; rc=$?; "
           "grep -v '^fixme' /tmp/conv_$$.log | grep -E 'Backtrace|Unhandled|granny2_age3de\\+' | head -3; wineserver -k 2>/dev/null; exit $rc"
           % (prefix, shlex.quote(d), int(cfg.get('timeout', 900)), exe, ' '.join(shlex.quote(o) for o in opts), shlex.quote(name)))
    r = subprocess.run(['wsl.exe', '-d', distro, '--exec', 'bash', '-c', cmd], capture_output=True, text=True)
    return r.returncode, r.stdout


def run_native(cfg, opts, f):
    r = subprocess.run([cfg['exe']] + opts + [os.path.basename(f)], cwd=os.path.dirname(f), capture_output=True, text=True, timeout=cfg.get('timeout', 900))
    return r.returncode, r.stdout + r.stderr


def run_command(cfg, opts, f):
    cmd = cfg['command'].format(exe=cfg.get('exe', ''), opts=' '.join(opts), file=f, dir=os.path.dirname(f), name=os.path.basename(f))
    r = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=cfg.get('timeout', 900))
    return r.returncode, r.stdout + r.stderr


def run_manual(cfg, opts, f, out):
    print(f'MANUAL converter step needed:\n   input : {f}\n   options: {" ".join(opts) or "(none)"}\n   expected output: {out}\n'
          '   Convert it with your tool (GUI / 3ds Max or Blender plugin / web converter) and leave the result at that path;\n'
          f'   waiting up to {cfg.get("timeout", 1800)} s ...')
    t0 = time.time()
    while time.time() - t0 < cfg.get('timeout', 1800):
        if os.path.exists(out) and os.path.getsize(out) > 0 and time.time() - os.path.getmtime(out) > 2: return 0, ''
        time.sleep(3)
    return 1, 'timed out waiting for the output file'


BACKENDS = {'wine-wsl': run_wine_wsl, 'native': run_native, 'command': run_command}


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--format', choices=['gr2', 'gxo', 'fbx']); ap.add_argument('--bang', action='store_true')
    ap.add_argument('--modify-gr2', metavar='OPS'); ap.add_argument('--check', action='store_true'); ap.add_argument('files', nargs='*')
    a = ap.parse_args(); cfg = load_config(); backend = cfg.get('backend', 'manual')
    if a.check:
        print('backend:', backend, '| config:', 'env AOE3_CONVERTER' if os.environ.get('AOE3_CONVERTER') else (LOCAL if os.path.exists(LOCAL) else f'none (copy {os.path.basename(EXAMPLE)} to converter.local.json)'))
        if backend == 'wine-wsl':
            r = subprocess.run(['wsl.exe', '-d', cfg.get('distro', 'Ubuntu'), '--exec', 'bash', '-c', 'command -v wine >/dev/null && test -f ' + cfg.get('exe', '$HOME/gxo/GXOConverterAge3DE.exe') + ' && echo ok'], capture_output=True, text=True)
            print('wine + exe in the distro:', 'ok' if 'ok' in r.stdout else 'MISSING - see the gxo-convert setup guide')
        elif backend == 'native': print('exe exists:', os.path.exists(cfg.get('exe', '')))
        return 0
    if not a.files: ap.error('no files')
    opts = []
    if a.format: opts.append('--format=' + a.format)
    if a.bang: opts.append('--bang')
    if a.modify_gr2: opts.append('--modify-gr2=' + a.modify_gr2)
    rc_all = 0
    for f in a.files:
        f = os.path.abspath(f)
        out = os.path.join(os.path.dirname(f), os.path.splitext(os.path.basename(f))[0] + '.' + a.format) if a.format else f
        if a.format and os.path.splitext(f)[1].lower() == '.' + a.format:
            print(f'SKIPPED {os.path.basename(f)}: already a .{a.format} (converting a file onto its own format overwrites it)'); rc_all = 1; continue
        if backend == 'manual': rc, msg = run_manual(cfg, opts, f, out)
        else: rc, msg = BACKENDS[backend](cfg, opts, f)
        ok = rc == 0 and os.path.exists(out) and os.path.getsize(out) > 0
        print(('OK   ' if ok else f'FAILED (rc {rc}) ') + f'{os.path.basename(f)} {" ".join(opts)}' + (f' -> {os.path.basename(out)} ({os.path.getsize(out)} bytes)' if ok else ''))
        if msg.strip(): print('     ' + msg.strip().replace('\n', '\n     '))
        rc_all |= 0 if ok else 1
    return rc_all


if __name__ == '__main__':
    sys.exit(main())
