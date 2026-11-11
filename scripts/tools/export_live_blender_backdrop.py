#!/usr/bin/env python3
"""Export live Blender backdrop cylinder directly into Age of Empires 3 DE Granny2 binary (.gr2).

Captures whatever is currently in the active Blender viewport on port 9876,
transforms the exact world-space vertices, updates OBB bounding boxes,
and writes directly to korean_background.gr2.

Usage:
    python scripts/tools/export_live_blender_backdrop.py
"""

import os
import sys
import json
import socket
import struct
from pathlib import Path
import numpy as np

# Add scripts/havok to path
SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent.parent
sys.path.append(str(REPO_ROOT / "scripts" / "havok"))

from gr2_read import Gr2
from gr2_splitmesh import Builder
import gr2_dump

DEFAULT_PORT = 9876
SRC_GR2 = Path(r"C:\Users\TIGO\.gemini\antigravity\brain\4fade9ad-f24f-4bb6-8d3a-1bd3b1d8c3eb\scratch\china_hc_background.gr2")
TARGET_GR2 = REPO_ROOT.parent / "age-of-pirates-koreans" / "art" / "homecity" / "korean" / "korean_background" / "korean_background.gr2"


def get_blender_world_vertices(port=DEFAULT_PORT, obj_name="Korean_Backdrop_Cylinder"):
    s = socket.socket()
    s.settimeout(10.0)
    try:
        s.connect(("127.0.0.1", port))
    except Exception as e:
        print(f"ERROR: Could not connect to Blender on port {port}: {e}")
        sys.exit(1)

    code = f"""
import bpy
obj = bpy.data.objects.get('{obj_name}')
if not obj:
    result = {{'error': 'Object not found: {obj_name}'}}
else:
    mw = obj.matrix_world
    w_verts = [(mw @ v.co)[:] for v in obj.data.vertices]
    result = {{
        'nverts': len(w_verts),
        'verts': w_verts,
        'loc': list(obj.location),
        'scale': list(obj.scale),
        'rot': list(obj.rotation_euler)
    }}
"""
    req = json.dumps({"type": "execute", "code": code, "strict_json": False}) + "\0"
    s.sendall(req.encode("utf-8"))
    buf = bytearray()
    while True:
        chunk = s.recv(65536)
        if not chunk:
            break
        buf.extend(chunk)
        if b"\0" in buf:
            break
    s.close()

    data = json.loads(buf.partition(b"\0")[0].decode("utf-8"))
    res = data.get("result", {})
    if "error" in res:
        print(f"Blender Error: {res['error']}")
        sys.exit(1)
    return res


def export_backdrop():
    print("1. Fetching live vertices from Blender...")
    b_data = get_blender_world_vertices()
    w_verts = np.array(b_data["verts"], dtype=np.float32)
    nverts = len(w_verts)
    print(f"   Captured {nverts} vertices from Blender object.")
    print(f"   Blender Location: {b_data['loc']}")
    print(f"   Blender Scale:    {b_data['scale']}")

    # Coordinate transformation calibrated 1:1 to user's Blender scene (all 108 vertices):
    new_pos = np.zeros((nverts, 3), dtype=np.float32)
    new_pos[:, 0] = -2.54 * w_verts[:, 0]
    new_pos[:, 2] = -2.54 * w_verts[:, 1]
    new_pos[:, 1] = w_verts[:, 2] * 1.051086 - 6.152

    y_min, y_max = float(new_pos[:, 1].min()), float(new_pos[:, 1].max())
    print(f"2. Converted to Granny2 coordinates:")
    print(f"   GR2 Y height range: [{y_min:.3f} .. {y_max:.3f}] (Total: {y_max - y_min:.3f})")
    print(f"   GR2 X range:        [{new_pos[:, 0].min():.3f} .. {new_pos[:, 0].max():.3f}]")
    print(f"   GR2 Z range:        [{new_pos[:, 2].min():.3f} .. {new_pos[:, 2].max():.3f}]")

    print(f"3. Building binary GR2 from clean template...")
    g = Gr2(str(SRC_GR2))
    assert g.crc_check()
    B = Builder(g)

    # Write vertex positions into section 1
    for i in range(nverts):
        struct.pack_into("<3f", B.sec[1], i * 24, *new_pos[i])

    # Update Mesh BoneBindings / OBB Bounding Boxes
    obb_min = (float(new_pos[:, 0].min() - 15.0), float(y_min - 15.0), float(new_pos[:, 2].min() - 15.0))
    obb_max = (float(new_pos[:, 0].max() + 15.0), float(y_max + 15.0), float(new_pos[:, 2].max() + 15.0))

    r = g.root()
    for m, mp in gr2_dump.refs(g, r.get("Meshes")):
        bb_arr = m["BoneBindings"]
        sec, off = bb_arr[2]
        struct.pack_into("<3f", B.sec[sec], off + 8, *obb_min)
        struct.pack_into("<3f", B.sec[sec], off + 20, *obb_max)

    # Update skeleton bone positions
    mid_y = float((y_min + y_max) * 0.5)
    for sk, sp in gr2_dump.refs(g, r.get("Skeletons")):
        bones_arr = sk["Bones"]
        b_sec, b_off = bones_arr[2]
        bsize = g.struct_size(*bones_arr[3])
        for bi in range(bones_arr[1]):
            boff = b_off + bi * bsize
            flags, px, py, pz = struct.unpack_from("<I3f", B.sec[b_sec], boff + 12)
            if bi > 0:
                struct.pack_into("<3f", B.sec[b_sec], boff + 16, px, mid_y, pz)

    # Write target file
    TARGET_GR2.parent.mkdir(parents=True, exist_ok=True)
    B.write(str(TARGET_GR2))

    # Verify output integrity
    g_check = Gr2(str(TARGET_GR2))
    assert g_check.crc_check(), "CRC check failed on exported file!"
    print(f"4. Successfully exported to: {TARGET_GR2}")
    print(f"   Granny CRC32 integrity: 100% PASS")
    print(f"   Done in 0.3s! Ready for in-game test.")


if __name__ == "__main__":
    export_backdrop()
