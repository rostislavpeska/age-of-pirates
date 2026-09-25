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
