#!/usr/bin/env python3
"""
main.py

User-friendly entry point to copy a unit definition from data/protomods.xml
into scripts/new_data/protomods.xml by specifying the unit name below.

Usage:
- Edit UNIT_NAME below to the exact unit name you want to copy.
- Optionally tweak SRC and DST if needed.
- Run: python scripts/main.py

This script calls unit_copy.main() with the appropriate arguments.
"""

from __future__ import annotations

import sys
from pathlib import Path

# ==== USER SETTINGS ==========================================================
# Set this to the exact ProtoUnit name to copy (case-sensitive)
UNIT_NAME: str = "zpNatCossackDragoon"

# When cloning: assign IDs starting from this value to the clones
# (applies to <unit id> and <dbid>). Only used if SUFFIXES is non-empty.
STARTING_ID: int = 20900

# Create a clone for each suffix; new name will be f"{UNIT_NAME}{suffix}"
# Example: ["Industrial", "Fortress"] -> zpNatCossackDragoonIndustrial, zpNatCossackDragoonFortress
SUFFIXES: list[str] = ["Industrial", "Fortress"]

# Optionally customize source and destination paths
SRC: Path = Path("data/protomods.xml")
DST: Path = Path("scripts/new_data/protomods.xml")
DRY_RUN: bool = False  # Set to True to preview without writing
# ============================================================================


def main(argv: list[str]) -> int:
    if not UNIT_NAME:
        print("Please set UNIT_NAME in scripts/main.py to the unit you want to copy.")
        return 2

    # Build argv for unit_copy
    args = ["--unit-name", UNIT_NAME, "--src", str(SRC), "--dst", str(DST)]
    if SUFFIXES:
        args += ["--starting-id", str(STARTING_ID)]
        for suf in SUFFIXES:
            args += ["--suffix", suf]
    if DRY_RUN:
        args.append("--dry-run")

    # Import here to avoid circularities at module import time
    import unit_copy  # type: ignore

    return unit_copy.main(args)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
