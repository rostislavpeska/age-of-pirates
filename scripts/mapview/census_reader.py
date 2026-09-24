"""The saved generation (.age3Yscn) as world objects: census id, proto, world metres, fractions, owner; the map size.

Only Scenario Editor saves (.age3Yscn) are supported. An in-match save (.age3Ysav) carries its record header at
tag-62 / tag-63 (wf verify M2, 2026-09-24), outside HEADER_TRY: nothing decodes there and read() returns [].

THE RECORD LAYOUT (measured 2026-09-24, wf_twin_review F1). The container is 'l33t', u32 uncompressed size, zlib from
byte 8. Every unit is found by its 'UN' chunk; its position sits in a fixed header BEFORE the chunk:

    tag-B-20         u16 owner         the player (0 = gaia), base 'header' offset -20 (OWNER below)
    tag-B            float x, y, z     world metres (x east, z north, y height)
    tag-B+12         3x3 orientation   9 floats, orthonormal rows
    tag-1            (B = 49 only)     one byte, 0xFF in every record seen
    tag              'UN'
    tag+2            u32 chunk size    = 4 + idlen in every record seen
    tag+6            u32 idlen         the id string's length including its NUL
    tag+10           the census id     decimal digits + NUL
    tag+10+idlen     u32 proto         the engine's runtime proto INDEX (see name_table), the 'post-id base'

B = 49 on the current build, 48 on older builds. A header is accepted where the 36 bytes after xyz form an orthonormal
3x3 (row norms within 1e-3 of 1, rows orthogonal within 1e-3); B is tried 49, 48, then 44..60 nearest to 49 first.
Every record of every save at hand validated at exactly one offset in 44..60:
    <profile>/Scenario/LondonIndivUnitIDs (4p London, 2026-09-22)       8967/8967 at 49
    <profile>/Scenario/mapview_london4p_live (4p London, 2026-09-24)    10375/10375 at 49
    sandbox/census/samples/bench/*.age3Yscn (4 saves, 2026-09-17)        26/26 at 49
    sandbox/census/samples/census_elbe_* (6), census_istanbul, census_tortuga_01, Crownlands / Hansa Groupings
    (2026-08, older build)                                                all at 48
Proof on London: TownCenter 8385 (40.0954, 147.7606) = the EU_SPC_Player_London anchor (42, 150) + its TC member
(-1.9046, -2.2394); the Keeps = the Tower_01 / Tower_02 anchors + (-0.2764, 0.9881) / (0.2764, -0.9881); the four
zpOrientalFerry posts on the harbour spots. The first and the last record are read; the map size never filters, it
only sets `in_map`. Until 2026-09-24 sandbox/census/census.py took the first plausible float triple AFTER the tag,
which is the NEXT record's header: every position belonged to the next record in file order and the last record was
dropped. census.parse_units now reads through `decode` here.

SKEWED HEADERS (wf verify M1, measured 2026-09-24). A few records carry a slightly tilted 3x3 that fails the 1e-3
test: row norms exact, one dot product 0.0039 (ypSPCIndianFortGate, index 1199, on the Istanbul beach saves, B = 49 on
census_istanbulcity_s4242 and ~testing) or 0.012 (zpAustralianCavalry / Settler pairs on Rome, Italian Wars, the
Istanbul groupings saves, B = 48) - 30 records in 15 of 406 saves, never more than 6 in one. When no offset passes
the strict test, the save's dominant B is used if xyz is finite, the row norms are within ORTHO_TOL and every |dot|
is at most SKEW_TOL (0.05); such records are decoded with `skewed` set and counted in read_stats()['skewed'].

THE MAP SIZE (map_size; measured 2026-09-24 on 413 saves: <profile>/Scenario, sandbox/census/samples, the session's
generations, five .age3Ysav - exactly one hit each). The terrain header, right after a UTF-16 terrain-texture name:

    int32 tiles_x, int32 tiles_z, float32 metres per tile (2.0 in every save), float32 (8.0 on random-map
    generations, 4.0 on blank editor maps), then the 'TT' chunk: u32 size = 4 + tiles_x * tiles_z, u32 tiles_x * tiles_z

The engine rounds rmSetMapSize up to whole tiles: London 4p asks 360 x 685 and holds 180 x 343 tiles = 360 x 686 m;
Paris asks 653 and holds 327 tiles = 654 m. The engine converts fractions with the rounded size: on
mapview_london4p_live the grouping anchors' z residual (measured - asked) is at most 1.50 m with mapsim's 685 m and
at most 1.00 m (the even-metre snap) with 686 m (scripts/mapview/twin.py uses the save's size, 2026-09-24).

NAMES (name_table). The save stores the runtime proto index: vanilla units by position in the CURRENT protoy (the
mapcheck --live cache, else the scripts/source snapshot), then every mod unit whose name is not vanilla, in the order
of data/protomods.xml.xmb - what the game loads, comments are not in it - from base = vanilla count +
census.MOD_BASE_OFFSET. The XML (ElementTree, comments ignored) is the fallback. 2026-09-24: XMB = ElementTree = 1179
mod units; the raw-text regex used before counted 1258 (79 inside comments) and misnamed 48 indices from 3657 up.
The table is today's files, not the ones the game loaded when it saved: read_stats records both sources with their
sha1 and warns when a source is newer than the save (the bench save's index 2820 was zpNatInuitHarpooner on
2026-09-17 and reads zpNautilusProxy on 2026-09-24), and when a record's index lies outside today's table: such a
record reads 'unknown(N)', never an XML id's name (wf verify L1).

OWNER (adopted 2026-09-24: OWNER_OFFSET -20, OWNER_BASE 'header'). Offsets have two bases: 'header' = the record's
header start (tag-B, the x float; negative offsets reach the bytes before it, which begin with u32 76 at -32 in every
London and Elbe record) and 'post_id' = tag+10+idlen (the proto u32). Fields after the id string shift with its digit
count, so a tag-relative offset found on 4-digit ids would read another byte for every other id length. Evidence:
  - find_owner_offset on the LondonIndivUnitIDs town centres (owners 1, 2, 3, 4) returns exactly [('header', -20)];
    the u16 there is 0 on 8888 records and 1..4 on 79, all per-player content: TownCenter, Barracks, Church, Market,
    Stable, deTavern, LivestockPen, SPCFlag, zpAIStartUrbanMap one per player, Explorer 3 and deMineCoalBuildable 2
    per player, the walls' SPCFortGate / deSPCEuroTower on players 1 and 3, AIStart 2 / 3 / 4;
  - mapview_london4p_live (2026-09-24 12:07, lobby colours p1 blue, p2 red, p3 yellow, p4 purple): the same single
    hit; Explorers 8270 (43, 545) = 1, 8659 (189, 537) = 2, 9047 (55, 153) = 3, 9436 (175, 153) = 4 and TownCenters
    7884 (40.10, 531.76) = 1, 8273 (176.10, 531.76) = 2, 8661 (40.10, 145.76) = 3, 9050 (176.10, 145.76) = 4 - the
    stars of the player colours on the editor minimap;
  - census_elbe_01 (older build, B = 48): TownCenter 1..4, AIStart 2..4; the bench saves: TownCenter 1 / 2, House 1,
    the subject 1.
read() returns it as 'player' (0 = gaia); owner_offset=None turns it off.

    python scripts/mapview/census_reader.py <save.age3Yscn> [--size 360x686] [--protos TownCenter,Explorer]
    python scripts/mapview/census_reader.py <save.age3Yscn> --stats
    python scripts/mapview/census_reader.py <save.age3Yscn> --find-owner TownCenter --owners 1,2,3,4
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import math
import os
import re
import struct
import sys
import xml.etree.ElementTree as ET
import zlib
from collections import Counter
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Optional, Sequence, Tuple

REPO = Path(__file__).resolve().parents[2]
if str(REPO) not in sys.path:
    sys.path.insert(0, str(REPO))

HEADER_TRY: Tuple[int, ...] = (49, 48) + tuple(sorted((b for b in range(44, 61) if b not in (48, 49)),
                                                      key=lambda b: (abs(b - 49), b)))
ORTHO_TOL = 1e-3
SKEW_TOL = 0.05                         # a skewed header: |dot| of two rows at most this (measured max 0.0124)
OWNER_OFFSET: Optional[int] = -20       # u16 at the header start - 20 (see OWNER in the docstring)
OWNER_BASE: Optional[str] = "header"    # 'header' (from tag-B) or 'post_id' (from tag+10+idlen)
OWNER_BASES = ("header", "post_id")
XMB_TOOLS = REPO / ".claude" / "skills" / "aoe3de-bar-archives" / "scripts"
_UNIT_NAME = re.compile(r'<unit\b[^>]*\bname\s*=\s*"([^"]+)"')
_COMMENT = re.compile(r"<!--.*?-->", re.S)


# ----------------------------------------------------------------------------- records
@dataclass
class Record:
    census_id: str                      # the record's own id string (the editor's unit id)
    proto_id: int                       # runtime proto index
    tag: int                            # offset of 'UN' in the decompressed stream
    idlen: int                          # id string length including its NUL
    back: Optional[int]                 # B: the header starts at tag-B; None = no orthonormal header found
    x: float
    y: float
    z: float
    rot: Optional[Tuple[float, ...]]    # the 3x3, row-major
    skewed: bool = False                # decoded at the save's dominant B with |dot| <= SKEW_TOL (not orthonormal)

    @property
    def header(self) -> Optional[int]:
        """Offset of the x float (base 'header'); None when undecoded."""
        return None if self.back is None else self.tag - self.back

    @property
    def post_id(self) -> int:
        """Offset of the proto u32 (base 'post_id')."""
        return self.tag + 10 + self.idlen

    @property
    def decoded(self) -> bool:
        return self.back is not None


def decompress(save: Path) -> bytes:
    raw = Path(save).read_bytes()
    if raw[:4] != b"l33t":
        raise ValueError("not an l33t-compressed file: %s" % save)
    return zlib.decompress(raw[8:])


def scan_tags(data: bytes) -> List[Tuple[int, int, str, int]]:
    """[(tag, idlen, census_id, proto_id)] for every 'UN' chunk whose id is decimal digits + NUL (the scan
    census.py used since 2026-08; the proto u32 follows the id string)."""
    out = []
    i, n = 0, len(data)
    while True:
        i = data.find(b"UN", i)                          # the byte-by-byte scan's hits, without the Python loop
        if i < 0 or i >= n - 12:
            return out
        idlen = struct.unpack_from("<I", data, i + 6)[0]
        if 2 <= idlen <= 12 and i + 14 + idlen <= n:
            sid = data[i + 10:i + 10 + idlen]
            if sid[-1] == 0 and all(48 <= c <= 57 for c in sid[:-1]):
                proto = struct.unpack_from("<I", data, i + 10 + idlen)[0]
                out.append((i, idlen, sid[:-1].decode(), proto))
                i += 10 + idlen
                continue
        i += 1


def _rows(data: bytes, at: int) -> Optional[Tuple[Tuple[float, ...], ...]]:
    if at < 0 or at + 36 > len(data):
        return None
    m = struct.unpack_from("<9f", data, at)
    if not all(math.isfinite(v) for v in m):
        return None
    return (m[0:3], m[3:6], m[6:9])


def _frame_ok(data: bytes, at: int, dot_tol: float) -> bool:
    """The 9 floats from `at`: rows of unit length within ORTHO_TOL, mutually orthogonal within dot_tol."""
    rows = _rows(data, at)
    if rows is None:
        return False
    for r in rows:
        if abs(math.sqrt(r[0] * r[0] + r[1] * r[1] + r[2] * r[2]) - 1.0) > ORTHO_TOL:
            return False
    for a, b in ((0, 1), (0, 2), (1, 2)):
        if abs(sum(p * q for p, q in zip(rows[a], rows[b]))) > dot_tol:
            return False
    return True


def _orthonormal(data: bytes, at: int) -> bool:
    """The 9 floats from `at` form an orthonormal 3x3 (rows unit length and mutually orthogonal within ORTHO_TOL)."""
    return _frame_ok(data, at, ORTHO_TOL)


def _xyz_finite(data: bytes, at: int) -> bool:
    return 0 <= at and at + 12 <= len(data) and all(math.isfinite(v) for v in struct.unpack_from("<3f", data, at))


def header_back(data: bytes, tag: int, order: Sequence[int] = HEADER_TRY) -> Optional[int]:
    """B such that tag-B holds finite xyz followed by an orthonormal 3x3; the first hit in `order`, None if none."""
    for b in order:
        at = tag - b
        if at < 0:
            continue
        if _orthonormal(data, at + 12) and _xyz_finite(data, at):
            return b
    return None


def records(data: bytes) -> List[Record]:
    """Every tagged record at its OWN header position. A record no offset validates strictly is read at the save's
    dominant B when its 3x3 is only slightly skewed (docstring: SKEWED HEADERS; `skewed` set); otherwise NaN and
    back=None."""
    out = []
    order = HEADER_TRY
    for tag, idlen, sid, proto in scan_tags(data):
        b = header_back(data, tag, order)
        if b is None:
            out.append(Record(sid, proto, tag, idlen, None, math.nan, math.nan, math.nan, None))
            continue
        if b != order[0]:                                # one save = one layout: try its offset first from now on
            order = (b,) + tuple(o for o in HEADER_TRY if o != b)
        x, y, z = struct.unpack_from("<3f", data, tag - b)
        out.append(Record(sid, proto, tag, idlen, b, x, y, z, struct.unpack_from("<9f", data, tag - b + 12)))
    backs = Counter(r.back for r in out if r.back is not None)
    if backs and len(out) > sum(backs.values()):           # some record failed the strict test
        dom = backs.most_common(1)[0][0]
        for r in out:
            if r.back is None:
                at = r.tag - dom
                if _xyz_finite(data, at) and _frame_ok(data, at + 12, SKEW_TOL):
                    r.back, r.skewed = dom, True
                    r.x, r.y, r.z = struct.unpack_from("<3f", data, at)
                    r.rot = struct.unpack_from("<9f", data, at + 12)
    return out


def decode(save: Path) -> List[Record]:
    return records(decompress(Path(save)))


# ----------------------------------------------------------------------------- map size
_TT = b"TT"


def terrain_headers(data: bytes) -> List[Tuple[int, int, int, float, float]]:
    """[(offset, tiles_x, tiles_z, metres per tile, second float)] of every terrain header in the stream: int32
    tiles_x, int32 tiles_z, float32 tile metres, float32, then 'TT' + u32 (4 + tiles_x*tiles_z) + u32 tiles_x*tiles_z
    (docstring: THE MAP SIZE)."""
    out = []
    t = data.find(_TT, 16)
    while t != -1:
        if t + 10 <= len(data):
            tx, tz, tile_m, second = struct.unpack_from("<iiff", data, t - 16)
            size, cells = struct.unpack_from("<II", data, t + 2)
            if 0 < tx <= 100000 and 0 < tz <= 100000 and cells == tx * tz and size == cells + 4 \
                    and math.isfinite(tile_m) and 0.0 < tile_m <= 64.0:
                out.append((t - 16, tx, tz, tile_m, second))
        t = data.find(_TT, t + 1)
    return out


def map_size_of(data: bytes) -> Optional[Tuple[float, float]]:
    """(size_x_m, size_z_m) = tiles x metres per tile from the stream's terrain header; None unless exactly one."""
    hits = terrain_headers(data)
    if len(hits) != 1:
        return None
    _at, tx, tz, tile_m, _second = hits[0]
    return tx * tile_m, tz * tile_m


