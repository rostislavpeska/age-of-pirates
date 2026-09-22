# Universal Age of Pirates skills

`skills/<name>/SKILL.md` is the single editable skill source for every agent. Both `.agents/skills` and `.claude/skills` are ignored discovery links to this directory. Create them after cloning with `python scripts/tools/setup_agent_skill_link.py`. Shared project rules live in `AGENTS.md`; `CLAUDE.md` imports that file.

Original AoP skills, Blender authoring, reusable AoE3DE workflows and import/export skills all live here. `bar-extract` and `aoe-building-pipeline` add only AoP policy and worked examples to `aoe3de-bar-archives` and `aoe3de-building-export`; their helper scripts have one implementation in the reusable skills.

Only the four packages listed in `scripts/skill-sync-manifest.json` may be exported. Other skills remain AoP-only by default. `skills/gxo-convert/` and `scripts/havok/converter.local.json` remain ignored machine-specific setup. Public export repository addresses live in ignored `config/skill-sync.local.json`; copy its example on another device.

Use `public-skill-export` and `public-skill-import` for reviewed transfers. Public repositories are release snapshots; the AoP suite remains the author's working source.
