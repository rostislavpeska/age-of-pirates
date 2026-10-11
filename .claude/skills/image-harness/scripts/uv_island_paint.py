"""Edit ONE UV island (or a few) of a texture page with ANY image generator - GPT/Codex/Astra native image editing, the
Claude-only harness, or a manual edit - and write it back inside the island only. Owner 2026-10-12: "Astra can't use the
harness ... the edit image based on UV island ... The feature is great! Should work also for GPT native image generation
(without harness)". The generator is not called here: this script prepares the edit and applies the result.

extract  the islands' texels of the page -> their crop, padded with neutral grey onto a canvas of a generator aspect
         (1:1, 2:3 or 3:2; long side --size) so any returned size maps back exactly (EDIT_INPUT.png), its edit mask (EDIT_MASK.png:
         alpha 0 = editable = the islands, the native/OpenAI mask convention), a GUIDE.png (island outlines over the crop, for
         the prompt and the review) and ISLAND.json (page hash, crop box, scale, mask hash, triangle count, prompt template).
apply    PAINTED.png (any size) -> resized to the canvas, the crop taken back from its placement, gated
         (the painting must keep the island's structure: edge correlation inside the mask >= --min-structure, unless
         --restyle), box-filtered to page texels and pasted ONLY on island texels (feather inside the island; outside
         bytes identical) -> the new page PNG + APPLY.json (provider route, prompt, input/output hashes, call count, cost
         unknown unless given: never a fabricated receipt). Optional --ddt patches the game DDT block-wise
         (AoP scripts/havok/ddt_patch.py).

Islands come from a model: --gr2 X.gr2 --mat mata (raw GR2 UVs = page image coordinates) and a selection: --at u,v
(page fraction; repeatable: the island under that point), --island N (connected-component index, largest first), or
--all (every island of the material). UV-connected = sharing a UV coordinate (1e-5).

    python uv_island_paint.py extract --page BaseColor.png --gr2 X.gr2 --mat mata --at 0.31,0.17 --out DIR [--size 1024 --margin 6]
    python uv_island_paint.py apply --dir DIR --painted PAINTED.png --route native-gpt --prompt-file PROMPT.txt --out-page NEW.png [--ddt X.ddt --ddt-out NEW.ddt]
"""
import argparse, hashlib, json, sys
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = Path(__file__).resolve().parent
HAVOK = HERE.parents[3] / 'scripts' / 'havok'                # the AoP checkout's scripts/havok
sha = lambda p: hashlib.sha256(Path(p).read_bytes()).hexdigest()
PROMPT = ('Repaint ONLY the texture inside the outlined island(s) of this game texture crop as {what}. Keep every edge, '
          'board joint, plank direction, opening and shape exactly where it is (the 3D model maps it), keep the overall '
          'brightness, orthographic flat lighting, no shadows, no text, no new objects; outside the island stays as it is.')


def islands(gr2, mat):
    sys.path.insert(0, str(HAVOK)); from gr2_lint import read_raw     # noqa: E402
    tris = []
    for m in read_raw(gr2)['render']:
        if m['mats'][0].lower() == mat.lower():
            uv = np.asarray(m['uv'], float)[:, :2]; tris += [uv[t] for t in np.asarray(m['tris'])]
    return components(tris)


def components(tris):
    T = np.asarray(tris, float)
    if T.ndim != 3 or T.shape[1:] != (3, 2) or not len(T) or not np.isfinite(T).all():
        raise ValueError('Expected nonempty finite UV triangles [N,3,2]')
    if T.min() < -1e-6 or T.max() > 1 + 1e-6:
        raise ValueError('UV triangles must be inside the requested 0..1 page')
    key = np.round(T.reshape(-1, 2) / 1e-5).astype(np.int64); parent = list(range(len(T)))
    def f(x):
        while parent[x] != x: parent[x] = parent[parent[x]]; x = parent[x]
        return x
    seen = {}
    for i, k in enumerate(map(tuple, key)):
        ti = i // 3
        if k in seen: parent[f(ti)] = f(seen[k])
        else: seen[k] = ti
    root = np.array([f(i) for i in range(len(T))]); comps = {}
    for i, r_ in enumerate(root): comps.setdefault(r_, []).append(i)
    return T, sorted(comps.values(), key=lambda c: -len(c))


