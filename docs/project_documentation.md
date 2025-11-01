# Project Documentation

> **📋 FOR AI ASSISTANTS:** This document provides the complete Age of Pirates mod structure overview. When working on specific tasks, you MUST read the appropriate reference files listed in the "Quick Reference Index" section below. Do not attempt random map scripting without reading `all_rm_commands.txt`, AI modifications without reading `ai_reference.xs`, UI commands without reading `command_list.md`, or editing data XML files without reading `data_xml_guide.md`.

## About This Mod

The project can't be run as a standalone software. It's just a mod which needs to be plugged-in into the base game. That's why it also doesn't contain a complete base of units, techs animations and so on, because it works with the dependencies taken from the vanilla game.

The project folder contains:

1/ Mod folders (these are part of the plug-in mod for Age of Empires)
- art
- data
- game
- randmaps
- sound

2/ Non-mod folders - documentation, github files, modding tools
- docs
- scripts
- other files directly in the root folder

## Quick Reference Index

**When working on specific file types, consult these reference documents:**

### 🗺️ Random Map Development (`*.xs` map scripts)
- **📄 READ:** `docs/all_rm_commands.txt`
- **When:** Editing any `.xs` file in `randmaps/` or `game/randmaps/`
- **Contains:** 273 RM commands for terrain, areas, objects, connections, trade routes, triggers
- **Key functions:** `rmCreateArea()`, `rmPlaceObjectDefAtLoc()`, `rmAddAreaConstraint()`, `rmBuildConnection()`, `rmCreateTradeRoute()`, `rmPlacePlayersCircular()`
- **Must read before:** Creating new maps, modifying terrain generation, placing objects, setting up player locations

### 🤖 AI Development (`*.xs` AI scripts)
- **📄 READ:** `docs/ai_reference.xs`
- **When:** Modifying any file in `game/ai/`
- **Contains:** Complete XS scripting language reference (2,400+ lines)
- **Key topics:** Rules system, vectors, arrays, unit queries, resource management, military planning, naval AI functions
- **Key functions:** `xsEnableRule()`, `aiPlanCreate()`, `kbUnitQuery()`, `aiTaskUnitMove()`, `aiGetResourceAmount()`
- **Must read before:** Creating AI rules, querying units, managing resources, issuing unit commands

### ⌨️ UI Commands & Hotkeys (`protounitcommandmods.xml`)
- **📄 READ:** `docs/command_list.md`
- **When:** Adding custom commands or hotkeys to `data/protounitcommandmods.xml`
- **Contains:** UI command functions, unit selection commands, unit type names for queries
- **Key commands:** `uiFindIdleType()`, `trainInSelected()`, `doAbilityInType()`, `researchTechInSelected()`, `uiCreateNumberGroup()`
- **Unit types:** `AbstractInfantry`, `AbstractCavalry`, `LogicalTypeLandEconomy`, `AbstractWarShip`
- **Must read before:** Creating custom hotkeys, unit selection macros, training commands

### 📦 Proto/Tech/Civ Syntax (Data XML files)
- **📄 READ:** `docs/data_xml_guide.md`
- **When:** Editing `protomods.xml`, `techtreemods.xml`, `civmods.xml`, `*.tactics` files
- **Contains:** Complete XML syntax and structure for unit definitions, technologies, civilizations, unit behaviors (2,146 lines)
- **Key topics:** ProtoUnit attributes, Commands, Flags, Tech elements, Civ structure, Tactics actions
- **Must read before:** Creating new units, modifying unit properties, adding techs, configuring civilizations

---

## Naming convention
- new content is (very often but not all the time) using zp prefix for distinguishing the newly added content from the original game content. Some of these files have an "y" suffix but not all of them like f.e. civs.xml

## IDs and #DBIDs
- strings - starting from 300001 to avoid conflicts with the original game (some specific content added by another contributors is starting from 400001)
- protomods - starting from 20001 to avoid conflicts
- techtreemods - starting from 40001 to avoid conflicts

## Additive modding
- .XML files with the "mods" suffix are an addon to the base game files, containing additional stuff. Some important base game files can be found in scripts/source folder

## Mod Folders

### ART
- building and unit models, textures and animations
- file formats:
    - .XML - unit animation control file describing the usage of individual 3D models and animations. These files are used as an animation output for the protomods file where the specific unit or building is defined
    - .XMB - special AoE 3 format, basically compressed .XML or -XML based file
    - .GR2 - 3D models / 3D animations
    - .MATERIAL - defines which textures are used for a specific model. Needs to have same name as the model file
    - .DDT - textures
    - .PKFX - special effects
    - other possible XML based formats like .PARTICLE, .LGT and so on - usually describing some visual effects, impact effect etc...
