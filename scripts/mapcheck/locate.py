"""Map script location (plan Part G2).

Maps live in two roots: the mod repo (game/randmaps/*.xs) and the game
install's RandMaps folder, where this project's development maps sit as
loose files (000_independence_war.xs, zp_z_z_zcivilwar2.xs ...). An explicit
path wins; a bare name searches both roots. The install is found the same
way the bar-extract skill finds it: AOE3DE_GAME env var, then the standard
Steam location.
"""

from __future__ import annotations

import os
from pathlib import Path
from typing import Optional

REPO_ROOT = Path(__file__).resolve().parents[2]
MOD_RANDMAPS = REPO_ROOT / "game" / "randmaps"

_STEAM_CANDIDATES = (
    Path("C:/Program Files (x86)/Steam/steamapps/common/AoE3DE/Game"),
    Path("C:/Program Files/Steam/steamapps/common/AoE3DE/Game"),
    Path("D:/Steam/steamapps/common/AoE3DE/Game"),
    Path("D:/SteamLibrary/steamapps/common/AoE3DE/Game"),
)


def game_install() -> Optional[Path]:
    env = os.environ.get("AOE3DE_GAME")
    if env and Path(env).is_dir():
        return Path(env)
    for cand in _STEAM_CANDIDATES:
        if cand.is_dir():
            return cand
    return None


def resolve_map(name_or_path: str) -> Path:
    p = Path(name_or_path)
    if p.suffix.lower() == ".xs" and p.is_file():
        return p
    stem = p.stem if p.suffix else name_or_path
    roots = [MOD_RANDMAPS]
    install = game_install()
    if install:
        roots.append(install / "RandMaps")
    tried = []
    for root in roots:
        cand = root / f"{stem}.xs"
        tried.append(str(cand))
        if cand.is_file():
            return cand
        if root.is_dir():
            # case-insensitive fallback (zpBalearicIslands vs zpbalearicislands)
            for f in root.glob("*.xs"):
                if f.stem.lower() == stem.lower():
                    return f
    raise FileNotFoundError(
        f"map {name_or_path!r} not found; tried: {tried}")
