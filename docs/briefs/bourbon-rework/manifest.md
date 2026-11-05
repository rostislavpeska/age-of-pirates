# Bourbon Rework Manifest (WP1 Inventory)

**Date:** 2026-10-26 | **Commit:** `629e69c1` | **Scope:** WP1 Read-Only Inventory and Manifest

## 1. Baseline Test Suites

| Test Suite | Passed | Failed | Skipped | XFailed | Duration | Status |
|---|---|---|---|---|---|---|

## 2. Vanilla Data Files Extracted

Extracted into `<SCRATCH>/vanilla/`:

- `abilities.xml`
- `civs.xml`
- `powers.xml`
- `protounitcommands.xml`
- `protoy.xml`
- `techtreey.xml`

## 3. Old -> New Name Map (Section 4 Confirmed)

| Old (Mod) | New (Vanilla / Target) | Vanilla File | Vanilla Line | Vanilla DBID | Notes |
|---|---|---|---|---|---|
| `civ SPCBourbon` | `Bourbon` | `civs.xml` | 13646 | - | Verified in vanilla civs.xml (). Note: SPCBourbon has <homecityflagtexture>objects\flags\natives\bourbon_french</homecityflagtexture> in data/civmods.xml (~556); vanilla Bourbon civ has no homecityflagtexture. See Decision D6. |
| `zpSocketSPCBourbon` | `deSocketBourbon` | `protoy.xml` | 169854 | - | Verified in vanilla protoy.xml; used by stock AI (aitechs.xs). |
| `zpNatRoyalMusketeer` | `deNatRoyalMusketeer` | `protoy.xml` | 154832 | - | Verified in vanilla protoy.xml; mod override already exists at data/protomods.xml  (giving it the Build action for Military Camp). |
| `zpNatRoyalDragoon` | `deNatRoyalDragoon` | `protoy.xml` | 175031 | - | Verified in vanilla protoy.xml; mod override exists at data/protomods.xml . |
| `zpNatRoyalHorsemanBourbonProxy` | `deNatRoyalHorsemanBourbonProxy` | `protoy.xml` | 171908 | - | Verified in vanilla protoy.xml under TradingPost train: <train row="0" page="0" column="3">deNatRoyalHorsemanBourbonProxy</train>, mapped in vanilla civs.xml to deMercRoyalHorseman. |
| `zpSPCNativeBourbon` | `DENativeBourbon` | `techtreey.xml` | 127077 | 9121 | Verified in vanilla techtreey.xml (, ). |
| `zpSPCNativeBourbonColonialize` | `DENativeBourbonColonialize` | `techtreey.xml` | 133343 | 9301 | Verified in vanilla techtreey.xml (, ). |
| `zpVeteranBourbon` | `DEVeteranBourbon` | `techtreey.xml` | 129754 | 9230 | Verified in vanilla techtreey.xml (, ). |
| `zpGuardBourbon` | `DEGuardBourbon` | `techtreey.xml` | 129790 | 9231 | Verified in vanilla techtreey.xml (, ). |
| `zpNatBourbonReforms` | `DENatBourbonReforms` | `techtreey.xml` | 134064 | 9327 | Verified in vanilla techtreey.xml (, ). |
| `zpNatBourbonRoyalTax` | `DENatBourbonRoyalTax` | `techtreey.xml` | 134087 | 9328 | Verified in vanilla techtreey.xml (, ). |
| `zpNatBourbonChouannerie` | `DENatBourbonChouannerie` | `techtreey.xml` | 134108 | 9329 | Verified in vanilla techtreey.xml (, ). |
| `zpNatBourbonMaisonDuRoi` | `DENatBourbonMaisonDuRoi` | `techtreey.xml` | 134130 | 9330 | Verified in vanilla techtreey.xml (, ). |
| `zpNativeTreatyBourbon` | `DENativeTreatyBourbon` | `techtreey.xml` | 127109 | 9122 | Verified in vanilla techtreey.xml (, ). |
| `zpIndianFriendshipBourbon` | `DEIndianFriendshipBourbon` | `techtreey.xml` | 127123 | 9123 | Verified in vanilla techtreey.xml (, ). |
| `zpNativeTradeTreatyBourbon` | `DENativeTradeTreatyBourbon` | `techtreey.xml` | 127142 | 9124 | Verified in vanilla techtreey.xml (, ). |
| `zpUnknownAllianceBourbon` | `DEUnknownAllianceBourbon` | `techtreey.xml` | 152174 | 10531 | Verified in vanilla techtreey.xml (, ). |
| `zpUnknownAllianceBourbonEnabler` | `DEUnknownAllianceBourbonEnabler` | `techtreey.xml` | 152157 | 10530 | Verified in vanilla techtreey.xml (, ). Commented out at game/randmaps/zpunknown.xs:15448. |
| `zpNatBourbonRoyalMarch` | `KEEP (tech slot)` | `-` | - | - | Retained as tech slot for the small ability button (counterpart to zpNatStuartHighlandCharge). |
| `zpNatPowerRoyalMarch` | `KEEP (clone power)` | `-` | - | - | Retained power clone in powermods.xml; verified 100% identical to vanilla deNatPowerRoyalMarch except power name attribute. |
| `vanilla Royal March ability / command / tech` | `deNatPowerRoyalMarch / deNatBourbonRoyalMarch / deNatBourbonRoyalMarch` | `-` | - | - | Found in vanilla abilities.xml (), protounitcommands.xml (), and techtreey.xml (, ). Shadow removes command and tech from TradingPost. |

