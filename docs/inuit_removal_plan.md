# Surgical removal of the AoP Inuit units

Written 2026-07-25. Precedes the switch to extending the DLC's Inuit civ.

**Scope: trainable units and the settlement socket only.** Architecture and props
stay — they only lose their `<subciv>` binding so they become plain decorative
protos. Maps and groupings keep their AoP look.

## Why cloning was abandoned

`DENatInuitQimmiit` carries:

```xml
<effect type="Data" subtype="DeadReplacement" proto="deQimmiitDeathReplacement">
  <target type="ProtoUnit">deNatInuitQamutik</target>
</effect>
```

It targets the DLC proto **by name**, so a clone can never receive the dead
replacement or the `deNatHusky` enable. The tech itself would have to be cloned
and re-reconciled after every patch.

General rule for future civ work: before choosing clone-vs-extend, grep the DLC's
techs for `<target type="ProtoUnit">` naming its units. Proto-targeted effects
make cloning lossy.

## What happens to each proto

| Proto | dbid | Action |
|---|---|---|
| `zpInuitTorchman` | 20127 | **DELETE** — trainable |
| `zpInuitDogVillager` | 20126 | **DELETE** — trainable |
| `zpSocketInuits` | 20121 | **DELETE** — settlement socket |
| `zpNativeHouseInuit` | 20122 | keep, **drop `<subciv>InuitNatives`** |
| `zpInuitVilProp` | 20123 | keep as-is (has no `<subciv>`) |
| `zpNatInuitHarpooner` | 20124 | keep unchanged — still needed |
| `zpInuitWarCanoe` | 20128 | keep unchanged — see below |

### `zpInuitWarCanoe` stays

Despite the name it has **no `<subciv>`** and is trained from `Dock`, `dePort`,
`YPDockAsian` and `zpDrydock`. It is a general naval unit using Inuit art, enabled
by `zpInuitUmiaks`. Deleting it would strip a ship from four docks. Renaming it to
drop the Inuit association is optional cosmetic work, not part of this.

## Edits

### data/protomods.xml

Delete the three `<unit>` blocks, then the references that would dangle:

| Where | Line to remove |
|---|---|
| `TradingPost` | `<train row="0" page="0" column="3">zpInuitDogVillager</train>` |
| `NativeEmbassy` | `<train row="0" page="0" column="89">zpInuitTorchman</train>` |
| `zpNativeEmbassyParisReward` ×2 | `<train row="0" page="0" column="88">zpInuitTorchman</train>` |

`zpInuitTorchman`'s `TradingPost` train line is **already commented out**, so only
the embassy entries are live.

`zpNativeEmbassyParisReward` appears **twice** as a `<unit>` entry — pre-existing
duplication, but both copies carry the line.

On `zpNativeHouseInuit`, delete only:

```xml
<subciv>InuitNatives</subciv>
```

### data/techtreemods.xml

| Tech | Reference to remove |
|---|---|
| `zpNativeInuits` | `Data/Enable` → `zpInuitDogVillager` |
| `zpUnknownAllianceInuits` | `Data/Enable` → `zpInuitDogVillager` |
| `zpWarriorSocietyInuit` | Hitpoints/Damage → `zpInuitTorchman` |
| `zpChampionInuit` | Hitpoints/Damage → `zpInuitTorchman` |
| `zpNatInuitInfluence` | `Enable` / `BuildLimit` → `zpInuitTorchman` |

`zpInuitUmiaks` → `zpInuitWarCanoe` is untouched.

After the edit, check `zpWarriorSocietyInuit` and `zpChampionInuit`: they exist to
buff Inuit units. If the harpooner is their only remaining target they still work;
if they end up with no targets at all they should be dropped or repointed at the
DLC units during the extension.

### game/randmaps and game/ai

Only the socket is going, so the villages keep their igloos and props. Repoint:

| File | Change |
|---|---|
| `groupings/Native Inuit Village 01–05.xml` | `zpSocketInuits` → `deSocketInuit` (1 each) |
| `zpcoldwar.xs` | `zpSocketInuits` → `deSocketInuit` (2) |
| `game/ai/core/aipiraterules.xs` | `zpSocketInuits` → `deSocketInuit` (1) |

`zpunknown.xs` references `zpInuitDogVillager` once — that spawn must be removed
or repointed at a DLC unit.

`zpNativeHouseInuit` (33 refs) and `zpInuitVilProp` (10 refs) across the groupings
need **no change** — the protos survive.

### sound/

Delete `zpinuittorchman_snds.xml` and `zpInuitdogvillager_snds.xml`.
Keep `zpnatinuitharpooner_snds.xml` and `zpinuitwarcanoe_snds.xml`.

### data/civmods.xml

`InuitNatives` stays for now — `zpNatInuitHarpooner` still uses it as `<subciv>`.
Whether the civ survives depends on how the extension binds the harpooner.

### art/

Nothing deleted. `art/units/artillery/inuit_qamutiik/` is still used by
`zpSantaHelper` and `zpTradeSledge`. Orphans can be identified once the extension
is finished.

## Order

1. `zpInuitTorchman` — 3 files, smallest blast radius, and the DLC Qamutik
   directly replaces it
2. `zpInuitDogVillager` — includes the `zpunknown.xs` spawn
3. `zpSocketInuits` — the 7 map/AI repoints
4. `zpNativeHouseInuit` — one-line `<subciv>` removal

## Verification

- no reference to `zpInuitTorchman`, `zpInuitDogVillager` or `zpSocketInuits`
  anywhere under `data/`, `game/` or `sound/`
- `zpNativeHouseInuit` and `zpInuitVilProp` still resolve in all five groupings
- `zpNatInuitHarpooner` and `zpInuitWarCanoe` unchanged
- all `data/*.xml` parse; `.xmb` pairs recompiled
