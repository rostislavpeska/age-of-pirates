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

Use a source-bound manifest and a separate live readback. The small layout smoke
check in `../scripts/contract.py` consumes schema 2: model/resource census,
simultaneous visible copies, standard checker, black isolation errors, actual UV
and family correspondence errors, page policy and one exercised editor selection.
Schema 1 and the earlier three-mode workspace were rejected and are obsolete.
A successful render is not a substitute for editable data.
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

## Small smoke test and portable packaging

Run `python -m unittest discover -s <skill-root>/tests -v`, then
`python <skill-root>/scripts/contract.py <consumer-output>/OPERATOR_READBACK.json`.
These checks reject missing copies, separate scenes, custom checkers, non-black
excluded faces, wrong UV bindings, fake sharing and invalid project pages. They
consume measured evidence; they do not independently inspect Blender or prove
agent compliance. Capture the actual UI and exercise selection separately.

For a short fresh-reader test, give another agent only this skill and a consumer
profile. Ask for the copy count/layout for three models and four resources, black
isolation rule, profile precedence and disposition of fake family colours. Expect
21 simultaneous copies at the AO stage (18 before AO), excluded faces black, subproject overriding project and
rejection of colours without actual sharing. Record whether this reader ran;
unit fixtures alone are not an agent test. Use existing job coordination.

At AO review/freeze, schema 2 additionally requires an AO copy for each model,
baker identity, texture-baked status, source geometry coverage, actual bake hash and
allowed dimensions. Unique references cannot claim frozen shared AO or enter runtime
export. An early profile may request these copies before the AO gate. See
[AO handoff](../../blender-uv-workflow/references/ao-handoff.md). Historical 18-copy
receipts remain historical; they cannot satisfy the extended AO-stage requirement.

`resources.json` declares this package and the consuming skills declare it as a
required companion. An export missing it must fail dependency checks. No public
publication is implied. The Korean adapter is optional sample UI; restore it from
the saved Blender Text through the approved integration after reopening. Never
enable automatic Python execution globally as a workaround.
