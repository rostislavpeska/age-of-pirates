"""Small, guarded game I/O for captures (the owner's go for screen control comes first: AGENTS.md rule 11).

    python game.py shot OUT.png        the game window's own pixels (PrintWindow): works even under a screen saver
    python game.py saver               is a screen saver running / is there a foreground window (input would be lost)
    python game.py focus               bring the game to the foreground (Alt trick); exit 3 if it did not work
    python game.py click X Y           guarded: refuses (exit 3) unless the game is the foreground window
    python game.py key esc|enter       guarded
    python game.py type TEXT           guarded
    python game.py cheat TEXT          guarded: Enter, TEXT, Enter (the aoe3-cheats skill)
    python game.py hold KEYS [SEC]     guarded: keys down in order, SEC seconds, up in reverse ('alt+w 0.4', 't')
    python game.py wheel N             guarded: N wheel notches at the cursor (+ away from you, - towards you)
    python game.py move X Y            guarded: move the cursor without clicking

Input goes through scripts/aitest/probe.py (SendInput). Never end a screen saver or switch desktops programmatically:
the permission system refused it on 2026-10-07 - ask the owner to wake the screen."""
import ctypes
import subprocess
import sys
import time
from ctypes import wintypes
from pathlib import Path

REPO = Path(__file__).resolve().parents[4]
PROBE = REPO / 'scripts' / 'aitest' / 'probe.py'
TITLE = 'Age of Empires III: Definitive Edition'
u, g = ctypes.windll.user32, ctypes.windll.gdi32


def foreground_title():
    buf = ctypes.create_unicode_buffer(512)
    u.GetWindowTextW(u.GetForegroundWindow(), buf, 512)
    return buf.value


def shot(out):
    from PIL import Image
    u.SetProcessDPIAware()
    hwnd = u.FindWindowW(None, TITLE)
    if not hwnd:
        sys.exit('no game window')
    r = wintypes.RECT()
    u.GetClientRect(hwnd, ctypes.byref(r))
    w, h = r.right - r.left, r.bottom - r.top
    hdc = u.GetDC(hwnd)
    mdc = g.CreateCompatibleDC(hdc)
    bmp = g.CreateCompatibleBitmap(hdc, w, h)
    g.SelectObject(mdc, bmp)
    ok = u.PrintWindow(hwnd, mdc, 3)                       # PW_CLIENTONLY | PW_RENDERFULLCONTENT

    class BIH(ctypes.Structure):
        _fields_ = [('biSize', wintypes.DWORD), ('biWidth', wintypes.LONG), ('biHeight', wintypes.LONG),
                    ('biPlanes', wintypes.WORD), ('biBitCount', wintypes.WORD), ('biCompression', wintypes.DWORD),
                    ('biSizeImage', wintypes.DWORD), ('biXPelsPerMeter', wintypes.LONG),
                    ('biYPelsPerMeter', wintypes.LONG), ('biClrUsed', wintypes.DWORD), ('biClrImportant', wintypes.DWORD)]

    bih = BIH(ctypes.sizeof(BIH), w, -h, 1, 32, 0, 0, 0, 0, 0, 0)
    buf = ctypes.create_string_buffer(w * h * 4)
    g.GetDIBits(mdc, bmp, 0, h, buf, ctypes.byref(bih), 0)
    Image.frombuffer('RGBA', (w, h), buf, 'raw', 'BGRA', 0, 1).convert('RGB').save(out)
    g.DeleteObject(bmp)
    g.DeleteDC(mdc)
    u.ReleaseDC(hwnd, hdc)
    print('PrintWindow ok' if ok else 'PrintWindow FAILED', (w, h), out)
    return 0 if ok else 1


def saver():
    running = wintypes.BOOL()
    u.SystemParametersInfoW(0x0072, 0, ctypes.byref(running), 0)      # SPI_GETSCREENSAVERRUNNING
    fg = u.GetForegroundWindow()
    print('screen saver running:', bool(running.value), '| foreground:', repr(foreground_title()) if fg else None)
    return 1 if running.value or not fg else 0


def focus():
    hwnd = u.FindWindowW(None, TITLE)
    if not hwnd:
        print('no game window')
        return 2
    u.keybd_event(0x12, 0, 0, 0)                                         # Alt down
    u.ShowWindow(hwnd, 9)                                                # SW_RESTORE
    u.SetForegroundWindow(hwnd)
    u.keybd_event(0x12, 0, 2, 0)                                         # Alt up
    time.sleep(1.0)
    print('foreground:', foreground_title())
    return 0 if foreground_title() == TITLE else 3


