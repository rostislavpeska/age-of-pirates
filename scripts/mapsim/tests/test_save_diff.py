"""save_diff.compare: the counts and percentages that decide a mismatch (the save reader is exercised on the owner's
machine by running the tool; no save lives in the repo)."""
from __future__ import annotations

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[3]))

from scripts.mapsim.save_diff import compare  # noqa: E402


def test_counts_each_direction():
    game = [[True, True], [False, False]]
    sim = [[True, False], [True, False]]
    r = compare(game, sim)
    assert (r["both"], r["game_only"], r["sim_only"]) == (1, 1, 1)
    assert r["game_only_pct"] == r["sim_only_pct"] == 25.0


def test_identical_grids_agree():
    g = [[True, False, True]] * 3
    r = compare(g, [row[:] for row in g])
    assert r["game_only"] == r["sim_only"] == 0


def test_size_mismatch_names_the_player_count():
    with pytest.raises(ValueError, match="player count"):
        compare([[True]], [[True, False]])
