# J1: T-plan building, two gable roofs meeting in valleys

A main block and a wing form a T in plan.

- `Wall.Main`: closed box, x 0 to 10, y 0 to 6, z 0 to 3.
- `Wall.Wing`: closed box, x 3 to 7, y 6 to 11, z 0 to 3.
- `Roof.Main`: sheet. Gable roof over the main block, ridge along x at y = 3, pitch 30 degrees on both slopes. The
  slopes pass through z = 3 at the wall faces (y = 0 and y = 6) and overhang 0.5 m horizontally beyond every wall
  face (eaves and both gable ends), continuing the same slope. Gable triangles are not part of this task.
- `Roof.Wing`: sheet. Gable roof over the wing, ridge along y at x = 5, pitch 30 degrees, through z = 3 at the wing
  wall faces (x = 3 and x = 7), 0.5 m overhang at both eaves and at the north gable end (y = 11.5).

The wing roof is lower than the main roof, so its ridge and both its slopes run into the main roof's north slope.
Where both roofs exist, only the higher surface may remain: the two roofs meet along the valley lines with no gap
(at most 5 mm), and neither roof continues under the other (at most 5 mm). Both roofs cover their full plan
including the overhangs.
