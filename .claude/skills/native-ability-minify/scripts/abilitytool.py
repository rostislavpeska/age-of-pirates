#!/usr/bin/env python3
"""Shrink a native big-button ability to a 1x1 grid button.

Reads vanilla straight out of the .bar archives via the bar-extract skill, so it
needs no unpacked game files.

    find    [pattern]   native ability commands in vanilla, with their size flags
    slots   <subciv>    Trading Post button grid for a subciv, vanilla + mod
    plan    <command>   emit every block needed to build the small variant
    verify  [prefix]    audit the mod's small-button chains, including .xmb staleness
"""
import argparse
import os
import re
import sys
import xml.etree.ElementTree as ET

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', '..', 'bar-extract', 'scripts'))
import bartool as B  # noqa: E402

# the three flags that make a button big -- all must be absent for a 1x1
ABILITY_FLAG = 'usebigabilitybutton3'
COMMAND_FLAG = 'usemediumbutton3'
TECH_FLAG = 'DEUseMediumButton3'

VANILLA = {
    'commands': 'Data/protounitcommands.xml.XMB',
    'abilities': 'Data/abilities/abilities.xml.XMB',
    'powers': 'Data/abilities/powers.xml.XMB',
    'techs': 'Data/techtreey.xml.XMB',
    'protos': 'Data/protoy.xml.XMB',
}

MOD = {
    'commands': 'data/protounitcommandmods.xml',
    'abilities': 'data/abilities/abilitymods.xml',
    'powers': 'data/abilities/powermods.xml',
    'techs': 'data/techtreemods.xml',
    'protos': 'data/protomods.xml',
}

_cache = {}


def vanilla(key):
    """Decompiled vanilla XML text, cached per run."""
    if key not in _cache:
        idx = _cache.setdefault('_index', B.build_index(B.find_game_dir(None)))
        hits = B.match(idx, [VANILLA[key]])
        if not hits:
            sys.exit(f'vanilla {VANILLA[key]} not found in the archives')
        data, _ = B.decode(B.read_entry(hits[0]), True, 'lf')
        _cache[key] = data.decode('utf-8', 'replace')
    return _cache[key]


def mod(key, root='.'):
    p = os.path.join(root, MOD[key].replace('/', os.sep))
    if not os.path.exists(p):
        return ''
    return open(p, 'rb').read().decode('utf-8-sig')


def block(text, tag, name):
    """The <tag> element whose <name> child or name= attribute is `name`.

    Non-crossing: the body may not contain a nested </tag>, so a lazy match
    cannot start at an earlier element and run into this one.
    """
    body = r'(?:(?!</%s>).)*?' % tag
    for pat in (r'<%s>%s<name>\s*%s\s*</name>%s</%s>' % (tag, body, re.escape(name), body, tag),
                r'<%s\s[^>]*name\s*=\s*"%s"[^>]*>%s</%s>' % (tag, re.escape(name), body, tag)):
        m = re.search(pat, text, re.S)
        if m:
            return m.group(0)
    return None


def child(blk, tag):
    m = re.search(r'<%s>([^<]*)</%s>' % (tag, tag), blk or '')
    return m.group(1).strip() if m else None


def ability_entry(text, power):
    """(owning proto tag, raw <ability> element) for a power, or (None, None).

    abilities.xml groups abilities under the proto that casts them, and the
    power name is the element's leading text -- not an attribute.
    """
    for m in re.finditer(r'<ability(?:\s[^>]*)?>\s*' + re.escape(power) + r'(?=[<\s])'
                         r'(?:(?!</ability>).)*?</ability>', text, re.S):
        head = text.rfind('<', 0, m.start())
        depth = text.rfind('>', 0, m.start())
        owner = None
        for om in re.finditer(r'<([a-z0-9_]+)>\s*$', text[:m.start()].rsplit('\n', 40)[0] or ''):
            owner = om.group(1)
        # walk back for the nearest unclosed single-tag line
        for line in reversed(text[:m.start()].splitlines()):
            om = re.match(r'\s*<([a-z0-9_]+)>\s*$', line)
            if om:
                owner = om.group(1)
                break
        del head, depth
        return owner, m.group(0)
    return None, None


