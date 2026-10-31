import hashlib
import json
from pathlib import Path
import runpy
import tempfile
import unittest

check = runpy.run_path(str(Path(__file__).resolve().parents[1] / 'scripts/check_reference_bundle.py'))['check']


class ReferenceIntegrityTests(unittest.TestCase):
    def test_line_endings_are_portable_and_truncation_is_detected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            refs = root / 'references'
            refs.mkdir()
            payload = b'function one\nfunction two\n'
            (refs / 'sources.json').write_text(json.dumps({'entries': [{'file': 'example.xs', 'normalizedSha256': hashlib.sha256(payload).hexdigest()}]}))
            source = refs / 'example.xs'
            source.write_bytes(payload.replace(b'\n', b'\r\n'))
            self.assertEqual(check(root), [])
            source.write_bytes(b'function one\n')
            self.assertTrue(check(root))
            source.unlink()
            self.assertTrue(check(root))

    def test_actual_bundle(self):
        self.assertEqual(check(Path(__file__).resolve().parents[1]), [])


if __name__ == '__main__': unittest.main()
