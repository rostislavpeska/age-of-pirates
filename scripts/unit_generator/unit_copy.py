#!/usr/bin/env python3
"""
unit_copy.py (moved to scripts/unit_generator/)

Copies unit definition(s) by name from data/protomods.xml into scripts/new_data/protomods.xml.
Also clones sound XMLs in scripts/new_sounds/ for newly created units.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path
from typing import Iterable, Optional, Tuple
import xml.etree.ElementTree as ET


def load_xml(path: Path) -> ET.ElementTree:
    if not path.exists():
        raise FileNotFoundError(f"XML not found: {path}")
    try:
        return ET.parse(path)
    except ET.ParseError as e:
        raise RuntimeError(f"Failed to parse XML {path}: {e}") from e


def find_proto_root(tree: ET.ElementTree) -> ET.Element:
    return tree.getroot()


def iter_matching_units(root: ET.Element, unit_name: Optional[str], unit_id: Optional[str]) -> Iterable[ET.Element]:
    """Yield all unit-like elements that match by name or id."""
    for elem in root.iter():
        tag = elem.tag.lower()
        if tag.endswith("protounit") or tag.endswith("unit"):
            name_match = False
            id_match = False

            # Attributes
            if unit_name:
                n = elem.get("name") or elem.get("Name")
                if n and n == unit_name:
                    name_match = True
            if unit_id:
                uid = elem.get("id") or elem.get("ID")
                if uid and uid == unit_id:
                    id_match = True

            # Child nodes
            if unit_name and not name_match:
                for c in elem:
                    if c.tag.lower() in ("name", "unitname") and (c.text or "").strip() == unit_name:
                        name_match = True
                        break
            if unit_id and not id_match:
                for c in elem:
                    if c.tag.lower() in ("id", "unitid") and (c.text or "").strip() == unit_id:
                        id_match = True
                        break

            if (unit_name and name_match) or (unit_id and id_match):
                yield elem


def deep_copy(elem: ET.Element) -> ET.Element:
    return ET.fromstring(ET.tostring(elem))

# merging removed per user request; copy units as-is


def ensure_parent_dir(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)


def write_units(src_tree: ET.ElementTree, units: Iterable[ET.Element], dst_path: Path) -> None:
    """Create a new XML file with the same root tag as the source and append all units inside."""
    ensure_parent_dir(dst_path)
    src_root_tag = src_tree.getroot().tag
    new_root = ET.Element(src_root_tag)
    for u in units:
        new_root.append(deep_copy(u))
    new_tree = ET.ElementTree(new_root)
    new_tree.write(dst_path, encoding="utf-8", xml_declaration=True)


def rename_and_reid(unit_elem: ET.Element, new_name: Optional[str], new_id: Optional[int]) -> ET.Element:
    """Return a deep-copied unit with updated name and IDs if provided.

    - Updates attribute name/Name and id/ID when present.
    - Updates child <Name>/<UnitName> and <dbid> when present.
    """
    clone = deep_copy(unit_elem)
    if new_name:
        if "name" in clone.attrib:
            clone.set("name", new_name)
        if "Name" in clone.attrib:
            clone.set("Name", new_name)
        for c in clone:
            t = c.tag.lower()
            if t in ("name", "unitname"):
                c.text = new_name
    if new_id is not None:
        if "id" in clone.attrib:
            clone.set("id", str(new_id))
        if "ID" in clone.attrib:
            clone.set("ID", str(new_id))
        for c in clone:
            if c.tag.lower() == "dbid":
                c.text = str(new_id)
                break
    return clone


def extract_unit_name(unit_elem: ET.Element) -> Optional[str]:
    n = unit_elem.get("name") or unit_elem.get("Name")
    if n:
        return n
    for c in unit_elem:
        if c.tag.lower() in ("name", "unitname") and (c.text or "").strip():
            return (c.text or "").strip()
    return None


def to_snake(s: str) -> str:
    """Convert a unit name to a simple snake-like lowercase token for filenames.

    Keeps alphanumerics, converts others to underscores, and lowercases.
    """
    return "".join((ch if ch.isalnum() else "_") for ch in s).lower()


def try_clone_sound(original_unit_name: str, new_unit_name: str, project_root: Path) -> Optional[Path]:
    """Clone a protounit sound XML for new_unit_name if a template exists.

    - Source template is looked up at sound/<original_name_lower>_snds.xml relative to project root.
    - Destination is scripts/new_sounds/<snake_case(new_unit_name)>_snds.xml.
    - Updates the <protounit name="..."> attribute to new_unit_name.
    - Returns the destination path on success, or None if skipped/missing.
    Prints a warning if the template is not found or cloning fails.
    """
    src_rel = Path("sound") / f"{original_unit_name.lower()}_snds.xml"
    src_path = project_root / src_rel
    if not src_path.exists():
        print(f"Sound files not found: {src_rel}", file=sys.stderr)
        return None

    try:
        tree = ET.parse(src_path)
        root = tree.getroot()
        for e in root.iter():
            if e.tag.lower() == "protounit":
                e.set("name", new_unit_name)
                break
        dst_rel = Path("scripts") / "new_sounds" / f"{to_snake(new_unit_name)}_snds.xml"
        dst_path = project_root / dst_rel
        ensure_parent_dir(dst_path)
        tree.write(dst_path, encoding="utf-8", xml_declaration=True)
        return dst_path
    except Exception as e:
        print(f"Sound cloning failed for '{original_unit_name}' -> '{new_unit_name}': {e}", file=sys.stderr)
        return None


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(
        description="Copy unit(s) by name from data/protomods.xml into scripts/new_data/protomods.xml. Optionally clone with suffixes and new IDs.",
    )
    parser.add_argument(
        "--src",
        type=Path,
        default=Path("data/protomods.xml"),
        help="Source XML file (default: data/protomods.xml)",
    )
    parser.add_argument(
        "--dst",
        type=Path,
        default=Path("scripts/new_data/protomods.xml"),
        help="Destination XML file (default: scripts/new_data/protomods.xml)",
    )

    identity = parser.add_argument_group("source unit selector (one is required)")
    identity.add_argument("--unit-name", dest="unit_name", help="Name of the unit to copy")
    identity.add_argument("--unit-id", dest="unit_id", help="ID of the unit to copy")

    clone = parser.add_argument_group("cloning options")
    clone.add_argument("--starting-id", dest="starting_id", type=int, help="Starting ID to assign to clones (applies to <unit id> and <dbid>)")
    clone.add_argument("--suffix", dest="suffixes", action="append", default=[], help="Suffix to append to the unit name for a clone. Repeat for multiple.")
    clone.add_argument("--new-name", dest="new_name", default=None, help="Override the base unit name before applying suffixes (optional)")

    parser.add_argument("--dry-run", action="store_true", help="Run without writing changes")

    args = parser.parse_args(argv)

    if not args.unit_name and not args.unit_id:
        print("Error: Specify at least --unit-name or --unit-id to select a unit.", file=sys.stderr)
        return 2

    try:
        src_tree = load_xml(args.src)
    except Exception as e:
        print(f"Failed to load XML: {e}", file=sys.stderr)
        return 1

    # Load additional source in front: scripts/source/protoy.xml (if present)
    extra_path = Path("scripts/source/protoy.xml")
    extra_tree: Optional[ET.ElementTree] = None
    if extra_path.exists():
        try:
            extra_tree = load_xml(extra_path)
        except Exception as e:
            print(f"Warning: failed to load extra source {extra_path}: {e}", file=sys.stderr)
            extra_tree = None

    # Build combined matches in strict order: extra first, then primary src
    matches: list[ET.Element] = []
    if extra_tree is not None:
        extra_root = find_proto_root(extra_tree)
        matches.extend(iter_matching_units(extra_root, args.unit_name, args.unit_id))
    src_root = find_proto_root(src_tree)
    matches.extend(iter_matching_units(src_root, args.unit_name, args.unit_id))
    if not matches:
        print("Error: Unit not found in source.", file=sys.stderr)
        return 3

    units_to_write: list[ET.Element] = []
    if args.suffixes:
        if args.starting_id is None:
            print("Error: --starting-id is required when using --suffix.", file=sys.stderr)
            return 2
        cur_id = int(args.starting_id)
        for u in matches:
            # Base name priority: --new-name (if provided) > extracted name > --unit-name > fallback
            base_name = (args.new_name.strip() if isinstance(args.new_name, str) and args.new_name.strip() else None) or extract_unit_name(u) or args.unit_name or "Unit"
            for suf in args.suffixes:
                new_name = f"{base_name}{suf}"
                units_to_write.append(rename_and_reid(u, new_name, cur_id))
                # Attempt to clone corresponding sound file for this new unit
                orig_name = extract_unit_name(u) or args.unit_name or base_name
                try_clone_sound(orig_name, new_name, Path.cwd())
                cur_id += 1
    else:
        # No suffixes: copy as-is, unless --new-name provided (and optionally re-ID if --starting-id provided)
        cur_id = int(args.starting_id) if args.starting_id is not None else None
        for u in matches:
            if args.new_name and isinstance(args.new_name, str) and args.new_name.strip():
                new_name = args.new_name.strip()
                units_to_write.append(rename_and_reid(u, new_name, cur_id))
                # Attempt to clone corresponding sound file for this new unit
                orig_name = extract_unit_name(u) or args.unit_name or new_name
                try_clone_sound(orig_name, new_name, Path.cwd())
                if cur_id is not None:
                    cur_id += 1
            else:
                # Copy as-is but still clone the sound file into scripts/new_sounds/
                units_to_write.append(deep_copy(u))
                orig_name = extract_unit_name(u) or args.unit_name or "Unit"
                # new unit name equals original when not renamed
                try_clone_sound(orig_name, orig_name, Path.cwd())

    if args.dry_run:
        print("Dry run: changes not written. Would write the following number of units:")
        print(len(units_to_write))
        print(str(args.dst))
        return 0

    try:
        write_units(src_tree, units_to_write, args.dst)
        print(f"Wrote {len(units_to_write)} unit(s) to: {args.dst}")
    except Exception as e:
        print(f"Failed to write destination XML: {e}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
