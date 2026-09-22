# Universal Age of Pirates skills

[System architecture](../../docs/skill-system-architecture.md) explains ownership, both public repositories, agent links, export/import, testing and recovery limits. [Agent setup](../../docs/agent-skills.md) covers checkout installation.

`.claude/skills/<name>/SKILL.md` is the single editable skill source for every agent. Shared project rules live in `AGENTS.md`; the tiny `CLAUDE.md` and `GEMINI.md` files import it.

Claude Code uses this physical directory directly. Run
`python scripts/tools/setup_agent_skill_link.py` after cloning to create the ignored
`.agents/skills` directory link for Codex, Cursor, Gemini CLI and VS Code Copilot.
Add `--check` to verify file identity without changes. Creating or editing a skill
through either path reaches this same library. No copying, generated instruction
wrappers, plugin registration or per-edit synchronization is needed. Git operations
use the canonical `.claude/skills` paths. The setup helper refuses conflicting paths.

Start agents in this repository. In a fresh session, inspect the native skill list and explicitly invoke a harmless skill check; then try a matching task without naming the skill. File-identity checks establish the layout, not native activation or task quality. Keep these manual checks brief and use scratch assets. MCP connections and application permissions still need configuration in each agent.

Original AoP skills, Blender authoring, reusable AoE3DE workflows and import/export skills all live here. `bar-extract` and `aoe-building-pipeline` add only AoP policy and worked examples to `aoe3de-bar-archives` and `aoe3de-building-export`; their helper scripts have one implementation in the reusable skills.

Only the four packages listed in `scripts/skill-sync-manifest.json` may be exported. Other skills remain AoP-only by default. `.claude/skills/gxo-convert/` and `scripts/havok/converter.local.json` remain ignored machine-specific setup. Public export repository addresses live in ignored `config/skill-sync.local.json`; copy its example on another device.

Use `public-skill-export` and `public-skill-import` for reviewed transfers. Public repositories are release snapshots; the AoP suite remains the author's working source.
