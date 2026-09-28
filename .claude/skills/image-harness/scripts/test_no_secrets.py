"""The repo is public: the image harness URL and key must never reach git.

python -m pytest .claude/skills/image-harness/scripts/test_no_secrets.py -q
Checks that config/image-harness.local.env is ignored and untracked, and that none of its values (URL, webhook
path, key) occur in any tracked, staged or new-but-unignored file. Failures name files only - never a value.
"""
import os
import subprocess
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[3]
LOCAL = 'config/image-harness.local.env'


def _git(*args):
    return subprocess.run(['git', '-C', str(REPO), *args], capture_output=True, text=True,
                          encoding='utf-8', errors='replace')


def _secret_values():
    vals = {}
    p = REPO / LOCAL
    if p.exists():
        for line in p.read_text(encoding='utf-8').splitlines():
            line = line.strip()
            if line and not line.startswith('#') and '=' in line:
                k, v = line.split('=', 1)
                vals[k.strip()] = v.strip().strip('"').strip("'")
    for k in ('IMAGE_HARNESS_URL', 'IMAGE_HARNESS_KEY'):
        if os.environ.get(k):
            vals[k] = os.environ[k]
    out = {}
    if vals.get('IMAGE_HARNESS_KEY'):
        out['key'] = vals['IMAGE_HARNESS_KEY']
    url = vals.get('IMAGE_HARNESS_URL', '')
    if url:
        out['url'] = url
        path = url.split('://', 1)[-1].split('/', 1)[-1]
        if len(path) >= 8:
            out['webhook path'] = path
    return {k: v for k, v in out.items() if v and '<' not in v}


def test_local_env_is_ignored_and_untracked():
    assert _git('check-ignore', '-q', LOCAL).returncode == 0, f'{LOCAL} is not gitignored'
    assert _git('ls-files', '--error-unmatch', LOCAL).returncode != 0, f'{LOCAL} is tracked - remove it from the index'


def test_secret_values_are_in_no_tracked_staged_or_new_file():
    leaks = {}
    for label, value in _secret_values().items():
        files = set()
        for mode in (('--untracked',), ('--cached',)):       # working tree incl. new unignored files; the index
            r = _git('grep', '-F', '-l', *mode, '-e', value)
            files.update(l for l in r.stdout.splitlines() if l.strip() and l.strip() != LOCAL)
        if files:
            leaks[label] = sorted(files)
    assert not leaks, f'harness secret found in git-visible files (values not shown): {leaks}'
