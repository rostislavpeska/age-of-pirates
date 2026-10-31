"""gameio.geom / inputs / CLI offline: the INPUT struct, the SendInput normalisation, the exact dry-run event lists,
and every refusal (not in front, abort corner, no window, a window of another process, outside the client, cursor
off target, another window under the press point, the foreground lost between the move and the press), the focus
settle, the one-call Alt tap, the guard audit of every non-release event, and the CLI's looked-at menu click
(fix round 2026-09-24, gameio review F2-F5 and F13). No test sends an
input event, changes a window, sleeps or takes a screenshot: the window lookups are faked and every state-changing
primitive is replaced by one that fails the test (the sandbox/census/tests/test_gamewin.py pattern). Runs on Linux
CI: nothing here needs Windows except the one scan-code test, which is skipped elsewhere."""
import ctypes
import math
import subprocess
import sys
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO))
from scripts.gameio import geom, inputs, win  # noqa: E402
from scripts.gameio import __main__ as cli  # noqa: E402

PRIMARY = (0, 0, 2560, 1080)
TWO = (0, 0, 5120, 1080)                  # a second 2560x1080 monitor right of the primary
LEFT_VDESK = (-2560, 0, 5120, 1080)       # a monitor LEFT of the primary: negative virtual origin
X64 = ctypes.sizeof(ctypes.c_void_p) == 8


def _boom(*_a, **_k):
    raise AssertionError("an input event, window change, sleep, process or screenshot happened")


class FakeWin:
    def __init__(self):
        self.hwnd = 4242
        self.client = PRIMARY
        self.vdesk = PRIMARY
        self.fg = True
        self.cursor = (1000, 500)
        self.exe = "AoE3DE_s.exe"
        self.under = None                   # the top-level window under a press point; None = the game


@pytest.fixture
def no_input(monkeypatch):
    for name in ("send_input", "set_foreground", "show_window"):
        monkeypatch.setattr(inputs, name, _boom)
    monkeypatch.setattr("time.sleep", _boom)
    monkeypatch.setattr(subprocess, "run", _boom)
    monkeypatch.setattr(subprocess, "Popen", _boom)


@pytest.fixture
def fake(monkeypatch, no_input):
    f = FakeWin()
    monkeypatch.setattr(win, "dpi_aware", lambda: False)
    monkeypatch.setattr(win, "find_window", lambda title=win.GAME_TITLE: f.hwnd)
    monkeypatch.setattr(win, "client_rect", lambda hwnd: f.client if hwnd else None)
    monkeypatch.setattr(win, "virtual_screen", lambda: f.vdesk)
    monkeypatch.setattr(win, "is_foreground", lambda hwnd: f.fg)
    monkeypatch.setattr(win, "foreground_title", lambda: win.GAME_TITLE if f.fg else "Visual Studio Code")
    monkeypatch.setattr(win, "cursor_pos", lambda: f.cursor)
    monkeypatch.setattr(win, "is_iconic", lambda hwnd: False)
    monkeypatch.setattr(win, "map_vk_to_scan", lambda vk: inputs.SCAN_FALLBACK.get(vk, 0))
    monkeypatch.setattr(win, "window_exe", lambda hwnd: f.exe if hwnd == f.hwnd else None)
    monkeypatch.setattr(win, "root_window_at", lambda x, y: f.hwnd if f.under is None else f.under)
    monkeypatch.setattr(win, "window_title", lambda hwnd: win.GAME_TITLE if hwnd == f.hwnd else "Windows toast")
    return f


@pytest.fixture
def live(monkeypatch, fake):
    """A 'live' session whose SendInput / sleep / focus calls are recorded instead of performed."""
    rec = {"sent": [], "sleeps": [], "fg_calls": []}
    monkeypatch.setattr(inputs, "send_input", lambda arr: rec["sent"].extend(arr) or len(arr))
    monkeypatch.setattr("time.sleep", lambda s: rec["sleeps"].append(s))
    monkeypatch.setattr(inputs, "set_foreground", lambda h: rec["fg_calls"].append(h) or True)
    return rec


