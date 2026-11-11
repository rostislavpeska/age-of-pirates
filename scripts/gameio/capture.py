"""Screenshots, pixels and screen recording of the game (PIL imported lazily; no Win32 call at import).

    grab(bbox)          PIL.ImageGrab over all monitors (bbox in screen pixels, left/top/right/bottom). Captures
                        WHATEVER IS ON TOP: recorded shots of 2026-09-22 show VS Code and the Start menu where the
                        game was expected (survey).
    window_image(hwnd)  PrintWindow(PW_RENDERFULLCONTENT) of the game window cropped to its client area - renders
                        the game even when another window covers it (sandbox/census/capture.py grab_printwindow and
                        scripts/havok/pw.py; pw.shot_ok's note: intermittently black while the game redraws, so a
                        black frame is retried).
    shot(path)          deletes `path` first, captures, verifies a fresh non-empty file, and writes the sidecar
                        <path>.json {time, mode, area, bbox, size, foreground_title, game_foreground (= in front
                        both right before and right after the grab), game_foreground_before/_after, client_rect,
                        mean_brightness}; RuntimeError when anything fails, a failed grab included. The fixes for
                        probe.py shot, which ignored PowerShell's exit status and let camera.py analyse a stale
                        file (mapview review F5).
    pixel(x, y)         GetPixel on the screen DC (driver.pixel_at / probe.pixel).
    Recorder            ffmpeg ddagrab with a gdigrab fallback (driver.start_recording / stop_recording), and a
                        verified result (review F6: a failed start used to report a video that did not exist).
"""
from __future__ import annotations

import ctypes
import json
import os
import shutil
import subprocess
import time
from datetime import datetime
from pathlib import Path
from typing import Optional, Tuple

from . import geom, win

PW_RENDERFULLCONTENT = 0x00000002
CLR_INVALID = 0xFFFFFFFF
FRESH_SLACK_S = 2.0                         # file-system mtime granularity allowance for the freshness check


# ------------------------------------------------------------------ grabs
def grab(bbox: Optional[Tuple[int, int, int, int]] = None, all_screens: bool = True):
    """The screen (bbox = left, top, right, bottom in screen pixels; None = everything) as an RGB image."""
    from PIL import ImageGrab
    return ImageGrab.grab(bbox=bbox, all_screens=all_screens).convert("RGB")


def _gdi32():
    g = ctypes.WinDLL("gdi32", use_last_error=True)
    vp = ctypes.c_void_p
    g.CreateCompatibleDC.restype = vp
    g.CreateCompatibleDC.argtypes = [vp]
    g.CreateCompatibleBitmap.restype = vp
    g.CreateCompatibleBitmap.argtypes = [vp, ctypes.c_int, ctypes.c_int]
    g.SelectObject.restype = vp
    g.SelectObject.argtypes = [vp, vp]
    g.DeleteObject.argtypes = [vp]
    g.DeleteDC.argtypes = [vp]
    g.GetDIBits.argtypes = [vp, vp, ctypes.c_uint, ctypes.c_uint, ctypes.c_void_p, ctypes.c_void_p, ctypes.c_uint]
    g.GetPixel.argtypes = [vp, ctypes.c_int, ctypes.c_int]
    g.GetPixel.restype = ctypes.c_uint32
    return g


class _BITMAPINFOHEADER(ctypes.Structure):
    _fields_ = [("biSize", ctypes.c_uint32), ("biWidth", ctypes.c_int32), ("biHeight", ctypes.c_int32),
                ("biPlanes", ctypes.c_uint16), ("biBitCount", ctypes.c_uint16), ("biCompression", ctypes.c_uint32),
                ("biSizeImage", ctypes.c_uint32), ("biXPelsPerMeter", ctypes.c_int32),
                ("biYPelsPerMeter", ctypes.c_int32), ("biClrUsed", ctypes.c_uint32),
                ("biClrImportant", ctypes.c_uint32)]


def _printwindow(hwnd):
    """The whole window (frame included) rendered by PrintWindow, as an RGB image; raises RuntimeError when
    PrintWindow reports failure."""
    from PIL import Image
    u = win.user32()
    g = _gdi32()
    vp = ctypes.c_void_p
    u.GetWindowDC.restype = vp
    u.GetWindowDC.argtypes = [vp]
    u.ReleaseDC.argtypes = [vp, vp]
    u.PrintWindow.argtypes = [vp, vp, ctypes.c_uint]
    wr = win.window_rect(hwnd)
    if wr is None:
        raise RuntimeError("no game window - nothing captured")
    w, h = wr[2], wr[3]
    hdc = u.GetWindowDC(hwnd)
    mdc = g.CreateCompatibleDC(hdc)
    bmp = g.CreateCompatibleBitmap(hdc, w, h)
    old = g.SelectObject(mdc, bmp)
    try:
        ok = u.PrintWindow(hwnd, mdc, PW_RENDERFULLCONTENT)
        hdr = _BITMAPINFOHEADER(ctypes.sizeof(_BITMAPINFOHEADER), w, -h, 1, 32, 0, 0, 0, 0, 0, 0)
        buf = ctypes.create_string_buffer(w * h * 4)
        g.GetDIBits(mdc, bmp, 0, h, buf, ctypes.byref(hdr), 0)
    finally:
        g.SelectObject(mdc, old)
        g.DeleteObject(bmp)
        g.DeleteDC(mdc)
        u.ReleaseDC(hwnd, hdc)
    if not ok:
        raise RuntimeError("PrintWindow failed - nothing captured")
    return Image.frombuffer("RGBA", (w, h), buf.raw, "raw", "BGRA", 0, 1).convert("RGB")


