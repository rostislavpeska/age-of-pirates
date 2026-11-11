"""AoP shim: rope / connector tubes for AoE3 composite props, with the AoE3 defaults.

The generic tube moved to Blendify blender-complex-scene `scripts/path_tube.py` on 2026-10-17 (journal
2026-10-17-claude-opus-5.5-17; outputs checked identical on 40 random paths). Defaults kept from the original tool:
radius 0.018 m (vanilla AoE3 rope), V 0.957..0.967, U 0.28 per metre - see SKILL.md rule 3 for the open V-space question.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'blender-complex-scene' / 'scripts'))
from path_tube import tube_mesh  # noqa: E402


def generate_rope_mesh(waypoints, radius=0.018, uv_v_min=0.957, uv_v_max=0.967, u_scale=0.28):
    return tube_mesh(waypoints, radius, uv_v_min, uv_v_max, u_scale)
