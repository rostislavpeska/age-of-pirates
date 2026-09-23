"""Offline tests of the AI test campaign (docs/briefs/2026-09-23-london-ai-test-report.md).

    python -m pytest scripts/aitest/tests -q

The criteria scripts on synthetic per-player records, static guards on the AI files (the campaign's globals, the
echo-only diagnostic, London-only code, CRLF) and the driver's input structs. No game needed.
"""
import os
import re
import sys

import pytest

HERE = os.path.dirname(os.path.abspath(__file__))
AITEST = os.path.dirname(HERE)
ROOT = os.path.normpath(os.path.join(AITEST, "..", ".."))
CORE = os.path.join(ROOT, "game", "ai", "core")
sys.path.insert(0, AITEST)

import criteria_baseline  # noqa: E402
import criteria_london  # noqa: E402


def core(name):
    return open(os.path.join(CORE, name), "rb").read().decode("utf-8", errors="replace")


def write_record(tmp_path, player, lines, glue=False):
    """A per-player file as the game writes it: UTF-16 with BOM; glue=True drops the newline after BuildPlan echoes."""
    text = ""
    for l in lines:
        text += l + ("" if glue and "BuildPlan" in l else "\n")
    (tmp_path / ("Age3DEAIOutputPlayer%d.txt" % player)).write_bytes(b"\xff\xfe" + text.encode("utf-16-le"))


def diag(t, p=2, age=1, vills=20, fails=0, london=0):
    m, s = divmod(t, 60)
    return ("00:%02d:%02d  (%d): AIDIAG p%d age %d score 1000 vills %d army 5 navy 0 tcs 1 houses 3 milbldg 1 farms 0"
            " plant 0 bldg 9 baseR 40.000000 fails %d failsTC 0 london %d" % (m, s, t * 1000, p, age, vills, fails, london))


# ---- criteria_london -------------------------------------------------------------------------------------------

class TestLondonLoader:
    def test_glued_engine_echo_is_split_at_the_stamp(self, tmp_path):
        write_record(tmp_path, 2, ["00:04:03  (1): BuildPlan(57: X : 57): failing because nope.",
                                   "00:04:11  (2): LONDONDIAG p2 pass 4"], glue=True)
        lines = criteria_london.load(str(tmp_path))[2]
        assert len(lines) == 2
        assert criteria_london.gtime(lines[1]) == 251

    def test_empty_human_file_is_ignored(self, tmp_path):
        (tmp_path / "Age3DEAIOutputPlayer1.txt").write_bytes(b"")
        write_record(tmp_path, 2, ["00:00:00  (0): Main is starting"])
        assert sorted(criteria_london.load(str(tmp_path))) == [2]


def london_record():
    L = ["00:00:00  (0): Main is starting", "00:00:01  (1): LONDON p2 build r3 x",
         "00:00:11  (1): LONDONSETUP p2 marker 1/2 socket 223 gates 232 207 ours 232 keepNear 1764 keepFar 1049"
         " pathNear 1 pathFar 1 gates found 2 keeps found 2 tc 9",
         "00:00:21  (1): LONDONWAR p2 held - crossing closed"]
    for k in range(1, 9):
        L.append("00:%02d:11  (1): LONDONDIAG p2 pass %d" % (k, k))
    L += ["00:08:15  (1): LONDONGATE p2 gate 1744 down kind nearKeep",
          "00:09:12  (1): LONDONKEEP p2 flag ours keep 1764 near",
          "00:09:12  (1): LONDONHOLD p2 6 holding keep 1764 near",
          "00:09:42  (1): LONDONHOLD p2 6 holding keep 1764 near",
          "00:10:12  (1): LONDONHOLD p2 6 holding keep 1764 near",
          "00:10:13  (1): LONDONWAR p2 released - crossing open"]
    return sorted(L, key=criteria_london.gtime)


class TestLondonCriteria:
    def verdicts(self, lines):
        return {r[0]: r[2] for r in criteria_london.evaluate({2: lines})}

    def test_a_complete_round_three_record_passes(self):
        v = self.verdicts(london_record())
        assert all(v[k] == "PASS" for k in ("L0", "L1", "L2", "L3", "L4", "L5", "L6", "L7", "L8", "U2")), v

    def test_release_before_hold_fails_l4(self):
        L = [l for l in london_record() if "held" not in l]
        assert self.verdicts(L)["L4"] == "FAIL"

    def test_task_on_a_skipped_target_in_the_same_pass_fails_l6(self):
        L = london_record() + ["00:05:00  (1): LONDONGATE p2 skip 5 unreachable",
                               "00:05:00  (1): LONDONGATE p2 tasked 8 on 5 nearKeep"]
        assert self.verdicts(L)["L6"] == "FAIL"

    def test_a_garrison_below_three_fails_l8(self):
        L = [l.replace("6 holding", "2 holding") for l in london_record()]
        assert self.verdicts(L)["L8"] == "FAIL"

    def test_round_two_ids_are_skipped_on_a_round_one_build(self):
        L = [l.replace("build r3", "build r1") for l in london_record()]
        assert "L4" not in self.verdicts(L)


