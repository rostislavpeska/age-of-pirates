# J9: wall with a window opening, with UVs

- `Wall`: closed, x 0 to 4, y 0 to 0.3, z 0 to 3, with a window opening x 1.4 to 2.6, z 1.0 to 2.2 cut through its
  whole thickness. The wall is ONE closed mesh: the face around the window on each side is one flat surface, not
  pieces around the hole, and no faces are hidden inside the wall.
- Window frame: boards 0.08 m thick lining the opening on all four sides, from y 0.05 to 0.25 (set back 5 cm from
  both wall faces), leaving a clear opening of 1.04 x 1.04 m. One closed part `Frame` or several closed parts
  `Frame.<something>`.
- UVs for every part. The wall's front face (with its hole) is one UV chart, the back face one chart, each reveal
  face one chart, all mapped at the same scale in both directions.

The frame sits tight in the opening: its outer faces touch the wall's reveal faces (gap at most 5 mm, at most 5 mm
into the wall). The clear opening stays empty.
