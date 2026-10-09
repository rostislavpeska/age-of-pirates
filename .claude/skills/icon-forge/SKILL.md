---
name: icon-forge
description: Composite artwork into Age of Empires III DE icon frames - tech, unit, ability, building and team-tech borders, the big-button frame, and borderless portraits. Use when adding or replacing any icon, iconwpf, portraiticon or big button for a new tech, unit, building or native, when generated or hand-painted art needs the game's gold border applied, when a disabled/greyed variant is wanted, and BEFORE generating icon art: what an icon should show and how it should look (visual language, prompt template, set review sheet). Triggers on "player colour dark/black in icon or portrait", "unit portrait recipe", "make an icon", "add the border", "icon for this tech", "icon style", "icon prompt", "icons look wrong", "big button image", "unit portrait", "greyed out icon", "512 portrait".
---

# Icons: art direction, border, set review

**Before any icon art is generated or painted, read [references/visual-language.md](references/visual-language.md):**
the form follows what the tech does (object, hands, unit, scene, documents; unit-class upgrades reuse the vanilla
medallions), colour is judged across the set, AoE icons are rendered props, not paintings. It holds the prompt
template for any generator (image harness, GPT, Codex) and the set workflow. After bordering, review the set with
its in-game neighbours:

```bash
python .claude/skills/icon-forge/scripts/iconsheet.py <scratchpad>/sheet.png <new icons> <neighbour icons>
```

It lays the set out at 128 and 64 px, names each icon's dominant colour and exits 1 when one colour covers more than
80% of the set. The sheet goes to the scratchpad and into the report, never into the repo.

## Putting the game border on an icon

```bash
python .claude/skills/icon-forge/scripts/iconforge.py <art.png> <out.png> [options]
```

