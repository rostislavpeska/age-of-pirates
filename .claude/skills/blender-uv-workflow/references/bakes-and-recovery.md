# Bakes, invalidation and bounded recovery

| Product | Can precede final pack? | Dependencies |
|---|---|---|
| AO measurements | Yes, after chart/material review | LOW, transforms, correspondence, occluders, alpha policy, radius/units, rays/seed |
| Pilot | Yes, one representative region | LOW/HIGH, cage, normals, exact region and recipe |
| Bake master | Yes, after local geometry/detail freeze | LOW/HIGH contract, recipe, adequate unique source density and coverage |
| Runtime bake/derive | After freeze | Frozen UV + normal/tangent contract, owner map, master or HIGH, final recipe |

Use [the existing bake master](../../blender-high-low-baking/references/bake-master.md)
when expected reuse justifies its up-front cost. It stores finite-resolution source
data, not lossless infinite detail. Apply its measured error/coverage tests and
source-density checks; derive tangent normals in the final tangent frame. Local
AO and assembly AO have different invalidation dependencies. A moving occluder
invalidates assembly AO even when the receiving mesh does not change.

Before changing a frozen layout, enumerate affected maps and scoped authorization.
An already authorized UV change does not need repeated permission. Keep source and
candidate separate and regenerate/derive the affected outputs through saved recipes.

Record an operation ID before publish/bake/export. A lost reply means UNKNOWN,
not success and not proof of failure. Reconcile durable output, its input hashes,
current target and readback before retrying. Do not repeat append or bake blindly.
The asset revision service owns publication and rollback; this skill adds evidence
contracts, not a second publisher. Cached results are usable only with identical
inputs, policy and relevant tool version, and intact output hashes.

Profile choices and visual reasoning may be agent-driven. Coverage, protected
scope, channel compatibility and measured tolerances are deterministic. A bounded
trial may fail; show its evidence, keep the better parent and record the lesson.
