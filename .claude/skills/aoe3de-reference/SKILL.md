---
name: aoe3de-reference
description: Look up AoE3DE data XML fields, random-map commands, XS/AI signatures and UI commands from bundled reference texts. Use for exact syntax lookup; verify version-sensitive behavior against the installed game.
---

# AoE3DE reference library

Read [source and coverage notes](references/provenance.md) before relying on these
texts. They are searchable reference snapshots, not a complete schema or proof
that every listed function works in the current build. This package needs no
installed application for document lookup.

| Task | Reference and useful search terms |
| --- | --- |
| Unit, tactic, civilization or technology data | [Data XML](references/data_xml_guide.md): `ProtoActions`, `ProtoUnitCommands`, `TechTree`, field name |
| Random-map functions | [RM commands](references/rm_commands_reference.md): exact `rm` function name |
| XS language and AI functions/constants | [XS/AI reference](references/ai_reference.xs): exact `xs`, `ai`, `kb` function or constant |
| UI commands and unit queries | [UI commands](references/command_list.md): `uiFind`, `trainInSelected`, `doAbilityInType` |
| Map and trigger work | [Reusable workflow](references/map-trigger-workflow.md): validation stages and trigger checks |
| Static building runtime XML | [Runtime XML profile](references/runtime-xml.md): model/material paths and validation boundaries |

Use a narrow search and read surrounding definitions. Resolve stock record names
and actual file structure from the user's installed game when needed; archive
lookup is supplied by the separate `aoe3de-bar-archives` skill. Consuming mods supply
their ids, factions, naming rules, deployment paths and examples. Do not copy AoP
names into another mod or assume a historical count describes the current game.

The `.xs` reference is documentation, not an executable map or an AI script to
install. This package ships no game data, tools, game executable or third-party
manual PDF. Third-party provenance/redistribution questions remain documented in
the provenance notes; local inclusion does not approve public redistribution.

Read [coverage](references/coverage.md) before claiming completeness. Verify the
four source texts with `scripts/check_reference_bundle.py`; this checks integrity,
not current-build API coverage.
