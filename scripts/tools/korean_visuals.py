#!/usr/bin/env python
"""Build the Korean building visuals into the vanilla Barracks and Stable animfiles (Town Center: see BUILDINGS).

Koreans (civ zpKoreans) use the vanilla protos ypBarracksJapanese and ypStableJapanese (and TownCenter), so
every tech, card, AI rule and trigger that names them keeps working; only the look differs. Animfiles
cannot be patched partially, so the mod ships a full copy of each vanilla animfile with:

  * the Korean model's <definebone> lines that vanilla lacks (after the last vanilla one);
  * the Korean model's <submodel> blocks (after the last vanilla submodel);
  * one more child of the Japanese "Tech" logic, <zpkoreanvisuals>, holding the Korean
    BuildingCompletion logic. It is the LAST child, so it wins over colonialize/industrialize
    while the owner has the tech - the vanilla pattern of <dehciturbidepalace> in the
    Mediterranean branch of town_center.xml and of the mod's <zpazteccitydefendersetup> in dock.xml.

zpKoreanVisuals is activated only by zpAge0Korean (data/techtreemods.xml), so Japanese buildings stay
Japanese. Every vanilla byte is kept: --check rebuilds the files from the installed game and
fails if the committed copies differ (run it after a DE patch; without --check the files are rewritten).

    python scripts/tools/korean_visuals.py            # (re)write the animfiles
    python scripts/tools/korean_visuals.py --check    # verify them against the installed game
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
# Korean Town Center: ready, but OFF until `gr2_lint.py --profile korean_tc art/buildings/korean_tc` exits 0
# (AGENTS.md rule 13; 2026-10-08: 6 FAIL - texture budget, texel density, UV lineage). To switch it on, add
#   ('Art/buildings/town_center/town_center.xml.XMB', 'art/buildings/town_center/town_center.xml',
#    'art/buildings/korean_tc/korean_tc.xml', 'japanese', False),
# Overriding town_center.xml touches every civ's Town Center; --check keeps its vanilla bytes honest.
BUILDINGS = [
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
    # 3. the marker branch, last child of the culture's Tech logic
    t0, t1 = tech_logic_span(out, culture)
    close = out.rindex('</logic>', t0, t1)
    line0 = out.rindex('\n', 0, close) + 1
    ind = out[line0:close]                       # indentation of the Tech logic's closing tag
    body = '\n'.join((ind + '    ' + l[4:]) if l.startswith('    ') else (ind + '    ' + l)
                     for l in completion.split('\n'))
    branch = '%s  <%s>\n%s\n%s  </%s>\n' % (ind, MARKER, body, ind, MARKER)
    out = out[:line0] + branch + out[line0:]
    return out


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
            return kids
    raise AssertionError('no %s branch' % culture)


def main():
    check = '--check' in sys.argv
    bad = 0
    for archive, out_path, src, culture, attack in BUILDINGS:
        merged = merge(vanilla_text(archive), read(src), culture, attack)
        kids = verify(merged, culture)
        data = merged.replace('\n', '\r\n').encode('utf-8')
        full = os.path.join(ROOT, out_path)
        if check:
            same = os.path.exists(full) and open(full, 'rb').read().replace(b'\r\n', b'\n') == data.replace(b'\r\n', b'\n')
            print('%-50s %s  Tech children %s' % (out_path, 'OK' if same else 'DIFFERS', kids))
            bad += not same
        else:
            os.makedirs(os.path.dirname(full), exist_ok=True)
            open(full, 'wb').write(data)
            print('wrote %-50s Tech children %s' % (out_path, kids))
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
