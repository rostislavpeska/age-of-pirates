"""Texture-set coherence rules (scripts/havok/texture_sets.py), generic part.

Incident 2026-10-08 (Korean TC): a review shader bound the new shared atlas colour with the retired revision's normal
and mask maps, and a page move kept the old UVs and tangents. The rules are tested here on a fixture registry and on
AoP's own Corvette (recolour variants that share the default Normals/Masks/Details must stay legal). The Korean
models and their registry live in ../age-of-pirates-koreans (temporary rule, AGENTS.md 15); their live tests are that
repo's tests/test_texture_sets.py.
"""
import json
import shutil
import subprocess
import sys
from pathlib import Path

import numpy as np
import pytest

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "scripts" / "havok"))
sys.dont_write_bytecode = True

import texture_sets as TS  # noqa: E402
import gr2_lint as L  # noqa: E402

ART = REPO / "art"
R2 = "props\\atlas\\textures\\atlas_r2_"
R1 = "props\\atlas\\textures\\atlas_r1_"


@pytest.fixture
def mod(tmp_path):
    """a mod with its own registry: atlas_r2 (current, two regions, T = +dP/du) and atlas_r1 (retired)."""
    reg = {"schema": 1, "sets": [
        {"id": "atlas_r2", "status": "current", "page": [1024, 1024], "tangent": "uv_derivative",
         "channels": {c: {"path": (R2 + c).replace("\\", "/"), "sha256": ""} for c in ("BaseColor", "Normals", "Masks")},
         "preview_sha256": {"Normals": ["ab12cd34ef56" + "0" * 52]},
         "aliases": {"BaseColor": ["atlas_r2_basecolor"], "Normals": ["atlas_r2_normal"], "Masks": ["atlas_r2_masks?"]},
         "regions": [{"role": "left", "box_px": [0, 0, 500, 1024]}, {"role": "right", "box_px": [524, 0, 1024, 1024]}]},
        {"id": "atlas_r1", "status": "retired", "retired_note": "use atlas_r2",
         "channels": {c: {"path": (R1 + c).replace("\\", "/"), "sha256": ""} for c in ("BaseColor", "Normals", "Masks")},
         "aliases": {"BaseColor": ["atlas_r1_basecolor"], "Normals": ["atlas_r1_normal"], "Masks": ["atlas_r1_masks?"]}}]}
    (tmp_path / "tools").mkdir()
    (tmp_path / "tools" / "texture_sets.json").write_text(json.dumps(reg), encoding="utf-8")
    (tmp_path / "art").mkdir()
    return tmp_path


def registry(mod):
    return TS.load_registry(mod / "tools" / "texture_sets.json")


def material(mod, body, name="x.material"):
    p = mod / "art" / name
    p.write_text(f"<material>\n{body}\n</material>\n", encoding="utf-8")
    return p


def block(sub, chans, variant=None, close=True):
    v = f' variant="{variant}"' if variant else ""
    tex = "".join(f'      <texture name="{c}" override="{r}" />\n' for c, r in chans.items())
    head = f'  <submaterial name="{sub}">\n    <materialdef name="default" />\n'
    return head + f"    <parameters{v}>\n{tex}    </parameters>\n" + ("  </submaterial>" if close else "")


# ----------------------------------------------------------------------------------------- registry lookup per mod
def test_each_mod_keeps_its_own_registry(mod):
    assert TS.registry_for(material(mod, block("matc", {}))) == mod / "tools" / "texture_sets.json"
    assert TS.registry_for(REPO / "art" / "units" / "naval" / "corvette" / "corvette.material") == TS.REGISTRY


# ----------------------------------------------------------------------------------- rule 1: one set per binding
def test_mixed_revisions_in_one_binding_fail(mod):
    m = material(mod, block("matc", {"BaseColor": R2 + "BaseColor", "Normals": R1 + "Normals", "Masks": R1 + "Masks"}))
    res = TS.material_findings(m, registry(mod))
    assert any("2 different texture sets" in e for e in res["errors"]), res
    assert any("RETIRED" in e for e in res["errors"]), res


def test_one_revision_passes(mod):
    m = material(mod, block("matc", {c: R2 + c for c in ("BaseColor", "Normals", "Masks")}))
    assert TS.material_findings(m, registry(mod))["errors"] == []


def test_the_lint_check_reads_the_mods_registry(mod):
    m = material(mod, block("matc", {"BaseColor": R2 + "BaseColor", "Normals": R1 + "Normals"}))
    assert L.check_texture_sets("intact", str(m), None)["status"] == "FAIL"


def test_aop_materials_have_no_registry_errors():
    bad = {}
    for m in ART.rglob("*.material"):
        errs = TS.material_findings(m, TS.load_registry(TS.registry_for(m)), ART)["errors"]
        if errs:
            bad[str(m.relative_to(REPO))] = errs
    assert not bad, bad


# --------------------------------------------------------------------------- rule 2: variants (the Corvette pattern)
def test_corvette_recolour_variants_stay_legal():
    res = TS.material_findings(ART / "units/naval/corvette/corvette.material", TS.load_registry(), ART)
    assert res["errors"] == [] and res["warnings"] == [], res


