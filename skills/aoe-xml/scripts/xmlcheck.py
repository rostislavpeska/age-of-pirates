"""aoe-xml verification: the one command after any XML change in the mod. Run from the repo root.

    python skills/aoe-xml/scripts/xmlcheck.py                 # whole mod
    python skills/aoe-xml/scripts/xmlcheck.py PATH [PATH...]  # only these files / folders (+ protos they define)
    python skills/aoe-xml/scripts/xmlcheck.py --no-archive    # skip the .bar index (offline / fast)

Checks (ERROR = exit 1, WARN = informational):
  well-formed XML .......... every .xml / .material / .tactics under art/, sound/, data/
  CRLF ..................... runtime family (art/, sound/) and data/ sources; LF-only art XML is ignored by the engine
  twin freshness ........... data/**/*.xml newer than its .xml.xmb  -> rebuild with xmbc.py build
  proto references ......... protomods: animfile, tactics, icons, placementfile, string ids, deadreplacement,
                             _snds file present (mod or archive) and its soundsets defined
  animfile references ...... GrannyModel/GrannyAnim files, decal textures, popcornFx/ParticleSystem
  material references ...... every texture override resolves (mod .ddt or archive .ddt); submaterial names vs the gr2 (WARN)
  ids ...................... proto ids unique and not in the vanilla range unless mergeMode=replace; string ids unique
  string sync .............. stringsync.py audit (stale languages)
Resolution: mod folder first, then the archive index (bartool). Archive-referenced assets are the RULE, not a warning.
"""
import glob, io, os, re, subprocess, sys
import xml.etree.ElementTree as ET

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.realpath(__file__)), '..', '..', '..'))
os.chdir(REPO)
sys.path.insert(0, os.path.join(REPO, 'skills', 'aoe3de-bar-archives', 'scripts'))
BS = chr(92)
VANILLA_STRING_MAX = 300366
errors = []; warns = []
def err(m): errors.append(m)
def warn(m): warns.append(m)


# ---------------------------------------------------------------- archive index
class Archive:
    def __init__(self, enabled=True):
        self.paths = set(); self.ok = False
        if not enabled: return
        try:
            import bartool
            idx = bartool.build_index(bartool.find_game_dir())
            self.paths = {p.lower() for p in idx}; self.ok = True; self.bt = bartool; self.idx = idx
        except Exception as e:
            warn(f'archive index unavailable ({e}); references only checked against the mod folder')
    def has(self, rel):
        r = rel.replace(BS, '/').lower()
        return r in self.paths or (r + '.xmb') in self.paths
    def cat(self, rel):
        r = rel.replace(BS, '/').lower()
        for k in (r, r + '.xmb'):
            if k in self.paths:
                e = self.idx[next(p for p in self.idx if p.lower() == k)]
                data = self.bt.read_entry(e)
                return self.bt.decode(data, True, 'lf')[0] if self.bt.is_xmb(data) else data
        return None


def mod_has(*cands):
    return any(os.path.isfile(c) for c in cands)


def norm(p):
    return p.strip().replace(BS, '/')


def resolve(kind, ref, arc):
    """True if the reference exists in the mod folder or the archive; kind selects the resolution rule."""
    p = norm(ref)
    if kind == 'animfile': return mod_has(f'art/{p}') or arc.has(f'Art/{p}')
    if kind == 'gr2': return mod_has(f'art/{p}.gr2') or arc.has(f'Art/{p}.gr2')
    if kind == 'ddt': return mod_has(f'art/{p}.ddt', f'art/{p}_BaseColor.ddt') or arc.has(f'Art/{p}.ddt') or arc.has(f'Art/{p}_BaseColor.ddt')
    if kind == 'pkfx': return mod_has(f'art/popcornfx/Particles/{p}') or arc.has(f'Art/popcornfx/Particles/{p}')
    if kind == 'particle': return mod_has(f'art/{p}') or arc.has(f'Art/{p}')
    if kind == 'tactics': return mod_has(f'data/tactics/{p}') or arc.has(f'Data/tactics/{p}')
    if kind == 'icon': return mod_has(f'data/wpfg/{p}') or arc.has(f'Data/wpfg/{p}')
    if kind == 'minimap': return mod_has(f'art/{p}.tga', f'art/{p}.ddt') or arc.has(f'Art/{p}.tga') or arc.has(f'Art/{p}.ddt')
    if kind == 'placement': return mod_has(f'data/placementrules/{p}') or arc.has(f'Data/placementrules/{p}')
    if kind == 'snds': return mod_has(f'sound/{p}_snds.xml') or arc.has(f'Sound/{p}_snds.xml')
    return True


# ---------------------------------------------------------------- generic file checks
def wellformed(path):
    try: ET.parse(path); return True
    except ET.ParseError as e: err(f'{path}: not well-formed XML: {e}'); return False


