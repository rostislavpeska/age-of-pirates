# Research: one editable skill library across agents

Date: 2026-09-22. **Recommendation only; no directory migration has been applied.**
The [architecture document](skill-system-architecture.md) describes the current implementation.

## Recommendation for this project

Use one physical, tracked `.agents/skills/` directory inside Age of Pirates.
Codex, Cursor, Gemini CLI and VS Code Copilot can discover that directory.
Expose it to Claude Code as a **local-directory plugin**, rather than creating a
`.claude/skills` junction. Keep AGENTS.md as project rules, with the existing small
CLAUDE.md and GEMINI.md imports.

This meets the requested one-tree authoring experience without treating a pointer
in CLAUDE.md as equivalent to native skill discovery. It introduces a small Claude
plugin registration instead of filesystem aliases. The public repositories should
use the same layout when this proposal is adopted.

Before adopting it, verify the actual Claude Desktop Code session loads the local
plugin and sees an edited scratch skill. VS Code's installed Claude runtime and the
terminal runtime passed isolated discovery/edit tests; the Desktop UI was not tested.

## What the official documentation establishes

| Host | Supported path / mechanism relevant here | Evidence |
| --- | --- | --- |
| Codex | Repository `.agents/skills`; supports symlinked skills | [Build skills](https://learn.chatgpt.com/docs/build-skills) |
| Claude Code | Native project `.claude/skills`, or plugin skills | [Skills](https://code.claude.com/docs/en/skills) |
| Cursor | `.agents/skills`; also reads compatibility directories | [Skills](https://cursor.com/docs/skills) |
| Gemini CLI | Workspace `.agents/skills` or `.gemini/skills` | [Managing skills](https://geminicli.com/docs/cli/using-agent-skills/) |
| VS Code Copilot | `.agents/skills`, `.claude/skills`, `.github/skills` | [Agent skills](https://code.visualstudio.com/docs/agent-customization/agent-skills) |
| Claude in VS Code | Plugin manager accepts local marketplace paths | [VS Code integration](https://code.claude.com/docs/en/vs-code#manage-marketplaces) |
| Claude Desktop Code | Plugin manager supports local sessions and installation scopes | [Desktop plugins](https://code.claude.com/docs/en/desktop) |

A shared SKILL.md format does not guarantee identical discovery paths or host-specific
features. The standard supports file-read activation too, but the host must expose a
catalog and instructions; a bare documentation link is not a native catalog registration.
See [Agent Skills integration](https://agentskills.io/client-implementation/adding-skills-support).

No documented shared setting was found that redirects every host to an arbitrary
root `skills/`. Codex's `skills.config` entries are enablement overrides, not a
documented custom discovery-root setting ([configuration reference](https://learn.chatgpt.com/docs/config-file/config-reference)).
VS Code's old `chat.agentSkillsLocations` setting is deprecated and local-agent-only.

## Proposed repository layout

```text
age-of-pirates/
  .agents/
    skills/                         THE ONLY authored skill tree
      blender-architecture/
      blender-architecture-texturing/
      aoe3de-bar-archives/
      ...other AoP skills...
    .claude-plugin/
      plugin.json                   small plugin identity manifest
  .claude-plugin/
    marketplace.json                points to ./.agents
  .claude/
    settings.json                   existing hooks/configuration, preserved
    settings.local.json             device-local plugin enablement, if chosen
  AGENTS.md
  CLAUDE.md
  GEMINI.md
  docs/
  scripts/
```

There would be no root `skills/`, no `.agents/skills` alias and no
`.claude/skills` alias. Metadata directories contain configuration, not additional
SKILL.md trees. A README link makes the one authoring location easy to open.

A local marketplace entry would identify one plugin with `source: "./.agents"`.
Register that checkout as a **local directory**, then enable the plugin at project
or local scope. The normal VS Code/Desktop launch should use that registration;
the proposal does not depend on remembering `--plugin-dir` for every session.
Do not install the private AoP suite globally into unrelated projects.

The registration is device-local setup, just as converter locations are. A fresh
clone or another machine needs the local marketplace registered. Relative paths
inside the manifests remain portable. This is not zero configuration.

## Why this works, and what remains different

Claude documents loading relative plugin sources from a local-directory marketplace
in place. Fresh sessions or `/reload-plugins` pick up edits without a release/version
bump. GitHub-installed plugins are a different distribution mode and can use copied
versions. See [plugin caching and resolution](https://code.claude.com/docs/en/plugins-reference#plugin-caching-and-file-resolution).

An installer may still leave a cache directory. Do not infer the runtime source
from that directory alone: the experiment below found an old cached description
while the active catalog reflected subsequent local source edits.

Plugin skills have a namespace. In the fixture, both Claude and the installed Codex
build reported `aop-skill-probe:probe-one-library`. A migration must update affected
invocations and test routing; unchanged SKILL.md files alone are insufficient.

Local native Desktop Code sessions are the target here. Claude Chat, Cowork,
cloud sessions and WSL have different access/plugin rules; local desktop support
does not establish support for all of them. In particular, the current Desktop
documentation excludes plugins in WSL and does not carry locally installed plugins
into cloud sessions. A cloud task needs its own supported provisioning.

Worktrees also need deliberate testing. Claude documents that relative local
marketplace paths resolve against the main checkout, so a worktree can see the main
checkout's skills rather than its own revision
([marketplace configuration](https://code.claude.com/docs/en/plugin-marketplaces)).
Do not claim per-worktree skill isolation until it is tested.

## Isolated tests performed

No model prompt or paid inference turn was submitted. Experiments used synthetic
skills in workspace scratch storage, with isolated Claude configuration for plugin
installation. No real user plugin installation or AoP folder layout was changed.

| Test | Observation |
| --- | --- |
| Claude Code 2.1.218, plain physical `.agents/skills` | Synthetic skill not discovered through the plain project path |
| Same runtime with local `--plugin-dir` | Skill discovered; edited description loaded on next initialization |
| Persistent local marketplace, 2.1.218 | Fresh initialization without `--plugin-dir` loaded current source marker D while cache still contained marker B |
| VS Code bundled Claude 2.1.278, persistent local marketplace | Two fresh initializations loaded source markers C then D, without reinstalling or passing `--plugin-dir` |
| Codex 0.155.0-alpha.9.2, same physical tree | Discovered exactly one matching skill at the actual source path; plugin manifest affected its displayed namespace |
| Actual Claude Desktop UI session | Not tested |
| Cursor/Gemini/Copilot runtime with this proposed layout | Documentation checked; runtime test not performed |

Test evidence remains in the session workspace under `work/skill-discovery-research/`,
particularly `claude-local-marketplace-runtime.json`,
`vscode-local-marketplace.json` and `codex-single-tree.json`.
These metadata tests establish discovery and source freshness, not model task quality
or correct execution of every bundled helper.

## Alternatives assessed

| Option | Benefit | Cost / conclusion |
| --- | --- | --- |
| Existing `skills/` plus two junctions | Native discovery already works locally | Three visible trees; setup after clone; historical path restoration hazard |
| Physical `.agents/skills` plus one Claude junction | Removes one unnecessary tree | Still displays the duplicate structure the owner rejected |
| Physical `.agents/skills` plus local Claude plugin | One authored tree; native catalogs; local edits picked up in tested runtimes | Recommended candidate; plugin setup, namespaces and Desktop/worktree verification required |
| Plain `skills/` referenced from instruction files | Simple, editable library without aliases | File-reading workflow; native menus and native automatic discovery are not provided by the reference |
| Install copies for every agent / generic skill manager | Broad installation tooling | Separate copies can drift; symlink mode still produces alias trees |

For comparison, Vercel's skills installer recommends symlinks to a canonical copy
([upstream README](https://github.com/vercel-labs/skills/blob/main/README.md)).
That is an established distribution technique, but it does not solve this user's
objection to duplicate-looking repository trees. Hiding links in the editor is
cosmetic and does not remove their Git-history risk.

## The independent Claude audit

The supplied audit verified 41 project skills, routing, references and read-only
commands. It did not prove write behavior. Its useful findings are separate from
the choice of directory layout:

- **Untracked setup files:** the infrastructure and documentation must be versioned
  with their callers so fresh clones can use them.
- **Historical write-through risk:** the current `.claude/skills` junction occupies
  a path tracked by older commits. Do not restore an old version of that path through
  the junction. Use a separate checkout to inspect historical skill files.
  Removing this alias in the proposed design removes that particular indirection.
- **Public AoP wording:** generalized the three `scripts/source` references and
  adjacent misleading help text in the canonical BAR tool before exporting.
- **Unpublished public repos:** published both initial releases; their GitHub Actions
  validation runs passed.
- **31 descriptions absent in model-visible catalog:** a fresh metadata initialization
  returned all 41 descriptions. Claude documents dropping descriptions when the skill
  listing exceeds its budget ([description troubleshooting](https://code.claude.com/docs/en/skills#skill-descriptions-are-cut-short)).
  Budgeting is a plausible explanation, not a confirmed diagnosis of the audited
  session. Do not increase token budgets or rewrite skills blindly; inspect that
  session's `/context` or `/doctor` if the symptom persists.

Concurrent agents committed earlier staged changes during the audit. Any follow-up
commit must name its owned files explicitly and avoid sweeping up another session's
staging. A read-only audit should report unrelated concurrent changes separately.

## Public distribution and migration boundary

The maintainer still edits only the AoP suite. Public repos remain reviewed snapshots:
[rts-3D-modelling](https://github.com/rostislavpeska/rts-3D-modelling) and
[aoe3-modding-skills](https://github.com/rostislavpeska/aoe3-modding-skills).
External contributions still return through reviewed import. Neither is a dependency
submodule or a second authoring source for the maintainer.

The initial published snapshots retain the existing layout. A later approved migration
must change source paths, imports, export destinations, validators, links, ignores and
documentation together. Preserve the skill bytes and baseline hashes where unchanged;
do not rebuild the skills or copy private AoP policy into public plugin metadata.

Acceptance before removing the current adapters: native discovery in the actual
VS Code and Desktop sessions; edit a scratch source and observe it after reload;
check one relevant skill and helper; verify a fresh clone and the chosen worktree
behavior; then migrate once. No live migration was performed during this research.
