---
name: blender-overlap-cleanup
description: Detect and repair overlapping architectural construction shapes, coplanar double surfaces and intersecting volumes in Blender. Includes an upfront joint-ownership gate and a repair gate before UV authoring; preserves quad/ngon authoring and separate destruction sources.
---

# Architectural overlap prevention and repair

An overlap here means **3D shapes layered or intersecting each other**, including
buried duplicated construction, not UV stacking. A coplanar-face test alone cannot
certify a clean model. Use with `blender-architecture`; UV reuse is a later task.

Use the established Blender MCP/API route. Confirm the live file, scene, mode and
objects; preserve unsaved work. Do expensive work on a saved independent copy.
Read [repair methods, evidence and limits](references/repair-methods.md) before
geometry changes. NumPy and Shapely 2+ are required for the supplied offline helpers;
Blender `bpy` is required for scene access. These helpers do not install software.

## Gate 1: prevent overlaps while constructing modules

- Assign a single owner to every corner post, sill, header, panel boundary and
  exposed surface. Do not repeat a complete end post from each adjoining facade.
- Define joins from shared construction coordinates. Rails and infill end at the
  post's inner boundary; horizontal/vertical modules share the same endpoint data.
  For a deliberate fused assembly, form its union boundary before duplication/UVs.
- Declare intentional layered details by role, support, clearance and render state:
  a ridge cap seated on a roof is different from an accidental duplicate panel.
  Name-based exclusions alone do not prove a good joint. Inspect its section.
- Validate one bay, a corner joining two rotated facades, a roof/wall junction,
  and any newly introduced prop construction. Test the assembled neighbor pair,
  not just isolated modules. Repeat after replication: corner-only defects may
  never occur in the straight specimen.
- Compare stages with stable part/face ancestry: source construction, assembled
  model, UV/material conversion, hidden-face splits, exported copy. Face-pair
  counts increase after subdivision without introducing new original-face pairs.
- Fail this gate before UV packing/AO/baking if a visible surface has competing
  owners or unexplained penetrating layers. Do not spend detailed texture work
  hiding geometric interference.

## Gate 2: detect, repair, validate, show

1. **Snapshot evidence.** Save positions, faces, geometric and corner normals,
   UVs, material/alpha classes, weights, part IDs and damage membership. Freeze
   the original capped/bake/destruction source separately from the intact shell.
2. **Run complementary detectors.** Across and within objects, measure duplicate
   and partial coplanar patches, transverse surface crossings, and positive-volume
   overlaps between verified solids. Containment can exist without a surface
   crossing. AABB/BVH hits are candidates, not final intersections. Log tolerances,
   nonplanar/alpha/open-shell exclusions and residuals.
3. **Choose a construction repair.** Remove fully redundant copies; trim partial
   shared patches to one owner; butt/miter adjoining members; form a proper union
   boundary for fused solids; reposition separate props. Retain intentional
   layered detail only after checking the actual joint and its visibility.
   Vertex merging or a tiny arbitrary offset is not a general volume repair.
4. **Preserve the contract.** Keep quads or deliberate planar ngons. Triangulation
   is permitted only on read-only measurement arrays or an export duplicate.
   Interpolate UVs/normals/weights at new cut corners; do not repack UVs or globally
   recalculate normals. Monitor vertex growth, small slivers and lost material
   labels. Keep alpha receivers protected unless the actual mask is evaluated.
   Intact union cleanup must not silently remove caps needed by separating debris.
5. **Validate the APPLIED Blender mesh.** Rerun all applicable detectors after
   float-coordinate serialization, not only on a double-precision plan. Check
   winding across UV/material seams, custom-normal direction, degenerates, loose
   geometry, UV interpolation, source preservation and budget. Re-run on a second
   application: unexplained substantial further trimming means non-idempotence.
6. **Agent visual check.** Inspect matched material, selected/wire and face-
   orientation images: every side/corner, marked/repeated locations, high/low,
   underside, interior, and grazing joints. Render-only views may conceal the
   striped selection artifacts visible in the operator's viewport. Use explicit
   readable orientation colors temporarily; restore theme settings afterward.
7. **Active manual handoff.** Append the repaired candidate into the live session,
   ACTIVATE that scene, frame it, keep meshes selectable and overlays/gizmos on,
   and inspect a separate native screenshot after the redraw. An inactive scene,
   colored diagnostic, unopened blend or report is not an updated model. Leave
   the repaired material-colored model active; retain diagnostics as secondary
   scenes. State actual changes, counts, unresolved contacts and user review state.

## Gate 3: deterministic logic QA (generated buildings)

Run `scripts/logic_qa.py` in the builder before saving and fail the build on any finding. It checks door free area
and support, window clearance, stair headroom, roof poke/embed, member pierce, protrusion beyond declared joints,
floating parts and z-fighting faces. Every finding is fixed in the generator or declared as a joint with a maximum
depth; never widen a tolerance to pass. It also lists advisory inspection topics (attachment, junction_proud, frame_proud, opening_band, near_gap); review
those, fix the real ones, and accept that some are false positives. Read [logic QA method, sources and pitfalls](references/logic-qa.md). Keep
project part vocabulary in the project and pass it with `configure()`. A clean report does not replace step 6 and
the owner's review.

## Helpers and verification

Before any texture or AO bake, run `scripts/shell_orientation.py` on the export set (`--names-from`, `--strict`):
every closed shell must enclose positive signed volume in world space. An inside-out shell passes UV integrity,
density and distant review renders, yet in game (back faces culled) the camera sees its recessed inner faces,
already darkened by AO (2026-10-10: a dock's gable boards read as black holes; 16 inspector views missed them).
Repair by reversing the winding, then re-check UV winding (a reversed face's UVs are mirrored). The same run lists
n-gons whose triangulation flips (`flipped_triangles`): a self-intersecting outline, e.g. a board whose sloped edge
ends below its curved bottom edge; make the outline simple and re-unwrap that face (its old UVs are distorted too).

For a declared covered trim/beam termination, use `scripts/termination_plane.py`
against the **actual sloped cover face**, in one coordinate system. Require the
specified setback for the complete end, then verify finite cover extent, alpha
and underside visibility in fixed corner views. This is a bounded geometric check,
not general collision or transparency certification. Its regression includes the
Korean House cap that protruded below a sloping eave despite plausible overall
bounds (owner, 2026-10-09); test both original failure and repaired coordinates,
plus rotated copies. Gap/contact tests alone do not catch protruding trim ends.

`scripts/overlap_geometry.py` supplies world-space coplanar intersection,
transverse crossing witnesses, positive box-volume overlap, protected-alpha handling, and planar union-boundary
planning against **caller-certified opaque boxes**. It does not certify boxes,
repair arbitrary curved solids, or mutate Blender. Read its explicit input and
opposing-contact policy. Reconstructing missing caps from a bounding box alone
is forbidden; actual boundary coverage or verified retained-union coverage is
required. Opposing contacts are report-only unless the intact-only policy is
explicitly justified.

Run `python -m unittest discover -s scripts -p 'test_*.py'` from this skill's
directory, and `blender -b --factory-startup --python scripts/blender_test_logic_qa.py` for Gate 3. These tests check geometry behavior, not artistic acceptance. Keep
consumer paths, models, renders and case reports outside this reusable package.

Record corrective prompts/app visits and measured human time. Separate agent
self-correction from user review rounds. User acceptance of a local candidate
does not certify every curved intersection or future building.
