# Interior faces: initial research and failed simplifications

Historical research below precedes the accepted consumer
[proxy/exposure aftercheck](proxy-aftercheck.md). Preserve these failed hypotheses;
do not treat this earlier proposal as the final implementation.

2026-09-27. The preferred Hybrid result still left colored surfaces when the user
entered the building. Preserve the baseline while investigating a separate pass.
This note records measured failures and a proposed next experiment; it does not
authorize automatic recoloring or UV allocation.

## Diagnose which side is being seen

An interior camera can see an actual inward-facing polygon, the reverse of an
exterior polygon, a polygon spanning both regions, or an external surface through
an opening. These are different cases. Render polygon IDs and front/back flags
alongside material colors. Map every analytical sample to the original polygon.
A material on one exterior polygon cannot generally become black on its reverse
without changing the representation; do not recolor it as though it were a
separate interior polygon. Preserve physical material families under the display.

In the measured building, four room seeds and six 160-square cubemap views per
seed found 119 still-colored polygons, including 84 with near-vertical normals.
All colored hits in these probes were front-facing. Two independent native
Blender Workbench renders reproduced the issue. This is a diagnostic sample,
not whole-model ground truth, and not all 119 are safe backing candidates.
One stone-cap polygon was visible from both inside and outside.

## Why the baseline and a simple enclosure fix fail

- The baseline opposing-surface channel only contributes for downward normals.
  Vertical room walls and upward floors get no support from it. In one observed
  face, a few outside pixels exhausted the image support while a zero-exposure
  ray result alone produced a score of 1.5/4.4, below the cut threshold.
- A room assembled from separate closed wall boxes is empty space. A winding
  number test returned approximately zero in the room and outside, and one inside
  a wall. Solid containment alone therefore cannot identify that room.
- A new, undilated grid experiment blocked neighbour connections when a segment
  crossed a surface. It correctly distinguished a sealed room from an open-door
  room and open courtyard. On the actual building, all four rooms connected to
  outside on one shifted grid. Tower-lower enclosure changed with grid alignment.
  Verified escape paths approached surfaces within 0.00030–0.00131 scene units.
  These are sampled clearances, not measured crack widths or widest-path bounds.
- Treating every path to outside as decisive propagates tiny-gap errors. Closing
  gaps indiscriminately can instead seal real doors, courtyards and alpha openings.
  Neither failure is cured by increasing the weight of the same binary test.

## Proposed two-pass experiment

Keep the established underside evidence as pass one. Pass two should reason
about **surface sides and surrounding spaces**, independently of vertical angle.

1. Split only the read-only analysis domain into patches where exposure changes;
   retain original quad/ngon topology and stable face IDs. Establish both sides,
   local thickness, coincident/intersecting surfaces and facing consistency.
2. Build a visibility graph between oriented patches. Connect samples across
   clear air, not merely adjacent mesh edges. Use cosine-weighted directional
   evidence and area-normalized connection strength. Distinguish weak crack
   leakage from broad external exposure; keep explicit opening/alpha controls.
3. Seed exterior space from outside evidence. For experimental interiors use
   verified room probes. A future factory may use authored room volumes or an
   independently tested automatic region finder. Manual diagnostic seeds are not
   evidence of fully automatic detection.
4. Compare an interior/exterior cut across sampling densities, offsets and leakage
   weights. Never select the weight solely because it makes one screenshot black.
   Preserve uncertain or mixed polygons, with separate reason codes.
5. Combine proposals with pass one only after independent exterior validation.
   A proposal may be physically interior yet exposed through a real opening.
   Keep it detailed, or propose a later controlled quad split at a construction
   boundary; no whole-polygon density reduction on mixed evidence.

This is a proposed pipeline, not an implemented or accepted new classifier.
The existing scripts still reproduce the documented Hybrid baseline.

## Image and specimen acceptance contract

- Fixed interior viewpoints: all rooms, both tower levels, wall backs, upward
  floors and roof junctions. Use material colors plus ID/depth/side buffers.
- Independent exterior views: offset azimuths/elevations, courtyard, doors,
  gables, beam ends and cutouts. Test actual opacity before a gameplay claim.
- Compare colored interior area against curated interior controls; compare
  exterior pixel changes before/after. Report mixed polygons separately.
- Test sealed room, open door, open courtyard, narrow slit, overlapping walls,
  single-sided facade and a polygon straddling an enclosure boundary. Vary the
  crack/opening scale and rendering side rules. The first three connectivity
  specimens have been run; this full proposed acceptance suite has not.
- Retain selectable review scenes, matched pictures, raw measurements and hashes.
  Agent image review precedes one consolidated user review. Do not promote the
  replacement formula until those checks pass.

## Primary research

[Zhou et al., 2008, Visibility-driven mesh analysis through graph cuts](https://peterwonka.net/Publications/pdfs/2008.VIS.Zhou.VisibilityMeshAnalysis.Final.pdf)
classifies oriented surface sides through sampled visibility connections and a
cut. It discusses weak connections through cracks and mixed/intersecting patches.
Our proposed room pass adapts that distinction to backing-material allocation;
the current Hybrid adjacency graph is not a reproduction of this algorithm.

[Jacobson et al., 2013, Generalized winding numbers](https://igl.ethz.ch/projects/winding-number/)
provides solid inside/outside reasoning. Its project notes explicitly distinguish
the two-sided visibility problem and warn about ambiguous enclosed cavities.

[CGAL Alpha Wrap 3](https://doc.cgal.org/latest/Alpha_wrap_3/index.html)
offers a conservative enclosing analysis proxy with scale-controlled openings.
It is an alternative to investigate, not an installed dependency or an excuse to
remesh authoring geometry. A proxy can erase meaningful openings; validate against
the original surfaces and images.
