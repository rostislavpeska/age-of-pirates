# J11: straight stair, with UVs

- `Stair`: a straight flight of 8 steps, x 0 to 1.2 wide, climbing along +y from y = 0: every riser 0.18 m high,
  every tread 0.28 m deep, so the top tread ends at y = 2.24, z = 1.44. The stair is solid down to the ground
  (z = 0) under every step. Build it as ONE closed mesh (or closed parts that never sit face to face): no faces hidden
  inside it, no overlapping blocks.
- UVs: each stair side (the sawtooth outline at x = 0 and at x = 1.2) is one UV chart; every tread, riser, the back and
  the bottom are mapped flat at the same scale in both directions (nothing stretched, mirrored or collapsed).