def map_size(save: Path) -> Optional[Tuple[float, float]]:
    """The map size the engine generated, in metres (x, z), from the save's terrain header; None when the save holds
    no single terrain header. London 4p (rmSetMapSize 360 x 685) = (360.0, 686.0)."""
    return map_size_of(decompress(Path(save)))


# ----------------------------------------------------------------------------- names
_NAME_CACHE: Dict[tuple, Tuple[Dict[int, str], Dict]] = {}
_BARTOOL = None


def _sig(p: Optional[Path]):
    if p is None or not p.is_file():
        return None
    st = p.stat()
    return (str(p), st.st_mtime_ns, st.st_size)


def _sha1(p: Optional[Path]) -> Optional[str]:
    return hashlib.sha1(p.read_bytes()).hexdigest() if p is not None and p.is_file() else None


def _bartool():
    global _BARTOOL
    if _BARTOOL is None:
        spec = importlib.util.spec_from_file_location("aop_census_bartool", XMB_TOOLS / "bartool.py")
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        _BARTOOL = mod
    return _BARTOOL


def unit_names_xml(path: Path) -> List[str]:
    """Names of <unit name=...> elements in document order; comments ignored. ElementTree, or the regex on the
    comment-stripped text when the file does not parse."""
    text = Path(path).read_text(encoding="utf-8", errors="replace")
    try:
        root = ET.fromstring(text.encode("utf-8"))
    except ET.ParseError:
        return _UNIT_NAME.findall(_COMMENT.sub("", text))
    return [u.get("name") for u in root.iter("unit") if u.get("name") is not None]