# ------------------------------------------------------------------ the INPUT structure
def test_input_struct_is_the_full_union_size():
    # SendInput silently drops a keyboard-only INPUT (driver.py 2026-09-23); x64 INPUT = 40 bytes, x86 = 28
    assert ctypes.sizeof(inputs.INPUT) == (40 if X64 else 28)
    assert ctypes.sizeof(inputs.MOUSEINPUT) == (32 if X64 else 24)
    assert ctypes.sizeof(inputs.KEYBDINPUT) == (24 if X64 else 16)
    assert inputs.INPUT.u.offset == (8 if X64 else 4)
    k = inputs.key_input(0x1B, 0x01, 0)
    assert ctypes.sizeof(k) == ctypes.sizeof(inputs.INPUT) and k.type == 1 and k.u.ki.wScan == 1


# ------------------------------------------------------------------ normalisation
@pytest.mark.parametrize("span", [1080, 2560, 5120])
def test_axis_abs_lands_on_every_pixel_under_both_readings(span):
    for x in range(span):
        n = geom.axis_abs(x, 0, span)
        assert 0 <= n <= 65535
        assert round(n * (span - 1) / 65535) == x          # the documented linear reading
        assert math.floor(n * span / 65536) == x            # the floor(n * w / 65536) reading


def test_input_abs_one_monitor():
    assert geom.input_abs(444, 435, PRIMARY) == (11375, 26423)
    assert geom.input_abs(0, 0, PRIMARY) == (6, 15)
    assert geom.input_abs(2559, 1079, PRIMARY) == (65529, 65520)
    assert geom.input_abs(2269.33, 920.33, PRIMARY) == geom.input_abs(2269, 920, PRIMARY)   # pixel grid first
    assert geom.pixel_from_abs(*geom.input_abs(1398, 739, PRIMARY), PRIMARY) == (1398, 739)


def test_input_abs_two_monitors():
    # a second monitor right of the primary: the same client pixel lands 2560 px further right
    assert geom.input_abs(2560 + 1398, 739, TWO) == (50670, 44879)
    # a monitor left of the primary: the virtual origin is negative
    assert geom.input_abs(-2560 + 1398, 739, LEFT_VDESK) == (17899, 44879)
    assert geom.input_abs(1398, 739, LEFT_VDESK) == (50670, 44879)
    assert geom.input_abs(-2560, 0, LEFT_VDESK)[0] == geom.input_abs(0, 0, TWO)[0]
    for x, y in ((-2560, 0), (-1, 539), (0, 0), (2559, 1079)):
        assert geom.pixel_from_abs(*geom.input_abs(x, y, LEFT_VDESK), LEFT_VDESK) == (x, y)


def test_corner_and_rect_helpers():
    assert geom.in_corner(0, 0, (0, 0)) and geom.in_corner(4, 4, (0, 0)) and not geom.in_corner(5, 0, (0, 0))
    assert geom.in_corner(-2556, 2, (-2560, 0)) and not geom.in_corner(-1, 0, (0, 0))
    assert geom.in_rect(2559, 1079, PRIMARY) and not geom.in_rect(2560, 0, PRIMARY)
    assert geom.client_to_screen(1398, 739, (2560, 0, 2560, 1080)) == (3958, 739)
    assert geom.rect_ltrb((2560, 0, 2560, 1080)) == (2560, 0, 5120, 1080)


