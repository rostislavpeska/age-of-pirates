---
name: icon-forge
description: Composite artwork into Age of Empires III DE icon frames - tech, unit, ability, building and team-tech borders, the big-button frame, and borderless portraits. Use when adding or replacing any icon, iconwpf, portraiticon or big button for a new tech, unit, building or native, when generated or hand-painted art needs the game's gold border applied, or when a disabled/greyed variant is wanted. Triggers on "make an icon", "add the border", "icon for this tech", "big button image", "unit portrait", "greyed out icon", "512 portrait".
---

# Putting the game border on an icon

```bash
python .claude/skills/icon-forge/scripts/iconforge.py <art.png> <out.png> [options]
```

| option | effect |
|---|---|
| `--kind` | `tech` `unit` `ability` `building` `team` `big` `portrait` (default `tech`) |
| `--full` | art fills the canvas and the border sits **on top** of it |
| `--inset 0.06` | trim a fraction off each edge of the source first |
| `--fit` | `cover` (crop to fill, default) or `contain` (letterbox) |
| `--size N` | output size; portraits default to 512 |
| `--disabled` | also write `<out>_disabled.png` |

Borders ship in `borders/` next to the script, so this works from a clone with
no dependency on any local art folder. Needs Pillow.

## Geometry

```
tech / unit / ability / building / team   128x128   window (14,18)-(115,114)  101x96
big                                       270x410   window (34,36)-(239,377)  205x341
portrait                                  512x512   no border
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
```

Then reference it from `protomods.xml` / `techtreemods.xml` with a
**backslash** path relative to `data/wpfg`:

```xml
<icon>resources\images\icons\techs\historical_maps\rochambeau_expedition.png</icon>
```

> Build that string with `chr(92)` or a raw string when scripting it. A heredoc
> collapsing `\\t` into `\t` once wrote a literal tab into an icon path, which
> shows as a missing icon in game with no error and is invisible on inspection.

## Checking a result

Look at the 128px output, not the source. Art that reads well at 1254px often
turns to texture at icon size — the test is whether one shape carries it. If
nothing does, the fix is simpler source art, not different compositing.
