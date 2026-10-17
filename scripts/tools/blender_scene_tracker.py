#!/usr/bin/env python3
"""Blender Scene Snapshot, Diff & Timeline Tracker.

Enables agents and users to track live edits made to Blender scenes:
- Detect added, deleted, moved, and conjoined/modified objects.
- Track changes over time via automatic `save_post` journaling.
- Audit live Blender objects against repository Granny2 (.gr2) assets without prior snapshots.

Usage:
    # 1. Take a baseline snapshot of the current Blender scene
    python scripts/tools/blender_scene_tracker.py snapshot [baseline.json]

    # 2. Diff live Blender state against baseline snapshot
    python scripts/tools/blender_scene_tracker.py diff baseline.json

    # 3. View chronological history of edits (when edits were made)
    python scripts/tools/blender_scene_tracker.py timeline [blender_scene_journal.jsonl]

    # 4. Install automatic save-tracker hook into Blender (runs on every Ctrl+S)
    python scripts/tools/blender_scene_tracker.py install-handler [--persist]

    # 5. Zero-prep audit: Compare live Blender objects directly against repo .gr2 assets
    python scripts/tools/blender_scene_tracker.py audit-repo
"""

import os
import sys
import json
import time
import socket
import argparse
from pathlib import Path
from datetime import datetime

# Optional Havok / GR2 support
SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent.parent
sys.path.append(str(REPO_ROOT / "scripts" / "havok"))

try:
    import gr2_lint
    HAS_GR2 = True
except ImportError:
    HAS_GR2 = False

DEFAULT_PORT = 9876


def execute_blender_code(code: str, port: int = DEFAULT_PORT, timeout: float = 10.0) -> dict:
    """Send python code to live Blender via socket on port 9876 and receive result."""
    s = socket.socket()
    s.settimeout(timeout)
    try:
        s.connect(("127.0.0.1", port))
    except Exception as e:
        raise ConnectionError(f"Could not connect to Blender on 127.0.0.1:{port}: {e}")

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

    raw = buf.partition(b"\0")[0].decode("utf-8")
    data = json.loads(raw)
    if data.get("status") != "ok":
        err_msg = data.get("message") or data.get("result", {}).get("error", "Unknown error")
        raise RuntimeError(f"Blender execution error: {err_msg}")
    return data.get("result", {})


def capture_manifest(port: int = DEFAULT_PORT) -> dict:
    """Query live Blender scene and construct a comprehensive scene manifest."""
    blender_script = '''
import bpy
import bmesh
import hashlib
import struct
import time
from datetime import datetime

active_obj = bpy.context.active_object
is_edit_mode = (active_obj and active_obj.mode == 'EDIT')

manifest = {
    'meta': {
        'filepath': bpy.data.filepath,
        'timestamp': datetime.utcnow().isoformat() + 'Z',
        'blender_version': list(bpy.app.version),
        'active_object': active_obj.name if active_obj else None,
        'mode': bpy.context.mode,
        'is_dirty': bpy.data.is_dirty
    },
    'objects': {}
}

for obj in bpy.data.objects:
    item = {
        'type': obj.type,
        'parent': obj.parent.name if obj.parent else None,
        'visible': obj.visible_get(),
        'loc': [round(x, 4) for x in obj.location],
        'rot': [round(x, 4) for x in obj.rotation_euler],
        'scale': [round(x, 4) for x in obj.scale],
        'dims': [round(x, 4) for x in obj.dimensions]
    }
    
    if obj.type == 'MESH' and obj.data:
        m = obj.data
        if is_edit_mode and obj == active_obj:
            bm = bmesh.from_edit_mesh(m)
            n_verts = len(bm.verts)
            n_faces = len(bm.faces)
            sample_verts = bm.verts[:50] + bm.verts[-50:] if len(bm.verts) > 100 else bm.verts
            v_bytes = b"".join(struct.pack('<3f', *v.co) for v in sample_verts)
        else:
            n_verts = len(m.vertices)
            n_faces = len(m.polygons)
            sample_verts = m.vertices[:50] + m.vertices[-50:] if len(m.vertices) > 100 else m.vertices
            v_bytes = b"".join(struct.pack('<3f', *v.co) for v in sample_verts)
            
        item['mesh_name'] = m.name
        item['n_verts'] = n_verts
        item['n_faces'] = n_faces
        item['materials'] = [slot.material.name for slot in obj.material_slots if slot.material]
        item['geo_hash'] = hashlib.md5(v_bytes).hexdigest()[:12]
        
    manifest['objects'][obj.name] = item

result = manifest
'''
    return execute_blender_code(blender_script, port=port)


