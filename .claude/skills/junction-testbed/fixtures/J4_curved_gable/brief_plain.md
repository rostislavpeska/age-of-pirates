# J4: small hall with a curved roof and gable boards

- `Wall.Hall`: closed box, x -3 to 3, y -2 to 2, z 0 to 3.2.
- `Roof.Main`: sheet. Curved gable roof, ridge along x at y = 0, from x -3.4 to 3.4, height z = 4.4 - 0.9 u + 0.15 u^2
  with u = |y|, for u from 0 to 2.5 (it sags between ridge and eave). Sample the section at most every 0.25 m of y.
- `Gable.E` and `Gable.W`: closed gable boards 5 cm thick, centred on x = 3.0 and x = -3.0, filling each gable end
  above the wall top (z = 3.2) under the roof, for y -2 to 2.
