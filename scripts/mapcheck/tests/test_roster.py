"""Roster gate (plan E4/G6): the S-tier must hold for EVERY mod map.

OPEN_STATIC is the visible backlog of real, user-decision-pending map bugs
found by the checker (plan G6 triage bucket 1 items whose fix is a content
choice). Each entry must still be reproduced — a fixed bug with a stale
allowlist entry fails the suite, so the list can only shrink honestly.
"""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[3]))

from scripts.mapcheck.universal import run  # noqa: E402

REPO = Path(__file__).resolve().parents[3]
MOD_MAPS = sorted((REPO / "game" / "randmaps").glob("*.xs"))

# stem -> {(check, message substring)} of OPEN findings awaiting a content
# decision (see docs/plan_mapsim_architecture.md G6 triage). Do NOT add
# entries without a triage note; remove them the moment the map is fixed.
OPEN_STATIC = {
    # dev-only variant, no lobby .xml on purpose? -> user decision
    "zp_z_cookislands": {("S5", "no companion")},
    # starting tree proto does not exist anywhere -> trees never spawn;
    # replacement name is a content choice (zpmalta uses TreeTexas)
    "zpBalearicIslands": {("S4", "TreeMediterranean")},
    # proto exists only inside a commented-out protomods block -> restore
    # the proto or repoint the maps
    "zpeyrebasin": {("S4", "zpTradingPostCaptureInvisible")},
    "zpwildwest": {("S4", "zpTradingPostCaptureInvisible")},
}


def _scenario():
    from scripts.mapsim.scene import Scenario
    return Scenario(players=2, teams=2)


@pytest.mark.parametrize("path", MOD_MAPS, ids=[p.stem for p in MOD_MAPS])
def test_static_tier(path):
    res = run(path, _scenario(), static_only=True)
    fails = [f for f in res.findings if f.severity == "FAIL"]
    allowed = OPEN_STATIC.get(path.stem, set())

    unexpected = [f for f in fails
                  if not any(f.check == c and s in f.message
                             for c, s in allowed)]
    assert unexpected == [], [f"{f.check}: {f.message}" for f in unexpected]

    stale = [entry for entry in allowed
             if not any(f.check == entry[0] and entry[1] in f.message
                        for f in fails)]
    assert stale == [], (f"OPEN_STATIC entries no longer reproduce for "
                         f"{path.stem}: {stale} — remove them")
