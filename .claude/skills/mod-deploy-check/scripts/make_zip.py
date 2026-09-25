"""Build the deployment zip of the Age of Pirates mod - beta or production, optionally with maps stripped.

    python .claude/skills/mod-deploy-check/scripts/make_zip.py <out.zip>                        # nothing stripped
    python .claude/skills/mod-deploy-check/scripts/make_zip.py <out.zip> --strip-map istanbul --strip-map london

Who decides the strip list (SKILL.md): beta = only maps the owner names; prod = ask the owner every time (often none).

What goes in: every file under the five game folders (art data game sound randmaps) on DISK, at the archive root.
Always left out: files in a `backup` folder, and gitignored files (today: the untracked .tga exports).

--strip-map NAME removes a map COMPLETELY from the zip: every file whose name contains NAME (case-insensitive)
directly in `randmaps/` or `game/randmaps/` - the .xs, the .xml and the .mods.xml; at least one .xs must match (a typo
stops the build). Read the printed STRIP lines: a short NAME can match more maps than meant. Groupings, art,
sounds and icons stay (owner 2026-09-25: "what we usually strip are just maps"). The repo is never touched: no move, no
delete, no git mv. 2026-09-11 a production build held back only zpistanbulb.xml; the .xs and .mods.xml shipped and the
map still appeared in the lobby - hence all files of the map, and the check inside the finished zip.

The zip is written as <out>.part.zip (matches the *.zip gitignore rule, so a commit in the meantime cannot pick it up)
and renamed when complete. Deflate level 6; .png stored (already compressed). After writing, the zip is re-opened and
checked: CRC of every entry, only the five folders at the root, no stripped map left, entry count as planned.
Standard library only. Exit 0 = zip written and verified."""
from __future__ import annotations
import argparse, os, re, subprocess, sys, time, zipfile

GAME_DIRS = ("art", "data", "game", "sound", "randmaps")
MAP_DIRS = ("randmaps", "game/randmaps")          # map scripts live directly in these two folders
STORED = {".png", ".jpg", ".jpeg"}


def git(root, *a):
    return subprocess.run(["git", "-C", root] + list(a), capture_output=True, text=True).stdout


def plan(root, strip):
    ignored = set(git(root, "ls-files", "--others", "--ignored", "--exclude-standard", "--", *GAME_DIRS).splitlines())
    files, skipped = [], []
    for top in GAME_DIRS:
        for d, dirs, names in os.walk(os.path.join(root, top)):
            dirs.sort()
            for n in sorted(names):
                rel = os.path.relpath(os.path.join(d, n), root).replace(os.sep, "/")
                if any(p.lower() == "backup" for p in rel.split("/")[:-1]):
                    skipped.append((rel, "backup folder"))
                elif rel in ignored:
                    skipped.append((rel, "gitignored"))
                else:
                    files.append(rel)
    stripped = {}
    for name in strip:
        hit = [rel for rel in files if rel.rsplit("/", 1)[0] in MAP_DIRS and name.lower() in rel.rsplit("/", 1)[1].lower()]
        if not any(h.lower().endswith(".xs") for h in hit):
            sys.exit("--strip-map %s: no map script (.xs) in %s has that in its name - nothing stripped, stop" % (name, " / ".join(MAP_DIRS)))
        stripped[name] = hit
    gone = {rel for hit in stripped.values() for rel in hit}
    return [f for f in files if f not in gone], skipped, stripped


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("out", help="the zip to write (name ends in .zip, outside the five game folders; never overwritten)")
    ap.add_argument("--strip-map", action="append", default=[], metavar="NAME", help="remove every file of the matching map(s)")
    ap.add_argument("--root", default=None, help="mod folder (default: the git root of the cwd)")
    a = ap.parse_args()
    root = os.path.abspath(a.root or git(os.getcwd(), "rev-parse", "--show-toplevel").strip() or os.getcwd())
    out = os.path.abspath(a.out)
    part = out[:-4] + ".part.zip"
    if not out.lower().endswith(".zip"):
        sys.exit("the output name must end in .zip")
    rel_out = os.path.relpath(out, root).replace(os.sep, "/")
    if rel_out.split("/")[0] in GAME_DIRS:
        sys.exit("the zip must not be written inside a game folder: " + rel_out)
    for p in (out, part):
        if os.path.exists(p):
            sys.exit("exists, not overwritten: " + p)
    if not rel_out.startswith("..") and not git(root, "check-ignore", rel_out[:-4] + ".part.zip").strip():
        sys.exit("the temporary name %s would not be gitignored - stop" % (rel_out[:-4] + ".part.zip"))

    files, skipped, stripped = plan(root, a.strip_map)
    for key, hit in stripped.items():
        print("STRIP %-10s %s" % (key, ", ".join(hit)))
    for rel, why in skipped:
        print("leave out (%s): %s" % (why, rel))

    t0 = time.time(); raw = 0
    with zipfile.ZipFile(part, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6, allowZip64=True) as z:
        for i, rel in enumerate(files):
            p = os.path.join(root, rel)
            raw += os.path.getsize(p)
            ctype = zipfile.ZIP_STORED if os.path.splitext(rel)[1].lower() in STORED else zipfile.ZIP_DEFLATED
            z.write(p, rel, compress_type=ctype)
            if i % 1500 == 0:
                print("  %d/%d files, %.0f s" % (i, len(files), time.time() - t0), flush=True)

    # verify the finished archive before it gets its real name
    with zipfile.ZipFile(part) as z:
        names = z.namelist()
        bad = z.testzip()
    problems = []
    if bad:
        problems.append("CRC error in " + bad)
    if len(names) != len(files):
        problems.append("entries %d != planned %d" % (len(names), len(files)))
    tops = sorted({n.split("/")[0] for n in names})
    if not set(tops) <= set(GAME_DIRS):
        problems.append("unexpected top-level entries: %s" % tops)
    for name in a.strip_map:
        left = [n for n in names if n.rsplit("/", 1)[0] in MAP_DIRS and name.lower() in n.rsplit("/", 1)[1].lower()]
        if left:
            problems.append("stripped map still inside: %s" % left)
    if problems:
        print("VERIFY FAILED - the zip keeps its .part.zip name:", *problems, sep="\n  ")
        sys.exit(1)
    os.replace(part, out)
    size = os.path.getsize(out)
    print("DONE %s: %d files, %.2f GB in, %.3f GB zipped (portal limit 2 GB)%s, %.0f s; verified: CRC, top level %s, %s" % (
        out, len(names), raw / 1e9, size / 1e9, "" if size < 2e9 else " - OVER THE LIMIT", time.time() - t0, tops,
        ("no file of %s left" % ", ".join(a.strip_map)) if a.strip_map else "nothing stripped"))
    return 0 if size < 2e9 else 1


if __name__ == "__main__":
    sys.exit(main())
