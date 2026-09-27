# Evidence and unresolved limits

## Later accepted checkpoint

The user subsequently approved continuation after the proxy/exposure aftercheck
and physical-overlap cleanup: interior recognition was "good enough for now",
explicitly imperfect. See [that measured process](proxy-aftercheck.md). False
positives/missed interiors remain quality debt. This supersedes the earlier lack
of local allocation acceptance below, but not its warnings about general automation.

## Original Hybrid evidence

Status on 2026-09-27: user inspected all five editable Blender scenes and preferred
method 5, Hybrid, then requested this dedicated skill. It is a reusable experimental
workflow; no blanket acceptance of all face assignments or automated density loss.

The measured Korean Town Center had 5,233 original polygons. The live authoring
mesh and UVs were preserved. No source triangles were introduced; read-only analysis
tessellation mapped back to original polygons. Blender 5.1.2 was used.

| Approach | Candidate faces | Marked-soffit proxy area recovered | Withheld exposed candidates |
| --- | ---: | ---: | ---: |
| Images | 2,063 | 81.3% | 23 |
| Rays | 1,989 | 81.3% | 8 |
| Paired surfaces | 656 | 58.4% | 152 |
| Voxel enclosure | 4 | 0% | 0 |
| Hybrid | 1,966 | 81.4% | 5 |

Training: 96 views at 640²; independent validation: 51 offset views at 960²;
36 image stress views at 10°, 20°, 85°. Rays also used 72 stress directions.
The 30–75° training envelope remains provisional. Alpha was protected and omitted
as an occluder. None of these finite sets proves universal concealment.

The soffit proxy was assistant-curated from the user's marked regions (671 faces),
not accepted face-by-face ground truth. Another 1,201 art controls included some
ambiguous hidden pottery surfaces; 3,361 faces remained unlabeled. Hybrid still
disagreed with 21 controls and exposed five candidates in withheld views. These
numbers are review risks, not a whole-building accuracy score.

Eight synthetic sets covered roof slab, open roof, curved roof, opening, sealed
room, open box, alpha and thin fin. Intended construction roles sometimes differ
from actual exposure through openings. Keep role labels separate from visibility.
The voxel prototype missed nearly all soffits, with 250 faces unstable under grid
changes; do not generalize this as a failure of all voxel methods.

Measured original building computation was about 42.2s rays/pairing, 4.7s images,
5.7s voxels including JIT, and subsecond graph solving on the test device. These
are observations, not timing guarantees. Cache matching evidence to limit cost.

Packaging verification on the same date: ten invariant tests passed; the packaged
classifier reproduced exact candidate and withheld-exposure IDs on all nine saved
datasets. Fresh packaged image, voxel and ray measurements reproduced the building
evidence exactly and yielded the same 1,966 Hybrid candidates. The snapshot helper
exported all 5,233 original polygons on a background copy. Metadata/resource checks
passed. These establish implementation fidelity, not new artistic approval.

## Lessons that change the next run

- Downward normal alone misses sloped undersides and can blacken visible sides.
  A conservative reversal that detects only certified burial misses broad soffits.
- Combine evidence and adjacency; preserve uncertainty instead of oscillating
  between two overconfident binary heuristics.
- A screenshot of a method is not the requested interactive Blender deliverable.
  Multiple requested alternatives must actually be loaded, selectable and named.
- Black is a shared-backing allocation proposal. Camera-hidden faces can still
  influence shadows/AO or become visible during destruction. Preserve damage
  interiors and their state-specific mapping.
- Keep the material-family checkpoint independent of unwrapping. Do not spend
  another texture/UV iteration before this face allocation is accepted.
- Future automation needs a second building, calibrated camera/terrain/shader
  behavior, mixed-polygon handling and measured low-resolution visual quality.

Consumers retain their own source snapshots, render evidence, feedback and defect
register outside runtime folders. The skill bundles algorithms and parameter
defaults, not proprietary building geometry, screenshots or machine-specific paths.
