#!/usr/bin/env python3
"""This device's local environment for Age of Pirates tooling: the ignored local files, their tracked examples, a check.

Device-specific paths live ONLY in ignored local files; tracked files hold examples and paths relative to the repo or
to a variable of config/aop.local.env ($AOP_KOREAN_REPO/research/...). The AoE3 profile is never configured: the repo
sits at <profile>/mods/local/age-of-pirates. Every agent sets its device up on a fresh clone, worktree or new device:

    python scripts/tools/local_env.py --init             # each missing local file from the main checkout (in a
                                                          # worktree) or from its example; never overwrites
    python scripts/tools/local_env.py                    # check: every local file and value, what is unset or broken
    python scripts/tools/local_env.py get AOP_KOREAN_REPO  # one value (exit 1 when unset)

Fill the values by finding the folders and programs on THIS device (never another device's paths, never a guess); the
comments in each example say what a value is and where it usually lives. What is not on this device stays empty.

    config/aop.local.env               <- config/aop.example.env             AoP folders (KEY=value)
    config/tool-paths.local.json       <- skill-library-audit assets/tool-paths.example.json   applications
    scripts/havok/converter.local.json <- scripts/havok/converter.example.json   GR2 converter backend
    config/skill-sync.local.json       <- config/skill-sync.example.json     public skill repository clones
    config/local-maps.local.json       <- config/local-maps.example.json     repo maps copied to the Steam RandMaps
    config/image-harness.local.env     <- config/image-harness.example.env   secrets: the owner fills it, never an agent

value(NAME): the real environment variable first, then config/aop.local.env. Exit 0 = nothing missing or broken
(unset values are listed, not errors); 1 = a local file is missing or a configured path does not exist.
"""
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ENV_LOCAL = 'config/aop.local.env'
ENV_EXAMPLE = 'config/aop.example.env'
# (local file, its example, who fills it): repo-relative, forward slashes
LOCAL_FILES = (
    (ENV_LOCAL, ENV_EXAMPLE, 'agent'),
    ('config/tool-paths.local.json', '.claude/skills/skill-library-audit/assets/tool-paths.example.json', 'agent'),
    ('scripts/havok/converter.local.json', 'scripts/havok/converter.example.json', 'agent'),
    ('config/skill-sync.local.json', 'config/skill-sync.example.json', 'agent'),
    ('config/local-maps.local.json', 'config/local-maps.example.json', 'agent'),
    ('config/image-harness.local.env', 'config/image-harness.example.env', 'owner'),
)


def _p(repo, rel):
    return os.path.join(repo, *rel.split('/'))


def read_env_file(path):
    """KEY=value lines of an env file ('#' comments, blank lines, optional quotes); {} when the file is absent"""
    vals = {}
    try:
        with open(path, encoding='utf-8-sig') as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#') and '=' in line:
                    k, v = line.split('=', 1)
                    vals[k.strip()] = v.strip().strip('"').strip("'")
    except OSError:
        pass
    return vals


def value(name, repo=REPO):
    """the real environment variable, else config/aop.local.env; None when neither sets it"""
    return os.environ.get(name) or read_env_file(_p(repo, ENV_LOCAL)).get(name) or None


def expand(text, repo=REPO):
    """'$NAME/rest' or '${NAME}/rest' with each NAME from value() -> (text, [names that are not set])"""
    missing = []

    def sub(m):
        name = m.group(1) or m.group(2)
        v = value(name, repo)
        if v is None:
            missing.append(name)
            return m.group(0)
        return v.rstrip('/\\')
    return re.sub(r'\$\{(\w+)\}|\$(\w+)', sub, text), missing


def claude_config_dir():
    return os.environ.get('CLAUDE_CONFIG_DIR') or os.path.join(os.path.expanduser('~'), '.claude')


def tasks_dir(repo=REPO):
    """the task engine folder (AOP_TASKS_DIR). Not set up on this device: <Claude config dir>/aop-tasks, which holds
    only this device's harness state (log, launch ledger, watch registry) - no tasks, no inbox."""
    return value('AOP_TASKS_DIR', repo) or os.path.join(claude_config_dir(), 'aop-tasks')


# ------------------------------------------------------------------------------------------ setup and check
def example_hints(path):
    """{KEY: the comment lines directly above it} of an example env file, in file order"""
    hints, block = {}, []
    try:
        lines = open(path, encoding='utf-8-sig').read().splitlines()
    except OSError:
        return hints
    for line in lines:
        s = line.strip()
        if s.startswith('#'):
            block.append(s.lstrip('#').strip())
        elif '=' in s:
            hints[s.split('=', 1)[0].strip()] = ' '.join(block)
            block = []
        else:
            block = []
    return hints


def main_checkout(repo=REPO):
    """the main working tree when `repo` is a linked git worktree, else None"""
    import subprocess
    try:
        out = subprocess.run(['git', '-C', repo, 'rev-parse', '--path-format=absolute', '--git-common-dir'],
                             capture_output=True, text=True, timeout=10).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        return None
    main = os.path.dirname(out) if out else None
    if not main or os.path.normcase(os.path.abspath(main)) == os.path.normcase(os.path.abspath(repo)):
        return None
    return main


