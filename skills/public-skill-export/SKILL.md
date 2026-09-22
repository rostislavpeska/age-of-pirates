---
name: public-skill-export
description: Export explicitly approved, public-safe skill snapshots from the canonical Age of Pirates skill directory into the architecture or AoE3DE public skill repositories. Use when publishing or refreshing public skills; never copy skill folders manually.
---

# Export public skill snapshots

Age of Pirates `skills/` is the canonical source on the owner's devices. Public repositories are curated snapshots.

Read the target allowlist in `scripts/skill-sync-manifest.json`. Repository locations belong only in the gitignored `config/skill-sync.local.json`, initially copied from `config/skill-sync.example.json`.

Start with a read-only status and dry run:

```bash
python scripts/tools/public_skill_sync.py status --target all
python scripts/tools/public_skill_sync.py export --target all
```

Only after reviewing the reported direction and changed files, write the export:

```bash
python scripts/tools/public_skill_sync.py export --target all --write
```

The tool exports only allowlisted skill directories and the explicitly mapped agent setup files in `supportFiles`. It scans for private paths and forbidden binaries, validates skill structure and refuses when both AoP and the public copy changed since their last synchronized hash. It never commits or pushes.

Agent setup has one maintained implementation in AoP. The exported setup helper creates local links to each public checkout's own `skills/`, including `.agents/skills` for Codex, Cursor, Gemini CLI and VS Code Copilot and `.claude/skills` for Claude Code. `CLAUDE.md` and `GEMINI.md` import each repository's own `AGENTS.md`; never export AoP's project rules into the public repository. Links and device paths are not exported. After export, run `python scripts/setup_repo_skill_links.py` and then the same command with `--check` inside each destination. Native agent activation is a separate fresh-session smoke check.

Edit a skill only in AoP. Do not repair an export by editing the public copy; fix the canonical source and export again. Outside contributions are the exception and must enter through `public-skill-import`.
