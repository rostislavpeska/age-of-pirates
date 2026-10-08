"""Texture-set coherence (scripts/havok/texture_sets.py, config/texture_sets.json).

Incident 2026-10-08: the Korean review scene bound r65 BaseColor with v2 Normals/Masks on v2 UVs, and the Town Center
still drew its backing from the 512 TC page while the rest of the Korean set used the shared r65 atlas. These tests
pin the rules that catch both, and the Corvette pattern that must stay legal (recolour variants that share the
default Normals/Masks/Details).
"""
import json
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "scripts" / "havok"))
sys.dont_write_bytecode = True

import texture_sets as TS  # noqa: E402
from gr2_lint import read_raw  # noqa: E402

ART = REPO / "art"
REG = TS.load_registry()
KOREAN_TEXTURE_DIRS = ("buildings/korean_tc/textures", "buildings/korean_shared/textures",
                       "zbench_korean_military/barracks/textures", "zbench_korean_military/stable/textures")


def material(tmp_path, body):
    p = tmp_path / "x.material"
    p.write_text(f"<material>\n{body}\n</material>\n", encoding="utf-8")
    return p


def block(sub, chans, variant=None):
    v = f' variant="{variant}"' if variant else ""
    tex = "".join(f'      <texture name="{c}" override="{r}" />\n' for c, r in chans.items())
    return f'  <submaterial name="{sub}">\n    <materialdef name="default" />\n    <parameters{v}>\n{tex}    </parameters>\n  </submaterial>'


R65 = "buildings\\korean_shared\\textures\\korean_shared_matc_r65_"
V2 = "buildings\\korean_shared\\textures\\korean_shared_matc_v2_"


# ------------------------------------------------------------------------------------------- the registry itself
def test_registry_current_sets_match_the_installed_files():
    assert REG, "config/texture_sets.json missing"
    for s in REG["sets"]:
        if s["status"] != "current":
            continue
        for ch, row in s["channels"].items():
            p = ART / (row["path"] + ".ddt")
            assert p.exists(), (s["id"], ch, p)
            assert TS.sha256(p) == row["sha256"], f"{s['id']} {ch}: the registry pins another revision of {p.name}"


def test_retired_sets_are_gone_from_the_game_and_unreferenced():
    retired = [r["path"] for s in REG["sets"] if s["status"] == "retired" for r in s["channels"].values()]
    assert retired
    for rel in retired:
        assert not (ART / (rel + ".ddt")).exists(), f"one atlas copy only: {rel} is retired"
    refs = {TS.norm_ref(r) for r in retired}
    for m in ART.rglob("*.material"):
        for _, _, b in TS.parse_material(m.read_text(encoding="utf-8", errors="replace")):
            assert not refs & {TS.norm_ref(r) for r in b.values()}, m


def test_every_korean_own_texture_is_registered():
    """a new revision cannot slip past rule 1: every own Korean DDT belongs to a registered set"""
    known = set(REG["_by_ref"])
    for d in KOREAN_TEXTURE_DIRS:
        for p in (ART / d).glob("*.ddt"):
            ref = TS.norm_ref(p.relative_to(ART).with_suffix("").as_posix())
            assert ref in known, f"register {p.relative_to(ART)} in config/texture_sets.json"


# ----------------------------------------------------------------------------------- rule 1: one set per binding
def test_mixed_revisions_in_one_binding_fail(tmp_path):
    m = material(tmp_path, block("matc", {"BaseColor": R65 + "BaseColor", "Normals": V2 + "Normals", "Masks": V2 + "Masks"}))
    res = TS.material_findings(m, REG, ART)
    assert any("2 different texture sets" in e for e in res["errors"]), res
    assert any("RETIRED" in e for e in res["errors"]), res


def test_one_revision_passes(tmp_path):
    m = material(tmp_path, block("matc", {c: R65 + c for c in ("BaseColor", "Normals", "Masks")}))
    assert TS.material_findings(m, REG, ART)["errors"] == []


def test_installed_korean_and_all_aop_materials_have_no_registry_errors():
    bad = {}
    for m in ART.rglob("*.material"):
        errs = TS.material_findings(m, REG, ART)["errors"]
        if errs:
            bad[str(m.relative_to(REPO))] = errs
    assert not bad, bad


# --------------------------------------------------------------------------- rule 2: variants (the Corvette pattern)
def test_corvette_recolour_variants_stay_legal():
    res = TS.material_findings(ART / "units/naval/corvette/corvette.material", REG, ART)
    assert res["errors"] == [] and res["warnings"] == [], res


