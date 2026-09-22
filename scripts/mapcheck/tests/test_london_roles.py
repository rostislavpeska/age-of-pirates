"""London's player-role harness (user 2026-09-21): the Florence system - firstDefender .. seventhAttacker - keyed
on the landmark coin, with no seat coordinates yet. Pins the contract so the seat tables can be written on top of it:

  - the helper is Florence's zpGetTeamPlayer, verbatim, at file scope (also Versailles');
  - TEAM 1 DEFENDS (Minster + Parliament), TEAM 0 ATTACKS (St Paul + Stuart) - Florence's fixed binding; the one
    coin defenderBank (0.5) says where the defenders' city stands, 10.0 places the natives by it (the Stuart-shaped
    and the Parliament-shaped 2 x 2 with Park and Menagerie), exports never rotated; spawnSwitch is set from it;
  - the 14 roles follow the helper's order on team 1 / team 0;
  - the roles resolve before any player is placed and stay -1 outside 2-team lobbies (Florence, Istanbul);
  - harness only: no rmPlacePlayer by role yet; the repo file and the Steam twin are identical and CRLF.
"""
from __future__ import annotations

import re
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
STEAM = Path(r"C:\Program Files (x86)\Steam\steamapps\common\AoE3DE\Game\RandMaps")
LONDON = REPO / "randmaps/zplondon.xs"
FLORENCE = REPO / "randmaps/zpflorence.xs"
VERSAILLES = REPO / "randmaps/zpverseilles.xs"

ORDER = ["first", "second", "third", "fourth", "fifth", "sixth", "seventh"]


def _text(p: Path) -> str:
    return p.read_bytes().decode("utf-8").replace(chr(13), "")


def _code(t: str) -> str:
    return chr(10).join(l for l in t.split(chr(10)) if not l.strip().startswith("//"))


def _helper(t: str) -> str:
    return t[t.index("// Get player order within a team"):t.index("// Place grouping at the first free slot")].rstrip(chr(10))


def _section(t: str, start: str, end: str) -> str:
    return t[t.index(start):t.index(end)]


def _assigns(block: str) -> dict:
    """name -> value for every `name = value;` in a block (declarations included)."""
    return dict(re.findall(r"(?:float |int )?(\w+) = ([\w.]+);", block))


class TestHelper:
    def test_florence_helper_verbatim_at_file_scope(self):
        lon, flo = _text(LONDON), _text(FLORENCE)
        h = _helper(flo)
        assert "void zpGetTeamPlayer(int teamOrder = -1, int teamID = -1)" in h and "int g_zpTeamPlayerResult = -1;" in h
        assert lon.count(h) == 1
        assert lon.index(h) < lon.index("void main(void)")            # file scope, like Florence and Versailles
        assert h in _text(VERSAILLES)                                  # the same words ship on Versailles too

    def test_helper_returns_via_the_global_only(self):
        h = _helper(_text(FLORENCE))            # London carries these exact words (test above)
        body = _code(h)
        assert body.count("g_zpTeamPlayerResult = i;") == 1 and body.count("return;") == 2 and "return " not in body


class TestLandmarkCoin:
    """10.0: the two coin values give the two layouts, cell for cell."""

    def _layouts(self):
        s = _section(_text(LONDON), "// ---- 10.0 THE LANDMARK COIN", "// ---- 10.1 fixed doubles")
        code = _code(s)
        assert "int defenderBank = rmRandInt(0, 1);" not in code          # rolled in 0.5, before the gates
        before, after = code.split("if (defenderBank == 1)")
        south = _assigns(before)                     # defaults = defender bank south
        north = dict(south); north.update(_assigns(after))   # the if-block overrides = defender bank north
        return south, north

    def test_defenders_south_means_parliament_south_and_stuart_north(self):
        south, _ = self._layouts()      # defenderBank 0: Minster + Parliament (team 1) south, St Paul + Stuart (team 0) north
        assert south["locZMinster"] == "locZs12" and south["locZStPaul"] == "locZn12"
        assert south["locZParliament"] == "locZs12" and south["locZParliamentPark"] == "locZs1"   # Parliament cols 1-2, Park row 4 col 1
        assert south["locZStuart"] == "locZn2" and south["locZStuartPark"] == "locZn1"            # unrotated export faces -z: Stuart col 2, Park col 1
        assert south["locZsMenagerie"] == "locZs2" and south["locZnMenagerie"] == "locZn1"       # behind the north (Stuart) Park

    def test_defenders_north_is_the_layout_that_first_shipped(self):
        _, north = self._layouts()      # defenderBank 1: Stuart south col 1 with the Park in col 2, Parliament north
        assert north["locZMinster"] == "locZn12" and north["locZStPaul"] == "locZs12"
        assert north["locZParliament"] == "locZn12" and north["locZParliamentPark"] == "locZn1"
        assert north["locZStuart"] == "locZs1" and north["locZStuartPark"] == "locZs2"
        assert north["locZsMenagerie"] == "locZs2" and north["locZnMenagerie"] == "locZn2"

    def test_placements_use_the_keyed_locations_in_the_shipped_call_order(self):
        s = _code(_section(_text(LONDON), "// ---- 10.1 fixed doubles", "// ---- 10.3 the cell table"))
        calls = re.findall(r"rmPlaceGrouping(?:Instance)?AtLoc\((\w+), (?:0, )?(\w+), (\w+)(?:, 0)?\);", s)
        assert calls[:7] == [("blockStPaul", "locX12", "locZStPaul"), ("blockStuart", "locX34", "locZStuart"),
                             ("blockTowerS", "locX78", "locZs12"), ("blockMinster", "locX12", "locZMinster"),
                             ("blockParliament", "locX3", "locZParliament"), ("blockTowerN", "locX78", "locZn12"),
                             ("blockTrade", "locX1", "locZs3")]
        assert ("blockPark", "locX3", "locZStuartPark") in calls and ("blockPark", "locX4", "locZParliamentPark") in calls
        assert ("blockMenagerie", "locX4", "locZsMenagerie") in calls and ("blockMenagerie", "locX4", "locZnMenagerie") in calls
        assert "int menagerieSInst = rmPlaceGroupingInstanceAtLoc(blockMenagerie, locX4, locZsMenagerie, 0);" in s
        assert "int menagerieNInst = rmPlaceGroupingInstanceAtLoc(blockMenagerie, locX4, locZnMenagerie, 0);" in s

    def test_no_rotated_exports(self):
        t = _text(LONDON)
        for name in ("EU_SPC_London_StPaul", "EU_SPC_London_Minster", "EU_Native_Block_Stuart_01", "EU_Native_Block_Parlam_01"):
            assert t.count('"%s"' % name) == 1, name
        assert not re.search(r"_(90|180|270)\"", t)


class TestRoles:
    def test_fourteen_roles_in_florence_order(self):
        s = _section(_text(LONDON), "// ---- 0.5 THE LOBBY", "// ---- 1. THE NAUTICAL LANE")
        calls = re.findall(r"zpGetTeamPlayer\((\d), (defenderTeam|attackerTeam)\);\n\tint (\w+) = g_zpTeamPlayerResult;", s)
        assert [(int(k), team, name) for k, team, name in calls] == \
            [(i + 1, "defenderTeam", o + "Defender") for i, o in enumerate(ORDER)] + \
            [(i + 1, "attackerTeam", o + "Attacker") for i, o in enumerate(ORDER)]
        assert s.count("g_zpTeamPlayerResult") == 14

    def test_team_1_defends_team_0_attacks_banks_and_spawnswitch_follow_the_coin(self):
        t = _text(LONDON)
        s = _code(_section(t, "// ---- 0.5 THE LOBBY", "// ---- 1. THE NAUTICAL LANE"))
        assert "int defenderTeam = 1;\n\tint attackerTeam = 0;" in s                                   # Florence's fixed binding
        assert re.search(r"int northTeam = attackerTeam;\n\tint southTeam = defenderTeam;\n\tspawnSwitch = 1;[^\n]*\n\tif \(defenderBank == 1\)\n\t\{\n\t\tnorthTeam = defenderTeam;\n\t\tsouthTeam = attackerTeam;\n\t\tspawnSwitch = 0;[^\n]*\n\t\}", s)
        assert "int defenderCount = rmGetNumberPlayersOnTeam(defenderTeam);" in s and "int attackerCount = rmGetNumberPlayersOnTeam(attackerTeam);" in s
        assert t.count("int spawnSwitch = 0;") == 1 and "rmRandInt(0,1)" not in t                     # no second coin
        assert t.index("int spawnSwitch = 0;") < t.index("// ---- 0.5 THE LOBBY") < t.index("int defenderBank = rmRandInt(0, 1);") < t.index("int defenderTeam = 1;")

    def test_strip_seats_read_the_coin_the_same_way(self):
        # defenderBank 0: the defenders' strip on the south bank (wallS), the attackers' on the north; 1: swapped (2026-09-22)
        s = _code(_section(_text(LONDON), "// ---- 12.2 SEATS BY ROLE", "// ---- 12.3 INTERIM PLACEMENT"))
        assert "float stripZd1 = wallS - rmZTilesToFraction(cityDepthTiles);" in s and "float stripZa2 = wallN + rmZTilesToFraction(cityDepthTiles);" in s
        d = re.search(r"if \(defenderBank == 1\)\n\t\{(.*?)\n\t\}", s, re.S).group(1)
        assert "stripZd1 = wallN + rmZTilesToFraction(col4 - 8);" in d and "stripZa1 = wallS - rmZTilesToFraction(cityDepthTiles);" in d

    def test_one_vs_all_and_the_echo(self):
        s = _section(_text(LONDON), "// ---- 0.5 THE LOBBY", "// ---- 1. THE NAUTICAL LANE")
        assert "int oneVsAll = 0;\n\tif (defenderCount >= 7 || attackerCount >= 7)\n\t\toneVsAll = 1;" in s
        assert s.count('rmEchoInfo("LONDON roles:') == 2 and "seventhAttacker + \" oneVsAll \" + oneVsAll" in s

    def test_roles_resolve_before_any_player_is_placed_and_inside_main(self):
        t = _code(_text(LONDON))
        roles = t.index("int firstDefender = g_zpTeamPlayerResult;")
        assert t.index("void main(void)") < roles
        assert roles < min(m.start() for m in re.finditer(r"rmPlacePlayer\w*\(", t))
        assert roles < t.index("rmCreateStartingUnitsObjectDef")

    def test_roles_are_not_gated_on_the_team_count(self):
        # Florence and Istanbul leave the roles at -1 in non-2-team lobbies instead of skipping them
        s = _section(_text(LONDON), "// ---- 0.5 THE LOBBY", "// ---- 1. THE NAUTICAL LANE")
        assert "cNumberTeams" not in s

    def test_no_seat_names_collide_with_other_declarations(self):
        t = _text(LONDON)
        for name in ["northTeam", "southTeam", "defenderTeam", "attackerTeam", "defenderCount", "attackerCount", "oneVsAll",
                     "defenderBank", "locZMinster", "locZStPaul", "locZParliament", "locZStuart", "locZParliamentPark", "locZStuartPark",
                     "locZsMenagerie", "locZnMenagerie"] + \
                [o + r for o in ORDER for r in ("Defender", "Attacker")]:
            assert len(re.findall(r"\b(?:int|float) %s\b" % name, t)) == 1, name


