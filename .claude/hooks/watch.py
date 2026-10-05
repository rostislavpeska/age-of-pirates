#!/usr/bin/env python3
"""Background watchdogs that end with their job (incident INC-027, task KTC-164).

INC-027 (owner, 2026-09-30 10:52: "You still have running tasks!!!!!!!!! Why????!!!!"): the Blender MCP port watchdog

    while netstat -ano 2>/dev/null | grep -q ":9876 .*LISTENING"; do sleep 20; done; echo "... 9876 DOWN"

ran as a Claude background Bash task 32 hours after the live Blender work had ended (the port never dropped, so the
loop never ended). Its Monitor twin (the same netstat poll in `while true`, timeout_ms 1800000) was re-armed six times.
A raw loop has no end tied to its job. This wrapper runs the loop itself and ends it on the FIRST of:

    ttl      --ttl since start (default 3h, max 12h)
    task     the task left the live states (done / rejected / superseded / on_hold), vanished from the store, or the
             lease it held at start was released or handed to another job
    run      --run given and no longer bound in <tasks>/inbox/runs.json (tasks.py bind-run ... --unbind, 24 h expiry)
    session  the Claude Code process that started it is gone (CLAUDE_PID, else the nearest claude/codex ancestor;
             --parent-pid overrides, 0 = none)
    until    --until-port-down PORT: the port stopped LISTENING (reported, then the watch ends);
             --until-file PATH: the file exists
    stop     `watch.py stop <id>` or `watch.py stop --stale` (a stop file, then a kill after a grace)

It prints only state changes, one line each: the start, every change of a probe's state, the end with its reason. Run
as a Monitor command or a background Bash task, each line is one event.

    python .claude/hooks/watch.py start --task KTC-164 [--run wf_x] [--ttl 3h] [--every 20]
                                        [--until-port-down 9876 | --until-file PATH] [-- <check cmd>]
    python .claude/hooks/watch.py list [--json]
    python .claude/hooks/watch.py stop <id> | --stale

The check command runs every --every seconds (one argument = a Git Bash command line, several = an argv), bounded by
a timeout; its state is ok / fail rc=N / timeout. The R9 port watchdog needs no command: --until-port-down 9876.

Registry: <tasks>/watch/<id>.json (<tasks> = scripts/tools/local_env.py tasks_dir(): AOP_TASKS_DIR from the environment
or config/aop.local.env) = {id, task, run, pid, created, started, ttl_s, every_s, until, cmd, parent, session,
lease_job, last_tick, state}; written at start, removed on exit. A hard kill leaves it behind: readers see the dead pid
(list: DEAD; stop --stale and turn_end_guard.py remove it). Readers judge an entry with stale_reason(): the same end
conditions plus a dead pid. Refusals exit 2 (no --task, unknown or ended task, unbound run, ttl > 12h, nothing to
watch). Standard library only; process facts through ctypes on Windows (Toolhelp32, GetProcessTimes,
NtQueryInformationProcess), /proc elsewhere. Every start, end, stop and refusal is one line in harness_log.jsonl.
"""
import argparse
import json
import os
import re
import shutil
import signal
import subprocess
import sys
import time
import uuid
from datetime import datetime, timezone
from pathlib import Path

_TOOLS = str(Path(__file__).resolve().parents[2] / 'scripts' / 'tools')
TTL_DEFAULT_S = 3 * 3600
TTL_MAX_S = 12 * 3600
EVERY_DEFAULT_S = 20.0
EVERY_MIN_S = 1.0
TICK_S = 1.0                  # the stop file and the TTL are checked this often
LIFE_EVERY_S = 5.0            # task / run / session: this often (stat-cached; the store is re-parsed only after a write)
CHECK_TIMEOUT_MAX_S = 120.0   # one check command never runs longer than this (nor longer than max(every, 5) s)
HEARTBEAT_S = 60.0            # the registry's last_tick is refreshed this often and on every state change
STOP_GRACE_S = 8.0            # watch.py stop: the stop file first, a kill after this
TERMINAL = {'done', 'rejected', 'superseded'}      # tasklib.TERMINAL
PAUSED = {'on_hold'}
TASK_RE = re.compile(r'^[A-Za-z]{2,10}-\d{1,5}$')
RUN_RE = re.compile(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,79}$')      # inbox.check_id
ID_RE = re.compile(r'^w-[0-9a-f]{6,12}$')
AGENT_EXE = re.compile(r'^(?:claude|codex|gemini)(?:\.exe)?$', re.I)
UNKNOWN = object()            # the store could not be read right now: no verdict


class Refused(Exception):
    """a refused start (exit 2); the message says why and what to do"""


# ------------------------------------------------------------------------------------------ paths, log, time
def tasks_dir():
    if _TOOLS not in sys.path:
        sys.path.append(_TOOLS)
    import local_env
    return Path(local_env.tasks_dir())


