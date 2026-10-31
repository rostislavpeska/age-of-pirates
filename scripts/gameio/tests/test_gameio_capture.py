"""gameio.capture offline: shot() deletes the old file first, refuses a missing / empty / stale result, and writes
the sidecar that says who was in front; Recorder reports a failed start and verifies its file. The grab, the
window lookups, ffmpeg and sleeps are all faked - nothing is captured or started."""
import json
import os
import sys
import time
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO))
from scripts.gameio import capture, win  # noqa: E402


class FakeImage:
    size = (2560, 1080)

    def __init__(self, write=True, age_s=0.0):
        self.write, self.age_s = write, age_s

    def save(self, path):
        if self.write:
            Path(path).write_bytes(b"\x89PNG fake")
            if self.age_s:
                old = time.time() - self.age_s
                os.utime(path, (old, old))


@pytest.fixture
def fake_win(monkeypatch):
    state = {"hwnd": 4242, "fg": False, "grabs": []}
    monkeypatch.setattr(win, "find_window", lambda title=win.GAME_TITLE: state["hwnd"])
    monkeypatch.setattr(win, "client_rect", lambda h: (0, 0, 2560, 1080) if h else None)
    monkeypatch.setattr(win, "is_foreground", lambda h: state["fg"])
    monkeypatch.setattr(win, "foreground_title", lambda: win.GAME_TITLE if state["fg"] else "Visual Studio Code")
    monkeypatch.setattr(win, "screen_size", lambda: (2560, 1080))
    monkeypatch.setattr(win, "virtual_screen", lambda: (-1920, 0, 4480, 1080))
    monkeypatch.setattr(capture, "mean_brightness", lambda img: 42.0)
    monkeypatch.setattr(capture, "window_image", lambda *a, **k: pytest.fail("PrintWindow called"))
    monkeypatch.setattr(capture, "pixel", lambda *a, **k: pytest.fail("GetPixel called"))
    return state


def _grab_with(state, img):
    def grab(bbox=None, all_screens=True):
        state["grabs"].append(bbox)
        return img
    return grab


def test_shot_raises_when_the_file_does_not_appear(tmp_path, fake_win, monkeypatch):
    out = tmp_path / "verify.png"
    out.write_bytes(b"an older target's picture")          # camera.py analysed such a stale file (review F5)
    (tmp_path / "verify.png.json").write_text("{}")
    monkeypatch.setattr(capture, "grab", _grab_with(fake_win, FakeImage(write=False)))
    with pytest.raises(RuntimeError, match="did not appear"):
        capture.shot(out)
    assert not out.exists() and not (tmp_path / "verify.png.json").exists()


def test_shot_raises_on_an_empty_or_stale_file(tmp_path, fake_win, monkeypatch):
    class Empty(FakeImage):
        def save(self, path):
            Path(path).write_bytes(b"")
    monkeypatch.setattr(capture, "grab", _grab_with(fake_win, Empty()))
    with pytest.raises(RuntimeError, match="empty"):
        capture.shot(tmp_path / "a.png")
    monkeypatch.setattr(capture, "grab", _grab_with(fake_win, FakeImage(age_s=3600)))
    with pytest.raises(RuntimeError, match="not fresh"):
        capture.shot(tmp_path / "b.png")


def test_shot_writes_the_sidecar(tmp_path, fake_win, monkeypatch):
    monkeypatch.setattr(capture, "grab", _grab_with(fake_win, FakeImage()))
    p = capture.shot(tmp_path / "sub" / "s.png")
    assert p == tmp_path / "sub" / "s.png" and p.is_file()
    meta = json.loads((tmp_path / "sub" / "s.png.json").read_text(encoding="utf-8"))
    assert meta["mode"] == "screen" and meta["area"] == "client" and meta["bbox"] == [0, 0, 2560, 1080]
    assert meta["game_foreground"] is False and meta["foreground_title"] == "Visual Studio Code"
    assert meta["game_foreground_before"] is False and meta["game_foreground_after"] is False
    assert meta["client_rect"] == [0, 0, 2560, 1080] and meta["size"] == [2560, 1080]
    assert meta["mean_brightness"] == 42.0 and meta["hwnd"] == 4242 and "time" in meta
    assert fake_win["grabs"] == [(0, 0, 2560, 1080)]


