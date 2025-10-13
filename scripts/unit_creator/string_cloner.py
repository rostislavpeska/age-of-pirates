import os
import xml.etree.ElementTree as ET
from typing import Dict, Any

from utils import ROOT, write_xml, ensure_dirs


class StringCloner:
    def __init__(self, config: Dict[str, Any]):
        self.config = config
        self.params = config["params"]
        self.start_id = int(config.get("starting_string_id", 80000))

    def process(self) -> Dict[str, int]:
        # Prepare output path scripts/newd_ata/stringmods.xml (per user spec)
        ensure_dirs(["scripts/new_data/"])
        root = ET.Element("stringtable")

        next_id = self.start_id
        id_map: Dict[str, int] = {}

        def add_string(key_config: str, out_key: str):
            nonlocal next_id
            val = self.params.get(key_config)
            if not val:
                return
            el = ET.SubElement(root, "string")
            el.set("_locid", str(next_id))
            el.text = val
            id_map[out_key] = next_id
            next_id += 1

        # Order: new_name, new_editor_name, new_rollover, new_shortrollover
        add_string("new_name", "displaynameid")
        add_string("new_editor_name", "editornameid")
        add_string("new_rollover", "rollovertextid")
        add_string("new_shortrollover", "shortrollovertextid")

        # Write output
        write_xml(root, "scripts/new_data/stringmods.xml")
        return id_map