def watch_dir():
    return tasks_dir() / 'watch'


def log_path():
    return Path(os.environ.get('AOP_HARNESS_LOG') or (tasks_dir() / 'harness_log.jsonl'))


def utc_iso(ts=None):
    return datetime.fromtimestamp(time.time() if ts is None else ts, timezone.utc).isoformat(timespec='seconds')


def log(rec, hook='watch'):
    try:
        p = log_path()
        p.parent.mkdir(parents=True, exist_ok=True)
        with open(p, 'a', encoding='utf-8', newline='\n') as f:
            f.write(json.dumps({'t': utc_iso(), 'hook': hook, **rec}, ensure_ascii=False, default=str) + '\n')
    except Exception:  # noqa: BLE001 - the log never breaks a watch
        pass


def parse_dur(s):
    """'3h', '90m', '1h30m', '45s', '2.5h' or plain seconds -> seconds"""
    s = str(s or '').strip().lower()
    if re.fullmatch(r'\d+(?:\.\d+)?', s):
        return float(s)
    m = re.fullmatch(r'(?:(\d+(?:\.\d+)?)h)?(?:(\d+(?:\.\d+)?)m(?:in)?)?(?:(\d+(?:\.\d+)?)s)?', s.replace(' ', ''))
    if not s or not m or not any(m.groups()):
        raise ValueError(f'bad duration {s!r}: 3h, 90m, 1h30m, 45s or seconds')
    h, mi, se = (float(x) if x else 0.0 for x in m.groups())
    return h * 3600 + mi * 60 + se


def fmt_dur(sec):
    sec = int(max(0, sec))
    h, r = divmod(sec, 3600)
    m, s = divmod(r, 60)
    return f'{h}h{m:02d}m' if h else (f'{m}m{s:02d}s' if m else f'{s}s')


def local_hms(ts=None):
    return time.strftime('%H:%M:%S', time.localtime(time.time() if ts is None else ts))


