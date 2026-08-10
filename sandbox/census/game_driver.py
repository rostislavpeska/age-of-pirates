"""Game window driver: focus, screenshot, synthetic mouse/keyboard.

Pure ctypes + PIL — no extra dependencies. Coordinates are always the
GAME WINDOW's client area, so clicks stay valid wherever the window sits.
Usage pattern from the harness: one small action per call, screenshot
after, decide next step from the pixels.
"""
from __future__ import annotations

import ctypes
import time
from ctypes import wintypes

from PIL import ImageGrab

user32 = ctypes.windll.user32
user32.SetProcessDPIAware()

GAME_TITLE = "Age of Empires III: Definitive Edition"

INPUT_MOUSE = 0
INPUT_KEYBOARD = 1
MOUSEEVENTF_MOVE = 0x0001
MOUSEEVENTF_ABSOLUTE = 0x8000
MOUSEEVENTF_LEFTDOWN = 0x0002
MOUSEEVENTF_LEFTUP = 0x0004
KEYEVENTF_KEYUP = 0x0002
KEYEVENTF_UNICODE = 0x0004


class _KI(ctypes.Structure):
    _fields_ = [("wVk", wintypes.WORD), ("wScan", wintypes.WORD),
                ("dwFlags", wintypes.DWORD), ("time", wintypes.DWORD),
                ("dwExtraInfo", ctypes.POINTER(wintypes.ULONG))]


class _MI(ctypes.Structure):
    _fields_ = [("dx", wintypes.LONG), ("dy", wintypes.LONG),
                ("mouseData", wintypes.DWORD), ("dwFlags", wintypes.DWORD),
                ("time", wintypes.DWORD),
                ("dwExtraInfo", ctypes.POINTER(wintypes.ULONG))]


class _IU(ctypes.Union):
    _fields_ = [("ki", _KI), ("mi", _MI)]


class _INPUT(ctypes.Structure):
    _fields_ = [("type", wintypes.DWORD), ("u", _IU)]


def _send(inputs):
    arr = (_INPUT * len(inputs))(*inputs)
    user32.SendInput(len(inputs), arr, ctypes.sizeof(_INPUT))


def find_game():
    hwnd = user32.FindWindowW(None, GAME_TITLE)
    return hwnd or None


def client_rect(hwnd):
    r = wintypes.RECT()
    user32.GetClientRect(hwnd, ctypes.byref(r))
    pt = wintypes.POINT(0, 0)
    user32.ClientToScreen(hwnd, ctypes.byref(pt))
    return pt.x, pt.y, r.right, r.bottom      # screen x, y, width, height


def focus(hwnd):
    # Alt tap defeats the foreground lock, then restore + raise
    for flag in (0, KEYEVENTF_KEYUP):
        inp = _INPUT(type=INPUT_KEYBOARD)
        inp.u.ki = _KI(0x12, 0, flag, 0, None)
        _send([inp])
    user32.ShowWindow(hwnd, 9)                # SW_RESTORE
    user32.SetForegroundWindow(hwnd)
    time.sleep(0.6)


def shot(hwnd, path):
    x, y, w, h = client_rect(hwnd)
    img = ImageGrab.grab(bbox=(x, y, x + w, y + h))
    img.save(path)
    return w, h


def click(hwnd, cx, cy, double=False):
    """Click at client-area coordinates (cx, cy)."""
    x, y, _w, _h = client_rect(hwnd)
    sx, sy = x + cx, y + cy
    vx = int(sx * 65535 / (user32.GetSystemMetrics(0) - 1))
    vy = int(sy * 65535 / (user32.GetSystemMetrics(1) - 1))
    mv = _INPUT(type=INPUT_MOUSE)
    mv.u.mi = _MI(vx, vy, 0, MOUSEEVENTF_MOVE | MOUSEEVENTF_ABSOLUTE, 0, None)
    dn = _INPUT(type=INPUT_MOUSE)
    dn.u.mi = _MI(vx, vy, 0, MOUSEEVENTF_LEFTDOWN | MOUSEEVENTF_ABSOLUTE, 0, None)
    up = _INPUT(type=INPUT_MOUSE)
    up.u.mi = _MI(vx, vy, 0, MOUSEEVENTF_LEFTUP | MOUSEEVENTF_ABSOLUTE, 0, None)
    seq = [mv, dn, up] + ([dn, up] if double else [])
    _send(seq)
    time.sleep(0.35)


def drag(hwnd, x1, y1, x2, y2, steps=12):
    """Drag from client (x1,y1) to (x2,y2)."""
    x, y, _w, _h = client_rect(hwnd)
    sw = user32.GetSystemMetrics(0) - 1
    sh = user32.GetSystemMetrics(1) - 1

    def _mi(px, py, flags):
        inp = _INPUT(type=INPUT_MOUSE)
        inp.u.mi = _MI(int((x + px) * 65535 / sw), int((y + py) * 65535 / sh),
                       0, flags | MOUSEEVENTF_ABSOLUTE, 0, None)
        return inp

    _send([_mi(x1, y1, MOUSEEVENTF_MOVE)])
    time.sleep(0.15)
    _send([_mi(x1, y1, MOUSEEVENTF_LEFTDOWN)])
    time.sleep(0.15)
    for k in range(1, steps + 1):
        px = x1 + (x2 - x1) * k / steps
        py = y1 + (y2 - y1) * k / steps
        _send([_mi(px, py, MOUSEEVENTF_MOVE)])
        time.sleep(0.04)
    time.sleep(0.15)
    _send([_mi(x2, y2, MOUSEEVENTF_LEFTUP)])
    time.sleep(0.3)


def type_text(text):
    inputs = []
    for ch in text:
        for flag in (KEYEVENTF_UNICODE, KEYEVENTF_UNICODE | KEYEVENTF_KEYUP):
            inp = _INPUT(type=INPUT_KEYBOARD)
            inp.u.ki = _KI(0, ord(ch), flag, 0, None)
            inputs.append(inp)
    _send(inputs)
    time.sleep(0.25)


def key(vk, times=1):
    """Press a virtual key (0x0D Enter, 0x1B Esc, 0x2E Del, 0x08 Backspace)."""
    for _ in range(times):
        for flag in (0, KEYEVENTF_KEYUP):
            inp = _INPUT(type=INPUT_KEYBOARD)
            inp.u.ki = _KI(vk, 0, flag, 0, None)
            _send([inp])
        time.sleep(0.08)


if __name__ == "__main__":
    import sys
    hwnd = find_game()
    if not hwnd:
        print("GAME NOT FOUND")
        sys.exit(1)
    focus(hwnd)
    w, h = shot(hwnd, sys.argv[1] if len(sys.argv) > 1 else "game_shot.png")
    print(f"game window client {w}x{h}, screenshot saved")
