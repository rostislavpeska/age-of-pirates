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
   check line endings **first**. One rule for every file the game reads (`art`, `data`, `game`, `randmaps`,
   `sound`): CRLF on disk, LF in git. Compare copies by content, never by bytes: `git hash-object
   --path=<repo path> <copy>` equals `git rev-parse HEAD:<repo path>` whatever the copy's line endings (a GitHub
   download is LF). An LF-only difference is not a content change: LF map scripts load (vanilla ships 199 of them).
2. **Never duplicate game assets.** Textures, models, decals, particles, sounds the game already ships are
   referenced by their archive path (`homecity\british\british_tol\textures\british_tol_matA_BaseColor` in a
   `.material`, `buildings\fort\west_fort_decal` in an animfile) - never copied under `art/` or `sound/`, not
   even renamed. Only content the mod itself made is a file here.
   **Exception (owner 2026-10-09): a distinct unit made as a retexture of a vanilla unit** may clone the vanilla
   gr2 under its own name (extracted with `bartool extract --in-repo`, the one case rule 3 allows), with its own
   `.material` and mod-made textures. The clone never changes shape: vanilla geometry, UVs and vertex data stay
   exactly as shipped (internal names may be renamed, `gr2_rename.py`; the skeleton may be replaced by another vanilla
   unit's skeleton whose joints sit at the same places, `gr2_reskeleton.py`, e.g. an infantry body on a rider
   skeleton); the retexture works within the vanilla silhouette. Vanilla textures it still uses are referenced by archive path, never copied. Not for a look that a
   `materialvariant` of the same unit would do.
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
   `python -m pytest scripts/aitest/tests -q` before every AI commit. Start every AI change with the
   `ai-edit` skill; see `docs/ai_scripting_guidelines.md` rule 13. **Mod AI code lives only in
   `game/ai/core/aipiraterules.xs`**; the other core files stay the adopted core byte for byte
   (`.claude/skills/ai-edit/references/mod-ai-architecture.md`).

