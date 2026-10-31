"""The stone frame must not slice a charge. Owner, 2026-10-14: the Chinese banner weapons were cut."""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import cutcheck  # noqa: E402

WINDOW = cutcheck.WINDOW


def _field(tmp_path):
    arr = np.zeros((128, 128, 3), np.uint8)
    arr[:] = (210, 180, 40)
    path = tmp_path / "field.png"
    Image.fromarray(arr).save(path)
    return path, arr


def _icon(tmp_path, field_arr, rect, name):
    arr = field_arr.copy()
    x0, y0, x1, y1 = rect
    arr[y0:y1, x0:x1] = (230, 210, 160)
    path = tmp_path / name
    Image.fromarray(arr).save(path)
    return path


def test_a_charge_inside_the_margin_passes(tmp_path):
    field, arr = _field(tmp_path)
    x0, y0, x1, y1 = WINDOW
    icon = _icon(tmp_path, arr, (x0 + 8, y0 + 8, x1 - 8, y1 - 8), "whole.png")
    assert cutcheck.violations(icon, field) == 0


def test_a_charge_touching_the_frame_fails(tmp_path):
    field, arr = _field(tmp_path)
    icon = _icon(tmp_path, arr, (0, 0, 40, 40), "cut.png")
    assert cutcheck.violations(icon, field) > 0


def test_a_charge_flush_with_the_window_fails(tmp_path):
    field, arr = _field(tmp_path)
    x0, y0, x1, y1 = WINDOW
    icon = _icon(tmp_path, arr, (x0, y0 + 10, x0 + 20, y1 - 10), "flush.png")
    assert cutcheck.violations(icon, field) > 0


def test_cli_exits_on_a_cut_icon(tmp_path):
    field, arr = _field(tmp_path)
    icon = _icon(tmp_path, arr, (0, 40, 30, 80), "cut.png")
    assert cutcheck.main([str(icon), "--field", str(field)]) == 1
    whole_x0 = WINDOW[0] + 10
    whole = _icon(tmp_path, arr, (whole_x0, WINDOW[1] + 10, whole_x0 + 20, WINDOW[1] + 30), "whole.png")
    assert cutcheck.main([str(whole), "--field", str(field)]) == 0
