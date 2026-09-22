"""Static checker for the game's compiled trigger script (<profile>\\Trigger\\trigtemp.xs).

The game rewrites trigtemp.xs on every random-map generation (editor and skirmish): one XS rule per
rmCreateTrigger, an eventHandler that maps "Fire Event" ids to xsEnableRule calls, and main() first.
This script reads that file (read-only) and reports what can be decided without playing:

    DEAD             trUnitSelect("...") - a unit parameter that was not a scenario index (select by NAME, no-op)
    GAIABUILD        trSocketBuild(0, ...) - a run-time socket build for gaia (no map in the mod does this)
    CYCLE            a Fire-Event cycle whose rules' conditions are not provably exclusive and carry no timer:
                     the rules can re-fire each other every frame (London's Towers_ON1 <-> Towers_ON2 flare)
    POLL             (info) the same kind of cycle throttled by a timer condition: a periodic re-check
    ALWAYS           an active, looping rule whose only condition is (true): runs every frame forever
    UNDEFINED        a fired event id with no handler case, or an enable target that is not a rule
    DISABLED-TARGET  trDisableTrigger(n) whose event id maps to no rule

    python trigtemp_check.py [path]            findings, one line each: KIND rule detail
    python trigtemp_check.py [path] --list     every rule: state, loop, condition summary, fired targets
    python trigtemp_check.py [path] --rule X   one rule verbatim (X with or without the leading _)

Exit 1 when any DEAD or CYCLE exists, else 0. Standard library only.
"""
from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List, Optional, Tuple

FAILING = ("DEAD", "CYCLE")

# the repo sits at <profile>/mods/local/<mod>; this file at <repo>/.claude/skills/rm-trigger-testing/scripts
REPO = Path(__file__).resolve().parents[4]
DEFAULT_PATH = REPO.parents[2] / "Trigger" / "trigtemp.xs"

RULE_HEAD = re.compile(r"^rule[ \t]+(\w+)[ \t]*\n((?:[ \t]*\w+(?:[ \t]+\w+)*[ \t]*\n)*?)[ \t]*\{", re.M)
BVAR = re.compile(r"^\s*bool\s+bVar(\d+)\s*=\s*\((.*)\);\s*$")
TEMPEXP = re.compile(r"^\s*bool\s+tempExp\s*=\s*\((.*)\);\s*$")
SELECT_BY_ID = re.compile(r"trUnitSelectByID\((\d+)\)")
CALL_INT = {k: re.compile(k + r"\((-?\d+)\)") for k in ("trEventFire", "trDisableTrigger")}
CALL_STR = {k: re.compile(k + r"\(\s*\"(\w+)\"\s*\)") for k in ("xsEnableRule", "xsDisableRule", "trDelayedRuleActivation")}
DEAD_SELECT = re.compile(r"trUnitSelect\(\s*\"[^\"]*\"\s*\)")
GAIA_BUILD = re.compile(r"trSocketBuild\(\s*0\s*,")
OWNED_BY = re.compile(r"^trUnitIsOwnedBy\((\d+)\)$")
NUMBER = re.compile(r"^-?\d+(?:\.\d+)?$")
CMP_OPS = (">=", "<=", "==", "!=", ">", "<")


@dataclass
class Cond:
    expr: str
    select: Optional[int] = None      # last trUnitSelectByID before it (the unit the condition reads)

    def summary(self) -> str:
        return f"{self.expr}@{self.select}" if self.select is not None and "trUnit" in self.expr else self.expr


@dataclass
class Rule:
    name: str
    line: int
    header: List[str]
    text: str
    conds: List[Cond] = field(default_factory=list)
    conj: bool = True                 # tempExp is a plain && of the bVars (else not analysable)
    effects: List[str] = field(default_factory=list)
    fires: List[int] = field(default_factory=list)
    enables: List[str] = field(default_factory=list)       # xsEnableRule / trDelayedRuleActivation in the body
    disables_rules: List[str] = field(default_factory=list)
    disables_events: List[int] = field(default_factory=list)

    @property
    def active(self) -> bool:
        return "active" in self.header

    @property
    def loop(self) -> bool:
        # a looping trigger compiles either without xsDisableRule(self), or as xsDisableRule(self) followed by
        # trDelayedRuleActivation(self) (re-armed for the next update; London's _Activate_Consulate_* rules)
        return self.name not in self.disables_rules or self.name in self.enables

    @property
    def real_conds(self) -> List[Cond]:
        return [c for c in self.conds if c.expr.strip() != "true"]

    @property
    def timed(self) -> bool:
        # a timer condition, or a minInterval header (the rule is evaluated at most every N seconds)
        return any("cActivationTime" in c.expr for c in self.conds) or "minInterval" in self.header