def mean_brightness(img) -> float:
    from PIL import ImageStat
    return round(sum(ImageStat.Stat(img.convert("RGB")).mean) / 3.0, 2)


def window_image(hwnd=None, tries: int = 3, retry_wait_s: float = 1.0):
    """The game's CLIENT area rendered by PrintWindow (works when the game is covered). The full window is rendered
    and cropped at the client offset, so a framed window gives client pixels too. An all-black frame (mean < 1) is
    retried `tries` times; the last frame is returned either way (the loading screen really is black)."""
    hwnd = hwnd or win.find_window()
    if not hwnd:
        raise RuntimeError("no game window - nothing captured")
    img = None
    for attempt in range(max(1, tries)):
        full = _printwindow(hwnd)
        wr, cr = win.window_rect(hwnd), win.client_rect(hwnd)
        ox, oy = cr[0] - wr[0], cr[1] - wr[1]
        img = full.crop((ox, oy, ox + cr[2], oy + cr[3]))
        if mean_brightness(img) >= 1.0:
            break
        if attempt + 1 < tries:
            time.sleep(retry_wait_s)
    return img


def pixel(x: int, y: int) -> Optional[Tuple[int, int, int]]:
    """The screen pixel at (x, y) as (r, g, b); None when GetPixel fails (outside every monitor)."""
    u = win.user32()
    g = _gdi32()
    u.GetDC.restype = ctypes.c_void_p
    u.GetDC.argtypes = [ctypes.c_void_p]
    u.ReleaseDC.argtypes = [ctypes.c_void_p, ctypes.c_void_p]
    dc = u.GetDC(None)
    try:
        raw = g.GetPixel(dc, int(x), int(y))
    finally:
        u.ReleaseDC(None, dc)
    if raw == CLR_INVALID:
        return None
    return raw & 0xFF, (raw >> 8) & 0xFF, (raw >> 16) & 0xFF


# ------------------------------------------------------------------ shot
def shot(path, hwnd=None, mode: str = "screen", area: Optional[str] = None) -> Path:
    """Capture to `path` (PNG) and write <path>.json beside it; returns the Path.

    mode 'screen' grabs the screen (whatever is on top); 'window' renders the game by PrintWindow.
    area (mode 'screen' only): 'client' = the game's client rectangle (pixels = sheet 'client' pixels),
    'primary' = the primary monitor (probe.py shot), 'all' = every monitor; default 'client' when the game window
    exists, else 'primary'. Raises RuntimeError when no fresh non-empty file appears."""
    path = Path(path)
    side = path.with_name(path.name + ".json")
    path.parent.mkdir(parents=True, exist_ok=True)
    for p in (path, side):
        try:
            p.unlink()
        except FileNotFoundError:
            pass
    if path.exists():
        raise RuntimeError(f"could not delete the old {path} - nothing captured")
    hwnd = hwnd or win.find_window()
    cr = win.client_rect(hwnd) if hwnd else None
    t0 = time.time()
    if mode == "window":
        if not hwnd:
            raise RuntimeError("mode 'window' needs the game window - none found, nothing captured")
        area, bbox = "client", geom.rect_ltrb(cr) if cr else None
    elif mode == "screen":
        area = area or ("client" if cr else "primary")
        if area == "client":
            if not cr:
                raise RuntimeError("area 'client' needs the game window - none found, nothing captured")
            bbox = geom.rect_ltrb(cr)
        elif area == "primary":
            sw, sh = win.screen_size()
            bbox = (0, 0, sw, sh)
        elif area == "all":
            bbox = geom.rect_ltrb(win.virtual_screen())
        else:
            raise ValueError(f"area must be 'client', 'primary' or 'all', not {area!r}")
    else:
        raise ValueError(f"mode must be 'screen' or 'window', not {mode!r}")
    # who is in front is read right before and right after the grab, not after the PNG is encoded (review F6,
    # 2026-09-24: sampled 0.3-1 s later, the sidecar could disagree with the image)
    fg_before = bool(hwnd) and win.is_foreground(hwnd)
    try:
        img = window_image(hwnd) if mode == "window" else grab(bbox)
    except OSError as e:                        # ImageGrab on a locked / secure desktop: 'screen grab failed'
        raise RuntimeError(f"the capture failed ({e}) - nothing captured") from e
    fg_after = bool(hwnd) and win.is_foreground(hwnd)
    fg_title = win.foreground_title()
    img.save(str(path))
    try:
        st = path.stat()
    except FileNotFoundError:
        raise RuntimeError(f"the screenshot {path} did not appear") from None
    if st.st_size <= 0:
        raise RuntimeError(f"the screenshot {path} is empty")
    if st.st_mtime < t0 - FRESH_SLACK_S:
        raise RuntimeError(f"the screenshot {path} is not fresh (mtime {st.st_mtime:.1f} < start {t0:.1f})")
    meta = {
        "time": datetime.fromtimestamp(t0).isoformat(timespec="seconds"),
        "epoch": round(t0, 3),
        "mode": mode,
        "area": area,
        "bbox": list(bbox) if bbox else None,
        "size": list(img.size),
        "foreground_title": fg_title,
        "game_foreground": bool(fg_before and fg_after),
        "game_foreground_before": bool(fg_before),
        "game_foreground_after": bool(fg_after),
        "client_rect": list(cr) if cr else None,
        "hwnd": hwnd,
    }
    try:
        meta["mean_brightness"] = mean_brightness(img)
    except ImportError:
        meta["mean_brightness"] = None
    side.write_text(json.dumps(meta, indent=1), encoding="utf-8")
    return path


