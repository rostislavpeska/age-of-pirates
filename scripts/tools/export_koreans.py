#!/usr/bin/env python
"""Export the Koreans add-on mod from AoP's koreans/ source tree into a game-ready mod folder.

The source of truth is AoP (branch Pirate-rework): koreans/ holds only Korean records and assets, laid out
like a mod root. This script turns it into the folder the game loads next to Age of Pirates, which is also the
public git repo rostislavpeska/age-of-pirates-koreans. Never edit the export by hand: change koreans/ and
re-export.

What the export adds to a plain copy of koreans/:
  data/<file>.xml           + its .xml.xmb twin (compiled, decoded back and compared before writing)
  data/strings/english      stringmods.xml + .xmb; every other language folder AoP ships gets the same
                            compiled table (stringsync's rule for a table without REWRITES)
  art/buildings/...         the Korean Town Center / Barracks / Stable animfiles (korean_visuals.build:
                            AoP's override of that file when it has one, else vanilla, plus the Korean branch)
  sound/soundsetsde.mods.xml  AoP's file + the Korean soundsets: the engine's merge of this file across two
                            mods is unverified, so the add-on carries both and is safe either way
  EXPORT.json               source commit and the SHA-256 of every exported file
  .gitattributes            "* -text": the repo stores the exported bytes exactly (CRLF runtime XML)

Additive data files (civmods, techtreemods, stringmods, homecity...) are merged by the engine with AoP's and
vanilla's, so the add-on ships only its own records (support.ageofempires.com "Additive Data Mods").

    python scripts/tools/export_koreans.py                 # write ../age-of-pirates-koreans
    python scripts/tools/export_koreans.py --out PATH
    python scripts/tools/export_koreans.py --check         # exit 1 if the export folder is stale
"""
import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
SRC = os.path.join(ROOT, 'koreans')
DEFAULT_OUT = os.path.join(os.path.dirname(ROOT), 'age-of-pirates-koreans')
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(ROOT, '.claude', 'skills', 'aoe3de-bar-archives', 'scripts'))
import korean_visuals  # noqa: E402
import xmbc  # noqa: E402
import bartool  # noqa: E402

KEEP = {'.git'}                      # never touched in the export folder
RUNTIME_XML = ('.xml', '.material', '.lgt', '.tactics', '.personality')


def crlf(data):
    return data.replace(b'\r\n', b'\n').replace(b'\n', b'\r\n')


def compile_xmb(name, data):
    """alz4-wrapped XMB of an XML file; refuses one that does not decode back identically."""
    with tempfile.TemporaryDirectory() as tmp:
        p = os.path.join(tmp, name)
        open(p, 'wb').write(data)
        xmb, root = xmbc.compile_xml(p)
        if xmbc.canon(bartool.xmb_to_element(xmb)) != xmbc.canon(root):
            sys.exit('%s: XMB does not decode back to the source - refusing to export' % name)
        return xmbc.wrap_alz4(xmb)


def languages():
    d = os.path.join(ROOT, 'data', 'strings')
    return sorted(x for x in os.listdir(d) if os.path.isdir(os.path.join(d, x)) and not x.startswith('_'))


def merged_soundsets(korean):
    aop = open(os.path.join(ROOT, 'sound', 'soundsetsde.mods.xml'), 'rb').read().decode('utf-8-sig')
    aop = aop.replace('\r\n', '\n')
    k = korean.decode('utf-8-sig').replace('\r\n', '\n')
    body = k[k.index('<soundsetdefmods>') + len('<soundsetdefmods>\n'):k.rindex('</soundsetdefmods>')]
    names = re.findall(r'<soundset name="([^"]+)"', body)
    clash = [n for n in names if '<soundset name="%s"' % n in aop]
    if clash:
        sys.exit('Korean soundsets already defined in AoP sound/soundsetsde.mods.xml: %s' % clash)
    end = aop.rindex('</soundsetdefmods>')
    return crlf((aop[:end] + body + aop[end:]).encode('utf-8'))


def build():
    """{relative path: bytes} of the complete export."""
    out = {}
    for d, _, files in os.walk(SRC):
        for f in files:
            full = os.path.join(d, f)
            rel = os.path.relpath(full, SRC).replace(os.sep, '/')
            data = open(full, 'rb').read()
            if rel.endswith(RUNTIME_XML):
                data = crlf(data)
            if rel == 'sound/soundsetsde.mods.xml':
                out[rel] = merged_soundsets(data)
            elif rel == 'data/strings/english/stringmods.xml':
                out[rel] = data
                xmb = compile_xmb('stringmods.xml', data)
                for lang in languages():
                    out['data/strings/%s/stringmods.xml.xmb' % lang] = xmb
            elif re.match(r'data/[^/]+\.xml$', rel):
                out[rel] = data
                out[rel + '.xmb'] = compile_xmb(os.path.basename(rel), data)
            else:
                out[rel] = data
    for rel, (data, _, _) in korean_visuals.build(ROOT).items():
        assert rel not in out, rel
        out[rel] = data
    out['.gitattributes'] = b'# Generated by AoP scripts/tools/export_koreans.py - store the exported bytes exactly.\r\n* -text\r\n'
    commit = subprocess.run(['git', '-C', ROOT, 'rev-parse', 'HEAD'], capture_output=True, text=True).stdout.strip()
    dirty = bool(subprocess.run(['git', '-C', ROOT, 'status', '--porcelain', '--', 'koreans', 'scripts/tools/export_koreans.py',
                                 'scripts/tools/korean_visuals.py'], capture_output=True, text=True).stdout.strip())
    manifest = {'source': 'https://github.com/rostislavpeska/age-of-pirates (branch Pirate-rework, folder koreans/)',
                'commit': commit, 'source_dirty': dirty,
                'files': {k: hashlib.sha256(v).hexdigest() for k, v in sorted(out.items())}}
    out['EXPORT.json'] = (json.dumps(manifest, indent=1, sort_keys=True) + '\n').encode('utf-8')
    return out


def existing(out_dir):
    have = {}
    for d, dirs, files in os.walk(out_dir):
        dirs[:] = [x for x in dirs if not (d == out_dir and x in KEEP)]
        for f in files:
            full = os.path.join(d, f)
            have[os.path.relpath(full, out_dir).replace(os.sep, '/')] = full
    return have


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--out', default=DEFAULT_OUT)
    ap.add_argument('--check', action='store_true')
    a = ap.parse_args()
    files = build()
    have = existing(a.out) if os.path.isdir(a.out) else {}
    changed = [r for r, d in files.items() if r not in have or open(have[r], 'rb').read() != d]
    stale = [r for r in have if r not in files]
    ignore = {'EXPORT.json'}           # the commit id changes with every AoP commit
    if a.check:
        bad = [r for r in changed if r not in ignore] + stale
        for r in bad:
            print('STALE' if r in stale else 'DIFFERS', r)
        print('%s: %d files, %s' % (a.out, len(files), 'up to date' if not bad else '%d differ' % len(bad)))
        return 1 if bad else 0
    for r in changed:
        p = os.path.join(a.out, *r.split('/'))
        os.makedirs(os.path.dirname(p), exist_ok=True)
        open(p, 'wb').write(files[r])
    for r in stale:
        os.remove(have[r])
    print('exported %d files to %s (%d written, %d removed)' % (len(files), a.out, len(changed), len(stale)))
    return 0


if __name__ == '__main__':
    sys.exit(main())