# ------------------------------------------------------------------ parsing
def _block(text: str, open_at: int) -> int:
    """Index just past the brace block that opens at text[open_at] == '{'."""
    depth = 0
    i = open_at
    in_str = False
    while i < len(text):
        ch = text[i]
        if in_str:
            if ch == "\\":
                i += 1
            elif ch == '"':
                in_str = False
        elif ch == '"':
            in_str = True
        elif ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return i + 1
        i += 1
    return len(text)


def parse_rules(text: str) -> Dict[str, Rule]:
    text = text.replace("\r\n", "\n")
    rules: Dict[str, Rule] = {}
    for m in RULE_HEAD.finditer(text):
        name = m.group(1)
        header = m.group(2).split()
        open_at = m.end() - 1
        end = _block(text, open_at)
        body = text[open_at:end]
        r = Rule(name=name, line=text.count("\n", 0, m.start()) + 1, header=header, text=text[m.start():end])
        _parse_body(r, body)
        rules[name] = r
    return rules


def _parse_body(r: Rule, body: str) -> None:
    lines = body.splitlines()
    sel: Optional[int] = None
    in_effects = False
    depth = 0
    for raw in lines:
        s = raw.strip()
        if not in_effects:
            if s.startswith("if (tempExp)"):
                in_effects = True
                depth = 0
                continue
            m = SELECT_BY_ID.search(s)
            if m:
                sel = int(m.group(1))
            b = BVAR.match(raw)
            if b:
                r.conds.append(Cond(b.group(2).strip(), sel))
            t = TEMPEXP.match(raw)
            if t:
                r.conj = "||" not in t.group(1)
            continue
        if s == "{":
            depth += 1
            continue
        if s == "}":
            depth -= 1
            if depth <= 0:
                in_effects = False
            continue
        if s:
            r.effects.append(s)
    for s in r.effects:
        for k, rx in CALL_INT.items():
            for v in rx.findall(s):
                (r.fires if k == "trEventFire" else r.disables_events).append(int(v))
        for k, rx in CALL_STR.items():
            for v in rx.findall(s):
                (r.disables_rules if k == "xsDisableRule" else r.enables).append(v)


def parse_handler(text: str) -> Dict[int, List[str]]:
    """eventHandler: case id -> the rules it enables."""
    text = text.replace("\r\n", "\n")
    i = text.find("void eventHandler")
    if i < 0:
        return {}
    open_at = text.find("{", i)
    block = text[open_at:_block(text, open_at)]
    out: Dict[int, List[str]] = {}
    parts = re.split(r"\bcase\s+(-?\d+)\s*:", block)
    for k in range(1, len(parts), 2):
        out[int(parts[k])] = CALL_STR["xsEnableRule"].findall(parts[k + 1])
    return out


# ------------------------------------------------------------- exclusivity
def _top_level_cmp(expr: str) -> Optional[Tuple[str, str, str]]:
    depth = 0
    in_str = False
    i = 0
    while i < len(expr):
        ch = expr[i]
        if in_str:
            if ch == '"':
                in_str = False
        elif ch == '"':
            in_str = True
        elif ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
        elif depth == 0:
            for op in CMP_OPS:
                if expr.startswith(op, i):
                    return expr[:i].strip(), op, expr[i + len(op):].strip()
        i += 1
    return None


def _interval(op: str, v: float):
    inf = float("inf")
    return {">=": (v, True, inf, False), ">": (v, False, inf, False),
            "<=": (-inf, False, v, True), "<": (-inf, False, v, False),
            "==": (v, True, v, True)}.get(op)


def _disjoint(a, b) -> bool:
    lo = max(a[0], b[0])
    hi = min(a[2], b[2])
    if lo > hi:
        return True
    if lo < hi:
        return False
    lo_in = (a[1] if a[0] == lo else True) and (b[1] if b[0] == lo else True)
    hi_in = (a[3] if a[2] == hi else True) and (b[3] if b[2] == hi else True)
    return not (lo_in and hi_in)


def atoms(r: Rule) -> List[Tuple]:
    """Facts a rule's condition asserts that another rule's condition can contradict. Timer conditions
    (cActivationTime is per rule) and anything under || assert nothing comparable."""
    if not r.conj:
        return []
    out = []
    for c in r.conds:
        e = c.expr.strip()
        if "cActivationTime" in e:
            continue
        m = OWNED_BY.match(e)
        if m and c.select is not None:
            out.append(("owner", c.select, int(m.group(1))))
            continue
        cmp_ = _top_level_cmp(e)
        if not cmp_:
            continue
        lhs, op, rhs = cmp_
        if NUMBER.match(rhs) and op != "!=":
            out.append(("num", lhs, _interval(op, float(rhs))))
        elif op == "==":
            out.append(("eq", lhs, rhs))
    return out


def exclusive(a: Rule, b: Rule) -> bool:
    for x in atoms(a):
        for y in atoms(b):
            if x[0] != y[0] or x[1] != y[1]:
                continue
            if x[0] in ("owner", "eq") and x[2] != y[2]:
                return True
            if x[0] == "num" and _disjoint(x[2], y[2]):
                return True
    return False


