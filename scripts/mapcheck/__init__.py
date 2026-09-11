"""mapcheck: the Layer-1 automatic test suite for random maps
(plan_mapsim_architecture.md Parts E/F/G).

    python -m scripts.mapcheck zptortuga --matrix

Static tier (S1-S5) needs only the extractor and the refdata catalogs;
grid tier (G1-G5) consumes the mapsim Layer-2 classified grid.
"""

from scripts.mapcheck.finding import Finding, worst_exit_code
from scripts.mapcheck.universal import RunResult, run

__all__ = ["Finding", "RunResult", "run", "worst_exit_code"]
