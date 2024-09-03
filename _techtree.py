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


def validate_techtreemods(xml_file):
    errors = []
    warnings = []

    duplicate_names = {}
    duplicate_dbids = {}

    try:
        tree = ET.parse(xml_file)
        root = tree.getroot()

        name_set = {}
        dbid_set = {}

        for tech in root.findall("./tech"):
            tech_name = tech.attrib.get("name", "").strip()
            tech_dbid_element = tech.find("dbid")
            tech_dbid = (
                tech_dbid_element.text.strip()
                if tech_dbid_element is not None and tech_dbid_element.text is not None
                else ""
            )

            if tech_name:
                tech_name_lower = tech_name.lower()
                if tech_name_lower in name_set:
                    duplicate_names[tech_name_lower] = (
                        duplicate_names.get(tech_name_lower, 0) + 1
                    )
                else:
                    name_set[tech_name_lower] = tech_dbid

            if tech_dbid:
                if tech_dbid in dbid_set:
                    duplicate_dbids[tech_dbid] = duplicate_dbids.get(tech_dbid, 0) + 1
                else:
                    dbid_set[tech_dbid] = tech_name

            if tech_name and not re.match(r"^[a-zA-Z][a-zA-Z0-9]*$", tech_name):
                warnings.append(
                    f"⚠️ Tech name {tech_name} does not match the ideal format [a-zA-Z][a-zA-Z0-9]*"
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
    xml_file = "data/techtreemods.xml"
    validate_techtreemods(xml_file)
