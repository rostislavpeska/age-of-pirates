"""Layer 2: anim-NAME validation. For every MOD tactics file: which protos
use it, which animfile each proto carries, and whether every <anim> name the
tactics demands appears in that animfile (mod art/ first, archives via
bartool otherwise). Heuristic text-containment on the anim XML - findings
are candidates for review, not convictions.
"""
import glob
import importlib.util
import io
import os
import re
import sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

REPO = ("c:/Users/rosti/Games/Age of Empires 3 DE/76561199512878537/mods/local/"
        "age-of-pirates")
os.chdir(REPO)
spec = importlib.util.spec_from_file_location(
    "bartool", ".claude/skills/bar-extract/scripts/bartool.py")
bt = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bt)

# proto -> (animfile, tactics) from protomods + map mods files
proto_anim = {}
proto_tactics = {}
for path in ([REPO + "/data/protomods.xml"]
             + sorted(glob.glob(REPO + "/randmaps/*.mods.xml"))):
    s = open(path, encoding="utf-8", errors="replace").read()
    unit = None
    for m in re.finditer(r'<unit\b[^>]*name="([^"]+)"|<(animfile|tactics)>([^<]+)</\2>', s):
        if m.group(1):
            unit = m.group(1)
        elif unit:
            if m.group(2) == "animfile":
                proto_anim.setdefault(unit, m.group(3).strip())
            else:
                proto_tactics.setdefault(unit, m.group(3).strip())

# the mod's OWN tactics files are the suspects
mod_tactics = {os.path.basename(f).lower(): f
               for f in glob.glob(REPO + "/data/tactics/*.tactics")}
print("mod tactics files: %d" % len(mod_tactics))

ANIM_TAG = re.compile(r"<anim[^>]*>([^<]+)</anim>", re.I)


def load_animfile(ref):
    """Return the anim XML text for an animfile reference, or None."""
    r = ref.replace("\\", "/").strip()
    local = os.path.join(REPO, "art", r)
    if os.path.exists(local):
        return open(local, encoding="utf-8", errors="replace").read()
    hits = bt.find(["art/" + r]) if hasattr(bt, "find") else []
    try:
        import subprocess
        out = subprocess.run(
            [sys.executable, ".claude/skills/bar-extract/scripts/bartool.py",
             "cat", "art/" + r],
            capture_output=True, timeout=120)
        if out.returncode == 0 and out.stdout:
            return out.stdout.decode("utf-8", errors="replace")
    except Exception:
        pass
    return None


findings = []
anim_cache = {}
checked_pairs = 0
for tfile_low, tfile in sorted(mod_tactics.items()):
    ttext = open(tfile, encoding="utf-8", errors="replace").read()
    anims = sorted(set(a.strip() for a in ANIM_TAG.findall(ttext) if a.strip()))
    if not anims:
        continue
    users = [u for u, t in proto_tactics.items() if t.lower() == tfile_low]
    for u in users:
        af = proto_anim.get(u)
        if not af:
            continue
        key = af.lower()
        if key not in anim_cache:
            anim_cache[key] = load_animfile(af)
        atext = anim_cache[key]
        if atext is None:
            findings.append((tfile_low, u, af, "ANIMFILE UNREADABLE"))
            continue
        low = atext.lower()
        checked_pairs += 1
        miss = [a for a in anims if a.lower() not in low]
        if miss:
            findings.append((tfile_low, u, af, "missing anims: " + ", ".join(miss[:8])))

print("tactics-proto pairs checked: %d" % checked_pairs)
print("FINDINGS: %d" % len(findings))
for t, u, af, msg in findings[:40]:
    print("   %-28s %-26s %s" % (t, u, msg))
    print("      animfile: %s" % af)
if len(findings) > 40:
    print("   ... and %d more" % (len(findings) - 40))
