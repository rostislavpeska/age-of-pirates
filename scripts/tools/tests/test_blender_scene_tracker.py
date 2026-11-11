import pytest
import sys
from pathlib import Path

# Add scripts/tools to path
TOOLS_DIR = Path(__file__).resolve().parent.parent
sys.path.append(str(TOOLS_DIR))

from blender_scene_tracker import compute_diff, format_diff_markdown


def test_compute_diff_add_delete():
    baseline = {
        "objects": {
            "Cube": {"type": "MESH", "loc": [0, 0, 0], "rot": [0, 0, 0], "scale": [1, 1, 1], "n_faces": 6, "n_verts": 8},
            "OldLight": {"type": "LIGHT", "loc": [5, 5, 5], "rot": [0, 0, 0], "scale": [1, 1, 1]}
        }
    }
    current = {
        "objects": {
            "Cube": {"type": "MESH", "loc": [0, 0, 0], "rot": [0, 0, 0], "scale": [1, 1, 1], "n_faces": 6, "n_verts": 8},
            "NewMonkey": {"type": "MESH", "loc": [1, 2, 3], "rot": [0, 0, 0], "scale": [1, 1, 1], "n_faces": 500, "n_verts": 500}
        }
    }

    diff = compute_diff(baseline, current)
    assert diff["summary"]["added_count"] == 1
    assert diff["summary"]["deleted_count"] == 1
    assert diff["summary"]["moved_count"] == 0
    assert diff["summary"]["modified_count"] == 0
    assert diff["summary"]["unchanged_count"] == 1

    assert diff["added"][0]["name"] == "NewMonkey"
    assert diff["deleted"][0]["name"] == "OldLight"


def test_compute_diff_moved():
    baseline = {
        "objects": {
            "TownCenter": {"type": "EMPTY", "loc": [10.0, 0.0, 5.0], "rot": [0, 0, 0], "scale": [1, 1, 1]}
        }
    }
    current = {
        "objects": {
            "TownCenter": {"type": "EMPTY", "loc": [12.5, 0.0, 5.0], "rot": [0, 0, 0], "scale": [1, 1, 1]}
        }
    }

    diff = compute_diff(baseline, current)
    assert diff["summary"]["moved_count"] == 1
    assert diff["moved"][0]["name"] == "TownCenter"
    assert diff["moved"][0]["delta_loc"] == [2.5, 0.0, 0.0]


def test_compute_diff_mesh_conjoined():
    baseline = {
        "objects": {
            "bridge": {
                "type": "MESH",
                "mesh_name": "bridge_mesh",
                "loc": [0, 0, 0], "rot": [0, 0, 0], "scale": [1, 1, 1],
                "n_faces": 1652,
                "n_verts": 4032,
                "materials": ["HC_Filler_Clay"],
                "geo_hash": "hash_a"
            }
        }
    }
    current = {
        "objects": {
            "bridge": {
                "type": "MESH",
                "mesh_name": "bridge_mesh",
                "loc": [0, 0, 0], "rot": [0, 0, 0], "scale": [1, 1, 1],
                "n_faces": 2360,
                "n_verts": 4620,
                "materials": ["HC_Filler_Clay", "Market_Wood"],
                "geo_hash": "hash_b"
            }
        }
    }

    diff = compute_diff(baseline, current)
    assert diff["summary"]["modified_count"] == 1
    m = diff["modified"][0]
    assert m["name"] == "bridge"
    assert m["delta_faces"] == 708
    assert m["delta_verts"] == 588
    assert m["hash_changed"] is True

    md = format_diff_markdown(diff)
    assert "Conjoined" in md
    assert "+708" in md
