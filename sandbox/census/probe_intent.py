"""Probe: does script-intent connect to grouping signatures?
For each rmCreateGrouping in a map .xs, resolve the grouping's XML and
show its distinctive (socket/flag) units — the fingerprint the census
can look for."""
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO))

from scripts.mapsim.xs_extract import extract
from scripts.mapsim.scene import Scenario
from scripts.refdata import catalog
from scripts.refdata.catalogs import grouping_units_m

xs = REPO / "randmaps" / "zpelbe.xs"
ex = extract(xs, Scenario(players=4, teams=2))
gcat = catalog("grouping")

defs = {d.line: d for d in ex.defs.values()}
seen = set()
print("grouping intent in zpelbe.xs:")
for p in ex.placements:
    d = defs.get(p.def_line)
    if not d or not d.is_grouping:
        continue
    ref = d.proto if isinstance(d.proto, str) else getattr(d.proto, "str_prefix", None) or "?"
    if ref in seen:
        continue
    seen.add(ref)
    stems = gcat.resolve(ref)
    sig = set()
    for e in stems[:3]:
        units = grouping_units_m(e.name) or ()
        for t, _x, _z in units:
            if any(k in t for k in ("Socket", "Flag", "socket", "flag")):
                sig.add(t)
    print(f"  ref={ref!r:40} -> {len(stems)} stems  signature={sorted(sig) or '(no socket/flag)'}")
