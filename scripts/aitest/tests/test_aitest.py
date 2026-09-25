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

    def test_a_keep_lost_longer_than_300_s_fails_l8(self):
        L = london_record() + ["00:11:00  (1): LONDONHOLD p2 6 retaking keep 1764 near owner 5",
                               "00:17:00  (1): LONDONHOLD p2 6 holding keep 1764 near owner 2"]
        assert self.verdicts(sorted(L, key=criteria_london.gtime))["L8"] == "FAIL"

    def test_a_keep_retaken_within_300_s_passes_l8(self):
        L = london_record() + ["00:11:00  (1): LONDONHOLD p2 6 retaking keep 1764 near owner 5",
                               "00:14:00  (1): LONDONHOLD p2 6 holding keep 1764 near owner 2"]
        assert self.verdicts(sorted(L, key=criteria_london.gtime))["L8"] == "PASS"

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
    @pytest.mark.parametrize("name", ["gAITestDiag", "gPlacementFailures", "gPlacementFailuresTC", "gPlacementFailuresDock", "gIsLondon",
                                      "gLondonWarState", "gPirateForwardBaseMap"])
    def test_campaign_globals_are_declared_once_in_aipiraterules(self, name):
        # isolation (owner 2026-09-24): no mod global in aiglobals.xs
        assert declarations(name) == ["aipiraterules.xs"]

    def test_the_diag_is_echo_only(self):
        s = core("aipiraterules.xs")
        body = s[s.index("rule aiTestDiag"):]
        body = body[:body.index("\n}") + 2]
        for forbidden in ("aiPlanCreate", "aiTask", "aiPlanAdd", "xsEnableRule", "xsDisableRule", "aiPlanSet"):
            assert forbidden not in body, forbidden
        assigned = set(re.findall(r"^\s*(\w+)\s*=", body, re.M))
        assert assigned <= {"baseRadius", "london", "dockState", "navyMap", "fishMap"}, assigned
        assert "cUnitTypeTradingPost" in body   # T1 reads the tps field

    def test_the_diag_is_enabled_only_through_its_flag(self):
        s = core("aipiraterules.xs")
        i = s.index('xsEnableRule("aiTestDiag")')
        assert "gAITestDiag == true" in s[i - 120:i]
        assert s.count('xsEnableRule("aiTestDiag")') == 1

    @pytest.mark.parametrize("h", ["aiTestPlacementFailedHandler", "londonBuildingPlacementFailedHandler"])
    def test_the_failure_counter_is_the_handlers_first_statement(self, h):
        s = core("aipiraterules.xs")
        i = s.index("void %s(" % h)
        first = s[s.index("{", i) + 1:].strip().splitlines()[0]
        assert first.startswith("gPlacementFailures = gPlacementFailures + 1;")

    def test_the_handlers_are_registered_from_the_pirate_rules(self):
        s = core("aipiraterules.xs")
        assert 'aiSetHandler("aiTestPlacementFailedHandler", cXSBuildingPlacementFailedHandler)' in s
        assert 'aiSetHandler("londonBuildingPlacementFailedHandler", cXSBuildingPlacementFailedHandler)' in s

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
        for k in ("lobby_mapbutton", "picker_search", "picker_first", "picker_ok", "lobby_probe", "postmatch_quit",
                  "menu_live_probe", "menu_post_probe"):
            assert k in sheet, k


# ---- round 4: London-only placement ----------------------------------------------------------------------------

def enclosing_headers(lines, i):
    """The block headers (the line before each '{') enclosing line i, innermost first."""
    heads, depth = [], 0
    for j in range(i - 1, -1, -1):
        depth += lines[j].count("}") - lines[j].count("{")
        if depth < 0:
            k = j if lines[j].strip() != "{" else j - 1
            heads.append(lines[k].strip())
            depth = 0
    return heads


BASELINE = "0b2c6aab"   # AI: adopt the Christmas-Release core (2026-09-11) - the stock core every mod path starts from


def _git_show(rev, path):
    import subprocess
    r = subprocess.run(["git", "show", "%s:%s" % (rev, path)], cwd=ROOT, capture_output=True)
    return r.stdout if r.returncode == 0 else None


