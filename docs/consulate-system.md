# Consulate system

How one ally card is assembled. The parameter catalog is
[data_xml_guide.md](data_xml_guide.md) and the shared reference it points at
(`.claude/skills/aoe3de-reference/references/data_xml_guide.md`). This note is
the wiring: which file owns which piece, and what breaks when a piece is missing.
Map-trigger shape is also in the `map-politician-triggers` skill. A new Asian
flag card follows the `native-politician` skill, section 7.

Read this before adding an ally, a sequester, or a `zpTurnConsulate*` line.

## What the player sees

An Asian consulate offers four big flag buttons. Choosing one enables that
nation's units and technologies and replaces the picker with an undo button.
The undo button is a separate tech, the sequester. Trading Post politicians
(pirate captains, Orthodox, Parliament, and the rest) use the same picker UI
and the same on/off sets, with a different card shape.

## The four files

Nothing else decides which cards appear.

| File | What it owns | What it does not own |
|---|---|---|
| `data/techtreemods.xml` | The flag card, its sequester, and every `zpTurnConsulateOn*` / `zpTurnConsulateOff*` set | The picture on the card, the map trigger, the XS command |
| `data/politicianmods.xml` | The card picture. The element name is the tech name in lowercase. `portraitfilename` is the legacy cloth. `portraitfilenamewpf` is the image the card shows | Effects, costs, who is allowed to see the card |
| The map script (`randmaps/*.xs` or `game/randmaps/*.xs`) | The `Activate …` trigger that fires one set for one civilization, and the `Fire Event` inside `Human_Check` that arms it | The list of politicians. A trigger that names a set the tech file does not have does nothing useful |
| `data/trigger/triggerdata.xml` | The commands those triggers call. `ZP Set Tech Status (XS)` is `trTechSetStatus`. `ZP Pick Consulate Tech` opens the consulate UI (`uiConsulateUIInSelected`) | Any particular ally. Adding a politician does not add an effect here |

A card with no `politicianmods` entry is omitted. A set that does not name a
card leaves that card in whatever state the previous set put it in. A trigger
that is not fired from `Human_Check` never runs. `triggerdata.xml` is already
complete for this system.

Data XML is CRLF and is read from the `.xml.xmb` twin. Rebuild with
`python .claude/skills/aoe3de-bar-archives/scripts/xmbc.py build data/<file>.xml`.
Map scripts are LF. The tech constant in a script is `cTech` plus the tech name,
and the game only knows constants for techs that were in the XMB when the
process started. A full restart is required. Returning to the menu does not
reload `data/*.xml`.

## Two layers

**Standard maps.** The civilization's Age 0 tech turns the vanilla consulate
buttons on. Japan uses `YPAge0Japanese`, which makes Dutch, Portuguese, Spanish
and Japanese Isolation obtainable and opens `ypPickConsulateTech`. The armies
are not on the proto. They are `multipleblocktrain` rows on the civilization.
The units sit on `ypConsulate`, disabled, until the relation tech enables them.

Korea's Age 0 is `zpAge0Korean` in the Korean add-on. It activates
`YPAge0Japanese` and then `zpKoreanConsulateAllies`. That second shadow turns
Dutch, Portuguese, Spanish and Isolation off, and turns Russia and Korea's own
Japanese Allies button on. The button lives in the add-on because it is Korean
civ data. AoP does not copy it.

**AoP maps.** Age 0 is not the switch. The map trigger waits until
`zpPickConsulateTechAvailable` is researching, then sets that civilization's
`zpTurnConsulateOn*` active (status 2), sets `zpBigButtonResearchDecrease`,
fires `ZP Pick Consulate Tech`, and fires `Cheat_Returner`. Asian switches fire
only the returner. Faction big buttons (Orthodox, Tortuga, Sultanate, and the
others) also fire the two Italian balance triggers. Omit the returner and every
later big button is free, because `zpBigButtonResearchDecrease` is never repaid.

`Human_Check` (human player, active from the start) grants `zpIsPirateMap` and
fires every `Activate` trigger. A new switcher with no `Fire Event` there is dead.

## A set

`zpTurnConsulateOn*` and `zpTurnConsulateOff*` are shadow techs
(`Shadow`, `YPInfiniteTech`, status `UNOBTAINABLE`). Each one is a total reset:
its own cards `obtainable`, every other politician `unobtainable`, and itself
`unobtainable` at the end so it does not stay in the list.

There are about forty of them. A new card is named in every one. Its own set
makes it obtainable. Every other set makes it unobtainable. The lines sit with
the other `zpBigConsulate*` lines at the top of the set, not in a new block at
the bottom.

