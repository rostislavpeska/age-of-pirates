#!/usr/bin/env python3
"""
bartool - extract anything from Age of Empires III: DE .bar archives.

Self-contained: standard library only. Installing the `lz4` package is optional
and only makes decompression ~10x faster.

Formats handled
---------------
.bar   ESPN v6 container. Header holds numFiles (u64 @0x118) and the file-table
       offset (u64 @0x120). The table is a root prefix ("Data\\", "Art\\", ...)
       followed by one record per file:
           u64 offset, u32 sizeRaw, u32 sizeStored, u32 sizeStored2,
           u32 nameLen, wchar name[nameLen], u32 compressedFlag
alz4   16-byte header ("alz4", u32 rawSize, u32 compSize, u32 blocks) wrapping a
       raw LZ4 block. Used for compressed .bar payloads AND for loose .xmb files.
XMB    Compiled XML ("X1"/"XR" v4): element-name table, attribute-name table,
       then a tree of "XN" nodes. Many entries are XMB even when the archive
       calls them .xml / .tactics / .material / .lgt -- so plain extraction of a
       ".xml" often yields binary. Use --xml to decompile.
"""

import argparse
import fnmatch
import os
import struct
import sys
import xml.etree.ElementTree as ET

sys.setrecursionlimit(20000)

DEFAULT_GAME_DIRS = [
    r"C:\Program Files (x86)\Steam\steamapps\common\AoE3DE\Game",
    r"C:\Program Files\Steam\steamapps\common\AoE3DE\Game",
    r"D:\Steam\steamapps\common\AoE3DE\Game",
    r"D:\SteamLibrary\steamapps\common\AoE3DE\Game",
    r"E:\SteamLibrary\steamapps\common\AoE3DE\Game",
]


# --------------------------------------------------------------------------- #
# alz4 / LZ4
# --------------------------------------------------------------------------- #

try:
    import lz4.block as _lz4

    def _lz4_decode(src, expected):
        return _lz4.decompress(src, uncompressed_size=expected)
except ImportError:
    def _lz4_decode(src, expected):
        """Pure-python LZ4 block decoder."""
        out = bytearray()
        i, n = 0, len(src)
        while i < n:
            token = src[i]
            i += 1
            lit = token >> 4
            if lit == 15:
                while True:
                    b = src[i]
                    i += 1
                    lit += b
                    if b != 255:
                        break
            out += src[i:i + lit]
            i += lit
            if i >= n:
                break
            offset = src[i] | (src[i + 1] << 8)
            i += 2
            mlen = token & 0x0F
            if mlen == 15:
                while True:
                    b = src[i]
                    i += 1
                    mlen += b
                    if b != 255:
                        break
            mlen += 4
            start = len(out) - offset
            if offset >= mlen:                      # non-overlapping: bulk copy
                out += out[start:start + mlen]
            else:                                   # overlapping run
                for j in range(mlen):
                    out.append(out[start + j])
        if len(out) != expected:
            raise ValueError(f"lz4: got {len(out)} bytes, expected {expected}")
        return bytes(out)


def unwrap_alz4(data):
    """Decompress an alz4 blob; return unchanged if it is not alz4."""
    if data[:4] != b"alz4":
        return data
    raw, comp, _blocks = struct.unpack_from("<III", data, 4)
    return _lz4_decode(data[16:16 + comp], raw)


# --------------------------------------------------------------------------- #
# .bar
# --------------------------------------------------------------------------- #

class Entry:
    __slots__ = ("path", "name", "offset", "size_raw", "size_stored", "bar")

    def __init__(self, path, name, offset, size_raw, size_stored, bar):
        self.path = path                # 'data/tactics/dock.tactics' (lowercase, /)
        self.name = name                # name as stored, original case
        self.offset = offset
        self.size_raw = size_raw
        self.size_stored = size_stored
        self.bar = bar

    @property
    def compressed(self):
        return self.size_raw != self.size_stored


