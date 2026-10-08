#!/usr/bin/env python
"""Build the Korean building visuals into the vanilla Town Center, Barracks and Stable animfiles.

Koreans (civ zpKoreans) use the vanilla protos ypBarracksJapanese and ypStableJapanese (and TownCenter), so
every tech, card, AI rule and trigger that names them keeps working; only the look differs. Animfiles
cannot be patched partially, so the mod ships a full copy of each vanilla animfile with:

  * the Korean model's <definebone> lines that vanilla lacks (after the last vanilla one);
  * the Korean model's <submodel> blocks (after the last vanilla submodel);
  * one more child of the Japanese "Tech" logic, <zpkoreanvisuals>. It is the LAST child, so it wins
    over colonialize/industrialize while the owner has the tech - the vanilla pattern of
    <dehciturbidepalace> in the Mediterranean branch of town_center.xml and of the mod's
    <zpazteccitydefendersetup> in dock.xml. Inside it a nested age switch: <none> = the vanilla
    Discovery Age look (generic Asian, as Japan), <colonialize> = the Korean model from the first
    upgrade (Colonial Age) on.

zpKoreanVisuals is activated only by zpAge0Korean (koreans/data/techtreemods.xml), so Japanese buildings
stay Japanese. Every byte of the base file is kept (the base is AoP's own override of that animfile when AoP has
one, else vanilla from the installed game). The files are generated into the Koreans add-on by
scripts/tools/export_koreans.py; they are never edited by hand and never live in AoP's art/ (they would replace
every civ's Town Center for AoP players without the add-on).

    python scripts/tools/korean_visuals.py            # summary of what the export would generate
"""
import os
import re
import subprocess
import sys
import xml.etree.ElementTree as ET

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
BARTOOL = os.path.join(ROOT, '.claude', 'skills', 'aoe3de-bar-archives', 'scripts', 'bartool.py')
BS = chr(92)

# (vanilla archive animfile, mod output, Korean source animfile, culture branch, add attack anims)
# Korean Town Center: ON by the owner's go of 2026-10-08 ("So GO with the Town center modification") while
# `gr2_lint.py --profile korean_tc art/buildings/korean_tc` still FAILs 6 checks (texture budget, texel density,
# UV lineage - the open texturing work, AGENTS.md rule 13). Overriding town_center.xml touches every civ's Town
# Center; --check keeps its vanilla bytes honest.
BUILDINGS = [
    ('Art/buildings/town_center/town_center.xml.XMB', 'art/buildings/town_center/town_center.xml',
     'art/buildings/korean_tc/korean_tc.xml', 'japanese', False),
    ('Art/buildings/asian_civs/bansho/bansho.xml.XMB', 'art/buildings/asian_civs/bansho/bansho.xml',
     'art/zbench_korean_military/barracks/korean_barracks_physics.xml', 'japanese', True),
    ('Art/buildings/asian_civs/stable/stable.xml.XMB', 'art/buildings/asian_civs/stable/stable.xml',
     'art/zbench_korean_military/stable/korean_stable_physics.xml', 'japanese', False),
]

MARKER = 'zpkoreanvisuals'

# The vanilla barracks fires from its RangedAttack/RangedAttackShip anims (barracks.tactics); the Korean
# bench animfile has none, so the merged copy adds them to the Korean built submodel (vanilla bansho text,
# simskeleton = the Korean damaged model, as in art/buildings/korean_tc/korean_tc.xml).
ATTACK_ANIMS = '''    <anim>RangedAttack<assetreference type="GrannyAnim">
        <file>animation_library{bs}building{bs}ranged_attack</file>
        <tag type="Attack">0.45</tag>
        <tag type="SpecificSoundSet" checkvisible="1" set="RifleShot">0.45</tag>
      </assetreference>
      <component>LIVE</component>
      <simskeleton>
        <model>{damaged}</model>
      </simskeleton>
    </anim>
    <anim>RangedAttackShip<assetreference type="GrannyAnim">
        <file>animation_library{bs}building{bs}ranged_attack</file>
        <tag type="Attack">0.45</tag>
        <tag type="SpecificSoundSet" checkvisible="1" set="RifleShot">0.45</tag>
      </assetreference>
      <component>LIVE</component>
      <simskeleton>
        <model>{damaged}</model>
      </simskeleton>
    </anim>
'''


def vanilla_text(archive_path):
    out = subprocess.run([sys.executable, BARTOOL, 'cat', archive_path], capture_output=True, check=True)
    return out.stdout.decode('utf-8-sig').replace('\r\n', '\n')


def read(path):
    return open(os.path.join(ROOT, path), 'rb').read().decode('utf-8-sig').replace('\r\n', '\n')


def korean_parts(text, add_attack):
    bones = re.findall(r'<definebone>([^<]+)</definebone>', text)
    subs = re.findall(r'(  <submodel>.*?</submodel>\n)', text, re.S)
    assert subs, 'no submodels'
    m = re.search(r'\n  <component>[^<]*(<logic type="BuildingCompletion">.*?\n    </logic>)\n  </component>\n</animfile>',
                  text, re.S)
    assert m, 'no top-level BuildingCompletion component'
    completion = m.group(1)
    if add_attack:
        built = [i for i, s in enumerate(subs) if re.match(r'  <submodel>\w+_built\b', s)]
        assert len(built) == 1, built
        s = subs[built[0]]
        assert '<anim>RangedAttack' not in s
        dmg = re.search(r'<simskeleton>\s*<model>([^<]+)</model>', s).group(1)
        i = s.rindex('  </submodel>')
        subs[built[0]] = s[:i] + ATTACK_ANIMS.format(bs=BS, damaged=dmg) + s[i:]
    return bones, subs, completion


