# Offline paired-surface probes

`scripts/paired_surface.py` provides small read-only NumPy operations for frozen
triangle data already exported into one physical frame. This supplements
`texture-corner-seams/scripts/seam_monitor.py`; that tool still owns bilinear
texture sampling and colour-seam metrics. It does not replace the complete
[geometry contract](geometry-contract.md) or claim automatic valley discovery.

- `exact_edge_pairs(co, uv, selected, decimals=6)` pairs spatially identical
  complete triangle edges across disconnected UVs and duplicated vertices.
  It returns ambiguous edges separately. It neither edits/welds the source nor
  matches partial overlaps or near-parallel edges. Quantization is explicit.
- `edge_probes` moves corresponding edge points a physical distance inward;
  every probe reports whether it remains in its own triangle.
- `barycentric` maps physical probes to UVs and returns plane residual.
- `normal_to_physical` uses the UV derivatives and interpolated corner normals
  to compare +Y tangent normals in one frame, including chart rotation/mirroring.
  This is a triangle-frame diagnostic, not a claim of exact engine/MikkTSpace
  tangent recalculation. Runtime green flips must already be decoded.

Run `python -m unittest discover -s .claude/skills/blender-roof-baking/scripts
-p test_paired_surface.py -v`. Five controls cover a duplicated split boundary,
an ambiguous three-sided edge, interior/exterior probes, rotated/mirrored
normal frames (including the wrong-sign negative), and degenerate UV rejection.

## Reader completeness

An archived reader table may omit writers. Combine writer positions and reader
positions before declaring sharing compatible or drawing a physical inventory.
Report per-side counts, all conflicting face/pixel identities, and existing
versus desired semantic surface roles. Owner-only bake coverage does not prove
that a top reader may safely consume an underside writer.

Before attributing a band to a local patch, sample the same physical area in
every retained stage. A patch with zero changed samples in that area is not its
source. Test a bounded phase/count hypothesis before proposing a frozen-UV
exception; do not move UVs, repaint a distant protected reader, or omit half a
valley merely to satisfy a containment check.

Evidence: KTC-377, journal `2026-10-13-roof-consulate-valley-01` through `-07`.
One specimen's measured proof is not a universal release gate. Compression,
visibility, all-tangent correctness, phase completeness and art acceptance stay
separate until their own checks are supplied.
