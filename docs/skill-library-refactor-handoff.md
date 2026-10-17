# Handoff: refactor the shared skill library

> Historical proposal, superseded on 2026-09-22 by the user-approved Claude-first
> implementation. Read [current architecture](skill-system-architecture.md):
> physical `.claude/skills`, one ignored `.agents/skills` link, no AoP plugin.

Prepared 2026-09-22. This document is the execution brief for the next agent.
The proposed filesystem migration has NOT been performed.

## Objective and user priorities

Implement one physical, editable skill library inside Age of Pirates (AoP), reachable
through native discovery by the user's agents. The user primarily uses Claude Code
in VS Code and also Claude Desktop Code, plus Codex; support Cursor, Gemini CLI and
VS Code Copilot using their documented common discovery path.

The user rejects duplicate-looking skill trees, including directory junctions.
Do not solve this by hiding aliases in an editor, making copies or stub skills, or
repeating that multiple paths are technically one source. Save operator time and
token budget. Keep the existing export/import workflow; do not build a new manager,
background synchronizer, registry service or nested repository.

This is a layout and integration refactor. Preserve current skill content and current
uncommitted edits. Do not turn it into a rewrite of the library or implement unrelated
planned features merely because a document mentions them.

## Exact locations

AoP:
`C:/Users/TIGO/Games/Age of Empires 3 DE/76561198347905238/mods/local/age-of-pirates`

Session workspace:
`C:/Users/TIGO/Documents/Codex/2026-09-12/can-you-find-age-of-empires`

Public checkout for target `architecture`:
`<workspace>/architecture-blender-skills`
Remote: https://github.com/rostislavpeska/rts-3D-modelling

Public checkout for target `aoe3de`:
`<workspace>/aoe3de-modding-skills`
Remote: https://github.com/rostislavpeska/aoe3-modding-skills

Read AoP `config/skill-sync.local.json` for actual device-specific export paths.
Do not hardcode this machine's paths in portable scripts or public files.

## Read first, in order

Paths below are relative to AoP unless explicitly marked otherwise.

1. `AGENTS.md`: live-mod rules, shared agent rules and historical junction hazard.
2. `docs/skill-library-research.md`: proposed design, evidence, alternatives and limits.
3. `docs/skill-system-architecture.md`: CURRENT implementation and ownership.
   It has newer uncommitted additions: read the working copy, not just HEAD.
4. `docs/agent-skills.md` and `skills/README.md`: current setup/discovery contract.
5. `skills/public-skill-export/SKILL.md` and `skills/public-skill-import/SKILL.md`.
   The export skill has newer resource/prerequisite requirements. Preserve them.
6. `skills/FEEDBACK.md`: original Claude critique plus later assessment. This contains
   historical proposals; do not treat every old recommendation as current instruction.
7. The implementation/resources below. Read only relevant package bodies after that;
   do not load all 41 skills and references into context.

Read each public checkout's `AGENTS.md` before editing it. After migration, skill
paths in this brief naturally move from `skills/` to `.agents/skills/`.

## Target design

- Physical canonical source: AoP `.agents/skills/<name>/SKILL.md`.
- No top-level `skills/` source or compatibility link.
- No `.claude/skills/` mirror, link, per-skill links or forwarding stub packages.
- Codex, Cursor, Gemini CLI and VS Code Copilot discover `.agents/skills`.
- Claude loads that same library as a local-directory plugin, registered persistently
  for this project/device. Do not rely on remembering a CLI flag for every session.
- Keep shared project rules in `AGENTS.md`; retain the small CLAUDE.md/GEMINI.md imports.
- Preserve unrelated `.claude` settings, permissions, memory and the existing XML
  line-ending hook. A configuration directory is not an additional skill tree.
- The public repositories use the same physical layout, containing only approved
  packages. AoP remains the maintainer's source; public repos are reviewed snapshots.

The tested candidate places a plugin manifest at
`.agents/.claude-plugin/plugin.json` and a marketplace manifest at
`.claude-plugin/marketplace.json`, whose plugin entry has `source: "./.agents"`.
These are small configuration files, not duplicate skill content. The synthetic
fixture below shows their exact working shape; choose clear production identities.

Register the marketplace from the LOCAL checkout directory and enable the AoP plugin
at project/local scope. Do not globally expose private AoP policy to unrelated mods,
and do not replace local authoring with a GitHub-installed cached release.
Managed plugin caches may exist outside the repo; they are not another authoring source.

## Implementation files to inspect

