"""Map profiles: one JSON per map, the single source of truth for that
map's verified weirdnesses (plan Parts D and G3).

Location: scripts/maps/<stem>.json, stem == the .xs stem. The schema is
documented in scripts/maps/schema.md; this loader enforces it mechanically:
unknown keys are errors, and every override must reference an evidence
entry by id (the D5 guard rail — no evidence, no override).

Consumers: mapcheck (expectations -> probe template instances, tests ->
template instances, known_issues -> finding demotion) and mapsim (overrides
-> waterdata.depth_overrides during grid builds).
"""

from __future__ import annotations

import json
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Dict, List, Optional

from scripts.mapcheck.finding import Finding

REPO_ROOT = Path(__file__).resolve().parents[2]
PROFILES_DIR = REPO_ROOT / "scripts" / "maps"

CLASS_NAMES = ("LAND", "SHALLOW", "DEEP", "CLIFF")

_TOP_KEYS = {"map", "version", "script", "notes", "evidence", "overrides",
             "expectations", "tests", "known_issues"}
_OVERRIDE_KEYS = {"water_depth_m"}
_EVIDENCE_KEYS = {"id", "date", "source", "claim", "ref"}
_EXPECTATION_KEYS = {"probe", "class", "why", "evidence"}
_TEST_KEYS = {"template", "params", "why"}
_KNOWN_ISSUE_KEYS = {"check", "match", "why", "evidence"}


@dataclass
class Profile:
    map: str
    path: Path
    version: int = 1
    script: Optional[str] = None
    notes: str = ""
    evidence: Dict[str, dict] = field(default_factory=dict)   # id -> entry
    water_depth_m: Dict[str, float] = field(default_factory=dict)
    expectations: List[dict] = field(default_factory=list)
    tests: List[dict] = field(default_factory=list)
    known_issues: List[dict] = field(default_factory=list)


