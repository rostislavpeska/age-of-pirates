# Town Center recipe evidence and paired export

## Which revision

The subsequent complete sign-and-export checkpoint is
`snapshots/2026-09-30-korean-tc-r2-export/HANDOFF.json`: installed after the owner's
subsequent explicit export request; `deployment/RECEIPT.json` records that action.
Its `review/HANDOFF.json` identifies `GPT_Astra_Hangul_ALL_MODELS.blend`; its
`hangul/HANDOFF.json` enumerates the full map set with the official Korean sign
override. This retains Wanja r2 geometry/UVs and roof coloring. The paired native
export passed 25 checks and failed five inherited budget/density/lineage checks;
these remain open after installation and are not a reusable exception.
Do not interpret the review status of a scoped sign edit as global export approval.

The Wanja r2 exemplar is the complete external snapshot
`snapshots/2026-09-30-window-wanja-r2/HANDOFF.json`. It names the all-model Blender
review and `LIVE_LOW_VERIFIED.blend`, and links the roof-color map bundle under
`2026-09-30-window-wanja-r2-roof`. The latter is the combined window-plus-roof
map set. The registry records these paths/hashes; verify before reproduction.

This exemplar has offline scoped validation and the owner's subsequent request
to export it, including `_damaged`. That request is not an in-game test result.
Do not replace a current accepted asset merely because this dated exemplar exists.
The project `CURRENT.md`, legacy S18i `HEAD`, and some earlier export configs still
describe older revisions. Always read the latest complete phase handoff.

The geometry/UV/map bundle is the unit of rollback. A texture-only rollback cannot
restore windows whose receivers changed. The full review `.blend` contains eight
LOW review sets and HIGH references: export **only the three Final LOW parts**.

## Game-specific paired update

For this Town Center, use `aoe-building-pipeline` and the donor-based destruction
skills. The existing game has a verified skeleton, orientation, flag placements
and HKT graph. Preserve these; do not rebuild damage through a static FBX converter.

Existing technical recipe: explicit `KTC_EXPORT_CONFIG` inputs, design orientation
B with a proper +90-degree raw-Y rotation and measured mast attachments. Runtime
pages use mata/matb/matc; matb carries eave alpha. The recorded exporter uses an
R-flipped normal map with OpenGL G retained to match its measured tangent basis.
This is **that exporter's convention**, not a general Korean normal-map rule.

When only window receivers change, transfer them in physical space onto damage
fragments, cutting triangles at the new UV seams and retaining rigid piece IDs.
Check panel area coverage as well as UV range. The old damage version had half
of panel 159 missing; valid UVs and successful native loading did not catch that.
Coplanar trim can overlap the same projected rectangle: use the old face/UV
provenance to distinguish infill from outer framing.

All damaged meshes must fit the tested 16-bit index limit; bindings and HKT hulls
must agree. Use full `gr2_lint.py --profile korean_tc <stage>` with native loading,
texture budget, density and UV lineage checks. Do not suppress failures because
the previous installed asset also fails them.

As measured at the start of the 2026-09-30 r2 export, existing runtime files pass
geometry, native loading, orientation, bones and HKT checks, but fail the new
two-set texture ceiling, hidden MATC density, and UV lineage. These are real open
constraints, not an accepted exception. Preserve the staged pair and exact report
until corrected or a permitted owner decision is recorded; never mark a red
gate green by lowering its thresholds.

The reusable generic checks stay in their shared packages. This page records the
Korean checkpoint and its measured limits so the next building does not inherit
a stale file or repeat a known experiment.