class TestSeats:
    """12.2: one strip layout per team size, Florence's `if (count == k)` blocks. ONE = the Figma (seat rows 7-8, the
    turned park rows 5-6 x cols 5-6, houses rows 5-6 x col 4 and rows 3-4, the prop filler rows 1-2); TWO = seats
    rows 7-8 + 3-4, houses rows 5-6, the filler; THREE = three seats + the filler; FOUR = four seats; FIVE AND MORE =
    the grass strip (TestStripSeats); non-2-team lobbies = the interim line, all eight spots filled."""

    SIDES = (("defender", "Defender", "locZdSeat", "locZd4", "locZd6", "locZd56"), ("attacker", "Attacker", "locZaSeat", "locZa4", "locZa6", "locZa56"))

    def _sec(self):
        return _code(_section(_text(LONDON), "// ---- 12.2 SEATS BY ROLE", "// ---- 12.3 INTERIM PLACEMENT"))

    def _block(self, side, k):
        s = self._sec()
        i = s.index("if (%sCount == %d)" % (side, k)); j = s.index("\n\t\t}", i)
        return re.findall(r"(rmPlacePlayer|rmSetNuggetDifficulty|rmPlaceGroupingAtLoc)\((.*?)\);", s[i:j])   # non-greedy: the outside posts' x carries parentheses

    def _stuart2(self, side, at):
        """each side's strips end with its second post: Stuart 2 on the attackers', Parliament 2 on the defenders'"""
        if side == "attacker":
            return [("rmPlaceGroupingAtLoc", "blockStuart2, 0, " + at)]
        return [("rmPlaceGroupingAtLoc", "blockParliament2, 0, " + at.replace("locXStuart2In, locZaStuart2In", "locXParl2In, locZdParl2In").replace("locZaOut", "locZdOut"))]

    def test_second_stuart_post_is_pinned_with_offset_knobs(self):
        s = self._sec()
        assert "rmSetGroupingMaxDistance(blockStuart2, 0.00);" in s and "float stuart2OffXM = " in s and "float stuart2OffZM = " in s
        assert "float locXStuart2In = locX12 + rmXMetersToFraction(stuart2OffXM);" in s
        assert "float locZaStuart2In = locZn5 + rmZMetersToFraction(stuart2OffZM);" in s and "locZaStuart2In = locZs5 - rmZMetersToFraction(stuart2OffZM);" in s

    def test_blocks_and_the_bank_keyed_columns(self):
        s = self._sec()
        for line in ('int blockPlayerLondon = cityBlock("player london", "EU_SPC_Player_London");',
                     'int blockPropFiller = cityBlock("prop filler", "EU_SPC_Prop_Block");',
                     'int blockParkBig02 = cityBlock("park big turned", "EU_SPC_Park_big_02");',
                     "float locX56 = (locX5 + locX6) * 0.5;", "float locZs56 = wallS-rmZTilesToFraction(col5+col6)*0.5;",
                     "float locZn56 = wallN+rmZTilesToFraction(col5+col6)*0.5;",
                     "if (cNumberTeams == 2)\n\t\tseatsByRole = 1;"):
            assert line in s, line
        d = re.search(r"float locZdSeat = locZs5;.*?if \(defenderBank == 1\)\n\t\{(.*?)\n\t\}", s, re.S).group(1)
        assert all(x in d for x in ("locZdSeat = locZn5;", "locZaSeat = locZs5;", "locZd4 = locZn4;", "locZa4 = locZs4;", "locZd6 = locZn6;", "locZa6 = locZs6;", "locZd56 = locZn56;", "locZa56 = locZs56;"))
        assert s.index("if (seatsByRole == 1)") < s.index("if (defenderCount == 1)") < s.index("if (attackerCount == 1)") < s.index("if (seatsByRole == 0)")

    def test_one_per_side_is_the_figma_strip(self):
        for side, o, S, z5, z7, z67 in self.SIDES:
            assert self._block(side, 1) == [
                ("rmPlacePlayer", "first%s, locX78, %s" % (o, S)),
                ("rmSetNuggetDifficulty", "295, 295"),                                    # the turned park's abandoned tower (zpFrenchTowerCapturable, as on Paris)
                ("rmPlaceGroupingAtLoc", "blockParkBig02, 0, locX56, %s" % z67),           # rows 5-6 x cols 5-6
                ("rmPlaceGroupingAtLoc", "blockHouse1, 0, locX5, %s" % z5),                # rows 5-6 x col 4
                ("rmPlaceGroupingAtLoc", "blockHouse2, 0, locX6, %s" % z5),
                ("rmPlaceGroupingAtLoc", "blockHouse3, 0, locX3, %s" % z5),                # rows 3-4 x cols 4-6
                ("rmPlaceGroupingAtLoc", "blockHouse4, 0, locX4, %s" % z5),
                ("rmPlaceGroupingAtLoc", "blockHouse5, 0, locX3, %s" % S),
                ("rmPlaceGroupingAtLoc", "blockHouse6, 0, locX4, %s" % S),
                ("rmPlaceGroupingAtLoc", "blockHouse1, 0, locX3, %s" % z7),
                ("rmPlaceGroupingAtLoc", "blockHouse2, 0, locX4, %s" % z7),
                ("rmPlaceGroupingAtLoc", "blockPropFiller, 0, locX12, %s" % S),            # rows 1-2 x cols 4-6
            ] + self._stuart2(side, "locXStuart2In, locZaStuart2In"), side

    def test_two_per_side(self):
        for side, o, S, z5, z7, z67 in self.SIDES:
            assert self._block(side, 2) == [
                ("rmPlacePlayer", "first%s, locX78, %s" % (o, S)), ("rmPlacePlayer", "second%s, locX34, %s" % (o, S)),
                ("rmPlaceGroupingAtLoc", "blockHouse3, 0, locX5, %s" % z5), ("rmPlaceGroupingAtLoc", "blockHouse4, 0, locX6, %s" % z5),
                ("rmPlaceGroupingAtLoc", "blockHouse5, 0, locX5, %s" % S), ("rmPlaceGroupingAtLoc", "blockHouse6, 0, locX6, %s" % S),
                ("rmPlaceGroupingAtLoc", "blockHouse1, 0, locX5, %s" % z7), ("rmPlaceGroupingAtLoc", "blockHouse2, 0, locX6, %s" % z7),
                ("rmPlaceGroupingAtLoc", "blockPropFiller, 0, locX12, %s" % S),
            ] + self._stuart2(side, "locXStuart2In, locZaStuart2In"), side

    def test_three_and_four_per_side(self):
        for side, o, S, z5, z7, z67 in self.SIDES:
            assert self._block(side, 3) == [("rmPlacePlayer", "first%s, locX78, %s" % (o, S)), ("rmPlacePlayer", "second%s, locX34, %s" % (o, S)),
                                            ("rmPlacePlayer", "third%s, locX56, %s" % (o, S)), ("rmPlaceGroupingAtLoc", "blockPropFiller, 0, locX12, %s" % S)] + self._stuart2(side, "locXStuart2In, locZaStuart2In"), side
            assert self._block(side, 4) == [("rmPlacePlayer", "first%s, locX78, %s" % (o, S)), ("rmPlacePlayer", "second%s, locX34, %s" % (o, S)),
                                            ("rmPlacePlayer", "third%s, locX56, %s" % (o, S)), ("rmPlacePlayer", "fourth%s, locX12, %s" % (o, S))] + (self._stuart2(side, "(xRoad + 0.5) * 0.5, locZaOut") + self._stuart2(side, "(0.5 + xGateMirror) * 0.5, locZaOut")), side

    def test_second_stuart_post_on_the_stuart_side(self):
        s = self._sec()
        assert 'int blockStuart2 = cityBlock("stuart 2", "EU_Native_Block_Stuart_02");' in s and "int stuart2OutTiles = wallOutTiles + 30;" in s
        assert "float locZaOut = wallN + rmZTilesToFraction(cityDepthTiles + stuart2OutTiles);" in s and "locZaOut = wallS - rmZTilesToFraction(cityDepthTiles + stuart2OutTiles);" in s
        for k in (1, 2, 3):          # inside the prop block's hole, right after the prop block
            b = self._block("attacker", k)
            assert b[-2:] == [("rmPlaceGroupingAtLoc", "blockPropFiller, 0, locX12, locZaSeat"), ("rmPlaceGroupingAtLoc", "blockStuart2, 0, locXStuart2In, locZaStuart2In")], k
            assert self._block("defender", k)[-2:] == [("rmPlaceGroupingAtLoc", "blockPropFiller, 0, locX12, locZdSeat"), ("rmPlaceGroupingAtLoc", "blockParliament2, 0, locXParl2In, locZdParl2In")], k
        assert self._block("attacker", 4)[-2:] == [("rmPlaceGroupingAtLoc", "blockStuart2, 0, (xRoad + 0.5) * 0.5, locZaOut"), ("rmPlaceGroupingAtLoc", "blockStuart2, 0, (0.5 + xGateMirror) * 0.5, locZaOut")]   # four and more per side: two, both outside
        assert self._block("defender", 4)[-2:] == [("rmPlaceGroupingAtLoc", "blockParliament2, 0, (xRoad + 0.5) * 0.5, locZdOut"), ("rmPlaceGroupingAtLoc", "blockParliament2, 0, (0.5 + xGateMirror) * 0.5, locZdOut")]
        fb = s[s.index("if (seatsByRole == 0)"):s.index('rmEchoInfo("LONDON seats:')]
        assert fb.count("blockParliament2") == 2 and "rmPlaceGroupingAtLoc(blockParliament2, 0, (xRoad + 0.5) * 0.5, locZdOut);" in fb
        assert fb.count("blockStuart2") == 2 and "rmPlaceGroupingAtLoc(blockStuart2, 0, (xRoad + 0.5) * 0.5, locZaOut);" in fb and "rmPlaceGroupingAtLoc(blockStuart2, 0, (0.5 + xGateMirror) * 0.5, locZaOut);" in fb   # more than four per side: two, both outside
        w = (REPO / "game/randmaps/groupings/EU_Native_Block_Stuart_02.xml").read_bytes()
        assert w.count(b"zpSPCSocketStuart") == 1 and b"<width>16</width>" in w
        w2 = (REPO / "game/randmaps/groupings/EU_Native_Block_Parlam_02.xml").read_bytes()
        assert w2.count(b"zpSocketParliament") == 1 and b"<width>15</width>" in w2
        s = self._sec(); assert "rmSetGroupingMaxDistance(blockParliament2, 0.00);" in s and "float parl2OffXM = " in s and "float locZdOut = wallS - rmZTilesToFraction(cityDepthTiles + stuart2OutTiles);" in s

    def test_fallback_fills_all_eight_spots(self):
        s = self._sec()
        b = s[s.index("if (seatsByRole == 0)"):s.index('rmEchoInfo("LONDON seats:')]
        fills = re.findall(r"rmPlaceGroupingAtLoc\(blockPropFiller, 0, (locX\d+), (locZ[da]Seat)\);", b)
        assert fills == [(x, z) for z in ("locZdSeat", "locZaSeat") for x in ("locX78", "locX34", "locX56", "locX12")]
        w = (REPO / "game/randmaps/groupings/EU_SPC_Prop_Block.xml").read_text(encoding="utf-8")
        assert "<width>30</width>" in w and "<height>45</height>" in w and "TownCenter" not in w and "Nugget" not in w
        # no Steam-root copies: Game/RandMaps/groupings is vanilla-only (user rule 2026-09-22, rm-groupings-deploy)

    def test_seated_players_get_the_block_not_the_command_post(self):
        t = _code(_text(LONDON))
        loop = t[t.index("for(i=1; < cNumberNonGaiaPlayers + 1) {"):t.index("int harbourN1PostUnit")]
        assert "if (seatsByRole == 1 && areaSeat == 0)\n\t\t{\n\t\t\trmPlaceGroupingAtLoc(blockPlayerLondon, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));\n\t\t}" in loop
        assert loop.count("deSPCCommandPost") == 1 and loop.index("if (seatsByRole == 0)") < loop.index("deSPCCommandPost")
        assert loop.count("rmPlaceObjectDefAtLoc(playerStart, i") == 1 and loop.count("rmPlaceObjectDefAtLoc(aiStartUrban, i, 0.5, 0.5)") == 1
        before = t[t.index("int aiStartUrban"):t.index("for(i=1; < cNumberNonGaiaPlayers + 1) {")]
        assert "rmSetNuggetDifficulty(1, 1);" in before        # the player treasure is level 1 (Istanbul 2506, Florence 1266)

    def test_interim_line_only_for_the_non_2_team_lobbies(self):
        s = _code(_section(_text(LONDON), "// ---- 12.3 INTERIM PLACEMENT", "int playerStart = rmCreateStartingUnitsObjectDef"))
        assert "if (seatsByRole == 0 && cNumberTeams != 2){" in s and "rmPlacePlayersLine(0.10, zPlLine, 0.75, zPlLine, 0, 0);" in s
        assert "cNumberTeams == 2" not in s and "spawnSwitch" not in s and "PlayerNum" not in s and "rmSetPlacementTeam" not in s   # the 2-team branch went with the strip (2026-09-22)


