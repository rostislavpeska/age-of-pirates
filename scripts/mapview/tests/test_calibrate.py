"""mapview.calibrate: pairs files, the disc -> check -> load route, the icon fit's gates, the edges check, blobs and
stars (review F1-F10, 2026-09-24, and the fix round). Records go to tmp_path (CAL_DIR patched); nothing touches the
screen. Image tests need PIL and skip without it (CI installs only pytest); the numeric route runs everywhere."""
import json
import sys
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO))
from scripts.mapview import calibrate as CB  # noqa: E402
from scripts.mapview import mapinfo as MI  # noqa: E402
from scripts.mapview import transform as T  # noqa: E402

FIXTURES = Path(__file__).resolve().parent / "fixtures"
PARIS = json.loads((FIXTURES / "paris_editor_minimap.json").read_text(encoding="utf-8"))
INGAME = json.loads((FIXTURES / "ingame_hud_minimap.json").read_text(encoding="utf-8"))
LONDON = json.loads((FIXTURES / "london4p_editor_minimap.json").read_text(encoding="utf-8"))


@pytest.fixture
def cal_dir(tmp_path, monkeypatch):
    d = tmp_path / "cal"
    monkeypatch.setattr(T, "CAL_DIR", d)
    monkeypatch.delenv("MAPVIEW_CAL_DIR", raising=False)
    return d


def _write(tmp_path, name, doc):
    p = tmp_path / name
    p.write_text(json.dumps(doc), encoding="utf-8")
    return p


def _pairs_doc(fix, which="explorer", with_size=True, with_map=True):
    pairs = []
    for s in fix["stars"]:
        src = s if which == "explorer" else s["post"]
        pairs.append({"what": src["what"], "x_m": src["x_m"], "z_m": src["z_m"], "px": s["star_px"], "py": s["star_py"]})
    doc = {"pairs": pairs}
    if with_map:
        doc.update(map=fix["map"], players=fix["players"], teams=fix["teams"])
    if with_size:
        doc.update(size_x_m=fix["size_x_m"], size_z_m=fix["size_z_m"])
    return doc


def _paris_pairs_doc(which="explorer", with_size=True, with_map=True):
    return _pairs_doc(PARIS, which, with_size, with_map)


def _disc_record(fix=PARIS):
    d = fix["disc"]
    return T.Calibration("editor", 2560, 1080, d["cx"], d["cy"], d["r_disc"], measured=True, method="disc",
                         accepted=True, r_line_px=d["r_line"])


_paris_disc_record = _disc_record


# ----------------------------------------------------------------------------- mapinfo
class TestMapInfo:
    def test_london_engine_sizes_by_player_count(self):
        """rmSetMapSize 645 / 685 / 765 -> whole 2 m tiles 646 / 686 / 766 (the save's terrain header: London 4p
        180 x 343 tiles, 2026-09-24)."""
        want = {2: (360.0, 646.0), 3: (360.0, 686.0), 4: (360.0, 686.0), 5: (360.0, 686.0), 6: (360.0, 766.0),
                8: (360.0, 766.0)}
        for players, size in want.items():
            assert MI.map_size(REPO / "randmaps" / "zplondon.xs", players, 2) == size

    def test_script_sizes_stay_available(self):
        assert MI.script_map_size("zplondon", 4) == MI.map_size("zplondon", 4, engine=False) == (360.0, 685.0)
        assert MI.script_map_size("zplondon", 2) == (360.0, 645.0)

    def test_paris_by_name(self):
        assert MI.map_size("zpparis", 4) == (PARIS["size_x_m"], PARIS["size_z_m"]) == (654.0, 360.0)
        assert MI.map_size("zpparis", 4, engine=False) == (653.0, 360.0)

    def test_engine_size_rounds_half_tiles_up(self):
        assert [MI.engine_size_m(v) for v in (685, 653, 645, 765, 360, 686, 620, 560)] == \
            [686.0, 654.0, 646.0, 766.0, 360.0, 686.0, 620.0, 560.0]
        with pytest.raises(ValueError):
            MI.engine_size_m(0)

    def test_cli(self, capsys):
        assert MI.main(["zplondon", "--players", "4"]) == 0
        out, err = capsys.readouterr()
        assert out.strip() == "360x686" and "685" in err
        assert MI.main(["zplondon", "--players", "4", "--script"]) == 0
        assert capsys.readouterr().out.strip() == "360x685"

    def test_parse_size(self):
        assert MI.parse_size("360x685") == (360.0, 685.0) and MI.parse_size(" 653X360 ") == (653.0, 360.0)
        for bad in ("360", "x685", "0x685", "360x-1", "abc"):
            with pytest.raises(ValueError):
                MI.parse_size(bad)

    def test_unknown_map(self):
        with pytest.raises(FileNotFoundError):
            MI.resolve_map("no_such_map_zz")