class TestIsolation:
    """Owner 2026-09-24: 'completely isolated - one line in aiglobals max'. Mod AI lives only in aipiraterules.xs;
    every other core file is the adopted core byte for byte (Istanbul's pattern: switch stock rules off, run copies)."""

    STOCK = sorted(f for f in os.listdir(CORE) if f.endswith(".xs") and f != "aipiraterules.xs")

    @pytest.mark.parametrize("name", STOCK)
    def test_stock_file_is_the_adopted_core(self, name):
        base = _git_show(BASELINE, "game/ai/core/" + name)
        if base is None:
            pytest.skip("git or the baseline commit is not available")
        now = open(os.path.join(CORE, name), "rb").read().replace(b"\r\n", b"\n")   # git stores LF; CRLF is tested apart
        base = base.replace(b"\r\n", b"\n")
        if name == "aiglobals.xs":   # the one allowed line
            a, b = base.splitlines(), now.splitlines()
            extra = [l for l in b if l not in a]
            assert len(b) - len(a) <= 1 and len(extra) <= 1 and all(l in b for l in a), extra
        else:
            assert now == base, "%s differs from %s - mod AI goes into aipiraterules.xs" % (name, BASELINE)

    @pytest.mark.parametrize("name", STOCK)
    def test_no_mod_map_name_outside_the_pirate_rules(self, name):
        assert not re.search(r"london|zpparis", core(name), re.I), name


class TestLondonOnlyPlacement:
    HELPERS = {"londonCountrysidePoint": "gIsLondon == false", "londonFieldPoint": "gIsLondon == false",
               "londonSelectFieldPosition": "gIsLondon == false", "pirateForwardBasePoint": "gPirateForwardBaseMap == false"}

    @pytest.mark.parametrize("h", sorted(HELPERS))
    def test_helpers_return_at_once_off_their_map(self, h):
        s = core("aipiraterules.xs")
        m = re.search(r"^(?:bool|vector|int|void)\s+%s\(" % h, s, re.M)
        assert m, h
        body = s[m.end():]
        first_if = body[body.index("{") + 1:].split("if (", 1)[1].split(")", 1)[0]
        assert first_if == self.HELPERS[h], (h, first_if)

    def test_detection_is_by_the_players_own_marker_unit(self):
        # owner 2026-09-24: 'all unit based' - London by its bridge marker, the forward base by the construction markers
        s = core("aipiraterules.xs")
        assert "if (kbUnitCount(cMyID, cUnitTypezpAILondonBridge, cUnitStateAny) > 0)" in s
        assert "if (kbUnitCount(cMyID, cUnitTypezpAILondonConstrMarker, cUnitStateAny) > 0)" in s
        assert not re.search(r'cRandomMapName == "(00000_)?zp(london|paris)"', s)

    def test_the_forward_base_copies_differ_from_stock_only_in_the_location(self):
        s = core("aipiraterules.xs")
        for rule, src, extra in (("forwardBaseManager", "aibuildings.xs", {"forwardTowerBaseManager();"}),
                                 ("forwardTowerBaseManager", "aiassertivewall.xs", set())):
            def body(text, name):
                i = text.index("rule %s\r\n" % name)
                return text[i:text.index("\r\n}\r\n", i)].split("\r\n")[1:]
            a, b = body(core(src), rule), body(s, "pirate" + rule[0].upper() + rule[1:])
            assert len(a) == len(b), rule
            diff = [(x.strip(), y.strip()) for x, y in zip(a, b) if x != y]
            allowed = {("location = selectForwardBaseLocation();", "location = pirateForwardBasePoint();"),
                       ("location = selectForwardBaseBeachHead();", "location = pirateForwardBeachHead();"),
                       ("forwardTowerBaseManager();", "pirateForwardTowerBaseManager();")}
            assert set(diff) <= allowed, (rule, diff)

    def test_build_echo_is_round_thirteen(self):
        assert "build r13 2026-09-25" in core("aipiraterules.xs")

    def test_istanbul_places_the_construction_markers_on_both_landing_beaches(self):
        # owner 2026-09-25: the forward base next to the Fisherman's guild - after every placement, before UNIT IDS
        s = open(os.path.join(ROOT, "randmaps", "zpistanbulb.xs"), "rb").read().decode("utf-8")
        i = s.index('rmAddObjectDefItem(constrMark, "zpAILondonConstrMarker"')
        assert i < s.index("//  UNIT IDS - every id a trigger targets")
        assert "rmPlaceObjectDefAtLoc(constrMark, cm, beachDockNX, beachDockNZ);" in s
        assert "rmPlaceObjectDefAtLoc(constrMark, cm, beachDockSX, beachDockSZ);" in s