- structure
    - animation_library - unit .GR2 animations
    - buildings (self-explanatory)
    - effects - definition of effects and particles
        - particlesets.xml - particles must be defined here so they can be used in unit's anim .XML file
    - homecity - homecity buildings - same functionality as buildings
    - lightsets - lightset definitions used in random map scripts
    - nuggets - prop 3d objects
    - objects - (self-explanatory)
        - flags - 2D pendant flags used other anim .xml files or protomopds.xml
    - popcornfx
        - special effects
    - terrain terrain and vegetation
        - terraintypes.xml - terrain (surface) types 
        - mix
            - .xml files defining terrain mixes used in random map scripts
    - war of the triple alliance - objects handed from another mod
    - WoL - objects handed from another mod


### DATA
- files in this folder define the main stuff like civilisations, units, technologies, unit abilities and so on. 
- file formats:
    - .XML - contains the code
    - .XMB - special AoE 3 format, basically compressed .XML or -XML based file 
    - .TACTICS - special XML based format used only in the tactics folder
    - .PNG - icons and other 2D images
    - .XAML - UI frontend definition
- syntax:
    - some files use the "MODS" suffix which means these files are just an addition on a top of the original file f.e.:
        - protoy.xml -> protomods.xml
        - techtreey.xml -> techtreemods.xml
    - files without the "mods" suffix contain also data from the original game
- structure:
    - abilities - contains unit abilities (abilitymods.xml) and ability definitions (powermods.xml)
    - placementrules - definition of special placement rules for specific buildings (always need to be assigned in protomods.xml)
    - strings - contain strings for different languages. The most up-to-date file is always english/stringmods.xml which contains all actual strings used by the mod
    - tactics - definition of unit behaviour like actions and tactics (currently activate set of actions)
    - trigger - set of conditions and effects defined in XML format which can be used by in the map editor or in a map script
    - wpfg 
        - .xaml UI files
        - resources - icons and other images
    - most important data files (directly in the data folder):
        - protomods.xml - definition of all newly added in-game units
        - civmods.xml - definition of all newly added civilisations
        - techtreemods-xml - new technologies
        - protounitcommandmods.xml - new special commands
            - **⚠️ AI MUST READ `docs/command_list.md` when working with UI commands and hotkeys**
            - Contains UI functions: uiFindIdleType(), trainInSelected(), doAbilityInType()
        - politicianmods.xml - additional definition for special techs using politician selection UI
        - unittypes.xml - abstract unit types used in protomods.xml
        - battle.xml - define battle formations
        - randomnamesmods.xml - if some unit like f.e. ship can have randomized name set, such set is defined here
        - unittransform.xml - the unit can't transform itself without a transformation being defined in this file

    -> The syntax of these .xml files is documented in docs/data_xml_guide.md

    - map related stuff
        - maptypemods - define spefific map types (used for random map scripts)
        - nuggetmods.xml - new nuggets (small treasures which are appearing on maps)
        - clifftype.xml - definition of cliff types used in editor or in random map scripts
        - waterbodies2.xml - water area (ocean/river/lake) types used in editor and random map scripts
        - traderoutedefs.xml - definition of trade route design and trade units
        - traderoutes.xml - definition of trade route rewards and trade route upgrades
        - ambienteffects.xml - define ambient effects for specific map type

    - other files:
        - tacticdisplay.xml - if the unit tactic is permanently displayed on the screen, such unit should be defined here
        - firepit.xml - special file defining firepit behaviour (zpAztecAltar)
        - gatheringplacedata.xml - defines settler behaviour around the firepit building (zpAztecAltar)
        - mapspecifictechmods - defines default techs for specific map types. Does not work well.
        - ui....xml - all files with UI prefix define UI for specific part of the map editor
        - homecity....xml - all files with homecity prefix define specific homecity and it's buildings and tech stack

### Randmaps
- random maps (are also contained in game/randmaps)
- this root randmaps file can accomodate more than 2 map related files, so it can contain also mods.xml files which are not supported while being placed in game/randmaps folder. Therefore all maps which need the third .mods.xml file are placed in the randmaps folder
- file formats
    - .xs - map script - the map itself using RM commands
        - **⚠️ AI MUST READ `docs/all_rm_commands.txt` when editing .xs map files**
        - Contains 273 functions: rmCreateArea(), rmPlaceObjectDef(), rmBuildConnection(), etc.
    - .xml - map metadata like name, description, map images or map specific setup like recommended civs or enforced settings
    - .mods.xml - defining map special settings (overwrites protoy.xml and protomods.xml) only for a specific map

