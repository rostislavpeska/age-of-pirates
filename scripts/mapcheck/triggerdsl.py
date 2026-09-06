"""Parse an RM-script trigger block and simulate it the way the engine does.

The engine turns every rmCreateTrigger(...) block into an XS rule (see the
generated Trigger/trigtemp.xs):

    rule _Name  highFrequency  active|inactive  runImmediately
    {  bVar_i = <condition_i>;  if (bVar_0 && bVar_1 ...) {
         <effects in order>;  trEventFire(n) per "Fire Event";
         xsDisableRule("_Name")  when loop is off } }
    eventHandler(n): xsEnableRule("_Target")

So: conditions are ANDed, a fired rule disables itself unless it loops, and
"Fire Event" ENABLES the target rule (which then still waits for its own
condition). This module models exactly that and nothing more.

The parser reads the subset of the RM trigger DSL this repo's maps use:
plain calls, string/int concatenation with "+", and the one loop idiom
`for (v = 1; <= cNumberNonGaiaPlayers) { ... }`, unrolled for a player count
the caller chooses. Nothing else (no arithmetic, no if).
"""
from __future__ import annotations

import re
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple


# ----------------------------------------------------------------- data model
@dataclass
class Param:
    name: str
    value: Any                # int/float/str, or {"sym": "var"} / {"trigger": "Name"}
    kind: str                 # "str" | "int" | "float"


@dataclass
class Item:
    name: str
    params: List[Param] = field(default_factory=list)

    def get(self, pname: str, default=None):
        for p in self.params:
            if p.name == pname:
                return p.value
        return default


@dataclass
class Trigger:
    name: str
    conditions: List[Item] = field(default_factory=list)
    effects: List[Item] = field(default_factory=list)
    priority: Optional[int] = None
    active: Optional[bool] = None
    run_immediately: Optional[bool] = None
    loop: Optional[bool] = None
    lookups: List[str] = field(default_factory=list)


class DSLError(Exception):
    pass


# --------------------------------------------------------------------- parser
_STR = r'"((?:[^"\\]|\\.)*)"'
_CALL = re.compile(r'^\s*(rm\w+)\s*\((.*)\)\s*;\s*$')
_FOR = re.compile(r'^\s*for\s*\(\s*([A-Za-z_]\w*)\s*=\s*(\d+)\s*;\s*<=\s*cNumberNonGaiaPlayers\s*\)\s*$')


def _split_top(s: str, sep: str) -> List[str]:
    out, depth, cur, q = [], 0, [], False
    for ch in s:
        if ch == '"':
            q = not q
        if not q:
            if ch == '(':
                depth += 1
            elif ch == ')':
                depth -= 1
            elif ch == sep and depth == 0:
                out.append(''.join(cur).strip()); cur = []; continue
        cur.append(ch)
    tail = ''.join(cur).strip()
    if tail:
        out.append(tail)
    return out


def _eval(expr: str, env: Dict[str, int]):
    """Literal / concatenation / loop-var expression -> str | int | {"sym"}."""
    expr = expr.strip()
    m = re.fullmatch(r'rmTriggerID\((.*)\)', expr, re.S)
    if m:
        v = _eval(m.group(1), env)
        if not isinstance(v, str):
            raise DSLError(f"rmTriggerID needs a resolvable string: {expr!r}")
        return {"trigger": v}
    terms = _split_top(expr, '+')
    vals = []
    for t in terms:
        if re.fullmatch(_STR, t):
            vals.append(re.fullmatch(_STR, t).group(1))
        elif re.fullmatch(r'-?\d+', t):
            vals.append(int(t))
        elif re.fullmatch(r'-?\d+\.\d+', t):
            vals.append(float(t))
        elif t in ("true", "false"):
            vals.append(t == "true")
        elif re.fullmatch(r'[A-Za-z_]\w*', t):
            vals.append(env[t] if t in env else {"sym": t})
        else:
            raise DSLError(f"unsupported expression: {t!r} in {expr!r}")
    if len(vals) == 1:
        return vals[0]
    if len(vals) == 2 and vals[0] == "" and isinstance(vals[1], dict):
        return vals[1]                                   # ""+socketVar -> symbol
    if any(isinstance(v, dict) for v in vals):
        raise DSLError(f"symbol inside a concatenation cannot be resolved offline: {expr!r}")
    return "".join(str(int(v)) if isinstance(v, bool) is False and isinstance(v, int) else str(v) for v in vals)


