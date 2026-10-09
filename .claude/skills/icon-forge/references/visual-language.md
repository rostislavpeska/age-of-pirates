# Icon visual language: what an icon shows and how it looks

Read before writing any icon prompt (tech, unit, ability, card), whoever generates the art: Claude through the
image harness, GPT or Codex natively, or a human. Owner, 2026-10-09: "it's always good when there is a mix",
"sometimes the amber brown is not bad when icon is simple", "we need some visual language when icon should look
like what".

Reference sets, look at them before a new set:

- vanilla DE: `resources\images\icons\techs\asians\*.png` (and the other `techs\*` folders); extract them into the
  session scratchpad with `bar-extract`, never into the repo;
- AoP Parliament natives (owner: "really good"): `data/wpfg/resources/images/icons/techs/parliament/*.png`.

## 1. The form follows what the tech does

| The tech ... | Form | Vanilla examples | AoP examples |
| --- | --- | --- | --- |
| upgrades a unit class step by step (+HP/attack for a line: Disciplined, Exalted ...) | **medallion**: never generated - **reuse the vanilla medallion icon** of the matching upgrade (owner 2026-10-09: "unit upgrades are standardized. We'll reuse vanilla") | `disciplined_cavalry`, `disciplined_ranged`, `exalted_pikeman`, `dojo_yabusame` | |
| raises weapon damage, range, rate of fire | **the weapon** alone, diagonal or crossed, on a dark or flat field | `samurai_damage`, `gold_hand_dmg` | `munster_levies` (musket and shield) |
| teaches an ability or practice (heal, throw, pray, write, negotiate) | **hands doing it**, close-up, no face | `tech_monk_healing_icon`, `tech_japan_kayakujutin_icon_64`, `compunction`, `christian_schools`, `diplomatic_intrigue` | `adventurers_act` (handshake over a charter) |
| unlocks, ships or improves one unit type | **the unit**: one figure, or its signature gear (helmet, armour, coat) | `hc_samurai_shipment`, `shaolin_warrior`, `tech_free_samurai` | `ironside_levy` (helmet and cuirass), `new_model_army` (red coat), `eastern_association` (rider with the colours) |
| improves an economy (gather rate, a resource, a trickle, livestock) | **the resource or the tool** as a still life | `hanami_parties` (berry basket), `meditation` (rake), `shrine_wood_on` | `welsh_drovers` (ram), `excise_ordinance` (barrel, meat, coins) |
| builds infrastructure or changes limits and logistics | **a small scene** or a top-down landscape | `irrigation_channels`, `elephant_limit`, `faster_shipments` | `new_river_company` (water mill) |
| is civic or political (charter, treaty, levy, nation) | **documents, seals, coins, heraldry** | `portuguese_expedition`, `por_army_icon_64` | `trained_bands` (bandolier with the St George cross), `excise_ordinance` (sealed scroll) |
| is an aura or a group effect | **the group or its source**, on a strongly coloured backdrop | `disciple_aura` (orange robes on purple) | |

When two forms fit, take the object or the hands. They read at 64 px, and generators fail on faces: Korean warrior
monks came back twice with hair and Western faces (2026-10-09). If people must appear, keep faces small, hidden by
gear, in silhouette or turned away.

## 2. Colour

- **Amber is the base colour of AoE icons, not a fault.** It dominates 150 of 281 vanilla Asian tech icons and 5 of the
  9 Parliament icons (measured 2026-10-09). It suits a simple object (wood, leather, gold, bread, skin), even as a
  full warm cast.
- **What fails is the whole set in one colour.** The first Korean monastery set (2026-10-09) was four warm scenes under
  one shared "warm dramatic lighting" style line, next to the amber vanilla Compunction: the panel read as one
  brown block.
- **A set** is the icons a player sees together: one building's tech panel, one card row, one native's techs. Give a
  set at least two forms (section 1) and at least one or two icons on another field colour: navy, teal, deep green,
  crimson, purple, black, or a daylight sky for scenes. Count the vanilla neighbours in that panel.
- Fields are flat or a soft vignette, never environment clutter behind an object.
- Accents: heraldic red, gold, white highlights. They give a dark icon its focal point.
- Colour variety alone does not make an icon look like AoE: the second Korean set had four different colours and
  still read as generic illustration (painterly scenes with faces). Form and rendering (sections 1 and 3) decide that.

## 3. Rendering: what "AoE style" means

- **Rendered props, not paintings.** Vanilla DE icons look like lit game assets: crisp edges, solid shapes, glossy
  metal and lacquer highlights, a strong key light plus a rim light, high local contrast, little small detail.
  Asking for "oil painting" or "visible brushwork" gives loose illustrations that do not sit next to vanilla (the second
  Korean set, 2026-10-09).
- **Not a photograph either.** GPT image drifts towards photos; keep a NOT-photograph block in every prompt.
- One subject, at most three elements; it fills 60-85% of the window and may be cropped by the frame.
- No text, letters, numbers, frames or UI marks in the art (`icon-forge` adds the border; vanilla overlays such as the
  green check of `shrine_wood_on` are separate art).

## 4. Prompt template

```
<FORM>: <the subject, concretely: materials, colours, arrangement>. Background: <field colour>, plain with a soft
vignette.
Age of Empires III Definitive Edition tech icon: one subject, centred, filling most of the square, strong key light
and rim light, crisp edges, readable at 64 pixels; no text, no letters, no numbers, no border, no frame.
Stylised video-game icon render, NOT a photograph and NOT photorealistic: clean hand-painted game-asset look,
saturated colours, simplified textures, no camera lens effects, no photographic depth of field.
```

Write each icon's own prompt. A shared style line may carry rendering words only, never lighting colour or mood
("warm", "golden", "sunset"): those turn the whole set one colour.

## 5. Workflow

1. **Plan the set** as a table, icon -> form (section 1) -> field colour (section 2), next to the neighbours already in
   that panel. Check the mix rules on the table, before any paid call.
2. **Generate one image per icon.** A grid of several icons in one image splits one image's detail between its cells
   and comes back crude (2026-10-09). Through the image harness: `--model gpt-image-1-mini --quality low` unless the
   owner asks otherwise (owner 2026-10-09; about 0.11 CZK per icon). Fall back to the default `gpt-image-1` when
   mini's result is bad or the icon is complex (a scene, several figures). Unit portraits and unit icons follow the
   recipe in SKILL.md "Unit portraits" (Gemini with vanilla portraits as references, then `portrait_compose.py`);
   their player-colour area follows "Player colour" there.
3. **Border** with `iconforge.py --kind <kind> --full`.
4. **Review the set in context:** `iconsheet.py OUT.png <new icons> <in-game neighbours>` lays them out at 128 and
   64 px and names each icon's dominant colour; it exits 1 when one colour covers more than 80% of the set (calibrated
   on vanilla and Parliament, see its docstring). Look at the 64 px row: one shape has to carry each icon. Judge form
   and rendering by eye against the reference sets.
5. Wire the icons only after that; send the sheet with the report.
