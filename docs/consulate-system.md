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
Map scripts are CRLF on disk, like every file the game reads. The tech constant in a script is `cTech` plus the tech name,
and the game only knows constants for techs that were in the XMB when the
process started. A full restart is required. Returning to the menu does not
reload `data/*.xml`.

## Two layers

**Standard maps.** The civilization's Age 0 tech turns the standard consulate
buttons on. Japan uses `YPAge0Japanese`, which makes Dutch, Portuguese, Spanish
and Japanese Isolation obtainable and opens `ypPickConsulateTech`. The armies
are not on the proto. They are `multipleblocktrain` rows on the civilization.
The units sit on `ypConsulate`, disabled, until the relation tech enables them.

Korea's Age 0 is `zpAge0Korean` in the Korean add-on. It activates
`YPAge0Japanese` and then `zpKoreanConsulateAllies`. That second shadow turns
Dutch, Portuguese, Spanish and Isolation off, and turns Korea's four allies on.

The Korean add-on is Korea's base layer, the way vanilla is for the other
civilizations (owner, 30 October 2026: "Treat Korean mod as vanilla ... AoP -
only rewrites"). Korea's standard buttons live in the add-on. AoP holds only
their AoP-map clones. The add-on requires AoP, so a standard button may use AoP
units and helper techs.

| Ally | Standard button (Korean add-on unless vanilla) | AoP-map clone (AoP) |
|---|---|---|
| Russia | `ypBigConsulateRussians` (vanilla) | `zpBigConsulateRussiansClone` |
| Japanese Allies | `zpBigConsulateJapaneseAllies` | `zpBigConsulateJapaneseAlliesKorea` |
| United States | `zpBigConsulateAmericans` | `zpBigConsulateAmericansClone` |
| China | `zpBigConsulateSPCChina` | `zpBigConsulateSPCChinaClone` |

Until 30 October 2026 the United States and China existed only as the AoP
clones, so Korea had two allies on a standard map instead of four (INC-618). The
two standard buttons were added to the add-on then:
- Each is its AoP clone copied byte for byte. Only the name, dbid, sequester link
  and strings differ, the same difference as in the Japanese Allies pair.
- Their units are AoP's: `zpNatConRegular`, `zpNatConUSCavalry`,
  `zpNatConGatlingGun` and their proxies, and `zpConsulateArmyChinese1-3`. The
  `multipleblocktrain` rows for them are on `zpKoreans` in the add-on's `civmods.xml`.

**AoP maps.** Age 0 is not the switch. The map trigger waits until
`zpPickConsulateTechAvailable` is researching, then sets that civilization's
`zpTurnConsulateOn*` active (status 2), sets `zpBigButtonResearchDecrease`,
fires `ZP Pick Consulate Tech`, and fires `Cheat_Returner`. Asian switches fire
only the returner. Faction big buttons (Orthodox, Tortuga, Sultanate, and the
others) also fire the two Italian balance triggers. Omit the returner and every
later big button is free, because `zpBigButtonResearchDecrease` is never repaid.

`Human_Check` (human player, active from the start) grants `zpIsPirateMap` and
fires every `Activate` trigger. A new switcher with no `Fire Event` there is dead.

Every map file with Asian switchers has one per Asian civilization: Japan,
China, India, Khmer where the map has it, and Korea. Korea's switcher is
`Activate Consulate Korea`, for civilization `zpKoreans`, firing
`zpTurnConsulateOnKorean`.
- Until 30 October 2026 only Burma had it. On every other map `zpIsPirateMap`
  turned Korea's standard buttons off and nothing turned the clones on, so the
  Korean consulate was empty.
- It is now in all 52 map files, copied from the map's own Japan switcher.
  Its `Fire Event` sits next to Japan's in `Human_Check`.
- Each switcher has its own per-player loop (`for (k=1; <= cNumberNonGaiaPlayers)`).
  Korea's loop comes directly after Japan's, its loop lines copied from Japan's.
- Istanbul is the exception: one per-player loop holds all its triggers. They are
  declared first and filled in later, so Korea's switcher there is a declaration
  line plus a body inside that loop, after Japan's.
- The ten game-folder copies that matched a repo map got the same text. The
  older copies in the game folder were left as they are.

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
the China clone, and `zpBigConsulateJapaneseAlliesKorea`. It turns Isolation's
clone off. Korea's standard buttons are not in any set: `zpIsPirateMap` turns
them off at the start, so a Korean player on an AoP map sees only the clones.

## Why a foreign card appears in a picker

Two reports on the Danube, verified in the data on 30 October 2026:
- An Ottoman player who had revolted to Romania saw "Russian Allies" among the Hussite leaders, priced 100 export in red.
- A Korean player with the add-on was offered Japanese Allies in a native picker.

The picker does not belong to a building. `ZP Pick Consulate Tech` opens one list: every tech the player holds that
has the `YPConsulateTech` flag and is obtainable. Three facts decide what is in it:

1. A set changes only the cards it names. AoP's sets name AoP's cards. They do not name the vanilla `ypBigConsulate*`
   cards or the add-on's cards.
2. `zpIsPirateMap` turns the standard cards off once, for human players, at the start. These are nine vanilla cards
   and the add-on's three. Until 30 October 2026 its add-on line named `ypBigConsulateJapaneseAllies`, a tech that
   exists nowhere, so Korea's Japanese Allies stayed in every picker.
3. `YPInfiniteTech` puts a card back to obtainable after it is researched or activated, which is why
   `ypPickConsulateTech` and every set turn themselves off. A card that another tech turns on after the start
   re-enters the pool.

Every card a skirmish civilization can hold, from the live techtree on 30 October 2026:

| Card | Turned on by | Off on an AoP map by |
|---|---|---|
| Nine vanilla cards: Russians, British, French, Germans, Ottomans, Portuguese, Dutch, Spanish, Japanese | The Asian Age 0 consulate techs; `ypBigSequester`, which only campaign techs reach | `zpIsPirateMap` |
| `ypBigConsulateRussians`, a second time | `DERevolutionRomania`, status active: Ottomans and Russians who revolt to Romania | `zpRevolutionRomaniaPirateMap` |
| `ypBigConsulateGermans`, a second time | `DERevolutionChile`, status active: Spanish who revolt to Chile | `zpRevolutionChilePirateMap` |
| Add-on `zpBigConsulateJapaneseAllies`, `zpBigConsulateAmericans`, `zpBigConsulateSPCChina` | `zpKoreanConsulateAllies` (Korea's Age 0) | `zpIsPirateMap` |
| The seven `ypBigConsulateSPC*` | Campaign Age 0 techs only | Nothing needed |

Romania and Chile are the only 2 of the 43 revolutions that reach a consulate card. This was checked through every tech
each revolution activates.

**The fix (owner, 30 October 2026).** Each card is turned off in exactly one place:
- `zpIsPirateMap` turns off every standard card at the start, the add-on's three included.
- Each of the two revolutions gets an AoP swap: `zpRevolutionRomaniaPirateMap` and `zpRevolutionChilePirateMap`.
  - They follow the shadow pattern of `zpTheBlackFlag`: status `UNOBTAINABLE`, the revolution as their only prereq.
  - `zpIsPirateMap` makes them obtainable, so they exist only on an AoP map.
- When the revolution is active, the swap does three things in order:
  1. It activates the vanilla sequester (`ypBigSequesterRussians` / `ypBigSequesterGermans`). The revolution
     activated the vanilla card, so the card's effects are already applied: armies enabled, the civilization
     relation, the export tax. Making the card unobtainable does not take these back. The sequester does.
  2. It turns the vanilla card off with `deactivate="true"`, the precedent in vanilla `ypBigSequester`.
  3. It activates the AoP clone (`zpBigConsulateRussiansClone` / `zpBigConsulateGermansClone`).

Not yet seen in game; check on the test device:
- that the swap fires after the revolution;
- that the sequester and the clone each apply once, with no doubled alliance.

An earlier attempt was reverted the same day. It added 80 lines that turned the two revolution cards off in every set,
but it never stopped the vanilla alliance.

Still open:
- Paris. `zpConsulateMalteseCentralEuropeans` is turned on only by `zpTurnConsulateOffMalteseLand`, and most other
  sets do not name it. After a Maltese alliance, the Sansculottes picker shows it.
- `zpTurnConsulateOffRevUSA` and `...RevCSA` each miss the other's three cards. Civil War gives each team one of the
  two, so no player sees this.
- `zpTurnConsulateOnEuropean` misses 72 cards. No map fires it.
- Two lines name techs that do not exist, so they do nothing:
  - `zpTurnConsulateOnKhmers` turns off `zpTurnConsulateOnKhmer`, not itself.
  - `zpTurnConsulateOffMalteseLand` activates `zpBigButtonResearchDone`.

`scripts/mapcheck/tests/test_consulate_validation.py` guards all of this:
- every name in a set is a real tech;
- every tech that turns a card on is classified as Age 0, play, replaced or never, so a new revolution or add-on card
  fails the test until someone records when it runs;
- every replaced revolution has its swap, armed by `zpIsPirateMap`, and the swap turns the revolution's card off;
- no picker on a map shows a card that another set on that map turned on;
- every map with a Japan switcher has a Korea switcher;
- the add-on's cards match the list the test pins.

On 30 October 2026 it fails only on the open items: the two dead names and Paris.

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
Master Training, Koujou and Osaka Ronin). The Osaka Ronin record lives in the Korean mod. Meiji Restoration stays off them. The title is Japanese Allies. Each has its
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
6. Put the sequester on `ypConsulate` in `data/protomods.xml`, the same slot as the other undo buttons: `<tech row="0" page="20" column="2">`. Obtainable is not enough. A sequester with no button there never appears. Rebuild `protomods.xml.xmb`.
7. Rebuild `techtreemods.xml.xmb` and `politicianmods.xml.xmb`.
8. The map trigger only if this civilization did not already have a switcher.
   Copy `Activate Consulate Japan` on every map that has it, in its own loop
   like the other switchers, with its `Fire Event` in `Human_Check`. Also patch
   the game-folder copies that match a repo map.

A standard button for a civilization that lives in another mod goes in that mod,
the way vanilla holds its own (owner, 30 October 2026). AoP holds only the
AoP-map clone. One `unobtainable` line in `zpIsPirateMap`, next to the vanilla
ones, turns the standard button off on an AoP map. Do not invent a second copy
of an ally that already has the right effects and its own sequester.