# ------------------------------------------------------------------ graph
def edges(rules: Dict[str, Rule], handler: Dict[int, List[str]]) -> Dict[str, List[str]]:
    g: Dict[str, List[str]] = {}
    for r in rules.values():
        tgt = []
        for ev in r.fires:
            tgt += handler.get(ev, [])
        tgt += [t for t in r.enables if t != r.name]      # self re-arming = the loop flag, not an edge
        g[r.name] = [t for t in dict.fromkeys(tgt) if t in rules]
    return g


def simple_cycles(g: Dict[str, List[str]], limit: int = 20000) -> List[List[str]]:
    """Elementary cycles, each once, rooted at its smallest node (small graphs; capped)."""
    order = sorted(g)
    rank = {n: i for i, n in enumerate(order)}
    found: List[List[str]] = []
    for start in order:
        stack = [(start, iter(g[start]))]
        path = [start]
        on_path = {start}
        while stack and len(found) < limit:
            node, it = stack[-1]
            nxt = next(it, None)
            if nxt is None:
                stack.pop()
                on_path.discard(path.pop())
                continue
            if nxt == start:
                found.append(list(path))
            elif nxt not in on_path and rank[nxt] > rank[start]:
                path.append(nxt)
                on_path.add(nxt)
                stack.append((nxt, iter(g[nxt])))
    return found


# --------------------------------------------------------------- findings
def check(text: str) -> List[Tuple[str, str, str]]:
    rules = parse_rules(text)
    handler = parse_handler(text)
    out: List[Tuple[str, str, str]] = []
    for r in rules.values():
        for s in DEAD_SELECT.findall(r.text):
            out.append(("DEAD", r.name, f"{s} (line {r.line}) - the unit parameter was not a scenario index"))
        for s in r.effects:
            if GAIA_BUILD.search(s):
                out.append(("GAIABUILD", r.name, s))
        if r.active and r.loop and not r.real_conds:
            out.append(("ALWAYS", r.name, "active, loops, condition (true) only - runs every frame"))
        for ev in r.fires:
            if ev not in handler:
                out.append(("UNDEFINED", r.name, f"trEventFire({ev}) has no eventHandler case"))
            else:
                for t in handler[ev]:
                    if t not in rules:
                        out.append(("UNDEFINED", r.name, f"trEventFire({ev}) -> {t} is not a rule"))
        for t in r.enables:
            if t not in rules:
                out.append(("UNDEFINED", r.name, f"enables {t}, which is not a rule"))
        for ev in r.disables_events:
            if not any(t in rules for t in handler.get(ev, [])):
                out.append(("DISABLED-TARGET", r.name, f"trDisableTrigger({ev}) maps to no rule"))
    g = edges(rules, handler)
    for cyc in simple_cycles(g):
        if any(exclusive(rules[a], rules[b]) for i, a in enumerate(cyc) for b in cyc[i + 1:]):
            continue
        ring = " -> ".join(cyc + [cyc[0]])
        conds = "; ".join(f"{n}: " + (" && ".join(c.summary() for c in rules[n].real_conds) or "true") for n in cyc)
        kind = "POLL" if any(rules[n].timed for n in cyc) else "CYCLE"
        out.append((kind, cyc[0], f"{ring}  [{conds}]"))
    return out


def list_rules(text: str) -> List[str]:
    rules = parse_rules(text)
    g = edges(rules, parse_handler(text))
    rows = []
    for r in rules.values():
        cond = " && ".join(c.summary() for c in r.real_conds) or "true"
        rows.append(f"{r.name}  {'active' if r.active else 'inactive'}  {'loop' if r.loop else 'once'}"
                    f"  if {cond}  -> {', '.join(g[r.name]) or '-'}")
    return rows


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("path", nargs="?", default=str(DEFAULT_PATH))
    ap.add_argument("--list", action="store_true")
    ap.add_argument("--rule")
    a = ap.parse_args(argv)
    p = Path(a.path)
    if not p.is_file():
        print(f"NOT FOUND {p}")
        return 2
    text = p.read_text(encoding="utf-8", errors="replace")
    if a.rule:
        name = a.rule if a.rule.startswith("_") else "_" + a.rule
        r = parse_rules(text).get(name)
        if not r:
            print(f"NO RULE {name}")
            return 2
        print(r.text)
        return 0
    if a.list:
        for row in list_rules(text):
            print(row)
        return 0
    found = check(text)
    for kind, rule, detail in found:
        print(f"{kind} {rule} {detail}")
    n_rules = len(parse_rules(text))
    bad = sum(1 for f in found if f[0] in FAILING)
    print(f"# {p}: {n_rules} rules, {len(parse_handler(text))} handler events, {len(found)} findings, {bad} failing")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
