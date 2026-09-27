# Scattered architectural UV faces: S12 research laboratory

Research date: 2026-09-27. Experimental, not a production unwrap approval.
Frozen input: Korean_TC_S12_Frame_Reuse.blend, SHA-256
`38e0ec0d7d6cdad8a38c131e4bd4218802bb152f7ae134666fb2a76bc91b8a5b`.
The model and its thirteen required companion assets passed the project verifier.
The later v22 supplement was absent locally; it is not an input to this experiment.
Scripts live on `codex/uv-scattering-research`; generated models and images live
outside Git. No S13/overlap-agent assets or live mod assets are edited.

## What is the problem?

Scattering is several distinct failures which require different remedies:

1. **Fragmented chart construction:** adjacent surface faces receive independent
   UV islands even where a usable continuous map is possible.
2. **Disconnected editable topology:** imported seam duplicates occupy coincident
   positions but do not share mesh vertices. Giving them equal UV coordinates
   does not make Blender's linked selection treat them as one island.
3. **Architectural assembly:** beams, caps, wall panels and reveals can belong to
   one visual feature while being physically separate surfaces. Nearby, crossing
   or touching-at-a-point surfaces must not be welded to improve a score.
4. **Layout scattering:** distinct valid charts can be placed near one another in
   the editor. This is grouping, not joining. Packing cannot repair connectivity.
5. **Reuse coloring:** equal texture ownership is not equal surface connectivity.
   S12's sharing-family colors were not a chart-connectivity diagnostic.

For a fixed surface graph, seek a partition into connected charts with a valid
piecewise mapping: finite, nondegenerate, no positive-area self-intersections,
bounded two-axis stretch, consistent orientation, and explicit semantic/normal
constraints. Minimize unnecessary cut length and chart count only after these
constraints. Texture memory, sharing, AO compatibility and packing are later
objectives. A low chart count by itself can reward invalid foldovers.

Some surfaces cannot be flattened isometrically without cuts or distortion.
Closed tubes require a cut; branching strips and curved corners are harder than
straight specimens. Existing small-bay/specimen scripts establish bounded cases,
not whole-building generalization. The source archive includes
`Vanilla_UV_ReverseEngineering/build_bay_specimen.py`; this is contextual evidence,
not proof that it was the particular specimen the owner recalled.

## Papers and solver implementations

