# J5: beam into an angled wall

- `Wall`: closed box 0.4 m thick, 6 m long, z 0 to 3.2. Its east face is the vertical plane through the origin with
  outward normal (cos 20 deg, -sin 20 deg, 0); the wall lies behind that face (0.4 m in the opposite direction) and
  runs 3 m each way from the origin along the face.
- `Post`: closed box 0.25 x 0.25, centred at x = 4, y = 0, z 0 to 2.8.
- `Beam`: closed, 0.2 m wide (y -0.1 to 0.1) and 0.25 m high (z 2.8 to 3.05), running along x from the wall's east
  face to x = 4.325 (0.2 m past the post). It rests on the post.

The beam's west end is cut to lie flat against the angled wall face: the whole end face touches the wall (gap at most
5 mm), at most 1 cm into the wall. The post top is fully covered by the beam and touches it.