def crlf(path):
    b = open(path, 'rb').read()
    lone = b.count(b'\n') - b.count(b'\r\n')
    if lone: err(f'{path}: {lone} LF-only line(s) - the engine ignores LF art XML (scripts/tools/check_art_eol.py --fix)')


def twin(path):
    t = path + '.xmb'
    if os.path.isfile(t) and os.path.getmtime(path) > os.path.getmtime(t) + 1:
        err(f'{path}: source newer than its .xmb twin - run xmbc.py build')


# ---------------------------------------------------------------- collectors
def mod_strings():
    ids = {}
    p = 'data/strings/english/stringmods.xml'
    if os.path.isfile(p):
        for m in re.finditer(r'_locid="(\d+)"', re.sub(r'<!--.*?-->', '', open(p, encoding='utf-8', errors='replace').read(), flags=re.S)):
            ids[int(m.group(1))] = ids.get(int(m.group(1)), 0) + 1
    return ids


def mod_soundsets(arc):
    names = set()
    for f in glob.glob('sound/soundsets*.xml'):
        names |= set(re.findall(r'<soundset name="([^"]+)"', open(f, encoding='utf-8', errors='replace').read()))
    if arc.ok:
        for rel in ('Sound/soundsets.xml', 'Sound/soundsetsx.xml', 'Sound/soundsetsy.xml', 'Sound/soundsetsde.xml'):
            t = arc.cat(rel)
            if t: names |= set(re.findall(r'<soundset name="([^"]+)"', t if isinstance(t, str) else t.decode('utf-8', 'replace')))
    return names


def vanilla_proto_ids():
    p = 'scripts/source/protoy.xml'
    if not os.path.isfile(p): return set()
    return {int(m) for m in re.findall(r'<unit id="(\d+)"', open(p, encoding='utf-8', errors='replace').read())}


# ---------------------------------------------------------------- data checks
def check_protomods(path, arc, strings, soundsets, only=None):
    root = ET.parse(path).getroot(); seen = {}; vanilla = vanilla_proto_ids()
    text = open(path, encoding='utf-8', errors='replace').read()
    tm = text.find('<!--TEST AND TEMPORARY CONTENT-->'); test_names = set()
    if tm >= 0: test_names = set(re.findall(r'<unit [^>]*name="([^"]+)"', text[tm:]))
    for u in root.iter('unit'):
        name = u.get('name'); uid = u.get('id')
        if only and name not in only: continue
        in_test = name in test_names
        tag = f'{path} {name}' + (' [TEST block]' if in_test else '')
        err = (lambda m: warns.append(m)) if in_test else errors.append          # TEST content: warn only
        if uid:
            i = int(uid)
            if i in seen: err(f'{tag}: duplicate proto id {i} (also {seen[i]})')
            seen[i] = name
            if i in vanilla and u.get('mergeMode') != 'replace': err(f'{tag}: id {i} is a vanilla id without mergeMode=replace')
            d = u.find('dbid')
            if d is not None and d.text and d.text.strip() != uid: warn(f'{tag}: dbid {d.text.strip()} != id {uid}')
        for fld, kind in (('animfile', 'animfile'), ('tactics', 'tactics'), ('icon', 'icon'), ('portraiticon', 'icon'),
                          ('minimapicon', 'minimap'), ('placementfile', 'placement')):
            e = u.find(fld)
            if e is not None and e.text and e.text.strip():
                if e.text != e.text.strip(): err(f'{tag}: <{fld}> text has surrounding whitespace (XMB keeps it verbatim)')
                if not resolve(kind, e.text, arc): err(f'{tag}: <{fld}> {e.text.strip()} not found (mod or archive)')
        for fld in ('displaynameid', 'editornameid', 'rollovertextid', 'shortrollovertextid'):
            e = u.find(fld)
            if e is not None and e.text and e.text.strip().isdigit():
                sid = int(e.text.strip())
                if sid > VANILLA_STRING_MAX and sid not in strings: err(f'{tag}: <{fld}> string {sid} not in english stringmods')
        types = {t.text.strip() for t in u.iter('unittype') if t.text}
        if name and u.get('mergeMode') != 'replace' and ({'Unit', 'Building'} & types) and not ({'EmbellishmentClass', 'Projectile', 'Socket'} & types):
            if not resolve('snds', name.lower(), arc): warn(f'{tag}: no sound/{name.lower()}_snds.xml (mod or archive) - unit will be silent')


def check_snds(path, soundsets):
    if not wellformed(path): return
    root = ET.parse(path).getroot()
    base = os.path.basename(path)[:-len('_snds.xml')]
    for pu in root.iter('protounit'):
        if (pu.get('name') or '').lower() != base: err(f'{path}: <protounit name="{pu.get("name")}"> does not match the file name')
    if soundsets:
        for ss in root.iter('soundset'):
            n = ss.get('name')
            if n and n not in soundsets: err(f'{path}: soundset {n} is not defined in any soundsets file')


