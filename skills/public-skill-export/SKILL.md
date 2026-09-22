---
name: public-skill-export
description: Export explicitly approved, public-safe skill snapshots from the canonical Age of Pirates skill directory into the architecture or AoE3DE public skill repositories. Use when publishing or refreshing public skills; never copy skill folders manually.
---

# Export public skill snapshots

Age of Pirates `skills/` is the canonical source on the owner's devices. Public repositories are curated snapshots.

Read the target allowlist in `scripts/skill-sync-manifest.json`. Repository locations belong only in the gitignored `config/skill-sync.local.json`, initially copied from `config/skill-sync.example.json`.

## Prepare in AoP first

Read the [architecture](../../docs/skill-system-architecture.md), especially resource
ownership and local application prerequisites. Update the canonical instructions
and their documentation before changing packaging. Implement and test additions in
AoP before touching a public checkout. A user request to hold exports takes precedence
over the write step below.

For each selected package, review its `SKILL.md`, supporting documents and helpers:

- Resolve required local files, script imports, data inputs and companion skills,
  including transitive dependencies. A file existing elsewhere in AoP does not make
  it available to a public consumer. Bundle reusable resources or declare an included
  companion package; keep consumer-specific assets and policies in the consuming mod.
- Maintain one editable reference source. When relocating a document, update callers
  and use a forwarding page if needed. Preserve attribution, provenance, version and
  coverage limits. Curate mod-specific guides instead of copying private examples
  and historical claims into universal instructions.
- Declare external prerequisites per operation: required capability, installed
  product/runtime, compatibility evidence, read-only availability check, optional
  alternatives and the step blocked when missing. Photoshop, Blender, Resource
  Manager, game archives, converters, licenses and connections remain local. Export
  procedures and wrapper source, never installed binaries or machine configuration.
- Separate package completeness from machine readiness. A missing commercial app
  does not invalidate a documentation export, but an undeclared required tool or a
  required helper missing from the package does. The converter's header check is not
  a substitute for the required GR2 structural inspection.

Run the [resource audit](../skill-library-audit/SKILL.md) on the selected AoP
packages and their declared companions before export. Its initial fixture tests
pass, but it is not yet integrated into the synchronizer or public CI. Review
dynamic/prose-only dependencies and provenance manually. Six packages currently
have declarations; report other packages as unaudited. Companion dependencies must
be explicitly allowlisted before release; do not widen the allowlist automatically.
The current exporter cannot create a new public package from an absent destination.
Implement and test explicit onboarding before exporting new packages; do not copy
folders manually or remove baselines to get around a refusal.

## Preview and export

Start with a read-only status and dry run:

```bash
python scripts/tools/public_skill_sync.py status --target aoe3de
python scripts/tools/public_skill_sync.py export --target aoe3de
```

Only after reviewing the reported direction and changed files, write the export:

```bash
python scripts/tools/public_skill_sync.py export --target aoe3de --write
```

The tool exports only allowlisted skill directories and the explicitly mapped agent setup files in `supportFiles`. It scans for private paths and forbidden binaries, validates skill structure and refuses when both AoP and the public copy changed since their last synchronized hash. It never commits or pushes.

Choose `architecture` for that library; use `all` only when both targets are in scope.
Before writing, review new resources as well as modifications and deletions. After
writing, compare package contents, run destination metadata/resource checks and
relevant helper tests, and inspect the destination diff. Report separately what was
exported locally, what was tested and whether anything was published to GitHub.

Agent setup has one maintained implementation in AoP. The exported setup helper creates local links to each public checkout's own `skills/`, including `.agents/skills` for Codex, Cursor, Gemini CLI and VS Code Copilot and `.claude/skills` for Claude Code. `CLAUDE.md` and `GEMINI.md` import each repository's own `AGENTS.md`; never export AoP's project rules into the public repository. Links and device paths are not exported. After export, run `python scripts/setup_repo_skill_links.py` and then the same command with `--check` inside each destination. Native agent activation is a separate fresh-session smoke check.

Edit a skill only in AoP. Do not repair an export by editing the public copy; fix the canonical source and export again. Outside contributions are the exception and must enter through `public-skill-import`.
