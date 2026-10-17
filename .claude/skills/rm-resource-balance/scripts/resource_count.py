"""Count a random map's resources: what its groupings carry, what its script places, and what a saved generation
actually holds on each half of the map.

  python .claude/skills/rm-resource-balance/scripts/resource_count.py groupings randmaps/zplondon.xs
  python .claude/skills/rm-resource-balance/scripts/resource_count.py census <save.age3Yscn> [--axis z] [--beyond 250]

groupings: every grouping file the map names (any string literal that is a file in game/randmaps/groupings), with
           its resource units by class and amount, then every rmAddObjectDefItem of a resource proto in the script
           (the placement COUNT is the script's formula: read it at the def's rmPlaceObjectDef* lines).
census:    a saved generation split at the middle of the map along --axis; --beyond M counts only units at least
           M metres from that midline (e.g. the countryside beyond a city wall). Parity = both halves equal.
Amounts come from the vanilla protoy (scripts/source/protoy.xml) overlaid by data/protomods.xml.
"""
import argparse
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

REPO = Path(__file__).resolve().parents[4]
GROUPINGS = REPO / "game" / "randmaps" / "groupings"
CLASSES = (("coin mine", ("AbstractMine", "MinedResource")), ("hunt", ("Huntable",)), ("livestock", ("Herdable",)),
           ("berries", ("AbstractBerryBush", "AbstractFruit")), ("fish", ("AbstractFish", "Fish")), ("wood", ("Tree",)))


def proto_table():
    """name -> (class, resource type, amount) for every unit that holds a resource."""
    table = {}
    for path in (REPO / "scripts" / "source" / "protoy.xml", REPO / "data" / "protomods.xml"):
        if not path.is_file():
            print(f"(missing {path.relative_to(REPO)} - amounts from it unavailable)", file=sys.stderr)
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        for m in re.finditer(r"<unit\b([^>]*)>(.*?)</unit>", text, re.S):
            name = re.search(r'name\s*=\s*"([^"]+)"', m.group(1))
            if not name:
                continue
            body = m.group(2)
            res = re.search(r'<initialresource[^>]*?type\s*=\s*"(\w+)"[^>]*>\s*([\d.]+)', body, re.I)
            if not res:
                continue
            types = set(re.findall(r"<unittype>(\w+)</unittype>", body, re.I))
            cls = next((c for c, keys in CLASSES if types & set(keys)), "other " + res.group(1).lower())
            table[name.group(1)] = (cls, res.group(1), float(res.group(2)))
    return table


def fmt(units: Counter, amounts: Counter) -> str:
    return ", ".join(f"{c} {units[c]} = {int(amounts[c])}" for c in sorted(units))


def cmd_groupings(xs: Path, table) -> None:
    text = xs.read_text(encoding="utf-8", errors="replace")
    files = {p.stem.lower(): p for p in GROUPINGS.glob("*.xml")}
    # per line with // comments stripped: one odd quote in a comment would misalign every later pair
    literals = {s for line in text.splitlines() for s in re.findall(r'"([^"\\]+)"', line.split("//")[0])}
    names = sorted(s for s in literals if s.lower() in files)
    print(f"== groupings named by {xs.name}: {len(names)} (resource units by class = amount)")
    for n in names:
        units, amounts, protos = Counter(), Counter(), Counter()
        for proto in re.findall(r"<unit[^>]*>\s*([^<\s]+)\s*</unit>", files[n.lower()].read_text(encoding="utf-8", errors="replace")):
            if proto in table and "wood" not in table[proto][0]:     # grouping trees are props, not the map's wood
                cls, _, amt = table[proto]
                units[cls] += 1
                amounts[cls] += amt
                protos[proto] += 1
        if units:
            print(f"  {n}: {fmt(units, amounts)}   [{', '.join(f'{p} x{c}' for p, c in sorted(protos.items()))}]")
    print("== resource items the script places (count per placement; multiply by the def's placement formula)")
    for i, line in enumerate(text.splitlines(), 1):
        m = re.search(r'rmAddObjectDefItem\(\s*(\w+)\s*,\s*"([^"]+)"\s*,\s*(rmRandInt\([^)]*\)|[^,]+),', line)
        if m and m.group(2) in table and "wood" not in table[m.group(2)][0]:
            cls, _, amt = table[m.group(2)]
            print(f"  {xs.name}:{i}  {m.group(1)}: {m.group(2)} x {m.group(3).strip()}  ({cls}, {int(amt)} each)")


def cmd_census(save: Path, axis: str, beyond: float, table) -> None:
    sys.path.insert(0, str(REPO / "sandbox" / "census"))
    sys.path.insert(0, str(REPO))
    from census import census  # the repo's .age3Yscn reader (rm-census)
    units = [u for u in census(save) if u["x"] == u["x"]]
    vals = [u[axis] for u in units]
    mid = (min(vals) + max(vals)) / 2
    halves = defaultdict(lambda: (Counter(), Counter()))
    for u in units:
        if u["proto"] not in table or "wood" in table[u["proto"]][0] or abs(u[axis] - mid) < beyond:
            continue
        cls, _, amt = table[u["proto"]]
        side = f"low {axis}" if u[axis] < mid else f"high {axis}"
        halves[side][0][cls] += 1
        halves[side][1][cls] += amt
    print(f"== {save.name}: midline {axis} = {mid:.0f} m, counting units >= {beyond:.0f} m from it")
    for side in (f"low {axis}", f"high {axis}"):
        print(f"  {side}: {fmt(*halves[side])}")
    a, b = halves[f"low {axis}"][0], halves[f"high {axis}"][0]
    diff = {c: a[c] - b[c] for c in set(a) | set(b) if a[c] != b[c]}
    print(f"  parity: {'EQUAL' if not diff else 'UNEQUAL ' + str(diff)}")


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    sub = ap.add_subparsers(dest="cmd", required=True)
    g = sub.add_parser("groupings")
    g.add_argument("xs", type=Path)
    c = sub.add_parser("census")
    c.add_argument("save", type=Path)
    c.add_argument("--axis", choices=("x", "z"), default="z")
    c.add_argument("--beyond", type=float, default=0.0)
    a = ap.parse_args(argv)
    table = proto_table()
    if a.cmd == "groupings":
        cmd_groupings(a.xs if a.xs.is_absolute() else REPO / a.xs, table)
    else:
        cmd_census(a.save, a.axis, a.beyond, table)
    return 0


if __name__ == "__main__":
    sys.exit(main())
