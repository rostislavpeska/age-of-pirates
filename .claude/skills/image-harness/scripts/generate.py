"""Claude-only image generation AND editing through the owner's n8n harness (workflow "Claude Image Harness (Webhook)").

Generate (unchanged):
  python generate.py "prompt" --out DIR [--name STEM] [--provider openai|gemini] [--model M]
         [--size 1024x1024] [--quality low|medium|high|auto] [--background transparent|opaque|auto]
         [--n 1..4] [--format png|jpeg|webp] [--aspect 1:1] [--image-size 1K|2K|4K] [--ref img.png ...]
Edit (harness v2):
  python generate.py "instruction" --out DIR --image IN.png [--image IN2.png ...] [--mask MASK.png]
         [--provider openai|gemini] [--input-fidelity high|low] [--size auto|1024x1024|...] [--quality ...]
  OpenAI /images/edits: up to 16 input images; --mask (PNG, same size as the FIRST image, fully transparent pixels =
  the area the model may change; make one with make_mask.py). Gemini: input images + instruction, no mask.
  A mask selects OpenAI automatically.
Agent safety:
  --dry-run            validate locally, print the request summary and a cost estimate; nothing is sent or billed
  --ping               free check of URL + key: no image is generated, nothing is billed
  --ledger             print the device-local ledger of paid calls (count + estimated USD per day and model)
  --allow-repeat       send a request identical to one sent in the last 10 minutes (refused by default: agent
                       retries must not pay twice)

Gate: runs only inside Claude Code (CLAUDECODE=1). GPT/Codex/Gemini agents generate images natively; this harness
costs API money per image, so they must never call it (owner rule, AGENTS.md rule 10).
Secrets (THE REPO IS PUBLIC): IMAGE_HARNESS_URL and IMAGE_HARNESS_KEY, from real environment variables or from
config/image-harness.local.env (gitignored; template config/image-harness.example.env). Nothing here may print, log
or write the URL or the key.
Writes DIR/STEM_1.png ... plus DIR/STEM.json (operation, prompt, inputs + sha256, provider, model, settings, usage,
estimate, time); prints only paths. DIR must be outside the repository (AGENTS.md rule 8). Every paid call is also
appended to the ledger (rule 12: paid calls are counted).
"""
import argparse
import base64
import datetime
import hashlib
import io
import json
import mimetypes
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path

REPO = Path(__file__).resolve().parents[4]  # scripts -> image-harness -> skills -> .claude -> repo
ENV_FILE = REPO / 'config' / 'image-harness.local.env'
EXAMPLE = 'config/image-harness.example.env'
LEDGER = Path(os.environ.get('IMAGE_HARNESS_LEDGER', Path.home() / '.image-harness' / 'ledger.jsonl'))
REPEAT_WINDOW_S = 600
MASK_MAX_BYTES = 4 * 1024 * 1024
# USD per 1024x1024 output image, OpenAI list prices checked 2026-10-09 (SKILL.md "Budget rules"). Estimates only:
# edits add input-image tokens, larger sizes cost more, and Gemini is not priced here (its usage is recorded instead).
PRICE = {('gpt-image-1', 'low'): .011, ('gpt-image-1', 'medium'): .042, ('gpt-image-1', 'high'): .167,
         ('gpt-image-1-mini', 'low'): .005, ('gpt-image-1.5', 'low'): .009}


def load_config():
    """IMAGE_HARNESS_URL / IMAGE_HARNESS_KEY: environment first, then the gitignored env file."""
    vals = {}
    if ENV_FILE.exists():
        for line in ENV_FILE.read_text(encoding='utf-8').splitlines():
            line = line.strip()
            if line and not line.startswith('#') and '=' in line:
                k, v = line.split('=', 1)
                vals[k.strip()] = v.strip().strip('"').strip("'")
    for k in ('IMAGE_HARNESS_URL', 'IMAGE_HARNESS_KEY'):
        if os.environ.get(k):
            vals[k] = os.environ[k]
    url, key = vals.get('IMAGE_HARNESS_URL', ''), vals.get('IMAGE_HARNESS_KEY', '')
    if not url or not key or '<' in url or '<' in key:
        sys.exit(f'Missing IMAGE_HARNESS_URL / IMAGE_HARNESS_KEY: copy {EXAMPLE} to '
                 f'config/image-harness.local.env (gitignored) and fill it in, or set the environment variables.')
    if not url.startswith('https://'):
        sys.exit('REFUSED: IMAGE_HARNESS_URL must be https (the key travels in a header).')
    return url, key


