# Shared agent setup

Author skill content in `.claude/skills/<name>/SKILL.md`. There is one physical source per checkout.
Repository rules live in `AGENTS.md`; `CLAUDE.md` and `GEMINI.md` import that file.
Only relevant skills and references should be loaded into context.

| Agent | Skill discovery | Project instructions |
| --- | --- | --- |
| Codex | `.agents/skills` | `AGENTS.md` |
| Claude Code | `.claude/skills` | `CLAUDE.md` imports `AGENTS.md` |
| Cursor | `.agents/skills` | `AGENTS.md` |
| Gemini CLI | `.agents/skills` | `GEMINI.md` imports `AGENTS.md` |
| VS Code Copilot | `.agents/skills` | `AGENTS.md` where supported/enabled |

Do not create extra `.codex/skills`, `.cursor/skills` or `.gemini/skills` copies.
An expanded discovery link looks like a second folder tree, but edits reach the same files.
Consumers can use a public checkout as their source; the maintainer authors in AoP and
exports reviewed snapshots. Do not install public snapshots globally on top of the
maintainer's AoP suite with the same skill names.

## Set up a checkout

Requires Python 3.10 or later. For a checkout using this layout, the public helper name is:

```bash
python scripts/setup_repo_skill_links.py
python scripts/setup_repo_skill_links.py --check
```

In the AoP authoring repository, the same helper is
`python scripts/tools/setup_agent_skill_link.py`.

The helper creates one ignored `.agents/skills` directory link to the physical
`.claude/skills/` source. Claude uses the source directly.
On Windows it uses directory junctions; elsewhere relative symbolic links.
It preflights every destination, refuses existing copies or unexpected/broken links,
preserves agent settings, and never deletes files. `--check` is read-only and verifies
file identity, not merely matching content.

Run setup separately after each clone, including CI, worktrees and remote workers.
Each worktree links to its own `.claude/skills`, never the main checkout.
Windows junctions point to absolute locations: after moving a checkout, inspect and
remove only the old link itself before rerunning setup. Never recursively delete a
discovery path. The helper intentionally refuses to guess about broken links.

For ZIP downloads, extract the entire repository, including dot-directories. Claude
uses `.claude/skills` directly. Codex needs the setup command once; Git is not needed
for setup, but Python 3.10+ is. Restart the host if its catalog still advertises paths
from an earlier layout; a new task alone may reuse cached discovery metadata.

## Optional use outside this checkout

Public consumers who want these skills across projects can run:

```bash
python scripts/install_user_skills.py
python scripts/install_user_skills.py --check
```

This links individual packages into `~/.agents/skills` and `~/.claude/skills`.
It does not copy packages or overwrite an existing installation. Keep the source
checkout in place. Review any reported name collision before changing it; a personal
skill may override a project's skill or appear twice, depending on the agent.
No user-level installation is required for repository-local use.

## Verify discovery and behavior

Open the agent in the intended repository after setup. Use a fresh session if a new
discovery root is not detected. List skills, check the source path, and explicitly
invoke one harmless inspection; then try a matching request without naming the skill.
For Gemini CLI use `/skills list` and `/skills reload`. For Cursor inspect its Skills
settings and slash menu. For Claude Code inspect `/skills`. For Codex CLI use
`/skills` or a `$skill-name` mention.

Use scratch fixtures for behavior checks. A Blender blockout should wait for approval
before detailed modeling; an export should preserve operator-edited source; a
conflicting public import should refuse to overwrite. Record the actual outcome and
time/token cost when running these checks. Passing layout tests does not prove that
an installed agent version discovers or follows the skill.

MCP servers, application sessions, permissions, runtimes and local converter paths
must be configured separately for each agent/device. Skills do not install those
connections. Keep shared instructions independent of vendor-specific tool names.
Use only standard skill frontmatter for portable content; keep optional vendor
metadata and hooks separate. Native UI details can vary by version.

## Documentation

- [Codex skills](https://learn.chatgpt.com/docs/build-skills)
- [Claude skills](https://code.claude.com/docs/en/skills) and [instruction imports](https://code.claude.com/docs/en/memory)
- [Cursor skills](https://cursor.com/docs/skills) and [AGENTS.md](https://cursor.com/docs/rules)
- [Gemini skills](https://geminicli.com/docs/cli/using-agent-skills/) and [instruction imports](https://geminicli.com/docs/cli/gemini-md/)
- [VS Code Copilot skills](https://code.visualstudio.com/docs/agent-customization/agent-skills)
- [Agent Skills specification](https://agentskills.io/specification)
