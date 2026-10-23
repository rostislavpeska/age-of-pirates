#!/usr/bin/env python3
"""Turn-end guard: a Stop hook (incident INC-027, task KTC-164). Background work must not outlive its job.

INC-027: a Blender port watchdog (`while netstat ... LISTENING; do sleep 20; done`, a background Bash task) ran 32 hours
after the live Blender work ended; nothing at the end of any turn said it was still there. At the end of a turn this
hook looks at two things and blocks the stop ONCE per item ({"decision": "block", "reason": "stop <id> first: ..."}):

  W  a watch registered by .claude/hooks/watch.py that outlived its job: its TTL passed, its task ended (done /
     rejected / superseded / on_hold, lease released), its run was unbound or its session is gone - and it still runs
     AOP_TURN_END_WAIT seconds (default 7) later (a live watch notices its end within ~5 s and exits by itself)
  L  a process of THIS session (a descendant of its Claude Code process: CLAUDE_PID, else the nearest claude/codex
     ancestor of the hook) whose command line runs an endless loop outside watch.py - the tool_guard R3 patterns
     (while/until ... sleep, while true, for (;;), watch, tail -f, sleep infinity ...), not wrapped by a timeout of
     at most 1h (in its own command line or an ancestor's). Nested copies of one command (Git Bash forks) are one item.
     Also an ORPHANED shell running such a loop (its parent is gone): killing a Git Bash tree misses what MSYS
     started through fork + exec, so leaked loops end up parentless (raw_loops docstring). An orphan is the session's
     when it, or its parent, was one of the session's processes at an earlier turn end (remembered in
     <tasks>/watch/.turn_end_session_procs.json, 24 h, per session root): found at once (INC-037). Any other orphan
     counts only older than 1h05m (it may still be a `timeout <= 1h` child).

A registry entry whose process is gone is removed silently (logged). Items already reported are remembered in
<tasks>/watch/.turn_end_reported.json (7 days) and never block twice: the model gets one continuation per item, and an
item already reported is not waited for again (INC-038: the 7 s grace ran at every turn end while it lived).
Fails OPEN: any internal error, a corrupt registry entry or an unwritable memory file = no block (logged); a corrupt
memory file is read as empty (logged) and rewritten - its items are named once more, since a lost memory must not hide
a stale watch (INC-038: the docstring said "no block").
Cost: one Python start per turn end; a process snapshot (ctypes) and the command lines of this session's shell
processes only. Env: AOP_TASKS_DIR, AOP_HARNESS_LOG, AOP_TURN_END_GUARD=off, AOP_TURN_END_SCAN=off (registry only),
AOP_TURN_END_WAIT (seconds). Contract: stdout carries only the hook JSON on a block, nothing otherwise; exit 0 always.
"""
import json
import os
import re
import sys
import time
from pathlib import Path

HOOK_DIR = Path(__file__).resolve().parent
if str(HOOK_DIR) not in sys.path:
    sys.path.insert(0, str(HOOK_DIR))
import tool_guard as G  # noqa: E402
import watch as W  # noqa: E402

SHELLS = re.compile(r'^(?:bash|sh|dash|zsh|ksh|powershell|pwsh|python\d*(?:\.\d+)?|pythonw|py|node)(?:\.exe)?$', re.I)
REMEMBER_S = 7 * 86400
SESSION_S = 86400                                  # how long the session's processes are remembered (orphan origin)
SESSION_PROCS = '.turn_end_session_procs.json'
ORPHAN_MIN_AGE_S = G.LOOP_TIMEOUT_MAX_S + 300      # an orphaned loop older than any allowed timeout bound
WAIT_DEFAULT_S = 7.0
MEMORY = '.turn_end_reported.json'


def _off(name):
    return (os.environ.get(name) or '').strip().lower() in ('off', '0', 'false', 'disabled')


def wait_s():
    try:
        return max(0.0, float(os.environ.get('AOP_TURN_END_WAIT') or WAIT_DEFAULT_S))
    except ValueError:
        return WAIT_DEFAULT_S


