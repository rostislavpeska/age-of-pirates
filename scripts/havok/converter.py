"""Run GXOConverterAge3DE.exe under Wine (WSL Ubuntu) with ARBITRARY options - the same code path as the gxo-convert
skill's launchers (which only know --format=). Never launches the exe on the host (Smart App Control blocks it and
caches the verdict). Output lands next to the input; the file is passed by its Windows path.

    python converter.py --format gr2 --bang model.gxo            # gxo -> gr2 in the engine's mesh format (skinned meshes)
    python converter.py --modify-gr2 calculatetangents model.gr2 # add tangents in place (GXO-built gr2s have none)
    python converter.py --format gxo model.gr2                    # dump (bones absolute, meshes, k lines) - also a LOADER TEST:
                                                                  #   a crash here (granny2_age3de+...) means the game would crash too
Options are passed through verbatim after the file(s); exit code 5 = the converter crashed (Wine backtrace in the log).
"""
import argparse, subprocess, sys, os, shlex

DISTRO = 'Ubuntu'


def winpath_to_wsl(p):
    p = os.path.abspath(p).replace('\\', '/')
    return '/mnt/' + p[0].lower() + p[2:]


def main():
    ap = argparse.ArgumentParser(); ap.add_argument('--format', choices=['gr2', 'gxo', 'fbx'])
    ap.add_argument('--bang', action='store_true'); ap.add_argument('--modify-gr2', metavar='OPS', help='e.g. calculatetangents, optimizemeshes, removeboneweights, decompressanimations')
    ap.add_argument('files', nargs='+'); a = ap.parse_args()
    opts = []
    if a.format: opts.append('--format=' + a.format)
    if a.bang: opts.append('--bang')
    if a.modify_gr2: opts.append('--modify-gr2=' + a.modify_gr2)
    rc_all = 0
    for f in a.files:
        d = winpath_to_wsl(os.path.dirname(f)); name = os.path.basename(f)
        cmd = ("export WINEARCH=win32 WINEPREFIX=$HOME/.wine_gxo WINEDEBUG=-all; cd %s && timeout 900 wine $HOME/gxo/GXOConverterAge3DE.exe %s %s >/tmp/conv_$$.log 2>&1; rc=$?; "
               "grep -v '^fixme' /tmp/conv_$$.log | grep -E 'Backtrace|Unhandled|granny2_age3de\\+' | head -3; wineserver -k 2>/dev/null; exit $rc") % (shlex.quote(d), ' '.join(shlex.quote(o) for o in opts), shlex.quote(name))
        r = subprocess.run(['wsl.exe', '-d', DISTRO, '--exec', 'bash', '-c', cmd], capture_output=True, text=True)
        out = os.path.join(os.path.dirname(f), os.path.splitext(name)[0] + '.' + a.format) if a.format else f
        ok = r.returncode == 0 and os.path.exists(out)
        print(('OK   ' if ok else f'FAILED (rc {r.returncode}) ') + f'{name} {" ".join(opts)}' + (f' -> {os.path.basename(out)} ({os.path.getsize(out)} bytes)' if ok else ''))
        if r.stdout.strip(): print('     ' + r.stdout.strip().replace('\n', '\n     '))
        rc_all |= 0 if ok else 1
    sys.exit(rc_all)


if __name__ == '__main__':
    main()
