#!/usr/bin/env python3
"""
mergetool - reconcile Age of Pirates overrides against a patched/DLC game build.

The mod replaces ~150 vanilla files wholesale. When a patch adds records to one of
those files, the mod's copy silently drops them (e.g. Baltic Powers added 268
soundsets to soundsetsde.xml that the mod's override does not contain).

This tool finds those losses and re-adds them, without disturbing anything else.

Pipeline
--------
  classify   which mod files override vanilla, which are new content
  baseline   snapshot the vanilla counterparts of every override
  report     per file: what the mod DROPS / ADDS / CONFLICTS with
  merge      write merged copies that re-add only the dropped records

`merge` is a text splice, not a re-serialisation: the mod file is copied byte for
byte and the missing records are inserted before the closing root tag. The diff
therefore shows only the additions.
"""

import argparse
import os
import sys
import xml.etree.ElementTree as ET

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                "..", "..", "bar-extract", "scripts"))
import bartool  # noqa: E402

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                    "..", "..", "..", ".."))

# Mod top-level dirs that ship into the game VFS. Everything else is repo-only.
SKIP_TOP = {".git", ".github", ".claude", "docs", "scripts", "playground"}

# Attributes that identify a record, in priority order.
KEY_ATTRS = ("name", "id", "type", "unit", "protounit", "proto", "tech", "resourcetype")

# Records identified by child elements rather than an attribute or <name>.
# Add an entry here when `report` flags a tag as not-keyable but it does have a
# stable identity; leave it out when the records are genuinely positional (e.g.
# <level> in traderoutes.xml, where order *is* the meaning).
KEY_CHILDREN = {
    "ambienteffect": ("protounit",),
    # from+to+command is the identity; <tech> is a value the DLC edits, so
    # including it would read every retuned transform as a drop plus an add.
    "transform": ("from", "to", "command"),
}

SINGLETON = "\0singleton"


# --------------------------------------------------------------------------- #
# classification
# --------------------------------------------------------------------------- #

def path_variants(rel):
    """A mod `foo.xml` can override a vanilla `foo.xml.XMB`, and vice versa."""
    r = rel.lower()
    return (r, r[:-4]) if r.endswith(".xmb") else (r, r + ".xmb")


def loose_vanilla(game_dir):
    """Unpacked vanilla files under Game\\ (RandMaps, AI, Campaign, ...)."""
    out = {}
    for root, _d, files in os.walk(game_dir):
        for f in files:
            if f.lower().endswith(".bar"):
                continue
            rel = os.path.relpath(os.path.join(root, f), game_dir)
            out[rel.replace("\\", "/").lower()] = os.path.join(root, f)
    return out


def classify(mod_dir, index, loose):
    """-> (overrides, new). overrides: list of (mod_rel, vanilla_key)."""
    overrides, new = [], []
    for root, dirs, files in os.walk(mod_dir):
        if root == mod_dir:
            dirs[:] = [d for d in dirs if d.lower() not in SKIP_TOP]
        for f in files:
            rel = os.path.relpath(os.path.join(root, f), mod_dir).replace("\\", "/")
            if "/" not in rel or rel.split("/")[0].lower() in SKIP_TOP:
                continue
            hit = next((v for v in path_variants(rel) if v in index or v in loose), None)
            (overrides.append((rel, hit)) if hit else new.append(rel))

    # A mod `foo.xml.xmb` sitting next to `foo.xml` is just the compiled artefact
    # of it. Analysing both would double-count every finding, so keep the source.
    mod_files = {rel for rel, _ in overrides}
    overrides = [(rel, key) for rel, key in overrides
                 if not (rel.lower().endswith(".xmb") and rel[:-4] in mod_files)]
    return sorted(overrides), sorted(new)


# --------------------------------------------------------------------------- #
# records
# --------------------------------------------------------------------------- #

