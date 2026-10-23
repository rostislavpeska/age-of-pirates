# Chapter 15 Trade Routes - Work Handoff Summary

## What Has Been Completed

### ✅ Completed Sections:

1. **Introduction** - Trade routes overview with file reference to `data/traderoutedefs.xml`
2. **Understanding Trade Route Positioning** - Explains blocksize snap grid and why waypoints don't align exactly
3. **A) Land Trade Routes** - Versailles example with dirt road, waypoints, stopper objects
4. **B) Water Trade Routes** - Black Sea example with player count variations (2-player vs 3+ player diamond shapes)
5. **C) Trade Socket Placement** - Framework with 4 subsections:
   - **C1) Simple Socket Placement** - Currently has PLACEHOLDER needing completion
   - **C2) Water Sockets on Platforms** - References uncategorized content, has basic explanation
   - **C3) Harbour Groupings** - Complete with Tortuga example, grouping explanation
   - **C4) Train Station Groupings** - Reserved placeholder
6. **Trade Route Best Practices** - Summary checklist completed

### ⚠️ Section Needing Work: **C1) Simple Socket Placement**

**Current State:** Placeholder with key concepts outlined

**What Needs to Be Added:**

#### **1. Philippines Example (Primary - Simple Water Map)**
**Source:** `game\randmaps\zpphilippines.xs` lines 481-504

```cpp
int socketID = rmCreateObjectDef("sockets to dock Trade Posts");
rmSetObjectDefTradeRouteID(socketID, tradeRouteID);
rmAddObjectDefItem(socketID, "SocketTradeRoute", 1, 0.0);
rmSetObjectDefAllowOverlap(socketID, true);
rmSetObjectDefMinDistance(socketID, 5.0);    // START 5m FROM WAYPOINT
rmSetObjectDefMaxDistance(socketID, 30.0);   // SEARCH UP TO 30m

vector socketLoc = rmGetTradeRouteWayPoint(tradeRouteID, 0.30);
rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

socketLoc = rmGetTradeRouteWayPoint(tradeRouteID, 0.75);
rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
```

**Key Points:**
- Philippines is a SIMPLE WATER MAP with basic island layout
- Uses `rmPlaceObjectDefAtPoint()` with extracted vector positions
- MinDistance = 5.0, MaxDistance = 30.0 (water route values)
- Works because islands are predictably distributed

#### **2. Balearic Islands FFA Example (Secondary - Complex Water Map)**
**Source:** Should reference Balearic Islands uneven teams/FFA gameplay
**Concepts:**
- Uses LARGER MaxDistance (40m+) for more complex island layouts
- Includes `avoidWater4` constraint
- Works for FFA/uneven teams where islands are distributed
- Does NOT work for 2v2 symmetric (needs platforms instead)

#### **3. Distance Parameter Guidelines Table**

| Route Type | MinDistance | MaxDistance | Reason |
|------------|-------------|-------------|--------|
| **Land routes** | 0.0 - 5.0 | 8.0 - 10.0 | Waypoints on stable land |
| **Simple water (Philippines)** | 5.0 | 30.0 | Basic island layout |
| **Complex water FFA** | 0.0 | 40.0 - 45.0 | Distributed islands |
| **Water 2v2 symmetric** | N/A | N/A | Use platforms instead |

#### **4. Explanation of Distance Parameters**
- `rmSetObjectDefMinDistance()` - Start search at this distance from waypoint
- `rmSetObjectDefMaxDistance()` - Maximum search radius
- Game searches in expanding circle from Min to Max until valid land found
- If no valid spot within MaxDistance, placement fails

#### **5. Why Water Routes Need Larger MaxDistance**
1. **Terrain uncertainty** - Waypoints may be 20-40m from island shores
2. **Island placement timing** - Route built first, islands placed after
3. **Player count effects** - More players = better island distribution = closer to waypoints

