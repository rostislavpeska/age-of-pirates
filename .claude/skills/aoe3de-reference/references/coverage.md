# Reference coverage

This package contains the complete reference texts available in the authoring
library, with the data XML guide split at its documented consumer-specific boundary.
It is not an authoritative complete schema or current DE API inventory.

| File | Included scope | Limit |
| --- | --- | --- |
| `ai_reference.xs` | Full existing XS/AI function and constant reference | Mixed game versions; no verified current DE enumeration |
| `rm_commands_reference.md` | Full existing categorized RM command reference | Historical reported count of 266 is not a current completeness guarantee |
| `data_xml_guide.md` | Entire shared guide before consumer-specific Placement Rules | Field tables, not a formal exhaustive XML schema; extraction artifacts remain |
| `command_list.md` | Full existing UI command reference | Source version and coverage unverified |
| `runtime-xml.md` | Curated runtime animation/material XML guidance | Tested profile, not all engine XML formats |
| `map-trigger-workflow.md` | Portable map/trigger workflow summary | Not every trigger condition/effect signature |

The XS file is documentation, not a script to load into a map. Reference signatures
and XML names should be checked against the installed game and working examples.
Consumer-specific ids, factions and deployment instructions deliberately stay out.

Run `python .claude/skills/aoe3de-reference/scripts/check_reference_bundle.py` from
the repository root to detect missing, truncated or altered original texts.
The hashes normalize line endings so Windows and Linux checkouts agree.
This validates copied content only; hashes cannot establish factual completeness.

See [provenance](provenance.md) for attribution and unresolved redistribution terms.
Do not interpret the repository's MIT license as relicensing third-party texts.
