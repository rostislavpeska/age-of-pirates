"""Durable local audit trail for Painter calls; never logs script bodies or resources.

Default: %TEMP%/painter-connector/<endpoint>/events.jsonl.
Set SP_CONNECTOR_LOG or call configure(log_path=..., project=...) before connecting.
"""
import argparse
import contextlib
import contextvars
import hashlib
import json
import os
from pathlib import Path
import tempfile
import threading
import time
from datetime import datetime, timezone
import uuid

_session = uuid.uuid4().hex
_sequence = 0
_write_lock = threading.RLock()
_parent = contextvars.ContextVar('painter_audit_parent', default=None)
_identity = {'endpoint': 'http://localhost:60041/run.json'}
_path = None
_locks = {}


class PainterBusyError(RuntimeError):
    """Another client owns the endpoint. No request was sent."""


def configure(log_path=None, **identity):
    global _path
    if log_path is not None:
        _path = Path(log_path).resolve()
    _identity.update({k: v for k, v in identity.items() if v is not None})


def log_path():
    return _path or Path(os.environ.get('SP_CONNECTOR_LOG',
        str(Path(tempfile.gettempdir()) / 'painter-connector' / 'localhost-60041' / 'events.jsonl')))


def script_info(code, name=None):
    return {'name': name, 'sha256': hashlib.sha256(code.encode('utf-8')).hexdigest(),
            'bytes': len(code.encode('utf-8'))}


def summary(value, depth=0):
    """Keep arguments useful and bounded; redact credentials and never inline scripts."""
    if depth > 4:
        return '<nested>'
    if isinstance(value, dict):
        out = {}
        for key, item in list(value.items())[:24]:
            key = str(key)
            if any(word in key.lower() for word in ('password', 'token', 'secret', 'credential')):
                out[key] = '<redacted>'
            elif key.lower() in ('code', 'script', 'source') and isinstance(item, str):
                out[key] = script_info(item)
            else:
                out[key] = summary(item, depth + 1)
        if len(value) > 24:
            out['_additional_fields'] = len(value) - 24
        return out
    if isinstance(value, (list, tuple)):
        items = [summary(x, depth + 1) for x in value[:12]]
        return items + ([{'additional_items': len(value) - 12}] if len(value) > 12 else [])
    if isinstance(value, str):
        return value if len(value) <= 500 else value[:500] + '...<truncated>'
    if value is None or isinstance(value, (bool, int, float)):
        return value
    return str(value)[:200]


def event(phase, operation, operation_id=None, **fields):
    global _sequence
    with _write_lock:
        _sequence += 1
        record = {'at': datetime.now(timezone.utc).isoformat(), 'schema': 1,
                  'session': _session, 'sequence': _sequence, 'client_pid': os.getpid(),
                  **_identity, 'phase': phase, 'operation': operation,
                  'operation_id': operation_id, 'parent_id': _parent.get(), **fields}
        path = log_path()
        path.parent.mkdir(parents=True, exist_ok=True)
        # One append and fsync BEFORE dispatch means process loss leaves a durable begin.
        data = (json.dumps(summary(record), ensure_ascii=False) + '\n').encode('utf-8')
        fd = os.open(str(path), os.O_WRONLY | os.O_CREAT | os.O_APPEND, 0o600)
        try:
            os.write(fd, data)
            os.fsync(fd)
        finally:
            os.close(fd)
        return record


