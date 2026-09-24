"""mapview.minimap_detect on committed minimap crops (fixtures/*.png + *.json, 2026-09-24): the drawn disc, the ring
probes, the camera trapezoid's look-at point and the player stars (= the Explorers), plus synthetic images for
8-connectivity, chroma matching, a star drawn over a same-colour glyph, outlines cut by the rim (review F2) and
terrain painted next to the rim (review F1). Needs PIL (skipped without it)."""
import json
import math
import sys
from pathlib import Path

import pytest

Image = pytest.importorskip("PIL.Image")
ImageDraw = pytest.importorskip("PIL.ImageDraw")

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO))
from scripts.mapview import minimap_detect as MD  # noqa: E402
from scripts.mapview import transform as T  # noqa: E402

FIXTURES = Path(__file__).resolve().parent / "fixtures"
PARIS = json.loads((FIXTURES / "paris_editor_minimap.json").read_text(encoding="utf-8"))
INGAME = json.loads((FIXTURES / "ingame_hud_minimap.json").read_text(encoding="utf-8"))
LONDON = json.loads((FIXTURES / "london4p_editor_minimap.json").read_text(encoding="utf-8"))
RIM_TERRAIN = ((70, 80, 30), (90, 72, 32), (80, 75, 40), (100, 80, 35), (60, 50, 20))   # review F1: all dark-gold


def _crop(fix):
    return Image.open(FIXTURES / fix["image"]).convert("RGB")


def _measure(fix):
    return MD.measure_disc(_crop(fix))


def _paint_annulus(img, cx, cy, lo, hi, colour):
    img = img.copy()
    px = img.load()
    W, H = img.size
    for y in range(H):
        for x in range(W):
            if lo <= math.hypot(x - cx, y - cy) <= hi:
                px[x, y] = colour
    return img


@pytest.mark.parametrize("fix", [PARIS, INGAME, LONDON], ids=["editor", "ingame", "london_live"])
class TestDisc:
    def test_measure_disc_within_half_a_pixel(self, fix):
        m = _measure(fix)
        ox, oy = fix["crop_offset"]
        d = fix["disc"]
        assert abs(m.cx + ox - d["cx"]) <= 0.5 and abs(m.cy + oy - d["cy"]) <= 0.5
        assert abs(m.r_disc - d["r_disc"]) <= 0.5 and abs(m.r_line - d["r_line"]) <= 0.5
        # the crop reads what the full frame read (2026-09-24)
        f = d["full_frame"]
        assert abs(d["cx"] - f["cx"]) <= 0.5 and abs(d["cy"] - f["cy"]) <= 0.5 and abs(d["r_disc"] - f["r_disc"]) <= 0.5
        assert abs(m.r_line / m.r_disc - MD.RING_RATIO) <= MD.RING_RATIO_TOL

    def test_probes_ok_and_dimmed(self, fix):
        img = _crop(fix)
        m = MD.measure_disc(img)
        assert len(m.probes) >= 4 and MD.probes_ok(img, m.probes)[0]
        dim = img.point(lambda v: int(v * 0.63))          # a modal dialog dims the screen to about 0.63x
        ok, good, n = MD.probes_ok(dim, m.probes)
        assert not ok and good == 0
        with pytest.raises(ValueError):
            MD.measure_disc(dim)

    def test_trapezoid_look_at(self, fix):
        m = _measure(fix)
        t = MD.find_trapezoid(_crop(fix), m.cx, m.cy, m.r_disc)
        ox, oy = fix["crop_offset"]
        assert t is not None and t["leg_support"] >= 0.7 and t["method"] == "outline"
        assert t["clipped"] == fix.get("trapezoid_clipped", False)
        assert abs(t["look_at"][0] + ox - fix["look_at"][0]) <= 0.5 and abs(t["look_at"][1] + oy - fix["look_at"][1]) <= 0.5


def test_ingame_look_at_matches_the_full_frame():
    assert INGAME["look_at"] == INGAME["look_at_full_frame"] == [2448.7, 933.2]
    assert LONDON["look_at"] == LONDON["look_at_full_frame"] == [2183.6, 908.5]


