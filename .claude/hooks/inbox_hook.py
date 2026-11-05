"""Task inbox hook: hands a running agent the late instructions of its task, and nothing else.

Registered for PostToolUse (every tool) and SubagentStop. The store and the CLI live with the task engine
(tasks/inbox.py, `tasks.py note|inbox|bind-run`); this file only resolves the agent to its task and calls it.

    PostToolUse   the agent's task has notes after its cursor -> they come back as additionalContext, the cursor
                  advances. No task, or the inbox file unchanged since the agent last read it -> no output (0 tokens).
    SubagentStop  unread notes -> exit 2 "read your inbox"; the third time it lets the agent stop and logs
                  TECH_BLOCKED (AGENTS.md rule 12). Released stays released for those notes: later stops pass
                  without a block (each block costs a continuation turn) until a NEWER note arrives.

The agent -> task link: tasks/inbox/runs.json {workflow run id | agent id: task}; the workflow run id is a folder of
the hook input's transcript_path (.../subagents/workflows/wf_XXXX/agent-*.jsonl). The reader is the agent id.
Fails open: any internal error is logged to tasks/harness_log.jsonl and the action goes on. Prints nothing else.
Task engine folder: AOP_TASKS_DIR from the environment or config/aop.local.env (scripts/tools/local_env.py; not set up
on this device or a missing folder = the hook does nothing). Unbound agents exit before json or the store is
imported: the cost is the Python start alone. The registered command skips Python entirely while runs.json binds
nothing (a Git Bash check, see .claude/hooks/settings_entries.json); a runs.json not written for 24 h is emptied
here (inbox.expire_bindings) so a forgotten binding cannot keep every call on the slow path.
"""
import os
import sys
import time

MAX_BLOCKS = 2          # SubagentStop blocks per reader; the next stop is let through as TECH_BLOCKED
_TOOLS = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), 'scripts', 'tools')


def tasks_dir():
    if _TOOLS not in sys.path:
        sys.path.append(_TOOLS)
    import local_env
    return local_env.tasks_dir()


def log(td, rec):
    try:
        import json
        rec = {'at': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()), 'src': 'inbox_hook', **rec}
        with open(os.path.join(td, 'harness_log.jsonl'), 'a', encoding='utf-8', newline='\n') as f:
            f.write(json.dumps(rec, ensure_ascii=False, default=str) + '\n')
    except Exception:
        pass


def bound_runs(runs_file):
    """runs.json as [(key, task)] without the json module (bind-run allows [A-Za-z0-9._-] only: no quote inside a
    key or a value, so the file splits on '"' into key, value, key, value ...); [] when nothing is bound"""
    try:
        with open(runs_file, encoding='utf-8') as f:
            tok = f.read().split('"')
    except OSError:
        return []
    return list(zip(tok[1::4], tok[3::4]))


def nothing_new(root, text, pairs):
    """True only when this agent's task inbox is provably unchanged since the agent last read it, decided without
    json or the store: one bound task among the keys found in the input, the agent id, and seen.<agent> (the stat
    the store wrote with the cursor) equal to the inbox file's stat now. Anything else -> False (the full path)."""
    tasks = {t for k, t in pairs if k and k in text}
    i = text.find('"agent_id"')
    if len(tasks) != 1 or i < 0:
        return False
    j = text.find('"', text.find(':', i) + 1)
    aid = text[j + 1:text.find('"', j + 1)] if j > 0 else ''
    if not aid or '\\' in aid or '/' in aid:
        return False
    d = os.path.join(root, tasks.pop())
    try:
        with open(os.path.join(d, 'seen.' + aid), encoding='ascii') as f:
            seen = f.read().strip()
        s = os.stat(os.path.join(d, 'inbox.jsonl'))
    except OSError:
        return False
    if seen != '%d %d' % (s.st_size, s.st_mtime_ns):
        return False
    try:                                        # keep the reader registered (READER_TTL in inbox.py)
        cp = os.path.join(d, 'cursor.' + aid + '.json')
        if time.time() - os.stat(cp).st_mtime > 900:
            os.utime(cp)
    except OSError:
        pass
    return True


