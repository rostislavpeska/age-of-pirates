# Sources

Every rule in this skill cites keys from this list, or says that it is a process rule or rests on the reference
measurement (see the last section). Access state is as of 2026-10-10 unless a row says otherwise. A key marked
*image* means the rule rests on what the picture shows, read by a person, not on page text.

## Blender manual (docs.blender.org, "latest" = the 5.x manual)

| Key | Page | Supports |
| --- | --- | --- |
| B1 | [Retopology](https://docs.blender.org/manual/en/latest/modeling/meshes/retopology.html) | no perfect automatic tools for deforming topology; remeshes do not give deformable topology |
| B2 | [Weight paint editing](https://docs.blender.org/manual/en/latest/sculpt_paint/weight_paint/editing.html) | Clean, Limit Total, Normalize All; Mirror needs a perfectly X-symmetric rest pose |
| B3 | [Data Transfer modifier](https://docs.blender.org/manual/en/latest/modeling/modifiers/modify/data_transfer.html) | vertex-group transfer; missing layers must be generated first |
| B4 | [Armature modifier](https://docs.blender.org/manual/en/latest/modeling/modifiers/deform/armature.html) | Preserve Volume uses quaternions; without it joint rotations scale down neighbouring geometry |
| B5 | [Armature parenting](https://docs.blender.org/manual/en/latest/animation/armatures/skinning/parenting.html) | automatic weights; parts may not deform as expected |
| B6 | [Bone naming](https://docs.blender.org/manual/en/latest/animation/armatures/bones/editing/naming.html) | left/right markers and separators Blender recognises |
| B7 | [Mirror modifier](https://docs.blender.org/manual/en/latest/modeling/modifiers/generate/mirror.html) | Clipping, Merge, vertex-group mirroring for L/R names |
| B8 | [Symmetrize](https://docs.blender.org/manual/en/latest/modeling/meshes/editing/mesh/symmetrize.html) | cut at the origin, mirror, merge |
| B9 | [Triangulate modifier](https://docs.blender.org/manual/en/latest/modeling/modifiers/generate/triangulate.html) | Beauty, Fixed, Fixed Alternate, Shortest/Longest Diagonal |
| B10 | [Mesh structure](https://docs.blender.org/manual/en/latest/modeling/meshes/structure.html) | quads deform well; edge loops stop at poles |
| B11 | [Skin modifier](https://docs.blender.org/manual/en/latest/modeling/modifiers/generate/skin.html) | per-vertex radius, Mark Root; branch areas give complicated, possibly overlapping topology |
| B12 | [Snapping](https://docs.blender.org/manual/en/latest/editors/3dview/controls/snapping.html) | Face Project / Face Nearest for retopology |
| B13 | [Decimate modifier](https://docs.blender.org/manual/en/latest/modeling/modifiers/generate/decimate.html) | not meant for carefully, economically modelled meshes; Un-Subdivide |
| B14 | [Shrinkwrap modifier](https://docs.blender.org/manual/en/latest/modeling/modifiers/deform/shrinkwrap.html) | Project with limit, Target Normal Project, offsets |
| B15 | [Solidify modifier](https://docs.blender.org/manual/en/latest/modeling/modifiers/generate/solidify.html) | thickness in local units (apply scale); Simple fails on edges with more than 2 faces |
| B16 | [Curve geometry](https://docs.blender.org/manual/en/latest/modeling/curves/properties/geometry.html) and [shape](https://docs.blender.org/manual/en/latest/modeling/curves/properties/shape.html) | bevel depth/resolution, bevel object, tilt, resolution |
| B17 | [Proportional editing](https://docs.blender.org/manual/en/latest/editors/3dview/controls/proportional_editing.html) | connected-only falloff |
| B18 | [Workbench lighting](https://docs.blender.org/manual/en/latest/render/workbench/lighting.html) and [colour](https://docs.blender.org/manual/en/latest/render/workbench/color.html) | Flat lighting, Single colour for silhouettes |
| B19 | [Weight paint symmetry](https://docs.blender.org/manual/en/latest/sculpt_paint/weight_paint/tool_settings/symmetry.html) | X-mirror painting, topology mirror |
| B20 | [Bone deform properties](https://docs.blender.org/manual/en/latest/animation/armatures/bones/properties/deform.html) | Deform off: the bone deforms nothing, overriding its weights, and is left out of Armature Deform With Automatic Weights (read 2026-10-11) |

## Blender API and source

| Key | Page | Supports |
| --- | --- | --- |
| A1 | [bpy.ops.object](https://docs.blender.org/api/current/bpy.ops.object.html) | `vertex_group_limit_total(group_select_mode='', limit=4)`, `vertex_group_normalize_all(group_select_mode='', lock_active=True)`, `vertex_group_clean(group_select_mode='', limit=0.0, keep_single=False)`, `data_transfer`, `datalayout_transfer`, `skin_armature_create`; `quadriflow_remesh`: "All data layers will be lost" |
| A2 | [Gotchas: meshes](https://docs.blender.org/api/current/info_gotchas_meshes.html) | Edit-Mode data reaches the mesh only on leaving Edit Mode; `loop_triangles` for exporters |
| A3 | [Gotchas: armatures and bones](https://docs.blender.org/api/current/info_gotchas_armatures_and_bones.html) | edit bones exist only in Edit Mode; stale references can crash |
| A4 | [mathutils.bvhtree](https://docs.blender.org/api/current/mathutils.bvhtree.html) | `overlap`, `ray_cast`, `find_nearest` |
| A5 | [bmesh.types](https://docs.blender.org/api/current/bmesh.types.html) | `is_manifold`, `is_boundary`, `is_contiguous`, `is_wire` |
| A6 | [bpy.types.Mesh](https://docs.blender.org/api/current/bpy.types.Mesh.html) | `validate`, `corner_normals`, `calc_loop_triangles` |
| A7 | [Blender 4.1 modeling release notes](https://developer.blender.org/docs/release_notes/4.1/modeling/) | `Mesh.use_auto_smooth` removed |
| A8 | [string_utils.cc](https://projects.blender.org/blender/blender/src/branch/main/source/blender/blenlib/intern/string_utils.cc) | `BLI_string_flip_side_name`: L/R only at the start or end of a name, or after the last separator |
| A9 | [MOD_skin.cc](https://projects.blender.org/blender/blender/src/branch/main/source/blender/modifiers/intern/MOD_skin.cc) | edge subdivisions = floor(length / (2 x mean radius)) + 1, capped at 128 |
| A10 | [object_remesh.cc](https://projects.blender.org/blender/blender/src/branch/main/source/blender/editors/object/object_remesh.cc) | QuadriFlow input checks; a rejection is only a WARNING report |

## Polycount wiki (practitioner reference)

The wiki refused some connections on 2026-10-10; the keys below were read on that date or through the images
they host.

| Key | Page | Supports |
| --- | --- | --- |
| PC1 | [Limb Topology](http://wiki.polycount.com/wiki/Limb_Topology), Ben Mathis sheet [image](http://wiki.polycount.com/w/images/d/d1/BenMathis_limb_deformations.gif) | two full rings keep volume; 3-into-2 is the best low-poly layout; 2-into-1 at 50/50 collapses; weights 100 / 50 / 100 |
| PC2 | [Shoulder Topology](http://wiki.polycount.com/wiki/ShoulderTopology), Ben Mathis [image](http://wiki.polycount.com/w/images/c/c3/BenMathis_shoulder_deform.jpg), Pior Oberson [image](http://wiki.polycount.com/w/images/7/79/PiorOberson_shoulder-compare.jpg) | low polycount shoulder tends to a deformed cylinder; anatomy versus easy weighting |
| PC3 | [Topology](http://wiki.polycount.com/wiki/Topology) | every edge there for a reason; spend on silhouette and curvature; poles in flat, non-deforming areas; avoid T-vertices, doubled, flipped, hidden and floating geometry |
| PC4 | [Polygon Count](http://wiki.polycount.com/wiki/Polygon_Count) | GPUs see triangles; ridge or valley per diagonal; vertex count is the cost; seams and hard edges split vertices |
| PC5 | [Normal map](http://wiki.polycount.com/wiki/Normal_map) | split UVs at every hard edge for tangent-space maps; triangulate before mirroring |
| PC6 | [Texture Baking](http://wiki.polycount.com/wiki/Texture_Baking) | triangulate before baking; mirrored triangulation; cages; no UV change after a bake |
| PC7 | [Character Modeling](http://wiki.polycount.com/wiki/Character_Modeling) | low-res model box-modelled or retopologized |
| PC8 | [ReTopologyModeling](http://wiki.polycount.com/wiki/ReTopologyModeling), [BaseMesh](http://wiki.polycount.com/wiki/BaseMesh) | retopology and base meshes as standard starts |
| PC9 | Rob Santa joint sheet [image](http://wiki.polycount.com/w/images/4/42/RobSanta_joint_modeling_for_deformation.jpg) | 6 rotational segments, 56 / 64 triangles: wedge versus extra ring |
| PC10 | Jeong Seong Hwa joint sheets: [joints](http://wiki.polycount.com/w/images/5/50/JeongSeongHwa_swordmaster_joints.gif), [compression](http://wiki.polycount.com/w/images/b/b6/JeongSeongHwa_swordmaster_leg_compress.gif), [types](http://wiki.polycount.com/w/images/e/e3/JeongSeongHwa_swordmaster_leg_types.gif) | crease-side diamond at the back of the knee and inner elbow |

## Engine and vendor documentation

| Key | Page | Supports |
| --- | --- | --- |
| E1 | [Unity: Modeling characters for optimal performance](https://docs.unity3d.com/Manual/ModelingOptimizedCharacters.html) | one skinned mesh per character, few materials, linear blend skinning with at most four influences, fewer bones |
| E2 | [Unity 5.3: Preparing a character from scratch](https://docs.unity3d.com/530/Documentation/Manual/Preparingacharacterfromscratch.html) | cap holes, weld vertices, remove hidden faces; test skinning early |
| E3 | [Unity ModelImporter.maxBonesPerVertex](https://docs.unity3d.com/ScriptReference/ModelImporter-maxBonesPerVertex.html) | default influence limit 4 |
| E4 | [Unreal: skeletal mesh rendering paths](https://dev.epicgames.com/documentation/en-us/unreal-engine/skeletal-mesh-rendering-paths-in-unreal-engine) | 4/8 influences, "unlimited" path capped at 12; per-section bone limits |
| E5 | [Source SDK 2013 studio.h](https://raw.githubusercontent.com/ValveSoftware/source-sdk-2013/master/src/public/studio.h) | 3 bones per vertex, 128 bones |
| E6 | [LSLib Granny Vertex.cs](https://raw.githubusercontent.com/Norbyte/lslib/master/LSLib/Granny/Model/Vertex.cs) | 4 influence slots; bone weights normalized uint8; weight 0 = empty slot; unused index slots take the first bone |
| E7 | [RAD Granny SDK](https://www.radgametools.com/granny/sdk.html) | the exporter clips and normalizes weights |
| E8 | [UDK Skeletal Mesh Simplification Tool](https://docs.unrealengine.com/udk/Three/SkeletalMeshSimplificationTool.html) | LOD reduction keeps silhouette first |
| E9 | [Microsoft: block compression](https://learn.microsoft.com/en-us/windows/win32/direct3d10/d3d10-graphics-programming-guide-resources-block-compression) | BC1 4x4 blocks with two endpoint colours |
| E10 | [Marmoset Toolbag baking tutorial](https://marmoset.co/posts/toolbag-baking-tutorial/) | bake with the renderer's tangent space on the final triangulation |

## Papers, talks and artists' breakdowns

| Key | Source | Supports |
| --- | --- | --- |
| R1 | Kavan et al. 2007, [Skinning with dual quaternions](https://users.cs.utah.edu/~ladislav/kavan07skinning/kavan07skinning.pdf) | linear-blend candy-wrapper and volume loss (Fig. 2) |
| R2 | Kavan et al. 2008, [Geometric skinning with approximate dual quaternion blending](https://doi.org/10.1145/1409625.1409627) | a 0.5/0.5 vertex collapses when one joint twists 180 deg |
| R3 | Abdrashitov, Raichstat, Monsen, Hill 2023, [Robust skin weights transfer via weight inpainting](https://doi.org/10.1145/3610543.3626180) ([project](https://www.dgp.toronto.edu/~rinat/projects/RobustSkinWeightsTransfer)) | body-to-garment weight transfer for loose clothes |
| R4 | Dionne and de Lasa 2013, [Geodesic voxel binding](https://doi.org/10.1145/2485895.2485919) | weights on production meshes with gaps and intersections |
| R5 | Mitchell, Francke, Eng, [Illustrative rendering in Team Fortress 2](https://www.cs.princeton.edu/courses/archive/fall07/cos597B/papers/mitchell-team-fortress.pdf) and [NPAR 2007 slides](https://cdn.fastly.steamstatic.com/apps/valve/2007/NPAR07_IllustrativeRenderingInTeamFortress2_Slides.pdf) | silhouette-first class reads; high-frequency detail omitted; read hierarchy and value gradient |
| R6 | Riot Games, [Clarity in League](https://www.leagueoflegends.com/en-us/news/dev/clarity-in-league/) | silhouettes are the most important thing for recognition; facing readable from the silhouette |
| R7 | Valve Dota 2 character art guide, summary at [CG Channel](https://www.cgchannel.com/2012/06/valve-releases-useful-character-design-guide); [Steam help](https://help.steampowered.com/faqs/view/0688-7692-4D5A-1935) | silhouette, value patterning, palette, judging assets in context at a high camera |
| R8 | [80.lv: Creating awesome characters for video games](https://80.lv/articles/creating-awesome-characters-for-video-games/) (Total War artists) | blockout, approved sculpt, low poly, bake; seams and reuse planned during the sculpt; large areas of contrast for distance |
| R9 | [Eurogamer interview with Samwise Didier](https://www.blizzplanet.com/blog/comments/eurogamer_interviews_samwise_didier) | bigger shapes instead of small detail for a top-down camera |
| R10 | [Game Informer: Warcraft III concept art](https://gameinformer.com/2018/11/14/explore-warcraft-iiis-origins-in-this-rare-concept-art-gallery) | units made bigger and bulkier to read from the top-down camera |
| R11 | [MobileSyrup: Relic developer interview](https://mobilesyrup.com/2021/04/10/age-of-empires-iv-relic-developer-interview/) | less detail on small RTS units for readability |
| R12 | [tech-artists.org: feedback on edgeflow before rigging](https://www.tech-artists.org/t/feedback-on-edgeflow-before-i-jump-in-to-rigging/10511) | poles in the armpit, not the crook of the elbow; even loop spacing |
| R13 | [Blender Artists: "The unsittable character"](https://blenderartists.org/t/the-unsittable-charater/378542) (2006) | sitting poses need extra hip/groin loops and hip weight on the top-rear thigh (old, overstated: rated may) |
| R14 | [Tuts+: low-poly ninja character in Blender](https://design.tutsplus.com/tutorials/creating-a-low-poly-ninja-game-character-using-blender-part-1--cg-16132) | about 1,200 triangles, fingers painted, not modelled |
| R15 | [Blender Studio: animation testing](https://studio.blender.org/tools/artist-guide/asset-creation/animation-testing); [Roblox: testing characters](https://create.roblox.com/docs/en-us/art/characters/testing) | test a rig through real animations, not the rest pose |
| R16 | [Wikipedia: Body proportions](https://en.wikipedia.org/wiki/Body_proportions) | head-count canons are realistic figure-drawing norms |
| R17 | [Rosenborg: Christian V's riding costume](https://kongernessamling.dk/en/rosenborg/object/christian-v-s-riding-costume) | riding coats slit to fall either side of the saddle |

## Local probes (measured)

Background Blender 5.1.2 (`blender -b --factory-startup`) on synthetic test bodies, 2026-10-10 (L16: 2026-10-11).
The original raw outputs are not stored in the library; `scripts/organic_probe.py` regenerates them (verified equal
on Blender 5.1.2, 2026-10-11, all 26 result keys; see [scripts/README.md](../scripts/README.md), which lists the
experiment behind each key). Each rule that cites a probe also gives a check that reproduces it.

| Key | Measurement |
| --- | --- |
| L1 | `bpy.utils.flip_name` leaves `Bip01_L_Thigh`, `Bip01 L Thigh`, `Bip01_R_Calf`, `Bip01_L_UpperArm` unchanged; flips `L_Thigh`, `Thigh_L`, `Thigh.L` |
| L2 | automatic weights: up to 5 influences (38-47 vertices over 4), weight sums off by up to 0.089; the Armature modifier normalizes at evaluation, so the viewport hides it (a vertex at 0.5 to one bone followed it fully); the same numbers and 0 unweighted vertices at scale 1, at scale 0.008 (applied), after a x100 scale-up and with a loose part |
| L3 | Limit Total without a following Normalize All left sums off by up to 0.42; Normalize All fixed them (0.0) |
| L4 | Data Transfer of weights onto a shell: up to 6 influences per vertex; shell-body intersecting triangle pairs 20 -> 77 after a 35 deg spine bend; at gap 0 the shell intersects at rest (7-11 pairs), at 1 cm gap 0; shell limited to the body's 4 influences: 0 / 14 overlaps at 30 / 60 deg bend; limited to 2: 21 / 31; rigid: 16 / 87 |
| L5 | a 182-vertex / 360-triangle body: Smart UV Project at 66 deg gave 393 GPU vertices with smooth shading and 598 with flat shading |
| L6 | QuadriFlow: 16 vertex groups and 1 UV map became 0 and 0; `target_faces=600` gave 470 quads |
| L7 | Subdivision then Decimate Collapse 0.5: minimum triangle angle 16.2 -> 6.6 deg; Un-Subdivide x2 recovered 186 / 191 against 182 / 183; Decimate kept all 16 vertex groups |
| L8 | operator defaults: `uv.unwrap` method CONFORMAL; `vertex_group_*` `group_select_mode=''`; `normalize_all` `lock_active=True`; `clean` `limit=0.0`, `keep_single=False` (also A1) |
| L9 | Mirror (clip, merge) then Skin on a joint graph: 166 vertices / 328 triangles, manifold, no UV layer; ring counts follow A9 |
| L10 | Workbench silhouette render in `-b`: first frame 2.9 s, later frames 0.01 s; Render Result pixels cannot be read directly, a saved and reloaded PNG can |
| L11 | 3 rings instead of 1 at a joint under automatic weights: same elbow compression (radius ratio 0.76 at 100 deg) and more knee self-intersections (21 against 0) |
| L12 | a fully flipped closed shell keeps contiguous winding; its signed volume changes sign (+0.05266 -> -0.05266) |
| L13 | headless connected-only proportional translate works (25 vertices moved) |
| L14 | Shrinkwrap Nearest Surface, Project and Target Normal Project gave identical numbers on an 8-sided limb (3.3 mm is the 8-gon chord error): the probe does not discriminate between them |
| L15 | linear-blend synthetic joints: radius ratio 0.76 / 0.75 at 100 deg; 9-19 self-intersections at 130 deg |
| L16 | `group_select_mode='BONE_DEFORM'` exists only on a mesh bound to an armature: on an unbound mesh `vertex_group_normalize_all` raised `TypeError: enum "BONE_DEFORM" not found in ('ALL')`; once an Armature modifier was added it finished; Limit Total raised the same error on the unbound mesh; Clean, Limit Total and Normalize All finished after an Armature modifier and after parenting with empty groups (probe experiment `bone_deform_enum`) |

## Process rules and reference measurements

- **Process rule of this skill**: an ordering or workflow rule (agree before modelling, test before dependent work,
  approve before detail). It rests on no external source; its check is the evidence that it was followed. It may be
  changed by the owner without new research.
- **Reference measurement**: a count, share or angle taken from the reference asset by the consuming game layer
  (evidence level "measured", [conventions](../../blender-asset-conventions/references/scene-and-export.md)
  section 5). This package never stores those numbers; the rule says which measurement it compares against.
