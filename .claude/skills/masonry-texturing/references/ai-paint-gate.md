# AI painting into a geometry-locked layout

The layout fixes joints, openings and relief. The image model adds the hand-painted surface: tone, grime, chips, the
vanilla look.

## Input frames

- **The elevation:** colour times simple top-left Lambert from the layout normal.
  - Openings: black.
  - Outside the outline and masked zones: flat 0.5 grey.
  - Pad to the nearest supported aspect ratio (Gemini: 1:1, 3:2, 4:3, 16:9, 21:9 and the portrait versions).
- **The second image:** a crop of the vanilla counterpart (for example a JP/CN castle wall), labelled "ONLY a style
  reference". In one call it moves the value range, grime language and painted top light to vanilla.
- **Unrolled elevations only:**
  - a wall with its corner facets in u order and the plinth below works;
  - the shared corner sheet works;
  - a quarter ring with its wrap strip works.
  Packed fragments (narrow strips side by side, small pieces on a grey sheet) get windows, doors or whole new walls
  invented into them.
- **Prompt:** keep every block, joint, opening and flat grey margin exactly where it is, with the same shapes, sizes
  and framing; do not copy the reference's stone shapes; no perspective, directional light, cast shadows or text.

## Registration gate

```
dark = luma(paint) < 0.8 * box_blur(luma(paint), 9 px)
for dx, dy in [-8, 8]^2:
    precision = |shift(dark) & dilate(J, 3)| / |shift(dark)|
    recall    = |dilate(shift(dark), 3) & J| / |J|        (inside the frame's valid mask)
    F1 = 2PR / (P + R)
PASS: best F1 >= 0.5 and |dx|, |dy| <= 4
```

Measured on the castle:
- wall elevations with a style reference: 0.53-0.85;
- corner sheet: 0.80;
- brick rings: 0.75-0.99;
- fragments: 0.35-0.40 (correctly rejected).

A FAIL keeps the layout colours, or gets one retry with `--allow-repeat`. A 5 px vertical shift on brick also failed
correctly.

## Wood gate (grain-rich paintings)

Wood grain is full of dark cracks, so on a correctly painted wood sheet the dark-line precision collapses and the joint F1
fails although the joints are in place. Gate wood on what must hold instead, at one shared shift within +-8 px:

```
sil    = max_channel(|paint - 0.5|) > 0.06          (the painted shapes against the flat grey background)
IoU    = |shift(sil) & valid| / |shift(sil) | valid|
recall = |dilate(shift(dark) & valid, 3) & J| / |J|
PASS: IoU >= 0.90 and recall >= 0.70 and |dx|, |dy| <= 4
```

Measured on five Korean prop sheets (keg, wheel, crate, shot tray, chocks; 2026-10-10): joint F1 0.25-0.67 (four would
have failed), IoU 0.988-0.996 and recall 0.76-0.95, all at zero shift. Keep the joint gate for masonry.

## Compose

- **Shift** the painting by the gate's (dx, dy).
- **Hue:** `paint = chroma * rgb + (1 - chroma) * luma * layout_tint`, with chroma 0.4-0.55, so the set hue stays.
- **Luminance:** scale per frame so the stone mean equals the calibrated layout mean.
- **Joints:** keep the layout's joints and relief. Blend the paint in only inside units, softened about 1.5 px.
- **Openings:** paint darker than luma 0.012 falls back to the layout colour, so no painted black reaches a face.
- **Reuse:** a re-run whose frames are byte-identical may reuse the paid paintings. Check the md5 first.

## Spend discipline

- One call at a time, with an n8n `--ping` after each.
- A 1K test first for a new prompt, then 2K.
- Count every call in the ledger and report it.