Japan's set (`zpTurnConsulateOnJapanese`) offers Isolation
(`zpBigConsulateJapaneseClone`) plus the Portuguese, Dutch and Spanish clones.
Khmer's set offers `zpBigConsulateJapaneseAlliesClone`. Korea's set
(`zpTurnConsulateOnKorean`) offers the Russian clone, the United States clone,
the China clone, and `zpBigConsulateJapaneseAlliesKorea`. It turns Isolation
and the add-on's standard Allies button off, so a Korean player on an AoP map
does not see two Japan cards.

## A flag card and its sequester

Copy `zpBigConsulateSPCChinaClone` or `zpBigConsulateJapaneseClone`, not a
Trading Post politician.

The working shape:

- Cost `Trade` 100, `researchpoints` 1, status `UNOBTAINABLE`.
- `<sequestertech>` names the undo tech.
- Flags: `CountsTowardEconomicScore`, `NativeDance`, `YPConsulateTech`,
  `YPInfiniteTech`, `YPSequesterTech`, `DoNotQueue`.
- Effects enable that ally's units, open its technologies, set the civilization
  relation, turn the export tax on, make the sequester obtainable, and set
  `zpPickConsulateTechAvailable` unobtainable. That last line hides the picker.

The sequester:

- `researchpoints` 45. No `researchlimit`.
- Flags: `NativeDance`, `YPInfiniteTech`, `YPSequesterTech`.
- It reverses the card: disables the units, closes the technologies, clears the
  relation, turns the export tax off, makes `ypPickConsulateTech` obtainable,
  and sets `zpPickConsulateTechAvailable` active so the picker can return.
- An alliance uses `resources\images\icons\ingame\politicians\consulate_endrelations.png`
  and the vanilla end-relations strings `68633` / `68632`. Isolation uses
  `consulate_endisolation.png` and its own strings. Korea's Japan sequesters
  use the end-relations icon.

`SequesterTech` on the card (the XML guide) is the tech the UI offers as the
undo. `YPSequesterTech` is the flag on both the card and the undo. Removing
either one, or adding `researchlimit` 99, was tried against the double-selection
bug on 14 October 2026. The button hid, End Relations could not be used, and
the second alliance became permanent. Those edits stay off the live tree.
The bug is reported, not patched here.

## Japan, three different buttons

| Button | Where | Who sees it | Undo |
|---|---|---|---|
| `ypBigConsulateJapanese` and `zpBigConsulateJapaneseClone` | Vanilla, and AoP | Japan's Isolation | `zpBigSequesterJapaneseClone`, end-isolation icon |
| `zpBigConsulateJapaneseAlliesClone` | AoP, dbid 40418 | Khmer. Research points 10. Shares Isolation's sequester | do not reuse for Korea |
| `zpBigConsulateJapaneseAllies` | Korean add-on, dbid 60042 | Korea on a standard map, via `zpKoreanConsulateAllies` | `zpBigSequesterJapaneseAllies` |
| `zpBigConsulateJapaneseAlliesKorea` | AoP, dbid 50091 | Korea on an AoP map, via `zpTurnConsulateOnKorean` | `zpBigSequesterJapaneseAlliesKorea` |

The two Korea buttons are the Isolation effect list (the four unit types, the
damage bonus on land military, villagers, and villagers' other upgrades, plus Rickshaw,
Master Training, Koujou and Meiji). The title is Japanese Allies. Each has its
own sequester, so ending one alliance does not end the other and does not end
Japan's Isolation.

## Adding an ally

1. Card and sequester at the end of real content in `data/techtreemods.xml`,
   directly above `<!--TEST-->`. Next dbid after the last real one.
2. Display and rollover strings in `data/strings/english/stringmods.xml`, then
   `python scripts/tools/stringsync.py --build`.
3. A `politicianmods.xml` entry whose element name is the tech name in lowercase.
4. One `obtainable` line in the set that should show it.
5. One `unobtainable` line in every other `zpTurnConsulate*` set, beside the
   other big-consulate lines.
6. Rebuild `techtreemods.xml.xmb` and `politicianmods.xml.xmb`.
7. The map trigger only if this civilization did not already have a switcher.
   Copy `Activate Consulate Japan` on that map, including `Human_Check`.

A standard-map button for a civilization that lives in another mod goes in that
mod, not in AoP. AoP's set may name it `unobtainable` when both mods load and
the AoP clone should be the only copy on screen. Do not invent a second copy of
an ally that already has the right effects and its own sequester.