def unit_names_xmb(path: Path) -> List[str]:
    """Names of <unit name=...> elements of a compiled .xmb (alz4 or raw X1), document order."""
    bt = _bartool()
    root = bt.xmb_to_element(bt.unwrap_alz4(Path(path).read_bytes()))
    return [u.get("name") for u in root.iter("unit") if u.get("name") is not None]


SNAPSHOT_PROTOY = REPO / "scripts" / "source" / "protoy.xml"


def vanilla_source() -> Optional[Path]:
    """The vanilla protoy the runtime indices count through: the mapcheck --live cache, else that cache built now
    from the game's Data.bar (scripts/refdata/catalogs._live_proto_path, the same code), else the repo snapshot.
    The snapshot lags every DLC: on 2026-09-24 it held 2456 units against the build's 2673, so on a device that had
    never run mapcheck --live (the 2880x1800 test machine) every mod index read 217 places off and the twin of a
    correct London save matched 6 of 35 key objects."""
    live = Path(os.environ.get("LOCALAPPDATA", "")) / "aoe3-mapcheck" / "protoy_live.xml"
    if os.environ.get("LOCALAPPDATA") and live.is_file():
        return live
    try:
        from scripts.refdata import catalogs
        built = catalogs._live_proto_path(force=True)
    except Exception:                                            # no game install / no archive tools: the snapshot
        built = None
    if built is not None and Path(built).is_file():
        return Path(built)
    return SNAPSHOT_PROTOY if SNAPSHOT_PROTOY.is_file() else None


