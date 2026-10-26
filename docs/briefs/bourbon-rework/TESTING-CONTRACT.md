# Bourbon Rework: Observable Testing Contract

**Date:** 2026-10-26  
**Branch:** `bourbon-rework`  
**Scope:** Observable verification contract for Bourbon rework across production maps, rigged test maps, and dedicated bench maps.

---

## 1. Root Cause of Previous Bug (SPC Bourbon Spawning)

The game client and Scenario Editor load custom random maps from the **Steam Game installation folder**:
`<Steam>\steamapps\common\AoE3DE\Game\RandMaps\`
While the repo files (`randmaps/zpparis.xs`, `randmaps/zpverseilles.xs`, `game/randmaps/zpunknown.xs`) had been updated to vanilla `Bourbon`, the corresponding twin files in the Game installation root were not yet synchronized.

### Resolution:
1. Synchronized all production twins via `scripts/tools/sync_local_maps.py`:
   - `randmaps/zpparis.xs` -> `00000_zpparis.xs` (OK)
   - `randmaps/zpverseilles.xs` -> `00000_zpverseilles.xs` (OK)
   - `game/randmaps/zpunknown.xs` -> `0zpunknown.xs` (OK)
2. Rigged `0unknownRIGGED.xs` in Game root to guarantee Bourbon settlement spawn and Bourbon alliance.
3. Created 4 isolated test bed maps directly in `<Steam>\Game\RandMaps\`.

---

## 2. Dedicated Test Bed Maps (Game Root Only)

All 5 test maps sit exclusively in `<Steam>\Game\RandMaps\` with prefix `0000_` (sorting to the very top of Custom Maps). Each map provides 3 Settlers and starting crates right next to a Bourbon settlement (`deSocketBourbon`) placed at `(0.52, 0.50)` for instant testing.

| Map Stem | In-Game Display Name | Configuration & Triggers | Expected Observable Behavior |
|---|---|---|---|
| `0000_bourbon_1_extended` | `0000 Bourbon Test: Extended (Sun King Era)` | Subciv: `Bourbon`<br>Triggers: `cTechzpExtendedBourbons` active | - Build Trading Post on socket.<br>- **Page 0, Col 4:** Small Royal March button (`zpNatBourbonRoyalMarchSmall`).<br>- **Page 1, Col 1:** Sun King Era (`zpBourbonExpansion`).<br>- Big Royal March button is **hidden/unobtainable**. |
| `0000_bourbon_2_vanilla` | `0000 Bourbon Test: Vanilla (Normal)` | Subciv: `Bourbon`<br>Triggers: None (pure vanilla) | - Build Trading Post on socket.<br>- Standard vanilla **Big Royal March button** (`deNatPowerRoyalMarch`) is active/visible.<br>- **No** small button on Page 0 Col 4.<br>- **No** Sun King Era button on Page 1.<br>- 100% exact vanilla AoE3 DE behavior. |
| `0000_bourbon_3_paris_spc` | `0000 Bourbon Test: Paris Style SPC` | Subciv: `Bourbon`<br>Triggers: `Industrialize`, `cTechzpBonusBourbon` & `cTechzpExtendedBourbonsSPC`<br>Units: Includes `zpBourbonSummerPalaceWagon` | - Build Trading Post on socket.<br>- **Page 0, Col 4:** Small Royal March button.<br>- **Page 1, Col 1:** Sun King Era SPC (`zpBourbonExpansionSPC`).<br>- Researching Sun King Era grants D'Artagnan and Summer Palace Wagon.<br>- Unpack Chateau: before Maison du Roi, col 3 has no horseman. Research Maison du Roi -> Royal Horseman appears at col 3! |
| `0000_bourbon_4_paris_attacker` | `0000 Bourbon Test: Attacker Locked` | Subciv: `Bourbon`<br>Triggers: `cTechzpNatBourbonBigbuttonDisableShadow` & `cTechzpNatBigbuttonDisableShadow` | - Build Trading Post on socket.<br>- Royal March big button is **disabled / locked** (attacker / revolutionary state where royalist power is barred). |
| `0000_bourbon_5_ancien_regime` | `0000 Bourbon Test: Ancien Regime (card)` | Bench 2 plus one trigger: at 5 s `DEHCAncienRegime` active for player 1 only (the tech the French home city card ships; the card is in no default deck). Added 2026-10-26. | - Chat line `BOURBON TEST 5` at 5 s.<br>- A **European Embassy Wagon** arrives with the European wagon model, for any civ (Spain included).<br>- The wagon builds the embassy: Royal Musketeer (page 0 col 1), Royal Dragoon (col 2), Veteran/Guard Bourbon (page 1), Reforms, Fencing School, Royal Tax (page 2). |

---

## 3. Production Maps & Rigged Unknown

| Map | Location | Configuration | Expected Observable Behavior |
|---|---|---|---|
| **Paris** | `00000_zpparis.xs` | Subciv 2: `Bourbon`<br>`cTechzpBonusBourbon`<br>`cTechzpExtendedBourbonsSPC` | - Bourbon village spawns with `deSocketBourbon` and `deNatRoyalMusketeer`.<br>- Royalists observe Sun King Era SPC and small Royal March.<br>- Revolutionaries have royalist buttons disabled. |
| **Versailles** | `00000_zpverseilles.xs` | Subciv 2: `Bourbon`<br>`cTechzpBonusBourbon`<br>`cTechzpExtendedBourbonsSPC` | - Same as Paris (Defender gets royalist extension, Attacker gets big button disabled). |
| **Unknown** | `0zpunknown.xs` | Subciv 32: `Bourbon`<br>`DEUnknownAllianceBourbonEnabler`<br>`zpExtendedBourbons` loop | - Natural random chance for Bourbon village and alliance trigger.<br>- When Bourbon appears, vanilla `Bourbon` subciv and extension are active. |
| **Unknown Rigged** | `0unknownRIGGED.xs` | `nativeChance = 0.005`<br>`bourbonAlliance = 1`<br>`zpExtendedBourbons` loop | - **Guaranteed** Bourbon village spawn.<br>- **Guaranteed** Bourbon alliance granted to all players.<br>- Sun King extension active.<br>- Caveat (2026-10-26): an older vanilla-based Unknown (vanilla village groupings), not the current AoP map; its lobby name is the vanilla "Unknown". |
| **AoP Unknown Rigged** | `0zpunknown_rigged_bourbon.xs`, lobby `0 Unknown RIGGED: Bourbons` | The repo `game/randmaps/zpunknown.xs` plus 3 RIGGED edits: first Bourbon slot forced in both village chains (`counterBour < 0`), `bourbonAlliance = 1`. Added 2026-10-26. | - **Guaranteed** one AoP Bourbon village (`deSocketBourbon`); the other natives stay random.<br>- **Guaranteed** Bourbon alliance at the Native Embassy (`DEUnknownAllianceBourbon`, page 1 col 1).<br>- `zpExtendedBourbons` active for every player: small Royal March, Sun King Era. |

The older root rigs (`0unknownTWOISLANDS`, `0zpunknown - rig volcano`, `0zpunknown - rigged rogue`, `0zpunknown_rigged_ai`,
`zpunknown - rigged orthodox`) got the same three Bourbon edits as the repo map on 2026-10-26: subciv 32 = vanilla `Bourbon`,
the alliance enabler = vanilla `DEUnknownAllianceBourbonEnabler`, the `zpExtendedBourbons` loop. Their other rigs are unchanged.

---

## 4. Maison du Roi & Bourbon Chateau Royal Horseman Training

- **Requirement:** Researching Maison du Roi (`DENatBourbonMaisonDuRoi`) enables Royal Horseman training at the Bourbon Chateau (`zpBourbonSummerPalace`).
- **Implementation:**
  - `data/techtreemods.xml`: Added override for `DENatBourbonMaisonDuRoi` with:
    ```xml
    <tech name="DENatBourbonMaisonDuRoi">
      <effects>
        <effect mergemode="add" type="Data" amount="1.00" subtype="Enable" relativity="Absolute">
          <target type="ProtoUnit">deMercRoyalHorseman</target>
        </effect>
      </effects>
    </tech>
    ```
  - `data/protomods.xml`: `zpBourbonSummerPalace` already lists `<train row="0" page="0" column="3">deMercRoyalHorseman</train>`.
  - Rebuilt twin `data/techtreemods.xml.xmb`.
- **Observable Contract on `0000_bourbon_3_paris_spc`:**
  - Unpack the starting `zpBourbonSummerPalaceWagon`.
  - Before researching Maison du Roi: Page 0 shows Musketeer (col 1), Dragoon (col 2), and Royal March (col 4). Col 3 is empty (Royal Horseman not enabled yet).
  - Research Maison du Roi (`DENatBourbonMaisonDuRoi`) at the Chateau (Page 2, Col 4) or at the Trading Post.
  - Immediately: Royal Horseman (`deMercRoyalHorseman`) appears at Page 0, Column 3 of the Bourbon Chateau and can be trained!

---

## 5. TEMPORARY: the production Unknown carries the Bourbon rig (beta test)

Owner, 2026-10-26: "replace Unknown with Bourbon rigged version - the production one - track it as temorary change, we'll
export Beta like that with rigged version and let people test". The rig is the root test copy `0zpunknown_rigged_bourbon.xs`, taken verbatim.

- **Where:** `game/randmaps/zpunknown.xs` (ships) and its root twin `0zpunknown.xs` (synced, identical). The lobby name stays the
  production "Unknown".
- **What:** 3 edits, every rig line tagged `AOP-BETA-RIG (owner 2026-10-26, revert before prod)`:
  1. AoP village chain: `if (counterBour < 0) nativeChance = 0.145;` (the first Bourbon village is guaranteed);
  2. all-native chain: `if (counterBour < 0) nativeChance = 0.005;` (the same);
  3. `bourbonAlliance = 1;` (was the commented line `//<tab><tab>bourbonAlliance = 1;<tab>`; the alliance is guaranteed).
