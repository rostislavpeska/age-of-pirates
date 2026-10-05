#!/usr/bin/env python3
"""Unit names must exist EXACTLY - spelling and case.

2026-10-05: Istanbul's per-map mods file gave the Dry Dock its placement rule as `zpDryDock`; the proto is `zpDrydock`.
The game applies that file when the map is set up, the AI constant cUnitTypezpDrydock stopped existing, and every AI on
Istanbul died at aiBuildings.xs 123 ("'cUnitTypezpDrydock' is not a valid operator"). Nothing flagged it for ten days.

    python scripts/tools/check_unit_names.py            # live game data when the install is found
    python scripts/tools/check_unit_names.py --no-live  # snapshot only (CI: no game install)

Checks:
  1. every <unit name="X"> in randmaps/*.mods.xml and game/randmaps/*.mods.xml
  2. every cUnitTypezp... constant in the AI the game compiles (game/ai/core/*.xs, comments ignored)
Known names: data/protomods.xml (unit names and unit types), the vanilla snapshot scripts/source/protoy.xml, and the
live protoy read through bartool when the game install is found.
  ERROR  a name that matches a known name only when case is ignored (zpDryDock -> zpDrydock), always
  ERROR  a mod name (zp...) that exists nowhere
  ERROR  a vanilla name that exists nowhere, when the live data was read
  WARN   a vanilla name missing from the snapshot alone (the snapshot is older than the game; CI has no install)
Exit 1 on any ERROR. Standard library only (bartool is optional)."""
import glob, os, re, sys

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
UNIT_NAME = re.compile(r'<unit\b[^>]*?\bname\s*=\s*"([^"]+)"')
UNIT_TYPE = re.compile(r"<unittype>\s*([^<\s]+)\s*</unittype>")
AI_CONST = re.compile(r"\bcUnitType(zp\w+)")


def names_in(text):
    return set(UNIT_NAME.findall(text)) | set(UNIT_TYPE.findall(text))


def read(path):
    with open(path, encoding="utf-8", errors="replace") as f:
        return f.read()


def live_protoy():
    """the live vanilla protoy as text, or None (no install / no bartool)"""
    import subprocess
    tool = os.path.join(REPO, ".claude", "skills", "aoe3de-bar-archives", "scripts", "bartool.py")
    if not os.path.exists(tool):
        return None
    try:
        r = subprocess.run([sys.executable, tool, "cat", "Data/protoy.xml.XMB"], capture_output=True, timeout=600)
    except Exception:
        return None
    text = r.stdout.decode("utf-8", errors="replace")
    return text if (r.returncode == 0 and "<unit " in text) else None


def known_names(live=True):
    mod = names_in(read(os.path.join(REPO, "data", "protomods.xml")))
    vanilla = set()
    snap = os.path.join(REPO, "scripts", "source", "protoy.xml")
    if os.path.exists(snap):
        vanilla |= names_in(read(snap))
    live_text = live_protoy() if live else None
    if live_text:
        vanilla |= names_in(live_text)
    return mod, vanilla, live_text is not None


def strip_xs_comments(text):
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    return re.sub(r"//[^\n]*", "", text)


def check(mods_files, ai_files, mod, vanilla, live):
    """-> (errors, warnings), each a list of 'file:line: message'"""
    known = mod | vanilla
    by_lower = {}
    for n in known:
        by_lower.setdefault(n.lower(), set()).add(n)
    errors, warns = [], []

    def judge(where, name, is_mod_name):
        if name in known:
            return
        if name.lower() in by_lower:
            errors.append("%s: '%s' does not exist - the real name is %s (names are case-sensitive)"
                          % (where, name, " / ".join(sorted(by_lower[name.lower()]))))
        elif is_mod_name:
            errors.append("%s: '%s' is not a unit or unit type in data/protomods.xml" % (where, name))
        elif live:
            errors.append("%s: '%s' exists in neither the mod nor the live game data" % (where, name))
        else:
            warns.append("%s: '%s' is not in the vanilla snapshot (stale snapshot, no live data to confirm)" % (where, name))

    for path in mods_files:
        rel = os.path.relpath(path, REPO).replace(os.sep, "/")
        for i, line in enumerate(read(path).splitlines(), 1):
            for name in UNIT_NAME.findall(line):
                judge("%s:%d" % (rel, i), name, name.lower().startswith("zp"))
    for path in ai_files:
        rel = os.path.relpath(path, REPO).replace(os.sep, "/")
        for i, line in enumerate(strip_xs_comments(read(path)).splitlines(), 1):
            for name in AI_CONST.findall(line):
                judge("%s:%d cUnitType%s" % (rel, i, name), name, True)
    return errors, warns


def default_files():
    mods = sorted(glob.glob(os.path.join(REPO, "randmaps", "*.mods.xml")) +
                  glob.glob(os.path.join(REPO, "game", "randmaps", "*.mods.xml")))
    ai = sorted(glob.glob(os.path.join(REPO, "game", "ai", "core", "*.xs")))
    return mods, ai


def run(live=True):
    mod, vanilla, used_live = known_names(live)
    mods, ai = default_files()
    errors, warns = check(mods, ai, mod, vanilla, used_live)
    return errors, warns, used_live, len(mods), len(ai)


def main():
    errors, warns, used_live, n_mods, n_ai = run(live="--no-live" not in sys.argv)
    for w in warns:
        print("WARN ", w)
    for e in errors:
        print("ERROR", e)
    print("unit names: %d per-map mods files, %d AI files - %d error(s), %d warning(s) [%s]"
          % (n_mods, n_ai, len(errors), len(warns), "live game data" if used_live else "snapshot only"))
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