class Operation:
    def __init__(self, name, mutating=None, **fields):
        self.name, self.fields = name, fields
        self.mutating = mutating
        self.id = uuid.uuid4().hex
        self.outcome = None

    def __enter__(self):
        self.start = time.monotonic()
        event('begin', self.name, self.id, mutating=self.mutating, **self.fields)
        self.token = _parent.set(self.id)
        return self

    def mark(self, phase, **fields):
        event(phase, self.name, self.id, **fields)

    def finish(self, outcome='done', **fields):
        self.outcome = outcome
        self.finish_fields = fields

    def __exit__(self, typ, exc, tb):
        _parent.reset(self.token)
        if exc is not None:
            # Connection failure is not evidence of a Painter crash. Mutations may have run.
            outcome = getattr(exc, 'audit_outcome', None)
            if outcome is None:
                outcome = 'blocked' if isinstance(exc, PainterBusyError) else (
                    'unknown' if isinstance(exc, (OSError, TimeoutError)) else 'failed')
            fields = {'error_type': typ.__name__}
            if isinstance(exc, PainterBusyError):
                fields['reason'] = str(exc)
        else:
            outcome = self.outcome or 'done'
            fields = getattr(self, 'finish_fields', {})
        event(outcome, self.name, self.id, duration_s=round(time.monotonic() - self.start, 4), **fields)
        return False


@contextlib.contextmanager
def endpoint_lock(host='localhost', port=60041):
    """Nonblocking OS lease across the entire queued job, including its polls.

    OS locks release on client death. They do not establish that its remote job stopped;
    the remote queue's job identity and active-state guard provide that second check.
    """
    key = (host, port)
    lock = _locks.setdefault(key, threading.RLock())
    if not lock.acquire(blocking=False):
        raise PainterBusyError('Another thread owns this Painter endpoint; request not sent')
    local = getattr(endpoint_lock, '_local', None)
    if local is None:
        endpoint_lock._local = local = threading.local()
    held = getattr(local, 'held', set())
    if key in held:
        try:
            yield
        finally:
            lock.release()
        return
    path = Path(tempfile.gettempdir()) / 'painter-connector' / (host + '-' + str(port)) / 'client.lock'
    path.parent.mkdir(parents=True, exist_ok=True)
    handle = path.open('a+b')
    acquired = False
    try:
        if handle.tell() == 0:
            handle.write(b'0'); handle.flush()
        handle.seek(0)
        try:
            if os.name == 'nt':
                import msvcrt
                msvcrt.locking(handle.fileno(), msvcrt.LK_NBLCK, 1)
            else:
                import fcntl
                fcntl.flock(handle.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        except (OSError, BlockingIOError) as exc:
            raise PainterBusyError('Another client owns this Painter endpoint; request not sent') from exc
        acquired = True
        local.held = held | {key}
        yield
    finally:
        local.held = held
        if acquired:
            handle.seek(0)
            if os.name == 'nt':
                msvcrt.locking(handle.fileno(), msvcrt.LK_UNLCK, 1)
            else:
                fcntl.flock(handle.fileno(), fcntl.LOCK_UN)
        handle.close()
        lock.release()


def inspect_log(path):
    """Read a crash-truncated log without treating connection loss as confirmed crash."""
    records, invalid = [], 0
    for line in Path(path).read_text(encoding='utf-8').splitlines():
        try:
            records.append(json.loads(line))
        except ValueError:
            invalid += 1
    begins, terminal, risky = {}, {}, []
    for row in records:
        ident = row.get('operation_id')
        if row.get('phase') == 'begin':
            begins[ident] = row
        if row.get('phase') in ('done', 'failed', 'blocked', 'unknown'):
            terminal[ident] = row
        if row.get('phase') in ('blocked', 'unknown', 'failed'):
            risky.append(row)
    unresolved = [row for ident, row in begins.items()
                  if ident not in terminal or terminal[ident].get('phase') == 'unknown']
    commands = [row for row in unresolved if row.get('mutating') is not False]
    semantic = [row for row in commands if row.get('operation', '').startswith('connector.')]
    return {'path': str(path), 'event_count': len(records), 'invalid_lines': invalid,
            'last_event': records[-1] if records else None,
            'last_unfinished_operation': unresolved[-1] if unresolved else None,
            'last_uncertain_command': (semantic or commands or [None])[-1],
            'unresolved': unresolved, 'recent_problems': risky[-12:],
            'interpretation': 'Unknown or unfinished means inspect Painter/project before retry. It does not prove a crash.'}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('log', nargs='?', type=Path, default=log_path())
    args = parser.parse_args()
    print(json.dumps(inspect_log(args.log), indent=2))
