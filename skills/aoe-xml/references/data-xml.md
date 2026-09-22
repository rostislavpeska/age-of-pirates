# data XML - the compiled family

Every `data/*.xml` here has a `.xml.xmb` twin (22/22); `data/abilities/*.xml` too; `data/tactics/*.tactics` are plain
(only one has a twin). Rule: rebuild the twin of every file that HAS one, never add a twin where none exists unless told.

## Files and what lives in them

| file | records | keyed by | notes |
|---|---|---|---|
| `protomods.xml` | `<unit id name>` protounits (units, buildings, wagons, sockets, projectiles) | `id` + `dbid` (same number) | fields: `animfile`, `tactics`, `icon`/`portraiticon` (`resources\art\...png` under `data/wpfg`), `displaynameid`/`editornameid`/`rollovertextid`/`shortrollovertextid`, `obstructionradiusx/z`, `placementfile`, `deadreplacement`, `unittype`*, `flag`*, `train`/`tech` (command panel), `command` (abilities). Semantics: `docs/data_xml_guide.md` lines 1-600 |
| `techtreemods.xml` | `<tech name type>` with `<prereqs>` + `<effects>` | `name` | effect grammar: guide lines 1333-2146; shadow techs (`type="Normal"` + `<flag>Shadow</flag>`) are the mod's on/off switches; consulate/sequester clone blocks are marked with comments |
| `protounitcommandmods.xml` | `<protounitcommand name>` (abilities, mode switches, unit-panel buttons) | `name` | referenced from a proto's `<command page column>`; UI functions: `docs/command_list.md` |
| `abilities/abilitymods.xml`, `abilities/powermods.xml` | ability / power definitions (charged actions, area effects) | `name` | both have twins |
| `tactics/*.tactics` | protoactions + anim names per tactic | file name | the proto's `<tactics>` names the file; every `<anim>` a tactic needs must exist in the animfile (`docs/anim_reference_findings.md`) |
| `strings/english/stringmods.xml` | `<string _locid>` | `_locid` | two marked sections: REWRITES (vanilla ids, translated per language in `strings/_rewrites/<lang>.xml`) and NEW STRINGS (mod ids 400001-400290, 500001+, copied 1:1). `scripts/tools/stringsync.py --build` writes all languages |
| `nuggetmods.xml`, `civmods.xml`, `politicianmods.xml`, `unittypes.xml`, `traderoutes.xml`, `traderoutedefs.xml`, `mapspecifictechmods.xml`, `maptypemods.xml`, `gatheringplacedata.xml`, `battle.xml`, `firepit.xml`, `homecityvenetians.xml`, `randomnamemods.xml`, `unittransform.xml`, `waterbodies2.xml`, `clifftypes2.xml`, `ambienteffects.xml`, `tacticdisplay.xml`, `uitraderoutedlg.xml` | one family each | see file | traderoute names and other identifier text: ONE line (whitespace trap) |
| `placementrules/*.xml` | building placement rules | file name | vanilla `buildinglarge.xml` etc. are in the archive; the mod adds `_city` variants |
| `wpfg/` | UI xaml + icon pngs | path | icons are referenced from protos as `resources\art\...` |

## Ids and ranges

- Protos: mod ids start at 20000 (`zp*`), real sequence ends at the last record above the TEST block (21175 today).
  Vanilla protoy ids are 0-~5000 (`scripts/source/protoy.xml`); re-declaring one needs `mergeMode='replace'`.
- Strings: vanilla tops out at 300366; mod NEW STRINGS 400001-400290 (legacy) and 500001+ (503439 today). Display
  name, editor name (`ZP ...` prefix by convention), long rollover, short rollover are separate ids.
- Techs, commands, abilities, soundsets: names, prefixed `zp`.
- Test content: 90001+ / 990001+ live in `playground/`, never in the shipped files.

## Insertion points (verbatim markers)

- `protomods.xml`: the line `  <!--TEST AND TEMPORARY CONTENT-->` (line ~74385 today) - insert the new `<unit>` block
  directly above it, after the `</unit>` of the last real record.
- `techtreemods.xml`: `<!--TEST TECHS-->` (line ~37550). Blocks that must stay grouped are fenced with
  `<!--CONSULATE CLONES-->` ... `<!--END CONSULATE CLONES-->`, `<!--SEQUESTER CLONES-->`, `<!--Legendary Natives names
  - add all new natives to the list below-->`, `<!--Native upgrade techs activation-->` - a new native goes INTO the
  lists those comments name, not only above TEST TECHS.
- `strings/english/stringmods.xml`: after the last real `_locid` of NEW STRINGS, before the
  `<!-- Christmas Strings added by AssertiveWall -->` block.
- Top-of-file exceptions: `techtreemods.xml` opens with ownership/probe techs whose header explains why they lead;
  `protomods.xml` keeps its single `mergeMode='replace'` override (`CommunityPlaza`) inside the TEST block on purpose.

## Cross-references a proto drags along (the checker resolves each)

`animfile` -> `art/<path>` (mod) or `Art/<path>.xmb` (archive) | `tactics` -> `data/tactics/<file>` or archive
`Data/tactics/<file>.xmb` | `icon`, `portraiticon`, `minimapicon` -> `data/wpfg/<path>` / archive `Data/wpfg/...` or
`Art/ui/...` | `*nameid`, `*textid` -> a `_locid` in english stringmods (mod range) or a vanilla id (<= 300366) |
`placementfile` -> `data/placementrules/` or archive | sounds -> `sound/<proto lowercase>_snds.xml` (mod) or archive
`Sound/<proto lowercase>_snds.xml.xmb`; each `<soundset name>` in it -> `sound/soundsets*.xml` or the vanilla soundset
files | `deadreplacement`, `train`, `tech`, `command`, `unittype` -> names that exist (mod or vanilla).

## Overrides

A vanilla record is replaced whole with `<unit mergeMode='replace' id="1710" name="CommunityPlaza">`; a partial
change is not possible - copy the vanilla record from `scripts/source/protoy.xml` (or `bar-extract cat`) and edit.
After a game patch, `vanilla-merge` finds overrides that silently dropped records the patch added.
