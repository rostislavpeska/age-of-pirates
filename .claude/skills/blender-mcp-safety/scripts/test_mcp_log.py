import contextlib
import io
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
import mcp_log as M


class LogTests(unittest.TestCase):
    def test_operation_ids_keep_interleaved_results_separate(self):
        with tempfile.TemporaryDirectory() as d, patch.object(M, 'LOG', Path(d) / 'events.jsonl'):
            a = M.begin('append A', 'R9', 'a.blend', 'astra', 'op-a')
            b = M.begin('append B', 'R9', 'b.blend', 'claude', 'op-b')
            M.finish(a['operation_id'], 'UNKNOWN', 'lost reply')
            self.assertEqual(M.operation_status('op-a')['status'], 'UNKNOWN')
            self.assertEqual(M.operation_status('op-b')['status'], 'IN_PROGRESS')
            with self.assertRaises(ValueError):
                M.begin('append A', 'R9', 'a.blend', 'astra', 'op-a')
            M.finish('op-a', 'VERIFIED', 'readback reconciled')
            self.assertEqual(M.operation_status('op-a')['status'], 'VERIFIED')

    def test_unknown_operation_cannot_complete(self):
        with tempfile.TemporaryDirectory() as d, patch.object(M, 'LOG', Path(d) / 'events.jsonl'):
            with self.assertRaises(ValueError):
                M.finish('missing', 'VERIFIED', 'claimed')


if __name__ == '__main__':
    unittest.main()
