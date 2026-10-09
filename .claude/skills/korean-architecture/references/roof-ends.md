# Rounded Korean roof ends: feature contract

## One roof = one bake (owner, 9 October 2026)

"The roof bottom should always be baked together - possibly also the ridges." A roof is baked, reviewed and
handed over as ONE assembly. A field-only bake is never a specimen, a pilot or a step: the castle pilot of
that day baked the tile field alone, its eave fronts and underlip on another page were left grey, and the owner
had to point it out although this file already demanded "field + front + back/under + corners".

| Part (castle subtype / TC-military class) | Source | Maps |
| --- | --- | --- |
| Tile field (`roof_field` / `ROOF_TILE`) | tile HIGH: set-reference section and downhill laps, measured against the TC HIGH | NORMAL (+ TC roof_v2 lip bump), AO, tile IDs |
| Eave front (`roof_end_receiver`) | front HIGH from military `uv_r43/eave_recipe.py` `relief()` on the actual receiver faces, on the field's roll rows | NORMAL, AO, role IDs, OPACITY from the same recipe's `silhouette()` |
| Underlip / back (`roof_underlip` / `EAVE_BACKING`) | no relief | flat NORMAL; OPACITY = the front's alpha at the underlip's actual height |
| Hip/verge caps (`clay_cap`) | cap HIGH: TC `ridge_v2/build_ridge_high.py` tiles (arc-length courses from the top, lip step, bead, eave upturn) + round end-tile disc | NORMAL, AO, tile IDs |
| Soffit band (`soffit_rafters`) | none - must stay behind the cutout clearance | assembly AO |
| Main ridge (`ridge_timber`) | none - timber (KR-RIDGE-01), grain along the length | colour pass, assembly AO |
| Gable boards, hidden backing | none | colour pass / never visible |

Enforcement, not memory: every roof bake recipe sets `"assembly"` to
[roof_assembly_spec.json](roof_assembly_spec.json). `blender-high-low-baking/scripts/bake_owner_maps.py` runs
`assembly_scope.py` before any preflight and refuses a roof scope that leaves a part out, misses a page holding a
part's owner faces, lacks a source object (caps) or gives a `none` part no reason. A part a building really lacks
is declared in `assembly_absent` with its reason. One review shows every part with its own maps and the alpha
bound; the eave gates below (`check_alpha_chain.py`, `check_eave_contract.py` with the building's declared
`expected_own_pages`) run on that assembly. Worked example: Korean repo
`research/Colonial_Expansion_17/castle_geometry_r1/ROOF_ASSEMBLY.md` (Colonial pavilion).

Read the Korean repository pattern **KR-EAVE-01**,
`patterns/korean/rounded_eave_tiles.md`, resolved through the current handoff and
`recipes.json`. It traces the accepted TC HIGH, fitted roof banks, course-ID bake,
geometry-derived alpha and the separate hip-cap generator. It holds measured
parameters and the military transfer status; do not duplicate that implementation.

Use this recipe when working on the round cover-tile ends, scalloped pan ends or
curved side/hip caps. Main top ridges remain timber per the Korean art direction.

The **accepted Korean Town Center is the primary roof-end standard**, explicitly
preferred by the owner over the Japanese Shrine on 8 October 2026. Reuse its
receiver, relief and cutout method at the new roof's measured scale. Japanese/
Chinese models inform functional silhouette and footprint comparisons, not a
replacement end treatment. This preference is recorded in project KR-EAVE-01.

The required unit of work is **field + front + back/under + corners + UV readers**.
A field-only normal bake is not a finished eave. Model the disc and pan ends on
the HIGH, then derive matching alpha from its actual silhouette. Keep field rows
and end centers in one measured coordinate system. Bind opacity in the preview.

