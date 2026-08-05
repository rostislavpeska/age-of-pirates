"""User-friendly entrypoint for the map spawn simulator.

Edit the USER SETTINGS block and run from the repo root:
  python scripts/mapsim/main.py
For flag-level control use the worker directly:
  python scripts/mapsim/sim.py --help
"""

from __future__ import annotations

import sys
from pathlib import Path

# ==== USER SETTINGS ==========================================================
SCENE = None          # None = the Independence War golden scene
MATRIX = True         # True = standard {2,3,5,7,8} x {2-team, FFA} sweep
PLAYERS = 2           # used when MATRIX is False
TEAMS = 2             # used when MATRIX is False
KOTH = False
NOMAD = False
OUT = None            # None = playground/mapsim
# ============================================================================

_project_root = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_project_root))

from scripts.mapsim import sim  # noqa: E402


def main() -> int:
    argv = []
    if SCENE is not None:
        argv += ["--scene", str(SCENE)]
    if OUT is not None:
        argv += ["--out", str(OUT)]
    if MATRIX:
        argv.append("--matrix")
    else:
        argv += ["--players", str(PLAYERS), "--teams", str(TEAMS)]
        if KOTH:
            argv.append("--koth")
        if NOMAD:
            argv.append("--nomad")
    return sim.main(argv)


if __name__ == "__main__":
    raise SystemExit(main())
