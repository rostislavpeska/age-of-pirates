"""Input for the game window: one Session object, a guard before every event, and an exact dry run.

    s = Session()                  # finds the window of AoE3DE_s.exe (GameNotFound otherwise); nothing is sent
    s.focus()                      # Alt tap, restore if minimised, SetForegroundWindow, poll up to 2 s, then a
                                   # 1.0 s settle when it switched -> bool
    s.check()                      # the guard + foreground check only, never takes the foreground back
    s.click(444, 435, space="client")
    s.key("esc"); s.type_text("ldn_t1")

Sources (copied, not imported - importing driver.py or game_driver.py runs Win32 calls at import):
  - click timings from scripts/aitest/driver.py click: move, 0.2 s, left down, 0.09 s, left up. The press and the
    release carry no coordinates (they happen where the move put the cursor), as there. driver.py's timings carry
    the most live runs (both devices, 2026-08-26..2026-09-24).
  - keys from driver.key_vk (fixed 2026-09-23, issue I5): the scan code from MapVirtualKeyW plus the extended flag
    for navigation keys, in a FULL-size INPUT (SendInput silently drops a keyboard-only struct) - the game ignored
    a VK-only Backspace in the lobby. Timing: down, 30 ms, up, 30 ms.
  - type_text from driver.type_text: KEYEVENTF_UNICODE per character, 30 ms gaps.
  - focus from sandbox/census/game_driver.focus (SendInput Alt tap, then SetForegroundWindow), plus what none of the
    copies did: SW_RESTORE only when minimised, and a poll of GetForegroundWindow for up to 2 s.
  - drag timings from game_driver.drag.
  - the abort corner from driver.guard (cursor in the top-left corner -> stop).
Differences, all deliberate:
  - mouse coordinates are normalised over the VIRTUAL desktop (MOUSEEVENTF_VIRTUALDESK, gamewin.Pilot), so a game
    window on any monitor is reached; the arithmetic is geom.input_abs (rounded, not truncated).
  - BEFORE EVERY EVENT: the abort corner (cursor within 5 px of the top-left corner of the primary monitor or of
    the virtual desktop -> Aborted, and the session refuses everything afterwards) and, with
    require_foreground, GetForegroundWindow == the game (else NotForeground: recorded failures typed a seed into
    Windows search, 2026-09-18, and clicked VS Code, 2026-09-22). The release that follows a press is never
    withheld, so no button or key is left down.
  - a click must land inside the game's client area (ValueError otherwise), and after the move the cursor is read
    back: more than 1 px off -> CursorMismatch, no press.
  - before every PRESS (click, drag) the top-level window under the press point, GetAncestor(WindowFromPoint,
    GA_ROOT), must be the game's window, else NotForeground and no press (review F4, 2026-09-24: a Windows toast
    bottom-right sits exactly over the 2560x1080 minimap while the game stays the foreground window).
  - Session() also checks that the window titled like the game belongs to AoE3DE_s.exe (GetWindowThreadProcessId
    + the process image name), else GameNotFound: a browser tab or an explorer folder can carry the same title.
  - focus() waits FOCUS_SETTLE_S = 1.0 s after it actually switched the foreground (driver.focus_game's live
    value; review F2: without it the gameio CLI pressed 0.2 s after SetForegroundWindow, and the game eats the
    first click after regaining focus). The Alt tap goes out as ONE SendInput call (down + up), and a lone key-up
    follows if that call fails, so Alt is never left down (review F5).
  - check() runs the guard and the foreground check alone and sends nothing: for callers that must NOT take the
    foreground back from the owner (camera.py's retry and every later target of a batch, review F1).
  - dry_run=True sends nothing, never sleeps, and records exactly the events a live run would send, in order
    (self.log). A dry-run focus() is taken as successful, so the rest of a flow can be planned while the game is
    in the background; without it the dry run refuses like a live one. The dry run reads neither the cursor nor
    the window under a press point (verify_cursor / verify_window log got None).
No Win32 call at import; Session() calls win.dpi_aware().
"""
from __future__ import annotations

import ctypes
import json
import time
from typing import Dict, List, Optional, Tuple, Union

from . import geom, win
from .win import GAME_EXE, GAME_TITLE

