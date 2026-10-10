# J1: T-plan building

A main block with a wing on its north side.

- `Wall.Main`: closed box, x 0 to 10, y 0 to 6, z 0 to 3.
- `Wall.Wing`: closed box, x 3 to 7, y 6 to 11, z 0 to 3.
- `Roof.Main`: sheet. Gable roof over the main block, ridge along x, pitch 30 degrees, eaves at z = 3 on the wall
  faces, 0.5 m overhang all round. No gable triangles needed.
- `Roof.Wing`: sheet. Gable roof over the wing, ridge along y, pitch 30 degrees, eaves at z = 3 on the wall faces,
  0.5 m overhang at the eaves and at the north gable end.