def tech_logic_span(text, culture):
    """(start, end) of the <logic type="Tech"> block directly inside <culture> of the Culture logic."""
    c0 = text.index('<%s>' % culture)
    c1 = text.index('</%s>' % culture, c0)
    t0 = text.index('<logic type="Tech">', c0)
    assert t0 < c1
    depth, pos = 0, t0
    for m in re.finditer(r'<logic\b|</logic>', text[t0:c1]):
        depth += 1 if m.group(0) == '<logic' else -1
        if depth == 0:
            return t0, t0 + m.end()
    raise ValueError('unbalanced Tech logic in <%s>' % culture)


def merge(vanilla, korean_text, culture, add_attack):
    bones, subs, completion = korean_parts(korean_text, add_attack)
    have = {b.lower() for b in re.findall(r'<definebone>([^<]+)</definebone>', vanilla)}
    vsubs = {s.lower() for s in re.findall(r'<submodel>([^<\s]+)', vanilla)}
    for s in subs:
        name = re.match(r'  <submodel>([^<\s]+)', s).group(1)
        assert name.lower() not in vsubs, 'submodel name collides with vanilla: ' + name
    out = vanilla
    # 1. bones vanilla lacks, after the last vanilla definebone
    new_bones, seen = [], set()
    for b in bones:
        if b.lower() not in have and b.lower() not in seen:
            seen.add(b.lower()); new_bones.append('  <definebone>%s</definebone>\n' % b)
    if new_bones:
        last = out.rindex('</definebone>\n') + len('</definebone>\n')
        out = out[:last] + ''.join(new_bones) + out[last:]
    # 2. Korean submodels after the last vanilla submodel
    last = out.rindex('</submodel>\n') + len('</submodel>\n')
    out = out[:last] + ''.join(subs) + out[last:]
    # 3. the marker branch, last child of the culture's Tech logic. Inside it a nested age switch (owner
    #    2026-10-08: "Age0 is generic asian (same as Japan) and age1 and age2 (1st upgrade is the new one"):
    #      <none>         the vanilla Discovery Age branch, verbatim
    #      <colonialize>  the Korean model - from the first upgrade on; colonialize stays active, so it holds
    #                     through Industrial/Imperial too (one Korean model so far)
    t0, t1 = tech_logic_span(out, culture)
    close = out.rindex('</logic>', t0, t1)
    line0 = out.rindex('\n', 0, close) + 1
    ind = out[line0:close]                       # indentation of the Tech logic's closing tag
    none = re.search(r'\n(%s  <none>\n.*?\n%s  </none>)\n' % (ind, ind), out[t0:t1], re.S)
    korean = '\n'.join((ind + '        ' + l[4:]) if l.startswith('    ') else (ind + '        ' + l)
                       for l in completion.split('\n'))
    parts = ['%s  <%s>' % (ind, MARKER), '%s    <logic type="Tech">' % ind]
    if none:                                     # the vanilla stable has no <none> branch
        parts.append('\n'.join('    ' + l for l in none.group(1).split('\n')))
    parts += ['%s      <colonialize>' % ind, korean, '%s      </colonialize>' % ind,
              '%s    </logic>' % ind, '%s  </%s>' % (ind, MARKER)]
    out = out[:line0] + '\n'.join(parts) + '\n' + out[line0:]
    return out


def canon(e):
    return (e.tag, sorted(e.attrib.items()), (e.text or '').strip(), [canon(c) for c in e])


def verify(text, culture):
    root = ET.fromstring(text)
    # case-insensitive: vanilla town_center.xml itself refers to lak_sub_construction_stage_02 in another case
    names = {(s.text or '').strip().lower() for s in root.iter('submodel')}
    refs = {r.get('ref').lower() for r in root.iter('submodelref')}
    missing = refs - names
    assert not missing, 'unresolved submodelref: %s' % sorted(missing)
    for comp in root.findall('component'):
        for lg in comp.findall('logic'):
            br = lg.find(culture)
            if br is None:
                continue
            tech = br.find('logic')
            kids = [c.tag for c in tech]
            assert kids[-1] == MARKER, kids
            inner = tech.find(MARKER).find('logic')
            assert inner.get('type') == 'Tech'
            ages = [c.tag for c in inner]
            assert ages[-1] == 'colonialize' and ages[:-1] in ([], ['none']), ages
            if 'none' in kids:   # the Discovery Age branch is a copy of vanilla's (indentation aside)
                assert canon(inner.find('none')) == canon(tech.find('none'))
            return kids + ['/'.join(ages)]
    raise AssertionError('no %s branch' % culture)


def build(aop_root=ROOT):
    """{add-on relative path: CRLF bytes} for every Korean building animfile."""
    out = {}
    for archive, out_path, src, culture, attack in BUILDINGS:
        own = os.path.join(aop_root, out_path)
        base = read(out_path) if os.path.isfile(own) else vanilla_text(archive)
        merged = merge(base, read(src), culture, attack)
        out[out_path] = (merged.replace('\n', '\r\n').encode('utf-8'), verify(merged, culture),
                         'AoP override' if os.path.isfile(own) else 'vanilla')
    return out


def main():
    for path, (data, kids, base) in build().items():
        print('%-50s base %-12s %7d bytes  Tech children %s' % (path, base, len(data), kids))
    return 0


if __name__ == '__main__':
    sys.exit(main())
