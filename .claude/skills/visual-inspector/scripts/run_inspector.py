"""Run visual inspectors from a job file (plan_batches.py) with Claude or Codex, headless and read-only.

    python run_inspector.py --job JOB.json --out-dir RESULTS [--batch ID ...] [--engine claude|codex] [--model M]
           [--parallel 3] [--timeout 600]
    python run_inspector.py --job JOB.json --print-prompt ID      (prompt text for an in-session subagent)

claude: `claude -p --model sonnet --output-format json --json-schema SCHEMA --allowedTools Read --add-dir IMGDIR`; the
        inspector opens each image path with Read (images under the 1568 px long edge are not downscaled).
codex:  `codex exec -s read-only --ephemeral --skip-git-repo-check -C WORKDIR --output-schema SCHEMA -o OUT --image F ...`
        with the prompt on stdin (the --image list is greedy; a positional prompt after it would be read as an image).
        The binary is CODEX_BIN, `codex` on PATH, or the Codex desktop app's bundled codex.exe (Windows Store package).
Writes RESULTS/<inspector_id>.json (the inspector's JSON) and RESULTS/<inspector_id>.log (engine, model, seconds, rc).
No secrets are passed or logged: both CLIs use their own stored sign-in.
"""
import argparse, json, os, re, shutil, subprocess, sys, tempfile, time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

HERE = Path(__file__).resolve().parent
SCHEMA = HERE.parent / 'references' / 'inspector_output.schema.json'
TEMPLATE = HERE.parent / 'references' / 'inspector_prompt.md'


def template_text():
    t = TEMPLATE.read_text(encoding='utf-8')
    return t.split('\n---\n', 1)[1].strip()


def fill(job, batch, engine):
    sp = job['spec']; files = batch['images']
    if engine == 'codex':
        inst = 'the images are attached to this message, in this order: ' + ', '.join(f'({i + 1}) {Path(f).name}' for i, f in enumerate(files)) + \
               '. Use these file names as image_file.'
    else:
        inst = 'read each of these files with your Read tool, in this order: ' + ', '.join(f'({i + 1}) {Path(f).resolve()}' for i, f in enumerate(files)) + \
               '. Use the bare file name (no folder) as image_file.'
    classes = '\n'.join(f'{k}: {v}' for k, v in sp['classes'].items())
    vals = {'asset': sp['asset'], 'camera': sp['camera'], 'legend': '\n'.join(sp['legend']), 'image_instruction': inst,
            'view_note': sp.get('view_note', 'Each image shows the model in flat false colours (no lighting, no texture) on a grey background.'),
            'classes': classes, 'not_defects': '; '.join(sp['not_defects']), 'inspector_id': batch['inspector_id']}
    return re.sub(r'\{(asset|camera|view_note|legend|image_instruction|classes|not_defects|inspector_id)\}', lambda m: vals[m.group(1)], template_text())


def codex_bin():
    for c in (os.environ.get('CODEX_BIN'), shutil.which('codex')):
        if c and Path(c).exists():
            return c
    if os.name == 'nt':                                   # Codex desktop app: WindowsApps cannot be listed, ask the package
        try:
            loc = subprocess.run(['powershell', '-NoProfile', '-Command', '(Get-AppxPackage -Name OpenAI.Codex).InstallLocation'],
                                 capture_output=True, text=True, timeout=30).stdout.strip().splitlines()
            for l in loc:
                exe = Path(l.strip()) / 'app' / 'resources' / 'codex.exe'
                if exe.exists():
                    return str(exe)
        except Exception:
            pass
    raise SystemExit('codex CLI not found: set CODEX_BIN')


def parse_json(text):
    text = text.strip()
    m = re.search(r'\{.*\}', text, re.S)
    return json.loads(m.group(0) if m else text)


def run_one(job, batch, out_dir, engine, model, timeout):
    out = Path(out_dir) / f"{batch['inspector_id']}.json"; log = out.with_suffix('.log'); prompt = fill(job, batch, engine)
    t0 = time.time(); rc = None; err = ''
    try:
        if engine == 'claude':
            dirs = sorted({str(Path(f).resolve().parent) for f in batch['images']})
            cmd = ['claude', '-p', '--model', model or 'sonnet', '--output-format', 'json', '--json-schema', SCHEMA.read_text(encoding='utf-8'),
                   '--allowedTools', 'Read', '--permission-mode', 'dontAsk'] + sum((['--add-dir', d] for d in dirs), [])   # anything but Read is denied, never prompted
            p = subprocess.run(cmd, input=prompt, capture_output=True, text=True, encoding='utf-8', timeout=timeout, cwd=dirs[0])
            rc = p.returncode; err = p.stderr[-2000:]
            env = json.loads(p.stdout)
            data = env.get('structured_output') or parse_json(env.get('result', ''))
        else:
            work = tempfile.mkdtemp(prefix='inspector_')
            cmd = [codex_bin(), 'exec', '-s', 'read-only', '--ephemeral', '--skip-git-repo-check', '-C', work,
                   '--output-schema', str(SCHEMA), '-o', str(out.with_suffix('.raw'))] + (['-m', model] if model else [])
            for f in batch['images']:
                cmd += ['--image', str(Path(f).resolve())]
            p = subprocess.run(cmd, input=prompt, capture_output=True, text=True, encoding='utf-8', timeout=timeout)
            rc = p.returncode; err = p.stderr[-2000:]
            data = parse_json(out.with_suffix('.raw').read_text(encoding='utf-8'))
        data['inspector_id'] = batch['inspector_id']
        json.dump(data, open(out, 'w'), indent=1); ok = True
    except Exception as e:                                   # a failed inspector is reported, never read as "clean"
        ok = False; err = f'{type(e).__name__}: {e}\n{err}'
    json.dump({'engine': engine, 'model': model or ('sonnet' if engine == 'claude' else 'codex default'), 'seconds': round(time.time() - t0, 1),
               'rc': rc, 'ok': ok, 'stderr_tail': err[-1500:]}, open(log, 'w'), indent=1)
    return batch['inspector_id'], ok, round(time.time() - t0, 1)


if __name__ == '__main__':
    ap = argparse.ArgumentParser(); ap.add_argument('--job', required=True); ap.add_argument('--out-dir'); ap.add_argument('--batch', nargs='*')
    ap.add_argument('--engine'); ap.add_argument('--model'); ap.add_argument('--parallel', type=int, default=3); ap.add_argument('--timeout', type=int, default=600)
    ap.add_argument('--print-prompt')
    a = ap.parse_args(); job = json.load(open(a.job))
    by_id = {b['inspector_id']: b for b in job['batches']}
    if a.print_prompt:
        b = by_id[a.print_prompt]; print(fill(job, b, a.engine or 'claude')); sys.exit(0)
    Path(a.out_dir).mkdir(parents=True, exist_ok=True)
    todo = [by_id[i] for i in a.batch] if a.batch else job['batches']
    with ThreadPoolExecutor(a.parallel) as ex:
        for iid, ok, sec in ex.map(lambda b: run_one(job, b, a.out_dir, a.engine or b['engine'], a.model, a.timeout), todo):
            print('INSPECTOR', iid, 'ok' if ok else 'FAILED', sec, 's')
