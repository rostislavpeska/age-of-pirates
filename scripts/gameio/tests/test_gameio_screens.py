"""gameio.screens on real pixels: committed crops of seven stored 2560x1080 shots (the home menu of 2026-09-20 and
the LIVE post-patch home menu of 2026-09-24, editor, editor with the New Scenario and Save File dialogs, VS Code in
front, an Istanbul match) are pasted back at their positions on a magenta canvas; the recognisers must give the
verdicts measured on the full shots, and menu_layout_ok must accept only the measured button layout (review F3).
Plus synthetic cases. Needs PIL (skipped where it is missing, as on the CI runner)."""
import json
import sys
from pathlib import Path

import pytest

Image = pytest.importorskip("PIL.Image")

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO))
from scripts.gameio import screens  # noqa: E402

FIX = Path(__file__).resolve().parent / "fixtures"
MANIFEST = json.loads((FIX / "screens_fixtures.json").read_text(encoding="utf-8"))["fixtures"]
MAGENTA = (255, 0, 255)                     # fails every colour class the recognisers use


def rebuild(name):
    f = MANIFEST[name]
    canvas = Image.new("RGB", tuple(f["size"]), MAGENTA)
    for c in f["crops"].values():
        if not (FIX / c["file"]).is_file():
            pytest.skip("capture %s absent: images never enter the repo (AGENTS.md rule 8), the crop lives only where it was made" % c["file"])
        canvas.paste(Image.open(FIX / c["file"]).convert("RGB"), tuple(c["box"][:2]))
    return canvas


def test_fixture_files_are_small():
    for p in FIX.iterdir():
        assert p.stat().st_size < 200_000, p.name


@pytest.mark.parametrize("name", sorted(MANIFEST))
def test_recognisers_on_real_frames(name):
    f = MANIFEST[name]
    im = rebuild(name)
    menu, mev = screens.is_main_menu(im)
    ed, eev = screens.is_editor(im)
    assert (menu, ed) == (f["expect"]["is_main_menu"], f["expect"]["is_editor"]), (mev, eev)
    assert mev["gold_rows"] == f["gold_rows"] and len(mev["frame_lines"]) == f["frame_lines"]
    assert eev["menubar"]["rgb"] == f["menubar_rgb"] and eev["playerbox"]["rgb"] == f["playerbox_rgb"]
    assert "warning" not in mev and "warning" not in eev


def test_the_expected_verdicts():
    got = {n: (f["expect"]["is_main_menu"], f["expect"]["is_editor"]) for n, f in MANIFEST.items()}
    assert got == {
        "menu_20260920": (True, False),
        "menu_20260924": (True, False),                     # the live post-patch capture of the main session
        "editor_20260917": (False, True),
        "editor_newscenario_20260922": (False, True),
        "editor_savefile_20260920": (False, False),         # the modal dims the player box to (12, 11, 162)
        "vscode_20260922": (False, False),
        "match_20260815": (False, False),
    }


def test_the_copied_column_test_alone_fires_on_sand():
    # why is_main_menu needs the frame test: editor_regen.is_menu's >= 12 gold rows fire on these two
    for name in ("match_20260815", "editor_newscenario_20260922"):
        ok, ev = screens.is_main_menu(rebuild(name))
        assert ev["legacy_is_menu"] and ev["gold_rows"] >= 12 and not ok and ev["frame_lines"] == []


NINE_BUTTONS = [251, 287, 306, 342, 361, 397, 416, 452, 471, 507, 526, 562, 581, 617, 636, 672, 691, 727]


@pytest.mark.parametrize("name", ["menu_20260920", "menu_20260924"])
def test_menu_frame_lines_are_the_nine_buttons(name):
    ok, ev = screens.is_main_menu(rebuild(name))
    assert ok and ev["frame_lines"] == NINE_BUTTONS


def test_the_live_menu_crops_are_small():
    # the fix-round brief: the committed crop of the live 2026-09-24 menu stays under 60 KB in total
    assert sum(p.stat().st_size for p in FIX.glob("menu_20260924_*.png")) < 60_000


