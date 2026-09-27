# Geometry correspondence, compatible sharing and space cost

## Geometry first: candidate discovery

Match coherent charts or named surface modules, not arbitrary tessellation
triangles. Preserve adjacency and semantic intent from clean UV authoring.
Use area, edge-length distributions, boundary loops, topology and curvature to
shortlist candidates. Equal bounds, area or a shape hash alone is not proof.

Establish an explicit surface correspondence c and transform T from owner to
candidate in verified world units. For a rigid match T(x) = R x + t, require
R-transpose R = I. Report det(R) = +1 for rotations or -1 for reflections; reject
unrecorded scaling. With characteristic length L, declared absolute and relative
tolerances, test at corresponding vertices and surface/boundary samples:

    position_error = max ||T(p) - c(p)||
    position_limit = absolute_tolerance + relative_tolerance * L
    normal_error = max acos(clamp(dot(R*n_owner, n_candidate), -1, 1))

Require preserved boundary/interior coverage, local lengths/angles and orientation,
not just nearby samples. Include curvature and protected silhouette points. A
sampled result is not an exact whole-surface certificate. Congruent mesh topology
helps construct correspondence; different tessellations need surface matching,
not automatic rejection. Reflection also needs the tangent-handedness checks below.

Differently sized modules may share a **metric subregion or trim** when grain,
normal/alpha coverage and shading agree. Record the covered domain and transform;
do not stretch a whole motif nonuniformly to force a match. Repeated patterns do
not permit unique text, ornaments or contact shadows to be mirrored unnoticed.

Keep a deterministic candidate manifest: source revision; persistent chart and
member IDs; owner; correspondence and transform; tolerance profile; position and
normal residuals; coverage; reflection flag; density; AO context; channel results;
potential saving; decision and reason. Stable ordering/tie-breaking keeps reruns
comparable. Separate discovered, geometry-passed, shading-passed and applied states.

## AO and other channel compatibility

Independently evaluate/bake each candidate in its own valid target. Use the same
linear ambient-visibility convention (0..1), radius, sidedness, occluder scope and
sampling. Compare corresponding surface texels, excluding gutters/background.

For required AO a_i(t) of each member i at texel t:

    range(t) = max_i a_i(t) - min_i a_i(t)
    smallest_possible_worst_case_error(t) = range(t) / 2
    minimax_shared_value(t) = (max_i a_i(t) + min_i a_i(t)) / 2

For allowed error e, sharing is feasible only if range <= 2e at every protected
texel. If the chosen shared bake is an existing owner, also measure its actual
error against every member: it need not achieve the minimax bound. A group passing
the mathematical feasibility test can still fail with a poorly chosen owner map.
Report peak error and affected coverage, including contact seams and target mips.

If each sample has a demonstrated error bound u, true minimax error lies between
max(0, range/2-u) and range/2+u. An assumed u is a tolerance allowance, not a
confidence certificate. Increase samples or repeat uncertain bakes. Test the
whole group's min/max envelope; A~B and B~C do not establish A~C.

Equivalent geometry, normals and all finite-radius occluders under a rigid
transform are sufficient for equal geometric AO, subject to opacity, sidedness
and numerical precision. They are not necessary. A context-hash mismatch should
trigger measurement or a named variant, not automatic unique allocation for every
piece. Opposite open roof sides may agree; a side near a tower may not.
Separate local relief AO from assembly contact AO and account for destruction.

For normals, compare decoded unit vectors in corresponding tangent frames:
angular error = acos(clamp(dot(n_i,n_j),-1,1)). Account for reflection, tangent
handedness and the destination's convention. Compare alpha coverage, material IDs,
mask values, grain direction and unique artwork independently. Compatible color
does not permit conflicting AO when all channels use the same UV set. Use a
separate unique AO map only when the actual destination supports it.

## Economics after compatibility

For physical surface area A and density d in pixels per world unit, ideal content
area is approximately A*d*d before distortion and gutters. A density multiplier k
costs k*k in area. For a proposed shared family, estimate savings as the sum of
member allocations minus owner/variant allocations. Measure actual padded chart
cost too: for rectangle w by h and gutter g it is (w+2g)*(h+2g).

Report unique content, padding, packing waste and page capacity separately. An
area sum within capacity does not prove the shapes can be packed. Shared members
pay owner cost once, but unique contact variants still cost space. Tightly joined
adjacent faces save internal gutters; unrelated parts merely touching in the
atlas are not joined and still need protection against bleed.

Keep opacity-bearing islands together when this avoids paying the destination's
more expensive alpha format over opaque surfaces. Use actual format/mip rules and
measured output bytes; there is no universal alpha cost multiplier. Shared hidden
materials belong in their declared small page/material class. Do not put visible
roof detail there to make the numbers fit.

Rank proposed reductions by visible error and saved padded pixels. Preserve named
hero details and alpha silhouettes; allow coarser tiny hidden details only under
the camera/density contract. Test mips and the actual-size building view. Maintain
the same chart/owner manifest in the real editable UV layer and bitmap outputs.