# ---------------------------------------------------------------- art checks
def check_animfile(path, arc):
    if not wellformed(path): return
    root = ET.parse(path).getroot()
    for a in root.iter('assetreference'):
        t = a.get('type'); f = a.find('file')
        if f is None or not f.text or not f.text.strip(): continue
        ref = f.text.strip(); kind = {'GrannyModel': 'gr2', 'GrannyAnim': 'gr2', 'popcornFx': 'pkfx', 'ParticleSystem': 'particle'}.get(t)
        if kind and not resolve(kind, ref, arc):
            err(f'{path}: {t} {ref} not found (mod or archive)')
        if t == 'CompositeModel' and not (resolve('animfile', ref + '.xml', arc) or resolve('animfile', ref + '.composite', arc)):
            warn(f'{path}: CompositeModel {ref}: no .xml/.composite found (resolution rule unverified)')
        if kind == 'gr2' and mod_has(f'art/{norm(ref)}.gr2') and not os.path.isfile(f'art/{norm(ref)}.material'):
            warn(f'{path}: mod model {ref} has no .material beside it')
    for d in root.iter('decal'):
        for fld in ('texture', 'bumptexture', 'selectedtexture'):
            e = d.find(fld)
            if e is not None and e.text and e.text.strip() and not resolve('ddt', e.text, arc): err(f'{path}: decal <{fld}> {e.text.strip()} not found')


def check_material(path, arc):
    if not wellformed(path): return
    root = ET.parse(path).getroot()
    for t in root.iter('texture'):
        ov = t.get('override')
        if ov and not resolve('ddt', ov, arc): err(f'{path}: texture {ov} not found (mod .ddt or archive)')
    gr2 = path[:-len('.material')] + '.gr2'
    if os.path.isfile(gr2):
        try:
            sys.path.insert(0, os.path.join(REPO, 'scripts', 'havok'))
            from gr2_read import Gr2
            from gr2_dump import refs
            g = Gr2(gr2); r = g.root(); names = {m['Name'] for m, _ in refs(g, r['Materials'])}
            subs = {s.get('name') for s in root.iter('submaterial')}
            bound = set()
            for me, _ in refs(g, r['Meshes']):
                mb = me['MaterialBindings']; sz = g.struct_size(*mb[3])
                for k in range(mb[1]): bound.add(g.read(*r['Materials'][3], *g.deref(mb[2][0], mb[2][1] + k * sz))['Name'])
            for b in bound:
                if b not in subs: warn(f'{path}: gr2 binds material {b!r} but no <submaterial name="{b}"> (case-sensitive?)')
        except NotImplementedError: pass          # converter-made gr2 (compressed): not readable, skip
        except Exception as e: warn(f'{path}: could not read {gr2}: {type(e).__name__}')


# ---------------------------------------------------------------- main
def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    arc = Archive('--no-archive' not in sys.argv)
    targets = args or ['art', 'sound', 'data']
    files = []
    for t in targets:
        if os.path.isfile(t): files.append(t)
        else:
            for d, _, fs in os.walk(t):
                files += [os.path.join(d, f) for f in fs if f.lower().endswith(('.xml', '.material', '.tactics'))]
    files = sorted({f.replace('\\', '/') for f in files})
    strings = mod_strings(); soundsets = mod_soundsets(arc)
    # string ids unique
    for sid, n in strings.items():
        if n > 1: err(f'data/strings/english/stringmods.xml: _locid {sid} defined {n} times')
    for f in files:
        low = f.lower()
        if low.endswith('.xmb'): continue
        if low.startswith(('art/', 'sound/')): crlf(f)
        if low.startswith('data/') and (low.endswith('.xml') or low.endswith('.tactics')): crlf(f); twin(f)
        if low.endswith('_snds.xml'): check_snds(f, soundsets); continue
        if low.startswith('art/') and low.endswith('.material'): check_material(f, arc); continue
        if low.startswith('art/') and low.endswith('.xml'): check_animfile(f, arc); continue
        if low == 'data/protomods.xml': wellformed(f) and check_protomods(f, arc, strings, soundsets); continue
        if low.endswith(('.xml', '.tactics')): wellformed(f)
    if not args or any('strings' in a for a in args):
        try:
            out = subprocess.run([sys.executable, 'scripts/tools/stringsync.py'], capture_output=True, text=True, timeout=300).stdout
            m = re.search(r'(\d+) language\(s\) out of date', out)
            if m and int(m.group(1)): warn(f'stringsync: {m.group(1)} language(s) stale - run scripts/tools/stringsync.py --build')
        except Exception as e: warn(f'stringsync audit skipped: {e}')
    for w in warns: print('WARN ', w)
    for e in errors: print('ERROR', e)
    print(f'{len(files)} file(s) checked - {len(errors)} error(s), {len(warns)} warning(s)' + ('' if arc.ok else ' [no archive index]'))
    return 1 if errors else 0


if __name__ == '__main__':
    sys.exit(main())
