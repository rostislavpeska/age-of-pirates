#!/usr/bin/env python
"""Which clips drive which skeleton (read-only): animation track names against donor skeletons, by the engine's rule
(tracks bind by bone name; a space equals an underscore; case-insensitive).

    python track_coverage.py --animfile Art/units/asians/chinese/iron_flail/iron_flail_rider.xml \
           --donor Art/units/asians/chinese/iron_flail/iron_rider_0.gr2 Art/units/asians/japanese/yabusame/yabusamerider_0.gr2
    python track_coverage.py --clips Art/animation_library/cavalry/oprichnik_attack_A.gr2 [...] --donor FILE.gr2 [...]

--animfile collects every GrannyAnim the animfile (plain XML or the archive's XMB) references; --donor and --clips
take archive paths or files on disk. Per donor: clips whose every track finds a bone, the union of tracks without a
bone (those motions are lost, e.g. a flail chain), bones no clip keys (they keep their rest local), and whether the
clips key the root (then the donor's rest root height does not move the posed body). Archive copies go to a temp
folder. Backs the donor choice in rider-skeleton.md, section 8.
"""
import argparse
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import unit_gr2 as U  # noqa: E402


def local_or_archive(items, extract_to=None):
    out = []
    for it in items:
        p = Path(it)
        out.append(p if p.is_file() else U.fetch([it], extract_to)[0])
    return out


def animfile_clips(rel, extract_to=None):
    bt, idx = U.game_index()
    key = rel.replace(chr(92), '/').lower()
    e = next((idx.get(k) for k in (key, key + '.xmb', 'art/' + key, 'art/' + key + '.xmb') if idx.get(k)), None)
    if e is None:
        p = Path(rel)
        if not p.is_file():
            raise SystemExit('animfile not found: %s' % rel)
        raw = p.read_bytes()
    else:
        raw = bt.read_entry(e)
    raw = bt.unwrap_alz4(raw)
    txt = bt.xmb_to_xml(raw) if bt.is_xmb(raw) else raw.decode('utf-8-sig', 'replace')
    files = []
    for ar in ET.fromstring(txt).iter('assetreference'):
        if (ar.get('type') or '').lower() == 'grannyanim':
            for f in ar.iter('file'):
                name = 'Art/' + f.text.strip().replace(chr(92), '/') + '.gr2'
                if name.lower() not in [x.lower() for x in files]:
                    files.append(name)
    return files


def tracks(path):
    """[(clip name, trackgroup, [(track name, rotation keyed, position keyed)])]"""
    from gr2_dump import curve_info
    m = U.Gr2(str(path))
    r = m.root()
    out = []
    for an, _ in U.refs(m, r.get('Animations')):
        for tg, _ in U.refs(m, an.get('TrackGroups')):
            tt = m.array(tg['TransformTracks']) if tg.get('TransformTracks') else []
            out.append((Path(path).stem, tg['Name'], [(t['Name'], 'Identity' not in curve_info(m, t['OrientationCurve']),
                                                       'Identity' not in curve_info(m, t['PositionCurve'])) for t in tt]))
    return out


def coverage(donor, clips):
    bones = [b['name'] for b in donor.skeleton]
    bn = {U.nm(b): b for b in bones}
    root = U.nm(bones[0]) if bones else None
    full, orphans, keyed, root_keyed = [], {}, set(), []
    for name, tg, tt in clips:
        miss = [t for t, _, _ in tt if U.nm(t) not in bn]
        keyed |= {U.nm(t) for t, _, _ in tt}
        for t in miss:
            orphans.setdefault(t, []).append(name)
        if not miss:
            full.append(name)
        rk = [(t, r_, p_) for t, r_, p_ in tt if U.nm(t) == root]
        if rk:
            root_keyed.append((name, rk[0][1], rk[0][2]))
    return dict(bones=len(bones), clips=len(clips), fully_covered=len(full), orphan_tracks=orphans,
                unkeyed_bones=[bn[b] for b in bn if b not in keyed], root_track=root_keyed)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('--animfile')
    ap.add_argument('--clips', nargs='*', default=[])
    ap.add_argument('--donor', nargs='+', required=True)
    ap.add_argument('--extract-to')
    a = ap.parse_args(argv)
    clip_paths = list(a.clips)
    if a.animfile:
        clip_paths += animfile_clips(a.animfile, a.extract_to)
    if not clip_paths:
        raise SystemExit('no clips: pass --animfile or --clips')
    clips = []
    for p in local_or_archive(clip_paths, a.extract_to):
        try:
            clips += tracks(p)
        except NotImplementedError as e:
            print('CLIP %s: UNREADABLE %s' % (p.stem, e))
    print('CLIPS %d: %s' % (len(clips), ' '.join(c[0] for c in clips)))
    res = {}
    for p in local_or_archive(a.donor, a.extract_to):
        d = U.Model(p)
        r = res[d.name] = coverage(d, clips)
        print('== %s: %d bones; %d of %d clips find a bone for every track' % (d.name, r['bones'], r['fully_covered'],
                                                                                r['clips']))
        for t, names in sorted(r['orphan_tracks'].items()):
            print('   track without a bone: %-18s in %d clips' % (t, len(names)))
        print('   bones no clip keys: %s' % (r['unkeyed_bones'] or 'none'))
        rk = r['root_track']
        print('   root track in %d of %d clips (rotation keyed in %d, position keyed in %d)' % (
            len(rk), r['clips'], sum(1 for x in rk if x[1]), sum(1 for x in rk if x[2])))
    return res


if __name__ == '__main__':
    main()
