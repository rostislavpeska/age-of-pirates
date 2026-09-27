# Reproducible hybrid formula

This packages the M5 experiment, with configurable constants. Coordinates and
normals are world-space Z-up. Face IDs index the frozen original polygons. Image,
ray and voxel arrays must use exactly that indexing; a new snapshot invalidates them.

## Measurements

- Images: two-sided opaque face-ID depth rasterization. For each face, `px` is
  maximum covered pixels over training views, `frac` maximum covered/projected
  area fraction (clamped to one). The projection denominator uses a one-pixel
  floor. Orthographic cameras use all azimuths and record framing/resolution.
- Rays: seven near-edge/centroid samples per analysis triangle, weighted by
  triangle area for camera exposure. `ray` is the maximum unoccluded sample-area
  fraction over training directions. Ray start epsilon is bounding diagonal ×
  2e-7, ray length diagonal × 4. Very thin geometry and coplanar faces need review.
- Pairing: from faces with normal Z < -0.05, upward probes find the first opaque
  upward-facing hit (normal Z > 0.15), between two epsilons and configured maximum
  distance. `pair` is the unweighted sample hit fraction, **not** a thickness proof
  or area-weighted coverage. This preserves the tested experiment exactly.
- Voxel: triangle/box SAT surface occupancy followed by 26-connected exterior-air
  flood fill. Sample centroid and inset vertices on the outward side at 1.25 and
  2.5 cell pitches; take the smaller enclosure fraction. Repeat at two pitches
  and a 0.37-cell shifted fine grid. `vox` is the minimum; unstable means max−min
  > 0.2. Occupied samples count as unenclosed, a known source of missed cavities.

Alpha receivers remain protected and alpha triangles are absent from occluders.
This transparent extreme can overestimate exposure but does not fabricate solid
coverage across texture holes. All these are finite measurements, not proofs.

## Scores and graph

With `clip(x)=min(1,max(0,x))`, baseline scores are:

```
s_image = clip(1 - max(px/4, frac/0.08))
s_ray   = clip(1 - ray/0.10)
s_pair  = pair * clip((-normal_z - 0.05)/0.30)
s_voxel = 0 if unstable else vox
p = (1.5*s_image + 1.5*s_ray + 1.0*s_pair + 0.4*s_voxel)/4.4
```

`p` is a heuristic support score. Each training-exposed face with `px >= 4` **and**
`frac >= 0.1`, every alpha face and every explicit keep override receives `p=0.0001`.
After graph solving these faces are forcibly kept. In the original experiment,
“hard keep” meant this final override: the unary itself is finite, so its graph
neighborhood influence is not equivalent to an infinite-capacity terminal.

Build graph edges only from exactly matching world-space polygon edges, without
welding/rounding authoring geometry. Require matching physical material keys and
alpha class, and geometric normal dot product >= 0.82. Baseline key normalization
removes `HIDDEN_` from the original diagnostic material name; for new assets supply
an explicit `physical_material` key to avoid name/suffix inference errors.

```
w_ij = min(4, edge_length / sqrt(max((area_i+area_j)/2, 1e-8))
               * dot(normal_i, normal_j)^8)
E(L) = sum_i D_i(L_i) + 0.35 * sum_edges w_ij * [L_i != L_j]
D_i(shared) = -log(clip(p_i, 0.0001, 0.9999))
D_i(keep)   = -log(1 - clip(p_i, 0.0001, 0.9999))
```

The solver converts nonnegative capacities to integers at scale 100,000 and uses
SciPy max-flow/min-cut. Sink-side polygons are shared-backing candidates. Exact
duplicate coincident edges may connect different objects; disconnected boxes and
tiny coordinate differences do not join. Report these limits rather than hiding
them with a geometry weld. This graph labels faces; it does **not** join UV islands.

## Validation and tuning

Withheld exposure flags candidates having >=4 pixels and >=10% projected area in
a withheld view. Inspect smaller exposures too. Stress views below/above the assumed
camera range are reported separately; they do not silently redefine training.
Treat mixed polygons (large hidden interior plus visible rim), instability and
contradictory signals as review cases. Protection overrides are original-face IDs
with reasons; they do not mutate geometry or retroactively change measurements.

Keep all constants in a versioned parameter file. Tune against training data and
user feedback; reserve fresh views/assets for validation. If held-out views guide
new thresholds, they become development data and a new holdout is needed. The
method's weights are visibility parameters, separate from the later AO-tolerance
parameter for UV stacking. World-distance thresholds must scale with the asset.

## Research provenance

Our code is an adaptation; it is not an implementation of each cited paper:

- [Zhang and Turk, Visibility-Guided Simplification](https://faculty.cc.gatech.edu/~turk/vis_simp/vis_simp.html): view-dependent importance.
- [Fast and robust shape diameter function](https://pmc.ncbi.nlm.nih.gov/articles/PMC5786294/): opposing-surface context; our vertical pairing is much simpler.
- [Schwarz and Seidel, Fast Parallel Surface and Solid Voxelization](https://www.michael-schwarz.com/research/publ/files/vox-siga10.pdf): distinguish surface occupancy and enclosed volume; our implementation is CPU SAT/flood fill.
- [Zhou et al., Visibility-driven Mesh Analysis through Graph Cuts](https://peterwonka.net/Publications/pdfs/2008.VIS.Zhou.VisibilityMeshAnalysis.Final.pdf): motivates combined visibility/graph segmentation; our material-adjacency graph differs from their half-space visibility graph.