def test_corvette_recolours_share_the_default_layout():
    """content signal (report only): a recolour keeps the default BaseColor's structure (calibrated 0.95)"""
    pytest.importorskip("scipy")
    res = TS.material_findings(ART / "units/naval/corvette/corvette.material", TS.load_registry(), ART, TS.content_checker(ART))
    rs = [c["r"] for c in res["content"] if c["channel"] == "basecolor"]
    assert len(rs) >= 2 and min(rs) > 0.9, res["content"]


def test_reskin_from_two_sources_is_reported_not_failed(mod):
    body = (block("mata", {"BaseColor": "a\\x_mata_BaseColor", "Normals": "a\\x_mata_Normals"}, close=False)
            + block("mata", {"BaseColor": "a\\y_mata_BaseColor", "Normals": "a\\z_mata_Normals"}, variant=1).split("    <materialdef name=\"default\" />\n", 1)[1])
    res = TS.material_findings(material(mod, body), registry(mod))
    assert res["errors"] == [] and any("re-skin" in w for w in res["warnings"]), res


# --------------------------------------------------------------------- Blender preview images (the live incident)
def test_preview_images_resolve_by_alias_and_hash_prefix(mod):
    reg = registry(mod)
    assert TS.set_of_image(reg, "atlas_r2_BaseColor.png")[0] == "atlas_r2"
    assert TS.set_of_image(reg, "atlas_r1_Normal.png.001")[0] == "atlas_r1"
    assert TS.set_of_image(reg, "ab12cd34ef56_some_normal.png")[0] == "atlas_r2"
    assert TS.set_of_image(reg, "STANDARD Blender Color Grid 2048") is None


def test_a_preview_mix_is_caught(mod):
    reg = registry(mod)
    bound = {"basecolor": TS.set_of_image(reg, "atlas_r2_BaseColor.png")[0], "normals": TS.set_of_image(reg, "atlas_r1_Normal.png")[0]}
    assert any("2 different texture sets" in e for e in TS.binding_findings(bound, reg, "review"))


# ------------------------------------------------------------- rules 3 + 4 on a model: atlas regions, tangents
def quad_model(u0, u1, flip_tangent=False):
    """one quad (2 triangles) bound to material 'matc' with UVs u0..u1 (raw GR2, v down) and tangents along +dP/du."""
    pos = np.array([[0, 0, 0], [1, 0, 0], [1, 1, 0], [0, 1, 0]], float)
    uv = np.array([[u0, 0.1], [u1, 0.1], [u1, 0.9], [u0, 0.9]], float)
    tan = np.tile([127, 0, 0, -128], (4, 1)).astype(float) * (-1 if flip_tangent else 1)
    return {"render": [dict(pos=pos, uv=uv, tan=tan, tris=np.array([[0, 1, 2], [0, 2, 3]]), groups=[(0, 0, 2)], mats=["matc"])]}


def test_faces_across_a_region_border_fail_and_inside_pass(mod):
    m = material(mod, block("matc", {c: R2 + c for c in ("BaseColor", "Normals", "Masks")}))
    reg = registry(mod)
    assert TS.region_findings(quad_model(0.05, 0.40), m, reg)[:2] == (2, 0)
    assert TS.region_findings(quad_model(0.30, 0.70), m, reg)[:2] == (2, 2)          # crosses the 500..524 px gap
    assert L.check_atlas_regions("intact", quad_model(0.30, 0.70), str(m))["status"] == "FAIL"


def test_tangents_against_the_declared_convention(mod):
    m = material(mod, block("matc", {c: R2 + c for c in ("BaseColor", "Normals", "Masks")}))
    reg = registry(mod)
    assert TS.tangent_findings(quad_model(0.05, 0.40), m, reg)[0][2] == 1.0
    assert TS.tangent_findings(quad_model(0.05, 0.40, flip_tangent=True), m, reg)[0][2] == 0.0


# ---------------------------------------------------------------------- Blender-side checker (this PC's Blender)
def blender_exe():
    cfg = REPO / "config" / "tool-paths.local.json"
    try:
        p = Path(json.loads(cfg.read_text(encoding="utf-8"))["tools"]["blender"]["path"])
    except (OSError, KeyError, ValueError):
        p = None
    if p and p.is_file():
        return p
    w = shutil.which("blender")
    return Path(w) if w else None


def test_blender_checker_flags_a_mixed_preview_material(mod, tmp_path):
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
        "for label, pair in (('mixed', ('atlas_r2_BaseColor.png', 'atlas_r1_Normal.png')), ('clean', ('atlas_r2_BaseColor.png', 'atlas_r2_Normal.png'))):\n"
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
    subprocess.run([str(exe), "-b", str(tmp_path / "probe.blend"), "--python", str(checker), "--", str(out), str(REPO),
                    str(mod / "tools" / "texture_sets.json")], capture_output=True, timeout=300, check=True)
    rep = json.loads(out.read_text(encoding="utf-8"))
    by = {m["material"]: m["errors"] for m in rep["materials"]}
    assert any("2 different texture sets" in e for e in by["mixed"]), rep
    assert by["clean"] == [], rep
