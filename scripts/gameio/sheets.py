"""UI coordinate sheets: scripts/gameio/sheets/<W>x<H>.json, one per client size (created 2026-09-24).

A sheet holds namespaces (menu, editor, match, minimap); each point is
    {"x": .., "y": .., "rgb": [r, g, b]?, "also": {"x", "y", "rgb"}?, "space": "client" | "screen",
     "provenance": "measured YYYY-MM-DD <how>" | "screenshot <file> ..." | "derived <how>", ...extras}
Keys starting with '_' (at the top or inside a namespace) are notes, never points; Sheet.note(ns, name) returns a
namespace note (menu._layout: the home-menu frame lines that screens.menu_layout_ok compares). The loader refuses a point
without a valid provenance or space; Sheet.point refuses a DERIVED point unless allow_derived=True, because the old
sheets mixed measured and guessed points without saying which (scripts/aitest/coords/2560x1080_default.json:
quit_yes 'derived', minimap_center undocumented and ~80 px off).

This store is new and separate: scripts/aitest/coords/*.json and sandbox/census/census_run.py sheet C stay as they
are (other device's campaign, 2026-09-24).
"""
from __future__ import annotations

import copy
import json
import re
from pathlib import Path
from typing import Dict, List, Optional

SHEETS_DIR = Path(__file__).resolve().parent / "sheets"
PROVENANCE_RE = re.compile(r"^(measured \d{4}-\d{2}-\d{2} \S.*|screenshot \S.*|derived \S.*)$", re.S)
SPACES = ("client", "screen")


class DerivedPoint(ValueError):
    """The point is derived, not measured: pass allow_derived=True to use it anyway."""


def _check_rgb(v, where: str) -> None:
    if not (isinstance(v, list) and len(v) == 3 and all(isinstance(c, int) and 0 <= c <= 255 for c in v)):
        raise ValueError(f"{where}: rgb must be [r, g, b] with 0..255 ints, got {v!r}")


def validate_point(name: str, p: Dict) -> None:
    if not isinstance(p, dict):
        raise ValueError(f"{name}: a point must be an object")
    for k in ("x", "y"):
        if not isinstance(p.get(k), (int, float)) or isinstance(p.get(k), bool):
            raise ValueError(f"{name}: '{k}' must be a number")
    if p.get("space") not in SPACES:
        raise ValueError(f"{name}: space must be one of {SPACES}, got {p.get('space')!r}")
    prov = p.get("provenance")
    if not isinstance(prov, str) or not PROVENANCE_RE.match(prov):
        raise ValueError(f"{name}: provenance must start 'measured YYYY-MM-DD <how>', 'screenshot <file>' or "
                         f"'derived <how>', got {prov!r}")
    if "rgb" in p and p["rgb"] is not None:
        _check_rgb(p["rgb"], name)
    also = p.get("also")
    if also is not None:
        if not isinstance(also, dict) or not all(isinstance(also.get(k), (int, float)) for k in ("x", "y")):
            raise ValueError(f"{name}: 'also' must be {{x, y, rgb}}")
        _check_rgb(also.get("rgb"), name + ".also")


class Sheet:
    def __init__(self, data: Dict, path: Optional[Path] = None):
        self.path = path
        self.size = tuple(data.get("size") or ())
        self.notes = {k: v for k, v in data.items() if k.startswith("_")}
        self.ns_notes: Dict[str, Dict] = {}
        self.points: Dict[str, Dict] = {}
        for ns, body in data.items():
            if ns.startswith("_") or ns == "size":
                continue
            if not isinstance(body, dict):
                raise ValueError(f"{path}: namespace {ns!r} must be an object")
            for name, p in body.items():
                if name.startswith("_"):
                    self.ns_notes.setdefault(ns, {})[name] = p
                    continue
                full = f"{ns}.{name}"
                validate_point(full, p)
                self.points[full] = p

    def names(self) -> List[str]:
        return sorted(self.points)

    def _resolve(self, name: str) -> str:
        if name in self.points:
            return name
        hits = [k for k in self.points if k.split(".", 1)[1] == name]
        if len(hits) == 1:
            return hits[0]
        if hits:
            raise KeyError(f"{name!r} is ambiguous: {hits}")
        raise KeyError(f"no point {name!r} in {self.path} (has: {', '.join(self.names())})")

    def note(self, ns: str, name: str):
        """A deep copy of the namespace note ns.name (e.g. note('menu', '_layout')); KeyError when absent."""
        try:
            return copy.deepcopy(self.ns_notes[ns][name])
        except KeyError:
            raise KeyError(f"no note {ns}.{name} in {self.path}") from None

    def is_derived(self, name: str) -> bool:
        return self.points[self._resolve(name)]["provenance"].startswith("derived")

    def point(self, name: str, allow_derived: bool = False) -> Dict:
        """'menu.skirmish' (or a bare name that is unique across namespaces) -> a copy of the point with its
        'name' added. A derived point raises DerivedPoint unless allow_derived."""
        full = self._resolve(name)
        p = self.points[full]
        if p["provenance"].startswith("derived") and not allow_derived:
            raise DerivedPoint(f"{full} is derived, not measured ({p['provenance']}) - measure it, or pass "
                               f"allow_derived=True")
        out = copy.deepcopy(p)
        out["name"] = full
        return out


def sheet_path(width: int, height: int, folder: Optional[Path] = None) -> Path:
    return Path(folder or SHEETS_DIR) / f"{int(width)}x{int(height)}.json"


def load_sheet(width: int, height: int, folder: Optional[Path] = None) -> Sheet:
    """The sheet for a client area of width x height; FileNotFoundError when none exists (the driver never
    guesses pixel positions for an unmeasured size), ValueError when a point is malformed."""
    path = sheet_path(width, height, folder)
    if not path.is_file():
        raise FileNotFoundError(f"no coordinate sheet {path} for a {width}x{height} client area - measure one")
    data = json.loads(path.read_text(encoding="utf-8"))
    sheet = Sheet(data, path)
    if sheet.size and tuple(sheet.size) != (int(width), int(height)):
        raise ValueError(f"{path} says size {list(sheet.size)}, not {width}x{height}")
    return sheet
