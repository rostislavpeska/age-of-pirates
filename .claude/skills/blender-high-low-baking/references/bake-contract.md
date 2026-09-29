# Owner-map bake contract

`bake_owner_maps.py` now requires an explicit scope in pilot and production recipes.
This catches missing curved corners and unintended neighboring roofs before HIGH
loading or image allocation. Scope is intent: derive it from the semantic region or
approved face list, not from the same ray-hit/normal-axis heuristic being checked.

```json
{
  "only": ["L:10", "L:11", "L:12"],
  "scope": {
    "mode": "pilot",
    "regions": [
      {"id": "west-roof", "faces": ["L:10", "L:11"], "highs": ["Roof_HIGH"]},
      {"id": "window", "faces": ["L:12"], "highs": ["Panel_HIGH"]}
    ]
  }
}
```

Add this block to the existing recipe; the other bake fields remain unchanged.
Every face must be an owner on a declared source/page. Each belongs to exactly one
region. `highs` names objects already declared in the recipe's top-level HIGH list;
names must be unique across those libraries. Multiple HIGHs per region are allowed.
The baker creates separate receivers and selects only that region's allowed HIGHs.

The union of region faces must equal the actual targets selected by `only` (or all
eligible owners when `only` is absent). Missing, unexpected, duplicate and unknown
faces stop the operation; they are never silently dropped. A deliberately partial
pilot is valid when its declared scope is that subset. This is not a mandatory
whole-building bake, nor a rule that similarly named objects must be paired.

## LOW identity and production

The existing `freeze` protects loop UVs and page indices. It does not protect
positions, normals or triangulation. Record the companion LOW contract once the
destination data is established:

```text
blender -b low.blend --python bake_contract.py -- record recipe.json low_contract.json
```

Set `"input_contract": ".../low_contract.json"` in the recipe. The signature covers
positions, object transforms, loop vertex order/winding, evaluated mesh triangles,
smoothing and corner normals of the unmodified LOW mesh data (modifiers must already
be applied). It does not repeatedly hash HIGH geometry. Its exact float32 data is
version-sensitive: a mismatch stops and identifies stale inputs, not automatically
bad art. Investigate before intentionally recording a changed contract. Recording
current data alone does not establish visual approval.

`scope.mode = "production"` requires both `freeze` and `input_contract`. `pilot`
permits either to be absent, but always records the observed signatures. Expanding
scope requires explicit region/source decisions; removing `only` is not a valid
production shortcut. Each independently measured slope can have its own recipe.

Set `"preflight_only": true` to validate scope, signatures and receiver extraction
without loading HIGHs or baking. A passing run writes `preflight.json`; a normal
bake records the same data in `bake_report.json`. Preflight does not test HIGH-file
existence, ray coverage, final filtering or appearance.

## Receiver invariant

Extraction carries stable original FACE/CORNER IDs through BMesh deletion, transfers
the original split corner normals to the owned receiver and checks equality within
vector distance `1e-4` (Blender's custom-normal representation is quantized). Triangle
loop membership and winding must also match the original destination. An arbitrary
subset is permitted when these invariants hold. The original LOW is never changed
to make a receiver pass. The report retains the actual face order and the normal
error before/after restoration instead of assuming BMesh preserved ordering.

## Tested limits and inexpensive diagnosis

September 2026, Blender 5.0.1: the Korean west roof's dominant-axis selection omitted
two upturned corner faces. Completing 48 to 50 field faces removed both pale patches
without changing ray distances or UVs. The old incomplete receiver changed five
adjacent normals by up to 7.01 degrees. A synthetic bent two-face fixture now keeps
a one-face receiver's normals (before error .39018; restored error .0000359) without
editing the source. Whole-region control error remains zero.

`test_bake_contract.py <blender>` tests missing/unexpected/pairing rejection, explicit
partial pilots, production requirements, geometry/smoothing mutations, and receiver
normal/triangle preservation. `test_bake_owner_maps.py <blender>` also bakes the
existing owner/member, normal and opacity fixtures, with a closer unrelated HIGH
that must not contaminate the declared pair. Its invalid-scope case stops before a
deliberately missing HIGH file is loaded. These controls do not prove that a human
declared the right region or that sampled rays cover every texel.

For a new shading defect, a fixed-camera normal-only/normal-disabled ablation can
settle whether AO or color is relevant before another bake. Use it when causality is
unclear; do not repeat a full manual turntable for each local edit. Neutral unit
normals, a UV hash and successful bake execution are validity evidence, not complete
surface coverage or visual acceptance. Keep corner/edge checks and actual destination
shader/mip validation at the appropriate review milestone.
