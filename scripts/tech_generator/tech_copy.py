#!/usr/bin/env python3
"""
tech_copy.py

Clone tech definitions from combined sources into scripts/new_data/techtreemods.xml.
Sources (in order):
  1) scripts/source/techtreey.xml
  2) data/techtreemods.xml

Behavior:
- Select techs by name or ID.
- Copy matching <tech> blocks AS-IS unless renaming/ID options are provided.
- Optional new base name (NEW_NAME/--new-name) and suffixes to create multiple clones.
- Optional STARTING_ID/--starting-id to assign sequential <dbid> values to clones.
- No sound handling for techs.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path
from typing import Iterable, Optional
import xml.etree.ElementTree as ET


def load_xml(path: Path) -> ET.ElementTree:
    if not path.exists():
        raise FileNotFoundError(f"XML not found: {path}")
    try:
        return ET.parse(path)
    except ET.ParseError as e:
        raise RuntimeError(f"Failed to parse XML {path}: {e}") from e


def find_root(tree: ET.ElementTree) -> ET.Element:
    return tree.getroot()


def deep_copy(elem: ET.Element) -> ET.Element:
    return ET.fromstring(ET.tostring(elem))


def ensure_parent_dir(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)


def iter_matching_techs(root: ET.Element, tech_name: Optional[str], tech_id: Optional[str]) -> Iterable[ET.Element]:
    """Yield <tech> elements matching by name attribute or <dbid> value."""
    for elem in root.iter():
        if elem.tag.lower() == "tech":
            name_ok = False
            id_ok = False
            if tech_name:
                n = elem.get("name")
                if n and n == tech_name:
                    name_ok = True
            if tech_id:
                for c in elem:
                    if c.tag.lower() == "dbid" and (c.text or "").strip() == tech_id:
                        id_ok = True
                        break
            if (tech_name and name_ok) or (tech_id and id_ok):
                yield elem


def rename_and_reid(tech_elem: ET.Element, new_name: Optional[str], new_id: Optional[int]) -> ET.Element:
    clone = deep_copy(tech_elem)
    if new_name:
        clone.set("name", new_name)
    if new_id is not None:
        for c in clone:
            if c.tag.lower() == "dbid":
                c.text = str(new_id)
                break
    return clone


def write_techs(src_tree: ET.ElementTree, techs: Iterable[ET.Element], dst_path: Path) -> None:
    ensure_parent_dir(dst_path)
    src_root_tag = src_tree.getroot().tag
    new_root = ET.Element(src_root_tag)
    for t in techs:
        new_root.append(deep_copy(t))
    new_tree = ET.ElementTree(new_root)
    new_tree.write(dst_path, encoding="utf-8", xml_declaration=True)


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(
        description="Copy tech(s) by name or id from combined sources into scripts/new_data/techtreemods.xml",
    )
    parser.add_argument("--dst", type=Path, default=Path("scripts/new_data/techtreemods.xml"), help="Destination XML file")

    identity = parser.add_argument_group("tech selector (one is required)")
    identity.add_argument("--tech-name", dest="tech_name", help="Name of the tech to copy")
    identity.add_argument("--tech-id", dest="tech_id", help="DBID of the tech to copy")

    clone = parser.add_argument_group("cloning options")
    clone.add_argument("--starting-id", dest="starting_id", type=int, help="Starting DBID to assign to clones")
    clone.add_argument("--suffix", dest="suffixes", action="append", default=[], help="Suffix to append to the base tech name. Repeat for multiple.")
    clone.add_argument("--new-name", dest="new_name", default=None, help="Override base tech name before applying suffixes")

    args = parser.parse_args(argv)

    if not args.tech_name and not args.tech_id:
        print("Error: Specify --tech-name or --tech-id.", file=sys.stderr)
        return 2

    # Load sources in order
    primary_src = Path("data/techtreemods.xml")
    extra_src = Path("scripts/source/techtreey.xml")
    try:
        prim_tree = load_xml(primary_src)
    except Exception as e:
        print(f"Failed to load primary source: {e}", file=sys.stderr)
        return 1

    extra_tree: Optional[ET.ElementTree] = None
    if extra_src.exists():
        try:
            extra_tree = load_xml(extra_src)
        except Exception as e:
            print(f"Warning: failed to load extra source {extra_src}: {e}", file=sys.stderr)
            extra_tree = None

    # Combined matches: extra first, then primary
    matches: list[ET.Element] = []
    if extra_tree is not None:
        matches.extend(iter_matching_techs(find_root(extra_tree), args.tech_name, args.tech_id))
    matches.extend(iter_matching_techs(find_root(prim_tree), args.tech_name, args.tech_id))

    if not matches:
        print("Error: Tech not found in sources.", file=sys.stderr)
        return 3

    # Build outputs
    out: list[ET.Element] = []
    if args.suffixes:
        if args.starting_id is None:
            print("Error: --starting-id is required when using --suffix.", file=sys.stderr)
            return 2
        cur_id = int(args.starting_id)
        for t in matches:
            base_name = (args.new_name.strip() if isinstance(args.new_name, str) and args.new_name.strip() else None) or t.get("name") or args.tech_name or "Tech"
            for suf in args.suffixes:
                new_name = f"{base_name}{suf}"
                out.append(rename_and_reid(t, new_name, cur_id))
                cur_id += 1
    else:
        cur_id = int(args.starting_id) if args.starting_id is not None else None
        for t in matches:
            if args.new_name and isinstance(args.new_name, str) and args.new_name.strip():
                new_name = args.new_name.strip()
                out.append(rename_and_reid(t, new_name, cur_id))
                if cur_id is not None:
                    cur_id += 1
            else:
                if cur_id is not None:
                    # Keep original name, only reassign DBID
                    out.append(rename_and_reid(t, t.get("name"), cur_id))
                    cur_id += 1
                else:
                    out.append(deep_copy(t))

    # Write using primary source root tag
    try:
        write_techs(prim_tree, out, args.dst)
        print(f"Wrote {len(out)} tech(s) to: {args.dst}")
    except Exception as e:
        print(f"Failed to write destination XML: {e}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
