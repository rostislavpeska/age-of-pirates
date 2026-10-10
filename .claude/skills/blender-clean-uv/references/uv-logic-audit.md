# UV logic audit: catch illogical unwraps before texturing

Owner, 2026-10-10, on the Korean Dock plaster: "now we're paying the tax for shitty UV unwrap ... Some research how to
detect this illogical unwrap upfront."

## What went wrong

**Fragmentation.** Each plaster wall bay was built as a grid of separate panel objects around its windows. Each piece became its own UV chart:
- 30 planar walls had 146 owner charts.
- Example: the Store east bay, 1.12 m², had 11 objects and 10 charts.

**Sharing context.** Congruent pieces then shared texels. Members read texels painted for a place up to 6 m away.

**Rescue mismatch.** A later rescue mapped falsely hidden eave-band pieces onto the panel below them, 16 cm lower.

**Result.** The weathering is painted per texel from world position (height above floor, distance below the eave, edges, AO). It came out:
- duplicated;
- cut off at piece borders;
- stair-stepped, from hard thresholds at about 1 cm per texel.

## Why the existing checks passed

- **Density, overlap, integrity and coverage gates:** none of them looks at planar regions or at shared context.
- **The clean-UV skill:** it already says facade panels are built from adjacency, but nothing enforced that.
- **Sharing review:** it compared AO only, and its context helper is documented as having false negatives.

The research agrees: published tools stack UVs by shape similarity only. Houdini UV Stacker, RizomUV Similarity and Blender Copy Mirrored UV all match by shape. None checks that stacked pieces see the same world context.

## Principles

1. **A planar region flattens with zero distortion, holes included, so any seam inside it is pure cost.** OptCuts (Li et al. 2018), Autocuts (Poranne et al. 2017), Boundary First Flattening (Sawhney & Crane 2017), D-Charts (Julius et al. 2005), xatlas, UVAtlas and Smart UV Project all split on angle or stretch, never inside a plane.
2. **A texel holds one value.** Every layer driven by position, height, AO or eave distance needs an injective mapping. Stack only what is position-independent (Adobe forum: "the same part of the UV map has two different places in the position map"). Practice: bake AO and grime on unique UVs, or keep a second unique UV set.
3. **Bake thresholded masks as coverage, not as binary values.** Use supersampling, or a signed distance with a one-texel ramp (aastep; Green 2007, Valve). Keep gutters of at least 4–8 texels.

## Tests

`scripts/uv_logic_audit.py` implements T1 and T4. The others are the next candidates.

| Test | Measures | Threshold |
| --- | --- | --- |
| T1 planar fragmentation | coplanar, connected faces of one material across objects; owner charts per region | 1 chart per region (an intentional split is listed) |
| T2 rigid mapping inside a planar chart | per interior edge: scale, rotation and flip of the two faces' UV transforms | scale < 2 %, rotation < 0.5°, no flip |
| T3 texel density | px/m per chart | within 10 % of the page target |
| T4 stack context | for each member: the owner it actually reads (UV polygon containment); compare height, tilt, eave distance and AO | height within 1 texel (we use 5 cm); same tilt; AO difference < 0.05 |
| T5 visible seam on flat surfaces | seam edges with dihedral < 10° where both faces are visible at game pitch | 0 m |
| T6 seam value continuity | after baking, texel differences across seams | ≤ 4 (8-bit) |
| T7 band alignment | world-up in UV on wall charts | aligned to V; same sign everywhere |
| T8 minimum feature size | chart and mask features | ≥ 4 texels |
| T9 antialiased masks | 0 → 1 jumps between neighbouring texels | none |
| T10 island budget | charts per planar region, per object | ≤ 1.2 (quick screening) |

**Visual probe.** Write the baked world position into the BaseColor as height bands and along-wall stripes, then render. On a logical unwrap the bands are continuous; every fragmented or wrongly shared piece shows a jump.

## Evidence (Korean Dock, 2026-10-10)

| Revision | Planar regions failing T1 | Owner charts | Members | Context failures (T4) | Context warnings (> 0.5 m away) |
| --- | --- | --- | --- | --- | --- |
| r4 | 30/30 | 146 | 123 | 0 | 119 |
| r5 (with the rescue) | 30/30 | 146 | 161 | 30 | 130 |

In r5 all 30 context failures are eave-band rows reading the row below. Report: `korean-market-dock/dock_r5/qa/UV_LOGIC_AUDIT_r*.json`.

## Sources

- Seam and chart theory:
  - OptCuts: https://www.cs.ubc.ca/labs/imager/tr/2018/OptCuts/
  - Autocuts: https://vcg-legacy.isti.cnr.it/Publications/2017/PTHPS17/
  - Boundary First Flattening: https://arxiv.org/abs/1704.06873
  - Seamster: https://www.cs.ubc.ca/~sheffa/papers/VIS02.pdf
  - D-Charts: https://www.cs.ubc.ca/~vlady/dcharts/EG05.pdf
- Tools that chart by angle or stretch:
  - xatlas: https://codebrowser.dev/qt6/qtquick3d/src/3rdparty/xatlas/xatlas.h.html
  - UVAtlas: https://learn.microsoft.com/en-au/windows/win32/direct3d9/using-uvatlas
  - Blender UV: https://docs.blender.org/manual/en/4.4/modeling/meshes/editing/uv.html
- Shared UVs and seam filtering:
  - Unity UV overlap: https://docs.unity3d.com/2021.2/Documentation/Manual/ProgressiveLightmapper-UVOverlap.html
  - Adobe forum on position maps with shared UVs: https://community.adobe.com/t5/substance-3d-painter-discussions/artifacts-when-baking-mesh-maps/m-p/13048259
- Antialiased masks:
  - Seam erasure: https://cragl.cs.gmu.edu/seamless/
  - Valve distance fields (Green 2007): https://cdn.akamai.steamstatic.com/apps/valve/2007/SIGGRAPH2007_AlphaTestedMagnification.pdf
