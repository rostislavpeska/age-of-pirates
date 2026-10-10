"""Run junction_check.py over a list of cases (a .blend + an answer key + the expected verdict) in background Blender,
one case at a time, and print one table. Plain Python; it launches Blender.

    python run_cases.py --cases CASES.json --out OUT_DIR [--roots ROOTS.local.json] [--blender EXE] [--only ID ...] [--shots]

--shots renders close-ups of every failing case's failing junctions (junction_shots.py) into OUT_DIR/<id>_shots/.
OUT_DIR holds images: keep it outside every repo (AoP rule 8; Korean repo: OneDrive).

CASES.json: {"cases": [{"id": "market-r1h", "blend": "${MARKET_DOCK}/geometry_r1h/x.blend",
                        "key": {... answer key ...} | "key_file": "relative/to/cases.json",
                        "expect": "FAIL", "expect_failing": ["balcony"], "why": "owner-reported defect"}]}
${NAME} in a path comes from ROOTS.local.json ({"NAME": "C:/device/path"}; ignored by Git, one per device) or the
environment. expect_failing lists junction ids (or 'orientation' / 'undeclared') that must fail; any other failing
check is a mismatch too. A case MATCHES when the verdict and the failing set equal the expectation.
Blender: --blender, else $BLENDER, else the AoP config/tool-paths.local.json entry tools.blender.path.
Exit 0 when every case matches, 1 otherwise.
"""
import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
CHECK = HERE / 'junction_check.py'


def blender_exe(arg):
    if arg:
        return arg
    if os.environ.get('BLENDER'):
        return os.environ['BLENDER']
    cfg = HERE.parents[3] / 'config' / 'tool-paths.local.json'
    if cfg.exists():
        exe = (json.load(open(cfg, encoding='utf-8')).get('tools', {}).get('blender') or {}).get('path')
        if exe:
            return exe
    sys.exit('no Blender: pass --blender, set BLENDER or fill config/tool-paths.local.json')


def expand(s, roots):
    def sub(m):
        v = roots.get(m.group(1), os.environ.get(m.group(1)))
        if v is None:
            raise KeyError('unknown root ${%s}: add it to the roots file' % m.group(1))
        return v
    return re.sub(r'\$\{(\w+)\}', sub, s)


def failing(rep):
    out = {j['id'] for j in rep.get('junctions', []) if j['status'] != 'PASS'}
    out |= {k for k in ('orientation', 'up', 'extents', 'probes', 'undeclared') if k in rep and rep[k]['status'] != 'PASS'}
    return sorted(out)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--cases', required=True); ap.add_argument('--out', required=True)
    ap.add_argument('--roots'); ap.add_argument('--blender'); ap.add_argument('--only', nargs='*')
    ap.add_argument('--shots', action='store_true', help='render close-ups of failing junctions (junction_shots.py)')
    a = ap.parse_args()
    cases_path = Path(a.cases).resolve()
    cases = json.load(open(cases_path, encoding='utf-8'))['cases']
    roots = json.load(open(a.roots, encoding='utf-8')) if a.roots else {}
    exe = blender_exe(a.blender)
    out = Path(a.out); out.mkdir(parents=True, exist_ok=True)
    rows = []
    for c in cases:
        if a.only and c['id'] not in a.only:
            continue
        key = c.get('key') or json.load(open(cases_path.parent / c['key_file'], encoding='utf-8'))
        kp = out / (c['id'] + '.key.json'); rp = out / (c['id'] + '.report.json')
        json.dump(key, open(kp, 'w', encoding='utf-8'), indent=1)
        if rp.exists():
            rp.unlink()
        blend = expand(c['blend'], roots)
        print('RUN', c['id'], blend, flush=True)
        p = subprocess.run([exe, '-b', blend, '--python', str(CHECK), '--', '--key', str(kp), '--out', str(rp)],
                           capture_output=True, text=True, encoding='utf-8', errors='replace')
        (out / (c['id'] + '.log')).write_text(p.stdout[-20000:] + '\n--- stderr\n' + p.stderr[-20000:], encoding='utf-8')
        if not rp.exists():
            rows.append((c['id'], c['expect'], 'ERROR', [], False, 'no report (see %s.log)' % c['id']))
            continue
        rep = json.load(open(rp, encoding='utf-8'))
        got = failing(rep)
        want = sorted(c.get('expect_failing', [])) if 'expect_failing' in c else None
        ok = rep['status'] == c['expect'] and (want is None or got == want)
        rows.append((c['id'], c['expect'], rep['status'], got, ok, c.get('why', '')))
        m = p.stdout.find('JUNCTION_CHECK')
        print(p.stdout[m:].split('\nBlender quit')[0] if m >= 0 else p.stdout[-1500:], flush=True)
        if a.shots and rep['status'] != 'PASS':
            sd = out / (c['id'] + '_shots')
            s = subprocess.run([exe, '-b', blend, '--python', str(HERE / 'junction_shots.py'), '--', '--report', str(rp), '--out', str(sd)],
                               capture_output=True, text=True, encoding='utf-8', errors='replace')
            print([ln for ln in s.stdout.splitlines() if ln.startswith('JUNCTION_SHOTS')] or s.stderr[-800:], flush=True)
    print('\n%-22s %-7s %-7s %-6s %s' % ('case', 'expect', 'got', 'match', 'failing checks'))
    for cid, exp, got, fl, ok, why in rows:
        print('%-22s %-7s %-7s %-6s %s%s' % (cid, exp, got, 'yes' if ok else 'NO', ', '.join(fl) or '-', ('   (' + why + ')') if why else ''))
    json.dump([dict(zip(('id', 'expect', 'got', 'failing', 'match', 'why'), r)) for r in rows],
              open(out / 'RESULTS.json', 'w', encoding='utf-8'), indent=1)
    sys.exit(0 if rows and all(r[4] for r in rows) else 1)


if __name__ == '__main__':
    main()
