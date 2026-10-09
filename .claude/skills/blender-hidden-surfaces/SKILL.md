---
name: blender-hidden-surfaces
description: Classify architectural interior and underside faces for economical shared backing materials using image visibility, rays, opposing surfaces and a hybrid graph cut. Use before UV allocation when simple down-facing rules fail; preserves geometry and UVs and delivers editable Blender review candidates.
---

# Hybrid hidden-surface classification

Identify which intact-building faces can be **proposed** for a shared, low-detail
backing material. Black in the review means proposed backing, never removed mesh.
This is separate from UV stacking, AO compatibility, density reduction and export.

Keep **visibility class and physical material as independent face attributes**.
The shared hidden atlas can contain several regions (wood, stone, clay, plaster,
metal, and other families actually present). Black is only a visibility-review
override. After that review, provide a colored hidden-family view with distinct
named materials while retaining the hidden mask and original face IDs. Never
collapse every hidden face into wood or a single final backing material.

The hybrid method was the user's preferred result after inspecting five alternatives
on the Korean Town Center (2026-09-27: “5 - hybrid - so far the best one”). The user
authorized this skill. That is acceptance of the approach for further work, not
proof that every face, camera range or future building is correct. See
[validation evidence](references/validation.md).

The later proxy/exposure-aftercheck candidate, after physical overlap repair, was
accepted to continue on 2026-09-27: the interior was "good enough for now", not
perfect. Follow [proxy proposals and exposure aftercheck](references/proxy-aftercheck.md)
for that additional pass. The packaged classifier still implements the earlier
Hybrid baseline; the accepted consumer aftercheck is documented separately and
must not be advertised as a fully automatic replacement.

## Binding rule: every inner/backing face is checked from OUTSIDE

Owner correction, 9 October 2026 (Korean Castle UV r1): faces were sent to the shared
generic atlas as "inner" because of their role or name (dark opening backs, an interior
shadow core seen through a lookout band), and they were plainly visible from outside.

- A face may go to a hidden/backing/generic resource ONLY after an outside check of
  the ASSEMBLED model: rays or renders from the whole exterior camera envelope (all
  azimuths, gameplay elevations plus low/grazing views), through every opening, with
  all other parts as occluders. Any escaping ray or visible pixel keeps it visible.
- Role, material, label, darkness, "void"/"inner"/"bottom" names and face normals are
  candidate generators only, never certificates. Dark backs of embrasures, doors and
  windows, and interiors seen through openings are VISIBLE surfaces.
- Contact faces (bottoms resting on other parts, tops buried under a ceiling) still get
  the same outside check; do not assume contact.
- Before handoff, render the generic resource's black isolation copy from those views
  and require it to read black from outside; keep the check's report in the handoff.
  A role-filtered pixel count (only the "hidden" material) is not this check.
