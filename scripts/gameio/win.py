"""Read-only window facts for the game (ctypes user32/gdi32, loaded lazily - importing this module calls nothing).

Copied from sandbox/census/gamewin.py (find_window with an HWND return type, client_rect via GetClientRect +
ClientToScreen, virtual_screen, is_foreground) and scripts/aitest/driver.py (game_running via tasklist,
abort_requested's GetCursorPos). Differences: every rectangle here is (x, y, w, h) in screen pixels, and nothing
here sends input or changes a window - inputs.py owns SendInput, SetForegroundWindow and ShowWindow.

Every function raises OSError off Windows, except dpi_aware() (a no-op returning False there).
"""
from __future__ import annotations

import ctypes
import subprocess
import sys
from typing import Optional, Tuple

GAME_TITLE = "Age of Empires III: Definitive Edition"      # game_driver.py:19, gamewin.py:29, capture.py:20
GAME_EXE = "AoE3DE_s.exe"                                   # driver.py EXE
Rect = Tuple[int, int, int, int]                            # x, y, w, h

SM_CXSCREEN, SM_CYSCREEN = 0, 1
SM_XVIRTUALSCREEN, SM_YVIRTUALSCREEN, SM_CXVIRTUALSCREEN, SM_CYVIRTUALSCREEN = 76, 77, 78, 79

_DPI_DONE = None


class RECT(ctypes.Structure):
    _fields_ = [("left", ctypes.c_long), ("top", ctypes.c_long), ("right", ctypes.c_long), ("bottom", ctypes.c_long)]


class POINT(ctypes.Structure):
    _fields_ = [("x", ctypes.c_long), ("y", ctypes.c_long)]


def is_windows() -> bool:
    return sys.platform == "win32"


def _require_windows() -> None:
    if not is_windows():
        raise OSError("gameio.win needs Windows (the game runs there)")


_U32 = None


def user32():
    """A PRIVATE user32 instance (ctypes.WinDLL, cached) with the handle-returning functions typed as pointers
    (a bare int restype truncates 64-bit HWNDs). Private so these argtypes never leak into ctypes.windll.user32,
    which driver.py, game_driver.py and capture.py call with their own structures in the same process."""
    global _U32
    _require_windows()
    if _U32 is not None:
        return _U32
    u = ctypes.WinDLL("user32", use_last_error=True)
    vp = ctypes.c_void_p
    u.FindWindowW.restype = vp
    u.FindWindowW.argtypes = [ctypes.c_wchar_p, ctypes.c_wchar_p]
    u.GetForegroundWindow.restype = vp
    u.GetForegroundWindow.argtypes = []
    u.GetWindowRect.argtypes = [vp, ctypes.POINTER(RECT)]
    u.GetClientRect.argtypes = [vp, ctypes.POINTER(RECT)]
    u.ClientToScreen.argtypes = [vp, ctypes.POINTER(POINT)]
    u.GetWindowTextW.argtypes = [vp, ctypes.c_wchar_p, ctypes.c_int]
    u.GetWindowTextLengthW.argtypes = [vp]
    u.IsIconic.argtypes = [vp]
    u.IsWindow.argtypes = [vp]
    u.GetCursorPos.argtypes = [ctypes.POINTER(POINT)]
    u.GetSystemMetrics.argtypes = [ctypes.c_int]
    u.MapVirtualKeyW.argtypes = [ctypes.c_uint, ctypes.c_uint]
    u.MapVirtualKeyW.restype = ctypes.c_uint
    u.WindowFromPoint.argtypes = [POINT]
    u.WindowFromPoint.restype = vp
    u.GetAncestor.argtypes = [vp, ctypes.c_uint]
    u.GetAncestor.restype = vp
    u.GetWindowThreadProcessId.argtypes = [vp, ctypes.POINTER(ctypes.c_ulong)]
    u.GetWindowThreadProcessId.restype = ctypes.c_ulong
    _U32 = u
    return u


_K32 = None


def kernel32():
    """A PRIVATE kernel32 instance (cached), typed for the process-name lookup only."""
    global _K32
    _require_windows()
    if _K32 is not None:
        return _K32
    k = ctypes.WinDLL("kernel32", use_last_error=True)
    vp = ctypes.c_void_p
    k.OpenProcess.argtypes = [ctypes.c_ulong, ctypes.c_int, ctypes.c_ulong]
    k.OpenProcess.restype = vp
    k.QueryFullProcessImageNameW.argtypes = [vp, ctypes.c_ulong, ctypes.c_wchar_p, ctypes.POINTER(ctypes.c_ulong)]
    k.QueryFullProcessImageNameW.restype = ctypes.c_int
    k.CloseHandle.argtypes = [vp]
    _K32 = k
    return k


def dpi_aware() -> bool:
    """SetProcessDPIAware once per process, as driver.py / probe.py / game_driver.py did at import - here only when
    called (Session() and the CLI call it). Pixel positions everywhere are physical pixels; on this device the
    display runs at 100 % (AppliedDPI 0x60, survey 2026-09-24), where it changes nothing. False off Windows."""
    global _DPI_DONE
    if not is_windows():
        return False
    if _DPI_DONE is None:
        _DPI_DONE = bool(user32().SetProcessDPIAware())
    return _DPI_DONE


def find_window(title: str = GAME_TITLE) -> Optional[int]:
    """The top-level window with exactly this title, or None."""
    h = user32().FindWindowW(None, title)
    return int(h) if h else None