INPUT_MOUSE, INPUT_KEYBOARD = 0, 1
MOUSEEVENTF_MOVE = 0x0001
MOUSEEVENTF_LEFTDOWN = 0x0002
MOUSEEVENTF_LEFTUP = 0x0004
MOUSEEVENTF_VIRTUALDESK = 0x4000
MOUSEEVENTF_ABSOLUTE = 0x8000
MOVE_ABS = MOUSEEVENTF_MOVE | MOUSEEVENTF_VIRTUALDESK | MOUSEEVENTF_ABSOLUTE      # 0xC001
KEYEVENTF_EXTENDEDKEY = 0x0001
KEYEVENTF_KEYUP = 0x0002
KEYEVENTF_UNICODE = 0x0004
VK_MENU = 0x12
SW_RESTORE = 9

# ------------------------------------------------------------------ the INPUT structure (x64: 40 bytes, x86: 28)
ULONG_PTR = ctypes.c_size_t


class MOUSEINPUT(ctypes.Structure):
    _fields_ = [("dx", ctypes.c_int32), ("dy", ctypes.c_int32), ("mouseData", ctypes.c_uint32),
                ("dwFlags", ctypes.c_uint32), ("time", ctypes.c_uint32), ("dwExtraInfo", ULONG_PTR)]


class KEYBDINPUT(ctypes.Structure):
    _fields_ = [("wVk", ctypes.c_uint16), ("wScan", ctypes.c_uint16), ("dwFlags", ctypes.c_uint32),
                ("time", ctypes.c_uint32), ("dwExtraInfo", ULONG_PTR)]


class HARDWAREINPUT(ctypes.Structure):
    _fields_ = [("uMsg", ctypes.c_uint32), ("wParamL", ctypes.c_uint16), ("wParamH", ctypes.c_uint16)]


class _INPUTUNION(ctypes.Union):
    # all three members: SendInput checks cbSize against the FULL INPUT and silently drops a keyboard-only struct
    # (driver.py _KIU, 2026-09-23: every typed key of the map search was lost)
    _fields_ = [("mi", MOUSEINPUT), ("ki", KEYBDINPUT), ("hi", HARDWAREINPUT)]


class INPUT(ctypes.Structure):
    _fields_ = [("type", ctypes.c_uint32), ("u", _INPUTUNION)]


def mouse_input(ax: int, ay: int, flags: int) -> INPUT:
    i = INPUT(type=INPUT_MOUSE)
    i.u.mi = MOUSEINPUT(ax, ay, 0, flags, 0, 0)
    return i


def key_input(vk: int, scan: int, flags: int) -> INPUT:
    i = INPUT(type=INPUT_KEYBOARD)
    i.u.ki = KEYBDINPUT(vk, scan, flags, 0, 0)
    return i


# ------------------------------------------------------------------ the three state-changing primitives
def send_input(inputs: List[INPUT]) -> int:
    """SendInput; raises OSError when Windows accepted fewer events than given (UIPI, a secure desktop)."""
    u = win.user32()
    u.SendInput.argtypes = [ctypes.c_uint, ctypes.POINTER(INPUT), ctypes.c_int]
    u.SendInput.restype = ctypes.c_uint
    arr = (INPUT * len(inputs))(*inputs)
    n = u.SendInput(len(inputs), arr, ctypes.sizeof(INPUT))
    if n != len(inputs):
        raise OSError(f"SendInput accepted {n} of {len(inputs)} events (error {ctypes.get_last_error()})")
    return n


def set_foreground(hwnd) -> bool:
    u = win.user32()
    u.SetForegroundWindow.argtypes = [ctypes.c_void_p]
    return bool(u.SetForegroundWindow(hwnd))


def show_window(hwnd, cmd: int) -> bool:
    u = win.user32()
    u.ShowWindow.argtypes = [ctypes.c_void_p, ctypes.c_int]
    return bool(u.ShowWindow(hwnd, cmd))


