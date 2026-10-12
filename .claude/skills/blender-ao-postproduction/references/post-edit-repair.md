# Contact-shadow repair after geometry edits

Use this when a moved or removed part leaves a baked shadow behind. Keep the
approved page size and UV layout unless a separate layout change is authorized.

## Diagnose the stored effect

1. Preserve the accepted maps and before/after geometry with source hashes. Locate
   the vacated receiver through its actual UV triangles. Include the moved part's
   old contact shading and its new receiver in the inspection.
2. Compare unlit BaseColor, AO-only and the final material at the same view. Sample
   the exported channels. AO may live in a packed mask, a BaseColor multiply, a
   Painter generator, or several of these. Record the actual effect chain.
3. Rasterize all consumers of the affected page. Prove which other surfaces read
   the proposed patch. A unique old receiver can be repaired even when the new
   receiver is shared; do not treat them as one blanket pass.

## Choose the smallest valid repair

- **Editable source:** regenerate the affected AO and its dependent generators
  from the corrected assembly, then composite only the affected region into the
  accepted maps. Keep baker radius, normals, connectivity and sampling fixed.
- **Flattened maps:** restore the local AO from clean matching material nearby,
  or an after-edit reference calibrated against that clean region. Match surface
  height and proximity to retained occluders; feather within the verified scope.
  Preserve legitimate eave, post and ground shadows. Neutral white is appropriate
  only where the intended AO is neutral.
- **Near-black burn-in:** do not divide by near-zero AO to recover BaseColor.
  Recover the underlying material from its source layer or a compatible donor,
  preserving grain/pattern scale. An AO-channel repair alone cannot undo baked
  BaseColor dirt. Do not change BaseColor if the defect exists only in AO.
- **New contact:** update only compatible UV readers. A unique new doorway shadow
  cannot be baked onto a shared wall without appearing on its other readers.
  Keep that limitation explicit; do not silently repack, create a page, or claim
  complete AO refresh. Use the skill's shared-AO treatment when required.

An independent baker is diagnostic evidence, not automatically a drop-in match
for the accepted atlas. Adding a before/after AO difference can leave a rectangular
contrast remnant when the old atlas and reference use different AO curves. Inspect
the AO-only model and align the reference to clean local donors before accepting
the repair. Do not make the whole material brighter to hide the remnant.

In Painter, use a replacement AO layer/mesh-map path as appropriate and verify the
export; painting white into a Multiply layer cannot erase existing darkness.
Generators consuming the old mesh map need explicit refresh or a scoped output
repair. Keep roughness, normals, opacity and player colour unchanged unless their
own stale contact effect is demonstrated and the edit is in scope.

## Verify and hand off

- Save the source maps, repair mask, processed channel, donor/reference identity
  and parameters. Prove zero changed pixels outside the mask and exact unrelated
  channels. Check compatible padding and consumer mips at the patch boundary.
- Inspect the vacated location in AO-only and textured views; no ghost silhouette,
  bright rectangle or lost legitimate contact shadow. Check all shared readers
  and the new location. Numerical containment alone is insufficient.
- Carry the repair forward in the build recipe so the next texture export does
  not restore the stale shadow. Mark construction/destruction state compatibility
  separately from texture repair and live-view delivery.

Measured example, 2026-10-12: an architectural door relocation left AO 8/255 on
the vacated plaster while neighbouring plaster was 247–255/255. BaseColor still
contained the underlying material. The old wall had unique UVs; the new wall's
135,101 sampled texels had other readers. A first additive-difference candidate
left a visible rectangle in the AO-only view, so it was retained as rejected
evidence and replaced by a locally calibrated donor repair.