def name_table(mod_base_offset: int = 0, vanilla: Optional[Path] = None,
               protomods_dir: Optional[Path] = None) -> Tuple[Dict[int, str], Dict]:
    """(runtime index -> name, info). info: vanilla_source, vanilla_sha1, vanilla_units, protomods_source,
    protomods_sha1, mod_units, mod_base, warnings. Cached per source file (path, mtime, size)."""
    van = Path(vanilla) if vanilla is not None else vanilla_source()
    pdir = Path(protomods_dir) if protomods_dir is not None else REPO / "data"
    xmb, xml = pdir / "protomods.xml.xmb", pdir / "protomods.xml"
    key = (_sig(van), _sig(xmb), _sig(xml), mod_base_offset)
    if key in _NAME_CACHE:
        table, info = _NAME_CACHE[key]
        return dict(table), dict(info, warnings=list(info["warnings"]))
    info = {"vanilla_source": van, "vanilla_sha1": None, "vanilla_units": 0, "protomods_source": None,
            "protomods_sha1": None, "mod_units": 0, "mod_base": None, "warnings": []}
    if van is None or not van.is_file():
        info["warnings"].append("no vanilla protoy (mapcheck --live cache or scripts/source/protoy.xml): no names")
        _NAME_CACHE[key] = ({}, info)
        return {}, dict(info, warnings=list(info["warnings"]))
    names = unit_names_xml(van)
    info.update(vanilla_sha1=_sha1(van), vanilla_units=len(names))
    if van.resolve() == SNAPSHOT_PROTOY.resolve():
        info["warnings"].append("vanilla names from the repo snapshot %s (%d units), which lags every DLC: every mod "
                                "index after it reads shifted - run mapcheck --live, or give the game install"
                                % (SNAPSHOT_PROTOY.name, len(names)))
    table = {i: n for i, n in enumerate(names)}
    vset = set(names)
    mods, src = None, None
    if xmb.is_file():
        try:
            mods, src = unit_names_xmb(xmb), xmb
        except Exception as e:                                   # a corrupt or foreign .xmb: fall back to the XML
            info["warnings"].append("protomods.xml.xmb unreadable (%s): names from the XML" % e)
    if mods is None and xml.is_file():
        mods, src = unit_names_xml(xml), xml
    if mods is not None:
        base = len(names) + mod_base_offset
        k = 0
        for n in mods:
            if n not in vset:
                table[base + k] = n
                k += 1
        info.update(protomods_source=src, protomods_sha1=_sha1(src), mod_units=k, mod_base=base)
    else:
        info["warnings"].append("no data/protomods.xml(.xmb): mod units unnamed")
    _NAME_CACHE[key] = (dict(table), info)
    return table, dict(info, warnings=list(info["warnings"]))


