"""Pre-zip audit of the Age of Pirates mod folder.

Deployment is from LOCAL FILES, not from git: whatever sits in the five game
folders (art, data, game, sound, randmaps) goes into the zip and onto the mod
portal. This script walks those folders on disk (or an existing zip) and
reports anything that is not game content or looks unfinished. It changes
nothing.

    python .claude/skills/mod-deploy-check/scripts/prezip_check.py            # audit the folders
    python .claude/skills/mod-deploy-check/scripts/prezip_check.py --zip age-of-pirates.zip
    python .claude/skills/mod-deploy-check/scripts/prezip_check.py --root <mod folder>

Exit code 0 = clean, 1 = blocking findings, 2 = warnings only.
Standard library only (bar-extract's bartool.py is borrowed, if present, to
decode XMB twins and compare their CONTENT with the .xml). Read-only.
"""
from __future__ import annotations
import argparse, os, re, subprocess, sys, time, zipfile
import xml.etree.ElementTree as ET
from collections import Counter, defaultdict

GAME_DIRS = ("art", "data", "game", "sound", "randmaps")

# Every extension the game itself ships (verified against the vanilla .bar
# archives on 2026-09-02) plus the loose-file formats the mod relies on.
NATIVE_EXT = {
    ".xml", ".xmb", ".xs", ".png", ".ddt", ".gr2", ".material", ".wav", ".mp3",
    ".tactics", ".hkt", ".precomp", ".dmg", ".lgt", ".set", ".pkfx", ".particle",
    ".xaml", ".tga", ".age3yscn", ".age3ysav", ".json", ".ttf", ".otf", ".bik",
    ".txt",
}
# Things that are never game content, whatever their extension.
BACKUP_RE = re.compile(r"(\.prev|\.bak|\.orig|\.old|\.tmp|\.temp|\.swp|~|\.28bak)$"
                       r"|(^|/)(_backups?|backups?|__pycache__|\.git|\.claude|\.vscode|\.pytest_cache|sandbox|scripts|docs)(/|$)"
                       r"|(^|/)(Thumbs\.db|desktop\.ini|\.DS_Store)$", re.I)
DOC_OR_CODE_EXT = {".md", ".py", ".pyc", ".ps1", ".bat", ".cmd", ".sh", ".exe", ".dll",
                   ".zip", ".7z", ".rar", ".psd", ".fbx", ".blend", ".max", ".obj",
                   ".log", ".csv", ".yaml", ".yml", ".ini", ".cfg", ".stackdump", ".mp4"}
ODD_NAME_RE = re.compile(r"[()\[\]{},;'\"!@#$%^&=+`]|^\s|\s$|\s\.|\.\s")
# "a.png.png", "a.gr2.gr2", "a.ddt.tga": a binary extension repeated or stacked.
STACKED_BIN_RE = re.compile(r"\.(png|ddt|gr2|tga|wav|mp3|xs)\.(png|ddt|gr2|tga|wav|mp3|xs)$", re.I)
PORTAL_LIMIT_GB = 2.0          # compressed zip, per the user (2026-09-02)
LAST_KNOWN_RATIO = 1.89 / 2.78 # compressed / uncompressed of the 2026-09-02 build

# ---- borrow the XMB decoder from the bar-extract skill, if it is there ------
def _load_bartool():
    here = os.path.dirname(os.path.abspath(__file__))
    cand = os.path.normpath(os.path.join(here, "..", "..", "bar-extract", "scripts"))
    if os.path.isfile(os.path.join(cand, "bartool.py")):
        sys.dont_write_bytecode = True          # never leave __pycache__ behind
        sys.path.insert(0, cand)
        try:
            import bartool                       # noqa: E402
            return bartool
        except Exception:
            return None
    return None

BARTOOL = _load_bartool()


def canon(el):
    """Canonical, whitespace-insensitive view of an element tree.

    All runs of whitespace collapse to one space: the XMB stores a CRLF that
    sits inside a string as LF, which is not a content difference."""
    return (el.tag, tuple(sorted(el.attrib.items())), re.sub(r"\s+", " ", el.text or "").strip(),
            tuple(canon(c) for c in list(el)))


