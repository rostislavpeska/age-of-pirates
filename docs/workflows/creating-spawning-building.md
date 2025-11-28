# Workflow: Creating a Building with Tactic-Based Unit Spawning

**Difficulty:** Advanced  
**Time:** 30-45 minutes  
**Result:** A defensive building that automatically spawns and maintains units, switchable between different unit types via tactic commands

## Overview

This workflow creates a building that uses the **Maintain system** to automatically spawn units. The building has multiple tactics that can be switched via buttons, each spawning different unit types.

**Example Created:** TestSufiCastle
- Spawns either Sufi Settlers OR War Elephants
- Switchable via tactic buttons
- Settlers ignore build limits, Elephants respect them
- Provides aura buffs to nearby units

## Prerequisites

- Understanding of proto unit structure
- Familiarity with tactics files
- Knowledge of ID ranges (Proto: 20001+, String: 300001+, or use test range 90001+)
- Units you want to spawn must already exist in the game

## Files to Create

> **🧪 For Testing:** Create files in `playground/` folder instead of `data/` when experimenting.

```
data/                                # Production location
├── protomods.xml                    # Building definition
├── protounitcommandmods.xml         # Tactic buttons
├── tactics/
│   └── yourbuilding.tactics         # Spawn system & behaviors
├── strings/
│   └── english/
│       └── stringmods.xml           # Text strings
└── sound/
    └── yourbuilding_snds.xml        # Sound definitions
```

**For testing/playground:** Replace `data/` with `playground/data/` and use test ID ranges (Proto: 90001+, Strings: 990001+).

---

## Step 1: Plan Your Building

### Decision Checklist:

**IDs to use:**
- [ ] Building Proto ID (e.g., 90001 for testing, 2XXXX for production)
- [ ] String IDs (990001-990009 for testing, 3XXXXX+ for production)

**Building Stats:**
- [ ] HP, Cost, Build Time
- [ ] Age requirement
- [ ] Build limit (usually 1 for unique buildings)
- [ ] Attack capabilities (if defensive)

**Units to Spawn:**
- [ ] Unit 1 name (ProtoUnit name, e.g., "zpSettlerSufi")
- [ ] Unit 2 name (e.g., "zpNatWarElephantProxy")
- [ ] Spawn intervals (in seconds)
- [ ] Build limit behavior (ignore or respect?)

**Tactic Names:**
- [ ] Tactic 1 name (e.g., "SettlersMode")
- [ ] Tactic 2 name (e.g., "ElephantsMode")

---

## Step 2: Create Building Proto Unit

**File:** `data/protomods.xml` (or `scripts/new_data/protomods.xml` for testing)

### Template:

```xml
<unit id="90001" name="YourBuildingName">
  <dbid>90001</dbid>
  <displaynameid>990001</displaynameid>
  <editornameid>990002</editornameid>
  
  <!-- Physical Properties -->
  <obstructionradiusx>6.0000</obstructionradiusx>
  <obstructionradiusz>6.0000</obstructionradiusz>
  <maxvelocity>0.0000</maxvelocity>
  <movementtype>land</movementtype>
  
  <!-- Visual (use existing game assets) -->
  <animfile>buildings\asian_civs\castle_regicide\castle_zen.xml</animfile>
  <deadreplacement>BuildingRubble4x4</deadreplacement>
  <deadreplacementlifespan>15</deadreplacementlifespan>
  <impacttype>Wood</impacttype>
  <physicsinfo>blockhouse</physicsinfo>
  <placementfile>buildingsmall.xml</placementfile>
  <icon>resources\art\buildings\zp_mountain_monastery_icon.png</icon>
  <portraiticon>resources\art\buildings\zp_mountain_monastery_icon_portrait.png</portraiticon>
  
  <!-- Rollover Text -->
  <rollovertextid>990003</rollovertextid>
  <shortrollovertextid>990003</shortrollovertextid>
  
  <!-- Stats -->
  <initialhitpoints>5000.0000</initialhitpoints>
  <maxhitpoints>5000.0000</maxhitpoints>
  <los>28.0000</los>
  <projectileprotounit>Arrow</projectileprotounit>
  <unitaitype>RangedCombative</unitaitype>
  
  <!-- Construction -->
  <buildpoints>180.0000</buildpoints>
  <buildlimit>1</buildlimit>
  <bounty>250.0000</bounty>
  <buildbounty>250.0000</buildbounty>
  <cost resourcetype="Wood">800.0000</cost>
  <cost resourcetype="Gold">700.0000</cost>
  <buildingworkrate>1.0000</buildingworkrate>
  <builderlimit>10</builderlimit>
  <allowedage>2</allowedage>
  
  <!-- Garrison -->
  <maxcontained>60</maxcontained>
  <notcontain>AbstractMonk</notcontain>
  <notcontain>ExcludeFromRansom</notcontain>
  <notcontain>AbstractFishingBoat</notcontain>
  <contain>AbstractVillager</contain>
  <contain>deHomesteadWagon</contain>
  <contain>AbstractHealer</contain>
  
  <!-- Armor -->
  <armor type="Siege" value="0.0000"></armor>
  
  <!-- Unit Types (REQUIRED for buildings) -->
  <unittype>LogicalTypeValidSabotage</unittype>
  <unittype>LogicalTypeHandUnitsAutoAttack</unittype>
  <unittype>LogicalTypeBuildingsNotWalls</unittype>
  <unittype>LogicalTypeRangedUnitsAutoAttack</unittype>
  <unittype>LogicalTypeRangedUnitsAutoAttackNoVillagers</unittype>
  <unittype>LogicalTypeVillagersAttack</unittype>
  <unittype>LogicalTypeHandUnitsAttack</unittype>
  <unittype>LogicalTypeShipsAndBuildings</unittype>
  <unittype>LogicalTypeRangedUnitsAttack</unittype>
  <unittype>LogicalTypeBuildingsNotWallsOrGroves</unittype>
  <unittype>LogicalTypeMinimapFilterMilitary</unittype>
  <unittype>MilitaryBuilding</unittype>
  <unittype>BuildingClass</unittype>
  <unittype>Building</unittype>
  <unittype>LogicalTypeBuildingsNoRangedAttack</unittype>
  <unittype>HasBountyValue</unittype>
  <unittype>CountsTowardMilitaryScore</unittype>
  <unittype>ConvertsHerds</unittype>
  <unittype>AbstractFort</unittype>
  <unittype>AbstractDefensiveBuilding</unittype>
  
  <!-- Flags (CRITICAL for functionality) -->
  <flag>CollidesWithProjectiles</flag>
  <flag>StartsAtFullEfficiency</flag>
  <flag>Immoveable</flag>
  <flag>NoBloodOnDeath</flag>
  <flag>ObscuresUnits</flag>
  <flag>NonAutoFormedUnit</flag>
  <flag>Doppled</flag>
  <flag>SelectWithObstruction</flag>
  <flag>PaintTextureWhenPlacing</flag>
  <flag>FlattenGround</flag>
  <flag>HasGatherPoint</flag>
  <flag>AllowAutoGarrison</flag>
  <flag>EnterHotkeyContext</flag>
  <flag>Tracked</flag>
  <flag>DanceActionNoWorkers</flag>
  <flag>BuildingShowTactics</flag>
  <flag>DoTacticToSameUnitType</flag>
  
  <!-- Commands - MUST match your tactic command names -->
  <command page="10" column="3">SetGatherPointMilitary</command>
  <command page="10" column="7">Delete</command>
  <command page="10" column="8">CancelAllQueued</command>
  <command page="0" column="0">TacticYourFirstMode</command>
  <command page="0" column="1">TacticYourSecondMode</command>
  <command page="10" column="2">SetGatherPointEconomy</command>
  <command page="1" column="6">SetBuildingAsHomeCityGatherPointEconomic</command>
  <command page="1" column="7">SetBuildingAsHomeCityGatherPointMilitary</command>
  
  <!-- Tactics File Reference -->
  <tactics>yourbuilding.tactics</tactics>
  
  <!-- Attack Actions (Optional - if defensive building) -->
  <protoaction>
    <name>RangedAttack</name>
    <damage>70.000000</damage>
    <damagetype>Ranged</damagetype>
    <minrange>0.000000</minrange>
    <maxrange>28.000000</maxrange>
    <rof>3.000000</rof>
    <damagebonus type="AbstractCavalry">1.500000</damagebonus>
  </protoaction>
</unit>
```