def _shifted(im, dy):
    """The menu column (x < 1000) moved dy px down, as a menu with one button more above would be."""
    out = Image.new("RGB", im.size, MAGENTA)
    out.paste(im, (0, 0))
    col = im.crop((0, 0, 1000, im.size[1]))
    out.paste(MAGENTA, (0, 0, 1000, im.size[1]))
    out.paste(col, (0, dy))
    return out


@pytest.mark.parametrize("name", ["menu_20260920", "menu_20260924"])
def test_menu_layout_ok_on_the_measured_menus(name):
    ok, ev = screens.menu_layout_ok(rebuild(name))
    assert ok and ev["got"] == ev["want"] == NINE_BUTTONS and ev["max_diff_px"] == 0 and ev["tol_px"] == 1


@pytest.mark.parametrize("dy,ok", [(1, True), (-1, True), (2, False), (55, False), (-55, False)])
def test_menu_layout_ok_refuses_a_moved_layout(dy, ok):
    # review F3: is_main_menu alone accepts any layout with >= 8 frame lines; a one-pitch shift (the 2026-08-26
    # menu) still is a menu, but not THE menu the sheet's points were measured on
    im = _shifted(rebuild("menu_20260924"), dy)
    assert screens.is_main_menu(im)[0] is True
    got, ev = screens.menu_layout_ok(im)
    assert got is ok, ev


def test_menu_layout_ok_is_false_off_the_menu_and_without_a_sheet():
    for name in ("editor_20260917", "match_20260815", "vscode_20260922", "editor_newscenario_20260922"):
        assert screens.menu_layout_ok(rebuild(name))[0] is False
    ok, ev = screens.menu_layout_ok(rebuild("menu_20260924").resize((1280, 540), Image.NEAREST))
    assert not ok and "no measured menu layout for 1280x540" in ev["error"]
    lay = {"frame_lines": NINE_BUTTONS[:-2], "tol_px": 1}                  # an explicit layout, e.g. from a test
    assert screens.menu_layout_ok(rebuild("menu_20260924"), lay)[0] is False


def _label_box(im, x0, y0, x1, y1):
    """The measurement behind the sheet's menu probes: gold glyph pixels (R > 150, G > 110, R - B > 60)."""
    g = [(x, y) for y in range(y0, y1) for x in range(x0, x1)
         if (lambda c: c[0] > 150 and c[1] > 110 and c[0] - c[2] > 60)(im.getpixel((x, y)))]
    xs, ys = [p[0] for p in g], [p[1] for p in g]
    return min(xs), max(xs), min(ys), max(ys)


def test_the_live_label_boxes_behind_the_sheet_points():
    im = rebuild("menu_20260924")
    assert _label_box(im, 360, 424, 530, 447) == (403, 485, 429, 441)     # Skirmish: centre (444.0, 435.0)
    assert _label_box(im, 360, 589, 530, 612) == (365, 524, 594, 606)     # Scenario Editor: centre (444.5, 600.0)


def test_synthetic_menu_and_editor():
    im = Image.new("RGB", (2560, 1080), (0, 0, 0))
    assert screens.is_main_menu(im)[0] is False and screens.is_editor(im)[0] is False
    im.putpixel((1280, 14), (40, 40, 40))
    im.putpixel((2375, 45), (20, 60, 230))
    assert screens.is_editor(im)[0] is True                 # sandbox/census/tests/test_gamewin.py's pixels
    for top in range(251, 251 + 55 * 6, 55):                # six buttons: fill, 2-px frames, black outside
        for y in range(top, top + 38):
            im.putpixel((444, y), (82, 34, 17))
        for y in (top, top + 1, top + 36, top + 37):
            im.putpixel((444, y), (253, 228, 163))
        im.putpixel((444, top - 1), (0, 0, 0))
        im.putpixel((444, top + 38), (0, 0, 0))
    ok, ev = screens.is_main_menu(im)
    assert not ok and len(ev["frame_lines"]) == 12 and ev["gold_rows"] == 0    # frames without gold labels
    for top in range(251, 251 + 55 * 6, 55):
        for y in range(top + 15, top + 23):
            im.putpixel((444, y), (220, 190, 110))
    ok, ev = screens.is_main_menu(im)
    assert ok and ev["gold_rows"] == 24