def record_key(el, tag_count):
    """Identify a record. None => not safely mergeable.

    Order matters: an explicit attribute beats a <name> child, which beats the
    element's own leading text (how <tactic>Normal<action>..</action></tactic>
    names itself), and a tag that occurs exactly once is a singleton setting
    (how .lgt lightsets are written).
    """
    for a in KEY_ATTRS:
        if a in el.attrib:
            return el.attrib[a].strip().lower()
    nm = el.find("name")
    if nm is not None and nm.text and nm.text.strip():
        return nm.text.strip().lower()
    if el.tag in KEY_CHILDREN:
        parts = []
        for child_tag in KEY_CHILDREN[el.tag]:
            c = el.find(child_tag)
            parts.append((c.text or "").strip().lower() if c is not None else "")
        if any(parts):
            return "|".join(parts)
    # A tag occurring once is a setting, and its text is its VALUE, not its
    # identity -- <sunintensity>3.0</sunintensity> must not re-key itself when
    # the number changes, or every edited setting reads as a drop plus an add.
    if tag_count == 1:
        return SINGLETON
    # Repeated tags: the text identifies the record, either as a bare value in a
    # list or as the name of a mixed-content record such as
    # <tactic>Normal<action>Heal</action></tactic>.
    if el.text and el.text.strip():
        return el.text.strip().lower()
    return None


def tag_counts(root):
    counts = {}
    for c in root:
        if not callable(c.tag):
            counts[c.tag] = counts.get(c.tag, 0) + 1
    return counts


def records(root, counts=None):
    """-> ({tag: {key: element}}, unkeyable_tags).

    `counts` must be the COMBINED per-tag counts of both sides. Deciding
    singleton-vs-list from one side alone is asymmetric: a tag appearing once in
    vanilla and twice in the mod would be keyed SINGLETON on one side and by text
    on the other, so vanilla's record would look dropped when it is present.
    """
    if counts is None:
        counts = tag_counts(root)
    out, unkeyable = {}, set()
    for c in root:
        if callable(c.tag):
            continue
        k = record_key(c, counts.get(c.tag, 1))
        if k is None:
            unkeyable.add(c.tag)
            continue
        group = out.setdefault(c.tag, {})
        if k in group:
            # Two records share a key, so the key is not an identity. Silently
            # keeping one would hide a whole record from the comparison.
            unkeyable.add(c.tag)
            continue
        group[k] = c
    return out, unkeyable


def canon(el):
    """Comment-free, whitespace-insensitive shape of an element."""
    return (el.tag, tuple(sorted(el.attrib.items())), (el.text or "").strip(),
            tuple(canon(c) for c in el if not callable(c.tag)))


def load_bytes_tree(data):
    if bartool.is_xmb(data):
        return bartool.xmb_to_element(data)
    return ET.fromstring(data.decode("utf-8-sig", errors="replace"))


# --------------------------------------------------------------------------- #
# analysis
# --------------------------------------------------------------------------- #

class Analysis:
    def __init__(self, rel, key):
        self.rel, self.key = rel, key
        self.status = "ok"
        self.dropped = []        # (tag, key, element) present in vanilla, missing in mod
        self.added = 0
        self.conflicts = []      # (tag, key) in both but different
        self.unkeyable = set()   # tags that could not be identified


def read_vanilla_bytes(key, index, loose):
    if key in index:
        return bartool.unwrap_alz4(bartool.read_entry(index[key]))
    return bartool.unwrap_alz4(open(loose[key], "rb").read())


def is_xml_like(data):
    return bartool.is_xmb(data) or data.lstrip()[:1] in (b"<",)


