# Age of Pirates - Documentation Hub

> **🚀 START HERE:** For complete project documentation, read [`project_documentation.md`](project_documentation.md)

> **🧪 TESTING:** When user says "use playground", work ONLY in `playground/` folder. Use test IDs (90001+, 990001+). See `../playground/README.md`.

## For AI Assistants & Developers

This directory contains all documentation needed to work on the Age of Pirates mod for Age of Empires III: Definitive Edition.

### Essential Reading

1. **[project_documentation.md](project_documentation.md)** ⭐ **READ FIRST**
   - Complete project structure
   - File organization and conventions
   - ID ranges and naming patterns
   - Mod folder descriptions

### Task-Specific References

Read these **BEFORE** working on specific file types:

| 📁 Working On... | 📄 Must Read | Description |
|------------------|--------------|-------------|
| **Random Maps** (`*.xs`) | ⚠️ [map_coordinate_system.md](map_coordinate_system.md) + [random_map_generation_guide.md](random_map_generation_guide.md) + [all_rm_commands.txt](all_rm_commands.txt) | **CRITICAL:** Coordinate system (45° rotation) + Complete workflow guide + 273 RM commands. Also check [waterbodies.xml](../scripts/source/waterbodies.xml), [terraintypes.xml](../scripts/source/art/terraintypes.xml) |
| **Map Triggers** | [map_trigger_guide.md](map_trigger_guide.md) + [triggerdata.xml](../data/trigger/triggerdata.xml) + [techtreemods.xml](../data/techtreemods.xml) | Starting techs, politicians (consulates), AI leaders. Includes complete examples for Mediterranean, Baltic, Australia variants. |
| **AI Scripts** (`game/ai/*.xs`) | [ai_reference.xs](ai_reference.xs) | Complete XS language reference (2,400+ lines) |
| **UI Commands** (`protounitcommandmods.xml`) | [command_list.md](command_list.md) | UI functions and unit type queries |
| **Data XML** (`protomods.xml`, etc.) | [data_xml_guide.md](data_xml_guide.md) | Complete XML syntax guide (2,146 lines) |

### Step-by-Step Workflows

**🔧 [workflows/](workflows/)** - Complete procedures for complex tasks

- **[creating-spawning-building.md](workflows/creating-spawning-building.md)** - Buildings with tactic-based unit spawning (Maintain system, switchable tactics, complete templates, testing checklist)

Use workflows for implementing multi-file features with tested procedures.

### Quick Reference Card

```
🗺️  Creating/editing maps?        → ⚠️ FIRST: map_coordinate_system.md (45° rotation!)
                                    Then: random_map_generation_guide.md
                                    Then: all_rm_commands.txt + waterbodies.xml
🎯  Adding triggers/politicians?   → Read map_trigger_guide.md + techtreemods.xml
🤖  Modifying AI behavior?         → Read ai_reference.xs
⌨️  Adding hotkeys/commands?       → Read command_list.md
📦  Creating units/techs/civs?     → Read data_xml_guide.md

Always check project_documentation.md for conventions and ID ranges!
```

## File Summaries

### [map_coordinate_system.md](map_coordinate_system.md) ⭐ **CRITICAL**
- ⚠️ **MUST READ BEFORE MAP WORK:** Explains the 45° rotation between XZ coordinates and visual minimap
- Visual representation of coordinate system (diamond shape)
- Coordinate mapping table (code NE → visual North, etc.)
- Practical examples for placing objects
- Common pitfalls and how to avoid them
- **Use cases:** ANY work involving map coordinates, object placement, understanding player reports

### [random_map_generation_guide.md](random_map_generation_guide.md) ⭐ **NEW**
- **Complete workflow guide** for AI agents creating random maps
- Map folder structure, naming conventions (`000zp` prefix), file requirements
- Reference file locations (waterbodies.xml, terraintypes.xml)
- Best practices (copy working maps, avoid encoded maps, verify types)
- Common issues & fixes, step-by-step creation process
- **Use cases:** Creating any new random map from scratch

### [all_rm_commands.txt](all_rm_commands.txt)
- **273 RM commands** for random map scripting
- Terrain initialization, area creation, object placement
- Connections, trade routes, triggers, player placement
- **Use cases:** Creating new maps, terrain generation, object placement

### [map_trigger_guide.md](map_trigger_guide.md) ⭐ **NEW**
- **Complete trigger implementation guide** for map events and gameplay
- Starting tech activation, universal consulate (politicians), AI leader selection
- Regional pirate variants (Mediterranean, Baltic, Australia)
- Complete working examples from Balearic Islands map
- Supporting triggers (Italian balance, research speed, cheat returner)
- Best practices, common mistakes, troubleshooting
- References `data/trigger/triggerdata.xml` and `data/techtreemods.xml`
- **Use cases:** Adding politicians, starting techs, AI captains, timed events

### [ai_reference.xs](ai_reference.xs)
- **Complete XS language reference** (2,400+ lines)
- Rules system, vectors, arrays, unit queries
- Resource management, military planning, naval AI
- **Use cases:** AI behavior modifications, custom AI rules, unit commands

### [command_list.md](command_list.md)
- **UI command functions** for hotkeys and selection
- Find/select commands (`uiFindIdleType`, `uiFindAllOfType`)
- Action commands (`trainInSelected`, `doAbilityInType`)
- **Unit type names** for queries (`AbstractInfantry`, `AbstractCavalry`, etc.)
- **Use cases:** Custom hotkeys, unit selection macros, training commands

### [data_xml_guide.md](data_xml_guide.md)
- **Comprehensive XML syntax guide** for data files (2,146 lines)
- ProtoUnit attributes, Commands, Flags, Tech elements, Civ structure, Tactics actions
- **Use cases:** Creating new units, modifying unit properties, adding techs, configuring civilizations

### [project_documentation.md](project_documentation.md)
- **Master documentation** for the entire project
- Project structure, conventions, ID ranges
- Detailed folder descriptions with file format explanations
- **Use cases:** Understanding project organization, finding where things go

## Contributing

See [`../CONTRIBUTING.md`](../CONTRIBUTING.md) for contribution guidelines and Git workflow.

---

**💡 Pro Tip for AI Models:** When a user asks you to work on a specific file type, always check this README or project_documentation.md first to determine which reference file(s) you need to read before proceeding.

