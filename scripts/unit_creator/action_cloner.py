import os
from typing import Dict, Any, List
import xml.etree.ElementTree as ET

from utils import ROOT, load_proto_trees, find_protounit_by_name, deep_clone, read_xml, write_xml


class ActionCloner:
    def __init__(self, config: Dict[str, Any], unit_info: Dict[str, Any]):
        self.config = config
        self.params = config["params"]
        self.sources = config["sources"]
        self.units = config["units"]
        self.unit_info = unit_info

    def _load_proto_sources(self):
        proto_sources = self.sources["proto_sources"]
        primary = os.path.join(ROOT, proto_sources[0].replace("/", os.sep))
        secondary = os.path.join(ROOT, proto_sources[1].replace("/", os.sep))
        trees, _ = load_proto_trees(primary, secondary)
        return trees

    def _load_new_unit_doc(self) -> ET.ElementTree:
        out_path = os.path.join(ROOT, "scripts", "new_data", "protomods.xml")
        tree = read_xml(out_path)
        if not tree:
            # If not present, create a skeleton
            root = ET.Element("protomods")
            tree = ET.ElementTree(root)
        return tree

    def _get_new_unit_el(self, tree: ET.ElementTree) -> ET.Element:
        name = self.units["proto_name"]
        el = tree.getroot().find(f".//protounit[@name='{name}']")
        if el is None:
            # Create new if missing (shouldn't happen normally because UnitCloner wrote it)
            el = ET.SubElement(tree.getroot(), "protounit")
            el.set("name", name)
        return el

    def _clone_action_from(self, trees: List[ET.ElementTree], clonefrom: str, action_name: str) -> ET.Element:
        bases = find_protounit_by_name(trees, clonefrom)
        if not bases:
            raise Exception("clonefrom unit is not defined")
        base = bases[0]
        src = base.find(f".//protoaction[@name='{action_name}']")
        if src is None:
            raise Exception("Not able to find action defined for the clonefrom unit")
        return deep_clone(src)

    def process(self) -> None:
        add_actions: List[Dict[str, Any]] = self.params.get("add_proto_actions", []) or []
        rem_actions: List[str] = self.params.get("remove_proto_actions", []) or []
        if not add_actions and not rem_actions:
            return

        new_tree = self._load_new_unit_doc()
        new_unit_el = self._get_new_unit_el(new_tree)

        # Handle additions
        if add_actions:
            trees = self._load_proto_sources()
            for entry in add_actions:
                action_name = None
                clonefrom = None
                if isinstance(entry, dict):
                    action_name = entry.get("name")
                    clonefrom = entry.get("clonefrom")
                elif isinstance(entry, (list, tuple)) and len(entry) == 2:
                    action_name, clonefrom = entry[0], entry[1]
                if not clonefrom:
                    raise Exception("clonefrom unit is not defined")
                if not action_name:
                    continue
                cloned = self._clone_action_from(trees, clonefrom, action_name)
                new_unit_el.append(cloned)

        # Handle removals
        for name in rem_actions:
            for child in list(new_unit_el.findall("protoaction")):
                if child.get("name") == name:
                    new_unit_el.remove(child)

        write_xml(new_tree.getroot(), "scripts/new_data/protomods.xml")