## 4. Deletion Candidates (Package D)

### 4.1 Clone Techs in `data/techtreemods.xml`

| Tech Name | Start Line | End Line |
|---|---|---|
| `zpSPCNativeBourbon` | 19871 | 19905 |
| `zpSPCNativeBourbonColonialize` | 19906 | 19913 |
| `zpVeteranBourbon` | 19914 | 19950 |
| `zpGuardBourbon` | 19951 | 19998 |
| `zpNatBourbonReforms` | 19999 | 20022 |
| `zpNatBourbonRoyalTax` | 20023 | 20045 |
| `zpNatBourbonChouannerie` | 20046 | 20067 |
| `zpNatBourbonMaisonDuRoi` | 20068 | 20090 |
| `zpNativeTreatyBourbon` | 20091 | 20105 |
| `zpIndianFriendshipBourbon` | 20106 | 20126 |
| `zpNativeTradeTreatyBourbon` | 20127 | 20141 |
| `zpUnknownAllianceBourbon` | 32507 | 32554 |
| `zpUnknownAllianceBourbonEnabler` | 32940 | 32956 |

### 4.2 Clone Units in `data/protomods.xml`

| Unit Name | Start Line | End Line |
|---|---|---|
| `zpNatRoyalMusketeer` | 40339 | 40506 |
| `zpNatRoyalDragoon` | 40531 | 40692 |
| `zpNatRoyalHorsemanBourbonProxy` | 40705 | 40836 |
| `zpSocketSPCBourbon` | 40837 | 40887 |

### 4.3 Subciv in `data/civmods.xml`

| Civ Name | Start Line | End Line |
|---|---|---|
| `SPCBourbon` | 526 | 558 |

### 4.4 Sound Files and Branches

- File: `sound/zpnatroyalmusketeer_snds.xml` (Musketeer soundset file)
- File: `sound/zpnatroyaldragoon_snds.xml` (Dragoon soundset file)
- Branch: `sound/zpspcregalship_snds.xml` lines 380-382 (SPCBourbon sound choice (line 380))
- Branch: `sound/zpspcregalship_snds.xml` lines 856-858 (SPCBourbon sound choice (line 856))
- Branch: `sound/zpspcostindedr_snds.xml` lines 480-482 (SPCBourbon sound choice (line 480))
- Branch: `sound/zpspcostindedr_snds.xml` lines 1027-1029 (SPCBourbon sound choice (line 1027))

### 4.5 Shared Selection References in `data/protomods.xml`

- Line 40510: `<unittype>zpNatRoyalMusketeer</unittype>` (in deNatRoyalMusketeer override)
- Line 40522: `<unittype>zpNatRoyalMusketeer</unittype>` (in deNatMercRoyalMusketeer)
- Line 40696: `<unittype>zpNatRoyalDragoon</unittype>` (in deNatRoyalDragoon override)
- Line 40702: `<unittype>zpNatRoyalDragoon</unittype>` (in deNatMercRoyalDragoon)