def init(repo=REPO, out=print):
    """create each missing agent-filled local file: the main checkout's copy (worktree), else the example"""
    import shutil
    main = main_checkout(repo)
    for local, example, who in LOCAL_FILES:
        dst = _p(repo, local)
        if who != 'agent' or os.path.exists(dst):
            continue
        src = _p(main, local) if main and os.path.isfile(_p(main, local)) else _p(repo, example)
        if not os.path.isfile(src):
            out('cannot create %s: no %s' % (local, os.path.relpath(src, repo)))
            continue
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copyfile(src, dst)
        out('created %s from %s' % (local, example if src == _p(repo, example) else src))


def _row(rows, state, name, detail=''):
    rows.append((state, name, detail))


def wsl_distros():
    """the WSL distro names on this device (wsl.exe -l -q writes UTF-16); None when wsl.exe cannot be run"""
    import subprocess
    try:
        out = subprocess.run(['wsl.exe', '-l', '-q'], capture_output=True, timeout=30).stdout
    except (OSError, subprocess.SubprocessError):
        return None
    text = out.decode('utf-16-le', errors='replace') if b'\0' in out else out.decode('utf-8', errors='replace')
    return [ln.strip().strip('\0') for ln in text.splitlines() if ln.strip().strip('\0')]


# keys whose value is not a path: (check(value) -> None when ok, else the problem)
NON_PATH = {
    'AOP_GR2_DLL_ROUTE': lambda v: None if v.lower() in ('wsl', 'native', 'both') else 'not wsl, native or both',
    'AOP_WSL_DISTRO': lambda v: (None if (d := wsl_distros()) is not None and v in d else
                                 'not a WSL distro on this device (%s)' % ', '.join(d or ['wsl.exe unavailable'])),
}


def check(repo=REPO, out=print):
    """print every local file and value; returns the number of problems (missing local files, broken paths)"""
    import json
    problems = 0
    for local, example, who in LOCAL_FILES:
        path, rows = _p(repo, local), []
        if not os.path.isfile(path):
            if who == 'owner':
                out('%s: absent (the owner fills it from %s; agents never create it)' % (local, example))
            else:
                out('%s: MISSING (python scripts/tools/local_env.py --init, then fill it)' % local)
                problems += 1
            continue
        if local == ENV_LOCAL:
            have = read_env_file(path)
            hints = example_hints(_p(repo, example))
            for k in list(hints) + [k for k in have if k not in hints]:
                v = value(k, repo)
                src = ' (environment)' if os.environ.get(k) else ''
                if not v:
                    _row(rows, 'unset', k, hints.get(k, 'not in the example'))
                elif k in NON_PATH:
                    bad = NON_PATH[k](v)
                    _row(rows, 'BROKEN' if bad else 'ok', k, v + src + (' - ' + bad if bad else ''))
                elif os.path.exists(v):
                    _row(rows, 'ok', k, v + src)
                else:
                    _row(rows, 'BROKEN', k, '%s%s - not found' % (v, src))
        elif local.endswith('.json'):
            try:
                d = json.load(open(path, encoding='utf-8-sig'))
            except (OSError, ValueError) as e:
                out('%s: BROKEN (%s)' % (local, e))
                problems += 1
                continue
            if 'tools' in d:
                for k, t in d['tools'].items():
                    v = t.get('path') if isinstance(t, dict) else t
                    if not v:
                        _row(rows, 'unset', k)
                    else:
                        _row(rows, 'ok' if os.path.exists(v) else 'BROKEN', k, v + ('' if os.path.exists(v) else
                                                                                   ' - not found'))
            elif 'repositories' in d:
                for k, v in d['repositories'].items():
                    _row(rows, 'ok' if os.path.isdir(v) else 'BROKEN', k, v + ('' if os.path.isdir(v) else
                                                                              ' - not found'))
            elif 'backend' in d:
                b, exe = d.get('backend'), d.get('exe')
                if b in ('native', 'command') and exe:
                    _row(rows, 'ok' if os.path.isfile(exe) else 'BROKEN', 'backend ' + b,
                         exe + ('' if os.path.isfile(exe) else ' - not found'))
                else:
                    _row(rows, 'ok', 'backend ' + str(b), exe or '')
            else:
                _row(rows, 'ok', 'present')
        else:
            vals = read_env_file(path)
            ph = [k for k, v in vals.items() if not v or '<' in v]
            _row(rows, 'unset' if ph else 'ok', 'values', 'placeholder or empty: ' + ', '.join(ph) if ph else 'set')
        out(local)
        for state, name, detail in rows:
            problems += state == 'BROKEN'
            out('  %-7s %s%s' % (state, name, ('  ' + detail) if detail else ''))
    gxo = _p(repo, '.claude/skills/gxo-convert')
    out('gxo-convert skill (gitignored): %s' % (os.path.realpath(gxo) if os.path.isdir(gxo) else
        'absent - the owner\'s devices link it: New-Item -ItemType Junction -Path .claude\\skills\\gxo-convert '
        '-Target "$env:OneDrive\\DE Converter\\claude-skills\\gxo-convert"'))
    out('tasks dir (harness state): %s' % tasks_dir(repo))
    return problems


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    if argv[:1] == ['get'] and len(argv) == 2:
        v = value(argv[1])
        if v:
            print(v)
        return 0 if v else 1
    if argv and argv != ['--init']:
        print(__doc__)
        return 2
    if argv == ['--init']:
        init()
    problems = check()
    print('%d problem(s)' % problems if problems else 'local environment: nothing missing or broken')
    return 1 if problems else 0


if __name__ == '__main__':
    sys.exit(main())
