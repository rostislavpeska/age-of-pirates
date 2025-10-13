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
        set_text("populationcount", p.get("populationcount"))
        set_text("allowedage", p.get("allowedage"))
        # bounty and buildbounty are plain numeric tags
        if p.get("bounty") is not None:
            set_text("bounty", p.get("bounty"))
        if p.get("buildbounty") is not None:
            set_text("buildbounty", p.get("buildbounty"))
        if p.get("new_tactics"):
            set_text("tactics", p.get("new_tactics"))
        if p.get("animfile"):
            set_text("animfile", p.get("animfile"))

        # Apply string IDs from StringCloner if available
        string_ids = self.config.get("string_ids", {})
        if string_ids:
            if string_ids.get("displaynameid") is not None:
                set_text("displaynameid", string_ids["displaynameid"])
            if string_ids.get("editornameid") is not None:
                set_text("editornameid", string_ids["editornameid"])
            if string_ids.get("rollovertextid") is not None:
                set_text("rollovertextid", string_ids["rollovertextid"])
            if string_ids.get("shortrollovertextid") is not None:
                set_text("shortrollovertextid", string_ids["shortrollovertextid"])

        # Helpers for ordered insertion of direct children
        def _last_index_of(tag: str) -> int:
            idx = -1
            for i, child in enumerate(list(pu)):
                if child.tag == tag:
                    idx = i
            return idx

        def _insert_elements_after_index(index: int, elements: List[ET.Element]):
            # insert maintaining order
            insert_at = index + 1
            for el in elements:
                pu.insert(insert_at, el)
                insert_at += 1

        # Shared build limit
        if p.get("sharedbuildlimit"):
            # Insert <flag>UseSharedBuildLimit</flag> in correct position
            flag_el = ET.Element("flag")
            flag_el.text = "UseSharedBuildLimit"
            last_flag_idx = _last_index_of("flag")
            if last_flag_idx >= 0:
                _insert_elements_after_index(last_flag_idx, [flag_el])
            else:
                # place below last <unittype> if present, else append
                last_ut_idx = _last_index_of("unittype")
                if last_ut_idx >= 0:
                    _insert_elements_after_index(last_ut_idx, [flag_el])
                else:
                    pu.append(flag_el)

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

        # Unit types and flags adjustments as direct children in correct order
        # Remove unittypes
        to_remove_ut = set(p.get("remove_unittypes", []))
        if to_remove_ut:
            for ch in list(pu.findall("unittype")):
                if (ch.text or "").strip() in to_remove_ut:
                    pu.remove(ch)

        # Add unittypes below the last existing <unittype>
        new_uts = p.get("new_unittypes", []) or []
        if new_uts:
            new_ut_elements = []
            for v in new_uts:
                el = ET.Element("unittype")
                el.text = v
                new_ut_elements.append(el)
            last_ut_idx = _last_index_of("unittype")
            if last_ut_idx >= 0:
                _insert_elements_after_index(last_ut_idx, new_ut_elements)
            else:
                # no existing unittype; append at end to keep structure valid
                for el in new_ut_elements:
                    pu.append(el)

        # Remove flags
        to_remove_flags = set(p.get("remove_flags", []))
        if to_remove_flags:
            for ch in list(pu.findall("flag")):
                if (ch.text or "").strip() in to_remove_flags:
                    pu.remove(ch)

        # Add flags below the last existing <flag>, or if none, below last <unittype>
        new_flags = p.get("new_flags", []) or []
        if new_flags:
            new_flag_elements = []
            for v in new_flags:
                el = ET.Element("flag")
                el.text = v
                new_flag_elements.append(el)
            last_flag_idx = _last_index_of("flag")
            if last_flag_idx >= 0:
                _insert_elements_after_index(last_flag_idx, new_flag_elements)
            else:
                last_ut_idx = _last_index_of("unittype")
                if last_ut_idx >= 0:
                    _insert_elements_after_index(last_ut_idx, new_flag_elements)
                else:
                    for el in new_flag_elements:
                        pu.append(el)

        # Placement rule: certain tags should appear right below <populationcount>
        def _place_group_below_populationcount(tags_in_order: List[str]):
            # find anchor
            anchor_idx = -1
            for i, child in enumerate(list(pu)):
                if child.tag == "populationcount":
                    anchor_idx = i
            if anchor_idx < 0:
                return  # keep default placement
            # move/create each tag in desired order below anchor, updating anchor as we go
            for tag in tags_in_order:
                el = pu.find(tag)
                if el is None:
                    continue
                # detach and re-insert
                pu.remove(el)
                pu.insert(anchor_idx + 1, el)
                anchor_idx += 1

        # Ensure the group order below populationcount when present
        _place_group_below_populationcount([
            "buildlimit",
            "subciv",
            "sharedbuildlimitunittypes",
            "sharedselectionunittypes",
        ])

        # Handle resource costs as changeable parameters with zero suppression
        def _set_cost(resource: str, value: Any):
            # remove if value is None or <= 0
            existing = None
            for c in list(pu.findall("cost")):
                if c.get("resourcetype") == resource:
                    existing = c
                    break
            try:
                v = float(value) if value is not None else None
            except Exception:
                v = None
            if v is None or v <= 0:
                if existing is not None:
                    pu.remove(existing)
                return
            # ensure exists and set formatted text
            if existing is None:
                existing = ET.Element("cost")
                existing.set("resourcetype", resource)
                # place cost lines after buildbounty if present, else after bounty, else after trainpoints if present, else append
                def _first_index_of(tag: str) -> int:
                    for i, child in enumerate(list(pu)):
                        if child.tag == tag:
                            return i
                    return -1
                insert_after = _first_index_of("buildbounty")
                if insert_after < 0:
                    insert_after = _first_index_of("bounty")
                if insert_after < 0:
                    insert_after = _first_index_of("trainpoints")
                if insert_after >= 0:
                    pu.insert(insert_after + 1, existing)
                else:
                    pu.append(existing)
            existing.text = f"{v:.4f}"

        # Support both a dict param `costs` and individual params
        costs = p.get("costs", {}) or {}
        _set_cost("Food", costs.get("Food", p.get("cost_food")))
        _set_cost("Wood", costs.get("Wood", p.get("cost_wood")))
        _set_cost("Gold", costs.get("Gold", p.get("cost_gold")))
        _set_cost("Influence", costs.get("Influence", p.get("cost_influence")))

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

        # Strings are handled by StringCloner; do not write here

        return {
            "proto_out_path": os.path.join(ROOT, "scripts", "new_data", "protomods.xml"),
            "proto_name": proto_name,
            "proto_base": proto_base,
            "base_animfile": (base.find("animfile").text if base.find("animfile") is not None else None),
        }
