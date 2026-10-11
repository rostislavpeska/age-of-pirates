# Scene, naming and export conventions

One rule set for every Blender asset in this library, hard-surface or organic. Each rule has its check. Where a
consuming project has its own convention, follow the project and record it in the phase handoff; the defaults
below apply only when nothing else is agreed.

## 1. Units, axes and working scale (must)

- Record in the handoff: the working scale (metres or the engine's unit), the axis frame (which axis is up,
  forward and across, handedness) and the import/export route that maps it to the target engine.
- Model at a known working scale, never at a tiny imported scale. Example: a converter that imports a 2 m figure
  at less than a hundredth of a Blender unit breaks every absolute-distance tool - Merge by Distance, bevel width,
  Data Transfer maximum distance, BVH tolerances. Reverse the scale once, at export, by the recipe the consuming
  project proves for its route.
- Never apply scale or rotation to an imported armature that must match a game skeleton; keep the mesh and
  armature object transforms identical at bind time.
- Express every distance threshold in a script in working units and say so in the script output.

Check: the handoff names scale, frame and route; scripts print the unit of each threshold; an armature's object
matrix equals the imported one (compare `matrix_world` before and after the session).

## 2. Naming (should)

Honor the consuming project's naming convention first (the hard-surface skills already require this). When none
exists, use:

| Thing | Default name |
| --- | --- |
| Editable authoring source | `<ASSET>_AUTHOR` (quads, live modifiers where useful) |
| Low/game mesh | `<ASSET>_LOW[_<PART>]`, LODs `<ASSET>_LOW_LOD<n>` |
| Bake source | `<ASSET>_HIGH[_<PART>]` |
| Export duplicate | `<ASSET>_EXPORT[_LOD<n>]` |
| Scratch reference (overlay of a shipped asset, remesh proxy, probe) | prefix `REF_`; never exported, never shipped |
| Vertex groups of a skinned mesh | exactly the target bone names - same case, same separators |
| Files | `<asset>_<phase>_r<NN>.blend`; never overwrite a revision the owner accepted |

Never rename a bone to rely on an engine treating two spellings as equal; copy the target name exactly.

Check: no object prefixed `REF_` in the export file list; the set of weighted vertex-group names is a subset of the
target bone names (exact strings); the accepted revision file still hashes as recorded.

## 3. Authoring source versus export copy (must)

The authoring source stays editable; export happens from a duplicate. The hard-surface skills state the same rule
in their own words (`blender-architecture/SKILL.md` step 4, `blender-clean-uv/SKILL.md`,
`blender-overlap-cleanup/SKILL.md` step 4, `blender-high-low-baking/references/process.md` section 4), and a
consuming project's engine-export skills may repeat it. Forwarding those copies here is a planned move
([SKILL.md](../SKILL.md), "Planned moves"); until it happens, this section and those copies must say the same.

On the export copy, in this order:

1. apply the evaluated modifiers the target needs (mirror, armature binding kept as data, not applied);
2. triangulate explicitly with a fixed method and inspect the diagonals where the surface bends or is lit at a
   grazing angle; mirrored halves get mirrored triangulation;
3. keep only the UV, colour and attribute layers the target recipe uses, and preserve custom corner normals;
4. for a skinned mesh: vertex groups named exactly as the target bones, weights cleaned, limited and normalized
   (organic skill), the armature modifier pointing at the target armature;
5. record a hash of the triangle index list and of the UV layer.

The triangulation and UVs used for a bake must be the ones exported: any later change to topology, UVs or normals
invalidates the bake. Never edit the source to make an export pass.

Check: the export copy has 0 faces with more than 3 vertices; the triangle-list and UV hashes at bake time equal
those at export; the source still has its quads and modifiers.

Sources: Polycount wiki "Polygon Count" (a quad becomes a ridge or a valley depending on the diagonal; check the
triangulation in the engine): http://wiki.polycount.com/wiki/Polygon_Count. Polycount wiki "Texture Baking"
(triangulate before baking; mirrored models need mirrored triangulation): http://wiki.polycount.com/wiki/Texture_Baking.
Blender manual, Triangulate modifier: https://docs.blender.org/manual/en/latest/modeling/modifiers/generate/triangulate.html.

## 4. Counts (must)

- Report triangles after triangulation (`mesh.calc_loop_triangles()`, then `len(mesh.loop_triangles)`), never the
  face count.
- Report base and evaluated vertex counts, and a GPU-vertex estimate: distinct corner keys of (vertex index, UV,
  split normal, material, UV-triangle winding sign; add vertex colour or a second UV if exported). UV seams, hard
  edges, materials and skinning split vertices; the shipped buffer is larger than Blender's vertex count.
- Counts measured on the serialized file (FBX, game format) are separate evidence from Blender counts.
- Budget from welded counts of reference assets, never from a reference's shipped buffer size alone: some shipped
  files carry per-corner splits (for example from tangents) that a clean export would not.

Sources: `blender-architecture/references/construction.md` ("Counts"; the same rule for hard-surface work, a
planned forward to this package); Polycount "Polygon Count" (vertex count, not triangle count, is the GPU cost; UV
seams and hard edges split vertices): http://wiki.polycount.com/wiki/Polygon_Count.

## 5. Evidence levels (must)

Every claim in a handoff, report or skill says which kind of evidence it rests on:

| Level | Meaning |
| --- | --- |
| documented | a cited source states it (URL or a file path in a repository) |
| measured | a local measurement, with the method, tool, date and input files named so it can be repeated |
| inferred | follows from documented or measured facts but was not tested directly |
| unverified | reported or assumed; must not gate work |

Delivery has its own levels, recorded separately: machine-checked (scripts passed), delivered (visible to the owner:
pictures in chat or the live viewer's readback) and owner-accepted (his words, quoted, with the date). A file on
disk is none of these.

Check: each `qa` entry and each `open_issues` line in the handoff carries a level; an "accepted" status carries the
owner's quote.
