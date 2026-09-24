"""mapview.camera and snapshots.py --world offline (2026-09-24): no input event, no window, no screenshot, no process,
no sleep. A fake Session records the clicks and moves, a fake capture writes prepared frames, and every real gameio
primitive (SendInput, SetForegroundWindow, ShowWindow, the screen grabs, the Recorder, the Win32 window queries,
subprocess, time.sleep) is replaced by one that fails the test (the sandbox/census/tests/test_gamewin.py pattern).

Two layers:
- control flow without PIL (runs on Linux CI): detection is scripted per frame (FakeImage + patched
  minimap_detect.probes_ok / find_trapezoid) - str and Path outputs, every refusal, the retry path, the states,
  the park point, record, the dry run, the map size and the CLI exit codes;
- the verification maths on the committed fixture crops (fixtures/ingame_hud_minimap.png, paris_editor_minimap.png,
  pasted back on a 2560x1080 canvas at their crop offsets; needs PIL): the in-match look-at (2448.7, 933.2), a
  5 px miss, an erased trapezoid then the real one, the clipped editor trapezoid, a dimmed frame, the ring park point.
- fix round 2026-09-24 (gameio review F1, F7-F13): the retry and every later batch target never call focus() (a
  plain check, NotForeground stops the batch), clipped is never retried (look_at None handled), a session must
  match dry_run, errors after a click are not exit 2, targets off the map and records with < 4 probes are refused;
  and two tests drive camera.py through the REAL gameio Session and the REAL capture.shot with only the Win32
  primitives simulated (SimDesk): a verified goto, and a world batch whose owner switches away after the first click.
snapshots.py imports scripts/aitest/driver.py, which calls Win32 at import: a stand-in module is put in sys.modules."""
import importlib.util
import json
import math
import runpy
import subprocess
import sys
import tempfile
import types
from functools import lru_cache
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO))
from scripts.gameio import capture, inputs, sheets, win  # noqa: E402
from scripts.mapview import camera  # noqa: E402
from scripts.mapview import minimap_detect as MD  # noqa: E402
from scripts.mapview import transform as T  # noqa: E402

FIXTURES = Path(__file__).resolve().parent / "fixtures"
SNAPSHOTS = REPO / "scripts" / "aitest" / "snapshots.py"
CLIENT = (0, 0, 2560, 1080)
LONDON = (360.0, 685.0)
# the in-match disc of the committed fixture (ingame_hud_minimap.json, measured 2026-09-24)
IG = {"cx": 2399.32, "cy": 899.31, "r": 147.0, "r_line": 153.35}
PROBE = [{"x": 2476, "y": 767, "rgb": [222, 182, 90]}] * camera.MIN_RING_PROBES     # scripted: content unused
# the real gameio primitives, kept before the autouse fixture replaces them (the real-Session test restores them)
REAL_SESSION, REAL_SHOT = inputs.Session, capture.shot


def _boom(*_a, **_k):
    raise AssertionError("a real input event, window change, screenshot, process or sleep happened")


@pytest.fixture(autouse=True)
def no_real_io(monkeypatch, tmp_path):
    for n in ("send_input", "set_foreground", "show_window"):
        monkeypatch.setattr(inputs, n, _boom)
    monkeypatch.setattr(inputs, "Session", _boom)                    # camera must go through camera.new_session
    for n in ("grab", "window_image", "shot", "pixel"):
        monkeypatch.setattr(capture, n, _boom)
    monkeypatch.setattr(capture.Recorder, "start", _boom)
    monkeypatch.setattr(capture.Recorder, "stop", _boom)
    for n in ("find_window", "client_rect", "is_foreground", "foreground_title", "cursor_pos", "dpi_aware",
              "virtual_screen", "window_rect"):
        monkeypatch.setattr(win, n, _boom)
    monkeypatch.setattr(subprocess, "run", _boom)
    monkeypatch.setattr(subprocess, "Popen", _boom)
    monkeypatch.setattr("time.sleep", _boom)
    monkeypatch.setenv("MAPVIEW_CAL_DIR", str(tmp_path / "cal"))
    monkeypatch.setattr(sheets, "SHEETS_DIR", tmp_path / "sheets")     # no park_mouse point unless a test writes one
    (tmp_path / "tmp").mkdir()
    monkeypatch.setattr(tempfile, "tempdir", str(tmp_path / "tmp"))    # camera's default out lands here


# ----------------------------------------------------------------------------- fakes
class FakeSession:
    """fg: whether the game is in front for check(); the owner 'switches away' by setting it False
    (fg_after_click: automatically after the n-th click)."""

    def __init__(self, focus_ok=True, dry_run=False, client=CLIENT, fg=True, fg_after_click=None):
        self.hwnd = 4242
        self.dry_run = dry_run
        self.focus_ok = focus_ok
        self.client = client
        self.fg = fg
        self.fg_after_click = fg_after_click
        self.log = []

    def client_rect(self):
        return self.client

    def focus(self):
        self.log.append({"event": "focus"})
        if self.focus_ok:
            self.fg = True
        return self.focus_ok

    def check(self, what="check"):
        self.log.append({"event": "check", "what": what})
        if not self.fg:
            raise inputs.NotForeground("%s: the game is not in the foreground - not sent" % what)

    def click(self, x, y, space="screen"):
        self.log.append({"event": "click", "x": x, "y": y, "space": space})
        if self.fg_after_click is not None and len(self.events("click")) >= self.fg_after_click:
            self.fg = False

    def move(self, x, y, space="screen"):
        self.log.append({"event": "move", "x": x, "y": y, "space": space})

    def wait(self, s, why=""):
        self.log.append({"event": "wait", "s": s})

    def events(self, kind):
        return [e for e in self.log if e["event"] == kind]


class FakeImage:
    """A frame without PIL: its detection results are scripted (probes, trapezoid) and every pixel is ring-dark."""

    def __init__(self, probes=True, trap=None, rgb=(40, 35, 24), size=(2560, 1080)):
        self.probes, self.trap, self.rgb, self.size = probes, trap, rgb, size

    def getpixel(self, xy):
        return self.rgb

    def crop(self, box):
        return FakeImage(size=(box[2] - box[0], box[3] - box[1]))

    def save(self, path, **_k):
        Path(path).write_bytes(b"fake frame")


