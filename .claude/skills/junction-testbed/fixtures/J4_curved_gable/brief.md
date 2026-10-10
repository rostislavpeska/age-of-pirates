# J4: gable boards under a curved roof

- `Wall.Hall`: closed box, x -3 to 3, y -2 to 2, z 0 to 3.2.
- `Roof.Main`: sheet. A curved gable roof, ridge along x at y = 0, the same section everywhere along x, from
  x -3.4 to 3.4. Its height is z = 4.4 - 0.9 u + 0.15 u^2 with u = |y|, for u from 0 to 2.5: ridge 4.4, 3.2 at the
  wall faces (u = 2), 3.0875 at the eave edge (u = 2.5). The slopes sag (concave upward). Sample the section at
  most every 0.25 m of y.
- `Gable.E` and `Gable.W`: closed boards 5 cm thick, centred on x = 3.0 and x = -3.0 (x 2.975 to 3.025 and -3.025 to
  -2.975). Each fills the gable end: from the wall top (z = 3.2) up to the roof, for y -2 to 2.

The top edge of each board follows the curved roof just under it: 1 to 5 mm below the roof along most of its length
(never exactly on the roof surface, never more than 1 cm below), and it never passes through the roof (at most 5 mm). Board outlines must be simple shapes (never crossing
themselves) and the boards closed with faces pointing outward.
