"""Tests for the RM tool library: patchfile, unitbench (template + spine guard), xmb_idcheck.

    python -m pytest scripts/tools/tests -q
"""
from __future__ import annotations

import sys
from pathlib import Path
import xml.etree.ElementTree as ET

import pytest

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO))
sys.path.insert(0, str(REPO / "scripts" / "tools"))

import patchfile      # noqa: E402
import unitbench      # noqa: E402
import xmb_idcheck    # noqa: E402


# ------------------------------------------------------------------------------------ patchfile
def test_patch_preserves_crlf_and_encoding(tmp_path):
    p = tmp_path / "a.xml"
    p.write_bytes(b"<a>\r\n  <b>x</b>\r\n</a>\r\n")
    pt = patchfile.Patch(p)
    pt.replace("<b>x</b>", "<b>y</b>").write()
    raw = p.read_bytes()
    assert raw == b"<a>\r\n  <b>y</b>\r\n</a>\r\n"
    assert b"\n" not in raw.replace(b"\r\n", b"")


def test_patch_refuses_ambiguous_anchor(tmp_path):
    p = tmp_path / "a.txt"
    p.write_bytes(b"x\r\nx\r\n")
    with pytest.raises(patchfile.PatchError):
        patchfile.Patch(p).replace("x", "y")
    assert p.read_bytes() == b"x\r\nx\r\n"          # nothing written


def test_patch_insert_before_and_after(tmp_path):
    p = tmp_path / "a.txt"
    p.write_bytes(b"one\nTWO\nthree\n")
    pt = patchfile.Patch(p)
    pt.insert_before("TWO\n", "before\n").insert_after("TWO\n", "after\n").write()
    assert p.read_bytes() == b"one\nbefore\nTWO\nafter\nthree\n"
    assert not pt.crlf


def test_patch_write_is_noop_without_change(tmp_path):
    p = tmp_path / "a.txt"
    p.write_bytes(b"abc\r\n")
    assert patchfile.Patch(p).write() is False


# ------------------------------------------------------------------------------------ unitbench
def test_render_contains_spine_and_substitutions():
    xs, xml = unitbench.render("000_t", "zpSomething", "House", 24, 1)
    for line in unitbench.SPINE:
        assert line in xs
    assert '"zpSomething"' in xs and '"House"' in xs
    assert "\r\n" in xs and "\n" not in xs.replace("\r\n", "")
    assert 'displayName = "000_t"' in xml


def test_render_refuses_when_spine_stripped(monkeypatch):
    monkeypatch.setattr(unitbench, "XS_TEMPLATE", unitbench.XS_TEMPLATE.replace("chooseMercs();", ""))
    with pytest.raises(SystemExit):
        unitbench.render("000_t", "A", "House", 24, 1)


def test_template_has_no_hidden_leftovers():
    xs, xml = unitbench.render("000_t", "A", "B", 10, 0)
    for k in ("{PROTO}", "{CONTROL}", "{DIST}", "{OWNER}", "{STEM}", "{BS}"):
        assert k not in xs and k not in xml
    assert "rmTerrainInitialize(\"deccan" + chr(92) + "ground_grass3_deccan\", 1.0);" in xs


def test_variant_grid_places_every_subject_once():
    names = ["zzA", "zzB", "zzC", "zzD", "zzE"]
    xs, xml = unitbench.render("000_t", names, "House", 24, 1, cols=3, spacing=36, rowgap=44)
    for i, n in enumerate(names, 1):
        assert xs.count(f'rmAddObjectDefItem(benchSubject{i}ID, "{n}", 1, 0.0);') == 1
        assert xs.count(f"rmPlaceObjectDefAtLoc(benchSubject{i}ID, 1,") == 1
    assert "benchSubjectID" not in xs and "rmPlacePlayersCircular(0.42, 0.42, 0.0);" in xs
    for k in ("{PROTO}", "{CONTROL}", "{OWNER}", "{LAYOUT}", "{BENCH}", "{RING}", "{DETAILS}", "{X}", "{Z}"):
        assert k not in xs and k not in xml
    # rows run screen-horizontally: subjects 1..3 share one camera depth, x + z equal; the back row sits 44 m deeper
    slots, rows = unitbench.grid_slots(5, 3, 36, 44)
    assert rows == 2 and [s[1] for s in slots] == [-22, -22, -22, 22, 22]
    assert [s[0] for s in slots] == [-36, 0, 36, -18, 18]


# ------------------------------------------------------------------------------------ xmb_idcheck
def test_bad_text_flags_identifier_with_newline():
    root = ET.fromstring("<r><route a='1'>arctic1\n    <straight>x</straight></route>"
                         "<from>arctic1\n</from><desc>free\ntext</desc><ok>clean</ok></r>")
    flagged = [e.tag for e in root.iter() if xmb_idcheck.bad_text(e)]
    assert flagged == ["route", "from"]


def test_scan_tree_reports_label():
    root = ET.fromstring("<r><to> x </to></r>")
    out = xmb_idcheck.scan_tree(root, "XMLWS")
    assert out and out[0][0] == "XMLWS" and out[0][1] == "to"