# ----------------------------------------------------------------------------- reader
_CENSUS = None


def _census_module():
    """sandbox/census/census.py (proto_names, MOD_BASE_OFFSET), loaded once."""
    global _CENSUS
    if _CENSUS is None:
        spec = importlib.util.spec_from_file_location("aop_census", REPO / "sandbox" / "census" / "census.py")
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        _CENSUS = mod
    return _CENSUS


def _namer():
    """(index -> name, info, runtime table). An index outside a non-empty runtime table reads 'unknown(N)': the XML
    ids (census.proto_names) name vanilla records by id, not by runtime index, and would give a wrong vanilla name
    (wf verify L1). Only without any runtime table (no vanilla protoy at all) do they stand in."""
    census = _census_module()
    by_rt, info = name_table(getattr(census, "MOD_BASE_OFFSET", 0))
    if by_rt:
        return (lambda pid: by_rt.get(pid) or "unknown(%d)" % pid), info, by_rt
    by_id, by_dbid = census.proto_names()
    return (lambda pid: by_id.get(pid) or by_dbid.get(pid) or "unknown(%d)" % pid), info, by_rt


def _check_owner_field(owner_offset: Optional[int], owner_base: Optional[str]):
    if owner_offset is not None and owner_base not in OWNER_BASES:
        raise ValueError("owner_offset %r needs owner_base in %s, got %r" % (owner_offset, OWNER_BASES, owner_base))