- **Not `AOP-TEST-ONLY` on purpose:** `make_zip.py` refuses beta and prod alike on that marker, and the beta must ship the rig.
  Nothing blocks a prod zip automatically: before a prod export, `grep -n AOP-BETA-RIG game/randmaps/zpunknown.xs` must be empty.
- **Revert:** delete the two `if (counterBour < 0)` line pairs and put back the commented line `//<tab><tab>bourbonAlliance = 1;<tab>`. Then run
  `python scripts/tools/sync_local_maps.py --sync`. `git diff` against the commit before the rig must then show no change from it.
- **Checks 2026-10-26:** mapcheck findings identical before and after (42 lines; only one line number moves by 2). Mapcheck suite:
  873 passed; the 5 failures are known ones, none on Unknown.
- **Expected in every Unknown game:** one Bourbon village (`deSocketBourbon`); the Bourbon alliance at the Native Embassy
  (`DEUnknownAllianceBourbon`); `zpExtendedBourbons` for every player (small Royal March, Sun King Era).

---

**Known and kept: Ancien Régime stacks (owner 2026-10-26, "we keep it").** Every activation of `DEHCAncienRegime` re-runs its
`UpgradeSubCivAlliance civ="Bourbon"`. Each run adds one Bourbon settlement's worth of units: +15 Royal Musketeers and +10 Royal Dragoons.
The card is re-activated by the Napoleonic revolution (`zpRevolutionFranceNE`, copied from vanilla `DERevolutionFranceNE`;
vanilla `DEIndependenceFrench` does it too) and by AoP's `zpMilitaryCampBuildLimit`.
Example: 1 settlement + the Chateau Royal + the card + the revolution = 60 / 40. This is not a test failure.