def read_bar_table(bar_path):
    """Parse one .bar's file table. Only reads the header + trailing table."""
    with open(bar_path, "rb") as f:
        head = f.read(0x130)
        if head[:4] != b"ESPN":
            raise ValueError(f"{bar_path}: not an ESPN archive")
        (version,) = struct.unpack_from("<I", head, 4)
        if version != 6:
            print(f"warning: {os.path.basename(bar_path)} is version {version}, "
                  f"expected 6 -- parsing anyway", file=sys.stderr)
        _num_hdr, table_off = struct.unpack_from("<QQ", head, 0x118)
        f.seek(table_off)
        tbl = f.read()

    p = 0
    (root_len,) = struct.unpack_from("<I", tbl, p)
    p += 4
    root = tbl[p:p + root_len * 2].decode("utf-16-le")
    p += root_len * 2
    (count,) = struct.unpack_from("<I", tbl, p)
    p += 4

    entries = []
    for _ in range(count):
        off, raw, stored, _stored2, nlen = struct.unpack_from("<QIIII", tbl, p)
        p += 24
        name = tbl[p:p + nlen * 2].decode("utf-16-le")
        p += nlen * 2
        p += 4                                          # compressed flag
        full = (root + name).replace("\\", "/")
        entries.append(Entry(full.lower(), full, off, raw, stored, bar_path))
    return root, entries


def find_game_dir(explicit=None):
    for cand in ([explicit] if explicit else []) + \
                [os.environ.get("AOE3DE_GAME")] + DEFAULT_GAME_DIRS:
        if cand and os.path.isdir(cand):
            if os.path.isdir(os.path.join(cand, "Data")):
                return cand
    raise SystemExit(
        "Could not locate the AoE3DE Game directory. Pass --game <path> or set "
        "AOE3DE_GAME. Expected something like:\n  "
        + DEFAULT_GAME_DIRS[0]
    )


def build_index(game_dir, verbose=False):
    """path -> Entry across every .bar. Cheap: tail reads only (~0.3s for 43 bars)."""
    index = {}
    bars = []
    for root, _dirs, files in os.walk(game_dir):
        for f in files:
            if f.lower().endswith(".bar"):
                bars.append(os.path.join(root, f))
    for bar_path in sorted(bars):
        try:
            _root, entries = read_bar_table(bar_path)
        except Exception as exc:                        # keep going on one bad archive
            print(f"warning: skipping {os.path.basename(bar_path)}: {exc}", file=sys.stderr)
            continue
        if verbose:
            print(f"  {os.path.basename(bar_path):<28} {len(entries):>7} files", file=sys.stderr)
        for e in entries:
            index[e.path] = e
    return index


def read_entry(entry):
    with open(entry.bar, "rb") as f:
        f.seek(entry.offset)
        data = f.read(entry.size_stored)
    if entry.compressed:
        data = unwrap_alz4(data)
        if len(data) != entry.size_raw:
            raise ValueError(f"{entry.path}: size mismatch after decompression")
    return data


# --------------------------------------------------------------------------- #
# XMB -> XML
# --------------------------------------------------------------------------- #

class _R:
    def __init__(self, b):
        self.b, self.p = b, 0

    def u32(self):
        (v,) = struct.unpack_from("<I", self.b, self.p)
        self.p += 4
        return v

    def tag(self):
        v = self.b[self.p:self.p + 2]
        self.p += 2
        return v

    def wstr(self):
        n = self.u32()
        s = self.b[self.p:self.p + n * 2].decode("utf-16-le", errors="replace")
        self.p += n * 2
        return s


def is_xmb(data):
    return data[:2] == b"X1"


def xmb_to_element(data):
    """Parse XMB into an ElementTree Element. Raises on malformed input."""
    r = _R(data)
    if r.tag() != b"X1":
        raise ValueError("not XMB")
    r.u32()                                             # payload length
    if r.tag() != b"XR":
        raise ValueError("bad XMB header (no XR)")
    r.u32()                                             # version (4)
    r.u32()                                             # unknown (8)
    elems = [r.wstr() for _ in range(r.u32())]
    attrs = [r.wstr() for _ in range(r.u32())]

    def node():
        if r.tag() != b"XN":
            raise ValueError(f"bad node marker at offset {r.p - 2}")
        r.u32()                                         # node byte length
        text = r.wstr()
        el = elems[r.u32()]
        r.u32()                                         # source line number
        a = {}
        for _ in range(r.u32()):
            # Keep these as separate statements: in `a[attrs[r.u32()]] = r.wstr()`
            # Python evaluates the value before the subscript, reversing the
            # order of the two reads and desynchronising the stream.
            ai = r.u32()
            a[attrs[ai]] = r.wstr()
        e = ET.Element(el, a)
        if text.strip():
            e.text = text
        for _ in range(r.u32()):
            e.append(node())
        return e

    root = node()
    if r.p != len(data):
        raise ValueError(f"trailing data: consumed {r.p} of {len(data)} bytes")
    return root


