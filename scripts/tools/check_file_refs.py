"""Reference validator: every <animfile> and <tactics> in protomods + map
mods files, checked against mod-local files AND the full archive index.
Written as a FILE because the bash heredoc collapses backslashes (see the
ids/heredoc memory) - which invalidated two earlier runs of this check.
"""
import glob
import io
import os
import re
import sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

SCRATCH = ("C:/Users/rosti/AppData/Local/Temp/claude/c--Users-rosti-Games-Age-of-"
           "Empires-3-DE-76561199512878537-mods-local-age-of-pirates/"
           "5b7fdc7a-c3d1-456d-b754-6770378f3405/scratchpad")
REPO = ("c:/Users/rosti/Games/Age of Empires 3 DE/76561199512878537/mods/local/"
        "age-of-pirates")

SEP = "\\"

archive = set()
for line in open(SCRATCH + "/archive_index.txt", encoding="utf-8", errors="replace"):
    archive.add(line.strip().lower().replace("/", SEP))

modfiles = set()
for root, dirs, files in os.walk(REPO):
    low = root.lower()
    if any(skip in low for skip in ("references", ".git", "runs")):
        continue
    for f in files:
        modfiles.add(os.path.relpath(os.path.join(root, f), REPO).lower())

print("archive entries: %d | mod files: %d" % (len(archive), len(modfiles)))
assert ("data" + SEP + "tactics" + SEP + "frigate.tactics.xmb") in archive, \
    "sanity probe failed - the index or separators are broken again"
print("sanity probe (frigate.tactics in archives): PASS")


def exists(ref, kind):
    r = ref.lower().replace("/", SEP).strip()
    if kind == "anim":
        pool = ["art" + SEP + r, "art" + SEP + r + ".xmb"]
    else:
        pool = ["data" + SEP + "tactics" + SEP + r,
                "data" + SEP + "tactics" + SEP + r + ".xmb"]
    for c in pool:
        if c in modfiles or c in archive:
            return True
    return False


missing = []
checked = 0
for path in ([REPO + "/data/protomods.xml"]
             + sorted(glob.glob(REPO + "/randmaps/*.mods.xml"))):
    s = open(path, encoding="utf-8", errors="replace").read()
    unit = "?"
    for m in re.finditer(r'<unit\b[^>]*name="([^"]+)"|<(animfile|tactics)>([^<]+)</\2>', s):
        if m.group(1):
            unit = m.group(1)
        else:
            checked += 1
            kind = "anim" if m.group(2) == "animfile" else "tactics"
            if not exists(m.group(3), kind):
                missing.append((os.path.basename(path), unit, kind, m.group(3).strip()))

print("references checked: %d" % checked)
print("BROKEN REFERENCES: %d" % len(missing))
for row in missing[:60]:
    print("   %-26s %-30s %-7s %s" % row)
if len(missing) > 60:
    print("   ... and %d more" % (len(missing) - 60))
