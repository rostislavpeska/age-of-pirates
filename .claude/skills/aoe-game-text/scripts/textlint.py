"""Lint player-facing English text against the vanilla voice, and a card's text against its effects.

    python .claude/skills/aoe-game-text/scripts/textlint.py --tech YPHCChineseImperialNavy
    python .claude/skills/aoe-game-text/scripts/textlint.py --id 503609 503608
    python .claude/skills/aoe-game-text/scripts/textlint.py --text "Ships 1 Treasure Ship and 1 Fire Junk."

Style rules come from the live vanilla string table (see ../SKILL.md for the counts). --tech also merges the tech
like the engine does (vanilla record, then the techtreemods record: mergemode remove drops the matching vanilla
effect, everything else appends), lists the units it ships and checks that the description names each of them with
its count, and that every Home City card badge (<displayunitcount>) equals the number of units shipped.
Exit 1 when a FAIL is found. Reads the game archives in memory; writes nothing.
"""
import argparse, os, re, sys
import xml.etree.ElementTree as ET

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", ".."))
sys.path.insert(0, os.path.join(REPO, ".claude", "skills", "aoe3de-bar-archives", "scripts"))
sys.dont_write_bytecode = True
BS = chr(92)

RULES = [  # (level, regex, message)
    ("FAIL", r"\b(we|our|us|my|I)\b", "first person - vanilla card/tech text never uses it (0 of 1,617 card texts)"),
    ("FAIL", r"\blike (the|a|an)\b|\bas (the|a|an) (one|ship|unit)\b", "comparison / storytelling - 1 of 1,617 card texts; lore belongs in the name"),
    ("FAIL", r"\bhit points\b|\bDefence\b|\barmour\b|\bcolour\b|\bhonour\b", "British spelling - vanilla: hitpoints, Defense, armor"),
    ("WARN", r"!", "exclamation - 4% of vanilla card texts; avoid"),
    ("WARN", r"(?<![A-Z][a-z])\b(coin|food|wood)\b", "resource names are capitalised in rules text (Coin, Food, Wood)"),
    ("WARN", r"\b(mighty|legendary|glorious|awesome|epic|amazing|incredible)\b", "hype adjective - state the effect instead"),
]
MAX_WORDS = 21   # 90th percentile of vanilla Home City card texts (median 12)
# colour tags (owner rule 2026-09-27, matches the mod's 237 tags): gold = politician/UI headers, yellow = highlighted
# label, red = inactive / forbidden, green = Bonus. Anything else is rare and needs a reason.
PALETTE = {"1.0,0.9,0.5": "gold (politician/UI header)", "1.0,1.0,0.0": "yellow (highlighted label)",
           "1.0,0.0,0.0": "red (inactive / forbidden)", "0.0,1.0,0.0": "green (Bonus)"}


def colour_findings(text, label):
    out = []
    for m in re.finditer(r"<color=\s*([^>]+?)\s*>", text):
        k = re.sub(r"\s+", "", m.group(1))
        if k not in PALETTE:
            out.append(("WARN", "%s: colour %s is outside the palette (gold 1.0,0.9,0.5 header / yellow 1.0,1.0,0.0 label / "
                                "red 1.0,0.0,0.0 inactive / green 0.0,1.0,0.0 Bonus)" % (label, k)))
    return out


def rollover_number_findings(text, label, flags):
    """Without DEHideAdvancedRollover the game prints the effect values (the advanced rollover) right above the
    description, so the description must not repeat numbers (owner rule 2026-09-27)."""
    if "DEHideAdvancedRollover" not in flags and re.search(r"\d", re.sub(r"%\d*[a-zA-Z]|<color=[^>]+>", "", text)):
        return [("WARN", "%s: numbers in the text - the tech has no DEHideAdvancedRollover, so the game already shows "
                         "the values above it; drop them (or set the flag and keep them)" % label)]
    return []


class Game:
    def __init__(self):
        import bartool
        self.bt = bartool
        idx = bartool.build_index(bartool.find_game_dir())
        self.arch = {}
        for e in (idx.values() if isinstance(idx, dict) else idx):
            p = getattr(e, "path", None) or getattr(e, "name", None) or str(e)
            self.arch[str(p).replace("/", BS).lower()] = e

    def xml(self, rel):
        e = self.arch.get(rel.lower()) or self.arch.get(rel.lower() + ".xmb")
        if e is None:
            return None
        data, _ = self.bt.decode(self.bt.read_entry(e), True)
        return ET.fromstring(data.decode("utf-8", "ignore"))

    def homecity_files(self):
        return [k for k in self.arch if re.search(r"data\\homecity[a-z]*\.xml(\.xmb)?$", k)]


def strings(game):
    s = {}
    van = game.xml("data" + BS + "strings" + BS + "english" + BS + "stringtabley.xml")
    for e in van.iter("string"):
        s[e.get("_locid")] = (e.text or "").strip()
    for e in ET.parse(os.path.join(REPO, "data", "strings", "english", "stringmods.xml")).getroot().iter("string"):
        s[e.get("_locid")] = (e.text or "").strip()
    return s