def post(url, key, body, timeout):
    req = urllib.request.Request(url, data=json.dumps(body).encode(), method='POST',
                                 headers={'Content-Type': 'application/json', 'x-api-key': key})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read())


def ping(url, key):
    """The workflow checks x-api-key before it validates the request, so an invalid body answers 401 on a
    wrong key and 400 (or a provider error) on a good one - without generating or billing anything."""
    try:
        post(url, key, {'provider': 'ping'}, 60)
    except urllib.error.HTTPError as e:
        if e.code == 401:
            sys.exit('PING: key rejected (401) - check IMAGE_HARNESS_KEY.')
        print(f'PING OK: harness reachable and key accepted (HTTP {e.code} for the deliberately invalid request).')
        return
    except urllib.error.URLError as e:
        sys.exit(f'PING: harness unreachable ({e.reason}) - check IMAGE_HARNESS_URL.')
    print('PING OK: harness reachable and key accepted.')


def sha(data):
    return hashlib.sha256(data).hexdigest()


def image_size(data):
    from PIL import Image
    with Image.open(io.BytesIO(data)) as im:
        return im.size


def check_mask(mask_path, first_image):
    """OpenAI rules, checked BEFORE paying: PNG, < 4 MB, same size as the first input image, with an alpha channel
    that has at least one fully transparent pixel (the editable area) and at least one opaque pixel."""
    from PIL import Image
    data = Path(mask_path).read_bytes()
    if len(data) >= MASK_MAX_BYTES:
        return f'mask {mask_path} is {len(data)} bytes; OpenAI needs < 4 MB'
    with Image.open(io.BytesIO(data)) as m:
        if m.format != 'PNG':
            return f'mask {mask_path} must be a PNG (got {m.format})'
        if m.size != image_size(Path(first_image).read_bytes()):
            return f'mask {mask_path} is {m.size}, the first --image {first_image} is {image_size(Path(first_image).read_bytes())}: sizes must match'
        if 'A' not in m.getbands():
            return f'mask {mask_path} has no alpha channel: fully transparent pixels mark the editable area (use make_mask.py)'
        lo, hi = m.getchannel('A').getextrema()
        if lo != 0:
            return f'mask {mask_path} has no fully transparent pixel: nothing would be editable'
        if hi == 0:
            return f'mask {mask_path} is fully transparent: the whole image would be regenerated - omit --mask instead'
    return None


