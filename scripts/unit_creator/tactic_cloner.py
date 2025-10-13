import os
from typing import Dict, Any, Optional
from utils import ROOT, copy_file_respecting_tree


class TacticCloner:
    def __init__(self, config: Dict[str, Any], unit_info: Dict[str, Any]):
        self.config = config
        self.params = config["params"]
        self.sources = config["sources"]
        self.unit_info = unit_info

    def _find_tactic_source(self, filename: str) -> Optional[str]:
        # Search both tactic_sources for the given file name
        for folder in self.sources.get("tactic_sources", []):
            candidate = os.path.join(folder, filename)
            abs_path = os.path.join(ROOT, candidate.replace("/", os.sep))
            if os.path.isfile(abs_path):
                return candidate  # return relative to ROOT
        return None

    def process(self) -> None:
        if not self.params.get("new_tactics"):
            return
        if not self.params.get("generate_tactics_file"):
            return
        tactics_to_clone = self.params.get("tactics_to_clone")
        if not tactics_to_clone:
            raise Exception("Not able to find source for tactics_to_clone")
        src_rel = self._find_tactic_source(tactics_to_clone)
        if not src_rel:
            raise Exception("Not able to find source for tactics_to_clone")
        # Destination must be scripts/new_data/tactics/<new_tactics>
        dst_rel = os.path.join("scripts", "new_data", "tactics", self.params["new_tactics"]).replace("\\", "/")
        copy_file_respecting_tree(src_rel, dst_rel)
