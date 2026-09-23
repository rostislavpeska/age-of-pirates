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
        lines = [l for l in decode(path).split("\n") if l.strip()]
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
            if "LONDONSETUP p%d" % p in l and "marker not found" not in l:
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