def analyse(rel, key, mod_dir, index, loose):
    a = Analysis(rel, key)
    mod_path = os.path.join(mod_dir, rel.replace("/", os.sep))
    try:
        mod_raw = bartool.unwrap_alz4(open(mod_path, "rb").read())
        van_raw = read_vanilla_bytes(key, index, loose)
    except Exception as exc:
        a.status = f"read-error: {exc}"
        return a

    # Binaries (.gr2 models, .ddt/.png textures, .xaml) have no record structure.
    if not (is_xml_like(mod_raw) and is_xml_like(van_raw)):
        a.status = "binary-same" if mod_raw == van_raw else "binary-differs"
        return a

    try:
        mod = load_bytes_tree(mod_raw)
        van = load_bytes_tree(van_raw)
    except Exception as exc:
        a.status = f"parse-error: {exc}"
        return a
    if mod.tag != van.tag:
        a.status = f"root mismatch ({mod.tag} vs {van.tag})"
        return a

    combined = tag_counts(mod)
    for t, n in tag_counts(van).items():
        combined[t] = max(combined.get(t, 0), n)
    mrec, mu = records(mod, combined)
    vrec, vu = records(van, combined)
    a.unkeyable = mu | vu
    if a.unkeyable:
        a.status = "not-keyable:" + ",".join(sorted(a.unkeyable))

    for tag, vd in vrec.items():
        md = mrec.get(tag, {})
        for k, ve in vd.items():
            if k not in md:
                a.dropped.append((tag, k, ve))
            elif canon(ve) != canon(md[k]):
                a.conflicts.append((tag, k))
    for tag, md in mrec.items():
        a.added += sum(1 for k in md if k not in vrec.get(tag, {}))
    if a.status == "ok" and not a.dropped:
        a.status = "up-to-date"
    return a


# --------------------------------------------------------------------------- #
# merge (text splice)
# --------------------------------------------------------------------------- #

def serialise_records(elements, indent, eol):
    """Render records as text, each line prefixed to sit at the child depth.

    ET.indent must run at level 0 so the record's own open/close tags start in
    column 0; `indent` is then added to every line. Indenting at level 1 instead
    would push children and the closing tag out by an extra step.
    """
    chunks = []
    for el in elements:
        e = ET.fromstring(ET.tostring(el, encoding="unicode"))   # detached copy
        ET.indent(e, "  ")
        text = ET.tostring(e, encoding="unicode").rstrip()
        chunks.append(eol.join(indent + line for line in text.splitlines()))
    return eol.join(chunks) + eol


def splice(mod_text, root_tag, addition, eol):
    """Insert `addition` immediately before the final </root_tag>."""
    close = f"</{root_tag}>"
    at = mod_text.rfind(close)
    if at < 0:
        raise ValueError(f"no closing {close} found")
    return mod_text[:at] + addition + mod_text[at:]


def child_indent(mod_text, root_tag):
    """Infer the indent used for the root's children (usually two spaces)."""
    for line in mod_text.splitlines():
        s = line.strip()
        if s.startswith("<") and not s.startswith(f"<{root_tag}") \
                and not s.startswith("<?") and not s.startswith("<!"):
            return line[:len(line) - len(line.lstrip())] or "  "
    return "  "


def merge_file(a, mod_dir, out_dir, in_place, eol="\r\n"):
    """Write a merged copy re-adding a.dropped. Returns the output path."""
    mod_path = os.path.join(mod_dir, a.rel.replace("/", os.sep))
    raw = open(mod_path, "rb").read()
    if bartool.unwrap_alz4(raw)[:2] == b"X1" or raw[:4] == b"alz4":
        raise ValueError("mod file is compiled XMB; edit the paired .xml instead")
    text = raw.decode("utf-8-sig", errors="replace")
    native_eol = "\r\n" if "\r\n" in text else "\n"

    root_tag = ET.fromstring(text).tag
    indent = child_indent(text, root_tag)
    addition = serialise_records([e for _t, _k, e in a.dropped], indent, native_eol)

    merged = splice(text, root_tag, addition, native_eol)
    ET.fromstring(merged)                       # fail loudly rather than write junk

    dst = mod_path if in_place else os.path.join(out_dir, a.rel.replace("/", os.sep))
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    with open(dst, "wb") as f:
        f.write(merged.encode("utf-8"))
    return dst


# --------------------------------------------------------------------------- #
# commands
# --------------------------------------------------------------------------- #

def selected(args, overrides):
    if not args.pattern:
        return overrides
    pats = [p.replace("\\", "/").lower() for p in args.pattern]
    return [(rel, key) for rel, key in overrides
            if any(p in rel.lower() for p in pats)]


def cmd_classify(args, ctx):
    overrides, new = ctx["overrides"], ctx["new"]
    if args.new:
        for r in new:
            print(r)
    else:
        for rel, key in selected(args, overrides):
            print(f"{rel}  <-  {key}")
    bartool.info(f"-- {len(overrides)} override(s), {len(new)} new file(s)")
    return 0


