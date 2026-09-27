# Regional prototype review

The September 27 regional review adds three editable Blender scenes: Previous,
Regional and RegionalBroad. The session script `regional_controls.py` exposes
comparison, isolation and checker controls in the UV Review sidebar. Its script
is also saved in the blend as REGIONAL_REVIEW_CONTROLS; registrations are local
to the launched Blender session, not an installed add-on.

Four explicit roof policies control fold limits, chart size and reflection.
Undersides receive provisional planar UVs; contiguous charts are aligned and
accepted only when valid and non-overlapping. Hidden-only charts can adopt an
adjacent visible chart's density within a factor of 0.25 to 4. This is an
experimental diagnostic atlas, requiring texture and tangent-normal validation.
Cross-material and hidden inclusion are enabled in this prototype; disabling
those policy flags is not implemented yet.

| Roof | Previous all-face islands | Regional | Broader |
|---|---:|---:|---:|
| Lower tower | 220 | 72 | 68 |
| Upper tower | 230 | 56 | 56 |
| Rear hall | 276 | 57 | 57 |
| West hall | 283 | 58 | 58 |

All-face counts include originally hidden faces. Counts touching originally
visible faces for the lower tower increase from 50 to 68 (broader: 64), and upper
tower from 46 to 53. This is a material tradeoff, not a universally better result.
Some invalid seed charts were reinitialized, so this experiment is not merely
joining existing islands. The acceptance decision remains open for visual review.

Independent reopen audit confirms all 5,234 unique face IDs in each scene, no
authored triangles, CandidateUV errors below 1.2e-7 and exact correspondence
between roof ChartID membership and native Blender UV connectivity. Construction
checks found maximum additional position drift 5.25e-6 and custom-normal vector
error below 0.001. The original ten regression tests pass. No automated metric
substitutes for the user's visual judgment on whether these seams are sensible.

Blend, rendered previews, JSON candidates and audit reports are outside the repo
in the Korean Buildings Blender snapshot `2026-09-27-regional-roof-review`.
The original comparison and the other agent's Blender process remain open.
