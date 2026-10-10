# J2: two crossing hip roofs

Roofs only (no walls in this task). Both are hip roofs: four slopes, pitch 35 degrees, rising from the eave line at
z = 3 above the wall line and overhanging 0.6 m horizontally beyond it, continuing the same slope.

- `Roof.Main`: sheet. Wall line x -5 to 5, y -3 to 3 (so the roof plan is x -5.6 to 5.6, y -3.6 to 3.6). Ridge
  along x.
- `Roof.Cross`: sheet. Wall line x -2 to 2, y -6 to 6 (roof plan x -2.6 to 2.6, y -6.6 to 6.6). Ridge along y. It is
  narrower, so its ridge is lower than the main ridge.

The cross roof runs across the main roof and out on both sides. Where both roofs exist, only the higher surface may
remain: the roofs meet in four valleys with no gap (at most 5 mm), and neither roof continues under the other (at
most 5 mm). Both roofs keep their full plan outside the crossing, hipped ends included.