class FakeCapture:
    """Writes the next prepared frame to the requested path (a PIL image or a FakeImage) plus the sidecar;
    foreground = one bool for every shot, or one per shot (the last repeats)."""

    def __init__(self, frames, foreground=True):
        self.frames, self.foreground = list(frames), foreground
        self.paths, self.by_path = [], {}

    def __call__(self, path, hwnd):
        assert hwnd == 4242
        path = Path(path)
        k = len(self.paths)
        frame = self.frames[min(k, len(self.frames) - 1)]
        fg = self.foreground[min(k, len(self.foreground) - 1)] if isinstance(self.foreground, list) else self.foreground
        path.parent.mkdir(parents=True, exist_ok=True)
        frame.save(str(path), compress_level=1)
        path.with_name(path.name + ".json").write_text(json.dumps({"game_foreground": fg}), encoding="utf-8")
        self.paths.append(path)
        self.by_path[str(path)] = frame
        return path


def trap(x, y, clipped=False):
    return {"look_at": (x, y), "clipped": clipped, "leg_support": 1.0}


def write_cal(screen="ingame", checked=True, accepted=True, probes=None, resid=1.3, offset=(0.0, 0.0), r_line=None,
              **disc):
    d = dict(cx=IG["cx"], cy=IG["cy"], r=IG["r"])
    d.update(disc)
    cal = T.Calibration(screen, 2560, 1080, d["cx"], d["cy"], d["r"], method="disc", accepted=accepted,
                        measured=accepted, checked=checked, r_line_px=IG["r_line"] if r_line is None else r_line,
                        probes=PROBE if probes is None else probes, check_residual_px=resid,
                        look_offset_px=list(offset))
    cal.save()
    return cal


@pytest.fixture
def rig(monkeypatch):
    """Scripted frames: rig(frames, session=...) patches the camera's seams and returns (session, capture)."""
    def make(frames, session=None, foreground=True, scripted=True):
        s = session or FakeSession()
        cap = FakeCapture(frames, foreground)
        monkeypatch.setattr(camera, "new_session", lambda dry_run=False: s)
        monkeypatch.setattr(camera, "take_shot", cap)
        if scripted:
            monkeypatch.setattr(camera, "load_image", lambda p: cap.by_path[str(p)])
            monkeypatch.setattr(MD, "probes_ok", lambda img, probes, **k: (img.probes, 8 if img.probes else 0, 8))
            monkeypatch.setattr(MD, "find_trapezoid", lambda img, cx, cy, r, **k: img.trap)
        return s, cap
    return make


def centre_target():
    """London's centre (180, 342.5) m maps exactly onto the disc centre."""
    return 180.0, 342.5


# ----------------------------------------------------------------------------- control flow (no PIL)
@pytest.mark.parametrize("kind", [str, Path])
def test_goto_verified_str_and_path_out(rig, tmp_path, kind):
    write_cal()
    s, cap = rig([FakeImage(), FakeImage(trap=trap(IG["cx"] + 0.5, IG["cy"]))])
    out = tmp_path / "o"
    res = camera.goto(*centre_target(), *LONDON, out=kind(out), name="bridge")
    assert res["state"] == "ok" and res["ok"] and res["verified"] and res["clicks"] == 1
    assert res["error_px"] == 0.5 and res["accept_px"] == 3.0
    assert res["size_m"] == [360.0, 685.0] and res["size_source"] == "--size 360x685"
    assert res["target_px"] == pytest.approx([IG["cx"], IG["cy"]]) and res["click_px"] == [2399, 899]
    assert [p.name for p in cap.paths] == ["bridge_pre.png", "bridge_verify_1.png"]
    assert all(p.parent == out for p in cap.paths)
    saved = json.loads((out / "bridge.json").read_text(encoding="utf-8"))
    assert saved["look_at_px"] == pytest.approx([IG["cx"] + 0.5, IG["cy"]]) and saved["size_m"] == [360.0, 685.0]
    assert saved["calibration"]["file"].endswith("ingame_2560x1080.json") and saved["calibration"]["checked"]
    # the order of events: focus, (shot), click on the target, wait, park, wait
    assert [e["event"] for e in s.log] == ["focus", "click", "wait", "move", "wait"]
    assert s.events("click")[0] == {"event": "click", "x": IG["cx"], "y": IG["cy"], "space": "client"}


@pytest.mark.parametrize("kind", [str, Path])
def test_shot_str_and_path_out(rig, tmp_path, kind):
    write_cal()
    s, cap = rig([FakeImage(), FakeImage(trap=trap(IG["cx"], IG["cy"])), FakeImage()])
    out = tmp_path / "o"
    res = camera.shot(*centre_target(), *LONDON, "enemy_block", out=kind(out))
    assert res["cmd"] == "shot" and res["ok"] and res["photo_game_foreground"] is True
    assert Path(res["full"]) == out / "enemy_block_full.png" and Path(res["crop"]).is_file()
    assert res["crop_box"] == [640, 140, 1920, 940]
    assert json.loads((out / "enemy_block.json").read_text(encoding="utf-8"))["full"] == res["full"]
    assert s.events("wait")[-1]["s"] == camera.PHOTO_WAIT_S


def test_another_window_in_front(rig, tmp_path):
    write_cal()
    # the photo (third shot) shows another window: verified, but not ok
    s, cap = rig([FakeImage(), FakeImage(trap=trap(IG["cx"], IG["cy"]))], foreground=[True, True, False])
    res = camera.shot(*centre_target(), *LONDON, "x", out=tmp_path)
    assert res["verified"] and not res["ok"] and res["photo_game_foreground"] is False
    # the pre-click shot shows another window: NotForeground (a batch stops, review F1), no click
    s.log.clear()
    cap.paths.clear()
    cap.foreground = False
    with pytest.raises(inputs.NotForeground, match="not the game") as e:
        camera.shot(*centre_target(), *LONDON, "y", out=tmp_path)
    assert s.events("click") == [] and camera.stops_batch(e.value) and camera.exit_code(e.value) == 3


def test_default_out_is_a_fresh_temp_folder_outside_the_repository(rig, tmp_path):
    write_cal()
    rig([FakeImage(), FakeImage(trap=trap(IG["cx"], IG["cy"]))])
    a = camera.goto(*centre_target(), *LONDON)
    b = camera.goto(*centre_target(), *LONDON)
    for r in (a, b):
        p = Path(r["out"])
        assert p.parent == tmp_path / "tmp" and p.name.startswith("mapview_camera_")
        assert REPO not in p.parents and (p / "goto.json").is_file()
    assert a["out"] != b["out"]


def test_refused_when_the_window_is_missing(monkeypatch, tmp_path):
    write_cal()

    def missing(dry_run=False):
        raise inputs.GameNotFound("no window")
    monkeypatch.setattr(camera, "new_session", missing)
    monkeypatch.setattr(camera, "take_shot", _boom)
    with pytest.raises(inputs.GameNotFound):
        camera.goto(*centre_target(), *LONDON, out=tmp_path)
    assert json.loads((tmp_path / "goto.json").read_text(encoding="utf-8"))["state"] == "error"
    with pytest.raises(inputs.GameNotFound):
        camera.shot(*centre_target(), *LONDON, "s", out=tmp_path)
    assert camera.stops_batch(inputs.GameNotFound("x"))


