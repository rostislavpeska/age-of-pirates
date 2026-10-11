# Definitions (one per metric)

Every metric of the skill has exactly one definition here and one implementation (named in brackets). Lengths are in
units of **H**, the height (Z extent) of the judged unit, unless stated. Frame: Z up, the character faces -Y, its left
side is +X. A number quoted with a reference id (hm08, S07, ...) was measured on that reference with this library.

## D0 Loading, frame and exclusion [tl_io.load]

- **OBJ** is read directly (`v`, `f` with any `v/vt/vn` form, negative ids, `g`/`o` group names); **GLB** by the own
  glTF 2.0 binary reader (raw indices per primitive, node world transforms, skin joints); **NPZ** (`V` + `F` + `off`);
  **.blend** and other formats through background Blender only (`-b --factory-startup --disable-autoexec
  --python-exit-code 2`).
- A **.blend is never opened as the main file**: the wanted objects (`--select REGEX`) or one collection
  (`--collection NAME`) are *appended* into the factory scene (`bpy.data.libraries.load`), so other assets of a mixed
  file are never loaded. The base cage is read: mesh data with modifiers off, in world space.
- **Exclusion**: `--exclude REGEX` (case-insensitive) drops object, node, group and collection names before anything is
  read. The calibration set passes `styli[sz]e|anime|cartoon` (owner 2026-10-12: "Learn only on realistic meshes!").
- **Axes**: OBJ and glTF are Y-up and become Z-up by (x, y, z) -> (x, -z, y), the Blender importer's rule; `--up z`
  keeps an OBJ as written; `--rot RX,RY,RZ` (degrees, XYZ order) is applied afterwards (S07 and S22 need `90,0,0`,
  S03 and S12 `0,0,-90`).

## D1 Canonical order [toplib.canonicalize]

After welding, only referenced vertices are kept and sorted by (x, y, z); each face is rotated to start at its
smallest id (winding kept) and the face list is sorted. Everything downstream runs on this order, so no result depends
on the file's vertex or face order (the OGT read-back, D14, reads the triangle order *before* this step by design).

## D2 Weld [toplib.weld_and_clean]

One rule: merge the **referenced** vertices that lie within **1e-6 x the bounding-box diagonal of the referenced
vertices** (transitively, union-find over a grid hash). Unreferenced helper vertices never enter the diagonal. Reported:
the vertex count at 0, 1e-6, 1e-5 and 1e-4 x diagonal (sensitivity), and a **fusion check** - non-manifold edges,
bow-tie vertices, duplicate and degenerate faces on the raw ids, after an exact-position weld and after the rule weld.
`fused_by_tolerance` is true when the rule weld made more of any of them than the exact weld: near-coincident shells
(stacked cards, hair layers) were fused by the tolerance and the result must not be trusted silently. Coincident
geometry that is already joined at exact positions (S14's lip corners) is the asset's own topology, not a weld effect.

## D3 Face clean-up [toplib.clean_faces]

Consecutive repeated vertices are dropped; a face with fewer than 3 distinct vertices is **degenerate**, a face that
still repeats a vertex is **invalid**, a face whose vertex set equals an earlier face's is a **duplicate** (and
**duplicate_reversed** when its winding is opposite). Only valid, first occurrences are kept.

## D4 Judged unit [toplib.judged_unit]

Every shell of the loaded part is judged (garments, teeth and separate limbs stay), minus:

- **eyeball shells**: any shell but the largest whose least-squares sphere has radius <= 10 % of H and RMS residual
  <= 5 % of that radius, open or closed - always excluded and listed (`--keep-eyeballs` judges them);
- **closing caps, only when declared** (`--declared-caps N`, e.g. the README-declared wrist cap of the Blender Studio
  realistic hand): a cap is one face of >= 5 sides, or a full fan of >= 5 triangles around one inner vertex, whose rim
  vertices each have exactly one edge outside it. When the found count differs from N nothing is excluded and the
  mismatch is reported; an undeclared cap always counts as the n-gon it is.

