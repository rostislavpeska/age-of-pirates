"""Keep this device's local copies of repo maps in step with the repo (owner, 2026-09-24).

The repo (the remote, across devices) is the single source of truth for every map script. Some tools need a map as a
loose copy under another name in the Steam install's Game/RandMaps folder: the Scenario Editor lists only that
folder, so London is tested there as 00000_zplondon.xs (conftest.steam_twin pins the byte identity). Which copies a
device has is local, so it lives in the ignored config/local-maps.local.json (created from the tracked
config/local-maps.example.json on first use):

    {"maps": [{"repo": "randmaps/zplondon", "local": "00000_zplondon"}]}

Each entry covers <repo>.xs and <repo>.xml -> <RandMaps>/<local>.xs and .xml. The repo copy always wins: --sync
overwrites a local copy that differs.

A per-map .mods.xml NEVER belongs in the game root (owner 2026-10-06: "mods xml in game root is NONSENSE"): the mod
loads its own randmaps/<map>.mods.xml, a root copy is at best a redundant duplicate and crashed the game on 2026-09-19.
--check reports every Game/RandMaps/*.mods.xml as FORBIDDEN (exit 1); --sync, the hook and the post-merge hook delete it.

    python scripts/tools/sync_local_maps.py [--check]        every copy: OK / EOL / STALE / MISSING, and FORBIDDEN for a
                                                              root .mods.xml (exit 1 unless all OK)
                                                              EOL = same content, only the line endings differ
    python scripts/tools/sync_local_maps.py --sync           copy the repo file over every stale or missing copy and
                                                              delete every root .mods.xml
    python scripts/tools/sync_local_maps.py --add randmaps/zpparis 00000_zpparis     register one, then sync it
    python scripts/tools/sync_local_maps.py --top game/randmaps/zpdanube    THE MAP UNDER TEST: register it with one
                                                              more leading zero than any map in the folder, so it is
                                                              row 2 of the editor's Type list (right under Blank), and
                                                              sync it. --add and --top both print the row.
    python scripts/tools/sync_local_maps.py --hook           Claude Code PostToolUse: sync the entry of an edited map
    python scripts/tools/sync_local_maps.py --install-git-hook   .git/hooks/post-merge runs --sync after every pull

Runs automatically: the PostToolUse hook in .claude/settings.json after an agent edits a registered map, and the
post-merge git hook (installed once per device) after every pull, so a map edited on another device reaches this
device's copy. Without a game install on the machine every command is a no-op that says so.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import sys
from pathlib import Path
from typing import Dict, List, Optional

REPO = Path(__file__).resolve().parents[2]
EXAMPLE = REPO / "config" / "local-maps.example.json"
LOCAL = REPO / "config" / "local-maps.local.json"
EXTS = (".xs", ".xml")
GIT_HOOK = """#!/bin/sh
# installed by scripts/tools/sync_local_maps.py --install-git-hook: refresh this device's local map copies after a pull
python scripts/tools/sync_local_maps.py --sync || true
"""


def randmaps_dir() -> Optional[Path]:
    """<install>/Game/RandMaps, found as scripts/mapcheck/locate finds the install (AOE3DE_GAME, then Steam)."""
    sys.path.insert(0, str(REPO))
    from scripts.mapcheck.locate import game_install
    g = game_install()
    return (g / "RandMaps") if g else None


def load_registry(path: Path = LOCAL, example: Path = EXAMPLE) -> Dict:
    """The device's registry; created from the example on first use."""
    if not path.is_file():
        data = json.loads(example.read_text(encoding="utf-8")) if example.is_file() else {"maps": []}
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(data, indent=1) + "\n", encoding="utf-8")
        print(f"created {path.relative_to(REPO) if path.is_relative_to(REPO) else path} from the example")
    data = json.loads(path.read_text(encoding="utf-8"))
    for e in data.get("maps", []):
        if not (isinstance(e, dict) and e.get("repo") and e.get("local")):
            raise ValueError(f"{path}: every entry needs 'repo' and 'local', got {e!r}")
        if e["repo"].endswith(EXTS) or e["local"].endswith(EXTS):
            raise ValueError(f"{path}: give stems without .xs / .xml, got {e!r}")
    return data


def _sha(p: Path, eol_blind: bool = False) -> Optional[str]:
    """sha256 of the bytes; eol_blind hashes the content with CRLF read as LF (a GitHub download is LF)."""
    if not p.is_file():
        return None
    b = p.read_bytes()
    return hashlib.sha256(b.replace(b"\r\n", b"\n") if eol_blind else b).hexdigest()


def pairs(entry: Dict, rm: Path, repo: Path = REPO) -> List[tuple]:
    """[(repo file, local file)] of one entry - only the files the repo has."""
    out = []
    for ext in EXTS:
        src = repo / (entry["repo"] + ext)
        if src.is_file():
            out.append((src, rm / (entry["local"] + ext)))
    return out


def status(entries: List[Dict], rm: Path, repo: Path = REPO) -> List[Dict]:
    rows = []
    for e in entries:
        ps = pairs(e, rm, repo)
        if not ps:
            rows.append({"entry": e, "src": None, "dst": None, "state": "NO REPO FILE"})
        for src, dst in ps:
            d = _sha(dst)
            if d is None:
                state = "MISSING"
            elif d == _sha(src):
                state = "OK"
            else:                                # same text, other line endings is not a content change
                state = "EOL" if _sha(dst, True) == _sha(src, True) else "STALE"
            rows.append({"entry": e, "src": src, "dst": dst, "state": state})
    for p in sorted(rm.glob("*.mods.xml")):      # never in the game root (module docstring)
        rows.append({"entry": None, "src": None, "dst": p, "state": "FORBIDDEN"})
    return rows


