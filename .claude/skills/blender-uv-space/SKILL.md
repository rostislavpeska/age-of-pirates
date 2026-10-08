---
name: blender-uv-space
description: Measure texture-space use at destination pixel resolution and improve UV packing without breaking chart families, density or sampling margins. Use for wasted atlas space, thin/hollow charts, packing comparisons and fixed texture budgets.
---

# UV space efficiency

This skill owns pixel accounting and packing experiments. It consumes clean charts,
material ownership and sharing families; it does not replace unwrap, reuse, AO or
the [operator contract](../blender-uv-observability/SKILL.md). Read
[the research and decision rules](references/research.md) before selecting a method.

## Fixed inputs

Use the consumer's explicitly agreed model scope, owned page count/dimensions,
shared atlas identity/cells, density classes, permissible rotations and reuse.
Preserve the current source. Diagnostic pages use the SAME UVs and dimensions.
Keep existing textured dependencies fixed; do not repack their cells or allocate
a replacement page. Owner agreement persists; do not repeatedly ask for it.

## Account for every pixel

Run `scripts/pixel_audit.py INPUT.json --out DIR` on actual destination UVs.
Input uses pixel coordinates, one entry per unique owner/variant, all polygons of
that owner together. Valid stacks count once, not once per member. The script
cannot certify sharing compatibility; the input must come from the sharing plan.
Show its image and counts for surface content, the declared padding band, and
unallocated pixels. They must sum to the whole page. Also report geometric area,
cross-owner overlap, tiny/subpixel charts, and the largest empty chart envelopes.

Raster counts are at pixel centres with closed boundaries; padding uses a stated
integer square dilation. This is a reproducible sampling diagnostic, not proof of
all GPU filtering footprints. Exact polygon distance and channel/mip tests remain
separate. Never rename bounding-box occupancy or overlapping face-area sum as
useful content. Shared dependency occupancy is not newly allocated owned cost.

## Improve in order of measured benefit

1. Remove unnecessary unique ownership through existing compatible atlas cells,
   repeated modules, trims and cross-model families. Use
   [reuse](../blender-uv-reuse/SKILL.md) and
   [conjoin](../blender-uv-conjoin/SKILL.md); preserve material, role, grain,
   tangent, alpha and player-colour correspondence. AO variants follow later.
2. Rank hollow/thin charts by empty envelope pixels and gutter cost. Keep coherent
   charts. Try concave nesting before cuts; a connected strip may be straightened
   only with measured two-axis stretch and surface continuity. Never collapse a
   curved chart to a line or chop it into triangles to inflate a packing score.
3. Compare the retained layout, a rectangular packing baseline and an outline-aware
   candidate at the SAME scale, margin and page constraints. Large subtype shelves
   are not mandatory; subtype identity can travel with chart masks/IDs. If grouping
   is required for painting, quantify its cost separately.
4. Pack only owners and unique variants. Keep disconnected pieces of one semantic
   owner locked. Verify one proper rotation/uniform-scale/translation per owner;
   propagate it to every member through existing correspondence. No repacker may
   silently split a family, re-unwrap, reflect or change individual density.
5. For an authorized density revision, report it explicitly. Compare both fixed
   density space savings and best validated density in the agreed pages. Keep
   necessary padding, final page bounds and existing dependencies fixed. A failed
   heuristic does not prove infeasibility; a successful one does not prove optimality.

`scripts/pack_masks.py` is a bounded, deterministic outline-aware experiment.
It preserves full owner groups and only uses declared multiples of 90 degrees.
Its conservative coarse raster is followed by exact polygon validation; it is
not a proof of a globally optimal packing. Consumer scripts must additionally
verify UV/member correspondence, real density, chart orientation and live copies.
Use a finite scale list/time budget and retain the best validated parent on failure.

## Accept a candidate only with evidence

Before a dependent edit: save, reread actual UVs, remeasure useful content and
density, check bounds/overlap/gap, preserve chart/material/family and geometry
census, and verify attachment world transforms. The three House poles regression
demonstrates why object names and closed topology alone are insufficient.
Publish actual UV sheets plus checker, resource isolations and family views via
the operator contract. Log failures and distinguish file verification, live
readback, visible delivery and operator acceptance. AO/mip readiness can remain
explicitly pending in an authorized WIP; no final freeze while they fail.

Every unused pixel should have an explanation or an optimization candidate.
Do not promise zero unused pixels or remove safety margins to claim 100% use.
Do not report credit-card or memory savings merely from filling a fixed-size page:
allocation falls only when page dimensions/count/channels/formats actually change.

Smoke tests: `python -m unittest discover -s .claude/skills/blender-uv-space/tests -v`.
