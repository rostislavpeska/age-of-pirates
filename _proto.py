###############################################################################
# This script checks if the protomods.xml file follows a certain set of rules
# and forces a status check failure if it doesn't.
###############################################################################

import xml.etree.ElementTree as ET
import os
import re


def print_info(msg):
    print(f"\033[94m{msg}\033[0m")


def print_success(msg):
    print(f"\033[92m{msg}\033[0m")


def print_warning(msg):
    print(f"\033[93m{msg}\033[0m")


def print_error(msg):
    print(f"\033[91m{msg}\033[0m")


# ---- DELIBERATE VANILLA BUGFIXES: never "fix" these back ---------------------------------------------------------
# Artillery load delay on ships (b4621763 + a3bbd8cd, 2024-02). A vanilla ship lists AbstractArtillery WITH a load
# delay (indelay) next to LogicalTypeGarrisonInShips; artillery carries both unit types, so it boarded with the slow
# delay. The mod removes ONLY that delay entry (<contain mergeMode='remove'>AbstractArtillery</contain>); artillery
# still boards through LogicalTypeGarrisonInShips, so the capacity is unchanged. Owner 2026-09-26: "we do NOT remove
# artillery capacity. We only remove the delay!!!!! This is a vanilla bugfix, should be monitored so no agent
# unintentionally fixes it." Removing a ship from this list is the owner's approval step.
ARTILLERY_LOAD_DELAY_FIX = frozenset({
    "Canoe", "Caravel", "DEFlatBoatNoCondition", "FishingBoat", "Fluyt", "Frigate", "Galleon", "Galley",
    "IGCFishingBoat", "IGCGalleon", "Monitor", "Privateer", "SPCDinghy", "SPCFrigate", "SPCLizzieFlagship",
    "SPCMorganFlagship", "SPCTreasureShip", "SPCTreasureShip2", "SPCXPFlatBoat", "SPCXPTreasureShip",
    "deAfricanCatamaran", "deBattleCanoe", "deCannonBoat", "deChinchaRaft", "deDinghy", "deFishingBoatAfrican",
    "deGalleass", "deMercBattleship", "deMercDhow", "deMercXebec", "deOrderGalley", "dePrivateerGuardian",
    "deSPCCorsairShip", "deSPCFrigate", "deSPCPhiladelphia", "deSPCPrivateer", "deSPCRowboat", "deSloop",
    "deStartingUnitPrivateer", "deSteamer", "xpIronclad", "xpTlalocCanoe", "xpWarCanoe", "ypAtakabune",
    "ypCatamaran", "ypFishingBoatAsian", "ypFishingBoatIndians", "ypFuchuan", "ypFune", "ypGreatWhiteShark",
    "ypIGCTreasureShip", "ypJunk", "ypMarathanCatamaran", "ypOrca", "ypTekkousen", "ypWarJunk",
    "ypWarJunkSittingDucks", "ypWokouJunk",
    "deGuardianNavalWhaler", "deOutlawWhalingShip",       # newer vanilla ships, added 2026-09-26 (not in the snapshot)
})
# The mod's own ships: no delayed AbstractArtillery entry at all (owner 2026-09-26: the Corvette's 3.0 s delay "is a
# bug, strip the delay"); artillery boards through LogicalTypeGarrisonInShips like on the fixed vanilla ships.
MOD_SHIPS_WITHOUT_ARTILLERY_DELAY = frozenset({"zpCorvette"})
VANILLA_SNAPSHOT = "scripts/source/protoy.xml"   # in-repo vanilla snapshot (CI has no game install)


def _contains(unit, text, removed):
    for c in unit.findall("contain"):
        mode = (c.get("mergeMode") or c.get("mergemode") or "").lower()
        if (c.text or "").strip() == text and (mode == "remove") == removed:
            return True
    return False