def build_request(a):
    """Validate the CLI arguments into the harness JSON body. Returns (body, summary) or exits with an actionable error."""
    op = a.operation or ('edit' if a.image else 'generate')
    if op not in ('generate', 'edit'):
        sys.exit("ERROR: --operation must be 'generate' or 'edit'")
    if op == 'edit' and not a.image:
        sys.exit('ERROR: --operation edit needs at least one --image (the picture to edit)')
    if op == 'generate' and a.image:
        sys.exit('ERROR: --image is an edit input; use --operation edit (or --ref for Gemini style references)')
    if a.mask and op != 'edit':
        sys.exit('ERROR: --mask belongs to an edit: add --image IN.png')
    provider = a.provider or ('openai' if (op == 'edit' and a.mask) or (op == 'generate' and not a.ref) else
                              ('gemini' if op == 'generate' else 'openai'))
    if a.mask and provider != 'openai':
        sys.exit('ERROR: --mask needs --provider openai (Gemini edits by instruction only, no mask)')
    if provider == 'openai' and a.ref:
        sys.exit('ERROR: --ref (style references) needs --provider gemini; OpenAI takes edit inputs as --image')
    if provider == 'openai' and len(a.image or []) > 16:
        sys.exit('ERROR: OpenAI edits accept at most 16 --image inputs')
    if a.input_fidelity and not (provider == 'openai' and op == 'edit'):
        sys.exit('ERROR: --input-fidelity applies to OpenAI edits only')
    if a.mask:
        problem = check_mask(a.mask, a.image[0])
        if problem:
            sys.exit('ERROR: ' + problem)
    body = {'operation': op, 'provider': provider}
    for k in ('prompt', 'model', 'size', 'quality', 'background', 'n', 'output_format', 'aspect_ratio', 'image_size', 'input_fidelity'):
        v = getattr(a, k, None)
        if v is not None:
            body[k] = v
    inputs = [Path(p) for p in (a.image or a.ref or [])]
    for p in inputs:
        if not p.is_file():
            sys.exit(f'ERROR: input image {p} does not exist')
    if inputs:
        body['references'] = [{'b64': base64.b64encode(p.read_bytes()).decode('ascii'),
                                'mime': mimetypes.guess_type(str(p))[0] or 'image/png'} for p in inputs]
    if a.mask:
        body['mask'] = {'b64': base64.b64encode(Path(a.mask).read_bytes()).decode('ascii'), 'mime': 'image/png'}
    model = body.get('model') or ('gpt-image-1' if provider == 'openai' else 'gemini-3.1-flash-image-preview')
    quality = body.get('quality') or ('medium' if provider == 'openai' else None)
    n = int(body.get('n') or 1)
    unit = PRICE.get((model, quality))
    summary = {'operation': op, 'provider': provider, 'model': model, 'quality': quality, 'n': n,
               'size': body.get('size') or body.get('image_size'), 'inputs': [str(p) for p in inputs],
               'inputs_sha256': [sha(p.read_bytes()) for p in inputs], 'mask': a.mask,
               'mask_sha256': sha(Path(a.mask).read_bytes()) if a.mask else None,
               'estimate_usd': round(unit * n, 3) if unit else None,
               'estimate_note': 'OpenAI list price per 1024 output image; edits add input-image tokens' if unit else
                                'no local price for this provider/model/quality; usage is recorded'}
    summary['request_sha256'] = sha(json.dumps({k: v for k, v in body.items() if k not in ('references', 'mask')}, sort_keys=True).encode()
                                    + ''.join(summary['inputs_sha256']).encode() + (summary['mask_sha256'] or '').encode())
    return body, summary


def ledger_rows():
    if not LEDGER.exists():
        return []
    rows = []
    for line in LEDGER.read_text(encoding='utf-8').splitlines():
        try:
            rows.append(json.loads(line))
        except ValueError:
            pass
    return rows


def recent_duplicate(request_hash):
    now = datetime.datetime.now()
    for r in reversed(ledger_rows()):
        try:
            t = datetime.datetime.fromisoformat(r['time'])
        except (KeyError, ValueError):
            continue
        if (now - t).total_seconds() > REPEAT_WINDOW_S:
            break
        if r.get('request_sha256') == request_hash:
            return r
    return None


def ledger_append(row):
    LEDGER.parent.mkdir(parents=True, exist_ok=True)
    with LEDGER.open('a', encoding='utf-8') as f:
        f.write(json.dumps(row) + '\n')


def ledger_report():
    rows = ledger_rows(); agg = {}
    for r in rows:
        k = (r.get('time', '')[:10], r.get('provider'), r.get('model'), r.get('operation', 'generate'))
        c = agg.setdefault(k, [0, 0., 0]); c[0] += r.get('images', 1); c[1] += r.get('estimate_usd') or 0.; c[2] += r.get('estimate_usd') is None
    print(f'LEDGER {LEDGER} ({len(rows)} calls)')
    for (day, prov, model, op), (imgs, usd, unpriced) in sorted(agg.items()):
        print(f'  {day} {prov} {model} {op}: {imgs} image(s), ~${usd:.3f}' + (f' (+{unpriced} unpriced call(s))' if unpriced else ''))