def age_s(created, now=None):
    """seconds since a process started (W.proc_created value), or None"""
    now = time.time() if now is None else now
    if not created:
        return None
    if os.name == 'nt':
        return max(0.0, now - (created / 1e7 - 11644473600))
    try:
        with open('/proc/uptime', encoding='ascii') as f:
            up = float(f.read().split()[0])
        return max(0.0, up - created / os.sysconf('SC_CLK_TCK'))
    except (OSError, ValueError, AttributeError):
        return None


# ------------------------------------------------------------------------------------------ W: registered watches
def watch_items(store=None, now=None, wait=None, wdir=None, known=()):
    """[(key, text)] for alive watches that outlived their job; dead entries are removed (logged). Keys in `known`
    (already reported) are skipped without the grace wait (INC-038)"""
    store = store or W.Store()
    now = time.time() if now is None else now
    pending = []
    for p, e in W.entries(wdir):
        if e is None:
            W.log({'event': 'turn_end_corrupt_entry', 'file': str(p)}, hook='turn_end_guard')
            continue                                    # fail open for that entry
        if not W.proc_alive(e.get('pid'), e.get('created')):
            W.unregister(e['id'], p.parent)
            W.log({'event': 'watch_entry_pruned', 'id': e['id'], 'task': e.get('task'), 'pid': e.get('pid')},
                  hook='turn_end_guard')
            continue
        why = W.end_reason(e, store, now)
        if why and f"watch:{e['id']}" not in known:
            pending.append((p, e, why))
    if pending:
        t_end = time.time() + (wait_s() if wait is None else wait)
        while time.time() < t_end and any(p.exists() for p, _e, _w in pending):
            time.sleep(0.25)
    out = []
    for p, e, why in pending:
        if p.exists() and W.proc_alive(e.get('pid'), e.get('created')):
            age = W.fmt_dur(now - float(e.get('started_ts') or now))
            out.append((f"watch:{e['id']}",
                        f"stop {e['id']} first: watch {e['id']} (task {e.get('task')}, pid {e.get('pid')}, age {age}) "
                        f"outlived its job - {why}. Run: python .claude/hooks/watch.py stop {e['id']}"))
    return out


# ------------------------------------------------------------------------------------------ L: raw loops of the session
def session_root(table, env=None):
    env = os.environ if env is None else env
    try:
        pid = int(env.get('CLAUDE_PID') or 0)
    except ValueError:
        pid = 0
    if pid and pid in table and W.proc_alive(pid):
        return pid
    for p, exe in W.ancestors(os.getpid(), table):
        if W.AGENT_EXE.match(exe or ''):
            return p
    return None


def descendants(root, table):
    kids = {}
    for pid, (ppid, _exe) in table.items():
        kids.setdefault(ppid, []).append(pid)
    out, todo = [], list(kids.get(root, []))
    seen = {root}
    while todo:
        p = todo.pop()
        if p in seen:
            continue
        seen.add(p)
        out.append(p)
        todo.extend(kids.get(p, []))
    return out


def _bounded_by(cmdline):
    """an ancestor's command line that bounds its children: the watch.py wrapper, or a timeout <= 1h"""
    if not cmdline:
        return False
    if G.WATCH_PY.search(cmdline):
        return True
    return any(0 < G._secs(m) <= G.LOOP_TIMEOUT_MAX_S for m in G.TIMEOUT_WRAP.finditer(cmdline))