def diag4(t, p=2, baseR=40.0, fails=0, farms=0, plant=0, london=1):
    m, s = divmod(t, 60)
    return ("00:%02d:%02d  (%d): AIDIAG p%d age 2 score 1000 vills 30 army 5 navy 0 tcs 1 houses 3 milbldg 1 farms %d"
            " plant %d bldg 9 baseR %.6f fails %d failsTC 0 london %d" % (m, s, t * 1000, p, farms, plant, baseR, fails, london))


class TestRoundFourCriteria:
    def record(self, **kw):
        L = [l.replace("build r3", "build r4") for l in london_record()]
        L += [diag4(t, **kw) for t in range(60, 1560, 60)]
        L += ["00:12:00  (1): LONDONPLACE p2 field Mill plan 5 at the countryside 1/2"]
        return sorted(L, key=criteria_london.gtime)

    def verdicts(self, L):
        return {r[0]: r[2] for r in criteria_london.evaluate({2: L})}

    def test_a_growing_base_with_fields_passes(self):
        v = self.verdicts(self.record(baseR=80.0, fails=3, farms=2))
        assert (v["P0"], v["P1"], v["P3"]) == ("PASS",) * 3, v

    def test_a_frozen_base_fails_p1(self):
        assert self.verdicts(self.record(baseR=40.0, farms=2))["P1"] == "FAIL"

    def test_p2_is_info_only_until_the_owner_sets_a_bound(self):
        assert self.verdicts(self.record(baseR=80.0, fails=40, farms=2))["P2"] == "N/A"

    def test_no_eco_building_fails_p3(self):
        assert self.verdicts(self.record(baseR=80.0))["P3"] == "FAIL"

    def test_london_flag_off_fails_p0(self):
        assert self.verdicts(self.record(baseR=80.0, farms=2, london=0))["P0"] == "FAIL"


def test_home_probe_needs_a_second_pixel():
    # the in-match terrain under the Skirmish button matched the single home pixel (run 18): two pixels now
    import json
    sheet = json.load(open(os.path.join(AITEST, "coords", "2880x1800_default.json")))
    assert "also" in sheet["home_skirmish"]


# ---- XS syntax lint: constructs the engine's parser rejected in game (each one cost a run) ----------------------

def xs_conditions(text):
    """(line number, condition text) of every if / while condition, the parentheses matched."""
    for m in re.finditer(r"\b(?:if|while)\s*\(", text):
        i, depth = m.end(), 1
        while i < len(text) and depth:
            depth += {"(": 1, ")": -1}.get(text[i], 0)
            i += 1
        yield text[:m.start()].count("\n") + 1, text[m.end():i - 1]


def suspect_group_product_compare(cond):
    """True for the shape the engine rejected in run 19 (2026-09-23), aibuildings.xs(883):
        if ((xsVectorGetZ(g) - xsVectorGetZ(b)) * side < (xsVectorGetZ(t) - xsVectorGetZ(b)) * side + 20.0)
    -> XS Error 0308 illogical or invalid expression / 0135 parseConditionDecl failed; every AI player dead.
    The exact trigger is NOT isolated: the stock core compiles '(a - b) * f(x) >= g(y)' (aieconomy.xs 1609) and
    '(a + b) < (c * d)' (aiassertivewall.xs 11130). Flagged: a parenthesised group that contains a call, multiplied by
    a bare identifier, then compared - the rejected line's shape, which the stock core never uses. Plain steps into
    locals are the safe form."""
    group = r"\((?:[^()]|\([^()]*\))*\w\([^()]*\)(?:[^()]|\([^()]*\))*\)"   # a group holding a call, one nesting level
    return re.search(group + r"\s*\*\s*[A-Za-z_]\w*\s*[<>]", cond) is not None


