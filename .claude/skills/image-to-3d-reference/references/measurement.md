# Measuring the pose: 2D before paying, 3D after

Tools: `scripts/grid.py`, `scripts/pose_angles.py` (host Python), `scripts/render_ortho.py` and
`scripts/mesh_stats.py` (background Blender). Command lines: [scripts/README.md](../scripts/README.md).

## Angle definitions (the same for the target and the measurement)

| Name | Definition |
| --- | --- |
| upper arm from down | shoulder -> elbow against straight down; positive = away from the body |
| forearm from down, chord from down | elbow -> wrist, shoulder -> wrist, same convention |
| elbow bend | angle between upper arm and forearm; 0 = straight (the bind-pose "elbow 26.5" is a bend) |
| leg from down | hip -> ankle against straight down, positive outward |
| leg spread | both leg angles summed (= the angle between the legs when both point outward) |

Take the target from the skeleton's bind pose with the same definitions on the joint centres (bone heads: upper arm,
forearm and hand for the arm; thigh and foot for the leg). In a front view "R" is the image-left limb = the figure's
right side.

## 2D check of the edited image (free, before the paid 3D job)

1. `grid.py edited.png grid.png --step 50`, and `--crop ... --zoom 2` around each joint; the labels are source pixels.
2. Write the picks: `front.image`, `front.arms.R/L` = shoulder, elbow, wrist centres; legs as hip, (knee,) ankle, or a
   `hip_rule` when the hips are hidden (below).
3. `pose_angles.py picks.json --out pose.json --overlay-dir overlays`, look at the overlay (green = measured, yellow
   = target), then compare with `--centre-limbs`.
4. Go on to the 3D job only when the angles meet the tolerance agreed for the asset. The evidence run went ahead at
   +2..+3 deg (2D) and came back at -3..+0.4 deg in 3D; no general threshold is established yet.

A generated image is not a true orthographic view: its 2D angles are an estimate of the pose TRELLIS will build.

## 3D measurement of the generated model

1. `render_ortho.py --model model.glb --out-dir DIR`: the model scaled to 2.0 m (feet at z 0, centred), front and side
   orthographic renders at 1200 px across 2.4 m (500 px per metre), transparent film, and `<prefix>_ortho.json` with
   the mapping. Front: image right = world +X = the figure's left. Side (camera on +X): image right = world +Y, the
   figure faces image-left, its left arm is the near one.
2. Pick the same joints of one arm in both views (front x and side x give X and Y; both y give Z).
3. Add `"side": {"arm": "L", "points": [...]}` and `"ortho": "<prefix>_ortho.json"` to the case and run
   `pose_angles.py`. `front_side_z_mismatch_m` above about 0.02 m means the two picks are not the same joint:
   re-pick before trusting the 3D angles.
4. Legs of a robed figure: the hip joints are hidden. A `hip_rule` places them from both shoulder picks and the
   ground line: hip height = `height` x shoulder height above the sole, hips `half_width` x that height either side
   of the shoulder centre. Take both fractions from the target skeleton (the example run used 0.646 and 0.0615 from a
   rider skeleton: hip joint height / shoulder joint height, half the hip separation / shoulder joint height). Pick
   the ankles at the boot centres about 6 % of the shoulder height above the sole. Leg spreads from a rule are
   estimates.

## Uncertainty (2026-10-11, journal `2026-10-11-claude-i3d-skill-01`)

A generated arm is often fused to the coat at the elbow. The silhouette run through such an elbow has no inner edge,
so "centring across the limb" lands wherever the search stops. On the E3 front render the same picks gave:

| Elbow placement | Upper arm 2D (R / L) | Upper arm 3D | Elbow 3D |
| --- | --- | --- | --- |
| as picked | 24.6 / 26.6 | 26.6 | 17.1 |
| centred, 45 px cap (the recorded value; both elbows capped) | 21.6 / 22.8 | 23.2 | 19.5 |
| centred, 60 px cap | 19.3 / 19.6 | 20.4 | 23.8 |
| capped elbows kept as picked (the tool's behaviour now) | 19.3 / 26.6 | 26.6 | 16.0 |

The image-left elbow's run (88 px against a 45 px wrist) was not capped but ran into the sleeve and coat junction,
visible on the overlay. Rules: `pose_angles.py` keeps a capped pick unchanged and flags it
(`elbow_kept_as_picked`); an elbow run far wider than the wrist run is suspect too; compare the result with and
without `--centre-limbs` and report the spread. Treat about 3 deg as the pick uncertainty of a fused arm. Keep the
picks JSON beside the renders: the result records its sha256, so a measurement can be repeated.

## Mesh census (mesh_stats.py)

glTF splits vertices at every UV seam and hard edge (E3: 432,755 raw against 231,764 welded vertices), so loose parts
are counted after welding. What to read:

- `largest_part_share`: E3 had 90.4 % in one part; the rest is noise, not separate garments.
- `fragment_count_by_height_band` (tenths from the feet): E3 `[0, 0, 2, 6, 13, 5, 56, 92, 163, 40]`, so 351 of 377
  fragments sit in the upper four tenths (shoulder flaps to the plume). Expect noise around thin features.
- `nonmanifold_edges` (E3: 11,924) and `open_edges`: a generated mesh is never a clean surface; section loops break
  ([fitting](fitting.md), "Mesh traits").