def expire_stale(td, root):
    """runs.json not written for inbox.BIND_TTL (24 h): drop every binding (one stat when fresh)"""
    try:
        if time.time() - os.stat(os.path.join(root, 'runs.json')).st_mtime <= 24 * 3600:
            return
        sys.path.insert(0, td)
        import inbox as ib
        gone = ib.expire_bindings(root)
        if gone:
            log(td, {'event': 'bindings_expired', 'dropped': gone})
    except Exception as e:                      # never block on housekeeping
        log(td, {'event': 'inbox_error', 'error': f'expire: {type(e).__name__}: {e}', 'action': 'ignored'})


def _parts(tp):
    parts = str(tp or '').replace('\\', '/').split('/')
    return parts[parts.index('subagents') + 1:] if 'subagents' in parts else []


def keys_of(p):
    """candidate binding keys: the agent id, then every folder/file below 'subagents' in the transcript paths"""
    aid = str(p.get('agent_id') or '').strip()
    keys = [aid] if aid else []
    for tp in (p.get('agent_transcript_path'), p.get('transcript_path')):
        for x in _parts(tp):
            x = x[:-6] if x.endswith('.jsonl') else x
            if x and x not in keys:
                keys.append(x)
    return keys


def reader_of(p):
    aid = str(p.get('agent_id') or '').strip()
    if aid:
        return aid
    for tp in (p.get('agent_transcript_path'), p.get('transcript_path')):
        parts = _parts(tp)
        name = parts[-1] if parts else ''
        if name.startswith('agent-') and name.endswith('.jsonl'):
            return name[len('agent-'):-len('.jsonl')]
    return None


def run_of_agent(root, text):
    """The workflow run of a subagent whose hook input carries only its agent_id and the SESSION transcript_path
    (PostToolUse inside a workflow agent - measured live 2026-09-29 23:20: only SubagentStop carries the agent's own
    transcript path). Looks for <session>/subagents/workflows/<run>/agent-<id>.jsonl once and caches the answer
    (also a negative one) in inbox/agents.cache, so later tool calls cost one small file read."""
    import json
    try:
        p = json.loads(text or '{}')
    except ValueError:
        return None
    aid = str(p.get('agent_id') or '').strip()
    tp = str(p.get('transcript_path') or '')
    if not aid or not tp:
        return None
    cache = os.path.join(root, 'agents.cache')
    try:
        with open(cache, encoding='utf-8') as f:
            for line in f:
                a, _, r = line.strip().partition(' ')
                if a == aid:
                    return r or None
    except OSError:
        pass
    import glob
    sess = tp[:-6] if tp.endswith('.jsonl') else tp
    hits = glob.glob(os.path.join(sess, 'subagents', 'workflows', '*', f'agent-{aid}.jsonl'))
    run = os.path.basename(os.path.dirname(hits[0])) if hits else ''
    if hits or os.path.isdir(sess):             # cache a miss only when the session folder exists (not a bad path)
        try:
            with open(cache, 'a', encoding='utf-8') as f:
                f.write(f'{aid} {run}\n')
        except OSError:
            pass
    return run or None


def post_tool(ib, root, task, reader, td, why=None):
    d = ib.task_dir(root, task)
    if not d.is_dir():
        return 0
    try:
        c = ib.read_cursor(d, reader)
    except ib.CorruptCursor as e:
        ib.quarantine_cursor(d, reader)        # the next call re-registers this reader from note 1
        log(td, {'event': 'inbox_error', 'task': task, 'reader': reader, 'error': f'corrupt cursor: {e}',
                 'action': 'fail open; cursor moved to .bad'})
        return 0
    if c is not None and c.get('stat') == ib.file_stat(d / 'inbox.jsonl'):
        try:                                    # fast path: nothing new; keep the reader registered
            cp = ib.cursor_path(d, reader)
            if time.time() - cp.stat().st_mtime > ib.TOUCH_EVERY:
                os.utime(cp)
        except OSError:
            pass
        return 0
    new = ib.unread(root, task, reader)
    if not new:
        return 0
    import json
    txt = '\n'.join(ib.fmt(r) for r in new)
    txt += ('\nThese override your brief: apply them now. Your final report lists the notes you applied as '
            f"NOTES APPLIED: {', '.join(str(r['n']) for r in new)}")
    sys.stdout.write(json.dumps({'hookSpecificOutput': {'hookEventName': 'PostToolUse', 'additionalContext': txt}}))
    log(td, dict({'event': 'inbox_delivered', 'task': task, 'reader': reader, 'notes': [r['n'] for r in new]},
                 **(why or {})))
    return 0


