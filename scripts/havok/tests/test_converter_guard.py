"""converter.py refuses a GXO with 2+ root bones before any conversion (bone bench 2026-09-26: such a
converter-built gr2 renders nothing in game). Synthetic GXOs only - no converter, no game.

    python -m pytest scripts/havok/tests -q
"""
from __future__ import annotations

import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "scripts" / "havok"))
sys.dont_write_bytecode = True

import converter  # noqa: E402

M = "2.68757248 0 0 0 1.64566326e-16 2.68757248 0 -2.68757248 1.64566326e-16 0 0 0"
I = "1 0 0 0 1 0 0 0 1 0 0 0"
MESH = 'm "Body"\nmb "Bone"\nmm 1\nv 0 0 0\nvn 0 0 1\nvt 0 0\n'


def gxo(tmp_path, bones, name="t.gxo"):
    p = tmp_path / name
    p.write_text('t "a.tga"\nmt "mata"\ntb 1\n' + "\n".join(bones) + "\n" + MESH, encoding="utf-8")
    return p


def test_roots_of_the_bench_variants(tmp_path):
    assert converter.gxo_roots(gxo(tmp_path, [f'b "bone_prop" 0 {I}', f'b "Bone" 1 {M}'])) == ["bone_prop"]
    assert converter.gxo_roots(gxo(tmp_path, [f'b "Bone" 0 {M}', f'b "bone_prop" 1 {I}'])) == ["Bone"]
    assert converter.gxo_roots(gxo(tmp_path, [f'b "Bone" 0 {M}', f'b "bone_prop" 0 {I}'])) == ["Bone", "bone_prop"]


def test_bone_lines_after_the_first_mesh_are_not_read(tmp_path):
    p = tmp_path / "late.gxo"
    p.write_text('b "Bone" 0 ' + M + "\n" + MESH + 'b "late" 0 ' + I + "\n", encoding="utf-8")
    assert converter.gxo_roots(p) == ["Bone"]


def test_two_roots_refused_before_the_backend_runs(tmp_path, monkeypatch, capsys):
    p = gxo(tmp_path, [f'b "Bone" 0 {M}', f'b "bone_prop" 0 {I}'])
    ran = []
    monkeypatch.setattr(converter, "run_manual", lambda *a: ran.append(a) or (0, ""))
    monkeypatch.setattr(converter, "load_config", lambda: {"backend": "manual"})
    monkeypatch.setattr(sys, "argv", ["converter.py", "--format", "gr2", str(p)])
    assert converter.main() == 1
    assert "REFUSED" in capsys.readouterr().out and not ran


def test_override_reaches_the_backend(tmp_path, monkeypatch):
    p = gxo(tmp_path, [f'b "Bone" 0 {M}', f'b "bone_prop" 0 {I}'])
    ran = []
    monkeypatch.setattr(converter, "run_manual", lambda *a: ran.append(a) or (1, "no converter in tests"))
    monkeypatch.setattr(converter, "load_config", lambda: {"backend": "manual"})
    monkeypatch.setattr(sys, "argv", ["converter.py", "--format", "gr2", "--allow-multi-root", str(p)])
    converter.main()
    assert len(ran) == 1
