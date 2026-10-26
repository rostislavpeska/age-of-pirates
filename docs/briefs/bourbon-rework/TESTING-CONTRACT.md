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

All 4 test maps sit exclusively in `<Steam>\Game\RandMaps\` with prefix `0000_` (sorting to the very top of Custom Maps). Each map provides 3 Settlers and starting crates right next to a Bourbon settlement (`deSocketBourbon`) placed at `(0.52, 0.50)` for instant testing.

| Map Stem | In-Game Display Name | Configuration & Triggers | Expected Observable Behavior |
|---|---|---|---|
| `0000_bourbon_1_extended` | `0000 Bourbon Test: Extended (Sun King Era)` | Subciv: `Bourbon`<br>Triggers: `cTechzpExtendedBourbons` active | - Build Trading Post on socket.<br>- **Page 0, Col 4:** Small Royal March button (`zpNatBourbonRoyalMarchSmall`).<br>- **Page 1, Col 1:** Sun King Era (`zpBourbonExpansion`).<br>- Big Royal March button is **hidden/unobtainable**. |
| `0000_bourbon_2_vanilla` | `0000 Bourbon Test: Vanilla (Normal)` | Subciv: `Bourbon`<br>Triggers: None (pure vanilla) | - Build Trading Post on socket.<br>- Standard vanilla **Big Royal March button** (`deNatPowerRoyalMarch`) is active/visible.<br>- **No** small button on Page 0 Col 4.<br>- **No** Sun King Era button on Page 1.<br>- 100% exact vanilla AoE3 DE behavior. |
| `0000_bourbon_3_paris_spc` | `0000 Bourbon Test: Paris Style SPC` | Subciv: `Bourbon`<br>Triggers: `Industrialize`, `cTechzpBonusBourbon` & `cTechzpExtendedBourbonsSPC`<br>Units: Includes `zpBourbonSummerPalaceWagon` | - Build Trading Post on socket.<br>- **Page 0, Col 4:** Small Royal March button.<br>- **Page 1, Col 1:** Sun King Era SPC (`zpBourbonExpansionSPC`).<br>- Researching Sun King Era grants D'Artagnan and Summer Palace Wagon.<br>- Unpack Chateau: before Maison du Roi, col 3 has no horseman. Research Maison du Roi -> Royal Horseman appears at col 3! |
| `0000_bourbon_4_paris_attacker` | `0000 Bourbon Test: Attacker Locked` | Subciv: `Bourbon`<br>Triggers: `cTechzpNatBourbonBigbuttonDisableShadow` & `cTechzpNatBigbuttonDisableShadow` | - Build Trading Post on socket.<br>- Royal March big button is **disabled / locked** (attacker / revolutionary state where royalist power is barred). |

---

## 3. Production Maps & Rigged Unknown

| Map | Location | Configuration | Expected Observable Behavior |
|---|---|---|---|
| **Paris** | `00000_zpparis.xs` | Subciv 2: `Bourbon`<br>`cTechzpBonusBourbon`<br>`cTechzpExtendedBourbonsSPC` | - Bourbon village spawns with `deSocketBourbon` and `deNatRoyalMusketeer`.<br>- Royalists observe Sun King Era SPC and small Royal March.<br>- Revolutionaries have royalist buttons disabled. |
| **Versailles** | `00000_zpverseilles.xs` | Subciv 2: `Bourbon`<br>`cTechzpBonusBourbon`<br>`cTechzpExtendedBourbonsSPC` | - Same as Paris (Defender gets royalist extension, Attacker gets big button disabled). |
| **Unknown** | `0zpunknown.xs` | Subciv 32: `Bourbon`<br>`DEUnknownAllianceBourbonEnabler`<br>`zpExtendedBourbons` loop | - Natural random chance for Bourbon village and alliance trigger.<br>- When Bourbon appears, vanilla `Bourbon` subciv and extension are active. |
| **Unknown Rigged** | `0unknownRIGGED.xs` | `nativeChance = 0.005`<br>`bourbonAlliance = 1`<br>`zpExtendedBourbons` loop | - **Guaranteed** Bourbon village spawn.<br>- **Guaranteed** Bourbon alliance granted to all players.<br>- Sun King extension active. |

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

## 5. Verification Oracle & Pass Criteria

1. **Pre-flight Mapcheck:**
   - Ran `python -m scripts.mapcheck <stem> --static-only` across all 4 test maps:
   - Result: `0 FAIL, 0 WARN, 0 INFO` on every map.
2. **In-Game Observation Pass Criteria:**
   - In `0000_bourbon_1_extended`: Small button at page 0 column 4 is clickable; Sun King Era is clickable at page 1 column 1.
   - In `0000_bourbon_2_vanilla`: Big button appears in center; no small button or Sun King Era.
   - In `0000_bourbon_3_paris_spc`: SPC Sun King Era trains D'Artagnan; researching Maison du Roi enables Royal Horseman at the Chateau!
   - In `0000_bourbon_4_paris_attacker`: Big button is greyed out / inactive.
