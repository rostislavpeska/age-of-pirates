# 🎯 Map Trigger Guide for Age of Empires III: DE

**Version:** 1.0  
**Last Updated:** November 2025

---

## 📖 Table of Contents

1. [Introduction](#introduction)
2. [Trigger Reference](#trigger-reference)
3. [Basic Trigger Structure](#basic-trigger-structure)
4. [Common Trigger Patterns](#common-trigger-patterns)
   - [Starting Tech Activation](#starting-tech-activation)
   - [Universal Consulate (Politicians)](#universal-consulate-politicians)
   - [AI Leader Selection](#ai-leader-selection)
   - [Supporting Triggers](#supporting-triggers)
5. [Complete Examples](#complete-examples)
6. [Best Practices](#best-practices)
7. [Common Mistakes](#common-mistakes)
8. [Troubleshooting](#troubleshooting)

---

## 🎬 Introduction

**Triggers** are powerful scripting tools that enable dynamic gameplay events in Age of Empires III: DE random maps. They can:

- ✅ Activate technologies for players
- ✅ Enable/disable politician options (consulates)
- ✅ Assign random leaders for AI players
- ✅ React to game conditions (player civilization, age, tech status)
- ✅ Fire sequential events
- ✅ Control trade routes and map features

Triggers execute during or after map generation and can respond to in-game conditions, making maps more dynamic and balanced.

---

## 📚 Trigger Reference

### Official Trigger Definition File

All available trigger **effects**, **conditions**, and their **parameters** are defined in:

```
📁 data/trigger/triggerdata.xml
```

**Important:** Always refer to `triggerdata.xml` when:
- Looking for available trigger effects (e.g., `ZP Set Tech Status (XS)`, `ZP Pick Consulate Tech`)
- Checking parameter names and types
- Understanding what conditions you can use
- Discovering new trigger capabilities

**Note:** The `triggerdata.xml` file is part of the base game and mod. Check both locations if you're working with custom triggers.

---

## 🏗️ Basic Trigger Structure

### Creating a Trigger

```xs
// 1. Create the trigger
rmCreateTrigger("MyTriggerName");

// 2. Switch to it (make it active for setup)
rmSwitchToTrigger(rmTriggerID("MyTriggerName"));

// 3. Add conditions (optional)
rmAddTriggerCondition("ConditionType");
rmSetTriggerConditionParamInt("ParamName", value);

// 4. Add effects (what the trigger does)
rmAddTriggerEffect("EffectType");
rmSetTriggerEffectParamInt("ParamName", value);
rmSetTriggerEffectParam("ParamName", "stringValue");

// 5. Set trigger properties
rmSetTriggerPriority(4);              // Execution priority (1-4, higher = sooner)
rmSetTriggerActive(true);             // Is it active from start?
rmSetTriggerRunImmediately(true);     // Run instantly when conditions met?
rmSetTriggerLoop(false);              // Run once or continuously?
```

### Key Trigger Commands

| Command | Purpose |
|---------|---------|
| `rmCreateTrigger(name)` | Creates a new trigger |
| `rmSwitchToTrigger(id)` | Switches context to configure a specific trigger |
| `rmAddTriggerCondition(type)` | Adds a condition that must be met |
| `rmAddTriggerEffect(type)` | Adds an action the trigger performs |
| `rmSetTriggerConditionParam*()` | Sets condition parameters |
| `rmSetTriggerEffectParam*()` | Sets effect parameters |
| `rmTriggerID(name)` | Gets trigger ID by name for referencing |
| `rmSetTriggerPriority(1-4)` | Sets execution priority |

---

## 🎨 Common Trigger Patterns

### 1️⃣ Starting Tech Activation

**Use Case:** Activate technologies for all players at game start (map setup, special rules, etc.)

**Example:** Activating Spanish Habsburgs and European Embassy

```xs
// Create trigger
rmCreateTrigger("Starting Techs");
rmSwitchToTrigger(rmTriggerID("Starting techs"));

// Activate trade route
rmAddTriggerEffect("Trade Route Set Level");
rmSetTriggerEffectParamInt("TradeRoute",1);
rmSetTriggerEffectParamInt("Level",1);

// Loop through all players
for(i=0; <= cNumberNonGaiaPlayers) {
    rmAddTriggerEffect("ZP Set Tech Status (XS)");
    rmSetTriggerEffectParamInt("PlayerID",i);
    rmSetTriggerEffectParam("TechID","cTechdeEUMapUpdateVisuals"); // Activate European Embassy for all players
    rmSetTriggerEffectParamInt("Status",2);
    
    rmAddTriggerEffect("ZP Set Tech Status (XS)");
    rmSetTriggerEffectParamInt("PlayerID",i);
    rmSetTriggerEffectParam("TechID","cTechzpSpanishHabsburgs"); // Activate Spanish Habsburgs for all players
    rmSetTriggerEffectParamInt("Status",2);
}

// Optional: Set quest variables
rmAddTriggerEffect("Quest Var Set");
rmSetTriggerEffectParam("QVName","Eruption");
rmSetTriggerEffectParamInt("Value",1);

// Configure trigger execution
rmSetTriggerPriority(4);
rmSetTriggerActive(true);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);
```

**Key Points:**
- ✅ Use **inline comments** on the `TechID` line for clarity
- ✅ Status `2` = Active/Researched
- ✅ Loop from `0` to include all players
- ✅ Run immediately at game start

---

### 2️⃣ Universal Consulate (Politicians)

**Use Case:** Enable consulate politicians for Asian civilizations and custom factions

#### A) Supporting Triggers

**Italian Settler Balance** (adjusts settlers when using consulates):

```xs
for (k=1; <= cNumberNonGaiaPlayers) {
    rmCreateTrigger("Italian Vilager Balance"+k);
    rmAddTriggerCondition("ZP Player Civilization");
    rmSetTriggerConditionParamInt("Player",k);
    rmSetTriggerConditionParam("Civilization","DEItalians");
    rmAddTriggerEffect("ZP Set Tech Status (XS)");
    rmSetTriggerEffectParamInt("PlayerID",k);
    rmSetTriggerEffectParam("TechID","cTechzpItalianSettlerBallance"); // Italian Settler Balance
    rmSetTriggerEffectParamInt("Status",2);
    rmSetTriggerPriority(2);
    rmSetTriggerActive(false);
    rmSetTriggerRunImmediately(false);
    rmSetTriggerLoop(false);
}
```

**Cheat Returner** (resets research speed after consulate selection):

```xs
for (k=1; <= cNumberNonGaiaPlayers) {
    rmCreateTrigger("Cheat Returner"+k);
    rmAddTriggerCondition("Timer ms");
    rmSetTriggerConditionParamInt("Param1",10);
    rmAddTriggerEffect("ZP Set Tech Status (XS)");
    rmSetTriggerEffectParamInt("PlayerID",k);
    rmSetTriggerEffectParam("TechID","cTechzpBigButtonResearchIncrease"); // Reset research speed
    rmSetTriggerEffectParamInt("Status",2);
    rmSetTriggerPriority(2);
    rmSetTriggerActive(false);
    rmSetTriggerRunImmediately(false);
    rmSetTriggerLoop(false);
}
```

#### B) Civilization-Specific Consulates

**Japanese Consulate:**

```xs
for (k=1; <= cNumberNonGaiaPlayers) {
    rmCreateTrigger("Activate Consulate Japan"+k);
    rmAddTriggerCondition("ZP Player Civilization");
    rmSetTriggerConditionParamInt("Player",k);
    rmSetTriggerConditionParam("Civilization","Japanese");
    rmAddTriggerCondition("ZP Tech Researching (XS)");
    rmSetTriggerConditionParam("TechID","cTechzpPickConsulateTechAvailable"); // Consulate tech available
    rmSetTriggerConditionParamInt("PlayerID",k);
    rmAddTriggerEffect("ZP Set Tech Status (XS)");
    rmSetTriggerEffectParamInt("PlayerID",k);
    rmSetTriggerEffectParam("TechID","cTechzpTurnConsulateOnJapanese"); // Turn on Japanese consulate
    rmSetTriggerEffectParamInt("Status",2);
    rmAddTriggerEffect("ZP Set Tech Status (XS)");
    rmSetTriggerEffectParamInt("PlayerID",k);
    rmSetTriggerEffectParam("TechID","cTechzpBigButtonResearchDecrease"); // Decrease research speed
    rmSetTriggerEffectParamInt("Status",2);
    rmAddTriggerEffect("ZP Pick Consulate Tech");
    rmSetTriggerEffectParamInt("Player",k);
    rmAddTriggerEffect("Fire Event");
    rmSetTriggerEffectParamInt("EventID", rmTriggerID("Cheat_Returner"+k));
    rmSetTriggerPriority(4);
    rmSetTriggerActive(false);
    rmSetTriggerRunImmediately(true);
    rmSetTriggerLoop(true);
}
```

**Chinese Consulate:**

```xs
for (k=1; <= cNumberNonGaiaPlayers) {
    rmCreateTrigger("Activate Consulate China"+k);
    rmAddTriggerCondition("ZP Player Civilization");
    rmSetTriggerConditionParamInt("Player",k);
    rmSetTriggerConditionParam("Civilization","Chinese");
    rmAddTriggerCondition("ZP Tech Researching (XS)");
    rmSetTriggerConditionParam("TechID","cTechzpPickConsulateTechAvailable"); // Consulate tech available
    rmSetTriggerConditionParamInt("PlayerID",k);
    rmAddTriggerEffect("ZP Set Tech Status (XS)");
    rmSetTriggerEffectParamInt("PlayerID",k);
    rmSetTriggerEffectParam("TechID","cTechzpTurnConsulateOnChinese"); // Turn on Chinese consulate
    rmSetTriggerEffectParamInt("Status",2);
    rmAddTriggerEffect("ZP Set Tech Status (XS)");
    rmSetTriggerEffectParamInt("PlayerID",k);
    rmSetTriggerEffectParam("TechID","cTechzpBigButtonResearchDecrease"); // Decrease research speed
    rmSetTriggerEffectParamInt("Status",2);
    rmAddTriggerEffect("ZP Pick Consulate Tech");
    rmSetTriggerEffectParamInt("Player",k);
    rmAddTriggerEffect("Fire Event");
    rmSetTriggerEffectParamInt("EventID", rmTriggerID("Cheat_Returner"+k));
    rmSetTriggerPriority(4);
    rmSetTriggerActive(false);
    rmSetTriggerRunImmediately(true);
    rmSetTriggerLoop(true);
}
```

**Indian Consulate:**

```xs
for (k=1; <= cNumberNonGaiaPlayers) {
    rmCreateTrigger("Activate Consulate India"+k);
    rmAddTriggerCondition("ZP Player Civilization");
    rmSetTriggerConditionParamInt("Player",k);
    rmSetTriggerConditionParam("Civilization","Indians");
    rmAddTriggerCondition("ZP Tech Researching (XS)");
    rmSetTriggerConditionParam("TechID","cTechzpPickConsulateTechAvailable"); // Consulate tech available
    rmSetTriggerConditionParamInt("PlayerID",k);
    rmAddTriggerEffect("ZP Set Tech Status (XS)");
    rmSetTriggerEffectParamInt("PlayerID",k);
    rmSetTriggerEffectParam("TechID","cTechzpTurnConsulateOnIndian"); // Turn on Indian consulate
    rmSetTriggerEffectParamInt("Status",2);
    rmAddTriggerEffect("ZP Set Tech Status (XS)");
    rmSetTriggerEffectParamInt("PlayerID",k);
    rmSetTriggerEffectParam("TechID","cTechzpBigButtonResearchDecrease"); // Decrease research speed
    rmSetTriggerEffectParamInt("Status",2);
    rmAddTriggerEffect("ZP Pick Consulate Tech");
    rmSetTriggerEffectParamInt("Player",k);
    rmAddTriggerEffect("Fire Event");
    rmSetTriggerEffectParamInt("EventID", rmTriggerID("Cheat_Returner"+k));
    rmSetTriggerPriority(4);
    rmSetTriggerActive(false);
    rmSetTriggerRunImmediately(true);
    rmSetTriggerLoop(true);
}
```

#### C) Pirate Consulate (Universal)

**Mediterranean Pirate Consulate:**

```xs
for (k=1; <= cNumberNonGaiaPlayers) {
    rmCreateTrigger("Activate Tortuga"+k);
    rmAddTriggerCondition("ZP Tech Researching (XS)");
    rmSetTriggerConditionParam("TechID","cTechzpTheBlackFlag"); // Pirates consulate tech
    rmSetTriggerConditionParamInt("PlayerID",k);
    rmAddTriggerEffect("ZP Set Tech Status (XS)");
    rmSetTriggerEffectParamInt("PlayerID",k);
    rmSetTriggerEffectParam("TechID","cTechzpTurnConsulateOffPiratesMedi"); // Turn on Mediterranean Pirate consulate
    rmSetTriggerEffectParamInt("Status",2);
    rmAddTriggerEffect("ZP Set Tech Status (XS)");
    rmSetTriggerEffectParamInt("PlayerID",k);
    rmSetTriggerEffectParam("TechID","cTechzpBigButtonResearchDecrease"); // Decrease research speed
    rmSetTriggerEffectParamInt("Status",2);
    rmAddTriggerEffect("ZP Pick Consulate Tech");
    rmSetTriggerEffectParamInt("Player",k);
    rmAddTriggerEffect("Fire Event");
    rmSetTriggerEffectParamInt("EventID", rmTriggerID("Italian_Vilager_Balance"+k));
    rmAddTriggerEffect("Fire Event");
    rmSetTriggerEffectParamInt("EventID", rmTriggerID("Italian_Gondola_Balance"+k));
    rmAddTriggerEffect("Fire Event");
    rmSetTriggerEffectParamInt("EventID", rmTriggerID("Cheat_Returner"+k));
    rmSetTriggerPriority(4);
    rmSetTriggerActive(false);
    rmSetTriggerRunImmediately(true);
    rmSetTriggerLoop(true);
}
```

**Regional Variants:**
- **Baltic:** `cTechzpTurnConsulateOffPiratesBaltic`
- **Mediterranean:** `cTechzpTurnConsulateOffPiratesMedi`
- **Australia/Pacific:** `cTechzpTurnConsulateOffPiratesAustralia`
- **Default:** `cTechzpTurnConsulateOffPirates`

#### D) Human Check (Activation)

**Activates all consulate triggers for human players:**

```xs
for(k=1; <= cNumberNonGaiaPlayers) {
    rmCreateTrigger("Human Check Plr"+k);
    rmAddTriggerCondition("ZP PLAYER Human");
    rmSetTriggerConditionParamInt("Player",k);
    rmSetTriggerConditionParam("MyBool", "true");
    rmAddTriggerEffect("ZP Set Tech Status (XS)");
    rmSetTriggerEffectParamInt("PlayerID",k);
    rmSetTriggerEffectParam("TechID","cTechzpIsPirateMap"); // Mark as pirate map
    rmSetTriggerEffectParamInt("Status",2);
    rmAddTriggerEffect("Fire Event");
    rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Consulate_Japan"+k));
    rmAddTriggerEffect("Fire Event");
    rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Consulate_China"+k));
    rmAddTriggerEffect("Fire Event");
    rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Consulate_India"+k));
    rmAddTriggerEffect("Fire Event");
    rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Tortuga"+k));
    rmSetTriggerPriority(4);
    rmSetTriggerActive(true);
    rmSetTriggerRunImmediately(true);
    rmSetTriggerLoop(false);
}
```

**Key Points:**
- ✅ Only human players can select politicians manually
- ✅ Fires all consulate activation triggers
- ✅ Runs immediately at game start
- ✅ One-time execution (loop = false)

---

### 3️⃣ AI Leader Selection

**Use Case:** Randomly assign leaders/captains to AI players at game start

**Example: Mediterranean Pirate Captains**

```xs
for (k=1; <= cNumberNonGaiaPlayers) {

    rmCreateTrigger("ZP Pick Pirate Captain"+k);
    rmAddTriggerCondition("ZP PLAYER Human");
    rmSetTriggerConditionParamInt("Player",k);
    rmSetTriggerConditionParam("MyBool", "false"); // Only for AI players
    rmAddTriggerCondition("Tech Status Equals");
    rmSetTriggerConditionParamInt("PlayerID",k);
    rmSetTriggerConditionParamInt("TechID",586); // Age 1 tech
    rmSetTriggerConditionParamInt("Status",2);

    int pirateCaptain=-1;
    pirateCaptain = rmRandInt(1,3);

    if (pirateCaptain==1)
    {
        rmAddTriggerEffect("ZP Set Tech Status (XS)");
        rmSetTriggerEffectParamInt("PlayerID",k);
        rmSetTriggerEffectParam("TechID","cTechzpConsulatePiratesBlackbeard"); // Blackbeard (Mediterranean)
        rmSetTriggerEffectParamInt("Status",2);
    }
    if (pirateCaptain==2)
    {
        rmAddTriggerEffect("ZP Set Tech Status (XS)");
        rmSetTriggerEffectParamInt("PlayerID",k);
        rmSetTriggerEffectParam("TechID","cTechzpConsulatePiratesBlackCaesar"); // Black Caesar (Mediterranean)
        rmSetTriggerEffectParamInt("Status",2);
    }
    if (pirateCaptain==3)
    {
        rmAddTriggerEffect("ZP Set Tech Status (XS)");
        rmSetTriggerEffectParamInt("PlayerID",k);
        rmSetTriggerEffectParam("TechID","cTechzpConsulatePiratesBarbarossa"); // Barbarossa (Mediterranean)
        rmSetTriggerEffectParamInt("Status",2);
    }
    rmSetTriggerPriority(4);
    rmSetTriggerActive(true);
    rmSetTriggerRunImmediately(true);
    rmSetTriggerLoop(false);
}
```

**Key Points:**
- ✅ Condition: `MyBool = "false"` → Only for **AI players**
- ✅ Triggers when player reaches Age 1 (TechID 586)
- ✅ Uses `rmRandInt(1,3)` for random selection
- ✅ Variable `pirateCaptain` declared **inside trigger loop** (XS allows this)
- ✅ Each captain gets assigned via separate `if` blocks

**Common AI Leader Categories:**
- **Pirate Captains:** Blackbeard, Grace O'Malley, Black Caesar, Barbarossa, Beauregard
- **Hansa Leaders:** Western, Central, East
- **Scientists:** Nemo, Valentine, Khora
- **Revolution Leaders:** Various per faction

---

### 4️⃣ Supporting Triggers

#### Timer-Based Triggers

**Example: Delayed Event**

```xs
rmCreateTrigger("Delayed_Event");
rmAddTriggerCondition("Timer");
rmSetTriggerConditionParamInt("Param1", 120); // 120 seconds
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Next_Trigger"));
rmSetTriggerPriority(4);
rmSetTriggerActive(true);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);
```

#### Countdown Timer

```xs
rmAddTriggerEffect("Counter:Add Timer");
rmSetTriggerEffectParam("Name","MyCounter");
rmSetTriggerEffectParamInt("Start", 120);
rmSetTriggerEffectParamInt("Stop", 0);
rmSetTriggerEffectParam("Msg", "Event starts in");
rmSetTriggerEffectParamInt("Event", rmTriggerID("Target_Trigger"));
```

---

## 📋 Complete Examples

### Example 1: Complete Starting Techs Setup

```xs
// Variables for socket references (if needed)
int flag1 = rmGetUnitPlaced(pirateFlagID1, 0);
int flag2 = rmGetUnitPlaced(pirateFlagID2, 0);
string pirate1Socket = ""+(flag1-1);
string pirate2Socket = ""+(flag2-1);

// Create starting techs trigger
rmCreateTrigger("Starting Techs");
rmSwitchToTrigger(rmTriggerID("Starting techs"));

// Activate trade route
rmAddTriggerEffect("Trade Route Set Level");
rmSetTriggerEffectParamInt("TradeRoute",1);
rmSetTriggerEffectParamInt("Level",1);

// Activate techs for all players
for(i=0; <= cNumberNonGaiaPlayers) {
    rmAddTriggerEffect("ZP Set Tech Status (XS)");
    rmSetTriggerEffectParamInt("PlayerID",i);
    rmSetTriggerEffectParam("TechID","cTechdeEUMapUpdateVisuals"); // Activate European Embassy for all players
    rmSetTriggerEffectParamInt("Status",2);
    
    rmAddTriggerEffect("ZP Set Tech Status (XS)");
    rmSetTriggerEffectParamInt("PlayerID",i);
    rmSetTriggerEffectParam("TechID","cTechzpSpanishHabsburgs"); // Activate Spanish Habsburgs for all players
    rmSetTriggerEffectParamInt("Status",2);
}

// Set quest variables
rmAddTriggerEffect("Quest Var Set");
rmSetTriggerEffectParam("QVName","Eruption");
rmSetTriggerEffectParamInt("Value",1);

// Configure execution
rmSetTriggerPriority(4);
rmSetTriggerActive(true);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);
```

### Example 2: Complete Politicians Setup (Mediterranean Map)

```xs
// ******************* Politicians *******************

// Italian Vilager Balance
for (k=1; <= cNumberNonGaiaPlayers) {
    rmCreateTrigger("Italian Vilager Balance"+k);
    rmAddTriggerCondition("ZP Player Civilization");
    rmSetTriggerConditionParamInt("Player",k);
    rmSetTriggerConditionParam("Civilization","DEItalians");
    rmAddTriggerEffect("ZP Set Tech Status (XS)");
    rmSetTriggerEffectParamInt("PlayerID",k);
    rmSetTriggerEffectParam("TechID","cTechzpItalianSettlerBallance"); // Italian Settler Balance
    rmSetTriggerEffectParamInt("Status",2);
    rmSetTriggerPriority(2);
    rmSetTriggerActive(false);
    rmSetTriggerRunImmediately(false);
    rmSetTriggerLoop(false);
}

// Cheat Returner (research speed reset)
for (k=1; <= cNumberNonGaiaPlayers) {
    rmCreateTrigger("Cheat Returner"+k);
    rmAddTriggerCondition("Timer ms");
    rmSetTriggerConditionParamInt("Param1",10);
    rmAddTriggerEffect("ZP Set Tech Status (XS)");
    rmSetTriggerEffectParamInt("PlayerID",k);
    rmSetTriggerEffectParam("TechID","cTechzpBigButtonResearchIncrease"); // Reset research speed
    rmSetTriggerEffectParamInt("Status",2);
    rmSetTriggerPriority(2);
    rmSetTriggerActive(false);
    rmSetTriggerRunImmediately(false);
    rmSetTriggerLoop(false);
}

// Japanese Consulate
for (k=1; <= cNumberNonGaiaPlayers) {
    rmCreateTrigger("Activate Consulate Japan"+k);
    rmAddTriggerCondition("ZP Player Civilization");
    rmSetTriggerConditionParamInt("Player",k);
    rmSetTriggerConditionParam("Civilization","Japanese");
    rmAddTriggerCondition("ZP Tech Researching (XS)");
    rmSetTriggerConditionParam("TechID","cTechzpPickConsulateTechAvailable");
    rmSetTriggerConditionParamInt("PlayerID",k);
    rmAddTriggerEffect("ZP Set Tech Status (XS)");
    rmSetTriggerEffectParamInt("PlayerID",k);
    rmSetTriggerEffectParam("TechID","cTechzpTurnConsulateOnJapanese");
    rmSetTriggerEffectParamInt("Status",2);
    rmAddTriggerEffect("ZP Set Tech Status (XS)");
    rmSetTriggerEffectParamInt("PlayerID",k);
    rmSetTriggerEffectParam("TechID","cTechzpBigButtonResearchDecrease");
    rmSetTriggerEffectParamInt("Status",2);
    rmAddTriggerEffect("ZP Pick Consulate Tech");
    rmSetTriggerEffectParamInt("Player",k);
    rmAddTriggerEffect("Fire Event");
    rmSetTriggerEffectParamInt("EventID", rmTriggerID("Cheat_Returner"+k));
    rmSetTriggerPriority(4);
    rmSetTriggerActive(false);
    rmSetTriggerRunImmediately(true);
    rmSetTriggerLoop(true);
}

// Chinese Consulate (similar pattern)
// Indian Consulate (similar pattern)

// Mediterranean Pirates
for (k=1; <= cNumberNonGaiaPlayers) {
    rmCreateTrigger("Activate Tortuga"+k);
    rmAddTriggerCondition("ZP Tech Researching (XS)");
    rmSetTriggerConditionParam("TechID","cTechzpTheBlackFlag");
    rmSetTriggerConditionParamInt("PlayerID",k);
    rmAddTriggerEffect("ZP Set Tech Status (XS)");
    rmSetTriggerEffectParamInt("PlayerID",k);
    rmSetTriggerEffectParam("TechID","cTechzpTurnConsulateOffPiratesMedi");
    rmSetTriggerEffectParamInt("Status",2);
    rmAddTriggerEffect("ZP Set Tech Status (XS)");
    rmSetTriggerEffectParamInt("PlayerID",k);
    rmSetTriggerEffectParam("TechID","cTechzpBigButtonResearchDecrease");
    rmSetTriggerEffectParamInt("Status",2);
    rmAddTriggerEffect("ZP Pick Consulate Tech");
    rmSetTriggerEffectParamInt("Player",k);
    rmAddTriggerEffect("Fire Event");
    rmSetTriggerEffectParamInt("EventID", rmTriggerID("Italian_Vilager_Balance"+k));
    rmAddTriggerEffect("Fire Event");
    rmSetTriggerEffectParamInt("EventID", rmTriggerID("Italian_Gondola_Balance"+k));
    rmAddTriggerEffect("Fire Event");
    rmSetTriggerEffectParamInt("EventID", rmTriggerID("Cheat_Returner"+k));
    rmSetTriggerPriority(4);
    rmSetTriggerActive(false);
    rmSetTriggerRunImmediately(true);
    rmSetTriggerLoop(true);
}

// Human player check (activates all consulate triggers)
for(k=1; <= cNumberNonGaiaPlayers) {
    rmCreateTrigger("Human Check Plr"+k);
    rmAddTriggerCondition("ZP PLAYER Human");
    rmSetTriggerConditionParamInt("Player",k);
    rmSetTriggerConditionParam("MyBool", "true");
    rmAddTriggerEffect("ZP Set Tech Status (XS)");
    rmSetTriggerEffectParamInt("PlayerID",k);
    rmSetTriggerEffectParam("TechID","cTechzpIsPirateMap");
    rmSetTriggerEffectParamInt("Status",2);
    rmAddTriggerEffect("Fire Event");
    rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Consulate_Japan"+k));
    rmAddTriggerEffect("Fire Event");
    rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Consulate_China"+k));
    rmAddTriggerEffect("Fire Event");
    rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Consulate_India"+k));
    rmAddTriggerEffect("Fire Event");
    rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Tortuga"+k));
    rmSetTriggerPriority(4);
    rmSetTriggerActive(true);
    rmSetTriggerRunImmediately(true);
    rmSetTriggerLoop(false);
}

// AI Pirate Captain Selection
for (k=1; <= cNumberNonGaiaPlayers) {
    rmCreateTrigger("ZP Pick Pirate Captain"+k);
    rmAddTriggerCondition("ZP PLAYER Human");
    rmSetTriggerConditionParamInt("Player",k);
    rmSetTriggerConditionParam("MyBool", "false");
    rmAddTriggerCondition("Tech Status Equals");
    rmSetTriggerConditionParamInt("PlayerID",k);
    rmSetTriggerConditionParamInt("TechID",586);
    rmSetTriggerConditionParamInt("Status",2);

    int pirateCaptain=-1;
    pirateCaptain = rmRandInt(1,3);

    if (pirateCaptain==1) {
        rmAddTriggerEffect("ZP Set Tech Status (XS)");
        rmSetTriggerEffectParamInt("PlayerID",k);
        rmSetTriggerEffectParam("TechID","cTechzpConsulatePiratesBlackbeard");
        rmSetTriggerEffectParamInt("Status",2);
    }
    if (pirateCaptain==2) {
        rmAddTriggerEffect("ZP Set Tech Status (XS)");
        rmSetTriggerEffectParamInt("PlayerID",k);
        rmSetTriggerEffectParam("TechID","cTechzpConsulatePiratesBlackCaesar");
        rmSetTriggerEffectParamInt("Status",2);
    }
    if (pirateCaptain==3) {
        rmAddTriggerEffect("ZP Set Tech Status (XS)");
        rmSetTriggerEffectParamInt("PlayerID",k);
        rmSetTriggerEffectParam("TechID","cTechzpConsulatePiratesBarbarossa");
        rmSetTriggerEffectParamInt("Status",2);
    }
    rmSetTriggerPriority(4);
    rmSetTriggerActive(true);
    rmSetTriggerRunImmediately(true);
    rmSetTriggerLoop(false);
}
```

---

## 🚢 Pirate Ship Training & Trading Post Activation

**Use Case:** Allow players to train unique pirate ships and privateers when they control pirate settlements

### Pattern Overview

This advanced trigger system consists of three layers:
1. **Privateer Training** - Basic pirate ships trainable by all captains
2. **Unique Ship Training** - Captain-specific legendary ships (Mediterranean variant)
3. **Trading Post Activation** - Enables ship training when player builds TP at pirate settlement

### Implementation: Balearic Islands (Complete Example)

#### Socket Variables Setup

```xs
// Variables (at start of trigger section)
int flag1 = rmGetUnitPlaced(piratewaterflagID1, 0);
int flag2 = rmGetUnitPlaced(piratewaterflagID2, 0);

string pirate1Socket = ""+(flag1-1);
string pirate2Socket = ""+(flag2-1);
```

#### Layer 1: Privateer Training

```xs
// Privateer training (always created for all players)
for (k=1; <= cNumberNonGaiaPlayers) {
    rmCreateTrigger("TrainPrivateer1ON Plr"+k);
    rmCreateTrigger("TrainPrivateer1OFF Plr"+k);
    rmCreateTrigger("TrainPrivateer1TIME Plr"+k);

    rmSwitchToTrigger(rmTriggerID("TrainPrivateer1ON_Plr"+k));
    rmAddTriggerCondition("Units in Area");
    rmSetTriggerConditionParam("DstObject",pirate1Socket);
    rmSetTriggerConditionParamInt("Player",k);
    rmSetTriggerConditionParam("UnitType","zpPrivateerProxy");
    rmSetTriggerConditionParamInt("Dist",35);
    rmSetTriggerConditionParam("Op",">=");
    rmSetTriggerConditionParamInt("Count",1);
    rmAddTriggerEffect("ZP Set Tech Status (XS)");
    rmSetTriggerEffectParamInt("PlayerID",k);
    rmSetTriggerEffectParam("TechID","cTechzpTrainPrivateer1"); // Enable Privateer training
    rmSetTriggerEffectParamInt("Status",2);
    rmAddTriggerEffect("Fire Event");
    rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainPrivateer1OFF_Plr"+k));
    rmAddTriggerEffect("Fire Event");
    rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainPrivateer1TIME_Plr"+k));
    rmSetTriggerPriority(4);
    rmSetTriggerActive(false);
    rmSetTriggerRunImmediately(true);
    rmSetTriggerLoop(false);

    rmSwitchToTrigger(rmTriggerID("TrainPrivateer1OFF_Plr"+k));
    rmAddTriggerCondition("Timer ms");
    rmSetTriggerConditionParamFloat("Param1",1200); // 1.2 second cooldown
    rmAddTriggerEffect("Fire Event");
    rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainPrivateer1ON_Plr"+k));
    rmSetTriggerPriority(4);
    rmSetTriggerActive(false);
    rmSetTriggerRunImmediately(true);
    rmSetTriggerLoop(false);

    rmSwitchToTrigger(rmTriggerID("TrainPrivateer1TIME_Plr"+k));
    rmAddTriggerCondition("Timer ms");
    rmSetTriggerConditionParamFloat("Param1",200); // 200ms training window
    rmAddTriggerEffect("ZP Set Tech Status (XS)");
    rmSetTriggerEffectParamInt("PlayerID",k);
    rmSetTriggerEffectParam("TechID","cTechzpPrivateerBuildLimitReduceShadow"); // Reduce build limit
    rmSetTriggerEffectParamInt("Status",2);
    rmAddTriggerEffect("ZP Set Tech Status (XS)");
    rmSetTriggerEffectParamInt("PlayerID",k);
    rmSetTriggerEffectParam("TechID","cTechzpTrainPrivateer1"); // Disable training
    rmSetTriggerEffectParamInt("Status",0);
    rmSetTriggerPriority(4);
    rmSetTriggerActive(false);
    rmSetTriggerRunImmediately(true);
    rmSetTriggerLoop(false);
}

// Privateer 2 training (conditional - only if >3 players)
if (cNumberNonGaiaPlayers > 3) {
    for (k=1; <= cNumberNonGaiaPlayers) {
        rmCreateTrigger("TrainPrivateer2ON Plr"+k);
        rmCreateTrigger("TrainPrivateer2OFF Plr"+k);
        rmCreateTrigger("TrainPrivateer2TIME Plr"+k);
        // ... (same pattern as Privateer 1, using pirate2Socket)
    }
}
```

#### Layer 2: Unique Ship Training (Mediterranean)

**Three Captain Ships:**
- **Blackbeard** → Queen Anne (`zpSPCQueenAnneProxy` → `cTechzpTrainQueenAnne1/2`)
- **Barbarossa** → Sultana (`zpSPCPirateGalleassProxy` → `cTechzpTrainSultana1/2`)
- **Black Caesar** → Neptune (`zpSPCNeptuneGalleyProxy` → `cTechzpTrainNeptune1/2`)

```xs
// Unique ship Training (Mediterranean)
for (k=1; <= cNumberNonGaiaPlayers) {
    rmCreateTrigger("UniqueShip1TIMEPlr"+k);

    rmCreateTrigger("BlackbTrain1ONPlr"+k);
    rmCreateTrigger("BlackbTrain1OFFPlr"+k);

    rmCreateTrigger("BarbarossaTrain1ONPlr"+k);
    rmCreateTrigger("BarbarossaTrain1OFFPlr"+k);

    rmCreateTrigger("BlackCaesarTrain1ONPlr"+k);
    rmCreateTrigger("BlackCaesarTrain1OFFPlr"+k);

    // Conditional for second settlement (only if >3 players)
    if (cNumberNonGaiaPlayers > 3) {
        rmCreateTrigger("UniqueShip2TIMEPlr"+k);
        rmCreateTrigger("BlackbTrain2ONPlr"+k);
        rmCreateTrigger("BlackbTrain2OFFPlr"+k);
        rmCreateTrigger("BarbarossaTrain2ONPlr"+k);
        rmCreateTrigger("BarbarossaTrain2OFFPlr"+k);
        rmCreateTrigger("BlackCaesarTrain2ONPlr"+k);
        rmCreateTrigger("BlackCaesarTrain2OFFPlr"+k);
        
        // Build limit reducer for settlement 2
        rmSwitchToTrigger(rmTriggerID("UniqueShip2TIMEPlr"+k));
        rmAddTriggerCondition("Timer ms");
        rmSetTriggerConditionParamFloat("Param1",200);
        rmAddTriggerEffect("ZP Set Tech Status (XS)");
        rmSetTriggerEffectParamInt("PlayerID",k);
        rmSetTriggerEffectParam("TechID","cTechzpReducePirateShipsBuildLimit"); // Reduce build limit
        rmSetTriggerEffectParamInt("Status",2);
        rmSetTriggerPriority(4);
        rmSetTriggerActive(false);
        rmSetTriggerRunImmediately(true);
        rmSetTriggerLoop(false);

        // Blackbeard (Queen Anne) - Settlement 2
        rmSwitchToTrigger(rmTriggerID("BlackbTrain2ONPlr"+k));
        rmAddTriggerCondition("Units in Area");
        rmSetTriggerConditionParam("DstObject",pirate2Socket);
        rmSetTriggerConditionParamInt("Player",k);
        rmSetTriggerConditionParam("UnitType","zpSPCQueenAnneProxy");
        rmSetTriggerConditionParamInt("Dist",35);
        rmSetTriggerConditionParam("Op",">=");
        rmSetTriggerConditionParamInt("Count",1);
        rmAddTriggerEffect("ZP Set Tech Status (XS)");
        rmSetTriggerEffectParamInt("PlayerID",k);
        rmSetTriggerEffectParam("TechID","cTechzpTrainQueenAnne2"); // Train Queen Anne at settlement 2
        rmSetTriggerEffectParamInt("Status",2);
        rmAddTriggerEffect("Fire Event");
        rmSetTriggerEffectParamInt("EventID", rmTriggerID("UniqueShip2TIMEPlr"+k));
        rmAddTriggerEffect("Fire Event");
        rmSetTriggerEffectParamInt("EventID", rmTriggerID("BlackbTrain2OFFPlr"+k));
        rmSetTriggerPriority(4);
        rmSetTriggerActive(false);
        rmSetTriggerRunImmediately(true);
        rmSetTriggerLoop(false);

        rmSwitchToTrigger(rmTriggerID("BlackbTrain2OFFPlr"+k));
        rmAddTriggerCondition("Timer ms");
        rmSetTriggerConditionParamInt("Param1",1200);
        rmAddTriggerEffect("Fire Event");
        rmSetTriggerEffectParamInt("EventID", rmTriggerID("BlackbTrain2ONPlr"+k));
        rmSetTriggerPriority(4);
        rmSetTriggerActive(false);
        rmSetTriggerRunImmediately(true);
        rmSetTriggerLoop(false);

        // ... (similar for Barbarossa and Black Caesar settlement 2)
    }

    // Build limit reducer for settlement 1
    rmSwitchToTrigger(rmTriggerID("UniqueShip1TIMEPlr"+k));
    rmAddTriggerCondition("Timer ms");
    rmSetTriggerConditionParamFloat("Param1",200);
    rmAddTriggerEffect("ZP Set Tech Status (XS)");
    rmSetTriggerEffectParamInt("PlayerID",k);
    rmSetTriggerEffectParam("TechID","cTechzpReducePirateShipsBuildLimit"); // Reduce build limit
    rmSetTriggerEffectParamInt("Status",2);
    rmSetTriggerPriority(4);
    rmSetTriggerActive(false);
    rmSetTriggerRunImmediately(true);
    rmSetTriggerLoop(false);

    // Blackbeard (Queen Anne) - Settlement 1
    rmSwitchToTrigger(rmTriggerID("BlackbTrain1ONPlr"+k));
    rmAddTriggerCondition("Units in Area");
    rmSetTriggerConditionParam("DstObject",pirate1Socket);
    rmSetTriggerConditionParamInt("Player",k);
    rmSetTriggerConditionParam("UnitType","zpSPCQueenAnneProxy");
    rmSetTriggerConditionParamInt("Dist",35);
    rmSetTriggerConditionParam("Op",">=");
    rmSetTriggerConditionParamInt("Count",1);
    rmAddTriggerEffect("ZP Set Tech Status (XS)");
    rmSetTriggerEffectParamInt("PlayerID",k);
    rmSetTriggerEffectParam("TechID","cTechzpTrainQueenAnne1"); // Train Queen Anne at settlement 1
    rmSetTriggerEffectParamInt("Status",2);
    rmAddTriggerEffect("Fire Event");
    rmSetTriggerEffectParamInt("EventID", rmTriggerID("UniqueShip1TIMEPlr"+k));
    rmAddTriggerEffect("Fire Event");
    rmSetTriggerEffectParamInt("EventID", rmTriggerID("BlackbTrain1OFFPlr"+k));
    rmSetTriggerPriority(4);
    rmSetTriggerActive(false);
    rmSetTriggerRunImmediately(true);
    rmSetTriggerLoop(false);

    rmSwitchToTrigger(rmTriggerID("BlackbTrain1OFFPlr"+k));
    rmAddTriggerCondition("Timer ms");
    rmSetTriggerConditionParamInt("Param1",1200);
    rmAddTriggerEffect("Fire Event");
    rmSetTriggerEffectParamInt("EventID", rmTriggerID("BlackbTrain1ONPlr"+k));
    rmSetTriggerPriority(4);
    rmSetTriggerActive(false);
    rmSetTriggerRunImmediately(true);
    rmSetTriggerLoop(false);

    // Barbarossa (Sultana) - Settlement 1
    rmSwitchToTrigger(rmTriggerID("BarbarossaTrain1ONPlr"+k));
    rmAddTriggerCondition("Units in Area");
    rmSetTriggerConditionParam("DstObject",pirate1Socket);
    rmSetTriggerConditionParamInt("Player",k);
    rmSetTriggerConditionParam("UnitType","zpSPCPirateGalleassProxy");
    rmSetTriggerConditionParamInt("Dist",35);
    rmSetTriggerConditionParam("Op",">=");
    rmSetTriggerConditionParamInt("Count",1);
    rmAddTriggerEffect("ZP Set Tech Status (XS)");
    rmSetTriggerEffectParamInt("PlayerID",k);
    rmSetTriggerEffectParam("TechID","cTechzpTrainSultana1"); // Train Sultana (Barbarossa)
    rmSetTriggerEffectParamInt("Status",2);
    rmAddTriggerEffect("Fire Event");
    rmSetTriggerEffectParamInt("EventID", rmTriggerID("UniqueShip1TIMEPlr"+k));
    rmAddTriggerEffect("Fire Event");
    rmSetTriggerEffectParamInt("EventID", rmTriggerID("BarbarossaTrain1OFFPlr"+k));
    rmSetTriggerPriority(4);
    rmSetTriggerActive(false);
    rmSetTriggerRunImmediately(true);
    rmSetTriggerLoop(false);

    rmSwitchToTrigger(rmTriggerID("BarbarossaTrain1OFFPlr"+k));
    rmAddTriggerCondition("Timer ms");
    rmSetTriggerConditionParamInt("Param1",1200);
    rmAddTriggerEffect("Fire Event");
    rmSetTriggerEffectParamInt("EventID", rmTriggerID("BarbarossaTrain1ONPlr"+k));
    rmSetTriggerPriority(4);
    rmSetTriggerActive(false);
    rmSetTriggerRunImmediately(true);
    rmSetTriggerLoop(false);

    // Black Caesar (Neptune) - Settlement 1
    rmSwitchToTrigger(rmTriggerID("BlackCaesarTrain1ONPlr"+k));
    rmAddTriggerCondition("Units in Area");
    rmSetTriggerConditionParam("DstObject",pirate1Socket);
    rmSetTriggerConditionParamInt("Player",k);
    rmSetTriggerConditionParam("UnitType","zpSPCNeptuneGalleyProxy");
    rmSetTriggerConditionParamInt("Dist",35);
    rmSetTriggerConditionParam("Op",">=");
    rmSetTriggerConditionParamInt("Count",1);
    rmAddTriggerEffect("ZP Set Tech Status (XS)");
    rmSetTriggerEffectParamInt("PlayerID",k);
    rmSetTriggerEffectParam("TechID","cTechzpTrainNeptune1"); // Train Neptune (Black Caesar)
    rmSetTriggerEffectParamInt("Status",2);
    rmAddTriggerEffect("Fire Event");
    rmSetTriggerEffectParamInt("EventID", rmTriggerID("UniqueShip1TIMEPlr"+k));
    rmAddTriggerEffect("Fire Event");
    rmSetTriggerEffectParamInt("EventID", rmTriggerID("BlackCaesarTrain1OFFPlr"+k));
    rmSetTriggerPriority(4);
    rmSetTriggerActive(false);
    rmSetTriggerRunImmediately(true);
    rmSetTriggerLoop(false);

    rmSwitchToTrigger(rmTriggerID("BlackCaesarTrain1OFFPlr"+k));
    rmAddTriggerCondition("Timer ms");
    rmSetTriggerConditionParamInt("Param1",1200);
    rmAddTriggerEffect("Fire Event");
    rmSetTriggerEffectParamInt("EventID", rmTriggerID("BlackCaesarTrain1ONPlr"+k));
    rmSetTriggerPriority(4);
    rmSetTriggerActive(false);
    rmSetTriggerRunImmediately(true);
    rmSetTriggerLoop(false);
}
```

#### Layer 3: Trading Post Activation

```xs
// Pirate trading post activation (settlement 1 - always)
for (k=1; <= cNumberNonGaiaPlayers) {
    rmCreateTrigger("Pirates1on Player"+k);
    rmCreateTrigger("Pirates1off Player"+k);

    // ON: Player builds TP at pirate settlement
    rmSwitchToTrigger(rmTriggerID("Pirates1on_Player"+k));
    rmAddTriggerCondition("Units in Area");
    rmSetTriggerConditionParam("DstObject",pirate1Socket);
    rmSetTriggerConditionParamInt("Player",k);
    rmSetTriggerConditionParamInt("Dist",35);
    rmSetTriggerConditionParam("UnitType","TradingPost");
    rmSetTriggerConditionParam("Op",">=");
    rmSetTriggerConditionParamFloat("Count",1);
    rmAddTriggerEffect("Convert Units in Area");
    rmSetTriggerEffectParam("SrcObject",pirate1Socket);
    rmSetTriggerEffectParamInt("SrcPlayer",0);
    rmSetTriggerEffectParamInt("TrgPlayer",k);
    rmSetTriggerEffectParam("UnitType","zpPirateWaterSpawnFlag1");
    rmSetTriggerEffectParamInt("Dist",100);
    rmAddTriggerEffect("Fire Event");
    rmSetTriggerEffectParamInt("EventID", rmTriggerID("Pirates1off_Player"+k));
    // Activate ALL ship training triggers
    rmAddTriggerEffect("Fire Event");
    rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainPrivateer1ON_Plr"+k));
    rmAddTriggerEffect("Fire Event");
    rmSetTriggerEffectParamInt("EventID", rmTriggerID("BlackbTrain1ONPlr"+k));
    rmAddTriggerEffect("Fire Event");
    rmSetTriggerEffectParamInt("EventID", rmTriggerID("BarbarossaTrain1ONPlr"+k));
    rmAddTriggerEffect("Fire Event");
    rmSetTriggerEffectParamInt("EventID", rmTriggerID("BlackCaesarTrain1ONPlr"+k));
    rmSetTriggerPriority(4);
    rmSetTriggerActive(true);
    rmSetTriggerRunImmediately(true);
    rmSetTriggerLoop(false);

    // OFF: Player loses TP at pirate settlement
    rmSwitchToTrigger(rmTriggerID("Pirates1off_Player"+k));
    rmAddTriggerCondition("Units in Area");
    rmSetTriggerConditionParam("DstObject",pirate1Socket);
    rmSetTriggerConditionParamInt("Player",k);
    rmSetTriggerConditionParamInt("Dist",35);
    rmSetTriggerConditionParam("UnitType","TradingPost");
    rmSetTriggerConditionParam("Op","==");
    rmSetTriggerConditionParamFloat("Count",0);
    rmAddTriggerEffect("Convert Units in Area");
    rmSetTriggerEffectParam("SrcObject",pirate1Socket);
    rmSetTriggerEffectParamInt("SrcPlayer",k);
    rmSetTriggerEffectParamInt("TrgPlayer",0);
    rmSetTriggerEffectParam("UnitType","zpPirateWaterSpawnFlag1");
    rmSetTriggerEffectParamInt("Dist",100);
    rmAddTriggerEffect("Fire Event");
    rmSetTriggerEffectParamInt("EventID", rmTriggerID("Pirates1on_Player"+k));
    // Disable ALL ship training triggers
    rmAddTriggerEffect("Disable Trigger");
    rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainPrivateer1ON_Plr"+k));
    rmAddTriggerEffect("Disable Trigger");
    rmSetTriggerEffectParamInt("EventID", rmTriggerID("BlackbTrain1ONPlr"+k));
    rmAddTriggerEffect("Disable Trigger");
    rmSetTriggerEffectParamInt("EventID", rmTriggerID("BarbarossaTrain1ONPlr"+k));
    rmAddTriggerEffect("Disable Trigger");
    rmSetTriggerEffectParamInt("EventID", rmTriggerID("BlackCaesarTrain1ONPlr"+k));
    rmSetTriggerPriority(4);
    rmSetTriggerActive(false);
    rmSetTriggerRunImmediately(true);
    rmSetTriggerLoop(false);
}

// Trading post activation for settlement 2 (conditional - only if >3 players)
if (cNumberNonGaiaPlayers > 3) {
    for (k=1; <= cNumberNonGaiaPlayers) {
        rmCreateTrigger("Pirates2on Player"+k);
        rmCreateTrigger("Pirates2off Player"+k);
        // ... (same pattern as settlement 1, using pirate2Socket)
    }
}
```

### Key Features of This System

✅ **Conditional Settlement 2** - Only creates triggers if `>3` players  
✅ **Cooldown Management** - 1200ms between training attempts  
✅ **Build Limit Control** - Reduces population with `cTechzpReducePirateShipsBuildLimit`  
✅ **Trading Post Control** - Ships only trainable when player owns the TP  
✅ **Water Flag Conversion** - Transfers spawn flag ownership with TP control  
✅ **Multi-Ship System** - Both privateers and unique ships active simultaneously

### Regional Pirate Captain Variants

| Region | Captain 1 | Captain 2 | Captain 3 | Consulate Tech |
|--------|-----------|-----------|-----------|----------------|
| **Mediterranean** | Blackbeard (Queen Anne) | Barbarossa (Sultana) | Black Caesar (Neptune) | `cTechzpTurnConsulateOffPiratesMedi` |
| **Baltic** | Blackbeard | Grace O'Malley | Beauregard | `cTechzpTurnConsulateOffPiratesBaltic` |
| **Australia** | Different set | Different set | Different set | `cTechzpTurnConsulateOffPiratesAustralia` |

**⚠️ Important:** Always match captain names in triggers to the regional variant and verify ship availability in `techtreemods.xml`!

---

## ✅ Best Practices

### 1. **Variable Declaration**

```xs
// ✅ CORRECT: Declare loop variables at the top of main()
int i=0;
int k=0;

// ✅ CORRECT: Variables inside trigger loops are allowed
for (k=1; <= cNumberNonGaiaPlayers) {
    int pirateCaptain=-1; // This is valid in XS
    pirateCaptain = rmRandInt(1,3);
}
```

### 2. **Inline Comments**

```xs
// ✅ CORRECT: Comment on the same line as TechID
rmSetTriggerEffectParam("TechID","cTechzpSpanishHabsburgs"); // Activate Spanish Habsburgs for all players

// ❌ INCORRECT: Comment on separate line (less readable)
// Activate Spanish Habsburgs for all players
rmSetTriggerEffectParam("TechID","cTechzpSpanishHabsburgs");
```

### 3. **Trigger Naming**

```xs
// ✅ CORRECT: Descriptive names with player suffix
rmCreateTrigger("Activate Consulate Japan"+k);
rmCreateTrigger("ZP Pick Pirate Captain"+k);

// ❌ INCORRECT: Generic names
rmCreateTrigger("Trigger1");
rmCreateTrigger("Test");
```

### 4. **Priority Settings**

| Priority | Use Case |
|----------|----------|
| **4** | Starting techs, critical setup, politician triggers |
| **3** | Mid-game events |
| **2** | Supporting triggers (balance adjustments) |
| **1** | Low-priority background tasks |

### 5. **Loop vs One-Time Execution**

```xs
// ✅ Loop = true for continuous monitoring
rmSetTriggerLoop(true);  // E.g., consulate activation (monitors tech research)

// ✅ Loop = false for one-time events
rmSetTriggerLoop(false); // E.g., starting techs, AI captain selection
```

### 6. **Regional Variant Selection**

Always match the **pirate consulate tech** to your map's region:

| Region | Tech ID |
|--------|---------|
| Mediterranean | `cTechzpTurnConsulateOffPiratesMedi` |
| Baltic/North Europe | `cTechzpTurnConsulateOffPiratesBaltic` |
| Pacific/Australia | `cTechzpTurnConsulateOffPiratesAustralia` |
| Default/Caribbean | `cTechzpTurnConsulateOffPirates` |

**Validation:** Always check `data/techtreemods.xml` to confirm which captains are available for each variant.

---

## ⚠️ Common Mistakes

### 1. **Forgetting to Declare Loop Variables**

```xs
// ❌ WRONG: 'k' never declared
for (k=1; <= cNumberNonGaiaPlayers) {
    rmCreateTrigger("Test"+k);
}

// ✅ CORRECT: Declare at top of main()
int k=0;
for (k=1; <= cNumberNonGaiaPlayers) {
    rmCreateTrigger("Test"+k);
}
```

### 2. **Wrong Player Loop Range**

```xs
// ❌ WRONG: Should start from 1 for player-specific triggers
for (k=0; <= cNumberNonGaiaPlayers) { ... }

// ✅ CORRECT: Start from 1 for player triggers
for (k=1; <= cNumberNonGaiaPlayers) { ... }

// ✅ CORRECT: Start from 0 for tech activation (includes Gaia in some cases)
for (i=0; <= cNumberNonGaiaPlayers) { ... }
```

### 3. **Mismatched Trigger Names**

```xs
// ❌ WRONG: Case mismatch
rmCreateTrigger("Starting Techs");
rmSwitchToTrigger(rmTriggerID("Starting techs")); // Different case!

// ✅ CORRECT: Exact match (case-insensitive in this engine, but best practice)
rmCreateTrigger("Starting Techs");
rmSwitchToTrigger(rmTriggerID("Starting Techs"));
```

### 4. **Missing Fire Event References**

```xs
// ❌ WRONG: Trigger created but never activated
rmCreateTrigger("Cheat Returner"+k);
// ... setup ...
rmSetTriggerActive(false);

// No Fire Event to activate it!

// ✅ CORRECT: Fire the trigger from another event
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Cheat_Returner"+k));
```

### 5. **Using Wrong Pirate Captains for Region**

```xs
// ❌ WRONG: Baltic captain on Mediterranean map
rmSetTriggerEffectParam("TechID","cTechzpTurnConsulateOffPiratesBaltic");
// Then using: Beauregard, Grace O'Malley (not available in Baltic!)

// ✅ CORRECT: Match captains to regional tech
rmSetTriggerEffectParam("TechID","cTechzpTurnConsulateOffPiratesMedi");
// Then using: Blackbeard, Black Caesar, Barbarossa (Mediterranean)
```

---

## 🔧 Troubleshooting

### Issue: Trigger Not Firing

**Check:**
1. Is `rmSetTriggerActive(true)` set?
2. Are conditions being met? (Test with `rmEchoInfo()`)
3. Is trigger priority correct?
4. Is it referenced by another trigger's Fire Event?

### Issue: Politicians Not Appearing

**Check:**
1. Is "Human Check" trigger active and firing?
2. Is the correct civilization condition set?
3. Is `ZP Pick Consulate Tech` effect present?
4. Is the correct regional variant used?

### Issue: AI Not Getting Captains

**Check:**
1. Condition: `MyBool = "false"` (AI only)
2. Age 1 tech condition (TechID 586)
3. Random variable initialization (`int pirateCaptain=-1`)
4. Correct TechID for regional variant

### Issue: Tech Not Activating

**Check:**
1. TechID spelling (case-sensitive!)
2. Status parameter (should be `2` for active)
3. Player loop range (`0` to `cNumberNonGaiaPlayers` or `1` to `cNumberNonGaiaPlayers`)
4. Verify tech exists in `data/techtreemods.xml`

---

## 📚 See Also

- **[Random Map Generation Guide](random_map_generation_guide.md)** - Main guide for creating maps
- **[Map Coordinate System Guide](map_coordinate_system.md)** - Understanding XZ coordinate rotation
- **[Project Documentation](project_documentation.md)** - Overall mod structure
- **`data/trigger/triggerdata.xml`** - Complete trigger reference (in-game file)
- **`data/techtreemods.xml`** - Tech definitions and availability

---

## 📝 Summary Checklist

When implementing triggers on a new map:

### Basic Setup
- [ ] Declare loop variables (`int i=0; int k=0;`) at top of `main()`
- [ ] Create "Starting Techs" trigger for map setup
- [ ] Use **inline comments** for all TechID parameters
- [ ] Verify all TechIDs in `techtreemods.xml`

### Politicians & Consulates
- [ ] Add politician triggers if map is pirate/universal theme
- [ ] Include supporting triggers (Italian balance, cheat returner)
- [ ] Add "Human Check" trigger to activate politician triggers
- [ ] Add AI leader selection (if applicable)
- [ ] Match regional pirate variant to map theme (Mediterranean/Baltic/Australia)

### Pirate Ship Training (Advanced)
- [ ] Create socket variables from pirate water flags
- [ ] Implement privateer training triggers (Layer 1)
- [ ] Implement unique ship training triggers (Layer 2)
- [ ] Implement trading post activation triggers (Layer 3)
- [ ] Add conditional settlement 2 triggers if `>3` players
- [ ] Ensure correct captain names match regional variant
- [ ] Link all training triggers to trading post activation/deactivation

### Testing
- [ ] Test with different player counts (2, 3, 4, 6, 8)
- [ ] Test with different civilizations
- [ ] Verify pirate ship training with Trading Post control
- [ ] Check conditional triggers activate correctly

---

**Version History:**
- **v1.1** (November 2025) - Added comprehensive pirate ship training & trading post activation section with Mediterranean captain implementation (Blackbeard, Barbarossa, Black Caesar)
- **v1.0** (November 2025) - Initial guide based on Balearic Islands map implementation

---

*This guide was created as part of the Age of Empires 3: DE - Age of Pirates mod project.*

