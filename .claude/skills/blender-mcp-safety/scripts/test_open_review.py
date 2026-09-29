"""Offline tests for open_review.py: argument parsing and the port-wait polling loop only.

Never opens a real socket and never launches Blender - subprocess.Popen and the port
check are both monkeypatched/injected. Run with:
    python test_open_review.py
"""
import sys
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent))
import open_review  # noqa: E402
import mcp_log  # noqa: E402


class TestParseArgs(unittest.TestCase):
    def test_defaults(self):
        args = open_review.parse_args(["review.blend"])
        self.assertEqual(args.blend, "review.blend")
        self.assertIsNone(args.exe)
        self.assertEqual(args.port, 9876)
        self.assertEqual(args.timeout, 120.0)
        self.assertEqual(args.poll_interval, 2.0)
        self.assertFalse(args.force)

    def test_overrides(self):
        args = open_review.parse_args([
            "C:/tmp/review.blend", "--exe", "C:/blender/blender.exe",
            "--port", "9877", "--timeout", "5", "--poll-interval", "0.5", "--force",
        ])
        self.assertEqual(args.blend, "C:/tmp/review.blend")
        self.assertEqual(args.exe, "C:/blender/blender.exe")
        self.assertEqual(args.port, 9877)
        self.assertEqual(args.timeout, 5.0)
        self.assertEqual(args.poll_interval, 0.5)
        self.assertTrue(args.force)

    def test_missing_blend_path_errors(self):
        with self.assertRaises(SystemExit):
            open_review.parse_args([])


class TestWaitForPort(unittest.TestCase):
    """All of check_fn/sleep_fn/clock_fn are injected - no real time.sleep, no real socket."""

    def test_opens_immediately(self):
        opened, elapsed = open_review.wait_for_port(
            9876, timeout=10, check_fn=lambda p: True,
            sleep_fn=lambda s: self.fail("should not sleep when already open"),
            clock_fn=iter([0.0, 0.0]).__next__,
        )
        self.assertTrue(opened)
        self.assertEqual(elapsed, 0.0)

    def test_opens_after_a_few_polls(self):
        calls = {"n": 0}

        def check_fn(port):
            calls["n"] += 1
            return calls["n"] >= 3  # fails twice, then succeeds

        sleeps = []
        # clock advances by 1s per call; called once per loop iteration (elapsed check)
        # plus once at start and once on return -> give it a generous sequence.
        clock = iter([0.0, 0.0, 1.0, 1.0, 2.0, 2.0, 3.0, 3.0, 4.0])
        opened, elapsed = open_review.wait_for_port(
            9876, timeout=10, poll_interval=1.0, check_fn=check_fn,
            sleep_fn=lambda s: sleeps.append(s),
            clock_fn=clock.__next__,
        )
        self.assertTrue(opened)
        self.assertEqual(calls["n"], 3)
        self.assertEqual(sleeps, [1.0, 1.0])

    def test_times_out(self):
        sleeps = []
        clock = iter([0.0, 0.0, 1.0, 1.0, 2.0, 2.0, 3.0, 3.0])
        opened, elapsed = open_review.wait_for_port(
            9876, timeout=3.0, poll_interval=1.0, check_fn=lambda p: False,
            sleep_fn=lambda s: sleeps.append(s),
            clock_fn=clock.__next__,
        )
        self.assertFalse(opened)
        self.assertGreaterEqual(elapsed, 3.0)

    def test_never_calls_real_time_sleep_or_socket(self):
        # Guard against a regression that removes the injection points.
        with mock.patch("time.sleep", side_effect=AssertionError("real sleep called")), \
             mock.patch("socket.create_connection", side_effect=AssertionError("real socket used")):
            opened, _ = open_review.wait_for_port(
                9876, timeout=1, check_fn=lambda p: True,
            )
            self.assertTrue(opened)


class TestMainOrchestration(unittest.TestCase):
    """main() end-to-end but with launch_blender, port checks and logging all stubbed."""

    def test_refuses_when_port_already_open_without_force(self):
        with mock.patch.object(mcp_log, "port_open", return_value=True), \
             mock.patch.object(mcp_log, "write") as write_mock, \
             mock.patch.object(open_review, "launch_blender") as launch_mock:
            rc = open_review.main(["review.blend"])
        self.assertEqual(rc, 2)
        launch_mock.assert_not_called()
        self.assertTrue(any(c.args[0]["event"] == "open_review" and "refused" in c.args[0]["action"]
                             for c in write_mock.call_args_list))

    def test_force_launches_even_if_port_open(self):
        with mock.patch.object(mcp_log, "port_open", return_value=True), \
             mock.patch.object(mcp_log, "write"), \
             mock.patch.object(open_review, "launch_blender") as launch_mock, \
             mock.patch.object(open_review, "wait_for_port", return_value=(True, 1.2)):
            rc = open_review.main(["review.blend", "--force"])
        self.assertEqual(rc, 0)
        launch_mock.assert_called_once()

    def test_normal_launch_success(self):
        with mock.patch.object(mcp_log, "port_open", return_value=False), \
             mock.patch.object(mcp_log, "write") as write_mock, \
             mock.patch.object(open_review, "launch_blender") as launch_mock, \
             mock.patch.object(open_review, "wait_for_port", return_value=(True, 3.4)) as wait_mock:
            rc = open_review.main(["review.blend", "--exe", "blender.exe"])
        self.assertEqual(rc, 0)
        launch_mock.assert_called_once_with("blender.exe", Path("review.blend"))
        wait_mock.assert_called_once()
        self.assertTrue(any(c.args[0].get("mcp_port_open") is True for c in write_mock.call_args_list))

    def test_normal_launch_timeout(self):
        with mock.patch.object(mcp_log, "port_open", return_value=False), \
             mock.patch.object(mcp_log, "write"), \
             mock.patch.object(open_review, "launch_blender"), \
             mock.patch.object(open_review, "wait_for_port", return_value=(False, 120.0)):
            rc = open_review.main(["review.blend"])
        self.assertEqual(rc, 1)


if __name__ == "__main__":
    unittest.main()