def check_vanilla_bugfixes(root, snapshot=VANILLA_SNAPSHOT):
    """Errors and warnings for the deliberate vanilla bugfixes above (used by validate_protomods and the tests)."""
    errors, warnings = [], []
    by_name = {}
    for unit in root.findall("./unit"):
        by_name.setdefault(unit.attrib.get("name", "").strip(), []).append(unit)
    why = "vanilla bugfix: the mod removes only the artillery LOAD DELAY, never the capacity (owner 2026-09-26)"
    lost = sorted(n for n in ARTILLERY_LOAD_DELAY_FIX
                  if not any(_contains(u, "AbstractArtillery", True) for u in by_name.get(n, [])))
    if lost:
        errors.append("❌ Artillery load-delay fix missing - restore <contain mergeMode='remove'>AbstractArtillery"
                      "</contain> on: " + ", ".join(lost) + " (" + why + ")")
    cut = sorted(n for n in ARTILLERY_LOAD_DELAY_FIX for u in by_name.get(n, [])
                 if _contains(u, "LogicalTypeGarrisonInShips", True) or (u.findtext("maxcontained") or "").strip() == "0")
    if cut:
        errors.append("❌ Artillery capacity cut on: " + ", ".join(cut) + " - LogicalTypeGarrisonInShips removed or "
                      "maxcontained 0 (" + why + ")")
    for n in sorted(MOD_SHIPS_WITHOUT_ARTILLERY_DELAY):
        us = by_name.get(n, [])
        if any(_contains(u, "AbstractArtillery", False) for u in us):
            errors.append(f"❌ {n}: delayed AbstractArtillery load entry is back - strip it ({why})")
        if not any(_contains(u, "LogicalTypeGarrisonInShips", False) for u in us):
            errors.append(f"❌ {n}: LogicalTypeGarrisonInShips missing - artillery could not board ({why})")
    extra = sorted(n for n, us in by_name.items() if n not in ARTILLERY_LOAD_DELAY_FIX
                   and any(_contains(u, "AbstractArtillery", True) for u in us))
    if extra:
        warnings.append("⚠️ More ships carry the artillery load-delay fix than ARTILLERY_LOAD_DELAY_FIX lists: "
                        + ", ".join(extra) + " - add them to the list")
    if os.path.isfile(snapshot):
        snap = {}
        for unit in ET.parse(snapshot).getroot().iter("unit"):
            snap.setdefault(unit.attrib.get("name", "").strip(), unit)
        noboard = sorted(n for n in ARTILLERY_LOAD_DELAY_FIX
                         if n in snap and not _contains(snap[n], "LogicalTypeGarrisonInShips", False))
        if noboard:
            errors.append("❌ Vanilla " + ", ".join(noboard) + " no longer list LogicalTypeGarrisonInShips: removing "
                          "their AbstractArtillery entry would now cut the capacity - owner decision needed")
    return errors, warnings


def validate_protomods(xml_file):
    errors = []
    warnings = []

    duplicate_names = {}
    duplicate_ids = {}
    duplicate_dbids = {}

    try:
        tree = ET.parse(xml_file)
        root = tree.getroot()

        id_set = {}
        name_set = {}
        dbid_set = {}

        for unit in root.findall("./unit"):
            unit_id = unit.attrib.get("id", "").strip()
            unit_name = unit.attrib.get("name", "").strip()
            unit_dbid_element = unit.find("dbid")
            unit_dbid = (
                unit_dbid_element.text.strip()
                if unit_dbid_element is not None and unit_dbid_element.text is not None
                else ""
            )

            if unit_name:
                unit_name_lower = unit_name.lower()
                if unit_name_lower in name_set:
                    duplicate_names[unit_name_lower] = (
                        duplicate_names.get(unit_name_lower, 0) + 1
                    )
                else:
                    name_set[unit_name_lower] = unit_id

            if unit_id:
                if unit_id in id_set:
                    duplicate_ids[unit_id] = duplicate_ids.get(unit_id, 0) + 1
                else:
                    id_set[unit_id] = unit_name

            if unit_dbid:
                if unit_dbid in dbid_set:
                    duplicate_dbids[unit_dbid] = duplicate_dbids.get(unit_dbid, 0) + 1
                else:
                    dbid_set[unit_dbid] = unit_name

            if unit_name and not re.match(r"^[a-zA-Z][a-zA-Z0-9]*$", unit_name):
                warnings.append(
                    f"⚠️ Unit name {unit_name} does not match the ideal format [a-zA-Z][a-zA-Z0-9]*"
                )

            if unit_id and not re.match(r"^\d+$", unit_id):
                warnings.append(
                    f"⚠️ Unit ID {unit_id} does not match the ideal format [0-9]+"
                )

        fix_errors, fix_warnings = check_vanilla_bugfixes(root)
        errors += fix_errors
        warnings += fix_warnings
        if not fix_errors:
            print_success(f"✅ Vanilla bugfixes intact ({len(ARTILLERY_LOAD_DELAY_FIX)} vanilla + "
                          f"{len(MOD_SHIPS_WITHOUT_ARTILLERY_DELAY)} mod ships: artillery load delay removed, capacity kept)")

    except Exception as e:
        errors.append(f"❌ Error occurred while parsing {xml_file}: {e}")

    if duplicate_names:
        errors.append(
            "❌ Duplicate names found:\n - "
            + "\n - ".join(
                [f"{name} (x{count + 1})" for name, count in duplicate_names.items()]
            )
        )
    else:
        print_success("✅ No duplicate names found!")

    if duplicate_ids:
        errors.append(
            "❌ Duplicate IDs found:\n - "
            + "\n - ".join(
                [f"{id} (x{count + 1})" for id, count in duplicate_ids.items()]
            )
        )
    else:
        print_success("✅ No duplicate IDs found!")

    if duplicate_dbids:
        errors.append(
            "❌ Duplicate DBIDs found:\n - "
            + "\n - ".join(
                [f"{dbid} (x{count + 1})" for dbid, count in duplicate_dbids.items()]
            )
        )
    else:
        print_success("✅ No duplicate DBIDs found!")

    if errors:
        for error in errors:
            print_error(error)
        exit(1)

    if warnings:
        for warning in warnings:
            print_warning(warning)

    if not errors:
        print_success(f"✅ {os.path.basename(xml_file)} validation passed!")


if __name__ == "__main__":
    xml_file = "data/protomods.xml"
    validate_protomods(xml_file)
