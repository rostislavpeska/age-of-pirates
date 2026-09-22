"""grouping-centering: detection, the fix rule, byte preservation and the verification-map layout (offline)."""
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "scripts"))
sys.dont_write_bytecode = True
import centering as cg  # noqa: E402
import workflow as wf   # noqa: E402

EDGE = 14.0             # a centred 15-tile block has its edge poles ~1 m inside the +-15 m edge


def block(dx=0.0, dz=0.0, size=(15, 15), poles=True, middle=True, sides="xz", extra=()):
    """A synthetic city block: poles on the chosen sides at +-EDGE, a middle pole, a house, everything moved by
    (dx, dz); CRLF like the real files."""
    hx, hz = size
    us = []
    if poles:
        if "x" in sides:
            us += [(-hx + 1, -4, "PropsPoles"), (-hx + 1, 5, "PropsPoles"), (hx - 1, -3, "PropsPoles"), (hx - 1, 6, "PropsPoles")]
        if "z" in sides:
            us += [(-5, -hz + 1, "PropsPoles"), (6, -hz + 1, "PropsPoles"), (-4, hz - 1, "PropsPoles"), (5, hz - 1, "PropsPoles")]
    if middle:
        us.append((3.0, 2.0, "PropsPoles"))          # a pole in the middle of the block: must be ignored
    us.append((0.5, -0.5, "zpSPCEUHouseProp"))
    us += list(extra)
    lines = ['<?xml version="1.0"?>', "", "<grouping>", f"\t<width>{hx}</width>", f"\t<height>{hz}</height>", "\t<units>"]
    lines += [f'\t\t<unit variation="3" posx="{x + dx:.4f}" posz="{z + dz:.4f}" orientx="0.0000" orienty="0.0000" '
              f'orientz="-1.0000">{p}</unit>' for x, z, p in us]
    lines += ["\t</units>", "\t<tiles>",
              f'\t\t<tilegroup type="Block" subtype="city\\ground1_city_street_ground">',
              f'\t\t\t<block startx="-{hx // 2}" startz="-{hz // 2}" endx="{hx // 2}" endz="{hz // 2}"></block>',
              "\t\t</tilegroup>", "\t</tiles>", "</grouping>"]
    return "\r\n".join(lines) + "\r\n"


def fix(text, stem="EU_House_Block_Test", groupings=HERE):
    dx, dz, _ = cg.decide(stem, text, groupings)
    return dx, dz


# ------------------------------------------------------------------ the rule
def test_centred_block_needs_nothing():
    assert fix(block()) == (0, 0)


def test_negative_whole_metre_displacement_is_fixed_back():
    assert fix(block(-1, -1)) == (1, 1)
    assert fix(block(-1, 0)) == (1, 0)
    assert fix(block(0, -2)) == (0, 2)
    assert fix(block(-1.2, -0.6)) == (1, 1)          # rounded half up to whole metres


def test_positive_small_and_large_offsets_are_left_alone():
    assert fix(block(1, 1)) == (0, 0)                # positive = uneven poles, never a displacement
    assert fix(block(-0.3, -0.45)) == (0, 0)         # under 0.5 m
    assert fix(block(-3, 0)) == (0, 0)               # beyond 2 m = a different layout


def test_middle_poles_do_not_count():
    far = block(-1, 0, extra=[(-6.0, 0.0, "PropsPoles")] * 5)      # five extra poles off-centre in the middle
    assert fix(far) == (1, 0)


def test_one_sided_poles_fall_back_to_edge_units_for_city_lots_only():
    lot = block(0, -1, sides="x", extra=[(-2, -14, "zpUnderbrushConstructionColony"), (2, 14, "zpUnderbrushConstructionMine")])
    assert fix(lot, "IT_SPC_PlayerWood") == (0, 1)                 # z decided by the edge units
    assert fix(lot, "EU_Riverside_NE_01") == (0, 0)                # not a city lot: z undecidable


