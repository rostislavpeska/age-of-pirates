"""London's player-role harness (user 2026-09-21): the Florence system - firstDefender .. seventhAttacker - keyed
on the bank coin, with no seat coordinates yet. Pins the contract so the seat tables can be written on top of it:

  - the helper is Florence's zpGetTeamPlayer, verbatim, at file scope (also Versailles');
  - the 14 roles follow the helper's order, defenders = the NORTH bank's team, attackers = the SOUTH bank's;
  - the bank coin is the existing spawnSwitch, and the interim Paris line placement reads it the same way
    (spawnSwitch 0: team 1 far z = north, team 0 near z = south), so roles and seats agree;
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


def _helper(t: str) -> str:
    return t[t.index("// Get player order within a team"):t.index("// Place grouping at the first free slot")].rstrip(chr(10))


def _section(t: str, start: str, end: str) -> str:
    return t[t.index(start):t.index(end)]


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
        body = chr(10).join(l for l in h.split(chr(10)) if not l.strip().startswith("//"))
        assert body.count("g_zpTeamPlayerResult = i;") == 1 and body.count("return;") == 2 and "return " not in body


class TestRoles:
    def test_fourteen_roles_in_florence_order(self):
        s = _section(_text(LONDON), "// ---- 12.1 ROLES", "// ---- 12.2 SEATS BY ROLE")
        calls = re.findall(r"zpGetTeamPlayer\((\d), (northTeam|southTeam)\);\n\tint (\w+) = g_zpTeamPlayerResult;", s)
        assert [(int(k), team, name) for k, team, name in calls] == \
            [(i + 1, "northTeam", o + "Defender") for i, o in enumerate(ORDER)] + \
            [(i + 1, "southTeam", o + "Attacker") for i, o in enumerate(ORDER)]
        assert s.count("g_zpTeamPlayerResult") == 14

    def test_defenders_are_the_north_bank_by_the_existing_coin(self):
        t = _text(LONDON)
        s = _section(t, "// ---- 12.1 ROLES", "// ---- 12.2 SEATS BY ROLE")
        assert re.search(r"int northTeam = 1;\n\tint southTeam = 0;\n\tif \(spawnSwitch == 1\)\n\t\{\n\t\tnorthTeam = 0;\n\t\tsouthTeam = 1;\n\t\}", s)
        assert "int northCount = rmGetNumberPlayersOnTeam(northTeam);" in s and "int southCount = rmGetNumberPlayersOnTeam(southTeam);" in s
        assert t.count("int spawnSwitch = rmRandInt(0,1);") == 1 and t.index("int spawnSwitch") < t.index("// ---- 12.1 ROLES")

    def test_interim_placement_reads_the_coin_the_same_way(self):
        # spawnSwitch 0: team 1 on the far-z line (the north bank), team 0 on the near-z line (the south bank)
        s = _section(_text(LONDON), "// ---- 12.3 INTERIM PLACEMENT", "int playerStart = rmCreateStartingUnitsObjectDef")
        first = s[s.index("if (spawnSwitch ==0){"):s.index("else{")]
        assert re.search(r"rmSetPlacementTeam\(0\);\n\t\t\trmPlacePlayersLine\(0\.10, zPlLine,", first)
        assert re.search(r"rmSetPlacementTeam\(1\);\n\t\t\trmPlacePlayersLine\(0\.90, zPlLineFar,", first)

    def test_one_vs_all_and_the_echo(self):
        s = _section(_text(LONDON), "// ---- 12.1 ROLES", "// ---- 12.2 SEATS BY ROLE")
        assert "int oneVsAll = 0;\n\tif (northCount >= 7 || southCount >= 7)\n\t\toneVsAll = 1;" in s
        assert s.count('rmEchoInfo("LONDON roles:') == 2 and "seventhAttacker + \" oneVsAll \" + oneVsAll" in s

    def test_roles_resolve_before_any_player_is_placed_and_inside_main(self):
        t = _text(LONDON)
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
        for name in ["northTeam", "southTeam", "northCount", "southCount", "oneVsAll"] + \
                [o + r for o in ORDER for r in ("Defender", "Attacker")]:
            assert len(re.findall(r"\bint %s\b" % name, t)) == 1, name


class TestScope:
    def test_harness_only_no_seat_by_role_yet(self):
        t = _text(LONDON)
        code = chr(10).join(l for l in t.split(chr(10)) if not l.strip().startswith("//"))
        assert not re.search(r"rmPlacePlayer\((\w+)(Defender|Attacker)", code)
        assert "// ---- 12.2 SEATS BY ROLE: none yet" in t

    def test_twin_identical_and_crlf(self):
        raw = LONDON.read_bytes()
        assert raw == (STEAM / "00000_zplondon.xs").read_bytes()
        assert raw.count(b"\r\n") == raw.count(b"\n")