**LOW/HIGH distinction (owner correction, 8 October 2026):** LOW uses clean
continuous roof fields and perpendicular/steep overlapping eave receiver strips,
with a hard normal and UV break at the fold. Individual rounded tile noses,
end discs and scalloped pans belong in HIGH and are baked onto these strips;
they are not a row of separate LOW solids. Overall projection, closure and backing
clearance remain real geometry. Preserve matching cutout readers on front, back
and under surfaces. The rejected House r1-r3 interpretation does not supersede
the accepted Town Center recipe or authorize edits to the military workstream.

Do not paste the TC opacity atlas onto a different UV layout. The accepted TC
uses separate source opacity packed into cutout BaseColor at export; its PNG
BaseColor alone does not establish transparency. Military prop matB is not the
TC's cutout matB. Reproduce the method within the current building's page budget.

Generic shared underside cells cannot receive alpha holes needed by a narrow
eave lip when unrelated opaque wood also reads those cells. Show the FRONT,
BACK/UNDER and owner/member allocation explicitly before that local transfer.
Preserve existing TC shared pixels, prop UVs and image bindings.

## Geometry and missing-feature failures, INC-100 / INC-101 (2026-10-06)

The military r42 pass repaired roof-field artifacts but left the requested eave
feature as an unbaked material placeholder. A documented recipe was mistaken for
completed scope. The first r43 end bake then fit the existing flush fascia,
without establishing the tile projection the owner expected.

Before an eave bake, show a side section naming the tile nose, backing/fascia,
underside, projection distance, receiver height and relief radius. Compare it to
the accepted TC cross-section. Validate actual geometry, not material color or
normal shading. The original TC generator explicitly inset the backing in XY;
a Z-only roof shell is not an equivalent construction. If the owner asks for
more projection, make that silhouette/geometry change first. Recessing backing
alone is not evidence that the tile edge moved outward.

The feature inventory must account for every roof and mirrored reader: field,
front relief, front opacity, corresponding underlip and corners. Missing roles,
unbaked placeholder bindings, an all-opaque cutout, or a flush nose are failures.
Keep geometry acceptance separate from successful ray coverage. Use
`scripts/check_eave_contract.py` with measured evidence; it does not replace
images, mesh/UV checks, or engine validation.

If geometry changes, classify bake dependencies explicitly. Unchanged positions,
UVs and corner normals can reuse their maps; altered outer roof rows need a new
HIGH and bake. Preserve original skin weights when rebuilding mesh data, including
original vertices as well as new ones. Do not silently lower density, enlarge a
texture page, or add a runtime material to accommodate a local roof repair.

Check coupled corner-cap reach and every perimeter terminal after extrusion.
The r43c Stable lip initially left two triangular openings at its internal roof
junction (six boundary edges; r42 had zero). Two existing-shared-WOOD backing
end-grain faces closed them without new vertices or atlas space. Compare boundary
and nonmanifold counts to the source, including interrupted or partial eaves;
a closed rectangular eave does not validate a roof that terminates in a wall.
Keep this topology check before publishing, independently of bake ray coverage.

## Failure prevention, INC-098 (2026-10-06)

Derive roof cross-sections from actual surface intersections. A collection of
vertices at one coordinate is not a complete section: UV seam cuts can insert
isolated boundary vertices without changing the surface. Using those vertices
as min/max boundaries erased the military roof relief in large rectangular bands.

Before HIGH generation, run a seam-insertion invariance fixture and inspect every
measured profile for collapsed/narrowed interior sections. Cache keys include the
LOW/UV contract, HIGH recipe code and parameters, not only the source blend hash.
After baking, test missing relief independently from ray coverage and inspect
normal-only views of all sides and mirrored users. A successful front-slope pilot
does not approve the remaining slopes. Reuse unchanged region bakes with explicit
provenance; preserve rejected maps and renders for the regression test.

Generic cage/normal/triangulation, texture QA, UV ownership and export mechanics
remain in their existing skills. No new general workflow or extra texture page
is implied by this Korean feature recipe.

## INC-103: front opacity passed while the underside filled the holes

The r43c handoff was rejected for missing visible alpha. Its front shader and
texture were connected, but the underside UV interpolated from the front's bottom
to its top across the projection depth. That sampled opaque front texels behind
transparent ones. The previous reader checker only iterated FRONT faces despite
its broader name, and the semantic gate accepted a small nonzero cut fraction.
Neither established a visible cutout. This was a validation failure.

