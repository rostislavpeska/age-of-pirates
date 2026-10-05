"""gr2_lint.py on the Korean TC specimens: each in-game defect must FAIL its check, the fixed files must PASS.

    python -m pytest scripts/havok/tests/test_gr2_lint.py -q

Specimens outside the repo (session scratchpad backups, never committed) are skipped when absent; their folder is
GR2_LINT_SPECIMENS of this device's local environment (the environment, else config/aop.local.env;
scripts/tools/local_env.py). The installed model in art/buildings/korean_tc is always there.
The DLL test needs WSL + Wine + gr2_to_raw.py (skipped otherwise).
"""
from __future__ import annotations

import copy
import json
import os
import re
import struct
import sys
from pathlib import Path

import numpy as np
import pytest

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "scripts" / "havok"))
sys.dont_write_bytecode = True

import gr2_lint as L  # noqa: E402

KTC = REPO / "art" / "buildings" / "korean_tc"


def s18k(name):
    """the SHIPPED S18k Korean TC model (commit ba233e90), read from git: the live art/ file is the builder's latest
    install (2026-09-30 12:15 an Oodle-compressed intact replaced it and 15 of these tests broke); the pinned numbers
    below are S18k's. .material / .xml / .hkt are unchanged since that commit and stay the live ones."""
    import subprocess
    import tempfile
    out = Path(tempfile.gettempdir()) / "gr2_lint_s18k" / name
    if not out.exists():
        r = subprocess.run(["git", "-C", str(REPO), "show", f"ba233e90:art/buildings/korean_tc/{name}"],
                           capture_output=True, timeout=120)
        if r.returncode:
            pytest.skip(f"the S18k specimen is not in this clone (git show ba233e90:{name})")
        out.parent.mkdir(parents=True, exist_ok=True)
        tmp = out.with_suffix(".part")
        tmp.write_bytes(r.stdout)
        tmp.replace(out)
    return out


sys.path.append(str(REPO / "scripts" / "tools"))
import local_env  # noqa: E402
SPEC = Path(local_env.value("GR2_LINT_SPECIMENS") or REPO / "no-specimens")     # not set on this device: skipped
OLD_DAMAGED = SPEC / "p0_damaged/backup/korean_tc_damaged.gr2.1939"       # one 102,527-vertex mesh, unrotated
F_2050 = SPEC / "p0_damaged/split/F.gr2"                                   # per-material split, windows on 'base'
PRE_ROT_RAW = SPEC / "install_rot_split/backup_195802/korean_tc.gr2"        # intact before the 90-degree turn
PRE_ROT_OODLE = SPEC / "ingame_fix/backup_1928/korean_tc.gr2"               # same, converter output (compressed)

PROFILES = L.load_profiles()
PROF = L.resolve_profile(PROFILES, "korean_tc")


def need(*paths):
    for p in paths:
        if not Path(p).exists():
            pytest.skip(f"specimen missing: {p}")


def run(**kw):
    files = dict(intact=str(s18k("korean_tc.gr2")), hkt=str(KTC / "korean_tc_damaged.hkt"),
                 intact_material=str(KTC / "korean_tc.material"), damaged_material=str(KTC / "korean_tc_damaged.material"))
    files.update(kw)
    res = L.lint(PROF, **files, use_dll=False, art_root=REPO / "art")
    return {(r["stage"], r["check"]): r for r in res}


def status(res, stage, check):
    return res[(stage, check)]["status"]


@pytest.fixture(scope="module")
def installed_intact():
    return L.read_raw(s18k("korean_tc.gr2"))


# ------------------------------------------------------------------------------------------------ the specimens
TEXTURE_GATES = ("texture_budget", "texel_density")        # KTC-165: the shipped model FAILS these (tests further down)
KNOWN_TANGENT_DEFECT = ("tangents",)                       # 2026-09-30: S18k ships 5277 zero tangents (pages A, H)


def test_installed_intact_passes_the_geometry_checks():
    res = run(damaged=None, hkt=None, animfile=str(KTC / "korean_tc.xml"))
    bad = {k: v["summary"] for k, v in res.items()
           if v["status"] == "FAIL" and k[1] not in TEXTURE_GATES + KNOWN_TANGENT_DEFECT}
    assert not bad, bad
    assert status(res, "intact", "tangents") == "FAIL"          # the known defect stays visible until the model is fixed
    assert sum(m["zero_tangent"] for m in res[("intact", "tangents")]["data"]["meshes"]) > 0
    for c in ("vertex_limit", "wrap16", "orientation", "handedness", "attach_bones", "hitpointbar", "flag_on_mast",
              "bone_set", "materials"):
        assert status(res, "intact", c) == "PASS", c
    assert res[("intact", "orientation")]["data"]["mast_quadrant"] == "+X+Y"
    assert res[("intact", "orientation")]["data"]["courtyard_quadrant"] == "-X-Y"


def test_old_damaged_fails_vertex_limit_and_frame():
    need(OLD_DAMAGED)
    res = run(damaged=str(OLD_DAMAGED))
    for c in ("vertex_limit", "wrap16", "orientation", "damaged_frame"):
        assert status(res, "damaged", c) == "FAIL", c
    assert res[("damaged", "vertex_limit")]["data"]["meshes"][0]["vertices"] == 102527
    assert res[("damaged", "wrap16")]["data"]["changed_tris"] > 0


def test_2050_split_passes_limits_and_frame_fails_windows_on_base():
    need(F_2050)
    res = run(damaged=str(F_2050))
    for c in ("crc", "vertex_limit", "wrap16", "orientation", "handedness", "attach_bones", "hitpointbar", "bindings",
              "damaged_frame", "hkt_pairing", "materials"):
        assert status(res, "damaged", c) == "PASS", (c, res[("damaged", c)]["summary"])
    base = res[("damaged", "base_binding")]
    assert base["status"] == "FAIL"
    na = base["data"]["not_allowed"]
    assert set(na) == {"window_panel"}, na
    assert na["window_panel"]["elements"] == 14 and na["window_panel"]["tris"] == 27
    assert {"platform", "notice_board", "jar_cluster"} <= set(base["data"]["allowed"])


def test_pre_rotation_intact_fails_orientation():
    need(PRE_ROT_RAW)
    res = run(intact=str(PRE_ROT_RAW), damaged=None, hkt=None)
    assert status(res, "intact", "orientation") == "FAIL"
    assert res[("intact", "orientation")]["data"]["mast_quadrant"] == "-X+Y"       # a quarter turn
    assert status(res, "intact", "hitpointbar") == "FAIL"


