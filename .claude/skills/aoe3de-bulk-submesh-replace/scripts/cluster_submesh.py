"""AoP shim: repeated-prop islands in AoE3 composite meshes (`*_GEOShape`, `bridgesandstuff`, lantern sets).

The generic finder moved to Blendify blender-complex-scene `scripts/mesh_islands.py` on 2026-10-17 (journal
2026-10-17-claude-opus-5.5-17; outputs checked identical on 40 random meshes). Reached through the AoP discovery link
`.claude/skills/blender-complex-scene`.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'blender-complex-scene' / 'scripts'))
from mesh_islands import deduplicate_multi_part_clusters, find_submesh_components  # noqa: E402,F401
