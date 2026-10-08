"""Replay an AoE3DE Flag Maker PSD template with a new flag image, without Photoshop.

Each template = cached raster layers (base, darkener, lightener, frame) + one 'Flag' smart object placed
with Trnf (quad) and optionally a 4x4 custom envelope warp, composited with Photoshop blend modes.
We re-render only the Flag smart object from a new flat flag image and reuse every other layer's
cached pixels.

  python flagmaker_render.py TEMPLATE.psd FLAG.png OUT.png [--validate]

Templates: "Age of Empires III Definitive Edition Flag Maker Pack" v1.0.2.2 by EmpAhmadK (free for AoE3DE
modding; aoe3de-flagmaker.ahmadalikarim.com) - kept outside the repo. Needs `pip install psd-tools` (run it from
a venv; on Windows a short venv path avoids the long-path install error). Validated 2026-10-08 against each
template's own saved composite: mean difference 0.1-0.7 % (plain templates), 4-5 % (postgame warps).
Template -> file (vanilla Japanese sizes): General Flag -> flags/Flag_X.png 512x341, Techtree Flag ->
flags/Techtree_X.png, Definitive UI Button -> flags/flag_hc_X.png (1:1 flag), Legacy UI Button ->
flags/flag_hc_legacy_X.png (12:7 flag), Flag Icon -> eso/flag_X_icon.png (1:1), Left Postgame Flag ->
flags/postgame_flag_X.png, Right Postgame Flag -> flags/flag_thin_right_X.png (feed the design flipped, as
the template's README says), Object Flag -> 512x512 PNG for flag_ddt.py.

--validate renders the template's own placeholder content and reports the difference against the
PSD's saved composite (proves the compositor before it is trusted with a new flag).
"""
import io, sys
import numpy as np
from PIL import Image
from psd_tools import PSDImage
from psd_tools.constants import Tag


def so_data(layer):
    return layer.tagged_blocks.get_data(Tag.SMART_OBJECT_LAYER_DATA1).data


def so_content(layer):
    so = layer.smart_object
    raw = so.data
    if so.filetype in (b'png', 'png', b'jpg', 'jpg'):
        return Image.open(io.BytesIO(raw)).convert('RGBA')
    return PSDImage.open(io.BytesIO(raw)).composite().convert('RGBA')


def bern3(t):
    t = t[..., None]
    return np.concatenate([(1 - t) ** 3, 3 * t * (1 - t) ** 2, 3 * t ** 2 * (1 - t), t ** 3], axis=-1)


