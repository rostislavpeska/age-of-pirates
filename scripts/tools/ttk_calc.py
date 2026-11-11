#!/usr/bin/env python3
import argparse
import math
import os
import sys
import xml.etree.ElementTree as ET
from typing import Dict, List, Optional, Tuple

# Paths default relative to repository root (this script assumed to be run from repo root)
DEFAULT_PROTOMODS = os.path.join('data', 'protomods.xml')
DEFAULT_PROTOY = os.path.join('scripts', 'source', 'protoy.xml')

ARMOR_TYPES = {"Ranged", "Hand", "Siege"}

# Protoactions to ignore during auto-pick (still usable if explicitly forced via --attack-*)
SPACIAL_ABILITIES = {
    "BroadsideAttack",
}

class Attack:
    def __init__(self, name: str):
        self.name = name
        self.damage: float = 0.0
        self.rof: float = 1.5
        self.maxrange: float = 0.0
        self.minrange: float = 0.0
        self.damagetype: str = "Ranged"
        self.accuracy: Optional[float] = None
        self.projectiles: Optional[int] = None
        self.damagecap: Optional[float] = None
        self.damagearea: Optional[float] = None
        self.multipliers: Dict[str, float] = {}

    def __repr__(self) -> str:
        return f"Attack(name={self.name}, dmg={self.damage}, rof={self.rof}, rng={self.maxrange}, type={self.damagetype})"

class Unit:
    def __init__(self, name: str):
        self.name = name
        self.maxhp: float = 1.0
        self.armors: Dict[str, float] = {"Ranged": 0.0, "Hand": 0.0, "Siege": 0.0}
        self.unittype: List[str] = []
        self.attacks: List[Attack] = []
        self.maxvelocity: Optional[float] = None
        self.costs: Dict[str, float] = {}
        # Population-related fields for PopCoeficient
        self.populationcount: Optional[int] = None
        self.buildlimit: Optional[int] = None

    def resist_vs(self, damage_type: str) -> float:
        return self.armors.get(damage_type, 0.0)

    def has_class(self, clazz: str) -> bool:
        return clazz in self.unittype

    def best_attack(self, prefer_ranged: bool = True) -> Optional[Attack]:
        if not self.attacks:
            return None
        candidates = self.attacks
        if prefer_ranged:
            # Prefer attacks with maxrange > 0
            ranged = [a for a in candidates if a.maxrange and a.maxrange > 0]
            if ranged:
                # pick highest maxrange, then highest damage
                return sorted(ranged, key=lambda a: (a.maxrange, a.damage), reverse=True)[0]
        # fallback: highest damage per shot
        return sorted(candidates, key=lambda a: a.damage, reverse=True)[0]


def _maxrange(a: Attack) -> float:
    try:
        return float(a.maxrange or 0.0)
    except Exception:
        return 0.0


def _speed(u: Unit) -> float:
    return float(u.maxvelocity or 0.0)


