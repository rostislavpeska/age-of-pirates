"""Offline wrong-machine / wrong-instance regression checks; no application contact."""
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import painter_environment as env
import sp_remote as sp


class EnvironmentTests(unittest.TestCase):
    def test_explicit_local_file_overrides_stale_ambient_file(self):
        with tempfile.TemporaryDirectory() as root, patch.dict(os.environ, {'PAINTER_LOCAL_CONFIG':'absent-file.json'}):
            p=Path(root)/'tool-paths.local.json'
            p.write_text(json.dumps({'tools':{'substance-painter':{'path':'per-device.exe','port':60042}}}))
            with patch.dict(os.environ):
                os.environ.pop('PAINTER_PORT',None)
                self.assertEqual(env.settings(p)['port'],60042)

    def test_stale_explicit_executable_does_not_silently_select_another(self):
        with self.assertRaises(FileNotFoundError):
            env.resolve_executable({'path':'missing-painter-install.exe'},running=[],candidates=[])

    def test_separate_installations_need_explicit_selection(self):
        with tempfile.TemporaryDirectory() as root:
            files=[Path(root)/name for name in ('A.exe','B.exe')]
            for p in files:p.touch()
            with self.assertRaises(RuntimeError):
                env.resolve_executable({},running=[],candidates=list(map(str,files)))

    def test_hidden_handle_is_not_visible(self):
        p=[{'ProcessId':1,'MainWindowHandle':123,'WindowVisible':False},
           {'ProcessId':2,'MainWindowHandle':456,'WindowVisible':True}]
        result=env.instance_status({'pid':1},p)
        self.assertEqual(result['visible_window_pids'],[2])
        self.assertFalse(result['backend_window_visible'])
        self.assertTrue(result['other_visible_instance'])
        self.assertTrue(result['target_pid_required'])

    def test_raw_code_default_is_guarded_before_any_request(self):
        for run in (lambda:sp.py('RESULT=1'),lambda:sp.js('1')):
            with patch.object(sp,'guard_instance',side_effect=sp.PainterError('ambiguous')), patch.object(sp.http.client,'HTTPConnection') as http:
                with self.assertRaises(sp.PainterError):run()
                http.assert_not_called()

    def test_multiple_instances_reject_unpinned_mutation(self):
        with patch.dict(os.environ), patch.object(sp.os,'name','nt'), patch.object(env,'windows_processes',return_value=[{'ProcessId':1},{'ProcessId':2}]):
            os.environ.pop('PAINTER_EXPECT_PID',None)
            with self.assertRaisesRegex(sp.PainterError,'Multiple Painter'):sp.guard_instance()

    def test_expected_pid_must_be_the_remote_pid(self):
        with patch.dict(os.environ,{'PAINTER_EXPECT_PID':'2'}), patch.object(sp,'py',return_value=1) as probe:
            with self.assertRaisesRegex(sp.PainterError,'PID differs'):sp.guard_instance()
            self.assertFalse(probe.call_args.kwargs['mutating'])


if __name__=='__main__':unittest.main()