### ⚠️ Critical Points:
- **Tactics file name** in `<tactics>` must match the file you'll create
- **Command names** (TacticYourFirstMode) must match protounitcommand names
- **BuildingShowTactics** flag is REQUIRED for tactic buttons to appear

---

## Step 3: Create Tactics File

**File:** `data/tactics/yourbuilding.tactics`

### Structure:

```xml
<tactics>
  <!-- ATTACK ACTIONS (if defensive building) -->
  <action>
    <name stringid="38133">RangedAttack</name>
    <type>Attack</type>
    <attackaction>1</attackaction>
    <rangedlogic>1</rangedlogic>
    <anim>RangedAttack</anim>
    <accuracy>1.0</accuracy>
    <projectile>InvisibleProjectile</projectile>
    <impacteffect>effects\impacts\gun</impacteffect>
    <rate type="Unit">1.0</rate>
    <instantballistics>1</instantballistics>
  </action>

  <!-- MAINTAIN ACTIONS (Unit Spawning) -->
  <action>
    <name stringid="990004">MaintainFirstUnit</name>
    <type>Maintain</type>
    <rate type="YourFirstUnitProtoName">1.0</rate>
    <maintaintrainpoints>30</maintaintrainpoints>
    <active>1</active>
    <persistent>1</persistent>
    <ignorebuildlimit>1</ignorebuildlimit>  <!-- OPTIONAL: Ignore unit's build limit -->
  </action>
  
  <action>
    <name stringid="990005">MaintainSecondUnit</name>
    <type>Maintain</type>
    <rate type="YourSecondUnitProtoName">1.0</rate>
    <maintaintrainpoints>45</maintaintrainpoints>
    <active>1</active>
    <persistent>1</persistent>
    <!-- NO ignorebuildlimit = respects unit's build limit -->
  </action>

  <!-- AURA BUFF ACTIONS (Optional) -->
  <action>
    <name stringid="112433">ExtraDamageInfantry</name>
    <type>AutoRangedModify</type>
    <active>0</active>
    <maxrange>34</maxrange>
    <modifyabstracttype>AbstractInfantry</modifyabstracttype>
    <persistent>1</persistent>
    <nostack>1</nostack>
    <modifytype>BaseDamage</modifytype>
    <modifymultiplier>1.30</modifymultiplier>
    <modelattachment>effects\chiefpower\chiefpower.xml</modelattachment>
    <modelattachmentbone>bonethatdoesntexist</modelattachmentbone>
  </action>

  <!-- TACTIC 1: First Unit Mode (Default) -->
  <tactic>YourFirstMode
    <protounitcommand>TacticYourFirstMode</protounitcommand>
    <active>1</active>
    <attacktype>LogicalTypeRangedUnitsAttack</attacktype>
    <autoattacktype>LogicalTypeRangedUnitsAutoAttack</autoattacktype>
    <attackresponsetype>LogicalTypeRangedUnitsAttack</attackresponsetype>
    <action priority="25">RangedAttack</action>
    <action>MaintainFirstUnit</action>
    <action>ExtraDamageInfantry</action>
    <transition>
      <tactic>YourSecondMode</tactic>
      <length>2</length>
      <exit>1</exit>
    </transition>
  </tactic>

  <!-- TACTIC 2: Second Unit Mode -->
  <tactic>YourSecondMode
    <protounitcommand>TacticYourSecondMode</protounitcommand>
    <active>1</active>
    <attacktype>LogicalTypeRangedUnitsAttack</attacktype>
    <autoattacktype>LogicalTypeRangedUnitsAutoAttack</autoattacktype>
    <attackresponsetype>LogicalTypeRangedUnitsAttack</attackresponsetype>
    <action priority="25">RangedAttack</action>
    <action>MaintainSecondUnit</action>
    <action>ExtraDamageInfantry</action>
    <transition>
      <tactic>YourFirstMode</tactic>
      <length>2</length>
      <exit>1</exit>
    </transition>
  </tactic>

</tactics>
```

