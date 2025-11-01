# Age of Pirates - Documentation Hub

> **🚀 START HERE:** For complete project documentation, read [`project_documentation.md`](project_documentation.md)

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
| **Random Maps** (`*.xs`) | [all_rm_commands.txt](all_rm_commands.txt) | 273 RM functions for terrain, areas, objects, connections |
| **AI Scripts** (`game/ai/*.xs`) | [ai_reference.xs](ai_reference.xs) | Complete XS language reference (2,400+ lines) |
| **UI Commands** (`protounitcommandmods.xml`) | [command_list.md](command_list.md) | UI functions and unit type queries |
| **Data XML** (`protomods.xml`, etc.) | [data_xml_guide.md](data_xml_guide.md) | Complete XML syntax guide (2,146 lines) |

### Quick Reference Card

```
🗺️  Editing map scripts?        → Read all_rm_commands.txt
🤖  Modifying AI behavior?       → Read ai_reference.xs
⌨️  Adding hotkeys/commands?     → Read command_list.md
📦  Creating units/techs/civs?   → Read data_xml_guide.md

Always check project_documentation.md for conventions and ID ranges!
```

## File Summaries

### [all_rm_commands.txt](all_rm_commands.txt)
- **273 RM commands** for random map scripting
- Terrain initialization, area creation, object placement
- Connections, trade routes, triggers, player placement
- **Use cases:** Creating new maps, terrain generation, object placement

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

