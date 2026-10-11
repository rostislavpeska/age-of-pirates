# Calibration record (2026-10-12)

How the 60 step-1 rules were re-pointed at this library and recalibrated. Every number is a measurement with this
library (version in `toplib.LIB_VERSION`) on the reference named; no reference mesh, render or coordinate is stored in
this package. Rule texts and thresholds: [rules.json](rules.json); definitions: [definitions.md](definitions.md).

## Principle

A rule that an accepted professional reference fails is a wrong rule (or a wrong implementation): it was recalibrated,
narrowed or turned into a report - unless the failure is a defect recorded at intake. Every change cites the reference
that forced it (`recalibrated` in rules.json). Rules our own pipeline needs but practice does not (mirror-exact build,
export triangulation, layers, wrap) have scope `pipeline` and are only reported on references.

**Learn only on realistic meshes** (owner 2026-10-12): no stylized, anime or cartoon mesh was loaded, measured,
calibrated on, tested on or shown. The Blender Studio bundle is read by appending named realistic objects only, with
`--exclude styli[sz]e|anime|cartoon`; S06 is gone. An interrupted earlier run had surveyed S06 and four stylized
Blender Studio assets: those outputs, three S06 renders and four inventory/debug scripts were deleted, and nothing in
the thresholds below comes from them.

## Sets

| Role | Items | Use |
| --- | --- | --- |
| calibration | hm08 (MPFB2 base mesh, CC0, must pass every rule), proxy741, male1591, Blender Studio planar head, Blender Studio realistic male and female bodies, S03, S07, S12 LOD1-LOD4 | thresholds |
| reference (hold-out) | female1605, the four high-poly MakeHuman proxies, Blender Studio generic head / realistic hand / realistic foot (caps declared) / primitive realistic male body, S01, S14, S15, S22, S25, six MakeHuman garments | validation, findings below |
| control | a Decimate copy (ratio 0.10) and a QuadriFlow copy (2000 faces) of hm08 | must fail |
| vanilla | 63 AoE3 DE bodies (Tris to Quads) | game-layer profile only (budgets, shares), never quad-quality thresholds |

The [item list](calibration_items.json) holds every calibration and reference item with its orientation, selection
and recorded defects (paths as `<library_root>` / `<mpfb>`). Rig-less references use the estimator (D18); the MakeHuman
proxy OBJs are NOT in hm08's default shape (the hm08 joints fall outside proxy741's arms), so hm08's skeleton is never
lent to them.

## Result

- **hm08 passes every rule** (grade PASS).
- **Every calibration item passes the reference grade**; S03 fails only P1, its recorded defect (6+ poles 1.41 %).
- **Both controls fail**: Decimate the gate (M1, P1, P3) and the grade (L1, L2, L5, M7, M8, P2, P4, P5, R1); QuadriFlow
  the gate (M4) and the grade (L1, L2, P2, P4, P5, M9 as a build).
- **Our G1 r2 LOW** fails M1 and P1 (64 triangles, 12 6+ poles, mostly fan caps) and, under the game profile, **F5**:
  head with neck 8.4 % of the triangles (94 triangles) against the vanilla range 20.8-30.7 % and minimum 172.

| rule | calibration verdicts | controls failing | calibration extremes |
| --- | --- | --- | --- |
| M1 | PASS 12 | Decimate | - |
| M2 | PASS 12 | - | - |
| M4 | PASS 12 | QuadriFlow (1.27 %) | concave share 0 (hm08) .. 0.255 % (male1591) |
| M5 | PASS 12 | - | 0 (S12 LOD1) .. 7.0 % (male1591) |
| M6 | PASS 12 | - | aspect p99 3.8 (BS male) .. 12.7 (S12 LOD2) |
| M7 | PASS 12 | Decimate | corner p1 21.3 (S12 LOD3) .. 42.7 deg (S07) |
| M8 | PASS 12 | Decimate | area ratio p99 3.6 (S07) .. 13.7 (S12 LOD2) |
| P1 | PASS 11, FAIL 1 (S03, recorded) | Decimate | 6+ share 0 (hm08) .. 0.97 % (S12 LOD2) |
| P2, P5 | PASS 12 | both | - |
| P3 | PASS 7 (bodies) | Decimate | - |
| P4 | PASS 7 | both | - |
| L1, L2 | PASS 7 | both | ring cover: proxy741 upper arm 0.56, S03 forearm 0.59, others >= 0.95 |
| L3, L5, L7 | PASS 7 | L5: Decimate | spacing ratio <= 1.07 (Blender Studio knees) |
| F1, F2, F3 | PASS where the face mode asks, else REPORT | - | eye rings: hm08 21, BS bodies 11, S12 LOD2 2 |

## What changed from the step-1 checklist

