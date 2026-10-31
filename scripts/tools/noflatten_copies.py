"""The no-flatten copies of settlement groupings: <Name>_noflatten.xml = <Name>.xml minus its flattener line.

Owner 2026-10-07: "keep the debt and define some standards for flatten / unflatten groupings". A copy is derived,
never edited: edit the base grouping, then run --write. The standard is in the rm-groupings-deploy skill ("Flatten /
unflatten standard"); scripts/mapcheck/tests/test_area_flattener.py pins it.

    python scripts/tools/noflatten_copies.py --check         # exit 1 when a copy differs from its base minus the line
    python scripts/tools/noflatten_copies.py --write         # regenerate every existing copy from its base
    python scripts/tools/noflatten_copies.py --add <Name>    # create <Name>_noflatten.xml (a map must use it)
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path
from typing import List, Tuple

REPO = Path(__file__).resolve().parents[2]
GROUPINGS = REPO / "game" / "randmaps" / "groupings"
FLATTENER = "zpInvisibleGroundFlattener"
SUFFIX = "_noflatten"


def derived(base: Path) -> bytes:
    """The copy's bytes: the base without its one flattener line, CRLF (AGENTS.md rule 1)."""
    text = base.read_bytes().decode("utf-8").replace("\r\n", "\n")
    lines = text.split("\n")
    flat = [k for k, line in enumerate(lines) if FLATTENER in line]
    if len(flat) != 1:
        raise ValueError(f"{base.name}: {len(flat)} flattener lines, expected exactly one")
    del lines[flat[0]]
    return "\n".join(lines).replace("\n", "\r\n").encode("utf-8")


def copies(folder: Path = GROUPINGS) -> List[Tuple[Path, Path]]:
    """(copy, base) for every <Name>_noflatten.xml."""
    return [(c, folder / (c.stem[: -len(SUFFIX)] + ".xml")) for c in sorted(folder.glob(f"*{SUFFIX}.xml"))]


def problems(folder: Path = GROUPINGS) -> List[str]:
    out = []
    for copy, base in copies(folder):
        if not base.is_file():
            out.append(f"{copy.name}: no base {base.name}")
            continue
        try:
            want = derived(base)
        except ValueError as e:
            out.append(str(e))
            continue
        if copy.read_bytes() != want:
            out.append(f"{copy.name}: differs from {base.name} minus its flattener line (run --write)")
    return out


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--check", action="store_true")
    g.add_argument("--write", action="store_true")
    g.add_argument("--add", metavar="NAME")
    a = ap.parse_args(argv)
    if a.add:
        base = GROUPINGS / f"{a.add}.xml"
        copy = GROUPINGS / f"{a.add}{SUFFIX}.xml"
        copy.write_bytes(derived(base))
        print(f"wrote {copy.relative_to(REPO).as_posix()}")
        return 0
    if a.write:
        for copy, base in copies():
            want = derived(base)
            if copy.read_bytes() != want:
                copy.write_bytes(want)
                print(f"rewrote {copy.name}")
        return 0
    found = problems()
    for p in found:
        print(p)
    print(f"{len(copies())} copies, {len(found)} problem(s)")
    return 1 if found else 0


if __name__ == "__main__":
    sys.exit(main())