---

## 6. Verification Oracle & Pass Criteria

1. **Pre-flight Mapcheck:**
   - Ran `python -m scripts.mapcheck <stem> --static-only` across all 5 test maps (bench 5 on 2026-10-26):
   - Result: `0 FAIL, 0 WARN, 0 INFO` on every map.
   - `0zpunknown_rigged_bourbon`: the same 38 FAIL as `0zpunknown` (3 S4 stale-snapshot protos, 35 S7 edge constraints), none new.
2. **In-Game Observation Pass Criteria:**
   - In `0000_bourbon_1_extended`: Small button at page 0 column 4 is clickable; Sun King Era is clickable at page 1 column 1.
   - In `0000_bourbon_2_vanilla`: Big button appears in center; no small button or Sun King Era.
   - In `0000_bourbon_3_paris_spc`: SPC Sun King Era trains D'Artagnan; researching Maison du Roi enables Royal Horseman at the Chateau!
   - In `0000_bourbon_4_paris_attacker`: Big button is greyed out / inactive.
   - In `0000_bourbon_5_ancien_regime`: chat `BOURBON TEST 5` at 5 s; the European Embassy Wagon arrives as the European wagon; its embassy offers Royal Musketeer and Royal Dragoon.
   - In `0zpunknown_rigged_bourbon`: a Bourbon village on the map; the Native Embassy offers the Bourbon alliance at page 1 col 1.
   - In the production Unknown (beta rig, section 5): every game has one Bourbon village and the Bourbon alliance at the Native Embassy.
