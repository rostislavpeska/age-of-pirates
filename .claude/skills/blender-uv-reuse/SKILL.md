---
name: blender-uv-reuse
description: Find geometry-based UV sharing candidates, validate AO and texture-channel compatibility, and optimize atlas space with explicit density and memory budgets. Use after clean chart authoring for stacking, mirrored parts, trim reuse and economical packing.
---

# UV reuse and space optimization

Use [the shared UV workflow](../blender-uv-workflow/SKILL.md) for stage order,
evidence and bounded recovery. Candidate discovery can be planned early, but apply
sharing after clean-chart/material review. Preserve persistent parent/member IDs;
any semantic chart subdivision requires renewed continuity evidence. Show the
sharing checkpoint separately from AO and final packing.

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

A composite facade may be refined at **physical panel/material boundaries** when
its enclosing frame wrongly blocks reuse of complete repeated panels. Preserve
the parent chart ID and untouched frame UVs; join adjacent coplanar same-material
panel faces into one region before matching. This is a semantic refinement, not
per-face fragmentation. See [reuse relations](references/reuse-relations.md).

## Workflow

1. Freeze the source revision, chart IDs, face membership, verified scale, density
   classes, target pages and unique bake coordinates. Preserve this baseline so
   candidates can be evaluated independently without overwriting shared texels.
2. Read [geometry matching and compatibility](references/matching-and-budget.md).
   Discover candidates from coherent geometry, including opposite roof sides and
   repeated modules. Cheap signatures shortlist; measured correspondence decides.
   Record mirrored candidates separately because tangent handedness matters.
   Run the geometry matcher on current owners before declaring sharing complete;
   a caller's UV rectangle or exact UV hash must not bypass it. For every large
   unique region report a geometric mismatch, a named compatibility constraint
   or an unresolved candidate. Use `transfer_corresponding_uv` for complete
   face/corner transfer when original UV layouts differ. Choosing a larger-area
   owner does not guarantee both density axes: check each after transfer.
3. Deliver a candidate report before bulk stacking: same-color physical pieces
   and chart outlines, owner/member IDs, transform/correspondence, residuals,
   potential area saved, and specific rejection or unresolved reasons. Distinguish
   filled surface area from reclaimed chart envelopes and measured packed size;
   hollow frames can keep the same large footprint after their panels share.
   Test complete frames as well as panels. A geometry
   match is a **candidate**, not a passed AO/material test.
4. Validate normals/tangents, color/grain, opacity, masks and unique ornament.
   Apply the provisional geometry/material/role sharing checkpoint first, with AO
   marked pending. Then test AO in those saved families and split differing contact
   contexts into variants. AO must not veto the first phase. Test each member
   against its actual owner, not transitive chains. Follow
   [the two-phase contract](../blender-uv-workflow/references/sharing-and-capacity.md).
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

- [Whole-chart geometry sharing](scripts/geometry_share.py): a provisional
  geometry-first correspondence solver. Material/valence counts and measured 3D
  invariants shortlist; polygon boundary correspondence, rigid/reflected fits and
  normals decide. Existing UV signatures never veto geometry discovery. Transferring
  owner coordinates must preserve per-face texel density within the declared
  tolerance. UV residual/reflection is reported for later channel review. It never
  fits a geometric scale or packs. Different mesh topologies still stay unique.
  See [the geometry-only handoff](references/geometry-only-handoff.md) and run
  `python -m unittest discover -s scripts -p 'test_*.py'` from this package.

- [Planar surface experiment](scripts/planar_share.py): whole planar material
  regions can share despite different internal edge counts. Fits a rigid/reflected
  surface map, checks both density axes and compares material-ID raster images at
  two resolutions and phases. Requires NumPy and Shapely 2.x. This is an
  experimental extension, not an approved replacement for the strict matcher.
  See [three-method evaluation](references/three-method-evaluation.md) for its
  limits, tolerances and the geometry-only review gate. Image similarity alone
  never authorizes a match; curved patches still use the strict correspondence.

- [Semantic regions](scripts/semantic_regions.py),
  [partial curved-surface reuse](scripts/partial_surface_share.py), and
  [bounded rectangle proposals](scripts/scaled_rectangle_share.py): experimental
  extensions for composite walls, trimmed opposite roofs, integer-fraction
  rectangles and small generic-material scaling. Exact, mirrored, partial and
  scaled are recorded separately; a partial match can also be mirrored. The
  scaled helper proposes candidates only. User visual acceptance is pending.

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

The complete AO/channel/packing solver is not implemented or approved. Geometry
sharing has a bounded helper and measured building candidate, not a guarantee
of finding every valid match. Store new
matching code as reusable helpers with tolerances and reproducible reports; test
one equal module, one false shape match, one AO-conflicting match and one mirrored
normal/alpha case before applying that implementation to a whole set.
