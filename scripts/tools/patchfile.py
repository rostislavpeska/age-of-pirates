"""Anchored, CRLF-preserving, count-asserting text edits for the mod's data and map files.

Every hand-written patch script this project produced had the same shape: read bytes, normalise
CRLF, assert an anchor occurs exactly once, replace or insert, write CRLF back. This is that shape
as a library and a CLI, so a patch is one call and refuses to run when the anchor is ambiguous.

Library:
    from scripts.tools.patchfile import Patch
    p = Patch("data/techtreemods.xml")          # detects CRLF/LF and encoding (utf-8, latin-1 fallback)
    p.replace("old text", "new text")           # exactly one occurrence, else PatchError
    p.insert_after("anchor line\\n", "added\\n") # anchor must be unique
    p.insert_before("<!--TEST TECHS-->\\n", block)
    p.replace_re(r"^\\s*int x\\s*=.*?\\n", "", count=1)   # regex, exact match count required
    p.assert_absent("zparctic")                 # guards
    p.write()                                   # writes only if something changed; returns True

CLI (one edit per call, anchors read from files so no shell escaping is involved):
    python scripts/tools/patchfile.py FILE replace --old OLD.txt --new NEW.txt
    python scripts/tools/patchfile.py FILE insert-after --anchor A.txt --text T.txt
    python scripts/tools/patchfile.py FILE insert-before --anchor A.txt --text T.txt
    python scripts/tools/patchfile.py FILE check --absent NAME [--present NAME]

Text arguments are file paths whose contents are the literal text (LF or CRLF, both accepted).
Nothing is written when any assertion fails. Exit 0 = written or nothing to do, 2 = assertion failed.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


class PatchError(RuntimeError):
    pass


class Patch:
    def __init__(self, path):
        self.path = Path(path)
        raw = self.path.read_bytes()
        self.crlf = b"\r\n" in raw
        try:
            text = raw.decode("utf-8")
            self.encoding = "utf-8"
        except UnicodeDecodeError:
            text = raw.decode("latin-1")
            self.encoding = "latin-1"
        self.bom = text.startswith("﻿")
        if self.bom:
            text = text[1:]
        self.original = text.replace("\r\n", "\n")
        self.text = self.original
        self.log = []

    # ---- helpers -------------------------------------------------------------------------
    @staticmethod
    def _norm(s: str) -> str:
        return s.replace("\r\n", "\n")

    def count(self, needle: str) -> int:
        return self.text.count(self._norm(needle))

    def _one(self, needle: str, what: str) -> str:
        n = self._norm(needle)
        c = self.text.count(n)
        if c != 1:
            raise PatchError(f"{what}: anchor occurs {c} times, need exactly 1: {n[:80]!r}")
        return n

    # ---- edits ---------------------------------------------------------------------------
    def replace(self, old: str, new: str, count: int = 1):
        o, n = self._norm(old), self._norm(new)
        c = self.text.count(o)
        if c != count:
            raise PatchError(f"replace: {c} occurrences, need exactly {count}: {o[:80]!r}")
        self.text = self.text.replace(o, n)
        self.log.append(f"replace x{count}: {o[:60]!r}")
        return self

    def replace_re(self, pattern: str, repl: str, count: int = 1, flags=re.M):
        rx = re.compile(pattern, flags)
        found = rx.findall(self.text)
        if len(found) != count:
            raise PatchError(f"replace_re: {len(found)} matches, need exactly {count}: {pattern!r}")
        self.text = rx.sub(lambda m: repl, self.text)
        self.log.append(f"replace_re x{count}: {pattern[:60]!r}")
        return self

    def insert_after(self, anchor: str, text: str):
        a = self._one(anchor, "insert_after")
        self.text = self.text.replace(a, a + self._norm(text), 1)
        self.log.append(f"insert_after: {a[:60]!r}")
        return self

    def insert_before(self, anchor: str, text: str):
        a = self._one(anchor, "insert_before")
        self.text = self.text.replace(a, self._norm(text) + a, 1)
        self.log.append(f"insert_before: {a[:60]!r}")
        return self

    # ---- guards --------------------------------------------------------------------------
    def assert_absent(self, needle: str):
        if self._norm(needle) in self.text:
            raise PatchError(f"assert_absent failed: {needle!r} is present")
        return self

    def assert_present(self, needle: str, count: int | None = None):
        c = self.text.count(self._norm(needle))
        if c == 0 or (count is not None and c != count):
            raise PatchError(f"assert_present failed: {needle!r} occurs {c} times")
        return self

    # ---- output --------------------------------------------------------------------------
    def changed(self) -> bool:
        return self.text != self.original

    def write(self) -> bool:
        if not self.changed():
            return False
        out = self.text.replace("\n", "\r\n") if self.crlf else self.text
        if self.bom:
            out = "﻿" + out
        self.path.write_bytes(out.encode(self.encoding))
        return True


def _read_text_arg(p: str) -> str:
    return Path(p).read_bytes().decode("utf-8")


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("file")
    sub = ap.add_subparsers(dest="cmd", required=True)
    r = sub.add_parser("replace"); r.add_argument("--old", required=True); r.add_argument("--new", required=True)
    r.add_argument("--count", type=int, default=1)
    ia = sub.add_parser("insert-after"); ia.add_argument("--anchor", required=True); ia.add_argument("--text", required=True)
    ib = sub.add_parser("insert-before"); ib.add_argument("--anchor", required=True); ib.add_argument("--text", required=True)
    ck = sub.add_parser("check"); ck.add_argument("--absent", action="append", default=[]); ck.add_argument("--present", action="append", default=[])
    a = ap.parse_args(argv)
    try:
        p = Patch(a.file)
        if a.cmd == "replace":
            p.replace(_read_text_arg(a.old), _read_text_arg(a.new), a.count)
        elif a.cmd == "insert-after":
            p.insert_after(_read_text_arg(a.anchor), _read_text_arg(a.text))
        elif a.cmd == "insert-before":
            p.insert_before(_read_text_arg(a.anchor), _read_text_arg(a.text))
        elif a.cmd == "check":
            for n in a.absent:
                p.assert_absent(n)
            for n in a.present:
                p.assert_present(n)
            print("check ok")
            return 0
        wrote = p.write()
        print(("written" if wrote else "no change") + f" ({'CRLF' if p.crlf else 'LF'}, {p.encoding}): " + "; ".join(p.log))
        return 0
    except PatchError as e:
        print("PATCH REFUSED:", e, file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
