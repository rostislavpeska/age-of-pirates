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