## D5 Face kinds and budget [toplib.face_kinds]

Faces by side count; quad share = quads / faces; **triangle equivalent** = sum of (sides - 2) = the triangle count after
any triangulation; stated deviation = |quads - tri_equivalent / 2| / (tri_equivalent / 2).

## D6 Manifold, boundaries, bow-ties [toplib.Topology]

An edge with 1 face is a **boundary** edge, with >= 3 faces **non-manifold**. A manifold edge whose two faces walk it in
the same direction is **flipped**. A **bow-tie** vertex is one whose incident faces form more than one fan (faces joined
through edges at that vertex). Boundary edges chain into **boundary loops** (at a vertex with several boundary edges
the next one is found by rotating through the fan of the face owning the incoming half-edge).

## D7 Inner vertices and poles [toplib.pole_census]

An **inner** vertex has faces, no boundary edge, no non-manifold edge and is not a bow-tie. **Valence** = number of
edges. A **pole** is an inner vertex of valence 3, 5 or 6+ (`v3`, `v5`, `v6plus`); valence <= 2 inner vertices are
listed apart. **6+ share = v6plus / referenced vertices of the judged unit** (the step-1 and step-2 convention).
Vertices excluded from the inner set (on non-manifold edges, bow-ties) are counted by valence in
`excluded_off_boundary`, so a count that includes them (the step-2 verifier's) is reproduced by adding them back.
**Pole chains** (P5): components of same-valence poles joined by edges.

## D8 Edge loops [toplib.Topology.edge_loops]

At every inner valence-4 vertex each edge is paired with the one edge that shares no face with it. An edge loop is a
maximal chain of edges through such pairings; every edge belongs to exactly one loop. A loop is **closed** when it
returns to its first edge, otherwise **open** with two **stops** (the vertices where it ends: a pole, a boundary,
non-manifold or bow-tie vertex).

## D9 Quad quality [toplib.quad_quality]

Per quad: **aspect** = longest / shortest edge; **corner angles** (3D); **planarity** = dihedral angle between the two
triangles of the shorter diagonal; **concave** = in the quad's Newell plane the four turning directions are not all
equal, with the worst reflex corner reported (`concave_worst_deg`, > 180); **zero-area** face = area below 1e-10 H^2;
**neighbour area ratio** = per face the largest area ratio to an edge neighbour. Reported as percentiles over the quads.

## D10 Face rings [toplib.Topology.face_strips]

Quads chained across opposite edges; every quad is in exactly two strips (one per direction). A **closed** strip is a
face ring.

## D11 Rings of a segment [tl_features.find_rings, ring_strips, ring_cover]

- **Edge ring** of segment s: a closed edge loop that winds exactly once around s's axis (winding number of its
  vertices, D11 `toplib.winding_number`), whose centroid lies at t in [-0.2, 1.2] of s, and >= 75 % of whose vertices are
  labelled s or a neighbour of s (D19). A loop qualifying for several segments belongs to the one owning most of its
  vertices, then the one with t nearest 0.5. Reported per segment: t, sides, tilt (angle between the loop plane normal
  and the bone), radius.
- **Ring strip** of s: a closed face ring (D10) that winds once around s's axis (ordered face centroids) with >= 75 % of
  its faces labelled s or a neighbour (face label = majority of its vertex labels).
- **Ring cover** (L1): share of s's shaft faces (centroid t in [0.25, 0.9]) on ring strips of s, and on perpendicular
  ones (cos tilt >= 0.8). Density-free: a low-poly limb with one face row per segment is covered by its one strip. The
  root quarter belongs to the shoulder / hip flow (D20).

## D12 Joint bands, joint rings, band poles [tl_features.joint_rings, band_poles]

