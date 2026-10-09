"""live_publish.py: published is not delivered until the viewer's fresh heartbeat shows the same bytes and scene."""
import json
import sys
import tempfile
import threading
import time
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
import live_publish as LP  # noqa: E402


def now():
    return time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())


class LivePublish(unittest.TestCase):
    def setUp(self):
        t = tempfile.TemporaryDirectory(); self.addCleanup(t.cleanup)
        self.root = Path(t.name); self.live = self.root / 'live'
        self.src = self.root / 'Model.blend'; self.src.write_bytes(b'checkpoint bytes')
        self.ptr = LP.publish(self.live, self.src, 'uv-r4-pub02', 'Castle | UV r4 OPERATOR')

    def viewer(self, delay=.2, **over):
        st = {'pid': 4242, 'loaded_version': self.ptr['version'], 'file': self.ptr['file'], 'file_sha256': self.ptr['sha256'],
              'scene': self.ptr['scene'], 'at': now(), 'stashed': [], 'error': None}
        st.update(over)

        def run():
            time.sleep(delay); (self.live / 'VIEWER_STATE.json').write_text(json.dumps(st), encoding='utf-8')
        threading.Thread(target=run, daemon=True).start()

    def test_no_viewer_is_not_visible(self):
        ok, res = LP.wait_readback(self.live, self.ptr, wait=.5, poll=.1)
        self.assertFalse(ok); self.assertIn('no viewer heartbeat', res['why'][0])
        self.assertFalse((self.live / 'uv-r4-pub02' / 'LIVE_READBACK.json').exists())

    def test_matching_fresh_heartbeat_is_delivered(self):
        self.viewer()
        ok, rb = LP.wait_readback(self.live, self.ptr, wait=3, poll=.1)
        self.assertTrue(ok)
        self.assertEqual((rb['version'], rb['file_sha256'], rb['scene'], rb['viewer']),
                         (self.ptr['version'], self.ptr['sha256'], self.ptr['scene'], 'pid 4242'))
        self.assertEqual(json.loads((self.live / 'uv-r4-pub02' / 'LIVE_READBACK.json').read_text())['file_sha256'], self.ptr['sha256'])

    def test_viewer_stuck_on_an_older_version_is_not_delivered(self):
        self.viewer(loaded_version='uv-r1-pub01', file_sha256='0' * 64)          # the 2026-10-09 failure
        ok, res = LP.wait_readback(self.live, self.ptr, wait=.8, poll=.1)
        self.assertFalse(ok); self.assertTrue(any("viewer shows 'uv-r1-pub01'" in w for w in res['why']))

    def test_stale_heartbeat_or_viewer_error_is_not_delivered(self):
        self.viewer(at='2026-10-09T00:00:00Z')
        ok, res = LP.wait_readback(self.live, self.ptr, wait=.8, poll=.1)
        self.assertFalse(ok); self.assertTrue(any('stale' in w for w in res['why']))
        self.viewer(error='RuntimeError: cannot open file')
        ok, res = LP.wait_readback(self.live, self.ptr, wait=.8, poll=.1)
        self.assertFalse(ok); self.assertTrue(any('viewer error' in w for w in res['why']))

    def test_cli_exit_codes(self):
        self.assertEqual(LP.main(['--live', str(self.live), '--source', str(self.src), '--version', 'v9', '--scene', 'S', '--wait', '.3']), 4)


if __name__ == '__main__':
    unittest.main()
