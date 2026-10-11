"""Derive a GAME profile from a survey of that game's shipped units (survey.py output): the game-scale numbers the
generic profile leaves as REPORT - triangle budget (D1), head-first budget (F5), region shares (D2), hand share (X1),
limb ring sides (D3) - as [p_lo, p_hi] ranges over the units. The profile belongs to the consuming game's layer, never
to this package; triangle meshes surveyed through Tris to Quads give budgets and shares, not quad-quality thresholds.

    python -I profile_from_survey.py <survey dir> --name aoe3_vanilla --out profile.json [--lo 10 --hi 90]
                                     [--role vanilla]
"""
import argparse
import json
import os
import sys

import numpy as np

LIMB_KINDS = ('upperarm', 'forearm', 'thigh', 'calf', 'spine_lower')


def build(survey_dir, name, lo=10, hi=90, role=None):
    rows = [r for r in json.load(open(os.path.join(survey_dir, 'summary.json')))
            if 'error' not in r and r.get('kind') == 'body' and (role is None or r.get('role') == role)]
    if not rows:
        raise SystemExit('no body rows in %s' % survey_dir)
    tri, hs, htri, reg, sides = [], [], [], {}, {}
    for r in rows:
        rep = json.load(open(os.path.join(survey_dir, r['id'], 'report.json')))
        rg = rep['regions']
        tri.append(rep['face_kinds']['tri_equivalent'])
        hs.append(rg['head_with_neck_share'])
        pr = rg['per_region']
        htri.append(pr.get('head', {}).get('tri_equivalent', 0) + pr.get('neck', {}).get('tri_equivalent', 0))
        for k, v in pr.items():
            reg.setdefault(k, []).append(v['tri_share'])
        reg.setdefault('head_with_neck', []).append(rg['head_with_neck_share'])
        for k, v in (rep.get('ring_sides_by_kind') or {}).items():
            if v is not None:
                sides.setdefault(k, []).append(int(v))

    def rng(a):
        return [round(float(np.percentile(a, lo)), 3), round(float(np.percentile(a, hi)), 3)]
    n = len(rows)
    prof = dict(schema='cta-profile/1', name=name,
                note='game profile derived by profile_from_survey.py from %d shipped units (p%d-p%d); budgets and shares only' % (n, lo, hi),
                source=dict(survey=os.path.basename(os.path.normpath(survey_dir)), units=n, percentiles=[lo, hi]),
                thresholds=dict(
                    D1=dict(tri_range=[int(round(np.percentile(tri, lo))), int(round(np.percentile(tri, hi)))]),
                    F5=dict(head_share_range=rng(hs), head_tris_min=int(round(np.percentile(htri, lo)))),
                    D2=dict(ranges={k: rng(v) for k, v in sorted(reg.items()) if len(v) >= 0.5 * n and k != 'other'}),
                    X1=dict(hand_share_range=rng(reg.get('hands', [0.0]))),
                    D3=dict(sides={k: int(np.median(v)) for k, v in sorted(sides.items())
                                   if k in LIMB_KINDS and len(v) >= 0.5 * n})))
    return prof


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('survey')
    ap.add_argument('--name', required=True)
    ap.add_argument('--out', required=True)
    ap.add_argument('--lo', type=float, default=10)
    ap.add_argument('--hi', type=float, default=90)
    ap.add_argument('--role')
    a = ap.parse_args(argv)
    prof = build(a.survey, a.name, a.lo, a.hi, a.role)
    with open(a.out, 'w') as fh:
        json.dump(prof, fh, indent=1)
    print('PROFILE', a.out, json.dumps(prof['thresholds']))
    return 0


if __name__ == '__main__':
    sys.exit(main())
