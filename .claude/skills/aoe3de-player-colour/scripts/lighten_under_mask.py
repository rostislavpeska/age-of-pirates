"""lighten_under_mask.py - decide, and optionally apply, the BaseColor change under an AoE3 DE player-colour mask.

The game multiplies: albedo_lin = BaseColor_lin * lerp(1, PlayerColour_lin, Details.R). A saturated or dark base under
the mask therefore tints and darkens the player colour (gold x blue = dark navy). Owner rule (Age of Pirates,
2026-09-29): "Only light objects like sails / white walls don't need basecolor transform beneath player color override".

Decision (pc_common.classify, on the texels under the full mask, Details.R >= 250):
    KEEP     mean Rec.709 luma of the 8-bit sRGB base >= 200 AND mean Lab chroma <= 20   (sails, white / cream walls)
    LIGHTEN  anything else (gold, wood, painted colours): mode 'partial' or 'neutral'
Calibrated on the Korean TC: cream walls luma 210.8 / chroma 11.4 = KEEP; gold gable cells 127.2 / 41.2 = LIGHTEN.

Modes (the owner chooses after seeing the in-game look with 2-3 player colours):
    report   (default) print the verdict and the predicted in-game colours; write nothing
    keep     the BaseColor is not changed (the output is a byte copy)
    neutral  grey = target x (luma / mean luma) ^ grain_gamma: desaturated, lifted to the target mean, the grain and soot
             kept as relative brightness (compressed so a large lift does not clip), capped at grey_max (linear)
    partial  the neutral grey with partial_keep of the lightened texel's own colour kept (some hue, at the target luma)
Blend weight = Details.R: only texels with R > 0 (inside --region when given) can change; a 1-texel soft edge moves by
its mask fraction. Every other texel is copied unchanged, and the tool asserts it.

    python lighten_under_mask.py --basecolor P2048_BaseColor.png --details P2048_Details.png [--region gables.png]
           [--mode report|keep|partial|neutral] [--out OUT_BaseColor.png] [--report r.json]
           [--target-srgb 211] [--partial-keep 0.35] [--grain-gamma 0.6] [--grey-max 0.92] [--players 1,2,5]
--region (any PNG, non-zero = inside) limits the change to one field, e.g. the gable cells while cream walls under the
same Details map are kept. Exit code 0; a mode that contradicts the verdict prints WARNING (the owner may still choose it).
"""
import argparse
import json
import shutil
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import pc_common as C  # noqa: E402

TARGET_SRGB = 211.0     # mean sRGB of the lightened field (AoP walls' neutral grey; vanilla China/Japan/East TC 231-255)
GRAIN_GAMMA = 0.6       # grey = target x (Y / mean Y) ^ 0.6 (gamma 1 clipped 1388 light grain texels on a x2.9 lift)
GREY_MAX = 0.92         # linear ceiling: no clipped white
PARTIAL_KEEP = 0.35     # 'partial': share of the lightened texel's own colour kept


def lighten(lin, w, full, mode, target_srgb=TARGET_SRGB, grain_gamma=GRAIN_GAMMA, grey_max=GREY_MAX,
            partial_keep=PARTIAL_KEEP):
    """lin [H, W, 3] linear base; w [H, W] weight 0..1 (Details.R inside the region); full = bool texels that set the
    mean -> (new linear base, report). Texels with w == 0 come back unchanged."""
    if mode == 'keep':
        return lin.copy(), dict(mode=mode)
    assert mode in ('neutral', 'partial'), mode
    Y = np.maximum(lin @ C.LUMA709, 1e-5)
    ref = full if full.any() else w > 0
    ymean = float(Y[ref].mean())
    grey_raw = float(C.s2l(target_srgb)) * (Y / ymean) ** grain_gamma
    grey = np.clip(grey_raw, 0, grey_max)[..., None]
    tgt = np.repeat(grey, 3, -1)
    if mode == 'partial':
        tgt = tgt * (1 - partial_keep) + np.clip(lin * (grey / Y[..., None]), 0, grey_max) * partial_keep
    ww = w[..., None].astype(np.float64)
    out = lin * (1 - ww) + tgt * ww
    return out, dict(mode=mode, target_srgb=target_srgb, grain_gamma=grain_gamma, grey_max=grey_max,
                     partial_keep=partial_keep if mode == 'partial' else 0.0,
                     mean_linear_luma_before=round(ymean, 4), clipped_texels=int(((grey_raw > grey_max) & (w > 0)).sum()))