# ------------------------------------------------------------------ keys
KEYS: Dict[str, int] = {
    "esc": 0x1B, "escape": 0x1B, "enter": 0x0D, "return": 0x0D, "tab": 0x09, "space": 0x20,
    "backspace": 0x08, "delete": 0x2E, "del": 0x2E, "insert": 0x2D, "home": 0x24, "end": 0x23,
    "pageup": 0x21, "pagedown": 0x22, "left": 0x25, "up": 0x26, "right": 0x27, "down": 0x28,
    "shift": 0x10, "ctrl": 0x11, "alt": 0x12,
    **{f"f{i}": 0x6F + i for i in range(1, 13)},
}
# PC/AT set-1 scan codes of the layout-independent keys: what MapVirtualKeyW returns for them. Used only where
# MapVirtualKeyW is unavailable (off Windows: a dry run on Linux CI); letters and digits depend on the keyboard
# layout (this device types Czech QWERTZ) and log scan 0 there.
SCAN_FALLBACK: Dict[int, int] = {
    0x1B: 0x01, 0x08: 0x0E, 0x09: 0x0F, 0x0D: 0x1C, 0x11: 0x1D, 0x10: 0x2A, 0x12: 0x38, 0x20: 0x39,
    0x24: 0x47, 0x26: 0x48, 0x21: 0x49, 0x25: 0x4B, 0x27: 0x4D, 0x23: 0x4F, 0x28: 0x50, 0x22: 0x51,
    0x2D: 0x52, 0x2E: 0x53,
    **{0x6F + i: 0x3A + i for i in range(1, 11)}, 0x7A: 0x57, 0x7B: 0x58,
}
# driver.key_vk's extended set (End, Home, arrows, Insert, Delete) plus Page Up / Page Down, which the
# KEYEVENTF_EXTENDEDKEY documentation lists among the extended keys of the navigation cluster.
EXTENDED_VKS = frozenset({0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28, 0x2D, 0x2E})


def resolve_key(name_or_vk: Union[str, int]) -> Tuple[int, str]:
    """'esc' / 'End' / 'f5' / 'a' / 0x1B -> (vk, name)."""
    if isinstance(name_or_vk, int):
        vk = name_or_vk
        names = [k for k, v in KEYS.items() if v == vk]
        return vk, (names[0] if names else f"vk 0x{vk:02X}")
    s = str(name_or_vk).strip()
    low = s.lower()
    if low in KEYS:
        return KEYS[low], low
    if low.startswith("0x"):
        return resolve_key(int(low, 16))
    if len(s) == 1 and s.isalnum() and s.isascii():
        return ord(s.upper()), s.lower()
    raise ValueError(f"unknown key {name_or_vk!r} (names: {', '.join(sorted(KEYS))}, a letter or digit, or 0xNN)")


def scan_code(vk: int) -> int:
    """MapVirtualKeyW (driver.key_vk) on Windows; the set-1 table elsewhere."""
    if win.is_windows():
        return win.map_vk_to_scan(vk)
    return SCAN_FALLBACK.get(vk, 0)


# ------------------------------------------------------------------ exceptions
class GameNotFound(Exception):
    """No window with the game's title, or that window does not belong to AoE3DE_s.exe: nothing was sent."""


class NotForeground(Exception):
    """The game window is not in the foreground, or another window lies under the press point: the event was NOT
    sent."""


class Aborted(Exception):
    """The cursor is in the abort corner: the event was NOT sent, and the session refuses all further events."""


class CursorMismatch(Exception):
    """After the move the cursor is not where the click was aimed: no press was sent."""


