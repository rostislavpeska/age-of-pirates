"""Independent audit of the WP1 manifest. Written by Claude, 2026-10-26. The WP1 agent RUNS it and never edits it.

usage (repo root):  python docs/briefs/bourbon-rework/audit_wp1.py [<vanilla dir>] [-v]
    <vanilla dir> defaults to <tempdir>/aop-bourbon/vanilla (the six bartool extracts).
exit 0 = every check passed; 1 = at least one FAIL (each FAIL prints its evidence). -v also prints the PASS lines.

Repo files are read from git at the manifest's metadata.repo_commit, so later edits to the working tree do not move
the line numbers WP1 described. Every location (line number, range, dbid) must be one the files confirm; a number a
tool did not produce fails here.
  A  name map: structured vanilla_file / vanilla_line (opening-tag line) / vanilla_dbid fields; no numbers in notes
  B  package D: every range equals the real record extent (opening tag .. closing tag), every line/text pair is exact
  C  groupings: counts, CRLF-normalised sha256, profile identity
  D  line inventory: every quoted line is the real line
  E  completeness: every occurrence (any case) in data/, game/ai/core/, maps, sound/ is inventoried
  F  facts: clone power, Bourbon flag, musketeer Build action
  J  manifest.md: UTF-8 without '?' mojibake; every line/dbid number it prints exists in manifest.json
  K  WP1-report.md: names the audit command and says "Owner tests: none (read-only package)"
"""
import hashlib, json, re, subprocess, sys, tempfile
from pathlib import Path

REPO = Path.cwd()
args = [a for a in sys.argv[1:] if not a.startswith("-")]
V = Path(args[0]) if args else Path(tempfile.gettempdir()) / "aop-bourbon" / "vanilla"
OUT = REPO / "docs/briefs/bourbon-rework"
M = json.loads((OUT / "manifest.json").read_text(encoding="utf-8"))
BASE = M["metadata"]["repo_commit"]
PROFILE_G = REPO.parents[2] / "RandMaps" / "groupings"
VERBOSE = "-v" in sys.argv
res = {"PASS": 0, "FAIL": 0}


def out(ok, what, ev=""):
    res["PASS" if ok else "FAIL"] += 1
    if not ok or VERBOSE:
        print(("PASS " if ok else "FAIL ") + what + (("  | " + str(ev)) if ev != "" else ""))


def git_bytes(rel):
    r = subprocess.run(["git", "show", "%s:%s" % (BASE, rel)], capture_output=True)
    return r.stdout if r.returncode == 0 else None


_cache = {}


def lines_of(p):
    """Lines of a repo file at BASE (git), or of any other file on disk."""
    p = Path(p)
    if p not in _cache:
        try:
            rel = p.resolve().relative_to(REPO.resolve()).as_posix()
        except ValueError:
            rel = None
        b = git_bytes(rel) if rel else None
        if b is None:
            b = p.read_bytes() if p.is_file() else b""
        _cache[p] = b.decode("utf-8", "replace").splitlines()
    return _cache[p]


def extent(path, kind, name):
    """1-based (start, end): the record's opening-tag line .. the first closing-tag line after it."""
    L = lines_of(path)
    if kind == "civ":
        n = next((i for i, l in enumerate(L) if l.strip() == "<name>%s</name>" % name), None)
        if n is None:
            return None
        s = max(i for i in range(n + 1) if L[i].strip().startswith("<civ>"))
    else:
        rx = re.compile(r'<%s\b[^>]*\bname="%s"' % (kind, re.escape(name)))
        s = next((i for i, l in enumerate(L) if rx.search(l)), None)
        if s is None:
            return None
    e = next(i for i in range(s, len(L)) if "</%s>" % kind in L[i])
    return s + 1, e + 1


norm = lambda s: re.sub(r"\s+", " ", s).strip()
blk = lambda s, k, n: re.search(r'<%s\b[^>]*\bname="%s"[^>]*>.*?</%s>' % (k, re.escape(n), k), s, re.S)
VFILES = {f: V / f for f in ("techtreey.xml", "protoy.xml", "civs.xml", "powers.xml", "abilities.xml", "protounitcommands.xml")}
for f, p in VFILES.items():
    if not p.exists():
        print("FAIL vanilla file missing: %s (pass the vanilla dir as the first argument)" % p)
        sys.exit(1)

