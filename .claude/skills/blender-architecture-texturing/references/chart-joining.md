# Coherent charts, intentional reuse and AO

This procedure separates **chart construction**, **reuse**, and **packing**. Run
them in that order. A density-consistent atlas containing thousands of separately
packed construction faces is not an accepted architectural unwrap. A checker and
an overlap pass cannot establish a useful atlas composition.

## 1. Joining is different from stacking

A chart is a map f from a surface patch to texture coordinates. For ordinary
unique shading it must be injective on triangle interiors: different visible
surface points receive different texels. Adjacent triangles may share an edge.
One chart may contain very dark and very light AO: the texture represents that
variation. **Do not split charts merely because AO varies across the surface.**

Stacking deliberately makes f non-injective. Several surface points then request
the same texel. Their required material values, tangent-space normals, opacity
and baked AO must agree within the declared tolerances. Similar geometry alone
does not prove this. Packing islands close together is neither joining nor reuse.

## 2. Identify joinable surfaces before choosing atlas dimensions

Construct a face adjacency graph using shared geometric edges. Imported meshes
may duplicate vertices at seams: coincident edges can be identified virtually
with a scale-aware position tolerance without welding or changing source normals.
Do not connect faces that merely cross, touch at one point or happen to be nearby.
Require an explicit structural/semantic group: facade bay, roof slope, ridge strip,
foundation course. Different source materials can occupy one authored atlas chart
when the receiver and baked material-ID map preserve their boundaries.

For each proposed connected patch:

1. Check normal/tangent discontinuities, silhouette edges, holes and material
   intent. A hard normal generally needs a UV split for tangent-normal baking.
   Do not erase hard normals to manufacture connectivity. UV seams do not always
   imply hard normals. Keep lettering and grain orientation explicit.
2. For a coplanar patch use one metric planar frame. For a roof/curved strip use a
   coherent measured unfolding or constrained unwrap. Add a seam only where
   topology or measured distortion requires it. A closed tube needs a longitudinal
   seam; disconnected construction boxes cannot be stitched into a wall surface.
3. Evaluate the Jacobian J = texel_edge_matrix * inverse(orthonormal_world_edges)
   on every final triangle. Its singular values give both density axes; their
   ratio gives anisotropy. Test every triangle, not only mean island area.
4. Check exact positive-area intersections within the proposed chart. Reject
   foldovers. With a shared UV edge, neighboring face interiors must occupy
   opposite sides of that edge. Equal endpoints alone do not establish this.
5. Sample AO along the patch at the intended resolution. A smooth gradient is
   valid. A narrow contact feature that filtering cannot preserve calls for more
   local texel budget, a material variant or real geometry, not arbitrary cuts at
   every polygon. Inspect mip levels and hard boundaries.

If no edge-connected patch exists, decide between a shared trim region and a
**new low receiver baked from the assembled details**. This is an authoring choice,
not a UV stitch. Paper-backed shallow lattice can become a whole facade/window
panel; open rails, deep reveals, major posts and silhouette projections stay real.
Test high, low without normals, and baked low with opposing lights and a grazing
camera. A flat receiver cannot reproduce silhouette or parallax. A useful camera
bound is projected displacement in pixels from replacing each high point by its
receiver point, evaluated over the actual gameplay camera envelope.