# ----------------------------------------------------------------------------- pairs files
class TestPairs:
    def test_metres_with_file_size_and_mapsim_agree(self, tmp_path):
        d, pairs, note = CB.load_metre_pairs(_write(tmp_path, "p.json", _paris_pairs_doc()))
        assert len(pairs) == 4 and all((p["size_x_m"], p["size_z_m"]) == (654.0, 360.0) for p in pairs)
        assert "zpparis.xs" in note and "rmSetMapSize 653x360" in note

    def test_size_from_mapsim_alone(self, tmp_path):
        d, pairs, note = CB.load_metre_pairs(_write(tmp_path, "p.json", _paris_pairs_doc(with_size=False)))
        assert pairs[0]["size_x_m"] == 654.0 and pairs[0]["size_z_m"] == 360.0

    def test_size_disagreeing_with_the_engine_is_refused(self, tmp_path):
        """review F1 + the fix round: a 4-player London is 360 x 686 m. The documented 645 m example and rmSetMapSize's
        own 685 m are refused (the latter with a hint); 686 and a float within 0.5 m pass."""
        doc = {"map": "zplondon", "players": 4, "size_x_m": 360, "size_z_m": 645,
               "pairs": [{"what": "TC", "x_m": 40.1, "z_m": 147.76, "px": 1, "py": 2}]}
        with pytest.raises(CB.PairsError, match="disagrees") as e:
            CB.load_metre_pairs(_write(tmp_path, "p.json", doc))
        assert "use 360x686" not in str(e.value)
        doc["size_z_m"] = 685
        with pytest.raises(CB.PairsError, match="whole 2 m tiles: use 360x686"):
            CB.load_metre_pairs(_write(tmp_path, "q.json", doc))
        for ok in (686, 686.3):
            doc["size_z_m"] = ok
            assert CB.load_metre_pairs(_write(tmp_path, "r.json", doc))[1][0]["size_z_m"] == ok

    def test_no_size_is_refused(self, tmp_path):
        doc = _paris_pairs_doc(with_size=False, with_map=False)
        with pytest.raises(CB.PairsError, match="no map size"):
            CB.load_metre_pairs(_write(tmp_path, "p.json", doc))

    def test_string_sizes_are_cast(self, tmp_path):
        """review F9: "654" is a size, not a traceback."""
        doc = _paris_pairs_doc(with_map=False)
        doc["size_x_m"], doc["size_z_m"] = "654", "360"
        assert CB.load_metre_pairs(_write(tmp_path, "p.json", doc))[1][0]["size_x_m"] == 654.0
        doc["size_x_m"] = "wide"
        with pytest.raises(CB.PairsError):
            CB.load_metre_pairs(_write(tmp_path, "q.json", doc))

    def test_fraction_pairs_need_size_or_aspect(self, tmp_path):
        """review F7: no silent aspect 1.0."""
        doc = {"pairs": [{"fx": 0.1, "fz": 0.2, "px": 1, "py": 2}] * 3}
        with pytest.raises(CB.PairsError, match="aspect"):
            CB.load_pairs(_write(tmp_path, "p.json", doc))
        doc["aspect"] = 1.9
        assert CB.load_pairs(_write(tmp_path, "q.json", doc))[3] == 1.9

    def test_check_pairs_must_be_metres(self, tmp_path):
        doc = {"size_x_m": 1, "size_z_m": 1, "pairs": [{"fx": 0.1, "fz": 0.2, "px": 1, "py": 2}]}
        with pytest.raises(CB.PairsError, match="metres"):
            CB.load_metre_pairs(_write(tmp_path, "p.json", doc))

    def test_cli_contradicting_the_file_is_refused(self, tmp_path):
        """review F6: --players 2 on a file that says 4 players used to re-size every pair silently."""
        p = _write(tmp_path, "p.json", _pairs_doc(LONDON, with_size=False))
        with pytest.raises(CB.PairsError, match="--players 2 contradicts"):
            CB.load_metre_pairs(p, players_arg=2)
        with pytest.raises(CB.PairsError, match="contradicts the file's map"):
            CB.load_metre_pairs(p, map_arg="randmaps/zpparis.xs", players_arg=4)
        with pytest.raises(CB.PairsError, match="--teams 3 contradicts"):
            CB.load_metre_pairs(p, teams_arg=3)
        # agreeing values, a path spelling of the same map: accepted
        assert CB.load_metre_pairs(p, map_arg="randmaps/zplondon.xs", players_arg=4, teams_arg=2)[1][0]["size_z_m"] == 686.0