def main():
    if os.environ.get('CLAUDECODE') != '1':
        sys.exit('REFUSED: image-harness is Claude-only. GPT/Codex/Gemini agents generate images natively '
                 '(owner rule: the harness is paid per image).')
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('prompt', nargs='?'); ap.add_argument('--out'); ap.add_argument('--name', default='image')
    ap.add_argument('--ping', action='store_true', help='check URL and key; generates nothing')
    ap.add_argument('--ledger', action='store_true', help='print the paid-call ledger')
    ap.add_argument('--dry-run', action='store_true', help='validate and estimate; send nothing')
    ap.add_argument('--allow-repeat', action='store_true', help='allow an identical request within 10 minutes')
    ap.add_argument('--operation', choices=('generate', 'edit'))
    ap.add_argument('--provider', choices=('openai', 'gemini')); ap.add_argument('--model')
    ap.add_argument('--size'); ap.add_argument('--quality'); ap.add_argument('--background')
    ap.add_argument('--n', type=int); ap.add_argument('--format', dest='output_format')
    ap.add_argument('--aspect', dest='aspect_ratio'); ap.add_argument('--image-size', dest='image_size')
    ap.add_argument('--ref', action='append', default=[], help='Gemini style/reference image for generate')
    ap.add_argument('--image', action='append', default=[], help='edit input image (repeatable; the first gets the mask)')
    ap.add_argument('--mask', help='OpenAI edit mask PNG (transparent = editable), same size as the first --image')
    ap.add_argument('--input-fidelity', dest='input_fidelity', choices=('high', 'low'))
    ap.add_argument('--timeout', type=int, default=300)
    a = ap.parse_args()
    if a.ledger:
        return ledger_report()
    if a.ping:
        url, key = load_config()
        return ping(url, key)
    if not a.prompt or not a.out:
        ap.error('a prompt and --out are required (or use --ping / --ledger)')
    out = Path(a.out).resolve()
    if out == REPO or REPO in out.parents:
        sys.exit(f'REFUSED: {out} is inside the repository; write to the scratchpad or a OneDrive checkpoint.')
    body, summary = build_request(a)
    if a.dry_run:
        print('DRY RUN (nothing sent):', json.dumps(summary, indent=1))
        return
    dup = recent_duplicate(summary['request_sha256'])
    if dup and not a.allow_repeat:
        sys.exit(f'REFUSED: the identical request was paid at {dup["time"]} -> {dup.get("files")}. Reuse those files, '
                 'change the request, or pass --allow-repeat if a second paid sample is really wanted.')
    url, key = load_config()
    try:
        res = post(url, key, body, a.timeout)
    except urllib.error.HTTPError as e:
        text = e.read().decode('utf-8', 'replace')[:1500]
        if 'need provider gemini' in text and summary['operation'] == 'edit':
            text += ('\n  -> the n8n workflow is still v1 (no OpenAI edit route; nothing was billed). Apply the v2 change in '
                     'references/workflow-v2.md, or edit with --provider gemini (no mask).')
        sys.exit(f'HARNESS ERROR {e.code}: {text}')
    if res.get('error'):
        sys.exit(f'HARNESS ERROR: {json.dumps(res)[:1500]}')
    out.mkdir(parents=True, exist_ok=True)
    files = []
    for i, img in enumerate(res['images'], 1):
        ext = (mimetypes.guess_extension(img.get('mime', 'image/png')) or '.png').replace('.jpe', '.jpg')
        p = out / f'{a.name}_{i}{ext}'; p.write_bytes(base64.b64decode(img['b64'])); files.append(str(p))
    now = datetime.datetime.now().isoformat(timespec='seconds')
    meta = dict(request={k: v for k, v in body.items() if k not in ('references', 'mask')}, operation=summary['operation'],
                inputs=summary['inputs'], inputs_sha256=summary['inputs_sha256'], mask=summary['mask'], mask_sha256=summary['mask_sha256'],
                references=a.ref, provider=res.get('provider'), model=res.get('model'), usage=res.get('usage'),
                estimate_usd=summary['estimate_usd'], request_sha256=summary['request_sha256'],
                revised_prompts=[i.get('revised_prompt') for i in res['images'] if i.get('revised_prompt')],
                files=files, time=now)
    (out / f'{a.name}.json').write_text(json.dumps(meta, indent=2))
    ledger_append(dict(time=now, operation=summary['operation'], provider=res.get('provider'), model=res.get('model'),
                       quality=summary['quality'], images=len(files), estimate_usd=summary['estimate_usd'],
                       usage=res.get('usage'), request_sha256=summary['request_sha256'], files=files))
    print(f'{res.get("provider")} {res.get("model")} {summary["operation"]}: {len(files)} image(s)'
          + (f' ~${summary["estimate_usd"]}' if summary['estimate_usd'] else ''))
    for f in files:
        print(' ', f)
    if res.get('usage'):
        print('  usage', json.dumps(res['usage']))


if __name__ == '__main__':
    main()