def grid(proto_text, unit):
    """{(page, column): [entries]} for a proto's train/tech/command buttons."""
    m = re.search(r'<unit\s[^>]*name\s*=\s*"%s"' % re.escape(unit), proto_text)
    if not m:
        return {}
    blk = proto_text[m.start():proto_text.find('</unit>', m.start())]
    out = {}
    for em in re.finditer(r'<(train|tech|command|build)\b([^>]*)>([^<]+)</\1>', blk):
        attrs, val = em.group(2), em.group(3).strip()
        p = re.search(r'page="(\d+)"', attrs)
        c = re.search(r'column="(\d+)"', attrs)
        if p and c:
            out.setdefault((int(p.group(1)), int(c.group(1))), []).append(
                f'{em.group(1)}:{val}')
    return out


# --------------------------------------------------------------------- find
def cmd_find(args):
    text = vanilla('commands')
    abil = vanilla('abilities')
    techs = vanilla('techs')
    n = 0
    for m in re.finditer(r'<protounitcommand>(?:(?!</protounitcommand>).)*?'
                         r'</protounitcommand>', text, re.S):
        blk = m.group(0)
        power = child(blk, 'associatedpower')
        if not power:
            continue
        name = child(blk, 'name')
        subciv = child(blk, 'subciv') or '-'
        if args.pattern and args.pattern.lower() not in (name + subciv + power).lower():
            continue
        tech = child(blk, 'associatedtech')
        tblk = block(techs, 'tech', tech) if tech else None
        _, ablk = ability_entry(abil, power)
        flags = []
        if ablk and ABILITY_FLAG in ablk:
            flags.append('ability:big')
        if COMMAND_FLAG in blk:
            flags.append('command:medium')
        if tblk and TECH_FLAG in tblk:
            flags.append('tech:medium')
        if args.big_only and not flags:
            continue
        n += 1
        print(f'{name}')
        print(f'    subciv {subciv:<14} power {power}')
        print(f'    tech   {tech}')
        print(f'    size   {", ".join(flags) if flags else "already 1x1"}')
    print(f'\n{n} command(s)')
    return 0


# -------------------------------------------------------------------- slots
def cmd_slots(args):
    van = grid(vanilla('protos'), args.unit)
    modtext = mod('protos', args.root)
    mg = grid(modtext, args.unit) if modtext else {}

    added = {}
    for m in re.finditer(r'<effect type="CommandAdd"([^>]*)>\s*'
                         r'<target type="ProtoUnit">%s</target>' % re.escape(args.unit),
                         mod('techs', args.root)):
        a = m.group(1)
        p = re.search(r'page="(\d+)"', a)
        c = re.search(r'column="(\d+)"', a)
        nm = re.search(r'(?:tech|command)="([^"]+)"', a)
        if p and c and nm:
            added.setdefault((int(p.group(1)), int(c.group(1))), []).append(nm.group(1))

    subciv = args.subciv.lower() if args.subciv else None
    print(f'{args.unit} button grid'
          + (f'  (filtered to entries naming "{args.subciv}")' if subciv else ''))
    for key in sorted(set(van) | set(mg) | set(added)):
        rows = [('vanilla', e) for e in van.get(key, [])]
        rows += [('mod', e) for e in mg.get(key, [])]
        rows += [('CommandAdd', e) for e in added.get(key, [])]
        if subciv:
            rows = [r for r in rows if subciv in r[1].lower()]
        if not rows:
            continue
        print(f'  p{key[0]} c{key[1]}')
        for src, e in rows:
            print(f'      {src:<11} {e}')
    return 0