# ------------------------------------------------------------------ exact dry-run event lists
def test_dry_run_click_event_list(fake):
    s = inputs.Session(dry_run=True)
    s.click(444, 435, space="client")
    assert s.log == [
        {"event": "move", "x": 444, "y": 435, "client": (444, 435), "abs": (11375, 26423), "flags": 0xC001,
         "sent": False},
        {"event": "wait", "s": 0.2},
        {"event": "verify_cursor", "expect": (444, 435), "got": None},
        {"event": "verify_window", "at": (444, 435), "expect": 4242, "got": None},
        {"event": "down", "x": 444, "y": 435, "flags": 0x0002, "sent": False},
        {"event": "wait", "s": 0.09},
        {"event": "up", "x": 444, "y": 435, "flags": 0x0004, "sent": False},
    ]


def test_dry_run_click_on_a_second_monitor(fake):
    fake.client, fake.vdesk = (2560, 0, 2560, 1080), TWO
    s = inputs.Session(dry_run=True)
    s.click(1398, 739, space="client")
    mv = s.log[0]
    assert (mv["x"], mv["y"], mv["client"], mv["abs"]) == (3958, 739, (1398, 739), (50670, 44879))
    s.click(3958, 739)                                       # the same pixel in screen space
    assert len(s.log) == 14 and s.log[7] == mv


def test_click_point_uses_the_points_space(fake):
    from scripts.gameio import sheets
    fake.client, fake.vdesk = (2560, 0, 2560, 1080), TWO
    s = inputs.Session(dry_run=True)
    s.click_point(sheets.load_sheet(2560, 1080).point("editor.generate"))
    assert (s.log[0]["x"], s.log[0]["y"], s.log[0]["client"]) == (2560 + 1398, 739, (1398, 739))


def test_dry_run_key_event_list(fake):
    s = inputs.Session(dry_run=True)
    s.key("esc")
    s.key("End", times=2)
    esc = [{"event": "key_down", "key": "esc", "vk": 0x1B, "scan": 0x01, "flags": 0, "sent": False},
           {"event": "wait", "s": 0.03},
           {"event": "key_up", "key": "esc", "vk": 0x1B, "scan": 0x01, "flags": 0x0002, "sent": False},
           {"event": "wait", "s": 0.03}]
    end = [{"event": "key_down", "key": "end", "vk": 0x23, "scan": 0x4F, "flags": 0x0001, "sent": False},
           {"event": "wait", "s": 0.03},
           {"event": "key_up", "key": "end", "vk": 0x23, "scan": 0x4F, "flags": 0x0003, "sent": False},
           {"event": "wait", "s": 0.03}]
    assert s.log == esc + end + end


def test_dry_run_type_text_event_list(fake):
    s = inputs.Session(dry_run=True)
    s.type_text("a1")
    ev = []
    for ch in "a1":
        ev += [{"event": "char_down", "char": ch, "vk": 0, "scan": ord(ch), "flags": 0x0004, "sent": False},
               {"event": "wait", "s": 0.03},
               {"event": "char_up", "char": ch, "vk": 0, "scan": ord(ch), "flags": 0x0006, "sent": False},
               {"event": "wait", "s": 0.03}]
    assert s.log == ev


def test_dry_run_drag_event_list(fake):
    s = inputs.Session(dry_run=True)
    s.drag(1482, 500, 1482, 385, space="client", steps=4)
    kinds = [e["event"] if e["event"] != "wait" else ("wait", e["s"]) for e in s.log]
    assert kinds == ["move", ("wait", 0.15), "verify_cursor", "verify_window", "down", ("wait", 0.15)] + \
        ["move", ("wait", 0.04)] * 4 + [("wait", 0.15), "up", ("wait", 0.3)]
    assert [(e["x"], e["y"]) for e in s.log if e["event"] == "move"][-1] == (1482, 385)
    assert s.log[-2]["event"] == "up" and (s.log[-2]["x"], s.log[-2]["y"]) == (1482, 385)


def test_dry_run_prints_every_event(fake, capsys):
    import io
    buf = io.StringIO()
    s = inputs.Session(dry_run=True, out=buf)
    s.key("enter")
    lines = buf.getvalue().splitlines()
    assert len(lines) == 4 and all(line.startswith("DRY {") for line in lines)


