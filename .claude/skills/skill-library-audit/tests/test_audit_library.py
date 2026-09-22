"""Failure fixtures for file closure and non-executing prerequisite checks."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[1] / 'scripts' / 'audit_library.py'
SPEC = importlib.util.spec_from_file_location('audit_library', SCRIPT)
audit_module = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(audit_module)


class ResourceAuditTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / 'skills'
        self.root.mkdir()

    def package(self, name='demo', body='', files=None, skills=None, external=None):
        folder = self.root / name
        folder.mkdir()
        (folder / 'SKILL.md').write_text(
            f'---\nname: {name}\ndescription: Fixture package.\n---\n{body}', encoding='utf-8')
        (folder / 'resources.json').write_text(json.dumps({
            'schemaVersion': 1, 'files': ['SKILL.md', *(files or [])],
            'skills': skills or [], 'external': external or []}), encoding='utf-8')
        return folder

    def tool(self, optional=False):
        return {'id': 'editor', 'kind': 'application', 'requiredFor': ['edit'],
                'optional': optional, 'note': 'Requires a verified editor session.'}

    def test_complete_isolated_package_passes(self):
        folder = self.package(body='[Guide](guide.md)', files=['guide.md'])
        (folder / 'guide.md').write_text('A local guide.', encoding='utf-8')
        self.assertEqual(audit_module.audit(self.root)['exitCode'], 0)

    def test_deleted_reference_fails(self):
        self.package(body='[Guide](guide.md)', files=['guide.md'])
        result = audit_module.audit(self.root)
        self.assertEqual(result['exitCode'], 1)
        self.assertTrue(any('missing resource' in e for e in result['errors']))

    def test_missing_companion_fails(self):
        self.package(skills=['absent'])
        self.assertTrue(any('absent: missing SKILL.md' in e for e in audit_module.audit(self.root)['errors']))

    def test_transitive_dependency_is_checked(self):
        self.package(skills=['middle'])
        self.package('middle', skills=['leaf'])
        self.package('leaf', files=['missing.txt'])
        result = audit_module.audit(self.root, ['demo'])
        self.assertEqual(set(result['packages']), {'demo', 'middle', 'leaf'})
        self.assertEqual(result['exitCode'], 1)

    def test_declared_cycle_terminates(self):
        self.package(skills=['peer'])
        self.package('peer', skills=['demo'])
        self.assertEqual(audit_module.audit(self.root, ['demo'])['exitCode'], 0)

    def test_undeclared_companion_link_fails(self):
        self.package(body='[Other](../peer/SKILL.md)')
        self.package('peer')
        self.assertTrue(any('undeclared companion' in e for e in audit_module.audit(self.root)['errors']))

    def test_path_escape_fails_even_when_file_exists(self):
        (self.root / 'outside.txt').write_text('outside package', encoding='utf-8')
        self.package(files=['../outside.txt'])
        self.assertTrue(any('escapes package' in e for e in audit_module.audit(self.root)['errors']))

    def test_link_escape_fails(self):
        self.package(body='[Outside](../../outside.txt)')
        self.assertTrue(any('escapes library' in e for e in audit_module.audit(self.root)['errors']))

    def test_literal_script_path_is_checked(self):
        self.package(body='Run `scripts/missing.py`.')
        self.assertTrue(any('literal resource' in e for e in audit_module.audit(self.root)['errors']))

    def test_missing_declaration_is_incomplete(self):
        folder = self.package()
        (folder / 'resources.json').unlink()
        result = audit_module.audit(self.root)
        self.assertEqual(result['packageIntegrity'], 'incomplete')
        self.assertEqual(result['exitCode'], 2)

    def test_invalid_declaration_fails(self):
        folder = self.package()
        (folder / 'resources.json').write_text('{"schemaVersion": 99}', encoding='utf-8')
        self.assertEqual(audit_module.audit(self.root)['exitCode'], 1)

    def test_unknown_external_command_field_rejected(self):
        item = self.tool()
        item['probeCommand'] = 'run arbitrary code'
        self.package(external=[item])
        self.assertEqual(audit_module.audit(self.root)['exitCode'], 1)

    def test_undeclared_import_is_not_executed(self):
        folder = self.package(files=['helper.py'])
        (folder / 'helper.py').write_text('import missing_dependency_xyz\nraise RuntimeError("must never run")\n', encoding='utf-8')
        result = audit_module.audit(self.root)
        self.assertTrue(any('undeclared Python import' in e for e in result['errors']))

    def test_new_unlisted_helper_fails(self):
        folder = self.package()
        (folder / 'new.py').write_text('pass\n', encoding='utf-8')
        self.assertTrue(any('undeclared bundled file' in e for e in audit_module.audit(self.root)['errors']))

    def test_required_app_missing_is_machine_limit_not_package_error(self):
        self.package(external=[self.tool()])
        with patch('subprocess.Popen', side_effect=AssertionError('no programs allowed')):
            result = audit_module.audit(self.root, machine=True, operation='edit')
        self.assertEqual(result['packageIntegrity'], 'passed')
        self.assertEqual(result['machine'][0]['status'], 'missing')
        self.assertEqual(result['exitCode'], 2)

    def test_optional_app_missing_does_not_block(self):
        self.package(external=[self.tool(optional=True)])
        self.assertEqual(audit_module.audit(self.root, machine=True)['exitCode'], 0)

    def test_configured_executable_not_run_or_assumed_compatible(self):
        program = Path(self.temp.name) / 'editor.exe'
        program.write_bytes(b'not executable')
        self.package(external=[self.tool()])
        with patch('subprocess.Popen', side_effect=AssertionError('no programs allowed')):
            result = audit_module.audit(self.root, machine=True, config={'editor': {'path': str(program)}})
        self.assertEqual(result['machine'][0]['status'], 'present-unverified')
        self.assertEqual(result['exitCode'], 2)

    def test_unknown_operation_does_not_bypass_requirements(self):
        self.package(external=[self.tool()])
        self.assertEqual(audit_module.audit(self.root, machine=True, operation='typo')['exitCode'], 1)

    def test_operation_skips_unrelated_application(self):
        item = {'id': 'archive', 'kind': 'directory', 'requiredFor': ['read'],
                'optional': True, 'note': 'Archive source.'}
        self.package(external=[self.tool(), item])
        result = audit_module.audit(self.root, machine=True, operation='read')
        self.assertEqual(result['machine'][0]['status'], 'not-required')
        self.assertEqual(result['exitCode'], 0)

    def test_config_refuses_commands(self):
        config = Path(self.temp.name) / 'tools.json'
        config.write_text(json.dumps({'tools': {'editor': {'path': '', 'command': 'unsafe'}}}), encoding='utf-8')
        with self.assertRaises(ValueError):
            audit_module.local_config(config)

    def test_external_urls_are_unchecked_not_fetched(self):
        self.package(body='[Reference](https://example.invalid/missing)')
        result = audit_module.audit(self.root)
        self.assertEqual(result['exitCode'], 0)
        self.assertEqual(result['externalLinksUnchecked'], ['https://example.invalid/missing'])


if __name__ == '__main__':
    unittest.main()