@pytest.mark.parametrize("name", sorted(f for f in os.listdir(CORE) if f.endswith(".xs")))
def test_no_condition_has_the_run_19_rejected_shape(name):
    text = re.sub(r"//[^\n]*", "", core(name))
    bad = [(n, c.strip()[:90]) for n, c in xs_conditions(text) if suspect_group_product_compare(c)]
    assert not bad, bad


def test_the_lint_catches_the_run_19_line():
    assert suspect_group_product_compare("(xsVectorGetZ(a) - xsVectorGetZ(b)) * side < (xsVectorGetZ(c) - 1.0) * side + 20.0")
    assert not suspect_group_product_compare("(totalAmount - lastTotalGoldAmount) * xsArrayGetFloat(g, c) >= x")
    assert not suspect_group_product_compare("(friendlyStrength + allyStrength) < (enemyStrength * strengthFactor)")
    assert not suspect_group_product_compare("gateOff < tcOff")


# lint rules from the AOE3 AI scripting guide (references/ai-guide/docs/xs), kept only where the stock core complies
def _strip_comments(t):
    return re.sub(r"/\*.*?\*/", "", re.sub(r"//[^\n]*", "", t), flags=re.S)


def _core_files():
    return {f: _strip_comments(core(f)) for f in sorted(os.listdir(CORE)) if f.endswith(".xs")}


def _top_level_names(files):
    """{name: [(file, mutable)]} of every function DEFINITION (a body follows) and every rule."""
    import collections
    out = collections.defaultdict(list)
    for f, s in files.items():
        for m in re.finditer(r"^(mutable\s+)?(?:void|int|float|bool|vector|string)\s+(\w+)\s*\([^;{]*\)\s*\{", s, re.M):
            out[m.group(2)].append((f, bool(m.group(1))))
        for m in re.finditer(r"^rule\s+(\w+)", s, re.M):
            out[m.group(1)].append((f, False))
    return out


def test_no_name_is_defined_twice_without_a_mutable_stub():
    # functions.md 1.2: a name may not repeat a function / rule; the core's pattern is a 'mutable' stub in aicore.xs
    # overridden by the real body later
    bad = {k: v for k, v in _top_level_names(_core_files()).items() if len(v) > 1 and not any(mu for _, mu in v)}
    assert not bad, bad


def test_no_local_is_named_like_a_function_or_rule():
    # variables.md 2.1.2: a variable may not share a function's or rule's name (checked while writing londonWarPlan:
    # 'far', 'open'); the compile error kills every AI player
    files = _core_files()
    names = set(_top_level_names(files))
    bad = [(f, s[:m.start()].count("\n") + 1, m.group(1)) for f, s in files.items()
           for m in re.finditer(r"^\s+(?:static\s+)?(?:int|float|bool|vector|string)\s+(\w+)\s*[=;]", s, re.M)
           if m.group(1) in names]
    assert not bad, bad


def test_no_scalar_times_vector():
    # vectors.md 4.3: '2.0 * v' is an error, 'v * 2.0' is the form
    files = _core_files()
    vecs = set()
    for s in files.values():
        vecs |= set(re.findall(r"\bvector\s+(\w+)", s))
    bad = [(f, s[:m.start()].count("\n") + 1, m.group(0)) for f, s in files.items()
           for m in re.finditer(r"\b\d+(?:\.\d+)?\s*\*\s*(\w+)\b", s) if m.group(1) in vecs]
    assert not bad, bad