# ----------------------------------------------------------------------------- check (numbers only)
class TestCheck:
    def test_paris_explorer_check_passes_and_is_stored(self, tmp_path, cal_dir, capsys):
        _paris_disc_record().save()
        with pytest.raises(ValueError, match="never passed"):
            T.load_calibration("editor", 2560, 1080)
        pj = _write(tmp_path, "pairs.json", _paris_pairs_doc())
        assert CB.main(["check", str(pj), "--screen", "editor", "--screen-size", "2560x1080"]) == 0
        assert "PASS" in capsys.readouterr().out
        cal = T.load_calibration("editor", 2560, 1080)
        assert cal.checked and len(cal.check_pairs) == 4 and cal.check_residual_px < 2.0
        assert all(abs(p["err_px"] - s["explorer_err_px"]) <= 0.006 for p, s in zip(cal.check_pairs, PARIS["stars"]))
        assert set(cal.check_pairs[0]) == {"kind", "what", "x_m", "z_m", "size_x_m", "size_z_m", "px", "py", "err_px"}
        assert cal.check_pairs[0]["kind"] == "icon"

    def test_london_live_explorers_pass_within_1_5_px(self, tmp_path, cal_dir, capsys):
        """The live London 4p frame (2026-09-24): the disc record + the save's Explorers at the engine size."""
        _disc_record(LONDON).save()
        pj = _write(tmp_path, "pairs.json", _pairs_doc(LONDON, with_size=False, with_map=False))
        assert CB.main(["check", str(pj), "--screen", "editor", "--size", "2560x1080",
                        "--map", "zplondon", "--players", "4"]) == 0
        out = capsys.readouterr().out
        assert "360x686 m (engine" in out and "PASS" in out
        cal = T.load_calibration("editor", 2560, 1080)
        assert cal.check_residual_px < 1.5
        assert [p["err_px"] for p in cal.check_pairs] == pytest.approx([s["explorer_err_px"] for s in LONDON["stars"]],
                                                                       abs=0.006)

    def test_check_with_map_and_players(self, tmp_path, cal_dir):
        _paris_disc_record().save()
        pj = _write(tmp_path, "pairs.json", _paris_pairs_doc(with_size=False, with_map=False))
        assert CB.main(["check", str(pj), "--screen", "editor", "--size", "2560x1080",
                        "--map", "randmaps/zpparis.xs", "--players", "4"]) == 0
        assert T.load_calibration("editor", 2560, 1080).checked

    def test_command_posts_fail_and_nothing_is_written(self, tmp_path, cal_dir, capsys):
        """The stars are the explorers: pairing them with the command posts fails the 3 px check."""
        p = _paris_disc_record().save()
        before = p.read_bytes()
        pj = _write(tmp_path, "posts.json", _paris_pairs_doc("post"))
        assert CB.main(["check", str(pj), "--screen", "editor", "--size", "2560x1080"]) == 1
        out = capsys.readouterr().out
        assert "FAIL" in out and out.count("err ") == 4
        assert p.read_bytes() == before and not T.Calibration.from_json(before.decode()).checked

    def test_a_failed_check_revokes_an_earlier_pass(self, tmp_path, cal_dir, capsys):
        _paris_disc_record().save()
        good = _write(tmp_path, "pairs.json", _paris_pairs_doc())
        bad = _write(tmp_path, "posts.json", _paris_pairs_doc("post"))
        assert CB.main(["check", str(good), "--screen", "editor", "--size", "2560x1080"]) == 0
        assert CB.main(["check", str(bad), "--screen", "editor", "--size", "2560x1080"]) == 1
        assert "REVOKED" in capsys.readouterr().out
        with pytest.raises(ValueError, match="never passed"):
            T.load_calibration("editor", 2560, 1080)
        rec = T.load_calibration("editor", 2560, 1080, require_checked=False)
        assert not rec.checked and rec.check_residual_px > T.ACCEPT_CHECK_PX

    def test_a_contradicting_cli_cannot_revoke(self, tmp_path, cal_dir, capsys):
        """review F6: `--players 2` on a 4-player file used to fail at 14 px and revoke a good record."""
        _disc_record(LONDON).save()
        pj = _write(tmp_path, "pairs.json", _pairs_doc(LONDON, with_size=False))
        assert CB.main(["check", str(pj), "--screen", "editor", "--size", "2560x1080"]) == 0
        assert CB.main(["check", str(pj), "--screen", "editor", "--size", "2560x1080", "--players", "2"]) == 2
        assert "contradicts" in capsys.readouterr().out
        assert T.load_calibration("editor", 2560, 1080).checked

    def test_check_refuses_an_unaccepted_record(self, tmp_path, cal_dir, capsys):
        rec = _paris_disc_record()
        rec.accepted = rec.measured = False
        rec.save()
        pj = _write(tmp_path, "pairs.json", _paris_pairs_doc())
        assert CB.main(["check", str(pj), "--screen", "editor", "--size", "2560x1080"]) == 1
        assert "not an accepted" in capsys.readouterr().out

    def test_check_refuses_the_fitted_points(self, tmp_path, cal_dir, capsys):
        """review F8: an icon record checked with the very pairs it was fitted on is not an independent check."""
        pj = _write(tmp_path, "pairs.json", _paris_pairs_doc())
        assert CB.main(["fit", str(pj), "--screen", "editor", "--size", "2560x1080"]) == 0
        capsys.readouterr()
        assert CB.main(["check", str(pj), "--screen", "editor", "--size", "2560x1080"]) == 1
        assert "fitted on" in capsys.readouterr().out
        assert not T.load_calibration("editor", 2560, 1080, require_checked=False).checked

    def test_check_screen_choices(self, tmp_path, cal_dir):
        """review F9: a typo is an argparse error, not a FileNotFoundError traceback."""
        with pytest.raises(SystemExit):
            CB.main(["check", "x.json", "--screen", "ingam", "--size", "2560x1080"])

    def test_map_size_given_as_screen_size_gets_a_hint(self, tmp_path, cal_dir, capsys):
        """review F7: camera.py's --size is the map size; here it is the screen's."""
        pj = _write(tmp_path, "pairs.json", _paris_pairs_doc())
        assert CB.main(["check", str(pj), "--screen", "editor", "--size", "360x686"]) == 1
        assert "looks like a map size" in capsys.readouterr().out

    def test_missing_pairs_file_is_a_message(self, tmp_path, cal_dir, capsys):
        """review F7: a missing file used to end in a FileNotFoundError traceback."""
        _paris_disc_record().save()
        assert CB.main(["check", str(tmp_path / "nope.json"), "--screen", "editor", "--size", "2560x1080"]) == 2
        assert "REFUSED" in capsys.readouterr().out

    def test_check_refuses_disagreeing_map(self, tmp_path, cal_dir, capsys):
        _paris_disc_record().save()
        doc = _paris_pairs_doc()
        doc["players"] = 2                      # Paris is 573 m (engine 574) long for 2 players
        pj = _write(tmp_path, "pairs.json", doc)
        assert CB.main(["check", str(pj), "--screen", "editor", "--size", "2560x1080"]) == 2
        assert "disagrees" in capsys.readouterr().out


