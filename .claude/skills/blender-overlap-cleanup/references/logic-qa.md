# Deterministic logic QA (openings, roofs, joints)

`scripts/logic_qa.py` reports shapes that cannot exist or cannot be used: doors into nowhere, members poking
through roofs or through each other, parts touching nothing, coincident faces. It is read-only and runs inside
Blender on the generated LOW parts in world space. Run it in the builder before saving, and fail the build on
any finding (strict gate): every finding is either fixed in the generator or declared as a joint with a limit.

## Checks and the method behind each

| Check | Rule | Source of the method |
|---|---|---|
| door_free_area | rays through a box in front of each door/shutter (width x .9 m x 1.8 m; .6 m for raised gallery doors) | Solibri 226 "Free Area in Front of Components", 208 Accessible Door |
| door_support | a step, deck or floor within .40 under the sill, .45 out | IRC R311.3 landing at exterior doors (scaled) |
| window_clearance | rays .35 m out of each window | Solibri 226 applied to windows |
| stair_headroom | rays up 1.85 m from each tread | Solibri 210, IRC R311.7.2 |
| roof_poke | part crosses a roof shell, has points outside, exposed (+z ray misses the shell), > .03 above an upward face | composite: visibility from above + crossing |
| roof_embed / penetration | protrusion depth: deepest sample of A inside closed B, distance to B's nearest surface | IfcOpenShell clash "protrusion"; Navisworks hard clash depth tolerance |
| pierce | member axis enters and leaves B, both ends outside, B surrounds the member's section | IfcOpenShell clash "pierce" |
| floating | contact graph from the datum (ground or seabed) | Solibri 23 "Components Must Touch" |
| zfight | coincident same-facing faces (centroid within .5 mm, normals within 2.5 deg) | coplanar-duplicate checks (Navisworks Duplicates, Solibri) |
| open_shells | an edge used by an odd number of faces: containment undefined, listed | IfcOpenShell falls back for open meshes |

### Inspection topics (advisory, not a gate)

`R['inspect']` lists topics to look at. These are oddities that are not strictly impossible. Expect some false
positives. Fix the real ones in the generator and leave the rest listed; never silence a topic by widening a
tolerance.

| Topic | Rule | Caught (historical control) |
|---|---|---|
| attachment | a deck side faces the building within .20 but leaves a gap, or under 60% of that face touches something (rays start 1 mm behind the face, against each nearby part's own BVH) | balcony 9.5 cm off the wall, 6% contact; decks 4 cm short of a quay |
| junction_proud | a horizontal member (rail, band, beam) butting into a post sticks out beyond the post's faces | rails 7.5 cm proud of 3 cm posts |
| frame_proud | an opening frame stands more than .05 proud of the wall face | 12 cm window frames |
| opening_band | an opening's sill or head falls inside a horizontal band or rail, or leaves a sliver under .05 next to one | a window standing in the player-colour band; door thresholds 1 cm inside the sill rail |
| near_gap | two parts face each other across a .01-.08 slot over an area; noise pairs (one opening's internals, shutter boards, wall panels, roof assemblies) skipped; ranked by facing area | lattice 6 cm in front of its paper, a thatch not resting on its beam, railing bottom rails 2 cm above the deck |

Owner, 2026-10-09: "balcony is not attached to the building - can we extend the geometry check test to cover
these issues too? Maybe some false positives, but at least topics to inspect".

Containment is the generalized winding number (Jacobson 2013): exact 0/1 on closed meshes, including pinched
edges used by 4 faces, and graceful on imperfect ones. Ray parity breaks at shared edges and vertices.

## Joints are declared, not guessed

Intentional contacts (a bracket tenoned into a post, a cap seated on a roof, a rail into a post) pass only within a
maximum protrusion per family pair (`JOINTS`), plus per-pair declarations. A joint deeper than its limit is reported.
Project vocabulary (part names, extra families) goes in through `configure()` from the project's builder, never into
this file. Name-based exclusion without a depth limit hides drift, as warned in Gate 1.

## Pitfalls found while building it (each produced false results first)

- **Measure depth to the nearest surface.** "Distance along +z to the first surface" reports a 2 cm rail tenon as
  50 cm deep, because the measurement runs to the top of the post. Use `find_nearest` distance.
- **Sample faces, not just vertices.** A post sunk into a girder with a coplanar bottom face has no vertex inside the
  girder. An 8 cm in-plane lattice on every triangle catches it. Points within .2 mm of a surface are contacts.
- **Never use a polygon's vertex mean as a face sample.** The mean of a concave n-gon can lie outside the face. A board
  whose top follows a sagging roof underside produced false 3-4 cm embeds. Use triangle centroids.
- **Touching is not crossing.** BVH `overlap()` reports touching faces and misses coplanar overlaps and fully
  contained parts. Decide contact with a 4 mm normal-inflated BVH, and decide clashes by depth.
- **Pierce needs the member axis plus a surround test.** A raw edge test flags boards seated lengthwise in a wall top.
  An edge depth-ratio test misses a baluster through a rail, because its edges run 5 mm from the rail's sides. An axis
  test without the surround check flags a post whose axis runs through a bracket tenon inside it.
- **Ray-cast a shell from far below for its underside.** A cast that starts at the wall top begins inside an eave
  that drops below the wall and returns the top face.
- **Fit to the faceted LOW shell, not the analytic surface.** Chord error between rows sinks fitted boards
  several centimetres into the mesh.
- **Straight members under concave sweeps.** The chord of a rafter rises above a curved underside. Lower the member
  by the largest sag, so it touches at one point.
- **Split heights need de-duplication.** Float-near-equal z values (.1 mm apart) create zero-height slivers and
  coincident faces.
- **Drop collinear profile points.** Polygon fill makes zero-area triangles on flat stretches.

## Verification

- `scripts/blender_test_logic_qa.py` builds one minimal scene per defect class: each must be reported. One clean
  scene with designed joints must pass.
  Run: `blender -b --factory-startup --python blender_test_logic_qa.py`
  It is named `blender_test_*` so plain-Python discovery skips it: it needs `bpy`.
- **Historical negative control.** Re-run the checker on an older file that has a known, owner-reported defect.
  The defect must appear. Also inject a known-bad opening into every build and assert that it is reported.
- A clean report is necessary, not sufficient. Still do the agent visual check (Gate 2, step 6) and the owner
  review in the live session.