def test_compressed_pre_rotation_intact_through_the_dll():
    need(PRE_ROT_OODLE)
    tools = L.find_tools(PROFILES)
    if tools is None or not (tools / "gr2_to_raw.py").exists():
        pytest.skip("gr2_to_raw.py not available")
    assert L.header(PRE_ROT_OODLE)["compressed"]
    res = {(r["stage"], r["check"]): r for r in L.lint(PROF, intact=str(PRE_ROT_OODLE), tools=tools, use_dll=True)}
    if res[("intact", "dll_read")]["status"] != "PASS":
        pytest.skip(f"DLL route unavailable here: {res[('intact', 'dll_read')]['summary']}")
    assert status(res, "intact", "orientation") == "FAIL"
    assert status(res, "intact", "flag_on_mast") == "FAIL"                          # the pilot's 15.5 cm off the pole
    assert res[("intact", "flag_on_mast")]["data"]["off_axis_m"] > 0.1


# ------------------------------------------------------------------------------------ synthetic defects (in memory)
def transformed(info, M, flip_winding):
    """a copy of a read model with every position multiplied by M (3x3, raw frame) - a turn or a mirror."""
    out = copy.deepcopy(info)
    for m in out["meshes"]:
        m["pos"] = m["pos"] @ np.asarray(M, float).T
        if flip_winding:
            m["tris"] = m["tris"][:, [0, 2, 1]]
    for b in out["bones"]:
        b["world"][3, :3] = np.asarray(M, float) @ b["world"][3, :3]
    L._mark_bound(out)
    return out


def test_quarter_turn_and_x_mirror_fail_orientation(installed_intact):
    turn = [[0, 0, 1], [0, 1, 0], [-1, 0, 0]]
    assert L.check_orientation("intact", installed_intact, PROF)["status"] == "PASS"
    assert L.check_orientation("intact", transformed(installed_intact, turn, False), PROF)["status"] == "FAIL"
    mirror_x = [[-1, 0, 0], [0, 1, 0], [0, 0, 1]]
    assert L.check_orientation("intact", transformed(installed_intact, mirror_x, True), PROF)["status"] == "FAIL"


def test_diagonal_mirror_keeps_quadrants_but_fails_handedness(installed_intact):
    """mirror across the mast-courtyard diagonal (raw x <-> z): the quadrant test cannot see it, handedness does."""
    diag = [[0, 0, 1], [0, 1, 0], [1, 0, 0]]
    m = transformed(installed_intact, diag, True)
    assert L.check_orientation("intact", m, PROF)["status"] == "PASS"
    h = L.check_handedness("intact", m, PROF)
    assert h["status"] == "FAIL" and h["data"]["fraction_expected_sign"] < 0.2
    assert L.check_handedness("intact", installed_intact, PROF)["status"] == "PASS"


def test_name_board_faces(installed_intact):
    mesh = installed_intact["render"][0]
    s, a = L.uv_handedness(mesh["pos"][mesh["tris"]], mesh["uv"][mesh["tris"]])
    ids = [int(i) for i in np.nonzero((s > 0) & (a > 0.01))[0][:6]]
    prof = copy.deepcopy(PROF)
    prof["handedness"]["name_board"] = dict(stage="intact", mesh=mesh["name"], triangles=ids, expect_sign=1)
    ok = L.check_handedness("intact", installed_intact, prof)
    assert ok["status"] == "PASS" and ok["data"]["name_board"]["reading_right"] == len(ids)
    mirrored = transformed(installed_intact, [[-1, 0, 0], [0, 1, 0], [0, 0, 1]], True)
    assert L.check_handedness("intact", mirrored, prof)["status"] == "FAIL"


def test_flag_off_the_mast_fails(installed_intact):
    m = copy.deepcopy(installed_intact)
    for b in m["bones"]:
        if b["name"] in ("bone_flag_civ", "BONE_GARRISONFLAG"):
            b["world"][3, 0] += 0.155                                            # the pilot's offset
    assert L.check_flag("intact", installed_intact, PROF)["status"] == "PASS"
    assert L.check_flag("intact", m, PROF)["status"] == "FAIL"


def test_missing_attach_bone_and_undeclared_bone_fail(installed_intact):
    m = copy.deepcopy(installed_intact)
    m["bones"] = [b for b in m["bones"] if b["name"] != "BONE_GARRISONFLAG"]
    m["bones"].append(dict(name="pilot_flag", parent=0, world=np.eye(4)))
    assert L.check_attach("intact", m, PROF)[0]["status"] == "FAIL"
    bs = L.check_bone_set("intact", m, PROF["intact_bones"])
    assert bs["status"] == "FAIL" and bs["data"]["extra"] == ["pilot_flag"] and bs["data"]["missing"] == ["BONE_GARRISONFLAG"]


def test_vertex_limit_counts_a_mesh_over_65535():
    info = dict(render=[dict(name="big", mats=["mata"], nv=70000, index_width=4,
                             tris=np.array([[0, 1, 69999], [0, 1, 2]], np.int64))])
    lim, wrap = L.check_limits("damaged", info, PROF)
    assert lim["status"] == "FAIL" and wrap["status"] == "FAIL" and wrap["data"]["changed_tris"] == 1


def test_zero_tangents_fail_and_fade_bits_are_only_reported():
    """west_towncenter_3age (legacy DE conversion) ships every tangent (0,0,0): materialdefault normalises it -> NaN
    lighting, the building rendered 'very dark' in game with any texture (2026-09-30). Converter models carry fade bits
    other than 127 and render fine: reported, never failed."""
    tris = np.array([[0, 1, 2]], np.int64)
    def mesh(tan, w):
        return dict(name="m", mats=["mata"], nv=3, index_width=4, tris=tris,
                    tan=np.array(tan, float), tanw=np.array(w, float).reshape(-1, 1))
    zero = L.check_tangents("intact", dict(render=[mesh([[0, 0, 0]] * 3, [0, 0, 0])]))
    good = L.check_tangents("intact", dict(render=[mesh([[1, 0, 0]] * 3, [127, 255, 127])]))
    other_fade = L.check_tangents("intact", dict(render=[mesh([[0, 1, 0]] * 3, [0, 128, 0])]))
    assert zero["status"] == "FAIL" and zero["data"]["meshes"][0]["zero_tangent"] == 3
    assert good["status"] == "PASS" and good["data"]["meshes"][0]["fade_not_127"] == 0
    assert other_fade["status"] == "PASS" and other_fade["data"]["meshes"][0]["fade_not_127"] == 3