# ------------------------------------------------------------------ refusals
def test_click_refused_when_the_game_is_not_in_front(fake):
    fake.fg = False
    s = inputs.Session()                                     # LIVE: send_input would fail the test if reached
    with pytest.raises(inputs.NotForeground):
        s.click(444, 435, space="client")
    assert s.log == [{"event": "refused", "what": "move at (444, 435)", "why": "NotForeground",
                      "detail": "the game is not in the foreground ('Visual Studio Code' is)"}]
    with pytest.raises(inputs.NotForeground):
        s.type_text("4242")                                  # never type into another window (2026-09-18)


def test_dry_run_refuses_like_a_live_run_until_focus(fake):
    fake.fg = False
    s = inputs.Session(dry_run=True)
    with pytest.raises(inputs.NotForeground):
        s.key("esc")
    assert s.focus() is True
    s.key("esc")
    assert s.log[1]["event"] == "focus" and s.log[1]["ok"] is None and s.log[1]["sent"] is False
    assert s.log[1]["switched"] is None
    # the dry run logs the settle wait a live switch would make (review F2), without sleeping
    assert s.log[2] == {"event": "wait", "s": inputs.Session.FOCUS_SETTLE_S, "why": "focus settle"}
    assert inputs.Session.FOCUS_SETTLE_S == 1.0
    assert [e["event"] for e in s.log[3:]] == ["key_down", "wait", "key_up", "wait"]


def test_require_foreground_false_skips_the_check(fake):
    fake.fg = False
    s = inputs.Session(dry_run=True, require_foreground=False)
    s.key("esc")
    assert s.log[0]["event"] == "key_down"


def test_abort_corner_stops_the_session_for_good(fake):
    fake.cursor = (2, 3)
    s = inputs.Session(dry_run=True)
    with pytest.raises(inputs.Aborted):
        s.click(444, 435, space="client")
    fake.cursor = (1000, 500)                                # moving away does not re-arm it
    with pytest.raises(inputs.Aborted):
        s.key("esc")
    with pytest.raises(inputs.Aborted):
        s.focus()
    assert all(e["event"] == "refused" and e["why"] == "Aborted" for e in s.log)


def test_abort_corner_of_a_virtual_desktop_left_of_the_primary(fake):
    fake.vdesk, fake.cursor = LEFT_VDESK, (-2559, 1)
    with pytest.raises(inputs.Aborted):
        inputs.Session(dry_run=True).key("esc")


def test_abort_corner_off(fake):
    fake.cursor = (0, 0)
    s = inputs.Session(dry_run=True, abort_corner=False)
    s.key("esc")
    assert s.log[0]["event"] == "key_down"


def test_game_not_found(fake):
    fake.hwnd = None
    with pytest.raises(inputs.GameNotFound):
        inputs.Session()
    with pytest.raises(inputs.GameNotFound):
        inputs.Session(dry_run=True)


@pytest.mark.parametrize("exe", ["chrome.exe", "explorer.exe", None])
def test_a_window_of_another_process_is_not_the_game(fake, exe):
    # review F4: the window is found by its title only; a browser tab or a folder can carry the same title
    fake.exe = exe
    for dry in (False, True):
        with pytest.raises(inputs.GameNotFound, match="not AoE3DE_s.exe"):
            inputs.Session(dry_run=dry)
    fake.exe = "aoe3de_s.EXE"                                # case does not matter on Windows
    assert inputs.Session().exe == "aoe3de_s.EXE"


def test_click_outside_the_client_area_is_refused(fake):
    fake.client = (2560, 0, 2560, 1080)                     # the game on monitor 2
    s = inputs.Session(dry_run=True)
    with pytest.raises(ValueError, match="outside the game's client area"):
        s.click(1398, 739)                                   # screen space: that is monitor 1
    with pytest.raises(ValueError):
        s.click(2560, 10, space="client")
    with pytest.raises(ValueError):
        s.click(10, 10, space="window")
    assert s.log == []


