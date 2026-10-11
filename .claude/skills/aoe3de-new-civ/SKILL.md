---
name: aoe3de-new-civ
description: Add a new civilization to Age of Empires III DE as a separate add-on of a base mod, cloned from a vanilla civ. Covers the repository layout (one source of truth, base mod free of the civ's names), the civ entry and villager switch, setup and Shadow techs that actually fire, build-menu and tech-panel slots, new house types and the base mod's house rules, occupied-building attacks, explorer swaps, home-city cards, English-only strings, voices on shared protos, routing the civ's building models through vanilla animfiles the base mod may override, AI limits, and the add-on tests that catch each. Use when creating or extending a civ add-on, or for these symptoms - "the new building sits alone in the top row", "the civ tech never fires", "the house never shoots", "cards still ship the old villager", "the vanilla building shows instead of ours" - and before wiring a civ's buildings into vanilla animfiles.
---

# New civilization as an add-on

Distilled 2026-10-11 from journal records 2026-10-08-claude-28..41, 2026-10-09-claude-01/07..12,
2026-10-09-claude-houses-game-04 and 2026-10-11-claude-civic-pair-33. Worked example: the Koreans add-on
(`../age-of-pirates-koreans`: `tools/`, `tests/test_koreans.py`, `AUDIT.md`), a clone of Japan on top of AoP.
**Status** says what the evidence covers: *game* = seen in the owner's game test, *vanilla* = read in DE data,
*offline* = data and tests only, still to be seen in game.

## 1. Layout and ownership

- The add-on is its own mod folder and repository, the single source of truth for every civ record, model, tool and
  test. The base mod keeps no copy, mirror or source folder of it, not even one the game does not read (owner
  2026-10-08: "I said we're working in two separate mods!"). A guard test in the base mod fails on the civ's names in
  its data files and on a second copy of the add-on.
- The base mod never names the civ. When it must react to the civ (house rules, map setups), the add-on adds a record
  with the base mod's tech as prerequisite, or the base mod hosts an inert branch keyed on a marker tech that exists
  only with the add-on (section 7).
- Skills, even ones written while working in the add-on, go into the base mod's skill library and hold the generic
  method; civ-specific notes stay in the add-on (owner 2026-10-08).
- Take vanilla numbers from DE's own data (`aoe3de-bar-archives`: `bartool.py cat`), never from a legacy mod's copy of
  a vanilla proto: legacy mods rebalance vanilla records (one rebalanced 48 protos; a Shrine read 1400 HP instead of
  DE's 1300).

## 2. Civ entry, villager and home city

| Change | Where | Status |
|---|---|---|
| Swap the villager | the civ entry names it three times: `settlerprotoname`, every `townstartingunit`, every `empirewarsstartingunit` (20 entries for one clone); plus an Age0 setup tech that enables the new villager and disables the source civ's | offline |
| Home-city cards | vanilla villager-shipment cards ship the source civ's villager **by name**, whatever the card is called (`YPHCShipSettlersAsian1/2/5` ship `ypSettlerJapanese`); review every card and tech that targets the old villager | vanilla |
| Replace the explorer | before dropping the old explorer's unit type, list what the source civ's age-ups and cards do to it (Japan's age techs only scale the monk's sabotage damage) | vanilla |

## 3. Techs that fire

- **A civ-only effect at an age-up** is a Shadow tech: status `UNOBTAINABLE`, prerequisites `techstatus Active` of the
  age tech plus a civ marker tech. **It does not fire by itself:** the civ's setup tech must arm it with
  `TechStatus status=obtainable`; then it researches itself once its prerequisites are active (the house never shot
  until it was armed; AoP and vanilla arm theirs the same way). Status: fix offline, the house attack to re-check.
- **Own techs in an existing building's panel:** `CommandAdd tech=X page=P column=C` on that building (vanilla
  VeteranGrenadiers pattern); set the replaced techs unobtainable and the new ones obtainable from the setup tech.
  Status: game (four monastery techs in the Japanese monk techs' slots).

## 4. Buttons and slots

- **A new building in every villager's build menu at a fixed slot:** `Enable` plus `CommandAdd proto=X page=6
  column=N` on `AbstractVillager` (DE's `DEIndependenceConfucianAcademyUnlock` pattern). `AddTrain` has no slot: the
  button landed alone in the top row (owner's screenshot). The house slot is page 6 column 0.

## 5. New house types

- Carry every action the base mod adds to all houses (`ActionAdd unittype AbstractHouse`, e.g. AoP's `SpawnCowboy`,
  `SpawnChristmasTree`) in the new house's own tactics, or it silently misses those map features. Pin it with a test
  that reads the base mod's ActionAdd list.
- Base-mod map rules that disable standard houses or cap special ones (AoP `zpSPCDisableHousesShadow`) must also
  cover the new house: an add-on shadow tech with the base-mod tech as prerequisite (owner 2026-10-08).
- **A building that shoots only while occupied, stronger with more occupants:** tactics `RangedAttack` with
  `activeifcontainsunits 1`, `scalebycontainedunits 1`, `damagefactorcap` = capacity, `active 0` until a tech's
  `ActionEnable` (vanilla `village.tactics`, `dock.tactics`). Status: offline.

## 6. Units, strings and voices

- **A new explorer on an existing horse model** needs every animation its tactics name in both the horse animfile and
  the rider animfile it includes. Build and treasure pickup come from a vanilla mounted hero (General Kichiro's horse
  and rider pair); Idle copies made the unit stand still while building (owner's test). Mounted heroes have no
  Knockout/KnockoutIdle/Recover animations: the engine plays the death animation.
- **Animation checks read building animfiles per finished submodel** (anims live inside submodels, vanilla
  `shrine.xml`), unit animfiles at top level; a top-level-only check fails a correct building.
- **Strings are English only**, copied unchanged into every language by the add-on's build; only rewrites of
  original-game strings are translated (owner 2026-10-08). **aoe-game-text**.
- **Voices on a shared proto** (a villager both civs use): when the civ's soundsets mirror a vanilla family name by
  name, generate the sound file: wrap each matching leaf soundset in `civlogic` none / new civ and assert that every
  leaf was wrapped (**aoe3de-soundsets**). The base mod's `xmlcheck.py` resolves soundsets against the base mod only:
  check an add-on's soundsets against its own merged `soundsetsde.mods.xml` in an add-on test. Status: offline.

## 7. Buildings: route the civ's models through vanilla animfiles

- The civ's look on a shared building proto is a branch in the vanilla animfile, keyed on a civ marker tech that only
  the add-on's civ researches; the add-on's build merges its own logic-free animfile into the vanilla text and can strip
  it back byte-identically (**aoe-xml** art XML; Koreans `tools/korean_visuals.py`).
- **Check first whether the base mod overrides that animfile** (**aoe3de-multi-mod**, `mod_overlap.py`). An add-on
  copy loses to a base-mod override whenever the base mod stands above the add-on in mod priority: the Japanese castle
  (2026-10-10) and the Japanese consulate (2026-10-11) showed in game although the add-on's merged copies were correct.
  The base mod then hosts the inert branch itself (it never fires without the add-on's marker tech; the add-on's build
  check fails when the base mod's file drifts from the add-on source) and the add-on ships no copy; an add-on test
  fails on any shadowed file.
- Every building model ships with its test bed (**aoe3de-model-test-unit**), its construction and damaged states
  (**aoe3de-building-states**) and the lint profile of its texture class (**aoe-building-pipeline**).

## 8. AI

A mod civ gets the XS constant `cCiv<name>`, but a base mod that must run without the add-on can never name it
(the constant does not exist without the add-on, and the base mod keeps its core AI files byte for byte). Use a run-time lookup, or ship AI files in the add-on (subscribed civ
mods override `aisetup.xs` and `aihccards.xs`); **ai-edit**.

## 9. Add-on tests worth having

One civ on the setup tech; the techs it activates; strings, flags and voices; the house actions; every tactics
animation exists and moves (per finished submodel); replaced techs unobtainable; generated files current; every
routed building has a bench; materials keep their source `materialdef` (**aoe-xml** point 8). Chain dependent build
steps with `&&` or one script: a failed fix followed by a newline-separated run executed the unfixed original.

Icons and portraits: **icon-forge** and **image-harness** (`generate.py --ping` before promising paid work; low-quality
drafts are good enough at 128 px once the composition reads).

Related: **aoe-xml**, **aoe3de-reference** (`data_xml_guide.md`: civ and tech fields), **aoe3de-soundsets**,
**aoe-game-text**, **aoe3de-bar-archives**, **aoe3de-model-test-unit**, **aoe3de-building-states**,
**aoe-building-pipeline**, **ai-edit**, **workflow-journal**.
