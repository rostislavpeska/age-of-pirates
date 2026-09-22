"""Swap zpNativeHouseVenetianB placements (0.0001 obstruction, walkable) for the solid proto that shows the
IDENTICAL model, keeping position/orientation. The engine picks Variation entry (N mod K), verified in the
editor 2026-09-12 with IS_Validation_HouseSwap.xml (B/13 == B/0, B/246 == B/12, B/99 == house3b ...).

    python house_swap.py <groupings dir> [--prefix IS_] [--narrow] [--apply] [--also <other dir>]

B (venetian_buildings2.xml, K=13): 0 generic_04, 1 generic_08, 2 generic_05, 3 campanile_big, 4 floor_01,
5 floor_02, 6 wall, 7 covered_bridge, 8 house3b, 9 rialto2, 10 rialto, 11 house3c, 12 generic_09
E (K=2): 0 generic_04, 1 generic_05   G (K=2): 0 generic_08, 1 generic_09   D (K=4): 0/1 house3b, 2/3 house3c
Only the large houses swap by default; --narrow also moves house3b/house3c to D. Everything else stays B.
Dry run unless --apply. Byte-preserving: only the matched <unit ...>B</unit> lines change."""
import os, re, sys, hashlib, argparse
ap = argparse.ArgumentParser()
ap.add_argument('dir'); ap.add_argument('--prefix', default='IS_'); ap.add_argument('--narrow', action='store_true')
ap.add_argument('--apply', action='store_true'); ap.add_argument('--also')
a = ap.parse_args()
K = 13
SWAP = {0: ('zpNativeHouseVenetianE', 0), 2: ('zpNativeHouseVenetianE', 1), 1: ('zpNativeHouseVenetianG', 0), 12: ('zpNativeHouseVenetianG', 1)}
if a.narrow:
    SWAP.update({8: ('zpNativeHouseVenetianD', 0), 11: ('zpNativeHouseVenetianD', 2)})
NAMES = {0: 'generic_04', 1: 'generic_08', 2: 'generic_05', 3: 'campanile_big', 4: 'floor_01', 5: 'floor_02', 6: 'wall', 7: 'covered_bridge', 8: 'house3b', 9: 'rialto2', 10: 'rialto', 11: 'house3c', 12: 'generic_09'}
UNIT = re.compile(r'<unit variation="(\d+)"([^>]*)>zpNativeHouseVenetianB</unit>')
total = 0; changed_files = []
for f in sorted(os.listdir(a.dir)):
    if not f.startswith(a.prefix) or not f.lower().endswith('.xml'): continue
    p = os.path.join(a.dir, f); raw = open(p, 'rb').read(); t = raw.decode('utf-8')
    log = []
    def rep(m):
        v = int(m.group(1)); idx = v % K
        if idx not in SWAP: return m.group(0)
        proto, nv = SWAP[idx]; log.append('B/%d (%s) -> %s/%d' % (v, NAMES[idx], proto[-1], nv))
        return '<unit variation="%d"%s>%s</unit>' % (nv, m.group(2), proto)
    t2 = UNIT.sub(rep, t)
    if not log: continue
    total += len(log); changed_files.append(f)
    print('%-34s %2d swapped: %s' % (f, len(log), '; '.join(log)))
    if a.apply:
        open(p, 'wb').write(t2.encode('utf-8'))
        import xml.etree.ElementTree as ET; ET.parse(p)
        if a.also:
            d = os.path.join(a.also, f); open(d, 'wb').write(t2.encode('utf-8'))
            assert hashlib.md5(open(d, 'rb').read()).hexdigest() == hashlib.md5(open(p, 'rb').read()).hexdigest()
print('\n%s: %d placements in %d files%s' % ('APPLIED' if a.apply else 'DRY RUN', total, len(changed_files), ' (+ mirrored to %s)' % a.also if a.apply and a.also else ''))
