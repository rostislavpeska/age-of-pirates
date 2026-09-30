# Universal UV texel-density floor (hard gate)

Owner, 2026-09-30: "Plus we need hard DPI floor!!!!!!!!!! Scattered UV map is a nightmare!!!!!! ... But UV map DPI
floor should be universal". The rule is the same for every model and every project. Each game has its own numbers in
[uv-density-floor.json](uv-density-floor.json), measured on its own shipped assets. A project overrides the numbers,
never the rule. Nobody edits a number so that a model passes.

## The rule

`density(face) = sqrt(UV area in texels² / 3D area)`, where the page is the texture the face samples (its BaseColor).
Percentiles are weighted by 3D area.

| id | Rule | AoE3DE number |
| --- | --- | --- |
| a | The model's median density is at least `model_median_min` | 100 t/u |
| b | At most `face_max_share_below` of the textured area sits below `face_floor`. This holds **for the whole model and for each page** | 2 % below 60 t/u |
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

- **No tolerance.** A value below a number FAILS.
- **INCOMPLETE is a FAIL, and no waiver clears it.** This covers a missing measurement, a page of unknown size, and a
  measurement made against another `face_floor`, in another unit or game, or with an older schema (before INC-035).
- **Hidden faces count.** A page counts even if it is thought to be invisible (for example, the Korean TC's matc page).
- **The owner's recorded waiver is the only exception.** It has the form `{id, check: "density_floor", model,
  pages?, owner_quote, msg, at, recorded_by}`, where `owner_quote` is his **whole** message, checked against his
  message store. A fragment never counts. The message must be **about this check and this model**: it names the
  density floor (density, DPI, texel) and the model (its name, or an alias the project records). "approve" or "yes"
  never waives (INC-036). Instead of a message, `decision: D-x, option` points at a decision the owner answered with
  that option, whose question names the floor and the model. With `pages`, only those pages are left out and the rest
  must still pass. Without `pages`, the waiver covers the whole check.

## Measure and record

```text
python scripts/density_floor.py faces FACES.npz      # P (n,3,3), UV (n,3,2), page (n,) + names, W, H: any engine
python scripts/density_floor.py gr2 MODEL.gr2        # AoE3DE, through the consuming mod's GR2 reader
python scripts/density_floor.py block HANDOFF.json   # a recorded "density" block
```

Exit codes: 0 means PASS or WAIVED, 1 means FAIL, 2 means the input is unreadable. `--json` prints the metrics block.

A 03_uv `HANDOFF.json` in review or accepted status records two things (see the
[handoff contract](handoff-contract.md)): that block as `density`, and the page budget. `handoff.py write` refuses the
UV freeze while the floor fails. Measure after the final pack, on the runtime pages, at the model's export scale.

The same rule runs in more places:

- **At export:** the consuming engine's gate. In Age of Pirates this is `scripts/havok/gr2_lint.py`, check
  `texel_density`, on the intact and the damaged model.
- **In a version registry:** for example, the UV lineage gate's check e.
