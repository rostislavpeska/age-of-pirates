---
name: visual-detail-check
description: Check that a small visual detail (texture feature, seam, valley, trim, decal, emblem, icon element) is really visible - and not too loud - at the size the player sees it, in the renderer that counts (the game), before reporting it. Proves which version the running game shows, measures the detail against a capture without it at on-screen scale, and makes an enlarged crop sheet to look at. Use whenever the owner says "I don't see it", "too strong", "more subtle", "thinner", or before claiming that a detail reads at game distance.
---

# Visual detail check: see it, measure it, in the renderer that counts

Owner, 9 October 2026: "IT looks you do NOT check it visually at all!!! We possibly need skill for detail check and
analyzing details from images!!!" This skill prevents two failures:
- reporting a detail as visible (or invisible) from an image where the claim does not hold;
- judging a detail in a preview renderer that does not show it the way the game does.

## 1. Know what the viewer actually sees

- **Name the target view** before judging: the game at default or close zoom, a model viewer, an icon size. Take its
  pixel scale (px per metre, or px across the object) from a real capture of that view, not from a guess.
- **Prove the version on screen.** A game that reads its assets at start shows the last install made *before* the
  process started. Use `python scripts/loaded_version.py [--process AoE3DE_s.exe] FILE...`: it compares the process
  start time with each file's write time, read-only (never stop or start the game; only the owner launches it).
- **A preview is another renderer.** Blender EEVEE or material preview, review renders and viewers differ from the game
  in lighting, exposure, specular and normal-map response. Calibrate a preview once against a game screenshot of the
  *same* version and the same kind of detail. If the game shows it clearly and the preview faintly (or the reverse),
  the preview cannot rank that detail: say so and judge in the game. Details carried by the normal map (laps, steps,
  grooves) are the usual casualty of a soft preview.

## 2. Capture pairs

Same camera, lighting and resolution for:
- **BASE**: without the detail (the previous version, or the detail switched off);
- **each variant**: with it.

`--scale` = target on-screen px per metre / render px per metre. Owner verdicts become calibration points.

## 3. Measure

```bash
python scripts/detail_visibility.py --base BASE.png --variant v1=V1.png --variant v2=V2.png \
    --scale 0.5 --verdict v1=invisible --verdict v2=strong --out DIR
```

The footprint is where any variant differs from BASE by more than the JND (CIEDE2000 > 2.3); the ring is a band around
it.

| Metric | Meaning | Use |
| --- | --- | --- |
| `footprint_px` = 0 | Nothing above the JND at this scale | Invisible: redesign, do not report it as visible |
| `edge_ratio` | Gradient energy in the footprint / in the ring | Details made of lines and rhythm (seams, valleys, laps, trims): the main readability measure |
| `dE_p90`, `frac_clear` | How much the picture changed; share over dE 6 | Over-rates broad smooth tints; never use it alone |
| `cnr`, `dL_ring` | Mean lightness step against the ring's texture noise | Flat-tint details (stains, patches, bands) |

With `--verdict` the report prints the band between "too weak" and "too strong" verdicts for each metric. A band
belongs to one renderer, lighting and scale; never carry it to another renderer.

## 4. Look, then describe

Open `DIR/detail_sheet.png`. Per row:
1. the crop at on-screen size (1:1);
2. the same crop ×4 nearest-neighbour;
3. the dE heatmap.

Write one sentence per variant about what *you see* at 1:1 before reporting. If the 1:1 crop does not show the detail,
the report cannot say "visible". Send the owner the 1:1 view next to the zoom, labelled with the renderer; never only a
zoom, and never a soft-preview picture presented as the game.

## 5. Owner adjustment rounds

- For "a bit more subtle" or "thinner", change **one or two parameters by ~20-30 %**. First find the cue that makes the
  detail readable (from the heatmap and the ×4 crop), keep it, and tone down only the loudest element. Several
  simultaneous reductions cannot be attributed and may overshoot.
- After each round: measure, look, and, when the detail depends on lighting or normals, verify it in the game before
  calling it done.

## Gate before reporting a detail

- [ ] Version on screen proven (game start time later than the install).
- [ ] Measured at the on-screen scale against BASE; a non-empty footprint for every "visible" claim.
- [ ] Sheet looked at; one sentence per variant, consistent with the metrics.
- [ ] Renderer named; any preview-versus-game calibration gap stated.

Example of calibration (9 October 2026, a house roof valley painted at texture level): in an uncalibrated EEVEE
preview at 0.56 scale, a seam scored edge ratio 1.04 ("invisible"), a narrow toned valley 1.09 and a wide valley 1.21
("too strong"). The game showed the narrow valley clearly because it renders the normal-map lap steps strongly; the
narrow one was accepted. The preview had to be calibrated against the game, not trusted.
