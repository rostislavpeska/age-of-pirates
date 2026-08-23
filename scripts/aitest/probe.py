"""Agent-side eyes and hands: screenshot, click, pixel - one action per call.

    python probe.py shot <out.png>     full-screen capture (physical pixels)
    python probe.py click <x> <y>      absolute click (focuses whatever is there)
    python probe.py pixel <x> <y>      print rgb under that point
    python probe.py key esc            tap Escape
    python probe.py res                print screen resolution
"""
import ctypes
import sys
import time

user32 = ctypes.windll.user32
gdi32 = ctypes.windll.gdi32
user32.SetProcessDPIAware()
SW = user32.GetSystemMetrics(0)
SH = user32.GetSystemMetrics(1)


class MOUSEINPUT(ctypes.Structure):
    _fields_ = [("dx", ctypes.c_long), ("dy", ctypes.c_long),
                ("mouseData", ctypes.c_ulong), ("dwFlags", ctypes.c_ulong),
                ("time", ctypes.c_ulong),
                ("dwExtraInfo", ctypes.POINTER(ctypes.c_ulong))]


class KEYBDINPUT(ctypes.Structure):
    _fields_ = [("wVk", ctypes.c_ushort), ("wScan", ctypes.c_ushort),
                ("dwFlags", ctypes.c_ulong), ("time", ctypes.c_ulong),
                ("dwExtraInfo", ctypes.POINTER(ctypes.c_ulong))]


class _IU(ctypes.Union):
    _fields_ = [("mi", MOUSEINPUT), ("ki", KEYBDINPUT)]


class INPUT(ctypes.Structure):
    _fields_ = [("type", ctypes.c_ulong), ("u", _IU)]


def send(inputs):
    arr = (INPUT * len(inputs))(*inputs)
    user32.SendInput(len(inputs), arr, ctypes.sizeof(INPUT))


def click(x, y):
    mv = INPUT(type=0)
    mv.u.mi = MOUSEINPUT(int(x * 65535 / SW), int(y * 65535 / SH), 0,
                         0x0001 | 0x8000, 0, None)
    send([mv])
    time.sleep(0.2)
    dn = INPUT(type=0); dn.u.mi = MOUSEINPUT(0, 0, 0, 0x0002, 0, None)
    up = INPUT(type=0); up.u.mi = MOUSEINPUT(0, 0, 0, 0x0004, 0, None)
    send([dn]); time.sleep(0.09); send([up])


def key_esc():
    d = INPUT(type=1); d.u.ki = KEYBDINPUT(0x1B, 0, 0, 0, None)
    u = INPUT(type=1); u.u.ki = KEYBDINPUT(0x1B, 0, 0x0002, 0, None)
    send([d]); time.sleep(0.06); send([u])


def shot(path):
    import subprocess
    ps = ("Add-Type -AssemblyName System.Drawing; "
          "$b = New-Object System.Drawing.Bitmap(%d, %d); "
          "$g = [System.Drawing.Graphics]::FromImage($b); "
          "$g.CopyFromScreen(0, 0, 0, 0, $b.Size); "
          "$b.Save('%s', [System.Drawing.Imaging.ImageFormat]::Png)"
          % (SW, SH, path.replace("'", "''")))
    subprocess.run(["powershell", "-NoProfile", "-Command", ps], timeout=60)


def pixel(x, y):
    dc = user32.GetDC(0)
    raw = gdi32.GetPixel(dc, x, y)
    user32.ReleaseDC(0, dc)
    if raw == 0xFFFFFFFF:
        return None
    return (raw & 0xFF, (raw >> 8) & 0xFF, (raw >> 16) & 0xFF)


if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "shot":
        shot(sys.argv[2]); print("saved %s (%dx%d)" % (sys.argv[2], SW, SH))
    elif cmd == "click":
        click(int(sys.argv[2]), int(sys.argv[3])); print("clicked")
    elif cmd == "pixel":
        print(pixel(int(sys.argv[2]), int(sys.argv[3])))
    elif cmd == "key" and sys.argv[2] == "esc":
        key_esc(); print("esc")
    elif cmd == "res":
        print("%dx%d" % (SW, SH))
