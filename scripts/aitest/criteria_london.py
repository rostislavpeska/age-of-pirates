"""Deterministic criteria for London AI test runs (docs/briefs/2026-09-23-london-ai-plan.md, section 3).

    python scripts/aitest/criteria_london.py runs/run_NNN

Reads the per-player AI files the quit flushed (Age3DEAIOutputPlayer<N>.txt, UTF-16) - the live echo
channel is silent since the 2026-09 patch, so these files ARE the record. A run PASSES only if every
applicable criterion passes. Round 1 judges L0-L3 and U1-U2; later rounds append their ids here.

Echo vocabulary: LONDON p<N> build | LONDONSETUP | LONDONDIAG (round 1); LONDONWAR / LONDONGATE /
LONDONKEEP / LONDONHOLD / LONDONBRIDGE (rounds 2-4, see the plan).
"""
import glob
import os
import re
import sys

STAMP = re.compile(r"(\d{2}):(\d{2}):(\d{2})")


def decode(path):
    b = open(path, "rb").read()
    if b.startswith(b"\xff\xfe") or b.startswith(b"\xfe\xff"):
        return b.decode("utf-16", errors="replace")
    if len(b) > 1 and b[1:2] == b"\x00":
        return b.decode("utf-16-le", errors="replace")
    return b.decode("utf-8", errors="replace")


def gtime(line):
    m = STAMP.search(line)
    if not m:
        return None
    h, mn, s = (int(x) for x in m.groups())
    return h * 3600 + mn * 60 + s


def load(run_dir):
    """{player: [lines]} for every non-empty per-player file in the run folder."""
    out = {}
    for path in sorted(glob.glob(os.path.join(run_dir, "Age3DEAIOutputPlayer*.txt"))):
        m = re.search(r"Player(\d+)", os.path.basename(path))
        # the engine's own echoes (BuildPlan ... failing) end without a newline: split at every stamp, not at "\n"
        text = re.sub(r"(?<!^)(?<!\n)(\d{2}:\d{2}:\d{2}  \()", r"\n\1", decode(path))
        lines = [l for l in text.split("\n") if l.strip()]
        if m and lines:
            out[int(m.group(1))] = lines
    return out