### 4.6 Consulate Off-Tech Lines in `data/techtreemods.xml`

- Line 879: `<effect type="TechStatus" status="unobtainable">zpConsulateRevNapoleon</effect>`
- Line 3370: `<effect type="TechStatus" status="unobtainable">zpConsulateRevNapoleon</effect>`
- Line 4178: `<effect type="TechStatus" status="unobtainable">zpConsulateRevNapoleon</effect>`
- Line 7183: `<effect type="TechStatus" status="unobtainable">zpConsulateRevNapoleon</effect>`
- Line 7875: `<effect type="TechStatus" status="unobtainable">zpConsulateRevNapoleon</effect>`
- Line 8122: `<effect type="TechStatus" status="unobtainable">zpConsulateRevNapoleon</effect>`
- Line 8527: `<effect type="TechStatus" status="unobtainable">zpConsulateRevNapoleon</effect>`
- Line 10537: `<effect type="TechStatus" status="unobtainable">zpConsulateRevNapoleon</effect>`
- Line 12064: `<effect type="TechStatus" status="unobtainable">zpConsulateRevNapoleon</effect>`
- Line 12412: `<effect type="TechStatus" status="unobtainable">zpConsulateRevNapoleon</effect>`
- Line 12901: `<effect type="TechStatus" status="unobtainable">zpConsulateRevNapoleon</effect>`
- Line 13556: `<effect type="TechStatus" status="unobtainable">zpConsulateRevNapoleon</effect>`
- Line 15583: `<effect type="TechStatus" status="unobtainable">zpConsulateRevNapoleon</effect>`
- Line 15855: `<effect type="TechStatus" status="unobtainable">zpConsulateRevNapoleon</effect>`
- Line 16075: `<effect type="TechStatus" status="unobtainable">zpConsulateRevNapoleon</effect>`
- Line 17213: `<effect type="TechStatus" status="unobtainable">zpConsulateRevNapoleon</effect>`
- Line 18646: `<effect type="TechStatus" status="unobtainable">zpConsulateRevNapoleon</effect>`
- Line 19124: `<effect type="TechStatus" status="obtainable">zpConsulateRevNapoleon</effect>`
- Line 23336: `<effect type="TechStatus" status="unobtainable">zpConsulateRevNapoleon</effect>`
- Line 24146: `<effect type="TechStatus" status="unobtainable">zpConsulateRevNapoleon</effect>`
- Line 27084: `<effect type="TechStatus" status="unobtainable">zpConsulateRevNapoleon</effect>`
- Line 27665: `<effect type="TechStatus" status="unobtainable">zpConsulateRevNapoleon</effect>`
- Line 27868: `<effect type="TechStatus" status="unobtainable">zpConsulateRevNapoleon</effect>`
- Line 28880: `<effect type="TechStatus" status="unobtainable">zpConsulateRevNapoleon</effect>`
- Line 29318: `<effect type="TechStatus" status="unobtainable">zpConsulateRevNapoleon</effect>`
- Line 31317: `<effect type="TechStatus" status="unobtainable">zpConsulateRevNapoleon</effect>`
- Line 32035: `<effect type="TechStatus" status="unobtainable">zpConsulateRevNapoleon</effect>`
- Line 33957: `<effect type="TechStatus" status="unobtainable">zpConsulateRevNapoleon</effect>`
- Line 34432: `<effect type="TechStatus" status="unobtainable">zpConsulateRevNapoleon</effect>`
- Line 35893: `<effect type="TechStatus" status="unobtainable">zpConsulateRevNapoleon</effect>`
- Line 37029: `<effect type="TechStatus" status="unobtainable">zpConsulateRevNapoleon</effect>`
- Line 37135: `<effect type="TechStatus" status="unobtainable">zpConsulateRevNapoleon</effect>`
- Line 37707: `<effect type="TechStatus" status="unobtainable">zpConsulateRevNapoleon</effect>`
- Line 38741: `<effect type="TechStatus" status="unobtainable">zpConsulateRevNapoleon</effect>`

### 4.7 Static TradingPost Lines in `data/protomods.xml`