def test_material_mismatch_fails(tmp_path, installed_intact):
    mat = tmp_path / "x.material"
    mat.write_text('<material>\r\n  <submaterial name="mata" />\r\n  <submaterial name="matb" />\r\n</material>\r\n')
    r = L.check_materials("intact", installed_intact, str(mat), None)
    assert r["status"] == "FAIL" and r["data"]["used"] == ["mata", "matb", "matc"]


def test_animfile_lf_fails(tmp_path):
    p = tmp_path / "a.xml"
    p.write_bytes(b"<animfile>\n</animfile>\n")
    assert L.check_crlf(str(p))["status"] == "FAIL"
    p.write_bytes(b"<animfile>\r\n</animfile>\r\n")
    assert L.check_crlf(str(p))["status"] == "PASS"


def fake_uv_gate(tmp_path, status="PASS"):
    """a stand-in for Claude_CP2 gates/uv_gate.py: run() -> one check with `status` (RAISE: an unreadable registry)"""
    p = tmp_path / "uv_gate.py"
    if status == "RAISE":
        run = "    raise ValueError('versions[S2].metrics is list, not dict')\n"
    else:
        run = (f"    c = {{'id': 'b', 'status': {status!r}, 'text': {status + '   b open_upgrade: D-001=B not done'!r}}}\n"
               f"    return {{'ok': {status != 'FAIL'}, 'in_use': 'S18k', 'approved_target': 'S19-fix', "
               "'head_status': 'open', 'checks': [c]}\n")
    p.write_text("from pathlib import Path\nDEFAULT_LINEAGE = Path(__file__).with_name('uv_lineage.json')\n\n\n"
                 "def run(lineage=None):\n" + run, encoding="utf-8")
    return p


@pytest.fixture
def passing_uv_gate(tmp_path, monkeypatch):
    """the CLI tests of the other checks: the UV lineage gate passes (its own tests are below)"""
    gate = fake_uv_gate(tmp_path)
    monkeypatch.setattr(L, "uv_gate_path", lambda profiles, prof: gate)
    return gate


def test_the_korean_tc_profile_runs_the_uv_lineage_gate():
    """INC-002 / INC-022: the rule 13 lint of the Korean TC runs the UV lineage gate"""
    assert PROF["uv_gate"]["path"].replace("\\", "/").endswith("Claude_CP2/gates/uv_gate.py")
    assert L.uv_gate_path(PROFILES, PROF) is not None and L.uv_gate_path(PROFILES, {"files": {}}) is None


@pytest.mark.parametrize("status,exp", [("PASS", "PASS"), ("WAIVED", "PASS"), ("FAIL", "FAIL"), ("RAISE", "FAIL")])
def test_uv_lineage_check_follows_the_gate(tmp_path, status, exp):
    r = L.check_uv_gate(fake_uv_gate(tmp_path, status))
    assert r["check"] == "uv_lineage" and r["status"] == exp, r["summary"]
    if status == "FAIL":
        assert "D-001=B not done" in r["summary"]
    if status == "RAISE":
        assert "cannot read the registry" in r["summary"]
    assert L.check_uv_gate(tmp_path / "missing" / "uv_gate.py")["status"] == "SKIP"      # not found: not proven


def test_a_failing_uv_gate_fails_the_lint(tmp_path, monkeypatch, capsys):
    """exit 1 even with --allow-skip: the model is not cleared for the owner's game test while the UV lineage FAILS"""
    gate = fake_uv_gate(tmp_path, "FAIL")
    monkeypatch.setattr(L, "uv_gate_path", lambda profiles, prof: gate)
    intact_only = ["--profile", "korean_tc", str(KTC), "--intact", str(s18k("korean_tc.gr2")), "--only", "intact"]
    assert L.main(intact_only + ["--no-dll", "--allow-skip"]) == 1
    out = capsys.readouterr().out
    assert "uv_lineage" in out and "FAIL   b open_upgrade" in out


@pytest.fixture
def passing_texture_gates(monkeypatch):
    """the CLI tests of the other checks: the texture ceiling, the density floor and the tangents pass (their own
    tests elsewhere; the S18k specimen fails all three)"""
    monkeypatch.setattr(L, "check_texture_budget", lambda stage, *a, **k: L.R(stage, "texture_budget", True, "stub"))
    monkeypatch.setattr(L, "check_density", lambda stage, *a, **k: L.R(stage, "texel_density", True, "stub"))
    monkeypatch.setattr(L, "check_tangents", lambda stage, *a, **k: L.R(stage, "tangents", True, "stub"))


def test_cli_exit_codes(passing_uv_gate, passing_texture_gates):
    need(OLD_DAMAGED)
    intact_only = ["--profile", "korean_tc", str(KTC), "--intact", str(s18k("korean_tc.gr2")), "--only", "intact"]
    assert L.main(intact_only + ["--no-dll"]) == 2                 # dll_read SKIP: not proven to load in the game
    assert L.main(intact_only + ["--no-dll", "--allow-skip"]) == 0
    assert L.main(["--profile", "korean_tc", str(KTC), "--intact", str(s18k("korean_tc.gr2")), "--damaged",
                   str(OLD_DAMAGED), "--no-dll"]) == 1


def test_exit_code_rules():
    ok, skip, fail = dict(status="PASS"), dict(status="SKIP"), dict(status="FAIL")
    assert L.exit_code([ok, ok]) == 0
    assert L.exit_code([ok, skip]) == 2 and L.exit_code([ok, skip], allow_skip=True) == 0
    assert L.exit_code([skip, fail]) == 1 and L.exit_code([fail], allow_skip=True) == 1


def test_missing_dll_tools_exit_2(monkeypatch, passing_uv_gate, passing_texture_gates):
    """the tools folder is missing: dll_read SKIP must not clear the model (was exit 0, 2026-09-29 review)"""
    monkeypatch.setattr(L, "find_tools", lambda profiles: Path("Z:/no/tools"))
    assert L.main(["--profile", "korean_tc", str(KTC), "--intact", str(s18k("korean_tc.gr2")),
                   "--only", "intact"]) == 2