class TestStripSeats:
    """12.2 + the kit loop (user 2026-09-22): five and more per side - no block on that bank's reserved columns, one flat
    grass strip over rows 1-8 x cols 4-6 instead, the team spaced along it on an all-integer tile pitch, each seat's kit
    (the seat block's own protos) laid out by hand around the seat; the 2-team interim line is gone."""

    def _sec(self):
        return _code(_section(_text(LONDON), "// ---- 12.2 SEATS BY ROLE", "// ---- 12.3 INTERIM PLACEMENT"))

    def test_helper_is_two_flat_layers_city_tiles_then_inset_grass(self):
        t = _text(LONDON)
        h = _code(t[t.index("void seatStrip("):t.index("int countryside(string name")])
        assert "float walkM = 4.0)" in h
        for layer, box, paint in (("strip", "box", 'rmSetAreaTerrainType(strip, "city' + chr(92) + 'ground1_city_street_ground");'),
                                  ("lawn", "lawnBox", 'rmSetAreaMix(lawn, "newengland_grass");')):
            for line in ("rmSetAreaSize(%s, 0.7, 0.7);" % layer, "rmSetAreaLocation(%s, (x1 + x2) * 0.5, (z1 + z2) * 0.5);" % layer,
                         "rmSetAreaCoherence(%s, 1.0);" % layer, "rmSetAreaBaseHeight(%s, 1.0);" % layer,
                         "rmAddAreaInfluenceSegment(%s, x1 + (x2 - x1) * 0.1, (z1 + z2) * 0.5, x2 - (x2 - x1) * 0.1, (z1 + z2) * 0.5);" % layer,
                         paint, "rmAddAreaConstraint(%s, %s);" % (layer, box), "rmSetAreaObeyWorldCircleConstraint(%s, false);" % layer, "rmBuildArea(%s);" % layer):
                assert line in h, line
        assert 'int box = rmCreateBoxConstraint(name + " box", x1, z1, x2, z2);' in h
        assert 'int lawnBox = rmCreateBoxConstraint(name + " lawn box", x1 + rmXMetersToFraction(walkM), z1 + rmZMetersToFraction(walkM), x2 - rmXMetersToFraction(walkM), z2 - rmZMetersToFraction(walkM));' in h
        assert h.index("rmBuildArea(strip);") < h.index("int lawnBox") and "Elevation" not in h and "CliffType" not in h
        g = (REPO / "game/randmaps/groupings/EU_SPC_Player_London.xml").read_text(encoding="utf-8")
        assert 'type="PassableLand" subtype="city' + chr(92) + 'ground1_city_street_ground"' in g                # the groupings' own city tiles
        assert t.index("void quaySegment(") < t.index("void seatStrip(") < t.index("int countryside(string name")

    def test_strip_box_on_rows_1_to_8_and_the_reserved_columns_keyed_by_the_coin(self):
        s = self._sec()
        for line in ("float stripX1 = locX8 - rmXMetersToFraction(15.0);", "float stripX2 = locX1 + rmXMetersToFraction(15.0);",
                     "float stripZd1 = wallS - rmZTilesToFraction(cityDepthTiles);", "float stripZd2 = wallS - rmZTilesToFraction(col4 - 8);",
                     "float stripZa1 = wallN + rmZTilesToFraction(col4 - 8);", "float stripZa2 = wallN + rmZTilesToFraction(cityDepthTiles);",
                     "int stripLenTiles = 134;", "int seatPitchTiles = 0;", "float seatXk = 0.0;", "if (cNumberTeams == 2)\n\t\tseatsByRole = 1;"):
            assert line in s, line
        d = re.search(r"if \(defenderBank == 1\)\n\t\{(.*?)\n\t\}", s, re.S).group(1)
        for line in ("stripZd1 = wallN + rmZTilesToFraction(col4 - 8);", "stripZd2 = wallN + rmZTilesToFraction(cityDepthTiles);",
                     "stripZa1 = wallS - rmZTilesToFraction(cityDepthTiles);", "stripZa2 = wallS - rmZTilesToFraction(col4 - 8);"):
            assert line in d, line
        assert "defenderCount <= 4" not in s and "attackerCount <= 4" not in s

    def test_five_and_more_per_side(self):
        s = self._sec()
        for side, team, z_seat, strip, zs, post, z_out in (("defender", "defenderTeam", "locZdSeat", "D", "stripZd1, stripX2, stripZd2", "blockParliament2", "locZdOut"),
                                                            ("attacker", "attackerTeam", "locZaSeat", "A", "stripZa1, stripX2, stripZa2", "blockStuart2", "locZaOut")):
            i = s.index("if (%sCount >= 5)" % side); b = s[i:s.index("\n\t\t}", i)]
            for line in ('seatStrip("seat strip %s", stripX1, %s);' % (strip, zs),
                         "seatPitchTiles = stripLenTiles / %sCount;" % side,
                         "seatXk = stripX1 + rmXTilesToFraction((stripLenTiles - seatPitchTiles * %sCount) / 2) + rmXTilesToFraction(seatPitchTiles) * 0.5;" % side,
                         "for (k = 1; <= %sCount)" % side, "zpGetTeamPlayer(k, %s);" % team, "rmPlacePlayer(g_zpTeamPlayerResult, seatXk, %s);" % z_seat,
                         "seatXk = seatXk + rmXTilesToFraction(seatPitchTiles);",
                         "rmPlaceGroupingAtLoc(%s, 0, (xRoad + 0.5) * 0.5, %s);" % (post, z_out), "rmPlaceGroupingAtLoc(%s, 0, (0.5 + xGateMirror) * 0.5, %s);" % (post, z_out)):
                assert line in b, (side, line)
            assert "blockPropFiller" not in b and "blockHouse" not in b and "blockPlayerLondon" not in b and "blockParkBig02" not in b
        assert s.index("if (defenderCount == 4)") < s.index("if (defenderCount >= 5)") < s.index("if (attackerCount == 1)") < s.index("if (attackerCount >= 5)") < s.index("if (seatsByRole == 0)")

    def test_the_kit_is_the_seat_blocks_protos_laid_out_the_same_way_for_every_seat(self):
        t = _code(_text(LONDON))
        defs = t[t.index('int areaTC = rmCreateObjectDef("strip seat town center");'):t.index("rmSetNuggetDifficulty(1, 1);")]
        items = re.findall(r'rmAddObjectDefItem\((\w+), (.*?)\);', defs)
        assert items == [("areaTC", '"TownCenter", 1, 0.0'), ("areaMine", '"deMineCoalBuildable", 1, 0.0'), ("areaBerry", '"BerryBush", 6, 4.0'), ("areaDeer", '"Deer", 11, 6.0'),
                         ("areaTrees", '"TreeNewEngland", 14, 9.0'), ("areaTrees", '"TreeGreatLakes", 14, 9.0'), ("areaTrees", '"UnderbrushForest", 8, 8.0'), ("areaNugget", '"Nugget", 1, 0.0')]
        assert "rmSetObjectDefCreateHerd(areaDeer, true);" in defs and 'rmAddObjectDefToClass(areaTrees, rmClassID("classForest"));' in defs
        assert "rmSetObjectDefMaxDistance(areaTC, 0.0);" in defs and defs.count("rmSetObjectDefMaxDistance(") == 6
        block = _text(LONDON)
        w = (REPO / "game/randmaps/groupings/EU_SPC_Player_London.xml").read_text(encoding="utf-8")
        for proto, n in (("TownCenter", 1), ("deMineCoalBuildable", 2), ("BerryBush", 6), ("Deer", 11)):
            assert w.count(">%s</unit>" % proto) == n, proto                                        # the kit's counts are the block's
        loop = t[t.index("for(i=1; < cNumberNonGaiaPlayers + 1) {"):t.index("int harbourN1PostUnit")]
        a = loop[loop.index("if (areaSeat == 1)"):loop.index("if (seatsByRole == 0)")]
        places = re.findall(r"rmPlaceObjectDefAtLoc\((\w+), (\w+), (.*?)\);", a)
        assert places == [("areaTC", "i", "seatX, seatZ"),
                          ("areaMine", "i", "seatX + rmXMetersToFraction(12.0), seatZ - outZ * rmZMetersToFraction(18.0)"),
                          ("areaMine", "i", "seatX - rmXMetersToFraction(12.0), seatZ - outZ * rmZMetersToFraction(18.0)"),
                          ("areaBerry", "0", "seatX, seatZ - outZ * rmZMetersToFraction(18.0)"),
                          ("areaNugget", "0", "seatX, seatZ - outZ * rmZMetersToFraction(32.0)"),
                          ("areaDeer", "0", "seatX, seatZ + outZ * rmZMetersToFraction(22.0)"),
                          ("areaTrees", "0", "seatX - rmXMetersToFraction(10.0), seatZ + outZ * rmZMetersToFraction(32.0)"),
                          ("areaTrees", "0", "seatX + rmXMetersToFraction(10.0), seatZ + outZ * rmZMetersToFraction(32.0)")]
        assert "float outZ = 1.0;" in a and "if (seatZ < 0.5)\n\t\t\t\toutZ = -1.0;" in a
        gate = loop[loop.index("int areaSeat = 0;"):loop.index("if (areaSeat == 1)")]
        assert "if (seatsByRole == 1 && rmGetPlayerTeam(i) == defenderTeam && defenderCount >= 5)\n\t\t\tareaSeat = 1;" in gate
        assert "if (seatsByRole == 1 && rmGetPlayerTeam(i) == attackerTeam && attackerCount >= 5)\n\t\t\tareaSeat = 1;" in gate
        assert "if (seatsByRole == 1 && areaSeat == 0)" in gate
        assert loop.count("rmPlaceObjectDefAtLoc(playerStart, i") == 1                             # the starting units for every seat, the Town Center apart (Black Sea)

    def test_no_int_times_float_and_no_name_collisions(self):
        t = _code(_text(LONDON)); main = t[t.index("void main("):]
        for name in ("stripX1", "stripX2", "stripZd1", "stripZd2", "stripZa1", "stripZa2", "stripLenTiles", "seatPitchTiles", "seatXk", "areaSeat",
                     "seatX", "seatZ", "outZ", "areaTC", "areaMine", "areaBerry", "areaDeer", "areaTrees", "areaNugget"):
            assert len(re.findall(r"\b(?:int|float) %s\b" % name, main)) == 1, name
        assert not re.search(r"\b(?:defenderCount|attackerCount|seatPitchTiles|stripLenTiles|k)\s*\*\s*(?:seatXk|outZ|stripX\d|stripZ\w+)\b", main)
        assert not re.search(r"\b(?:seatXk|outZ|stripX\d|stripZ\w+)\s*\*\s*(?:defenderCount|attackerCount|seatPitchTiles|stripLenTiles|k)\b", main)


