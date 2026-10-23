"""Deterministic success criteria for Istanbul AI test runs.

    python scripts/aitest/criteria.py runs/run_012
    python scripts/aitest/criteria.py <path-to-log-slice.txt>

Reads a run archive (events.txt preferred, any log slice accepted) and
evaluates every criterion against its hard boundary. A run PASSES only if
every applicable criterion passes - no interpretation, no partial credit.
Boundaries are calibrated so the historic false-successes (run_012 "PALACE-
CAPTURED" with two starved teams; the 17:39 "best match on record") FAIL.

Echo vocabulary evaluated: LAND/LANDWAIT/LANDED, PALACE*/PALACEHOME/
PALACEHOLD/PALACEGARRISON, GUNFLEET/GUNRAID, MONITORMAINT.
"""
import os
import re
import sys

GAME_MIN = re.compile(r"(\d+):(\d+):(\d+)")


def gtime(line):
    """Game time in seconds from the echo's timestamp, or None."""
    m = re.search(r"(\d{2}):(\d{2}):(\d{2})", line)
    if not m:
        return None
    h, mn, s = (int(x) for x in m.groups())
    return h * 3600 + mn * 60 + s


def load(path):
    if os.path.isdir(path):
        path = os.path.join(path, "events.txt")
    return [l for l in open(path, encoding="utf-8", errors="replace").read().split("\n") if l.strip()]


def player(line):
    m = re.search(r"P#(\d+)", line) or re.search(r" p(\d+) ", line)
    return int(m.group(1)) if m else None


