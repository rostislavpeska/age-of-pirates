import os
import re
import shutil
from typing import List, Tuple, Dict, Optional
import xml.etree.ElementTree as ET

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

class DataSource:
    def __init__(self, primary: str, secondary: str):
        self.primary = os.path.join(ROOT, primary.replace("/", os.sep))
        self.secondary = os.path.join(ROOT, secondary.replace("/", os.sep))

    def as_list(self) -> List[str]:
        return [self.primary, self.secondary]


def ensure_dirs(paths: List[str]) -> None:
    for p in paths:
        ap = os.path.join(ROOT, p.replace("/", os.sep))
        os.makedirs(ap, exist_ok=True)


def snakecase(name: str) -> str:
    s = re.sub(r"[^a-zA-Z0-9]+", "_", name).strip("_")
    return s.lower()


def read_xml(path: str) -> Optional[ET.ElementTree]:
    if not os.path.isfile(path):
        return None
    try:
        return ET.parse(path)
    except ET.ParseError:
        return None


def write_xml(root_el: ET.Element, target_rel_path: str) -> None:
    target_abs = os.path.join(ROOT, target_rel_path.replace("/", os.sep))
    os.makedirs(os.path.dirname(target_abs), exist_ok=True)
    tree = ET.ElementTree(root_el)
    ET.indent(tree, space="  ", level=0)  # Python 3.9+
    tree.write(target_abs, encoding="utf-8", xml_declaration=True)


def copy_file_respecting_tree(src_rel: str, dst_rel: str) -> None:
    src = os.path.join(ROOT, src_rel.replace("/", os.sep))
    dst = os.path.join(ROOT, dst_rel.replace("/", os.sep))
    if not os.path.isfile(src):
        raise FileNotFoundError(src)
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    shutil.copy2(src, dst)


def find_first_existing(paths: List[str]) -> Optional[str]:
    for p in paths:
        ap = os.path.join(ROOT, p.replace("/", os.sep))
        if os.path.isfile(ap):
            return ap
    return None


def find_files_with_suffix(folders: List[str], suffix: str) -> List[str]:
    found = []
    for f in folders:
        base = os.path.join(ROOT, f.replace("/", os.sep))
        if not os.path.isdir(base):
            continue
        for root, _, files in os.walk(base):
            for name in files:
                if name.lower().endswith(suffix.lower()):
                    found.append(os.path.join(root, name))
    return found


def load_proto_trees(primary: str, secondary: str) -> Tuple[List[ET.ElementTree], Dict[str, int]]:
    trees: List[ET.ElementTree] = []
    seen: Dict[str, int] = {}
    for idx, p in enumerate([primary, secondary]):
        t = read_xml(p)
        if not t:
            continue
        trees.append(t)
        for pu in t.getroot().iterfind(".//protounit"):
            name = pu.attrib.get("name", "")
            if not name:
                continue
            if name in seen:
                seen[name] += 1
            else:
                seen[name] = 1
    return trees, seen


def get_all_protounits(trees: List[ET.ElementTree]) -> List[ET.Element]:
    acc: List[ET.Element] = []
    for t in trees:
        acc.extend(list(t.getroot().iterfind(".//protounit")))
    return acc


def find_protounit_by_name(trees: List[ET.ElementTree], name: str) -> List[ET.Element]:
    res: List[ET.Element] = []
    for t in trees:
        for pu in t.getroot().iterfind(".//protounit[@name='%s']" % name):
            res.append(pu)
    return res


def deep_clone(element: ET.Element) -> ET.Element:
    clone = ET.Element(element.tag, element.attrib)
    clone.text = element.text
    for child in list(element):
        clone.append(deep_clone(child))
    return clone
