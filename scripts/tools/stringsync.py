#!/usr/bin/env python
"""Compile the English string table and build every language's twin from it.

    python scripts/tools/stringsync.py                   # audit: which languages are stale or incomplete
    python scripts/tools/stringsync.py --build           # write the twins, then commit all of them
    python scripts/tools/stringsync.py --build --vanilla # also verify the REWRITES / NEW STRINGS split

The engine knows exactly one string-mod filename, stringmods.xml, loaded from
data/strings/<language>/. Only english/ keeps an editable .xml; the other folders
ship the compiled .xml.xmb alone. Forgetting to rebuild them silently ships missing
names to every non-English player (2026-09-17: ten ids were absent from fourteen
languages). Releases run --build; prezip_check.py blocks a release that did not.

english/stringmods.xml is the single source of truth and has two marked sections:

  <!-- ===== REWRITES ... -->      overrides of VANILLA string ids. Each other language
                                   keeps its own translation of exactly these ids in
                                   data/strings/_rewrites/<language>.xml (static, in that
                                   language). Building a language swaps this block for
                                   that file - it is never copied as English.
  <!-- ===== NEW STRINGS ... -->   mod-own ids (400001-400290, 500001+; vanilla tops out at
                                   300366). Copied 1:1 into every language, English text.

So a release only ever replaces the NEW STRINGS part of a language; its rewrites
survive untouched. A language whose fragment is missing, or does not hold exactly the
ids the English REWRITES block holds, is INCOMPLETE and is not written. Fragments are
UTF-8; anything else is refused. Ordering inside the English file is stringcheck.py's job.
"""
import argparse
import os
import re
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
SKILL = os.path.join(REPO, '.claude', 'skills', 'bar-extract', 'scripts')
STRINGS = os.path.join(REPO, 'data', 'strings')
SOURCE_LANG = 'english'
NAME = 'stringmods.xml'
REWRITES = os.path.join(STRINGS, '_rewrites')
LOCID = re.compile(r'_locid="(\d+)"')
MARK_REWRITES = b'<!-- ===== REWRITES'
MARK_NEW = b'<!-- ===== NEW STRINGS'
VANILLA_TABLE = 'data/strings/English/stringtabley.xml'

sys.path.insert(0, SKILL)
try:
    import xmbc
    import bartool
except ImportError as e:                                    # pragma: no cover
    sys.exit('cannot import the XMB tools from %s (%s). pip install lz4' % (SKILL, e))


def languages():
    """Every language folder, source first. A leading _ marks a non-language folder."""
    if not os.path.isdir(STRINGS):
        sys.exit('no such directory: %s' % STRINGS)
    found = sorted(d for d in os.listdir(STRINGS)
                   if os.path.isdir(os.path.join(STRINGS, d)) and not d.startswith('_'))
    if SOURCE_LANG not in found:
        sys.exit('no %s/ folder under %s' % (SOURCE_LANG, STRINGS))
    return [SOURCE_LANG] + [d for d in found if d != SOURCE_LANG]


def live_ids(lines):
    """ids on lines that are not commented out (a parked <!-- <string> --> is not live)."""
    out = []
    for l in lines:
        s = l.strip()
        if s.startswith(b'<!--'):
            continue
        out += LOCID.findall(s.decode('utf-8', 'replace'))
    return out


def split_source(raw):
    """(head, rewrite_lines, tail, eol). head ends with the REWRITES marker line, tail starts
    with the NEW STRINGS marker line. Without markers: whole file is NEW STRINGS."""
    eol = b'\r\n' if raw.count(b'\r\n') else b'\n'
    lines = raw.split(eol)
    r = [i for i, l in enumerate(lines) if MARK_REWRITES in l]
    n = [i for i, l in enumerate(lines) if MARK_NEW in l]
    if not r and not n:
        return None, [], None, eol
    if len(r) != 1 or len(n) != 1 or r[0] > n[0]:
        sys.exit('english/%s: expected one REWRITES marker followed by one NEW STRINGS marker' % NAME)
    # the REWRITES comment may span lines; head runs to the line that closes it
    end = r[0]
    while b'-->' not in lines[end]:
        end += 1
    return lines[:end + 1], lines[end + 1:n[0]], lines[n[0]:], eol


def compile_to_alz4(xml_path):
    """(alz4 bytes, live string count). Refuses an XMB that does not decode back identically."""
    xmb, root = xmbc.compile_xml(xml_path)
    if xmbc.canon(bartool.xmb_to_element(xmb)) != xmbc.canon(root):
        sys.exit('%s: XMB does not decode back to the source - refusing to write' % xml_path)
    return xmbc.wrap_alz4(xmb), sum(1 for _ in root.iter('string'))


def fragment_lines(lang):
    """(path, string lines) of this language's rewrite fragment, or (None, [])."""
    p = os.path.join(REWRITES, lang + '.xml')
    if not os.path.isfile(p):
        return None, []
    frag = open(p, 'rb').read()
    if frag.startswith(b'\xef\xbb\xbf'):
        frag = frag[3:]
    try:
        frag.decode('utf-8')
    except UnicodeDecodeError as e:
        sys.exit('%s is not UTF-8 (byte %d). Save the fragment as UTF-8 and rerun.' % (p, e.start))
    lines = [l.rstrip(b'\r') for l in frag.split(b'\n')]
    return p, [l for l in lines if LOCID.search(l.decode('utf-8')) and not l.strip().startswith(b'<!--')]


class Plan(object):
    """What one language should ship and why; data is None when it cannot be built."""
    def __init__(self, how, data=None, problem=None):
        self.how, self.data, self.problem = how, data, problem