# --------------------------------------------------------------------- plan
def cmd_plan(args):
    cmds, abil, powers, techs = (vanilla('commands'), vanilla('abilities'),
                                 vanilla('powers'), vanilla('techs'))
    cblk = block(cmds, 'protounitcommand', args.command)
    if not cblk:
        sys.exit(f'{args.command} is not a vanilla protounitcommand')

    power = child(cblk, 'associatedpower')
    tech = child(cblk, 'associatedtech')
    subciv = child(cblk, 'subciv') or ''
    icon = child(cblk, 'icon') or ''
    owner, ablk = ability_entry(abil, power)
    pblk = block(powers, 'power', power)
    tblk = block(techs, 'tech', tech) if tech else None

    pre = args.prefix
    new_cmd = f'{pre}{strip_prefix(args.command)}Small'
    new_tech = f'{pre}{strip_prefix(tech)}' if tech else None
    new_power = f'{pre}{strip_prefix(power)}'
    gate = args.gate or f'{pre}{subciv or "X"}Ability'
    gate_big, gate_small = gate + 'Big', gate + 'Small'

    # who flips the vanilla associatedtech on -- the button is dead without this
    activators = [m.group(1) for m in re.finditer(
        r'<tech name="([^"]+)" type="[^"]*">(?:(?!</tech>).)*?'
        r'<effect type="TechStatus" status="active">%s</effect>' % re.escape(tech or '\0'),
        techs, re.S)] if tech else []
    enablers = [m.group(1) for m in re.finditer(
        r'<tech name="([^"]+)" type="[^"]*">(?:(?!</tech>).)*?'
        r'<effect type="TechStatus" status="obtainable">%s</effect>' % re.escape(tech or '\0'),
        techs, re.S)] if tech else []
    gate_tech = child(ablk, 'tech') if ablk else None

    print(f'# {args.command}  ->  {new_cmd}')
    print(f'#   subciv {subciv}   power {power}   tech {tech}')
    print(f'#   ability lives under <{owner}> in abilities.xml, gated on <tech>{gate_tech}</tech>')
    print(f'#   size flags present: '
          f'ability={ABILITY_FLAG in (ablk or "")}, '
          f'command={COMMAND_FLAG in cblk}, '
          f'tech={TECH_FLAG in (tblk or "")}')
    print(f'#   {tech} is activated by: {activators or "NOTHING FOUND -- check by hand"}')
    print(f'#   {tech} made obtainable by: {enablers or "(nothing; it is set active directly)"}')
    print()

    print('# ---- data/abilities/powermods.xml  (clone, same string ids)')
    print('  ' + rename_block(pblk, power, new_power) if pblk
          else '#   !! vanilla power not found')
    print()

    print('# ---- data/abilities/abilitymods.xml  '
          f'(inside <{owner}>; repoint the vanilla gate, add the small twin)')
    if ablk:
        # abilitymods writes these one per line with no inner whitespace; collapse
        # vanilla's pretty-printing rather than carrying it over
        one = re.sub(r'>\s+<', '><', ' '.join(ablk.split()))
        big = re.sub(r'<tech>[^<]*</tech>', f'<tech>{gate_big}</tech>', one, count=1)
        big = big.replace('<ability>', '<ability mergemode="replace">', 1)
        small = re.sub(r'<tech>[^<]*</tech>', f'<tech>{gate_small}</tech>', one, count=1)
        small = re.sub(r'<%s>[^<]*</%s>' % (ABILITY_FLAG, ABILITY_FLAG), '', small)
        small = small.replace(power, new_power, 1)
        print('    ' + big)
        print('    ' + small)
    else:
        print('#   !! vanilla ability entry not found')
    print()

    print('# ---- data/protounitcommandmods.xml  '
          f'(vanilla shape minus <{COMMAND_FLAG} />)')
    print(f'''  <protounitcommand>
    <name>{new_cmd}</name>
    <icon>{icon}</icon>
    <associatedtech>{new_tech}</associatedtech>
    <associatedpower>{new_power}</associatedpower>
    <castpower>
    </castpower>
    <subciv>{subciv}</subciv>
    <usemultiple>
    </usemultiple>
  </protounitcommand>''')
    print()

    print('# ---- data/techtreemods.xml  (gates + associatedtech clone; assign real dbids)')
    prereq = gate_tech or 'Colonialize'
    print(f'''  <tech name="{gate_big}" type="Normal">
    <dbid>DBID</dbid>
    <researchpoints>0.0000</researchpoints>
    <status>OBTAINABLE</status>
    <flag>Shadow</flag>
    <prereqs>
      <techstatus status="active">{prereq}</techstatus>
    </prereqs>
  </tech>
  <tech name="{gate_small}" type="Normal">
    <dbid>DBID</dbid>
    <researchpoints>0.0000</researchpoints>
    <status>UNOBTAINABLE</status>
    <flag>Shadow</flag>
    <prereqs>
      <techstatus status="active">{prereq}</techstatus>
    </prereqs>
  </tech>''')
    if tblk:
        clone = rename_block(tblk, tech, new_tech)
        clone = re.sub(r'[ \t]*<flag>%s</flag>\n' % TECH_FLAG, '', clone)
        clone = re.sub(r'<dbid>\d+</dbid>', '<dbid>DBID</dbid>', clone)
        print('  ' + clone)
    print()

    print('# ---- data/techtreemods.xml  (overrides so the clone actually switches on)')
    for t in enablers:
        print(f'''  <tech name="{t}">
    <effects>
      <effect mergemode="add" type="TechStatus" status="obtainable">{new_tech}</effect>
    </effects>
  </tech>''')
    for t in activators:
        print(f'''  <tech name="{t}">
    <effects>
      <effect mergemode="add" type="TechStatus" status="active">{new_tech}</effect>
    </effects>
  </tech>''')
    print()

    print('# ---- effects for the extension shadow tech (put it near the TOP of the file)')
    print(f'''      <effect type="CommandRemove" command="{args.command}">
        <target type="ProtoUnit">{args.unit}</target>
      </effect>
      <effect type="CommandAdd" command="{new_cmd}" page="{args.page}" column="{args.column}">
        <target type="ProtoUnit">{args.unit}</target>
      </effect>
      <effect type="TechStatus" status="unobtainable">{gate_big}</effect>
      <effect type="TechStatus" status="obtainable">{gate_small}</effect>''')
    if tblk and re.search(r'<%s>%s</%s>' % ('tech', re.escape(tech), 'tech'), ''):
        pass
    van_grid = grid(vanilla('protos'), args.unit)
    here = [k for k, v in van_grid.items() if any(args.command in e for e in v)]
    if here:
        print(f'\n#   vanilla places it at p{here[0][0]} c{here[0][1]}'
              f'{" as a tech entry too -- CommandRemove/Add tech= as well" if any("tech:" in e for e in van_grid[here[0]] if args.command in e) else ""}')
    return 0


