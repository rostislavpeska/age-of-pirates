"""Synthetic checks of small_size_check.py: blotches on a subject raise 'mottle'; a dark subject on a dark backdrop
stands out less ('subject') than a light one; verdicts and ranks are written."""
import json, subprocess, sys, tempfile
from pathlib import Path
import numpy as np
from PIL import Image

HERE = Path(__file__).parent


def picture(subject_rgb, blotches=False, seed=0):
    im = np.full((256, 256, 3), (30, 31, 26), np.float32)              # dark olive backdrop
    im[60:200, 50:206] = subject_rgb                                    # the "building"
    im[60:90, 50:206] *= .8                                             # a roof band (a big shape)
    if blotches:
        rng = np.random.default_rng(seed)
        for _ in range(140):
            y, x = rng.integers(62, 196), rng.integers(52, 202)
            im[y:y + 6, x:x + 6] *= rng.uniform(.6, 1.4)
    return Image.fromarray(np.uint8(np.clip(im, 0, 255)))


def run(tmp, pics, refs):
    args = [sys.executable, str(HERE / 'small_size_check.py'), '--out', str(tmp / 'out'), '--sizes', '128,64']
    for kind, items in (('--img', pics), ('--ref', refs)):
        for n, im in items.items():
            im.save(tmp / f'{n}.png'); args += [kind, f'{n}={tmp / (n + ".png")}']
    subprocess.run(args, check=True, capture_output=True)
    return json.loads((tmp / 'out' / 'SMALL_SIZE.json').read_text(encoding='utf-8'))


def test_mottle_and_subject():
    with tempfile.TemporaryDirectory() as t:
        r = run(Path(t), {'clean': picture((150, 140, 120)), 'dirty': picture((150, 140, 120), True),
                          'dark': picture((48, 50, 46))}, {'ref': picture((170, 120, 90))})
        P = r['pictures']
        for n in ('128', '64'):
            assert P['dirty']['per_size'][n]['mottle'] > P['clean']['per_size'][n]['mottle']
            assert P['dark']['per_size'][n]['subject'] < P['clean']['per_size'][n]['subject']
            assert r['rank'][n]['mottle'][0] != 'dirty'
        assert 'verdict' in P['clean'] and (Path(t) / 'out' / 'small_size_sheet.png').is_file()


if __name__ == '__main__':
    test_mottle_and_subject(); print('ok')
