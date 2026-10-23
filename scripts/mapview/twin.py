"""The twin: what the map script should spawn (mapsim) joined with what spawned (the census of a saved generation).

    python scripts/mapview/twin.py randmaps/zplondon.xs --players 4 --teams 2 [--census <save.age3Yscn>]
                                   [--team-layout 1,2/3,4] [--out <dir>] [--tol-m 4] [--member-tol-m 1]
                                   [--groupings-rev <git rev>] [--screens ingame,editor] [--no-png] [--all] [--force]

The census must be a Scenario Editor save (.age3Yscn) of a generation: an in-match .age3Ysav decodes nothing
(census_reader) and is refused.

MAP SIZE: with a census the whole expected side is extracted at the save's own map size (census_reader.map_size: the
terrain header, whole tiles), not the script's rmSetMapSize: the engine rounds up to whole tiles and converts every
fraction with that size (measured 2026-09-24 on mapview_london4p_live: 360 x 686 m for the asked 360 x 685; the
grouping anchors' z residual is at most 1.50 m at 685 and at most 1.00 m - the even-metre snap - at 686). A save size
more than SIZE_WARN_M away from the script's is warned (a wrong --players / --teams or map); a save without a
single terrain header falls back to the script's size with a warning. report['size'] records both.

TEAM LAYOUT: mapsim answers rmGetPlayerTeam with its one team model (scene.team_of: contiguous blocks, 1,2/3,4 at 4
players / 2 teams; it alternated until 2026-09-25). The lobby can differ: on
mapview_london4p_live players 1 and 2 share the north bank (lobby teams {1,2} / {3,4}). --team-layout 1,2/3,4 (team
0 = the lobby's first team, then team 1, ...) makes the extractions answer rmGetPlayerTeam / rmGetNumberPlayersOnTeam
from the lobby; without it owner mismatches that a different layout explains are reported with the layout the census
owners fit (a hint, never applied silently).

EXPECTED (expected_scene): mapsim's nominal scene for that player setup after gsolve.ensure_solved (a solver error
is recorded in twin.json, never swallowed).
  - Object defs: one expected object per unit, count x item count x players (ResolvedPlacement.item_counts and
    .players, mapsim 2026-09-24: a per-player loop collapsed onto one spot keeps every player - zplondon.xs
    'london bridge marker' = 4 zpAILondonBridge at 4 players, one per player). A def is judged within tol_m +
    its search radius (max_dist_m): the engine may put the unit anywhere inside the radius and snaps it by up to
    ~3 m even without one (wf verify M4, LondonIndivUnitIDs: the harbour posts 3.04 m, the guard nuggets with a 3 m
    radius 5.72 m). A def whose radius exceeds MAX_DEF_SEARCH_M, and rmCreateStartingUnitsObjectDef ('startingUnits',
    the civ's own set), are 'unjudged' with the reason, never MISSING; the report counts what the census holds
    inside such a search radius.
  - Every spot judged is the AUTHORED one (before gsolve moved anything): the engine searches around the spot the
    script asked for; the solver's pick inside the radius is one guess (wf verify L6).
  - Groupings: one expected object per MEMBER at anchor + (posx, posz). Measured 2026-09-24 on
    <profile>/Scenario/LondonIndivUnitIDs.age3Yscn (wf_twin_review F3): posx/posz are metres in world axes relative
    to the placed anchor, NOT rotated by rmPlaceGroupingAtLoc / rmPlaceGroupingInstanceAtLoc; against the exports of
    that generation (git cc050ea4) the bridge 110/110, Tower_01 and Tower_02 244/245, each harbour 20/20 and the
    player block 257/258 members sit at anchor + offset to 0.01 m. Members come from scripts/refdata (catalog
    ('grouping').resolve + grouping_units_m: the mod folder, then the game install; every prefix variant is voted and
    the best wins) or, with groupings_rev, from the grouping exports of that git revision - a save older than an
    export is judged against the export it was generated with (a later export moves members: the same London save
    votes Tower 188/247 and the player block 300/385 against the 2026-09-24 exports).
  - Placements without an authored position (runtime anchors; in_area placements even where gsolve guessed a spot
    inside the area - the engine picks its own, wf verify M3), a def handle mapsim could not follow (its 'nothing
    placed' warnings), groupings named by a runtime string (an empty reference) and groupings without a readable file
    go to 'unmodelled' (line, name, reason); their protos are excluded from 'extra'.
  - COIN WORLDS: the extraction runs twice more with every literal rmRandInt / rmRandFloat rolled to its low bound
    (world L) and to its high bound (world H). A placement whose spot (or owner) differs between the worlds is
    'either-arm': judged at whichever candidate spot the save supports, never MISSING without that note. mapsim's
    own nominal scene can mix both arms (xs_extract runs both arms of a tainted if, last write wins; twin review F5).
    London 2026-09-24: the defenderBank coin moves St Paul, Minster, both Stuart and both Parliament blocks, both
    Parks and one Menagerie (nominal = world H for those spots; the walls' owners are world L).

ACTUAL (actual_objects) = census_reader.read(save): census_id, proto, world position, owner ('player', the u16 at
the record header - 20, adopted 2026-09-24; 0 = gaia), skewed (a slightly tilted header, census_reader M1).

PROTO NAMES are compared case-insensitively everywhere (the engine resolves XS item and grouping names so;
2026-09-24: 14 randmaps use a spelling that differs from the proto's, London none).

JOIN (join):
  1. Each grouping instance is voted. Hypothesis anchors = unit - member offset, from its rarest members' units
     within allow_m + member_tol_m of the asked spot; the hypothesis with the most members that have a same-proto
     unit within member_tol_m of anchor + offset wins. SNAP (measured 2026-09-24, LondonIndivUnitIDs): the engine
     puts a grouping anchor on even metres, 0.5-2.68 m from mapsim's asked anchor over 60 well-voted London
     groupings (the review's subset: 1.1-2.34 m); SNAP_M = 3 m is that budget and it is carried by tol_m (default
     4 m; a tol_m below SNAP_M is warned). allow_m = tol_m, or max(tol_m, max_dist_m + SNAP_M) with a search
     radius. The variant: among variants whose vote reaches VOTE_OK the one with the most votes (a small prefix
     variant that is a subset of the real file never wins, wf verify L4), else the best fraction.
  2. One global greedy nearest-first claim, one census unit per expected object: members within member_tol_m of
     hypothesis + offset (members of a MISSING grouping claim nothing), object defs within tol_m + max_dist_m of any
     candidate spot, a unit of the expected owner first. match_dist_m is measured from the ASKED spot (anchor +
     offset for members); dist_measured_m from the measured anchor + offset. measured anchor = the median of
     (unit - offset) over the claimed members.
     Verdict: matched (claimed >= VOTE_OK of the members and offset <= allow_m), partial (>= VOTE_MIN), moved
     (offset > allow_m), missing (below VOTE_MIN, nothing claimed).
  3. An unclaimed census unit is 'extra' only when its proto is an item of a judged object def or a member of a
     judged grouping, no unmodelled / unjudged placement could have produced it, AND it lies inside an expected
     footprint of that proto (a grouping's member box around its judged spot + allow_m + member_tol_m, or tol_m
     around an object def's spot); everything else is 'unjudged' with the reason. The footprint rule keeps forest
     AREAS out (rmSetAreaForestType trees are no placement): London 2026-09-24, 80 TreeNewEngland / TreeGreatLakes
     50+ m from every grouping read 'extra' without it. Object-def items match by kind (ITEM_KINDS, unittypes).
  4. OWNERS (check_owners, a verdict column, never a MISSING): an object def that carries a player (1..8) is 'ok'
     when its unit's owner is that player, 'gaia' when the unit is gaia, 'mismatch' otherwise. A grouping placed for
     players is judged on the owners of its claimed members: the engine gives the player only some protos (on
     LondonIndivUnitIDs 79 of 4 x 258 player-block members: TownCenter, Barracks, Church, Market, Stable, deTavern,
     LivestockPen, SPCFlag, zpAIStartUrbanMap, the mines, the walls' gates and towers), so gaia members are never a
     mismatch: 'ok' when every owned member belongs to the expected players, 'mismatch' when one does not, 'gaia'
     when no member is owned. An either-arm placement whose owner flips with the coin is judged against the detected
     coin world's owners. Placements of gaia (player 0) or a runtime player are not judged.
  join() resets every result first: it is idempotent; census_id (actual) and match_id (the cross-reference) are
  separate fields.

KEY OBJECTS: grouping members that are a TownCenter, the Keep (zpSPCTowerOfLondon) or a socket (the proto contains
'Socket': the bridge's zpSPCPortSocket and its tower / gate sockets), reported one by one with their distances and
owners.

SAVE CHECKS (twin review F7, wf verify M2): refused (TwinInputError; the CLI exits 2) when the census decodes no
record (an .age3Ysav, a foreign file - --force cannot override this), when more than UNDECODED_REFUSE_FRAC of its
records are undecoded, when it holds no TownCenter while players >= 1, when the TownCenter count differs from players,
or when more than OUTSIDE_REFUSE_FRAC of the units lie far outside the map. --force judges the last four anyway.
Undecoded records (read nothing, so their placements can read MISSING) and skewed ones are always warned.

OUTPUT: <out>/twin.png (minimap orientation, needs matplotlib), then <out>/twin.json (one object per line). <out>
defaults to a fresh temporary folder, never the repository (scripts/mapview/out/ is gitignored for an explicit
--out there). Minimap pixels come only from calibrations that are accepted AND checked (what
transform.load_calibration(require_checked=True) serves; wf verify L7); every other record is listed in
calibrations_skipped with the reason.
"""
from __future__ import annotations

import argparse
import json
import math
import re
import statistics
import subprocess
import sys
import tempfile
import time
import xml.etree.ElementTree as ET
from collections import Counter, defaultdict
from dataclasses import dataclass, asdict, field
from pathlib import Path
from typing import Any, Dict, List, Optional, Sequence, Set, Tuple

REPO = Path(__file__).resolve().parents[2]
if str(REPO) not in sys.path:
    sys.path.insert(0, str(REPO))
from scripts.mapview.transform import (Calibration, aspect_of, frac_to_minimap, frac_to_uv,  # noqa: E402
                                        list_calibrations, disc_radius_display)

GROUPINGS = REPO / "game" / "randmaps" / "groupings"
GROUPINGS_REL = "game/randmaps/groupings"

TOL_M = 4.0                  # object defs: unit within this of the asked spot; groupings: anchor offset allowed
MEMBER_TOL_M = 1.0           # a member: unit within this of the hypothesis anchor + offset (exact to 0.01 m, F3)
ROUTE_NEAR_M = 15.0          # an object placed within this of an EARLIER route-docked placement follows its real spot
ROUTE_DRIFT_M = 4.0          # ... so its allowance grows by this (fix-round verify V1, 2026-09-24: London's harbour
                             # groupings and guards are built from the route-docked posts' rmGetUnitPosition, which mapsim
                             # evaluates as the ASKED spot; between two generations they moved 1.4-1.9 m and a guard
                             # reached 6.95 m against 7.0)