- `scripts/tools/setup_agent_skill_link.py`
- `scripts/tools/install_user_skills.py`
- `scripts/tools/public_skill_sync.py`
- `scripts/tools/test_skill_layout.py`
- `scripts/tools/test_public_skill_sync.py`
- `scripts/skill-sync-manifest.json`
- `scripts/skill-sync-state.json`
- `config/skill-sync.example.json` and ignored `config/skill-sync.local.json`
- `.gitignore`, `CLAUDE.md`, `GEMINI.md`
- Public `scripts/setup_repo_skill_links.py`, `scripts/install_user_skills.py`,
  `scripts/validate_skills.py`, `.github/workflows/validate-skills.yml`,
  README, AGENTS, contribution/integration docs and AoE3DE `tests/`.

Find all callers using `rg`, including slash and backslash paths and Python path
construction. Known callers include `scripts/refdata/catalogs.py`,
`scripts/tools/check_anim_refs.py`, `stringsync.py`, `unitbench.py`,
`xmb_idcheck.py`, documentation and skill-local scripts.

Check `Path.parents[n]`, repository-root detection, relative Markdown links and
relative script imports: the new canonical location is one directory deeper.
Preserve the AoP entry routing (`bar-extract` -> `aoe3de-bar-archives`,
`aoe-building-pipeline` -> `aoe3de-building-export`).
Public reusable packages must not require private AoP wrappers.

Current export allowlist:
- `architecture`: `blender-architecture`, `blender-architecture-texturing`.
- `aoe3de`: `aoe3de-bar-archives`, `aoe3de-building-export`.
The manifest, not this list, is authoritative if it has since changed.

## Research evidence and what it proves

Under `<workspace>/work/skill-discovery-research/`:
- `single-tree/`: isolated fixture with the proposed physical tree and both manifests.
- `claude-plugin-results.json`: plain discovery versus CLI plugin flag.
- `claude-local-marketplace-runtime.json`: persistent registration, no per-launch flag.
- `vscode-local-marketplace.json`: source-edit checks with VS Code's bundled runtime.
- `codex-single-tree.json`: matching native Codex discovery and actual source path.
- `claude-fresh-catalog.json`: 41 current AoP names and descriptions in metadata.
- `public-ci-results.json`: initial published validation runs.

Tested runtimes:
- Terminal Claude Code 2.1.218.
- VS Code bundled Claude Code 2.1.278 at
  `C:/Users/TIGO/.vscode/extensions/anthropic.claude-code-2.1.278-win32-x64/resources/native-binary/claude.exe`.
- Codex 0.155.0-alpha.9.2.
Recheck installed paths/versions; do not assume these remain current.

Persistent local registration loaded new source descriptions in fresh Claude sessions
without reinstalling. The installation record still named a cache containing old
text; runtime catalogs loaded the newer source. A cache path or samefile=false for
that cache alone is NOT proof that runtime reads a stale copy.

Codex found the same physical skill, but the Claude plugin manifest also affected
its displayed namespace. Test invocation/routing by actual registered names.

No model prompt was sent during those metadata tests. They prove discovery/source
freshness, not successful model execution of a skill. Actual Desktop UI integration,
worktree behavior and Cursor/Gemini/Copilot runtime activation remain untested.

## Required sequence

1. Inspect current branch, status, staged files, public status and sync baselines.
   Other sessions are active. Preserve their edits and use explicit file lists for
   staging/commits; never sweep the shared index into a general commit.
2. Back up the physical skills and relevant configuration outside the live mod.
   Record hashes and preserve ignored local-only skill/tool content too.
3. Prove the candidate with a small fixture in the user's actual VS Code and native
   Desktop Code workflow before removing the current adapters. Verify registration,
   a fresh session, a source edit followed by reload, and one harmless skill read.
   Prefer available APIs/MCP/metadata checks. If Desktop cannot be verified, clearly
   report that remaining check; do not claim full compatibility or silently fall back
   to aliases. Prepare the rest without disrupting the working library.
4. Migrate the real source ONCE. Inspect existing junction identities and resolved
   paths before removing link entries or moving anything. Never recursively delete
   a junction or restore old tracked files through it. After removing only the
   verified alias entries, move the actual source to the physical destination.
   If concurrent edits appear, reconcile them before proceeding.
5. Update roots, callers, docs, ignores, setup/install behavior and tests together.
   Remove the blanket `/.agents/` ignore so the new canonical source is tracked.
   Keep private `gxo-convert`, converter config and device export paths ignored at
   their correct new locations. Retire or repurpose obsolete link helpers; no command
   should recreate the rejected duplicate trees.
6. Adapt export/import to the new roots in all three repos. Preserve the allowlist,
   direction/conflict checks and known synchronization baseline; do not wipe hashes
   to bypass a refusal. A directory relocation does not itself change package bytes.
   Preserve public contributors' changes. Follow current export instructions for
   local resource completeness and machine prerequisites.
