# Chinese Town Center: confirmed Korean destruction adaptation

Inspected 2026-09-25: `buildings/asian_civs/town_center/china/age_2/`
`china_towncenter_age2_damaged.gr2` and `.hkt`. On 2026-09-25, after the exported
prototype was installed and the game launched, the user reported: **"Great,
destruction works"**. Record this as user-confirmed in-game destruction for this
prototype, separate from the offline measurements below. No per-stage capture or
separate collision-quality assessment accompanied that report; do not invent one.

This establishes a working donor-adaptation method: new building geometry and
new collision hulls can use the retained Chinese Town Center destruction graph.
It does not establish arbitrary HKT graph generation or compatibility with every donor.

## Confirmed artifact identity

Prototype: `zpKoreanTownCenterTest` (21207), runtime assets under
`art/buildings/korean_tc_experiment/`. Prepared comparison: Chinese age-2 control
`zpChineseTownCenterControl` (21208), map `000_korean_destruction`.

| File | SHA-256 |
| --- | --- |
| `korean_tc_pilot.gr2` | `55c3b8577656ecf52b9e64406d2bc8c6954af121a13d13f3e0c8d516b7243252` |
| `korean_tc_pilot_damaged.gr2` | `1594cd861a67cb1fba26e2d23a3685c2883179e76f0f112848122cad2fbaba2b` |
| `korean_tc_pilot_damaged.hkt` | `78fd1384db82279b279d05b2bff1f991e0611960a7fc259ed29d823be745ca22` |

Editable scene: `Korean_Town_Center_Destruction_v07.blend`. The external
`Korean_Civilization_Research/Experiment_01` research folder preserves geometry
JSON, audits, `runtime_verification.json` and the experiment scripts in `Scripts/`.
Its `original_locations.json` records the original session paths. These scripts
retain checkpoint/path assumptions; they are evidence and a reproduction starting
point, not a parameterized exporter bundled with this skill. Inspect them before
replay, and never rerun their one-time deployment against an existing destination.

## What the file contains

The HKT is a Havok `20180200` TAG0 container whose root variant is `Physics Data`
(`hkpPhysicsData`). Its active `Default Physics System` contains 221 rigid
bodies, zero constraints, zero actions and zero phantoms. No `hkd` types were
present. Do not equate a Havok 2018 tagfile with a new `hknp` physics system or
assume that this building uses a standard Havok Destruction fracture graph.
The four custom integer properties described in the parent skill supply the
AoE-specific grouping information; they are not standard constraint objects.

Top-level body shapes: 207 convex-vertex shapes, 13 cylinders and one list shape
with 16 children. Bodies include 13 type-6 base proxies, 28 type-7 group proxies,
163 type-1 on-death pieces and 17 type-0 stage pieces. Simulation properties:
one base, 79 keyframed and 141 dynamic. The GR2 has 272 bones and 181 geometry
groups. `base` geometry has no same-named HKT body. Counts are intentionally
different; preserve named parent links and distinguish visible pieces from proxies.

## Coordinate frames

For this exact donor, measured collision clouds agree with render clouds using:

```
HKT world = 1.024 * (GR2 world.z, GR2 world.y, GR2 world.x)
```

After this mapping, the mean per-piece fraction of render vertices inside its
corresponding convex hull within 0.05 HKT units was 0.999718; the median was 1.0.
Without it, the mean was 0.041121. These hulls are approximations, so a small
residual does not itself indicate corruption. Recalibrate for other donors.

The stored HKT transform has three basis columns in padded groups of four,
followed by translation at indices 12..14. Ignore padding lanes: they can
contain nonzero values. In row-vector NumPy notation, with
`R = transform.reshape(4,4)[:3,:3]`, use `world = local @ R + translation`.
Conversely, `local = (world - translation) @ R.T` for the orthonormal donor basis.

Do not equate a GR2 bone's parent-relative translation with an HKT body's world
translation, especially for nested proxy bones. Use the full hierarchy or its
inverse-world matrix. GR2 BoneBinding OBBMin/OBBMax are **bone-local**:
`local = homogeneous_model_vertices @ inverse_world.reshape(4,4)` for the
stored row-vector convention. HKT center of mass is also distinct from the
body/bone pivot; shape edits can require updating swept COM and inertia while
retaining the pivot and orientation used by the engine's binding.