def compute_diff(baseline: dict, current: dict, tol: float = 1e-4) -> dict:
    """Compute structural and geometric difference between two manifests."""
    base_objs = baseline.get("objects", {})
    curr_objs = current.get("objects", {})

    base_names = set(base_objs.keys())
    curr_names = set(curr_objs.keys())

    added_names = sorted(list(curr_names - base_names))
    deleted_names = sorted(list(base_names - curr_names))
    common_names = sorted(list(base_names & curr_names))

    added = [curr_objs[k] | {"name": k} for k in added_names]
    deleted = [base_objs[k] | {"name": k} for k in deleted_names]
    moved = []
    modified = []
    unchanged_count = 0

    for name in common_names:
        b = base_objs[name]
        c = curr_objs[name]
        is_changed = False

        # 1. Transform / movement check
        loc_d = [c["loc"][i] - b["loc"][i] for i in range(3)]
        rot_d = [c["rot"][i] - b["rot"][i] for i in range(3)]
        scale_d = [c["scale"][i] - b["scale"][i] for i in range(3)]

        has_moved = any(abs(d) > tol for d in loc_d) or \
                    any(abs(d) > tol for d in rot_d) or \
                    any(abs(d) > tol for d in scale_d)

        if has_moved:
            is_changed = True
            moved.append({
                "name": name,
                "type": c.get("type"),
                "old_loc": b["loc"],
                "new_loc": c["loc"],
                "delta_loc": [round(x, 4) for x in loc_d],
                "old_rot": b["rot"],
                "new_rot": c["rot"],
                "old_scale": b["scale"],
                "new_scale": c["scale"]
            })

        # 2. Mesh geometry & material changes
        if c.get("type") == "MESH" and b.get("type") == "MESH":
            d_verts = c.get("n_verts", 0) - b.get("n_verts", 0)
            d_faces = c.get("n_faces", 0) - b.get("n_faces", 0)
            hash_changed = (c.get("geo_hash") != b.get("geo_hash"))
            mats_changed = (c.get("materials") != b.get("materials"))
            parent_changed = (c.get("parent") != b.get("parent"))

            if d_verts != 0 or d_faces != 0 or hash_changed or mats_changed or parent_changed:
                is_changed = True
                modified.append({
                    "name": name,
                    "mesh_name": c.get("mesh_name"),
                    "old_faces": b.get("n_faces", 0),
                    "new_faces": c.get("n_faces", 0),
                    "delta_faces": d_faces,
                    "old_verts": b.get("n_verts", 0),
                    "new_verts": c.get("n_verts", 0),
                    "delta_verts": d_verts,
                    "old_mats": b.get("materials", []),
                    "new_mats": c.get("materials", []),
                    "hash_changed": hash_changed,
                    "parent_changed": parent_changed,
                    "old_parent": b.get("parent"),
                    "new_parent": c.get("parent")
                })

        if not is_changed:
            unchanged_count += 1

    return {
        "summary": {
            "baseline_count": len(base_names),
            "current_count": len(curr_names),
            "added_count": len(added),
            "deleted_count": len(deleted),
            "moved_count": len(moved),
            "modified_count": len(modified),
            "unchanged_count": unchanged_count
        },
        "added": added,
        "deleted": deleted,
        "moved": moved,
        "modified": modified
    }


