# Proposal: reasoning-guided architectural UV construction

Status: architecture proposal, 2026-09-27. No model changes in this pass.
This extends the isolated S12 laboratory; it is not an implemented solver.

## Evidence and research direction

The previous experiments apply global rules and inherit baseline chart/page
boundaries. The eligibility function rejects hidden faces, cross-page joins and
cross-material-family joins. Consequently an angle change cannot recover many
roof/underside relationships. A read-only audit of the frozen input measured:

| Part | Faces | Hidden faces | Visible/hidden boundary edges | Cross-page edges | Cross-material edges |
|---|---:|---:|---:|---:|---:|
| Rear hall roof | 615 | 214 | 168 | 200 | 258 |
| Tower lower eave | 522 | 170 | 138 | 146 | 194 |
| Tower upper roof | 530 | 184 | 148 | 176 | 234 |
| West hall roof | 616 | 227 | 161 | 195 | 243 |

Categories overlap; these are not additive defect counts. They identify barriers,
not a proof that every blocked edge should be joined. The screenshot does not
establish adjacency, single-sided visibility or flattenability by itself.

Relevant prior art:

- [PartUV](https://arxiv.org/abs/2511.16659) combines learned part decomposition
  with recursive geometric decisions. Its [configuration](https://github.com/EricWang12/PartUV/blob/main/doc/config.md)
  exposes distortion thresholds and ABF/LSCM selection. Borrow the hierarchical
  propose/test/split structure; do not assume its part labels equal UV boundaries.
- [OptCuts](https://www.cs.ubc.ca/labs/imager/tr/2018/OptCuts/) jointly optimizes
  seams and distortion and supports seam-placement preferences. Its
  [implementation](https://github.com/liminchen/OptCuts) includes regional seam
  placement examples. Borrow constrained local optimization and explicit seam
  preferences; Windows integration remains unvalidated here.
- [SeamGPT](https://victorcheung12.github.io/seamgpt/) learns seam proposals from
  shape information. It is a specialized generative geometry model, not a
  general-purpose conversational LLM controlling a verified UV pipeline.
- [MeshTailor](https://meshtailor.github.io/) proposes mesh-native generative seam
  prediction. Its project page currently labels code TBA. It is research context,
  not a callable dependency of this proposal.

These antecedents mean that learned reasoning plus geometry is not an established
novelty claim. The proposed contribution for this project is an inspectable,
versioned policy per architectural region, produced from visual reasoning and
tested through multiple deterministic backends with saved-file validation.

## Separate four relationships

1. **Semantic assembly:** roof shell, folded edge, underside lip, brackets and
   caps can belong to one roof assembly without being one continuous surface.
2. **Physical adjacency:** native edge, coincident duplicated edge, partial-edge
   T-junction, point contact, intersection or disconnected nearby surface.
3. **UV chart connectivity:** actual editable coordinate continuity on the mesh.
4. **Texture/shading constraints:** material masks, alpha, tangent normals,
   grain direction, visibility/destruction state and density allocation.

A material boundary is not automatically a geometric seam. Conversely, one
semantic assembly does not authorize welding physically separate parts.
An atlas address is an allocation decision; it should not determine semantic
chart construction. Cross-page candidates remain proposals until the whole
joined chart is assigned one compatible page and texture bindings are rebuilt.

## Modules and contracts

| Module | Responsibility | Output |
|---|---|---|
| Snapshot exporter | Freeze source hash, geometry, face IDs, normals, UVs, materials and visibility state | Immutable snapshot and source-ID map |
| Geometry evidence builder | Classify adjacency, curvature, holes, thickness and existing discontinuities; measure tolerances relative to scale | Surface graph and boundary witnesses |
| Visual evidence builder | Matching overview, underside, cutaway and checker views with selectable face IDs; report occluded areas | Evidence packet linked to source hash |
| Reasoning planner | Identify intended assemblies, propose grouping, choose allowed operations/backends and bounded local settings | Declarative region policies with rationale and confidence |
| Policy validator | Validate selectors, scope, overrides, conflicting obligations and input freshness | Accepted policy or exact conflict report |
| Candidate scheduler | Try a small family of deterministic operations/configurations for each region | Versioned candidates and operation logs |
| Geometry/UV validator | Independent numeric checks, seam feasibility and displacement budgets | Pass/fail and face/edge counterexamples |
| Visual critic | Inspect valid candidates in context and against references; explain remaining semantic defects | Local policy revision or visually accepted candidate |
| Blender transaction adapter | Apply to a copy, save, reopen, verify actual coordinates/topology/bindings | Reviewable revision plus readback certificate |

The planner emits data, not arbitrary executable scripts. Face selections must
resolve against the exact snapshot. Numeric failures cannot be waived through
free-text reasoning. A policy conflict is explicit; it must not silently fall
back to per-face charts or inflate tolerances until the job appears successful.

## Policy scope and variables

Use hierarchy: project contract → assembly → surface region → explicit boundary
exception. A child can specialize a declared bounded variable; it cannot weaken
global correctness invariants. Conflicting policies on a shared boundary must be
resolved before candidate generation.

Each policy stores:

- Stable region and face IDs, intended assembly, reference views, source hash.
- Target relationship: prefer join, must remain separate, coordinate grouping
  only, or undecided pending evidence.
- Allowed operations: rigid stitch, planar reconstruction, strip/cylinder
  unfolding, constrained reparameterization, source-duplicate sewing.
- Per-region search ranges: fold angle, area-weighted and worst local distortion,
  density variation, seam-placement preference, chart-count aspiration and solver
  runtime/candidate budget. Avoid a single scalar aggression setting.
- Boundary permissions: material transitions, hidden/visible transitions,
  atlas migration, hard-normal exceptions and whether physical sewing is allowed.
- Protected features: silhouette, alpha openings, ornament, grain, custom normals,
  destruction exposure, source topology and approved neighboring regions.
- Provenance: reasoning, confidence, measured support, author, policy version,
  candidate IDs and unresolved obligations.

Illustrative declaration (not an approved numeric parameter set):

```yaml
region: tower_lower_eave_shell
intent: connect_roof_surface_to_its_contiguous_underside_lip
evidence: [underside_view, matched_boundary_report]
membership: explicit_face_ids_from_frozen_snapshot
prefer_join: [roof_to_fold, fold_to_underside_lip]
keep_separate: [independent_brackets, ridge_caps, alpha_openings]
methods: [strip_unfold, constrained_reparameterization]
material_boundary: may_cross_if_semantics_are_preserved
hidden_boundary: reconsider_classification_and_allocation
atlas_boundary: propose_whole_chart_migration
hard_normal_boundary: candidate_allowed_requires_channel_validation
topology: verified_duplicate_sewing_only_in_derived_copy
budgets: calibrated_region_limits
fallback: report_failed_boundary_and_retain_previous_revision
```

Do not assert a roof-specific distortion budget without calibration. Initial
ranges are experimental knobs, and the final decision reports measured errors
plus the visible consequences. Hidden surfaces get neither automatic low density
nor automatic exemption from correctness checks.

## Region strategies for this building

| Region | Planner's intended behavior | Deterministic restrictions |
|---|---|---|
| Roof face + contiguous underside lip | Strong preference for a folded continuous chart | Verified edge path; no foldovers; allocation/classification reviewed; normal-channel test |
| Curved eave strip | Follow construction direction; keep longitudinal continuity | Local unfolding/reparameterization; corner strain and endpoint closure measured |
| Roof corner / return | Evaluate independently from straight spans | Additional views; cycle/closure checks; explicit justified seam if required |
| Large decorated roof face | Protect motif and distortion budget | No opportunistic cuts through ornament; density and orientation protected |
| Repeated brackets / rafter ends | Preserve actual separate pieces; consider coordinated layout/reuse later | Never bridge empty space or merge merely because close in 3D |
| Window, lattice and alpha border | Conservative treatment | Preserve holes, alpha geometry and UV binding; reflection prohibited unless verified |
| Plain backing | Potentially more permissive after visibility review | Preserve destruction-exposed surfaces and material distinctions |

The lower roof receives its own policy and failure report. Do not assume the
upper roof's settings transfer just because the names or silhouettes are similar.

## Candidate selection and feedback

Generate conservative, moderate and aggressive candidates within each region's
allowed operations. Their differences should be concrete (allowed fold paths,
reparameterization, page migration), not only a changed angle threshold.

First eliminate invalid candidates. Then present the remaining tradeoffs:
semantic coherence, measured distortion, seam visibility, editability and runtime
cost. Keep alternatives that improve one objective at a cost to another; do not
hide the tradeoff in one global weighted score. Chart count is an objective only
after geometric, UV and texture obligations are met.

The validator returns exact counterexamples, e.g. “joining roof lip edge 412
would overlap faces 87 and 93” or “this apparent neighbor is a T-junction.” The
planner can choose a different unfolding, place a named seam, split the semantic
region at a real construction boundary or request additional views. It cannot
declare the measured intersection acceptable because the preview looks better.
Use a bounded iteration budget and retain the last valid candidate on failure.

Validate both each region and its interactions with adjacent regions. Locally
valid charts can collide after assembly, change shared allocations or break a
neighbor's established boundary. A source hash change from the overlap agent
invalidates affected selections and evidence; it never triggers an automatic
merge into that agent's model.

## Non-negotiable gates versus adaptable preferences

Always require finite UVs, coverage, valid authored polygons, bounded geometry
changes, true adjacency for sewing, no newly introduced foldovers/unintended
overlaps, and correct saved-file readback. Existing source defects remain listed
and prevent a clean production certification until resolved or explicitly scoped
out of a diagnostic experiment.

Adapt region grouping, seam priorities, solver choice, visibility-reviewed
density policy, allowed material crossings and channel-specific hard-normal
handling. The LLM's confidence is not a geometric certificate. Unknown texture
channels produce a conditional candidate, not a silent assumption of safety.

## Explainability and visualization

Supply separate toggles for semantic assembly, actual native UV islands, planned
joins, forbidden seams, hard-normal risks, distortion and uncertainty. Maintain
stable region IDs/colors between revisions. Graph-neighbor contrast improves
legibility; labels prevent repeated colors from implying shared identity.

Clicking a boundary should reveal its endpoint IDs, physical relation, current
policy, measured limits, rejection reason and before/after views. Dashed outlines
can show one semantic roof assembly while different fills show its real UV
charts. Never color disconnected pieces identically and call them stitched.

## Implementation and evaluation plan

1. Add evidence graph, rejection reasons and schema-validated policies to the
   existing laboratory. Use the current multimodal assistant as planner/critic;
   no new neural-model training is needed for the first prototype.
2. Implement roof, eave, corner and sensitive-detail policies, plus the atlas and
   hidden-classification dependencies currently missing from the global solver.
3. Test upper roof, lower eave and a difficult return. Reserve another complete
   roof as an unseen evaluation case; do not tune against all specimens at once.
4. Compare fixed global rules, region rules without visual feedback, and region
   rules with visual feedback. Optionally compare later with PartUV/OptCuts where
   tooling is verified. This measures whether reasoning adds value.
5. Score intended-join success, false joins, unnecessary seams, distortion,
   density, true editable connectivity, unresolved defects, elapsed machine time,
   review iterations and measured human corrections. Do not optimize island
   count alone. Record LLM/tool versions, seeds and every policy revision.

Reasoning output need not be identical on every fresh run. Reproducibility comes
from freezing its accepted policy and replaying the same snapshot, tools and
numeric configuration; backend nondeterminism must be measured rather than
assumed away.

The first deliverable should be a policy-driven roof repair demonstrator with
boundary-level explanations and a controlled comparison. A universal automatic
architectural unwrap system would be a later, separately demonstrated claim.
