# J3: hall roof ending against a tower

- `Tower`: closed box, x -2 to 2, y -2 to 2, z 0 to 10.
- `Wall.Hall`: closed box, x 2 to 8, y -1.5 to 1.5, z 0 to 3.5. It stands against the tower's east face.
- `Roof.Hall`: sheet. Gable roof over the hall, ridge along x at y = 0, pitch 30 degrees, through z = 3.5 at the
  hall's wall faces (y = -1.5 and y = 1.5), overhanging 0.4 m horizontally at both eaves and at the east gable end
  (x = 8.4), continuing the slope.

At its west end the roof stops exactly at the tower's east face (x = 2): no gap (at most 5 mm), and it may tuck at
most 2 cm into the tower, never through it. The roof meets the tower face along its full width, eave to eave. The
hall wall meets the tower the same way.
