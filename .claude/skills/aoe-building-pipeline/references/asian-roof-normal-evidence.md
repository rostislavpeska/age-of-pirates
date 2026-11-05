# Vanilla Town Center roof/eave study

Inspected from the installed game on 2026-09-25. This is measured mesh/texture
evidence, not a claim about the original artists' high-poly sources or tools.
Decoded maps and reference meshes stay outside the mod; retain archive paths for
any runtime reuse. The Korean pilot will author custom textures separately.

## Sources and exact sampled geometry

Primary mesh indices are zero-based as returned by the repository GR2 reader.
Face IDs below are triangle indices in those primary meshes, not Blender object
names or stable identifiers for every future game version.

| Source under `art/buildings/asian_civs/town_center/` | Primary mesh | Sample eave triangles | Raw V band, approximately |
| --- | --- | --- | --- |
| `china/age_2/china_towncenter_age2.gr2` | 0 | 1034, 1035 | 0.3008-0.3169, about 33 texels at 2048 |
| `japan/age_4/japan_towncenter_age4.gr2` | 1 | 488, 489 | 0.7402-0.7495, about 17-19 texels at 2048 |

Each sampled section is a continuous quad represented by two long triangles.
There are no individual circle meshes in these sampled strips. Along a central
cross-section the Chinese strip drops about 0.214 raw model units while moving
outward about 0.11; the Japanese example drops about 0.136 while moving outward
about 0.066. Both turn more steeply than the adjoining roof field. These are raw
model coordinates, not a claim of real-world meters.

The `mata` basecolor and normal atlases are 2048-square. The corresponding
`textures/<model>_mata_normals.ddt` carries broad cover-tile rolls, finer course
seams, and a distinct circular/scalloped end band. The band's UVs coincide with
the low mesh's change of slope. Some atlas roof patches run in the opposite
direction; their different normal colors are not by themselves a shading fault.

Normal-disabled wireframe renders show continuous smooth faces. Grey normal-only
renders recover the rolls and round endings without using basecolor or an AO map.
Basecolor adds material and painted shading, so basecolor-only is a separate
control rather than an unlit geometry test. Both green-axis variants were rendered
in Blender. The destination engine's sign/tangent behavior was not tested here.

After operator feedback, sampled the decoded BaseColor alpha on those exact
triangles: all 34,748 Chinese and 6,136 Japanese sampled texels were 255. Both
materials use `materialdef name="default"`; these BaseColor DDT headers are
RTS3 `(0,0,4,10)`. A few transparent texels elsewhere in the decoded atlases are
not evidence of a cutout eave, especially without verifying the DDT/shader alpha
interpretation. Do not describe every vanilla Asian roof as using alpha clipping
based only on a transparent atlas preview. A deliberate custom cutout is a separate
authoring decision and needs shader, backing-geometry and mip validation.

## Consequences for Korean authoring

Plan a coordinated curved roof field, short eave turn, end band and underside.
Assign UVs so cover-tile centers arrive at the centers of round endings. Keep the
large curve and silhouette in LOW and bake the tile construction from HIGH.
Retain individual tile geometry only where its silhouette is useful at the target
view. An ordinary repeating roof texture can cover a field; the fitted transition,
hip terminations and end treatment are the reasons for a custom bake.

The approved Korean solid v13 used separate eight-sided cap cylinders
along the long eaves at the rafter sampling pitch. The earlier generic tile-field
test used a different pitch. Applying those two independently would misalign tile
rows and ends. Resolve that construction before propagating a whole-roof bake;
do not silently label the plane specimen a complete Korean roof solution.

For the general procedure use the canonical
[high/low baking skill](../../blender-high-low-baking/SKILL.md). Save primary mesh,
UV and decoded-map provenance with external project evidence. This study changed
no Korean source geometry, runtime materials or game files.

## Accepted Korean roof checkpoint

The user accepted the subsequent v15 Blender checkpoint on 2026-09-25. Four roof
bakes replaced 78 individual cap cylinders with coordinated cover rows and end
faces. Final end faces meet their rows directly; an earlier separate neck and low
ring arrangement was rejected. Vertical front bands use a separate hard-normal/UV
boundary, and an inset underside avoids coplanar shell faces. Matching opacity on
the outer and backing lip provides the custom cutout; this is not a claim that
the sampled stock eave bands used alpha clipping.

Hip/gable caps remain geometry with seated undersides. The rear/right hall is
0.28 scene units higher, with walls/posts extended above the fixed floor. The roof,
trims and bake sources moved together. These dimensions are this approved model's
decision, not a universal Korean architecture rule.

Final authoring counts: 39 low meshes, 7,208 evaluated vertices, 11,996 triangles
and an estimated 21,750 corner splits before final nonroof UVs. High sources and
receivers are excluded. The four 1024-square bakes were assembled without
resampling into one 2048-square atlas per map; AO stays separate. This unique atlas
is a prototype, not an approved memory budget for the whole civilization.

Verified in Blender: opposing-light eave pilot; front/rear/left/right/top, roof
junction, tower and low views; no boundary/nonmanifold edges, loose geometry or
degenerate triangles in the candidate components; all static-root weights restored
after mesh replacement. Original v13 authoring meshes remain in their own scene.
External project evidence includes `Review_v15.md`, `geometry_audit_v15.json`,
`atlas_validation_v15.json`, `hall_height_step.json` and `final_state_v15.json`.
Unique albedo/nonroof UVs, serialized GR2 counts, destination alpha/tangents/mips
and the revised destruction model were not validated by this checkpoint.

## Town Center flag mounts

Inspected the same installed Chinese age-2 intact GR2 and
`china/age_2/china_towncenter_age2_damaged.gr2` on 2026-09-25. Bone positions below
are intact model-space values converted from engine Y-up into the study's Blender
Z-up frame, `(X, -Z, Y)`; they are evidence, not a universal exporter axis recipe.

| Exact intact name | Blender position, approximately | Intact parent | Damaged parent |
| --- | --- | --- | --- |
| `bone_flag_civ` | (-2.21893, 2.11267, 12.05978) | `BONE_MAIN` | `animtrans01` |
| `BONE_GARRISONFLAG` | (-2.21893, 2.11267, 10.95377) | `BONE_MAIN` | `animtrans02` |
| `BONE_HITPOINTBAR` | (2.32843, 0.39333, 11.69929) | `BONE_MAIN` | `BONE_MAIN` |

The donor has one physical mast at the flag XY, reaching approximately Z=13.43858.
The two flag origins are 1.10601 apart vertically; the civ origin is 1.37880 below
the mast top. Do not assume an attachment origin belongs at the tip or require two
masts based on a ship-specific example. Preserve donor axes and exact names, then
position the mounts deliberately on the new architecture. Keep unweighted
attachment bones when exporting; a deform-only filter can otherwise drop them.

The animfile defines a banner role, but this inspected intact skeleton has no
third banner bone. A declaration alone does not prove a physical attachment.
Carry the damaged model's animated parenting forward during destruction work;
an intact Blender rig does not certify GR2 attachment or animation behavior.