Sample every BACK/UNDER point at its **actual height**, project outward onto its
corresponding FRONT, then compare alpha through each surface's own destination
UVs. Enumerate owners and mirrored members, assert the expected face count, and
fail above5% opaque-backing mismatch. Never substitute a check of front members.

Also render the final receiver with its backing, a front-only silhouette reference
and a deliberately opaque shader control at the same useful camera. The reference
must expose at least100 cut pixels; a fully blocked/empty view is not a pass.
Fail if more than5% of the reference cut pixels are filled. Preserve these images
and source identities in the handoff. Test restored solid backing, disconnected
opacity and an unusable camera as negative cases. The shared
`scripts/check_alpha_chain.py` performs the measured-evidence check and is now
required by `check_eave_contract.py`; a legacy report without it fails.

r44 measured underlip mismatch fell from91.13%/89.85% to2.64%/3.59% for
Barracks/Stable. In the controlled rendered views, obstruction fell from63.54%/
61.11% to0%; the opaque control was100%. The fix uses local strips on previously
unused own2048 texels (2.62%/2.54%, including margins), retaining front/field pixels
and all geometry. Generic shared opaque wood cells cannot carry these cuts because
unrelated buildings read them. No new runtime page or material was introduced.

These are Blender candidate checks. Export must separately verify cutout shader
selection, packed DDT alpha, UV identity, mipmaps and engine rendering. A grayscale
Opacity PNG with an opaque file-alpha channel works through its RGB-to-Alpha link
in this authoring shader; exporting that PNG's A channel would lose the cutout.

### r45b correction: check the complete backing at useful angles

The owner rejected r44 again: a narrow front/underlip silhouette test passed,
but actual shaded shallow-angle views still showed a dark band. Shared opaque
WOOD underside faces remained behind the gaps. Checking only faces labelled
EAVE_BACKING missed the occluder. Small iterative extensions consumed additional
work without resolving the construction; the owner explicitly identified this
as costly rework. No independent dollar measurement was made.

Before rebaking, ray-test the full assembled roof, including generic atlas wood
and corner caps. Show a measured section and a contrasting backdrop through the
actual final shader from shallow, normal and side angles. Determine the required
clearance from the tile relief envelope and visible underside, then make one
adequately sized, bounded correction. Do not use an arbitrary small increment as
proof of sufficiency. For this military candidate the existing 0.10 projection
needed an additional 0.18 inward backing setback (about 0.28 total), with the
tile nose, outer field and UVs held fixed. This is evidence for this model, not a
universal dimensional constant. Verify all six roofs and mirrored readers.

Retain the failed shaded render as a regression case. An emission-only alpha
test, connected Alpha socket, or nonzero transparent-pixel count cannot pass the
handoff alone. Preserve actual texture-alpha bytes and test all opaque geometry
behind cutouts independently from mesh closure and bake ray coverage.
# Roof-end colour and visual regression checks

Treat exposed clay end discs, scalloped pans and roof-field surfaces as separate
material roles when inheriting the Town Center finish. A roof-field colour sample
is not an end-disc colour reference. Resolve the actual effective object material,
UV binding and current texture revision; retain that reference read-only.

From fixed frontal and oblique cameras compare full material, unlit BaseColor,
AO-only and neutral-grey normal-only views. Include a normal-disabled control when
darkness survives the isolated normal view, and inspect both lit and shadow sides.
Test all repeated readers and door/window-adjacent eaves. Do not brighten AO or
invert correct normals to hide a BaseColor mismatch. Preserve the agreed page
budget, UV coordinates, cutout alpha and unrelated pixels during a colour repair.

Owner evidence, Korean Houses 2026-10-09: dark ends were rejected; actual TC
comparison identified a separate grey end-clay treatment. The owner confirmed the
separated-view method with "Testing works". This confirms the review method,
not every future textured candidate or engine shading.