# ----------------------------------------------------------------------------- review F1: terrain next to the rim
class TestRimTerrain:
    """The old outward scan took dark-gold terrain next to the rim for the ring's band (r_disc 120.5 instead of
    130.5, every gate passing). The inward scan reads the band that touches the bright line."""

    @pytest.mark.parametrize("fix", [PARIS, INGAME], ids=["editor", "ingame"])
    @pytest.mark.parametrize("colour", RIM_TERRAIN)
    def test_terrain_up_to_the_rim_leaves_the_rim(self, fix, colour):
        img = _crop(fix)
        m0 = MD.measure_disc(img)
        m = MD.measure_disc(_paint_annulus(img, m0.cx, m0.cy, m0.r_disc - 12, m0.r_disc - 0.5, colour))
        assert abs(m.r_disc - m0.r_disc) <= 0.1 and abs(m.cx - m0.cx) <= 0.1 and abs(m.cy - m0.cy) <= 0.1

    @pytest.mark.parametrize("fix", [PARIS, INGAME], ids=["editor", "ingame"])
    def test_terrain_over_the_dark_edge_line(self, fix):
        """Painted half a pixel past the rim (over part of the ring's dark edge line): within 0.5 px, or refused."""
        img = _crop(fix)
        m0 = MD.measure_disc(img)
        try:
            m = MD.measure_disc(_paint_annulus(img, m0.cx, m0.cy, m0.r_disc - 12, m0.r_disc + 0.5, (70, 80, 30)))
        except ValueError:
            return
        assert abs(m.r_disc - m0.r_disc) <= 0.5

    @pytest.mark.parametrize("fix", [PARIS, INGAME], ids=["editor", "ingame"])
    def test_terrain_merged_with_the_band_is_refused(self, fix):
        img = _crop(fix)
        m0 = MD.measure_disc(img)
        with pytest.raises(ValueError, match="merged"):
            MD.measure_disc(_paint_annulus(img, m0.cx, m0.cy, m0.r_disc - 12, m0.r_disc + 1.0, (70, 80, 30)))

    @pytest.mark.parametrize("fix", [PARIS, LONDON], ids=["paris", "london_live"])
    def test_ring_ratio_gate(self, fix):
        """The dark edge line painted dark-gold: the band reads 1 px deeper, line / rim 1.051 - refused."""
        img = _crop(fix)
        m0 = MD.measure_disc(img)
        with pytest.raises(ValueError, match="geometry"):
            MD.measure_disc(_paint_annulus(img, m0.cx, m0.cy, m0.r_disc + 0.3, m0.r_disc + 1.3, (79, 62, 19)))


# ----------------------------------------------------------------------------- review F2: outlines cut by the rim
R_SYN, C_SYN = 130.0, (160.0, 160.0)


def _outline(corners=None, lines=()):
    """A 320x320 synthetic minimap: dark map, the white outline (1 px lines), then everything beyond the rim painted
    with the ring's dark colour - the ring hides whatever part of the outline lies outside the disc."""
    img = Image.new("RGB", (320, 320), (40, 70, 38))
    d = ImageDraw.Draw(img)
    if corners:
        TL, TR, BL, BR = corners
        for a, b in ((TL, TR), (TR, BR), (BR, BL), (BL, TL)):
            d.line([a, b], fill=(255, 255, 255), width=1)
    for a, b in lines:
        d.line([a, b], fill=(255, 255, 255), width=1)
    return _paint_annulus(img, C_SYN[0], C_SYN[1], R_SYN - 0.5, 1e9, (40, 35, 24))


