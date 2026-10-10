"""Plan inspector batches (a job file) from annotated views. Pure Python, no Blender.

    python plan_batches.py --spec SPEC.json --annotated DIR/ANNOTATED.json [...] --out JOB.json
           [--per-inspector 5] [--votes 2] [--engines claude,codex] [--seed 7]

SPEC.json: {"asset": "...", "camera": "...", "legend": ["MAGENTA = ...", ...],
            "classes": {"H1": "binary question ...", ...}, "not_defects": ["...", ...]}

Every inspection image is seen by --votes independent inspectors (one round per vote, each round a fresh shuffle, so
neighbours and positions differ). A round's batches hold --per-inspector images (4-6 keeps attention per image high),
one of them the PLANTED control (an image with a known defect the inspector must report) and, when available, one CLEAN
control (an image with nothing to report) at a random position. --engines is the running agent's family (claude from a
Claude agent, codex from a Codex agent); a list alternates rounds, for callers that legitimately own several engines.
"""
import argparse, json, random
from pathlib import Path


def plan(spec, annotated, per=5, votes=2, engines=('claude',), seed=7):
    imgs = [x for x in annotated if not x.get('control')]
    planted = [x for x in annotated if x.get('control') in ('planted', True)]
    clean = [x for x in annotated if x.get('control') == 'clean']
    if not planted:
        raise SystemExit('no planted control image: render one (render_overlay_views.py --control-object) - an inspector that '
                         'cannot prove it sees a defect proves nothing by reporting none')
    if not 4 <= per <= 6:
        raise SystemExit('--per-inspector must be 4..6')
    twins = {x['label'].split('(')[0].strip() for x in planted + clean} & {x['label'].split('(')[0].strip() for x in imgs}
    if twins:                                               # every batch holds the controls: a twin view would reveal the plant
        raise SystemExit(f'control renders share a view with inspected images: {sorted(twins)}; render controls from their own camera')
    rng = random.Random(seed); batches = []
    slots = per - 1 - (1 if clean else 0)
    for r in range(votes):
        order = imgs[:]; rng.shuffle(order); eng = engines[r % len(engines)]
        chunks = [order[i:i + slots] for i in range(0, len(order), slots)]
        if len(chunks) > 1 and len(chunks[-1]) < 2:          # no single-image tail batch: spread it over the previous one
            tail = chunks.pop(); chunks[-1] = chunks[-1] + tail    # (chunks[-2] += chunks.pop() would write the wrong slot)
        for b, ch in enumerate(chunks):
            files = [x['file'] for x in ch]
            ctl = [rng.choice(planted)['file']] + ([rng.choice(clean)['file']] if clean else [])
            for c in ctl:
                files.insert(rng.randrange(len(files) + 1), c)
            batches.append({'inspector_id': f'{eng}-r{r}-b{b:02d}', 'engine': eng, 'round': r, 'images': files})
    return {'spec': spec, 'images': {x['file']: {'label': x['label'], 'control': x.get('control') or None, 'grid': x.get('grid', [8, 6])}
                                     for x in annotated},
            'votes': votes, 'batches': batches}


if __name__ == '__main__':
    ap = argparse.ArgumentParser(); ap.add_argument('--spec', required=True); ap.add_argument('--annotated', nargs='+', required=True)
    ap.add_argument('--out', required=True); ap.add_argument('--per-inspector', type=int, default=5); ap.add_argument('--votes', type=int, default=2)
    ap.add_argument('--engines', default='claude'); ap.add_argument('--seed', type=int, default=7)
    a = ap.parse_args()
    ann = []
    for f in a.annotated:
        for x in json.load(open(f)):
            if isinstance(x, str):                          # old ANNOTATED.json (file list): label from the file name
                st = Path(x).stem.replace('__ann', '')
                x = {'file': x, 'label': st.replace('CONTROL_', '').replace('CLEAN_', ''),
                     'control': 'planted' if st.startswith('CONTROL_') else ('clean' if st.startswith('CLEAN_') else None)}
            elif x.get('control') is True:
                x['control'] = 'planted'
            fp = Path(x['file'])
            if not fp.is_absolute():                        # older ANNOTATED.json: paths relative to where it was written
                fp = fp if fp.exists() else Path(f).parent / fp.name
            if not fp.exists():
                raise SystemExit(f'image not found: {x["file"]}')
            x['file'] = str(fp.resolve()); ann.append(x)
    job = plan(json.load(open(a.spec)), ann, a.per_inspector, a.votes, tuple(a.engines.split(',')), a.seed)
    json.dump(job, open(a.out, 'w'), indent=1)
    print('PLANNED', len(job['batches']), 'inspectors,', len([1 for v in job['images'].values() if not v['control']]), 'images x', a.votes, 'votes')
