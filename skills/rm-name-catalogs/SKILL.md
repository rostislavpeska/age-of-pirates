---
name: rm-name-catalogs
description: Finding the exact names a random map may use - protos, terrain subtypes and their editor palette names, terrain mixes, water bodies, cliff types, trade route types, groupings, lighting sets - from the CURRENT game archives and the mod's own data, and why the repo snapshot is not the authority (it lags every DLC; mapcheck --live fixes the false positives). Use before writing any name into a map, when mapcheck reports an unknown name, when the editor palette shows a name you need in code, or when a DLC proto is "unknown". Triggers on "what is the name of", "proto name", "mix name", "terrain name", "water type name", "cliff type", "unknown proto", "did you mean", "palette name".
---

# rm-name-catalogs: read names, never guess them

| Name kind | Where the truth is | Command |
|---|---|---|
| proto (unit/building) | `data/protomods.xml` (mod) then the LIVE `Data/protoy.xml` in Data.bar | `python bartool.py cat data/protoy.xml \| grep 'name="Walrus"'` or `mapcheck --live` |
| terrain subtype (code) from an editor palette name | `Art/terrain/terraintypes*.xml` (`uiname="Rockies Ground Snow 3"` -> text `rockies\groundsnow3_roc`) | `bartool.py cat art/terrain/terraintypes.xml \| grep -B1 -A1 uiname=...` |
| terrain mix (`rmSetAreaMix`) | `Art/terrain/mix/<name>.xml` (title inside); repo mirror `scripts/source/art/terrain/mix/` | `bartool.py list "art/terrain/mix/*rockies*"` |
| water body (`rmSetSeaType`, area water type) | `data/waterbodies*.xml` (mod) over `scripts/source/waterbodies*.xml` | mapcheck S4 water check; `grep name= data/waterbodies2.xml` |
| cliff type (`rmSetAreaCliffType`) | `data/clifftypes2.xml` (mod override) + `Data/clifftypes.xml` (bar) | `grep '<cliff name=' data/clifftypes2.xml` |
| trade route type (`rmBuildTradeRoute`) | `data/traderoutedefs.xml` (mod overrides the whole file) | mapcheck S4 route check (rm-trade-routes) |
| grouping stem (`rmCreateGrouping`) | `game/randmaps/groupings/*.xml` + the deployed folders | `ls game/randmaps/groupings` (rm-groupings-deploy) |
| lighting set | `Art/lightingsets/*` in the bars | `bartool.py list "*lightingset*"` |
| strings (names/descriptions) | `data/strings/english/stringmods.xml` (mod, one file per language, see string-tables memory) | `grep _locid=`; new ids after the highest of the block |

`bartool.py` = `skills/aoe3de-bar-archives/scripts/bartool.py`; `cat` writes nothing, `extract`
needs `-o <scratchpad>` (no repo contamination). Data in the bars is XMB; `cat` decompiles it.

## The snapshot trap

`scripts/source/protoy.xml` is the Oct 2025 vanilla snapshot. Every Baltic-build proto (Walrus,
deFishingHole, deSocketInuit, deArcticTrader...) is absent there, so plain `mapcheck` reports a
FAIL S4 "unknown proto" that is false. Either run `mapcheck --live` (decodes the current protoy
into a LOCALAPPDATA cache once per game build) or refresh the snapshot with the sanctioned command
in the bar-extract skill (`extract ... -o scripts/source --flat --in-repo`) and commit the diff.
The unit bench pre-flight already checks the live protoy.

## Rules

- Mod first, then vanilla: a mod record with the same name overrides.
- A name that exists in the XML but was pasted multi-line compiles wrong (aoe-xml rule 3, rm-trade-routes).
- Copy the string exactly, including case and backslashes; the engine does not fuzzy-match.
- When mapcheck says "did you mean", it is a suggestion from the catalog, not a fact: verify.
