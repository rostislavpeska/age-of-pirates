---
name: alpha-cutout-texturing
description: Build and verify texture cutouts on game assets, including eaves, fringes and openings. Use for leftover rims, mismatched cuts, shared-pixel conflicts or cutouts that fail in compressed mipmaps.
---

# Alpha cut-out texturing

Built on the Korean Market stall thatch and eave rounds of 2026-10-11, where the owner reported "the seams are not
matching... the corner is redundant" on a 13 cm straw slab, and an eave band that only the viewer drew. The core rule:
**the geometry and an analytic mask own the silhouette; the image model only paints colour.** A cut is one function of
the surface's own coordinates, so it runs through every face of a thick part.

## 1. What the game draws

- **Only a cutout material def cuts.** The `.material` def decides what BaseColor alpha does: `*cutout*` (and
  `speedtree\*`) cut; `default`, `default_doublesided` and `destructible` ignore alpha and draw a solid card
  ([aoe-xml](../aoe-xml/SKILL.md) rule 8). Copy the donor's def per submaterial.
- **Single-sided.** The game culls back faces unless the def is double-sided. Through a cut you see whatever FRONT
  faces lie behind it, never the inside of the slab.
- **Pages.** Cut-outs live on the small alpha page (DXT5 BaseColor alpha); the large page stays opaque (DXT1)
  ([blender-uv-workflow](../blender-uv-workflow/SKILL.md), alpha on the small page).

## 2. The silhouette is analytic

- Build the cut from geometry or a seeded mask: per-strand straw tips (`fringe_depth`: low-order sines plus a per-strand
  power-law tail, 2-14 cm deep), tile scallops from the tile row, lattice holes from the panel's bars. Never let the
  painting decide where the alpha is.
- Hand the image model the layout with the cut region flat, and gate the painting on its structure (strand direction,
  rope recall, silhouette registration) before composing ([masonry-texturing](../masonry-texturing/SKILL.md) section 7,
  [image-harness](../image-harness/SKILL.md)).

## 3. Thick parts: cut through, not skin-deep

A thatch or straw eave is usually a slab: one profile (top, back, underside, often a rounded bullnose) extruded along the
eave, with two end caps. Texturing each face in its own frame produces two defects at once:
- **seams** where neighbouring faces sample unrelated parts of the painting;
- **a leftover rim** where the top is cut but the nose and underside stay opaque. The rim reads as a "redundant corner"
  under the fringe.

Use one folded parameterisation for the whole slab ([`scripts/slab_fold.py`](scripts/slab_fold.py)):

1. **Inspect the profile.** Run [`scripts/slab_profile_map.py`](scripts/slab_profile_map.py) in background Blender. It
   writes the per-face page px to 3D maps, the outline in slab coordinates (lip first, top first, a rounded nose ending
   at the lip) and the shared edges.
2. **Assign one coordinate pair.** `v` is the slope coordinate of the nearest outline point. Top and underside both read
   `v = s`, so the straw seen from below lies under the straw seen from above. The nose takes its inner vertices by arc
   length, so `v` stays monotone.
3. **Let the end caps continue the top.** Use `us = u + depth x (1 - 2u/W)`. The end caps then carry the top's straw
   straight down over the end, and the shift meets the underside, back and nose on the same columns. Folding the caps at
   mid-thickness was also continuous, but the mirrored straw angles read as a herringbone.
4. **Apply one cut function `cut(us, v)` to every face.** The fringe then removes the nose and the front of the
   underside together with the top's tips.
5. **Choose a variant per part.** Use the cut fringe for a thin, light eave. Use a rolled eave (no cut; the straw
   wraps the nose with `v` mirrored at the lip) where a thick edge is wanted.

At grazing angles a slab cut through can look hollow: you see its far side's back faces culled. At RTS camera pitch the
top hides it; check the low review view anyway.

## 4. Seam QA (fails the run)

Scope the result to the supplied asset, contour, readers and stage. Consume the
same source identities and selected regions as the composing recipe. A failed
contour blocks its dependent bake/release; it does not authorize UV relocation
or prove every texture-only solution impossible. Record inherited defects
separately from new regressions. For a colour-only patch, first prove alpha
identity; do not invent a new silhouette merely to perform the check.

Keep evidence-tool completion separate from the nested asset verdict. Report
the actual page/reader failures even when the command itself exits successfully.
Fixture tests, real-asset adapter execution and release checks are distinct
proofs; do not report their aggregate as a finished model.