def xmb_to_xml(data):
    """XMB bytes -> indented XML text, matching Resource Manager's 2-space style."""
    root = xmb_to_element(data)
    ET.indent(root, "  ")
    return ET.tostring(root, encoding="unicode") + "\n"


def decode(data, want_xml, eol="crlf"):
    """Return (bytes, was_decompiled). Applies alz4, then optionally XMB->XML.

    Decompiled XML defaults to CRLF: the game's own XML, Resource Manager's
    output and this repo are all CRLF, so LF output would make every refreshed
    snapshot look 100% changed in a diff.
    """
    data = unwrap_alz4(data)
    if want_xml and is_xmb(data):
        text = xmb_to_xml(data)
        if eol == "crlf":
            text = text.replace("\n", "\r\n")
        return text.encode("utf-8"), True
    return data, False


def out_name(path, decompiled):
    """Drop a redundant .xmb suffix once the content is real XML."""
    if decompiled and path.lower().endswith(".xmb"):
        return path[:-4]
    return path


# --------------------------------------------------------------------------- #
# commands
# --------------------------------------------------------------------------- #

def match(index, patterns):
    """Match patterns against full paths, case-insensitively.

    A pattern with no glob metacharacter is treated as a substring search, so
    `soundset` finds Sound/soundsetsde.xml.XMB without needing wildcards.

    Globs also match with an implicit trailing `.xmb`, because most logical
    ".xml"/".tactics"/".material" files are physically stored as "*.XMB".
    Without this, `*.tactics` would silently match nothing.
    """
    if not patterns:
        return sorted(index.values(), key=lambda e: e.path)
    hits = {}
    for pat in patterns:
        p = pat.replace("\\", "/").lower()
        if any(c in p for c in "*?["):
            alt = p + ".xmb"
            for path, e in index.items():
                if fnmatch.fnmatch(path, p) or fnmatch.fnmatch(path, alt):
                    hits[path] = e
        else:
            for path, e in index.items():
                if p in path:
                    hits[path] = e
    return sorted(hits.values(), key=lambda e: e.path)


def info(msg):
    """Progress/summary line on stderr, ordered after any stdout already written."""
    sys.stdout.flush()
    print(msg, file=sys.stderr)
    sys.stderr.flush()


def cmd_list(args, index):
    hits = match(index, args.pattern)
    for e in hits:
        if args.long:
            kind = "lz4" if e.compressed else "raw"
            print(f"{e.size_raw:>10}  {kind}  {os.path.basename(e.bar):<26} {e.name}")
        else:
            print(e.name)
    info(f"-- {len(hits)} file(s)")
    return 0


def cmd_cat(args, index):
    hits = match(index, args.pattern)
    if not hits:
        print("no match", file=sys.stderr)
        return 1
    if len(hits) > 1 and not args.all:
        print(f"{len(hits)} files match; narrow the pattern or pass --all:", file=sys.stderr)
        for e in hits[:20]:
            print(f"  {e.name}", file=sys.stderr)
        return 1
    for e in hits:
        data, _ = decode(read_entry(e), not args.raw, args.eol)
        if len(hits) > 1:
            print(f"===== {e.name} =====")
        sys.stdout.buffer.write(data)
    return 0


