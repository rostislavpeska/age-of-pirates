"""Portable ZIP/clone setup checks; fixture needs no Git repository or installed apps."""
from pathlib import Path
import os
import runpy
import tempfile
import unittest

HERE = Path(__file__).resolve().parent
HELPER = next(p for p in (HERE / 'setup_repo_skill_links.py', HERE / 'setup_agent_skill_link.py') if p.is_file())
setup = runpy.run_path(str(HELPER))['setup']


class AgentSetupTests(unittest.TestCase):
    def test_zip_setup_is_idempotent_and_new_skills_share_identity(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            source = root / '.claude/skills'
            (source / 'initial').mkdir(parents=True)
            (source / 'initial/SKILL.md').write_text('initial')
            alias = root / '.agents/skills'
            with self.assertRaises(SystemExit):
                setup(root, check=True)
            self.assertFalse(alias.exists())
            setup(root)
            try:
                setup(root)
                (alias / 'new-skill').mkdir()
                (alias / 'new-skill/SKILL.md').write_text('created through Codex')
                actual = source / 'new-skill/SKILL.md'
                self.assertEqual(actual.read_text(), 'created through Codex')
                actual.write_text('edited through Claude')
                self.assertEqual((alias / 'new-skill/SKILL.md').read_text(), 'edited through Claude')
                self.assertTrue(os.path.samefile(actual, alias / 'new-skill/SKILL.md'))
                setup(root, check=True)
            finally:
                if os.name == 'nt': os.rmdir(alias)
                else: alias.unlink()

    def test_existing_copy_is_preserved(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / '.claude/skills/demo').mkdir(parents=True)
            (root / '.claude/skills/demo/SKILL.md').write_text('source')
            conflict = root / '.agents/skills/demo'
            conflict.mkdir(parents=True)
            (conflict / 'SKILL.md').write_text('preserve')
            with self.assertRaises(SystemExit): setup(root)
            self.assertEqual((conflict / 'SKILL.md').read_text(), 'preserve')


if __name__ == '__main__': unittest.main()
