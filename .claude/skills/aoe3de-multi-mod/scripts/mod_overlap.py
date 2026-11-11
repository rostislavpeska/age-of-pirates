#!/usr/bin/env python
"""Which files of several Age of Empires III DE mods shadow each other.

The game resolves a path shipped by two enabled mods by mod priority: the lower `Priority` in
<profile>/mods/age3-mod-status.json wins. The additive data files (`*mods.xml` and their `.xmb` twins) are merged
across mods instead. This lists, for every pair of the chosen mods, the shared replacing paths and the winner.

    python mod_overlap.py --profile "<...>/<steam id>/mods"                  # every enabled mod
    python mod_overlap.py --profile ... --mods age-of-pirates age-of-pirates-koreans --fail
    python mod_overlap.py --profile ... --fail --allow sound/fortwagon_snds.xml   # a known, recorded case

Exit 1 with --fail when a replacing path is shared and not allowed. Read-only; standard library only.
"""
import argparse
import json
import os
import sys

GAME_DIRS = {'art', 'data', 'game', 'sound', 'randmaps', 'render', 'ui', 'cinematics', 'movies', 'scenario', 'terrain'}


def additive(rel):
    """True for the data files the engine merges across mods (`protomods.xml`, `techtreemods.xml` ...)."""
    name = rel.lower()
    if name.endswith('.xmb'):
        name = name[:-4]
    return name.endswith('mods.xml')


def game_files(base):
    out = {}
    for top in os.listdir(base):
        if top.lower() not in GAME_DIRS or not os.path.isdir(os.path.join(base, top)):
            continue
        for dp, _, fn in os.walk(os.path.join(base, top)):
            for f in fn:
                rel = os.path.relpath(os.path.join(dp, f), base).replace(os.sep, '/')
                out[rel.lower()] = rel          # Windows paths: compare case-insensitively
    return out


def load_mods(profile, titles=None):
    status = json.load(open(os.path.join(profile, 'age3-mod-status.json'), encoding='utf-8-sig'))
    mods = [m for m in status['Mods'] if (m['Title'] in titles if titles else m.get('Enabled'))]
    if titles:
        missing = set(titles) - {m['Title'] for m in mods}
        if missing:
            raise SystemExit('not in age3-mod-status.json: %s' % sorted(missing))
    return sorted(mods, key=lambda m: m['Priority'])


def overlaps(profile, mods):
    files = {m['Title']: game_files(os.path.join(profile, m['Path'])) for m in mods}
    rows = []
    for i, a in enumerate(mods):
        for b in mods[i + 1:]:
            fa, fb = files[a['Title']], files[b['Title']]
            for key in sorted(set(fa) & set(fb)):
                rows.append({'path': fa[key], 'winner': a['Title'], 'loser': b['Title'],
                             'priorities': [a['Priority'], b['Priority']], 'additive': additive(key)})
    return rows


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--profile', required=True, help='the <steam id>/mods folder holding age3-mod-status.json')
    ap.add_argument('--mods', nargs='*', help='mod titles (default: every enabled mod)')
    ap.add_argument('--fail', action='store_true', help='exit 1 on a shared replacing path')
    ap.add_argument('--allow', nargs='*', default=[], help='replacing paths already recorded as known')
    ap.add_argument('--json', action='store_true')
    a = ap.parse_args(argv)
    mods = load_mods(a.profile, a.mods)
    rows = overlaps(a.profile, mods)
    allow = {p.lower() for p in a.allow}
    bad = [r for r in rows if not r['additive'] and r['path'].lower() not in allow]
    if a.json:
        print(json.dumps({'mods': [(m['Priority'], m['Title']) for m in mods], 'shared': rows, 'shadowed': bad}, indent=1))
    else:
        print('mods by priority (lower wins):', ', '.join('%s=%s' % (m['Priority'], m['Title']) for m in mods))
        for r in rows:
            kind = 'merged ' if r['additive'] else ('known  ' if r['path'].lower() in allow else 'SHADOW ')
            if not r['additive']:
                print('%s %-60s %s wins over %s' % (kind, r['path'], r['winner'], r['loser']))
        print('%d shared paths: %d merged (*mods.xml), %d replacing (%d not allowed)'
              % (len(rows), sum(r['additive'] for r in rows), sum(not r['additive'] for r in rows), len(bad)))
    return 1 if a.fail and bad else 0


if __name__ == '__main__':
    sys.exit(main())