def window_rect(hwnd) -> Optional[Rect]:
    """GetWindowRect (frame included) as (x, y, w, h), or None for no window."""
    if not hwnd:
        return None
    r = RECT()
    if not user32().GetWindowRect(hwnd, ctypes.byref(r)):
        return None
    return r.left, r.top, r.right - r.left, r.bottom - r.top


def client_rect(hwnd) -> Optional[Rect]:
    """The client area in screen pixels as (x, y, w, h) - what every sheet point with space 'client' is relative
    to. On this device the game runs borderless full screen on the primary monitor, so it is (0, 0, 2560, 1080)."""
    if not hwnd:
        return None
    u = user32()
    r = RECT()
    if not u.GetClientRect(hwnd, ctypes.byref(r)):
        return None
    pt = POINT(0, 0)
    u.ClientToScreen(hwnd, ctypes.byref(pt))
    return pt.x, pt.y, r.right - r.left, r.bottom - r.top


def foreground_window() -> Optional[int]:
    h = user32().GetForegroundWindow()
    return int(h) if h else None


def is_foreground(hwnd) -> bool:
    return bool(hwnd) and foreground_window() == int(hwnd)


def window_title(hwnd) -> str:
    if not hwnd:
        return ""
    u = user32()
    n = u.GetWindowTextLengthW(hwnd)
    buf = ctypes.create_unicode_buffer(n + 1)
    u.GetWindowTextW(hwnd, buf, n + 1)
    return buf.value


def foreground_title() -> str:
    """The title of the window that has the keyboard focus now ('' for none) - the thing a click would hit."""
    return window_title(foreground_window())


def is_iconic(hwnd) -> bool:
    return bool(hwnd) and bool(user32().IsIconic(hwnd))


def cursor_pos() -> Tuple[int, int]:
    p = POINT()
    user32().GetCursorPos(ctypes.byref(p))
    return p.x, p.y


GA_ROOT = 2
PROCESS_QUERY_LIMITED_INFORMATION = 0x1000


def root_window_at(x: int, y: int) -> Optional[int]:
    """The top-level window that a press at screen pixel (x, y) would reach: GetAncestor(WindowFromPoint, GA_ROOT),
    or None. Added 2026-09-24 (gameio review F4): a topmost window over the game's client area - a Windows toast
    appears bottom-right, exactly over the minimap on 2560x1080 - takes the click while the game is still the
    foreground window, so the foreground check alone does not cover it. Measured 2026-09-24 read-only (no input) with
    the game on the primary at 2560x1080: at (1280,540), (2269,920) the editor disc, (2399,899) the match disc and
    (444,435) Skirmish this returns exactly find_window()'s hwnd, and window_exe() of it is 'AoE3DE_s.exe'."""
    u = user32()
    h = u.WindowFromPoint(POINT(int(x), int(y)))
    if not h:
        return None
    root = u.GetAncestor(h, GA_ROOT)
    return int(root) if root else int(h)


def window_pid(hwnd) -> Optional[int]:
    """GetWindowThreadProcessId: the id of the process that owns hwnd, or None."""
    if not hwnd:
        return None
    pid = ctypes.c_ulong(0)
    user32().GetWindowThreadProcessId(hwnd, ctypes.byref(pid))
    return int(pid.value) or None


def process_exe(pid: Optional[int]) -> Optional[str]:
    """The executable file name (no folder) of process pid, or None when it cannot be read
    (OpenProcess with PROCESS_QUERY_LIMITED_INFORMATION + QueryFullProcessImageNameW; read-only)."""
    if not pid:
        return None
    k = kernel32()
    h = k.OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, 0, int(pid))
    if not h:
        return None
    try:
        size = ctypes.c_ulong(1024)
        buf = ctypes.create_unicode_buffer(size.value)
        if not k.QueryFullProcessImageNameW(h, 0, buf, ctypes.byref(size)):
            return None
        return buf.value.replace("/", "\\").rsplit("\\", 1)[-1]
    finally:
        k.CloseHandle(h)


def window_exe(hwnd) -> Optional[str]:
    """The executable name of the process that owns hwnd (e.g. 'AoE3DE_s.exe'), or None."""
    return process_exe(window_pid(hwnd))


def virtual_screen() -> Rect:
    """The whole virtual desktop (all monitors) as (x, y, w, h); x or y is negative with a monitor left of or above
    the primary."""
    g = user32().GetSystemMetrics
    return g(SM_XVIRTUALSCREEN), g(SM_YVIRTUALSCREEN), g(SM_CXVIRTUALSCREEN), g(SM_CYVIRTUALSCREEN)


def screen_size() -> Tuple[int, int]:
    """The primary monitor's size in pixels (driver.py / probe.py SW, SH)."""
    g = user32().GetSystemMetrics
    return g(SM_CXSCREEN), g(SM_CYSCREEN)


def map_vk_to_scan(vk: int) -> int:
    """MapVirtualKeyW(vk, MAPVK_VK_TO_VSC) - driver.key_vk's scan code source."""
    return int(user32().MapVirtualKeyW(vk, 0))


def process_running(exe: str = GAME_EXE) -> bool:
    """driver.game_running: tasklist filtered by image name (starts tasklist, never touches the game)."""
    _require_windows()
    try:
        out = subprocess.run(["tasklist", "/FI", "IMAGENAME eq " + exe], capture_output=True, text=True,
                             timeout=30, creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0)).stdout
    except (OSError, subprocess.SubprocessError):
        return False
    return exe.lower() in out.lower()