def cmd_extract(args, index):
    hits = match(index, args.pattern)
    if not hits:
        print("no match -- nothing extracted", file=sys.stderr)
        return 1
    if args.dry_run:
        for e in hits:
            print(f"would extract {e.name}")
        info(f"-- {len(hits)} file(s)")
        return 0

    written = failed = 0
    total = 0
    for e in hits:
        try:
            data, decompiled = decode(read_entry(e), not args.raw, args.eol)
        except Exception as exc:
            print(f"FAIL {e.name}: {exc}", file=sys.stderr)
            failed += 1
            continue
        rel = out_name(e.name, decompiled)
        if args.flat:
            rel = os.path.basename(rel)
        dst = os.path.join(args.out, rel.replace("/", os.sep))
        os.makedirs(os.path.dirname(dst) or ".", exist_ok=True)
        with open(dst, "wb") as f:
            f.write(data)
        written += 1
        total += len(data)
        if args.verbose:
            print(f"  {rel}")
    info(f"-- extracted {written} file(s), {total / 1e6:.1f} MB -> {args.out}"
         + (f"  ({failed} failed)" if failed else ""))
    return 1 if failed else 0


def cmd_bars(args, index):
    game = args.game_dir
    rows = []
    for root, _dirs, files in os.walk(game):
        for f in sorted(files):
            if f.lower().endswith(".bar"):
                p = os.path.join(root, f)
                try:
                    bar_root, entries = read_bar_table(p)
                except Exception as exc:
                    rows.append((f, "ERROR", str(exc)[:40], 0))
                    continue
                rows.append((f, bar_root, "", len(entries)))
    for name, bar_root, err, n in rows:
        print(f"{name:<30} root={bar_root!r:<16} files={n:>7} {err}")
    info(f"-- {len(rows)} archive(s), {sum(r[3] for r in rows)} files")
    return 0


def cmd_verify(args, index):
    """Decode every match and report failures. Use to sanity-check a game patch."""
    hits = match(index, args.pattern)
    ok = xmb_ok = fail = 0
    for e in hits:
        try:
            data = unwrap_alz4(read_entry(e))
            if is_xmb(data):
                xmb_to_element(data)
                xmb_ok += 1
            ok += 1
        except Exception as exc:
            fail += 1
            print(f"FAIL {e.name}: {exc}", file=sys.stderr)
    info(f"-- decoded {ok}/{len(hits)} ({xmb_ok} XMB parsed), {fail} failed")
    return 1 if fail else 0


def main(argv=None):
    ap = argparse.ArgumentParser(
        prog="bartool",
        description="Extract anything from AoE3:DE .bar archives.")
    ap.add_argument("--game", help="path to ...\\AoE3DE\\Game (auto-detected by default)")
    ap.add_argument("--eol", choices=("crlf", "lf"), default="crlf",
                    help="line endings for decompiled XML (default: crlf, matching "
                         "the game's own files, Resource Manager and this repo)")
    sub = ap.add_subparsers(dest="cmd", required=True)

    def add_pattern(p, required=False):
        p.add_argument("pattern", nargs="*" if not required else "+",
                       help="substring, or glob if it contains * ? [ ] "
                            "(matched against the full path, case-insensitive)")

    p = sub.add_parser("bars", help="list the archives and their file counts")
    p.set_defaults(func=cmd_bars)

    p = sub.add_parser("list", help="find files across all archives")
    add_pattern(p)
    p.add_argument("-l", "--long", action="store_true", help="show size, codec, archive")
    p.set_defaults(func=cmd_list)

    p = sub.add_parser("cat", help="print one file to stdout")
    add_pattern(p, required=True)
    p.add_argument("--raw", action="store_true", help="do not decompile XMB")
    p.add_argument("--all", action="store_true", help="allow multiple matches")
    p.set_defaults(func=cmd_cat)

    p = sub.add_parser("extract", help="extract matching files to a directory")
    add_pattern(p)
    p.add_argument("-o", "--out", default="bar_export", help="output dir (default: bar_export)")
    p.add_argument("--raw", action="store_true",
                   help="write XMB as-is instead of decompiling to XML")
    p.add_argument("--flat", action="store_true", help="drop directory structure")
    p.add_argument("-n", "--dry-run", action="store_true", help="list what would be written")
    p.add_argument("-v", "--verbose", action="store_true")
    p.set_defaults(func=cmd_extract)

    p = sub.add_parser("verify", help="decode matches and report any that fail")
    add_pattern(p)
    p.set_defaults(func=cmd_verify)

    args = ap.parse_args(argv)
    args.game_dir = find_game_dir(args.game)
    index = build_index(args.game_dir)
    return args.func(args, index)


if __name__ == "__main__":
    sys.exit(main())
