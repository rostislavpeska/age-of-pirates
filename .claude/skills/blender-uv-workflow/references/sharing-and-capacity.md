# Two-phase sharing and capacity decisions

This is the coordinator's protocol, not another matcher or version registry.
Use the existing HANDOFF, checkpoint, conjoin, AO and density implementations.
Keep project-specific targets in the project plan; read numerical universal floors
from the density skill's JSON, never duplicate them in scripts.

## 1. Material and visibility handoff

Publish all models by physical material, then by runtime resource. Those are two
different inventories: six physical classes can sample one runtime page. Count
actual assigned material slots, distinct material definitions and texture paths;
do not report the intended three bindings while eleven are still assigned.

Route approved concealed/backing surfaces out of the unique detailed page into
compatible shared cells. Preserve geometry needed for destruction. Direction alone
does not prove invisibility or material compatibility. Record an unresolved cell as
PENDING, with face count and estimated capacity cost; do not silently put stone on
a wood cell or pretend pending storage costs nothing. Preserve existing prop UVs.
Count shared textures once in incremental asset cost and also disclose total
referenced resources; repeated references are not repeated disk copies.

## 2. Aggressive sharing, before AO

Start from clean coherent charts, stable IDs and the approved material handoff.
Search all repeated beams, panels and similar eligible shapes under the owner's
key: **same physical material + compatible shape + same functional role**.
Preserve scale unless a separately declared density/approximation change allows
it. Record grain, normal orientation, alpha, ornament and tile pitch/phase constraints.
Identical plain timber can share; a beam end cannot inherit its long-side grain.

AO/context differences are PENDING at this stage, not a rejection reason. Save
the maximal compatible proposal produced by the bounded search, owner/member
correspondence and reasons for remaining unique charts. A matcher is not a proof
that no further sharing exists. Preserve the unique bake coordinates and baseline.
Show a separate pre-AO family view and every UV resource. Do not bake overlapping
members into one image or claim production compatibility.

## 3. AO split, after the sharing checkpoint

Consume those exact parent families and their maps. Compare each member against
its actual owner at corresponding points using the recorded occluders, units,
radius, sample scheme and seed. Missing evidence means unknown, not compatible.
Use the AO skill's calibrated recipe, not a new arbitrary threshold.

Keep compatible members together. Split incompatible members into AO variants
inside their original family. Reusing `conjoin.families` requires partitioning by
that parent first and preserving geometric correspondence; a fresh global pass
is a different sharing revision, not this AO step. Every child records its parent
and complete face coverage. Whole-chart variants are the default. A localized
contact can justify a coherent interior/contact-region split with explicit lineage
and new continuity checks; it never justifies per-triangle fragmentation.

Report changed owned area and padding, not just the number of variants. Verify
the shared result against a unique-texel AO reference at matched views. Geometry,
occluder or correspondence changes invalidate the dependent AO evidence. Reuse
only measurements whose inputs still match, not an old UV-bound bitmap by name.

## 4. Capacity before expensive work

Separate these quantities in the handoff:

- Page capacity and new versus shared texture bytes by channel/mips/compression.
- Owned surface area, owner envelope waste, packing loss and padding.
- Pending backing storage, unresolved unique content and AO-created area.
- Working density targets and the universal rejection floor.

Area scaling is quadratic: a 0.90 linear density factor uses 0.81 times the surface
texels. Fixed-width gutters do not scale that way. Apply calculations per eligible
class; retain protected text/windows or other owner-protected targets. This is a
capacity estimate, not evidence of a new UV layout, visual quality or packability.

Before full AO, use a representative contact/clear-surface pilot when existing
evidence is insufficient. Report estimated AO area growth as a range with its
provenance, or explicitly UNKNOWN. Stress scenarios are not guaranteed bounds.
Choose an advisory reserve from that evidence. Do not invent a universal reserve
percentage that becomes a new blocking gate. Keep some capacity uncommitted until
the actual AO children and their gutters are measured.

Only attempt bounded packing when the measured demand can plausibly fit. A lower
area sum does not prove a rectangle/bin fit. Never launch repeated packers against
unchanged impossible inputs. One pilot and one evidence-driven revision per
hypothesis is the default; stop with the measured trade-off if there is no gain.

## 5. Density decisions and approval

Read the [density policy](../../blender-architecture-texturing/references/uv-density-floor.md).
A universal floor is a rejection threshold, not the desired density for every
surface. Lowering that threshold does not change any saved UVs. Changing working
targets is a separate recorded operation with measured per-class and weak-axis
results, matched close-ups and source-detail checks.

An owner-authorized modest target change may be explored above the floor without
another approval question. If a measured model/texture fails the revised floor,
prepare a concrete proposal with model, exact pages/dimensions, candidate identity,
measured deficit, expected saving and visible comparison. Then obtain the owner's
explicit GO for that proposal using the density tool's verified approval contract.
General permission to reduce the floor is not permission for a below-floor asset.
Silence, a question, HOLD, refusal, another model/page or an older candidate is not GO.
Incomplete measurements and other failing gates cannot be waived through density.

## 6. Observable checkpoints and enforcement limits

Deliver material/backing review, pre-AO sharing, post-AO variants, then final packed
UVs as distinct results. Each uses all models/resources, readable sheets, matched
family/material/checker views and the standard review packet. Preserve the prior
candidate. Read back active/editor, render and shader UV bindings on publication;
saved-file evidence alone never becomes live verification.

Existing checkpoint tooling validates sequence, hashes, report presence and
publication identity. It does not inspect meshes or authenticate arbitrary
self-written PASS reports. The specialist density validator enforces numerical
floors and scoped approvals. Automated semantic checks for parent-family-only AO,
runtime-binding census and capacity provenance must be supplied by the producing
tools; until implemented and tested, label those checks manual/evidence-reviewed.
Do not claim that editing these instructions implements those future gates.

Evidence: Korean military KTC-176, 2026-10-06; INC-086 (actual materials), INC-087
(AO veto applied before aggressive sharing), INC-088 (WIP resume), INC-089
(approval validation). These failures motivate stage-specific checks rather than
more generic rules or another orchestrator.
