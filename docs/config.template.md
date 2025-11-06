# Local Machine Configuration Template

**Instructions:** Copy this file to `config.local.md` and update the paths below with your actual file system paths.

**⚠️ IMPORTANT:** The `config.local.md` file is gitignored and will NOT be committed to the repository. This keeps your personal paths private.

---

## Path Variables

### BASE_GAME_PATH

**Description:** Your Age of Empires III: Definitive Edition installation folder

**Common Locations:**
- **Steam (Windows):** `C:\Program Files (x86)\Steam\steamapps\common\AoE3DE`
- **Microsoft Store (Windows):** `C:\Program Files\WindowsApps\Microsoft.AgeOfEmpires3DE_[version]`
- **Steam (Linux):** `~/.steam/steam/steamapps/common/AoE3DE`

**Your Path:**
```
C:\Program Files (x86)\Steam\steamapps\common\AoE3DE
```

**How to Find:**
1. Open Steam
2. Right-click Age of Empires III: DE
3. Properties → Installed Files → Browse
4. Copy the path

---

### MOD_WORKSPACE

**Description:** Your mod's root folder (for Age of Pirates, or your custom mod)

**Common Location:**
```
C:\Users\[YourUsername]\Games\Age of Empires 3 DE\[YourSteamID]\mods\local\[mod-name]
```

**For Age of Pirates, this contains:**
- `data/` - Mod-specific XML files
- `randmaps/` - Your random map scripts
- `docs/` - This documentation
- `game/` - Game overrides
- `scripts/` - Script files

**Your Path:**
```
C:\Users\[YourUsername]\Games\Age of Empires 3 DE\[YourSteamID]\mods\local\age-of-pirates
```

**How to Find:**
1. Open File Explorer
2. Navigate to: `%USERPROFILE%\Games\Age of Empires 3 DE`
3. Look for your Steam ID folder (numbers like `76561198347905238`)
4. Go to: `mods\local\age-of-pirates`
5. Copy the full path

---

### EXTRACTED_DATA_PATH

**Description:** Extracted base game XML files (data, art, sounds) from .bar archives

**⚠️ FALLBACK ONLY:** Use only when data cannot be found in `<MOD_WORKSPACE>/scripts/source/` or `<MOD_WORKSPACE>/data/`

**Purpose:** Reference files extracted from base game .bar archives for deep research

**Your Paths:**
```
Data:   C:\Users\[YourUsername]\Desktop\data
Art:    C:\Users\[YourUsername]\Desktop\art
Sounds: C:\Users\[YourUsername]\Desktop\sound
```

**When to use:**
- ✅ When data not found in mod workspace
- ✅ For deep research into base game mechanics
- ❌ NOT for regular map development (use mod workspace files instead)

---

### MODS_DIRECTORY

**Description:** Parent directory containing all mods (for reference and comparison)

**Purpose:** Access other mods to check interesting approaches or techniques

**Your Path:**
```
C:\Users\[YourUsername]\Games\Age of Empires 3 DE\[YourSteamID]\mods
```

**Contains:**
- `local/age-of-pirates/` - Your Age of Pirates mod
- `local/[other-mods]/` - Other local mods for reference

**Use case:** Analyzing other mods' solutions to similar problems

---

### LOCAL_GROUPINGS_PATH

**Description:** Local groupings folder (reference only)

**⚠️ CRITICAL:** These groupings can NEVER be used directly in RM scripts!

**Your Path:**
```
C:\Users\[YourUsername]\Games\Age of Empires 3 DE\[YourSteamID]\randmaps\groupings
```

**Purpose:** Reference only - can be copied into `<MOD_WORKSPACE>/game/randmaps/groupings/` for use

**Why it exists:** Testing area for groupings before adding to mod

---

### SOURCE_REPOS_PATH

**Description:** Directory containing cloned GitHub repositories and other sources

**Purpose:** Access to external repositories for reference or collaboration