def format_diff_markdown(diff: dict) -> str:
    """Format diff dictionary into readable Markdown report."""
    s = diff["summary"]
    lines = [
        "### Blender Scene Diff Summary",
        f"- **Objects Baseline**: {s['baseline_count']}  -->  **Current**: {s['current_count']}",
        f"- **Changes**: `+{s['added_count']}` added | `-{s['deleted_count']}` deleted | `~{s['moved_count']}` moved | `#{s['modified_count']}` mesh modified | `{s['unchanged_count']}` unchanged",
        ""
    ]

    if diff["modified"]:
        lines.append("#### Modified Meshes / Conjoinments")
        lines.append("| Object Name | Face Delta | Vert Delta | Old Faces -> New | Materials | Change Detail |")
        lines.append("| :--- | :--- | :--- | :--- | :--- | :--- |")
        for m in diff["modified"]:
            fd = f"+{m['delta_faces']}" if m['delta_faces'] > 0 else str(m['delta_faces'])
            vd = f"+{m['delta_verts']}" if m['delta_verts'] > 0 else str(m['delta_verts'])
            detail = []
            if m['delta_faces'] > 0:
                detail.append("Conjoined / faces added")
            elif m['delta_faces'] < 0:
                detail.append("Faces dropped")
            elif m['hash_changed']:
                detail.append("Reshaped / vertices moved")
            if m['old_mats'] != m['new_mats']:
                detail.append("Material slots changed")
            if m['parent_changed']:
                detail.append(f"Parent: {m['old_parent']} -> {m['new_parent']}")
            
            lines.append(f"| `{m['name']}` | **{fd}** | {vd} | {m['old_faces']} -> {m['new_faces']} | {', '.join(m['new_mats'])} | {'; '.join(detail)} |")
        lines.append("")

    if diff["added"]:
        lines.append("#### Added Objects")
        lines.append("| Object Name | Type | Parent | Faces | Location [X, Y, Z] |")
        lines.append("| :--- | :--- | :--- | :--- | :--- |")
        for a in diff["added"]:
            faces = a.get("n_faces", "-")
            lines.append(f"| `{a['name']}` | {a.get('type')} | {a.get('parent') or '-'} | {faces} | `{a.get('loc')}` |")
        lines.append("")

    if diff["deleted"]:
        lines.append("#### Deleted Objects")
        lines.append("| Object Name | Type | Previous Parent | Previous Faces |")
        lines.append("| :--- | :--- | :--- | :--- |")
        for d in diff["deleted"]:
            faces = d.get("n_faces", "-")
            lines.append(f"| `{d['name']}` | {d.get('type')} | {d.get('parent') or '-'} | {faces} |")
        lines.append("")

    if diff["moved"]:
        lines.append("#### Moved / Repositioned Objects")
        lines.append("| Object Name | Type | Delta Location (dx, dy, dz) | New Location |")
        lines.append("| :--- | :--- | :--- | :--- |")
        for mv in diff["moved"]:
            dx, dy, dz = mv["delta_loc"]
            lines.append(f"| `{mv['name']}` | {mv.get('type')} | `[{dx:+.3f}, {dy:+.3f}, {dz:+.3f}]` m | `{mv['new_loc']}` |")
        lines.append("")

    if not diff["added"] and not diff["deleted"] and not diff["moved"] and not diff["modified"]:
        lines.append("> [!NOTE]\n> Scene is identical to baseline. Zero differences detected.\n")

    return "\n".join(lines)