- **Black proves nothing without a lit positive control.** Run the same views with an owned page isolated and
  require it to light a stated floor of pixels (for example most of the model's silhouette). Otherwise the check
  FAILS.
  - Castle UV r4 incident: the check read 0 lit pixels because the model had been placed off camera from stale
    world matrices. Its control lit 197 k px instead of ~4 M.
  - Background scripts evaluate the view layers before reading `matrix_world`
    (`blender-uv-space/scripts/safe_pack.py: fresh_world()`).

## Preserve the current checkpoint

- Verify the actual Blender connection, file, scene, objects and mode through the
  project's available MCP/API route. Preserve unsaved work; do not replace the live
  file with a background result. Desktop control is not a substitute for a working API.
- Start from approved solid material families: wood, stone, plaster, tile, metal,
  glazing, cutout, decoration. Preserve the physical family under a black review
  override; darkness or an earlier black assignment is not a training label.
  Recover lost family labels from original face semantics first. Unanimous labels
  on the same connected construction component can support an inference; mixed
  components need explicit decisions. Do not spread a majority label across a
  roof shell combining clay tiles and timber soffits. Record retained assumptions.
- Work on an independent comparison copy. Do not delete faces, change normals,
  apply modifiers, triangulate the authoring mesh, unwrap, rescale or stack UVs.
  Tessellated read-only arrays are allowed solely for measurements, with every
  sample mapped to its original object and polygon.
- Inspect opaque geometry from both sides. Protect alpha receivers and omit them
  from opaque occluders unless actual opacity is sampled. Unknown shader behavior
  is a recorded uncertainty, not a concealment certificate.

## Process

1. **Freeze the contract and input.** Record source hashes, object/face identities,
   material families, world up, scale, camera elevations/azimuths/zoom, terrain and
   render state. Record unknowns. The bundled example uses Z-up and provisional
   orthographic 30–75° cameras; it is not an engine guarantee. Intact, damaged and
   freely rotating debris require separate decisions.
2. **Measure independent evidence.** Follow [data and execution](references/execution.md)
   using the packaged snapshot, ray, image and voxel helpers. Train and withheld
   views must differ. Do not classify from a single screenshot, face normal, AO
   darkness or one centroid ray. Keep the marked narrow outside eave strips,
   underside beams and sealed interior panels distinguishable.
3. **Fuse and retain uncertainty.** Use the exact, configurable
   [hybrid formula](references/method.md) and `scripts/hybrid_visibility.py`.
   Adjacent faces only influence each other across compatible physical-material
   boundaries and sufficiently similar normals. Explicitly keep exposed rims,
   protected details and ambiguous mixed polygons until reviewed. Visibility
   scores are not calibrated probabilities or invisibility proofs.
   For missed inward-facing walls or floors, first read the
   [interior-pass research and failures](references/interior-pass-research.md).
   The replayable Hybrid baseline is incomplete for these surfaces. Do not fix
   that by changing a normal threshold or declaring every enclosed region hidden.
   Room-proxy proposals need the exposure aftercheck above: protect small mixed
   beam/wall returns whole; use bounded coherent hidden cores only on broad panels.
4. **Inspect before asking the user.** Check matched whole-building gameplay and
   underside views, soffit close-ups, opposite sides, gables, beam sides/ends,
   openings, interior and junctions. List withheld-view exposures and control
   disagreements by original object/face. A low false-positive count does not
   excuse missing all intended backing (the voxel-only failure).
5. **Deliver actual Blender scenes.** Preserve the original. Supply independently
   editable, clearly named review scenes with solid family colors plus black
   backing, selectable meshes, overlays, gizmos and usable UV Edit controls.
   If several methods are requested, load **all** in the live session and save one
   reopenable comparison file; images or separate unopened files are insufficient.
   Provide matching images in chat and a concise uncertainty list. For interior
   inspection by moving through solid walls, retain opaque shading and use
   perspective with Dolly/Walk navigation. Do not interpret that request as
   transparency. Use X-Ray only for an explicit see-through/selection inspection.
   Record prior clipping/navigation/X-Ray settings when changing them.
6. **Record the feedback accurately.** Distinguish preferred approach, accepted
   face allocation and approval to automate. Continue within existing authorization;
   do not repeatedly ask for approval already given. Do not silently advance to
   UV reuse/AO/packing from a method preference alone. Keep a defect register and
   count corrective prompts, extra reviews and requested app visits; record human
   time only if measured or supplied.

Run expensive measurements on a saved background copy, with bounded progress and
memory limits. Reuse evidence when geometry, camera and shader contracts match;
changing only graph weights does not require another bake or Blender restart.
Re-run five competing methods only for an actual comparison request or regression,
not on every building. Keep renders and consumer datasets in project scratch space.

## Handoff

Supply the source fingerprint, original-face mapping, parameter file, raw evidence,
candidate/uncertainty report, matched pictures, editable comparison `.blend`, live
scene names, untouched-geometry/UV verification and feedback state. Test scripts
check computation, not artistic acceptance. A second building and calibrated camera
and shader behavior remain necessary before advertising a general factory rule.

For geometry-removal proofs or damage-state topology, read the architecture skill's
[surface visibility and destruction](../blender-architecture/references/surface-visibility.md).
For the later allocation workflow, return to
[architectural texturing](../blender-architecture-texturing/SKILL.md); this skill
does not solve AO-safe UV overlap.
