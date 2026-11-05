# WP2 Analysis: Ancien Regime and Napoleonic Era Reverse Engineering

**Date:** 2026-10-26  
**Status:** Completed Analysis (Read-Only)  
**Output:** Target design and Truth Tables for WP6

---

## 1. Questions Q1 to Q12

### Q1: Vanilla `DEHCAncienRegime` Effects
- **UpgradeSubCivAlliance (`civ="Bourbon"`):** Upgrades any existing Bourbon alliance.
- **European Embassy Reskin:** Sets name to 124945, icon to `deIconEuropeanEmbassy`, enables `NativeEmbassy` proto, grants `deEmbassyTravois`.
- **Enables Merc Units:** Enables `deNatMercRoyalMusketeer` and `deNatMercRoyalDragoon` with pop costs (1 and 2 pop).
- **Embassy Train Commands:** Adds `deNatMercRoyalMusketeer` (col 1) and `deNatMercRoyalDragoon` (col 2) to `NativeEmbassy`.
- **Embassy Tech Commands:** Adds `DEVeteranBourbon`, `DEGuardBourbon`, `DENatBourbonReforms`, `DENatBourbonFencingSchool`, and `DENatBourbonRoyalTax` to `NativeEmbassy`.
- **Sets Tech Status:** Makes all 5 above Bourbon techs obtainable for the player.
- **Dependency:** Specifically requires vanilla `Bourbon` subciv alliance and `NativeEmbassy`.

### Q2: The Mod Override of `DEHCAncienRegime` (lines 21248?21266)
- **What it removes (`mergemode="remove"`):**
  - Removes all 5 `CommandAdd` effects for `DEVeteranBourbon`, `DEGuardBourbon`, `DENatBourbonReforms`, `DENatBourbonFencingSchool`, `DENatBourbonRoyalTax` on `NativeEmbassy`.
  - Removes all 5 `TechStatus obtainable` effects for those same techs.
  - Removes `UpgradeSubCivAlliance` for `civ="Bourbon"`.
- **Why:** Because the mod created a custom clone `SPCBourbon` subciv and did not want vanilla Bourbon techs to show up in the Embassy or trigger alliance upgrades on maps using `SPCBourbon`.
- **What replaced it:** `zpAncienRegimeAddTechsToEmbassy` (~21269) was added to inject the `zp` clone techs (`zpVeteranBourbon`, `zpGuardBourbon`, etc.) into `NativeEmbassy` instead.

### Q3: `zpAncienRegimeAddTechsToEmbassy` (~line 21269)
- **Function:** Injects `CommandAdd` for `zpVeteranBourbon`, `zpGuardBourbon`, `zpNatBourbonReforms`, and `zpNatBourbonRoyalTax` to `NativeEmbassy`, and sets their status to obtainable.
- **Activator:** Activated by `zpAncienRegimeNormalizer` and `zpParisSetup`.
- **Prereqs:** Prereq is `DEHCAncienRegime`.

### Q4: `zpAncienRegimeNormalizer` (~line 20988)
- **Function:** Normalizes tech statuses between French home city shipments, the Paris map setup, and the Embassy.
- **On a vanilla map:** Where `zpBonusBourbon` is never active, `zpAncienRegimeNormalizer` is inactive. Vanilla maps running French Ancien R?gime had their Embassy techs stripped by the mod override, causing the Embassy to lack Bourbon upgrade techs on vanilla maps!

### Q5: Maps that activate `zpBonusBourbon`
- `randmaps/zpparis.xs` (line 2038)
- `randmaps/zpverseilles.xs` (line 1834)
- `game/randmaps/zpunknown.xs` (line 16932)
- `randmaps/performance_test.xs` (line 1679)
- **Embassy presence:** Paris has `zpNativeEmbassyParisReward` and regular `NativeEmbassy`. Versailles and Unknown can build `NativeEmbassy` via Ancien R?gime travois.

### Q6: `DERevolutionFranceNE` and `zpRevolutionFranceNE` Buff Overlap
- Vanilla `DERevolutionFranceNE` buffs:
  - `deNatMercRoyalMusketeer`: +40% HP, +40% Damage, MortarAttack enabled, -PistolCharge, +2 LOS.
  - `deNatMercRoyalDragoon`: +40% HP, +30% Damage.
- Mod `zpRevolutionFranceNE`:
  - Buffs `deNatMercRoyalMusketeer` and `deNatMercRoyalDragoon` by the exact same amounts.
  - Also buffs `zpNatRoyalMusketeer` and `zpNatRoyalDragoon`.
  - Sets `DEHCAncienRegime` active.
