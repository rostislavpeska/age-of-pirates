"""Finding record for mapcheck (plan_mapsim_architecture.md Part G2).

Severity contract (Part F):
  FAIL — the map is broken in a way the evidence base documents (crash,
         silent no-spawn, unreachable players). Gates CI.
  WARN — likely-broken or community-documented risk; needs a human look.
  INFO — context the triage wants (suppressed known issues, sim caveats).

Basis contract (docs/plan_mapsim_testing_refactor.md FACT-vs-MODEL):
  deterministic — from the script text, catalogs, or files on disk; no
                  simulator modeling involved.
  model         — from the mapsim terrain/placement model; correct to the
                  model's calibration, not engine ground truth.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Dict, Optional

SEVERITIES = ("FAIL", "WARN", "INFO")


@dataclass
class Finding:
    check: str                 # "S1".."S5", "G1".."G5", "SIM:<verdict>", template name
    severity: str              # FAIL | WARN | INFO
    basis: str                 # deterministic | model
    message: str
    map: str = ""              # map stem
    scenario: str = ""         # "P2T2" etc.; "" for static findings
    line: Optional[int] = None
    guide_ref: Optional[str] = None   # e.g. "guide 21.2:10867"
    details: Dict[str, Any] = field(default_factory=dict)

    def to_dict(self) -> Dict[str, Any]:
        return {
            "check": self.check, "severity": self.severity, "basis": self.basis,
            "message": self.message, "map": self.map, "scenario": self.scenario,
            "line": self.line, "guide_ref": self.guide_ref,
            "details": self.details,
        }


def worst_exit_code(findings) -> int:
    """0 clean / 1 FAIL present (runner contract; 2 = crash, set by caller)."""
    return 1 if any(f.severity == "FAIL" for f in findings) else 0
