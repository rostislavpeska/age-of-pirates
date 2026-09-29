"""Client for Substance Painter remote scripting (Painter started with --enable-remote-scripting).

python sp_remote.py --check                 -> prints the Painter version or exits 2
python sp_remote.py js "alg.version.painter"
python sp_remote.py py file_or_code         -> runs Python in Painter; the value of RESULT comes back
Importable: js(code), py(code), check().

Protocol (verified on Painter 9.1.2): POST http://localhost:60041/run.json with
{"js": base64} or {"python": base64}. JS returns its last expression. Python returns a value
only for a single expression, so py() wraps any code into one expression that exec()s it and
returns the variable RESULT (JSON-serialisable). Errors come back as {"error": {...}}.
"""
import base64
import http.client
import json
import os
import sys
import time
import uuid
import painter_audit as audit

HOST, PORT = 'localhost', 60041


class PainterError(RuntimeError):
    pass


class PainterJobUnknown(PainterError):
    audit_outcome = 'unknown'


def _post(kind, code, timeout=3600, *, operation=None, mutating=None, script_name=None):
    with audit.Operation(operation or ('remote.' + kind), mutating=mutating,
                         script=audit.script_info(code, script_name), timeout_s=timeout) as trace:
        with audit.endpoint_lock(HOST, PORT):
            body = json.dumps({kind: base64.b64encode(code.encode('utf-8')).decode('ascii')})
            conn = http.client.HTTPConnection(HOST, PORT, timeout=timeout)
            try:
                # Durable begin above precedes the first byte sent to Painter.
                conn.request('POST', '/run.json', body, {'Content-type': 'application/json', 'Accept': 'application/json'})
                response = conn.getresponse()
                text = response.read().decode('utf-8', 'replace')
                trace.mark('response', http_status=response.status, response_bytes=len(text))
                try:
                    value = json.loads(text)
                except ValueError:
                    return text
                if isinstance(value, dict) and set(value) == {'error'}:
                    error = value['error']
                    raise PainterError(error.get('description', error) if isinstance(error, dict) else error)
                trace.finish(result_type=type(value).__name__)
                return value
            except (OSError, http.client.HTTPException) as exc:
                exc.audit_outcome = 'unknown'
                trace.mark('connection_failure', error_type=type(exc).__name__, outcome='unknown')
                raise
            finally:
                conn.close()


def js(code, timeout=3600, **audit_fields):
    return _post('js', code, timeout, **audit_fields)


def py(code, timeout=3600, **audit_fields):
    expr = f"(lambda g: (exec({code!r}, g), g.get('RESULT'))[1])({{'__name__': 'sp_remote'}})"
    return _post('python', expr, timeout, **audit_fields)


_LATER = '''
import builtins, traceback, os, json, time
from datetime import datetime, timezone
from PySide2 import QtCore
def _sp_later(code, job_id, audit_path, audit_metadata):
    old = getattr(builtins, '_sp_job', None)
    if old and old.get('state') in ('queued', 'running'):
        return {'state': 'blocked', 'reason': 'A previous Painter job is active',
                'active_job_id': old.get('id'), 'remote_pid': os.getpid()}
    import substance_painter.project as p
    if p.is_busy():
        return {'state': 'blocked', 'reason': 'Painter project is busy', 'remote_pid': os.getpid()}
    job = {'id': job_id, 'state': 'queued', 'result': None, 'error': None,
           'remote_pid': os.getpid()}
    def record(phase, **fields):
        job['audit_sequence'] = job.get('audit_sequence', 0) + 1
        row = dict(audit_metadata)
        row.update({'phase': phase, 'job_id': job_id, 'remote_pid': os.getpid(),
                    'origin': 'painter', 'remote_time_unix': time.time(),
                    'at': datetime.now(timezone.utc).isoformat(),
                    'job_sequence': job['audit_sequence'],
                    'error_type': job.get('error_type')})
        row.update(fields)
        data = (json.dumps(row) + chr(10)).encode('utf-8')
        fd = os.open(audit_path, os.O_WRONLY | os.O_CREAT | os.O_APPEND, 0o600)
        try:
            os.write(fd, data); os.fsync(fd)
        finally:
            os.close(fd)
    def audit_step(stage, phase='before'):
        if phase not in ('before', 'after', 'failed'):
            raise ValueError('Invalid adapter audit phase')
        record('step_' + phase, stage=str(stage)[:160])
    def run():
        job['state'] = 'running'
        try:
            record('running')
            g = {'__name__': 'sp_remote_job', '_sp_audit_step': audit_step}
            exec(code, g); job['result'] = g.get('RESULT'); job['state'] = 'done'
        except Exception as exc:
            job['error_type'] = type(exc).__name__
            job['error'] = traceback.format_exc(); job['state'] = 'failed'
        finally:
            try:
                record(job['state'])
            except Exception:
                job['state'] = 'audit_failed'
                job['error'] = 'Remote audit write failed; inspect project before retry'
    record('queued')
    builtins._sp_job = job
    QtCore.QTimer.singleShot(0, run)
    return {key: job[key] for key in ('id', 'state', 'remote_pid')}
builtins._sp_later = _sp_later
'''