def test_refused_when_focus_fails(rig, tmp_path):
    write_cal()
    s, cap = rig([FakeImage()], session=FakeSession(focus_ok=False))
    with pytest.raises(inputs.NotForeground):
        camera.goto(*centre_target(), *LONDON, out=tmp_path)
    assert s.events("click") == [] and cap.paths == []


def test_refused_when_the_probes_fail(rig, tmp_path):
    write_cal()
    s, cap = rig([FakeImage(probes=False)])
    with pytest.raises(camera.Refused, match="not on screen or is dimmed"):
        camera.goto(*centre_target(), *LONDON, out=tmp_path, name="dim")
    assert s.events("click") == [] and s.events("move") == [] and len(cap.paths) == 1
    saved = json.loads((tmp_path / "dim.json").read_text(encoding="utf-8"))
    assert saved["state"] == "refused" and saved["pre_probes"] == [0, 8] and not saved["ok"]


def _world_at(cal, dist_px, deg=200.0, size=LONDON):
    a = math.radians(deg)
    return T.minimap_to_world(cal.cx + dist_px * math.cos(a), cal.cy - dist_px * math.sin(a), size[0], size[1], cal)


def test_refused_when_the_target_is_outside_the_disc(rig, tmp_path):
    cal = write_cal()
    s, cap = rig([FakeImage(), FakeImage(trap=trap(0, 0))])
    for x, z in ((0.0, 0.0), _world_at(cal, cal.radius_px - 3.0), _world_at(cal, cal.radius_px + 20.0)):
        with pytest.raises(camera.Refused, match="outside the drawn disc"):
            camera.goto(x, z, *LONDON, out=tmp_path)
    assert s.log == [] and cap.paths == []
    # 7 px inside the rim is clickable (the margin is 6 px): at 135 degrees that is (180, 668.7) m, on the map
    x, z = _world_at(cal, cal.radius_px - 7.0, deg=135.0)
    assert 0 <= x <= LONDON[0] and 0 <= z <= LONDON[1]
    res = camera.goto(x, z, *LONDON, out=tmp_path)
    assert len(s.events("click")) == 2 and res["state"] == "off_target"


def test_refused_when_the_target_is_inside_the_disc_but_off_the_map(rig, tmp_path):
    # review F11: London's long sides leave black disc area beside the map; 45 degrees, 100 px = x 461 m
    cal = write_cal()
    s, cap = rig([FakeImage(), FakeImage(trap=trap(0, 0))])
    x, z = _world_at(cal, 100.0, deg=45.0)
    assert x > LONDON[0]
    with pytest.raises(camera.Refused, match="outside the 360x685 m map") as e:
        camera.goto(x, z, *LONDON, out=tmp_path)
    assert not e.value.fatal and s.log == [] and cap.paths == []


def test_calibration_gates(rig, tmp_path):
    s, cap = rig([FakeImage(), FakeImage(trap=trap(IG["cx"], IG["cy"]))])
    with pytest.raises(camera.Refused, match="no calibration") as e:
        camera.goto(*centre_target(), *LONDON, out=tmp_path)
    assert e.value.fatal and camera.stops_batch(e.value)
    write_cal(checked=False)
    with pytest.raises(camera.Refused, match="never passed"):
        camera.goto(*centre_target(), *LONDON, out=tmp_path)
    assert s.log == []
    assert camera.goto(*centre_target(), *LONDON, out=tmp_path, unchecked=True)["ok"]
    write_cal(accepted=False, checked=False)
    with pytest.raises(camera.Refused, match="not an accepted"):
        camera.goto(*centre_target(), *LONDON, out=tmp_path, unchecked=True)


@pytest.mark.parametrize("n", [0, 1, 3])
def test_refused_without_enough_ring_probes(rig, tmp_path, n):
    # review F11: calibrate.py disc demands 4; a hand-edited record with fewer is a one-pixel check
    write_cal(probes=PROBE[:1] * n)
    s, cap = rig([FakeImage()])
    with pytest.raises(camera.Refused, match="has %d ring probes, fewer than the 4" % n) as e:
        camera.goto(*centre_target(), *LONDON, out=tmp_path)
    assert e.value.fatal and s.log == [] and cap.paths == []


def test_min_ring_probes_is_calibrates_disc_minimum():
    from scripts.mapview import calibrate
    assert camera.MIN_RING_PROBES == calibrate.DISC_MIN_PROBES == 4


def test_retry_after_the_first_click_is_eaten(rig, tmp_path):
    write_cal()
    s, cap = rig([FakeImage(), FakeImage(trap=None), FakeImage(trap=trap(IG["cx"] + 1, IG["cy"] - 1))])
    res = camera.goto(*centre_target(), *LONDON, out=tmp_path, name="r")
    assert [a["state"] for a in res["attempts"]] == ["not_found", "ok"] and res["ok"] and res["clicks"] == 2
    assert [p.name for p in cap.paths] == ["r_pre.png", "r_verify_1.png", "r_verify_2.png"]
    # the retry runs a plain foreground check, never focus() (review F1): one focus, as the goto's first event
    assert [e["event"] for e in s.log] == ["focus", "click", "wait", "move", "wait", "check", "click", "wait", "move",
                                          "wait"]


def test_the_owner_takes_the_foreground_after_the_first_click(rig, tmp_path):
    # review F1: the retry must NOT pull the game back over the owner's window - NotForeground, the batch stops
    write_cal()
    s, cap = rig([FakeImage(), FakeImage(trap=None)], session=FakeSession(fg_after_click=1))
    with pytest.raises(inputs.NotForeground) as e:
        camera.goto(*centre_target(), *LONDON, out=tmp_path, name="away")
    assert [ev["event"] for ev in s.log] == ["focus", "click", "wait", "move", "wait", "check"]
    assert camera.stops_batch(e.value) and camera.exit_code(e.value) == 3
    saved = json.loads((tmp_path / "away.json").read_text(encoding="utf-8"))
    assert saved["state"] == "error" and saved["clicks"] == 1 and saved["focused"] is True
    assert e.value.camera_result["clicks"] == 1