class TestWalls:
    """12.5: Florence's three gate segments per bank - over the route, centre, the route's mirror - and its hills."""

    def test_three_gates_per_bank_on_the_outer_edge(self):
        s = _code(_section(_text(LONDON), "// ---- 3.5 THE GATES", "// ---- 4. THE RIVER"))
        assert 'int wallGateS = rmCreateGrouping("wall se", "EU_SPC_London_Wall_SE_01");' in s      # faces -z: the south bank's outer edge
        assert 'int wallGateN = rmCreateGrouping("wall nw", "EU_SPC_London_Wall_NW_01");' in s      # faces +z: the north bank's
        assert "float xGateMirror = 1.0 - xRoad;" in s
        assert "float wallZS = wallS - rmZTilesToFraction(cityDepthTiles + wallOutTiles);" in s
        assert "float wallZN = wallN + rmZTilesToFraction(cityDepthTiles + wallOutTiles);" in s
        calls = re.findall(r"rmPlaceGroupingAtLoc\((wallGate[SN]), (wallOwner[SN]), ([\w.]+), (wallZ[SN])\);", s)
        assert calls == [("wallGateS", "wallOwnerS", "xRoad", "wallZS"), ("wallGateS", "wallOwnerS", "0.5", "wallZS"), ("wallGateS", "wallOwnerS", "xGateMirror", "wallZS"),
                         ("wallGateN", "wallOwnerN", "xRoad", "wallZN"), ("wallGateN", "wallOwnerN", "0.5", "wallZN"), ("wallGateN", "wallOwnerN", "xGateMirror", "wallZN")]
        for g in ("EU_SPC_London_Wall_SE_01", "EU_SPC_London_Wall_NW_01"):
            w = (REPO / ("game/randmaps/groupings/%s.xml" % g)).read_text(encoding="utf-8")
            assert "Flag" not in w and w.count("<tilegroup") == 1 and 'type="PassableLand" subtype="city' + chr(92) + 'ground1_city_street_ground"' in w
            assert w.count("SPCFortGate") == 1 and w.count("deSPCEuroTower") == 2 and w.count("<unit ") == 27

    def test_walls_belong_to_the_banks_first_player_gaia_otherwise(self):
        s = _code(_section(_text(LONDON), "// ---- 3.5 THE GATES", "// ---- 4. THE RIVER"))
        assert re.search(r"int wallOwnerS = firstAttacker;\n\tint wallOwnerN = firstDefender;\n\tif \(defenderBank == 0\)\n\t\{\n\t\twallOwnerS = firstDefender;\n\t\twallOwnerN = firstAttacker;\n\t\}", s)
        assert "if (wallOwnerS < 0) wallOwnerS = 0;" in s and "if (wallOwnerN < 0) wallOwnerN = 0;" in s

    def test_hills_are_florences_wallcliffs_in_the_four_gaps(self):
        t = _text(LONDON)
        h = _code(t[t.index("void wallCliff("):t.index("// One city cell on both banks")])
        for line in ('rmSetAreaSize(area, rmAreaTilesToFraction(tiles), rmAreaTilesToFraction(tiles));', 'rmSetAreaCliffType(area, "ZP Cliff British");',
                     "rmSetAreaCliffEdge(area, 1, 1, 0.0, 0.0, 2);", "rmSetAreaCliffHeight(area, 0, 0, 0.5);", "rmSetAreaBaseHeight(area, 8.0);",
                     "rmSetAreaHeightBlend(area, 3);", "rmSetAreaCoherence(area, 0.93);", 'rmAddAreaToClass(area, rmClassID("classPlateau"));'):
            assert line in h, line
        s = _code(_section(t, "// ---- 3.5 THE GATES", "int harbourN1PostUnit"))
        assert "float hillX1 = (1.0 + xRoad + wallHalfX) * 0.5;" in s and "float hillX2 = (xRoad + 0.5) * 0.5;" in s
        assert "float hillX3 = (0.5 + xGateMirror) * 0.5;" in s and "float hillX4 = (xGateMirror - wallHalfX) * 0.5;" in s
        hills = re.findall(r'wallCliff\("wall hill (\w+)", (hillX\d), (hillZ[SN]), (hill\w+Tiles), avoidPlateauShort, avoidTradeRouteWall, avoidWall\);', s)
        E, I = "hillEdgeTiles", "hillInnerTiles"   # London's gaps: 43.8 m at both edges, 25.2 m between segments
        assert hills == [("S1", "hillX1", "hillZS", E), ("S2", "hillX2", "hillZS", I), ("S3", "hillX3", "hillZS", I), ("S4", "hillX4", "hillZS", E),
                         ("N1", "hillX1", "hillZN", E), ("N2", "hillX2", "hillZN", I), ("N3", "hillX3", "hillZN", I), ("N4", "hillX4", "hillZN", E)]
        assert "int hillEdgeTiles = 360;" in s and "int hillInnerTiles = 200;" in s
        assert s.index("rmPlaceGroupingAtLoc(wallGateN, wallOwnerN, xGateMirror, wallZN);") < s.index('wallCliff("wall hill S1"')   # walls first: the hills avoid them
        assert 'int avoidTradeRouteWall = rmCreateTradeRouteDistanceConstraint("trade route wall", 4.0);' in t
        assert 'rmCreateClassDistanceConstraint("avoid plateau short", rmClassID("classPlateau"), 4.0);' in t   # the hills' street clearance (2026-09-21: 2 too little, 6 too much)
        assert 'int avoidWall = rmCreateTypeDistanceConstraint("avoid wall object", "AbstractWall", 0.001);' in t

    def test_wall_terrain_twins_after_the_countryside(self):
        t = _code(_text(LONDON))
        s = t[t.index('countryside("countryside N"'):t.index('rmSetStatusText("",0.50);')]
        assert 'int wallTerrainS = rmCreateGrouping("wall se terrain", "EU_SPC_London_Wall_SE_Terrain_01");' in s
        assert 'int wallTerrainN = rmCreateGrouping("wall nw terrain", "EU_SPC_London_Wall_NW_Terrain_01");' in s
        calls = re.findall(r"rmPlaceGroupingAtLoc\((wallTerrain[SN]), 0, ([\w.]+), (wallZ[SN])\);", s)
        assert calls == [("wallTerrainS", "xRoad", "wallZS"), ("wallTerrainS", "0.5", "wallZS"), ("wallTerrainS", "xGateMirror", "wallZS"),
                         ("wallTerrainN", "xRoad", "wallZN"), ("wallTerrainN", "0.5", "wallZN"), ("wallTerrainN", "xGateMirror", "wallZN")]
        for g in ("EU_SPC_London_Wall_SE_Terrain_01", "EU_SPC_London_Wall_NW_Terrain_01"):
            w = (REPO / ("game/randmaps/groupings/%s.xml" % g)).read_text(encoding="utf-8")
            assert w.count("<tilegroup") == 1 and 'type="PassableLand" subtype="city' + chr(92) + 'ground1_city_street_ground"' in w
            assert w.count("<unit ") == 1 and "zpSPCWaterSpawnPoint" in w     # Florence's terrain twin, as it is

    def test_the_british_cliff_exists(self):
        c = (REPO / "data/clifftypes2.xml").read_text(encoding="utf-8", errors="replace")
        assert '<cliff name="ZP Cliff British"' in c and (REPO / "data/clifftypes2.xml.xmb").is_file()
        b = c[c.index('<cliff name="ZP Cliff British"'):]; b = b[:b.index("</cliff>")]
        assert "<top>new_england" + chr(92) + "ground3_ne</top>" in b and "<topedge>new_england" + chr(92) + "ground3_ne</topedge>" in b
        assert "<bottomedge>new_england" + chr(92) + "ground3_ne</bottomedge>" in b and "ceylon_cliff_basecolor" in b

    def test_walls_come_before_the_road_is_built_hills_after_the_players(self):
        t = _code(_text(LONDON))
        assert t.index('rmCreateGrouping("wall se"') < t.index('rmBuildTradeRoute(tradeRouteID, "dirt");')
        assert t.index("rmPlaceObjectDefAtLoc(aiStartUrban, i, 0.5, 0.5);") < t.index('wallCliff("wall hill S1"') < t.index("int harbourN1PostUnit")