# ----------------------------------------------------------------------------- edges: the geometry (no PIL)
class TestEdgeGeometry:
    def test_london_rays(self):
        geo = CB.long_edge_rays(_disc_record(LONDON), 360.0, 686.0)
        for k, x_name in (("a", "x=0 m"), ("b", "x=360 m")):
            g = geo[k]
            assert g["what"] == "long edge " + x_name and abs(g["model_px"] - 68.484) < 0.001
            assert len(g["rays"]) == LONDON["edges"]["sides"][k]["rays"] == 101
            for x0, y0, nx, ny, dm in g["rays"]:
                assert abs(nx * nx + ny * ny - 1) < 1e-9 and abs(dm - g["model_px"]) < 1e-9
                assert ((x0 + (dm + 13.5) * nx - 2269.33) ** 2 + (y0 + (dm + 13.5) * ny - 920.33) ** 2) ** 0.5 <= 130.5
        # the normals point away from each other, across the map: +45 degrees on screen for x = 360 m
        (xa, ya, nxa, nya, _), (xb, yb, nxb, nyb, _) = geo["a"]["rays"][50], geo["b"]["rays"][50]
        assert abs(nxa + nxb) < 1e-9 and abs(nya + nyb) < 1e-9 and nxb > 0 and nyb < 0

    def test_paris_rays(self):
        geo = CB.long_edge_rays(_disc_record(PARIS), 654.0, 360.0)
        assert geo["a"]["what"] == "long edge z=0 m" and abs(geo["b"]["model_px"] - 71.835) < 0.001
        assert len(geo["a"]["rays"]) == PARIS["edges"]["sides"]["a"]["rays"] == 99

    def test_square_map_is_refused(self):
        with pytest.raises(ValueError, match="square"):
            CB.long_edge_rays(_disc_record(PARIS), 500.0, 500.0)
        with pytest.raises(ValueError, match="square"):
            CB.long_edge_rays(_disc_record(PARIS), 500.0, 520.0)

    def test_edges_reaching_the_rim_are_refused(self):
        """A barely oblong map: its long edges run within 13.5 px of the rim on every sample."""
        with pytest.raises(ValueError, match="reach the"):
            CB.measure_edges(None, _disc_record(PARIS), 500.0, 540.0)