class TestRoundFiveCriteria:
    def base(self):
        return [l.replace("build r3", "build r5") for l in london_record()]

    def verdicts(self, L):
        return {r[0]: r[2] for r in criteria_london.evaluate({2: sorted(L, key=criteria_london.gtime)})}

    def test_no_forward_ask_is_not_applicable(self):
        assert self.verdicts(self.base())["P4"] == "N/A"

    def test_an_ask_with_few_failures_passes(self):
        L = self.base() + ["00:12:00  (1): LONDONPLACE p2 forward base next to the bridge at 1/2",
                           "00:12:30  (1): BuildPlan(9: Forward Tower build plan  : 9): failing because building placement failed with state (3)."]
        assert self.verdicts(L)["P4"] == "PASS"

    def test_repeated_forward_failures_fail(self):
        L = self.base() + ["00:12:00  (1): LONDONPLACE p2 forward base next to the bridge at 1/2"]
        L += ["00:13:%02d  (1): BuildPlan(9: Forward Tower build plan  : 9): failing because building placement failed with state (3)." % s
              for s in range(0, 50, 10)]
        assert self.verdicts(L)["P4"] == "FAIL"


# ---- GAMEPLAY-SCOPE GATE (owner 2026-09-24: "a heavy violation which should be prevented") ---------------------
# The night of 2026-09-23/24 shipped three London changes nobody approved: the stock Trading Post rule stopped
# claiming the bridge's port socket and every far-bank socket, towers moved to the (decorative) wall gates, and the
# forward base was switched off. They improved the failure metric by removing what the AI contests on the map.
# Rule: London code may live ONLY in the functions / rules listed here, each with the owner's approval. A new place
# fails this test; adding it to the list is the explicit approval step (docs/ai_scripting_guidelines.md rule 13).
APPROVED_LONDON_CODE = {
    # aipiraterules.xs - the plan 'docs/briefs/2026-09-23-london-ai-plan.md', owner 'Go' 2026-09-23 (rounds 1-3)
    ("aipiraterules.xs", "initializePirateRules"): "detection by the player's own marker unit - plan round 1",
    ("aipiraterules.xs", "londonSetup"): "plan round 1",
    ("aipiraterules.xs", "londonDiag"): "plan round 1 (test mode only)",
    ("aipiraterules.xs", "londonFarBridgeGate"): "plan round 2",
    ("aipiraterules.xs", "londonKeepGate"): "plan round 2",
    # owner 2026-09-24: 'fix the dead-end state ... eliminate the between states' (run 31, rebuilt bridge gate)
    ("aipiraterules.xs", "londonBlockingGate"): "gates found fresh, any owner, classified - no remembered ids",
    ("aipiraterules.xs", "londonGateTarget"): "plan round 2",
    ("aipiraterules.xs", "londonWarPlan"): "plan round 2",
    ("aipiraterules.xs", "londonGateKiller"): "plan round 2",
    ("aipiraterules.xs", "londonHoldKeep"): "plan round 3",
    ("aipiraterules.xs", "londonKeepHold"): "plan round 3",
    # owner 2026-09-24 (option 2: 'good, edit AI'): the army retakes our lost near Keep
    ("aipiraterules.xs", "londonKeepRetake"): "retake our enemy-held near Keep with the gate killer's reserve",
    ("aipiraterules.xs", "aiTestDiag"): "echo-only test diagnostic, owner baseline plan 2026-09-23",
    # owner 2026-09-23: 'AI can absolutely use the space behind the walls ... farms / plantations / mills / Folwarks';
    # moved from aibuildings.xs 2026-09-24 (owner: 'completely isolated')
    ("aipiraterules.xs", "londonCountrysidePoint"): "economic buildings behind the wall",
    ("aipiraterules.xs", "londonFieldPoint"): "economic buildings behind the wall, spread over the gates",
    ("aipiraterules.xs", "londonSelectFieldPosition"): "economic buildings behind the wall",
    ("aipiraterules.xs", "londonPlanPlacer"): "economic buildings + the Town Center fallback behind the wall",
    ("aipiraterules.xs", "londonBuildingPlacementFailedHandler"): "base growth over river / hills / countryside, 120 m cap",
    # owner 2026-09-24: 'can be also enemy bridgehead' + 'target the unique units instead of the map spot' +
    # 'let's try the same with Paris, ideally one rule ... ideally the other shore'
    ("aipiraterules.xs", "pirateForwardBasePoint"): "forward base at the enemy construction block (London once open, Paris)",
}