SNAP_M = 3.0                 # grouping anchor snap budget (measured 0.5-2.68 m on London, 2026-09-24)
VOTE_OK = 0.8                # claimed members / members for 'matched'
VOTE_MIN = 0.25              # below: 'missing' (a few shared props of an overlapping block are no evidence)
MAX_GROUPING_SEARCH_M = 60.0     # a grouping with a larger search radius is unjudged
MAX_DEF_SEARCH_M = 30.0      # an object def with a larger search radius is unjudged (judged within tol_m + radius)
HYP_MEMBERS = 12             # hypotheses come from this many of the rarest members
HYP_CAP = 200                # at most this many hypothesis anchors per (variant, spot)
MAX_VARIANTS = 8
OUTSIDE_MARGIN_M = 10.0      # save check: a unit this far beyond the map edge counts as outside
OUTSIDE_REFUSE_FRAC = 0.005  # ... and more than this share of the census refuses
UNDECODED_REFUSE_FRAC = 0.005    # save check: more than this share of undecoded census records refuses
SIZE_WARN_M = 2.0            # the save's map size vs the script's rmSetMapSize: a larger gap is warned
KEY_PROTOS = {"TownCenter": "town centre", "zpSPCTowerOfLondon": "Keep"}
_KEY_LOW = {k.lower(): v for k, v in KEY_PROTOS.items()}
# An object-def item that names a generic kind: the engine places a concrete proto of it. Measured 2026-09-24 on
# LondonIndivUnitIDs: 'harbour guard north 1' (rmAddObjectDefItem 'Nugget', max 3 m) is ypNuggetTradingPost 3.44 m
# from the asked spot (the nugget table picks the unit; rmSetNuggetDifficulty). Items also match every census proto
# whose <unittype>s include the item (scripts/refdata proto_counts_as).
ITEM_KINDS = {"nugget": "AbstractNugget"}
# rmCreateStartingUnitsObjectDef places the civ's own set (unjudged). An unclaimed unit of these kinds within
# STARTING_UNITS_RADIUS_M of a 'startingUnits' spot is left unjudged: measured 2026-09-24 on LondonIndivUnitIDs, the
# four starting Explorers (unittype Hero) stand 13.9-17.4 m from their seat anchors (max distance 12 m).
STARTING_KINDS = ("Hero", "AbstractVillager", "AbstractWagon", "AbstractResourceCrate")
STARTING_UNITS_RADIUS_M = 24.0
NEAREST_DIAG_M = 50.0        # a MISSING object def names its nearest same-kind census unit within this
_NOTHING_PLACED = re.compile(r"line (\d+): (\w+) on (.*); nothing placed")


class TwinInputError(ValueError):
    """The save does not fit the requested setup (save_checks). forceable=False: --force cannot override it."""

    def __init__(self, msg: str, forceable: bool = True):
        super().__init__(msg)
        self.forceable = forceable


def key_label(proto: str) -> str:
    low = proto.lower()
    if low in _KEY_LOW:
        return _KEY_LOW[low]
    return "socket" if "socket" in low else ""


def parse_team_layout(text: Optional[str], players: int, teams: int) -> Optional[Dict[int, int]]:
    """'1,2/3,4' -> {1: 0, 2: 0, 3: 1, 4: 1}: the lobby's teams in order (team 0 first). Every player 1..players
    exactly once in exactly `teams` groups; ValueError otherwise. None / '' -> None (mapsim's model, scene.team_of)."""
    if not text:
        return None
    groups = [g for g in str(text).replace(" ", "").split("/")]
    out: Dict[int, int] = {}
    for t, g in enumerate(groups):
        for s in g.split(","):
            if not s:
                continue
            p = int(s)
            if p in out or not 1 <= p <= players:
                raise ValueError("team layout %r: player %d repeated or outside 1..%d" % (text, p, players))
            out[p] = t
    if len(groups) != teams or sorted(out) != list(range(1, players + 1)):
        raise ValueError("team layout %r: needs every player 1..%d once in %d teams" % (text, players, teams))
    return out


def _model_layout(players: int, teams: int) -> Dict[int, int]:
    """mapsim's own lobby layout (scene.team_of) as {player: team}."""
    from scripts.mapsim.scene import team_of as _team_of
    return {p: _team_of(p, players, teams) for p in range(1, players + 1)}


def format_team_layout(team_of: Dict[int, int]) -> str:
    by: Dict[int, List[int]] = defaultdict(list)
    for p, t in sorted(team_of.items()):
        by[t].append(p)
    return "/".join(",".join(str(p) for p in by[t]) for t in sorted(by))


@dataclass
class TwinObject:
    kind: str                 # "expected" | "actual"
    proto: str                # object-def item / grouping member proto (actual: the census proto name)
    x_m: float                # expected: the asked spot judged (anchor + offset for a member); actual: census
    z_m: float
    fx: float
    fz: float
    player: Optional[int] = None
    anchor: str = ""          # the object def / grouping def name in the script
    line: int = 0             # the def's line
    grouping: str = ""        # members: the grouping file stem
    instance: str = ""        # expected: the placement instance ("<line>:<name>#<n>")
    member: Optional[int] = None      # members: index in the grouping file
    dx_m: Optional[float] = None      # members: posx / posz
    dz_m: Optional[float] = None
    key: str = ""             # key-object label ("" = not a key object)
    coin: str = ""            # "" | "either-arm": the spot or the owner depends on a random roll
    arm: str = ""             # the world(s) of the judged spot: "L", "H", "L+H", "N" (mapsim's mix only)
    spots: List[Dict[str, Any]] = field(default_factory=list)   # object defs: every candidate spot, nominal first
    judged: bool = True       # False = unjudged by construction (reason says why)
    status: str = ""          # matched | missing | extra | unjudged ("" = not joined)
    note: str = ""            # expected: what the scene knows (either-arm, approximate spot, why unjudged)
    reason: str = ""          # the join's explanation (why missing / unjudged)
    id: str = ""              # expected: unique object id
    census_id: str = ""       # actual: the census id in the save
    match_id: str = ""        # expected: census_id it matched; actual: id of the expected object it served
    match_dist_m: Optional[float] = None      # from the asked spot
    dist_measured_m: Optional[float] = None   # members: from the measured anchor + offset
    pixels: Dict[str, Tuple[float, float]] = field(default_factory=dict)
    max_dist_m: float = 0.0   # expected object def: its search radius (judged within tol_m + max_dist_m)
    owner: str = ""           # expected: owner verdict ok | mismatch | gaia ("" = not judged)
    census_player: Optional[int] = None       # expected: the owner of the census unit it matched
    owner_worlds: Dict[str, List[int]] = field(default_factory=dict)   # either-arm owner: players per coin world
    skewed: bool = False      # actual: decoded from a slightly skewed header (census_reader)
    drift_m: float = 0.0      # expected object def: extra allowance next to a route-docked placement (ROUTE_DRIFT_M)


Member = Tuple[str, float, float]            # (proto, posx, posz)


@dataclass
class GroupingInstance:
    id: str
    name: str
    line: int
    ref: str                                  # the grouping reference in the script (a stem or a prefix)
    players: List[int]
    spots: List[Dict[str, Any]]               # candidate spots {'arm','x_m','z_m','players'}, the nominal first
    variants: List[Tuple[str, List[Member], str]]   # (stem, members, source)
    allow_m: float                            # the anchor offset judged in place: join sets max(tol_m, max_dist_m)
    max_dist_m: float = 0.0                   # the def's rmSetGroupingMaxDistance
    coin: str = ""
    coin_group: str = ""
    capacity: Dict[Tuple[float, float], int] = field(default_factory=dict)
    notes: List[str] = field(default_factory=list)
    # join results
    verdict: str = ""
    stem: str = ""
    arm: str = ""
    x_m: Optional[float] = None               # the asked spot judged
    z_m: Optional[float] = None
    hyp: Optional[Tuple[float, float]] = None
    vi: int = 0                               # the chosen variant / spot indices
    si: int = 0
    measured_x_m: Optional[float] = None
    measured_z_m: Optional[float] = None
    offset_m: Optional[float] = None
    vote: int = 0                             # non-exclusive vote of the chosen hypothesis
    votes: int = 0                            # members claimed one to one
    n_members: int = 0
    missing_protos: Dict[str, int] = field(default_factory=dict)
    members: List[TwinObject] = field(default_factory=list)
    owner_worlds: Dict[str, List[int]] = field(default_factory=dict)   # either-arm owner: players per coin world
    owner: str = ""                           # ok | mismatch | gaia ("" = not judged: no player)
    owners_expected: List[int] = field(default_factory=list)
    owners_seen: Dict[int, int] = field(default_factory=dict)          # census owner -> claimed members (non-gaia)

    def summary(self) -> Dict[str, Any]:
        r = lambda v: None if v is None else round(v, 3)  # noqa: E731
        return {"id": self.id, "name": self.name, "line": self.line, "ref": self.ref, "stem": self.stem,
                "variants": [v[0] for v in self.variants], "source": next((v[2] for v in self.variants
                                                                          if v[0] == self.stem), ""),
                "players": self.players, "verdict": self.verdict, "votes": self.votes, "members": self.n_members,
                "vote_frac": r(self.votes / self.n_members) if self.n_members else None,
                "asked_x_m": r(self.x_m), "asked_z_m": r(self.z_m),
                "measured_x_m": r(self.measured_x_m), "measured_z_m": r(self.measured_z_m),
                "offset_m": r(self.offset_m), "allow_m": self.allow_m, "coin": self.coin, "arm": self.arm,
                "spots": self.spots, "notes": self.notes,
                "missing_protos": dict(Counter(self.missing_protos).most_common(12)),
                "owner": self.owner, "owners_expected": self.owners_expected,
                "owners_seen": {str(k): v for k, v in sorted(self.owners_seen.items())},
                "owner_worlds": self.owner_worlds}


@dataclass
class ExpectedScene:
    xs: Path
    players: int
    teams: int
    rs: Any
    size_x_m: float
    size_z_m: float
    objects: List[TwinObject]                 # object-def expected objects (members are made per join)
    groupings: List[GroupingInstance]
    unmodelled: List[Dict[str, Any]]
    unjudged: List[Dict[str, Any]]
    warnings: List[str]
    mapsim_warnings: List[str]
    solve_error: Optional[str]
    coin: Dict[str, Any]
    judged_protos: Set[str]                   # lower-case proto names
    excluded_protos: Set[str]                 # lower-case proto names
    groupings_source: str
    script_size_m: Optional[Tuple[float, float]] = None   # what the script's rmSetMapSize asked (mapsim's size)
    size_source: str = "script"               # "save": extracted at the census's own map size
    team_layout: Optional[Dict[int, int]] = None           # lobby player -> team (None = mapsim's scene.team_of)


# ----------------------------------------------------------------------------- grouping members
_REV_LIST: Dict[str, Dict[str, str]] = {}
_REV_UNITS: Dict[Tuple[str, str], Optional[List[Member]]] = {}


def _units_from_xml(data: bytes) -> List[Member]:
    """grouping_units_m's rule on raw XML: every <unit> with text and posx / posz."""
    out = []
    for u in ET.fromstring(data).iter("unit"):
        t = (u.text or "").strip()
        px, pz = u.get("posx"), u.get("posz")
        if not t or px is None or pz is None:
            continue
        try:
            out.append((t, float(px), float(pz)))
        except ValueError:
            continue
    return out


def _rev_listing(rev: str) -> Dict[str, str]:
    """{stem lower: repo path} of the grouping exports at a git revision ({} when git or the revision is missing)."""
    if rev not in _REV_LIST:
        listing = {}
        try:
            r = subprocess.run(["git", "-C", str(REPO), "ls-tree", "--name-only", rev, GROUPINGS_REL + "/"],
                               capture_output=True, text=True, timeout=60)
            if r.returncode == 0:
                for line in r.stdout.splitlines():
                    if line.lower().endswith(".xml"):
                        listing[Path(line).stem.lower()] = line
        except (OSError, subprocess.SubprocessError):
            pass
        _REV_LIST[rev] = listing
    return _REV_LIST[rev]