def test_resolve_key():
    assert inputs.resolve_key("ESC") == (0x1B, "esc")
    assert inputs.resolve_key("Backspace") == (0x08, "backspace")
    assert inputs.resolve_key("f5") == (0x74, "f5")
    assert inputs.resolve_key("a") == (0x41, "a") and inputs.resolve_key("7") == (0x37, "7")
    assert inputs.resolve_key(0x0D) == (0x0D, "enter") and inputs.resolve_key("0x2e")[0] == 0x2E
    with pytest.raises(ValueError):
        inputs.resolve_key("seed")


# ------------------------------------------------------------------ the live path, with SendInput recorded
def test_live_click_sends_drivers_sequence(fake, live):
    fake.cursor = (444, 435)                                 # the move 'landed'
    s = inputs.Session()
    s.click(444, 435, space="client")
    mv, dn, up = live["sent"]
    assert (mv.type, mv.u.mi.dx, mv.u.mi.dy, mv.u.mi.dwFlags) == (0, 11375, 26423, 0xC001)
    assert (dn.u.mi.dx, dn.u.mi.dy, dn.u.mi.dwFlags) == (0, 0, 0x0002)
    assert (up.u.mi.dx, up.u.mi.dy, up.u.mi.dwFlags) == (0, 0, 0x0004)
    assert live["sleeps"] == [0.2, 0.09]
    assert [e.get("sent") for e in s.log if e["event"] in ("move", "down", "up")] == [True, True, True]
    assert s.log[2] == {"event": "verify_cursor", "expect": (444, 435), "got": (444, 435)}
    assert s.log[3] == {"event": "verify_window", "at": (444, 435), "expect": 4242, "got": 4242}


@pytest.mark.parametrize("kind", ["click", "drag"])
def test_no_press_when_another_window_lies_under_the_point(fake, live, kind):
    # review F4: a toast over the minimap while the game is still the foreground window
    fake.cursor, fake.under = (2449, 933), 777
    s = inputs.Session()
    with pytest.raises(inputs.NotForeground, match="Windows toast"):
        if kind == "click":
            s.click(2449, 933, space="client")
        else:
            s.drag(2449, 933, 2460, 940, space="client")
    assert [i.u.mi.dwFlags for i in live["sent"]] == [0xC001]              # the move only: no press, no release
    assert s.log[-2]["event"] == "verify_window" and s.log[-2]["got"] == 777
    assert s.log[-1]["event"] == "refused" and s.log[-1]["why"] == "NotForeground"


def test_foreground_flip_between_the_move_and_the_press(fake, live, monkeypatch):
    # review F13 (probe_session.py step 2): the owner clicks another window during the 0.2 s settle
    fake.cursor = (2448, 933)
    reads = {"n": 0}

    def is_fg(hwnd):
        reads["n"] += 1
        return reads["n"] <= 1                                   # True for the move's check, False from then on
    monkeypatch.setattr(win, "is_foreground", is_fg)
    s = inputs.Session()
    with pytest.raises(inputs.NotForeground):
        s.click(2448, 933, space="client")
    assert [i.u.mi.dwFlags for i in live["sent"]] == [0xC001]