def sync(entries: List[Dict], rm: Path, repo: Path = REPO, quiet: bool = False) -> List[Dict]:
    rows = status(entries, rm, repo)
    for r in rows:
        if r["state"] in ("STALE", "MISSING", "EOL"):   # EOL too: the copy takes the repo's CRLF bytes
            shutil.copyfile(r["src"], r["dst"])
            print(f"[local maps] {r['dst'].name} <- {r['src'].relative_to(repo).as_posix()} ({r['state'].lower()})")
            r["state"] = "SYNCED"
        elif r["state"] == "FORBIDDEN":
            r["dst"].unlink()
            print(f"[local maps] {r['dst'].name} deleted: a .mods.xml never belongs in the game root")
            r["state"] = "REMOVED"
    if not quiet:
        _print(rows, repo)
    return rows


def _print(rows: List[Dict], repo: Path) -> None:
    for r in rows:
        src = r["src"].relative_to(repo).as_posix() if r["src"] else (r["entry"]["repo"] if r["entry"] else "(game root)")
        dst = r["dst"].name if r["dst"] else r["entry"]["local"]
        print(f"  {r['state']:<12} {src} -> {dst}")


def editor_order(rm: Path) -> List[str]:
    """The Scenario Editor's Type list under Blank: the folder's maps, sorted case-insensitively (2026-10-07: row 2
    00000000_zpdanube, then 0000000_areaprobe, 000000_destrbench_..., 00000_zpatols before 00000_zpBalearicIslands)."""
    return sorted((p.stem for p in rm.glob("*.xs") if p.with_suffix(".xml").is_file()), key=str.lower)


def editor_row(local: str, rm: Path) -> int:
    """1-based row of a local copy in the editor's Type list (row 1 is Blank)."""
    return editor_order(rm).index(local) + 2


def top_stem(stem: str, rm: Path, entries: List[Dict]) -> str:
    """The local stem that puts the map under test on row 2, right under Blank: its own copy when one already sits
    there, else one more leading zero than any map in the folder (owner 2026-10-07: a Danube copy registered as
    00000_zpdanube sat among 49 other 00000_ maps and every test generation scrolled for it)."""
    order = editor_order(rm)
    if order and any(e["repo"] == stem and e["local"] == order[0] for e in entries):
        return order[0]
    zeros = max((len(n) - len(n.lstrip("0")) for n in order), default=0)
    return "0" * (zeros + 1) + "_" + stem.rsplit("/", 1)[-1]


def hook(payload: Dict, entries: List[Dict], rm: Path, repo: Path = REPO) -> List[Dict]:
    """PostToolUse: the entries whose repo file was just written get synced; everything else is ignored."""
    ti = payload.get("tool_input") or {}
    paths = [ti.get("file_path")] if ti.get("file_path") else []
    paths += [e.get("file_path") for e in ti.get("edits") or [] if isinstance(e, dict) and e.get("file_path")]
    hit = []
    for p in paths:
        try:
            rel = Path(os.path.abspath(p)).relative_to(repo).as_posix()
        except ValueError:
            continue
        stem = rel.rsplit(".", 1)[0] if rel.endswith(EXTS) else None
        hit += [e for e in entries if stem and e["repo"] == stem and e not in hit]
    return sync(hit, rm, repo, quiet=True) if hit else []


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    g = ap.add_mutually_exclusive_group()
    g.add_argument("--check", action="store_true")
    g.add_argument("--sync", action="store_true")
    g.add_argument("--add", nargs=2, metavar=("REPO_STEM", "LOCAL_STEM"))
    g.add_argument("--top", metavar="REPO_STEM", help="register the map under test on row 2 of the editor's list")
    g.add_argument("--hook", action="store_true")
    g.add_argument("--install-git-hook", action="store_true")
    a = ap.parse_args(argv)
    if a.install_git_hook:
        h = REPO / ".git" / "hooks" / "post-merge"
        h.write_text(GIT_HOOK, encoding="utf-8", newline="\n")
        print(f"installed {h} (runs --sync after every pull)")
        return 0
    if a.hook:
        try:
            payload = json.load(sys.stdin)
        except Exception:                        # a hook never blocks the tool call
            return 0
    rm = randmaps_dir()
    if rm is None or not rm.is_dir():
        if not a.hook:
            print("no AoE3DE install on this machine (AOE3DE_GAME / Steam): no local map copies to keep")
        return 0
    reg = load_registry()
    if a.add or a.top:
        stem, local = (s.rsplit(".", 1)[0] if s.endswith(EXTS) else s for s in (a.add or [a.top, a.top]))
        if not any((REPO / (stem + ext)).is_file() for ext in EXTS):
            print(f"no {stem}.xs / .xml in the repo")
            return 1
        if a.top:
            local = top_stem(stem, rm, reg["maps"])
        reg["maps"] = [e for e in reg["maps"] if e["local"] != local] + [{"repo": stem, "local": local}]
        LOCAL.write_text(json.dumps(reg, indent=1) + "\n", encoding="utf-8")
        print(f"registered {stem} -> {local}")
        sync([{"repo": stem, "local": local}], rm)
        row = editor_row(local, rm)
        print(f"{local}: row {row} of the Scenario Editor's Type list"
              + ("" if row <= 2 else f" - a map under test belongs on row 2: --top {stem}"))
        return 0
    if a.hook:
        hook(payload, reg["maps"], rm)
        return 0
    if a.sync:
        rows = sync(reg["maps"], rm)
        return 0 if all(r["state"] in ("OK", "SYNCED", "REMOVED") for r in rows) else 1
    rows = status(reg["maps"], rm)
    _print(rows, REPO)
    return 0 if all(r["state"] == "OK" for r in rows) else 1


if __name__ == "__main__":
    sys.exit(main())
