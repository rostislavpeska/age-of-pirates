#!/usr/bin/env python
"""Keep string tables in ascending _locid order.

    python scripts/tools/stringcheck.py                 # audit every string file
    python scripts/tools/stringcheck.py --where 303356  # WHERE does this id go?
    python scripts/tools/stringcheck.py --fix           # sort contiguous runs

Why this exists: strings were once appended just before </language>, which put
303350-303355 after 400290. The engine did not care - it keys on _locid - but a
human reading the file could no longer find anything, and the next author
appended to the wrong place again. Anchor a new string on the id that
NUMERICALLY PRECEDES it, never on a structural tag like </language>.

--fix only reorders runs that are already contiguous string lines, so comments
and blank-line section markers are never moved across.
"""
import argparse
import glob
import re
import sys

DEFAULT_GLOBS = ['data/strings/*/*.xml', 'data/strings/*.xml']
LOCID = re.compile(r'_locid="(\d+)"')


def read(path):
    raw = open(path, 'rb').read()
    crlf = raw.count(b'\r\n')
    lf = raw.count(b'\n') - crlf
    return raw.decode('utf-8'), ('\r\n' if crlf and not lf else '\n'), crlf, lf


def entries(lines):
    """[(index, locid)] for every LIVE line carrying a _locid.

    Commented-out strings are skipped: the repo keeps old copies parked in
    <!-- --> next to their replacement, which is not a duplicate.
    """
    out = []
    for i, l in enumerate(lines):
        m = LOCID.search(l)
        if not m:
            continue
        s = l.strip()
        if s.startswith('<!--') or (s.startswith('<!') and s.endswith('-->')):
            continue
        out.append((i, int(m.group(1))))
    return out


def inversions(ids):
    return [(b[0], b[1], a[1]) for a, b in zip(ids, ids[1:]) if b[1] < a[1]]


def files(patterns):
    out = []
    for g in patterns:
        out.extend(sorted(glob.glob(g)))
    return out


def cmd_where(paths, target):
    for p in paths:
        text, _, _, _ = read(p)
        lines = text.split('\n')
        ids = entries(lines)
        if not ids:
            continue
        if any(v == target for _, v in ids):
            ln = next(i for i, v in ids if v == target)
            print('  %s: %d ALREADY EXISTS at line %d' % (p, target, ln + 1))
            continue
        before = [(i, v) for i, v in ids if v < target]
        if not before:
            print('  %s: insert BEFORE line %d (id %d) - lowest in file'
                  % (p, ids[0][0] + 1, ids[0][1]))
            continue
        i, v = before[-1]
        print('  %s: insert AFTER line %d  (id %d)' % (p, i + 1, v))
        print('        %s' % lines[i].strip()[:100])
    return 0


def cmd_check(paths, fix):
    bad_total = 0
    for p in paths:
        text, eol, crlf, lf = read(p)
        lines = text.split('\n')
        ids = entries(lines)
        if not ids:
            continue
        inv = inversions(ids)
        dupes = sorted({v for _, v in ids if [x for _, x in ids].count(v) > 1})
        tag = 'MIXED' if (crlf and lf) else ('CRLF' if crlf else 'LF')
        print('  %-46s %5d strings  %s' % (p, len(ids), tag))
        for ln, v, pv in inv:
            print('     OUT OF ORDER  line %d: %d follows %d' % (ln + 1, v, pv))
        for v in dupes:
            print('     DUPLICATE     _locid %d' % v)
        bad_total += len(inv) + len(dupes)

        if fix and inv:
            # sort only maximal runs of consecutive string-bearing lines
            runs, run = [], [ids[0]]
            for cur in ids[1:]:
                if cur[0] == run[-1][0] + 1:
                    run.append(cur)
                else:
                    runs.append(run)
                    run = [cur]
            runs.append(run)
            changed = 0
            for r in runs:
                if len(r) < 2:
                    continue
                a, b = r[0][0], r[-1][0]
                seg = lines[a:b + 1]
                srt = sorted(seg, key=lambda l: int(LOCID.search(l).group(1)))
                if srt != seg:
                    lines[a:b + 1] = srt
                    changed += 1
            if changed:
                open(p, 'wb').write(eol.join(
                    '\n'.join(lines).split('\n')).encode('utf-8'))
                print('     FIXED %d contiguous run(s), endings preserved (%s)'
                      % (changed, tag))
                left = inversions(entries(open(p, encoding='utf-8').read().split('\n')))
                if left:
                    print('     %d inversion(s) REMAIN - they straddle a comment or '
                          'blank line, move those by hand' % len(left))
    return 1 if (bad_total and not fix) else 0


def main():
    ap = argparse.ArgumentParser(add_help=True, description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--where', type=int, metavar='LOCID',
                    help='report the line a new string with this id belongs after')
    ap.add_argument('--fix', action='store_true', help='sort contiguous runs in place')
    ap.add_argument('paths', nargs='*', help='files to check (default: data/strings)')
    a = ap.parse_args()
    paths = a.paths or files(DEFAULT_GLOBS)
    if not paths:
        print('no string files found')
        return 2
    if a.where is not None:
        return cmd_where(paths, a.where)
    return cmd_check(paths, a.fix)


if __name__ == '__main__':
    sys.exit(main())
