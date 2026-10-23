"""Robust game capture: ImageGrab first, PrintWindow(PW_RENDERFULLCONTENT)
fallback for swapchains GDI screen-grab returns black for.

    python sandbox/census/capture.py out.png
"""
from __future__ import annotations

import ctypes
import sys
import time
from ctypes import wintypes
from pathlib import Path

from PIL import Image, ImageGrab, ImageStat

user32 = ctypes.windll.user32
gdi32 = ctypes.windll.gdi32
user32.SetProcessDPIAware()

TITLE = "Age of Empires III: Definitive Edition"
PW_RENDERFULLCONTENT = 0x00000002


def _brightness(img):
    return sum(ImageStat.Stat(img.convert("RGB")).mean) / 3.0


def grab_screen(hwnd):
    r = wintypes.RECT()
    user32.GetWindowRect(hwnd, ctypes.byref(r))
    return ImageGrab.grab(bbox=(r.left, r.top, r.right, r.bottom))


def grab_printwindow(hwnd):
    r = wintypes.RECT()
    user32.GetWindowRect(hwnd, ctypes.byref(r))
    w, h = r.right - r.left, r.bottom - r.top
    hdc = user32.GetWindowDC(hwnd)
    mdc = gdi32.CreateCompatibleDC(hdc)
    bmp = gdi32.CreateCompatibleBitmap(hdc, w, h)
    gdi32.SelectObject(mdc, bmp)
    ok = user32.PrintWindow(hwnd, mdc, PW_RENDERFULLCONTENT)

    class BMPINFOHDR(ctypes.Structure):
        _fields_ = [("biSize", wintypes.DWORD), ("biWidth", wintypes.LONG),
                    ("biHeight", wintypes.LONG), ("biPlanes", wintypes.WORD),
                    ("biBitCount", wintypes.WORD), ("biCompression", wintypes.DWORD),
                    ("biSizeImage", wintypes.DWORD),
                    ("biXPelsPerMeter", wintypes.LONG),
                    ("biYPelsPerMeter", wintypes.LONG),
                    ("biClrUsed", wintypes.DWORD), ("biClrImportant", wintypes.DWORD)]

    hdr = BMPINFOHDR(ctypes.sizeof(BMPINFOHDR), w, -h, 1, 32, 0, 0, 0, 0, 0, 0)
    buf = ctypes.create_string_buffer(w * h * 4)
    gdi32.GetDIBits(mdc, bmp, 0, h, buf, ctypes.byref(hdr), 0)
    img = Image.frombuffer("RGBA", (w, h), buf, "raw", "BGRA", 0, 1)
    gdi32.DeleteObject(bmp)
    gdi32.DeleteDC(mdc)
    user32.ReleaseDC(hwnd, hdc)
    return img.convert("RGB"), bool(ok)


def capture(path):
    hwnd = user32.FindWindowW(None, TITLE)
    if not hwnd:
        raise SystemExit("game window not found")
    # foreground so the swapchain is presenting
    for flag in (0, 0x0002):
        cls = ctypes.Structure
        _ = cls
    user32.ShowWindow(hwnd, 9)
    user32.SetForegroundWindow(hwnd)
    time.sleep(1.0)

    img = grab_screen(hwnd)
    b = _brightness(img)
    how = "ImageGrab"
    if b < 1.0:
        img2, ok = grab_printwindow(hwnd)
        b2 = _brightness(img2)
        print("ImageGrab black (%.2f); PrintWindow ok=%s brightness=%.2f" % (b, ok, b2))
        if b2 > b:
            img, b, how = img2, b2, "PrintWindow"
    img.save(path)
    print("saved %s via %s  size=%s  mean brightness=%.2f" % (path, how, img.size, b))
    return b


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "capture.png"
    Path(out).parent.mkdir(parents=True, exist_ok=True)
    capture(out)
