---
name: character-topology-analysis
description: Measure and judge the quad topology of a character mesh (body, head, hand, garment) with one metric library - weld, judged unit, face kinds, poles, manifold, edge loops, limb and joint rings, eye / mouth rings found from topology, shoulder and hip flow, regions and density, symmetry - write its topology blueprint (loops with their stop poles, rings per segment, pole list, plane map, budget, deterministic hash) and check the 60 calibrated topology rules (gate and reference grade). Use to analyse a reference or our own character mesh, to compare a build against references, to turn a reference into a blueprint a builder can follow, to recalibrate a rule, or to derive a game profile from shipped units. Reads OBJ, GLB (with the source polygons read back from the triangle order), NPZ and .blend (background Blender). Not for modelling, UVs or rigging themselves.
---

# Character topology analysis

One metric library for clean QUAD low-poly characters: every metric has one written definition
([definitions.md](references/definitions.md), sections D0-D27 and B) and one implementation (`scripts/toplib.py`,
`tl_skeleton.py`, `tl_features.py`; loading in `tl_io.py`, Blender only through `tl_blender.py`). The 60 rules of the
step-1 topology checklist are re-pointed at it ([rules.json](references/rules.json)) and calibrated on accepted
realistic references ([calibration.md](references/calibration.md)). The package holds no reference mesh, no render of
a third-party model and no device path.

## Hard rules

- **Learn only on realistic meshes** (owner 2026-10-12). No stylized, anime or cartoon mesh is loaded, measured,
  calibrated on, tested on or shown. Pass the exclusion (`--exclude "styli[sz]e|anime|cartoon"`, case-insensitive) for
  every mixed file; a .blend is never opened whole - only the selected objects or collection are appended (D0).
- References are **analysis only**: read in place, never copied, never written to. Outputs and pictures go to a work
  folder outside every repository (`survey.py` and `render_topology.py` refuse a git work tree); quoted numbers carry the
  reference id.
- Python that reads downloaded files runs with **`python -I`**; Blender runs **background only**
  (`-b --factory-startup --disable-autoexec --python-exit-code 2`, done by `tl_io.run_blender`), never a live session.

## Local prerequisites

Host Python 3.9+ with numpy (all metrics) and Pillow (pictures); pytest for the tests. Blender (4.x / 5.x; numbers here
from 5.1.2) only for .blend files, foreign formats, Tris to Quads and the control generator, found through the
companion `blender-organic-modeling/scripts/blender_env.py` (`--blender EXE`, `--local-config FILE`, `BLENDER`, PATH,
the standard folder). Follow the [local-tool guidance](../skill-library-audit/references/local-tools.md).

## Commands (from this folder's `scripts/`)

```bash
python -I toplib.py measure MESH [--kind body|head|hand|part] [--select RE] [--exclude RE] [--collection NAME]
       [--group G] [--rot RX,RY,RZ] [--skeleton auto|rig|estimate|FILE.json] [--face-source native|ogt|t2q]
       [--declared-caps N] --out report.json          # every metric (JSON report)
python -I blueprint.py MESH [same options] --out blueprint.json      # the blueprint + its hash
python -I rules.py MESH [same options] [--profile P.json] [--declared-openings N] [--stage authoring|reduction|export]
       [--face-mode auto|animated|static|planes] --out rules.json     # exit 0 = gate PASS, 1 = a must rule fails
python -I render_topology.py MESH [same options] --out OUT.png [--view front|34|left|...] [--zoom head|shoulder_l|...]
       [--color region|plane|plain] [--skeleton-overlay]
python -I survey.py ITEMS.json --root library_root=DIR --root mpfb=DIR --out WORKDIR [--only ids] [--renders]
python -I calibrate.py WORKDIR --out table.json --md table.md        # per-rule evidence, CALIBRATION MISMATCH lines
python -I profile_from_survey.py WORKDIR --name GAME --out game_profile.json   # game-layer budgets and shares
```

- **Face source**: `native` = the file's polygons; `ogt` = a GLB's source polygons read back from the triangle order
  (D14, six-corner runs read as two quads and counted); `t2q` = Blender Tris to Quads with normals computed (D15) when
  the order is lost. Judge Sketchfab GLBs on `ogt` whenever the read-back is used (strict pair share >= 90 %).
- **Skeleton**: `auto` = the asset's rig (GLB skin at bind pose, armature, OBJ `joint-` groups via
  `--joints-from-groups joint-`) else the landmark estimator (D18, median error 0.013-0.023 H against rigs); a given
  JSON maps canonical keys (`l_shoulder`, `l_elbow`, ... `neck`, `head`) to positions in the mesh frame. Never lend one
  asset's skeleton to another mesh (the MakeHuman proxy OBJs are not in hm08's shape).
- **Frame**: Z up, facing -Y, left +X; fix a GLB with `--rot` (S07 `90,0,0`, S03 and S12 `0,0,-90`).
- [calibration_items.json](references/calibration_items.json) is a ready `survey.py` item file for the calibration and
  hold-out sets (`--root library_root=... --root mpfb=...`).

