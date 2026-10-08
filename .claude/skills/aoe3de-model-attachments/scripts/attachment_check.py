"""Every attachment in an animfile must resolve to a real bone in every skeleton the engine may use for it.

    python attachment_check.py art/zbench_korean_military/stable/korean_stable_physics.xml [--art-root DIR] [--json out.json]

For each <attach a=".." tobone=".."> inside a <component>, the check finds every GrannyModel that component can
show (Destruction p1/p99, LowPoly normal/lowpoly ...) and the <simskeleton> model of every <anim> in the same
scope (<submodel> or file root) that plays that component. The tobone must exist in ALL of them: the engine
resolves it through the animated (simskeleton) skeleton, so a bone present only in the intact model drops the
attachment to the model origin with no rotation.
Policy (AoE Buildings construction rules): a construction-stage submodel (referenced from BuildingCompletion
below p100) must not carry bone_flag_civ / bone_garrisonflag - the engine hangs the player flag on them.
Archive (vanilla) models are reported as not checked. Exit 0 PASS, 1 FAIL.
Found 2026-10-08: the Korean stable horses both appeared at the stall-wing origin, sideways - bone_horse1/2 were
in the intact GR2 only while the LIVE Idle anim's simskeleton is the damaged GR2 (vanilla stables carry the horse
bones in both); the Korean construction models inherited bone_flag_civ from the donor skeleton.
"""
import argparse, json, re, sys
import xml.etree.ElementTree as ET
from pathlib import Path

REPO = Path(__file__).resolve().parents[4]   # .claude/skills/<skill>/scripts/<this>
sys.path.insert(0, str(REPO / 'scripts' / 'havok'))

FLAG_BONES = ('bone_flag_civ', 'bone_garrisonflag')


def bones(gr2):
    from gr2_read import Gr2
    g = Gr2(str(gr2))
    r = g.root(); _, _, sp, st = r['Skeletons']; sk = g.read(*st, *g.deref(sp[0], sp[1]))
    return [b['Name'] for b in g.array(sk['Bones'])]


def name_of(el):
    return (el.text or '').strip()


def resolve(ref, art_root):
    p = Path(art_root) / (ref.replace(chr(92), '/') + '.gr2')
    return p if p.exists() else None


def check(animfile, art_root=None, bones_of=bones):
    """bones_of(path) -> list of bone names; replaceable in tests."""
    art_root = Path(art_root) if art_root else REPO / 'art'
    root = ET.parse(animfile).getroot()
    parent = {c: p for p in root.iter() for c in p}
    findings, rows, cache = [], [], {}

    def skeleton(ref):
        p = resolve(ref, art_root)
        if p is None:
            return None
        if p not in cache:
            cache[p] = bones_of(p)
        return cache[p]

    def scope_of(el):
        while el is not None and el.tag != 'submodel':
            el = parent.get(el)
        return el if el is not None else root

    for att in root.iter('attach'):
        comp = att
        while comp is not None and comp.tag != 'component':
            comp = parent.get(comp)
        if comp is None:                                   # anim-level attach (e.g. Death smoke at ATTACHPOINT)
            continue
        scope = scope_of(comp); cname = name_of(comp); tobone = att.get('tobone')
        models = [f.text.strip() for ar in comp.iter('assetreference') if ar.get('type') == 'GrannyModel' for f in ar.iter('file')]
        sims = [m.text.strip() for an in scope.findall('anim') if any(name_of(c) == cname for c in an.findall('component'))
                for s in an.findall('simskeleton') for m in s.findall('model')]
        for ref, role in [(m, 'model') for m in models] + [(s, 'simskeleton') for s in sims]:
            names = skeleton(ref)
            row = dict(attach=att.get('a'), tobone=tobone, component=cname,
                       submodel=name_of(scope) if scope is not root else None, ref=ref, role=role)
            if names is None:
                row['status'] = 'NOT CHECKED (archive model)'
            elif tobone in names:
                row['status'] = 'OK'
            else:
                row['status'] = 'FAIL'
                findings.append(f"attach '{att.get('a')}' -> {tobone}: missing in {role} {ref} (component {cname}); "
                                f"the engine drops it to the model origin with no rotation")
            rows.append(row)
    stages = {}
    for bc in root.iter('logic'):
        if bc.get('type') != 'BuildingCompletion':
            continue
        for p in bc:
            m = re.fullmatch(r'p(\d+)', p.tag)
            if m and int(m.group(1)) < 100:
                for ref in p.iter('submodelref'):
                    stages[ref.get('ref')] = int(m.group(1))
    for sm in root.iter('submodel'):
        if name_of(sm) not in stages:
            continue
        for ar in sm.iter('assetreference'):
            if ar.get('type') != 'GrannyModel':
                continue
            for f in ar.iter('file'):
                names = skeleton(f.text.strip())
                bad = [b for b in (names or []) if b in FLAG_BONES]
                rows.append(dict(construction_stage=name_of(sm), p=stages[name_of(sm)], ref=f.text.strip(), flag_bones=bad,
                                 status='NOT CHECKED (archive model)' if names is None else ('FAIL' if bad else 'OK')))
                if bad:
                    findings.append(f"construction stage {name_of(sm)} (p{stages[name_of(sm)]}) model {f.text.strip()} carries {bad}: "
                                    f"the engine hangs the player flag there")
    return dict(animfile=str(animfile), status='FAIL' if findings else 'PASS', findings=findings, rows=rows)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('animfile'); ap.add_argument('--json')
    ap.add_argument('--art-root', help="folder that holds the art tree (default: this repo's art/)")
    a = ap.parse_args()
    rep = check(Path(a.animfile), a.art_root)
    if a.json:
        Path(a.json).write_text(json.dumps(rep, indent=2))
    ok = sum(r['status'] == 'OK' for r in rep['rows'])
    print(f"{rep['status']:5} {Path(a.animfile).name}: {ok} bone checks OK, {len(rep['findings'])} finding(s)")
    for f in rep['findings']:
        print('   FAIL', f)
    sys.exit(0 if rep['status'] == 'PASS' else 1)


if __name__ == '__main__':
    main()