For a joint between parent and child segments: **pivot** = the child's start joint; **plane normal** = bisector of
the two segment directions (the head joint's plane leans 50 deg forward, calibrated on the hm08 weights);
**band length** = the longer of the two segments. A vertex or ring centroid is **in the band** when its distance to the
pivot plane is <= 15 % of the band length, **on the pivot ring** at <= 5 %. Joint rings = rings of the two segments in
the band; **spacing ratio** = median gap between the offsets within +-20 % / median gap of all offsets (L3).
**Band poles** = poles labelled with the joint's segments inside the band; the **crease half** is the flexion side
(elbow front -Y, knee back +Y) - P3 gates crease poles, extension-side poles (kneecap, elbow tip) are reported.

## D13 Eye, mouth and mask rings from topology [tl_features.face_features]

No rig markers. **Candidates**: closed edge loops and closed boundary loops whose vertices are all head-region, facing
forward (plane normal within 60 deg of -Y) with radius <= 0.3 x head height. **Family** of a candidate = the closed
edge loops (not boundaries) containing its centroid in their plane. **Eyes**: the mirrored pair off the midline in the
upper 60 % of the head with the largest family sum (ties: the larger candidates, i.e. the eye opening rather than a
corner detail inside it); **e** = eye distance. **Mouth**: the midline candidate 0.6-1.6 e below the eyes, radius < 0.9 e,
with the largest family. **Ring around a centre c**: a closed edge loop with centroid within 0.6 e of c (front view),
radius < 0.9 e, containing c and no other feature centre. **Mask loops**: loops of radius < 1.5 e containing the mouth
and the nose tip (most forward midline vertex between mouth and eyes) but no eye. **Face poles**: head poles within 1.2 e
of the landmark centre, by nearest landmark (within / beyond 0.6 e). **Face mode**: head triangles > 1500 animated,
> 700 static, else a plane-map head (eye rings not required, F1 reported).

## D14 OGT read-back [tl_io.fan_runs, ogt_read_back]

Source polygons from the glTF triangle order, on **raw** indices (never welded ids): triangle k+1 continues a run when
it shares the run's first corner and its second corner is triangle k's third. The read-back is used only when >= 90 %
of strict pairs (0,1), (2,3), ... share an edge. A run of even length > 2 is split into consecutive pairs (quads) when
its polygon repeats a welded vertex or its primitive is a pure quad stream. A remaining six-corner run is ambiguous (a
hexagon or two quads fanned from one corner) and is **read as two quads** (a,b,c,d) + (a,d,e,f) and counted
(`ambiguous_six_runs`); `six_runs_as_pairs` gives the same reading of a polygon list. Measured: S01 34, S15 4, S14 0.

## D15 Tris to Quads [tl_io.add_t2q, tl_blender t2q]

When the order is lost: weld + clean + canonicalise the triangles (D1-D3), build a bmesh, **compute the face normals**
(`normal_update`, the step-2 defect was join_triangles on zero normals), then `bmesh.ops.join_triangles` with face and
shape thresholds 180 deg, topology influence 1.15, no seam / sharp / UV / colour / material compare. Reported:
`zero_normals_after_update` (must be 0). The pairing breaks ties by face order, so counts agree with another run's
within about 0.2 % (S15: 1561 vs 1558 faces).

## D16 Symmetry [toplib.symmetry]

Mirror plane x = the bounding-box middle. **Partner share** = vertices whose mirror image has a vertex within 1e-4 H;
**face mirror share** = faces whose mirrored vertex set is a face; **centre vertices** = |dx| < 1e-4 H, **inexact** when
|dx| > 1e-5 H.

## D17 Skeleton from the asset [tl_skeleton.canon_from_rig, complete, rig_mismatch]

Joint names (GLB skins at their bind pose = mesh-node world x inverse bind matrix; Blender armature bone heads; OBJ
joint groups as the mean of their vertices) map to canonical keys by name tokens (Mixamo, Bip01, Rigify DEF, MakeHuman
`joint-` styles). A rig is rejected when > 10 % of its joints lie outside the mesh box grown by 10 %, the head joint
sits below 0.7 H or a knee above its hip. Derived joints: pelvis = mid hips, chest = mid pelvis-neck, top = crown,
hand tip = farthest vertex past the wrist (none when nothing reaches 0.01 H past it), toe tip.

## D18 Landmark estimator [tl_skeleton.estimate_joints, arm_chain, section_components]

For assets without a usable rig: proportions of a standing adult (Drillis & Contini) refined by **plane sections** of
the mesh edges - exact at any density - split into connected polylines (crossing points of edges sharing a face), the
polyline nearest the expected place being used. Knee = leg section centroid at 0.285 H; ankle = the knee -> 0.08 H line
extended to 0.045 H; hip 0.01 H inside the 0.45 H thigh section, at 0.51 H; **arm**: the centre line is walked from
the hand tip toward the body through perpendicular sections (0.01 H steps) until the section merges with the torso
(radius > 2x the arm's running median, tested beyond 0.15 H from the tip); shoulder = the last arm centroid one arm
radius further; elbow and wrist at the Drillis fractions 0.186 / 0.44 and 0.332 / 0.44 of the shoulder -> tip line;
neck = the narrowest horizontal section between 0.80 and 0.93 H. Measured against the assets' own rigs: median joint
error 0.023 H (hm08), 0.013 H (S07), 0.015 H (S22); worst 0.047 H.

## D19 Segments, labels and regions [tl_skeleton.build_segments, segment_labels, clean_labels]

Segments: spine (pelvis-chest, chest-neck), neck, head, clavicles, upper arms, forearms, hands, pelvis halves, thighs,
calves, feet; regions head, neck, torso, arms, hands, legs, feet. A vertex takes the segment with the smallest capsule
distance / radius prior among the segments whose slab (between their joint planes) contains it, else among all.
**Connectivity clean-up**: within each shell every label keeps only its largest edge-connected piece; other pieces (an
elbow ring the fat torso capsule claimed) take the majority label of their neighbours. A face's region is the majority
of its vertices' regions.

## D20 Shoulder and hip flow [tl_features.flow_measure, limb_radius]

The step-1 ring metric reads 0 at the shoulder and hip even on hm08, because the loops there wrap the limb root without
being closed rings of one segment. **Zone**: t in [-0.25, 0.35] of the child segment (upper arm / thigh) from the
pivot, radial distance <= 2.5 x the local limb radius (mean distance of the section at t 0.4, D18 sections). Every edge
loop is cut into runs of consecutive zone vertices; a run that turns >= 0.75 of a full turn around the child axis
**wraps** the root. Reported: wrapping runs (t, tilt), closed rings among them, runs at t 0-0.25 (`arm_root_wrapping`),
tilt slope. hm08: 4 arm-root runs per shoulder.

## D21 Region density [tl_features.region_density]

Per region: faces, triangle equivalent, its share of the judged unit's triangles (**tri share**), area share,
**density ratio** = tri share / area share, median face area. **Head share** = head tri share; **head with neck** adds
the neck.

## D22 Pole zones [tl_features.pole_zones]

Every pole gets one zone, first match wins: hands / feet region -> hand / foot; head region -> face_site (within 1.0 e of
an eye, the mouth or the nose in the front view), neck_stump (head parts, > 0.8 e below the mouth), ear_side (>= 0.6 of
the half head width from the centre), head_top_back (behind the head centre or above the eyes), head_planes (no face
found), else face_other; neck region -> jaw_line / neck_base (head / neck-base band), neck_back, else neck_front; limbs
and torso -> inset_pattern (D26, off the crease), elbow / knee band: bend_band on the crease half, joint_cap on the
extension half (kneecap, elbow tip), shoulder / hip band (+-15 %), wrist / ankle band (+-25 %, the hand and foot
funnels), shoulder_root / hip_root (t <= 0.35 of the upper arm / thigh), torso:
armpit_side_chest, back_flat, crotch, chest_abdomen; else limb_mid. **Unexplained**: bend_band, limb_mid, face_other,
neck_front.

## D23 Plane map [tl_features.plane_map]

For heads up to 700 triangles: head faces grown into near-planar patches - seeds in order of decreasing area, a
neighbour joins when its normal is within 20 deg of the patch's area-weighted mean normal. Per patch: faces, triangles,
area share, normal, centre (x head height), facing, side.

## D24 Limb edge alignment [tl_features.limb_edges]

Edges inside one limb segment: parallel share (within 20 deg of the bone), perpendicular share (within 20 deg of
perpendicular).

## D25 Ring parity [tl_features.ring_parity, band_faces]

Between consecutive rings of a segment with N != M sides: the **band** = the face component(s) touching both rings once
both rings' edges are cut (None when the rings do not cut an annulus). In an all-quad annulus 4Q = 2E_inner + N + M,
so N + M is even; an odd step needs a triangle or an n-gon in the band (`odd_without_nonquad` counts the failures).

## D26 Inset patterns [tl_features.inset_patterns]

Clusters of >= 2 edge-joined valence-3 / valence-5 pole pairs within 3 edge hops of each other, with as many 3-poles as
5-poles and every 3-pole nearer the cluster centre than its 5-pole: one inset (kneecap, elbow cap, nipple, navel).

## D27 Verdicts [rules.check]

PASS, FAIL, REPORT (measured, no threshold in this profile, or a pipeline rule on a reference), N/A (an input is
missing, named in `needs`). **gate** = no must rule fails; **grade** = no must or should rule fails (reference grade);
`expected_fail` = failures named in the reference's recorded defects, `unexpected_fail` = all others.

## B Blueprint [blueprint.build]

The structure a builder can follow, as counts, ratios and normalised positions only - never coordinates or faces, so a
blueprint of a third-party reference is a measurement, not a copy. Lists are sorted by measured keys; the hash is the
SHA-256 of the canonical JSON without `meta` and `hash`.

| Field | Meaning |
| --- | --- |
| B1 `budget` | faces, quads, tris, n-gons, triangle equivalent (D5), quad share, vertices, caps and eyeballs excluded (D4) |
| B2 `regions`, `head_share`, `head_with_neck_share` | per region tri share, area share, density ratio, faces (D21) |
| B3 `poles` | counts by valence, pole share, by region, by zone (D22), and the **list**: valence, region, zone, segment, t along it, angle around it (5 deg steps, front = 0), radius (x H); without a segment the position relative to the box centre (x H) |
| B4 `loops` | open loops with their **start and end stops** (type: pole3/pole5/pole6+/boundary/nonmanifold/bowtie, the pole id of B3, region) and the regions they cross; closed loops with sides and **role** (ring:<segment>, eye_l, eye_r, mouth, mask, none) |
| B5 `pole_links` | how many open loops join each pair of stop types (pole5-pole5, pole3-boundary, ...) |
| B6 `rings` | per segment: count, t, sides, tilt, median sides, partial rings (D11) |
| B7 `joints` | per joint: rings in the band and their sides, spacing ratio, band poles, pivot-ring poles (D12) |
| B8 `flow` | shoulder and hip: wrapping runs, closed rings, t and tilt of each (D20) |
| B9 `face_rings` | closed face rings by region with their lengths, open strips (D10) |
| B10 `face` | eyes / mouth found, eye and mouth rings and their sides, mask loops, eye distance (D13) |
| B11 `plane_map` | low-poly heads: planes, planes over 2 % of the area, each patch's faces, area share, normal, centre, facing, side (D23) |
| B12 `symmetry`, `hash` | partner and face-mirror shares (D16); the deterministic hash (same mesh in any vertex or face order -> same hash) |
