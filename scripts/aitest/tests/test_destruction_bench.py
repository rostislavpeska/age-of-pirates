"""Offline tests of the destruction bench (scripts/aitest/destruction_bench.py, docs/briefs/2026-09-28-destruction-bench-plan.md).

    python -m pytest scripts/aitest/tests/test_destruction_bench.py -q

The generated map (spine, trigger wiring, gates), the marker parser against OCR noise, and the sheet builder on a
synthetic run. No game needed.
"""
import json
import os
import re
import subprocess
import sys
from pathlib import Path

import pytest

AITEST = Path(__file__).resolve().parents[1]
ROOT = AITEST.parents[1]
sys.path.insert(0, str(AITEST))

import destruction_bench as B  # noqa: E402

SUBJECT = "zpKoreanTownCenterTest"


def rendered(damage="both"):
    return B.render("000000_destrbench_t", "DESTRBENCH T", SUBJECT, damage)


class TestGeneratedMap:
    def test_spine_is_unitbench_s_frozen_one(self):
        xs, _, _ = rendered()
        for line in ('include "mercenaries.xs";', 'include "ypAsianInclude.xs";', 'include "ypKOTHInclude.xs";',
                     "void main(void)", "rmSetMapSize(200, 200);", "rmSetSeaLevel(0.0);", "rmSetBaseTerrainMix(",
                     "rmTerrainInitialize(", 'rmSetMapType("arabia");', "chooseMercs();", "rmPlacePlayersCircular(",
                     'rmAddObjectDefItem(tcID, "TownCenter", 1, 0.0);', "rmPlaceObjectDefAtLoc(tcID, i,"):
            assert line in xs, line

    def test_the_subject_owns_player_1_s_start_location(self):
        xs, _, _ = rendered()
        assert xs.index("rmPlacePlayersCircular(") < xs.index("rmPlacePlayer(1, 0.5, 0.5);")
        assert f'rmAddObjectDefItem(subjectDef, "{SUBJECT}", 1, 0.0);' in xs
        assert "rmPlaceObjectDefAtLoc(subjectDef, 1, 0.5, 0.5);" in xs
        assert "for(i=2; <= cNumberNonGaiaPlayers)" in xs          # no ordinary Town Center on the subject's spot
        assert 'rmAddObjectDefItem(keeperDef, "Settler", 1, 0.0);' in xs

    def test_no_placeholder_or_python_leftovers(self):
        for damage in ("both", "steps", "artillery"):
            xs, xml, _ = rendered(damage)
            assert not re.search(r"\{[A-Z_]+\}", xs + xml)
            assert "None" not in xs and "True" not in xs and "False" not in xs

    def test_every_trigger_is_created_once_filled_once_and_every_event_resolves(self):
        xs, _, trigs = rendered()
        names = [t.name for t in trigs]
        assert len(names) == len(set(names))
        created = re.findall(r'rmCreateTrigger\("([^"]+)"\);', xs)
        switched = re.findall(r'rmSwitchToTrigger\(rmTriggerID\("([^"]+)"\)\);', xs)
        assert sorted(created) == sorted(names) == sorted(switched)
        assert all(" " not in n for n in names)                     # rm-triggers law 3 cannot bite
        last_create = max(xs.index(f'rmCreateTrigger("{n}");') for n in names)
        first_switch = min(xs.index(f'rmSwitchToTrigger(rmTriggerID("{n}"));') for n in names)
        assert last_create < first_switch                          # every Fire Event lookup finds its target
        for target in re.findall(r'ParamInt\("EventID", rmTriggerID\("([^"]+)"\)\)', xs):
            assert target in names, target

    def test_one_gated_family_per_candidate_shift(self):
        xs, _, trigs = rendered()
        gates = [t for t in trigs if t.name.startswith("DB_Gate")]
        assert [g.name for g in gates] == [f"DB_Gate{s}" for s in B.SHIFTS]
        for s in B.SHIFTS:
            body = "\n".join(next(t for t in trigs if t.name == f"DB_Gate{s}").body())
            assert f'rmSetTriggerConditionParam("DstObject", ""+(dbTC+{s}));' in body
            assert f'rmSetTriggerConditionParam("UnitType", "{SUBJECT}");' in body
            assert f'rmTriggerID("DB_Setup{s}")' in body
            setup = "\n".join(next(t for t in trigs if t.name == f"DB_Setup{s}").body())
            assert "rmSetTriggerActive(false);" in setup
            assert setup.count('rmAddTriggerEffect("Unit Action Suspend");') == 3
            assert f"ZPMARK START S{s}" in setup

    def test_markers_and_the_index_free_death(self):
        xs, _, _ = rendered()
        for label in ("HP75", "HP50", "HP25", "DEAD", "PLUS5", "PLUS15", "END"):
            assert f"<font=largeingame 30>ZPMARK {label}" in xs and f'"ZPMARK {label}"' in xs
        dead = xs[xs.index('rmSwitchToTrigger(rmTriggerID("DB_Dead"));'):]
        dead = dead[:dead.index("rmSetTriggerLoop")]
        assert 'rmAddTriggerCondition("Player Unit Count");' in dead and "dbTC" not in dead

    def test_damage_modes(self):
        xs_steps, _, t_steps = rendered("steps")
        assert "rmAddObjectDefItem(mortarDef" not in xs_steps and not any("Art" in t.name for t in t_steps)
        assert xs_steps.count('rmAddTriggerEffect("Damage Unit");') == 4 * len(B.SHIFTS)
        xs_both, _, t_both = rendered("both")
        assert xs_both.count('rmAddObjectDefItem(mortarDef') == 2
        step1 = "\n".join(next(t for t in t_both if t.name == "DB_Step1_0").body())
        assert '"Percent Damaged"' in step1 and 'rmSetTriggerConditionParamInt("Percent", 25);' in step1
        assert 'rmSetTriggerEffectParamFloat("DamageAmt", 1625.0);' in step1
        xs_art, _, t_art = rendered("artillery")
        assert not any("Step" in t.name for t in t_art) and any(t.name == "DB_Art1_0" for t in t_art)

    def test_scope_check_passes(self, tmp_path):
        xs, xml, _ = rendered()
        p = tmp_path / "000000_destrbench_t.xs"
        B.write_crlf(p, xs)
        assert p.read_bytes().count(b"\r\n") == p.read_bytes().count(b"\n")
        if B.newest_rm_dump() is None:
            pytest.skip("no RM dump on this device: S6 needs the engine's builtin catalogue")
        rc, msg = B.scope_check(p)
        assert rc == 0, msg

    def test_gen_refuses_the_mod_folder(self, capsys):
        with pytest.raises(SystemExit):
            B.main(["gen", "--proto", SUBJECT, "--tag", "t", "--out", str(ROOT / "randmaps"), "--no-preflight"])


