import os
from typing import Dict, Any, Optional

from utils import ROOT, copy_file_respecting_tree


class AnimCloner:
    def __init__(self, config: Dict[str, Any], unit_info: Dict[str, Any]):
        self.config = config
        self.params = config["params"]
        self.sources = config["sources"]
        self.units = config["units"]
        self.unit_info = unit_info

    def _resolve_anim_source(self, anim_rel_path: str) -> Optional[str]:
        # anim_sources are folders; anim_to_clone is a relative path under one of them
        for base in self.sources.get("anim_sources", []):
            candidate = os.path.join(base, anim_rel_path).replace("\\", "/")
            abs_c = os.path.join(ROOT, candidate.replace("/", os.sep))
            if os.path.isfile(abs_c):
                return candidate
        return None

    def _clone_from_base_if_needed(self) -> None:
        # When no animfile parameter is provided, clone animations from base unit
        if self.params.get("animfile"):
            return
        base_anim = self.unit_info.get("base_animfile")
        if not base_anim:
            return
        # Copy base anim file into scripts/new_art/<base_anim>
        dst_rel = os.path.join("scripts", "new_art", base_anim).replace("\\", "/")
        # Source is under data/anim/<base_anim>
        src_rel = os.path.join("data", "anim", base_anim).replace("\\", "/")
        try:
            copy_file_respecting_tree(src_rel, dst_rel)
        except FileNotFoundError:
            # If base anim file isn't present, skip silently
            return

    def process(self) -> None:
        # 1) Clone from base if no explicit animfile specified
        self._clone_from_base_if_needed()

        # 2) If generate_anim_file is true, create new anim file into scripts/new_art/... using anim_to_clone as source
        if not self.params.get("generate_anim_file"):
            return
        anim_to_clone = self.params.get("anim_to_clone")
        if not anim_to_clone:
            raise Exception("Not able to find source for anim_to_clone")
        src_rel = self._resolve_anim_source(anim_to_clone)
        if not src_rel:
            raise Exception("Not able to find source for anim_to_clone")
        # Destination uses path defined by animfile
        dest_animfile = self.params.get("animfile")
        if not dest_animfile:
            # respect structure, mirror source to scripts/new_art/ if target not provided
            dest_animfile = anim_to_clone
        dst_rel = os.path.join("scripts", "new_art", dest_animfile).replace("\\", "/")
        copy_file_respecting_tree(src_rel, dst_rel)
