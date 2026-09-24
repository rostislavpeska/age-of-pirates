# Age of Pirates: shared agent instructions

This folder IS the live mod: the game loads it directly. Every byte here ships in the portal zip.

## Any XML -> read `.claude/skills/aoe-xml/SKILL.md` first, verify with `python .claude/skills/aoe-xml/scripts/xmlcheck.py`

## Hard rules

1. **Runtime XML is CRLF.** Any XML the engine parses from this folder at run time - animfiles (`art/**/*.xml`),
   `*.material`, `sound/**/*_snds.xml`, `*.lgt`, `*.tactics` - must have CRLF line endings. An LF-only file is
   **silently ignored**: the unit places, the decal draws, the model never renders, no error anywhere
   (2026-09-17, ten game restarts lost). The Write tool writes LF. After writing any such file run
   `python scripts/tools/check_art_eol.py` (`--fix` converts); the PostToolUse hook in `.claude/settings.json`
   converts automatically, `.gitattributes` keeps checkouts CRLF. When a model "does not appear" in game,
   check line endings **first**.
2. **Never duplicate game assets.** Textures, models, decals, particles, sounds the game already ships are
   referenced by their archive path (`homecity\british\british_tol\textures\british_tol_matA_BaseColor` in a
   `.material`, `buildings\fort\west_fort_decal` in an animfile) - never copied under `art/` or `sound/`, not
   even renamed. Only content the mod itself made is a file here.
3. **Vanilla extractions never enter the repo.** `bartool extract` only into the session scratchpad
   (skill `bar-extract`); the tool refuses in-repo targets.
4. **`data/*.xml` edits are inert until the `.xml.xmb` twin is rebuilt**
   (`python .claude/skills/aoe3de-bar-archives/scripts/xmbc.py check|build data/<file>.xml`); commit both.
   Art and sound XML stay plain - no twins there.
5. **New records go at the end of real content**, directly above the file's first long TEST/commented
   section, ids continuing the real sequence (protomods 21160+).
6. **Backslashes in the Bash tool collapse** (`\\` loses a level even in quoted heredocs). Write scripts that
   contain Windows paths with the Write tool and build the character from `chr(92)`.

7. **AI changes never change what the AI contests without the owner's approval.** That covers sockets, Trading
   Posts, natives, bridges, objectives, forward bases, targets and where defences stand. Propose, don't commit. Map-
   specific AI code lives only where `scripts/aitest/tests` (`APPROVED_LONDON_CODE`) lists the owner's approval. Run
   `python -m pytest scripts/aitest/tests -q` before every AI commit. See `docs/ai_scripting_guidelines.md` rule 13.

## Where things are

- Skills: `.claude/skills/` - `bar-extract` (vanilla files, XML<->XMB), `aoe-building-pipeline` (buildings,
  materials, textures), `gr2-granny-edit` (byte-level .gr2 edits: `scripts/havok/gr2_*.py`), `mod-deploy-check`
  (pre-zip audit), `game-startup` (never kill the game; launch only on instruction).
- Tools: `scripts/tools/check_art_eol.py`, `scripts/havok/ddt_dxt1.py` (DXT1 .ddt with mips),
  `scripts/havok/gr2_editmesh.py` (in-place vanilla model edits - the converter route loses large faces in game).

## Universal skill source

When maintaining the skill system, read [its architecture](docs/skill-system-architecture.md).
It describes AoP ownership, both public repositories, sync boundaries and verification.

All skills are authored in `.claude/skills/`, including the original AoP skills, Blender authoring,
reusable AoE3DE tooling and public export/import. Read and edit that directory directly.
Choose relevant packages from `.claude/skills/*/SKILL.md` by their names and frontmatter
descriptions, then read their instructions before acting. Load only relevant skills
and references; do not load the entire suite into context. This applies to every agent.

Claude Code reads the physical, tracked `.claude/skills/` library directly.
Codex, Cursor, Gemini CLI and VS Code Copilot use the single ignored `.agents/skills`
directory link to it. Creating or editing a skill through either path changes the
same source, including new skill directories. There are no generated skill bodies,
plugins or synchronization between agents. No top-level `skills/` tree remains.
After a fresh clone or worktree, run `python scripts/tools/setup_agent_skill_link.py`;
add `--check` for read-only file-identity verification. Never replace a conflicting
directory automatically. Do not add extra `.codex`, `.cursor` or `.gemini` skill mirrors.
Perform Git operations on canonical `.claude/skills` paths. Never recursively delete
through `.agents/skills`; remove only the verified link entry when repairing setup.

`CLAUDE.md` and `GEMINI.md` import this file; Codex and Cursor read it directly.
Discovery paths do not configure MCP connections, permissions or installed tools.
Check the live tool connection required by the selected skill before editing assets.

For geometry use `.claude/skills/blender-architecture/SKILL.md`; for UVs and textures use
`.claude/skills/blender-architecture-texturing/SKILL.md`. Building work in this mod starts with
`.claude/skills/aoe-building-pipeline/SKILL.md`, which adds the AoP profile to the reusable workflow.
Archive/XMB work starts with `.claude/skills/bar-extract/SKILL.md`, then its referenced
`aoe3de-bar-archives` tools. The reusable packages are implementations, not competing
AoP entry points. Keep AoP-specific routing out of their public instructions.

Public repositories receive only allowlisted snapshots. Use `.claude/skills/public-skill-export/SKILL.md`
or `.claude/skills/public-skill-import/SKILL.md`. Device paths live in ignored
`config/skill-sync.local.json`; initialize from its example on a new device.
Local-only converter configuration remains ignored, and tools use the installed executable
through that configuration. Do not duplicate private binaries into public skill packages.

Keep source assets outside runtime folders, preserve unrelated changes, and keep art and
`_snds` XML editable without introducing XMB twins. All agent-specific wrappers refer here;
maintain shared rules in this file.