# --------------------------------------------------------- KTC-164 / KTC-165: texture ceilings + the universal UV floor
# Owner 2026-09-30 (m334): "Plus we need hard DPI floor!!!!!!!!!! Scattered UV map is a nightmare!!!!!! Plus also hard
# floor for texture sizes ... These are ceilings for this project!!!!!!!!!!!!!! But UV map DPI floor should be
# universal". Classes m335 (medium: TC, Market) / m336 (house small). The shipped Korean TC failing is the right result.
DF = L._density_module()
FLOOR = DF.load_floor("aoe3de")
MATA, MATC = "korean_tc_mata_BaseColor", "korean_tc_matc_BaseColor"
VANILLA = SPEC / "vanilla" / "m"          # the density baseline's extraction (scratchpad, never the repo: rule 3)
VANILLA_NON_LARGE = ("china_towncenter_age2", "japan_towncenter_age2", "india_towncenter_age2", "west_tc_age2",
                     "med_tc_age2", "west_barracks_age2", "japan_dojo_age2", "china_waracademy_age2", "west_house_age2a",
                     "village_age_2_01", "japan_shrine_age2_01", "spanish_church_age2", "temple_of_heaven",
                     "porcelain_tower", "toshogu_shrine")


def need_archive():
    if not L._bartool()[1]:
        pytest.skip("the game archives are not readable here (vanilla texture sizes)")


def need_vanilla(*stems):
    for st in stems:
        if not (VANILLA / f"{st}.gr2").exists():
            pytest.skip(f"vanilla sample missing: {VANILLA / st} (bar-extract into the scratchpad)")


def ktc_groups(info, stage="intact"):
    return L.density_groups(info, KTC / ("korean_tc.material" if stage == "intact" else "korean_tc_damaged.material"),
                            REPO / "art")


def test_the_shipped_korean_tc_fails_the_ceiling_on_the_third_set():
    """medium (m335) = 2048 + one 1024 complement; the shipped model loads mata 2048, matb 1024 (cutout) AND matc 512"""
    res = run(damaged=str(s18k("korean_tc_damaged.gr2")))
    for stage in ("intact", "damaged"):
        r = res[(stage, "texture_budget")]
        d = r["data"]
        assert r["status"] == "FAIL", r["summary"]
        assert (d["cls"], d["confirmed_by"], d["ceiling"], d["counted"]) == ("medium", "m335", [2048, 1024], 3)
        assert sorted(x["size"] for x in d["sets"] if x["src"] == "mod") == [512, 1024, 2048]
        assert "over the ceiling: 3 sets > 2" in r["summary"] and f"{MATC} 512" in r["summary"]
    dmg = res[("damaged", "texture_budget")]
    if L._bartool()[1]:                                  # the vanilla destruction sheet: listed, never counted
        assert "shared vanilla, not counted: destructionsheet_mata_basecolor 2048" in dmg["summary"]


def test_the_shipped_korean_tc_density_exactly_as_measured(installed_intact):
    """gates/density_baseline.json: a median 107.0 PASSES; b 9.6 % of the area below 60 t/u FAILS, all of it on the
    matc page (the hidden faces: 28.6 % of that page below 60); without matc 0 % below, p2 105.6; 278 islands / 100 u2"""
    r = L.check_density("intact", installed_intact, KTC / "korean_tc.material", REPO / "art", PROF, "korean_tc")
    m = r["data"]["metrics"]
    assert r["status"] == "FAIL" and r["data"]["verdict"] == "FAIL"
    assert abs(m["model"]["p50"] - 106.98) < 0.05 and abs(m["model"]["share_below_face_floor"] - 0.0961) < 5e-4
    assert abs(m["model"]["p2"] - 29.4) < 0.1 and abs(m["pages"][MATC]["share_below_face_floor"] - 0.2861) < 5e-4
    assert {(f["rule"], f["page"]) for f in r["data"]["findings"]} == {("face_floor", None), ("face_floor", MATC),
                                                                         ("untextured", None)}      # b+c (INC-035)
    rest = DF.measure(ktc_groups(installed_intact), FLOOR, exempt=[MATC])
    assert not DF.rules(rest, FLOOR)
    assert rest["model"]["share_below_face_floor"] == 0 and abs(rest["model"]["p2"] - 105.58) < 0.05
    assert abs(rest["model"]["islands_per_100u2"] - 278.4) < 0.5


def test_the_shipped_damaged_model_fails_the_floor_on_matc_too():
    need_archive()                                      # the destruction sheet's size comes from the game archive
    info = L.read_raw(s18k("korean_tc_damaged.gr2"))
    r = L.check_density("damaged", info, KTC / "korean_tc_damaged.material", REPO / "art", PROF, "korean_tc")
    m = r["data"]["metrics"]
    assert r["status"] == "FAIL" and ("face_floor", MATC) in {(f["rule"], f["page"]) for f in r["data"]["findings"]}
    assert m["pages"]["destructionsheet_mata_basecolor"]["p50"] > 100          # vanilla cut faces pass easily
    assert not DF.rules(DF.measure(ktc_groups(info, "damaged"), FLOOR, exempt=[MATC]), FLOOR)


def owner_store(tmp_path, text):
    p = tmp_path / "tasks.json"
    p.write_text(json.dumps({"messages": {"2026-09-30": {"items": [{"id": "m900", "text": text}]}}}), encoding="utf-8")
    return p


def test_only_the_owners_whole_message_exempts_the_hidden_page(tmp_path, monkeypatch, installed_intact):
    """the matc exemption is the owner's call (KTC-164): a recorded waiver with his whole message exempts the page and
    the rest must still pass; a fragment, another model or no message store never does"""
    text = "The Korean TC matc faces are hidden in game, leave the matc page out of the density floor."
    monkeypatch.setattr(L, "owner_message_store", lambda prof: owner_store(tmp_path, text))
    prof = copy.deepcopy(PROF)
    prof["waivers"] = [dict(id="W-D1", check="density_floor", model="korean_tc", pages=[MATC], owner_quote=text,
                            msg="m900", at="2026-09-30T11:00:00Z", recorded_by="test")]
    check = lambda p: L.check_density("intact", installed_intact, KTC / "korean_tc.material", REPO / "art", p,  # noqa
                                      "korean_tc")
    r = check(prof)
    assert r["status"] == "PASS" and r["data"]["verdict"] == "WAIVED" and "WAIVED W-D1" in r["summary"]
    prof["waivers"][0]["owner_quote"] = "leave the matc page out of the density floor"
    r = check(prof)
    assert r["status"] == "FAIL" and "a fragment never waives" in r["summary"]
    prof["waivers"][0].update(owner_quote=text, model="market")
    assert check(prof)["status"] == "FAIL"
    monkeypatch.setattr(L, "owner_message_store", lambda prof: None)
    prof["waivers"][0]["model"] = "korean_tc"
    assert "no owner message store" in check(prof)["summary"]
    assert PROF["waivers"] == []                          # nothing recorded: the exemption is the owner's call