# ----------------------------------------------------------------------------- fit (icons)
class TestFitCli:
    def test_fit_on_the_explorer_stars(self, tmp_path, cal_dir, capsys):
        pj = _write(tmp_path, "pairs.json", _paris_pairs_doc())
        assert CB.main(["fit", str(pj), "--screen", "editor", "--size", "2560x1080"]) == 0
        out = capsys.readouterr().out
        assert "residual" in out and "n/a" not in out
        cal = T.load_calibration("editor", 2560, 1080, require_checked=False)
        assert cal.method == "icons" and cal.accepted and not cal.checked and cal.residual_px < 1.0
        assert (cal.sign_u, cal.sign_v) == (1, -1) and abs(cal.radius_px - PARIS["disc"]["r_disc"]) < 1.0
        assert cal.points[0]["size_x_m"] == 654.0 and "what" in cal.points[0]

    def test_three_pairs_print_na_and_two_are_refused(self, tmp_path, cal_dir, capsys):
        doc = _paris_pairs_doc()
        doc["pairs"] = doc["pairs"][:3]
        assert CB.main(["fit", str(_write(tmp_path, "p3.json", doc)), "--screen", "editor", "--size", "2560x1080"]) == 0
        assert "n/a (needs >= 4 pairs)" in capsys.readouterr().out
        doc["pairs"] = doc["pairs"][:2]
        assert CB.main(["fit", str(_write(tmp_path, "p2.json", doc)), "--screen", "ingame", "--size", "2560x1080"]) == 1
        assert not T.cal_path("ingame", 2560, 1080).exists()

    def test_force_writes_an_unaccepted_record_that_is_refused(self, tmp_path, cal_dir, capsys):
        """review F6: --force keeps a failed fit for inspection, never for aiming."""
        doc = _paris_pairs_doc()
        doc["pairs"][0]["px"] += 8.0
        pj = _write(tmp_path, "bad.json", doc)
        assert CB.main(["fit", str(pj), "--screen", "editor", "--size", "2560x1080"]) == 1
        assert not T.cal_path("editor", 2560, 1080).exists()
        assert CB.main(["fit", str(pj), "--screen", "editor", "--size", "2560x1080", "--force"]) == 1
        rec = T.Calibration.from_json(T.cal_path("editor", 2560, 1080).read_text(encoding="utf-8"))
        assert not rec.accepted and not rec.measured and rec.residual_px > T.ACCEPT_FIT_PX
        with pytest.raises(ValueError, match="not an accepted"):
            T.load_calibration("editor", 2560, 1080, require_checked=False)

    def test_fit_does_not_replace_a_disc_record_silently(self, tmp_path, cal_dir, capsys):
        p = _paris_disc_record().save()
        before = p.read_bytes()
        pj = _write(tmp_path, "pairs.json", _paris_pairs_doc())
        assert CB.main(["fit", str(pj), "--screen", "editor", "--screen-size", "2560x1080"]) == 1
        assert p.read_bytes() == before and "--overwrite" in capsys.readouterr().out
        assert CB.main(["fit", str(pj), "--screen", "editor", "--size", "2560x1080", "--overwrite"]) == 0
        assert T.Calibration.from_json(p.read_text(encoding="utf-8")).method == "icons"