Before a new bake, project the independent silhouette onto **every face reading
the affected pixels**, including mirrored/reused back and underside faces. An
atlas-owner mask can pass while another reader at a different depth needs the
opposite alpha. Run `scripts/alpha_reader_gate.py samples.npz --out preflight.json`
before the bake and add `--alpha decoded_runtime.png` afterward. Its input schema
is documented in the script. Record the complete reader inventory from the LOW,
never from candidate alpha. Boundary tolerance is measured in the destination
texel footprint; do not remove failing faces from the inventory.

A real face may touch texel cells while containing no texel centre. Keep it in
the geometric inventory and use polygon/cell intersections plus a separate
continuous expected-alpha bound. Never convert an empty sample list into a
visibility exemption or drop it from a positive release. A constant projection
frame makes depth affine over a triangle: vertex extrema can certify its whole
depth range. This narrow proof does not generalize to varying frames or contours.
The Python `measure(..., certificates=..., certificate_inputs=...)` API now
consumes the narrow `constant-station-opaque-v1` certificate described in
`verify_certificates` in that script. It rehashes current mesh/frame/contour/page
sources, matches exact reader/triangle/UV/page identities, rejects duplicate or
missing triangle certificates, recalculates positive-area cell intersections and
the absence of centres, and evaluates the source-identified contour against the
affine vertex-depth bound. Cells remain separate constraints; sample counts stay
unchanged and conflicts with other readers or fixed alpha still fail.

The independent geometry adapter must supply every triangle of each missing
reader and establish its correspondence to those sources and material bindings.
Never build `certificate_inputs` by copying certificate assertions. The generic
gate verifies the mathematical proof and identities, not a project's extraction
or inventory completeness. A PASS string in an input is not evidence. Only
constant lateral stations, whole-triangle opacity and bounded in-page triangles
are supported; varying frames, transparent proofs and shader filter footprints
remain outside this contract.

Verification: 20 unit tests (8 existing plus 12 certificate tests), and one
source-checked saved Market fixture: 0 centres, 2 cell constraints, missing matc
reader restored to the inventory while 16,444 shared conflicts and 22,841 fixed
mismatches remain unchanged. The consuming civic CLI now reconstructs current
independent inputs and exercises this API: 16 adapter tests pass; one fresh
real-source command accounts for all 1,396 readers in 29.562 seconds. Four invalid
proof controls are rejected and all 16 strict negative witnesses are preserved.
The contour still FAILS; command exit 0 means evidence generation completed,
not asset release. No runtime or Blender asset was changed by these checks.
The generic CLI itself still accepts sample arrays; certificate bundle ingestion
belongs to the consuming adapter, whose R2 receipt records this integration.

Conflicting interior requirements fail before texture work. Keep the frozen source
and report the incompatibility; taking the minimum/maximum alpha only moves the
defect to another face. Shared protected pages need a separate required-cut report.
An opaque back face may be exempted only with exterior visibility evidence for all
consuming states, not from its name, normal direction, or an owner-only mask.
For an immutable protected page, supply its independently decoded installed alpha
with `--fixed-alpha PAGE.png`. The gate then treats it as a fixed constraint and
fails on any interior mismatch even when the proposed readers agree with each
other. Reports include exact totals and up to 16 texel/reader witness pairs; their
sample indices link back to the geometry adapter's NPZ. A failure proves the
**supplied contour** incompatible with the stated samples and freezes. It does
not establish that every possible contour is impossible, nor grant permission to
edit the protected page. Project adapters must use actual per-page dimensions,
resolve current material bindings, and keep nonzero boundary samples in inventory.
Regression: one candidate passed 75,416 owner samples but failed 3,633 reused
reader samples. The expanded all-face fixture exposes 3,343 contradictory texels.
Run `python -m unittest discover -s scripts -p test_alpha_reader_gate.py`.

`slab_fold.py qa --profile PROFILE_MAP.json --basecolor PAGE_BaseColor.png` compares the colour step across every shared
edge with the same-distance step inside the two faces: bilinear sampling, 6 and 18 mm inside each face, only where all
four samples are opaque. Pass: each edge ≤ 2.0×, mean ≤ 1.3×.

On the Market stall: the old per-face compose scored mean 3.37 and worst 17.3 (end cap against bullnose), which fails.
The fold scored .87 and 1.26, which passes. Keep the strand-direction QA as well
([blender-architecture-texturing](../blender-architecture-texturing/SKILL.md) `check_material_direction.py`).

