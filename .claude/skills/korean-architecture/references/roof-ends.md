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