- **Double Buff Risk:** If `zpRevolutionFranceNE` and vanilla `DERevolutionFranceNE` both fire, `deNatMercRoyalMusketeer` would get +80% HP and +80% damage. Once `zpNatRoyal...` is replaced by `deNatRoyal...`, `zpRevolutionFranceNE` must not duplicate buffs on `deNatMerc...`.

### Q7: The Sansculotte / Napoleonic Consulate Chain
- `zpConsulateRevNapoleon` (~19036) -> unlocked at Consulate (Age 2/3).
- Researches `zpRevolutionFranceNE` (~20717).
- Activates `zpNapoleonicEraIcons` (~21172), `zpNapoleonicEraNames` (~21227), and `zpNapoleonicEraNamesLegendary` (~21292).
- Enables Mortar attack and changes visual appearances.

### Q8: `zpMilitaryCampBuildLimit` (~20962)
- Sets `DEHCAncienRegime` active to grant the European Embassy travois and allow training of Royal Musketeers if the player hasn't shipped the card.
- After rework: It still enables Ancien R?gime mechanics cleanly without needing the SPC subciv.

### Q9: Names and Icons on `DEVeteranBourbon` / `DEGuardBourbon`
- `zpNapoleonicEraNames` and `zpNapoleonicEraIcons` currently check for `zpVeteranBourbon` and `zpGuardBourbon`.
- Replacement: Repoint condition to `DEVeteranBourbon` and `DEGuardBourbon`.

### Q10: Buffs to `zpAbstractHeroMusketeer`
- Target the abstract unittype `zpAbstractHeroMusketeer` (Athos, Porthos, Aramis, D'Artagnan).
- Buffs in `DERevolutionFranceNE` and `zpRevolutionFranceNE` apply cleanly to the abstract unittype.

### Q11: `DENatBourbonFencingSchool`
- Vanilla Ancien R?gime grants `DENatBourbonFencingSchool`. Mod override removed it.
- On Paris today, fencing school is absent from the Embassy.
- After rework: Fencing school restores cleanly as part of vanilla Bourbon.

### Q12: Embassy Content Today
- On vanilla map: Missing Bourbon upgrade techs due to mod override removal!
- On Paris / Versailles: Displays `zp` clone techs via `zpAncienRegimeAddTechsToEmbassy`.
- Target: Both vanilla maps and Paris/Versailles show standard vanilla Bourbon techs in the Embassy.

---

## 2. Truth Table: Current vs Target

| Case | Map / Situation | Today (Mod) | Target (Vanilla Bourbon) |
|---|---|---|---|
| **C1** | French on vanilla map, no Bourbon TP | Embassy missing upgrade techs (broken by override) | Clean vanilla Embassy (Ancien R?gime has all vanilla techs) |
| **C2** | French on vanilla map with Bourbon TP | Double alliance confusion (SPCBourbon vs Bourbon) | Single unified vanilla Bourbon alliance |
| **C3** | Paris Royalist | Uses `zpSPCNativeBourbon`, `zp` clone units, custom Embassy | Uses vanilla `Bourbon`, `de` units, extension shadow active |
| **C4** | Paris Revolutionary | Sansculottes active, Bourbon techs disabled by shadow | Identical behavior via `zpNatBourbonBigbuttonDisableShadow` |
| **C5** | Versailles Attacker | Uses `zpSPCNativeBourbon` sockets | Uses `deSocketBourbon`, extension shadow active |
| **C6** | Versailles Defender | Defender setup swaps expansion | Clean extension shadow |
| **C7** | Unknown with Bourbon alliance | Uses commented Enabler / `SPCBourbon` | Uses vanilla Enabler & `Bourbon` subciv |
| **C8** | French Rev -> Napoleonic France | Duplicate buff risk between NE techs | Buffs apply strictly once per unit |
| **C9** | Non-French civ with Bourbon TP | Researches broken `zp` techs | Researches working vanilla Bourbon techs |

---

## 3. Target Design for WP6
1. Remove mod overrides in `data/techtreemods.xml` that stripped vanilla effects from `DEHCAncienRegime`.
2. Deprecate `zpAncienRegimeAddTechsToEmbassy` and `zpAncienRegimeNormalizer`.
3. In `zpRevolutionFranceNE`, eliminate duplicate buff lines that hit `deNatMerc...` twice.
4. Repoint Napoleonic Era names and icons from `zpVeteranBourbon`/`zpGuardBourbon` to `DEVeteranBourbon`/`DEGuardBourbon`.