def test_every_non_release_event_is_guarded(fake, monkeypatch):
    """review F13 (probe_session.py audit): every SendInput call that is not a release is preceded, since the
    previous send, by the corner guard (GetCursorPos) AND the foreground check - for click, move, key, type, drag."""
    trace = []
    monkeypatch.setattr(win, "cursor_pos", lambda: trace.append("cursor") or fake.cursor)
    monkeypatch.setattr(win, "is_foreground", lambda h: trace.append("fg") or True)

    def send(arr):
        for i in arr:
            if i.type == 0 and i.u.mi.dwFlags & 0x8000:
                fake.cursor = geom.pixel_from_abs(i.u.mi.dx, i.u.mi.dy, fake.vdesk)
            release = (i.type == 0 and i.u.mi.dwFlags == 0x0004) or (i.type == 1 and i.u.ki.dwFlags & 0x2)
            trace.append(("release",) if release else ("send",))
        return len(arr)
    monkeypatch.setattr(inputs, "send_input", send)
    monkeypatch.setattr("time.sleep", lambda s: None)
    fake.vdesk = (-2560, -522, 5120, 1602)                    # this device's desktop, left monitor included
    s = inputs.Session()
    s.click(2448, 933, space="client")
    s.move(2509, 1009, space="client")
    s.key("esc")
    s.key("end", times=2)
    s.type_text("ldn_t1")
    s.drag(1482, 500, 1482, 385, space="client", steps=4)
    seen, bad, n = set(), [], 0
    for t in trace:
        if t in ("cursor", "fg"):
            seen.add(t)
        else:
            n += 1
            if t == ("send",) and seen != {"cursor", "fg"}:
                bad.append(n)
            seen = set()
    assert n == 3 + 1 + 2 + 4 + 12 + 7 and not bad              # click, move, esc, end x2, 'ldn_t1', drag (4 steps)
    assert all(tuple(e["got"]) == tuple(e["expect"]) for e in s.log if e["event"] == "verify_cursor")


def test_live_click_with_the_cursor_off_target_never_presses(fake, live):
    fake.cursor = (500, 500)
    s = inputs.Session()
    with pytest.raises(inputs.CursorMismatch):
        s.click(444, 435, space="client")
    assert len(live["sent"]) == 1 and live["sent"][0].u.mi.dwFlags == 0xC001
    assert s.log[-1]["why"] == "CursorMismatch"


def test_the_release_after_a_press_is_never_withheld(fake, live, monkeypatch):
    fake.cursor = (444, 435)

    def sleep(s):
        if s == 0.09:
            raise KeyboardInterrupt                          # interrupted while the button is down
    monkeypatch.setattr("time.sleep", sleep)
    s = inputs.Session()
    with pytest.raises(KeyboardInterrupt):
        s.click(444, 435, space="client")
    assert live["sent"][-1].u.mi.dwFlags == 0x0004


def test_abort_between_characters_leaves_no_key_down(fake, live, monkeypatch):
    reads = iter([(1000, 500), (0, 0)])                     # the second guard finds the cursor in the corner
    monkeypatch.setattr(win, "cursor_pos", lambda: next(reads))
    s = inputs.Session()
    with pytest.raises(inputs.Aborted):
        s.type_text("ab")
    assert [(k.u.ki.wScan, k.u.ki.dwFlags) for k in live["sent"]] == [(ord("a"), 0x4), (ord("a"), 0x6)]


def test_live_focus(fake, live, monkeypatch):
    fake.fg = False

    def set_fg(h):
        live["fg_calls"].append(h)
        fake.fg = True
        return True
    monkeypatch.setattr(inputs, "set_foreground", set_fg)
    calls = []
    monkeypatch.setattr(inputs, "send_input", lambda arr: calls.append(list(arr)) or live["sent"].extend(arr) or len(arr))
    s = inputs.Session()
    assert s.focus() is True
    assert [(k.u.ki.wVk, k.u.ki.dwFlags) for k in live["sent"]] == [(0x12, 0), (0x12, 0x2)]   # the Alt tap
    assert len(calls) == 1                                   # down + up in ONE SendInput call (review F5)
    assert live["fg_calls"] == [4242]
    ev = s.log[-2]
    assert ev["event"] == "focus" and ev["ok"] is True and ev["switched"] is True and ev["restored"] is False
    # it switched: 1.0 s settle before the first event (review F2)
    assert s.log[-1] == {"event": "wait", "s": 1.0, "why": "focus settle"} and live["sleeps"] == [1.0]


