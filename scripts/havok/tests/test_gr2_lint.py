"""gr2_lint.py on the Korean TC specimens: each in-game defect must FAIL its check, the fixed files must PASS.

    python -m pytest scripts/havok/tests/test_gr2_lint.py -q

Specimens outside the repo (session scratchpad backups, never committed) are skipped when absent; set
GR2_LINT_SPECIMENS to their folder on another device. The installed model in art/buildings/korean_tc is always there.
The DLL test needs WSL + Wine + gr2_to_raw.py (skipped otherwise).
"""
from __future__ import annotations

import copy
import os
import sys
from pathlib import Path

import numpy as np
import pytest

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "scripts" / "havok"))
sys.dont_write_bytecode = True

import gr2_lint as L  # noqa: E402

KTC = REPO / "art" / "buildings" / "korean_tc"
SPEC = Path(os.environ.get("GR2_LINT_SPECIMENS", Path.home() / "AppData/Local/Temp/claude/"
            "C--Users-rosti-Games-Age-of-Empires-3-DE-76561199512878537-mods-local-age-of-pirates/"
            "606bcdfd-b93c-4bed-807e-4732d03a4805/scratchpad"))
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
    files = dict(intact=str(KTC / "korean_tc.gr2"), hkt=str(KTC / "korean_tc_damaged.hkt"),
                 intact_material=str(KTC / "korean_tc.material"), damaged_material=str(KTC / "korean_tc_damaged.material"))
    files.update(kw)
    res = L.lint(PROF, **files, use_dll=False, art_root=REPO / "art")
    return {(r["stage"], r["check"]): r for r in res}


def status(res, stage, check):
    return res[(stage, check)]["status"]


@pytest.fixture(scope="module")
def installed_intact():
    return L.read_raw(KTC / "korean_tc.gr2")


# ------------------------------------------------------------------------------------------------ the specimens
def test_installed_intact_passes():
    res = run(damaged=None, hkt=None, animfile=str(KTC / "korean_tc.xml"))
    bad = {k: v["summary"] for k, v in res.items() if v["status"] == "FAIL"}
    assert not bad, bad
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


def test_cli_exit_codes():
    need(OLD_DAMAGED)
    intact_only = ["--profile", "korean_tc", str(KTC), "--intact", str(KTC / "korean_tc.gr2"), "--only", "intact"]
    assert L.main(intact_only + ["--no-dll"]) == 2                 # dll_read SKIP: not proven to load in the game
    assert L.main(intact_only + ["--no-dll", "--allow-skip"]) == 0
    assert L.main(["--profile", "korean_tc", str(KTC), "--damaged", str(OLD_DAMAGED), "--no-dll"]) == 1


def test_exit_code_rules():
    ok, skip, fail = dict(status="PASS"), dict(status="SKIP"), dict(status="FAIL")
    assert L.exit_code([ok, ok]) == 0
    assert L.exit_code([ok, skip]) == 2 and L.exit_code([ok, skip], allow_skip=True) == 0
    assert L.exit_code([skip, fail]) == 1 and L.exit_code([fail], allow_skip=True) == 1


def test_missing_dll_tools_exit_2(monkeypatch):
    """the tools folder is missing: dll_read SKIP must not clear the model (was exit 0, 2026-09-29 review)"""
    monkeypatch.setattr(L, "find_tools", lambda profiles: Path("Z:/no/tools"))
    assert L.main(["--profile", "korean_tc", str(KTC), "--intact", str(KTC / "korean_tc.gr2"), "--only", "intact"]) == 2
