"""Regression checks for the single universal source and moved helper imports."""
import os
from pathlib import Path
import runpy
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


def read_module(path):
    cwd, search_path = Path.cwd(), list(sys.path)
    try:
        return runpy.run_path(str(path))
    finally:
        os.chdir(cwd)
        sys.path[:] = search_path


class SkillLayoutTests(unittest.TestCase):
    def test_agent_adapters_share_the_same_source_files(self):
        source = ROOT / '.claude' / 'skills'
        self.assertFalse(source.is_symlink())
        self.assertFalse(getattr(source.stat(follow_symlinks=False), 'st_file_attributes', 0) & 0x400)
        self.assertFalse(os.path.lexists(ROOT / 'skills'))
        for adapter in (ROOT / '.agents/skills', ROOT / '.claude/skills'):
            if not adapter.exists():
                self.skipTest('Run scripts/tools/setup_agent_skill_link.py for local discovery links')
            self.assertTrue(os.path.samefile(adapter, source))
            for entry in source.glob('*/SKILL.md'):
                self.assertTrue(os.path.samefile(entry, adapter / entry.relative_to(source)))

    def test_xml_checker_and_merger_still_find_repo_from_all_entrypoints(self):
        for prefix in ('.agents/skills', '.claude/skills'):
            for relative in ('aoe-xml/scripts/xmlcheck.py', 'vanilla-merge/scripts/mergetool.py'):
                path = ROOT / prefix / relative
                if path.exists():
                    module = read_module(path)
                    self.assertEqual(Path(module['REPO']).resolve(), ROOT)

    def test_deployment_and_string_tools_use_the_single_bar_implementation(self):
        deploy = read_module(ROOT / '.claude/skills/mod-deploy-check/scripts/prezip_check.py')
        self.assertIsNotNone(deploy['BARTOOL'])
        expected = ROOT / '.claude/skills/aoe3de-bar-archives/scripts/bartool.py'
        self.assertEqual(Path(deploy['BARTOOL'].__file__).resolve(), expected)
        strings = read_module(ROOT / 'scripts/tools/stringsync.py')
        self.assertEqual(Path(strings['SKILL']).resolve(), expected.parent)

    def test_exporter_reads_universal_source(self):
        module = read_module(ROOT / 'scripts/tools/public_skill_sync.py')
        self.assertEqual(module['SOURCE_ROOT'], ROOT / '.claude' / 'skills')

    def test_setup_refuses_real_skill_directory_before_any_changes(self):
        module = read_module(ROOT / 'scripts/tools/setup_agent_skill_link.py')
        setup = module['setup']
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / '.claude/skills'
            (source / 'example').mkdir(parents=True)
            (source / 'example/SKILL.md').write_text('example', encoding='utf-8')
            legacy = root / '.agents/skills'
            legacy.mkdir(parents=True)
            sentinel = legacy / 'SKILL.md'
            sentinel.write_text('preserve me', encoding='utf-8')
            with self.assertRaises(SystemExit):
                setup(root)
            self.assertEqual(sentinel.read_text(encoding='utf-8'), 'preserve me')
            self.assertTrue((source / 'example/SKILL.md').is_file())

    def test_check_mode_never_creates_missing_adapters(self):
        setup = read_module(ROOT / 'scripts/tools/setup_agent_skill_link.py')['setup']
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / '.claude/skills/example').mkdir(parents=True)
            (root / '.claude/skills/example/SKILL.md').write_text('example', encoding='utf-8')
            with self.assertRaises(SystemExit):
                setup(root, check=True)
            self.assertFalse((root / '.agents').exists())
            self.assertTrue((root / '.claude/skills/example/SKILL.md').exists())

    def test_new_skills_and_edits_share_identity_in_both_directions(self):
        setup = read_module(ROOT / 'scripts/tools/setup_agent_skill_link.py')['setup']
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / '.claude/skills'
            (source / 'initial').mkdir(parents=True)
            (source / 'initial/SKILL.md').write_text('initial')
            setup(root)
            alias = root / '.agents/skills'
            try:
                (alias / 'codex-created').mkdir()
                (alias / 'codex-created/SKILL.md').write_text('created via Codex')
                self.assertEqual((source / 'codex-created/SKILL.md').read_text(), 'created via Codex')
                (source / 'codex-created/SKILL.md').write_text('edited via Claude')
                self.assertEqual((alias / 'codex-created/SKILL.md').read_text(), 'edited via Claude')
                self.assertTrue(os.path.samefile(alias / 'codex-created/SKILL.md', source / 'codex-created/SKILL.md'))
                setup(root, check=True)
            finally:
                if os.name == 'nt':
                    os.rmdir(alias)
                else:
                    alias.unlink()


if __name__ == '__main__':
    unittest.main()
