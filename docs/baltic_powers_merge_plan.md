# Baltic Powers DLC — merge plan

Status against game build `24241387` (`open_beta`). Written 2026-07-25.

Tooling: `.claude/skills/bar-extract` (read vanilla out of the `.bar` archives)
and `.claude/skills/vanilla-merge` (find and re-add dropped records).

## Done

- `sound/soundsetsde.xml` → additive `sound/soundsetsde.mods.xml`. Recovered 268
  soundsets; the override's whole contribution was 1 record.
- Five `*_snds.xml` overrides merged: Danish/Polish/Italian/Maltese/Japanese/
  Canadian civ branches restored, frozen Mexican mappings corrected.
- Commit `5684731e`.

## A. Tactics — 21 overrides, 23 changes to apply

Record-level comparison reports only 7 dropped records. That is misleading: an
`<action>` can carry the mod's own tuning *and* still be missing a child the game
added. At child level there are 24 genuinely missing elements, of which 23 should
be applied and 1 is a decision (below).

| Change | Count | Files |
|---|---|---|
| `<typedanim type="deFishingHole">GatherFish` in `<gather>` | 7 | coureur, settler, settlerafrican, settlerindian, settlerjapanese, settlernative, settlerwagon |
| `<rate type=…>` in healer `<gather>` | 7 | healer — Plantation, Farm, Mill, AbstractBerryBush, AbstractInfiniteCrate, ypBerryBuilding, ypGroveBuilding |
| `<action>` reference inside `<tactic>Normal` | 6 | tradingpost ×3 (Kontors), settler, settlerwagon, healer |
| `<rate type="All">1.0` in `<flameattack>` | 1 | flamethrower |
| `<boredanim>` | 2 | saloonpirate (defend, standground) |

Five of these also need the matching `<action>` **definition** added, not just the
reference, or the file gains a dangling reference:

| File | Action to define + reference |
|---|---|
| `tradingpost.tactics` | `AutoGatherKontorsFood`, `AutoGatherKontorsWood`, `AutoGatherKontorsGold` |
| `settler.tactics` | `IncreaseHPWithUnits` |
| `settlerwagon.tactics` | `AutoGatherTrade` |
| `healer.tactics` | `Build` |
| `saloonpirate.tactics` | `coverrangedattack` (definition only — no tactic references it) |

The `AutoGatherKontors*` actions are Hanseatic Kontor gathering, i.e. Baltic-era.
All 21 files currently have **zero** dangling references; that invariant must hold
after the merge.

### Do not touch

`<active>` is the mod's, not vanilla's. saloonpirate's `HandAttackCrate` and
`RangedAttack` are `<active>1</active>` where vanilla has `0` — deliberately
enabled. Likewise defend/standground swap the whole ranged→hand attack profile and
`Cover_*`→`Charge_*` animations. Restoring vanilla's values there would silently
disable working content.

### One open decision

`<tactic>volley` — vanilla has `<active>0</active>`, the mod has no `<active>` at
all. Adding it disables Volley. Given the pattern above the mod probably wants it
enabled, so the default is **leave it out**. Confirm before applying.

### Method

In-place byte-level edits against the existing files (as used for the `_snds`
merge), not regeneration — formatting, indentation and `<soundset>` style stay put
so the diff shows only real changes.

## B. Folwark

Poland's Folwark replaces the Mill/Farm and the engine treats it as a **distinct
unittype**, `AbstractFolwark`, carried by five protos: `deFolwark`,
`deFolwarkFarm`, `deFolwarkLivestock`, `deFolwarkDefensive`, `deFolwarkSich`.

Nothing to do in tactics: Folwark appears only in `czern.tactics`, `herd.tactics`
and `protoactioncontainer.tactics`, none of which the mod overrides.

### B1. `data/unittypes.xml` is missing `AbstractFolwark`

`unittypes.xml` is a *registration list*, not a registry of every type: vanilla
holds only **17** entries. A type is otherwise established by being carried on a
proto (`<unittype>X</unittype>`) — across vanilla + mod that is 304 abstract types
over 3627 protos.

The mod's file has 37 entries: 5 shared with vanilla, 32 its own, and **12 vanilla
entries dropped**:

```
AbstractFolwark          AbstractTrainingShip     AbstractRegent
AbstractShogunate        AbstractGoldenPavillion  AbstractRebuildableWonder
AbstractToriiGates       AbstractWhitePagoda      AbstractPorcelainTower
AbstractTowerOfVictory   LogicalTypeStealthUnit   LogicalTypeCanSpawnCattle
```

Until `AbstractFolwark` is declared, **any effect targeting it cannot resolve** —
including the vanilla farming techs that already carry Folwark effects. Fix this
first; it is a prerequisite for B2 being testable.

Fix: append the 12 to the mod's list (order is not significant; the mod already
keeps vanilla's first 5 at the top). Result: 49 entries. Then regenerate the paired
`data/unittypes.xml.xmb` in Resource Manager — there is no XMB writer in the
toolkit.

Hygiene note: all 37 current entries are referenced somewhere, so there is nothing
to prune.

### B3. Dangling references found while auditing unittypes

Sweeping every `unittype=` reference against the 3931 known names (protos +
abstract types) turned up a small number of genuinely broken ones. `protomods.xml`
is clean — 0 dangling references. Two live problems in `techtreemods.xml`:

| Reference | Refs | Diagnosis |
|---|---|---|
| `zpNatMersSettlementMilitia` | 2 (`techtreemods.xml:7753`, `:7768`) | **Typo** for `zpNatMer`**c**`SettlementMilitia`, which exists. Both are `FreeHomeCityUnit amount="10"` — the shipment currently delivers nothing. |
| `zpNatMercPavisier` | 1 (`techtreemods.xml:10290`) | **Missing proto.** `zpNatPavisier` exists but the `Merc` variant does not, though a sound file declares it. `FreeHomeCityUnit amount="12"` delivers nothing. |

The `zpNatMerc*` / `zpNat*` pairing is a strong convention — 27 merc protos, 23
with a matching base — so `zpNatMercPavisier` was probably intended and never
added. Either create the proto or repoint the effect at `zpNatPavisier`.

Separately, five `sound/*_snds.xml` files declare a protounit that exists nowhere:

```
zpmercwokousteamer_snds.xml   -> zpMercWokouSteamer
zpnatmercpavisier_snds.xml    -> zpNatMercPavisier   (see above)
zpnatoprichnik_snds.xml       -> zpNatOprichnik
zpnatrifleman_snds.xml        -> zpNatRifleman
zpnatwarwagon_snds.xml        -> zpNatWarWagon
```

Harmless — the game never looks them up — but they are dead files from renamed or
removed units, and `zpnatmercpavisier_snds.xml` is evidence for the missing proto
above. Delete or reconnect.

### B2. Mod farming techs do not reach Folwarks

**Vanilla pattern.** A food-economy tech lists each gatherable target explicitly.
Where Poland can research it, `AbstractFolwark` sits alongside `Mill` and `Farm`:

```xml
<effect type="Data" action="Gather" amount="1.15" subtype="WorkRate" unittype="Mill"            relativity="BasePercent">
<effect type="Data" action="Gather" amount="1.15" subtype="WorkRate" unittype="Farm"            relativity="BasePercent">
<effect type="Data" action="Gather" amount="1.15" subtype="WorkRate" unittype="AbstractFolwark" relativity="BasePercent">
<effect type="Data" action="AutoGatherFood" amount="1.15" subtype="WorkRate" unittype="Food"    relativity="BasePercent">
```
(`SeedDrill`, `HCFoodSilos` — same shape.)

It is **not** universal: 42 vanilla techs pair Farm with AbstractFolwark, 47 touch
Farm without it (e.g. `ImpLargeScaleAgriculture`, `ChurchCodeNapoleon`). The
discriminator is whether a Polish player can reach the tech.

**Mod status: 11 techs boost Farm, 0 mention Folwark.** So a Polish player gets
none of the mod's farm economy.

| Tech | Source | Farm | Reaches Poland? |
|---|---|---|---|
| `zpNatCossackGoldenFields` | Cossack native | 1.15 | yes — native alliance |
| `zpNatSufiFastingClone` | Sufi native | 1.10 | yes — native alliance |
| `zpPolynesianAgriculture` | Polynesian native | 1.30 | yes — native alliance |
| `zpJewishTorah` | Jewish native | 1.15 | yes — native alliance |
| `zpJewishYomKippur` | Jewish native | 1.20 | yes — native alliance |
| `zpAcademyBiology1` | Academy (mod building) | 1.07 | verify Poland can build it |
| `zpAcademyBiology2` | Academy | 1.07 | verify |
| `zpAcademyEconomy1` | Academy | 1.05 | verify |
| `zpAcademyEconomy2` | Academy | 1.05 | verify |
| `zpBigConsulateFrenchClone` | Consulate | 1.05 | verify — consulate access |
| `zpConsulateRevPresidentConfederate` | Revolution | 1.15 | verify — can Poland revolt |

All 11 already carry a `Mill` effect at the same amount, so the fix is one extra
`<effect>` per tech mirroring the `Farm`/`Mill` line with
`unittype="AbstractFolwark"`. All 11 are new `zp*` definitions — no `mergeMode`
needed, just add the element.

The five native techs are unambiguous. The other six depend on mod design; decide
per tech rather than blanket-applying.

### Not a problem

`techtreemods.xml` names 50 vanilla techs, which looked at first like overrides
that might drop vanilla Folwark effects. Only `DESPCNapoleonicSetup` touches farm
rates, and it uses `mergeMode="add"` with a single ResearchPoints effect — it
appends, it does not replace. `mergeMode` appears exactly once in the whole file.

## Verification

1. `mergetool report tactics` → DROPPED 0.
2. `mergetool report unittypes` → DROPPED 0 (49 entries).
3. No dangling `<tactic>`→`<action>` references (all 21 files).
4. No dangling `unittype=` references in `techtreemods.xml` (currently 2).
5. No `*_snds.xml` declaring a non-existent protounit (currently 5).
6. In game: Polish Folwark food rate before/after researching one native farm tech.
7. Re-run `bartool verify "*.xmb"` after any game patch — 16800/16800 expected.

## Remaining queue (not covered here)

`mergetool report` still lists other stale overrides — `waterbodies2.xml`,
`traderoutedefs.xml`, `battle.xml`, `tacticdisplay.xml`, `particlesets.xml`, the
art `.material`/unit XML, and 23 differing binaries. Also
`data/gatheringplacedata.xml`, which is not keyable and needs manual work.