class TestGateOrder:
    """Paris's gate order (zpparis.xs 309-350, user 2026-09-21): lane, road defined, gates at fixed coordinates,
    road built through them, then the river."""

    def test_lane_first_road_defined_gates_road_built_river(self):
        t = _code(_text(LONDON))
        lane = t.index('rmBuildTradeRoute(waterRouteID, "water_trail");')
        road_def = t.index("int tradeRouteID = rmCreateTradeRoute();")
        walls = t.index('rmCreateGrouping("wall se"')
        bridge = t.index("int bridgeInst = placeIsland(londonBridge")
        road_built = t.index('rmBuildTradeRoute(tradeRouteID, "dirt");')
        socket = t.index("routeSocket(tradeRouteID, xRoad, zRiver);")
        river = t.index("rmRiverCreate(")
        posts = t.index('int harbourN1PostDef')
        assert lane < road_def < walls < road_built < socket < river < posts < bridge   # the bridge back after the river (2026-09-21: before the road it did not spawn)
        assert t.index("float zRiver = zRiverAsk;") < t.index("int waterRouteID = rmCreateTradeRoute();")

    def test_road_on_the_authored_line(self):
        t = _code(_text(LONDON))
        assert t.count("float xRoad = roadAsk;") == 1 and t.index("float xRoad = roadAsk;") < t.index("int waterRouteID = rmCreateTradeRoute();")
        assert re.search(r"rmAddTradeRouteWaypoint\(tradeRouteID, roadAsk, 0\.0\);\n\trmAddTradeRouteWaypoint\(tradeRouteID, roadAsk, 0\.5\);\n\trmAddTradeRouteWaypoint\(tradeRouteID, roadAsk, 1\.0\);", t)
        assert "float xRoadReal = (road25X + road75X) * 0.5;" in t and "xRoad = (road25X" not in t   # the read-back is an echo only
        assert t.index('rmBuildTradeRoute(tradeRouteID, "dirt");') < t.index("routePoint(tradeRouteID, 0.25);")

    def test_gaia_gets_the_gate_tech_at_start(self):
        t = _code(_text(LONDON))
        s = t[t.index('rmCreateTrigger("LondonStartingTechs");'):t.index('rmAddTriggerEffect("Player : Override Civilization for Flag");')]
        assert chr(10).join(['rmSetTriggerEffectParamInt("PlayerID", 0);', '\trmSetTriggerEffectParam("TechID", "cTechzpConverGate");', '\trmSetTriggerEffectParamInt("Status", 2);']) in s
        x = (REPO / "data/techtreemods.xml").read_text(encoding="utf-8", errors="replace")
        i = x.index('<tech name="zpConverGate"')
        assert 'toprotoid="SPCFortGate" fromprotoid="zpInvisibleGateSocket"' in x[i:x.index("</tech>", i)]

    def test_bridge_export_carries_invisible_gate_sockets(self):
        b = (REPO / "game/randmaps/groupings/EU_SPC_London_Bridge.xml").read_bytes()
        assert b.count(b">zpInvisibleGateSocket</unit>") == 2 and b"SPCFortGate" not in b and b"zpSPCWaterSpawnPoint" not in b and b"<heights>" in b
        assert (REPO / "sandbox/backups/groupings/EU_SPC_London_Bridge_2026-09-21_waterspawn_placeholders.xml").is_file()


