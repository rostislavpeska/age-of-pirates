#!/usr/bin/env python3
"""Launch gate: a PreToolUse hook on the Workflow / Agent / Task tools.

Owner, 2026-09-29: "How to prevent firing too many agents and how to define ABSOLUTE priorities for
CRITICAL tasks". The gate refuses a launch (the model sees the reason) when:

  A  cap          >= CAP (2) jobs already run. A job is, in every in-scope session (this repo's project slugs,
                  env AOP_LAUNCH_GATE_SCOPE, 'all' = every project): a Workflow run with no finished run record
                  and activity in the last 6 h; a top-level Agent (background OR foreground) whose transcript
                  moved in the last 45 min and whose last turn did not end; a launch reservation not yet matched
                  by its real run (TTL 3 min); a claim taken with --claim (Codex and other agents, TTL 60 min).
                  Every allowed launch writes its reservation under an O_EXCL ledger lock, so parallel calls in
                  one message are counted one after the other (3 parallel launches with 1 running: allow, deny,
                  deny). Exempt from A only: an Agent/Task call whose description contains "read-only lookup",
                  and a launch made from inside a running job (hook input has agent_id: it is part of that job).
  B  P0 first     tasks.json holds open P0 bugs (effective band P0, type bug, status captured|ready, no owner
                  hold). Then a launch must DECLARE one of them, or a running (leased|in_progress) P0 task:
                  `task: KTC-155` (or `P0: KTC-155`) in its meta description / Agent description or prompt, or
                  Workflow args.task. A bare mention ("not KTC-155") does not count. Applies to every launch.
  C  resume       a Workflow of this session started in the last 12 h with the same meta name, OR a script
                  that shares >= 80 % of its lines with it (a renamed copy), launched without resumeFromRunId,
                  unless its description holds "fresh-run: <reason>".

Override (owner only): env AOP_LAUNCH_GATE=off, or the file .claude/hooks/LAUNCH_GATE_OFF (gitignored).
Every refusal, override, exemption, allow, claim and internal error is one line in harness_log.jsonl.

Where the run facts come from (measured on session 606bcdfd, 2026-09-29): subagents/workflows/<runId>/
journal.jsonl holds launched/started/result lines, but "result" lines are PER AGENT - there is no final
workflow line. The finished marker is the run record workflows/<runId>.json (status completed|killed),
written when the run ends. Script copies workflows/scripts/<name>-<runId>.js (name lower-cased) give
names and start times; when the session cwd changed they sit under a sibling project slug, so every
projects/*/<session_id>/ directory is scanned. Agent metas subagents/agent-*.meta.json carry toolUseId
(= the PreToolUse tool_use_id: how a reservation meets its real agent) and requestShape.

Contract: stdout carries only the Claude Code hook JSON on a deny; nothing is printed otherwise; exit 0
always. Any internal error fails OPEN (logged, launch allowed); a rule whose data cannot be read is
skipped and logged, the other rules still apply. Python standard library only.

CLI:  python launch_gate.py            (hook mode, reads the hook JSON on stdin)
      python launch_gate.py --dry-run  (same input, prints the evaluation as JSON, logs and reserves nothing)
      python launch_gate.py --claim "<job name>" --by codex [--task KTC-155] [--ttl-min 60]
                                       (a non-Claude agent takes a job slot: rules A + B; prints JSON with the
                                        claim id; exit 0 granted, 3 refused)
      python launch_gate.py --renew <claim-id> | --release <claim-id>
Env for tests/other machines: AOP_LAUNCH_GATE_PROJECTS_DIR, AOP_LAUNCH_GATE_TASKS, AOP_HARNESS_LOG,
AOP_LAUNCH_GATE_OFF_FILE, AOP_LAUNCH_GATE_CAP, AOP_LAUNCH_GATE_LEDGER, AOP_LAUNCH_GATE_SCOPE.
"""
import json
import os
import re
import sys
import time
import uuid
from datetime import datetime, timezone
from pathlib import Path

HOOK_DIR = Path(__file__).resolve().parent
GATED_TOOLS = ('Workflow', 'Agent', 'Task')
AGENT_TOOLS = ('Agent', 'Task')
CAP = 2
STALE_S = 6 * 3600            # a run with no activity for 6 h is not running
RELAUNCH_S = 12 * 3600        # rule C window
BG_IDLE_S = 45 * 60           # an agent silent for 45 min is not running
SESSION_RECENT_S = 24 * 3600  # other sessions: only folders touched in the last 24 h are scanned
RES_TTL_S = 180               # a reservation not met by its real run within 3 min expires
CLAIM_TTL_S = 3600            # a --claim holds its slot 60 min unless renewed or released
MATCH_SLACK_S = 30            # a real run/agent this much older than its reservation still meets it
LOCK_WAIT_S = 3.0
LOCK_STALE_S = 30.0
SIMILAR = 0.8                 # rule C: share of script lines that makes a renamed copy
SIMILAR_MIN_LINES = 8
SIMILAR_MAX_RUNS = 20
SCOPE_DEFAULT = r'age-of-pirates|korean-buildings-blender'
RUNNING_STATUSES = {'running', 'started', 'pending', 'queued', 'launched'}
OPEN_P0_STATUSES = {'captured', 'ready'}
RUNNING_TASK_STATUSES = {'leased', 'in_progress'}
LOOKUP_RE = re.compile(r'read[- ]only lookup', re.I)
FRESH_RE = re.compile(r'fresh-run:\s*\S', re.I)
ID_RE = re.compile(r'\b([A-Za-z]{2,10})-(\d{1,5})\b')
DECL_RE = re.compile(r'\b(?:task|p0)\s*[:=]\s*([A-Za-z]{2,10}-\d{1,5})\b', re.I)
SCRIPT_RE = re.compile(r'^(?P<name>.+)-(?P<rid>wf_[0-9a-f]+-[0-9a-f]+)\.js$', re.I)
P0_LIST_MAX = 15