class TestTrapezoidClipped:
    def test_whole_outline(self):
        c = ((100, 120), (164, 120), (115, 147), (149, 147))
        t = MD.find_trapezoid(_outline(c), C_SYN[0], C_SYN[1], R_SYN)
        want = MD._intersect(c[0], c[3], c[1], c[2])
        assert t["method"] == "outline" and not t["clipped"] and t["rebuilt"] == []
        assert math.dist(t["look_at"], want) <= 0.2

    def test_top_left_under_the_rim_is_rebuilt(self):
        """The London P1 case (ldn_hb2_generated): the far edge runs under the ring on the left."""
        c = ((60, 60), (124, 60), (75, 87), (109, 87))           # TL 141 px from the centre, the rest inside
        assert math.dist(c[0], C_SYN) > R_SYN and all(math.dist(p, C_SYN) < R_SYN - 10 for p in c[1:])
        t = MD.find_trapezoid(_outline(c), C_SYN[0], C_SYN[1], R_SYN)
        want = MD._intersect(c[0], c[3], c[1], c[2])
        assert t["method"] == "mirror" and t["clipped"] and t["rebuilt"] == ["TL"]
        assert math.dist(t["TL"], c[0]) <= 1.0 and math.dist(t["look_at"], want) <= 1.0

    def test_bottom_right_under_the_rim_is_rebuilt(self):
        c = ((170, 255), (234, 255), (185, 282), (219, 282))     # BR 135.5 px out, the rest at most 124.5
        assert math.dist(c[3], C_SYN) > R_SYN and all(math.dist(p, C_SYN) < R_SYN - 5 for p in c[:3])
        t = MD.find_trapezoid(_outline(c), C_SYN[0], C_SYN[1], R_SYN)
        want = MD._intersect(c[0], c[3], c[1], c[2])
        assert t["method"] == "mirror" and t["rebuilt"] == ["BR"] and math.dist(t["look_at"], want) <= 1.0

    def test_one_side_hidden_gives_no_look_at(self):
        c = ((10, 150), (74, 150), (25, 177), (59, 177))         # TL and BL outside: the axis is unknown
        t = MD.find_trapezoid(_outline(c), C_SYN[0], C_SYN[1], R_SYN)
        assert t is not None and t["method"] == "partial" and t["clipped"] and t["look_at"] is None
        assert t["TL"] is None and t["BL"] is None and t["TR"] == (74, 150)

    def test_far_edge_beyond_the_rim_gives_legs(self):
        """A zoomed-out camera (ub_unitbench_*_generated): the far edge beyond the rim, the legs traced to it."""
        k = 230
        c = ((130 - 0.6 * k, 250 - k), (190 + 0.6 * k, 250 - k), (130, 250), (190, 250))
        t = MD.find_trapezoid(_outline(c), C_SYN[0], C_SYN[1], R_SYN)
        assert t is not None and t["method"] == "legs" and t["clipped"] and t["look_at"] is None
        assert t["BL"] == (130, 250.0) and t["BR"] == (190, 250.0) and t["TL"] is None

    def test_no_outline_is_none(self):
        """A lone horizontal white run (a route segment) and an X marker are not an outline."""
        img = _outline(lines=(((100, 100), (140, 100)), ((200, 200), (206, 206)), ((200, 206), (206, 200))))
        assert MD.find_trapezoid(img, C_SYN[0], C_SYN[1], R_SYN) is None


# ----------------------------------------------------------------------------- the map rectangle's edge
def test_first_black_along_projects_the_pixel_centre():
    img = Image.new("RGB", (60, 20), (40, 70, 38))
    ImageDraw.Draw(img).rectangle((30, 0, 59, 19), fill=(0, 0, 0))
    got = MD.first_black_along(img, [(5.0, 10.0, 1.0, 0.0, 24.0), (5.0, 10.0, -1.0, 0.0, 3.0)])
    assert got[0] == 25.0 and got[1] is None            # pixel 30 is 25 px from x = 5; nothing black leftward
    ImageDraw.Draw(img).point((20, 10), fill=(0, 0, 0))  # a 1 px black outline is not the outside
    assert MD.first_black_along(img, [(5.0, 10.0, 1.0, 0.0, 20.0)])[0] == 25.0


