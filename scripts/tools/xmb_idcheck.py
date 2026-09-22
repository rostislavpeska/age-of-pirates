"""Compiled-twin identifier check: does the .xml.xmb the game loads carry clean identifier text?

    python scripts/tools/xmb_idcheck.py                 # every data/**/*.xml that has a .xmb twin
    python scripts/tools/xmb_idcheck.py data/traderoutedefs.xml data/traderoutes.xml
    python scripts/tools/xmb_idcheck.py --xml-only      # check the XML sources, skip decoding twins

Why: Resource Manager's XMB compiler keeps element TEXT verbatim. A record written multi-line whose
identifier is element text (traderoutedefs `<route ...>arctic1`, traderoutes `<from>`/`<to>`) compiles
to 'arctic1\\r\\n    ' and the engine's lookup silently fails - the Cold War trade route fell back to
the base route for hours (2026-09-10). This tool decodes the loose twin with bartool and reports:

  STALE   twin older than its XML (the game would load yesterday's data)
  WSTEXT  an element whose text is an identifier (has children, or is a known identifier tag) and
          carries leading/trailing whitespace or a newline in the COMPILED twin
  XMLWS   the same condition in the XML source (will compile wrong on the next regen)

Exit 1 if anything is reported. Identifier tags checked when the element has no children:
  from, to, unit, name, proto, animfile, tactics, file, texture, unittype, flag, target, techstatus
"""
from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path
import xml.etree.ElementTree as ET

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "skills" / "aoe3de-bar-archives" / "scripts"))
sys.dont_write_bytecode = True

ID_TAGS = {"from", "to", "unit", "name", "proto", "animfile", "tactics", "file", "texture",
           "unittype", "flag", "target", "techstatus", "train", "levelname"}


def bad_text(e):
    t = e.text
    if t is None:
        return False
    if not t.strip():
        return False                      # pure whitespace = formatting, not an identifier
    if len(e) == 0 and e.tag.lower() not in ID_TAGS:
        return False                      # free text (descriptions) is allowed to be multi-line
    return t != t.strip()


def scan_tree(root, label):
    out = []
    for e in root.iter():
        if bad_text(e):
            out.append((label, e.tag, repr(e.text[:40])))
    return out


def check(xml_path: Path, xml_only: bool):
    findings = []
    try:
        xroot = ET.parse(xml_path).getroot()
    except ET.ParseError as ex:
        return [("PARSE", xml_path.name, str(ex))]
    findings += [("XMLWS",) + f[1:] for f in scan_tree(xroot, "XMLWS")]
    xmb = xml_path.with_name(xml_path.name + ".xmb")
    if xml_only or not xmb.is_file():
        return findings
    if xmb.stat().st_mtime < xml_path.stat().st_mtime:
        findings.append(("STALE", xmb.name, "twin older than its XML - regenerate"))
    try:
        import bartool
        data = bartool.unwrap_alz4(xmb.read_bytes())
        root = bartool.xmb_to_element(data)
    except Exception as ex:  # noqa: BLE001
        return findings + [("DECODE", xmb.name, str(ex)[:80])]
    findings += [("WSTEXT",) + f[1:] for f in scan_tree(root, "WSTEXT")]
    return findings


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("files", nargs="*")
    ap.add_argument("--xml-only", action="store_true")
    a = ap.parse_args(argv)
    if a.files:
        paths = [Path(f) for f in a.files]
    else:
        paths = []
        for dp, _dn, fns in os.walk(REPO / "data"):
            for fn in fns:
                if fn.lower().endswith(".xml") and (Path(dp) / (fn + ".xmb")).is_file():
                    paths.append(Path(dp) / fn)
    total = 0
    for p in sorted(paths):
        f = check(p, a.xml_only)
        if f:
            total += len(f)
            print(f"{p.relative_to(REPO) if p.is_relative_to(REPO) else p}:")
            for kind, tag, txt in f[:20]:
                print(f"  {kind:7s} <{tag}> {txt}")
            if len(f) > 20:
                print(f"  ... {len(f) - 20} more")
    print(f"{len(paths)} file(s) checked, {total} finding(s)")
    return 1 if total else 0


if __name__ == "__main__":
    raise SystemExit(main())
