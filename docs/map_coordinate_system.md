# Age of Empires III: Random Map Coordinate System

## 🎯 Critical Concept: 45° Rotation

**⚠️ IMPORTANT:** The XZ coordinate system used in `.xs` scripts is **rotated 45° from the visual minimap display!**

---

## Visual Representation

### Code Coordinates (Standard XZ Axes)
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

### Visual Minimap Display (Rotated 45° - Diamond Shape)
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

## Coordinate Mapping Table

### Corner Positions

| Code Name | Code Coordinates (X, Z) | Visual Map Direction | Description |
|-----------|------------------------|---------------------|-------------|
| **NE** (Northeast in code) | `(1.0, 1.0)` | **N** (North/Top) | High X, High Z → Top of diamond |
| **SE** (Southeast in code) | `(1.0, 0.0)` | **E** (East/Right) | High X, Low Z → Right of diamond |
| **SW** (Southwest in code) | `(0.0, 0.0)` | **S** (South/Bottom) | Low X, Low Z → Bottom of diamond |
| **NW** (Northwest in code) | `(0.0, 1.0)` | **W** (West/Left) | Low X, High Z → Left of diamond |

### Center Position
| Code Name | Code Coordinates (X, Z) | Visual Map Direction |
|-----------|------------------------|---------------------|
| **Center** | `(0.5, 0.5)` | **Center** |

---

## Understanding the Axes

### X-Axis (Horizontal in code)
- **X = 0.0** → Left side of code grid → **West + South** on visual map
- **X = 0.5** → Center horizontal
- **X = 1.0** → Right side of code grid → **East + North** on visual map

### Z-Axis (Vertical in code)
- **Z = 0.0** → Bottom of code grid → **South + East** on visual map
- **Z = 0.5** → Center vertical
- **Z = 1.0** → Top of code grid → **North + West** on visual map

---

## Practical Examples

### Example 1: Placing Object in Visual "North"
**Goal:** Place something at the top of the minimap (visual North)

**Code coordinates:** `(0.5, 1.0)` or nearby like `(0.6, 0.9)`
- High Z value (close to 1.0)
- Moderate X value (around 0.5)

```xs
float objectX = 0.5;
float objectZ = 0.9;  // High Z = visual North
rmPlaceObjectDefAtLoc(objectID, 0, objectX, objectZ);
```

### Example 2: Placing Object in Visual "West"
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

### Example 3: Balearic Islands Bonus Island Placement

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

## Quick Reference: Visual Direction → Code Coordinates

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

## Common Pitfalls

### ❌ Mistake: Using Cardinal Directions from Code Names
```xs
// This is code "NE" but visual "North"!
float x = 0.9;
float z = 0.9;
```

### ✅ Correct: Think in X/Z, Convert to Visual
```xs
// Want visual "West" (left side of minimap)?
// Use low X, high Z
float westX = 0.15;   // Low X value
float westZ = 0.85;   // High Z value
```

---

## Working with Players

### Player Descriptions vs Code Coordinates

When a player says:
- **"It's in the North"** → Look for **high Z** values (0.7-1.0), moderate X (0.4-0.6)
- **"It's in the South"** → Look for **low Z** values (0.0-0.3), moderate X (0.4-0.6)
- **"It's in the East"** → Look for **high X** values (0.7-1.0), moderate Z (0.4-0.6)
- **"It's in the West"** → Look for **low X** values (0.0-0.3), moderate Z or high Z (0.4-0.8)

---

## Testing Coordinates

### Method 1: Use Fixed Positions
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

### Method 2: Debug with Echo
```xs
rmEchoInfo("Placed at X: " + objectX + " Z: " + objectZ);
```

Check the in-game console or log files to see where objects actually placed.

---

## Summary

✅ **Key Takeaway:** The XZ coordinate system is rotated 45° from the visual minimap!

| To place in... | Use coordinates... |
|---------------|-------------------|
| **Visual North** | High Z (0.8-1.0), Mid X (0.4-0.6) |
| **Visual East** | High X (0.8-1.0), Mid Z (0.4-0.6) |
| **Visual South** | Low Z (0.0-0.2), Mid X (0.4-0.6) |
| **Visual West** | Low X (0.0-0.2), High Z (0.7-1.0) |

**Always think in terms of X and Z values, not cardinal directions from the code!**

---

## Related Files
- `docs/random_map_generation_guide.md` - Main random map guide
- `Game/RandMaps/000zpBalearicIslands.xs` - Example implementation
- `Game/RandMaps/000zpBalearicIslands.md` - Map-specific documentation