def cmd_baseline(args, ctx):
    out = args.out
    n = 0
    for rel, key in selected(args, ctx["overrides"]):
        try:
            if key in ctx["index"]:
                data, dec = bartool.decode(bartool.read_entry(ctx["index"][key]),
                                           True, args.eol)
            else:
                data, dec = bartool.decode(open(ctx["loose"][key], "rb").read(),
                                           True, args.eol)
        except Exception as exc:
            print(f"FAIL {key}: {exc}", file=sys.stderr)
            continue
        dst = os.path.join(out, bartool.out_name(key, dec).replace("/", os.sep))
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        with open(dst, "wb") as f:
            f.write(data)
        n += 1
    stamp = os.path.join(out, "BUILD.txt")
    with open(stamp, "w") as f:
        f.write(f"game: {ctx['game']}\nbuildid: {ctx['buildid']}\nfiles: {n}\n")
    bartool.info(f"-- baseline: {n} vanilla file(s) -> {out} (build {ctx['buildid']})")
    return 0


def cmd_report(args, ctx):
    rows = [analyse(rel, key, ctx["mod"], ctx["index"], ctx["loose"])
            for rel, key in selected(args, ctx["overrides"])]
    losing = sorted([r for r in rows if r.dropped], key=lambda r: -len(r.dropped))
    other = [r for r in rows if not r.dropped]

    print(f"{'DROPPED':>8} {'ADDED':>6} {'CONFLICT':>9}  file")
    print("-" * 96)
    for r in losing:
        note = "" if r.status in ("ok", "up-to-date") else f"   [{r.status}]"
        print(f"{len(r.dropped):>8} {r.added:>6} {len(r.conflicts):>9}  {r.rel}{note}")
        if args.verbose:
            for tag, k, _e in r.dropped[:args.verbose]:
                print(f"{'':>26}+ {tag} {k}")
            if len(r.dropped) > args.verbose:
                print(f"{'':>26}... {len(r.dropped) - args.verbose} more")
    print("-" * 96)
    bins = [r for r in rows if r.status.startswith("binary")]
    unkey = [r for r in rows if r.status.startswith("not-keyable")]
    errs = [r for r in rows if "error" in r.status]
    conf = [r for r in rows if r.conflicts]
    clean = [r for r in other if r.status == "up-to-date"]

    print(f"losing content : {len(losing)} file(s), "
          f"{sum(len(r.dropped) for r in losing)} record(s)  -> `merge` fixes these")
    print(f"up to date     : {len(clean)} XML file(s)")
    print(f"needs review   : {len(conf)} file(s), {sum(len(r.conflicts) for r in conf)} "
          f"record(s) differ on both sides (mod wins; merge never rewrites them)")
    print(f"binary         : {len([r for r in bins if r.status == 'binary-differs'])} differ, "
          f"{len([r for r in bins if r.status == 'binary-same'])} identical to vanilla "
          f"(models/textures -- compare by hand)")
    if unkey:
        tags = sorted({t for r in unkey for t in r.unkeyable})
        print(f"not keyable    : {len(unkey)} file(s); tags {tags}")
        print( "                 positional records -- merge skips them. If a tag does")
        print( "                 have a stable identity, add it to KEY_CHILDREN.")
        for r in unkey:
            print(f"                 {r.rel}  (+{len(r.dropped)} dropped)")
    if errs:
        print(f"errors         : {len(errs)} file(s)")
        for r in errs:
            print(f"                 {r.rel}  [{r.status}]")
    return 0