@pytest.mark.parametrize("before,after", [(True, True), (True, False), (False, True)])
def test_the_foreground_is_read_right_around_the_grab(tmp_path, fake_win, monkeypatch, before, after):
    # review F6: sampled after the PNG was encoded, the sidecar could disagree with the image
    order = []
    fake_win["fg"] = before

    def grab(bbox=None, all_screens=True):
        order.append("grab")
        fake_win["fg"] = after                                  # the owner switches during the grab
        return FakeImage()

    def is_fg(h):
        order.append("fg")
        return fake_win["fg"]
    monkeypatch.setattr(capture, "grab", grab)
    monkeypatch.setattr(win, "is_foreground", is_fg)
    capture.shot(tmp_path / "s.png")
    meta = json.loads((tmp_path / "s.png.json").read_text(encoding="utf-8"))
    assert order == ["fg", "grab", "fg"]
    assert (meta["game_foreground_before"], meta["game_foreground_after"]) == (before, after)
    assert meta["game_foreground"] is (before and after)


def test_a_failed_grab_is_a_runtime_error(tmp_path, fake_win, monkeypatch):
    def grab(bbox=None, all_screens=True):
        raise OSError("screen grab failed")                   # ImageGrab on a locked / secure desktop
    monkeypatch.setattr(capture, "grab", grab)
    with pytest.raises(RuntimeError, match="the capture failed"):
        capture.shot(tmp_path / "s.png")
    assert not (tmp_path / "s.png").exists() and not (tmp_path / "s.png.json").exists()


def test_shot_areas(tmp_path, fake_win, monkeypatch):
    monkeypatch.setattr(capture, "grab", _grab_with(fake_win, FakeImage()))
    capture.shot(tmp_path / "all.png", area="all")
    fake_win["hwnd"] = None
    capture.shot(tmp_path / "prim.png")                     # no game window -> the primary monitor (probe.py shot)
    assert fake_win["grabs"] == [(-1920, 0, 2560, 1080), (0, 0, 2560, 1080)]
    meta = json.loads((tmp_path / "prim.png.json").read_text(encoding="utf-8"))
    assert meta["area"] == "primary" and meta["game_foreground"] is False and meta["client_rect"] is None
    with pytest.raises(RuntimeError, match="needs the game window"):
        capture.shot(tmp_path / "w.png", mode="window")
    with pytest.raises(RuntimeError):
        capture.shot(tmp_path / "c.png", area="client")
    with pytest.raises(ValueError):
        capture.shot(tmp_path / "x.png", mode="video")


def test_shot_window_mode_uses_printwindow(tmp_path, fake_win, monkeypatch):
    calls = []
    monkeypatch.setattr(capture, "window_image", lambda hwnd, **k: calls.append(hwnd) or FakeImage())
    monkeypatch.setattr(capture, "grab", lambda *a, **k: pytest.fail("screen grab in window mode"))
    capture.shot(tmp_path / "w.png", mode="window")
    meta = json.loads((tmp_path / "w.png.json").read_text(encoding="utf-8"))
    assert calls == [4242] and meta["mode"] == "window" and meta["area"] == "client"


# ------------------------------------------------------------------ Recorder
class FakeProc:
    def __init__(self, alive, on_wait=None):
        self.alive, self.on_wait, self.stdin_data = alive, on_wait, b""
        outer = self

        class Stdin:
            def write(self, b):
                outer.stdin_data += b

            def flush(self):
                pass
        self.stdin = Stdin()

    def poll(self):
        return None if self.alive else 1

    def wait(self, timeout=None):
        if self.on_wait:
            self.on_wait()
        return 0

    def kill(self):
        pass


