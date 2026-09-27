---
name: blender-uv-reuse
description: Find geometry-based UV sharing candidates, validate AO and texture-channel compatibility, and optimize atlas space with explicit density and memory budgets. Use after clean chart authoring for stacking, mirrored parts, trim reuse and economical packing.
---

# UV reuse and space optimization

This skill owns **geometry candidate discovery, compatibility decisions and atlas
economics**. Begin with the inspectable baseline from
[clean UV authoring](../blender-clean-uv/SKILL.md). Do not hide broken charts or
foldovers by stacking them. Plan reuse families early; apply shared coordinates
only after compatibility is established.

An explicitly requested **geometry-only checkpoint** may apply candidate stacks
in a separate scene before AO/channel validation. Label them provisional, retain
the unique baseline UV layer, preserve chart scale and owner placement, and leave
freed space empty. Do not pack, bake AO or call the stacks production-compatible.
Whole coherent charts are the matching unit; do not cut them into triangles or
smaller matching scraps just to increase reuse. For hidden backing, an explicit
material-only policy may allow arbitrary overlap inside distinct family cells.
That exception must never spread to visible detailed charts.

## Workflow

1. Freeze the source revision, chart IDs, face membership, verified scale, density
   classes, target pages and unique bake coordinates. Preserve this baseline so
   candidates can be evaluated independently without overwriting shared texels.
2. Read [geometry matching and compatibility](references/matching-and-budget.md).
   Discover candidates from coherent geometry, including opposite roof sides and
   repeated modules. Cheap signatures shortlist; measured correspondence decides.
   Record mirrored candidates separately because tangent handedness matters.
3. Deliver a candidate report before bulk stacking: same-color physical pieces
   and chart outlines, owner/member IDs, transform/correspondence, residuals,
   potential area saved, and specific rejection or unresolved reasons. A geometry
   match is a **candidate**, not a passed AO/material test.
4. Validate all channels that share the UV set: AO, normals/tangents, color/grain,
   opacity, masks and unique ornament. Keep differing contact contexts as variants
   when errors exceed the declared limit. Test entire proposed groups, not just
   transitive chains of similar pairs.
5. Pack verified owners and unique variants, then assign member coordinates. Bake
   each owner/variant once with the intended occluders; never bake all overlapping
   members sequentially into the same image. Revalidate coordinates and final maps.
6. Report content and gutter costs, padding/mip behavior, two-axis density and
   actual destination texture memory. Repeat the clean-UV skill's three views,
   actual sheets and live editor check on the optimized revision. Keep budget,
   visual approval and runtime validation as separate results.

## Controlled compromises

First reduce redundant surface ownership; then improve chart composition and
packing. If the budget still fails, propose named detail classes, tolerances or
variants. Quantify their visible error and space savings before changing them.
Do not silently lower all density, enlarge runtime sheets, discard alpha detail
or turn per-face tiling into the visible architectural layout.

Small disconnected ridge ends may share a compatible library patch without being
stitched to a beam. A connected beam should use a continuous strip where topology,
hard edges, grain and distortion permit. Tiny-patch gutter cost matters. Keep a
debt entry for human-editable strip straightening and small-part legibility when
accepted for later refinement; approval does not make them resolved.

## Existing tools and limits

- [Geometry/context helper](../blender-architecture-texturing/scripts/blender_hybrid_uv.py):
  conservative matching, not a complete correspondence or AO-equivalence solver.
  Its context mismatches have false negatives; they do not prove uniqueness.
- [AO constraints](../blender-architecture-texturing/scripts/ao_chart_constraints.py):
  scalar group range/error tests, not normal/alpha or geometric certification.
- [Blender AO review](../blender-architecture-texturing/scripts/blender_ao_review.py):
  isolated unique-owner baking; receivers must exclude overlapping members while
  retaining intended assembly occluders.
- [UV metrics](../blender-architecture-texturing/scripts/uv_metrics.py): density
  and rectangle packing; neither establishes architectural chart quality.

The matching specification is a reusable process, not a claim that the complete
automatic solver has been implemented or passed on the full building. Store new
matching code as reusable helpers with tolerances and reproducible reports; test
one equal module, one false shape match, one AO-conflicting match and one mirrored
normal/alpha case before applying that implementation to a whole set.
