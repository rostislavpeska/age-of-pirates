"""gamewin.py pure geometry, and the drivers' --dry-run proven input-free (no window needed: the window lookup is
faked, every input / screenshot / process primitive is replaced by one that fails the test if called)."""
import sys
from pathlib import Path

import pytest

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
sys.dont_write_bytecode = True
import gamewin as gw          # noqa: E402
import game_driver as gd      # noqa: E402
from census_run import C      # noqa: E402

CAL = gw.CALIBRATION
PRIMARY = (0, 0, 2560, 1080)
MON2 = (2560, 0, 5120, 1080)          # a second monitor right of the primary
LEFT = (-2560, 0, 0, 1080)            # a monitor left of the primary (negative virtual origin)


# ------------------------------------------------------------------ pure functions
def test_calibration_sheet_round_trips_exactly():
    for k, v in C.items():
        if isinstance(v, tuple):
            assert gw.to_client(*gw.norm(*v), CAL) == v, k
    for p in [(444, 599), (1280, 14), (2375, 45), (1024, 528), (1024, 559), (785, 1032), (1773, 1032)]:
        assert gw.to_client(*gw.norm(*p), CAL) == p


def test_normalise_sheet_skips_scalars():
    n = gw.normalise_sheet(C)
    assert "dd_row_h" not in n and n["file_menu"] == (18 / 2560, 14 / 1080)


def test_to_screen_offsets_by_the_window_origin():
    nx, ny = gw.norm(*C["generate"])
    assert gw.to_screen(nx, ny, PRIMARY) == (1398, 739)
    assert gw.to_screen(nx, ny, MON2) == (2560 + 1398, 739)
    assert gw.to_screen(nx, ny, LEFT) == (-2560 + 1398, 739)
    assert gw.to_screen(nx, ny, (100, 50, 100 + 2560, 50 + 1080)) == (1498, 789)


def test_from_screen_inverts_to_screen():
    for rect in (PRIMARY, MON2, LEFT, (7, 9, 1927, 1089)):
        for p in ((0.0, 0.0), (0.5, 0.25), (0.58516, 0.68426), (1.0, 1.0)):
            x, y = gw.to_screen(*p, rect)
            bx, by = gw.from_screen(x, y, rect)
            w, h = rect[2] - rect[0], rect[3] - rect[1]
            assert abs(bx - p[0]) <= 0.5 / w and abs(by - p[1]) <= 0.5 / h


def test_to_screen_scales_proportionally_at_other_sizes():
    assert gw.to_screen(0.5, 0.5, (0, 0, 1920, 1080)) == (960, 540)


def test_input_abs_matches_game_driver_on_one_monitor():
    for sx, sy in ((0, 0), (1398, 739), (2559, 1079)):
        assert gw.input_abs(sx, sy, PRIMARY) == (int(sx * 65535 / 2559), int(sy * 65535 / 1079))


def test_input_abs_spans_the_virtual_desktop():
    vdesk = (-2560, 0, 2560, 1080)
    assert gw.input_abs(-2560, 0, vdesk) == (0, 0)
    assert gw.input_abs(2559, 1079, vdesk) == (65535, 65535)
    assert gw.input_abs(0, 0, vdesk)[0] == int(2560 * 65535 / 5119)


# ------------------------------------------------------------------ dry runs perform no input
def _boom(*_a, **_k):
    raise AssertionError("an input event, screenshot or process call happened in a dry run")


@pytest.fixture
def no_input(monkeypatch):
    import subprocess
    from PIL import ImageGrab
    for name in ("_send", "focus", "click", "drag", "key", "type_text", "set_field", "shot"):
        monkeypatch.setattr(gd, name, _boom)
    monkeypatch.setattr(ImageGrab, "grab", _boom)
    monkeypatch.setattr(subprocess, "run", _boom)
    monkeypatch.setattr("time.sleep", _boom)


@pytest.fixture
def fake_window(monkeypatch, no_input):
    monkeypatch.setattr(gw, "find_window", lambda title=gw.GAME_TITLE: 4242)
    monkeypatch.setattr(gw, "client_rect", lambda hwnd=None: MON2)
    monkeypatch.setattr(gw, "virtual_screen", lambda: (0, 0, 5120, 1080))
    monkeypatch.setattr(gw, "monitor_of", lambda rect: {"index": 2, "device": r"\\.\DISPLAY2", "rect": MON2,
                                                         "work": MON2, "primary": False})