class TestStars:
    def test_paris_stars_are_the_explorers(self):
        """Disc calibration only, the engine size 654 x 360: every star within 2 px of its Explorer's pixel,
        more than 3 px from the command post."""
        img = _crop(PARIS)
        m = MD.measure_disc(img)
        ox, oy = PARIS["crop_offset"]
        cal = T.Calibration("editor", 2560, 1080, m.cx + ox, m.cy + oy, m.r_disc)
        sx, sz = PARIS["size_x_m"], PARIS["size_z_m"]
        assert (sx, sz) == (654.0, 360.0)
        for s in PARIS["stars"]:
            star = MD.player_star(img, s["player_colour"], m)
            assert star is not None, s["what"]
            x, y = star[0] + ox, star[1] + oy
            assert abs(x - s["star_px"]) <= 0.5 and abs(y - s["star_py"]) <= 0.5
            ex = T.world_to_minimap(s["x_m"], s["z_m"], sx, sz, cal)
            po = T.world_to_minimap(s["post"]["x_m"], s["post"]["z_m"], sx, sz, cal)
            assert math.dist(ex, (x, y)) < 2.0, s["what"]
            assert math.dist(po, (x, y)) > 3.0, s["what"]

    def test_london_live_stars_are_the_explorers(self):
        """The live London 4p frame (2026-09-24): the four stars found where the sidecar says, each within 1.5 px of
        its Explorer at 360 x 686 m."""
        img = _crop(LONDON)
        m = MD.measure_disc(img)
        ox, oy = LONDON["crop_offset"]
        cal = T.Calibration("editor", 2560, 1080, m.cx + ox, m.cy + oy, m.r_disc)
        for s in LONDON["stars"]:
            star = MD.player_star(img, s["player_colour"], m)
            assert star is not None and abs(star[0] + ox - s["star_px"]) <= 0.5 and abs(star[1] + oy - s["star_py"]) <= 0.5
            ex = T.world_to_minimap(s["x_m"], s["z_m"], LONDON["size_x_m"], LONDON["size_z_m"], cal)
            assert math.dist(ex, (star[0] + ox, star[1] + oy)) < 1.5, s["what"]

    def test_ingame_regression(self):
        img = _crop(INGAME)
        m = MD.measure_disc(img)
        ox, oy = INGAME["crop_offset"]
        colours = {"P1 blue": (0, 0, 255), "P2 red": (255, 0, 0), "P3 yellow": (255, 255, 0), "P4 purple": (128, 0, 128)}
        for label, col in colours.items():
            star = MD.player_star(img, col, m)
            want = INGAME["stars_regression"][label]
            assert star is not None and abs(star[0] + ox - want[0]) <= 0.5 and abs(star[1] + oy - want[1]) <= 0.5

    def test_absent_colour_is_none(self):
        img = _crop(PARIS)
        m = MD.measure_disc(img)
        assert MD.player_star(img, (0, 255, 255), m) is None          # no cyan player on this map

    def test_synthetic_star_over_a_glyph(self):
        """A star with a dark outline drawn over a same-colour building glyph: the centre, not the merged blob."""
        img = Image.new("RGB", (80, 80), (70, 120, 65))
        d = ImageDraw.Draw(img)
        d.rectangle((38, 22, 54, 40), fill=(0, 0, 255), outline=(0, 0, 0))          # the glyph behind, up-right
        cx, cy = 40.0, 42.0
        poly = MD._star_polygon(cx, cy, 8.5)
        d.polygon(poly, fill=(0, 0, 255), outline=(0, 0, 0))
        blob = MD.blobs(img, (0, 0, 80, 80), (0, 0, 255))[0]
        assert math.dist((blob[0], blob[1]), (cx, cy)) > 3.0           # the colour blob is pulled toward the glyph
        star = MD.player_star(img, (0, 0, 255), (40, 40, 38))
        # the ultimate core of a rasterised star sits on a half-pixel grid: within 1.5 px, never on the glyph
        assert star is not None and math.dist(star, (cx, cy)) <= 1.5 and math.dist(star, (46, 31)) > 8

    def test_square_glyph_is_not_a_star(self):
        img = Image.new("RGB", (60, 60), (70, 120, 65))
        ImageDraw.Draw(img).rectangle((20, 20, 38, 38), fill=(255, 0, 0), outline=(0, 0, 0))
        assert MD.player_star(img, (255, 0, 0), (30, 30, 28)) is None


