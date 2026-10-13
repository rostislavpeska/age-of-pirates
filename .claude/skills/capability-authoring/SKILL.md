---
name: capability-authoring
description: Create or extend reusable workflows after a tool gap, correction or repeatability request. Assign generic mechanics, project style, set parameters and asset recipes to their existing owners.
---

# Capability ownership and automatic upkeep

Use this during the work, without waiting for a separate documentation request.
Extend the existing owner of a capability before creating another implementation.
Follow [workflow-journal](../workflow-journal/SKILL.md) for discovery, failures and
measured or explicitly unknown usage. This skill does not authorize new art,
paid services, deployment or changing an approval requirement.

## Decide where the knowledge belongs

| Question | Owner | Examples |
| --- | --- | --- |
| Would this operation still be needed for another culture, project or finish? | Generic skill in the canonical skill library | Find ridge/hip/valley from geometry; sweep a cross-section; bake; compare both sides of a UV seam; derive masks; preserve alpha |
| Does it select the visual construction or reference language of this project? | Consuming project's guidelines | Korean ridge form, tile proportions, valley style, source collection |
| Does it vary with a concrete set/age within that project? | Set/subproject profile | Colonial grey; Industrial aqua glaze; ridge colour, selective gold, weathering parameters |
| Does it identify one asset, exception, accepted revision or installed output? | Asset recipe, selector and handoff in the consuming project | Frozen mesh/UV hashes, receiver dimensions, exact map bindings, permission for a local geometry change |
| Is it an attempted method or a failure? | Existing journal/incident plus immutable evidence | Rejected one-sided valley, failed full replay, missing paired-face coverage |

Keep one editable definition. Entry skills and indexes link to it. Historical
records remain evidence, not competing instructions. Project/set cards are not
additional skill installations. The repository maintainer defines the physical
roots; never create a personal mirror. Reuse across Korean/Japanese/Chinese work
does not make their styles interchangeable: promote only demonstrated common
mechanics, with separate project profiles.

## Automatic actions

1. **Before code:** search the named capability, tools and accepted recipes in
   bounded locations. Record reuse/extension/gap and a test/stop condition before
   new code, including scratch code. Inspect the actual implementation, not just
   a skill title. Missing discovery is not proof that the capability is absent.
2. **If an existing capability fits:** use it; fix its missing integration or
   reference at the source. Do not create another skill for the same operation.
3. **If a real reusable capability is missing:** create a focused skill when its
   purpose and ownership are clear. Describe inputs, outputs, callable tools,
   limitations and verification. An unimplemented requirement stays explicitly
   pending; a written algorithm is not a working tool. Do not create empty
   directories, speculative frameworks or a separate tracker.
4. **If the gap is project/set-specific:** update that card/profile and its
   existing index automatically. Record new observations as measured, proposed,
   rejected or accepted with their evidence. A failed experiment updates the
   failure case immediately; it does not become a production default.
5. **On a confirmed correction/failure:** update the owning rule and add a
   regression to the existing test suite when executable behaviour is affected.
   Preserve the negative specimen. Do this before the next dependent rollout,
   rather than requiring the owner to report the same defect on another asset.
6. **On completion:** verify links/dependencies, run relevant existing checks,
   save scoped changes and leave remaining implementation gaps in the existing
   task system. Do not claim automatic software enforcement merely because an
   agent instruction now exists.

## Repeatable and tunable

### A workflow must name its deliverable

Choose the smallest operation that satisfies the request. Record allowed edits,
the affected asset/stage, the executable steps and the visible output expected.
A diagnostic can finish without finishing an asset. A failed method does not
authorize changing UVs, geometry, providers or the assignment. Show the specific
conflict and a bounded alternative before expanding the requested scope.

Keep the following in the consuming asset's existing recipe/handoff, rather than
introducing another tracking format:

- Input identities: mesh, UVs, normals, bindings, maps, masks and current approval.
- Scope: selected physical regions and all affected readers; allowed channels;
  protected pixels, geometry and states.
- Execution: actual commands, ordered stages, tool/code versions, parameters with
  units, seeds, coordinate frames, sampling and colour/normal conventions.
- Outputs: fresh destinations, hashes, stage receipts and dependent stages to
  invalidate when a relevant input changes.