# ------------------------------------------------------------------------------------------ config
def _home_claude():
    return Path(os.environ.get('CLAUDE_CONFIG_DIR') or (Path.home() / '.claude'))


def projects_dir():
    return Path(os.environ.get('AOP_LAUNCH_GATE_PROJECTS_DIR') or (_home_claude() / 'projects'))


def _tasks_dir():
    """scripts/tools/local_env.py: AOP_TASKS_DIR from the environment or config/aop.local.env; not set up on this
    device -> <Claude config dir>/aop-tasks (ledger and log only: no tasks.json, so rule B has no P0 list)"""
    tools = str(HOOK_DIR.parents[1] / 'scripts' / 'tools')
    if tools not in sys.path:
        sys.path.append(tools)
    import local_env
    return Path(local_env.tasks_dir())


def tasks_path():
    return Path(os.environ.get('AOP_LAUNCH_GATE_TASKS') or (_tasks_dir() / 'tasks.json'))


def log_path():
    return Path(os.environ.get('AOP_HARNESS_LOG') or (_tasks_dir() / 'harness_log.jsonl'))


def ledger_dir():
    return Path(os.environ.get('AOP_LAUNCH_GATE_LEDGER') or (_tasks_dir() / 'launch_ledger'))


def off_file():
    return Path(os.environ.get('AOP_LAUNCH_GATE_OFF_FILE') or (HOOK_DIR / 'LAUNCH_GATE_OFF'))


def cap():
    try:
        return max(1, int(os.environ.get('AOP_LAUNCH_GATE_CAP') or CAP))
    except ValueError:
        return CAP


def scope_re():
    s = os.environ.get('AOP_LAUNCH_GATE_SCOPE')
    if s is None or not s.strip():
        s = SCOPE_DEFAULT
    return None if s.strip().lower() == 'all' else re.compile(s, re.I)


def override_source():
    if (os.environ.get('AOP_LAUNCH_GATE') or '').strip().lower() in ('off', '0', 'false', 'disabled'):
        return 'env AOP_LAUNCH_GATE=off'
    try:
        if off_file().exists():
            return 'file ' + off_file().name
    except OSError:
        pass
    return None


# ------------------------------------------------------------------------------------------ helpers
def utc_iso(ts=None):
    dt = datetime.fromtimestamp(ts if ts is not None else time.time(), tz=timezone.utc)
    return dt.strftime('%Y-%m-%dT%H:%M:%SZ')


def norm_name(s):
    return re.sub(r'[^a-z0-9]+', '-', (s or '').lower()).strip('-')


def ids_in(text):
    return {(p.upper(), int(n)) for p, n in ID_RE.findall(text or '')}


def declared_in(text):
    """task ids a launch DECLARES ('task: KTC-155' / 'P0: KTC-155'); a bare mention is not a declaration"""
    out = set()
    for m in DECL_RE.finditer(text or ''):
        out |= ids_in(m.group(1))
    return out


def _js_string(src, key):
    """value of `key: '...'` (or "..." / `...`) in a JS object literal, escapes resolved"""
    m = re.search(r'\b' + key + r"""\s*:\s*(['"`])((?:\\.|(?!\1)[^\\])*)\1""", src, re.S)
    if not m:
        return None
    v = m.group(2)
    return re.sub(r'\\(.)', lambda e: {'n': '\n', 't': '\t'}.get(e.group(1), e.group(1)), v)


def parse_meta(script):
    """(name, description) from `export const meta = {...}`; the meta block is searched first"""
    head = script[:40000]
    i = head.find('meta')
    block = head[i:] if i >= 0 else head
    return _js_string(block, 'name'), _js_string(block, 'description')


def _strip_meta(src):
    """the script without its `export const meta = {...}` block (brace-matched)"""
    i = src.find('export const meta')
    if i < 0:
        return src
    j = src.find('{', i)
    if j < 0:
        return src
    depth = 0
    for k in range(j, min(len(src), j + 40000)):
        c = src[k]
        if c == '{':
            depth += 1
        elif c == '}':
            depth -= 1
            if depth == 0:
                return src[:i] + src[k + 1:]
    return src


def body_lines(src):
    return {ln.strip() for ln in _strip_meta(src or '').splitlines() if len(ln.strip()) >= 4}


def similarity(a, b):
    if min(len(a), len(b)) < SIMILAR_MIN_LINES:
        return 0.0
    return len(a & b) / float(len(a | b))


def log(entry):
    rec = {'t': utc_iso(), 'hook': 'launch_gate'}
    rec.update(entry)
    line = json.dumps(rec, ensure_ascii=False, default=str) + '\n'
    try:
        p = log_path()
        p.parent.mkdir(parents=True, exist_ok=True)
        with open(p, 'a', encoding='utf-8', newline='\n') as f:
            f.write(line)
    except Exception:   # the log itself failed: last resort outside the repo, never the screen
        try:
            fb = Path(os.environ.get('TEMP') or os.environ.get('TMP') or '.') / 'aop_launch_gate_errors.log'
            with open(fb, 'a', encoding='utf-8') as f:
                f.write(line)
        except Exception:
            pass