def raw_loops(table=None, root=None, cmdline=None, now=None, orphans=True, created=None, seen=None):
    """[{pid, created, exe, cmd, hits, age, orphan}] - the topmost process of each endless loop that runs outside
    watch.py and without a timeout <= 1h: under `root` (the session's agent process), and - orphans=True - any shell
    whose parent is gone and that is older than ORPHAN_MIN_AGE_S. Orphans are how loops leak on Windows: killing a Git
    Bash tree (TaskStop, a Monitor expiry, taskkill /T) misses processes MSYS started through fork + exec (their Windows
    parent is a stub that is already gone; measured 2026-09-30 with `timeout 60 bash -c 'while ...'`), and a leaked
    loop older than the longest allowed timeout bound cannot be a bounded one. `seen` {pid: created} = the session's
    processes at earlier turn ends: an orphan that was one of them, or whose parent was, is the session's leak at any
    age (INC-037). [] when the root is unknown"""
    table = W.proc_table() if table is None else table
    cmdline = cmdline or W.proc_cmdline
    created_of = created or W.proc_created
    root = session_root(table) if root is None else root
    if not root:
        return []
    mine = {os.getpid()} | {p for p, _ in W.ancestors(os.getpid(), table)}
    flagged, orphan = {}, set()
    cache = {}

    def cl(p):
        if p not in cache:
            cache[p] = cmdline(p) or ''
        return cache[p]

    below = descendants(root, table)
    for pid in below:
        exe = table[pid][1]
        if pid in mine or not SHELLS.match(exe or ''):
            continue
        hits = G.check_loop(cl(pid))
        if not hits:
            continue
        chain = []
        for a, _exe in W.ancestors(pid, table):
            if a == root:
                break
            chain.append(a)
        if any(_bounded_by(cl(a)) for a in chain):
            continue
        flagged[pid] = hits
    if orphans:
        skip = set(below) | mine
        for pid, (ppid, exe) in table.items():
            if pid in skip or ppid in table or pid <= 4 or not SHELLS.match(exe or ''):
                continue
            c = created_of(pid)
            a = age_s(c, now)
            ours = bool(seen) and (seen.get(pid) == c or (ppid in seen and (not c or not seen[ppid]
                                                                             or seen[ppid] <= c)))
            if not ours and (a is None or a < ORPHAN_MIN_AGE_S):
                continue
            hits = G.check_loop(cl(pid))
            if hits:
                flagged[pid] = hits
                orphan.add(pid)
    out = []
    for pid, hits in flagged.items():
        if table[pid][0] in flagged:
            continue                                   # a nested copy (Git Bash forks): its top is reported
        created = created_of(pid)
        out.append({'pid': pid, 'created': created, 'exe': table[pid][1], 'cmd': cl(pid), 'hits': hits,
                    'age': age_s(created, now), 'orphan': pid in orphan})
    return sorted(out, key=lambda r: r['pid'])


def _loop_text(cmd):
    """the user command inside Claude Code's `bash -c "source <snapshot> ... && eval '<command>'"` wrapper"""
    i = cmd.find("eval '")
    s = cmd[i + 6:] if i >= 0 else cmd
    s = s.replace('\'"\'"\'', "'").replace('\\"', '"')
    return ' '.join(s.split())[:140]


def loop_items(procs):
    out = []
    for r in procs:
        age = W.fmt_dur(r['age']) if r['age'] is not None else '?'
        kill = (f"taskkill /PID {r['pid']} /T /F" if os.name == 'nt' else f"kill {r['pid']}")
        whose = 'an ORPHANED process (its parent is gone)' if r.get('orphan') else r['exe']
        out.append((f"proc:{r['pid']}:{r['created']}",
                    f"stop pid {r['pid']} first: {whose} (age {age}) runs an endless loop outside watch.py - "
                    f"{r['hits'][0]}: {_loop_text(r['cmd'])}. End it (TaskStop on its background task, or {kill}); "
                    'if it is still needed, restart it through python .claude/hooks/watch.py start --task <KTC id> ...'))
    return out


def _session_key(root, created_of):
    return f'{root}:{created_of(root) or 0}'


def session_seen(root, created_of=None, wdir=None, now=None):
    """{pid: created} of the session's processes remembered at earlier turn ends (INC-037); {} when none or unreadable"""
    created_of = created_of or W.proc_created
    now = time.time() if now is None else now
    try:
        doc = json.loads(((wdir or W.watch_dir()) / SESSION_PROCS).read_text(encoding='utf-8'))
        mine = doc.get(_session_key(root, created_of)) or {}
        return {int(k.split(':')[0]): int(k.split(':')[1]) for k, t in mine.items() if now - float(t) < SESSION_S}
    except (OSError, ValueError, AttributeError, IndexError, TypeError):
        return {}