def _units_with_london_code():
    found = set()
    for f in sorted(os.listdir(CORE)):
        if not f.endswith(".xs"):
            continue
        t = _strip_comments(core(f))
        for m in re.finditer(r"^(?:mutable\s+)?(?:void|int|float|bool|vector|string)\s+(\w+)\s*\([^;{]*\)\s*\{|^rule\s+(\w+)", t, re.M):
            name = m.group(1) or m.group(2)
            i = t.index("{", m.start())
            depth, j = 0, i
            while j < len(t):
                depth += {"{": 1, "}": -1}.get(t[j], 0)
                if depth == 0:
                    break
                j += 1
            if re.search(r"gIsLondon|\blondon\w*\(|\bgLondon", t[i:j + 1]):
                found.add((f, name))
    return found


def test_london_code_lives_only_where_the_owner_approved_it():
    unapproved = sorted(_units_with_london_code() - set(APPROVED_LONDON_CODE))
    assert not unapproved, ("London code in functions / rules the owner has not approved - propose the change, get the "
                            "approval, then add it to APPROVED_LONDON_CODE with the quote and date: %s" % unapproved)


@pytest.mark.parametrize("fn", ["tradingPostMonitor", "forwardTowerBaseManager", "selectTowerBuildPlanPosition", "towerManager"])
def test_contested_decisions_carry_no_london_branch(fn):
    body = core("aibuildings.xs") + core("aiassertivewall.xs")
    assert re.search(r"^rule\s+%s\s*$" % fn, body, re.M) or re.search(r"^(?:void|int|bool|vector)\s+%s\(" % fn, body, re.M), fn
    # the stock rules that decide WHAT the AI contests (sockets, the bridge post, natives, forward base, towers) never
    # branch on London; only the forward base's PLACE is approved (selectForwardBaseLocation)
    assert all(name != fn for _, name in _units_with_london_code()), fn


class TestRoundSixCriteria:
    def base(self):
        return [l.replace("build r3", "build r6") for l in london_record()]

    def verdicts(self, L):
        return {r[0]: r[2] for r in criteria_london.evaluate({2: sorted(L, key=criteria_london.gtime)})}

    def test_a_reappeared_gate_that_is_tasked_passes(self):
        L = self.base() + ["00:20:00  (1): LONDONGATE p2 gate 900 reappeared kind bridgeFar owner 3 hp 2000 - reserve again",
                           "00:21:00  (1): LONDONGATE p2 tasked 30 on 900 bridgeFar guard -1 hp 2000"]
        assert self.verdicts(L)["L9"] == "PASS"

    def test_a_reappeared_gate_left_alone_fails(self):
        L = self.base() + ["00:20:00  (1): LONDONGATE p2 gate 900 reappeared kind bridgeFar owner 3 hp 2000 - reserve again"]
        assert self.verdicts(L)["L9"] == "FAIL"


def suspect_and_then_subtraction_compare(cond):
    """Run 32 (2026-09-24): aibuildings.xs(3405) 'if (gAITestDiag == true && xsGetTime() - dockDiagTime >= 60000)'
    -> XS Error 0308 / 0135, every AI dead. An unparenthesised subtraction compared right after '&&'; the stock core
    never writes it (0 conditions). Plain steps into a local are the safe form."""
    return re.search(r"&&\s*[A-Za-z_][\w.]*(\([^()]*\))?\s*-\s*[A-Za-z_]\w*(\([^()]*\))?\s*(<|>|<=|>=|==)", cond) is not None


@pytest.mark.parametrize("name", sorted(f for f in os.listdir(CORE) if f.endswith(".xs")))
def test_no_condition_has_the_run_32_rejected_shape(name):
    text = re.sub(r"//[^\n]*", "", core(name))
    bad = [(n, c.strip()[:90]) for n, c in xs_conditions(text) if suspect_and_then_subtraction_compare(c)]
    assert not bad, bad


def test_the_lint_catches_the_run_32_line():
    assert suspect_and_then_subtraction_compare("gAITestDiag == true && xsGetTime() - dockDiagTime >= 60000")
    assert not suspect_and_then_subtraction_compare("xsGetTime() - gLastAttackMissionTime < (gAttackMissionInterval * 0.65)")