def test_a_scattered_uv_map_on_the_same_pages_fails_the_per_face_floor(installed_intact):
    """the owner's "scattered UV map": the same Korean TC pages, but 10 % of the mata area cut into one-triangle islands
    shrunk to 45 % (about 48 t/u). The median still passes; the per-face floor fails, per model and per page. matc is
    left out here (it fails on its own)."""
    groups = ktc_groups(installed_intact)
    base = DF.measure(groups, FLOOR, exempt=[MATC])
    assert not DF.rules(base, FLOOR)
    scattered = copy.deepcopy(groups)
    mata = [g for g in scattered if g["page"] == MATA]
    total = sum(DF.face_density(g["P"], g["UV"], 1, 1)[0].sum() for g in mata)
    cut = 0.0
    for g in mata:
        a3 = DF.face_density(g["P"], g["UV"], 1, 1)[0]
        for i in range(len(a3)):
            if cut >= 0.10 * total:
                break
            c = g["UV"][i].mean(0)
            g["UV"][i] = c + (g["UV"][i] - c) * 0.45
            cut += a3[i]
    m = DF.measure(scattered, FLOOR, exempt=[MATC])
    found = {(f["rule"], f["page"]) for f in DF.rules(m, FLOOR)}
    assert found == {("face_floor", None), ("face_floor", MATA), ("untextured", None)}, found     # b+c: INC-035
    assert m["model"]["p50"] >= 100                                            # the median alone would not see it
    assert m["model"]["islands_per_100u2"] > base["model"]["islands_per_100u2"]


# -------------------------------------------------------------------------- ceilings on synthetic material + DDTs
def ddt(path, size):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(b"RTS3" + bytes([0, 0, 1, 12]) + struct.pack("<II", size, size) + bytes(16))


def budget(tmp_path, sizes, cls, confirmed="m9", shared=(), per_model=None, missing=False, monkeypatch=None):
    """a model 'fake' with one texture set per size (BaseColor + Normals DDT headers) and optional shared submaterials;
    the owner's message m9 names the fake building and every class (INC-033: confirmed_by is verified)"""
    art = tmp_path / "art"
    subs = []
    for i, size in enumerate(sizes):
        base = f"buildings\\fake\\textures\\fake_mat{i}"
        ddt(art / "buildings" / "fake" / "textures" / f"fake_mat{i}_BaseColor.ddt", size)
        ddt(art / "buildings" / "fake" / "textures" / f"fake_mat{i}_Normals.ddt", size)
        subs.append(f'  <submaterial name="mat{i}">\r\n    <materialdef name="{"default_cutout" if i else "default"}" />\r\n'
                    f'    <parameters>\r\n      <texture name="BaseColor" override="{base}_BaseColor" />\r\n'
                    f'      <texture name="Normals" override="{base}_Normals" />\r\n    </parameters>\r\n  </submaterial>')
    for k, path in enumerate(shared):
        subs.append(f'  <submaterial name="shared{k}">\r\n    <materialdef name="default" />\r\n    <parameters>\r\n'
                    f'      <texture name="BaseColor" override="{path}" />\r\n    </parameters>\r\n  </submaterial>')
    if missing:
        subs.append('  <submaterial name="lost">\r\n    <materialdef name="default" />\r\n    <parameters>\r\n'
                    '      <texture name="BaseColor" override="buildings\\nowhere\\textures\\nowhere_mata_BaseColor" />\r\n'
                    '    </parameters>\r\n  </submaterial>')
    mat = art / "buildings" / "fake" / "fake.material"
    mat.write_text("<material>\r\n" + "\r\n".join(subs) + "\r\n</material>\r\n", encoding="utf-8")
    tb = {"class": cls, "models": ["fake"],
          **({"confirmed_by": confirmed} if confirmed else {"status": "proposed, owner to confirm"})}
    if per_model:
        tb["per_model"] = per_model
    store = tmp_path / "tasks.json"
    store.write_text(json.dumps({"messages": {"d": {"items": [
        {"id": "m9", "text": "The fake building is small, medium or large, as the test needs."}]}}}), encoding="utf-8")
    monkeypatch.setattr(L, "owner_message_store", lambda prof: store)
    prof = dict(names=["fake"], texture_budget=tb, _texture_budget=PROFILES["texture_budget"])
    return L.check_texture_budget("intact", str(mat), art, prof, "fake")


@pytest.mark.parametrize("cls,sizes,ok,words", [
    ("small", [2048, 1024], False, "2 sets > 1"),                  # a barracks-size building with a complement
    ("large", [2048, 2048, 2048], False, "3 sets > 2"),            # a cathedral with a third 2048
    ("medium", [2048, 1024], True, ""),                            # a TC: 2048 + the 1024 complement
    ("medium", [2048, 1024, 512], False, "3 sets > 2"),            # the shipped Korean TC shape
    ("medium", [2048, 2048], False, "fake_mat1_BaseColor 2048 > 1024"),   # the complement is 1024 at most
    ("large", [2048, 2048], True, ""),
    ("small", [2048], True, ""),
    ("small", [4096], False, "fake_mat0_BaseColor 4096 > 2048"),
])
def test_the_ceiling_of_each_class(tmp_path, monkeypatch, cls, sizes, ok, words):
    r = budget(tmp_path, sizes, cls, monkeypatch=monkeypatch)
    assert r["status"] == ("PASS" if ok else "FAIL"), r["summary"]
    assert words in r["summary"]


def test_a_class_the_owner_did_not_confirm_fails(tmp_path, monkeypatch):
    r = budget(tmp_path, [2048], "small", confirmed=None, monkeypatch=monkeypatch)
    assert r["status"] == "FAIL" and "class small not confirmed by the owner" in r["summary"]
    r = budget(tmp_path / "x", [2048], None, monkeypatch=monkeypatch)
    assert r["status"] == "FAIL" and "no texture class recorded for fake" in r["summary"]


