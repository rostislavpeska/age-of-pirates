---
name: public-skill-import
description: Safely review and import changes made in the public architecture or AoE3DE skill repositories back into the canonical Age of Pirates skill suite. Use for public contributions or edits; refuse ambiguous two-sided changes.
---

# Import public skill changes

Age of Pirates remains the source of truth after import. Never copy a public skill directory over `skills/` by hand.

Inspect status and preview the import:

```bash
python scripts/tools/public_skill_sync.py status --target all
python scripts/tools/public_skill_sync.py import --target architecture
```

The preview lists changed files and refuses if AoP and the public copy both changed since their last synchronized hash. Resolve such a conflict manually in AoP; do not force an overwrite.

After reviewing the public commit and preview, import explicitly:

```bash
python scripts/tools/public_skill_sync.py import --target architecture --write
```

Run the relevant AoP skill tests after import. The tool scans incoming files, rejects private paths and forbidden binaries, validates each skill, updates the synchronization hash and never commits either repository.