def install_save_handler(port: int = DEFAULT_PORT, persist_startup: bool = False):
    """Register persistent save_post handler in Blender to auto-journal edits on every Ctrl+S."""
    handler_code = '''
import bpy
import bmesh
import hashlib
import struct
import json
import os
import time
from datetime import datetime

HANDLER_NAME = "aop_scene_tracker_save_handler"

# Remove existing if already registered
bpy.app.handlers.save_post[:] = [h for h in bpy.app.handlers.save_post if h.__name__ != HANDLER_NAME]

@bpy.app.handlers.persistent
def aop_scene_tracker_save_handler(dummy):
    filepath = bpy.data.filepath
    if not filepath:
        return
        
    blend_dir = os.path.dirname(filepath)
    base_name = os.path.splitext(os.path.basename(filepath))[0]
    manifest_path = os.path.join(blend_dir, f".{base_name}.manifest.json")
    journal_path = os.path.join(blend_dir, "blender_scene_journal.jsonl")
    
    # 1. Build current manifest
    active_obj = bpy.context.active_object
    curr_objects = {}
    for obj in bpy.data.objects:
        item = {
            'type': obj.type,
            'parent': obj.parent.name if obj.parent else None,
            'loc': [round(x, 4) for x in obj.location],
            'rot': [round(x, 4) for x in obj.rotation_euler],
            'scale': [round(x, 4) for x in obj.scale],
            'dims': [round(x, 4) for x in obj.dimensions]
        }
        if obj.type == 'MESH' and obj.data:
            m = obj.data
            n_verts = len(m.vertices)
            n_faces = len(m.polygons)
            sample_verts = m.vertices[:50] + m.vertices[-50:] if len(m.vertices) > 100 else m.vertices
            v_bytes = b"".join(struct.pack('<3f', *v.co) for v in sample_verts)
            item['mesh_name'] = m.name
            item['n_verts'] = n_verts
            item['n_faces'] = n_faces
            item['materials'] = [s.material.name for s in obj.material_slots if s.material]
            item['geo_hash'] = hashlib.md5(v_bytes).hexdigest()[:12]
        curr_objects[obj.name] = item
        
    curr_manifest = {
        'meta': {
            'filepath': filepath,
            'timestamp': datetime.utcnow().isoformat() + 'Z',
            'object_count': len(curr_objects)
        },
        'objects': curr_objects
    }
    
    # 2. Check baseline manifest
    if os.path.exists(manifest_path):
        try:
            with open(manifest_path, 'r', encoding='utf-8') as f:
                prev_manifest = json.load(f)
        except Exception:
            prev_manifest = None
    else:
        prev_manifest = None
        
    # 3. If baseline exists, compute delta and log to journal
    if prev_manifest:
        prev_objs = prev_manifest.get('objects', {})
        prev_names = set(prev_objs.keys())
        curr_names = set(curr_objects.keys())
        
        added = sorted(list(curr_names - prev_names))
        deleted = sorted(list(prev_names - curr_names))
        common = sorted(list(curr_names & prev_names))
        
        moved = []
        modified = []
        for name in common:
            p = prev_objs[name]
            c = curr_objects[name]
            # check loc/rot/scale
            if any(abs(c['loc'][i] - p['loc'][i]) > 1e-4 for i in range(3)) or \
               any(abs(c['rot'][i] - p['rot'][i]) > 1e-4 for i in range(3)):
                moved.append({
                    'name': name,
                    'delta_loc': [round(c['loc'][i] - p['loc'][i], 4) for i in range(3)]
                })
            if c.get('type') == 'MESH' and p.get('type') == 'MESH':
                df = c.get('n_faces', 0) - p.get('n_faces', 0)
                dv = c.get('n_verts', 0) - p.get('n_verts', 0)
                if df != 0 or dv != 0 or c.get('geo_hash') != p.get('geo_hash') or c.get('materials') != p.get('materials'):
                    modified.append({
                        'name': name,
                        'delta_faces': df,
                        'delta_verts': dv,
                        'old_faces': p.get('n_faces', 0),
                        'new_faces': c.get('n_faces', 0)
                    })
                    
        if added or deleted or moved or modified:
            record = {
                'timestamp': datetime.utcnow().isoformat() + 'Z',
                'event': 'file_save',
                'file': os.path.basename(filepath),
                'summary': f"+{len(added)} added, -{len(deleted)} deleted, ~{len(moved)} moved, #{len(modified)} modified",
                'diff': {
                    'added': added,
                    'deleted': deleted,
                    'moved': moved,
                    'modified': modified
                }
            }
            with open(journal_path, 'a', encoding='utf-8') as f:
                f.write(json.dumps(record) + "\\n")
            print(f"[AOP Scene Tracker] Saved delta logged: {record['summary']}")
            
    # Save current manifest as new baseline
    with open(manifest_path, 'w', encoding='utf-8') as f:
        json.dump(curr_manifest, f, indent=2)

bpy.app.handlers.save_post.append(aop_scene_tracker_save_handler)
result = {'status': 'installed', 'handlers': [h.__name__ for h in bpy.app.handlers.save_post]}
'''
    res = execute_blender_code(handler_code, port=port)
    print(f"[*] Save handler successfully registered in active Blender instance: {res}")

    if persist_startup:
        # Put into user startup scripts
        startup_dir = Path(os.environ.get("APPDATA", "")) / "Blender Foundation" / "Blender" / "5.1" / "scripts" / "startup"
        if not startup_dir.exists():
            startup_dir.mkdir(parents=True, exist_ok=True)
        startup_file = startup_dir / "aoe_scene_tracker_startup.py"
        with open(startup_file, "w", encoding="utf-8") as f:
            f.write(handler_code.replace("result = ", "# Registered\n"))
        print(f"[*] Persisted startup script to: {startup_file}")