# ----------------------------------------------------------------------------- disc gate (no PIL)
class TestDiscGate:
    def _m(self, probes, r_disc=130.5, r_line=136.18):
        from scripts.mapview import minimap_detect as MD
        return MD.DiscMeasurement(100.0, 100.0, r_disc, r_line, 1200, 0.55, 288, 0.0,
                                  [{"x": x, "y": y, "rgb": [222, 186, 90]} for x, y in probes])

    def test_quadrants(self):
        four = [(200, 50), (0, 50), (0, 150), (200, 150), (150, 10)]
        assert CB.probe_quadrants(self._m(four)) == 4 and CB.disc_gate(self._m(four)) == []
        bunched = [(200, 50), (190, 40), (180, 30), (170, 20), (160, 10)]
        why = CB.disc_gate(self._m(bunched))
        assert len(why) == 1 and "1 quadrant" in why[0]

    def test_ring_ratio(self):
        four = [(200, 50), (0, 50), (0, 150), (200, 150)]
        assert CB.disc_gate(self._m(four, r_disc=130.5, r_line=136.18)) == []
        why = CB.disc_gate(self._m(four, r_disc=120.5, r_line=136.18))   # the review's painted-rim result
        assert len(why) == 1 and "bright line / rim" in why[0]


# ----------------------------------------------------------------------------- images (PIL)
def _screen_from_crop(fix, tmp_path, name, dim=None):
    """A full 2560x1080 'screenshot' with the fixture crop pasted at its offset (the rest black)."""
    Image = pytest.importorskip("PIL.Image")
    crop = Image.open(FIXTURES / fix["image"]).convert("RGB")
    if dim is not None:
        crop = crop.point(lambda v: int(v * dim))
    full = Image.new("RGB", tuple(fix["screen_size"]), (0, 0, 0))
    full.paste(crop, tuple(fix["crop_offset"]))
    p = tmp_path / name
    full.save(p)
    return p


class TestDiscCli:
    @pytest.mark.parametrize("fix", [PARIS, INGAME, LONDON], ids=["editor", "ingame", "london_live"])
    def test_disc_record(self, fix, tmp_path, cal_dir, capsys):
        png = _screen_from_crop(fix, tmp_path, "shot.png")
        assert CB.main(["disc", str(png), "--screen", fix["screen"]]) == 0
        assert "in 4 quadrants" in capsys.readouterr().out
        cal = T.load_calibration(fix["screen"], 2560, 1080, require_checked=False)
        d = fix["disc"]
        assert cal.method == "disc" and cal.accepted and cal.measured and not cal.checked
        assert abs(cal.cx - d["cx"]) <= 0.5 and abs(cal.cy - d["cy"]) <= 0.5 and abs(cal.radius_px - d["r_disc"]) <= 0.5
        assert abs(cal.r_line_px - d["r_line"]) <= 0.5 and (cal.sign_u, cal.sign_v) == (1, -1)
        assert len(cal.probes) >= CB.DISC_MIN_PROBES and "line / rim 1.04" in cal.note
        from scripts.mapview import minimap_detect as MD
        assert MD.probes_ok(png, cal.probes)[0]                 # probes are stored in screen pixels
        with pytest.raises(ValueError):
            T.load_calibration(fix["screen"], 2560, 1080)       # not checked yet

    def test_disc_refuses_a_dimmed_screen(self, tmp_path, cal_dir, capsys):
        """A modal dialog dims the screen to about 0.63x: no ring, nothing written."""
        png = _screen_from_crop(PARIS, tmp_path, "dim.png", dim=0.63)
        assert CB.main(["disc", str(png), "--screen", "editor"]) == 1
        assert "REFUSED" in capsys.readouterr().out and not T.cal_path("editor", 2560, 1080).exists()

    def test_disc_then_check_then_aim(self, tmp_path, cal_dir):
        """The whole route: disc on the screenshot, check with the explorers of the same generation, load."""
        png = _screen_from_crop(PARIS, tmp_path, "shot.png")
        assert CB.main(["disc", str(png), "--screen", "editor"]) == 0
        pj = _write(tmp_path, "pairs.json", _paris_pairs_doc())
        assert CB.main(["check", str(pj), "--screen", "editor", "--size", "2560x1080"]) == 0
        cal = T.load_calibration("editor", 2560, 1080)
        assert cal.checked and cal.check_residual_px < 2.0