def run(basecolor, details, mode='report', out=None, region=None, report=None, players=(1, 2, 5), **kw):
    bc = C.read_rgb8(basecolor)
    r = C.read_details_r(details)
    assert r.shape == bc.shape[:2], f'Details {r.shape} and BaseColor {bc.shape[:2]} differ in size: vanilla keeps them equal'
    if region is not None:
        reg = C.read_rgb8(region).max(-1) > 0
        assert reg.shape == r.shape, 'region size differs'
        r = np.where(reg, r, 0.0)
    full = r >= C.FULL_R / 255.0
    before = C.base_stats(bc, full)
    verdict, why = C.classify(before)
    rep = dict(basecolor=str(basecolor), details=str(details), region=str(region) if region else None,
               basecolor_sha256=C.sha_file(basecolor), details_sha256=C.sha_file(details), mode=mode,
               mask_texels=int((r > 0).sum()), full_texels=int(full.sum()), soft_texels=int(((r > 0) & ~full).sum()),
               verdict=verdict, verdict_reason=why, thresholds=dict(luma_min=C.LIGHT_LUMA_MIN, chroma_max=C.LIGHT_CHROMA_MAX),
               stats_before=before, ingame_before=C.predicted_colours(bc, r, full, players))
    warn = None
    if mode == 'keep' and verdict == 'lighten':
        warn = 'keeping a saturated/dark base: the player colour will be tinted and darkened (e.g. gold x blue = dark navy)'
    elif mode in ('partial', 'neutral') and verdict == 'keep':
        warn = 'lightening a light object: the owner rule keeps light objects (sails, white walls) untouched'
    rep['warning'] = warn
    if mode != 'report':
        assert out, '--out is required for keep / partial / neutral'
        out = Path(out)
        assert out.resolve() != Path(basecolor).resolve(), 'write to a new file, never over the input'
        if mode == 'keep':
            shutil.copy2(basecolor, out)
            rep['lighten'] = dict(mode='keep')
            new = bc
        else:
            lin = C.s2l(bc)
            new_lin, lrep = lighten(lin, r, full, mode, **kw)
            new = bc.copy()
            ch = r > 0
            new[ch] = C.l2s(new_lin[ch])
            C.write_rgb8(out, new)
            rep['lighten'] = lrep
        changed = (new != bc).any(-1)
        rep['result'] = dict(out=str(out), texels_changed=int(changed.sum()),
                             changed_outside_mask=int((changed & (r == 0)).sum()),
                             stats_after=C.base_stats(new, full), ingame_after=C.predicted_colours(new, r, full, players))
        rep['result']['verdict_after'] = C.classify(rep['result']['stats_after'])[0]
        assert rep['result']['changed_outside_mask'] == 0, 'a texel outside the mask changed'
    if report:
        Path(report).write_text(json.dumps(rep, indent=1))
    return rep


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--basecolor', required=True); ap.add_argument('--details', required=True)
    ap.add_argument('--region'); ap.add_argument('--mode', default='report', choices=('report', 'keep', 'partial', 'neutral'))
    ap.add_argument('--out'); ap.add_argument('--report')
    ap.add_argument('--target-srgb', type=float, default=TARGET_SRGB)
    ap.add_argument('--partial-keep', type=float, default=PARTIAL_KEEP)
    ap.add_argument('--grain-gamma', type=float, default=GRAIN_GAMMA)
    ap.add_argument('--grey-max', type=float, default=GREY_MAX)
    ap.add_argument('--players', default='1,2,5')
    a = ap.parse_args(argv)
    rep = run(a.basecolor, a.details, a.mode, a.out, a.region, a.report, tuple(int(p) for p in a.players.split(',')),
              target_srgb=a.target_srgb, grain_gamma=a.grain_gamma, grey_max=a.grey_max, partial_keep=a.partial_keep)
    s = rep['stats_before']
    print(f'VERDICT {rep["verdict"].upper()}: {rep["verdict_reason"]}')
    print(f'  under the full mask: {s.get("texels", 0)} texels, mean sRGB {s.get("mean_srgb")}, in-game {rep["ingame_before"]}')
    if rep.get('warning'):
        print('WARNING', rep['warning'])
    if 'result' in rep:
        r = rep['result']
        print(f'MODE {a.mode}: {r["texels_changed"]} texels changed, {r["changed_outside_mask"]} outside the mask; after: mean '
              f'sRGB {r["stats_after"].get("mean_srgb")}, verdict {r["verdict_after"]}, in-game {r["ingame_after"]}')
    return rep


if __name__ == '__main__':
    main()
