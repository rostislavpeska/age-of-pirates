# Universal UV texel-density floor (hard gate)

Owner, 2026-09-30: "Plus we need hard DPI floor!!!!!!!!!! Scattered UV map is a nightmare!!!!!! ... But UV map DPI
floor should be universal". The rule is the same for every model and every project. Each game has its own numbers in
[uv-density-floor.json](uv-density-floor.json), measured on its own shipped assets. A project overrides the numbers,
never the rule. Agents do not edit a number so that a model passes. On 2026-10-06 the owner authorized a modest
reduction; this revision implements 10%: median 100 -> 90 and face floor 60 -> 54. All share, collapse and
dilution limits stay unchanged. Higher authored/component targets remain separate requirements; changing the
floor does not itself change targets or UVs. Record any owner-authorized target revision separately and preserve
protected detail requirements. Historical vanilla measurements below remain historical evidence.

## The rule

`density(face) = sqrt(UV area in texels² / 3D area)`, where the page is the texture the face samples (its BaseColor).
Percentiles are weighted by 3D area.

| id | Rule | AoE3DE number |
| --- | --- | --- |
| a | The model's median density is at least `model_median_min` | 90 t/u |
| b | At most `face_max_share_below` of the textured area sits below `face_floor`. This holds **for the whole model and for each page** | 2 % below 54 t/u |
| c | Faces parked on no texels (zero UV area, or below 1 t/u) cover at most `collapsed_max_share` of the area | 3 % |
| b (owned) | b again over the **texel-owning area** (`face_max_share_below_owned`), per model and per page | 3 % |
| b+c | The area below `face_floor` and the collapsed area **together**: `untextured_max_share` of the area, and `untextured_max_share_owned` of the texel-owning area | 3.5 % / 8 % |

Rule b is where a scattered map fails. Cutting a page into many small islands and shrinking them lowers per-face
density, even while the median still passes. Rule c keeps a model from escaping b by collapsing faces onto one texel.
Rule b+c keeps b's and c's allowances from stacking (INC-035: 1.9 % below plus 2.9 % collapsed passed both).

**Dilution-proof (INC-035).** Added area dilutes a share: hidden faces whose UVs sit on texels the model already
uses turned the shipped Korean TC from FAIL (9.6 %) to PASS (1.55 %). The texel-owning area counts each texel region
once: the page is rasterised (at most 256 cells a side), the largest 3D face covering a cell owns it, and a face stacked
on texels another face covers adds nothing. Faces below the floor and collapsed faces count in full. Stacking cannot
lower the owned shares; new unique texels cost page space, which the texture ceiling caps.

**Fragmentation** (islands per 100 u²) has a **proposed** ceiling, `fragmentation_proposed` (200; vanilla maximum 178,
the S18k Korean TC 372). It is a note, never a FAIL, until the owner confirms it.

**AoE3DE basis** (17 vanilla buildings, `Claude_CP2/gates/density_baseline.json`): all 15 non-large models pass
every rule, per model and per page. The lowest median is Med TC at 100.4, the worst share below 60 is West TC at 1.4 %
(2.51 % of a page's texel-owning area), and the most collapsed area is the China war academy at 2.7 % (b+c 3.18 %,
7.71 % owned). The vanilla cathedral (median 73) and basilica (60) fall below
the floor. The owner made it universal anyway, so a large building meets it through stacking, or through his waiver.

## Hard

- **No tolerance.** A value below a number FAILS. Schema 3 stores all density percentiles and gate shares
  at full floating-point precision; rounding is for display only. Schema 2 blocks used rounded gate values
  and must be remeasured, not relabelled as schema 3. This changes no helper function signatures.
- **INCOMPLETE is a FAIL, and no waiver clears it.** This covers a missing measurement, a page of unknown size, and a
  measurement made against another `face_floor`, in another unit or game, or with an older measurement schema.