def test_focus_false_never_focuses(rig, tmp_path):
    # a later batch target: the game must still be in front; it is never brought back (review F1)
    write_cal()
    s, cap = rig([FakeImage(), FakeImage(trap=trap(IG["cx"], IG["cy"]))], session=FakeSession(fg=False))
    with pytest.raises(inputs.NotForeground):
        camera.shot(*centre_target(), *LONDON, "later", out=tmp_path, focus=False)
    assert [ev["event"] for ev in s.log] == ["check"] and cap.paths == []
    s.fg = True
    s.log.clear()
    res = camera.shot(*centre_target(), *LONDON, "later", out=tmp_path, focus=False)
    assert res["ok"] and [ev["event"] for ev in s.log][:2] == ["check", "click"] and not s.events("focus")


def test_stop_batch_covers_the_owner_and_the_cursor():
    assert set(camera.STOP_BATCH) == {inputs.Aborted, inputs.GameNotFound, inputs.NotForeground,
                                      inputs.CursorMismatch}
    for exc in (inputs.NotForeground("x"), inputs.CursorMismatch("x"), camera.Refused("x", fatal=True)):
        assert camera.stops_batch(exc)
    assert not camera.stops_batch(camera.Refused("minimap dimmed")) and not camera.stops_batch(ValueError("x"))


def test_off_target_twice_is_not_verified(rig, tmp_path):
    write_cal()
    s, _ = rig([FakeImage(), FakeImage(trap=trap(IG["cx"] + 5, IG["cy"]))])
    res = camera.goto(*centre_target(), *LONDON, out=tmp_path)
    assert res["state"] == "off_target" and not res["ok"] and res["error_px"] == 5.0 and len(s.events("click")) == 2
    assert camera.main(["goto", "180", "342.5", "--size", "360x685", "--out", str(tmp_path)]) == 1


def test_minimap_lost_after_the_click_stops_without_a_retry(rig, tmp_path):
    write_cal()
    s, _ = rig([FakeImage(), FakeImage(probes=False)])
    res = camera.goto(*centre_target(), *LONDON, out=tmp_path)
    assert res["state"] == "minimap_lost" and len(s.events("click")) == 1 and not res["ok"]


def test_clipped_is_its_own_state_and_never_retried(rig, tmp_path):
    write_cal()
    s, _ = rig([FakeImage(trap=trap(IG["cx"] + 30, IG["cy"])), FakeImage(trap=trap(IG["cx"], IG["cy"], clipped=True))])
    res = camera.goto(*centre_target(), *LONDON, out=tmp_path)
    assert res["state"] == "clipped" and res["clipped"] and res["error_px"] == 0.0 and not res["ok"]
    assert not res["verified"] and len(s.events("click")) == 1 and "clipped" not in camera.RETRY_STATES
    assert res["moved_px"] == 30.0                                         # the camera did move


def test_a_clipped_trapezoid_without_a_look_at(rig, tmp_path):
    # minimap_detect.find_trapezoid may return a clipped outline whose look_at is None (fix round 2026-09-24)
    write_cal()
    cut = {"look_at": None, "clipped": True, "leg_support": 0.4}
    s, _ = rig([FakeImage(trap=dict(cut)), FakeImage(trap=dict(cut))])
    res = camera.goto(*centre_target(), *LONDON, out=tmp_path, name="cut")
    assert res["state"] == "clipped" and res["look_at_px"] is None and res["error_px"] is None
    assert res["pre_look_at_px"] is None and res["moved_px"] is None and not res["ok"]
    assert len(s.events("click")) == 1
    assert camera.main(["goto", "180", "342.5", "--size", "360x685", "--out", str(tmp_path)]) == 1
    # an unclipped outline without a look-at is not a verification either: not_found, one retry
    s2, _ = rig([FakeImage(), FakeImage(trap={"look_at": None, "clipped": False}), FakeImage(trap=trap(IG["cx"], IG["cy"]))])
    res = camera.goto(*centre_target(), *LONDON, out=tmp_path, name="none")
    assert [a["state"] for a in res["attempts"]] == ["not_found", "ok"]


@pytest.mark.parametrize("resid,err,ok", [(None, 2.9, True), (None, 3.1, False), (2.5, 3.9, True), (2.5, 4.1, False)])
def test_acceptance_is_max_of_3_and_check_residual_plus_1_5(rig, tmp_path, resid, err, ok):
    write_cal(resid=resid)
    rig([FakeImage(), FakeImage(trap=trap(IG["cx"] + err, IG["cy"]))])
    res = camera.goto(*centre_target(), *LONDON, out=tmp_path)
    assert res["accept_px"] == max(3.0, (resid or 0) + 1.5) and res["ok"] is ok


def test_look_offset_is_applied(rig, tmp_path):
    write_cal(offset=(4.0, -2.0))
    rig([FakeImage(), FakeImage(trap=trap(IG["cx"] + 4.0, IG["cy"] - 2.0))])
    res = camera.goto(*centre_target(), *LONDON, out=tmp_path)
    assert res["ok"] and res["error_px"] == 0.0
    assert res["expected_look_at_px"] == pytest.approx([IG["cx"] + 4.0, IG["cy"] - 2.0])


def test_park_on_the_ring_dark_band(rig, tmp_path):
    cal = write_cal()
    s, _ = rig([FakeImage(), FakeImage(trap=trap(IG["cx"], IG["cy"]))])
    res = camera.goto(*centre_target(), *LONDON, out=tmp_path)
    park = res["park"]
    assert (park["x"], park["y"]) == (2509, 1009) and park["verified"] and park["space"] == "client"
    assert "315 deg" in park["source"] and "match.park_mouse (FileNotFoundError)" in park["note"]
    assert math.hypot(park["x"] - cal.cx, park["y"] - cal.cy) >= cal.radius_px + camera.PARK_MIN_OUT_PX
    assert s.events("move")[0] == {"event": "move", "x": 2509, "y": 1009, "space": "client"}


def test_no_dark_ring_pixel_means_no_click(rig, tmp_path):
    write_cal()
    s, _ = rig([FakeImage(rgb=(255, 255, 255))])
    with pytest.raises(camera.Refused, match="no park point"):
        camera.goto(*centre_target(), *LONDON, out=tmp_path)
    assert s.events("click") == []


def _sheet(folder, point):
    folder.mkdir(parents=True, exist_ok=True)
    (folder / "2560x1080.json").write_text(json.dumps({"size": [2560, 1080], "match": {"park_mouse": point}}),
                                           encoding="utf-8")


