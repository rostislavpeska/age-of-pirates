"""gameio.sheets: the 2560x1080 sheet loads, every point carries a provenance, derived points are refused unless
asked for, malformed sheets fail at load, and the sheet's menu probe matches the committed home-menu crop."""
import json
import sys
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO))
from scripts.gameio import sheets  # noqa: E402

FIX = Path(__file__).resolve().parent / "fixtures"


def _write(tmp_path, data, name="100x50.json"):
    (tmp_path / name).write_text(json.dumps(data), encoding="utf-8")
    return tmp_path


def _pt(**kw):
    p = {"x": 1, "y": 2, "space": "client", "provenance": "measured 2026-09-24 by hand"}
    p.update(kw)
    return p


def test_the_2560_sheet_loads_with_provenance_everywhere():
    s = sheets.load_sheet(2560, 1080)
    assert s.size == (2560, 1080)
    assert {n.split(".")[0] for n in s.names()} == {"menu", "editor", "match", "minimap"}
    for n in s.names():
        p = s.point(n, allow_derived=True)
        assert sheets.PROVENANCE_RE.match(p["provenance"]), n
        assert p["space"] == "client", n
    assert not any(s.is_derived(n) for n in s.names())      # nothing derived was entered


def test_the_2560_sheet_points():
    s = sheets.load_sheet(2560, 1080)
    sk = s.point("menu.skirmish")
    assert (sk["x"], sk["y"], sk["rgb"]) == (444, 435, [212, 181, 104]) and sk["also"]["y"] == 417
    se = s.point("scenario_editor")                                         # bare unique name
    assert (se["x"], se["y"], se["rgb"], se["also"]["y"]) == (440, 600, [243, 215, 125], 582)
    for n in ("skirmish", "scenario_editor", "tools"):                      # every menu point: a label probe
        p = s.point("menu." + n)
        assert p["rgb"] and p["also"] and p["provenance"].startswith("measured 2026-09-24 live/01_menu.png"), n
    ed = s.point("editor.generate")
    assert (ed["x"], ed["y"]) == (1398, 739) and ed["name"] == "editor.generate"
    mm = s.point("minimap.editor_disc")
    assert (mm["x"], mm["y"], mm["r_disc"]) == (2269.33, 920.33, 130.5)
    assert "Measured 2026-09-24 LIVE" in mm["provenance"]                  # the post-patch editor frames
    ig = s.point("minimap.match_disc")
    assert (ig["x"], ig["y"], ig["r_disc"]) == (2399.32, 899.31, 147.0) and "re-measure live" in ig["provenance"].lower()
    # the old aitest minimap_center (2320, 900) is ~80 px off the disc: it must not reappear
    assert all((p["x"], p["y"]) != (2320, 900) for p in (s.point(n) for n in s.names()))
    # the stale 2026-08-26 Skirmish probe now lies on Multiplayer: not a point
    assert all((p["x"], p["y"]) != (444, 490) for p in (s.point(n) for n in s.names()))
    with pytest.raises(KeyError):
        s.point("editor.seed_field")                          # hits the label, never landed a seed


def test_point_returns_a_copy():
    s = sheets.load_sheet(2560, 1080)
    p = s.point("menu.skirmish")
    p["x"] = 0
    p["also"]["x"] = 0
    assert s.point("menu.skirmish")["x"] == 444 and s.point("menu.skirmish")["also"]["x"] == 444


def test_derived_points_are_refused_unless_asked(tmp_path):
    folder = _write(tmp_path, {"size": [100, 50], "match": {
        "quit_yes": _pt(provenance="derived from the 1920 sheet by +320"), "cog": _pt()}})
    s = sheets.load_sheet(100, 50, folder)
    with pytest.raises(sheets.DerivedPoint):
        s.point("match.quit_yes")
    assert s.point("match.quit_yes", allow_derived=True)["x"] == 1
    assert s.is_derived("quit_yes") and not s.is_derived("cog")


@pytest.mark.parametrize("bad", [
    _pt(provenance=""),
    _pt(provenance="measured last week"),                    # no date
    _pt(provenance="guessed"),
    {"x": 1, "y": 2, "space": "client"},                     # no provenance at all
    _pt(space="window"),
    _pt(x="444"),
    _pt(rgb=[300, 0, 0]),
    _pt(also={"x": 1, "y": 2}),                              # an 'also' needs an rgb
])
def test_malformed_points_fail_at_load(tmp_path, bad):
    folder = _write(tmp_path, {"menu": {"p": bad}})
    with pytest.raises(ValueError):
        sheets.load_sheet(100, 50, folder)