def test_rectangular_blocks_use_their_real_size():
    tall = block(-1, 0, size=(15, 30))
    assert cg.area(tall) == (15.0, 30.0)
    assert fix(tall) == (1, 0)


def test_excluded_grouping_is_never_fixed():
    assert fix(block(-1, -1), "EU_SPC_Player_London") == (0, 0)


def test_twin_decides_even_without_poles(tmp_path):
    lot = [(-9.0, -9.0, "BerryBush"), (4.0, 6.0, "BerryBush"), (-2.0, 3.0, "zpUnderbrushConstructionJesuit"), (8.0, -5.0, "Deer")]
    good = block(poles=False, middle=False, extra=lot)
    bad = block(-1, -1, poles=False, middle=False, extra=lot)
    (tmp_path / "EU_SPC_PlayerFood.xml").write_bytes(good.encode())
    (tmp_path / "IT_SPC_PlayerFood.xml").write_bytes(bad.encode())
    assert cg.decide("IT_SPC_PlayerFood", bad, tmp_path)[:2] == (1, 1)
    assert cg.decide("EU_SPC_PlayerFood", good, tmp_path)[:2] == (0, 0)   # the twin further + is not displaced
    assert "twin EU_SPC_PlayerFood" in cg.decide("IT_SPC_PlayerFood", bad, tmp_path)[2]


# ------------------------------------------------------------------ the fix
def test_fix_moves_units_only_and_keeps_bytes():
    t = block(-1, -1)
    out = cg.shift_text(t, 1, 1)
    a, b = t.split("\r\n"), out.split("\r\n")
    assert len(a) == len(b) and out.count("\r\n") == t.count("\r\n")
    changed = [i for i, (x, y) in enumerate(zip(a, b)) if x != y]
    assert changed and all("<unit " in b[i] for i in changed)
    assert fix(out) == (0, 0)                        # fixed = centred
    assert cg.units(out)[0][:2] == (-14.0, -4.0)                   # back at -hx + 1 after (-1) + 1


# ------------------------------------------------------------------ the repo and the verification maps
def test_repo_has_nothing_left_to_fix():
    """Pinned 2026-09-22 after the user-approved apply (14 groupings); a new flag means a new out-centred block."""
    assert [r[0] for r in cg.groupings_to_fix()] == []


def test_real_set_map_keeps_the_minimum_gap():
    fixed = {r[0] for r in cg.groupings_to_fix()}
    sb, _, _ = wf.set_layout(wf.city_blocks(cg.GROUPINGS, fixed))
    assert len(sb) > 100 and wf.min_gap(sb) >= wf.GAP


def test_maps_keep_a_minimum_gap_and_great_plains_ground():
    fixed = [("EU_A", block(-1, -1), 1, 1, ""), ("EU_B", block(-1, 0, size=(30, 15)), 1, 0, ""),
             ("IT_C", block(0, -1, size=(15, 30)), 0, 1, "")]
    pb, pw, ph = wf.pairs_layout(fixed)
    assert wf.min_gap(pb) >= wf.GAP
    blocks = [(f"EU_X{i}", 30.0, 30.0, False) for i in range(20)] + [(f"EU_W{i}", 64.0, 64.0, False) for i in range(3)]
    blocks += [("IT_Y", 60.0, 30.0, True), ("IT_V", 30.0, 60.0, False), ("IS_Z", 60.0, 90.0, False), ("IS_Q", 28.0, 30.0, False)]
    sb, sw, sh = wf.set_layout(blocks)
    assert wf.min_gap(sb) >= wf.GAP
    xs, xml = wf.map_script("000_test", ["t"], 400, 400, sb)
    assert 'rmTerrainInitialize("great_plains' + chr(92) + 'ground1_gp", 1.0);' in xs   # one backslash, as vanilla
    assert 'rmSetLightingSet("GreatPlains_Skirmish");' in xs
    assert "MetersToFraction(-" not in xs                          # never a negative into *MetersToFraction
    assert all(float(v) % 2 == 0 for v in re.findall(r"MetersToFraction\(([\d.]+)\)", xs))   # even metres
