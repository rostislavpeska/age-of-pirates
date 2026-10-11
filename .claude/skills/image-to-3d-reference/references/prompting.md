# Prompt wording that worked and failed (2026-10-11)

One armoured rider, target bind pose: upper arm 26.2 deg from straight down, elbow bent 26.5 deg, legs spread
16.4 deg in total. Numbers measured with the bundled tools ([measurement](measurement.md)).

## Failed: the pose in a TRELLIS text prompt

Text mode lets an image model draw the picture TRELLIS builds from, and image models get degrees wrong when the
degrees stand alone. E1 sent the costume plus:

> "... perfectly symmetric pose: both arms held away from the body, straight down-and-outward at 26 degrees from
> vertical (64 degrees below horizontal), arms not touching the body, a clear gap between each arm and the torso,
> hands well clear of the hips and the armored skirt; elbows slightly bent, about 26 degrees; ... thighs spread
> about 16 degrees in total ..."

Result: upper arm 79 deg from down (+53, near a T-pose), forearm pointing forward (35 deg elbow in 3D, 0 in the front
view), legs 12.5; the design drifted (a different helmet, a ragged 0.5 m plume, added skirt panels). The earlier text
prompt that only named "A-pose" gave arms hanging at about 1 deg (-25). The Blendify tool's own description suggests
stating the bind pose in degrees in the text prompt; this measurement contradicts it for a body pose.

## Worked: a Gemini edit of an existing image of the design

E2, one image-harness call (`--provider gemini`, `gemini-3.1-flash-image-preview`, `--image-size 1K`,
`--aspect 3:4`), input = our own front render of the generated design:

> "Re-pose the character in this image. Keep the costume, colours, materials, armour details, helmet, red plume, face
> and body proportions exactly identical; change only the pose and the background. Target pose, a 3D rig's bind
> pose: standing upright, facing the viewer, perfectly symmetric left and right. Both arms held away from the body,
> pointing down and outward at 26 degrees from vertical, NOT a T-pose, arms NOT raised towards shoulder height: the
> wrists sit at hip height, each hand about one hand-span outside the edge of the armored skirt, with a clear gap of
> background between each arm and the torso and between each hand and the skirt. Elbows slightly bent, about 26
> degrees. Hands open, fingers together, palms facing inward. Legs straight, feet apart, the thighs spread about 16
> degrees in total (8 degrees each side of vertical), so there is a visible gap between the boots. Head level,
> looking straight ahead. Full body including both feet, centred, nothing cropped. Front orthographic view without
> perspective, plain flat light-grey background, no shadow, no floor."

Result: upper arm 28 / 29 deg (+2..+3), chord 30 / 31, legs 14, costume and colours kept, hands clear of the skirt.
Fed to TRELLIS-2 through image mode (E3): upper arm 23.2 deg in 3D, design kept.

## Template for a re-pose edit

Keep the order: what to keep, what to change, the pose in landmarks with negatives, the framing.

1. **Keep:** "Re-pose the character in this image. Keep <costume, colours, materials, headgear, face, body
   proportions> exactly identical; change only the pose and the background."
2. **Pose by landmarks:** where the wrists are (hip height), the gap to the body or skirt ("one hand-span outside
   the skirt edge, background visible between arm and torso"), the knee or boot gap. Give degrees as a second
   description, never alone.
3. **Negatives for the likely failure:** "NOT a T-pose, arms NOT raised towards shoulder height" when the target is
   an A-pose; "arms NOT hanging against the body" when the source arms hang.
4. **Framing:** "Full body including both feet, centred, nothing cropped. Front orthographic view without
   perspective, plain flat light-grey background, no shadow, no floor." TRELLIS wants one whole object on a plain
   light background.

## Rules from the run

- Start from an image of the approved design (a render or concept art), not from words: the edit keeps the design,
  a fresh generation drifts.
- One edit is usually enough; check it in 2D before paying for 3D. A second edit corrects the landmarks, not the
  degrees.
- The elbow bend survives weakly: 6 / 4 deg in the edited front view and 16-19.5 deg in the 3D result against 26.5.
  Ask for a visible bend ("forearms angled slightly outward from the elbows") if the bend matters; this wording is
  untested.
- The rider was generated without a weapon (its prompt said "no weapon"), so it gave nothing for the weapon; whether
  TRELLIS reproduces a held weapon usefully is untested. Plan a separate weapon reference, or build the weapon from
  the rig (the route the weapon stage took).
