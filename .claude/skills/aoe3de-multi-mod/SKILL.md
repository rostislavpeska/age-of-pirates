---
name: aoe3de-multi-mod
description: How Age of Empires III DE combines several enabled mods (a base mod plus civ add-ons, compatibility packs, home-city packs) and how to keep them from silently shadowing each other - mod priority in age3-mod-status.json (the lower Priority wins), which files merge across mods (the additive *mods.xml data files) and which replace whole (animfiles, sound files, tactics, materials, textures), a collision audit of the enabled mods (mod_overlap.py), and the hosting pattern for an add-on that needs a change in a file another mod overrides (an inert branch keyed on the add-on's tech or civ, a drift check in the add-on, companion references allowed in the host's checker). Use when "the new model / voice / change does not show in game although the files are installed", before an add-on ships a copy of any non-additive file, when adding, enabling or reordering mods, and before releasing mods that run together.
---

# Several mods at once: priority, merging and hosting

Owner, 2026-10-11, after the Korean Consulate showed as the Japanese one: "explore other buildings which are either
in AoP and the Korean mod - follow pattern - maybe add a multi mod management skill". Worked example: AoP (base mod)
plus the Koreans add-on (`../age-of-pirates-koreans`) plus `AoP-StPauls-HomeCity`.

## 1. How the game resolves files

| Rule | Status |
|---|---|
| The enabled mods and their order are in `<profile>/mods/age3-mod-status.json` (`Mods[]`: `Title`, `Path`, `Priority`, `Enabled`). **The lower `Priority` wins** a path that two mods ship | game: AoP (1) beat the add-on (2) twice - its `castle.xml` (2026-10-10) and its `consulate.xml` (2026-10-11) showed instead of the add-on's merged copies |
| The additive data files are **merged** across mods: `protomods.xml`, `techtreemods.xml`, `civmods.xml`, `strings/<lang>/stringmods.xml` (and their `.xmb` twins) | game: the add-on's civ, units, techs and names appear next to AoP's |
| Other `*mods.xml` files (`abilities/abilitymods.xml`, `randomnamemods.xml`, `sound/soundsetsde.mods.xml`) follow the same naming | **unverified** per file: the Koreans add-on carries AoP's full `soundsetsde.mods.xml` plus its own sets because the merge was never proven |
| Every other file **replaces whole**: animfiles, `sound/<proto>_snds.xml`, `.tactics`, `.material`, textures, xaml, maps | game (the two cases above) |
| Paths compare case-insensitively (Windows); the checker does the same | assumption |

Players and the owner can reorder mods, so never make a feature depend on an order you do not control.

## 2. Audit the enabled mods

```bash
python .claude/skills/aoe3de-multi-mod/scripts/mod_overlap.py --profile "<...>/<steam id>/mods"
python .claude/skills/aoe3de-multi-mod/scripts/mod_overlap.py --profile ... --mods age-of-pirates age-of-pirates-koreans --fail
```

It lists every path two of the mods share, marks the merged `*mods.xml` files, and names the winner of each
replacing path (`SHADOW`). `--fail` exits 1 on a replacing path that is not passed to `--allow`. Read-only. On
2026-10-11 it found 62 shared paths between the three enabled mods: 59 merged, 3 shadowed (the consulate animfile
and two wagon sound files).

## 3. When an add-on needs a change in a file another mod overrides

Pick in this order:
1. **Additive record instead of a copy**: a `*mods.xml` entry, a new animfile or sound file under the add-on's own
   name, or a tech that swaps the proto's look. Nothing is shadowed.
2. **Host the branch in the winning mod's file** (the castle pattern). The base mod's own file carries the add-on's
   branch, keyed on something only the add-on defines: a marker tech the add-on's civ researches
   (`zpKoreanVisuals` in AoP's `castle.xml` and `consulate.xml`), a civ name in a `civlogic` choice, or another mod's
   tech (AoP's `zpAotWKhmers` is keyed on Age of the World's `Age0Khmers`). Without the add-on the branch never
   fires. Requirements:
   - the owner's exception recorded in the host's rules (AoP `AGENTS.md` rule 15);
   - the add-on generates the branch from its own source and fails its build check when the host's file drifts
     (Koreans: `korean_visuals.AOP_HOSTED`, `build.py --check`, `korean_visuals.py --write-aop`);
   - the host's reference checker accepts the add-on's paths in that branch (AoP `xmlcheck.py` `COMPANION_ART`);
   - the add-on ships **no** copy of that file.
3. **A copy built on the base mod's file** works only while the add-on outranks the base mod. Not in AoP's setup,
   where AoP is priority 1.

## 4. Gates

- **The add-on fails its own tests on a shadowed file:** every replacing path it ships that the base mod also ships
  (Koreans: `tests/test_no_shadowed_files.py`). A case waiting for the owner is listed with a strict xfail and an
  `AUDIT.md` entry, never silently allowed.
- **The base mod keeps the add-on's content out** except the hosted branches (AoP:
  `test_no_korean_civ_in_aop.py`, rule 15).
- **Before a release** of mods meant to run together, run `mod_overlap.py --fail` over exactly those mods.
- **Test in game per file type:** a merge or override seen working for one kind of file proves nothing for another.

## 5. Pitfalls

- **A generator that merges onto the base mod's file still loses** when the base mod outranks it: the Korean
  Consulate's merged copy was correct, byte for byte, and never shown.
- **Cross-mod references fail the host's checks:** soundsets defined only in the add-on read as "not defined" in
  the base mod's checker (journal 2026-10-08-claude-40). Allow them explicitly, like `COMPANION_ART`, or keep the
  reference in the add-on.
- **Verify the version on screen:** the game reads files at start (**visual-detail-check** `loaded_version.py`).
  Never change installed files while the owner's game runs.

Related: **aoe3de-new-civ** (civ add-ons), **aoe-xml** (file families, `xmlcheck.py`), **aoe3de-soundsets**,
**mod-deploy-check** (release zips), **vanilla-merge** (overrides against game patches).
