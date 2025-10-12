#!/usr/bin/env python3
"""
main.py (moved to scripts/unit_generator/)

User-friendly entry point to copy/clone units and sounds.
"""
from __future__ import annotations

import sys
from pathlib import Path

# ==== USER SETTINGS ==========================================================
# Set this to the exact ProtoUnit name to copy (case-sensitive)
UNIT_NAME: str = "deSPCYermak"

# When cloning: assign IDs starting from this value to the clones
# (applies to <unit id> and <dbid>). Only used if SUFFIXES is non-empty.
STARTING_ID: int = 20901

# Optional: completely override the base name before applying any suffixes.
# If empty/None, the original unit name is used as base.
NEW_NAME: str | None = "zpSPChatman"

# Create a clone for each suffix; new name will be f"{(NEW_NAME or UNIT_NAME)}{suffix}"
# Example: ["Industrial", "Fortress"] -> ...Industrial, ...Fortress
SUFFIXES: list[str] = ["Bohdan", "Petro", "Mazepa"]

# Optionally customize source and destination paths
SRC: Path = Path("data/protomods.xml")
DST: Path = Path("scripts/new_data/protomods.xml")
DRY_RUN: bool = False  # Set to True to preview without writing
# ============================================================================


def main(argv: list[str]) -> int:
    if not UNIT_NAME:
        print("Please set UNIT_NAME in scripts/unit_generator/main.py to the unit you want to copy.")
        return 2

    # Build argv for unit_copy
    args = ["--unit-name", UNIT_NAME, "--src", str(SRC), "--dst", str(DST)]
    if SUFFIXES:
        args += ["--starting-id", str(STARTING_ID)]
        for suf in SUFFIXES:
            args += ["--suffix", suf]
    if NEW_NAME and NEW_NAME.strip():
        args += ["--new-name", NEW_NAME.strip()]
    if DRY_RUN:
        args.append("--dry-run")

    # Import the moved module in a way that works both as a package and as a direct script
    # Ensure project root (the parent dir that contains the 'scripts' package) is on sys.path
    import sys as _sys
    from pathlib import Path as _Path
    _project_root = _Path(__file__).resolve().parents[2]
    if str(_project_root) not in _sys.path:
        _sys.path.insert(0, str(_project_root))

    from scripts.unit_generator import unit_copy  # type: ignore

    return unit_copy.main(args)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
