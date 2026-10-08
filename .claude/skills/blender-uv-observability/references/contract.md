# Operator contract and research

Owner correction, 2026-10-08: all UV work must be understandable and observable
in Blender: density, concrete materials and conjoined island families. A single
checker image beneath UVs outside its extent failed that requirement.

## Evidence boundary

The workflow orchestrator owns phase order and acceptance. Clean UV owns chart
continuity/stretch; hidden-surfaces owns visibility evidence; material allocation
owns physical class and texture destinations; conjoin owns correspondence; AO
separation owns shadow variants; final packing owns runtime fit and density.
This interface consumes their results. It must not silently invent their passes.

Use a source-bound manifest and a separate live readback. Required readback fields
are implemented in `scripts/contract.py`: revision, model census, mode readiness,
page size, selected scope, active/editor/shader UV identity, image identity,
out-of-canvas loops, pixel-coordinate conversion error, density values and sharing
owner/member counts. A successful render is not a substitute for editable data.
Fail on missing or stale evidence. Keep `pending`, `file_verified`, `live_verified`
and `owner_accepted` distinct. Recheck affected evidence after mutation.

Before conjoin, the sharing mode is explicitly pending. This can pass an early
operator-view check; it cannot pass a sharing checkpoint. Material readiness is
similarly stage-dependent. Each failed attempt has an immutable log and source
identity; never overwrite the previous attempt with a successful retry.

## Research applied

- [Anthropic, Effective harnesses for long-running agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents)
  (2025-11-26): incremental work, durable state and end-to-end verification address
  premature completion and lost context. Applied here as bounded UV revisions and
  actual operator-path checks, not a request to spawn extra agents.
- [OpenAI, Harness engineering](https://openai.com/index/harness-engineering/)
  (2026-02-11): repository knowledge and mechanical checks make agent work more
  inspectable. Applied as executable binding/coverage tests rather than additional
  repeated instructions.
- [Blender UV Map API](https://docs.blender.org/api/4.5/bpy.types.ShaderNodeUVMap.html)
  and [UV Map node manual](https://docs.staging.blender.org/manual/en/latest/render/shader_nodes/input/uv_map.html):
  shader UV selection is explicit and separate from editor presentation. Verify
  against the installed Blender API; the staged manual may describe a later version.

These sources support the design principles, not proof that this implementation
is correct. Test the implementation against the current asset and negative cases.
