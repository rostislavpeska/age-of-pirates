# Age of Pirates: Koreans (add-on mod)

A playable **Koreans** civilization for *Age of Empires III: Definitive Edition* with the
[Age of Pirates](https://github.com/rostislavpeska/age-of-pirates) mod. Version 1 is a clone of the
Japanese civilization with Korean flags, a Korean Town Center, Barracks and Stable, a Korean home city
name and the AI personality Empress Myeongseong. What is still missing: [AUDIT.md](AUDIT.md).

## Install and play

1. Age of Pirates must be installed and enabled.
2. Put this folder into `<your AoE3DE profile>/mods/local/age-of-pirates-koreans`
   (`git clone https://github.com/rostislavpeska/age-of-pirates-koreans` there).
3. In the game: Manage Mods - enable Age of Pirates and Age of Pirates Koreans. Keep this add-on above Age of
   Pirates in priority. Restart the game after enabling or updating.
4. Pick "Koreans" in the skirmish lobby or the Scenario Editor. Disable the add-on to remove the civ again.

## For maintainers and agents: this repository is GENERATED

| What | Where |
|---|---|
| Source of truth | [age-of-pirates](https://github.com/rostislavpeska/age-of-pirates), branch `Pirate-rework`, folder `koreans/` |
| Korean building models (3D pipeline) | AoP `art/buildings/korean_tc/`, `art/zbench_korean_military/` |
| Export tool | AoP `scripts/tools/export_koreans.py` (+ `korean_visuals.py`, `flagmaker_render.py`, `flag_ddt.py`) |
| Tests | AoP `scripts/tools/tests/test_korean_addon.py` |
| This repo | the export only - never edit it by hand; `EXPORT.json` names the source commit |

Workflow (any computer):

```
# in the AoP checkout (Pirate-rework)
edit koreans/...                                   # Korean records and assets only
python -m pytest scripts/tools/tests/test_korean_addon.py -q
git commit + git push                              # the source goes to AoP first
python scripts/tools/export_koreans.py             # writes ../age-of-pirates-koreans
# in ../age-of-pirates-koreans
git add -A && git commit -m "export AoP <commit>" && git push
```

### Merge strategy

- **One source, two products.** AoP's game folders (`art data game sound randmaps`) are the AoP mod; `koreans/`
  is the add-on's source. The AoP zip packs only the five game folders, so `koreans/` never ships with AoP, and
  the game never reads it there.
- **Ownership.** The AoP agent edits everything outside `koreans/`; the Korean agent edits `koreans/` and the
  Korean tools. Both commit to `Pirate-rework` on separate paths, `git pull --rebase` before every push, so they
  do not collide. The 3D agents own the Korean models in AoP `art/` and change them in place.
- **No Korean record in AoP files.** The engine merges each mod's additive data files (`civmods`,
  `techtreemods`, `stringmods`, `homecity`...) with vanilla and with each other, so the add-on carries only its
  own records. Ids reserved for the add-on: strings 600000+, tech dbids 60000+, protos 22000+.
- **Generated shared files.** Two kinds of files exist in both mods and are rebuilt by every export, so re-export
  after AoP changes them:
  - the Town Center, Barracks and Stable animfiles: vanilla (or AoP's own copy, if AoP ever overrides one) plus
    the Korean branch;
  - `sound/soundsetsde.mods.xml`: AoP's soundsets plus the Korean ones (cross-mod merging of this file is
    unverified, so the add-on carries both).
- **The `korean-civ` branch** (2026-10-08) was the first prototype as a full AoP fork; it is superseded by this
  layout and kept only as history.

## Credits

- Flag: Korean Empire flag (1897-1910, public domain), rendered with the *AoE3DE Flag Maker Pack* v1.0.2.2 by
  EmpAhmadK (free for AoE3DE modding).
- Korean villager voices: *Age of Empires II: Definitive Edition* (Microsoft), from the Age of Empires wiki page
  "Koreans".
- Korean buildings: Age of Pirates 3D pipeline.
