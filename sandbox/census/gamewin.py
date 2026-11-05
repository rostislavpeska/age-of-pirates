"""Monitor-independent geometry for the census screen drivers (bench_run.py, london_gen_safe.py, editor_regen.py).

The drivers were written against one calibration: the game's CLIENT area at 2560x1080 (census_run.py C sheet,
lines 41-49; editor_regen.py checks w >= 2560 and h >= 1080). Positions are stored here as normalised 0..1
pairs of that client area and converted back to pixels of the CURRENT client area on whatever monitor the
window sits on. At 2560x1080 the conversion reproduces the calibrated pixels exactly (tests pin it).
At any other client size the conversion is proportional, which is NOT measured: the game may anchor or
centre its dialogs instead of scaling them. The drivers print a warning then.

Monitor independence: game_driver.click normalises SendInput coordinates over the PRIMARY monitor
(GetSystemMetrics 0/1) and ImageGrab.grab(bbox) without all_screens captures only the primary monitor.
Pilot below uses MOUSEEVENTF_VIRTUALDESK over the whole virtual desktop and grabs with all_screens=True,
so a window on a secondary monitor (including one left of or above the primary) is driven correctly.

Pure functions (tested without a window): norm, normalise_sheet, to_screen, from_screen, to_client,
input_abs. Window functions use ctypes.windll.user32 only; the window title is game_driver.GAME_TITLE.

Pilot(dry_run=True) performs NO input event: every click, drag, key, text entry, focus and screenshot is
printed with its normalised and pixel coordinates instead.
"""
from __future__ import annotations

import ctypes
import sys
import time
from ctypes import wintypes
from typing import Dict, Optional, Tuple

GAME_TITLE = "Age of Empires III: Definitive Edition"      # game_driver.py:19, capture.py:20
CALIBRATION = (2560, 1080)                                  # client size every driver position was measured at

Rect = Tuple[int, int, int, int]                            # left, top, right, bottom (screen pixels)

MOUSEEVENTF_MOVE = 0x0001
MOUSEEVENTF_LEFTDOWN = 0x0002
MOUSEEVENTF_LEFTUP = 0x0004
MOUSEEVENTF_VIRTUALDESK = 0x4000
MOUSEEVENTF_ABSOLUTE = 0x8000
SM_XVIRTUALSCREEN, SM_YVIRTUALSCREEN, SM_CXVIRTUALSCREEN, SM_CYVIRTUALSCREEN = 76, 77, 78, 79
MONITOR_DEFAULTTONEAREST = 2


# ------------------------------------------------------------------ pure geometry
def norm(px: float, py: float, base: Tuple[int, int] = CALIBRATION) -> Tuple[float, float]:
    """Pixel position on the calibration client area -> normalised 0..1 pair."""
    return px / base[0], py / base[1]


def normalise_sheet(sheet: Dict[str, object], base: Tuple[int, int] = CALIBRATION) -> Dict[str, Tuple[float, float]]:
    """Every (x, y) pair of a coordinate sheet (census_run.C) normalised; scalars are skipped."""
    return {k: norm(v[0], v[1], base) for k, v in sheet.items() if isinstance(v, tuple) and len(v) == 2}


def to_client(nx: float, ny: float, size: Tuple[int, int]) -> Tuple[int, int]:
    """Normalised pair -> client-area pixels of a client area of `size` (w, h)."""
    return round(nx * size[0]), round(ny * size[1])


def to_screen(nx: float, ny: float, rect: Rect) -> Tuple[int, int]:
    """Normalised pair -> screen pixels inside `rect` (left, top, right, bottom)."""
    left, top, right, bottom = rect
    cx, cy = to_client(nx, ny, (right - left, bottom - top))
    return left + cx, top + cy


def from_screen(x: float, y: float, rect: Rect) -> Tuple[float, float]:
    """Screen pixels -> normalised pair of `rect`; the inverse of to_screen."""
    left, top, right, bottom = rect
    return (x - left) / (right - left), (y - top) / (bottom - top)


def input_abs(x: int, y: int, vdesk: Rect) -> Tuple[int, int]:
    """Screen pixel -> SendInput absolute coordinates with MOUSEEVENTF_VIRTUALDESK (0..65535 over the whole
    virtual desktop). Same arithmetic as game_driver.click (int(), span - 1), with the virtual origin."""
    left, top, right, bottom = vdesk
    return int((x - left) * 65535 / (right - left - 1)), int((y - top) * 65535 / (bottom - top - 1))


def describe(rect: Rect) -> str:
    left, top, right, bottom = rect
    return f"({left}, {top}, {right - left}, {bottom - top})"


