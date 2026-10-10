# J10: wall with a door opening, with UVs

- `Wall`: closed, x 0 to 4, y 0 to 0.3, z 0 to 3, with a door opening x 1.5 to 2.5, z 0 to 2.1 cut through its whole
  thickness (the opening reaches the ground, so the wall face around it is U-shaped). The wall is ONE closed mesh:
  the U-shaped face on each side is one flat surface, not a U plus pieces, and no faces are hidden inside the wall.
- Door frame: two jambs and a head, boards 0.08 m thick lining the opening, from y 0.05 to 0.25, leaving a clear
  opening 0.84 m wide and 2.02 m high (no threshold). One closed part `Frame` or several closed parts
  `Frame.<something>`.
- UVs for every part. The wall's front face is one UV chart, the back face one chart, each reveal face one chart, all
  mapped at the same scale in both directions.

The frame sits tight in the opening: its outer faces touch the wall's reveal faces (gap at most 5 mm, at most 5 mm
into the wall). The clear opening stays empty down to the ground.
