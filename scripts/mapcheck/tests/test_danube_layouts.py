"""Every lobby layout of the Danube (owner 2026-10-07: "Consider also very asymmetric spawns like 1v7 - also these
should be proper - test all"): 2-8 players, every 2-team split in both orders, FFA, 3 and 4 teams.

Two teams of any split stand on their own sections of the half-moon with a gap between them and the Jesuit cathedral
at its centre ("gap between two teams is necessary"); FFA and 3-4 teams keep the even
half-moon; there the Hussite / Orthodox pair closest to the map centre are cathedrals instead.
Distances from mapsim's starts and the native anchors the script asks for (each village may still move 25 m).
"""
from __future__ import annotations

import math
import sys
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO))

from scripts.mapcheck.universal import _placement_findings  # noqa: E402
from scripts.mapsim.scene import Scenario, team_of  # noqa: E402
from scripts.mapsim.xs_extract import extract, ring_positions  # noqa: E402

DANUBE = REPO / "game" / "randmaps" / "zpdanube.xs"


def _layouts():
    for p in range(2, 9):
        for a in range(1, p):
            yield pytest.param(Scenario(players=p, teams=2, team_sizes=(a, p - a)), id=f"P{p}-{a}v{p - a}")
        if p >= 3:
            yield pytest.param(Scenario(players=p, teams=p), id=f"P{p}-FFA")
        if p >= 6:
            yield pytest.param(Scenario(players=p, teams=3), id=f"P{p}-3teams")
        if p == 8:
            yield pytest.param(Scenario(players=p, teams=4), id=f"P{p}-4teams")


@pytest.mark.parametrize("players", [2, 8])
def test_each_harbour_stands_on_a_port_site_joined_to_the_bank_close_to_the_route(players):
    # owner 2026-10-08: "on a tiny island beneath and closer to the trade route ... bigger islands connected with
    # mainland ... it's a known pattern from other maps" (the port site of Australia, New Guinea, Mississippi, ...);
    # v12 left the sockets 30 m off the route
    from scripts.mapsim.bridge import extraction_to_resolved
    from scripts.mapsim.field import terrain_grid
    ex = extract(DANUBE, Scenario(players=players, teams=2))
    size = ex.map_size_x
    tg = terrain_grid(extraction_to_resolved(ex), cell_tiles=1.0)
    step = size / tg.nx

    def water(x, z):
        i, j = int(x / step), int(z / step)
        return 0 <= i < tg.nx and 0 <= j < tg.nz and bool(tg.water[j][i])

    rivers = [[(x * size, z * size) for x, z in w] for h, w in ex.route_waypoints.items()
              if ex.route_types.get(h) == "river_trail"]

    def nearest(p):
        best = (1e9, None)
        for r in rivers:
            for a, b in zip(r[:-1], r[1:]):
                dx, dz = b[0] - a[0], b[1] - a[1]
                u = max(0.0, min(1.0, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dz) / (dx * dx + dz * dz or 1e-9)))
                q = (a[0] + u * dx, a[1] + u * dz)
                d = math.hypot(p[0] - q[0], p[1] - q[1])
                if d < best[0]:
                    best = (d, q)
        return best

    sockets = [(p.x * size, p.z * size) for p in ex.placements
               if ex.defs.get(p.def_handle) is not None and ex.defs[p.def_handle].name.startswith("harbour ")]
    assert len(sockets) == 5
    for s in sockets:
        d, q = nearest(s)
        assert 16.0 <= d <= 20.0, round(d, 1)      # 18 m: one tile back (owner 2026-10-07), 16 m before
        n = ((s[0] - q[0]) / d, (s[1] - q[1]) / d)                    # from the route towards the bank
        assert not water(*s), "the socket must stand on the port site"
        assert any(water(s[0] - n[0] * k, s[1] - n[1] * k) for k in range(2, 9)), "water in front, towards the route"
        assert all(not water(s[0] + n[0] * k, s[1] + n[1] * k) for k in range(0, 35, 2)), "joined to the bank"


def test_the_harbour_groupings_are_the_owners_socket_and_three_platforms_without_terrain():
    # owner 2026-10-07: "use unit distances and harbour platform variants from the new file (Harbour center - platform
    # unit) meanwhile keeping the original unpainted terrain ... why don't we simply have one grouping together with the
    # socket - standard sockets work in groupings, only capturable ones don't"; then "move [the platforms] 1 m from the
    # socket while keeping the socket in place": his distances 9.43 / 11.53 / 12.11 m, each 1 m further out
    import re
    for side in ("NE", "NW", "SE", "SW"):     # the harbour groupings' convention: the water side in screen terms
        t = (REPO / "game" / "randmaps" / "groupings" / f"Harbour_River_{side}.xml").read_text(encoding="utf-8")
        units = re.findall(r'variation="(\d+)" posx="([-\d.]+)" posz="([-\d.]+)"[^>]*>([^<]+)</unit>', t)
        assert [u[3] for u in units] == ["SocketTradeRoute"] + ["zpHarbourPlatform"] * 3, units
        assert sorted(u[0] for u in units) == ["130", "130", "247", "247"], units
        assert math.hypot(float(units[0][1]), float(units[0][2])) < 0.01          # the socket is the origin
        reach = sorted(math.hypot(float(x), float(z)) for _, x, z, _ in units[1:])
        assert all(abs(r - want) < 0.01 for r, want in zip(reach, (10.4256, 12.5274, 13.1126))), (side, reach)
        assert "<tiles></tiles>" in t and "tilegroup" not in t