### ⚠️ Critical Points:
- **Tactic names** (YourFirstMode) must match `<protounitcommand>` references
- **Only ONE Maintain action** should be active per tactic
- **`<active>1</active>`** means tactic can be switched to
- **`<transition><length>2</length>`** = 2-second switch delay
- **`<ignorebuildlimit>1</ignorebuildlimit>`** overrides unit's build limit

---

## Step 4: Create Tactic Commands

**File:** `data/protounitcommandmods.xml`

### Template:

```xml
<!-- First Mode Command -->
<protounitcommand>
  <name>TacticYourFirstMode</name>
  <icon>resources\images\icons\command\sohei_tactic_off.png</icon>
  <activeicon>resources\images\icons\command\sohei_tactic_on.png</activeicon>
  <disabledicon>resources\images\icons\command\sohei_tactic_off.png</disabledicon>
  <rollovertextid>990007</rollovertextid>
  <activerollovertextid>990007</activerollovertextid>
  <command>unitSetTactic("YourFirstMode")</command>
</protounitcommand>

<!-- Second Mode Command -->
<protounitcommand>
  <name>TacticYourSecondMode</name>
  <icon>resources\images\icons\command\soheicavalry_tactic_off.png</icon>
  <activeicon>resources\images\icons\command\soheicavalry_tactic_on.png</activeicon>
  <disabledicon>resources\images\icons\command\soheicavalry_tactic_off.png</disabledicon>
  <rollovertextid>990009</rollovertextid>
  <activerollovertextid>990009</activerollovertextid>
  <command>unitSetTactic("YourSecondMode")</command>
</protounitcommand>
```

### ⚠️ CRITICAL - Most Common Error:

**The `<command>` tag is REQUIRED!**