def extract(a):
    O = Path(a.out); O.mkdir(parents=True, exist_ok=True); page = Image.open(a.page).convert('RGBA'); W, H = page.size
    if a.uv_json:
        src = json.loads(Path(a.uv_json).read_text(encoding='utf-8'))
        if src.get('origin') != 'top-left':
            raise ValueError('UV JSON must explicitly use top-left image coordinates; Blender V becomes 1-V')
        if not src.get('source_id') or not src.get('uv_layer'):
            raise ValueError('UV JSON needs source_id and uv_layer for provenance')
        T, comps = components(src['triangles'])
    else:
        if not a.mat: raise ValueError('--mat is required with --gr2')
        T, comps = islands(a.gr2, a.mat)
    sel = []
    if a.all: sel = list(range(len(T)))
    for i in a.island or []: sel += comps[i]
    for at in a.at or []:
        u, v = map(float, at.split(','))
        for c in comps:
            if any(_inside((u, v), T[t]) for t in c): sel += c; break
        else: raise SystemExit(f'no island under {at}')
    assert sel, 'select islands with --at, --island or --all'
    mask = Image.new('L', (W, H), 0); d = ImageDraw.Draw(mask)
    for t in sorted(set(sel)): d.polygon([(x * W, y * H) for x, y in T[t]], fill=255)
    M = np.asarray(mask) > 0; ys, xs = np.where(M); m = a.margin
    box = (max(0, xs.min() - m), max(0, ys.min() - m), min(W, xs.max() + 1 + m), min(H, ys.max() + 1 + m))
    crop = page.crop(box); cm = mask.crop(box); cw, ch = crop.size
    asp = min((1, 1), (2, 3), (3, 2), key=lambda r: abs(np.log((cw / ch) / (r[0] / r[1]))))     # aspects generators return
    CW, CH = (a.size, round(a.size * asp[1] / asp[0])) if asp[0] >= asp[1] else (round(a.size * asp[0] / asp[1]), a.size)
    s = min(CW / cw, CH / ch) * .92; size = (max(1, round(cw * s)), max(1, round(ch * s))); ox, oy = (CW - size[0]) // 2, (CH - size[1]) // 2
    canvas = Image.new('RGB', (CW, CH), (128, 128, 128)); canvas.paste(crop.convert('RGB').resize(size, Image.LANCZOS), (ox, oy)); canvas.save(O / 'EDIT_INPUT.png')
    cmS = cm.resize(size, Image.NEAREST); full = Image.new('L', (CW, CH), 0); full.paste(cmS, (ox, oy))
    em = Image.new('RGBA', (CW, CH), (0, 0, 0, 255)); em.putalpha(Image.eval(full, lambda x: 0 if x else 255)); em.save(O / 'EDIT_MASK.png')
    guide = canvas.copy(); guide.paste((255, 0, 255), mask=full.filter(ImageFilter.FIND_EDGES)); guide.save(O / 'GUIDE.png')
    cm.save(O / 'ISLAND_MASK_PAGE_CROP.png')
    rec = dict(page=str(Path(a.page).resolve()), page_sha256=sha(a.page), page_size=[W, H], material=a.mat,
               triangles=len(set(sel)), box=list(map(int, box)), canvas=[CW, CH], placed=[ox, oy, ox + size[0], oy + size[1]], scale=s, mask_texels=int(M.sum()),
               edit_input_sha256=sha(O / 'EDIT_INPUT.png'), edit_mask_sha256=sha(O / 'EDIT_MASK.png'), prompt_template=PROMPT)
    if a.uv_json: rec.update(uv_json=Path(a.uv_json).name, uv_json_sha256=sha(a.uv_json), source_id=src['source_id'], uv_layer=src['uv_layer'], origin='top-left')
    else: rec.update(gr2=Path(a.gr2).name, gr2_sha256=sha(a.gr2))
    (O / 'ISLAND.json').write_text(json.dumps(rec, indent=1)); print('EXTRACT', O, rec['triangles'], 'triangles', rec['mask_texels'], 'texels, edit', size)


def _inside(p, t):
    (x, y), (a_, b_, c_) = p, t
    d = lambda p1, p2, p3: (p1[0] - p3[0]) * (p2[1] - p3[1]) - (p2[0] - p3[0]) * (p1[1] - p3[1])
    s1, s2, s3 = d((x, y), a_, b_), d((x, y), b_, c_), d((x, y), c_, a_)
    return not ((s1 < 0 or s2 < 0 or s3 < 0) and (s1 > 0 or s2 > 0 or s3 > 0))


def _edges(img):
    g = np.asarray(img.convert('L'), float); gx = np.zeros_like(g); gy = np.zeros_like(g)
    gx[:, 1:-1] = g[:, 2:] - g[:, :-2]; gy[1:-1] = g[2:] - g[:-2]; return np.hypot(gx, gy)


