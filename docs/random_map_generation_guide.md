# Random Map Generation Guide for AI Agents

**Audience:** AI assistants working on Age of Empires III: Definitive Edition random map scripts  
**Last Updated:** 2025-11-01

---

## ⚠️ CRITICAL: Understanding Coordinates

**Before working with ANY map coordinates, read `docs/map_coordinate_system.md`!**

The XZ coordinate system used in `.xs` scripts is **rotated 45° from the visual minimap display**:
- Code "NE" (1.0, 1.0) → Visual **North** (top of diamond)
- Code "SE" (1.0, 0.0) → Visual **East** (right of diamond)
- Code "SW" (0.0, 0.0) → Visual **South** (bottom of diamond)
- Code "NW" (0.0, 1.0) → Visual **West** (left of diamond)

**Always think in X/Z values, not cardinal directions!**

---

## 📁 Map Folder Structure

### **Three Map Locations:**

1. **Root Game Folder (PREFERRED FOR TESTING):**
   ```
   C:/Program Files (x86)/Steam/steamapps/common/AoE3DE/Game/RandMaps/
   ```
   - ✅ Use this for **all new map development**
   - ✅ Loads directly without mod packaging
   - ✅ Fastest iteration/testing
   - ⚠️ **CAUTION:** Some maps here are **ENCODED** (`.xs` files are binary, unreadable)
     - **Encoded prefixes:** `eu*` (European maps), `af*` (African maps)
     - **Example:** `euMediterranean.xs` is ENCODED - cannot be copied/read!

2. **Mod Folder (for mod distribution):**
   ```
   <workspace>/randmaps/
   ```
   - Use for **final mod packaging**
   - Maps here are loaded by the mod system
   - Good for version control

3. **Mod Game Subfolder (advanced):**
   ```
   <workspace>/game/randmaps/
   ```
   - Mirrors root game structure
   - Use for overriding base game maps

---

## 📝 Naming Convention

### **Prefix: `000zp`**

**Format:** `000zp<MapName>.xs` and `000zp<MapName>.xml`

**Why this prefix?**
- `000` = Sorts to top of map list in-game
- `zp` = Age of Pirates mod identifier
- **Examples:**
  - `000zpBalearicIslands.xs`
  - `000zpCaribbean.xs`
  - `000zpMalta.xs`

---

## 📋 Required Files

Every random map needs **TWO files:**

### **1. `.xs` File (Script)**
The actual map generation code (XS language).

**Template:**
```xs
// MapName
// Description

include "mercenaries.xs";
include "ypAsianInclude.xs";
include "ypKOTHInclude.xs";

void main(void)
{
    rmSetStatusText("",0.01);
    
    // Map generation code here...
    
    rmSetStatusText("",1.0);
}
```

### **2. `.xml` File (Metadata)**
Map metadata for game menus.

**Template:**
```xml
<?xml version="1.0" encoding="utf-8"?>
<map>
  <name>[String ID]</name>
  <description>[String ID]</description>
  <defaultplayers>4</defaultplayers>
  <minplayers>2</minplayers>
  <maxplayers>8</maxplayers>
  <playerposition x="0.25" z="0.25" />
  <playerposition x="0.75" z="0.25" />
  <playerposition x="0.75" z="0.75" />
  <playerposition x="0.25" z="0.75" />
  <type>water</type>
  <type>islands</type>
</map>
```

---

## 📚 Reference Documentation

### **1. RM Commands List**
**Location:** `docs/all_rm_commands.txt` (273 commands)

**⚠️ AI MUST READ when creating maps!**

**Key command categories:**
- **Terrain:** `rmTerrainInitialize()`, `rmSetSeaType()`, `rmSetBaseTerrainMix()`
- **Players:** `rmPlacePlayersCircular()`, `rmSetPlayerArea()`
- **Areas:** `rmCreateArea()`, `rmBuildArea()`, `rmSetAreaSize()`
- **Objects:** `rmCreateObjectDef()`, `rmPlaceObjectDefAtLoc()`
- **Resources:** `rmAddObjectDefItem()`, `rmPlaceObjectDefInArea()`
- **Natives:** `rmCreateGrouping()`, `rmPlaceGroupingAtLoc()`
- **Trade Routes:** `rmCreateTradeRoute()`, `rmAddTradeRouteWaypoint()`

### **2. Water Types**
**Locations:**
- `scripts/source/waterbodies.xml` (base game water types)
- `data/waterbodies2.xml` (mod-specific water types - Age of Pirates custom waters!)

**⚠️ ALWAYS search BOTH files for matching water type names based on map concept!**

**How to find water types:**
1. **Search BOTH files** (base game + mod):
   - `scripts/source/waterbodies.xml` (base game)
   - `data/waterbodies2.xml` (Age of Pirates mod - check here first for custom types!)
2. **Search for concept keywords:**
   - Balearic Islands → search for "mediterranean", "iceland"
   - Caribbean map → search for "caribbean"
   - Asian map → search for "ceylon", "japan"
   - Mod maps → check `waterbodies2.xml` for "ZP" prefix types!
3. **Find `<ocean name="..."` or `<river name="..."` or `<lake name="..."` tags**
4. **Use EXACT name** from the `name=` attribute

**Example search process:**
```bash
# For Balearic Islands (Mediterranean theme):
# First, check mod file for custom types:
grep -i "mediterranean\|iceland" data/waterbodies2.xml  # Check mod waters first!
# Then check base game:
grep -i "mediterranean" scripts/source/waterbodies.xml  # No results!
grep "name=" scripts/source/waterbodies.xml | grep -i "coast"  # List all coasts
# Result: Use "ZP Iceland" from mod file or closest base game match
```

**DO NOT:**
- ❌ Provide pre-made "common" lists (they may not exist!)
- ❌ Guess names based on assumptions
- ❌ Search only ONE file - check BOTH waterbodies.xml AND waterbodies2.xml!
- ✅ ALWAYS search mod file (waterbodies2.xml) first for custom "ZP" types
- ✅ Then search base game file (scripts/source/waterbodies.xml) for standard types

### **3. Terrain Types vs. Terrain Mixes**

**⚠️ IMPORTANT:** Understand the difference!

#### **A) Terrain TYPES (Individual textures/brushes)**
**Locations:**
- `scripts/source/art/terrain/terraintypes.xml`
- `scripts/source/art/terrain/terraintypes2.xml`
- `scripts/source/art/terrain/terraintypes3.xml`
- `scripts/source/art/terrain/terraintypescherry.xml`

**Definition:** Single texture definitions (e.g., `"andes\ground07_and"`, `"Amazon\ground1_ama"`)

**Used for:** Painting individual terrain textures

**Example from terraintypes.xml:**
```xml
<subtype uiname="Amazon Ground 1">Amazon\ground1_ama</subtype>
<subtype uiname="Amazon Ground 2">Amazon\ground2_ama</subtype>
```

#### **B) Terrain MIXES (Combinations of terrain types)**
**Location:** `scripts/source/art/terrain/mix/` (258 XML files)

**Definition:** Blended combinations of multiple terrain types with weights

**Used in maps via:** `rmSetBaseTerrainMix("mix name")` or `rmSetAreaMix()`

**Example file:** `caribbean grass.xml`
```xml
<mix>
  <title>Caribbean Grass</title>
  <paint mode="turbulence">
    <texture weight="4">caribbean\ground1_crb</texture>
    <texture weight="3">caribbean\ground2_crb</texture>
    <texture weight="1">caribbean\ground3_crb</texture>
  </paint>
</mix>
```

**How to find terrain mixes:**
1. **List files:** `scripts/source/art/terrain/mix/` folder
2. **Search by theme:** Look for names matching your map concept
   - Balearic Islands → look for "italy" (Mediterranean region)
   - Caribbean → look for "caribbean grass.xml"
   - Asian → look for "ceylon", "borneo", "coastal_japan"
3. **Use exact filename** (without .xml extension) in map script
   - ⚠️ **CRITICAL: Use underscores not spaces!**
   - File: `italy_grass.xml` → Use: `"italy_grass"` ✅
   - **NOT:** `"italy grass"` ❌ (will crash the game!)

**Common terrain mixes (examples from the folder):**
- `"caribbean grass"` (tropical islands - file has space in name!)
- `"ceylon_grass_a"` (Sri Lanka/Asian islands)
- `"italy_grass"` (Mediterranean - note the underscore!)
- `"great plains grass"` (temperate)
- `"borneo_grass_a"` (Southeast Asian jungle)

### **4. Cliff Types**

**Locations:**
- `<workspace>/data/clifftypes2.xml` (mod-specific cliffs)
- `<workspace>/scripts/source/clifftypes.xml` (base game cliffs)

**Definition:** 3D cliff/edge definitions for creating vertical terrain features

**Used in maps via:** `rmSetAreaCliffType()` in area creation

**How to find cliff types:**
1. **Search both files** for `name=` attributes in `<clifftype>` tags
2. **Look for thematic matches** (e.g., "Iceland", "fjord", "volcano", "coastal")
3. **Use exact name** from the `name=` attribute

**Example cliff types:**
- `"ZP Iceland Fjord"` (custom mod cliff)
- `"ZP Iceland Low/Medium/High"` (volcano cliffs)
- `"ZP Hawaii Crater"` (crater edges)

---

### **5. Resource Types (Huntables, Fish, Whales, Mines, Berries)**

Resources are ProtoUnits defined in `data/protomods.xml` and `scripts/source/protoy.xml`. Each resource type is identified by specific `<unittype>` tags.

#### **A) Huntable Animals**

**Requirements:**
```xml
<unittype>Huntable</unittype>
```

**Common huntable types:**
- **deer** - Generic temperate deer
- **ypIbex** - Iberian Ibex (Mediterranean wild goats) 🎯
- **Sheep** - Domestic Mediterranean sheep
- **ypGoat** - Asian/Mediterranean goats
- **Caribou** - Arctic/subarctic deer
- **BighornSheep** - American mountain sheep

**How to find:**
1. Search `data/protomods.xml` for `<unittype>Huntable</unittype>`
2. Look for regionally-appropriate animals (e.g., ypIbex for Mediterranean)
3. Check existing Mediterranean maps (Venice, Black Sea, Malta) for examples

**Usage example:**
```xs
string huntPrimary = "ypIbex";              // Iberian Ibex for Mediterranean
rmAddObjectDefItem(playerDeerID, huntPrimary, 10, 8.0);
```

#### **B) Fish**

**Requirements:**
```xml
<unittype>AbstractFish</unittype>
<unittype>AbstractFishOrWhale</unittype>
<!-- Must NOT have: <unittype>MovableFish</unittype> -->
```

**⚠️ CRITICAL:** Never use fish with `<unittype>MovableFish</unittype>` - these are special animated fish

**Common fish types:**
- **ypFishTuna** - Mediterranean tuna (Venice, Malta) 🎯
- **FishSalmon** - Temperate salmon (Mediterranean, Black Sea)
- **FishMahi** - Tropical mahi-mahi (Caribbean)
- **FishTarpon** - Tropical tarpon (Caribbean)
- **ypFishCarp** - Freshwater carp (rivers, lakes)
- **ypFishMolaMola** - Ocean sunfish (Pacific)

**How to find:**
1. Look at existing maps for your region (e.g., zp_mediterranean.xs, zp_venice.xs)
2. Mediterranean → ypFishTuna, FishSalmon
3. Caribbean → FishMahi, FishTarpon
4. Pacific → ypFishTuna, ypFishMolaMola

**Usage example:**
```xs
string fishPrimary = "ypFishTuna";          // Mediterranean tuna
rmAddObjectDefItem(fishID, fishPrimary, 1, 0.0);
```

#### **C) Whales**

**Requirements:**
```xml
<unittype>AbstractWhale</unittype>
<unittype>AbstractFishOrWhale</unittype>
<!-- Must NOT have: <unittype>AbstractUnderwaterMine</unittype> -->
```

**⚠️ CRITICAL:** Never use whales with `<unittype>AbstractUnderwaterMine</unittype>` - these are special objects

**Common whale types:**
- **MinkeWhale** - Mediterranean, temperate oceans (most common) 🎯
- **HumpbackWhale** - Pacific, tropical oceans

**How to find:**
1. **MinkeWhale** is standard for Mediterranean, Atlantic, Arctic
2. **HumpbackWhale** for Pacific, tropical regions
3. Check existing maps: Venice, Malta, Black Sea all use MinkeWhale

**Usage example:**
```xs
string whaleType = "MinkeWhale";
rmAddObjectDefItem(whaleID, whaleType, 1, 0.0);
```

#### **D) Mines**

**Requirements:**
```xml
<unittype>AbstractMine</unittype>
<unittype>MinedResource</unittype>
```

**⚠️ CRITICAL:** Must have BOTH tags. Objects with only `<unittype>AbstractMine</unittype>` are special objects

**Common mine types:**
- **Mine** - Generic silver/gold mine (most common) 🎯
- **MineCopper** - Copper mine (Black Sea, historical regions)
- **MineGold** - Specific gold mine
- **MineSalt** - Salt mine (special maps)

**Usage example:**
```xs
string mineType = "Mine";
rmAddObjectDefItem(playerSilverID, mineType, 1, 0);
```

#### **E) Berries**

**Requirements:**
```xml
<unittype>AbstractBerryBush</unittype>
<!-- Must NOT have: <unittype>Building</unittype> -->
```

**⚠️ CRITICAL:** Never use berries with `<unittype>Building</unittype>` - these are special buildings

**Common berry types:**
- **BerryBush** - Standard berry bush (used in all maps) 🎯

**Usage example:**
```xs
string berryType = "BerryBush";
rmAddObjectDefItem(berryID, berryType, 5, 4.0);  // 5 bushes, 4.0 cluster spread
```

---

### **6. Map Types (Gameplay, AI Behavior, Treasures)**

Map types are defined in `scripts/source/maptypes.xml` (base game) and `data/maptypemods.xml` (mod-specific). They control:
- AI behavior (land vs water strategies)
- Treasure/nugget types spawned
- Trade route types
- Special gameplay modifiers

**⚠️ IMPORTANT:** Always define map types as **variables** for clarity and maintainability.

#### **Map Type Categories**

**A) Layout Type (REQUIRED)**
- **`"water"`** - Maps with significant water areas (naval gameplay, AI builds ships)
- **`"land"`** - Maps with no/minimal water (AI focuses on land units)

**Rule:** If your map has oceans, seas, or large lakes → use `"water"`

**B) Biome Type**
- **`"grass"`** - Temperate grasslands
- **`"snow"`** - Arctic/winter maps
- **`"tropical"`** - Tropical/jungle maps
- **`"desert"`** - Arid desert maps