def test_a_failed_alt_tap_still_sends_the_key_up(fake, live, monkeypatch):
    # review F5: the Alt release is protected like every other release
    fake.fg = False
    calls = []

    def send(arr):
        calls.append([(k.u.ki.wVk, k.u.ki.dwFlags) for k in arr])
        if len(calls) == 1:
            raise OSError("SendInput accepted 1 of 2 events")
        return len(arr)
    monkeypatch.setattr(inputs, "send_input", send)
    s = inputs.Session()
    with pytest.raises(OSError):
        s.focus()
    assert calls == [[(0x12, 0), (0x12, 0x2)], [(0x12, 0x2)]] and live["fg_calls"] == []


def test_live_focus_times_out(fake, live):
    fake.fg = False
    s = inputs.Session()
    assert s.focus(timeout=0.3) is False                    # set_foreground 'worked' but the game never came up
    assert live["sleeps"] == [0.1, 0.1, 0.1]                # polls only: no settle after a failed switch
    assert s.log[-1]["ok"] is False and s.log[-1]["foreground_title"] == "Visual Studio Code"
    assert s.log[-1]["switched"] is False


def test_focus_when_already_in_front_sends_nothing(fake):
    s = inputs.Session()                                     # live, but send_input fails the test if reached
    assert s.focus() is True
    assert s.log == [{"event": "focus", "already": True, "switched": False, "ok": True, "sent": False}]


def test_check_sends_nothing_and_never_takes_the_foreground(fake):
    s = inputs.Session()                                     # live: send_input / set_foreground fail the test
    s.check("retry")
    assert s.log == []
    fake.fg = False
    with pytest.raises(inputs.NotForeground):
        s.check("retry click 2")
    assert s.log[-1]["what"] == "retry click 2" and s.log[-1]["why"] == "NotForeground"
    fake.cursor = (1, 1)
    with pytest.raises(inputs.Aborted):
        s.check()


# ------------------------------------------------------------------ CLI
def test_cli_dry_run_click(fake, capsys):
    assert cli.main(["click", "444", "435", "--client", "--dry-run"]) == 0
    out = capsys.readouterr().out.splitlines()
    assert len(out) == 8 and all(line.startswith("DRY {") for line in out)
    assert '"already": true' in out[0] and '"abs": [11375, 26423]' in out[1] and '"verify_window"' in out[4]


def test_cli_dry_run_key_in_the_background_plans_after_focus(fake, capsys):
    fake.fg = False
    assert cli.main(["key", "esc", "--times", "2", "--dry-run"]) == 0
    out = capsys.readouterr().out
    assert '"event": "focus"' in out and out.count('"key_down"') == 2


def test_cli_no_window(fake, capsys):
    fake.hwnd = None
    assert cli.main(["click", "10", "10", "--dry-run"]) == 2
    assert "GAME WINDOW NOT FOUND" in capsys.readouterr().out


def test_cli_live_click_stops_when_focus_fails(fake, live, capsys):
    fake.fg = False
    assert cli.main(["click", "444", "435", "--client"]) == 3
    assert [k.type for k in live["sent"]] == [1, 1]          # only the Alt tap of the focus attempt
    assert "did not come to the foreground" in capsys.readouterr().out


def test_cli_unknown_key(fake, capsys):
    assert cli.main(["key", "seed", "--dry-run"]) == 1


def test_cli_menu_dry_run_plans_the_measured_point(fake, capsys, monkeypatch):
    from scripts.gameio import capture
    fake.fg = False
    monkeypatch.setattr(capture, "grab", _boom)                             # a dry run never captures
    assert cli.main(["menu", "skirmish", "--dry-run"]) == 0
    out = capsys.readouterr().out
    assert "DRY look skipped" in out and '"client": [444, 435]' in out and '"event": "down"' in out
    assert cli.main(["menu", "exit", "--dry-run"]) == 1                     # not a sheet point
    assert "no point 'menu.exit'" in capsys.readouterr().out