| Source | Relevant contribution | Limitation for this task |
|---|---|---|
| [LSCM, Levy et al. 2002](https://brunolevy.github.io/papers/LSCM_SIGGRAPH_2002.pdf) | Conformal parameterization of chosen surface patches | Flattening alone does not determine architectural patch identity |
| [OptCuts, Li et al. 2018](https://www.cs.ubc.ca/labs/imager/tr/2018/OptCuts/) and [MIT source](https://github.com/liminchen/OptCuts) | Jointly optimizes cuts and distortion; can improve an existing embedding | Repository expects one connected component per input; Windows build/performance cautions. Researched, not executed here |
| [Autocuts, Poranne et al. 2017](https://roipo.github.io/publication/2017-poranne-autocuts/) and [MPL-2.0 source](https://github.com/Roipo/Autocuts) | Joint cut/parameterization optimization with seam weighting | Research implementation, not a verified current Blender plug-in; not executed |
| [Boundary First Flattening](https://github.com/GeometryCollective/boundary-first-flattening) | MIT implementation of boundary-controlled conformal flattening | Automatic cuts do not supply building-part semantics; not executed |
| [xatlas](https://github.com/jpcy/xatlas) | MIT chart generation plus packing, with public chart-growth weights and seam controls | Tested through Python 0.0.11; triangle solver can introduce cuts inside an authored quad/ngon |
| [PartUV paper](https://www.zhaoningwang.com/PartUV/static/partuv.pdf) and [source](https://github.com/EricWang12/PartUV) | Part priors plus geometric refinement target fewer coherent charts | Promising for semantic grouping; model/environment dependencies and nonmanifold limitations. Not executed; inspect actual license before redistribution |

The inference from these sources is that a hybrid pipeline is appropriate:
semantic grouping and verified adjacency before flattening; distortion and
injectivity checks after it; explicit seams/constraints when automatic choices
conflict with construction or texture requirements. No paper establishes that
all disconnected building pieces should become one chart.

## Open-source add-on and repository survey

This is a broad, dated survey of discoverable implementations, not a claim to
have enumerated every open-source UV plug-in or tested their Blender 5.0 support.
Primary repositories were checked; `repositories.json` records metadata/licenses.

| Project | Role and relevance | This experiment |
|---|---|---|
| [UVgami](https://github.com/danielboxer/UVgami) | GPL-3.0 Blender front-end for automatic unwrap engines; controls seam restrictions | Researched wrapper; testing xatlas separately does not certify this add-on |
| [UniV](https://github.com/Oxicid/UniV) | GPL-3.0 unwrap, stitch, straighten, quadrify and inspection workflow | Strong candidate for operator correction gates; not installed/tested |
| [TexTools](https://github.com/franMarz/TexTools-Blender) | UV editing, unwrap and texture tools | Relevant manual tools; API did not classify its license, so inspect repository terms before copying |
| [UV Squares](https://github.com/Radivarig/UvSquares) | GPL-2.0 quad-grid reshaping | Useful for approved regular strips; not a semantic chart generator |
| [DreamUV](https://github.com/leukbaars/DreamUV) | Viewport tools including patch/tube workflows | Source available; license not identified by repository API. Not executed |
| [uhlik/bpy Tube UV Unwrap](https://github.com/uhlik/bpy) | Explicit tube/strip workflow scripts | Specialized prior rather than whole-building segmentation; current compatibility unverified |
| [AutoUV](https://github.com/visualbruno/AutoUV) | MIT low-poly unwrap implementation explicitly targeting larger islands | Relevant alternative; repository claims are not benchmark evidence on S12 |
| [Remi](https://github.com/shaderko/remi-blender-addon) | GPL-3.0 mesh workflow with candidate search and UV validation | Relevant multi-candidate architecture; geometry repair/retopology features are outside this experiment |
| [Blender native UV tools](https://docs.blender.org/manual/en/latest/modeling/meshes/editing/uv.html) | Angle-based/conformal unwrap and Smart Project | Angle-based and Smart Project actually tested on the same analytical proxy |

OKUnwrap and Easeam were also discovered, but this pass did not establish a
public source repository and license for them. They are not counted as verified
open-source implementations. Packing-only products are not chart-construction
solutions. Commercial availability does not itself establish or disprove an
open-source license.

## Actual experiments

All methods operate on the same exported S12 face IDs and analytical surface
data: 5,234 quads/ngons, 3,756 visible faces, 1,478 hidden faces. No authored
triangulation is introduced. Hidden UV allocation is preserved. Read-only
Blender loop tessellation supplies measurement triangles.

- **Baseline:** actual S12 UVMap, with a new connectivity diagnostic.
- **Planar:** join complete coplanar baseline charts at verified shared edges.
- **Strip65 / Strip100:** rigidly align entire existing charts along matching
  edges, reject UV-length mismatch and positive-area overlap, allow respectively
  65 or 100 degrees geometric dihedral. No chart scaling or face splitting.
- **Protected:** 100-degree search with additional protection of corner-normal
  discontinuities over 5 degrees. This is a candidate safety constraint, not
  tangent-space bake validation.
- **Xatlas:** per connected semantic component on a disposable triangle proxy.
  Reject an entire component if returned UVs conflict within an authored polygon.
  Thirteen components were rejected and retain baseline coordinates. Consequently
  this is a hybrid accepted-subset result, not a pure xatlas whole-model result.
- **ABF:** Blender angle-based unwrap on a virtual-edge proxy with 65-degree
  starting seams. **Smart:** Blender Smart Project at 66 degrees on that proxy.
  Both restore each output chart's total UV area to its baseline allocation;
  that does not preserve individual face density or anisotropy.
- **Sewn100:** the Strip100 UV proposal plus actual vertex sewing in a separate
  derived mesh. Only verified matching boundary endpoints of UV-connected faces
  are joined. Original S12 and all other candidates remain intact. Its small
  coordinate and custom-normal changes are measured, not described as zero.

Matching uses a fixed 0.00002-world-unit endpoint tolerance for this frozen model,
neighbor-bucket search, same source-part boundaries and complete edge matches.
Point contacts, crossings, proximity alone and ambiguous edge fans are excluded.
Material family and visible/hidden rules constrain eligible joins. Partial-edge
T-junctions are intentionally unresolved; do not increase tolerance to hide them.
The counted geometric components are policy-bounded components, not an unrestricted
whole-scene weld. Generalization requires a scale-relative tolerance study.

Diagnostic UV contact sheets use translation only, outside the production tile.
They are not runtime atlas packing. Original `UVMap` stays available; `CandidateUV`
is the editable experimental layer. The RGB bitmap checker samples that layer.
World scale has not been certified in metres, so no physical texel-density claim
is made. Measure both Jacobian singular values after any real atlas allocation.

## Why numeric and visual gates are both necessary

1. **Freeze and identify:** hash input; record scene, face IDs, units, materials,
   actual UV layer and model/process identity. Work in a disposable copy.
2. **Classify adjacency:** native shared edge, virtual seam duplicate, partial
   edge, point contact, intersecting independent piece. Keep these classes distinct.
3. **Construct component families:** straight strip, curved strip, corner, cap,
   ring, hole/reveal, branching frame, roof transition. Test multiple real members
   from different buildings/levels, not only one easy specimen.
4. **Generate bounded proposals:** planar charts, normal-protected unfolding,
   native solvers and external solvers. Keep charts whole unless a named physical
   boundary authorizes a split. Maintain IDs and a rejection/debt log.
5. **Reject invalid maps:** finite data, analytical triangle nondegeneracy,
   same-side foldovers, intra-chart intersections, accidental different-owner
   overlap, stretch in both axes, unintended reflection and density drift.
   Existing defects are a failing baseline, not permission for new ones.
6. **Read the saved file back:** verify actual UV values, native chart count,
   source topology/positions/normals, hidden allocation and image binding.
   Compare to the proposal JSON. Passing a generator's own in-memory report
   is insufficient. Attribute allocation and Edit Mode can invalidate Blender
   RNA handles; reacquire them before writes/reads.
7. **Agent visual gate:** fixed opposing views, underside and roof/eave cutaway,
   closeups of boundary witnesses, island IDs, native-vs-virtual display and
   orientation checker. Reject fragmented strips or misleading same-color
   contacts even if aggregate scores improve. Check the actual UV editor next.
8. **Texture/tangent gate:** hard-normal boundaries, grain, alpha, relief,
   destruction-visible faces and channel-specific seam policy. A joined color
   chart is not automatically a safe tangent-normal chart.
9. **Human comparison packet:** only after the agent catches its own faults;
   present alternatives and specific remaining choices. Then reuse/AO/packing
   and runtime validation, as separately authorized stages.

## Current bounded result and debt

See `results.json`, `saved_file_audit.json`, the gallery and the measured results
table. Protected joining makes a modest improvement. Aggressive joining and
sewing give a much larger reduction but cross hard normal boundaries. Thus the
aggressive result demonstrates recoverable connectivity, not a production winner.

The original UVs contain 74 detected intra-chart positive-area face-overlap pairs.
Rigid methods inherit them; ABF creates more. These are UV-space measurements,
not a new assessment of the other agent's 3D overlap work. A near-degenerate
analytical triangle on face 3838 makes the raw worst-anisotropy maximum enormous;
the area-weighted statistic and the face witness must be reported together.
Do not delete that face as part of a UV experiment.

Color IDs use actual native UV connectivity, with deterministic high contrast
across graph neighbors. A finite palette repeats on nonadjacent charts; same
color alone is not proof of identity. Use `Measured_Chart_ID`/face IDs to inspect
membership. The sewn variant uses the joined chart colors only after independent
native-topology readback confirms them.

Ten regression cases cover split duplicates, point contact, nearby parallel
surfaces, cross-part contact, foldover, density mismatch, ambiguous edge fans and
a bent-strip case. Whole-model saved-file checks and visual review remain separate.
The independent review script found a stale CustomData handle and prevented a
false handoff where colors changed but the intended UV layer did not. This was
fixed by reacquiring all handles after attribute creation and rerunning readback.
An earlier stale Edit Mode UV handle crashed only the isolated lab; reacquiring
the handle fixed the native-solver run. No other agent's process was stopped.

Native UI screenshot capture was denied by the computer-use tool's Blender
permission. Rendered evidence and saved-file readback are available; an actual
live UV-editor screenshot/interaction gate must not be claimed as passed.

## Measured comparison

Counts below are from independent native edge/UV traversal of the saved Blender
file, not the color labels or the proposal's virtual adjacency graph.

| Candidate | Native islands | Single-face islands | Intra-chart overlap pairs | Visible area with anisotropy >1.1 |
|---|---:|---:|---:|---:|
| Baseline | 2109 | 1918 | 74 | 0.89% |
| Planar | 2100 | 1903 | 74 | 0.89% |
| Protected | 2026 | 1832 | 74 | 0.89% |
| Strip65 | 1931 | 1741 | 74 | 0.89% |
| Strip100 | 1204 | 672 | 74 | 0.89% |
| Sewn100 | 1041 | 477 | 74 inherited proposal pairs | 0.89% before tiny sewing displacement |
| Xatlas accepted subset | 1995 | 1794 | 37 | 58.56% |
| Angle-based proxy | 1895 | 1757 | 373 | 3.53% |
| Smart Project proxy | 2079 | 1808 | 17 | 13.39% |

Rigid candidates preserve individual UV edge lengths to floating-point precision.
Saved UV coordinates agree with plans to at most 2.65e-7 UV units. Every original
UVMap is unchanged. All candidates have zero authored triangles. All non-sewn
model candidates preserve topology, vertex positions and custom corner normals
exactly. Sewn100's maximum positional change is 1.222e-5 world units; its maximum
custom-normal vector change is 0.000480 (approximately 0.028 degrees). Its full
post-sewing distortion/overlap recertification is still a production gate.

The aggressive proposal has 1047 UV-joined edges whose corner normals differ by
more than five degrees, versus 77 in the baseline. This is why it cannot win
simply on its 50.6% native-island reduction. Protected refuses new joins across
that constraint. It does not remove the pre-existing exceptions.

Visual observations: long eave perimeter strips become more coherent under
Strip100/Sewn100, while repeated under-eave teeth remain separate small patches.
Planar-only joining is nearly indistinguishable from baseline. ABF changes major
roof partition boundaries and creates many extra measured UV overlaps. Smart
Project reduces overlaps but keeps heavy small-island fragmentation. The checker
views show phase/rotation changes after translation and distinctly altered chart
shapes for solver candidates. No normal/AO bake comparison was performed.