def test_a_per_model_class_overrides_the_folder_class(tmp_path, monkeypatch):
    assert budget(tmp_path, [2048, 2048], "small", monkeypatch=monkeypatch)["status"] == "FAIL"
    r = budget(tmp_path / "x", [2048, 2048], "small", per_model={"fake": {"class": "large", "confirmed_by": "m9"}},
               monkeypatch=monkeypatch)
    assert r["status"] == "PASS" and "class large (owner m9)" in r["summary"]


def test_one_basecolor_is_one_set_and_unresolved_textures_fail(tmp_path, monkeypatch):
    r = budget(tmp_path, [2048], "small", shared=["buildings\\fake\\textures\\fake_mat0_BaseColor"],
               monkeypatch=monkeypatch)
    assert r["status"] == "PASS" and r["data"]["counted"] == 1          # two submaterials on one page
    r = budget(tmp_path / "x", [2048], "small", missing=True, monkeypatch=monkeypatch)
    assert r["status"] == "FAIL" and "resolve nowhere" in r["summary"]


def test_a_shared_vanilla_atlas_is_listed_not_counted(tmp_path, monkeypatch):
    need_archive()
    r = budget(tmp_path, [2048], "small", monkeypatch=monkeypatch,
               shared=["homecity\\home_city_props\\generic_props\\textures\\generic_props_BaseColor"])
    assert r["status"] == "PASS" and "shared vanilla, not counted: generic_props_BaseColor 2048" in r["summary"]
    assert PROFILES["texture_budget"]["count_shared_vanilla"] is False         # proposed; the owner confirms


def test_every_building_folder_has_a_class_and_only_the_owner_confirms_one():
    """no silent default (note 2, m335): every art/buildings folder has a profile with a class; confirmed only where
    the owner said so, everything else 'proposed, owner to confirm' (and that FAILS an export)"""
    prof = PROFILES["profiles"]
    folders = {p.name for p in (REPO / "art" / "buildings").iterdir() if p.is_dir()}
    assert folders <= set(prof), sorted(folders - set(prof))
    classes = PROFILES["texture_budget"]["classes"]
    assert {k: v["ceiling"] for k, v in classes.items()} == {"small": [2048], "medium": [2048, 1024],
                                                            "large": [2048, 2048]}
    confirmed = {k: (v["texture_budget"]["class"], v["texture_budget"]["confirmed_by"]) for k, v in prof.items()
                 if v["texture_budget"].get("confirmed_by")}
    assert confirmed == {"korean_tc": ("medium", "m335"), "market": ("medium", "m335"), "house": ("small", "m336")}
    for name, v in prof.items():
        entries = [v["texture_budget"], *(v["texture_budget"].get("per_model") or {}).values()]
        for e in entries:
            assert e["class"] in classes, name
            assert e.get("confirmed_by") or e.get("status") == "proposed, owner to confirm", name


def test_inc036_a_generic_owner_message_never_waives_the_korean_tc(tmp_path, monkeypatch, installed_intact):
    """INC-036: the verifier waived the shipped KTC's floor with m278 "approve" and a matc page waiver with m264 "yes".
    A waiver's message must name the density floor and the model (the profile's names: Korean TC, TC ...)"""
    store = tmp_path / "tasks.json"
    store.write_text(json.dumps({"messages": {"d": {"items": [
        {"id": "m278", "text": "approve"}, {"id": "m264", "text": "yes"},
        {"id": "m901", "text": "Keep the KTC matc page out of the DPI floor, it is hidden."}]}}}), encoding="utf-8")
    monkeypatch.setattr(L, "owner_message_store", lambda prof: store)
    prof = copy.deepcopy(PROF)
    check = lambda p: L.check_density("intact", installed_intact, KTC / "korean_tc.material", REPO / "art", p,  # noqa
                                      "korean_tc")
    for mid, text, pages in (("m278", "approve", None), ("m264", "yes", [MATC])):
        prof["waivers"] = [dict(id="W-X", check="density_floor", model="korean_tc", owner_quote=text, msg=mid,
                                at="2026-09-30T11:00:00Z", recorded_by="test", **({"pages": pages} if pages else {}))]
        r = check(prof)
        assert r["status"] == "FAIL" and "does not name the density floor and the model" in r["summary"], mid
    prof["waivers"] = [dict(id="W-Y", check="density_floor", model="korean_tc", pages=[MATC], msg="m901",
                            owner_quote="Keep the KTC matc page out of the DPI floor, it is hidden.",
                            at="2026-09-30T11:00:00Z", recorded_by="test")]
    assert check(prof)["data"]["verdict"] == "WAIVED"                  # KTC is one of the profile's names


# -------------------------------------------------------------- INC-033: the texture ceiling cannot be escaped
BS = chr(92)                                    # the Windows path separator of .material / animfile paths


def adv_tree(tmp_path):
    """a synthetic model folder art/buildings/advx with DDT headers of the given sizes"""
    art = tmp_path / "art"
    (art / "buildings" / "advx" / "textures").mkdir(parents=True)
    return art


def adv_tex(art, name, size):
    ddt(art / "buildings" / "advx" / "textures" / f"{name}.ddt", size)
    return "buildings" + BS + "advx" + BS + "textures" + BS + name


def adv_mat(art, fname, subs, variants=None):
    x = ["<material>"]
    for name, tex in subs:
        x.append(f'  <submaterial name="{name}">')
        x.append('    <materialdef name="default" />')
        x.append("    <parameters>")
        x += [f'      <texture name="{k}" override="{v}" />' for k, v in tex.items()]
        x.append("    </parameters>")
        for vn, vt in (variants or {}).get(name, []):
            x.append(f'    <parameters variant="{vn}">')
            x += [f'      <texture name="{k}" override="{v}" />' for k, v in vt.items()]
            x.append("    </parameters>")
        x.append("  </submaterial>")
    x.append("</material>")
    p = art / "buildings" / "advx" / fname
    p.write_text("\r\n".join(x) + "\r\n", encoding="utf-8")
    return p