**C) Nugget/Treasure Type (Regional)**
- **`"mediEurope"`** - Mediterranean Europe (Spain, Italy, Greece)
- **`"centralEurope"`** - Central Europe (Germany, Austria)
- **`"eastEurope"`** - Eastern Europe (Poland, Russia, Turkey)
- **`"westEurope"`** - Western Europe (France, Netherlands)
- **`"Tassili"`**, **`"Wallachia"`**, etc. - Specific region treasures

**D) Trade Route Type**

**For European maps:**
- **`"euroLandTradeRoute"`** - European land trade route
- **`"euroNavalTradeRoute"`** - European naval trade route (standard water maps)
- **`"euroLandNavalTradeRoute"`** - Both land and naval
- **`"euroRiverTradeRoute"`** - River-based trade route
- **`"euroTradeRouteCapture"`** - Capturable trading post sockets ⚠️

**For non-European maps** (Caribbean, Asia, Pacific, Africa, Americas):
- No special trade route map type is necessary (leave empty or omit)

**⚠️ IMPORTANT:** Only use `"euroTradeRouteCapture"` when your map explicitly has capturable trade sockets!

**E) Special Types**
- **`"piratehistoricalmap"`** - Age of Pirates mod special type (enables pirate features)
- **`"caribbeanwater"`**, **`"malta"`**, **`"icelandWater"`** - Custom mod map types

---

#### **Example: Mediterranean Map**

Based on zpBalearicIslands.xs:

```xs
// Map types (define gameplay and treasure types)
string layoutType = "water";                             // Water map (has naval gameplay)
string biomeType = "grass";                              // Grass biome
string nuggetType = "mediEurope";                        // Mediterranean Europe treasures
string tradeType = "euroNavalTradeRoute";                // European naval trade route
string specialType1 = "piratehistoricalmap";             // Age of Pirates special type
string specialType2 = "";                                // Reserved for future use

// Apply map types
rmSetMapType(layoutType);
rmSetMapType(biomeType);
rmSetMapType(nuggetType);
rmSetMapType(tradeType);
rmSetMapType(specialType1);
```

**Why this works:**
- ✅ **`layoutType = "water"`** - Map has Italian Sea (significant water)
- ✅ **`biomeType = "grass"`** - Mediterranean grasslands (not snow/desert/tropical)
- ✅ **`nuggetType = "mediEurope"`** - Balearic Islands are in Mediterranean Europe
- ✅ **`tradeType = "euroNavalTradeRoute"`** - European naval trade route (standard, not capturable)
- ✅ **`specialType1 = "piratehistoricalmap"`** - This is an Age of Pirates mod map

---

#### **How to Choose Map Types**

1. **Analyze existing maps in your region:**
   ```bash
   # Search for similar maps
   grep "rmSetMapType" zp_venice.xs
   grep "rmSetMapType" 000_blacksea.xs
   ```

2. **Check maptypes files:**
   - `scripts/source/maptypes.xml` - Base game types
   - `data/maptypemods.xml` - Mod-specific types

3. **Follow the pattern:**
   - **Water maps:** Always include `"water"`
   - **Land maps:** Always include `"land"`
   - **All maps:** Include biome type (`"grass"`, `"snow"`, etc.)
   - **Regional maps:** Include nugget type (`"mediEurope"`, `"eastEurope"`, etc.)
   - **Trade route maps:** Include trade type (`"euroTradeRouteCapture"`, etc.)
   - **Age of Pirates maps:** Include `"piratehistoricalmap"`

---

#### **Common Patterns**

| Region | Layout | Biome | Nugget | Trade | Special |
|--------|--------|-------|--------|-------|---------|
| **Mediterranean (Balearic)** | water | grass | mediEurope | euroNavalTradeRoute | piratehistoricalmap |
| **Venice** | water | grass | mediEurope | euroNavalTradeRoute | piratehistoricalmap |
| **Black Sea** (capturable) | water | grass | eastEurope | euroTradeRouteCapture | piratehistoricalmap |
| **Caribbean** | water | tropical | - | - | caribbeanwater, piratehistoricalmap |
| **Iceland** | water | snow | Iceland | euroLandTradeRoute | icelandWater, piratehistoricalmap |

**Note:** Use `euroTradeRouteCapture` ONLY when map has capturable trade sockets!

---

### **7. Native Civilizations (Subcivs)**

**Locations:**
- `<workspace>/scripts/source/civs.xml` (base game natives) ⚠️ **MUST SEARCH THIS FILE!**
- `<workspace>/data/civmods.xml` (mod-specific natives) ⚠️ **MUST SEARCH THIS FILE!**

**Definition:** Minor civilizations that appear on maps as native villages/sites that players can ally with

**How to find natives:**
1. ⚠️ **CRITICAL: Search BOTH XML files** - Base game natives (like `Habsburg`, `Maltese`) are in `civs.xml`, mod natives (like `zpVenetians`, `SPCBourbon`) are in `civmods.xml`
2. **Search for `<name>` tags** within `<civ>` entries in BOTH files
3. **Check `<subcivtype>`** tag to understand native type (values: 1, 2, 3, or 4)
4. Look at existing similar maps to see which natives they use

**Important rules:**
- ⚠️ **Always search BOTH files!** Don't assume a native doesn't exist if you only checked one file
- ⚠️ **If multiple subcivs have similar names** (e.g., `SPCSufi` and `Sufi`), **always use the SPC variant** (`SPCSufi`)
- Same rule applies to other duplicates: prefer `SPCZen` over `Zen`, `SPCJesuit` over `Jesuit`, etc.

---

#### **Usage in Random Maps**

```xs
// Step 1: Declare native variables
int subCiv0 = -1;
int subCiv1 = -1;
int subCiv2 = -1;

// Step 2: Allocate and set subcivs
if (rmAllocateSubCivs(3) == true)
{
    // First native
    subCiv0 = rmGetCivID("Maltese");
    rmEchoInfo("subCiv0 is Maltese " + subCiv0);
    if (subCiv0 >= 0)
        rmSetSubCiv(0, "Maltese");

    // Second native
    subCiv1 = rmGetCivID("zpVenetians");
    rmEchoInfo("subCiv1 is zpVenetians " + subCiv1);
    if (subCiv1 >= 0)
        rmSetSubCiv(1, "zpVenetians");
    
    // Third native
    subCiv2 = rmGetCivID("NatPirates");
    rmEchoInfo("subCiv2 is NatPirates " + subCiv2);
    if (subCiv2 >= 0)
        rmSetSubCiv(2, "NatPirates");
}
```

**⚠️ NOTE:** Native village placement (groupings) is a more complex topic covered separately.

---

#### **How to Choose Natives**

1. **Look at existing maps** in your region:
   ```bash
   grep "rmGetCivID" zpvenice.xs
   grep "rmSetSubCiv" zpmalta.xs
   ```

2. **Search BOTH XML files** for natives that match your map's theme/region:
   ```bash
   # Search base game natives
   grep "<name>" scripts/source/civs.xml
   
   # Search mod natives
   grep "<name>" data/civmods.xml
   ```

3. **Use the exact name** from the `<name>` tag in your `rmGetCivID()` and `rmSetSubCiv()` calls

---

### **8. Forest Types**

**Locations:**
- `<workspace>/scripts/source/forest.xml` (base game - 29 forest types)
- `<workspace>/scripts/source/forest2.xml` (expanded - 49+ forest types)

**Definition:** Complete forest definitions including tree species, density, clumpiness, floor mix, and underbrush

**Used in maps via:** `rmSetAreaForestType()` in forest area creation

**How to find forest types:**
1. **Search both files** for `name=` attributes in `<forest>` tags
2. **Look for thematic/regional matches** (e.g., "Mediterranean", "Italian", "Caribbean")
3. **Use exact name** from the `name=` attribute
4. **Check tree species** in `<protounit>` tags (e.g., `TreeCaribbean`, `ypTreeMongolianFir`)

**Example forest types:**
- `"Italian Forest"` (Mediterranean temperate forest)
- `"z31 Mediterranean Coastal Forest"` (coastal Mediterranean)
- `"z42 Italian Forest"` (northern Italian style)
- `"Caribbean Palm Forest"` (tropical palms)
- `"Great Lakes Forest"` (temperate hardwoods)

**Forest Properties:**
- `density` - Tree spacing (0.0 to 1.0, typical 0.25-0.75)
- `clumpiness` - Tree clustering (0.0 = scattered, 1.0 = dense clumps)
- `floor` or `floormix` - Ground texture under trees
- `<protounit>` - Tree species (can have multiple for variety)
- `<underbrushobj>` - Undergrowth/bushes

---

## 🏝️ Map Patterns: Player vs Team Islands

**Understanding island placement patterns is critical for creating balanced, playable maps.**

There are two fundamental patterns for placing player starting areas on island maps:

---

### **Pattern 1: Player Islands (Individual Islands)**

**Concept:** Each player gets their own separate island.

**Used in:** zpPhilippines (original), most standard island maps

#### **Structure:**

```xs
// Player placement (same for both patterns)
rmSetPlacementSection(0.15, 0.85);
rmPlacePlayersCircular(0.29, 0.29, 0);

// PLAYER ISLANDS - One island per player
float playerFraction = rmAreaTilesToFraction(7000 - cNumberNonGaiaPlayers*300);
for(i=1; <cNumberPlayers)
{
    // Create individual player's island
    int playerID = rmCreateArea("player "+i);
    rmSetPlayerArea(i, playerID);  // Assign island to player
    rmSetAreaSize(playerID, playerFraction, playerFraction);
    rmAddAreaToClass(playerID, classIsland);
    rmSetAreaLocPlayer(playerID, i);  // Place at player's spawn location
    rmSetAreaWarnFailure(playerID, false);
    rmSetAreaCoherence(playerID, 0.5);
    rmSetAreaBaseHeight(playerID, 2.0);
    rmSetAreaSmoothDistance(playerID, 20);
    rmSetAreaMix(playerID, baseMix);
    
    // Constraints
    rmAddAreaConstraint(playerID, islandConstraint);
    rmAddAreaConstraint(playerID, islandEdgeConstraint);
    rmAddAreaConstraint(playerID, islandAvoidTradeRoute);
    
    // Elevation
    rmSetAreaElevationType(playerID, cElevTurbulence);
    rmSetAreaElevationVariation(playerID, 4.0);
    rmSetAreaElevationMinFrequency(playerID, 0.09);
    rmSetAreaElevationOctaves(playerID, 3);
    rmSetAreaElevationPersistence(playerID, 0.2);
    rmSetAreaElevationNoiseBias(playerID, 1);
}

// Build all islands
rmBuildAllAreas();

// Resource placement - per player island
for (i=0; <cNumberPlayers)
{
    rmPlaceObjectDefInArea(silverID, 0, rmAreaID("player "+i), 3);
    rmPlaceObjectDefInArea(foodID, 0, rmAreaID("player "+i), 4);
    rmPlaceObjectDefInArea(nuggetID, 0, rmAreaID("player "+i), 2);
}
```

#### **Key Characteristics:**
- ✅ **Loop starts at 1:** `for(i=1; <cNumberPlayers)` - player 0 is Gaia
- ✅ **Individual ownership:** Each player owns their island
- ✅ **Player-specific location:** `rmSetAreaLocPlayer(playerID, i)`
- ✅ **Size calculation:** Based on total players (`7000 - cNumberNonGaiaPlayers*300`)
- ✅ **Resource scaling:** Fixed amount per player (e.g., 3 mines each)

#### **Advantages:**
- 🎯 Guaranteed personal space for each player
- 🎯 Equal island size for all players
- 🎯 Easier to balance resources per player
- 🎯 Works well for FFA (Free For All) games

#### **Disadvantages:**
- ⚠️ Team members are separated (harder to help each other)
- ⚠️ More islands = more complex map generation
- ⚠️ Harder to defend/coordinate as a team

---

### **Pattern 2: Team Islands (Shared Islands)**

**Concept:** Each team gets one large shared island that contains all team members.

**Used in:** zpCookIslands, Caribbean, Balearic Islands (updated)

#### **Structure:**

```xs
// Player placement (same as Pattern 1)
rmSetPlacementSection(0.15, 0.85);
rmPlacePlayersCircular(0.29, 0.29, 0);

// TEAM ISLANDS - One island per team
float isleSize = (0.18 / cNumberTeams);  // Cook Islands formula
for(i=0; <cNumberTeams)
{
    // Create shared team island
    int teamID = rmCreateArea("team "+i);
    rmSetAreaSize(teamID, isleSize, isleSize);
    rmAddAreaToClass(teamID, classIsland);
    rmSetAreaWarnFailure(teamID, false);
    rmSetAreaCoherence(teamID, 0.5);
    rmSetAreaBaseHeight(teamID, 2.0);
    rmSetAreaSmoothDistance(teamID, 20);
    rmSetAreaMix(teamID, baseMix);
    
    // Constraints
    rmAddAreaConstraint(teamID, islandConstraint);
    rmAddAreaConstraint(teamID, islandEdgeConstraint);
    rmAddAreaConstraint(teamID, islandAvoidTradeRoute);
    
    // Elevation
    rmSetAreaElevationType(teamID, cElevTurbulence);
    rmSetAreaElevationVariation(teamID, 4.0);
    rmSetAreaElevationMinFrequency(teamID, 0.09);
    rmSetAreaElevationOctaves(teamID, 3);
    rmSetAreaElevationPersistence(teamID, 0.2);
    rmSetAreaElevationNoiseBias(teamID, 1);
    
    rmSetAreaLocTeam(teamID, i);  // Place at team's collective location
    rmEchoInfo("Team area "+i);
}

// Build all islands
rmBuildAllAreas();

// Resource placement - per team island (scaled by team size)
for (i=0; <cNumberTeams)
{
    int playersOnTeam = rmGetNumberPlayersOnTeam(i);
    rmPlaceObjectDefInArea(silverID, 0, rmAreaID("team "+i), 3*playersOnTeam);
    rmPlaceObjectDefInArea(foodID, 0, rmAreaID("team "+i), 4*playersOnTeam);
    rmPlaceObjectDefInArea(nuggetID, 0, rmAreaID("team "+i), 2*playersOnTeam);
}
```

#### **Key Characteristics:**
- ✅ **Loop starts at 0:** `for(i=0; <cNumberTeams)` - teams start from 0
- ✅ **Shared ownership:** All team members share one island
- ✅ **Team-based location:** `rmSetAreaLocTeam(teamID, i)`
- ✅ **Size calculation:** Based on number of teams (`0.18 / cNumberTeams`)
- ✅ **Resource scaling:** Multiplied by team size (`3*rmGetNumberPlayersOnTeam(i)`)

#### **Advantages:**
- 🎯 Team members start together (easier cooperation)
- 🎯 Better for team games (2v2, 3v3, 4v4)
- 🎯 Fewer islands = faster map generation
- 🎯 More realistic for historical team scenarios