# ------------------------------------------------------------------ the window (ctypes, read-only)
def _user32():
    u = ctypes.windll.user32
    u.FindWindowW.restype = wintypes.HWND
    u.FindWindowW.argtypes = [wintypes.LPCWSTR, wintypes.LPCWSTR]
    u.MonitorFromRect.restype = wintypes.HMONITOR
    u.MonitorFromRect.argtypes = [ctypes.POINTER(wintypes.RECT), wintypes.DWORD]
    u.GetForegroundWindow.restype = wintypes.HWND
    return u


class MONITORINFOEXW(ctypes.Structure):
    _fields_ = [("cbSize", wintypes.DWORD), ("rcMonitor", wintypes.RECT), ("rcWork", wintypes.RECT),
                ("dwFlags", wintypes.DWORD), ("szDevice", wintypes.WCHAR * 32)]


def find_window(title: str = GAME_TITLE):
    return _user32().FindWindowW(None, title) or None


def window_rect(hwnd=None) -> Optional[Rect]:
    """GetWindowRect of the game window (frame included), or None when there is no window."""
    hwnd = hwnd or find_window()
    if not hwnd:
        return None
    r = wintypes.RECT()
    _user32().GetWindowRect(hwnd, ctypes.byref(r))
    return r.left, r.top, r.right, r.bottom


def client_rect(hwnd=None) -> Optional[Rect]:
    """The client area in screen pixels - what every driver position is relative to."""
    hwnd = hwnd or find_window()
    if not hwnd:
        return None
    u = _user32()
    r = wintypes.RECT()
    u.GetClientRect(hwnd, ctypes.byref(r))
    pt = wintypes.POINT(0, 0)
    u.ClientToScreen(hwnd, ctypes.byref(pt))
    return pt.x, pt.y, pt.x + r.right, pt.y + r.bottom


def monitors() -> list:
    """Every monitor in EnumDisplayMonitors order: dict(index 1.., device, rect, work, primary)."""
    u = _user32()
    out = []
    proc_t = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HMONITOR, wintypes.HDC, ctypes.POINTER(wintypes.RECT),
                                wintypes.LPARAM)

    def cb(hmon, _hdc, _rc, _lp):
        out.append(_info(u, hmon, len(out) + 1))
        return True

    u.EnumDisplayMonitors(None, None, proc_t(cb), 0)
    return out


def _info(u, hmon, index: int) -> dict:
    mi = MONITORINFOEXW()
    mi.cbSize = ctypes.sizeof(MONITORINFOEXW)
    u.GetMonitorInfoW(hmon, ctypes.byref(mi))
    m, w = mi.rcMonitor, mi.rcWork
    return {"index": index, "device": mi.szDevice, "rect": (m.left, m.top, m.right, m.bottom),
            "work": (w.left, w.top, w.right, w.bottom), "primary": bool(mi.dwFlags & 1)}


def monitor_of(rect: Rect) -> dict:
    """The monitor the rect sits on (MonitorFromRect, nearest), with its index among all monitors."""
    u = _user32()
    r = wintypes.RECT(*rect)
    hmon = u.MonitorFromRect(ctypes.byref(r), MONITOR_DEFAULTTONEAREST)
    info = _info(u, hmon, 0)
    for m in monitors():
        if m["device"] == info["device"]:
            info["index"] = m["index"]
    return info


def virtual_screen() -> Rect:
    g = ctypes.windll.user32.GetSystemMetrics
    left, top = g(SM_XVIRTUALSCREEN), g(SM_YVIRTUALSCREEN)
    return left, top, left + g(SM_CXVIRTUALSCREEN), top + g(SM_CYVIRTUALSCREEN)


def is_foreground(hwnd=None) -> bool:
    hwnd = hwnd or find_window()
    return bool(hwnd) and _user32().GetForegroundWindow() == hwnd