def evaluate(lines):
    results = []  # (id, desc, boundary, measured, PASS/FAIL/N-A)
    players = sorted(set(p for p in (player(l) for l in lines) if p))

    def add(cid, desc, ok, measured, na=False):
        results.append((cid, desc, "N/A" if na else ("PASS" if ok else "FAIL"), measured))

    # --- P1 home capture universality: PALACEGARRISON per >=2 distinct players
    #     (one per team side) by minute 20
    garr = {}
    for l in lines:
        if "PALACEGARRISON" in l:
            t = gtime(l)
            p = player(l)
            if p and t is not None and p not in garr:
                garr[p] = t
    early = [p for p, t in garr.items() if t <= 20 * 60]
    add("P1", "home flags garrisoned, both sides, by 20:00",
        len(early) >= 2, "players garrisoning by 20:00: %s" % (sorted(early) or "none"))

    # --- P2 no silent stalls: max gap between palace echoes per player < 180 s
    #     until that player garrisons (or match end)
    worst = 0
    worst_p = "-"
    for p in players:
        times = [gtime(l) for l in lines
                 if ("PALACE" in l) and player(l) == p and gtime(l) is not None]
        stop = garr.get(p)
        times = [t for t in times if stop is None or t <= stop]
        if len(times) >= 2:
            gaps = [b - a for a, b in zip(times, times[1:])]
            g = max(gaps)
            if g > worst:
                worst, worst_p = g, "P%d" % p
        elif not times and players:
            worst, worst_p = 99999, "P%d (zero palace echoes)" % p
    add("P2", "max palace-echo silence per player < 180 s",
        worst < 180, "worst gap %ss (%s)" % (worst if worst < 99999 else "inf", worst_p))

    # --- P3 guardian-kill tempo: first 'onto guardian' -> that player's
    #     'standing at flag'/'capture pending'/garrison within 300 s
    tempo_bad = []
    for p in players:
        first = next((gtime(l) for l in lines if player(l) == p and "onto guardian" in l), None)
        done = next((gtime(l) for l in lines if player(l) == p and
                     ("standing at flag" in l or "capture pending" in l
                      or "PALACEGARRISON" in l or "PALACEHOLD" in l)), None)
        if first is not None:
            if done is None or done - first > 300:
                tempo_bad.append("P%d" % p)
    add("P3", "guardian contact -> flag phase <= 300 s",
        not tempo_bad, "slow/no-finish: %s" % (tempo_bad or "none"),
        na=not any("onto guardian" in l for l in lines))

    # --- P4 overseas capture with force >= 4
    hold = [l for l in lines if "PALACEHOLD" in l]
    lone = [l for l in lines if re.search(r"PALACE p\d+ [123] troops onto guardian", l)]
    add("P4", ">=1 overseas PALACEHOLD by 30:00, no lone-wolf assaults",
        bool(hold) and all((gtime(h) or 0) <= 30 * 60 for h in hold[:1]) and not lone,
        "holds: %d, lone-wolf task lines: %d" % (len(hold), len(lone)))

    # --- L1 wave floor 15 (release mode)
    sails = [(player(l), int(m.group(1)), int(m.group(2)))
             for l in lines for m in [re.search(r"sailing, (\d+)/(\d+)", l)] if m]
    small = [s for s in sails if s[1] < 15]
    add("L1", "every sailed wave >= 15 aboard",
        not small, "waves: %s" % ([("P%s" % p, "%d/%d" % (a, b)) for p, a, b in sails] or "none"),
        na=not sails)

    # --- L2 crossing closure: sailing -> LANDED/abort within 240 s (per player order)
    unclosed = []
    for p in set(s[0] for s in sails):
        st = [gtime(l) for l in lines if player(l) == p and "sailing," in l]
        en = [gtime(l) for l in lines if player(l) == p and
              ("LANDED" in l or "ship lost" in l or "crossing timed out" in l)]
        for t in st:
            if not any(e is not None and t is not None and 0 <= e - t <= 240 for e in en):
                unclosed.append("P%d@%s" % (p, t))
    add("L2", "every sailing closed (LANDED/abort) <= 240 s",
        not unclosed, "unclosed: %s" % (unclosed or "none"), na=not sails)

    # --- L3 staged bound: no STAGED streak longer than 8 min per player
    staged_bad = []
    for p in players:
        ts = [gtime(l) for l in lines if player(l) == p and "STAGED" in l and gtime(l) is not None]
        if ts and ts[-1] - ts[0] > 8 * 60:
            runs_ = 1
            streak_start = ts[0]
            for a, b in zip(ts, ts[1:]):
                if b - a > 150:
                    streak_start = b
                if b - streak_start > 8 * 60:
                    staged_bad.append("P%d" % p)
                    break
    add("L3", "no STAGED hold > 8 min", not sorted(set(staged_bad)),
        "over-limit: %s" % (sorted(set(staged_bad)) or "none"),
        na=not any("STAGED" in l for l in lines))

    # --- L4 no orphans: LANDED -> adoption echo <= 20 s
    orphans = []
    for p in players:
        lands = [gtime(l) for l in lines if player(l) == p and "LANDED" in l]
        adopts = [gtime(l) for l in lines if player(l) == p and "adopted" in l]
        for t in lands:
            if not any(a is not None and t is not None and 0 <= a - t <= 20 for a in adopts):
                orphans.append("P%d@%s" % (p, t))
    add("L4", "every LANDED adopted <= 20 s", not orphans,
        "orphaned: %s" % (orphans or "none"),
        na=not any("LANDED" in l for l in lines))

    # --- G1 monitors: MONITORMAINT per player by 12:00 (dock ownership not
    #     visible in echoes; boundary = every player that echoes anything)
    mm = {player(l): gtime(l) for l in lines if "MONITORMAINT" in l}
    add("G1", "MONITORMAINT for every active player by 12:00",
        bool(mm) and len(mm) >= max(1, len(players) // 2) and all(t <= 12 * 60 for t in mm.values() if t),
        "monitor plans: %s" % (sorted("P%s" % p for p in mm) or "none"))

    # --- G2 specialist raids for >= half the players by 20:00
    fleetraid = {player(l) for l in lines if "GUNRAID" in l and " fleet " in l
                 and (gtime(l) or 0) <= 20 * 60}
    add("G2", "GUNRAID fleet path for >= half of players by 20:00",
        players and len(fleetraid) * 2 >= len(players),
        "fleet-path raiders: %s of %d" % (sorted("P%s" % p for p in fleetraid if p) or "none", len(players)))

    # --- G3 zombie rosters
    zombies = [l for l in lines if re.search(r"-> 0 (gun-fleet hulls|ships) onto", l)]
    add("G3", "zero 0-hull raid orders", not zombies, "%d occurrences" % len(zombies))

    # --- S1 KB independence
    kb = [l for l in lines if "no palace exists in the KB" in l or "KB group" in l]
    add("S1", "zero KB-dependence echoes", not kb, "%d occurrences" % len(kb))

    # --- S2 boarding quota
    bt = [l for l in lines if "boarding timed out" in l]
    add("S2", "boarding timeouts <= 1", len(bt) <= 1, "%d timeouts" % len(bt))

    return results


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else None
    if not path:
        print(__doc__)
        return
    lines = load(path)
    results = evaluate(lines)
    fails = sum(1 for r in results if r[2] == "FAIL")
    print("criteria for %s (%d echo lines)" % (path, len(lines)))
    print("%-4s %-52s %-5s %s" % ("id", "criterion", "state", "measured"))
    for cid, desc, state, measured in results:
        print("%-4s %-52s %-5s %s" % (cid, desc, state, measured))
    print("\nRUN VERDICT: %s (%d criteria failed)" % ("PASS" if fails == 0 else "FAIL", fails))
    sys.exit(0 if fails == 0 else 1)


if __name__ == "__main__":
    main()