def test_a_measured_sheet_point_wins_and_one_on_the_disc_is_refused(rig, tmp_path, monkeypatch):
    write_cal()
    monkeypatch.setattr(sheets, "SHEETS_DIR", tmp_path / "sheets")
    _sheet(tmp_path / "sheets", {"x": 2200, "y": 1060, "space": "client", "provenance": "measured 2026-09-24 test"})
    s, _ = rig([FakeImage(), FakeImage(trap=trap(IG["cx"], IG["cy"]))])
    res = camera.goto(*centre_target(), *LONDON, out=tmp_path)
    assert res["park"]["source"] == "sheet match.park_mouse" and s.events("move")[0]["x"] == 2200
    _sheet(tmp_path / "sheets", {"x": 2400, "y": 900, "space": "client", "provenance": "measured 2026-09-24 test"})
    s.log.clear()
    with pytest.raises(camera.Refused, match="lies on the minimap disc"):
        camera.goto(*centre_target(), *LONDON, out=tmp_path)
    _sheet(tmp_path / "sheets", {"x": 2600, "y": 1060, "space": "client", "provenance": "measured 2026-09-24 test"})
    with pytest.raises(camera.Refused, match="outside the game's 2560x1080 client area"):
        camera.goto(*centre_target(), *LONDON, out=tmp_path)
    assert s.events("click") == []
    _sheet(tmp_path / "sheets", {"x": 2200, "y": 1060, "space": "client", "provenance": "derived by a guess"})
    res = camera.goto(*centre_target(), *LONDON, out=tmp_path)              # derived: ignored, the ring is used
    assert res["park"]["source"].startswith("ring") and "DerivedPoint" in res["park"]["note"]


class FakeRecorder:
    def __init__(self, path, seconds, starts=True, writes=True):
        self.path, self.seconds, self.starts, self.writes, self.how = Path(path), seconds, starts, writes, None

    def start(self):
        self.how = "ddagrab" if self.starts else None
        return self.starts

    def stop(self):
        if self.writes:
            self.path.write_bytes(b"mp4")
        return self.writes


@pytest.mark.parametrize("starts,writes,ok", [(False, False, False), (True, False, False), (True, True, True)])
def test_record_verifies_the_video(rig, tmp_path, monkeypatch, capsys, starts, writes, ok):
    write_cal()
    s, _ = rig([FakeImage(), FakeImage(trap=trap(IG["cx"], IG["cy"]))])
    made = []
    monkeypatch.setattr(camera, "new_recorder",
                        lambda p, sec: made.append(FakeRecorder(p, sec, starts, writes)) or made[-1])
    res = camera.record(*centre_target(), *LONDON, 30, "bridge", out=tmp_path)
    assert res["verified"] and res["ok"] is ok and made[0].seconds == 35
    assert res["video"] == (str(tmp_path / "bridge.mp4") if ok else None)
    if not starts:
        assert "ffmpeg did not start" in res["error"] and "NO VIDEO" in capsys.readouterr().err
        assert s.events("wait")[-1]["s"] != 30                           # no recording wait at all
    else:
        assert s.events("wait")[-1]["s"] == 30
    assert json.loads((tmp_path / "bridge.json").read_text(encoding="utf-8"))["ok"] is ok


def test_dry_run_plans_without_screenshots(rig, tmp_path):
    write_cal()
    s, cap = rig([FakeImage()], session=FakeSession(dry_run=True))
    res = camera.shot(*centre_target(), *LONDON, "plan", out=tmp_path, dry_run=True)
    assert res["state"] == "planned" and not res["ok"] and cap.paths == []
    assert res["park"]["verified"] is False and (res["park"]["x"], res["park"]["y"]) == (2509, 1009)
    assert [e["event"] for e in res["events"]] == ["focus", "click", "wait", "move"]
    assert camera.main(["goto", "180", "342.5", "--size", "360x685", "--out", str(tmp_path), "--dry-run"]) == 0


def test_a_session_must_match_dry_run(rig, tmp_path):
    # review F9: goto(dry_run=True, session=<live Session>) used to run LIVE
    write_cal()
    live, dry = FakeSession(), FakeSession(dry_run=True)
    for s, flag in ((live, True), (dry, False)):
        with pytest.raises(ValueError, match="dry_run"):
            camera.goto(*centre_target(), *LONDON, out=tmp_path, session=s, dry_run=flag)
        assert s.log == []


def test_an_error_after_a_click_is_not_exit_2(rig, tmp_path, monkeypatch, capsys):
    # review F10: a ValueError / FileNotFoundError after a click used to map to 'refused before any click'
    write_cal()
    rig([FakeImage(), FakeImage(trap=trap(IG["cx"], IG["cy"]))])
    real = camera.load_image
    calls = []

    def vanish(p):
        calls.append(p)
        if "verify" in str(p):
            raise FileNotFoundError(p)
        return real(p)
    monkeypatch.setattr(camera, "load_image", vanish)
    assert camera.main(["goto", "180", "342.5", "--size", "360x685", "--out", str(tmp_path)]) == 1
    err = FileNotFoundError("x")
    assert camera.exit_code(err) == 2
    err.camera_result = {"clicks": 1}
    assert camera.exit_code(err) == 1
    assert "-> %s" % tmp_path in capsys.readouterr().out                    # the goto line names its folder


def test_resolve_size():
    assert camera.resolve_size("360x685") == (360.0, 685.0, "--size 360x685")
    sx, sz, src = camera.resolve_size(None, "zplondon", 4)
    # mapinfo.map_size gives the ENGINE size since the fix round: rmSetMapSize 685 -> 343 whole 2 m tiles = 686 m
    # (the save's terrain header, 16 saves, 2026-09-24)
    assert (sx, sz) == (360.0, 686.0) and src == "mapsim zplondon.xs, 4 players, 2 teams"
    assert camera.resolve_size(None, "zplondon", 2)[:2] == (360.0, 646.0)
    assert camera.resolve_size("360x686", "zplondon", 4)[:2] == (360.0, 686.0)
    for old in ("360x645", "360x685"):                           # the skill's old example; rmSetMapSize's own value
        with pytest.raises(ValueError, match="disagrees"):
            camera.resolve_size(old, "zplondon", 4)
    for bad in ((None, None, None), (None, "zplondon", None), ("360", None, None), ((0, 5), None, None)):
        with pytest.raises(ValueError):
            camera.resolve_size(*bad)


def test_names_are_plain(rig, tmp_path):
    for bad in ("../up", "a/b", "", " x"):
        with pytest.raises(ValueError):
            camera.goto(*centre_target(), *LONDON, out=tmp_path, name=bad)


def test_cli_exit_codes(rig, tmp_path, monkeypatch):
    args = ["goto", "180", "342.5", "--size", "360x685", "--out", str(tmp_path)]
    s, _ = rig([FakeImage(), FakeImage(trap=trap(IG["cx"], IG["cy"]))])
    assert camera.main(args) == 2                                          # no calibration
    write_cal()
    assert camera.main(args) == 0
    assert camera.main(["goto", "180", "342.5", "--out", str(tmp_path)]) == 2          # no size
    assert camera.main(["goto", "180", "342.5", "--size", "360x645", "--map", "zplondon", "--players", "4"]) == 2
    s.focus_ok = False
    assert camera.main(args) == 3
    s.focus_ok = True

    def aborted(x, y, space="screen"):
        raise inputs.Aborted("cursor in the corner")
    monkeypatch.setattr(s, "click", aborted)
    assert camera.main(args) == 4
    with pytest.raises(SystemExit) as e:
        camera.main(["shot", "1", "2", "--size", "360x685"])                          # --name is required
    assert e.value.code == 2


