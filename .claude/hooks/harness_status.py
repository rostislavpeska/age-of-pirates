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
It also counts owner-approved work that never started (INC-002 G3, KTC-160): tasks of the task store whose applied
decision or owner go is older than 60 min with no lease or attempt (the engine's meta.board.approved_waiting;
tasks.py tick / audit exit 3 on the same list).
And the background tasks (INC-027, KTC-164): "background tasks: N (oldest ..., task ...)" - the watches registered by
watch.py plus this session's raw endless loops outside it, with what to stop.
"""
import json
import os
import sys
import time
from datetime import datetime, timezone
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


def _utc(s):
    try:
        t = datetime.fromisoformat(str(s).replace('Z', '+00:00'))
    except (TypeError, ValueError):
        return None
    return t if t.tzinfo else t.replace(tzinfo=timezone.utc)


def approved_idle(now=None):
    """owner-approved work idle past its due time, read from the task store's board (every engine command writes
    meta.board.approved_waiting = [{id, by, since, due}]): {count, ids, waiting, store}; None = no readable store"""
    p = tasks_dir() / 'tasks.json'
    try:
        d = json.loads(p.read_text(encoding='utf-8-sig'))
    except (OSError, ValueError):
        return None
    now = now or datetime.now(timezone.utc)
    waiting = [w for w in ((d.get('meta') or {}).get('board') or {}).get('approved_waiting') or [] if isinstance(w, dict)]
    due = [w for w in waiting if _utc(w.get('due')) is not None and _utc(w.get('due')) <= now]
    return {'count': len(due), 'ids': [w.get('id') for w in due], 'waiting': len(waiting), 'store': str(p)}


def background(now=None, scan=None):
    """INC-027 (KTC-164): the background tasks - watches registered by watch.py (<tasks>/watch/) and, for this session,
    raw endless loops running outside watch.py (turn_end_guard.raw_loops). -> {count, oldest, watches, stale, dead,
    corrupt, loops}; oldest = {what, age_s, task}; loops None when the process scan failed; None when watch.py is
    missing. AOP_TURN_END_SCAN=off skips the process scan"""
    try:
        if str(HOOK_DIR) not in sys.path:
            sys.path.insert(0, str(HOOK_DIR))
        import watch as W
    except Exception:  # noqa: BLE001 - a status line never breaks the status
        return None
    now = time.time() if now is None else now
    store = W.Store()
    rows, corrupt = [], 0
    for _p, e in W.entries():
        if e is None:
            corrupt += 1
            continue
        rows.append({'what': e['id'], 'task': e.get('task'), 'age_s': now - float(e['started_ts']),
                     'why': W.stale_reason(e, store, now)})
    dead = [r['what'] for r in rows if (r['why'] or '').startswith('dead')]
    live = [r for r in rows if r['what'] not in dead]
    scan = ((os.environ.get('AOP_TURN_END_SCAN') or '').strip().lower() not in ('off', '0', 'false', 'disabled')
            if scan is None else scan)
    loops = []
    if scan:
        try:
            import turn_end_guard as T
            loops = [{'what': 'pid %d' % r['pid'], 'task': None, 'age_s': r['age'] or 0.0, 'why': r['hits'][0]}
                     for r in T.raw_loops(now=now)]
        except Exception:  # noqa: BLE001
            loops = None
    every = live + (loops or [])
    oldest = max(every, key=lambda r: r['age_s']) if every else None
    return {'count': len(every), 'oldest': oldest, 'watches': len(live), 'stale': [r for r in live if r['why']],
            'dead': dead, 'corrupt': corrupt, 'loops': loops}


def _dur(sec):
    sec = int(max(0, sec or 0))
    return '%dh%02dm' % (sec // 3600, sec % 3600 // 60) if sec >= 3600 else '%dm%02ds' % (sec // 60, sec % 60)


def background_line(bg):
    """'background tasks: N (oldest ..., task ...)' + what to do about stale ones"""
    if bg is None:
        return 'background tasks: unknown (.claude/hooks/watch.py missing)'
    o = bg['oldest']
    line = 'background tasks: %d' % bg['count']
    if o:
        line += ' (oldest %s %s, task %s)' % (o['what'], _dur(o['age_s']),
                                             o['task'] or 'none: raw loop outside watch.py')
    extra = []
    if bg['stale']:
        extra.append('%d watch(es) outlived their job: %s -> python .claude/hooks/watch.py stop --stale'
                     % (len(bg['stale']), ', '.join('%s (%s)' % (r['what'], r['why']) for r in bg['stale'])))
    if bg['loops']:
        extra.append('%d raw loop(s) outside watch.py: %s -> TaskStop them (or taskkill /PID <pid> /T /F), '
                     'restart through watch.py if still needed'
                     % (len(bg['loops']), ', '.join('%s %s' % (r['what'], _dur(r['age_s'])) for r in bg['loops'])))
    elif bg['loops'] is None:
        extra.append('process scan failed')
    if bg['dead'] or bg['corrupt']:
        extra.append('%d entr(ies) left behind by killed watches (watch.py stop --stale removes them)'
                     % (len(bg['dead']) + bg['corrupt']))
    return line + ('; ' + '; '.join(extra) if extra else '')


def status(settings_path):
    entries = json.loads(ENTRIES.read_text(encoding='utf-8'))
    try:
        settings = json.loads(Path(settings_path).read_text(encoding='utf-8'))
        err = None
    except Exception as e:
        settings, err = {}, '%s: %s' % (type(e).__name__, e)
    st = {'settings': str(settings_path), 'settings_error': err,
          'registered': registration(settings, entries),
          'scripts_present': {n: (HOOK_DIR / n).is_file() for n in ('launch_gate.py', 'inbox_hook.py', 'tool_guard.py',
                                                                   'watch.py', 'turn_end_guard.py')},
          'gate_off_file': (HOOK_DIR / 'LAUNCH_GATE_OFF').exists(),
          'gate_off_env': (os.environ.get('AOP_LAUNCH_GATE') or '').lower() in ('off', '0', 'false', 'disabled'),
          'harness_log': str(log_path())}
    st.update(live_proof(log_path()))
    # rule 13 is live when the launch gate and the inbox are registered and seen; other entries (tool_guard) are
    # listed as pending without turning the core harness "NOT LIVE"
    core = {'hooks': {ev: [g for g in groups if any(s in json.dumps(g) for s in ('launch_gate.py', 'inbox_hook.py'))]
                      for ev, groups in entries['hooks'].items()}}
    core_ok = all(registration(settings, core).values())
    st['pending'] = sorted({h.get('command', '').split('/.claude/hooks/')[-1].split('"')[0]
                            for ev, groups in entries['hooks'].items() for g in groups for h in g.get('hooks', [])
                            if h.get('command') not in _commands(settings.get('hooks', {}).get(ev))})
    st['live'] = core_ok and bool(st['gate_seen_live']) and bool(st['inbox_seen_live'])
    st['approved_idle'] = approved_idle()
    st['background'] = background()
    return st


def text(st):
    reg = ', '.join('%s %s' % (k, 'yes' if v else 'NO') for k, v in st['registered'].items())
    out = ['harness: %s' % ('LIVE' if st['live'] else 'NOT LIVE (rule 13 is advisory until it is)')
           + ('; not registered yet: %s' % ', '.join(st['pending']) if st.get('pending') else ''),
           'registered in %s: %s%s' % (st['settings'], reg, ' (%s)' % st['settings_error'] if st['settings_error'] else ''),
           'scripts: ' + ', '.join('%s %s' % (k, 'ok' if v else 'MISSING') for k, v in st['scripts_present'].items()),
           'gate switched off: %s' % ('yes (file)' if st['gate_off_file'] else 'yes (env)' if st['gate_off_env'] else 'no'),
           'live proof: gate %s; inbox %s' % (st['gate_seen_live'] or 'not seen yet', st['inbox_seen_live'] or 'not seen yet')]
    ai = st.get('approved_idle')
    out.append('approved work idle > 60 min: unknown (no task store)' if ai is None else
               'approved work idle > 60 min: %d%s (%d approved and waiting; tasks.py tick / audit exit 3 while any)'
               % (ai['count'], ' - ' + ', '.join(ai['ids']) if ai['ids'] else '', ai['waiting']))
    if 'background' in st:
        out.append(background_line(st['background']))
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
