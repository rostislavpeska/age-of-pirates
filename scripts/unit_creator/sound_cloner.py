import os
import xml.etree.ElementTree as ET
from typing import Dict, Any, Optional

from utils import ROOT, read_xml, write_xml


class SoundCloner:
    def __init__(self, config: Dict[str, Any], unit_info: Dict[str, Any]):
        self.config = config
        self.params = config["params"]
        self.sources = config["sources"]
        self.units = config["units"]
        self.unit_info = unit_info

    def _find_sound_file_for_unit(self, unit: str) -> Optional[str]:
        # search in sound_sources for file named unitname_snds.xml
        candidates = []
        for folder in self.sources.get("sound_sources", []):
            rel = os.path.join(folder, f"{unit.lower()}_snds.xml").replace("\\", "/")
            abs_p = os.path.join(ROOT, rel.replace("/", os.sep))
            candidates.append((rel, abs_p))
        for rel, abs_p in candidates:
            if os.path.isfile(abs_p):
                return rel
        return None

    def process(self) -> None:
        base_unit = self.units["proto_base"]
        new_unit = self.units["proto_name"]
        source_unit = self.params.get("sound_unit") or base_unit

        rel_src = self._find_sound_file_for_unit(source_unit)
        if not rel_src:
            # Nothing to clone; silently skip if file doesn't exist anywhere
            return
        abs_src = os.path.join(ROOT, rel_src.replace("/", os.sep))
        tree = read_xml(abs_src)
        if not tree:
            return
        root = tree.getroot()

        # Update protounit name to new unit name
        for pu in root.findall(".//protounit"):
            pu.set("name", new_unit)

        # Write into scripts/new_sounds/<new>_snds.xml
        out_rel = os.path.join("scripts", "new_sounds", f"{new_unit.lower()}_snds.xml").replace("\\", "/")
        write_xml(root, out_rel)