#### **Disadvantages:**
- ⚠️ Teammates may compete for nearby resources
- ⚠️ Less personal space per player
- ⚠️ Unbalanced if teams have different sizes

---

### **Critical Differences Summary**

| Aspect | Player Islands | Team Islands |
|--------|---------------|--------------|
| **Loop** | `for(i=1; <cNumberPlayers)` | `for(i=0; <cNumberTeams)` |
| **Area name** | `"player "+i` | `"team "+i` |
| **Location function** | `rmSetAreaLocPlayer(playerID, i)` | `rmSetAreaLocTeam(teamID, i)` |
| **Size formula** | `rmAreaTilesToFraction(7000 - cNonGaia*300)` | `0.18 / cNumberTeams` |
| **Resource placement loop** | `for (i=0; <cNumberPlayers)` | `for (i=0; <cNumberTeams)` |
| **Resource amount** | Fixed (e.g., `3` mines) | Scaled (e.g., `3*rmGetNumberPlayersOnTeam(i)`) |
| **Player assignment** | `rmSetPlayerArea(i, playerID)` | Not used |
| **Best for** | FFA, small games | Team games, large games |

---

### **Choosing the Right Pattern**

**Use Player Islands when:**
- ✅ Map is designed for FFA (Free For All)
- ✅ Each player needs guaranteed personal space
- ✅ Historical accuracy requires separate territories
- ✅ Player count is low (2-4 players)

**Use Team Islands when:**
- ✅ Map is designed for team play (2v2, 3v3, 4v4)
- ✅ You want teammates to start together
- ✅ Historical scenario involves allied territories
- ✅ You want faster map generation (fewer islands)
- ✅ Following maps like Caribbean, Cook Islands pattern

---

### **Hybrid Approach (Advanced)**

Some maps use both patterns:
- **Player Islands** for starting areas
- **Bonus Team Islands** for contested resources

Example: Players spawn on individual small islands, but there's a large central team island with extra resources.

---

### **⚠️ Common Mistakes**

#### **❌ Mistake 1: Wrong loop index**
```xs
// WRONG - Player islands but team loop
for(i=0; <cNumberTeams)  // Should be cNumberPlayers!
{
    int playerID = rmCreateArea("player "+i);
    rmSetAreaLocPlayer(playerID, i);  // Won't work correctly
}
```

#### **❌ Mistake 2: Forgetting to scale resources**
```xs
// WRONG - Team islands but not scaling resources
for (i=0; <cNumberTeams)
{
    rmPlaceObjectDefInArea(silverID, 0, rmAreaID("team "+i), 3);  // Always 3!
    // Should be: 3*rmGetNumberPlayersOnTeam(i)
}
```

#### **❌ Mistake 3: Using wrong area reference**
```xs
// WRONG - Team islands but referencing "player" areas
for (i=0; <cNumberPlayers)
{
    rmPlaceObjectDefInArea(foodID, 0, rmAreaID("player "+i), 4);  // Area doesn't exist!
    // Should be: rmAreaID("team "+teamIndex)
}
```

---

### **Example: Converting Between Patterns**

**Original (Player Islands):**
```xs
for(i=1; <cNumberPlayers) {
    int playerID = rmCreateArea("player "+i);
    rmSetAreaSize(playerID, 0.08, 0.08);
    rmSetAreaLocPlayer(playerID, i);
}

for (i=0; <cNumberPlayers) {
    rmPlaceObjectDefInArea(silverID, 0, rmAreaID("player "+i), 3);
}
```

**Converted (Team Islands):**
```xs
for(i=0; <cNumberTeams) {
    int teamID = rmCreateArea("team "+i);
    rmSetAreaSize(teamID, 0.18/cNumberTeams, 0.18/cNumberTeams);
    rmSetAreaLocTeam(teamID, i);
}

for (i=0; <cNumberTeams) {
    rmPlaceObjectDefInArea(silverID, 0, rmAreaID("team "+i), 3*rmGetNumberPlayersOnTeam(i));
}
```

**Key changes:**
1. Loop index: `i=1` → `i=0` and `cNumberPlayers` → `cNumberTeams`
2. Area name: `"player"` → `"team"`
3. Location: `rmSetAreaLocPlayer()` → `rmSetAreaLocTeam()`
4. Size: Fixed fraction → Divided by team count
5. Resources: Fixed amount → Scaled by `rmGetNumberPlayersOnTeam(i)`

---

### **8. Groupings (Native Villages, City States, Decorative Structures)**

⚠️ **COORDINATE WARNING:** Grouping placement uses `rmPlaceGroupingAtLoc()` with X/Z coordinates!
- **MUST READ:** `docs/map_coordinate_system.md` before placing groupings
- Code coordinates are rotated 45° from visual minimap
- Example: To place on visual "West", use low X + high Z like `(0.15, 0.85)`

**Locations:**
- `<workspace>/game/randmaps/groupings/` (contains 100+ `.xml` files)

**Definition:** Pre-built clusters of buildings, units, terrain, and decorative objects that represent native villages, city states, pirate hideouts, etc.

**Used in maps via:** `rmCreateGrouping()` and `rmPlaceGroupingAtLoc()` or `rmPlaceGroupingInArea()`

---

#### **How to Find Groupings:**

⚠️ **CRITICAL: NEVER guess grouping filenames! Always verify the actual files exist.**

**Step 1: List all grouping files for a specific civ:**
```bash
# Windows (PowerShell/CMD)
ls game/randmaps/groupings/ | findstr -i "scientist"
ls game/randmaps/groupings/ | findstr -i "habsburg"
ls game/randmaps/groupings/ | findstr -i "pirate"

# Linux/Mac
ls game/randmaps/groupings/ | grep -i scientist
```

**Step 2: Count the variants:**
```bash
# This shows you how many variants exist (e.g., 1-6)
ls game/randmaps/groupings/scientist_lab*.xml
# Output: scientist_lab01.xml, scientist_lab02.xml, ..., scientist_lab06.xml
```

**Step 3: Use the EXACT filename (without .xml):**
```xs
// ✅ CORRECT - Verified file exists
scientistsVillageID = rmCreateGrouping("scientists", "scientist_lab0"+rmRandInt(1,6));

// ❌ WRONG - Guessed name
scientistsVillageID = rmCreateGrouping("scientists", "native scientists village "+variant);
```

---

#### **Common Naming Patterns (NOT UNIVERSAL - Always Verify!):**

⚠️ These are examples only. Actual filenames vary by civ:

- `native_<civname>_village_##.xml` - Some native villages
- `Natives_<CivName>_##.xml` - Alternative format
- `<civname>_village##.xml` - Short format (e.g., `pirate_village01.xml`)
- `<civname>_lab##.xml` - Scientists (e.g., `scientist_lab01.xml`)
- `<CivName>_CityState_##.xml` - Larger city states
- `zp<CivName>_<Variant>_##.xml` - Mod-specific (e.g., `zpHabsburg_SP_01.xml`)

**Examples of actual grouping names:**
| Civ | Grouping Files | Count |
|-----|---------------|-------|
| Habsburg (Spanish) | `zpHabsburg_SP_01.xml` to `zpHabsburg_SP_03.xml` | 3 |
| Bourbon | `Natives_SPCBourbon_01.xml` to `Natives_SPCBourbon_03.xml` | 3 |
| Pirates | `pirate_village01.xml` to `pirate_village08.xml` | 8 |
| Scientists | `scientist_lab01.xml` to `scientist_lab06.xml` | 6 |
| Venetians | Various types (port, city state, etc.) | Many |

---

#### **How to Place Groupings:**

**Basic Syntax:**
```xs
int groupingID = rmCreateGrouping("internal name", "filename_without_xml");
rmSetGroupingMinDistance(groupingID, minDistance);
rmSetGroupingMaxDistance(groupingID, maxDistance);
rmAddGroupingConstraint(groupingID, constraint1);
rmAddGroupingConstraint(groupingID, constraint2);
// ... more constraints

// Place at specific location (x, z fractions 0.0-1.0)
rmPlaceGroupingAtLoc(groupingID, playerNum, xFraction, zFraction);

// OR place in area
rmPlaceGroupingInArea(groupingID, playerNum, areaID);
```

**Example 1: Center Island Native (Fixed Location)**
```xs
// Create grouping
int centerNativeID = rmCreateGrouping("center native", "zpHabsburg_SP_01");
rmSetGroupingMinDistance(centerNativeID, 0.0);
rmSetGroupingMaxDistance(centerNativeID, 10.0);
rmAddGroupingConstraint(centerNativeID, avoidTC);
rmAddGroupingConstraint(centerNativeID, avoidImpassableLand);

// Place at specific coordinates
rmPlaceGroupingAtLoc(centerNativeID, 0, 0.5, 0.5);  // Center of map
```