def kiting_adjusted_ttks(ua: Unit, atk_a: Attack, ub: Unit, atk_b: Attack) -> Tuple[float, float, str]:
    """
    Returns (T_A_abs, T_B_abs, note) in seconds under a simple kiting model:
    - Longer-ranged unit starts at its maxrange and can fire immediately.
    - Shorter-ranged unit must close the range gap at relative speed.
    - If shorter-ranged speed <= longer-ranged speed, it never gets into range (TTK = inf).
    - While closing, the longer-ranged unit gets free opening shots; we count them explicitly.
    - After the shorter-ranged unit starts firing, both continue normal ROF cycles.
    """
    ra = _maxrange(atk_a)
    rb = _maxrange(atk_b)
    va = _speed(ua)
    vb = _speed(ub)

    # Base TTKs without kiting
    _, base_ttk_ab, _ = ttk(ua, atk_a, ub)
    _, base_ttk_ba, _ = ttk(ub, atk_b, ua)

    note = ""
    # If equal ranges, no kiting effect
    if abs(ra - rb) < 1e-9:
        return (base_ttk_ab, base_ttk_ba, note)

    # Identify which side has longer range
    if ra > rb:
        gap = ra - rb
        # If B cannot close, B never fires
        if vb <= va + 1e-9:
            note = f"Kiting: {ua.name} outranges and is not slower; {ub.name} never returns fire."
            # A needs normal time to kill; B's TTK is infinite
            return (base_ttk_ab, float('inf'), note)
        # Extra time before B can fire
        extra_time = gap / max(1e-9, (vb - va))
        # A gets free opening shots during [0, extra_time], including one at t=0
        ed_ab = effective_damage(ua, atk_a, ub)
        free_shots = 1 + int(extra_time // max(1e-9, atk_a.rof))
        damage_done = free_shots * ed_ab
        if damage_done >= ub.maxhp:
            t_kill_a = max(0.0, (free_shots - 1) * atk_a.rof)
        else:
            remaining = ub.maxhp - damage_done
            more_shots = math.ceil(remaining / max(1e-9, ed_ab))
            total_shots = free_shots + more_shots
            t_kill_a = max(0.0, (total_shots - 1) * atk_a.rof)
        # B's first shot occurs at extra_time; then needs its normal base TTK to finish A
        t_kill_b = extra_time + base_ttk_ba
        note = f"Kiting: {ua.name} outranges {ub.name} by {gap:.1f} and is slower by {(vb - va):.2f} m/s; free shots={free_shots}."
        return (t_kill_a, t_kill_b, note)
    else:
        gap = rb - ra
        if va <= vb + 1e-9:
            note = f"Kiting: {ub.name} outranges and is not slower; {ua.name} never returns fire."
            return (float('inf'), base_ttk_ba, note)
        extra_time = gap / max(1e-9, (va - vb))
        ed_ba = effective_damage(ub, atk_b, ua)
        free_shots = 1 + int(extra_time // max(1e-9, atk_b.rof))
        damage_done = free_shots * ed_ba
        if damage_done >= ua.maxhp:
            t_kill_b = max(0.0, (free_shots - 1) * atk_b.rof)
        else:
            remaining = ua.maxhp - damage_done
            more_shots = math.ceil(remaining / max(1e-9, ed_ba))
            total_shots = free_shots + more_shots
            t_kill_b = max(0.0, (total_shots - 1) * atk_b.rof)
        t_kill_a = extra_time + base_ttk_ab
        note = f"Kiting: {ub.name} outranges {ua.name} by {gap:.1f} and is slower by {(va - vb):.2f} m/s; free shots={free_shots}."
        return (t_kill_a, t_kill_b, note)


def first_fire_delay(attacker: Unit, atk_att: Attack, defender: Unit, atk_def: Attack, kiting: bool) -> float:
    """Time until attacker can land its first attack on defender.
    Without kiting: 0. With kiting: closing time if outranged and slower; inf if can never close."""
    if not kiting:
        return 0.0
    ra = _maxrange(atk_att)
    rb = _maxrange(atk_def)
    va = _speed(attacker)
    vb = _speed(defender)
    if ra >= rb:
        # Attacker has equal or longer range; can fire immediately
        return 0.0
    # Attacker has shorter range -> must close gap
    gap = rb - ra
    # Needs to be faster to close while the longer-ranged tries to maintain distance
    if va <= vb + 1e-9:
        return float('inf')
    return gap / max(1e-9, (va - vb))


def parse_unit(node: ET.Element) -> Unit:
    name = node.attrib.get('name', '')
    u = Unit(name)
    # HP
    hp_node = node.find('maxhitpoints')
    if hp_node is not None and hp_node.text:
        u.maxhp = float(hp_node.text)
    # Velocity (optional)
    vel_node = node.find('maxvelocity')
    if vel_node is not None and vel_node.text:
        try:
            u.maxvelocity = float(vel_node.text)
        except Exception:
            pass
    # Population/build limit for PopCoeficient
    pc_node = node.find('populationcount')
    if pc_node is not None and pc_node.text:
        try:
            u.populationcount = int(float(pc_node.text))
        except Exception:
            pass
    bl_node = node.find('buildlimit')
    if bl_node is not None and bl_node.text:
        try:
            u.buildlimit = int(float(bl_node.text))
        except Exception:
            pass
    # Armors
    for armor in node.findall('armor'):
        atype = armor.attrib.get('type')
        val = armor.attrib.get('value')
        if atype in ARMOR_TYPES and val is not None:
            try:
                u.armors[atype] = float(val)
            except Exception:
                pass
    # Unit classes
    for ut in node.findall('unittype'):
        if ut.text:
            u.unittype.append(ut.text.strip())
    # Costs
    for c in node.findall('cost'):
        rtype = c.attrib.get('resourcetype')
        if rtype and c.text:
            try:
                u.costs[rtype] = float(c.text)
            except Exception:
                pass
    # Protoactions
    for pa in node.findall('protoaction'):
        aname_node = pa.find('name')
        aname = aname_node.text.strip() if (aname_node is not None and aname_node.text) else 'Attack'
        atk = Attack(aname)
        # Basic fields
        def ffind(tag: str) -> Optional[float]:
            t = pa.find(tag)
            if t is not None and t.text:
                try:
                    return float(t.text)
                except Exception:
                    return None
            return None
        d = ffind('damage')
        if d is not None:
            atk.damage = d
        r = ffind('rof')
        if r is not None:
            atk.rof = r
        mx = ffind('maxrange')
        if mx is not None:
            atk.maxrange = mx
        mn = ffind('minrange')
        if mn is not None:
            atk.minrange = mn
        acc = ffind('accuracy')
        if acc is not None:
            atk.accuracy = acc
        proj = ffind('projectiles')
        if proj is not None:
            atk.projectiles = int(proj)
        cap = ffind('damagecap')
        if cap is not None:
            atk.damagecap = cap
        area = ffind('damagearea')
        if area is not None:
            atk.damagearea = area
        # damage type
        dt_node = pa.find('damagetype')
        if dt_node is not None and dt_node.text:
            atk.damagetype = dt_node.text.strip()
        # Multipliers
        for db in pa.findall('damagebonus'):
            dtype = db.attrib.get('type')
            if dtype and db.text:
                try:
                    atk.multipliers[dtype] = float(db.text)
                except Exception:
                    pass
        u.attacks.append(atk)
    return u


def iter_units(path: str):
    # Efficiently iterate over <unit> elements
    context = ET.iterparse(path, events=("start", "end"))
    _, root = next(context)  # get root
    for event, elem in context:
        if event == 'end' and elem.tag == 'unit':
            yield elem
            root.clear()


def load_units(paths: List[str]) -> Dict[str, Unit]:
    units: Dict[str, Unit] = {}
    for p in paths:
        if not os.path.isfile(p):
            continue
        try:
            for node in iter_units(p):
                name = node.attrib.get('name')
                if not name:
                    continue
                # Keep first-seen definition (protoy.xml is loaded first). If a duplicate unit
                # appears later (e.g., in protomods.xml), ignore it to avoid overriding base stats.
                if name in units:
                    continue
                u = parse_unit(node)
                units[name] = u
        except ET.ParseError as e:
            print(f"Warning: failed to parse {p}: {e}", file=sys.stderr)
    return units


def effective_damage(attacker: Unit, attack: Attack, defender: Unit) -> float:
    # Compute applicable multipliers
    mult = 1.0
    for dtype, value in attack.multipliers.items():
        # Apply if bonus type matches any defender unittype OR matches exact defender proto name
        if defender.has_class(dtype) or dtype == defender.name:
            mult *= value
    # Resist vs attack type
    resist = defender.resist_vs(attack.damagetype)
    acc = attack.accuracy if attack.accuracy is not None else 1.0
    proj = attack.projectiles if attack.projectiles is not None else 1
    ed = attack.damage * mult * (1.0 - resist) * acc * proj
    # Cap per shot if damagecap present
    if attack.damagecap is not None:
        ed = min(ed, attack.damagecap)
    return max(0.0, ed)


def ttk(attacker: Unit, attack: Attack, defender: Unit) -> Tuple[int, float, float]:
    ed = effective_damage(attacker, attack, defender)
    if ed <= 0:
        return (math.inf, math.inf, ed)
    shots = math.ceil(defender.maxhp / ed)
    time_sec = max(0.0, (shots - 1) * attack.rof)
    dps = ed / attack.rof if attack.rof > 0 else float('inf')
    return (shots, time_sec, dps)


def _attack_is_building_or_ship_only(attack_name: str) -> bool:
    # Heuristic: typical names used exclusively vs buildings/ships in proto files
    lower = attack_name.lower()
    return (
        'buildingattack' in lower or
        'antiship' in lower or
        'shipattack' in lower or
        lower == 'build'  # protoaction used for building actions
    )


def _defender_is_land_military(defender: Unit) -> bool:
    # Use common tags seen in protos
    return ('LogicalTypeLandMilitary' in defender.unittype) or ('Military' in defender.unittype)


def choose_attack_vs(attacker: Unit, defender: Unit, prefer_ranged: bool = True) -> Attack:
    # Prefer attack that can hit at range, otherwise highest damage per shot
    if not attacker.attacks:
        raise ValueError(f"Unit {attacker.name} has no attacks defined")
    candidates = attacker.attacks
    # Filter by having non-zero damage
    candidates = [a for a in candidates if a.damage > 0]
    # Exclude building/ship-only attacks when defender is a land military unit
    if _defender_is_land_military(defender):
        candidates = [a for a in candidates if not _attack_is_building_or_ship_only(a.name)]
    # Exclude special/ability-style attacks from auto-pick
    candidates = [a for a in candidates if a.name not in SPACIAL_ABILITIES]
    if not candidates:
        raise ValueError(f"Unit {attacker.name} has no damaging attacks")
    # Prefer ranged
    ranged = [a for a in candidates if (a.maxrange or 0) > 0]
    if prefer_ranged and ranged:
        # Pick one with highest effective range advantage; tie-break by higher damage per shot
        return sorted(ranged, key=lambda a: (a.maxrange, a.damage), reverse=True)[0]
    # Else pick highest damage per shot
    return sorted(candidates, key=lambda a: a.damage, reverse=True)[0]


def main():
    ap = argparse.ArgumentParser(description="Compute 1v1 TTK between two AoE3DE units using proto XMLs.")
    ap.add_argument('unit_a', help='Attacker A unit name (e.g., zpMercHussiteWagon)')
    ap.add_argument('unit_b', help='Attacker B unit name (e.g., zpSteamTank)')
    ap.add_argument('--protomods', default=DEFAULT_PROTOMODS, help='Path to data/protomods.xml')
    ap.add_argument('--protoy', default=DEFAULT_PROTOY, help='Path to scripts/source/protoy.xml')
    ap.add_argument('--attack-a', help='Force attack name for unit A (defaults to best ranged)')
    ap.add_argument('--attack-b', help='Force attack name for unit B (defaults to best ranged)')
    ap.add_argument('--show-attacks', action='store_true', help='List all parsed attacks for both units')
    ap.add_argument('--kiting', action='store_true', help='Enable simple kiting model using range and speed')
    args = ap.parse_args()

    search_paths = []
    # Base first, then overrides (later overrides earlier)
    if os.path.isfile(args.protoy):
        search_paths.append(args.protoy)
    if os.path.isfile(args.protomods):
        search_paths.append(args.protomods)

    if not search_paths:
        print("Error: could not find proto XMLs. Specify --protoy and/or --protomods.", file=sys.stderr)
        sys.exit(1)

    units = load_units(search_paths)

    if args.unit_a not in units:
        print(f"Error: unit '{args.unit_a}' not found in given XMLs", file=sys.stderr)
        sys.exit(1)
    if args.unit_b not in units:
        print(f"Error: unit '{args.unit_b}' not found in given XMLs", file=sys.stderr)
        sys.exit(1)

    ua = units[args.unit_a]
    ub = units[args.unit_b]

    # Select attacks
    if args.attack_a:
        atk_a = next((a for a in ua.attacks if a.name == args.attack_a), None)
        if atk_a is None:
            raise ValueError(f"Attack '{args.attack_a}' not found for unit {ua.name}")
    else:
        atk_a = choose_attack_vs(ua, ub)

    if args.attack_b:
        atk_b = next((a for a in ub.attacks if a.name == args.attack_b), None)
        if atk_b is None:
            raise ValueError(f"Attack '{args.attack_b}' not found for unit {ub.name}")
    else:
        atk_b = choose_attack_vs(ub, ua)

    if args.show_attacks:
        def list_attacks(u: Unit):
            print(f"\nAttacks for {u.name}:")
            for a in u.attacks:
                print(f"  - {a.name}: damage={a.damage}, rof={a.rof}, range={a.minrange}-{a.maxrange}, type={a.damagetype}, multipliers={a.multipliers}")
        list_attacks(ua)
        list_attacks(ub)

    # Compute both directions (base, no kiting)
    shots_ab, ttk_ab, dps_a = ttk(ua, atk_a, ub)
    shots_ba, ttk_ba, dps_b = ttk(ub, atk_b, ua)

    ed_ab = effective_damage(ua, atk_a, ub)
    ed_ba = effective_damage(ub, atk_b, ua)

    # Report
    print("\n=== 1v1 Combat Calculator ===")
    print(f"Source protoy: {args.protoy if os.path.isfile(args.protoy) else 'N/A'}")
    print(f"Source protomods: {args.protomods if os.path.isfile(args.protomods) else 'N/A'}")

    def armor_str(u: Unit):
        return f"Ranged={u.armors.get('Ranged',0):.2f}, Hand={u.armors.get('Hand',0):.2f}, Siege={u.armors.get('Siege',0):.2f}"

    print(f"\nUnit A: {ua.name}")
    print(f"  HP: {ua.maxhp:.1f}")
    print(f"  Armor: {armor_str(ua)}")
    print(f"  Classes: {', '.join(ua.unittype) if ua.unittype else '(none)'}")
    print(f"  Attack used: {atk_a.name} (damage={atk_a.damage}, rof={atk_a.rof}, range={atk_a.minrange}-{atk_a.maxrange}, type={atk_a.damagetype})")

    print(f"\nUnit B: {ub.name}")
    print(f"  HP: {ub.maxhp:.1f}")
    print(f"  Armor: {armor_str(ub)}")
    print(f"  Classes: {', '.join(ub.unittype) if ub.unittype else '(none)'}")
    print(f"  Attack used: {atk_b.name} (damage={atk_b.damage}, rof={atk_b.rof}, range={atk_b.minrange}-{atk_b.maxrange}, type={atk_b.damagetype})")

    print(f"\nA -> B: eff_dmg={ed_ab:.2f} per shot, shots={shots_ab}, TTK={ttk_ab:.2f}s, DPS={dps_a:.2f}")
    print(f"B -> A: eff_dmg={ed_ba:.2f} per shot, shots={shots_ba}, TTK={ttk_ba:.2f}s, DPS={dps_b:.2f}")

    # Kiting adjustment (optional)
    if args.kiting:
        tA, tB, note = kiting_adjusted_ttks(ua, atk_a, ub, atk_b)
        def fmt(x: float) -> str:
            return "inf" if not math.isfinite(x) else f"{x:.2f}s"
        print("\n[Kiting enabled]")
        print(f"  Adjusted TTKs: A kills B = {fmt(tA)}, B kills A = {fmt(tB)}")
        if note:
            print(f"  Note: {note}")
        # Override for winner selection below
        ttk_ab, ttk_ba = tA, tB

    if math.isfinite(ttk_ab) and math.isfinite(ttk_ba):
        if abs(ttk_ab - ttk_ba) < 1e-6:
            print("\nResult: Tie (simultaneous kill under this model)")
        elif ttk_ab < ttk_ba:
            margin = (ttk_ba - ttk_ab)
            print(f"\nResult: Winner = {ua.name} (kills faster by {margin:.2f}s)")
            # Winner HP left and how many losers needed
            delay_b = first_fire_delay(ub, atk_b, ua, atk_a, args.kiting)
            active_time_b = 0.0 if not math.isfinite(delay_b) else max(0.0, ttk_ab - delay_b)
            dmg_taken = dps_b * active_time_b
            hp_left = max(0.0, ua.maxhp - dmg_taken)
            pct = 100.0 * (hp_left / ua.maxhp) if ua.maxhp > 0 else 0.0
            print(f"  {ua.name} HP left ≈ {hp_left:.1f} ({pct:.1f}%)")
            # N losers to kill winner before first kill by winner
            if active_time_b <= 0 or dps_b <= 0:
                print(f"  Losers needed to kill {ua.name} before it kills one: infinite (no damage can be dealt in time)")
            else:
                n_needed = math.ceil(ua.maxhp / (dps_b * active_time_b))
                print(f"  Losers needed to kill {ua.name} before it kills one: {n_needed}")
            # Economic summary incl. PopCoeficient
            def pop_coef(u: Unit) -> float:
                if u.populationcount is not None and u.populationcount != 0:
                    return float(u.populationcount)
                if u.buildlimit is not None and u.buildlimit > 0:
                    return 16.0 / float(u.buildlimit)
                return 0.0

            def fmt_costs(costs: Dict[str, float], pop: float) -> str:
                food = costs.get('Food', 0.0)
                wood = costs.get('Wood', 0.0)
                gold = costs.get('Gold', 0.0)
                influence = costs.get('Influence', 0.0)
                return f"Food={food:.0f}, Wood={wood:.0f}, Gold={gold:.0f}, Influence={influence:.0f}, PopCoeficient={pop:.2f}"
            win_cost = ua.costs
            lose_cost = ub.costs
            print(f"  Winner cost ({ua.name}): {fmt_costs(win_cost, pop_coef(ua))}")
            if active_time_b <= 0 or dps_b <= 0:
                print(f"  Cost of losers to kill {ua.name}: infinite")
            else:
                total_loser_costs = {k: v * n_needed for k, v in lose_cost.items()}
                print(f"  Cost of losers to kill {ua.name}: {fmt_costs(total_loser_costs, pop_coef(ub) * n_needed)}")
        else:
            margin = (ttk_ab - ttk_ba)
            print(f"\nResult: Winner = {ub.name} (kills faster by {margin:.2f}s)")
            delay_a = first_fire_delay(ua, atk_a, ub, atk_b, args.kiting)
            active_time_a = 0.0 if not math.isfinite(delay_a) else max(0.0, ttk_ba - delay_a)
            dmg_taken = dps_a * active_time_a
            hp_left = max(0.0, ub.maxhp - dmg_taken)
            pct = 100.0 * (hp_left / ub.maxhp) if ub.maxhp > 0 else 0.0
            print(f"  {ub.name} HP left ≈ {hp_left:.1f} ({pct:.1f}%)")
            if active_time_a <= 0 or dps_a <= 0:
                print(f"  Losers needed to kill {ub.name} before it kills one: infinite (no damage can be dealt in time)")
            else:
                n_needed = math.ceil(ub.maxhp / (dps_a * active_time_a))
                print(f"  Losers needed to kill {ub.name} before it kills one: {n_needed}")
            # Economic summary incl. PopCoeficient
            def pop_coef(u: Unit) -> float:
                if u.populationcount is not None and u.populationcount != 0:
                    return float(u.populationcount)
                if u.buildlimit is not None and u.buildlimit > 0:
                    return 16.0 / float(u.buildlimit)
                return 0.0

            def fmt_costs(costs: Dict[str, float], pop: float) -> str:
                food = costs.get('Food', 0.0)
                wood = costs.get('Wood', 0.0)
                gold = costs.get('Gold', 0.0)
                influence = costs.get('Influence', 0.0)
                return f"Food={food:.0f}, Wood={wood:.0f}, Gold={gold:.0f}, Influence={influence:.0f}, PopCoeficient={pop:.2f}"
            win_cost = ub.costs
            lose_cost = ua.costs
            print(f"  Winner cost ({ub.name}): {fmt_costs(win_cost, pop_coef(ub))}")
            if active_time_a <= 0 or dps_a <= 0:
                print(f"  Cost of losers to kill {ub.name}: infinite")
            else:
                total_loser_costs = {k: v * n_needed for k, v in lose_cost.items()}
                print(f"  Cost of losers to kill {ub.name}: {fmt_costs(total_loser_costs, pop_coef(ua) * n_needed)}")
    else:
        if not math.isfinite(ttk_ab) and not math.isfinite(ttk_ba):
            print("\nResult: Neither unit can damage the other under this model.")
        elif not math.isfinite(ttk_ab):
            print(f"\nResult: {ua.name} cannot damage {ub.name}; {ub.name} wins by default.")
        else:
            print(f"\nResult: {ub.name} cannot damage {ua.name}; {ua.name} wins by default.")

if __name__ == '__main__':
    main()