def subagent_stop(ib, root, task, reader, td, why=None):
    d = ib.task_dir(root, task)
    if not d.is_dir():
        return 0, None
    try:
        ns, c = ib.pending_notes(root, task, reader)
    except ib.CorruptCursor as e:
        ib.quarantine_cursor(d, reader)
        log(td, {'event': 'inbox_error', 'task': task, 'reader': reader, 'error': f'corrupt cursor: {e}',
                 'action': 'fail open: stop allowed'})
        return 0, None
    n = len(ns)
    if not n:
        if c and (c.get('blocks') or c.get('released')):
            with ib.Lock(d):
                c2 = ib.read_cursor(d, reader) or c
                c2['blocks'] = 0
                c2.pop('released', None)
                ib.write_cursor(d, reader, c2)
        return 0, None
    top = max(ns)
    with ib.Lock(d):
        c = ib.read_cursor(d, reader) or {'n': 0, 'stat': None, 'blocks': 0}
        if int(c.get('released') or 0) >= top:
            return 0, None                      # already let through for these notes; only a newer one re-arms
        blocks = int(c.get('blocks') or 0) + 1
        if blocks > MAX_BLOCKS:
            c['blocks'] = 0
            c['released'] = top
            ib.write_cursor(d, reader, c)
            log(td, {'event': 'TECH_BLOCKED', 'task': task, 'reader': reader, 'unread': n, 'released_up_to': top,
                     'why': f'agent stopped {blocks - 1}x with unread inbox notes; stop let through, no further '
                            f'blocks until a note after {top}'})
            return 0, None
        c['blocks'] = blocks
        ib.write_cursor(d, reader, c)
    log(td, dict({'event': 'inbox_stop_blocked', 'task': task, 'reader': reader, 'unread': n, 'block': blocks},
                 **(why or {})))
    return 2, (f'read your inbox: {n} unread note(s) for task {task}. Run any tool (they arrive with its result) or '
               f'`python tasks/tasks.py inbox {task} --unread --reader {reader}`, apply them, and list them in your '
               'report as NOTES APPLIED: <numbers>.')


def main():
    td = None
    try:
        raw = sys.stdin.buffer.read()           # always drain stdin (the caller's pipe must not break)
        td = tasks_dir()
        root = os.path.join(td, 'inbox')
        pairs = bound_runs(os.path.join(root, 'runs.json'))
        if not pairs:
            return 0                            # nothing bound anywhere: the common case
        text = raw.decode('utf-8-sig', errors='replace')
        run = None
        if not any(k and k in text for k, _t in pairs):
            run = run_of_agent(root, text) if '"agent_id"' in text else None
            if not run or not any(k == run for k, _t in pairs):
                expire_stale(td, root)
                return 0                        # this agent's run / id is not bound
        check = text + ' "' + run + '"' if run else text   # the run key appears for the fast checks only
        if nothing_new(root, check, pairs):
            return 0                            # bound, inbox unchanged since this agent read it
        import json
        p = json.loads(text or '{}')
        ev = p.get('hook_event_name')
        if ev not in ('PostToolUse', 'SubagentStop'):
            return 0
        sys.path.insert(0, td)
        import inbox as ib                      # noqa: E402  (the store lives with the task engine)
        task, key = ib.resolve(root, keys_of(p) + ([run] if run else []))
        if not task:
            return 0
        reader = reader_of(p)
        if not reader:
            return 0
        reader = ib.check_id('reader', reader)
        why = {'key': key, 'agent_id_in_input': bool(p.get('agent_id')),     # the live proof (AGENTS.md rule 13)
               'via': 'agent_run_lookup' if run and key == run else
                      ('transcript_path' if key != p.get('agent_id') else 'agent_id')}
        if ev == 'PostToolUse':
            return post_tool(ib, root, task, reader, td, why)
        rc, why = subagent_stop(ib, root, task, reader, td, why)
        if rc == 2:
            sys.stderr.write(why)
        return rc
    except Exception as e:                      # fail open: never block an agent on the hook's own error
        if td is not None:
            import traceback
            log(td, {'event': 'inbox_error', 'error': f'{type(e).__name__}: {e}',
                     'trace': traceback.format_exc(limit=3)[-600:], 'action': 'fail open'})
        return 0


if __name__ == '__main__':
    sys.exit(main())