def strip_prefix(name):
    return re.sub(r'^(?:de|DE|yp|xp)', '', name or '')


def rename_block(blk, old, new):
    return re.sub(r'(name\s*=\s*")%s(")' % re.escape(old), r'\g<1>%s\g<2>' % new, blk, count=1)


# ------------------------------------------------------------------- verify
def cmd_verify(args):
    root = args.root
    mcmd, mabil, mpow, mtech = (mod('commands', root), mod('abilities', root),
                                mod('powers', root), mod('techs', root))
    bad = 0

    smalls = re.findall(r'<name>(\w*Small)</name>', mcmd)
    smalls = [s for s in smalls if not args.prefix or s.startswith(args.prefix)]
    if not smalls:
        print('no *Small protounitcommands in the mod')
    for name in smalls:
        blk = block(mcmd, 'protounitcommand', name)
        power = child(blk, 'associatedpower')
        tech = child(blk, 'associatedtech')
        print(f'{name}')
        checks = []
        checks.append((COMMAND_FLAG not in blk, f'command has no <{COMMAND_FLAG}>'))
        pblk = block(mpow, 'power', power) if power else None
        checks.append((bool(pblk), f'power {power} defined in powermods'))
        _, ablk = ability_entry(mabil, power) if power else (None, None)
        checks.append((bool(ablk), f'ability {power} present in abilitymods'))
        if ablk:
            checks.append((ABILITY_FLAG not in ablk, f'ability has no <{ABILITY_FLAG}>'))
        tblk = block(mtech, 'tech', tech) if tech else None
        checks.append((bool(tblk), f'tech {tech} defined in techtreemods'))
        if tblk:
            checks.append((TECH_FLAG not in tblk, f'tech has no <flag>{TECH_FLAG}</flag>'))
            act = re.search(r'status="active">%s</effect>' % re.escape(tech), mtech)
            checks.append((bool(act), f'something sets {tech} active'))
        gate = child(ablk, 'tech') if ablk else None
        if gate:
            # A vanilla gate (Colonialize and friends) is already defined and
            # already reachable -- only a mod-authored gate has to be declared
            # and switched on by the mod.
            if block(vanilla('techs'), 'tech', gate):
                checks.append((True, f'gate tech {gate} is vanilla'))
            else:
                checks.append((bool(block(mtech, 'tech', gate)),
                               f'gate tech {gate} defined'))
                checks.append((bool(re.search(
                    r'status="obtainable">%s</effect>' % re.escape(gate), mtech)),
                    f'something makes {gate} obtainable'))
        for ok, msg in checks:
            print(f'    {"ok  " if ok else "FAIL"} {msg}')
            bad += not ok

    stray = len(re.findall(r'mergeMode="', mtech))
    print(f'\nmergeMode="" (capital M) occurrences in techtreemods: {stray}'
          f'{"   <-- repo convention is lowercase mergemode" if stray else ""}')

    print('\ncompiled .xmb freshness')
    for key in ('commands', 'abilities', 'powers', 'techs'):
        src = os.path.join(root, MOD[key].replace('/', os.sep))
        xmb = src + '.xmb'
        if not os.path.exists(src):
            continue
        if not os.path.exists(xmb):
            print(f'    ok   {MOD[key]}  (no .xmb; engine compiles from source)')
            continue
        fresh = os.path.getmtime(xmb) >= os.path.getmtime(src)
        print(f'    {"ok  " if fresh else "STALE"} {MOD[key]}.xmb')
        bad += not fresh
    return 1 if bad else 0


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--root', default='.', help='mod repo root (default: cwd)')
    sub = ap.add_subparsers(dest='cmd', required=True)

    p = sub.add_parser('find', help='native ability commands in vanilla')
    p.add_argument('pattern', nargs='?')
    p.add_argument('--big-only', action='store_true',
                   help='only those still using a big/medium button')
    p.set_defaults(fn=cmd_find)

    p = sub.add_parser('slots', help='button grid for a proto')
    p.add_argument('subciv', nargs='?')
    p.add_argument('--unit', default='TradingPost')
    p.set_defaults(fn=cmd_slots)

    p = sub.add_parser('plan', help='emit the blocks for a small variant')
    p.add_argument('command', help='vanilla protounitcommand name')
    p.add_argument('--prefix', default='zp')
    p.add_argument('--gate', help='gate tech base name (default zp<Subciv>Ability)')
    p.add_argument('--unit', default='TradingPost')
    p.add_argument('--page', default='0')
    p.add_argument('--column', default='4')
    p.set_defaults(fn=cmd_plan)

    p = sub.add_parser('verify', help='audit the mod chains')
    p.add_argument('prefix', nargs='?', default='')
    p.set_defaults(fn=cmd_verify)

    args = ap.parse_args(argv)
    return args.fn(args)


if __name__ == '__main__':
    sys.exit(main())
