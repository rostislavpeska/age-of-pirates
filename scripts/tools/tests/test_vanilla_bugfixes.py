"""Deliberate vanilla bugfixes in data/protomods.xml must survive (_proto.py runs the same check in CI on every push).

Artillery load delay on ships: the mod removes ONLY the slow AbstractArtillery load entry; artillery keeps boarding
through LogicalTypeGarrisonInShips. Owner 2026-09-26: "we do NOT remove artillery capacity. We only remove the
delay!!!!! This is a vanilla bugfix, should be monitored so no agent unintentionally fixes it."

    python -m pytest scripts/tools/tests/test_vanilla_bugfixes.py -q
"""
from __future__ import annotations

import copy
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO))
sys.dont_write_bytecode = True

import _proto  # noqa: E402

PROTOMODS = ET.parse(REPO / "data" / "protomods.xml").getroot()
SNAPSHOT = str(REPO / _proto.VANILLA_SNAPSHOT)


def unit(root, name):
    return next(u for u in root.findall("./unit") if u.get("name") == name)


def test_the_artillery_load_delay_fix_is_intact():
    errors, warnings = _proto.check_vanilla_bugfixes(PROTOMODS, SNAPSHOT)
    assert errors == [], errors
    assert warnings == [], warnings


def test_deleting_the_removal_line_fails():
    root = copy.deepcopy(PROTOMODS)
    u = unit(root, "ypWokouJunk")
    for c in list(u.findall("contain")):
        if (c.text or "").strip() == "AbstractArtillery":
            u.remove(c)
    errors, _ = _proto.check_vanilla_bugfixes(root, SNAPSHOT)
    assert any("load-delay fix missing" in e and "ypWokouJunk" in e for e in errors)


def test_cutting_the_capacity_fails():
    root = copy.deepcopy(PROTOMODS)
    ET.SubElement(unit(root, "Frigate"), "contain", {"mergeMode": "remove"}).text = "LogicalTypeGarrisonInShips"
    errors, _ = _proto.check_vanilla_bugfixes(root, SNAPSHOT)
    assert any("capacity cut" in e and "Frigate" in e for e in errors)


def test_the_corvette_delay_coming_back_fails():
    root = copy.deepcopy(PROTOMODS)
    c = ET.SubElement(unit(root, "zpCorvette"), "contain", {"indelay": "3.0", "outdelay": "0.0"})
    c.text = "AbstractArtillery"
    errors, _ = _proto.check_vanilla_bugfixes(root, SNAPSHOT)
    assert any("zpCorvette" in e and "delayed" in e for e in errors)


# vanilla ships newer than the Oct-2025 snapshot: LogicalTypeGarrisonInShips checked in the LIVE protoy on 2026-09-26
NEWER_THAN_SNAPSHOT = {"deGuardianNavalWhaler", "deOutlawWhalingShip"}


def test_every_fixed_ship_still_boards_artillery_in_vanilla():
    # the fix is only safe while vanilla keeps LogicalTypeGarrisonInShips on the ship (artillery carries that type)
    snap = {u.get("name"): u for u in ET.parse(SNAPSHOT).getroot().iter("unit")}
    for name in _proto.ARTILLERY_LOAD_DELAY_FIX - NEWER_THAN_SNAPSHOT:
        assert name in snap, f"{name} not in the vanilla snapshot"
        assert _proto._contains(snap[name], "LogicalTypeGarrisonInShips", False), name