# ------------------------------------------------------------------ the session
class Session:
    CLICK_SETTLE_S = 0.2        # driver.click: move, 0.2 s, down
    CLICK_HOLD_S = 0.09         # driver.click: down, 0.09 s, up
    KEY_GAP_S = 0.03            # driver.key_vk: down, 30 ms, up, 30 ms
    CHAR_GAP_S = 0.03           # driver.type_text
    FOCUS_TIMEOUT_S = 2.0
    FOCUS_POLL_S = 0.1
    FOCUS_SETTLE_S = 1.0        # driver.focus_game's live-run wait after SetForegroundWindow (review F2)
    CURSOR_TOL_PX = 1
    ABORT_SIZE_PX = 5

    def __init__(self, title: str = GAME_TITLE, dry_run: bool = False, require_foreground: bool = True,
                 abort_corner: bool = True, out=None):
        win.dpi_aware()
        self.title = title
        self.dry_run = dry_run
        self.require_foreground = require_foreground
        self.abort_corner = abort_corner
        self.out = out                      # a text stream: every event is printed as one JSON line when set
        self.log: List[Dict] = []
        self.hwnd = win.find_window(title)
        if not self.hwnd:
            raise GameNotFound(f"no window titled {title!r} - nothing was sent")
        self.exe = win.window_exe(self.hwnd)
        if not self.exe or self.exe.lower() != GAME_EXE.lower():
            raise GameNotFound(f"the window titled {title!r} (hwnd {self.hwnd}) belongs to "
                               f"{self.exe or 'a process whose name cannot be read'}, not {GAME_EXE} - nothing was sent")
        self.vdesk = win.virtual_screen()
        self._dry_focused = False
        self._aborted = False

    # ---------------------------------------------------------- bookkeeping
    def _record(self, ev: Dict) -> Dict:
        self.log.append(ev)
        if self.out is not None:
            tag = "DRY " if self.dry_run else ""
            print(tag + json.dumps(ev, default=list), file=self.out, flush=True)
        return ev

    def client_rect(self) -> Tuple[int, int, int, int]:
        c = win.client_rect(self.hwnd)
        if c is None:
            raise GameNotFound("the game window is gone - nothing was sent")
        return c

    def _refuse(self, exc_type, what: str, why: str):
        self._record({"event": "refused", "what": what, "why": exc_type.__name__, "detail": why})
        raise exc_type(f"{what}: {why} - not sent")

    def _guard(self, what: str) -> None:
        if self._aborted:
            self._refuse(Aborted, what, "this session was aborted earlier")
        if not self.abort_corner:
            return
        x, y = win.cursor_pos()
        corners = [(0, 0), (self.vdesk[0], self.vdesk[1])]
        if any(geom.in_corner(x, y, c, self.ABORT_SIZE_PX) for c in corners):
            self._aborted = True
            self._refuse(Aborted, what, f"cursor at ({x}, {y}) is in the abort corner")

    def _check(self, what: str) -> None:
        self._guard(what)
        if self.require_foreground and not win.is_foreground(self.hwnd):
            if self.dry_run and self._dry_focused:
                return
            self._refuse(NotForeground, what, f"the game is not in the foreground ({win.foreground_title()!r} is)")

    def check(self, what: str = "check") -> None:
        """The abort-corner guard and the foreground check alone; sends nothing. Raises Aborted / NotForeground
        (logged as a refusal). For callers that must not take the foreground back from the owner: camera.py's
        retry click and every target of a batch after the first (review F1, 2026-09-24)."""
        self._check(what)

    def _target(self, x: float, y: float, space: str, what: str) -> Tuple[int, int, int, int]:
        client = self.client_rect()
        if space == "client":
            sx, sy = geom.client_to_screen(x, y, client)
        elif space == "screen":
            sx, sy = int(round(x)), int(round(y))
        else:
            raise ValueError(f"space must be 'screen' or 'client', not {space!r}")
        if not geom.in_rect(sx, sy, client):
            raise ValueError(f"{what} at screen ({sx}, {sy}) is outside the game's client area {client} "
                             f"- nothing was sent")
        return sx, sy, sx - client[0], sy - client[1]

    def _send(self, ev: Dict, inputs: List[INPUT]) -> Dict:
        ev["sent"] = not self.dry_run
        if not self.dry_run:
            try:
                send_input(inputs)
            except OSError as e:
                ev["sent"] = False
                ev["error"] = str(e)
                self._record(ev)
                raise
        return self._record(ev)

    def wait(self, seconds: float, why: str = "") -> None:
        ev = {"event": "wait", "s": seconds}
        if why:
            ev["why"] = why
        self._record(ev)
        if not self.dry_run:
            time.sleep(seconds)

    # ---------------------------------------------------------- mouse
    def _mouse(self, kind: str, sx: int, sy: int, flags: int, check: bool = True, client=None) -> Dict:
        if check:
            self._check(f"{kind} at ({sx}, {sy})")
        ev: Dict = {"event": kind, "x": sx, "y": sy}
        if client is not None:
            ev["client"] = client
        if flags & MOUSEEVENTF_ABSOLUTE:
            ax, ay = geom.input_abs(sx, sy, self.vdesk)
            ev["abs"] = (ax, ay)
        else:
            ax = ay = 0                     # press / release where the cursor is (driver.click)
        ev["flags"] = flags
        return self._send(ev, [mouse_input(ax, ay, flags)])

    def _verify_cursor(self, sx: int, sy: int) -> None:
        self._guard(f"verify cursor at ({sx}, {sy})")
        if self.dry_run:
            self._record({"event": "verify_cursor", "expect": (sx, sy), "got": None})
            return
        got = win.cursor_pos()
        self._record({"event": "verify_cursor", "expect": (sx, sy), "got": tuple(got)})
        if max(abs(got[0] - sx), abs(got[1] - sy)) > self.CURSOR_TOL_PX:
            self._refuse(CursorMismatch, f"click at ({sx}, {sy})", f"the cursor landed at {tuple(got)}")

    def _verify_window(self, sx: int, sy: int) -> None:
        """Before a press: the top-level window under (sx, sy) must be the game's (review F4)."""
        if self.dry_run:
            self._record({"event": "verify_window", "at": (sx, sy), "expect": self.hwnd, "got": None})
            return
        got = win.root_window_at(sx, sy)
        self._record({"event": "verify_window", "at": (sx, sy), "expect": self.hwnd, "got": got})
        if got is None or int(got) != int(self.hwnd):
            self._refuse(NotForeground, f"press at ({sx}, {sy})",
                         f"the window under the press point is {win.window_title(got)!r} (hwnd {got}), not the game")

    def _before_press(self, sx: int, sy: int) -> None:
        self._verify_cursor(sx, sy)
        self._verify_window(sx, sy)

    def move(self, x: float, y: float, space: str = "screen") -> Dict:
        sx, sy, cx, cy = self._target(x, y, space, "move")
        return self._mouse("move", sx, sy, MOVE_ABS, client=(cx, cy))

    def click(self, x: float, y: float, space: str = "screen") -> None:
        """Left click: move, 0.2 s, read the cursor back, check the window under it, down, 0.09 s, up
        (driver.click's timings)."""
        sx, sy, cx, cy = self._target(x, y, space, "click")
        self._mouse("move", sx, sy, MOVE_ABS, client=(cx, cy))
        self.wait(self.CLICK_SETTLE_S)
        self._before_press(sx, sy)
        self._mouse("down", sx, sy, MOUSEEVENTF_LEFTDOWN)
        try:
            self.wait(self.CLICK_HOLD_S)
        finally:
            self._mouse("up", sx, sy, MOUSEEVENTF_LEFTUP, check=False)

    def click_point(self, point: Dict) -> None:
        """Click a sheet point (sheets.Sheet.point) in its own space ('client' for every 2560x1080 point)."""
        self.click(point["x"], point["y"], space=point.get("space", "screen"))

    def drag(self, x1: float, y1: float, x2: float, y2: float, space: str = "screen", steps: int = 12) -> None:
        """Left drag with game_driver.drag's timings (0.15 s after the move and the press, 40 ms per step,
        0.15 s before and 0.3 s after the release). Both ends must lie in the client area."""
        s1 = self._target(x1, y1, space, "drag start")
        s2 = self._target(x2, y2, space, "drag end")
        self._mouse("move", s1[0], s1[1], MOVE_ABS, client=(s1[2], s1[3]))
        self.wait(0.15)
        self._before_press(s1[0], s1[1])
        self._mouse("down", s1[0], s1[1], MOUSEEVENTF_LEFTDOWN)
        last = (s1[0], s1[1])
        try:
            self.wait(0.15)
            for k in range(1, steps + 1):
                px = round(s1[0] + (s2[0] - s1[0]) * k / steps)
                py = round(s1[1] + (s2[1] - s1[1]) * k / steps)
                self._mouse("move", px, py, MOVE_ABS, client=(px - s1[0] + s1[2], py - s1[1] + s1[3]))
                last = (px, py)
                self.wait(0.04)
            self.wait(0.15)
        finally:
            self._mouse("up", last[0], last[1], MOUSEEVENTF_LEFTUP, check=False)
        self.wait(0.3)

    # ---------------------------------------------------------- keyboard
    def _keyev(self, kind: str, vk: int, scan: int, flags: int, check: bool = True, **extra) -> Dict:
        if check:
            self._check(f"{kind} {extra.get('key') or extra.get('char')!r}")
        ev: Dict = {"event": kind, **extra, "vk": vk, "scan": scan, "flags": flags}
        return self._send(ev, [key_input(vk, scan, flags)])

    def key(self, name_or_vk: Union[str, int], times: int = 1) -> None:
        """Tap a key `times` times: scan code + extended flag, down, 30 ms, up, 30 ms (driver.key_vk)."""
        vk, name = resolve_key(name_or_vk)
        scan = scan_code(vk)
        ext = KEYEVENTF_EXTENDEDKEY if vk in EXTENDED_VKS else 0
        for _ in range(times):
            self._keyev("key_down", vk, scan, ext, key=name)
            try:
                self.wait(self.KEY_GAP_S)
            finally:
                self._keyev("key_up", vk, scan, ext | KEYEVENTF_KEYUP, check=False, key=name)
            self.wait(self.KEY_GAP_S)

    def type_text(self, s: str) -> None:
        """Type text as KEYEVENTF_UNICODE characters, 30 ms gaps (driver.type_text); characters outside the
        basic plane go as their two UTF-16 units."""
        for ch in str(s):
            data = ch.encode("utf-16-le")
            for i in range(0, len(data), 2):
                unit = data[i] | (data[i + 1] << 8)
                self._keyev("char_down", 0, unit, KEYEVENTF_UNICODE, char=ch)
                try:
                    self.wait(self.CHAR_GAP_S)
                finally:
                    self._keyev("char_up", 0, unit, KEYEVENTF_UNICODE | KEYEVENTF_KEYUP, check=False, char=ch)
                self.wait(self.CHAR_GAP_S)

    # ---------------------------------------------------------- focus
    @staticmethod
    def _alt_tap(scan: int) -> None:
        """Alt down + up in ONE SendInput call; if that call fails, a lone key-up follows (review F5: two separate
        calls could leave Alt down when the second one failed)."""
        up = key_input(VK_MENU, scan, KEYEVENTF_KEYUP)
        try:
            send_input([key_input(VK_MENU, scan, 0), up])
        except OSError:
            try:
                send_input([up])
            except OSError:
                pass
            raise

    def focus(self, timeout: Optional[float] = None) -> bool:
        """Bring the game to the foreground and report whether it got there. Already in front: nothing is sent
        ('switched' False). Otherwise: an Alt tap through SendInput (lifts the foreground lock; it reaches the window
        in front, as in driver.py and game_driver.py), SW_RESTORE only when minimised, SetForegroundWindow, then poll
        GetForegroundWindow every 0.1 s for up to `timeout` (2 s); when that switched the foreground ('switched'
        True), wait FOCUS_SETTLE_S = 1.0 s before returning - the 2560 coordinate sheet notes that the game eats the
        first click after it regains focus, and driver.focus_game waited 1.0 s (review F2, 2026-09-24). A dry run
        records the step and the settle wait and returns True."""
        timeout = self.FOCUS_TIMEOUT_S if timeout is None else timeout
        self._guard("focus")
        if win.is_foreground(self.hwnd):
            self._record({"event": "focus", "already": True, "switched": False, "ok": True, "sent": False})
            return True
        if self.dry_run:
            self._dry_focused = True
            self._record({"event": "focus", "already": False, "switched": None, "ok": None, "sent": False,
                          "foreground_title": win.foreground_title()})
            self.wait(self.FOCUS_SETTLE_S, "focus settle")
            return True
        self._alt_tap(scan_code(VK_MENU))
        restored = False
        if win.is_iconic(self.hwnd):
            show_window(self.hwnd, SW_RESTORE)
            restored = True
        set_foreground(self.hwnd)
        t0 = time.monotonic()
        ok = win.is_foreground(self.hwnd)
        polls = 0
        while not ok and polls * self.FOCUS_POLL_S < timeout:
            time.sleep(self.FOCUS_POLL_S)
            polls += 1
            ok = win.is_foreground(self.hwnd)
        self._record({"event": "focus", "already": False, "switched": ok, "restored": restored, "ok": ok,
                      "sent": True, "waited_s": round(time.monotonic() - t0, 2),
                      "foreground_title": None if ok else win.foreground_title()})
        if ok:
            self.wait(self.FOCUS_SETTLE_S, "focus settle")
        return ok