def guarded(args):
    if foreground_title() != TITLE:
        print(f'REFUSED: foreground is {foreground_title()!r}, not the game')
        return 3
    return subprocess.call([sys.executable, str(PROBE)] + args)


# --- held keys, the wheel and a plain mouse move (photo mode needs them; the game reads SCAN codes) ---------------
class _MI(ctypes.Structure):
    _fields_ = [('dx', wintypes.LONG), ('dy', wintypes.LONG), ('mouseData', wintypes.DWORD), ('dwFlags', wintypes.DWORD),
                ('time', wintypes.DWORD), ('dwExtraInfo', ctypes.POINTER(wintypes.ULONG))]


class _KI(ctypes.Structure):
    _fields_ = [('wVk', wintypes.WORD), ('wScan', wintypes.WORD), ('dwFlags', wintypes.DWORD), ('time', wintypes.DWORD),
                ('dwExtraInfo', ctypes.POINTER(wintypes.ULONG))]


class _U(ctypes.Union):
    _fields_ = [('mi', _MI), ('ki', _KI)]


class _IN(ctypes.Structure):
    _fields_ = [('type', wintypes.DWORD), ('u', _U)]


VK = {'alt': 0x12, 'ctrl': 0x11, 'shift': 0x10, 'esc': 0x1B, 'enter': 0x0D, 'space': 0x20, 'f15': 0x7E,
      'up': 0x26, 'down': 0x28, 'left': 0x25, 'right': 0x27}
EXTENDED = {'up', 'down', 'left', 'right'}


def _vk(name):
    return VK.get(name, ord(name.upper()) if len(name) == 1 else None)


def _key(name, up):
    vk = _vk(name)
    scan = u.MapVirtualKeyW(vk, 0)
    flags = 0x0008 | (0x0002 if up else 0) | (0x0001 if name in EXTENDED else 0)    # SCANCODE, KEYUP, EXTENDEDKEY
    i = _IN(type=1)
    i.u.ki = _KI(vk, scan, flags, 0, None)
    return i


def _send(items):
    arr = (_IN * len(items))(*items)
    return u.SendInput(len(items), arr, ctypes.sizeof(_IN))


def hold(combo, seconds):
    """'alt+w' 0.5: every key down in order, wait, every key up in reverse order."""
    keys = combo.lower().split('+')
    if any(_vk(k) is None for k in keys):
        print('unknown key in', combo)
        return 2
    _send([_key(k, False) for k in keys])
    time.sleep(max(0.0, seconds))
    _send([_key(k, True) for k in reversed(keys)])
    print('held', combo, seconds, 's')
    return 0


def wheel(notches):
    i = _IN(type=0)
    i.u.mi = _MI(0, 0, ctypes.c_ulong(int(notches) * 120 & 0xFFFFFFFF).value, 0x0800, 0, None)     # MOUSEEVENTF_WHEEL
    _send([i])
    print('wheel', notches)
    return 0


def move(x, y):
    sw, sh = u.GetSystemMetrics(0), u.GetSystemMetrics(1)
    i = _IN(type=0)
    i.u.mi = _MI(int(int(x) * 65535 / sw), int(int(y) * 65535 / sh), 0, 0x0001 | 0x8000, 0, None)   # MOVE | ABSOLUTE
    _send([i])
    print('moved to', x, y)
    return 0


def guarded_local(fn, *a):
    if foreground_title() != TITLE:
        print(f'REFUSED: foreground is {foreground_title()!r}, not the game')
        return 3
    return fn(*a)


if __name__ == '__main__':
    cmd, rest = sys.argv[1], sys.argv[2:]
    if cmd == 'shot':
        sys.exit(shot(rest[0]))
    if cmd == 'saver':
        sys.exit(saver())
    if cmd == 'focus':
        sys.exit(focus())
    if cmd in ('click', 'key', 'type', 'cheat'):
        sys.exit(guarded([cmd] + rest))
    if cmd == 'hold':
        sys.exit(guarded_local(hold, rest[0], float(rest[1]) if len(rest) > 1 else 0.05))
    if cmd == 'wheel':
        sys.exit(guarded_local(wheel, int(rest[0])))
    if cmd == 'move':
        sys.exit(guarded_local(move, rest[0], rest[1]))
    sys.exit(__doc__)