| Rule | Step 1 | Now | Forced by |
| --- | --- | --- | --- |
| M4 | 0 concave quads | <= 0.3 % of quads | Blender Studio bodies 8 folded quads (189-359 deg), male1591 4 |
| M5 | <= 3 % bent over 30 deg | <= 10 %, bodies and heads | male1591 7.0 %, proxy741 6.6 %; hold-outs S15 8.5 %, female1605 9.5 % |
| M6 | p99 7.5, max 14 | p99 13, max reported | S12 LOD2 12.7; single quads up to 35 (BS male) |
| M7 | p1 35 deg, min 12 deg | p1 20 deg, min reported | S12 LOD3 21.3; single corners down to 2.3 deg (BS male) |
| M8 | p99 6, max 11 | p99 15, max reported | S12 LOD2 13.7, S15 14.5; single pairs up to 76 |
| M5-M8 | all parts | bodies and heads gated, hands and parts reported | no hand or garment in the calibration set |
| M9 | mirror-exact | pipeline rule | references symmetric to ~1e-3 H only (BS bodies 0.50 at 1e-4 H, 0.99 at 1e-3 H) |
| P1 | no 6+ pole | <= 1 % of vertices | S07 0.94 %, S12 LOD2 0.97 %, male1591 0.88 % |
| P2 | zones | + shoulder_root, hip_root, joint_cap (extension half of elbow / knee), wider wrist / ankle bands, neck_stump | BS armpit poles, kneecap poles, S03 wrist poles at 0.20, S15 neck |
| P3 | every band pole | crease-side band poles | MakeHuman generic proxies and S01: kneecap / elbow-tip poles on the extension side |
| P4 | shoulder, elbow, wrist, knee | wrist reported | wrist-ring poles on BS (2-5), S03 (2), S07 (2) |
| P5 | skip hands, feet, face, ears | + head_planes | the planar head chains poles along plane borders |
| L1 | rings per length, covered 0.8 | shaft faces on ring strips, 0.5 | low-poly limbs with one face row per segment (proxy741, S03) |
| L2 | elbow 2, knee 2 | elbow 1, knee 2 | proxy741, male1591 bend the elbow on one ring |
| L3 | <= 1.0 | <= 1.1 | BS knees 1.05-1.07, male1591 elbow 1.02 |
| L5 | 2 straw rings + pole placement | pole placement only, straw count reported | BS bodies run the neck-concentric rings over the deltoid (0-1 wrapping runs) |
| L6 | V-ring + thigh ring | reported | only hm08 shows a V-ring |
| F1 | plane heads <= 600 tris | <= 700 | BS planar head 632; S12 LOD2 at 796 has eye rings |
| R1 | always | only at the reduction stage | it re-runs M1 + P1 + P3 |

## Hold-out findings (accepted references that still fail - reported, not recalibrated)

- **S01**: 3 crease-side poles at each knee (P3; its 5 elbow poles sit on the extension side), elbow ring spacing
  2.6-2.8x mid-arm (L3), crease and mid-limb poles (P2), poles on the elbow ring (P4), a same-type chain (P5) -
  besides its recorded 168 triangles (M1).
- **MakeHuman muscle proxies**: 8 crease-side knee poles (P3), knee spacing (L3); **generic proxies**: crease-side and
  mid-limb poles (P2), a pole on the knee ring (P4).
- **female1605**: 24 folded quads (1.5 %, worst 322 deg, M4) - a geometric defect, the threshold was not widened (it
  would pass the QuadriFlow control).
- **S22**: one ring at the knee (L2), poles at the face sides (P2) - besides its recorded non-manifold wrist rings.
- **Blender Studio primitive body**: separate-part assembly (open tube ends at every joint): fails the joint rules by
  construction; kept as a proportion reference only.
- S14 fails only M2 (recorded); S15, S25, the hand, foot and the garments pass.

## Estimator and verifier checks

- Estimator against the assets' own rigs: median joint error 0.023 H (hm08), 0.013 H (S07), 0.015 H (S22); worst
  0.047 H.
- Step-2 verifier reproduced: S15 and S01 OGT exactly (S15 1532 faces / 1526 quads / 6 tris / poles 68-50-10; S01 4477 /
  4309 / 168 / 87-207-19) with six-corner runs read as two quads, S14 OGT exactly once poles on its 12 non-manifold
  edges are added back (D7); Tris to Quads with normals: S01 and S14 faces / quads / tris exactly, S15 1561 / 1497
  against 1558 / 1500 (tie order), poles within 7 %.

## Vanilla survey (game layer)

63 AoE3 DE bodies through Tris to Quads: triangle budget p10-p90 872-1257 (median 1066), head with neck 20.8-30.7 %,
head with neck triangles p10 172, region shares and limb ring sides (forearm 6, calf 8, waist 10). Written by
`profile_from_survey.py` into a game profile kept in the game layer, not here. Vanilla meshes are triangle-authored
(T2Q quad share 84-94 %, aspect p99 up to 50): they set budgets and shares, never quad-quality thresholds.
