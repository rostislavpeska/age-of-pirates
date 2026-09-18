---
name: aoe-xml
description: The COMMON layer for every XML in the Age of Pirates mod - the mechanics that make the engine actually load a file (data XML + its .xml.xmb twin, runtime art/sound XML, strings per language), the placement convention for new records (above the TEST section, ids continuing the real sequence), the reference rules (archive assets by path, never copied), and the one verification command, scripts/xmlcheck.py. Read this BEFORE editing protomods, techtreemods, stringmods, tactics, abilities, any animfile, .material or _snds.xml; the specialised recipes (add-unit, add-building, extended-native, native-politician, aoe-building-pipeline ...) assume it and only add their domain content. Triggers on "add to protomods", "new proto", "animfile", "material file", "_snds", "xmb twin", "string id", "where do I put the record", "xml check", "model does not appear".
---

# aoe-xml - how XML works in this mod (mechanics only, no game design)

Two file families. Everything else follows from which one you are touching.

| family | where | what the engine reads | after every edit |
|---|---|---|---|
| **data** | `data/**/*.xml` (protomods, techtreemods, protounitcommandmods, abilities/, tactics/, nuggetmods, civmods, traderoute*, strings/...) | the compiled **`.xml.xmb` twin** when one exists beside the source (it does for all 22 `data/*.xml`); a file with no twin is compiled from source at load | `python .claude/skills/bar-extract/scripts/xmbc.py check data/X.xml` then `build`; strings: `python scripts/tools/stringsync.py --build` (14 languages) |
| **runtime** | `art/**/*.xml` (animfiles), `*.material`, `sound/*_snds.xml`, `*.lgt` | the plain XML, parsed at run time | nothing to compile - but it MUST be CRLF (below); never create a twin here |

Both families load once per process: **every change needs a full game restart** (the `game-startup` skill; never kill the game).

## Invariants (each one has cost a day)

1. **CRLF, always, for the runtime family.** An LF-only animfile/material/_snds is silently ignored: proto loads, unit places, decal draws, model never renders, no error (Tower of London 2026-09-17). The Write tool and `open(..., 'w')` produce LF - `python scripts/tools/check_art_eol.py --fix` converts; the project hook does it on every Write/Edit; `.gitattributes` keeps checkouts CRLF. "Model does not appear" -> line endings first, gr2 last.
2. **Never copy an archive asset into the mod.** Textures, models, decals, particles, sounds the game ships are referenced by their archive path (`homecity\british\british_tol\textures\british_tol_matA_BaseColor`, `buildings\fort\west_fort_decal`). Only content the mod made is a file here. Every byte ships in the zip.
3. **Identifier text is one line.** XMB keeps element text verbatim: `<name>\n  arctic1\n</name>` compiles to `'arctic1\n  '` and silently falls back to the default (traderoutedefs 2026-09). Names, ids, paths: opening tag, text, closing tag on ONE line.
4. **Twins are the truth.** An edited `data/*.xml` whose `.xml.xmb` was not rebuilt is inert; commit both. Art/sound XML never gets a twin (it would mask the plain file).
5. **English strings are the source.** `data/strings/english/stringmods.xml` (NEW STRINGS block, ids 500001+) -> `stringsync.py --build` writes every language's `.xml.xmb`; forgetting it ships missing names to 14 languages.
6. **Paths in XML are archive-style**: backslashes, relative to `art/` (models/textures/decals/animfiles, no extension) or `data/` (tactics, placement rules, icons under `data/wpfg`: `resources\art\...png`). In Bash heredocs backslashes collapse - write such files with the Write tool / `chr(92)`.

## Placement convention (unless the user says otherwise)

New records go at the **end of the real content, directly above the file's first long TEST / commented block**,
ids continuing the real sequence. Never beside an older related record.

| file | insert above | id / key |
|---|---|---|
| `data/protomods.xml` | `<!--TEST AND TEMPORARY CONTENT-->` | `id` = `dbid` = last real id + 1 (21175 today) |
| `data/techtreemods.xml` | `<!--TEST TECHS-->` | techs are keyed by `name` |
| `data/strings/english/stringmods.xml` | the Christmas/test comment block at the end of NEW STRINGS | `_locid` = last real id + 1 (503439 today); display, editor, rollover as separate ids |
| `data/protounitcommandmods.xml`, `abilities/abilitymods.xml`, `nuggetmods.xml` ... | end of file, before any trailing comment block | keyed by `name` |
| `sound/<proto lowercase>_snds.xml` | own file | file name = lower-case proto name |
| `art/<area>/<name>/` | own folder: `<name>.xml` + `<name>.material` (+ `.gr2`, `textures/` only for mod-made textures) | animfile path in the proto = `<area>\<name>\<name>.xml` |