7. Update public setup and CI for physical discovery plus optional Claude registration.
   Public docs, AGENTS and manifests must contain their own identities and portable
   guidance, not private AoP project rules. Do not auto-install private plugins in CI.
8. Run the checks below, inspect diffs, and document implemented behavior separately
   from any remaining limitations. Commit only scoped changes. The user requested
   both public repos be published: push scoped public updates after validation unless
   newer instructions hold exports. Do not force-push or publish AoP/private assets.

Current sync limitations to account for: destination packages must already exist;
both configured destinations are validated even when selecting one; a write run is
item-by-item, not an all-or-nothing transaction. Do not introduce a second general
sync framework to perform this migration.

## Acceptance checks

- Exactly one authored skill tree per repository; no duplicate discovery trees.
  Counts match the current pre-migration inventory (previously 41 AoP, 2 each public).
- Skill text/helper bytes preserved except intentional reviewed path/config changes;
  no lost local edits or ignored private resources.
- Native Codex and Claude discovery, descriptions, actual source paths and command
  names checked. A real source edit is visible after reload/fresh initialization.
- Actual VS Code and Desktop integration checked; explicitly identify any untested host.
- Fresh clone setup works. Verify chosen worktree behavior: local marketplace paths
  can resolve to the MAIN checkout, so do not promise per-worktree skill isolation.
- Dry-run export/import writes nothing. Scratch tests cover normal export/import,
  conflict refusal, missing targets and recovery behavior without touching real assets.
- Public export scans and metadata/resource validation pass; GitHub CI passes.
- No game, Steam, Blender, Photoshop, runtime asset or private binary changes.

Useful existing commands from AoP (adapt implementation/paths when needed):
```text
python -B -m unittest discover -s scripts/tools -p test_skill_layout.py
python -B -m unittest discover -s scripts/tools -p test_public_skill_sync.py
python -B scripts/tools/public_skill_sync.py status --target all
```
The first two create temporary fixtures; do not describe them as strictly no-write.
Public checks: `python -B scripts/validate_skills.py`, plus
`python -B -m unittest discover -s tests` in the AoE3DE checkout.
Replace tests that require obsolete junctions with meaningful new-layout assertions.

## Audit findings and current Git state

The independent Claude audit identified an old-history write-through hazard at the
current `.claude/skills` junction. Inspect historical files only in another checkout.
The proposed removal addresses this specific hazard; hiding the path does not.

Fresh metadata reported all 41 descriptions, while the audited model-visible listing
showed only 10. Claude documents listing-budget truncation; that remains a possible
cause, not a confirmed diagnosis. Do not spend model tokens or increase budgets
blindly. Check the actual affected session's /context or /doctor if required.

AoP infrastructure/docs were committed locally as `3a779c73` on `inuit-harpooner`.
No AoP push was performed. Recheck branch/status: do not switch, reset, or merge it
automatically. At handoff there are NEW uncommitted changes in the architecture doc,
Blender/AoE3DE skill bodies, export skill and grouping skills. Preserve them.
The existing proposal is not permission to overwrite these with earlier snapshots.

Initial public main commits are already pushed, with green CI:
- 3D: `51f5683a252881fc4d44b58024e310e286516664`
- AoE3DE: `e8467001c6add4c01ac545a5e96057a402a6bc89`
They still use the old layout. Recheck remote heads before writing/pushing.

## Official sources â€” use targeted follow-ups only

- https://learn.chatgpt.com/docs/build-skills
- https://learn.chatgpt.com/docs/config-file/config-reference
- https://code.claude.com/docs/en/skills
- https://code.claude.com/docs/en/plugins-reference
- https://code.claude.com/docs/en/plugin-marketplaces
- https://code.claude.com/docs/en/vs-code
- https://code.claude.com/docs/en/desktop
- https://code.claude.com/docs/en/env-vars
- https://cursor.com/docs/skills
- https://geminicli.com/docs/cli/using-agent-skills/
- https://code.visualstudio.com/docs/agent-customization/agent-skills
- https://agentskills.io/client-implementation/adding-skills-support

The current Desktop documentation distinguishes native local, WSL and cloud sessions.
Do not equate Desktop Code with ordinary Chat/Cowork or promise identical capabilities
in all environments. Reuse the research instead of starting a broad search again.

## Completion report

Give the user the one edit location, how each agent loads it, the one-time device
setup, tests actually run, remaining limitations, scoped commits and public push/CI
links. Distinguish local exports from GitHub publication and documentation claims from
runtime evidence. Keep the final explanation short and concrete.
