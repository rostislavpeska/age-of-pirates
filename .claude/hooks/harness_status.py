#!/usr/bin/env python3
"""Is the agent harness (AGENTS.md rule 13) live? Read-only status, plus the merged settings file the owner applies.

    python .claude/hooks/harness_status.py                      # registered? scripts present? gate off? live proof?
    python .claude/hooks/harness_status.py --json
    python .claude/hooks/harness_status.py --write-proposed OUT  # .claude/settings.json + the missing entries of
                                                                 # settings_entries.json (existing hooks kept as they are)

Agents never write .claude/settings.json (the permission classifier refuses it as self-modification, 2026-09-29):
the owner copies the proposed file. "Live proof" is read from tasks/harness_log.jsonl, written by the hooks themselves:
  gate   a launch_gate record from a real hook call (it carries a session_id)
  inbox  an inbox_delivered or inbox_stop_blocked record whose key is a workflow run id (wf_...) and whose hook input
         carried agent_id: real workflow-subagent hook input has the fields the binding relies on.
Until both exist the rules are advisory for Claude too. The one live check after the owner applied the settings (new
session): bind a small workflow run (tasks.py bind-run <TASK> <wf_id>), add a note (tasks.py note <TASK> "..."), then
run this script. Env: AOP_HARNESS_LOG, AOP_TASKS_DIR.
"""
import json
import os
import sys
from pathlib import Path

HOOK_DIR = Path(__file__).resolve().parent
REPO = HOOK_DIR.parent.parent
ENTRIES = HOOK_DIR / 'settings_entries.json'
_TASKS = ('Documents', 'WORKSPACE', 'korean-buildings-blender', 'research', 'Texturing_11', 'Claude_CP2', 'tasks')


def tasks_dir():
    return Path(os.environ.get('AOP_TASKS_DIR') or Path.home().joinpath(*_TASKS))


def log_path():
    return Path(os.environ.get('AOP_HARNESS_LOG') or (tasks_dir() / 'harness_log.jsonl'))


def _commands(block):
    return {h.get('command') for g in block or [] for h in g.get('hooks', []) if isinstance(h, dict)}


def registration(settings, entries):
    """{event: True/False} - every entry command of the event is present in settings (any group)"""
    have = (settings or {}).get('hooks', {})
    return {ev: _commands(groups) <= _commands(have.get(ev)) for ev, groups in entries['hooks'].items()}


def merged(settings, entries):
    """settings with the missing entry groups appended; existing groups untouched, nothing duplicated"""
    out = json.loads(json.dumps(settings or {}))
    hooks = out.setdefault('hooks', {})
    for ev, groups in entries['hooks'].items():
        cur = hooks.setdefault(ev, [])
        have = _commands(cur)
        for g in groups:
            if not _commands([g]) <= have:
                cur.append(g)
    return out


def live_proof(log):
    gate = inbox = None
    try:
        lines = log.read_text(encoding='utf-8', errors='replace').splitlines()
    except OSError:
        lines = []
    for raw in lines:
        try:
            r = json.loads(raw)
        except ValueError:
            continue
        if r.get('hook') == 'launch_gate' and r.get('session_id') and r.get('decision') in ('allow', 'deny', 'override'):
            gate = r.get('t')
        if r.get('src') == 'inbox_hook' and r.get('event') in ('inbox_delivered', 'inbox_stop_blocked') \
                and str(r.get('key') or '').startswith('wf_') and r.get('agent_id_in_input'):
            inbox = r.get('at')
    return {'gate_seen_live': gate, 'inbox_seen_live': inbox}


def status(settings_path):
    entries = json.loads(ENTRIES.read_text(encoding='utf-8'))
    try:
        settings = json.loads(Path(settings_path).read_text(encoding='utf-8'))
        err = None
    except Exception as e:
        settings, err = {}, '%s: %s' % (type(e).__name__, e)
    st = {'settings': str(settings_path), 'settings_error': err,
          'registered': registration(settings, entries),
          'scripts_present': {n: (HOOK_DIR / n).is_file() for n in ('launch_gate.py', 'inbox_hook.py')},
          'gate_off_file': (HOOK_DIR / 'LAUNCH_GATE_OFF').exists(),
          'gate_off_env': (os.environ.get('AOP_LAUNCH_GATE') or '').lower() in ('off', '0', 'false', 'disabled'),
          'harness_log': str(log_path())}
    st.update(live_proof(log_path()))
    st['live'] = all(st['registered'].values()) and bool(st['gate_seen_live']) and bool(st['inbox_seen_live'])
    return st


def text(st):
    reg = ', '.join('%s %s' % (k, 'yes' if v else 'NO') for k, v in st['registered'].items())
    out = ['harness: %s' % ('LIVE' if st['live'] else 'NOT LIVE (rule 13 is advisory until it is)'),
           'registered in %s: %s%s' % (st['settings'], reg, ' (%s)' % st['settings_error'] if st['settings_error'] else ''),
           'scripts: ' + ', '.join('%s %s' % (k, 'ok' if v else 'MISSING') for k, v in st['scripts_present'].items()),
           'gate switched off: %s' % ('yes (file)' if st['gate_off_file'] else 'yes (env)' if st['gate_off_env'] else 'no'),
           'live proof: gate %s; inbox %s' % (st['gate_seen_live'] or 'not seen yet', st['inbox_seen_live'] or 'not seen yet')]
    if not all(st['registered'].values()):
        out.append('next: python .claude/hooks/harness_status.py --write-proposed <file>, then the owner copies it '
                   'over .claude/settings.json (new sessions pick it up)')
    elif not st['inbox_seen_live']:
        out.append('next: bind a small workflow run, add a note, run this again (see the docstring)')
    return '\n'.join(out)


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    sp = REPO / '.claude' / 'settings.json'
    if '--settings' in argv:
        sp = Path(argv[argv.index('--settings') + 1])
    if '--write-proposed' in argv:
        out = Path(argv[argv.index('--write-proposed') + 1])
        settings = json.loads(sp.read_text(encoding='utf-8')) if sp.exists() else {}
        m = merged(settings, json.loads(ENTRIES.read_text(encoding='utf-8')))
        out.write_text(json.dumps(m, indent=2) + '\n', encoding='utf-8', newline='\n')
        print('wrote %s (%s kept, entries merged)' % (out, sp))
        return 0
    st = status(sp)
    print(json.dumps(st, indent=1) if '--json' in argv else text(st))
    return 0


if __name__ == '__main__':
    sys.exit(main())