# ------------------------------------------------------------------------------------------ launch
def describe_launch(inp):
    """what is being launched: tool, name, description, text for id matching, resume id, fresh-run flag"""
    tool = inp.get('tool_name')
    ti = inp.get('tool_input')
    if not isinstance(ti, dict):
        raise ValueError('tool_input missing or not an object')
    if tool in AGENT_TOOLS:
        desc = str(ti.get('description') or '')
        prompt = str(ti.get('prompt') or '')
        return {'tool': tool, 'name': desc, 'description': desc, 'text': desc + '\n' + prompt,
                'subagent_type': ti.get('subagent_type'), 'background': bool(ti.get('run_in_background')),
                'resume': None, 'fresh': None, 'declared_extra': set(), 'src': None}
    script = ti.get('script')
    src = None
    if isinstance(script, str) and script.strip():
        src = script
    elif ti.get('scriptPath'):
        sp = Path(str(ti['scriptPath']))
        if not sp.is_absolute() and inp.get('cwd'):
            sp = Path(inp['cwd']) / sp
        src = sp.read_text(encoding='utf-8', errors='replace')   # unreadable -> internal error -> fail open
    if src is None:
        raise ValueError('Workflow call without script or scriptPath')
    name, desc = parse_meta(src)
    if name is None and desc is None:
        desc = src[:3000]        # no meta block: match ids against the script head
    args = ti.get('args') if isinstance(ti.get('args'), dict) else {}
    fresh = None
    if desc and FRESH_RE.search(desc):
        fresh = desc[FRESH_RE.search(desc).start():][:200]
    elif args.get('fresh_run_reason'):
        fresh = 'args.fresh_run_reason: ' + str(args['fresh_run_reason'])[:200]
    extra = ids_in(str(args.get('task') or ''))
    return {'tool': tool, 'name': name or '', 'description': desc or '',
            'text': (name or '') + '\n' + (desc or ''), 'resume': ti.get('resumeFromRunId') or None,
            'fresh': fresh, 'script_path': ti.get('scriptPath'), 'declared_extra': extra, 'src': src}


# ------------------------------------------------------------------------------------------ session facts
def session_id_of(inp):
    sid = inp.get('session_id')
    if not sid and inp.get('transcript_path'):
        sid = Path(str(inp['transcript_path'])).stem
    if not sid or not re.fullmatch(r'[A-Za-z0-9._-]+', str(sid)):
        raise ValueError('no usable session_id in the hook input')
    return str(sid)


def session_dirs(inp):
    sid = session_id_of(inp)
    return [p for p in projects_dir().glob('*/' + sid) if p.is_dir()]


def _recent(sd, now):
    for q in (sd, sd / 'subagents', sd / 'subagents' / 'workflows', sd / 'workflows'):
        try:
            if now - q.stat().st_mtime <= SESSION_RECENT_S:
                return True
        except OSError:
            pass
    return False


def other_sessions(own_sid, now):
    """{sid: [dirs]} of every OTHER in-scope session folder with activity in the last 24 h"""
    rx = scope_re()
    out = {}
    try:
        slugs = [e for e in os.scandir(projects_dir()) if e.is_dir()]
    except OSError:
        return out
    for s in slugs:
        if rx is not None and not rx.search(s.name):
            continue
        try:
            subs = [e for e in os.scandir(s.path) if e.is_dir() and e.name != own_sid]
        except OSError:
            continue
        for e in subs:
            p = Path(e.path)
            if _recent(p, now):
                out.setdefault(e.name, []).append(p)
    return out


def _run_last_activity(run_dir, journal):
    best = journal.stat().st_mtime
    try:
        with os.scandir(run_dir) as it:
            for e in it:
                try:
                    best = max(best, e.stat().st_mtime)
                except OSError:
                    pass
    except OSError:
        pass
    return best


def _journal_final(journal):
    """a workflow-level final line, if the harness ever writes one (it did not on 2026-09-29)"""
    try:
        lines = journal.read_text(encoding='utf-8', errors='replace').splitlines()
    except OSError:
        return False
    for raw in reversed(lines[-20:]):
        try:
            d = json.loads(raw)
        except ValueError:
            continue
        t = d.get('type')
        if t in ('workflow_result', 'completed', 'finished', 'killed', 'failed', 'workflow_end'):
            return True
        if t == 'result' and not d.get('agentId') and not d.get('key'):
            return True
    return False


def _record(path):
    """(status, workflowName, startTime s) of a run record; unreadable -> ('unreadable', None, None)"""
    try:
        with open(path, encoding='utf-8') as f:
            d = json.load(f)
    except Exception:
        return 'unreadable', None, None
    st = d.get('startTime')
    try:
        st = float(st) / 1000.0 if st is not None else None
    except (TypeError, ValueError):
        st = None
    return str(d.get('status') or 'unknown'), d.get('workflowName'), st


_RUNS_CACHE = {}


def workflow_runs(sdirs, now):
    """every run of the session: {rid: {name, started, last, state, status, script}} (one scan per evaluation)"""
    key = (tuple(str(p) for p in sdirs), now)
    if key not in _RUNS_CACHE:
        if len(_RUNS_CACHE) > 16:
            _RUNS_CACHE.clear()
        _RUNS_CACHE[key] = _scan_runs(sdirs, now)
    return _RUNS_CACHE[key]