8. **Images an agent makes never go into the repo.** Screenshots, captures, renders, previews, plots and test
   captures are written to the session scratchpad (or a tool's own temp folder), never next to code, docs or
   tests. `.gitignore` ignores png/jpg/jpeg/bmp/gif/webp everywhere except `art/` and `data/wpfg/` (runtime
   assets), `docs/images/` and `docs/assets/` (curated docs images) and `.claude/skills/` (tool assets); an image
   enters one of those only on the user's word. Tests do not depend on screenshots in the repo: build the image
   in the test or skip when the capture is absent. Never add a one-off ignore line for a new image folder - the
   rule already covers it.

9. **Deleting from a PRODUCTION record needs the owner's approval.** Removing a production tech, proto, trigger
   or other record, removing an effect or line from it, or moving it (which deletes it from its place): name the
   exact deletion and get a yes first. Exempt: TEST records (made only to prove something) and records created
   in the same session, when the intent is clearly to wipe out that mess. An approved deletion is made exactly
   and alone; a suspected further fix is proposed, never bundled in. Read the tests that pin the record first:
   they encode its dependencies (2026-09-27: the London side setup techs were moved unasked, and their order
   dependency on the generic setup was missed).

10. **The image harness is Claude-only.** GPT, Codex, Astra and Gemini agents generate images natively and
   must never call `.claude/skills/image-harness` or its n8n webhook: every call is billed to the owner's API
   accounts. Claude Code uses it (the client refuses outside Claude Code).

11. **Screen control is announced first.** Before any agent or subagent takes the screen - mouse or keyboard
   automation, driving the game or any GUI app, desktop screenshots or screen recording, computer-use / browser
   control tools, a GUI (non-background) Blender - it warns the owner in chat: what it will control, why and for
   how long, and waits for his go when he may be at the machine. Background work (`blender -b`, file tools,
   COM/API calls without UI) is not screen control. Owner, 2026-09-28: "always warn when activating screen control".
   A coordinator passes this rule into every subagent prompt that could touch the screen.

12. **Observable or it did not happen.** Owner, 2026-09-29: "No observability = 99% chance of failure". Long work
   (workflows, background agents, bakes, renders) follows these rules:
   - **Start:** say what runs, why, and a rough finish time; say it again when the time slips.
   - **Every finished step:** a short status (done / running / waiting, with the time of each agent's last
     action) plus the pictures that step made, sent to the owner as it lands. Nothing waits for the end, and there
     is at least one status every 30 min.
   - **"Done" means visible:** in the owner's Blender through the publish step, or pictures in chat. Files on
     disk alone are not a result.
     - A Blender delivery is proven only by the live viewer's readback. `blender-uv-observability`
       `live_publish.py` exits 0 and writes `LIVE_READBACK.json`.
     - Exit 4 = "published, NOT delivered" plus the reason.
     - A handoff asking for his review carries that readback: `handoff.py` and the library publisher refuse it
       otherwise (owner 2026-10-09: "this handoff contract should be unbreakable").
   - **No silent waits or stalls:** an agent that waits (memory gate, render, lock) logs why. The coordinator
     reports any agent idle for more than 15 min and any gate that holds with nothing running.
   - **Live links are watched:** while the owner's Blender is driven, a watchdog checks the MCP port and a drop is
     reported at once. Live changes stay small (register R9 in `blender-mcp-safety`).
   - **Paid or external calls are counted:** image harness generations and similar calls keep their provenance
     JSON, and every report counts them (n8n stores no successful harness runs).
   - **Stops are announced:** stopping or relaunching a workflow, a denied permission, a crash or a blocked step
     is reported with its reason and the decision needed. Nothing is dropped silently.

13. **Late instructions go through the inbox; launches are capped and P0 first.** Owner, 2026-09-29: "prevent firing
   too many agents", "ABSOLUTE priorities for CRITICAL tasks". (`tasks.py` = the task engine in `$AOP_TASKS_DIR`:
   `python scripts/tools/local_env.py get AOP_TASKS_DIR`.)
   - **Inbox:** a late detail is `tasks.py note <TASK> "text"`, never a restart or a prompt edit. Every agent reads
     only its unread notes at each step start (Claude: they arrive with the next tool result; others run
     `tasks.py inbox <TASK> --unread --reader <name>`), never re-reads old ones, and its final report says
     `NOTES APPLIED: <numbers>` or `none`. A coordinator runs `tasks.py bind-run <TASK> <run-id>` right after a launch
     and `--unbind` when the run ends (bindings expire 24 h after the last bind-run).
   - **Launches:** at most 2 jobs at once, counted over every session of this project: workflows, background AND
     foreground agents, launches just allowed; Codex and other agents take a slot with `python
     .claude/hooks/launch_gate.py --claim "<job>" --by <agent> [--task <ID>]` and `--release <id>` it. While an open
     P0 bug exists a launch declares `task: <P0 id>` (a mention does not count). Resume (`resumeFromRunId`), never
     relaunch or rename; a real fresh start says `fresh-run: <reason>` and is reported. Only the owner turns it off.
   - **Enforcement is live only once the owner registered the hooks** (`.claude/hooks/settings_entries.json` into
     `.claude/settings.json`); `python .claude/hooks/harness_status.py` says whether it is. Until then every agent
     follows this rule by hand.
   - **Exports:** no model reaches the owner's game test before `python scripts/havok/gr2_lint.py --profile <building>
     <folder>` exits 0 (a SKIP exits 2: never `--no-dll` or `--allow-skip` for this gate); a defect found in game
     first becomes a lint check. The lint holds two hard floors on every model:
     - the universal UV density floor (`texel_density`,
       `.claude/skills/blender-architecture-texturing/references/uv-density-floor.md`);
     - the AoP texture ceiling of the model's owner-confirmed class (`texture_budget`: small 1x2048, medium
       2048 + 1024, large 2x2048; `gr2_lint_profiles.json`).
     Korean TC: `python "$AOP_KOREAN_REPO/research/Texturing_11/Claude_CP2/gates/uv_gate.py"` exits 0 first
     (`python scripts/tools/local_env.py get AOP_KOREAN_REPO`; exit 1 = stop and report; the `--profile korean_tc`
     lint runs it as check `uv_lineage`).

14. **Report harness/process defects, never work around them silently.** Owner, 2026-09-30: "it MUST NEVER happen
   again". A lost version, a misfiring gate or tool, a rule you cannot keep: `tasks.py report --by <you> --kind
   harness|bug|regression|process|data-loss --severity S0..S3 --title "..." --what "..." [--evidence <absolute paths,
   ids>]` (the CLI is the way; `POST /api/incidents` only when the optional task app runs, tasks README "Reporting an
   incident"). It prints the INC id; S0/S1 open a P0 task. The coordinator investigates; the reporter continues its task.

15. **One source of truth: no duplicates of separate mods in AoP.** A separate mod or project (the Koreans add-on
   `../age-of-pirates-koreans`, any future civ add-on) lives only in its own repository. Never create a copy, mirror,
   source folder, export pipeline or second version of it inside AoP unless the owner explicitly requests a merge
   and confirms it. A duplicate you find is reported (rule 14), not followed. **Skills are the exception and always
   live here:** every skill goes into AoP's `.claude/skills/`, even one created while working in the separate repo;
   a skill holds the generic method only. **Project-specific documentation stays in the project's own repo**
   (Korean plan, audit, design and research stay in the Korean repositories, never in AoP). Owner, 2026-10-08:
   "One source of truth!!! NEVER TWO!!!", "skills always into Age of Pirates", "Korean specific documentation stays
   in korean repo" (INC-170).
   **Temporary (owner 2026-10-09): ALL Korean content lives in `../age-of-pirates-koreans`, AoP keeps none** -
   civ records AND the Korean building models, textures, 3D test benches, their sounds and test maps. Owner: "It
   should contain them. All Korean stuff should be there", "temporary. We will merge, but not now". Until the owner
   orders the merge, new Korean work goes there; AoP keeps only the generic skills and tools.
   Exception (owner 2026-10-09): `zpKoreanBombard` is AoP gameplay and stays in AoP, with the Korean soldier voices it
   uses (`sound/korean/`, the `Korean_Soldier_*` soundsets).
   Exception (owner 2026-10-10): AoP's own `art/buildings/asian_civs/castle/castle.xml` carries the Korean castle branch
   (inert without the add-on; models in the add-on, which ships no castle.xml). Refresh it only with the add-on's
   `python tools/korean_visuals.py --write-aop`; never delete it.

## Where things are

- Skills: `.claude/skills/` - `bar-extract` (vanilla files, XML<->XMB), `aoe-building-pipeline` (buildings,
  materials, textures), `gr2-granny-edit` (byte-level .gr2 edits: `scripts/havok/gr2_*.py`), `mod-deploy-check`
  (pre-zip audit), `game-startup` (never kill the game; launch only on instruction).
- Tools: `scripts/tools/check_art_eol.py`, `scripts/havok/ddt_dxt1.py` (DXT1 .ddt with mips),
  `scripts/havok/gr2_editmesh.py` (in-place vanilla model edits - the converter route loses large faces in game).
- Koreans add-on: a separate mod and repository, `../age-of-pirates-koreans`, the single source of truth for every
  Korean civ record, tool and test (owner 2026-10-08: never a second copy, source folder or export here). AoP stays
  Korean-free (`scripts/tools/tests/test_no_korean_civ_in_aop.py`); workflow and merge strategy in that repo's
  `README.md`, open work in its `AUDIT.md`.

## Local environment (every agent, every device)

Device-specific paths live only in ignored local files. Tracked code, docs and skills hold examples and paths relative
to the repo or to a local variable (`$AOP_KOREAN_REPO/research/...`); the AoE3 profile is never configured, the repo
sits at `<profile>/mods/local/age-of-pirates`. On a fresh clone, a new worktree or a new device, before other work:
`python scripts/tools/local_env.py --init` (creates each missing local file from the main checkout or its example,
never overwrites), fill in every value you can find on THIS device, and run `python scripts/tools/local_env.py` until
it exits 0. Never copy another device's paths and never guess; what the device lacks stays empty and the tools that
need it skip. `config/image-harness.local.env` holds secrets: the owner fills it. A new device path goes into a local
file and its tracked example, never into tracked files (`scripts/tools/tests/test_local_env.py` fails on one).

## 3D phase handoff and QA (every agent)

Every 3D phase (geometry, material split, UV, bake, sources, composite, review, Painter, export) ends with a
`HANDOFF.json` per `.claude/skills/blender-architecture-texturing/references/handoff-contract.md`: the next agent
consumes the canonical outputs of the latest accepted phase and never re-derives them (e.g. the material split and
its palette). Texturing iterations pass `.claude/skills/blender-high-low-baking/references/texturing-qa.md`
(numeric QA, fixed shot sheet, normal-stacking and material-consistency rules) before the owner sees them. Live
Blender work through the MCP follows `.claude/skills/blender-mcp-safety` (log first, one heavy op per call).

## Self-improvement journal (3D work)

**Partial UV review gates:** every bounded UV editing batch (including mirrored
sharing repairs and each model's AO separation) is saved and checked, then its
actual UV maps are embedded in chat before the next dependent edit. Follow
`.claude/skills/blender-uv-workflow/references/review-packet.md`. Account for every
model and shared/protected resource; unchanged pictures may be reused with source
identity. File-only delivery is insufficient. Record machine verification, chat
delivery and owner acceptance separately. Authorized continued WIP work may proceed
after delivery; silence does not grant final acceptance or a below-floor GO.

During any 3D work (modeling, UV, conjoinment, AO, atlas, baking, texturing, export - Blender or Photoshop)
every agent records lessons in the shared `.claude/skills/JOURNAL.jsonl` **at the moment they happen**: an owner
correction, a failure, a confirmed method, a measurement that settles a question. Use the `workflow-journal`
skill (`python .claude/skills/workflow-journal/scripts/journal.py add ...`). Skills are improved later by
distilling open records (`journal.py digest`), on the owner's request; agent-private memory is not shared.

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
For live Photoshop documents, layered edits or texture exports, read
`.claude/skills/photoshop-live-edit/SKILL.md`. It includes the tested Windows COM/JSX
connection used in this project; absence of Photoshop MCP does not rule out that route.
When the user asks to start Photoshop, run its `start_photoshop.ps1` with `-LocalConfig config/tool-paths.local.json`
(ignored, this device's application paths; `local_env.py --init` creates it from the skill-library-audit example).
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
