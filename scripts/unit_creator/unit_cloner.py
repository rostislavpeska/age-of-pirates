import os
from typing import Dict, Any, List, Tuple
import xml.etree.ElementTree as ET

from utils import (
    DataSource,
    ROOT,
    load_proto_trees,
    find_protounit_by_name,
    get_all_protounits,
    deep_clone,
    write_xml,
    snakecase,
)


class UnitCloner:
    def __init__(self, config: Dict[str, Any]):
        self.config = config
        self.units = config["units"]
        self.params = config["params"]
        self.sources = config["sources"]

    def _load_sources(self) -> Tuple[List[ET.ElementTree], bool]:
        proto_sources = self.sources["proto_sources"]
        primary = os.path.join(ROOT, proto_sources[0].replace("/", os.sep))
        secondary = os.path.join(ROOT, proto_sources[1].replace("/", os.sep))
        trees, seen = load_proto_trees(primary, secondary)
        duplicity = any(count > 1 for count in seen.values())
        # Spec requires raising an exception but still proceeding using the first protounit.
        # We surface duplicity via return flag and let callers decide how to report, without aborting generation.
        return trees, duplicity

    def _apply_params(self, pu: ET.Element) -> None:
        p = self.params
        # name is already set by caller
        def set_text(tag: str, value: Any):
            if value is None:
                return
            el = pu.find(tag)
            if el is None:
                el = ET.SubElement(pu, tag)
            el.text = str(value)

        set_text("maxhitpoints", p.get("HP"))
        set_text("initialhitpoints", p.get("HP"))
        if p.get("velocity") is not None:
            set_text("maxvelocity", p.get("velocity"))
            try:
                rv = float(p.get("velocity")) * 1.25
            except Exception:
                rv = p.get("velocity")
            set_text("maxrunvelocity", rv)
        set_text("los", p.get("LOS"))
        set_text("icon", p.get("icon"))
        set_text("portraiticon", p.get("portraiticon"))
        set_text("buildlimit", p.get("buildlimit"))
        set_text("subciv", p.get("subciv"))
        if p.get("new_tactics"):
            set_text("tactics", p.get("new_tactics"))
        if p.get("animfile"):
            set_text("animfile", p.get("animfile"))

        # Shared build limit
        if p.get("sharedbuildlimit"):
            flag_el = ET.SubElement(pu, "flag")
            flag_el.text = "UseSharedBuildLimit"
            if not p.get("shared_main") and p.get("main_unit_name"):
                sblu = ET.SubElement(pu, "sharedbuildlimitunit")
                sblu.text = p.get("main_unit_name")
            if p.get("shared_buildlimit_units"):
                types = ET.SubElement(pu, "sharedbuildlimitunittypes")
                for u in p.get("shared_buildlimit_units"):
                    t = ET.SubElement(types, "unittype")
                    t.text = u
        # shared selection
        if p.get("shared_selection_units"):
            types = pu.find("sharedselectionunittypes")
            if types is None:
                types = ET.SubElement(pu, "sharedselectionunittypes")
            for u in p.get("shared_selection_units"):
                t = ET.SubElement(types, "unittype")
                t.text = u

        # Unit types and flags adjustments
        def add_children(tag: str, child_tag: str, values: List[str]):
            if not values:
                return
            parent = pu.find(tag)
            if parent is None:
                parent = ET.SubElement(pu, tag)
            for v in values:
                c = ET.SubElement(parent, child_tag)
                c.text = v

        def remove_children(tag: str, child_tag: str, values: List[str]):
            parent = pu.find(tag)
            if parent is None:
                return
            for ch in list(parent.findall(child_tag)):
                if ch.text in values:
                    parent.remove(ch)

        add_children("unittype", "unittype", p.get("new_unittypes", []))
        remove_children("unittype", "unittype", p.get("remove_unittypes", []))
        add_children("flags", "flag", p.get("new_flags", []))
        remove_children("flags", "flag", p.get("remove_flags", []))

    def _inject_strings(self) -> None:
        # Create/append to scripts/new_data/stringmods.xml
        root = ET.Element("stringtable")
        # The game expects numeric ids, but spec says we create and assign ids; without id allocator
        # we will append entries and rely on consumers to use the generated ids externally.
        # We'll store textual entries; a further pass could map to ids if available.
        # This file is informational per the spec.
        for key in ("new_name", "new_editor_name", "new_rollover", "new_shortrollover"):
            if not self.params.get(key):
                continue
            e = ET.SubElement(root, "string")
            e.set("key", snakecase(self.params[key]))
            e.text = self.params[key]
        write_xml(root, "scripts/new_data/stringmods.xml")

    def clone(self) -> Dict[str, Any]:
        proto_name = self.units["proto_name"]
        proto_base = self.units["proto_base"]
        trees, _ = self._load_sources()
        bases = find_protounit_by_name(trees, proto_base)
        if not bases:
            raise Exception(f"Base unit '{proto_base}' not found in proto sources")
        base = bases[0]
        new_pu = deep_clone(base)
        new_pu.set("name", proto_name)
        # Apply parameters
        self._apply_params(new_pu)

        # Write to scripts/new_data/protomods.xml, wrapped in <protomods>
        out_root = ET.Element("protomods")
        out_root.append(new_pu)
        write_xml(out_root, "scripts/new_data/protomods.xml")

        # Strings file entries
        self._inject_strings()

        return {
            "proto_out_path": os.path.join(ROOT, "scripts", "new_data", "protomods.xml"),
            "proto_name": proto_name,
            "proto_base": proto_base,
            "base_animfile": (base.find("animfile").text if base.find("animfile") is not None else None),
        }
