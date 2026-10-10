"""Score builders' scripts on the junction fixtures: build each in an empty scene, check it against the fixture's
answer key, and print one table (fixtures x builders). Plain Python; launches background Blender, one job at a time.

    python run_bench.py --submissions DIR --out OUT_DIR [--fixtures FIX_DIR] [--builders NAME ...] [--only J1 ...]
                        [--shots] [--expect PASS|FAIL] [--blender EXE]

DIR/<builder>/<J1..J8>.py holds one builder script per fixture (a missing script is reported, not skipped silently).
FIX_DIR (default: this skill's fixtures/) holds <Jn>_<name>/key.json. OUT_DIR/<builder>/ receives each built .blend,
build log, report and, with --shots, the close-ups of failing junctions: keep OUT_DIR outside every repository.
--expect asserts every verdict (reference solutions must all PASS, known-bad ones all FAIL); exit 1 otherwise.
Writes OUT_DIR/BENCH.json and BENCH.md.
"""
import argparse
import json
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from run_cases import blender_exe, failing  # noqa: E402


def summary(rep):
    """One cell: verdict plus the first failing check and its numbers."""
    if rep['status'] == 'PASS':
        return 'PASS'
    for j in rep.get('junctions', []):
        if j['status'] != 'PASS':
            bad = [m for m in j.get('members', []) if m['status'] != 'PASS']
            return 'FAIL %s: %s' % (j['id'], bad[0].get('reason', '') if bad else j.get('reason', j['status']))
    for k in ('orientation', 'up', 'extents', 'probes', 'undeclared'):
        if k in rep and rep[k]['status'] != 'PASS':
            d = rep[k].get('defects', rep[k].get('clashes', []))
            return 'FAIL %s: %s' % (k, json.dumps(d[0])[:90] if d else '')
    return 'FAIL'


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--submissions', required=True); ap.add_argument('--out', required=True)
    ap.add_argument('--fixtures', default=str(HERE.parent / 'fixtures'))
    ap.add_argument('--builders', nargs='*'); ap.add_argument('--only', nargs='*')
    ap.add_argument('--shots', action='store_true'); ap.add_argument('--expect', choices=('PASS', 'FAIL'))
    ap.add_argument('--blender')
    a = ap.parse_args()
    exe = blender_exe(a.blender)
    fixtures = {p.name.split('_')[0]: p for p in sorted(Path(a.fixtures).iterdir()) if (p / 'key.json').exists()}
    if a.only:
        fixtures = {k: v for k, v in fixtures.items() if k in a.only}
    sub = Path(a.submissions)
    builders = a.builders or sorted(p.name for p in sub.iterdir() if p.is_dir())
    out = Path(a.out); rows = []
    for b in builders:
        bo = out / b; bo.mkdir(parents=True, exist_ok=True)
        for fid, fdir in fixtures.items():
            script = sub / b / (fid + '.py')
            cell = {'builder': b, 'fixture': fid}
            if not script.exists():
                rows.append(dict(cell, verdict='MISSING', summary='no %s' % script.name)); continue
            blend, rp = bo / (fid + '.blend'), bo / (fid + '.report.json')
            for f in (blend, rp):
                if f.exists():
                    f.unlink()
            p = subprocess.run([exe, '-b', '--factory-startup', '--python', str(HERE / 'build_runner.py'), '--', str(script), str(blend)],
                               capture_output=True, text=True, encoding='utf-8', errors='replace')
            (bo / (fid + '.build.log')).write_text(p.stdout[-20000:] + '\n--- stderr\n' + p.stderr[-20000:], encoding='utf-8')
            if p.returncode != 0 or not blend.exists():
                rows.append(dict(cell, verdict='ERROR', summary='build failed (see %s.build.log)' % fid)); print(b, fid, 'ERROR', flush=True)
                continue
            subprocess.run([exe, '-b', str(blend), '--python', str(HERE / 'junction_check.py'), '--', '--key', str(fdir / 'key.json'), '--out', str(rp)],
                           capture_output=True, text=True, encoding='utf-8', errors='replace')
            if not rp.exists():
                rows.append(dict(cell, verdict='ERROR', summary='check failed')); print(b, fid, 'ERROR (check)', flush=True)
                continue
            rep = json.load(open(rp, encoding='utf-8'))
            rows.append(dict(cell, verdict=rep['status'], summary=summary(rep), failing=failing(rep)))
            print(b, fid, rows[-1]['summary'], flush=True)
            if a.shots and rep['status'] != 'PASS':
                subprocess.run([exe, '-b', str(blend), '--python', str(HERE / 'junction_shots.py'), '--', '--report', str(rp), '--out', str(bo / (fid + '_shots'))],
                               capture_output=True, text=True, encoding='utf-8', errors='replace')
    lines = ['| Fixture | ' + ' | '.join(builders) + ' |', '|---|' + '---|' * len(builders)]
    for fid in fixtures:
        cells = [next((r['summary'] for r in rows if r['builder'] == b and r['fixture'] == fid), '') for b in builders]
        lines.append('| %s | %s |' % (fid, ' | '.join(c.replace('|', '/') for c in cells)))
    score = ['%s: %d/%d PASS' % (b, sum(r['verdict'] == 'PASS' for r in rows if r['builder'] == b), len(fixtures)) for b in builders]
    md = '\n'.join(lines + ['', '; '.join(score)])
    out.mkdir(parents=True, exist_ok=True)
    (out / 'BENCH.md').write_text(md + '\n', encoding='utf-8')
    json.dump(rows, open(out / 'BENCH.json', 'w', encoding='utf-8'), indent=1)
    print('\n' + md)
    if a.expect:
        wrong = [r for r in rows if r['verdict'] != a.expect]
        print('EXPECT %s: %s' % (a.expect, 'all match' if not wrong else '%d mismatch: %s' % (len(wrong), ', '.join('%s/%s' % (r['builder'], r['fixture']) for r in wrong))))
        sys.exit(1 if wrong else 0)


if __name__ == '__main__':
    main()
