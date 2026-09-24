"""mapview.census_reader and sandbox/census/census.py parse_units: every record at its OWN header position (xyz at
tag-49 on the current build, tag-48 on older ones, followed by an orthonormal 3x3; a slightly skewed 3x3 at the save's
own offset), names from what the game loads (an index outside today's table reads unknown(N)), the map size from the
terrain header and as an in_map flag only, the owner u16 at ('header', -20) (wf_twin_review F1, F6, F7, F8; wf verify
M1, M2, L1; measured 2026-09-24).

The committed sample saves run everywhere; the London saves in the profile and the history check are local."""
import hashlib
import importlib.util
import math
import os
import re
import struct
import subprocess
import sys
import zlib
from collections import Counter
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO))
from scripts.mapview import census_reader as CR  # noqa: E402

SAMPLES = REPO / "sandbox" / "census" / "samples"
BENCH = SAMPLES / "bench" / "ub_unitbench_unit_s4242.age3Yscn"
PROFILE = REPO.parents[2]
LONDON = PROFILE / "Scenario" / "LondonIndivUnitIDs.age3Yscn"
LIVE = PROFILE / "Scenario" / "mapview_london4p_live.age3Yscn"
ROME = PROFILE / "Scenario" / "Rome.age3Yscn"
INMATCH = SAMPLES / "Carib-afterPirates.age3Ysav"          # committed: an in-match save
# committed samples of both layouts (git ls-files, 2026-09-24): 4 bench saves at tag-49, 5 older saves at tag-48;
# (B, records, map size in metres from the terrain header)
SAMPLE_BACK = {
    "bench/ub_unitbench_unit_s4242.age3Yscn": (49, 7, (200.0, 200.0)),
    "bench/ub_unitbench_ctl_s4242.age3Yscn": (49, 7, (200.0, 200.0)),
    "bench/ub_unitbench_gaia_s4242.age3Yscn": (49, 5, (200.0, 200.0)),
    "bench/bench_000_unitbench_zpSPCLondonBasilica_s4242.age3Yscn": (49, 7, (200.0, 200.0)),
    "census_elbe_01.age3Yscn": (48, 3579, (500.0, 500.0)),
    "census_istanbul.age3Yscn": (48, 1911, (600.0, 600.0)),
    "census_tortuga_01.age3Yscn": (48, 2450, (640.0, 640.0)),
    "0 0  Crownlands Groupings.age3Yscn": (48, 1001, (500.0, 500.0)),
    "0 0  Hansa Groupings.age3Yscn": (48, 334, (360.0, 360.0)),
}


