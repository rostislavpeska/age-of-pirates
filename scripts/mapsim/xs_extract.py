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
    """Runtime-dependent value; propagates through arithmetic and concat."""

    __slots__ = ("expr", "lo", "hi")

    def __init__(self, expr: str, lo: Optional[float] = None, hi: Optional[float] = None):
        self.expr = expr
        self.lo = lo
        self.hi = hi

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
  | (?P<op>==|!=|<=|>=|&&|\|\||\+\+|--|[-+*/<>=!(){};,])
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
        self.expect("=")
        start = self.parse_expr()
        self.expect(";")
        # shorthand: `< bound` / `<= bound`; C-style: `i < bound; i++`
        if self.peek()[1] in ("<", "<="):
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
        while self.peek()[1] in ("*", "/"):
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


@dataclass
class Extraction:
    scenario: Scenario
    map_size_x: Optional[float] = None
    map_size_z: Optional[float] = None
    sea_level: Optional[float] = None
    world_circle: bool = False
    areas: Dict[int, XArea] = dfield(default_factory=dict)          # by handle
    defs: Dict[int, XDef] = dfield(default_factory=dict)
    placements: List[XPlacement] = dfield(default_factory=list)
    waypoints: List[Tuple[Any, Any]] = dfield(default_factory=list)
    route_waypoints: Dict[int, List[Tuple[Any, Any]]] = dfield(default_factory=dict)
    rivers: Dict[int, "XRiver"] = dfield(default_factory=dict)
    constraints: Dict[str, Dict[str, Any]] = dfield(default_factory=dict)
    player_events: List[Dict[str, Any]] = dfield(default_factory=list)
    warnings: List[str] = dfield(default_factory=list)

    def warn(self, msg: str) -> None:
        if msg not in self.warnings:
            self.warnings.append(msg)


class _Break(Exception):
    pass


class _Return(Exception):
    pass