❌ **WRONG (won't work):**
```xml
<type>TacticChangeCommand</type>
<active>0</active>
```

✅ **CORRECT:**
```xml
<command>unitSetTactic("YourFirstMode")</command>
```

**The tactic name in `unitSetTactic()` MUST exactly match:**
1. The `<tactic>` name in the tactics file
2. It's case-sensitive!

### Icon Paths:

Use existing game icons:
- `resources\images\icons\command\sohei_tactic_off.png`
- `resources\images\icons\command\soheiarcher_tactic_off.png`
- `resources\images\icons\command\soheicavalry_tactic_off.png`
- `resources\images\icons\command\submarine_stealth.png`
- Check `data/protounitcommandmods.xml` for more options

---

## Step 5: Create String Definitions

**File:** `data/strings/english/stringmods.xml`

### Template:

```xml
<!-- Building Strings -->
<string _locid="990001">Your Building Name</string>
<string _locid="990002">ZP Your Building Name Editor</string>
<string _locid="990003">Building description with functionality explanation.</string>

<!-- Maintain Action Strings -->
<string _locid="990004">Maintain First Unit Type</string>
<string _locid="990005">Maintain Second Unit Type</string>

<!-- Tactic Command Strings -->
<string _locid="990006">First Mode Name</string>
<string _locid="990007">Switch to first mode description</string>
<string _locid="990008">Second Mode Name</string>
<string _locid="990009">Switch to second mode description</string>
```

### String ID Usage:
- 990001: Building display name
- 990002: Editor name
- 990003: Rollover/tooltip
- 990004+: Action names and command tooltips

---

## Step 6: Create Sound Definitions

**File:** `sound/yourbuilding_snds.xml`

### Template:

```xml
<protounitsounddef>
  <protounit name="YourBuildingName">
    <soundtype name="Select">
      <soundset name="UI_Building_Military">
      </soundset>
    </soundtype>
    <soundtype name="SelectSecondary">
      <soundset name="UI_Select_Building_Barracks">
      </soundset>
    </soundtype>
    <soundtype name="Death">
      <soundset name="BuildingDestruction">
      </soundset>
    </soundtype>
    <soundtype name="Creation">
      <soundset name="UI_Select_Building_Barracks">
      </soundset>
    </soundtype>
  </protounit>
</protounitsounddef>
```

### Sound Types Explained:

- **Select:** Sound when clicking the building (usually `UI_Building_Military` or `UI_Building_Economic`)
- **SelectSecondary:** Secondary click sound (building-specific: `UI_Select_Building_Barracks`, `UI_Select_Building_Stable`, `UI_Select_Building_Arsenal`, etc.)
- **Death:** Sound when building is destroyed (usually `BuildingDestruction`)
- **Creation:** Sound when building finishes construction (usually same as SelectSecondary)

### Common Building Soundsets:

**Military Buildings:**
- Barracks: `UI_Select_Building_Barracks`
- Stable: `UI_Select_Building_Stable`
- Arsenal: `UI_Select_Building_Arsenal`
- Fort: `UI_Select_Building_Fort`
- Tower: `UI_Select_Building_WatchTower`

**Religious Buildings:**
- Church: `UI_Select_Building_Church`
- Monastery: `UI_Select_Building_MountainMonastery`

**Economic Buildings:**
- Mill: `UI_Select_Building_Mill`
- Factory: `UI_Select_Building_Factory`
- Plantation: `UI_Select_Building_Plantation`

### ⚠️ Important:
- The `name` attribute in `<protounit>` must match your building's proto unit name exactly
- Sound files use existing game soundsets - you don't need to create audio files
- File naming convention: `buildingname_snds.xml` (all lowercase, matching proto name)

---

## Step 7: Testing Checklist

### In-Game Testing:

- [ ] **Building Construction**
  - [ ] Can build the building (costs correct resources)
  - [ ] Takes correct build time
  - [ ] Correct HP when finished
  - [ ] Visual model appears correctly
  - [ ] Construction complete sound plays

- [ ] **Initial Spawning**
  - [ ] Building starts in default tactic (first tactic)
  - [ ] Units spawn automatically after interval
  - [ ] Spawned units have correct type

- [ ] **Tactic Switching**
  - [ ] Both tactic buttons appear on command panel
  - [ ] Icons show correctly
  - [ ] Clicking button changes active icon
  - [ ] 2-second transition occurs
  - [ ] Different unit type begins spawning

- [ ] **Build Limits**
  - [ ] If `ignorebuildlimit`: Units spawn infinitely
  - [ ] If no flag: Spawning stops at unit's build limit
  - [ ] Spawning resumes when units die

- [ ] **Sounds**
  - [ ] Click sound plays when selecting building
  - [ ] Secondary sound plays (building-specific)
  - [ ] Destruction sound plays when destroyed

- [ ] **Combat (if defensive)**
  - [ ] Building attacks enemies
  - [ ] Range is correct
  - [ ] Damage is appropriate

- [ ] **Auras (if included)**
  - [ ] Units near building get buffs
  - [ ] Buff ranges work correctly
  - [ ] Visual effects appear (if any)

---

## Common Pitfalls & Solutions

### Issue 1: Tactic Buttons Don't Work (Most Common!)

**Symptom:** Buttons appear but clicking does nothing

**Cause:** Missing `<command>` tag in protounitcommandmods.xml

**Solution:**
```xml
<!-- Add this line: -->
<command>unitSetTactic("YourTacticName")</command>
```

### Issue 2: Tactic Buttons Don't Appear

**Causes & Solutions:**
- Missing `BuildingShowTactics` flag in proto unit → Add it
- Command names don't match → Verify proto unit `<command>` tags match protounitcommand `<name>` tags
- Commands on wrong page/column → Check `page` and `column` attributes

### Issue 3: Units Don't Spawn

**Causes & Solutions:**
- Tactic name mismatch → Verify `unitSetTactic("Name")` matches `<tactic>Name` exactly
- Maintain action not in active tactic → Check each `<tactic>` has correct `<action>Maintain...</action>`
- Wrong unit proto name → Verify `<rate type="ProtoName">` uses actual unit name
- Unit doesn't exist → Check unit exists in protomods.xml

### Issue 4: Spawning Doesn't Stop at Limit

**Cause:** `ignorebuildlimit` flag when you don't want it

**Solution:** Remove `<ignorebuildlimit>1</ignorebuildlimit>` from Maintain action

### Issue 5: Wrong Units Spawn After Switch

**Cause:** Multiple Maintain actions active simultaneously

**Solution:** Only ONE Maintain action per tactic:
```xml
<tactic>FirstMode
  <action>MaintainFirstUnit</action>  <!-- Only this one -->
</tactic>

<tactic>SecondMode
  <action>MaintainSecondUnit</action>  <!-- Only this one -->
</tactic>
```

### Issue 6: Can't Switch Back to First Tactic

**Cause:** Missing transition in second tactic

**Solution:** Both tactics need transitions to each other:
```xml
<tactic>FirstMode
  <transition>
    <tactic>SecondMode</tactic>
    <exit>1</exit>
  </transition>
</tactic>

<tactic>SecondMode
  <transition>
    <tactic>FirstMode</tactic>  <!-- MUST HAVE THIS -->
    <exit>1</exit>
  </transition>
</tactic>
```

---

## Variations & Extensions

### Add Third Tactic:

1. Add Maintain action in tactics file
2. Create third `<tactic>` with transitions to others
3. Add third protounitcommand
4. Add command to proto unit (`<command page="0" column="2">`)

### Make Units Cost Resources:

- Units spawned by Maintain actions are FREE
- Building cost pays for everything
- To make units cost resources, use Train actions instead (different system)

### Add Upgrade Tech:

1. Create tech in techtreemods.xml
2. Reference in proto unit: `<tech row="0" page="1" column="1">YourUpgradeTech</tech>`
3. Tech can modify building stats or enable third tactic

### Different Spawn Rates:

Modify `<maintaintrainpoints>`:
- Lower number = faster spawning
- 30 = every 30 seconds
- 60 = every minute

---

## File Checklist

Before testing, verify you've created:

- [ ] Proto unit in `data/protomods.xml`
- [ ] Tactics file in `data/tactics/yourbuilding.tactics`
- [ ] Commands in `data/protounitcommandmods.xml`
- [ ] Strings in `data/strings/english/stringmods.xml`
- [ ] Sound definitions in `sound/yourbuilding_snds.xml`

And verify all cross-references match:
- [ ] Tactics filename matches `<tactics>` tag in proto
- [ ] Tactic names match between tactics file and `unitSetTactic()`
- [ ] Command names match between proto and protounitcommandmods
- [ ] Unit proto names in Maintain `<rate type="">` are correct
- [ ] Proto unit name in sound file matches building name exactly

---

## Example: TestSufiCastle

See `scripts/new_data/` for a complete working example:
- `protomods.xml` - Building definition (ID 90001)
- `tactics/testsuficastle.tactics` - Spawn system
- `protounitcommandmods.xml` - Tactic buttons
- `strings/english/stringmods.xml` - All text
- `README_TestSufiCastle.md` - Complete documentation

---

## Related Workflows

- Creating a standard training building (barracks-style)
- Adding technologies to buildings
- Creating custom unit abilities
- Implementing aura effects

---

**Last Updated:** November 2024  
**Tested On:** Age of Empires III: Definitive Edition  
**Example Project:** TestSufiCastle (ID 90001)