def test_verify_now_takes_one_shot_and_no_input(rig, tmp_path, monkeypatch):
    write_cal()
    s, cap = rig([FakeImage(trap=trap(IG["cx"], IG["cy"]))])
    monkeypatch.setattr(win, "dpi_aware", lambda: False)
    monkeypatch.setattr(win, "find_window", lambda title=win.GAME_TITLE: 4242)
    monkeypatch.setattr(win, "client_rect", lambda h: CLIENT)
    row = camera.verify_now("ingame", tmp_path, size=(360.0, 685.0, "--size 360x685"))
    assert row["state"] == "found" and row["look_at_m"] == [180.0, 342.5] and s.log == [] and len(cap.paths) == 1
    monkeypatch.setattr(win, "find_window", lambda title=win.GAME_TITLE: None)
    with pytest.raises(inputs.GameNotFound):
        camera.verify_now("ingame", tmp_path)


def test_the_recorder_uses_drivers_live_settings(tmp_path):
    # review F7: 10 fps, 1280 wide (driver.py start_recording), not 30 fps at native resolution
    r = camera.new_recorder(tmp_path / "v.mp4", 35)
    assert (r.fps, r.width, r.seconds) == (10, 1280, 35)


def test_import_does_not_touch_the_driver():
    assert "driver" not in camera.__dict__ and not hasattr(camera, "_driver")
    src = Path(camera.__file__).read_text(encoding="utf-8")
    assert "import driver" not in src and "probe.py" not in src


# ----------------------------------------------------------------------------- the fixture crops (PIL)
@lru_cache(maxsize=None)
def _fixture(stem):
    Image = pytest.importorskip("PIL.Image")
    fix = json.loads((FIXTURES / (stem + ".json")).read_text(encoding="utf-8"))
    crop = Image.open(FIXTURES / fix["image"]).convert("RGB")
    can = Image.new("RGB", tuple(fix["screen_size"]), (20, 20, 20))
    can.paste(crop, tuple(fix["crop_offset"]))
    m = MD.measure_disc(can)
    return fix, can, m


def _canvas(stem, dim=None, erase=False):
    fix, can, m = _fixture(stem)
    img = can.copy()
    if dim is not None:
        img = img.point(lambda v: int(v * dim))
    if erase:                                    # paint the camera outline out: the verify frame of an eaten click
        t = MD.find_trapezoid(img, m.cx, m.cy, m.r_disc)
        px = img.load()
        xs = [t[k][0] for k in ("TL", "TR", "BL", "BR")]
        ys = [t[k][1] for k in ("TL", "TR", "BL", "BR")]
        for y in range(int(min(ys)) - 2, int(max(ys)) + 3):
            for x in range(int(min(xs)) - 2, int(max(xs)) + 3):
                if min(px[x, y]) >= 250:
                    px[x, y] = (60, 60, 60)
        assert MD.find_trapezoid(img, m.cx, m.cy, m.r_disc) is None
    return img


def _fixture_cal(stem, screen, resid=1.3):
    fix, can, m = _fixture(stem)
    return write_cal(screen=screen, probes=m.probes, resid=resid, cx=m.cx, cy=m.cy, r=m.r_disc, r_line=m.r_line)


def test_fixture_verification_maths_in_a_match(rig, tmp_path):
    fix, _, _ = _fixture("ingame_hud_minimap")
    cal = _fixture_cal("ingame_hud_minimap", "ingame")
    lx, ly = fix["look_at"]                                         # (2448.7, 933.2), the trapezoid's diagonals
    x, z = T.minimap_to_world(lx, ly, *LONDON, cal)
    s, cap = rig([_canvas("ingame_hud_minimap")] * 3, scripted=False)
    res = camera.goto(x, z, *LONDON, out=tmp_path, name="hit")
    assert res["state"] == "ok" and res["error_px"] <= 0.5 and res["clicks"] == 1
    assert res["look_at_px"] == pytest.approx([lx, ly]) and res["pre_probes"] == [8, 8] and res["attempts"][0]["probes"] == [8, 8]
    assert (res["park"]["x"], res["park"]["y"]) == (2509, 1009) and res["park"]["rgb"] == [41, 35, 23]
    # a target 5 px away: off target, one retry, reported honestly
    x, z = T.minimap_to_world(lx + 3.0, ly + 4.0, *LONDON, cal)
    cap.paths.clear()
    res = camera.goto(x, z, *LONDON, out=tmp_path, name="miss")
    assert res["state"] == "off_target" and abs(res["error_px"] - 5.0) <= 0.05 and res["clicks"] == 2


def test_fixture_retry_after_an_erased_trapezoid(rig, tmp_path):
    fix, _, _ = _fixture("ingame_hud_minimap")
    cal = _fixture_cal("ingame_hud_minimap", "ingame")
    x, z = T.minimap_to_world(*fix["look_at"], *LONDON, cal)
    frames = [_canvas("ingame_hud_minimap"), _canvas("ingame_hud_minimap", erase=True), _canvas("ingame_hud_minimap")]
    s, _ = rig(frames, scripted=False)
    res = camera.goto(x, z, *LONDON, out=tmp_path)
    assert [a["state"] for a in res["attempts"]] == ["not_found", "ok"] and res["ok"] and len(s.events("click")) == 2


def test_fixture_clipped_editor_trapezoid(rig, tmp_path):
    fix, _, _ = _fixture("paris_editor_minimap")
    cal = _fixture_cal("paris_editor_minimap", "editor")
    size = (fix["size_x_m"], fix["size_z_m"])
    x, z = T.minimap_to_world(*fix["look_at"], *size, cal)
    s, _ = rig([_canvas("paris_editor_minimap")] * 3, scripted=False)
    res = camera.goto(x, z, *size, screen="editor", out=tmp_path)
    assert res["state"] == "clipped" and res["clipped"] and not res["ok"] and not res["verified"]
    # minimap_detect may give a cut outline's look_at, or None (fix round 2026-09-24): an error only with a look_at
    assert res["error_px"] is None or res["error_px"] <= 0.5
    assert len(s.events("click")) == 1                                    # clipped is never retried
    assert res["screen"] == "editor_2560x1080" and (res["park"]["x"], res["park"]["y"]) == (2367, 1018)


