import os
from typing import Dict, Any, List
import xml.etree.ElementTree as ET

from utils import ROOT, snakecase, read_xml, write_xml
from output_handler import OutputHandler


class AbilityCloner:
    def __init__(self, config: Dict[str, Any], unit_info: Dict[str, Any]):
        self.config = config
        self.params = config["params"]
        self.sources = config["sources"]
        self.units = config["units"]
        self.unit_info = unit_info

    def _find_base_abilities_elem(self, base_name: str) -> ET.Element:
        primary, secondary = self.sources["ability_sources"]
        for path in (primary, secondary):
            abs_p = os.path.join(ROOT, path.replace("/", os.sep))
            tree = read_xml(abs_p)
            if not tree:
                continue
            root = tree.getroot()
            # Try typical structures
            # 1) <abilities><protounit name="Base">...</protounit></abilities>
            el = root.find(f".//protounit[@name='{base_name}']")
            if el is not None:
                return el
            # 2) <abilities><unit name="Base">...</unit></abilities>
            el = root.find(f".//unit[@name='{base_name}']")
            if el is not None:
                return el
        return None

    def _ability_exists_somewhere(self, ability_name: str) -> bool:
        primary, secondary = self.sources["ability_sources"]
        for path in (primary, secondary):
            abs_p = os.path.join(ROOT, path.replace("/", os.sep))
            tree = read_xml(abs_p)
            if not tree:
                continue
            root = tree.getroot()
            # Iterate abilities: match name attr OR text startswith (handles inline child tags)
            for ab in root.findall(".//ability"):
                if ab.get("name") == ability_name:
                    return True
                txt = ab.text.strip() if ab.text else ""
                if txt.startswith(ability_name):
                    return True
        return False

    def process(self) -> None:
        # If neither base nor new abilities, nothing to do
        base_name = self.units["proto_base"]
        new_name = self.units["proto_name"]

        base_el = self._find_base_abilities_elem(base_name)
        abilities_to_add: List[str] = self.params.get("abilities", []) or []

        if base_el is None and not abilities_to_add:
            return  # nothing to write

        out_root = ET.Element("abilities")
        target_protounit = ET.SubElement(out_root, "protounit")
        # Spec: use new proto_name using snakecase
        target_protounit.set("name", snakecase(new_name))

        if base_el is not None:
            # clone existing abilities tags into target
            for ab in base_el.findall("ability"):
                target_protounit.append(ET.Element("ability", ab.attrib))
                target_protounit.findall("ability")[-1].text = ab.text

        # Append any new abilities, validating existence
        missing: List[str] = []
        for ab_name in abilities_to_add:
            if not self._ability_exists_somewhere(ab_name):
                missing.append(ab_name)
                continue
            ab_el = ET.SubElement(target_protounit, "ability")
            ab_el.text = ab_name
            rof = ET.SubElement(ab_el, "rof")
            rof.text = "60"

        if missing:
            OutputHandler.missing_abilities(missing)

        # If after processing there are no abilities at all, don't write a file
        if len(list(target_protounit.findall("ability"))) == 0:
            return

        write_xml(out_root, "scripts/new_data/abilities/abilitymods.xml")
        OutputHandler.info("Wrote abilities to scripts/new_data/abilities/abilitymods.xml")
