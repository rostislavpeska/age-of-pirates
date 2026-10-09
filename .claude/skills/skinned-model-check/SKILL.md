---
name: skinned-model-check
description: Check a skinned (rigged) unit or character model before and after any edit - bones, skin weights, influence limits, mesh binding - and prove against the untouched original what an edit changed (dropped meshes, moved vertices) and that it kept the skeleton and every vertex's weights. Converts AoE3 DE .gr2 through the GR2 converter under Wine in WSL, checks in background Blender, renders clay views. Use before an in-place GR2 edit of a unit (shaved head, removed part), after any unit/rider/animal model change, when a retextured or edited unit "deforms wrongly", "loses its arm", "stretches in animation", and as the evidence step before an owner game test.
---

# Skinned model check

A skinned model deforms with its skeleton: each vertex follows up to N bones by weight. An edit that keeps the
skeleton and every vertex's bone set and weights keeps the animations working; changing them is the classic way
game-mod meshes break (vertices with no bone influence stay behind, limbs stretch). This skill measures exactly
that, before the model reaches the game.

```bash
python .claude/skills/skinned-model-check/scripts/run_skin_check.py EDITED.gr2 --baseline VANILLA.gr2 \
       --out <scratchpad>/skin_check_<name> [--expect-dropped MESH ...] [--max-influences 4]
```

Inputs are `.gr2` (converted through the converter under Wine in WSL, never the exe on the Windows host) or
`.fbx`/`.glb`. Output in `--out` (the session scratchpad, refused inside the repo): `skin_check.json`, clay
renders `model_*.png` / `baseline_*.png` (front, three-quarter, side, back) for the owner, the converted FBX in
`work/`. Exit 1 on any FAIL, 2 when Blender, the converter or the WSL distro is missing.

## What it checks

| Level | Check |
| --- | --- |
| FAIL | unweighted vertex; more influences than `--max-influences`; mesh not bound to an armature; no armature; zero-length bone; negative scale |
| FAIL (with `--baseline`) | a bone added, removed, renamed or re-parented; a mesh dropped that is not in `--expect-dropped`; any vertex whose bone set or weights changed (tolerance 0.001) |
| WARN | weights not summing to 1; vertex groups with no bone; more than one armature; ngons, zero-area faces, loose vertices, edges shared by more than two faces; a mesh added; vertex count changed (weights then cannot be compared one to one) |
| INFO | moved vertices per mesh, dropped meshes you declared, influence maximum seen, seam doubles, armature object scale |

## Reading AoE3 converter output (measured on the DE yabusame rider, 2026-10-09)

- The converter FBX imports at engine/254/100 (`gr2-granny-edit`, "Frames, units"): a 2 m rider is 0.008 Blender
  units and the armature carries that scale. Expected, reported as INFO.
- Game meshes split vertices along UV seams, so "doubled vertices" are normal (187 on the rider). INFO.
- Vanilla data has tiny weights (11 below 0.01 on the rider): compare with the baseline, do not "fix" them.
- The rider: 30 bones (`Bip01_*`), body 715 vertices / 1026 triangles, deerskin leg covers a separate 64-vertex
  mesh; at most 3 influences per vertex seen. `gr2_dump.py` on the .gr2 shows the same counts.

## Workflow for an in-place edit

1. Baseline: `run_skin_check.py VANILLA.gr2 --baseline VANILLA.gr2` must pass with 0 moved vertices (proves the
   converter round trip itself on this device).
2. Edit the vanilla .gr2 in place (`gr2-granny-edit`: drop triangles, move existing vertices; no new vertices,
   so weights never need a transfer).
3. `run_skin_check.py EDITED.gr2 --baseline VANILLA.gr2 --expect-dropped <mesh>`: skeleton identical, only the
   intended meshes dropped and vertices moved, no vertex re-weighted. Send the clay views.
4. Only then the owner's game test (on the test device). A passing check does not prove the game loads the file.

If an edit must add vertices (new shapes), weights have to be transferred from the original (Blender Data Transfer,
nearest-face interpolated, group names = bone names, limit and normalise) and the model goes through the converter:
that is the route that lost faces on buildings - one falsifiable test before relying on it.

## Device setup

The converter folder (`wine/gxo_wine.sh`) comes from `GXO_CONVERTER_DIR`, else `%OneDrive%/DE Converter`; the WSL
distro from `GXO_WSL_DISTRO`, else an exact `Ubuntu`, else the first `Ubuntu*` (this PC: `Ubuntu-24.04`, INC-195);
Blender from `BLENDER`, else `tools.blender.path` in the gitignored `config/tool-paths.local.json`.

Related: `gr2-granny-edit` (the edits), `unit-bones` (adding bones), `aoe3de-model-test-unit` (bench units for the
game test). Third-party origin and licence: [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