@pytest.fixture
def no_sleep(monkeypatch):
    monkeypatch.setattr("time.sleep", lambda s: None)
    monkeypatch.setattr(win, "screen_size", lambda: (2560, 1080))       # the gdigrab region default (review F7)


def test_recorder_without_ffmpeg(tmp_path, monkeypatch, no_sleep):
    monkeypatch.setattr(capture, "find_ffmpeg", lambda: None)
    monkeypatch.setattr(capture.subprocess, "Popen", lambda *a, **k: pytest.fail("Popen without ffmpeg"))
    r = capture.Recorder(tmp_path / "v.mp4", 10)
    assert r.start() is False and r.stop() is False


def test_recorder_falls_back_and_reports_a_dead_start(tmp_path, monkeypatch, no_sleep):
    started, flags = [], []

    def popen(args, **k):
        started.append(args)
        flags.append(k.get("creationflags"))
        return FakeProc(alive=False)
    monkeypatch.setattr(capture.subprocess, "Popen", popen)
    r = capture.Recorder(tmp_path / "v.mp4", 10, ffmpeg="ffmpeg")
    assert r.start() is False
    assert [a[a.index("-filter_complex") + 1] if "-filter_complex" in a else a[a.index("-f") + 1] for a in started] \
        == ["ddagrab=framerate=30,hwdownload,format=bgra", "gdigrab"]
    # gdigrab records the primary monitor, not the 5120x1602 virtual desktop (review F7); no console window
    gdi = started[1]
    assert gdi[gdi.index("-video_size") + 1] == "2560x1080" and gdi[gdi.index("-offset_x") + 1] == "0"
    assert gdi.index("-video_size") < gdi.index("-i")
    assert flags == [getattr(capture.subprocess, "CREATE_NO_WINDOW", 0)] * 2


def test_recorder_start_stop_verifies_the_file(tmp_path, monkeypatch, no_sleep):
    out = tmp_path / "v.mp4"
    out.write_bytes(b"old")
    proc = FakeProc(alive=True, on_wait=lambda: out.write_bytes(b"mp4 data"))
    monkeypatch.setattr(capture.subprocess, "Popen", lambda args, **k: proc)
    r = capture.Recorder(out, 12, fps=10, width=1280, ffmpeg="ffmpeg")
    assert r.start() is True and r.how == "ddagrab" and not out.exists()      # the old file was removed first
    assert r.stop() is True and proc.stdin_data == b"q"
    proc2 = FakeProc(alive=True)                                                # ffmpeg wrote nothing
    monkeypatch.setattr(capture.subprocess, "Popen", lambda args, **k: proc2)
    r2 = capture.Recorder(tmp_path / "none.mp4", 12, ffmpeg="ffmpeg")
    assert r2.start() is True and r2.stop() is False


def test_recorder_commands():
    r = capture.Recorder("v.mp4", 12, fps=10, width=1280)
    (n1, dda), (n2, gdi) = r.commands("ff")
    assert n1 == "ddagrab" and dda[:4] == ["ff", "-y", "-t", "12"]
    assert dda[dda.index("-filter_complex") + 1] == "ddagrab=framerate=10,hwdownload,format=bgra,scale=1280:-2"
    assert n2 == "gdigrab" and gdi[gdi.index("-vf") + 1] == "scale=1280:-2" and gdi[-1] == "v.mp4"
    assert "-offset_x" not in gdi                                           # no region yet: start() fills it
    r = capture.Recorder("v.mp4", 12, region=(2560, 0, 1920, 1080))
    gdi = r.commands("ff")[1][1]
    i = gdi.index("-offset_x")
    assert gdi[i:i + 7] == ["-offset_x", "2560", "-offset_y", "0", "-video_size", "1920x1080", "-i"]