- Line 2609: `<command page="0" column="4">zpNatBourbonRoyalMarchSmall</command>` (Package A (WP4))
- Line 2345: `<train row="0" page="0" column="3">zpNatRoyalHorsemanBourbonProxy</train>` (Package D (WP7))
- Line 2525: `<tech row="0" page="1" column="1">zpVeteranBourbon</tech>` (Package D (WP7))
- Line 2526: `<tech row="0" page="1" column="1">zpGuardBourbon</tech>n` (Package D (WP7))
- Line 2527: `<tech row="0" page="2" column="1">zpNatBourbonReforms</tech>` (Package D (WP7))
- Line 2528: `<tech row="0" page="2" column="2">zpNatBourbonRoyalTax</tech>` (Package D (WP7))
- Line 2529: `<tech row="0" page="2" column="3">zpNatBourbonChouannerie</tech>` (Package D (WP7))
- Line 2530: `<tech row="0" page="2" column="4">zpNatBourbonMaisonDuRoi</tech>` (Package D (WP7))
- Line 2531: `<tech row="0" page="0" column="20">zpNatBourbonRoyalMarch</tech>` (Package D (WP7))

## 5. Groupings Table

| Grouping | In Repo | Repo Sockets | Repo Musketeers | Repo SHA256 | Profile Matches |
|---|---|---|---|---|---|
| `EU_Natives_Block_Bourbon_1.xml` | Yes | 1 | 0 | `995f39ff7000` | Yes |
| `EU_Natives_Block_Bourbon_2.xml` | Yes | 1 | 0 | `1e742f7b781c` | Yes |
| `EU_Natives_Block_Bourbon_3.xml` | Yes | 1 | 0 | `acc2fafbfefe` | Yes |
| `EU_Verseilles_2v2.xml` | Yes | 2 | 0 | `77d12350132f` | Yes |
| `EU_Wall_NE_socketable.xml` | Yes | 0 | 6 | `41aee9e2b542` | Yes |
| `EU_Wall_SW_socketable.xml` | Yes | 0 | 6 | `9b86af4220d5` | Yes |
| `Natives_SPCBourbon_01.xml` | Yes | 1 | 0 | `a048f3cfe62f` | Yes |
| `Natives_SPCBourbon_02.xml` | Yes | 1 | 0 | `155da2bc8222` | Yes |
| `Natives_SPCBourbon_03.xml` | Yes | 1 | 0 | `20046ee79420` | Yes |
| `Verseilles v2.xml` | No | 0 | 0 | `-` | No |
| `Verseilles v3.xml` | No | 0 | 0 | `-` | No |
| `Verseilles_2v2.xml` | Yes | 2 | 0 | `27b82d4f7879` | Yes |
| `Verseilles_4v4.xml` | Yes | 4 | 0 | `005ac67ea96b` | Yes |
| `Verseilles_Mega.xml` | Yes | 2 | 0 | `da15fc9607f3` | Yes |
| `Verseilles_Mega2.xml` | Yes | 2 | 0 | `16321a9ddc6f` | Yes |
| `Verseilles_Mega3.xml` | Yes | 2 | 0 | `39db22cad704` | Yes |

## 6. Facts & Verifications

- Power clone `zpNatPowerRoyalMarch` equals vanilla `deNatPowerRoyalMarch` except its name.
- Vanilla `Bourbon` civ has no `homecityflagtexture`.
- `deNatRoyalMusketeer` override in `data/protomods.xml` carries a `Build` action.

## 7. Decisions for Owner

- **D1:** WP0: are the two broken techs Bourbon Reforms and Taille Royale?
- **D2:** Approve the Ancien Regime / Napoleonic target design from WP2.
- **D3:** The profile-only legacy groupings Verseilles v2.xml and Verseilles v3.xml: update or leave.
- **D4:** randmaps/performance_test.xs: rework like Paris, or another decision. It cannot keep deleted names.
- **D5:** Which Steam-root map copies to refresh: 00000_zpparis.xs, 00000_zpverseilles.xs, 0zpunknown.xs, other copies.
- **D6:** The flag: if vanilla Bourbon homecityflagtexture differs from SPCBourbon, whether to add civmods override.
- **D7:** Approval packages A (WP4), B (WP5), C (WP6) and D (WP7).
- **D8:** With vanilla socket, stock AI also researches Taille Royale on Paris and Versailles. Accept or not.