def _scan_runs(sdirs, now):
    records, scripts = {}, {}
    for sd in sdirs:
        wdir = sd / 'workflows'
        for p in wdir.glob('wf_*.json'):
            records[p.stem] = p
        for p in (wdir / 'scripts').glob('*-wf_*.js'):
            m = SCRIPT_RE.match(p.name)
            if m:
                try:
                    scripts[m.group('rid')] = (m.group('name'), p.stat().st_mtime, p)
                except OSError:
                    pass
    runs = {}
    for sd in sdirs:
        for j in (sd / 'subagents' / 'workflows').glob('wf_*/journal.jsonl'):
            rid = j.parent.name
            name, started, sp = scripts.get(rid, (None, None, None))
            last = _run_last_activity(j.parent, j)
            if started is None:
                started = j.stat().st_ctime
            runs[rid] = {'name': name, 'started': started, 'last': last, 'state': None, 'status': None,
                         'from_script': name is not None, 'script': sp}
    for rid, (name, started, sp) in scripts.items():      # a script copy with no journal yet
        runs.setdefault(rid, {'name': name, 'started': started, 'last': started, 'state': None, 'status': None,
                              'from_script': True, 'script': sp})
    for rid, r in runs.items():
        if rid in records:
            if now - r['last'] > STALE_S and now - r['started'] > STALE_S:
                r['state'], r['status'] = 'finished', 'record'          # old: no need to parse the record
            else:
                st, wname, t0 = _record(records[rid])
                r['status'] = st
                r['state'] = 'running' if st in RUNNING_STATUSES and now - r['last'] <= STALE_S else 'finished'
                r['name'] = r['name'] or wname
                if t0 and not r.get('from_script'):
                    r['started'] = t0
        elif now - r['last'] > STALE_S:
            r['state'], r['status'] = 'finished', 'stale>6h'
        else:
            j = next((sd / 'subagents' / 'workflows' / rid / 'journal.jsonl' for sd in sdirs
                      if (sd / 'subagents' / 'workflows' / rid / 'journal.jsonl').exists()), None)
            if j is not None and _journal_final(j):
                r['state'], r['status'] = 'finished', 'journal-final'
            else:
                r['state'], r['status'] = 'running', 'no-record'
    return runs


def _turn_ended(transcript):
    """Recognize end_turn and a successful terminal SubagentHandback receipt.

    Newer transcripts finish with a user tool result, not an assistant end_turn.
    Require the terminal marker, matching tool call and explicit success; an
    ordinary result, failed handback or later follow-up still occupies a slot.
    """
    with open(transcript, 'rb') as f:
        f.seek(0, 2)
        size = f.tell()
        f.seek(max(0, size - 262144))
        data = f.read()
    rows = []
    for raw in data.split(b'\n'):
        raw = raw.strip()
        if not raw:
            continue
        try:
            d = json.loads(raw)
        except ValueError:
            continue
        if isinstance(d, dict):
            rows.append(d)
    for index in range(len(rows) - 1, -1, -1):
        d = rows[index]
        t = d.get('type')
        if t == 'assistant':
            msg = d.get('message') if isinstance(d.get('message'), dict) else {}
            return msg.get('stop_reason') == 'end_turn'
        if t == 'user':
            if d.get('toolEndsTurn') is True:
                msg = d.get('message') or {}
                content = msg.get('content') or []
                if not isinstance(content, list):
                    return False
                for result in content:
                    if not isinstance(result, dict) or result.get('type') != 'tool_result' or result.get('is_error'):
                        continue
                    tool_id = result.get('tool_use_id')
                    if not tool_id:
                        continue
                    called = any(
                        isinstance(item, dict) and item.get('type') == 'tool_use'
                        and item.get('id') == tool_id and item.get('name') == 'SubagentHandback'
                        for row in rows[:index] if row.get('type') == 'assistant'
                        for item in (row.get('message') or {}).get('content', [])
                    )
                    if not called:
                        continue
                    payload = result.get('content')
                    texts = [payload] if isinstance(payload, str) else [
                        item.get('text', '') for item in payload or []
                        if isinstance(item, dict) and item.get('type') == 'text'
                    ]
                    for text in texts:
                        try:
                            receipt = json.loads(text)
                        except (ValueError, TypeError):
                            continue
                        if isinstance(receipt, dict) and receipt.get('success') is True:
                            return True
            return False
    return False


def session_agents(sdirs, now):
    """top-level agents of a session: [{id, description, shape, tool_use_id, created, last, running}].
    Background AND foreground agents count while running (owner decision 2026-09-29: parallel foreground calls
    in one message are concurrent jobs too; a sequential foreground call has ended before the next launch)."""
    out = []
    for sd in sdirs:
        for meta in (sd / 'subagents').glob('agent-*.meta.json'):
            tr = meta.with_name(meta.name[:-len('.meta.json')] + '.jsonl')
            try:
                created = meta.stat().st_mtime
                mt = tr.stat().st_mtime if tr.exists() else created
            except OSError:
                continue
            fresh = now - created <= RES_TTL_S + MATCH_SLACK_S      # may still have to meet a reservation
            if now - mt > BG_IDLE_S and not fresh:
                continue
            try:
                m = json.loads(meta.read_text(encoding='utf-8'))
            except Exception:
                continue
            running = now - mt <= BG_IDLE_S
            if running:
                try:
                    if tr.exists() and _turn_ended(tr):
                        running = False
                except OSError:
                    pass
            out.append({'id': meta.name.split('.')[0], 'description': m.get('description') or '',
                        'shape': m.get('requestShape') or '?', 'tool_use_id': m.get('toolUseId'),
                        'created': created, 'last': mt, 'running': running})
    return out


