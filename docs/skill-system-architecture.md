# Skill system ownership

Owner-approved migration, 13 October 2026: generic capabilities are authored in
private Blendify; AoE3 adapters and AoP mod policy remain here. Korean appearance
is owned by the Korean project. This replaces the former all-skills-in-AoP rule.

The canonical architecture is Blendify `docs/skill-system.md`, resolved using
`BLENDIFY_REPO` in ignored `config/aop.local.env`. AoP retains its consumer setup
and game policy. [Agent setup](agent-skills.md) explains local access.

| Work | Owner |
| --- | --- |
| Generic geometry, UV, bake, texture/review mechanics and workflow upkeep | Blendify `.claude/skills/` |
| GR2/GXO, Havok, DDT, game states, attachments and runtime validation | AoP `.claude/skills/` |
| AoP deployment, XML, AI and random maps | AoP `.claude/skills/` and `AGENTS.md` |
| Korean forms and references | Korean project's entry and `patterns/korean/` |
| Age-specific palette, glaze, moss and ornament | Korean set/subproject profiles |

`config/skill-sources.json` selects owners, not names. Discovery scans their live
physical folders. `.claude/skills` contains local owned skills plus ignored links;
`.agents/skills` exposes those same files to Codex/Cursor. Refresh after additions
or reorganization. Search is live: `python scripts/tools/setup_agent_skill_link.py --search roof --json`.

Keep one editable definition. Never copy a private skill into this public repo to
fix a missing link. The converter's existing local package remains a configured,
non-redistributable prerequisite. Applications and permissions are separate.
No MCP service or vector database is required for this layout.

Public `rts-3D-modelling` and `aoe3-modding-skills` repositories remain reviewed
snapshots. The explicit release allowlist in `scripts/skill-sync-manifest.json`
does not authorize releasing new private content. Imports target the registered
canonical owner. Historical copies already published cannot be made private by
this migration. No public skill snapshot is refreshed as part of this split.
