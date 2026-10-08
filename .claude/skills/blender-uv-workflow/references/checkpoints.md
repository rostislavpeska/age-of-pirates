# Checkpoint contract v1

The operator layout was accepted on 2026-10-08 and extended on 2026-10-09 with
white texture-baked AO per model. The portable `blender-uv-observability` contract
is mandatory; this does not retroactively accept historical assets. Follow
[the AO handoff contract](ao-handoff.md) before final packing.

The existing phase handoff and asset revision store remain authoritative for files
and versions. A CHECKPOINT is evidence for a substep, not another asset database.

| ID | Owner checkpoint | Required check reports | Required visible evidence |
|---|---|---|---|
| geometry | 1 | coverage, geometry, attachments, mesh_budget | model, ground, attachments |
| clean | 2a | coverage, charts, continuity, stretch | model, checker, uv_sheet |
| materials | 2b | coverage, material_classes, protected_scope | model, materials, legend |
| share | 3a | coverage, families, correspondence, channels, protected_scope | model, families, uv_sheet |
| ao | 3b | coverage, ao_correspondence, ao_recipe, continuity | model, ao_white, ao_heatmap, families |
| freeze | 3c | coverage, overlap, density, page_budget, padding, source_detail, shared_mapping | model, checker, uv_sheet, ao_white |
| base | 4 | coverage, bindings, bake_contract, texture_qa | model, basecolor, normal, ao |
| details | 5 | bindings, texture_qa, protected_scope | model, details, player_color |
| game | 6 | source_binding, export_roundtrip, runtime_lint, installed_hashes, game_test | intact, destruction |

The `shared_mapping` report at freeze records integer counts `shared_face_count`,
`unmapped`, `incompatible`, `unbound`, `outside_cells`, `unreviewed_exposure` and
`coverage_errors`. All defect counts must be zero, including when a caller labels
the report PASS. A model with no shared resources supplies an actual empty census.
Extract UVs, physical classes and shader/image bindings from the saved mesh; pass
them to `scripts/shared_mapping.py`. A named matC slot or pointer in custom
properties is not an image binding. Visible shared surfaces are allowed when their
quality is reviewed; downward normals alone do not establish concealment.

Order is linear above. A new checkpoint consumes a predecessor receipt. Same-stage
iterations may consume the previous receipt of that stage. Geometry is the only
root. Importing historical acceptance means capturing its evidence honestly, not
writing fabricated PASS reports. A legacy/WIP asset can still be inspected or
repaired without a complete chain; it cannot claim a newly verified checkpoint.

Specification (paths relative to its own directory):

```json
{
  "schema": 1, "asset": "building", "revision": "content-id", "stage": "clean",
  "inputs": {"low": {"path": "candidate.blend", "sha256": "64 hex characters"}},
  "parent": {"path": "../geometry/CHECKPOINT.json", "sha256": "64 hex characters"},
  "checks": [{"path": "chart-report.json", "sha256": "64 hex characters"}],
  "views": [{"kind": "checker", "path": "checker.png", "sha256": "64 hex characters"}],
  "dispositions": {},
  "acceptance": {"scope": "clean", "evidence": {"path": "owner-message.txt", "sha256": "64 hex characters"}},
  "publication": {"level": "FILE_VERIFIED", "evidence": {"path": "readback.json", "sha256": "64 hex characters"}}
}
```

Each check report contains `check`, `status` (PASS/FAIL/INCOMPLETE/REVIEW), `asset`,
`revision`, `stage`, `inputs` (the exact role→hash dictionary), `validator` with
`name` and `version`, and a nonempty `metrics` object. Produce it from the measured
specialist output; the coordinator verifies provenance/structure, not the truth of
a self-written PASS. Required check names are fixed in code and cannot be dropped
from the spec. Unknown check names are rejected, except `advisory:*` reports, which
are visible but never block promotion. Required metric schemas stay with specialist
validators (e.g. the existing density floor and final handoff); no boolean wrapper
can replace those measurements. A missing metric block is INCOMPLETE.

Every report binds all checkpoint inputs. Changing geometry, UVs, materials,
recipe, policy or occluder data therefore requires new reports for that spec. For
fine-grained cache reuse make a separate scoped candidate/spec, not a stale report.

A REVIEW result needs a hashed disposition file keyed by check name. FAIL and
INCOMPLETE cannot be waived through that route. `acceptance` records the actual
owner message, scoped to this stage. This file validator does not authenticate
who wrote a message; project adapters must resolve the actual user message store.
Acceptance already supplied in chat is reused, never asked for again.

Publication evidence is JSON with exact asset/revision/input identities and a
matching `level` of FILE_VERIFIED or LIVE_VERIFIED. Live publication additionally
requires `session_id`, `scene`, and `readback_operation`. A saved-file receipt must
never be relabeled live. A render/owner acceptance is separate from publication.

`write` preserves an existing identical receipt but refuses replacement with a
different candidate. Use a new version directory. The receipt hashes its content;
`check` revalidates sources, reports, views, publication and ancestor receipts,
detecting cycles, tampering and missing ancestors. No approval is inferred from a
filename. `validate`/`write` return 2 for incomplete, 3 for failure, 0 for valid.

Final density and runtime ceiling are deliberately absent from `clean`. They are
mandatory at `freeze` and are also reevaluated by the existing final UV handoff
and export validators. `03_uv` stays WIP while only early checkpoints are accepted.

Views must be nonempty image files with the declared hash. This is a presence and
identity check, not visual quality judgment. Inspect them at readable scale; use
all models plus close-ups. Store a saved checker, deterministic family colors and
an ID lookup. Merely capturing a window is not proof of correct active UV bindings.