def render_so(layer, content, canvas_wh, ss=4):
    """Rasterise smart object `layer` with replacement `content` (PIL RGBA) onto a canvas. -> HxWx4 float"""
    d = so_data(layer)
    q = np.array(d[b'Trnf'], dtype=np.float64).reshape(4, 2)  # TL TR BR BL in canvas px
    w = d[b'warp']
    b = w[b'bounds']
    left, top, right, btm = float(b[b'Left']), float(b[b'Top ']), float(b[b'Rght']), float(b[b'Btom'])
    W, H = canvas_wh
    # sample density: enough samples per canvas pixel along the quad's longest edges
    ex = max(np.linalg.norm(q[1] - q[0]), np.linalg.norm(q[2] - q[3]))
    ey = max(np.linalg.norm(q[3] - q[0]), np.linalg.norm(q[2] - q[1]))
    warped = w[b'warpStyle'].enum == b'warpCustom'
    if warped:
        ss = max(ss, 6)
    nu, nv = int(ex * ss) + 2, int(ey * ss) + 2
    u = (np.arange(nu) + 0.5) / nu
    v = (np.arange(nv) + 0.5) / nv
    if warped:
        mp = w[b'customEnvelopeWarp'][b'meshPoints']
        hx = np.array(list(mp[b'Hrzn'].values), dtype=np.float64)
        vy = np.array(list(mp[b'Vrtc'].values), dtype=np.float64)
        nu_o, nv_o = int(w.get(b'uOrder', 4)), int(w.get(b'vOrder', 4))
        assert len(hx) == nu_o * nv_o == 16, (len(hx), nu_o, nv_o)
        Px = hx.reshape(4, 4)  # [row j (v), col i (u)]
        Py = vy.reshape(4, 4)
        Bu, Bv = bern3(u), bern3(v)  # nu x 4, nv x 4
        # measured on the postgame templates: the mesh points are already canvas pixels (Trnf baked in)
        X = np.einsum('vj,ji,ui->vu', Bv, Px, Bu)
        Y = np.einsum('vj,ji,ui->vu', Bv, Py, Bu)
        if q[1, 0] < q[0, 0]:
            # measured on the Right Postgame template: its mesh is the Left template's, unflipped; the
            # horizontal flip lives only in Trnf. Map the mirrored reference span onto the Trnf span.
            r0, r1 = W - q[0, 0], W - q[1, 0]
            X = q[0, 0] + (X - r0) * (q[1, 0] - q[0, 0]) / (r1 - r0)
    else:
        s, t = np.meshgrid(u, v)
        # bilinear map of the unit square to the quad (exact for the rectangles used by the templates)
        X = (1 - s) * (1 - t) * q[0, 0] + s * (1 - t) * q[1, 0] + s * t * q[2, 0] + (1 - s) * t * q[3, 0]
        Y = (1 - s) * (1 - t) * q[0, 1] + s * (1 - t) * q[1, 1] + s * t * q[2, 1] + (1 - s) * t * q[3, 1]
    # colour: content sampled at (u, v) - the content is stretched to the smart object's own size
    ci = np.asarray(content.resize((nu, nv), Image.LANCZOS), dtype=np.float64) / 255.0
    acc = np.zeros((H, W, 4)); cnt = np.zeros((H, W))
    xi = np.floor(X).astype(np.int64); yi = np.floor(Y).astype(np.int64)
    ok = (xi >= 0) & (xi < W) & (yi >= 0) & (yi < H)
    idx = (yi[ok] * W + xi[ok])
    a = ci[..., 3][ok]
    for c in range(3):
        np.add.at(acc[..., c].reshape(-1), idx, ci[..., c][ok] * a)
    np.add.at(acc[..., 3].reshape(-1), idx, a)
    np.add.at(cnt.reshape(-1), idx, 1.0)
    out = np.zeros((H, W, 4))
    nz = acc[..., 3] > 0
    out[..., :3][nz] = acc[..., :3][nz] / acc[..., 3][nz][:, None]
    if not warped:
        # coverage: samples per pixel relative to the expected count
        expect = np.median(cnt[cnt > 0]) if (cnt > 0).any() else 1
        out[..., 3] = np.clip(acc[..., 3] / expect, 0, 1)
        return out
    # warped: alpha from the rasterised outline of the warped surface (4x supersampled), colour holes
    # inside it filled from neighbours - a stretched Bezier patch leaves gaps in a forward splat
    from PIL import ImageDraw
    k = 4
    edge = np.concatenate([np.stack([X[0], Y[0]], 1), np.stack([X[:, -1], Y[:, -1]], 1),
                           np.stack([X[-1, ::-1], Y[-1, ::-1]], 1), np.stack([X[::-1, 0], Y[::-1, 0]], 1)])
    big = Image.new('L', (W * k, H * k), 0)
    ImageDraw.Draw(big).polygon([(float(x) * k, float(y) * k) for x, y in edge], fill=255)
    cov = np.asarray(big.resize((W, H), Image.BOX), dtype=np.float64) / 255.0
    have = nz.copy()
    rgb = out[..., :3]
    for _ in range(64):
        need = (cov > 0) & ~have
        if not need.any():
            break
        s = np.zeros((H, W, 3)); n = np.zeros((H, W))
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                hv = np.roll(np.roll(have, dy, 0), dx, 1)
                s += np.roll(np.roll(rgb, dy, 0), dx, 1) * hv[..., None]; n += hv
        fill = need & (n > 0)
        rgb[fill] = s[fill] / n[fill][:, None]
        have |= fill
    meana = np.where(cnt > 0, acc[..., 3] / np.maximum(cnt, 1), 1.0)
    out[..., 3] = cov * meana
    return out


def layer_pixels(layer, canvas_wh):
    W, H = canvas_wh
    out = np.zeros((H, W, 4))
    im = layer.topil()
    if im is None:
        return out
    im = np.asarray(im.convert('RGBA'), dtype=np.float64) / 255.0
    x0, y0 = layer.left, layer.top
    paste(out, im, x0, y0)
    return out