#### **6. When to Use Simple Placement**
- ✅ Land routes (MaxDistance 8-10m)
- ✅ Simple water maps (Philippines style, MaxDistance 30m)
- ✅ Complex water FFA/uneven (MaxDistance 40m+ with avoidWater)
- ⚠️ Water 2v2 symmetric (use platforms - C2 instead)

---

## User's Key Instructions

1. **User said:** "bad example... The maxdistance is not defined... Use Philippines example instead."
2. **User said:** "NOTE: You may use simple placement for naval trade sockets, but with caution. Philippines is a very basic map, so it's possible to do it there."
3. **User's edits showed:**
   - Removed stopper object code from examples (was creating noise)
   - Added route type upgrades (basic, upgrade 1, upgrade 2)
   - Added river trade routes and special types (lava_flow)
   - Noted sockets don't spawn at all (not just underwater) with wrong MaxDistance
   - Warning about MinDistance/MaxDistance being critical for water sockets

---

## File References for Next Agent

### **Files to Reference:**
1. **Philippines map:** `game\randmaps\zpphilippines.xs`
   - Lines 481-504: Socket placement with MinDistance/MaxDistance
   - Simple water map example
   
2. **Balearic Islands:** Look for pattern where it uses simple placement for uneven teams/FFA
   - Should have larger MaxDistance (40m+)
   - May include `avoidWater` constraint

3. **Current documentation:** `docs\random_map_generation_guide_v2.md`
   - Line ~4626: C1) Simple Socket Placement section (PLACEHOLDER)

### **Uncategorized Content Section:**
The document already has Pattern 2 (Sockets on Platforms) details in the uncategorized section at the bottom. C2 references this.

---

## Documentation Style Guide (From This Session)

### **Formatting Conventions:**
1. File references: `data/traderoutedefs.xml` format (not "modfolder/...")
2. Code blocks: Use `cpp` language identifier
3. Emojis: Use for visual aids (🌊🏝️⬛🏛️) in diagrams only
4. Tables: Use markdown tables for comparisons
5. Lists: Use ✅ ❌ ⚠️ 💡 for status indicators

### **Section Structure Pattern:**
1. Brief description
2. Code example with comments
3. "How it works" explanation
4. Comparison tables
5. "When to use" guidelines

### **Important Notes:**
- User edited route types to show upgrade levels (basic, upgrade 1, upgrade 2)
- User simplified water route player count explanation to focus on waypoint displacement
- User removed detailed stopper object code from examples (keeps examples clean)

---

## Task for Next Agent

**Primary Goal:** Complete section C1) Simple Socket Placement in Chapter 15

**Steps:**
1. Add Philippines example as PRIMARY example (lines 481-504 from zpphilippines.xs)
2. Add explanation of MinDistance=5.0, MaxDistance=30.0 for simple water maps
3. Add distance parameters table comparing land vs simple water vs complex water
4. Add "Why water needs larger MaxDistance" explanation (3 points)
5. Add Balearic Islands FFA example as SECONDARY showing MaxDistance 40m+ for complex water
6. Add "When to use simple placement" checklist
7. Ensure it flows with existing C2 (platforms) and C3 (harbour groupings)

**Key Message to Convey:**
"Simple socket placement CAN work on water routes IF:
- Map has basic/predictable island layout (Philippines: 30m)
- OR distributed islands (Balearic FFA: 40m+)
- BUT NOT on symmetric 2v2 (use platforms)"

**Files to Read:**
- `game\randmaps\zpphilippines.xs` (lines 481-504)
- Current placeholder at line ~4626 in guide

**Style:**
- Keep examples concise (user removed verbose stopper code)
- Focus on actual defined values from real maps
- Use tables for comparisons
- Include practical guidelines

---

## What User Wants to Achieve

The user wants to document that:
1. Simple socket placement is NOT just for land routes
2. It CAN work on water routes with proper MaxDistance values
3. Philippines (30m) and Balearic FFA (40m+) are real examples
4. But it has limits - 2v2 symmetric needs platforms
5. Distance parameters are CRITICAL and must be explained clearly

The goal is to teach map makers when they can use simple placement vs when they need platforms, based on map complexity and team configuration.
