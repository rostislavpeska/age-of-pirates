"""Line-ending audit for the XML the engine reads at runtime: every *.xml / *.material / *.lgt / *.tactics under
art/ and sound/ (and data/ for consistency) must be CRLF. An LF-only art XML is silently ignored by the game - the unit
places, the decal draws, the model never renders (Tower of London, 2026-09-17: ten restarts before this was found).

    python scripts/tools/check_art_eol.py            # report (exit 1 if any offender)
    python scripts/tools/check_art_eol.py --fix      # convert offenders to CRLF in place (bytes only, text unchanged)
    python scripts/tools/check_art_eol.py PATH...    # restrict to files/folders
"""
import os, sys

EXT = ('.xml', '.material', '.lgt', '.tactics', '.xs')
ROOTS = ('art', 'sound', 'data')


def files(paths):
    for p in paths:
        if os.path.isfile(p): yield p
        else:
            for d, _, fs in os.walk(p):
                for f in fs:
                    if f.lower().endswith(EXT): yield os.path.join(d, f)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]; fix = '--fix' in sys.argv
    bad = []
    for f in files(args or [r for r in ROOTS if os.path.isdir(r)]):
        b = open(f, 'rb').read()
        if b'\n' not in b: continue
        lone_lf = b.count(b'\n') - b.count(b'\r\n')
        if lone_lf:
            bad.append((f, lone_lf))
            if fix: open(f, 'wb').write(b.replace(b'\r\n', b'\n').replace(b'\n', b'\r\n'))
    for f, n in bad: print(('FIXED ' if fix else 'LF    ') + f'{f}  ({n} LF-only line(s))')
    print(f'{len(bad)} file(s) with LF-only lines' + (' - converted' if fix and bad else ''))
    return 1 if bad and not fix else 0


if __name__ == '__main__':
    sys.exit(main())