def remember_session(root, table, created_of=None, now=None, wdir=None):
    """write the session's current descendants (pid:created) under its root, keeping 24 h (INC-037)"""
    created_of = created_of or W.proc_created
    now = time.time() if now is None else now
    p = (wdir or W.watch_dir()) / SESSION_PROCS
    try:
        doc = json.loads(p.read_text(encoding='utf-8'))
        doc = doc if isinstance(doc, dict) else {}
    except (OSError, ValueError):
        doc = {}
    doc = {r: {k: t for k, t in (v or {}).items() if isinstance(t, (int, float)) and now - t < SESSION_S}
           for r, v in doc.items() if isinstance(v, dict)}
    mine = doc.setdefault(_session_key(root, created_of), {})
    for pid in descendants(root, table):
        mine[f'{pid}:{created_of(pid) or 0}'] = now
    doc = {r: v for r, v in doc.items() if v}
    try:
        p.parent.mkdir(parents=True, exist_ok=True)
        W._write_json(p, doc)
    except OSError as e:
        W.log({'event': 'turn_end_session_unwritable', 'error': str(e)[:120]}, hook='turn_end_guard')


# ------------------------------------------------------------------------------------------ memory + main
def load_memory(p, now):
    try:
        m = json.loads(p.read_text(encoding='utf-8'))
        if not isinstance(m, dict):
            raise ValueError('not an object')
    except FileNotFoundError:
        return {}
    except (OSError, ValueError) as e:
        W.log({'event': 'turn_end_memory_corrupt', 'file': str(p), 'error': str(e)[:120]}, hook='turn_end_guard')
        return {}
    return {k: v for k, v in m.items() if isinstance(v, (int, float)) and now - v < REMEMBER_S}


def evaluate(inp=None, now=None, scan=None, table=None, root=None, orphans=True):
    """-> (block reason or None, new item keys)"""
    now = time.time() if now is None else now
    wdir = W.watch_dir()
    mp = wdir / MEMORY
    mem = load_memory(mp, now) if mp.exists() else {}
    items = watch_items(now=now, known=set(mem))
    scan = (not _off('AOP_TURN_END_SCAN')) if scan is None else scan
    if scan:
        table = W.proc_table() if table is None else table
        root = session_root(table) if root is None else root
        seen = session_seen(root) if root else {}
        items += loop_items(raw_loops(table=table, root=root, now=now, orphans=orphans, seen=seen))
        if root:
            remember_session(root, table, now=now)
    if not items:
        return None, []
    new = [(k, t) for k, t in items if k not in mem]
    if not new:
        return None, []
    for k, _t in new:
        mem[k] = now
    try:
        W._write_json(mp, mem)
    except OSError as e:                                # cannot remember: say so, and do not block (fail open,
        W.log({'event': 'turn_end_memory_unwritable', 'error': str(e)[:120]}, hook='turn_end_guard')
        return None, []                                 # a block we cannot remember could repeat every turn)
    reason = ('Background work outlived its job (INC-027): ' + ' | '.join(t for _k, t in new) +
              ' (reported once; `python .claude/hooks/watch.py list` shows the registered watches)')
    return reason, [k for k, _t in new]


def main():
    try:
        raw = sys.stdin.buffer.read()
        if _off('AOP_TURN_END_GUARD'):
            return 0
        try:
            inp = json.loads(raw.decode('utf-8-sig', 'replace')) if raw.strip() else {}
        except ValueError:
            inp = {}
        inp = inp if isinstance(inp, dict) else {}
        reason, keys = evaluate(inp)
        if not reason:
            return 0
        W.log({'event': 'turn_end_block', 'items': keys, 'session_id': inp.get('session_id'),
               'stop_hook_active': inp.get('stop_hook_active')}, hook='turn_end_guard')
        sys.stdout.write(json.dumps({'decision': 'block', 'reason': reason}))
        return 0
    except Exception as e:  # noqa: BLE001 - fail open, logged
        W.log({'event': 'turn_end_error', 'error': f'{type(e).__name__}: {e}'}, hook='turn_end_guard')
        return 0


if __name__ == '__main__':
    sys.exit(main())