## 5. Colour under alpha, gutters and mips

- Cut texels keep the material colour sampled just inside the cut, never the painting's background. Bilinear filtering
  and mips average across the cut, and a grey or dark background grows a halo round every strand tip.
- Extend island colour only into its declared, unoccupied gutter territory before mip generation
  ([aoe3de-building-export](../aoe3de-building-export/references/textures-xml.md)). A historical 48 px dilation
  is valid only where reserved space permits it; never overwrite another chart to meet that number.
- Alpha-tested fringes thin out in lower mips, because averaging moves texels below the threshold. Before shipping,
  measure the opaque fraction of each fringe region at every mip level of the encoded DDT. If a fringe vanishes at game
  distance, preserve the coverage when building the alpha mips. This has not yet been verified on the project encoder.

Use [`scripts/alpha_mip_coverage.py`](scripts/alpha_mip_coverage.py) with decoded
compressed mip images, the immutable source alpha and geometry-derived region masks.
Declare one region per independent strip/island: a healthy whole-page average can
hide a vanished small strip. Check both shrinkage and gap filling. The helper also
reports silhouette IoU, lost opaque samples and filled cutout samples. Do not use a
mask inferred from the tested alpha: it would exclude the holes being checked.

The JSON configuration names `source`, `threshold` (normally 0.5), `regions`
(`name`, `mask`) and `mips` (`level`, `image`). Bounds are explicit per mip:
`min_retention`, `max_retention`, and `max_empty_coverage` for deliberately removed
surfaces. PNGs must contain alpha or be L-mode alpha images. Masks use the same
dimensions/orientation as the source. Run:

```
python scripts/alpha_mip_coverage.py config.json --out report.json
python -m unittest discover -s scripts -p test_alpha_mip_coverage.py
```

Exit 0 passes only declared gates; exit 1 reports failures; exit 2 means invalid
input or a diagnostic with no acceptance bounds. Ungated mips stay labelled
DIAGNOSTIC. Keep actual-size camera renders alongside the measurements: bilinear
samples at fixed source UVs do not certify projected, trilinear or anisotropic
game rendering. Do not raise alpha globally to fix a strip: doing so can close
other cutouts or resurrect intentionally removed faces. No automatic encoder or
atlas mutation is performed by this helper. It needs NumPy and Pillow; the
destination-engine adapter supplies decoded mip images.

## 6. Normals on a folded parameterisation

Sample the relief height through the same fold, then differentiate it in **page space**. Page space is already the UV
tangent frame (x = +U, y = +V, page rows run down), so this stays exact on folded end caps, where a per-face sheet-to-UV
rotation is only approximate. Match the relief scale to the previous accepted map's measured slope.

## 7. Hidden surfaces behind cuts

A face classified hidden (backing atlas) can still show through a cut. Run
[blender-uv-workflow](../blender-uv-workflow/SKILL.md)'s `alpha_backing_check.py` on every alpha page.

## 8. Review and variants

- **Single-sided review:** set `use_backface_culling` on every review material, with the alpha blend or clip mode the
  game uses. A double-sided viewer showed back faces plugging every eave scallop that is open in game, so the owner saw a
  solid band.
- **Views:** render each cut-out part from the top, owner (RTS pitch), low front, side (end caps) and eave front.
- **Variants:** when the owner asks for options, compose each variant into its own copy of the page and publish it as
  its own scene. Every variant must pass the seam and direction QA before it is shown.

## Failure log (Korean Market stall thatch, 2026-10-11)

| Defect | Cause | Fix |
| --- | --- | --- |
| Straw stood upright on the end caps | A vertical frame on the end caps, 70° off the fall line | Direction QA against the fall line |
| Seams (owner) | Each face had its own frame: caps shifted by .37 of the sheet, edges painted as end grain | One folded parameterisation |
| A redundant rounded edge under the fringe (owner) | The cut was skin-deep; the opaque bullnose remained | Cut through the slab with one `cut(us, v)` |
| Herringbone on the end caps | The caps were folded at mid-thickness, mirroring the straw angles | Carry the top's straw straight down the cap |
| A solid band behind the eave scallops | The review viewer was double-sided | Single-sided review |

Worked example (project recipes): Korean repo `research/Junction_TestBed_21/market_r1p/recipes/market_thatch_fold.py`
and the card `patterns/korean/thatch.md`.

Run the fixtures from this skill's `scripts/` folder: `python -B -m unittest test_slab_fold -v`.