def _unroll(lines: List[str], players: int, env: Dict[str, int]) -> List[str]:
    """Expand `for (v = a; <= cNumberNonGaiaPlayers) { body }` textually."""
    out, i = [], 0
    while i < len(lines):
        m = _FOR.match(lines[i])
        if not m:
            out.append(lines[i]); i += 1; continue
        var, start = m.group(1), int(m.group(2))
        j = i + 1
        while j < len(lines) and not lines[j].strip():
            j += 1
        if j >= len(lines) or lines[j].strip() != "{":
            raise DSLError("for-loop must be followed by '{' on its own line")
        depth, k = 0, j
        while k < len(lines):
            depth += lines[k].count("{") - lines[k].count("}")
            if depth == 0:
                break
            k += 1
        body = lines[j + 1:k]
        for v in range(start, players + 1):
            sub = [re.sub(r'\b%s\b' % re.escape(var), str(v), ln) for ln in body]
            out.extend(_unroll(sub, players, env))
        i = k + 1
    return out


def parse_block(text: str, begin: str, end: str, players: int = 2) -> List[Trigger]:
    """Triggers between the two marker comments, in creation order, with the
    player loops unrolled for `players` non-gaia players."""
    i, j = text.find(begin), text.find(end)
    if i < 0 or j < 0 or j < i:
        raise DSLError(f"markers not found: {begin!r} .. {end!r}")
    raw_lines = [ln.split("//", 1)[0].rstrip() for ln in text[i + len(begin):j].splitlines()]
    lines = _unroll(raw_lines, players, {})
    triggers: List[Trigger] = []
    byname: Dict[str, Trigger] = {}
    cur: Optional[Trigger] = None
    target: Optional[Item] = None
    for line in lines:
        line = line.strip()
        if not line:
            continue
        if re.match(r'^(for|while|if)\b', line) or line in ("{", "}"):
            raise DSLError(f"unsupported control flow in trigger block: {line!r}")
        m = _CALL.match(line)
        if not m:
            raise DSLError(f"not a trigger DSL call: {line!r}")
        fn, args = m.group(1), _split_top(m.group(2), ',')
        if fn == "rmCreateTrigger":
            name = _eval(args[0], {})
            if not isinstance(name, str):
                raise DSLError("rmCreateTrigger needs a string name")
            if name in byname:
                raise DSLError(f"trigger created twice: {name}")
            cur = Trigger(name); triggers.append(cur); byname[name] = cur; target = None
        elif fn == "rmSwitchToTrigger":
            v = _eval(args[0], {})
            if not isinstance(v, dict) or "trigger" not in v:
                raise DSLError(f"rmSwitchToTrigger must use rmTriggerID(...): {line!r}")
            key = v["trigger"]
            hit = [t for t in triggers if t.name.replace(" ", "_") == key]
            if not hit:
                raise DSLError(f"rmSwitchToTrigger to unknown trigger {key!r} (create with spaces, look up with underscores)")
            cur = hit[0]; cur.lookups.append(key); target = None
        elif cur is None:
            raise DSLError(f"{fn} before any rmCreateTrigger")
        elif fn == "rmAddTriggerCondition":
            target = Item(_eval(args[0], {})); cur.conditions.append(target)
        elif fn == "rmAddTriggerEffect":
            target = Item(_eval(args[0], {})); cur.effects.append(target)
        elif fn in ("rmSetTriggerConditionParam", "rmSetTriggerConditionParamInt", "rmSetTriggerConditionParamFloat",
                    "rmSetTriggerEffectParam", "rmSetTriggerEffectParamInt", "rmSetTriggerEffectParamFloat"):
            if target is None:
                raise DSLError(f"{fn} with no condition/effect selected")
            if ("Condition" in fn) != (target in cur.conditions):
                raise DSLError(f"{fn} applied to the wrong item kind on {cur.name}")
            kind = "int" if fn.endswith("Int") else "float" if fn.endswith("Float") else "str"
            val = _eval(args[1], {})
            if isinstance(val, dict) and "trigger" in val:
                # rmTriggerID is evaluated NOW, at generation time: a trigger that
                # is created later does not exist yet and the editor shows "(None)"
                if not any(t.name.replace(" ", "_") == val["trigger"] for t in triggers):
                    raise DSLError(f"{cur.name}: rmTriggerID({val['trigger']!r}) before that trigger is created "
                                   f"(create every trigger first, then fill them)")
            target.params.append(Param(_eval(args[0], {}), val, kind))
        elif fn == "rmSetTriggerPriority":
            cur.priority = int(args[0])
        elif fn == "rmSetTriggerActive":
            cur.active = args[0] == "true"
        elif fn == "rmSetTriggerRunImmediately":
            cur.run_immediately = args[0] == "true"
        elif fn == "rmSetTriggerLoop":
            cur.loop = args[0] == "true"
        else:
            raise DSLError(f"unsupported call in trigger block: {fn}")
    return triggers


