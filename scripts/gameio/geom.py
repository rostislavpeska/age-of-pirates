"""Pure geometry for gameio (no ctypes, no Windows): rectangles are (x, y, w, h) in screen pixels.

SendInput normalisation (MOUSEEVENTF_ABSOLUTE | MOUSEEVENTF_VIRTUALDESK): 0..65535 spans the whole virtual desktop
(MOUSEINPUT documentation: 0 maps to its first pixel, 65535 to its last). Two readings of how Windows turns the
number back into a pixel circulate: the documented linear one, round(n * (w - 1) / 65535), and floor(n * w / 65536).
axis_abs picks, per pixel, the middle of the numbers BOTH readings send to that pixel, so the click lands on the
same pixel either way (checked 2026-09-24 for every pixel of spans 1080, 1440, 1800, 1920, 2560, 2880, 3440, 5120
and 7680). The copies it replaces truncated - driver.click int(x * 65535 / SW), gamewin.input_abs
int(x * 65535 / (w - 1)) - which under the floor reading lands 1 px left for 42 of 2560 columns (mapview review
F9, 2026-09-24). Which reading Windows really applies is NOT measured on this machine: inputs.Session.click reads
the cursor back after every move and refuses to press when it is more than 1 px off.
"""
from __future__ import annotations

import math
from typing import Tuple

Rect = Tuple[int, int, int, int]          # x, y, w, h (screen pixels)


def axis_abs(p: float, origin: int, span: int) -> int:
    """One axis of input_abs: pixel p of a span starting at `origin` -> 0..65535."""
    if span < 2:
        raise ValueError(f"span {span} is degenerate")
    x = int(round(p - origin))
    x = min(span - 1, max(0, x))
    lo = max(math.ceil(x * 65536 / span), math.ceil((x - 0.5) * 65535 / (span - 1)), 0)
    hi = min(math.ceil((x + 1) * 65536 / span) - 1, math.ceil((x + 0.5) * 65535 / (span - 1)) - 1, 65535)
    return (lo + hi) // 2


def input_abs(x: float, y: float, vdesk: Rect) -> Tuple[int, int]:
    """Screen pixel -> SendInput absolute coordinates over the virtual desktop `vdesk` (x, y, w, h). Positions
    are rounded to the pixel grid first; a position outside the desktop is clamped to its edge."""
    vx, vy, vw, vh = vdesk
    return axis_abs(x, vx, vw), axis_abs(y, vy, vh)


def pixel_from_abs(ax: int, ay: int, vdesk: Rect) -> Tuple[int, int]:
    """The pixel an absolute coordinate lands on under the documented linear reading (for logs and tests)."""
    vx, vy, vw, vh = vdesk
    return vx + round(ax * (vw - 1) / 65535), vy + round(ay * (vh - 1) / 65535)


def in_rect(x: float, y: float, rect: Rect) -> bool:
    rx, ry, rw, rh = rect
    return rx <= x < rx + rw and ry <= y < ry + rh


def client_to_screen(x: float, y: float, client: Rect) -> Tuple[int, int]:
    """Client-area position -> screen pixel (rounded to the pixel grid)."""
    return int(round(client[0] + x)), int(round(client[1] + y))


def screen_to_client(x: float, y: float, client: Rect) -> Tuple[float, float]:
    return x - client[0], y - client[1]


def in_corner(x: int, y: int, origin: Tuple[int, int], size: int = 5) -> bool:
    """True when (x, y) lies in the size x size pixel square at `origin` (the abort corner)."""
    return origin[0] <= x < origin[0] + size and origin[1] <= y < origin[1] + size


def rect_ltrb(rect: Rect) -> Tuple[int, int, int, int]:
    """(x, y, w, h) -> (left, top, right, bottom), the bbox form PIL.ImageGrab takes."""
    x, y, w, h = rect
    return x, y, x + w, y + h