def apply(a):
    D = Path(a.dir); rec = json.loads((D / 'ISLAND.json').read_text()); CW, CH = rec['canvas']; px0, py0, px1, py1 = rec['placed']
    painted = Image.open(a.painted).convert('RGB')               # any returned size: the canvas aspect is a generator aspect
    aspect_error = abs((painted.width / painted.height) / (CW / CH) - 1)
    if aspect_error > .02:
        raise ValueError('Generated canvas aspect differs by more than 2%; register its placement before applying, do not stretch it')
    assert sha(D / 'EDIT_INPUT.png') == rec['edit_input_sha256'], 'edit input changed after extraction'
    assert sha(D / 'EDIT_MASK.png') == rec['edit_mask_sha256'], 'edit mask changed after extraction'
    painted = painted.resize((CW, CH), Image.LANCZOS)
    inp = Image.open(D / 'EDIT_INPUT.png').convert('RGB'); mask = np.asarray(Image.open(D / 'EDIT_MASK.png'))[..., 3] == 0
    e0, e1 = _edges(inp)[mask], _edges(painted)[mask]
    structure = float(np.corrcoef(e0, e1)[0, 1]) if e0.std() > 0 and e1.std() > 0 else 0.
    ok = a.restyle or structure >= a.min_structure
    page = Image.open(rec['page']).convert('RGBA'); assert sha(rec['page']) == rec['page_sha256'], 'the page changed since extract'
    x0, y0, x1, y1 = rec['box']; cw, ch = x1 - x0, y1 - y0
    small = painted.crop((px0, py0, px1, py1)).resize((cw, ch), Image.BOX)                     # box prefilter to the page texel footprint
    cm = Image.open(D / 'ISLAND_MASK_PAGE_CROP.png').convert('L')
    if a.feather: cm = Image.fromarray((np.minimum(np.asarray(cm), np.asarray(cm.filter(ImageFilter.MinFilter(2 * a.feather + 1)).filter(ImageFilter.GaussianBlur(a.feather))))).astype(np.uint8))
    region = page.crop(rec['box']); out_rgb = Image.composite(small.convert('RGBA'), region, cm)
    out_rgb.putalpha(region.getchannel('A'))                         # alpha (cutouts) is never repainted
    new = page.copy(); new.paste(out_rgb, rec['box'][:2])
    original_array, new_array = np.asarray(page), np.asarray(new)
    protect = np.ones(original_array.shape[:2], bool)
    protect[y0:y1, x0:x1] = np.asarray(Image.open(D / 'ISLAND_MASK_PAGE_CROP.png')) == 0
    outside_changed = int(np.any(original_array != new_array, axis=-1)[protect].sum())
    alpha_changed = int((original_array[..., 3] != new_array[..., 3]).sum())
    assert outside_changed == 0 and alpha_changed == 0, 'Protected pixels or alpha changed'
    res = dict(painted=str(Path(a.painted).resolve()), painted_sha256=sha(a.painted), route=a.route, calls=a.calls, cost_usd=a.cost,
               prompt=(Path(a.prompt_file).read_text(encoding='utf-8') if a.prompt_file else a.prompt), structure=round(structure, 3),
               min_structure=a.min_structure, restyle=a.restyle, gate='PASS' if ok else 'FAIL')
    res.update(outside_changed_texels=outside_changed, alpha_changed_texels=alpha_changed, aspect_error=aspect_error)
    if not ok and not a.force:
        (D / 'APPLY.json').write_text(json.dumps(res, indent=1)); raise SystemExit(f'GATE FAIL: structure {structure:.2f} < {a.min_structure} (the painting moved the island\'s edges; --restyle if a new structure was asked)')
    new.save(a.out_page); res.update(out_page=str(Path(a.out_page).resolve()), out_page_sha256=sha(a.out_page))
    if a.ddt:
        sys.path.insert(0, str(HAVOK)); import ddt_patch as DP     # noqa: E402
        chm = (np.any(np.asarray(new) != np.asarray(page), -1) * 255).astype(np.uint8); Image.fromarray(chm).save(D / 'CHANGED.png')
        res['ddt_blocks'] = DP.patch(a.ddt, a.out_page, str(D / 'CHANGED.png'), a.ddt_out); res['ddt_out_sha256'] = sha(a.ddt_out)
    (D / 'APPLY.json').write_text(json.dumps(res, indent=1, default=str)); print('APPLY', res['gate'], 'structure', res['structure'], '->', a.out_page)


ap = argparse.ArgumentParser(); sub = ap.add_subparsers(dest='cmd', required=True)
e = sub.add_parser('extract'); e.add_argument('--page', required=True); src = e.add_mutually_exclusive_group(required=True); src.add_argument('--gr2'); src.add_argument('--uv-json'); e.add_argument('--mat')
e.add_argument('--at', action='append'); e.add_argument('--island', action='append', type=int); e.add_argument('--all', action='store_true')
e.add_argument('--out', required=True); e.add_argument('--size', type=int, default=1024); e.add_argument('--margin', type=int, default=6)
p = sub.add_parser('apply'); p.add_argument('--dir', required=True); p.add_argument('--painted', required=True); p.add_argument('--out-page', required=True)
p.add_argument('--route', required=True, choices=['native-gpt', 'native-other', 'harness-gemini', 'harness-openai', 'manual'])
p.add_argument('--prompt'); p.add_argument('--prompt-file'); p.add_argument('--calls', type=int, default=1); p.add_argument('--cost', default='unknown')
p.add_argument('--min-structure', type=float, default=.35); p.add_argument('--restyle', action='store_true'); p.add_argument('--force', action='store_true')
p.add_argument('--feather', type=int, default=1); p.add_argument('--ddt'); p.add_argument('--ddt-out')
a = ap.parse_args(); extract(a) if a.cmd == 'extract' else apply(a)
