"""Offline failure simulations only. No Painter instance or socket is contacted."""
import builtins
import contextlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import threading
import types
import unittest
from unittest.mock import patch

import painter_audit as audit
import sp_remote as sp
from painter_connector import Connector, QuarantinedCommand


class FakeHTTP:
    error = None
    payload = b'{"ok":true}'
    closed = False
    begin_before_request = False
    status = 200

    def __init__(self, *args, **kwargs):
        self.closed = False
        type(self).instance = self

    def request(self, *args):
        rows = [json.loads(x) for x in audit.log_path().read_text().splitlines()]
        self.begin_before_request = rows[-1]['phase'] == 'begin'
        if self.error:
            raise self.error

    def getresponse(self):
        return self

    def read(self):
        return self.payload

    def close(self):
        self.closed = True


class Harness(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='painter-audit-test-')
        self.root = Path(self.temp.name)
        audit.configure(log_path=self.root/'events.jsonl', project='offline-test', remote_pid=0)
        FakeHTTP.error, FakeHTTP.payload = None, b'{"ok":true}'

    def tearDown(self):
        self.temp.cleanup()

    def rows(self):
        return [json.loads(x) for x in audit.log_path().read_text().splitlines()]

    def connector(self):
        connector = Connector.__new__(Connector)
        connector.project = self.root/'test.spp'
        connector.audit_path = audit.log_path()
        connector.guard = lambda: None
        return connector

    @contextlib.contextmanager
    def remote(self, *, run=True, fail_poll=False, replace=False, old=None):
        callbacks = []
        saved = {name: getattr(builtins, name, None) for name in ('_sp_job', '_sp_later')}
        had = {name: hasattr(builtins, name) for name in saved}
        if old is not None:
            builtins._sp_job = old
        elif hasattr(builtins, '_sp_job'):
            del builtins._sp_job
        qt = types.SimpleNamespace(QTimer=types.SimpleNamespace(singleShot=lambda ms, cb: callbacks.append(cb)))
        project = types.ModuleType('substance_painter.project')
        project.is_busy = lambda: False
        painter = types.ModuleType('substance_painter')
        painter.project = project
        modules = {'PySide2': types.SimpleNamespace(QtCore=qt),
                   'substance_painter': painter, 'substance_painter.project': project}
        def fake_py(code, **kwargs):
            if code.startswith('import builtins\nRESULT = getattr'):
                if fail_poll:
                    raise ConnectionResetError('offline simulated reset')
                if run and callbacks:
                    callbacks.pop(0)()
                if replace:
                    builtins._sp_job = {'id': 'other-client', 'state': 'done'}
            g = {}
            exec(code, g)
            return g.get('RESULT')
        try:
            with patch.dict(sys.modules, modules), patch.object(sp, 'py', side_effect=fake_py):
                yield callbacks
        finally:
            for name in saved:
                if had[name]:
                    setattr(builtins, name, saved[name])
                elif hasattr(builtins, name):
                    delattr(builtins, name)

    def test_transport_success_is_logged_before_request_and_closed(self):
        with patch.object(sp.http.client, 'HTTPConnection', FakeHTTP):
            self.assertEqual(sp.js('TEST_SCRIPT_SECRET', mutating=True), {'ok': True})
        self.assertTrue(FakeHTTP.instance.begin_before_request)
        self.assertTrue(FakeHTTP.instance.closed)
        self.assertNotIn('TEST_SCRIPT_SECRET', audit.log_path().read_text())
        self.assertEqual(self.rows()[-1]['phase'], 'done')

    def test_transport_reset_is_unknown_not_confirmed_crash(self):
        FakeHTTP.error = ConnectionResetError('reset')
        with patch.object(sp.http.client, 'HTTPConnection', FakeHTTP):
            with self.assertRaises(ConnectionResetError):
                sp.js('mutation()', mutating=True)
        self.assertTrue(FakeHTTP.instance.closed)
        self.assertEqual(self.rows()[-1]['phase'], 'unknown')
        self.assertIsNotNone(audit.inspect_log(audit.log_path())['last_unfinished_operation'])

    def test_transport_timeout_is_unknown(self):
        FakeHTTP.error = TimeoutError('timeout')
        with patch.object(sp.http.client, 'HTTPConnection', FakeHTTP):
            with self.assertRaises(TimeoutError):
                sp.py('RESULT=7', timeout=.01)
        self.assertEqual(self.rows()[-1]['phase'], 'unknown')

    def test_logging_failure_prevents_request_dispatch(self):
        with patch.object(audit.os, 'fsync', side_effect=OSError('disk unavailable')), \
                patch.object(sp.http.client, 'HTTPConnection') as connection:
            with self.assertRaises(OSError):
                sp.js('mutation()', mutating=True)
        connection.assert_not_called()

    def test_remote_explicit_error_is_failed(self):
        FakeHTTP.payload = b'{"error":{"description":"expected remote error"}}'
        with patch.object(sp.http.client, 'HTTPConnection', FakeHTTP):
            with self.assertRaises(sp.PainterError):
                sp.py('RESULT=7')
        self.assertEqual(self.rows()[-1]['phase'], 'failed')

    def test_runtime_success_records_every_state_and_actual_process(self):
        with self.remote():
            self.assertEqual(sp.later('RESULT={"saved":True}', poll=0, timeout=2), {'saved': True})
        remote = [row for row in self.rows() if row.get('origin') == 'painter']
        self.assertEqual([row['phase'] for row in remote], ['queued','running','done'])
        self.assertTrue(all(row['remote_pid'] == os.getpid() for row in remote))
        self.assertEqual(len({row['job_id'] for row in remote}), 1)
        self.assertEqual(audit.inspect_log(audit.log_path())['unresolved'], [])

    def test_runtime_failure_is_failed_and_never_retried(self):
        with self.remote() as callbacks:
            with self.assertRaises(sp.PainterError):
                sp.later('raise ValueError("offline")', poll=0, timeout=2)
            self.assertEqual(callbacks, [])
        self.assertEqual([r['phase'] for r in self.rows() if r.get('origin') == 'painter'],
                         ['queued','running','failed'])
        self.assertEqual(self.rows()[-1]['phase'], 'failed')

    def test_inner_stage_hook_survives_a_failed_step_without_false_after(self):
        code=('_sp_audit_step("mask.select", "before")\n'
              '_sp_audit_step("mask.select", "after")\n'
              '_sp_audit_step("generator.create", "before")\n'
              'raise ValueError("offline inner failure")\n')
        with self.remote():
            with self.assertRaises(sp.PainterError):
                sp.later(code,poll=0,timeout=2)
        stages=[(r['stage'],r['phase']) for r in self.rows() if 'stage' in r]
        self.assertEqual(stages,[('mask.select','step_before'),('mask.select','step_after'),
                                 ('generator.create','step_before')])
        self.assertTrue(all('job_sequence' in r for r in self.rows() if r.get('origin')=='painter'))

    def test_reset_after_enqueue_remains_unknown_without_retry(self):
        with self.remote(run=False, fail_poll=True) as callbacks:
            with self.assertRaises(ConnectionResetError):
                sp.later('RESULT=42', poll=0, timeout=2)
            self.assertEqual(len(callbacks), 1)
        self.assertEqual(self.rows()[-1]['phase'], 'unknown')

    def test_timeout_after_enqueue_remains_unknown(self):
        with self.remote(run=False) as callbacks:
            with self.assertRaises(TimeoutError):
                sp.later('RESULT=42', poll=.001, timeout=.015)
            self.assertEqual(len(callbacks), 1)
        self.assertEqual(self.rows()[-1]['phase'], 'unknown')

    def test_existing_active_job_is_not_overwritten(self):
        old = {'id': 'existing', 'state': 'running'}
        with self.remote(old=old) as callbacks:
            with self.assertRaises(audit.PainterBusyError):
                sp.later('RESULT=42', poll=0, timeout=2)
            self.assertIs(builtins._sp_job, old)
            self.assertEqual(callbacks, [])
        self.assertEqual(self.rows()[-1]['phase'], 'blocked')

    def test_replaced_job_is_unknown_not_someone_elses_success(self):
        with self.remote(replace=True):
            with self.assertRaises(sp.PainterJobUnknown):
                sp.later('RESULT=42', poll=0, timeout=2)
        self.assertEqual(self.rows()[-1]['phase'], 'unknown')

    def test_uncertain_command_is_reported_above_nested_read_only_poll(self):
        audit.event('begin','connector.ensure_fill','command',mutating=True,arguments={'name':'Base'})
        audit.event('begin','job.poll','poll',mutating=False)
        audit.event('unknown','job.poll','poll')
        report=audit.inspect_log(audit.log_path())
        self.assertEqual(report['last_unfinished_operation']['operation'],'job.poll')
        self.assertEqual(report['last_uncertain_command']['operation'],'connector.ensure_fill')

    def test_endpoint_lock_blocks_another_process(self):
        code = ('import painter_audit as a\n'
                'try:\n'
                ' with a.endpoint_lock(): print("UNEXPECTED")\n'
                'except a.PainterBusyError: print("BLOCKED")\n')
        with audit.endpoint_lock():
            proc = subprocess.run([sys.executable, '-c', code], cwd=Path(__file__).parent,
                                  capture_output=True, text=True, timeout=5)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertEqual(proc.stdout.strip(), 'BLOCKED')

    def test_endpoint_lock_blocks_another_thread_and_allows_nested_owner(self):
        outcomes=[]
        def worker():
            try:
                with audit.endpoint_lock(): outcomes.append('unexpected')
            except audit.PainterBusyError:
                outcomes.append('blocked')
        with audit.endpoint_lock(), audit.endpoint_lock():
            thread=threading.Thread(target=worker); thread.start(); thread.join(2)
        self.assertEqual(outcomes, ['blocked'])

    def test_quarantined_command_logs_blocked_before_guard_or_dispatch(self):
        connector = self.connector()
        with patch.object(sp, 'later') as remote, patch.object(connector, 'guard') as guard:
            with self.assertRaises(QuarantinedCommand):
                connector.run({'op':'set_opacity','name':'Dirt','value':.4})
        remote.assert_not_called(); guard.assert_not_called()
        self.assertEqual(self.rows()[-1]['phase'], 'blocked')

    def test_recipe_rejected_before_any_layer_mutation(self):
        connector = self.connector()
        with patch.object(connector, 'run') as run:
            with self.assertRaises(QuarantinedCommand):
                connector.apply_recipe({'texture_sets':[{'name':'mata','layers':[{'name':'Dirt','opacity':.4}]}]})
        run.assert_not_called()
        self.assertEqual(self.rows()[-1]['phase'], 'blocked')

    def test_generator_family_and_menu_entry_are_blocked_before_remote_dispatch(self):
        requests=[{'op':'ensure_generator','name':'Dirt','url':'resource://test'},
                  {'op':'bind_generator','url':'resource://test'},
                  {'op':'menu_action','button':'addEffect','text':'Add generator'}]
        connector=self.connector()
        with patch.object(sp,'later') as remote, patch.object(connector,'guard') as guard:
            for request in requests:
                with self.subTest(request=request), self.assertRaises(QuarantinedCommand):
                    connector.run(request)
        remote.assert_not_called(); guard.assert_not_called()

    def test_default_generator_recipe_is_blocked_before_even_base_layer_mutates(self):
        connector=self.connector()
        recipe={'texture_sets':[{'name':'mata','layers':[{'name':'Base'},
                 {'name':'Dirt','generator':{'url':'resource://test'}}]}]}
        with patch.object(connector,'run') as run:
            with self.assertRaises(QuarantinedCommand):
                connector.apply_recipe(recipe)
        run.assert_not_called()

    def test_resource_save_and_export_have_operation_records(self):
        connector = self.connector()
        asset=self.root/'texture.png'; asset.write_bytes(b'fixture')
        exported=self.root/'out.png'; exported.write_bytes(b'fixture')
        with patch.object(sp, 'later', side_effect=['resource://test', {'saved':True},
                {'status':'ExportStatus.Success','files':[str(exported)]}]):
            connector.resource({'file':str(asset)})
            connector.save()
            connector.export({'exportPath':str(self.root)})
        names=[row['operation'] for row in self.rows() if row['phase']=='begin']
        self.assertEqual(names, ['connector.resource','connector.save','connector.export'])

    def test_inspector_survives_truncated_last_line(self):
        audit.event('begin', 'risky', 'unfinished', mutating=True)
        with audit.log_path().open('a') as handle:
            handle.write('{"truncated"')
        report=audit.inspect_log(audit.log_path())
        self.assertEqual(report['invalid_lines'], 1)
        self.assertEqual(report['last_unfinished_operation']['operation'], 'risky')

    def test_summary_does_not_record_credentials_or_unbounded_payloads(self):
        audit.event('begin','safety','safe',arguments={'password':'SECRET','code':'BODY','values':list(range(1000))})
        raw=audit.log_path().read_text()
        self.assertNotIn('SECRET',raw); self.assertNotIn('BODY',raw)
        self.assertLess(len(raw),2000)


if __name__ == '__main__':
    unittest.main(verbosity=2)