# Config / cosmetic / trigger calls that are correct to ignore entirely.
NOOP_FUNCS = {
    "rmSetStatusText", "rmEchoInfo", "rmEchoError", "rmSetLightingSet",
    "rmSetSeaType", "rmSetMapType", "rmEnableLocalWater",
    "rmSetMapElevationParameters", "rmSetMapElevationHeightBlend",
    "rmTerrainInitialize", "rmSetWindMagnitude", "rmSetUnderbrushTree",
    "rmSetGlobalRain", "rmSetGlobalSnow", "rmSetMapElevationOctaves",
    "rmSetAreaMix", "rmAddAreaTerrainLayer", "rmSetAreaTerrainType",
    "rmSetAreaElevationType", "rmSetAreaElevationVariation",
    "rmSetAreaElevationMinFrequency", "rmSetAreaElevationOctaves",
    "rmSetAreaElevationPersistence", "rmSetAreaElevationNoiseBias",
    "rmSetAreaHeightBlend", "rmSetAreaReveal", "rmSetAreaWarnFailure",
    "rmSetAreaForestType", "rmSetAreaForestDensity",
    "rmSetAreaForestClumpiness", "rmSetAreaForestUnderbrushDensity",
    "rmSetAreaForestUnderbrush",
    "rmSetAreaMinBlobs", "rmSetAreaMaxBlobs", "rmSetAreaMinBlobDistance",
    "rmSetAreaMaxBlobDistance", "rmAddAreaRemoveType", "rmAddAreaCliffEdge",
    "rmSetAreaCliffEdge", "rmSetAreaCliffHeight", "rmSetAreaCliffPainting",
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
    "rmRiverSetShallowRadius", "rmRiverAddShallow",
    "rmRiverAddShallows", "rmRiverSetBankPercent", "rmRiverSetConnections",
    "rmRiverBuild", "rmRiverReveal", "rmRiverSetFoundationTerrain",
    "rmSetTeamSpacing", "rmSetAreaWaterType",
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

# Runtime-only reads -> Tainted.
TAINTED_FUNCS = {
    "rmGetUnitPosition", "rmGetUnitPlacedOfPlayer", "rmGetUnitPlaced",
    "rmFindClosestPointVector", "rmGetTradeRouteWayPoint",
    "rmPlayerLocXFraction", "rmPlayerLocZFraction", "rmGetPlayerCiv",
    "rmGetPlayerName", "ypIsAsian",
    "rmGetNumberUnitsPlaced", "rmGetHomeCityLevel",
    "rmGetGroupingInstanceUnitByType",
}


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
            iterations = 0
            while (i < end) if cmp_op == "<" else (i <= end):
                self.assign(var, i)
                try:
                    for s in body:
                        self.exec_stmt(s)
                except _Break:
                    break
                i += 1
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
            return Tainted(f"({a!r} {op} {b!r})")
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
            src = args[0].expr if isinstance(args[0], Tainted) else repr(args[0])
            return Tainted(f"{name}({src})")
        if name == "xsVectorSet":
            return Tainted(f"xsVectorSet({args[0]},{args[1]},{args[2]})")
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
                    "rmCreateAreaMaxDistanceConstraint"):
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
        if name == "rmSetAreaCliffType":
            a = res.areas.get(args[0])
            if a is not None:
                a.cliff_type = str(args[1])
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

        # --- rivers: painted water bands. Official reference (rm_commands_
        #     reference.md:699): rmRiverCreate(areaID, waterType, breaks,
        #     offset, minR, maxR) — minR/maxR are RADII from the centerline
        #     in meters, so full width = minR + maxR. (guide v2:7400's
        #     "width, shallowWidth" reading is an erratum; the Elbe bridge
        #     geometry and the ground-truth band width both confirm radii.)
        if name == "rmRiverCreate":
            h = self._new_handle()
            if len(args) > 5 and not isinstance(args[4], Tainted) \
                    and not isinstance(args[5], Tainted):
                width = float(args[4]) + float(args[5])
            elif len(args) > 4 and not isinstance(args[4], Tainted):
                width = 2.0 * float(args[4])
            else:
                width = Tainted("river width")
            res.rivers[h] = XRiver(line=line, water_type=str(args[1]), width=width)
            return h
        if name == "rmRiverAddWaypoint":
            r = res.rivers.get(args[0])
            if r is not None:
                r.waypoints.append((args[1], args[2]))
            return 0

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
            res.placements.append(XPlacement(
                def_line=d.line, name=d.name, kind="at_loc",
                players=[player], x=x, z=z, count=count,
                variant="|".join(self.variant_stack)))
            return 1
        if name == "rmPlaceObjectDefInArea":
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
            expr = vec.expr if isinstance(vec, Tainted) else repr(vec)
            res.placements.append(XPlacement(
                def_line=d.line, name=d.name, kind="at_point",
                players=[args[1]], x=Tainted(expr), z=Tainted(expr),
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
                "call": name, "min": args[0], "max": args[1], "variance": args[2],
                "team": self._pp_state["team"], "section": self._pp_state["section"],
                "variant": "|".join(self.variant_stack)})
            return 0
        if name == "rmPlacePlayer":
            res.player_events.append({
                "call": name, "player": args[0], "x": args[1], "z": args[2],
                "variant": "|".join(self.variant_stack)})
            return 0
        if name in ("rmPlacePlayersSquare", "rmPlacePlayersLine", "rmPlacePlayersRiver"):
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
                   a.coherence, a.cliff_type)
            groups.setdefault(key, []).append(h)
        for key, handles in groups.items():
            if len(handles) > 2:
                keep = res.areas[handles[0]]
                keep.name = key[0]
                keep.count = len(handles)
                for h in handles[1:]:
                    del res.areas[h]

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
                    issues.append(f"{cp.name}: curated runtime anchor but extraction is concrete")
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