print("== A. name map")
for row in M["name_map"]:
    new = row.get("new", "")
    if new.startswith("KEEP") or "/" in new:
        continue
    vf, vl, vd = row.get("vanilla_file"), row.get("vanilla_line"), row.get("vanilla_dbid")
    if vf not in VFILES or not isinstance(vl, int):
        out(False, "%s: needs vanilla_file (one of %s) and an integer vanilla_line" % (row["old"], ", ".join(VFILES)), "got %r / %r" % (vf, vl))
        continue
    kind = {"techtreey.xml": "tech", "protoy.xml": "unit", "civs.xml": "civ"}.get(vf)
    ex = extent(VFILES[vf], kind, new) if kind else None
    out(bool(ex) and ex[0] == vl, "%s -> %s at %s:%s" % (row["old"], new, vf, vl), "real opening-tag line %s" % (ex[0] if ex else None))
    if kind == "tech" and ex:
        m = re.search(r"<dbid>(\d+)</dbid>", "\n".join(lines_of(VFILES[vf])[ex[0] - 1:ex[1]]))
        out(m is not None and str(vd) == m.group(1), "%s vanilla_dbid" % new, "manifest %r, real %s" % (vd, m.group(1) if m else None))
    bad = re.findall(r"\b(?:line|lines|dbid)\s+\d+", row.get("notes", ""), re.I)
    out(not bad, "%s notes carry no hand-written numbers" % row["old"], bad)

print("== B. package D")
KIND = {"techtreemods": ("data/techtreemods.xml", "tech"), "protomods": ("data/protomods.xml", "unit"), "civmods": ("data/civmods.xml", "civ")}
for key, entries in M["deletion_candidates_package_d"].items():
    if not isinstance(entries, list):
        out(False, "%s must be a list of entries, not text" % key, str(entries)[:80])
        continue
    tgt = next((v for k, v in KIND.items() if key.endswith("_in_" + k)), None)
    for e in entries:
        if not isinstance(e, dict):
            out(False, "%s entry must be an object with file/line/text or name/start_line/end_line" % key, str(e)[:100])
            continue
        f = REPO / e.get("file", e.get("path", tgt[0] if tgt else ""))
        if e.get("type") == "branch":                 # a <choice name="SPCBourbon"> block inside a soundset
            ex = None
            L = lines_of(f)
            s0 = e.get("start_line", 0)
            if 0 < s0 <= len(L) and '<choice name="SPCBourbon">' in L[s0 - 1]:
                ex = (s0, next(i + 1 for i in range(s0 - 1, len(L)) if "</choice>" in L[i]))
            out(ex is not None and ex == (s0, e.get("end_line")), "%s branch %s-%s is a whole SPCBourbon <choice>" % (f.name, s0, e.get("end_line")), "real %s" % (ex,))
            continue
        if "start_line" in e:
            if "name" not in e or not tgt:
                out(False, "%s range entry needs 'name' and a checkable file" % key, json.dumps(e)[:120])
                continue
            ex = extent(f, tgt[1], e["name"])
            out(ex == (e["start_line"], e["end_line"]), "%s %s %s-%s is the whole record" % (f.name, e["name"], e["start_line"], e["end_line"]), "real %s" % (ex,))
        elif "line" in e:
            L = lines_of(f)
            real = L[e["line"] - 1].strip() if 0 < e["line"] <= len(L) else "<no such line>"
            out(real == e.get("text", "").strip(), "%s:%s text is exact (comments go in a separate 'note' field)" % (f.name, e["line"]), "real: " + real[:90])
        elif e.get("type") == "file":
            out(bool(git_bytes(e.get("path", ""))), "file exists at %s: %s" % (BASE, e.get("path")))
        else:
            out(False, "%s entry has no checkable location" % key, json.dumps(e)[:120])

print("== C. groupings")
for g in M["groupings_table"]:
    rel = "game/randmaps/groupings/" + g["grouping"]
    pp = PROFILE_G / g["grouping"]
    if g.get("in_repo"):
        b = git_bytes(rel) or b""
        n = b.replace(b"\r\n", b"\n")
        cnt = (b.count(b">zpSocketSPCBourbon<"), b.count(b">zpNatRoyalMusketeer<"))
        out(cnt == (g["repo_socket_count"], g["repo_musketeer_count"]), "%s counts" % g["grouping"], cnt)
        out(hashlib.sha256(n).hexdigest() == g.get("repo_sha256"), "%s sha256" % g["grouping"])
        if pp.exists():
            pn = pp.read_bytes().replace(b"\r\n", b"\n")
            now = (REPO / rel).read_bytes().replace(b"\r\n", b"\n")   # the profile copy may since have been edited with the repo copy
            out(((pn == n) or (pn == now)) == g["profile_matches_repo_crlf_norm"], "%s profile identity" % g["grouping"])
    else:
        out(pp.exists(), "%s profile-only file exists" % g["grouping"])