def test_corvette_recolours_share_the_default_layout():
    """content signal (report only): a recolour keeps the default BaseColor's structure (calibrated 0.95)"""
    pytest.importorskip("scipy")
    res = TS.material_findings(ART / "units/naval/corvette/corvette.material", REG, ART, TS.content_checker(ART))
    rs = [c["r"] for c in res["content"] if c["channel"] == "basecolor"]
    assert len(rs) >= 2 and min(rs) > 0.9, res["content"]


def test_reskin_from_two_sources_is_reported_not_failed(tmp_path):
    body = (block("mata", {"BaseColor": "a\\x_mata_BaseColor", "Normals": "a\\x_mata_Normals", "Masks": "a\\x_mata_Masks"})
            .replace("  </submaterial>", "") + "\n    <parameters variant=\"1\">\n"
            '      <texture name="BaseColor" override="a\\y_mata_BaseColor" />\n'
            '      <texture name="Normals" override="a\\z_mata_Normals" />\n    </parameters>\n  </submaterial>')
    res = TS.material_findings(material(tmp_path, body), REG, ART)
    assert res["errors"] == [] and any("re-skin" in w for w in res["warnings"]), res


# --------------------------------------------------------------------- Blender preview images (the live incident)
def test_preview_images_resolve_to_their_sets():
    assert TS.set_of_image(REG, "shared_r65_BaseColor.png")[0] == "korean_shared_matc_r65"
    assert TS.set_of_image(REG, "MATC_V2_Normal.png.001")[0] == "korean_shared_matc_v2"
    assert TS.set_of_image(REG, "26f76a47d69a_26f76a47d69a_MATC_V2_Masks.png")[0] == "korean_shared_matc_v2"
    assert TS.set_of_image(REG, "MATC_BaseColor.png")[0] == "korean_tc_matc_v1"
    assert TS.set_of_image(REG, "6f3f0fe4c347_MATC_BaseColor.png")[0] == "korean_tc_matc_v1"
    assert TS.set_of_image(REG, "STANDARD Blender Color Grid 2048") is None


def test_the_review_scene_mix_is_caught():
    bound = {"basecolor": TS.set_of_image(REG, "shared_r65_BaseColor.png")[0],
             "normals": TS.set_of_image(REG, "MATC_V2_Normal.png")[0],
             "masks": TS.set_of_image(REG, "MATC_V2_Masks.png")[0]}
    errs = TS.binding_findings(bound, REG, "barracks | r60-library-v3")
    assert any("2 different texture sets" in e for e in errs), errs


# ------------------------------------------------------------- rules 3 + 4 on the models (gr2): regions, tangents
KOREAN_MODELS = [("buildings/korean_tc/korean_tc.gr2", "buildings/korean_tc/korean_tc.material"),
                 ("buildings/korean_tc/korean_tc_damaged.gr2", "buildings/korean_tc/korean_tc_damaged.material"),
                 ("buildings/korean_tc/korean_tc_con.gr2", "buildings/korean_tc/korean_tc_con.material"),
                 ("zbench_korean_military/barracks/korean_barracks_physics.gr2", "zbench_korean_military/barracks/korean_barracks_physics.material"),
                 ("zbench_korean_military/barracks/korean_barracks_physics_damaged.gr2", "zbench_korean_military/barracks/korean_barracks_physics_damaged.material"),
                 ("zbench_korean_military/stable/korean_stable_physics.gr2", "zbench_korean_military/stable/korean_stable_physics.material"),
                 ("zbench_korean_military/stable/korean_stable_physics_damaged.gr2", "zbench_korean_military/stable/korean_stable_physics_damaged.material")]


@pytest.mark.parametrize("gr2,mat", KOREAN_MODELS)
def test_installed_korean_models_sit_inside_the_atlas_regions_with_its_tangents(gr2, mat):
    info = read_raw(ART / gr2)
    checked, outside, sets = TS.region_findings(info, ART / mat, REG)
    assert checked and outside == 0 and sets == ["korean_shared_matc_r65"], (checked, outside, sets)
    rows = [r for r in TS.tangent_findings(info, ART / mat, REG) if r[3] >= 50]
    assert rows and all(share >= 0.9 for _, _, share, _ in rows), rows