# ------------------------------------------------------------------------------------------ processes
if os.name == 'nt':
    import ctypes
    from ctypes import wintypes

    _k32 = ctypes.WinDLL('kernel32', use_last_error=True)
    _nt = ctypes.WinDLL('ntdll')
    _H = wintypes.HANDLE

    class _PE32(ctypes.Structure):
        _fields_ = [('dwSize', wintypes.DWORD), ('cntUsage', wintypes.DWORD), ('th32ProcessID', wintypes.DWORD),
                    ('th32DefaultHeapID', ctypes.c_size_t), ('th32ModuleID', wintypes.DWORD),
                    ('cntThreads', wintypes.DWORD), ('th32ParentProcessID', wintypes.DWORD),
                    ('pcPriClassBase', ctypes.c_long), ('dwFlags', wintypes.DWORD), ('szExeFile', ctypes.c_wchar * 260)]

    class _US(ctypes.Structure):
        _fields_ = [('Length', ctypes.c_ushort), ('MaximumLength', ctypes.c_ushort), ('Buffer', ctypes.c_void_p)]

    _k32.CreateToolhelp32Snapshot.argtypes = [wintypes.DWORD, wintypes.DWORD]
    _k32.CreateToolhelp32Snapshot.restype = _H
    _k32.Process32FirstW.argtypes = [_H, ctypes.POINTER(_PE32)]
    _k32.Process32NextW.argtypes = [_H, ctypes.POINTER(_PE32)]
    _k32.OpenProcess.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
    _k32.OpenProcess.restype = _H
    _k32.CloseHandle.argtypes = [_H]
    _k32.GetProcessTimes.argtypes = [_H] + [ctypes.POINTER(wintypes.FILETIME)] * 4
    _k32.GetExitCodeProcess.argtypes = [_H, ctypes.POINTER(wintypes.DWORD)]
    _nt.NtQueryInformationProcess.argtypes = [_H, ctypes.c_ulong, ctypes.c_void_p, ctypes.c_ulong,
                                              ctypes.POINTER(ctypes.c_ulong)]
    _nt.NtQueryInformationProcess.restype = ctypes.c_long
    _INVALID = ctypes.c_void_p(-1).value
    _QUERY = 0x1000               # PROCESS_QUERY_LIMITED_INFORMATION
    _STILL_ACTIVE = 259

    def proc_table():
        """{pid: (ppid, exe name)} of every process ({} when the snapshot fails)"""
        out = {}
        h = _k32.CreateToolhelp32Snapshot(0x2, 0)
        if not h or h == _INVALID:
            return out
        try:
            e = _PE32()
            e.dwSize = ctypes.sizeof(_PE32)
            ok = _k32.Process32FirstW(h, ctypes.byref(e))
            while ok:
                out[int(e.th32ProcessID)] = (int(e.th32ParentProcessID), e.szExeFile)
                ok = _k32.Process32NextW(h, ctypes.byref(e))
        finally:
            _k32.CloseHandle(h)
        return out

    def _open(pid):
        return _k32.OpenProcess(_QUERY, False, int(pid)) if pid and int(pid) > 0 else None

    def proc_created(pid):
        """the creation time (FILETIME ticks) of a RUNNING process, or None (gone, or not ours to query)"""
        h = _open(pid)
        if not h:
            return None
        try:
            code = wintypes.DWORD()
            if not _k32.GetExitCodeProcess(h, ctypes.byref(code)) or code.value != _STILL_ACTIVE:
                return None
            c, e, k, u = (wintypes.FILETIME() for _ in range(4))
            if not _k32.GetProcessTimes(h, ctypes.byref(c), ctypes.byref(e), ctypes.byref(k), ctypes.byref(u)):
                return None
            return (c.dwHighDateTime << 32) | c.dwLowDateTime
        finally:
            _k32.CloseHandle(h)

    def proc_alive(pid, created=None):
        """pid runs (and is the same process: its creation time equals `created` when given)"""
        h = _open(pid)
        if not h:
            return ctypes.get_last_error() == 5 and created is None      # access denied: it exists
        _k32.CloseHandle(h)
        c = proc_created(pid)
        return c is not None and (created is None or c == created)

    def proc_cmdline(pid):
        """the command line of a process (Windows 8.1+: ProcessCommandLineInformation), or None"""
        h = _open(pid)
        if not h:
            return None
        try:
            need = ctypes.c_ulong(0)
            buf = ctypes.create_string_buffer(512)
            st = _nt.NtQueryInformationProcess(h, 60, buf, len(buf), ctypes.byref(need))
            if st != 0 and need.value > len(buf):
                buf = ctypes.create_string_buffer(need.value)
                st = _nt.NtQueryInformationProcess(h, 60, buf, len(buf), ctypes.byref(need))
            if st != 0:
                return None
            us = _US.from_buffer(buf)
            return ctypes.wstring_at(us.Buffer, us.Length // 2) if us.Buffer and us.Length else ''
        finally:
            _k32.CloseHandle(h)
else:
    def _stat(pid):
        with open(f'/proc/{int(pid)}/stat', encoding='utf-8', errors='replace') as f:
            s = f.read()
        head, _, rest = s.rpartition(')')
        return head.partition('(')[2], rest.split()

    def proc_table():
        out = {}
        try:
            names = os.listdir('/proc')
        except OSError:
            names = []
        for n in names:
            if n.isdigit():
                try:
                    comm, f = _stat(n)
                    out[int(n)] = (int(f[1]), comm)
                except (OSError, IndexError, ValueError):
                    continue
        if not out:                               # no /proc (macOS): ps
            try:
                txt = subprocess.run(['ps', '-A', '-o', 'pid=,ppid=,comm='], capture_output=True, text=True,
                                     timeout=10).stdout
                for ln in txt.splitlines():
                    p = ln.split(None, 2)
                    if len(p) == 3:
                        out[int(p[0])] = (int(p[1]), os.path.basename(p[2]))
            except (OSError, ValueError, subprocess.SubprocessError):
                pass
        return out

    def proc_created(pid):
        try:
            return int(_stat(pid)[1][19])
        except (OSError, IndexError, ValueError):
            try:
                os.kill(int(pid), 0)
                return 0
            except (OSError, ValueError):
                return None

    def proc_alive(pid, created=None):
        try:
            os.kill(int(pid), 0)
        except PermissionError:
            return created is None
        except (OSError, ValueError, TypeError):
            return False
        c = proc_created(pid)
        return c is not None and (created is None or not c or c == created)

    def proc_cmdline(pid):
        try:
            with open(f'/proc/{int(pid)}/cmdline', 'rb') as f:
                return f.read().replace(b'\0', b' ').decode('utf-8', 'replace').strip()
        except OSError:
            return None


def kill_tree(pid):
    """end a process and its children (taskkill /T /F on Windows; the process group elsewhere)"""
    try:
        if os.name == 'nt':
            subprocess.run(['taskkill', '/T', '/F', '/PID', str(int(pid))], capture_output=True, timeout=20)
        else:
            try:
                os.killpg(os.getpgid(int(pid)), signal.SIGKILL)
            except OSError:
                os.kill(int(pid), signal.SIGKILL)
    except (OSError, ValueError, subprocess.SubprocessError):
        pass


def ancestors(pid, table=None):
    """[(pid, exe)] from pid's parent upwards (cycle-safe)"""
    table = proc_table() if table is None else table
    out, seen, p = [], {pid}, (table.get(pid) or (None,))[0]
    while p and p in table and p not in seen:
        seen.add(p)
        out.append((p, table[p][1]))
        p = table[p][0]
    return out


def session_parent(env=None, table=None):
    """the agent process (Claude Code) this watch belongs to: CLAUDE_PID when it runs, else the nearest claude / codex
    ancestor; None = unknown (the watch then ends by TTL, task or run only)"""
    env = os.environ if env is None else env
    table = proc_table() if table is None else table
    try:
        pid = int(env.get('CLAUDE_PID') or 0)
    except ValueError:
        pid = 0
    if pid and proc_alive(pid):
        return {'pid': pid, 'created': proc_created(pid), 'name': (table.get(pid) or (0, '?'))[1], 'via': 'CLAUDE_PID'}
    for p, exe in ancestors(os.getpid(), table):
        if AGENT_EXE.match(exe or ''):
            return {'pid': p, 'created': proc_created(p), 'name': exe, 'via': 'ancestor'}
    return None


# ------------------------------------------------------------------------------------------ the task store (read-only)
class Store:
    """tasks.json and inbox/runs.json, re-parsed only when their (size, mtime) changed; a torn read keeps the last good
    value, a file never read gives UNKNOWN"""

    def __init__(self, tdir=None):
        self.tdir = Path(tdir or tasks_dir())
        self._c = {}

    def _read(self, p, missing):
        try:
            st = p.stat()
        except FileNotFoundError:
            return missing
        except OSError:
            return self._c.get(p, (None, UNKNOWN))[1]
        key = (st.st_size, st.st_mtime_ns)
        hit = self._c.get(p)
        if hit and hit[0] == key:
            return hit[1]
        try:
            val = json.loads(p.read_text(encoding='utf-8-sig') or '{}')
        except (OSError, ValueError):
            return hit[1] if hit else UNKNOWN
        self._c[p] = (key, val)
        return val

    def task(self, tid):
        """the task record, None when the store has no such task, UNKNOWN when the store cannot be read"""
        d = self._read(self.tdir / 'tasks.json', UNKNOWN)
        if d is UNKNOWN or not isinstance(d, dict):
            return UNKNOWN
        t = (d.get('tasks') or {}).get(tid)
        return t if isinstance(t, dict) else None

    def runs(self):
        m = self._read(self.tdir / 'inbox' / 'runs.json', {})
        return m if isinstance(m, dict) or m is UNKNOWN else {}


def task_end(e, store):
    t = store.task(e['task'])
    if t is UNKNOWN:
        return None
    if t is None:
        return f"task {e['task']} is not in the task store"
    st = t.get('status')
    if st in TERMINAL or st in PAUSED:
        return f"task {e['task']} is {st}"
    lj = e.get('lease_job')
    if lj and ((t.get('lease') or {}).get('job') != lj):
        return f"task {e['task']}: lease {lj} ended"
    return None


def run_end(e, store):
    if not e.get('run'):
        return None
    m = store.runs()
    if m is UNKNOWN:
        return None
    if m.get(e['run']) != e['task']:
        return f"run {e['run']} is no longer bound to {e['task']} (inbox/runs.json)"
    return None


def session_end(e, alive=None):
    par = e.get('parent') or {}
    if not par.get('pid'):
        return None
    if not (alive or proc_alive)(par['pid'], par.get('created')):
        return f"session gone ({par.get('name') or 'pid'} {par['pid']} ended)"
    return None


def ttl_end(e, now):
    if now >= float(e['started_ts']) + float(e['ttl_s']):
        return f"ttl {fmt_dur(e['ttl_s'])} reached"
    return None


def end_reason(e, store, now, alive=None):
    """why the watch e must end now (ttl, task, run, session), or None"""
    return ttl_end(e, now) or task_end(e, store) or run_end(e, store) or session_end(e, alive)


def stale_reason(e, store=None, now=None, alive=None):
    """a reader's verdict on a registry entry: 'dead: ...' (the process is gone, the entry was left behind), an end
    condition that already holds (the watch outlived its job or TTL), or None (running within its limits)"""
    alive = alive or proc_alive
    now = time.time() if now is None else now
    if not alive(e.get('pid'), e.get('created')):
        return f"dead: pid {e.get('pid')} is gone, entry left behind"
    return end_reason(e, store or Store(), now, alive)


# ------------------------------------------------------------------------------------------ registry
def _write_json(p, obj):
    p = Path(p)
    p.parent.mkdir(parents=True, exist_ok=True)
    tmp = p.with_name(f'.{p.name}.{os.getpid()}.tmp')
    tmp.write_text(json.dumps(obj, ensure_ascii=False, indent=1) + '\n', encoding='utf-8', newline='\n')
    for _ in range(30):
        try:
            os.replace(tmp, p)
            return
        except PermissionError:           # a reader holds it open on Windows: retry briefly
            time.sleep(0.02)
    os.replace(tmp, p)


def entry_path(wid, wdir=None):
    return Path(wdir or watch_dir()) / f'{wid}.json'


def stop_path(wid, wdir=None):
    return Path(wdir or watch_dir()) / f'{wid}.stop'


def register(e, wdir=None):
    """create the entry exclusively (a new id on a clash)"""
    wdir = Path(wdir or watch_dir())
    wdir.mkdir(parents=True, exist_ok=True)
    for _ in range(20):
        p = entry_path(e['id'], wdir)
        try:
            fd = os.open(p, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
        except FileExistsError:
            e['id'] = new_id()
            continue
        os.close(fd)
        _write_json(p, e)
        return p
    raise OSError('no free watch id')


def unregister(wid, wdir=None):
    for p in (entry_path(wid, wdir), stop_path(wid, wdir)):
        try:
            p.unlink()
        except FileNotFoundError:
            pass
        except OSError:
            pass


def entries(wdir=None):
    """[(path, entry dict or None when unreadable)] of the registry"""
    wdir = Path(wdir or watch_dir())
    out = []
    try:
        files = sorted(wdir.glob('w-*.json'))
    except OSError:
        return out
    for p in files:
        try:
            e = json.loads(p.read_text(encoding='utf-8'))
            if not isinstance(e, dict) or not e.get('id') or not e.get('pid') or 'started_ts' not in e:
                e = None
        except (OSError, ValueError):
            e = None
        out.append((p, e))
    return out


def new_id():
    return 'w-' + uuid.uuid4().hex[:6]


# ------------------------------------------------------------------------------------------ probes
def git_bash():
    for c in (os.environ.get('CLAUDE_CODE_GIT_BASH_PATH'), r'C:\Program Files\Git\bin\bash.exe',
              r'C:\Program Files (x86)\Git\bin\bash.exe'):
        if c and Path(c).is_file():
            return c
    w = shutil.which('bash')
    if w and not (os.name == 'nt' and 'system32' in w.lower()):     # System32\bash.exe is WSL, not Git Bash
        return w
    return None


def run_check(cmd, timeout):
    """-> (state, first output line). One string = a Git Bash command line; a list of several = an argv"""
    cmd = list(cmd or [])
    if len(cmd) == 1:
        sh = git_bash()
        argv, shell = ([sh, '-c', cmd[0]], False) if sh else (cmd[0], True)
    else:
        argv, shell = cmd, False
    kw = {'creationflags': 0x08000000} if os.name == 'nt' else {'start_new_session': True}   # CREATE_NO_WINDOW
    try:
        p = subprocess.Popen(argv, shell=shell, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                             stderr=subprocess.STDOUT, **kw)
    except OSError as ex:
        return f'error: {type(ex).__name__}', str(ex)[:160]
    try:
        out, _ = p.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        kill_tree(p.pid)
        try:
            p.communicate(timeout=10)
        except (subprocess.TimeoutExpired, OSError, ValueError):
            pass
        return 'timeout', f'no answer within {fmt_dur(timeout)}'
    line = next((ln.strip() for ln in out.decode('utf-8', 'replace').splitlines() if ln.strip()), '')[:160]
    return ('ok' if p.returncode == 0 else f'fail rc={p.returncode}'), line


def port_state(port):
    """'up' (something LISTENs on the TCP port), 'down', or 'error' (netstat failed: not a verdict). Read-only: the
    port itself is never touched (a connect would reach the Blender MCP server)"""
    argv = ['netstat', '-ano'] if os.name == 'nt' else (['ss', '-ltnH'] if shutil.which('ss') else ['netstat', '-ltn'])
    kw = {'creationflags': 0x08000000} if os.name == 'nt' else {}
    try:
        p = subprocess.run(argv, capture_output=True, timeout=30, **kw)
    except (OSError, subprocess.SubprocessError):
        return 'error'
    if p.returncode != 0:
        return 'error'
    want = f':{int(port)}'
    for ln in p.stdout.decode('utf-8', 'replace').splitlines():
        parts = ln.split()
        if os.name == 'nt':
            if len(parts) >= 4 and parts[0].upper().startswith('TCP') and parts[1].endswith(want) \
                    and parts[3].upper() == 'LISTENING':
                return 'up'
        elif any(x.endswith(want) for x in parts) and ('LISTEN' in ln.upper() or argv[0] == 'ss'):
            return 'up'
    return 'down'


def build_probe(e):
    """probe() -> {name: (state, detail)} and until(states) -> end reason or None, from the entry"""
    until = e.get('until') or {}
    timeout = min(CHECK_TIMEOUT_MAX_S, max(float(e['every_s']), 5.0))

    def probe():
        out = {}
        if until.get('port_down'):
            out[f"port {until['port_down']}"] = (port_state(until['port_down']), '')
        if until.get('file'):
            out['file'] = ('present' if Path(until['file']).exists() else 'absent', until['file'])
        if e.get('cmd'):
            out['check'] = run_check(e['cmd'], timeout)
        return out

    return probe


def until_reason(e, states):
    until = e.get('until') or {}
    if until.get('port_down') and states.get(f"port {until['port_down']}", ('',))[0] == 'down':
        return f"port {until['port_down']} down"
    if until.get('file') and states.get('file', ('',))[0] == 'present':
        return f"file {until['file']} exists"
    return None


# ------------------------------------------------------------------------------------------ the loop
def new_entry(task, run=None, ttl_s=TTL_DEFAULT_S, every_s=EVERY_DEFAULT_S, until=None, cmd=None, parent=None,
              session=None, lease_job=None, now=None, pid=None, created=None):
    now = time.time() if now is None else now
    pid = os.getpid() if pid is None else pid
    return {'id': new_id(), 'task': task, 'run': run, 'pid': pid,
            'created': proc_created(pid) if created is None else created,
            'started': utc_iso(now), 'started_ts': now, 'ttl_s': float(ttl_s), 'every_s': float(every_s),
            'until': until or None, 'cmd': list(cmd) if cmd else None, 'parent': parent, 'session': session,
            'lease_job': lease_job, 'host': _host(), 'last_tick': utc_iso(now), 'state': {}}


def _host():
    return os.environ.get('COMPUTERNAME') or (os.uname().nodename if hasattr(os, 'uname') else None)


def validate_start(store, task, run=None, ttl_s=TTL_DEFAULT_S, every_s=EVERY_DEFAULT_S, until=None, cmd=None):
    """-> the lease job the task holds now (None when not leased); Refused with the reason otherwise"""
    if not task:
        raise Refused('--task <KTC id> is required: a background watch ends with its job (INC-027: a port watchdog '
                      'without one ran 32 h after its job ended)')
    if not TASK_RE.match(str(task)):
        raise Refused(f'--task {task!r} is not a task id (KTC-164)')
    if run and not RUN_RE.match(str(run)):
        raise Refused(f'--run {run!r} is not a run id (wf_...)')
    if not (0 < ttl_s <= TTL_MAX_S):
        raise Refused(f'--ttl {fmt_dur(ttl_s)} is outside 1s..12h (a longer watch is a job of its own: lease a task)')
    if every_s < EVERY_MIN_S:
        raise Refused(f'--every {every_s:g}s is below {EVERY_MIN_S:g}s')
    if not until and not cmd:
        raise Refused('nothing to watch: give --until-port-down PORT, --until-file PATH or a check command after --')
    for _ in range(5):
        t = store.task(task)
        if t is not UNKNOWN:
            break
        time.sleep(0.2)
    if t is UNKNOWN:
        raise Refused(f'the task store {store.tdir / "tasks.json"} cannot be read: a watch must be tied to a task')
    if t is None:
        raise Refused(f'task {task} is not in the task store {store.tdir / "tasks.json"}')
    if t.get('status') in TERMINAL or t.get('status') in PAUSED:
        raise Refused(f"task {task} is {t.get('status')}: nothing to watch for it")
    if run:
        m = store.runs()
        if m is UNKNOWN or m.get(run) != task:
            raise Refused(f'run {run} is not bound to {task} in {store.tdir / "inbox" / "runs.json"}: '
                          f'bind it first (tasks.py bind-run {task} {run}) or leave --run out')
    return (t.get('lease') or {}).get('job')


class Watch:
    """the loop: probes every every_s, the end conditions every tick; prints only changes. clock / sleep / probe /
    alive are injectable (tests run hours of watch in milliseconds)"""

    def __init__(self, e, store=None, wdir=None, clock=time.time, sleep=time.sleep, out=None, probe=None,
                 alive=None):
        self.e, self.store = e, store or Store()
        self.wdir = Path(wdir or watch_dir())
        self.clock, self.sleep = clock, sleep
        self.out = out or sys.stdout
        self.probe = probe or build_probe(e)
        self.alive = alive or proc_alive
        self.lines = []

    def emit(self, text):
        line = f'{local_hms(self.clock())} watch {self.e["id"]} {self.e["task"]}: {text}'
        self.lines.append(line)
        try:
            self.out.write(line + '\n')
            self.out.flush()
        except (OSError, ValueError):
            pass

    def _save(self, now):
        self.e['last_tick'] = utc_iso(now)
        try:
            if entry_path(self.e['id'], self.wdir).exists():
                _write_json(entry_path(self.e['id'], self.wdir), self.e)
        except OSError:
            pass

    def run(self):
        e = self.e
        t0 = float(e['started_ts'])
        end_at = t0 + float(e['ttl_s'])
        every = float(e['every_s'])
        par = e.get('parent') or {}
        ends = [f"ttl {fmt_dur(e['ttl_s'])} (at {local_hms(end_at)})", f"task {e['task']} ends"]
        if e.get('run'):
            ends.append(f"run {e['run']} is unbound")
        ends.append(f"session {par.get('name')} {par['pid']} ends" if par.get('pid') else 'no session known')
        u = e.get('until') or {}
        if u.get('port_down'):
            ends.append(f"port {u['port_down']} goes down")
        if u.get('file'):
            ends.append(f"{u['file']} appears")
        self.emit(f"started (pid {e['pid']}, every {every:g}s); ends at the first of: {'; '.join(ends)}. "
                  f"Stop: python .claude/hooks/watch.py stop {e['id']}")
        states, reason = {}, None
        next_check = next_life = self.clock()
        next_beat = next_check + HEARTBEAT_S
        try:
            while True:
                now = self.clock()
                if stop_path(e['id'], self.wdir).exists():
                    reason = 'stopped (watch.py stop)'
                    break
                reason = ttl_end(e, now)
                if reason:
                    break
                if now >= next_life:
                    reason = task_end(e, self.store) or run_end(e, self.store) or session_end(e, self.alive)
                    if reason:
                        break
                    next_life = now + LIFE_EVERY_S
                changed = False
                if now >= next_check:
                    new = self.probe()
                    for k, (st, detail) in new.items():
                        if (states.get(k) or ('',))[0] != st:
                            self.emit(f'{k} {st}' + (f' | {detail}' if detail and k == 'check' else ''))
                            changed = True
                    states = new
                    e['state'] = {k: v[0] for k, v in states.items()}
                    reason = until_reason(e, states)
                    if reason:
                        break
                    next_check = max(next_check + every, self.clock())
                now = self.clock()
                if changed or now >= next_beat:
                    self._save(now)
                    next_beat = now + HEARTBEAT_S
                self.sleep(max(0.05, min(TICK_S, next_check - now, next_life - now, end_at - now)))
        except KeyboardInterrupt:
            reason = 'interrupted'
        except SystemExit:
            reason = 'terminated'
        finally:
            unregister(e['id'], self.wdir)
            self.emit(f"ended after {fmt_dur(self.clock() - t0)}: {reason or 'error'}")
            log({'event': 'watch_end', 'id': e['id'], 'task': e['task'], 'run': e.get('run'), 'reason': reason,
                 'secs': round(self.clock() - t0, 1)})
        return reason


# ------------------------------------------------------------------------------------------ CLI
def _on_signal(signum, frame):   # noqa: ARG001
    raise SystemExit(0)


def cmd_start(a):
    store = Store()
    try:
        ttl = parse_dur(a.ttl)
        every = parse_dur(a.every)
    except ValueError as ex:
        return refuse(str(ex), a)
    until = {}
    if a.until_port_down:
        until['port_down'] = int(a.until_port_down)
    if a.until_file:
        until['file'] = str(Path(a.until_file).resolve())
    cmd = list(a.cmd or [])
    cmd = (cmd[1:] if cmd[:1] == ['--'] else cmd) or None
    try:
        lease_job = validate_start(store, a.task, a.run, ttl, every, until, cmd)
    except Refused as ex:
        return refuse(str(ex), a)
    if a.parent_pid is not None:
        parent = ({'pid': a.parent_pid, 'created': proc_created(a.parent_pid), 'name': 'pid', 'via': '--parent-pid'}
                  if a.parent_pid else None)
        if parent and parent['created'] is None:
            return refuse(f'--parent-pid {a.parent_pid} does not run', a)
    else:
        parent = session_parent()
    e = new_entry(a.task, a.run, ttl, every, until, cmd, parent, os.environ.get('CLAUDE_CODE_SESSION_ID'), lease_job)
    register(e)
    log({'event': 'watch_start', 'id': e['id'], 'task': e['task'], 'run': e['run'], 'ttl_s': ttl, 'every_s': every,
         'until': until or None, 'cmd': (' '.join(cmd))[:200] if cmd else None, 'parent': parent})
    for s in ('SIGTERM', 'SIGBREAK', 'SIGHUP'):
        if hasattr(signal, s):
            try:
                signal.signal(getattr(signal, s), _on_signal)
            except (OSError, ValueError):
                pass
    Watch(e, store).run()
    return 0


def refuse(msg, a=None):
    sys.stderr.write(f'watch.py start refused: {msg}\n')
    log({'event': 'watch_refused', 'why': msg, 'task': getattr(a, 'task', None), 'run': getattr(a, 'run', None)})
    return 2


def describe(e, now=None, store=None):
    now = time.time() if now is None else now
    why = stale_reason(e, store, now)
    left = float(e['started_ts']) + float(e['ttl_s']) - now
    return {'id': e['id'], 'task': e.get('task'), 'run': e.get('run'), 'pid': e.get('pid'),
            'age': fmt_dur(now - float(e['started_ts'])), 'ttl_left': fmt_dur(left),
            'state': e.get('state') or {}, 'status': 'DEAD' if why and why.startswith('dead') else
            ('STALE' if why else 'running'), 'why': why, 'cmd': e.get('cmd'), 'until': e.get('until')}


def cmd_list(a):
    store = Store()
    rows = []
    for p, e in entries():
        rows.append(describe(e, store=store) if e else {'id': p.stem, 'status': 'CORRUPT', 'why': f'{p} unreadable'})
    if a.json:
        print(json.dumps(rows, indent=1))
        return 0
    if not rows:
        print('no background watches')
        return 0
    for r in rows:
        if r['status'] == 'CORRUPT':
            print(f"{r['id']}  CORRUPT  {r['why']}")
            continue
        st = ', '.join(f'{k} {v}' for k, v in (r['state'] or {}).items()) or '-'
        print(f"{r['id']}  {r['status']:<7} task {r['task']}{' run ' + r['run'] if r['run'] else ''}  pid {r['pid']}  "
              f"age {r['age']}  ttl left {r['ttl_left']}  [{st}]" + (f"  <- {r['why']}" if r['why'] else ''))
    return 0


def stop_one(p, e, why='stop'):
    """ask the watch to end (stop file), kill it after STOP_GRACE_S; -> what happened"""
    wid = e['id'] if e else p.stem
    wdir = p.parent
    if e and proc_alive(e.get('pid'), e.get('created')):
        try:
            stop_path(wid, wdir).write_text(why + '\n', encoding='utf-8')
        except OSError:
            pass
        t_end = time.time() + STOP_GRACE_S
        while time.time() < t_end and p.exists():
            time.sleep(0.2)
        if p.exists() and proc_alive(e.get('pid'), e.get('created')):
            kill_tree(e['pid'])
            unregister(wid, wdir)
            res = 'killed'
        else:
            unregister(wid, wdir)
            res = 'stopped'
    else:
        unregister(wid, wdir)
        res = 'removed (process already gone)' if e else 'removed (unreadable entry)'
    log({'event': 'watch_stop', 'id': wid, 'task': (e or {}).get('task'), 'result': res, 'why': why})
    return res


def cmd_stop(a):
    all_ = entries()
    if a.stale:
        store, n = Store(), 0
        for p, e in all_:
            why = stale_reason(e, store) if e else 'unreadable entry'
            if why:
                print(f'{p.stem}: {stop_one(p, e, "stale: " + why)} ({why})')
                n += 1
        if not n:
            print('no stale watches')
        return 0
    if not a.id:
        sys.stderr.write('watch.py stop <id> | --stale\n')
        return 2
    hit = [(p, e) for p, e in all_ if p.stem == a.id]
    if not hit:
        sys.stderr.write(f'no watch {a.id} (watch.py list)\n')
        return 1
    print(f'{a.id}: {stop_one(*hit[0], why="watch.py stop")}')
    return 0


def main(argv=None):
    argv = list(sys.argv[1:] if argv is None else argv)
    ap = argparse.ArgumentParser(prog='watch.py', description='background watchdogs tied to their job (INC-027)')
    sub = ap.add_subparsers(dest='cmd_name', required=True)
    s = sub.add_parser('start', help='run a watch in this process (use as a Monitor or background Bash command)')
    s.add_argument('--task', help='the task the watch belongs to (required)')
    s.add_argument('--run', help='the workflow run id it belongs to (must be bound: tasks.py bind-run)')
    s.add_argument('--ttl', default='3h', help='3h default, 12h max (3h, 90m, 1h30m, seconds)')
    s.add_argument('--every', default=str(int(EVERY_DEFAULT_S)), help='probe interval (s), >= 1')
    s.add_argument('--until-port-down', type=int, metavar='PORT', help='end when this TCP port stops LISTENING')
    s.add_argument('--until-file', metavar='PATH', help='end when this file exists')
    s.add_argument('--parent-pid', type=int, help='the session process (default CLAUDE_PID / claude ancestor; 0 none)')
    s.add_argument('cmd', nargs=argparse.REMAINDER, help='-- check command (one string = Git Bash line)')
    li = sub.add_parser('list', help='the registered watches')
    li.add_argument('--json', action='store_true')
    so = sub.add_parser('stop', help='stop one watch, or every stale one')
    so.add_argument('id', nargs='?')
    so.add_argument('--stale', action='store_true')
    a = ap.parse_args(argv)
    if a.cmd_name == 'start':
        return cmd_start(a)
    if a.cmd_name == 'list':
        return cmd_list(a)
    return cmd_stop(a)


if __name__ == '__main__':
    sys.exit(main())