def lint(text, label):
    out = []
    for level, rx, msg in RULES:
        m = re.search(rx, text)
        if m:
            out.append((level, "%s: '%s' - %s" % (label, m.group(0), msg)))
    n = len(text.split())
    if n > MAX_WORDS and "\\n" not in text:        # multi-line politician texts have their own formats
        out.append(("WARN", "%s: %d words - vanilla card texts: median 12, 90%% at most %d" % (label, n, MAX_WORDS)))
    return out + colour_findings(text, label)


def tech_flags_by_rollover():
    """rollovertextid -> flags of the mod tech using it (techtreemods; vanilla flags are merged in --tech mode)."""
    out = {}
    for t in ET.parse(os.path.join(REPO, "data", "techtreemods.xml")).getroot().iter("tech"):
        r = (t.findtext("rollovertextid") or "").strip()
        if r:
            out[r] = [f.text for f in t.findall("flag")]
    return out


def sig(ef):
    a = {k.lower(): v for k, v in ef.attrib.items() if k.lower() != "mergemode"}
    return (tuple(sorted(a.items())), tuple((t.get("type"), (t.text or "").strip()) for t in ef.findall("target")),
            (ef.text or "").strip())


def merged_tech(game, name):
    van = next((t for t in game.xml("data" + BS + "techtreey.xml").iter("tech") if t.get("name") == name), None)
    mod = next((t for t in ET.parse(os.path.join(REPO, "data", "techtreemods.xml")).getroot().iter("tech")
                if t.get("name") == name), None)
    if van is None and mod is None:
        raise SystemExit("tech %s not found" % name)
    fields = {}
    effects = [e for e in (van.iter("effect") if van is not None else [])]
    for src in (van, mod):
        if src is None:
            continue
        for tag in ("displaynameid", "rollovertextid", "icon", "researchpoints"):
            if src.find(tag) is not None:
                fields[tag] = (src.findtext(tag) or "").strip()
    if mod is not None and van is not None:
        for ef in mod.iter("effect"):
            if (ef.get("mergemode") or ef.get("mergeMode") or "").lower() == "remove":
                hit = [e for e in effects if sig(e) == sig(ef)]
                if not hit:
                    print("WARN  techtreemods removal matches no vanilla effect: %s" % (sig(ef),))
                effects = [e for e in effects if sig(e) != sig(ef)]
            else:
                effects.append(ef)
    elif mod is not None:
        effects = list(mod.iter("effect"))
    fields["flags"] = [f.text for src in (van, mod) if src is not None for f in src.findall("flag")]
    return fields, effects


def shipped(effects):
    units = {}
    for ef in effects:
        sub = ef.get("subtype") or ""
        if sub.startswith("FreeHomeCityUnit"):
            units[ef.get("unittype")] = units.get(ef.get("unittype"), 0) + int(float(ef.get("amount", "1")))
            if ef.get("unittype2"):
                units[ef.get("unittype2")] = units.get(ef.get("unittype2"), 0) + int(float(ef.get("amount2", "1")))
    return units


def unit_names(game, S):
    names = {}
    for root in (game.xml("data" + BS + "protoy.xml"), ET.parse(os.path.join(REPO, "data", "protomods.xml")).getroot()):
        for u in root.iter("unit"):
            d = u.findtext("displaynameid")
            if u.get("name") and d:
                names[u.get("name")] = S.get(d.strip(), u.get("name"))
    return names


def mod_strings(xml_text):
    root = ET.fromstring(xml_text)
    return {e.get("_locid"): (e.text or "").strip() for e in root.iter("string")}


def changed_strings():
    """ids new or changed in english/stringmods.xml since HEAD (git), with their text."""
    import subprocess
    rel = "data/strings/english/stringmods.xml"
    now = mod_strings(open(os.path.join(REPO, rel), "rb").read().decode("utf-8"))
    try:
        head = mod_strings(subprocess.run(["git", "show", "HEAD:" + rel], cwd=REPO, capture_output=True, check=True).stdout.decode("utf-8"))
    except Exception:
        head = {}
    return {i: t for i, t in now.items() if head.get(i) != t}


def placeholders(s):
    return tuple(re.findall(r"%\d*[a-zA-Z]", s or ""))