def s18k_damaged(tmp_path):
    out = tmp_path / "korean_tc_damaged_s18k.gr2"
    r = subprocess.run(["git", "-C", str(REPO), "show", "ba233e90:art/buildings/korean_tc/korean_tc_damaged.gr2"],
                       capture_output=True, timeout=120)
    if r.returncode or not r.stdout:
        pytest.skip("the S18k specimen is not in this clone")
    out.write_bytes(r.stdout)
    return out


def test_a_path_swap_without_uv_remap_and_tangents_is_caught(tmp_path):
    """the shipped S18k damaged TC (backing on the old 512 page, TC tangents) bound to the r65 material: the faces
    cross region borders and carry the opposite tangent convention."""
    info = read_raw(s18k_damaged(tmp_path))
    mat = ART / "buildings/korean_tc/korean_tc_damaged.material"
    checked, outside, _ = TS.region_findings(info, mat, REG)
    assert checked and outside / checked > 0.2, (checked, outside)          # measured 7,836 / 20,357 cross a border
    import gr2_lint as L
    assert L.check_atlas_regions("damaged", info, mat)["status"] == "FAIL"
    assert L.check_tangent_convention("damaged", info, mat)["status"] == "FAIL"
    r65 = [r for r in TS.tangent_findings(info, mat, REG) if r[0] == "korean_shared_matc_r65"]
    assert r65 and r65[0][2] < 0.1, r65


# ---------------------------------------------------------------------- Blender-side checker (this PC's Blender)
def blender_exe():
    cfg = REPO / "config" / "tool-paths.local.json"
    try:
        p = Path(json.loads(cfg.read_text(encoding="utf-8"))["tools"]["blender"]["path"])
    except (OSError, KeyError, ValueError):
        return None
    return p if p.is_file() else (shutil.which("blender") and Path(shutil.which("blender")))


def test_blender_checker_flags_a_mixed_preview_material(tmp_path):
    exe = blender_exe()
    if not exe:
        pytest.skip("no Blender on this machine (config/tool-paths.local.json)")
    build = tmp_path / "build.py"
    build.write_text(
        "import bpy, sys\n"
        "from pathlib import Path\n"
        "d = Path(sys.argv[sys.argv.index('--') + 1])\n"
        "bpy.ops.wm.read_factory_settings(use_empty=True)\n"
        "def img(name):\n"
        "    im = bpy.data.images.new(name, 4, 4); im.filepath_raw = str(d / name); im.file_format = 'PNG'; im.save(); return im\n"
        "for label, pair in (('mixed', ('shared_r65_BaseColor.png', 'MATC_V2_Normal.png')), ('clean', ('shared_r65_BaseColor.png', 'r65_Normal.png'))):\n"
        "    m = bpy.data.materials.new(label); m.use_nodes = True; nt = m.node_tree; b = nt.nodes['Principled BSDF']\n"
        "    t1 = nt.nodes.new('ShaderNodeTexImage'); t1.image = img(pair[0]); nt.links.new(t1.outputs['Color'], b.inputs['Base Color'])\n"
        "    t2 = nt.nodes.new('ShaderNodeTexImage'); t2.image = img(pair[1]); nm = nt.nodes.new('ShaderNodeNormalMap')\n"
        "    nt.links.new(t2.outputs['Color'], nm.inputs['Color']); nt.links.new(nm.outputs['Normal'], b.inputs['Normal'])\n"
        "    me = bpy.data.meshes.new(label); me.from_pydata([(0,0,0),(1,0,0),(0,1,0)], [], [(0,1,2)]); me.materials.append(m)\n"
        "    bpy.context.scene.collection.objects.link(bpy.data.objects.new(label, me))\n"
        "bpy.ops.wm.save_as_mainfile(filepath=str(d / 'probe.blend'))\n", encoding="utf-8")
    subprocess.run([str(exe), "-b", "--factory-startup", "--python", str(build), "--", str(tmp_path)],
                   capture_output=True, timeout=300, check=True)
    out = tmp_path / "report.json"
    checker = REPO / ".claude/skills/aoe-uv-atlas-export/scripts/blender_texture_sets.py"
    subprocess.run([str(exe), "-b", str(tmp_path / "probe.blend"), "--python", str(checker), "--", str(out), str(REPO)],
                   capture_output=True, timeout=300, check=True)
    rep = json.loads(out.read_text(encoding="utf-8"))
    by = {m["material"]: m["errors"] for m in rep["materials"]}
    assert any("2 different texture sets" in e for e in by["mixed"]), rep
    assert by["clean"] == [], rep
