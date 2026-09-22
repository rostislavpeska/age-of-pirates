import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch


MODULE_PATH = Path(__file__).with_name("public_skill_sync.py")
SPEC = importlib.util.spec_from_file_location("public_skill_sync", MODULE_PATH)
sync = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(sync)


class PublicSkillSyncTests(unittest.TestCase):
    def test_new_package_requires_explicit_onboarding_and_no_prior_baseline(self):
        with tempfile.TemporaryDirectory() as tmp:
            source = Path(tmp) / 'demo'
            source.mkdir()
            (source / 'SKILL.md').write_text('---\nname: demo\ndescription: Example\n---\n')
            destination = Path(tmp) / 'missing'
            with self.assertRaises(ValueError):
                sync.skill_status(source, destination, 'demo', None, 'export')
            self.assertEqual(sync.skill_status(source, destination, 'demo', None, 'export', True), 'new-public')
            for command, base in [('import', None), ('export', 'existing-baseline')]:
                with self.assertRaises(ValueError):
                    sync.skill_status(source, destination, 'demo', base, command, True)

    def test_release_audit_refuses_omitted_companion(self):
        with self.assertRaisesRegex(ValueError, 'resource audit'):
            sync.audit_release(sync.SOURCE_ROOT, ['aoe3de-building-export'])

    def test_public_root_refuses_legacy_tree(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / '.claude/skills').mkdir(parents=True)
            self.assertEqual(sync.public_root(root), root / '.claude/skills')
            (root / 'skills').mkdir()
            with self.assertRaises(ValueError):
                sync.public_root(root)

    def test_failed_replacement_restores_previous_package(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            source, dest = root / 'src/demo', root / 'dst/demo'
            source.mkdir(parents=True); dest.mkdir(parents=True)
            header = '---\nname: demo\ndescription: Example\n---\n'
            (source / 'SKILL.md').write_text(header + 'new')
            (dest / 'SKILL.md').write_text(header + 'old')
            original = Path.rename
            def fail_incoming(path, target):
                if path.name.endswith('.sync-new'):
                    raise OSError('simulated rename failure')
                return original(path, target)
            with patch.object(Path, 'rename', fail_incoming):
                with self.assertRaises(OSError):
                    sync.replace_tree(source, dest)
            self.assertEqual((dest / 'SKILL.md').read_text(), header + 'old')

    def test_change_direction_and_conflict_classification(self):
        self.assertEqual(sync.classify("a", "a", None), "untracked-equal")
        self.assertEqual(sync.classify("a", "b", None), "untracked-different")
        self.assertEqual(sync.classify("new", "base", "base"), "aop-ahead")
        self.assertEqual(sync.classify("base", "new", "base"), "public-ahead")
        self.assertEqual(sync.classify("a", "b", "base"), "conflict")
        self.assertEqual(sync.classify("new", "new", "base"), "equal")

    def test_adapter_export_import_and_conflict(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            aop, public = root / "aop", root / "public"
            aop.mkdir()
            public.mkdir()
            source = aop / "CLAUDE.md"
            source.write_text("@AGENTS.md\n", encoding="utf-8")
            old_root = sync.ROOT
            sync.ROOT = aop
            try:
                state = {}
                mapping = {"CLAUDE.md": "CLAUDE.md"}
                self.assertEqual(sync.sync_support_files(mapping, public, "test", state, "export", False), (False, False))
                self.assertFalse((public / "CLAUDE.md").exists())
                self.assertEqual(sync.sync_support_files(mapping, public, "test", state, "export", True), (False, True))
                (public / "CLAUDE.md").write_text("@./AGENTS.md\n", encoding="utf-8")
                self.assertEqual(sync.sync_support_files(mapping, public, "test", state, "import", True), (False, True))
                self.assertEqual(source.read_bytes(), (public / "CLAUDE.md").read_bytes())
                source.write_text("local\n", encoding="utf-8")
                (public / "CLAUDE.md").write_text("external\n", encoding="utf-8")
                self.assertEqual(sync.sync_support_files(mapping, public, "test", state, "export", True), (True, False))
                self.assertEqual((public / "CLAUDE.md").read_text(), "external\n")
            finally:
                sync.ROOT = old_root

    def test_safety_scan_rejects_private_path_and_binary(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "note.md").write_text(r"C:\Users\Owner\private", encoding="utf-8")
            (root / "tool.exe").write_bytes(b"MZ")
            with self.assertRaisesRegex(ValueError, "absolute Windows user path"):
                sync.safety_scan(root)

    def test_atomic_replacement_preserves_valid_skill(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            source = root / "source" / "demo-skill"
            destination = root / "destination" / "demo-skill"
            source.mkdir(parents=True)
            destination.mkdir(parents=True)
            header = "---\nname: demo-skill\ndescription: Demonstration.\n---\n"
            (source / "SKILL.md").write_text(header + "new\n", encoding="utf-8")
            (destination / "SKILL.md").write_text(header + "old\n", encoding="utf-8")
            sync.replace_tree(source, destination)
            self.assertEqual((destination / "SKILL.md").read_text(encoding="utf-8"), header + "new\n")


if __name__ == "__main__":
    unittest.main()