**Example 2: Player Native (Near Each Player's TC)**
```xs
// Inside player loop: for(i=1; <cNumberPlayers)
vector TCLoc = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(TCID, i));

// Randomize between two native types
int nativeChoice = rmRandInt(0,1);
int playerNativeID = -1;

if (nativeChoice == 0) {
    int habsburgVar = rmRandInt(1,3);
    playerNativeID = rmCreateGrouping("player native "+i, "zpHabsburg_SP_0"+habsburgVar);
} else {
    int bourbonVar = rmRandInt(1,3);
    playerNativeID = rmCreateGrouping("player native "+i, "Natives_SPCBourbon_0"+bourbonVar);
}

rmAddGroupingToClass(playerNativeID, classNative);
rmSetGroupingMinDistance(playerNativeID, 30);
rmSetGroupingMaxDistance(playerNativeID, 50);
rmAddGroupingConstraint(playerNativeID, avoidTC);
rmAddGroupingConstraint(playerNativeID, avoidImpassableLand);
rmAddGroupingConstraint(playerNativeID, avoidNatives);

// CRITICAL: Use player 0 for native groupings!
rmPlaceGroupingAtLoc(playerNativeID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), 
                                        rmZMetersToFraction(xsVectorGetZ(TCLoc)));
```

**Example 3: Team Native (In Team Area)**
```xs
if (cNumberTeams == 2) {
    int teamNativeID = rmCreateGrouping("team 0 native", "Natives_SPCBourbon_02");
    rmAddGroupingConstraint(teamNativeID, avoidTC);
    rmAddGroupingConstraint(teamNativeID, avoidCW);
    rmAddGroupingConstraint(teamNativeID, avoidImpassableLand);
    
    // Place in team area (player 0 owns it)
    rmPlaceGroupingInArea(teamNativeID, 0, rmAreaID("team 0"));
}
```

---

#### **⚠️ CRITICAL RULES:**

1. **Player Ownership:**
   - **Native villages are ALWAYS player 0 (Gaia/neutral)** unless explicitly specified otherwise
   - Use `rmPlaceGroupingAtLoc(groupingID, 0, x, z)` - note the `0`!
   - Natives are neutral entities that players ally with, not owned by players

2. **Unique Internal Names:**
   - Each grouping needs a unique internal name: `"player native "+i` (not just `"player native"`)

3. **Filename Format:**
   - Use filename WITHOUT `.xml` extension: `"pirate_village01"` (not `"pirate_village01.xml"`)
   - ⚠️ **ALWAYS verify the file exists** in `game/randmaps/groupings/` before using it
   - Use `ls` or `findstr`/`grep` to search for the exact filename

4. **Distance Settings:**
   - For fixed locations (center island): `minDistance = 0.0`, `maxDistance = 10.0`
   - For player-relative placement: `minDistance = 30`, `maxDistance = 50`

5. **Constraints:**
   - Always add `avoidTC`, `avoidImpassableLand`, `avoidNatives` (or `avoidNativesMed`)
   - For coastal placement: Add terrain distance constraints (see Pirate Placement below)

---

#### **Pirate Placement (Coastal Natives)**

⚠️ **Special rules for coastal placement**

These subcivs need special grouping placement next to a water:
- NatPirates
- Wokou
- zpScientists (if it's not explicitely defined the map will use "Land Scientists" -> land scientist should then not be placed next to a water)
- zpVenetians
- zpHansaKontor

##### Ferry on shore constraint
- For correct placement the coastal (naval) natives need to use a special constraint which can look like this:

int ferryOnShore = rmCreateTerrainMaxDistanceConstraint("ferry v. water", "water", true, 22.0); // Object / grouping placed not far from the shore

##### Controllers
- are special invisible objects defining the area where the coastal natives get spawned. Controller is usually spawned before the grouping

```xs
int controllerID1 = rmCreateObjectDef("Controler 1");
   rmAddObjectDefItem(controllerID1, "zpSPCWaterSpawnPoint", 1, 0.0);
   rmSetObjectDefMinDistance(controllerID1, 0.0);
   rmSetObjectDefMaxDistance(controllerID1, 30.0);
   rmAddObjectDefConstraint(controllerID1, avoidImpassableLand);
   rmAddObjectDefConstraint(controllerID1, ferryOnShore); 
   rmPlaceObjectDefAtLoc(controllerID1, 0, 0.15, 0.65); // location is defined as an aproximate shore location in the RM grid based on the island shape, location and size
```

vector ControllerLoc1 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(controllerID1, 0));

##### Examples for of placement:

1/ Simple coastal placement

```xs
// Pirate Village 1
int piratesVillageID = -1;
int piratesVillageType = rmRandInt(1,2);
   piratesVillageID = rmCreateGrouping("pirate city 1", "pirate_village01");
   rmAddGroupingToClass(piratesVillageID, rmClassID("natives"));
   rmAddGroupingToClass(piratesVillageID, rmClassID("pirates"));
   rmSetGroupingMinDistance(piratesVillageID, 0);
   rmSetGroupingMaxDistance(piratesVillageID, 22);
   rmAddGroupingConstraint(piratesVillageID, avoidEdge);
   rmAddGroupingConstraint(piratesVillageID, ferryOnShore);

   rmPlaceGroupingAtLoc(piratesVillageID, 0, rmXMetersToFraction(xsVectorGetX(ControllerLoc1)), rmZMetersToFraction(xsVectorGetZ(ControllerLoc1)), 1);
```

2/ Fixed placement with an island underneath the settlement

```xs
int controllerID1 = rmCreateObjectDef("Controler 1");
   rmAddObjectDefItem(controllerID1, "zpSPCWaterSpawnPoint", 1, 0.0);
   rmPlaceObjectDefAtLoc(controllerID1, 0, 0.15, 0.27); // in this case controller doesn't need any constraints, because we'll use a special small island beneath the settlement grouping
   vector ControllerLoc1 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(controllerID1, 0));

int pirateSite1 = rmCreateArea ("pirate_site1"); // Creates an area beneath the settlement
   rmSetAreaSize(pirateSite1, rmAreaTilesToFraction(600.0), rmAreaTilesToFraction(600.0));
   rmSetAreaLocation(pirateSite1, rmXMetersToFraction(xsVectorGetX(ControllerLoc1)), rmZMetersToFraction(xsVectorGetZ(ControllerLoc1)));
   rmSetAreaMix(pirateSite1, "africa desert sand");
   rmSetAreaCoherence(pirateSite1, 1);
   rmSetAreaSmoothDistance(pirateSite1, 15);
   rmSetAreaBaseHeight(pirateSite1, 2.0);
   rmAddAreaToClass(pirateSite1, classBonusIsland);
   rmBuildArea(pirateSite1);

int piratesVillageID = -1;
   piratesVillageID = rmCreateGrouping("pirate city", "pirate_village03");      
   rmPlaceGroupingAtLoc(piratesVillageID, 0, rmXMetersToFraction(xsVectorGetX(ControllerLoc1)), rmZMetersToFraction(xsVectorGetZ(ControllerLoc1)), 1);
```

#### Water Flag Placement
- All coastal natives (if not explicitly defined otherwise) need a water flag placed in the water next to the settlement

##### **Native-Specific Water Flags:**

⚠️ **CRITICAL: Use the correct water flag for each coastal native civ!**

| Native Civ | Water Flag ProtoUnits | Notes |
|------------|----------------------|-------|
| **Pirates** (`NatPirates`) | `zpPirateWaterSpawnFlag1`, `zpPirateWaterSpawnFlag2` | 2 variants available |
| **Wokou** | `zpWokouWaterSpawnFlag1`, `zpWokouWaterSpawnFlag2` | 2 variants available |
| **Scientists** (`zpScientists`) | `zpNativeWaterSpawnFlag1`, `zpNativeWaterSpawnFlag2` | Generic native flags |
| **Venetians** (`zpVenetians`) | `zpVenetianWaterSpawnFlag1` to `zpVenetianWaterSpawnFlag4` | 4 variants available |
| **Hansa** (`zpHansaKontor`) | `zpHansaWaterSpawnFlag1`, `zpHansaWaterSpawnFlag2` | 2 variants available |

##### **How to Find Water Flags for Other Coastal Natives:**

If a coastal native is not in the list above:

1. **Search `data/protomods.xml` for the civ's water flag:**
   ```bash
   # Windows
   findstr /i "WaterSpawnFlag" data/protomods.xml | findstr /i "cossack"
   
   # Linux/Mac
   grep -i "WaterSpawnFlag" data/protomods.xml | grep -i cossack
   ```

2. **Look for pattern:** `zp<CivName>WaterSpawnFlag1`

3. **If no civ-specific flag exists:**
   - Use generic: `zpNativeWaterSpawnFlag1` or `zpNativeWaterSpawnFlag2`
   - Or use placeholder: `HomeCityWaterSpawnFlag` (base game flag)

##### **Example Water Flag Placement:**

```xs
int piratewaterflagID1 = rmCreateObjectDef("pirate water flag 1");
   rmAddObjectDefItem(piratewaterflagID1, "zpPirateWaterSpawnFlag1", 1, 1.0);
   rmAddObjectDefToClass(piratewaterflagID1, rmClassID("pirates"));
   rmAddClosestPointConstraint(flagLandShort);
   rmAddClosestPointConstraint(avoidEdge);
   vector closeToVillage1 = rmFindClosestPointVector(ControllerLoc1, rmXFractionToMeters(1.0));
   rmPlaceObjectDefAtLoc(piratewaterflagID1, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage1)), rmZMetersToFraction(xsVectorGetZ(closeToVillage1)));

   rmClearClosestPointConstraints();
```

**⚠️ Water Flag Selection Guidelines:**
- Always use civ-specific flags when available (e.g., `zpPirateWaterSpawnFlag1` for pirates)
- Use `zpNativeWaterSpawnFlag1` as generic fallback for coastal natives
- Each coastal native typically has 2 flag variants (some have more, like Venetians with 4)
- Flags are defined as ProtoUnits in `data/protomods.xml`
- Search protomods.xml to verify flag existence before using



---

## 📝 Practical Usage Examples

⚠️ **REMINDER:** Before placing objects with coordinates, review `docs/map_coordinate_system.md`!
- Code coordinates are rotated 45° from visual display
- When examples show `(0.15, 0.85)`, understand this is low X + high Z = visual West

---

### **Water Types - Three Use Cases:**

#### **A) Base Ocean/Sea (Map-wide water)**
```xs
// Set the water type for the entire map
rmSetSeaType("Caribbean Coast");

// Initialize the base terrain as water
rmTerrainInitialize("water");
```

#### **B) Lake (Water area within land)**
```xs
// Create a water area (simplified example)
int basinsID = rmCreateArea("Verseilles Basins");
rmSetAreaWaterType(basinsID, "ZP Verseilles Pond");
rmBuildArea(basinsID);
```

#### **C) River (Flowing water connection)**
```xs
// Create a river with waypoints
int riverID = rmRiverCreate(-1, "ZP Hansa Baltic Lake", 4, 4, 39, 39);
rmRiverAddWaypoint(riverID, 0.3, 0.65);
rmRiverAddWaypoint(riverID, 0.7, 0.65);
rmRiverBuild(riverID);
```

---

### **Terrain Types - Two Use Cases:**

#### **A) Base Terrain (Map-wide ground)**
```xs
// Set a specific terrain type for the entire map base
rmTerrainInitialize("nwterritory\ground_grass2_nwt", 1.0);
```

#### **B) Area-Specific Terrain**
```xs
// Paint a specific area with a terrain type
int streetsSouth = rmCreateArea("streets South");
rmSetAreaSize(streetsSouth, 0.7, 0.7);
rmSetAreaLocation(streetsSouth, 0.2, 0.5);
rmSetAreaTerrainType(streetsSouth, "city\ground1_cob_dark");
rmBuildArea(streetsSouth);
```

---

### **Terrain Mixes - Two Use Cases:**

#### **A) Base Terrain Mix (Map-wide blended terrain)**
```xs
// Set a terrain mix for the base map
rmSetBaseTerrainMix("nwt_grass1");  // ⚠️ Use exact filename (underscores!)
```
**⚠️ CRITICAL:** Always use the exact filename from `mix/` folder without .xml
- File: `italy_grass.xml` → Use: `"italy_grass"` ✅
- **NOT:** `"italy grass"` ❌ (will crash!)

#### **B) Area-Specific Terrain Mix**
```xs
// Apply a terrain mix to a specific area
int countrysideNorth = rmCreateArea("countryside N");
rmSetAreaSize(countrysideNorth, 0.6, 0.6);
rmSetAreaLocation(countrysideNorth, 0.8, 0.5);
rmSetAreaMix(countrysideNorth, "nwt_grass1");
rmBuildArea(countrysideNorth);
```

#### **C) Terrain Patches (Simple Method)**

**Best for:** Creating scattered terrain variation across islands/landmasses

**Use `rmSetAreaMix()` for simple, effective patches** - much simpler than complex blob settings!

```xs
// Example: Mediterranean terrain patches (from Black Sea / Balearic Islands)

// Greener patches (scattered grass areas)
for (i=0; < 20+cNumberNonGaiaPlayers*50) {
	int patchGreen = rmCreateArea("green patch "+i);
	rmSetAreaWarnFailure(patchGreen, false);
	rmSetAreaSize(patchGreen, rmAreaTilesToFraction(37), rmAreaTilesToFraction(42));
	rmSetAreaMix(patchGreen, "italy_grass");  // Use terrain mix name
	rmSetAreaSmoothDistance(patchGreen, 1.0);
	rmAddAreaConstraint(patchGreen, avoidWater4);  // Keep on land
	rmBuildArea(patchGreen); 
}

// Dry dirt patches (more numerous for arid look)
for (i=0; < 100+cNumberNonGaiaPlayers*30) {
	int patchDry = rmCreateArea("dry patch "+i);
	rmSetAreaWarnFailure(patchDry, false);
	rmSetAreaSize(patchDry, rmAreaTilesToFraction(37), rmAreaTilesToFraction(42));
	rmSetAreaMix(patchDry, "italy_dirt");  // Drier mix
	rmSetAreaSmoothDistance(patchDry, 1.0);
	rmAddAreaConstraint(patchDry, avoidWater4);
	rmBuildArea(patchDry); 
}
```

**Key points:**
- ✅ **Simple formula:** `20-100 + cNumberNonGaiaPlayers * 30-50` patches
- ✅ **Small size:** `rmAreaTilesToFraction(37)` to `(42)` - creates natural small patches
- ✅ **Use `rmSetAreaMix()`** not `rmSetAreaTerrainType()` - works better for patches
- ✅ **Smooth distance: 1.0** - blends edges nicely
- ✅ **Always constrain:** Use `avoidWater4` to keep patches on land (or `avoidNatives` if needed)
- ⚠️ **No complex blobs needed** - simple is better for scattered patches!

**How it works:**
1. Creates many small areas (37-42 tiles each)
2. Each area gets a terrain mix applied
3. Smooth distance blends the edges
4. Loop creates natural randomized distribution
5. More patches = more variation

**Common mistakes to avoid:**
- ❌ Don't use `rmSetAreaTerrainType()` for patches - use `rmSetAreaMix()`
- ❌ Don't add complex blob/coherence settings - keep it simple
- ❌ Don't forget water constraint - patches will spawn in ocean!
- ❌ Don't use too few patches - map looks monotonous

---

## 🏔️ **Cliff Patterns: Simple vs Manual Ramps**

There are two main approaches to creating cliffs with accessible ramps. Each has distinct advantages.

---

### **🔹 Method 1: Simple (Automatic Ramps)**

**Best for:** Quick cliff setup, natural-looking random ramp placement, when you don't need precise ramp locations

**Uses `rmSetAreaCliffEdge()` to automatically generate ramps** around the cliff perimeter.

```xs
// Example: Central cliff with 3 automatic ramps (Balearic Islands - first version)
int centerCliffID = rmCreateArea("center cliff");
rmSetAreaSize(centerCliffID, 0.01, 0.012);
rmSetAreaLocation(centerCliffID, 0.5, 0.5);
rmSetAreaCliffType(centerCliffID, "Mediterranean");
rmSetAreaCliffEdge(centerCliffID, 3, 0.25, 0.05, 0.6, 0);
//                                 │    │     │     │    └─ 0 = automatic placement
//                                 │    │     │     └────── spacing between ramps (0.6)
//                                 │    │     └──────────── variance in size (0.05)
//                                 │    └────────────────── size of each ramp (0.25 = 25%)
//                                 └─────────────────────── number of ramps (3)
rmSetAreaCliffHeight(centerCliffID, 4.0, 0.0, 0.5);
rmSetAreaBaseHeight(centerCliffID, 2.0);
rmSetAreaCoherence(centerCliffID, 0.7);
rmSetAreaSmoothDistance(centerCliffID, 10);
rmSetAreaHeightBlend(centerCliffID, 2);
rmBuildArea(centerCliffID);
```

**Parameters for `rmSetAreaCliffEdge(areaID, count, size, variance, spacing, mapEdge)`:**
- **count:** Number of ramps to generate
- **size:** Percentage of perimeter each ramp covers (0.0-1.0)
  - 0.25 = 25% (3 ramps × 25% = 75% ramps, 25% solid cliff)
  - 1.0 = 100% (completely surrounded, no ramps)
- **variance:** Random variation in ramp sizes (0.0-1.0)
- **spacing:** Distance between ramps (0.0-1.0)
- **mapEdge:** 0 = automatic, 1 = snap to map edge

**Advantages:**
- ✅ Very simple - just one function call
- ✅ Automatic random distribution
- ✅ Natural-looking placement
- ✅ Less code to maintain

**Disadvantages:**
- ❌ Can't control exact ramp locations
- ❌ Ramps might appear under buildings/groupings
- ❌ Uneven terrain on cliff top (elevation variation)

---

### **🔹 Method 2: Manual (Controlled Ramps)**

**Best for:** Precise ramp placement, flat cliff tops for buildings, strategic gameplay design

**Uses a controller + manually placed ramp areas BEFORE building the main cliff.**

```xs
// Example: Central cliff with manually placed north/south ramps (Balearic Islands - Burma style)

// 1. Place controller to get exact coordinates
int cliffControllerID = rmCreateObjectDef("cliff controller");
rmAddObjectDefItem(cliffControllerID, "zpSPCWaterSpawnPoint", 1, 0.0);
rmPlaceObjectDefAtLoc(cliffControllerID, 0, 0.5, 0.5);
vector cliffControllerLoc = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(cliffControllerID, 0));

// 2. Build south ramp FIRST (before cliff)
int southRampID = rmCreateArea("south ramp");
rmSetAreaSize(southRampID, rmAreaTilesToFraction(250.0), rmAreaTilesToFraction(250.0));
rmSetAreaLocation(southRampID, rmXMetersToFraction(xsVectorGetX(cliffControllerLoc)), 
                                rmZMetersToFraction(xsVectorGetZ(cliffControllerLoc)-35));  // 35m south
rmSetAreaBaseHeight(southRampID, 5.0);  // Slopes up to cliff height
rmSetAreaCoherence(southRampID, 0.8);
rmSetAreaMix(southRampID, baseMix);
rmSetAreaSmoothDistance(southRampID, 30);  // Smooth transition
rmBuildArea(southRampID);

// 3. Build north ramp FIRST (before cliff)
int northRampID = rmCreateArea("north ramp");
rmSetAreaSize(northRampID, rmAreaTilesToFraction(250.0), rmAreaTilesToFraction(250.0));
rmSetAreaLocation(northRampID, rmXMetersToFraction(xsVectorGetX(cliffControllerLoc)), 
                                rmZMetersToFraction(xsVectorGetZ(cliffControllerLoc)+35));  // 35m north
rmSetAreaBaseHeight(northRampID, 5.0);
rmSetAreaCoherence(northRampID, 0.8);
rmSetAreaMix(northRampID, baseMix);
rmSetAreaSmoothDistance(northRampID, 30);
rmBuildArea(northRampID);

// 4. NOW build main cliff (completely surrounded, no auto-ramps)
int centerCliffID = rmCreateArea("center cliff");
rmSetAreaSize(centerCliffID, rmAreaTilesToFraction(600.0), rmAreaTilesToFraction(600.0));
rmSetAreaLocation(centerCliffID, rmXMetersToFraction(xsVectorGetX(cliffControllerLoc)), 
                                 rmZMetersToFraction(xsVectorGetZ(cliffControllerLoc)));
rmSetAreaCoherence(centerCliffID, 0.9);
rmSetAreaSmoothDistance(centerCliffID, 5);
rmSetAreaCliffType(centerCliffID, "Mediterranean");
rmSetAreaCliffEdge(centerCliffID, 1, 1.0, 0.0, 1.0, 0);  // 1.0 = 100% surrounded, NO auto-ramps
rmSetAreaCliffHeight(centerCliffID, 1.0, 0.0, 0.5);
rmSetAreaBaseHeight(centerCliffID, 4.0);
rmSetAreaElevationVariation(centerCliffID, 0.0);  // FLAT top!
rmBuildArea(centerCliffID);

// 5. Place buildings on flat cliff top using controller location
int monasteryID = rmCreateGrouping("cliff monastery", "Jesuit_Cathedral_EU_02");
rmPlaceGroupingAtLoc(monasteryID, 0, rmXMetersToFraction(xsVectorGetX(cliffControllerLoc)), 
                                     rmZMetersToFraction(xsVectorGetZ(cliffControllerLoc)));
```

**Key Technical Details:**
1. **Controller:** Invisible object that gives exact coordinates
   - Uses `zpSPCWaterSpawnPoint` (invisible, doesn't affect gameplay)
   - Placed first, coordinates captured with `rmGetUnitPosition()`

2. **Ramp Placement:** Build ramps BEFORE cliff
   - Offset from controller: ±35 meters in desired direction
   - Height matches cliff base height (5.0 for ramps → 4.0-5.0 for cliff)
   - Smooth distance (30) creates gentle slope

3. **Cliff Edge:** `rmSetAreaCliffEdge(centerCliffID, 1, 1.0, 0.0, 1.0, 0)`
   - Size = 1.0 means 100% surrounded by cliffs
   - NO automatic ramps generated

4. **Flat Top:** `rmSetAreaElevationVariation(centerCliffID, 0.0)`
   - Zero variation = perfectly flat
   - Buildings won't have uneven ground underneath

**Advantages:**
- ✅ Exact control over ramp locations
- ✅ Flat cliff top for buildings
- ✅ Ramps never interfere with structures
- ✅ Strategic placement (north/south for balance)
- ✅ Professional, polished appearance

**Disadvantages:**
- ❌ More complex code
- ❌ Requires controller setup
- ❌ More manual work for each ramp

---

### **📊 Comparison Table**

| Feature | Simple (Auto-Ramps) | Manual (Controlled) |
|---------|---------------------|---------------------|
| **Code Complexity** | Very low | Medium |
| **Ramp Placement** | Random | Precise |
| **Cliff Top Terrain** | Uneven (variation) | Flat (0.0 variation) |
| **Building-Safe** | ❌ No guarantee | ✅ Yes |
| **Strategic Control** | ❌ Limited | ✅ Full control |
| **Setup Time** | ⚡ Fast | 🐢 Slower |
| **Best Use** | Decorative cliffs | Gameplay cliffs |

---

### **🎯 When to Use Each Method:**

**Use Simple (Auto-Ramps) when:**
- Creating decorative cliffs
- Don't need buildings on top
- Want natural, random appearance
- Working quickly on draft maps

**Use Manual (Controlled) when:**
- Placing buildings on cliff top (natives, monasteries, forts)
- Need strategic symmetry (team maps)
- Want professional polish
- Cliff is a key gameplay feature

---

### **⚠️ Common Mistakes:**

1. **Simple Method:**
   - ❌ Placing buildings before checking ramp locations
   - ❌ Using size = 1.0 thinking it creates 1 ramp (it creates 0 ramps!)
   - ❌ Forgetting to set elevation variation (buildings look bad)

2. **Manual Method:**
   - ❌ Building cliff BEFORE ramps (ramps won't work!)
   - ❌ Ramp height doesn't match cliff base height
   - ❌ Not setting elevation variation to 0.0 (uneven top)
   - ❌ Placing buildings at 0.5, 0.5 instead of controller location

---

### **Basic Cliff Setup (No Ramps):**

```xs
// Create a cliff/fjord area
int cliffID = rmCreateArea("cliff");
rmSetAreaSize(cliffID, 0.06);
rmSetAreaCliffType(cliffID, "ZP Iceland Fjord");

// Configure cliff appearance
rmSetAreaCliffPainting(cliffID, false, true, false, 0.5, false);
// Parameters: paintGround, paintOutsideEdge, paintSide, minSideHeight, paintInsideEdge
rmSetAreaCliffHeight(cliffID, 7, 0.0, 0.8);
rmSetAreaCliffEdge(cliffID, 1, 1.00, 0.0, 0.30, 0);
rmAddAreaCliffEdgeAvoidClass(cliffID, classAvoidance, 20);

// Place the cliff
rmSetAreaLocation(cliffID, cliffXLoc1, cliffYLoc1);
rmBuildArea(cliffID);
```

---

### **Forest Types - Area Usage:**

```xs
// Create a forest area
int forestID = rmCreateArea("main forest");
rmSetAreaSize(forestID, 0.10);  // 10% of map
rmSetAreaForestType(forestID, "Italian Forest");  // Mediterranean trees

// Configure forest density
rmSetAreaForestDensity(forestID, 0.7);  // 0.0 to 1.0
rmSetAreaForestClumpiness(forestID, 0.5);  // How clustered

// Position and build
rmSetAreaCoherence(forestID, 0.4);
rmSetAreaLocation(forestID, forestXLoc, forestYLoc);
rmBuildArea(forestID);

// Example: Multiple small forest patches
for(i=0; <numberPatches)
{
   int smallForest = rmCreateArea("forest patch "+i);
   rmSetAreaSize(smallForest, rmAreaTilesToFraction(60));
   rmSetAreaForestType(smallForest, "z31 Mediterranean Coastal Forest");
   rmSetAreaForestDensity(smallForest, 0.5);
   rmSetAreaForestClumpiness(smallForest, 0.9);  // Very clustered
   rmSetAreaCoherence(smallForest, 0.6);
   rmSetAreaLocation(smallForest, rmRandFloat(0.0, 1.0), rmRandFloat(0.0, 1.0));
   rmBuildArea(smallForest);
}
```

---

### **Variable Organization (Best Practice):**

**⚠️ ALWAYS define type names as variables at the top of the `.xs` file!**

This makes it easy to change themes and maintain consistency.

#### **Example from `zpIceland.xs`:**

```xs
// WATER TYPES
string wetTypeSea = "ZP Iceland";
string wetTypeLake = "ZP Iceland Lake";

// TERRAIN TYPES
string volcTerrainLow = "lava\volcano_snow";
string volcTerrainHigh = "lava\volcano_dirt";
string volcTerrainCrater = "lava\crater";

// TERRAIN MIXES
string paintMix0 = "great_lakes_ice";
string paintMix1 = "rockies_snowa";
string paintMix2 = "italy_snow_grass";
string paintMix3 = "italy_snow";
string paintMix4 = "araucania_snow_b";
string paintMix5 = "italy_snow_cliff";
string paintMix6 = "italy_snow_forest";
string paintMix7 = "rockies_snow_forest";
string paintMix8 = "araucania_snow_a";

// CLIFF TYPES
string volcCliffLow = "ZP Iceland Low";
string volcCliffMid = "ZP Iceland Medium";
string volcCliffHigh = "ZP Iceland High";
string volcCliffCrater = "ZP Hawaii Crater";
```

**Then use variables throughout the script:**
```xs
rmSetSeaType(wetTypeSea);  // Instead of hardcoded "ZP Iceland"
rmSetAreaMix(someArea, paintMix2);  // Instead of "italy_snow_grass"
rmSetAreaCliffType(cliffArea, volcCliffLow);  // Instead of "ZP Iceland Low"
```

**Benefits:**
- ✅ Change entire map theme by editing one place
- ✅ Easy to spot which resources are used
- ✅ Prevents typos in hardcoded strings
- ✅ Clear documentation of map dependencies

---

## ⚓ **Trade Socket Placement Patterns**

Trade routes require sockets to enable trade. There are three main approaches to placing sockets, each with different levels of control and visual polish.

---

### **🔹 Pattern 1: Simple Sockets (Basic)**

**Best for:** Quick implementation, simple maps, when terrain around trade route is already suitable

**Directly places sockets on trade route waypoints without terrain modification.**

```xs
// Example: Basic socket placement (zpphilippines.xs)
int numSockets = 8;
for (i = 0; < numSockets) {
   // Define waypoint position for this socket
   int waypointPos = 0;
   if (i == 0) waypointPos = socketWaypoint0;
   else if (i == 1) waypointPos = socketWaypoint1;
   // ... etc for all sockets
   
   // Place socket directly on trade route
   int socketID = rmCreateObjectDef("socket "+i);
   rmAddObjectDefItem(socketID, "SocketTradeRoute", 1, 0.0);
   rmSetObjectDefTradeRouteID(socketID, tradeRouteID);
   rmPlaceObjectDefAtLoc(socketID, 0, 0, 0, socketWaypoint);
   
   rmEchoInfo("Socket "+i+" placed at waypoint "+waypointPos);
}
```

**Key Points:**
- Uses `rmPlaceObjectDefAtLoc(socketID, 0, 0, 0, waypointIndex)` with waypoint parameter
- `rmSetObjectDefTradeRouteID()` links socket to specific trade route
- No terrain modification or platform creation
- Socket inherits elevation from existing terrain at waypoint

**Advantages:**
- ✅ Simplest implementation (fewest lines of code)
- ✅ Fast execution
- ✅ Works well on flat terrain
- ✅ No offset calculations needed

**Disadvantages:**
- ❌ Sockets may spawn in water if waypoint is near coastline
- ❌ No control over socket surroundings
- ❌ Can fail if terrain is unsuitable
- ❌ No visual enhancement (docks, platforms, etc.)

---

### **🔹 Pattern 2: Sockets on Platforms (Reliable)**

**Best for:** Naval/island maps, ensuring sockets always have land, preventing placement failures

**Creates guaranteed land platforms beneath sockets by calculating positions and offsetting toward map center.**

```xs
// Example: Socket placement with platforms (Balearic Islands - non-4-player)
int numSockets = 8;
for (i = 0; < numSockets) {
   int waypointPos = 0;
   if (i == 0) waypointPos = socketWaypoint0;
   else if (i == 1) waypointPos = socketWaypoint1;
   // ... etc
   
   // Get socket location from trade route waypoint
   vector socketLoc = rmGetTradeRouteWayPoint(tradeRouteID, waypointPos);
   
   // Calculate offset toward map center (0.5, 0.5)
   float socketX = xsVectorGetX(socketLoc);
   float socketZ = xsVectorGetZ(socketLoc);
   float centerX = rmXFractionToMeters(0.5);
   float centerZ = rmZFractionToMeters(0.5);
   
   // Direction vector toward center
   float dirX = centerX - socketX;
   float dirZ = centerZ - socketZ;
   
   // Normalize direction
   float distance = sqrt(dirX*dirX + dirZ*dirZ);
   
   // Calculate offset distance (35m toward center)
   float offsetDistance = 35.0;
   float offsetX = (dirX / distance) * offsetDistance;
   float offsetZ = (dirZ / distance) * offsetDistance;
   float platformX = socketX + offsetX;
   float platformZ = socketZ + offsetZ;
   
   // Create platform area offset toward center (guarantees land base)
   int socketPlatformID = rmCreateArea("socket platform "+i);
   rmSetAreaSize(socketPlatformID, rmAreaTilesToFraction(400.0), rmAreaTilesToFraction(400.0));
   rmSetAreaLocation(socketPlatformID, rmXMetersToFraction(platformX), rmZMetersToFraction(platformZ));
   rmSetAreaMix(socketPlatformID, baseMix);
   rmSetAreaCoherence(socketPlatformID, 1.0);
   rmSetAreaSmoothDistance(socketPlatformID, 15);
   rmSetAreaBaseHeight(socketPlatformID, 2.2);
   rmSetAreaWarnFailure(socketPlatformID, false);
   rmBuildArea(socketPlatformID);
   
   // Place socket at platform location
   int socketID = rmCreateObjectDef("socket "+i);
   rmAddObjectDefItem(socketID, "SocketTradeRoute", 1, 0.0);
   rmAddObjectDefConstraint(socketID, avoidWater4);
   rmSetObjectDefTradeRouteID(socketID, tradeRouteID);
   rmPlaceObjectDefAtLoc(socketID, 0, rmXMetersToFraction(platformX), rmZMetersToFraction(platformZ));
   
   rmEchoInfo("Socket "+i+" placed at waypoint "+waypointPos+" on platform");
}
```

**Key Technical Details:**
1. **Vector Math:** Get exact waypoint coordinates using `rmGetTradeRouteWayPoint()`
2. **Direction Calculation:** Vector from socket to map center (0.5, 0.5)
3. **Normalization:** `distance = sqrt(dirX*dirX + dirZ*dirZ)` to get unit vector
4. **Offset:** Move socket inland by fixed distance (35m typical)
5. **Platform:** Create raised land area (height 2.2) beneath socket
6. **Placement:** Use `rmXMetersToFraction()` to convert meters to fraction coordinates

**Advantages:**
- ✅ Guarantees sockets on land (never in water)
- ✅ Consistent offset distance from coast
- ✅ Works on any map size
- ✅ Reliable placement success rate
- ✅ Creates small docks/platforms visually

**Disadvantages:**
- ❌ More complex code (vector math required)
- ❌ Fixed offset may not suit all maps
- ❌ Platform may look artificial on some terrain
- ❌ No directional awareness (sockets face random directions)

---

### **🔹 Pattern 3: Harbour Groupings on Platforms (Visual Polish)**

**Best for:** Specific player counts (e.g., 4-player), maps with strategic symmetry, maximum visual quality

**Combines platform creation with pre-built harbour groupings that orient correctly toward water.**

```xs
// Example: Harbour grouping placement (Balearic Islands - 4-player only)
int numSockets = 4;  // Works best with 4 sockets (diagonal positions)
for (i = 0; < numSockets) {
   int waypointPos = 0;
   if (i == 0) waypointPos = socketWaypoint0;
   // ... etc
   
   // Get socket location from trade route waypoint
   vector socketLoc = rmGetTradeRouteWayPoint(tradeRouteID, waypointPos);
   
   // Calculate offset toward map center
   float socketX = xsVectorGetX(socketLoc);
   float socketZ = xsVectorGetZ(socketLoc);
   float centerX = rmXFractionToMeters(0.5);
   float centerZ = rmZFractionToMeters(0.5);
   
   // Direction vector toward center
   float dirX = centerX - socketX;
   float dirZ = centerZ - socketZ;
   float distance = sqrt(dirX*dirX + dirZ*dirZ);
   
   // Calculate platform offset distance (35m toward center for land guarantee)
   float platformOffsetDistance = 35.0;
   float platformOffsetX = (dirX / distance) * platformOffsetDistance;
   float platformOffsetZ = (dirZ / distance) * platformOffsetDistance;
   float platformX = socketX + platformOffsetX;
   float platformZ = socketZ + platformOffsetZ;
   
   // Create platform area offset toward center
   int socketPlatformID = rmCreateArea("socket platform "+i);
   rmSetAreaSize(socketPlatformID, rmAreaTilesToFraction(400.0), rmAreaTilesToFraction(400.0));
   rmSetAreaLocation(socketPlatformID, rmXMetersToFraction(platformX), rmZMetersToFraction(platformZ));
   rmSetAreaMix(socketPlatformID, baseMix);
   rmSetAreaCoherence(socketPlatformID, 1.0);
   rmSetAreaSmoothDistance(socketPlatformID, 15);
   rmSetAreaBaseHeight(socketPlatformID, 2.2);
   rmSetAreaWarnFailure(socketPlatformID, false);
   rmBuildArea(socketPlatformID);
   
   // For 4-player games, use harbour groupings
   if (cNumberNonGaiaPlayers == 4) {
      // Calculate harbour offset (closer to water for groupings)
      float harbourOffsetDistance = 18.0;  // Closer to water than platform
      float harbourOffsetX = (dirX / distance) * harbourOffsetDistance;
      float harbourOffsetZ = (dirZ / distance) * harbourOffsetDistance;
      float harbourX = socketX + harbourOffsetX;
      float harbourZ = socketZ + harbourOffsetZ;
      
      // Determine which harbour grouping to use based on direction
      // IMPORTANT: Account for 45° coordinate rotation (see map_coordinate_system.md)
      float dirToSocketX = socketX - centerX;  // Direction FROM center TO socket
      float dirToSocketZ = socketZ - centerZ;
      int harbourGroupingID = -1;
      
      // Use diagonal groupings for 4-player circular layout
      // Code diagonals (NE/SE/SW/NW) map to visual cardinals (N/E/S/W)
      if ((dirToSocketX > 0) && (dirToSocketZ > 0)) {
         harbourGroupingID = rmCreateGrouping("harbour "+i, "Harbour_Universal_N");
         rmEchoInfo("Harbour "+i+" using N orientation");
      }
      else if ((dirToSocketX < 0) && (dirToSocketZ > 0)) {
         harbourGroupingID = rmCreateGrouping("harbour "+i, "Harbour_Universal_W");
         rmEchoInfo("Harbour "+i+" using W orientation");
      }
      else if ((dirToSocketX > 0) && (dirToSocketZ < 0)) {
         harbourGroupingID = rmCreateGrouping("harbour "+i, "Harbour_Universal_E");
         rmEchoInfo("Harbour "+i+" using E orientation");
      }
      else if ((dirToSocketX < 0) && (dirToSocketZ < 0)) {
         harbourGroupingID = rmCreateGrouping("harbour "+i, "Harbour_Universal_S");
         rmEchoInfo("Harbour "+i+" using S orientation");
      }
      else {
         harbourGroupingID = rmCreateGrouping("harbour "+i, "Harbour_Universal_S");
         rmEchoInfo("Harbour "+i+" using S orientation (fallback)");
      }
      
      // Place harbour grouping closer to water
      rmSetGroupingMinDistance(harbourGroupingID, 0.0);
      rmSetGroupingMaxDistance(harbourGroupingID, 0.0);
      rmPlaceGroupingAtLoc(harbourGroupingID, 0, rmXMetersToFraction(harbourX), rmZMetersToFraction(harbourZ));
      
      rmEchoInfo("Harbour "+i+" placed (platform at 35m, harbour at 18m)");
   }
}
```

**Key Technical Details:**
1. **Two-Layer Offset:**
   - Platform at 35m (guarantees land)
   - Grouping at 18m (closer to water for visual effect)
2. **Direction Detection:**
   - Calculate direction FROM center TO socket
   - Use quadrant logic to determine orientation
3. **Coordinate System:**
   - Must account for 45° rotation (see `map_coordinate_system.md`)
   - Code diagonals (X+,Z+) → Visual cardinals (North)
4. **Grouping Requirements:**
   - Need 8 directional groupings (N/NE/E/SE/S/SW/W/NW) OR
   - 4 cardinal groupings (N/E/S/W) for 4-player maps

**Advantages:**
- ✅ Professional visual appearance (docks, buildings, ships)
- ✅ Directionally correct (faces water)
- ✅ Gameplay enhancement (garrison points, cover)
- ✅ Highly polished for specific player counts
- ✅ Can include defensive structures

**Disadvantages:**
- ❌ Most complex implementation
- ❌ Requires custom grouping files for each direction
- ❌ Only works reliably for specific player counts (4-player ideal)
- ❌ Direction detection can fail on complex shapes
- ❌ Groupings may spawn incorrectly if orientation logic is wrong

---

### **📊 Comparison Table**

| Feature | Simple Sockets | Sockets on Platforms | Harbour Groupings |
|---------|----------------|----------------------|-------------------|
| **Code Complexity** | Very low | Medium | High |
| **Placement Reliability** | ❌ Moderate | ✅ High | ⚠️ Player-count specific |
| **Water Safety** | ❌ No guarantee | ✅ Guaranteed land | ✅ Guaranteed land |
| **Visual Quality** | ⚠️ Basic | ⚠️ Simple platform | ✅ Professional |
| **Direction Awareness** | ❌ None | ❌ None | ✅ Faces water |
| **Player Count Flexibility** | ✅ Any | ✅ Any | ❌ Best for 4-player |
| **Setup Time** | ⚡ Instant | 🐢 Medium | 🐌 Slow |
| **Best Use** | Flat land maps | Island/naval maps | 4v4 showcase maps |

---

### **🎯 When to Use Each Pattern:**

**Use Simple Sockets (Pattern 1) when:**
- Map terrain is flat and away from water
- Trade route is inland
- Quick implementation needed
- Testing/draft phase

**Use Sockets on Platforms (Pattern 2) when:**
- Naval or island maps
- Trade route near coastline
- Any player count
- Reliability is priority over visuals

**Use Harbour Groupings (Pattern 3) when:**
- Creating a 4-player competitive map
- Visual quality is important
- Have time to create/adapt 4-8 directional grouping files
- Trade route is circular or oval around map center

---

### **⚠️ Common Mistakes:**

1. **Pattern 1 (Simple):**
   - ❌ Forgetting `rmSetObjectDefTradeRouteID()` - socket won't activate
   - ❌ Not testing on water maps (sockets spawn in ocean)

2. **Pattern 2 (Platforms):**
   - ❌ Wrong offset direction (away from center instead of toward)
   - ❌ Platform too small (use 400+ tiles)
   - ❌ Not normalizing direction vector (wrong distances)
   - ❌ Forgetting `rmSetObjectDefTradeRouteID()` on socket

3. **Pattern 3 (Groupings):**
   - ❌ Using for non-4-player counts (orientation breaks)
   - ❌ Not accounting for 45° coordinate rotation
   - ❌ Direction calculated wrong way (TO socket instead of FROM center)
   - ❌ Missing grouping files (NE/NW/SE/SW variants)
   - ❌ Platform and grouping at same offset (defeats purpose)

---

### **🔧 Pro Tips:**

1. **Hybrid Approach:** Use Pattern 3 for 4-player, Pattern 2 for all other counts
   ```xs
   if (cNumberNonGaiaPlayers == 4) {
      // Use harbour groupings (Pattern 3)
   } else {
      // Use simple sockets (Pattern 2)
   }
   ```

2. **Offset Distance:**
   - Platform: 35m (standard, guarantees land)
   - Grouping: 15-20m (closer to water for visual effect)
   - Adjust based on map size (larger maps may need 40-50m)

3. **Echo Debugging:**
   ```xs
   rmEchoInfo("Socket "+i+" at X:"+socketX+" Z:"+socketZ);
   rmEchoInfo("Platform offset: "+offsetDistance+"m toward center");
   ```

4. **Water Constraints:**
   - Always add `avoidWater4` or similar constraint to socket objects
   - Prevents rare edge cases where platform fails

---

## 🎯 Best Practices for AI Agents

⚠️ **COORDINATE SYSTEM WARNING:** Always reference `docs/map_coordinate_system.md` when working with positions!

### **✅ DO:**

1. **Read `docs/map_coordinate_system.md` before placing any objects:**
   - ⚠️ **CRITICAL:** Coordinate system is rotated 45° from visual display
   - Code "NE" (1.0, 1.0) → Visual North (top of minimap)
   - Code "SE" (1.0, 0.0) → Visual East (right of minimap)
   - Code "SW" (0.0, 0.0) → Visual South (bottom of minimap)
   - Code "NW" (0.0, 1.0) → Visual West (left of minimap)
   - Think in X/Z values, not visual cardinal directions!

2. **Copy working maps as base:**
   ```
   GOOD: zp_philiphines.xs (Age of Pirates mod)
   GOOD: caribbean.xs (base game)
   GOOD: Ceylon.xs (base game)
   BAD: euMediterranean.xs (ENCODED!)
   ```

3. **Use variable definitions at top:**
   ```xs
   string seaType = "Caribbean Coast";
   string baseMix = "caribbean grass";
   string forestType = "Caribbean Palm Forest";
   string huntable1 = "deer";
   string fish1 = "FishMahi";
   ```

4. **Check reference files BEFORE using types:**
   - Water types → `waterbodies.xml`
   - Terrain types → `terraintypes.xml`
   - Proto units → `protoy.xml` or `protomods.xml`

5. **Test incrementally:**
   - Get map to load (basic terrain)
   - Add player placement
   - Add resources
   - Add features

6. **Place in root game folder for testing:**
   ```
   C:/Program Files (x86)/Steam/steamapps/common/AoE3DE/Game/RandMaps/
   ```

### **❌ DON'T:**

1. **Don't copy encoded maps:**
   - `eu*` prefix = European (encoded)
   - `af*` prefix = African (encoded)

2. **Don't guess type names:**
   - ❌ `"mediterranean sea"` (doesn't exist!)
   - ❌ `"Mediterranean_skirmish"` (might not exist!)
   - ✅ Check reference files first!

3. **Don't write maps from scratch:**
   - Start with working map structure
   - Modify variables, not logic

4. **Don't forget both files:**
   - Must have `.xs` AND `.xml`

---

## 🔧 Step-by-Step Workflow

⚠️ **BEFORE YOU START:** Read `docs/map_coordinate_system.md` to understand coordinate rotation!

### **Phase 1: Choose Base Map**

1. **User provides concept/image**
2. **Find similar working map:**
   - Island map? → `caribbean.xs`, `zp_philiphines.xs`
   - River map? → `greatplains.xs`, `yellowriver.xs`
   - Coastal map? → `california.xs`, `yucatan.xs`
3. **Verify map is readable (not encoded)**

### **Phase 2: Copy & Verify**

1. **Copy to root game RandMaps folder:**
   ```bash
   Copy: workingmap.xs → 000zpNewMap.xs
   Copy: workingmap.xml → 000zpNewMap.xml
   ```

2. **Read reference files:**
   ```
   Check: scripts/source/waterbodies.xml
   Check: scripts/source/art/terraintypes.xml
   ```

### **Phase 3: Modify Variables**

**⚠️ BEST PRACTICE: Define ALL type names as variables at the top of the file!**

**At top of `.xs` file, organize variables by category:**

```xs
// ============================================================================
// WATER TYPES (search waterbodies.xml!)
// ============================================================================
string seaType = "[EXACT name from waterbodies.xml]";
string lakeType = "[For rmSetAreaWaterType()]";
string riverType = "[For rmRiverCreate()]";
string baseTerrain = "water";

// ============================================================================
// TERRAIN TYPES (individual textures from terraintypes.xml)
// ============================================================================
string terrainType1 = "[path\to\texture]";
string terrainType2 = "[path\to\texture]";

// ============================================================================
// TERRAIN MIXES (search art/terrain/mix/ folder!)
// ============================================================================
string baseMix = "[filename from terrain/mix/ without .xml]";
string paintMix1 = "[For different areas]";
string paintMix2 = "[For forests, cliffs, etc.]";

// ============================================================================
// CLIFF TYPES (search clifftypes.xml and clifftypes2.xml)
// ============================================================================
string cliffType1 = "[EXACT name from clifftypes]";
string cliffType2 = "[For different elevations]";

// ============================================================================
// FOREST TYPES (search forest.xml and forest2.xml)
// ============================================================================
string forestType1 = "[EXACT name from forest types]";
string forestType2 = "[For different biomes]";

// ============================================================================
// VEGETATION
// ============================================================================
string forestType = "[VALID forest type]";
string startTreeType = "[VALID tree proto]";

// ============================================================================
// NATIVES
// ============================================================================
string nativeCiv1 = "[VALID subciv]";
string nativeCiv2 = "[VALID subciv]";

// ============================================================================
// ANIMALS
// ============================================================================
string huntable1 = "[VALID proto]";
string huntable2 = "[VALID proto]";
string fish1 = "[VALID proto]";
string fish2 = "[VALID proto]";

// ============================================================================
// LIGHTING & MAP TYPES
// ============================================================================
string lightingType = "[VALID lighting set]";
string mapType1 = "[theme]";
string mapType2 = "water" or "grass";
```

**Why organize this way?**
- ✅ All theme elements in one place
- ✅ Easy to change map theme
- ✅ Clear documentation of dependencies
- ✅ Prevents hardcoded strings throughout code

### **Phase 4: Update Native Logic**

⚠️ **COORDINATE REMINDER:** When placing natives at specific locations, remember the 45° rotation!
- If user says "place on West", use low X + high Z (e.g., 0.2, 0.8)
- Review `docs/map_coordinate_system.md` for details

**Find and replace native placement code:**
```xs
// OLD (from base map):
subCiv0=rmGetCivID("caribs");
if (subCiv0 >= 0)
    rmSetSubCiv(0, "caribs");

// NEW (for your map):
subCiv0=rmGetCivID("Berbers");
if (subCiv0 >= 0)
    rmSetSubCiv(0, "Berbers");
```

### **Phase 5: Test**

1. **Launch game**
2. **Create Skirmish game**
3. **Select your map (should be at top of list)**
4. **Load and check:**
   - Terrain renders correctly?
   - Players spawn?
   - Resources present?
   - Natives spawn?

### **Phase 6: Document**

**Create `.md` file with same name:**
```
000zpBalearicIslands.md
```

**Include:**
- Map features
- Water/terrain types used
- Native civs
- Known issues
- Reference to base map used

---

## ⚠️ Common Issues & Fixes

### **Issue: Map crashes on load**

**Likely causes:**
1. **Invalid water type name**
   - Fix: Search BOTH `data/waterbodies2.xml` and `scripts/source/waterbodies.xml`, use exact name from `name=` attribute
2. **Invalid terrain mix name**
   - Fix: List `art/terrain/mix/` folder, use exact filename (without .xml)
3. **Invalid native civ ID**
   - Fix: Check `civs.xml` for valid subciv names
4. **Missing `rmTerrainInitialize()`**
   - Fix: Add after `rmSetMapSize()`, before player placement
5. **Invalid loop syntax**
   - Fix: Use `for(i=1; <cNumberPlayers)` not `for(i=1; <=cNumberPlayers)`

### **Issue: Water looks wrong**

**Fix:** Search BOTH water files for available options:
```bash
# Check mod file first:
grep "name=" data/waterbodies2.xml
# Then check base game:
grep "name=" scripts/source/waterbodies.xml | grep -i "coast"
```
Then test with exact names from results, or use generic `"water"` fallback.

### **Issue: Natives don't spawn**

**Possible causes:**
1. Invalid subciv name
2. Wrong grouping name format
3. Constraints too restrictive

**Fix:** Check existing working map for exact native placement code.

---

## 📖 Example: Creating "Balearic Islands"

### **Bad Approach (what NOT to do):**
```xs
// ❌ Writing from scratch
rmSetSeaType("mediterranean sea");  // doesn't exist!
rmSetLightingSet("Mediterranean");  // might not exist!
// ... hundreds of lines of untested code
```

### **Good Approach:**

**Step 1:** Copy working island map:
```bash
Copy: zp_philiphines.xs → 000zpBalearicIslands.xs
```

**Step 2:** Search for matching types:
```bash
# Water types (search BOTH files - mod first!):
grep -i "mediterranean\|balearic" data/waterbodies2.xml  # Check mod waters first!
grep -i "iceland" data/waterbodies2.xml  # "ZP Iceland" found! (similar climate)
grep -i "coast" scripts/source/waterbodies.xml | head -20  # List base game coasts
# Result: Use "ZP Iceland" (mod file) or "Atlantic Coast" (base game)

# Terrain mixes (list terrain/mix/ folder):
ls scripts/source/art/terrain/mix/ | grep -i "italy\|mediterranean"
# Result: "italy_grass.xml" exists! (Mediterranean region)
```

**Step 3:** Update variables with VERIFIED names:
```xs
string seaType = "ZP Iceland";  // from waterbodies2.xml (mod file)
string baseMix = "italy_grass";  // Mediterranean region mix
string forestType = "Italian Forest";  // Mediterranean forest
```

**Step 4:** Update natives:
```xs
subCiv0=rmGetCivID("Berbers");  // change from pirates
subCiv1=rmGetCivID("zpCorsairs");  // change from wokou
```

**Step 5:** Test immediately - map should load!

**Step 6:** Then iterate on details (island sizes, resources, etc.)

---

## 🎓 Learning from Working Maps

### **Good Reference Maps:**

1. **`zp_philiphines.xs`** (Age of Pirates mod)
   - Clean variable structure
   - Multiple islands
   - Good native placement
   - Asian theme

2. **`caribbean.xs`** (Base game)
   - Proven island generation
   - Trade route system
   - Team placement logic
   - Resource distribution

3. **`Ceylon.xs`** (Base game)
   - Asian theme
   - Center island design
   - Multiple natives

### **Read These Sections:**

1. **Variable declarations** (top of file)
2. **Player placement** (`rmPlacePlayersCircular()`)
3. **Island creation** (`rmCreateArea()` loops)
4. **Native placement** (`rmCreateGrouping()`)
5. **Resource distribution** (mines, hunt, fish)

---

## 📂 File Organization

### **For New Map Development:**

```
C:/Program Files (x86)/Steam/steamapps/common/AoE3DE/Game/RandMaps/
├── 000zpBalearicIslands.xs   (script - place here for testing)
├── 000zpBalearicIslands.xml  (metadata - place here for testing)
└── 000zpBalearicIslands.md   (documentation - place here)
```

### **Reference Files (in mod workspace):**

```
<workspace>/scripts/source/
├── waterbodies.xml              (⚠️ CHECK: Base game water types!)
├── clifftypes.xml               (⚠️ CHECK: Base game cliff types!)
├── forest.xml                   (⚠️ CHECK: Base game forest types - 29 types!)
├── forest2.xml                  (⚠️ CHECK: Expanded forest types - 49+ types!)
├── art/
│   ├── terrain/
│   │   ├── terraintypes.xml     (⚠️ CHECK: Individual terrain textures!)
│   │   ├── terraintypes2.xml
│   │   ├── terraintypes3.xml
│   │   ├── terraintypescherry.xml
│   │   └── mix/                 (⚠️ CHECK: Terrain mixes - 258 files!)
│   │       ├── caribbean grass.xml
│   │       ├── italy_grass.xml
│   │       └── ...
├── protoy.xml                   (base game proto units)
├── civs.xml                     (civilization definitions)
└── randmaps/
    └── all_rm_commands.txt      (⚠️ READ: 273 RM commands!)

<workspace>/data/
├── waterbodies2.xml             (⚠️ CHECK FIRST: Mod-specific water types! "ZP" prefix)
└── clifftypes2.xml              (⚠️ CHECK: Mod-specific cliff types!)
```

---

## 🚀 Quick Start Checklist

**Before creating ANY new map:**

- [ ] ⚠️ **CRITICAL:** Read `docs/map_coordinate_system.md` (understand 45° rotation!)
- [ ] Read `docs/all_rm_commands.txt`
- [ ] Find similar working map (non-encoded!)
- [ ] Copy working map to root game `RandMaps/` folder
- [ ] **Search** `data/waterbodies2.xml` FIRST, then `scripts/source/waterbodies.xml` for water names (don't guess!)
- [ ] **List** `scripts/source/art/terrain/mix/` folder for matching terrain mixes
- [ ] **Search** `data/clifftypes2.xml` + `scripts/source/clifftypes.xml` for cliff types (if needed)
- [ ] Rename to `000zp[MapName].xs` and `.xml`
- [ ] **Organize variables at top of `.xs` file** (water, terrain, cliffs, natives, etc.)
- [ ] Update all variables with VERIFIED names from reference files
- [ ] Update native civs
- [ ] Test in-game (does it load?)
- [ ] Create `.md` documentation file

**Never:**
- [ ] ❌ Copy encoded maps (`eu*`, `af*`)
- [ ] ❌ Guess water/terrain type names
- [ ] ❌ Write maps from scratch
- [ ] ❌ Skip testing after each change

---

## 💡 Pro Tips

1. **Use Ceylon/Caribbean as templates** - they're readable and well-structured
2. **Test early, test often** - load map in-game after every major change
3. **Keep working backups** - copy `.xs` file before major changes
4. **Document as you go** - note what types you used and why
5. **When in doubt, use generic fallbacks:**
   ```xs
   rmSetSeaType("water");           // always works
   rmSetBaseTerrainMix("grass");    // always works
   rmSetLightingSet("texas");       // generic outdoor lighting
   ```

---

## 📞 Troubleshooting for AI Agents

⚠️ **COORDINATE TROUBLESHOOTING:** If objects appear in wrong locations, check `docs/map_coordinate_system.md`!
- User reports "West" but objects appear elsewhere? You likely used wrong X/Z values
- Remember: Visual West = Code NW = Low X + High Z

**If map crashes:**
1. Read error in game console (if visible)
2. Check all type names against reference files
3. Simplify - comment out features until map loads
4. Compare to working source map

**If unsure about type name:**
1. Search based on map description:
   ```bash
   # For water types (search BOTH files!):
   grep -i "[map theme]" data/waterbodies2.xml  # Check mod first!
   grep -i "[map theme]" scripts/source/waterbodies.xml  # Then base game
   
   # For terrain mixes:
   ls scripts/source/art/terrain/mix/ | grep -i "[map theme]"
   ```
2. If no match found, use closest thematic alternative or generic fallback
3. Explain to user what names exist and why you chose the alternative
4. Document the decision in the `.md` file

**If user requests non-existent feature:**
1. Check if similar feature exists in working maps
2. Suggest closest alternative
3. Document what's technically possible vs. requested

---

## 🔄 Example Tasks

This section provides step-by-step guides for common map modification tasks that AI agents may encounter.

---

### **Task: Rotating a Map by 90° Clockwise**

**Scenario:** User requests to rotate an entire map by 90° to change its orientation.

**⚠️ CRITICAL UNDERSTANDING:**

Maps have two types of positioning:
1. **Absolute Coordinates** - Fixed X/Z positions (e.g., `0.5, 0.8`) → **MUST be rotated**
2. **Relative/Dynamic Positioning** - Calculated from current positions → **Automatically adapts**

---

### **Step 1: Identify What Needs Rotation**

#### **✅ MUST Rotate (Absolute Coordinates):**

1. **Trade Route Waypoints**
   ```xs
   // BEFORE rotation:
   rmAddTradeRouteWaypoint(tradeRouteID, 0.82, 0.82);
   rmAddTradeRouteWaypoint(tradeRouteID, 0.95, 0.5);
   rmAddTradeRouteWaypoint(tradeRouteID, 0.82, 0.18);
   
   // AFTER 90° clockwise rotation (swap X and Z):
   rmAddTradeRouteWaypoint(tradeRouteID, 0.82, 0.82);
   rmAddTradeRouteWaypoint(tradeRouteID, 0.5, 0.95);
   rmAddTradeRouteWaypoint(tradeRouteID, 0.18, 0.82);
   ```

2. **Player Placement Section**
   ```xs
   // BEFORE rotation:
   rmSetPlacementSection(0.15, 0.85);
   
   // AFTER 90° clockwise rotation (add 0.25 to both, wrap if >1.0):
   rmSetPlacementSection(0.40, 0.10);
   // Calculation: 0.15+0.25=0.40, 0.85+0.25=1.10→wraps to 0.10
   ```

3. **Fixed Object Positions**
   ```xs
   // BEFORE rotation:
   rmPlaceObjectDefAtLoc(controllerID, 0, 0.54, 0.53);
   
   // AFTER rotation (swap X and Z):
   rmPlaceObjectDefAtLoc(controllerID, 0, 0.53, 0.54);
   ```

4. **Area Influence Segments**
   ```xs
   // BEFORE rotation:
   rmAddAreaInfluenceSegment(bigIslandID, 0.4, 0.5, 0.5, 0.65);
   // Parameters: (areaID, startX, startZ, endX, endZ)
   
   // AFTER rotation (swap X↔Z in all positions):
   rmAddAreaInfluenceSegment(bigIslandID, 0.5, 0.4, 0.65, 0.5);
   ```

#### **❌ DO NOT Rotate (Automatic/Relative):**

1. **Player Island/Team Island Placement**
   ```xs
   rmSetAreaLocPlayer(playerIslandID, i);  // ← Automatically follows player position
   rmSetAreaLocTeam(teamID, i);            // ← Automatically follows team position
   ```
   **Why:** These functions place areas wherever players spawned. Since players are rotated by `rmSetPlacementSection`, islands automatically follow.

2. **Direction-Based Grouping Logic**
   ```xs
   // This code calculates direction AFTER sockets are in rotated positions:
   float dirToSocketX = socketX - centerX;  // ← Uses new rotated socketX
   float dirToSocketZ = socketZ - centerZ;  // ← Uses new rotated socketZ
   
   // Logic checks quadrants based on CURRENT positions:
   if ((dirToSocketX > 0) && (dirToSocketZ > 0)) {
      harbourGroupingID = rmCreateGrouping("harbour", "Harbour_Universal_N");
   }
   ```
   **Why:** Direction is calculated from already-rotated positions, so quadrant checks automatically detect correct orientation.

3. **Circular Player Placement Distance**
   ```xs
   rmPlacePlayersCircular(0.29, 0.29, 0);  // ← Distance from center, not coordinates
   ```
   **Why:** This sets radius, not position. Players rotate via `rmSetPlacementSection`.

---

### **Step 2: Apply Rotations Systematically**

#### **A) Trade Route (Swap X and Z in all waypoints)**

```xs
// Original waypoints
rmAddTradeRouteWaypoint(tradeRouteID, 0.82, 0.82);
rmAddTradeRouteWaypoint(tradeRouteID, 0.95, 0.5);
rmAddTradeRouteWaypoint(tradeRouteID, 0.82, 0.18);
rmAddTradeRouteWaypoint(tradeRouteID, 0.5, 0.05);
rmAddTradeRouteWaypoint(tradeRouteID, 0.18, 0.18);
rmAddTradeRouteWaypoint(tradeRouteID, 0.05, 0.5);
rmAddTradeRouteWaypoint(tradeRouteID, 0.18, 0.82);
rmAddTradeRouteWaypoint(tradeRouteID, 0.5, 0.95);
rmAddTradeRouteWaypoint(tradeRouteID, 0.82, 0.82);

// After 90° clockwise rotation (X and Z swapped):
rmAddTradeRouteWaypoint(tradeRouteID, 0.82, 0.82);  // (0.82, 0.82) → (0.82, 0.82)
rmAddTradeRouteWaypoint(tradeRouteID, 0.5, 0.95);   // (0.95, 0.5) → (0.5, 0.95)
rmAddTradeRouteWaypoint(tradeRouteID, 0.18, 0.82);  // (0.82, 0.18) → (0.18, 0.82)
rmAddTradeRouteWaypoint(tradeRouteID, 0.05, 0.5);   // (0.5, 0.05) → (0.05, 0.5)
rmAddTradeRouteWaypoint(tradeRouteID, 0.18, 0.18);  // (0.18, 0.18) → (0.18, 0.18)
rmAddTradeRouteWaypoint(tradeRouteID, 0.5, 0.05);   // (0.05, 0.5) → (0.5, 0.05)
rmAddTradeRouteWaypoint(tradeRouteID, 0.82, 0.18);  // (0.18, 0.82) → (0.82, 0.18)
rmAddTradeRouteWaypoint(tradeRouteID, 0.95, 0.5);   // (0.5, 0.95) → (0.95, 0.5)
rmAddTradeRouteWaypoint(tradeRouteID, 0.82, 0.82);  // (0.82, 0.82) → (0.82, 0.82)
```

#### **B) Player Placement Section (Add 0.25, wrap if needed)**

**Formula for 90° clockwise rotation:**
```
newStart = (oldStart + 0.25) % 1.0
newEnd = (oldEnd + 0.25) % 1.0
```

**Example:**
```xs
// Original: Players spawn from 54° to 306° (252° arc)
rmSetPlacementSection(0.15, 0.85);

// Calculation:
// Start: 0.15 + 0.25 = 0.40 (144°)
// End:   0.85 + 0.25 = 1.10 → wraps to 0.10 (36°)

// After rotation: Players spawn from 144° through 0° to 36° (same 252° arc, rotated)
rmSetPlacementSection(0.40, 0.10);
```

**Understanding Wrap-Around:**
- When end < start (e.g., `0.40` to `0.10`), the arc wraps through 0°/360°
- Arc goes: 144° → 180° → 270° → 360°/0° → 36°
- This maintains the original arc length

#### **C) Fixed Object Positions (Conditional swaps)**

For objects placed at specific coordinates:

```xs
// Example: Pirate controller positions
if (i == 0) {
   // BEFORE rotation:
   controllerX = 0.54;
   controllerZ = 0.53;
   
   // AFTER rotation (swap X and Z):
   controllerX = 0.53;
   controllerZ = 0.54;
}
```

**Multiple conditional positions example:**
```xs
// Original pirate controllers
if (i == 0) {
   if (cNumberNonGaiaPlayers <= 2) {
      controllerX = 0.53; controllerZ = 0.53;
   }
   else if (cNumberNonGaiaPlayers == 3) {
      controllerX = 0.54; controllerZ = 0.53;  // BEFORE
   }
   else {
      controllerX = 0.54; controllerZ = 0.54;
   }
}

// After 90° rotation
if (i == 0) {
   if (cNumberNonGaiaPlayers <= 2) {
      controllerX = 0.53; controllerZ = 0.53;  // Diagonal, unchanged
   }
   else if (cNumberNonGaiaPlayers == 3) {
      controllerX = 0.53; controllerZ = 0.54;  // AFTER (swapped)
   }
   else {
      controllerX = 0.54; controllerZ = 0.54;  // Diagonal, unchanged
   }
}
```

#### **D) Area Influence Segments (Swap all X/Z pairs)**

```xs
// Original bonus island shape
rmSetAreaLocation(bigIslandID, 0.5, 0.5);  // Center stays the same
rmAddAreaInfluenceSegment(bigIslandID, 0.4, 0.5, 0.5, 0.65);
rmAddAreaInfluenceSegment(bigIslandID, 0.6, 0.5, 0.5, 0.65);
rmAddAreaInfluenceSegment(bigIslandID, 0.4, 0.5, 0.5, 0.39);
rmAddAreaInfluenceSegment(bigIslandID, 0.6, 0.5, 0.5, 0.39);

// After rotation (swap X↔Z in each segment)
rmSetAreaLocation(bigIslandID, 0.5, 0.5);  // Center unchanged
rmAddAreaInfluenceSegment(bigIslandID, 0.5, 0.4, 0.65, 0.5);
rmAddAreaInfluenceSegment(bigIslandID, 0.5, 0.6, 0.65, 0.5);
rmAddAreaInfluenceSegment(bigIslandID, 0.5, 0.4, 0.39, 0.5);
rmAddAreaInfluenceSegment(bigIslandID, 0.5, 0.6, 0.39, 0.5);
```

---

### **Step 3: Verify What NOT to Change**

#### **✅ Keep Unchanged:**

1. **Dynamic Direction Calculations**
   ```xs
   // This calculates direction from CURRENT socket position (already rotated)
   float dirToSocketX = socketX - centerX;
   float dirToSocketZ = socketZ - centerZ;
   
   // Quadrant checks work correctly with rotated positions
   if ((dirToSocketX > 0) && (dirToSocketZ > 0)) {
      // This socket is in NE quadrant based on its NEW position
      harbourGroupingID = rmCreateGrouping("harbour", "Harbour_Universal_N");
   }
   ```
   **Why it works:** After rotating waypoints, `socketX` and `socketZ` are already in new positions. The direction calculation uses these NEW values, so quadrant checks automatically detect correct orientation.

2. **Relative Area Placement**
   ```xs
   rmSetAreaLocPlayer(playerIslandID, i);   // ← Don't change
   rmSetAreaLocTeam(teamID, i);             // ← Don't change
   ```
   **Why:** These APIs place areas at player/team locations, which are already rotated via `rmSetPlacementSection`.

3. **Distance/Radius Values**
   ```xs
   rmPlacePlayersCircular(0.29, 0.29, 0);   // ← Don't change
   ```
   **Why:** This is a radius from center, not coordinates.

---

### **Step 4: Common Mistakes to Avoid**

#### **❌ MISTAKE 1: Double Rotation**

```xs
// WRONG: Rotating both waypoints AND grouping logic
rmAddTradeRouteWaypoint(tradeRouteID, 0.5, 0.95);  // Rotated waypoint ✅

// Then also trying to rotate the grouping selection:
if ((dirToSocketX > 0) && (dirToSocketZ > 0)) {
   harbourGroupingID = rmCreateGrouping("harbour", "Harbour_Universal_E");  // ❌ WRONG!
}
```

**Why wrong:** You've rotated the physical position (waypoint) AND the logic. That's double rotation! The direction calculation adapts automatically to new positions.

**Correct approach:**
```xs
// Rotate waypoints only
rmAddTradeRouteWaypoint(tradeRouteID, 0.5, 0.95);  // ✅

// Keep original grouping logic
if ((dirToSocketX > 0) && (dirToSocketZ > 0)) {
   harbourGroupingID = rmCreateGrouping("harbour", "Harbour_Universal_N");  // ✅
}
```

#### **❌ MISTAKE 2: Forgetting Player Placement Section**

```xs
// Rotated trade route ✅
rmAddTradeRouteWaypoint(tradeRouteID, 0.5, 0.95);

// But forgot to rotate placement section ❌
rmSetPlacementSection(0.15, 0.85);  // Players in wrong position!
```

**Fix:** Add 0.25 to placement section values:
```xs
rmSetPlacementSection(0.40, 0.10);  // ✅ Rotated 90° clockwise
```

#### **❌ MISTAKE 3: Only Rotating Some Waypoints**

```xs
// Partially rotated - creates broken route ❌
rmAddTradeRouteWaypoint(tradeRouteID, 0.82, 0.82);
rmAddTradeRouteWaypoint(tradeRouteID, 0.5, 0.95);   // Rotated
rmAddTradeRouteWaypoint(tradeRouteID, 0.82, 0.18);  // NOT rotated - wrong!
```

**Fix:** Rotate ALL waypoints consistently.

#### **❌ MISTAKE 4: Swapping Wrong Parameters**

```xs
// WRONG: Swapping parameters in area size
rmSetAreaSize(areaID, 0.18, 0.24);  // startSize, endSize - NOT coordinates!
// Should NOT swap these ❌
```

**Only swap X/Z in:**
- Waypoint coordinates: `rmAddTradeRouteWaypoint(id, X, Z)`
- Object positions: `rmPlaceObjectDefAtLoc(id, player, X, Z)`
- Area locations: `rmSetAreaLocation(id, X, Z)`
- Influence segments: `rmAddAreaInfluenceSegment(id, startX, startZ, endX, endZ)`

---

### **Step 5: Testing Checklist**

After rotation, verify:

- ✅ Trade route forms correct shape (circular, oval, etc.)
- ✅ Players spawn in rotated positions
- ✅ Player islands appear at player locations
- ✅ Trade sockets spawn correctly (test with 4-player for groupings)
- ✅ Fixed objects (pirates, cliff) are in expected rotated positions
- ✅ Bonus island shape is rotated correctly

---

### **Complete Example: Balearic Islands 90° Rotation**

#### **Changes Made:**

1. **Trade Route** (Lines 236-244): Swapped X/Z in all 9 waypoints
2. **Player Section** (Line 250): Changed `(0.15, 0.85)` → `(0.40, 0.10)`
3. **Pirate Controllers** (Lines 377-393): Swapped X/Z for 3-player positions
4. **Cliff Controller** (Lines 434-438): Swapped X/Z coordinates
5. **Bonus Island** (Lines 223-226): Swapped X/Z in influence segments

#### **Unchanged (Automatic Adaptation):**

1. **Island Placement**: `rmSetAreaLocPlayer()` and `rmSetAreaLocTeam()` - follow players
2. **Grouping Logic**: Direction calculated from rotated positions - adapts automatically
3. **Player Distance**: `rmPlacePlayersCircular(0.29, 0.29, 0)` - radius, not coordinates

**Result:** Map rotated 90° clockwise with all features correctly oriented! ✅

---

### **Quick Reference: 90° Rotation Formulas**

| Element | Rotation Method | Example |
|---------|----------------|---------|
| **Trade Waypoint** | Swap X and Z | `(0.95, 0.5)` → `(0.5, 0.95)` |
| **Placement Section** | Add 0.25, wrap >1.0 | `(0.15, 0.85)` → `(0.40, 0.10)` |
| **Object Position** | Swap X and Z | `(0.54, 0.53)` → `(0.53, 0.54)` |
| **Influence Segment** | Swap all X/Z pairs | `(0.4, 0.5, 0.5, 0.65)` → `(0.5, 0.4, 0.65, 0.5)` |
| **Direction Logic** | **NO CHANGE** | Adapts automatically |
| **Area Loc Player/Team** | **NO CHANGE** | Follows rotated players |

---

### **Other Rotation Angles**

**180° Clockwise:**
- Waypoints: `X_new = 1.0 - X_old`, `Z_new = 1.0 - Z_old`
- Placement: Add 0.5 to both values

**270° Clockwise (= 90° Counter-Clockwise):**
- Waypoints: Swap X and Z, then: `X_new = 1.0 - X_swapped`, `Z_new = 1.0 - Z_swapped`
- Placement: Subtract 0.25 from both values

---

## 📊 Quick Reference: Type Categories

| Type Category | Reference Files | Search Method | Used In | Example |
|--------------|----------------|---------------|---------|---------|
| **Water Types** | `data/waterbodies2.xml` (mod) + `scripts/source/waterbodies.xml` (base) | `grep -i "[theme]"` in BOTH files | `rmSetSeaType()`, `rmSetAreaWaterType()`, `rmRiverCreate()` | `"ZP Iceland"`, `"Caribbean Coast"` |
| **Terrain Types** | `art/terrain/terraintypes*.xml` | Browse `<subtype>` tags | `rmTerrainInitialize()`, `rmSetAreaTerrainType()` | `"lava\volcano_snow"`, `"city\ground1_cob_dark"` |
| **Terrain Mixes** | `art/terrain/mix/*.xml` (258 files) | `ls` folder, use filename without .xml | `rmSetBaseTerrainMix()`, `rmSetAreaMix()` | `"italy_grass"` (underscores!) |
| **Cliff Types** | `clifftypes.xml`, `data/clifftypes2.xml` | `grep name=` in both files | `rmSetAreaCliffType()` | `"ZP Iceland Fjord"`, `"ZP Iceland High"` |
| **Forest Types** | `forest.xml` (29 types), `forest2.xml` (49+ types) | `grep 'forest name='` in both files | `rmSetAreaForestType()` | `"Italian Forest"`, `"z31 Mediterranean Coastal Forest"` |
| **Huntables** | `data/protomods.xml` | `grep "<unittype>Huntable</unittype>"` | `rmAddObjectDefItem()` | `"ypIbex"`, `"deer"`, `"Sheep"` |
| **Fish** | Check existing region maps | Look at maps: zp_mediterranean.xs, zp_venice.xs | `rmAddObjectDefItem()` | `"ypFishTuna"`, `"FishSalmon"` |
| **Whales** | Check existing region maps | Mediterranean→MinkeWhale, Pacific→HumpbackWhale | `rmAddObjectDefItem()` | `"MinkeWhale"`, `"HumpbackWhale"` |
| **Mines** | `data/protomods.xml` | Standard: "Mine" | `rmAddObjectDefItem()` | `"Mine"`, `"MineCopper"` |
| **Berries** | Standard | Always use "BerryBush" | `rmAddObjectDefItem()` | `"BerryBush"` |
| **Map Types** | `maptypes.xml`, `data/maptypemods.xml` | Define as variables (layoutType, nuggetType, tradeType, specialType1/2) | `rmSetMapType()` | `"water"`, `"mediEurope"`, `"euroNavalTradeRoute"`, `"piratehistoricalmap"` |
| **Natives (Subcivs)** | `scripts/source/civs.xml` + `data/civmods.xml` ⚠️ **SEARCH BOTH!** | `grep "<name>"` in BOTH files; check `<subcivtype>`; prefer SPC variants | `rmGetCivID()`, `rmSetSubCiv()` | `"Habsburg"`, `"SPCBourbon"`, `"NatPirates"` |
| **Groupings** | `game/randmaps/groupings/*.xml` (100+ files) | `ls \| findstr/grep` to find exact filenames ⚠️ **NEVER GUESS!** | `rmCreateGrouping()`, `rmPlaceGroupingAtLoc()` ⚠️ **ALWAYS player 0!** | `"zpHabsburg_SP_01"`, `"scientist_lab03"`, `"pirate_village05"` |

**Usage Pattern:**
```xs
// 1. Define variables at top of file
string seaType = "Caribbean Coast";        // Water type
string baseMix = "caribbean grass";        // Terrain mix
string volcCliff = "ZP Iceland High";      // Cliff type
string volcTerrain = "lava\volcano_dirt";  // Terrain type

// 2. Use variables throughout script
rmSetSeaType(seaType);                     // Base ocean
rmSetBaseTerrainMix(baseMix);              // Base terrain
rmSetAreaCliffType(cliffID, volcCliff);    // Cliff area
rmSetAreaTerrainType(areaID, volcTerrain); // Specific terrain
```

---

## 🎯 Map Triggers

**Triggers** enable dynamic gameplay events, tech activation, and politician systems on your maps.

### When to Use Triggers

- ✅ Activating starting technologies for all players
- ✅ Enabling consulate politicians (Asian civilizations, pirates, etc.)
- ✅ Assigning random leaders/captains to AI players
- ✅ Creating timed events or conditional gameplay
- ✅ Balancing civilization-specific features

### Trigger Reference Files

| File | Purpose |
|------|---------|
| **`data/trigger/triggerdata.xml`** | Complete trigger definitions (effects, conditions, parameters) |
| **`data/techtreemods.xml`** | Technology definitions and availability by region |
| **[docs/map_trigger_guide.md](map_trigger_guide.md)** | **Complete trigger implementation guide** ⭐ |

### Quick Trigger Example

```xs
// Activate a starting tech for all players
rmCreateTrigger("Starting Techs");
rmSwitchToTrigger(rmTriggerID("Starting Techs"));

for(i=0; <= cNumberNonGaiaPlayers) {
    rmAddTriggerEffect("ZP Set Tech Status (XS)");
    rmSetTriggerEffectParamInt("PlayerID",i);
    rmSetTriggerEffectParam("TechID","cTechzpSpanishHabsburgs"); // Activate Spanish Habsburgs for all players
    rmSetTriggerEffectParamInt("Status",2);
}

rmSetTriggerPriority(4);
rmSetTriggerActive(true);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);
```

### 📚 For Complete Trigger Documentation

See **[Map Trigger Guide](map_trigger_guide.md)** for:
- Starting tech activation
- Universal consulate setup (Japan, China, India, Pirates)
- AI leader/captain selection
- Regional pirate variants (Mediterranean, Baltic, Australia)
- Supporting triggers (Italian balance, research speed)
- Complete working examples
- Best practices and troubleshooting

---

**This guide ensures AI agents create working, tested maps following Age of Pirates mod conventions.** 🗺️✅