**Your Path:**
```
C:\Users\[YourUsername]\[path-to-repos]
```

**Example:** `C:\Users\TIGO\source\repos` or `C:\Users\TIGO\GitHub`

---

## Quick Reference

**Example paths (update these with YOUR paths):**

| Variable | Example Path | Purpose |
|----------|-------------|---------|
| `<BASE_GAME_PATH>` | `C:\Program Files (x86)\Steam\steamapps\common\AoE3DE` | Base game installation |
| `<MOD_WORKSPACE>` | `C:\Users\TIGO\Games\...\age-of-pirates` | Your mod workspace |
| `<EXTRACTED_DATA_PATH>` | `C:\Users\TIGO\Desktop\data` | Fallback reference (data) |
| `<EXTRACTED_ART_PATH>` | `C:\Users\TIGO\Desktop\art` | Fallback reference (art) |
| `<EXTRACTED_SOUNDS_PATH>` | `C:\Users\TIGO\Desktop\sound` | Fallback reference (sounds) |
| `<MODS_DIRECTORY>` | `C:\Users\TIGO\Games\...\mods` | All mods (for comparison) |
| `<LOCAL_GROUPINGS_PATH>` | `C:\Users\TIGO\Games\...\randmaps\groupings` | Local groupings (reference only) |
| `<SOURCE_REPOS_PATH>` | `C:\Users\TIGO\GitHub` | Cloned repositories |

---

## Usage in Documentation

When you see paths like this in the guide:
```
<BASE_GAME_PATH>/scripts/source/waterbodies.xml
<MOD_WORKSPACE>/data/waterbodies2.xml
```

Replace with your actual paths:
```
C:\Program Files (x86)\Steam\steamapps\common\AoE3DE\scripts\source\waterbodies.xml
C:\Users\TIGO\Games\Age of Empires 3 DE\76561198347905238\mods\local\age-of-pirates\data\waterbodies2.xml
```

---

## For AI Assistants

### Initial Setup

When working with a user:

1. **Read config.local.md** if it exists (gitignored, contains user's actual paths)
2. **Save paths to memory** for the session
3. **Substitute placeholders** automatically in all file paths

### Search Priority (CRITICAL)

When looking for data files, **ALWAYS search in this order:**

1. **MOD CUSTOM CONTENT:** `<MOD_WORKSPACE>/data/` (Age of Pirates custom content)
2. **MOD REFERENCE FILES:** `<MOD_WORKSPACE>/scripts/source/` (pre-extracted base game reference)
3. **FALLBACK ONLY:** `<EXTRACTED_DATA_PATH>`, `<EXTRACTED_ART_PATH>`, `<EXTRACTED_SOUNDS_PATH>` (use ONLY when not found in 1 or 2)

**Example workflow:**
```
User asks: "Use Caribbean water"

Search order:
1. <MOD_WORKSPACE>/data/waterbodies2.xml → Found "ZP Caribbean Coast" ✅ USE THIS
2. If not found: <MOD_WORKSPACE>/scripts/source/waterbodies.xml → Found "caribbean" ✅ USE THIS
3. Last resort: <EXTRACTED_DATA_PATH>/waterbodies.xml → Fallback only
```

### Special Paths

**MODS_DIRECTORY:**
- Purpose: Compare with other mods when user asks "how does [other mod] handle this?"
- Never directly use in RM scripts

**LOCAL_GROUPINGS_PATH:**
- ⚠️ CRITICAL: Files here CANNOT be used directly in RM scripts!
- Purpose: Reference only - must be copied to `<MOD_WORKSPACE>/game/randmaps/groupings/` first
- Always warn user if they try to use these directly

**SOURCE_REPOS_PATH:**
- Purpose: Access cloned GitHub repositories
- Use when user references external projects

---

## Notes

- Use forward slashes `/` or double backslashes `\\` in code
- Avoid spaces in paths when possible
- Keep this template updated if new path variables are added