def xmb_matches_xml(xmb_bytes, xml_bytes):
    """True / False, or None when it cannot be decided."""
    if BARTOOL is None:
        return None
    try:
        data = BARTOOL.unwrap_alz4(xmb_bytes)
        if not BARTOOL.is_xmb(data):
            return None
        a = BARTOOL.xmb_to_element(data)
        b = ET.fromstring(xml_bytes)
        return canon(a) == canon(b)
    except Exception:
        return None


class Report:
    def __init__(self):
        self.block = defaultdict(list)
        self.warn = defaultdict(list)
        self.info = []

    def b(self, cat, item): self.block[cat].append(item)
    def w(self, cat, item): self.warn[cat].append(item)


def audit(entries, rep, on_disk_root=None):
    """entries: list of (relative posix path, size, mtime, reader) - reader() -> bytes."""
    names = [e[0] for e in entries]
    byname = {e[0]: e for e in entries}
    total = sum(e[1] for e in entries)
    ext = Counter((os.path.splitext(n)[1].lower() or "(none)") for n in names)
    rep.info.append("%d files, %.2f GB uncompressed" % (len(names), total / 1e9))
    rep.info.append("estimated zip %.2f GB at the last known ratio (portal limit %.0f GB compressed)"
                    % (total / 1e9 * LAST_KNOWN_RATIO, PORTAL_LIMIT_GB))
    rep.info.append("extensions: " + "  ".join("%s=%d" % kv for kv in ext.most_common()))
    spaces = 0

    for n, size, mtime, _rd in entries:
        top = n.split("/")[0]
        e = os.path.splitext(n)[1].lower()
        base = n.rsplit("/", 1)[-1]
        if top not in GAME_DIRS:
            rep.b("outside the five game folders (must not be zipped)", n); continue
        if BACKUP_RE.search(n):
            rep.b("backup / tooling / repo leftovers", n)
        elif e in DOC_OR_CODE_EXT:
            rep.b("documentation, code or archive - not game content", n)
        elif e not in NATIVE_EXT:
            rep.b("extension the game does not ship (verify or remove)", n)
        if ODD_NAME_RE.search(base) or any(ord(c) > 127 for c in n):
            rep.b("odd characters in the name (validators choke on these)", n)
        if STACKED_BIN_RE.search(base):
            rep.w("stacked binary extension (export leftover?)", n)
        if size == 0:
            rep.b("zero-byte file", n)
        # content sniff: the extension says one thing, the bytes another (2026-09-02:
        # four data/wpfg .png were JPEGs inside - the only anomaly in a rejected data/)
        try:
            head = _rd()[:12]
            if (e == ".png" and head[:8] != b"\x89PNG\r\n\x1a\n") or \
               (e == ".wav" and head[:4] != b"RIFF") or \
               (e == ".ddt" and head[:4] != b"RTS3") or \
               (e == ".xmb" and head[:4] != b"alz4" and head[:2] != b"X1") or \
               (e in (".xml", ".material", ".tactics", ".lgt", ".particle", ".set", ".xaml")
                and not head.lstrip(b"\xef\xbb\xbf").lstrip().startswith(b"<")):
                rep.b("CONTENT does not match the extension (mislabelled file)", n + "  head=" + repr(head[:4]))
        except Exception:
            pass
        if base.startswith("."):
            rep.b("hidden file", n)
        if len(n) > 200:
            rep.w("very long path (>200 chars; Windows limit is 260 incl. the install path)", n)
        if " " in n:
            spaces += 1
    if spaces:
        rep.info.append("%d paths contain spaces (normal for this mod's groupings; not a finding)" % spaces)

    lc = Counter(n.lower() for n in names)
    for n, c in lc.items():
        if c > 1:
            rep.b("case-insensitive duplicate path", n)

    # XMB twins: the game loads the .xmb. Compare its CONTENT with the .xml.
    undecidable = 0
    for n in names:
        if not n.lower().endswith(".xml.xmb"):
            continue
        x = n[:-4]
        twin = byname.get(x) or next((byname[k] for k in byname if k.lower() == x.lower()), None)
        if twin is None:
            continue
        verdict = xmb_matches_xml(byname[n][3](), twin[3]())
        if verdict is False:
            rep.b("STALE XMB twin - its content differs from the .xml (rebuild it)", n)
        elif verdict is None:
            undecidable += 1
            m_x, m_t = byname[n][2], twin[2]
            if m_x is not None and m_t is not None and m_x < m_t:
                rep.w("XMB older than its .xml by mtime (content not decodable here - verify)", n)
    if undecidable and BARTOOL is None:
        rep.info.append("XMB content check unavailable (bar-extract skill not found) - mtime fallback used")

    # git awareness, informational
    if on_disk_root:
        try:
            out = subprocess.run(["git", "-C", on_disk_root, "ls-files", "-z", "--", *GAME_DIRS],
                                 capture_output=True, text=True, timeout=30).stdout
            tracked = set(p for p in out.split("\0") if p)
            nameset = set(names)
            for n in names:
                if n not in tracked:
                    rep.w("on disk but not tracked in git (gitignored or new - decide)", n)
            for t in tracked:
                if t not in nameset:
                    rep.w("tracked in git but MISSING on disk", t)
        except Exception as ex:
            rep.info.append("git check skipped (%s)" % ex)


