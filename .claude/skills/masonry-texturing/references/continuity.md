# Continuity across faces: corner sheets, rings, ledges

A texture junction is clean only when **both faces sample the same function at the shared edge**. Painting each face
separately, even well, fails: doubled quoins, stepping joints, colour jumps. Faceted rounded corners also need smooth
shading (SKILL.md section 8).

## Unrolled corner coordinate

For a corner made of facets `0..3` between wall A (before) and wall B (after), both walls run counter-clockwise, with
`u = up x n`:

```
w_i(z)  = width of facet i at world height z      (its outline's u-extent at v_of_z(facet, z))
F_i(z)  = w_0(z) + ... + w_{i-1}(z)                (F_4 = total corner width)
facet i : s = F_i(z) + (u - u_left(v))
wall A  : s = t - W_A(z)       for t > W_A(z) - q_end(k)        (negative: before the corner)
wall B  : s = F_4(z) + t       for t < q_start(k)               (after the corner)
```

`t = u - u_left(v)` is measured from the face's **actual** outline edge at that height, not from a course-mid edge.
At the shared edge both sides give the same `s`. Every corner-zone pixel samples ONE corner sheet
`C(s, z)` for colour, the joint mask and the height gradient.

Convert the gradient to the face's tangent frame per face: `dh/du = dh/ds`, `dh/dv = dh/dz * V.z`.

- **Quoin lengths** alternate per course: long at one end, short at the other. That interlocks the corners.
- **Straight beds** in the zone. Taper the wall's warp to zero within about 0.5 m of the zone, so the bed joints meet
  without a step.
- **Stones per course:** cut at `F_1, F_3` on even courses and at `F_1/2, F_2, (F_3+F_4)/2` on odd ones. That gives
  3-4 stones of 0.7-1.3 m, staggered.
- **Openings win:** where a gun slit or door surround falls inside the zone, keep the surround. Draw the ring's outer
  joint into the corner stones.

## Quarter-perimeter brick rings

For running bond round a tower with rounded corners:

```
Q(z)   = W(z) + F_4(z)                 (one wall + one corner; four rings of these close the perimeter)
xn     = x / Q(z) in [0, 1)            (columns of the sheet are xn; metres per column = Q(z) / Wn)
course k: N_k = round(Q(z_mid) / L);  lengths l_j = 1 + 0.1 * u_j, renormalised to sum 1;
          joint positions p_j = cumsum(l)/sum(l), shifted by 0.5/N_k on odd courses (running bond)
head-joint distance = periodic |xn - p_j| * Q(z)
noise: wrap-around in x (append the first grid column before resampling)
```

Paint the sheet plus a wrap strip (about 0.6 m). Then cross-fade the strip into the start:
`final[:, x] = lerp(paint[:, Wn + x], paint[:, x], x / ext)` for `x < ext`. The seam is then invisible.

## Ledges and other horizontal faces

- **Ledge top:** give it its own grainy dressed surface. Carry the joints of the face below across it (look up that
  face's joint mask about 7 cm below its top). Do not fold the colour row over: that streaks across the depth.
- **Sills, soffits, thresholds:** dressed surround stone with mottling and pits, so they don't fail as flat islands.
- **Sun-facing tops** at about 0.5-0.6 of the wall value.

## Congruent texel sharing

When member faces read an owner's texels (rotated copies), all corners must be identical. That means corner sheet and
ring sheet content may depend only on `(s, z)` or `(xn, z)` and the course, never on which corner. Keep landmarks out
of shared texels: a crack or stain would repeat four times.