# ------------------------------------------------------------------------------------------ ledger
class LedgerLock:
    """one evaluator of rule A at a time (O_CREAT|O_EXCL, the tasklib/inbox lock pattern)"""

    def __init__(self, d):
        self.path = Path(d) / '.lock'

    def __enter__(self):
        t0 = time.time()
        self.path.parent.mkdir(parents=True, exist_ok=True)
        while True:
            try:
                fd = os.open(str(self.path), os.O_CREAT | os.O_EXCL | os.O_WRONLY)
                os.write(fd, ('%d %.0f' % (os.getpid(), time.time())).encode())
                os.close(fd)
                return self
            except FileExistsError:
                try:
                    if time.time() - self.path.stat().st_mtime > LOCK_STALE_S:
                        self.path.unlink()
                        continue
                except FileNotFoundError:
                    continue
                except OSError:
                    pass
                if time.time() - t0 > LOCK_WAIT_S:
                    raise TimeoutError('launch ledger locked (%s)' % self.path)
                time.sleep(0.01)

    def __exit__(self, *exc):
        try:
            self.path.unlink()
        except OSError:
            pass


def ledger_load():
    p = ledger_dir() / 'ledger.json'
    try:
        with open(p, encoding='utf-8') as f:
            d = json.load(f)
    except FileNotFoundError:
        return []
    items = d.get('entries') if isinstance(d, dict) else None
    if not isinstance(items, list):
        raise ValueError('ledger.json has no entries list')
    return [e for e in items if isinstance(e, dict) and isinstance(e.get('t'), (int, float))]


def ledger_save(entries):
    d = ledger_dir()
    d.mkdir(parents=True, exist_ok=True)
    tmp = d / ('.ledger.%d.tmp' % os.getpid())
    tmp.write_text(json.dumps({'entries': entries}, ensure_ascii=False, indent=0) + '\n', encoding='utf-8')
    for _ in range(30):
        try:
            os.replace(tmp, d / 'ledger.json')
            return
        except PermissionError:
            time.sleep(0.02)
    os.replace(tmp, d / 'ledger.json')


def _met(e, runs, agents):
    """True when the reservation's real run / agent exists now"""
    since = e['t'] - MATCH_SLACK_S
    if e.get('tool') == 'Workflow':
        return any(r['name'] and norm_name(r['name']) == e.get('norm') and r['started'] >= since for r in runs)
    if e.get('tool_use_id'):
        return any(a['tool_use_id'] == e['tool_use_id'] for a in agents)
    return any(a['description'] == e.get('description') and a['created'] >= since for a in agents)


def live_entries(entries, runs, agents, now):
    """drop expired entries and reservations their real run already meets (the run itself is counted)"""
    keep = []
    for e in entries:
        if now > e['t'] + float(e.get('ttl') or RES_TTL_S):
            continue
        if e.get('kind') == 'reservation' and _met(e, runs, agents):
            continue
        keep.append(e)
    return keep


# ------------------------------------------------------------------------------------------ tasks
def _band(t):
    p = t.get('prio') if isinstance(t.get('prio'), dict) else {}
    o = t.get('owner') if isinstance(t.get('owner'), dict) else {}
    return p.get('eff_band') or (o.get('prio') if o.get('prio') in ('P0', 'P1', 'P2') else None) \
        or p.get('band') or 'P2'


def _title(t):
    o = t.get('owner') if isinstance(t.get('owner'), dict) else {}
    return str(o.get('title') or t.get('title') or '')


def _held(t):
    o = t.get('owner') if isinstance(t.get('owner'), dict) else {}
    h = o.get('hold')
    return isinstance(h, dict) and bool(h.get('on'))


def p0_state(path):
    with open(path, encoding='utf-8') as f:
        d = json.load(f)
    T = d.get('tasks') if isinstance(d, dict) else None
    items = T.values() if isinstance(T, dict) else (T if isinstance(T, list) else [])
    open_bugs, running = [], []
    for t in items:
        if not isinstance(t, dict) or _band(t) != 'P0' or not t.get('id'):
            continue
        st = t.get('status')
        if t.get('type') == 'bug' and st in OPEN_P0_STATUSES and not _held(t):
            open_bugs.append({'id': t['id'], 'title': _title(t), 'status': st})
        elif st in RUNNING_TASK_STATUSES:
            running.append({'id': t['id'], 'title': _title(t), 'status': st})
    return open_bugs, running