# ---- criteria_baseline -----------------------------------------------------------------------------------------

class TestBaseline:
    def floor(self):
        rows = [diag(t, vills=10 + t // 60, age=min(3, t // 400), fails=t // 300) for t in range(60, 1260, 60)]
        return criteria_baseline.metrics({2: rows})[0]

    def test_the_floor_itself_passes(self):
        rows = [diag(t, vills=10 + t // 60, age=min(3, t // 400), fails=t // 300) for t in range(60, 1260, 60)]
        res, _ = criteria_baseline.evaluate({2: rows}, self.floor())
        assert all(r[2] == "PASS" for r in res), res

    def test_a_london_flag_on_a_standard_map_is_a_hard_fail(self):
        rows = [diag(t, london=1) for t in range(60, 600, 60)]
        res, _ = criteria_baseline.evaluate({2: rows})
        assert dict((r[0], r[2]) for r in res)["B5"] == "FAIL"

    def test_an_early_stall_fails_b1(self):
        rows = [diag(t) for t in range(60, 400, 60)]
        res, _ = criteria_baseline.evaluate({2: rows}, self.floor())
        assert dict((r[0], r[2]) for r in res)["B1"] == "FAIL"

    def test_failure_spam_fails_b4(self):
        rows = [diag(t, vills=40, age=3, fails=t) for t in range(60, 1260, 60)]
        res, _ = criteria_baseline.evaluate({2: rows}, self.floor())
        assert dict((r[0], r[2]) for r in res)["B4"] == "FAIL"

    def test_a_player_without_aidiag_fails_b0(self):
        res, _ = criteria_baseline.evaluate({2: [diag(60)], 3: ["00:00:00  (0): Main is starting"]})
        assert dict((r[0], r[2]) for r in res)["B0"] == "FAIL"


# ---- static guards on the AI files -----------------------------------------------------------------------------

def declarations(name):
    decl = re.compile(r"^\s*extern\s+\w+\s+(\w+)\s*=", re.M)
    out = {}
    for f in os.listdir(CORE):
        if f.endswith(".xs"):
            for n in decl.findall(core(f)):
                out.setdefault(n, []).append(f)
    return out.get(name, [])


class TestAIFiles:
    @pytest.mark.parametrize("name", ["gAITestDiag", "gPlacementFailures", "gPlacementFailuresTC", "gIsLondon"])
    def test_campaign_globals_are_declared_once_in_aiglobals(self, name):
        assert declarations(name) == ["aiglobals.xs"]

    def test_the_diag_is_echo_only(self):
        s = core("aipiraterules.xs")
        body = s[s.index("rule aiTestDiag"):]
        body = body[:body.index("\n}") + 2]
        for forbidden in ("aiPlanCreate", "aiTask", "aiPlanAdd", "xsEnableRule", "xsDisableRule", "aiPlanSet"):
            assert forbidden not in body, forbidden
        assigned = set(re.findall(r"^\s*(\w+)\s*=", body, re.M))
        assert assigned <= {"baseRadius", "london"}, assigned

    def test_the_diag_is_enabled_only_through_its_flag(self):
        s = core("aipiraterules.xs")
        i = s.index('xsEnableRule("aiTestDiag")')
        assert "gAITestDiag == true" in s[i - 120:i]
        assert s.count('xsEnableRule("aiTestDiag")') == 1

    def test_the_failure_counter_is_the_handlers_first_statement(self):
        s = core("aibuildings.xs")
        i = s.index("void buildingPlacementFailedHandler(")
        first = s[s.index("{", i) + 1:].strip().splitlines()[0]
        assert first.startswith("gPlacementFailures = gPlacementFailures + 1;")

    @pytest.mark.parametrize("name", ["aiglobals.xs", "aibuildings.xs", "aipiraterules.xs"])
    def test_ai_files_are_crlf(self, name):
        b = open(os.path.join(CORE, name), "rb").read()
        assert b.count(b"\n") == b.count(b"\r\n")


# ---- driver ----------------------------------------------------------------------------------------------------

@pytest.mark.skipif(sys.platform != "win32", reason="the driver drives Windows input")
class TestDriverInput:
    def test_keyboard_input_struct_is_the_full_input_size(self):
        import ctypes
        import driver
        # SendInput silently drops a keyboard-only INPUT (2026-09-23: every typed key and Escape were lost)
        assert ctypes.sizeof(driver.KINPUT) == ctypes.sizeof(driver.INPUT) == (40 if ctypes.sizeof(ctypes.c_void_p) == 8 else 28)

    def test_select_map_needs_its_sheet_points(self):
        import json
        sheet = json.load(open(os.path.join(AITEST, "coords", "2880x1800_default.json")))
        for k in ("lobby_mapbutton", "picker_search", "picker_first", "picker_ok", "lobby_probe", "postmatch_quit"):
            assert k in sheet, k