def cmd_merge(args, ctx):
    rows = [analyse(rel, key, ctx["mod"], ctx["index"], ctx["loose"])
            for rel, key in selected(args, ctx["overrides"])]
    # Only files whose every root-level record could be identified. A file with
    # an unkeyable tag is usually a nested, order-sensitive format (art unit
    # XML, traderoute levels) where appending records is not a valid edit.
    todo = [r for r in rows if r.dropped and r.status == "ok"]
    skipped = [r for r in rows if r.dropped and r.status.startswith("not-keyable")]
    if args.include_partial:
        todo += skipped
        skipped = []
    if not todo:
        bartool.info("-- nothing to merge")
        for r in skipped:
            bartool.info(f"-- skipped {r.rel} [{r.status}]")
        return 0

    written, failed, stale = 0, 0, []
    for r in todo:
        if args.dry_run:
            print(f"would add {len(r.dropped):>4} record(s) to {r.rel}")
            continue
        try:
            dst = merge_file(r, ctx["mod"], args.out, args.in_place)
        except Exception as exc:
            print(f"FAIL {r.rel}: {exc}", file=sys.stderr)
            failed += 1
            continue
        written += 1
        print(f"+{len(r.dropped):>4} records  {dst}")
        if os.path.exists(os.path.join(ctx["mod"], r.rel.replace("/", os.sep)) + ".xmb"):
            stale.append(r.rel + ".xmb")

    if args.dry_run:
        bartool.info(f"-- {len(todo)} file(s) would change, "
                     f"{sum(len(r.dropped) for r in todo)} record(s) re-added")
        return 0
    bartool.info(f"-- merged {written} file(s)" + (f", {failed} failed" if failed else "")
                 + ("" if args.in_place else f" -> {args.out} (review, then copy in)"))
    for r in skipped:
        bartool.info(f"-- skipped {r.rel} (+{len(r.dropped)} dropped) [{r.status}]")
    if stale:
        bartool.info(f"-- {len(stale)} paired .xml.xmb now stale, recompile in "
                     f"Resource Manager:")
        for s in stale:
            bartool.info(f"     {s}")
    return 1 if failed else 0


def read_buildid(game_dir):
    acf = os.path.abspath(os.path.join(game_dir, "..", "..", "..",
                                       "appmanifest_933110.acf"))
    try:
        for line in open(acf, encoding="utf-8", errors="replace"):
            if '"buildid"' in line:
                return line.split('"')[3]
    except OSError:
        pass
    return "unknown"


def main(argv=None):
    ap = argparse.ArgumentParser(
        prog="mergetool",
        description="Reconcile mod overrides against a patched game build.")
    ap.add_argument("--game", help="path to ...\\AoE3DE\\Game (auto-detected)")
    ap.add_argument("--mod", default=REPO, help="mod repo root (default: this repo)")
    ap.add_argument("--eol", choices=("crlf", "lf"), default="crlf")
    sub = ap.add_subparsers(dest="cmd", required=True)

    def pattern(p):
        p.add_argument("pattern", nargs="*",
                       help="substring filter on the mod-relative path")

    p = sub.add_parser("classify", help="list overrides (or --new for mod-only files)")
    pattern(p)
    p.add_argument("--new", action="store_true", help="list new files instead")
    p.set_defaults(func=cmd_classify)

    p = sub.add_parser("baseline", help="snapshot vanilla counterparts of the overrides")
    pattern(p)
    p.add_argument("-o", "--out", default="vanilla-baseline")
    p.set_defaults(func=cmd_baseline)

    p = sub.add_parser("report", help="what each override drops / adds / conflicts on")
    pattern(p)
    p.add_argument("-v", "--verbose", nargs="?", type=int, const=10, default=0,
                   metavar="N", help="also list up to N dropped records per file")
    p.set_defaults(func=cmd_report)

    p = sub.add_parser("merge", help="re-add dropped vanilla records to the mod files")
    pattern(p)
    p.add_argument("-o", "--out", default="merged",
                   help="output dir (default: merged; nothing is edited in place)")
    p.add_argument("--in-place", action="store_true",
                   help="rewrite the mod files directly (commit first)")
    p.add_argument("--include-partial", action="store_true",
                   help="also merge files that contain unkeyable records (unsafe "
                        "for nested formats such as art unit XML)")
    p.add_argument("-n", "--dry-run", action="store_true")
    p.set_defaults(func=cmd_merge)

    args = ap.parse_args(argv)
    game = bartool.find_game_dir(args.game)
    index = bartool.build_index(game)
    loose = loose_vanilla(game)
    overrides, new = classify(args.mod, index, loose)
    ctx = dict(game=game, mod=args.mod, index=index, loose=loose,
               overrides=overrides, new=new, buildid=read_buildid(game))
    return args.func(args, ctx)


if __name__ == "__main__":
    sys.exit(main())
