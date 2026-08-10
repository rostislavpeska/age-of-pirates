"""XS extractor (WP4): a mini-interpreter that reads an AoE3 DE random map
script and emits the geometry a scene needs — per scenario key, no regex.

Why an interpreter: the construct survey (docs/mapsim_xs_extraction_evidence.json)
proved pattern-matching wrong on this codebase — variables are reassigned
between uses, rmSetAreaSize is called up to 4x per handle under player-count
guards, conversions depend on the already-folded map size, and loop variables
leak into later names. So this executes the script with:

- a taint lattice: runtime-only reads (rmGetUnitPosition, rmRand*,
  rmFindClosestPointVector, rmGetTradeRouteWayPoint, rmPlayerLoc*Fraction...)
  return Tainted values that poison derived expressions; tainted geometry is
  emitted symbolic, never guessed
- model policies (documented): rmBuildArea succeeds (retry loops run their
  full count); rmGetCivID returns a valid id; tainted if-conditions execute
  BOTH arms as labeled variants (the teamStartLoc fork), with last-write-wins
  state — correct for the mirror-symmetric cases maps actually write
- scenario resolution: cNumberNonGaiaPlayers/cNumberPlayers/cNumberTeams,
  rmGetIsKOTH(), rmGetNomadStart() come from the Scenario key
- trigger DSL parse-and-discard (arguments still evaluated: trigger loops
  share loop variables with geometry code)

Unknown functions warn once and return 0; every warning is carried in the
result so "extraction completed with zero unsupported-construct warnings" is
a checkable gate.
"""

from __future__ import annotations

import math
import re
from dataclasses import dataclass, field as dfield
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

from scripts.mapsim.scene import Scenario


class ExtractError(Exception):
    pass


class Tainted:
    """Runtime-dependent value; propagates through arithmetic and concat.

    str_prefix: when the value is a string concat whose LEFT part is a
    literal ("maori_hawaii_0" + rmRandInt(1,5)), the literal survives here —
    the engine's grouping variant mechanic resolves by prefix, so the
    prefix IS the deterministically knowable identity of the reference."""

    __slots__ = ("expr", "lo", "hi", "str_prefix")

    def __init__(self, expr: str, lo: Optional[float] = None,
                 hi: Optional[float] = None,
                 str_prefix: Optional[str] = None):
        self.expr = expr
        self.lo = lo
        self.hi = hi
        self.str_prefix = str_prefix

    def __repr__(self) -> str:
        return f"?{self.expr}"


# ---------------------------------------------------------------------------
# Lexer
# ---------------------------------------------------------------------------

def strip_comments(src: str) -> str:
    out = []
    i, n = 0, len(src)
    while i < n:
        c = src[i]
        if c == '"':
            j = src.find('"', i + 1)
            j = n - 1 if j < 0 else j
            out.append(src[i:j + 1])
            i = j + 1
        elif c == '/' and i + 1 < n and src[i + 1] == '/':
            j = src.find('\n', i)
            i = n if j < 0 else j
        elif c == '/' and i + 1 < n and src[i + 1] == '*':
            j = src.find('*/', i + 2)
            j = n - 2 if j < 0 else j
            out.append('\n' * src.count('\n', i, j + 2))  # keep line numbers
            i = j + 2
        else:
            out.append(c)
            i += 1
    return ''.join(out)


TOKEN_RE = re.compile(r'''
    (?P<ws>[ \t\r]+)
  | (?P<nl>\n)
  | (?P<num>\d+\.\d*|\.\d+|\d+)
  | (?P<id>[A-Za-z_][A-Za-z0-9_]*)
  | (?P<str>"[^"\n]*")
  | (?P<op>==|!=|<=|>=|&&|\|\||\+\+|--|[-+*/%<>=!(){};,])
''', re.X)

KEYWORDS = {"int", "float", "string", "bool", "vector", "void", "if", "else",
            "for", "break", "return", "include", "true", "false", "rule",
            "while", "switch"}


def tokenize(src: str) -> List[Tuple[str, str, int]]:
    tokens = []
    line = 1
    pos = 0
    n = len(src)
    while pos < n:
        m = TOKEN_RE.match(src, pos)
        if m is None:
            # Unknown character (stray backtick etc.): skip with a marker.
            pos += 1
            continue
        kind = m.lastgroup
        text = m.group()
        pos = m.end()
        if kind == "nl":
            line += 1
            continue
        if kind == "ws":
            continue
        tokens.append((kind, text, line))
    tokens.append(("eof", "", line))
    return tokens


# ---------------------------------------------------------------------------
# Parser -> tuple AST
# ---------------------------------------------------------------------------

class Parser:
    def __init__(self, tokens: List[Tuple[str, str, int]]):
        self.toks = tokens
        self.i = 0

    def peek(self, k: int = 0):
        return self.toks[min(self.i + k, len(self.toks) - 1)]

    def next(self):
        t = self.toks[self.i]
        self.i += 1
        return t

    def expect(self, text: str):
        kind, val, line = self.next()
        if val != text:
            raise ExtractError(f"line {line}: expected {text!r}, got {val!r}")

    def at(self, text: str) -> bool:
        return self.peek()[1] == text

    # -- program ------------------------------------------------------------

    def parse_program(self) -> List[tuple]:
        items = []
        while self.peek()[0] != "eof":
            items.append(self.parse_top())
        return items

    def parse_top(self) -> tuple:
        kind, val, line = self.peek()
        if val == "include":
            self.next()
            name = self.next()[1].strip('"')
            if self.at(";"):
                self.next()
            return ("include", name, line)
        if val in ("void", "int", "float", "string", "bool", "vector") and \
                self.peek(1)[0] == "id" and self.peek(2)[1] == "(":
            return self.parse_funcdef()
        return self.parse_stmt()

    def parse_funcdef(self) -> tuple:
        _, rettype, line = self.next()
        name = self.next()[1]
        self.expect("(")
        params = []
        while not self.at(")"):
            ptype = self.next()[1]           # type or 'void'
            if ptype == "void" and self.at(")"):
                break
            pname = self.next()[1]
            default = None
            if self.at("="):
                self.next()
                default = self.parse_expr()
            params.append((pname, default))
            if self.at(","):
                self.next()
        self.expect(")")
        body = self.parse_block()
        return ("func", rettype, name, params, body, line)

    # -- statements ----------------------------------------------------------

    def parse_block(self) -> List[tuple]:
        self.expect("{")
        stmts = []
        while not self.at("}"):
            if self.peek()[0] == "eof":
                raise ExtractError("unexpected EOF in block")
            stmts.append(self.parse_stmt())
        self.next()
        return stmts

    def parse_stmt(self) -> tuple:
        kind, val, line = self.peek()
        if val == "{":
            return ("block", self.parse_block(), line)
        if val == ";":
            self.next()
            return ("nop", line)
        if val == "include":
            return self.parse_top()
        if val == "if":
            return self.parse_if()
        if val == "for":
            return self.parse_for()
        if val == "break":
            self.next()
            if self.at(";"):
                self.next()
            return ("break", line)
        if val == "return":
            self.next()
            expr = None
            if not self.at(";"):
                expr = self.parse_expr()
            if self.at(";"):
                self.next()
            return ("return", expr, line)
        if val in ("int", "float", "string", "bool", "vector"):
            self.next()
            name = self.next()[1]
            expr = None
            if self.at("="):
                self.next()
                expr = self.parse_expr()
            if self.at(";"):
                self.next()
            return ("decl", val, name, expr, line)
        # assignment or expression statement
        if kind == "id" and self.peek(1)[1] == "=" and self.peek(1)[0] == "op" \
                and self.toks[self.i + 1][1] == "=":
            name = self.next()[1]
            self.next()  # =
            expr = self.parse_expr()
            if self.at(";"):
                self.next()
            return ("assign", name, expr, line)
        if kind == "id" and self.peek(1)[1] in ("++", "--"):
            name = self.next()[1]
            op = self.next()[1]
            if self.at(";"):
                self.next()
            delta = 1 if op == "++" else -1
            return ("assign", name, ("bin", "+", ("var", name), ("num", delta)), line)
        expr = self.parse_expr()
        if self.at(";"):
            self.next()
        return ("expr", expr, line)

    def parse_if(self) -> tuple:
        _, _, line = self.next()
        self.expect("(")
        cond = self.parse_expr()
        self.expect(")")
        then = [self.parse_stmt()]
        if then[0][0] == "block":
            then = then[0][1]
        els: List[tuple] = []
        if self.at("else"):
            self.next()
            els = [self.parse_stmt()]
            if els[0][0] == "block":
                els = els[0][1]
        return ("if", cond, then, els, line)

    def parse_for(self) -> tuple:
        _, _, line = self.next()
        self.expect("(")
        var = self.next()[1]
        if var in ("int", "float", "bool", "string", "vector"):
            var = self.next()[1]
        self.expect("=")
        start = self.parse_expr()
        self.expect(";")
        # shorthand: `< bound` / `> bound` etc. (zpunknown:7986 uses
        # `for (n=2; > fail*1000)`); C-style: `i < bound; i++`
        if self.peek()[1] in ("<", "<=", ">", ">="):
            op = self.next()[1]
            bound = self.parse_expr()
            self.expect(")")
        else:
            cond_var = self.next()[1]
            op = self.next()[1]
            bound = self.parse_expr()
            if self.at(";"):
                self.next()
                # step clause: i++ (only observed form)
                if self.peek()[0] == "id":
                    self.next()
                    if self.peek()[1] in ("++", "--"):
                        self.next()
            self.expect(")")
            if cond_var != var:
                raise ExtractError(f"line {line}: for-loop cond var {cond_var!r} != {var!r}")
        body = [self.parse_stmt()]
        if body[0][0] == "block":
            body = body[0][1]
        return ("for", var, start, op, bound, body, line)

    # -- expressions ----------------------------------------------------------

    def parse_expr(self) -> tuple:
        return self.parse_or()

    def parse_or(self):
        left = self.parse_and()
        while self.at("||"):
            self.next()
            left = ("bin", "||", left, self.parse_and())
        return left

    def parse_and(self):
        left = self.parse_eq()
        while self.at("&&"):
            self.next()
            left = ("bin", "&&", left, self.parse_eq())
        return left

    def parse_eq(self):
        left = self.parse_rel()
        while self.peek()[1] in ("==", "!="):
            op = self.next()[1]
            left = ("bin", op, left, self.parse_rel())
        return left

    def parse_rel(self):
        left = self.parse_add()
        while self.peek()[1] in ("<", "<=", ">", ">="):
            op = self.next()[1]
            left = ("bin", op, left, self.parse_add())
        return left

    def parse_add(self):
        left = self.parse_mul()
        while self.peek()[1] in ("+", "-"):
            op = self.next()[1]
            left = ("bin", op, left, self.parse_mul())
        return left

    def parse_mul(self):
        left = self.parse_unary()
        while self.peek()[1] in ("*", "/", "%"):
            op = self.next()[1]
            left = ("bin", op, left, self.parse_unary())
        return left

    def parse_unary(self):
        if self.at("-"):
            self.next()
            return ("neg", self.parse_unary())
        if self.at("!"):
            self.next()
            return ("not", self.parse_unary())
        return self.parse_primary()

    def parse_primary(self):
        kind, val, line = self.next()
        if kind == "num":
            return ("num", float(val) if "." in val else int(val))
        if kind == "str":
            return ("str", val[1:-1])
        if val == "true":
            return ("bool", True)
        if val == "false":
            return ("bool", False)
        if val == "(":
            e = self.parse_expr()
            self.expect(")")
            return e
        if kind == "id":
            if self.at("("):
                self.next()
                args = []
                while not self.at(")"):
                    if self.at(","):        # tolerate trailing/duplicate commas
                        self.next()
                        continue
                    args.append(self.parse_expr())
                self.next()
                return ("call", val, args, line)
            return ("var", val)
        raise ExtractError(f"line {line}: unexpected token {val!r}")