- Evidence: required checks, comparison views, known failures and the exact
  acceptance/delivery condition. Reuse the existing handoff schema where present.

Manual selection can be a reproducible input: save its face/edge identities and
physical correspondence against the source fingerprint. Do not require automatic
discovery before a bounded manual workflow can be demonstrated.

Report evidence separately: **implemented**, **fixture-tested**, **executed on a
real asset**, **replayed from pinned inputs**, **transferred to a second asset**,
**visually accepted**, **delivered**, and **runtime-verified**. Each claim names
its specimen and scope; these are not interchangeable or a new universal enum.
An end-to-end repeatability claim requires a complete scoped replay and a second
specimen using the same interface. Do not rerun unchanged proofs merely to raise
test counts. Documentation describes requirements; it does not enforce them.

### Skill discovery and description quality

Extend the existing owning skill when the operation and inputs already fit it.
Create a new skill only for a distinct reusable operation with a clear boundary,
callable implementation and demonstrated need. Keep the default route short;
load detailed procedures only for the selected mode. Asset-specific recipes and
failure histories stay with their project, with links rather than copied rules.

A description should state the operation and when it applies in one or two clear
sentences. Include a boundary only when it prevents likely misrouting. Move tool
inventories, examples, historical stories and detailed parameters into the body
or a relevant reference. Describe implemented capability accurately: a declared
edge mapper is not automatic valley discovery, and a diagnostic is not a repair.
Preserve existing names and discovery paths unless a rename is necessary.

Scope each blocker to named artifacts and dependent stages. A metadata failure
blocks the affected publication; a bake failure blocks that bake's consumers;
an approval hold blocks promotion of that candidate. Record independent useful
work separately and continue it where authorized. Do not interpret a local hold
as permission to waive it, or as a global stop. Before pausing an unattended run,
account for every remaining authorized task and use the overnight-session pause
gate. An unknown task state is not evidence that no useful work remains.

Separate structural pattern, base material transfer, surface effects and runtime
encoding. Keep each stage's inputs, masks and outputs identifiable. A method
records tool/version, source and code hashes, complete parameters and units,
seeds, processing order, resampling, colour spaces, normal conventions, scope,
protected readers, compression and known limitations.

Snapshot/hash the executable source before launching concurrent work. A copy
made after the run may contain another worker's edits; compare its hash with
the execution receipt before calling it replay provenance. Retain a mismatch
as a source-closure gap without discarding independently verified outputs.

Replay into an empty output location against a pinned accepted specimen before
claiming reproducibility. Require exact output identity where deterministic;
declare justified tolerances before running otherwise. Reopening or re-exporting
a saved project proves only that stage. Compare local regions and matched views;
an atlas-wide average cannot certify seams, moss or readable relief.

An accepted baseline is a **quality floor**, not a permanent ceiling. Keep
parameters editable and effect providers replaceable through the same channel
and mask contract. A proposed improvement branches from the immutable baseline,
states its hypothesis and cost, and receives a bounded comparison. Record the
owner's approval before promoting it where approval is required. Do not silently
substitute a new method or accumulate adjustments on previously derived output.

Validate package closure with [skill-library-audit](../skill-library-audit/SKILL.md).
Static package checks, successful execution, visual acceptance and deployment
are different evidence. Public export remains separately authorized.

## Efficiency without weakening quality

Measure computation, tool/discovery overhead, waiting and review separately.
Materialize compressed array inputs once before per-face loops; use bulk native
attribute reads where supported. Enforce the declared deadline in code, not only
in prose. Verify optimized output against the preserved baseline before claiming
a gain; one fast diagnostic does not establish a whole-pipeline speedup.

Reuse stage outputs only when every relevant input identity matches: geometry,
UVs, normals/tangents, bindings, resolution, cage, parameters, seed and tool/code
version as applicable. Appearance-only changes can reuse unchanged structural
maps; geometry/UV/cage changes invalidate the affected maps and downstream work.
Keep alpha/readers, state parity, compressed mips and visual checks. Batch source
discovery and publication per useful deliverable; do not repeat a full-library
verification while another verified coordinator-owned check already covers it.
No new generic cache controller is implied by these rules: report its actual
implementation and replay status in the consuming workflow.