def test_other_sizes_scale_and_warn():
    im = rebuild("menu_20260920").resize((1280, 540), Image.NEAREST)
    ok, ev = screens.is_main_menu(im)
    assert "warning" in ev and ev["x"] == 222


def test_probe_ok_and_path_input(tmp_path):
    im = rebuild("editor_20260917")
    p = tmp_path / "e.png"
    im.save(p)
    pt = {"x": 2375, "y": 45, "rgb": [0, 0, 255]}
    assert screens.probe_ok(str(p), pt)[0] is True
    assert screens.probe_ok(im, dict(pt, also={"x": 1280, "y": 14, "rgb": [28, 28, 28]}))[0] is True
    ok, ev = screens.probe_ok(im, dict(pt, also={"x": 1280, "y": 14, "rgb": [200, 28, 28]}))
    assert not ok and ev["ok"] and not ev["also"]["ok"]
    with pytest.raises(ValueError):
        screens.probe_ok(im, {"x": 1, "y": 1})
    assert screens.is_editor(str(p))[0] is True


# The 2880x1800 test device (2026-09-24, the twin test session): its home menu column is x = 186, not the 2560
# column scaled (500), the buttons are 82.5 px apart and every second frame line is one row, not two (the UI is
# scaled 1.5x by the game, so a 2-px line lands on 1.5 rows). The live full-resolution capture's column and label
# probe pixels as numbers (fixtures/menu_2880_20260924.json; rule 8: no screenshots in the repo).
NINE_BUTTONS_2880 = [377, 431, 460, 514, 542, 596, 625, 679, 707, 761, 790, 844, 872, 926, 955, 1009, 1037, 1091]


def rebuild_2880_menu():
    f = json.loads((FIX / "menu_2880_20260924.json").read_text(encoding="utf-8"))
    canvas = Image.new("RGB", tuple(f["size"]), MAGENTA)
    x = f["column_x"]
    for y0, n, r, g, b in f["column"]:
        for y in range(y0, y0 + n):
            canvas.putpixel((x, y), (r, g, b))
    for px, py, r, g, b in f["pixels"]:
        canvas.putpixel((px, py), (r, g, b))
    return canvas


def test_menu_2880_uses_the_sheet_geometry():
    ok, ev = screens.is_main_menu(rebuild_2880_menu())
    assert ok and ev["x"] == 186 and ev["frame_lines"] == NINE_BUTTONS_2880, ev
    assert "warning" not in ev
    ok, ev = screens.menu_layout_ok(rebuild_2880_menu())
    assert ok and ev["max_diff_px"] == 0, ev


def test_menu_2880_probes_hit_the_labels():
    from scripts.gameio import sheets
    sh = sheets.load_sheet(2880, 1800)
    im = rebuild_2880_menu()
    for name in ("menu.skirmish", "menu.scenario_editor", "menu.tools"):
        ok, ev = screens.probe_ok(im, sh.point(name))
        assert ok, (name, ev)


def test_menu_2880_layout_refuses_a_one_pitch_shift():
    im = rebuild_2880_menu()
    out = Image.new("RGB", im.size, MAGENTA)
    out.paste(im.crop((0, 0, 1000, 1800)), (0, 82))
    assert screens.menu_layout_ok(out)[0] is False


def test_editor_2880_uses_the_sheet_points():
    # the 2880x1800 sheet's measured editor.menubar (1440,14) (29,29,29) and editor.player_box (2673,76) (0,0,255)
    # (live/01_editor.png, 2026-09-24); the 2560 positions scaled read (1440,23) and (2672,75), never measured here
    im = Image.new("RGB", (2880, 1800), MAGENTA)
    im.putpixel((1440, 14), (29, 29, 29))
    im.putpixel((2673, 76), (0, 0, 255))
    ok, ev = screens.is_editor(im)
    assert ok and ev["menubar"]["xy"] == [1440, 14] and ev["playerbox"]["xy"] == [2673, 76], ev
    assert "warning" not in ev
    im.putpixel((2673, 76), (12, 11, 162))                  # the Save File dialog dims the box
    assert screens.is_editor(im)[0] is False