## What is measured (one line each; definitions.md has the rule)

| Metric | Definition |
| --- | --- |
| weld, fusion check | 1e-6 x diagonal of the referenced vertices; raw / exact / rule counts of non-manifold edges, bow-ties, duplicates (D2) |
| judged unit | all shells; eyeball shells out; caps out only when declared and found (D4) |
| face kinds, budget | quads / tris / n-gons, triangle equivalent (D5) |
| poles | inner valence 3 / 5 / 6+, 6+ share of the vertices, chains (D7) |
| manifold | boundary loops, non-manifold edges, flipped edges, bow-ties (D6) |
| loops and rings | edge loops through valence-4 vertices with their stops (D8); face rings (D10); limb rings, ring strips, ring cover (D11) |
| joints | bands +-15 % of the longer segment, joint rings, spacing ratio, crease / extension band poles (D12) |
| face | eyes, mouth, mask loops and face poles found from topology; face mode (D13) |
| flow | shoulder / hip wrapping runs in the root zone (D20) - the arm root the ring metric misses |
| regions | head, neck, torso, arms, hands, legs, feet: tri share, area share, density ratio (D19, D21) |
| quality, symmetry | concave, planarity, aspect, corners, neighbour area (D9); mirror partners and centre loop (D16) |
| plane map | near-planar patches of low-poly heads (D23) |

## The blueprint

`blueprint.py` writes counts, ratios and normalised positions only (never coordinates), sorted by measured keys, with
a SHA-256 hash that is identical for the same mesh in any vertex or face order. Fields (definitions.md B1-B12):
`budget`, `regions` and head shares, `poles` (counts, by region and zone, and the list: valence, segment, t along it,
angle around it, radius), `loops` (open loops with start and end stop type and pole id; closed loops with their role:
ring:<segment>, eye_l/eye_r, mouth, mask), `pole_links`, `rings` per segment (t, sides, tilt), `joints` (band rings,
spacing, band poles), `flow`, `face_rings`, `face`, `plane_map` (heads up to 700 triangles), `symmetry`, `hash`. A
builder follows it ring by ring and pole by pole; two builds compare by field, not by eye.

## Gates

- Levels: **must** (blocks the **gate**), **should** (blocks the **reference grade**), **may** (reported).
  Scopes: **practice** rules are claims about good topology, calibrated on the references; **pipeline** rules (mirror-exact
  build, export triangulation, layers, wrap) are our pipeline's needs and only REPORTed on a reference
  (`subject: reference`).
- A reference's **recorded defects** (registry intake) are listed as `expected_fail`, never hidden; everything else
  fails as `unexpected_fail`.
- The generic profile gates topology, not game numbers: budget (D1), head-first share (F5), region shares (D2), hand share
  (X1) and ring sides (D3) are REPORT until a **game profile** made by `profile_from_survey.py` from the game's shipped
  units is passed with `--profile` (it lives in the game layer, not here).
- Done means: our build passes the gate and the grade under the game profile, its blueprint is compared with the
  chosen reference's, and the pictures (`render_topology.py`) are in front of the owner.

## Known limits

- The estimator assumes a standing human (A or T pose, Z up, facing -Y); joint-band rules on a rig-less asset carry
  its ~0.02 H error. Pass a rig or a skeleton JSON when one exists.
- Shape heuristics M5-M8 are gated on bodies and heads only (no hand or garment was in the calibration set).
- Six-corner OGT runs are ambiguous (a hexagon or two quads); they are read as two quads and counted, and
  `tl_io.six_runs_as_pairs` gives the alternative. Tris to Quads breaks ties by face order (counts within ~0.2 %).
- L4, D4, D5, X2, R2, T2 and the layer / wrap rules need inputs the library does not derive (bend directions, part
  labels, camera silhouettes, poses, templates): they answer N/A with `needs`.
- Hold-out references that still fail (S01, the MakeHuman muscle proxies, female1605, S22) are findings in
  calibration.md, not reasons to loosen a rule.

## Tests

```bash
python -I -B -m pytest tests -q -p no:cacheprovider
```

Synthetic known-answer tests run anywhere; `test_blender.py` skips without Blender; `test_references.py` runs when
`CTA_LIBRARY_ROOT`, `CTA_MPFB_DATA` (and for single tests `CTA_VERIFIER_DATA`, `CTA_GAME_PROFILE`, `CTA_OWN_G1`) name the
inputs (see `tests/conftest.py`): hm08 passes every rule, the calibration set passes the grade except recorded defects,
Decimate and QuadriFlow copies of hm08 (made in a temp folder) fail, our G1 r2 squat head fails F5 under the game
profile, the estimator agrees with the rigs, the step-2 verifier's S15 / S14 / S01 numbers are reproduced.

## Handoff and journal

Each analysis phase ends with a `HANDOFF.json` next to its outputs (in this library the contract is
`blender-architecture-texturing/references/handoff-contract.md`). Record lessons when they happen with the
[workflow journal](../workflow-journal/SKILL.md) (`--skills character-topology-analysis`, stage `modeling`).