def adv_prof(tmp_path, monkeypatch, cls, who="m9", text=None, **tb):
    store = tmp_path / "tasks.json"
    store.write_text(json.dumps({"messages": {"d": {"items": [
        {"id": "m9", "text": text or f"The advx building is {cls}."}, {"id": "m264", "text": "yes"}]}}}),
        encoding="utf-8")
    monkeypatch.setattr(L, "owner_message_store", lambda prof: store)
    tb.setdefault("models", ["advx"])
    prof = dict(name="advx", names=["advx"], texture_budget=dict({"class": cls}, **({"confirmed_by": who} if who else {}),
                                                                  **tb))
    prof["_texture_budget"] = PROFILES["texture_budget"]
    prof["_tools"] = PROFILES.get("tools") or {}
    return prof


def adv_check(art, mat, prof, **kw):
    return L.check_texture_budget("intact", str(mat), art, prof, "advx", **kw)


def test_inc033_a_shared_basecolor_does_not_hide_extra_own_maps(tmp_path, monkeypatch):
    """INC-033: C2: two submaterials on one 2048 BaseColor, the second with its OWN 2048 Normals and Masks: two 2048 pages"""
    art = adv_tree(tmp_path)
    a, n1 = adv_tex(art, "advx_mata_BaseColor", 2048), adv_tex(art, "advx_mata_Normals", 2048)
    n2, m2 = adv_tex(art, "advx_matb_Normals", 2048), adv_tex(art, "advx_matb_Masks", 2048)
    one = adv_mat(art, "c1.material", [("mata", {"BaseColor": a, "Normals": n1}), ("matb", {"BaseColor": a})])
    assert adv_check(art, one, adv_prof(tmp_path, monkeypatch, "small"))["status"] == "PASS"     # one page, shared
    two = adv_mat(art, "advx.material", [("mata", {"BaseColor": a, "Normals": n1}),
                                         ("matb", {"BaseColor": a, "Normals": n2, "Masks": m2})])
    r = adv_check(art, two, adv_prof(tmp_path, monkeypatch, "small"))
    assert r["status"] == "FAIL" and "2 sets > 1" in r["summary"] and r["data"]["counted"] == 2


def test_inc033_own_maps_under_a_vanilla_basecolor_count(tmp_path, monkeypatch):
    """INC-033: C7: a vanilla BaseColor with the mod's own 4096 Normals: the own file counts (was: the set was not counted)"""
    need_archive()
    art = adv_tree(tmp_path)
    van = "buildings" + BS + "town_center" + BS + "med" + BS + "age_2" + BS + "textures" + BS + "med_tc_age2_matA_BaseColor"
    mat = adv_mat(art, "advx.material", [("mata", {"BaseColor": van, "Normals": adv_tex(art, "advx_big_Normals", 4096)})])
    r = adv_check(art, mat, adv_prof(tmp_path, monkeypatch, "small"))
    assert r["status"] == "FAIL" and "advx_big_Normals 4096 > 2048" in r["summary"]


def test_inc033_a_variant_texture_counts(tmp_path, monkeypatch):
    """INC-033: C6: <parameters variant="1"> with a 4096 BaseColor is loaded for that variant (dutch_church uses variant 1)"""
    art = adv_tree(tmp_path)
    mat = adv_mat(art, "advx.material", [("mata", {"BaseColor": adv_tex(art, "advx_mata_BaseColor", 2048)})],
                  variants={"mata": [("1", {"BaseColor": adv_tex(art, "advx_matx_BaseColor", 4096)})]})
    r = adv_check(art, mat, adv_prof(tmp_path, monkeypatch, "small"))
    assert r["status"] == "FAIL" and "advx_matx_BaseColor 4096 > 2048" in r["summary"]


def test_inc033_an_animfile_replacetexture_counts(tmp_path, monkeypatch):
    """INC-033: C10: the animfile swaps the 2048 BaseColor for a 4096 (<replacetexture>): the game draws the 4096"""
    art = adv_tree(tmp_path)
    a, x = adv_tex(art, "advx_mata_BaseColor", 2048), adv_tex(art, "advx_matx_BaseColor", 4096)
    mat = adv_mat(art, "advx.material", [("mata", {"BaseColor": a})])
    assert adv_check(art, mat, adv_prof(tmp_path, monkeypatch, "small"))["status"] == "PASS"
    xml = ("<animfile>\r\n<component>ModelComp<assetreference type=\"GrannyModel\"><file>buildings" + BS + "advx" + BS +
           f"advx</file><replacetexture><from>{a}</from><to>{x}</to></replacetexture></assetreference></component>"
           "\r\n</animfile>\r\n")
    (art / "buildings" / "advx" / "advx.xml").write_text(xml, encoding="utf-8")
    r = adv_check(art, mat, adv_prof(tmp_path, monkeypatch, "small"))
    assert r["status"] == "FAIL" and "advx_matx_BaseColor 4096 > 2048" in r["summary"] and "advx.xml" in r["summary"]


def test_inc033_intact_damaged_and_construction_are_one_budget(tmp_path, monkeypatch):
    """INC-033: C11: intact 2048 + 1024 and damaged ANOTHER 2048 + 1024 passed medium stage by stage: the model loads 4 pages.
    The construction material (<model>_con) belongs to the same budget"""
    art = adv_tree(tmp_path)
    t = {n: adv_tex(art, f"advx_{n}_BaseColor", sz) for n, sz in (("a", 2048), ("b", 1024), ("d", 2048), ("e", 1024))}
    intact = adv_mat(art, "advx.material", [("a", {"BaseColor": t["a"]}), ("b", {"BaseColor": t["b"]})])
    prof = adv_prof(tmp_path, monkeypatch, "medium")
    assert adv_check(art, intact, prof)["status"] == "PASS"
    adv_mat(art, "advx_damaged.material", [("d", {"BaseColor": t["d"]}), ("e", {"BaseColor": t["e"]})])
    r = adv_check(art, intact, prof)                                   # the damaged sibling joins the budget
    assert r["status"] == "FAIL" and "4 sets > 2" in r["summary"], r["summary"]
    (art / "buildings" / "advx" / "advx_damaged.material").unlink()
    adv_mat(art, "advx_con.material", [("d", {"BaseColor": t["d"]})])
    assert "3 sets > 2" in adv_check(art, intact, prof)["summary"]