### Game
- ai - artificial intelligence
    - **⚠️ AI MUST READ `docs/ai_reference.xs` when editing any .xs file in game/ai/**
    - Complete XS language reference with rules, unit queries, resource management, military planning
    - Key functions: xsEnableRule(), aiPlanCreate(), kbUnitQuery(), aiTaskUnitMove()
    - core - core ai files, contains the whole AoE3 game ai (except individual personalities) not just modded files
    - all files are customized and different from the vanilla game ai
    - the new ai contains way more rules specific for naval maps and special maps with custom objectives as well as new native civs
    - the completely custom files
        - assertivewall.xs
        - aipiraterules.xs
- randmaps - random maps which don't need the -mods.xml folder. Mostly more standardized maps
    - **⚠️ AI MUST READ `docs/all_rm_commands.txt` when editing .xs map files**
    - groupings - special groups of units(objects) which can be be placed on a map. Can contain not just multiple objects but also information about terrain or terrain elevation and cliffs. Can't contain any water areas. Oftenly used for native settlements or city blocks, but also nature objects like volcanos.

### Sound
- contain information about unit voices and other sounds. Every unit needs a special sound file in a format:

    "unit_name_snds.xml"

- file formats
    - .XML - unit voice / sound definition or soundset definitions
    - .WAV - sound itself
- folders (aboriginals, hebrew, ...)
    - sources of .WAV sounds
- soundsetsde.xml, soundsets.xml, soundsetsx.xml, soundsetsy.xml - contain soundsets definitions (turning .WAV file into .XML definitions). Soundsets are then used directly in the _snds.xml unit sound folders.


## Other folders

### Docs
- project documentation and reference materials for specific development tasks
    - **project_documentation.md** - THIS FILE - Complete project structure and conventions
    - **ai_reference.xs** - Complete XS language reference for AI scripting (2,400+ lines)
        - MUST READ when editing any game/ai/*.xs files
        - Contains all AI functions, rules system, unit queries, resource management
    - **all_rm_commands.txt** - Complete RM command reference for random map scripting (273 functions)
        - MUST READ when editing any randmaps/*.xs or game/randmaps/*.xs files
        - Contains terrain, area, object, connection, trade route, trigger functions
    - **command_list.md** - UI command functions and unit type names
        - MUST READ when adding commands to protounitcommandmods.xml
        - Contains find, select, train, research commands and unit type queries
    - **data_xml_guide.md** - Comprehensive XML syntax guide for data files (2,146 lines)
        - MUST READ when editing protomods.xml, techtreemods.xml, civmods.xml, tactics files
        - Contains complete ProtoUnit attributes, Commands, Flags, Tech elements, Civ structure, Tactics actions

### Scripts
- tool used for protounit balance and unit / tech automatic generation
- mostly a playground for programming experiment and automatization
    - new_art - newly generated art/ .xml files
    - new_data - newly generated data files
    - new_sounds - newly generated sound files
    - source - source files from the base game
        - protoy.xml - definition of all protounits (from the base game) -> modded addition: data/ protomods.xml
        - techtreey.xml - definiton of all tech (from the base game) -> modded addition: data/techtreemods.xml
        - civs.xml -> modded addition: civmods.xml
        - protounitcommands.xml -> addition: protounitcommandmods.xml
        - nuggets.xml -> addition: nuggetmods.xml
    - unit generator - generates new unit based on original one
    - tech generator - generates new tech based on original one

### Other files
- _all_xmls.py - github validation for XML
- _proto.py - github validation for proto.py
- _stringtables.py - github validation for string duplicities and strings
- _techtree.py - github validation for techtree

---

## AI Assistant Quick Reference

**Before editing ANY file, check this table:**

| File Type | Location | Required Reading | Why |
|-----------|----------|------------------|-----|
| `*.xs` (maps) | `randmaps/`, `game/randmaps/` | Read `docs/all_rm_commands.txt` | Need 273 RM function definitions |
| `*.xs` (AI) | `game/ai/` | Read `docs/ai_reference.xs` | Need XS language & AI function reference |
| `protounitcommandmods.xml` | `data/` | Read `docs/command_list.md` | Need UI command syntax & unit types |
| `protomods.xml`, `techtreemods.xml`, etc. | `data/` | Read `docs/data_xml_guide.md` | Need XML syntax reference (2,146 lines) |

**ID Ranges to Remember:**
- String IDs: 300001+ (400001+ for some contributors)
- Proto IDs: 20001+
- Tech IDs: 40001+

**Naming Convention:**
- New content often uses `zp` prefix
- Base game files have "y" suffix (protoy.xml → protomods.xml)