IDLE = "import substance_painter.project as p\nRESULT = not p.is_busy()"


def later(code, until=IDLE, poll=2.0, timeout=3600, *, operation='remote.job',
          mutating=True, script_name=None):
    """Long operations (create, open, bake, export): queue on Painter's main loop, poll to the end.

    A long call made inside the request re-enters the request handler while Painter
    processes events, and the request runs a second time ("Cannot create a new project
    because one is already opened" after a successful create). Queued, it runs once.
    The call itself returns before Painter finishes (create: no texture sets yet), so after
    the job the client also polls `until` (Python setting RESULT truthy; default: not busy).
    """
    if poll < 0 or timeout <= 0:
        raise ValueError('poll must be nonnegative and timeout positive')
    job_id = uuid.uuid4().hex
    with audit.Operation(operation, mutating=mutating, job_id=job_id,
                         script=audit.script_info(code, script_name), timeout_s=timeout) as trace:
        with audit.endpoint_lock(HOST, PORT):
            deadline = time.monotonic() + timeout
            def remaining():
                value = deadline - time.monotonic()
                if value <= 0:
                    raise TimeoutError('Painter job deadline elapsed; outcome unknown; job ' + job_id)
                return value
            py(_LATER, timeout=remaining(), operation='job.install_queue', mutating=False)
            metadata = {'schema': 1, 'operation': operation, 'operation_id': trace.id,
                        'parent_id': trace.id, 'client_pid': os.getpid(),
                        'endpoint': 'http://%s:%s/run.json' % (HOST, PORT),
                        'script': audit.script_info(code, script_name)}
            accepted = py('import builtins\nRESULT = builtins._sp_later(%r, %r, %r, %r)' %
                          (code, job_id, str(audit.log_path()), metadata),
                          timeout=remaining(), operation='job.enqueue', mutating=mutating)
            if isinstance(accepted, dict) and accepted.get('remote_pid'):
                audit.configure(remote_pid=accepted['remote_pid'])
            if not isinstance(accepted, dict):
                raise PainterJobUnknown('Invalid enqueue response; inspect project before retry')
            if accepted.get('state') == 'blocked':
                raise audit.PainterBusyError(accepted.get('reason', 'Painter queue busy'))
            if accepted.get('id') != job_id:
                raise PainterJobUnknown('Enqueued job identity mismatch; inspect project before retry')
            trace.mark('accepted', job_id=job_id, remote_pid=accepted.get('remote_pid'))
            job, previous_state = None, None
            while True:
                time.sleep(min(poll, remaining()))
                if not job or job['state'] != 'done':
                    job = py('import builtins\nRESULT = getattr(builtins, "_sp_job", None)',
                             timeout=remaining(), operation='job.poll', mutating=False)
                if not isinstance(job, dict) or job.get('id') != job_id:
                    raise PainterJobUnknown('Painter job disappeared or was replaced: ' + job_id)
                if job['state'] != previous_state:
                    trace.mark('observed_' + job['state'], job_id=job_id)
                    previous_state = job['state']
                if job['state'] == 'failed':
                    raise PainterError(job['error'])
                if job['state'] == 'audit_failed':
                    raise PainterJobUnknown(job['error'])
                if job['state'] == 'done' and py(until, timeout=remaining(), operation='job.until', mutating=False):
                    trace.finish(job_id=job_id, result_type=type(job['result']).__name__)
                    return job['result']


def check():
    try:
        version = js('alg.version.painter', timeout=5, operation='painter.version', mutating=False)
        audit.configure(painter_version=version)
        return version
    except OSError:
        return None


if __name__ == '__main__':
    if sys.argv[1] == '--check':
        v = check()
        print(v or 'Painter remote scripting is not reachable on port 60041'); sys.exit(0 if v else 2)
    kind, arg = sys.argv[1], sys.argv[2]
    code = open(arg, encoding='utf-8').read() if os.path.isfile(arg) else arg
    try:
        print(json.dumps(js(code) if kind == 'js' else py(code), indent=2))
    except PainterError as e:
        print('PAINTER ERROR:', e); sys.exit(1)
