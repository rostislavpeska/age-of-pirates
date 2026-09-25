# Asian building research: installed DE evidence, 2026-09-25

Start from the installed proto's `animfile`, then evaluate the intended culture
and technology branches. An identically named XML under another directory can
be an unused or different routing file. The inspected `TownCenter` proto uses
`buildings/town_center/town_center.xml`, not the similarly named XML under
`buildings/asian_civs/town_center/`.

In that file the Chinese/Japanese branches use `none`, `colonialize`, and
`industrialize` for the starting, middle, and late art. These correspond to
zero-based ages 0, 1-2, and 3-4; common geometry filenames say `age1`, `age2`,
and `age4`. Chinese starting TC already references the Japanese `age_1` model
family. Confirm each building's own routing rather than extrapolating this
mapping from its filename.

Starting-tech `Enable` targets are an inventory seed, not a complete proof of
villager buildability. Intersect with builder commands and later unlocks;
separate consulate, shipment, wagon, regicide and other conditional buildings.
Different wonder age-up proto records can use the same animfile and geometry.

## Ground decals as scale references

Before approving building scale, inspect the active component's `decal`: texture,
width, height, offset/rotation if present, and state/age routing. Load a decoded
preview outside the mod into Blender with preserved alpha. Size the ground plane
from the XML's world dimensions, accounting for the model's actual export scale
and axis mapping; image resolution does not determine world size. Align it to the
unit origin, not the mesh bounding-box center. Validate UV orientation against the
original donor foundations and, when available, a matched in-game view. Do not
silently resize a decal to fit a new model.

The installed `buildings/town_center/town_center.xml` has these shared Chinese and
Japanese completed-building references (2026-09-25):

| User art tier | Texture relative to `buildings/asian_civs/town_center/` | Width x height |
| --- | --- | --- |
| Age 0 | `asian_age1_ground` | 12 x 12 |
| Age 1-2 | `china/china_footprint` | 12 x 12 |
| Age 3-4 | `china/china_footprint_age04` | 12 x 12 |

Both cultures share these textures; there is no separate Japanese completed-TC
decal in these branches. Construction branches differ: some Japanese stages use
`castle_ground` at 11 x 11 and stage 3 uses `asian_age1_ground` at 10 x 10. Resolve
each active component rather than applying one completed-building size everywhere.
The extracted companion `_basecolor` maps provide 2048-square DE previews with
alpha; the unsuffixed legacy textures are 256-square. Preserve provenance for both.

For the Korean pilot, one Blender unit equals one raw export coordinate unit:
Blender XYZ = GR2 (X, -Z, Y). A quarter-turned planar UV, U=0.5+BlenderY/12 and
V=0.5-BlenderX/12, aligns the shared footprint's wood foundations with the donor's
L plan. This alignment was checked in Blender, not newly calibrated from an engine
capture. It is evidence for this pilot, not a universal decal UV orientation.

Use a slight ground-plane separation to avoid z-fighting, a 12 x 12 boundary and
unit ticks, and top/RTS views. Keep age alternatives mutually exclusive to avoid
stacked alpha darkening. Pack preview images into the research blend. Link the
authoring model into a separate decal-review scene; keep guide geometry out of
source/export collections and bake targets. An `export_exclude` custom property
is documentation, not automatic exporter behavior: export explicit model objects.
The decal includes feathered terrain and painted foundations; its rectangular
extent is distinct from model bounds and gameplay obstruction. Compare all three
without treating the decal rectangle as the exact collision footprint.

Exclude home-city scenes by use, not every path containing `homecity`: gameplay
Asian buildings reference accessory/fence textures stored there. Resolve those
texture dependencies and retain archive paths in runtime materials. Never copy
the vanilla maps into the mod to make a preview work.

The early Chinese Town Center's intact meshes total 5,819 vertices / 3,126
triangles, while its damaged pair has 272 GR2 bones, 221 HKT bodies and 181
geometry-bearing pieces. The late pair has 342 bones, 291 bodies and 219 pieces.
All inspected HKT names matched GR2 bones; a GR2 `base` geometry group did not
have a same-named HKT body. These counts came from offline inspection. The later
[Korean Town Center adaptation](../../havok-destruction/references/chinese-tc-experiment.md)
received user confirmation that destruction works in game on 2026-09-25. It
preserved the 221-body graph and refitted 145 hulls to new fractured geometry.
Preserve unexplained donor groups until their role is verified; success of this
prototype does not establish every donor or every damage-stage detail.

A later piece-geometry inspection of that early donor found 35 explicitly
roof-named pieces, all with HKT type 1 (on-death), while some type 0 stage
geometry also occupies the roof under generic object names. Select affected
pieces spatially as well as by name. A successful death-only roof-piece test
does not validate progressive damage; exercise both phases separately.

Use [havok-destruction](../../havok-destruction/SKILL.md) for piece/body matching.
Similar overall footprints do not prove equivalent collision hulls, rest
transforms, break groups or vertex bindings. Use the confirmed prototype as the
baseline for this donor, keeping its hashes and source checkpoints. For a new
donor, establish a control and a bounded adaptation before expanding to a whole set.

When a legacy mod supplies architectural references, keep its visual identity
separate from the current DE technical reference. Converted legacy FBX/GXO
rest meshes and textures can support silhouette review; they do not establish
DE material packing, destruction compatibility or export settings.

## Roof geometry and normal-map evidence

Read [the measured vanilla eave study](asian-roof-normal-evidence.md) when planning
Asian roof UVs or tile bakes. Circular tile ends in the sampled Chinese/Japanese
Town Centers are largely normal-map detail carried by continuous eave strips;
their appearance alone does not justify adding a cylinder for every roof tile.
