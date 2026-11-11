"""A temporary passive AI for captures (owner 2026-10-07: "on purpose break the AI to stay passive - reversible
temporary"). apply: a block at the start of the rule initializePirateRules in both mod AI files (core and coreDLC;
the game picks one by DLC ownership) sets every control flag false - nothing is explored, gathered, built, trained or
attacked. revert: git checkout of both files, then a check that they equal HEAD. Never commit while applied: the
AI isolation tests (scripts/aitest/tests) fail on it by design.
usage: passive_ai.py apply | revert | status"""
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[4]
FILES = ['game/ai/core/aipiraterules.xs', 'game/ai/coreDLC/aipiraterules.xs']
HEAD = 'rule initializePirateRules\nactive\nminInterval 1\n{\n'
MARK = '// TEMPORARY - passive AI for a capture'
BLOCK = ('   ' + MARK + ' (scripts: passive_ai.py). Reverted by git checkout right after.\n'
         '   cvOkToBuild = false; cvOkToTrainArmy = false; cvOkToTrainNavy = false; cvOkToAttack = false;\n'
         '   cvOkToExplore = false; cvOkToGatherFood = false; cvOkToGatherGold = false; cvOkToGatherWood = false;\n'
         '   cvOkToBuildForts = false; cvOkToFortify = false; cvOkToAllyNatives = false; cvOkToClaimTrade = false;\n'
         '   cvOkToFish = false; cvOkToGatherNuggets = false; cvOkToResign = false; cvOkToTaunt = false;\n'
         '   cvOkToBuildConsulate = false;\n')


def git(*a):
    return subprocess.run(['git', *a], cwd=REPO, capture_output=True, text=True, check=True).stdout


def status():
    dirty = git('status', '--short', '--', *FILES).strip()
    applied = [f for f in FILES if MARK in (REPO / f).read_text(encoding='utf-8', errors='replace')]
    return dirty, applied


cmd = sys.argv[1] if len(sys.argv) > 1 else 'status'
if cmd == 'apply':
    dirty, applied = status()
    if dirty:
        sys.exit(f'refused: the AI files have other changes:\n{dirty}')
    for rel in FILES:
        p = REPO / rel
        raw = p.read_bytes().decode('utf-8')
        crlf = '\r\n' in raw
        t = raw.replace('\r\n', '\n')
        if t.count(HEAD) != 1:
            sys.exit(f'refused: {rel} has {t.count(HEAD)} initializePirateRules heads')
        t = t.replace(HEAD, HEAD + BLOCK)
        p.write_bytes((t.replace('\n', '\r\n') if crlf else t).encode('utf-8'))
    print('passive AI applied to', ', '.join(FILES))
elif cmd == 'revert':
    git('checkout', '--', *FILES)
    dirty, applied = status()
    print('reverted; AI files equal HEAD:', not dirty and not applied)
    sys.exit(0 if not dirty and not applied else 1)
else:
    dirty, applied = status()
    print('applied in:', applied or 'none', '| other changes:', dirty or 'none')