def evaluate(files, events_path=None):
    results = []  # (id, desc, PASS/FAIL/N-A, measured)

    def add(cid, desc, ok, measured, na=False):
        results.append((cid, desc, "N/A" if na else ("PASS" if ok else "FAIL"), measured))

    ai = {p: ls for p, ls in files.items() if any("LONDON" in l or "Main is starting" in l for l in ls)}
    players = sorted(ai)
    add("L*", "AI players with a per-player file", len(players) > 0, "players: %s" % (players or "none"))

    # L0 build + detection within 30 s, every AI player
    late = []
    for p in players:
        t = [gtime(l) for l in ai[p] if ("LONDON p%d build" % p) in l]
        if not t or t[0] is None or t[0] > 30:
            late.append(p)
    add("L0", "LONDON p<N> build echo within 30 s, every AI player", not late, "missing/late: %s" % (late or "none"))

    # L1 setup complete within 60 s: both gates, both keeps, all ids > 0
    bad = []
    for p in players:
        ok = False
        for l in ai[p]:
            if "LONDONSETUP p%d" % p in l and "marker not found" not in l and "construction blocks" not in l:
                ids = {k: int(v) for k, v in re.findall(r"(socket|ours|keepNear|keepFar) (-?\d+)", l)}
                gates = re.search(r"gates (-?\d+) (-?\d+)", l)
                found = re.search(r"gates found (\d+) keeps found (\d+)", l)
                t = gtime(l)
                ok = (t is not None and t <= 60 and gates is not None and found is not None
                      and int(found.group(1)) == 2 and int(found.group(2)) == 2
                      and int(gates.group(1)) > 0 and int(gates.group(2)) > 0
                      and all(ids.get(k, -1) > 0 for k in ("socket", "ours", "keepNear", "keepFar")))
                break
        if not ok:
            bad.append(p)
    add("L1", "LONDONSETUP within 60 s: socket, 2 gates, our gate, 2 keeps, all ids > 0", not bad, "failing players: %s" % (bad or "none"))

    # L2 diagnostics flowing: >= 4 LONDONDIAG lines by 6:00, gaps < 120 s
    bad = []
    for p in players:
        ts = [gtime(l) for l in ai[p] if "LONDONDIAG p%d pass" % p in l and gtime(l) is not None]
        early = [t for t in ts if t <= 360]
        gaps = [b - a for a, b in zip(ts, ts[1:])]
        if len(early) < 4 or (gaps and max(gaps) >= 120):
            bad.append("P%d(%d lines, max gap %s)" % (p, len(early), max(gaps) if gaps else "-"))
    add("L2", ">= 4 LONDONDIAG lines by 6:00, gaps < 120 s", not bad, "failing: %s" % (bad or "none"))

    # L3 no silent AI: more than the 4 stock lines
    thin = ["P%d(%d)" % (p, len(ai[p])) for p in players if len(ai[p]) <= 10]
    add("L3", "per-player file has more than 10 lines", not thin, "thin files: %s" % (thin or "none"))

    # U1 process alive at the cap (the driver's events)
    died = False
    if events_path and os.path.exists(events_path):
        died = "GAME PROCESS DIED" in open(events_path, encoding="utf-8", errors="replace").read()
    add("U1", "game process alive at the cap", not died, "died" if died else "alive")

    # U2 no stalls: max gap between LONDON* echoes per AI player < 120 s
    worst = 0
    worst_p = "-"
    for p in players:
        ts = [gtime(l) for l in ai[p] if "LONDON" in l and gtime(l) is not None]
        gaps = [b - a for a, b in zip(ts, ts[1:])]
        if gaps and max(gaps) > worst:
            worst, worst_p = max(gaps), "P%d" % p
    add("U2", "max gap between LONDON echoes per AI player < 120 s", worst < 120, "worst %ds (%s)" % (worst, worst_p))

    # round 2 - applicable once the build echo says r2 or later
    r2 = [p for p in players if any(re.search(r"LONDON p%d build r([2-9]|\d\d)" % p, l) for l in ai[p])]
    if r2:
        # L4 attacks held: the first LONDONWAR held precedes any released; every released line says the crossing is open
        bad = []
        for p in r2:
            war = [l for l in ai[p] if "LONDONWAR p%d" % p in l]
            held = [i for i, l in enumerate(war) if " held - " in l]
            rel = [i for i, l in enumerate(war) if " released" in l]
            if not held or (rel and rel[0] < held[0]) or any("crossing open" not in war[i] for i in rel):
                bad.append("P%d(held %d released %d)" % (p, len(held), len(rel)))
        add("L4", "LONDONWAR held precedes any released; released only with the crossing open", not bad, "failing: %s" % (bad or "none"))

        # L5 near Keep gate down by 12:00 (test mode)
        bad = []
        for p in r2:
            t = [gtime(l) for l in ai[p] if re.search(r"LONDONGATE p%d gate \d+ down kind nearKeep" % p, l)]
            if not t or t[0] is None or t[0] > 720:
                bad.append("P%d(%s)" % (p, "%ds" % t[0] if t and t[0] is not None else "never"))
        add("L5", "LONDONGATE gate <id> down kind nearKeep by 12:00", not bad, "failing: %s" % (bad or "none"))

        # L6 no unreachable order: no 'tasked ... on <id>' in the same pass (same stamp) as 'skip <id> unreachable'
        n = 0
        for p in r2:
            skips = set()
            for l in ai[p]:
                m = re.search(r"LONDONGATE p%d skip (\d+) unreachable" % p, l)
                if m:
                    skips.add((gtime(l), m.group(1)))
            for l in ai[p]:
                m = re.search(r"LONDONGATE p%d tasked \d+ on (\d+)" % p, l)
                if m and (gtime(l), m.group(1)) in skips:
                    n += 1
        add("L6", "no LONDONGATE tasked on a target the same pass skipped as unreachable", n == 0, "count %d" % n)

    # round 3 - applicable once the build echo says r3 or later
    r3 = [p for p in players if any(re.search(r"LONDON p%d build r([3-9]|\d\d)" % p, l) for l in ai[p])]
    if r3:
        # L7 Keep captured by 15:00
        bad = []
        l7 = {}
        for p in r3:
            t = [gtime(l) for l in ai[p] if re.search(r"LONDONKEEP p%d flag ours" % p, l)]
            if t and t[0] is not None:
                l7[p] = t[0]
            if p not in l7 or l7[p] > 900:
                bad.append("P%d(%s)" % (p, "%ds" % l7[p] if p in l7 else "never"))
        add("L7", "LONDONKEEP flag ours by 15:00", not bad, "failing: %s" % (bad or "none"))

        # L8 (owner 2026-09-24, option 2): the AIs contest the Keeps - a lost Keep ('LONDONHOLD .. retaking keep K') must be
        # held again ('.. holding keep K') within 300 s; an episode still open less than 300 s before the record ends is fine
        bad = []
        for p in r3:
            if p not in l7:
                bad.append("P%d(no capture)" % p)
                continue
            end = max(gtime(l) for l in ai[p] if gtime(l) is not None)
            open_since = {}
            for l in ai[p]:
                m = re.search(r"LONDONHOLD p%d \d+ (holding|retaking) keep (\d+)" % p, l)
                t = gtime(l)
                if not m or t is None:
                    continue
                k = m.group(2)
                if m.group(1) == "retaking":
                    open_since.setdefault(k, t)
                elif k in open_since:
                    if t - open_since[k] > 300:
                        bad.append("P%d keep %s lost %ds" % (p, k, t - open_since[k]))
                    del open_since[k]
            for k, t0 in open_since.items():
                if end - t0 > 300:
                    bad.append("P%d keep %s lost %ds (open)" % (p, k, end - t0))
        add("L8", "a lost Keep is held again within 300 s", not bad, "failing: %s" % (bad or "none"))

    # round 4 (placement, London only) - applicable once the build echo says r4 or later; reads the AIDIAG line
    r4 = [p for p in players if any(re.search(r"LONDON p%d build r([4-9]|\d\d)" % p, l) for l in ai[p])]
    if r4:
        diag = re.compile(r"AIDIAG p(\d+) age (-?\d+) .*? farms (-?\d+) plant (-?\d+) bldg (-?\d+) baseR (-?[\d.]+) fails (-?\d+) failsTC (-?\d+) london (\d)")
        rows = {p: [(gtime(l), diag.search(l)) for l in ai[p] if diag.search(l) and gtime(l) is not None] for p in r4}
        # P0 the London flag is on for every London AI player (the placement code acts only then)
        off = [p for p in r4 if not rows[p] or rows[p][-1][1].group(9) != "1"]
        add("P0", "AIDIAG london 1 for every AI player", not off, "failing: %s" % (off or "none"))
        # P1 the main base grows past its 40 m start by 20:00 (only judged when the record reaches 20:00)
        bad = []
        for p in r4:
            late = [(t, m) for t, m in rows[p] if t <= 1200]
            if rows[p] and rows[p][-1][0] >= 1200 and max(float(m.group(6)) for t, m in late) <= 60.0:
                bad.append("P%d(%.0f m)" % (p, max(float(m.group(6)) for t, m in late)))
        add("P1", "main base radius > 60 m by 20:00", not bad, "failing: %s" % (bad or "none"))
        # P2 placement failures <= 4 per 10 game minutes (runs 16-17: 13 and 15 in about 20 minutes, most endless)
        bad = []
        for p in r4:
            if rows[p]:
                t, m = rows[p][-1]
                rate = int(m.group(7)) * 600.0 / t if t else 0.0
                if rate > 4.0:
                    bad.append("P%d(%d fails in %ds = %.1f / 10 min)" % (p, int(m.group(7)), t, rate))
        # INFO since 2026-09-24: the bound was the agent's own metric, not an owner requirement, and chasing it produced the
        # socket filter the owner reverted (I13); reported, never a verdict, until the owner sets a bound
        add("P2", "INFO placement failures per 10 game minutes (owner bound pending)", True,
            "above 4: %s" % (bad or "none"), na=True)
        # INFO: Trading Posts owned at the last AIDIAG (the reverts must restore normal claiming - bridge post, natives)
        tp = []
        for p in r4:
            last = [l for l in ai[p] if "AIDIAG p%d" % p in l]
            m = re.search(r" tps (\d+)", last[-1]) if last else None
            tp.append("P%d %s" % (p, m.group(1) if m else "?"))
        add("T1", "INFO Trading Posts owned at the end", True, ", ".join(tp), na=True)
        # P3 the economy uses the countryside: a LONDONPLACE field line and a Mill / Plantation / Farm standing by 25:00
        bad = []
        for p in r4:
            field = any(re.search(r"LONDONPLACE p%d field " % p, l) for l in ai[p])
            eco = any(int(m.group(3)) + int(m.group(4)) > 0 for t, m in rows[p] if t <= 1500)
            if rows[p] and rows[p][-1][0] >= 1500 and not (field and eco):
                bad.append("P%d(field line %s, eco building %s)" % (p, field, eco))
        add("P3", "a countryside field placement and an eco building by 25:00", not bad, "failing: %s" % (bad or "none"))

    # round 6 - no dead end at the bridge (run 31: a rebuilt / converted bridge gate stood unseen after the release):
    # every 'gate <id> reappeared' is followed within 180 s by 'tasked n on <id>' or 'gate <id> down'
    r6 = [p for p in players if any(re.search(r"LONDON p%d build r([6-9]|\d\d)" % p, l) for l in ai[p])]
    if r6:
        bad = []
        for p in r6:
            for l in ai[p]:
                m = re.search(r"LONDONGATE p%d gate (\d+) reappeared" % p, l)
                if not m:
                    continue
                t0, gid = gtime(l), m.group(1)
                ok = any(gtime(k) is not None and t0 <= gtime(k) <= t0 + 180 and
                         (re.search(r"LONDONGATE p%d tasked \d+ on %s " % (p, gid), k) or
                          re.search(r"LONDONGATE p%d gate %s down" % (p, gid), k)) for k in ai[p])
                if not ok:
                    bad.append("P%d gate %s at %ds" % (p, gid, t0))
        add("L9", "a reappeared bridge / Keep gate is tasked or down within 180 s", not bad,
            "failing: %s" % (bad or "none"))

    # F1 (owner 2026-09-24: 'the AI builds the estates far behind'): every field target within 200 m of our base
    r9 = [p for p in players if any(re.search(r"LONDON p%d build r(9|\d\d)" % p, l) for l in ai[p])]
    if r9:
        bad, worst = [], {}
        for p in r9:
            ds = [float(m.group(1)) for l in ai[p] for m in [re.search(r"LONDONPLACE p%d field .* dist ([\d.]+)" % p, l)] if m]
            if ds:
                worst[p] = max(ds)
                if max(ds) > 200.0:
                    bad.append("P%d(%.0f m)" % (p, max(ds)))
        add("F1", "every field target within 200 m of our base", not bad,
            "worst: %s; failing: %s" % (", ".join("P%d %.0f m" % kv for kv in sorted(worst.items())) or "no field yet", bad or "none"))

    # round 5 - the forward base at our bridgehead (owner 2026-09-24): when the stock AI asks for one, the point is
    # London's; judged only for players whose record shows the ask
    r5 = [p for p in players if any(re.search(r"LONDON p%d build r([5-9]|\d\d)" % p, l) for l in ai[p])]
    if r5:
        asked = [p for p in r5 if any("LONDONPLACE p%d forward base next to the bridge" % p in l for l in ai[p])]
        bad = []
        for p in asked:
            n = sum(1 for l in ai[p] if re.search(r"BuildPlan\(\d+: Forward .*failing because (building placement failed|we can't path)", l))
            if n > 3:
                bad.append("P%d(%d Forward placement failures)" % (p, n))
        add("P4", "forward base at the bridgehead: <= 3 Forward placement / can't-path failures", not bad,
            "asked by %s; failing: %s" % (asked or "nobody", bad or "none"), na=not asked)
    return results


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(2)
    run_dir = sys.argv[1]
    files = load(run_dir)
    results = evaluate(files, os.path.join(run_dir, "events.txt"))
    print("%-4s %-4s %-72s %s" % ("id", "res", "criterion", "measured"))
    for cid, desc, res, measured in results:
        print("%-4s %-4s %-72s %s" % (cid, res, desc, measured))
    fails = sum(1 for r in results if r[2] == "FAIL")
    print("\nRUN VERDICT: %s (%d criteria failed)" % ("PASS" if fails == 0 else "FAIL", fails))
    sys.exit(1 if fails else 0)


if __name__ == "__main__":
    main()
