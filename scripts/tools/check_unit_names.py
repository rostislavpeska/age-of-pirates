#!/usr/bin/env python3
"""Unit and tech names must exist EXACTLY - spelling and case.

2026-10-05: Istanbul's per-map mods file gave the Dry Dock its placement rule as `zpDryDock`; the proto is `zpDrydock`.
The game applies that file when the map is set up, the AI constant cUnitTypezpDrydock stopped existing, and every AI on
Istanbul died at aiBuildings.xs 123 ("'cUnitTypezpDrydock' is not a valid operator"). Nothing flagged it for ten days.

    python scripts/tools/check_unit_names.py            # live game data when the install is found
    python scripts/tools/check_unit_names.py --no-live  # snapshot only (CI: no game install)

Checks:
  1. data/protomods.xml  - an entry that rewrites a vanilla unit names it exactly; an entry without an id rewrites a unit
                           that exists (vanilla, or a mod unit defined with an id); no two mod units differ only by case
  2. data/techtreemods.xml - the same for techs (rewrites carry no <dbid>, new techs do)
  3. randmaps/*.mods.xml, game/randmaps/*.mods.xml - every <unit name> and <tech name> exists exactly; a tech entry in a
                           per-map file is also a WARN: the route works on paper but is not reliable (owner 2026-10-06)
  4. game/ai/core/*.xs   - every cUnitTypezp... and cTechzp... constant exists exactly (comments ignored)
Known names: the mod's data files, the vanilla snapshots scripts/source/protoy.xml + techtreey.xml, and the live protoy
and techtreey read through bartool when the game install is found.
  ERROR  a name that matches a known name only when case is ignored (zpDryDock -> zpDrydock), always
  ERROR  a mod name (zp...) that exists nowhere; an id-less rewrite of something that exists nowhere (live data)
  ERROR  a vanilla name that exists nowhere, when the live data was read
  WARN   a vanilla name missing from the snapshot alone (the snapshot is older than the game; CI has no install)
Exit 1 on any ERROR. Standard library only (bartool is optional)."""
import glob, os, re, subprocess, sys
import xml.etree.ElementTree as ET

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
UNIT_TAG = re.compile(r'<unit\b[^>]*?\bname\s*=\s*"([^"]+)"')
TECH_TAG = re.compile(r'<tech\b[^>]*?\bname\s*=\s*"([^"]+)"')
UNIT_TYPE = re.compile(r"<unittype>\s*([^<\s]+)\s*</unittype>")
AI_UNIT = re.compile(r"\bcUnitType(zp\w+)")
AI_TECH = re.compile(r"\bcTech(zp\w+)")


def read(path):
    with open(path, encoding="utf-8", errors="replace") as f:
        return f.read()


def rel(path):
    return os.path.relpath(path, REPO).replace(os.sep, "/")


def no_comments(text):
    """XML comments blanked, line numbers kept"""
    return re.sub(r"<!--.*?-->", lambda m: "\n" * m.group(0).count("\n"), text, flags=re.S)


def strip_xs_comments(text):
    text = re.sub(r"/\*.*?\*/", lambda m: "\n" * m.group(0).count("\n"), text, flags=re.S)
    return re.sub(r"//[^\n]*", "", text)


def live_text(archive_path):
    """a live vanilla data file as text, or None (no install / no bartool)"""
    tool = os.path.join(REPO, ".claude", "skills", "aoe3de-bar-archives", "scripts", "bartool.py")
    if not os.path.exists(tool):
        return None
    try:
        r = subprocess.run([sys.executable, tool, "cat", archive_path], capture_output=True, timeout=600)
    except Exception:
        return None
    text = r.stdout.decode("utf-8", errors="replace")
    return text if (r.returncode == 0 and "name=" in text) else None


class Known:
    """every name the checks compare against"""
    def __init__(self, live=True, protomods=None, techtreemods=None):
        self.protomods = protomods or os.path.join(REPO, "data", "protomods.xml")
        self.techtreemods = techtreemods or os.path.join(REPO, "data", "techtreemods.xml")
        pm, tm = read(self.protomods), read(self.techtreemods)
        self.mod_units = set(UNIT_TAG.findall(no_comments(pm)))
        self.mod_types = set(UNIT_TYPE.findall(no_comments(pm)))
        self.mod_techs = set(TECH_TAG.findall(no_comments(tm)))
        self.van_units, self.van_types, self.van_techs = set(), set(), set()
        for name in ("protoy.xml", "techtreey.xml"):
            p = os.path.join(REPO, "scripts", "source", name)
            if os.path.exists(p):
                self._vanilla(name, read(p))
        self.live = False
        if live:
            lp, lt = live_text("Data/protoy.xml.XMB"), live_text("Data/techtreey.xml.XMB")
            if lp and lt:
                self._vanilla("protoy.xml", lp)
                self._vanilla("techtreey.xml", lt)
                self.live = True

    def _vanilla(self, name, text):
        if name == "protoy.xml":
            self.van_units |= set(UNIT_TAG.findall(text))
            self.van_types |= set(UNIT_TYPE.findall(text))
        else:
            self.van_techs |= set(TECH_TAG.findall(text))

    def units(self):
        return self.mod_units | self.mod_types | self.van_units | self.van_types

    def techs(self):
        return self.mod_techs | self.van_techs


def lower_map(names):
    m = {}
    for n in names:
        m.setdefault(n.lower(), set()).add(n)
    return m


