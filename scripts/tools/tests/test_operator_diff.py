"""Tests for operator_diff.py (Blender interactive change tracking)."""

import json
from pathlib import Path
import pytest
import sys

REPO = Path(__file__).resolve().parents[3]
SYS_DIR = REPO / ".claude" / "skills" / "blender-mcp-safety" / "scripts"
sys.path.insert(0, str(SYS_DIR))

import operator_diff


def test_compute_diff_transforms():
    baseline = {
        "camera": {"location": [0, 0, 10], "rotation_euler": [0, 0, 0], "lens": 35.0},
        "objects": {
            "Cylinder": {
                "name": "Cylinder",
                "location": [0.0, 0.0, 0.0],
                "scale": [1.0, 1.0, 2.6],
                "dimensions": [10.0, 10.0, 26.0],
                "rotation_euler": [0.0, 0.0, 0.0],
                "num_vertices": 100,
                "num_polygons": 200,
                "materials": ["matA"]
            }
        }
    }

    current = {
        "camera": {"location": [0, 0, 15], "rotation_euler": [0, 0, 0], "lens": 35.0},
        "objects": {
            "Cylinder": {
                "name": "Cylinder",
                "location": [0.0, 0.0, 10.3925],
                "scale": [1.03415, 1.03415, 2.6888],
                "dimensions": [10.3415, 10.3415, 26.888],
                "rotation_euler": [0.0, 0.0, 0.0],
                "num_vertices": 100,
                "num_polygons": 200,
                "materials": ["matA"]
            },
            "NewProp": {
                "name": "NewProp",
                "location": [5, 5, 0]
            }
        }
    }

    diff = operator_diff.compute_diff(baseline, current)

    # Verify camera detection
    assert diff["camera_delta"] is not None
    assert diff["camera_delta"]["location"]["delta"] == [0.0, 0.0, 5.0]

    # Verify added objects
    assert "NewProp" in diff["added_objects"]

    # Verify modified objects
    assert "Cylinder" in diff["modified_objects"]
    cyl = diff["modified_objects"]["Cylinder"]
    assert cyl["location"]["delta"] == [0.0, 0.0, 10.3925]
    assert cyl["scale"]["uniform"] is True
    assert pytest.approx(cyl["scale"]["uniform_factor"], rel=1e-4) == 1.03415