def test_notes_are_not_points(tmp_path):
    folder = _write(tmp_path, {"_comment": "x", "menu": {"_frames": "text", "p": _pt()}, "_not_entered": {"a": "b"}})
    s = sheets.load_sheet(100, 50, folder)
    assert s.names() == ["menu.p"] and "_not_entered" in s.notes
    assert s.note("menu", "_frames") == "text"
    with pytest.raises(KeyError):
        s.note("menu", "_layout")


def test_the_menu_layout_note():
    s = sheets.load_sheet(2560, 1080)
    lay = s.note("menu", "_layout")
    assert lay["x"] == 444 and lay["tol_px"] == 1 and len(lay["frame_lines"]) == 18
    assert lay["frame_lines"][6:8] == [416, 452] and lay["buttons"]["skirmish"] == [416, 453]
    assert lay["provenance"].startswith("measured 2026-09-24 live/01_menu.png")
    # every point sits inside its button's frame rows
    for n in ("skirmish", "scenario_editor", "tools"):
        top, bottom = lay["buttons"][n]
        p = s.point("menu." + n)
        assert top < p["y"] < bottom and lay["outline_x"][0] < p["x"] < lay["outline_x"][1], n
    lay["x"] = 0
    assert s.note("menu", "_layout")["x"] == 444                          # a copy


def test_missing_sheet_and_wrong_size(tmp_path):
    with pytest.raises(FileNotFoundError):
        sheets.load_sheet(1234, 567)
    folder = _write(tmp_path, {"size": [99, 50], "menu": {"p": _pt()}})
    with pytest.raises(ValueError):
        sheets.load_sheet(100, 50, folder)


def test_ambiguous_bare_name(tmp_path):
    folder = _write(tmp_path, {"menu": {"p": _pt()}, "editor": {"p": _pt()}})
    s = sheets.load_sheet(100, 50, folder)
    with pytest.raises(KeyError, match="ambiguous"):
        s.point("p")
    assert s.point("editor.p")["name"] == "editor.p"


def test_skirmish_probe_matches_the_committed_menu_crop():
    Image = pytest.importorskip("PIL.Image")
    from scripts.gameio import screens
    s = sheets.load_sheet(2560, 1080)
    sk = s.point("menu.skirmish")
    if not (FIX / "menu_20260920_col.png").is_file():
        pytest.skip("capture %s absent: images never enter the repo (AGENTS.md rule 8), the crop lives only where it was made" % "menu_20260920_col.png")
    col = Image.open(FIX / "menu_20260920_col.png").convert("RGB")      # crop box 424,230 - 464,750
    shifted = dict(sk, x=sk["x"] - 424, y=sk["y"] - 230, also=dict(sk["also"], x=sk["also"]["x"] - 424,
                                                                   y=sk["also"]["y"] - 230))
    ok, ev = screens.probe_ok(col, shifted, tol=0)
    assert ok, ev
    # the old point (444, 490) reads the MULTIPLAYER button there
    assert col.getpixel((444 - 424, 490 - 230)) == (113, 69, 38)


def test_every_menu_probe_matches_the_live_menu_crop():
    # the live 2026-09-24 capture (fixture menu_20260924_col.png, crop box 424,230 - 464,750), exact pixels
    Image = pytest.importorskip("PIL.Image")
    from scripts.gameio import screens
    s = sheets.load_sheet(2560, 1080)
    if not (FIX / "menu_20260924_col.png").is_file():
        pytest.skip("capture %s absent: images never enter the repo (AGENTS.md rule 8), the crop lives only where it was made" % "menu_20260924_col.png")
    col = Image.open(FIX / "menu_20260924_col.png").convert("RGB")
    for n in ("skirmish", "scenario_editor", "tools"):
        p = s.point("menu." + n)
        shifted = dict(p, x=p["x"] - 424, y=p["y"] - 230, also=dict(p["also"], x=p["also"]["x"] - 424,
                                                                  y=p["also"]["y"] - 230))
        ok, ev = screens.probe_ok(col, shifted, tol=0)
        assert ok, (n, ev)
    # the older Scenario Editor click (444, 599) is plain button fill: no label probe possible there
    assert col.getpixel((444 - 424, 599 - 230)) == (82, 34, 17)