class TestCountryside:
    """9 / 9.2 / 12.7 (user 2026-09-22): New England grass on Paris's turbulence, Istanbul's patches and object method -
    resources after the wall hills, fussiest first, counts per bank from that bank's head-count, treasures from the
    westEurope pool at difficulty 3 and 4, every def fenced off cliffs, walls, blocks, plateaus and routes."""

    def test_countryside_helper_new_england_grass_on_paris_turbulence(self):
        t = _text(LONDON)
        h = _code(t[t.index("int countryside(string name"):t.index("void countryPatch(")])
        for line in ("rmSetAreaBaseHeight(area, 1.0);", "rmSetAreaElevationType(area, cElevTurbulence);", "rmSetAreaElevationVariation(area, 2.0);",
                     "rmSetAreaElevationPersistence(area, 0.2);", "rmSetAreaElevationNoiseBias(area, 1);", "rmAddAreaConstraint(area, constraint);",
                     "rmAddAreaConstraint(area, wallConstraint);", 'rmSetAreaMix(area, "newengland_grass");', "return(area);"):
            assert line in h, line
        assert "italy_cliff_top" not in h and "rmSetBaseTerrainMix" not in t
        s = _code(_section(t, "// ---- 9. CITY FLOOR", "// ---- 9.2 PAINT PATCHES"))
        assert re.search(r'int countryS = countryside\("countryside S", zRiver-rmZTilesToFraction\([^)]*\), avoidPlateauShort, avoidWallMedium\);', s)
        assert re.search(r'int countryN = countryside\("countryside N", zRiver\+rmZTilesToFraction\([^)]*\), avoidPlateauShort, avoidWallMedium\);', s)

    def test_patches_box_fenced_after_the_base_pass_before_the_wall_terrain(self):
        t = _text(LONDON)
        assert t.index("// ---- 9.2 PAINT PATCHES") < t.index("// ---- 9.5 THE WALL TERRAIN")
        s = _code(_section(t, "// ---- 9.2 PAINT PATCHES", "// ---- 9.5 THE WALL TERRAIN"))
        assert "int countryPatchCount = 5;" in s and "int countryPatchTiles = 60;" in s
        assert "float stripEdgeS = zRiverAsk - rmZMetersToFraction(laneLegM) - rmZTilesToFraction(cityDistTiles + cityDepthTiles);" in s
        assert 'int stripBoxS = rmCreateBoxConstraint("countryside strip S", 0.0, rmZMetersToFraction(6.0), 1.0, stripEdgeS - rmZMetersToFraction(6.0), 0.01);' in s
        assert 'int stripBoxN = rmCreateBoxConstraint("countryside strip N", 0.0, stripEdgeN + rmZMetersToFraction(6.0), 1.0, 1.0 - rmZMetersToFraction(6.0), 0.01);' in s
        calls = re.findall(r'countryPatch\("country patch (\w+) (S|N) " \+ cp, "([^"]*)", countryPatchTiles, (stripBox[SN]), avoidWallMedium, avoidTradeRouteWall, avoidPatch\);', s)
        assert calls == [("grass", "S", "italy_cliff_top_grass", "stripBoxS"), ("dirt", "S", "italy_grass_dirt", "stripBoxS"),
                         ("grass", "N", "italy_cliff_top_grass", "stripBoxN"), ("dirt", "N", "italy_grass_dirt", "stripBoxN")]
        h = _code(t[t.index("void countryPatch("):t.index("// ---- object defs")])
        assert "rmSetAreaCoherence(area, 0.1);" in h and 'rmAddAreaToClass(area, rmClassID("classPatch"));' in h and "rmSetAreaLocation" not in h and "BaseHeight" not in h

    def test_constraints_in_metres(self):
        t = _code(_text(LONDON))
        for line in ('int avoidWallMedium = rmCreateTypeDistanceConstraint("avoid wall object medium", "AbstractWall", 2.0);',
                     'int avoidPatch = rmCreateClassDistanceConstraint("patch vs. patch", rmClassID("classPatch"), 4.0);',
                     'int avoidCliff5 = rmCreateClassDistanceConstraint("objects off the cliffs", rmClassID("classCliff"), 5.0);',
                     'int avoidBlocks8 = rmCreateClassDistanceConstraint("objects off the blocks", rmClassID("classBlock"), 8.0);',
                     'int avoidPlateau8 = rmCreateClassDistanceConstraint("objects off the plateaus", rmClassID("classPlateau"), 8.0);',
                     'int avoidWallObjXL = rmCreateTypeDistanceConstraint("avoid wall object xl", "AbstractWall", 20.0);',
                     'int avoidWallObjTree = rmCreateTypeDistanceConstraint("avoid wall object trees", "AbstractWall", 10.0);',
                     'int avoidTradeRouteRes = rmCreateTradeRouteDistanceConstraint("resources off the routes", 8.0);',
                     'int mineVsMine = rmCreateTypeDistanceConstraint("mine v mine", "MineTin", 60.0);',
                     'int deerVsDeer = rmCreateTypeDistanceConstraint("herd v herd", "Deer", 40.0);',
                     'int berryVsBerry = rmCreateTypeDistanceConstraint("berries v berries", "BerryBush", 40.0);',
                     'int nugVsNug = rmCreateTypeDistanceConstraint("treasure v treasure", "AbstractNugget", 50.0);',
                     'int treeVsTree = rmCreateTypeDistanceConstraint("tree clump v tree clump", "TreeNewEngland", 16.0);',
                     'int belowCliffs = rmCreateMaxHeightConstraint("below the cliffs", 3.5);',
                     'float rimRadiusM = sqrt(rimHalfX * rimHalfX + rimHalfZ * rimHalfZ) - rimCornerM;',
                     'int insideWorld = rmCreatePieConstraint("inside the world circle", 0.5, 0.5, 0.0, rimRadiusM, rmDegreesToRadians(0), rmDegreesToRadians(360));',
                     'int insideFrame = rmCreateBoxConstraint("inside the frame", rmXMetersToFraction(8.0), rmZMetersToFraction(8.0), 1.0 - rmXMetersToFraction(8.0), 1.0 - rmZMetersToFraction(8.0), 0.01);'):
            assert line in t, line
        assert t.index("int avoidWallMedium") < t.index("int countryS = countryside(")

    def _objects(self):
        t = _text(LONDON)
        return _code(_section(t, "// ---- 12.7 THE COUNTRYSIDE OBJECTS", "int harbourN1PostUnit"))

    def test_objects_after_the_hills_fussiest_first_trees_last(self):
        t = _code(_text(LONDON))
        assert t.index('wallCliff("wall hill N4"') < t.index('rmCreateObjectDef("countryside tin")') < t.index("int harbourN1PostUnit")
        s = self._objects()
        order = [re.search(r'"countryside (\w+)"', m).group(1) for m in re.findall(r'rmCreateObjectDef\("countryside \w+"\)', s)]
        assert order == ["tin", "deer", "berries", "treasure", "trees"]
        assert "int resScale = cNumberNonGaiaPlayers / 4;" in s
        assert re.search(r"int seatsBankD = defenderCount;\n\tint seatsBankA = attackerCount;\n\tif \(cNumberTeams != 2\)", s)
        assert "if (seatsBankD < 1) seatsBankD = 1;" in s and "if (seatsBankA < 1) seatsBankA = 1;" in s
        assert re.search(r"int countryD = countryS;\n\tint countryA = countryN;\n\tif \(defenderBank == 1\)\n\t\{\n\t\tcountryD = countryN;\n\t\tcountryA = countryS;\n\t\}", s)

    def test_each_def_its_items_fences_and_counts(self):
        s = self._objects()
        def block(name):
            i = s.index('rmCreateObjectDef("countryside %s")' % name); j = s.index("rmCreateObjectDef(", i + 10) if s.find("rmCreateObjectDef(", i + 10) > 0 else s.index("rmEchoInfo", i)
            return s[i:j]
        rim = {"insideWorld", "insideFrame"}        # the world-circle pie and the 8 m frame box (user 2026-09-22)
        fences = {"tin": {"mineVsMine", "avoidBlocks8", "avoidPlateau8", "avoidWallObjXL", "avoidCliff5", "belowCliffs", "avoidTradeRouteRes"} | rim,
                  "deer": {"deerVsDeer", "avoidBlocks8", "avoidPlateau8", "avoidWallObjXL", "avoidCliff5", "belowCliffs", "avoidTradeRouteRes"} | rim,
                  "berries": {"berryVsBerry", "avoidBlocks8", "avoidPlateau8", "avoidWallObjXL", "avoidCliff5", "belowCliffs", "avoidTradeRouteRes"} | rim,
                  "treasure": {"nugVsNug", "avoidBlocks8", "avoidPlateau8", "avoidWallObjXL", "avoidCliff5", "belowCliffs", "avoidTradeRouteRes"} | rim,
                  "trees": {"treeVsTree", "avoidBlocks8", "avoidPlateau8", "avoidWallObjTree", "avoidCliff5", "belowCliffs", "avoidTradeRouteRes"} | rim}
        items = {"tin": ['"MineTin", 1, 0.0'], "deer": ['"Deer", rmRandInt(6, 8), 6.0'], "berries": ['"BerryBush", 5, 4.0'], "treasure": ['"Nugget", 1, 0.0'],
                 "trees": ['"TreeNewEngland", rmRandInt(5, 7), 10.0', '"TreeGreatLakes", rmRandInt(2, 3), 11.0', '"UnderbrushForest", rmRandInt(3, 4), 9.0']}
        counts = {"tin": ["seatsBankD + 1", "seatsBankA + 1"], "deer": ["seatsBankD + 1", "seatsBankA + 1"], "berries": ["seatsBankD", "seatsBankA"],
                  "treasure": ["2 + resScale", "2 + resScale", "1 + resScale", "1 + resScale"], "trees": ["3 + 2 * resScale", "3 + 2 * resScale"]}
        for name in ("tin", "deer", "berries", "treasure", "trees"):
            b = block(name)
            assert set(re.findall(r"rmAddObjectDefConstraint\(\w+, (\w+)\);", b)) == fences[name], name
            assert re.findall(r"rmAddObjectDefItem\(\w+, (.*?)\);", b) == items[name], name
            got = re.findall(r"rmPlaceObjectDefInArea\(\w+, 0, (country[DA]), ([^)]*)\);", b)
            assert [a for a, _ in got] == (["countryD", "countryA"] * (2 if name == "treasure" else 1)) and [c for _, c in got] == counts[name], name
        assert "rmSetObjectDefCreateHerd(countryDeer, true);" in block("deer")
        assert 'rmAddObjectDefToClass(countryTrees, rmClassID("classForest"));' in block("trees")
        tb = block("treasure")
        assert tb.index("rmSetNuggetDifficulty(3, 3);") < tb.index("rmPlaceObjectDefInArea(countryNugget, 0, countryD, 2 + resScale);") < tb.index("rmSetNuggetDifficulty(4, 4);") < tb.index("rmPlaceObjectDefInArea(countryNugget, 0, countryD, 1 + resScale);")

    def test_the_treasure_pool_and_the_map_types(self):
        t = _text(LONDON)
        assert 'rmSetMapType("westEurope")' in t and 'rmSetMapType("piratehistoricalmap")' in t
        assert "deliberately absent at the layout stage" not in t


class TestVictory:
    """13.4 (user 2026-09-22): Paris's victory system on the two Towers - both zpSPCCapturableFlagNoIcon flags held by one team
    for 480 s -> Team Victory; objectives per side; the flag proto swapped in both Tower exports."""

    def test_paris_shape_on_two_flags(self):
        t = _code(_text(LONDON)); v = t[t.index("rmObjectiveScreenSetTitle(503557);"):t.index('rmCreateTrigger("LondonStartingTechs")')]
        for line in ("rmObjectiveScreenSetGoal(503558);", "rmObjectiveAdd(503559, 502023, true, true, true);", "rmObjectiveSetTeam(1, 1);",
                     "rmObjectiveAdd(503560, 502023, true, true, true);", "rmObjectiveSetTeam(2, 2);", "int victoryCountDown = 480;",
                     'rmCreateTrigger("TeamVictory" + i);', 'rmCreateTrigger("Towers_ON" + i);', 'rmCreateTrigger("Victory_Counter" + i);', 'rmCreateTrigger("Victory_Counter_OFF" + i);',
                     'rmAddTriggerEffect("Team Victory");', 'rmSetTriggerConditionParam("Protounit", "zpSPCCapturableFlagNoIcon");',
                     'rmSetTriggerConditionParamInt("Count", 2);', 'rmAddTriggerEffect("Counter:Add Timer");', 'rmSetTriggerEffectParamInt("Start", victoryCountDown);',
                     'rmSetTriggerEffectParamInt("Event", rmTriggerID("TeamVictory" + i));', 'rmAddTriggerEffect("Counter Stop");', 'rmSetTriggerEffectParam("Msg", "{503561}");', 'rmSetTriggerEffectParam("Msg", "{503562}");'):
            assert line in v, line
        assert v.count('rmSetTriggerConditionParam("Protounit", "zpSPCCapturableFlagNoIcon");') == 2 and 'rmSetTriggerConditionParam("Op", "<");' in v
        assert 'rmGetGroupingInstanceUnitByType(towerSInst, "zpSPCCapturableFlagNoIcon") + instanceIdShift;' in t and 'rmGetGroupingInstanceUnitByType(towerNInst, "zpSPCCapturableFlagNoIcon") + instanceIdShift;' in t
        for n in ("EU_SPC_London_Tower_01", "EU_SPC_London_Tower_02"):
            w = (REPO / ("game/randmaps/groupings/%s.xml" % n)).read_bytes()
            assert w.count(b">zpSPCCapturableFlagNoIcon</unit>") == 1 and b"deSPCCapturableFlagCossack" not in w and b">SPCFortWallMedium</unit>" not in w
        st = (REPO / "data/strings/english/stringmods.xml").read_text(encoding="utf-8")
        assert all(('_locid="%d"' % i) in st for i in range(503557, 503563))