## Working recipe and validation

The approved blockout was closed and partitioned into 429 closed fragments,
grouped onto 146 donor bone names (145 HKT bodies plus fixed base geometry).
Eleven geometry-bearing names were stage pieces. Every source part's summed
fragment volume was checked against its intact volume; cuts received closed caps.
This is a diagnostic fracture layout, not a final art or construction pattern.

The fracture seeds were the donor geometry pieces' bounding-box centers, filtered
to bodies with convex-vertex shapes. Closed Voronoi cuts partitioned the approved
source parts; all fragments assigned to one donor name shared that bone and one
conservative collision hull. Preserve per-piece rigid indices on every triangle.
The intact and damaged assemblies must coincide before any piece moves.

The adapted HKT retains all 221 bodies, their order, names, custom properties,
motion types, parent graph, rest pivots and the complete TYPE section. It replaces
145 convex hulls and updates their bounds, swept COM and conservative box inertia.
Donor masses are retained for the trial. The serializer must reconstruct the
unchanged input byte-for-byte before being used to alter DATA/ITEM records.

The normal model has 444 triangles; its damaged counterpart has 9,288. Raw GR2
editing retained the donor skeleton and packed vertex layout. Intact vertex/index
buffers stayed in sections 1/2, damaged buffers in 3/4; newly appended mixed-format
vertices received marshalling records. Bone-binding bounds were measured in each
bone's local frame. Native Granny loading and read-only GXO dumps passed before
the user tested in game. See [GR2 editing](../../gr2-granny-edit/SKILL.md) for the
serialization failure and inspection ladder.

The accepted damaged export retained three unbound donor mesh records but bound
only the new Korean mesh to the model. Account for those records when inspecting
counts/material dependencies; do not mistake them for visible duplicates or
remove them without another native load check. The damaged material uses
`destructible`; the normal model uses `default`. Animation XML preserves the
donor's Destruction p1/p99 switch, Death component and damaged simskeleton.

Known remaining limitations: base/group proxy envelopes retain donor geometry;
unused bodies can still simulate invisible debris; convex hulls may bridge
separate fragments bound to one body; mass tuning is pending. Offline tagfile
parsing and convex-plane containment do **not** prove the game's Havok runtime
will accept a later revision or trigger progressive breaks correctly. The user's
successful runtime result applies to the identified prototype; these quality and
coverage limits remain relevant when extending or optimizing it.

The small local `hull3d` implementation failed containment on one of these
fragment clouds. Validate all input points against emitted planes; do not trust
successful serialization. The trial instead used already-installed SciPy
`ConvexHull`, followed by the same containment check. This does not establish
that every other use of the small hull helper is broken.

For subsequent runtime verification, compare an unchanged Chinese donor and the prototype
under the same ownership, damage and timing. Test intact placement, first damage
transition, several intermediate HP levels and final collapse separately. Inspect
remaining geometry, piece pivots, seams, contact with terrain and flying/offset
debris. A Blender exploded view is a binding preview, not a Havok simulation.

## Resources

Use the owner's local Havok 2018.1 Content Tools manual, without copying it into
the repository: Physics 2012 Create Rigid Bodies (PDF pp. 168-174), custom
`hkProperties` (p. 174), convex shrinking (pp. 178-180), and mass/center-of-mass
authoring (pp. 307-310). Distinguish integer runtime properties from the separate
node user-property string described around pp. 2255-2257. The manual explains
Havok mechanics; meanings of the four AoE property IDs are project measurements.

[Soulstruct Havok](https://github.com/Grimrukh/soulstruct-havok) provides an
independent parser research resource, not proven AoE tooling. The official
[Space Engineers collision guide](https://www.spaceengineersgame.com/modding-guides/moddable-collision-models/)
illustrates an older Content Tools export pipeline; its version and game-specific
rules must not be substituted for the installed AoE donor's formats.