class TestEdgeEnds:
    """fix-round verify V1: the along-axis half - a map drawn off-centre inside the ring leaves a black cap at one end."""

    def test_a_black_cap_at_one_end_fails(self, tmp_path, cal_dir, capsys):
        import math
        from PIL import Image
        png = _screen_from_crop(LONDON, tmp_path, "shot.png")
        rec = _disc_record(LONDON)
        rec.save()
        im = Image.open(png).convert("RGB")
        px = im.load()
        a = T.aspect_of(LONDON["size_x_m"], LONDON["size_z_m"])
        e = T.frac_to_minimap(0.5, 1.0, rec, a)
        L = math.hypot(e[0] - rec.cx, e[1] - rec.cy)
        ux, uy = (e[0] - rec.cx) / L, (e[1] - rec.cy) / L
        for o10 in range(-120, 121):                     # paint a 7 px black cap just inside the rim at the z=max end
            o = o10 / 10.0
            for d10 in range(int((rec.radius_px - 8) * 10), int((rec.radius_px - 1) * 10)):
                d = d10 / 10.0
                px[int(round(rec.cx + d * ux - o * uy)), int(round(rec.cy + d * uy + o * ux))] = (0, 0, 0)
        im.save(png)
        assert CB.main(["edges", str(png), "--screen", "editor", "--map", "zplondon", "--players", "4"]) == 1
        out = capsys.readouterr().out
        assert "short of the rim" in out and "FAIL" in out