def test_inc033_confirmed_by_is_the_owners_message_about_this_class_and_model(tmp_path, monkeypatch):
    """INC-033: C9: confirmed_by m99999 (no such message) and m264 ("yes") passed a large class. The id must resolve to an owner
    message that names the class and the model; no message store = not proven (SKIP, exit 2)"""
    art = adv_tree(tmp_path)
    mat = adv_mat(art, "advx.material", [("a", {"BaseColor": adv_tex(art, "advx_a_BaseColor", 2048)}),
                                         ("b", {"BaseColor": adv_tex(art, "advx_b_BaseColor", 2048)})])
    assert adv_check(art, mat, adv_prof(tmp_path, monkeypatch, "large"))["status"] == "PASS"
    r = adv_check(art, mat, adv_prof(tmp_path, monkeypatch, "large", who="m99999"))
    assert r["status"] == "FAIL" and "m99999 is not an owner message" in r["summary"]
    r = adv_check(art, mat, adv_prof(tmp_path, monkeypatch, "large", who="m264"))
    assert r["status"] == "FAIL" and "does not name the class large" in r["summary"]
    r = adv_check(art, mat, adv_prof(tmp_path, monkeypatch, "large", text="The market is large."))
    assert r["status"] == "FAIL" and "does not name advx" in r["summary"]
    prof = adv_prof(tmp_path, monkeypatch, "large")
    monkeypatch.setattr(L, "owner_message_store", lambda prof: None)
    assert adv_check(art, mat, prof)["status"] == "SKIP"


def test_inc033_a_confirmed_folder_class_covers_only_its_models(tmp_path, monkeypatch):
    """INC-033: the market folder's medium class (m335) covered oriental_house, a house (m336), and trading_port2_Model: a
    confirmed folder class names the models it covers; any other model needs its own per_model class"""
    art = adv_tree(tmp_path)
    mat = adv_mat(art, "advx.material", [("a", {"BaseColor": adv_tex(art, "advx_a_BaseColor", 2048)})])
    prof = adv_prof(tmp_path, monkeypatch, "medium", models=["advx_market"])
    r = adv_check(art, mat, prof)
    assert r["status"] == "FAIL" and "covers advx_market only" in r["summary"]
    prof["texture_budget"]["per_model"] = {"advx": {"class": "small", "status": "proposed, owner to confirm"}}
    assert "class small not confirmed by the owner" in adv_check(art, mat, prof)["summary"]
    market = PROFILES["profiles"]["market"]["texture_budget"]
    assert "oriental_house" not in market["models"] and "trading_port2_Model" not in market["models"]
    assert L.model_class(L.resolve_profile(PROFILES, "market"), "oriental_house").get("confirmed_by") is None


def test_inc033_every_confirmed_folder_class_names_the_models_it_covers():
    """INC-033: no folder class silently covers a different building type: each confirmed class lists its models, and every
    model of the folder (a .gr2 with a .material) is listed or has a per_model entry"""
    for name, v in PROFILES["profiles"].items():
        tb = v["texture_budget"]
        if not tb.get("confirmed_by"):
            continue
        assert tb.get("models") and v.get("names"), name
        folder = REPO / "art" / "buildings" / name
        stems = {L.model_of(g.stem) for g in folder.rglob("*.gr2") if g.with_suffix(".material").exists()
                 and "backup" not in g.parts}
        assert stems <= set(tb["models"]) | set(tb.get("per_model") or {}), (name, stems)


def test_an_unknown_profile_is_refused():
    with pytest.raises(SystemExit):
        L.main(["--profile", "no_such_building", str(KTC), "--no-dll"])


# --------------------------------------------------------------------------------------- vanilla and the CLI
@pytest.mark.parametrize("stem", VANILLA_NON_LARGE)
def test_the_vanilla_sample_passes_the_floor(stem):
    """the 15 non-large vanilla buildings the floor was measured on pass it, per model and per page"""
    need_vanilla(stem)
    need_archive()
    info = L.read_raw(VANILLA / f"{stem}.gr2")
    r = L.check_density("intact", info, VANILLA / f"{stem}.material", None, {"waivers": []}, stem)
    assert r["status"] == "PASS" and r["data"]["verdict"] == "PASS", r["summary"]


def test_the_vanilla_cathedral_is_below_the_universal_floor():
    """large vanilla religious buildings sit below it (median 73); the owner made the floor universal anyway"""
    need_vanilla("cathedral_age4")
    need_archive()
    info = L.read_raw(VANILLA / "cathedral_age4.gr2")
    r = L.check_density("intact", info, VANILLA / "cathedral_age4.material", None, {"waivers": []}, "cathedral_age4")
    assert r["status"] == "FAIL" and ("model_median", None) in {(f["rule"], f["page"]) for f in r["data"]["findings"]}


def test_the_shipped_korean_tc_is_not_cleared(passing_uv_gate, capsys):
    """exit 1 even with --allow-skip: the ceiling and the density floor FAIL on both stages; no game test"""
    assert L.main(["--profile", "korean_tc", str(KTC), "--intact", str(s18k("korean_tc.gr2")), "--damaged",
                   str(s18k("korean_tc_damaged.gr2")), "--no-dll", "--allow-skip"]) == 1
    out = capsys.readouterr().out
    for stage in ("intact", "damaged"):
        assert re.search(rf"{stage} +texture_budget +FAIL", out) and re.search(rf"{stage} +texel_density +FAIL", out)


OWNER_M335_M336 = [
    {"id": "m335", "text": "yes, and 1024+2048 - not only TC. Let's say Medium size buildings (TC + Market + possibly some "
                           "others.... building class can be discussed individually per model"},
    {"id": "m336", "text": "But House is definitely small model f.e."}]


def test_a_generic_profile_runs_the_universal_checks(capsys, tmp_path, monkeypatch):
    """house (small, m336): no orientation / flag / Havok facts, but the ceiling and the floor, from the model's folder"""
    house = REPO / "art" / "buildings" / "house" / "west" / "age_3" / "west_house_SPCa.gr2"
    need(house)
    store = tmp_path / "tasks.json"
    store.write_text(json.dumps({"messages": {"2026-09-30": {"items": OWNER_M335_M336}}}), encoding="utf-8")
    monkeypatch.setattr(L, "owner_message_store", lambda prof: store)
    L.main(["--profile", "house", str(house.parent), "--intact", str(house), "--no-dll", "--allow-skip"])
    out = capsys.readouterr().out
    assert re.search(r"intact +texture_budget +PASS .*class small \(owner m336\)", out)
    assert re.search(r"intact +texel_density +PASS", out)
    assert "orientation" not in out and "flag_on_mast" not in out