class TestScreenAccess:
    def test_input_desktop_is_named(self):
        """The harness stops on anything but 'Default' (a screen saver hid the game on 2026-09-28)."""
        name = B.input_desktop()
        assert isinstance(name, str) and name

    def test_run_stops_before_touching_anything_when_the_screen_is_hidden(self, tmp_path, monkeypatch):
        monkeypatch.setattr(B, "input_desktop", lambda: "Screen-saver")
        meta = tmp_path / "000000_destrbench_t.bench.json"
        meta.write_text(json.dumps({"stem": "000000_destrbench_t", "title": "DESTRBENCH T"}), encoding="utf-8")
        monkeypatch.setattr(B, "STEAM_RANDMAPS", tmp_path)
        assert B.main(["run", "--tag", "t", "--out", str(tmp_path / "out")]) == 7
        run = json.loads(next((tmp_path / "out").glob("*_t/run.json")).read_text(encoding="utf-8"))
        assert "Screen-saver" in run["events"][0][1]


class TestMarkerParser:
    @pytest.mark.parametrize("text,want", [
        ("Gaia: ZPMARK HP75", "HP75"), ("ZP MARK HP 50", "HP50"), ("ZPMARK HP2S", "HP25"), ("ZPMARK DEAD", "DEAD"),
        ("ZPMARK PLUS15", "PLUS15"), ("ZPMARK PLUSI5", "PLUS15"), ("ZPMARK PLUS5", "PLUS5"), ("ZPMARK END", "END"),
        ("2PMARK START S3", "START"), ("ZPMARK ST4RT S0", None),
    ])
    def test_tokens(self, text, want):
        found, _ = B.parse_markers([text])
        assert found == ({want} if want else set())

    def test_plus5_is_not_read_inside_plus15(self):
        assert B.parse_markers(["ZPMARK PLUS15"])[0] == {"PLUS15"}

    def test_clock(self):
        assert B.parse_markers(["ZPCLOCK 14:37"])[1] == 900 - (14 * 60 + 37)
        assert B.parse_markers(["ZPCL0CK 9 : 58"])[1] == 900 - (9 * 60 + 58)

    @pytest.mark.parametrize("text,shift", [("ZPMARK START S3", 3), ("ZPMARK START 3", 3), ("ZPMARK START S5", 5),
                                            ("ZPMARK START 5", 5), ("ZPMARK START", None)])
    def test_shift(self, text, shift):
        assert B.parse_shift(text) == shift


class TestSheet:
    def test_sheet_from_a_synthetic_run(self, tmp_path):
        from PIL import Image
        rd = tmp_path / "run_k"
        (rd / "frames").mkdir(parents=True)
        frames, markers = [], {}
        for i in range(1, 41):
            f = f"f{i:05d}.jpg"
            Image.new("RGB", (400, 250), (i * 5, 80, 40)).save(rd / "frames" / f)
            frames.append({"n": i, "file": f, "t": 1000.0 + i, "sim": None, "markers": []})
        for k, m in enumerate(B.MARKERS):
            markers[m] = {"t": 1000.0 + 3 + k * 4, "frame": f"f{3 + k * 4:05d}.jpg", "sim": None, "text": ""}
        Image.new("RGB", (400, 250), (200, 200, 200)).save(rd / "close_intact_1.jpg")
        (rd / "run.json").write_text(json.dumps({"tag": "korean", "frames": frames, "markers": markers}), encoding="utf-8")
        out = tmp_path / "sheet"
        assert B.main(["sheet", str(rd), "--out", str(out)]) == 0
        assert (out / "contact_sheet.jpg").exists()
        assert len(list((out / "keyframes").glob("korean_*.jpg"))) == len(B.SHEET_COLS) - 1   # no close_final

    def test_sheet_refuses_the_repo(self, tmp_path):
        with pytest.raises(SystemExit):
            B.main(["sheet", str(tmp_path), "--out", str(ROOT / "docs" / "x")])