def test_the_driver_always_takes_the_loaded_screenshot():
    s = open(os.path.join(AITEST, "driver.py"), encoding="utf-8").read()
    assert "LOADED SCREENSHOT" in s and "loaded.png" in s


class TestFieldDistance:
    def base(self):
        return [l.replace("build r3", "build r9") for l in london_record()]

    def verdicts(self, L):
        return {r[0]: r[2] for r in criteria_london.evaluate({2: sorted(L, key=criteria_london.gtime)})}

    def test_near_fields_pass_f1(self):
        L = self.base() + ["00:15:00  (1): LONDONPLACE p2 field Plantation plan 5 at the countryside 1/2 dist 95.2"]
        assert self.verdicts(L)["F1"] == "PASS"

    def test_a_far_field_fails_f1(self):
        L = self.base() + ["00:15:00  (1): LONDONPLACE p2 field Plantation plan 5 at the countryside 1/2 dist 95.2",
                           "00:18:00  (1): LONDONPLACE p2 field Plantation plan 6 at the countryside 1/2 dist 310.0"]
        assert self.verdicts(L)["F1"] == "FAIL"


# ---- OWNER FEATURES MUST NOT DISAPPEAR (owner 2026-09-25: "The issue is extremely fatal ... If not discovered, the
# impact would be BRUTAL") ------------------------------------------------------------------------------------------
# 570d65a2 (2026-08-27, "strip to three concerns") deleted Istanbul's fleet split - the owner's own design - and the
# suite stayed green: it tested that the code which exists is well-formed, never that the owner's behaviours exist.
# Every behaviour the owner ordered is listed here with the rules / functions that implement it. A rule that is gone or
# never enabled fails the suite. Removing or changing an entry is the owner's approval step, as for APPROVED_LONDON_CODE.
OWNER_FEATURES = {
    "istanbul fleet split": {
        "quote": "'Pirate ships should attack the Naval Guns, because they have bonus against them (same monitors) and "
                 "other ships should guard the Naval Forts' (owner 2026-09-25; first built 893135a4, 2026-08-25)",
        "rules": ["istanbulGunFleet", "istanbulGunRaid", "istanbulMonitorMaintain"],
        "functions": ["istanbulIsGunFleetHull"],
    },
    "forward base at the enemy construction block": {
        "quote": "'can be also enemy bridgehead' + 'target the unique units instead of the map spot' (owner 2026-09-24); "
                 "Istanbul: next to the Fisherman's Guild (owner 2026-09-25)",
        "rules": ["pirateForwardBaseWatch"],
        "functions": ["pirateForwardBasePoint"],
    },
}


@pytest.mark.parametrize("feature", sorted(OWNER_FEATURES))
def test_owner_features_are_still_in_the_ai(feature):
    t = _strip_comments(core("aipiraterules.xs"))
    spec = OWNER_FEATURES[feature]
    for r in spec["rules"]:
        assert re.search(r"^rule\s+%s\s*$" % r, t, re.M), "%s: rule %s is gone - %s" % (feature, r, spec["quote"])
        assert re.search(r'xsEnableRule\("%s"\)' % r, t), "%s: rule %s is never enabled - %s" % (feature, r, spec["quote"])
    for fn in spec["functions"]:
        found = re.search(r"^(?:void|int|float|bool|vector|string)\s+%s\s*\(" % fn, t, re.M)
        assert found, "%s: function %s is gone - %s" % (feature, fn, spec["quote"])


def test_the_gun_fleet_sits_at_exactly_100():
    # stock gatherNavy (aiassertivewall.xs 7406) drains every warship whose plan's desired priority is not exactly
    # 24, 25, 99 or 100 into the amphibious assault - the August pool at 96 would be emptied at the first landing
    t = _strip_comments(core("aipiraterules.xs"))
    assert re.search(r"aiPlanSetDesiredPriority\(gIstanbulGunFleetPlan,\s*100\)", t)
    assert "if (aiPlanGetDesiredPriority(unitPlanID) == 99)" in core("aiassertivewall.xs")
    assert "aiPlanGetDesiredPriority(unitPlanID) == 100 ||" in core("aiassertivewall.xs")