class TestTowerOwnership:
    """13.3 (user 2026-09-22, 'wrong towers' / 'wrong unit'): the Tower complex follows the flag's owner. Exports: the four
    corner zpSPCFortTowerProp are Caribbean Wars' tower socket zpSPCSocketCityTowerWooden (the owner builds
    zpSPCCityTowerWooden on it), each SPCFortGate has King of Bohemia's unique invisible gate socket under it
    (A/B in Tower_01, C/D in Tower_02, file order). Script: the building by id, Caribbean Wars' area sweep by UnitType
    from the building over every source player, the gate sockets converted by id, Bohemia's GateN_Rebuilt (transform
    tech per socket) fired on capture with a 500 ms deactivator."""

    SWEEP = ("SPCFortGate", "zpSPCSocketCityTowerWooden", "zpSPCCityTowerWooden", "deSPCFortWallMediumProp", "deSPCFortCornerProp", "deSPCFortWallLargeProp")
    SOCKETS = {"EU_SPC_London_Tower_01": ("zpInvisibleGateSocketA", "zpInvisibleGateSocketB"), "EU_SPC_London_Tower_02": ("zpInvisibleGateSocketC", "zpInvisibleGateSocketD")}

    def _block(self):
        t = _code(_text(LONDON))
        return t, t[t.index("int towerSweepM = 40;"):t.index("int victoryCountDown = 480;")]

    def test_exports_tower_sockets_and_unique_gate_sockets(self):
        for name, sockets in self.SOCKETS.items():
            b = (REPO / ("game/randmaps/groupings/%s.xml" % name)).read_bytes()
            assert b.count(b"\r\n") == b.count(b"\n") and b"zpSPCFortTowerProp" not in b and b"zpSPCFortWallProp" not in b and b.count(b">deSPCFortWallLargeProp</unit>") == 10
            assert b.count(b">zpSPCSocketCityTowerWooden</unit>") == 4 and b.count(b">SPCFortGate</unit>") == 2
            assert b.count(b">zpInvisibleGateSocket</unit>") == 0
            lines = b.decode("utf-8").split(chr(13) + chr(10))
            gates = [i for i, l in enumerate(lines) if l.endswith(">SPCFortGate</unit>")]
            assert len(gates) == 2
            for i, proto in zip(gates, sockets):
                head = lines[i][:lines[i].index(">SPCFortGate</unit>")]
                assert lines[i + 1] == head + ">" + proto + "</unit>", (name, proto)     # same position and orientation as the gate
            old = (REPO / ("sandbox/backups/groupings/%s_2026-09-22_towerprops.xml" % name)).read_bytes()
            assert old.replace(b">zpSPCFortTowerProp</unit>", b">zpSPCSocketCityTowerWooden</unit>").count(b"</unit>") == b.count(b"</unit>") - 2
            for l in lines:
                if l.endswith(">zpSPCSocketCityTowerWooden</unit>"):
                    assert (l.replace(">zpSPCSocketCityTowerWooden</unit>", ">zpSPCFortTowerProp</unit>") + chr(13) + chr(10)).encode("utf-8") in old

    def test_protos_and_transform_techs_exist(self):
        pm = (REPO / "data/protomods.xml").read_text(encoding="utf-8", errors="replace")
        i = pm.index('name="zpSPCSocketCityTowerWooden"'); u = pm[i:pm.index("</unit>", i)]
        assert "<socketbuildprotounit>zpSPCCityTowerWooden</socketbuildprotounit>" in u and "<unittype>TowerSocket</unittype>" in u
        assert 'name="zpSPCCityTowerWooden"' in pm
        tt = (REPO / "data/techtreemods.xml").read_text(encoding="utf-8", errors="replace")
        for n, proto in enumerate(("zpInvisibleGateSocketA", "zpInvisibleGateSocketB", "zpInvisibleGateSocketC", "zpInvisibleGateSocketD"), 1):
            assert ('name="%s"' % proto) in pm
            j = tt.index('<tech name="zpConverGate%d"' % n)
            assert 'toprotoid="SPCFortGate" fromprotoid="%s"' % proto in tt[j:tt.index("</tech>", j)]

    def test_id_block_and_placement_order(self):
        t, _ = self._block()
        for var, inst, proto in (("towerSGate1SocketUnit", "towerSInst", "zpInvisibleGateSocketA"), ("towerSGate2SocketUnit", "towerSInst", "zpInvisibleGateSocketB"),
                                 ("towerNGate1SocketUnit", "towerNInst", "zpInvisibleGateSocketC"), ("towerNGate2SocketUnit", "towerNInst", "zpInvisibleGateSocketD")):
            assert ('int %s = rmGetGroupingInstanceUnitByType(%s, "%s") + instanceIdShift;' % (var, inst, proto)) in t
        # the literal harbour indices (fix B) hold: both Towers are placed after section 8's guard nuggets
        assert t.index("rmPlaceObjectDefAtLoc(harbourS2GuardDef, 0, harbourS2GuardX, harbourS2GuardZ);") < t.index("int towerSInst = rmPlaceGroupingInstanceAtLoc(blockTowerS")

    def test_sweep_from_the_building_over_every_source_player(self):
        _, s = self._block()
        assert "int towerGateRebuildM = 15;" in s
        for bank, bld, g1, g2 in (("S", "towerSBldUnit", "towerSGate1SocketUnit", "towerSGate2SocketUnit"), ("N", "towerNBldUnit", "towerNGate1SocketUnit", "towerNGate2SocketUnit")):
            fam = s[s.index('rmSwitchToTrigger(rmTriggerID("TowerConv%s_Plr" + p));' % bank):s.index('rmSwitchToTrigger(rmTriggerID("Tower%sGate1_Rebuilt" + k));' % bank)]
            assert fam.count('rmAddTriggerEffect("Convert");') == 3 and ('rmSetTriggerEffectParam("SrcObject", "" + %s);' % bld) in fam
            assert fam.index("for (i = 0; <= cNumberNonGaiaPlayers)") < fam.index('rmSetTriggerEffectParam("SrcObject", "" + %s);' % g1) < fam.index('rmSetTriggerEffectParam("SrcObject", "" + %s);' % g2)
            for proto in self.SWEEP:
                seg = chr(10).join(['\t\t\t\trmAddTriggerEffect("Convert Units in Area");', '\t\t\t\trmSetTriggerEffectParam("SrcObject", "" + %s);' % bld,
                                    '\t\t\t\trmSetTriggerEffectParamInt("SrcPlayer", i);', '\t\t\t\trmSetTriggerEffectParamInt("TrgPlayer", p);',
                                    '\t\t\t\trmSetTriggerEffectParam("UnitType", "%s");' % proto, '\t\t\t\trmSetTriggerEffectParamInt("Dist", towerSweepM);'])
                assert fam.count(seg) == 1, (bank, proto)
            assert fam.count('rmAddTriggerEffect("Convert Units in Area");') == len(self.SWEEP)
            for ev in ("Tower%sGate1_Rebuilt" % bank, "Tower%sGate2_Rebuilt" % bank, "Tower%sGate_Rebuilt_Deactivator" % bank):
                assert ('rmSetTriggerEffectParamInt("EventID", rmTriggerID("%s" + p));' % ev) in fam
            assert fam.index('rmTriggerID("Tower%sGate_Rebuilt_Deactivator" + p)' % bank) < fam.index('rmTriggerID("TowerConv%s_Plr" + q)' % bank)
        assert '"zpInvisibleGateSocket"' not in s     # the generic socket is the bridge's (gaia's zpConverGate at start)

    def test_bohemia_rebuild_once_on_capture(self):
        _, s = self._block()
        for bank, socks in (("S", (("towerSGate1SocketUnit", "cTechzpConverGate1"), ("towerSGate2SocketUnit", "cTechzpConverGate2"))),
                            ("N", (("towerNGate1SocketUnit", "cTechzpConverGate3"), ("towerNGate2SocketUnit", "cTechzpConverGate4")))):
            for n, (g, tech) in enumerate(socks, 1):
                body = chr(10).join(['\t\t\trmSwitchToTrigger(rmTriggerID("Tower%sGate%d_Rebuilt" + k));' % (bank, n), '\t\t\trmAddTriggerCondition("Units in Area");',
                                     '\t\t\trmSetTriggerConditionParam("DstObject", "" + %s);' % g, '\t\t\trmSetTriggerConditionParamInt("Player", k);',
                                     '\t\t\trmSetTriggerConditionParam("UnitType", "SPCFortGate");', '\t\t\trmSetTriggerConditionParamInt("Dist", towerGateRebuildM);',
                                     '\t\t\trmSetTriggerConditionParam("Op", "==");', '\t\t\trmSetTriggerConditionParamInt("Count", 0);',
                                     '\t\t\trmAddTriggerEffect("ZP Set Tech Status (XS)");', '\t\t\trmSetTriggerEffectParamInt("PlayerID", k);',
                                     '\t\t\trmSetTriggerEffectParam("TechID", "%s");' % tech, '\t\t\trmSetTriggerEffectParamInt("Status", 2);',
                                     '\t\t\trmSetTriggerPriority(4);', '\t\t\trmSetTriggerActive(false);', '\t\t\trmSetTriggerRunImmediately(true);', '\t\t\trmSetTriggerLoop(false);'])
                assert s.count(body) == 1, (bank, n)
            de = chr(10).join(['\t\t\trmSwitchToTrigger(rmTriggerID("Tower%sGate_Rebuilt_Deactivator" + k));' % bank, '\t\t\trmAddTriggerCondition("Timer ms");',
                               '\t\t\trmSetTriggerConditionParamInt("Param1", 500);', '\t\t\trmAddTriggerEffect("Disable Trigger");',
                               '\t\t\trmSetTriggerEffectParamInt("EventID", rmTriggerID("Tower%sGate1_Rebuilt" + k));' % bank, '\t\t\trmAddTriggerEffect("Disable Trigger");',
                               '\t\t\trmSetTriggerEffectParamInt("EventID", rmTriggerID("Tower%sGate2_Rebuilt" + k));' % bank])
            assert s.count(de) == 1, bank
        made = set(re.findall(r'rmCreateTrigger\("([^"]+)"', s)); used = set(re.findall(r'rmTriggerID\("([^"]+)"', s))
        assert made == used and len(made) == 10, (made ^ used)

    SOCKET_VARS = ("towerSSocket1Unit", "towerSSocket2Unit", "towerSSocket3Unit", "towerSSocket4Unit", "towerNSocket1Unit", "towerNSocket2Unit", "towerNSocket3Unit", "towerNSocket4Unit")

    def test_sockets_last_in_the_exports(self):
        # AztecCity's order law (user 2026-09-22): the tower sockets are the export's last four units, so a marker placed right after
        # the grouping addresses them as marker - 1 .. - 4
        for name in self.SOCKETS:
            lines = (REPO / ("game/randmaps/groupings/%s.xml" % name)).read_bytes().decode("utf-8").split(chr(13) + chr(10))
            end = lines.index(chr(9) + "</units>")
            assert all(l.endswith(">zpSPCSocketCityTowerWooden</unit>") for l in lines[end - 4:end]) and not lines[end - 5].endswith(">zpSPCSocketCityTowerWooden</unit>")

    def test_markers_right_after_the_groupings(self):
        t = re.sub(r"[ \t]+//[^\n]*", "", _code(_text(LONDON)))   # trailing comments off
        for bank, var, x, z in (("S", "towerSMark", "locX78", "locZs12"), ("N", "towerNMark", "locX78", "locZn12")):
            seg = chr(10).join(["\tint tower%sInst = rmPlaceGroupingInstanceAtLoc(blockTower%s, %s, %s, 0);" % (bank, bank, x, z),
                                '\tint %s = rmCreateObjectDef("tower mark %s");' % (var, "south" if bank == "S" else "north"),
                                '\trmAddObjectDefItem(%s, "zpSPCWaterSpawnPoint", 1, 0.0);' % var,
                                "\trmSetObjectDefAllowOverlap(%s, true);" % var, "\trmSetObjectDefMinDistance(%s, 0.0);" % var, "\trmSetObjectDefMaxDistance(%s, 0.0);" % var,
                                "\trmPlaceObjectDefAtLoc(%s, 0, %s, %s);" % (var, x, z)])
            assert t.count(seg) == 1, bank
            assert ("int %sUnit = rmGetUnitPlaced(%s, 0) + instanceIdShift;" % (var, var)) in t       # Istanbul 4205-4206
            for n in range(1, 5):
                assert ("int tower%sSocket%dUnit = %sUnit - %d;" % (bank, n, var, 5 - n)) in t     # AztecCity 1348-1351

    def test_ai_socket_build_is_the_last_block(self):
        raw = _text(LONDON); h = raw.index("// ---- 16. AI SOCKET BUILD"); t = _code(raw); i = t.index('rmCreateTrigger("LondonAI_Plr" + k);'); s = t[i:]
        assert raw[h:].count("// ----") == 1 and raw.rindex("rmCreateTrigger(") > h and s.rstrip().endswith("} // END")
        assert chr(10).join(['\t\trmAddTriggerCondition("ZP PLAYER Human");', '\t\trmSetTriggerConditionParamInt("Player", k);', '\t\trmSetTriggerConditionParam("MyBool", "false");',
                             '\t\trmAddTriggerEffect("ZP Set Tech Status (XS)");', '\t\trmSetTriggerEffectParamInt("PlayerID", k);',
                             '\t\trmSetTriggerEffectParam("TechID", "cTechzpSPCPirateCityStatesAI");', '\t\trmSetTriggerEffectParamInt("Status", 2);']) in s
        for var in self.SOCKET_VARS:
            tag = var[5] + var[12]     # towerSSocket1Unit -> S1
            on = chr(10).join(['\t\trmSwitchToTrigger(rmTriggerID("BuildTower%s_ON_Plr" + k));' % tag, '\t\trmAddTriggerCondition("Units in Area");',
                               '\t\trmSetTriggerConditionParam("DstObject", "" + %s);' % var, '\t\trmSetTriggerConditionParamInt("Player", k);',
                               '\t\trmSetTriggerConditionParam("UnitType", "zpSPCWoodenTowerAIProxy");', '\t\trmSetTriggerConditionParamInt("Dist", 10);',
                               '\t\trmSetTriggerConditionParam("Op", ">=");', '\t\trmSetTriggerConditionParamInt("Count", 1);',
                               '\t\trmAddTriggerEffect("Socket Build");', '\t\trmSetTriggerEffectParamInt("PlayerID", k);',
                               '\t\trmSetTriggerEffectParam("Socket", "" + %s);' % var, '\t\trmSetTriggerEffectParam("Protounit", "zpSPCCityTowerWooden");',
                               '\t\trmAddTriggerEffect("Fire Event");', '\t\trmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower%s_OFF_Plr" + k));' % tag])
            assert s.count(on) == 1, var
            off = chr(10).join(['\t\trmSwitchToTrigger(rmTriggerID("BuildTower%s_OFF_Plr" + k));' % tag, '\t\trmAddTriggerCondition("Timer ms");',
                                '\t\trmSetTriggerConditionParamFloat("Param1", 1200);', '\t\trmAddTriggerEffect("Fire Event");',
                                '\t\trmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower%s_ON_Plr" + k));' % tag])
            assert s.count(off) == 1, var
            assert ('rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower%s_ON_Plr" + k));' % tag) in s[:s.index('rmSwitchToTrigger(rmTriggerID("BuildTowerS1_ON_Plr" + k));')]
        made = set(re.findall(r'rmCreateTrigger\("([^"]+)"', s)); used = set(re.findall(r'rmTriggerID\("([^"]+)"', s))
        assert made == used and len(made) == 17, (made ^ used)
        tt = (REPO / "data/techtreemods.xml").read_text(encoding="utf-8", errors="replace"); j = tt.index('<tech name="zpSPCPirateCityStatesAI"')
        assert '<effect type="CommandAdd" proto="zpSPCWoodenTowerAIProxy" page="0" column="4">' in tt[j:tt.index("</tech>", j)] and "<target type=\"ProtoUnit\">zpSPCSocketCityTowerWooden</target>" in tt[j:tt.index("</tech>", j)]

    def test_twin_identical_and_crlf(self):
        a = LONDON.read_bytes(); b = (STEAM / "00000_zplondon.xs").read_bytes()
        assert a == b and a.count(b"\r\n") == a.count(b"\n")


