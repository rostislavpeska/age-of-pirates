"""check_state.py - prove a player-colour candidate changed only what it may, against the base state it was built on.

    python check_state.py --base <base maps dir> --cand <candidate maps dir> [--glob "*.png"]
           [--faces faces.json --select ids|@ids.json --page P2048] [--report r.json]

PASS requires:
  1. every map except <page>_Details and <page>_BaseColor is BYTE-identical to the base (else its differing texels are
     counted and it FAILS - Normal, Masks, Roughness ... never move in player-colour work);
  2. <page>_BaseColor differs from the base only at texels where the candidate's <page>_Details.R > 0 (the scoped
     lighten); a changed texel outside the mask FAILS;
  3. a <page>_Details map exists in either state (new, changed or unchanged; R-only expected: G / B > 0 is reported);
  4. with --faces/--select: no texel-sharing leak - every UNSELECTED face whose centre texels carry mean Details.R > 0.5
     FAILS (it would turn player-coloured); 0 < R <= 0.5 is the soft edge on a shared chart boundary (reported);
     a selected face with mean R < 0.5 is reported as under-painted.
Exit 1 on FAIL. Compare maps by texels, never by the image viewer; the base is the state the owner sees (HEAD).
"""
import argparse
import json
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import pc_common as C  # noqa: E402
import details_mask as DM  # noqa: E402


def load_any(p):
    """decode any bit depth (OpenCV when available, else Pillow)"""
    try:
        import cv2
        a = cv2.imdecode(np.fromfile(str(p), np.uint8), cv2.IMREAD_UNCHANGED)
        if a is not None:
            return a
    except ImportError:
        pass
    from PIL import Image
    return np.asarray(Image.open(p))


def texels_differ(a, b):
    x, y = load_any(a), load_any(b)
    if x.shape != y.shape:
        return -1
    d = x != y
    return int((d.any(-1) if d.ndim == 3 else d).sum())


def check(base, cand, pattern='*.png', faces=None, select=None, page=None):
    base, cand = Path(base), Path(cand)
    names = sorted({p.name for p in base.glob(pattern)} | {p.name for p in cand.glob(pattern)})
    dets = [n for n in names if n.lower().endswith('_details.png')]
    pages = [n[:-len('_Details.png')] for n in dets]
    rep = dict(base=str(base), cand=str(cand), maps={}, fails=[], notes=[])
    for n in names:
        a, b = base / n, cand / n
        if not b.exists():
            rep['maps'][n] = 'missing in candidate'; rep['fails'].append(f'{n} missing in the candidate'); continue
        if not a.exists():
            rep['maps'][n] = 'new'
            if n not in dets:
                rep['fails'].append(f'{n} is new and is not a Details map')
            continue
        same = C.sha_file(a) == C.sha_file(b)
        if same:
            rep['maps'][n] = 'byte-identical'; continue
        diff = texels_differ(a, b)
        rep['maps'][n] = f'{diff} texels differ' if diff >= 0 else 'size differs'
        if n in dets:
            continue
        pg = next((p for p in pages if n == f'{p}_BaseColor.png'), None)
        if pg is None:
            rep['fails'].append(f'{n}: {rep["maps"][n]} (only Details and the masked BaseColor may change)'); continue
        x, y = C.read_rgb8(a), C.read_rgb8(b)
        r = C.read_details_r(cand / f'{pg}_Details.png')
        ch = (x != y).any(-1)
        out = int((ch & (r == 0)).sum())
        rep[f'{pg}_basecolor'] = dict(changed=int(ch.sum()), changed_outside_details=out, changed_inside=int((ch & (r > 0)).sum()))
        if out:
            rep['fails'].append(f'{n}: {out} texels changed outside the Details mask')
    if not dets:
        rep['fails'].append('no *_Details.png in either state')
    for n in dets:
        if (cand / n).exists():
            a = C.read_rgb8(cand / n)
            if a[..., 1:].max() > 0:
                rep['notes'].append(f'{n}: G/B not zero (max {int(a[..., 1:].max())}); only R is read, G is emissive in '
                                    f'default_emissive - check this is intended')
    if faces and select:
        size, fd = DM.load_faces(faces)
        pg = page or (pages[0] if pages else None)
        r = C.read_details_r(cand / f'{pg}_Details.png')
        size = size or r.shape[0]
        sel = set(select); leak, soft, under = [], [], []
        for k, f in fd.items():
            rr, cc = DM.raster(DM.uv_px(f['uv'], size), size)
            if not len(rr):
                continue
            mr = float(r[rr, cc].mean())
            if k in sel:
                if mr < 0.5:
                    under.append(dict(face=k, mean_R=round(mr, 3)))
            elif mr > 0.5:
                leak.append(dict(face=k, mean_R=round(mr, 3), seen_px=f.get('seen_px')))
            elif r[rr, cc].max() > 0:
                soft.append(dict(face=k, mean_R=round(mr, 3), max_R=round(float(r[rr, cc].max()), 3)))
        rep['leak_check'] = dict(page=pg, faces=len(fd), selected=len(sel), leaking=leak, soft_edge=soft, under_painted=under)
        if leak:
            rep['fails'].append(f'{len(leak)} unselected faces carry player colour (texel-sharing leak): '
                                f'{[x["face"] for x in leak[:10]]}')
    rep['verdict'] = 'FAIL' if rep['fails'] else 'PASS'
    return rep


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--base', required=True); ap.add_argument('--cand', required=True)
    ap.add_argument('--glob', default='*.png'); ap.add_argument('--faces'); ap.add_argument('--select')
    ap.add_argument('--page'); ap.add_argument('--report')
    a = ap.parse_args(argv)
    rep = check(a.base, a.cand, a.glob, a.faces, DM.parse_ids(a.select), a.page)
    if a.report:
        Path(a.report).write_text(json.dumps(rep, indent=1))
    for n, v in rep['maps'].items():
        print(f'  {n}: {v}')
    for k in [k for k in rep if k.endswith('_basecolor')]:
        print(' ', k, json.dumps(rep[k]))
    if 'leak_check' in rep:
        lc = rep['leak_check']
        print(f'  leak check {lc["page"]}: {len(lc["leaking"])} leaking, {len(lc["soft_edge"])} soft-edge, '
              f'{len(lc["under_painted"])} under-painted of {lc["faces"]} faces')
    for x in rep['notes']:
        print('  NOTE', x)
    print(rep['verdict'], *rep['fails'], sep='\n  ' if rep['fails'] else '')
    sys.exit(1 if rep['fails'] else 0)


if __name__ == '__main__':
    main()
