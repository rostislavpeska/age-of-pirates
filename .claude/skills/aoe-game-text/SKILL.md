---
name: aoe-game-text
description: Write player-facing English text for Age of Pirates in the vanilla AoE3 DE voice - Home City card and tech names and descriptions, team techs, native unit upgrade names, politician descriptions, nugget strings (format strings - a wrong placeholder crashes the game), colour tags, and the rare vanilla string rewrite. Measured rules, a lint script that stringsync.py --build runs. Use before adding or changing any string in data/strings/english/stringmods.xml. Triggers on "description", "rollover", "card text", "tech name", "tooltip", "name the card", "politician text", "nugget text", "upgrade names", "rewrite a vanilla string".
---

# Player-facing text in the vanilla voice

**Brief beats ambiguous.** A description says what the effects do, in the words vanilla uses for the same kind of
thing. Story, comparison and hype are wrong by default. The owner must not have to proofread every word: run the lint.

## Process for every string

1. **Mirror a vanilla sibling** of the same kind, read from the live string table (bar-extract), never from memory.
   Ships: 61648 "Ships 1 Fire Junk and 1 Fuchuan." Upgrade: "Monitor attack and hitpoints increased."
2. **Text = effects.** Every unit in the text is an effect; every player-visible effect is in the text. Never
   describe a mechanic you have not verified on this unit.
3. **Numbers: only with `DEHideAdvancedRollover`.** Without that flag the game prints the effect values right above
   the description, so the text repeats no numbers: "Ships a Treasure Ship and a Fire Junk." With the flag (62 vanilla,
   31 mod techs) the text must carry them.
4. **Home City badge.** A card's `<displayunitcount>` is fixed in the Home City file (never edited): the units the card
   ships must add up to it.
5. **Lore in the name only**, and only lore the game's strings state (the TAD hero is "Captain Huang"; the fleet's
   admiral is Zheng He).
6. `python .claude/skills/aoe-game-text/scripts/textlint.py --tech <TechName>` (also `--id`, `--text`, `--changed`,
   `--nuggets`, `--team`). Fix every FAIL.
7. New strings: NEW STRINGS block of `data/strings/english/stringmods.xml`, ascending ids, then
   `python scripts/tools/stringsync.py --build` - it writes the 15 language twins and then runs the lint (`--hook`:
   changed strings, all nuggets, all team techs). The report does not block the build; a FAIL still has to be fixed.

## Measured vanilla voice

Live `stringtabley.xml`, 2026-09-27: 1,617 Home City card descriptions, 1,910 other tech descriptions.

| Rule | Evidence |
|---|---|
| Card text median 12 words, 90% at most 21; other techs median 7 | length census |
| One factual sentence; a second only for a second effect | 27% have 2+ |
| No first person (0 of 1,617); "your" only for the player's own things ("your allies") | census |
| No comparisons: "like the / as the" in 1 of 1,617 | census |
| No exclamation marks (4%) and no hype words (mighty, legendary as an adjective, glorious) | census |
| American spelling: hitpoints (1,147 vs 22), Defense, armor (67 vs 0) | word counts |
| Capitalised game nouns: Coin, Food, Wood, Villagers, Age, unit names as displayed | word counts |
| Card names: Title Case, mostly a person, event or concept ("Valmy", "Koxinga") | 2.7% start with a number |

## Team techs

A tech with the `TeamTech` flag says so in its name: the mod writes **"Team ..."** (vanilla "TEAM ...", 206 of 210).
The lint fails a team tech without it.

## Unit upgrade names

Three tiers, one word each, placed before the unit name ("Guard Musketeer"):

| Culture | Fortress | Industrial | Imperial | Vanilla example |
|---|---|---|---|---|
| European | Veteran | Guard | Imperial | Musketeer |
| Asian | Disciplined | Honored | Exalted | Qiang Pikeman |
| Native American civs, African civs | Elite | Champion | Legendary | Aenna; Gascenya, Shotel Warrior (Ethiopia); Maigadi (Hausa) |
| Minor natives | Champion | Legendary | - | "Champion Zapotec" |