def nugget_findings(game, S):
    """Nugget strings are printf formats filled by the engine per nugget <type>: a placeholder the engine does not
    pass, or of the wrong kind, crashes the game (391d6085, 2024-07-16: rollover/apply ids swapped). Allowed patterns
    per (type, second resource?, field) are the ones vanilla nuggets.xml uses; no placeholder at all is always safe."""
    out = []
    allowed = {}
    for n in game.xml("data" + BS + "nuggets.xml").iter("nugget"):
        key = ((n.findtext("type") or "").strip(), n.find("resource2") is not None)
        for field in ("rolloverstringid", "applystringid"):
            i = (n.findtext(field) or "").strip()
            if i in S:
                allowed.setdefault(key + (field,), set()).add(placeholders(S[i]))
    for n in ET.parse(os.path.join(REPO, "data", "nuggetmods.xml")).getroot().iter("nugget"):
        key = ((n.findtext("type") or "").strip(), n.find("resource2") is not None)
        name = (n.findtext("name") or "?").strip()
        for field in ("rolloverstringid", "applystringid"):
            i = (n.findtext(field) or "").strip()
            if not i:
                continue
            if i not in S:
                out.append(("FAIL", "nugget %s: %s %s is not a string" % (name, field, i)))
                continue
            p = placeholders(S[i])
            ok = allowed.get(key + (field,))
            if p and ok is not None and p not in ok:
                out.append(("FAIL", "nugget %s (type %s): %s %s has %s - vanilla uses %s for this type and field; a wrong "
                            "placeholder crashes the game" % (name, key[0], field, i, " ".join(p) or "none",
                                                              " | ".join(" ".join(x) or "none" for x in sorted(ok)))))
            elif p and ok is None:
                out.append(("WARN", "nugget %s: type %s has no vanilla string for %s - placeholders %s unverified"
                            % (name, key[0], field, " ".join(p))))
    return out


def team_findings(S):
    """Team techs (flag TeamTech) must say so in the name: vanilla 'TEAM ...' (206 of 210), the mod 'Team ...'."""
    out = []
    for t in ET.parse(os.path.join(REPO, "data", "techtreemods.xml")).getroot().iter("tech"):
        if "TeamTech" in [f.text for f in t.findall("flag")]:
            name = S.get((t.findtext("displaynameid") or "").strip(), "")
            if name and not re.match(r"team\b", name, re.I):
                out.append(("FAIL", "team tech %s: name '%s' must start with 'Team' (owner rule; vanilla 'TEAM' 206 of 210)"
                            % (t.get("name"), name)))
    return out


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--tech", nargs="*", default=[])
    ap.add_argument("--id", nargs="*", default=[])
    ap.add_argument("--text", nargs="*", default=[])
    ap.add_argument("--changed", action="store_true", help="lint every English string new or changed since HEAD")
    ap.add_argument("--nuggets", action="store_true", help="nuggetmods string placeholders against vanilla per nugget type")
    ap.add_argument("--team", action="store_true", help="team techs in techtreemods must be named 'TEAM ...'")
    ap.add_argument("--hook", action="store_true", help="= --changed --nuggets --team (run by stringsync.py --build)")
    a = ap.parse_args(argv)
    if a.hook:
        a.changed = a.nuggets = a.team = True
    findings = [f for i, t in enumerate(a.text) for f in lint(t, "text %d" % (i + 1))]
    if a.changed:
        ch = changed_strings()
        print("changed or new English strings since HEAD: %d" % len(ch))
        rf = tech_flags_by_rollover()
        for i, txt in sorted(ch.items(), key=lambda kv: int(kv[0])):
            findings += lint(txt, "string %s" % i)
            if i in rf:
                findings += rollover_number_findings(txt, "string %s" % i, rf[i])
    if a.nuggets or a.team:
        try:
            game = Game()
            S = strings(game)
        except Exception as e:      # no game install (CI): the nugget check needs vanilla nuggets.xml
            print("SKIPPED nugget/team checks: %s" % e)
            game = None
        if game is not None:
            findings += (nugget_findings(game, S) if a.nuggets else []) + (team_findings(S) if a.team else [])
    if a.id or a.tech:
        game = Game()
        S = strings(game)
        findings += [f for i in a.id for f in lint(S.get(i, ""), "string %s" % i)]
        names = unit_names(game, S) if a.tech else {}
        for tech in a.tech:
            fields, effects = merged_tech(game, tech)
            title, text = S.get(fields.get("displaynameid", ""), "?"), S.get(fields.get("rollovertextid", ""), "")
            print("%s: name '%s' | text '%s'" % (tech, title, text))
            findings += lint(text, "%s description" % tech)
            findings += rollover_number_findings(text, "%s description" % tech, fields["flags"])
            units = shipped(effects)
            for u, n in units.items():
                dn = names.get(u, u)
                if not re.search(r"\b%s\b" % re.escape(dn), text, re.I) and not re.search(r"\b%ss?\b" % re.escape(dn), text, re.I):
                    findings.append(("FAIL", "%s: ships %d %s (%s) but the description does not name it" % (tech, n, dn, u)))
            print("   ships: %s" % (", ".join("%d %s" % (n, names.get(u, u)) for u, n in units.items()) or "no units"))
            for hc in game.homecity_files():
                root = game.xml(hc.replace(".xmb", ""))
                for c in (root.iter("card") if root is not None else []):
                    if (c.findtext("name") or "").lower() == tech.lower() and c.findtext("displayunitcount"):
                        badge = int(c.findtext("displayunitcount"))
                        if units and badge != sum(units.values()):
                            findings.append(("FAIL", "%s: card badge in %s says %d, the card ships %d units"
                                             % (tech, hc.split(BS)[-1], badge, sum(units.values()))))
    for level, msg in findings:
        print("%-5s %s" % (level, msg))
    fails = sum(1 for f in findings if f[0] == "FAIL")
    print("%d FAIL, %d WARN" % (fails, len(findings) - fails))
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