def _census_py():
    spec = importlib.util.spec_from_file_location("aop_census_test", REPO / "sandbox" / "census" / "census.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


# ----------------------------------------------------------------------------- synthetic saves
def _rot_y(deg):
    c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    return (c, 0.0, -s, 0.0, 1.0, 0.0, s, 0.0, c)


def _record(cid, proto, xyz, rot=None, back=49, before=b"", after=b""):
    """One record as the engine writes it: [before] xyz, 3x3, (0xFF when B = 49), 'UN' chunk, proto, [after]."""
    head = struct.pack("<3f", *xyz) + struct.pack("<9f", *(rot or _rot_y(0)))
    if back == 49:
        head += b"\xff"
    sid = cid.encode() + b"\0"
    return before + head + b"UN" + struct.pack("<II", 4 + len(sid), len(sid)) + sid + struct.pack("<I", proto) + after


def _save(tmp_path, body, name="synthetic.age3Yscn", terrain=None):
    """A synthetic l33t save; terrain=(tiles_x, tiles_z, tile_m, second) appends a terrain header after a UTF-16
    texture name, followed by its 'TT' chunk (4 + tiles_x * tiles_z, tiles_x * tiles_z), as the engine writes it."""
    tail = b""
    if terrain is not None:
        tx, tz, tile_m, second = terrain
        tail = ("AfricaDesert\\ground_rock_impassable_afriDesert".encode("utf-16-le")
                + struct.pack("<iiff", tx, tz, tile_m, second) + b"TT" + struct.pack("<II", 4 + tx * tz, tx * tz)
                + b"\0" * 32)
    stream = b"\x11" * 200 + body + b"\x22" * 64 + tail
    p = tmp_path / name
    p.write_bytes(b"l33t" + struct.pack("<I", len(stream)) + zlib.compress(stream))
    return p


# ----------------------------------------------------------------------------- the layout
class TestLayout:
    def test_header_try_order(self):
        assert CR.HEADER_TRY[:2] == (49, 48) and sorted(CR.HEADER_TRY) == list(range(44, 61))

    def test_synthetic_both_builds_first_and_last(self, tmp_path):
        body = b"".join(_record(str(i), 294, (10.0 + i, 1.0, 20.0 + i), _rot_y(30 * i), back=49, after=b"\x33" * 40)
                        for i in range(5))
        recs = CR.decode(_save(tmp_path, body))
        assert [r.census_id for r in recs] == ["0", "1", "2", "3", "4"]
        assert all(r.back == 49 for r in recs)                          # the first and the last record included
        assert [(r.x, r.z) for r in recs] == [(10.0 + i, 20.0 + i) for i in range(5)]
        body48 = b"".join(_record(str(i), 293, (5.0, 0.5, 7.0 + i), back=48, after=b"\x33" * 17) for i in range(3))
        recs48 = CR.decode(_save(tmp_path, body48, "old.age3Yscn"))
        assert [r.back for r in recs48] == [48, 48, 48] and [r.z for r in recs48] == [7.0, 8.0, 9.0]

    def test_not_orthonormal_is_undecoded_not_guessed(self, tmp_path):
        bad = (2.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0)            # row 0 has length 2
        skew = (1.0, 0.0, 0.0, 0.70710678, 0.70710678, 0.0, 0.0, 0.0, 1.0)  # unit rows, |dot| 0.71 > SKEW_TOL
        body = (_record("1", 294, (1.0, 1.0, 1.0), after=b"\x33" * 30) + _record("2", 294, (3.0, 1.0, 3.0), bad, after=b"\x33" * 30)
                + _record("3", 294, (4.0, 1.0, 4.0), skew, after=b"\x33" * 30) + _record("4", 294, (5.0, 1.0, 5.0)))
        save = _save(tmp_path, body)
        recs = CR.decode(save)
        assert [r.decoded for r in recs] == [True, False, False, True] and not any(r.skewed for r in recs)
        assert math.isnan(recs[1].x) and recs[1].rot is None and recs[3].x == 5.0
        units = CR.read(save, 10, 10)
        assert [u["census_id"] for u in units] == ["1", "4"] and CR.read.dropped == 2
        st = CR.read_stats(save)
        assert (st["records"], st["decoded"], st["undecoded"], st["skewed"], st["header_offset"]) == (4, 2, 2, 0, 49)

    def test_slightly_skewed_header_is_read_at_the_saves_offset(self, tmp_path):
        """wf verify M1: ypSPCIndianFortGate on census_istanbulcity_s4242 has rows (-1, 0.004, 0), (0, 1, 0), ...: row
        norms exact, one dot 0.0039 - fails the 1e-3 test, read at the save's dominant B and marked skewed."""
        tilt = (-1.0, 0.0039, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, -1.0)
        body = (_record("1", 294, (1.0, 1.0, 1.0), after=b"\x33" * 30)
                + _record("2", 1199, (206.09, 2.955, 380.15), tilt, after=b"\x33" * 30)
                + _record("3", 294, (5.0, 1.0, 5.0)))
        save = _save(tmp_path, body)
        recs = CR.decode(save)
        assert [r.decoded for r in recs] == [True, True, True] and [r.skewed for r in recs] == [False, True, False]
        assert recs[1].back == 49 and (round(recs[1].x, 2), round(recs[1].z, 2)) == (206.09, 380.15)
        units = CR.read(save)
        assert [u["skewed"] for u in units] == [False, True, False] and CR.read.dropped == 0
        st = CR.read_stats(save)
        assert (st["decoded"], st["undecoded"], st["skewed"]) == (3, 0, 1)

    def test_no_strict_record_no_skew_fallback(self, tmp_path):
        """Without a single strictly valid record there is no dominant offset: nothing is guessed."""
        tilt = (-1.0, 0.0039, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, -1.0)
        save = _save(tmp_path, _record("1", 294, (1.0, 1.0, 1.0), tilt))
        assert [r.decoded for r in CR.decode(save)] == [False]

    def test_non_l33t(self, tmp_path):
        p = tmp_path / "x.age3Yscn"
        p.write_bytes(b"PK\x03\x04" + b"\0" * 20)
        with pytest.raises(ValueError):
            CR.decode(p)
        with pytest.raises(SystemExit):                                 # census.py's CLI exit, as before
            _census_py().parse_units(p)

    @pytest.mark.parametrize("rel", sorted(SAMPLE_BACK))
    def test_committed_samples_decode_completely(self, rel):
        back, n, size = SAMPLE_BACK[rel]
        recs = CR.decode(SAMPLES / rel)
        assert len(recs) == n and all(r.back == back and not r.skewed for r in recs)   # one layout per save
        assert all(abs(math.sqrt(sum(v * v for v in r.rot[k:k + 3])) - 1) < 1e-3 for r in recs for k in (0, 3, 6))
        assert CR.map_size(SAMPLES / rel) == size

    def test_in_match_save_decodes_nothing(self):
        """wf verify M2: an .age3Ysav carries its header at tag-62/-63, outside HEADER_TRY: no record decodes, no
        position is guessed (the twin refuses such a census). Its terrain header reads like an editor save's."""
        assert CR.read(INMATCH) == [] and CR.read.dropped == 2698
        st = CR.read_stats(INMATCH)
        assert (st["records"], st["decoded"], st["undecoded"], st["header_offset"]) == (2698, 0, 2698, None)
        assert st["map_size_m"] == [620.0, 620.0] and st["map_tiles"] == [310, 310]


# ----------------------------------------------------------------------------- the map size
class TestMapSize:
    def test_terrain_header(self, tmp_path):
        save = _save(tmp_path, _record("1", 294, (1.0, 1.0, 1.0)), terrain=(180, 343, 2.0, 8.0))
        assert CR.map_size(save) == (360.0, 686.0)                     # London 4p: 685 asked, 343 tiles held
        st = CR.read_stats(save)
        assert st["map_size_m"] == [360.0, 686.0] and st["map_tiles"] == [180, 343] and st["tile_m"] == 2.0
        blank = _save(tmp_path, _record("1", 294, (1.0, 1.0, 1.0)), "blank.age3Yscn", terrain=(100, 100, 2.0, 4.0))
        assert CR.map_size(blank) == (200.0, 200.0)                   # a blank editor map: second float 4.0

    def test_no_or_two_headers_is_none(self, tmp_path):
        assert CR.map_size(_save(tmp_path, _record("1", 294, (1.0, 1.0, 1.0)))) is None
        body = _record("1", 294, (1.0, 1.0, 1.0))
        p = _save(tmp_path, body, "two.age3Yscn", terrain=(10, 10, 2.0, 8.0))
        data = CR.decompress(p)
        doubled = data + data[-(len("AfricaDesert\\ground_rock_impassable_afriDesert") * 2 + 16 + 10 + 32):]
        assert len(CR.terrain_headers(doubled)) == 2 and CR.map_size_of(doubled) is None

    def test_a_count_that_does_not_fit_is_no_header(self, tmp_path):
        tail = struct.pack("<iiff", 180, 343, 2.0, 8.0) + b"TT" + struct.pack("<II", 4 + 180 * 343, 999)
        p = tmp_path / "bad.age3Yscn"
        stream = b"\x11" * 64 + tail + b"\0" * 16
        p.write_bytes(b"l33t" + struct.pack("<I", len(stream)) + zlib.compress(stream))
        assert CR.map_size(p) is None


# ----------------------------------------------------------------------------- the bench sample (committed)
class TestBench:
    # decoded 2026-09-24; the wf_twin_review F1 truth: TC0 (97,77), TC1 (125,95), House = P1 + 24 m, subject = P1 - 24 m
    WANT = [("0", 294, 97.0, 77.0), ("1", 294, 125.0, 95.0), ("2", 293, 119.0, 77.0), ("3", 2820, 71.0, 77.0),
            ("4", 454, 98.0, 98.0), ("5", 454, 98.0, 98.0), ("6", 454, 98.0, 98.0)]

    def test_own_positions(self):
        recs = CR.decode(BENCH)
        assert [(r.census_id, r.proto_id) for r in recs] == [w[:2] for w in self.WANT]
        for r, (_cid, _pid, x, z) in zip(recs, self.WANT):
            assert abs(r.x - x) < 1e-4 and abs(r.z - z) < 1e-4, (r.census_id, r.x, r.z)
        assert [round(r.y, 4) for r in recs] == [0.745, 0.8779, 0.9176, 0.991, 0.5809, 0.5809, 0.5809]

    def test_read_all_seven_with_ids_and_flags(self):
        units = CR.read(BENCH, 200, 200)
        assert len(units) == 7 and CR.read.dropped == 0
        assert [u["census_id"] for u in units] == [str(i) for i in range(7)]
        assert all(u["id"] == u["census_id"] for u in units)          # 'id' = the same census id, for twin.py
        names = [u["proto"] for u in units]
        assert names[:3] == ["TownCenter", "TownCenter", "House"] and names[4:] == ["AIStart"] * 3
        assert all(u["in_map"] is True and abs(u["fx"] - u["x_m"] / 200) < 1e-12 and abs(u["fz"] - u["z_m"] / 200) < 1e-12
                   for u in units)
        # the owner u16 at ('header', -20): TC0 player 1, TC1 player 2, the House and the subject player 1, AIStart 2..4
        assert [u["player"] for u in units] == [1, 2, 1, 1, 2, 3, 4]
        assert all(u["skewed"] is False for u in units)
        assert all(u["player"] is None for u in CR.read(BENCH, owner_offset=None))   # the owner can be turned off

    def test_size_is_a_flag_never_a_filter(self):
        small = CR.read(BENCH, 100, 100)
        assert len(small) == 7
        off = {u["census_id"] for u in small if u["in_map"] is False}
        assert off == {"1", "2"}                                       # TC1 x 125, House x 119
        assert all(u["fx"] > 1 for u in small if u["census_id"] in off)
        bare = CR.read(BENCH)
        assert len(bare) == 7 and all(u["fx"] is None and u["fz"] is None and u["in_map"] is None for u in bare)

    def test_parse_units_same_records_same_shape(self):
        census = _census_py()
        units = census.parse_units(BENCH)
        assert all(set(u) == {"id", "proto_id", "x", "y", "z"} for u in units)
        assert [(u["id"], u["proto_id"], u["x"], u["z"]) for u in units] == \
               [(r.census_id, r.proto_id, r.x, r.z) for r in CR.decode(BENCH)]
        assert census.parse_units(BENCH, 50.0, 50.0) == units         # the size never filters

    def test_stats(self):
        st = CR.read_stats(BENCH)
        assert (st["records"], st["decoded"], st["undecoded"], st["header_offset"], st["header_offsets"]) == (7, 7, 0, 49, {49: 7})
        assert (st["skewed"], st["map_size_m"], st["map_tiles"], st["unnamed"]) == (0, [200.0, 200.0], [100, 100], 0)
        src = st["protomods_source"]
        assert src is not None and Path(src).name == "protomods.xml.xmb"   # what the game loads
        assert st["protomods_sha1"] == hashlib.sha1(Path(src).read_bytes()).hexdigest()
        assert st["save_sha1"] == hashlib.sha1(BENCH.read_bytes()).hexdigest()


# ----------------------------------------------------------------------------- names
class TestNames:
    VANILLA = '<proto>\n <unit id="0" name="A"/>\n <unit id="1" name ="B"/>\n <!-- <unit id="9" name="Z"/> -->\n <unit id="2" name="C"/>\n</proto>\n'
    MODS = ('<protomods>\n <unit name="M1"/>\n <!-- <unit name="Hidden"/> -->\n <unit name="B"/>\n <unit id="5" name ="M2">'
            '<Flag>x</Flag></unit>\n</protomods>\n')

    def _dirs(self, tmp_path, mods_xml, xmb_bytes=None):
        (tmp_path / "protoy.xml").write_text(self.VANILLA, encoding="utf-8")
        (tmp_path / "protomods.xml").write_text(mods_xml, encoding="utf-8")
        if xmb_bytes is not None:
            (tmp_path / "protomods.xml.xmb").write_bytes(xmb_bytes)
        return tmp_path / "protoy.xml", tmp_path

    def test_xml_comments_never_count(self, tmp_path):
        van, pdir = self._dirs(tmp_path, self.MODS)
        table, info = CR.name_table(0, van, pdir)
        assert table == {0: "A", 1: "B", 2: "C", 3: "M1", 4: "M2"}     # Z and Hidden are comments; B is vanilla
        assert info["protomods_source"] == pdir / "protomods.xml" and info["mod_units"] == 2 and info["mod_base"] == 3
        assert info["protomods_sha1"] == hashlib.sha1((pdir / "protomods.xml").read_bytes()).hexdigest()
        table2, _ = CR.name_table(2, van, pdir)
        assert table2[5] == "M1" and table2[6] == "M2"                 # MOD_BASE_OFFSET shifts the mod block

    def test_xmb_wins_over_the_xml(self, tmp_path):
        if str(CR.XMB_TOOLS) not in sys.path:
            sys.path.insert(0, str(CR.XMB_TOOLS))
        import xmbc
        src = tmp_path / "compiled_from.xml"
        src.write_text('<protomods><unit name="M2"/><unit name="M1"/><unit name="M3"/></protomods>', encoding="utf-8")
        raw_x1 = xmbc.compile_xml(str(src))[0]                          # raw X1; unwrap_alz4 passes it through
        van, pdir = self._dirs(tmp_path, self.MODS, raw_x1)
        table, info = CR.name_table(0, van, pdir)
        assert [table[i] for i in (3, 4, 5)] == ["M2", "M1", "M3"] and info["protomods_source"] == pdir / "protomods.xml.xmb"

    def test_broken_xmb_falls_back_to_the_xml_with_a_warning(self, tmp_path):
        van, pdir = self._dirs(tmp_path, self.MODS, b"X1 not an xmb")
        table, info = CR.name_table(0, van, pdir)
        assert table[3] == "M1" and info["protomods_source"] == pdir / "protomods.xml"
        assert any("unreadable" in w for w in info["warnings"])

    def test_repo_table_skips_commented_units(self):
        """The repo's protomods: the table's mod block is exactly the non-vanilla names of the committed .xmb, in order;
        names that occur only inside the XML's comments (79 units, 19 names outside vanilla on 2026-09-24) never
        appear."""
        census = _census_py()
        table, info = CR.name_table(census.MOD_BASE_OFFSET)
        if not table:
            pytest.skip("no vanilla protoy on this machine")
        vanilla = set(CR.unit_names_xml(info["vanilla_source"]))
        xml, xmb = REPO / "data" / "protomods.xml", REPO / "data" / "protomods.xml.xmb"
        assert info["protomods_source"] == xmb                          # committed next to the XML (AGENTS rule 4)
        loaded = [n for n in CR.unit_names_xmb(xmb) if n not in vanilla]
        mods = [table[i] for i in sorted(table) if i >= info["mod_base"]]
        assert mods == loaded and len(mods) == info["mod_units"]
        text = xml.read_text(encoding="utf-8", errors="replace")
        only_commented = set(re.findall(r'<unit\b[^>]*\bname\s*=\s*"([^"]+)"', text)) - set(CR.unit_names_xml(xml)) - vanilla
        assert not only_commented & set(mods)
        rt, src = census.runtime_names()                                # census.py's wrapper: same table, the vanilla file
        assert rt == table and src == info["vanilla_source"]

    def test_an_index_outside_the_table_reads_unknown(self, tmp_path):
        """wf verify L1: an index past today's runtime table is never named from the XML ids (a vanilla id there
        names another unit); read_stats warns."""
        table, _info = CR.name_table(_census_py().MOD_BASE_OFFSET)
        if not table:
            pytest.skip("no vanilla protoy on this machine")
        past = max(table) + 5
        save = _save(tmp_path, _record("1", 294, (1.0, 1.0, 1.0), after=b"\x33" * 30) + _record("2", past, (2.0, 1.0, 2.0)))
        assert [u["proto"] for u in CR.read(save)] == [table[294], "unknown(%d)" % past]
        st = CR.read_stats(save)
        assert st["unnamed"] == 1 and any("outside today's runtime table" in w for w in st["warnings"])


# ----------------------------------------------------------------------------- owner offsets (two bases)
class TestOwnerBases:
    def test_post_id_base_follows_the_id_length(self, tmp_path):
        tail = lambda owner: struct.pack("<H", owner) + b"\x44" * 30    # the owner right after the proto u32
        body = (_record("7", 294, (1.0, 1.0, 1.0), after=tail(1)) + _record("1234", 294, (2.0, 1.0, 2.0), after=tail(2))
                + _record("56", 293, (3.0, 1.0, 3.0), after=tail(0)))
        save = _save(tmp_path, body)
        assert ("post_id", 4) in CR.find_owner_offset(save, "TownCenter", [1, 2])
        assert CR._owners(save, "post_id", 4) == {"7": 1, "1234": 2, "56": 0}
        units = CR.read(save, 10, 10, owner_offset=4, owner_base="post_id")
        assert [u["player"] for u in units] == [1, 2, 0]
        with pytest.raises(ValueError):
            CR.read(save, owner_offset=4, owner_base=None)             # an offset without its base is refused

    def test_header_base_owner_adopted_on_the_bench(self):
        """Adopted 2026-09-24: the owner is the u16 at ('header', -20) (LondonIndivUnitIDs and mapview_london4p_live:
        the only hit on the four town centres; the bench: TCs 1 / 2)."""
        assert (CR.OWNER_OFFSET, CR.OWNER_BASE) == (-20, "header")
        assert ("header", -20) in CR.find_owner_offset(BENCH, "TownCenter", [1, 2])
        assert CR._owners(BENCH, "header", -20) == {"0": 1, "1": 2, "2": 1, "3": 1, "4": 2, "5": 3, "6": 4}
        assert {u["census_id"]: u["player"] for u in CR.read(BENCH)} == CR._owners(BENCH, "header", -20)


# ----------------------------------------------------------------------------- the London save (profile)
@pytest.mark.local("profile")
class TestLondon:
    """<profile>/Scenario/LondonIndivUnitIDs.age3Yscn: 4 players, 360x685, map at e8f5f2c0, generated 2026-09-22.
    Grouping member offsets from the e8f5f2c0 exports (wf_twin_review F1/F3): EU_SPC_Player_London TownCenter
    (-1.9046, -2.2394); Tower_01 Keep (-0.2764, 0.9881), Tower_02 Keep (0.2764, -0.9881); bridge port socket
    (-10.8661, 1.5821). Anchors on even metres from the reviewer's member votes."""

    @pytest.fixture(scope="class")
    def units(self):
        if not LONDON.is_file():
            pytest.skip("local (profile): no %s" % LONDON)
        return {u["census_id"]: u for u in CR.read(LONDON, 360, 685)}

    def _at(self, u, x, z, tol=0.1):
        return abs(u["x_m"] - x) <= tol and abs(u["z_m"] - z) <= tol

    def test_every_record_decoded_orthonormal(self, units):
        recs = CR.decode(LONDON)
        assert len(recs) == 8967 and all(r.back == 49 for r in recs) and len(units) == 8967 and CR.read.dropped == 0
        assert recs[0].census_id == "0" and recs[0].proto_id == 1804 and self._at(units["0"], 107.4483, 360.0, 1e-3)
        assert recs[-1].census_id == "9135" and self._at(units["9135"], 129.0, 651.0, 1e-3)   # the last record is read
        assert all(u["in_map"] for u in units.values())

    def test_town_centre_is_anchor_plus_member(self, units):
        tc = units["8385"]
        assert tc["proto_id"] == 294 and tc["proto"] == "TownCenter"
        assert self._at(tc, 42 - 1.9046, 150 - 2.2394)
        for cid in ("7862", "8124", "8385", "8647"):                    # all four: an even-metre anchor + the member offset
            u = units[cid]
            ax, az = u["x_m"] + 1.9046, u["z_m"] + 2.2394
            assert u["proto_id"] == 294 and abs(ax - 2 * round(ax / 2)) < 1e-3 and abs(az - 2 * round(az / 2)) < 1e-3

    def test_keeps_socket_ferries(self, units):
        assert units["1050"]["proto_id"] == units["1762"]["proto_id"] == 3638            # zpSPCTowerOfLondon on 2026-09-22
        assert self._at(units["1050"], 40 - 0.2764, 262 + 0.9881)
        assert self._at(units["1762"], 42 + 0.2764, 424 - 0.9881)
        assert units["227"]["proto_id"] == 2691 and self._at(units["227"], 280 - 10.8661, 344 + 1.5821)  # zpSPCPortSocket
        ferries = {cid: (units[cid]["x_m"], units[cid]["z_m"]) for cid in ("169", "170", "171", "172")}
        assert all(units[cid]["proto_id"] == 3605 for cid in ferries)                     # zpOrientalFerry
        assert ferries == {"169": (41.0, 375.0), "170": (141.0, 375.0), "171": (41.0, 313.0), "172": (143.0, 313.0)}

    def test_owner_on_the_town_centres(self, units):
        """Adopted 2026-09-24: ('header', -20) is the only hit; 0 on 8888 records and 1..4 on the 79 per-player ones
        (north bank TCs 1 / 2, south bank 3 / 4: lobby teams {1,2} / {3,4})."""
        assert CR.find_owner_offset(LONDON, "TownCenter", [1, 2, 3, 4]) == [("header", -20)]
        data = CR.decompress(LONDON)
        vals = Counter(CR._field_at(data, r, "header", -20) for r in CR.records(data))
        assert vals[0] == 8888 and set(vals) == {0, 1, 2, 3, 4} and sum(vals.values()) == 8967
        assert {cid: units[cid]["player"] for cid in ("7862", "8124", "8385", "8647")} == \
               {"7862": 1, "8124": 2, "8385": 3, "8647": 4}

    def test_map_size_is_the_engines(self, units):
        """rmSetMapSize(360, 685) at 4 players; the engine holds 180 x 343 tiles = 360 x 686 m."""
        assert CR.map_size(LONDON) == (360.0, 686.0)


@pytest.mark.local("profile")
class TestLive:
    """<profile>/Scenario/mapview_london4p_live.age3Yscn: London 4p / 2 teams, generated in the post-September-patch
    editor 2026-09-24 12:07 (lobby colours p1 blue, p2 red, p3 yellow, p4 purple; the stars of the editor minimap sit on
    the Explorers, predicted within 0.75 / 1.22 / 0.80 / 0.81 px at the true size 360 x 686)."""

    @pytest.fixture(scope="class")
    def units(self):
        if not LIVE.is_file():
            pytest.skip("local (profile): no %s" % LIVE)
        return {u["census_id"]: u for u in CR.read(LIVE, 360, 686)}

    def test_every_record_and_the_size(self, units):
        recs = CR.decode(LIVE)
        assert len(recs) == 10375 and all(r.back == 49 and not r.skewed for r in recs) and len(units) == 10375
        assert CR.map_size(LIVE) == (360.0, 686.0)

    def test_explorers_and_town_centres_with_their_owners(self, units):
        want = {"8270": ("Explorer", 43.0, 545.0, 1), "8659": ("Explorer", 189.0, 537.0, 2),
                "9047": ("Explorer", 55.0, 153.0, 3), "9436": ("Explorer", 175.0, 153.0, 4),
                "7884": ("TownCenter", 40.10, 531.76, 1), "8273": ("TownCenter", 176.10, 531.76, 2),
                "8661": ("TownCenter", 40.10, 145.76, 3), "9050": ("TownCenter", 176.10, 145.76, 4)}
        for cid, (proto, x, z, player) in want.items():
            u = units[cid]
            assert u["proto"] == proto and abs(u["x_m"] - x) < 0.01 and abs(u["z_m"] - z) < 0.01, (cid, u)
            assert u["player"] == player, (cid, u["player"])
        assert CR.find_owner_offset(LIVE, "TownCenter", [1, 2, 3, 4]) == [("header", -20)]


@pytest.mark.local("profile")
def test_skewed_headers_on_an_older_save():
    """<profile>/Scenario/Rome.age3Yscn (older build, B = 48): records 1237 (index 3027) and 1247 (index 284, Settler)
    have |dot| 0.0124 / 0.0122 - undecoded before wf verify M1, read at B = 48 now, marked skewed."""
    if not ROME.is_file():
        pytest.skip("local (profile): no %s" % ROME)
    recs = {r.census_id: r for r in CR.decode(ROME)}
    assert len(recs) == 2153 and all(r.decoded for r in recs.values())
    assert sorted(cid for cid, r in recs.items() if r.skewed) == ["1237", "1247"]
    assert recs["1237"].back == recs["1247"].back == 48
    assert (round(recs["1237"].x, 3), round(recs["1237"].z, 3)) == (152.996, 57.163)
    assert (round(recs["1247"].x, 3), round(recs["1247"].z, 3)) == (151.806, 60.316)
    assert CR.read_stats(ROME)["skewed"] == 2


@pytest.mark.local("profile")
def test_bench_names_with_the_protomods_of_their_day(tmp_path):
    """The bench saves of 2026-09-17 recorded zpNatInuitHarpooner (2820) and zpSPCLondonBasilica (3631). The XMB-based
    table built from data/protomods.xml(.xmb) at 7592cafe (2026-09-17 12:03, before the bench commit 3c23d3c9) with the
    live vanilla list (2673 units) names both, on the subject slots (TC - 26 m and TC - 22 m on x)."""
    live = Path(os.environ.get("LOCALAPPDATA", "")) / "aoe3-mapcheck" / "protoy_live.xml"
    if not os.environ.get("LOCALAPPDATA") or not live.is_file():
        pytest.skip("no mapcheck --live protoy cache")
    for f in ("protomods.xml", "protomods.xml.xmb"):
        r = subprocess.run(["git", "-C", str(REPO), "show", "7592cafe:data/" + f], capture_output=True)
        if r.returncode != 0:
            pytest.skip("no git history of data/%s (shallow clone?)" % f)
        (tmp_path / f).write_bytes(r.stdout)
    table, info = CR.name_table(0, live, tmp_path)
    assert info["vanilla_units"] == 2673 and info["protomods_source"] == tmp_path / "protomods.xml.xmb"
    got = {}
    for save in ("ub_unitbench_unit_s4242", "bench_000_unitbench_zpSPCLondonBasilica_s4242"):
        recs = CR.decode(SAMPLES / "bench" / (save + ".age3Yscn"))
        got[save] = [(r.proto_id, table.get(r.proto_id), r.x, r.z) for r in recs if r.proto_id >= 2673]
    assert got == {"ub_unitbench_unit_s4242": [(2820, "zpNatInuitHarpooner", 71.0, 77.0)],
                   "bench_000_unitbench_zpSPCLondonBasilica_s4242": [(3631, "zpSPCLondonBasilica", 57.0, 91.0)]}
