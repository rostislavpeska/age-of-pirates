"""Standard-map baseline and regression check for the AI test campaign (docs/briefs/2026-09-23-london-ai-test-report.md).

    python scripts/aitest/criteria_baseline.py runs/run_NNN                    # metrics.json + table
    python scripts/aitest/criteria_baseline.py runs/run_NNN --floor runs/run_MMM/metrics.json   # + regression verdict

Reads the per-player AI files the quit flushed and the AIDIAG line every AI player echoes once a minute on every map
(rule aiTestDiag, game/ai/core/aipiraterules.xs - echo only). The first run on a standard map is the FLOOR; every later
standard-map run is judged against it, so a change made for London that leaks into other maps shows up as a regression.

Regression criteria (per AI player, the floor's worst player vs this run's worst player - civs are random, so the
bounds are deliberately wide; one run is one sample):
  B0  every AI player echoes AIDIAG (the diag and the whole AI compiled)            hard
  B1  the last AIDIAG is at least 80 % of the floor's game time (no early stall)     hard
  B2  age reached >= floor age - 1                                                   regression bound
  B3  villagers at the floor's last timestamp >= 60 % of the floor                   regression bound
  B4  placement failures per 10 game minutes <= 2 x floor + 5                        regression bound
  B5  AIDIAG never says london 1 on a standard map (the London flag must stay off)   hard
"""
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from criteria_london import load, gtime  # noqa: E402

DIAG = re.compile(r"AIDIAG p(\d+) age (-?\d+) score (-?\d+) vills (-?\d+) army (-?\d+) navy (-?\d+) tcs (-?\d+) houses (-?\d+)"
                  r" milbldg (-?\d+) farms (-?\d+) plant (-?\d+) bldg (-?\d+) baseR (-?[\d.]+) fails (-?\d+) failsTC (-?\d+)"
                  r" london (\d)")
KEYS = ("age", "score", "vills", "army", "navy", "tcs", "houses", "milbldg", "farms", "plant", "bldg", "baseR",
        "fails", "failsTC", "london")


def series(files):
    """{player: [(t, {metric: value})]} from the AIDIAG lines."""
    out = {}
    for p, lines in files.items():
        rows = []
        for l in lines:
            m = DIAG.search(l)
            t = gtime(l)
            if m and t is not None and int(m.group(1)) == p:
                vals = [float(x) for x in m.groups()[1:]]
                rows.append((t, dict(zip(KEYS, vals))))
        if rows:
            out[p] = rows
    return out


def at(rows, t):
    """The last sample at or before t (the first sample when t precedes them all)."""
    best = rows[0][1]
    for ts, v in rows:
        if ts <= t:
            best = v
    return best


def metrics(files):
    s = series(files)
    m = {"players": {}, "ai_players": sorted(files)}
    for p, rows in s.items():
        last_t, last = rows[-1]
        m["players"][str(p)] = {
            "last_t": last_t,
            "last": last,
            "samples": {str(t): v for t, v in rows if t % 300 < 60},   # about every 5 minutes
            "fails_per_10min": (last["fails"] * 600.0 / last_t) if last_t > 0 else 0.0,
        }
    return m, s


def evaluate(files, floor=None):
    res = []

    def add(cid, desc, ok, measured):
        res.append((cid, desc, "PASS" if ok else "FAIL", measured))

    m, s = metrics(files)
    missing = [p for p in files if p not in s]
    add("B0", "every AI player echoes AIDIAG", not missing and bool(s), "missing: %s" % (missing or "none"))
    london = [p for p, rows in s.items() if any(v["london"] > 0 for _, v in rows)]
    add("B5", "no AIDIAG says london 1 on a standard map", not london, "players: %s" % (london or "none"))
    if floor and s:
        fp = floor["players"]
        f_last_t = min(v["last_t"] for v in fp.values())
        f_age = min(v["last"]["age"] for v in fp.values())
        f_vills = min(v["last"]["vills"] for v in fp.values())
        f_fails = max(v["fails_per_10min"] for v in fp.values())
        last_t = min(rows[-1][0] for rows in s.values())
        add("B1", "last AIDIAG >= 80 % of the floor's game time", last_t >= 0.8 * f_last_t,
            "%ds vs floor %ds" % (last_t, f_last_t))
        age = min(at(rows, f_last_t)["age"] for rows in s.values())
        add("B2", "age reached >= floor age - 1", age >= f_age - 1, "%d vs floor %d" % (age, f_age))
        vills = min(at(rows, f_last_t)["vills"] for rows in s.values())
        add("B3", "villagers >= 60 %% of the floor at %ds" % f_last_t, vills >= 0.6 * f_vills,
            "%d vs floor %d" % (vills, f_vills))
        fails = max(v["fails_per_10min"] for v in m["players"].values())
        add("B4", "placement failures / 10 min <= 2 x floor + 5", fails <= 2 * f_fails + 5,
            "%.1f vs floor %.1f" % (fails, f_fails))
    return res, m


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(2)
    rd = sys.argv[1]
    floor = None
    if "--floor" in sys.argv:
        floor = json.load(open(sys.argv[sys.argv.index("--floor") + 1]))
    files = load(rd)
    res, m = evaluate(files, floor)
    with open(os.path.join(rd, "metrics.json"), "w") as f:
        json.dump(m, f, indent=1)
    print("%-4s %-4s %-58s %s" % ("id", "res", "criterion", "measured"))
    for cid, desc, r, meas in res:
        print("%-4s %-4s %-58s %s" % (cid, r, desc, meas))
    for p, v in sorted(m["players"].items()):
        last = v["last"]
        print("P%s at %ds: age %d score %d vills %d army %d navy %d tcs %d houses %d milbldg %d farms %d plant %d"
              " bldg %d baseR %.0f fails %d (TC %d) = %.1f / 10 min"
              % (p, v["last_t"], last["age"], last["score"], last["vills"], last["army"], last["navy"], last["tcs"],
                 last["houses"], last["milbldg"], last["farms"], last["plant"], last["bldg"], last["baseR"],
                 last["fails"], last["failsTC"], v["fails_per_10min"]))
    bad = [r for r in res if r[2] == "FAIL"]
    print("")
    print("RUN VERDICT: %s (%d criteria failed)" % ("FAIL" if bad else "PASS", len(bad)))


if __name__ == "__main__":
    main()