Blender's [Stitch operation](https://docs.blender.org/UATEST/manual/en/4.5/modeling/meshes/uv/editing.html)
joins UVs at shared vertices; it does not decide semantic groups or compatible
bake values. The [UV operator documentation](https://docs.blender.org/manual/en/5.0/modeling/meshes/editing/uv.html)
describes unwrap/packing operations. Use these as mechanics after chart design.

## 3. Mathematical test for sharing pixels

Independently evaluate/bake each candidate in its own valid UV target. Use the
same linear AO convention (ambient visibility 0..1), radius, sidedness, occluder
scope, tangent convention and sampling. Establish correspondence first; never
compare unrelated texels or include padding/background as surface evidence.

At each texel t let a_i(t) be the required AO of instance i. Then

    range(t) = max_i a_i(t) - min_i a_i(t)
    smallest possible worst-case error(t) = range(t) / 2
    minimax shared value(t) = (max_i a_i(t) + min_i a_i(t)) / 2

For maximum permitted scalar error e, sharing is feasible only when range <= 2e
at every protected texel. Report both peak error and affected coverage; a small
high-contrast seam can still matter. If every sample has a demonstrated error bound
u, the true minimax error lies between max(0, range/2-u) and range/2+u. An assumed
u is only a tolerance allowance, not a statistical confidence certificate. Increase
samples or repeat the bake for uncertain cases. Compare intended mip levels too.

Do not build groups by transitive pairwise similarity: A can be close to B and B
to C while A and C conflict. Test the entire proposed group's min/max envelopes.
The bundled `scripts/ao_chart_constraints.py` implements this scalar test. It does
not prove normal, color, opacity, geometry, packing or camera compatibility.

For normals, compare decoded unit vectors in corresponding tangent frames;
angular error is acos(clamp(dot(n_i,n_j),-1,1)). Mirrored mappings need handedness.
Compare alpha coverage and semantic IDs independently. In a shader where all
channels share one UV set, compatible color alone cannot license overlapping AO.

Equivalent local geometry/normals and occluders under a rigid transform are a
sufficient condition for equal finite-radius geometric AO, subject to material
opacity, sidedness and numerical precision. They are not necessary: different
surroundings can produce sufficiently similar AO. Therefore conservative context
hashing can approve some reuse; a hash mismatch must not be treated as proof that
every chart needs unique space. Resolve with a measured bake, scope choice or
named variant. Do not cast an entire building's permanent shadow into shared trim.

[Marmoset bake groups](https://docs.marmoset.co/docs/bake-groups/) isolate projection
sources, while its [map settings](https://docs.marmoset.co/docs/map-types/) let AO
include other groups or exclude them. These are different decisions. Record local
detail AO separately from assembly contact AO, especially for removable/destructible
pieces. Neither layer is a baked sun direction.

## 4. Camera and hidden-surface allocation

Record the actual camera envelope. For a face normal n and direction v toward an
orthographic camera, dot(n,v) <= 0 is back-facing in a single-sided surface model.
Ray tests determine whether front-facing samples are occluded. Finite samples can
miss a narrow visible edge; opaque BVHs can incorrectly hide surfaces behind
cutouts. Keep uncertain geometry and inspect a color overlay before deletion.

Delete truly unnecessary intact-model bottoms only after checking shadows,
cutouts, exposed silhouettes and the destruction workflow. Otherwise use a named
low-density class. One-eighth linear density consumes one-sixty-fourth of the
texel area before gutters. Small hidden charts can waste more pixels on padding
than on content: give them an appropriate shared neutral region where allowed.
Visible soffits and exposed fracture interiors are separate cases. Preserve the
closed authoring/bake/fracture source even when the intact render mesh omits faces.

## 5. Reusable sequence and checkpoints

1. Inspect a shipped reference's geometry, actual UVs, all map channels and shader
   bindings. Trace a few atlas rectangles to their mesh faces. Mark observation
   separately from inferred authoring history.
2. Define structural patches, shared trim/library families and unique landmarks.
   Budget camera-visible, detail and hidden density classes from measured assets.
3. Prove one continuous gradient chart, one shared module, one conflicting corner,
   and one shallow-detail bake. Inspect the maps and corresponding 3D views.
4. Freeze semantic charts and allowed reuse before packing. Report chart counts,
   wasted gutter area and density. A feasible rectangle packing is not an art gate.
5. Pack owners once, then assign verified instances. Bake only owners/unique
   variants; retain all intended occluders. Never write all overlapping instances
   into the same bake target. Use explicit authored bitmap maps and semantic masks.
6. Apply the proven module to a candidate building; verify each variant, camera
   views, actual geometry savings, per-corner normals and other preserved surfaces.
   Then style textures and perform engine-specific tests.

## Helper scope and demonstrated limits

- `scripts/uv_metrics.py`: two-axis world-space density and fixed-size rectangle
  packing; does not design architectural charts.
- `scripts/blender_uv_layout.py`: copies/normalizes existing charts and makes
  **diagnostic unique layouts**, with explicit density classes and optional planar
  face repairs. Do not use per-face repairs plus packing as the final architectural
  chart generator. The fragmented full-building trial was rejected by the user.
- `scripts/blender_hybrid_uv.py`: conservative canonical geometry/context matching
  after chart design. Records reuse owners; protects nearby cutouts. It is not an
  AO-equivalence solver or a chart-joining algorithm. Its many false negatives
  make it insufficient as the sole atlas authoring method.
- `scripts/blender_ao_review.py`: checker/AO views and unique-owner AO bakes in an
  isolated scene, with explicitly listed extra occluders. Exercised on a repeated
  architectural bay and continuous wall in Blender 5.1.2. Do not give its baker a
  whole mesh containing overlapping instances; first extract owners as receivers.
- `scripts/ao_chart_constraints.py`: linear scalar AO overlap feasibility, tested
  for gradients, disjoint coverage, incompatible contexts, uncertainty and a
  non-transitive similarity chain. Real bake comparisons require correct masks.

The evidence supports a workflow, not a universal automatic unwrap solver. Full
normal/alpha conflict testing, robust general chart solving and engine mip/runtime
acceptance remain separate checks. Keep the exact project specimens and reports
outside the skill package; never redistribute extracted game textures with it.