def paste(out, im, x0, y0):
    H, W = out.shape[:2]
    h, w = im.shape[:2]
    sx0, sy0 = max(0, -x0), max(0, -y0)
    dx0, dy0 = max(0, x0), max(0, y0)
    dx1, dy1 = min(W, x0 + w), min(H, y0 + h)
    if dx1 > dx0 and dy1 > dy0:
        out[dy0:dy1, dx0:dx1] = im[sy0:sy0 + dy1 - dy0, sx0:sx0 + dx1 - dx0]


def mask_alpha(layer, canvas_wh):
    W, H = canvas_wh
    m = layer.mask
    full = np.full((H, W), (m.background_color or 0) / 255.0)
    mi = m.topil()
    if mi is not None:
        arr = np.asarray(mi.convert('L'), dtype=np.float64) / 255.0
        tmp = np.zeros((H, W, 1)); tmp[..., 0] = full
        paste(tmp, arr[..., None], m.left, m.top)
        full = tmp[..., 0]
    return full


def blend(mode, cb, cs):
    m = str(mode).split('.')[-1]
    if m == 'NORMAL':
        return cs
    if m == 'MULTIPLY':
        return cb * cs
    if m == 'SCREEN':
        return cb + cs - cb * cs
    if m == 'HARD_LIGHT':
        return np.where(cs <= 0.5, cb * 2 * cs, cb + (2 * cs - 1) - cb * (2 * cs - 1))
    if m == 'OVERLAY':
        return np.where(cb <= 0.5, 2 * cb * cs, 1 - 2 * (1 - cb) * (1 - cs))
    if m == 'SOFT_LIGHT':
        d = np.where(cb <= 0.25, ((16 * cb - 12) * cb + 4) * cb, np.sqrt(cb))
        return np.where(cs <= 0.5, cb - (1 - 2 * cs) * cb * (1 - cb), cb + (2 * cs - 1) * (d - cb))
    raise ValueError('blend mode ' + m)


def over(dst, src, mode, opacity):
    a_s = src[..., 3:4] * opacity
    a_d = dst[..., 3:4]
    cs, cb = src[..., :3], dst[..., :3]
    mixed = (1 - a_d) * cs + a_d * blend(mode, cb, cs)
    a_o = a_s + a_d * (1 - a_s)
    rgb = np.where(a_o > 0, ((1 - a_s) * a_d * cb + a_s * mixed) / np.maximum(a_o, 1e-9), 0)
    return np.concatenate([rgb, a_o], axis=-1)


def walk(container, visible=True):
    for layer in container:
        vis = visible and layer.visible
        if layer.kind == 'group':
            yield from walk(layer, vis)
        else:
            yield layer, vis


def render(psd_path, flag=None, log=print):
    psd = PSDImage.open(psd_path)
    W, H = psd.size
    dst = np.zeros((H, W, 4))
    for layer, vis in walk(psd):
        if not vis:
            continue
        kind = layer.kind
        if kind in ('brightnesscontrast', 'vibrance', 'huesaturation', 'levels', 'curves'):
            log('  skip adjustment', layer.name)
            continue
        if kind == 'smartobject' and layer.name.startswith('Flag'):
            content = flag if flag is not None else so_content(layer)
            src = render_so(layer, content, (W, H))
            log('  flag SO', layer.name, so_data(layer)[b'warp'][b'warpStyle'].enum)
        else:
            src = layer_pixels(layer, (W, H))
        if layer.has_mask():
            src[..., 3] *= mask_alpha(layer, (W, H))
        dst = over(dst, src, layer.blend_mode, layer.opacity / 255.0)
    return psd, np.clip(dst, 0, 1)


def to_img(arr):
    return Image.fromarray((arr * 255 + 0.5).astype(np.uint8), 'RGBA')


if __name__ == '__main__':
    tpl, flag_path, out = sys.argv[1:4]
    validate = '--validate' in sys.argv
    flag = None if validate else Image.open(flag_path).convert('RGBA')
    psd, arr = render(tpl, flag)
    to_img(arr).save(out)
    if validate:
        ref = np.asarray(psd.topil().convert('RGBA'), dtype=np.float64) / 255.0
        a = arr[..., 3:4]; r = ref[..., 3:4]
        diff = np.abs(arr[..., :3] * a - ref[..., :3] * r)
        print('validate', tpl, 'mean abs diff (premult rgb) %.4f  p99 %.4f  alpha diff %.4f' % (
            diff.mean(), np.percentile(diff, 99), np.abs(a - r).mean()))
        to_img(ref).save(out.replace('.png', '_ref.png'))