def _rev_units(rev: str, stem: str) -> Optional[List[Member]]:
    key = (rev, stem.lower())
    if key not in _REV_UNITS:
        units = None
        path = _rev_listing(rev).get(stem.lower())
        if path:
            try:
                r = subprocess.run(["git", "-C", str(REPO), "show", "%s:%s" % (rev, path)], capture_output=True,
                                   timeout=60)
                if r.returncode == 0:
                    units = _units_from_xml(r.stdout) or None
            except (OSError, subprocess.SubprocessError, ET.ParseError):
                units = None
        _REV_UNITS[key] = units
    return _REV_UNITS[key]


def git_rev_available(rev: str) -> bool:
    return bool(_rev_listing(rev))


def grouping_variants(ref: str, rev: Optional[str] = None) -> List[Tuple[str, List[Member], str]]:
    """[(stem, [(proto, posx, posz)], source)] for every file the reference can select (prefix variants, the
    engine's rule, scripts/refdata GroupingCatalog.resolve), exact stem first. source: 'git <rev>' when the file
    exists at that revision, else 'mod' (game/randmaps/groupings) or 'install' (the vanilla loose files)."""
    from scripts.refdata import catalog
    from scripts.refdata.catalogs import grouping_units_m
    stems = [e.name for e in catalog("grouping").resolve(ref)]
    if rev:
        low = {s.lower() for s in stems}
        key = ref.lower()
        for s_low, path in sorted(_rev_listing(rev).items()):
            if s_low.startswith(key) and s_low not in low:
                stems.append(Path(path).stem)
    stems.sort(key=lambda s: (s.lower() != ref.lower(), s.lower()))
    out = []
    for stem in stems[:MAX_VARIANTS]:
        units, src = None, ""
        if rev:
            units = _rev_units(rev, stem)
            src = "git %s" % rev if units else ""
        if not units:
            units = list(grouping_units_m(stem) or ())
            src = "mod" if (GROUPINGS / (stem + ".xml")).is_file() else "install"
        if units:
            out.append((stem, list(units), src))
    return out


def grouping_members(grouping_ref: str) -> List[str]:
    """Distinct unit protos of the first readable variant of a grouping reference ([] when none is readable)."""
    v = grouping_variants(grouping_ref)
    return sorted({p for p, _dx, _dz in v[0][1]}) if v else []


# ----------------------------------------------------------------------------- coin worlds
def _is_num(v) -> bool:
    return isinstance(v, (int, float)) and not isinstance(v, bool)


def _twin_extractor(XE, scenario, roll: Optional[str] = None, size_m: Optional[Tuple[float, float]] = None,
                    team_of: Optional[Dict[int, int]] = None):
    """An xs_extract.Extractor for one concrete twin world (relies on Extractor.call(name, args, line) and
    .res.map_size_x / _z, 2026-09-24):
      roll 'lo' / 'hi': every literal rmRandInt / rmRandFloat returns its low / high bound (a coin world);
      size_m: rmSetMapSize takes the save's (x, z) metres - every later conversion uses it, as the engine's does;
      team_of: rmGetPlayerTeam / rmGetNumberPlayersOnTeam answer from the lobby's layout instead of scene.team_of.
    .asked_size keeps what the script's rmSetMapSize asked."""
    team_n = Counter(team_of.values()) if team_of else Counter()

    class _Twin(XE.Extractor):
        def __init__(self, sc):
            super().__init__(sc)
            self.roll = roll
            self.rolled: Counter = Counter()
            self.asked_size: Optional[Tuple[float, float]] = None

        def call(self, name, args, line):
            if roll and name in ("rmRandInt", "rmRandFloat") and len(args) >= 2 and _is_num(args[0]) \
                    and _is_num(args[1]):
                self.rolled[line] += 1
                v = args[0] if roll == "lo" else args[1]
                return int(v) if name == "rmRandInt" else float(v)
            if team_of and args and _is_num(args[0]):
                if name == "rmGetPlayerTeam" and int(args[0]) in team_of:
                    return team_of[int(args[0])]
                if name == "rmGetNumberPlayersOnTeam":
                    return team_n.get(int(args[0]), 0)
            r = super().call(name, args, line)
            if name == "rmSetMapSize" and self.res.map_size_x is not None:
                self.asked_size = (self.res.map_size_x, self.res.map_size_z)
                if size_m is not None:
                    self.res.map_size_x, self.res.map_size_z = float(size_m[0]), float(size_m[1])
            return r
    return _Twin(scenario)


def _pkey(p) -> Tuple[str, int, str, str]:
    return (p.name, p.line, str(p.proto), p.kind)


def _spots_of(rs, sx: float, sz: float, positions=None) -> Dict[tuple, List[Tuple[float, float, Tuple[int, ...]]]]:
    out: Dict[tuple, list] = defaultdict(list)
    for i, p in enumerate(rs.placements):
        x, z = positions[i] if positions is not None else (p.x, p.z)
        if x is None or z is None:
            continue
        out[_pkey(p)].append((round(x * sx, 2), round(z * sz, 2), tuple(p.players or ())))
    return out


def _coin_worlds(src: str, scenario, sx: float, sz: float, size_m: Optional[Tuple[float, float]] = None,
                 team_of: Optional[Dict[int, int]] = None) -> Tuple[Dict[str, dict], Dict[str, Any]]:
    from scripts.mapsim import xs_extract as XE
    from scripts.mapsim.bridge import extraction_to_resolved
    worlds, info = {}, {"rolled_lines": {}, "errors": []}
    for label, roll in (("L", "lo"), ("H", "hi")):
        try:
            ext = _twin_extractor(XE, scenario, roll, size_m, team_of)
            rs = extraction_to_resolved(ext.run(src))
            if (rs.grid.size_x_m, rs.grid.size_z_m) != (sx, sz):
                info["errors"].append("world %s: map size %s x %s differs from the nominal %s x %s"
                                      % (label, rs.grid.size_x_m, rs.grid.size_z_m, sx, sz))
            worlds[label] = _spots_of(rs, sx, sz)
            if label == "L":
                info["rolled_lines"] = {str(k): v for k, v in sorted(ext.rolled.items())}
        except Exception as e:  # noqa: BLE001 - recorded: the twin then has no coin information
            info["errors"].append("world %s: %s: %s" % (label, type(e).__name__, e))
    return worlds, info


def _sk(x: float, z: float) -> Tuple[float, float]:
    """A spot's identity across the nominal scene and the coin worlds (0.1 m)."""
    return (round(float(x), 1), round(float(z), 1))


def _arm_of(pos: Tuple[float, float], worlds: Dict[str, dict], key: tuple) -> str:
    arms = [w for w in ("L", "H")
            if w in worlds and any(_sk(x, z) == _sk(*pos) for x, z, _p in worlds[w].get(key, ()))]
    return "+".join(arms) if arms else "N"


