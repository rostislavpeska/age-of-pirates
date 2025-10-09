#!/usr/bin/env python3
"""
Tech generator entrypoint (scripts/tech_generator/main.py)

User-friendly wrapper around tech_copy.main() to clone techs from combined sources
into scripts/new_data/techtreemods.xml.

Sources (search order):
  1) scripts/source/techtreey.xml
  2) data/techtreemods.xml
"""
from __future__ import annotations

import sys
from pathlib import Path

# ==== USER SETTINGS ==========================================================
# Select tech by name or by DBID (set one of these)
TECH_NAME: str | None = "zpCossackExpansion"  # set None to use TECH_ID instead
TECH_ID: int | None = None              # example: 105

# Optional: completely override the base tech name before applying any suffixes
NEW_NAME: str | None = "zpCoccackTech"

# Optional: create a clone for each suffix; new name will be f"{(NEW_NAME or TECH_NAME)}{suffix}"
SUFFIXES: list[str] = ["Industrial", "Fortress"]  # e.g. ["Industrial", "Fortress"]

# Optional: starting DBID for clones; required if SUFFIXES is non-empty
STARTING_ID: int | None = 41270  # e.g. 600000

# Destination file
DST: Path = Path("scripts/new_data/techtreemods.xml")
# ============================================================================


def main(argv: list[str]) -> int:
    # Build argv for tech_copy
    args: list[str] = ["--dst", str(DST)]

    if TECH_NAME and TECH_NAME.strip():
        args += ["--tech-name", TECH_NAME.strip()]
    elif TECH_ID is not None:
        args += ["--tech-id", str(int(TECH_ID))]
    else:
        print("Please set TECH_NAME or TECH_ID in scripts/tech_generator/main.py")
        return 2

    if SUFFIXES:
        if STARTING_ID is None:
            print("When using SUFFIXES you must set STARTING_ID in scripts/tech_generator/main.py")
            return 2
        args += ["--starting-id", str(int(STARTING_ID))]
        for suf in SUFFIXES:
            args += ["--suffix", suf]

    if NEW_NAME and NEW_NAME.strip():
        args += ["--new-name", NEW_NAME.strip()]

    # Ensure absolute import works even if launched directly
    # by adding the project root (parent that contains 'scripts')
    import sys as _sys
    from pathlib import Path as _Path
    _project_root = _Path(__file__).resolve().parents[2]
    if str(_project_root) not in _sys.path:
        _sys.path.insert(0, str(_project_root))

    from scripts.tech_generator import tech_copy  # type: ignore

    return tech_copy.main(args)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
