"""Replace one proto by another in groupings while keeping the exact model (mesh + texture) on screen.

A grouping unit shows entry (variation mod K) of its proto animfile's first <logic type="Variation"> list
(K children, file order, 0-based; entries are <data> with an <assetreference><file> or a
<submodelref ref="Name"> pointing at a <submodel> whose component carries the file). To swap proto A for
proto B and keep the look, the target must list the SAME model file; its index there is the new variation.

    python model_swap.py <groupings dir> --from PROTO --to PROTO[,PROTO...] [--prefix IS_] [--apply] [--also <dir>]
    python model_swap.py table --from PROTO --to PROTO[,PROTO...]                     # the model -> target map only
    python model_swap.py validate --from PROTO --to PROTO[,PROTO...] --out <dir> [--name IS_Validation_X.xml]

Dry run unless --apply. Only the matched <unit ...>FROM</unit> lines change (variation + proto); bytes
elsewhere survive. --also mirrors the identical bytes to a second folder (the user's RandMaps/groupings).
`validate` writes a side-by-side grouping: per mapped model three rows - the original proto with the small
index, the target proto, and the original with index+K (proves the N mod K rule in the editor).
Protos come from data/protomods.xml; set AOP_VANILLA=<dir holding vanilla/protoy.xml and allart/Art> to
resolve vanilla protos/animfiles too.
"""
import os, re, sys, argparse, hashlib
BS = chr(92)
REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.realpath(__file__)), '..', '..', '..', '..'))
VAN = os.environ.get('AOP_VANILLA', '')

def read(p):
    return open(p, 'rb').read().decode('utf-8', 'replace')

def proto_record(name):
    for src in [os.path.join(REPO, 'data', 'protomods.xml')] + ([os.path.join(VAN, 'vanilla', 'protoy.xml')] if VAN else []):
        if not os.path.exists(src): continue
        m = re.search(r'<unit id="\d+" name="%s">(.*?)</unit>' % re.escape(name), read(src), re.S)
        if m: return m.group(1), src
    raise SystemExit('proto %s not found in protomods%s' % (name, ' or vanilla protoy' if VAN else ' (set AOP_VANILLA for vanilla protos)'))

def animfile_path(rel):
    rel = rel.replace(BS, '/')
    for base in [os.path.join(REPO, 'art')] + ([os.path.join(VAN, 'allart', 'Art')] if VAN else []):
        p = os.path.join(base, rel)
        if os.path.exists(p): return p
        d, f = os.path.split(p)   # case-insensitive fallback
        if os.path.isdir(d):
            for g in os.listdir(d):
                if g.lower() == f.lower(): return os.path.join(d, g)
    raise SystemExit('animfile not found: %s' % rel)

def model_list(proto):
    """[(index, model file lowercased)] in Variation order; K=1 single model when there is no logic."""
    rec, _ = proto_record(proto)
    rel = re.search(r'<animfile>([^<]*)</animfile>', rec).group(1)
    t = read(animfile_path(rel))
    subs = {m.group(1).strip(): m.group(2) for m in re.finditer(r'<submodel>\s*(\w+)(.*?)</submodel>', t, re.S)}
    var = re.search(r'<logic type="Variation">(.*?)</logic>', t, re.S)
    out = []
    if var:
        for i, d in enumerate(re.findall(r'<data>(.*?)</data>', var.group(1), re.S)):
            f = re.search(r'<assetreference type="(?:GrannyModel|CompositeModel)">\s*<file>([^<]*)</file>', d) or re.search(r'<file>([^<]*)</file>', d)
            if not f:
                ref = re.search(r'<submodelref ref="(\w+)"', d)
                body = subs.get(ref.group(1), '') if ref else ''
                f = re.search(r'<assetreference type="(?:GrannyModel|CompositeModel)">\s*<file>([^<]*)</file>', body) or re.search(r'<file>([^<]*)</file>', body)
            out.append((i, f.group(1).strip().lower() if f else '?'))
    else:
        f = re.search(r'<component>\s*\w+.*?<file>([^<]*)</file>', t, re.S)
        out.append((0, f.group(1).strip().lower() if f else '?'))
    locked = '<flag>VariationLocked</flag>' in rec
    obstr = re.findall(r'<obstructionradius[xz]>([^<]*)', rec)
    return out, rel, locked, obstr

def build_map(src, targets):
    smodels, srel, slock, sobs = model_list(src)
    tinfo = {t: model_list(t) for t in targets}
    table = {}
    for i, m in smodels:
        for t in targets:
            hit = [j for j, tm in tinfo[t][0] if tm == m]
            if hit:
                table[i] = (t, hit[0], m); break
    return smodels, tinfo, table, (srel, slock, sobs)

