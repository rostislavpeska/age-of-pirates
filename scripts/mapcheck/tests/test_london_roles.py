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

    def test_interim_placement_reads_the_coin_the_same_way(self):
        # spawnSwitch 0: team 1 on the far-z line (the north bank), team 0 on the near-z line (the south bank)
        s = _section(_text(LONDON), "// ---- 12.3 INTERIM PLACEMENT", "int playerStart = rmCreateStartingUnitsObjectDef")
        first = s[s.index("if (spawnSwitch ==0){"):s.index("else{")]
        assert re.search(r"rmSetPlacementTeam\(0\);\n\t\t\trmPlacePlayersLine\(0\.10, zPlLine,", first)
        assert re.search(r"rmSetPlacementTeam\(1\);\n\t\t\trmPlacePlayersLine\(0\.90, zPlLineFar,", first)

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
    rows 7-8 + 3-4, houses rows 5-6, the filler; THREE = three seats + the filler; FOUR = four seats; 5+ and
    non-2-team lobbies = the interim line, all eight spots filled."""

    SIDES = (("defender", "Defender", "locZdSeat", "locZd4", "locZd6", "locZd56"), ("attacker", "Attacker", "locZaSeat", "locZa4", "locZa6", "locZa56"))

    def _sec(self):
        return _code(_section(_text(LONDON), "// ---- 12.2 SEATS BY ROLE", "// ---- 12.3 INTERIM PLACEMENT"))

    def _block(self, side, k):
        s = self._sec()
        i = s.index("if (%sCount == %d)" % (side, k)); j = s.index("\n\t\t}", i)
        return re.findall(r"(rmPlacePlayer|rmSetNuggetDifficulty|rmPlaceGroupingAtLoc)\(([^)]*)\);", s[i:j])

    def test_blocks_and_the_bank_keyed_columns(self):
        s = self._sec()
        for line in ('int blockPlayerLondon = cityBlock("player london", "EU_SPC_Player_London");',
                     'int blockPropFiller = cityBlock("prop filler", "EU_SPC_Prop_Block");',
                     'int blockParkBig02 = cityBlock("park big turned", "EU_SPC_Park_big_02");',
                     "float locX56 = (locX5 + locX6) * 0.5;", "float locZs56 = wallS-rmZTilesToFraction(col5+col6)*0.5;",
                     "float locZn56 = wallN+rmZTilesToFraction(col5+col6)*0.5;",
                     "if (cNumberTeams == 2 && defenderCount <= 4 && attackerCount <= 4)\n\t\tseatsByRole = 1;"):
            assert line in s, line
        d = re.search(r"float locZdSeat = locZs5;.*?if \(defenderBank == 1\)\n\t\{(.*?)\n\t\}", s, re.S).group(1)
        assert all(x in d for x in ("locZdSeat = locZn5;", "locZaSeat = locZs5;", "locZd4 = locZn4;", "locZa4 = locZs4;", "locZd6 = locZn6;", "locZa6 = locZs6;", "locZd56 = locZn56;", "locZa56 = locZs56;"))
        assert s.index("if (seatsByRole == 1)") < s.index("if (defenderCount == 1)") < s.index("if (attackerCount == 1)") < s.index("if (seatsByRole == 0)")

    def test_one_per_side_is_the_figma_strip(self):
        for side, o, S, z5, z7, z67 in self.SIDES:
            assert self._block(side, 1) == [
                ("rmPlacePlayer", "first%s, locX78, %s" % (o, S)),
                ("rmSetNuggetDifficulty", "607, 607"),                                    # the turned park's Huntsman rock
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
            ], side

    def test_two_per_side(self):
        for side, o, S, z5, z7, z67 in self.SIDES:
            assert self._block(side, 2) == [
                ("rmPlacePlayer", "first%s, locX78, %s" % (o, S)), ("rmPlacePlayer", "second%s, locX34, %s" % (o, S)),
                ("rmPlaceGroupingAtLoc", "blockHouse3, 0, locX5, %s" % z5), ("rmPlaceGroupingAtLoc", "blockHouse4, 0, locX6, %s" % z5),
                ("rmPlaceGroupingAtLoc", "blockHouse5, 0, locX5, %s" % S), ("rmPlaceGroupingAtLoc", "blockHouse6, 0, locX6, %s" % S),
                ("rmPlaceGroupingAtLoc", "blockHouse1, 0, locX5, %s" % z7), ("rmPlaceGroupingAtLoc", "blockHouse2, 0, locX6, %s" % z7),
                ("rmPlaceGroupingAtLoc", "blockPropFiller, 0, locX12, %s" % S),
            ], side

    def test_three_and_four_per_side(self):
        for side, o, S, z5, z7, z67 in self.SIDES:
            assert self._block(side, 3) == [("rmPlacePlayer", "first%s, locX78, %s" % (o, S)), ("rmPlacePlayer", "second%s, locX34, %s" % (o, S)),
                                            ("rmPlacePlayer", "third%s, locX56, %s" % (o, S)), ("rmPlaceGroupingAtLoc", "blockPropFiller, 0, locX12, %s" % S)], side
            assert self._block(side, 4) == [("rmPlacePlayer", "first%s, locX78, %s" % (o, S)), ("rmPlacePlayer", "second%s, locX34, %s" % (o, S)),
                                            ("rmPlacePlayer", "third%s, locX56, %s" % (o, S)), ("rmPlacePlayer", "fourth%s, locX12, %s" % (o, S))], side

    def test_fallback_fills_all_eight_spots(self):
        s = self._sec()
        b = s[s.index("if (seatsByRole == 0)"):s.index('rmEchoInfo("LONDON seats:')]
        fills = re.findall(r"rmPlaceGroupingAtLoc\(blockPropFiller, 0, (locX\d+), (locZ[da]Seat)\);", b)
        assert fills == [(x, z) for z in ("locZdSeat", "locZaSeat") for x in ("locX78", "locX34", "locX56", "locX12")]
        w = (REPO / "game/randmaps/groupings/EU_SPC_Prop_Block.xml").read_text(encoding="utf-8")
        assert "<width>30</width>" in w and "<height>45</height>" in w and "TownCenter" not in w and "Nugget" not in w
        assert (REPO / "game/randmaps/groupings/EU_SPC_Prop_Block.xml").read_bytes() == (STEAM / "groupings/EU_SPC_Prop_Block.xml").read_bytes()
        assert (REPO / "game/randmaps/groupings/EU_SPC_Park_big_02.xml").read_bytes() == (STEAM / "groupings/EU_SPC_Park_big_02.xml").read_bytes()

    def test_seated_players_get_the_block_not_the_command_post(self):
        t = _code(_text(LONDON))
        loop = t[t.index("for(i=1; < cNumberNonGaiaPlayers + 1) {"):t.index("int harbourN1PostUnit")]
        assert "if (seatsByRole == 1)\n\t\t{\n\t\t\trmPlaceGroupingAtLoc(blockPlayerLondon, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));\n\t\t}" in loop
        assert loop.count("deSPCCommandPost") == 1 and loop.index("else") < loop.index("deSPCCommandPost")
        assert loop.count("rmPlaceObjectDefAtLoc(playerStart, i") == 1 and loop.count("rmPlaceObjectDefAtLoc(aiStartUrban, i, 0.5, 0.5)") == 1
        before = t[t.index("int aiStartUrban"):t.index("for(i=1; < cNumberNonGaiaPlayers + 1) {")]
        assert "rmSetNuggetDifficulty(1, 1);" in before        # the player treasure is level 1 (Istanbul 2506, Florence 1266)

    def test_interim_line_only_when_nobody_is_seated(self):
        s = _code(_section(_text(LONDON), "// ---- 12.3 INTERIM PLACEMENT", "int playerStart = rmCreateStartingUnitsObjectDef"))
        assert "if (seatsByRole == 0 && cNumberTeams == 2){" in s and "if (seatsByRole == 0 && cNumberTeams != 2){" in s
        assert not re.search(r"\n\tif \(cNumberTeams == 2\)\{", s) and "else{\n\t\trmPlacePlayersLine" not in s


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
        for line in ('rmSetAreaSize(area, rmAreaTilesToFraction(tiles), rmAreaTilesToFraction(tiles));', 'rmSetAreaCliffType(area, "Italian Cliff");',
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
        assert b == (STEAM / "groupings/EU_SPC_London_Bridge.xml").read_bytes()
        assert (REPO / "sandbox/backups/groupings/EU_SPC_London_Bridge_2026-09-21_waterspawn_placeholders.xml").is_file()


class TestScope:

    def test_reserved_columns_take_the_berry_mill(self):
        t = _code(_text(LONDON))
        assert 'cityBlock("Mill Food4", "EU_Resource_Block_Food4")' in t and "Food3" not in t
        assert (REPO / "game/randmaps/groupings/EU_Resource_Block_Food4.xml").is_file()

    def test_base_mix_and_the_1v1_frame(self):
        t = _code(_text(LONDON))
        assert 'rmTerrainInitialize("new_england' + chr(92) + 'cliff_inland_top_ne", 1.0);' in t and "rmSetBaseTerrainMix" not in t   # a plain type: a base MIX scatters its rocks (2026-09-21)
        assert 'rmSetAreaMix(area, "italy_cliff_top");' in t                                    # the same mix the countryside paints
        assert "int baseSizeZ = 613;" in t and "baseSizeZ = 653;" in t and "baseSizeZ = 773;" in t

    def test_park_bakes_the_royal_huntsman_rescue(self):
        t = _code(_text(LONDON))
        i = t.index("rmPlaceGroupingAtLoc(blockParkBig, 0, locX000, locZs45);")
        assert t[t.rindex("rmSetNuggetDifficulty(", 0, i):i].startswith("rmSetNuggetDifficulty(607, 607);")
        park = (REPO / "game/randmaps/groupings/EU_SPC_Park_big.xml").read_bytes()
        assert park.count(b"Nugget") == 1 and b">NuggetDroppedWood</unit>" in park and b"<heights>" in park
        n = (REPO / "data/nuggetmods.xml").read_text(encoding="utf-8", errors="replace")
        assert "<name>zpRockRoyalHuntsman</name>" in n and n.count("<difficulty>607</difficulty>") == 1

    def test_twin_identical_and_crlf(self):
        raw = LONDON.read_bytes()
        assert raw == (STEAM / "00000_zplondon.xs").read_bytes()
        assert raw.count(b"\r\n") == raw.count(b"\n")
