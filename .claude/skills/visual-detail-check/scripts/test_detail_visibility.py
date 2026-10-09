"""Synthetic checks of detail_visibility.py: a structured line detail is found and ranks above a faint one; a change
below the JND gives an empty footprint (invisible)."""
import json, subprocess, sys, tempfile
from pathlib import Path
import numpy as np
from PIL import Image

HERE = Path(__file__).parent


def run(tmp, base, variants, extra=()):
    Image.fromarray(base).save(tmp / 'base.png')
    args = [sys.executable, str(HERE / 'detail_visibility.py'), '--base', str(tmp / 'base.png'), '--out', str(tmp / 'out'), *extra]
    for n, im in variants.items():
        Image.fromarray(im).save(tmp / f'{n}.png'); args += ['--variant', f'{n}={tmp / (n + ".png")}']
    subprocess.run(args, check=True, capture_output=True)
    return json.loads((tmp / 'out' / 'DETAIL_VISIBILITY.json').read_text(encoding='utf-8'))


def texture():
    rng = np.random.default_rng(1)
    b = np.full((120, 160, 3), 90, np.float32) + rng.normal(0, 6, (120, 160, 1))
    return np.uint8(np.clip(b, 0, 255))


def with_steps(base, amp):
    im = base.astype(np.float32).copy()
    for y in range(20, 100, 8):                                  # a stepped strip: lighter band with dark lap lines
        im[y:y + 6, 70:86] += amp; im[y + 6:y + 8, 70:86] -= amp
    return np.uint8(np.clip(im, 0, 255))


def test_structured_detail_ranks_by_strength():
    with tempfile.TemporaryDirectory() as t:
        b = texture()
        r = run(Path(t), b, {'strong': with_steps(b, 40), 'faint': with_steps(b, 12)}, ['--verdict', 'faint=weak', '--verdict', 'strong=strong'])
        s, f = r['variants']['strong'], r['variants']['faint']
        assert r['footprint_px'] > 0
        assert s['edge_ratio'] > f['edge_ratio'] > 1.0
        assert s['dE_p90'] > f['dE_p90']
        band = r['band']['edge_ratio']
        assert band['above (too weak at or below)'] == f['edge_ratio'] and band['below (too strong at or above)'] == s['edge_ratio']
        assert (Path(t) / 'out' / 'detail_sheet.png').is_file()


def test_change_below_jnd_is_invisible():
    with tempfile.TemporaryDirectory() as t:
        b = texture()
        r = run(Path(t), b, {'tiny': with_steps(b, 1)})
        assert r['footprint_px'] == 0 and 'INVISIBLE' in r['note']


if __name__ == '__main__':
    test_structured_detail_ranks_by_strength(); test_change_below_jnd_is_invisible(); print('ok')