def show_table(src, targets):
    smodels, tinfo, table, (srel, slock, sobs) = build_map(src, targets)
    print('%s  (%s, K=%d, VariationLocked=%s, obstruction %s)' % (src, srel, len(smodels), slock, sobs))
    for t, (ml, rel, lock, obs) in tinfo.items():
        print('  target %s  (%s, K=%d, VariationLocked=%s, obstruction %s)%s' % (t, rel, len(ml), lock, obs, '' if lock else '   <- WARNING: not VariationLocked, verify in the editor that it honours variation'))
    for i, m in smodels:
        print('  %2d %-58s -> %s' % (i, m.split('/')[-1].split(BS)[-1], ('%s/%d' % table[i][:2]) if i in table else '(no identical model in targets - stays)'))
    return smodels, table

def unit_re(proto):
    return re.compile(r'<unit variation="(\d+)"([^>]*)>%s</unit>' % re.escape(proto))

def swap(dirpath, src, targets, prefix, apply, also):
    smodels, table = show_table(src, targets)
    K = len(smodels); rx = unit_re(src); total = 0; files = 0
    for f in sorted(os.listdir(dirpath)):
        if not f.startswith(prefix) or not f.lower().endswith('.xml'): continue
        p = os.path.join(dirpath, f); t = read(p); log = []
        def rep(m):
            v = int(m.group(1)); i = v % K
            if i not in table: return m.group(0)
            tp, ti, _ = table[i]; log.append('%s/%d(%d)->%s/%d' % (src[-1], v, i, tp[-1], ti))
            return '<unit variation="%d"%s>%s</unit>' % (ti, m.group(2), tp)
        t2 = rx.sub(rep, t)
        if not log: continue
        total += len(log); files += 1; print('%-36s %2d: %s' % (f, len(log), '; '.join(log)))
        if apply:
            open(p, 'wb').write(t2.encode('utf-8'))
            import xml.etree.ElementTree as ET; ET.parse(p)
            if also:
                d = os.path.join(also, f); open(d, 'wb').write(t2.encode('utf-8'))
                assert hashlib.md5(open(d, 'rb').read()).hexdigest() == hashlib.md5(open(p, 'rb').read()).hexdigest()
    print('%s: %d placements in %d files%s' % ('APPLIED' if apply else 'DRY RUN', total, files, ' (+ mirrored to %s)' % also if apply and also else ''))

def validate(src, targets, out_dir, name):
    smodels, table = show_table(src, targets)
    K = len(smodels); cols = [(i, m) for i, m in smodels if i in table]
    def unit(v, x, z, proto):
        return '\t\t<unit variation="%d" posx="%.4f" posz="%.4f" orientx="0.0000" orienty="0.0000" orientz="1.0000">%s</unit>' % (v, x, z, proto)
    DX = 10.0; X0 = -DX * (len(cols) - 1) / 2.0
    lines = ['<?xml version="1.0"?>', '', '<grouping>', '\t<width>%d</width>' % int(DX * len(cols) / 2 + 8), '\t<height>40</height>',
             '\t<ignoreplacementrules>1</ignoreplacementrules>', '\t<selectassingleunit>0</selectassingleunit>', '\t<workonassingleunit>0</workonassingleunit>', '\t<units>']
    for c, (i, m) in enumerate(cols):
        x = X0 + c * DX; tp, ti, _ = table[i]
        lines += [unit(i, x, 12.0, src), unit(ti, x, 0.0, tp), unit(i + K, x, -12.0, src)]
    lines += ['\t</units>', '</grouping>', '']
    p = os.path.join(out_dir, name); open(p, 'wb').write('\r\n'.join(lines).encode('utf-8'))
    import xml.etree.ElementTree as ET; ET.parse(p)
    print('validation grouping: %s | columns (x -> model): %s | rows z=+12 original/small index, z=0 target, z=-12 original/index+K' % (p, ', '.join('%.0f=%s' % (X0 + c * DX, m.split(BS)[-1]) for c, (i, m) in enumerate(cols))))

ap = argparse.ArgumentParser()
ap.add_argument('target_or_cmd'); ap.add_argument('--from', dest='src', required=True); ap.add_argument('--to', required=True)
ap.add_argument('--prefix', default=''); ap.add_argument('--apply', action='store_true'); ap.add_argument('--also')
ap.add_argument('--out'); ap.add_argument('--name')
a = ap.parse_args()
targets = a.to.split(',')
if a.target_or_cmd == 'table': show_table(a.src, targets)
elif a.target_or_cmd == 'validate': validate(a.src, targets, a.out, a.name or 'IS_Validation_%s.xml' % a.src)
else: swap(a.target_or_cmd, a.src, targets, a.prefix, a.apply, a.also)
