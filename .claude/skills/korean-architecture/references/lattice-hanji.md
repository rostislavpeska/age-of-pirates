# Simple lattice and grey hanji

## Art direction

Fortress-age Town Center: natural brown wooden lattice, simple repeated angular
cross/rectangular pattern, subdued grey hanji. The owner preferred the second
pattern from the top left of the original sheet, then supplied simpler cross
examples. Reserve richer **green-painted decorative lattice for Industrial age**.
This is this set's art direction, not a claim that every supplied stock pattern
is historically Korean.

Hanji should show paper fibers, quiet tonal variation and contact darkening at
the bars, without a luminous white fill or another old grid in the paper.
Wood should read as separate bars: subtle bevel relief, grain along each bar,
and restrained joints/contact AO. Avoid drawing wood grain across the empty paper.
Do not add gratuitous ornament merely because the bake is expensive.

Validate **material readability**, not just the presence of the hanji bitmap.
Military r47 passed a 0.006 luma-variation floor with measured std 0.0098 yet
looked like a uniform panel. Compare a dedicated window crop with the actual TC
under matched lighting. Inspect physical fiber size, quiet mottling, roughness
and contact at the real bars. Larger, higher-contrast fibers may read as cracks;
keep that a visual check. Short-range frame AO can be shared conservatively by
keeping the least-dark value at corresponding texels when the owner has allowed
AO removal; this does not establish full-building AO. Record all affected readers
and retain opaque grey paper unless the owner changes the art direction.

After the r49 owner rejection (2026-10-07), review **window-versus-wall separation**
as its own item: compare the actual TC leaf and role-matched Japanese/Chinese
window crops, then matched close and RTS-size model views. Framed plaster panels
elsewhere on those atlases are not window references. Check each enclosed cell's
center-to-edge shading and warm lattice versus infill contrast; paper noise or a
reviewer's "textured" judgment cannot close this item. The owner requested a
muted blue-grey trial. Keep that a named art-direction variant, not a claim that
hanji is transparent glass or that all Korean windows should be blue.

Record the color space of baked shadow composition. TC Wanja multiplies sRGB by
`.55 + .45*AO`; military r49 multiplied linear color by `.76 + .24*AO`, with AO
clamped at .25 (minimum multiplier .82). Those coefficients are not equivalent.
Use actual frame occluders and inspect every shared reader; widening AO distance
must not darken a complete large pane or introduce another building's shadows.
Distinguish channel storage from shader application. The accepted TC stores its
measured window AO in Masks.R **and** shades BaseColor. Preserve that channel
contract; do not clear R to avoid an imagined second multiplication. An additional
Blender multiply is a separate shader operation and needs its own verification.
Military r50 cleared window R while its preview did not use R at all (INC-120,
owner rejection 2026-10-07). Compare packed AO-only, BaseColor-only and final views
against TC; retain the measured contact field and immutable parent.

User references live under `references/window-lattice/` in the external Korean
asset library, with `INDEX.json`. Preferred simple references include
`07_simple_cross_realism`, `09_preferred_repeated_cross` and
`10_simple_open_patterns`; the real joinery photograph provides material cues.
Keep the original files and watermarks. These are references, not texture inputs.

## Demonstrated Wanja r2 method

1. Scope window/door infill receivers separately from the outer frames. Group by
   physical proportions and lower wooden-panel treatment. Repeated instances may
   use shared leaf texels where color/AO/normal compatibility permits.
2. Allocate at the **final** runtime resolution before baking. In this Town Center,
   14 receiver quads became 56 coplanar leaf sections at a central stile and a
   physical horizontal rail. Two shared patches hold upper/lower leaf sections;
   right leaves mirror left leaves. This is a semantic UV split, not a new global
   unwrap or a requirement to merge every window object into one mesh.
3. Build the actual bars and relief in HIGH, with grey paper behind them and the
   appropriate wooden lower panel. Bake fresh normal, AO, material ID and color
   into those allocations. All previous grid structure must contribute zero to
   the new infill. Existing clean wood grain/paper fibers may be reused as material
   sources, independently of their old structural normal/AO.
4. Composite with exact feature masks and guarded gutters; include every affected
   channel. Keep unaffected atlas pixels and outer-frame geometry/UVs unchanged.
   Review mirrored normal response, bar bevels, corners, paper contact shadows,
   all four sides and actual gameplay-scale readability.

The current exemplar uses two patches of **162 x 325** and **162 x 301** pixels
inside the existing 2048 atlas. Its measured density is **256–289 texels per raw
model unit on both axes**, versus rejected r1 at 115. The owner's local requirement
was >=230 (2x linear, 4x area) plus the comparable vanilla floor. A large source
bake shrunk back to 115 does not meet that request. These measurements are an
exemplar, not the universal density policy for every future building.

Reference bar width: .024 model units (~6.14 final pixels at 256 t/u). Use physical
dimensions and final pixels to choose it for another model; do not copy world-unit
values across different scales. Bake antialiasing improves edges but does not
increase final texel density. Mirrored leaves require tangent-space verification
in the actual export, especially where the engine stores no bitangent sign.

For new lattice HIGHs, join plain overlapping timber solids **before** beveling
the joined exterior. Extend corner joints through the adjoining member width.
Coplanar duplicate surfaces produced black AO squares at crossings in the military
r55 pilot; Boolean unions of already beveled full-lap bars then dropped a vertical.
The corrected order passed 238 centerline ray probes and eight exposed crossing
AO samples at 0.994–1.0. Assert every intended bar is covered before baking and
inspect crossing/corner crops afterward. Those numbers describe this pilot,
not a universal requirement that exposed timber or real recesses have white AO.
An isolated pattern/AO specimen is not whole-model acceptance: compare its final
resolution against the modeled frame, retain the rollback, and check every shared
reader before propagating its texture or removing inner lattice geometry.

## Implementation and evidence

In the Korean repo: `research/Texturing_11/Claude_CP2/window_wanja/`:

- `r2_prepare.py`: allocation and protected scope.
- `r2_bake.py`: high geometry and fresh channel bakes.
- `r2_compose.py`: guarded atlas composition.
- `r2_model.py`: semantic splits with original vertices/nonwindow UVs retained.

These scripts are **checkpoint-specific reproduction sources**, with explicit
paths and face IDs. Inspect/configure them for a new building; do not run them
blindly. Registry entries identify their tested hashes and the complete exemplar
handoff, density measurements, original-material baseline and rollback.

Known pitfall: clearing a mesh's material slots reset 713 original face indices
to slot zero and put the wrong atlas on roofs. Preserve the per-face material
vector before manipulating slots and verify it after save/load and live publish.
The r2 repair verified all 24 LOW objects across the eight review sets.