| option | effect |
|---|---|
| `--kind` | `tech` `unit` `ability` `building` `team` `big` `portrait` `politician` (default `tech`) |
| `--full` | art fills the canvas and the border sits **on top** of it |
| `--inset 0.06` | trim a fraction off each edge of the source first |
| `--fit` | `cover` (crop to fill, default) or `contain` (letterbox) |
| `--size N` | output size; portraits default to 512 |
| `--disabled` | also write `<out>_disabled.png` |
| `--cut X,Y[,W]` | politician only: cut a W x 2W window (default 512 = native scale) at X,Y and scale it to the card; W < 512 zooms in. Use it to give every portrait of a set the same head size (measure the face height on a grid render; the card's head should sit in the upper fifth) |

Borders ship in `borders/` next to the script, so this works from a clone with
no dependency on any local art folder. Needs Pillow.

## Geometry

```
tech / unit / ability / building / team   128x128   window (14,18)-(115,114)  101x96
big                                       270x410   window (34,36)-(239,377)  205x341
portrait                                  512x512   no border
politician                                512x1024  no border, RGB - the card portrait of politicianmods.xml
```

All five square borders share one window, so they are one code path. Three
things about that window are easy to get wrong and are handled here:

- **It is not centred** — 14px left, 18px top, 13px right, 14px bottom. Artwork
  centred by halving the difference sits about 2px high.
- **It is not square** — 101x96. A square source has to be cropped or
  letterboxed; scaling it to fit distorts.
- The numbers are **measured from the border's alpha at run time**, not
  hardcoded, so replacing a border file cannot silently break the placement.

## `--full` versus `--inset`

Generated art usually arrives with its own painted frame. Two ways to deal with
it, and they look different:

- `--full` — art fills the whole canvas and the game border overlays it, hiding
  the painted edge underneath. Tighter join, no gap, but the outer ~14px of the
  source is covered, so anything near the edge is lost.
- `--inset 0.06` — trim the painted frame off first, then place the result
  inside the window. Keeps more of the composition but can leave a faint gap
  where the trim was imperfect.

`--full` is usually the better result for AI-generated art, which tends to put a
decorative border around everything.

## Where the output goes

Match the convention already in the mod rather than inventing a path:

```
data/wpfg/resources/images/icons/techs/<set>/<name>.png     tech icons
data/wpfg/resources/art/units/natives/<name>.png            unit portraits
data/wpfg/resources/images/icons/politicians/<name>.png      politician card portraits (politicianmods.xml portraitfilenamewpf, forward slashes)
```

Then reference it from `protomods.xml` / `techtreemods.xml` with a
**backslash** path relative to `data/wpfg`:

```xml
<icon>resources\images\icons\techs\historical_maps\rochambeau_expedition.png</icon>
```

> Build that string with `chr(92)` or a raw string when scripting it. A heredoc
> collapsing `\\t` into `\t` once wrote a literal tab into an icon path, which
> shows as a missing icon in game with no error and is invisible on inspection.

## Player colour: the game multiplies, it does not show through

A transparent area in a unit/building icon or portrait takes the player colour, but the game does **not** show the
colour through the hole: it multiplies the player colour into the RGB stored under the transparent pixels
(`colour = RGB x lerp(player colour, 1, alpha)`, drawn opaque). Vanilla stores a light grey shading there (the folds of
the sash; median luminance 131 over 1492 vanilla images). Black stored there shows a black sash in every colour
(owner's game test 2026-10-09, Korean monk portraits: (21,1,21) and (0,0,0) under the kasaya). Many tools write black
under alpha 0 - Pillow's RGBA `resize` and `alpha_composite` premultiply - which is why the same art "sometimes works".
On 2026-10-09 half of AoP's unit art with a player-colour area (30 of 103) had it dark; all repaired.

| Tool | Does |
|---|---|
| `scripts/pccheck.py FILE_OR_DIR...` | exit 1 when a player-colour area stores dark RGB (median luminance < 60; 8% of vanilla is below too). Background transparency (it holds an image corner), the art-to-frame gap strips and specks are skipped |
| `scripts/pcfix.py IN.png... [--out-dir D]` | rewrites only that RGB as light grey (folds kept when still stored, else flat 205); alpha untouched |
| `scripts/pcpreview.py OUT.png IN.png...` | sheet in blue, red, yellow, green with the game's multiply - look at it before installing |

`iconforge.py` resizes and composites without premultiplying (`resize_keep_rgb`, `composite_keep_rgb`), so the grey
survives the frame. Any other editor: run `pccheck.py` on the saved file. Guard:
`scripts/test_player_colour.py` scans `data/wpfg/resources/art/units` and `buildings`.

## Unit portraits: the repeatable recipe (owner 2026-10-09: "cheap repeatable path")

One paid call per portrait, everything after it free and scripted:

1. **Generate** with the Gemini route of the image harness, two vanilla portraits of the same culture as style
   references (extract them with `bar-extract`; fill their transparent sash with a natural cloth colour first):

   ```bash
   python .claude/skills/image-harness/scripts/generate.py "Paint a new Age of Empires III unit portrait in exactly the
   painting style of the reference images (official Age of Empires III unit portraits): close-up of head and shoulders,
   the head large in the upper half, three-quarter view, smooth airbrushed painterly skin, simplified stylised forms and
   folds, soft warm key light, hand-painted video-game look, NOT a photograph. Subject: <who, age, face, clothing,
   weapon>. The <sash / band / emblem> is one flat pure magenta colour (#FF00FF) with no shading. Background: flat pure
   green (#00FF00), nothing else. No text, no border." --provider gemini --ref REF1.png --ref REF2.png --aspect 1:1
   --image-size 1K --out <scratchpad> --name <unit>
   ```

   Name the age and the face ("a young man of about 22 with masculine features"; the first try read as a woman).
   Leave "crisp rim light" out: it leaves a light line round the figure that vanilla does not have.
2. **Compose**: `python .claude/skills/icon-forge/scripts/portrait_compose.py <unit>_1.jpg OUT_portrait.png --icon
   OUT_icon.png` - green and magenta keyed, light grey under the player-colour area, the stock vanilla backdrop (median
   of the vanilla portraits, cached in the temp folder) and the halo measured on the vanilla Asian portraits.
3. **Check** with `pcpreview.py`, install under `data/wpfg/resources/art/units/...`, keep the harness JSON as provenance.

Tried and dropped the same day: gpt-image-1 from a prompt (cartoon-like, the magenta drifted to purple and missed the
key), restyling an existing picture with Gemini (good, but two calls per portrait), a semi-transparent background that
lets the player colour glow (owner: "background must be consistent" - vanilla shares one backdrop).

## Checking a result

Look at the 128px output, not the source. Art that reads well at 1254px often
turns to texture at icon size — the test is whether one shape carries it. If
nothing does, the fix is simpler source art, not different compositing.