# ----------------------------------------------------------------------------- expected
def expected_scene(xs_path: Path, players: int, teams: int, tol_m: float = TOL_M,
                   groupings_rev: Optional[str] = None, size_m: Optional[Tuple[float, float]] = None,
                   team_layout: Optional[Dict[int, int]] = None) -> ExpectedScene:
    """The expected side of the twin for one player setup (module docstring: EXPECTED). size_m: extract at this map
    size (the save's) instead of the script's rmSetMapSize; team_layout: lobby player -> team (parse_team_layout)."""
    from scripts.mapsim import xs_extract as XE
    from scripts.mapsim.bridge import extraction_to_resolved
    from scripts.mapsim.scene import Scenario
    xs_path = Path(xs_path)
    src = xs_path.read_text(encoding="utf-8", errors="replace")
    sc = Scenario(players, teams)
    ext = _twin_extractor(XE, sc, None, size_m, team_layout)
    ex = ext.run(src)
    rs = extraction_to_resolved(ex)
    sx, sz = rs.grid.size_x_m, rs.grid.size_z_m
    authored = [(p.x, p.z) for p in rs.placements]           # before the solver moves anything
    approx0 = [bool(p.approx) for p in rs.placements]        # the bridge's own flag (the solver sets it too)
    worlds, coin_info = _coin_worlds(src, sc, sx, sz, size_m, team_layout)
    solve_error = None
    try:
        from scripts.mapsim.gsolve import ensure_solved
        ensure_solved(rs)
    except Exception as e:  # noqa: BLE001 - recorded in the report, never swallowed
        solve_error = "%s: %s" % (type(e).__name__, e)
    warnings: List[str] = []
    if solve_error:
        warnings.append("gsolve.ensure_solved failed (%s): grouping anchors are the AUTHORED ones" % solve_error)
    for e in coin_info["errors"]:
        warnings.append("coin %s: either-arm detection incomplete" % e)
    if groupings_rev and not git_rev_available(groupings_rev):
        warnings.append("groupings_rev %r: no grouping exports at that revision (git missing, shallow clone or a "
                        "wrong rev) - the working tree's exports are used" % groupings_rev)

    nominal = _spots_of(rs, sx, sz, authored)
    coin_keys: Dict[tuple, Dict[str, Any]] = {}
    for k, lst in nominal.items():
        pos_n = sorted((x, z) for x, z, _p in lst)
        present = [w for w in ("L", "H") if w in worlds]
        if not present:
            continue
        spot_diff = any(sorted((x, z) for x, z, _p in worlds[w].get(k, ())) != pos_n for w in present)
        owner_diff = any(sorted(worlds[w].get(k, ())) != sorted(lst) for w in present)
        if not spot_diff and not owner_diff:
            continue
        cands: List[Dict[str, Any]] = []
        pool = [w for w in present if worlds[w].get(k)]
        src_lists = [(w, worlds[w][k]) for w in pool] if len(pool) == len(present) else \
            [("N", lst)] + [(w, worlds[w][k]) for w in pool]
        cap: Counter = Counter()
        for w, wl in src_lists:
            c = Counter(_sk(x, z) for x, z, _p in wl)
            for pos, n in c.items():
                cap[pos] = max(cap[pos], n)
            for x, z, pl in wl:
                if not any(_sk(c_["x_m"], c_["z_m"]) == _sk(x, z) for c_ in cands):
                    cands.append({"arm": _arm_of((x, z), worlds, k), "x_m": x, "z_m": z, "players": list(pl)})
        coin_keys[k] = {"spot": spot_diff, "cands": cands, "cap": dict(cap),
                        "worlds": {w: sorted(worlds[w].get(k, ())) for w in present}}

    objects: List[TwinObject] = []
    groupings: List[GroupingInstance] = []
    unmodelled: List[Dict[str, Any]] = []
    unjudged: List[Dict[str, Any]] = []
    judged: Set[str] = set()
    excluded: Set[str] = set()
    seq: Counter = Counter()

    route_anchors = [(q.line, q.name, authored[j][0] * sx, authored[j][1] * sz) for j, q in enumerate(rs.placements)
                     if getattr(q, "route_docked", False) and authored[j][0] is not None and authored[j][1] is not None]

    for i, p in enumerate(rs.placements):
        k = _pkey(p)
        players_l = list(p.players or ())
        count = max(1, int(p.count or 1))
        n_inst = count * max(1, len(players_l))
        base = {"line": p.line, "name": p.name, "proto": str(p.proto), "kind": p.kind}
        if not p.active:
            unmodelled.append({**base, "reason": "inactive (a mode gate excluded it)"})
            continue
        if p.is_grouping and not str(p.proto).strip():
            unmodelled.append({**base, "reason": "grouping named by a runtime string (no literal file name)"})
            continue
        variants = grouping_variants(str(p.proto), groupings_rev) if p.is_grouping else []
        member_protos = {m[0].lower() for v in variants for m in v[1]}
        items = list(p.item_counts) or [(t, 1) for t in p.items]
        ax, az = authored[i]
        if ax is None or az is None or p.kind == "in_area":
            if p.kind == "in_area":
                why = "in_area %s: the engine picks the spot" % ",".join(p.area_refs)
                if p.x is not None:
                    why += " (gsolve's guess (%.1f, %.1f) m is not judged)" % (p.x * sx, p.z * sz)
            else:
                why = "runtime anchor: %s" % (p.runtime_expr or "?")
            unmodelled.append({**base, "reason": why})
            excluded |= member_protos | {t.lower() for t, _n in items}
            continue
        x_m, z_m = ax * sx, az * sz                          # the authored spot: the engine searches from here
        ck = coin_keys.get(k)
        notes = []
        if approx0[i]:
            notes.append("approx: nominal ring position")
        if p.x is not None and (p.x, p.z) != (ax, az):
            notes.append("gsolve moved it to (%.1f, %.1f) m inside its search radius: judged around the authored "
                         "anchor" % (p.x * sx, p.z * sz))
        if p.solve_unsat:
            notes.append("solver unsat: %s" % ",".join(map(str, p.solve_unsat)))
        if getattr(p, "route_docked", False):
            notes.append("route-docked: the engine moves it onto the trade route")
        if p.kind == "at_point_runtime":
            notes.append("a runtime point mapsim models (e.g. a trade-route waypoint): the spot is approximate")
        own_pos = (round(x_m, 2), round(z_m, 2))
        spot0 = {"arm": _arm_of(own_pos, worlds, k) if ck is not None else "", "x_m": round(x_m, 2),
                 "z_m": round(z_m, 2), "players": players_l}
        coin, spots, owner_worlds = "", [spot0], {}
        if ck is not None:
            coin = "either-arm"
            if ck["spot"]:
                spots += [c for c in ck["cands"] if _sk(c["x_m"], c["z_m"]) != _sk(*own_pos)]
                notes.append("either-arm: the spot depends on a random roll (%d candidate spots)" % len(spots))
            else:
                owners = {w: sorted({tuple(pl) for x, z, pl in wl if _sk(x, z) == _sk(*own_pos)})
                          for w, wl in ck["worlds"].items()}
                owner_worlds = {w: sorted({q for o in v for q in o}) for w, v in sorted(owners.items())}
                notes.append("either-arm: the owner depends on a random roll (players here: %s)"
                             % ", ".join("%s %s" % (w, [list(o) for o in v]) for w, v in sorted(owners.items())))
        md = float(p.max_dist_m or 0.0)
        drift = 0.0
        if not getattr(p, "route_docked", False):
            near = [ra for ra in route_anchors if ra[0] < p.line and math.hypot(ra[2] - x_m, ra[3] - z_m) <= ROUTE_NEAR_M]
            if near:
                drift = ROUTE_DRIFT_M
                notes.append("next to route-docked %r (line %d): its spot follows the real one, allowance +%g m"
                             % (near[0][1], near[0][0], drift))

        if p.is_grouping:
            if not variants:
                unmodelled.append({**base, "reason": "grouping %r: no readable export (mod folder%s, install)"
                                                       % (str(p.proto), ", git " + groupings_rev
                                                          if groupings_rev else "")})
                continue
            if md > MAX_GROUPING_SEARCH_M:
                unjudged.append({**base, "reason": "search radius %g m" % md, "x_m": round(x_m, 2),
                                 "z_m": round(z_m, 2), "count": n_inst, "protos": sorted(member_protos)[:20]})
                excluded |= member_protos
                continue
            allow = grouping_allow(tol_m, md) + drift
            if allow > tol_m:
                notes.append("searched within %g m (its max distance %g m + the %g m snap)" % (allow, md, SNAP_M))
            judged |= member_protos
            cap = {}
            if ck is not None and ck["spot"]:
                mult = max(1, n_inst)
                cap = {pos: n * mult for pos, n in ck["cap"].items()}
            for _ in range(n_inst):
                seq[(p.line, p.name)] += 1
                groupings.append(GroupingInstance(
                    id="%d:%s#%d" % (p.line, p.name, seq[(p.line, p.name)]), name=p.name, line=p.line,
                    ref=str(p.proto), players=players_l, spots=[dict(s) for s in spots], variants=variants,
                    allow_m=allow, max_dist_m=md, coin=coin,
                    coin_group=("%d:%s:%s" % (p.line, p.name, p.proto) if ck is not None and ck["spot"] else ""),
                    capacity=cap, notes=list(notes), owner_worlds=dict(owner_worlds)))
            continue

        # object def
        if not items:
            if p.name == "startingUnits" or str(p.proto) == "startingUnits":
                reason = "civ starting units (rmCreateStartingUnitsObjectDef): the set is the civ's, not modelled"
                unjudged.append({**base, "reason": reason, "x_m": round(x_m, 2), "z_m": round(z_m, 2),
                                 "count": n_inst, "players": players_l, "protos": []})
                for n in range(n_inst):
                    seq[(p.line, p.name)] += 1
                    objects.append(_expected_obj("startingUnits", p, x_m, z_m, sx, sz, seq, spots, coin,
                                                 judged=False, reason=reason,
                                                 player=players_l[n // count] if players_l else None))
            else:
                unmodelled.append({**base, "reason": "object def without an item"})
            continue
        protos = {t.lower() for t, _n in items}
        if md > MAX_DEF_SEARCH_M:
            reason = "search radius %g m" % md
            unjudged.append({**base, "reason": reason, "x_m": round(x_m, 2), "z_m": round(z_m, 2),
                             "radius_m": md, "count": n_inst * sum(max(1, n) for _t, n in items),
                             "players": players_l, "protos": sorted({t for t, _n in items})})
            excluded |= protos
            ok, why = False, reason
        else:
            judged |= protos
            if md > 0:
                notes.append("judged within tol + %g m (its search radius)" % md)
            ok, why = True, "; ".join(notes)
        for proto, n_item in items:
            per = count * max(1, int(n_item))                # units of this item per player call
            for n in range(n_inst * max(1, int(n_item))):
                seq[(p.line, p.name)] += 1
                objects.append(_expected_obj(proto, p, x_m, z_m, sx, sz, seq, spots, coin, judged=ok, reason=why,
                                             player=players_l[n // per] if players_l else None, max_dist_m=md,
                                             owner_worlds=owner_worlds, drift_m=drift))

    for w in ex.warnings:
        m = _NOTHING_PLACED.match(w)
        if m:
            unmodelled.append({"line": int(m.group(1)), "name": m.group(2), "proto": "", "kind": "call",
                               "reason": "mapsim: %s" % w})

    coin = {"worlds": "L = every literal rmRandInt / rmRandFloat at its low bound, H = at its high bound",
            "rolled_lines": coin_info["rolled_lines"], "errors": coin_info["errors"],
            "either_arm_placements": [{"line": k[1], "name": k[0], "proto": k[2], "spot": v["spot"],
                                       "candidates": v["cands"]} for k, v in coin_keys.items()],
            "limits": ["the two worlds roll every random call together: a generation mixing independent rolls can "
                       "put a placement at a spot neither world has",
                       "forks on other runtime values (unit positions, arrays, trigger state) are not varied"]}
    src_note = ("git %s (the working tree / install where a stem is absent there)" % groupings_rev
                if groupings_rev else "working tree (mod folder), then the game install")
    return ExpectedScene(xs=xs_path, players=players, teams=teams, rs=rs, size_x_m=sx, size_z_m=sz,
                         objects=objects, groupings=groupings, unmodelled=unmodelled, unjudged=unjudged,
                         warnings=warnings, mapsim_warnings=list(ex.warnings), solve_error=solve_error, coin=coin,
                         judged_protos=judged, excluded_protos=excluded, groupings_source=src_note,
                         script_size_m=ext.asked_size, size_source="save" if size_m is not None else "script",
                         team_layout=dict(team_layout) if team_layout else None)


def grouping_allow(tol_m: float, max_dist_m: float) -> float:
    """The anchor offset a grouping is judged in place with: tol_m (which carries the SNAP_M anchor snap), or
    max_dist_m + SNAP_M when the script gives it a search radius (wf verify M4)."""
    return max(tol_m, max_dist_m + SNAP_M) if max_dist_m > 0 else tol_m


def _expected_obj(proto, p, x_m, z_m, sx, sz, seq, spots, coin, judged=True, reason="", player="first",
                  max_dist_m=0.0, owner_worlds=None, drift_m=0.0) -> TwinObject:
    n = seq[(p.line, p.name)]
    if player == "first":
        player = p.players[0] if p.players else None
    o = TwinObject("expected", proto, x_m, z_m, x_m / sx, z_m / sz, player,
                   p.name, p.line, instance="%d:%s" % (p.line, p.name), coin=coin, arm=spots[0]["arm"],
                   judged=judged, status="" if judged else "unjudged", note=reason,
                   reason="" if judged else reason, id="%d:%s#%d/%s" % (p.line, p.name, n, proto),
                   max_dist_m=float(max_dist_m or 0.0), owner_worlds=dict(owner_worlds or {}), drift_m=float(drift_m))
    if len(spots) > 1:
        o.spots = [dict(s, fx=s["x_m"] / sx, fz=s["z_m"] / sz) for s in spots]
    return o


def materialize(g: GroupingInstance, variant: int = 0, spot: int = 0, sx: float = 1.0, sz: float = 1.0
                ) -> List[TwinObject]:
    """The member objects of one grouping instance at one candidate spot and variant (asked positions)."""
    stem, members, _src = g.variants[variant]
    s = g.spots[spot]
    out = []
    for j, (proto, dx, dz) in enumerate(members):
        x, z = s["x_m"] + dx, s["z_m"] + dz
        out.append(TwinObject("expected", proto, x, z, x / sx, z / sz, (g.players[0] if g.players else None),
                              g.name, g.line, grouping=stem, instance=g.id, member=j, dx_m=dx, dz_m=dz,
                              key=key_label(proto), coin=g.coin, arm=s["arm"], id="%s/m%d" % (g.id, j)))
    return out


def expected_objects(xs_path: Path, players: int, teams: int, tol_m: float = TOL_M):
    """(objects, resolved scene, warnings) without a census: the object-def objects plus every grouping's members
    at its nominal spot and first variant (kept for callers of the first version)."""
    exp = expected_scene(xs_path, players, teams, tol_m)
    objs = list(exp.objects)
    for g in exp.groupings:
        objs += materialize(g, 0, 0, exp.size_x_m, exp.size_z_m)
    return objs, exp.rs, exp.mapsim_warnings + exp.warnings


# ----------------------------------------------------------------------------- actual
def actual_objects(save: Path, size_x_m: float, size_z_m: float) -> List[TwinObject]:
    """The census units (census_reader.read): census_id, proto, position, owner ('player', 0 = gaia), skewed."""
    from scripts.mapview.census_reader import read
    out = []
    for u in read(Path(save), size_x_m, size_z_m):
        x, z = u["x_m"], u["z_m"]
        if not (math.isfinite(x) and math.isfinite(z)):
            continue
        out.append(TwinObject("actual", u["proto"], x, z, x / size_x_m, z / size_z_m, u.get("player"),
                              status="unjudged", census_id=str(u.get("census_id", u.get("id", ""))),
                              skewed=bool(u.get("skewed"))))
    return out


def census_facts(save: Path) -> Dict[str, Any]:
    """census_reader.read_stats of the save: records, decoded, undecoded, skewed, map_size_m, warnings, sources."""
    from scripts.mapview.census_reader import read_stats
    return read_stats(Path(save))


def save_checks(actual: Sequence[TwinObject], players: int, size_x_m: float, size_z_m: float,
                margin_m: float = OUTSIDE_MARGIN_M, stats: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
    """Does the save fit the requested setup? (module docstring: SAVE CHECKS). stats = census_facts(save): the
    decoded / undecoded record counts. 'hard' = --force cannot override (nothing decoded)."""
    tcs = sum(1 for a in actual if a.proto.lower() == "towncenter")
    outside = [a for a in actual if a.x_m < -margin_m or a.z_m < -margin_m or a.x_m > size_x_m + margin_m
               or a.z_m > size_z_m + margin_m]
    msgs = []
    records = int(stats["records"]) if stats else len(actual)
    undecoded = int(stats["undecoded"]) if stats else 0
    decoded = int(stats["decoded"]) if stats else len(actual)
    hard = decoded == 0 or not actual
    if hard:
        msgs.append("the census decodes no unit (%d records, 0 decoded): only Scenario Editor .age3Yscn saves of a "
                    "generation are supported (an in-match .age3Ysav carries its header at tag-62/-63)" % records)
    undecoded_ok = records == 0 or undecoded <= UNDECODED_REFUSE_FRAC * records
    if undecoded and not hard:
        msgs.append("%d of %d census records are undecoded (no valid header): their placements can read MISSING%s"
                    % (undecoded, records, "" if undecoded_ok else " - more than %.1f %%: a foreign layout?"
                       % (100 * UNDECODED_REFUSE_FRAC)))
    if tcs == 0:
        tc_ok = players < 1
        if not hard and players >= 1:
            msgs.append("the save holds no TownCenter while --players is %d: not a generation of this setup?"
                        % players)
    else:
        tc_ok = tcs == players
        if not tc_ok:
            msgs.append("the save holds %d TownCenter but --players is %d" % (tcs, players))
    limit = OUTSIDE_REFUSE_FRAC * max(1, len(actual))
    out_ok = len(outside) <= limit
    if outside:
        msgs.append("%d census units lie more than %g m outside the %g x %g m map (max x %.1f, max z %.1f)%s"
                    % (len(outside), margin_m, size_x_m, size_z_m, max(a.x_m for a in actual),
                       max(a.z_m for a in actual), "" if out_ok else ": wrong player count or map?"))
    return {"town_centres": tcs, "players": players, "tc_ok": tc_ok, "outside": len(outside),
            "outside_margin_m": margin_m, "records": records, "decoded": decoded, "undecoded": undecoded,
            "undecoded_ok": undecoded_ok, "hard": hard,
            "ok": (not hard) and tc_ok and out_ok and undecoded_ok, "messages": msgs}


# ----------------------------------------------------------------------------- join
class _Index:
    """Census units by (lower-case proto, 4 m cell). Every lookup is case-insensitive (the engine resolves XS item
    and grouping unit names case-insensitively)."""

    def __init__(self, actual: Sequence[TwinObject], cell: float = 4.0):
        self.cell, self.actual = cell, actual
        self.by: Dict[tuple, List[int]] = defaultdict(list)
        self.count: Counter = Counter()
        self._kinds: Dict[str, List[str]] = {}
        for i, a in enumerate(actual):
            p = a.proto.lower()
            self.by[(p, math.floor(a.x_m / cell), math.floor(a.z_m / cell))].append(i)
            self.count[p] += 1

    def kinds(self, item: str) -> List[str]:
        """Census protos (lower case) an object-def item accepts: the item itself, every proto whose unittypes
        include it, and the ITEM_KINDS alias (Nugget -> AbstractNugget)."""
        key = item.lower()
        hit = self._kinds.get(key)
        if hit is None:
            try:
                from scripts.refdata.catalogs import proto_counts_as
            except ImportError:                      # pragma: no cover - refdata ships with the repo
                proto_counts_as = None
            alias = ITEM_KINDS.get(key)
            hit = []
            for p in self.count:
                if p == key or (proto_counts_as is not None and (
                        proto_counts_as(p, key) or (alias is not None and proto_counts_as(p, alias)))):
                    hit.append(p)
            self._kinds[key] = hit
        return hit

    def near_kinds(self, item: str, x: float, z: float, r: float) -> List[Tuple[float, int]]:
        out = []
        for p in self.kinds(item):
            out += self.near(p, x, z, r)
        out.sort()
        return out

    def near(self, proto: str, x: float, z: float, r: float) -> List[Tuple[float, int]]:
        proto = proto.lower()
        if not self.count.get(proto):
            return []
        c, out = self.cell, []
        for cx in range(math.floor((x - r) / c), math.floor((x + r) / c) + 1):
            for cz in range(math.floor((z - r) / c), math.floor((z + r) / c) + 1):
                for i in self.by.get((proto, cx, cz), ()):
                    a = self.actual[i]
                    d = math.hypot(a.x_m - x, a.z_m - z)
                    if d <= r:
                        out.append((d, i))
        out.sort()
        return out

    def any_near(self, proto: str, x: float, z: float, r: float) -> bool:
        proto = proto.lower()
        if not self.count.get(proto):
            return False
        c = self.cell
        for cx in range(math.floor((x - r) / c), math.floor((x + r) / c) + 1):
            for cz in range(math.floor((z - r) / c), math.floor((z + r) / c) + 1):
                for i in self.by.get((proto, cx, cz), ()):
                    a = self.actual[i]
                    if math.hypot(a.x_m - x, a.z_m - z) <= r:
                        return True
        return False


def _vote(members: Sequence[Member], sx: float, sz: float, index: _Index, search_m: float,
          member_tol_m: float) -> Tuple[int, Optional[Tuple[float, float]]]:
    """(votes, hypothesis anchor): the anchor = unit - offset that the most members support within member_tol_m.
    A tie in votes goes to the smaller residual (the summed distance of each supporting member to its nearest
    same-proto unit), then to the anchor nearer the asked spot. 2026-09-24, the 2880x1800 device's London save: two
    harbour platforms 0.54 m apart let a hypothesis seeded from the wrong pairing (0.73 m off the exact anchor) draw
    all 20 votes too, and the nearer-to-the-asked-spot rule alone chose it by 0.02 m - one platform then read missing
    and its unit 'extra'."""
    rare = []
    for j, (proto, dx, dz) in enumerate(members):
        n = index.near(proto, sx + dx, sz + dz, search_m)
        if n:
            rare.append((len(n), j, n))
    rare.sort(key=lambda t: (t[0], t[1]))
    hyps: Dict[Tuple[float, float], Tuple[float, float]] = {}
    for _cnt, j, n in rare[:HYP_MEMBERS]:
        _p, dx, dz = members[j]
        for _d, i in n:
            a = index.actual[i]
            hx, hz = a.x_m - dx, a.z_m - dz
            hyps.setdefault((round(hx, 1), round(hz, 1)), (hx, hz))
        if len(hyps) >= HYP_CAP:
            break
    best, best_key, best_h = 0, None, None
    for hx, hz in list(hyps.values())[:HYP_CAP]:
        v, res = 0, 0.0
        for proto, dx, dz in members:
            n = index.near(proto, hx + dx, hz + dz, member_tol_m)
            if n:
                v += 1
                res += n[0][0]
        key = (-v, round(res, 6), math.hypot(hx - sx, hz - sz))
        if v and (best_key is None or key < best_key):
            best, best_key, best_h = v, key, (hx, hz)
    return best, best_h


def _reset(expected, actual, groupings):
    for e in expected:
        e.status = "" if e.judged else "unjudged"
        e.reason = "" if e.judged else e.note
        e.match_id, e.match_dist_m, e.dist_measured_m = "", None, None
        e.owner, e.census_player = "", None
        if e.spots:
            s = e.spots[0]
            e.x_m, e.z_m, e.fx, e.fz, e.arm = s["x_m"], s["z_m"], s["fx"], s["fz"], s["arm"]
    for a in actual:
        a.status, a.match_id, a.match_dist_m, a.dist_measured_m, a.reason = "unjudged", "", None, None, ""
    for g in groupings:
        g.verdict, g.stem, g.arm, g.x_m, g.z_m, g.hyp, g.vi, g.si = "", "", "", None, None, None, 0, 0
        g.measured_x_m = g.measured_z_m = g.offset_m = None
        g.vote = g.votes = g.n_members = 0
        g.missing_protos, g.members = {}, []
        g.owner, g.owners_expected, g.owners_seen = "", [], {}


def _rank(v: int, n: int, si: int, vi: int) -> tuple:
    """Sort key of a (variant, spot) vote, best first: variants whose vote reaches VOTE_OK before the others; among
    them the most votes (a small prefix variant that is a subset of the real file never beats it, wf verify L4),
    among the others the best fraction; then the nominal spot, the variant order."""
    frac = v / n if n else 0.0
    ok = frac >= VOTE_OK
    return (0 if ok else 1, -v if ok else -frac, -frac if ok else -v, si != 0, vi, si)


def _choose(groupings: List[GroupingInstance], index: _Index, member_tol_m: float) -> None:
    """Pick (variant, spot, hypothesis) per instance; either-arm groups share their candidate spots one to one."""
    cand: Dict[int, list] = {}
    for gi, g in enumerate(groupings):
        rows = []
        for vi, (_stem, members, _src) in enumerate(g.variants):
            for si, s in enumerate(g.spots):
                v, h = _vote(members, s["x_m"], s["z_m"], index, g.allow_m + member_tol_m, member_tol_m)
                rows.append(_rank(v, len(members), si, vi) + (v, h))
        rows.sort(key=lambda r: r[:6])
        cand[gi] = rows
    by_group: Dict[str, List[int]] = defaultdict(list)
    for gi, g in enumerate(groupings):
        by_group[g.coin_group or ("#%d" % gi)].append(gi)
    for key, gis in by_group.items():
        flat = sorted(((r, gi) for gi in gis for r in cand[gi]), key=lambda t: (t[0][:4], t[1], t[0][4:6]))
        used: Counter = Counter()
        done = set()
        for r, gi in flat:
            if gi in done:
                continue
            g = groupings[gi]
            s = g.spots[r[5]]
            pos = _sk(s["x_m"], s["z_m"])
            if not key.startswith("#") and used[pos] >= g.capacity.get(pos, 1):
                continue
            used[pos] += 1
            done.add(gi)
            _apply_choice(g, r)
        for gi in gis:                        # capacity exhausted: the instance keeps its best row anyway
            if gi not in done and cand[gi]:
                _apply_choice(groupings[gi], cand[gi][0])


def _apply_choice(g: GroupingInstance, row) -> None:
    _ok, _s1, _s2, _nn, vi, si, v, h = row
    s = g.spots[si]
    g.stem, g.arm, g.x_m, g.z_m, g.vote, g.hyp = g.variants[vi][0], s["arm"], s["x_m"], s["z_m"], v, h
    g.vi, g.si = vi, si


def join(expected: List[TwinObject], actual: List[TwinObject], tol_m: float = TOL_M,
         groupings: Optional[List[GroupingInstance]] = None, member_tol_m: float = MEMBER_TOL_M,
         excluded_protos: Optional[Set[str]] = None, size_x_m: float = 1.0, size_z_m: float = 1.0
         ) -> Dict[str, Any]:
    """Join the expected side (object-def objects + grouping instances) with the census units (module docstring:
    JOIN). Mutates the objects, fills every grouping's verdict and members; returns the counts."""
    groupings = groupings or []
    _reset(expected, actual, groupings)
    for g in groupings:
        g.allow_m = grouping_allow(tol_m, g.max_dist_m)
    index = _Index(actual)
    _choose(groupings, index, member_tol_m)

    members_all: List[TwinObject] = []
    tier: Dict[str, int] = {}
    for g in groupings:
        g.members = materialize(g, g.vi, g.si, size_x_m, size_z_m)
        g.n_members = len(g.members)
        frac = g.vote / g.n_members if g.n_members else 0.0
        if g.hyp is None or frac < VOTE_MIN:
            g.verdict = "missing"
            for m in g.members:
                m.status, m.reason = "missing", "grouping missing (vote %d/%d)" % (g.vote, g.n_members)
        else:
            t = 0 if frac >= VOTE_OK else 1
            for m in g.members:
                tier[m.id] = t
        members_all += g.members

    claims = []                  # (tier, owner penalty, dist to the claim centre, e_idx, a_idx, spot idx or -1)
    everything = list(expected) + members_all
    ginst = {g.id: g for g in groupings}
    for ei, e in enumerate(everything):
        if e.status in ("unjudged", "missing"):
            continue
        if e.member is not None:
            g = ginst[e.instance]
            cx, cz = g.hyp[0] + e.dx_m, g.hyp[1] + e.dz_m
            for d, ai in index.near(e.proto, cx, cz, member_tol_m):
                claims.append((tier.get(e.id, 1), 0, d, ei, ai, -1))
        else:
            spots = e.spots or [{"x_m": e.x_m, "z_m": e.z_m}]
            allow = tol_m + float(e.max_dist_m or 0.0) + float(e.drift_m or 0.0)
            want = _owners_expected(e.owner_worlds, [e.player] if e.player else [], None)
            best: Dict[int, Tuple[float, int]] = {}
            for si, s in enumerate(spots):
                for d, ai in index.near_kinds(e.proto, s["x_m"], s["z_m"], allow):
                    if ai not in best or d < best[ai][0]:
                        best[ai] = (d, si)
            for ai, (d, si) in best.items():
                q = actual[ai].player
                claims.append((0, 1 if want and q is not None and q not in want else 0, d, ei, ai, si))
    claims.sort(key=lambda c: (c[0], c[1], c[2], c[3], c[4]))
    taken_e, taken_a = set(), set()
    for _t, _pen, d, ei, ai, si in claims:
        if ei in taken_e or ai in taken_a:
            continue
        taken_e.add(ei)
        taken_a.add(ai)
        e, a = everything[ei], actual[ai]
        if si > 0:                                # an alternative arm's spot matched
            s = e.spots[si]
            e.x_m, e.z_m, e.fx, e.fz, e.arm = s["x_m"], s["z_m"], s["fx"], s["fz"], s["arm"]
        e.status, e.match_id = "matched", a.census_id
        e.match_dist_m = round(math.hypot(a.x_m - e.x_m, a.z_m - e.z_m), 3)
        a.status, a.match_id, a.match_dist_m = "matched", e.id, e.match_dist_m
    for ei, e in enumerate(everything):
        if e.status == "" and ei not in taken_e:
            e.status = "missing"
            why = []
            if e.coin and e.spots:
                why.append("either-arm: none of the %d candidate spots matched" % len(e.spots))
            if e.member is None:
                near = index.near_kinds(e.proto, e.x_m, e.z_m, NEAREST_DIAG_M)
                if near:
                    d, ai = near[0]
                    why.append("nearest %s (census %s) at %.2f m" % (actual[ai].proto, actual[ai].census_id, d))
                else:
                    why.append("no %s within %g m" % (e.proto, NEAREST_DIAG_M))
            if e.note:
                why.append(e.note)
            e.reason = "; ".join(why)

    by_id = {a.census_id: a for a in actual if a.status == "matched"}
    for g in groupings:
        got = [m for m in g.members if m.status == "matched"]
        g.votes = len(got)
        if got:
            mx = statistics.median(by_id[m.match_id].x_m - m.dx_m for m in got)
            mz = statistics.median(by_id[m.match_id].z_m - m.dz_m for m in got)
            g.measured_x_m, g.measured_z_m = mx, mz
            g.offset_m = math.hypot(mx - g.x_m, mz - g.z_m)
            for m in got:
                a = by_id[m.match_id]
                m.dist_measured_m = round(math.hypot(a.x_m - (mx + m.dx_m), a.z_m - (mz + m.dz_m)), 3)
        frac = g.votes / g.n_members if g.n_members else 0.0
        if g.verdict != "missing":
            if not got or frac < VOTE_MIN:
                g.verdict = "missing"
            elif g.offset_m > g.allow_m:
                g.verdict = "moved"
            else:
                g.verdict = "matched" if frac >= VOTE_OK else "partial"
        g.missing_protos = dict(Counter(m.proto for m in g.members if m.status != "matched"))

    if excluded_protos is None:
        excluded_protos = {e.proto for e in expected if not e.judged}
    excluded = set()
    for item in excluded_protos:
        excluded.update(index.kinds(item))
    zones: Dict[str, List[Tuple[float, float, float, float]]] = defaultdict(list)
    for e in expected:
        if e.judged:
            r = tol_m + float(e.max_dist_m or 0.0)
            for s in (e.spots or [{"x_m": e.x_m, "z_m": e.z_m}]):
                box = (s["x_m"] - r, s["z_m"] - r, s["x_m"] + r, s["z_m"] + r)
                for p in index.kinds(e.proto):
                    zones[p].append(box)
    for g in groupings:
        pad = g.allow_m + member_tol_m
        for _stem, members, _src in g.variants:
            if not members:
                continue
            x0 = g.x_m + min(m[1] for m in members) - pad
            x1 = g.x_m + max(m[1] for m in members) + pad
            z0 = g.z_m + min(m[2] for m in members) - pad
            z1 = g.z_m + max(m[2] for m in members) + pad
            for p in {m[0].lower() for m in members}:
                zones[p].append((x0, z0, x1, z1))
    start_spots = [(e.x_m, e.z_m) for e in expected if e.proto.lower() == "startingunits"]
    start_protos = set()
    if start_spots:
        for kind in STARTING_KINDS:
            start_protos.update(index.kinds(kind))
    for a in actual:
        if a.status == "matched":
            continue
        low = a.proto.lower()
        if low in excluded:
            a.status, a.reason = "unjudged", "an unmodelled or unjudged placement can place this proto"
        elif low in start_protos and any(math.hypot(a.x_m - x, a.z_m - z) <= STARTING_UNITS_RADIUS_M
                                         for x, z in start_spots):
            a.status, a.reason = "unjudged", "the civ's starting units (rmCreateStartingUnitsObjectDef) near a seat"
        elif any(x0 <= a.x_m <= x1 and z0 <= a.z_m <= z1 for x0, z0, x1, z1 in zones.get(low, ())):
            a.status, a.reason = "extra", ""
        elif low in zones:
            a.status, a.reason = "unjudged", "outside every expected footprint of its proto (areas, unmodelled code)"
        else:
            a.status, a.reason = "unjudged", ""

    verdicts = Counter(g.verdict for g in groupings)
    keys = [m for m in members_all if m.key]
    world = _coin_tally(expected, groupings)["detected"]
    return {"expected": len(everything), "matched": len(taken_e),
            "missing": sum(1 for e in everything if e.status == "missing"),
            "unjudged": sum(1 for e in everything if e.status == "unjudged"),
            "extra": sum(1 for a in actual if a.status == "extra"), "actual": len(actual),
            "groupings": {"total": len(groupings), **{k: verdicts.get(k, 0)
                                                      for k in ("matched", "partial", "moved", "missing")}},
            "key_objects": {"total": len(keys), "matched": sum(1 for m in keys if m.status == "matched")},
            "owners": check_owners(expected, groupings, actual, world)}


def _owners_expected(owner_worlds: Dict[str, List[int]], players: Sequence[int], world: Optional[str]) -> Set[int]:
    """The players a placement's units may belong to: the detected coin world's owners for an owner-flipping
    either-arm placement (every world's while undetected), else its own players (gaia / runtime = empty)."""
    if owner_worlds:
        if world in owner_worlds:
            return {int(q) for q in owner_worlds[world] if q}
        return {int(q) for v in owner_worlds.values() for q in v if q}
    return {int(p) for p in players if p}


def _owner_verdict(q: int, want: Set[int]) -> str:
    return "ok" if q in want else ("gaia" if q == 0 else "mismatch")


def check_owners(expected: Sequence[TwinObject], groupings: Sequence[GroupingInstance], actual: Sequence[TwinObject],
                 world: Optional[str] = None) -> Dict[str, Any]:
    """Owner verdicts after a join (module docstring: JOIN 4). Object defs: e.owner of the matched unit. Groupings:
    g.owner from the owned (non-gaia) claimed members, each member's m.owner / m.census_player. world = the detected
    coin world ('L' / 'H') for owner-flipping either-arm placements. Returns the tallies."""
    by_cid = {a.census_id: a for a in actual}
    defs, grps = Counter(), Counter()
    for e in expected:
        if e.member is not None:
            continue
        e.owner, e.census_player = "", None
        a = by_cid.get(e.match_id) if e.status == "matched" else None
        if a is None or a.player is None:
            continue
        e.census_player = a.player
        want = _owners_expected(e.owner_worlds, [e.player] if e.player else [], world)
        if want:
            e.owner = _owner_verdict(a.player, want)
            defs[e.owner] += 1
    for g in groupings:
        spot_players = g.spots[g.si].get("players") if g.spots and g.si < len(g.spots) else None
        want = _owners_expected(g.owner_worlds, spot_players or g.players, world)
        g.owners_expected = sorted(want)
        seen: Counter = Counter()
        for m in g.members:
            m.owner, m.census_player = "", None
            a = by_cid.get(m.match_id) if m.status == "matched" else None
            if a is None or a.player is None:
                continue
            m.census_player = a.player
            if a.player:
                seen[a.player] += 1
            if want:
                m.owner = _owner_verdict(a.player, want)
        g.owners_seen = dict(seen)
        g.owner = ""
        if want and g.verdict in ("matched", "partial", "moved"):
            g.owner = "gaia" if not seen else ("ok" if set(seen) <= want else "mismatch")
            grps[g.owner] += 1
    tally = lambda c: {k: c.get(k, 0) for k in ("ok", "mismatch", "gaia")}  # noqa: E731
    return {"world": world, "defs": tally(defs), "groupings": tally(grps),
            "mismatch": defs.get("mismatch", 0) + grps.get("mismatch", 0)}


def suggest_team_layout(expected: Sequence[TwinObject], groupings: Sequence[GroupingInstance], players: int,
                        teams: int, team_layout: Optional[Dict[int, int]] = None) -> Optional[Dict[int, int]]:
    """The lobby layout the census owners fit, or None. Every single-player placement (a seat; its expected owner
    as check_owners set it, i.e. in the detected coin world) the census shows owned by player q says: q sits where
    the model put p, so q plays on p's team. Only a complete, consistent assignment of players 1..players to `teams`
    teams is returned (a hint for --team-layout; measured 2026-09-24 on mapview_london4p_live: 1,2/3,4, which
    --team-layout then confirms with 0 mismatches)."""
    model = team_layout or _model_layout(players, teams)
    fit: Dict[int, Set[int]] = defaultdict(set)
    for g in groupings:
        if len(set(g.owners_expected)) == 1 and len(g.owners_seen) == 1:
            p, q = g.owners_expected[0], next(iter(g.owners_seen))
            if p in model:
                fit[q].add(model[p])
    per_instance: Dict[str, Set[int]] = defaultdict(set)
    for e in expected:
        if e.member is None and e.player:
            per_instance[e.instance].add(e.player)
    for e in expected:                           # a spot shared by several players is no seat evidence
        if e.member is None and e.player and e.census_player and not e.owner_worlds and e.player in model \
                and len(per_instance[e.instance]) == 1:
            fit[e.census_player].add(model[e.player])
    if sorted(fit) != list(range(1, players + 1)) or any(len(t) != 1 for t in fit.values()):
        return None
    out = {q: next(iter(t)) for q, t in fit.items()}
    if len(set(out.values())) != teams:
        return None
    return out


# ----------------------------------------------------------------------------- pixels
def add_pixels(objs: List[TwinObject], aspect: float, screens: Optional[List[str]] = None,
               skipped: Optional[List[str]] = None) -> Dict[str, str]:
    """Minimap pixels per calibration that is accepted AND checked (what transform.load_calibration serves with
    require_checked=True; wf verify L7); returns {screen_key: file}. Unreadable, unaccepted and unchecked records
    are listed in `skipped` with the reason."""
    used = {}
    for p in list_calibrations():
        try:
            cal = Calibration.from_json(p.read_text(encoding="utf-8"))
        except (OSError, ValueError, TypeError) as e:
            if skipped is not None:
                skipped.append("%s: unreadable (%s)" % (p.name, e))
            continue
        if not getattr(cal, "accepted", False):
            if skipped is not None:
                skipped.append("%s: not an accepted calibration (method %r)" % (p.name, getattr(cal, "method", "")))
            continue
        if not getattr(cal, "checked", False):
            if skipped is not None:
                skipped.append("%s: accepted but never passed `calibrate.py check` (checked=false)" % p.name)
            continue
        if screens and cal.screen not in screens:
            continue
        key = p.stem
        used[key] = str(p)
        for o in objs:
            o.pixels[key] = tuple(round(v, 1) for v in frac_to_minimap(o.fx, o.fz, cal, aspect))
    return used


# ----------------------------------------------------------------------------- render
def render(objs: List[TwinObject], rs, out_png: Path, title: str = "twin",
           groupings: Optional[List[GroupingInstance]] = None) -> bool:
    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
        from matplotlib.transforms import Affine2D
        from matplotlib.patches import Circle
    except ImportError:
        return False
    sx, sz = rs.grid.size_x_m, rs.grid.size_z_m
    aspect = aspect_of(sx, sz)
    fig, ax = plt.subplots(figsize=(10, 10), dpi=150)
    disp = Affine2D().scale(1.0, aspect) + Affine2D().rotate_deg_around(0.5, 0.5 * aspect, 45)
    tr = disp + ax.transData
    try:
        from scripts.mapsim.field import terrain_grid
        from scripts.mapsim.render import terrain_rgba
        tg = terrain_grid(rs, cell_tiles=1.0)
        ax.imshow(terrain_rgba(tg), origin="lower", extent=(0, 1, 0, 1), transform=tr, interpolation="nearest", zorder=1)
    except Exception as e:  # noqa: BLE001 - the picture still shows the objects
        ax.text(0.02, 0.98, "terrain: %s" % e, transform=ax.transAxes, fontsize=6, va="top")
    r = disc_radius_display(aspect)
    ax.add_patch(Circle((0.5, 0.5 * aspect), r, fill=False, lw=0.8, color="#888", zorder=2))

    def xy(fx, fz):
        u, v = frac_to_uv(fx, fz, aspect)
        return 0.5 + u, 0.5 * aspect + v

    colours = {"matched": "#22c55e", "missing": "#ef4444", "extra": "#f97316", "unjudged": "#94a3b8",
               "partial": "#eab308", "moved": "#a855f7", "": "#3b82f6"}
    batches: Dict[tuple, List[Tuple[float, float]]] = defaultdict(list)
    for o in objs:
        if o.kind == "expected":
            if o.member is not None:
                if o.status == "missing":
                    batches[("member-missing",)].append(xy(o.fx, o.fz))
                if o.key:
                    batches[("key", o.status)].append(xy(o.fx, o.fz))
            else:
                batches[("def", o.status)].append(xy(o.fx, o.fz))
        elif o.status in ("matched", "extra"):
            batches[("actual", o.status)].append(xy(o.fx, o.fz))
    for k, pts in batches.items():
        X = [p[0] for p in pts]
        Y = [p[1] for p in pts]
        if k[0] == "member-missing":
            ax.scatter(X, Y, s=2, c="#ef4444", marker=".", zorder=3, linewidths=0)
        elif k[0] == "key":
            ax.scatter(X, Y, s=40, facecolors="none", edgecolors=colours.get(k[1], "#3b82f6"), marker="*",
                       linewidths=1.0, zorder=6)
        elif k[0] == "def":
            ax.scatter(X, Y, s=14 if k[1] != "missing" else 40, facecolors="none",
                       edgecolors=colours.get(k[1], "#3b82f6"), marker="o", linewidths=1.0, zorder=4)
        elif k[1] == "matched":
            ax.scatter(X, Y, s=3, c=colours["matched"], marker="x", linewidths=0.5, alpha=0.35, zorder=3)
        else:
            ax.scatter(X, Y, s=24, c=colours[k[1]], marker="x", linewidths=0.9, zorder=7)
    for g in groupings or []:
        if g.x_m is None:
            continue
        X, Y = xy(g.x_m / sx, g.z_m / sz)
        c = colours.get(g.verdict, "#3b82f6")
        ax.plot(X, Y, marker="s", ms=5 if g.verdict == "matched" else 8, mfc="none", mec=c, mew=1.2, ls="", zorder=5)
        if g.verdict != "matched":
            ax.annotate("%s %d/%d" % (g.name[:20], g.votes, g.n_members), (X, Y), fontsize=5, color=c,
                        xytext=(3, 3), textcoords="offset points")
    for o in objs:
        if o.kind == "expected" and o.status == "missing" and (o.key or o.member is None) and o.judged:
            X, Y = xy(o.fx, o.fz)
            ax.annotate(o.proto[:22], (X, Y), fontsize=5, color="#ef4444", xytext=(3, -6), textcoords="offset points")
    lim = r + 0.05
    ax.set_xlim(0.5 - lim, 0.5 + lim)
    ax.set_ylim(0.5 * aspect - lim, 0.5 * aspect + lim)
    ax.set_aspect("equal")
    ax.set_xticks([])
    ax.set_yticks([])
    ax.set_title("%s   o object def   [] grouping   * key   x actual   red = missing   orange = extra   "
                 "yellow = partial   (top = code 1,1)" % title, fontsize=7)
    out_png.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(out_png, bbox_inches="tight")
    plt.close(fig)
    return True


# ----------------------------------------------------------------------------- report
def key_objects(groupings: List[GroupingInstance]) -> List[Dict[str, Any]]:
    out = []
    for g in groupings:
        for m in g.members:
            if m.key:
                out.append({"label": m.key, "proto": m.proto, "grouping": m.grouping, "instance": g.id,
                            "anchor": g.name, "line": g.line, "coin": m.coin, "arm": m.arm,
                            "asked_x_m": round(m.x_m, 3), "asked_z_m": round(m.z_m, 3), "status": m.status,
                            "census_id": m.match_id, "dist_m": m.match_dist_m,
                            "dist_measured_m": m.dist_measured_m, "grouping_verdict": g.verdict,
                            "owners_expected": list(g.owners_expected), "census_player": m.census_player,
                            "owner": m.owner})
    return out


def owner_mismatches(objects: Sequence[TwinObject], groupings: Sequence[GroupingInstance]) -> List[Dict[str, Any]]:
    """Every placement whose census owner is not the expected player (after check_owners)."""
    out = []
    for e in objects:
        if e.owner == "mismatch":
            out.append({"kind": "def", "id": e.id, "name": e.anchor, "line": e.line, "proto": e.proto,
                        "expected": [e.player], "census": {str(e.census_player): 1}, "census_id": e.match_id})
    for g in groupings:
        if g.owner == "mismatch":
            out.append({"kind": "grouping", "id": g.id, "name": g.name, "line": g.line, "proto": g.stem,
                        "expected": list(g.owners_expected),
                        "census": {str(k): v for k, v in sorted(g.owners_seen.items())}, "census_id": ""})
    return out


def _coin_tally(objects: List[TwinObject], groupings: List[GroupingInstance]) -> Dict[str, Any]:
    tally: Counter = Counter()
    for g in groupings:
        if g.coin and len(g.spots) > 1 and g.verdict in ("matched", "partial") and g.arm in ("L", "H"):
            tally[g.arm] += 1
    for o in objects:
        if o.coin and o.spots and o.status == "matched" and o.arm in ("L", "H"):
            tally[o.arm] += 1
    world = None
    if tally["L"] and not tally["H"]:
        world = "L"
    elif tally["H"] and not tally["L"]:
        world = "H"
    elif tally["L"] and tally["H"]:
        world = "mixed"
    return {"detected": world, "L": tally["L"], "H": tally["H"]}


def _staleness(census: Path, xs_path: Path, groupings: List[GroupingInstance], rev: Optional[str]) -> List[str]:
    out = []
    try:
        saved = Path(census).stat().st_mtime
    except OSError:
        return out
    if Path(xs_path).is_file() and Path(xs_path).stat().st_mtime > saved:
        out.append("%s is newer than the save: the expected side is today's script" % Path(xs_path).name)
    if rev:
        return out
    newer = sorted({v[0] for g in groupings for v in g.variants if v[2] == "mod"
                    and (GROUPINGS / (v[0] + ".xml")).is_file()
                    and (GROUPINGS / (v[0] + ".xml")).stat().st_mtime > saved})
    if newer:
        out.append("%d grouping exports are newer than the save (%s%s): their members may have moved since the "
                   "generation - judge against that time's exports with --groupings-rev <git rev>"
                   % (len(newer), ", ".join(newer[:8]), " ..." if len(newer) > 8 else ""))
    return out


def _dump(report: Dict[str, Any]) -> str:
    """JSON with one list element per line (a London twin holds ~10k member objects)."""
    parts = []
    for k, v in report.items():
        if isinstance(v, list) and v and isinstance(v[0], dict):
            body = ",\n  ".join(json.dumps(o, separators=(",", ":")) for o in v)
            parts.append(" %s: [\n  %s\n ]" % (json.dumps(k), body))
        else:
            parts.append(" %s: %s" % (json.dumps(k), json.dumps(v)))
    return "{\n" + ",\n".join(parts) + "\n}\n"


def default_out_dir(xs_path: Path, players: int) -> Path:
    """A fresh temporary folder: twin output never lands in the live-mod repository (twin review F11)."""
    return Path(tempfile.mkdtemp(prefix="twin_%s_%dp_" % (Path(xs_path).stem, players)))


def build(xs_path: Path, players: int, teams: int, census: Optional[Path], out_dir: Optional[Path] = None,
          tol_m: float = TOL_M, screens: Optional[List[str]] = None, png: bool = True,
          member_tol_m: float = MEMBER_TOL_M, groupings_rev: Optional[str] = None, strict: bool = False,
          team_layout=None) -> Dict:
    """Expected + (optional) census -> join -> <out>/twin.png, then <out>/twin.json. strict: raise
    TwinInputError when save_checks fails (the CLI's refusal); a census that decodes nothing is refused always.
    team_layout: '1,2/3,4' or {player: team} (module docstring: TEAM LAYOUT)."""
    t0 = time.time()
    team_of = dict(team_layout) if isinstance(team_layout, dict) else parse_team_layout(team_layout, players, teams)
    warnings: List[str] = []
    census_stats, size_m = None, None
    if census:
        try:
            census_stats = census_facts(Path(census))
        except (OSError, ValueError) as e:
            raise TwinInputError("the census %s is unreadable (%s): only Scenario Editor .age3Yscn saves are "
                                 "supported" % (Path(census).name, e), forceable=False)
        if not census_stats.get("decoded"):
            raise TwinInputError("the census %s decodes no unit (%d records, 0 decoded): only Scenario Editor "
                                 ".age3Yscn saves of a generation are supported (an in-match .age3Ysav carries its "
                                 "header at tag-62/-63)" % (Path(census).name, census_stats.get("records", 0)),
                                 forceable=False)
        if census_stats.get("map_size_m"):
            size_m = (float(census_stats["map_size_m"][0]), float(census_stats["map_size_m"][1]))
        else:
            warnings.append("the save holds no single terrain header: the script's map size is used, unverified "
                            "against the engine's")
    exp = expected_scene(xs_path, players, teams, tol_m=tol_m, groupings_rev=groupings_rev, size_m=size_m,
                         team_layout=team_of)
    sx, sz = exp.size_x_m, exp.size_z_m
    warnings += exp.warnings
    script = exp.script_size_m
    size_report = {"save_m": list(size_m) if size_m else None, "script_m": list(script) if script else None,
                   "used": exp.size_source, "gap_m": None}
    size_msgs: List[str] = []
    if size_m and script:
        gap = max(abs(size_m[0] - script[0]), abs(size_m[1] - script[1]))
        size_report["gap_m"] = round(gap, 3)
        if gap > SIZE_WARN_M:
            size_msgs.append("the save's map is %g x %g m but the script asks %g x %g m at %d players / %d teams "
                             "(%.1f m apart): a wrong --players / --teams or another map? The save's size is used"
                             % (size_m[0], size_m[1], script[0], script[1], players, teams, gap))
    warnings += size_msgs
    if tol_m < SNAP_M:
        warnings.append("tol_m %g m is below the grouping anchor snap budget %g m (measured up to 2.68 m on "
                        "London): in-place groupings may read as moved" % (tol_m, SNAP_M))
    actual: List[TwinObject] = []
    checks, mismatches = None, []
    if census:
        actual = actual_objects(Path(census), sx, sz)
        checks = save_checks(actual, players, sx, sz, stats=census_stats)
        if checks["hard"]:
            raise TwinInputError("; ".join(checks["messages"]), forceable=False)
        if strict and not checks["ok"]:
            raise TwinInputError("; ".join(checks["messages"] + size_msgs))
        warnings += checks["messages"]
        if census_stats.get("skewed"):
            warnings.append("census: %d records read from a slightly skewed header (census_reader SKEW_TOL)"
                            % census_stats["skewed"])
        warnings += ["census: %s" % w for w in census_stats.get("warnings", [])]
        warnings += _staleness(Path(census), Path(xs_path), exp.groupings, groupings_rev)
        counts = join(exp.objects, actual, tol_m, exp.groupings, member_tol_m, exp.excluded_protos, sx, sz)
        mismatches = owner_mismatches(exp.objects, exp.groupings)
        if mismatches:
            model = team_of or _model_layout(players, teams)
            hint = suggest_team_layout(exp.objects, exp.groupings, players, teams, team_of)
            msg = "owner mismatches on %d placements (the census owner is not the expected player)" % len(mismatches)
            if hint and hint != model:
                msg += ": the census owners fit --team-layout %s (%s %s)" % (
                    format_team_layout(hint), "the run used" if team_of else "mapsim's team model is",
                    format_team_layout(model))
            warnings.append(msg)
    else:
        for g in exp.groupings:
            g.stem, g.arm, g.x_m, g.z_m = g.variants[0][0], g.spots[0]["arm"], g.spots[0]["x_m"], g.spots[0]["z_m"]
            g.members = materialize(g, 0, 0, sx, sz)
            g.n_members = len(g.members)
        counts = {"expected": len(exp.objects) + sum(len(g.members) for g in exp.groupings),
                  "groupings": {"total": len(exp.groupings)}}
    members = [m for g in exp.groupings for m in g.members]
    expected_all = exp.objects + members
    for u in exp.unjudged:
        if census and u.get("radius_m"):
            r = u["radius_m"]
            want = {p.lower() for p in u["protos"]}
            u["found_in_radius"] = sum(1 for a in actual if a.proto.lower() in want
                                       and math.hypot(a.x_m - u["x_m"], a.z_m - u["z_m"]) <= r)
    aspect = aspect_of(sx, sz)
    skipped: List[str] = []
    used = add_pixels(expected_all + [a for a in actual if a.status in ("matched", "extra")], aspect, screens, skipped)
    out_dir = Path(out_dir) if out_dir else default_out_dir(Path(xs_path), players)
    out_dir.mkdir(parents=True, exist_ok=True)
    coin = dict(exp.coin)
    coin.update(_coin_tally(exp.objects, exp.groupings) if census else {"detected": None})
    report = {"map": str(xs_path), "players": players, "teams": teams, "size_x_m": sx, "size_z_m": sz,
              "size": size_report, "team_layout": format_team_layout(team_of) if team_of else None,
              "aspect": aspect, "census": str(census) if census else None, "census_stats": census_stats,
              "save_checks": checks, "owner_mismatches": mismatches,
              "tol_m": tol_m, "member_tol_m": member_tol_m, "snap_m": SNAP_M,
              "vote_ok": VOTE_OK, "vote_min": VOTE_MIN, "groupings_source": exp.groupings_source,
              "calibrations": used, "calibrations_skipped": skipped, "counts": counts, "coin": coin,
              "warnings": warnings, "solve_error": exp.solve_error, "mapsim_warnings": exp.mapsim_warnings,
              "unmodelled": exp.unmodelled, "unjudged": exp.unjudged,
              "groupings": [g.summary() for g in exp.groupings], "key_objects": key_objects(exp.groupings),
              "extra_by_proto": dict(Counter(a.proto for a in actual if a.status == "extra").most_common()),
              "unjudged_outside_footprints": dict(Counter(
                  a.proto for a in actual if a.reason.startswith("outside every")).most_common()),
              "actual_unjudged": sum(1 for a in actual if a.status == "unjudged"),
              "out": str(out_dir), "png": None, "seconds": None,
              "expected": [asdict(o) for o in expected_all],
              "actual": [asdict(o) for o in actual if o.status in ("matched", "extra")]}
    if png:
        report["png"] = render(expected_all + actual, exp.rs, out_dir / "twin.png", Path(xs_path).stem,
                               exp.groupings)
    report["seconds"] = round(time.time() - t0, 2)
    (out_dir / "twin.json").write_text(_dump(report), encoding="utf-8")
    return report


# ----------------------------------------------------------------------------- CLI
def _fmt_g(g: Dict[str, Any]) -> str:
    meas = "measured (%.2f, %.2f) off %.2f m" % (g["measured_x_m"], g["measured_z_m"], g["offset_m"]) \
        if g["measured_x_m"] is not None else "no anchor found"
    coin = "  [%s, arm %s]" % (g["coin"], g["arm"]) if g["coin"] else ""
    return "  %-8s %-26s %-36s %3d/%-3d at (%.1f, %.1f) %s%s (line %d)" % (
        g["verdict"].upper(), g["name"][:26], g["stem"][:36], g["votes"], g["members"], g["asked_x_m"],
        g["asked_z_m"], meas, coin, g["line"])


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("xs")
    ap.add_argument("--players", type=int, default=2)
    ap.add_argument("--teams", type=int, default=2)
    ap.add_argument("--census", default=None)
    ap.add_argument("--out", default=None, help="output folder (default: a fresh temporary folder)")
    ap.add_argument("--tol-m", type=float, default=TOL_M)
    ap.add_argument("--member-tol-m", type=float, default=MEMBER_TOL_M)
    ap.add_argument("--groupings-rev", default=None,
                    help="judge groupings against their exports at this git revision (a save older than an export)")
    ap.add_argument("--screens", default=None)
    ap.add_argument("--no-png", action="store_true")
    ap.add_argument("--all", action="store_true", help="print every grouping, not only the ones not matched")
    ap.add_argument("--force", action="store_true",
                    help="judge a save that fails the save checks anyway (never one that decodes nothing)")
    ap.add_argument("--team-layout", default=None,
                    help="the lobby's teams, team 0 first, e.g. 1,2/3,4 (default: mapsim's (p-1) %% teams model)")
    a = ap.parse_args(argv)
    try:
        layout = parse_team_layout(a.team_layout, a.players, a.teams)
    except ValueError as e:                      # a malformed --team-layout
        print("REFUSED: %s" % e)
        return 2
    try:
        rep = build(Path(a.xs), a.players, a.teams, Path(a.census) if a.census else None,
                    Path(a.out) if a.out else None, a.tol_m, a.screens.split(",") if a.screens else None,
                    png=not a.no_png, member_tol_m=a.member_tol_m, groupings_rev=a.groupings_rev,
                    strict=not a.force, team_layout=layout)
    except TwinInputError as e:
        tail = ("the save does not look like a %d-player generation of %s; --force judges it anyway"
                % (a.players, Path(a.xs).name)) if e.forceable else "--force cannot judge it"
        print("REFUSED: %s\n  %s" % (e, tail))
        return 2
    sz_ = rep["size"]
    print("%s %dp/%dt: map %.0f x %.0f m (%s%s); team layout %s; census %s; tol %g m, member tol %g m; "
          "groupings from %s" % (
              Path(a.xs).stem, a.players, a.teams, rep["size_x_m"], rep["size_z_m"],
              "the save's" if sz_["used"] == "save" else "the script's",
              (", the script asks %g x %g" % tuple(sz_["script_m"])) if sz_["used"] == "save" and sz_["script_m"]
              and sz_["gap_m"] else "", rep["team_layout"] or "mapsim model (1,2/3,4 blocks)",
              Path(rep["census"]).name if rep["census"] else "none", rep["tol_m"], rep["member_tol_m"],
              rep["groupings_source"]))
    print("  counts %s" % rep["counts"])
    print("  out %s (twin.json%s); calibrations %s; %.1f s" % (
        rep["out"], ", twin.png" if rep["png"] else "", list(rep["calibrations"]) or "none", rep["seconds"]))
    for w in rep["warnings"]:
        print("  WARNING %s" % w)
    c = rep["coin"]
    if c["either_arm_placements"]:
        print("  COIN world %s (L %s, H %s) over %d either-arm placements; %s" % (
            c.get("detected"), c.get("L", 0), c.get("H", 0), len(c["either_arm_placements"]), c["worlds"]))
    if rep["census"]:
        gs = rep["groupings"]
        print("  GROUPINGS %s" % rep["counts"]["groupings"])
        for g in gs:
            if a.all or g["verdict"] != "matched":
                print(_fmt_g(g))
        print("  KEY OBJECTS %s" % rep["counts"]["key_objects"])
        for k in rep["key_objects"]:
            d = "%.2f m from the asked spot, %s m from the measured anchor; census %s" % (
                k["dist_m"], k["dist_measured_m"], k["census_id"]) if k["status"] == "matched" else ""
            own = (" owner %s%s" % (k["census_player"], (" (expected %s: %s)" % (k["owners_expected"], k["owner"]))
                                    if k["owners_expected"] else "")) if k["census_player"] is not None else ""
            print("    %-8s %-12s %-26s %-24s %s%s" % (k["status"].upper(), k["label"], k["proto"][:26],
                                                       k["anchor"][:24], d, own))
        print("  OWNERS %s" % rep["counts"]["owners"])
        for o in rep["owner_mismatches"]:
            print("    OWNER MISMATCH %-8s %-28s line %-5d expected %s, census %s %s" % (
                o["kind"], o["name"][:28], o["line"], o["expected"], o["census"], o["census_id"]))
        for o in rep["expected"]:
            if o["status"] == "missing" and o["member"] is None:
                print("  MISSING %-30s %-28s at %6.1f / %6.1f m (line %d)%s" % (
                    o["proto"], o["anchor"], o["x_m"], o["z_m"], o["line"], ("  " + o["reason"]) if o["reason"] else ""))
        if rep["extra_by_proto"]:
            print("  EXTRA %d units: %s" % (rep["counts"]["extra"], ", ".join(
                "%s %d" % kv for kv in list(rep["extra_by_proto"].items())[:15])))
    for u in rep["unjudged"]:
        found = (" - census: %d of %d within the radius" % (u["found_in_radius"], u["count"])
                 if "found_in_radius" in u else "")
        print("  UNJUDGED line %d %-26s %s%s" % (u["line"], u["name"][:26], u["reason"], found))
    for u in rep["unmodelled"]:
        print("  UNMODELLED line %d %-26s %s" % (u["line"], u["name"][:26], u["reason"]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