def test_fixture_dimmed_frame_is_refused(rig, tmp_path):
    fix, _, _ = _fixture("ingame_hud_minimap")
    cal = _fixture_cal("ingame_hud_minimap", "ingame")
    x, z = T.minimap_to_world(*fix["look_at"], *LONDON, cal)
    s, _ = rig([_canvas("ingame_hud_minimap", dim=0.63)], scripted=False)
    with pytest.raises(camera.Refused, match="0 of 8 ring probes"):
        camera.goto(x, z, *LONDON, out=tmp_path)
    assert s.events("click") == [] and s.events("move") == []


class SimDesk:
    """The Win32 side of a real gameio Session, simulated (review F13, the verifier's probe_camera.py step 1): the
    cursor follows absolute moves, the foreground is a flag, and every call lands in one trace."""

    def __init__(self, monkeypatch, canvas):
        self.vdesk, self.cursor, self.fg, self.trace, self.canvas = (-2560, -522, 5120, 1602), (1200, 600), True, [], canvas
        m = monkeypatch
        m.setattr(win, "dpi_aware", lambda: False)
        m.setattr(win, "find_window", lambda title=win.GAME_TITLE: 4242)
        m.setattr(win, "window_exe", lambda h: "AoE3DE_s.exe")
        m.setattr(win, "client_rect", lambda h: CLIENT)
        m.setattr(win, "virtual_screen", lambda: self.vdesk)
        m.setattr(win, "is_foreground", self.is_fg)
        m.setattr(win, "foreground_title", lambda: win.GAME_TITLE if self.fg else "Visual Studio Code")
        m.setattr(win, "cursor_pos", self.cursor_pos)
        m.setattr(win, "is_iconic", lambda h: False)
        m.setattr(win, "root_window_at", lambda x, y: self.trace.append(("root", x, y)) or 4242)
        m.setattr(win, "window_title", lambda h: win.GAME_TITLE)
        m.setattr(win, "map_vk_to_scan", lambda vk: inputs.SCAN_FALLBACK.get(vk, 0))
        m.setattr(inputs, "send_input", self.send)
        m.setattr(inputs, "set_foreground", lambda h: self.trace.append(("set_foreground", h)) or True)
        m.setattr(capture, "grab", self.grab)
        m.setattr("time.sleep", lambda s: self.trace.append(("sleep", s)))
        m.setattr(inputs, "Session", REAL_SESSION)                       # the REAL Session and the REAL shot
        m.setattr(capture, "shot", REAL_SHOT)

    def is_fg(self, h):
        self.trace.append(("fg",))
        return self.fg

    def cursor_pos(self):
        self.trace.append(("cursor",))
        return self.cursor

    def send(self, arr):
        from scripts.gameio import geom
        for i in arr:
            if i.type == 0:
                if i.u.mi.dwFlags & 0x8000:
                    self.cursor = geom.pixel_from_abs(i.u.mi.dx, i.u.mi.dy, self.vdesk)
                self.trace.append(("mouse", i.u.mi.dwFlags, self.cursor))
            else:
                self.trace.append(("key", i.u.ki.wVk, i.u.ki.dwFlags))
        return len(arr)

    def grab(self, bbox=None, all_screens=True):
        self.trace.append(("grab", bbox))
        return self.canvas.copy()


def test_fixture_goto_through_the_real_session_and_the_real_shot(tmp_path, monkeypatch):
    fix, can, _ = _fixture("ingame_hud_minimap")
    cal = _fixture_cal("ingame_hud_minimap", "ingame")
    desk = SimDesk(monkeypatch, can)
    x, z = T.minimap_to_world(*fix["look_at"], *LONDON, cal)
    res = camera.goto(x, z, *LONDON, out=tmp_path, name="real")
    assert res["state"] == "ok" and res["clicks"] == 1 and res["error_px"] <= 0.5
    grabs = [t for t in desk.trace if t[0] == "grab"]
    assert grabs == [("grab", (0, 0, 2560, 1080))] * 2                     # pre-click + verify, client rect only
    kinds = [t[0] for t in desk.trace]
    assert kinds.index("grab") < kinds.index("mouse")                     # the pre-click shot before any input
    mouse = [t for t in desk.trace if t[0] == "mouse"]
    assert [t[1] for t in mouse] == [0xC001, 0x0002, 0x0004, 0xC001]
    assert mouse[0][2] == tuple(res["click_px"]) and mouse[-1][2] == (res["park"]["x"], res["park"]["y"])
    assert ("root", *res["click_px"]) in desk.trace                       # the window under the press was checked
    assert not [t for t in desk.trace if t[0] in ("key", "set_foreground")]    # in front already: no Alt tap
    # every non-release send was preceded by the corner guard and the foreground check
    seen = set()
    for t in desk.trace:
        if t[0] in ("cursor", "fg"):
            seen.add(t[0])
        elif t[0] == "mouse":
            assert t[1] == 0x0004 or seen == {"cursor", "fg"}, t
            seen = set()
    meta = json.loads((tmp_path / "real_pre.png.json").read_text(encoding="utf-8"))
    assert meta["game_foreground"] is True and meta["area"] == "client"


def test_fixture_world_batch_never_refocuses_after_the_owner_left(tmp_path, monkeypatch, snapshots):
    # review F1 (probe_camera.py step 3): the owner clicks VS Code right after target a's click; target b must not
    # send an Alt tap nor SetForegroundWindow, and the batch stops
    fix, can, _ = _fixture("ingame_hud_minimap")
    cal = _fixture_cal("ingame_hud_minimap", "ingame")
    desk = SimDesk(monkeypatch, can)
    send = desk.send

    def send_and_leave(arr):
        n = send(arr)
        if any(i.type == 0 and i.u.mi.dwFlags == 0x0004 for i in arr):
            desk.fg = False                                                # the owner takes the foreground
        return n
    monkeypatch.setattr(inputs, "send_input", send_and_leave)
    x, z = T.minimap_to_world(*fix["look_at"], *LONDON, cal)
    tj = tmp_path / "targets.json"
    tj.write_text(json.dumps([{"name": n, "x_m": x, "z_m": z} for n in ("a", "b", "c")]), encoding="utf-8")
    assert snapshots.world_targets(tmp_path / "w", str(tj), "360x685") == 1
    results = json.loads((tmp_path / "w" / "world_targets.json").read_text(encoding="utf-8"))
    assert [r["state"] for r in results] == ["error", "skipped", "skipped"]
    assert "NotForeground" in results[0]["error"]
    assert not [t for t in desk.trace if t[0] in ("key", "set_foreground")]