class TestBlobs:
    def test_true_8_connectivity(self):
        """review F4: two 3x3 squares 1 px apart are two blobs (the old 3 px buckets joined them)."""
        img = Image.new("RGB", (20, 20), (0, 0, 0))
        d = ImageDraw.Draw(img)
        d.rectangle((5, 5, 7, 7), fill=(0, 0, 250))
        d.rectangle((9, 5, 11, 7), fill=(0, 0, 250))
        d.point((13, 9), fill=(0, 0, 250)); d.point((14, 10), fill=(0, 0, 250))     # diagonal neighbours: one blob
        got = MD.blobs(img, (0, 0, 20, 20), (0, 0, 255), min_px=2)
        assert sorted(b[2] for b in got) == [2, 9, 9]

    def test_chroma_matches_a_dimmed_screen(self):
        """review F5: under a dialog the red star reads (165,11,9) / (140,11,9) and still matches the player colour
        (245,0,0); plain chroma drifts 0.11-0.13 there, the grey-removed one does not."""
        img = Image.new("RGB", (30, 20), (0, 0, 0))
        d = ImageDraw.Draw(img)
        d.rectangle((2, 4, 7, 9), fill=(165, 11, 9))
        d.rectangle((12, 4, 17, 9), fill=(140, 11, 9))
        got = MD.blobs(img, (0, 0, 30, 20), (245, 0, 0))
        assert sorted(b[2] for b in got) == [36, 36]
        assert max(abs(a - b) for a, b in zip(MD.chroma((165, 11, 9)), MD.chroma((245, 0, 0)))) > 0.08

    def test_colour_match_rejects_terrain(self):
        yellow, red = MD.hue_chroma((255, 255, 0)), MD.hue_chroma((255, 0, 0))
        assert not MD.colour_match((146, 107, 45), yellow)       # brown city ground
        assert not MD.colour_match((127, 51, 63), red)           # maroon glyphs
        assert not MD.colour_match((23, 0, 0), red)              # the star's dark outline
        assert MD.colour_match((161, 160, 9), yellow) and MD.colour_match((255, 0, 0), red)

    def test_orange_matches_brown_ground(self):
        """review F5, documented not fixed: brown city ground is within the tolerance of orange; for an orange
        player only the star-shape score separates them."""
        assert MD.colour_match((146, 107, 45), MD.hue_chroma((255, 128, 0)))

    def test_dimmed_stars_with_the_disc_from_the_record(self):
        """The ring cannot be measured under a dialog, but a stored disc still finds the stars."""
        img = _crop(PARIS)
        m = MD.measure_disc(img)
        dim = img.point(lambda v: int(v * 0.615 + 8))
        for s in PARIS["stars"]:
            star = MD.player_star(dim, s["player_colour"], m)
            ox, oy = PARIS["crop_offset"]
            assert star is not None and abs(star[0] + ox - s["star_px"]) <= 0.5 and abs(star[1] + oy - s["star_py"]) <= 0.5

    def test_disc_mask_and_box_clamp(self):
        img = Image.new("RGB", (40, 40), (0, 0, 0))
        d = ImageDraw.Draw(img)
        d.rectangle((18, 18, 21, 21), fill=(0, 0, 255))        # inside the disc
        d.rectangle((0, 0, 3, 3), fill=(0, 0, 255))            # outside it (a ring-coloured corner, say)
        assert len(MD.blobs(img, (-10, -10, 400, 400), (0, 0, 255))) == 2
        got = MD.blobs(img, (-10, -10, 400, 400), (0, 0, 255), disc=(20, 20, 10))
        assert len(got) == 1 and got[0][:2] == (19.5, 19.5)

    def test_disc_tuple_forms(self):
        m = MD.DiscMeasurement(1.0, 2.0, 3.0, 4.0, 0, 0.0, 0, 0.0)
        cal = T.Calibration("editor", 1, 1, 5.0, 6.0, 7.0)
        assert MD.disc_tuple(m) == (1.0, 2.0, 3.0) and MD.disc_tuple(cal) == (5.0, 6.0, 7.0)
        assert MD.disc_tuple({"cx": 1, "cy": 2, "r_disc": 3}) == (1.0, 2.0, 3.0) and MD.disc_tuple((1, 2, 3)) == (1.0, 2.0, 3.0)
        assert MD.disc_tuple(None) is None


def test_ultimate_cores_of_a_square():
    square = {(x, y) for x in range(9) for y in range(9)}
    cores = MD.ultimate_cores(square)
    assert len(cores) == 1 and cores[0][0] == 4 and cores[0][1] == [(4, 4)]
