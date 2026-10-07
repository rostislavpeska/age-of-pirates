# Rounded Korean roof ends: feature contract

Read the Korean repository pattern **KR-EAVE-01**,
`patterns/korean/rounded_eave_tiles.md`, resolved through the current handoff and
`recipes.json`. It traces the accepted TC HIGH, fitted roof banks, course-ID bake,
geometry-derived alpha and the separate hip-cap generator. It holds measured
parameters and the military transfer status; do not duplicate that implementation.

Use this recipe when working on the round cover-tile ends, scalloped pan ends or
curved side/hip caps. Main top ridges remain timber per the Korean art direction.

The required unit of work is **field + front + back/under + corners + UV readers**.
A field-only normal bake is not a finished eave. Model the disc and pan ends on
the HIGH, then derive matching alpha from its actual silhouette. Keep field rows
and end centers in one measured coordinate system. Bind opacity in the preview.

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
