"""Roster gate (plan E4/G6): the S-tier must hold for EVERY mod map.

OPEN_STATIC is the visible backlog of real, user-decision-pending map bugs
found by the checker (plan G6 triage bucket 1 items whose fix is a content
choice). Each entry must still be reproduced — a fixed bug with a stale
allowlist entry fails the suite, so the list can only shrink honestly.
"""

from __future__ import annotations

import os
import re
import sys
from functools import lru_cache
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


@lru_cache(maxsize=None)
def _live_vanilla_protos() -> frozenset:
    """Proto names of the CURRENT game build (catalogs' live layer: Data.bar decoded to a LOCALAPPDATA cache), empty
    where the install is not reachable. scripts/source/protoy.xml is the 2025-10-10 snapshot and lags every DLC:
    zpcoldwar / zpunknown place Walrus, deFishingHole, deFeralSheep, deRMWoodCabin, which the live game has."""
    from scripts.refdata import catalogs
    was = os.environ.get("MAPCHECK_LIVE_PROTO")
    os.environ["MAPCHECK_LIVE_PROTO"] = "1"
    try:
        live = catalogs._live_proto_path()
    except SystemExit:      # bartool.find_game_dir() exits where there is no install; the live layer promises None
        live = None
    finally:
        if was is None:
            os.environ.pop("MAPCHECK_LIVE_PROTO")
        else:
            os.environ["MAPCHECK_LIVE_PROTO"] = was
    return frozenset(n.lower() for n in catalogs._proto_names(live)) if live else frozenset()


def _snapshot_lag(f) -> bool:
    """An S4 'unknown proto' the live game has: the repo snapshot is behind, the map is fine."""
    m = re.match(r"unknown proto '([^']+)'", f.message) if f.check == "S4" else None
    return bool(m) and m.group(1).lower() in _live_vanilla_protos()


def _scenario():
    from scripts.mapsim.scene import Scenario
    return Scenario(players=2, teams=2)


@pytest.mark.parametrize("path", MOD_MAPS, ids=[p.stem for p in MOD_MAPS])
def test_static_tier(path):
    res = run(path, _scenario(), static_only=True)
    fails = [f for f in res.findings if f.severity == "FAIL" and not _snapshot_lag(f)]
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