def _field_at(data: bytes, rec: Record, base: str, offset: int) -> Optional[int]:
    start = rec.header if base == "header" else rec.post_id
    if start is None:
        return None
    at = start + offset
    return struct.unpack_from("<H", data, at)[0] if 0 <= at <= len(data) - 2 else None


def read(save: Path, size_x_m: Optional[float] = None, size_z_m: Optional[float] = None,
         owner_offset: Optional[int] = OWNER_OFFSET, owner_base: Optional[str] = OWNER_BASE) -> List[Dict]:
    """Every decoded record: {census_id, proto, proto_id, x_m, y_m, z_m, fx, fz, in_map, player, skewed} (+ 'id',
    the same census id, for older callers). player = the owner u16 (0 = gaia; None with owner_offset=None). With the
    map size, fx/fz are fractions (outside 0..1 for a unit off the map) and in_map is 0 <= x <= size_x and
    0 <= z <= size_z; without it all three are None (map_size(save) reads the size the engine generated). Nothing is
    filtered by the size. Records without a valid header are left out: their count is read_stats()['undecoded'] (and
    `read.dropped` after the call)."""
    _check_owner_field(owner_offset, owner_base)
    save = Path(save)
    data = decompress(save)
    recs = records(data)
    name, _info, _table = _namer()
    sized = bool(size_x_m) and bool(size_z_m)
    if sized:
        from scripts.mapview.transform import world_to_frac
    out, dropped = [], 0
    for r in recs:
        if not r.decoded:
            dropped += 1
            continue
        fx = fz = in_map = None
        if sized:
            fx, fz = world_to_frac(r.x, r.z, size_x_m, size_z_m)
            in_map = 0.0 <= r.x <= size_x_m and 0.0 <= r.z <= size_z_m
        player = _field_at(data, r, owner_base, owner_offset) if owner_offset is not None else None
        out.append({"census_id": r.census_id, "id": r.census_id, "proto": name(r.proto_id), "proto_id": r.proto_id,
                    "x_m": r.x, "y_m": r.y, "z_m": r.z, "fx": fx, "fz": fz, "in_map": in_map, "player": player,
                    "skewed": r.skewed})
    read.dropped = dropped
    return out