def test_hussite_and_orthodox_groupings_carry_the_area_flattener_at_their_centre_and_the_forts_do_not():
    # owner 2026-10-07: "ZP Area Flattener ... Jesuits use it, Orthodox and Hussites don't. I'd give it them too - right
    # in the very centre of the grouping"; for the forts, after the v14 editor check: "I still see a problem with the
    # explorer spawn - maybe the area flattener for player castles. So remove it. Do the flattening for player castles
    # manually through a flat area beneath them" (the fort site, next test)
    names = ([f"Hussite_Camp_0{k}" for k in range(1, 6)] + [f"Orthodox_Monastery0{k}" for k in range(1, 7)]
             + [f"Orthodox_South_0{k}" for k in range(1, 4)])
    for n in names:
        t = (REPO / "game" / "randmaps" / "groupings" / f"{n}.xml").read_text(encoding="utf-8")
        first = t[t.index("<units>"):].split("</unit>")[0]
        assert 'posx="0" posz="0"' in first and first.rstrip().endswith("zpInvisibleGroundFlattener"), n
    for n in ("malta_player_fort", "malta_player_fort2", "danube_player_fort"):
        assert "zpInvisibleGroundFlattener" not in (REPO / "game" / "randmaps" / "groupings" / f"{n}.xml").read_text(
            encoding="utf-8"), n


def test_every_fort_stands_on_a_flat_site_built_before_it():
    # the fort's flat ground is an area, not a unit: the elector plateau's size, smoothing and zero variation without
    # its cliff, at the land height, off the water, built right before the fort grouping on the same marker
    import re
    src = DANUBE.read_text(encoding="utf-8").replace("\r\n", "\n")
    block = src[src.index('int fortSiteID = rmCreateArea("fort site "+i);'):
                src.index('rmPlaceGroupingAtLoc(playerFortID, i,')]
    for line in ("rmSetAreaSize(fortSiteID, rmAreaTilesToFraction(650.0), rmAreaTilesToFraction(650.0));",
                 "rmSetAreaBaseHeight(fortSiteID, landHeight);", "rmSetAreaSmoothDistance(fortSiteID, 5);",
                 "rmSetAreaElevationVariation(fortSiteID, 0.0);", "rmAddAreaConstraint(fortSiteID, avoidWater10);",
                 "rmBuildArea(fortSiteID);", 'rmCreateGrouping("player fort "+i, "danube_player_fort");'):
        assert line in block, line
    assert "rmSetAreaCliffType" not in block
    assert re.search(r'int avoidWater10 = rmCreateTerrainDistanceConstraint\("avoid water short", "Land", false, 2\.0\);',
                     src)


def test_every_fort_fits_inside_the_world_circle():
    # owner 2026-10-07, a 1v1 game: one start had no fort at all. The marker's edge box fences only the square's sides;
    # a start in a world diagonal stands near the circle, which drops what lies beyond ~0.455 of the map
    # (rm-coordinates), and a grouping that does not fit places nothing. The marker's circle leaves room for the
    # fort's farthest unit, and still lets the marker stand within its 20 m of the start ring on the smallest map
    import re
    src = DANUBE.read_text(encoding="utf-8").replace("\r\n", "\n")
    assert "rmSetWorldCircleConstraint(true);" in src
    circles = []
    for name in re.findall(r"rmAddObjectDefConstraint\(TCID, (\w+)\);", src):
        m = re.search(r"int %s\s*=\s*rmCreatePieConstraint\(\"[^\"]*\", 0\.5, 0\.5, 0\.0, rmXFractionToMeters\(([\d.]+)\)"
                      r"-([\d.]+), rmDegreesToRadians\(0\), rmDegreesToRadians\(360\)\);" % name, src)
        if m:
            circles.append((float(m.group(1)) * 512.0 - float(m.group(2)), name))
    assert circles, "the fort marker has no world-circle constraint"
    allowed, name = min(circles)
    fort = (REPO / "game" / "randmaps" / "groupings" / "danube_player_fort.xml").read_text(encoding="utf-8")
    reach = max(math.hypot(float(x), float(z)) for x, z in re.findall(r'posx="([-\d.]+)" posz="([-\d.]+)"', fort))
    assert allowed + reach + 2.0 <= 0.455 * 512.0, (name, allowed, reach)
    ring = float(re.search(r"rmPlacePlayersCircular\(([\d.]+), ", src).group(1)) * 512.0
    assert allowed >= ring - 10.0, (allowed, ring)


