# Pipeline order: reusable sources, frozen runtime UVs

A baked image belongs to the UV layout it was baked on. Moving, rotating, flipping,
scaling, merging or repacking charts afterwards puts every pixel in the wrong place,
and tangent-space normals also change with the chart's orientation. The image can
only be rebaked, or transferred to the new layout with one resampling loss. Either
costs a session when the bake was set up by hand. Final runtime bakes use frozen
UVs. Pilots and reusable masters have separate contracts below; save every bake
as a one-command recipe with explicit inputs.

## Order

0. **Declare budget and quality references.** Record owner-confirmed runtime pages
   and vanilla density floors. Area estimates guide planning but do not reject a
   deliberately unpacked clean-chart worksheet. Use the [shared UV workflow](../../blender-uv-workflow/SKILL.md):
   clean charts -> visible material split -> sharing review -> AO variants -> pack.
   Density and page budget are hard gates at final freeze/export. Never shrink
   clean charts or force merging to satisfy an early area estimate.
1. **Geometry.** Final low mesh. The high poly is built in place (same world
   transform as the low), with an explicit region/detail contract.
2. **Bake plan.** List the regions that receive baked detail (normal, local AO,
   opacity, ID) and the high source of each. Faces whose high detail differs must not
   share texels: pass that list to conjoinment as `protect` or as a compat reject.
3. **Pilot bake.** One representative bay and one roof slope, on a throwaway layout,
   labelled `pilot`. The deliverable is the **recipe** (config JSON + one command:
   targets, ray distance or cage, margin, samples), not the images. Pilot images are
   never treated as final page acceptance. A reusable bake master is a separate
   allowed product after local geometry/detail freeze; see the [dependency table](../../blender-uv-workflow/references/bakes-and-recovery.md).
4. **UV chain.** Clean charts -> conjoin -> AO separation -> pages. Keep the high poly
   next to the low (same file or linked, same transforms). AO sampled to decide
   families is a measurement, not a deliverable.
5. **UV freeze.** The 03_uv handoff records the measured density and the page budget, and both
   must pass ([handoff contract](handoff-contract.md) rule 7). The owner signs off the final layer. Record its fingerprint:
   `blender -b file.blend --python ../../blender-high-low-baking/scripts/uv_fingerprint.py -- record config.json`.
6. **Final bake** with the recipe (`bake_owner_maps.py` for normal / local AO /
   opacity, `bake_owner_ao.py` for assembly AO) onto the owners of the frozen layer.
   Each bake report stores the fingerprint. Before assembly or export run `check`:
   a stale bake stops the step.
   For `bake_owner_maps.py`, also record the LOW geometry/normal/triangle contract and
   declare exact region faces and allowed HIGH pairs; see the
   [bake contract](../../blender-high-low-baking/references/bake-contract.md).
   Its preflight rejects missing or unexpected targets and preserves receiver normals.
   Extend pilots through explicit per-region recipes, not by deleting `only`: a good
   center region does not certify its upturned corners or the next slope's source.
7. **Texture and export.** Tiled materials projected in 3D and baked into the owners,
   painted details, then export. Sources: Poly Haven / Substance assets by default, edited (tinted,
   made seamless); GPT-generated images only for genuinely unique textures (image harness, Claude only).

**Every phase ends with a `HANDOFF.json`** ([handoff contract](handoff-contract.md)): standard canonical
outputs so any agent can continue at any phase by consuming them - never reinventing an upstream result
(e.g. the material split and its palette are consumed, not re-derived).

**Every texturing iteration passes the QA contract** before the owner sees it
([texturing QA](../../blender-high-low-baking/references/texturing-qa.md)): numeric checks
(`qa_textures.py`: no empty texels, no flat islands, class colours on target), the fixed shot sheet
(`qa_shots.py`: RTS, roofs, ridges, roof bottoms, corners, walls, base), the four-way diagnosis for any
unexplained defect, and the normal-stacking and material-consistency rules.

## Review deliverable after the freeze (standard, owner decision 2026-09-28)

Every bake or texture step from step 5 on is handed to the owner as a **live scene in the owner's
open Blender**, never as a single image. `blender-high-low-baking/scripts/review_scene.py` builds it
from the bake recipes (one config JSON per review, one call through the Blender connection):

- the FULL low model with the new maps (owners and members, as the game draws it) - the candidate;
- the previous or reference variant, the same way, beside it;
- the high-poly bake source (its own shader kept, so a bump variant is visible), beside them;
- identical grey clay with normal and AO (assembly x local), eave alpha, labels, one grazing sun;
- Material Preview with scene lights, framed on the tested area from the side it faces; file saved.

Publish a revision-scoped candidate with readback, preserving dirty live work.
Do not delete/rebuild the live scene as part of a combined call. Report file-verified
and live-verified states separately; if live verification fails, show background
evidence and name the pending live check. Desktop capture/control requires the
owner's explicit permission. Report the revision, scene and views to compare.

## After the freeze

Any UV change (a repack, a conjoinment rerun, a chart fix) first lists the bakes it
invalidates and confirms that this change is within existing authorization. Ask only
if that scope has not already been authorized. Then the affected recipes run again; nothing is re-set up by hand.
A bake master ([bake master](../../blender-high-low-baking/references/bake-master.md)) turns such a UV change into a derive (`derive_maps.py`, seconds to minutes, no HIGH loaded) instead of a rebake, as long as the LOW geometry contract and the HIGHs are unchanged.

**UV version switch checklist** (Korean TC S18f, 2026-09-28): a new version gets its own plan, freeze and
texturing LOW; ONE switch file names the active version for every script (`uv_version.json` / `uvver.py`),
never per-script path edits. Then every layout-bound input is re-derived - the list, not memory:
surface masks (POS/WN/EDGE/AOS/CLS), projected sources, ridge/part IDs, member audits, HIGH bakes of every
face that became an owner (NORMAL/AO/OPACITY/tile IDs, from its OWN high), and maps made OUTSIDE Blender on
the old layout (Painter AO read 1.0 under all moved charts - use a Blender building AO baked on the current
layout). Finish with the registration detector on the new plan and a same-camera owner-vs-member render.

Baking to a staging layout ("bank") is allowed as a pilot or as a source, but its move
into the pages is a planned transfer or rebake step, budgeted before the bank is made.