Outlaw and special natives replace the tier word with a rising title and keep the unit noun - the model for new
outlaw-based natives:

| Native | Fortress | Industrial | Imperial |
|---|---|---|---|
| Pirates (zpNatPirate, Corsair, Wokou pirate) | Bloodthirsty Buccaneer | Notorious Buccaneer | Legendary Buccaneer |
| Parliament lords (zpNatLord) | Lord Commander | Lord Lieutenant | Lord General |
| Christmas units | Hardy | Seasoned | Storied |

Build a new native's ladder by copying an existing one's three techs (e.g. `zpNatDisciplinedPirate`,
`zpNatHonoredPirate`, `ImpLegendaryNativesShadow`); keep their SetName pattern as it is.

## Colours

`<color=r, g, b>` tags (escaped `&lt;color=...&gt;` in the XML source):

| Colour | Value | Use |
|---|---|---|
| Gold | `1.0, 0.9, 0.5` | politician / UI section headers ("TRAINING:") |
| Yellow | `1.0, 1.0, 0.0` | a highlighted label ("ATTACKERS:", vanilla "Civilization bonus:") |
| Red | `1.0, 0.0, 0.0` | inactive or forbidden ("Can't be used when ...") |
| Green | `0.0, 1.0, 0.0` | "Bonus:" |

Other colours are rare and need a reason; the lint warns on them.

## Politician descriptions (multi-line)

Literal two-character `\n` line breaks, escaped colour tags, gold headers with a space before `\n`. Three shapes only
(extra sections overflow the card) - details in [native-politician](../native-politician/SKILL.md) section 3:

```
TRAINING:\n<unit>\n\n<one description line>\n\nSPECIAL TECH:\n<tech>
TRAINING:\n<unit>\n\n<description>\n\nTECHS:\n<tech 1>, <tech 2>
TECHS:\n<tech 1>, <tech 2>
```

A map bonus replaces the description line with one green `Bonus:` line (Barbarossa, 303391).

## Nugget strings - format strings, a mistake crashes the game

`rolloverstringid` and `applystringid` are printf formats the engine fills according to the nugget `<type>`.
AdjustResource: apply "%1s has uncovered X worth %2d %3s." (player, amount, resource); rollover
"It contains X worth %1d %2s." (amount, resource). Swapped ids crashed the game (391d6085, 2024-07-16).

- Copy the placeholder sequence of a vanilla nugget of the same type and field; no placeholder at all is always safe.
- Do not copy vanilla `symbol=` attributes onto mod strings (the crash fix removed them).
- `textlint.py --nuggets` checks every nuggetmods string against vanilla's patterns for its type.

## Rewriting a vanilla string (extremely rare)

Only when a vanilla id must say something else in every language (precedent: 64988 "Choose an Ally"):
1. Put the vanilla id in the REWRITES block at the top of `data/strings/english/stringmods.xml`.
2. Add the same id to every `data/strings/_rewrites/<language>.xml`: the official vanilla translation, edited minimally.
3. `python scripts/tools/stringsync.py --build --vanilla` (checks REWRITES ids are vanilla and NEW STRINGS ids are not).

## Rejected by the owner (2026-09-27)

| Written | Why | Now |
|---|---|---|
| "Ships 1 Treasure Ship, like the one Captain Huang commanded, and 1 Fire Junk." | "too childish"; comparison | "Ships a Treasure Ship and a Fire Junk." |
| "... now benefit from Defence Promotions, improving their hitpoints." | copied, unverified, British spelling | removed |
| a card shipping 1 unit under a badge of 2 | the badge is fixed | Fire Junk kept |
| "Ships 1 Treasure Ship and 1 Fire Junk." | numbers already shown above (no DEHideAdvancedRollover) | "a / a" |

Related: bar-extract (live strings), icon-forge (card icons), native-politician (politician layouts), aoe-xml.
