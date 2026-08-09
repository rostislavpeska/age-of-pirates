"""G1 gate tests (plan_mapsim_architecture.md Part G1).

Every asserted name was verified against the live files on 2026-08-09:
protoy.xml (2456 units), protomods.xml (1158 names), 498 mod grouping
files, 466 vanilla grouping stems in the index.
"""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[3]))

from scripts.refdata import catalog  # noqa: E402
from scripts.refdata.catalogs import Entry, GroupingCatalog  # noqa: E402


class TestProto:
    # The G1 done-when gate: 5 vanilla + 5 mod spot checks.
    VANILLA = ["TownCenter", "Outpost", "Musketeer", "MineCopper",
               "InvisibleProjectile"]
    MOD = ["zpNautilusTransport", "zpSubmarineTransport", "zpSulphurMine",
           "zpNatColonialGuard", "zpNatEclaireur"]

    def test_vanilla_names_resolve(self):
        c = catalog("proto")
        for name in self.VANILLA:
            e = c.get(name)
            assert e is not None, name
            assert e.source == "vanilla"

    def test_mod_names_resolve(self):
        c = catalog("proto")
        for name in self.MOD:
            e = c.get(name)
            assert e is not None, name
            assert e.source == "mod"

    def test_mod_shadows_vanilla(self):
        # Caravel is one of 133 live overrides present in BOTH protomods.xml
        # and protoy.xml -> mod wins. (Not Arsenal: protomods contains
        # <unit name="Arsenal"> only inside the commented-out "Florence
        # MAPMODS" block at lines 71529-71712 — grep sees it, the parser
        # correctly does not.)
        assert catalog("proto").get("Caravel").source == "mod"

    def test_case_insensitive(self):
        c = catalog("proto")
        assert c.has("musketeer") and c.has("MUSKETEER")
        assert c.get("musketeer").name == "Musketeer"  # canonical spelling

    def test_unknown_with_suggestion(self):
        c = catalog("proto")
        assert not c.has("Musketeeer")
        assert "Musketeer" in c.suggest("Musketeeer")

    def test_size_sane(self):
        assert len(catalog("proto")) >= 2456  # at least the vanilla roster


class TestGrouping:
    def test_is_grouping_catalog(self):
        assert isinstance(catalog("grouping"), GroupingCatalog)

    def test_exact_mod_stem(self):
        # zpatols references "Platform_Universal"; the file is
        # Platform_universal.xml -> exact case-insensitive resolve.
        hits = catalog("grouping").resolve("Platform_Universal")
        assert any(e.name.lower() == "platform_universal" for e in hits)

    def test_prefix_variants_mod(self):
        # "pirate_village0" -> pirate_village05.xml, pirate_village06.xml...
        hits = catalog("grouping").resolve("pirate_village0")
        assert len(hits) >= 2
        assert all(e.name.lower().startswith("pirate_village0") for e in hits)

    def test_prefix_with_trailing_space_vanilla(self):
        # Vanilla-only loose files: "native apache village 1..5". The
        # trailing space in the reference is significant and preserved.
        hits = catalog("grouping").resolve("native apache village ")
        assert len(hits) == 5
        assert all(e.source == "vanilla" for e in hits)

    def test_mod_shadows_vanilla(self):
        # verseilles_fixed_gun_l ships in the mod folder AND the vanilla
        # index -> the mod copy is the one the game loads.
        assert catalog("grouping").get("verseilles_fixed_gun_l").source == "mod"

    def test_missing_grouping_is_empty(self):
        # Real bug found during G1 research: zpunknown.xs:6351 references
        # Rogue_Factory_Japan; only _North/_South exist anywhere.
        assert catalog("grouping").resolve("Rogue_Factory_Japan") == []

    def test_author_machine_path_never_resolves(self):
        # zptortuga/zptorresstrait/zpzealand reference an absolute
        # c:/users/rosti/... path — non-portable, must not resolve.
        ref = ("c:/users/rosti/games/age of empires 3 de/76561198347905238/"
               "mods/local/tortuga local/randmaps/groupings/harbour_01")
        assert catalog("grouping").resolve(ref) == []

    def test_size_sane(self):
        # 498 mod stems + 466 vanilla stems, minus case-insensitive overlap.
        assert len(catalog("grouping")) >= 498


class TestWater:
    def test_known_names(self):
        c = catalog("water")
        assert c.has("Amazon Rainforest River Muddy")
        assert c.has("Africa Desert Lake")

    def test_entries_carry_layer(self):
        assert catalog("water").get("Africa Desert Lake").source in (
            "mod", "vanilla")


class TestKindDispatch:
    def test_unknown_kind_raises(self):
        with pytest.raises(ValueError, match="unknown catalog kind"):
            catalog("terrain_mix")

    def test_cached_identity(self):
        assert catalog("proto") is catalog("proto")


class TestGroupingFootprint:
    def test_pirate_village_footprint(self):
        # Footprint = units' bounding box in METERS relative to the anchor
        # (the <width>/<height> header is the editor canvas, NOT the
        # footprint - forensic 2026-08-10). pirate_village05's units span
        # x -7.02..8.74, z -9.79..6.11.
        from scripts.refdata.catalogs import grouping_footprint_m
        fp = grouping_footprint_m("pirate_village05")
        assert fp is not None
        x0, z0, x1, z1 = fp
        # full-file bounds: x -8.14..8.74, z -9.79..9.80
        assert -8.2 < x0 < -8.0 and 8.6 < x1 < 8.8
        assert -9.9 < z0 < -9.7 and 9.7 < z1 < 9.9

    def test_offcenter_compound(self):
        # City_State_Inventors_01: canvas 46x50 but the real compound is
        # ~49x51 m offset east - the header would have drawn 92x100.
        from scripts.refdata.catalogs import grouping_footprint_m
        x0, z0, x1, z1 = grouping_footprint_m("City_State_Inventors_01")
        assert 45 < (x1 - x0) < 55 and 45 < (z1 - z0) < 55
        assert x0 > -15   # off-center: nothing 46 m west of the anchor

    def test_unknown_stem_is_none(self):
        from scripts.refdata.catalogs import grouping_footprint_m
        assert grouping_footprint_m("no_such_grouping_xyz") is None
