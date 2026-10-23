# Skills available from this project

Work in the project you mean to change. Do not switch repositories merely to use
a skill: this directory exposes the registered owners through verified links.
Generic 3D sources are private Blendify; AoE3 adapters and AoP mod skills are here;
the Korean entry belongs to the Korean authoring project.

See [ownership](../../docs/skill-system-architecture.md) and
[agent access](../../docs/agent-skills.md). Discovery scans current source folders.
Search by task: `python scripts/tools/setup_agent_skill_link.py --search roof --json`.
At first skill use in a session, agents check links with --check and refresh if
needed. Users do not need to copy skills, maintain a list or run setup every turn.

Claude reads this assembled view; Codex/Cursor read the .agents/skills alias.
Edits go to the canonical owner. New generic skills are created in Blendify.
Public exports remain explicit reviewed releases, never automatic mirrors.
Native app catalog use must be tested inside that app; file identity alone proves
only the filesystem connection. Reload a host whose discovery metadata is stale.