# ------------------------------------------------------------------------------------------ rules
def _ago(now, ts):
    m = int(max(0, now - ts) // 60)
    return '%d min' % m if m < 120 else '%.1f h' % (m / 60)


def a_exemption(launch, inp):
    if launch['tool'] in AGENT_TOOLS and LOOKUP_RE.search(launch['description']):
        return 'read-only lookup'
    if inp.get('agent_id'):
        return 'inside a running job (agent %s)' % str(inp['agent_id'])[:40]
    return None


def jobs_now(own_sid, own_dirs, now):
    """(workflows, agents, all_runs, all_agents): running jobs in every in-scope session, and the raw scans the
    ledger needs to meet reservations"""
    groups = dict(other_sessions(own_sid, now))
    if own_sid is not None:
        groups[own_sid] = list(own_dirs or [])
    wfs, ags, all_runs, all_agents = [], [], [], []
    for sid, dirs in groups.items():
        tag = 'this session' if sid == own_sid else 'session ' + sid[:8]
        for rid, r in workflow_runs(dirs, now).items():
            all_runs.append(r)
            if r['state'] == 'running':
                wfs.append(dict(r, rid=rid, where=tag))
        for a in session_agents(dirs, now):
            all_agents.append(a)
            if a['running']:
                ags.append(dict(a, where=tag))
    wfs.sort(key=lambda r: r['started'])
    return wfs, ags, all_runs, all_agents


def rule_a(launch, ledger, wfs, ags, now):
    n, c = len(wfs) + len(ags) + len(ledger), cap()
    facts = {'running_workflows': [r['rid'] for r in wfs], 'running_agents': [a['id'] for a in ags],
             'pending': [e.get('id') for e in ledger], 'cap': c}
    if n < c:
        return None, facts
    lines = ['Rule A (cap %d): %d jobs already run:' % (c, n)]
    for r in wfs:
        lines.append("  - workflow %s '%s' (%s, started %s ago, last activity %s ago)"
                     % (r['rid'], r['name'] or '?', r['where'], _ago(now, r['started']), _ago(now, r['last'])))
    for a in ags:
        lines.append("  - %s agent %s '%s' (%s, last activity %s ago)"
                     % (a['shape'], a['id'], a['description'], a['where'], _ago(now, a['last'])))
    for e in ledger:
        what = 'claim by %s' % e.get('by') if e.get('kind') == 'claim' else 'launch just allowed, starting'
        lines.append("  - %s: %s '%s' (%s ago)" % (what, e.get('tool') or 'job', e.get('name') or '?',
                                                  _ago(now, e['t'])))
    lines.append('  Wait for one to finish, or hand the detail to a running job as a task note '
                 '(tasks.py note <ID> "...") instead of a new launch.')
    return '\n'.join(lines), facts


def rule_b(launch):
    open_bugs, running = p0_state(tasks_path())
    facts = {'open_p0_bugs': [t['id'] for t in open_bugs], 'running_p0': [t['id'] for t in running]}
    if not open_bugs:
        return None, facts
    declared = declared_in(launch['text']) | set(launch.get('declared_extra') or ())
    allowed = {k for t in open_bugs + running for k in ids_in(t['id'])}
    hit = sorted('%s-%03d' % k for k in declared & allowed)
    if hit:
        facts['declared'] = hit
        return None, facts
    where = 'description or prompt' if launch['tool'] in AGENT_TOOLS else 'meta description (or args.task)'
    lines = ['Rule B (P0 first): %d open P0 bugs nobody holds; a launch must DECLARE one of them (or a running '
             'P0 task) in its %s as `task: <ID>`:' % (len(open_bugs), where)]
    for t in open_bugs[:P0_LIST_MAX]:
        lines.append('  - %s [%s] %s' % (t['id'], t['status'], t['title'][:90]))
    if len(open_bugs) > P0_LIST_MAX:
        lines.append('  - ... and %d more (tasks.py list)' % (len(open_bugs) - P0_LIST_MAX))
    if running:
        lines.append('  Running P0 tasks that also qualify: ' + ', '.join(t['id'] for t in running))
    mentioned = sorted('%s-%03d' % k for k in ids_in(launch['text']) & allowed)
    if mentioned:
        lines.append('  %s is mentioned but not declared; a mention does not count.' % ', '.join(mentioned))
    return '\n'.join(lines), facts


def rule_c(launch, sdirs, now):
    if launch['tool'] != 'Workflow' or launch['resume'] or not launch['name']:
        return None, {}
    key = norm_name(launch['name'])
    runs = workflow_runs(sdirs, now)
    recent = sorted(((rid, r) for rid, r in runs.items() if now - r['started'] <= RELAUNCH_S),
                    key=lambda x: -x[1]['started'])
    same = [(rid, r, None) for rid, r in recent if r['name'] and norm_name(r['name']) == key]
    if not same and launch.get('src'):
        mine = body_lines(launch['src'])
        for rid, r in recent[:SIMILAR_MAX_RUNS]:
            if not r.get('script'):
                continue
            try:
                s = similarity(mine, body_lines(Path(r['script']).read_text(encoding='utf-8', errors='replace')))
            except OSError:
                continue
            if s >= SIMILAR:
                same.append((rid, r, s))
    facts = {'same_name_runs': [rid for rid, _r, s in same if s is None],
             'similar_runs': [[rid, round(s, 2)] for rid, _r, s in same if s is not None]}
    if not same:
        return None, facts
    if launch['fresh']:
        facts['fresh_run'] = launch['fresh']
        return None, facts
    rid, r, s = same[0]
    state = 'still RUNNING' if r['state'] == 'running' else (r['status'] or r['state'])
    how = ('already ran in this session' if s is None else
           "is a renamed copy (%d%% of the script lines) of '%s', which ran in this session" % (s * 100, r['name']))
    msg = ("Rule C (resume, not relaunch): workflow '%s' %s %s ago as %s (%s)."
           "\n  Resume it with resumeFromRunId: '%s', or give the running job a task note (tasks.py note <ID> "
           "\"...\"). A deliberate new run needs 'fresh-run: <reason>' in its meta description."
           % (launch['name'], how, _ago(now, r['started']), rid, state, rid))
    return msg, facts


# ------------------------------------------------------------------------------------------ evaluate
def _reservation(launch, inp, now):
    return {'id': 'r-' + uuid.uuid4().hex[:10], 'kind': 'reservation', 'tool': launch['tool'],
            'name': (launch.get('name') or '')[:120], 'norm': norm_name(launch.get('name')),
            'description': (launch.get('description') or '')[:300], 'tool_use_id': inp.get('tool_use_id'),
            'session_id': inp.get('session_id'), 't': now, 'ttl': RES_TTL_S}


def evaluate(inp, now=None, reserve=False):
    """reserve=True (hook mode): rule A is evaluated under the ledger lock and an allowed counted launch writes
    its reservation before the lock is released. reserve=False (tests, --dry-run): read-only."""
    now = time.time() if now is None else now
    res = {'decision': 'allow', 'violations': [], 'errors': [], 'facts': {}}
    tool = inp.get('tool_name')
    if tool not in GATED_TOOLS:
        res['decision'] = 'skip'
        return res
    launch = describe_launch(inp)
    res['launch'] = {k: launch.get(k) for k in ('tool', 'name', 'resume', 'fresh', 'subagent_type', 'background')}
    res['launch']['description'] = (launch.get('description') or '')[:300]
    sid, sdirs = None, None
    try:
        sid = session_id_of(inp)
        sdirs = session_dirs(inp)
    except Exception as e:
        res['errors'].append('session: %s: %s' % (type(e).__name__, e))

    def run_rule(rule, fn):
        try:
            msg, facts = fn()
            res['facts'][rule] = facts
            if msg:
                res['violations'].append({'rule': rule, 'text': msg})
        except Exception as e:   # this rule fails open; the others still count
            res['errors'].append('rule %s: %s: %s' % (rule, type(e).__name__, e))

    run_rule('B', lambda: rule_b(launch))
    run_rule('C', lambda: rule_c(launch, sdirs, now) if sdirs is not None else (None, {'skipped': 'no session'}))
    ov = override_source()
    exempt = a_exemption(launch, inp)
    if exempt:
        res['facts']['A'] = {'exempt': exempt}
    elif sdirs is None:
        res['facts']['A'] = {'skipped': 'no session'}
    else:
        def a_and_reserve(locked):
            wfs, ags, all_runs, all_agents = jobs_now(sid, sdirs, now)
            try:
                raw = ledger_load()
            except Exception as e:
                res['errors'].append('ledger: %s: %s (ignored)' % (type(e).__name__, e))
                raw = []
            ledger = live_entries(raw, all_runs, all_agents, now)
            run_rule('A', lambda: rule_a(launch, ledger, wfs, ags, now))
            if locked:
                proceeds = ov is not None or not res['violations']
                if proceeds:
                    r = _reservation(launch, inp, now)
                    ledger = ledger + [r]
                    res['reserved'] = r['id']
                if proceeds or len(ledger) != len(raw):
                    ledger_save(ledger)
        if reserve:
            try:
                with LedgerLock(ledger_dir()):
                    a_and_reserve(True)
            except Exception as e:           # lock timeout or ledger write failure: fail open, A read-only
                res['errors'].append('ledger: %s: %s' % (type(e).__name__, e))
                if 'A' not in res['facts']:
                    a_and_reserve(False)
        else:
            a_and_reserve(False)
    order = {'A': 0, 'B': 1, 'C': 2}
    res['violations'].sort(key=lambda v: order[v['rule']])
    if res['violations']:
        res['decision'] = 'deny'
    if ov:
        res['override'] = ov
        res['decision'] = 'override'
    return res


def deny_reason(res):
    name = (res.get('launch') or {}).get('name') or '?'
    parts = ["LAUNCH GATE refused '%s' (owner rule 2026-09-29: few jobs at a time, open P0 bugs first, "
             "resume instead of relaunch)." % name[:80]]
    parts += [v['text'] for v in res['violations']]
    parts.append('Do not work around the gate: fix the launch, or report the block to the owner '
                 '(only he switches the gate off).')
    return '\n'.join(parts)


def _log_entry(inp, res, ms):
    e = {'decision': res['decision'], 'rules': [v['rule'] for v in res['violations']],
         'launch': res.get('launch'), 'session_id': inp.get('session_id'), 'agent_id': inp.get('agent_id'),
         'tool_use_id': inp.get('tool_use_id'), 'ms': round(ms, 1)}
    if res.get('reserved'):
        e['reserved'] = res['reserved']
    if res['violations']:
        e['reasons'] = [v['text'] for v in res['violations']]
    if res.get('override'):
        e['override'] = res['override']
    if res['errors']:
        e['errors'] = res['errors']
    e['facts'] = res.get('facts')
    return e


# ------------------------------------------------------------------------------------------ claims (non-Claude agents)
def claim(name, by, task=None, ttl_min=None, now=None):
    """a job slot for an agent the hook cannot see (Codex ...): rules A (every in-scope session) and B.
    -> (exit code, result dict)"""
    now = time.time() if now is None else now
    launch = {'tool': 'Claim', 'name': name, 'description': name,
              'text': name + ('\ntask: ' + task if task else ''), 'declared_extra': set()}
    res = {'decision': 'allow', 'violations': [], 'errors': [], 'facts': {}}
    try:
        msg, facts = rule_b(launch)
        res['facts']['B'] = facts
        if msg:
            res['violations'].append({'rule': 'B', 'text': msg})
    except Exception as e:
        res['errors'].append('rule B: %s: %s' % (type(e).__name__, e))
    ttl = max(60, int(float(ttl_min) * 60)) if ttl_min else CLAIM_TTL_S
    try:
        with LedgerLock(ledger_dir()):
            wfs, ags, all_runs, all_agents = jobs_now(None, None, now)
            raw = ledger_load()
            ledger = live_entries(raw, all_runs, all_agents, now)
            msg, facts = rule_a(launch, ledger, wfs, ags, now)
            res['facts']['A'] = facts
            if msg:
                res['violations'].insert(0, {'rule': 'A', 'text': msg})
            if not res['violations'] or override_source():
                e = {'id': 'c-' + uuid.uuid4().hex[:10], 'kind': 'claim', 'tool': 'Claim', 'name': name[:120],
                     'norm': norm_name(name), 'description': name[:300], 'by': by, 'task': task, 't': now,
                     'ttl': ttl}
                ledger.append(e)
                res['claim_id'] = e['id']
                res['expires'] = utc_iso(now + ttl)
            ledger_save(ledger)
    except Exception as e:                   # fail open, like the hook
        res['errors'].append('ledger: %s: %s' % (type(e).__name__, e))
    if res['violations'] and not res.get('claim_id'):
        res['decision'] = 'deny'
        res['reason'] = deny_reason({'launch': {'name': name}, 'violations': res['violations']})
    elif res['violations']:
        res['decision'] = 'override'
        res['override'] = override_source()
    log({'decision': res['decision'], 'rules': [v['rule'] for v in res['violations']], 'claim': res.get('claim_id'),
         'launch': {'tool': 'Claim', 'name': name, 'by': by, 'task': task}, 'errors': res['errors'] or None,
         'facts': res['facts']})
    return (3 if res['decision'] == 'deny' else 0), res


def claim_update(cid, release=False, now=None):
    now = time.time() if now is None else now
    with LedgerLock(ledger_dir()):
        entries = ledger_load()
        hit = [e for e in entries if e.get('id') == cid]
        if not hit:
            return 3, {'error': 'no live claim %s' % cid}
        if release:
            entries = [e for e in entries if e.get('id') != cid]
        else:
            hit[0]['t'] = now
        ledger_save(entries)
    log({'decision': 'release' if release else 'renew', 'claim': cid})
    return 0, {'claim_id': cid, 'released' if release else 'renewed': True}


def _arg(argv, flag):
    if flag in argv:
        i = argv.index(flag)
        return argv[i + 1] if i + 1 < len(argv) else ''
    return None


def claim_cli(argv):
    try:
        if '--release' in argv or '--renew' in argv:
            rel = '--release' in argv
            rc, out = claim_update(_arg(argv, '--release' if rel else '--renew'), release=rel)
        else:
            name = (_arg(argv, '--claim') or '').strip()
            by = (_arg(argv, '--by') or '').strip()
            if not name or not by:
                rc, out = 2, {'error': 'usage: --claim "<job name>" --by <agent> [--task KTC-155] [--ttl-min 60]'}
            else:
                rc, out = claim(name, by, task=_arg(argv, '--task'), ttl_min=_arg(argv, '--ttl-min'))
    except Exception as e:
        rc, out = 0, {'decision': 'error-allow', 'error': '%s: %s' % (type(e).__name__, e)}
    sys.stdout.write(json.dumps(out, ensure_ascii=True, default=str) + '\n')
    return rc


# ------------------------------------------------------------------------------------------ main
def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    if any(a in argv for a in ('--claim', '--renew', '--release')):
        return claim_cli(argv)
    dry = '--dry-run' in argv
    t0 = time.perf_counter()
    inp = {}
    try:
        raw = sys.stdin.buffer.read()
        try:
            inp = json.loads(raw.decode('utf-8-sig') or 'null')
        except ValueError as e:
            if not dry:
                log({'decision': 'error-allow', 'errors': ['malformed hook input: %s' % e],
                     'input_head': raw[:200].decode('utf-8', 'replace')})
            return 0
        if not isinstance(inp, dict):
            if not dry:
                log({'decision': 'error-allow', 'errors': ['hook input is not an object']})
            return 0
        res = evaluate(inp, reserve=not dry)
        ms = (time.perf_counter() - t0) * 1000
        if dry:
            res['ms'] = round(ms, 1)
            if res['decision'] == 'deny':
                res['reason'] = deny_reason(res)
            sys.stdout.write(json.dumps(res, indent=1, ensure_ascii=True, default=str) + '\n')
            return 0
        if res['decision'] == 'skip':
            return 0
        log(_log_entry(inp, res, ms))
        if res['decision'] == 'deny':
            out = {'hookSpecificOutput': {'hookEventName': 'PreToolUse', 'permissionDecision': 'deny',
                                          'permissionDecisionReason': deny_reason(res)}}
            sys.stdout.write(json.dumps(out, ensure_ascii=True))
            sys.stdout.flush()
        return 0
    except Exception as e:      # fail open
        if not dry:
            log({'decision': 'error-allow', 'errors': ['internal: %s: %s' % (type(e).__name__, e)],
                 'tool': inp.get('tool_name') if isinstance(inp, dict) else None,
                 'ms': round((time.perf_counter() - t0) * 1000, 1)})
        else:
            sys.stdout.write(json.dumps({'decision': 'error-allow', 'error': '%s: %s' % (type(e).__name__, e)}) + '\n')
        return 0


if __name__ == '__main__':
    sys.exit(main())
