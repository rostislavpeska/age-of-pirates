# The LowPoly (_lp) LOD

Measured 2026-10-10 on vanilla animfiles and models (method in [vanilla unit measurements](vanilla-unit-measurements.md)).
Scripts: counts `scripts/measure_units.py`, legacy fill `scripts/vertex_fill.py`, mirrored UVs and head share
`scripts/shape_metrics.py --what uv,regions`, the legacy texture names `scripts/texture_pages.py gr2`.
The generic LOD method is in [blender-organic-modeling](../../blender-organic-modeling/references/lod.md).

## 1. The animfile switch

A model component chooses the LOD with a `LowPoly` logic inside each tech branch. From
`asians/chinese/iron_flail/iron_flail_rider.xml`:

```xml
<component>ModelComp<logic type="Tech">
    <none>
      <logic type="LowPoly">
        <normal>
          <assetreference type="GrannyModel">
            <file>units\asians\chinese\iron_flail\iron_rider_0</file>
          </assetreference>
        </normal>
        <lowpoly>
          <assetreference type="GrannyModel">
            <file>units\asians\chinese\iron_flail\iron_rider_0_lp</file>
          </assetreference>
        </lowpoly>
      </logic>
    </none>
    ...
```

No file read states what condition selects the `<lowpoly>` child (unknown; do not guess a zoom distance).

## 2. Who uses it

| Use | Units |
| --- | --- |
| Rider LowPoly logic | iron flail, steppe rider, naginata rider, yabusame |
| No LowPoly logic, although `lp_*` files ship unreferenced | keshik rider, hussar, dragoon |
| Horse: the full model in both slots | iron flail, steppe rider, naginata rider |
| Horse: a real LP | yabusame (`yabusameHorse_0_lp`, `_2_lp`), keshik (`lp_keshik_horse_rank0X`) |

## 3. The LP files are legacy

- 2007-era meshes with exporter material names (`oprichnik 3age map`, `Material #62`); no unit `_lp` gr2 has a DE
  `.material`. The only `*_lp*.material` files under `Art/units` belong to special heroes (58 hits for
  `*_lp.material*` / `*lp_*.material*`, the rest are trees).
- The textures they name are legacy `.ddt` files: 64 x 64 for riders, 128 x 128 for horses.
- UVs mirror 22-57 % of their area and stack 41-96 % of texels (DE full-LOD bodies: 0 % mirrored, 0.0-0.3 % stacked;
  the stacking figures' script was not kept).
- Legacy fill: Normal and Tangent w = -70, vertex colour 127/129, zero-weight slots pointing at index 0.
- `iron_rider_1` and `iron_rider_1_lp` ship but no animfile uses them; `lp_keshik_horse_rank0X` is a mesh named
  `stagecoach_horse` on a 45-bone `HS Bone Master` rig, while the normal keshik horse uses the 32-bone `root_x` rig.

## 4. LP numbers (the 10 referenced LP riders)

- 200-262 triangles (median 228.5); welded vertices 256-419; shipped GPU vertices 352-592; unique positions 124-173.
- LP / full triangle ratio 0.17-0.21 per pair (mean 0.19). Across all LP files measured: 161-293 triangles.
- Maximum 2 influences on every Asian LP (legacy European LPs 2-4); 61-88 % single-influence; 0-5 blended positions
  per knee (the iron LP knee has none).
- Head share 10-19 % of positions (full model 19-27 %).
- LP / full bounding box per axis 0.91-1.10; height 1.008-1.061 (LPs are never shorter; the excess is probably a
  legacy leftover, not a target).
- Skeletons can differ from the full model's (see [rider skeleton](rider-skeleton.md), section 4).

## 5. Options for a new unit

1. **No LowPoly logic**: the keshik, hussar and dragoon precedent. The minimum deliverable.
2. **The full model in both slots**: the horse precedent; changes nothing visible, keeps the grammar.
3. **A real LP**: built by hand from the full model, on the donor LP's own skeleton, at most 2 influences,
   0.17-0.21 of the full triangles, sharing the full model's 1024 page through UV0 or with a small page of its own.
   No vanilla unit has a DE-material LP, so this route must pass a bench test
   ([aoe3de-model-test-unit](../../aoe3de-model-test-unit/SKILL.md)) before it is relied on.

The owner decides; record it in the handoff. Never copy the legacy LP setup (64 x 64 textures, mirrored UVs, legacy
fill), and never ship an automatic Decimate to about 20 % as the LP.

Check: in the animfile, LowPoly logic is absent, or both children name existing files and a `<lowpoly>` file that is
not the full model has a `.material` next to it; an LP passes the generic LOD checks and the numbers above.
