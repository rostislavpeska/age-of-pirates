"""The area flattener policy (owner 2026-10-07).

zpInvisibleGroundFlattener ("ZP Nat Area Flattener", obstructionradiusx/z 20) levels a 40 x 40 m square round its
grouping's origin. That was measured in 14 Danube editor saves: 21 x 21 height vertices at the flattener's own height
(rm-groupings-deploy skill). The owner's policy: "default with flattener. There where flattening might cause critical
issues - King of Bohemia, maybe some other maps? ... use _noflatten variant".

- Hussite_Camp_01-05, Orthodox_Monastery01-06 and Orthodox_South_01-03 carry the flattener as their first unit, at
  0 / 0 (test_danube_layouts.py).
- <name>_noflatten.xml is the same grouping without it: the committed grouping from before the flattener was added.
- Only the copies are used on the maps whose real editor generations (the gt_<map>_P2T2 / P6T2 captures of
  2026-09-25, made before the flattener) put a steep face (>= 1.5 m between neighbouring vertices) inside a
  settlement's square:
  - King of Bohemia: castle plateaus, 3 of 5 castles.
  - Dead Sea: 1 of 2 villages, 5.5 m of terrace.
  - Black Sea: every village on a 2 m cliff plateau, 2 of 4.
- Elbe, Crown Lands, Kurils, Adriatic Sea, The Unknown and the Danube showed gentle slopes or flat ground. They keep
  the flattener.
- A grouping holding a Town Center never carries the flattener. Owner, of the Malta forts: "I still see a problem with
  the explorer spawn - maybe the area flattener for player castles. So remove it". The Danube levels its forts with a
  flat area beneath them.
- The copies are derived, never edited: `python scripts/tools/noflatten_copies.py --write` regenerates them.
- A flattened settlement keeps its 40 m box on the map. Owner: "obstruction can touch the map edge". Its centre can
  never come closer than 22 m to the edge: its point minus how far it may move, or an edge box / world circle.
  Maps mapsim cannot bound are skipped with their real-save evidence, never passed silently.

The owner kept the 40 m flattener over a smaller one ("the settlements are big"), and with it the copies: "keep the
debt and define some standards for flatten / unflatten groupings". The standard is in the rm-groupings-deploy skill.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO))

G = REPO / "game" / "randmaps" / "groupings"
FLAT = "zpInvisibleGroundFlattener"
FAMILIES = re.compile(r"(hussite_camp_0|orthodox_monastery0|orthodox_south_0)", re.I)
NO_FLATTEN_MAPS = {          # map -> the families it places, all as _noflatten copies
    "randmaps/zpkingofbohemia.xs": ["Hussite_Camp_01", "Hussite_Camp_02", "Hussite_Camp_03"],
    "game/randmaps/zpdeadsea.xs": ["Orthodox_South_01", "Orthodox_South_02", "Orthodox_South_03"],
    "randmaps/zpblacksea.xs": [f"Orthodox_Monastery0{k}" for k in range(1, 7)],
}


def _maps():
    return sorted(list((REPO / "randmaps").glob("*.xs")) + list((REPO / "game" / "randmaps").glob("*.xs")))


def _grouping_names(src: str):
    """The grouping-name expression of every rmCreateGrouping that builds one of the flattened families."""
    out = []
    for m in re.finditer(r"rmCreateGrouping\([^;]*?,\s*(\"[^\"]*\"[^;]*?)\)\s*;", src):
        if FAMILIES.search(m.group(1)):
            out.append(m.group(1))
    return out


def test_each_noflatten_copy_is_its_grouping_without_the_flattener_line():
    copies = sorted(G.glob("*_noflatten.xml"))
    assert {p.stem for p in copies} == {f"{n}_noflatten" for ns in NO_FLATTEN_MAPS.values() for n in ns}
    for copy in copies:
        base = G / (copy.stem[:-len("_noflatten")] + ".xml")
        raw = copy.read_bytes()
        assert raw.count(b"\r\n") == raw.count(b"\n"), f"{copy.name}: CRLF on disk (AGENTS.md rule 1)"
        b = base.read_text(encoding="utf-8").replace("\r\n", "\n")
        flat = [ln for ln in b.split("\n") if FLAT in ln]
        assert len(flat) == 1, base.name
        assert raw.decode("utf-8").replace("\r\n", "\n") == b.replace(flat[0] + "\n", "", 1), copy.name


@pytest.mark.parametrize("rel", sorted(NO_FLATTEN_MAPS))
def test_the_maps_with_cliffs_at_their_settlements_ask_only_for_the_copies(rel):
    names = _grouping_names((REPO / rel).read_text(encoding="utf-8", errors="replace"))
    assert names, rel
    assert all(n.rstrip().endswith('"_noflatten"') for n in names), names


@pytest.mark.parametrize("rel", sorted(NO_FLATTEN_MAPS))
def test_every_copy_a_map_can_draw_exists(rel):
    # the scripts build the name from a drawn type: "Hussite_Camp_0"+bohemianCastle1Type+"_noflatten" with
    # bohemianCastle1Type = rmRandInt(1,3); every value of the draw must name a file (mapsim leaves draws unresolved)
    src = (REPO / rel).read_text(encoding="utf-8", errors="replace")
    files = {p.stem.lower() for p in G.glob("*.xml")}
    drawn = set()
    for prefix, var in re.findall(r'"(\w+)"\s*\+\s*(\w+)\s*\+\s*"_noflatten"', src):
        lo, hi = map(int, re.search(r"\b%s\s*=\s*rmRandInt\(\s*(\d+)\s*,\s*(\d+)\s*\)" % var, src).groups())
        drawn |= {f"{prefix}{k}_noflatten" for k in range(lo, hi + 1)}
    assert drawn == {f"{n}_noflatten" for n in NO_FLATTEN_MAPS[rel]}, sorted(drawn)
    assert all(n.lower() in files for n in drawn), sorted(drawn)


def test_every_other_map_keeps_the_flattened_defaults():
    # the copies are the exception the owner named, never a silent default elsewhere
    users = []
    for path in _maps():
        rel = path.relative_to(REPO).as_posix()
        if rel in NO_FLATTEN_MAPS:
            continue
        names = _grouping_names(path.read_text(encoding="utf-8", errors="replace"))
        if names:
            users.append(rel)
            assert not any("_noflatten" in n for n in names), (rel, names)
    assert "game/randmaps/zpdanube.xs" in users and "game/randmaps/zpunknown.xs" in users, users


def test_no_grouping_with_a_town_center_carries_the_flattener():
    bad = [p.name for p in sorted(G.glob("*.xml"))
           if ">TownCenter<" in (t := p.read_text(encoding="utf-8", errors="replace")) and FLAT in t]
    assert bad == []


def test_the_copies_are_what_the_tool_derives():
    # the copies are derived, never edited: scripts/tools/noflatten_copies.py --write regenerates them from the bases
    from scripts.tools.noflatten_copies import problems
    assert problems() == []


EDGE_M = 22.0      # the flattener's 20 m half-width + one 2 m vertex (the square can sit a vertex off its centre)
FLATTENED = re.compile(r"(hussite_camp_0|orthodox_monastery0|orthodox_south_0|jesuit_cathedral_eu_flat_0)", re.I)
EDGE_NOT_MODELLED = {   # mapsim cannot bound these; the real editor saves (gt_<map>_P2T2 / P6T2, 2026-09-25) can
    "game/randmaps/zpBalearicIslands.xs": "the Jesuit cathedrals may move 90 m round the start, held only by the island "
                                          "(8-20 m off the water); real saves: 88 m and more from the edge",
    "game/randmaps/zpunknown.xs": "mapsim does not reach The Unknown's settlements (random terrain branches); real "
                                  "save P6: 38 m from the edge",
}


def _flattened_maps():
    out = []
    for path in _maps():
        names = [n for n in _grouping_names(path.read_text(encoding="utf-8", errors="replace"))
                 if "_noflatten" not in n] + re.findall(r'"Jesuit_Cathedral_EU_Flat_0"', path.read_text(
                     encoding="utf-8", errors="replace"))
        if names:
            out.append(path.relative_to(REPO).as_posix())
    return out


def _num(v):
    try:
        return float(v)
    except (TypeError, ValueError):
        return None


@pytest.mark.parametrize("rel", _flattened_maps())
def test_a_flattened_settlement_keeps_its_box_on_the_map(rel):
    # owner 2026-10-07: "obstruction can touch the map edge". The closest a settlement's centre can come to the edge:
    # its requested point minus how far it may move (rmSetGroupingMaxDistance), or the margin of an edge box / world
    # circle among its constraints, whichever is larger - at every lobby size
    if rel in EDGE_NOT_MODELLED:
        pytest.skip(EDGE_NOT_MODELLED[rel])
    from scripts.mapsim.scene import Scenario
    from scripts.mapsim.xs_extract import extract
    seen = 0
    for players, teams in [(p, 2) for p in range(2, 9)] + [(p, p) for p in range(3, 9)]:
        ex = extract(REPO / rel, Scenario(players=players, teams=teams))
        W = ex.map_size_x
        H = getattr(ex, "map_size_z", None) or W
        for p in ex.placements:
            d = ex.defs.get(p.def_handle)
            if d is None or not d.is_grouping or not FLATTENED.search(str(d.proto)) or "_noflatten" in str(d.proto):
                continue
            x, z = _num(p.x), _num(p.z)
            assert x is not None and z is not None, (players, teams, d.name, p.x, p.z)
            x, z = x * W, z * H
            guaranteed = min(x, z, W - x, H - z) - (_num(d.max_dist) or 0.0)
            for cname in d.constraints:
                c = ex.constraints.get(cname) or {}
                if c.get("kind") == "box" and None not in (b := [_num(v) for v in c["box"]]):
                    guaranteed = max(guaranteed, min(b[0] * W, b[1] * H, (1 - b[2]) * W, (1 - b[3]) * H))
                if c.get("kind") == "pie" and [_num(v) for v in c["center"]] == [0.5, 0.5] and _num(c["r_min_m"]) == 0 \
                        and _num(c["r_max_m"]) is not None:
                    guaranteed = max(guaranteed, min(W, H) / 2 - _num(c["r_max_m"]))
            seen += 1
            assert guaranteed >= EDGE_M, (players, teams, d.name, round(guaranteed, 1))
    assert seen, rel
