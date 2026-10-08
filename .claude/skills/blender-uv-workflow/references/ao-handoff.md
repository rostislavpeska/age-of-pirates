# White AO checkpoint and UV handoff contract

Owner extension, 2026-10-09: add one white texture-baked AO model per building;
resolve genuine AO differences before final UV rearrangement. This extends the
accepted operator layout, not acceptance of any current asset's UV quality.

## Order and deliverables

1. Record the session's existing operator-agreed runtime texture budget and sources.
2. Preserve geometry, semantic IDs and attachments; classify hidden/reused surfaces
   and physical painting subtypes. Produce coherent charts and material isolations.
3. Conjoin compatible geometry/material families with explicit owners and exact
   correspondences. Show the standard checker, resource isolations and family colors.
4. Fit provisionally in the agreed pages; measure density, content, necessary padding
   and unused pixels. Do not call this final capacity: AO may require more variants.
5. **Bake the independent white AO reference.** Prefer the available Painter API;
   document any Blender fallback. Use complete assembled geometry as occluders,
   explicit triangulation and unique diagnostic coordinates. No screen-space AO
   substitute. Label recipe, source, revision and `REFERENCE — NOT FINAL SHARED AO`.
6. Compare corresponding points in every parent sharing family against the explicit
   owner. Show dark/contact regions and mismatch heatmaps. Save per-family decisions:
   keep; split into compatible AO variants; unique; or approved neutral-mask region.
   Differences in roughness, dirt, normals, opacity and player color remain independent
   constraints. AO removal does not make those differences compatible.
7. Apply those decisions, then final pack/freeze. Recompute density, source-cell
   compatibility, pixel accounting, gaps and mip behavior within the agreed budget.
8. Bake once per final owner into the frozen layout and display that result on the
   complete white models. Compare against the preserved unique reference with fixed
   views and low eave/contact close-ups. Repacking invalidates old page-space bakes:
   reproject from verified masters or rebake; never relabel the reference as final.

## Who writes an overlapping texel?

There is no workflow guarantee that an island visually “on top” or “underneath”
another is the winner. UV coordinates have no artist-controlled depth/layer order.
Do not depend on face index, object order or an undocumented rasterization winner.
For each channel and family name exactly one **bake owner**. Only its surface writes
those texels; all assembly parts still participate in occlusion as configured.
The owner-only receiver may be incomplete geometry; the occluder assembly must not
lose members simply to avoid overlapping targets. Prove current texel coverage.

A lightly occluded face may be chosen as a simplification's representative, but
that does not automatically make its AO correct for the other faces. First measure
all members against the unique reference. Declare changed owner IDs and correspondences.

## Two conflict dispositions

**Split:** retain parent lineage and allocate a separate compatible variant inside
the agreed existing page budget. A genuinely unique shadow pattern can remain unique.
Quantify added pixels and density cost. Do not jump to a new texture page.

**Neutralize:** form the union of conflicting regions in common owner coordinates;
set AO to 1 throughout that region for the owner AND all readers. Preserve matching
AO elsewhere, record the mask and lost contact shading, and show the candidate before
acceptance. This is a deliberate simplification, not an AO compatibility pass.
It cannot clear only one member while all members still read the same texels.

### AO accumulation: count applications, not shared islands

AO is a scalar visibility field, with 1 unoccluded and 0 fully occluded. An ideal
unweighted estimator is `A = unoccluded_rays / total_rays`; distance falloff and the
chosen baker can modify this recipe. Two actual nearby occluders can legitimately
make a surface darker. Duplicate target writers and repeated multiplication are
different defects: neither is repaired by counting how many UV islands read a texel.

If N islands read one texel `A=0.8`, each must still read **0.8**, whether N=1 or N=10.
Multiplying that AO into an image twice gives **0.64**, three times **0.512**. That is
an application/compositing issue, not an inherent consequence of conjoined UVs.
An overlap bake may overwrite or otherwise corrupt pixels instead of multiplying;
there is no general “N overlapping islands” correction formula.

Enforce this deterministic postproduction sequence:

1. Preserve raw reference AO. Validate exactly one final bake writer at every used
   owned texel and the full set of occluders. Count duplicate target writes separately
   from allowed UV readers. Assembly duplicates must not silently enter the ray scene.
2. Resolve conflict variants or the explicit common neutral mask. Use
   `A_resolved = (1-mask)*A_owner + mask`, with mask in [0,1]. Never run this operation
   incrementally on an already composited BaseColor. Any artistic strength adjustment
   must be explicit, e.g. `1-strength*(1-A_resolved)`, independent of reader count.
