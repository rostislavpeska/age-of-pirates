---
name: blender-uv-workflow
description: Coordinate architectural UV work through clean charts, material review, sharing, AO variants and final packing. Use for a multi-step unwrap or resuming it across agents; specialist skills perform the geometry and measurements.
---

# Observable UV workflow

Use one immutable candidate per step. Consume the accepted source and its handoff;
never choose a file by timestamp. Read [the checkpoint contract](references/checkpoints.md)
and run `scripts/checkpoint.py` before promoting a result. This validator checks
stage order, bound evidence and applicable gates; it does not itself inspect meshes.

1. **Geometry:** exact authored/protected/reference census, ground and attachment
   contracts, surface checks and budget. Use the geometry skill's accepted result.
2. **Clean charts:** use [blender-clean-uv](../blender-clean-uv/SKILL.md). Stitch
   adjacent surfaces into coherent charts; preserve editable UVs and per-run IDs.
   Show checker, chart colors, readable UV sheets and close-ups on every model.
   An unpacked worksheet may extend outside 0–1. Runtime capacity is not this gate.
3. **Material review:** show the same models by physical material class with a
   legend and exact per-face coverage. Consume the existing class attribute/palette.
   Classification does not authorize destructive object splitting.
4. **Sharing review:** [blender-uv-reuse](../blender-uv-reuse/SKILL.md) proposes
   correspondences; [blender-uv-conjoin](../blender-uv-conjoin/SKILL.md) applies them
   on a copy. Choose approximation per region, preserve approved chart boundaries,
   grain/role/normal/alpha/player-color compatibility. Show family colors and owner
   versus member checks before proceeding to AO. No blanket aggressive preset.
5. **AO review:** [blender-uv-ao-separation](../blender-uv-ao-separation/SKILL.md)
   tests corresponding points against the actual owner, with declared occluders,
   units, ray settings and seed. Prefer whole-chart variants; chart subdivision
   needs parent-child lineage and renewed continuity checks. Show mismatch heatmaps
   and the split families. Never infer A≈C just from A≈B and B≈C.
6. **Pack/freeze:** [aoe-uv-atlas-export](../aoe-uv-atlas-export/SKILL.md) packs a
   supported profile. Now enforce final density, page budget, mip-safe padding and
   accidental-overlap checks. The final `03_uv` handoff consumes this checkpoint.
7. Continue through base textures, details and the engine-specific export/game
   checks. See [bake dependencies](references/bakes-and-recovery.md) for permitted
   intermediate bakes and reusable masters.

Declare runtime budget and vanilla quality references upfront. Measure fit after
sharing and AO, never silently shrink charts to satisfy an early estimate. Keep
coverage/density correctness separate from sharing percentage and packing advice.

Every checkpoint has fixed views, actual editable data, source identity, machine
reports and scoped owner acceptance. A background result is FILE_VERIFIED, not
LIVE_VERIFIED. Preserve unsaved live work; use connectors. No desktop fallback is
authorized here. Color legends distinguish chart IDs, materials, sharing and AO.

Use `checkpoint.py validate SPEC.json`, then `write SPEC.json --out CHECKPOINT.json`.
`check CHECKPOINT.json` revalidates hashes and upstream receipts. `summary` produces
readable status from a receipt; do not maintain an independent version pointer.
Evidence files belong in the project's scratch/output area, not this package.

Bound each hypothesis to a pilot and one evidence-driven revision by default.
Validate every variant; retain a better parent. When inputs are unchanged, reuse
hash-verified reports; when they change, invalidate only dependent results. Missing
evidence is INCOMPLETE, a failed experiment stays visible, and a timeout is UNKNOWN.
Record confirmed lessons with the shared journal. Run the bundled failure fixtures
with `python -m unittest discover -s .claude/skills/blender-uv-workflow/tests -v`.