class TestScope:

    def test_reserved_columns_take_the_berry_mill(self):
        t = _code(_text(LONDON))
        assert 'cityBlock("Mill Food4", "EU_Resource_Block_Food4")' in t and "Food3" not in t
        assert (REPO / "game/randmaps/groupings/EU_Resource_Block_Food4.xml").is_file()

    def test_base_mix_and_the_1v1_frame(self):
        t = _code(_text(LONDON))
        assert 'rmTerrainInitialize("new_england' + chr(92) + 'cliff_inland_top_ne", 1.0);' in t and "rmSetBaseTerrainMix" not in t   # a plain type: a base MIX scatters its rocks (2026-09-21)
        assert 'rmSetAreaMix(area, "newengland_grass");' in t                                    # the countryside's mix (2026-09-22)
        assert "int baseSizeZ = 613;" in t and "baseSizeZ = 653;" in t and "baseSizeZ = 733;" in t

    def test_park_bakes_the_royal_huntsman_rescue(self):
        t = _code(_text(LONDON))
        i = t.index("rmPlaceGroupingAtLoc(blockParkBig, 0, locX000, locZs45);")
        assert t[t.rindex("rmSetNuggetDifficulty(", 0, i):i].startswith("rmSetNuggetDifficulty(607, 607);")
        park = (REPO / "game/randmaps/groupings/EU_SPC_Park_big.xml").read_bytes()
        assert park.count(b"Nugget") == 1 and b">NuggetWolfRock</unit>" in park and b"<heights>" in park   # the user's 2026-09-22 01:35 export: the 607 huntsman record's own proto
        n = (REPO / "data/nuggetmods.xml").read_text(encoding="utf-8", errors="replace")
        assert "<name>zpRockRoyalHuntsman</name>" in n and n.count("<difficulty>607</difficulty>") == 1

    def test_unit_ids_derive_in_one_block_through_the_two_shifts(self):
        # Istanbul's architecture (zpistanbulb.xs 4173-4193): both shifts declared together at the head of 13, every id through them
        t = _code(_text(LONDON))
        assert t.count("int instanceIdShift = 3;") == 1 and "instanceIdShiftIndividual" not in t   # grouping shift measured 2026-09-22; the object-def ids are literal indices (fix B)
        assert t.index('rmCreateObjectDef("countryside tin")') < t.index("int instanceIdShift = 3;") < t.index("int harbourN1PostUnit")
        for s, post, guard in (("N1", 169, 363), ("N2", 170, 368), ("S1", 171, 373), ("S2", 172, 378)):                # fix B: literal indices (census 2026-09-22)
            assert ("int harbour%sPostUnit = %d;" % (s, post)) in t and ("int harbour%sGuardUnit = %d;" % (s, guard)) in t and ("rmSetTriggerConditionParam(\"NuggetObject\", \"\" + harbour%sGuardUnit);" % s) in t
        inst = re.findall(r"int \w+ = rmGetGroupingInstanceUnitByType\([^;]*;", t)
        assert len(inst) == 18 and all(r.endswith("+ instanceIdShift;") for r in inst)   # 14 + the four gate sockets (13.3, 2026-09-22)
        plain = chr(10).join(l for l in t.split(chr(10)) if not re.match(r"\s*int \w+Socket\dUnit = \w+MarkUnit - [1-4];$", l))   # AztecCity 1348-1351: marker - n is the one admitted literal form
        assert not re.search(r"\\w*(Unit|Id|Flag|Nug|Socket|Bld|Post)\w*\s*[-+]\s*\d+\s*[;)]", plain.replace("Idx", "").replace("Tiles", ""))   # no other literal id arithmetic

    def test_twin_identical_and_crlf(self):
        raw = LONDON.read_bytes()
        assert raw == (STEAM / "00000_zplondon.xs").read_bytes()
        assert raw.count(b"\r\n") == raw.count(b"\n")