- **Hidden faces count.** A page counts even if it is thought to be invisible (for example, the Korean TC's matc page).
- **Below the revised floor needs explicit owner GO for the model and texture.** The old blanket and natural-language
  keyword waivers are retired (INC-089). Every exception names a nonempty, unique list of actual current page names;
  omitted, empty or unknown names never waive. A list explicitly naming every current page is allowed. Pages outside
  the scope still have to pass. Incomplete evidence cannot be waived, including by GO.
- **Collapsed UV coverage cannot be waived by a density GO.** The original model-wide collapsed-area limit
  remains enforced even when every page is approved or raw remeasurement excludes the page containing bad UVs.

## Candidate-bound proposal and GO (r36, INC-089)

Use `make_proposal(metrics, floor, model, pages)` to prepare the exact evidence. It records the canonical model name,
actual page names and dimensions, measured page densities/shares, model median, full numeric-policy hash, full
measurement hash, and the geometry/UV candidate hash emitted by `measure()`. A different candidate, UV revision,
page size, measurement or policy requires a new proposal and GO. A prior worse/better candidate is not implicitly
approved. An old block without `candidate_sha256` must be remeasured before requesting an exception.

The waiver record is `{id, check: "density_floor", model, pages, proposal, at, recorded_by, ...approval evidence}`.
`proposal` is exactly the generated object; callers must not recreate or relax it. Two approval paths are supported:

1. **Whole owner message:** show the proposal and its density findings, then ask for the exact compact line returned by
   `proposal_go(proposal)`: `GO density_floor MODEL pages PAGE WxH, ... proposal SHA256`. Record the owner's whole
   message as `owner_quote` and its actual store id as `msg`. The verifier checks that message. Questions, refusal,
   generic `yes`, and arbitrary prose containing model/density keywords do not pass.
2. **Answered decision:** create a decision whose `density_proposal` is the proposal, whose `question` is exactly
   `proposal_question(proposal)`, and whose options include `{key: "GO", label: "GO"}` plus HOLD. Show that question
   with the proposal's full findings. The owner may answer `GO` or `GO DECISION_ID`. Capture the authentic message id
   and whole answer in the decision record: `{option: "GO", answer, msg, source: "chat MSG_ID", at,
   question_sha256: SHA256(question UTF-8)}`. The waiver references `{decision, option: "GO"}`. The verifier requires
   the owner's stored message and checks the question hash, proposal, option and any separate owner answer. An
   agent-written `record.option`, a HOLD answer, a conflicting owner answer or a later edited question never counts.
   The consuming decision recorder must preserve this question hash when the answer is captured; old task records
   lacking it are not automatically upgraded or treated as approval.

These helpers only prepare evidence. They do not generate, simulate or record an owner's GO. The owner-message
store and decision capture are the trusted evidence boundary; do not manufacture entries or attach an unrelated GO.
Canonical model/page identifiers avoid brittle parsing of arbitrary prose or ambiguous aliases.

Raw-face evaluation can remeasure with the approved pages excluded. A recorded block can clear those pages' own
findings only; it cannot recompute model-wide percentiles for a partial-page exception. A fully enumerated page scope
can waive the density findings of that exact complete measurement, but never its collapsed-UV coverage failure.
Export and handoff consumers retain their source
hash, page-budget and canonical revision checks. This is not permission to change geometry or textures.

## Measure and record

```text
python scripts/density_floor.py faces FACES.npz      # P (n,3,3), UV (n,3,2), page (n,) + names, W, H: any engine
python scripts/density_floor.py gr2 MODEL.gr2        # AoE3DE, through the consuming mod's GR2 reader
python scripts/density_floor.py block HANDOFF.json   # a recorded "density" block
python scripts/density_floor.py faces FACES.npz --model MODEL --propose-pages matA --json  # evidence only
```

Exit codes: 0 means PASS or WAIVED, 1 means FAIL, 2 means the input is unreadable. `--json` prints the metrics block.

A 03_uv `HANDOFF.json` in review or accepted status records two things (see the
[handoff contract](handoff-contract.md)): that block as `density`, and the page budget. `handoff.py write` refuses the
UV freeze while the floor fails. Measure after the final pack, on the runtime pages, at the model's export scale.

The same rule runs in more places:

- **At export:** the consuming engine's gate. In Age of Pirates this is `<consumer-root>/scripts/havok/gr2_lint.py`, check
  `texel_density`, on the intact and the damaged model.
- **In a version registry:** for example, the UV lineage gate's check e.
