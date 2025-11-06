# Random Map Generation Guide for AI Agents

**Audience:** AI assistants working on Age of Empires III: Definitive Edition random map scripts  
**Version:** 2.11  
**Last Updated:** 2025-11-06

---

## **1.** 📋 Document Version Control

**AI Assistant Instructions:**
- **After making ANY changes to this document, update the "Last Updated" date above**
- Format: YYYY-MM-DD
- Update version: 2.x for minor updates, 3.0 for major restructuring

**⚠️ CRITICAL RULE - Content Removal:**
- **NEVER remove content from categorized sections** (chapters, main sections, subsections) without explicit user permission
- If you think content should be removed or relocated, **ASK FIRST** and explain:
  - What content you want to remove
  - Why it should be removed
  - Where it will be moved (if applicable)
- **WARNING TO USER:** Once content is removed from this document, it may be difficult or impossible to recover from AI memory
- **Always create a backup** before making large structural changes

**Version History:**
- **2.11** (2025-11-06): Added map layout pattern classification table to Chapter 22 Phase 1 with 13 distinct patterns; Added C-style for loop crash example to experimental syntax section with correct XS syntax fix
- **2.10** (2025-11-06): Reorganized chapters - Created Chapter 22 "Best Practices for AI Agents", removed redundant Chapter 23 "Common Issues & Fixes" (content already in Chapter 21 Troubleshooting), renumbered Chapter 24→23 "Complete Example"; Updated Table of Contents
- **2.9** (2025-11-06): Added two new troubleshooting sections: "⚠️ Spawn on Impossible Location" (land objects on water with island examples, objects on cliffs with plateau examples, groupings on trade routes) and "⚠️ Players Circular Issues" (case study of circular trade route conflict with detailed solution)
- **2.8** (2025-11-06): Enhanced section 17.1.2 "Players Circular" with detailed explanation of distance values as fraction of map radius; Added warning about values over 0.45 causing spawn failures; Added practical examples for trade route avoidance
- **2.7** (2025-11-06): Added `vector` type to variable types; Added new crash cause "Invalid Array Syntax" to troubleshooting; Added experimental code rule requiring `// EXPERIMENTAL` comments for undocumented patterns
- **2.6** (2025-11-06): Added Chapter 20 (Triggers) and Chapter 21 (Troubleshooting), completed Table of Contents with all 21 chapters, added cross-references and back-to-top navigation
- **2.5** (2025-11-06): Restored complete coordinate system content with visual diagrams and examples; Added CRITICAL RULE about content removal
- **2.4** (2025-11-06): Added numbering convention section, created dedicated Forests subsection (14.2.4), removed duplicate content
- **2.3** (2025-11-05): Made documentation generic for any mod/machine, added Age of Pirates section and local config system
- **2.2** (2025-11-05): Added XS programming basics, map grid system, object names guide, and simple complete example from official docs
- **2.1** (2025-11-05): Added Table of Contents and RM Commands Reference section
- **2.0** (2025-11-05): Restructured for AI assistant efficiency
- **1.0** (2025-11-01): Initial version

---

## **2.** 📑 Table of Contents

**⚠️ AI Assistant Instructions for Table of Contents:**
- **IMPORTANT:** When you add, remove, or rename ANY section in this document, you MUST update this ToC
- After making changes, scroll through the document to verify all section headings
- Update section numbers and titles to match exactly
- Test that all internal links work correctly

---

### **2.1. Numbering Convention**

**Strict hierarchy rules - ALWAYS follow this structure:**

1. **Top-level chapters:** `## N.` (e.g., `## 14.`, `## 15.`)
   - Major topics (Areas, Trade Routes, Rivers, Players, Objects, etc.)
   - ⚠️ **Always use bold font for chapter numbers**
   - Example: `## 14. 🗺️ Areas`
   
2. **Main sections:** `### **N.M.**` (e.g., `### **14.1.**, `### **14.2.**`)
   - Major subdivisions within a chapter
   - Use bold double asterisks for section numbers
   - Example: `### **14.2. Random Area Patterns**`
   
3. **Subsections:** `#### **N.M.P**` (e.g., `#### **14.2.1`, `#### **14.2.4`)
   - Specific techniques, examples, or patterns
   - Use bold for subsection numbers
   - Example: `#### **14.2.4 Forests:**`
   
4. **Sub-subsections (level 4):** `##### **N.M.P.Q**` or descriptive titles
   - Fine-grained details within subsections
   - Can use letters (A, B, C) or numbers for clarity
   - Example from 14.3.4: `##### **Part 1: Fixed Elevated Plateaus**`
   - Example with letters: `##### **A) Base Terrain**`

5. **Sub-sub-subsections (level 5):** `##### **N.M.P.Q.R**` (rarely used)
   - Very specific details, used sparingly
   - Example from Trade Routes: `##### **15.4.4.5 Train Stations (Advanced)**`

**Complete hierarchy example:**
```
## **14.** 🗺️ Areas                              ← Top-level chapter (bold number)
### **14.2. Random Area Patterns**            ← Main section (bold)
#### **14.2.4 Forests:**                      ← Subsection (bold)
##### **Example 1: Random Forests**           ← Sub-subsection (descriptive, bold)

## **15.** 🚂 Trade Routes                        ← Top-level chapter (bold number)
### **15.4. Socket Types**                    ← Main section (bold)
#### **15.4.4 Socket Variants**               ← Subsection (bold)
##### **15.4.4.5 Train Stations**             ← Sub-sub-subsection (5 levels deep, bold)
```

**When renumbering after adding/removing sections:**
1. Find all affected sections using regex: `^##+ \*\*?14\.2\.[0-9]`
2. Renumber subsections sequentially (14.2.1, 14.2.2, 14.2.3, 14.2.4...)
3. Check for sub-subsections and ensure they're nested correctly
4. Update cross-references (e.g., "see section 14.2.4")
5. Verify ToC is updated

---

### **2.2. Complete Table of Contents**

1. [📋 Document Version Control](#1--document-version-control)
2. [📑 Table of Contents](#2--table-of-contents)
3. [⚠️ Understanding Coordinates (CRITICAL)](#3-️-understanding-coordinates-critical)
4. [💻 XS Programming Basics](#4--xs-programming-basics)
5. [🗺️ Map Grid & Measurement System](#5-️-map-grid--measurement-system)
6. [📦 Finding Object Names](#6--finding-object-names)
7. [🏴‍☠️ Age of Pirates Localization](#7-️-age-of-pirates-localization)
8. [💻 Local Machine Configuration](#8--local-machine-configuration)
9. [📁 Map Folder Structure](#9--map-folder-structure)
10. [📋 Required Files](#10--required-files)
11. [🚀 Simple Complete Example](#11--simple-complete-example)
12. [📚 Reference Documentation](#12--reference-documentation)
13. [🧩 Map Properties](#13--map-properties)
14. [🏝️ Areas](#14-️-areas)
15. [🚂 Trade Routes](#15--trade-routes)
16. [🤖 Rivers](#16--rivers)
17. [👥 Players](#17--players)
18. [📦 Objects](#18--objects)
19. [🏘️ Groupings (Native Villages, City States)](#19-️-groupings-native-villages-city-states-decorative-structures)
20. [🎯 Map Triggers](#20--map-triggers)
21. [📞 Troubleshooting](#21--troubleshooting)
22. [🎯 Best Practices for AI Agents](#22--best-practices-for-ai-agents)
23. [📖 Complete Example: Creating Balearic Islands](#23--complete-example-creating-balearic-islands)

**External Resources:**
- [📚 RM Commands Reference](rm_commands_reference.md) ⭐ (274 commands documented)
- [Map Trigger Guide](map_trigger_guide.md) - Complete trigger documentation

---

## **3.** ⚠️ Understanding Coordinates (CRITICAL)

### **🎯 Critical Concept: 45° Rotation**

**⚠️ IMPORTANT:** The XZ coordinate system used in `.xs` scripts is **rotated 45° from the visual minimap display!**

---

### **Visual Representation**

#### **Code Coordinates (Standard XZ Axes)**
```
              Z-axis (North in code)
                     ↑
                (0.5, 1.0)
                     |
                     |
(0.0, 0.5) ←────────(0.5, 0.5)────────→ (1.0, 0.5)
X-axis              |                    X-axis
(West)              |                    (East)
                    |
               (0.5, 0.0)
                    ↓
              (South in code)
```

#### **Visual Minimap Display (Rotated 45° - Diamond Shape)**
```
                    N (North)
                    ↑
               (0.5, 1.0)
                   /|\
                  / | \
                 /  |  \
                /   |   \
               /    |    \
              /     |     \
     (0.0, 1.0)    |    (1.0, 1.0)
         W ←───(0.5, 0.5)───→ E
     (0.0, 0.5)    |    (1.0, 0.5)
              \    |    /
               \   |   /
                \  |  /
                 \ | /
                  \|/
               (0.5, 0.0)
                    ↓
                    S (South)
```

---

### **Coordinate Mapping Table**

#### **Corner Positions**

| Code Name | Code Coordinates (X, Z) | Visual Map Direction | Description |
|-----------|------------------------|---------------------|-------------|
| **NE** (Northeast in code) | `(1.0, 1.0)` | **N** (North/Top) | High X, High Z → Top of diamond |
| **SE** (Southeast in code) | `(1.0, 0.0)` | **E** (East/Right) | High X, Low Z → Right of diamond |
| **SW** (Southwest in code) | `(0.0, 0.0)` | **S** (South/Bottom) | Low X, Low Z → Bottom of diamond |
| **NW** (Northwest in code) | `(0.0, 1.0)` | **W** (West/Left) | Low X, High Z → Left of diamond |

#### **Center Position**
| Code Name | Code Coordinates (X, Z) | Visual Map Direction |
|-----------|------------------------|---------------------|
| **Center** | `(0.5, 0.5)` | **Center** |

---

### **Understanding the Axes**

#### **X-Axis (Horizontal in code)**
- **X = 0.0** → Left side of code grid → **West + South** on visual map
- **X = 0.5** → Center horizontal
- **X = 1.0** → Right side of code grid → **East + North** on visual map

#### **Z-Axis (Vertical in code)**
- **Z = 0.0** → Bottom of code grid → **South + East** on visual map
- **Z = 0.5** → Center vertical
- **Z = 1.0** → Top of code grid → **North + West** on visual map

---

### **Practical Examples**

#### **Example 1: Placing Object in Visual "North"**
**Goal:** Place something at the top of the minimap (visual North)

**Code coordinates:** `(0.5, 1.0)` or nearby like `(0.6, 0.9)`
- High Z value (close to 1.0)
- Moderate X value (around 0.5)

```xs
float objectX = 0.5;
float objectZ = 0.9;  // High Z = visual North
rmPlaceObjectDefAtLoc(objectID, 0, objectX, objectZ);
```

#### **Example 2: Placing Object in Visual "West"**
**Goal:** Place something on the left side of the minimap (visual West)

**Code coordinates:** `(0.2, 0.8)` or similar
- Low X value (close to 0.0)
- High Z value (close to 1.0)

```xs
float objectX = 0.2;   // Low X
float objectZ = 0.8;   // High Z
// This appears on the left (West) of the visual map
rmPlaceObjectDefAtLoc(objectID, 0, objectX, objectZ);
```

#### **Example 3: Balearic Islands Bonus Island Placement**

The code uses `IslandLoc` to randomize the bonus island position:

```xs
if (IslandLoc == 1) {
   // Code NE → Visual N (Top)
   bonusX = 0.80;  // High X
   bonusZ = 0.80;  // High Z
} else if (IslandLoc == 2) {
   // Code SE → Visual E (Right)
   bonusX = 0.85;  // High X
   bonusZ = 0.15;  // Low Z
} else if (IslandLoc == 3) {
   // Code SW → Visual S (Bottom)
   bonusX = 0.15;  // Low X
   bonusZ = 0.15;  // Low Z
} else {
   // Code NW → Visual W (Left)
   bonusX = 0.15;  // Low X
   bonusZ = 0.85;  // High Z
}
```

**If a player reports:** *"The bonus island is on the West side"*
→ **That's IslandLoc 4 (code NW)** with coordinates around `(0.15-0.20, 0.80-0.85)`

---

### **Quick Reference: Visual Direction → Code Coordinates**

| Visual Direction | X Range | Z Range | Code Name | Example Coords |
|-----------------|---------|---------|-----------|----------------|
| **North (Top)** | 0.4-0.6 | 0.8-1.0 | NE region | `(0.5, 0.9)` |
| **East (Right)** | 0.8-1.0 | 0.4-0.6 | SE region | `(0.9, 0.5)` |
| **South (Bottom)** | 0.4-0.6 | 0.0-0.2 | SW region | `(0.5, 0.1)` |
| **West (Left)** | 0.0-0.2 | 0.4-0.6 | NW region | `(0.1, 0.5)` |
| **Northeast** | 0.7-1.0 | 0.7-1.0 | True NE | `(0.85, 0.85)` |
| **Southeast** | 0.7-1.0 | 0.0-0.3 | True SE | `(0.85, 0.15)` |
| **Southwest** | 0.0-0.3 | 0.0-0.3 | True SW | `(0.15, 0.15)` |
| **Northwest** | 0.0-0.3 | 0.7-1.0 | True NW | `(0.15, 0.85)` |
| **Center** | 0.4-0.6 | 0.4-0.6 | Center | `(0.5, 0.5)` |

---

### **Common Pitfalls**

#### **❌ Mistake: Using Cardinal Directions from Code Names**
```xs
// This is code "NE" but visual "North"!
float x = 0.9;
float z = 0.9;
```

#### **✅ Correct: Think in X/Z, Convert to Visual**
```xs
// Want visual "West" (left side of minimap)?
// Use low X, high Z
float westX = 0.15;   // Low X value
float westZ = 0.85;   // High Z value
```

---

### **Working with Players**

#### **Player Descriptions vs Code Coordinates**

When a player says:
- **"It's in the North"** → Look for **high Z** values (0.7-1.0), moderate X (0.4-0.6)
- **"It's in the South"** → Look for **low Z** values (0.0-0.3), moderate X (0.4-0.6)
- **"It's in the East"** → Look for **high X** values (0.7-1.0), moderate Z (0.4-0.6)
- **"It's in the West"** → Look for **low X** values (0.0-0.3), moderate Z or high Z (0.4-0.8)

---

### **Testing Coordinates**

#### **Method 1: Use Fixed Positions**
```xs
// Test visual North placement
rmPlaceObjectDefAtLoc(testObject, 0, 0.5, 0.95);

// Test visual West placement
rmPlaceObjectDefAtLoc(testObject, 0, 0.15, 0.85);

// Test visual East placement
rmPlaceObjectDefAtLoc(testObject, 0, 0.85, 0.15);

// Test visual South placement
rmPlaceObjectDefAtLoc(testObject, 0, 0.5, 0.05);
```

#### **Method 2: Debug with Echo**
```xs
rmEchoInfo("Placed at X: " + objectX + " Z: " + objectZ);
```

Check the in-game console or log files to see where objects actually placed.

---

### **Summary**

✅ **Key Takeaway:** The XZ coordinate system is rotated 45° from the visual minimap!

| To place in... | Use coordinates... |
|---------------|-------------------|
| **Visual North** | High Z (0.8-1.0), Mid X (0.4-0.6) |
| **Visual East** | High X (0.8-1.0), Mid Z (0.4-0.6) |
| **Visual South** | Low Z (0.0-0.2), Mid X (0.4-0.6) |
| **Visual West** | Low X (0.0-0.2), High Z (0.7-1.0) |

**Always think in terms of X and Z values, not cardinal directions from the code!**

**See also:**
- [Chapter 14 (Areas)](#14-️-areas) - Practical coordinate usage in area placement
- [Chapter 17 (Players)](#17--players) - Player positioning with coordinates
- [Chapter 19 (Groupings)](#19-️-groupings-native-villages-city-states-decorative-structures) - Grouping placement with X/Z coordinates

[↑ Back to Table of Contents](#2--table-of-contents)

---

## **4.** 💻 XS Programming Basics

**Purpose:** Understanding XS language fundamentals for creating random maps

**📚 Complete XS Reference:** For comprehensive XS language documentation, see [AOE3 AI Scripting Guide - The XS Language](https://aoe3mc.github.io/ai-guide/xs/)

### **4.1. Variables**

**Format:** `<type> <name> = <value>;`

**Variable Types:**
- **int** - Integer numbers (no decimals): `int myCounter = 1;`
- **float** - Decimal numbers: `float myFraction = 0.28;`
- **string** - Text: `string myUnitName = "Settler";`
- **bool** - True/False: `bool myCheck = true;`
- **vector** - Coordinate/position data: `vector myLocation = rmGetTradeRouteWayPoint(routeID, 0.5);`

**Naming Convention:**
- First letter lowercase
- Multiple words: use camelCase
- Examples: `myCounter`, `playerStartArea`, `cliffHeightValue`

**Operations:**
```cpp
// Math operations
int sum = counter1 + counter2;
float result = value1 * value2;

// String concatenation
string fullName = firstName + " " + lastName;

// Variable reuse (no type needed after first definition)
myCounter = 5;  // Don't use "int" again
```

### **4.2. AOE3:DE Predefined Variables**

These are automatically set by the game:
- `cMapSize` - 0 = normal, 1 = large
- `cNumberNonGaiaPlayers` - Number of players (excluding Gaia)
- `cNumberPlayers` - Total players including Gaia
- `cNumberTeams` - Number of teams

**Example:**
```cpp
int myTiles = 8000;
if (cMapSize == 1) {
    myTiles = 12000;  // Large map
}
```

### **4.3. Operators**

**Comparison:**
- `==` - Equal to
- `!=` - Not equal to
- `<` - Less than
- `>` - Greater than
- `<=` - Less than or equal
- `>=` - Greater than or equal

**Logical:**
- `&&` - AND (both must be true)
- `||` - OR (either can be true)

**Example:**
```cpp
if (cNumberNonGaiaPlayers >= 4 && cMapSize == 1) {
    // Large map with 4+ players
}
```

### **4.4. Control Flow**

**If/Else:**
```cpp
if (condition) {
    // Execute if true
} else if (otherCondition) {
    // Execute if first false, this true
} else {
    // Execute if all false
}
```

**For Loop:**
```cpp
for (i = 1; <= cNumberNonGaiaPlayers) {
    // Repeat for each player
    int playerArea = rmCreateArea("Player" + i);
}
```

### **4.5. Functions**

**Predefined Functions** (start with `rm`):
- `rmCreateArea()` - Create an area
- `rmPlaceObjectDefAtLoc()` - Place object
- `rmEchoInfo()` - Debug output

**Custom Functions:**
```cpp
int myFunction(int x = 0) {
    return (x + 2);
}
```

**Main Function** (required in every map):
```cpp
void main(void) {
    // All map generation code goes here
}
```

### **4.6. Script Conventions**

**⚠️ Important Rules:**
- **Case-sensitive:** `int` ≠ `Int` ≠ `INT`
- **Semicolons required:** End every statement with `;`
- **Define before use:** Variables must be declared before using
- **Comments:** Use `//` for single line, `/* */` for multi-line
- **Script order matters:** Build land before placing objects on it

**Example:**
```cpp
// This is a comment
int myVar = 5;  // Semicolon required

/* Multi-line comment
   for longer explanations */
```

---

## **5.** 🗺️ Map Grid & Measurement System

### **5.1. Coordinate System**

**Map Grid:** X, Z coordinates (Y is elevation)
- Origin `(0, 0)` = Bottom of screen
- Center `(0.5, 0.5)` = Middle of map
- `(1, 0)` = Right corner (3 o'clock)
- `(0, 1)` = Left corner (9 o'clock)
- `(1, 1)` = Top (12 o'clock)

**⚠️ CRITICAL:** The XZ grid is rotated 45° from visual display! (See [Chapter 3: Understanding Coordinates](#3-️-understanding-coordinates-critical))

### **5.2. Tiles & Measurements**

**Tile Size:** 2x2 meters (square tiles)
- Small buildings: 1 tile (2x2m)
- Small units: ¼ tile (1x1m)
- Visible in Scenario Editor: View → Grid
  - White rectangles = 1 tile
  - Blue rectangles = 5x5 tiles (10x10m)

**Map Sizes:**
- 4-player map ≈ 400m per side
- 8-player map ≈ 600m per side
- Scales with player count

**Conversion Functions:**
- `rmXFractionToMeters(fraction)` - Fraction → meters (X axis)
- `rmZFractionToMeters(fraction)` - Fraction → meters (Z axis)
- `rmAreaTilesToFraction(tiles)` - Tiles → map fraction
- `rmMetersToTiles(meters)` - Meters → tiles

**Example:**
```cpp
// Calculate map size based on players
int myTiles = 8000;
int mySize = 2.0 * sqrt(cNumberNonGaiaPlayers * myTiles);
rmSetMapSize(mySize, mySize);
```

---

## **6.** 📦 Finding Object Names

**⚠️ Important:** Game uses protounit names, not display names!

**Path Variables:** This guide uses `<BASE_GAME_PATH>` and `<MOD_WORKSPACE>` - see [Local Machine Configuration](#-local-machine-configuration)

**Search Priority:** Always check mod files FIRST, then base game files.

### **6.1. Protounit Names (Units & Buildings)**

**Display Name → Protounit Name:**
- "Villager" → `"Settler"`
- "Town Center" → `"TownCenter"`
- "Outpost" → `"Outpost"`

**Generic Locations:**
1. **Your Mod:** `<MOD_WORKSPACE>/data/protomods.xml` (if your mod has custom units)
2. **Base Game:** `<BASE_GAME_PATH>/scripts/source/protoy.xml`

**How to Find:**
1. Open file in XML Viewer (recommended: Mindfusion XML Viewer)
2. Search for unit name
3. Look for `<unit name="ProtounitName">`
4. Use exact name in script

**See detailed examples:** [Chapter 12: Reference Documentation → Resource Types](#121-resource-types-huntables-fish-whales-mines-berries)

### **6.2. Water Types**

**Generic Locations:**
1. **Your Mod:** `<MOD_WORKSPACE>/data/waterbodies2.xml` ⭐ (Check FIRST if exists)
2. **Base Game:** `<BASE_GAME_PATH>/scripts/source/waterbodies.xml`

**See detailed guide:** [Chapter 12: Reference Documentation → Water Types](#122-water-types)

### **6.3. Terrain Names**

**Terrain Types (individual textures):**
- **Base Game:** `<BASE_GAME_PATH>/scripts/source/art/terrain/terraintypes.xml`
- Format: `"folder\texture_name"`
- Example: `"texas\ground2_tex"`, `"yukon\ground1_yuk"`

**Terrain Mixes (blended combinations):**
- **Base Game:** `<BASE_GAME_PATH>/scripts/source/art/terrain/mix/` (258 XML files)
- ⚠️ Use filename WITHOUT .xml extension
- ⚠️ Use underscores not spaces: `"italy_grass"` ✅ NOT `"italy grass"` ❌

**See detailed guide:** [Chapter 12: Reference Documentation → Terrain Types vs Mixes](#123-terrain-types-vs-terrain-mixes)

### **6.4. Cliff Types**

**Generic Locations:**
1. **Your Mod:** `<MOD_WORKSPACE>/data/clifftypes2.xml` (if your mod has custom cliffs)
2. **Base Game:** `<BASE_GAME_PATH>/scripts/source/clifftypes.xml`

**See detailed guide:** [Chapter 12: Reference Documentation → Cliff Types](#124-cliff-types)

### **6.5. Forest Types**

**Base Game Locations:**
1. `<BASE_GAME_PATH>/scripts/source/forest.xml` (29 types)
2. `<BASE_GAME_PATH>/scripts/source/forest2.xml` (49+ types)

**See detailed guide:** [Chapter 12: Reference Documentation → Forest Types](#125-forest-types)

### **6.6. Native Civilizations (Subcivs)**

**Generic Locations:**
1. **Your Mod:** `<MOD_WORKSPACE>/data/civmods.xml` (if your mod has custom natives)
2. **Base Game:** `<BASE_GAME_PATH>/scripts/source/civs.xml`

**See detailed guide:** [Chapter 12: Reference Documentation → Native Civilizations](#126-native-civilizations-subcivs)

### **6.7. Map Types**

**Base Game Location:** `<BASE_GAME_PATH>/scripts/source/maptypes.xml`

Examples: `"water"`, `"land"`, `"grass"`, `"snow"`

**See detailed guide:** [Chapter 12: Reference Documentation → Map Types](#127-map-types-gameplay-ai-behavior-treasures)

### **6.8. Technology Names**

**Base Game Location:** `<BASE_GAME_PATH>/scripts/source/techtree.xml`

Examples: attack upgrades, armor, hitpoints, etc.

### **6.9. Trigger Names**

**Age of Pirates Location:** `<MOD_WORKSPACE>/data/trigger/triggerdata.xml`

Used for scenario-style events in random maps.

**See detailed guide:** Map Triggers (Chapter 31 - in uncategorized section)

### **6.10. RM Commands**

**Documentation:** [rm_commands_reference.md](rm_commands_reference.md)

All 274 Random Map functions with signatures and descriptions.

**⚠️ DO NOT edit base game XML files - will break game! Only read them for reference.**

[↑ Back to Table of Contents](#2--table-of-contents)

---

## **7.** 🏴‍☠️ Age of Pirates Localization

**This section is specific to the Age of Pirates mod.**

**⚠️ IMPORTANT FOR AI ASSISTANTS:**
Age of Pirates has **pre-extracted base game reference files** in the mod workspace. This means you can directly read files without extracting .bar archives. All paths below are relative to `<MOD_WORKSPACE>`.

---

### **7.1. File Locations (Age of Pirates Specific)**

#### Custom Mod Content (Age of Pirates Only)

**These files contain Age of Pirates custom content - ALWAYS CHECK THESE FIRST:**

- `data/waterbodies2.xml` - Custom water types with "ZP" prefix (e.g., "ZP Mediterranean", "ZP Caribbean Coast")
- `data/clifftypes2.xml` - Custom cliff types  
- `data/civmods.xml` - Custom native civilizations
- `data/protomods.xml` - Custom units and buildings
- `data/maptypemods.xml` - Custom map types (e.g., `"piratehistoricalmap"`)
- `data/techtreemods.xml` - Custom technologies
- `data/trigger/triggerdata.xml` - Trigger definitions (Age of Pirates specific)

#### Base Game Reference Files (Pre-extracted)

**These base game files are extracted from .bar archives and included in the Age of Pirates repository for easy access:**

- `scripts/source/protoy.xml` - Unit and building definitions
- `scripts/source/waterbodies.xml` - Base game water types
- `scripts/source/clifftypes.xml` - Base game cliff types
- `scripts/source/civs.xml` - Base game native civilizations
- `scripts/source/forest.xml` - Forest types (29 types)
- `scripts/source/forest2.xml` - Additional forest types (49+ types)
- `scripts/source/maptypes.xml` - Map type definitions
- `scripts/source/techtree.xml` - Technology definitions
- `scripts/source/art/terrain/terraintypes.xml` - Terrain texture definitions
- `scripts/source/art/terrain/mix/` - Terrain mix definitions (258 XML files)

**Note:** Original base game files are in `<BASE_GAME_PATH>/*.bar` archives. Age of Pirates has pre-extracted copies so you don't need bar extraction tools.

#### Map Scripts & Groupings

- `randmaps/` - Your custom random map `.xs` files
- `game/randmaps/` - Alternative location for map scripts
- `game/randmaps/groupings/` - Native village and city state groupings (100+ XML files)

#### Documentation

- `docs/` - This documentation folder

### **7.2. Age of Pirates Naming Conventions**

**Map Files:**

*Production Maps (in mod folders):*
- Prefix: `zp` (identifies Age of Pirates)
- Location: `<MOD_WORKSPACE>/randmaps/` or `<MOD_WORKSPACE>/game/randmaps/`
- Example: `zpBalearicIslands.xs`, `zpCaribbean.xs`

*WIP Maps (work in progress):*
- Prefix: `000zp` (sorts to top for easy access during development)
- Location: Game's root randmaps folder (outside mod)
- Example: `000zpBalearicIslands.xs`, `000zpCaribbean.xs`

**Custom Types:**
- Water types: "ZP" prefix (e.g., `"ZP Mediterranean"`, `"ZP Caribbean Coast"`)
- Always check `data/waterbodies2.xml` FIRST before base game files


### **7.3. Search Priority for Age of Pirates**

When looking for type names, **always search in this order:**

1. **Mod files first:** `<MOD_WORKSPACE>/data/` (waterbodies2.xml, clifftypes2.xml, etc.)
2. **Base game second:** `<MOD_WORKSPACE>/scripts/source/` (pre-extracted reference files)

**Example workflow:**
```
Looking for water type "Caribbean"?
1. Check: <MOD_WORKSPACE>/data/waterbodies2.xml → Found "ZP Caribbean Coast" ✅
2. If not found, check: <MOD_WORKSPACE>/scripts/source/waterbodies.xml
```

**Why this works:**
- All files are in `<MOD_WORKSPACE>` - no need to access `<BASE_GAME_PATH>`
- Pre-extracted files mean direct access without .bar tools
- AI assistants can read files immediately

### **7.4. Age of Pirates Specific Features**

**Custom Groupings:**
- Extensive pirate village groupings
- Custom harbour groupings on platforms
- Special city state definitions
- See: `game/randmaps/groupings/` folder

**Custom Resources:**
- Modified treasure types
- Pirate-themed decorative objects
- Custom fish and whale types

**Custom Map Patterns:**
- Player vs Team island patterns optimized for pirates
- Trade socket placement patterns
- Special cliff and ramp configurations

See detailed sections below for usage examples.

---

### **7.5. File Organization**

#### **For New Map Development:**

```
<BASE_GAME_PATH>/Game/RandMaps/
├── 000zpBalearicIslands.xs   (script - place here for testing)
├── 000zpBalearicIslands.xml  (metadata - place here for testing)
└── 000zpBalearicIslands.md   (documentation - place here)
```

#### **Reference Files (in mod workspace):**

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

<workspace>/data/
├── waterbodies2.xml             (⚠️ CHECK FIRST: Mod-specific water types! "ZP" prefix)
└── clifftypes2.xml              (⚠️ CHECK: Mod-specific cliff types!)
```

---

## **8.** 💻 Local Machine Configuration

**Setup Instructions:**

1. **Copy the template:** `docs/config.template.md` → `docs/config.local.md`
2. **Update with YOUR paths** in `config.local.md`
3. **File is gitignored** - won't be committed to repository

### **8.1. Path Variables Used in This Guide**

Throughout this documentation, you'll see these placeholders:

**`<BASE_GAME_PATH>`**
- Your Age of Empires III: Definitive Edition installation folder
- Default Windows (Steam): `C:\Program Files (x86)\Steam\steamapps\common\AoE3DE`
- Default Windows (MS Store): `C:\Program Files\WindowsApps\Microsoft.AgeOfEmpires3DE_[version]`

**`<MOD_WORKSPACE>`**
- Your mod's root folder
- For Age of Pirates: Usually in `C:\Users\[YourName]\Games\Age of Empires 3 DE\[SteamID]\mods\local\age-of-pirates`
- Contains: `data/`, `randmaps/`, `docs/`, etc.

### **8.2. How to Use Path Variables**

**In documentation, you see:**
```
<BASE_GAME_PATH>/scripts/source/waterbodies.xml
```

**On your machine, this becomes:**
```
C:\Program Files (x86)\Steam\steamapps\common\AoE3DE\scripts\source\waterbodies.xml
```

### **8.3. Quick Setup**

**Edit `config.local.md` with your paths:**
```markdown
## My Local Paths

- **BASE_GAME_PATH:** C:\Program Files (x86)\Steam\steamapps\common\AoE3DE
- **MOD_WORKSPACE:** C:\Users\TIGO\Games\Age of Empires 3 DE\76561198347905238\mods\local\age-of-pirates
```

**For AI Assistants:**
- Always ask user for their paths on first run
- Substitute `<BASE_GAME_PATH>` and `<MOD_WORKSPACE>` with actual paths
- Reference `config.local.md` for user's specific setup

---

## **9.** 📁 Map Folder Structure

### **9.1. Three Map Locations**

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

2. **Mod Folder - Advanced Maps (PRODUCTION):**
   ```
   <MOD_WORKSPACE>/randmaps/
   ```
   - ✅ Use for **advanced maps with custom protounits/objects**
   - ✅ Can include `<mapname>.mods.xml` file with map-specific protounit modifications
   - ✅ Mods files follow protomods structure but apply only to specific map
   - ✅ Example: `zpblacksea.mods.xml` alongside `zpblacksea.xs`
   - ✅ Included in mod distribution

3. **Mod Game Subfolder - Generic Maps (PRODUCTION):**
   ```
   <MOD_WORKSPACE>/game/randmaps/
   ```
   - ✅ Use for **generic maps without special requirements**
   - ✅ No `.mods.xml` file needed
   - ✅ Mirrors root game structure
   - ✅ Can override base game maps by using same filename
   - ✅ Included in mod distribution

**Key Difference:**
- `randmaps/` = Advanced maps + optional mapmods support
- `game/randmaps/` = Generic maps, no special dependencies

---

## **10.** 📋 Required Files

Every random map needs **two required files** and **one optional file:**

### **10.1. `.xs` File (Script)**
The actual map generation code (XS language).

**Template:**
```cpp
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

### **10.2. `.xml` File (Metadata)**
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

### **10.3. `.mods.xml` File (Optional - Map-Specific Mods)**

**⚠️ OPTIONAL:** Only needed for advanced maps that require map-specific protounit modifications.

**Naming Convention:** `<mapname>.mods.xml`
- Example: `zpblacksea.mods.xml` for `zpblacksea.xs`

**Location:** Place alongside `.xs` and `.xml` files in `<MOD_WORKSPACE>/randmaps/`

**Purpose:**
- Override/modify protounit properties **only for this specific map**
- Follows same structure as global `protomods.xml` but applies locally
- Use for map-specific visual/behavior changes without affecting entire mod

**Template:**
```xml
<?xml version="1.0"?>
<mods>
  <protomods>
    <!-- Map-specific protounit modifications -->
    <unit name="UnitName">
      <placementfile>newplacement.xml</placementfile>
      <obstructionradiusx>4.0</obstructionradiusx>
      <obstructionradiusz>4.0</obstructionradiusz>
      <flag>NotSelectable</flag>
      <civflagoverride>objects\flags\ottoman_sultanate</civflagoverride>
    </unit>
  </protomods>
</mods>
```

**Common Use Cases:**
- Change building placement rules for urban maps
- Modify unit flags (NotSelectable, NoIdleActions, etc.)
- Override civ flags for scenario elements
- Adjust obstruction radius for tight spaces
- Change animation files for visual variants

**Simple Example:** `zpcaribbeanwars.mods.xml`
```xml
<?xml version="1.0"?>
<mods>
  <protomods>
    <unit name="zpSPCFixedGun">
      <animfile>buildings\fixed_gun\fixed_gun_pirate.xml</animfile>
    </unit>
  </protomods>
</mods>
```

**Complex Example:** See `zpblacksea.mods.xml` (170 lines) - modifies 60+ units for city map

---

## **11.** 🚀 Simple Complete Example

**A minimal working map for learning** - MySimpleMap

This example creates a flat terrain map with Town Centers for each player placed in a circle.

### **11.1. MySimpleMap.xs**

```cpp
/* A SIMPLE RANDOM MAP - by Tutorial - Version 1.0 */

include "mercenaries.xs";  // Required for standard gameplay

void main(void) {
    rmSetStatusText("", 0.01);  // Progress bar start
    
    // ===== MAP SIZE =====
    int myTiles = 8000;
    if (cMapSize == 1) {  // Check if large map selected
        myTiles = 12000;
        rmEchoInfo("Large map");
    }
    
    // Calculate map size proportional to player count
    int mySize = 2.0 * sqrt(cNumberNonGaiaPlayers * myTiles);
    rmEchoInfo("Map size = " + mySize + "m x " + mySize + "m");
    rmSetMapSize(mySize, mySize);
    
    rmSetStatusText("", 0.20);
    
    // ===== TERRAIN =====
    rmSetSeaLevel(0);  // Height of water
    rmSetSeaType("Amazon River");  // Water texture if used
    rmTerrainInitialize("texas\ground2_tex", 4);  // Base terrain at height 4
    
    rmSetStatusText("", 0.40);
    
    // ===== PLAYER PLACEMENT =====
    // Place players in circle (30% from edge, no rotation)
    rmPlacePlayersCircular(0.3, 0.3, rmDegreesToRadians(0.0));
    
    // Create area for each player
    for (i = 1; <= cNumberNonGaiaPlayers) {
        // Define player area
        int id = rmCreateArea("Player" + i);
        rmSetAreaBaseHeight(id, 4.0);  // Height
        rmSetAreaCoherence(id, 1.0);   // 1.0 = smooth circle
        rmSetAreaHeightBlend(id, 2);   // Blend with surroundings
        rmSetAreaLocPlayer(id, i);     // Center on player start
        rmSetAreaSize(id, 0.001, 0.001);  // Very small area
        rmSetPlayerArea(i, id);        // Assign to player
        rmSetAreaTerrainType(id, "texas\ground3_tex");  // Different texture
        rmBuildArea(id);  // Create the area
        
        // Place Town Center for player
        int towncenterID = rmCreateObjectDef("Starting Towncenter" + i);
        rmAddObjectDefItem(towncenterID, "TownCenter", 1, 0.0);
        rmPlaceObjectDefAtLoc(towncenterID, i, 
                             rmPlayerLocXFraction(i), 
                             rmPlayerLocZFraction(i), 1);
    }
    
    rmSetStatusText("", 1.00);  // Progress bar complete
}
```

### **11.2. MySimpleMap.xml**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<mapinfo detailsText="My Simple Map Description" 
         imagepath="ui\random_map\all_maps" 
         displayName="My Simple Map"
         cannotReplace=""
         loadDetails="" 
         loadBackground="ui\random_map\all_maps">
    <loadss>ui\random_map\new_england\new_england_ss_01</loadss>
    <loadss>ui\random_map\new_england\new_england_ss_02</loadss>
    <loadss>ui\random_map\new_england\new_england_ss_03</loadss>
</mapinfo>
```

### **11.3. How to Test This Map**

1. **Save both files** in: `C:\...\Age of Empires III\RandMaps\`
   - `MySimpleMap.xs`
   - `MySimpleMap.xml`

2. **Enable Debugger** (for testing):
   - Create desktop shortcut to Age3.exe
   - Right-click → Properties
   - Add to target: `+debugRandomMaps`
   - Example: `"C:\...\Age3.exe" +debugRandomMaps`

3. **Test in Scenario Editor:**
   - Launch game with debugger shortcut
   - Open Scenario Editor
   - File → New → Select "MySimpleMap"
   - Click Debugger button
   - Generate map

4. **Play Test:**
   - **MOVE files** (don't copy) to: `C:\...\My Documents\My Games\Age of Empires III\RM\`
   - Start Skirmish game
   - Select map from Custom Maps

### **11.4. What This Map Does**

- **Flat terrain** with "texas\ground2_tex" texture
- **Circular player placement** at 30% radius
- **Small player areas** with different texture around each start
- **One Town Center** per player at their starting location
- **Scales automatically** for 2-8 players, normal/large maps

### **11.5. Next Steps**

Once this works, try:
- Adding starting Villagers: `rmAddObjectDefItem(towncenterID, "Settler", 5, 4.0);`
- Changing terrain textures
- Adding trees, resources, or native villages
- See advanced sections for complex patterns

---

## **12.** 📚 Reference Documentation

### **12.1. RM Commands List**

**Reference:** [rm_commands_reference.md](rm_commands_reference.md)

**Contains:** 274 commands with signatures and descriptions

**⚠️ AI MUST READ when creating maps!**

**Key command categories:**
- **Terrain:** `rmTerrainInitialize()`, `rmSetSeaType()`, `rmSetBaseTerrainMix()`
- **Players:** `rmPlacePlayersCircular()`, `rmSetPlayerArea()`
- **Areas:** `rmCreateArea()`, `rmBuildArea()`, `rmSetAreaSize()`
- **Objects:** `rmCreateObjectDef()`, `rmPlaceObjectDefAtLoc()`
- **Resources:** `rmAddObjectDefItem()`, `rmPlaceObjectDefInArea()`
- **Natives:** `rmCreateGrouping()`, `rmPlaceGroupingAtLoc()`
- **Trade Routes:** `rmCreateTradeRoute()`, `rmAddTradeRouteWaypoint()`

### **12.2. Water Types**
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

### **12.3. Terrain Types vs. Terrain Mixes**

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

### **12.4. Cliff Types**

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

### **12.5. Resource Types (Huntables, Fish, Whales, Mines, Berries)**

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
```cpp
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
```cpp
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
```cpp
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
```cpp
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
```cpp
string berryType = "BerryBush";
rmAddObjectDefItem(berryID, berryType, 5, 4.0);  // 5 bushes, 4.0 cluster spread
```

---

#### **Variable Organization (Best Practice)**

⚠️ **ALWAYS define type names as variables at the top of the .xs file!**

This makes it easy to change themes and maintain consistency.

**Example from zpIceland.xs:**

```cpp
// WATER TYPES
string wetTypeSea = "ZP Iceland";
string wetTypeLake = "ZP Iceland Lake";

// TERRAIN TYPES
string volcTerrainLow = "lava\\volcano_snow";
string volcTerrainHigh = "lava\\volcano_dirt";
string volcTerrainCrater = "lava\\crater";

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

```cpp
rmSetSeaType(wetTypeSea);  // Instead of hardcoded "ZP Iceland"
rmSetAreaMix(someArea, paintMix2);  // Instead of "italy_snow_grass"
rmSetAreaCliffType(cliffArea, volcCliffLow);  // Instead of "ZP Iceland Low"
```

**Benefits:**

✅ Change entire map theme by editing one place  
✅ Easy to spot which resources are used  
✅ Prevents typos in hardcoded strings  
✅ Clear documentation of map dependencies  

---

### **12.6. Map Types (Gameplay, AI Behavior, Treasures)**

Map types are defined in `scripts/source/maptypes.xml` (base game) and `data/maptypemods.xml` (mod-specific). They control:
- AI behavior (land vs water strategies)
- Treasure/nugget types spawned
- Trade route types
- Special gameplay modifiers

**Where to find map types:**
- **Base game types (124 types):** `<MOD_WORKSPACE>/scripts/source/maptypes.xml`
  - Standard types: `"water"`, `"land"`, `"snow"`, `"grass"`, `"tropical"`, `"desert"`, `"mountain"`
  - Region types: `"caribbean"`, `"mediterranean"`, `"amazonia"`, `"siberia"`, etc.
  - AI behavior types: `"AITransportRequired"`, `"AIFishingUseful"`, etc. ⚠️ **DEPRECATED** - Have no effect unless specifically defined in AI scripts
  - Trade route types: `"euroNavalTradeRoute"`, `"euroLandTradeRoute"`, etc.
- **Age of Pirates types (19 types):** `<MOD_WORKSPACE>/data/maptypemods.xml`
  - Custom regions: `"caribbeanwater"`, `"malta"`, `"burma"`, `"hawaii"`, `"australia"`, etc.
  - Special: `"piratehistoricalmap"`



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

```cpp
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

### **12.7. Native Civilizations (Subcivs)**

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

```cpp
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

### **12.8. Forest Types**

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

## **13.** 🧩 Map Properties

### **13.1. Map Size & Scaling**

**Command:** `rmSetMapSize(int x, int z)` - Sets the dimensions of the map in meters.

**When to call:** Very early in `main()`, right after `rmSetStatusText()` and before terrain initialization.

**Parameters:**
- `x` - Width in meters
- `z` - Height/depth in meters
- Both parameters are typically the same for square maps

---

#### **Four Map Size Patterns:**

### **Pattern 1: Dynamic Calculation (Generic - Balearic Islands)**

**Best for:** Standard competitive maps that need balanced scaling with player count.

**How it works:** Calculate map size using a formula that scales proportionally with square root of players × tile budget.

```cpp
// Set size based on player count with dynamic calculation
int playerTiles = 23000;              // Base tile budget per player

// Adjust tile budget for fewer players (give more space)
if (cNumberNonGaiaPlayers < 5)
    playerTiles = 25500;
if (cNumberNonGaiaPlayers < 3)
    playerTiles = 29500;

// Calculate map size: 2.0 * sqrt(players * tiles)
int size = 2.0 * sqrt(cNumberNonGaiaPlayers * playerTiles);
rmEchoInfo("Map size=" + size + "m x " + size + "m");
rmSetMapSize(size, size);
```

**Result sizes (approximately):**
- 2 players: ~486m × 486m
- 3 players: ~595m × 595m
- 4 players: ~638m × 638m
- 6 players: ~740m × 740m
- 8 players: ~770m × 770m

**Advantages:**
- ✅ Smooth scaling with player count
- ✅ Maintains consistent player space (tiles per player)
- ✅ Industry standard formula
- ✅ Works for any player count

**When to use:**
- Standard island/naval maps
- Competitive/balanced maps
- When you want consistent resource density

---

### **Pattern 2: Rectangular/Linear Scaling (Great Barrier Reef)**

**Best for:** Elongated/rectangular maps where only one dimension should scale.

**How it works:** One axis scales linearly with players, other axis stays relatively fixed.

```cpp
// Rectangular map - X axis scales with players, Y axis mostly static
int sizeX = 200 * cNumberNonGaiaPlayers;   // Width scales linearly
int sizeY = 320;                            // Height is fixed

// Special case for 2-player KOTH
if (cNumberNonGaiaPlayers == 2) {
    if (rmGetIsKOTH()) {
        sizeX = 500;
    }
    sizeY = 320;
}

rmSetMapSize(sizeY, sizeX);   // NOTE: Y first, X second!
```

**Result sizes:**
- 2 players: 320m × 400m (or 320m × 500m for KOTH)
- 4 players: 320m × 800m
- 6 players: 320m × 1200m
- 8 players: 320m × 1600m

**Advantages:**
- ✅ Perfect for barrier reef, river, or coastal maps
- ✅ Creates "long and narrow" gameplay
- ✅ Forces linear player placement
- ✅ Simple linear calculation

**When to use:**
- Barrier reef/coastal strip maps
- River/canal maps
- Maps with linear geography (chain of islands)

---

### **Pattern 3: Stepped Fixed Sizes (Black Sea)**

**Best for:** Maps with distinct layouts for different player count ranges.

**How it works:** Predefined size brackets that jump at specific player count thresholds.

```cpp
// Stepped sizes based on player count ranges
int size = 450;                         // Default: 1-2 players

if (cNumberNonGaiaPlayers > 2) {
    size = 530;                         // 3-4 players
}
if (cNumberNonGaiaPlayers > 4) {
    size = 580;                         // 5-6 players
}
if (cNumberNonGaiaPlayers > 6) {
    size = 640;                         // 7-8 players
}

rmSetMapSize(size, size);
```

**Result sizes:**
- 1-2 players: 450m × 450m
- 3-4 players: 530m × 530m
- 5-6 players: 580m × 580m
- 7-8 players: 640m × 640m

**Advantages:**
- ✅ Simple to understand
- ✅ Predictable map sizes
- ✅ Easy to tune per player count range
- ✅ Can optimize layouts for specific brackets
- ✅ More control than "almost fixed" but simpler than formulas

**When to use:**
- Maps with hand-crafted layouts
- When you need specific sizes for art/design reasons
- Historical maps with fixed geography
- When you want more size options than "almost fixed"

---

### **Pattern 4: Almost Fixed / Minimally Scaled (Aztec City)**

**Best for:** Scenario/city defense maps where the map size should remain mostly constant.

**How it works:** Hardcoded sizes with minimal variation. Map barely scales - only 2-3 size options total.

```cpp
// Almost fixed - only 2 sizes
int size = 540;                       // Default for 1-4 players (most games)

if (cNumberNonGaiaPlayers > 4) {
    size = 600;                       // Slightly larger for 5-8 players
}

rmSetMapSize(size, size);
```

**Result sizes:**
- 1-4 players: 540m × 540m (same size whether 2v2 or 1v1v1v1)
- 5-8 players: 600m × 600m (only 11% larger!)

**Key characteristic:** Size barely changes. An 8-player game is almost the same size as a 2-player game.

**Advantages:**
- ✅ Extremely simple code
- ✅ Very consistent map experience
- ✅ Perfect for fixed scenarios
- ✅ Easy to design around (nearly identical layout)
- ✅ No scaling calculations needed

**When to use:**
- Scenario/defense maps with fixed layouts
- City maps (like Aztec City Defense)
- Maps with pre-placed elements that don't scale
- Historical recreations requiring exact geography
- When layout consistency > per-player space

**⚠️ Important:** More players = significantly more crowded. Use only when:
- Map design is intentionally tight/compact
- Scenario mechanics don't require per-player space
- Fixed layout is more important than spacing
- You want the SAME map experience regardless of player count

---

### **Pattern 5: Rectangular Stepped (Paris)**

**Best for:** City/river maps with constrained dimensions that need predictable size brackets.

**How it works:** One axis is fixed, the other axis uses stepped sizes (combining Pattern 2 + Pattern 3).

```cpp
// Rectangular with stepped X axis, fixed Z axis
int sizeZ = 360;              // Height FIXED (constant for all player counts)
int sizeX = 573;              // Width STEPPED (default: 1-2 players)

if (cNumberNonGaiaPlayers >= 3)
    sizeX = 653;              // 3-5 players
if (cNumberNonGaiaPlayers >= 6)
    sizeX = 773;              // 6-8 players

rmSetMapSize(sizeX, sizeZ);   // Note: X first, Z second
```

**Result sizes:**
- 1-2 players: 573m × 360m
- 3-5 players: 653m × 360m
- 6-8 players: 773m × 360m

**Key characteristic:** Combines rectangular shape with stepped brackets instead of continuous/linear scaling.

**Advantages:**
- ✅ Perfect for maps with geographic constraints (rivers, cities)
- ✅ More control over size jumps than linear
- ✅ Predictable sizes (not continuous)
- ✅ Can optimize layout for specific brackets
- ✅ One dimension stays constant (consistent feature placement)

**When to use:**
- City maps with fixed height/width (like Paris along Seine)
- River/canyon maps where one dimension is constrained by geography
- Historical maps requiring specific aspect ratios
- When you want rectangular shape + size brackets (not linear)

**Comparison to other rectangular approaches:**
- vs **Pattern 2 (Barrier Reef - Linear):** More control, predictable jumps vs smooth scaling
- vs **Pattern 3 (Black Sea - Square Stepped):** Maintains aspect ratio, one axis fixed

---

#### **Comparison Table:**

| Pattern | Scaling Type | Code Complexity | Flexibility | Best For |
|---------|-------------|-----------------|-------------|----------|
| **Dynamic** | Proportional (√) | Low | High | Standard maps |
| **Rectangular Linear** | Linear (one axis) | Low | Medium | Long/narrow maps |
| **Stepped Fixed** | Brackets (4 sizes) | Very Low | Low | Hand-crafted maps |
| **Almost Fixed** | Hardcoded (2 sizes) | Very Low | Very Low | Scenario/city maps |
| **Rectangular Stepped** | Brackets (one axis) | Very Low | Low | City/river maps |

---

#### **Important Constants:**

```cpp
// Game constants available for map size logic
cNumberNonGaiaPlayers    // Total number of players (excluding Gaia/Mother Nature)
cNumberPlayers           // Total including Gaia (usually +1)
cNumberTeams             // Number of teams
cMapSize                 // 0=small, 1=large (selected in lobby)
```

**Using cMapSize for lobby options:**
```cpp
int playerTiles = 23000;

// Allow players to select Large map in lobby
if (cMapSize == 1) {
    playerTiles = 30000;     // 30% larger
    rmEchoInfo("Large map selected");
}

int size = 2.0 * sqrt(cNumberNonGaiaPlayers * playerTiles);
rmSetMapSize(size, size);
```

---

#### **Best Practices:**

✅ **Always echo the final map size** for debugging  
✅ **Call rmSetMapSize() early** (before terrain/elevation setup)  
✅ **Use consistent formulas** across similar maps  
✅ **Test all player counts** (2, 4, 6, 8 players minimum)  
✅ **Consider resource scaling** - larger maps need more resources  
✅ **Square maps use same X/Z** - rectangular maps can differ  

⚠️ **Avoid extremely large maps** (>800m) - performance issues  
⚠️ **Avoid extremely small maps** (<300m) - cramped gameplay  
⚠️ **Don't forget single-player** - test with cNumberNonGaiaPlayers == 1

---

### **13.2. Classes**

**What they are:** Classes are **groups/categories** that you assign to areas or objects so you can refer to them collectively later, especially in constraints.

**Purpose:** Instead of creating constraints for each individual island/forest/player area, you group them into classes and create ONE constraint that applies to the whole class.

**Commands:**
- `rmDefineClass(string className)` - Define a new class
- `rmAddAreaToClass(int areaID, int classID)` - Add area to class
- `rmAddObjectDefToClass(int objectDefID, int classID)` - Add object to class
- `rmClassID(string name)` - Get class ID by name (for classes defined without storing ID)

---

#### **How Classes Work:**

**Step 1: Define Classes (at the start of script, after includes)**
```cpp
// Classes section - Define all classes early
int classPlayer = rmDefineClass("player");
int classIsland = rmDefineClass("island");
int classBonusIsland = rmDefineClass("bonusIsland");
int classPortSite = rmDefineClass("portSite");
int classMountains = rmDefineClass("mountains");
rmDefineClass("classForest");      // Can define without storing ID
rmDefineClass("classPatch");       // Use rmClassID() to reference later
rmDefineClass("importantItem");
```

⚠️ **CRITICAL:** When using specially defined integer classes, always make sure they're correctly defined as `int` variables BEFORE using them!

```cpp
// ❌ WRONG - Class not stored as int
rmDefineClass("classIsland");
int avoidIsland = rmCreateClassDistanceConstraint("avoid island", classIsland, 30.0);  // ERROR!

// ✅ CORRECT - Class defined as int variable
int classIsland = rmDefineClass("classIsland");
int avoidIsland = rmCreateClassDistanceConstraint("avoid island", classIsland, 30.0);  // Works!
```

**Step 2: Add Areas/Objects to Classes (when creating them)**
```cpp
// Add player area to class
int playerID = rmCreateArea("player " + i);
rmAddAreaToClass(playerID, classIsland);
rmAddAreaToClass(playerID, classPlayer);  // Can belong to multiple classes!

// Add bonus islands to class
rmAddAreaToClass(bonusIslandID, classBonusIsland);
rmAddAreaToClass(bonusIslandID, classIsland);  // thid class

// Add port sites to class
rmAddAreaToClass(portSite1, classPortSite);

// Add forests to class (using rmClassID to reference)
rmAddAreaToClass(forestID, rmClassID("classForest"));
```

**Step 3: Use Classes in Constraints (see Section 10)**

---

#### **Common Class Names:**

Based on Age of Pirates maps (Venice, Cook Islands, etc.):

**Area Classes:**
- **`classPlayer`** - Player starting areas
- **`classIsland`** - All islands (player + bonus + team)
- **`classBonusIsland`** - Non-player islands
- **`classTeamIsland`** - Team islands (team games)
- **`classPortSite`** - Trade route port locations
- **`classMountains`** - Mountain/cliff areas

**Object Classes:**
- **`classForest`** - All forest areas
- **`classPatch`** - Terrain patches (decorative)
- **`classTeamCliff`** - Team cliff areas
- **`classUnderwaterPatch`** - Underwater terrain patches
- **`importantItem`** - Secrets, treasures, special objects
- **`socketClass`** - Trade route sockets

---

#### **Best Practices:**

✅ **Define ALL classes at the top** (before constraints)  
✅ **Use descriptive names** (`classPlayer` not `cp`)  
✅ **Store ID if used multiple times** (`int classPlayer = rmDefineClass("player")`)  
✅ **Areas can belong to multiple classes** (player island = classPlayer + classIsland)  
✅ **Add to class BEFORE adding constraints** to that area  
✅ **Use classes for groups**, types for specific units (`"TownCenter"`, `"mine"`)

---

### **13.3. Constraints**

**What they are:** **Rules that control WHERE things can be placed** - minimum distances, terrain requirements, area avoidance, etc.

**Purpose:** Prevent objects/areas from overlapping, ensure proper spacing, create balanced/fair maps.

**Pattern:** Define constraints → Apply them when creating areas/objects

---

#### **Constraint Types:**

### **A) Class Distance Constraints** (most common!)

Force objects/areas to stay away from ALL members of a class.

```cpp
// Stay away from ALL player areas (any area in classPlayer)
int playerConstraint = rmCreateClassDistanceConstraint("stay away from players", classPlayer, 20.0);
int longPlayerConstraint = rmCreateClassDistanceConstraint("stay away from players long", classPlayer, 35.0);
int shortPlayerConstraint = rmCreateClassDistanceConstraint("short stay away from players", classPlayer, 5.0);

// Islands avoid each other
int islandConstraint = rmCreateClassDistanceConstraint("islands avoid each other", classIsland, 48.0);

// Forests avoid forests
int forestConstraint = rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("classForest"), 7.0);

// Bonus islands constraints
int avoidBonusIslands = rmCreateClassDistanceConstraint("stuff avoids bonus islands", classBonusIsland, 100.0);
```

**Common distances:**
- Short: 5-10m (resources, decorations)
- Medium: 10-25m (player areas, important objects)
- Long: 35-75m (natives, bonus islands)
- Very long: 100m+ (major landmarks)

---

### **B) Type Distance Constraints** (specific unit/object types)

Force spacing between specific object types (units, buildings, resources).

```cpp
// Avoid Town Centers
int avoidTC = rmCreateTypeDistanceConstraint("avoid Town Center", "townCenter", 10.0);
int avoidTCFar = rmCreateTypeDistanceConstraint("avoid Town Center Far", "townCenter", 40.0);

// Resources avoid resources
int avoidResource = rmCreateTypeDistanceConstraint("resource avoid resource", "resource", 10.0);
int shortAvoidResource = rmCreateTypeDistanceConstraint("resource avoid resource short", "resource", 5.0);

// Nuggets avoid nuggets
int avoidNugget = rmCreateTypeDistanceConstraint("nugget vs. nugget", "AbstractNugget", 40.0);
int avoidNuggetsFar = rmCreateTypeDistanceConstraint("nugget vs. nugget far", "AbstractNugget", 70.0);

// Specific resources
int avoidSilver = rmCreateTypeDistanceConstraint("avoid silver", "mine", 65.0);
int avoidHerdable = rmCreateTypeDistanceConstraint("herdables avoid herdables", herdableType, 75.0);
int avoidBerries = rmCreateTypeDistanceConstraint("avoid berries", "berrybush", 55.0);

// Units
int avoidHuntable = rmCreateTypeDistanceConstraint("avoid huntable", huntable1, 60.0);

// Special objects
int avoidSocket = rmCreateTypeDistanceConstraint("avoid socket", "Socket", 20.0);
int avoidKOTH = rmCreateTypeDistanceConstraint("stay away from Kings Hill", "ypKingsHill", 30.0);

// General
int avoidAll = rmCreateTypeDistanceConstraint("avoid all", "all", 7.0);
```

**Common type names:**
- `"townCenter"`, `"TownCenter"` - Town Centers
- `"resource"` - All resources
- `"mine"` - Mines (silver, gold)
- `"AbstractNugget"` - Treasures
- `"berrybush"` - Berry bushes
- `"huntable"` - Huntable animals
- `"all"` - Everything

---

### **C) Terrain Distance Constraints** (land/water)

Control placement based on terrain passability.

```cpp
// Land objects avoid impassable land (water/cliffs)
int avoidImpassableLand = rmCreateTerrainDistanceConstraint("avoid impassable land", "Land", false, 6.0);
int shortAvoidImpassableLand = rmCreateTerrainDistanceConstraint("short avoid impassable land", "Land", false, 2.0);
int longAvoidImpassableLand = rmCreateTerrainDistanceConstraint("long avoid impassable land", "Land", false, 10.0);

// Ships stay in water, avoid land
int avoidLand = rmCreateTerrainDistanceConstraint("ship avoid land", "land", true, 15.0);

// Fish constraints
int fishLand = rmCreateTerrainDistanceConstraint("fish land", "land", true, 8.0);

// Whales far from shore
int whaleLand = rmCreateTerrainDistanceConstraint("whale land", "land", true, 20.0);
```

**Parameters:**
- `string name` - Descriptive name
- `string terrainType` - `"Land"` or `"land"` (case matters!)
- `bool passable` - `false` = avoid impassable (water), `true` = avoid passable (land)
- `float distance` - Distance in meters

**Max Distance Constraints** (stay CLOSE to terrain):
```cpp
// Stay near water
int riverGrass = rmCreateTerrainMaxDistanceConstraint("stay near the water", "land", false, 6.0);
```

---

### **D) Pie Constraints** (circular/angular areas)

Control placement within circular or wedge-shaped regions.

```cpp
// Keep things away from map edge (full circle)
int playerEdgeConstraint = rmCreatePieConstraint("player edge of map", 
    0.5, 0.5,                                    // Center of map (x, z fractions)
    rmXFractionToMeters(0.0),                   // Inner radius (0 = center)
    rmXFractionToMeters(0.45),                  // Outer radius (90% of map)
    rmDegreesToRadians(0),                       // Start angle
    rmDegreesToRadians(360));                    // End angle (full circle)

// Keep objects in central circle
int circleConstraint = rmCreatePieConstraint("circle Constraint", 
    0.5, 0.5, 
    0, 
    rmZFractionToMeters(0.48), 
    rmDegreesToRadians(0), 
    rmDegreesToRadians(360));

// Edge constraint for whales (keep away from absolute edge)
int whaleEdgeConstraint = rmCreatePieConstraint("whale edge of map", 
    0.5, 0.5, 
    0, 
    rmGetMapXSize() - 20,                        // 20m from edge
    0, 0, 0);

// Flags away from edge
int flagEdgeConstraint = rmCreatePieConstraint("flags away from edge of map", 
    0.5, 0.5, 
    rmGetMapXSize() - 200,                       // Inner radius
    rmGetMapXSize() - 100,                       // Outer radius (creates ring)
    0, 0, 0);
```

---

### **E) Trade Route Constraints**

Keep objects away from trade routes.

```cpp
int avoidTradeRoute = rmCreateTradeRouteDistanceConstraint("objects avoid trade route", 6.0);
int avoidTradeRouteSmall = rmCreateTradeRouteDistanceConstraint("objects avoid trade route small", 6.0);
```

---

### **F) Area-Specific Constraints**

**Area Distance:**
```cpp
int areaConstraint = rmCreateAreaDistanceConstraint("avoid area", areaID, 10.0);
int areaMaxConstraint = rmCreateAreaMaxDistanceConstraint("stay near area", areaID, 20.0);
```

**Area Overlap:**
```cpp
int overlapConstraint = rmCreateAreaOverlapConstraint("no overlap", areaID);
```

---

### **G) Box Constraints** (Rectangular Areas)

Confine objects/areas to rectangular regions. **Ideal for rectangular/non-circular maps.**

**Syntax:**
```cpp
int boxConstraint = rmCreateBoxConstraint("name", 
    minX,     // Left edge (0.0-1.0 fraction)
    minZ,     // Bottom edge (0.0-1.0 fraction)
    maxX,     // Right edge (0.0-1.0 fraction)
    maxZ,     // Top edge (0.0-1.0 fraction)
    buffer);  // Edge buffer (usually 0.01)
```

**Examples from Age of Pirates maps:**

```cpp
// Keep objects away from map edges (rectangular map)
int playerEdgeConstraint = rmCreateBoxConstraint("player edge of map", 
    rmXTilesToFraction(10),          // 10 tiles from left
    rmZTilesToFraction(10),          // 10 tiles from bottom
    1.0 - rmXTilesToFraction(10),    // 10 tiles from right
    1.0 - rmZTilesToFraction(10),    // 10 tiles from top
    0.01);

// Long edge constraint (more buffer)
int longPlayerEdgeConstraint = rmCreateBoxConstraint("long avoid edge of map", 
    rmXTilesToFraction(20), 
    rmZTilesToFraction(20), 
    1.0 - rmXTilesToFraction(20), 
    1.0 - rmZTilesToFraction(20), 
    0.01);

// Confine objects to southern portion of island (Balearic Islands)
int mesaConstraint = rmCreateBoxConstraint("mesas stay in southern portion", 
    0.35, 0.55,    // Start at 35% X, 55% Z
    0.65, 0.35);   // End at 65% X, 35% Z (inverted Z = south)

// Confine huntables to northern side
int northConstraint = rmCreateBoxConstraint("huntable constraint for north side", 
    0.25, 0.55,    // Northwestern region
    0.8, 0.85);
```

**Box vs Pie Constraints - When to Use Which:**

✅ **Use Box Constraints when:**
- Map is rectangular or has non-circular layout
- You need to divide map into specific regions (north, south, east, west)
- Working with river maps or maps with elongated shapes
- Need precise rectangular boundaries

✅ **Use Pie Constraints when:**
- Map is circular or symmetrical around center
- Need radial/circular boundaries (distance from center)
- Placing objects in rings or wedges
- Island maps with circular layout

**Example: Rectangular Map (Wild West style)**
```cpp
// Rectangular map uses box constraints for edge avoidance
int playerEdgeConstraint = rmCreateBoxConstraint("player edge", 
    rmXTilesToFraction(10), rmZTilesToFraction(10),
    1.0 - rmXTilesToFraction(10), 1.0 - rmZTilesToFraction(10), 
    0.01);

// Central river zone (keep players away from middle)
int centralRiver = rmCreateBoxConstraint("central river zone",
    0.4, 0.0,    // 40% from left, full height
    0.6, 1.0);   // 60% from left, full height
```

---

### **H) Water Constraints** (Land/Water Placement)

Control object placement relative to water/land boundaries. **Critical for coastal maps, ships, and water resources.**

---

#### **H.1) Avoid Water (Land Objects)**

Keep land objects away from water. Uses terrain distance with `"Land"` as terrain type and `false` for passable.

**Naming Convention:** Use numbered suffixes (`avoidWater4`, `avoidWater20`) to indicate distance in meters.

```cpp
// Short distance - decorations, small objects
int avoidWater4 = rmCreateTerrainDistanceConstraint("avoid water short", "Land", false, 4.0);

// Medium distance - resources, buildings
int avoidWater8 = rmCreateTerrainDistanceConstraint("avoid water long", "Land", false, 10.0);
int avoidWater20 = rmCreateTerrainDistanceConstraint("avoid water medium", "Land", false, 20.0);

// Long distance - natives, important objects
int avoidWater40 = rmCreateTerrainDistanceConstraint("avoid water super long", "Land", false, 40.0);
```

**Usage examples (Balearic Islands):**
```cpp
// Town Center placement (avoid water)
rmAddObjectDefConstraint(TCID, avoidWater8);

// Silver mines (far from water)
rmAddObjectDefConstraint(silverID, avoidWater8);

// Socket placement (on land, away from water)
rmAddObjectDefConstraint(socketID, avoidWater4);

// King of the Hill (land only)
rmAddObjectDefConstraint(KotHID, avoidWater8);

// Native settlements
rmAddGroupingConstraint(playerNativeID, avoidWater8);   // 2 players
rmAddGroupingConstraint(playerNativeID, avoidWater20);  // 3+ players (more spacing)
```

---

#### **H.2) Avoid Land (Water Objects)**

Keep water objects away from shore. Uses terrain distance with `"land"` as terrain type and `true` for passable.

**Used for:** Ships, water flags, fish, whales, water treasures

```cpp
// Ships stay in water, away from shore
int avoidLand = rmCreateTerrainDistanceConstraint("ship avoid land", "land", true, 15.0);
int avoidLandShort = rmCreateTerrainDistanceConstraint("ship avoid land short", "land", true, 4.0);

// Fish near shore
int fishLand = rmCreateTerrainDistanceConstraint("fish land", "land", true, 8.0);

// Whales far from shore
int whaleLand = rmCreateTerrainDistanceConstraint("whale land", "land", true, 20.0);
```

**Usage example (Balearic Islands - Pearl placement):**
```cpp
// Pearl oysters in water (avoid land)
int pearlNWID = rmCreateObjectDef("pearl northwest");
rmAddObjectDefItem(pearlNWID, "zpPearl", 1, 0);
rmAddObjectDefConstraint(pearlNWID, avoidLandShort);  // Stay in water, 4m from shore
rmPlaceObjectDefAtLoc(pearlNWID, 0, 0.50, 0.4);
```

---

#### **H.3) Ferry On Shore (Coastal Placement)**

**Special constraint for objects that must be NEAR water** (not in water, not far from water).

Uses `rmCreateTerrainMaxDistanceConstraint` - forces objects to stay CLOSE to water edge.

```cpp
// Object must be within 18m of water
int ferryOnShore = rmCreateTerrainMaxDistanceConstraint("ferry v. water", "water", true, 18.0);

// Port placement (close to land)
int portOnShore = rmCreateTerrainDistanceConstraint("port vs land", "land", true, 3.5);
```

**Primary use case: Coastal Native Settlements (Pirates, fishing villages)**

See detailed explanation in: [**Coastal Natives Placement Section**](#coastal-natives-special-settlement-types)

**Usage example (Balearic Islands - Pirate settlement):**
```cpp
// Step 1: Place controller near shore
int pirateControllerID = rmCreateObjectDef("pirate controller " + i);
rmAddObjectDefItem(pirateControllerID, "zpSPCWaterSpawnPoint", 1, 0.0);
rmAddObjectDefConstraint(pirateControllerID, ferryOnShore);  // Must be near water!
rmPlaceObjectDefAtLoc(pirateControllerID, 0, controllerX, controllerZ);

// Step 2: Get controller location
vector pirateControllerLoc = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(pirateControllerID, 0));

// Step 3: Place pirate village at controller location
piratesVillageID = rmCreateGrouping("pirate city", "pirate_village01");
rmAddGroupingConstraint(piratesVillageID, ferryOnShore);  // Settlement near shore
rmPlaceGroupingAtLoc(piratesVillageID, 0, 
    rmXMetersToFraction(xsVectorGetX(pirateControllerLoc)), 
    rmZMetersToFraction(xsVectorGetZ(pirateControllerLoc)), 1);
```

**Why ferryOnShore matters:**
- ✅ Ensures coastal natives spawn ON LAND (not in water)
- ✅ Ensures they're NEAR water (accessible by ships)
- ✅ Creates realistic coastal settlements
- ❌ Without it: Natives spawn too far inland or in water

---

### **I) Cardinal Directions**

⚠️ **CRITICAL:** Map coordinates are **rotated 45° clockwise** from visual appearance!

#### **Visual vs Code Coordinates**

**On minimap (what you SEE):**
```
        North
         ↑
    NW   |   NE
         |
West ←---+---→ East
         |
    SW   |   SE
         ↓
        South
```

**In code (what you WRITE):**
```
Code coordinates rotated 45° clockwise:

         Z=1.0 (Code North = Visual NE)
              ↑
    X=0.0 ←---+---→ X=1.0
(Code W       |       Code E
= Visual NW)  |       = Visual SE)
              ↓
         Z=0.0 (Code South = Visual SW)
```

#### **Conversion Table**

| Visual Direction | Code X | Code Z | Example |
|-----------------|--------|--------|---------|
| **North** (top) | 0.5 | 1.0 | `rmSetAreaLocation(id, 0.5, 1.0)` |
| **South** (bottom) | 0.5 | 0.0 | `rmSetAreaLocation(id, 0.5, 0.0)` |
| **East** (right) | 1.0 | 0.5 | `rmSetAreaLocation(id, 1.0, 0.5)` |
| **West** (left) | 0.0 | 0.5 | `rmSetAreaLocation(id, 0.0, 0.5)` |
| **NE** (top-right) | 0.85 | 0.85 | `rmSetAreaLocation(id, 0.85, 0.85)` |
| **SE** (bottom-right) | 0.85 | 0.15 | `rmSetAreaLocation(id, 0.85, 0.15)` |
| **SW** (bottom-left) | 0.15 | 0.15 | `rmSetAreaLocation(id, 0.15, 0.15)` |
| **NW** (top-left) | 0.15 | 0.85 | `rmSetAreaLocation(id, 0.15, 0.85)` |

#### **Practical Examples**

```cpp
// To place area on VISUAL NORTH (top of minimap)
rmSetAreaLocation(northArea, 0.5, 1.0);  // High Z = North

// To place area on VISUAL SOUTH (bottom of minimap)
rmSetAreaLocation(southArea, 0.5, 0.0);  // Low Z = South

// To place area on VISUAL WEST (left side of minimap)
rmSetAreaLocation(westArea, 0.0, 0.5);   // Low X = West

// To place area on VISUAL EAST (right side of minimap)
rmSetAreaLocation(eastArea, 1.0, 0.5);   // High X = East
```

#### **Box Constraints for Regions**

```cpp
// Keep objects in VISUAL NORTH (top half)
int stayNorth = rmCreateBoxConstraint("stay north", 0.0, 0.5, 1.0, 1.0);
// Args: (name, minX, minZ, maxX, maxZ)
// minZ=0.5 means "only in upper half where Z >= 0.5"

// Keep objects in VISUAL SOUTH (bottom half)
int staySouth = rmCreateBoxConstraint("stay south", 0.0, 0.0, 1.0, 0.5);

// Keep objects in VISUAL WEST (left half)
int stayWest = rmCreateBoxConstraint("stay west", 0.0, 0.0, 0.5, 1.0);

// Keep objects in VISUAL EAST (right half)
int stayEast = rmCreateBoxConstraint("stay east", 0.5, 0.0, 1.0, 1.0);
```

**Key principle:**
- **X axis** = West-East (left-right on minimap)
  - X=0.0 = West (left)
  - X=1.0 = East (right)
- **Z axis** = South-North (bottom-top on minimap)
  - Z=0.0 = South (bottom)
  - Z=1.0 = North (top)

---

#### **Water Constraint Summary:**

| Constraint Type | Terrain Type | Passable | Distance | Use Case |
|----------------|--------------|----------|----------|----------|
| **avoidWater** | `"Land"` | `false` | 4-40m | Land objects (TC, mines, natives) |
| **avoidLand** | `"land"` | `true` | 4-20m | Water objects (ships, pearls, fish) |
| **ferryOnShore** | `"water"` | `true` | Max 18m | Coastal objects (pirate settlements) |
| **portOnShore** | `"land"` | `true` | 3.5m | Ports/docks (very close to shore) |

**Key difference:**
- `rmCreateTerrainDistanceConstraint` = **minimum** distance (stay AWAY from terrain)
- `rmCreateTerrainMaxDistanceConstraint` = **maximum** distance (stay CLOSE to terrain)

---

#### **How to Apply Constraints:**

**To Areas:**
```cpp
int playerID = rmCreateArea("player " + i);
rmAddAreaConstraint(playerID, islandConstraint);      // Islands avoid each other
rmAddAreaConstraint(playerID, playerEdgeConstraint);  // Stay away from edge
rmAddAreaConstraint(playerID, avoidBonusIslands);     // Avoid bonus islands
rmBuildArea(playerID);
```

**To Objects:**
```cpp
int mineID = rmCreateObjectDef("player silver");
rmAddObjectDefItem(mineID, "mine", 1, 0);
rmAddObjectDefConstraint(mineID, playerConstraint);   // Avoid player areas
rmAddObjectDefConstraint(mineID, avoidSilver);        // Avoid other mines
rmAddObjectDefConstraint(mineID, avoidTC);            // Avoid Town Center
rmPlaceObjectDefPerPlayer(mineID, false, 1);
```

**To FairLocs:**
```cpp
int fairLocID = rmAddFairLoc("TownCenter", true, false, 70, 120, 60, 40);
rmAddFairLocConstraint(fairLocID, avoidImpassableLand);
rmAddFairLocConstraint(fairLocID, playerConstraint);
```

---

#### **Best Practices:**

⚠️ **CRITICAL:** All constraints must be defined before they're used! While copy-pasting code snippets from other map scripts, always check if the constraints are defined. Otherwise, the map will cause an error because of an undefined value!

```cpp
// ❌ WRONG - Using undefined constraint
int mineID = rmCreateObjectDef("mine");
rmAddObjectDefConstraint(mineID, avoidMine);  // ERROR if avoidMine not defined!

// ✅ CORRECT - Define constraint first
int avoidMine = rmCreateTypeDistanceConstraint("avoid mine", "mine", 30.0);
int mineID = rmCreateObjectDef("mine");
rmAddObjectDefConstraint(mineID, avoidMine);  // Works!
```

💡 **IMPORTANT:** Copying constraints from other scripts may cause issues when the original constraint has different values. It can result in strange behavior. When values differ, define separate constraints with different names.

⚠️ **CRITICAL:** Having two constraints with the same name will cause an error or unpredictable behavior!

```cpp
// Script A has:
int avoidPlayer = rmCreateTypeDistanceConstraint("avoid player", "AbstractSettlement", 40.0);

// ❌ WRONG - Script B tries to redefine with same name but different value
int avoidPlayer = rmCreateTypeDistanceConstraint("avoid player", "AbstractSettlement", 25.0);  
// This overwrites the first constraint! Now both use 25.0

// ✅ CORRECT Solution 1 - Use descriptive variant names
int avoidPlayer = rmCreateTypeDistanceConstraint("avoid player", "AbstractSettlement", 40.0);
int avoidPlayerShort = rmCreateTypeDistanceConstraint("avoid player short", "AbstractSettlement", 25.0);

// Then use the appropriate one:
rmAddObjectDefConstraint(mineID, avoidPlayer);       // Uses 40.0
rmAddObjectDefConstraint(treeID, avoidPlayerShort);  // Uses 25.0

// ✅ CORRECT Solution 2 - If you only need the 25.0 version, replace it completely
// int avoidPlayer = rmCreateTypeDistanceConstraint("avoid player", "AbstractSettlement", 40.0);  // Comment out or delete
int avoidPlayer = rmCreateTypeDistanceConstraint("avoid player", "AbstractSettlement", 25.0);  // Define only this
```

💡 **IMPORTANT:** When adding constraints to objects or areas, you must add them BEFORE calling `rmBuildArea()`! Adding constraints after building will not work.

```cpp
// ❌ WRONG - Adding constraint after building area
int playerID = rmCreateArea("player " + i);
rmBuildArea(playerID);                                 // Area built first
rmAddAreaConstraint(playerID, playerEdgeConstraint);  // TOO LATE! Constraint ignored!

// ✅ CORRECT - Add constraints before building
int playerID = rmCreateArea("player " + i);
rmAddAreaConstraint(playerID, playerEdgeConstraint);  // Add constraints first
rmAddAreaConstraint(playerID, avoidPlayer);           // Can add multiple
rmBuildArea(playerID);                                 // Build AFTER all constraints added
```

⚠️ **CRITICAL:** Area constraints (using specific area IDs) can only be created AFTER the area is defined and built!

```cpp
// ❌ WRONG - Using area constraint before area exists
int avoidSpecificIsland = rmCreateAreaConstraint("avoid my island", islandID);  // ERROR - islandID doesn't exist yet!

// ✅ CORRECT - Create and build area first, then create constraint
int islandID = rmCreateArea("island");
rmAddAreaToClass(islandID, classIsland);
rmBuildArea(islandID);                                 // Build the area
// Now safe to create constraint that references this specific area
int avoidSpecificIsland = rmCreateAreaConstraint("avoid my island", islandID);
```

⚠️ **CRITICAL:** Class constraints can be created right after defining the class - you do NOT need to add areas to the class first!

**Note:** If you use a class constraint BEFORE defining the class, the result depends on definition type:
- **Hardcoded Integer definition** (`int classIsland`) → causes CRITICAL ERROR (undefined variable)
- **String definition** (`rmClassID("island")`) → no error, but constraint has NO EFFECT (silent fail)

```cpp
// ✅ CORRECT - Standard pattern from official maps
// Step 1: Define class
int classIsland = rmDefineClass("island");

// Step 2: Create constraint immediately (no areas in class yet - that's OK!)
int avoidIsland = rmCreateClassDistanceConstraint("avoid island", classIsland, 30.0);

// Step 3: Later, when creating areas, add to class BEFORE building
int islandID = rmCreateArea("island");
rmAddAreaToClass(islandID, classIsland);  // Add to class
rmBuildArea(islandID);                     // Then build

// ❌ WRONG - Using class before defining it
int avoidIsland = rmCreateClassDistanceConstraint("avoid island", classIsland, 30.0);  // ERROR!
int classIsland = rmDefineClass("island");  // Class used before definition!
```

**Key difference:** Area constraints need the area built first. Class constraints only need the class defined (areas can be added later).

---

✅ **Define ALL constraints AFTER classes** (classes first, then constraints that reference them)  
✅ **Group constraints by category** (player, resource, terrain, etc.) with comments  
✅ **Use descriptive names** (`avoidTownCenterFar` not `c1`)  
✅ **Create multiple distance variants** (short/medium/long) for flexibility  
✅ **Apply constraints BEFORE building areas** or placing objects  
✅ **More constraints = more attempts to place** = slower generation  
✅ **Test with fewer constraints first**, add more as needed for balance  

---

#### **Typical Constraint Workflow:**

```cpp
// 1. Define classes
int classPlayer = rmDefineClass("player");
int classIsland = rmDefineClass("island");

// 2. Create constraints (reference classes)
int playerConstraint = rmCreateClassDistanceConstraint("avoid players", classPlayer, 20.0);
int islandConstraint = rmCreateClassDistanceConstraint("islands avoid each other", classIsland, 48.0);
int avoidTC = rmCreateTypeDistanceConstraint("avoid TC", "townCenter", 10.0);

// 3. Create areas, add to classes, add constraints
int playerID = rmCreateArea("player " + i);
rmAddAreaToClass(playerID, classPlayer);
rmAddAreaToClass(playerID, classIsland);
rmAddAreaConstraint(playerID, islandConstraint);
rmAddAreaConstraint(playerID, playerEdgeConstraint);
rmBuildArea(playerID);

// 4. Create objects with constraints
int mineID = rmCreateObjectDef("player mine");
rmAddObjectDefItem(mineID, "mine", 1, 0);
rmAddObjectDefConstraint(mineID, playerConstraint);
rmAddObjectDefConstraint(mineID, avoidTC);
rmPlaceObjectDefPerPlayer(mineID, false, 1);
```

---

### **13.4. Map Customization**

**Purpose:** Add variety and replayability through randomization and visual customization.

---

#### **A) Lightsets (Visual Atmosphere)**

**Command:** `rmSetLightingSet(string lightsetName)`

**What they are:** Lightsets control the map's visual atmosphere - time of day, sun position, shadows, ambient lighting, fog, and color grading.

**Location:** Lightsets are defined in `art/lightsets/` but are inside BAR files (not directly accessible). You must reference them by name.

**When to call:** Early in `main()`, typically after map size and before terrain setup.

---

#### **Common Lightsets by Region:**

Based on `zpunknown.xs` biome system, here are proven lightset examples:

**North America:**
```cpp
shineAlight = "California_Skirmish";      // Warm, golden California sun
shineAlight = "Carolina_Skirmish";        // Temperate, balanced lighting
shineAlight = "NewEngland_Skirmish";      // Cool, autumn-like light
shineAlight = "Saguenay_Skirmish";        // Cold, northern atmosphere
shineAlight = "Yukon_Skirmish";           // Arctic, snowy lighting
shineAlight = "Texas_Skirmish";           // Hot, desert sunlight
shineAlight = "Rockies_Skirmish";         // Mountain daylight
```

**South America:**
```cpp
shineAlight = "Amazonia_Skirmish";        // Tropical rainforest (humid, green)
shineAlight = "Pampas_Skirmish";          // Grassland plains
shineAlight = "Andes_Skirmish";           // High altitude, clear sky
shineAlight = "Patagonia_Skirmish";       // Southern temperate
```

**Caribbean & Tropical:**
```cpp
shineAlight = "Caribbean_Skirmish";       // Tropical islands, bright sun
shineAlight = "Yucatan_Skirmish";         // Mayan jungle
shineAlight = "Bayou_Skirmish";           // Swamp, misty atmosphere
shineAlight = "Florida_Skirmish";         // Subtropical, warm
```

**Asia:**
```cpp
shineAlight = "Borneo_Skirmish";          // Southeast Asian jungle
shineAlight = "Deccan_Skirmish";          // Indian subcontinent
shineAlight = "Himalayas_Skirmish";       // High mountain pass
shineAlight = "Japan_Skirmish";           // East Asian islands
shineAlight = "Mongolia_Skirmish";        // Central Asian steppe
shineAlight = "Ceylon_Skirmish";          // Tropical island
shineAlight = "Silk Road_Skirmish";       // Desert trade route
```

**Europe & Mediterranean:**
```cpp
shineAlight = "Mediterranean_Skirmish";   // Warm, coastal light
shineAlight = "Italy_Skirmish";           // Italian countryside
shineAlight = "Anatolia_Skirmish";        // Turkish/Greek regions
```

**Africa & Middle East:**
```cpp
shineAlight = "Sahara_Skirmish";          // Desert, intense sunlight
shineAlight = "Horn_Skirmish";            // East African arid
```

---

#### **Usage Pattern: Season Selection (Summer/Winter):**

Many maps use a **season picker** to randomly select between summer and winter variations.

**Example from Great Lakes map:**

```cpp
// Choose summer or winter randomly
float seasonPicker = rmRandFloat(0, 1);  // < 0.5 = summer, >= 0.5 = winter
// seasonPicker = 0.77;                  // For testing (force winter)

// ... (map size, natives, etc.) ...

// Apply season-specific lightsets
if (seasonPicker < 0.5)
    rmSetLightingSet("GreatLakes_Summer_Skirmish");
else
    rmSetLightingSet("GreatLakes_Winter_Skirmish");

// Apply season-specific terrain
if (seasonPicker < 0.5) {
    // Summer: Grass terrain
    rmSetBaseTerrainMix("greatlakes_grass");
    rmTerrainInitialize("great_lakes\ground_grass1_gl", 1.0);
    rmSetMapType("grass");
    
} else {
    // Winter: Snow/ice terrain
    rmSetBaseTerrainMix("greatlakes_snow");
    rmTerrainInitialize("great_lakes\ground_ice1_glw", 1.0);
    rmSetMapType("snow");
}
```

**What changes between seasons:**
- ✅ **Lightsets** - Summer vs Winter atmosphere
- ✅ **Terrain mix** - `greatlakes_grass` vs `greatlakes_snow`
- ✅ **Terrain initialization** - Grass vs ice textures
- ✅ **Map types** - `grass` vs `snow` (affects AI behavior)
- ✅ **Natives** (optional) - Different civilizations per season

**Key benefits:**
- ✅ **Adds replayability** - Same map feels completely different
- ✅ **Simple to implement** - Just one `if/else` check
- ✅ **Easy to test** - Uncomment test line to force a season
- ✅ **Affects gameplay** - Snow changes movement, visibility, aesthetics

**Common season-specific lightsets:**
- **Great Lakes:** `GreatLakes_Summer_Skirmish` / `GreatLakes_Winter_Skirmish`
- **Generic pairings:**
  - Summer: `Carolina_Skirmish`, `Mediterranean_Skirmish`, `Florida_Skirmish`
  - Winter: `Yukon_Skirmish`, `Saguenay_Skirmish`, `Rockies_Skirmish`

---

#### **Simple Fixed Lightset Example:**

For maps with a single consistent theme:

```cpp
void main(void) {
    rmSetStatusText("", 0.01);
    
    // Set map size
    int size = 2.0 * sqrt(cNumberNonGaiaPlayers * 25000);
    rmSetMapSize(size, size);
    
    // Set lightset for Caribbean theme
    rmSetLightingSet("Caribbean_Skirmish");
    
    // Continue with terrain setup...
    rmSetSeaLevel(1.0);
    rmSetSeaType("Caribbean Coast");
    // ...
}
```

---

#### **Best Practices:**

✅ **Match lightset to biome** - Use `Amazonia_Skirmish` for tropical, `Yukon_Skirmish` for snow  
✅ **Declare lightset variable early** if randomizing (`string shineAlight = "";`)  
✅ **Apply with `rmSetLightingSet()`** before building terrain  
✅ **Test different lightsets** - same terrain looks very different with different lighting  
✅ **Use established lightset names** - they're proven to work

⚠️ **Lightsets are case-sensitive**  
⚠️ **Invalid lightset name = default lighting (not an error)**  
⚠️ **Lightsets are in BAR files** - cannot browse them directly

---

#### **B) Default Terrain Setup**

**Purpose:** Configure base terrain, elevation blending, and terrain initialization.

---

#### **Elevation Height Blend:**

**Command:** `rmSetMapElevationHeightBlend(int value)`

Controls how terrain elevation transitions are blended.

**Parameter values:**
- `1` = Standard blending (most common)
- `4` = Heavy blending (very smooth slopes)
- `-9` = Sharp transitions (dramatic cliffs)

**Examples:**
```cpp
rmSetMapElevationHeightBlend(1);      // Great Lakes - standard
rmSetMapElevationHeightBlend(4);      // Venice - smooth water
rmSetMapElevationHeightBlend(-9);     // Blue Mountains - cliffs
```

---

#### **Sea Level (Water Height):**

**Command:** `rmSetSeaLevel(float height)`

Controls the height/level of water on the map. Determines what is underwater vs above water (buildable land).

**How it works:**
- Sets the water plane height
- Terrain below this height = underwater (not buildable)
- Terrain above this height = land (buildable)
- Affects how much of the map is water vs land

**Common values:**
```cpp
rmSetSeaLevel(0.0);      // No water / very low water
rmSetSeaLevel(1.0);      // Standard water level (most maps)
rmSetSeaLevel(6.0);      // Raised water (Great Lakes style)
```

**Examples:**
```cpp
// Black Sea - standard water level
rmSetSeaLevel(1.0);

// Great Lakes - raised water for lake effect
rmSetSeaLevel(6.0);

// Dry/desert map - minimal water
rmSetSeaLevel(0.0);
```

**Important notes:**
- ✅ Call **after** map size and elevation blend
- ✅ Call **before** terrain initialization
- ✅ Higher values = more water coverage
- ✅ Lower values = more buildable land
- ⚠️ Must match terrain height in `rmTerrainInitialize()`

**🚨 CRITICAL: Island/Area Heights Must Exceed Sea Level**

When using raised sea levels (e.g., `rmSetSeaLevel(6.0)`), all islands and areas MUST have their base height set **higher than the sea level**, otherwise they will appear underwater!

```cpp
// Great Lakes - Sea level at 6.0
rmSetSeaLevel(6.0);

// WRONG - Island will be underwater!
rmSetAreaBaseHeight(islandID, 2.0);   // ❌ 2.0 < 6.0 = underwater

// CORRECT - Island above water
rmSetAreaBaseHeight(islandID, 7.0);   // ✅ 7.0 > 6.0 = visible land
rmSetAreaBaseHeight(islandID, 8.0);   // ✅ 8.0 > 6.0 = even higher
```

**Rule:** `Area Base Height > Sea Level` for islands to be visible!

**Example: Great Barrier Reef (Underwater + Upperwater Areas)**

The Great Barrier Reef map demonstrates using different heights for underwater and above-water features:

```cpp
// Water map - base is water at level 0.0
rmTerrainInitialize("water");

// Underwater cliffs (decorative, below water)
rmSetAreaBaseHeight(underwaterCliff, -5.0);      // Deep underwater
rmAddAreaToClass(underwaterCliff, classUnderwaterCliff);

// Shallow water areas (visible as lighter water)
rmSetAreaBaseHeight(playerShallows, -0.5);       // Shallow underwater

// Player islands (above water, buildable)
rmSetAreaBaseHeight(playerIsland, 2.0);          // Above water
rmSetAreaMix(playerIsland, baseMix);

// Bonus islands (higher for variety)
rmSetAreaBaseHeight(bonusIsland, 2.5);           // Even higher
rmSetAreaMix(bonusIsland, baseMix);
```

**Height layers explained:**
- `-5.0` = Deep underwater features (cliffs, decoration)
- `-0.5` = Shallow water (visible but not buildable)
- `0.0` = Water surface (default terrain)
- `2.0` = Standard islands (buildable land)
- `2.5` = Elevated islands (higher terrain)

This creates depth and visual variety in water maps!

---

**Relationship with terrain initialization:**
```cpp
// Land map - terrain at height 1.0, water at 1.0
rmSetSeaLevel(1.0);
rmTerrainInitialize("great_lakes\\ground_grass1_gl", 1.0);
// Result: Land starts at water level, rises from there

// Water map - terrain at height 0.0, water at 1.0
rmSetSeaLevel(1.0);
rmTerrainInitialize("water", 0.0);
// Result: Water covers everything at height 1.0
```

---

#### **Terrain Initialization Methods:**

**1. Land Maps - Terrain Mix + Initialization (Most Common):**

This is the standard pattern used in most land maps:

```cpp
// Set terrain mix first, then initialize with specific texture
rmSetBaseTerrainMix("greatlakes_grass");
rmTerrainInitialize("great_lakes\\ground_grass1_gl", 1.0);
```

**How it works:**
1. `rmSetBaseTerrainMix()` - Defines the base terrain mix/palette
2. `rmTerrainInitialize()` - Fills the map with a specific terrain texture at height 1.0 (land level)

**Great Lakes example (with seasons):**
```cpp
if (seasonPicker < 0.5) {
    // Summer
    rmSetBaseTerrainMix("greatlakes_grass");
    rmTerrainInitialize("great_lakes\\ground_grass1_gl", 1.0);
} else {
    // Winter
    rmSetBaseTerrainMix("greatlakes_snow");
    rmTerrainInitialize("great_lakes\\ground_ice1_glw", 1.0);
}
```

⚠️ **Use double backslash** (`\\`) in terrain paths  
⚠️ **Height parameter:** `1.0` = land level, `0.0` = water level

---

**2. Water Maps - Base Water Initialization:**
```cpp
rmSetSeaType(seaType1);              // Define water type
rmTerrainInitialize("water");       // Fill map with water
```

**What it does:** Sets the water type, then fills the map with water. Used for naval/water maps.

**Example (Black Sea):**
```cpp
rmSetSeaType("Black Sea");           // Set water appearance
rmEnableLocalWater(false);           // Disable water disturbances
rmTerrainInitialize("water");       // Fill map with water
```

---

#### **Local Water Disturbances:**

**Command:** `rmEnableLocalWater(bool enable)`

**What it does:** Enables or disables local water disturbances (ripples, waves, visual effects on water surface).

**Usage:**
```cpp
rmEnableLocalWater(false);           // Disable water disturbances (most maps)
rmEnableLocalWater(true);            // Enable water disturbances (dynamic water)
```

**When to use:**
- `false` (most common) - Static water, better performance, cleaner look
- `true` - Dynamic water with ripples and waves, more realistic

**Note:** Most Age of Pirates maps use `false` for consistent water appearance.

---

#### **World Circle Constraint:**

**Command:** `rmSetWorldCircleConstraint(bool constrain)`

**What it does:** Constrains all random map generation activities to a circular area within the square map.

**From the reference:** "Sets whether RM activities should be constrained to the main world circle."

```cpp
rmSetWorldCircleConstraint(true);    // Enable circular constraint (default)
rmSetWorldCircleConstraint(false);   // Allow full square map
```

**Why it's important:**

✅ **Creates circular/diamond playable area**
- Map appears round/diamond instead of square
- Matches the diamond-shaped minimap display
- Corners become inactive/decorative areas

✅ **Prevents corner placement issues**
- Players won't spawn in corners
- Resources/objects stay within circle
- Trade routes follow natural curved paths

✅ **Standard for almost all maps**
- **99% of maps use `true`** (including city maps like Paris)
- Only special rectangular maps might use `false`

**Visual effect:**
```
false (full square):     true (circular):
┌─────────────┐          ┌─────────────┐
│█████████████│          │             │
│█████████████│          │   ███████   │
│█████████████│          │  █████████  │
│█████████████│          │  █████████  │
│█████████████│          │   ███████   │
└─────────────┘          └─────────────┘
```

**When to call:** After `chooseMercs()`, before defining classes and constraints.

**Example:**
```cpp
chooseMercs();

// Corner constraint
rmSetWorldCircleConstraint(true);

// Define classes
int classPlayer = rmDefineClass("player");
```

**When to use `false`:**
- Only if you specifically need full rectangular map
- Very rare - even city maps (Paris, Venice) use `true`

---

**Complete terrain setup example (Great Lakes):**
```cpp
// Set map size
int size = 2.0 * sqrt(cNumberNonGaiaPlayers * 10000);
rmSetMapSize(size, size);

// Elevation blending
rmSetMapElevationHeightBlend(1);

// Water level
rmSetSeaLevel(6.0);

// Season-based terrain
if (seasonPicker < 0.5) {
    // Summer
    rmSetLightingSet("GreatLakes_Summer_Skirmish");
    rmSetBaseTerrainMix("greatlakes_grass");
    rmTerrainInitialize("great_lakes\\ground_grass1_gl", 1.0);
    rmSetMapType("grass");
} else {
    // Winter
    rmSetLightingSet("GreatLakes_Winter_Skirmish");
    rmSetBaseTerrainMix("greatlakes_snow");
    rmTerrainInitialize("great_lakes\\ground_ice1_glw", 1.0);
    rmSetMapType("snow");
}
```

**Call order:**
1. `rmSetMapSize()`
2. `rmSetMapElevationHeightBlend()`
3. `rmSetSeaLevel()`
4. `rmSetLightingSet()`
5. `rmSetBaseTerrainMix()`
6. `rmTerrainInitialize()`
7. `rmSetMapType()`

---

### **13.5. Useful Variables**

**Purpose:** Define helpful variables at the start of your map script to simplify calculations and improve readability throughout map generation.

These variables are commonly used across many maps and make your code more maintainable.

---

#### **Player & Team Count Variables:**

**Standard player/team variables (from Black Sea map):**

```cpp
int TeamNum = cNumberTeams;
int PlayerNum = cNumberNonGaiaPlayers;
int numPlayer = cNumberPlayers;
```

**What they do:**
- `TeamNum` - Total number of teams in the game
- `PlayerNum` - Number of human/AI players (excludes Gaia/Mother Nature)
- `numPlayer` - Total number of players including Gaia (usually `PlayerNum + 1`)

**Why use them:**
- ✅ Shorter, more readable variable names
- ✅ Easier to type than `cNumberNonGaiaPlayers` repeatedly
- ✅ Consistent naming convention across your map

**Usage example:**
```cpp
// Instead of:
if (cNumberNonGaiaPlayers == 2) {
    playerTiles = 12000;
}

// Use:
if (PlayerNum == 2) {
    playerTiles = 12000;
}
```

---

#### **Team Player Counts:**

**Get the number of players on specific teams:**

```cpp
int teamZeroCount = rmGetNumberPlayersOnTeam(0);
int teamOneCount = rmGetNumberPlayersOnTeam(1);
```

**What they do:**
- `teamZeroCount` - Number of players on Team 0
- `teamOneCount` - Number of players on Team 1

**Why use them:**
- ✅ Essential for team-based map variations
- ✅ Balance resources based on team size
- ✅ Create asymmetric team scenarios (2v3, 1v4, etc.)

**Usage example (from Black Sea):**
```cpp
int teamZeroCount = rmGetNumberPlayersOnTeam(0);
int teamOneCount = rmGetNumberPlayersOnTeam(1);

if (PlayerNum == 2) {
    // 1v1 logic
} else if (teamZeroCount == teamOneCount) {
    // Balanced teams (2v2, 3v3, etc.)
} else {
    // Unbalanced teams (2v3, 1v4, etc.)
}
```

---

#### **Map Radius:**

**Calculate the diagonal radius of the map:**

```cpp
float mapRadius = sqrt(rmGetMapXSize() * rmGetMapXSize() + rmGetMapZSize() * rmGetMapZSize()) / 2.0;
```

**What it does:**
- Calculates the distance from map center to corner
- Uses Pythagorean theorem: `sqrt(x² + z²) / 2`
- Returns the maximum distance available on the map

**Why use it:**
- ✅ Create distance constraints relative to map size
- ✅ Scale object placement based on map dimensions
- ✅ Ensure constraints work on any map size

**Usage example (from Black Sea):**
```cpp
float mapRadius = sqrt(rmGetMapXSize() * rmGetMapXSize() + rmGetMapZSize() * rmGetMapZSize()) / 2.0;

// Use mapRadius for dynamic constraints
int avoidCenterPointUltraLong = rmCreateTypeDistanceConstraint(
    "avoid center point ultra long", 
    "zpSPCWaterSpawnPointB", 
    1.3 * mapRadius  // Distance scales with map size
);
```

**Other uses:**
```cpp
// Area size relative to map
float islandSize = 0.1 * mapRadius;

// Placement rings
float innerRing = 0.3 * mapRadius;
float outerRing = 0.7 * mapRadius;
```

---

#### **Best Practices:**

✅ **Define at the top** of your script (before `void main()` or right after)  
✅ **Use descriptive names** - `PlayerNum` is clearer than `pNum`  
✅ **Calculate once, use many times** - Don't recalculate `mapRadius` repeatedly  
✅ **Comment complex calculations** - Explain what `mapRadius` formula does  

**Complete example (Black Sea style):**

```cpp
// Useful variables
int TeamNum = cNumberTeams;
int PlayerNum = cNumberNonGaiaPlayers;
int numPlayer = cNumberPlayers;

void main(void) {
    rmSetStatusText("", 0.01);
    
    // Map setup
    int size = 2.0 * sqrt(PlayerNum * 25000);
    rmSetMapSize(size, size);
    
    // Calculate map radius for constraints
    float mapRadius = sqrt(rmGetMapXSize() * rmGetMapXSize() + rmGetMapZSize() * rmGetMapZSize()) / 2.0;
    
    // Get team sizes
    int teamZeroCount = rmGetNumberPlayersOnTeam(0);
    int teamOneCount = rmGetNumberPlayersOnTeam(1);
    
    // Use variables in logic
    if (PlayerNum == 2) {
        // 1v1 setup
    } else if (teamZeroCount == teamOneCount) {
        // Balanced teams
    }
    
    // Use mapRadius for constraints
    int farConstraint = rmCreateTypeDistanceConstraint("far", "all", 0.5 * mapRadius);
}
```

---

## **14.** 🏝️ Areas

**Purpose:** Areas are the building blocks of your map - islands, continents, forests, lakes, and terrain features. Understanding how to create and configure areas is essential for map generation.

---

### **14.0 Terrain Types and Mixes (Foundation)**

Before creating areas, understand how to apply terrain to your map.

---

#### **Terrain Types - Two Use Cases**

##### **A) Base Terrain (Map-wide ground)**

```cpp
// Set a specific terrain type for the entire map base
rmTerrainInitialize("nwterritory\\ground_grass2_nwt", 1.0);
```

##### **B) Area-Specific Terrain**

```cpp
// Paint a specific area with a terrain type
int streetsSouth = rmCreateArea("streets South");
rmSetAreaSize(streetsSouth, 0.7, 0.7);
rmSetAreaLocation(streetsSouth, 0.2, 0.5);
rmSetAreaTerrainType(streetsSouth, "city\\ground1_cob_dark");
rmBuildArea(streetsSouth);
```

---

#### **Terrain Mixes - Two Use Cases**

##### **A) Base Terrain Mix (Map-wide blended terrain)**

```cpp
// Set a terrain mix for the base map
rmSetBaseTerrainMix("nwt_grass1");  // ⚠️ Use exact filename (underscores!)
```

⚠️ **CRITICAL:** Always use the exact filename from `mix/` folder without `.xml`
- File: `italy_grass.xml` → Use: `"italy_grass"` ✅
- NOT: `"italy grass"` ❌ (will crash!)

##### **B) Area-Specific Terrain Mix**

```cpp
// Apply a terrain mix to a specific area
int countrysideNorth = rmCreateArea("countryside N");
rmSetAreaSize(countrysideNorth, 0.6, 0.6);
rmSetAreaLocation(countrysideNorth, 0.8, 0.5);
rmSetAreaMix(countrysideNorth, "nwt_grass1");
rmBuildArea(countrysideNorth);
```

##### **C) Terrain Patches (Simple Method)**

**Best for:** Creating scattered terrain variation across islands/landmasses

Use `rmSetAreaMix()` for simple, effective patches - much simpler than complex blob settings!

**Example: Mediterranean terrain patches (from Black Sea / Balearic Islands)**

```cpp
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
- ✅ Simple formula: `20-100 + cNumberNonGaiaPlayers * 30-50` patches
- ✅ Small size: `rmAreaTilesToFraction(37)` to `(42)` - creates natural small patches
- ✅ Use `rmSetAreaMix()` not `rmSetAreaTerrainType()` - works better for patches
- ✅ Smooth distance: `1.0` - blends edges nicely
- ✅ Always constrain: Use `avoidWater4` to keep patches on land (or `avoidNatives` if needed)
- ⚠️ No complex blobs needed - simple is better for scattered patches!

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

### **14.1 Islands**

Islands are elevated land areas surrounded by water. They can be single standalone islands, team-shared islands, or individual player islands.

---

#### **14.1.1 Single Islands (Bonus/Neutral Islands):**

Single islands are standalone land masses that don't belong to any specific player or team. They're often used for contested resources or neutral objectives.

**Example from Balearic Islands - Center Bonus Island:**

```cpp
// Elevated island on top (center bonus island) - elongated east-west for cross effect
int bigIslandID = rmCreateArea("migration island");

// Size varies by player count
if (cNumberNonGaiaPlayers <= 3) {
    rmSetAreaSize(bigIslandID, 0.05, 0.05);
} else {
    rmSetAreaSize(bigIslandID, 0.04, 0.04);
}

// Location and shape
rmSetAreaLocation(bigIslandID, 0.5, 0.5);                    // Center of map
rmSetAreaCoherence(bigIslandID, 0.75);                       // Shape coherence

// Height and terrain
rmSetAreaBaseHeight(bigIslandID, 2.0);                       // Above water
rmSetAreaSmoothDistance(bigIslandID, 20);                    // Smooth edges
rmSetAreaMix(bigIslandID, baseMix);                          // Terrain texture

// Elevation variation (makes island less flat)
rmSetAreaElevationType(bigIslandID, cElevTurbulence);
rmSetAreaElevationVariation(bigIslandID, 2.0);
rmSetAreaElevationMinFrequency(bigIslandID, 0.09);
rmSetAreaElevationOctaves(bigIslandID, 3);
rmSetAreaElevationPersistence(bigIslandID, 0.2);
rmSetAreaElevationNoiseBias(bigIslandID, 1);

// Class assignment
rmAddAreaToClass(bigIslandID, classIsland);

// Influence segments (creates elongated cross shape)
rmAddAreaInfluenceSegment(bigIslandID, 0.5, 0.44, 0.67, 0.5);
rmAddAreaInfluenceSegment(bigIslandID, 0.5, 0.56, 0.67, 0.5);
rmAddAreaInfluenceSegment(bigIslandID, 0.5, 0.44, 0.37, 0.5);
rmAddAreaInfluenceSegment(bigIslandID, 0.5, 0.56, 0.37, 0.5);

// Allow placement outside world circle
rmSetAreaObeyWorldCircleConstraint(bigIslandID, false);

// Build the island
rmBuildArea(bigIslandID);
```

**Key commands for single islands:**
- `rmCreateArea()` - Create the area
- `rmSetAreaSize()` - Set size (0.0 to 1.0, or use `rmAreaTilesToFraction()`)
- `rmSetAreaLocation()` - Set position (0.0 to 1.0 for X and Z)
- `rmSetAreaBaseHeight()` - Set height above water
- `rmSetAreaMix()` - Set terrain texture
- `rmAddAreaToClass()` - Add to class for constraints
- `rmBuildArea()` - Actually generate the island

**Common uses:**
- ✅ Neutral trade post islands
- ✅ King of the Hill objectives
- ✅ Bonus resource islands
- ✅ Central contested areas

---

#### **14.1.2 Player Islands (Individual Islands):**

**Concept:** Each player gets their own separate island.

**Used in:** zpPhilippines (original), most standard island maps

**Complete structure:**

```cpp
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

**⚠️ CRITICAL RECOMMENDATION - Building Islands:**

When creating bonus/random islands AFTER player/team islands, use **individual `rmBuildArea()`** instead of `rmBuildAllAreas()`:

```cpp
// ❌ WRONG - Can cause spawn issues
for(i=0; <3) {
    int bonusID = rmCreateArea("bonus "+i);
    // ... configure area ...
}
rmBuildAllAreas();  // May interfere with already-built player islands

// ✅ CORRECT - Build each island individually
for(i=0; <3) {
    int bonusID = rmCreateArea("bonus "+i);
    // ... configure area ...
    rmBuildArea(bonusID);  // Build immediately in the loop
}
```

**Why this matters:**
- `rmBuildAllAreas()` rebuilds ALL areas, including already-built player islands
- This can cause player spawn failures or overlapping islands
- Building individually prevents interference with existing areas

**Key characteristics:**
- ✅ **Loop starts at 1:** `for(i=1; <cNumberPlayers)` - player 0 is Gaia
- ✅ **Individual ownership:** Each player owns their island
- ✅ **Player-specific location:** `rmSetAreaLocPlayer(playerID, i)`
- ✅ **Size calculation:** Based on total players (`7000 - cNumberNonGaiaPlayers*300`)
- ✅ **Resource scaling:** Fixed amount per player (e.g., 3 mines each)

**Advantages:**
- 🎯 Guaranteed personal space for each player
- 🎯 Equal island size for all players
- 🎯 Easier to balance resources per player
- 🎯 Works well for FFA (Free For All) games

**Disadvantages:**
- ⚠️ Team members are separated (harder to help each other)
- ⚠️ More islands = more complex map generation
- ⚠️ Harder to defend/coordinate as a team

---

#### **14.1.3 Team Islands (Shared Islands):**

**Concept:** Each team gets one large shared island that contains all team members.

**Used in:** zpCookIslands, Caribbean, Balearic Islands (updated)

**Complete structure:**

```cpp
// Player placement (same as Player Islands)
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

**Key characteristics:**
- ✅ **Loop starts at 0:** `for(i=0; <cNumberTeams)` - teams start from 0
- ✅ **Shared ownership:** All team members share one island
- ✅ **Team-based location:** `rmSetAreaLocTeam(teamID, i)`
- ✅ **Size calculation:** Based on number of teams (`0.18 / cNumberTeams`)
- ✅ **Resource scaling:** Multiplied by team size (`3*rmGetNumberPlayersOnTeam(i)`)

**Advantages:**
- 🎯 Team members start together (easier cooperation)
- 🎯 Better for team games (2v2, 3v3, 4v4)
- 🎯 Fewer islands = faster map generation
- 🎯 More realistic for historical team scenarios

**Disadvantages:**
- ⚠️ Teammates may compete for nearby resources
- ⚠️ Less personal space per player
- ⚠️ Unbalanced if teams have different sizes

---

##### **Comparison: Player vs Team Islands**

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

##### **Choosing the Right Pattern**

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

##### **Hybrid Approach (Advanced)**

Some maps use both patterns:
- **Player Islands** for starting areas
- **Bonus Team Islands** for contested resources

Example: Players spawn on individual small islands, but there's a large central team island with extra resources.

#### **14.1.4 Layered Islands (Foundation + Visible Island)**

For creating cross-shaped or complex islands, use a **layered approach**: first build an underwater foundation, then place the visible island on top. This technique is used in Balearic Islands to create a distinct cross pattern.

**Example from Balearic Islands - Cross-Shaped Center Island:**

This creates a cross-shaped island by layering two perpendicular areas.

```cpp
// LAYER 1: Base underwater foundation (North-South orientation)
int baseIslandID = rmCreateArea("base island");

if (cNumberNonGaiaPlayers <= 3) {
    rmSetAreaSize(baseIslandID, 0.05, 0.05);
} else {
    rmSetAreaSize(baseIslandID, 0.04, 0.04);
}

rmSetAreaCoherence(baseIslandID, 0.75);
rmSetAreaBaseHeight(baseIslandID, 0.5);          // ⚠️ UNDERWATER! Below sea level
rmSetAreaSmoothDistance(baseIslandID, 20);
rmSetAreaMix(baseIslandID, baseMix);
rmAddAreaToClass(baseIslandID, classIsland);
rmSetAreaObeyWorldCircleConstraint(baseIslandID, false);
rmSetAreaLocation(baseIslandID, 0.5, 0.5);

// North-South influence segments (vertical arm of cross)
rmAddAreaInfluenceSegment(baseIslandID, 0.5, 0.44, 0.58, 0.5);
rmAddAreaInfluenceSegment(baseIslandID, 0.5, 0.56, 0.58, 0.5);
rmAddAreaInfluenceSegment(baseIslandID, 0.5, 0.44, 0.46, 0.5);
rmAddAreaInfluenceSegment(baseIslandID, 0.5, 0.56, 0.46, 0.5);

rmBuildArea(baseIslandID);

// LAYER 2: Elevated visible island on top (East-West orientation)
int bigIslandID = rmCreateArea("migration island");

if (cNumberNonGaiaPlayers <= 3) {
    rmSetAreaSize(bigIslandID, 0.05, 0.05);
} else {
    rmSetAreaSize(bigIslandID, 0.04, 0.04);
}

rmSetAreaCoherence(bigIslandID, 0.75);
rmSetAreaBaseHeight(bigIslandID, 2.0);           // ✅ ABOVE WATER! Visible landmass
rmSetAreaSmoothDistance(bigIslandID, 20);
rmSetAreaMix(bigIslandID, baseMix);
rmSetAreaObeyWorldCircleConstraint(bigIslandID, false);

// Elevation variation for natural terrain
rmSetAreaElevationType(bigIslandID, cElevTurbulence);
rmSetAreaElevationVariation(bigIslandID, 2.0);
rmSetAreaElevationMinFrequency(bigIslandID, 0.09);
rmSetAreaElevationOctaves(bigIslandID, 3);
rmSetAreaElevationPersistence(bigIslandID, 0.2);
rmSetAreaElevationNoiseBias(bigIslandID, 1);

rmAddAreaToClass(bigIslandID, classIsland);
rmSetAreaLocation(bigIslandID, 0.5, 0.5);

// East-West influence segments (horizontal arm of cross)
rmAddAreaInfluenceSegment(bigIslandID, 0.5, 0.44, 0.67, 0.5);
rmAddAreaInfluenceSegment(bigIslandID, 0.5, 0.56, 0.67, 0.5);
rmAddAreaInfluenceSegment(bigIslandID, 0.5, 0.44, 0.37, 0.5);
rmAddAreaInfluenceSegment(bigIslandID, 0.5, 0.56, 0.37, 0.5);

rmBuildArea(bigIslandID);
```

**Why is the first island underwater?**

The base island is placed at height **0.5** (below the typical sea level of 1.0) for several important reasons:

1. **Creates foundation for visible island:**
   - Provides a solid underwater base for the elevated island
   - Prevents water from penetrating between the two layers
   - Ensures smooth terrain transitions

2. **Defines buildable area shape:**
   - The perpendicular orientation creates the cross pattern
   - Base layer (N-S) + Top layer (E-W) = Cross shape
   - Only the intersection appears as land

3. **Controls shallow water zones:**
   - Areas where base is present but top island isn't = shallow water
   - Creates natural-looking coastline gradients
   - Adds visual depth around the island

4. **Prevents terrain gaps:**
   - Without the underwater base, the elevated island might have gaps
   - Base fills in underwater areas to create solid foundation
   - Ensures consistent elevation across the entire shape

**Visual representation:**
```
Top View:                    Side View (cross-section):
                            
     N                           Sea Level (1.0)
     |                           ─────────────────
  W──+──E  (Cross shape)            ███        Top island (2.0)
     |                              ████        
     S                             ██████       Base island (0.5)
                                  ────────      Seafloor
```

**Key characteristics:**
- ✅ **Base height < Sea level:** Foundation underwater
- ✅ **Top height > Sea level:** Visible landmass
- ✅ **Perpendicular orientations:** Creates complex shapes
- ✅ **Same center location:** Islands overlay perfectly
- ✅ **Build order matters:** Base first, then top

**When to use layered islands:**

✅ **Cross-shaped islands** - Two perpendicular layers  
✅ **Star-shaped islands** - Three+ overlapping layers  
✅ **Complex geometric shapes** - Multiple directional influences  
✅ **Shallow water effects** - Base creates depth variation  
✅ **Foundation for cliffs** - Underwater support for elevated terrain  

**Common height values:**
```cpp
// Typical layering pattern:
rmSetAreaBaseHeight(baseIslandID, 0.5);      // Underwater foundation
rmSetSeaLevel(1.0);                          // Water surface
rmSetAreaBaseHeight(bigIslandID, 2.0);       // Visible island
```

**Advantages:**
- 🎯 Creates unique, complex island shapes
- 🎯 Natural-looking shallow water zones
- 🎯 Prevents terrain gaps and holes
- 🎯 Allows perpendicular influence segments

**Disadvantages:**
- ⚠️ More complex to visualize during development
- ⚠️ Requires careful height coordination
- ⚠️ Double the area creation code
- ⚠️ Must build base before top layer

---

#### **14.2.4 Advanced: Complex Landmasses with Influence Segments**

For creating hyperrealistic continents or large islands with detailed coastlines, use **multiple influence segments** to define the exact shape. This technique is used in maps like Australia to recreate real-world geography.

**Example from Australia - Realistic Continent Shape:**

This creates a detailed landmass by chaining many influence segments to trace the coastline.

```cpp
// Make one big island (Australia-shaped landmass)
int bigIslandID = rmCreateArea("big lone island");
rmSetAreaSize(bigIslandID, 0.25, 0.25);
rmSetAreaCoherence(bigIslandID, 0.9);           // High coherence = smooth coastline
rmSetAreaBaseHeight(bigIslandID, 2.0);
rmSetAreaSmoothDistance(bigIslandID, 20);
rmSetAreaMix(bigIslandID, islandTerrainMix);
rmAddAreaTerrainLayer(bigIslandID, "Africa\\pathBlend_afr", 0, 6);
rmAddAreaConstraint(bigIslandID, islandAvoidTradeRoute);

rmAddAreaToClass(bigIslandID, classIsland);
rmSetAreaObeyWorldCircleConstraint(bigIslandID, false);

// Elevation variation
rmSetAreaElevationType(bigIslandID, cElevTurbulence);
rmSetAreaElevationVariation(bigIslandID, 4.0);
rmSetAreaElevationMinFrequency(bigIslandID, 0.09);
rmSetAreaElevationOctaves(bigIslandID, 3);
rmSetAreaElevationPersistence(bigIslandID, 0.2);
rmSetAreaElevationNoiseBias(bigIslandID, 1);

// Define complex coastline with many influence segments
// Each segment traces a portion of the coastline from point A to point B
rmAddAreaInfluenceSegment(bigIslandID, 0.15, 0.6, 0.18, 0.56);   // Northwest coast
rmAddAreaInfluenceSegment(bigIslandID, 0.23, 0.55, 0.27, 0.52);  // Northern curve
rmAddAreaInfluenceSegment(bigIslandID, 0.32, 0.53, 0.36, 0.51);  // Northeast approach
rmAddAreaInfluenceSegment(bigIslandID, 0.44, 0.44, 0.43, 0.38);  // Eastern bulge
rmAddAreaInfluenceSegment(bigIslandID, 0.49, 0.49, 0.44, 0.34);  // Eastern indent
rmAddAreaInfluenceSegment(bigIslandID, 0.46, 0.33, 0.44, 0.27);  // Southeast coast
rmAddAreaInfluenceSegment(bigIslandID, 0.47, 0.23, 0.49, 0.22);  // Southern point
rmAddAreaInfluenceSegment(bigIslandID, 0.49, 0.19, 0.54, 0.18);  // Southern curve
rmAddAreaInfluenceSegment(bigIslandID, 0.56, 0.16, 0.64, 0.20);  // Southwest approach
rmAddAreaInfluenceSegment(bigIslandID, 0.68, 0.21, 0.74, 0.24);  // Western bulge
rmAddAreaInfluenceSegment(bigIslandID, 0.78, 0.30, 0.80, 0.43);  // West coast
rmAddAreaInfluenceSegment(bigIslandID, 0.79, 0.48, 0.81, 0.50);  // Western indent
rmAddAreaInfluenceSegment(bigIslandID, 0.84, 0.56, 0.83, 0.58);  // Northwest curve 1
rmAddAreaInfluenceSegment(bigIslandID, 0.87, 0.64, 0.86, 0.66);  // Northwest curve 2
rmAddAreaInfluenceSegment(bigIslandID, 0.74, 0.68, 0.72, 0.69);  // Northern peninsula
rmAddAreaInfluenceSegment(bigIslandID, 0.69, 0.68, 0.75, 0.71);  // Northern cape
rmAddAreaInfluenceSegment(bigIslandID, 0.69, 0.79, 0.68, 0.77);  // Northern tip

rmBuildArea(bigIslandID);
```

**How influence segments work:**

Each `rmAddAreaInfluenceSegment()` defines a line segment:
```cpp
rmAddAreaInfluenceSegment(areaID, startX, startZ, endX, endZ);
```

- Creates a "pull" from `(startX, startZ)` to `(endX, endZ)`
- Area stretches along these segments to create the desired shape
- Multiple segments chain together to trace complex outlines

**Visual representation:**
```
Map grid (0.0 to 1.0):
    0.0                    0.5                    1.0
0.0 ┌────────────────────────────────────────────┐
    │                                            │
    │     Segment 1 →      ╱──╲                 │
0.5 │                    ╱      ╲   Segment 2   │
    │                  ╱          ╲────→         │
    │                ╱                  ╲        │
1.0 └────────────────────────────────────────────┘
    
Each segment "pulls" the area to create the landmass shape
```

**Key characteristics:**
- ✅ **High coherence (0.9):** Creates smooth, realistic coastlines
- ✅ **Many segments:** More segments = more detail and accuracy
- ✅ **Sequential order:** Segments should connect logically around the perimeter
- ✅ **Small coordinate changes:** Gentle curves, not sharp angles

**Planning your segments:**

1. **Sketch the shape:** Draw your desired landmass on paper or digitally
2. **Mark key points:** Identify corners, bulges, indents, capes
3. **Connect the dots:** Create segments between key points
4. **Refine:** Add more segments for smoother curves

**Tips for realistic landmasses:**

✅ **Start with reference:** Use real geography or sketches  
✅ **Use 10-20 segments:** Good balance between detail and complexity  
✅ **Keep coherence high (0.8-0.95):** Prevents blobby, unrealistic shapes  
✅ **Test iteratively:** Build, view, adjust segment positions  
✅ **Document your segments:** Comment what part of coastline each represents  

**Common mistakes:**

❌ **Too few segments** - Results in simple, blocky shapes  
❌ **Segments crossing** - Can create strange bulges or holes  
❌ **Sharp angle changes** - Makes coastlines look artificial  
❌ **Random order** - Segments should trace coastline sequentially  

**When to use this technique:**
- ✅ Recreating real-world geography (Australia, India, Italy, etc.)
- ✅ Large, detailed continents
- ✅ Hyperrealistic historical maps
- ✅ Asymmetric scenarios requiring specific landmass shapes

**Simpler alternative:**

For less complex islands, use basic properties without influence segments:
```cpp
int simpleIslandID = rmCreateArea("simple island");
rmSetAreaSize(simpleIslandID, 0.15, 0.15);
rmSetAreaCoherence(simpleIslandID, 0.6);        // Lower = more organic
rmSetAreaLocation(simpleIslandID, 0.5, 0.5);   // Center
rmBuildArea(simpleIslandID);
// No influence segments = natural, random shape
```

#### **14.2.5 Randomized Terrain (Natural Lakes via Elevation Variation)**

**Used in:** New Guinea - Combining **fixed elevated plateaus** (guaranteed land) with **random terrain variation** (natural lakes) on the same map.

**The Contrast:** 
- **Player/Native plateaus**: Fixed height, always land, predictable placement
- **Central continent**: Random elevation variation, mix of land/lakes, unpredictable

---

##### **Part 1: Fixed Elevated Plateaus (Players/Natives)**

First, create guaranteed land areas for players and natives at **fixed elevations**:

```cpp
// Create elevated land plateaus for each player (GUARANTEED LAND)
for(i=1; < cNumberNonGaiaPlayers + 1) {
    int PlayerArea1 = rmCreateArea("NeedLand1"+i);
    rmSetAreaSize(PlayerArea1, rmAreaTilesToFraction(1030), rmAreaTilesToFraction(1030));
    
    // Fixed height - ALWAYS above water (no variation)
    rmSetAreaBaseHeight(PlayerArea1, 1.0);  // Guaranteed land
    
    rmSetAreaMix(PlayerArea1, "borneo_grass_a");
    rmSetAreaHeightBlend(PlayerArea1, 1);
    rmSetAreaLocation(PlayerArea1, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
    rmSetAreaCoherence(PlayerArea1, 0.7);
    rmAddAreaToClass(PlayerArea1, rmClassID("classPlateau"));
    
    // NO elevation variation - stays flat and buildable
    
    rmBuildArea(PlayerArea1);
}
```

**Key difference:** NO `rmSetAreaElevationVariation()` = flat, predictable, always buildable land.

---

##### **Part 2: Random Continent with Natural Lakes**

Then, create a large central area with **elevation variation** for random lakes:

```cpp
// Random water height determines base continent elevation
float waterHeight = rmRandFloat(0.6, 0.9);  // Random: 0.6-0.9

// Create large central continent
int continent2 = rmCreateArea("continent");

// Size scales with player count
if (cNumberNonGaiaPlayers <= 2)
    rmSetAreaSize(continent2, 0.53, 0.53);
else
    rmSetAreaSize(continent2, 0.55, 0.55);

rmSetAreaLocation(continent2, 0.5, 0.5);
rmSetAreaMix(continent2, "borneo_grass_a");

// Base height near water level (randomized 0.6-0.9)
rmSetAreaBaseHeight(continent2, waterHeight);

// Shape and smoothing
rmSetAreaCoherence(continent2, 0.9);
rmSetAreaSmoothDistance(continent2, 7);
rmSetAreaHeightBlend(continent2, 1);

// CRITICAL: Elevation variation creates random lakes!
rmSetAreaElevationVariation(continent2, 7);  // ±7 meters variation
rmSetAreaElevationNoiseBias(continent2, 0);
rmSetAreaElevationEdgeFalloffDist(continent2, 6);
rmSetAreaElevationPersistence(continent2, 0.4);
rmSetAreaElevationOctaves(continent2, 5);
rmSetAreaElevationMinFrequency(continent2, 0.02);
rmSetAreaElevationType(continent2, cElevTurbulence);

rmAddAreaConstraint(continent2, avoidTradeRouteSmall);
rmSetAreaObeyWorldCircleConstraint(continent2, false);
rmBuildArea(continent2);
```

---

##### **How Elevation Variation Creates Lakes**

**Key function:** `rmSetAreaElevationVariation(continent2, 7);`

This adds **±7 meters of random height variation** across the continent:

```
Base Height: 0.6-0.9 (waterHeight)
Variation: ±7 meters

Result:
- High points: waterHeight + 7 = ~7.6-7.9 meters (LAND)
- Low points: waterHeight - 7 = ~-6.4 to -6.1 meters (UNDERWATER = LAKES!)
```

**Sea level is at height 1.0:**
- Terrain **above 1.0** = Walkable land
- Terrain **below 1.0** = Water (lakes)

---

##### **Why Parts Are Underwater**

The continent's `baseHeight` (0.6-0.9) is **below sea level** (1.0). Combined with elevation variation:

```
Example with waterHeight = 0.7:

Highest terrain: 0.7 + 7 = 7.7 meters (well above water = hills)
Medium terrain: 0.7 + 3 = 3.7 meters (above water = flat land)
Low terrain:     0.7 - 2 = -1.3 meters (below water = shallow lakes)
Lowest terrain:  0.7 - 7 = -6.3 meters (deep underwater = lakes)
```

**Result:** Natural-looking continent with scattered lakes where terrain dips below sea level!

---

##### **The Key Contrast: Fixed vs Random**

| Feature | Player Plateaus (Part 1) | Central Continent (Part 2) |
|---------|-------------------------|---------------------------|
| **Base Height** | 1.0 (fixed, above water) | 0.6-0.9 (random, near water) |
| **Elevation Variation** | ❌ None (flat) | ✅ ±7 meters (random) |
| **Result** | Always land | Mix of land + lakes |
| **Purpose** | Guaranteed buildable area | Natural randomized terrain |
| **Placement** | Player spawn locations | Center of map |
| **Predictability** | 100% land every game | Different every game |

**Why use both?**
- **Players need certainty** - TC must have flat, buildable land
- **Map needs variety** - Random lakes make each game unique
- **Strategic balance** - Fixed spawns, random center resources

---

##### **Visual Breakdown**

```
Height:
  8.0 ─────  Hills/mountains (land)
  5.0 ─────  Elevated terrain (land)
  3.0 ─────  Flat land
  1.0 ═════  SEA LEVEL (water surface)
  0.0 ─────  Shallow water (lakes)
 -3.0 ─────  Deeper water (lakes)
 -6.0 ─────  Deep water (lakes)
```

Elevation variation randomly pushes terrain **up** (land) and **down** (lakes).

---

##### **Map Layout: How Both Techniques Work Together**

```
Top-down view of New Guinea map:

        Ocean (height 0.0)
    ┌─────────────────────────┐
    │  [P1 Plateau]           │  Player 1: Fixed height 1.0
    │   (flat land)           │  NO variation = guaranteed land
    │                         │
    │     ╔═══════════╗       │  Central Continent:
    │  [P2│ ~ lake ~  │P3]    │  - Base height 0.6-0.9 (random)
    │     │ ▓▓ land ▓▓│       │  - Elevation variation ±7
    │     │ ~ lake ~  │       │  - Random lakes where dips < 1.0
    │     ╚═══════════╝       │  - Hills where rises > 2.0
    │                         │
    │  [P4 Plateau]           │  Player 4: Fixed height 1.0
    │   (flat land)           │  NO variation = guaranteed land
    └─────────────────────────┘
        Ocean (height 0.0)

Legend:
[Px Plateau] = Fixed elevated areas (always land)
╔═══════╗    = Random continent (land + lakes mix)
~ lake ~     = Areas where elevation < 1.0 (water)
▓▓ land ▓▓   = Areas where elevation > 1.0 (land)
```

**Result on the map:**
1. **Player spawns** → Isolated flat plateaus (predictable, buildable)
2. **Center area** → Random mix of land and lakes (varies each game)
3. **Surroundings** → Ocean at height 0.0

---

##### **Why This Technique Works**

✅ **Natural randomization** - Every map has different lake patterns  
✅ **No manual placement** - Lakes appear automatically  
✅ **Organic appearance** - Lakes look natural, not artificial  
✅ **Varied gameplay** - Different water/land ratios each game  
✅ **Reduces predictability** - No two maps are identical  

---

##### **Key Parameters Explained**

**`rmSetAreaElevationVariation(id, variance)`**
- Controls how much terrain height varies (±meters)
- Higher value = more dramatic hills AND deeper lakes
- New Guinea uses 7 = significant variation

**`rmSetAreaElevationType(id, cElevTurbulence)`**
- `cElevTurbulence` = Natural, random noise pattern
- Creates organic-looking elevation changes
- Alternative: `cElevFractal` for more structured patterns

**`rmSetAreaElevationOctaves(id, octaves)`**
- Controls detail level of terrain noise
- Higher = more fine detail in elevation
- New Guinea uses 5 = medium detail

**`rmSetAreaElevationPersistence(id, value)`**
- Controls how much each octave contributes
- 0.4 = balanced between large and small features

---

##### **Comparison: Fixed vs Random Lakes**

| Approach | Fixed Water Areas | Elevation Variation (New Guinea) |
|----------|------------------|----------------------------------|
| **Setup** | Manual `rmSetAreaWaterType()` | Automatic via elevation |
| **Randomization** | Same pattern every game | Different every game |
| **Code complexity** | More code (each lake) | Less code (one area) |
| **Visual result** | Predictable placement | Organic, natural |
| **Best for** | Strategic lakes | Chaotic, varied maps |

---

##### **Common Mistakes**

❌ **Base height too high** - If baseHeight > 1.0, no lakes form (all land)  
❌ **Variation too small** - Terrain never dips below sea level  
❌ **Variation too large** - Entire continent underwater or extreme mountains  
❌ **Wrong elevation type** - Some types don't create natural patterns  

---

##### **When to Use This Technique**

✅ **Random map generation** - Want every game to be unique  
✅ **Natural-looking terrain** - Organic lakes and hills  
✅ **Water-based maps** - Continents rising from ocean  
✅ **Unpredictable gameplay** - Players must adapt to terrain  

❌ **Don't use when:**
- Need predictable, balanced lake positions
- Want specific strategic water placement
- Require symmetrical terrain for competitive play

---

### **14.3. Cliffs and Ramps**

There are two main approaches to creating cliffs with accessible ramps. Each has distinct advantages.

#### **Method 1: Simple (Automatic Ramps)**

**Best for:** Quick cliff setup, natural-looking random ramp placement, when you don't need precise ramp locations

**Uses `rmSetAreaCliffEdge()` to automatically generate ramps** around the cliff perimeter.

```cpp
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

##### **Method 2: Manual (Controlled Ramps)**

**Best for:** Precise ramp placement, flat cliff tops for buildings, strategic gameplay design

**Uses a controller + manually placed ramp areas BEFORE building the main cliff.**

```cpp
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

##### **Comparison Table**

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

##### **When to Use Each Method**

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

##### **Common Mistakes**

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

##### **Basic Cliff Setup (No Ramps)**

```cpp
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

#### **14.2.2 Area creation Loops:**

Sometimes you need to create multiple similar areas (walls, decorative cliffs, terrain patches) with slight variations in position or size. Use a loop with conditional statements for each variation.

**Example from Versailles - Wall Cliffs:**

This pattern creates 12 cliff areas around the map perimeter, with different positions and sizes for each segment.

```cpp
// Loop creates 12 separate wall cliff segments
for (j=0; < 12) {   
 
    // Create cliff area with unique ID
    int wallCliffs = rmCreateArea("wallCliffs"+j);
    rmSetAreaObeyWorldCircleConstraint(wallCliffs, false);
    rmAddAreaToClass(wallCliffs, rmClassID("classPlateau"));
    
    // Common constraints for all segments
    rmAddAreaConstraint(wallCliffs, avoidFence);
    rmAddAreaConstraint(wallCliffs, avoidTradeRouteWall);
    rmAddAreaConstraint(wallCliffs, avoidWall);
    
    // Common cliff settings
    rmSetAreaCliffType(wallCliffs, "Northwest Territory");
    rmAddAreaToClass(wallCliffs, classMountains);
    rmSetAreaCliffEdge(wallCliffs, 1, 1, 0.0, 0.0, 2);
    rmSetAreaCliffPainting(wallCliffs, false, true, true, 1.5, true);
    rmSetAreaCliffHeight(wallCliffs, 0, 0, 0.5);
    rmSetAreaBaseHeight(wallCliffs, 5.0);
    rmSetAreaHeightBlend(wallCliffs, 3);
    
    // Variation 1 - Right side, lower position
    if (j == 0) {
        rmSetAreaSize(wallCliffs, rmAreaTilesToFraction(150), rmAreaTilesToFraction(150));
        rmSetAreaCoherence(wallCliffs, 0.93);
        rmSetAreaLocation(wallCliffs, 0.9, mapCenter+rmZTilesToFraction(9));
        rmAddAreaInfluenceSegment(wallCliffs, 0.78, mapCenter+rmZTilesToFraction(9), 
                                              1.0, mapCenter+rmZTilesToFraction(9));
    }
    
    // Variation 2 - Left side, lower position
    if (j == 1) {
        rmSetAreaSize(wallCliffs, rmAreaTilesToFraction(150), rmAreaTilesToFraction(150));
        rmSetAreaCoherence(wallCliffs, 0.93);
        rmSetAreaLocation(wallCliffs, 0.1, mapCenter+rmZTilesToFraction(9));
        rmAddAreaInfluenceSegment(wallCliffs, 0.0, mapCenter+rmZTilesToFraction(9), 
                                              0.26, mapCenter+rmZTilesToFraction(9));
    }
    
    // Variation 3 - Right side, upper position (smaller)
    if (j == 2) {
        rmSetAreaSize(wallCliffs, rmAreaTilesToFraction(80), rmAreaTilesToFraction(80));
        rmSetAreaCoherence(wallCliffs, 0.93);
        rmSetAreaLocation(wallCliffs, 0.8, mapCenter+rmZTilesToFraction(35));
        rmAddAreaInfluenceSegment(wallCliffs, 0.78, mapCenter+rmZTilesToFraction(35), 
                                              0.84, mapCenter+rmZTilesToFraction(35));
    }
    
    // Variation 4 - Left side, upper position (smaller)
    if (j == 3) {
        rmSetAreaSize(wallCliffs, rmAreaTilesToFraction(80), rmAreaTilesToFraction(80));
        rmSetAreaCoherence(wallCliffs, 0.93);
        rmSetAreaLocation(wallCliffs, 0.2, mapCenter+rmZTilesToFraction(35));
        rmAddAreaInfluenceSegment(wallCliffs, 0.16, mapCenter+rmZTilesToFraction(35), 
                                              0.27, mapCenter+rmZTilesToFraction(35));
    }
    
    // ... more variations for j == 4, 5, 6, etc.
    
    // Build each cliff segment
    rmBuildArea(wallCliffs);
}
```

**Key characteristics:**
- ✅ **Unique area names:** `"wallCliffs"+j` creates unique IDs
- ✅ **Common properties set once:** Cliff type, constraints, height settings
- ✅ **Conditional variations:** Different positions/sizes per iteration
- ✅ **Build inside loop:** `rmBuildArea()` called for each segment

**Pattern structure:**
1. **Loop declaration:** `for (j=0; < totalCount)`
2. **Create area:** `rmCreateArea("name"+j)`
3. **Set common properties:** Settings that apply to all variations
4. **Conditional variations:** `if (j == 0)`, `if (j == 1)`, etc.
5. **Build area:** `rmBuildArea()` inside the loop

**When to use this pattern:**
- ✅ Decorative walls or cliffs around map perimeter
- ✅ Multiple terrain patches with varied positions
- ✅ Scattered decorative areas (ruins, forests, rocks)
- ✅ Symmetrical features that mirror across map center

**Advantages:**
- 🎯 Reduces code duplication
- 🎯 Easy to adjust common properties for all areas
- 🎯 Can create many variations efficiently
- 🎯 Maintains consistent styling across areas

**Disadvantages:**
- ⚠️ Can become verbose with many conditional blocks
- ⚠️ Harder to visualize final placement
- ⚠️ Each variation needs explicit positioning

---

#### **14.2.3 Randomly Placed Areas (Constraint-Based):**

Instead of explicitly positioning each area with `if` statements, let **constraints handle the placement**. This creates natural, scattered distributions - perfect for decorative cliffs, forests, or terrain patches.

**Example from Balearic Islands - Random FFA Cliffs:**

This pattern creates randomly scattered cliff areas across the map, using constraints to avoid important features.

```cpp
// Create multiple random cliff areas (scaled by player count)
for (j=0; < (2.5*cNumberNonGaiaPlayers-cNumberTeams)) {   
    
    int ffaCliffs = rmCreateArea("ffaCliffs"+j);
    rmSetAreaSize(ffaCliffs, rmAreaTilesToFraction(50), rmAreaTilesToFraction(100));
    rmAddAreaToClass(ffaCliffs, rmClassID("classPlateau"));
    
    // Cliff settings
    rmSetAreaCliffType(ffaCliffs, cliffType);
    rmSetAreaCliffEdge(ffaCliffs, 1, 0.8, 0.0, 0.0, 2);
    rmSetAreaCliffPainting(ffaCliffs, true, true, true, 1.5, true);
    rmSetAreaCliffHeight(ffaCliffs, rmRandInt(6,8), 1, 0.5);  // Random height!
    rmSetAreaSmoothDistance(ffaCliffs, 10);
    rmSetAreaHeightBlend(ffaCliffs, 3);
    rmAddAreaToClass(ffaCliffs, rmClassID("classCliff"));
    
    // ⚠️ NO EXPLICIT LOCATION! Constraints determine placement
    rmAddAreaConstraint(ffaCliffs, forestConstraint);
    rmAddAreaConstraint(ffaCliffs, avoidAll);
    rmAddAreaConstraint(ffaCliffs, avoidTP);
    rmAddAreaConstraint(ffaCliffs, avoidTCMedium);
    rmAddAreaConstraint(ffaCliffs, avoidSocket);
    rmAddAreaConstraint(ffaCliffs, avoidCliff);
    rmAddAreaConstraint(ffaCliffs, shortAvoidImpassableLand);
    
    // Build with random placement
    rmBuildArea(ffaCliffs);
}
```

**Why are these placed randomly?**

Unlike the Versailles wall cliffs which use explicit positions (`if (j == 0)` sets location), these cliffs:

1. **No `rmSetAreaLocation()` call:**
   - No explicit X/Z coordinates specified
   - Engine chooses random valid locations

2. **Constraints control placement:**
   - `avoidTP`, `avoidTCMedium`, `avoidSocket` keep away from important features
   - `avoidCliff` prevents cliffs overlapping
   - `forestConstraint`, `avoidAll` maintain spacing
   - Random location must satisfy ALL constraints

3. **Natural distribution:**
   - Each cliff appears in a different random spot
   - Creates organic, scattered appearance
   - Better for decorative/aesthetic features

4. **Variable height:**
   - `rmRandInt(6,8)` randomizes cliff height
   - Adds more natural variation

**Comparison: Explicit vs Random Placement**

| Aspect | Explicit (Versailles) | Random (Balearic) |
|--------|----------------------|-------------------|
| **Location** | `rmSetAreaLocation()` + conditionals | No location (constraints only) |
| **Positioning** | Fixed, predictable positions | Random, scattered positions |
| **Constraints** | Used for avoidance | Used to define valid zones |
| **Best for** | Walls, symmetric features | Decorative cliffs, forests |
| **Variability** | Same positions every time | Different layout each game |

**Pattern structure:**
1. **Calculate count:** Scale by player count/teams
2. **Loop through count:** `for (j=0; < count)`
3. **Create area:** `rmCreateArea("name"+j)`
4. **Set properties:** Size, cliff settings, classes
5. **Add constraints:** Define where it CAN'T go
6. **Build area:** `rmBuildArea()` finds random valid spot

**Common uses for random placement:**

✅ **Decorative cliffs** - Scattered across map  
✅ **Forests** - Most common use case (see section 14.2.4)  
✅ **Rock formations** - Aesthetic terrain features  
✅ **Terrain patches** - Random dirt/grass/sand spots  
✅ **Small decorative areas** - Ruins, clearings, etc.

**Advantages:**
- 🎯 Natural, organic distribution
- 🎯 Different every game (replayability)
- 🎯 No need to plan exact positions
- 🎯 Scales automatically with map size

**Disadvantages:**
- ⚠️ Can fail if constraints too strict
- ⚠️ Unpredictable final appearance
- ⚠️ May cluster in some areas
- ⚠️ Harder to ensure symmetry

**Tips for random placement:**

✅ **Use reasonable constraints** - Too many = placement failures  
✅ **Scale count with players** - More players = more features  
✅ **Add failure warnings** - `rmSetAreaWarnFailure(false)` if optional  
✅ **Test with different player counts** - Ensure enough valid spots  
✅ **Use class constraints** - Prevent clustering (`avoidForest`, `avoidCliff`)  

---

#### **14.2.4 Forests:**

Forests are one of the most common random placement features. They can be placed randomly across the map or confined to specific regions using directional or area-based constraints.

**Example 1: Random Forests with Basic Settings**

```cpp
// Create random forests across the map
int forestCount = 8 + 2*cNumberNonGaiaPlayers;

for (i=0; < forestCount) {
    int forestID = rmCreateArea("forest "+i);
    rmSetAreaSize(forestID, rmAreaTilesToFraction(50), rmAreaTilesToFraction(100));
    rmSetAreaForestType(forestID, forestType);
    rmSetAreaCoherence(forestID, 0.4);
    
    // Constraints define where forests can spawn
    rmAddAreaConstraint(forestID, avoidTC);
    rmAddAreaConstraint(forestID, avoidStartingResources);
    rmAddAreaConstraint(forestID, forestConstraint);  // Avoid other forests
    rmAddAreaConstraint(forestID, avoidImpassableLand);
    
    // Build at random valid location
    rmBuildArea(forestID);
}
```

**Example 2: Single Large Forest Area**

```cpp
// Create a single large forest
int forestID = rmCreateArea("main forest");
rmSetAreaSize(forestID, 0.10);  // 10% of map
rmSetAreaForestType(forestID, "Italian Forest");  // Mediterranean trees

// Configure forest density and appearance
rmSetAreaForestDensity(forestID, 0.7);       // 0.0 to 1.0 (70% dense)
rmSetAreaForestClumpiness(forestID, 0.5);    // How clustered (0.0 = scattered, 1.0 = tight)
rmSetAreaCoherence(forestID, 0.4);            // Shape coherence

// Position and build
rmSetAreaLocation(forestID, forestXLoc, forestYLoc);
rmBuildArea(forestID);
```

**Example 3: Multiple Small Forest Patches**

```cpp
// Create scattered small forest patches
int numberPatches = 15;

for(i=0; < numberPatches) {
   int smallForest = rmCreateArea("forest patch "+i);
   rmSetAreaSize(smallForest, rmAreaTilesToFraction(60));
   rmSetAreaForestType(smallForest, "z31 Mediterranean Coastal Forest");
   rmSetAreaForestDensity(smallForest, 0.5);
   rmSetAreaForestClumpiness(smallForest, 0.9);  // Very clustered
   rmSetAreaCoherence(smallForest, 0.6);
   
   // Random placement across entire map
   rmSetAreaLocation(smallForest, rmRandFloat(0.0, 1.0), rmRandFloat(0.0, 1.0));
   rmBuildArea(smallForest);
}
```

**Example 4: Sub-Biome Forests with Directional Constraints (Dead Sea Pattern)**

This is a very common Age of Pirates pattern where different forest types are placed in different regions based on directional constraints, creating distinct sub-biomes.

```cpp
// Define directional constraints (pie constraints for cardinal directions)
int Northward = rmCreatePieConstraint("northMapConstraint", 0.5, 0.5, 0, rmZFractionToMeters(0.5), 
                                      rmDegreesToRadians(315), rmDegreesToRadians(135));
int Southward = rmCreatePieConstraint("southMapConstraint", 0.5, 0.5, 0, rmZFractionToMeters(0.5), 
                                      rmDegreesToRadians(135), rmDegreesToRadians(315));

// Northern forests (desert vegetation)
int numTriesNorth = 20 + 7*cNumberNonGaiaPlayers;
int failCount = 0;

for (i=0; < numTriesNorth) {
   int northForest = rmCreateArea("northforest"+i);
   rmSetAreaWarnFailure(northForest, false);
   rmSetAreaSize(northForest, rmAreaTilesToFraction(100), rmAreaTilesToFraction(200));
   
   // Desert forest type for northern biome
   rmSetAreaForestType(northForest, "z45 arabian desert");
   rmSetAreaForestDensity(northForest, 1.0);
   rmSetAreaForestClumpiness(northForest, 0.0);
   rmSetAreaForestUnderbrush(northForest, 0.0);
   rmSetAreaCoherence(northForest, 0.4);
   
   // Standard constraints
   rmAddAreaConstraint(northForest, avoidTownCenterFar);
   rmAddAreaConstraint(northForest, avoidTradeRoute);
   rmAddAreaConstraint(northForest, forestConstraint);  // Avoid other forests
   
   // ⚠️ KEY: Directional constraint keeps forests in NORTH only
   rmAddAreaConstraint(northForest, Northward);
   
   // Build with failure handling
   if(rmBuildArea(northForest)==false) {
      failCount++;
      if(failCount==5) break;  // Stop after 5 consecutive failures
   }
   else failCount=0;
}

// Southern forests (could be different vegetation type)
int numTriesSouth = 5*cNumberNonGaiaPlayers;
failCount = 0;

for (i=0; < numTriesSouth) {
   int southForest = rmCreateArea("southForest"+i);
   rmSetAreaWarnFailure(southForest, false);
   rmSetAreaSize(southForest, rmAreaTilesToFraction(100), rmAreaTilesToFraction(200));
   
   // Same type in Dead Sea, but could be different (e.g., "Borneo Palm Forest")
   rmSetAreaForestType(southForest, "z45 arabian desert");
   rmSetAreaForestDensity(southForest, 1.0);
   rmSetAreaForestClumpiness(southForest, 0.0);
   rmSetAreaCoherence(southForest, 0.4);
   
   rmAddAreaConstraint(southForest, avoidTownCenterFar);
   rmAddAreaConstraint(southForest, avoidTradeRoute);
   rmAddAreaConstraint(southForest, forestConstraint);
   
   // ⚠️ KEY: Directional constraint keeps forests in SOUTH only
   rmAddAreaConstraint(southForest, Southward);
   
   if(rmBuildArea(southForest)==false) {
      failCount++;
      if(failCount==5) break;
   }
   else failCount=0;
}
```

**Why use directional constraints for forests:**
- 🎯 **Sub-biomes** - Create distinct vegetation zones (desert north, tropical south, etc.)
- 🎯 **Thematic maps** - Match forest types to regional climate/theme
- 🎯 **Visual variety** - Different areas look and feel different
- 🎯 **Balance** - Ensure both regions have similar forest coverage

**Directional constraint angles (for reference):**
- **North:** 315° to 135° (upper half of map)
- **South:** 135° to 315° (lower half of map)  
- **East:** 45° to 225° (right half of map)
- **West:** 225° to 45° (left half of map)

**Common variations:**
- Different forest types per region (`"Italian Forest"` north, `"Borneo Palm Forest"` south)
- Different densities per region (sparse desert north, dense jungle south)
- Can use area-based constraints instead (`stayInTeamIsland`, `stayInPlayerArea`)

---

**Forest Configuration Parameters:**

- **`rmSetAreaForestType()`** - Forest type from `forest.xml` or `forest2.xml`
- **`rmSetAreaForestDensity()`** - Tree density: 0.0 (sparse) to 1.0 (very dense)
- **`rmSetAreaForestClumpiness()`** - Tree clustering: 0.0 (evenly spaced) to 1.0 (tight clumps)
- **`rmSetAreaCoherence()`** - Overall shape coherence (affects forest boundary smoothness)
- **`rmSetAreaForestUnderbrush()`** - Undergrowth density: 0.0 (none) to 1.0 (thick)

---

#### **14.2.5 Terrain Patches (Visual Variety):**

Terrain patches are simple areas that use different terrain mixes to add visual variety to the map. They're one of the easiest ways to improve map aesthetics without affecting gameplay.

**Why Use Terrain Patches:**

- 🎨 **Visual interest** - Breaks up monotonous terrain
- 🌍 **Biome variety** - Creates regional differences (dry grass, wet grass, dirt, etc.)
- ⚡ **Quick to implement** - Simple areas with different mixes
- 🎯 **No gameplay impact** - Purely aesthetic (unless using different terrain types)

**Example from Black Sea - Northern and Southern Terrain Patches:**

This creates two large terrain patches with different grass mixes in the northern and southern regions to add visual variety to the continent.

```cpp
// Define terrain mixes first
string baseMix = "italy_grass";          // Main continent terrain
string paintMix = "italy_grass_dry";     // Drier variant for patches

// Create two terrain patches (north and south)
for (i=0; < 2) {
    int patchID = rmCreateArea("patch "+i);
    
    // Size and appearance
    rmSetAreaSize(patchID, rmAreaTilesToFraction(500), rmAreaTilesToFraction(500));
    rmSetAreaCoherence(patchID, 1.0);                    // High coherence = smooth edges
    rmSetAreaMix(patchID, paintMix);                     // Different terrain mix!
    
    // Constraints to keep patches away from important features
    rmAddAreaConstraint(patchID, avoidCityShort);
    rmAddAreaConstraint(patchID, mediumGreatLakesConstraint);
    rmAddAreaConstraint(patchID, avoidTradeRouteFar3);
    rmAddAreaConstraint(patchID, avoidCityState);
    
    // NORTHERN PATCH (i == 0)
    if (i == 0) {
        if (PlayerNum == 2 || PlayerNum > 6) {
            // Larger maps - further north
            rmSetAreaLocation(patchID, 0.2, 0.5+rmZTilesToFraction(53));
            rmAddAreaInfluenceSegment(patchID, 0.2, 0.5+rmZTilesToFraction(53), 0.22, 0.5+rmZTilesToFraction(43));
            rmAddAreaInfluenceSegment(patchID, 0.16, 0.5+rmZTilesToFraction(49), 0.2, 0.5+rmZTilesToFraction(59));
        } else {
            // Smaller maps - closer to center
            rmSetAreaLocation(patchID, 0.2, 0.5+rmZTilesToFraction(49));
            rmAddAreaInfluenceSegment(patchID, 0.16, 0.5+rmZTilesToFraction(45), 0.2, 0.5+rmZTilesToFraction(49));
            rmAddAreaInfluenceSegment(patchID, 0.2, 0.5+rmZTilesToFraction(49), 0.22, 0.5+rmZTilesToFraction(45));
        }
    }
    // SOUTHERN PATCH (i == 1)
    else {
        if (PlayerNum == 2 || PlayerNum > 6) {
            // Larger maps - further south
            rmSetAreaLocation(patchID, 0.2, 0.5-rmZTilesToFraction(44));
            rmAddAreaInfluenceSegment(patchID, 0.2, 0.5-rmZTilesToFraction(44), 0.22, 0.5-rmZTilesToFraction(40));
            rmAddAreaInfluenceSegment(patchID, 0.16, 0.5-rmZTilesToFraction(40), 0.2, 0.5-rmZTilesToFraction(44));
        } else {
            // Smaller maps - closer to center
            rmSetAreaLocation(patchID, 0.2, 0.5-rmZTilesToFraction(47));
            rmAddAreaInfluenceSegment(patchID, 0.2, 0.5-rmZTilesToFraction(47), 0.22, 0.5-rmZTilesToFraction(43));
            rmAddAreaInfluenceSegment(patchID, 0.16, 0.5-rmZTilesToFraction(43), 0.2, 0.5-rmZTilesToFraction(47));
        }
    }
    
    rmBuildArea(patchID);
}

// RESULT: Two drier grass patches appear on the main continent
//         North patch = dry grass in northern region
//         South patch = dry grass in southern region
//         Creates visual regionalization without affecting gameplay
```

**Key characteristics:**

- ✅ **Different mix than base:** `paintMix` (dry grass) vs `baseMix` (regular grass)
- ✅ **High coherence:** Smooth, natural-looking patches (1.0)
- ✅ **Fixed positions:** North and south of center using conditionals
- ✅ **Influence segments:** Create irregular, organic shapes
- ✅ **Scale with map size:** Different positions for different player counts
- ✅ **Constraints:** Avoid cities, water, trade routes

**Common terrain mix variations:**

```cpp
// Grass variants
string baseMix = "grass";
string patchMix = "grass_dry";              // Drier grass
string patchMix2 = "grass_medium";          // Medium grass
string patchMix3 = "grass_wet";             // Wetter grass

// Dirt variants
string baseMix = "dirt";
string patchMix = "dirt_dark";              // Darker dirt
string patchMix2 = "sand";                  // Sandy patches

// Regional mixes (Italy example)
string baseMix = "italy_grass";
string patchMix = "italy_grass_dry";        // Drier variant
string patchMix2 = "italy_grass_medium";    // Medium variant
string patchMix3 = "italy_cliff_top";       // Rocky variant
```

**Simple random patches pattern:**

For scattered small patches across the map, use random placement:

```cpp
// Create many small random patches
for (i=0; < 100+cNumberNonGaiaPlayers*50) {
    int patchID = rmCreateArea("terrain patch "+i);
    rmSetAreaWarnFailure(patchID, false);                    // Don't warn if placement fails
    rmSetAreaSize(patchID, rmAreaTilesToFraction(37), rmAreaTilesToFraction(42));
    rmSetAreaMix(patchID, "italy_grass_medium");             // Different terrain
    rmSetAreaSmoothDistance(patchID, 1.0);                   // Slight blending
    
    // Constraints define where patches can appear
    rmAddAreaConstraint(patchID, avoidCity);
    rmAddAreaConstraint(patchID, avoidWater);
    rmAddAreaConstraint(patchID, northernRegionConstraint); // Optional: region-specific
    
    rmBuildArea(patchID);
    // Random placement within constraints = natural scattered appearance
}
```

**When to use terrain patches:**

✅ **Visual polish** - Quick way to improve map aesthetics  
✅ **Regional identity** - North vs south, wet vs dry areas  
✅ **Breaking monotony** - Large single-terrain maps  
✅ **Biome transitions** - Gradual shifts between terrain types  
✅ **Historical accuracy** - Different soil types, climate zones  

**Patch size guidelines:**

```cpp
// Tiny patches (scattered detail)
rmSetAreaSize(patchID, rmAreaTilesToFraction(20), rmAreaTilesToFraction(40));

// Small patches (visual accents)
rmSetAreaSize(patchID, rmAreaTilesToFraction(50), rmAreaTilesToFraction(100));

// Medium patches (regional zones) - Black Sea example
rmSetAreaSize(patchID, rmAreaTilesToFraction(500), rmAreaTilesToFraction(500));

// Large patches (major terrain zones)
rmSetAreaSize(patchID, 0.05, 0.1);
```

**Tips for terrain patches:**

✅ **Match biome** - Use terrain mixes from same family (italy_grass_*, grass_*, etc.)  
✅ **High coherence** - Smooth, natural patches (0.7-1.0)  
✅ **Influence segments** - Create irregular shapes for large patches  
✅ **Scale count with players** - More players = larger map = more patches  
✅ **Layer patches** - Multiple types for complex visual variety  
✅ **Add smooth distance** - Blend edges with surrounding terrain  

**Advantages:**
- 🎯 Extremely simple to implement
- 🎯 No gameplay impact (purely visual)
- 🎯 Adds significant visual polish
- 🎯 Can create regional identity

**Disadvantages:**
- ⚠️ Purely aesthetic (no strategic value)
- ⚠️ Can look random if poorly placed
- ⚠️ Too many patches = visual clutter
- ⚠️ Wrong mixes can clash with theme

**Comparison: Fixed vs Random Patches**

| Aspect | Fixed Patches (Black Sea) | Random Patches |
|--------|---------------------------|----------------|
| **Placement** | Explicit positions (north/south) | Constraint-based random |
| **Count** | Usually 2-10 | Often 50-200 |
| **Size** | Medium to large | Small to medium |
| **Purpose** | Regional identity | Visual texture |
| **Control** | Precise placement | Scattered naturally |
| **Best for** | Strategic regions | Overall aesthetics |

---

#### **14.2.6 Multi-Layered Structures (Volcanoes, Pyramids)**

The layered area approach can also be used for complex 3D structures like **volcanoes, mountains, and pyramids**. These features stack multiple cliff and terrain areas on top of each other at the same location with decreasing sizes and increasing heights.

**For volcano implementation, see:**
- **File:** `randmaps/zpunknown.xs` (Unknown map)
- **Location:** Lines ~4804-5103 (map is still wip so this may differ in the future)
- **Pattern:** Advanced loop-based system creating 5-level volcanic mountain with crater using 22 layered areas

This is an advanced technique that combines areas, cliffs, trade routes, and groupings. Reference the Unknown map for complete implementation details.


---

#### **14.2.7 Connections**


**Purpose:** Connections create pathways between areas, ensuring players can reach different parts of the map. Critical for island maps and multi-plateau layouts.

**Used in:** Hawaii, New Guinea, and any map with separated land masses.

---

##### What Connections Do

Connections **automatically generate terrain** between two or more areas to link them together. They can be:
- **Land bridges** between islands
- **Shallow water passages** between deep ocean areas  
- **Paths** between plateaus
- **Elevated walkways** on top of terrain

---

##### Basic Connection Setup

**Example from Hawaii (Land Connection):**

```cpp
// Create connection between player island and central island
int connectionID1 = rmCreateConnection("connection player "+i);
rmSetConnectionType(connectionID1, cConnectAreas, false, 1);
rmSetConnectionWidth(connectionID1, 30, 8);           // 30m wide, 8m variance
rmSetConnectionCoherence(connectionID1, 0.3);         // Low = natural curves
rmSetConnectionWarnFailure(connectionID1, false);
rmSetConnectionBaseHeight(connectionID1, 0.5);        // Slightly above seafloor
rmSetConnectionHeightBlend(connectionID1, 20);        // Smooth transitions

// Connect the two areas
rmAddConnectionArea(connectionID1, centralIslandID);
rmAddConnectionArea(connectionID1, playerID);

// Replace seafloor with beach texture (LAND CONNECTION ONLY!)
rmAddConnectionTerrainReplacement(connectionID1, "ceylon\\seafloor5_ceylon", "caribbean\\ground_shoreline1_crb");

rmBuildConnection(connectionID1);
```

---

##### Key Functions

##### `rmSetConnectionType(connectionID, type, flag, variance)`
- `type`: Usually `cConnectAreas` (connects areas together)
- `flag`: `false` = normal, `true` = special modes
- `variance`: Random variation in path (1.0 = normal)

##### `rmSetConnectionWidth(connectionID, width, variance)`
- `width`: Width in meters (20-50 typical)
- `variance`: Random width variation (0-10)

##### `rmSetConnectionCoherence(connectionID, coherence)`
- `0.0-0.5`: Natural, curving paths (organic)
- `0.6-1.0`: Straight, direct paths (artificial)

##### `rmSetConnectionBaseHeight(connectionID, height)`
- Height of the connection terrain
- Must be between the two areas it connects

##### `rmSetConnectionHeightBlend(connectionID, distance)`
- How far the height transitions smoothly (10-30 meters)
- Higher = gentler slopes

##### `rmAddConnectionTerrainReplacement(connectionID, oldTerrain, newTerrain)`
- ⚠️ **ONLY works for LAND connections!**
- Replaces terrain type along the connection path
- Example: Replace seafloor with beach sand

---

##### Land vs Shallow Water Connections

**Hawaii shows both types:**

##### Type 1: Land Connection (with Terrain Replacement) ✅

```cpp
// Player islands connected to center with LAND bridges
int connectionID1 = rmCreateConnection("connection player "+i);
rmSetConnectionType(connectionID1, cConnectAreas, false, 1);
rmSetConnectionWidth(connectionID1, 30, 8);
rmSetConnectionBaseHeight(connectionID1, 0.5);      // Above seafloor
rmSetConnectionHeightBlend(connectionID1, 20);

rmAddConnectionArea(connectionID1, centralIslandID);
rmAddConnectionArea(connectionID1, playerID);

// ✅ Works! Terrain replacement creates beach
rmAddConnectionTerrainReplacement(connectionID1, 
    "ceylon\\seafloor5_ceylon",       // Old: seafloor
    "caribbean\\ground_shoreline1_crb");  // New: beach sand

rmBuildConnection(connectionID1);
```

**Result:** Walkable land bridge with beach texture connecting islands.

---

##### Type 2: Shallow Water Connection (No Terrain Replacement) ❌

```cpp
// Bonus islands connected to center with SHALLOW WATER
int connectionID2 = rmCreateConnection("connection bonus 1");
rmSetConnectionType(connectionID2, cConnectAreas, false, 1);
rmSetConnectionWidth(connectionID2, 30, 30);
rmSetConnectionBaseHeight(connectionID2, 0.5);      // Below water level
rmSetConnectionHeightBlend(connectionID2, 30);

rmAddConnectionArea(connectionID2, centralIslandID);
rmAddConnectionArea(connectionID2, bonusIsland1);

// ❌ NO terrain replacement - doesn't work underwater!
// rmAddConnectionTerrainReplacement(...);  // This would fail

rmBuildConnection(connectionID2);
```

**Result:** Shallow water passage (ships can sail, units cannot walk).

---

##### Why the Difference?

| Feature | Land Connection | Shallow Water Connection |
|---------|----------------|-------------------------|
| **Base Height** | > 1.0 (above water) | 0.0-0.9 (below water) |
| **Terrain Replacement** | ✅ Works | ❌ Doesn't work underwater |
| **Walkable** | ✅ Yes | ❌ No (ships only) |
| **Visual Result** | Land bridge, beach | Shallow water, reef |
| **Use Case** | Connect player spawn islands | Connect bonus/resource islands |

**Technical reason:** `rmAddConnectionTerrainReplacement()` only functions on land-height terrain. It cannot replace water-type terrain because water is handled differently by the engine.


---

### **14.3. Water Areas (Lakes and fake Rivers)**

Water areas create lakes, ponds, rivers, and other water features on land maps. They use `rmSetAreaWaterType()` to define the water appearance.

---

#### **Water Types - Three Use Cases**

##### **A) Base Ocean/Sea (Map-wide water)**

```cpp
// Set the water type for the entire map
rmSetSeaType("Caribbean Coast");

// Initialize the base terrain as water
rmTerrainInitialize("water");
```

**Used for:** Setting the primary ocean/sea water type for the entire map.

---

##### **B) Lake (Water area within land)**

```cpp
// Create a water area (simplified example)
int basinsID = rmCreateArea("Verseilles Basins");
rmSetAreaWaterType(basinsID, "ZP Verseilles Pond");
rmBuildArea(basinsID);
```

**Used for:** Creating lakes, ponds, or localized water bodies on land.

---

##### **C) River (Flowing water connection)**

```cpp
// Create a river with waypoints
int riverID = rmRiverCreate(-1, "ZP Hansa Baltic Lake", 4, 4, 39, 39);
rmRiverAddWaypoint(riverID, 0.3, 0.65);
rmRiverAddWaypoint(riverID, 0.7, 0.65);
rmRiverBuild(riverID);
```

**Used for:** Creating rivers that flow across the map connecting different areas.

---

#### **14.3.1 Simple Lakes:**

Lakes are water areas placed on land maps, typically at or below sea level. They're simpler than islands - just define size, location, and water type.

**Example from Australia - Lake Eyre (Red Lake):**

This creates a distinctive red-colored lake in the center of the Australian continent.

```cpp
// Create Lake Eyre (red lake)
int deadSeaLakeDeepID = rmCreateArea("Lake Eyre");

// Define water type (custom red lake appearance)
rmSetAreaWaterType(deadSeaLakeDeepID, "ZP Australia Red Lake");

// Size and shape
rmSetAreaSize(deadSeaLakeDeepID, 0.007, 0.007);        // Small lake
rmSetAreaCoherence(deadSeaLakeDeepID, 0.3);            // Low coherence = organic shape

// Position
rmSetAreaLocation(deadSeaLakeDeepID, 0.55, 0.45);      // Center-right of map

// Smooth edges
rmSetAreaSmoothDistance(deadSeaLakeDeepID, 10);

// Build the lake
rmBuildArea(deadSeaLakeDeepID);
```

**Key command for water areas:**

```cpp
rmSetAreaWaterType(areaID, "waterTypeName");
```

This converts a land area into water. The water type determines appearance (color, texture, reflection).

**Common water types:**

```cpp
// Standard water
rmSetAreaWaterType(lakeID, "great lakes2");           // Great Lakes style
rmSetAreaWaterType(lakeID, "Caribbean Coast");         // Tropical blue water
rmSetAreaWaterType(lakeID, "new england lake");        // New England lake

// Special water
rmSetAreaWaterType(lakeID, "ZP Australia Red Lake");   // Red desert lake
rmSetAreaWaterType(lakeID, "Black Sea");               // Black Sea style
rmSetAreaWaterType(lakeID, "ZP Great Barrier Reef");   // Coral reef water
```

**Key characteristics:**

- ✅ **No base height needed:** Water areas typically at elevation 0.0
- ✅ **Small coherence:** Lower values (0.2-0.4) create natural, organic shapes
- ✅ **Location required:** Unlike random forests, lakes need explicit positioning
- ✅ **Smooth distance:** Creates gradual shore transitions

**Complete lake example (Black Sea map style):**

```cpp
// Create a lake in the center
int centralLakeID = rmCreateArea("central lake");
rmSetAreaWaterType(centralLakeID, "Black Sea");
rmSetAreaSize(centralLakeID, 0.015, 0.015);
rmSetAreaCoherence(centralLakeID, 0.25);
rmSetAreaLocation(centralLakeID, 0.5, 0.5);
rmSetAreaSmoothDistance(centralLakeID, 15);
rmAddAreaConstraint(centralLakeID, avoidPlayerArea);
rmBuildArea(centralLakeID);
```

**When to use lakes:**

✅ **Historical accuracy** - Real geography (Lake Eyre, Great Lakes, etc.)  
✅ **Strategic element** - Forces naval gameplay or routing  
✅ **Visual variety** - Breaks up large land masses  
✅ **Resource distribution** - Fish, naval resources  
✅ **Aesthetic appeal** - Adds color and reflection  

**Lake size guidelines:**

```cpp
// Tiny pond
rmSetAreaSize(lakeID, 0.002, 0.002);      // ~200-400 tiles

// Small lake
rmSetAreaSize(lakeID, 0.007, 0.007);      // ~700-1000 tiles (Lake Eyre)

// Medium lake
rmSetAreaSize(lakeID, 0.015, 0.015);      // ~1500-2000 tiles

// Large lake
rmSetAreaSize(lakeID, 0.03, 0.03);        // ~3000+ tiles
```

**Tips for realistic lakes:**

✅ **Use low coherence (0.2-0.4)** - Creates natural, irregular shorelines  
✅ **Match water to biome** - Desert = red/salt lakes, temperate = blue/green  
✅ **Add smooth distance** - Prevents harsh edges (10-20 recommended)  
✅ **Consider constraints** - Keep lakes away from TCs, trade routes  
✅ **Test different water types** - Water appearance varies greatly  

**Advantages:**
- 🎯 Simple to implement (fewer settings than islands)
- 🎯 Adds visual interest to maps
- 🎯 Creates strategic chokepoints
- 🎯 Enables naval units on land maps

**Disadvantages:**
- ⚠️ Can block player expansion
- ⚠️ May interfere with trade routes
- ⚠️ Requires careful positioning
- ⚠️ Can cause pathfinding issues if too large

**Multiple lakes pattern:**

For maps with several lakes, use constraints to space them:

```cpp
int classLake = rmDefineClass("lake");
int avoidLake = rmCreateClassDistanceConstraint("lakes avoid lakes", classLake, 40.0);

for (i=0; < 3) {
    int lakeID = rmCreateArea("lake "+i);
    rmSetAreaWaterType(lakeID, "great lakes2");
    rmSetAreaSize(lakeID, 0.01, 0.01);
    rmSetAreaCoherence(lakeID, 0.3);
    rmAddAreaConstraint(lakeID, avoidLake);
    rmAddAreaToClass(lakeID, classLake);
    rmBuildArea(lakeID);
    // No location = random placement based on constraints
}
```

---

#### **14.3.2 Layered Water Areas (Different Depths):**

For realistic water bodies, layer multiple water areas with different water types to create depth variation. The water depth is defined in the `waterbodies.xml` file, allowing visual differentiation between shallow and deep areas.

**Why Use Layered Water:**

- 🌊 **Visual depth** - Shows shallow edges and deep centers
- 🎯 **Realistic lakes** - Natural water bodies have depth gradients
- 🐟 **Gameplay zones** - Different depths can support different resources
- 🎨 **Color variation** - Shallow = lighter, deep = darker

**Example from Dead Sea Map - Two-Layer Lake:**

This creates a realistic lake with shallow outer water and deep center water, both at the same location but different sizes.

```cpp
// Define classes for water management
int classGreatLake = rmDefineClass("great lake");
int classDeepWater = rmDefineClass("deep lake");

// LAYER 1: Shallow water (outer/larger lake)
int deadSeaLakeID = rmCreateArea("Dead Sea Lake Shallow");

rmSetAreaWaterType(deadSeaLakeID, "ZP Dead Sea Shallow");  // Shallow water type
rmSetAreaSize(deadSeaLakeID, 0.23, 0.23);                  // Larger area (23% of map)
rmSetAreaCoherence(deadSeaLakeID, 0.8);
rmSetAreaLocation(deadSeaLakeID, 0.5, 0.5);                // Center of map
rmAddAreaToClass(deadSeaLakeID, classGreatLake);
rmSetAreaBaseHeight(deadSeaLakeID, 0.0);                   // Sea level
rmSetAreaObeyWorldCircleConstraint(deadSeaLakeID, false);
rmSetAreaSmoothDistance(deadSeaLakeID, 10);

rmBuildArea(deadSeaLakeID); 


// LAYER 2: Deep water (inner/smaller lake)
int deadSeaLakeDeepID = rmCreateArea("Dead Sea Lake Deep");

rmSetAreaWaterType(deadSeaLakeDeepID, "ZP Dead Sea");      // Deep water type
rmSetAreaSize(deadSeaLakeDeepID, 0.08, 0.08);              // Smaller area (8% of map)
rmSetAreaCoherence(deadSeaLakeDeepID, 0.9);                // Higher coherence = rounder
rmSetAreaLocation(deadSeaLakeDeepID, 0.5, 0.5);            // Same center!
rmAddAreaToClass(deadSeaLakeDeepID, classGreatLake);
rmSetAreaBaseHeight(deadSeaLakeDeepID, 0.0);               // Same elevation
rmSetAreaObeyWorldCircleConstraint(deadSeaLakeDeepID, false);
rmSetAreaSmoothDistance(deadSeaLakeDeepID, 10);

rmBuildArea(deadSeaLakeDeepID);
rmAddAreaToClass(deadSeaLakeDeepID, classDeepWater);       // Also add to deep water class

// RESULT: Lake with depth gradient
//   Outer ring: Shallow water (lighter color, 0.5 depth)
//   Center: Deep water (darker color, 2.0 depth)
//   Creates natural-looking depth variation
```

**Water Type Definitions (waterbodies.xml):**

The depth difference is defined in the XML water definitions:

```xml
<!-- DEEP WATER (center) -->
<ocean name="ZP Dead Sea" 
       depth="2.0000"                           <!-- Deep water: 2.0 meters -->
       bottom="california\groundshore1_cal"
       bank="AfricaDesert\ground_dirt1_afriDesert"
       color="9 110 88" 
       deepcolor="0 0 0">                       <!-- Darker color -->
    <textureplacement>
        <texture distance="7">DeadSea\ground_dirt5_DeadSea</texture>
        <texture distance="20">DeadSea\ground_dirt5_DeadSea</texture>
    </textureplacement>
    <rendering 
        water_color="0.200 0.438 0.502"         <!-- Darker blue-green -->
        fog_density="0.5140"
        caustics_depth="1.1000">                <!-- Deep caustics -->
    </rendering>
</ocean>

<!-- SHALLOW WATER (outer ring) -->
<ocean name="ZP Dead Sea Shallow" 
       depth="0.5000"                           <!-- Shallow water: 0.5 meters -->
       bottom="DeadSea\ground_dirt1_DeadSea"    <!-- Visible bottom -->
       bank="AfricaDesert\ground_dirt1_afriDesert"
       color="9 110 88" 
       deepcolor="0 0 0">
    <textureplacement>
        <texture distance="6">DeadSea\ground_dirt2_DeadSea</texture>
        <texture distance="9">DeadSea\ground_dirt3_DeadSea</texture>
        <texture distance="12">DeadSea\ground_dirt4_DeadSea</texture>
        <texture distance="15">DeadSea\ground_dirt5_DeadSea</texture>
    </textureplacement>
    <rendering 
        water_color="0.200 0.438 0.502"         <!-- Same color base -->
        fog_density="0.5140"
        caustics_depth="1.1000">                <!-- Shallower caustics -->
    </rendering>
</ocean>
```

**Key XML attributes for depth:**

```xml
depth="2.0000"              <!-- Water depth in meters -->
bottom="terrain_path"       <!-- Visible in shallow water -->
caustics_depth="1.1000"     <!-- Light penetration depth -->
fog_density="0.5140"        <!-- Underwater visibility -->
```

**How layering creates depth:**

```
Top View:                    Side View:
                            
    ┌─────────────┐              Shore ─┐
    │  Shallow    │                     │ Shallow (0.5m)
    │             │              ───────┤
    │  ┌─────┐    │                     │ Deep (2.0m)
    │  │Deep │    │              ───────┘
    │  └─────┘    │              
    └─────────────┘              
    Same location,
    different sizes
```

**Key characteristics:**

- ✅ **Same location:** Both centered at (0.5, 0.5)
- ✅ **Different sizes:** Shallow (0.23) > Deep (0.08)
- ✅ **Different water types:** Each with unique depth setting
- ✅ **Same base height:** Both at 0.0 elevation
- ✅ **Build order:** Shallow first, then deep overlays it
- ✅ **Separate classes:** Deep water can have additional constraints

**Common depth values:**

```cpp
// Very shallow (beach, reef)
depth="0.2"     // Can see bottom clearly

// Shallow (lake edge)
depth="0.5"     // Lighter color, visible bottom

// Medium depth
depth="1.0"     // Transition zone

// Deep (lake center, ocean)
depth="2.0"     // Darker color, deep caustics

// Very deep (ocean trenches)
depth="5.0"     // Very dark, mysterious
```

**Creating depth constraints:**

```cpp
// Define classes for different depths
int classDeepWater = rmDefineClass("deep lake");

// Build deep water area and add to class
rmBuildArea(deadSeaLakeDeepID);
rmAddAreaToClass(deadSeaLakeDeepID, classDeepWater);

// Create constraint to avoid deep water
int avoidDeepWater = rmCreateClassDistanceConstraint("stuff avoids deep water", classDeepWater, 30.0);

// Use constraint for objects that shouldn't be in deep water
rmAddObjectDefConstraint(fishingBoatID, avoidDeepWater);  // Boats stay in shallow areas
```

**When to use layered water areas:**

✅ **Natural lakes** - Shallow edges, deep centers  
✅ **Coral reefs** - Shallow reefs, deep channels  
✅ **River deltas** - Shallow distributaries, deep main channel  
✅ **Coastal waters** - Shallow coast, deep ocean  
✅ **Strategic depth zones** - Control where naval units/fish spawn  

**Tips for layered water:**

✅ **Build shallow first** - Then overlay deep water on top  
✅ **Size ratio 3:1** - Shallow area should be ~3x larger than deep  
✅ **Higher coherence for deep** - Makes deep water more circular/natural  
✅ **Use depth classes** - Control object placement by depth  
✅ **Match water families** - Use related water types (Dead Sea + Dead Sea Shallow)  
✅ **Test visibility** - Ensure depth difference is noticeable  

**Advantages:**
- 🎯 Realistic visual depth
- 🎯 Gameplay depth zones
- 🎯 Natural color gradients
- 🎯 Control over resource placement

**Disadvantages:**
- ⚠️ Requires custom water types in XML
- ⚠️ More complex than single water areas
- ⚠️ Must coordinate sizes/locations carefully
- ⚠️ Depth differences may not be obvious to players

**Pattern variations:**

```cpp
// Three-layer depth (shallow → medium → deep)
int shallowLakeID = rmCreateArea("shallow");
rmSetAreaWaterType(shallowLakeID, "water_shallow");
rmSetAreaSize(shallowLakeID, 0.30, 0.30);
rmBuildArea(shallowLakeID);

int mediumLakeID = rmCreateArea("medium");
rmSetAreaWaterType(mediumLakeID, "water_medium");
rmSetAreaSize(mediumLakeID, 0.18, 0.18);
rmBuildArea(mediumLakeID);

int deepLakeID = rmCreateArea("deep");
rmSetAreaWaterType(deepLakeID, "water_deep");
rmSetAreaSize(deepLakeID, 0.08, 0.08);
rmBuildArea(deepLakeID);
// Result: Gradual depth transition from edge to center
```

**Advanced Application: Underwater Caves (Iceland Map)**

The layered water technique can also create **underwater cave effects** using multiple layers of transparent water. The Iceland map demonstrates this advanced pattern:

**How it works:**

Instead of varying water depth, Iceland uses **three layers of progressively transparent water types** all centered at the same location but with different sizes:

1. **Outer layer (largest):** Uses "Iceland Transparent 3" water type with higher fog density (0.75) - least transparent, more reflective
2. **Middle layer:** Uses "Iceland Transparent 2" with medium fog density (0.55) - semi-transparent
3. **Inner layer (smallest):** Uses "Iceland Transparent" with low fog density (0.40) - most transparent, brightest

**The visual effect:**

- The center appears **clearest** - you can see the underwater terrain/decorative props (underwater volcano grouping)
- It gradually becomes **more opaque** toward the edges, creating depth perception
- Combined with an "underwater_volcano" grouping placed at the cave location, this creates the illusion of looking down into an underwater volcanic crater
- High-tier nuggets (treasure boats) are placed around the cave as diving treasures

**Key XML differences:**

Each water type uses different rendering parameters:
- **fog_density:** Controls water transparency (0.4 = clear, 0.75 = murky)
- **water_brighten:** How bright the water appears (1.8 = bright center, 1.5 = darker edges)
- **reflection_normal & reflection_intensity:** Reflection strength (low at center for clarity, higher at edges)

**Why this is advanced:**

- ⚠️ Requires **three custom water types** in waterbodies.xml with carefully tuned transparency values
- ⚠️ Must precisely **balance all three sizes** to create smooth gradient (5800 → 4300 → 3200 tiles)
- ⚠️ Transparency values must be **calibrated** to allow underwater prop visibility
- ⚠️ Works best with **decorative groupings** placed at the same location to enhance the illusion
- ⚠️ Needs **special underwater terrain** visible through transparent water

**When to use:**

✅ **Underwater volcanic craters** - Underwater volcanic features  
✅ **Coral reefs** - Visible reef structures beneath surface  
✅ **Shipwrecks** - Sunken vessels visible from above  
✅ **Underwater ruins** - Ancient structures beneath water  
✅ **Deep ocean vents** - Geothermal features  

This technique is essentially the opposite of depth layering - instead of darker = deeper, you use **clearer = center** to draw the player's eye into the underwater feature.

---

#### **14.3.4 Advanced: Invisible Water Areas (Inverted Logic)**

For complex water bodies like seas, straits, and archipelagos, use **invisible water areas** - an advanced technique that reverses the normal approach. Instead of placing water ON land, you initialize the map AS water, then build land AROUND invisible area masks.

**How It Works:**

Traditional lakes: `Land base → Add water areas → Water appears`  
Invisible water: `Water base → Add empty masks → Build land around masks → Water remains in gaps`

The "areas" don't create water - they mark where water should STAY when land is built.

**Example from Black Sea Map - Complete Pattern:**

This creates the Black Sea, Bosporus Strait, and Mediterranean connection using inverted logic.

**Step 1: Initialize Map as Water**

```cpp
// Set entire map to water base
rmTerrainInitialize("black_sea_type");
rmSetSeaType("black sea");
```

**Step 2: Define Water Class**

```cpp
// Create class for water zones
int classGreatLake = rmDefineClass("classGreatLake");
```

**Step 3: Create Avoidance Constraint**

```cpp
// Constraint to keep land away from water zones
int greatLakesConstraint = rmCreateClassDistanceConstraint("avoid the great lakes", classGreatLake, 1.0);

// Optional: Far constraint for mountains
int farGreatLakesConstraint = rmCreateClassDistanceConstraint("far from lakes", classGreatLake, 20.0);
```

**Step 4: Place Invisible Water Masks**

These areas have **NO water type, NO terrain, NO elevation** - they're just invisible boundaries.

```cpp
// ============ BLACK SEA (center) ============
int lakeArea = rmCreateArea("lakeArea");

if (PlayerNum > 6) {
    rmSetAreaSize(lakeArea, 0.20, 0.20);
    rmSetAreaLocation(lakeArea, 0.48, 0.5);    
} else {
    rmSetAreaSize(lakeArea, 0.22, 0.22);
    rmSetAreaLocation(lakeArea, 0.5, 0.5); 
}

rmSetAreaCoherence(lakeArea, 0.6);
rmSetAreaMinBlobs(lakeArea, 8);
rmSetAreaMaxBlobs(lakeArea, 12);
rmSetAreaMinBlobDistance(lakeArea, 8.0);
rmSetAreaMaxBlobDistance(lakeArea, 12.0);
rmSetAreaElevationVariation(lakeArea, 0.0);           // ⚠️ FLAT - no terrain change

rmAddAreaToClass(lakeArea, classGreatLake);           // ⚠️ KEY: Mark as water zone
if (rmGetIsKOTH())
    rmSetAreaReveal(lakeArea, 1);                     // Reveal in KOTH mode

rmBuildArea(lakeArea);
// NOTE: No rmSetAreaWaterType() or rmSetAreaMix() - completely invisible!


// ============ BOSPORUS STRAIT (west connection) ============
int bosporArea = rmCreateArea("bosporArea");

if (PlayerNum == 2)
    rmSetAreaSize(bosporArea, rmAreaTilesToFraction(4000), rmAreaTilesToFraction(4000));
else if (PlayerNum == 3 || PlayerNum == 4)
    rmSetAreaSize(bosporArea, rmAreaTilesToFraction(5000), rmAreaTilesToFraction(5000));
else
    rmSetAreaSize(bosporArea, rmAreaTilesToFraction(6000), rmAreaTilesToFraction(6000));

rmSetAreaLocation(bosporArea, 0.1, 0.5);
rmSetAreaCoherence(bosporArea, 1.0);
rmSetAreaElevationVariation(bosporArea, 0.0);
rmAddAreaToClass(bosporArea, classGreatLake);         // Mark as water zone
rmSetAreaObeyWorldCircleConstraint(bosporArea, false);
rmAddAreaInfluenceSegment(bosporArea, 0.0, 0.5, 0.25, 0.5);  // Strait shape

if (rmGetIsKOTH())
    rmSetAreaReveal(bosporArea, 1);

rmBuildArea(bosporArea);


// ============ MEDITERRANEAN SEA (far west) ============
int mediterraneanArea = rmCreateArea("mediterraneanArea");

rmSetAreaSize(mediterraneanArea, 0.04, 0.04);
rmSetAreaLocation(mediterraneanArea, 0.0, 0.5);
rmSetAreaCoherence(mediterraneanArea, 1.0);
rmSetAreaElevationVariation(mediterraneanArea, 0.0);
rmAddAreaToClass(mediterraneanArea, classGreatLake);
rmSetAreaObeyWorldCircleConstraint(mediterraneanArea, false);

if (rmGetIsKOTH())
    rmSetAreaReveal(mediterraneanArea, 1);

// Mediterranean shape with influence segments
rmAddAreaInfluenceSegment(mediterraneanArea, 0.0, 0.5, 0.05, 0.7);
rmAddAreaInfluenceSegment(mediterraneanArea, 0.05, 0.7, 0.05, 0.3);
rmAddAreaInfluenceSegment(mediterraneanArea, 0.05, 0.3, 0.0, 0.5);

rmBuildArea(mediterraneanArea);
```

**Step 5: Build Land Around the Masks**

Now create the continent - it will avoid `classGreatLake`, leaving water in those zones.

```cpp
// Build main continent (avoids invisible water masks)
int northContinentID = rmCreateArea("north_continent");

rmSetAreaSize(northContinentID, 0.65, 0.65);
rmSetAreaCoherence(northContinentID, 0.65);
rmSetAreaMix(northContinentID, paintMix);

// Shoreline terrain layers
rmAddAreaTerrainLayer(northContinentID, "carolinas\ground_shoreline2_car", 0, 1);
rmAddAreaTerrainLayer(northContinentID, "carolinas\ground_shoreline3_car", 1, 2);

rmSetAreaBaseHeight(northContinentID, 4);         // Elevated above sea level
rmSetAreaHeightBlend(northContinentID, 2);
rmSetAreaSmoothDistance(northContinentID, 50);
rmSetAreaObeyWorldCircleConstraint(northContinentID, false);

// ⚠️ KEY CONSTRAINT: Avoid the invisible water masks
rmAddAreaConstraint(northContinentID, greatLakesConstraint);
rmAddAreaConstraint(northContinentID, avoidTradeRouteFar4);
rmAddAreaConstraint(northContinentID, avoidSocket);
rmAddAreaConstraint(northContinentID, avoidCity);

rmSetAreaLocation(northContinentID, 0.9, 0.5);    // East side
rmBuildArea(northContinentID);

// RESULT: Continent builds around the masks → Water shows through gaps
//         = Black Sea (center) + Bosporus (strait) + Mediterranean (west)
```

**Optional Enhancement: Layered Mountains on Continent**

Add elevated terrain on top of the continent using the far constraint:

```cpp
// Create mountain range on continent (away from coastline)
int terrainElevatedID = rmCreateArea("terrain_elevated");

rmSetAreaSize(terrainElevatedID, 0.45, 0.45);
rmSetAreaCoherence(terrainElevatedID, 0.35);
rmSetAreaBaseHeight(terrainElevatedID, 4.8);          // Higher than continent base (4.0)

// Keep mountains away from water edges
rmAddAreaConstraint(terrainElevatedID, farGreatLakesConstraint);  // 20.0 from water
rmAddAreaConstraint(terrainElevatedID, avoidTradeRouteFar4);
rmAddAreaConstraint(terrainElevatedID, avoidCityLong);

// Elevation settings
rmSetAreaElevationType(terrainElevatedID, cElevTurbulence);
rmSetAreaElevationVariation(terrainElevatedID, 6.0);
rmSetAreaElevationPersistence(terrainElevatedID, 0.2);
rmSetAreaElevationNoiseBias(terrainElevatedID, 1);
rmSetAreaObeyWorldCircleConstraint(terrainElevatedID, false);

// Position and shape
rmSetAreaLocation(terrainElevatedID, 0.95, 0.5);
rmAddAreaInfluencePoint(terrainElevatedID, 0.3, 0.90);
rmAddAreaInfluencePoint(terrainElevatedID, 0.3, 0.10);

rmBuildArea(terrainElevatedID);

// RESULT: Three-layer map
//   Layer 1: Water base (Black Sea, straits)
//   Layer 2: Continent (height 4.0)
//   Layer 3: Mountains (height 4.8+)
```

**Why This Technique Exists:**

The invisible water areas pattern solves problems that simple lakes cannot:

1. **Complex water shapes:**
   - Straits connecting multiple seas
   - Archipelagos with irregular coastlines
   - Realistic geography with multiple water bodies

2. **Natural coastlines:**
   - Continent shapes define water boundaries
   - Influence segments create detailed shorelines
   - No need to manually draw water shapes

3. **Multi-layered terrain:**
   - Water base (elevation 0.0)
   - Continent (elevation 4.0)
   - Mountains (elevation 4.8+)
   - All layers interact naturally

4. **Performance:**
   - One water base instead of many water areas
   - Simpler constraint logic
   - Better for large water bodies

**Comparison: Simple Lakes vs Invisible Water Areas**

| Aspect | Simple Lakes | Invisible Water Areas |
|--------|--------------|----------------------|
| **Base terrain** | Land | Water |
| **Water creation** | `rmSetAreaWaterType()` | Water base (no command needed) |
| **Areas define** | Where water IS | Where water ISN'T |
| **Best for** | Small ponds, single lakes | Seas, straits, archipelagos |
| **Complexity** | Simple | Advanced |
| **Layering** | Limited | Full multi-layer support |
| **Coastlines** | Defined by lake edges | Defined by continent edges |

**Key characteristics of invisible masks:**

- ❌ **NO `rmSetAreaWaterType()`** - They don't create water
- ❌ **NO `rmSetAreaMix()`** - They don't change terrain
- ✅ **YES `rmSetAreaElevationVariation(0.0)`** - Must be flat
- ✅ **YES `rmAddAreaToClass()`** - Must be in water class
- ✅ **YES `rmBuildArea()`** - Must be built before land

**Critical pattern order:**

```
1. Initialize map as water
2. Define water class + constraints
3. Build invisible mask areas (add to class)
4. Build land areas (avoid class)
5. Water remains in gaps
```

**When to use invisible water areas:**

✅ **Multiple connected water bodies** - Seas linked by straits  
✅ **Complex archipelagos** - Many islands with irregular water  
✅ **Historical maps** - Real geography (Black Sea, Mediterranean)  
✅ **Large water features** - When water is 30%+ of map  
✅ **Multi-layer terrain** - Continent + mountains + water  

**When to use simple lakes instead:**

✅ **Small water features** - Single lake, small pond  
✅ **Land-dominant maps** - Water is minor feature  
✅ **Simple shapes** - Circular/oval lakes  
✅ **Beginner-friendly** - Easier to understand  

**Common mistakes:**

❌ **Adding terrain to masks** - Defeats the purpose (makes them visible)  
❌ **Wrong build order** - Land built before masks won't work  
❌ **Forgetting constraints** - Land will overlap water zones  
❌ **Using on land base** - Must initialize as water first  
❌ **Non-zero elevation** - Masks must be flat (0.0 variation)  

**Tips for invisible water areas:**

✅ **Plan water zones first** - Sketch map before coding  
✅ **Use influence segments** - Create realistic strait shapes  
✅ **Test with KOTH reveal** - Visualize invisible zones  
✅ **Layer constraints** - Near water (1.0), far water (20.0+)  
✅ **Scale with players** - Adjust water size for game size  
✅ **Add shoreline terrain layers** - Smooth land/water transitions  

**Visual representation:**

```
STEP 1-3: Setup
┌─────────────────────┐
│ Water Water Water   │  ← Entire map is water
│ Water Water Water   │  ← Invisible masks placed
│ Water Water Water   │  ← (not visible yet)
└─────────────────────┘

STEP 4-5: Build Land
┌─────────────────────┐
│ ████████░░░░████████ │  ← Land avoids masks
│ ████████░░░░████████ │  ← Water shows through
│ ████████░░░░████████ │  ░ = Water zones
└─────────────────────┘  █ = Continent
```

---

## **15.** 🚂 Trade Routes

Trade routes are visual paths across the map where caravans, ships, or trains travel. They allow players to build Trading Posts at trade sockets along the route to generate resources. Trade routes are defined in two places:
- **Route types:** `traderoutedefs.xml` - Defines visual appearance and units
- **Map placement:** Random map script - Defines waypoints and socket locations

**Trade route types are defined in:** `data/traderoutedefs.xml`

---

### **Understanding Trade Route Positioning**

**Why trade routes never align exactly with waypoint coordinates:**

Trade routes in the `traderoutedefs.xml` file define a `blocksize` attribute (typically `16.0` meters). This is the **snap grid** size that the game uses to place trade route segments. When you place waypoints at exact decimal coordinates like `(0.5, 0.5)`, the game **snaps** these positions to the nearest multiple of the blocksize.

**Example:**
```xml
<route blocksize="16.0" nautical="false">dirt</route>
```

If you place a waypoint at `rmAddTradeRouteWaypoint(tradeRouteID, 0.325, 0.678)`:
- The game converts fractional coordinates to meters
- Rounds to nearest 16-meter grid position
- Trade route visually appears slightly offset from your exact coordinate

**Why this matters:**
- ❌ Sockets placed at exact waypoint coordinates may not align with visual route
- ❌ Calculating socket offsets requires accounting for snap drift
- ❌ Trade route lengths may differ slightly from calculated distances
- ✅ Using `rmGetTradeRouteWayPoint()` returns the **actual snapped position**
- ✅ Always extract coordinates from built routes for accurate placement

**Best practice:**
```cpp
// Build route FIRST
rmBuildTradeRoute(tradeRouteID, "stone");

// THEN extract actual positions
vector actualPos = rmGetTradeRouteWayPoint(tradeRouteID, 0.5);
rmPlaceObjectDefAtPoint(socketID, 0, actualPos);  // Now aligned!
```

---

### **15.1. Land Trade Routes**

Land trade routes use terrain textures (dirt, stone, snow, train tracks) and spawn land-based trade units like stagecoaches, trains, or travois.

**Common land route types:**
- `"dirt"` - Basic dirt road (basic)
- `"stone"` - Paved stone road (upgrade 1)
- `"train"` - Railroad tracks with train (upgrade 2)
- `"snow"` - Snow-covered path (basic)

**Example from Versailles Map - Simple Horizontal Route:**

```cpp
// Create socket definition
int socketID = rmCreateObjectDef("TR Socket");
rmAddObjectDefItem(socketID, "SocketTradeRoute", 1, 0.0);
rmSetObjectDefAllowOverlap(socketID, true);
rmSetObjectDefMinDistance(socketID, 2.0);
rmSetObjectDefMaxDistance(socketID, 8.0);

// Create trade route
int tradeRouteID = rmCreateTradeRoute();
rmSetObjectDefTradeRouteID(stopperID, tradeRouteID);
rmSetObjectDefTradeRouteID(socketID, tradeRouteID);

// Define waypoints (straight horizontal line)
rmAddTradeRouteWaypoint(tradeRouteID, 0.0, 0.55);   // West edge
rmAddTradeRouteWaypoint(tradeRouteID, 0.5, 0.55);   // Center
rmAddTradeRouteWaypoint(tradeRouteID, 1.0, 0.55);   // East edge

// Build the route
rmBuildTradeRoute(tradeRouteID, "dirt");

// Place stopper at center (prevents visual glitches)
vector socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.5);
rmPlaceObjectDefAtPoint(stopperID, 0, socketLoc1);
```

**Key points for land routes:**
- ✅ **Stopper objects** - Prevent trade route building issues
- ✅ **Socket definitions** - Linked to route via `rmSetObjectDefTradeRouteID()`
- ✅ **Waypoint progression** - Must form connected path
- ✅ **Build before placement** - Route must exist before placing sockets

---

### **15.2. Water (river) Trade Routes**

Water trade routes use nautical routes for ships. They require **special timing** - often placed **before islands** to ensure proper land/water generation.

**Common water route types:**

**Sea Trade routes:**
- `"water_trail"` - Basic water route (trading ship, basic)
- `"water2_trail"` - Advanced (galleon, upgrade 1)
- `"water3_trail"` - Premium (fluyt, upgrade 2)
- `"asian_water_trail"` - Asian ship variants (basic)

**River Trade routes:**
- `"river_trail"` - river trade route (basic)
- `"river2_trail"` - river trade route (upgrade 1)
- `"river3_trail"` - river trade route (upgrade 2)
- `"australia_river_trail"` - river trade route (upgrade 2)
- `"native_water_trail"` - American water trade route (basic)
- `"native_water2_trail"` - American water trade route (upgrade 1)
- `"native_water3_trail"` - American water trade route (upgrade 2)

**Special types:**
- `"lava_flow"` - used only as volcano lava trail!

**Why water routes are placed first:**

Water trade routes on maps with dynamic island placement must be built **before continents/islands** to:
1. **Reserve water space** - Prevents islands from spawning on trade route path
2. **Enable constraints** - `rmCreateTradeRouteDistanceConstraint()` only works on existing routes
3. **Coordinate extraction** - Need route positions to offset harbors/islands properly

**Example from Black Sea Map - Player Count Variations:**

The Black Sea map adjusts trade route shape based on player count to maintain balance between water area and island spacing.

```cpp
// Create trade route
int tradeRouteID = rmCreateTradeRoute();
rmSetObjectDefTradeRouteID(stopperID, tradeRouteID);

// VARIATION 1: 2-player layout (smaller diamond)
if (cNumberNonGaiaPlayers == 2) {
    if (blockadeSpawn == 0)
        rmAddTradeRouteWaypoint(tradeRouteID, 0.0, 0.5);   // Optional edge start
    rmAddTradeRouteWaypoint(tradeRouteID, 0.32, 0.5);  // West point
    rmAddTradeRouteWaypoint(tradeRouteID, 0.5, 0.71);  // North point
    rmAddTradeRouteWaypoint(tradeRouteID, 0.7, 0.5);   // East point
    rmAddTradeRouteWaypoint(tradeRouteID, 0.5, 0.32);  // South point
    rmAddTradeRouteWaypoint(tradeRouteID, 0.32, 0.5);  // Back to west
    if (blockadeSpawn == 0)
        rmAddTradeRouteWaypoint(tradeRouteID, 0.0, 0.5);   // Optional edge end
}
// VARIATION 2: 3+ player layout (larger diamond)
else {
    if (blockadeSpawn == 0)
        rmAddTradeRouteWaypoint(tradeRouteID, 0.0, 0.5);
    rmAddTradeRouteWaypoint(tradeRouteID, 0.29, 0.5);  // Larger radius
    rmAddTradeRouteWaypoint(tradeRouteID, 0.5, 0.7);
    rmAddTradeRouteWaypoint(tradeRouteID, 0.7, 0.5);
    rmAddTradeRouteWaypoint(tradeRouteID, 0.49, 0.29);
    rmAddTradeRouteWaypoint(tradeRouteID, 0.29, 0.5);
    if (blockadeSpawn == 0)
        rmAddTradeRouteWaypoint(tradeRouteID, 0.0, 0.5);
}

// Build water route
rmBuildTradeRoute(tradeRouteID, "water_trail");
```

**Why player count variations:**
Because the trade route needs to have a diamond-like shape. Uneven placement of the trade route means, that the waypoints get often displaced. That's why trade route needs exceptions based on amount of players.


**Key differences from land routes:**
- ⚠️ **Timing critical** - Must build before `rmCreateArea()` for islands
- ⚠️ **Blockade variations** - Some gameplay modes skip edge waypoints
- ⚠️ **Stopper placement** - Required to prevent island spawn failures
- ⚠️ **Constraint dependency** - Islands use `rmCreateTradeRouteDistanceConstraint()` on this route

**Common water route mistakes:**
- ❌ Building route after islands - Islands overlap trade path
- ❌ Wrong route type - Using land route on water map

---

### **15.3 Layered Trade Routes (Advanced)**

**What are layered trade routes?**

Multiple trade routes built at the same path position, with different route types stacked on top of each other. Only one layer is visible at a time, controlled by triggers.

**Primary use case:** Armored Train mechanics - allow switching between regular trade route and armored train routes through gameplay triggers.

**Example:** Labrador Coast map

**How it works:**

1. **Bottom layer** - Regular trade route (e.g., "snow") with train stations
2. **Top layers** - Armored train routes (invisible at start)
3. **Trigger activation** - When players research armored train technology, original route deactivates and armored train routes activate
4. **Bidirectional travel** - Two armored train routes (opposite directions) for gameplay variety

**Code example from Labrador Coast:**

```cpp
// Layer 1: Regular trade route (visible at start)
int tradeRouteID = rmCreateTradeRoute();
rmSetObjectDefTradeRouteID(stopperID, tradeRouteID);      // Link stoppers
rmSetObjectDefTradeRouteID(stopperID2, tradeRouteID);     // for train stations
// ... (link all stoppers)
rmAddTradeRouteWaypoint(tradeRouteID, 0.3, 0.01);         // South to north
rmAddTradeRouteWaypoint(tradeRouteID, 0.3, 0.5);
rmAddTradeRouteWaypoint(tradeRouteID, 0.3, 0.99);
rmBuildTradeRoute(tradeRouteID, "snow");                  // Regular route type

// Place train stations on regular route (see section 4.4.5)
// ... station placement code ...

// Layer 2: Armored Train Route 1 (north to south - invisible at start)
int tradeRouteID2 = rmCreateTradeRoute();
rmAddTradeRouteWaypoint(tradeRouteID2, 0.3, 0.01);
rmAddTradeRouteWaypoint(tradeRouteID2, 0.3, 0.5);
rmAddTradeRouteWaypoint(tradeRouteID2, 0.3, 0.99);
rmBuildTradeRoute(tradeRouteID2, "armored_train");        // Armored train type

// Layer 3: Armored Train Route 2 (south to north - invisible at start)
int tradeRouteID3 = rmCreateTradeRoute();
rmAddTradeRouteWaypoint(tradeRouteID3, 0.3, 0.99);        // Reversed waypoints
rmAddTradeRouteWaypoint(tradeRouteID3, 0.3, 0.5);
rmAddTradeRouteWaypoint(tradeRouteID3, 0.3, 0.01);
rmBuildTradeRoute(tradeRouteID3, "armored_train");        // Armored train type
```

**Trigger setup (hiding armored train routes at start):**

```cpp
// Initialize trigger - hide armored train routes at game start
rmCreateTrigger("AT_Initialize");
rmAddTriggerEffect("Trade Route Toggle State");
rmSetTriggerEffectParamInt("TradeRoute", 2);              // Hide route 2
rmSetTriggerEffectParam("ShowUnit", "false");
rmAddTriggerEffect("Trade Route Toggle State");
rmSetTriggerEffectParamInt("TradeRoute", 3);              // Hide route 3
rmSetTriggerEffectParam("ShowUnit", "false");
```

**Key concepts:**

1. **Same waypoints** - All layers use identical waypoint positions (0.3, 0.01/0.5/0.99)
2. **Different route types** - Layer 1 uses "snow", layers 2-3 use "armored_train"
3. **Opposite directions** - Armored train routes go both directions for gameplay
4. **Train stations required** - Regular route needs train stations (see section 4.4.5)
5. **Trigger control** - Routes switched via "Trade Route Set Level" and "Trade Route Toggle State"

**Why use layered routes:**

- ✅ **Dynamic gameplay** - Switch between route types mid-game
- ✅ **Armored trains** - Special units that travel on dedicated routes
- ✅ **Technology gating** - Players must research to unlock armored trains
- ✅ **Bidirectional** - Two armored train routes allow movement in both directions
- ✅ **Same infrastructure** - Train stations work for both regular and armored trains

**Requirements:**

- ⚠️ Train stations must be placed on the regular (visible) route - see **section 4.4.5**
- ⚠️ Armored train routes must be invisible at start (ShowUnit = false)
- ⚠️ Trigger system must handle route activation based on technology
- ⚠️ All route layers must use identical waypoint positions
- ⚠️ Armored train spawn mechanics handled separately via triggers

**When to use:**

- Maps with armored train gameplay mechanics
- Technology-gated trade route upgrades
- Dynamic route type switching
- Advanced trigger-based map design

**Status:** Very advanced topic requiring understanding of triggers, trade routes, and train stations. Reference Labrador Coast map for complete implementation.

---

### **15.4 Trade Sockets**

Sockets are where players build Trading Posts. There are multiple placement strategies depending on map type and desired reliability.

---

#### **15.4.1 Simple Socket Placement**

**Best for:** Land trade routes and simple water maps where terrain is relatively predictable.

This is the basic pattern - sockets placed directly on trade route waypoints without terrain modification.

**Example from King of Bohemia Map (Land Route):**

```cpp
// Socket definition
int socketID = rmCreateObjectDef("sockets to dock Trade Posts Land");
rmSetObjectDefTradeRouteID(socketID, tradeRouteID);
rmAddObjectDefItem(socketID, "SocketTradeRoute", 1, 0.0);
rmSetObjectDefAllowOverlap(socketID, true);
rmSetObjectDefMinDistance(socketID, 2.0);    // Start search 2m from waypoint
rmSetObjectDefMaxDistance(socketID, 8.0);    // Search up to 8m for valid land

// Socket placement - extract waypoint positions and place
vector socketLoc2 = rmGetTradeRouteWayPoint(tradeRouteID, 0.12);  // 12% along route
rmPlaceObjectDefAtPoint(socketID, 0, socketLoc2);

socketLoc2 = rmGetTradeRouteWayPoint(tradeRouteID, 0.31);  // 31% along route
rmPlaceObjectDefAtPoint(socketID, 0, socketLoc2);

socketLoc2 = rmGetTradeRouteWayPoint(tradeRouteID, 0.50);  // Center (50%)
rmPlaceObjectDefAtPoint(socketID, 0, socketLoc2);

socketLoc2 = rmGetTradeRouteWayPoint(tradeRouteID, 0.69);  // 69% along route
rmPlaceObjectDefAtPoint(socketID, 0, socketLoc2);

socketLoc2 = rmGetTradeRouteWayPoint(tradeRouteID, 0.88);  // 88% along route
rmPlaceObjectDefAtPoint(socketID, 0, socketLoc2);
```

**Advantages of this approach:**

- ✅ **Simplicity** - Native code support, no advanced techniques needed
- ✅ **Dynamic placement** - Sockets can be adjusted based on player count
- ✅ **Per-player sockets** - Every player can have their own socket if necessary
- ✅ **Randomization support** - Allows advanced randomization of socket positions
- ✅ **Ideal for land routes** - Reliable placement on stable terrain

**Example: Dynamic socket count based on player count (King of Bohemia):**

```cpp
int numPlayers = cNumberNonGaiaPlayers;
int numSockets = 8;  // Default for most team sizes

if (numPlayers == 5)
    numSockets = 5;
else if (numPlayers == 6 || numPlayers == 3)
    numSockets = 6;
else if (numPlayers == 7)
    numSockets = 7;

// Then place 'numSockets' sockets evenly along the route
```

**How it works:**
- `rmGetTradeRouteWayPoint(tradeRouteID, fraction)` extracts the actual position of a waypoint
- `fraction` ranges from 0.0 (start) to 1.0 (end) along the route
- `rmPlaceObjectDefAtPoint(socketID, player, vectorPosition)` places socket at extracted position
- Game searches from that position within MinDistance to MaxDistance for valid placement

---

**Usage for Water Trade Routes:**

Simple placement is **possible but not always recommended** for water routes. Use it only when:
- You need randomized socket positions
- You need per-player socket allocation
- Map has simple, predictable island layout (like Philippines)

**Example from Philippines Map (Water Route):**

```cpp
// Socket definition for water trade route
int socketID = rmCreateObjectDef("sockets to dock Trade Posts");
rmSetObjectDefTradeRouteID(socketID, tradeRouteID);
rmAddObjectDefItem(socketID, "SocketTradeRoute", 1, 0.0);
rmSetObjectDefAllowOverlap(socketID, true);
rmSetObjectDefMinDistance(socketID, 5.0);
rmSetObjectDefMaxDistance(socketID, 30.0);   // MUCH LARGER - search up to 30m for land!

// Socket placement
vector socketLoc = rmGetTradeRouteWayPoint(tradeRouteID, 0.30);
rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

socketLoc = rmGetTradeRouteWayPoint(tradeRouteID, 0.80);
rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
```

**Key difference: MaxDistance values**

| Route Type | MaxDistance | Why? |
|------------|-------------|------|
| **Land routes** | `8.0` | Waypoints on stable land, small search needed |
| **Simple water maps** | `30.0` | Waypoints may be in water, need to reach nearby islands |
| **Complex water maps** | `40.0+` or platforms | Waypoints far from islands in symmetric layouts |

**Why water routes need larger MaxDistance:**
1. **Waypoint location** - May be 20-30m from nearest island shore
2. **Island timing** - Islands built after route, distance varies
3. **Search requirement** - Game must search outward to find valid land

**When simple placement works on water routes:**
- ✅ Simple island layouts (Philippines, basic maps)
- ✅ FFA/uneven teams (islands more distributed)
- ✅ Maps with predictable island positions

**When to use platforms instead (Section 1.3.2):**
- ⚠️ Symmetric 2v2 layouts (islands concentrated on sides)
- ⚠️ Complex water maps (Balearic Islands 2v2)
- ⚠️ When MaxDistance 40m+ still fails


---

#### **15.4.2 Water Sockets on Platforms (Reliable solution for complex)**

**Best for:** Symmetric 2v2 water maps where islands are far from trade route waypoints. Creates guaranteed land beneath sockets using vector math and area creation.

**Why platforms are needed:**

In symmetric team layouts (like Balearic Islands 2v2), islands are concentrated at team spawn locations on opposite sides of the map. The trade route runs through the center, meaning waypoints can be **50+ meters from the nearest island**. Simple placement fails because even with `MaxDistance = 40.0`, the game cannot find land.

**Solution:** Create artificial land platforms offset toward islands using vector math.

---

**Example from Balearic Islands Map (2v2 Symmetric Layout):**

This pattern uses a loop to create platforms and place sockets at multiple waypoint positions.

```cpp
// Loop through all socket positions
int numSockets = 8;
for (i = 0; < numSockets) {
    // Determine which waypoint to use for this socket
    float waypointPos = 0.0;
    if (i == 0) waypointPos = 0.10;
    else if (i == 1) waypointPos = 0.23;
    else if (i == 2) waypointPos = 0.37;
    else if (i == 3) waypointPos = 0.52;
    else if (i == 4) waypointPos = 0.63;
    else if (i == 5) waypointPos = 0.77;
    else if (i == 6) waypointPos = 0.88;
    else if (i == 7) waypointPos = 0.95;
    
    // STEP 1: Get exact waypoint position from trade route
    vector socketLoc = rmGetTradeRouteWayPoint(tradeRouteID, waypointPos);
    float socketX = xsVectorGetX(socketLoc);  // Extract X coordinate
    float socketZ = xsVectorGetZ(socketLoc);  // Extract Z coordinate
    
    // STEP 2: Calculate direction from waypoint toward map center (0.5, 0.5)
    float centerX = rmXFractionToMeters(0.5);
    float centerZ = rmZFractionToMeters(0.5);
    float dirX = centerX - socketX;  // X component of direction
    float dirZ = centerZ - socketZ;  // Z component of direction
    
    // STEP 3: Normalize the direction vector (make length = 1.0)
    float distance = sqrt(dirX*dirX + dirZ*dirZ);  // Pythagorean theorem
    float normalizedDirX = dirX / distance;
    float normalizedDirZ = dirZ / distance;
    
    // STEP 4: Offset 35 meters toward center (toward nearest island)
    float offsetDistance = 35.0;  // Distance to move inland
    float offsetX = normalizedDirX * offsetDistance;
    float offsetZ = normalizedDirZ * offsetDistance;
    float platformX = socketX + offsetX;  // New platform position
    float platformZ = socketZ + offsetZ;
    
    // STEP 5: Create land platform area at offset position
    int socketPlatformID = rmCreateArea("socket platform "+i);
    rmSetAreaSize(socketPlatformID, rmAreaTilesToFraction(400.0), rmAreaTilesToFraction(400.0));
    rmSetAreaLocation(socketPlatformID, rmXMetersToFraction(platformX), rmZMetersToFraction(platformZ));
    rmSetAreaMix(socketPlatformID, baseMix);  // Use same terrain as islands
    rmSetAreaCoherence(socketPlatformID, 1.0);  // Solid, not blobby
    rmSetAreaSmoothDistance(socketPlatformID, 15);  // Smooth edges
    rmSetAreaBaseHeight(socketPlatformID, 2.2);  // Above water level
    rmSetAreaWarnFailure(socketPlatformID, false);  // Don't spam warnings
    rmBuildArea(socketPlatformID);
    
    // STEP 6: Place socket on the platform
    int socketID = rmCreateObjectDef("socket "+i);
    rmAddObjectDefItem(socketID, "SocketTradeRoute", 1, 0.0);
    rmAddObjectDefConstraint(socketID, avoidWater4);  // Ensure on land
    rmSetObjectDefTradeRouteID(socketID, tradeRouteID);  // Link to route
    rmPlaceObjectDefAtLoc(socketID, 0, rmXMetersToFraction(platformX), rmZMetersToFraction(platformZ));
}
```

---

**How it works - Step by step:**

**Problem:** Trade route waypoint is in open water, 50+ meters from island  
**Solution:** Calculate direction toward nearest land and create platform 35m in that direction

**Visual representation:**

```
Map layout (2v2 symmetric):
┌─────────────────────────────────┐
│  Team 1 Island         Team 2   │
│       🏝️                 🏝️      │
│                                 │
│         ⚪──────⚪──────⚪        │  ← Trade route (water)
│          ↓35m   ↓35m   ↓35m     │
│         ⬛🏛️    ⬛🏛️    ⬛🏛️      │  ← Platforms + sockets
│                                 │
│       🏝️                 🏝️      │
│  Team 1 Island         Team 2   │
└─────────────────────────────────┘

⚪ = Trade route waypoint (in water)
⬛ = Created platform (land area)
🏛️ = Socket placed on platform
```

**Vector math explanation:**

1. **Direction vector:** Points from waypoint to center (where islands are)
2. **Normalize:** Make vector length = 1.0 (preserves direction, standardizes distance)
3. **Scale:** Multiply by 35m to get exact offset distance
4. **Result:** Platform positioned 35m toward nearest island

---

**Key parameters:**

| Parameter | Value | Purpose |
|-----------|-------|---------|
| **offsetDistance** | `35.0` meters | Distance to move inland from waypoint |
| **Platform size** | `400` tiles | Area size (≈20x20 meters) |
| **Platform height** | `2.2` | Above sea level (buildable land) |
| **Coherence** | `1.0` | Solid platform, not scattered |
| **Smooth distance** | `15` | Blend edges with surrounding terrain |

**Why 35 meters?**
- Too small (< 30m): May still spawn in water
- Too large (> 45m): Platform may collide with island or other objects
- 35m: Sweet spot for most symmetric layouts

---

**When to use platforms:**

✅ **Symmetric 2v2 layouts** - Islands concentrated on sides, waypoints in center  
✅ **Complex water maps** - When simple placement fails even with 40m MaxDistance  
✅ **Guaranteed reliability** - Must ensure 100% socket placement success  
✅ **Long-distance waypoints** - When waypoints > 40m from any island  

**When simple placement is enough:**

⚠️ **Simple water maps** (Philippines) - Islands near waypoints, 30m MaxDistance works  
⚠️ **FFA/uneven teams** - Islands distributed, 40m MaxDistance sufficient  

---

**Advantages:**

- ✅ **100% reliability** - Platforms guarantee land beneath sockets
- ✅ **Works on any map size** - Vector math scales automatically
- ✅ **Symmetric placement** - Consistent offset for all sockets
- ✅ **No placement failures** - Platform always succeeds

**Disadvantages:**

- ⚠️ **Complex code** - Requires vector math and normalization
- ⚠️ **Artificial appearance** - Small platforms may look unnatural
- ⚠️ **More areas to build** - One platform per socket (8 sockets = 8 extra areas)
- ⚠️ **Collision risk** - Platform may overlap with islands if offset too large

---

**Alternative: Harbour Groupings (Pattern 3)**

For 4-player maps, Balearic Islands uses **harbour groupings** instead of bare sockets. This combines platforms with pre-built dock structures for visual polish. See section 1.3.3 for harbour implementation.

For complete code including harbour groupings, see **Pattern 2 & Pattern 3** in uncategorized content section.

---

#### **15.4.3 Socket Placement Methods Comparison**

There are three main methods for placing trade route sockets, each with different use cases and complexity levels.

---

**Method 1: Dynamic Waypoint Extraction (Flexible)**

**How it works:** Extract exact waypoint position from trade route, then place socket at that position.

**Example from King of Bohemia (Section 1.3.1):**

```cpp
// Extract waypoint position as vector
vector socketLoc = rmGetTradeRouteWayPoint(tradeRouteID, 0.30);  // 30% along route

// Place socket at extracted position
rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
```

**Advantages:**
- ✅ **Adaptive** - Works with any trade route shape
- ✅ **Dynamic** - Can adjust socket count based on player count
- ✅ **Flexible** - Sockets follow route automatically
- ✅ **Scalable** - Works with loops and randomization

**Disadvantages:**
- ⚠️ **Requires waypoint extraction** - More complex than fixed coordinates
- ⚠️ **May need distance parameters** - MinDistance/MaxDistance for land search

**When to use:**
- Maps with variable player counts
- Dynamic trade route generation
- When socket count varies by game size

---

**Method 2: Fixed Coordinate Placement (Simple & Advanced)**

**How it works:** Place sockets or groupings at hardcoded map coordinates without extracting from trade route. Can be used for simple sockets or advanced harbour/station groupings.

**Key characteristic:** Uses fixed coordinates (X, Z) instead of extracting waypoint positions.

---

**Example A: Simple Socket Placement (Riverina Map)**

```cpp
// Define socket once
int socketID = rmCreateObjectDef("sockets to dock Trade Posts");
rmSetObjectDefTradeRouteID(socketID, tradeRouteID);
rmAddObjectDefItem(socketID, "SocketTradeRoute", 1, 0.0);
rmSetObjectDefAllowOverlap(socketID, true);
rmSetObjectDefMinDistance(socketID, 0.0);

// Player count-based MaxDistance
if (cNumberNonGaiaPlayers == 6)
    rmSetObjectDefMaxDistance(socketID, 9.0);
else if (cNumberNonGaiaPlayers == 7)
    rmSetObjectDefMaxDistance(socketID, 10.0);
else if (cNumberNonGaiaPlayers == 8)
    rmSetObjectDefMaxDistance(socketID, 13.0);
else
    rmSetObjectDefMaxDistance(socketID, 6.0);

// Place at fixed coordinates with offset calculations
rmPlaceObjectDefAtLoc(socketID, 0, 0.5 - rmXMetersToFraction(25), 0.55);
rmPlaceObjectDefAtLoc(socketID, 0, 0.4 + rmXMetersToFraction(45), 0.45);
rmPlaceObjectDefAtLoc(socketID, 0, 0.55 - rmXMetersToFraction(23), 0.25 - rmXMetersToFraction(23));

if (cNumberNonGaiaPlayers >= 7)
    rmPlaceObjectDefAtLoc(socketID, 0, 0.52 + rmXMetersToFraction(15), 0.28 + rmXMetersToFraction(15));
else
    rmPlaceObjectDefAtLoc(socketID, 0, 0.55 + rmXMetersToFraction(15), 0.25 + rmXMetersToFraction(15));
```

---

**Example B: Advanced Grouping Placement (Tortuga Map)**

Same coordinate-based approach, but places **harbour groupings** instead of bare sockets. Groupings include platforms, buildings, and decorative elements.

```cpp
// Create and place harbour groupings at fixed coordinates
// (includes socket + platform + buildings + props)
int portID01 = rmCreateGrouping("portG 01", "harbour_01");
rmPlaceGroupingAtLoc(portID01, 0, 0.45 + rmXTilesToFraction(16), 0.7 + rmZTilesToFraction(0));

int portID02 = rmCreateGrouping("portG 02", "harbour_02");
rmPlaceGroupingAtLoc(portID02, 0, 0.55 + rmXTilesToFraction(11), 0.5);

int portID03 = rmCreateGrouping("portG 03", "harbour_03");
rmPlaceGroupingAtLoc(portID03, 0, 0.5, 0.45 - rmZTilesToFraction(10));

int portID04 = rmCreateGrouping("portG 04", "harbour_04");
rmPlaceGroupingAtLoc(portID04, 0, 0.3 + rmZTilesToFraction(1), 0.55 - rmZTilesToFraction(9.5));
```

**Difference:** 
- **Riverina** uses `rmPlaceObjectDefAtLoc()` for bare sockets
- **Tortuga** uses `rmPlaceGroupingAtLoc()` for harbour groupings
- **Both** use fixed coordinates (X, Z) independent of trade route waypoints

*Note: Grouping content (XML structure, props, platforms) is covered in the Groupings chapter. This section focuses only on the placement method.*

---

**Key differences from Method 1:**
- Uses `rmPlaceObjectDefAtLoc(socketID, player, X, Z)` or `rmPlaceGroupingAtLoc()` with **hardcoded coordinates**
- Does NOT extract waypoint positions with `rmGetTradeRouteWayPoint()`
- Coordinates calculated using `rmXMetersToFraction()` / `rmZMetersToFraction()` offsets
- Socket/grouping placement independent of trade route waypoint positions

**Advantages:**
- ✅ **Simple code** - No waypoint extraction needed
- ✅ **Precise control** - Exact coordinate placement
- ✅ **Fixed layouts** - Sockets/groupings always in same positions
- ✅ **No vector math** - Direct coordinate specification
- ✅ **Visual options** - Can use bare sockets OR groupings

**Disadvantages:**
- ❌ **Not adaptive** - Doesn't follow trade route changes
- ❌ **Hardcoded positions** - Must manually calculate for each socket
- ❌ **Breaks with route changes** - If trade route moves, sockets don't follow
- ❌ **Requires XML groupings** (if using advanced groupings like Tortuga)

**When to use:**
- Fixed-layout maps (scenario maps, historical recreations)
- Maps where trade route NEVER changes position
- Simple river trade routes with predictable paths
- Historical harbour/port city maps (Tortuga, Venice, Malta)
- When you want exact socket positions regardless of route
- Story-driven maps requiring specific visual layouts

---

**Comparison Summary:**

| Aspect | Method 1: Waypoint Extraction | Method 2: Fixed Coordinates |
|--------|-------------------------------|----------------------------|
| **Placement function** | `rmPlaceObjectDefAtPoint(ID, player, vector)` | `rmPlaceObjectDefAtLoc(ID, player, X, Z)` or `rmPlaceGroupingAtLoc()` |
| **Coordinates** | Extracted from route | Hardcoded |
| **Follows route changes** | Yes | No |
| **Complexity** | Medium | Low |
| **Flexibility** | High | Low |
| **Visual options** | Basic sockets only | Basic sockets OR groupings (harbours/stations) |
| **Best for** | Procedural/dynamic maps | Fixed layout/scenario maps |

**Decision tree:**

1. **Dynamic map with variable player counts?** → Use Method 1 (Waypoint extraction)
2. **Procedurally generated terrain/routes?** → Use Method 1 (Waypoint extraction)
3. **Fixed scenario map with unchanging route?** → Use Method 2 (Fixed coordinates)
4. **Need visual polish with harbours/stations?** → Use Method 2 with groupings (Tortuga example)

---

#### **15.4.4 Socket Types**

Trade route sockets come in different types depending on gameplay mechanics and visual requirements. Each type serves specific map design purposes.

---

##### **15.4.4.1 Simple Sockets (Standard)**

The most common type - bare `SocketTradeRoute` objects placed on trade routes. Used in most maps.

**Protounit:** Always uses `SocketTradeRoute` - the standard socket type.

**Examples:**
- **Riverina** - River trade route with fixed coordinates
- **Philippines** - Water trade route with waypoint extraction
- **King of Bohemia** - Land trade route with dynamic player count

**Characteristics:**
- ✅ Simple implementation - just socket object placement
- ✅ Works for all route types (land, water, river, train)
- ✅ Minimal code required
- ✅ Standard Trading Post build mechanic
- ✅ Players can build immediately (no capture required)

**Code example (covered in sections 1.3.1 and 1.3.2):**
```cpp
int socketID = rmCreateObjectDef("socket");
rmAddObjectDefItem(socketID, "SocketTradeRoute", 1, 0.0);  // Standard socket protounit
rmSetObjectDefTradeRouteID(socketID, tradeRouteID);
rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
```

---

##### **15.4.4.2 Capturable Sockets (Gameplay Mechanic)**

Special socket types that must be captured before players can build Trading Posts. Uses capturable protounit variants with the `<unittype>CapturableTradingPost</unittype>` tag.

**Protounits:** Various capturable socket types defined in proto/protomods:

| Protounit Name | Use Case |
|----------------|----------|
| `zpTradingPostCaptureNavalLone` | Naval routes, standalone |
| `zpTradingPostCaptureNaval` | Naval routes, grouped |
| `zpTradingPostCaptureNavalOriental` | Middle Eastern-themed naval routes |
| `deTradingPostCaptureEuropean` | European-themed land routes |
| *(more available)* | Check proto files for complete list |

**Example:** Black Sea map

**How it works:**
1. Place **capturable socket** (not standard `SocketTradeRoute`)
2. Place **treasure nugget** near the socket
3. Players capture nugget → gain control of socket → can build Trading Post
4. No triggers required (handled by capturable protounit)

**Code example from Black Sea:**

```cpp
// Define capturable socket (NOT SocketTradeRoute!)
int harbourID1 = rmCreateObjectDef("sockets to dock Trade Posts1");
rmSetObjectDefTradeRouteID(harbourID1, tradeRouteID); // Capturable socket always needs to be assigned to a trade route, otherwise does not work!
rmAddObjectDefItem(harbourID1, "zpTradingPostCaptureNavalLone", 1, 0.0);  // Capturable type
rmSetObjectDefMinDistance(harbourID1, 0.0);
rmSetObjectDefMaxDistance(harbourID1, 0.5);

// Define nugget (placed near socket)
int nuggetID1 = rmCreateObjectDef("nuggets to dock Trade Posts1");
rmSetObjectDefTradeRouteID(nuggetID1, tradeRouteID);
rmAddObjectDefItem(nuggetID1, "Nugget", 1, 0.0);
rmSetObjectDefMinDistance(nuggetID1, 4.0);   // 4-6m away from waypoint
rmSetObjectDefMaxDistance(nuggetID1, 6.0);

// Set nugget difficulty - Important for trade route nuggets!
rmSetNuggetDifficulty(511, 511);  // Links to trade route nugget definitions

// Place both at same waypoint
vector socketLoc = rmGetTradeRouteWayPoint(tradeRouteID, 0.33);
rmPlaceObjectDefAtPoint(harbourID1, 0, socketLoc);  // Socket at waypoint
rmPlaceObjectDefAtPoint(nuggetID1, 0, socketLoc);   // Nugget nearby (4-6m offset)
```

**Key differences from simple sockets:**
- Uses `zpTradingPostCaptureNaval*` or `deTradingPostCaptureEuropean` instead of `SocketTradeRoute`
- Capturable sockets have `<unittype>CapturableTradingPost</unittype>` in proto definition
- Nugget placed 4-6m away from socket (not at exact same position)
- No custom triggers needed - capture mechanic built into protounit
- Socket appears as capturable objective to players

**When to use:**
- Maps with contested objectives
- Adds strategic layer to trade route control
- Naval maps where sockets should be fought over
- Thematic maps (pirate harbors, contested ports)

**Important notes:**
- ⚠️ **`rmSetNuggetDifficulty(511, 511)` is important** - This links to trade route nugget definitions in `nuggets.xml` and `nuggetmods.xml`
- ⚠️ Trade route nuggets are specially defined in nugget files - look for definitions containing the word "trade"
- ⚠️ Capturable socket protounits must be defined in proto/protomods with `<unittype>CapturableTradingPost</unittype>` tag
- ⚠️ Nugget distance (4-6m) prevents overlap but keeps them visually connected
- ⚠️ Check proto files for available capturable socket variants before using
- ⚠️ May require additional triggers for advanced capture mechanics (see Black Sea map)

**Nugget difficulty explained:**
- The value `511` references specific trade route nugget definitions in `data/nuggets.xml` and `data/nuggetmods.xml`
- Trade route nuggets have special properties (lower resources, themed units, capture mechanics)
- Without `rmSetNuggetDifficulty()`, nuggets will use default difficulty instead of trade route variants
- Trade route nugget names typically contain "trade" (e.g., "Trade Route Nugget", "Trade Socket Nugget")

---

##### **15.4.4.3 Harbour Groupings (Visual Polish)**

Pre-built harbour structures that include socket, platform, dock buildings, and decorative props. Used for maximum visual quality.

**Examples:**
- **Balearic Islands (2v2)** - Directional harbours facing water
- **Malta** - Historical port city theme
- **Kurils** - Island chain harbours
- **Melanesia** - Coastal trading posts

**Two Harbour Grouping Variants:**

There are two main harbour grouping families, each with directional variants:

1. **`Harbour_Universal_`** - For maps with multiple trade routes or complex layouts
2. **`Harbour_Center_`** - For maps with a **single central trade route only**

**Key difference:**
- `Harbour_Universal_` can be used with any number of trade routes
- `Harbour_Center_` should only be used when there is exactly **one trade route** on the map
- Both support 8 directional variants (N, NE, E, SE, S, SW, W, NW)
- Some specialized variants: `Harbour_Center_River_` (for river routes), `harbour_centerb_` (variant B)

---

**Naming Convention - `Harbour_Universal_` Prefix:**

The `Harbour_Universal_` family uses **8 cardinal/ordinal directions** to orient docks toward water:

| Grouping Name | Direction | When to Use |
|---------------|-----------|-------------|
| `Harbour_Universal_N` | North | Dock faces north (water to north) |
| `Harbour_Universal_NE` | Northeast | Dock faces northeast diagonal |
| `Harbour_Universal_E` | East | Dock faces east (water to east) |
| `Harbour_Universal_SE` | Southeast | Dock faces southeast diagonal |
| `Harbour_Universal_S` | South | Dock faces south (water to south) |
| `Harbour_Universal_SW` | Southwest | Dock faces southwest diagonal |
| `Harbour_Universal_W` | West | Dock faces west (water to west) |
| `Harbour_Universal_NW` | Northwest | Dock faces northwest diagonal |

---

**Naming Convention - `Harbour_Center_` Prefix:**

The `Harbour_Center_` family is similar but designed specifically for single-route maps:

| Grouping Name | Direction | When to Use |
|---------------|-----------|-------------|
| `Harbour_Center_N` | North | Single route map, dock faces north |
| `Harbour_Center_NE` | Northeast | Single route map, dock faces northeast |
| `Harbour_Center_E` | East | Single route map, dock faces east |
| `Harbour_Center_SE` | Southeast | Single route map, dock faces southeast |
| `Harbour_Center_S` | South | Single route map, dock faces south |
| `Harbour_Center_SW` | Southwest | Single route map, dock faces southwest |
| `Harbour_Center_W` | West | Single route map, dock faces west |
| `Harbour_Center_NW` | Northwest | Single route map, dock faces northwest |
| `Harbour_Center_River_NE` | Northeast | River route variant |
| `Harbour_Center_River_SW` | Southwest | River route variant |
| `harbour_center_sw` | Southwest | Lowercase variant (Caribbean Wars) |
| `harbour_centerb_se` | Southeast | Variant B (Caribbean Wars) |
| `harbour_centerb_ne` | Northeast | Variant B (Caribbean Wars) |

**Examples of maps using `Harbour_Center_`:**
- **Mediterranean** - Single circular water route with NE/NW harbours
- **Polynesia** - Single central route with 4 cardinal harbours
- **Malta Castles** - Single route with conditional harbour placement
- **Tasmania** - Single route with SW/SE/S harbours
- **Mississippi** - River route with NE/SW river harbours
- **Caribbean Wars** - Single route with variant A/B harbours

**Note:** Not all directional variants exist for `Harbour_Center_` yet, but they can be created by adding new grouping XML files if needed.

---

**How to choose direction:**

Determine which direction the water is FROM the harbour location:

```
Example: Harbour at (0.8, 0.8), Water at (0.5, 0.5)
- Water is southwest of harbour → Use Harbour_Universal_SW

Example: Harbour at (0.2, 0.5), Water at (0.8, 0.5)  
- Water is east of harbour → Use Harbour_Universal_E
```

**Code example from Balearic Islands (2v2 - automatic direction detection):**

```cpp
// Calculate direction from harbor to map center (where water is)
float dirToSocketX = socketX - centerX;  // Direction FROM center TO socket
float dirToSocketZ = socketZ - centerZ;

// Determine grouping based on quadrant
if ((dirToSocketX > 0) && (dirToSocketZ > 0)) {
    harbourGroupingID = rmCreateGrouping("harbour", "Harbour_Universal_N");
}
else if ((dirToSocketX < 0) && (dirToSocketZ > 0)) {
    harbourGroupingID = rmCreateGrouping("harbour", "Harbour_Universal_W");
}
else if ((dirToSocketX > 0) && (dirToSocketZ < 0)) {
    harbourGroupingID = rmCreateGrouping("harbour", "Harbour_Universal_E");
}
else if ((dirToSocketX < 0) && (dirToSocketZ < 0)) {
    harbourGroupingID = rmCreateGrouping("harbour", "Harbour_Universal_S");
}

rmPlaceGroupingAtLoc(harbourGroupingID, 0, harbourX, harbourZ);
```

**Code example from Malta (manual direction specification):**

```cpp
// Port 1 - Northeast facing (water to northeast)
int portID01 = rmCreateGrouping("portG 01", "harbour_Universal_NE");
rmPlaceGroupingAtLoc(portID01, 0, 0.8 - rmXTilesToFraction(10), 0.23);

// Port 3 - Northwest facing (water to northwest)
int portID03 = rmCreateGrouping("portG 03", "harbour_Universal_NW");
rmPlaceGroupingAtLoc(portID03, 0, 0.23, 0.8 - rmZTilesToFraction(10));

// Port 5 - Southwest facing (water to southwest)
int portID05 = rmCreateGrouping("portG 05", "harbour_Universal_SW");
rmPlaceGroupingAtLoc(portID05, 0, 0.5 + rmXTilesToFraction(12), 0.9);
```

**Advantages:**
- ✅ Maximum visual quality - looks like real harbour
- ✅ Directionally correct - docks face water
- ✅ Includes platform automatically
- ✅ Thematically consistent

**Disadvantages:**
- ❌ Requires XML grouping files
- ❌ Fixed coordinates only (not dynamic)
- ❌ Large footprint
- ❌ Must choose correct direction

*Note: Harbour grouping XML structure is covered in the Groupings chapter.*

---

##### **15.4.4.4 Invisible Sockets (Advanced Positioning)**

Invisible protounit placed on trade route waypoints to serve as positioning anchors for platforms and harbour groupings. These are **not actual trade sockets** - they're invisible stoppers/markers.

**Invisible protounits:**
- `zpSPCWaterSpawnPoint` - Invisible water spawn point (most common for trade routes)
- `zpTrainStopper` - Invisible train route marker
- Other invisible objects with `NonSolid` and `DoNotShowOnMiniMap` flags

**Common naming:** Often named `socketID` or `stopperID` in code (naming convention varies)

**How it works:** The invisible marker is placed on the trade route, then its position is extracted and used by platforms and harbour groupings for precise offset placement.

**Example from Australia Map:**

```cpp
// Step 1: Define invisible socket/stopper (NOT a visible trading post socket!)
int socketID = rmCreateObjectDef("sockets to dock Trade Posts");
rmSetObjectDefTradeRouteID(socketID, tradeRouteID);
rmAddObjectDefItem(socketID, "zpSPCWaterSpawnPoint", 1, 0.0);  // Invisible marker
rmSetObjectDefAllowOverlap(socketID, true);
rmSetObjectDefMinDistance(socketID, 0.0);
rmSetObjectDefMaxDistance(socketID, 0.0);

// Step 2: Extract waypoint position
vector socketLoc = rmGetTradeRouteWayPoint(tradeRoute3ID, 0.22);

// Step 3: Place invisible marker at waypoint
rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

// Step 4: Create and build platform offset from invisible marker position
int portSite1 = rmCreateArea("port_site1");
rmSetAreaSize(portSite1, rmAreaTilesToFraction(400.0), rmAreaTilesToFraction(400.0));
rmSetAreaMix(portSite1, "california_snowground2");
rmSetAreaCoherence(portSite1, 1);
rmSetAreaSmoothDistance(portSite1, 15);
rmSetAreaBaseHeight(portSite1, 2.2);
rmSetAreaLocation(portSite1, 
    rmXMetersToFraction(xsVectorGetX(socketLoc) - 38),  // Offset -38m X
    rmZMetersToFraction(xsVectorGetZ(socketLoc)));       // Same Z
rmBuildArea(portSite1);

// Step 5: Create harbour grouping (contains actual socket in XML)
int stationGrouping01 = rmCreateGrouping("station grouping 01", "Harbour_Universal_NE");
rmSetGroupingMinDistance(stationGrouping01, 0.0);
rmSetGroupingMaxDistance(stationGrouping01, 0.0);

// Step 6: Place harbour grouping offset from invisible marker position
rmPlaceGroupingAtLoc(stationGrouping01, 0, 
    rmXMetersToFraction(xsVectorGetX(socketLoc) - 20),  // Offset -20m X
    rmZMetersToFraction(xsVectorGetZ(socketLoc)));       // Same Z
```

**The invisible marker workflow:**

1. **Define invisible stopper** - Uses `zpSPCWaterSpawnPoint` linked to trade route
2. **Extract waypoint** - `rmGetTradeRouteWayPoint()` gets position along route
3. **Place invisible marker** - Placed at waypoint, serves as anchor point
4. **Build platform** - Positioned offset from marker (e.g., -38m X, same Z)
5. **Place harbour grouping** - Positioned offset from marker (e.g., -20m X, same Z)
6. **Result** - Harbour grouping XML contains actual `SocketTradeRoute`, marker is invisible

**Why use invisible stoppers:**

- ✅ **Single anchor point** - All offsets calculated from one waypoint position
- ✅ **Clean visuals** - No visible socket object; only harbour structure appears
- ✅ **Flexible positioning** - Platform and harbour can have different offsets
- ✅ **Harbour contains socket** - Functional socket embedded in harbour grouping XML
- ✅ **Precise placement** - Vector position used for exact coordinate calculations

**Key differences from visible sockets:**

| Aspect | Visible Socket | Invisible Marker |
|--------|----------------|------------------|
| **Protounit** | `SocketTradeRoute` | `zpSPCWaterSpawnPoint` |
| **Visible in game** | Yes (white post) | No (invisible) |
| **Trading function** | Built-in | Provided by harbour grouping |
| **Purpose** | Direct trading | Position anchor |
| **Typical use** | Standard maps | Complex harbour layouts |

**When to use invisible stoppers:**

- Maps with harbour groupings that need precise platform placement (Australia)
- When socket should be hidden inside harbour structure
- Multiple offsets calculated from single waypoint anchor
- Complex harbour layouts with platforms

**Important notes:**

- ⚠️ Invisible markers do **NOT** provide trading functionality
- ⚠️ The harbour grouping XML must contain actual `SocketTradeRoute` for trading
- ⚠️ This is an advanced technique - 4.4.1 (Simple Sockets) is simpler for most maps
- ⚠️ The `socketLoc` vector is the key - it holds the waypoint position used for all offsets

---

##### **15.4.4.5 Train Stations (Advanced)**

Pre-built train station groupings for armored train trade routes. Uses TWO groupings placed at same location: one for skeleton/platform (contains socket), one for the station building itself.

**Railway station grouping naming convention:**

`Railway_Station_Big_[Direction]_[Type]`

**Direction suffix (only 4 variants needed):**
- `N` - North (also works as South from opposite side)
- `E` - East (also works as West from opposite side)
- `SE` - South-East (also works as North-West from opposite side)
- `SW` - South-West (also works as North-East from opposite side)

**Why only 4 directions?**

Train stations overflow on BOTH SIDES of the trade route, creating bilateral symmetry. The same grouping works from either viewing direction.

**Critical constraint:** The trade route line must always pass through a dedicated space within the station. You **cannot** place a station over/across the trade route - the route must flow through the station structure.

*Note: Unlike harbour groupings (which face water), direction indicates where station building faces along the trade route.*

**Type suffix:**

| Suffix | Description | Contains Socket | Purpose |
|--------|-------------|----------------|----------|
| `_nostation` | Skeleton/platform only | ✅ Yes | Infrastructure layer with functional socket |
| `_stationA` | Station building variant A | ❌ No | Visual building for Trade Route 1 |
| `_stationB` | Station building variant B | ❌ No | Visual building for Trade Route 2 |

**A/B variant rule:**
- **Trade Route 1** → Use `stationA` variant
- **Trade Route 2** → Use `stationB` variant
- Both variants are visually identical but assigned to different routes

**Available grouping examples (4 directions only):**
```
Railway_Station_Big_N_nostation   (skeleton)
Railway_Station_Big_N_stationA    (building variant A)
Railway_Station_Big_N_stationB    (building variant B)

Railway_Station_Big_E_nostation   (skeleton)
Railway_Station_Big_E_stationA    (building variant A)
Railway_Station_Big_E_stationB    (building variant B)

Railway_Station_Big_SE_nostation  (skeleton)
Railway_Station_Big_SE_stationA   (building variant A)
Railway_Station_Big_SE_stationB   (building variant B)

Railway_Station_Big_SW_nostation  (skeleton)
Railway_Station_Big_SW_stationA   (building variant A)
Railway_Station_Big_SW_stationB   (building variant B)
```

**Examples of maps using train stations:**
- **Mississippi** - Clean river route with multiple stations
- **Blue Mountains** - All 4 cardinal directions used
- **Labrador Coast** - Player-based placement
- **Wild West** - Desert railroad theme
- **King of Bohemia** - Mixed land and train routes

**Characteristics:**
- Two-layer grouping system (skeleton + building)
- Skeleton contains functional `SocketTradeRoute`
- Direction must match between skeleton and building
- Rail infrastructure integrated with trade route
- Uses invisible stoppers for positioning

**Placement workflow (Mississippi pattern):**

1. Define invisible stopper using `zpSPCWaterSpawnPoint`
2. Link stopper to trade route
3. Define skeleton grouping (`_nostation`)
4. Define station building grouping (`_stationA` or `_stationB`)
5. Extract waypoint position from trade route
6. Place invisible stopper at waypoint
7. Extract stopper position
8. Place both groupings at stopper position

**Code example from Mississippi Map:**

```cpp
// Step 1: Define invisible stopper
int stopperID = rmCreateObjectDef("Armored Train Stopper");
rmAddObjectDefItem(stopperID, "zpSPCWaterSpawnPoint", 1, 0.0);  // Invisible marker
rmSetObjectDefAllowOverlap(stopperID, true);
rmSetObjectDefMinDistance(stopperID, 0.0);
rmSetObjectDefMaxDistance(stopperID, 0.0);
rmSetObjectDefTradeRouteID(stopperID, tradeRouteID);  // Link to trade route

// Step 2: Define skeleton grouping (contains socket)
int stationGrouping03 = rmCreateGrouping("station grouping 03", "Railway_Station_Big_N_nostation");
rmSetGroupingMinDistance(stationGrouping03, 0.0);
rmSetGroupingMaxDistance(stationGrouping03, 0.0);

// Step 3: Define station building grouping (variant A for Trade Route 1)
int stationGrouping005 = rmCreateGrouping("station 05", "Railway_Station_Big_N_stationA");
rmSetGroupingMinDistance(stationGrouping005, 0.0);
rmSetGroupingMaxDistance(stationGrouping005, 0.0);
// Direction must match: both use "N" (North)

// Step 4: Extract waypoint and place stopper
vector socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.5);
rmPlaceObjectDefAtPoint(stopperID, 0, socketLoc1);

// Step 5: Get actual stopper position
vector StopperLoc1 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID, 0));

// Step 6: Place both groupings at stopper location
rmPlaceGroupingAtLoc(stationGrouping03, 0, 
    rmXMetersToFraction(xsVectorGetX(StopperLoc1)), 
    rmZMetersToFraction(xsVectorGetZ(StopperLoc1)));
    
rmPlaceGroupingAtLoc(stationGrouping005, 0, 
    rmXMetersToFraction(xsVectorGetX(StopperLoc1)), 
    rmZMetersToFraction(xsVectorGetZ(StopperLoc1)));
```

**Key points:**

1. **Skeleton first, building second** - Both placed at identical coordinates
2. **Direction consistency** - `_nostation` and `_stationA/B` must use same direction suffix
3. **Variant selection** - Choose A or B based on trade route ID
4. **Socket location** - Functional socket embedded in skeleton (`_nostation`) grouping
5. **Invisible stopper** - Acts as positioning anchor, linked to trade route

**Other train station protounits (used in some maps):**
- `spSocketTrainStationA` - Train station socket variant A
- `spSocketTrainStationB` - Train station socket variant B  
- `zpTrainStationA` - Train station building object

**When to use:**
- Armored train trade routes
- Industrial/railroad-themed maps
- Maps with city infrastructure
- Post-industrial time period (1800s+)
- When maximum visual immersion needed

**Status:** Advanced topic requiring understanding of object placement, coordinate extraction, and grouping systems. Reference Civil War, King of Bohemia, or Labrador Coast maps for complete implementation.

---

**Comparison:**

| Type | Complexity | Visual Quality | Trading Function | Use Case |
|------|-----------|----------------|------------------|----------|
| **4.4.1: Simple sockets** | Low | Basic | Built-in | Most maps |
| **4.4.2: Capturable sockets** | High | Basic | Built-in (after capture) | Contested objectives |
| **4.4.3: Harbour groupings** | Medium | Maximum | Embedded in grouping | Water maps, historical ports |
| **4.4.4: Invisible sockets** | Very High | N/A (invisible) | Provided by groupings | Position anchors, advanced harbour layouts |
| **4.4.5: Train stations** | Very High | Maximum | Embedded in grouping | Railroad maps |

**Decision tree:**

1. **Standard gameplay?** → 4.4.1: Simple sockets (sections 4.1-4.2)
2. **Need contested trade route control?** → 4.4.2: Capturable sockets
3. **Water map with visual focus?** → 4.4.3: Harbour groupings (choose correct direction)
4. **Complex harbour layout with precise positioning?** → 4.4.4: Invisible sockets (advanced)
5. **Railroad map with theme?** → 4.4.5: Train stations (advanced)

---

### **Trade Route Best Practices**

**Route definition:**
- ✅ Define sockets before building route
- ✅ Link sockets to route via `rmSetObjectDefTradeRouteID()`
- ✅ Build route before placing sockets
- ✅ Extract actual positions with `rmGetTradeRouteWayPoint()`

**Water routes:**
- ⚠️ **Always build before islands**
- ⚠️ Place stopper objects
- ⚠️ Use platforms for sockets on naval maps
- ⚠️ Test with multiple player counts

**Socket placement:**
- 💡 Simple placement for land routes
- 💡 Platform offset for water routes
- 💡 Harbour groupings for themed maps
- 💡 Balance socket spacing (3-5 per route typical)

**Common mistakes:**
- ❌ Wrong blocksize interpretation
- ❌ Building islands before water route
- ❌ No stopper object on complex routes
- ❌ Socket constraints too restrictive
- ❌ Ignoring player count scaling

---

## **16.** 🤖 Rivers

Rivers are decorative water features that add visual variety and gameplay depth to maps. They use a dedicated river creation system separate from regular water areas.

### **16.1 River Basics**

**What are rivers?**

Rivers are procedurally generated water paths that flow through the terrain. Unlike area-based water (`rmSetAreaWaterType`), rivers use dedicated RM functions and custom water types defined in XML.

**Key characteristics:**
- Created using `rmRiverCreate()` and `rmRiverBuild()`
- Use waypoints like trade routes for pathfinding
- Support shallows (crossable areas) via `rmRiverAddShallow()`
- Have configurable width and bank noise
- Often paired with trade routes running alongside
- Must be built BEFORE islands on maps with water/island generation

**Common uses:**
- Visual centerpieces (Mississippi, Danube, Arno)
- Gameplay dividers (split map into sides)
- Shallow crossings for unit passage
- Trade route integration (river routes)
- Thematic map identity (Paris, Florence, Venice)

---

### **16.2 River Creation Workflow**

**Basic river creation pattern:**

```cpp
// 1. Create river with water type and dimensions
int riverID = rmRiverCreate(depth, "WaterTypeName", frequency, octaves, width, shallowWidth);

// 2. Add waypoints to define river path
rmRiverAddWaypoint(riverID, x, z);
rmRiverAddWaypoint(riverID, x, z);
// ... more waypoints

// 3. Optional: Configure bank noise
rmRiverSetBankNoiseParams(riverID, octaves, frequency, persistence, sineSize, sineFreq, curve);

// 4. Optional: Add shallow crossings
rmRiverSetShallowRadius(riverID, radius);
rmRiverAddShallow(riverID, fraction);  // 0.0-1.0 along river path

// 5. Build the river
rmRiverBuild(riverID);
```

**Example from Riverina Map:**

```cpp
// Downer River - main central river with shallows
int riverID2 = rmRiverCreate(-5, "ZP Riverina Waterfalls", 5, 2, 15, 15);
rmRiverAddWaypoint(riverID2, 0.5, 0.55);  // Start at center-upper
rmRiverAddWaypoint(riverID2, 0.5, 0.5);   // Flow through center
rmRiverAddWaypoint(riverID2, 0.4, 0.4);   // Curve left
rmRiverAddWaypoint(riverID2, 0.6, 0.2);   // Curve right
rmRiverAddWaypoint(riverID2, 0.4, 0.0);   // Exit at bottom-left

// Disable bank noise for clean edges
rmRiverSetBankNoiseParams(riverID2, 0.00, 0, 0.0, 0.0, 0.0, 0.0);

// Add shallow crossing near bottom (90% along river)
rmRiverSetShallowRadius(riverID2, 15);
rmRiverAddShallow(riverID2, 0.9);

rmRiverBuild(riverID2);
```

---

### **16.3 River Functions Reference**

**`rmRiverCreate(int depth, string waterType, int frequency, int octaves, int width, int shallowWidth)`**

Creates a river and returns its ID.

| Parameter | Type | Description | Typical Values |
|-----------|------|-------------|----------------|
| `depth` | int | River depth (negative = below terrain) | -1 to -5 |
| `waterType` | string | Water type name from XML | "ZP Mississippi River", "ZP Riverina Waterfalls" |
| `frequency` | int | Bank noise frequency | 4-5 (typical) |
| `octaves` | int | Bank noise octaves | 2-4 (typical) |
| `width` | int | River width in meters | 15-180 depending on map scale |
| `shallowWidth` | int | Width of shallow crossings | Same as width typically |

**Examples from maps:**
```cpp
// Narrow river (Riverina)
rmRiverCreate(-5, "ZP Riverina Waterfalls", 5, 2, 15, 15);

// Medium river (King of Bohemia)
rmRiverCreate(-1, "ZP Bohemian River", 4, 4, 89, 89);

// Wide river (Civil War)
rmRiverCreate(-1, "ZP Mississippi River", 4, 4, 150, 180);  // Scaled by player count
```

---

**`rmRiverAddWaypoint(int riverID, float x, float z)`**

Adds a waypoint to define river path. Works like trade route waypoints.

```cpp
rmRiverAddWaypoint(riverID, 0.5, 0.0);  // Start at south center
rmRiverAddWaypoint(riverID, 0.5, 1.0);  // Flow to north center
```

---

**`rmRiverSetBankNoiseParams(int riverID, float octaves, float frequency, float persistence, float sineSize, float sineFreq, float curve)`**

Controls how wavy/irregular the river banks are.

```cpp
// Smooth banks (no noise) - used in Florence
rmRiverSetBankNoiseParams(riverID, 0.00, 0, 0.0, 0.0, 0.0, 0.0);

// Natural banks (default) - omit this call for organic look
```

---

**`rmRiverSetShallowRadius(int riverID, float radius)` + `rmRiverAddShallow(int riverID, float fraction)`**

Creates crossable shallow areas.

```cpp
rmRiverSetShallowRadius(riverID, 10);      // Shallow area radius
rmRiverAddShallow(riverID, 0.15);          // Shallow at 15% along river
rmRiverAddShallow(riverID, 0.85);          // Shallow at 85% along river
```

**`fraction` parameter:** 0.0 = start, 1.0 = end of river path.

**Example from Florence:**
```cpp
rmRiverSetShallowRadius(riverID, 10);
rmRiverAddShallow(riverID, 0.15);  // Crossing near start
rmRiverAddShallow(riverID, 0.85);  // Crossing near end
```

---

**`rmRiverBuild(int riverID)`**

Builds the river. Must be called LAST after all configuration.

---

### **16.4 River + Trade Route Integration**

Rivers are often paired with trade routes running alongside or through them. The trade route provides trading functionality while the river provides visuals.

⚠️ **CRITICAL TECHNIQUE:** This is a very important pattern for creating clean river-route integration!

**The Problem:**

While **trade routes** get placed almost precisely based on given coordinates, **rivers do NOT place precisely**. Rivers are generated procedurally and don't follow exact waypoints. This means if you just place a river and trade route with similar waypoints, they won't align properly.

**The Solution - 3-Step Terrain Cleanup Method:**

```cpp
// STEP 1: Place a LARGE river first
int riverID2 = rmRiverCreate(-5, "ZP Riverina Waterfalls", 5, 2, 15, 15);
rmRiverAddWaypoint(riverID2, 0.5, 0.55);
rmRiverAddWaypoint(riverID2, 0.5, 0.5);
rmRiverAddWaypoint(riverID2, 0.4, 0.4);
rmRiverAddWaypoint(riverID2, 0.6, 0.2);
rmRiverAddWaypoint(riverID2, 0.4, 0.0);
rmRiverBuild(riverID2);

// STEP 2: Place trade route ON TOP of the river with similar waypoints
int tradeRouteID4 = rmCreateTradeRoute();
rmAddTradeRouteWaypoint(tradeRouteID4, 0.5, 0.6);
rmAddTradeRouteWaypoint(tradeRouteID4, 0.5, 0.5);
rmAddTradeRouteWaypoint(tradeRouteID4, 0.4, 0.39);
rmAddTradeRouteWaypoint(tradeRouteID4, 0.6, 0.19);
rmAddTradeRouteWaypoint(tradeRouteID4, 0.4, 0.0);
rmBuildTradeRoute(tradeRouteID4, "australia_river_trail");

// STEP 3: Place terrain (land areas) using trade route constraints
// This "cleans" the terrain over the river, making it smaller
int cleanupAreaID = rmCreateArea("river bank cleanup");
rmSetAreaSize(cleanupAreaID, 0.05, 0.05);
rmSetAreaMix(cleanupAreaID, "grass_mix");
rmAddAreaConstraint(cleanupAreaID, avoidTradeRouteShort);  // Key constraint!
rmSetAreaLocation(cleanupAreaID, 0.5, 0.5);
rmBuildArea(cleanupAreaID);

// 4. Place trade sockets (see Chapter 4)
```

**How it works:**

1. **Large river placed** - Creates a wide, imprecise water feature
2. **Trade route placed on top** - Placed precisely where you want it
3. **Terrain placed with `avoidTradeRoute` constraint** - This terrain "overwrites" parts of the river, shrinking it and aligning it with the trade route

**Result:**
- ✅ River appears smaller and cleaner
- ✅ Terrain perfectly overflows the trade route edges
- ✅ River visually follows the trade route path precisely
- ✅ Trade route gameplay works correctly

**Why this is necessary:**

Because rivers don't place precisely (unlike trade routes), you CANNOT simply place a narrow river and expect it to align with a trade route. The cleanup technique uses the trade route's precise placement as a "mask" to shape the terrain around it, creating the illusion of perfect alignment.

**Key points:**
- River waypoints and trade route waypoints should be SIMILAR but don't need exact match
- Start with OVERSIZED river, then trim it with terrain constraints
- Use `avoidTradeRoute` or similar constraints on cleanup terrain areas
- This is the standard technique for all river trade route maps
- Use river-appropriate route type: "australia_river_trail", "water_trail"

---

### **16.5 River Banks and Height Variation**

Rivers often need raised banks or elevated terrain for proper visual integration.

**Bank creation pattern from Riverina:**

```cpp
// Create raised bank area
int leftBankDowner = rmCreateArea("left bank downer");
rmSetAreaLocation(leftBankDowner, 0.60, 0.5);
rmSetAreaSize(leftBankDowner, 0.04, 0.04);
rmSetAreaCoherence(leftBankDowner, 0.95);
rmSetAreaSmoothDistance(leftBankDowner, 12);
rmSetAreaBaseHeight(leftBankDowner, 2.0);       // Raised height
rmSetAreaMix(leftBankDowner, paintMix1);
rmSetAreaHeightBlend(leftBankDowner, 8);        // Smooth transition
rmAddAreaToClass(leftBankDowner, classRiverBank);
rmSetAreaCliffPainting(leftBankDowner, true, false, true, 1.5, true);

// Use influence segments to shape bank alongside river
rmAddAreaInfluenceSegment(leftBankDowner, 0.6, 0.7, 0.6, 0.5);
rmBuildArea(leftBankDowner);
```

**Key techniques:**
- `rmSetAreaBaseHeight()` - Elevate banks above river level
- `rmSetAreaHeightBlend()` - Smooth transition from bank to flat terrain
- `rmSetAreaCliffPainting()` - Add cliff textures for steep banks
- `rmAddAreaInfluenceSegment()` - Shape bank along river path
- Class constraint (`classRiverBank`) - Prevent multiple banks from overlapping

---

### **16.6 Common River Patterns**

**Pattern 1: Straight Central Divider (King of Bohemia, Paris)**

```cpp
int riverID = rmRiverCreate(-1, "ZP Bohemian River", 4, 4, 89, 89);
rmRiverAddWaypoint(riverID, 0.5, 0.0);   // South center
rmRiverAddWaypoint(riverID, 0.5, 1.5);   // North center (extends beyond map)
rmRiverBuild(riverID);
```

**Use case:** Divides map into left/right team sides

---

**Pattern 2: Diagonal Cross (Venice City)**

```cpp
// Vertical river
int riverID = rmRiverCreate(-1, "ZP Venice Lagoon Shore", 4, 4, 72, 72);
rmRiverAddWaypoint(riverID, 0.5, 1.0);
rmRiverAddWaypoint(riverID, 0.5, 0.0);
rmRiverBuild(riverID);

// Horizontal river
int riverID2 = rmRiverCreate(-1, "ZP Venice Lagoon Shore", 4, 4, 68, 68);
rmRiverAddWaypoint(riverID2, 0.0, 0.5);
rmRiverAddWaypoint(riverID2, 1.0, 0.5);
rmRiverBuild(riverID2);
```

**Use case:** Creates canal system, divides map into quadrants

---

**Pattern 3: Curved Scenic River (Riverina, Crown Lands)**

```cpp
int riverID = rmRiverCreate(-1, "ZP Danube River", 4, 4, 14, 14);
rmRiverAddWaypoint(riverID, 0.0, 0.4);    // Enter from west
rmRiverAddWaypoint(riverID, 0.35, 0.6);   // Curve up
rmRiverAddWaypoint(riverID, 0.65, 0.4);   // Curve down
rmRiverAddWaypoint(riverID, 1.0, 0.6);    // Exit to east
rmRiverBuild(riverID);
```

**Use case:** Decorative feature with shallow crossings

---

### **16.7 River Water Types**

Rivers require custom water types defined in XML. Common examples from codebase:

| Water Type Name | Use Case |
|-----------------|----------|
| `"ZP Mississippi River"` | Wide river (Civil War, Mississippi) |
| `"ZP Riverina Waterfalls"` | River with waterfall areas |
| `"ZP Bohemian River"` | European-themed river |
| `"ZP Venice Lagoon Shore"` | Lagoon/canal water |
| `"ZP Paris River"` | Seine-style river |
| `"ZP Arno River Pond"` | Italian river |
| `"ZP Danube River"` | Central European river |

*Water types define visual appearance, depth rendering, and shallow behavior in XML.*

---

### **16.8 Critical Timing: Rivers Before Islands**

⚠️ **IMPORTANT:** Rivers must be built BEFORE creating island areas.

**Correct order:**
```cpp
// 1. Build river first
rmRiverBuild(riverID);

// 2. THEN create islands
rmCreateArea("island 1");
// ... island configuration
rmBuildArea(islandID);
```

**Why?** Island generation uses pathfinding to ensure connectivity. If river exists first, pathfinding accounts for it. If islands built first, river may cut through islands unpredictably.

**Example comment from King of Bohemia:**
```cpp
// River must be defined before the islands are placed
int riverID = rmRiverCreate(-1, "ZP Bohemian River", 4, 4, 89, 89);
rmRiverBuild(riverID);

// NOW place islands
```

---

### **16.9 River Best Practices**

**Design:**
- ✅ Use rivers as visual focal points and map dividers
- ✅ Add 1-3 shallow crossings for gameplay connectivity
- ✅ Match river width to map scale (larger maps = wider rivers)
- ✅ Curve rivers for natural appearance (avoid perfectly straight)
- ✅ Pair rivers with trade routes for trade route gameplay

**Technical:**
- ✅ Build rivers BEFORE islands
- ✅ Use bank areas for elevation changes
- ✅ Set bank noise to 0 for clean edges (cities) or default for natural look
- ✅ Scale river width by player count (see Civil War example)
- ✅ Use appropriate water type for theme

**Common mistakes:**
- ❌ Building islands before river → unpredictable river placement
- ❌ No shallows → map too divided, poor connectivity
- ❌ River too wide → dominates map, limits buildable area
- ❌ Wrong water type → visual inconsistency
- ❌ No bank elevation → river looks flat/unnatural

---

### **16.10 Advanced: Multiple Rivers and Waterfalls**

⚠️ **VERY ADVANCED:** This technique requires very precise positioning of lakes, rivers, and surrounding cliff banks. Small coordinate errors will break the waterfall effect.

Maps can have multiple rivers at different elevations to create waterfall cascade effects. This requires careful coordination of water areas, elevated banks, and decorative groupings.

---

**Complete Example from Riverina (3-tier waterfall system):**

**STEP 1: Create Middle Lake (elevation 0.0 - base level beneath the waterfall)**

```cpp
// Downer Lake - middle tier waterfall pool
int downerLakeID = rmCreateArea("Downer Lake");
rmSetAreaWaterType(downerLakeID, "ZP Riverina Waterfalls");
rmSetAreaSize(downerLakeID, 0.05, 0.05);
rmSetAreaCoherence(downerLakeID, 1.0);
rmSetAreaLocation(downerLakeID, 0.5, 0.60);              // Precise center-north position
rmSetAreaSmoothDistance(downerLakeID, 10);
rmAddAreaInfluenceSegment(downerLakeID, 0.4, 0.65, 0.6, 0.65);  // Horizontal shape
rmBuildArea(downerLakeID);
```

---

**STEP 2: Create Upper Lake (elevation 7.0 - top tier above the waterfall)**

```cpp
// Upper Lake - top tier waterfall source
int upperLakeID = rmCreateArea("Upper Lake");
rmSetAreaWaterType(upperLakeID, "ZP Riverina Waterfalls");

// Scale size by player count
if (cNumberNonGaiaPlayers == 6 || cNumberNonGaiaPlayers == 8)
    rmSetAreaSize(upperLakeID, 0.055, 0.055);
else
    rmSetAreaSize(upperLakeID, 0.05, 0.05);

rmSetAreaCoherence(upperLakeID, 1.0);
rmSetAreaBaseHeight(upperLakeID, 7.0);                   // Elevated 7 meters

// PRECISE positioning varies by player count for proper alignment
if (cNumberNonGaiaPlayers == 3 || cNumberNonGaiaPlayers == 5 || 
    cNumberNonGaiaPlayers == 7 || cNumberNonGaiaPlayers == 4)
    rmSetAreaLocation(upperLakeID, 0.5, 0.85);
else
    rmSetAreaLocation(upperLakeID, 0.5, 0.845);          // Slightly adjusted

rmAddAreaToClass(upperLakeID, classMountains);           // Mark as impassable
rmAddAreaInfluenceSegment(upperLakeID, 0.4, 0.8, 0.6, 0.8);  // Horizontal shape
rmSetAreaSmoothDistance(upperLakeID, 10);
rmBuildArea(upperLakeID);
```

-> These two lakes will conjoin which creates the waterfall effect. The overlap is the waterfall.

---

**STEP 3: Create Upper River (elevation 7.0 - connects to upper lake)**

```cpp
// Upper River - flows FROM upper lake down to edge of cliff
int upperRiverD = rmCreateArea("Upper River");
rmSetAreaWaterType(upperRiverD, "ZP Riverina Waterfalls");
rmSetAreaSize(upperRiverD, 0.06, 0.06);
rmSetAreaCoherence(upperRiverD, 1.0);
rmSetAreaBaseHeight(upperRiverD, 7.0);                   // Same elevation as upper lake
rmSetAreaLocation(upperRiverD, 0.5, 0.85);               // Starts at upper lake
rmSetAreaSmoothDistance(upperRiverD, 10);

// Two influence segments create V-shaped flow from upper lake to cliff edge
rmAddAreaInfluenceSegment(upperRiverD, 0.7, 1.0, 0.5, 0.85);    // Right flow
rmAddAreaInfluenceSegment(upperRiverD, 0.3, 1.0, 0.5, 0.85);    // Left flow
rmBuildArea(upperRiverD);
```

---

**STEP 4: Create Downer Lake Banks (elevation 2.0 - around middle lake)**

```cpp
// Left bank of downer lake
int leftBankDowner = rmCreateArea("left bank downer");
rmSetAreaLocation(leftBankDowner, 0.6, 0.6);             // East side of lake

if (cNumberNonGaiaPlayers <= 3)
    rmSetAreaSize(leftBankDowner, 0.025, 0.025);
else
    rmSetAreaSize(leftBankDowner, 0.033, 0.033);         // Larger for more players

rmSetAreaWarnFailure(leftBankDowner, false);
rmSetAreaCoherence(leftBankDowner, 0.99);
rmSetAreaSmoothDistance(leftBankDowner, 12);
rmSetAreaBaseHeight(leftBankDowner, 2.0);                // Raised 2m above water
rmSetAreaMix(leftBankDowner, paintMix1);
rmSetAreaHeightBlend(leftBankDowner, 8);                 // Smooth slope
rmAddAreaToClass(leftBankDowner, classRiverBank);        // Prevent overlap
rmSetAreaCliffPainting(leftBankDowner, true, false, true, 1.5, true);
rmAddAreaInfluenceSegment(leftBankDowner, 0.6, 0.7, 0.6, 0.5);  // Shape along lake
rmBuildArea(leftBankDowner);

// Right bank of downer lake (mirror of left)
int rightBankDowner = rmCreateArea("right bank downer");
rmSetAreaLocation(rightBankDowner, 0.4, 0.6);            // West side of lake

if (cNumberNonGaiaPlayers <= 3)
    rmSetAreaSize(rightBankDowner, 0.025, 0.025);
else
    rmSetAreaSize(rightBankDowner, 0.033, 0.033);

rmSetAreaWarnFailure(rightBankDowner, false);
rmSetAreaCoherence(rightBankDowner, 0.99);
rmSetAreaSmoothDistance(rightBankDowner, 12);
rmSetAreaBaseHeight(rightBankDowner, 2.0);
rmSetAreaMix(rightBankDowner, paintMix1);
rmSetAreaHeightBlend(rightBankDowner, 8);
rmAddAreaToClass(rightBankDowner, classRiverBank);
rmSetAreaCliffPainting(rightBankDowner, true, false, true, 1.5, true);
rmAddAreaInfluenceSegment(rightBankDowner, 0.4, 0.7, 0.4, 0.5);
rmBuildArea(rightBankDowner);
```

---

**STEP 5: Create Upper Lake Banks (elevation 8.0 - cliffs around upper lake)**

```cpp
// Middle bank - back of upper lake
int middleBankUpper = rmCreateArea("middle bank upper");
rmSetAreaLocation(middleBankUpper, 0.5, 0.9);            // Behind upper lake

if (cNumberNonGaiaPlayers <= 3)
    rmSetAreaSize(middleBankUpper, 0.025, 0.025);
else
    rmSetAreaSize(middleBankUpper, 0.02, 0.02);

rmSetAreaWarnFailure(middleBankUpper, false);
rmSetAreaMix(middleBankUpper, paintMix1);
rmSetAreaCoherence(middleBankUpper, 0.9);
rmSetAreaSmoothDistance(middleBankUpper, 12);
rmSetAreaBaseHeight(middleBankUpper, 8.0);               // Higher than upper lake!
rmSetAreaHeightBlend(middleBankUpper, 8);
rmAddAreaToClass(middleBankUpper, classRiverBankUpper);
rmAddAreaInfluenceSegment(middleBankUpper, 0.45, 1.0, 0.5, 0.85);
rmAddAreaInfluenceSegment(middleBankUpper, 0.55, 1.0, 0.5, 0.85);
rmAddAreaInfluenceSegment(middleBankUpper, 0.55, 1.0, 0.45, 1.0);
rmBuildArea(middleBankUpper);

// Left bank - east cliff of upper lake
int leftBankUpper = rmCreateArea("left bank upper");

// PRECISE positioning by player count
if (cNumberNonGaiaPlayers <= 3)
    rmSetAreaLocation(leftBankUpper, 0.63, 0.9);
else
    rmSetAreaLocation(leftBankUpper, 0.6, 0.9);

rmSetAreaSize(leftBankUpper, 0.033, 0.033);
rmSetAreaWarnFailure(leftBankUpper, false);
rmSetAreaMix(leftBankUpper, paintMix1);
rmSetAreaCoherence(leftBankUpper, 0.7);
rmSetAreaSmoothDistance(leftBankUpper, 12);
rmSetAreaBaseHeight(leftBankUpper, 8.0);
rmSetAreaHeightBlend(leftBankUpper, 8);
rmAddAreaToClass(leftBankUpper, classRiverBankUpper);
rmAddAreaConstraint(leftBankUpper, riverBankUpperConstraint);  // Avoid other upper banks
rmAddAreaInfluenceSegment(leftBankUpper, 0.7, 1.0, 0.6, 0.74);
rmBuildArea(leftBankUpper);

// Right bank - west cliff of upper lake (mirror)
int rightBankUpper = rmCreateArea("right bank upper");

if (cNumberNonGaiaPlayers <= 3)
    rmSetAreaLocation(rightBankUpper, 0.37, 0.9);
else
    rmSetAreaLocation(rightBankUpper, 0.4, 0.9);

rmSetAreaSize(rightBankUpper, 0.033, 0.033);
rmSetAreaWarnFailure(rightBankUpper, false);
rmSetAreaMix(rightBankUpper, paintMix1);
rmSetAreaCoherence(rightBankUpper, 0.7);
rmSetAreaSmoothDistance(rightBankUpper, 12);
rmSetAreaBaseHeight(rightBankUpper, 8.0);
rmSetAreaHeightBlend(rightBankUpper, 8);
rmAddAreaToClass(rightBankUpper, classRiverBankUpper);
rmAddAreaConstraint(rightBankUpper, riverBankUpperConstraint);
rmAddAreaInfluenceSegment(rightBankUpper, 0.3, 1.0, 0.4, 0.74);
rmBuildArea(rightBankUpper);
```

---

**STEP 6: Add Waterfall Decorative Groupings**

```cpp
// Waterfall visual effect between upper and downer lakes
int waterfallGroupingID = -1;
waterfallGroupingID = rmCreateGrouping("waterfall", "Waterfall");

// PRECISE placement varies by player count (within 0.002 precision!)
if (cNumberNonGaiaPlayers == 8 || cNumberNonGaiaPlayers == 5 || cNumberNonGaiaPlayers == 7)
    rmPlaceGroupingAtLoc(waterfallGroupingID, 0, 0.5, 0.717);
else
    rmPlaceGroupingAtLoc(waterfallGroupingID, 0, 0.5, 0.715);

// Waterfall blocker - prevents units from walking through
int waterfallBlockerID = -1;
waterfallBlockerID = rmCreateGrouping("waterfall_blocker", "Waterfall_Blocker");

if (cNumberNonGaiaPlayers == 3 || cNumberNonGaiaPlayers == 5 || 
    cNumberNonGaiaPlayers == 6 || cNumberNonGaiaPlayers == 7 || cNumberNonGaiaPlayers == 8)
    rmPlaceGroupingAtLoc(waterfallBlockerID, 0, 0.5, 0.72);
else
    rmPlaceGroupingAtLoc(waterfallBlockerID, 0, 0.5, 0.715);
```

---

**STEP 7: Lower River (elevation -5 - flows from downer lake down)**

```cpp
// Lower river - flows from middle lake to bottom of map
int riverID2 = rmRiverCreate(-5, "ZP Riverina Waterfalls", 5, 2, 15, 15);
rmRiverAddWaypoint(riverID2, 0.5, 0.55);   // Start just below downer lake
rmRiverAddWaypoint(riverID2, 0.5, 0.5);
rmRiverAddWaypoint(riverID2, 0.4, 0.4);    // Curve left
rmRiverAddWaypoint(riverID2, 0.6, 0.2);    // Curve right
rmRiverAddWaypoint(riverID2, 0.4, 0.0);    // Exit at bottom

rmRiverSetBankNoiseParams(riverID2, 0.00, 0, 0.0, 0.0, 0.0, 0.0);  // Smooth edges
rmRiverSetShallowRadius(riverID2, 15);
rmRiverAddShallow(riverID2, 0.9);          // Crossing near bottom
rmRiverBuild(riverID2);
```

---

**Key Techniques for Waterfall Systems:**

1. **Elevation hierarchy:**
   - Upper lake/river: 7.0m
   - Upper banks: 8.0m (higher than water for cliff effect)
   - Downer lake: 0.0m (base level)
   - Downer banks: 2.0m
   - Lower river: -5.0m (below terrain)

2. **Precise positioning:**
   - Upper lake position varies by 0.005 units (0.85 vs 0.845) based on player count
   - Waterfall groupings vary by 0.002-0.005 units
   - Bank positions adjust by 0.03 units for different player counts
   - Small errors break the visual cascade effect

3. **Class constraints:**
   - `classRiverBank` prevents downer banks from overlapping
   - `classRiverBankUpper` prevents upper banks from overlapping
   - Separate classes for different elevation tiers

4. **Influence segments:**
   - Shape water areas along specific paths
   - Create V-shaped flows and horizontal pools
   - Guide cliff banks alongside water features

5. **Height blending:**
   - `rmSetAreaHeightBlend(8)` creates smooth transitions
   - `rmSetAreaCliffPainting()` adds cliff textures to steep areas
   - Prevents jarring elevation jumps

6. **Player count scaling:**
   - Lake sizes increase for 6-8 players
   - Bank sizes increase for 4+ players
   - Positions micro-adjust for map balance

**Creates:** Dramatic 3-tier waterfall cascade with cliffs, flowing water, and decorative effects.

---

**Examples of maps with rivers:**
- **Mississippi** - Wide central river divider
- **Riverina** - Complex multi-tier waterfall system
- **King of Bohemia** - Straight north-south divider
- **Venice City** - Canal cross system
- **Florence** - Arno river with bridges
- **Paris** - Seine river centerpiece
- **Crown Lands** - Curved Danube with shallows
- **Civil War** - Massive Mississippi with variable width

---

## **17.** 👥 Players

This chapter covers player positioning and placement on random maps.

---

### **17.1. Player Positioning**

Player positioning determines where players spawn on the map. Age of Empires III offers several placement methods, each suited for different map types and gameplay scenarios.

---

#### **17.1.1. Player Coordinates (Fixed Positions)**

**Best for:** 2-player maps, mirrored team spawns, when precise positioning is required

**Uses:** Fixed X/Z coordinates with `rmPlacePlayer()`

**Example from Black Sea - Team Spawn Variations:**

```cpp
// Black Sea: 2 teams with circular placement and spawn variations
float teamStartLoc = rmRandFloat(0,1);  // Randomize which team starts where

if (TeamNum == 2 && teamZeroCount == teamOneCount){
    if (teamStartLoc > 0.5)
    {
        // Team 0 spawns North
        rmSetPlacementTeam(0);
        rmSetPlacementSection(0.888, 0.070);
        rmPlacePlayersCircular(0.34, 0.36, 0);
        
        // Team 1 spawns South
        rmSetPlacementTeam(1);
        rmSetPlacementSection(0.430, 0.612);
        rmPlacePlayersCircular(0.34, 0.36, 0);
    }
    else
    {
        // Team 1 spawns North
        rmSetPlacementTeam(1);
        rmSetPlacementSection(0.888, 0.070);
        rmPlacePlayersCircular(0.34, 0.36, 0);
        
        // Team 0 spawns South
        rmSetPlacementTeam(0);
        rmSetPlacementSection(0.430, 0.612);
        rmPlacePlayersCircular(0.34, 0.36, 0);
    }
}
else{
    // FFA or unbalanced teams - single circular
    rmSetPlacementSection(0.888, 0.612);  
    rmPlacePlayersCircular(0.34, 0.36, 0);
}
```

**Key Functions:**
- `rmSetPlacementTeam(int teamID)` - Set which team to place next
- `rmSetPlacementSection(float startAngle, float endAngle)` - Define arc section for circular placement (in radians)
- `rmPlacePlayer(int playerID, float xFraction, float zFraction)` - Place specific player at exact coordinates

**Advantages:**
- ✅ Full control over spawn positions
- ✅ Perfect for mirrored/balanced team maps
- ✅ Can create spawn variations with randomization

**Disadvantages:**
- ❌ More code for different player counts
- ❌ Requires careful balancing

---

#### **17.1.2. Players Circular**

**Best for:** FFA maps, team maps, most symmetric gameplay scenarios

**Uses:** `rmPlacePlayersCircular(float minPlayerDist, float maxPlayerDist, float distVariance)`

##### **Understanding Distance Values**

**⚠️ CRITICAL: Distance is measured from map center (0.5, 0.5) as a fraction of map radius**

The distance values represent how far from the center players spawn:
- **0.0** = exact center of map (0.5, 0.5)
- **0.5** = at the map edge (maximum possible value)
- **Distance = fraction of radius** (not diameter!)

**Example values and their meaning:**
```cpp
// Near center - players start close together
rmPlacePlayersCircular(0.15, 0.15, 0.0);
// Players spawn at 15% of map radius from center

// Medium distance - balanced gameplay
rmPlacePlayersCircular(0.35, 0.40, 0.05);
// Players spawn 35-40% from center with 5% variance

// Close to edge - maximum safe distance
rmPlacePlayersCircular(0.45, 0.45, 0.0);
// Players spawn at 45% of map radius (near edge but safe)
```

**⚠️ WARNING:** Avoid using values over **0.45**!
- Values of 0.5 or higher may cause **player spawn failures**
- Players will spawn in fallback location (usually bunched together)
- Map edge constraints prevent reliable spawning at extreme distances

##### **A) Two Circulars for Two Teams (with spawn variations)**

**Example from Black Sea** (shown above in 17.1.1)

##### **B) Simple Circular for FFA and Asymmetric Spawns**

```cpp
// Simple FFA circular placement
rmSetPlacementSection(0.0, 1.0);  // Full circle (0 to 2π radians)
rmPlacePlayersCircular(0.35, 0.40, 0.05);
//                      │     │     └─ distance variance (randomness)
//                      │     └─────── maximum distance from center (fraction of radius)
//                      └──────────── minimum distance from center (fraction of radius)
```

**Distance parameters depend on map design:**
- **Cliff positions** - Players must spawn outside cliff areas
- **Trade route layout** - Avoid spawning on trade route path
  - Example: If trade route circle is at 0.3-0.4 range, place players at 0.15 or 0.45
- **Water areas** - Distance from lakes, rivers, or ocean
- **Center features** - Distance from central island, monastery, or monuments
- **Map size** - Available space for player areas

**Practical examples:**
```cpp
// Close to center (when center is empty or has resources only)
rmPlacePlayersCircular(0.25, 0.30, 0.0);

// Medium distance (most common - balanced access to center and edges)
rmPlacePlayersCircular(0.35, 0.40, 0.05);

// Far from center (when center has cliffs, water, or major features)
rmPlacePlayersCircular(0.45, 0.45, 0.0);

// INSIDE a circular trade route (trade route at 0.3-0.5 range)
rmPlacePlayersCircular(0.15, 0.20, 0.0);
```

##### **C) Circular with Team Spacing Modifier**

**Used in:** Some vanilla maps like Great Lakes

**We don't use this method in Age of Pirates** because:
- Better for simple maps with more randomization
- AoP maps are complex - fewer spawn variants = more consistent gameplay
- More predictable spawns help with complex terrain/trade routes

```cpp
// Example (not used in AoP)
rmSetTeamSpacingModifier(0.75);  // Increases space between teams
rmPlacePlayersCircular(0.35, 0.40, 0.05);
```

---

#### **17.1.3. Player Line**

**Best for:** Linear maps, siege scenarios, canyon maps, river-divided maps

**Uses:** `rmPlacePlayersLine(float xStart, float zStart, float xEnd, float zEnd, float distVariance, float edgeDistance)`

##### **Single Line (Labrador Coast)**

**Balanced Teams (2v2, 3v3):**
```cpp
// 4 players: 2v2 on vertical line
if (PlayerNum == 4)
{
    // Team 0: North section
    rmSetPlacementTeam(0);
    rmPlacePlayersLine(0.38, 0.15, 0.38, 0.38, 0, 0);
    
    // Team 1: South section
    rmSetPlacementTeam(1);
    rmPlacePlayersLine(0.38, 0.62, 0.38, 0.85, 0, 0);
}

// 6 players: 3v3 on vertical line
if (PlayerNum == 6)
{
    rmSetPlacementTeam(0);
    rmPlacePlayersLine(0.38, 0.11, 0.38, 0.4, 0, 0);
    
    rmSetPlacementTeam(1);
    rmPlacePlayersLine(0.38, 0.6, 0.38, 0.89, 0, 0);
}
```

**Asymmetric Teams (1v2, 2v3, etc.) - Single Line:**
```cpp
// FFA or asymmetric teams: all players on one continuous line
// Example: 1v2, 2v3, or any unbalanced team setup
rmPlacePlayersLine(0.15, 0.2, 0.85, 0.2, 0, 0);
//                  │     │    │     │
//                  └─────┴────┴─────┴─ Horizontal line across map
// Players distributed evenly regardless of team

// Vertical line for asymmetric spawns
rmPlacePlayersLine(0.5, 0.15, 0.5, 0.85, 0, 0);
// All players along center vertical axis
```

##### **Double Line (Paris, WW Canyon)**

```cpp
// Paris: Two parallel vertical lines (East vs West)
if (teamStartLoc > 0.5)
{
    // Team 0: West side
    rmSetPlacementTeam(0);
    rmPlacePlayersLine(0.1, 0.77, 0.1, 0.27, 0, 0);
    
    // Team 1: East side
    rmSetPlacementTeam(1);
    rmPlacePlayersLine(0.9, 0.27, 0.9, 0.77, 0, 0);
}
else
{
    // Swap team positions
    rmSetPlacementTeam(1);
    rmPlacePlayersLine(0.1, 0.77, 0.1, 0.27, 0, 0);
    
    rmSetPlacementTeam(0);
    rmPlacePlayersLine(0.9, 0.27, 0.9, 0.77, 0, 0);
}
```

**Parameters for `rmPlacePlayersLine()`:**
- `xStart, zStart` - Starting point of line (fractions 0.0-1.0)
- `xEnd, zEnd` - Ending point of line
- `distVariance` - Random variation in placement (usually 0)
- `edgeDistance` - Distance from map edge (usually 0)

---

#### **17.1.4. Players Square**

**Defined in:** RM Function Reference

**We don't use this method** in Age of Pirates, but it's available:

```cpp
// Theoretical example (not used in AoP)
rmPlacePlayersSquare(float dist, float distVariance, float edgeDistance);
```

**Why we don't use it:**
- Creates grid-like spawns (4 corners for 4 players, etc.)
- Less interesting strategically
- Circular and line methods offer better control

---

#### **17.1.5. Advanced Placement Functions**

##### **Team-Based Manual Placement (Urban Maps)**

**Used in:** Florence, Venice City - complex urban maps where players must spawn at specific predetermined locations while maintaining team consistency.

**Problem:** Standard placement functions don't allow precise positioning. `rmPlacePlayer(playerID, x, z)` requires exact player IDs, but player IDs are assigned randomly and don't correspond to team order.

**Solution:** Custom function to get player IDs by team order.

---

**Step 1: Define Global Variable and Function**

```cpp
// Global variable to store result (XS doesn't support return values)
int g_zpTeamPlayerResult = -1;

void zpGetTeamPlayer(int teamOrder = -1, int teamID = -1)
{
    g_zpTeamPlayerResult = -1;
    if (teamOrder <= 0) {
        return;
    }

    int count = 0;
    for (i = 1; <= cNumberNonGaiaPlayers)
    {
        if (rmGetPlayerTeam(i) == teamID)
        {
            count = count + 1;
            if (count == teamOrder)
            {
                g_zpTeamPlayerResult = i;  // "return" via global
                return;
            }
        }
    }
    // not found => stays -1
}
```

---

**Step 2: Get Player IDs for Each Team Position**

```cpp
// Get Team 1 players (Defenders)
zpGetTeamPlayer(1, 1);  // First player in Team 1
int firstDefender = g_zpTeamPlayerResult;

zpGetTeamPlayer(2, 1);  // Second player in Team 1
int secondDefender = g_zpTeamPlayerResult;

zpGetTeamPlayer(3, 1);  // Third player in Team 1
int thirdDefender = g_zpTeamPlayerResult;
// ... up to 7 players

// Get Team 0 players (Attackers)
zpGetTeamPlayer(1, 0);  // First player in Team 0
int firstAttacker = g_zpTeamPlayerResult;

zpGetTeamPlayer(2, 0);  // Second player in Team 0
int secondAttacker = g_zpTeamPlayerResult;
// ... up to 7 players
```

---

**Step 3: Define Grid Locations (specific for urban maps - optional)**

```cpp
// X coordinates (West to East)
float locX0 = 0.94;
float locX1 = 0.851;
float locX2 = 0.755;
// ... more positions

// Z coordinates for North side (Team 1)
float locZ1 = 1.0-rmZTilesToFraction(cityEdgeInner-10);
float locZ2 = 1.0-rmZTilesToFraction(cityEdgeInner-27);
// ... more positions

// Z coordinates for South side (Team 0)
float locZm1 = 0.0+rmZTilesToFraction(cityEdgeInner-10);
float locZm2 = 0.0+rmZTilesToFraction(cityEdgeInner-27);
// ... more positions
```

---

**Step 4: Place Players Based on Team Size**

```cpp
if (cNumberTeams == 2) {
    // Team 1 has 2 players
    if (teamOneCount == 2) {
        rmPlacePlayer(firstDefender, locX8, locZ2); // you can use also coordinates instead of grid variables
        rmPlacePlayer(secondDefender, locX0, locZ2);
    }
    
    // Team 0 has 2 players
    if (teamZeroCount == 2) {
        rmPlacePlayer(firstAttacker, locX9, locZm2);
        rmPlacePlayer(secondAttacker, locX1, locZm2);
    }
    
    // Team 1 has 3 players
    if (teamOneCount == 3) {
        rmPlacePlayer(firstDefender, locX8, locZ2);
        rmPlacePlayer(secondDefender, locX0, locZ2);
        rmPlacePlayer(thirdDefender, locX2, locZ4);
    }
    // ... all combinations up to 7v7
}
```

---

**Benefits:**
- ✅ Teammates always spawn together
- ✅ Precise positioning in urban layouts
- ✅ Works with any player count per team (1v1 to 7v7)
- ✅ Players placed at strategic city positions

**Use Cases:**
- Urban siege maps (Florence, Venice)
- Fortress maps with fixed positions
- Any map requiring exact spawn coordination

---

#### **17.1.6. Best Practices**

##### **Spawn Variants for 2 Teams**

Randomize which team spawns where to prevent predictable gameplay.

```cpp
float teamStartLoc = rmRandFloat(0, 1);

if (teamStartLoc > 0.5) {
    rmSetPlacementTeam(0);
    // ... place team 0 at position A
    rmSetPlacementTeam(1);
    // ... place team 1 at position B
}
else {
    rmSetPlacementTeam(1);
    // ... place team 1 at position A (swapped)
    rmSetPlacementTeam(0);
    // ... place team 0 at position B (swapped)
}
```

---

##### **weirdSpawn Variable**

Handle FFA, 3+ teams, or asymmetric teams (1v2, 2v3, etc.).

```cpp
int weirdSpawn = 0;

if (cNumberTeams == 2 && teamZeroCount == teamOneCount) {
    weirdSpawn = 0;
    // ... normal 2-team placement
}
else {
    weirdSpawn = 1;
    // ... manual placement for FFA/asymmetric
    float placementGap = 0;
    for (k=1; <= cNumberNonGaiaPlayers) {
        rmPlacePlayer(k, 0.38, 0.15+placementGap);
        placementGap = placementGap + 0.7/(cNumberNonGaiaPlayers-1);
    }
}

// Use later in script:
if (weirdSpawn == 1) {
    // ... place objects/terrain differently for weird spawns
}
```

---

##### **KotH Mode**

Special configuration for King of the Hill mode.

```cpp
int blockadeSpawn = 0;
if (rmGetIsKOTH() == true && cNumberTeams == 2)
    blockadeSpawn = 1;

// Use for different configurations:
if (blockadeSpawn == 0)
    rmAddTradeRouteWaypoint(tradeRouteID, 0.0, 0.5);  // Normal: edge connection
// ... interior waypoints
if (blockadeSpawn == 0)
    rmAddTradeRouteWaypoint(tradeRouteID, 0.0, 0.5);  // KotH: no edge connection

// Different groupings
if (blockadeSpawn == 0)
    groupingID = rmCreateGrouping("name", "Normal_Variant");
else
    groupingID = rmCreateGrouping("name", "KotH_Variant");

// Player positions closer to center for KotH
if (blockadeSpawn == 1) {
    rmPlacePlayer(1, 0.55, 0.88);
    // ...
}
```

**Treaty mode:** `rmGetIsTreaty()` exists but is not currently used in AoP maps.

---

### **17.2. Player Placement**

Player placement involves spawning Town Centers, starting units, resources, and water flags for each player.

---

#### **17.2.1. Typical Case (Standard Land Start)**

**Example from Balearic Islands** - Most maps follow this pattern.

```cpp
// 1. Define TC (with Nomad check)
int TCID = rmCreateObjectDef("player TC");
if (rmGetNomadStart())
    rmAddObjectDefItem(TCID, "coveredWagon", 1, 0);
else
    rmAddObjectDefItem(TCID, "townCenter", 1, 0);
rmSetObjectDefMinDistance(TCID, 0.0);
rmSetObjectDefMaxDistance(TCID, 40.0);
rmAddObjectDefConstraint(TCID, avoidWater8);

// 2. Define starting units (Explorer, dog, etc.)
int startingUnits = rmCreateStartingUnitsObjectDef(5.0);
rmSetObjectDefMinDistance(startingUnits, 8.0);
rmSetObjectDefMaxDistance(startingUnits, 12.0);
rmAddObjectDefConstraint(startingUnits, avoidAll);

// 3. Define starting mine
int playerGoldID = rmCreateObjectDef("player silver");
rmAddObjectDefItem(playerGoldID, mineType, 1, 0);
rmSetObjectDefMinDistance(playerGoldID, 12.0);
rmSetObjectDefMaxDistance(playerGoldID, 20.0);
// ... constraints

// 4. Define starting food (hunt)
int playerFoodID = rmCreateObjectDef("player food");
rmAddObjectDefItem(playerFoodID, huntable1, 8, 4.0);
rmSetObjectDefMinDistance(playerFoodID, 10);
rmSetObjectDefMaxDistance(playerFoodID, 15);
rmSetObjectDefCreateHerd(playerFoodID, true);
// ... constraints

// 5. Define starting berries
int playerBerriesID = rmCreateObjectDef("player berries");
rmAddObjectDefItem(playerBerriesID, "berrybush", 6, 4.0);
rmSetObjectDefMinDistance(playerBerriesID, 15);
rmSetObjectDefMaxDistance(playerBerriesID, 20);
// ... constraints

// 6. Define starting trees
int StartAreaTreeID = rmCreateObjectDef("starting trees");
rmAddObjectDefItem(StartAreaTreeID, startTreeType, 10, 12.0);
rmSetObjectDefMinDistance(StartAreaTreeID, 10.0);
rmSetObjectDefMaxDistance(StartAreaTreeID, 17.0);

// 7. Define starting nugget
int playerNuggetID = rmCreateObjectDef("player nugget");
rmAddObjectDefItem(playerNuggetID, "nugget", 1, 0.0);
rmSetObjectDefMinDistance(playerNuggetID, 10.0);
rmSetObjectDefMaxDistance(playerNuggetID, 15.0);
```

**Placement loop:**

```cpp
for(i=1; < cNumberPlayers) {
    // Place TC at player location
    rmPlaceObjectDefAtLoc(TCID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
    vector TCLoc = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(TCID, i));
    
    // Place resources relative to TC
    rmPlaceObjectDefAtLoc(startingUnits, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
    rmPlaceObjectDefAtLoc(playerGoldID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
    rmPlaceObjectDefAtLoc(playerFoodID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
    rmPlaceObjectDefAtLoc(playerBerriesID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
    rmPlaceObjectDefAtLoc(StartAreaTreeID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
    
    // Place nugget
    rmSetNuggetDifficulty(1, 1);
    rmPlaceObjectDefAtLoc(playerNuggetID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
    
    // Asian monastery
    if(ypIsAsian(i) && rmGetNomadStart() == false)
        rmPlaceObjectDefAtLoc(ypMonasteryBuilder(i), i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
}
```

**Key pattern:** Place TC at player location → Get TC position → Place resources relative to TC position.

---

#### **17.2.2. Player Groupings**

Some maps use groupings instead of individual objects for player starts.

⚠️ **CRITICAL:** Player groupings are **NOT** complete starting areas. They only include buildings/props from the grouping XML file. You **MUST** place starting units, resources, and other objects separately!

---

##### **A) Simple Player Grouping (Venice City)**

**Complete example showing what grouping contains vs. what you must place:**

```cpp
// Step 1: Define starting units (Explorer, dog, etc.) - NOT included in grouping
int playerStart = rmCreateStartingUnitsObjectDef(5.0);
rmSetObjectDefMinDistance(playerStart, 7.0);
rmSetObjectDefMaxDistance(playerStart, 12.0);

// Step 2: Define starting resources - NOT included in grouping
int foodID = rmCreateObjectDef("starting hunt");
rmAddObjectDefItem(foodID, "deer", 9, 6.0);
rmSetObjectDefMinDistance(foodID, 12.0);
rmSetObjectDefMaxDistance(foodID, 14.0);
rmSetObjectDefCreateHerd(foodID, true);

int goldID = rmCreateObjectDef("starting gold");
rmAddObjectDefItem(goldID, "Mine", 1, 2.0);
rmSetObjectDefMinDistance(goldID, 14.0);
rmSetObjectDefMaxDistance(goldID, 15.0);

int berryID = rmCreateObjectDef("starting berries");
rmAddObjectDefItem(berryID, "BerryBush", 5, 4.0);
rmSetObjectDefMinDistance(berryID, 16.0);
rmSetObjectDefMaxDistance(berryID, 17.0);

// Step 3: Placement loop
for(i=1; < cNumberNonGaiaPlayers + 1) {
    // Place player fort grouping (contains TC, walls, towers, etc.)
    int playerFortID = rmCreateGrouping("player fort", "malta_player_fort2");
    rmAddGroupingToClass(playerFortID, rmClassID("classBlock"));
    rmPlaceGroupingAtLoc(playerFortID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i), 1);
    
    // MUST place starting units separately - NOT in grouping!
    rmPlaceObjectDefAtLoc(playerStart, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
    
    // MUST place resources separately - NOT in grouping!
    rmPlaceObjectDefAtLoc(foodID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
    rmPlaceObjectDefAtLoc(goldID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
    rmPlaceObjectDefAtLoc(berryID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
    
    // Water flag, monastery, etc. also placed separately
    // ...
}
```

**What `malta_player_fort2` grouping contains:**
- ✅ Town Center
- ✅ Walls, gates, towers
- ✅ Decorative props

**What you MUST place separately:**
- ❌ Explorer, dog, starting units (use `rmCreateStartingUnitsObjectDef`)
- ❌ Starting mine, hunt, berries
- ❌ Water flag
- ❌ Asian monastery

---

##### **B) Complex Multiple Groupings (Florence)**

**Florence uses multiple player groupings per player** - requires separate placement of:
- Starting units (manually defined)
- TC or CoveredWagon (in grouping or separate)
- Monastery for Asian civs (separate)

```cpp
// Get player IDs by team order (see 17.1.5)
zpGetTeamPlayer(1, 0);
int firstAttacker = g_zpTeamPlayerResult;
// ...

// Place player groupings at fixed positions
if (teamZeroCount == 2) {
    int playerGrouping1 = rmCreateGrouping("player base 1", "Florence_PlayerBase_North");
    rmPlaceGroupingAtLoc(playerGrouping1, firstAttacker, locX9, locZm2, 1);
    
    int playerGrouping2 = rmCreateGrouping("player base 2", "Florence_PlayerBase_South");
    rmPlaceGroupingAtLoc(playerGrouping2, secondAttacker, locX1, locZm2, 1);
    
    // Still need to place starting units separately - NOT in grouping!
    rmPlaceObjectDefAtLoc(startingUnits, firstAttacker, locX9, locZm2);
    rmPlaceObjectDefAtLoc(startingUnits, secondAttacker, locX1, locZm2);
    // Also place resources, water flag, monastery separately...
}
```

---

#### **17.2.3. Nomad Start**

Nomad mode gives players a Covered Wagon instead of TC.

```cpp
int TCID = rmCreateObjectDef("player TC");
if (rmGetNomadStart())
    rmAddObjectDefItem(TCID, "coveredWagon", 1, 0);
else
    rmAddObjectDefItem(TCID, "townCenter", 1, 0);
```

**Additional considerations:**
- No monastery for Asian civs in Nomad
- Sometimes extra starting resources
- Covered Wagon placed at same location as TC would be

---

#### **17.2.4. Civ-Based Exceptions**

**Example from Burma** - Different starting units/resources per civilization.

```cpp
// Ottoman gets Galley instead of Caravel
if (rmGetPlayerCiv(i) == rmGetCivID("Ottomans"))
    rmAddObjectDefItem(colonyShipID, "Galley", 1, 10.0);
else
    rmAddObjectDefItem(colonyShipID, "caravel", 1, 10.0);

// Asian monastery (already shown in typical case)
if(ypIsAsian(i) && rmGetNomadStart() == false)
    rmPlaceObjectDefAtLoc(ypMonasteryBuilder(i, 1), i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));

// Japanese berry wagon in ship start (shown in 17.2.4)
if (rmGetPlayerCiv(i) == rmGetCivID("Japanese"))
    rmAddObjectDefItem(startingShipID, "ypBerryWagon1", 1, 0);
```

**Common checks:**
- `rmGetPlayerCiv(i) == rmGetCivID("CivName")` - Check specific civ
- `ypIsAsian(i)` - Check if Asian civ (needs monastery)
- `rmGetNomadStart()` - Check Nomad mode

---

#### **17.2.5. Water Flag Placement**

Water flags determine where naval shipments arrive. **Three methods in order of reliability:**

---

##### **A) Simple Placement (rmFindClosestPointVector)**

**Used in:** Caribbean, Balearic Islands - **Easiest but sometimes unreliable**.

```cpp
// Define closest point constraints
int flagVsFlag = rmCreateTypeDistanceConstraint("flag avoid same", "HomeCityWaterSpawnFlag", 55);
int flagLand = rmCreateTerrainDistanceConstraint("flag vs land", "land", true, 10.0);
int flagEdgeConstraint = rmCreatePieConstraint("flags away from edge", 0.5, 0.5, rmGetMapXSize()-200, rmGetMapXSize()-100, 0, 0, 0);

// Create water flag
int colonyShipID = rmCreateObjectDef("colony ship "+i);
rmAddObjectDefItem(colonyShipID, "HomeCityWaterSpawnFlag", 1, 1.0);

// Add constraints to closest point search
rmAddClosestPointConstraint(flagVsFlag);
rmAddClosestPointConstraint(flagLand);
rmAddClosestPointConstraint(flagEdgeConstraint);

// Find closest water point from TC
vector TCLoc = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(TCID, i));
vector closestPoint = rmFindClosestPointVector(TCLoc, rmXFractionToMeters(1.0));

// Place flag
rmPlaceObjectDefAtLoc(colonyShipID, i, rmXMetersToFraction(xsVectorGetX(closestPoint)), rmZMetersToFraction(xsVectorGetZ(closestPoint)));

rmClearClosestPointConstraints();
```

**Problem:** May fail on complex coastlines or when constraints conflict.

---

##### **B) Deterministic Placement (Vector Calculation)**

**Used in:** Dead Sea - **Sophisticated, works for circular water areas**.

```cpp
int waterSpawnFlagID = rmCreateObjectDef("water spawn flag");
rmAddObjectDefItem(waterSpawnFlagID, "HomeCityWaterSpawnFlag", 1, 0);

for(i=1; < cNumberPlayers) {
    // Map dimensions (adjust for your map)
    int mapX = 300;
    int mapZ = 300;
    int centerX = mapX / 2;
    int centerZ = mapZ / 2;
    
    // Player position in meters
    int playerX = rmPlayerLocXFraction(i) * mapX;
    int playerZ = rmPlayerLocZFraction(i) * mapZ;
    
    // Calculate vector from player toward center
    vector centerPos = xsVectorSet(centerX, 0, centerZ);
    vector playerPos = xsVectorSet(playerX, 0, playerZ);
    vector playerToCenter = xsVectorNormalize(centerPos - playerPos);
    
    // Place flag X meters toward center
    int distance = 80;  // Adjust until it's in water
    vector flagPos = playerPos + playerToCenter * distance;
    
    // Convert back to fractions
    float flagX = xsVectorGetX(flagPos) / mapX;
    float flagZ = xsVectorGetZ(flagPos) / mapZ;
    
    rmPlaceObjectDefAtLoc(waterSpawnFlagID, i, flagX, flagZ);
}
```

**Limitation:** Only works when center is water and players are around it.

---

##### **C) Area Placement (Invisible Water Areas)**

**Used in:** New Guinea - **Most advanced, most reliable**.

**Step 1: Create invisible water areas per player**

```cpp
// During area creation phase
for(i=1; < cNumberPlayers) {
    int waterFlagArea = rmCreateArea("water flag area "+i);
    rmSetAreaSize(waterFlagArea, 0.005, 0.005);  // Small area
    rmSetAreaLocation(waterFlagArea, locX, locZ);  // Near player's shore
    rmSetAreaWaterType(waterFlagArea, "great plains lake");
    rmSetAreaCoherence(waterFlagArea, 1.0);
    rmAddAreaToClass(waterFlagArea, classWaterFlag);
    rmSetAreaObeyWorldCircleConstraint(waterFlagArea, false);
    rmBuildArea(waterFlagArea);
}
```

**Step 2: Place flag with area constraint**

```cpp
int waterFlag = rmCreateObjectDef("HC water flag "+i);
rmAddObjectDefItem(waterFlag, "HomeCityWaterSpawnFlag", 1, 2.0);
rmSetObjectDefMinDistance(waterFlag, 0);
rmSetObjectDefMaxDistance(waterFlag, rmXFractionToMeters(0.05));
rmAddObjectDefConstraint(waterFlag, flagLand);
rmAddAreaConstraint(waterFlag, classWaterFlag);  // Must be in water flag area

rmPlaceObjectDefPerPlayer(waterFlag, true);
```

**Benefits:**
- ✅ Guaranteed placement in designated water zones
- ✅ Works with complex coastlines
- ✅ Full control over flag positions

**Drawback:** Requires planning water areas during terrain generation phase.

---

**Recommendation:**
- **Simple maps:** Use method A (rmFindClosestPointVector)
- **Circular water maps:** Use method B (vector calculation)
- **Complex coastlines:** Use method C (invisible areas)

---

#### **17.2.6. Landing Necessary (Ship Start)**

**Used in:** Iceland, Australia - players start on transport ships that land on shore.

**Key difference:** No land-based starting objects. Everything is placed on water.

```cpp
// Give extra resources for ship start
rmAddPlayerResource(i, "wood", 200);
rmAddPlayerResource(i, "XP", 100);

// Create transport ship with garrison
int startingShipID = rmCreateObjectDef("starting transport ship"+i);
rmAddObjectDefItem(startingShipID, startShipType2, 1, 5);  // Galleon/Fune
rmAddObjectDefItem(startingShipID, "CoveredWagon", 1, 0);
rmAddObjectDefItem(startingShipID, "deDockWagon", 1, 0);

// Garrison starting units (Explorer, etc.) into the ship
rmSetObjectDefGarrisonStartingUnits(startingShipID, true);
rmSetObjectDefGarrisonSecondaryUnits(startingShipID, true);

// Place ship in water at player location
rmPlaceObjectDefAtLoc(startingShipID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
```

**What's different:**
- ❌ No TC placement on land
- ❌ No starting hunt, berries, or mines on land
- ❌ No Explorer/dog spawned on land
- ✅ Everything starts in/on the transport ship
- ✅ Player must land to establish base

**Key functions:**
- `rmSetObjectDefGarrisonStartingUnits()` - Auto-garrisons default starting units
- `rmSetObjectDefGarrisonSecondaryUnits()` - Garrisons Explorers, dogs, etc.

---

## **18.** 📦 Objects

Objects are individual entities placed on the map, including resources, animals, treasures, decorative props, and special controllers.

---

### **18.1. Object Definition - Multiple Objects (Herds/Chunks)**

You can place multiple objects of the same type together as a "herd" or "chunk" using `rmAddObjectDefItem()` count parameter.

⚠️ **CRITICAL:** The "Item" parameter is a **ProtoUnit name** defined in `data/protoy.xml` or `data/protomods.xml`. Always verify the proto unit exists before using it!

**Basic Pattern:**

```cpp
// Single object
int mineID = rmCreateObjectDef("silver mine");
rmAddObjectDefItem(mineID, "mine", 1, 0.0);  // "mine" = ProtoUnit name, Count = 1

// Herd of animals (cluster)
int deerID = rmCreateObjectDef("deer herd");
rmAddObjectDefItem(deerID, "deer", 8, 4.0);  // "deer" = ProtoUnit, 8 count, 4m spread
rmSetObjectDefMinDistance(deerID, 50.0);
rmSetObjectDefMaxDistance(deerID, 80.0);
rmPlaceObjectDefPerPlayer(deerID, false, 2);  // 2 herds per player

// Berry bushes (cluster)
int berryID = rmCreateObjectDef("berry bush");
rmAddObjectDefItem(berryID, "BerryBush", 6, 4.0);  // "BerryBush" = ProtoUnit, 6 count, 4m spread
rmPlaceObjectDefInArea(berryID, 0, bonusIslandID, 3);  // 3 clusters on island
```

**Parameters:**
- **ProtoUnit:** Name of the unit from `protoy.xml` or `protomods.xml` (e.g., `"deer"`, `"mine"`, `"BerryBush"`)
- **Count:** Number of objects in the group (1 = single, 2+ = herd/cluster)
- **Distance:** How far objects spread from center point (0.0 = tight cluster, 4.0+ = loose herd)

**Common Herd Sizes:**
- **Huntables:** 4-8 animals per herd
- **Berries:** 4-6 bushes per cluster
- **Fish:** 3-4 fish per school
- **Trees:** 8-15 trees per grove

---

#### **Placement Methods: InArea vs AtLoc**

There are two main methods for placing objects, with different behaviors:

**Method 1: `rmPlaceObjectDefInArea()` - Constrained Area Placement**

```cpp
rmPlaceObjectDefInArea(berryID, 0, bonusIslandID, 3);  // 3 clusters on island
```

- **Purpose:** Place objects WITHIN a specific area
- **How it works:** 
  - Places exactly 3 berry clusters (in this example)
  - Each cluster placed INSIDE the `bonusIslandID` area boundaries
  - Respects area constraints and boundaries
  - Uses min/max distance from area center (if set)
- **Best for:** Resource clusters on islands, specific terrain areas, player starting resources

---

**Method 2: `rmPlaceObjectDefAtLoc()` - Random Map-Wide Placement**

```cpp
rmSetObjectDefMinDistance(randomTreeID, 0.0);
rmSetObjectDefMaxDistance(randomTreeID, rmXFractionToMeters(0.5));
rmPlaceObjectDefAtLoc(randomTreeID, 0, 0.5, 0.5, 20);  // 20 random trees
```

- **Purpose:** Scatter objects randomly across the map from a center point
- **How it works:**
  - Places 20 individual trees (in this example)
  - **Center point:** (0.5, 0.5) = map center
  - **Min distance:** 0.0 = can place immediately at center
  - **Max distance:** `rmXFractionToMeters(0.5)` = anywhere within 50% of map radius
  - Each tree placed randomly within this radius from center
  - Does NOT respect area boundaries (only constraints)
- **Best for:** Decorative objects scattered across entire map

**Why these distance settings?**
- `rmSetObjectDefMinDistance(randomTreeID, 0.0)` = No minimum distance from center (can place anywhere)
- `rmSetObjectDefMaxDistance(randomTreeID, rmXFractionToMeters(0.5))` = Maximum distance is 50% of map size from center
- **Result:** Trees scattered randomly across the entire map (from center to edges)

If you used smaller values like `rmXFractionToMeters(0.2)`, trees would only appear in the central 20% of the map.

---

#### **Advanced Placement Control**

##### **Subcase A: Using Constraints for Precise Placement**

You can further control object placement using multiple constraints:

**1. Stay in Concrete Area:**
```cpp
int stayInBonus = rmCreateAreaConstraint("stay in bonus", bonusIslandID);

int treasureID = rmCreateObjectDef("island treasure");
rmAddObjectDefItem(treasureID, "Nugget", 1, 0.0);
rmAddObjectDefConstraint(treasureID, stayInBonus);  // MUST be in bonus island
rmPlaceObjectDefAtLoc(treasureID, 0, 0.5, 0.5, 10);
```

**2. Avoid Specific Area or Class:**
```cpp
int avoidPlayerArea = rmCreateAreaConstraint("avoid player", classPlayerArea);
int avoidIslands = rmCreateClassDistanceConstraint("avoid islands", classBonusIsland, 30.0);

int fishID = rmCreateObjectDef("fish");
rmAddObjectDefItem(fishID, "FishMahi", 3, 8.0);
rmAddObjectDefConstraint(fishID, avoidPlayerArea);  // Stay away from player bases
rmAddObjectDefConstraint(fishID, avoidIslands);     // Keep distance from islands
rmPlaceObjectDefAtLoc(fishID, 0, 0.5, 0.5, 15);
```

**3. Cardinal Direction Constraints:**
```cpp
// Keep objects in northern half of map
int stayNorth = rmCreateBoxConstraint("stay north", 0.0, 0.5, 1.0, 1.0);

// Keep objects in southern half
int staySouth = rmCreateBoxConstraint("stay south", 0.0, 0.0, 1.0, 0.5);

// Place whales only in northern waters
int whaleID = rmCreateObjectDef("whale north");
rmAddObjectDefItem(whaleID, "HumpbackWhale", 1, 0.0);
rmAddObjectDefConstraint(whaleID, stayNorth);  // Northern half only
rmAddObjectDefConstraint(whaleID, fishLand);    // In water
rmPlaceObjectDefAtLoc(whaleID, 0, 0.5, 0.75, 3);  // 3 whales in north
```

**Box Constraint Format:**
- `rmCreateBoxConstraint("name", minX, minZ, maxX, maxZ)`
- Values are fractions (0.0 to 1.0)
- North = high Z (0.5-1.0), South = low Z (0.0-0.5)
- East = high X (0.5-1.0), West = low X (0.0-0.5)

---

##### **Subcase B: Precise Placement on Concrete Location**

For exact placement at specific coordinates (not random), use min/max distance of 0:

**Example: Pearl Placement (Black Sea Map Pattern)**

```cpp
// Define pearl object
int pearlID = rmCreateObjectDef("black sea pearl");
rmAddObjectDefItem(pearlID, "zpPearl", 1, 0.0);  // Single pearl
rmSetObjectDefMinDistance(pearlID, 0.0);
rmSetObjectDefMaxDistance(pearlID, 0.0);  // Both 0 = exact placement only
rmAddObjectDefConstraint(pearlID, stayInWater);

// Place pearls at exact coordinates (not random)
rmPlaceObjectDefAtLoc(pearlID, 0, 0.23, 0.78);  // Pearl 1 at specific location
rmPlaceObjectDefAtLoc(pearlID, 0, 0.45, 0.82);  // Pearl 2 at specific location
rmPlaceObjectDefAtLoc(pearlID, 0, 0.67, 0.76);  // Pearl 3 at specific location
rmPlaceObjectDefAtLoc(pearlID, 0, 0.31, 0.55);  // Pearl 4 at specific location
```

**Key Settings for Exact Placement:**
- `rmSetObjectDefMinDistance(0.0)` + `rmSetObjectDefMaxDistance(0.0)` = NO randomness
- Each `rmPlaceObjectDefAtLoc()` call places at the EXACT coordinates specified
- Count parameter (last parameter) should be 1 for single precise placement
- If count > 1, multiple objects placed at the same spot (usually not desired)

**Use Cases:**
- Special treasures at predetermined locations
- Unique resources (pearls, rare minerals)
- Landmark objects that must be in exact positions
- Symmetric map layouts with mirrored placements

**Reference:** See `randmaps/zpblacksea.xs` for pearl placement implementation.

---

#### **⚠️ CRITICAL: Constraint Definitions**

**Missing constraints are the #1 cause of object placement errors!**

When copying object definitions from other map files:

```cpp
// ❌ WRONG - Will crash if constraint doesn't exist!
int deerID = rmCreateObjectDef("deer herd");
rmAddObjectDefItem(deerID, "deer", 8, 4.0);
rmAddObjectDefConstraint(deerID, avoidHuntable);  // ERROR if avoidHuntable not defined!
rmPlaceObjectDefPerPlayer(deerID, false, 2);
```

```cpp
// ✅ CORRECT - Define ALL constraints BEFORE using them
int avoidHuntable = rmCreateTypeDistanceConstraint("avoid huntable", "huntable", 30.0);
int avoidAll = rmCreateTypeDistanceConstraint("avoid all", "all", 6.0);

int deerID = rmCreateObjectDef("deer herd");
rmAddObjectDefItem(deerID, "deer", 8, 4.0);
rmAddObjectDefConstraint(deerID, avoidHuntable);  // Now it works!
rmAddObjectDefConstraint(deerID, avoidAll);
rmPlaceObjectDefPerPlayer(deerID, false, 2);
```

**Rules:**
1. **Define ALL constraints at the top of your script** (in constraints section)
2. **Check every `rmAddObjectDefConstraint()` call** - does that constraint exist?
3. **When copying code** - copy the constraint definitions too!
4. **Common missing constraints:**
   - `avoidAll`, `avoidImpassableLand`, `avoidWater`
   - `avoidMine`, `avoidHuntable`, `avoidBerries`, `avoidFish`
   - `avoidNugget`, `avoidTree`, `avoidSocket`
   - `avoidStartingResources`, `avoidPlayer`, `avoidTC`

**Always verify:** If you see an object placement error, check constraint definitions first!

---

### **18.2. Object Classes and Map Patterns**

Different object types serve specific gameplay purposes. Here are the standard patterns:

#### **A) Mines (Gold/Silver)**

**ProtoUnit:** `"mine"`, `"minegold"`, or custom variants

```cpp
// Player starting mine
int playerMineID = rmCreateObjectDef("player mine");
rmAddObjectDefItem(playerMineID, "mine", 1, 0.0);
rmSetObjectDefMinDistance(playerMineID, 15.0);
rmSetObjectDefMaxDistance(playerMineID, 20.0);
rmAddObjectDefConstraint(playerMineID, avoidStartingResources);
rmPlaceObjectDefPerPlayer(playerMineID, false, 1);

// Bonus mines across map
int bonusMineID = rmCreateObjectDef("bonus mine");
rmAddObjectDefItem(bonusMineID, "mine", 1, 0.0);
rmAddObjectDefConstraint(bonusMineID, avoidAll);
rmAddObjectDefConstraint(bonusMineID, avoidMine);
rmPlaceObjectDefPerPlayer(bonusMineID, false, 3);  // 3 bonus mines per player
```

---

#### **B) Berries**

**ProtoUnit:** `"BerryBush"` or variants like `"zpBerryBush"`

```cpp
// Player starting berries
int playerBerriesID = rmCreateObjectDef("player berries");
rmAddObjectDefItem(playerBerriesID, "BerryBush", 6, 4.0);  // 6 bushes
rmSetObjectDefMinDistance(playerBerriesID, 20.0);
rmSetObjectDefMaxDistance(playerBerriesID, 25.0);
rmAddObjectDefConstraint(playerBerriesID, avoidStartingResources);
rmPlaceObjectDefPerPlayer(playerBerriesID, false, 1);

// Bonus berry clusters
int bonusBerriesID = rmCreateObjectDef("bonus berries");
rmAddObjectDefItem(bonusBerriesID, "BerryBush", 4, 3.0);
rmPlaceObjectDefInArea(bonusBerriesID, 0, bonusIslandID, 2);
```

---

#### **C) Huntables**

**Common ProtoUnits:** `"deer"`, `"elk"`, `"bison"`, `"zebra"`, `"ypSerow"`, `"zpElephant"`

```cpp
// Primary hunt (larger herds)
int deerID = rmCreateObjectDef("deer herd");
rmAddObjectDefItem(deerID, "deer", 8, 4.0);  // 8 deer per herd
rmSetObjectDefMinDistance(deerID, 50.0);
rmSetObjectDefMaxDistance(deerID, 80.0);
rmAddObjectDefConstraint(deerID, avoidAll);
rmAddObjectDefConstraint(deerID, avoidHuntable);  // Separate herds
rmPlaceObjectDefPerPlayer(deerID, false, 2);  // 2 herds per player

// Secondary hunt (smaller groups)
int turkeyID = rmCreateObjectDef("turkey");
rmAddObjectDefItem(turkeyID, "turkey", 4, 3.0);  // 4 turkeys
rmPlaceObjectDefPerPlayer(turkeyID, false, 3);
```

---

#### **D) Random Trees (Decorative)**

**ProtoUnits:** Various tree types from `protoy.xml`

```cpp
// Scattered decorative trees
int randomTreeID = rmCreateObjectDef("random tree");
rmAddObjectDefItem(randomTreeID, "TreeGreatPlains", 1, 0.0);
rmSetObjectDefMinDistance(randomTreeID, 0.0);
rmSetObjectDefMaxDistance(randomTreeID, rmXFractionToMeters(0.5));
rmAddObjectDefConstraint(randomTreeID, avoidAll);
rmAddObjectDefConstraint(randomTreeID, avoidTree);
rmPlaceObjectDefAtLoc(randomTreeID, 0, 0.5, 0.5, 20);  // 20 random trees

// Tree groves
int treeGroveID = rmCreateObjectDef("tree grove");
rmAddObjectDefItem(treeGroveID, "TreeCarolinas", 10, 5.0);  // 10 trees in cluster
rmPlaceObjectDefInArea(treeGroveID, 0, mainlandID, 5);  // 5 groves
```

---

#### **E) Other Decorative Objects**

Check specific maps for decorative prop patterns and verify proto units in `data/protoy.xml` or `data/protomods.xml`:

```cpp
// Decorative props (check protoy.xml for valid units)
int propID = rmCreateObjectDef("decorative prop");
rmAddObjectDefItem(propID, "UnderbrushForest", 1, 0.0);
rmAddObjectDefConstraint(propID, avoidAll);
rmPlaceObjectDefAtLoc(propID, 0, 0.5, 0.5, 30);

// Underwater vegetation
int plantID = rmCreateObjectDef("underwater plant");
rmAddObjectDefItem(plantID, "UnderWaterPlant", 1, 0.0);
rmAddObjectDefConstraint(plantID, stayInWater);
rmPlaceObjectDefAtLoc(plantID, 0, 0.5, 0.5, 50);
```

⚠️ **Always verify proto unit names exist before using them!**

---

### **18.3. Fishes - Common Patterns**

Fish are placed in water using specific constraints and typical herd patterns.

**Common Fish ProtoUnits:**
- `"FishMahi"` - Mahi-mahi (tropical)
- `"FishSalmon"` - Salmon (temperate)
- `"FishCod"` - Cod (northern)
- `"ypFishTuna"` - Tuna (Asian maps)
- `"FishSardines"` - Sardines (Mediterranean)

**Whale ProtoUnits:**
- `"HumpbackWhale"` - Humpback whale
- `"MinkeWhale"` - Minke whale
- `"ypWhaleHumpback"` - Asian humpback whale

#### **Standard Fish Pattern:**

```cpp
// Define water constraint
int fishLand = rmCreateTerrainDistanceConstraint("fish land", "land", true, 6.0);

// Player starting fish
int playerFishID = rmCreateObjectDef("player fish");
rmAddObjectDefItem(playerFishID, "FishMahi", 3, 8.0);  // 3 fish per school
rmSetObjectDefMinDistance(playerFishID, 50.0);
rmSetObjectDefMaxDistance(playerFishID, 80.0);
rmAddObjectDefConstraint(playerFishID, fishLand);  // Stay in water
rmAddObjectDefConstraint(playerFishID, avoidFish);  // Separate schools
rmPlaceObjectDefPerPlayer(playerFishID, false, 2);  // 2 schools per player

// Bonus fish across map
int bonusFishID = rmCreateObjectDef("bonus fish");
rmAddObjectDefItem(bonusFishID, "FishSalmon", 4, 10.0);
rmAddObjectDefConstraint(bonusFishID, fishLand);
rmPlaceObjectDefAtLoc(bonusFishID, 0, 0.5, 0.5, 15);  // 15 schools randomly
```

#### **Whale Pattern:**

```cpp
// Whales (decorative + food source)
int whaleID = rmCreateObjectDef("whale");
rmAddObjectDefItem(whaleID, "HumpbackWhale", 1, 0.0);  // Single whale
rmSetObjectDefMinDistance(whaleID, 0.0);
rmSetObjectDefMaxDistance(whaleID, rmXFractionToMeters(0.5));
rmAddObjectDefConstraint(whaleID, fishLand);
rmAddObjectDefConstraint(whaleID, avoidWhale);  // Keep whales separated
rmPlaceObjectDefAtLoc(whaleID, 0, 0.5, 0.5, 5);  // 5 whales on map
```

**Key Rules:**
- Fish schools typically 3-4 fish with 8-10 meter spread
- Whales are usually single or pairs
- Always use terrain distance constraint to keep in water
- Separate schools with `avoidFish` constraint

---

### **18.4. Nuggets (Treasures)**

Nuggets are treasure objects with different difficulty levels and rewards. Defined in `data/nuggetmods.xml`.

#### **Nugget Basics:**

**Standard Difficulty Levels:**
- **Difficulty 1:** Easy (few/weak guardians)
- **Difficulty 2:** Medium (moderate guardians)
- **Difficulty 3:** Hard (strong guardians)
- **Difficulty 4:** Very Hard (multiple strong guardians)

**Special Difficulty Levels (Age of Pirates):**
Pirate historical maps use custom difficulty values to define special nugget types:
- Check `data/nuggetmods.xml` for map-specific nuggets (e.g., `zpKev1`, `zpKev3`, `zpAUSettler`)
- Custom difficulties override default nugget types

#### **Basic Nugget Placement:**

```cpp
// Easy nuggets near players
int nuggetEasyID = rmCreateObjectDef("nugget easy");
rmAddObjectDefItem(nuggetEasyID, "Nugget", 1, 0.0);
rmSetNuggetDifficulty(nuggetEasyID, 1);  // Difficulty 1 = easy
rmSetObjectDefMinDistance(nuggetEasyID, 40.0);
rmSetObjectDefMaxDistance(nuggetEasyID, 60.0);
rmAddObjectDefConstraint(nuggetEasyID, avoidNugget);
rmAddObjectDefConstraint(nuggetEasyID, avoidAll);
rmPlaceObjectDefPerPlayer(nuggetEasyID, false, 2);  // 2 easy nuggets per player

// Hard nuggets on bonus islands
int nuggetHardID = rmCreateObjectDef("nugget hard");
rmAddObjectDefItem(nuggetHardID, "Nugget", 1, 0.0);
rmSetNuggetDifficulty(nuggetHardID, 3);  // Difficulty 3 = hard
rmPlaceObjectDefInArea(nuggetHardID, 0, bonusIslandID, 3);  // 3 hard nuggets
```

#### **Nuggets in Groupings:**

When a grouping contains nuggets, you must override the difficulty to specify the nugget type:

```cpp
// Place grouping with nuggets
int villageID = rmCreateGrouping("native village", "scientist_lab01");
rmSetGroupingMinDistance(villageID, 0.0);
rmSetGroupingMaxDistance(villageID, 0.0);

// Override nugget difficulty for grouping
rmSetGroupingNuggetDifficulty(villageID, 2);  // Sets all nuggets in grouping to difficulty 2

rmPlaceGroupingAtLoc(villageID, 0, 0.5, 0.5);
```

⚠️ **Important:** If you don't set the difficulty, grouping nuggets use their default from the XML, which may not match your map's intended balance.

---

#### **Water Nuggets:**

Water nuggets are placed in water areas using terrain constraints:

```cpp
// Define water constraint
int nuggetWater = rmCreateTerrainMaxDistanceConstraint("nugget water", "land", false, 12.0);

// Water nugget
int waterNuggetID = rmCreateObjectDef("water nugget");
rmAddObjectDefItem(waterNuggetID, "ypNuggetBoat", 1, 0.0);  // Boat nugget
rmSetNuggetDifficulty(waterNuggetID, 2);
rmAddObjectDefConstraint(waterNuggetID, nuggetWater);  // Must be in water
rmAddObjectDefConstraint(waterNuggetID, avoidLand);
rmPlaceObjectDefAtLoc(waterNuggetID, 0, 0.5, 0.5, 5);
```

#### **Special Water Nuggets (Diving Bell Example):**

Some maps feature unique water nuggets like diving bells. Check specific map implementations:

```cpp
// Example: Great Barrier Reef diving bell nuggets
// These use custom proto units and special difficulty levels
int diverNuggetID = rmCreateObjectDef("diver nugget");
rmAddObjectDefItem(diverNuggetID, "zpDivingBellNugget", 1, 0.0);  // Custom proto
rmSetNuggetDifficulty(diverNuggetID, 5);  // Custom difficulty for special behavior
rmAddObjectDefConstraint(diverNuggetID, nuggetWater);
rmPlaceObjectDefInArea(diverNuggetID, 0, reefAreaID, 3);
```

**Reference Files:**
- `data/nuggetmods.xml` - All nugget definitions
- `art/buildings/gold_mine/diving_bell_nugget.xml` - Special nugget models

---

### **18.5. Controllers (Special Object Class)**

**Controllers** are invisible placement markers used to precisely position groupings and other objects. They use the `"zpSPCWaterSpawnPoint"` proto unit.

#### **What Controllers Do:**

1. **Serve as reference points** - Get exact X/Z coordinates from their placement
2. **Center groupings** - Place native villages/city states relative to controller position
3. **Create constraints** - Other objects can avoid controllers to protect areas

#### **Basic Controller Pattern:**

```cpp
// Step 1: Create and place controller
int controllerID = rmCreateObjectDef("Controller 1");
rmAddObjectDefItem(controllerID, "zpSPCWaterSpawnPoint", 1, 0.0);
rmSetObjectDefMinDistance(controllerID, 0.0);
rmSetObjectDefMaxDistance(controllerID, 0.0);
rmPlaceObjectDefAtLoc(controllerID, 0, 0.15, 0.27);  // Place at specific location

// Step 2: Get controller's exact position
vector ControllerLoc1 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(controllerID, 0));

// Step 3: Use controller location for precise placement
int pirateVillageID = rmCreateGrouping("pirate village", "pirate_village03");
rmPlaceGroupingAtLoc(
    pirateVillageID, 
    0, 
    rmXMetersToFraction(xsVectorGetX(ControllerLoc1)),  // Use controller X
    rmZMetersToFraction(xsVectorGetZ(ControllerLoc1)),  // Use controller Z
    1
);
```

#### **Complete Example from Malta Map:**

**Step 1: Place controllers at specific locations**
```cpp
// Place Controllers
int controllerID1 = rmCreateObjectDef("Controler 1");
rmAddObjectDefItem(controllerID1, "zpSPCWaterSpawnPoint", 1, 0.0);
rmPlaceObjectDefAtLoc(controllerID1, 0, 0.15, 0.27);
vector ControllerLoc1 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(controllerID1, 0));

if(cNumberNonGaiaPlayers >= 4){
    int controllerID2 = rmCreateObjectDef("Controler 2");
    rmAddObjectDefItem(controllerID2, "zpSPCWaterSpawnPoint", 1, 0.0);
    rmPlaceObjectDefAtLoc(controllerID2, 0, 0.27, 0.15);
    vector ControllerLoc2 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(controllerID2, 0));
}
```

**Step 2: Create terrain areas at controller positions**
```cpp
int pirateSite1 = rmCreateArea ("pirate_site1");
rmSetAreaSize(pirateSite1, rmAreaTilesToFraction(600.0), rmAreaTilesToFraction(600.0));
rmSetAreaLocation(pirateSite1, rmXMetersToFraction(xsVectorGetX(ControllerLoc1)), rmZMetersToFraction(xsVectorGetZ(ControllerLoc1)));
rmSetAreaMix(pirateSite1, "africa desert sand");
rmSetAreaCoherence(pirateSite1, 1);
rmSetAreaSmoothDistance(pirateSite1, 15);
rmBuildArea(pirateSite1);
rmSetAreaWarnFailure(pirateSite1, false);

int pirateSite2 = rmCreateArea ("pirate_site2");
rmSetAreaSize(pirateSite2, rmAreaTilesToFraction(600.0), rmAreaTilesToFraction(600.0));
rmSetAreaLocation(pirateSite2, rmXMetersToFraction(xsVectorGetX(ControllerLoc2)), rmZMetersToFraction(xsVectorGetZ(ControllerLoc2)));
rmSetAreaMix(pirateSite2, "africa desert sand");
rmSetAreaCoherence(pirateSite2, 1);
rmSetAreaSmoothDistance(pirateSite2, 15);
rmBuildArea(pirateSite2);
rmSetAreaWarnFailure(pirateSite2, false);
```

**Step 3: Place groupings at controller positions**
```cpp
int piratesVillageID = -1;
piratesVillageID = rmCreateGrouping("pirate city", "pirate_village03");      
rmPlaceGroupingAtLoc(piratesVillageID, 0, rmXMetersToFraction(xsVectorGetX(ControllerLoc1)), rmZMetersToFraction(xsVectorGetZ(ControllerLoc1)), 1);
```

**Reference:** See `randmaps/zpmalta.xs` for the complete implementation.

#### **Controller Constraints:**

Controllers can be used in constraints to protect areas:

```cpp
// Create constraint to avoid controllers
int avoidController = rmCreateTypeDistanceConstraint("avoid controller", "zpSPCWaterSpawnPoint", 70.0);
int avoidControllerMedium = rmCreateTypeDistanceConstraint("avoid controller medium", "zpSPCWaterSpawnPoint", 40.0);

// Use in area/object placement
rmAddAreaConstraint(bonusIslandID, avoidControllerMedium);  // Keep islands away from groupings
rmAddObjectDefConstraint(mineID, avoidController);  // Keep mines away from native sites
```

#### **Why Use Controllers?**

1. **Precision** - Get exact meter coordinates from fraction placement
2. **Sequencing** - Create terrain AROUND the grouping position before placing grouping
3. **Complex layouts** - Multiple groupings positioned relative to each other
4. **Trigger integration** - Can be used as trigger points in scenarios

**Common Usage:**
- Native village placement on specific islands
- City state positioning with surrounding terrain
- Harbor/port placement relative to coastline
- Multi-part complexes (e.g., Venice with multiple districts)

---

## **19.** 🏘️ Groupings (Native Villages, City States, Decorative Structures)

⚠️ **COORDINATE WARNING:** Grouping placement uses `rmPlaceGroupingAtLoc()` with X/Z coordinates!
- **MUST READ:** `docs/map_coordinate_system.md` before placing groupings
- Common issues: coordinates are rotated 45° from visual minimap
- Example: To place on visual "West", use low X + high Z like `(0.15, 0.85)`

**Locations:**
- `<workspace>/game/randmaps/groupings/` (contains 100+ `.xml` files)

**Definition:** Pre-built clusters of buildings, units, terrain, and decorative objects that represent native villages, city states, pirate hideouts, etc.

**Used in maps via:** `rmCreateGrouping()` and `rmPlaceGroupingAtLoc()` or `rmPlaceGroupingInArea()`

---

### **19.1. How to Find Groupings**

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
```cpp
// ✅ CORRECT - Verified file exists
scientistsVillageID = rmCreateGrouping("scientists", "scientist_lab0"+rmRandInt(1,6));

// ❌ WRONG - Guessed name
scientistsVillageID = rmCreateGrouping("scientists", "native scientists village "+variant);
```

---

### **19.2. Common Naming Patterns**

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

### **19.3. How to Place Groupings**

**Basic Syntax:**
```cpp
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
```cpp
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
```cpp
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
```cpp
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

### **19.4. Critical Rules**

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

### **19.5. Pirate Placement (Coastal Natives)**

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

```cpp
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

```cpp
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

```cpp
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

### **19.6. Coastal Native Water Flag Placement**
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

```cpp
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

### **19.7 Floating Islands (Advanced Technique)**

⚠️ **EXTREMELY ADVANCED:** This technique exploits the game engine's bridge placement system to create islands that appear to "float" on water. Check `000_blacksea.xs` for a complete working example.

---

#### **The Problem**

The game engine does NOT support placing islands directly on water - such placement almost never works. What it DOES support is placing "bridges" over rivers on trade routes.

#### **The Solution**

Create a river over an invisible landmass, then place a grouping with embedded terrain height data that acts as a "bridge" - creating a floating island effect.

---

#### **Requirements**

**You need:**
1. Special placement order (strict - must follow exactly)
2. Grouping with defined land elevation levels (e.g., `Istanbul_AS.xml`)
3. Shoreless water type as base water
4. Paired water type with shoreline for river

**Grouping Example:** `game/randmaps/groupings/Istanbul_AS.xml`
- Contains `<heights><tiles>` section with elevation data
- Values like `5.999` = island surface, `-0.001` = water level
- This terrain height map creates "land" when placed on river

---

#### **Step-by-Step Implementation**

##### **Step 0: Choose Shoreless Water Type**

**Why shoreless water?** Some water types in `waterbodies.xml` have empty values: `bank=""` `outerbank=""`. These are shoreless water types.

**The problem:** The game automatically overwrites grouping terrain textures with shoreline textures from the water type, which can look awkward.

**The solution:** Shoreless water types don't have this overwriting behavior, preserving the original grouping terrain.

**Water Type Pairs:**
- Base water (shoreless): `"ZP Black Sea Lagoon"` → Use for `rmSetSeaType()`
- River water (with shore): `"ZP Black Sea Water"` → Use for `rmRiverCreate()`

```cpp
// Set shoreless water as base
rmSetSeaType("ZP Black Sea Lagoon");  // No shoreline textures
rmTerrainInitialize("water");
```

---

##### **Step 1: Create Invisible Landmass Beneath River**

**Why?** Bridges can only be placed on rivers, and rivers can only be placed on land. If you don't have natural land, you must create an invisible landmass first.


```cpp
// Create invisible landmass to support the river
int landMassID = rmCreateArea("land mass 1");
rmSetAreaSize(landMassID, rmAreaTilesToFraction(11000), rmAreaTilesToFraction(11000));
rmSetAreaLocation(landMassID, 0.15, 0.5);
rmSetAreaCoherence(landMassID, 1.0);
rmSetAreaBaseHeight(landMassID, 2.0);
rmSetAreaWarnFailure(landMassID, false);
rmSetAreaMix(landMassID, "italy_grass");
rmSetAreaElevationVariation(landMassID, 0.0);
rmAddAreaInfluenceSegment(landMassID, 0.15, 0.9, 0.15, 0.1);
rmBuildArea(landMassID);
```
---

##### **Step 2: Define Trade Route Dummy Object**

⚠️ **CRITICAL:** The dummy stopper object is mysteriously required - without it, islands won't spawn. Reason unknown, but it's absolutely necessary.

```cpp
// Trade route dummy stopper
int stopperID = rmCreateObjectDef("Armored Train Stopper");
rmAddObjectDefItem(stopperID, "zpSPCWaterSpawnPoint", 1, 0.0);
rmSetObjectDefAllowOverlap(stopperID, true);
rmSetObjectDefMinDistance(stopperID, 0.0);
rmSetObjectDefMaxDistance(stopperID, 0.0);
```
---

##### **Step 3: Create and Build Trade Route**

```cpp
// Define trade route
int tradeRouteID = rmCreateTradeRoute();
rmSetObjectDefTradeRouteID(stopperID, tradeRouteID);

// Add waypoints (circular route example)
rmAddTradeRouteWaypoint(tradeRouteID, 0.0, 0.5);
rmAddTradeRouteWaypoint(tradeRouteID, 0.32, 0.5);
rmAddTradeRouteWaypoint(tradeRouteID, 0.5, 0.71);
rmAddTradeRouteWaypoint(tradeRouteID, 0.7, 0.5);
rmAddTradeRouteWaypoint(tradeRouteID, 0.5, 0.32);
rmAddTradeRouteWaypoint(tradeRouteID, 0.32, 0.5);
rmAddTradeRouteWaypoint(tradeRouteID, 0.0, 0.5);

// Build with water trail type
rmBuildTradeRoute(tradeRouteID, "water_trail");

// Place the mysterious required stopper
vector socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.5);
rmPlaceObjectDefAtPoint(stopperID, 0, socketLoc1);
```

---

##### **Step 4: Then place river over the landmass:**

```cpp
// River must use water type WITH shoreline textures
int riverID = rmRiverCreate(-1, "ZP Black Sea Water", 4, 4, 40, 40);
rmRiverAddWaypoint(riverID, 0.15, 0.9);
rmRiverAddWaypoint(riverID, 0.15, 0.1);
rmRiverBuild(riverID);
```

⚠️ **CRITICAL RULE: 50% Ocean Water Dominance**

The invisible landmass should be **only as big as the grouping**. If the river water type covers more than 50% of the visible area, it becomes dominant and its beach textures will override everything, breaking the seamless appearance. The ocean water must remain the dominant water type visually.

---

##### **Step 5: Place Capturable Trade Sockets (Optional)**

Capturable trade sockets never work as part of groupings - they must be placed separately.

```cpp
int harbour01ID = rmCreateObjectDef("harbour");
rmAddObjectDefItem(harbour01ID, "zpTradingPostCaptureNavalOriental", 1, 0.0);
rmSetObjectDefTradeRouteID(harbour01ID, tradeRouteID);  // Link to trade route
rmSetObjectDefAllowOverlap(harbour01ID, true);
rmSetObjectDefMinDistance(harbour01ID, 0.0);  // Precise positioning
rmSetObjectDefMaxDistance(harbour01ID, 0.0);
rmPlaceObjectDefAtLoc(harbour01ID, 0, 0.15+rmXTilesToFraction(7), 0.5+rmXTilesToFraction(13));

// Get location for grouping placement
vector harbourLoc1 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(harbour01ID, 0));
```

---

##### **Step 6: Place the Grouping ("Bridge"/Floating Island)**

The grouping placement acts as a "bridge" on the river, but because it has terrain height data, it appears as a floating island.

```cpp
int istanbulEurope = rmCreateGrouping("istanbul europe", "Istanbul_AS");
rmSetGroupingMinDistance(istanbulEurope, 0.00);
rmSetGroupingMaxDistance(istanbulEurope, 0.01);
rmAddGroupingToClass(istanbulEurope, rmClassID("classPlateau"));

// Special placement method for city states (optional - allows trigger access)
int istanbulInstanceID1 = rmPlaceGroupingInstanceAtLoc(
    istanbulEurope, 
    rmXMetersToFraction(xsVectorGetX(ControllerLoc1)) + rmXTilesToFraction(8), 
    rmZMetersToFraction(xsVectorGetZ(ControllerLoc1)) + rmZTilesToFraction(15), 
    0
);
```

---

##### **Step 7: Place Continent and Connect to Island**

The continent must be constrained to avoid overflowing into the grouping terrain.

```cpp
// Define constraint to protect grouping terrain
int avoidCity = rmCreateTypeDistanceConstraint("avoid city", "AbstractWall", 7);

// Create continent
int northContinentID = rmCreateArea("north_continent");
rmSetAreaSize(northContinentID, 0.65, 0.65);
rmSetAreaCoherence(northContinentID, 0.65);
rmSetAreaMix(northContinentID, paintMix);

// Manual beach layers (shoreless water has no beaches)
rmAddAreaTerrainLayer(northContinentID, "carolinas\\ground_shoreline2_car", 0, 1);
rmAddAreaTerrainLayer(northContinentID, "carolinas\\ground_shoreline3_car", 1, 2);

rmSetAreaBaseHeight(northContinentID, 4);
rmSetAreaHeightBlend(northContinentID, 2);
rmSetAreaSmoothDistance(northContinentID, 50);
rmSetAreaObeyWorldCircleConstraint(northContinentID, false);

// Constraints
rmAddAreaConstraint(northContinentID, greatLakesConstraint);
rmAddAreaConstraint(northContinentID, avoidTradeRouteFar4);
rmAddAreaConstraint(northContinentID, avoidSocket);
rmAddAreaConstraint(northContinentID, avoidCity);  // CRITICAL: Protects grouping terrain

rmSetAreaLocation(northContinentID, 0.9, 0.5);
rmBuildArea(northContinentID);
```

---

##### **Step 8: Create Seamless Terrain Blending**

Terrain patches fill the gap between the grouping and continent, creating an invisible connection.

**Constraint Hierarchy (Critical):**
- `avoidCity` (larger distance 7) on continent → stops before grouping
- `avoidCityShort` (smaller distance) on patches → fills the gap
- `mediumGreatLakesConstraint` on patches → prevents overwriting beaches

```cpp
for (i = 0; < 2) {
    int patchID = rmCreateArea("patch " + i);
    rmSetAreaSize(patchID, rmAreaTilesToFraction(500), rmAreaTilesToFraction(500));
    rmSetAreaCoherence(patchID, 1.0);
    rmSetAreaMix(patchID, paintMix);
    
    // Constraint hierarchy creates seamless blend
    rmAddAreaConstraint(patchID, avoidCityShort);              // Shorter than continent
    rmAddAreaConstraint(patchID, mediumGreatLakesConstraint);  // Protects beaches
    rmAddAreaConstraint(patchID, avoidTradeRouteFar3);
    rmAddAreaConstraint(patchID, avoidCityState);
    
    // Position patches to connect grouping to continent
    if (i == 0) {
        if (PlayerNum == 2 || PlayerNum > 6) {
            rmSetAreaLocation(patchID, 0.2, 0.5 + rmZTilesToFraction(53));
            rmAddAreaInfluenceSegment(patchID, 0.2, 0.5 + rmZTilesToFraction(53), 0.22, 0.5 + rmZTilesToFraction(43));
            rmAddAreaInfluenceSegment(patchID, 0.16, 0.5 + rmZTilesToFraction(49), 0.2, 0.5 + rmZTilesToFraction(59));
        } else {
            rmSetAreaLocation(patchID, 0.2, 0.5 + rmZTilesToFraction(49));
            rmAddAreaInfluenceSegment(patchID, 0.16, 0.5 + rmZTilesToFraction(45), 0.2, 0.5 + rmZTilesToFraction(49));
            rmAddAreaInfluenceSegment(patchID, 0.2, 0.5 + rmZTilesToFraction(49), 0.22, 0.5 + rmZTilesToFraction(45));
        }
    } else {
        if (PlayerNum == 2 || PlayerNum > 6) {
            rmSetAreaLocation(patchID, 0.2, 0.5 - rmZTilesToFraction(44));
            rmAddAreaInfluenceSegment(patchID, 0.2, 0.5 - rmZTilesToFraction(44), 0.22, 0.5 - rmZTilesToFraction(40));
            rmAddAreaInfluenceSegment(patchID, 0.16, 0.5 - rmZTilesToFraction(40), 0.2, 0.5 - rmZTilesToFraction(44));
        } else {
            rmSetAreaLocation(patchID, 0.2, 0.5 - rmZTilesToFraction(47));
            rmAddAreaInfluenceSegment(patchID, 0.2, 0.5 - rmZTilesToFraction(47), 0.22, 0.5 - rmZTilesToFraction(43));
            rmAddAreaInfluenceSegment(patchID, 0.16, 0.5 - rmZTilesToFraction(43), 0.2, 0.5 - rmZTilesToFraction(47));
        }
    }
    
    rmBuildArea(patchID);
}
```

---

#### **Key Technical Rules**

1. **50% Water Dominance Rule:**
   - Ocean water must be visually dominant (>50% of area)
   - River must be minimal - just wide enough for grouping
   - If river dominates, its beach textures override everything

2. **Placement Order is Critical:**
   - Invisible landmass → Trade route → River → Grouping → Continent → Patches
   - Any deviation will likely fail

3. **Constraint Hierarchy for Blending:**
   - Large distance on continent stops it before grouping
   - Small distance on patches fills the gap
   - Water constraint protects beach textures

4. **Mysterious Stopper Requirement:**
   - Dummy object on trade route is required (reason unknown)
   - Without it, groupings won't spawn

---

#### **Complete Working Example**

See `randmaps/zpblacksea.xs` for full implementation across an entire map with multiple floating islands.

---

### **19.8 City Blocks (Advanced Technique)**

⚠️ **ADVANCED:** Urban maps use a coordinate grid system to create city blocks geometrically divided by streets, creating realistic urban layouts.

---

#### **The Concept**

City blocks use a predefined grid system where groupings (buildings) are placed at specific grid intersections. This creates the appearance of organized urban streets and blocks.

**Key Features:**
- Precise geometric layout
- Street spacing between blocks
- Support for single and multi-block buildings
- Randomization for variety

---

#### **1. City Block Sets**

Different architectural styles have their own block grouping sets:

| Block Set | Used On | Notes |
|-----------|---------|-------|
| **EU_*** | Paris map | European architectural style, standardized |
| **IT_*** | Florence map | Italian architectural style, standardized |
| **IS_*** | Istanbul map | Ottoman architectural style, standardized |
| **AZ_*** | Aztec City map | Special size format, different grid system |

**Standard Block Size:** 15x15 meters (validated from `EU_House_Block_01.xml` - `<width>15</width>` `<height>15</height>`)

**Multi-Block Buildings:**
- Some groupings span multiple blocks: 1x2, 2x2, etc.
- Length is always >30 meters (15m + 15m + street space)
- Require special grid positions (see `palaceZ1`, `palaceZ2` example)

⚠️ **Note:** EU_, IT_, and IS_ sets are mostly standardized. AZ_ blocks use a special size format and slightly different grid system.

---

#### **2. Grid System Setup**

The grid defines all possible building positions. Example from Paris map:

```cpp
//=================== Set up grid locations ===================

// Block X locations on BOTH sides of the river
// Left side (negative offset from center)
float locX1 = 0.5 - rmXTilesToFraction(27);
float locX2 = 0.5 - rmXTilesToFraction(43);
float locX3 = 0.5 - rmXTilesToFraction(59);
float locX4 = 0.5 - rmXTilesToFraction(75);
float locX5 = 0.5 - rmXTilesToFraction(92);
float locX6 = 0.5 - rmXTilesToFraction(109);

// Right side (positive offset from center)
float locXm1 = 0.5 + rmXTilesToFraction(27);
float locXm2 = 0.5 + rmXTilesToFraction(43);
float locXm3 = 0.5 + rmXTilesToFraction(59);
float locXm4 = 0.5 + rmXTilesToFraction(75);
float locXm5 = 0.5 + rmXTilesToFraction(92);
float locXm6 = 0.5 + rmXTilesToFraction(109);

// Block Z locations (vertical positions)
float locZ0 = 0.94;
float locZ1 = 0.851;
float locZ2 = 0.755;
float locZ3 = 0.66;
float locZ4 = 0.57;
float locZ5 = 0.45;
float locZ6 = 0.35;
float locZ7 = 0.25;
float locZ8 = 0.15;
float locZ9 = 0.06;

// Special positions for multi-block buildings (e.g., palace 1x2)
float palaceZ1 = 0.615;  // Multi-block position 1
float palaceZ2 = 0.4;    // Multi-block position 2
```

**Grid Pattern:**
- Symmetrical around center (0.5, 0.5)
- X-axis: Offsets in tiles (27, 43, 59, 75, 92, 109)
- Z-axis: Absolute fraction values (0.06 to 0.94)
- Creates ~16 tiles spacing between blocks (street width)

---

#### **3. Define City Block Groupings**

```cpp
// Park block example
int blockPark = rmCreateGrouping("park", "EU_House_Block_Park");
rmSetGroupingMinDistance(blockPark, 0.00);
rmSetGroupingMaxDistance(blockPark, 0.50);
rmAddGroupingToClass(blockPark, rmClassID("classBlock"));

// Factory block example
int blockFactory = rmCreateGrouping("factory", "EU_House_Block_Factory");
rmSetGroupingMinDistance(blockFactory, 0.00);
rmSetGroupingMaxDistance(blockFactory, 0.50);
rmAddGroupingToClass(blockFactory, rmClassID("classBlock"));
```

**Best Practice:** Add all blocks to `classBlock` class for constraint management.

---

#### **4. Place Grouping at Grid Position**

Simple placement at a specific grid intersection:

```cpp
// Place park at grid position (locX2, locZ4)
rmPlaceGroupingAtLoc(blockPark, 0, locX2, locZ4);

// Place factory at grid position (locXm3, locZ1)
rmPlaceGroupingAtLoc(blockFactory, 0, locXm3, locZ1);
```

This creates a predictable, geometric urban layout.

---

#### **5. Grouping Randomization (Very Advanced)**

##### **A) Simple Randomization**

Randomly swap positions between two blocks:

```cpp
// Random variation variable (set earlier in script)
int verticalVariation = rmRandInt(1, 2);

// Swap factory positions based on random variation
if (verticalVariation == 1) {
    int factoryPlacement1 = rmPlaceGroupingInstanceAtLoc(blockFactory, locX3, locZ8, 0);
    int factoryPlacement2 = rmPlaceGroupingInstanceAtLoc(blockFactory, locXm3, locZ1, 0);
} else {
    factoryPlacement1 = rmPlaceGroupingInstanceAtLoc(blockFactory, locX3, locZ1, 0);
    factoryPlacement2 = rmPlaceGroupingInstanceAtLoc(blockFactory, locXm3, locZ8, 0);
}
```

**Effect:** Same blocks, different positions each game.

---

##### **B) Full Randomization**

Use grouping arrays to randomize WHICH buildings appear at each grid position.

**Example Structure:**
1. Define arrays of possible groupings for each position
2. Randomly select from array for each grid cell
3. Ensures variety while maintaining urban structure

**Working Examples:**
- `randmaps/zpflorence.xs` - Simpler randomization system
- `randmaps/zpparis.xs` - More advanced randomization with arrays

**Key Pattern:**
```cpp
// Define array of possible blocks for a position
string blockOptions[] = {
    "EU_House_Block_Residential1",
    "EU_House_Block_Residential2",
    "EU_House_Block_Shop1",
    "EU_House_Block_Park"
};

// Random selection
int randomIndex = rmRandInt(0, 3);
int randomBlock = rmCreateGrouping("block", blockOptions[randomIndex]);
rmPlaceGroupingAtLoc(randomBlock, 0, locX2, locZ4);
```

---

#### **Key Technical Rules**

1. **Grid Consistency:**
   - All blocks must align to grid positions
   - Street spacing is critical (typically ~16 tiles)
   - Multi-block buildings need special grid positions

2. **Symmetry:**
   - Most urban maps are symmetrical around center
   - Use mirror positions (locX vs locXm) for balance

3. **Block Classification:**
   - Always add blocks to `classBlock` class
   - Allows constraint-based spacing rules

4. **Randomization Levels:**
   - None: Static city (testing)
   - Simple: Position swaps (variety)
   - Full: Building type selection (maximum variety)

---

#### **Complete Working Examples**

- `randmaps/zpparis.xs` - Full urban grid with advanced randomization
- `randmaps/zpflorence.xs` - Simpler grid system, easier to understand
- Base game `paris.xs` - Original implementation (if accessible)

[↑ Back to Table of Contents](#2--table-of-contents)

---

## **20.** 🎯 Map Triggers

**Triggers** enable dynamic gameplay events, tech activation, and politician systems on your maps.

### **When to Use Triggers**

- ✅ Activating starting technologies for all players
- ✅ Enabling consulate politicians (Asian civilizations, pirates, etc.)
- ✅ Assigning random leaders/captains to AI players
- ✅ Creating timed events or conditional gameplay
- ✅ Balancing civilization-specific features

### **Trigger Reference Files**

| File | Purpose |
|------|---------|
| **`data/trigger/triggerdata.xml`** | Complete trigger definitions (effects, conditions, parameters) |
| **`data/techtreemods.xml`** | Technology definitions and availability by region |
| **[docs/map_trigger_guide.md](map_trigger_guide.md)** | **Complete trigger implementation guide** ⭐ |

### **Quick Trigger Example**

```cpp
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

### **📚 For Complete Trigger Documentation**

See **[Map Trigger Guide](map_trigger_guide.md)** for:
- Starting tech activation
- Universal consulate setup (Japan, China, India, Pirates)
- AI leader/captain selection
- Regional pirate variants (Mediterranean, Baltic, Australia)
- Supporting triggers (Italian balance, research speed)
- Complete working examples
- Best practices and troubleshooting

**See also:**
- [Chapter 12: Reference Documentation](#12--reference-documentation) - Technology and trigger file references
- [Chapter 6: Finding Object Names](#6--finding-object-names) - Locating trigger and tech names

[↑ Back to Table of Contents](#2--table-of-contents)

---

## **21.** 📞 Troubleshooting

### **21.1. 🚨 Map Crashes on Load (Critical Errors)**

These errors prevent the map from loading and will crash the game.

---

#### **🔄 AI Agent Recovery Protocol for Critical Errors**

**When a map fails to load with a critical error:**

1. **Ask the user:** "Did the previous version (before my latest edits) work correctly?"

2. **If user says YES:**
   - Automatically create a backup of the current broken version
   - Ask: "Would you like me to:
     - A) Restore the map from the backup (working version)
     - B) Troubleshoot the current version manually"

3. **If user chooses A (Restore):**
   - Copy the `.backup` file back to the main file
   - Explain what was reverted
   - Suggest testing the restored version

4. **If user chooses B (Troubleshoot):**
   - Analyze the recent changes
   - Identify likely causes (undefined variables, syntax errors, etc.)
   - Propose specific fixes

**Example workflow:**
```
User: "The map crashes on load!"

AI: "Did the previous version (before my latest edits) work correctly?"

User: "Yes"

AI: [Creates backup]
    "I've created a backup of the current version.
     Would you like me to:
     A) Restore from the working backup
     B) Troubleshoot the current version manually"

User: "A"

AI: [Restores backup]
    "Restored the working version. The issue was likely in the pirate 
     placement code I just added. Would you like me to try a different 
     approach?"
```

**⚠️ CRITICAL:** Always create a backup BEFORE attempting fixes, so the working version is preserved.

---

#### **❌ Undefined Variable**

**Problem:** Using a variable that was never declared.

**Example:**
```cpp
// ❌ WRONG - avoidBlock is never defined
rmAddObjectDefConstraint(mineID, avoidBlock);
```

**Fix:** Ensure all variables are defined before use:
```cpp
// ✅ CORRECT - Define constraint first
int avoidBlock = rmCreateClassDistanceConstraint("avoid block", classBlock, 5.0);
rmAddObjectDefConstraint(mineID, avoidBlock);
```

---

#### **❌ Same Variable Defined Twice**

**Problem:** Declaring the same variable multiple times causes a compilation error.

**Example from zpblacksea.xs:**

```cpp
// ✅ BEST PRACTICE - Define variable BEFORE conditions
int riverID = -1;  // Defined once at the top

if (cNumberNonGaiaPlayers == 3 || cNumberNonGaiaPlayers == 4)
    riverID = rmRiverCreate(-1, seaType2, 4, 4, 72, 72);
else if (cNumberNonGaiaPlayers == 5 || cNumberNonGaiaPlayers == 6)
    riverID = rmRiverCreate(-1, seaType2, 4, 4, 75, 75);
// Variable already exists, just reassigning value ✅
```

```cpp
// ⚠️ VALID but harder to read - Define in first if only
if (cNumberNonGaiaPlayers == 3 || cNumberNonGaiaPlayers == 4)
    int riverID = rmRiverCreate(-1, seaType2, 4, 4, 72, 72);  // First if has "int"
else if (cNumberNonGaiaPlayers == 5 || cNumberNonGaiaPlayers == 6)
    riverID = rmRiverCreate(-1, seaType2, 4, 4, 75, 75);  // No "int" - reusing variable
// This works but is confusing to read
```

```cpp
// ❌ WRONG - Variable defined twice = CRASH!
if (cNumberNonGaiaPlayers == 3 || cNumberNonGaiaPlayers == 4)
    int riverID = rmRiverCreate(-1, seaType2, 4, 4, 72, 72);  // Defined with "int"
else if (cNumberNonGaiaPlayers == 5 || cNumberNonGaiaPlayers == 6)
    int riverID = rmRiverCreate(-1, seaType2, 4, 4, 75, 75);  // ERROR: "int" again!
// Causes map loading error or game crash!
```

**Fix:** Only define the variable once at the beginning of the function or code block.

---

#### **❌ Missing `rmTerrainInitialize()`**

**Problem:** Map lacks base terrain initialization.

**Fix:** Add immediately after `rmSetMapSize()`:
```cpp
rmSetMapSize(size, size);
rmTerrainInitialize("water");  // or "grass", etc.
```

---

#### **❌ Invalid Syntax**

**Problem:** Using incorrect or untested XS syntax patterns.

**Fix:**
1. Check [XS Documentation](https://aoe3mc.github.io/ai-guide/xs/) for correct syntax
2. Compare with working map scripts in `randmaps/` folder
3. **Always inform user** if using a new pattern not found in existing maps
4. Avoid inventing new patterns - stick to proven examples

**Common syntax errors:**
```cpp
// ❌ WRONG - Missing variable name in comparison
for(i=1; <=cNumberPlayers; i++)
//       ↑ Says "less than or equal" but doesn't say WHAT to compare!

// ✅ CORRECT - Need "i<" to compare i with cNumberPlayers
for(i=1; i<cNumberPlayers; i++)
//       ↑ Now it says "while i is less than cNumberPlayers, increment i"
```

---

#### **❌ Invalid Array Syntax**

**Problem:** Using C-style array declaration `type name[] = {...}` which XS doesn't support.

**Example of crash:**
```cpp
// ❌ WRONG - XS doesn't support this array syntax!
string playerTerrains[] = {"great plains grass", "carolina grass", "italy grass", "texas grass"};
int randomTerrain = rmRandInt(0, 3);
rmSetAreaMix(playerID, playerTerrains[randomTerrain]);  // CRASH!
```

**Fix:** Use if/else chains instead:
```cpp
// ✅ CORRECT - Use conditional statements
int randomTerrain = rmRandInt(1, 4);
if (randomTerrain == 1)
   rmSetAreaMix(playerID, "great plains grass");
else if (randomTerrain == 2)
   rmSetAreaMix(playerID, "carolina grass");
else if (randomTerrain == 3)
   rmSetAreaMix(playerID, "italy grass");
else
   rmSetAreaMix(playerID, "texas grass");
```

**Note:** While XS technically supports arrays in some contexts, the `type name[] = {...}` initialization syntax is NOT supported and will crash the map. Always use patterns found in existing map scripts.

**⚠️ EXPERIMENTAL CODE RULE:** If you use any code pattern not found in:
- [XS Documentation](https://aoe3mc.github.io/ai-guide/xs/)
- Existing map scripts in `randmaps/` folder

Always mark it with a comment: `// EXPERIMENTAL - may cause crashes`

---

#### **🔍 Cooperative Debugging with Comments**

When a map fails to load and the issue isn't immediately obvious, use **comment-based debugging** to isolate the problem.

**Comment Syntax in XS:**

```cpp
// Single-line comment - everything after // is ignored

/* Multi-line comment
   Everything between /* and */ is ignored
   Can span multiple lines
*/

/* Block comment for large sections
for(i=0; <10) {
    int someID = rmCreateArea("test");
    rmBuildArea(someID);
}
*/
```

**⚠️ CRITICAL SYNTAX RULE:** 
- Closing comment must be `*/` NOT `*/"` or `*/ "` 
- Extra characters after `*/` will cause syntax errors!

---

**Cooperative Debugging Workflow:**

**1. User Requests Comment-Out**

When the user says "comment out the recently added code" or "comment out section X":

```
User: "Comment out the pirate placement code"

AI: [Wraps code in /* ... */]
    [Restores previous working code]
    [Labels: "COMMENTED OUT - [reason]"]
```

**2. AI Sees User Comments**

When the AI detects user has commented out code:

```cpp
/* User commented this out
int pirateVillageID = rmCreateGrouping(...);
rmPlaceGroupingAtLoc(...);
*/
```

**⚠️ AI RULE:** Do NOT remove or uncomment user's comments until the issue is fixed and user confirms the map works!

**3. Binary Search Debugging**

When user says "the map works with section X commented out":

```
User: "Map works when pirate code is commented out"

AI: "The issue is in the pirate placement section. Let me analyze 
     that specific code block rather than the whole file."
     
     [Examines only the problematic section]
     [Identifies specific line causing crash]
     [Proposes targeted fix]
```

**DO NOT** browse through the entire document - focus on the commented section!

---

**Example Debugging Session:**

```
User: "Map crashes on load!"

AI: "Did the previous version work?" [Recovery Protocol]

User: "Yes, before you added the Balearic Islands pattern"

AI: [Comments out Balearic pattern]
    [Restores simple placement]
    "Try this version. Does it load?"

User: "Yes, it loads now"

AI: "The issue is in the Balearic Islands code. Let me check 
     that specific section..."
     
     [Analyzes only lines 295-353]
     [Finds: missing variable declaration]
     
     "Found it! Line 297 uses variable 'k' but it's not declared.
      Should I add 'int k=0;' before the loop?"

User: "Yes"

AI: [Fixes the specific issue]
    [Uncomments the working code]
    "Fixed. The Balearic pattern should work now."
```

---

**Best Practices:**

✅ **DO:**
- Comment out large sections to isolate problems
- Keep commented code for reference
- Label commented sections clearly
- Focus debugging on the commented section only
- Wait for user confirmation before uncommenting

❌ **DON'T:**
- Remove user's comments during debugging
- Uncomment code until issue is confirmed fixed
- Browse entire file when problem is isolated
- Delete commented code (keep for reference)
- Add extra characters after `*/`

---

**Common Comment Patterns:**

```cpp
// Temporary disable for testing
/* 
int problematicCode = ...;
*/

// COMMENTED OUT - Causes crash, investigating
/*
for(i=0; <10) {
    // ... code ...
}
*/

// COMMENTED OUT - Balearic Islands pattern (kept for reference)
/*
// Original implementation
for(k=0; <2) {
    // ... code ...
}
*/
```

---

### **21.2. ⚠️ Content Doesn't Spawn (Very serious but not Critical Issues)**

These errors don't crash the map but content won't appear in-game. The game typically uses fallback/default values.

**Root cause:** Usually undefined string names (not in reference files).

---

#### **⚠️ Invalid Water Type Name**

**Problem:** Water type not defined in either water file → water area doesn't spawn or uses fallback.

**Example:**
```cpp
// ❌ May not exist
rmSetSeaType("Mediterranean Sea");
```

**Fix:** Search BOTH water files:
```bash
# Check mod file FIRST:
grep "name=" data/waterbodies2.xml | grep -i "mediterranean"

# Then check base game:
grep "name=" scripts/source/waterbodies.xml | grep -i "mediterranean"
```

Use exact name from `name=` attribute:
```cpp
// ✅ Use exact name found
rmSetSeaType("ZP Mediterranean");
```

**Reference:** [Chapter 12: Reference Documentation](#12--reference-documentation)

---

#### **⚠️ Invalid Terrain Mix Name**

**Problem:** Terrain mix not in `art/terrain/mix/` folder → area uses base terrain as backup.

**Fix:** List available terrain mixes:
```bash
ls scripts/source/art/terrain/mix/ | grep -i "italy"
```

Use exact filename WITHOUT `.xml`:
```cpp
// ❌ WRONG
rmSetAreaMix(areaID, "Italian Grass");

// ✅ CORRECT - exact filename without .xml
rmSetAreaMix(areaID, "italy_grass");
```

**Reference:** [Chapter 12.4: Terrain Mixes](#124-terrain-mixes)

---

#### **⚠️ Invalid Terrain Type Name**

**Problem:** Terrain type not defined in terrain type files → terrain doesn't appear.

**Fix:** Check terrain type files:
```bash
# Mod terrain types:
grep "name=" data/terraintypes2.xml | grep -i "[terrain name]"

# Base game terrain types (multiple files):
grep "name=" scripts/source/art/terrain/terraintypes.xml
grep "name=" scripts/source/art/terrain/terraintypes2.xml
grep "name=" scripts/source/art/terrain/terraintypes3.xml
```

Use exact name from `name=` attribute:
```cpp
// ✅ Use exact name
rmSetAreaTerrainType(areaID, "lava\\volcano_dirt");
```

**Terrain type file locations:**
- Mod: `data/terraintypes2.xml`
- Base game: `scripts/source/art/terrain/terraintypes*.xml` (multiple files)

**Reference:** [Chapter 12.3: Terrain Types](#123-terrain-types)

---

#### **⚠️ Invalid Native Civ ID**

**Problem:** Native civ not defined in civ files → natives can't be used by players (not properly initialized).

**Fix:** Check civilization files:
```bash
# Mod civs (check FIRST):
grep "name=" data/civmods.xml | grep -i "pirate"

# Base game civs:
grep "name=" scripts/source/civs.xml | grep -i "aztec"
```

Use exact subciv name:
```cpp
// ✅ Correct format
subCiv0 = rmGetCivID("natpirates");
if (subCiv0 >= 0)
    rmSetSubCiv(0, "natpirates");
```

**Reference:** [Chapter 12.6: Native Civilizations](#126-native-civilizations)

---

#### **⚠️ Invalid Object Name**

**Problem:** Object not defined in proto files → object doesn't spawn, game uses backup/default.

**Fix:** Check proto files:
```bash
# Mod objects (check FIRST):
grep "name=" data/protomods.xml | grep -i "whale"

# Base game objects:
grep "name=" scripts/source/protoy.xml | grep -i "deer"
```

Use exact proto name:
```cpp
// ✅ Use exact proto name
rmAddObjectDefItem(huntID, "deer", 8, 4.0);
rmAddObjectDefItem(fishID, "FishMahi", 3, 8.0);
```

**Reference:** [Chapter 12.1: Units and Buildings](#121-units-and-buildings-protoyxml)

---

#### **⚠️ Invalid Grouping Name**

**Problem:** Grouping not defined in grouping files → grouping doesn't spawn.

**Fix:** Check grouping folders:
```bash
# Base game groupings:
ls Game/RandMaps/groupings/ | grep -i "pirate"

# Mod groupings:
ls <MOD_WORKSPACE>/randmaps/groupings/ | grep -i "scientist"
```

Use exact grouping name:
```cpp
// ✅ Use exact grouping name
int piratesID = rmCreateGrouping("pirates", "pirate_village02");
int scientistsID = rmCreateGrouping("scientists", "scientist_lab01");
```

**Grouping file locations:**
- Base game: `Game/RandMaps/groupings/*.xml`
- Mod: `<MOD_WORKSPACE>/randmaps/groupings/*.xml`

**Reference:** [Chapter 19: Groupings](#19-️-groupings-native-villages-city-states-decorative-structures)

---

#### **⚠️ Spawn on Impossible Location**

**Problem:** Objects/groupings don't spawn because they're placed on unsupported terrain or invalid locations.

**Common causes:**

##### **1. Land Objects (or grouping) on Water**

**Scenario:** Small player islands on water map

```cpp
// Define player island (small landmass in center)
int islandID = rmCreateArea("player island");
rmSetAreaSize(islandID, rmAreaTilesToFraction(3000), rmAreaTilesToFraction(3000));
rmSetAreaLocation(islandID, 0.1, 0.5);  // South-West
rmSetAreaWaterType(islandID, "ZP Black Sea Lagoon");
rmSetAreaBaseHeight(islandID, 2.0);
rmSetAreaMix(islandID, "great plains grass");
rmAddAreaToClass(islandID, classIsland);
rmBuildArea(islandID);
```

**❌ WRONG - Deers spawn outside island (on other side of map in water):**
```cpp
// No terrain constraint! Deers may spawn anywhere on map
int deerID = rmCreateObjectDef("deer");
rmAddObjectDefItem(deerID, "deer", 8, 4.0);
rmSetObjectDefMinDistance(deerID, 0.0);
rmSetObjectDefMaxDistance(deerID, 30); // max distance too short to cover the whole map
rmPlaceObjectDefAtLoc(deerID, 0, 0.9, 0.5); // north-east (there is no northIsland in there)
// Result: Deers try to spawn in water → Fail to spawn
```

**✅ CORRECT - Deers spawn in center of island:**
```cpp
// Place at correct location matching island position
int deerID = rmCreateObjectDef("deer");
rmAddObjectDefItem(deerID, "deer", 8, 4.0);
rmSetObjectDefMinDistance(deerID, 0.0);
rmSetObjectDefMaxDistance(deerID, 30.0);  // Search only nearby
rmPlaceObjectDefAtLoc(deerID, 0, 0.1, 0.5);  // Place at island center (matches island location!)
// Result: Deers spawn successfully in center of island
```

**Alternative solution - Use constraints with larger search area:**
```cpp
// Define constraints first
int stayOnIsland = rmCreateClassDistanceConstraint("stay on island", classIsland, -10.0);
int avoidWater = rmCreateTerrainDistanceConstraint("avoid water", "water", true, 8.0);

// Use constraints to keep deers ON the island even with large search area
int deerID = rmCreateObjectDef("deer");
rmAddObjectDefItem(deerID, "deer", 8, 4.0);
rmSetObjectDefMinDistance(deerID, 0.0);
rmSetObjectDefMaxDistance(deerID, rmXFractionToMeters(0.5));  // Can search entire map
rmAddObjectDefConstraint(deerID, avoidWater);    // Stay on land terrain!
rmAddObjectDefConstraint(deerID, stayOnIsland);  // Stay within island class!
rmPlaceObjectDefAtLoc(deerID, 0, 0.9, 0.5);  // Even placed far from island...
// Result: Constraints force spawn on island → Deers spawn successfully
```

**Key difference:**
- **Placement method:** Small search radius at correct location → Simple but requires precise placement
- **Constraint method:** Large search radius with terrain constraints → More flexible, works from any placement location

##### **2. Objects on Cliffs**

**Important:** Objects CAN spawn on cliff tops (flat elevated areas), but NOT on cliff edges (steep slopes).

**Scenario:** Circular cliff plateau

```cpp
// Create circular cliff plateau
int cliffID = rmCreateArea("cliff plateau");
rmSetAreaSize(cliffID, rmAreaTilesToFraction(2000), rmAreaTilesToFraction(2000));
rmSetAreaLocation(cliffID, 0.3, 0.3);  // Center of cliff
rmSetAreaBaseHeight(cliffID, 6.0);  // Elevated
rmSetAreaCliffType(cliffID, "ZP Smoky Mountain Cliff");
rmSetAreaCliffEdge(cliffID, 1, 1.0, 0.0, 0.0, 0);
rmSetAreaCliffHeight(cliffID, 6.0, 0.0, 0.5);
rmSetAreaMix(cliffID, "great plains grass");
rmBuildArea(cliffID);
```

**❌ WRONG - Grouping spawned on cliff edge:**
```cpp
// Placed at edge of cliff (0.35, 0.35 is near the edge of the circular cliff)
int villageID = rmCreateGrouping("native village", "native_village01");
rmSetGroupingMinDistance(villageID, 0.0);
rmSetGroupingMaxDistance(villageID, 0.0);
rmPlaceGroupingAtLoc(villageID, 0, 0.35, 0.35);  // Near cliff edge!
// Result: Spawns on steep slope → Won't place (impassable terrain)
```

**✅ CORRECT - Grouping spawned in middle of cliff:**
```cpp
// Placed at center of cliff plateau (flat area)
int villageID = rmCreateGrouping("native village", "native_village01");
rmSetGroupingMinDistance(villageID, 0.0);
rmSetGroupingMaxDistance(villageID, 0.0);
rmPlaceGroupingAtLoc(villageID, 0, 0.3, 0.3);  // Center of cliff plateau!
// Result: Spawns on flat cliff top → Success!
```

**Key difference:**
- **Edge placement:** Steep slope is impassable → Spawn fails
- **Center placement:** Flat elevated area is passable → Spawn succeeds

##### **3. Groupings on Trade Route Path**

**Important:** Groupings are MORE problematic than objects - they can't easily be moved by constraints!

**Scenario:** Circular trade route with waypoints

```cpp
// Create circular trade route
int tradeRouteID = rmCreateTradeRoute();
rmAddTradeRouteWaypoint(tradeRouteID, 0.5, 0.2);
rmAddTradeRouteWaypoint(tradeRouteID, 0.7, 0.35);
rmAddTradeRouteWaypoint(tradeRouteID, 0.8, 0.5);
rmAddTradeRouteWaypoint(tradeRouteID, 0.7, 0.65);
rmAddTradeRouteWaypoint(tradeRouteID, 0.5, 0.8);
rmBuildTradeRoute(tradeRouteID, "water");
```

**❌ WRONG - Grouping placed directly on trade route:**
```cpp
// Placed at trade route waypoint location!
int piratesID = rmCreateGrouping("pirates", "pirate_village02");
rmSetGroupingMinDistance(piratesID, 0.0);
rmSetGroupingMaxDistance(piratesID, 0.0);
rmPlaceGroupingAtLoc(piratesID, 0, 0.5, 0.2);  // This is waypoint location!
// Result: Grouping blocks trade route OR fails to spawn
```

**✅ CORRECT - Grouping placed away from trade route:**
```cpp
// Placed far from trade route path
int piratesID = rmCreateGrouping("pirates", "pirate_village02");
rmSetGroupingMinDistance(piratesID, 0.0);
rmSetGroupingMaxDistance(piratesID, 0.0);
rmAddGroupingConstraint(piratesID, avoidTradeRoute);  // Helps but may not always work
rmPlaceGroupingAtLoc(piratesID, 0, 0.1, 0.5);  // Far from trade route waypoints!
// Result: Grouping spawns successfully away from route
```

**Key difference:**
- **On route:** Grouping conflicts with trade route → Spawn fails or blocks route
- **Away from route:** Grouping has clear space → Success

**Note:** Unlike objects, groupings have fixed structures and can't easily adjust to constraints. **Always place groupings at locations you KNOW are clear of trade routes!**

**Key constraints for valid spawning:**
- **`avoidWater`** - Keep land objects on land terrain
- **`stayOnIsland`** / **`stayNearShore`** - Keep within defined land areas
- **`avoidImpassableLand`** - Avoid cliffs and impassable terrain
- **`avoidTradeRoute`** - Don't block trade route paths
- **`avoidPlayer`** - Don't spawn too close to player starting locations

**Debugging tip:** If objects don't spawn, check terrain type and add appropriate constraints!

---

#### **⚠️ Players Circular Issues**

**Problem:** Players don't spawn in circular placement, all appear bunched together in fallback location.

**Root cause:** Player placement conflicts with constraints, especially trade routes.

##### **Case Study: Circular Trade Route Conflict**

```cpp
// Trade route circle waypoints (creates circle at ~0.3 radius from center)
rmAddTradeRouteWaypoint(tradeRouteID, 0.5, 0.2);
rmAddTradeRouteWaypoint(tradeRouteID, 0.7, 0.35);
rmAddTradeRouteWaypoint(tradeRouteID, 0.8, 0.5);
rmAddTradeRouteWaypoint(tradeRouteID, 0.7, 0.65);
rmAddTradeRouteWaypoint(tradeRouteID, 0.5, 0.8);
// ... continues in circle
// Trade route passes through 0.2-0.8 range (radius ~0.3 from center 0.5, 0.5)

// ❌ WRONG - Players placed directly on trade route path!
rmPlacePlayersCircular(0.30, 0.30, 0.0);  // Places players at 0.3 radius = ON trade route!

// Player areas (objects) usually have constraint:
rmAddAreaConstraint(playerID, avoidTradeRouteFar);  // Must be 30 units away
// → Players spawn ON the trade route path!
// → Player areas can't build (violate avoidTradeRouteFar constraint)
// → Fallback spawn used → All players bunched together!

// ✅ CORRECT - Players outside trade route circle
rmPlacePlayersCircular(0.45, 0.45, 0.0);  // Safely outside trade route (0.45 > 0.3)
// Now player areas can build successfully
```

**How to calculate safe player placement:**

1. **Find trade route radius:**
   - Look at waypoint coordinates
   - Calculate distance from center (0.5, 0.5)
   - Example: waypoints at 0.2-0.8 range → radius ~0.3 from center

2. **Check constraint distances:**
   - `avoidTradeRoute` = typically 15.0 units
   - `avoidTradeRouteFar` = typically 30.0 units

3. **Place players either:**
   - **Inside:** Much closer to center (e.g., 0.10-0.15) if trade route is far out
   - **Outside:** Beyond constraint range (e.g., 0.40-0.45) if trade route is closer

**Warning signs of placement failure:**
- All players spawn in same corner/edge
- Players appear bunched together despite circular placement code
- Only some players spawn (others use fallback location)

**Solution:** Adjust player placement distance to avoid conflicting with:
- Trade route paths and constraints
- Water areas (if land-based players)
- Cliffs and impassable terrain
- Large central features (lakes, monuments, etc.)

---

### **21.3. ⚠️ Objects Appear in Wrong Locations**

**Problem:** Objects spawn in unexpected positions on the map.

⚠️ **COORDINATE TROUBLESHOOTING:** The XS coordinate system is rotated 45° from the visual minimap!

**Example Issue:**
- User requests "place on West side"
- You use `(0.0, 0.5)` (thinking X=0 is west)
- Objects appear on **Southwest** instead

**Fix:** Use correct coordinate mapping:
```cpp
// Visual West = Code Northwest
rmPlaceGroupingAtLoc(groupID, 0, 0.15, 0.85);  // Low X + High Z

// Visual North = Code Northeast  
rmPlaceGroupingAtLoc(groupID, 0, 0.85, 0.85);  // High X + High Z

// Visual East = Code Southeast
rmPlaceGroupingAtLoc(groupID, 0, 0.85, 0.15);  // High X + Low Z

// Visual South = Code Southwest
rmPlaceGroupingAtLoc(groupID, 0, 0.15, 0.15);  // Low X + Low Z
```

**Must read:** [Chapter 3: Understanding Coordinates](#3-️-understanding-coordinates-critical) for complete coordinate system explanation with diagrams.

---

### **21.4. 🔧 Debugging Workflow**

#### **For Map Crashes:**

1. **Check script syntax** - ensure all variables defined before use
   - Reference: [XS Documentation](https://aoe3mc.github.io/ai-guide/xs/) for correct syntax patterns
2. **Verify all names** against reference files (see Chapter 12)
3. **Comment out sections** - disable features one by one to isolate the problem:
   ```cpp
   // Comment out problematic areas to test
   // rmBuildArea(suspiciousArea);
   // rmPlaceGroupingAtLoc(groupID, 0, 0.5, 0.5);
   ```
   - Check [XS syntax documentation](https://aoe3mc.github.io/ai-guide/xs/) if unsure about correct patterns
4. **Compare to working map** - find similar map in `randmaps/` folder and copy patterns
5. **Start simple, add features gradually** - get basic map working first, then add complexity

#### **For Spawn Issues:**

1. **Verify all string names** exist in reference files (water, terrain, objects, groupings)
2. **Check constraints** - may be too restrictive (objects can't find valid placement)
3. **Test with fallbacks** - use generic names (`"water"`, `"grass"`) to isolate issue
4. **Increase placement attempts** - add more object counts or area tries
5. **Disable `rmSetAreaWarnFailure()`** - set to `false` to prevent failed area warnings

#### **Type Name Search Strategy:**

1. **Search by theme:**
   ```bash
   # For water types (search BOTH files!):
   grep -i "[map theme]" data/waterbodies2.xml  # Check mod first!
   grep -i "[map theme]" scripts/source/waterbodies.xml  # Then base game
   
   # For terrain mixes:
   ls scripts/source/art/terrain/mix/ | grep -i "[map theme]"
   
   # For objects:
   grep -i "[object type]" data/protomods.xml  # Mod first
   grep -i "[object type]" scripts/source/protoy.xml  # Base game
   ```

2. **If no match found:**
   - Use closest thematic alternative
   - Explain to user what names exist
   - Document the decision in map's `.md` file

3. **If user requests non-existent feature:**
   - Check if similar feature exists in working maps
   - Suggest closest alternative
   - Document what's technically possible

---

### **21.5. 💡 Generic Fallbacks (Always Work)**

When in doubt, use these safe defaults:
```cpp
rmSetSeaType("water");           // Always works
rmSetBaseTerrainMix("grass");    // Always works
rmSetLightingSet("texas");       // Generic outdoor lighting
```

---

### **21.6. 📋 Testing Checklist**

Before declaring map complete, verify all of the following:

**Essential Tests:**
- ✅ Map loads without crashing
- ✅ All players spawn correctly
- ✅ Starting units appear for all players
- ✅ Resources present and accessible (mines, huntables, berries)
- ✅ Natives spawn correctly (if included)
- ✅ Trade route appears correctly (if included)

**Visual/Terrain Tests:**
- ✅ Water appears at correct height/type
- ✅ Terrain looks appropriate for map theme
- ✅ No z-fighting or visual glitches
- ✅ Cliffs render properly (if included)
- ✅ Forests placed correctly (if included)

**Multiplayer Tests:**
- ✅ Test with different player counts (2, 4, 6, 8)
- ✅ Player starting positions are balanced
- ✅ Resource distribution is fair across all players

**Documentation:**
- ✅ Create matching `.xml` file with map metadata
- ✅ Create matching `.md` documentation file
- ✅ Document all custom types used (water, terrain, natives, etc.)

**See also:**
- [Chapter 12: Reference Documentation](#12--reference-documentation) - All type references
- [Chapter 6: Finding Object Names](#6--finding-object-names) - How to verify names exist
- [Chapter 10: Required Files](#10--required-files) - Complete file requirements

[↑ Back to Table of Contents](#2--table-of-contents)

---

## **22.** 🎯 Best Practices for AI Agents

⚠️ **COORDINATE SYSTEM WARNING:** Always reference Chapter 3 (Understanding Coordinates) when working with positions!

### **✅ DO:**

1. **Read Chapter 3 (Understanding Coordinates) before placing any objects:**
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
   ```cpp
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

4. **Don't use experimental/undocumented syntax:**
   - ❌ Array initialization: `string arr[] = {"a", "b", "c"};` (CRASHES!)
   - ❌ C-style for loops: `for(i=0; <10; i++)` (CRASHES! - XS doesn't support `i++`)
   - ❌ Any pattern not in XS docs or existing maps
   - ✅ **Correct XS for loop syntax:** `for(i=0; <10)` (no increment operator!)
   - ✅ If you must experiment, mark it clearly: `// EXPERIMENTAL - may cause crashes`
   - ✅ Test thoroughly before using in production maps
   - ✅ Use if/else chains instead of arrays
   
   **Example - C-style for loop error:**
   ```cpp
   // ❌ WRONG - Causes crash! (C-style increment)
   for(i=0; <3; i++)
   {
       int bonusID=rmCreateArea("bonus "+i);
       rmBuildArea(bonusID);
   }
   
   // ✅ CORRECT - XS syntax (no i++)
   for(i=0; <3)
   {
       int bonusID=rmCreateArea("bonus "+i);
       rmBuildArea(bonusID);
   }
   ```

5. **Don't forget both files:**
   - Must have `.xs` AND `.xml`

### **🚀 Quick Start Checklist**

**Before creating ANY new map:**

- [ ] ⚠️ **CRITICAL:** Read Chapter 3 (Understanding Coordinates) - understand 45° rotation!
- [ ] Read [rm_commands_reference.md](rm_commands_reference.md) (274 RM commands)
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

### **📊 Quick Reference: Type Categories**

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
```cpp
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

### **🔧 Step-by-Step Workflow**

⚠️ **BEFORE YOU START:** Read Chapter 3 (Understanding Coordinates) to understand coordinate rotation!

#### **Phase 1: Choose Base Map**

1. **User provides concept/image**

2. **Identify map layout pattern:**

| Pattern | Description | Key Techniques | Example Maps |
|---------|-------------|----------------|--------------|
| **Player Island** | Each player gets their own island | `rmSetAreaLocPlayer()` for individual islands | `zpphilippines.xs`, `Indonesia.xs`, `Hispaniola.xs` |
| **Team Island** | Teams share islands, players subdivided | `rmSetAreaLocTeam()` | `caribbean.xs` (2v2+), `game/randmaps/zpBalearicIslands.xs` (teams) |
| **Single Central Island** | One large central island (can also have an additional smaller bonus island) | `rmSetAreaLocation() with fixed coordinates`) | `game/randmaps/zpnewguinea.xs`, `game/randmaps/zpaustralia.xs`, `Borneo.xs` |
| **Players around Central Island** | Players around central island with player /team areas around it | Large central area (+ player areas via `rmSetAreaLocation() with fixed coordinates`) | `Ceylon.xs`, `game/randmaps/zpphiliphines.xs`, `game/randmaps/zpBalearicIslands.xs` |
| **Fixed Islands (N/S or E/W)** | Pre-positioned islands at cardinal directions + bonus islands | `rmSetAreaLocation()` with fixed coordinates | `game/randmaps/zptortuga.xs`, `amazonia.xs`, `game/randmaps/zpvenice.xs` (big/med/small islands) |
| **Water Trade Route** | Circular/path trade route on water with island(s) | `rmCreateTradeRoute()` + `"water_trail"` | `game/randmaps/zpphiliphines.xs`, `game/randmaps/zpmediterranean.xs` |
| **Land Trade Route** | Trade route crosses land areas | `rmCreateTradeRoute()` + `"dirt"` or `"road"` | `silkRoad.xs`, `great plains.xs` |
| **Central Lake** | Large lake in center, land around edges | Water terrain in center + land rim | `great lakes.xs` (Lake Michigan), `afLakeVictoria.xs`, `zpdeadsea.xs`, `zpeyrebasin.xs` |
| **River Map** | Major river(s) crossing the map | `rmRiverCreate()` with waypoints | `yellow river.xs`, `Orinoco.xs`, `Panama.xs` |
| **Archipelago** | Many small scattered islands | Multiple small areas with `rmCreateArea()` loops | `game/randmaps/zpmelanesia.xs`, `game/randmaps/zpmediterranean.xs`, `game/randmaps/zpkurils.xs` |
| **Mountain/Plateau** | Elevated terrain with cliffs | `rmSetAreaCliffType()` + `rmSetAreaBaseHeight()` | `Andes.xs`, `Rockies.xs`, `Himalayas.xs` |
| **Urban/Grid Layout** | City buildings in grid pattern | Groupings with city blocks | `randmaps/zpazteccity.xs`, `randmaps/zpparis.xs` |
| **Floating Islands** | Islands at different elevations (not on water) | Elevated `rmSetAreaBaseHeight()` with no water below | `randmaps/zpvenicecity.xs`, `randmaps/zpelbe.xs` |
| **Fake Water Areas** | Land constrained from invisible water | Water areas player can't see but constraints use | `randmaps/zpcivilwar.xs`, `randmaps/zpblacksea.xs` |

3. **Find similar working map:**
   - Match your concept to the pattern above
   - Choose a readable (non-encoded) reference map
   - **⚠️ Avoid:** Maps with `eu*` or `af*` prefix (encoded)
   
   **📁 Map Search Locations:**
   - `game/randmaps/` = Mod workspace maps (published Age of Pirates maps)
   - `randmaps/` = Local development maps (experimental/in-progress)
   - No prefix = Base game maps in `C:\Program Files (x86)\Steam\steamapps\common\AoE3DE\Game\RandMaps\`
   
4. **Verify map is readable (not encoded)**

#### **Phase 2: Copy & Verify**

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

#### **Phase 3: Modify Variables**

**⚠️ BEST PRACTICE: Define ALL type names as variables at the top of the file!**

**At top of `.xs` file, organize variables by category:**

```cpp
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

#### **Phase 4: Update Native Logic**

⚠️ **COORDINATE REMINDER:** When placing natives at specific locations, remember the 45° rotation!
- If user says "place on West", use low X + high Z (e.g., 0.2, 0.8)
- Review Chapter 3 (Understanding Coordinates) for details

**Find and replace native placement code:**
```cpp
// OLD (from base map):
subCiv0=rmGetCivID("caribs");
if (subCiv0 >= 0)
    rmSetSubCiv(0, "caribs");

// NEW (for your map):
subCiv0=rmGetCivID("Berbers");
if (subCiv0 >= 0)
    rmSetSubCiv(0, "Berbers");
```

#### **Phase 5: Test**

1. **Launch game**
2. **Create Skirmish game**
3. **Select your map (should be at top of list)**
4. **Load and check:**
   - Terrain renders correctly?
   - Players spawn?
   - Resources present?
   - Natives spawn?

#### **Phase 6: Document**

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


## **23.** 📖 Complete Example: Creating Balearic Islands

### **Bad Approach (what NOT to do):**
```cpp
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
```cpp
string seaType = "ZP Iceland";  // from waterbodies2.xml (mod file)
string baseMix = "italy_grass";  // Mediterranean region mix
string forestType = "Italian Forest";  // Mediterranean forest
```

**Step 4:** Update natives:
```cpp
subCiv0=rmGetCivID("Berbers");  // change from pirates
subCiv1=rmGetCivID("zpCorsairs");  // change from wokou
```

**Step 5:** Test immediately - map should load!

**Step 6:** Then iterate on details (island sizes, resources, etc.)

---

## **24.** 🔄 Example Tasks

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
   ```cpp
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
   ```cpp
   // BEFORE rotation:
   rmSetPlacementSection(0.15, 0.85);
   
   // AFTER 90° clockwise rotation (add 0.25 to both, wrap if >1.0):
   rmSetPlacementSection(0.40, 0.10);
   // Calculation: 0.15+0.25=0.40, 0.85+0.25=1.10→wraps to 0.10
   ```

3. **Fixed Object Positions**
   ```cpp
   // BEFORE rotation:
   rmPlaceObjectDefAtLoc(controllerID, 0, 0.54, 0.53);
   
   // AFTER rotation (swap X and Z):
   rmPlaceObjectDefAtLoc(controllerID, 0, 0.53, 0.54);
   ```

4. **Area Influence Segments**
   ```cpp
   // BEFORE rotation:
   rmAddAreaInfluenceSegment(bigIslandID, 0.4, 0.5, 0.5, 0.65);
   // Parameters: (areaID, startX, startZ, endX, endZ)
   
   // AFTER rotation (swap X↔Z in all positions):
   rmAddAreaInfluenceSegment(bigIslandID, 0.5, 0.4, 0.65, 0.5);
   ```

#### **❌ DO NOT Rotate (Automatic/Relative):**

1. **Player Island/Team Island Placement**
   ```cpp
   rmSetAreaLocPlayer(playerIslandID, i);  // ← Automatically follows player position
   rmSetAreaLocTeam(teamID, i);            // ← Automatically follows team position
   ```
   **Why:** These functions place areas wherever players spawned. Since players are rotated by `rmSetPlacementSection`, islands automatically follow.

2. **Direction-Based Grouping Logic**
   ```cpp
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
   ```cpp
   rmPlacePlayersCircular(0.29, 0.29, 0);  // ← Distance from center, not coordinates
   ```
   **Why:** This sets radius, not position. Players rotate via `rmSetPlacementSection`.

---

### **Step 2: Apply Rotations Systematically**

#### **A) Trade Route (Swap X and Z in all waypoints)**

```cpp
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
```cpp
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

```cpp
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
```cpp
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

```cpp
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
   ```cpp
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
   ```cpp
   rmSetAreaLocPlayer(playerIslandID, i);   // ← Don't change
   rmSetAreaLocTeam(teamID, i);             // ← Don't change
   ```
   **Why:** These APIs place areas at player/team locations, which are already rotated via `rmSetPlacementSection`.

3. **Distance/Radius Values**
   ```cpp
   rmPlacePlayersCircular(0.29, 0.29, 0);   // ← Don't change
   ```
   **Why:** This is a radius from center, not coordinates.

---

### **Step 4: Common Mistakes to Avoid**

#### **❌ MISTAKE 1: Double Rotation**

```cpp
// WRONG: Rotating both waypoints AND grouping logic
rmAddTradeRouteWaypoint(tradeRouteID, 0.5, 0.95);  // Rotated waypoint ✅

// Then also trying to rotate the grouping selection:
if ((dirToSocketX > 0) && (dirToSocketZ > 0)) {
   harbourGroupingID = rmCreateGrouping("harbour", "Harbour_Universal_E");  // ❌ WRONG!
}
```

**Why wrong:** You've rotated the physical position (waypoint) AND the logic. That's double rotation! The direction calculation adapts automatically to new positions.

**Correct approach:**
```cpp
// Rotate waypoints only
rmAddTradeRouteWaypoint(tradeRouteID, 0.5, 0.95);  // ✅

// Keep original grouping logic
if ((dirToSocketX > 0) && (dirToSocketZ > 0)) {
   harbourGroupingID = rmCreateGrouping("harbour", "Harbour_Universal_N");  // ✅
}
```

#### **❌ MISTAKE 2: Forgetting Player Placement Section**

```cpp
// Rotated trade route ✅
rmAddTradeRouteWaypoint(tradeRouteID, 0.5, 0.95);

// But forgot to rotate placement section ❌
rmSetPlacementSection(0.15, 0.85);  // Players in wrong position!
```

**Fix:** Add 0.25 to placement section values:
```cpp
rmSetPlacementSection(0.40, 0.10);  // ✅ Rotated 90° clockwise
```

#### **❌ MISTAKE 3: Only Rotating Some Waypoints**

```cpp
// Partially rotated - creates broken route ❌
rmAddTradeRouteWaypoint(tradeRouteID, 0.82, 0.82);
rmAddTradeRouteWaypoint(tradeRouteID, 0.5, 0.95);   // Rotated
rmAddTradeRouteWaypoint(tradeRouteID, 0.82, 0.18);  // NOT rotated - wrong!
```

**Fix:** Rotate ALL waypoints consistently.

#### **❌ MISTAKE 4: Swapping Wrong Parameters**

```cpp
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

## **25.** ⚠️ Unorganized Content (To Be Sorted)

### **Trigger Debugging (To be moved to Chapter 20 - Triggers)**

#### **⚠️ Console Output and Trigger Debugging in AoE3 DE**

**Note:** These methods are for **trigger debugging only**, not for random map script debugging.

**Problem:** Developer console (`modeTrack` in `game.cfg`) often doesn't show output in AoE3 DE.

**Alternative debugging methods for triggers:**

1. **Use `rmEchoInfo()` statements:**
   ```cpp
   // Add logging in trigger code
   rmEchoInfo("Starting player placement", 0);
   rmEchoInfo("Player count: " + cNumberNonGaiaPlayers, 0);
   rmEchoInfo("Created area: " + areaID, 0);
   ```
   
2. **Check `trigtemp.xs` file:**
   - Location: Generated in `My Documents\My Games\Age of Empires 3 DE\` when loading map with triggers in editor
   - Contains compiled trigger code
   - Useful for debugging trigger syntax errors
   - **Only works for triggers, not random map scripts**

3. **Test in Map Editor:**
   - Load your map in the Scenario Editor
   - Trigger errors may appear in editor interface
   - Faster iteration than launching full game

---

**This guide ensures AI agents create working, tested maps following Age of Pirates mod conventions.** 🗺️✅