# --------------------------------------------------------- triggerdata.xml
def load_triggerdata(path: Path) -> Dict[str, Dict[str, Dict[str, Any]]]:
    root = ET.fromstring(Path(path).read_bytes())
    out: Dict[str, Dict[str, Dict[str, Any]]] = {"condition": {}, "effect": {}}
    for kind in ("condition", "effect"):
        for el in root.iter(kind):
            name = el.get("name")
            if name:
                out[kind][name] = {"params": [p.get("name") for p in el.findall("param")],
                                   "expression": (el.findtext("expression") or "").strip()}
    return out


def check_against_triggerdata(triggers: List[Trigger], td) -> List[str]:
    errs = []
    for t in triggers:
        for kind, items in (("condition", t.conditions), ("effect", t.effects)):
            for it in items:
                spec = td[kind].get(it.name)
                if spec is None:
                    errs.append(f"{t.name}: unknown {kind} {it.name!r}"); continue
                for p in it.params:
                    if p.name not in spec["params"]:
                        errs.append(f"{t.name}: {kind} {it.name!r} has no param {p.name!r} (has {spec['params']})")
    return errs


# ------------------------------------------------------------------ simulator
class World:
    """gun[socket_symbol] = {player: count of zpAntiShipGun within range};
    suspended[socket_symbol] = AutoConvert suspend state."""

    def __init__(self, sockets):
        self.gun: Dict[str, Dict[int, int]] = {s: {} for s in sockets}
        self.suspended = {s: False for s in sockets}
        self.log: List[str] = []

    def any_gun(self, s: str) -> bool:
        return any(v > 0 for v in self.gun[s].values())


def _cmp(op: str, a: float, b: float) -> bool:
    return {">=": a >= b, "<=": a <= b, "==": a == b, "!=": a != b, ">": a > b, "<": a < b}[op]


def _cond_true(c: Item, w: World) -> bool:
    if c.name == "Units in Area":
        sym = c.get("DstObject")["sym"]
        if c.get("UnitType") != "zpAntiShipGun":
            raise DSLError(f"simulator only models zpAntiShipGun counts, got {c.get('UnitType')}")
        pl = c.get("Player")
        if not isinstance(pl, int):
            raise DSLError("Units in Area needs an integer Player after unrolling")
        return _cmp(c.get("Op"), w.gun[sym].get(pl, 0), float(c.get("Count")))
    if c.name == "Always":
        return True
    raise DSLError(f"simulator does not model condition {c.name!r}")


def _apply(e: Item, w: World, fire: List[str]):
    if e.name == "Unit Action Suspend":
        sym = e.get("SrcObject")["sym"]
        if e.get("ActionName") != "AutoConvert":
            raise DSLError("only AutoConvert suspends are modelled")
        w.suspended[sym] = str(e.get("Suspend")).lower() == "true"
        w.log.append(f"suspend {sym} {w.suspended[sym]}")
    elif e.name == "Fire Event":
        fire.append(e.get("EventID")["trigger"])
    else:
        raise DSLError(f"simulator does not model effect {e.name!r}")


class Sim:
    """Rules in priority order (higher first), creation order within.
    same_tick=False: a rule enabled by an event runs from the NEXT tick;
    same_tick=True: it may run later in the same tick."""

    def __init__(self, triggers: List[Trigger], world: World, same_tick=False):
        self.rules = sorted(triggers, key=lambda t: -(t.priority or 0))
        self.enabled = {t.name: bool(t.active) for t in triggers}
        self.world = world
        self.same_tick = same_tick
        self.fired: List[Tuple[int, str]] = []
        self.tick_no = 0
        self._names = {t.name.replace(" ", "_"): t.name for t in triggers}

    def tick(self):
        pending: List[str] = []
        for r in self.rules:
            if not self.enabled[r.name]:
                continue
            if all(_cond_true(c, self.world) for c in r.conditions):
                fire: List[str] = []
                for e in r.effects:
                    _apply(e, self.world, fire)
                if not r.loop:
                    self.enabled[r.name] = False
                self.fired.append((self.tick_no, r.name))
                for key in fire:
                    if key not in self._names:
                        raise DSLError(f"Fire Event to unknown trigger {key}")
                    if self.same_tick:
                        self.enabled[self._names[key]] = True
                    else:
                        pending.append(self._names[key])
        for n in pending:
            self.enabled[n] = True
        self.tick_no += 1

    def settle(self, n=4):
        for _ in range(n):
            self.tick()