def walk_disk(root):
    out = []
    for d in GAME_DIRS:
        base = os.path.join(root, d)
        if not os.path.isdir(base):
            continue
        for dp, dn, fn in os.walk(base):
            for f in fn:
                p = os.path.join(dp, f)
                rel = os.path.relpath(p, root).replace("\\", "/")
                st = os.stat(p)
                out.append((rel, st.st_size, st.st_mtime, (lambda q=p: open(q, "rb").read())))
    return out


def walk_zip(path):
    z = zipfile.ZipFile(path)
    out = []
    for i in z.infolist():
        if i.is_dir():
            continue
        m = time.mktime(i.date_time + (0, 0, -1))
        out.append((i.filename, i.file_size, m, (lambda nm=i.filename: z.read(nm))))
    return out


def top_level_notes(root, rep):
    extra = sorted(e for e in os.listdir(root) if e not in GAME_DIRS and not e.startswith("."))
    rep.info.append("top-level entries that are NOT game folders (leave them out of the zip): " + ", ".join(extra))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default=None, help="mod folder (default: the git root of the cwd, else cwd)")
    ap.add_argument("--zip", default=None, help="audit an existing zip instead of the folders")
    a = ap.parse_args()
    rep = Report()
    if a.zip:
        entries = walk_zip(a.zip)
        rep.info.append("source: zip %s (%.2f GB on disk)" % (a.zip, os.path.getsize(a.zip) / 1e9))
        audit(entries, rep)
    else:
        root = a.root or subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True,
                                        text=True).stdout.strip() or os.getcwd()
        rep.info.append("source: folders under %s" % root)
        entries = walk_disk(root)
        top_level_notes(root, rep)
        audit(entries, rep, on_disk_root=root)

    for line in rep.info:
        print("  " + line)
    print()
    if rep.block:
        print("BLOCKING (%d categories):" % len(rep.block))
        for cat, items in rep.block.items():
            print("  [%d] %s" % (len(items), cat))
            for it in items[:25]:
                print("        " + it)
            if len(items) > 25:
                print("        ... +%d more" % (len(items) - 25))
    if rep.warn:
        print("WARNINGS (%d categories):" % len(rep.warn))
        for cat, items in rep.warn.items():
            print("  [%d] %s" % (len(items), cat))
            for it in items[:8]:
                print("        " + it)
            if len(items) > 8:
                print("        ... +%d more" % (len(items) - 8))
    verdict = "CLEAN - ready to zip" if not rep.block and not rep.warn else \
              ("NOT READY - fix the blocking items" if rep.block else "READY with warnings - read them")
    print("\nVERDICT: " + verdict)
    sys.exit(1 if rep.block else (2 if rep.warn else 0))


if __name__ == "__main__":
    main()
