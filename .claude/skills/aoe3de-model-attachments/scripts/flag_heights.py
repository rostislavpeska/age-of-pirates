"""Flag heights: how far below its pole tip each flag bone sits (vanilla norms) and whether a model follows them.
Owner 2026-10-11 (Korean Market game test: "market flag sits too high on the flag pile"; "check the optimal flag distances ...
same with garrisonflag, that one is actually smaller so optimal distance is higher. Some objects like Town Center have two
flags"). The engine hangs the flag cloth ABOVE its bone (the bone is the cloth's lower edge, SKILL.md section 3), so a bone
at the pole tip floats the whole cloth above the pole.

    python flag_heights.py survey VANILLA_GR2_DIR --out FLAG_NORMS.json      # vanilla intact building models
    python flag_heights.py check MODEL.gr2 [--norms FLAG_NORMS.json]        # exit 1 when a flag bone is off the norm

Pole: the model's render vertices within RADIUS (0.25 m) of the bone's vertical axis (engine raw: y up), from 6 m below to
6 m above the bone; tip = their highest point. drop = tip - bone (m, at the bone's scale 1; the bone scale is reported).
A flag bone with no pole vertices (a flag on a roof finial, a wall) is reported 'no pole' and not judged.
"""
import argparse, json, os, sys
from pathlib import Path
import numpy as np

HERE = Path(__file__).resolve()
sys.path.insert(0, str(HERE.parents[4] / 'scripts' / 'havok'))
FLAGS = {'bone_flag_civ': 'civ', 'bone_garrisonflag': 'garrison'}
RADIUS = .25


def measure(path):
    from gr2_lint import read_raw
    r = read_raw(str(path))
    if not r.get('render'):
        return []
    P = np.concatenate([m['pos'] for m in r['render']])
    out = []
    for b in r['bones']:
        kind = FLAGS.get(b['name'].lower())
        if kind is None:
            continue
        W = np.asarray(b['world'], float); bp = W[3, :3]; scale = float(np.linalg.norm(W[:3, :3], axis=1).mean())
        sel = (np.hypot(P[:, 0] - bp[0], P[:, 2] - bp[2]) < RADIUS) & (P[:, 1] > bp[1] - 6) & (P[:, 1] < bp[1] + 6)
        row = dict(model=Path(path).name, bone=b['name'], kind=kind, bone_y=round(float(bp[1]), 3), scale=round(scale, 3))
        if sel.sum() < 4:
            row['pole'] = None
        else:
            tip = float(P[sel, 1].max()); row.update(pole=int(sel.sum()), tip_y=round(tip, 3), drop=round(tip - float(bp[1]), 3))
        out.append(row)
    return out


def survey(root, out):
    rows, failed = [], 0
    skip = ('damag', '_lp', '_con', 'stage', 'death', 'frame', 'decal', 'rubble', 'scaffold', 'construction', 'anim')
    files = [p for p in Path(root).rglob('*.gr2') if not any(k in p.name.lower() for k in skip)]
    for p in files:
        try:
            rows += measure(p)
        except Exception:
            failed += 1
    norms = {}
    for kind in ('civ', 'garrison'):
        d = np.array([r['drop'] for r in rows if r['kind'] == kind and r.get('pole') and r['drop'] is not None])
        if len(d):
            norms[kind] = dict(n=int(len(d)), median=round(float(np.median(d)), 3), p10=round(float(np.percentile(d, 10)), 3),
                               p90=round(float(np.percentile(d, 90)), 3), min=round(float(d.min()), 3), max=round(float(d.max()), 3))
    both = sorted({r['model'] for r in rows if r['kind'] == 'civ'} & {r['model'] for r in rows if r['kind'] == 'garrison'})
    rep = dict(models_read=len(files) - failed, models_failed=failed, flag_bones=len(rows),
               no_pole=sum(1 for r in rows if not r.get('pole')), norms=norms, two_flag_models=len(both),
               two_flag_examples=both[:12], rows=rows)
    Path(out).write_text(json.dumps(rep, indent=1))
    print('FLAG_SURVEY', json.dumps({k: rep[k] for k in ('models_read', 'models_failed', 'flag_bones', 'no_pole', 'norms', 'two_flag_models')}))


def check(model, norms_path):
    N = json.load(open(norms_path))['norms'] if norms_path else {}
    bad = 0
    for r in measure(model):
        n = N.get(r['kind'])
        if not r.get('pole'):
            print('NO_POLE', r['bone'], 'y', r['bone_y'], '(not judged)'); continue
        verdict = 'INFO'
        if n:
            verdict = 'PASS' if n['p10'] <= r['drop'] <= n['p90'] else 'FAIL'
            bad += verdict == 'FAIL'
        print(verdict, r['bone'], f"drop {r['drop']} m below the tip {r['tip_y']}", f"(vanilla {r['kind']} p10-p90 {n['p10']}-{n['p90']}, median {n['median']})" if n else '')
    sys.exit(1 if bad else 0)


if __name__ == '__main__':
    ap = argparse.ArgumentParser(); ap.add_argument('mode', choices=('survey', 'check')); ap.add_argument('path')
    ap.add_argument('--out'); ap.add_argument('--norms')
    a = ap.parse_args()
    survey(a.path, a.out) if a.mode == 'survey' else check(a.path, a.norms)