class TestEdgesCli:
    """review F3: the icon-free check on the live editor frames (London 4p 2026-09-24, Paris 2026-09-20)."""

    @pytest.mark.parametrize("fix,players", [(LONDON, 4), (PARIS, 4)], ids=["london_live", "paris"])
    def test_edges_pass_and_are_stored(self, fix, players, tmp_path, cal_dir, capsys):
        png = _screen_from_crop(fix, tmp_path, "shot.png")
        _disc_record(fix).save()
        assert CB.main(["edges", str(png), "--screen", "editor", "--map", fix["map"], "--players", str(players)]) == 0
        out = capsys.readouterr().out
        assert "PASS" in out and "%gx%g m (engine" % (fix["size_x_m"], fix["size_z_m"]) in out
        cal = T.load_calibration("editor", 2560, 1080)
        assert cal.checked and [p["kind"] for p in cal.check_pairs] == ["edge", "edge", "end", "end"]
        assert all(p["ok"] for p in cal.check_pairs if p["kind"] == "end")      # the map reaches the rim at both ends
        for got, k in zip(cal.check_pairs, ("a", "b")):
            want = fix["edges"]["sides"][k]
            assert {kk: got[kk] for kk in want} == want
            assert CB.EDGE_INSET_MIN_PX <= got["inset_px"] <= CB.EDGE_INSET_MAX_PX
        assert abs(cal.check_residual_px - fix["edges"]["agree_px"] / 2) <= 0.001

    def test_live_frame_numbers(self):
        """The numbers the fixtures pin, against what the main session measured on the live frames (their scan used
        the script sizes: model half-widths 68.59 / 71.94 px)."""
        lon, par = LONDON["edges"], PARIS["edges"]
        assert [lon["sides"][k]["inset_px"] for k in "ab"] == [1.309, 1.309] and lon["agree_px"] == 0.0
        assert [par["sides"][k]["inset_px"] for k in "ab"] == [1.591, 2.072] and par["agree_px"] == 0.481
        assert lon["main_session_scan"]["measured_px"] == [66.83, 66.83]
        assert par["main_session_scan"]["measured_px"] == [70.19, 70.69]

    def test_wrong_player_count_fails_and_revokes(self, tmp_path, cal_dir, capsys):
        """London read at the 2-player size (646 m): both insets 5.55 px - FAIL, and the earlier pass is revoked."""
        png = _screen_from_crop(LONDON, tmp_path, "shot.png")
        _disc_record(LONDON).save()
        assert CB.main(["edges", str(png), "--screen", "editor", "--map", "zplondon", "--players", "4"]) == 0
        assert CB.main(["edges", str(png), "--screen", "editor", "--map", "zplondon", "--players", "2"]) == 1
        out = capsys.readouterr().out
        assert "inset 5.55 px outside" in out and "REVOKED" in out
        assert not T.load_calibration("editor", 2560, 1080, require_checked=False).checked

    @pytest.mark.parametrize("change,why", [({"radius_px": 128.0}, "outside"), ({"cx": 2270.83, "cy": 918.83}, "disagree")],
                             ids=["scale", "centre"])
    def test_a_wrong_record_fails(self, change, why, tmp_path, cal_dir, capsys):
        """A rim 2.5 px small (scale) or the centre 2.1 px off across the strip: the check fails, nothing written."""
        png = _screen_from_crop(LONDON, tmp_path, "shot.png")
        rec = _disc_record(LONDON)
        for k, v in change.items():
            setattr(rec, k, v)
        p = rec.save()
        before = p.read_bytes()
        assert CB.main(["edges", str(png), "--screen", "editor", "--map", "zplondon", "--players", "4"]) == 1
        out = capsys.readouterr().out
        assert "FAIL" in out and why in out and p.read_bytes() == before

    def test_square_map_is_refused(self, tmp_path, cal_dir, capsys):
        png = _screen_from_crop(PARIS, tmp_path, "shot.png")
        _disc_record(PARIS).save()
        assert CB.main(["edges", str(png), "--screen", "editor", "--map", "zpelbe", "--players", "4"]) == 2
        assert "square" in capsys.readouterr().out

    def test_dimmed_frame_is_refused(self, tmp_path, cal_dir, capsys):
        png = _screen_from_crop(LONDON, tmp_path, "dim.png", dim=0.63)
        rec = _disc_record(LONDON)
        from scripts.mapview import minimap_detect as MD
        rec.probes = MD.measure_disc(_screen_from_crop(LONDON, tmp_path, "shot.png")).probes
        rec.save()
        assert CB.main(["edges", str(png), "--screen", "editor", "--map", "zplondon", "--players", "4"]) == 1
        assert "ring probes match" in capsys.readouterr().out

    def test_no_record(self, tmp_path, cal_dir, capsys):
        png = _screen_from_crop(LONDON, tmp_path, "shot.png")
        assert CB.main(["edges", str(png), "--screen", "editor", "--map", "zplondon", "--players", "4"]) == 1
        assert "no calibration" in capsys.readouterr().out


class TestStarsAndBlobsCli:
    @pytest.mark.parametrize("fix", [PARIS, LONDON], ids=["paris", "london_live"])
    def test_stars_prints_the_four_explorer_stars(self, fix, tmp_path, capsys):
        png = _screen_from_crop(fix, tmp_path, "shot.png")
        args = ["stars", str(png)]
        for s in fix["stars"]:
            args += ["--colour", ",".join(str(v) for v in s["player_colour"])]
        assert CB.main(args) == 0
        out = capsys.readouterr().out
        for s in fix["stars"]:
            assert "star at (%.2f, %.2f)" % (s["star_px"], s["star_py"]) in out

    def test_blobs_needs_a_colour(self, tmp_path):
        with pytest.raises(SystemExit):
            CB.main(["blobs", "x.png"])

    def test_blobs_clamps_and_warns_on_zero(self, tmp_path, capsys):
        """review F5/F9: a box past the image edge is clamped (no IndexError); zero blobs warn."""
        Image = pytest.importorskip("PIL.Image")
        im = Image.new("RGB", (40, 30), (0, 0, 0))
        p = tmp_path / "tiny.png"
        im.save(p)
        assert CB.main(["blobs", str(p), "--colour", "0,0,255", "--box", "0,0,400,300", "--no-disc"]) == 0
        err = capsys.readouterr().err
        assert "clamped" in err and "zero blobs" in err
