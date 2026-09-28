"""Claude-only image generation through the owner's n8n harness (workflow "Claude Image Harness (Webhook)").

python generate.py "prompt" --out DIR [--name STEM] [--provider openai|gemini] [--model M]
       [--size 1024x1024] [--quality low|medium|high|auto] [--background transparent|opaque|auto]
       [--n 1..4] [--format png|jpeg|webp] [--aspect 1:1] [--image-size 1K|2K|4K] [--ref img.png ...]
python generate.py --ping          # free check of URL + key: no image is generated, nothing is billed

Gate: runs only inside Claude Code (CLAUDECODE=1). GPT/Codex/Gemini agents generate images
natively; this harness costs API money per image, so they must never call it (owner rule).
Secrets (THE REPO IS PUBLIC): IMAGE_HARNESS_URL and IMAGE_HARNESS_KEY, from real environment variables
or from config/image-harness.local.env (gitignored; template config/image-harness.example.env).
Nothing here may print, log or write the key.
Writes DIR/STEM_1.png ... plus DIR/STEM.json (prompt, provider, model, settings, usage, time);
prints only paths - never image data. DIR must be outside the repository (AGENTS.md rule 8).
"""
import argparse
import base64
import datetime
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


def main():
    if os.environ.get('CLAUDECODE') != '1':
        sys.exit('REFUSED: image-harness is Claude-only. GPT/Codex/Gemini agents generate images natively '
                 '(owner rule: the harness is paid per image).')
    ap = argparse.ArgumentParser()
    ap.add_argument('prompt', nargs='?'); ap.add_argument('--out'); ap.add_argument('--name', default='image')
    ap.add_argument('--ping', action='store_true', help='check URL and key; generates nothing')
    ap.add_argument('--provider'); ap.add_argument('--model')
    ap.add_argument('--size'); ap.add_argument('--quality'); ap.add_argument('--background')
    ap.add_argument('--n', type=int); ap.add_argument('--format', dest='output_format')
    ap.add_argument('--aspect', dest='aspect_ratio'); ap.add_argument('--image-size', dest='image_size')
    ap.add_argument('--ref', action='append', default=[])
    ap.add_argument('--timeout', type=int, default=300)
    a = ap.parse_args()
    url, key = load_config()
    if a.ping:
        return ping(url, key)
    if not a.prompt or not a.out:
        ap.error('a prompt and --out are required (or use --ping)')
    out = Path(a.out).resolve()
    if out == REPO or REPO in out.parents:
        sys.exit(f'REFUSED: {out} is inside the repository; write to the scratchpad or a OneDrive checkpoint.')
    body = {k: v for k, v in vars(a).items()
            if k in ('prompt', 'provider', 'model', 'size', 'quality', 'background', 'n', 'output_format',
                     'aspect_ratio', 'image_size') and v is not None}
    if a.ref:
        body['references'] = [{'b64': base64.b64encode(Path(r).read_bytes()).decode('ascii'),
                               'mime': mimetypes.guess_type(r)[0] or 'image/png'} for r in a.ref]
    try:
        res = post(url, key, body, a.timeout)
    except urllib.error.HTTPError as e:
        sys.exit(f'HARNESS ERROR {e.code}: {e.read().decode("utf-8", "replace")[:1500]}')
    if res.get('error'):
        sys.exit(f'HARNESS ERROR: {json.dumps(res)[:1500]}')
    out.mkdir(parents=True, exist_ok=True)
    files = []
    for i, img in enumerate(res['images'], 1):
        ext = (mimetypes.guess_extension(img.get('mime', 'image/png')) or '.png').replace('.jpe', '.jpg')
        p = out / f'{a.name}_{i}{ext}'; p.write_bytes(base64.b64decode(img['b64'])); files.append(str(p))
    meta = dict(request={k: v for k, v in body.items() if k != 'references'}, references=a.ref,
                provider=res.get('provider'), model=res.get('model'), usage=res.get('usage'),
                revised_prompts=[i.get('revised_prompt') for i in res['images'] if i.get('revised_prompt')],
                files=files, time=datetime.datetime.now().isoformat(timespec='seconds'))
    (out / f'{a.name}.json').write_text(json.dumps(meta, indent=2))
    print(f'{res.get("provider")} {res.get("model")}: {len(files)} image(s)')
    for f in files:
        print(' ', f)
    if res.get('usage'):
        print('  usage', json.dumps(res['usage']))


if __name__ == '__main__':
    main()