# ------------------------------------------------------------------ recording
def find_ffmpeg() -> Optional[str]:
    """driver.start_recording's WinGet build, else ffmpeg on PATH, else None."""
    ff = os.path.join(os.environ.get("LOCALAPPDATA", ""), "Microsoft", "WinGet", "Packages",
                      "Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe", "ffmpeg-9.0-full_build", "bin",
                      "ffmpeg.exe")
    if os.path.isfile(ff):
        return ff
    return shutil.which("ffmpeg")


class Recorder:
    """Screen recording of the primary output: ddagrab (Desktop Duplication - no gdigrab flicker, driver.py run_012)
    and gdigrab when ddagrab dies within 2 s. `seconds` caps the file (-t) so ffmpeg stops even if we die.
    width=None keeps the native resolution (analysis); driver.py recorded 1280 wide at 10 fps (its live value).
    region = (x, y, w, h) in screen pixels for the gdigrab fallback (-offset_x/-offset_y/-video_size); None = the
    primary monitor, read at start() - without it gdigrab records the whole virtual desktop, 5120x1602 with this
    device's left monitor (review F7, 2026-09-24). ffmpeg starts with CREATE_NO_WINDOW (no console flashes up)."""

    START_GRACE_S = 2.0

    def __init__(self, path, seconds: float, fps: int = 30, width: Optional[int] = None, ffmpeg: Optional[str] = None,
                 region: Optional[Tuple[int, int, int, int]] = None):
        self.path = Path(path)
        self.seconds = seconds
        self.fps = fps
        self.width = width
        self.ffmpeg = ffmpeg
        self.region = tuple(region) if region else None
        self.proc = None
        self.how = None

    def commands(self, ff: str):
        scale = f",scale={self.width}:-2" if self.width else ""
        out = str(self.path)
        dda = [ff, "-y", "-t", str(self.seconds),
               "-filter_complex", f"ddagrab=framerate={self.fps},hwdownload,format=bgra{scale}",
               "-c:v", "libx264", "-preset", "ultrafast", "-crf", "26", "-pix_fmt", "yuv420p", out]
        gdi = [ff, "-y", "-f", "gdigrab", "-framerate", str(self.fps), "-t", str(self.seconds)]
        if self.region:
            x, y, w, h = (int(v) for v in self.region)
            gdi += ["-offset_x", str(x), "-offset_y", str(y), "-video_size", f"{w}x{h}"]
        gdi += ["-i", "desktop"]
        if self.width:
            gdi += ["-vf", f"scale={self.width}:-2"]
        gdi += ["-c:v", "libx264", "-preset", "ultrafast", "-crf", "28", "-pix_fmt", "yuv420p", out]
        return [("ddagrab", dda), ("gdigrab", gdi)]

    def start(self) -> bool:
        """True when ffmpeg is running; False when it is missing or both grabbers die within 2 s."""
        ff = self.ffmpeg or find_ffmpeg()
        if not ff:
            return False
        self.path.parent.mkdir(parents=True, exist_ok=True)
        try:
            self.path.unlink()
        except FileNotFoundError:
            pass
        if self.region is None:
            try:
                sw, sh = win.screen_size()
                self.region = (0, 0, int(sw), int(sh))
            except OSError:
                pass
        for how, args in self.commands(ff):
            try:
                proc = subprocess.Popen(args, stdin=subprocess.PIPE, stdout=subprocess.DEVNULL,
                                        stderr=subprocess.DEVNULL,
                                        creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
            except OSError:
                continue
            time.sleep(self.START_GRACE_S)
            if proc.poll() is None:
                self.proc, self.how = proc, how
                return True
        return False

    def stop(self) -> bool:
        """Ask ffmpeg to finish ('q'), wait up to 20 s, kill if needed; True when a non-empty file exists."""
        proc, self.proc = self.proc, None
        if proc is None:
            return False
        try:
            proc.stdin.write(b"q")
            proc.stdin.flush()
            proc.wait(timeout=20)
        except Exception:
            try:
                proc.kill()
            except Exception:
                pass
        return self.path.is_file() and self.path.stat().st_size > 0
