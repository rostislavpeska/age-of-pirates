"""London's player-role harness (user 2026-09-21): the Florence system - firstDefender .. seventhAttacker - keyed
on the landmark coin, with no seat coordinates yet. Pins the contract so the seat tables can be written on top of it:

  - the helper is Florence's zpGetTeamPlayer, verbatim, at file scope (also Versailles');
  - the landmark coin defenderBank (10.0) puts St Paul + Stuart (+ the Stuart-shaped 2 x 2 with Park and Menagerie)
    on one bank and Minster + Parliament (+ the Parliament-shaped 2 x 2) on the other, exports never rotated;
  - the 14 roles follow the helper's order: defenders = the team on the defender bank, attackers = the other team;
    which lobby team holds which bank is the existing spawnSwitch, read the same way by the interim line placement;
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
        assert "int defenderBank = rmRandInt(0, 1);" in code
        before, after = code.split("if (defenderBank == 1)")
        south = _assigns(before)                     # defaults = defender bank south
        north = dict(south); north.update(_assigns(after))   # the if-block overrides = defender bank north
        return south, north

    def test_defender_bank_south_is_the_layout_that_shipped(self):
        south, _ = self._layouts()
        assert south["locZd12"] == "locZs12" and south["locZa12"] == "locZn12"
        assert south["locZdStuart"] == "locZs1" and south["locZdPark"] == "locZs2"          # Stuart col 1, Park on its -z forecourt side
        assert south["locZaParliament"] == "locZn12" and south["locZaPark"] == "locZn1"     # Parliament cols 1-2, Park row 4 col 1
        assert south["locZsMenagerie"] == "locZs2" and south["locZnMenagerie"] == "locZn2"

    def test_defender_bank_north_keeps_stuarts_forecourt_toward_the_park(self):
        _, north = self._layouts()
        assert north["locZd12"] == "locZn12" and north["locZa12"] == "locZs12"
        assert north["locZdStuart"] == "locZn2" and north["locZdPark"] == "locZn1"          # unrotated export faces -z: Stuart col 2, Park col 1
        assert north["locZaParliament"] == "locZs12" and north["locZaPark"] == "locZs1"
        assert north["locZsMenagerie"] == "locZs2" and north["locZnMenagerie"] == "locZn1"  # behind the north Park

    def test_placements_use_the_keyed_locations_in_the_shipped_call_order(self):
        s = _code(_section(_text(LONDON), "// ---- 10.1 fixed doubles", "// ---- 10.3 the cell table"))
        calls = re.findall(r"rmPlaceGrouping(?:Instance)?AtLoc\((\w+), (?:0, )?(\w+), (\w+)(?:, 0)?\);", s)
        assert calls[:7] == [("blockStPaul", "locX12", "locZd12"), ("blockStuart", "locX34", "locZdStuart"),
                             ("blockTowerS", "locX78", "locZs12"), ("blockMinster", "locX12", "locZa12"),
                             ("blockParliament", "locX3", "locZaParliament"), ("blockTowerN", "locX78", "locZn12"),
                             ("blockTrade", "locX1", "locZs3")]
        assert ("blockPark", "locX3", "locZdPark") in calls and ("blockPark", "locX4", "locZaPark") in calls
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
        s = _section(_text(LONDON), "// ---- 12.1 ROLES", "// ---- 12.2 SEATS BY ROLE")
        calls = re.findall(r"zpGetTeamPlayer\((\d), (defenderTeam|attackerTeam)\);\n\tint (\w+) = g_zpTeamPlayerResult;", s)
        assert [(int(k), team, name) for k, team, name in calls] == \
            [(i + 1, "defenderTeam", o + "Defender") for i, o in enumerate(ORDER)] + \
            [(i + 1, "attackerTeam", o + "Attacker") for i, o in enumerate(ORDER)]
        assert s.count("g_zpTeamPlayerResult") == 14

    def test_defender_team_is_the_team_on_the_defender_bank(self):
        t = _text(LONDON)
        s = _section(t, "// ---- 12.1 ROLES", "// ---- 12.2 SEATS BY ROLE")
        assert re.search(r"int northTeam = 1;\n\tint southTeam = 0;\n\tif \(spawnSwitch == 1\)\n\t\{\n\t\tnorthTeam = 0;\n\t\tsouthTeam = 1;\n\t\}", s)
        assert re.search(r"int defenderTeam = southTeam;\n\tint attackerTeam = northTeam;\n\tif \(defenderBank == 1\)\n\t\{\n\t\tdefenderTeam = northTeam;\n\t\tattackerTeam = southTeam;\n\t\}", s)
        assert "int defenderCount = rmGetNumberPlayersOnTeam(defenderTeam);" in s and "int attackerCount = rmGetNumberPlayersOnTeam(attackerTeam);" in s
        assert t.count("int spawnSwitch = rmRandInt(0,1);") == 1 and t.index("int spawnSwitch") < t.index("// ---- 12.1 ROLES")
        assert t.index("int defenderBank = rmRandInt(0, 1);") < t.index("// ---- 12.1 ROLES")

    def test_interim_placement_reads_the_coin_the_same_way(self):
        # spawnSwitch 0: team 1 on the far-z line (the north bank), team 0 on the near-z line (the south bank)
        s = _section(_text(LONDON), "// ---- 12.3 INTERIM PLACEMENT", "int playerStart = rmCreateStartingUnitsObjectDef")
        first = s[s.index("if (spawnSwitch ==0){"):s.index("else{")]
        assert re.search(r"rmSetPlacementTeam\(0\);\n\t\t\trmPlacePlayersLine\(0\.10, zPlLine,", first)
        assert re.search(r"rmSetPlacementTeam\(1\);\n\t\t\trmPlacePlayersLine\(0\.90, zPlLineFar,", first)

    def test_one_vs_all_and_the_echo(self):
        s = _section(_text(LONDON), "// ---- 12.1 ROLES", "// ---- 12.2 SEATS BY ROLE")
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
        s = _section(_text(LONDON), "// ---- 12.1 ROLES", "// ---- 12.2 SEATS BY ROLE")
        assert "cNumberTeams" not in s

    def test_no_seat_names_collide_with_other_declarations(self):
        t = _text(LONDON)
        for name in ["northTeam", "southTeam", "defenderTeam", "attackerTeam", "defenderCount", "attackerCount", "oneVsAll",
                     "defenderBank", "locZd12", "locZa12", "locZdStuart", "locZaParliament", "locZdPark", "locZaPark",
                     "locZsMenagerie", "locZnMenagerie"] + \
                [o + r for o in ORDER for r in ("Defender", "Attacker")]:
            assert len(re.findall(r"\b(?:int|float) %s\b" % name, t)) == 1, name


class TestSeats:
    """12.2: BLUE rows 7-8, RED rows 3-4, YELLOW rows 5-6, PURPLE rows 1-2 on the team's own bank, cumulative."""

    def test_seats_by_role_on_the_reserved_columns(self):
        s = _code(_section(_text(LONDON), "// ---- 12.2 SEATS BY ROLE", "// ---- 12.3 INTERIM PLACEMENT"))
        assert 'int blockPlayerLondon = cityBlock("player london", "EU_SPC_Player_London");' in s
        assert "float locX56 = (locX5 + locX6) * 0.5;" in s
        assert re.search(r"float locZdSeat = locZs6;.*\n\tfloat locZaSeat = locZn6;\n\tif \(defenderBank == 1\)\n\t\{\n\t\tlocZdSeat = locZn6;\n\t\tlocZaSeat = locZs6;\n\t\}", s)
        assert "if (cNumberTeams == 2 && defenderCount <= 4 && attackerCount <= 4)\n\t\tseatsByRole = 1;" in s
        seats = re.findall(r"(?:if \((\w+) >= (\d)\) )?rmPlacePlayer\((\w+), (locX\d+), (locZ[da]Seat)\);", s)
        assert seats == [("", "", "firstDefender", "locX78", "locZdSeat"), ("defenderCount", "2", "secondDefender", "locX34", "locZdSeat"),
                         ("defenderCount", "3", "thirdDefender", "locX56", "locZdSeat"), ("defenderCount", "4", "fourthDefender", "locX12", "locZdSeat"),
                         ("", "", "firstAttacker", "locX78", "locZaSeat"), ("attackerCount", "2", "secondAttacker", "locX34", "locZaSeat"),
                         ("attackerCount", "3", "thirdAttacker", "locX56", "locZaSeat"), ("attackerCount", "4", "fourthAttacker", "locX12", "locZaSeat")]

    def test_seated_players_get_the_block_not_the_command_post(self):
        t = _code(_text(LONDON))
        loop = t[t.index("for(i=1; < cNumberNonGaiaPlayers + 1) {"):t.index("int harbourN1PostUnit")]
        assert "if (seatsByRole == 1)\n\t\t{\n\t\t\trmPlaceGroupingAtLoc(blockPlayerLondon, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));\n\t\t}" in loop
        assert loop.count("deSPCCommandPost") == 1 and loop.index("else") < loop.index("deSPCCommandPost")
        assert loop.count("rmPlaceObjectDefAtLoc(playerStart, i") == 1 and loop.count("rmPlaceObjectDefAtLoc(aiStartUrban, i, 0.5, 0.5)") == 1
        before = t[t.index("int aiStartUrban"):t.index("for(i=1; < cNumberNonGaiaPlayers + 1) {")]
        assert "rmSetNuggetDifficulty(195, 195);" in before        # the export's capturable-building nugget: the resource / embassy latch

    def test_interim_line_only_when_nobody_is_seated(self):
        s = _code(_section(_text(LONDON), "// ---- 12.3 INTERIM PLACEMENT", "int playerStart = rmCreateStartingUnitsObjectDef"))
        assert "if (seatsByRole == 0 && cNumberTeams == 2){" in s and "if (seatsByRole == 0 && cNumberTeams != 2){" in s
        assert not re.search(r"\n\tif \(cNumberTeams == 2\)\{", s) and "else{\n\t\trmPlacePlayersLine" not in s


class TestScope:

    def test_reserved_columns_take_the_berry_mill(self):
        t = _code(_text(LONDON))
        assert 'cityBlock("Mill Food4", "EU_Resource_Block_Food4")' in t and "Food3" not in t
        assert (REPO / "game/randmaps/groupings/EU_Resource_Block_Food4.xml").is_file()

    def test_twin_identical_and_crlf(self):
        raw = LONDON.read_bytes()
        assert raw == (STEAM / "00000_zplondon.xs").read_bytes()
        assert raw.count(b"\r\n") == raw.count(b"\n")
