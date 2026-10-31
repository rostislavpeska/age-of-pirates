"""Player colour in UI icons (owner's game test 2026-10-09: near-black sashes on the Korean monk portraits). The game
multiplies the player colour into the RGB stored under a transparent pixel, so that RGB must stay light grey.

    python -m pytest .claude/skills/icon-forge/scripts -q
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import iconforge  # noqa: E402
import pccheck  # noqa: E402
import pcfix  # noqa: E402


def art(tmp_path, under=(200, 200, 200)):
    """256x256 opaque brown 'portrait' with a transparent diagonal sash whose stored RGB is `under`."""
    a = np.zeros((256, 256, 4), np.uint8)
    a[..., :3] = (120, 80, 50)
    a[..., 3] = 255
    yy, xx = np.mgrid[0:256, 0:256]
    sash = (np.abs(xx - yy) < 18) & (xx > 40) & (xx < 215)
    a[sash, :3] = under
    a[sash, 3] = 0
    p = tmp_path / 'art.png'
    Image.fromarray(a).save(p)
    return p


def test_dark_stored_rgb_is_flagged_and_light_passes(tmp_path):
    assert pccheck.region_luma(art(tmp_path, (0, 0, 0)))[0] < 60
    assert pccheck.region_luma(art(tmp_path, (200, 200, 200)))[0] > 150


def test_pcfix_lifts_the_region_and_keeps_alpha(tmp_path):
    p = art(tmp_path, (21, 1, 21))
    alpha = np.array(Image.open(p))[..., 3].copy()
    res, _ = pcfix.fix(p)
    res.save(p)
    assert pccheck.region_luma(p)[0] >= 150
    assert (np.array(Image.open(p))[..., 3] == alpha).all()


def test_iconforge_keeps_the_rgb_under_the_player_colour(tmp_path):
    out = tmp_path / 'icon.png'
    iconforge.main([str(art(tmp_path)), str(out), '--kind', 'unit'])
    med, n = pccheck.region_luma(out)
    assert n > 50 and med > 150                    # Pillow's premultiplied resize/composite wrote (0,0,0) here


def test_mod_unit_and_building_art_has_no_dark_player_colour():
    """All AoP unit/building icons and portraits store light RGB under their player-colour area (30 repaired
    2026-10-09 with pcfix.py; the art-to-frame gap and specks are not player colour and are skipped)."""
    import pytest
    pytest.importorskip('scipy')
    repo = HERE.parents[3]
    dark = []
    for root in ('data/wpfg/resources/art/units', 'data/wpfg/resources/art/buildings'):
        for p in sorted((repo / root).rglob('*.png')):
            r = pccheck.region_luma(p)
            if r and r[0] < 60:
                dark.append('%s %.0f' % (p.relative_to(repo).as_posix(), r[0]))
    assert not dark, dark


def test_pcfix_reaches_an_area_whose_soft_edge_touches_a_corner(tmp_path):
    """Bohemian knight 2026-10-09: soft (alpha 128-249) pixels joined the sash to an image corner; the repair skipped
    it while the check still saw it dark. Both now judge the same area (alpha < 128)."""
    p = art(tmp_path, (10, 10, 10))
    a = np.array(Image.open(p))
    a[0:200, 0:3, 3] = 200                         # a soft strip from the top-left corner down the left edge ...
    a[180:200, 0:60, 3] = 200                      # ... and across to the sash
    Image.fromarray(a).save(p)
    res, _ = pcfix.fix(p)
    res.save(p)
    assert pccheck.region_luma(p)[0] >= 150