def _menu_canvas(shift_y=0):
    """The live 2026-09-24 home menu rebuilt from its committed crops (fixtures/screens_fixtures.json)."""
    Image = pytest.importorskip("PIL.Image")
    import json
    fix = Path(__file__).resolve().parent / "fixtures"
    f = json.loads((fix / "screens_fixtures.json").read_text(encoding="utf-8"))["fixtures"]["menu_20260924"]
    can = Image.new("RGB", tuple(f["size"]), (255, 0, 255))
    for c in f["crops"].values():
        box = c["box"]
        dy = shift_y if box[0] < 1000 else 0                 # only the menu column moves
        if not (fix / c["file"]).is_file():
            pytest.skip("capture %s absent: images never enter the repo (AGENTS.md rule 8), the crop lives only where it was made" % c["file"])
        can.paste(Image.open(fix / c["file"]).convert("RGB"), (box[0], box[1] + dy))
    return can


@pytest.mark.parametrize("name,xy", [("skirmish", (444, 435)), ("scenario_editor", (440, 600)), ("tools", (444, 709))])
def test_cli_menu_looks_then_clicks(fake, live, monkeypatch, name, xy):
    from scripts.gameio import capture
    img = _menu_canvas()
    grabs = []
    monkeypatch.setattr(capture, "grab", lambda bbox=None, all_screens=True: grabs.append(bbox) or img)
    fake.cursor = xy
    assert cli.main(["menu", name]) == 0
    assert grabs == [(0, 0, 2560, 1080)]
    mv, dn, up = live["sent"]
    assert geom.pixel_from_abs(mv.u.mi.dx, mv.u.mi.dy, PRIMARY) == xy and (dn.u.mi.dwFlags, up.u.mi.dwFlags) == (2, 4)


def test_cli_menu_refuses_a_shifted_layout(fake, live, monkeypatch, capsys):
    # the 2026-08-26 menu had one button more above Skirmish: everything one 55 px pitch lower
    from scripts.gameio import capture
    img = _menu_canvas(shift_y=55)
    monkeypatch.setattr(capture, "grab", lambda bbox=None, all_screens=True: img)
    fake.cursor = (444, 435)
    assert cli.main(["menu", "skirmish"]) == 6
    assert live["sent"] == [] and "not the measured home menu" in capsys.readouterr().out


# ------------------------------------------------------------------ import hygiene and Windows facts
def test_importing_the_package_makes_no_win32_call():
    code = ("import ctypes, sys\n"
            "class Boom:\n"
            "    def __getattr__(self, n): raise AssertionError('Win32 at import: ' + n)\n"
            "ctypes.windll = Boom()\n"
            "ctypes.WinDLL = lambda *a, **k: (_ for _ in ()).throw(AssertionError('WinDLL at import'))\n"
            "sys.path.insert(0, sys.argv[1])\n"
            "import scripts.gameio, scripts.gameio.win, scripts.gameio.geom, scripts.gameio.inputs\n"
            "import scripts.gameio.capture, scripts.gameio.sheets, scripts.gameio.screens\n"
            "import scripts.gameio.__main__\n"
            "print('clean')\n")
    r = subprocess.run([sys.executable, "-c", code, str(REPO)], capture_output=True, text=True, timeout=60)
    assert r.returncode == 0 and r.stdout.strip() == "clean", r.stderr[-800:]


@pytest.mark.skipif(sys.platform != "win32", reason="MapVirtualKeyW exists on Windows only")
def test_windows_scan_codes_match_the_fallback_table():
    for name in ("esc", "enter", "backspace", "end", "home", "delete", "tab", "space", "left", "f5"):
        vk = inputs.KEYS[name]
        assert win.map_vk_to_scan(vk) == inputs.SCAN_FALLBACK[vk], name