# ---------------------------------------------------------------------------
# Extraction result model
# ---------------------------------------------------------------------------

@dataclass
class XArea:
    name: str
    line: int
    x: Any = None                     # float | Tainted | None
    z: Any = None
    size_min_frac: Any = None         # fraction of map area
    size_max_frac: Any = None
    base_height: Optional[float] = None
    coherence: Optional[float] = None
    smooth: float = 0.0
    obey_world_circle: bool = True
    cliff_type: Optional[str] = None
    cliff_height: Optional[float] = None   # rmSetAreaCliffHeight val (rand -> lo)
    water_type: Optional[str] = None   # rmSetAreaWaterType: paints real water
    has_paint: bool = False            # rmSetAreaMix/TerrainType/TerrainLayer
    loc_player: Optional[Any] = None   # rmSetAreaLocPlayer: anchored to player N
    loc_team: Optional[Any] = None     # rmSetAreaLocTeam: anchored to team N
    height_blend: float = 0.0          # rmSetAreaHeightBlend (>=2 flattens stamps)
    has_elevation: bool = False        # any rmSetAreaElevation* call
    classes: List[str] = dfield(default_factory=list)
    constraints: List[str] = dfield(default_factory=list)
    influence_segments: List[Tuple[Any, Any, Any, Any]] = dfield(default_factory=list)
    built: bool = False
    count: int = 1                    # after collapse


@dataclass
class XDef:
    name: str
    line: int
    is_grouping: bool = False
    proto: Any = ""
    items: List[Tuple[Any, Any]] = dfield(default_factory=list)   # (proto, count)
    min_dist: Any = 0.0
    max_dist: Any = 0.0
    constraints: List[str] = dfield(default_factory=list)
    classes: List[str] = dfield(default_factory=list)
    route_docked: bool = False


@dataclass
class XPlacement:
    def_line: int
    name: str
    kind: str                          # at_loc | in_area | at_point
    players: List[Any] = dfield(default_factory=list)
    x: Any = None
    z: Any = None
    area_refs: List[str] = dfield(default_factory=list)
    count: Any = 1
    variant: str = ""


@dataclass
class XRiver:
    line: int
    water_type: str
    width: Any = 10.0
    waypoints: List[Tuple[Any, Any]] = dfield(default_factory=list)
    shallow_radius: Any = 15.0             # rmRiverSetShallowRadius (m)
    shallows: List[Any] = dfield(default_factory=list)   # rmRiverAddShallow t


@dataclass
class XConnection:
    """rmCreateConnection causeway: a band between two areas at a base
    height (Tortuga/Cook waterline causeways, Hawaii island links)."""
    line: int
    width: Any = 10.0
    base_height: Optional[float] = None
    areas: List[int] = dfield(default_factory=list)
    built: bool = False


@dataclass
class Extraction:
    scenario: Scenario
    map_size_x: Optional[float] = None
    map_size_z: Optional[float] = None
    sea_level: Optional[float] = None
    sea_type: Optional[str] = None            # rmSetSeaType
    terrain_init: Optional[str] = None        # rmTerrainInitialize terrain arg
    terrain_init_height: Optional[float] = None   # its height arg, when given
    world_circle: bool = False
    areas: Dict[int, XArea] = dfield(default_factory=dict)          # by handle
    defs: Dict[int, XDef] = dfield(default_factory=dict)
    placements: List[XPlacement] = dfield(default_factory=list)
    waypoints: List[Tuple[Any, Any]] = dfield(default_factory=list)
    route_waypoints: Dict[int, List[Tuple[Any, Any]]] = dfield(default_factory=dict)
    rivers: Dict[int, "XRiver"] = dfield(default_factory=dict)
    connections: Dict[int, "XConnection"] = dfield(default_factory=dict)
    constraints: Dict[str, Dict[str, Any]] = dfield(default_factory=dict)
    player_events: List[Dict[str, Any]] = dfield(default_factory=list)
    warnings: List[str] = dfield(default_factory=list)

    def warn(self, msg: str) -> None:
        if msg not in self.warnings:
            self.warnings.append(msg)


# River half-width saturation (see rmRiverCreate handler). RECALIBRATED
# 2026-08-09 (second pass, lake-calibrated transform + overlay method):
# - low R is EXACT 2R, uncapped: crownlands R=14 -> 28 m band, riverina
#   R=15 -> 30 m band, both hugging their minimap edges to the pixel;
# - saturation is real: civilwar R=180 measures ~60-66 m full width on
#   clean stretches (incl. the shallow tan fringe) -> cap half = 32;
# - the original 27 came partly from elbe, whose "river" runs inside its
#   open estuary and cannot be measured — that calibration is void.
# Between R=32 and R=180 the corpus has no measurable river (elbe estuary,
# kingofbohemia city-covered, venice lagoon) — refining the knee is
# experiment E6 (in-game probe map).
RIVER_HALF_WIDTH_CAP_M = 32.0


class _Break(Exception):
    pass


class _Return(Exception):
    pass


# Config / cosmetic / trigger calls that are correct to ignore entirely.
NOOP_FUNCS = {
    "rmSetStatusText", "rmEchoInfo", "rmEchoError", "rmSetLightingSet",
    "rmSetMapType", "rmEnableLocalWater",
    "rmSetMapElevationParameters", "rmSetMapElevationHeightBlend",
    "rmSetWindMagnitude", "rmSetUnderbrushTree",
    "rmSetGlobalRain", "rmSetGlobalSnow", "rmSetMapElevationOctaves",
    "rmSetAreaReveal", "rmSetAreaWarnFailure",
    "rmSetAreaForestType", "rmSetAreaForestDensity",
    "rmSetAreaForestClumpiness", "rmSetAreaForestUnderbrushDensity",
    "rmSetAreaForestUnderbrush",
    "rmSetAreaMinBlobs", "rmSetAreaMaxBlobs", "rmSetAreaMinBlobDistance",
    "rmSetAreaMaxBlobDistance", "rmAddAreaRemoveType", "rmAddAreaCliffEdge",
    "rmSetAreaCliffEdge", "rmSetAreaCliffPainting",
    "rmSetAreaEdgeFilling", "rmSetAreaSmoothDistance2",
    "rmSetObjectDefAllowOverlap", "rmSetObjectDefForceFullRotation",
    "rmSetObjectDefCreateHerd", "rmSetObjectDefHerdAngle",
    "rmSetObjectDefMinItemDistance", "rmPlaceObjectDefPerPlayer",
    "rmSetNuggetDifficulty", "rmSetIgnoreForceToGaia",
    "rmSetTradeRouteWanderDistance",
    "rmAddClosestPointConstraint", "rmClearClosestPointConstraints",
    "rmSetSubCiv", "rmAddMerc", "chooseMercs", "ypMonasteryBuilder",
    "rmDisableDefaultMercs", "rmDisableCivTypeMercRestriction",
    "rmEnableMerc", "rmDisableMerc", "rmSetBaseTerrainMix",
    "ypKingsHillPlacer", "rmBuildAllAreas", "rmSetPlacementArea",
    "rmRiverAddShallows", "rmRiverSetBankPercent", "rmRiverSetConnections",
    "rmRiverBuild", "rmRiverReveal", "rmRiverSetFoundationTerrain",
    "rmSetTeamSpacing",
    "rmSetConnectionType", "rmSetConnectionCoherence",
    "rmSetConnectionWarnFailure", "rmSetConnectionHeightBlend",
    "rmSetConnectionSmoothDistance", "rmSetConnectionPositionVariance",
    "rmAddConnectionTerrainReplacement", "rmAddConnectionStartConstraint",
    "rmAddConnectionEndConstraint", "rmAddConnectionConstraint",
    "kbGetPlayerName", "rmRiverSetBankNoiseParams", "rmSetOceanReveal",
    # objectives screen: UI-only, no geometry
    "rmObjectiveScreenSetTitle", "rmObjectiveScreenSetGoal",
    "rmObjectiveAdd", "rmObjectiveSetTeam",
    # victory settings: no geometry
    "rmForbidTradeMonopoly",
}

