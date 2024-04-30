###############################################################################
# This script checks if the string tables follow a certain set of rules and
# forces a status check failure if they don't.
###############################################################################

import os
import xml.etree.ElementTree as ET


SUPPORTED_LANGUAGES = ["english"]


def print_info(msg):
    print(f"\033[94m{msg}\033[0m")


def print_success(msg):
    print(f"\033[92m{msg}\033[0m")


def print_warning(msg):
    print(f"\033[93m{msg}\033[0m")


def print_error(msg):
    print(f"\033[91m{msg}\033[0m")


def validate_locid(locid):
    if not locid.isdigit():
        return False
    return True


def validate_stringmods(xml_file, expected_language):
    success = True
    try:
        tree = ET.parse(xml_file)
        root = tree.getroot()

        language = root.find("./stringtable/language")
        lang_name = language.attrib.get('name', 'Unknown')

        if lang_name.lower() != expected_language.lower():
            print_error(
                f"❌ Non-{str(expected_language).capitalize()} stringtable ({str(lang_name).capitalize()}) in the `{expected_language}` folder")
            return False

        print_info(f"ℹ️ Validating {lang_name}")

        invalid_locids = set()
        empty_locids = 0
        duplicate_locids = set()
        empty_strings = set()

        locid_set = set()
        for string_elem in root.findall("./stringtable/language/string"):
            locid = string_elem.attrib.get('_locid', '')
            string_text = string_elem.text.strip() if string_elem.text else ''

            if not locid:
                empty_locids += 1
            elif not validate_locid(locid):
                invalid_locids.add(locid)
            elif locid in locid_set:
                duplicate_locids.add(locid)
            else:
                locid_set.add(locid)

            if not string_text:
                empty_strings.add(locid)

        if invalid_locids:
            print_error("❌ Found invalid locids:")
            for locid in invalid_locids:
                print_error(f"    🔴 {locid}")
            if empty_locids:
                print_error(f"    🔴 {empty_locids} empty locids")

        if duplicate_locids:
            print_error("❌ Found duplicate locids:")
            for locid in duplicate_locids:
                print_error(f"    🔴 {locid}")

        if empty_strings:
            print_error("❌ Found empty strings:")
            for locid in empty_strings:
                print_error(f"    🔴 {locid}")

        if not invalid_locids and not duplicate_locids and not empty_strings:
            print_success(f"✅ {lang_name} stringtable validation passed!")
        else:
            print_error(f"❌ {lang_name} stringtable validation failed!")
            success = False

    except Exception as e:
        print_error(f"❌ Error occurred while parsing {xml_file}: {e}")
        success = False

    return success


def validate_strings_folder(folder_path):
    success = True
    for root, dirs, files in os.walk(folder_path):
        language_folder = os.path.basename(root)
        stringmods_files = [
            file for file in files if file.lower() == "stringmods.xml"]

        if language_folder.lower() in SUPPORTED_LANGUAGES and not stringmods_files:
            print_warning(
                f"⚠️ No stringmods.xml found in the \033[0m\033[1;97m{language_folder}\033[0m\033[93m folder")
            continue

        for file in stringmods_files:
            xml_file = os.path.join(root, file)
            success = success and validate_stringmods(xml_file, language_folder)

    return success


if __name__ == "__main__":
    strings_folder = "data/strings"
    # validate_strings_folder(strings_folder)
    if not validate_strings_folder(strings_folder):
        exit(1)
