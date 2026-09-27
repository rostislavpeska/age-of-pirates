# Room proxies followed by exposure checks

## Accepted scope

Korean Town Center, 2026-09-27: after reviewing the repaired S7 exterior and entering
the building, the user accepted the inside as approximately good and sufficient to
continue. This is a practical local allocation checkpoint, not perfect detection,
a universal false-positive rate, or approval to delete hidden geometry. Some
interior surrounds stay detailed and small shared cores can be glimpsed through
assembly gaps. Record these debts rather than relabeling them invisible.

The bundled Hybrid classifier remains the reproducible first pass. This additional
consumer-tested procedure is not yet packaged as a general automated room finder.

## Ordered process

1. Resolve competing physical surface ownership with `blender-overlap-cleanup`.
   Duplicated posts and layered wall boxes corrupt visibility evidence and create
   misleading black/color stripes. Keep intact and destruction closure separate.
2. Preserve face ancestry, semantic materials, UVs, normals and weights. Treat
   underside evidence and authored simplified room volumes as proposals. An empty
   in a room is a probe, not sufficient evidence that every face facing it is hidden.
3. Sample membership across face extent. A centroid, bounding-box overlap, or normal
   alone cannot distinguish broad interior panels from exposed rims/beam sides.
4. Record front-facing exterior exposure using face IDs plus front/back information.
   Seeing the back of an exterior polygon from inside does not make that polygon an
   interior receiver. Keep alpha cutouts protected unless the actual mask is sampled.
5. Small exposed or mixed beam sides, wall returns, narrow roof borders and decorative
   ends stay coherent and detailed. Avoid tiny cuts for negligible atlas savings.
6. Broad mixed floors/panels may retain a hidden rectangular core. Protect measured
   exposure with a margin, then select a large empty rectangle in panel coordinates;
   use a bounded number of construction-aligned cuts. Surrounding exposed regions
   retain their physical material/detail allocation. Do not pixel-tessellate faces.
7. Interpolate UVs/weights only at new corners. Preserve encoded corner normals where
   possible; needless reapplication can quantize them. Check area, winding, boundary
   length and vertex growth. Preserve quads/ngons and record original-face mappings.
8. Agent inspects matched images from every exterior side, all rooms, low/high angles,
   underside, floor rims, tower corners, openings and roof-wall joints. A numeric
   pass does not replace this. Return one consolidated packet and an active candidate.

## Measured example parameters, not universal defaults

- Exterior sweep: 24 azimuths at elevations 10,20,30,45,60,75,85 degrees, 960-square
  ID buffers; two front-facing pixels protected ordinary small faces.
- Offset sweep: 19 azimuths at 13,33,52,71 degrees, phase 0.127, 1100-square buffers.
  It was used to revise the candidate, so it is **not an untouched validation set**.
- Broad panel: minimum area 1.5 scene-square units; 24x24 exposure grid; one-cell
  protection dilation; largest empty axis-aligned rectangle; core area >=0.6,
  core fraction >=0.25; border >=0.06 scene units; at most four cut planes.
- Floor core: additional 0.12-unit clearance. Two cores retained 30 and 35 pixels
  of hairline exposure at 1100-square resolution, no solid 3x3 pixel patch, no
  training hits. The experiment tolerated <=64 such pixels. This is low-detail
  allocation tolerance, **never a deletion/invisibility certificate**.

The candidate split 43 original polygons (+147 vertices, +82 polygons), with no
authored triangles. Twenty-eight panel cores retained about 53.98 scene-square
units of shared area. Six hidden material families remained distinct. These are
case measurements, not performance/quality guarantees for another building.

## Handoff and reuse boundary

Keep hidden physical materials separate even while all display black. A later
explicitly authorized shared hidden atlas may overlap these faces freely **within
each physical family**, without geometry/AO equivalence. Visible detailed charts
need separate geometric and eventual shading compatibility checks. No allocation
acceptance alone authorizes UV packing, lower density, or new texture work.

For inspection inside solid walls use perspective with a small scale-appropriate
near clip and Dolly/Walk; keep X-ray off. If native framebuffer capture is black,
record that failure and use Blender viewport renders for visual evidence, without
claiming they prove every UI overlay. Never replace the user's live file with a
background result; append and activate the verified candidate instead.
