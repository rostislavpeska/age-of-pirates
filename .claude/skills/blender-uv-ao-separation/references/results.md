# Korean TC results (S17, 2026-09-28)

Input: S16 (clean charts, frames split, T3 conjoinment at original UV scale).
AO radius 0.5 unit, 256 rays; risk = |member AO - owner AO| at shared texels.

| Test | Families A | Page A (orig. scale) | Member texels err > .20 | Visual (owner-only bake vs unique reference) |
| --- | --- | --- | --- | --- |
| none (plain T3) | 89 | 2782 | 46% | black streaks on roofs and eaves |
| D1 mean | 243 | 3060 | 15% | stains remain |
| D3 SSIM | 274 | 3283 | 10% | a few stains |
| D4 classes | 189 | 2881 | 25% | stains |
| D2 p95 on 6x6 bins | 397 | 3777 | 6% | big areas fine; lost door-knob dots, wrong panel gradients, ghost dots on wall bands, beam ends wrong |
| D5 combined (bins) | 334 | 3751 | 5% | as D2 |
| **D6 point-to-point** | 651 | 4946 | 2.9% | matches the reference in all four low close-ups |

With the export skill: D6 families on a 2048 + 1024 pair reach a uniform 118
texels/unit (vanilla Japanese/Chinese town centres: 116-137).

## Lessons

- The owner's own review found what bins missed: beam ends, a wall band with ghost dots
  and dark corner squares. Owner's suggestion (subdivide faces, compare sub-faces) is what
  the point test does without changing geometry.
- Sampling must guarantee points on small faces: a 12-texel grid alone gave beam ends one
  sample or none.
- Research summary (literature subagent): mean catches darkness only, SSIM structure
  catches shape only, max/percentile per texel catches both; complete linkage guarantees
  every pair in a group within tolerance (minimal group count is NP-hard).