# ------------------------------------------------------------------ the pilot
class Pilot:
    """Input for one game window in normalised coordinates. dry_run=True never sends an input event and
    never grabs the screen: it prints what it would do. `client` and `vdesk` may be injected (tests)."""

    def __init__(self, hwnd=None, dry_run: bool = False, client: Optional[Rect] = None,
                 vdesk: Optional[Rect] = None, out=None):
        self.hwnd = hwnd
        self.dry_run = dry_run
        self._client = client
        self._vdesk = vdesk
        self.out = out or sys.stdout
        self.log = []                       # every planned/performed action, for the tests

    # geometry
    def client(self) -> Rect:
        return self._client or client_rect(self.hwnd)

    def vdesk(self) -> Rect:
        return self._vdesk or virtual_screen()

    def size(self) -> Tuple[int, int]:
        c = self.client()
        return c[2] - c[0], c[3] - c[1]

    def header(self) -> str:
        c = self.client()
        lines = [f"client area {describe(c)} (calibration {CALIBRATION[0]}x{CALIBRATION[1]})"]
        try:
            m = monitor_of(c) if self._client is None else None
        except OSError:
            m = None
        if m:
            lines.append(f"window on monitor {m['index']} {m['device']} at {describe(m['rect'])}"
                         f"{' (primary)' if m['primary'] else ''}")
        if self.size() != CALIBRATION:
            lines.append(f"WARNING client {self.size()[0]}x{self.size()[1]} != calibration: positions are scaled "
                         f"proportionally, which is not measured for this game's UI")
        return "\n".join(lines)

    def _say(self, what: str) -> None:
        self.log.append(what)
        if self.dry_run:
            print("DRY " + what, file=self.out, flush=True)

    def _pt(self, nx: float, ny: float) -> Tuple[Tuple[int, int], Tuple[int, int]]:
        return to_client(nx, ny, self.size()), to_screen(nx, ny, self.client())

    def _fmt(self, label: str, nx: float, ny: float) -> str:
        cpx, spx = self._pt(nx, ny)
        return f"{label} norm=({nx:.5f}, {ny:.5f}) client={cpx} screen={spx}"

    # input
    def _mouse(self, sx: int, sy: int, flags: int) -> None:
        import game_driver as gd
        ax, ay = input_abs(sx, sy, self.vdesk())
        inp = gd._INPUT(type=gd.INPUT_MOUSE)
        inp.u.mi = gd._MI(ax, ay, 0, flags | MOUSEEVENTF_ABSOLUTE | MOUSEEVENTF_VIRTUALDESK, 0, None)
        gd._send([inp])

    def focus(self) -> None:
        self._say("focus the game window (Alt tap, restore, SetForegroundWindow)")
        if not self.dry_run:
            import game_driver as gd
            gd.focus(self.hwnd)

    def click(self, nx: float, ny: float, label: str = "click") -> None:
        self._say(self._fmt("click " + label, nx, ny))
        if self.dry_run:
            return
        _c, (sx, sy) = self._pt(nx, ny)
        self._mouse(sx, sy, MOUSEEVENTF_MOVE)
        self._mouse(sx, sy, MOUSEEVENTF_LEFTDOWN)
        self._mouse(sx, sy, MOUSEEVENTF_LEFTUP)
        time.sleep(0.35)                       # game_driver.click

    def drag(self, n1: Tuple[float, float], n2: Tuple[float, float], label: str = "drag", steps: int = 12) -> None:
        self._say(self._fmt("drag " + label + " from", *n1) + " | " + self._fmt("to", *n2))
        if self.dry_run:
            return
        _c, (x1, y1) = self._pt(*n1)
        _c, (x2, y2) = self._pt(*n2)
        self._mouse(x1, y1, MOUSEEVENTF_MOVE); time.sleep(0.15)          # game_driver.drag timings
        self._mouse(x1, y1, MOUSEEVENTF_LEFTDOWN); time.sleep(0.15)
        for k in range(1, steps + 1):
            self._mouse(round(x1 + (x2 - x1) * k / steps), round(y1 + (y2 - y1) * k / steps), MOUSEEVENTF_MOVE)
            time.sleep(0.04)
        time.sleep(0.15)
        self._mouse(x2, y2, MOUSEEVENTF_LEFTUP); time.sleep(0.3)

    def key(self, vk: int, times: int = 1, label: str = "") -> None:
        self._say(f"key 0x{vk:02X} x{times} {label}".rstrip())
        if not self.dry_run:
            import game_driver as gd
            gd.key(vk, times)

    def set_field(self, nx: float, ny: float, text, width: int = 12, label: str = "field") -> None:
        """game_driver.set_field: click the field, End, Backspace x width, type the text."""
        self.click(nx, ny, label)
        self.key(0x23, label="End")
        self.key(0x08, width, "Backspace")
        self._say(f"type {str(text)!r}")
        if not self.dry_run:
            import game_driver as gd
            gd.type_text(str(text))

    def wait(self, seconds: float, why: str = "") -> None:
        if self.dry_run:
            self._say(f"wait {seconds} s {why}".rstrip())
        else:
            time.sleep(seconds)

    def grab(self):
        """The client area as an RGB image (all monitors), or None in a dry run."""
        if self.dry_run:
            self._say("grab the client area")
            return None
        from PIL import ImageGrab
        return ImageGrab.grab(bbox=self.client(), all_screens=True).convert("RGB")

    def shot(self, path: str) -> None:
        if self.dry_run:
            self._say(f"screenshot -> {path}")
            return
        from PIL import ImageGrab
        ImageGrab.grab(bbox=self.client(), all_screens=True).save(path)


def open_pilot(dry_run: bool, out=None) -> Optional[Pilot]:
    """The game window's Pilot, its header printed; None (after printing why) when there is no window.
    Looking the window up is read-only: no input event happens here."""
    h = find_window()
    if not h:
        print("GAME WINDOW NOT FOUND - no input event made", file=out or sys.stdout)
        return None
    p = Pilot(h, dry_run=dry_run, out=out)
    print(p.header(), file=p.out)
    return p