def test_the_danube_fort_is_maltas_fort_with_new_england_and_great_lakes_trees():
    # owner 2026-10-07: "a mix of New England and Great Lakes oaks ... same for player starting trees". Malta keeps its
    # own trees, so the Danube has a copy that differs from malta_player_fort in its six tree protos only
    g = REPO / "game" / "randmaps" / "groupings"
    malta = (g / "malta_player_fort.xml").read_bytes().split(b"\r\n")
    danube = (g / "danube_player_fort.xml").read_bytes().split(b"\r\n")
    assert len(malta) == len(danube)
    trees = []
    for a, b in zip(malta, danube):
        if a != b:
            assert a.endswith((b">TreeTexas</unit>", b">ypTreeEucalyptus</unit>")), a
            assert a.rsplit(b">", 2)[0] == b.rsplit(b">", 2)[0], (a, b)       # position, angle and variation kept
            trees.append(b.rsplit(b">", 2)[1].split(b"<")[0])
    assert sorted(trees) == [b"TreeGreatLakes"] * 3 + [b"TreeNewEngland"] * 3, trees


def test_the_land_is_level_with_the_bridges_and_the_docks_keep_the_base_mix():
    # owner 2026-10-07: docks below the bridge "look creepy"; then the docks at the bridge's height stood above the land
    # ("shift all terrain height a bit up"); and the cliff's own ground on the dock top: "paint the area with the base
    # mix, only the area on top of the cliff". Bridge_Universal_03's block: 3.07..3.25 m in the v12 editor saves
    src = DANUBE.read_text(encoding="utf-8").replace("\r\n", "\n")
    assert "float landHeight = 3.2;" in src
    dock = src[src.index('int bridgeDockID = rmCreateArea("bridge dock "+b);'):src.index("rmBuildArea(bridgeDockID);")]
    for line in ("rmSetAreaBaseHeight(bridgeDockID, landHeight);", 'rmSetAreaMix(bridgeDockID, "italy_grass_lush");',
                 "rmSetAreaCliffPainting(bridgeDockID, false, true, true, 1.5, true);"):
        assert line in dock, line
    assert 'rmSetBaseTerrainMix("italy_grass_lush");' in src
    assert "rmSetAreaBaseHeight(electorPlateauID, landHeight+2.0);" in src


@pytest.mark.parametrize("sc", list(_layouts()))
def test_the_layout_keeps_its_spawn_rules(sc):
    ex = extract(DANUBE, sc)
    size = ex.map_size_x
    starts = [(x * size, z * size) for x, z in ring_positions(ex.player_events, sc.players, sc.teams, sc.team_sizes)]
    teams = [team_of(k + 1, sc.players, sc.teams, sc.team_sizes) for k in range(sc.players)]
    natives = {"hussite camp": [], "orthodox monastery": [], "jesuit cathedral": []}
    for p in ex.placements:
        d = ex.defs.get(p.def_handle)
        if d is not None and d.is_grouping:
            for prefix in natives:
                if d.name.startswith(prefix):
                    natives[prefix].append((p.x * size, p.z * size))

    def gap(a, b):
        return math.hypot(a[0] - b[0], a[1] - b[1])

    # every player placed, on the players' ring (radius 0.41): a placement section of no length places nobody (v12
    # editor saves 1v1 and 2v1: no Town Center for the lone players; mapsim puts such a player at the map centre)
    assert _placement_findings(ex, "zpdanube") == []
    centre = size / 2.0
    assert all(abs(gap(s, (centre, centre)) - 0.41 * size) < 2.0 for s in starts), [
        round(gap(s, (centre, centre)) / size, 3) for s in starts]
    every = [q for rows in natives.values() for q in rows]
    assert min(gap(q, s) for q in every for s in starts) >= 75.0          # natives off every start
    assert min((gap(h, o) for h in natives["hussite camp"] for o in natives["orthodox monastery"]),
               default=999.0) >= 150.0
    # two teams: every Hussite and Orthodox settlement plus one cathedral in the gap; FFA (and 3-4 teams, the same
    # half-moon): the Hussite / Orthodox pair closest to the map centre are cathedrals ("1 Hussite, 2 Jesuit and 1
    # Orthodox - FFA only", 3-4 players). Per side: 1 settlement at 2 players, 2 at 3-4, 3 at 5+
    per_side = 1 if sc.players == 2 else 2 if sc.players <= 4 else 3
    counts = {k: len(v) for k, v in natives.items()}
    if sc.teams == 2:
        assert counts == {"hussite camp": per_side, "orthodox monastery": per_side, "jesuit cathedral": 1}
    else:
        assert counts == {"hussite camp": per_side - 1, "orthodox monastery": per_side - 1, "jesuit cathedral": 2}
        centre = size / 2.0
        far = max(gap(j, (centre, centre)) for j in natives["jesuit cathedral"])
        assert all(far <= gap(q, (centre, centre)) + 0.5 for q in natives["hussite camp"] + natives["orthodox monastery"])
    if sc.teams == 2:
        enemy = min(gap(starts[a], starts[b]) for a in range(sc.players) for b in range(sc.players)
                    if teams[a] != teams[b])
        assert enemy >= 250.0, round(enemy)                                 # the gap between the teams
        j = natives["jesuit cathedral"][0]
        assert min(gap(j, s) for s in starts) >= 100.0
