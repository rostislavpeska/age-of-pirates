# Extending an accepted building set

Use when an accepted building establishes the look of a civilization, age or
architectural set and subsequent buildings must share its materials. Resolve this
contract before sourcing or tinting the next member; reuse it at every handoff.

## Reference and inheritance

Pin the exact accepted reference revision, mesh/UV identity, final maps and hashes,
editable source/recipe, shader bindings, color spaces and review settings. A raw
photograph, an early bake or a similarly named file is not the finished reference.
If source history is incomplete, use the accepted output as the comparison target
and label reconstruction explicitly; do not silently substitute a reconstructed look.

Maintain one versioned **set material manifest**, separate from per-building UVs:

| Record | Content |
| --- | --- |
| Set scope | Civilization/style, age, accepted reference and evidence of acceptance |
| Material role | Roof field, clay caps/eaves, structural timber, lattice, plaster, stone, infill, painted trim |
| Inherited controls | Source revision, tint transform and color space, roughness/metallic, normal strength/convention, alpha mode, variation and weathering palette/ranges |
| Model-specific inputs | Geometry/UVs, direction and physical scale, tile IDs, spatial weathering masks, assembly AO, player-color placement |
| Dependencies | Shared atlas/material references versus the member's own pages and runtime budget |
| Evidence | Comparable material samples, fixed scene settings, paired review views and outstanding differences |

For a role required to have the **same tint**, inherit the exact color-transform
controls; do not pick another approximately matching hex value. Keep normalization
constants/calibration anchored to the reference. Recomputing normalization from
each building's histogram can change the apparent material even with equal inputs.
Variation may change spatially within the established material range. An age or
role-specific palette change must be an explicit art decision recorded in the manifest.

Reuse shared resources directly where appropriate. Separate UV layouts can use the
same source/recipe without additional runtime pages. Never repaint the accepted
reference to hide a mismatch in a new member, or inflate material counts to match it.

Define player-colour roles before conjoining UVs: repeated wall bands and secondary
trim, their weight, and explicit role-specific exceptions. Equivalent roles must
be accounted for on every facade, including end walls and open structures. Verify
coverage completeness separately from shared-texel leakage with the player-colour
workflow; naming-based face selections alone cannot establish either property.

## Validate the material, then the building

1. **Identity check:** report inherited parameter/source equality and any declared
   difference. Fail a set-match claim when a required role or reference is missing.
2. **Controlled material comparison:** use like-for-like clean clay, worn clay,
   moss, wood or stone samples at equal physical scale. Compare unlit BaseColor
   and standardized shader swatches with identical normals, light, exposure and
   view transform. Show matched crops and numeric color/value differences.
3. **Geometry comparison:** show the reference and member together in a common
   scene, including game-scale views. Diagnose BaseColor, roughness/specular,
   normals, AO and lighting separately when one looks lighter. Differently angled
   surfaces naturally receive different light; identical rendered pixels across
   unlike geometry are not the criterion for identical tint.
4. **Scoped correction and delivery:** use the immutable current parent and an
   explicit material mask. Preserve unrelated pixels, relief, alpha/cutouts, UVs
   and budget. Show before/reference/after; verify saved, live and exported bindings
   at their respective handoff stages. Visual/model acceptance remains distinct
   from a numeric pass. Carry set-manifest identity into the existing HANDOFF.

Whole-atlas means include unrelated materials; whole-roof means mix different
roll/channel/AO/weathering proportions. Use them to find drift, not as an automatic
exposure correction. A broad per-class quality tolerance does not prove a set match.
For identical recipe inputs, check deterministic equality within encoding precision;
for independently baked surfaces, document comparable samples and review the residual.
Do not invent a large color tolerance and call it permission to alter the palette.

## Known failure

Korean military r50, owner 2026-10-07: roof recipes retained the TC's nominal hex
colors but recomposed shading/weathering independently. Final roof texels averaged
3.9%/3.7% higher encoded luma than the accepted reference. Generic QA accepted a
35% relative luma difference from the nominal hex, never testing the set reference.
The confirmed lesson is missing final-output palette comparison; the contribution
of each shader/lighting factor still requires isolation before correcting the maps.

Follow-up isolation in r51 found that exposed roll samples already matched closely,
while the member compositor lacked the reference's assembly-contact color stage.
Reusing nominal colors does not inherit the sequence of shading operations.
Record local relief/AO, assembly AO, color-space transitions and finishing order
as separate inherited controls. Apply only the missing stage, once, with the new
building's measured contact. Preserve regions whose comparable samples already
match; whole-roof means remain diagnostic and never define the exposure target.
