"""Offline tests of the harness client (no network, nothing billed): request validation, edit masks, dry run,
duplicate-call guard, ledger, Claude-only gate and make_mask.py.
python -m pytest .claude/skills/image-harness/scripts/test_generate_client.py -q
"""
import argparse
import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent


def load():
    spec = importlib.util.spec_from_file_location('harness_generate', HERE / 'generate.py')
    m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m); return m


G = load()


def args(**kw):
    base = dict(prompt='p', operation=None, provider=None, model=None, size=None, quality=None, background=None, n=None,
                output_format=None, aspect_ratio=None, image_size=None, ref=[], image=[], mask=None, input_fidelity=None)
    base.update(kw); return argparse.Namespace(**base)


class Client(unittest.TestCase):
    def setUp(self):
        self.d = Path(tempfile.mkdtemp())
        Image.new('RGB', (64, 32), (90, 90, 90)).save(self.d / 'in.png')
        m = Image.new('RGBA', (64, 32), (0, 0, 0, 255)); m.paste((0, 0, 0, 0), (0, 0, 16, 16)); m.save(self.d / 'mask.png')
        Image.new('RGBA', (32, 32), (0, 0, 0, 0)).save(self.d / 'wrong_size.png')
        Image.new('RGB', (64, 32), (0, 0, 0)).save(self.d / 'no_alpha.png')
        G.LEDGER = self.d / 'ledger.jsonl'

    def test_generate_is_unchanged(self):
        body, s = G.build_request(args(quality='low'))
        self.assertEqual((body['operation'], body['provider']), ('generate', 'openai'))
        self.assertNotIn('references', body); self.assertEqual(s['estimate_usd'], .011)

    def test_ref_routes_to_gemini(self):
        body, _ = G.build_request(args(ref=[str(self.d / 'in.png')]))
        self.assertEqual(body['provider'], 'gemini'); self.assertEqual(len(body['references']), 1)

    def test_edit_with_mask_routes_to_openai(self):
        body, s = G.build_request(args(image=[str(self.d / 'in.png')], mask=str(self.d / 'mask.png'), input_fidelity='high'))
        self.assertEqual((body['operation'], body['provider'], body['input_fidelity']), ('edit', 'openai', 'high'))
        self.assertIn('mask', body); self.assertTrue(s['mask_sha256'])

    def assertExit(self, fn, text):
        with self.assertRaises(SystemExit) as c:
            fn()
        self.assertIn(text, str(c.exception))

    def test_mask_rules_fail_before_paying(self):
        img = [str(self.d / 'in.png')]
        self.assertExit(lambda: G.build_request(args(image=img, mask=str(self.d / 'wrong_size.png'))), 'sizes must match')
        self.assertExit(lambda: G.build_request(args(image=img, mask=str(self.d / 'no_alpha.png'))), 'no alpha channel')
        self.assertExit(lambda: G.build_request(args(image=img, mask=str(self.d / 'mask.png'), provider='gemini')), 'needs --provider openai')
        self.assertExit(lambda: G.build_request(args(mask=str(self.d / 'mask.png'))), 'belongs to an edit')
        self.assertExit(lambda: G.build_request(args(operation='edit')), 'needs at least one --image')
        self.assertExit(lambda: G.build_request(args(ref=[str(self.d / 'in.png')], provider='openai')), 'needs --provider gemini')

    def test_duplicate_guard(self):
        _, s = G.build_request(args(quality='low'))
        self.assertIsNone(G.recent_duplicate(s['request_sha256']))
        G.ledger_append(dict(time=__import__('datetime').datetime.now().isoformat(timespec='seconds'), request_sha256=s['request_sha256'], files=['x']))
        self.assertIsNotNone(G.recent_duplicate(s['request_sha256']))
        _, s2 = G.build_request(args(quality='medium'))
        self.assertIsNone(G.recent_duplicate(s2['request_sha256']))

    def test_cli_dry_run_and_gate(self):
        env = dict(os.environ, CLAUDECODE='1', IMAGE_HARNESS_LEDGER=str(self.d / 'l.jsonl'))
        r = subprocess.run([sys.executable, str(HERE / 'generate.py'), 'edit it', '--out', str(self.d / 'o'), '--image', str(self.d / 'in.png'),
                            '--mask', str(self.d / 'mask.png'), '--dry-run'], capture_output=True, text=True, env=env)
        self.assertEqual(r.returncode, 0, r.stderr); self.assertIn('DRY RUN', r.stdout); self.assertFalse((self.d / 'l.jsonl').exists())
        env.pop('CLAUDECODE')
        r = subprocess.run([sys.executable, str(HERE / 'generate.py'), '--ledger'], capture_output=True, text=True, env=env)
        self.assertNotEqual(r.returncode, 0); self.assertIn('Claude-only', r.stderr + r.stdout)

    def test_openai_edit_is_never_sent(self):
        # INC-203: the multipart edit route hung the production n8n; the client refuses before loading any config.
        env = dict(os.environ, CLAUDECODE='1', IMAGE_HARNESS_LEDGER=str(self.d / 'l.jsonl'), IMAGE_HARNESS_URL='', IMAGE_HARNESS_KEY='')
        r = subprocess.run([sys.executable, str(HERE / 'generate.py'), 'edit it', '--out', str(self.d / 'o'), '--image', str(self.d / 'in.png'),
                            '--mask', str(self.d / 'mask.png')], capture_output=True, text=True, env=env)
        self.assertNotEqual(r.returncode, 0); self.assertIn('INC-203', r.stderr + r.stdout); self.assertFalse((self.d / 'l.jsonl').exists())

    def test_make_mask(self):
        out = self.d / 'm.png'
        r = subprocess.run([sys.executable, str(HERE / 'make_mask.py'), str(self.d / 'in.png'), str(out), '--rect', '0,0,32,16'],
                           capture_output=True, text=True)
        self.assertEqual(r.returncode, 0, r.stderr); self.assertIn('editable 25.0%', r.stdout)
        self.assertIsNone(G.check_mask(out, self.d / 'in.png'))


if __name__ == '__main__':
    unittest.main()