read.dropped = 0


def read_stats(save: Path) -> Dict:
    """{records, decoded, undecoded, skewed, header_offset (the B most records use, None if none decoded),
    header_offsets {B: n}, map_size_m [x, z] (None without a single terrain header), map_tiles [x, z], tile_m,
    unnamed (records whose index lies outside today's runtime table), protomods_source, protomods_sha1,
    vanilla_source, vanilla_sha1, mod_units, vanilla_units, save_sha1, warnings}. A warning names each name source
    newer than the save (its runtime indices may have moved since) and the records outside the runtime table."""
    save = Path(save)
    raw = save.read_bytes()
    data = decompress(save)
    recs = records(data)
    backs = Counter(r.back for r in recs if r.decoded)
    _name, info, table = _namer()
    warnings = list(info["warnings"])
    saved = save.stat().st_mtime
    for k in ("vanilla_source", "protomods_source"):
        p = info[k]
        if p is not None and Path(p).is_file() and Path(p).stat().st_mtime > saved:
            warnings.append("%s %s is newer than the save: runtime indices after its first edit may be renamed"
                            % (k.split("_")[0], Path(p).name))
    unnamed = sorted({r.proto_id for r in recs if table and r.proto_id not in table})
    if unnamed:
        warnings.append("%d records carry %d proto indices outside today's runtime table (%d entries, first %s): "
                        "the protomods the game loaded differ from today's - they read unknown(N)"
                        % (sum(1 for r in recs if r.proto_id in set(unnamed)), len(unnamed), len(table),
                           unnamed[:5]))
    hits = terrain_headers(data)
    one = hits[0] if len(hits) == 1 else None
    decoded = sum(backs.values())
    return {"records": len(recs), "decoded": decoded, "undecoded": len(recs) - decoded,
            "skewed": sum(1 for r in recs if r.skewed),
            "header_offset": backs.most_common(1)[0][0] if backs else None,
            "header_offsets": dict(backs),
            "map_size_m": [one[1] * one[3], one[2] * one[3]] if one else None,
            "map_tiles": [one[1], one[2]] if one else None, "tile_m": one[3] if one else None,
            "unnamed": len(unnamed),
            "protomods_source": str(info["protomods_source"]) if info["protomods_source"] else None,
            "protomods_sha1": info["protomods_sha1"],
            "vanilla_source": str(info["vanilla_source"]) if info["vanilla_source"] else None,
            "vanilla_sha1": info["vanilla_sha1"], "vanilla_units": info["vanilla_units"],
            "mod_units": info["mod_units"], "save_sha1": hashlib.sha1(raw).hexdigest(), "warnings": warnings}