def test_fixture_shot_crops_the_screen_centre(rig, tmp_path):
    fix, _, _ = _fixture("ingame_hud_minimap")
    cal = _fixture_cal("ingame_hud_minimap", "ingame")
    x, z = T.minimap_to_world(*fix["look_at"], *LONDON, cal)
    rig([_canvas("ingame_hud_minimap")] * 3, scripted=False)
    res = camera.shot(x, z, *LONDON, "photo", out=str(tmp_path))
    from PIL import Image
    with Image.open(res["crop"]) as im:
        assert im.size == (1280, 800)
    assert res["ok"]


# ----------------------------------------------------------------------------- snapshots.py --world
@pytest.fixture
def snapshots(monkeypatch):
    """snapshots.py loaded with a stand-in for driver (the real one calls Win32 at import); sys.path restored."""
    monkeypatch.setattr(sys, "path", list(sys.path))
    monkeypatch.setitem(sys.modules, "driver", types.ModuleType("driver"))
    spec = importlib.util.spec_from_file_location("aitest_snapshots_under_test", SNAPSHOTS)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


@pytest.fixture
def fake_shot(monkeypatch):
    calls = []

    def shot(x_m, z_m, sx, sz, name, out=None, screen="ingame", unchecked=False, size_source=None, focus=True,
             **k):
        calls.append({"name": name, "out": out, "size": (sx, sz), "src": size_source, "unchecked": unchecked,
                      "focus": focus})
        if name.startswith("fail"):
            return {"ok": False, "state": "off_target", "size_m": [sx, sz], "focused": True}
        if name.startswith("raise"):                  # refused after the focus step (the pre-click probes)
            e = camera.Refused("minimap dimmed")
            e.camera_result = {"focused": True, "clicks": 0}
            raise e
        if name.startswith("outside"):                # refused before the focus step (target off the map)
            e = camera.Refused("outside the map")
            e.camera_result = {"focused": False, "clicks": 0}
            raise e
        if name.startswith("abort"):
            raise inputs.Aborted("cursor in the corner")
        if name.startswith("away"):
            raise inputs.NotForeground("the game left the foreground")
        return {"ok": True, "state": "ok", "size_m": [sx, sz], "focused": True}
    monkeypatch.setattr(camera, "shot", shot)
    return calls


def _targets(tmp_path, names):
    p = tmp_path / "targets.json"
    p.write_text(json.dumps([{"name": n, "x_m": 180, "z_m": 342.5} for n in names]), encoding="utf-8")
    return str(p)


@pytest.mark.parametrize("names,code", [(["a", "b"], 0), (["a", "fail_b"], 1), (["raise_a", "b"], 1), ([], 1)])
def test_world_exit_codes_and_names(snapshots, fake_shot, tmp_path, names, code):
    out = str(tmp_path / "w")                                    # a str, as the CLI passes it (review F1)
    assert snapshots.world_targets(out, _targets(tmp_path, names), "360x685") == code
    results = json.loads((tmp_path / "w" / "world_targets.json").read_text(encoding="utf-8"))
    assert [r["name"] for r in results] == names and all(r["size_m"] == [360.0, 685.0] for r in results)
    assert all(isinstance(c["out"], Path) and c["src"] == "--size 360x685" for c in fake_shot)
    if "raise_a" in names:
        assert results[0]["error"] == "Refused: minimap dimmed" and results[1]["ok"]      # not fatal: continue


def test_world_batch_stops_at_an_abort(snapshots, fake_shot, tmp_path):
    assert snapshots.world_targets(tmp_path, _targets(tmp_path, ["abort_a", "b", "c"]), None, "ingame",
                                   "zplondon", 4) == 1
    results = json.loads((tmp_path / "world_targets.json").read_text(encoding="utf-8"))
    assert [r["state"] for r in results] == ["error", "skipped", "skipped"] and len(fake_shot) == 1
    assert fake_shot[0]["size"] == (360.0, 686.0) and fake_shot[0]["src"].startswith("mapsim zplondon.xs, 4 players")


@pytest.mark.parametrize("names,focus", [
    (["a", "b", "c"], [True, False, False]),
    (["outside_a", "b", "c"], [True, True, False]),              # a refused before its focus step: b may focus
    (["raise_a", "b"], [True, False]),                           # a reached its focus step, then was refused
])
def test_world_batch_focuses_only_once(snapshots, fake_shot, tmp_path, names, focus):
    # review F1: only the target that first reaches the focus step may bring the game to the front
    snapshots.world_targets(tmp_path, _targets(tmp_path, names), "360x685")
    assert [c["focus"] for c in fake_shot] == focus


@pytest.mark.parametrize("stopper", ["away_a", "abort_a"])
def test_world_batch_stops_when_the_owner_takes_the_foreground(snapshots, fake_shot, tmp_path, stopper):
    assert snapshots.world_targets(tmp_path, _targets(tmp_path, [stopper, "b", "c"]), "360x685") == 1
    results = json.loads((tmp_path / "world_targets.json").read_text(encoding="utf-8"))
    assert [r["state"] for r in results] == ["error", "skipped", "skipped"] and len(fake_shot) == 1


def test_world_refusals_before_any_target(snapshots, fake_shot, tmp_path):
    t = _targets(tmp_path, ["a"])
    assert snapshots.world_targets(tmp_path, t, None) == 2                               # no size
    assert snapshots.world_targets(tmp_path, t, "360x645", "ingame", "zplondon", 4) == 2  # size disagrees
    bad = tmp_path / "bad.json"
    bad.write_text('{"name": "a"}', encoding="utf-8")
    assert snapshots.world_targets(tmp_path, str(bad), "360x685") == 2
    assert snapshots.world_targets(tmp_path, str(tmp_path / "missing.json"), "360x685") == 2
    bad.write_text('[{"name": "a"}]', encoding="utf-8")                                 # no coordinates
    assert snapshots.world_targets(tmp_path, str(bad), "360x685") == 1 and fake_shot == []


@pytest.mark.parametrize("names,extra,code", [
    (["a"], ["--size", "360x685"], 0),
    (["a", "fail_b"], ["--map", "zplondon", "--players", "4", "--unchecked"], 1),
    ([], ["--size", "360x685"], 1),
    (["a"], [], 2),                                              # argparse: the size is required
])
def test_world_cli_exit_status(snapshots, fake_shot, tmp_path, monkeypatch, names, extra, code):
    monkeypatch.setattr(sys, "argv", ["snapshots.py", str(tmp_path / "o"), "--world", _targets(tmp_path, names)]
                        + extra)
    with pytest.raises(SystemExit) as e:
        runpy.run_path(str(SNAPSHOTS), run_name="__main__")
    assert e.value.code == code
    if "--unchecked" in extra:
        assert all(c["unchecked"] for c in fake_shot)