def validate(data: Any, stem: str) -> List[str]:
    """Schema v1 errors as human-readable strings; [] = valid."""
    errs: List[str] = []
    if not isinstance(data, dict):
        return [f"profile root must be an object, got {type(data).__name__}"]
    for k in data:
        if k not in _TOP_KEYS:
            errs.append(f"unknown top-level key {k!r} (schema.md v1)")
    if data.get("map") != stem:
        errs.append(f"'map' must equal the file stem {stem!r}, "
                    f"got {data.get('map')!r}")
    if data.get("version") != 1:
        errs.append(f"'version' must be 1, got {data.get('version')!r}")

    ev_ids: List[str] = []
    for i, ev in enumerate(data.get("evidence", [])):
        where = f"evidence[{i}]"
        if not isinstance(ev, dict):
            errs.append(f"{where} must be an object"); continue
        for k in ev:
            if k not in _EVIDENCE_KEYS:
                errs.append(f"{where}: unknown key {k!r}")
        for req in ("id", "date", "source", "claim"):
            if not ev.get(req):
                errs.append(f"{where}: missing required {req!r}")
        if ev.get("id") in ev_ids:
            errs.append(f"{where}: duplicate id {ev['id']!r}")
        if ev.get("id"):
            ev_ids.append(ev["id"])

    ov = data.get("overrides", {})
    if not isinstance(ov, dict):
        errs.append("'overrides' must be an object")
        ov = {}
    for k in ov:
        if k not in _OVERRIDE_KEYS:
            errs.append(f"overrides: unknown key {k!r} "
                        f"(v1 allows only {sorted(_OVERRIDE_KEYS)})")
    for name, entry in (ov.get("water_depth_m") or {}).items():
        where = f"overrides.water_depth_m[{name!r}]"
        if (not isinstance(entry, dict)
                or set(entry) != {"value", "evidence"}):
            errs.append(f"{where}: entry must be "
                        "{{\"value\": <meters>, \"evidence\": <id>}}")
            continue
        if not isinstance(entry["value"], (int, float)):
            errs.append(f"{where}: value must be a number")
        if entry["evidence"] not in ev_ids:
            errs.append(f"{where}: evidence id {entry['evidence']!r} not "
                        "found — no evidence, no override (plan D5)")

    for i, ex in enumerate(data.get("expectations", [])):
        where = f"expectations[{i}]"
        if not isinstance(ex, dict):
            errs.append(f"{where} must be an object"); continue
        for k in ex:
            if k not in _EXPECTATION_KEYS:
                errs.append(f"{where}: unknown key {k!r}")
        probe = ex.get("probe")
        if (not isinstance(probe, list) or len(probe) != 2
                or not all(isinstance(v, (int, float)) for v in probe)):
            errs.append(f"{where}: 'probe' must be [x_frac, z_frac]")
        if ex.get("class") not in CLASS_NAMES:
            errs.append(f"{where}: 'class' must be one of {CLASS_NAMES}")
        if not ex.get("why"):
            errs.append(f"{where}: missing 'why'")
        if "evidence" in ex and ex["evidence"] not in ev_ids:
            errs.append(f"{where}: evidence id {ex['evidence']!r} not found")

    for i, t in enumerate(data.get("tests", [])):
        where = f"tests[{i}]"
        if not isinstance(t, dict):
            errs.append(f"{where} must be an object"); continue
        for k in t:
            if k not in _TEST_KEYS:
                errs.append(f"{where}: unknown key {k!r}")
        if not t.get("template"):
            errs.append(f"{where}: missing 'template'")
        if not isinstance(t.get("params", {}), dict):
            errs.append(f"{where}: 'params' must be an object")
        if not t.get("why"):
            errs.append(f"{where}: missing 'why'")

    for i, ki in enumerate(data.get("known_issues", [])):
        where = f"known_issues[{i}]"
        if not isinstance(ki, dict):
            errs.append(f"{where} must be an object"); continue
        for k in ki:
            if k not in _KNOWN_ISSUE_KEYS:
                errs.append(f"{where}: unknown key {k!r}")
        if not ki.get("check") or not ki.get("match"):
            errs.append(f"{where}: needs 'check' and 'match'")
        if not ki.get("why"):
            errs.append(f"{where}: missing 'why'")
        if "evidence" in ki and ki["evidence"] not in ev_ids:
            errs.append(f"{where}: evidence id {ki['evidence']!r} not found")
    return errs


def load(stem: str, profiles_dir: Path = PROFILES_DIR
         ) -> tuple[Optional[Profile], List[str]]:
    """(profile, errors). (None, []) = no profile exists — always valid."""
    path = profiles_dir / f"{stem}.json"
    if not path.is_file():
        return None, []
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        return None, [f"{path.name}: invalid JSON: {e}"]
    errs = validate(data, stem)
    if errs:
        return None, errs
    ov = data.get("overrides", {}).get("water_depth_m") or {}
    return Profile(
        map=stem, path=path, version=data["version"],
        script=data.get("script"), notes=data.get("notes", ""),
        evidence={e["id"]: e for e in data.get("evidence", [])},
        water_depth_m={k: float(v["value"]) for k, v in ov.items()},
        expectations=list(data.get("expectations", [])),
        tests=list(data.get("tests", [])),
        known_issues=list(data.get("known_issues", [])),
    ), []


def apply_known_issues(findings: List[Finding], prof: Optional[Profile]
                       ) -> List[Finding]:
    """Demote matching FAIL/WARN findings to INFO, visibly labeled — a
    known issue is suppressed from the gate, never hidden from the report."""
    if prof is None or not prof.known_issues:
        return findings
    for f in findings:
        if f.severity == "INFO":
            continue
        for ki in prof.known_issues:
            if f.check == ki["check"] and ki["match"] in f.message:
                f.details["suppressed_severity"] = f.severity
                f.severity = "INFO"
                f.message = f"[known: {ki['why']}] {f.message}"
                break
    return findings