# ----------------------------------------------------------------------------- owner search
def _owners(save: Path, base: str, offset: int) -> Dict[str, int]:
    """{census_id: u16 at base+offset} for every decoded record."""
    _check_owner_field(offset, base)
    data = decompress(Path(save))
    out = {}
    for r in records(data):
        v = _field_at(data, r, base, offset)
        if v is not None:
            out[r.census_id] = v
    return out


def find_owner_offset(save: Path, proto: str, owners: Sequence[int], lo: int = -64,
                      hi: int = 420) -> List[Tuple[str, int]]:
    """[(base, offset)] at which the records of `proto` carry exactly the multiset `owners` as a u16. Bases: 'header'
    (offsets lo .. B+9 from tag-B: the bytes before x, the header, the 'UN' chunk up to the id string) and 'post_id'
    (offsets 0 .. hi-1 from tag+10+idlen). Use on a save whose owners are known, e.g. a London generation with 4
    players and TownCenter, owners 1,2,3,4. 2026-09-24 on LondonIndivUnitIDs and mapview_london4p_live:
    [('header', -20)] (the tag-relative search before, -64..419 from the tag, never reached it and found nothing)."""
    data = decompress(Path(save))
    name, _info, _table = _namer()
    recs = [r for r in records(data) if r.decoded and name(r.proto_id) == proto]
    want = Counter(int(o) for o in owners)
    if not recs:
        return []
    hits = []
    back = min(r.back for r in recs)
    for base, rng in (("header", range(lo, back + 10)), ("post_id", range(0, hi))):
        for k in rng:
            vals = [_field_at(data, r, base, k) for r in recs]
            if all(v is not None for v in vals) and Counter(vals) == want:
                hits.append((base, k))
    return hits


# ----------------------------------------------------------------------------- CLI
def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("save")
    ap.add_argument("--size", default=None, help="map size WxL in metres (default: the save's own terrain header)")
    ap.add_argument("--protos", default=None, help="comma list: print only these protos")
    ap.add_argument("--stats", action="store_true", help="records, header offsets, map size, name sources with sha1")
    ap.add_argument("--find-owner", default=None, metavar="PROTO")
    ap.add_argument("--owners", default=None, help="expected owners of that proto's records, e.g. 1,2,3,4")
    a = ap.parse_args(argv)
    save = Path(a.save)
    if a.find_owner:
        if not a.owners:
            raise SystemExit("--find-owner needs --owners")
        hits = find_owner_offset(save, a.find_owner, [int(x) for x in a.owners.split(",")])
        print("owner offset candidates for %s: %s" % (a.find_owner, hits or "none"))
        return 0
    if a.stats:
        for k, v in read_stats(save).items():
            print("%-17s %s" % (k, v))
        return 0
    sx = sz = None
    if a.size:
        sx, sz = (float(x) for x in a.size.lower().split("x"))
    else:
        got = map_size(save)
        if got:
            sx, sz = got
    units = read(save, sx, sz)
    want = set(a.protos.split(",")) if a.protos else None
    off = sum(1 for u in units if u["in_map"] is False)
    print("%s: %d units with positions (%d undecoded, %d skewed)%s" % (
        save.name, len(units), read.dropped, sum(1 for u in units if u["skewed"]),
        (", map %g x %g m%s, %d outside" % (sx, sz, "" if a.size else " (the save's)", off)) if sx else ""))
    counts = Counter(u["proto"] for u in units)
    for proto, n in counts.most_common():
        if want and proto not in want:
            continue
        print("%5d  %s" % (n, proto))
    if want:
        for u in units:
            if u["proto"] in want:
                print("  %-6s %-32s x %8.3f z %8.3f  player %s  frac %s%s%s" % (
                    u["census_id"], u["proto"], u["x_m"], u["z_m"], u["player"],
                    "(%.4f, %.4f)" % (u["fx"], u["fz"]) if u["fx"] is not None else "-",
                    "  OFF MAP" if u["in_map"] is False else "", "  skewed" if u["skewed"] else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
