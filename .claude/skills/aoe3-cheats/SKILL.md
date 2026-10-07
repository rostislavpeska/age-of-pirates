---
name: aoe3-cheats
description: Cheat codes in Age of Empires III DE for testing - how to enter them (by hand and by the harness), the full list with effects and where each comes from, which are verified in this project, and what a cheat costs (single player only, blocks challenges). Use when a test needs the map revealed or without fog, resources, speed, an instant win, or any cheat unit; when capturing a minimap; or when asked "is there a cheat for X". Triggers on "cheat", "reveal the map", "X marks the spot", "mercator", "mircator", "fog of war", "give me resources in the test".
---

# AoE3 DE cheat codes

Owner 2026-10-07: "maybe we need a skill for using cheats", "add all cheats".

## Entering a cheat

- **By hand:** in a match press Enter (the chat line opens), type the phrase exactly, press Enter.
- **By the harness:** `python <repo>/scripts/aitest/probe.py cheat <phrase>` sends Enter, the text and Enter. It needs the game
  in the foreground. A screen saver or locked screen swallows the input (PrintWindow captures still work), and ending
  a screen saver programmatically was refused by the permission system on 2026-10-07: ask the owner to wake the screen.
- **Single player skirmish:** cheats work without a setting. **Multiplayer:** only with the lobby option "Allow
  Cheats" (string 19135). A game with cheats completes no challenges (string 72792).
- Type the phrase exactly: capitals, punctuation and spaces as listed. Where the game reacts to a cheat, check the
  effect on the screen (the minimap, the resource bar) before relying on it.

## Verified in this project

| Phrase | Effect seen | Evidence |
|---|---|---|
| `X marks the spot` | reveals the whole map; the fog of war stays (land outside your units' sight is drawn darker, your own sight brighter, on the map and the minimap) | Danube skirmish 2026-10-07, minimap captures |
| `mercator` | reveals the whole map with full visibility: no fog of war, every area lit as if in sight, minimap bright (the cheat for a clean lobby minimap) | Danube skirmish 2026-10-07: minimap captures after it; the owner's spelling `mircator` is not recognised (it appeared in the chat as a plain message), `mercator` worked at once |

## The published list (third-party, not verified here)

Source: [gameplay.tips, "Age of Empires III: Definitive Edition - All Cheat Codes"](https://gameplay.tips/guides/8679-age-of-empires-iii-definitive-edition.html),
read 2026-10-07; [magicgameworld](https://www.magicgameworld.com/?p=46911) and
[tecnobits](https://tecnobits.com/en/age-of-empires-iii-definitive-edition-cheats-for-pc/) list the same phrases.
Game build of the sources unknown.

| Phrase | Effect |
|---|---|
| `X marks the spot` | reveals the entire map (verified above) |
| `speed always wins` | faster gathering, building, training, research and shipments |
| `sooo good` | shows unit kill-feed hover text |
| `this is too hard` | skips and instantly wins a single-player mission |
| `Give me liberty or give me coin` | +10,000 Coin |
| `Medium Rare Please` | +10,000 Food |
| (censored in the sources) | +10,000 Wood |
| `trade plz` | +10,000 Export |
| `a whole lot of love` | +10,000 of each resource |
| `nova & orion` | +10,000 XP |
| `A recent study indicated that 100% of herdables are obese` | fattens all animals |
| `tuck tuck tuck` | Tommynator monster truck |
| `wee ooh wee ooh` | Big Andy monster truck |
| `ding ding ding` | monster ice cream truck (trains villagers) |
| `mustard relish and burning oil` | flaming hot dog cart |
| `ya gotta make do with what ya got` | capybara-launching bombards |
| `where's that axe?` | George Crushington |
| `o Canada 2005` | Canadian Lazerbear |
| `don't kick the pitbull` | Learicorn |
| `we <3 fluffy!1!` | Fluffy, "the world's ugliest dog" |
| `wuv woo vol.2` | flying purple tapir |

## Unlockable cheats (the game's own string table)

These come from challenge rewards, so they work only on a profile that unlocked them. Texts are from
`data/strings/english/stringtabley.xml` (bar-extract), read 2026-10-07; the phrase is given where the string gives it.

| Phrase | Effect | String |
|---|---|---|
| `Granny Nanny` | all villagers turn into Dahomey Amazons | 49993 |
| `Release the hounds` | all units become Wolf Beasts | 55686 |
| `I don't exist` | summons a penguin | 55743 |
| `Flying Dutchman` | naval units can move on land | 55745 |
| (phrase not in the strings) | Honey Badger cheat unit | 49453 |
| (phrase not in the strings) | Chinese Guardian Lion | 49920 |

The tech tree (`techtreey.xml`, 6,730 techs) holds no cheat techs: the phrases live in the engine, so this list
can be incomplete for the current build. Add a cheat here only with its source, or as verified with the date and
what it did.

## Where tests use cheats

- Lobby minimaps: reveal the map before the capture (the `lobby-minimap` skill).
- Anything that changes the economy or speed (`speed always wins`, the resource cheats) also changes what an AI
  test measures. Never use them in an AI verdict run.
