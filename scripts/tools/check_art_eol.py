"""Line-ending audit for every file the game reads from the mod folder: *.xml / *.material / *.lgt / *.tactics / *.xs /
*.set / *.xaml under art/, sound/, data/, game/ and randmaps/ must be CRLF. An LF-only art XML is silently ignored by
the game - the unit places, the decal draws, the model never renders (Tower of London, 2026-09-17: ten restarts before
this was found). LF map scripts and map-info XML do load (vanilla ships 199 LF/mixed .xs), but one rule for every game
file keeps copies byte-comparable. Compare copies by content, not bytes:
    git hash-object --path=<repo path> <copy>   ==  git rev-parse HEAD:<repo path>   (any line endings)

    python scripts/tools/check_art_eol.py            # report (exit 1 if any offender)
    python scripts/tools/check_art_eol.py --fix      # convert offenders to CRLF in place (bytes only, text unchanged)
    python scripts/tools/check_art_eol.py PATH...    # restrict to files/folders
"""
import os, sys

EXT = ('.xml', '.material', '.lgt', '.tactics', '.xs', '.set', '.xaml')
ROOTS = ('art', 'sound', 'data', 'game', 'randmaps')


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
