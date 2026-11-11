#!/usr/bin/env python3
import os
import sys

# Configure your matchup here
UNIT_A = "zpSPCQueenAnne"
UNIT_B = "deMercDhow"

# Optional overrides (set to None to use defaults inside ttk_calc)
PROTOMODS = None  # e.g., r"data/protomods.xml"
PROTOY = None     # e.g., r"scripts/source/protoy.xml"

# Force a specific protoaction name per unit (leave as None to auto-pick best non-special attack)
# Valid values must match an attack name present on the unit (see --show-attacks). If specified but
# missing on the unit, ttk_calc will raise an exception.
ATTACK_TYPE_UNIT_A = None  # e.g., "RangedAttack" or a special like "BroadsideAttack"
ATTACK_TYPE_UNIT_B = None  # e.g., "RangedAttack"
SHOW_ATTACKS = False

def build_argv() -> list:
    argv = ["ttk_calc.py", UNIT_A, UNIT_B]
    if PROTOMODS:
        argv += ["--protomods", PROTOMODS]
    if PROTOY:
        argv += ["--protoy", PROTOY]
    if ATTACK_TYPE_UNIT_A:
        argv += ["--attack-a", ATTACK_TYPE_UNIT_A]
    if ATTACK_TYPE_UNIT_B:
        argv += ["--attack-b", ATTACK_TYPE_UNIT_B]
    if SHOW_ATTACKS:
        argv += ["--show-attacks"]
    return argv


def main():
    try:
        # Import the CLI and call it with our constructed argv
        import ttk_calc  # type: ignore
    except ImportError:
        # Allow running from repository root by adding this script's directory to path
        tools_dir = os.path.dirname(os.path.abspath(__file__))
        if tools_dir not in sys.path:
            sys.path.insert(0, tools_dir)
        import ttk_calc  # type: ignore

    saved_argv = sys.argv[:]
    try:
        sys.argv = build_argv()
        ttk_calc.main()
    finally:
        sys.argv = saved_argv


if __name__ == "__main__":
    main()