# Trigger DSL: parse-and-discard (arguments ARE evaluated by the caller).
TRIGGER_FUNCS = {
    "rmCreateTrigger", "rmSwitchToTrigger", "rmAddTriggerCondition",
    "rmAddTriggerEffect", "rmSetTriggerConditionParam",
    "rmSetTriggerConditionParamInt", "rmSetTriggerConditionParamFloat",
    "rmSetTriggerEffectParam", "rmSetTriggerEffectParamInt",
    "rmSetTriggerEffectParamFloat", "rmSetTriggerPriority",
    "rmSetTriggerActive", "rmSetTriggerRunImmediately", "rmSetTriggerLoop",
    "rmTriggerID", "rmAddTriggerEffectParam",
}

# Runtime-only reads -> Tainted. (rmPlayerLocX/ZFraction and
# rmGetTradeRouteWayPoint are NOT here: ring nominals and the authored
# route polyline make them deterministic — see the call handlers.)
TAINTED_FUNCS = {
    "rmFindClosestPointVector",
    "rmGetPlayerCiv",
    "rmGetPlayerName", "ypIsAsian",
    "rmGetNumberUnitsPlaced", "rmGetHomeCityLevel",
    "rmGetGroupingInstanceUnitByType",
}


def ring_positions(player_events, players: int, teams: int):
    """Deterministic NOMINAL player positions from the placement calls
    recorded so far — the single implementation shared by the bridge and
    the in-extractor rmPlayerLocX/ZFraction resolution (per-player content
    like Cook Islands' Maori villages anchors on TC readbacks of these).

    ENGINE ANGLE CONVENTION (pinned 2026-08-10; the "Civil War forts"
    bug): circle fraction s sits at position angle 90° − s·360° — s=0 at
    authored NORTH (+z), increasing CLOCKWISE toward +x:
        pos(s) = (0.5 + r·sin(2πs), 0.5 + r·cos(2πs))
    i.e. the x/z SWAP of the naive math convention. Full rings (0..1)
    produce the same uniform point set either way, which is why only
    SECTIONED team maps exposed the transpose. Evidence: zpunknown's
    8-way bay ladder pairs each bay compass point with the player
    section opposite it — exact fit for this formula and no other;
    zpcivilwar's P2 branch places both players literally at z=0.25
    (south, mirrored about x=0.5, minimap-confirmed) and its P4+
    sections (0.28-0.4 / 0.6-0.72) reproduce that design only under
    this formula; the official RMS doc's minimap clock agrees.

    rmPlacePlayersLine: players evenly spaced from (x1,z1) to (x2,z2),
    ENDPOINTS INCLUDED, in lobby order (zpbarrierreef widens its line
    span with player count to hold spacing — interior-only slots would
    make its 2-player lines absurdly tight). Per-team lines honored
    (bluemountains/paris shores).

    Fallback: explicit rmPlacePlayer literal coordinates, first concrete
    pair per player, only when players 1..n are all present (Civil War's
    2-player branch). None when no form exists. Positions are NOMINAL —
    variance/variation args are ignored."""
    import math

    def _n(v):
        return None if v is None or isinstance(v, Tainted) else float(v)

    def _is_circ(e):
        return (e.get("call") == "rmPlacePlayersCircular"
                and _n(e.get("min")) is not None and _n(e.get("max")) is not None)

    def _is_line(e):
        return (e.get("call") == "rmPlacePlayersLine"
                and all(_n(e.get(k)) is not None
                        for k in ("x1", "z1", "x2", "z2")))

    evs = [e for e in player_events if _is_circ(e) or _is_line(e)]
    if not evs:
        placed = {}
        for e in player_events:
            if e.get("call") != "rmPlacePlayer":
                continue
            p = e.get("player")
            x, z = _n(e.get("x")), _n(e.get("z"))
            if (p is not None and not isinstance(p, Tainted)
                    and x is not None and z is not None):
                placed.setdefault(int(p), (x, z))
        if all(k in placed for k in range(1, players + 1)):
            return [placed[k] for k in range(1, players + 1)]
        return None

    def _sec(ev):
        sec = ev.get("section")
        if sec and _n(sec[0]) is not None and _n(sec[1]) is not None:
            s0, s1 = float(sec[0]), float(sec[1])
        else:
            s0, s1 = 0.0, 1.0
        if s1 <= s0:
            s1 += 1.0
        return s0, s1

    def _pos(ev, idx, count):
        if ev.get("call") == "rmPlacePlayersCircular":
            r = (_n(ev.get("min")) + _n(ev.get("max"))) / 2.0
            s0, s1 = _sec(ev)
            th = 2.0 * math.pi * (s0 + (s1 - s0) * idx / max(1, count))
            return (0.5 + r * math.sin(th), 0.5 + r * math.cos(th))
        x1, z1 = _n(ev.get("x1")), _n(ev.get("z1"))
        x2, z2 = _n(ev.get("x2")), _n(ev.get("z2"))
        t = 0.5 if count <= 1 else idx / (count - 1.0)
        return (x1 + (x2 - x1) * t, z1 + (z2 - z1) * t)

    n = players
    n_teams = max(1, teams)
    team_evs = {}
    for e in evs:
        t = e.get("team")
        if t is not None and not isinstance(t, Tainted) and int(t) not in team_evs:
            team_evs[int(t)] = e
    out = []
    if len(team_evs) >= 2:
        members = {t: [k for k in range(n) if k * n_teams // n == t]
                   for t in range(n_teams)}
        for k in range(n):
            t = k * n_teams // n
            ev = team_evs.get(t, evs[0])
            mem = members[t]
            out.append(_pos(ev, mem.index(k), len(mem)))
        return out
    ev = evs[0]
    if ev.get("call") == "rmPlacePlayersCircular":
        # full/sectioned single ring: n equal slots, no endpoint doubling
        r = (_n(ev.get("min")) + _n(ev.get("max"))) / 2.0
        s0, s1 = _sec(ev)
        for k in range(n):
            th = 2.0 * math.pi * (s0 + (s1 - s0) * k / n)
            out.append((0.5 + r * math.sin(th), 0.5 + r * math.cos(th)))
        return out
    for k in range(n):
        out.append(_pos(ev, k, n))
    return out


class Extractor:
    def __init__(self, scenario: Scenario):
        self.sc = scenario
        self.res = Extraction(scenario)
        self.globals: Dict[str, Any] = {}
        self.scopes: List[Dict[str, Any]] = [self.globals]
        self.funcs: Dict[str, tuple] = {}
        self.next_handle = 1
        self.classes: Dict[int, str] = {}
        self.constraint_handles: Dict[int, str] = {}
        self.routes: Dict[int, bool] = {}
        self.variant_stack: List[str] = []
        self._pp_state: Dict[str, Any] = {"team": None, "section": None}
        # Literal-anchor rule for readbacks: last concrete placement anchor
        # per def handle, consumed by rmGetUnitPosition (the IW pirate-site
        # idiom places a controller at a literal loc, reads its position
        # back, and anchors an area there).
        self.def_last_anchor: Dict[int, Tuple[float, float]] = {}

    # -- helpers -------------------------------------------------------------

    def _new_handle(self) -> int:
        h = self.next_handle
        self.next_handle += 1
        return h

    def lookup(self, name: str) -> Any:
        for scope in reversed(self.scopes):
            if name in scope:
                return scope[name]
        # engine constants
        if name == "cNumberNonGaiaPlayers":
            return self.sc.players
        if name == "cNumberPlayers":
            return self.sc.players + 1
        if name == "cNumberTeams":
            return self.sc.teams
        if name.startswith("cElev") or name.startswith("cTech") or name.startswith("c"):
            return Tainted(name)
        self.res.warn(f"unknown variable {name!r}")
        return Tainted(name)

    def assign(self, name: str, value: Any) -> None:
        for scope in reversed(self.scopes):
            if name in scope:
                scope[name] = value
                return
        self.scopes[-1][name] = value

    # -- execution -----------------------------------------------------------

    def run(self, src: str) -> Extraction:
        ast = Parser(tokenize(strip_comments(src))).parse_program()
        main_def = None
        for item in ast:
            if item[0] == "func":
                self.funcs[item[2]] = item
                if item[2] == "main":
                    main_def = item
            elif item[0] == "include":
                pass  # helper includes are modeled by the whitelists
            else:
                self.exec_stmt(item)
        if main_def is None:
            raise ExtractError("no main() found")
        self.scopes.append({})
        try:
            for stmt in main_def[4]:
                self.exec_stmt(stmt)
        except _Return:
            pass
        self.scopes.pop()
        self._collapse()
        return self.res

    def exec_stmt(self, stmt: tuple) -> None:
        op = stmt[0]
        if op in ("nop",):
            return
        if op == "include":
            return
        if op == "decl":
            _, _type, name, expr, _line = stmt
            value = self.eval(expr) if expr is not None else _default(_type)
            self.scopes[-1][name] = value
            return
        if op == "assign":
            _, name, expr, _line = stmt
            self.assign(name, self.eval(expr))
            return
        if op == "expr":
            self.eval(stmt[1])
            return
        if op == "block":
            for s in stmt[1]:
                self.exec_stmt(s)
            return
        if op == "if":
            _, cond, then, els, line = stmt
            value = self.eval(cond)
            if isinstance(value, Tainted):
                # Fork: both arms as labeled variants, last write wins.
                self.variant_stack.append(f"{value.expr}@{line}:true")
                for s in then:
                    self.exec_stmt(s)
                self.variant_stack.pop()
                if els:
                    self.variant_stack.append(f"{value.expr}@{line}:false")
                    for s in els:
                        self.exec_stmt(s)
                    self.variant_stack.pop()
                return
            for s in (then if value else els):
                self.exec_stmt(s)
            return
        if op == "for":
            _, var, start, cmp_op, bound, body, line = stmt
            start_v = self.eval(start)
            bound_v = self.eval(bound)
            if isinstance(start_v, Tainted) or isinstance(bound_v, Tainted):
                self.res.warn(f"line {line}: for-loop bound is runtime-dependent; loop skipped")
                return
            i = int(start_v)
            end = int(bound_v)
            step = 1 if cmp_op in ("<", "<=") else -1
            conds = {"<": lambda v: v < end, "<=": lambda v: v <= end,
                     ">": lambda v: v > end, ">=": lambda v: v >= end}
            cond = conds.get(cmp_op)
            if cond is None:
                raise ExtractError(f"line {line}: unsupported for-loop "
                                   f"condition operator {cmp_op!r}")
            iterations = 0
            while cond(i):
                self.assign(var, i)
                try:
                    for s in body:
                        self.exec_stmt(s)
                except _Break:
                    break
                i += step
                self.assign(var, i)
                iterations += 1
                if iterations > 5000:
                    raise ExtractError(f"line {line}: runaway loop")
            return
        if op == "break":
            raise _Break()
        if op == "return":
            raise _Return()
        raise ExtractError(f"unhandled statement {op!r}")

    # -- expression evaluation -----------------------------------------------

    def eval(self, expr: tuple) -> Any:
        op = expr[0]
        if op == "num":
            return expr[1]
        if op == "str":
            return expr[1]
        if op == "bool":
            return expr[1]
        if op == "var":
            return self.lookup(expr[1])
        if op == "neg":
            v = self.eval(expr[1])
            return Tainted(f"-{v.expr}") if isinstance(v, Tainted) else -v
        if op == "not":
            v = self.eval(expr[1])
            return Tainted(f"!{v.expr}") if isinstance(v, Tainted) else (not v)
        if op == "bin":
            return self._binop(expr[1], expr[2], expr[3])
        if op == "call":
            return self.call(expr[1], [self.eval(a) for a in expr[2]], expr[3])
        raise ExtractError(f"unhandled expression {op!r}")

    def _binop(self, op: str, a_expr: tuple, b_expr: tuple) -> Any:
        # short-circuit for && / || when the left side is concrete
        if op in ("&&", "||"):
            a = self.eval(a_expr)
            if not isinstance(a, Tainted):
                if op == "&&" and not a:
                    return False
                if op == "||" and a:
                    return True
                return self.eval(b_expr)
            b = self.eval(b_expr)
            if not isinstance(b, Tainted):
                if op == "&&" and not b:
                    return False
                if op == "||" and b:
                    return True
            return Tainted(f"({a!r} {op} {b_expr!r})")
        a = self.eval(a_expr)
        b = self.eval(b_expr)
        if isinstance(a, Tainted) or isinstance(b, Tainted):
            # literal-string + runtime -> keep the literal as str_prefix
            # (grouping variant refs like "maori_hawaii_0"+rand resolve
            # deterministically by prefix)
            prefix = None
            if op == "+":
                if isinstance(a, str):
                    prefix = a + (b.str_prefix or "")
                elif isinstance(a, Tainted) and a.str_prefix is not None:
                    prefix = a.str_prefix
            return Tainted(f"({a!r} {op} {b!r})", str_prefix=prefix)
        av = isinstance(a, tuple) and len(a) == 4 and a[0] == "vec"
        bv = isinstance(b, tuple) and len(b) == 4 and b[0] == "vec"
        if av or bv:
            if op == "+" and av and bv:
                return ("vec", a[1] + b[1], a[2] + b[2], a[3] + b[3])
            if op == "-" and av and bv:
                return ("vec", a[1] - b[1], a[2] - b[2], a[3] - b[3])
            if op == "*" and av and not bv:
                return ("vec", a[1] * b, a[2] * b, a[3] * b)
            if op == "*" and bv and not av:
                return ("vec", b[1] * a, b[2] * a, b[3] * a)
            if op == "/" and av and not bv and float(b) != 0.0:
                return ("vec", a[1] / b, a[2] / b, a[3] / b)
            return Tainted(f"vec {op}")
        if isinstance(a, tuple) or isinstance(b, tuple):
            # opaque handles (unit_of refs) in arithmetic: runtime-dependent
            return Tainted(f"({op} on handle)")
        if op == "+":
            if isinstance(a, str) or isinstance(b, str):
                return _to_str(a) + _to_str(b)
            return a + b
        if op == "-":
            return a - b
        if op == "*":
            return a * b
        if op == "/":
            return a / b
        if op == "%":
            # XS integer modulo (zpBalearicIslands:945 player parity)
            return int(a) % int(b)
        if op == "==":
            return a == b
        if op == "!=":
            return a != b
        if op == "<":
            return a < b
        if op == "<=":
            return a <= b
        if op == ">":
            return a > b
        if op == ">=":
            return a >= b
        raise ExtractError(f"unhandled operator {op!r}")

    # -- engine dispatch ------------------------------------------------------

    def call(self, name: str, args: List[Any], line: int) -> Any:
        res = self.res
        sc = self.sc

        if name in self.funcs:
            fdef = self.funcs[name]
            local: Dict[str, Any] = {}
            for idx, (pname, default) in enumerate(fdef[3]):
                local[pname] = args[idx] if idx < len(args) else (
                    self.eval(default) if default is not None else 0)
            self.scopes.append(local)
            try:
                for s in fdef[4]:
                    self.exec_stmt(s)
            except _Return:
                pass
            self.scopes.pop()
            return 0

        if name in NOOP_FUNCS or name in TRIGGER_FUNCS:
            return 0
        if name == "rmGetTradeRouteWayPoint":
            # Deterministic: the point at arc-length fraction t along the
            # AUTHORED route polyline, as a METERS vector (the engine's
            # return convention — callers wrap it in rmX/ZMetersToFraction).
            # This is the anchor chain for train stations / route sockets /
            # bridges (wwcanyon, bluemountains, civilwar): waypoint ->
            # stopper -> readback -> grouping. Nominal: the real route
            # snaps to 16 m blocks around this polyline.
            handle = args[0] if args else None
            t = args[1] if len(args) > 1 else None
            wps = res.route_waypoints.get(handle) if not isinstance(handle, Tainted) else None
            if (wps and not isinstance(t, Tainted) and t is not None
                    and res.map_size_x and res.map_size_z
                    and not any(isinstance(c, Tainted) for p_ in wps for c in p_)):
                import math as _m
                pts = [(float(x) * res.map_size_x, float(z) * res.map_size_z)
                       for x, z in wps]
                if len(pts) >= 2:
                    segs = list(zip(pts, pts[1:]))
                    L = sum(_m.hypot(x2 - x1, z2 - z1)
                            for (x1, z1), (x2, z2) in segs)
                    d = min(max(float(t), 0.0), 1.0) * L
                    for (x1, z1), (x2, z2) in segs:
                        sl = _m.hypot(x2 - x1, z2 - z1)
                        if d <= sl and sl > 0:
                            f = d / sl
                            return ("vec", x1 + (x2 - x1) * f, 0.0,
                                    z1 + (z2 - z1) * f)
                        d -= sl
                    return ("vec", pts[-1][0], 0.0, pts[-1][1])
            return Tainted("rmGetTradeRouteWayPoint(...)")

        if name in ("rmPlayerLocXFraction", "rmPlayerLocZFraction"):
            # Deterministic NOMINAL ring position for the player (the same
            # doctrine as loc_player areas) — unlocks per-player content
            # anchored on TC/player-loc readbacks (Cook Islands Maori
            # villages, starting trees). Tainted only when no placement
            # call has run yet or the player index is runtime/invalid.
            p = args[0] if args else None
            if not isinstance(p, Tainted) and p is not None:
                ring = ring_positions(res.player_events, sc.players, sc.teams)
                k = int(p)
                if ring is not None and 1 <= k <= len(ring):
                    x, z = ring[k - 1]
                    return x if name == "rmPlayerLocXFraction" else z
            return Tainted(f"{name}(...)")

        if name in TAINTED_FUNCS:
            return Tainted(f"{name}(...)")

        # --- XS math builtins ---
        if name == "sqrt":
            return _t(args[0], math.sqrt)
        if name == "abs":
            return _t(args[0], abs)
        if name == "pow":
            if isinstance(args[0], Tainted) or isinstance(args[1], Tainted):
                return Tainted("pow(...)")
            return math.pow(float(args[0]), float(args[1]))
        if name == "rmGetIsTreaty":
            return False
        if name == "rmRandInt":
            return Tainted(f"rmRandInt({args[0]},{args[1]})", lo=args[0], hi=args[1])
        if name == "rmRandFloat":
            return Tainted(f"rmRandFloat({args[0]},{args[1]})", lo=args[0], hi=args[1])
        if name in ("xsVectorGetX", "xsVectorGetY", "xsVectorGetZ"):
            v = args[0]
            if isinstance(v, tuple) and len(v) == 4 and v[0] == "vec":
                return float(v[{"xsVectorGetX": 1, "xsVectorGetY": 2,
                                "xsVectorGetZ": 3}[name]])
            src = v.expr if isinstance(v, Tainted) else repr(v)
            return Tainted(f"{name}({src})")
        if name == "xsVectorSet":
            if not any(isinstance(a, Tainted) for a in args[:3]):
                return ("vec", float(args[0]), float(args[1]), float(args[2]))
            return Tainted(f"xsVectorSet({args[0]},{args[1]},{args[2]})")
        if name in ("rmGetUnitPlacedOfPlayer", "rmGetUnitPlaced"):
            return ("unit_of", args[0])
        if name == "rmGetUnitPosition":
            ref = args[0]
            if isinstance(ref, tuple) and len(ref) == 2 and ref[0] == "unit_of":
                anchor = self.def_last_anchor.get(ref[1])
                if anchor is not None:
                    sx, sz = self._need_size()
                    return ("vec", anchor[0] * sx, 0.0, anchor[1] * sz)
            return Tainted("rmGetUnitPosition(...)")
        if name in ("xsArrayCreateInt", "xsArrayCreateFloat", "xsArrayCreateString"):
            return {"__array__": [args[1]] * int(args[0]) if not isinstance(args[0], Tainted) else []}
        if name in ("xsArraySetInt", "xsArraySetFloat", "xsArraySetString"):
            arr, idx, value = args
            if isinstance(arr, dict) and not isinstance(idx, Tainted):
                lst = arr["__array__"]
                while len(lst) <= int(idx):
                    lst.append(0)
                lst[int(idx)] = value
            return 0
        if name in ("xsArrayGetInt", "xsArrayGetFloat", "xsArrayGetString"):
            arr, idx = args
            if isinstance(arr, dict) and not isinstance(idx, Tainted):
                lst = arr["__array__"]
                if int(idx) < len(lst):
                    return lst[int(idx)]
            return Tainted("xsArrayGet(...)")

        # --- scenario-resolved reads ---
        if name == "rmGetIsKOTH":
            return sc.koth
        if name == "rmGetPlayerTeam":
            # Deterministic team model: players alternate teams in lobby
            # order ((p-1) mod teams). Concrete so per-team placement
            # branches (fort slot counters) exercise BOTH shores.
            if isinstance(args[0], Tainted):
                return Tainted(f"rmGetPlayerTeam({args[0].expr})")
            return (int(args[0]) - 1) % max(1, sc.teams)
        if name == "rmGetNomadStart":
            return sc.nomad
        if name == "rmGetNumberPlayersOnTeam":
            t = args[0]
            if isinstance(t, Tainted):
                return Tainted("rmGetNumberPlayersOnTeam(?)")
            base = sc.players // sc.teams
            extra = sc.players % sc.teams
            return base + (1 if int(t) < extra else 0)
        if name == "rmAllocateSubCivs":
            return True
        if name == "rmGetCivID":
            return 100
        if name == "rmSetSubCivReplacement":
            return 0

        # --- map config ---
        if name == "rmSetMapSize":
            if isinstance(args[0], Tainted):
                raise ExtractError(f"line {line}: map size is runtime-dependent ({args[0]!r})")
            res.map_size_x = float(args[0])
            res.map_size_z = float(args[1] if len(args) > 1 else args[0])
            if res.map_size_x <= 0 or res.map_size_z <= 0:
                raise ExtractError(f"line {line}: non-positive map size {args!r} "
                                   "(a builtin the size formula uses may be unmodeled)")
            return 0
        if name == "rmSetSeaLevel":
            res.sea_level = float(args[0])
            return 0
        if name == "rmSetSeaType":
            if isinstance(args[0], Tainted):
                res.warn(f"line {line}: rmSetSeaType is runtime-dependent; "
                         "sea depth falls back to the default")
            else:
                res.sea_type = str(args[0])
            return 0
        if name == "rmTerrainInitialize":
            if isinstance(args[0], Tainted):
                res.warn(f"line {line}: rmTerrainInitialize terrain is "
                         "runtime-dependent; base terrain unknown")
            else:
                res.terrain_init = str(args[0])
            if len(args) > 1 and not isinstance(args[1], Tainted):
                res.terrain_init_height = float(args[1])
            return 0
        if name == "rmSetWorldCircleConstraint":
            res.world_circle = bool(args[0])
            return 0
        if name in ("rmGetMapXSize", "rmGetMapSizeX"):
            return self._need_size()[0]
        if name in ("rmGetMapZSize", "rmGetMapSizeZ"):
            return self._need_size()[1]

        # --- conversions (the eight foldable builtins) ---
        if name == "rmXTilesToFraction":
            return _t(args[0], lambda v: v * 2.0 / self._need_size()[0])
        if name == "rmZTilesToFraction":
            return _t(args[0], lambda v: v * 2.0 / self._need_size()[1])
        if name == "rmXMetersToFraction":
            return _t(args[0], lambda v: v / self._need_size()[0])
        if name == "rmZMetersToFraction":
            return _t(args[0], lambda v: v / self._need_size()[1])
        if name == "rmXFractionToMeters":
            return _t(args[0], lambda v: v * self._need_size()[0])
        if name == "rmZFractionToMeters":
            return _t(args[0], lambda v: v * self._need_size()[1])
        if name == "rmAreaTilesToFraction":
            sx, szz = self._need_size()
            return _t(args[0], lambda v: v / ((sx / 2.0) * (szz / 2.0)))
        if name == "rmDegreesToRadians":
            return _t(args[0], math.radians)

        # --- classes ---
        if name == "rmDefineClass":
            h = self._new_handle()
            self.classes[h] = args[0]
            return h
        if name == "rmClassID":
            for h, cname in self.classes.items():
                if cname == args[0]:
                    return h
            h = self._new_handle()
            self.classes[h] = args[0]
            return h
        if name in ("rmAddAreaToClass", "rmAddObjectDefToClass", "rmAddGroupingToClass"):
            target, cid = args[0], args[1]
            cname = self.classes.get(cid if not isinstance(cid, Tainted) else -1, "?")
            if name == "rmAddAreaToClass" and target in res.areas:
                res.areas[target].classes.append(cname)
            elif target in res.defs:
                res.defs[target].classes.append(cname)
            return 0

        # --- constraints ---
        if name in ("rmCreatePieConstraint", "rmCreateBoxConstraint",
                    "rmCreateTerrainDistanceConstraint",
                    "rmCreateTerrainMaxDistanceConstraint",
                    "rmCreateTypeDistanceConstraint",
                    "rmCreateClassDistanceConstraint",
                    "rmCreateTradeRouteDistanceConstraint"):
            # Display strings are not unique in real maps ("avoid town center"
            # appears twice on this one); uniquify so handles never collide.
            base = str(args[0])
            if base in res.constraints:
                args = [f"{base}#{line}"] + list(args[1:])

        if name == "rmCreatePieConstraint":
            h = self._new_handle()
            cname = args[0]
            self.constraint_handles[h] = cname
            res.constraints[cname] = {
                "kind": "pie", "center": [args[1], args[2]],
                "r_min_m": args[3], "r_max_m": args[4], "line": line,
            }
            return h
        if name == "rmCreateBoxConstraint":
            h = self._new_handle()
            cname = args[0]
            self.constraint_handles[h] = cname
            res.constraints[cname] = {"kind": "box", "box": args[1:5], "line": line}
            return h
        if name == "rmCreateTerrainDistanceConstraint":
            h = self._new_handle()
            cname = args[0]
            self.constraint_handles[h] = cname
            is_land_type = str(args[1]).lower() == "land"
            avoid_land = (bool(args[2]) == is_land_type)
            res.constraints[cname] = {
                "kind": "terrain", "avoid": "land" if avoid_land else "water",
                "distance_m": args[3], "line": line,
            }
            return h
        if name == "rmCreateTerrainMaxDistanceConstraint":
            h = self._new_handle()
            self.constraint_handles[h] = args[0]
            res.constraints[args[0]] = {"kind": "opaque", "desc": "terrain_max", "line": line}
            return h
        if name == "rmCreateTypeDistanceConstraint":
            h = self._new_handle()
            self.constraint_handles[h] = args[0]
            res.constraints[args[0]] = {
                "kind": "class_distance", "class": str(args[1]),
                "distance_m": args[2], "line": line,
            }
            return h
        if name == "rmCreateClassDistanceConstraint":
            h = self._new_handle()
            cid = args[1]
            cname_target = self.classes.get(cid if not isinstance(cid, Tainted) else -1, "?")
            self.constraint_handles[h] = args[0]
            res.constraints[args[0]] = {
                "kind": "class_distance", "class": cname_target,
                "distance_m": args[2], "line": line,
            }
            return h
        if name == "rmCreateTradeRouteDistanceConstraint":
            h = self._new_handle()
            self.constraint_handles[h] = args[0]
            res.constraints[args[0]] = {"kind": "route_distance", "distance_m": args[1], "line": line}
            return h
        if name == "rmConstraintID":
            for h, cname in self.constraint_handles.items():
                if cname == args[0]:
                    return h
            return Tainted(f"rmConstraintID({args[0]})")
        if name in ("rmCreateEdgeDistanceConstraint", "rmCreateCliffRampConstraint",
                    "rmCreateAreaDistanceConstraint", "rmCreateAreaConstraint",
                    "rmCreateAreaMaxDistanceConstraint", "rmCreateHCGPConstraint"):
            h = self._new_handle()
            self.constraint_handles[h] = str(args[0])
            res.constraints[str(args[0])] = {"kind": "opaque", "desc": name, "line": line}
            return h

        # --- areas ---
        if name == "rmCreateArea":
            h = self._new_handle()
            res.areas[h] = XArea(name=str(args[0]), line=line)
            return h
        if name == "rmSetAreaSize":
            a = res.areas.get(args[0])
            if a is not None:
                a.size_min_frac = args[1]
                a.size_max_frac = args[2] if len(args) > 2 else args[1]
            return 0
        if name == "rmSetAreaLocation":
            a = res.areas.get(args[0])
            if a is not None:
                a.x, a.z = args[1], args[2]
            return 0
        if name == "rmSetAreaBaseHeight":
            a = res.areas.get(args[0])
            if a is not None and not isinstance(args[1], Tainted):
                a.base_height = float(args[1])
            return 0
        if name == "rmSetAreaCoherence":
            a = res.areas.get(args[0])
            if a is not None and not isinstance(args[1], Tainted):
                a.coherence = float(args[1])
            return 0
        if name == "rmSetAreaSmoothDistance":
            a = res.areas.get(args[0])
            if a is not None and not isinstance(args[1], Tainted):
                a.smooth = float(args[1])
            return 0
        if name == "rmSetAreaObeyWorldCircleConstraint":
            a = res.areas.get(args[0])
            if a is not None:
                a.obey_world_circle = bool(args[1])
            return 0
        if name == "rmSetAreaHeightBlend":
            a = res.areas.get(args[0])
            if a is not None and not isinstance(args[1], Tainted):
                a.height_blend = float(args[1])
            return 0
        if name == "rmSetAreaLocPlayer":
            a = res.areas.get(args[0])
            if a is not None and not isinstance(args[1], Tainted):
                a.loc_player = int(args[1])
            return 0
        if name == "rmSetAreaLocTeam":
            a = res.areas.get(args[0])
            if a is not None and not isinstance(args[1], Tainted):
                a.loc_team = int(args[1])
            return 0
        if name == "rmSetPlayerArea":
            return 0
        if name == "rmSetAreaCliffType":
            a = res.areas.get(args[0])
            if a is not None:
                a.cliff_type = str(args[1])
            return 0
        if name == "rmSetAreaCliffHeight":
            a = res.areas.get(args[0])
            if a is not None:
                v = args[1]
                if isinstance(v, Tainted):
                    if v.lo is not None:      # rmRandInt(6,8): lower bound
                        a.cliff_height = float(v.lo)
                else:
                    a.cliff_height = float(v)
            return 0
        if name == "rmSetAreaWaterType":
            a = res.areas.get(args[0])
            if a is None:
                return 0
            if isinstance(args[1], Tainted):
                res.warn(f"line {line}: water type of area {a.name!r} is "
                         "runtime-dependent; the lake may render as land")
            else:
                a.water_type = str(args[1])
            return 0
        if name in ("rmSetAreaMix", "rmSetAreaTerrainType", "rmAddAreaTerrainLayer"):
            a = res.areas.get(args[0])
            if a is not None:
                a.has_paint = True
            return 0
        if name in ("rmSetAreaElevationType", "rmSetAreaElevationVariation",
                    "rmSetAreaElevationMinFrequency", "rmSetAreaElevationOctaves",
                    "rmSetAreaElevationPersistence", "rmSetAreaElevationNoiseBias",
                    "rmSetAreaElevationEdgeFalloffDist"):
            a = res.areas.get(args[0])
            if a is not None:
                a.has_elevation = True
            return 0
        if name == "rmAddAreaConstraint":
            a = res.areas.get(args[0])
            if a is not None:
                cname = self.constraint_handles.get(args[1], "?")
                a.constraints.append(cname)
            return 0
        if name == "rmAddAreaInfluenceSegment":
            a = res.areas.get(args[0])
            if a is not None:
                a.influence_segments.append((args[1], args[2], args[3], args[4]))
            return 0
        if name == "rmAddAreaInfluencePoint":
            a = res.areas.get(args[0])
            if a is not None:
                a.influence_segments.append((args[1], args[2], args[1], args[2]))
            return 0
        if name == "rmBuildArea":
            a = res.areas.get(args[0])
            if a is not None:
                a.built = True
            return True    # model policy: builds succeed; retry loops run full count
        if name == "rmAreaID":
            for h, a in res.areas.items():
                if a.name == args[0]:
                    return h
            return Tainted(f"rmAreaID({args[0]})")

        # --- rivers: painted water bands. rmRiverCreate(areaID, waterType,
        #     breaks, offset, minR, maxR). CALIBRATED 2026-08-09 from
        #     perpendicular pixel measurements on the minimaps: the args act
        #     as a HALF-WIDTH that the engine SATURATES around 27 m —
        #     riverina (15,15) measures 25-35 m wide, elbe (39,39) measures
        #     38-56 m, civil war (150,150) measures 40-70 m (NOT 300).
        #     width = 2 * min(avg(minR, maxR), RIVER_HALF_WIDTH_CAP_M).
        if name == "rmRiverCreate":
            h = self._new_handle()
            if len(args) > 5 and not isinstance(args[4], Tainted) \
                    and not isinstance(args[5], Tainted):
                half = (float(args[4]) + float(args[5])) / 2.0
            elif len(args) > 4 and not isinstance(args[4], Tainted):
                half = float(args[4])
            else:
                half = None
            width = (2.0 * min(half, RIVER_HALF_WIDTH_CAP_M)
                     if half is not None else Tainted("river width"))
            res.rivers[h] = XRiver(line=line, water_type=str(args[1]), width=width)
            return h
        if name == "rmRiverAddWaypoint":
            r = res.rivers.get(args[0])
            if r is not None:
                r.waypoints.append((args[1], args[2]))
            return 0
        if name == "rmRiverSetShallowRadius":
            r = res.rivers.get(args[0])
            if r is not None and not isinstance(args[1], Tainted):
                r.shallow_radius = float(args[1])
            return 0
        if name == "rmRiverAddShallow":
            r = res.rivers.get(args[0])
            if r is not None and not isinstance(args[1], Tainted):
                r.shallows.append(float(args[1]))
            return 0

        # --- connections: causeway bands between two areas ---
        if name == "rmCreateConnection":
            h = self._new_handle()
            res.connections[h] = XConnection(line=line)
            return h
        if name == "rmSetConnectionWidth":
            c = res.connections.get(args[0])
            if c is not None:
                c.width = args[1]
            return 0
        if name == "rmSetConnectionBaseHeight":
            c = res.connections.get(args[0])
            if c is not None and not isinstance(args[1], Tainted):
                c.base_height = float(args[1])
            return 0
        if name == "rmAddConnectionArea":
            c = res.connections.get(args[0])
            if c is not None:
                c.areas.append(args[1])
            return 0
        if name == "rmBuildConnection":
            c = res.connections.get(args[0])
            if c is not None:
                c.built = True
            return True

        # --- object defs / groupings ---
        if name in ("rmCreateObjectDef", "rmCreateStartingUnitsObjectDef"):
            h = self._new_handle()
            dname = str(args[0]) if name == "rmCreateObjectDef" else "startingUnits"
            res.defs[h] = XDef(name=dname, line=line)
            return h
        if name == "rmCreateGrouping":
            h = self._new_handle()
            res.defs[h] = XDef(name=str(args[0]), line=line, is_grouping=True, proto=args[1])
            return h
        if name == "rmAddObjectDefItem":
            d = res.defs.get(args[0])
            if d is not None:
                d.items.append((args[1], args[2]))
            return 0
        if name in ("rmSetObjectDefMinDistance", "rmSetGroupingMinDistance"):
            d = res.defs.get(args[0])
            if d is not None:
                d.min_dist = args[1]
            return 0
        if name in ("rmSetObjectDefMaxDistance", "rmSetGroupingMaxDistance"):
            d = res.defs.get(args[0])
            if d is not None:
                d.max_dist = args[1]
            return 0
        if name in ("rmAddObjectDefConstraint", "rmAddGroupingConstraint"):
            d = res.defs.get(args[0])
            if d is not None:
                d.constraints.append(self.constraint_handles.get(args[1], "?"))
            return 0
        if name == "rmSetObjectDefTradeRouteID":
            d = res.defs.get(args[0])
            if d is not None:
                d.route_docked = True
            return 0
        if name in ("rmPlaceObjectDefAtLoc", "rmPlaceGroupingAtLoc",
                    "rmPlaceGroupingInstanceAtLoc"):
            d = res.defs.get(args[0])
            if d is None:
                return 0
            # ARG-ORDER TRAP (guide-documented): the normal methods take
            # (id, player, x, z[, count]); the city-state instance variant
            # takes (id, x, z, player).
            if name == "rmPlaceGroupingInstanceAtLoc":
                player, x, z, count = (args[3] if len(args) > 3 else 0), args[1], args[2], 1
            else:
                player, x, z = args[1], args[2], args[3]
                count = args[4] if len(args) > 4 else 1
            if not isinstance(x, Tainted) and not isinstance(z, Tainted):
                self.def_last_anchor[args[0]] = (float(x), float(z))
            res.placements.append(XPlacement(
                def_line=d.line, name=d.name, kind="at_loc",
                players=[player], x=x, z=z, count=count,
                variant="|".join(self.variant_stack)))
            return 1
        if name in ("rmPlaceObjectDefInArea", "rmPlaceGroupingInArea"):
            # Third grouping placement method (user 2026-08-10): random
            # placement INSIDE an area — cookislands underwater patches,
            # melanesia villages. Same signature as the object-def form.
            d = res.defs.get(args[0])
            if d is None:
                return 0
            area_name = res.areas[args[2]].name if args[2] in res.areas else "?"
            count = args[3] if len(args) > 3 else 1
            res.placements.append(XPlacement(
                def_line=d.line, name=d.name, kind="in_area",
                players=[args[1]], area_refs=[area_name], count=count,
                variant="|".join(self.variant_stack)))
            return 1
        if name in ("rmPlaceObjectDefAtPoint", "rmPlaceGroupingAtPoint"):
            d = res.defs.get(args[0])
            if d is None:
                return 0
            vec = args[2]
            if isinstance(vec, tuple) and len(vec) == 4 and vec[0] == "vec":
                sx, sz = self._need_size()
                x, z = vec[1] / sx, vec[3] / sz
                self.def_last_anchor[args[0]] = (x, z)
            else:
                expr = vec.expr if isinstance(vec, Tainted) else repr(vec)
                x, z = Tainted(expr), Tainted(expr)
            res.placements.append(XPlacement(
                def_line=d.line, name=d.name, kind="at_point",
                players=[args[1]], x=x, z=z,
                count=args[3] if len(args) > 3 else 1,
                variant="|".join(self.variant_stack)))
            return 1

        # --- trade routes (per-handle: maps ship several separate routes) ---
        if name == "rmCreateTradeRoute":
            h = self._new_handle()
            self.routes[h] = False
            res.route_waypoints[h] = []
            return h
        if name == "rmAddTradeRouteWaypoint":
            res.waypoints.append((args[1], args[2]))
            if args[0] in res.route_waypoints:
                res.route_waypoints[args[0]].append((args[1], args[2]))
            return 0
        if name == "rmBuildTradeRoute":
            self.routes[args[0]] = True
            return True
        if name == "rmAddRandomTradeRouteWaypoints":
            self.res.warn("rmAddRandomTradeRouteWaypoints: waypoints are runtime-dependent")
            return 0

        # --- player placement ---
        if name == "rmSetTeamSpacingModifier":
            res.player_events.append({"call": name, "args": args,
                                      "variant": "|".join(self.variant_stack)})
            return 0
        if name == "rmSetPlacementTeam":
            self._pp_state["team"] = args[0]
            return 0
        if name == "rmSetPlacementSection":
            self._pp_state["section"] = [args[0], args[1]]
            return 0
        if name == "rmPlacePlayersCircular":
            res.player_events.append({
                "call": name, "min": args[0],
                "max": args[1] if len(args) > 1 else args[0],
                "variance": args[2] if len(args) > 2 else 0.0,
                "team": self._pp_state["team"], "section": self._pp_state["section"],
                "variant": "|".join(self.variant_stack)})
            return 0
        if name == "rmPlacePlayer":
            res.player_events.append({
                "call": name, "player": args[0], "x": args[1], "z": args[2],
                "variant": "|".join(self.variant_stack)})
            return 0
        if name == "rmPlacePlayersLine":
            # (x1, z1, x2, z2[, distVariation, spacingVariation]) — the
            # variations are noise around the line; nominal ignores them.
            res.player_events.append({
                "call": name,
                "x1": args[0], "z1": args[1], "x2": args[2], "z2": args[3],
                "team": self._pp_state["team"],
                "variant": "|".join(self.variant_stack)})
            return 0
        if name in ("rmPlacePlayersSquare", "rmPlacePlayersRiver"):
            res.player_events.append({"call": name, "args": args,
                                      "variant": "|".join(self.variant_stack)})
            return 0

        self.res.warn(f"unknown function {name!r} (line {line})")
        return 0

    def _need_size(self) -> Tuple[float, float]:
        if self.res.map_size_x is None:
            raise ExtractError("conversion used before rmSetMapSize")
        return self.res.map_size_x, self.res.map_size_z

    # -- postprocessing -------------------------------------------------------

    def _collapse(self) -> None:
        """Collapse loop-generated areas ('westforest0'..'westforest51') into
        one record with a count, and per-player placements into one record."""
        res = self.res
        groups: Dict[Tuple, List[int]] = {}
        for h, a in res.areas.items():
            if a.x is not None:
                continue    # located areas are individuals, never collapsed
            m = re.match(r"^(.*?)[ ]?(\d+)$", a.name)
            prefix = m.group(1) if m else a.name
            key = (prefix, repr(a.size_min_frac), a.base_height,
                   a.coherence, a.cliff_type, a.water_type,
                   a.loc_player, a.loc_team)
            groups.setdefault(key, []).append(h)
        for key, handles in groups.items():
            if len(handles) > 2:
                keep = res.areas[handles[0]]
                keep.name = key[0]
                keep.count = len(handles)
                for h in handles[1:]:
                    del res.areas[h]
                # Connections referencing a collapsed member must follow the
                # kept handle (Hawaii links its volcano rings/bonus islets in
                # a loop — dangling handles silently dropped 6 causeways).
                for c in res.connections.values():
                    c.areas = [handles[0] if h in handles[1:] else h
                               for h in c.areas]

        # Same def placed repeatedly merges into one record ONLY when the
        # anchors agree (per-player TCLoc-style runtime anchors, or identical
        # literals like the deer-herd loop). Distinct literal coordinates are
        # distinct placements — the fort slot table places one grouping def at
        # four different spots and every spot must survive for checks/render
        # (the old name-only merge hid three of the four forts).
        def _coord_key(p: XPlacement):
            literal = (p.x is not None and not isinstance(p.x, Tainted)
                       and not isinstance(p.z, Tainted))
            if literal:
                return (round(float(p.x), 6), round(float(p.z), 6))
            return "runtime"

        merged: Dict[Tuple, XPlacement] = {}
        out: List[XPlacement] = []
        for p in res.placements:
            key = (p.def_line, p.kind, p.variant, _coord_key(p))
            if key in merged:
                prev = merged[key]
                prev.players.extend(p.players)
                for ref in p.area_refs:
                    if ref not in prev.area_refs:
                        prev.area_refs.append(ref)
            else:
                merged[key] = p
                out.append(p)
        seen_names: Dict[str, int] = {}
        for p in out:
            n = seen_names.get(p.name, 0) + 1
            seen_names[p.name] = n
            if n > 1:
                p.name = f"{p.name} [{n}]"
        res.placements = out


def _default(_type: str) -> Any:
    return {"int": 0, "float": 0.0, "string": "", "bool": False}.get(_type, Tainted("uninit"))


def _to_str(v: Any) -> str:
    if isinstance(v, float) and v.is_integer():
        return str(int(v))
    return str(v)


def _t(v: Any, fn) -> Any:
    if isinstance(v, Tainted):
        return Tainted(f"conv({v.expr})")
    return fn(float(v))


def extract(path: Path | str, scenario: Scenario) -> Extraction:
    src = Path(path).read_text(encoding="utf-8", errors="replace")
    return Extractor(scenario).run(src)


# ---------------------------------------------------------------------------
# Golden diff (WP4 gate): extraction vs curated scene, keyed by source line.
#
# Compared: config, every area's location/size/height/coherence/smooth/
# world-circle flag/cliff/count, every placement's kind/anchor/distances/
# route-docking/constraint lines/counts, waypoint lists, constraint params.
# Skipped (curation semantics, not statically derivable): terrain_affinity,
# category, approx anchors, class-name normalization, closest-point constraint
# lists (pushed via rmAddClosestPointConstraint, not stored on the def).
# ---------------------------------------------------------------------------

def _close(a: float, b: float) -> bool:
    return abs(a - b) <= max(1e-9, 1e-9 * max(abs(a), abs(b)))


def diff_vs_scene(ex: Extraction, scene, sc: Scenario) -> List[str]:
    issues: List[str] = []
    rs = scene.resolve(sc)
    grid = rs.grid

    if ex.map_size_x is None or not _close(ex.map_size_x, grid.size_x_m):
        issues.append(f"config: map size {ex.map_size_x} != {grid.size_x_m}")
    if ex.sea_level is None or not _close(ex.sea_level, rs.sea_level):
        issues.append(f"config: sea level {ex.sea_level} != {rs.sea_level}")
    if ex.world_circle != rs.world_circle:
        issues.append("config: world-circle flag differs")
    from scripts.mapsim.waterdata import is_water_type_name
    ex_base_water = ex.terrain_init is None or is_water_type_name(ex.terrain_init)
    if ex_base_water != rs.base_is_water:
        issues.append(f"config: base terrain {ex.terrain_init!r} resolves "
                      f"water={ex_base_water} != curated {rs.base_is_water}")
    if (ex.sea_type or None) != (rs.sea_type or None) and rs.sea_type is not None:
        issues.append(f"config: sea type {ex.sea_type} != {rs.sea_type}")

    # -- areas --
    ex_areas = {a.line: a for a in ex.areas.values()}
    for ca in rs.areas:
        xa = ex_areas.get(ca.line)
        if xa is None:
            issues.append(f"area {ca.name} (line {ca.line}): not extracted")
            continue
        if ca.engine_placed:
            if xa.x is not None:
                issues.append(f"area {ca.name}: curated engine_placed but extracted has a location")
            if xa.count != ca.count:
                issues.append(f"area {ca.name}: loop count {xa.count} != {ca.count}")
        elif isinstance(xa.x, Tainted) or isinstance(xa.z, Tainted):
            pass  # runtime-derived location (pirate sites): curation adds the literal anchor
        elif xa.x is None:
            issues.append(f"area {ca.name}: no location extracted")
        else:
            if not _close(xa.x, ca.x) or not _close(xa.z, ca.z):
                issues.append(f"area {ca.name}: loc ({xa.x},{xa.z}) != ({ca.x},{ca.z})")
        if xa.size_max_frac is not None and not isinstance(xa.size_max_frac, Tainted):
            r = grid.area_frac_to_radius_m(float(xa.size_max_frac))
            if not _close(r, ca.radius_m):
                issues.append(f"area {ca.name}: radius {r:.3f} != {ca.radius_m:.3f}")
            r_min = grid.area_frac_to_radius_m(float(xa.size_min_frac))
            if not _close(r_min, ca.radius_min_m):
                issues.append(f"area {ca.name}: min radius {r_min:.3f} != {ca.radius_min_m:.3f}")
        for label, xv, cv in (("base_height", xa.base_height, ca.base_height),
                              ("coherence", xa.coherence, ca.coherence),
                              ("smooth", xa.smooth, ca.smooth_distance)):
            if cv is None and xv is None:
                continue
            if (cv is None) != (xv is None) or (cv is not None and not _close(float(xv), float(cv))):
                issues.append(f"area {ca.name}: {label} {xv} != {cv}")
        if xa.obey_world_circle != ca.obey_world_circle:
            issues.append(f"area {ca.name}: obey_world_circle {xa.obey_world_circle} != {ca.obey_world_circle}")
        if (xa.cliff_type or None) != (ca.cliff_type or None):
            issues.append(f"area {ca.name}: cliff {xa.cliff_type} != {ca.cliff_type}")
        if (xa.water_type or None) != (ca.water_type or None):
            issues.append(f"area {ca.name}: water {xa.water_type} != {ca.water_type}")
    curated_lines = {a.line for a in rs.areas}
    for line, xa in ex_areas.items():
        if line not in curated_lines:
            issues.append(f"extra extracted area {xa.name} (line {line}) missing from curated scene")

    # -- placements --
    ex_defs = {d.line: d for d in ex.defs.values()}
    ex_place: Dict[int, List[XPlacement]] = {}
    for p in ex.placements:
        ex_place.setdefault(p.def_line, []).append(p)

    for cp in rs.placements:
        if not cp.active:
            if cp.line in ex_place:
                issues.append(f"{cp.name}: placed in extraction but mode-gated off in curated scene")
            continue
        xd = ex_defs.get(cp.line)
        if xd is None:
            if cp.proto.startswith("("):
                continue  # curation pseudo-entry for a helper call (ypMonasteryBuilder)
            issues.append(f"placement {cp.name} (line {cp.line}): def not extracted")
            continue
        plist = ex_place.get(cp.line, [])
        if not plist:
            issues.append(f"placement {cp.name}: def exists but never placed")
            continue
        p0 = plist[0]
        if cp.kind == "in_area":
            if p0.kind != "in_area" or set(p0.area_refs) != set(cp.area_refs):
                issues.append(f"{cp.name}: in_area refs {p0.area_refs} != {cp.area_refs}")
        elif cp.kind in ("at_loc", "grouping_at_loc"):
            if cp.runtime_expr is not None:
                if not isinstance(p0.x, Tainted):
                    # The vector-readback rule resolves anchors the curation
                    # recorded as runtime-with-approx: accept when the
                    # concrete value matches the curated approx anchor.
                    if cp.x is None or not (_close(p0.x, cp.x) and _close(p0.z, cp.z)):
                        issues.append(f"{cp.name}: concrete anchor "
                                      f"({p0.x},{p0.z}) != curated approx "
                                      f"({cp.x},{cp.z})")
            elif isinstance(p0.x, Tainted) or isinstance(p0.z, Tainted):
                issues.append(f"{cp.name}: extracted anchor tainted but curated is literal")
            elif not (_close(p0.x, cp.x) and _close(p0.z, cp.z)):
                issues.append(f"{cp.name}: anchor ({p0.x},{p0.z}) != ({cp.x},{cp.z})")
        elif cp.kind == "at_point_runtime":
            if p0.kind != "at_point":
                issues.append(f"{cp.name}: expected at_point, got {p0.kind}")
        elif cp.kind == "closest_point":
            if not isinstance(p0.x, Tainted):
                issues.append(f"{cp.name}: closest-point anchor should be runtime-dependent")
        elif cp.kind == "player_loop":
            # Some per-player defs place FOR gaia (player arg 0) inside the
            # loop, so count placement calls, not distinct player ids.
            calls = sum(len(pp.players) for pp in plist)
            if calls < sc.players:
                issues.append(f"{cp.name}: {calls} placement calls, expected >= {sc.players}")
        for label, cv, xv in (("min_dist", cp.min_dist_m, xd.min_dist),
                              ("max_dist", cp.max_dist_m, xd.max_dist)):
            if isinstance(xv, Tainted):
                continue
            if not _close(float(xv), cv):
                issues.append(f"{cp.name}: {label} {xv} != {cv}")
        if xd.route_docked != cp.route_docked:
            issues.append(f"{cp.name}: route_docked {xd.route_docked} != {cp.route_docked}")
        if cp.kind != "closest_point":
            cur_lines = {rs.constraints[n]["line"] for n in cp.constraints
                         if n in rs.constraints and "line" in rs.constraints[n]}
            got_lines = {ex.constraints[n]["line"] for n in xd.constraints
                         if n in ex.constraints}
            if cur_lines - got_lines:
                issues.append(f"{cp.name}: missing constraint lines {sorted(cur_lines - got_lines)}")
        if cp.count != 1:
            candidates = set()
            if not isinstance(p0.count, Tainted):
                candidates.add(int(p0.count))
            for proto, n in xd.items:
                if isinstance(n, Tainted):
                    if n.hi is not None:
                        candidates.add(int(n.hi))
                else:
                    candidates.add(int(n))
            if cp.count not in candidates:
                issues.append(f"{cp.name}: count {cp.count} not among extracted {sorted(candidates)}")

    active_lines = {cp.line for cp in rs.placements if cp.active}
    for line, plist in ex_place.items():
        if line not in {cp.line for cp in rs.placements}:
            issues.append(f"extra extracted placement {plist[0].name} (line {line})")

    # -- waypoints --
    ex_wp = [(float(x), float(z)) for x, z in ex.waypoints
             if not isinstance(x, Tainted) and not isinstance(z, Tainted)]
    if len(ex_wp) != len(rs.trade_route_waypoints) or any(
            not (_close(a[0], b[0]) and _close(a[1], b[1]))
            for a, b in zip(ex_wp, rs.trade_route_waypoints)):
        issues.append(f"waypoints {ex_wp} != {rs.trade_route_waypoints}")

    # -- constraint catalog (evaluable kinds, matched by definition line) --
    ex_by_line = {spec["line"]: (name, spec) for name, spec in ex.constraints.items()}
    from scripts.mapsim.scene import resolve_branch
    for cname, cspec in rs.constraints.items():
        kind = cspec.get("kind")
        if kind not in ("pie", "box", "terrain", "route_distance", "class_distance"):
            continue
        if not cspec.get("applied", True):
            continue
        hit = ex_by_line.get(cspec.get("line"))
        if hit is None:
            issues.append(f"constraint {cname}: line {cspec.get('line')} not extracted")
            continue
        xname, xspec = hit
        if xspec["kind"] != kind:
            issues.append(f"constraint {cname}: kind {xspec['kind']} != {kind}")
            continue
        if kind == "pie":
            for ckey, xkey in (("r_min", "r_min_m"), ("r_max", "r_max_m")):
                cv = float(resolve_branch(cspec[ckey], sc, grid))
                if not _close(float(xspec[xkey]), cv):
                    issues.append(f"constraint {cname}: {ckey} {xspec[xkey]} != {cv}")
        elif kind == "box":
            if any(not _close(float(a), float(b)) for a, b in zip(xspec["box"], cspec["box"])):
                issues.append(f"constraint {cname}: box {xspec['box']} != {cspec['box']}")
        elif kind == "terrain":
            if xspec["avoid"] != cspec["avoid"] or not _close(
                    float(xspec["distance_m"]), float(cspec["distance_m"])):
                issues.append(f"constraint {cname}: terrain {xspec} != {cspec}")
        elif kind in ("route_distance", "class_distance"):
            if not _close(float(xspec["distance_m"]), float(cspec["distance_m"])):
                issues.append(f"constraint {cname}: distance {xspec['distance_m']} != {cspec['distance_m']}")

    return issues