class Report:
    def __init__(self, live):
        self.live, self.errors, self.warns = live, [], []

    def judge(self, where, name, known, kind):
        """kind: 'unit' or 'tech'"""
        if name in known:
            return
        low = lower_map(known)
        if name.lower() in low:
            self.errors.append("%s: %s '%s' does not exist - the real name is %s (names are case-sensitive)"
                               % (where, kind, name, " / ".join(sorted(low[name.lower()]))))
        elif name.lower().startswith("zp"):
            self.errors.append("%s: %s '%s' is not defined in the mod's data" % (where, kind, name))
        elif self.live:
            self.errors.append("%s: %s '%s' exists in neither the mod nor the live game data" % (where, kind, name))
        else:
            self.warns.append("%s: %s '%s' is not in the vanilla snapshot (stale snapshot, no live data to confirm)"
                              % (where, kind, name))


def entries(path, tag, marker):
    """top-level entries of a data file in document order: (name, line, has_marker) - marker = id attribute / <dbid>"""
    text = read(path)
    root = ET.fromstring(text.encode("utf-8"))
    els = [e for e in root if e.tag == tag and e.get("name")]
    regex = UNIT_TAG if tag == "unit" else TECH_TAG
    clean = no_comments(text)
    spans = [clean.count("\n", 0, m.start()) + 1 for m in regex.finditer(clean)]
    lines = spans if len(spans) == len(els) else [None] * len(els)
    out = []
    for e, ln in zip(els, lines):
        has = (e.get("id") is not None) if marker == "id" else (e.find("dbid") is not None)
        out.append((e.get("name"), ln, has))
    return out


def check_rewrites(rep, path, tag, marker, vanilla, kind):
    """vanilla rewrites spelled exactly, id-less entries rewrite something that exists, no case twins among mod names"""
    ents = entries(path, tag, marker)
    defined = {n for n, _, has in ents if has}
    van_low, def_low = lower_map(vanilla), lower_map(defined)
    for name, line, has in ents:
        where = "%s:%s" % (rel(path), line if line else "?")
        if name in vanilla:
            continue
        if name.lower() in van_low:
            rep.errors.append("%s: %s '%s' differs from the vanilla %s only by case - as written it is a NEW %s, not a rewrite"
                              % (where, kind, name, " / ".join(sorted(van_low[name.lower()])), kind))
            continue
        if has:
            continue
        if name in defined:
            continue                       # a partial rewrite of a mod entry defined with its id / dbid
        if name.lower() in def_low:
            rep.errors.append("%s: %s '%s' rewrites nothing - the mod defines %s (names are case-sensitive)"
                              % (where, kind, name, " / ".join(sorted(def_low[name.lower()]))))
        elif rep.live:
            rep.errors.append("%s: %s '%s' has no %s and exists nowhere - a rewrite of nothing" % (where, kind, name, marker))
        else:
            rep.warns.append("%s: %s '%s' has no %s and is not in the vanilla snapshot (stale snapshot, no live data)"
                             % (where, kind, name, marker))
    for low, names in lower_map(defined).items():
        if len(names) > 1:
            rep.errors.append("%s: %s names that differ only by case: %s" % (rel(path), kind, " / ".join(sorted(names))))


def check_mods_files(rep, paths, known):
    units, techs = known.units(), known.techs()
    for path in paths:
        text = no_comments(read(path))
        for i, line in enumerate(text.splitlines(), 1):
            where = "%s:%d" % (rel(path), i)
            for name in UNIT_TAG.findall(line):
                rep.judge(where, name, units, "unit")
            for name in TECH_TAG.findall(line):
                rep.judge(where, name, techs, "tech")
                rep.warns.append("%s: tech '%s' in a per-map mods file - it can work but is not reliable (owner 2026-10-06);"
                                 " flip it from the map's setup tech instead" % (where, name))


def check_ai(rep, paths, known):
    units, techs = known.units(), known.techs()
    for path in paths:
        for i, line in enumerate(strip_xs_comments(read(path)).splitlines(), 1):
            for name in AI_UNIT.findall(line):
                rep.judge("%s:%d cUnitType%s" % (rel(path), i, name), name, units, "unit")
            for name in AI_TECH.findall(line):
                rep.judge("%s:%d cTech%s" % (rel(path), i, name), name, techs, "tech")


def default_files():
    mods = sorted(glob.glob(os.path.join(REPO, "randmaps", "*.mods.xml")) +
                  glob.glob(os.path.join(REPO, "game", "randmaps", "*.mods.xml")))
    ai = sorted(glob.glob(os.path.join(REPO, "game", "ai", "core", "*.xs")))
    return mods, ai


def run(live=True):
    known = Known(live)
    rep = Report(known.live)
    check_rewrites(rep, known.protomods, "unit", "id", known.van_units, "unit")
    check_rewrites(rep, known.techtreemods, "tech", "dbid", known.van_techs, "tech")
    mods, ai = default_files()
    check_mods_files(rep, mods, known)
    check_ai(rep, ai, known)
    return rep.errors, rep.warns, known.live, len(mods), len(ai)


def main():
    errors, warns, used_live, n_mods, n_ai = run(live="--no-live" not in sys.argv)
    for w in warns:
        print("WARN ", w)
    for e in errors:
        print("ERROR", e)
    print("names: protomods, techtreemods, %d per-map mods files, %d AI files - %d error(s), %d warning(s) [%s]"
          % (n_mods, n_ai, len(errors), len(warns), "live game data" if used_live else "snapshot only"))
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