def test_pilot_dry_run_logs_and_sends_nothing(no_input, capsys):
    P = gw.Pilot(dry_run=True, client=MON2, vdesk=(0, 0, 5120, 1080))
    P.focus()
    P.click(*gw.norm(*C["file_menu"]), "File")
    P.drag(gw.norm(*C["dd_thumb_top_from"]), gw.norm(*C["dd_thumb_top_to"]), "thumb")
    P.set_field(*gw.norm(*C["seed_field"]), 4242, width=6, label="seed")
    P.wait(10)
    assert P.grab() is None
    P.shot("x.png")
    out = capsys.readouterr().out
    assert "click File norm=(0.00703, 0.01296) client=(18, 14) screen=(2578, 14)" in out
    assert "key 0x08 x6 Backspace" in out and "type '4242'" in out
    assert all(line.startswith("DRY ") for line in out.splitlines())


def test_no_window_exits_2_without_input(monkeypatch, no_input, capsys):
    monkeypatch.setattr(gw, "find_window", lambda title=gw.GAME_TITLE: None)
    import bench_run, london_gen_safe, editor_regen
    assert bench_run.main(["--proto", "X", "--nav", "8,3"]) == 2
    assert london_gen_safe.main(["t", "4242"]) == 2
    assert editor_regen.main(["t", "4242", "--in-editor"]) == 2
    assert editor_regen.main(["t", "4242", "--from-menu", "--dry-run"]) == 2
    assert editor_regen.main(["t", "4242", "--dry-run"]) == 2
    assert "NOT FOUND" in capsys.readouterr().out


def test_bench_run_dry_run(fake_window, capsys):
    import bench_run
    assert bench_run.main(["--proto", "zpSPCLondonBasilica", "--nav", "8,3", "--dry-run"]) == 0
    out = capsys.readouterr().out
    assert "window on monitor 2" in out
    # row 3 of the dropdown: y = 497 + 2 * 31 = 559, on monitor 2 x + 2560
    assert "click dropdown row 3 norm=(0.40000, 0.51759) client=(1024, 559) screen=(3584, 559)" in out
    assert out.count("click dropdown down arrow") == 8
    assert "click Save norm=" in out and "client=(699, 838)" in out


def test_bench_run_peek_dry_run(fake_window, capsys):
    import bench_run
    assert bench_run.main(["--peek", "--dry-run"]) == 0
    assert "screenshot -> " in capsys.readouterr().out


def test_london_gen_safe_dry_run(fake_window, capsys):
    import london_gen_safe
    assert london_gen_safe.main(["t", "4242", "--save", "ldn_t", "--dry-run"]) == 0
    out = capsys.readouterr().out
    assert "click row 2 = 00000_zplondon norm=(0.40000, 0.51759) client=(1024, 559)" in out
    assert "click Generate" in out and "type 'ldn_t'" in out


def test_editor_regen_dry_runs(fake_window, capsys):
    import editor_regen
    assert editor_regen.main(["t", "4242", "--in-editor", "--dry-run"]) == 0
    out = capsys.readouterr().out
    assert "click row 2 = 00000_zplondon norm=(0.40000, 0.48889) client=(1024, 528)" in out
    assert editor_regen.main(["t", "4242", "--from-menu", "--dry-run"]) == 0
    assert "click Scenario Editor norm=(0.17344, 0.55463) client=(444, 599)" in capsys.readouterr().out
    assert editor_regen.main(["t", "4242", "--dry-run"]) == 0
    out = capsys.readouterr().out
    assert "DRY kill AoE3DE_s" in out and "click Generate" in out


# ------------------------------------------------------------------ pixel checks read the calibrated pixels
def test_pixel_checks_at_calibration(tmp_path):
    from PIL import Image
    import editor_regen as er
    im = Image.new("RGB", CAL, (0, 0, 0))
    im.putpixel((1280, 14), (40, 40, 40)); im.putpixel((2375, 45), (20, 60, 230))
    assert er.is_editor(im)
    for y in range(240, 264, 2):
        im.putpixel((444, y), (220, 190, 90))
    assert er.is_menu(im)
    bar = Image.new("RGB", CAL, (0, 0, 0))
    for x in range(785, 785 + 494):
        bar.putpixel((x, 1032), (60, 200, 220))
    p = tmp_path / "bar.png"
    bar.save(p)
    assert er.bar_fill(str(p)) == 50.0
