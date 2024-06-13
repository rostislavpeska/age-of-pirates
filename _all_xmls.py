###############################################################################
# This script finds all the XML files in the entire repository and parses them
# to check if they are well-formed.
###############################################################################

import xml.etree.ElementTree as ET
import os


def print_info(msg):
    print(f"\033[94m{msg}\033[0m")


def print_success(msg):
    print(f"\033[92m{msg}\033[0m")


def print_warning(msg):
    print(f"\033[93m{msg}\033[0m")


def print_error(msg):
    print(f"\033[91m{msg}\033[0m")


print_info("ℹ️ Validating XML files...")

malformed_files = []

for root, dirs, files in os.walk("."):
    for file in files:
        if file.lower().endswith(".xml") or file.lower().endswith(".tactics") or file.lower().endswith(".material") or file.lower().endswith(".dmg"):
            try:
                ET.parse(os.path.join(root, file))
            except ET.ParseError as e:
                malformed_files.append(
                    f"{os.path.join(root, file)[2:]}: {e}")

if len(malformed_files) == 0:
    print_success("✅ All XML files are well-formed.")
else:
    print_error(
        f"❌ {len(malformed_files)} XML files are not well-formed:")
    for file in malformed_files:
        print_error(f"  🔴 {file}")
    exit(1)