**Top-of-file exceptions exist**: records the rest of the file depends on (ownership/probe techs, shadow techs that many later records reference, `mergeMode='replace'` overrides of vanilla ids) sit at the top and the file's own header comment says so. Read the first 60 lines of the file before inserting; ask when the user has not said where a record belongs and it is not a plain addition.

Overriding a vanilla record: same id, `mergeMode='replace'` (protomods has one: `CommunityPlaza`). Never re-declare a vanilla id without it.

## Nuggets: land and naval are two different things (nuggetmods.xml)

A `<nugget>` record is picked by the map script's `rmSetNuggetDifficulty(d, d)` latch at the moment a placeholder
unit is placed (baked in a grouping or an object def). Two families, placed on different spots and never
interchangeable:

| | land nugget | naval (water) nugget |
|---|---|---|
| record | no `<waternugget>` | `<waternugget>true</waternugget>` |
| `<nuggetunit>` | `zpNuggetInvisible`, `Nugget*`, `NuggetCapturableBuildingBig`... | `zpNuggetInvisibleWater`, `ypNuggetBoat`, `ypNuggetSeaLionRock`... |
| placeholder in the script / grouping | `Nugget` (object def) or the baked land placeholder | object def: `ypNuggetBoat` (zpcaribbeanwars, zpindependencewar, zpIceland - SEA maps only: an rmRiverCreate river floats no collideable hull, London 2026-09-18); baked in a grouping: `zpNuggetInvisibleWater` (Istanbul's forts / guild) |
| where it may stand | on land (a plateau, a block cell, inside walls) | on OPEN water - clear of a pier grouping's terrain box and of the lane (London 2026-09-18: 18 m in front of the pier = on the box edge, nothing spawned) |
| guardians | `<guardian>` or `<guardianunit><unit>` land units - guardian clones (`deGuardian*`, `zpGuardian*`) OR plain aggressive units (`zpNuggetIstanbul` 512 = 9 x `zpNatJanissary`, `zpNuggetTowerOfLondon` 605 = 10 x `deSPCHMRedcoat`) | ships (`zpGuardianCorsairGalley`, `dePrivateerGuardian`) |
| texts | copy `rolloverstringid` / `applystringid` from the record you clone - never new strings for a variant | same |

A land record latched onto a water placeholder (or the reverse) spawns nothing, silently. The map type must be
listed in the record (`<maptype>piratehistoricalmap</maptype>` for the pirate historical maps). Query a baked
nugget's unit in the script by the record's `<nuggetunit>`, never by the authored placeholder proto (Istanbul's
law). New records: `data/nuggetmods.xml` only loads at game start - XMB rebuild plus a restart before a test.

## Verification ladder (do all of it before a game test)

```
python .claude/skills/aoe-xml/scripts/xmlcheck.py [paths...]     # the one command
```
It checks: well-formed XML; CRLF on the runtime family; twin freshness (source newer than `.xmb`); every reference
resolves - animfile, tactics, icons, gr2/textures/decals/pkfx (mod folder or archive index), string ids (mod or
vanilla range), `_snds` present for every mod proto and every soundset it names defined (mod or vanilla soundsets);
proto/string ids unique and above the vanilla range; `stringsync` audit. Exit 1 on any ERROR.
Then: `xmbc.py build` for the twins you touched, `stringsync.py --build` if strings changed, full game restart,
and the **`rm-unit-bench`** skill for a new unit/building (offline pre-flight + one-unit map + census + screenshot).

## References (read the one you need)

- `references/data-xml.md` - the data files: record families, which twin, id ranges, string sections, mergeMode, the
  sections of `docs/data_xml_guide.md` to read for attribute semantics.
- `references/art-xml.md` - animfile grammar (components, anims, attachments, logic types, decal, materialvariant),
  `.material` grammar and texture profile, `_snds.xml` grammar and generation rules, path resolution table.

## Related skills

`bar-extract` (read vanilla, compile XMB), `rm-unit-bench` (see it in game), `mod-deploy-check` (release audit),
`gr2-granny-edit` / `aoe-building-pipeline` (models and textures), the recipes: `extended-native`, `native-politician`,
`native-ability-minify`, `add-unit`, `add-building`, `add-tech` (each starts with "Prerequisite: aoe-xml").