def plan_language(lang, raw, parts, base, tmp):
    head, rewrites, tail, eol = parts
    rewrite_ids = set(live_ids(rewrites))
    frag_path, frag = fragment_lines(lang)
    if lang == SOURCE_LANG:
        return Plan('source, %d rewrite(s)' % len(rewrite_ids), base)
    if not rewrite_ids:
        if frag_path:
            return Plan('fragment present', problem='English has no REWRITES block to replace - remove the fragment or add the block')
        return Plan('copy of %s' % SOURCE_LANG, base)
    if not frag_path:
        return Plan('no fragment', problem='English has %d rewrite(s) but data/strings/_rewrites/%s.xml is missing - '
                    'add it, translated, or this language would ship English for a vanilla string' % (len(rewrite_ids), lang))
    frag_ids = set(live_ids(frag))
    if frag_ids != rewrite_ids:
        miss = sorted(rewrite_ids - frag_ids, key=int)
        extra = sorted(frag_ids - rewrite_ids, key=int)
        return Plan('fragment mismatch', problem='fragment must hold exactly the English REWRITES ids: missing %s, extra %s'
                    % (miss or '-', extra or '-'))
    merged = eol.join(head + [b'      ' + l.strip() for l in frag] + tail)
    path = os.path.join(tmp, lang + '.xml')
    open(path, 'wb').write(merged)
    data, _ = compile_to_alz4(path)
    return Plan('%s rewrites + English new strings' % lang, data)


def run(build, check_vanilla):
    source_xml = os.path.join(STRINGS, SOURCE_LANG, NAME)
    if not os.path.isfile(source_xml):
        sys.exit('missing source of truth: %s' % source_xml)
    raw = open(source_xml, 'rb').read()
    parts = split_source(raw)
    base, count = compile_to_alz4(source_xml)
    print('%s: %d strings, %d bytes compiled%s' % (
        os.path.relpath(source_xml, REPO), count, len(base),
        '' if parts[0] is not None else '  (no REWRITES/NEW STRINGS markers: whole file treated as new strings)'))
    if check_vanilla:
        report_vanilla(parts)

    tmp = tempfile.mkdtemp(prefix='stringsync-')
    stale = incomplete = 0
    for lang in languages():
        twin = os.path.join(STRINGS, lang, NAME + '.xmb')
        p = plan_language(lang, raw, parts, base, tmp)
        have = open(twin, 'rb').read() if os.path.isfile(twin) else None
        if p.data is None:
            state, incomplete = 'INCOMPLETE', incomplete + 1
        elif have == p.data:
            state = 'current'
        elif have is None:
            state, stale = 'MISSING', stale + 1
        else:
            state, stale = 'STALE', stale + 1
        if build and p.data is not None and have != p.data:
            open(twin, 'wb').write(p.data)
            state = 'written'
        print('   %-20s %-11s %s' % (lang, state, p.how))
        if p.problem:
            print('   %-20s             %s' % ('', p.problem))

    if incomplete:
        print('\n%d language(s) INCOMPLETE and not written - fix the fragments above.' % incomplete)
        return 1
    if build:
        print('\nall %d languages written or current. Commit every .xml.xmb.' % len(languages()))
        print('XMBs load once at process start: restart the game to see the change.')
        return 0
    if stale:
        print('\n%d language(s) out of date. Run with --build, then commit the twins.' % stale)
        return 1
    print('\nall %d languages current.' % len(languages()))
    return 0


def report_vanilla(parts):
    """The split invariant: every REWRITES id is a vanilla id, no NEW STRINGS id is."""
    cache = os.path.join(tempfile.gettempdir(), 'aoe3-vanilla-stringtable.xml')
    if not (os.path.isfile(cache) and os.path.getsize(cache) > 1000000):
        tool = os.path.join(SKILL, 'bartool.py')
        print('   reading the vanilla string table from the game archives...')
        try:
            with open(cache, 'wb') as fh:
                subprocess.check_call([sys.executable, tool, 'cat', VANILLA_TABLE], stdout=fh)
        except (subprocess.CalledProcessError, OSError) as e:
            print('   SKIPPED the vanilla check: %s' % e)
            return
    van = set(LOCID.findall(open(cache, 'rb').read().decode('utf-8', 'replace')))
    head, rewrites, tail, _ = parts
    rw = set(live_ids(rewrites))
    _, root = xmbc.compile_xml(os.path.join(STRINGS, SOURCE_LANG, NAME))
    new = {e.get('_locid') for e in root.iter('string')} - rw          # exactly what compiles, comments excluded
    bad_rw = sorted(rw - van, key=int)
    bad_new = sorted(new & van, key=int)
    print('   vanilla check: REWRITES %d id(s), all vanilla: %s | NEW STRINGS %d id(s), none vanilla: %s'
          % (len(rw), 'yes' if not bad_rw else 'NO ' + ', '.join(bad_rw),
             len(new), 'yes' if not bad_new else 'NO ' + ', '.join(bad_new)))
    if bad_rw:
        print('      these REWRITES ids do not exist in vanilla - they belong under NEW STRINGS')
    if bad_new:
        print('      these NEW STRINGS ids override vanilla - move them to REWRITES and translate them per language')


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0],
                                 formatter_class=argparse.RawDescriptionHelpFormatter, epilog=__doc__)
    ap.add_argument('--build', action='store_true', help='write the twins (default: audit only)')
    ap.add_argument('--vanilla', action='store_true', help='verify the REWRITES / NEW STRINGS split against vanilla ids')
    a = ap.parse_args()
    sys.exit(run(a.build, a.vanilla))


if __name__ == '__main__':
    main()
