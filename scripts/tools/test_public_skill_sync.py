import importlib.util
from pathlib import Path
import tempfile
import unittest


MODULE_PATH = Path(__file__).with_name("public_skill_sync.py")
SPEC = importlib.util.spec_from_file_location("public_skill_sync", MODULE_PATH)
sync = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(sync)


class PublicSkillSyncTests(unittest.TestCase):
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
