# Shared agent setup

AoP owns game adapters and mod skills. Private Blendify owns generic 3D skills;
the Korean authoring project owns its style entry. All agents use the same files.

1. Configure `BLENDIFY_REPO` and `AOP_KOREAN_REPO` in ignored `config/aop.local.env`
   using clones on this machine. See `config/aop.example.env`.
2. Run `python scripts/tools/setup_agent_skill_link.py` to refresh discovery.
3. Run `python scripts/tools/setup_agent_skill_link.py --check` to verify identity.
4. Search without loading the suite: `python scripts/tools/setup_agent_skill_link.py --search roof --json`.

Claude Code reads `.claude/skills`. Codex and Cursor read `.agents/skills`, a link
to that assembled view. `CLAUDE.md` and `GEMINI.md` import `AGENTS.md`. No copied
skill bodies, personal mirrors or additional plugin/MCP registration are needed.

The physical source folders supply the live catalog. New skills, deletions and
renames are detected at refresh. Edits are visible immediately through links.
The installer updates only its own verified links, refusing unknown copies or
duplicate names. `--check` is read-only. Restart a host whose catalog still
advertises old metadata; filesystem verification does not prove host use.

Always edit the resolved owner. A new generic skill is created in Blendify, an
AoE adapter here, and a Korean art recipe in its project. See
[ownership](skill-system-architecture.md). Explicit global installation remains
available through `scripts/tools/install_user_skills.py`; setup does not run it.
Do not install old public snapshots over the maintainer's same-name sources.

No licensed converters, binaries or credentials are installed. The external
converter package is identified by ignored `config/skill-local-packages.json`.
Its presence is not application readiness. Never recursively delete links.
