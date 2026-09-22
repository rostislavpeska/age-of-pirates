---
name: vanilla-merge
description: Reconcile Age of Pirates overrides against a patched or new-DLC game build - find which mod files silently drop records the patch added (soundsets, unittypes, tactics, transforms, particlesets) and re-add them without disturbing the mod's own changes. Use after any AoE3DE game update, DLC or beta build, when units go silent, when a tech or effect stops resolving, or when asked what a patch broke, which mod files are stale, what the mod overrides, or to merge/reconcile/update overrides against vanilla. Triggers on "new DLC broke", "game patch", "merge with vanilla", "what did the update change", "which files are out of date", "mod overrides".
---

# Reconciling mod overrides after a game patch

The mod replaces ~150 vanilla files wholesale. When a patch adds records to one of
those files, the mod's copy silently drops them — nothing errors, the content is
just gone. Baltic Powers added **268 soundsets** to `soundsetsde.xml` alone that
the mod's override does not contain.

```bash
python .claude/skills/vanilla-merge/scripts/mergetool.py <command> [pattern...]
```

Run from the repo root. Reuses the `bar-extract` skill's reader, so it needs no
unpacked game files. `pattern` is a substring filter on the mod-relative path.

| Command | Purpose |
|---|---|
| `classify` | Which mod files override vanilla (`--new` for mod-only files) |
| `baseline -o DIR` | Snapshot the vanilla counterpart of every override, stamped with buildid |
| `report [-v N]` | Per file: records DROPPED / ADDED / in CONFLICT |
| `merge -o DIR` | Write merged copies that re-add only the dropped records |

## Workflow after a patch

```bash
M=.claude/skills/vanilla-merge/scripts/mergetool.py

python $M report                      # what did the patch cost us?
python $M report -v 20 soundsetsde    # inspect one file's losses
python $M merge -n                    # dry run
python $M merge -o /tmp/merged        # write copies, review the diff
python $M --mod /tmp/merged report    # acceptance check: DROPPED must be 0
```

Then copy the reviewed files in, or re-run with `--in-place` (commit first).
Finally recompile any paired `.xml.xmb` — `merge` lists exactly which ones went
stale. There is no XMB writer here; use Resource Manager.

Snapshot the baseline **before** you merge and commit it. It is the pre-merge
vanilla reference the *next* patch will diff against, which is the piece the repo
does not otherwise have — git history bottoms out at a squashed "Version 5.4"
import that already contains modified files, so it holds no pristine vanilla.

## What merge does, and does not, touch

It is a **text splice**, not a re-serialisation: the mod file is copied byte for
byte and the missing records are inserted before the closing root tag, at the
right indent and in the file's own line-ending style. The diff is therefore
additions only — verified across all 20 mergeable files as +1673 / −0 lines.

Three buckets, and only the first is automatic:

- **dropped** — in vanilla, missing from the mod → re-added
- **mod-only** — the mod's own additions → untouched
- **conflict** — present in both but different → **never rewritten**, the mod
  always wins. These are listed by `report` for you to judge; a conflict is
  usually the mod deliberately retuning a vanilla record, but it can also be a
  DLC rebalance the mod is now overwriting.

## Record identity

Merging by key only works if records can be identified. `record_key` tries, in
order: a `name`/`id`/`type`/`unit`/`protounit`/`tech` **attribute**, a `<name>`
**child**, an entry in the `KEY_CHILDREN` table, **singleton** status (a tag
occurring once is a setting), then the element's own **text**.

Two ordering rules in there are load-bearing and easy to get wrong:

- **Singleton beats text.** In `<sunintensity>3.0</sunintensity>` the text is a
  *value*, not an identity. Key it by text and every retuned setting reads as a
  drop plus an add — which is exactly what made seven `.lgt` lightsets appear to
  lose 30-40 records each when their tag sets are in fact supersets of vanilla.
- **Text is an identity only for repeated tags**, where it names the record, as
  in `<tactic>Normal<action>Heal</action></tactic>`.

`KEY_CHILDREN` handles records identified by child elements. Pick the fields that
are the *identity*, never fields the game retunes — `transform` is keyed on
`from|to|command`, and adding `tech` there wrongly turned 8 retuned transforms
into 18 phantom drops.

If two records share a key, the key is not an identity: the tag is marked
unkeyable rather than one record silently shadowing the other.

## Files merge refuses to touch

- **Unkeyable tags** — `merge` skips the whole file. These are nested or
  order-sensitive formats where appending is not a valid edit: `<level>` in
  `traderoutes.xml` (position *is* the meaning), `<gatheringplace>`, and some art
  unit XML. `report` names the tags. `--include-partial` overrides this; be sure
  first. If a flagged tag does have a stable identity, add it to `KEY_CHILDREN`
  instead.
- **Binaries** — `.gr2` models, `.ddt`/`.png` textures, `.xaml`. `report` says
  only whether they match vanilla; compare and replace by hand.
- **`foo.xml.xmb` next to `foo.xml`** — treated as the compiled artefact of the
  source and skipped, so findings are not double-counted.

## Prefer an additive `.mods.xml` over merging, where it is supported

Merging fixes a stale override; it does not stop the file going stale again next
patch. Where the engine supports an **additive** overlay, converting the override
is the permanent fix — the mod then carries only its own records and inherits
everything the patch adds.

The repo already uses this for random maps (`randmaps/*.mods.xml`, root `<mods>`).
Per the official forum, an October 2022 update extended it to sound:
`soundsetsde.mods.xml` (root `<soundsetdefmods>`) and `<unit>_snds.mods.xml`
(root `<protounitsounddefmods>`). Corroborating evidence on disk: `AoE3DE_s.exe`
contains a `.mods.xml` literal and hardcodes exactly the four soundsets
filenames. The root element names themselves could **not** be confirmed from the
binary (XMB tag names are not stored there), so verify in game on one file first.

Check the payoff before merging a sound file — `report` gives it directly. For
`sound/soundsetsde.xml` the whole 226 KB / 762-soundset override contributes just
4 records (1 added, 3 retuned) while dropping 268. An additive file would be
those 4 records.

## Current state (build 24241387, Baltic Powers beta)

168 overrides / 5893 new files. 21 files lose 334 records; 20 of those merge
cleanly and `data/gatheringplacedata.xml` needs manual work. 110 files hold 468
conflicting records awaiting review. 23 binaries differ, 6 are now identical to
vanilla and could simply be deleted.

`sound/soundsetsde.xml` alone is 268 of the 334 — new building selects
(`ui_select_building_lavra`, `_minster`, `_dry_dock`) and whole unit families
(`dutchfemplorer*`, `ethiopianprincess*`). Do that one first and confirm in game
before touching the rest.