def format_timeline(journal_path: Path) -> str:
    """Format JSONL journal into readable chronological timeline."""
    if not journal_path.exists():
        return f"No journal file found at: {journal_path}"

    records = []
    with open(journal_path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line:
                try:
                    records.append(json.loads(line))
                except Exception:
                    pass

    if not records:
        return f"Journal at {journal_path} is empty."

    lines = [
        f"### Blender Scene Change Timeline ({len(records)} events recorded)",
        f"Journal source: `{journal_path.name}`",
        ""
    ]

    for idx, r in enumerate(records, 1):
        ts = r.get("timestamp", "Unknown time")
        event = r.get("event", "save")
        fname = r.get("file", "")
        summary = r.get("summary", "")
        diff = r.get("diff", {})

        lines.append(f"**[{idx}] {ts}** — `{fname}` ({summary})")
        if diff.get("modified"):
            for m in diff["modified"]:
                df = f"+{m['delta_faces']}" if m.get('delta_faces', 0) > 0 else str(m.get('delta_faces', 0))
                lines.append(f"  - **MODIFIED**: `{m['name']}` ({df} faces: {m.get('old_faces')} -> {m.get('new_faces')})")
        if diff.get("added"):
            for a in diff["added"]:
                name = a if isinstance(a, str) else a.get("name")
                lines.append(f"  - **ADDED**: `{name}`")
        if diff.get("deleted"):
            for d in diff["deleted"]:
                name = d if isinstance(d, str) else d.get("name")
                lines.append(f"  - **DELETED**: `{name}`")
        if diff.get("moved"):
            for mv in diff["moved"]:
                name = mv.get("name")
                dloc = mv.get("delta_loc")
                lines.append(f"  - **MOVED**: `{name}` (delta: `{dloc}`)")
        lines.append("")

    return "\n".join(lines)


def audit_against_repo(port: int = DEFAULT_PORT):
    """Compare live Blender meshes against corresponding repository Granny2 (.gr2) assets."""
    if not HAS_GR2:
        print("ERROR: gr2_lint / scripts/havok not found. Cannot audit GR2 assets.")
        return

    print("1. Extracting live Blender scene objects...")
    manifest = capture_manifest(port=port)
    live_meshes = {k: v for k, v in manifest.get("objects", {}).items() if v.get("type") == "MESH"}
    print(f"   Found {len(live_meshes)} meshes in Blender scene.")

    # Locate candidate GR2 files across AoP and Koreans repo
    candidate_roots = [
        REPO_ROOT / "art",
        REPO_ROOT.parent / "age-of-pirates-koreans" / "art"
    ]

    print("2. Searching repository GR2 assets...")
    gr2_files = []
    for r in candidate_roots:
        if r.exists():
            gr2_files.extend(list(r.rglob("*.gr2")))
    print(f"   Indexed {len(gr2_files)} repository GR2 assets.")

    # Match meshes
    audit_table = []
    for gr2_p in gr2_files:
        try:
            info = gr2_lint.read_raw(str(gr2_p))
            for m in info.get("meshes", []):
                m_name = m.get("name")
                if m_name in live_meshes:
                    b_obj = live_meshes[m_name]
                    gr2_tris = len(m.get("tris", []))
                    gr2_verts = len(m.get("pos", []))
                    b_faces = b_obj.get("n_faces", 0)
                    b_verts = b_obj.get("n_verts", 0)
                    d_faces = b_faces - gr2_tris
                    d_verts = b_verts - gr2_verts

                    audit_table.append({
                        "name": m_name,
                        "gr2_file": gr2_p.name,
                        "gr2_tris": gr2_tris,
                        "blender_faces": b_faces,
                        "delta_faces": d_faces,
                        "delta_verts": d_verts,
                        "status": "MODIFIED" if d_faces != 0 else "MATCHING"
                    })
        except Exception:
            continue

    print("\n### Live Blender Scene vs. Repository GR2 Assets")
    if not audit_table:
        print("No direct name matches found between live Blender scene meshes and repo GR2s.")
        return

    print(f"| Object Name | Repo Asset | GR2 Triangles | Live Blender Faces | Delta | Status |")
    print(f"| :--- | :--- | :--- | :--- | :--- | :--- |")
    for row in sorted(audit_table, key=lambda x: abs(x['delta_faces']), reverse=True):
        delta_str = f"+{row['delta_faces']}" if row['delta_faces'] > 0 else str(row['delta_faces'])
        status_str = f"**{row['status']}**" if row['status'] == "MODIFIED" else "OK"
        print(f"| `{row['name']}` | `{row['gr2_file']}` | {row['gr2_tris']} | {row['blender_faces']} | {delta_str} | {status_str} |")


def main():
    parser = argparse.ArgumentParser(description="Blender Scene Diff & Change Tracker")
    subparsers = parser.add_subparsers(dest="command", required=True)

    # Subcommand: snapshot
    p_snap = subparsers.add_parser("snapshot", help="Take a manifest snapshot of the current Blender scene")
    p_snap.add_argument("output", nargs="?", default="scene_manifest.json", help="Path to save JSON manifest")
    p_snap.add_argument("--port", type=int, default=DEFAULT_PORT, help="Blender MCP port")

    # Subcommand: diff
    p_diff = subparsers.add_parser("diff", help="Diff live scene against baseline (or diff two manifest JSONs)")
    p_diff.add_argument("baseline", help="Baseline manifest JSON file")
    p_diff.add_argument("current", nargs="?", default=None, help="Optional current manifest JSON (defaults to live Blender)")
    p_diff.add_argument("--port", type=int, default=DEFAULT_PORT, help="Blender MCP port")
    p_diff.add_argument("--json", action="store_true", help="Output raw JSON instead of markdown")

    # Subcommand: timeline
    p_time = subparsers.add_parser("timeline", help="Display chronological timeline of saved edits")
    p_time.add_argument("journal", nargs="?", default="blender_scene_journal.jsonl", help="Path to journal JSONL file")

    # Subcommand: install-handler
    p_inst = subparsers.add_parser("install-handler", help="Install auto-tracker save hook into Blender")
    p_inst.add_argument("--port", type=int, default=DEFAULT_PORT, help="Blender MCP port")
    p_inst.add_argument("--persist", action="store_true", help="Persist to user startup scripts across Blender restarts")

    # Subcommand: audit-repo
    p_audit = subparsers.add_parser("audit-repo", help="Audit live Blender objects directly against repository GR2 assets")
    p_audit.add_argument("--port", type=int, default=DEFAULT_PORT, help="Blender MCP port")

    args = parser.parse_args()

    if args.command == "snapshot":
        print(f"Capturing live scene snapshot from port {args.port}...")
        manifest = capture_manifest(port=args.port)
        out_path = Path(args.output).resolve()
        with open(out_path, "w", encoding="utf-8") as f:
            json.dump(manifest, f, indent=2)
        print(f"[OK] Saved scene manifest ({len(manifest['objects'])} objects) to: {out_path}")

    elif args.command == "diff":
        base_path = Path(args.baseline).resolve()
        if not base_path.exists():
            print(f"Error: Baseline manifest not found: {base_path}")
            sys.exit(1)
        with open(base_path, "r", encoding="utf-8") as f:
            base_manifest = json.load(f)

        if args.current:
            curr_path = Path(args.current).resolve()
            with open(curr_path, "r", encoding="utf-8") as f:
                curr_manifest = json.load(f)
        else:
            curr_manifest = capture_manifest(port=args.port)

        diff = compute_diff(base_manifest, curr_manifest)
        if args.json:
            print(json.dumps(diff, indent=2))
        else:
            print(format_diff_markdown(diff))

    elif args.command == "timeline":
        j_path = Path(args.journal).resolve()
        print(format_timeline(j_path))

    elif args.command == "install-handler":
        install_save_handler(port=args.port, persist_startup=args.persist)

    elif args.command == "audit-repo":
        audit_against_repo(port=args.port)


if __name__ == "__main__":
    main()