3. Pack the resolved field into the engine-declared mask channel as DATA (linear /
   Non-Color in Blender), preserving the other packed channels and channel convention.
   Do not multiply by each member's AO, premultiply multiple bakes together, or change
   the mask to white merely because BaseColor already contains shading.
4. Maintain an effect ledger: raw AO -> resolved AO -> packed channel; separate entries
   for BaseColor shading, Painter shader/mixing, AO-driven generators, export and
   runtime shader usage. **Storage is not a second application.** The accepted engine
   recipe may legitimately store AO and include artistic contact shading in BaseColor;
   preserve that recipe and identify unintended repetitions rather than removing data.
5. Compare resolved AO against the decoded packed channel over used pixels, including
   sparse contact witnesses. Show AO-only, BaseColor-only and final-material views.
   Reuse `blender-high-low-baking/scripts/check_ao_storage.py` and its regression tests.
   Check padded/mip boundaries separately. Final shading still needs visual validation.

Only when the SAME scalar AO was multiplied exactly k times in known linear data,
with no other factors, clipping or quantization loss, is `A = result**(1/k)` an exact
inverse. k is the verified application count, **not** the conjoined-island count.
Use it as a diagnostic explanation, not an automatic repair; regenerate clean data
from the preserved source. Lost information and mixed lighting cannot be recovered
by such a root.

Keep immutable raw AO for diagnosis and a separate resolved AO input. Apply correction
before multiplication into BaseColor or packed AO channels. White multiplied by a
dark AO map remains dark. In Painter use AO channel **Replace** mixing and **Normal**
layer blending when overriding the additional mesh map. Effects/generators may read
the mesh-map input rather than the painted output; bind the resolved map consistently
where intended and re-evaluate those effects. Do not claim this fixes shadows already
in BaseColor, painted dirt, roughness or normal maps. A changed generator look is
separate evidence requiring review.

## Observable completion and machine evidence

At the AO stage, simultaneous copies = models x (texture resources + 3): standard
COLOR_GRID, one rest-black isolation per resource, real family colors, white AO.
For A/B/C with four resources this is **21**, not 18. All retain their attachments.
The AO copy's UV editor, shader and displayed bake must agree. A temporary unique AO
layer is explicitly diagnostic; it must never replace production UVs, inflate density
claims or become an unapproved runtime allocation. Diagnostic dimensions follow the
project's square/page-size policy and are recorded separately from runtime pages.

**Operator boundary (owner correction2026-10-09):** create and inspect temporary AO
coordinates in background Blender. Publish the agreed white AO model, not its temporary
unwrap worksheet. The normal operator workspace opens on production UVs; white reference
copies are display-only by default. Expose diagnostic UV editing only on a specific
operator request, with an unmistakable TEST/REFERENCE label and correct image bindings.
Before any publication give the actual production-map/density delta, including zero.
No surprise view or layout changes. Experimental output is not a review deliverable.

The final UV handoff binds: geometry/attachment census; material/subtype ownership;
production UVs; family/owner/correspondence table; raw and resolved AO with recipe,
occluder and triangulation identities; decisions/masks/variant lineage; final page
layout; density versus named baseline; pixel/padding/overlap/source-cell reports;
saved review workspace and pictures. Keep authoring `.spp` if used, noting unique-UV
diagnostic projects are not final shared-UV paint masters.

Missing AO comparison, unresolved decisions or a failed density/source-cell gate means
**WIP handoff**, not complete frozen UVs. Machine verification, visible delivery and
owner acceptance are separate statuses; adding a white copy alone does not satisfy
AO separation. The contract is fail-closed evidence validation, not a promise that
instructions alone make an agent infallible.

## Primary-source research (checked 2026-10-09)

- [Adobe AO painting](https://experienceleague.adobe.com/en/docs/substance-3d-painter/using/painting/advanced-channel-painting/ambient-occlusion-painting)
  documents Multiply versus Replace and Normal AO-layer blending.
- [Adobe AO from mesh](https://experienceleague.adobe.com/en/docs/substance-3d/bakers/bakers-settings/ambient-occlusion-from-mesh)
  documents ray count, relative/world distances, backface policy and secondary-ray
  mesh-name filtering. Do not confuse target matching with which parts occlude.
- [Adobe project creation](https://experienceleague.adobe.com/en/docs/substance-3d-painter/using/getting-started/project-creation)
  explains separate materials/texture sets. Separate sets are separate resources;
  they are not free runtime capacity for overlapping UVs.

The explicit-owner and shared-neutral-mask rules are this harness's deterministic
design, supported by the existing owner-only bake workflow; they are not a claim
that Adobe specifies a supported top/bottom UV overwrite priority.
