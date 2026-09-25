# Surface removal, backs and destruction

Use this before deleting hidden construction faces or allocating a low-density UV
class. It is a conservative classification procedure, not a universal decimator.
The helper is [surface_visibility.py](../scripts/surface_visibility.py); run
[its regression tests](../scripts/test_surface_visibility.py) with unittest.

## Define the contract before classifying

Record world up, all permitted camera azimuths/elevations/zoom, building rotations,
terrain placement range, opaque/cutout/two-sided material behavior and render
states. Intact, construction, progressive damage, death and debris are separate
states. Unknown camera or damage limits mean unknown visibility, not invisibility.
Never define the back as negative Y, the current screenshot's far side, a dark AO
pixel, or simply normal.z < 0. Shading normals/normal maps do not define face winding.

Keep three representations where needed: closed editable/bake/fracture source,
optimized intact render shell, and damaged render pieces with exposed interiors.
Collision volumes are a separate physics representation. Deleting render faces
does not authorize changing collision hulls, piece membership or source topology.

## Exact orientation test

For geometric unit normal n=(nx,ny,nz), camera elevation e and arbitrary azimuth a:

```
v(a,e) = (cos(e) cos(a), cos(e) sin(a), sin(e))
h = sqrt(nx*nx + ny*ny)
e_star = clamp(atan2(nz,h), e_min, e_max)
B(n) = max(n dot v) = h*cos(e_star) + nz*sin(e_star)
```

The expression assumes -90 <= e_min <= e_max <= 90 and all azimuths. B<0 means
never front-facing within that envelope for a single-sided surface. Use a numeric
margin; grazing B=0 and zero/degenerate normals are not removal certificates.
For an illustrative 30–60 degree camera, a downward normal must be within
30 degrees of straight down to be excluded; many sloping soffits remain visible.
These example angles are not a claim about a particular game's camera limits.
For unrestricted rigid debris rotations, max over rotation/view of (R*n) dot v
is 1: rest-pose orientation gives no backside exemption to falling pieces.

Orientation exclusion only licenses a camera-invisible classification. The face
can still block sunlight/AO or be required in another render state.

## Sufficient whole-face burial certificate

Let Q be an actual retained, opaque, closed, convex render component represented
by normalized outward planes a_j dot x + b_j <= 0. For every vertex x_i of a
triangle F require:

```
max over i,j (a_j dot x_i + b_j) < -clearance
```

Convexity then places the entire triangle strictly inside Q. Every ray from outside
Q reaches Q before F, so F cannot affect external visibility or binary shadow/AO
occlusion. This is a sufficient test, not a complete solver: a union of several
occluders can hide a face which fails the single-component test.

Required conditions:

- Q is verified from its actual render triangles: exact positional weld, closed
  oriented manifold, positive volume, all vertices inside its supporting planes.
  A convex hull of a concave/open mesh or a Havok collider is NOT this proof.
- Q stays opaque and retained. Freeze certifying shells or explicitly resolve
  dependencies before simultaneous deletions. Transparency, portals, volume
  effects and an AO bake requiring closed-source topology invalidate the shortcut.
- For each relevant state, F remains inside Q. A shared rigid transform preserves
  containment. Different breakable pieces, stage hiding and unknown motion do not.
  An intact-only certificate is not permission to omit damage interiors.
- Clearance exceeds numeric tolerance. Coplanar contacts, tiny gaps and partially
  buried triangles need separate handling. Vertex-inside tests alone do not prove
  containment in a nonconvex volume. A rounded-grid weld is a measurement aid,
  not a proof that the original mesh is watertight.
- Classify triangulated geometry but preserve polygon correspondence. Delete an
  original polygon only when ALL its triangles qualify; otherwise retain it or
  deliberately split it on the export copy. Preserve retained corner normals,
  UVs, weights and material assignments.

A ground underside is a separate certificate: the entire patch must remain under
guaranteed opaque terrain for every permitted placement. z=0, a footprint decal,
or one flat test map does not establish that for slopes, cliffs or water.

## Operational categories

| Category | Geometry | Texture allocation |
| --- | --- | --- |
| Certified buried in all states using this mesh | Omit on export copy; retain source | No runtime UV allocation |
| Back-facing for the complete intact camera envelope | Retain until shadow/state tests justify removal | Small shared opaque backing patch is eligible on the intact mesh; damage uses its own mapping |
| Invisible in finitely sampled views only | Keep/review; never auto-delete | No automatic density downgrade; inspect narrow exposed strips |
| Visible, transparent, two-sided, silhouette or destruction-exposed | Keep appropriate surface/thickness | Normal measured density or explicit detail class |

Do not turn each retained backing face into a new unique island. Use a shared
wood/stone backing family where shader response and AO agree. The intact exterior
and the damaged interior can have different material regions and UV layouts.

For visible surfaces, let J_s map an orthonormal local surface basis into screen
pixels for supported state/view s. For isotropic density d in texels/world-unit:

```
d_required >= k * max_over_visible_states_and_views sigma_max(J_s)
```

k is the chosen texels-per-screen-pixel quality factor. With a general texture
Jacobian T, inspect singular values of J_s * inverse(T) (screen pixels per texel).
Area-average sqrt(projected area) is not enough: a foreshortened strip can still
need full resolution along its long axis. If no visibility is proven, the camera
term is zero, but shader/alpha/bake/state requirements can still impose a floor.
Screen coverage, darkness and visibility frequency are prioritization hints, not
proofs that a detailed visible feature tolerates lower density. Calibrate actual
downsampling with a fixed-zoom comparison and an explicit error budget.

## AO and verification

Geometric AO is an integral of visibility over a hemisphere, not a face's up/down
classification. Camera-hidden geometry may affect AO on a neighboring visible
face. Compare AO/shadow results on retained visible receivers; do not compare only
the removed faces. Preserve the closed bake source where appropriate.

AO-aware UV sharing is another decision: identical shape/orientation does not
imply identical surroundings. Use the texturing workflow's per-texel AO range and
error budget before stacking regions. A shadow-only backing patch needs no unique
AO chart merely because it is a separate construction box.

Use finite ray/raster comparisons as regression checks, labeled with view/light
sets and tolerances. Centroid-plus-vertex probes can miss narrow visible strips;
even a dense raster only covers its tested camera states. For alpha geometry,
evaluate the mask at intersections or conservatively omit it from the occluder
set. Never treat a cutout plane as solid proof of concealment.

External technical basis: PBRT distinguishes geometric intersections and opaque
occlusion and explicitly evaluates alpha masks before accepting hits:
[Primitive interface and geometric primitives](https://www.pbr-book.org/4ed/Primitives_and_Intersection_Acceleration/Primitive_Interface_and_Geometric_Primitives).
The camera-cone and convex-containment formulas above are elementary geometric
derivations; they do not assert a particular engine's material behavior.