print("== D. line inventory quotes")
for e in M["line_inventory"]:
    L = lines_of(REPO / e["file"])
    real = L[e["line"] - 1].strip() if 0 < e["line"] <= len(L) else "<no such line>"
    out(real == e["current_text"].strip(), "%s:%s quoted exactly" % (e["file"], e["line"]), "real: " + real[:90])

print("== E. completeness (case-insensitive)")
NAMES = """zpSPCNativeBourbon zpSPCNativeBourbonColonialize zpVeteranBourbon zpGuardBourbon zpNatBourbonReforms
 zpNatBourbonRoyalTax zpNatBourbonChouannerie zpNatBourbonMaisonDuRoi zpNativeTreatyBourbon zpIndianFriendshipBourbon
 zpNativeTradeTreatyBourbon zpUnknownAllianceBourbon zpUnknownAllianceBourbonEnabler zpNatRoyalMusketeer zpNatRoyalDragoon
 zpNatRoyalHorsemanBourbonProxy zpSocketSPCBourbon""".split()
pat = re.compile(r"spcbourbon|(?<![A-Za-z0-9_])(?:cTech|cUnitType)?(?:%s)(?![A-Za-z0-9_])" % "|".join(NAMES), re.I)
inv = {(e["file"].replace("\\", "/"), e["line"]) for e in M["line_inventory"]}
tracked = subprocess.run(["git", "ls-tree", "-r", "--name-only", BASE, "--", "data", "game/ai/core", "randmaps", "game/randmaps", "sound"],
                         capture_output=True, text=True).stdout.split("\n")
for rel in tracked:
    if not rel.lower().endswith((".xml", ".xs")) or "/groupings/" in rel:
        continue
    if rel.startswith("game/randmaps/") and rel.count("/") > 2:
        continue
    for i, line in enumerate(lines_of(REPO / rel), 1):
        if pat.search(line):
            out((rel, i) in inv, "%s:%s inventoried" % (rel, i), line.strip()[:90])

print("== F. facts")
zp = blk("\n".join(lines_of(REPO / "data/abilities/powermods.xml")), "power", "zpNatPowerRoyalMarch")
va = blk("\n".join(lines_of(VFILES["powers.xml"])), "power", "deNatPowerRoyalMarch")
out(bool(zp and va) and norm(zp.group(0)).replace("zpNatPowerRoyalMarch", "X") == norm(va.group(0)).replace("deNatPowerRoyalMarch", "X"),
    "clone power equals vanilla except its name")
cv = re.search(r"<civ>\s*<name>Bourbon</name>.*?</civ>", "\n".join(lines_of(VFILES["civs.xml"])), re.S)
out(bool(cv) and "homecityflagtexture" not in cv.group(0), "vanilla Bourbon civ has no homecityflagtexture")
mo = blk("\n".join(lines_of(REPO / "data/protomods.xml")), "unit", "deNatRoyalMusketeer")
out(bool(mo) and "Build" in mo.group(0), "the deNatRoyalMusketeer override carries a Build action")

print("== J. manifest.md")
md = (OUT / "manifest.md").read_bytes().decode("utf-8", "replace")
out(not re.search(r"\w \? \w|\d\?\d", md), "manifest.md has no '?' mojibake (write UTF-8)")
nums_json = set(re.findall(r"\d+", json.dumps(M)))
typed = [n for n in re.findall(r"\b(?:line|lines|dbid|at)\s+(\d+)", md, re.I) if n not in nums_json]
out(not typed, "every line/dbid number in manifest.md comes from manifest.json", typed[:10])

print("== K. WP1-report.md")
rep = (OUT / "WP1-report.md").read_text(encoding="utf-8", errors="replace")
out("audit_wp1.py" in rep, "the report names the audit command")
out("Owner tests: none (read-only package)" in rep, "the report says 'Owner tests: none (read-only package)'")

print("\nAUDIT: %d PASS, %d FAIL" % (res["PASS"], res["FAIL"]))
sys.exit(1 if res["FAIL"] else 0)
